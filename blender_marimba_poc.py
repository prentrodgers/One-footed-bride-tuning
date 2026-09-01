#!/usr/bin/env python3
"""
blender_marimba_poc.py — first Blender/bpy prototype for the marimba
section: a real 3D scene (camera, lighting, EEVEE render) instead of
marimba_section_poc.py's matplotlib cabinet-projection trick.

Reuses the same note-data pipeline as the matplotlib version —
pitch_bucket.py for the pitch-class folding (37 bars), and marimba_poc.py for
loading the features array and the amber->steel-blue bar coloring — only
the geometry/rendering layer is new. No mallets yet (bar glow only): this
is a first pass to validate the Blender workflow and measure render time
per frame before building out the rest.

bpy only exists inside Blender's own Python, so this must be run via the
Blender executable, not plain python3:

  blender --background --python blender_marimba_poc.py -- \\
      --npy bwv253_features_array.npy --tempo 100 --duration 5.0 \\
      --out blender_marimba_frames
"""
import argparse
import heapq
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

# marimba_poc.py imports matplotlib at module level, which doesn't exist in
# Blender's bundled Python — so bar_base_color/blended/load_features_array/
# GLOW_DECAY are duplicated here (all pure numpy in the original) rather
# than importing that module. Keep these in sync with marimba_poc.py by
# hand if the color scheme changes there.

FPS = 30
GLOW_DECAY = 0.24


# How much of bar_base_color's pitch ramp survives in the wood. 1.0 is the
# old fully-coloured bar; 0.0 is plain rosewood with pitch showing only in
# the strike flash.
TINT_STRENGTH = 0.22
# Emission multiplier at the instant of a strike, before the glow decays.
GLOW_STRENGTH = 4.0


def bar_base_color(i, n):
    """Amber/warm (low, i=0) -> steel-blue (high, i=n-1). Copied from
    marimba_poc.py — see note above."""
    t = i / max(n - 1, 1)
    if t < 0.5:
        s = t * 2
        return (0.80 - s * 0.40, 0.38 + s * 0.28, 0.02 + s * 0.30)
    else:
        s = (t - 0.5) * 2
        return (0.40 - s * 0.28, 0.66 - s * 0.22, 0.32 + s * 0.52)


def bar_object_color(i, n, glow=0.0):
    """The RGBA a bar's object colour carries for make_bar_material():
    RGB is its pitch tint, ALPHA is how hard it was just struck. Two
    per-bar values in one plain tuple, so 37 bars still animate without
    touching a material."""
    return (*bar_base_color(i, n), float(max(0.0, min(1.0, glow))))


def blended(base, intensity):
    """Blend base colour toward white-cyan on impact. Copied from
    marimba_poc.py — see note above."""
    glow = np.array([0.45, 0.88, 1.00])
    b = np.array(base)
    return tuple(np.clip(b + intensity * (glow - b + 0.55 * glow), 0, 1))


def load_features_array(npy_file, tempo, voice=None):
    """Notes as [start_s, pitch_cents, duration_s, velocity, volume].
    Copied from marimba_poc.py — see note above."""
    arr = np.load(npy_file)
    mask = (arr[:, 5] > 0) & (arr[:, 2] > 0) & (arr[:, 14] > 0) & (arr[:, 3] > 0)
    if voice is not None:
        mask &= (arr[:, 6].astype(int) == int(voice))
    arr = arr[mask]

    beats_per_sec = tempo / 60.0
    start_s    = arr[:, 1] / beats_per_sec
    duration_s = arr[:, 2] / beats_per_sec
    pitch_cents = arr[:, 5] * 1200.0 + arr[:, 4]
    notes = np.column_stack([start_s, pitch_cents, duration_s, arr[:, 3], arr[:, 14]])
    return notes[notes[:, 0].argsort()]

# Real keyboard (piano) geometry, for a performer standing BEHIND the
# instrument: naturals in the BACK rank (+Y, nearest the player) evenly
# spaced; accidentals in the FRONT rank (-Y, toward the camera), each one
# sitting in the X gap between its two neighbouring naturals and raised in
# Z. Because the black keys come in groups of two (C#, D#) and three (F#,
# G#, A#), the accidental row has the natural gaps at E-F and B-C — that
# grouping IS what makes it read as a keyboard, and it aligns the two rows
# into clean columns instead of an incommensurate moiré.
# Widened from 0.46 when pitch_bucket dropped to 3 octaves: 22 white columns
# instead of 28, so a wider pitch keeps the instrument the same size on stage
# and spends the saved bars on making every remaining one bigger.
WHITE_SPACING = 0.59   # m between adjacent naturals (white keys) in X
# Real bars widen toward the bass rather than running at one width.
BAR_WIDTH_LOW  = 0.36   # lowest bar
BAR_WIDTH_HIGH = 0.26   # highest bar
BAR_WIDTH   = (BAR_WIDTH_LOW + BAR_WIDTH_HIGH) / 2.0   # nominal, for callers
BAR_THICK   = 0.18     # thick enough to read as 3D from a wide establishing shot
BAR_LEN_MAX = 1.6       # lowest bar
BAR_LEN_MIN = 0.7       # highest bar
# The undercut: a real marimba bar has an arch cut out of its underside,
# deep on the long low bars and shallow at the top. After the resonators it
# is the strongest cue that this is a marimba and not a row of tiles, and it
# is what a silhouette or an edge-detect pass actually sees.
ARCH_DEPTH_LOW  = 0.55  # fraction of BAR_THICK removed at the centre, lowest bar
ARCH_DEPTH_HIGH = 0.12  # .. and at the highest
BAR_BEVEL = 0.012      # m — edges catch light instead of being razor sharp

