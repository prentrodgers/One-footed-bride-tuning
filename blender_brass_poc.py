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


def _tube(p0, p1, r0, r1, mat, verts=16):
    """A (possibly tapered) tube between two arbitrary 3D points."""
    p0v, p1v = mathutils.Vector(p0), mathutils.Vector(p1)
    d = p1v - p0v
    bpy.ops.mesh.primitive_cone_add(radius1=r0, radius2=r1, depth=d.length,
                                    vertices=verts, location=(p0v + p1v) / 2.0)
    o = bpy.context.object
    o.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    o.data.materials.append(mat)
    return o


def _curve_tube(points, radius, mat, name="brtube"):
    """A round tube swept along a polyline of 3D points (for the curved
    tubing brass is full of: leadpipes, valve slides, tuning-slide U-loops)."""
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


def _uloop(a, b, bulge, radius, mat, n=12):
    """A smooth U-shaped tube from point a to point b, bowing out in the
    `bulge` direction (a half-sine) — a valve slide or tuning-slide crook."""
    a, b, bulge = mathutils.Vector(a), mathutils.Vector(b), mathutils.Vector(bulge)
    pts = []
    for k in range(n + 1):
        s = k / n
        p = a.lerp(b, s) + bulge * math.sin(math.pi * s)
        pts.append((p.x, p.y, p.z))
    return _curve_tube(pts, radius, mat)


# ── the three brass instruments (built held-up at ~player height) ─────────────
# All bores run along X so the recognisable side profile faces the camera.
def build_trumpet(body_mat):
    silver = ww.make_solid("BrTrpValve", SILVER, roughness=0.3, metallic=0.8)
    mpc_mat = ww.make_solid("BrTrpMpc", (0.72, 0.73, 0.75), roughness=0.3, metallic=0.7)
    z = 1.05
    vx = (-0.10, 0.0, 0.10)   # the three valve x positions
    # Bottom bore: mouthpiece (left) -> leadpipe -> straight through the valves.
    bore = _tube((-0.52, 0.0, z), (0.40, 0.0, z), 0.03, 0.03, body_mat)
    mpc = ww._ball(-0.55, z, 0.032, mpc_mat, scale=(1.4, 1.0, 1.0))
    # Three valve casings up + finger buttons.
    valves = [_tube((x, 0.0, z + 0.01), (x, 0.0, z + 0.21), 0.026, 0.026, silver) for x in vx]
    buttons = [ww._ball(x, z + 0.235, 0.03, silver) for x in vx]
    # Valve slides — the little U-loops hanging DOWN below each valve ("bottom
    # coils"): pressing a valve routes air through these to lengthen the tube.
    vslides = [_uloop((x - 0.022, 0.0, z), (x + 0.022, 0.0, z), (0.0, 0.0, -0.17), 0.018, body_mat)
               for x in vx]
    # Main tuning slide: a U-loop bowing right, off the end of the bore, then
    # the bell tube runs back and flares out to the right.
    tuning = _uloop((0.40, 0.0, z), (0.40, 0.0, z + 0.14), (0.20, 0.0, 0.0), 0.026, body_mat)
    bell_tube = _tube((0.40, 0.0, z + 0.14), (0.18, 0.0, z + 0.14), 0.028, 0.03, body_mat)
    bell = _tube((0.18, 0.0, z + 0.14), (0.70, 0.0, z + 0.17), 0.045, 0.20, body_mat, verts=26)
    # body = every brass-coloured (glowing) part; extras keep fixed materials
    body = [bore, bell_tube, bell, tuning] + vslides
    extras = valves + buttons + [mpc]
    return body + extras, body


def build_trombone(body_mat):
    slide = ww.make_solid("BrTbnSlide", SILVER, roughness=0.22, metallic=0.85)
    mpc_mat = ww.make_solid("BrTbnMpc", (0.72, 0.73, 0.75), roughness=0.3, metallic=0.7)
    z = 1.12
    # Long outer slide: two parallel tubes reaching right, joined by a crook.
    sl_a = _tube((-0.05, 0.0, z + 0.045), (1.15, 0.0, z + 0.045), 0.02, 0.02, slide)
    sl_b = _tube((-0.05, 0.0, z - 0.045), (1.15, 0.0, z - 0.045), 0.02, 0.02, slide)
    crook = _uloop((1.15, 0.0, z + 0.045), (1.15, 0.0, z - 0.045), (0.09, 0.0, 0.0), 0.02, slide)
    mpc = ww._ball(-0.10, z + 0.045, 0.03, mpc_mat, scale=(1.4, 1.0, 1.0))
    # Bell section (upper): tube back from the slide, a tuning-slide U-crook at
    # the far left, then the bell flares out to the right, above the slide.
    up = _tube((-0.05, 0.0, z + 0.045), (-0.05, 0.0, z + 0.20), 0.024, 0.024, body_mat)
    tuning = _uloop((-0.05, 0.0, z + 0.20), (0.10, 0.0, z + 0.24), (-0.14, 0.0, 0.06), 0.024, body_mat)
    bell_tube = _tube((0.10, 0.0, z + 0.24), (0.45, 0.0, z + 0.22), 0.028, 0.032, body_mat)
    bell = _tube((0.45, 0.0, z + 0.22), (0.86, 0.0, z + 0.20), 0.05, 0.21, body_mat, verts=26)
    braces = [_tube((0.15, 0.0, z + 0.045), (0.15, 0.0, z + 0.235), 0.008, 0.008, body_mat),
              _tube((0.55, 0.0, z + 0.045), (0.55, 0.0, z + 0.19), 0.008, 0.008, body_mat)]
    body = [up, tuning, bell_tube, bell] + braces
    extras = [sl_a, sl_b, crook, mpc]
    return body + extras, body


