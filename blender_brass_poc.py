#!/usr/bin/env python3
"""
blender_brass_poc.py — 4 invisible brass players as a Blender stage section,
porting brass_section_poc.py (matplotlib) to 3D.

Seats:
  back  : Trombone (voice 26), Tuba (voice 27)
  front : Trumpet I, Trumpet II (both voice 25)

Same static-silhouette + idle-sway + playing-lean + body-glow language as
the woodwinds — the sway/lean/glow driver, note routing, geometry helpers
and materials are all reused from blender_woodwind_poc; this module only
adds the three brass instrument shapes and the brass colour/lean tables.

Standalone smoke test:
    blender --background --python blender_brass_poc.py -- --still out.png
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

import blender_bass_section_poc as bass
import blender_woodwind_poc as ww

VOICE_TRUMPET, VOICE_TROMBONE, VOICE_TUBA = 25, 26, 27

BRASS = (0.82, 0.68, 0.22)
SILVER = (0.74, 0.76, 0.80)
BODY_CLR = {'trumpet': BRASS, 'trombone': BRASS, 'tuba': BRASS}
GLOW_CLR = {
    'trumpet':  (1.00, 0.90, 0.50),
    'trombone': (1.00, 0.85, 0.42),
    'tuba':     (1.00, 0.82, 0.35),
}
PLAY_LEAN_DEG = {'trumpet': 10.0, 'trombone': 8.0, 'tuba': 5.0}
SWAY_AMP_DEG = 0.5   # ~10% of the old ±5° — a faint breath, not a big idle rock
SWAY_FREQS = [0.24, 0.21, 0.27, 0.255]
SWAY_PHASES = [0.5, 1.7, 0.0, 2.1]

# ── showing pitch, not just "sounding" ──────────────────────────────────────
# Same problem the woodwinds had: glow and sway say WHEN, never WHAT. Brass
# has no tone holes, so the pitch class is spelled by the mechanism each
# instrument actually has.
#
#   valves   the three (four, on the tuba) pistons go down in turn as the
#            pitch class rises — a thermometer, not a real fingering chart.
#            All up is C; all down is the top of the octave.
#   slide    the trombone's outer slide runs out as the pitch class rises,
#            closed at C. A real player moves it the other way (further out
#            is LOWER), but reversing it here keeps the travel monotonic, so
#            a rising line reads as one continuous movement instead of
#            snapping back to first position every semitone.
#
# Both are continuous in cents, so a note between two semitones sits between
# two positions — which is the point, in this tuning.
# The travel alone is a handful of pixels at stage framing, so a pressed
# piston also darkens — the same language the woodwind pads use, where dark
# means "this one is down".
VALVE_TRAVEL = 0.040     # m a piston sinks when fully pressed
VALVE_UP_CLR = (0.93, 0.94, 0.97)
VALVE_DOWN_CLR = (0.07, 0.065, 0.06)
SLIDE_TRAVEL = 0.45      # m from closed to fully out


def _tube(p0, p1, r0, r1, mat, verts=24):
    """A (possibly tapered) tube between two arbitrary 3D points."""
    p0v, p1v = mathutils.Vector(p0), mathutils.Vector(p1)
    d = p1v - p0v
    bpy.ops.mesh.primitive_cone_add(radius1=r0, radius2=r1, depth=d.length,
                                    vertices=verts, location=(p0v + p1v) / 2.0)
    o = bpy.context.object
    o.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    o.data.materials.append(mat)
    return ww._smooth(o)


def _curve_tube(points, radius, mat, name="brtube"):
    """A round tube swept along a polyline of 3D points (for the curved
    tubing brass is full of: leadpipes, valve slides, tuning-slide U-loops)."""
    cu = bpy.data.curves.new(name, 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = radius
    cu.bevel_resolution = 6
    sp = cu.splines.new('POLY')
    sp.points.add(len(points) - 1)
    for i, (x, y, z) in enumerate(points):
        sp.points[i].co = (x, y, z, 1.0)
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def _uloop(a, b, bulge, radius, mat, n=16):
    """A smooth U-shaped tube from point a to point b, bowing out in the
    `bulge` direction (a half-sine) — a valve slide or tuning-slide crook."""
    a, b, bulge = mathutils.Vector(a), mathutils.Vector(b), mathutils.Vector(bulge)
    pts = []
    for k in range(n + 1):
        s = k / n
        p = a.lerp(b, s) + bulge * math.sin(math.pi * s)
        pts.append((p.x, p.y, p.z))
    return _curve_tube(pts, radius, mat)


def _bell(p0, p1, r0, r1, mat, power=3.0, name="brbell"):
    """A bell with a real flare profile and a garland ring at the mouth."""
    bell = ww._flare(p0, p1, r0, r1, mat, power=power, name=name)
    axis = mathutils.Vector(p1) - mathutils.Vector(p0)
    garland = ww._torus(0.0, 0.0, r1, r1 * 0.025, mat)
    garland.location = p1
    garland.rotation_euler = axis.to_track_quat('Z', 'Y').to_euler()
    return bell, garland


def _mouthpiece(tip, back, mat):
    """Cup at `tip` (the player's end) tapering to the receiver at `back`."""
    cup = ww._cone_dir(tip, back, 0.022, 0.011, mat, verts=20)
    rim = ww._torus(0.0, 0.0, 0.020, 0.005, mat)
    rim.location = tip
    rim.rotation_euler = (mathutils.Vector(back) - mathutils.Vector(tip)).to_track_quat('Z', 'Y').to_euler()
    return [cup, rim]


def _pistons(xs, y, z_top, mat, pad_mat, stem_h=0.045, r_button=0.024):
    """Valve buttons on stems above the casings' tops; the buttons are the
    pitch indicators the stage presses (see arm_pitch_mechanism)."""
    stems = [_tube((x, y, z_top), (x, y, z_top + stem_h), 0.006, 0.006, mat) for x in xs]
    buttons = [ww._ball(x, z_top + stem_h + r_button * 0.5, r_button, pad_mat, y=y, scale=(1, 1, 0.45))
               for x in xs]
    return stems, buttons


# ── the three brass instruments (built held-up at ~player height) ─────────────
# All bores run along X so the recognisable side profile faces the camera.
def valve_throws(cents, n):
    """How far each of `n` pistons is pressed, 0..1, first one first."""
    total = ((cents % 1200.0) / 1200.0) * n
    return [min(1.0, max(0.0, total - i)) for i in range(n)]


def arm_pitch_mechanism(seat, moving):
    """Give a seat the closure that shows its pitch — pistons or slide."""
    if moving.get("valves"):
        objs = moving["valves"]
        rest = [tuple(o.location) for o in objs]

        def press(cents, objs=objs, rest=rest):
            for o, r, d in zip(objs, rest, valve_throws(cents, len(objs))):
                o.location = (r[0], r[1], r[2] - VALVE_TRAVEL * d)
                o.color = (*(u + d * (dn - u) for u, dn in
                             zip(VALVE_UP_CLR, VALVE_DOWN_CLR)), 1.0)
        seat["fingering"] = press
        for o in objs:
            o.color = (*VALVE_UP_CLR, 1.0)
    elif moving.get("slide"):
        objs = moving["slide"]
        rest = [tuple(o.location) for o in objs]

        def extend(cents, objs=objs, rest=rest):
            out = SLIDE_TRAVEL * ((cents % 1200.0) / 1200.0)
            for o, r in zip(objs, rest):
                o.location = (r[0] + out, r[1], r[2])
        seat["fingering"] = extend


def build_trumpet(body_mat):
    """Laid out from Trumpet.jpg, mouthpiece left, bell right: the leadpipe
    runs right along the middle into the main tuning slide (the crook at
    the front, under the bell), back along the bottom into the valves,
    and out of the first valve to the rear bow at the left, which turns
    up into the bell tube along the top. First and third valve slides lie
    flat at the bottom, the second hangs down."""
    silver = ww.make_solid("BrTrpValve", SILVER, roughness=0.3, metallic=0.8)
    mpc_mat = ww.make_solid("BrTrpMpc", (0.72, 0.73, 0.75), roughness=0.3, metallic=0.7)
    z0 = 1.05
    z_top, z_lead, z_bot = z0 + 0.085, z0 + 0.025, z0 - 0.065
    vx = (-0.10, 0.0, 0.10)
    r_tube = 0.015
    lead = _tube((-0.50, 0.0, z_lead), (0.36, 0.0, z_lead), 0.011, 0.015, body_mat)
    mpc = _mouthpiece((-0.58, 0.0, z_lead), (-0.50, 0.0, z_lead), mpc_mat)
    tuning = _uloop((0.36, 0.0, z_lead), (0.36, 0.0, z_bot), (0.14, 0.0, 0.0), r_tube, body_mat)
    bottom = _tube((0.36, 0.0, z_bot), (-0.10, 0.0, z_bot), r_tube, r_tube, body_mat)
    rear = _tube((-0.10, 0.0, z_bot), (-0.38, 0.0, z_bot), r_tube, r_tube, body_mat)
    bow = _uloop((-0.38, 0.0, z_bot), (-0.38, 0.0, z_top), (-0.11, 0.0, 0.0), r_tube, body_mat)
    bell_tube = _tube((-0.38, 0.0, z_top), (0.30, 0.0, z_top), 0.016, 0.022, body_mat)
    bell, garland = _bell((0.30, 0.0, z_top), (0.80, 0.0, z_top), 0.022, 0.17, body_mat, name="trumpet_bell")
    casings = [_tube((x, 0.0, z_bot - 0.03), (x, 0.0, z0 + 0.07), 0.025, 0.025, silver) for x in vx]
    stems, buttons = _pistons(vx, 0.0, z0 + 0.07, silver, ww.make_pad_material())
    vslides = [
        _uloop((vx[0] - 0.02, 0.0, z_bot + 0.028), (vx[0] - 0.02, 0.0, z_bot - 0.028), (-0.17, 0.0, 0.0), 0.012, body_mat),
        _uloop((vx[1] - 0.018, 0.0, z_bot - 0.02), (vx[1] + 0.018, 0.0, z_bot - 0.02), (0.0, 0.0, -0.10), 0.012, body_mat),
        _uloop((vx[2] + 0.02, 0.0, z_bot + 0.028), (vx[2] + 0.02, 0.0, z_bot - 0.028), (0.20, 0.0, 0.0), 0.012, body_mat),
    ]
    ring = ww._torus(0.26, z_bot - 0.045, 0.022, 0.004, body_mat)     # third-valve slide ring
    braces = [_tube((0.20, 0.0, z_lead), (0.20, 0.0, z_top), 0.005, 0.005, body_mat),
              _tube((-0.30, 0.0, z_bot), (-0.30, 0.0, z_top), 0.005, 0.005, body_mat)]
    body = [lead, tuning, bottom, rear, bow, bell_tube, bell, garland, ring] + vslides + braces
    extras = casings + stems + buttons + mpc
    return body + extras, body, {"valves": buttons}


def build_trombone(body_mat):
    """From trombone.webp: the slide runs right along the bottom, the bell
    section above it. The lower slide tube runs left past the mouthpiece
    and turns up in ONE continuous curve — through the tuning-slide crook
    at the instrument's left edge — into the top tube, which runs right
    to the bell. Two slide braces sit between the mouthpiece and the
    slide's long run (one on the inner slide, one the outer slide's
    grip); two bell braces tie the top tube down to the slide."""
    slide = ww.make_solid("BrTbnSlide", SILVER, roughness=0.22, metallic=0.85)
    mpc_mat = ww.make_solid("BrTbnMpc", (0.72, 0.73, 0.75), roughness=0.3, metallic=0.7)
    z0 = 1.12
    za, zb = z0 + 0.045, z0 - 0.045          # the two slide tubes
    z_hi = z0 + 0.24                         # the bell section's top tube
    # Inner slide: fixed, from the mouthpiece receiver.
    # It reaches left so the mouthpiece tip lines up with the crook: the
    # slide is the full length of the instrument.
    inner = [_tube((-0.32, 0.0, za), (0.62, 0.0, za), 0.013, 0.013, slide),
             _tube((-0.32, 0.0, zb), (0.62, 0.0, zb), 0.013, 0.013, slide),
             _tube((-0.25, 0.0, zb), (-0.25, 0.0, za), 0.006, 0.006, slide)]   # inner slide brace
    # Outer slide: what the pitch moves.
    sl_a = _tube((-0.05, 0.0, za), (1.15, 0.0, za), 0.017, 0.017, slide)
    sl_b = _tube((-0.05, 0.0, zb), (1.15, 0.0, zb), 0.017, 0.017, slide)
    crook = _uloop((1.15, 0.0, za), (1.15, 0.0, zb), (0.09, 0.0, 0.0), 0.017, slide)
    grip = _tube((-0.03, 0.0, zb), (-0.03, 0.0, za), 0.006, 0.006, slide)       # outer slide brace
    bumper = ww._ball(1.24, z0, 0.014, ww.make_solid("BrTbnBumper", (0.05, 0.05, 0.05), roughness=0.6))
    mpc = _mouthpiece((-0.41, 0.0, za), (-0.32, 0.0, za), mpc_mat)
    # Bell section: one smooth run from the lower slide tube, up round the
    # crook at the left edge, into the top tube.
    bend = _curve_tube(ww._smooth_points([(-0.24, 0.0, zb), (-0.32, 0.0, zb), (-0.39, 0.0, zb + 0.03),
                                          (-0.43, 0.0, z0 + 0.05), (-0.43, 0.0, z0 + 0.14),
                                          (-0.39, 0.0, z_hi - 0.03), (-0.31, 0.0, z_hi), (-0.22, 0.0, z_hi)], 8),
                       0.015, body_mat, name="tbn_bend")
    weight = ww._ball(-0.46, z0 + 0.10, 0.035, ww.make_solid("BrTbnWeight", (0.06, 0.06, 0.06), roughness=0.5),
                      scale=(0.5, 1.0, 1.0))
    upper = _tube((-0.22, 0.0, z_hi), (0.30, 0.0, z_hi), 0.015, 0.024, body_mat)
    bell, garland = _bell((0.30, 0.0, z_hi), (0.84, 0.0, z_hi), 0.024, 0.19, body_mat, name="tbn_bell")
    braces = [_tube((-0.12, 0.0, za), (-0.12, 0.0, z_hi), 0.006, 0.006, body_mat),
              _tube((0.12, 0.0, za), (0.12, 0.0, z_hi), 0.006, 0.006, body_mat)]
    body = [bend, upper, bell, garland] + braces
    extras = inner + [sl_a, sl_b, crook, grip, bumper, weight] + mpc
    return body + extras, body, {"slide": [sl_a, sl_b, crook, grip, bumper]}


def build_tuba(body_mat):
    """From tuba.webp, side on, bell up-left: the main tube wraps in a big
    oval with a second branch inside it, the bell rises off the top-left
    and flares, four pistons stand at the front with their valve slides
    looping below, the leadpipe curls down from the mouthpiece at the top
    to the first valve, and the main tuning slide sticks out on the right."""
    silver = ww.make_solid("BrTubaValve", SILVER, roughness=0.3, metallic=0.8)
    mpc_mat = ww.make_solid("BrTubaMpc", (0.72, 0.73, 0.75), roughness=0.3, metallic=0.7)
    cx, cz = 0.10, 0.80          # the wrap's bottom, and the valve slides under it, clear the floor
    rx, rz = 0.34, 0.38
    n = 64
    oval = [(cx + rx * math.cos(2 * math.pi * k / n), 0.0, cz + rz * math.sin(2 * math.pi * k / n))
            for k in range(n + 1)]
    main = _curve_tube(oval, 0.060, body_mat, name="tuba_main")
    inner = [(cx + 0.02 + 0.22 * math.cos(2 * math.pi * k / n), 0.045, cz - 0.02 + 0.25 * math.sin(2 * math.pi * k / n))
             for k in range(n + 1)]
    branch = _curve_tube(inner, 0.042, body_mat, name="tuba_branch")
    tuning = _uloop((cx + rx, 0.0, cz + 0.07), (cx + rx, 0.0, cz - 0.07), (0.13, 0.0, 0.0), 0.045, body_mat)
    # Bell: a conical stem off the top-left of the wrap, then the flare.
    stem = _tube((cx - 0.12, 0.0, cz + rz - 0.06), (cx - 0.24, 0.0, 1.46), 0.070, 0.105, body_mat)
    bell, garland = _bell((cx - 0.24, 0.0, 1.46), (cx - 0.40, 0.05, 2.02), 0.105, 0.40, body_mat,
                          power=2.6, name="tuba_bell")
    # Valve cluster at the front.
    vy = -0.075
    vxs = (cx - 0.08, cx + 0.03, cx + 0.14, cx + 0.25)
    z_cas0, z_cas1 = cz - 0.10, cz + 0.12
    casings = [_tube((x, vy, z_cas0), (x, vy, z_cas1), 0.028, 0.028, silver) for x in vxs]
    knuckle = _tube((vxs[0] - 0.05, vy, cz + 0.01), (vxs[-1] + 0.05, vy, cz + 0.01), 0.022, 0.022, body_mat)
    stems, buttons = _pistons(vxs, vy, z_cas1, silver, ww.make_pad_material(), stem_h=0.05, r_button=0.03)
    vslides = []
    for i, x in enumerate(vxs):
        h = (0.15, 0.10, 0.19, 0.23)[i]
        vslides.append(_uloop((x - 0.022, vy, z_cas0), (x + 0.022, vy, z_cas0), (0.0, 0.0, -h), 0.020, body_mat))
    # Leadpipe from the mouthpiece at the top down the front to the first valve.
    lead = _curve_tube(ww._smooth_points([(0.40, -0.05, 1.46), (0.44, -0.06, 1.30), (0.38, -0.08, 1.10),
                                          (vxs[0] - 0.02, vy, z_cas1 + 0.02)], 8), 0.018, body_mat,
                       name="tuba_leadpipe")
    mpc = _mouthpiece((0.36, -0.045, 1.54), (0.40, -0.05, 1.46), mpc_mat)
    body = [main, branch, tuning, stem, bell, garland, knuckle, lead] + vslides
    extras = casings + stems + buttons + mpc
    return body + extras, body, {"valves": buttons}


BUILDERS = {'trumpet': build_trumpet, 'trombone': build_trombone, 'tuba': build_tuba}

# Staggered so no seat sits directly in front of another (the tuba used to
# overlap the front-right trumpet): back pair on the outside, the two
# trumpets tucked into the middle-front.
SEATS_SPEC = [
    # id, kind, voices, x, y (depth), scale
    # Trombone / trumpet / trumpet stacked in one vertical column (same x,
    # back-to-front in y, which reads top-to-bottom in the elevated view);
    # the tuba stands alone beside the column, scaled up to match the
    # column's overall height.
    ('trombone', 'trombone', (VOICE_TROMBONE,), -1.1,  2.2, 1.56),  # top; a real trombone dwarfs a trumpet
    ('trumpet1', 'trumpet',  (VOICE_TRUMPET,),  -1.05, 0.0, 1.0),  # middle
    ('trumpet2', 'trumpet',  (VOICE_TRUMPET,),  -1.05, -1.6, 1.0),  # bottom
    ('tuba',     'tuba',     (VOICE_TUBA,),     -3.0,  0.0, 1.8),  # left of the column, tucked in beside it
]


def build_brass(x0):
    body_mat = ww.make_body_material("BrBody")
    seats = []
    for i, (sid, kind, voices, sx, sy, sc) in enumerate(SEATS_SPEC):
        built = BUILDERS[kind](body_mat)
        all_objs, body_objs = built[0], built[1]
        moving = built[2] if len(built) > 2 else {}
        for o in body_objs:
            o.color = (*BODY_CLR[kind], 1.0)
        empty = bpy.data.objects.new(f"brass_{sid}", None)
        bpy.context.scene.collection.objects.link(empty)
        empty.location = (x0 + sx, sy, 0.0)
        empty.scale = (sc, sc, sc)
        for o in all_objs:
            if o.parent is None:
                o.parent = empty
        seat = dict(id=sid, kind=kind, voices=voices, empty=empty,
                    body=body_objs, sway_freq=SWAY_FREQS[i],
                    sway_phase=SWAY_PHASES[i], sway_env=0.0)
        arm_pitch_mechanism(seat, moving)
        seats.append(seat)
    return dict(seats=seats)


def load_seat_notes(npy, tempo, seats):
    return ww.load_seat_notes(npy, tempo, seats)


def update_brass(t, geom, seat_note_sets):
    ww.update_wind_seats(t, geom['seats'], seat_note_sets, BODY_CLR, GLOW_CLR,
                         PLAY_LEAN_DEG, SWAY_AMP_DEG)


def _smoke_test(out_path):
    bass.clear_scene()
    geom = build_brass(0.0)
    for s in geom['seats']:
        for o in s['body']:
            o.color = (*BODY_CLR[s['kind']], 1.0)
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("Cam"); cam_data.lens = 35
    cam = bpy.data.objects.new("Cam", cam_data); scene.collection.objects.link(cam)
    cam.location = (0.0, -4.4, 1.5)
    d = mathutils.Vector((0.0, 0.0, 1.0)) - mathutils.Vector(cam.location)
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
    print(f"[brass] wrote {out_path}")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--still", default="brass_smoke.png")
    args = p.parse_args(argv)
    _smoke_test(args.still)