# Pitch-class -> keyboard column, in "white-key units" within an octave.
# Naturals land on integer columns 0..6; accidentals land on the half
# column between their neighbours (C# between C=0 and D=1, etc.) — no
# accidental exists at 2.5 (E-F) or 6.5 (B-C), giving the keyboard gaps.
SHARP_PITCH_CLASSES = frozenset({1, 3, 6, 8, 10})
WHITE_KEY_COL = {0: 0, 2: 1, 4: 2, 5: 3, 7: 4, 9: 5, 11: 6}
SHARP_KEY_COL = {1: 0.5, 3: 1.5, 6: 3.5, 8: 4.5, 10: 5.5}
WHITE_KEYS_PER_OCT = 7

# Naturals (back) vs accidentals (front) depth gap, and the accidentals'
# lift onto their raised tier (real marimbas raise the accidental frame).
RANK_GAP_Y    = 0.55
SHARP_RAISE_Z = 0.30

# Real marimba bars are strung on cords through their vibrational nodes,
# roughly 1/5 of the bar's length in from each end. The cords, anchored to
# end posts, sag in the middle like a hammock — SAG_AMOUNT is that dip's
# depth at row centre.
NODE_FRAC  = 0.2
SAG_AMOUNT = 0.6
FRAME_MARGIN = 0.5    # how far past the end bars the frame posts sit
STAND_H = 1.6         # end posts run this far below the resonators — the legs
                      # the instrument stands on, so the bars sit at playing
                      # height instead of near the floor

# Each bar is built with extra cross-section rings at its two node points
# (plus the centre and the two ends) so a struck bar can visibly flex right
# after impact while its node points stay put — matching how a real bar's
# fundamental bending mode has stationary nodes with the ends and centre
# moving (out of phase with each other). RING_FRACS are fractions of the
# bar's length; VIB_MODE_SHAPE is each ring's relative displacement (0 at
# the nodes by construction), precomputed once since it only depends on
# NODE_FRAC, not on any individual bar's dimensions.
RING_FRACS = [0.0, NODE_FRAC, 0.5, 1.0 - NODE_FRAC, 1.0]
VIB_AMPLITUDE  = 0.018   # m — small flex, visible but subtle at this framing
VIB_DECAY_TAU  = 0.075   # s — fast decay, dies out well within half a second
VIB_FREQ       = 10.0    # Hz — kept well under the 30fps/2 Nyquist limit so it reads as motion, not flicker
VIB_CUTOFF     = 0.45    # s — stop bothering to update a bar's mesh once it's inaudibly still


def bar_vibration_mode_shape():
    span = 1.0 - 2.0 * NODE_FRAC
    return [math.sin(math.pi * (frac - NODE_FRAC) / span) for frac in RING_FRACS]


VIB_MODE_SHAPE = bar_vibration_mode_shape()

# Mallet strike timing.
#
# Rather than one mallet parked over every bar, an invisible (super-humanly
# quick) player "teleports" a small pool of mallets to wherever the next
# note needs striking. Each mallet is a rigid, fixed-length rod hinged at a
# pivot that sits directly above its target bar and does not move for the
# whole strike — only the rod's angle changes, swinging the head from a
# hover just above the bar down to the bar's centre and back, exactly like
# a normal mallet stroke (not a stretching handle). A mallet is invisible
# except during its own strike window. The pool size is derived from the
# notes themselves (the max number of simultaneous strikes), not one per bar.
#
# The approach uses a steep power curve (MALLET_APPROACH_POWER) so almost
# all of the head's motion happens right at the end, just before contact —
# a hard, accelerating hit rather than a mallet drifting down and settling
# onto the bar. The rebound mirrors that with an ease-out power curve: fast
# off the bar (a real player yanks the mallet clear so the bar can ring),
# decelerating only as it nears the rest position.
MALLET_STICK_R  = 0.040
MALLET_HEAD_R   = 0.105   # big enough to read against the bars from the wide stage shot
MALLET_LEN      = 1.00   # fixed rod length, pivot to head
# The player stands BEHIND the instrument (+Y, away from camera) and reaches
# over it, so a mallet's pivot — her hand — belongs back there, not floating
# above the bar it is about to hit. Rotation is about X: a NEGATIVE angle
# swings the head forward, toward the camera and down onto the bar. The
# strike angle therefore also fixes where the hand has to be, and
# update_mallet_pool derives the pivot from it rather than repeating the
# number. More negative = lifted higher and further back.
MALLET_STRIKE_ANGLE = -45.0   # degrees: the stick at the moment of contact
MALLET_REST_ANGLE   = -75.0   # degrees: lifted clear, waiting to come down
MALLET_OVER_REACH = 0.22  # fractional overshoot past vertical on follow-through
MALLET_APPROACH_POWER = 2.6   # >1: velocity builds through the approach, peaking at contact
MALLET_REBOUND_POWER  = 2.2   # >1 ease-out: fast off the bar, slows into rest
APPROACH_T = 0.050
DWELL_T    = 0.020
OVER_T     = 0.018
REBOUND_T  = 0.085

