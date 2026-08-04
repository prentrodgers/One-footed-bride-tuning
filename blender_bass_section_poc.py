#!/usr/bin/env python3
"""
blender_bass_section_poc.py — first Blender/bpy prototype for the bass
section: bass_section_poc.py's pairing of a consolidated bass finger piano
(49 tines) and a consolidated baritone guitar (6 strings), following the
same pattern as blender_marimba_poc.py / blender_pizzicato_poc.py.

Axis convention (matches the other blender_*_poc.py files): X = left-right
across the row, Z = up/down (the instrument's own visible "height"), Y =
thin depth toward/away from the camera. Tines stand up out of their base
(Z), the guitar's body/neck run left-right (X) with string spread and body
height in Z, facing the camera — not lying flat on the ground plane, which
an early version of this file did by mistake (mapping the tine length and
string spread onto Y, the depth axis) and read as a paper-thin sliver from
the camera position every other section here uses.

Bass finger piano: tines are arranged low-to-high, left-to-right (like a
xylophone) — deliberately NOT the fanned/alternating "kalimba" layout a
real bass finger piano uses, per explicit direction. Each tine is a
cantilever (fixed at a node, free at the tip), not a standing wave like a
string — plucking sets the free end flapping forward/back, node stationary.

Baritone guitar: a real 6-string guitar (body, neck, headstock, pegs,
pickups, bridge). Strings are curves with the same shortened-length
standing-wave physics as blender_pizzicato_poc.py's strings, just running
horizontally instead of vertically.

pitch_bucket.py/string_length.py are reused directly (pure numpy, no
matplotlib dependency). bass_section_poc.py/marimba_poc.py both import
matplotlib at module level, so the small amount of pure-numpy logic needed
from them (bass_color, blended) is duplicated here rather than imported —
see marimba's note on the same tradeoff.

bpy only exists inside Blender's own Python, so this must be run via the
Blender executable, not plain python3:

  blender --background --python blender_bass_section_poc.py -- \\
      --npy bwv253_features_array.npy --tempo 100 --duration 5.0 \\
      --out blender_bass_frames
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

import pitch_bucket as pb
import string_length as sl

FPS = 30
GLOW_DECAY = 0.22


def blended(base, intensity):
    """Blend base colour toward white-cyan on impact. Copied from
    marimba_poc.py — see module note."""
    glow = np.array([0.45, 0.88, 1.00])
    b = np.array(base)
    return tuple(np.clip(b + intensity * (glow - b + 0.55 * glow), 0, 1))


def bass_color(i, n):
    """Deep red (low) -> indigo (high) — copied from bass_section_poc.py,
    see module note."""
    t = i / max(n - 1, 1)
    return (0.55 - t * 0.30, 0.14 + t * 0.08, 0.16 + t * 0.42)


def load_voices(npy_file, tempo, voices):
    """Notes as [start_s, pitch_cents, dur_s, vel, vol, voice_id] —
    duplicated from bass_section_poc.py (pure numpy, see module note)."""
    arr = np.load(npy_file)
    mask = (arr[:, 5] > 0) & (arr[:, 2] > 0) & (arr[:, 14] > 0) & (arr[:, 3] > 0)
    mask &= np.isin(arr[:, 6].astype(int), voices)
    arr = arr[mask]
    if not len(arr):
        return np.zeros((0, 5))
    bps = tempo / 60.0
    start_s = arr[:, 1] / bps
    duration_s = arr[:, 2] / bps
    pitch_cents = arr[:, 5] * 1200.0 + arr[:, 4]
    notes = np.column_stack([start_s, pitch_cents, duration_s, arr[:, 3], arr[:, 14]])
    return notes[notes[:, 0].argsort()]


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--npy", required=True)
    p.add_argument("--tempo", type=float, required=True)
    p.add_argument("--duration", type=float, required=True)
    p.add_argument("--out", default="blender_bass_frames")
    return p.parse_args(argv)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_wood_material(name, color):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.6
    return mat


def make_solid_material(name, color, roughness=0.5, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def make_glow_material(name):
    """Shared material: emission colour from each object's own Object
    Color, same trick as marimba's bars / pizzicato's strings."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emission = nt.nodes.new("ShaderNodeEmission")
    obj_info = nt.nodes.new("ShaderNodeObjectInfo")
    nt.links.new(obj_info.outputs["Color"], emission.inputs["Color"])
    emission.inputs["Strength"].default_value = 1.3
    nt.links.new(emission.outputs["Emission"], out.inputs["Surface"])
    return mat


def point_camera_at(cam, target):
    direction = mathutils.Vector(target) - mathutils.Vector(cam.location)
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()


def add_corner_bevel(obj, width, segments=3):
    """Rounds every edge of a box-like object — a Bevel modifier is enough
    since these are static (never per-frame vertex-edited) props."""
    mod = obj.modifiers.new("Bevel", 'BEVEL')
    mod.width = width
    mod.segments = segments
    mod.limit_method = 'NONE'


# ── Bass finger piano ───────────────────────────────────────────────────────
# Real bass finger pianos are built kalimba-style (long low tine in the
# centre, alternating shorter tines fanning left/right) — deliberately NOT
# reproduced here; tines run low-to-high, left-to-right, like a xylophone,
# matching bass_section_poc.py's existing (matplotlib) layout. Tines stand
# up out of the base (Z), clamped at the bottom (the node), free at the top
# (the tip) — a cantilever that flaps forward/back (Y) when plucked, not a
# standing wave.
TINE_BOTTOM_OCTAVE = 1     # C1..C5 — bass notes sit well below marimba/finger-piano's C4..C8
# Total horizontal span of the whole rack. Sharps/flats (5/octave) and
# naturals (7/octave, plus the lone extra top C) each spread their own
# notes evenly across this same width independently (see build_tine_
# layout) — a 5-note row and a 7-note row can't share one per-semitone
# step without one of them crowding, so neither tries to.
TINE_RACK_W    = 1.05
TINE_LEN_MAX   = 0.123    # lowest tine (left)
TINE_LEN_MIN   = 0.085    # highest tine (right)
TINE_WIDTH_MAX = 0.017
TINE_WIDTH_MIN = 0.011
TINE_THICK     = 0.003
SOLDER_R       = 0.0064   # blob of solder on every tine tip (real bass kalimba tuning trick)
N_TINE_PTS     = 10

