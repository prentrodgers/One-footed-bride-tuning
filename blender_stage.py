#!/usr/bin/env python3
"""
blender_stage.py — prototype single shared 3D scene that places the three
existing Blender sections (marimba, pizzicato strings, bass) on ONE stage,
under one camera/floor.

The three section modules were each authored at their own arbitrary world
scale and centred on the origin (marimba ~20 units wide, pizz ~2.4, bass
~1.7), each with its own floor/camera/lights baked into a build_stage().
This script does NOT call those build_stage()s. Instead it:

  1. builds each section's *instruments* into the shared scene,
  2. collects the objects that build created,
  3. parents them under one Empty per section, and
  4. scales + translates that Empty so the section is normalised to a
     common on-stage height and dropped into its own non-overlapping slot,
     bottom sitting on the z=0 floor.

Layout concept — real orchestra staging: the wide, low marimba spans the
BACK of the stage; the taller string + bass sections sit in FRONT of it,
side by side. Uses the depth (Y) axis, which is the whole reason for going
3D in the first place.

This is a STATIC layout prototype (no per-frame animation yet) — its only
job is to prove the sections can share one stage without overlapping and
still read clearly. Animation wiring comes once the layout is agreed.

    blender --background --python blender_stage.py -- --out stage_proto.png
"""
import argparse
import math
import sys
import time
from pathlib import Path

import bpy
import mathutils
import numpy as np

REPO_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_DIR))

import blender_marimba_poc as marimba
import blender_pizzicato_poc as pizz
import blender_bass_section_poc as bass
import blender_finger_piano_poc as fingerpiano
import blender_woodwind_poc as woodwind
import blender_brass_poc as brass
import blender_bowed_strings_poc as bowedstrings
import blender_melody_poc as melody
import blender_conductor_poc as conductor
import pitch_bucket as pb
import string_length as sl

FPS = 30

# Each section is placed by a DIRECT scale + a floor position (cx, cy) — no
# auto-fit. A bigger `scale` makes a section genuinely bigger on screen,
# because the camera below is FIXED and never pulls back to re-fit the stage.
# cy is depth: larger = further back = higher up the frame. Tune these with
# the stage_layout_editor artifact, which writes exactly this block.
SECTIONS = {
    "pizz":          dict(cx=-16.0, cy=15.0, scale=5.50),
    "marimba":       dict(cx=11.5,  cy=4.0,  scale=0.90),
    "bass":          dict(cx=-0.5,  cy=3.5,  scale=3.50),
    "finger_piano":  dict(cx=-12.0, cy=4.5,  scale=8.00),
    "woodwind":      dict(cx=-10.0, cy=-7.0, scale=1.80),
    "brass":         dict(cx=16.5,  cy=14.5, scale=1.80),
    "bowed_strings": dict(cx=1.0,   cy=15.0, scale=4.00),
    "melody":        dict(cx=10.0,  cy=-7.0, scale=1.80),
    "conductor":     dict(cx=0.0,   cy=-6.5, scale=1.50),
}

# Fixed camera — shared verbatim with the stage_layout_editor artifact so its
# preview matches the render. (position, look-at target, focal length mm,
# sensor width mm.)
CAM_POS = (0.0, -36.0, 18.0)
CAM_TARGET = (0.0, 4.0, 3.0)
CAM_LENS = 38.0
CAM_SENSOR = 36.0


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    # With --npy the stage animates: --out is a frame directory. Without it,
    # a single static still is written to --out (the layout-check path).
    p.add_argument("--npy", default=None)
    p.add_argument("--tempo", type=float, default=None)
    p.add_argument("--duration", type=float, default=None)
    p.add_argument("--out", default="stage_proto.png")
    p.add_argument("--res-x", type=int, default=1280)
    p.add_argument("--res-y", type=int, default=720)
    return p.parse_args(argv)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mesh_bounds(objs):
    """World-space (min_x,max_x,min_y,max_y,min_z,max_z) over all the mesh
    verts in objs — before any grouping transform, so it's the section's
    own authored footprint."""
    xs, ys, zs = [], [], []
    for o in objs:
        if o.type != 'MESH':
            continue
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            xs.append(w.x); ys.append(w.y); zs.append(w.z)
    return min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)


