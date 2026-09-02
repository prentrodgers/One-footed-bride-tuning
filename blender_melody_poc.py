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
    'bassoon':    (0.20, 0.11, 0.05),   # dark stained maple, at rest
    'trumpet':    (0.82, 0.68, 0.22),   # brass
}
GLOW_CLR = {
    'flute':      (0.88, 0.92, 1.00),
    'clarinet':   (0.55, 0.65, 0.90),
    'vibraphone': (0.90, 0.95, 1.00),
    'oboe':       (0.55, 0.65, 0.90),
    'bassoon':    (0.76, 0.55, 0.31),   # light brown while playing
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


# Vibraphone bar geometry. Bars are supported only at their vibrational
# nodes — NODE_FRAC in from each end, where the fundamental bending mode is
# stationary — so the ends and the middle stay free to ring. Nothing crosses
# over the top of the bars: a rail there would both damp them and hide them
# from the overhead shot.
VIB_N = 13
VIB_X0, VIB_X1, VIB_Z = -0.52, 0.52, 0.80
VIB_BAR_LEN_LOW, VIB_BAR_LEN_HIGH = 0.20, 0.14
VIB_BAR_THICK = 0.014
VIB_NODE_FRAC = 0.2
VIB_RAIL_DROP = 0.05     # rails run this far below the bars
# Quarter-wave tubes go as 1/f while bar length goes as 1/sqrt(f), so tube
# length tracks the SQUARE of bar length. The absolute lengths are not tuned
# to anything — the visible ramp from long to short is the whole point.
VIB_RES_LEN_LOW = 0.46


def build_vibraphone(body_mat):
    """A compact vibraphone: aluminium bars resting on felt pads at their
    nodes, over a resonator per bar whose length grows with its bar's."""
    frame = ww.make_solid("MelVibeFrame", (0.13, 0.13, 0.15), roughness=0.55)
    felt = ww.make_solid("MelVibeFelt", (0.32, 0.09, 0.11), roughness=0.9)
    reson = ww.make_solid("MelVibeReson", (0.55, 0.56, 0.60), roughness=0.35, metallic=0.6)
    span = VIB_BAR_LEN_LOW - VIB_BAR_LEN_HIGH
    half_t = VIB_BAR_THICK / 2.0
    rail_z = VIB_Z - VIB_RAIL_DROP
    bars, others, rails = [], [], ([], [])
    for i in range(VIB_N):
        f = i / (VIB_N - 1)
        bx = VIB_X0 + (VIB_X1 - VIB_X0) * f
        blen = VIB_BAR_LEN_LOW - span * f
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx, 0.0, VIB_Z))
        b = bpy.context.object
        b.scale = (0.032, blen, VIB_BAR_THICK)
        b.data.materials.append(body_mat)
        bars.append(b)

        for k, sign in enumerate((-1, 1)):
            ny = sign * blen * (0.5 - VIB_NODE_FRAC)
            rails[k].append((bx, ny, rail_z))
            bpy.ops.mesh.primitive_cylinder_add(
                radius=0.011, depth=VIB_RAIL_DROP - half_t,
                location=(bx, ny, (rail_z + VIB_Z - half_t) / 2.0))
            pad = bpy.context.object
            pad.data.materials.append(felt)
            others.append(pad)

        rlen = VIB_RES_LEN_LOW * (blen / VIB_BAR_LEN_LOW) ** 2
        rrad = 0.012 + 0.014 * (blen - VIB_BAR_LEN_HIGH) / span
        bpy.ops.mesh.primitive_cylinder_add(
            radius=rrad, depth=rlen,
            location=(bx, 0.0, VIB_Z - half_t - 0.02 - rlen / 2.0))
        t = bpy.context.object
        t.data.materials.append(reson)
        others.append(t)

    # Two rails threaded through the node points — they taper inward as the
    # bars shorten — each carried on a leg at either end.
    for pts in rails:
        run = ([(VIB_X0 - 0.06, pts[0][1], rail_z)] + pts
               + [(VIB_X1 + 0.06, pts[-1][1], rail_z)])
        others.append(ww._curve_tube(run, 0.010, frame, name="MelVibeRail"))
        for lx, ly, _ in (run[0], run[-1]):
            others.append(brass._tube((lx, ly, 0.0), (lx, ly, rail_z), 0.014, 0.014, frame))
    return bars + others, bars


BUILDERS = {
    'flute': build_flute, 'clarinet': ww.build_clarinet, 'vibraphone': build_vibraphone,
    'oboe': ww.build_oboe, 'bassoon': ww.build_bassoon, 'trumpet': brass.build_trumpet,
}

# id, kind, voice, x, y (depth), roll, scale
SEATS_SPEC = [
    ('flute',      'flute',      14, -1.7,  0.6,  0.0,  1.0),
    ('clarinet',   'clarinet',   13, -1.05, 0.7,  14.0, 1.0),  # pulled left, in under the flute
    ('vibraphone', 'vibraphone', 7,   2.5,  1.1,  0.0,  2.0),  # enlarged 1.5 -> 2.0, shifted right to keep the bassoon clear
    ('oboe',       'oboe',       15, -2.1, -0.7,  14.0, 1.0),  # under the flute, clear of the clarinet
    ('bassoon',    'bassoon',    12, -0.2, -0.5,  20.0, 1.0),  # tilt halved (40 -> 20)
    ('trumpet',    'trumpet',    25,  1.3, -1.9,  0.0,  1.0),  # further forward (-1.05 -> -1.9)
]


def build_melody(x0):
    metal_mat = ww.make_body_material("MelBodyMetal")
    wood_mat = ww.make_body_material("MelBodyWood", metallic=0.0, roughness=0.45)
    seats = []
    for i, (sid, kind, voice, sx, sy, roll, scale) in enumerate(SEATS_SPEC):
        # Silver flute, aluminium vibraphone bars and brass trumpet take the
        # metal response; the clarinet, oboe and bassoon are wood.
        body_mat = metal_mat if kind in ww.METAL_KINDS else wood_mat
        built = BUILDERS[kind](body_mat)
        all_objs, body_objs = built[0], built[1]
        moving = built[2] if len(built) > 2 else {}
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
        # These are the woodwind and brass builders, so the same pitch
        # mechanisms come free here — and this is the front row, where they
        # are most likely to be seen.
        if moving.get("valves") or moving.get("slide"):
            brass.arm_pitch_mechanism(seat, moving)
        else:
            ww._arm_fingering(seat, moving)
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
