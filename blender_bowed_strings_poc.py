#!/usr/bin/env python3
"""
blender_bowed_strings_poc.py — the bowed (arco) string section: Violin I & II,
Viola, Cello (csound voices 17/18/19). Geometrically these are the same
violin/viola/cello bodies the pizzicato section builds, so this module
reuses blender_pizzicato_poc.build_player wholesale — it just supplies its
own four players (two violins, a viola, a cello) and the arco voices.

Placement first; per-frame string glow + bowing animation is wired the same
way the pizzicato section is, once positioned.
"""
import sys
from pathlib import Path

import numpy as np

REPO_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_DIR))

import blender_pizzicato_poc as pizz
import blender_bass_section_poc as bass

# Two violins on the outside, viola + cello inside — a small string choir.
PLAYERS = [
    dict(id=0, name='Violin I',  voice=17, inst='violin', x=-1.35),
    dict(id=1, name='Viola',     voice=18, inst='viola',  x=-0.45),
    dict(id=2, name='Cello',     voice=19, inst='cello',  x=0.55),
    dict(id=3, name='Violin II', voice=17, inst='violin', x=1.55),
]

# Player spacing is compressed toward the section centre so the (now larger)
# instruments cluster tighter and stop crowding the pizzicato section beside
# them — they stay big, just closer together.
SPREAD = 0.62


def build_bowed_strings(x0):
    string_mat = pizz.make_string_glow_material()
    geoms = {}
    for pl in PLAYERS:
        p = dict(pl)
        p['x'] = pl['x'] * SPREAD + x0
        p['_notes'] = np.zeros((0, 5))
        p['bow'] = True    # arco — every player draws a bow across the sounding string
        geoms[pl['id']] = pizz.build_player(p, string_mat)
    return dict(geoms=geoms)


def load_notes(npy, tempo):
    return None   # string animation not wired yet (placement pass)


def update_bowed_strings(t, geom, notes):
    pass


def _smoke_test(out_path):
    import bpy, math, mathutils
    bass.clear_scene()
    build_bowed_strings(0.0)
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("Cam"); cam_data.lens = 35
    cam = bpy.data.objects.new("Cam", cam_data); scene.collection.objects.link(cam)
    cam.location = (0.0, -3.6, 1.3)
    d = mathutils.Vector((0, 0, 0.4)) - mathutils.Vector(cam.location)
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
    print(f"[bowed] wrote {out_path}")


if __name__ == "__main__":
    import argparse
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser(); p.add_argument("--still", default="bowed_smoke.png")
    _smoke_test(p.parse_args(argv).still)