# Margin is a modest fraction of the tine rack's own width — enough for
# the base to clearly read as the single piece every tine is rooted in,
# without leaving a wide strip of visibly unused stand on either side.
BASE_W_MARGIN_FRAC = 0.10
BASE_DEPTH     = 0.085
BASE_HEIGHT    = 0.047

TINE_VIB_FREQ = 7.0
TINE_TAU      = 0.42
TINE_PLK_APP_T = 0.055
TINE_PLK_DWL_T = 0.025
TINE_PLK_RET_T = 0.150
TINE_PLK_TRAVEL = 0.038
TINE_PLK_TRAVEL_BEND = 0.0255   # m — vibration flap amplitude at the tip, full amplitude
TINE_FINGER_R  = 0.0094

# Two ranks by pitch class, not by rack position: sharps/flats (black-key
# equivalents) in front (closer to the camera/audience), naturals in back
# (the performer's side) — a real 12-tone kalimba's black/white-key split,
# not an arbitrary alternation. Row gap generous enough, combined with the
# backward tilt below, that the back row isn't hidden behind the front one.
ROW_GAP_Y = 0.075
SHARP_PITCH_CLASSES = {1, 3, 6, 8, 10}   # C#, D#, F#, G#, A#

# Tines lean backward (+Y, away from the camera, toward the performer's
# side) as they rise, instead of standing straight up — both so a player
# standing behind the instrument can reach them, and so the back row's
# tines lean further clear of the front row's instead of being hidden
# directly behind them. Slope is tan(angle): 0.35 ~= 19 degrees off vertical.
TINE_TILT_SLOPE = 0.35

NODE_CLR   = (0.28, 0.27, 0.25)
SOLDER_CLR = (0.74, 0.75, 0.78)
FINGER_CLR = (0.85, 0.78, 0.68)


# Pitch-class -> keyboard column (white-key units within an octave), for the
# piano_layout mode: naturals on integer columns, accidentals on the half
# column between their neighbours (no column at 2.5=E-F or 6.5=B-C).
_WHITE_COL = {0: 0, 2: 1, 4: 2, 5: 3, 7: 4, 9: 5, 11: 6}
_SHARP_COL = {1: 0.5, 3: 1.5, 6: 3.5, 8: 4.5, 10: 5.5}