def place_section(name, before_objs):
    """Group everything build() just created into one Empty, normalise it
    to SECTIONS[name]['target_h'], and drop it into its slot with its
    bottom on the floor. Returns the Empty and its post-transform world
    bounds (for camera framing)."""
    new = [o for o in bpy.data.objects if o not in before_objs]
    if not new:
        raise RuntimeError(f"section {name!r} created no objects")

    min_x, max_x, min_y, max_y, min_z, max_z = mesh_bounds(new)
    cfg = SECTIONS[name]
    scale = cfg["scale"]   # direct scale, no auto-fit

    cx_src = (min_x + max_x) / 2.0
    cy_src = (min_y + max_y) / 2.0

    empty = bpy.data.objects.new(f"section_{name}", None)
    bpy.context.scene.collection.objects.link(empty)
    empty.scale = (scale, scale, scale)
    # Centre the section over its slot (x, y); sit its bottom on z=0.
    empty.location = (cfg["cx"] - cx_src * scale,
                      cfg["cy"] - cy_src * scale,
                      -min_z * scale)

    for o in new:
        if o.parent is None:
            o.parent = empty

    # Post-transform world bounds of this section's footprint corners.
    def w(x, y, z):
        return (x * scale + empty.location.x,
                y * scale + empty.location.y,
                z * scale + empty.location.z)
    corners = [w(x, y, z) for x in (min_x, max_x) for y in (min_y, max_y) for z in (min_z, max_z)]
    wb = (min(c[0] for c in corners), max(c[0] for c in corners),
          min(c[1] for c in corners), max(c[1] for c in corners),
          min(c[2] for c in corners), max(c[2] for c in corners))
    print(f"[stage] {name:8s} scale={scale:.3f}  "
          f"X[{wb[0]:.2f},{wb[1]:.2f}] Y[{wb[2]:.2f},{wb[3]:.2f}] Z[{wb[4]:.2f},{wb[5]:.2f}]")
    return empty, wb


# Each setup_* builds its section's instruments into the current scene,
# loads that section's notes from (npy, tempo), and returns an update(t)
# callback that drives one frame. The objects the build created get parented
# under the section's Empty afterwards (place_section); because the update
# callbacks only ever set obj.color / obj.location / obj.hide_render /
# obj.rotation_euler or edit mesh-local vertex coords — all of which compose
# through a parent transform — the animation rides the scale+translate for
# free, no matter where the section is placed on the stage.

def setup_marimba(npy, tempo):
    bars, pitch_to_idx, n_bars, bar_info, half_width = marimba.build_bars()
    post_l = bar_info[0]["x"] - marimba.FRAME_MARGIN
    post_r = bar_info[-1]["x"] + marimba.FRAME_MARGIN
    marimba.build_strings(bar_info, post_l, post_r)
    marimba.build_frame(bar_info, post_l, post_r)
    marimba.build_resonators(bar_info, n_bars)

    notes = marimba.load_features_array(npy, tempo, voice=5) if npy else np.zeros((0, 5))
    if len(notes):
        notes[:, 1] = [pb.bucket_cents(p) for p in notes[:, 1]]
    assignments, n_slots = marimba.assign_mallet_slots(notes, pitch_to_idx)
    pivots, sticks, heads = marimba.build_mallet_pool(n_slots)
    vibrating = set()

    def update(t):
        nonlocal vibrating
        glow = marimba.compute_bar_glow(t, notes, pitch_to_idx, n_bars)
        for i, obj in enumerate(bars):
            base = marimba.bar_base_color(i, n_bars)
            g = glow[i]
            col = marimba.blended(base, g) if g > 0.02 else base
            obj.color = (*col, 1.0)
        last_onset = marimba.compute_last_onset(t, notes, pitch_to_idx, n_bars)
        still = set()
        for i in np.nonzero(~np.isnan(last_onset))[0]:
            dt = t - last_onset[i]
            if dt < marimba.VIB_CUTOFF:
                marimba.apply_bar_vibration(bars[i], dt)
                still.add(int(i))
        for i in vibrating - still:
            marimba.reset_bar_mesh(bars[i])
        vibrating = still
        marimba.update_mallet_pool(t, assignments, n_slots, pivots, sticks, heads, bar_info)

    return update


