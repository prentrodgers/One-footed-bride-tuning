#!/usr/bin/env python3
"""
blender_melody_poc.py — the melody section: flute, clarinet, vibraphone
(back) and oboe, bassoon, trumpet (front), csound voices 14/13/7/15/12/25.

Reuses the woodwind clarinet/oboe/bassoon builders and the brass trumpet
builder wholesale; adds a simple silver flute and a compact vibraphone.
Static placement pass — the sway/lean/glow animation is wired the same way
the woodwind/brass sections are, once positioned.
"""
import math
import sys
from pathlib import Path

import bpy
import mathutils

REPO_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_DIR))

import blender_bass_section_poc as bass
import blender_woodwind_poc as ww
import blender_brass_poc as brass

BODY_CLR = {
    'flute':      (0.82, 0.84, 0.88),   # silver
    'clarinet':   (0.14, 0.12, 0.10),   # ebony
    'vibraphone': (0.80, 0.82, 0.86),   # aluminium bars
    'oboe':       (0.12, 0.10, 0.08),   # grenadilla
    'bassoon':    (0.50, 0.32, 0.14),   # maple
    'trumpet':    (0.82, 0.68, 0.22),   # brass
}
GLOW_CLR = {
    'flute':      (0.88, 0.92, 1.00),
    'clarinet':   (0.55, 0.65, 0.90),
    'vibraphone': (0.90, 0.95, 1.00),
    'oboe':       (0.55, 0.65, 0.90),
    'bassoon':    (0.85, 0.70, 0.45),
    'trumpet':    (1.00, 0.90, 0.50),
}
PLAY_LEAN_DEG = {'flute': 8.0, 'clarinet': 8.0, 'vibraphone': 0.0,
                 'oboe': 7.0, 'bassoon': 6.0, 'trumpet': 9.0}
SWAY_FREQS = [0.24, 0.21, 0.19, 0.26, 0.225, 0.27]
SWAY_PHASES = [0.0, 1.2, 2.4, 0.6, 1.8, 3.0]


def build_flute(body_mat):
    """A slim silver flute held horizontally: bore along X, lip plate + a row
    of keys on top, closed crown at the left end."""
    key = ww.make_solid("MelFluteKey", (0.70, 0.72, 0.76), roughness=0.3, metallic=0.7)
    z = 1.35
    bore = brass._tube((-0.48, 0.0, z), (0.46, 0.0, z), 0.024, 0.024, body_mat)
    crown = brass._tube((-0.48, 0.0, z), (-0.54, 0.0, z), 0.026, 0.026, key)
    lip = ww._ball(-0.30, z + 0.02, 0.03, key, scale=(1.4, 0.6, 1.0))
    keys = [ww._ball(kx, z + 0.028, 0.016, key, scale=(1.0, 1.0, 0.6)) for kx in
            (-0.05, 0.05, 0.15, 0.25, 0.35)]
    return [bore] + [crown, lip] + keys, [bore]


def build_vibraphone(body_mat):
    """A compact vibraphone: a short row of aluminium bars on a dark frame
    with resonator tubes hanging below."""
    frame = ww.make_solid("MelVibeFrame", (0.13, 0.13, 0.15), roughness=0.55)
    reson = ww.make_solid("MelVibeReson", (0.55, 0.56, 0.60), roughness=0.35, metallic=0.6)
    n = 13
    x0, x1, z = -0.52, 0.52, 0.80
    bars, others = [], []
    for i in range(n):
        bx = x0 + (x1 - x0) * i / (n - 1)
        blen = 0.20 - 0.06 * i / (n - 1)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx, 0.0, z))
        b = bpy.context.object
        b.scale = (0.032, blen, 0.014)
        b.data.materials.append(body_mat)
        bars.append(b)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.018, depth=0.28,
                                             location=(bx, 0.0, z - 0.20))
        t = bpy.context.object; t.data.materials.append(reson); others.append(t)
    # frame rails + legs
    for ry in (-0.09, 0.09):
        others.append(brass._tube((x0 - 0.05, ry, z + 0.01), (x1 + 0.05, ry, z + 0.01),
                                  0.012, 0.012, frame))
    for lx in (x0, x1):
        for ly in (-0.09, 0.09):
            others.append(brass._tube((lx, ly, 0.0), (lx, ly, z), 0.014, 0.014, frame))
    return bars + others, bars


BUILDERS = {
    'flute': build_flute, 'clarinet': ww.build_clarinet, 'vibraphone': build_vibraphone,
    'oboe': ww.build_oboe, 'bassoon': ww.build_bassoon, 'trumpet': brass.build_trumpet,
}

# id, kind, voice, x, y (depth), roll, scale
SEATS_SPEC = [
    ('flute',      'flute',      14, -1.7,  0.6,  0.0,  1.0),
    ('clarinet',   'clarinet',   13, -0.5,  0.7,  14.0, 1.0),
    ('vibraphone', 'vibraphone', 7,   2.3,  1.1,  0.0,  1.5),  # larger + back + right (clear of the bassoon); no tilt/sway
    ('oboe',       'oboe',       15, -1.5, -0.7,  14.0, 1.0),
    ('bassoon',    'bassoon',    12, -0.2, -0.5,  20.0, 1.0),  # tilt halved (40 -> 20)
    ('trumpet',    'trumpet',    25,  1.3, -1.05, 0.0,  1.0),  # nudged forward (-0.8 -> -1.05)
]


def build_melody(x0):
    body_mat = ww.make_body_material("MelBody")
    seats = []
    for i, (sid, kind, voice, sx, sy, roll, scale) in enumerate(SEATS_SPEC):
        all_objs, body_objs = BUILDERS[kind](body_mat)
        for o in body_objs:
            o.color = (*BODY_CLR[kind], 1.0)
        empty = bpy.data.objects.new(f"mel_{sid}", None)
        bpy.context.scene.collection.objects.link(empty)
        empty.location = (x0 + sx, sy, 0.0)
        empty.scale = (scale, scale, scale)
        empty.rotation_euler = (0.0, math.radians(roll), 0.0)
        for o in all_objs:
            if o.parent is None:
                o.parent = empty
        seat = dict(id=sid, kind=kind, voice=voice, empty=empty, body=body_objs,
                    sway_freq=SWAY_FREQS[i], sway_phase=SWAY_PHASES[i],
                    sway_env=0.0, base_roll=roll)
        if kind == 'vibraphone':
            seat['sway_amp'] = 0.0   # struck instrument — no tilt, no rock
        seats.append(seat)
    return dict(seats=seats)


def load_seat_notes(npy, tempo, seats):
    import numpy as np
    if not npy:
        return {s['id']: np.zeros((0, 5)) for s in seats}
    return {s['id']: bass.load_voices(npy, tempo, (s['voice'],)) for s in seats}


def update_melody(t, geom, seat_notes):
    ww.update_wind_seats(t, geom['seats'], seat_notes, BODY_CLR, GLOW_CLR, PLAY_LEAN_DEG)


def _smoke_test(out_path):
    bass.clear_scene()
    build_melody(0.0)
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("Cam"); cam_data.lens = 35
    cam = bpy.data.objects.new("Cam", cam_data); scene.collection.objects.link(cam)
    cam.location = (0.0, -4.2, 1.7)
    d = mathutils.Vector((0, 0, 0.9)) - mathutils.Vector(cam.location)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler(); scene.camera = cam
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
    print(f"[melody] wrote {out_path}")


if __name__ == "__main__":
    import argparse
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser(); p.add_argument("--still", default="melody_smoke.png")
    _smoke_test(p.parse_args(argv).still)