def build_tine_layout(bottom_octave, rack_w, color_fn=bass_color, piano_layout=False):
    """One representative pitch per fixed rack position (pitch_bucket's
    49-position window), low-to-high overall. Sharps/flats go in the front
    row, naturals in the back (see ROW_GAP_Y/SHARP_PITCH_CLASSES above).

    piano_layout=False (default): each row spaces its own notes evenly across
    the full rack_w independently. piano_layout=True: real keyboard geometry
    — naturals on their columns, each accidental in the gap between its two
    neighbouring naturals (with the E-F and B-C gaps), so the rows line up
    like a piano."""
    reps = pb.representative_cents(bottom_octave=bottom_octave)
    n = len(reps)
    is_sharp = [(int(round(c)) // 100) % 12 in SHARP_PITCH_CLASSES for c in reps]

    x_of = [0.0] * n
    if piano_layout:
        cols = []
        for c in reps:
            octv, pc = divmod(int(round(c / 100.0)), 12)
            col = (_SHARP_COL if pc in SHARP_PITCH_CLASSES else _WHITE_COL)[pc]
            cols.append((octv - bottom_octave) * 7 + col)
        centre = (min(cols) + max(cols)) / 2.0
        white_spacing = rack_w / max(max(cols) - min(cols), 1)
        x_of = [(c - centre) * white_spacing for c in cols]
    else:
        for row in ([i for i in range(n) if is_sharp[i]],
                    [i for i in range(n) if not is_sharp[i]]):
            m = len(row)
            step = rack_w / (m - 1) if m > 1 else 0.0
            for j, i in enumerate(row):
                x_of[i] = (j - (m - 1) / 2.0) * step

    tines = []
    pitch_to_idx = {}
    for i, cents in enumerate(reps):
        t = i / max(n - 1, 1)
        y = -ROW_GAP_Y / 2.0 if is_sharp[i] else ROW_GAP_Y / 2.0
        length = TINE_LEN_MAX + (TINE_LEN_MIN - TINE_LEN_MAX) * t
        width = TINE_WIDTH_MAX + (TINE_WIDTH_MIN - TINE_WIDTH_MAX) * t
        tines.append(dict(x=x_of[i], y=y, length=length, width=width, base=color_fn(i, n)))
        pitch_to_idx[int(round(cents))] = i
    return tines, pitch_to_idx, n


def build_tine_mesh(name, x, y0, base_z, length, half_w, half_thick, n_seg=N_TINE_PTS):
    """A flat cantilever strip standing up out of the base: rings of 4
    vertices from the node (z=base_z) to the free tip (z=base_z+length),
    same ring-mesh technique as the violin fingerboard/marimba bars — lets
    the tip flap forward/back per-frame without rebuilding the mesh. y0 is
    this tine's rank offset (front or back). Leans backward (+Y) linearly
    with height (TINE_TILT_SLOPE) so it isn't standing bolt upright."""
    zs = np.linspace(0.0, length, n_seg)
    verts = []
    for dz in zs:
        z = base_z + dz
        y = y0 + TINE_TILT_SLOPE * dz
        verts.append((x - half_w, y - half_thick, z))
        verts.append((x + half_w, y - half_thick, z))
        verts.append((x + half_w, y + half_thick, z))
        verts.append((x - half_w, y + half_thick, z))
    n = len(zs)
    faces = []
    for i in range(n - 1):
        i0, i1 = i * 4, (i + 1) * 4
        for c in range(4):
            c0, c1 = i0 + c, i0 + (c + 1) % 4
            c2, c3 = i1 + (c + 1) % 4, i1 + c
            faces.append((c0, c1, c2, c3))
    faces.append((0, 1, 2, 3))
    total = len(verts)
    faces.append((total - 1, total - 2, total - 3, total - 4))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    return mesh, zs


def update_tine_bend(obj, zs, y0, half_thick, length, amp, phase):
    """Cantilever deflection: 0 at the node, growing toward the tip
    (shape ~ (z/length)^2), same profile finger_piano_section_poc.py uses
    — flaps in Y (toward/away from the camera) around this tine's own rank
    offset y0, since Z is now the tine's own long axis."""
    disp = amp * TINE_PLK_TRAVEL_BEND * (zs / max(length, 1e-9)) ** 2 * math.cos(phase)
    verts = obj.data.vertices
    for i in range(len(zs)):
        y = y0 + TINE_TILT_SLOPE * zs[i] + disp[i]
        verts[i * 4 + 0].co.y = y - half_thick
        verts[i * 4 + 1].co.y = y - half_thick
        verts[i * 4 + 2].co.y = y + half_thick
        verts[i * 4 + 3].co.y = y + half_thick
    obj.data.update()


def reset_tine_bend(obj, zs, y0, half_thick):
    verts = obj.data.vertices
    for i in range(len(zs)):
        y = y0 + TINE_TILT_SLOPE * zs[i]
        verts[i * 4 + 0].co.y = y - half_thick
        verts[i * 4 + 1].co.y = y - half_thick
        verts[i * 4 + 2].co.y = y + half_thick
        verts[i * 4 + 3].co.y = y + half_thick
    obj.data.update()


def build_fp_stand(x0, base_w, base_depth, floor_z):
    """Four legs and a foot rail carrying a finger piano's base down to
    `floor_z`, so it is played standing at a stand like the marimba instead
    of lying on the floor. `floor_z` is in this builder's own units and is
    how the caller sets the height — each section is scaled differently on
    the shared stage, so there is no one right number here."""
    mat = make_wood_material("FingerPianoStandWood", (0.30, 0.24, 0.18))
    top_z = -BASE_HEIGHT / 2.0
    drop = top_z - floor_z
    r = min(base_depth * 0.16, drop * 0.06)
    legs = []
    for dx in (-base_w * 0.40, base_w * 0.40):
        for dy in (-base_depth * 0.32, base_depth * 0.32):
            bpy.ops.mesh.primitive_cylinder_add(
                radius=r, depth=drop, location=(x0 + dx, dy, (top_z + floor_z) / 2.0))
            leg = bpy.context.object
            leg.name = "finger_piano_leg"
            leg.data.materials.append(mat)
            legs.append(leg)
    # Foot rail low down, tying the legs together — without it four separate
    # posts read as the instrument hovering over sticks.
    rail_z = floor_z + drop * 0.16
    for dy in (-base_depth * 0.32, base_depth * 0.32):
        bpy.ops.mesh.primitive_cylinder_add(
            radius=r * 0.8, depth=base_w * 0.80, location=(x0, dy, rail_z),
            rotation=(0.0, math.radians(90), 0.0))
        rail = bpy.context.object
        rail.name = "finger_piano_rail"
        rail.data.materials.append(mat)
        legs.append(rail)
    return legs


def build_bass_finger_piano(x0, bottom_octave=TINE_BOTTOM_OCTAVE, color_fn=bass_color,
                            piano_layout=False, stand_floor_z=None):
    total_w = TINE_RACK_W
    tines, pitch_to_idx, n = build_tine_layout(bottom_octave, TINE_RACK_W, color_fn, piano_layout)
    glow_mat = make_glow_material("TineGlow")
    node_mat = make_solid_material("TineNode", NODE_CLR, roughness=0.7)
    solder_mat = make_solid_material("TineSolder", SOLDER_CLR, roughness=0.35, metallic=0.6)
    finger_mat = make_solid_material("TineFinger", FINGER_CLR, roughness=0.6)

    base_z = BASE_HEIGHT / 2.0

    tine_objs, tine_zs, tine_geo = [], [], []
    for tn in tines:
        x = x0 + tn['x']
        y0 = tn['y']
        tip_y = y0 + TINE_TILT_SLOPE * tn['length']
        half_w, half_thick = tn['width'] / 2.0, TINE_THICK / 2.0
        mesh, zs = build_tine_mesh(f"tine_{x:.4f}_{y0:.4f}", x, y0, base_z, tn['length'], half_w, half_thick)
        obj = bpy.data.objects.new(f"tine_{x:.4f}_{y0:.4f}", mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(glow_mat)
        obj.color = (*tn['base'], 1.0)
        tine_objs.append(obj)
        tine_zs.append(zs)
        tine_geo.append(dict(x=x, y=y0, length=tn['length'], half_w=half_w, half_thick=half_thick,
                              tip_z=base_z + tn['length'], tip_y=tip_y))

        # Node clamp — straddles the base's top surface (half sunk into the
        # base, half rising around the tine's root) so every tine visibly
        # grips into the base instead of floating above it. Sits at the
        # untilted y0 since the lean starts at zero right at the base.
        bpy.ops.mesh.primitive_cylinder_add(radius=half_w * 1.8, depth=0.022,
                                             location=(x, y0, base_z))
        node = bpy.context.object
        node.name = f"tine_node_{x:.4f}_{y0:.4f}"
        node.data.materials.append(node_mat)

        # Solder blob at the (tilted) tip
        bpy.ops.mesh.primitive_uv_sphere_add(radius=SOLDER_R, location=(x, tip_y, base_z + tn['length']))
        solder = bpy.context.object
        solder.scale = (1.0, 0.6, 0.6)
        solder.name = f"tine_solder_{x:.4f}_{y0:.4f}"
        solder.data.materials.append(solder_mat)

    # Base box (resonator) — clearly the single piece every tine is rooted
    # in, extending well past the end tines on every side, and deep enough
    # to cover both ranks.
    base_w = total_w * (1.0 + 2.0 * BASE_W_MARGIN_FRAC)
    base_depth = max(BASE_DEPTH, ROW_GAP_Y + TINE_THICK + 0.02)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x0, 0.0, 0.0))
    base = bpy.context.object
    base.scale = (base_w, base_depth, BASE_HEIGHT)
    base.name = "finger_piano_base"
    # Bake the (heavily non-uniform) scale into the mesh so the bevel
    # modifier's width means the same thing on every axis instead of
    # getting stretched by base_w vs. BASE_HEIGHT.
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    add_corner_bevel(base, width=0.012)
    base.data.materials.append(make_wood_material("FingerPianoBaseWood", (0.72, 0.60, 0.42)))

    # Plucking finger — one, since a player plucks with one hand at a time.
    bpy.ops.mesh.primitive_uv_sphere_add(radius=TINE_FINGER_R, location=(x0, 0.0, base_z))
    finger = bpy.context.object
    finger.scale = (0.7, 0.6, 1.0)
    finger.name = "tine_finger"
    finger.data.materials.append(finger_mat)
    finger.hide_render = True

    if stand_floor_z is not None:
        build_fp_stand(x0, base_w, base_depth, stand_floor_z)

    return dict(tine_objs=tine_objs, tine_zs=tine_zs, tine_geo=tine_geo,
                pitch_to_idx=pitch_to_idx, n=n, finger=finger, total_w=total_w,
                base_z=base_z, base_w=base_w, color_fn=color_fn)


def compute_tine_state(t, notes, pitch_to_idx, n):
    glow = np.zeros(n)
    vib_amp = np.zeros(n)
    vib_onset = np.full(n, -999.0)
    last_gest = {}
    total_gest = TINE_PLK_APP_T + TINE_PLK_DWL_T + TINE_PLK_RET_T
    for row in notes:
        onset_t = row[0]
        idx = pitch_to_idx.get(int(round(row[1])))
        if idx is None:
            continue
        dt = t - onset_t
        if 0.0 <= dt <= GLOW_DECAY:
            glow[idx] = max(glow[idx], 1.0 - dt / GLOW_DECAY)
        if dt >= 0.0:
            amp = math.exp(-dt / TINE_TAU)
            if amp > vib_amp[idx]:
                vib_amp[idx] = amp
                vib_onset[idx] = onset_t
        if -TINE_PLK_APP_T <= dt <= total_gest:
            if idx not in last_gest or onset_t > last_gest[idx]:
                last_gest[idx] = onset_t
    return glow, vib_amp, vib_onset, last_gest


def update_bass_finger_piano(t, geom, notes):
    glow, vib_amp, vib_onset, last_gest = compute_tine_state(t, notes, geom['pitch_to_idx'], geom['n'])
    n = geom['n']
    color_fn = geom.get('color_fn', bass_color)
    last_idx, last_onset = None, -1e9
    for i in range(n):
        obj = geom['tine_objs'][i]
        g_info = geom['tine_geo'][i]
        base = color_fn(i, n)
        g = glow[i]
        col = blended(base, g) if g > 0.03 else base
        obj.color = (*col, 1.0)

        a = vib_amp[i]
        if a > 0.01:
            dt = t - vib_onset[i]
            phase = 2.0 * math.pi * TINE_VIB_FREQ * dt
            update_tine_bend(obj, geom['tine_zs'][i], g_info['y'], g_info['half_thick'],
                              g_info['length'], a, phase)
        else:
            reset_tine_bend(obj, geom['tine_zs'][i], g_info['y'], g_info['half_thick'])

        onset = last_gest.get(i)
        if onset is not None and onset > last_onset:
            last_onset, last_idx = onset, i

    finger = geom['finger']
    if last_idx is None:
        finger.hide_render = True
        return
    dt = t - last_onset
    total = TINE_PLK_APP_T + TINE_PLK_DWL_T + TINE_PLK_RET_T
    if not (-TINE_PLK_APP_T <= dt <= total):
        finger.hide_render = True
        return
    g_info = geom['tine_geo'][last_idx]
    if dt < 0:
        ph = ((dt + TINE_PLK_APP_T) / TINE_PLK_APP_T) ** 1.5
        off = TINE_PLK_TRAVEL * (1.0 - ph)
    elif dt < TINE_PLK_DWL_T:
        off = 0.0
    else:
        ph = min(1.0, (dt - TINE_PLK_DWL_T) / TINE_PLK_RET_T) ** 0.7
        off = TINE_PLK_TRAVEL * ph
    # Finger approaches from the player's side, touches the (tilted) tip,
    # retracts.
    finger.location = (g_info['x'], g_info['tip_y'] + off, g_info['tip_z'])
    finger.hide_render = False


# ── Baritone guitar ─────────────────────────────────────────────────────────
# Body/neck run left-to-right (X); string spread and body height are in Z
# (facing the camera), thickness in Y — same standing-wave/shortened-
# length physics as blender_pizzicato_poc.py's strings, just laid out
# horizontally instead of vertically.
N_STRINGS = 6
GUITAR_OPEN_CENTS = [2300, 2800, 3300, 3800, 4200, 4700]   # B1 E2 A2 D3 F#3 B3
GUITAR_STRING_REACH = 2400

# Offset single-cutaway solid body (Reverend Descent-style): one horn near
# the neck joint, smooth rounded lower bout with no matching horn, a
# Fender-style paddle headstock with all 6 pegs in a row along one edge.
HEAD_LEN, HEAD_H = 0.11, 0.11
NECK_LEN = 0.46
BODY_W, BODY_H = 0.50, 0.40
BODY_DEPTH = 0.045
STRING_SPACING = 0.016
PLUCK_X_FRAC = 0.80
STRING_RADIUS = 0.0018
N_STRING_PTS = 24

# primitive_cube_add(size=1.0) + object.scale = final extent directly
# (scale multiplies the cube's own +-0.5 span, so setting scale.x = W
# gives an object that is exactly W wide — every box below is sized this
# way now, matching how BODY_W/BODY_H/NECK_LEN already work).
STRING_SPREAD = STRING_SPACING * (N_STRINGS - 1)
NECK_H = STRING_SPREAD * 1.15   # "just slightly wider than the strings"
FRETBOARD_H = NECK_H * 0.9   # solid surface under the strings, a thin rim of neck wood visible around it

GUITAR_BODY_CLR = (0.015, 0.015, 0.02)      # true black solid-body finish
GUITAR_BINDING_CLR = (0.88, 0.85, 0.76)     # cream body binding (the thin rim in the reference photo)
GUITAR_NECK_CLR = (0.80, 0.64, 0.42)        # light maple neck
GUITAR_FRETBOARD_CLR = (0.15, 0.09, 0.06)   # dark rosewood-style fretboard — solid, no frets or dots
GUITAR_CHROME_CLR = (0.85, 0.86, 0.88)
GUITAR_KNOB_CLR = (0.10, 0.10, 0.11)
STRING_CLRS = [
    (0.62, 0.60, 0.55), (0.66, 0.63, 0.56), (0.72, 0.68, 0.58),
    (0.78, 0.72, 0.55), (0.82, 0.78, 0.60), (0.86, 0.84, 0.70),
]
STRING_GLOW_COLOR = (0.90, 0.92, 0.80)

GTR_VIB_FREQ = 7.0
GTR_TAU = 0.30
GTR_PLK_APP_T = 0.055
GTR_PLK_DWL_T = 0.025
GTR_PLK_RET_T = 0.140
GTR_PICK_R = 0.010
GTR_STOP_DOT_R = 0.013
GTR_STOP_DOT_CLR = (0.85, 0.65, 0.25)
GTR_PICK_CLR = (0.85, 0.90, 0.97)
VIB_AMPLITUDE_GTR = 0.010   # m — visual side-to-side (Y) wiggle at full amplitude


def _note_to_guitar_string(pitch_cents):
    for i, op in enumerate(GUITAR_OPEN_CENTS):
        if -50 <= pitch_cents - op <= GUITAR_STRING_REACH:
            return i
    return int(np.argmin([abs(pitch_cents - op) for op in GUITAR_OPEN_CENTS]))


def guitar_body_outline_points(bw, bh, inflate=0.0):
    """Local (x, z) offsets for an offset single-cutaway solid body — x=0
    at the neck joint growing toward the tail, z centred on the string
    plane. A pointed upper horn (the single cutaway) near the neck joint on
    the +z side, then a deep waist notch, and a full rounded lower bout with
    no matching horn on the -z side — the Reverend Descent / offset-Fender
    silhouette. `inflate` pushes every point radially outward from the body
    centroid (used to build the light binding rim a touch larger than the
    body itself)."""
    pts = [
        (0.00 * bw, 0.12 * bh),
        (0.04 * bw, 0.34 * bh),
        (0.08 * bw, 0.50 * bh),   # upper-horn tip (cutaway)
        (0.13 * bw, 0.44 * bh),
        (0.20 * bw, 0.33 * bh),   # waist notch after the horn
        (0.30 * bw, 0.40 * bh),
        (0.44 * bw, 0.50 * bh),
        (0.62 * bw, 0.50 * bh),
        (0.80 * bw, 0.47 * bh),
        (0.92 * bw, 0.38 * bh),
        (1.00 * bw, 0.24 * bh),
        (1.05 * bw, 0.10 * bh),
        (1.06 * bw, 0.00 * bh),   # tail
        (1.05 * bw, -0.12 * bh),
        (1.00 * bw, -0.26 * bh),
        (0.90 * bw, -0.40 * bh),
        (0.70 * bw, -0.50 * bh),  # full lower bout
        (0.48 * bw, -0.50 * bh),
        (0.30 * bw, -0.44 * bh),
        (0.16 * bw, -0.30 * bh),
        (0.06 * bw, -0.16 * bh),
        (0.00 * bw, -0.08 * bh),
    ]
    if inflate:
        cx, cz0 = 0.5 * bw, 0.0
        out = []
        for x, z in pts:
            dx, dz = x - cx, z - cz0
            d = math.hypot(dx, dz) or 1.0
            out.append((x + inflate * dx / d, z + inflate * dz / d))
        return out
    return pts


def make_guitar_body_mesh(name, bx, cz, bw, bh, depth, inflate=0.0):
    """Flat-slab extrusion of guitar_body_outline_points — same fan-cap
    extrusion technique as blender_pizzicato_poc.py's make_body_mesh, minus
    the arched-dome bulge (a solid-body electric is flat, not carved)."""
    outline = guitar_body_outline_points(bw, bh, inflate)
    n = len(outline)
    front_y, back_y = -depth / 2.0, depth / 2.0
    verts = [(bx + x, front_y, cz + z) for x, z in outline] + \
            [(bx + x, back_y, cz + z) for x, z in outline]
    cx = bx + bw * 0.45
    front_c, back_c = len(verts), len(verts) + 1
    verts.append((cx, front_y, cz))
    verts.append((cx, back_y, cz))

    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    edge_face_count = len(faces)
    for i in range(n):
        j = (i + 1) % n
        faces.append((front_c, j, i))
        faces.append((back_c, n + i, n + j))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    # Smooth-shade the rim (edge) faces only, to soften the low-poly
    # outline into a rounded contour edge; the front/back caps stay flat,
    # like a real flat-top solid body.
    for f in mesh.polygons[:edge_face_count]:
        f.use_smooth = True
    return mesh


def guitar_headstock_outline_points(head_len, head_h, peg_fracs):
    """Local (x, z) offsets for a paddle headstock, scalloped around each
    tuning peg (peg_fracs, an x-fraction of head_len per peg) instead of a
    plain rectangle — material is cut away between pegs the way the
    Reverend Descent-style reference photo does, leaving a comb of bumps
    only where a peg actually needs support."""
    bottom = [
        (0.00, -0.36), (0.20, -0.40), (0.55, -0.36), (0.85, -0.24), (1.02, -0.08),
    ]
    tip = [(1.08, 0.02)]
    top = [(1.02, 0.14)]
    for i in range(len(peg_fracs) - 1, -1, -1):
        top.append((peg_fracs[i], 0.40))
        if i > 0:
            mid = (peg_fracs[i] + peg_fracs[i - 1]) / 2.0
            top.append((mid, 0.14))
    top.append((0.06, 0.30))
    top.append((0.00, 0.36))
    return [(x * head_len, z * head_h) for x, z in bottom + tip + top]


def make_guitar_headstock_mesh(name, x0, cz, head_len, head_h, depth, peg_fracs):
    """Flat-slab extrusion of guitar_headstock_outline_points — same
    fan-cap technique as make_guitar_body_mesh, smooth-shaded rim only."""
    outline = guitar_headstock_outline_points(head_len, head_h, peg_fracs)
    n = len(outline)
    front_y, back_y = -depth / 2.0, depth / 2.0
    verts = [(x0 + x, front_y, cz + z) for x, z in outline] + \
            [(x0 + x, back_y, cz + z) for x, z in outline]
    cx = x0 + head_len * 0.45
    front_c, back_c = len(verts), len(verts) + 1
    verts.append((cx, front_y, cz))
    verts.append((cx, back_y, cz))

    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    edge_face_count = len(faces)
    for i in range(n):
        j = (i + 1) % n
        faces.append((front_c, j, i))
        faces.append((back_c, n + i, n + j))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    for f in mesh.polygons[:edge_face_count]:
        f.use_smooth = True
    return mesh


def make_pick_mesh(name, r):
    """A small teardrop/pick-shaped flat mesh in the X-Z plane, point
    toward +z (up, toward the string it plucks)."""
    pts = np.array([
        [0.00, 1.00], [0.42, 0.55], [0.62, 0.05], [0.55, -0.45],
        [0.28, -0.85], [0.00, -1.00], [-0.28, -0.85], [-0.55, -0.45],
        [-0.62, 0.05], [-0.42, 0.55],
    ]) * r
    n = len(pts)
    thick = r * 0.25
    verts = [(x, -thick, z) for x, z in pts] + [(x, thick, z) for x, z in pts]
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    return mesh


def build_baritone_guitar(x0, cz):
    head_len, head_h = HEAD_LEN, HEAD_H
    neck_len, neck_h = NECK_LEN, NECK_H
    bw, bh = BODY_W, BODY_H
    x_nut = x0 + head_len
    bx = x0 + head_len + neck_len   # neck/body joint — body outline's local x=0
    x_bridge = bx + bw * 0.86
    total_len = bx + bw * 1.05 - x0   # tail tip, for camera/layout framing
    pluck_x = x_nut + (x_bridge - x_nut) * PLUCK_X_FRAC
    front_y = -(BODY_DEPTH / 2.0 + 0.006)   # string/hardware plane, proud of the body's front face

    body_mat = make_solid_material("GuitarBody", GUITAR_BODY_CLR, roughness=0.14)
    binding_mat = make_solid_material("GuitarBinding", GUITAR_BINDING_CLR, roughness=0.35)
    neck_mat = make_wood_material("GuitarNeck", GUITAR_NECK_CLR)
    fretboard_mat = make_wood_material("GuitarFretboard", GUITAR_FRETBOARD_CLR)
    # Lower metallic than a physically-accurate chrome so the bright base
    # colour still shows as diffuse — a fully-metallic surface just mirrors
    # the (dark) environment and reads black under this lighting.
    chrome_mat = make_solid_material("GuitarChrome", GUITAR_CHROME_CLR, roughness=0.28, metallic=0.35)
    knob_mat = make_solid_material("GuitarKnob", GUITAR_KNOB_CLR, roughness=0.4)

    # Cream body binding — a slightly-inflated copy of the body silhouette,
    # sitting flush at the body plane. The black body (built next) is pushed
    # a touch toward the camera so only this rim shows around its edge, the
    # way the reference photo's white binding frames the black body.
    binding_mesh = make_guitar_body_mesh("guitar_binding", bx, cz, bw, bh, BODY_DEPTH, inflate=0.007)
    binding = bpy.data.objects.new("guitar_binding", binding_mesh)
    bpy.context.scene.collection.objects.link(binding)
    binding.data.materials.append(binding_mat)

    # Body — offset single-cutaway silhouette, flat-extruded from an
    # explicit outline (see guitar_body_outline_points) instead of
    # overlapping spheres. Nudged proud of the binding (toward camera).
    body_mesh = make_guitar_body_mesh("guitar_body", bx, cz, bw, bh, BODY_DEPTH)
    body = bpy.data.objects.new("guitar_body", body_mesh)
    bpy.context.scene.collection.objects.link(body)
    body.location = (0.0, -0.005, 0.0)
    body.data.materials.append(body_mat)

    # Neck — spans the full gap between the headstock (x_nut) and the body
    # (bx), with a 2% overlap on each end so it visibly joins both instead
    # of floating between them with a gap on either side.
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x0 + head_len + neck_len / 2.0, 0.0, cz))
    neck = bpy.context.object
    neck.scale = (neck_len * 1.02, 0.015, neck_h)
    neck.name = "guitar_neck"
    # Bake scale into the mesh first so the bevel width is uniform in real
    # units instead of getting stretched by the neck's very non-uniform
    # length-vs-thickness scale.
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    add_corner_bevel(neck, width=0.005)
    neck.data.materials.append(neck_mat)

    # Fretboard overlay — solid, no frets or dots. Narrower than the neck
    # (which stays visible framing it on all sides) so there's a wood
    # surface for stopped strings to visibly press against.
    neck_front_y = -0.0075 - 0.004
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x_nut + neck_len * 0.5, neck_front_y, cz))
    fretboard = bpy.context.object
    fretboard.scale = (neck_len * 0.96, 0.008, FRETBOARD_H)
    fretboard.name = "guitar_fretboard"
    fretboard.data.materials.append(fretboard_mat)

    # Headstock — flat black paddle, matching the body's finish. All 6
    # pegs sit in a row along its own length (X) instead of stacked in Z —
    # a real Fender-style inline headstock, not a symmetric 3-per-side one.
    # Scalloped around each peg (see guitar_headstock_outline_points)
    # rather than a plain rectangle, with the same smooth-shaded rounded
    # rim as the body — no filler material where nothing is mounted.
    # The neck already overlaps back into the headstock's own span (its
    # 2% overlap trick above), so the headstock mesh itself just needs to
    # be exactly head_len — no separate stretch needed for the joint.
    peg_fracs = np.linspace(0.10, 0.95, N_STRINGS)
    head_mesh = make_guitar_headstock_mesh("guitar_head", x0, cz, head_len, head_h, 0.012, peg_fracs)
    head = bpy.data.objects.new("guitar_head", head_mesh)
    bpy.context.scene.collection.objects.link(head)
    head.data.materials.append(body_mat)

    szs = [cz - STRING_SPACING * (N_STRINGS - 1) / 2.0 + i * STRING_SPACING for i in range(N_STRINGS)]

    peg_xs = x0 + peg_fracs * head_len
    peg_z = cz + head_h * 0.32
    route_mat = make_solid_material("GuitarRoute", (0.5, 0.5, 0.52), roughness=0.6)
    for i, (px, sz) in enumerate(zip(peg_xs, szs)):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.007, depth=0.026, location=(px, 0.0, peg_z))
        peg = bpy.context.object
        peg.rotation_euler = (math.radians(90.0), 0.0, 0.0)
        peg.name = f"guitar_peg_{i}"
        peg.data.materials.append(chrome_mat)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.005, depth=0.026, location=(px, 0.0, peg_z + 0.016))
        knob = bpy.context.object
        knob.rotation_euler = (math.radians(90.0), 0.0, 0.0)
        knob.name = f"guitar_peg_knob_{i}"
        knob.data.materials.append(knob_mat)

        # Static routing line from the nut to this string's peg
        curve_data = bpy.data.curves.new(f"guitar_route_{i}", type='CURVE')
        curve_data.dimensions = '3D'
        curve_data.bevel_depth = 0.0012
        spline = curve_data.splines.new('POLY')
        spline.points.add(1)
        spline.points[0].co = (x_nut, front_y, sz, 1.0)
        spline.points[1].co = (px, front_y, peg_z, 1.0)
        route = bpy.data.objects.new(f"guitar_route_{i}", curve_data)
        bpy.context.scene.collection.objects.link(route)
        route.data.materials.append(route_mat)

    # Pickups — bright chrome-covered humbuckers (the shiny rectangular
    # pickups in the reference). A plain bright slab reads better at stage
    # distance than a fussy surround-plus-core that just muddies to grey.
    # Set just behind the string plane so the strings still pass over them.
    pickup_mat = make_solid_material("GuitarPickup", (0.80, 0.81, 0.83), roughness=0.3, metallic=0.2)
    pickup_y = front_y + 0.006
    for pu_x in (bx + bw * 0.40, bx + bw * 0.62):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(pu_x, pickup_y, cz))
        pu = bpy.context.object
        pu.scale = (bw * 0.07, 0.008, bh * 0.34)
        pu.name = f"guitar_pickup_{pu_x:.3f}"
        pu.data.materials.append(pickup_mat)

    # Bridge — black plate + a chrome saddle per string
    z_lo, z_hi = szs[0], szs[-1]
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x_bridge, front_y, cz))
    bridge = bpy.context.object
    bridge.scale = (0.010, 0.010, (z_hi - z_lo) / 2.0 + 0.018)
    bridge.name = "guitar_bridge"
    bridge.data.materials.append(knob_mat)
    for i, sz in enumerate(szs):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x_bridge, front_y - 0.006, sz))
        saddle = bpy.context.object
        saddle.scale = (0.008, 0.006, 0.004)
        saddle.name = f"guitar_saddle_{i}"
        saddle.data.materials.append(chrome_mat)

    # Control knobs + switch on the lower bout
    for k, kx_frac in enumerate((0.55, 0.66, 0.77)):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.014, depth=0.014,
                                             location=(bx + bw * kx_frac, front_y - 0.004, cz - bh * 0.30))
        knob_o = bpy.context.object
        knob_o.rotation_euler = (math.radians(90.0), 0.0, 0.0)
        knob_o.name = f"guitar_knob_{k}"
        knob_o.data.materials.append(knob_mat)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx + bw * 0.30, front_y - 0.004, cz - bh * 0.22))
    switch = bpy.context.object
    switch.scale = (0.018, 0.006, 0.007)
    switch.name = "guitar_switch"
    switch.data.materials.append(chrome_mat)

    string_mat = make_glow_material("GuitarStringGlow")
    strings, str_xs = [], []
    for i, sz in enumerate(szs):
        xs = np.linspace(x_nut, x_bridge, N_STRING_PTS)
        curve_data = bpy.data.curves.new(f"guitar_string{i}", type='CURVE')
        curve_data.dimensions = '3D'
        curve_data.bevel_depth = STRING_RADIUS
        curve_data.bevel_resolution = 2
        spline = curve_data.splines.new('POLY')
        spline.points.add(N_STRING_PTS - 1)
        for k, x in enumerate(xs):
            spline.points[k].co = (x, front_y, sz, 1.0)
        obj = bpy.data.objects.new(f"guitar_string{i}", curve_data)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(string_mat)
        obj.color = (*STRING_CLRS[i], 1.0)
        strings.append(obj)
        str_xs.append(xs)

    # Pick + fretboard stop dot, one of each (one plucking hand)
    pick_mat = make_solid_material("GuitarPick", GTR_PICK_CLR, roughness=0.4)
    pick_mesh = make_pick_mesh("guitar_pick_mesh", GTR_PICK_R)
    pick = bpy.data.objects.new("guitar_pick", pick_mesh)
    bpy.context.scene.collection.objects.link(pick)
    pick.data.materials.append(pick_mat)
    pick.hide_render = True

    stop_mat = make_solid_material("GuitarStopDot", GTR_STOP_DOT_CLR, roughness=0.5)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=GTR_STOP_DOT_R, location=(x_nut, front_y, cz))
    stop_dot = bpy.context.object
    stop_dot.scale = (0.6, 0.6, 1.0)
    stop_dot.name = "guitar_stop_dot"
    stop_dot.data.materials.append(stop_mat)
    stop_dot.hide_render = True

    return dict(strings=strings, str_xs=str_xs, szs=szs, x_nut=x_nut, x_bridge=x_bridge,
                pluck_x=pluck_x, front_y=front_y, pick=pick, stop_dot=stop_dot,
                total_len=total_len, cz=cz, top_z=cz + bh / 2.0, bottom_z=cz - bh / 2.0)


