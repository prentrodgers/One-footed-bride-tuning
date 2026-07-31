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
    'bassoon':  (0.50, 0.32, 0.14),   # maple
}
GLOW_CLR = {
    'clarinet': (0.55, 0.65, 0.90),
    'oboe':     (0.55, 0.65, 0.90),
    'horn':     (1.00, 0.88, 0.40),
    'bassoon':  (0.85, 0.70, 0.45),
}
SILVER = (0.72, 0.74, 0.78)
REED_CLR = (0.62, 0.55, 0.35)

GLOW_DECAY = 0.55
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


# ── the four instruments ─────────────────────────────────────────────────────
# Each returns (all_objs, body_objs): body_objs are the ones whose colour is
# animated (glow); all_objs get parented to the seat empty for sway/lean.
def build_clarinet(body_mat):
    silver = make_solid("WWClarKey", SILVER, roughness=0.3, metallic=0.7)
    body = [
        _cone(0.00, 0.16, 0.095, 0.055, body_mat),   # flared bell
        _cone(0.16, 1.45, 0.050, 0.042, body_mat),   # long body
        _cone(1.45, 1.60, 0.036, 0.028, body_mat),   # barrel
    ]
    mp = _cone(1.60, 1.72, 0.026, 0.014, body_mat)   # mouthpiece
    body.append(mp)
    keys = [_ball(0.035, z, 0.018, silver, y=-0.05, scale=(1, 0.5, 1))
            for z in (0.45, 0.62, 0.80, 0.98, 1.16)]
    return body + keys, body


def build_oboe(body_mat):
    silver = make_solid("WWOboeKey", SILVER, roughness=0.3, metallic=0.7)
    reed = make_solid("WWReed", REED_CLR, roughness=0.6)
    body = [
        _cone(0.00, 0.14, 0.075, 0.045, body_mat),   # small bell
        _cone(0.14, 1.35, 0.030, 0.050, body_mat),   # conical body (widens upward)
    ]
    r = _cone(1.35, 1.50, 0.018, 0.006, reed)        # double-reed staple
    keys = [_ball(0.032, z, 0.015, silver, y=-0.045, scale=(1, 0.5, 1))
            for z in (0.40, 0.58, 0.76, 0.94, 1.12)]
    return body + [r] + keys, body


def build_bassoon(body_mat):
    metal = make_solid("WWBocal", SILVER, roughness=0.3, metallic=0.75)
    reed = make_solid("WWBsnReed", REED_CLR, roughness=0.6)
    # Doubled bore: the tall bass/bell joint (left) and the shorter wing joint
    # (right), joined at the boot (double joint) U-bend at the bottom.
    bass = _cone(0.10, 1.90, 0.070, 0.048, body_mat, x=-0.07)
    bell = _cone(1.90, 2.10, 0.052, 0.078, body_mat, x=-0.07)      # bell joint + flare
    bell_ring = _torus(-0.07, 2.09, 0.078, 0.010, metal)          # metal bell ring
    wing = _cone(0.10, 1.68, 0.062, 0.050, body_mat, x=0.07)
    boot = _ball(0.0, 0.10, 0.11, body_mat, scale=(1.7, 0.85, 0.5))
    body = [bass, bell, wing, boot]
    # Bocal (crook): a slender S-curved metal tube off the top of the wing
    # joint that hooks up and back toward the player's reed.
    bocal = _curve_tube([(0.07, 0.0, 1.68), (0.11, -0.05, 1.80),
                         (0.10, -0.13, 1.90), (0.02, -0.18, 1.95)], 0.009, metal)
    reed_o = _cone_dir((0.02, -0.18, 1.95), (-0.02, -0.21, 1.99), 0.008, 0.004, reed)
    return body + [bell_ring, bocal, reed_o], body


def build_horn(body_mat):
    # French horn: concentric coiled tubing, a big flared bell off the
    # lower-left, a curved leadpipe up to a funnel mouthpiece, valve rotors.
    silver = make_solid("WWHornValve", SILVER, roughness=0.3, metallic=0.75)
    coils = [_torus(0.0, 0.92, r, 0.032, body_mat) for r in (0.36, 0.29, 0.22)]
    # Big flared bell pointing down and to the left (the horn's signature).
    bpy.ops.mesh.primitive_cone_add(radius1=0.34, radius2=0.055, depth=0.52,
                                    vertices=30, location=(-0.52, 0.06, 0.55))
    bell = bpy.context.object
    bell.rotation_euler = (math.radians(78), 0, math.radians(38))
    bell.data.materials.append(body_mat)
    # Curved leadpipe sweeping up to a funnel mouthpiece at the top-right.
    lead = _curve_tube([(0.20, 0.0, 1.20), (0.30, -0.03, 1.32),
                        (0.34, -0.05, 1.44), (0.33, -0.06, 1.54)], 0.018, body_mat)
    mpc = _cone_dir((0.33, -0.06, 1.54), (0.34, -0.07, 1.66), 0.016, 0.032, silver)
    rotors = [_torus(vx, 0.92, 0.06, 0.03, silver) for vx in (-0.06, 0.06)]
    body = coils + [bell, lead]
    return body + [mpc] + rotors, body


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
        all_objs, body_objs = BUILDERS[kind](body_mat)
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
        seats.append(dict(id=sid, kind=kind, voices=voices, empty=empty,
                          body=body_objs, sway_freq=SWAY_FREQS[i],
                          sway_phase=SWAY_PHASES[i], sway_env=0.0,
                          base_roll=roll))
    return dict(seats=seats)


# ── notes + animation ────────────────────────────────────────────────────────
def load_seat_notes(npy, tempo, seats):
    """{seat_id: notes} — load each seat's own voice(s) directly. (load_voices
    already filters by voice and returns 5-col notes without a voice column,
    so there's nothing to route after the fact.)"""
    if not npy:
        return {s['id']: np.zeros((0, 5)) for s in seats}
    return {s['id']: bass.load_voices(npy, tempo, s['voices']) for s in seats}


def _seat_state(t, notes):
    glow, playing, last_off = 0.0, False, -999.0
    for row in notes:
        onset, dur = row[0], row[2]
        end = onset + dur
        if onset <= t <= end:
            playing = True
            glow = 1.0
        elif t > end:
            decay = (t - end) / GLOW_DECAY
            if decay < 1.0:
                glow = max(glow, 1.0 - decay)
            last_off = max(last_off, end)
    return glow, playing, last_off


def update_wind_seats(t, seats, seat_note_sets, body_clr, glow_clr, lean_deg,
                      sway_amp=SWAY_AMP_DEG):
    """Shared sway/lean/glow driver for any wind section (woodwind or brass)
    — the two differ only in their colour/lean tables, passed in here."""
    sway_alpha_in = 1.0 - math.exp(-(1.0 / FPS) / SWAY_ENV_TAU_IN)
    sway_alpha_out = 1.0 - math.exp(-(1.0 / FPS) / SWAY_ENV_TAU_OUT)
    lean_alpha = 1.0 - math.exp(-(1.0 / FPS) / LEAN_TAU)
    for s in seats:
        s.setdefault('lean_state', 0.0)
        glow, playing, last_off = _seat_state(t, seat_note_sets[s['id']])

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