# Resonator tubes, one per bar, hanging below it. The stand gives them the
# full height under the bars to work with, so they hang straight down as far
# as they can and only fold back up when they run out of room.
INCH = 0.0254
# Length per bar rather than per octave-tier: a quarter-wave tube goes as
# 1/f and a bar's length as 1/sqrt(f), so tube length tracks the SQUARE of
# its own bar's length. That gives a smooth ramp across the keyboard instead
# of four flat steps, and it is the ramp — not any absolute tuning — that
# reads on screen. RESON_LEN_LOW is the lowest bar's tube.
RESON_LEN_LOW    = 3.6         # metres, the longest tube (folds into a U)
RESON_RAD_LOW    = 0.075       # tube radius at the lowest bar ..
RESON_RAD_HIGH   = 0.022       # .. and at the highest
RESON_BEND_RADIUS     = 0.05
# A tube may hang until it is level with the bottom of the stand legs, then
# it has to turn back up. Keeping the fold at exactly the stand bottom means
# the resonators never become the section's lowest point, so adding all this
# length does not shift the marimba upward when the stage sits it on z=0.
RESON_FLOOR_Z         = -SAG_AMOUNT - 0.5 - STAND_H


def sag_z(x, half_width):
    """Hammock dip: 0 at the row ends (x=+-half_width), -SAG_AMOUNT at centre."""
    frac = x / half_width if half_width else 0.0
    frac = max(-1.0, min(1.0, frac))
    return -SAG_AMOUNT * (1.0 - frac * frac)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--npy", required=True)
    p.add_argument("--tempo", type=float, required=True)
    p.add_argument("--duration", type=float, required=True)
    p.add_argument("--out", default="blender_marimba_frames")
    return p.parse_args(argv)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_glow_material():
    """Deprecated: the flat emission material the bars used before they were
    given real wood. Kept because the standalone smoke tests in the other
    section modules still build against it."""
    mat = bpy.data.materials.new("BarGlow")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emission = nt.nodes.new("ShaderNodeEmission")
    obj_info = nt.nodes.new("ShaderNodeObjectInfo")
    nt.links.new(obj_info.outputs["Color"], emission.inputs["Color"])
    emission.inputs["Strength"].default_value = 1.6
    nt.links.new(emission.outputs["Emission"], out.inputs["Surface"])
    return mat


ROSEWOOD_DARK  = (0.105, 0.036, 0.022, 1.0)   # the streaks
ROSEWOOD_LIGHT = (0.330, 0.128, 0.068, 1.0)   # the body
STRIKE_COLOR   = (1.0, 0.95, 0.86, 1.0)       # what the flash tends toward


def _emission_sockets(bsdf):
    """(colour socket, strength socket) — Blender renamed "Emission" to
    "Emission Color" at 4.0, and this file has to build on both."""
    ins = bsdf.inputs
    colour = ins.get("Emission Color") or ins.get("Emission")
    return colour, ins.get("Emission Strength")


def make_bar_material():
    """One shared material for every bar, reading two things off each
    object: its COLOUR is the pitch tint mixed faintly into the rosewood,
    and its ALPHA is the strike glow. That keeps the old one-tuple-per-bar
    animation while the bars themselves become lit wood — diffuse, specular
    and shadowed — instead of self-lit tiles.

    Wood matters twice over. It is what makes the instrument read as a
    marimba, and a shaded, grained surface gives comfy_restyle.py's canny
    pass real edges to hold; a flat emissive bar gives it almost none.
    """
    mat = bpy.data.materials.new("BarRosewood")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    # Grain, in the bar's own space: fast variation across the width,
    # slow along the length, so it streaks the way sawn wood does.
    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (14.0, 1.1, 14.0)
    nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 7.0
    noise.inputs["Detail"].default_value = 6.0
    noise.inputs["Roughness"].default_value = 0.62
    nt.links.new(mapping.outputs["Vector"], noise.inputs["Vector"])

    grain = nt.nodes.new("ShaderNodeValToRGB")
    grain.color_ramp.elements[0].position = 0.35
    grain.color_ramp.elements[0].color = ROSEWOOD_DARK
    grain.color_ramp.elements[1].position = 0.68
    grain.color_ramp.elements[1].color = ROSEWOOD_LIGHT
    nt.links.new(noise.outputs["Fac"], grain.inputs["Fac"])

    obj_info = nt.nodes.new("ShaderNodeObjectInfo")

    # Base colour: the wood, nudged toward this bar's pitch tint.
    tint = _mix_rgb(nt, TINT_STRENGTH, grain.outputs["Color"],
                    obj_info.outputs["Color"])
    nt.links.new(tint, bsdf.inputs["Base Color"])

    # Rosewood is a hard, close-grained wood: fairly smooth, not glossy,
    # with the grain showing up as a little roughness variation.
    rough = nt.nodes.new("ShaderNodeMapRange")
    rough.inputs["To Min"].default_value = 0.26
    rough.inputs["To Max"].default_value = 0.44
    nt.links.new(noise.outputs["Fac"], rough.inputs["Value"])
    nt.links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])

    # The strike: object alpha drives emission strength, so a bar at rest
    # (alpha 0) is pure wood and a struck one flashes in its own pitch hue.
    em_colour, em_strength = _emission_sockets(bsdf)
    if em_colour is not None:
        flash = _mix_rgb(nt, 0.45, obj_info.outputs["Color"], STRIKE_COLOR)
        nt.links.new(flash, em_colour)
    alpha = obj_info.outputs.get("Alpha")
    if alpha is not None and em_strength is not None:
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = 'MULTIPLY'
        mul.inputs[1].default_value = GLOW_STRENGTH
        nt.links.new(alpha, mul.inputs[0])
        nt.links.new(mul.outputs["Value"], em_strength)
    else:
        # Pre-3.0 Blender has no Alpha output on Object Info; rather than
        # glow constantly, the bars simply stop flashing. Say so loudly.
        print("[marimba] Object Info has no Alpha output — no strike glow. "
              "Blender 3.0+ is needed for the flash.")
        if em_strength is not None:
            em_strength.default_value = 0.0
    return mat


