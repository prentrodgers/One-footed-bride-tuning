#!/usr/bin/env python3
"""
blender_woodwind_poc.py — 4 invisible woodwind players as a Blender stage
section, porting woodwind_section_poc.py (matplotlib) to 3D.

Seats (one instrument each, two depth rows):
  back  : French Horn (voice 16), Bassoon (voice 12)
  front : Clarinet (voices 13 + 14, i.e. clarinet absorbs the flute),
          Oboe (voice 15)

Each instrument is a static procedural silhouette that:
  • idle-sways (slow sinusoidal roll, per-seat freq/phase, faded in when the
    seat is playing and out again after it falls silent),
  • leans forward toward the camera while a note is held (eased back after),
  • glows: its body colour blends toward a bright family tint on held notes.
No per-note moving parts (unlike the marimba mallets / finger-piano tines),
so animation is just a per-seat rotation of a base Empty + a body colour.

Standalone smoke test:
    blender --background --python blender_woodwind_poc.py -- --still out.png
"""
import argparse
import math
import sys
from pathlib import Path

import bpy
import mathutils
import numpy as np

REPO_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_DIR))

import blender_bass_section_poc as bass   # reuse load_voices / clear_scene

FPS = 30

VOICE_BASSOON, VOICE_CLARINET, VOICE_FLUTE, VOICE_OBOE, VOICE_HORN = 12, 13, 14, 15, 16

# Rest body colours and the bright tint each blends toward while playing
# (ported from woodwind_section_poc.py).
BODY_CLR = {
    'clarinet': (0.14, 0.12, 0.10),   # ebony black
    'oboe':     (0.12, 0.10, 0.08),   # grenadilla black
    'horn':     (0.82, 0.68, 0.22),   # unlacquered brass
    'bassoon':  (0.20, 0.11, 0.05),   # dark stained maple, at rest
}
GLOW_CLR = {
    'clarinet': (0.55, 0.65, 0.90),
    'oboe':     (0.55, 0.65, 0.90),
    'horn':     (1.00, 0.88, 0.40),
    'bassoon':  (0.76, 0.55, 0.31),   # light brown while playing
}
SILVER = (0.72, 0.74, 0.78)
REED_CLR = (0.62, 0.55, 0.35)

GLOW_DECAY = 0.55

# ── showing pitch, not just "sounding" ──────────────────────────────────────
# A wind instrument that only glows and sways tells you WHEN it plays and
# nothing about WHAT. These sections carry the same four voices the marimba
# does, so the fingering is made to spell the pitch class out:
#
#   nine tone holes, all covered = C.  Half a hole opens per semitone, so
#   C# is 8.5 covered and B is 3.5.  Holes uncover from the BOTTOM up, the
#   way a real player lifts fingers to go higher.
#
# It is not a real fingering chart — no instrument works this way — but it is
# monotonic, it reads at a glance, and a half-open hole means exactly what it
# looks like: a pitch halfway between two semitones. That last part matters
# here, because these chorales are not in 12-TET; HOLE_QUANTIZE = True snaps
# every note to the nearest semitone instead, which reads more crisply but
# throws the tuning away.
N_HOLES = 9
HOLE_QUANTIZE = False
# Coverage is shown by COLOUR ALONE, with every pad fixed to the body. An
# earlier version also lifted the open pads clear of the instrument, which
# read as loose beads floating beside it rather than as holes: the eye lost
# track of which dot was which. Held still, the same nine dots simply darken
# and brighten in place, and the fingering is legible as a pattern.
HOLE_COVERED_CLR = (0.06, 0.055, 0.05)    # finger down on the hole
HOLE_OPEN_CLR = (0.93, 0.94, 0.97)        # hole standing open
# The horn has three rotors rather than nine holes, so it shows the same
# thing at coarser resolution: one dot per rotor, dark when that valve is
# thrown. They used to swing round the rotor as well, which at stage framing
# just smeared into the coiled tubing behind them.
PLAY_LEAN_DEG = {'clarinet': 7.0, 'oboe': 7.0, 'horn': 10.0, 'bassoon': 6.0}
PLAY_RELAX_T = 0.5
# Sway is deliberately tiny now (~10% of the old ±5.6°) and fades out fast
# once a seat stops playing, so instruments are essentially still except for
# a faint breath while sounding — the big idle rock read as unmotivated.
SWAY_AMP_DEG = 0.56
SWAY_ENV_TAU_IN, SWAY_ENV_TAU_OUT = 0.4, 0.5
LEAN_TAU = 0.12   # s — quick but smooth tip toward/away the mouthpiece (no onset snap)