def _update_string_player(t, pl, geom):
    """One string player's per-frame update (glow, vibration, stop finger,
    pluck/bow) — shared by the pizzicato and bowed-string sections, which
    build identical violin/viola/cello geometry."""
    state = pizz.compute_player_state(t, pl['_notes'], pl['inst'])
    glow, vib = state['str_glow'], state['str_vib']
    st_on, st_pitch = state['str_onset'], state['str_pitch']

    for si, s in enumerate(geom['strings']):
        g, a = glow[si], vib[si]
        g_col = pizz.STRING_REST_COLOR[si]
        if g > 0.02:
            base = np.array(pizz.STRING_REST_COLOR[si])
            g_col = base + g * (np.array(pizz.STRING_GLOW_COLOR) - base)
        s.color = (*g_col, 1.0)

        stopf = geom['stop_fingers'][si]
        if a > 0.005:
            dt = t - st_on[si]
            phase = 2.0 * math.pi * pizz.VIB_FREQ * dt
            pitch = st_pitch[si]
            length_frac = (sl.vibrating_length_fraction(pitch, geom['open_cents'][si])
                           if not math.isnan(pitch) else 1.0)
            vib_top_z = geom['bridge_z'] + length_frac * (geom['str_top'] - geom['bridge_z'])
            pizz.update_string_curve(s, geom['str_zs'][si], geom['str_xs'][si], geom['str_ys'][si],
                                     geom['bridge_z'], vib_top_z, a, phase)
            if length_frac < 0.98 and g > 0.05:
                stop_x = pizz.string_rest_x(vib_top_z, geom['str_top'], geom['bridge_z'],
                                            geom['sxs'][si], geom['bridge_sxs'][si])
                stop_y = geom['front_y'] - pizz.dome_bump(vib_top_z, geom['bh'], geom['arch_depth']) - 0.006
                stopf.location = (stop_x, stop_y, vib_top_z)
                stopf.hide_render = False
            else:
                stopf.hide_render = True
        else:
            pizz.reset_string_curve(s, geom['str_zs'][si], geom['str_xs'][si], geom['str_ys'][si])
            stopf.hide_render = True

    if geom['pluck'] is not None:
        pizz.update_pluck_finger(geom['pluck'], state['last_gest'],
                                 geom['contact_sxs'], geom['contact_z'], geom['contact_y'], t)
    if geom['bow_pivot'] is not None:
        pizz.update_bow(geom['bow_pivot'], geom['bow_parts'], state['last_gest'],
                        geom['contact_sxs'], geom['contact_z'], geom['contact_y'], t)


def setup_pizz(npy, tempo):
    string_mat = pizz.make_string_glow_material()
    notes = pizz.load_string_voices(npy, tempo) if npy else np.zeros((0, 5))
    player_note_sets = pizz.build_player_note_sets(notes, pizz.PLAYERS)
    geoms = {}
    for pl in pizz.PLAYERS:
        pl['_notes'] = player_note_sets[pl['id']]
        geoms[pl['id']] = pizz.build_player(pl, string_mat)

    def update(t):
        for pl in pizz.PLAYERS:
            _update_string_player(t, pl, geoms[pl['id']])

    return update


def setup_bass(npy, tempo):
    # Finger piano on the left, baritone guitar on the right, separated in X
    # (they were overlapping at a shared x0=0 before). Mirrors the standalone
    # bass section's own main() layout, with a slightly wider gap.
    fp_total_w = bass.TINE_RACK_W
    gtr_total_len = bass.HEAD_LEN + bass.NECK_LEN + bass.BODY_W
    gap = 0.45
    fp_x0 = -(fp_total_w + gap + gtr_total_len) / 2.0 + fp_total_w / 2.0
    gtr_x0 = fp_x0 + fp_total_w / 2.0 + gap
    fp_geom = bass.build_bass_finger_piano(fp_x0)
    gtr_geom = bass.build_baritone_guitar(gtr_x0, bass.BASE_HEIGHT / 2.0 + bass.BODY_H * 0.15)

    tine_notes = bass.load_voices(npy, tempo, (24,)) if npy else np.zeros((0, 5))
    if len(tine_notes):
        tine_notes[:, 1] = [pb.bucket_cents(p, bottom_octave=bass.TINE_BOTTOM_OCTAVE)
                            for p in tine_notes[:, 1]]
    guitar_notes = bass.load_voices(npy, tempo, (20,)) if npy else np.zeros((0, 5))

    def update(t):
        bass.update_bass_finger_piano(t, fp_geom, tine_notes)
        bass.update_baritone_guitar(t, gtr_geom, guitar_notes)

    return update


def setup_finger_piano(npy, tempo):
    geom = fingerpiano.build_finger_piano(0.0)
    notes = fingerpiano.load_notes(npy, tempo) if npy else np.zeros((0, 5))

    def update(t):
        fingerpiano.update_finger_piano(t, geom, notes)

    return update


def setup_woodwind(npy, tempo):
    geom = woodwind.build_woodwinds(0.0)
    seat_sets = woodwind.load_seat_notes(npy, tempo, geom['seats'])

    def update(t):
        woodwind.update_woodwinds(t, geom, seat_sets)

    return update


def setup_brass(npy, tempo):
    geom = brass.build_brass(0.0)
    seat_sets = brass.load_seat_notes(npy, tempo, geom['seats'])

    def update(t):
        brass.update_brass(t, geom, seat_sets)

    return update