def _mix_rgb(nt, factor, a, b):
    """Mix two colours, returning the output socket. `a`/`b` may be sockets
    or literal RGBA tuples. Uses the modern Mix node where it exists and the
    legacy MixRGB where it doesn't, since this file has to build on both."""
    if hasattr(bpy.types, "ShaderNodeMix"):
        node = nt.nodes.new("ShaderNodeMix")
        node.data_type = 'RGBA'
        f, sa, sb = node.inputs["Factor"], node.inputs[6], node.inputs[7]
        result = node.outputs[2]
    else:
        node = nt.nodes.new("ShaderNodeMixRGB")
        f, sa, sb = node.inputs["Fac"], node.inputs["Color1"], node.inputs["Color2"]
        result = node.outputs["Color"]
    f.default_value = factor
    for socket, value in ((sa, a), (sb, b)):
        if hasattr(value, "node"):
            nt.links.new(value, socket)
        else:
            socket.default_value = value
    return result


# mesh name -> the z of every vertex at rest. The bars are no longer flat
# boxes, so the vibration can't reconstruct their rest shape from BAR_THICK
# alone the way it used to; it has to be remembered per bar.
_BAR_REST_Z = {}


def arch_lift(arch_depth):
    """How far the underside is cut away at each of the RING_FRACS rings:
    nothing at the ends, deepest at the centre — the marimba's undercut."""
    return [arch_depth * math.sin(math.pi * f) for f in RING_FRACS]


def make_bar_mesh(name, width, length, thick, arch_depth=0.0):
    """A box built with 5 cross-section rings (at RING_FRACS along its
    length, in local space with y=0 at the bar's centre) instead of a
    single primitive cube — the extra edge loops let apply_bar_vibration()
    bend it ring-by-ring for the post-strike flex, and let the underside
    carry the tuning arch: the bottom face lifts toward the bar's middle,
    so the bar is thin at its centre and full thickness at its ends."""
    lift = arch_lift(arch_depth)
    verts, rest_z = [], []
    for ring, frac in enumerate(RING_FRACS):
        y = (frac - 0.5) * length
        bottom = -thick / 2.0 + lift[ring]
        top = thick / 2.0
        for x, z in ((-width / 2, bottom), (width / 2, bottom),
                     (width / 2, top), (-width / 2, top)):
            verts.append((x, y, z))
            rest_z.append(z)

    faces = []
    for ring in range(len(RING_FRACS) - 1):
        i0, i1 = ring * 4, (ring + 1) * 4
        for c in range(4):
            c0, c1 = i0 + c, i0 + (c + 1) % 4
            c2, c3 = i1 + (c + 1) % 4, i1 + c
            faces.append((c0, c1, c2, c3))
    faces.append((0, 1, 2, 3))
    n = len(verts)
    faces.append((n - 1, n - 2, n - 3, n - 4))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    _BAR_REST_Z[mesh.name] = rest_z
    return mesh


def bar_rest_z(mesh, v):
    """Rest height of vertex v — the arched profile if this mesh was built
    by make_bar_mesh, the old flat box if something else made it."""
    rest = _BAR_REST_Z.get(mesh.name)
    if rest is not None and v < len(rest):
        return rest[v]
    return -BAR_THICK / 2.0 if (v % 4) < 2 else BAR_THICK / 2.0


def keyboard_column(cents, bottom_octave):
    """White-key-unit X column for a pitch, and whether it's an accidental.
    Naturals land on integer columns, accidentals on the half column
    between their neighbours — the conventional keyboard geometry, with the
    E-F and B-C gaps falling out naturally (no 2.5 or 6.5 column exists)."""
    semitone = int(round(cents / 100.0))
    octave, pc = divmod(semitone, 12)
    is_sharp = pc in SHARP_PITCH_CLASSES
    col_in_oct = SHARP_KEY_COL[pc] if is_sharp else WHITE_KEY_COL[pc]
    return (octave - bottom_octave) * WHITE_KEYS_PER_OCT + col_in_oct, is_sharp