# ── materials ────────────────────────────────────────────────────────────────
# Which instrument bodies are metal. Everything else (grenadilla clarinet and
# oboe, maple bassoon) is wood and must not get the polished-metal response.
METAL_KINDS = frozenset({'horn', 'flute', 'trumpet', 'vibraphone'})


def hole_coverage(cents, n=N_HOLES):
    """How many of `n` holes are covered for a pitch, 9.0 down to 3.5.

    Cyclic in the octave, so it jumps back to fully covered at every C — a
    sawtooth, which is what a pitch CLASS display has to be."""
    pc = (cents % 1200.0) / 100.0            # semitones within the octave
    if HOLE_QUANTIZE:
        pc = float(round(pc) % 12)
    return n - pc * 0.5


def hole_states(covered, n=N_HOLES):
    """Per-hole coverage 0..1, TOP hole first. The holes fill from the top
    down and the boundary hole takes the fraction — that hole, sitting half
    covered, is the one saying "between these two semitones"."""
    return [min(1.0, max(0.0, covered - i)) for i in range(n)]


def make_pad_material():
    """Pads take their colour from each object, so nine of them per
    instrument animate as plain tuples instead of nine materials."""
    mat = bpy.data.materials.new("WWPad")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    obj_info = nt.nodes.new("ShaderNodeObjectInfo")
    nt.links.new(obj_info.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 0.55
    bsdf.inputs["Roughness"].default_value = 0.28
    return mat


def make_body_material(name, metallic=0.7, roughness=0.15):
    """Principled body whose Base Color AND Emission Color both come from the
    object's own colour — so setting obj.color per frame both re-tints and
    self-illuminates the body (dark at rest, glowing when the colour is
    driven bright on a held note)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    obj_info = nt.nodes.new("ShaderNodeObjectInfo")
    nt.links.new(obj_info.outputs["Color"], bsdf.inputs["Base Color"])
    if "Emission Color" in bsdf.inputs:
        nt.links.new(obj_info.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 0.45
    # Defaults are polished metal: a tight highlight from the key light is what
    # reads as brass/silver at stage distance. Reflections are no help here —
    # the world and floor are near-black, so there is nothing to reflect — but
    # sun specular is free and needs no raytracing. Wooden bodies (grenadilla
    # clarinet/oboe, maple bassoon) must pass metallic=0.0 with a duller
    # roughness, or they come out looking like painted tin.
    bsdf.inputs["Roughness"].default_value = roughness
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metallic
    return mat


def make_solid(name, color, roughness=0.5, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = roughness
    b.inputs["Metallic"].default_value = metallic
    return mat


# ── geometry helpers (instruments stand up in Z, thin toward camera in Y) ─────
def _cone(z0, z1, r0, r1, mat, x=0.0, y=0.0, verts=20):
    bpy.ops.mesh.primitive_cone_add(radius1=r0, radius2=r1, depth=(z1 - z0),
                                    vertices=verts, location=(x, y, (z0 + z1) / 2.0))
    o = bpy.context.object
    o.data.materials.append(mat)
    return o


def _ball(x, z, r, mat, y=0.0, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y, z))
    o = bpy.context.object
    o.scale = scale
    o.data.materials.append(mat)
    return o


def _torus(x, z, major, minor, mat, y=0.0):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     location=(x, y, z),
                                     major_segments=28, minor_segments=10)
    o = bpy.context.object
    # stand the ring up in the XZ plane (default torus lies in XY)
    o.rotation_euler = (math.radians(90), 0, 0)
    o.data.materials.append(mat)
    return o


def _curve_tube(points, radius, mat, name="wwtube"):
    """A round tube swept along a polyline of 3D points — for curved tubing
    like the bassoon's bocal (crook) and the french horn's leadpipe."""
    cu = bpy.data.curves.new(name, 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = radius
    cu.bevel_resolution = 3
    sp = cu.splines.new('POLY')
    sp.points.add(len(points) - 1)
    for i, (x, y, z) in enumerate(points):
        sp.points[i].co = (x, y, z, 1.0)
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def _cone_dir(p0, p1, r0, r1, mat, verts=16):
    """A tapered tube between two arbitrary 3D points (for tilted parts like
    the mouthpiece funnel / reed staple sitting on a curved crook)."""
    p0v, p1v = mathutils.Vector(p0), mathutils.Vector(p1)
    d = p1v - p0v
    bpy.ops.mesh.primitive_cone_add(radius1=r0, radius2=r1, depth=d.length,
                                    vertices=verts, location=(p0v + p1v) / 2.0)
    o = bpy.context.object
    o.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    o.data.materials.append(mat)
    return o


def _key_zs(top, bottom, n=N_HOLES, power=1.25):
    """`n` key heights from `top` down to `bottom`, crowded at the top and
    spreading slightly toward the bell — real tone holes bunch up where the
    hand sits and open out down the bore. power=1 would space them evenly."""
    return [top - (top - bottom) * (i / (n - 1)) ** power for i in range(n)]


# ── the four instruments ─────────────────────────────────────────────────────
# Each returns (all_objs, body_objs): body_objs are the ones whose colour is
# animated (glow); all_objs get parented to the seat empty for sway/lean.
def build_clarinet(body_mat):
    silver = make_pad_material()
    body = [
        _cone(0.00, 0.16, 0.095, 0.055, body_mat),   # flared bell
        _cone(0.16, 1.45, 0.050, 0.042, body_mat),   # long body
        _cone(1.45, 1.60, 0.036, 0.028, body_mat),   # barrel
    ]
    mp = _cone(1.60, 1.72, 0.026, 0.014, body_mat)   # mouthpiece
    body.append(mp)
    holes = [_ball(0.035, z, 0.018, silver, y=-0.05, scale=(1, 0.5, 1))
             for z in _key_zs(1.34, 0.30, n=N_HOLES)]
    return body + holes, body, {"holes": holes}


def build_oboe(body_mat):
    silver = make_pad_material()
    reed = make_solid("WWReed", REED_CLR, roughness=0.6)
    body = [
        _cone(0.00, 0.14, 0.075, 0.045, body_mat),   # small bell
        _cone(0.14, 1.35, 0.030, 0.050, body_mat),   # conical body (widens upward)
    ]
    r = _cone(1.35, 1.50, 0.018, 0.006, reed)        # double-reed staple
    holes = [_ball(0.032, z, 0.015, silver, y=-0.045, scale=(1, 0.5, 1))
             for z in _key_zs(1.26, 0.26, n=N_HOLES)]
    return body + [r] + holes, body, {"holes": holes}


def build_bassoon(body_mat):
    metal = make_solid("WWBocal", SILVER, roughness=0.3, metallic=0.75)
    reed = make_solid("WWBsnReed", REED_CLR, roughness=0.6)
    # Doubled bore: the tall bass/bell joint (left) and the shorter wing joint
    # (right), joined at the boot (double joint) U-bend at the bottom.
    # Both joints stop well clear of the floor, leaving the boot's U room to
    # be seen — the two bores nearly touch, so a bare semicircle tucked
    # between them just reads as a rounded blob.
    foot_z = 0.34
    bore_x = 0.07
    bass = _cone(foot_z, 1.90, 0.070, 0.048, body_mat, x=-bore_x)
    bell = _cone(1.90, 2.10, 0.052, 0.078, body_mat, x=-bore_x)    # bell joint + flare
    bell_ring = _torus(-bore_x, 2.09, 0.078, 0.010, metal)         # metal bell ring
    wing = _cone(foot_z, 1.68, 0.062, 0.050, body_mat, x=bore_x)
    # Boot joint: the two bores really are joined at the bottom, so the air
    # turns the corner instead of the wing joint dead-ending into a blob. A
    # narrower tube than either bore, dropping out of each as a visible leg
    # before the half-circle turn, so the U reads as a U.
    turn_z = foot_z - 0.18
    arc = [(bore_x * math.cos(a), 0.0, turn_z + bore_x * math.sin(a))
           for a in (math.pi + math.pi * k / 12 for k in range(13))]
    boot = _curve_tube([(-bore_x, 0.0, foot_z + 0.03)] + arc + [(bore_x, 0.0, foot_z + 0.03)],
                       0.042, body_mat, name="WWBsnBoot")
    body = [bass, bell, wing, boot]
    # Bocal (crook): a slender S-curved metal tube off the top of the wing
    # joint that hooks up and back toward the player's reed.
    bocal = _curve_tube([(0.07, 0.0, 1.68), (0.11, -0.05, 1.80),
                         (0.10, -0.13, 1.90), (0.02, -0.18, 1.95)], 0.009, metal)
    reed_o = _cone_dir((0.02, -0.18, 1.95), (-0.02, -0.21, 1.99), 0.008, 0.004, reed)
    # Nine tone holes down the wing joint, on the camera side of the bore.
    holes = [_ball(bore_x + 0.045, z, 0.020, make_pad_material(), y=-0.052, scale=(1, 0.5, 1))
             for z in _key_zs(1.58, 0.52, n=N_HOLES)]
    return body + [bell_ring, bocal, reed_o] + holes, body, {"holes": holes}


def build_horn(body_mat):
    # French horn: concentric coiled tubing, a big flared bell off the
    # lower-left, a curved leadpipe up to a funnel mouthpiece, valve rotors.
    silver = make_solid("WWHornValve", SILVER, roughness=0.3, metallic=0.75)
    coil_r = (0.36, 0.29, 0.22)
    cz = 0.92                       # coil centre height
    coils = [_torus(0.0, cz, r, 0.032, body_mat) for r in coil_r]
    # Big flared bell pointing down and to the left (the horn's signature).
    # Its narrow end is placed ON the outer coil rather than near it: put the
    # throat at a chosen angle round the ring and build the cone outward from
    # there, so bell and tubing are one connected run instead of the bell
    # floating free in space.
    throat_a = math.radians(207.0)   # down and to the left, off the outer coil
    throat = (coil_r[0] * math.cos(throat_a), 0.0, cz + coil_r[0] * math.sin(throat_a))
    flare_dir = mathutils.Vector((math.cos(throat_a), -0.30, math.sin(throat_a))).normalized()
    mouth = mathutils.Vector(throat) + flare_dir * 0.52
    bell = _cone_dir(throat, tuple(mouth), 0.055, 0.34, body_mat, verts=30)
    # Curved leadpipe: starts on the outer coil too, sweeping up to the
    # funnel mouthpiece at the top-right.
    lead_a = math.radians(34.0)
    lead0 = (coil_r[0] * math.cos(lead_a), 0.0, cz + coil_r[0] * math.sin(lead_a))
    lead = _curve_tube([lead0, (0.30, -0.03, 1.32),
                        (0.34, -0.05, 1.44), (0.33, -0.06, 1.54)], 0.018, body_mat)
    mpc = _cone_dir((0.33, -0.06, 1.54), (0.34, -0.07, 1.66), 0.016, 0.032, silver)
    # Rotor valves threaded onto the innermost coil's lower arc, where a
    # player's left hand would sit — not hanging in the middle of the loop.
    # Three rotors, spread wide along the lower arc of the inner coil. They
    # used to sit at ±0.11 with fat 0.030 rings, which at stage framing piled
    # into one blob of overlapping tubing; spread to ±0.17 with thinner rings
    # they read as three separate valves, and the indicator disc in each one
    # stands proud of the coil rather than tangling with it.
    rotors, paddles = [], []
    for vx in (-0.17, 0.0, 0.17):
        vz = cz - math.sqrt(max(0.0, coil_r[-1] ** 2 - vx ** 2))
        rotors.append(_torus(vx, vz, 0.058, 0.020, silver))
        paddles.append(_ball(vx, vz, 0.045, make_pad_material(), y=-0.085,
                             scale=(1, 0.45, 1)))
    body = coils + [bell, lead]
    return body + [mpc] + rotors + paddles, body, {"rotors": paddles}


BUILDERS = {'clarinet': build_clarinet, 'oboe': build_oboe,
            'bassoon': build_bassoon, 'horn': build_horn}

# Seat layout in the section's own local space (normalised by the stage
# later). Staggered so the back pair sit on the OUTSIDE and the front pair
# INSIDE — from the elevated front camera none line up column-on-column, so
# they stop overlapping. Each instrument is also rolled BASE_ROLL_DEG (top
# toward screen-left, bottom toward screen-right), like a held instrument.
# Quartet order left->right: clarinet, then horn + bassoon in the middle,
# then oboe on the right. Clarinet/oboe (thin) sit slightly forward; horn +
# bassoon (bulkier) a touch back.
SEATS_SPEC = [
    # id, kind, voices, x, y (depth), scale
    ('clarinet', 'clarinet', (VOICE_CLARINET, VOICE_FLUTE),  -2.0, -0.2, 1.0),
    ('horn',     'horn',     (VOICE_HORN,),                  -0.7,  0.7, 1.0),
    ('bassoon',  'bassoon',  (VOICE_BASSOON,),                0.7,  0.5, 1.0),
    ('oboe',     'oboe',     (VOICE_OBOE,),                   2.0, -0.2, 1.0),
]
SWAY_FREQS = [0.225, 0.2625, 0.2375, 0.2875]
SWAY_PHASES = [0.0, 1.1, 2.3, 0.7]
# Constant lean (roll) per instrument so tops sit left, bottoms right; the
# bassoon leans hard, the way a player holds it diagonally across the body.
BASE_ROLL_DEG = 16.0
ROLL_BY_KIND = {'clarinet': 16.0, 'oboe': 16.0, 'horn': 10.0, 'bassoon': 26.0}


def build_woodwinds(x0):
    metal_mat = make_body_material("WWBodyMetal")
    wood_mat = make_body_material("WWBodyWood", metallic=0.0, roughness=0.45)
    seats = []
    for i, (sid, kind, voices, sx, sy, sc) in enumerate(SEATS_SPEC):
        before = set(bpy.data.objects)
        body_mat = metal_mat if kind in METAL_KINDS else wood_mat
        built = BUILDERS[kind](body_mat)
        all_objs, body_objs = built[0], built[1]
        moving = built[2] if len(built) > 2 else {}
        for o in body_objs:
            o.color = (*BODY_CLR[kind], 1.0)
        # Parent everything to a base empty at the seat position; scale/rotate
        # that empty for placement + per-frame sway/lean.
        empty = bpy.data.objects.new(f"ww_{sid}", None)
        bpy.context.scene.collection.objects.link(empty)
        empty.location = (x0 + sx, sy, 0.0)
        empty.scale = (sc, sc, sc)
        roll = ROLL_BY_KIND.get(kind, BASE_ROLL_DEG)
        # Bake the constant lean at build time so the tilt shows even in a
        # static layout render; the per-frame update re-applies it (plus
        # sway/lean) during animation.
        empty.rotation_euler = (0.0, math.radians(roll), 0.0)
        for o in all_objs:
            if o.parent is None:
                o.parent = empty
        seat = dict(id=sid, kind=kind, voices=voices, empty=empty,
                    body=body_objs, sway_freq=SWAY_FREQS[i],
                    sway_phase=SWAY_PHASES[i], sway_env=0.0,
                    base_roll=roll)
        _arm_fingering(seat, moving)
        seats.append(seat)
    return dict(seats=seats)


def _arm_fingering(seat, moving):
    """Record what a seat needs to show its pitch: each pad's rest position
    and the direction it lifts, or each rotor paddle's centre of swing.
    Seats whose builder offers neither simply keep glowing and swaying."""
    holes = moving.get("holes")
    if holes:
        seat["holes"] = list(holes)
        for o in holes:
            o.color = (*HOLE_COVERED_CLR, 1.0)
    rotors = moving.get("rotors")
    if rotors:
        seat["rotors"] = list(rotors)
        for o in rotors:
            o.color = (*HOLE_OPEN_CLR, 1.0)


def apply_fingering(seat, cents):
    """Put the pads (or the rotor paddles) where this pitch says they go.

    A section with a different mechanism — brass valves, a trombone slide —
    hands in its own closure instead, so its geometry stays in its own
    module while this shared driver still runs it once per frame."""
    if cents is None:
        return
    own = seat.get("fingering")
    if own:
        own(cents)
        return
    states = hole_states(hole_coverage(cents))
    for i, obj in enumerate(seat.get("holes", [])):
        open_frac = 1.0 - states[i]          # 0 covered, 1 wide open
        obj.color = (*(c + open_frac * (o - c) for c, o in
                       zip(HOLE_COVERED_CLR, HOLE_OPEN_CLR)), 1.0)
    # The horn has three rotors, not nine holes: the same coverage drives
    # how far round each paddle has swung, thirds of the octave apiece.
    pc = (cents % 1200.0) / 100.0
    for i, obj in enumerate(seat.get("rotors", [])):
        throw = min(1.0, max(0.0, pc / 4.0 - i))     # a third of the octave each
        obj.color = (*(o + throw * (c - o) for c, o in
                       zip(HOLE_COVERED_CLR, HOLE_OPEN_CLR)), 1.0)


# ── notes + animation ────────────────────────────────────────────────────────
def load_seat_notes(npy, tempo, seats):
    """{seat_id: notes} — load each seat's own voice(s) directly. (load_voices
    already filters by voice and returns 5-col notes without a voice column,
    so there's nothing to route after the fact.)"""
    if not npy:
        return {s['id']: np.zeros((0, 5)) for s in seats}
    return {s['id']: bass.load_voices(npy, tempo, s['voices']) for s in seats}


def _seat_state(t, notes):
    """(glow, playing, last_off, cents) for one seat at time t.

    cents is the pitch of the note sounding now, or of the last one that
    sounded — a rest holds the fingering rather than flapping every pad open,
    which is both what a player does and much calmer to look at."""
    glow, playing, last_off = 0.0, False, -999.0
    cents, latest = None, -1e9
    for row in notes:
        onset, dur = row[0], row[2]
        end = onset + dur
        if onset <= t and onset >= latest:
            latest, cents = onset, float(row[1])
        if onset <= t <= end:
            playing = True
            glow = 1.0
        elif t > end:
            decay = (t - end) / GLOW_DECAY
            if decay < 1.0:
                glow = max(glow, 1.0 - decay)
            last_off = max(last_off, end)
    return glow, playing, last_off, cents


def update_wind_seats(t, seats, seat_note_sets, body_clr, glow_clr, lean_deg,
                      sway_amp=SWAY_AMP_DEG):
    """Shared sway/lean/glow driver for any wind section (woodwind or brass)
    — the two differ only in their colour/lean tables, passed in here."""
    sway_alpha_in = 1.0 - math.exp(-(1.0 / FPS) / SWAY_ENV_TAU_IN)
    sway_alpha_out = 1.0 - math.exp(-(1.0 / FPS) / SWAY_ENV_TAU_OUT)
    lean_alpha = 1.0 - math.exp(-(1.0 / FPS) / LEAN_TAU)
    for s in seats:
        s.setdefault('lean_state', 0.0)
        glow, playing, last_off, cents = _seat_state(t, seat_note_sets[s['id']])
        apply_fingering(s, cents)

        # sway envelope (fade in when playing, out when silent). A seat can
        # override the amplitude (e.g. the vibraphone sets it to 0 — a struck
        # instrument shouldn't rock like a wind player).
        alpha = sway_alpha_in if playing else sway_alpha_out
        s['sway_env'] += ((1.0 if playing else 0.0) - s['sway_env']) * alpha
        amp = s.get('sway_amp', sway_amp)
        sway = amp * s['sway_env'] * math.sin(
            2 * math.pi * s['sway_freq'] * t + s['sway_phase'])

        # Playing lean toward the camera — eased BOTH ways. Previously it
        # snapped to lean_max instantly on every note onset (ease-out only),
        # so fast passages made the instrument jump. Now the lean angle glides
        # toward its target (lean_max while sounding, 0 when silent) with the
        # same exponential smoothing as the sway, so onsets tip in smoothly.
        lean_max = lean_deg[s['kind']]
        lean_target = lean_max if playing else 0.0
        s['lean_state'] += (lean_target - s['lean_state']) * lean_alpha
        lean = s['lean_state']

        # lean tips forward (top toward -Y/camera) around X; sway + a constant
        # base roll both rotate around Y (roll in the camera plane)
        roll = sway + s.get('base_roll', 0.0)
        s['empty'].rotation_euler = (math.radians(-lean), math.radians(roll), 0.0)

        base_c, tint = body_clr[s['kind']], glow_clr[s['kind']]
        col = (tuple(base_c[i] + glow * (tint[i] - base_c[i]) for i in range(3))
               if glow > 0.02 else base_c)
        for o in s['body']:
            o.color = (*col, 1.0)


def update_woodwinds(t, geom, seat_note_sets):
    update_wind_seats(t, geom['seats'], seat_note_sets, BODY_CLR, GLOW_CLR, PLAY_LEAN_DEG)


def _smoke_test(out_path):
    bass.clear_scene()
    geom = build_woodwinds(0.0)
    # tint bodies for the still
    for s in geom['seats']:
        for o in s['body']:
            o.color = (*BODY_CLR[s['kind']], 1.0)
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("Cam"); cam_data.lens = 35
    cam = bpy.data.objects.new("Cam", cam_data); scene.collection.objects.link(cam)
    cam.location = (0.0, -4.2, 1.6)
    d = mathutils.Vector((0.0, 0.0, 0.9)) - mathutils.Vector(cam.location)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    scene.camera = cam
    sun = bpy.data.lights.new("Sun", type='SUN'); sun.energy = 2.6
    so = bpy.data.objects.new("Sun", sun); so.rotation_euler = (math.radians(55), 0, math.radians(20))
    scene.collection.objects.link(so)
    w = scene.world or bpy.data.worlds.new("W"); scene.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.5
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.view_settings.view_transform = 'Standard'
    scene.render.filepath = str(Path(out_path).resolve())
    bpy.ops.render.render(write_still=True)
    print(f"[woodwind] wrote {out_path}")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--still", default="woodwind_smoke.png")
    args = p.parse_args(argv)
    _smoke_test(args.still)