def compute_guitar_state(t, notes):
    glow = np.zeros(N_STRINGS)
    vib_amp = np.zeros(N_STRINGS)
    vib_onset = np.full(N_STRINGS, -999.0)
    vib_pitch = np.full(N_STRINGS, np.nan)
    last_gest = None
    total_gest = GTR_PLK_APP_T + GTR_PLK_DWL_T + GTR_PLK_RET_T
    for row in notes:
        onset_t, pitch, dur_s = row[0], row[1], row[2]
        si = _note_to_guitar_string(pitch)
        dt = t - onset_t
        if 0.0 <= dt <= GLOW_DECAY:
            glow[si] = max(glow[si], 1.0 - dt / GLOW_DECAY)
        if dt > 0.0:
            amp = math.exp(-dt / GTR_TAU)
            if dt > dur_s:
                amp *= max(0.0, 1.0 - (dt - dur_s) / 0.18)
            if amp > vib_amp[si]:
                vib_amp[si] = amp
                vib_onset[si] = onset_t
                vib_pitch[si] = pitch
        if -GTR_PLK_APP_T <= dt <= total_gest:
            if last_gest is None or onset_t > last_gest[0]:
                last_gest = (onset_t, si)
    return glow, vib_amp, vib_onset, vib_pitch, last_gest