def setup_bowed_strings(npy, tempo):
    geom = bowedstrings.build_bowed_strings(0.0)
    voices = tuple(p['voice'] for p in bowedstrings.PLAYERS)
    notes = pizz.load_string_voices(npy, tempo, voices) if npy else np.zeros((0, 5))
    sets = pizz.build_player_note_sets(notes, bowedstrings.PLAYERS)
    for pl in bowedstrings.PLAYERS:
        pl['_notes'] = sets[pl['id']]

    def update(t):
        for pl in bowedstrings.PLAYERS:
            _update_string_player(t, pl, geom['geoms'][pl['id']])

    return update


def setup_melody(npy, tempo):
    geom = melody.build_melody(0.0)
    seat_notes = melody.load_seat_notes(npy, tempo, geom['seats'])

    def update(t):
        melody.update_melody(t, geom, seat_notes)

    return update


def setup_conductor(npy, tempo):
    geom = conductor.build_conductor_section(0.0)
    state = {'dir': [0.0, -0.45, 0.92]}   # smoothed baton direction, persists across frames

    def update(t):
        conductor.update_conductor(t, geom, tempo, state)

    return update


def point_camera_at(cam, target):
    d = mathutils.Vector(target) - mathutils.Vector(cam.location)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


def build_stage_env(bounds):
    """Floor + FIXED camera + flat lighting. The camera never re-fits to the
    content, so section scales map predictably to on-screen size."""
    floor_c = (0.0, 3.0, 0.0)
    bpy.ops.mesh.primitive_plane_add(size=140.0, location=floor_c)
    floor = bpy.context.object
    floor.name = "Floor"
    mat = bpy.data.materials.new("FloorMat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.05, 0.05, 0.06, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.95
    floor.data.materials.append(mat)

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = CAM_LENS
    cam_data.sensor_width = CAM_SENSOR
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = CAM_POS
    point_camera_at(cam, CAM_TARGET)
    bpy.context.scene.camera = cam

    sun_data = bpy.data.lights.new("Sun", type='SUN')
    sun_data.energy = 2.5
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(52), 0, math.radians(20))
    bpy.context.scene.collection.objects.link(sun)

    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.02, 0.03, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.4


def main():
    args = parse_args()
    t0 = time.time()
    animate = args.npy is not None
    if animate and args.tempo is None:
        raise SystemExit("--tempo is required with --npy")

    clear_scene()

    bounds, updates = [], []
    setups = (("pizz", setup_pizz), ("marimba", setup_marimba), ("bass", setup_bass),
              ("finger_piano", setup_finger_piano), ("woodwind", setup_woodwind),
              ("brass", setup_brass), ("bowed_strings", setup_bowed_strings),
              ("melody", setup_melody), ("conductor", setup_conductor))
    for name, setup in setups:
        before = set(bpy.data.objects)
        # Static build (no notes) when just checking layout; otherwise the
        # setup also loads notes and hands back a per-frame update callback.
        update_fn = setup(args.npy, args.tempo) if animate else _static_build(name, setup)
        _, wb = place_section(name, before)
        bounds.append(wb)
        if update_fn is not None:
            updates.append(update_fn)

    build_stage_env(bounds)

    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = args.res_x
    scene.render.resolution_y = args.res_y
    scene.render.fps = FPS
    scene.view_settings.view_transform = 'Standard'
    scene.render.image_settings.file_format = 'PNG'

    if not animate:
        scene.render.filepath = str(Path(args.out).resolve())
        bpy.ops.render.render(write_still=True)
        print(f"[stage] wrote still {args.out}")
        return

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    n_frames = int(np.ceil(args.duration * FPS))
    print(f"[stage] animating {n_frames} frames ({args.duration:.1f}s @ {FPS}fps) -> {out_dir}/")
    render_t0 = time.time()
    for fi in range(n_frames):
        t = fi / FPS
        for update in updates:
            update(t)
        scene.render.filepath = str(out_dir / f"frame_{fi:06d}.png")
        bpy.ops.render.render(write_still=True)
        if fi % 30 == 0:
            print(f"  frame {fi}/{n_frames}  t={t:.2f}s  elapsed={time.time() - render_t0:.1f}s")
    total = time.time() - render_t0
    print(f"[stage] done: {n_frames} frames in {total:.1f}s "
          f"({total / max(n_frames, 1):.3f}s/frame), total {time.time() - t0:.1f}s")


def _static_build(name, setup):
    """Layout-check path: run the section's setup with no notes so it just
    builds geometry (setup_* tolerate npy=None -> empty note arrays)."""
    setup(None, None)
    return None


if __name__ == "__main__":
    main()