def build_tuba(body_mat):
    silver = ww.make_solid("BrTubaValve", SILVER, roughness=0.3, metallic=0.8)
    mpc_mat = ww.make_solid("BrTubaMpc", (0.72, 0.73, 0.75), roughness=0.3, metallic=0.7)
    # Real-tuba silhouette (side profile faces the camera): a rounded oval
    # body of wrapped tubing, a huge bell flaring UP off the top, pistons on
    # top-centre, and a leadpipe curving down from the mouthpiece.
    cx, cz = 0.10, 0.60
    rx, rz = 0.34, 0.40
    n = 30
    oval = [(cx + rx * math.cos(2 * math.pi * k / n), 0.0, cz + rz * math.sin(2 * math.pi * k / n))
            for k in range(n + 1)]
    main = _curve_tube(oval, 0.065, body_mat, name="tuba_main")
    # Valve tubes: horizontal runs stacked across the lower body (the
    # characteristic wrapped look), joined by U-crooks at alternating ends.
    vtubes = []
    for i, vz in enumerate((cz - 0.24, cz - 0.10, cz + 0.04)):
        vtubes.append(_tube((cx - 0.24, 0.0, vz), (cx + 0.26, 0.0, vz), 0.045, 0.045, body_mat))
        end_x = cx + 0.26 if i % 2 == 0 else cx - 0.24
        vtubes.append(_uloop((end_x, 0.0, vz), (end_x, 0.0, vz + 0.14),
                             (0.10 if i % 2 == 0 else -0.10, 0.0, 0.0), 0.045, body_mat))
    # Bell: a wide neck rising from the top of the body, then a big flare up.
    bell_neck = _tube((cx - 0.06, 0.0, cz + rz - 0.04), (cx - 0.12, 0.0, 1.40), 0.10, 0.13, body_mat, verts=24)
    bell = _tube((cx - 0.12, 0.0, 1.40), (cx - 0.20, 0.03, 2.00), 0.14, 0.40, body_mat, verts=32)
    # Four pistons standing up from the top-centre of the body + buttons.
    valves, buttons = [], []
    for vx in (cx - 0.02, cx + 0.08, cx + 0.18, cx + 0.28):
        valves.append(_tube((vx, -0.05, cz + 0.10), (vx, -0.05, cz + 0.34), 0.028, 0.028, silver))
        buttons.append(ww._ball(vx, cz + 0.365, 0.032, silver, y=-0.05))
    # Leadpipe curving from an upper-right mouthpiece down to the valves.
    lead = _curve_tube([(0.46, -0.06, 1.18), (0.40, -0.05, 1.02),
                        (0.34, -0.04, 0.90), (cx + 0.28, -0.05, cz + 0.30)], 0.022, body_mat)
    mpc = ww._ball(0.48, 1.20, 0.032, mpc_mat, scale=(1.2, 1.0, 1.0), y=-0.06)
    body = [main, bell_neck, bell, lead] + vtubes
    extras = valves + buttons + [mpc]
    return body + extras, body


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
        all_objs, body_objs = BUILDERS[kind](body_mat)
        for o in body_objs:
            o.color = (*BODY_CLR[kind], 1.0)
        empty = bpy.data.objects.new(f"brass_{sid}", None)
        bpy.context.scene.collection.objects.link(empty)
        empty.location = (x0 + sx, sy, 0.0)
        empty.scale = (sc, sc, sc)
        for o in all_objs:
            if o.parent is None:
                o.parent = empty
        seats.append(dict(id=sid, kind=kind, voices=voices, empty=empty,
                          body=body_objs, sway_freq=SWAY_FREQS[i],
                          sway_phase=SWAY_PHASES[i], sway_env=0.0))
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