def update_baritone_guitar(t, geom, notes):
    glow, vib_amp, vib_onset, vib_pitch, last_gest = compute_guitar_state(t, notes)
    front_y = geom['front_y']
    for i, sz in enumerate(geom['szs']):
        s = geom['strings'][i]
        xs = geom['str_xs'][i]
        g, a = glow[i], vib_amp[i]

        g_col = STRING_CLRS[i]
        if g > 0.04:
            base = np.array(STRING_CLRS[i])
            g_col = base + g * (np.array(STRING_GLOW_COLOR) - base)
        s.color = (*g_col, 1.0)

        points = s.data.splines[0].points
        if a > 0.005:
            dt = t - vib_onset[i]
            phase = 2.0 * math.pi * GTR_VIB_FREQ * dt
            pitch = vib_pitch[i]
            length_frac = (sl.vibrating_length_fraction(pitch, GUITAR_OPEN_CENTS[i])
                           if not math.isnan(pitch) else 1.0)
            L_full = geom['x_bridge'] - geom['x_nut']
            vib_nut = geom['x_nut'] + (1.0 - length_frac) * L_full
            span = max(geom['x_bridge'] - vib_nut, 1e-6)
            for k, x in enumerate(xs):
                if x >= vib_nut:
                    wave = math.sin(math.pi * (x - vib_nut) / span)
                else:
                    wave = 0.0
                y = front_y + VIB_AMPLITUDE_GTR * a * wave * math.cos(phase)
                points[k].co = (x, y, sz, 1.0)
            if length_frac < 0.98 and g > 0.05:
                geom['stop_dot'].location = (vib_nut, front_y, sz)
                geom['stop_dot'].hide_render = False
            else:
                geom['stop_dot'].hide_render = True
        else:
            for k, x in enumerate(xs):
                points[k].co = (x, front_y, sz, 1.0)
            geom['stop_dot'].hide_render = True
        s.data.update_tag()

    pick = geom['pick']
    if last_gest is None:
        pick.hide_render = True
        return
    onset_t, si = last_gest
    dt = t - onset_t
    total = GTR_PLK_APP_T + GTR_PLK_DWL_T + GTR_PLK_RET_T
    if not (-GTR_PLK_APP_T <= dt <= total):
        pick.hide_render = True
        return
    sz = geom['szs'][si]
    if dt < 0:
        ph = ((dt + GTR_PLK_APP_T) / GTR_PLK_APP_T) ** 1.5
        off = 0.024 * (1.0 - ph)
    elif dt < GTR_PLK_DWL_T:
        off = 0.0
    else:
        ph = min(1.0, (dt - GTR_PLK_DWL_T) / GTR_PLK_RET_T) ** 0.7
        off = 0.024 * ph
    pick.location = (geom['pluck_x'], front_y, sz - off)
    pick.hide_render = False


