#!/usr/bin/env python3
"""
blender_conductor_poc.py — the invisible conductor: a podium with a music
stand and a large white baton held up at an angle. Ports
conductor_section_poc.py to 3D. Placement first; the beat-pointing baton
animation (down/left/right/up on beats) comes once it's positioned.
"""
import math
import sys
from pathlib import Path

import bpy
import mathutils

REPO_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_DIR))

import blender_bass_section_poc as bass


def _tube(p0, p1, r0, r1, mat, verts=16):
    p0v, p1v = mathutils.Vector(p0), mathutils.Vector(p1)
    d = p1v - p0v
    bpy.ops.mesh.primitive_cone_add(radius1=r0, radius2=r1, depth=d.length,
                                    vertices=verts, location=(p0v + p1v) / 2.0)
    o = bpy.context.object
    o.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    o.data.materials.append(mat)
    return o


def build_conductor(x0=0.0):
    dark = bass.make_solid_material("CondDark", (0.07, 0.07, 0.09), roughness=0.6)
    white = bass.make_solid_material("CondBaton", (0.95, 0.95, 0.92), roughness=0.4)
    cork = bass.make_solid_material("CondCork", (0.12, 0.10, 0.08), roughness=0.75)
    objs = []

    # Podium base + post
    bpy.ops.mesh.primitive_cylinder_add(radius=0.36, depth=0.10, location=(x0, 0.0, 0.05))
    base = bpy.context.object; base.data.materials.append(dark); objs.append(base)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=1.05, location=(x0, 0.0, 0.58))
    post = bpy.context.object; post.data.materials.append(dark); objs.append(post)
    # Angled music-stand plate
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x0, -0.14, 1.12))
    plate = bpy.context.object
    plate.scale = (0.30, 0.19, 0.02)
    plate.rotation_euler = (math.radians(62), 0, 0)
    plate.data.materials.append(dark); objs.append(plate)

    # Baton on a pivot at the conductor's hand, so it can swing to the beat.
    # The stick is built pointing straight up (+Z) from the pivot; update_
    # conductor rotates the pivot to aim it down / left / right / up.
    hand = (x0 - 0.05, -0.42, 1.35)
    pivot = bpy.data.objects.new("cond_pivot", None)
    bpy.context.scene.collection.objects.link(pivot)
    pivot.location = hand
    bpy.ops.mesh.primitive_cone_add(radius1=0.017, radius2=0.004, depth=0.62,
                                    location=(hand[0], hand[1], hand[2] + 0.31))
    stick = bpy.context.object; stick.data.materials.append(white)
    stick.parent = pivot; stick.matrix_parent_inverse = pivot.matrix_world.inverted()
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.045, location=hand)
    knob = bpy.context.object; knob.data.materials.append(cork)
    knob.parent = pivot; knob.matrix_parent_inverse = pivot.matrix_world.inverted()
    objs += [stick, knob]

    return dict(objs=objs, pivot=pivot)


# ── stage-section hooks ──────────────────────────────────────────────────────
def build_conductor_section(x0):
    return build_conductor(x0)


# 4/4 beat pattern: the baton tip aims down (ictus), left, right, up.
BEAT_DIRS = {
    0: (0.0, -0.55, -0.75),   # down / downbeat
    1: (-0.85, -0.50, 0.25),  # left
    2: (0.85, -0.50, 0.25),   # right
    3: (0.0, -0.45, 0.92),    # up
}


def update_conductor(t, geom, tempo, state):
    """Aim the baton at the current beat's direction, easing toward it each
    frame for a quick preparatory flick (4 chords per beat -> beat = t*bpm/60)."""
    if tempo is None:
        return
    beat = int(t * tempo / 60.0) % 4
    tgt = mathutils.Vector(BEAT_DIRS[beat]).normalized()
    cur = mathutils.Vector(state['dir']).lerp(tgt, 0.28)
    if cur.length > 1e-6:
        cur.normalize()
    state['dir'] = [cur.x, cur.y, cur.z]
    geom['pivot'].rotation_euler = cur.to_track_quat('Z', 'Y').to_euler()


def _smoke_test(out_path):
    bass.clear_scene()
    build_conductor(0.0)
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("Cam"); cam_data.lens = 40
    cam = bpy.data.objects.new("Cam", cam_data); scene.collection.objects.link(cam)
    cam.location = (1.4, -3.2, 1.6)
    d = mathutils.Vector((0, -0.4, 1.1)) - mathutils.Vector(cam.location)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler(); scene.camera = cam
    sun = bpy.data.lights.new("Sun", type='SUN'); sun.energy = 2.6
    so = bpy.data.objects.new("Sun", sun); so.rotation_euler = (math.radians(55), 0, math.radians(20))
    scene.collection.objects.link(so)
    w = scene.world or bpy.data.worlds.new("W"); scene.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.5
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x, scene.render.resolution_y = 1000, 800
    scene.view_settings.view_transform = 'Standard'
    scene.render.filepath = str(Path(out_path).resolve())
    bpy.ops.render.render(write_still=True)
    print(f"[conductor] wrote {out_path}")


if __name__ == "__main__":
    import argparse
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser(); p.add_argument("--still", default="conductor_smoke.png")
    _smoke_test(p.parse_args(argv).still)