def build_bars():
    reps = pb.representative_cents()   # the fixed positions, low->high
    n = len(reps)
    bottom_octave = int(round(reps[0] / 1200.0))
    cols = [keyboard_column(c, bottom_octave) for c in reps]
    is_sharp = [s for _, s in cols]
    col_vals = [c for c, _ in cols]
    centre_col = (min(col_vals) + max(col_vals)) / 2.0
    x_of = [(c - centre_col) * WHITE_SPACING for c in col_vals]
    half_width = (max(col_vals) - centre_col) * WHITE_SPACING

    mat = make_bar_material()
    bars = []
    bar_info = []   # per-bar dict: x, y (rank centre), z, length, node_offset, is_sharp
    pitch_to_idx = {}
    for i, cents in enumerate(reps):
        x = x_of[i]
        frac = i / (n - 1)
        length = BAR_LEN_MAX + (BAR_LEN_MIN - BAR_LEN_MAX) * frac
        # Naturals BACK (+Y, nearest the player behind); accidentals FRONT
        # (-Y, toward camera) and raised in Z so the ranks don't collide.
        y = (-RANK_GAP_Y / 2.0) if is_sharp[i] else (RANK_GAP_Y / 2.0)
        z = sag_z(x, half_width) + (SHARP_RAISE_Z if is_sharp[i] else 0.0)
        width = BAR_WIDTH_LOW + (BAR_WIDTH_HIGH - BAR_WIDTH_LOW) * frac
        arch = (ARCH_DEPTH_LOW + (ARCH_DEPTH_HIGH - ARCH_DEPTH_LOW) * frac) * BAR_THICK
        mesh = make_bar_mesh(f"bar_{i:02d}_mesh", width, length, BAR_THICK, arch)
        obj = bpy.data.objects.new(f"bar_{i:02d}", mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.location = (x, y, z)
        obj.data.materials.append(mat)
        bevel = obj.modifiers.new("Bevel", 'BEVEL')
        bevel.width = BAR_BEVEL
        bevel.segments = 2
        obj.color = bar_object_color(i, n)
        bars.append(obj)
        pitch_to_idx[int(round(cents))] = i
        node_offset = length * (0.5 - NODE_FRAC)
        bar_info.append(dict(x=x, y=y, z=z, length=length,
                             node_offset=node_offset, is_sharp=is_sharp[i]))
    return bars, pitch_to_idx, n, bar_info, half_width


def make_mallet_material():
    mat = bpy.data.materials.new("MalletMat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.75, 0.72, 0.65, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.5
    return mat


def assign_mallet_slots(notes, pitch_to_idx):
    """Greedy interval-graph voice allocation (same idea as synth voice
    stealing): each note gets a mallet 'slot', reusing a slot as soon as
    its previous note's strike window has ended. The number of slots that
    fall out of this is the max number of simultaneous strikes — usually
    just a handful, not one per bar."""
    total = APPROACH_T + DWELL_T + OVER_T + REBOUND_T
    events = []
    for row in notes:
        onset = row[0]
        idx = pitch_to_idx.get(int(round(row[1])))
        if idx is None:
            continue
        events.append((onset - APPROACH_T, onset + total, onset, idx))
    events.sort(key=lambda e: e[0])

    free_heap = []   # (end_time, slot)
    n_slots = 0
    assignments = []   # (start, end, onset, idx, slot)
    for start, end, onset, idx in events:
        if free_heap and free_heap[0][0] <= start:
            _, slot = heapq.heappop(free_heap)
        else:
            slot = n_slots
            n_slots += 1
        heapq.heappush(free_heap, (end, slot))
        assignments.append((start, end, onset, idx, slot))
    return assignments, max(n_slots, 1)


def build_mallet_pool(n_slots):
    """A small, fixed pool of mallets: each is an Empty pivot with a
    rigid-length stick (cylinder) + head (sphere) hanging straight down
    from it (built at identity rotation, then parented, exactly as in the
    single-mallet-per-bar prototype, so later rotating the pivot swings the
    rod without double-rotating the children). All hidden by default —
    update_mallet_pool() repositions the pivot and unhides them only while
    a note is mid-strike."""
    mat = make_mallet_material()
    pivots, sticks, heads = [], [], []
    for s in range(n_slots):
        pivot = bpy.data.objects.new(f"mallet_pivot_{s}", None)
        pivot.location = (0.0, 0.0, 0.0)
        bpy.context.scene.collection.objects.link(pivot)

        bpy.ops.mesh.primitive_cylinder_add(
            radius=MALLET_STICK_R, depth=MALLET_LEN, location=(0.0, 0.0, -MALLET_LEN / 2.0))
        stick = bpy.context.object
        stick.name = f"mallet_stick_{s}"
        stick.data.materials.append(mat)
        stick.hide_render = True
        stick.parent = pivot
        stick.matrix_parent_inverse = pivot.matrix_world.inverted()

        bpy.ops.mesh.primitive_uv_sphere_add(radius=MALLET_HEAD_R, location=(0.0, 0.0, -MALLET_LEN))
        head = bpy.context.object
        head.name = f"mallet_head_{s}"
        head.data.materials.append(mat)
        head.hide_render = True
        head.parent = pivot
        head.matrix_parent_inverse = pivot.matrix_world.inverted()

        pivots.append(pivot)
        sticks.append(stick)
        heads.append(head)
    return pivots, sticks, heads


def strike_angle(dt):
    """MALLET_REST_ANGLE (lifted, not yet touching) -> MALLET_STRIKE_ANGLE
    (touching the bar) -> a quick overshoot on follow-through -> back to
    MALLET_REST_ANGLE by the end of the rebound (right when the strike
    window closes and the mallet is hidden again).

    The approach is a steep power curve (frac ~ t_norm^POWER, POWER>1): it
    barely moves at first and then snaps down, arriving at maximum speed
    right at contact — a hard, accelerating hit, not a mallet drifting down
    and gently settling. The rebound is the mirror-image ease-out: fast
    off the bar immediately after impact, decelerating only as it nears
    the rest position, like a player yanking the mallet clear so the bar
    can ring instead of floating back up."""
    if dt < 0:
        t_norm = max(0.0, min(1.0, (dt + APPROACH_T) / APPROACH_T))
        frac = t_norm ** MALLET_APPROACH_POWER
    elif dt < DWELL_T:
        frac = 1.0
    elif dt < DWELL_T + OVER_T:
        phase = (dt - DWELL_T) / OVER_T
        frac = 1.0 + MALLET_OVER_REACH * phase
    else:
        phase = min(1.0, (dt - DWELL_T - OVER_T) / REBOUND_T)
        eased = 1.0 - (1.0 - phase) ** MALLET_REBOUND_POWER
        frac = (1.0 + MALLET_OVER_REACH) * (1.0 - eased)
    return MALLET_STRIKE_ANGLE + (MALLET_REST_ANGLE - MALLET_STRIKE_ANGLE) * (1.0 - frac)


def update_mallet_pool(t, assignments, n_slots, pivots, sticks, heads, bar_info):
    active = [None] * n_slots
    for start, end, onset, idx, slot in assignments:
        if start <= t <= end:
            active[slot] = (onset, idx)

    for s in range(n_slots):
        stick, head = sticks[s], heads[s]
        if active[s] is None:
            stick.hide_render = True
            head.hide_render = True
            continue
        onset, idx = active[s]
        info = bar_info[idx]
        bar_top = info["z"] + BAR_THICK / 2.0

        # Pivot — the player's hand — sits BEHIND and above the bar, placed
        # so that at MALLET_STRIKE_ANGLE the head lands on the bar's centre.
        # It does not move for the whole strike; only the rotation changes,
        # swinging the fixed-length rod forward and down onto the bar.
        tilt = math.radians(MALLET_STRIKE_ANGLE)
        pivots[s].location = (info["x"],
                              info["y"] - MALLET_LEN * math.sin(tilt),
                              bar_top + MALLET_LEN * math.cos(tilt))
        pivots[s].rotation_euler = (math.radians(strike_angle(t - onset)), 0, 0)
        stick.hide_render = False
        head.hide_render = False


def make_string_material():
    mat = bpy.data.materials.new("StringMat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.05, 0.05, 0.05, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.6
    return mat


def make_frame_material():
    mat = bpy.data.materials.new("FrameMat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.10, 0.08, 0.06, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.6
    return mat


def make_resonator_material():
    mat = bpy.data.materials.new("ResonatorMat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.55, 0.56, 0.58, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.8
    bsdf.inputs["Roughness"].default_value = 0.3
    return mat


def _node_pt(b, sign):
    """(x, y, z) of one of a bar's two node points: sign=+1 is the +Y
    (nearer-the-player) node, sign=-1 the -Y (toward-camera) node."""
    return (b["x"], b["y"] + sign * b["node_offset"], b["z"])


def _cord_point_sets(bar_info):
    """The three cord rails, as x-ordered lists of node points. The two-rank
    layout needs three cords, not two. With the naturals in the back rank
    (+Y, nearest the player) and accidentals in the front rank (-Y):

      near   (+Y, nearest player) : naturals' near (+Y) nodes
      middle (shared)             : naturals' far (-Y) nodes + accidentals' near (+Y) nodes
      far    (-Y, toward camera)  : accidentals' far (-Y) nodes

    So the naturals hang on the near+middle cords, the accidentals on the
    middle+far cords — the player's "bottom two" and "top two" respectively.
    """
    naturals = sorted((b for b in bar_info if not b["is_sharp"]), key=lambda b: b["x"])
    sharps = sorted((b for b in bar_info if b["is_sharp"]), key=lambda b: b["x"])
    near = [_node_pt(b, +1) for b in naturals]
    middle = sorted([_node_pt(b, -1) for b in naturals] + [_node_pt(b, +1) for b in sharps],
                    key=lambda p: p[0])
    far = [_node_pt(b, -1) for b in sharps]
    return {"near": near, "middle": middle, "far": far}


def build_strings(bar_info, post_x_left, post_x_right):
    """Three cords threaded through the two ranks' node points, each running
    out to loop around the frame posts. See _cord_point_sets for the
    front/middle/back split."""
    mat = make_string_material()
    strings = []
    for name, pts in _cord_point_sets(bar_info).items():
        full = [(post_x_left, pts[0][1], 0.0)] + pts + [(post_x_right, pts[-1][1], 0.0)]
        curve_data = bpy.data.curves.new(f"string_{name}", type='CURVE')
        curve_data.dimensions = '3D'
        curve_data.bevel_depth = 0.012
        curve_data.bevel_resolution = 2
        spline = curve_data.splines.new('POLY')
        spline.points.add(len(full) - 1)
        for i, (x, y, z) in enumerate(full):
            spline.points[i].co = (x, y, z, 1.0)

        obj = bpy.data.objects.new(f"String_{name}", curve_data)
        obj.data.materials.append(mat)
        bpy.context.scene.collection.objects.link(obj)
        strings.append(obj)
    return strings


def build_frame(bar_info, post_x_left, post_x_right):
    """End posts the three support cords loop onto, with small rings marking
    each cord's loop point (front/middle/back rails)."""
    frame_mat = make_frame_material()
    string_mat = make_string_material()
    post_bottom = -SAG_AMOUNT - 0.5 - STAND_H
    post_top = 0.4
    post_height = post_top - post_bottom
    for post_x in (post_x_left, post_x_right):
        bpy.ops.mesh.primitive_cylinder_add(
            radius=0.05, depth=post_height,
            location=(post_x, 0.0, (post_top + post_bottom) / 2.0))
        post = bpy.context.object
        post.name = f"frame_post_x{post_x:.2f}"
        post.data.materials.append(frame_mat)

    # Each cord loops onto both posts at that cord's own rail Y (its
    # first/last node point's Y).
    cords = _cord_point_sets(bar_info)
    for post_x, end in ((post_x_left, 0), (post_x_right, -1)):
        for name, pts in cords.items():
            y = pts[end][1]
            bpy.ops.mesh.primitive_torus_add(
                major_radius=0.08, minor_radius=0.018,
                location=(post_x, y, 0.0))
            ring = bpy.context.object
            ring.name = f"frame_loop_{name}_x{post_x:.2f}"
            ring.data.materials.append(string_mat)


def resonator_spec(bar_len):
    """(length, radius) of the tube under a bar of this length. Length goes
    as the square of bar length (see RESON_LEN_LOW); radius is interpolated
    so the bottom tubes read as fat pipes and the top ones as thin ones."""
    f = (bar_len - BAR_LEN_MIN) / (BAR_LEN_MAX - BAR_LEN_MIN)
    length = RESON_LEN_LOW * (bar_len / BAR_LEN_MAX) ** 2
    return length, RESON_RAD_HIGH + (RESON_RAD_LOW - RESON_RAD_HIGH) * f


def build_straight_resonator(x, bar_y, top_z, length, radius, mat):
    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius, depth=length, location=(x, bar_y, top_z - length / 2.0))
    tube = bpy.context.object
    tube.data.materials.append(mat)
    return tube


def resonator_fold_plan(length, max_drop):
    """The legs a tube of `length` is folded into, top to bottom, given it
    may drop at most `max_drop` before turning.

    Each leg runs the full drop and the LAST one takes whatever is left
    over, rather than dividing the length evenly. That matters visually:
    every tube long enough to fold reaches the same floor — the bottom of
    the stand — so the row of tube bottoms steps down smoothly with pitch
    instead of jumping back up each time a tube gains a leg."""
    r = RESON_BEND_RADIUS
    legs, left = [], length
    while left > max_drop and len(legs) < 20:
        legs.append(max_drop)
        left -= max_drop + math.pi * r / 2.0   # the turn eats tube too
    legs.append(max(0.02, left))
    return legs


def build_folded_resonator(x, bar_y, top_z, length, radius, mat, max_drop):
    """Zig-zag fold a too-long resonator into legs joined by half-circle
    turns, so it drops to the bottom of the stand and turns back up rather
    than hanging the full quarter-wavelength into the floor — the same
    reason real contrabass marimba resonators are bent."""
    r = RESON_BEND_RADIUS
    legs = resonator_fold_plan(length, max_drop)
    n_turns = len(legs) - 1

    y0 = bar_y - n_turns * r   # centre the whole zig-zag horizontally on the bar
    pts = [(x, y0, top_z)]
    y, z, direction = y0, top_z, -1.0
    for leg_i, leg in enumerate(legs):
        z += direction * leg
        pts.append((x, y, z))
        if leg_i < n_turns:
            bulge = 1.0 if direction < 0 else -1.0   # dip further down at a bottom turn, up at a top turn
            center_y = y + r
            n_arc = 8
            for k in range(1, n_arc):
                theta = math.pi + math.pi * k / n_arc
                pts.append((x, center_y + r * math.cos(theta), z + bulge * r * math.sin(theta)))
            y += 2 * r
            pts.append((x, y, z))
            direction *= -1.0

    curve_data = bpy.data.curves.new("resonator_fold", type='CURVE')
    curve_data.dimensions = '3D'
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = 3
    spline = curve_data.splines.new('POLY')
    spline.points.add(len(pts) - 1)
    for i, (px, py, pz) in enumerate(pts):
        spline.points[i].co = (px, py, pz, 1.0)

    obj = bpy.data.objects.new("resonator_fold", curve_data)
    obj.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_resonators(bar_info, n):
    """One resonator tube per bar, hanging below it — length proportional to
    its own bar's (see resonator_spec), hanging straight down until it is
    level with the bottom of the stand and only then folding back up."""
    mat = make_resonator_material()
    tubes = []
    for i, info in enumerate(bar_info):
        length, radius = resonator_spec(info["length"])
        top_z = info["z"] - BAR_THICK / 2 - 0.05
        max_drop = top_z - RESON_FLOOR_Z
        if length > max_drop:
            tube = build_folded_resonator(info["x"], info["y"], top_z, length,
                                          radius, mat, max_drop)
        else:
            tube = build_straight_resonator(info["x"], info["y"], top_z, length, radius, mat)
        tube.name = f"resonator_{i:02d}"
        tubes.append(tube)
    return tubes


def point_camera_at(cam, target):
    """Aim cam at target via Blender's track-quat math, instead of a
    hand-guessed Euler angle — robust to whatever position we pick."""
    direction = mathutils.Vector(target) - mathutils.Vector(cam.location)
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()


def build_floor(total_w):
    # Resonators bottom out at the stand's feet by construction, so the floor
    # only has to clear those.
    floor_z = RESON_FLOOR_Z - 0.3
    bpy.ops.mesh.primitive_plane_add(size=total_w * 1.15, location=(0.0, 0.0, floor_z))
    floor = bpy.context.object
    floor.name = "Floor"
    mat = bpy.data.materials.new("FloorMat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.04, 0.04, 0.05, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.8
    floor.data.materials.append(mat)


def build_stage(total_w):
    build_floor(total_w)

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 22
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = (0.0, -total_w * 0.62, total_w * 0.28)
    point_camera_at(cam, (0.0, total_w * 0.05, -0.8))
    bpy.context.scene.camera = cam

    sun_data = bpy.data.lights.new("Sun", type='SUN')
    sun_data.energy = 1.6
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.location = (2.0, -4.0, 6.0)
    sun.rotation_euler = (math.radians(40), 0, math.radians(20))
    bpy.context.scene.collection.objects.link(sun)

    fill_data = bpy.data.lights.new("Fill", type='AREA')
    fill_data.energy = 300.0
    fill_data.size = total_w * 0.3
    fill = bpy.data.objects.new("Fill", fill_data)
    fill.location = (-total_w * 0.3, -total_w * 0.2, total_w * 0.25)
    bpy.context.scene.collection.objects.link(fill)


def compute_bar_glow(t, notes, pitch_to_idx, n_bars):
    """Same envelope math as marimba_poc.compute_state's bar_glow, without
    the matplotlib-specific mallet-head geometry this prototype doesn't use yet."""
    glow = np.zeros(n_bars)
    for row in notes:
        onset_t = row[0]
        pitch = int(round(row[1]))
        idx = pitch_to_idx.get(pitch)
        if idx is None:
            continue
        dt = t - onset_t
        if 0.0 <= dt <= GLOW_DECAY:
            glow[idx] = max(glow[idx], 1.0 - dt / GLOW_DECAY)
    return glow


def compute_last_onset(t, notes, pitch_to_idx, n_bars):
    """Time of each bar's most recent onset at or before t (NaN if it
    hasn't been struck yet), driving the post-strike vibration decay."""
    last_onset = np.full(n_bars, np.nan)
    for row in notes:
        onset_t = row[0]
        if onset_t > t:
            continue
        idx = pitch_to_idx.get(int(round(row[1])))
        if idx is None:
            continue
        if np.isnan(last_onset[idx]) or onset_t > last_onset[idx]:
            last_onset[idx] = onset_t
    return last_onset


def apply_bar_vibration(obj, dt):
    """Flex a struck bar in a fast-decaying oscillation, ring by ring, so
    the ends and centre visibly move while the node-point rings (0 in
    VIB_MODE_SHAPE by construction) stay put — a stand-in for the real
    fundamental bending mode, sized to match the mallet strike's new hard,
    sharp attack rather than a slow gentle touch."""
    amp = VIB_AMPLITUDE * math.exp(-dt / VIB_DECAY_TAU) * math.cos(2.0 * math.pi * VIB_FREQ * dt)
    mesh = obj.data
    for v, vert in enumerate(mesh.vertices):
        vert.co.z = bar_rest_z(mesh, v) + VIB_MODE_SHAPE[v // 4] * amp
    mesh.update()


def reset_bar_mesh(obj):
    mesh = obj.data
    for v, vert in enumerate(mesh.vertices):
        vert.co.z = bar_rest_z(mesh, v)
    mesh.update()


def main():
    args = parse_args()
    t0 = time.time()

    clear_scene()
    bars, pitch_to_idx, n_bars, bar_info, half_width = build_bars()
    post_x_left = bar_info[0]["x"] - FRAME_MARGIN
    post_x_right = bar_info[-1]["x"] + FRAME_MARGIN
    build_strings(bar_info, post_x_left, post_x_right)
    build_frame(bar_info, post_x_left, post_x_right)
    build_resonators(bar_info, n_bars)
    build_stage(2.0 * half_width)

    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 960
    scene.render.resolution_y = 540
    scene.render.fps = FPS
    scene.view_settings.view_transform = 'Standard'
    scene.render.image_settings.file_format = 'PNG'

    notes = load_features_array(args.npy, args.tempo, voice=5)
    notes[:, 1] = [pb.bucket_cents(p) for p in notes[:, 1]]

    assignments, n_slots = assign_mallet_slots(notes, pitch_to_idx)
    pivots, sticks, heads = build_mallet_pool(n_slots)

    out_dir = Path(args.out)
    out_dir.mkdir(exist_ok=True)

    n_frames = int(np.ceil(args.duration * FPS))
    print(f"[blender marimba] {n_frames} frames, {len(bars)} bars, {len(notes)} notes, "
          f"{n_slots} mallet slots")

    render_t0 = time.time()
    vibrating = set()   # bar indices whose mesh currently has a non-zero flex
    for fi in range(n_frames):
        t = fi / FPS
        glow = compute_bar_glow(t, notes, pitch_to_idx, n_bars)
        for i, obj in enumerate(bars):
            obj.color = bar_object_color(i, n_bars, glow[i])

        last_onset = compute_last_onset(t, notes, pitch_to_idx, n_bars)
        still_vibrating = set()
        for i in np.nonzero(~np.isnan(last_onset))[0]:
            dt = t - last_onset[i]
            if dt < VIB_CUTOFF:
                apply_bar_vibration(bars[i], dt)
                still_vibrating.add(int(i))
        for i in vibrating - still_vibrating:
            reset_bar_mesh(bars[i])
        vibrating = still_vibrating

        update_mallet_pool(t, assignments, n_slots, pivots, sticks, heads, bar_info)

        scene.render.filepath = str(out_dir / f"frame_{fi:06d}.png")
        bpy.ops.render.render(write_still=True)
        if fi % 30 == 0:
            elapsed = time.time() - render_t0
            print(f"  frame {fi}/{n_frames}  t={t:.2f}s  elapsed={elapsed:.1f}s")

    render_total = time.time() - render_t0
    print(f"[blender marimba] done: {n_frames} frames in {render_total:.1f}s "
          f"({render_total / max(n_frames, 1):.3f}s/frame), "
          f"total script time {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