def build_stage(total_w, top_z, bottom_z, center_x=0.0):
    bpy.ops.mesh.primitive_plane_add(size=total_w * 1.3, location=(center_x, 0.0, bottom_z))
    floor = bpy.context.object
    floor.name = "Floor"
    mat = bpy.data.materials.new("FloorMat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.04, 0.04, 0.05, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.95
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.1
    floor.data.materials.append(mat)

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 30
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    # Distance derived from the camera's own horizontal FOV so total_w
    # actually fits in frame (with a 20% margin) — a fixed empirical
    # multiplier here previously left part of the scene cropped off-screen,
    # since it didn't account for the lens/sensor at all.
    half_fov = math.atan((cam_data.sensor_width / 2.0) / cam_data.lens)
    distance = (total_w / 2.0) / math.tan(half_fov) * 1.2
    cam.location = (center_x, -distance, top_z * 1.1)
    point_camera_at(cam, (center_x, total_w * 0.05, (top_z + bottom_z) * 0.3))
    bpy.context.scene.camera = cam

    sun_data = bpy.data.lights.new("Sun", type='SUN')
    sun_data.energy = 0.5
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.location = (1.5, -3.0, 4.0)
    sun.rotation_euler = (math.radians(45), 0, math.radians(25))
    bpy.context.scene.collection.objects.link(sun)

    fill_data = bpy.data.lights.new("Fill", type='AREA')
    fill_data.energy = 50.0
    fill_data.size = total_w * 0.3
    fill = bpy.data.objects.new("Fill", fill_data)
    fill.location = (-total_w * 0.3, -total_w * 0.3, top_z * 1.2)
    bpy.context.scene.collection.objects.link(fill)


def main():
    args = parse_args()
    t0 = time.time()

    clear_scene()

    fp_total_w = TINE_RACK_W   # must match build_bass_finger_piano's own total_w
    gtr_total_len = HEAD_LEN + NECK_LEN + BODY_W
    gap = 0.25
    fp_x0 = -(fp_total_w + gap + gtr_total_len) / 2.0 + fp_total_w / 2.0
    gtr_x0 = fp_x0 + fp_total_w / 2.0 + gap

    fp_geom = build_bass_finger_piano(fp_x0)
    gtr_geom = build_baritone_guitar(gtr_x0, BASE_HEIGHT / 2.0 + BODY_H * 0.15)

    fp_left_edge = fp_x0 - max(fp_total_w, fp_geom['base_w']) / 2.0
    gtr_right_edge = gtr_x0 + gtr_total_len
    total_w = gtr_right_edge - fp_left_edge
    center_x = (fp_left_edge + gtr_right_edge) / 2.0
    top_z = max(fp_geom['base_z'] + TINE_LEN_MAX, gtr_geom['top_z']) + 0.05
    bottom_z = min(-BASE_HEIGHT / 2.0, gtr_geom['bottom_z']) - 0.05
    build_stage(total_w, top_z, bottom_z, center_x)

    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 960
    scene.render.resolution_y = 540
    scene.render.fps = FPS
    scene.view_settings.view_transform = 'Standard'
    scene.render.image_settings.file_format = 'PNG'

    tine_notes = load_voices(args.npy, args.tempo, (24,))
    if len(tine_notes):
        tine_notes[:, 1] = [pb.bucket_cents(p, bottom_octave=TINE_BOTTOM_OCTAVE) for p in tine_notes[:, 1]]
    guitar_notes = load_voices(args.npy, args.tempo, (20,))

    out_dir = Path(args.out)
    out_dir.mkdir(exist_ok=True)

    n_frames = int(np.ceil(args.duration * FPS))
    print(f"[blender bass] {n_frames} frames, {fp_geom['n']} tines, {len(tine_notes)} tine notes, "
          f"{len(guitar_notes)} guitar notes")

    render_t0 = time.time()
    for fi in range(n_frames):
        t = fi / FPS
        update_bass_finger_piano(t, fp_geom, tine_notes)
        update_baritone_guitar(t, gtr_geom, guitar_notes)

        scene.render.filepath = str(out_dir / f"frame_{fi:06d}.png")
        bpy.ops.render.render(write_still=True)
        if fi % 30 == 0:
            elapsed = time.time() - render_t0
            print(f"  frame {fi}/{n_frames}  t={t:.2f}s  elapsed={elapsed:.1f}s")

    render_total = time.time() - render_t0
    print(f"[blender bass] done: {n_frames} frames in {render_total:.1f}s "
          f"({render_total / max(n_frames, 1):.3f}s/frame), "
          f"total script time {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
