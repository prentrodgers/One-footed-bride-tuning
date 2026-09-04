#!/usr/bin/env python3
"""
blender_pizzicato_poc.py — first Blender/bpy prototype for the string
section (string_section_poc.py's 4 players: Cello/Viola/Martele-violin/
Violin, pizzicato + martele), following the same pattern as
blender_marimba_poc.py: a real 3D scene (camera, lighting, EEVEE render)
instead of the matplotlib cabinet-projection + tilt-transform trick.

Bodies, necks, scrolls, bridges, tailpieces and strings; strings brighten
on note-glow and bend into a standing wave when vibrating (shortened to
the stopped length via string_length.vibrating_length_fraction, same
physics as the matplotlib version); a stopping finger holds the fingerboard
position while a note is fingered; a plucking finger approaches, plucks,
and retracts for pizzicato notes (voices 2/3/4). Martele (voice 9, the bow)
has no bow prop yet — its strings still glow/stop/vibrate normally.

string_section_poc.py imports matplotlib at module level (not available in
Blender's bundled Python), so the pure-numpy note-loading/string-selection
logic is duplicated here rather than imported — see marimba's note on the
same tradeoff. string_length.py has no such dependency and is imported
directly.

bpy only exists inside Blender's own Python, so this must be run via the
Blender executable, not plain python3:

  blender --background --python blender_pizzicato_poc.py -- \\
      --npy bwv253_features_array.npy --tempo 100 --duration 5.0 \\
      --out blender_pizzicato_frames
"""
import argparse
import math
import sys
import time
from pathlib import Path

import bpy
import bmesh
import mathutils
import numpy as np

REPO_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_DIR))

import string_length as sl

FPS = 30
GLOW_DECAY = 0.26

PIZZ_VOICES   = frozenset([2, 3, 4])
MARTEL_VOICES = frozenset([9])
ALL_VOICES    = PIZZ_VOICES | MARTEL_VOICES

# ── Instrument specs, in metres (real-world body/neck proportions) ─────────
INST_SPEC = {
    'violin': dict(body_len=0.355, body_w=0.205, waist=0.50, depth=0.045,
                   neck_len=0.130, neck_w=0.028, scroll_r=0.013,
                   str_s=0.011, wood=(0.30, 0.13, 0.07),
                   open_cents=[4300, 5000, 5700, 6400]),
    'viola':  dict(body_len=0.400, body_w=0.235, waist=0.51, depth=0.050,
                   neck_len=0.145, neck_w=0.031, scroll_r=0.015,
                   str_s=0.0125, wood=(0.27, 0.11, 0.06),
                   open_cents=[3600, 4300, 5000, 5700]),
    'cello':  dict(body_len=0.755, body_w=0.445, waist=0.52, depth=0.115,
                   neck_len=0.280, neck_w=0.046, scroll_r=0.023,
                   str_s=0.020, wood=(0.23, 0.09, 0.045),
                   open_cents=[2400, 3100, 3800, 4500]),
}

# Laid out along X (row direction, matching the marimba scene's
# convention) with a real edge-to-edge gap between adjacent bodies rather
# than uniform centre spacing — cello/viola/violin bodies are quite
# different widths, so equal centre spacing gives very unequal gaps.
# PLAYER_SPACING is the centre-to-centre spacing between two hypothetical
# equal-width instruments it's derived from; GAP_SCALE shrinks the actual
# gap it implies for each pair (0.5 = half the original gap, i.e. brought
# noticeably closer together without touching).
PLAYER_SPACING = 1.1
GAP_SCALE = 0.5
# String-quartet seating, left to right: violin, viola, cello (2nd from the
# right), violin — the two violins on the ends, viola inside-left, cello
# inside-right, as in a real quartet.
PLAYERS = [
    dict(id=2, name='Martele', voice=9, inst='violin'),
    dict(id=1, name='Viola',   voice=3, inst='viola'),
    # The pizzicato section is placed at a bigger stage scale than the bowed
    # section (6.60 vs 5.60), which made this cello visibly larger than the
    # bowed cello beside it; shrink it by that ratio so the two match.
    dict(id=0, name='Cello',   voice=4, inst='cello', size=5.60 / 6.60),
    dict(id=3, name='Violin',  voice=2, inst='violin'),
]


def layout_players(players, gap_scale=1.0):
    half_widths = [INST_SPEC[p['inst']]['body_w'] / 2.0 for p in players]
    xs = [0.0]
    for i in range(1, len(players)):
        gap = PLAYER_SPACING - half_widths[i - 1] - half_widths[i]
        xs.append(xs[-1] + half_widths[i - 1] + gap * gap_scale + half_widths[i])
    offset = (xs[0] + xs[-1]) / 2.0
    for p, xv in zip(players, xs):
        p['x'] = xv - offset


def quartet_seating(players, back=0.50, yaw_deg=27.0):
    """Typical string-quartet seating: the inner viola/cello sit slightly
    upstage of the outer violins, and each player is turned a little toward
    the middle of their own quartet (turn grows with distance from centre).
    Sets pl['y'] / pl['yaw'], which build_player applies to the finished
    instrument."""
    xmax = max(abs(p['x']) for p in players) or 1.0
    for p in players:
        p['y'] = back if p['inst'] in ('viola', 'cello') else 0.0
        p['yaw'] = math.radians(-yaw_deg * p['x'] / xmax)


layout_players(PLAYERS, gap_scale=GAP_SCALE)
# The end violin was stranded out on its own — close its gap to the next
# player by 38% (the other three keep the spacing layout_players gave them).
# It sits a row forward of the viola, so perspective pushes it further out
# than the raw spacing suggests; 38% is what evens up the on-screen gaps.
PLAYERS[0]['x'] += 0.38 * (PLAYERS[1]['x'] - PLAYERS[0]['x'])
quartet_seating(PLAYERS)

STRING_REACH = 2400   # cents — how far above a string's open pitch it's playable


def _note_to_str(pitch_cents, inst_type):
    """Which of the 4 strings (0=lowest) would actually play this pitch —
    duplicated from string_section_poc.py (pure numpy, see module note)."""
    opens = INST_SPEC[inst_type]['open_cents']
    for i, op in enumerate(opens):
        if -50 <= pitch_cents - op <= STRING_REACH:
            return i
    return int(np.argmin([abs(pitch_cents - op) for op in opens]))


def load_string_voices(npy_file, tempo, voices=None):
    """Notes as [start_s, pitch_cents, dur_s, vel, vol, voice_id] —
    duplicated from string_section_poc.py (pure numpy, see module note)."""
    if voices is None:
        voices = ALL_VOICES
    arr = np.load(npy_file)
    mask = (arr[:, 5] > 0) & (arr[:, 2] > 0) & (arr[:, 14] > 0) & (arr[:, 3] > 0)
    vm = np.zeros(len(arr), dtype=bool)
    for v in voices:
        vm |= (arr[:, 6].astype(int) == v)
    mask &= vm
    arr = arr[mask]
    if not len(arr):
        return np.zeros((0, 6))

    bps = tempo / 60.0
    notes = np.column_stack([
        arr[:, 1] / bps, arr[:, 5] * 1200 + arr[:, 4], arr[:, 2] / bps,
        arr[:, 3], arr[:, 14], arr[:, 6],
    ])
    return notes[notes[:, 0].argsort()]


def build_player_note_sets(notes, players):
    sets = {p['id']: [] for p in players}
    for row in notes:
        v = int(row[5])
        for pl in players:
            if pl['voice'] == v:
                sets[pl['id']].append(row)
                break
    return {k: (np.array(v) if v else np.zeros((0, 6))) for k, v in sets.items()}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--npy", required=True)
    p.add_argument("--tempo", type=float, required=True)
    p.add_argument("--duration", type=float, required=True)
    p.add_argument("--out", default="blender_pizzicato_frames")
    return p.parse_args(argv)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ── Body geometry: an extruded hourglass silhouette (same profile as
# string_section_poc._body_outline), giving a real violin-family outline
# instead of a squashed sphere. ──────────────────────────────────────────

def _catmull_rom(pts, n_per_seg=8):
    """Sample a Catmull-Rom spline through pts (tuples of any dimension):
    a smooth curve that passes through every control point. End tangents
    come from the first/last chord, so the curve starts and ends straight
    rather than hooking."""
    P = [np.asarray(p, dtype=float) for p in pts]
    if len(P) < 2:
        return [tuple(p) for p in P]
    out = []
    for i in range(len(P) - 1):
        p0 = P[i - 1] if i > 0 else P[0] + (P[0] - P[1])
        p1, p2 = P[i], P[i + 1]
        p3 = P[i + 2] if i + 2 < len(P) else P[-1] + (P[-1] - P[-2])
        for k in range(n_per_seg):
            t = k / n_per_seg
            q = 0.5 * (2.0 * p1 + (p2 - p0) * t
                       + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
                       + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t)
            out.append(tuple(float(v) for v in q))
    out.append(tuple(float(v) for v in P[-1]))
    return out


OUTLINE_SAMPLES = 6   # spline samples per control-point interval


def body_right_profile(bw, bh, waist):
    """The right-hand half of the body outline, (x, z) ordered from the
    top-centre (z=bh) down to the bottom-centre (z=-bh) — shared by
    body_outline_points(), body_edge_x_at_z() and plate_bump().

    Three smooth curves joined at the two corner tips: the upper bout,
    the concave C-bout (narrowest at waist*bw), and the wider lower bout,
    in the proportions of a real violin-family body — upper bout ~0.82 of
    the lower one, corners about a quarter of the way out from the
    centre, the lower bout widest ~60% of the way down. The short hook
    just before each corner tip is what makes the corner read as a point
    rather than a kink in an otherwise round outline. A ghost point past
    each end (the mirror of the second point) keeps the tangent level
    across the centre line, so the two halves meet without a peak."""
    w = waist
    n = OUTLINE_SAMPLES
    upper = [(-0.36 * bw, 0.955 * bh),
             (0.00, bh), (0.36 * bw, 0.955 * bh), (0.70 * bw, 0.80 * bh),
             (0.82 * bw, 0.58 * bh), (0.75 * bw, 0.37 * bh), (0.70 * bw, 0.29 * bh),
             (0.74 * bw, 0.235 * bh)]
    cbout = [(0.74 * bw, 0.235 * bh), (0.60 * bw, 0.17 * bh), (w * bw, 0.02 * bh),
             (0.60 * bw, -0.15 * bh), (0.78 * bw, -0.245 * bh)]
    lower = [(0.78 * bw, -0.245 * bh), (0.75 * bw, -0.30 * bh), (0.88 * bw, -0.42 * bh),
             (1.00 * bw, -0.60 * bh), (0.92 * bw, -0.81 * bh), (0.58 * bw, -0.96 * bh),
             (0.00, -bh), (-0.58 * bw, -0.96 * bh)]
    up = _catmull_rom(upper, n)[n:]                        # drop the ghost interval
    cb = _catmull_rom(cbout, n)[1:]
    lo = _catmull_rom(lower, n)[1:(len(lower) - 2) * n + 1]
    return [(max(0.0, x), z) for x, z in up + cb + lo]


def body_outline_points(bw, bh, waist):
    right = body_right_profile(bw, bh, waist)
    left = [(-x, z) for x, z in reversed(right[1:-1])]
    return right + left


def body_edge_x_at_z(z, bw, bh, waist):
    """The body's right-edge x-offset at height z, linearly interpolated
    between the outline's sample points."""
    right = body_right_profile(bw, bh, waist)
    for (x0_, z0_), (x1_, z1_) in zip(right, right[1:]):
        if z1_ <= z <= z0_:
            if z0_ == z1_:
                return max(x0_, x1_)
            t = (z0_ - z) / (z0_ - z1_)
            return x0_ + (x1_ - x0_) * t
    return right[-1][0]


def dome_bump(z, bh, arch_depth):
    """How far the arched top or back plate bulges out from the flat rim
    on the centre line at height z — 0 at the top/bottom edges (z=+-bh),
    maximum (arch_depth) at the vertical centre. A parabolic stand-in for
    the real longitudinal arching profile, used both to build the domed
    body mesh and to seat everything mounted on the centre line (strings,
    bridge, fingerboard, tailpiece) flush on that surface."""
    frac = max(-1.0, min(1.0, z / bh)) if bh else 0.0
    return arch_depth * (1.0 - frac * frac)


def plate_bump(x, z, bw, bh, waist, arch_depth):
    """dome_bump() carried across the plate: full height on the centre
    line, falling to zero at the rim. The (1-u^2)^0.65 cross-section keeps
    the crown broad and turns down only near the edge, which is what a
    carved plate does. Seats off-centre parts (the f-holes, bridge feet)."""
    edge = body_edge_x_at_z(z, bw, bh, waist)
    u = min(1.0, abs(x) / edge) if edge > 1e-6 else 1.0
    return dome_bump(z, bh, arch_depth) * (1.0 - u * u) ** 0.65


# Inset factors of the concentric outline copies each arched plate is built
# from (1.0 = the rim, then closing on a centre vertex). Denser near the rim,
# where the arching turns down fastest.
BODY_ARCH_RINGS = (1.0, 0.965, 0.91, 0.83, 0.72, 0.58, 0.42, 0.24)


def make_body_mesh(name, bw, bh, waist, depth, arch_depth):
    """Ribs extruded straight between the two plates; each plate is a set
    of concentric, inset copies of the outline lifted to plate_bump(), so
    the arching is carried across the plate as well as along it (a single
    centre vertex fanned to the rim, as before, is a pyramid, not a carved
    plate). Faces are smooth-shaded with edges over ~40 degrees kept
    sharp, so the plate/rib corner stays crisp."""
    outline = body_outline_points(bw, bh, waist)
    n = len(outline)
    front_y, back_y = -depth / 2.0, depth / 2.0
    verts, faces = [], []

    def plate(sign, y0):
        rings = []
        for s in BODY_ARCH_RINGS:
            rings.append(len(verts))
            for x, z in outline:
                xs, zs = x * s, z * s
                verts.append((xs, y0 + sign * plate_bump(xs, zs, bw, bh, waist, arch_depth), zs))
        centre = len(verts)
        verts.append((0.0, y0 + sign * arch_depth, 0.0))
        for a, b in zip(rings, rings[1:]):
            for i in range(n):
                j = (i + 1) % n
                faces.append((a + i, a + j, b + j, b + i))
        last = rings[-1]
        for i in range(n):
            j = (i + 1) % n
            faces.append((last + i, last + j, centre))
        return rings[0]

    f0 = plate(-1, front_y)
    b0 = plate(+1, back_y)
    for i in range(n):
        j = (i + 1) % n
        faces.append((f0 + i, f0 + j, b0 + j, b0 + i))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    for f in mesh.polygons:
        f.use_smooth = True
    try:
        mesh.set_sharp_from_angle(angle=math.radians(40.0))
    except AttributeError:
        pass
    return mesh


def make_wood_material(name, wood):
    """Figured wood: a noise field stretched along the object's z (the grain
    runs the length of a plate, a neck, a peg) through a two-colour ramp
    around the given wood colour. A flat colour under the studio varnish
    coat read as moulded plastic. Object coordinates, so primitives that
    use it must have their scale applied (see build_player) or the grain
    density changes with the object's scale."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (90.0, 90.0, 5.0)
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 1.0
    noise.inputs["Detail"].default_value = 7.0
    noise.inputs["Roughness"].default_value = 0.55
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    dark = tuple(min(1.0, c * 0.55) for c in wood)
    light = tuple(min(1.0, c * 1.30) for c in wood)
    ramp.color_ramp.elements[0].position = 0.36
    ramp.color_ramp.elements[0].color = (*dark, 1.0)
    ramp.color_ramp.elements[1].position = 0.64
    ramp.color_ramp.elements[1].color = (*light, 1.0)
    nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    nt.links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.45
    return mat


def make_string_glow_material(name="StringMetal", glow_strength=3.0):
    """Shared string material: metal (steel, or silver/bronze winding) whose
    colour comes from each object's own Object Color, plus emission whose
    strength comes from that colour's alpha — 0 at rest, 1 on a note — so
    a sounding string flares while the rest stay lit-and-shadowed metal.
    (Was a bare emission, which read as a glowing grey cord.)"""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    info = nt.nodes.new("ShaderNodeObjectInfo")
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = 'MULTIPLY'
    mul.inputs[1].default_value = glow_strength
    nt.links.new(info.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(info.outputs["Color"], bsdf.inputs["Emission Color"])
    nt.links.new(info.outputs["Alpha"], mul.inputs[0])
    nt.links.new(mul.outputs["Value"], bsdf.inputs["Emission Strength"])
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.32
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


STRING_REST_COLOR = [
    (0.66, 0.60, 0.44), (0.62, 0.58, 0.45),      # wound G and D: silver-bronze
    (0.62, 0.63, 0.66), (0.74, 0.75, 0.78),      # A, and a bright steel E
]
STRING_GLOW_COLOR = (0.75, 0.68, 0.45)

# Fraction of body depth used as the arched-top bulge (dome_bump's peak) —
# real violin-family tops/backs are arched, not flat plates.
ARCH_FRACTION = 0.42

# ── Gesture / vibration timing — same values as string_section_poc.py, so
# the feel matches the matplotlib version it's replacing.
N_STRING_PTS = 20
STRING_RADIUS = 0.0016     # ~1% of the body length was a rope; a real string is 0.2%
BRIDGE_SPACING_FACTOR = 2.5   # bridge string spacing is ~2.5x the nut spacing on a real instrument
VIB_AMPLITUDE = 0.012   # m — visual side-to-side wiggle at full amplitude
VIB_FREQ      = 8.0     # visual Hz, same as string_section_poc.py
TAU_PIZZ      = 0.28
TAU_MARTEL    = 0.10

PLK_ARM   = 0.05    # m — finger rest distance from the string
PLK_APP_T = 0.055
PLK_DWL_T = 0.025
PLK_RET_T = 0.130

# Both the pluck (pizzicato) and the bow (martele) contact the string a
# little way above the bridge, not on it — the bridge itself is a node
# (it doesn't vibrate), so plucking/bowing exactly there wouldn't sound.
# Nearer the bridge gives a sharper tone (ponticello), farther away a
# mellower one; this is a fixed fraction of the *open*-string length
# above the bridge, not the currently-stopped length, since a player's
# plucking/bowing hand sits at a roughly fixed physical spot regardless
# of where the other hand is fingering.
CONTACT_ABOVE_BRIDGE_FRAC = 0.07

FINGER_R = 0.007
STOP_FINGER_COLOR = (0.85, 0.72, 0.58)
VOICE_CLR = {
    2: (0.80, 0.70, 0.55),   # violin pizz — warm ivory
    3: (0.65, 0.72, 0.60),   # viola pizz — muted sage
    4: (0.70, 0.58, 0.45),   # cello pizz — warm tan
    9: (0.70, 0.72, 0.90),   # martele bow hair highlight (unused directly)
}

# ── Bow (martele) — a real bow silhouette, not just a sweeping bar: stick,
# hair, a fine-pointed tip, frog, screw and eye. Sized smaller than a real
# ~0.74m bow so it reads well against these instruments' scale.
BOW_APP_T = 0.028
BOW_DWL_T = 0.052
BOW_RET_T = 0.075
BOW_SWEEP = 0.015    # m — how far the contact point slides during a martele stroke
BOW_TILT_DEG = 12.0   # degrees the stick pitches away from the string plane,
                       # so only the string at the contact point is touched
# Sustained (arco) bowing — the bow stays on the string for the whole note,
# sliding back and forth in a long continuous stroke (unlike the martele flick).
BOW_STROKE_T = 1.0        # s per half-stroke (a slow, sustained draw)
BOW_SUSTAIN_SWEEP = 0.34  # m — frog-to-tip travel of a full sustained stroke,
                          # just short of the 0.38 m hair so contact stays on it
TAU_ARCO_REL = 0.14       # s — string-vibration release after the bow lifts
                       # rather than the hair lying flat across all four

BOW_LEN       = 0.46     # full-length bow — longer than the violin body, as in life
BOW_FROG_LEN  = 0.048
BOW_TIP_LEN   = 0.032
BOW_STICK_R   = 0.0095   # much thicker so the bow clearly reads at stage distance
BOW_HAIR_W    = 0.015
BOW_FROG_W    = 0.007
BOW_FROG_H    = 0.006
BOW_SCREW_R   = 0.0032
BOW_EYE_R     = 0.0016
BOW_STICK_GAP = 0.0045   # local Z offset between the hair and the stick above it


def make_hole_material(name):
    """Pure unlit black — used for f-holes so they read as a dark opening
    into the body rather than a lit, shaded, raised decal (a Principled
    BSDF surface picks up highlights/shadow gradients from the scene
    lights that make a thin proud shape look like a raised bump, not a
    hole)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emission = nt.nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    emission.inputs["Strength"].default_value = 0.0
    nt.links.new(emission.outputs["Emission"], out.inputs["Surface"])
    return mat


def make_finger_material(name, color):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.55
    return mat


def string_rest_y(z, str_top, bridge_z, str_bot, nut_y, bridge_y, tail_y):
    """A real string is taut, under tension — it does not drape over the
    arched body. It's two straight segments meeting at the bridge (the
    only place its height actually changes): nut -> bridge, then
    bridge -> tailpiece."""
    if z >= bridge_z:
        t = (z - bridge_z) / max(str_top - bridge_z, 1e-9)
        return bridge_y + (nut_y - bridge_y) * t
    t = (bridge_z - z) / max(bridge_z - str_bot, 1e-9)
    return bridge_y + (tail_y - bridge_y) * t


def string_rest_x(z, str_top, bridge_z, nut_x, bridge_x):
    """Strings fan out from a narrow spacing at the nut to a wider one at
    the bridge (real nut spacing is roughly a third of the bridge
    spacing) — straight in X same as in Y, and constant from the bridge
    down to the tailpiece."""
    if z >= bridge_z:
        t = (z - bridge_z) / max(str_top - bridge_z, 1e-9)
        return bridge_x + (nut_x - bridge_x) * t
    return bridge_x


def build_string_curve(name, str_top, str_bot, mat, nut_x, bridge_x, nut_y, bridge_z, bridge_y, tail_y):
    """A POLY curve sampled along the string's length, bevelled into a thin
    tube — unlike a rigid cylinder, its points can be bent per-frame into a
    standing-wave shape once plucked/bowed. xs/ys are precomputed once (the
    string's straight taut rest position, fanning out toward the bridge)
    since they never change — only the per-frame X wiggle (on top of xs)
    does."""
    zs = np.linspace(str_top, str_bot, N_STRING_PTS)
    xs = np.array([string_rest_x(z, str_top, bridge_z, nut_x, bridge_x) for z in zs])
    ys = np.array([string_rest_y(z, str_top, bridge_z, str_bot, nut_y, bridge_y, tail_y) for z in zs])
    curve_data = bpy.data.curves.new(name, type='CURVE')
    curve_data.dimensions = '3D'
    curve_data.bevel_depth = STRING_RADIUS
    curve_data.bevel_resolution = 2
    spline = curve_data.splines.new('POLY')
    spline.points.add(N_STRING_PTS - 1)
    for i, z in enumerate(zs):
        spline.points[i].co = (xs[i], ys[i], z, 1.0)
    obj = bpy.data.objects.new(name, curve_data)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj, zs, xs, ys


def update_string_curve(curve_obj, zs, xs, ys, bridge_z, vib_top_z, amp, phase):
    """Bend the string into a standing wave between the bridge (fixed) and
    vib_top_z (the stop point — the nut itself for an open string) — zero
    outside that span, matching string_section_poc.py's wave_shape math.
    The wiggle rides on top of the string's own (fanned) rest position xs,
    not a single constant X."""
    span = max(vib_top_z - bridge_z, 1e-6)
    points = curve_obj.data.splines[0].points
    for i, z in enumerate(zs):
        if bridge_z <= z <= vib_top_z:
            wave = math.sin(math.pi * (z - bridge_z) / span)
        else:
            wave = 0.0
        x = xs[i] + VIB_AMPLITUDE * amp * wave * math.cos(phase)
        points[i].co = (x, ys[i], z, 1.0)
    curve_obj.data.update_tag()


def reset_string_curve(curve_obj, zs, xs, ys):
    points = curve_obj.data.splines[0].points
    for i, z in enumerate(zs):
        points[i].co = (xs[i], ys[i], z, 1.0)
    curve_obj.data.update_tag()


def build_bow(name):
    """A violin bow built along local +X (frog at -X, tip at +X), with
    local origin sitting on the hair's centreline — so positioning the
    returned pivot at a world contact point and pitching it around Y
    (BOW_TILT_DEG) touches just that point against the string plane while
    the rest of the stick lifts away, instead of a flat bar across all
    four strings. Built once at identity rotation and parented (matching
    the mallet-pivot pattern) so later rotating the pivot doesn't
    double-rotate the parts."""
    half_stick = (BOW_LEN - BOW_FROG_LEN - BOW_TIP_LEN) / 2.0
    gap = BOW_STICK_GAP

    pivot = bpy.data.objects.new(f"{name}_pivot", None)
    pivot.location = (0.0, 0.0, 0.0)
    bpy.context.scene.collection.objects.link(pivot)

    wood_mat  = make_wood_material(f"{name}_stick_mat", (0.45, 0.27, 0.12))
    hair_mat  = make_finger_material(f"{name}_hair_mat", (0.90, 0.88, 0.80))
    frog_mat  = make_finger_material(f"{name}_frog_mat", (0.04, 0.04, 0.04))
    metal_mat = make_finger_material(f"{name}_metal_mat", (0.75, 0.72, 0.58))
    eye_mat   = make_finger_material(f"{name}_eye_mat", (0.88, 0.86, 0.90))

    parts = []

    # Stick — cylinder's default axis is local Z; rotate 90 deg around Y
    # so it runs along local X instead.
    bpy.ops.mesh.primitive_cylinder_add(radius=BOW_STICK_R, depth=half_stick * 2.0,
                                         location=(0.0, 0.0, gap))
    stick = bpy.context.object
    stick.rotation_euler = (0.0, math.radians(90.0), 0.0)
    stick.name = f"{name}_stick"
    stick.data.materials.append(wood_mat)
    parts.append(stick)

    # Tip — tapered cone continuing past the stick's +X end, down to a
    # fine point.
    bpy.ops.mesh.primitive_cone_add(radius1=BOW_STICK_R, radius2=0.0002,
                                     depth=BOW_TIP_LEN,
                                     location=(half_stick + BOW_TIP_LEN / 2.0, 0.0, gap))
    tip = bpy.context.object
    tip.rotation_euler = (0.0, math.radians(90.0), 0.0)
    tip.name = f"{name}_tip"
    tip.data.materials.append(wood_mat)
    parts.append(tip)

    # Hair — thin flat ribbon from frog to tip, below the stick.
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.0))
    hair = bpy.context.object
    hair.scale = (half_stick, 0.0006, BOW_HAIR_W / 2.0)
    hair.name = f"{name}_hair"
    hair.data.materials.append(hair_mat)
    parts.append(hair)

    # Frog — block at the -X end, where the hair anchors and the player's
    # hand sits.
    frog_x = -half_stick - BOW_FROG_LEN / 2.0
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(frog_x, 0.0, gap))
    frog = bpy.context.object
    frog.scale = (BOW_FROG_LEN / 2.0, BOW_FROG_W / 2.0, BOW_FROG_H / 2.0)
    frog.name = f"{name}_frog"
    frog.data.materials.append(frog_mat)
    parts.append(frog)

    # Screw — small knob at the very back of the frog (the hair tensioner).
    screw_x = frog_x - BOW_FROG_LEN / 2.0 - BOW_SCREW_R * 0.6
    bpy.ops.mesh.primitive_uv_sphere_add(radius=BOW_SCREW_R, location=(screw_x, 0.0, gap))
    screw = bpy.context.object
    screw.name = f"{name}_screw"
    screw.data.materials.append(metal_mat)
    parts.append(screw)

    # Eye — small inlay disc on the frog's near face.
    bpy.ops.mesh.primitive_cylinder_add(radius=BOW_EYE_R, depth=0.0008,
                                         location=(frog_x, -BOW_FROG_W / 2.0 - 0.0004, gap))
    eye = bpy.context.object
    eye.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    eye.name = f"{name}_eye"
    eye.data.materials.append(eye_mat)
    parts.append(eye)

    for p in parts:
        p.parent = pivot
        p.matrix_parent_inverse = pivot.matrix_world.inverted()
        # Where this part sits along the bow at rest. Drawing the bow slides
        # every part along local X off these bases while the pivot — the point
        # touching the string — stays put; see update_bow_sustained.
        p["bow_x0"] = p.location.x
        p.hide_render = True

    return pivot, parts


def build_pegbox_assembly(name, x0, front_y, depth, neck_top_z, nw, wood_mat, sxs, str_top):
    """Peg box just above the neck, a scroll (+ a smaller volute sphere
    suggesting the curl) above that, 4 tuning pegs alternating left/right
    up the box, and a thin static line per string routing it from the nut
    (str_top, the top of the neck/fingerboard) up to its peg."""
    peg_box_len = nw * 6.5
    peg_box_w = nw * 1.05    # half-width; close to the neck's own for a seamless join
    peg_box_d = depth * 0.55
    peg_len = peg_box_w * 2.4
    peg_r = nw * 0.30
    knob_r = peg_r * 1.9

    box_bottom, box_top = neck_top_z, neck_top_z + peg_box_len
    # The pegbox narrows toward the scroll, as a real one does.
    w0, w1, hd = peg_box_w, peg_box_w * 0.72, peg_box_d / 2.0
    pverts = [(x0 - w0, -hd, box_bottom), (x0 + w0, -hd, box_bottom),
              (x0 + w0, hd, box_bottom), (x0 - w0, hd, box_bottom),
              (x0 - w1, -hd, box_top), (x0 + w1, -hd, box_top),
              (x0 + w1, hd, box_top), (x0 - w1, hd, box_top)]
    pfaces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    pmesh = bpy.data.meshes.new(f"{name}_pegbox_mesh")
    pmesh.from_pydata(pverts, [], pfaces)
    pmesh.update()
    pegbox = bpy.data.objects.new(f"{name}_pegbox", pmesh)
    bpy.context.scene.collection.objects.link(pegbox)
    pegbox.data.materials.append(wood_mat)

    # Scroll: a volute — a ribbon spiralling in from the back of the
    # pegbox top through 1.4 turns to the eye, its axis across the
    # instrument, so it reads as a spiral from the side and as the classic
    # curled head from the front. A little wider than the pegbox, as real
    # scrolls are (the "ears"), and thicker at the outer turn.
    R = nw * 1.35                   # outer turn ~45 mm across on a violin
    n_seg = 48
    a0, a1 = -math.pi / 2.0, 2.0 * math.pi + 0.5
    cy, cz = peg_box_d * 0.10, box_top + R * 0.95
    hw0, hw1 = w1, peg_box_w * 1.5  # pegbox width at the throat, the ears at the eye
    NC = 8                          # chamfered cross-section: reads carved, not sawn
    sverts, sfaces = [], []
    for k in range(n_seg + 1):
        t = k / n_seg
        a = a0 + (a1 - a0) * t
        r = R * (1.0 - 0.78 * t)
        thick = R * (0.42 - 0.22 * t)
        hw = hw0 + (hw1 - hw0) * (t * t * (3.0 - 2.0 * t))
        ch = min(hw, thick / 2.0) * 0.45
        sect = [(-hw + ch, -thick / 2.0), (hw - ch, -thick / 2.0), (hw, -thick / 2.0 + ch),
                (hw, thick / 2.0 - ch), (hw - ch, thick / 2.0), (-hw + ch, thick / 2.0),
                (-hw, thick / 2.0 - ch), (-hw, -thick / 2.0 + ch)]
        for dx, dr in sect:
            rr = r + dr
            sverts.append((x0 + dx, cy + rr * math.cos(a), cz + rr * math.sin(a)))
    for k in range(n_seg):
        b = NC * k
        for e in range(NC):
            f = (e + 1) % NC
            sfaces.append((b + e, b + f, b + NC + f, b + NC + e))
    sfaces.append(tuple(range(NC - 1, -1, -1)))
    last = NC * n_seg
    sfaces.append(tuple(range(last, last + NC)))
    smesh = bpy.data.meshes.new(f"{name}_scroll_mesh")
    smesh.from_pydata(sverts, [], sfaces)
    smesh.update()
    for f in smesh.polygons:
        f.use_smooth = True
    try:
        smesh.set_sharp_from_angle(angle=math.radians(40.0))
    except AttributeError:
        pass
    scroll = bpy.data.objects.new(f"{name}_scroll", smesh)
    bpy.context.scene.collection.objects.link(scroll)
    scroll.data.materials.append(wood_mat)

    # Each string routes to a peg on its *own* side of the centreline —
    # a string on the right never crosses to a peg on the left. Within a
    # side, the string closest to centre gets the peg nearest the nut
    # (the shortest, most direct path); the outer string gets the
    # farther peg. Both choices together keep the two same-side routing
    # lines from crossing each other.
    route_mat = make_finger_material(f"{name}_route_mat", (0.55, 0.55, 0.55))
    side_heights = np.linspace(box_bottom + peg_box_len * 0.22, box_bottom + peg_box_len * 0.82, 2)
    left_idx = sorted((si for si in range(4) if sxs[si] < x0), key=lambda si: x0 - sxs[si])
    right_idx = sorted((si for si in range(4) if sxs[si] >= x0), key=lambda si: sxs[si] - x0)

    for side, idx_list in ((-1.0, left_idx), (1.0, right_idx)):
        for pz, si in zip(side_heights, idx_list):
            pz = float(pz)
            # The shaft passes through the box, its tip just short of the
            # far wall, the handle out the near side.
            shaft = peg_len + 1.9 * peg_box_w
            peg_x = x0 + side * (peg_box_w + peg_len - shaft / 2.0)
            bpy.ops.mesh.primitive_cylinder_add(radius=peg_r, depth=shaft, location=(peg_x, 0.0, pz))
            peg = bpy.context.object
            peg.rotation_euler = (0.0, math.radians(90.0), 0.0)
            peg.name = f"{name}_peg{si}"
            peg.data.materials.append(wood_mat)

            knob_x = x0 + side * (peg_box_w + peg_len)
            bpy.ops.mesh.primitive_uv_sphere_add(radius=knob_r, location=(knob_x, 0.0, pz))
            knob = bpy.context.object
            knob.scale = (0.6, 1.0, 1.0)
            knob.name = f"{name}_pegknob{si}"
            knob.data.materials.append(wood_mat)

            # Strings wind around the peg's base — the end nearest the
            # pegbox's own centreline/wall — not the outer handle.
            nut_pt = mathutils.Vector((sxs[si], front_y, str_top))
            peg_base = mathutils.Vector((x0 + side * peg_box_w * 1.05, 0.0, pz))
            direction = peg_base - nut_pt
            bpy.ops.mesh.primitive_cylinder_add(radius=0.0012, depth=direction.length,
                                                 location=(nut_pt + peg_base) / 2.0)
            route = bpy.context.object
            route.rotation_euler = direction.to_track_quat('Z', 'Y').to_euler()
            route.name = f"{name}_route{si}"
            route.data.materials.append(route_mat)


def build_arched_ribbon(name, x0, front_y, z0, z1, half_w, half_thick,
                         bh, arch_depth, mat, gap=0.0012, n_seg=8, half_w1=None):
    """A flat ribbon that follows the body's arch along its z-extent
    (built from cross-section rings, same technique as the marimba bar
    mesh) instead of a single flat box that would float above the dome at
    one end and dig into it at the other. Used for the fingerboard.
    half_w1, if given, tapers the width linearly from half_w (at z0) to
    half_w1 (at z1) — a real fingerboard is noticeably narrower at the nut
    end than at the body end."""
    zs = np.linspace(z0, z1, n_seg)
    verts = []
    for i, z in enumerate(zs):
        yc = front_y - dome_bump(z, bh, arch_depth) - gap
        w = half_w if half_w1 is None else half_w + (half_w1 - half_w) * (i / (n_seg - 1))
        verts.append((x0 - w, yc - half_thick, z))
        verts.append((x0 + w, yc - half_thick, z))
        verts.append((x0 + w, yc + half_thick, z))
        verts.append((x0 - w, yc + half_thick, z))

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
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def build_fingerboard(name, x0, front_y, fb_bottom_z, fb_top_z, half_w_bottom, half_w_top, bh, arch_depth):
    """A black fingerboard laid over the neck, extending well onto the
    body at the bottom and running all the way up to meet the pegbox at
    the top (fb_top_z) — no gap between the neck and the scroll assembly.
    Tapers from half_w_bottom (wide, at the body end) to half_w_top
    (narrow, at the nut end) — a real fingerboard is noticeably narrower
    at the nut than where it meets the body.

    It has to fit entirely within the ~STRING_RADIUS-wide gap between the
    neck/body surface (front_y - dome_bump, where the neck and body meshes
    themselves sit) and the string's own front face (that same surface
    minus STRING_RADIUS) — any thicker or wrongly offset and it either
    sinks into the neck/body mesh or pokes out in front of the strings.
    half_thick and gap are sized (with a small margin each side) to fit
    inside that gap; gap is *positive* here, meaning the ribbon sits
    forward of the raw surface (toward the string) but strictly behind
    the string's own closest point."""
    mat = make_finger_material(f"{name}_fingerboard_mat", (0.03, 0.03, 0.03))
    half_thick = min(0.00125, STRING_RADIUS * 0.35)
    gap = STRING_RADIUS - half_thick - 0.0005   # 0.5mm clearance from the string
    build_arched_ribbon(f"{name}_fingerboard", x0, front_y, fb_bottom_z, fb_top_z,
                        half_w_bottom, half_thick, bh, arch_depth, mat, gap=gap,
                        half_w1=half_w_top)


def tail_outline_points(top_w, bottom_w, length):
    """z=0 at the narrow top end (near the bridge/saddle), z=-length at
    the wide, rounded bottom end (near the end button) — the tapered
    wedge/shield silhouette real tailpieces have, instead of a plain bar."""
    right = [
        (0.0, 0.0),
        (top_w * 0.5, -length * 0.10),
        (bottom_w * 0.46, -length * 0.60),
        (bottom_w * 0.50, -length * 0.85),
        (bottom_w * 0.30, -length * 0.98),
        (0.0, -length),
    ]
    left = [(-x, z) for x, z in reversed(right[1:-1])]
    return right + left


def build_tailpiece(name, x0, front_y, tail_top_z, tail_bottom_z, top_w, bottom_w,
                     bh, arch_depth, mat):
    length = tail_top_z - tail_bottom_z
    outline = tail_outline_points(top_w, bottom_w, length)
    n = len(outline)
    thick = 0.003
    verts_front, verts_back = [], []
    for x, dz in outline:
        z = tail_top_z + dz
        yc = front_y - dome_bump(z, bh, arch_depth) - 0.0015
        verts_front.append((x0 + x, yc - thick / 2.0, z))
        verts_back.append((x0 + x, yc + thick / 2.0, z))
    verts = verts_front + verts_back

    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    faces.append(tuple(range(n - 1, -1, -1)))
    faces.append(tuple(range(n, 2 * n)))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def bridge_outline_points(foot_w, top_w, height):
    """(x, h) with h=0 at the feet on the belly and h=height where the
    strings cross. Two feet with an arch between them, the flanks
    narrowing to a gently curved top."""
    right = [
        (0.00, 0.30 * height),
        (0.28 * foot_w, 0.30 * height),
        (0.40 * foot_w, 0.00),
        (0.50 * foot_w, 0.00),
        (0.46 * foot_w, 0.26 * height),
        (0.58 * top_w, 0.62 * height),
        (0.50 * top_w, 0.88 * height),
        (0.42 * top_w, height),
        (0.00, 1.04 * height),
    ]
    left = [(-x, z) for x, z in reversed(right[:-1])]
    return right[:-1] + [right[-1]] + left[1:]


def build_bridge(name, x0, foot_y, bridge_y, bridge_z, bridge_w, mat):
    """A real bridge stands on the belly: a thin plate perpendicular to
    the top, its feet at foot_y (the arched plate surface under them),
    its top edge at bridge_y — the height the taut strings kink at (see
    build_player). Its thickness is along the string, in z."""
    height = foot_y - bridge_y
    outline = bridge_outline_points(bridge_w * 0.85, bridge_w * 0.70, height)
    n = len(outline)
    thick = 0.0045
    verts_front = [(x0 + x, foot_y - h, bridge_z - thick / 2.0) for x, h in outline]
    verts_back = [(x0 + x, foot_y - h, bridge_z + thick / 2.0) for x, h in outline]
    verts = verts_front + verts_back

    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    faces.append(tuple(range(n - 1, -1, -1)))
    faces.append(tuple(range(n, 2 * n)))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def build_tail_extras(name, x0, front_y, depth, bh, bw, wood_mat, has_chinrest, arch_depth):
    """End button at the body's bottom tip (what the tailgut loops
    around), and — violin/viola only — a chin rest over the lower bout
    edge."""
    btn_r, btn_len = bw * 0.10, bw * 0.22
    btn_z = -bh - btn_len / 2.0
    bpy.ops.mesh.primitive_cylinder_add(
        radius=btn_r, depth=btn_len,
        location=(x0, depth * 0.15 - dome_bump(-bh, bh, arch_depth), btn_z))
    btn = bpy.context.object
    btn.name = f"{name}_endbutton"
    btn.data.materials.append(wood_mat)

    if has_chinrest:
        # Real chin rests run from around the tailpiece down to the very
        # bottom edge of the body, not a small centred blob.
        cr_top_z = -bh * 0.40
        cr_bottom_z = -bh * 0.99
        cr_center_z = (cr_top_z + cr_bottom_z) / 2.0
        cr_half_len = (cr_top_z - cr_bottom_z) / 2.0
        cr_y = front_y * 0.3 - dome_bump(cr_center_z, bh, arch_depth)
        cr_mat = make_finger_material(f"{name}_chinrest_mat", (0.05, 0.05, 0.05))
        cr_radius = bw * 0.30
        bpy.ops.mesh.primitive_uv_sphere_add(radius=cr_radius, location=(x0 + bw * 0.55, cr_y, cr_center_z))
        cr = bpy.context.object
        cr.scale = (1.0, 0.55, cr_half_len / cr_radius)
        cr.name = f"{name}_chinrest"
        cr.data.materials.append(cr_mat)


def build_f_holes(name, x0, front_y, bridge_z, bw, waist, bh, arch_depth, outer_string_offset):
    """Two mirrored f-holes, each a real f: an upper eye near the centre
    line, a lower eye out toward the edge, a slanted stem between them
    that bows gently (an S) and carries the two nicks at the bridge line.
    Sized and placed in body units (a violin's is ~78 mm long on a 355 mm
    body, upper eyes ~50 mm apart, lower eyes ~100 mm), so the viola and
    cello scale with their bodies. Unlit black, every vertex seated on
    the arched plate under it, so it reads as an opening, not a decal."""
    fmat = make_hole_material(f"{name}_fhole_mat")
    H = 0.22 * bh                          # half-length, eye centre to eye centre
    x_up, x_lo = 0.30 * bw, 0.52 * bw      # eye centres, from the centre line
    r_up, r_lo = 0.105 * H, 0.13 * H
    w_mid, w_end = 0.15 * H, 0.085 * H     # stem width: widest at the nicks
    lift = 0.0004

    for side in (1.0, -1.0):
        verts, faces = [], []

        def seat(u, v):
            x = x0 + side * u
            z = bridge_z + v
            y = front_y - plate_bump(x - x0, z, bw, bh, waist, arch_depth) - lift
            verts.append((x, y, z))
            return len(verts) - 1

        # Stem: from the inner-upper side of the lower eye to the
        # outer-lower side of the upper eye, bowing out then in.
        a = np.array((x_lo - 0.55 * r_lo, -H + 0.75 * r_lo))
        b = np.array((x_up + 0.55 * r_up, H - 0.75 * r_up))
        ctrl = [tuple(a),
                tuple(a + 0.28 * (b - a) + (0.012 * bw, 0.0)),
                tuple(a + 0.50 * (b - a)),
                tuple(a + 0.72 * (b - a) - (0.012 * bw, 0.0)),
                tuple(b)]
        line = _catmull_rom(ctrl, 6)
        m = len(line)
        ring = []
        for k, (u, v) in enumerate(line):
            u0, v0 = line[max(k - 1, 0)]
            u1, v1 = line[min(k + 1, m - 1)]
            d = np.array((u1 - u0, v1 - v0))
            d /= max(np.linalg.norm(d), 1e-9)
            nrm = (-d[1], d[0])
            w = w_end + (w_mid - w_end) * math.sin(math.pi * k / (m - 1))
            ring.append((seat(u - nrm[0] * w / 2, v - nrm[1] * w / 2),
                         seat(u + nrm[0] * w / 2, v + nrm[1] * w / 2)))
        for (p, q), (r, s) in zip(ring, ring[1:]):
            faces.append((p, q, s, r))

        # Nicks: two small teeth at the stem's midpoint, in and out.
        um, vm = line[m // 2]
        for tooth in (1.0, -1.0):
            base = w_mid * 0.30
            faces.append((seat(um, vm - base), seat(um, vm + base),
                          seat(um + tooth * 0.45 * w_mid, vm)))

        # Eyes.
        for (cu, cv, r) in ((x_up, H, r_up), (x_lo, -H, r_lo)):
            idx = [seat(cu + r * math.cos(t), cv + r * math.sin(t))
                   for t in np.linspace(0.0, 2.0 * math.pi, 18, endpoint=False)]
            faces.append(tuple(idx))

        mesh = bpy.data.meshes.new(f"{name}_fhole_mesh_{side}")
        mesh.from_pydata(verts, [], faces)
        mesh.update()
        obj = bpy.data.objects.new(f"{name}_fhole_{side}", mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(fmat)


def _seat_transform(pl, before, x0):
    """Swing a finished player about its own vertical axis (x=x0) and push it
    back in Y, by grouping everything the build just made under one Empty.
    The per-frame updates set object locations in the authored space, so they
    ride this transform for free — same trick the stage uses per section."""
    empty = bpy.data.objects.new(f"seat_{pl['name']}", None)
    bpy.context.scene.collection.objects.link(empty)
    empty.location = (x0, pl.get('y', 0.0), 0.0)
    empty.rotation_euler = (0.0, 0.0, pl.get('yaw', 0.0))
    s = pl.get('size', 1.0)
    empty.scale = (s, s, s)
    pinv = mathutils.Matrix.Translation((-x0, 0.0, 0.0))   # pivot on the player, not the origin
    for o in bpy.data.objects:
        if o not in before and o.parent is None and o is not empty:
            o.parent = empty
            o.matrix_parent_inverse = pinv


def build_player(pl, string_mat):
    inst = pl['inst']
    spec = INST_SPEC[inst]
    x0 = pl['x']
    before = set(bpy.data.objects)
    bw, bh = spec['body_w'] / 2.0, spec['body_len'] / 2.0
    depth = spec['depth']
    arch_depth = depth * ARCH_FRACTION
    wood_mat = make_wood_material(f"wood_{pl['name']}", spec['wood'])

    # Body — arched (domed) front/back, not a flat cardboard cutout.
    mesh = make_body_mesh(f"{pl['name']}_body_mesh", bw, bh, spec['waist'], depth, arch_depth)
    body = bpy.data.objects.new(f"{pl['name']}_body", mesh)
    bpy.context.scene.collection.objects.link(body)
    body.location = (x0, 0.0, 0.0)
    body.data.materials.append(wood_mat)

    # Neck (extends up from body top) — Y half-extent matches the body's
    # own front_y (was a much shallower depth*0.35, leaving the neck's
    # front face recessed well behind the body's front surface; that gap
    # is exactly where the fingerboard/strings ended up sitting relative
    # to the neck, causing the layering bugs below).
    nw, nh = spec['neck_w'] / 2.0, spec['neck_len']
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x0, 0.0, bh + nh / 2.0))
    neck = bpy.context.object
    neck.scale = (nw * 2.0, depth, nh / 2.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    neck.name = f"{pl['name']}_neck"
    neck.data.materials.append(wood_mat)

    # Bridge/tailpiece geometry — nut at the top of the neck/fingerboard
    # (str_top, right where the pegbox begins), tailpiece near the body's
    # bottom (str_bot), bridge at the 6:1 nut:bridge to bridge:tailpiece
    # point (real violin-family proportion). The string itself (and the
    # fingerboard under it) now runs the whole nut-to-bridge length,
    # including the neck — not just the body portion — with only a short
    # routing segment continuing past the nut into the pegbox.
    str_top = bh + nh
    # The strings end on the tailpiece's top edge, ~55 mm below the bridge
    # on a violin — with the 6:1 rule below that puts the bridge at the
    # f-hole nicks, just under the C-bouts, where a real one stands.
    str_bot = -bh * 0.42
    bridge_z = str_top - (6.0 / 7.0) * (str_top - str_bot)

    # Strings fan out from a narrow spacing at the nut to a wider one at
    # the bridge. spec['str_s'] was already tuned (pre-fan) to look right
    # as the wide, visually-prominent spacing across most of the body —
    # i.e. it's the *bridge* width — so bridge_sxs keeps it as-is and sxs
    # (the nut) derives a narrower spacing from it, rather than the other
    # way round (multiplying str_s further out, as a first pass here did,
    # blew the bridge width out way past a real one).
    bridge_sxs = [x0 + (i - 1.5) * spec['str_s'] for i in range(4)]
    sxs = [x0 + (i - 1.5) * spec['str_s'] / BRIDGE_SPACING_FACTOR for i in range(4)]
    front_y = -depth / 2.0
    # A real bridge is tall specifically so the (straight, taut) string
    # clears the arched belly's peak everywhere between the bridge and the
    # nut/tailpiece — the body's dome peaks at its own geometric centre,
    # not at bridge_z, so using just the *local* dome height at bridge_z
    # (as a first pass here did) isn't enough clearance: the straight
    # chord from nut to bridge dips behind the dome's actual peak,
    # hiding the string behind the belly. 2x the peak arch depth is a
    # comfortable, checked-by-hand margin for these proportions.
    bridge_y = front_y - arch_depth * 2.2

    # Where the pluck/bow actually contacts the string — a little above
    # the bridge (see CONTACT_ABOVE_BRIDGE_FRAC), not on it.
    contact_z = bridge_z + (str_top - bridge_z) * CONTACT_ABOVE_BRIDGE_FRAC
    contact_y = string_rest_y(contact_z, str_top, bridge_z, str_bot, front_y, bridge_y, bridge_y)
    contact_sxs = [string_rest_x(contact_z, str_top, bridge_z, sxs[si], bridge_sxs[si]) for si in range(4)]

    # Peg box, scroll, tuning pegs and string routing above the neck.
    build_pegbox_assembly(pl['name'], x0, front_y, depth, bh + nh, nw, wood_mat, sxs, str_top)

    # Nut — small pale ridge at str_top marking where the fingerboard ends
    # and the strings cross into the pegbox.
    nut_mat = make_finger_material(f"{pl['name']}_nut_mat", (0.80, 0.72, 0.56))
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x0, front_y - 0.0018, str_top))
    nut = bpy.context.object
    nut.scale = (nw * 2.3, 0.0025, 0.003)
    nut.name = f"{pl['name']}_nut"
    nut.data.materials.append(nut_mat)

    # Fingerboard — bridges the neck visually, and must reach far enough
    # down toward the bridge that every stop position a finger can
    # actually land at (down to sl.MIN_LENGTH_FRAC, the shortest/highest
    # stop string_length allows) still has fingerboard underneath it —
    # a stop with no fingerboard to press the string against wouldn't
    # work. Runs up to str_top, exactly where the nut/pegbox begins (no
    # floating gap), following the body's arch.
    fb_bottom_z = bridge_z + (str_top - bridge_z) * (sl.MIN_LENGTH_FRAC - 0.03)
    build_fingerboard(pl['name'], x0, front_y, fb_bottom_z, str_top, nw * 1.5, nw * 0.9, bh, arch_depth)

    # F-holes either side of the bridge, centred between the outermost
    # string *at the bridge* (the wider spacing) and the body's actual edge.
    outer_string_offset = 1.5 * spec['str_s']
    build_f_holes(pl['name'], x0, front_y, bridge_z, bw, spec['waist'], bh, arch_depth,
                  outer_string_offset)

    # End button, and (violin/viola only) a chin rest.
    build_tail_extras(pl['name'], x0, front_y, depth, bh, bw, wood_mat,
                       inst in ('violin', 'viola'), arch_depth)

    # Bridge — a real silhouette (feet, waist, flared top), not a flat
    # block. Real bridges are unstained maple — pale, not a darkened shade
    # of the body's own (dyed/varnished) wood.
    bridge_w = (bridge_sxs[-1] - bridge_sxs[0]) + 0.02
    bridge_mat = make_wood_material(f"bridge_{pl['name']}", (0.80, 0.72, 0.56))
    foot_y = front_y - plate_bump(bridge_w * 0.42, bridge_z, bw, bh, spec['waist'], arch_depth)
    build_bridge(f"{pl['name']}_bridge", (bridge_sxs[0] + bridge_sxs[-1]) / 2.0, foot_y, bridge_y,
                 bridge_z, bridge_w, bridge_mat)

    # Tailpiece — a tapered wedge, wide where the strings anchor along its
    # top edge and narrowing to the tailgut at the end button, from just
    # above the strings' end down to near the bottom tip.
    tail_top_z = str_bot + bh * 0.04
    tail_bottom_z = -bh * 0.95
    # Ebony, like the fingerboard — a darkened shade of the body wood
    # rendered as a pale wedge under the studio lights.
    tail_mat = make_wood_material(f"tail_{pl['name']}", (0.035, 0.03, 0.025))
    build_tailpiece(f"{pl['name']}_tailpiece", (sxs[0] + sxs[-1]) / 2.0, front_y,
                     tail_top_z, tail_bottom_z, bridge_w * 0.72, bridge_w * 0.42,
                     bh, arch_depth, tail_mat)

    # Strings — taut and straight (nut -> bridge, bridge -> tailpiece),
    # fanning out from the narrow nut spacing to the wide bridge spacing,
    # not draped over the arched body, so they can still bend into a
    # standing wave once plucked/bowed.
    tail_y = front_y - dome_bump(str_bot, bh, arch_depth)
    strings, str_zs, str_xs, str_ys = [], [], [], []
    for si, sx in enumerate(sxs):
        s, zs, xs, ys = build_string_curve(f"{pl['name']}_string{si}", str_top, str_bot, string_mat,
                                            sx, bridge_sxs[si], front_y, bridge_z, bridge_y, tail_y)
        s.color = (*STRING_REST_COLOR[si], 0.0)
        strings.append(s)
        str_zs.append(zs)
        str_xs.append(xs)
        str_ys.append(ys)

    # Stopping fingers — one per string, held on the fingerboard at the
    # stop point while that string sounds a note above its open pitch.
    stop_mat = make_finger_material(f"stopfinger_{pl['name']}", STOP_FINGER_COLOR)
    stop_fingers = []
    for si in range(4):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=FINGER_R, location=(sxs[si], front_y, str_top))
        f = bpy.context.object
        f.scale = (1.0, 0.6, 1.3)
        f.name = f"{pl['name']}_stopfinger{si}"
        f.data.materials.append(stop_mat)
        f.hide_render = True
        stop_fingers.append(f)

    # Plucking finger — pizzicato players only; one finger since a player
    # plucks with one hand.
    pluck = None
    if pl['voice'] in PIZZ_VOICES:
        pluck_mat = make_finger_material(f"pluckfinger_{pl['name']}", VOICE_CLR.get(pl['voice'], (0.8, 0.75, 0.65)))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=FINGER_R * 1.2, location=(contact_sxs[0], contact_y, contact_z))
        pluck = bpy.context.object
        pluck.scale = (0.7, 1.5, 1.0)
        pluck.name = f"{pl['name']}_pluckfinger"
        pluck.data.materials.append(pluck_mat)
        pluck.hide_render = True

    # Bow — the martele player, plus any player explicitly flagged pl['bow']
    # (the arco bowed-string section reuses this builder and asks for bows).
    bow_pivot, bow_parts = (None, None)
    if pl.get('bow') or pl['voice'] in MARTEL_VOICES:
        bow_pivot, bow_parts = build_bow(f"{pl['name']}_bow")

    if pl.get('y') or pl.get('yaw') or pl.get('size', 1.0) != 1.0:
        _seat_transform(pl, before, x0)

    return dict(sxs=sxs, bridge_sxs=bridge_sxs, str_top=str_top, str_bot=str_bot, bridge_z=bridge_z,
                front_y=front_y, bridge_y=bridge_y, bh=bh, arch_depth=arch_depth,
                contact_z=contact_z, contact_y=contact_y, contact_sxs=contact_sxs,
                strings=strings, str_zs=str_zs, str_xs=str_xs, str_ys=str_ys,
                bow_pivot=bow_pivot, bow_parts=bow_parts,
                stop_fingers=stop_fingers, pluck=pluck, open_cents=spec['open_cents'])


def point_camera_at(cam, target):
    direction = mathutils.Vector(target) - mathutils.Vector(cam.location)
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()


def build_floor(total_w, lowest_z):
    bpy.ops.mesh.primitive_plane_add(size=total_w * 1.3, location=(0.0, 0.0, lowest_z - 0.1))
    floor = bpy.context.object
    floor.name = "Floor"
    mat = bpy.data.materials.new("FloorMat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.04, 0.04, 0.05, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.8
    floor.data.materials.append(mat)


def build_stage(total_w, top_z, bottom_z):
    build_floor(total_w, bottom_z)

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 30
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = (0.0, -total_w * 0.85, top_z * 0.35)
    point_camera_at(cam, (0.0, 0.0, (top_z + bottom_z) * 0.15))
    bpy.context.scene.camera = cam

    sun_data = bpy.data.lights.new("Sun", type='SUN')
    sun_data.energy = 0.6
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.location = (1.5, -3.0, 4.0)
    sun.rotation_euler = (math.radians(45), 0, math.radians(25))
    bpy.context.scene.collection.objects.link(sun)

    fill_data = bpy.data.lights.new("Fill", type='AREA')
    fill_data.energy = 80.0
    fill_data.size = total_w * 0.3
    fill = bpy.data.objects.new("Fill", fill_data)
    fill.location = (-total_w * 0.3, -total_w * 0.4, top_z * 0.6)
    bpy.context.scene.collection.objects.link(fill)


def compute_player_state(t, notes, inst_type, arco=False):
    """Per-string glow/vibration-amplitude/onset/pitch, plus the most
    recent gesture. `arco=True` (sustained bowed strings) keeps the string
    sounding — glow and vibration held at full — for the WHOLE note instead
    of decaying like a pluck/martele, and reports `bow_note` (the note
    currently under the bow) so the bow can stay drawn for its full length."""
    str_glow = np.zeros(4)
    str_vib = np.zeros(4)
    str_onset = np.full(4, -999.0)
    str_pitch = np.full(4, np.nan)
    last_gest = None
    bow_note = None

    for row in notes:
        onset_t, pitch, dur_s, voice_id = row[0], row[1], row[2], int(row[5])
        si = _note_to_str(pitch, inst_type)
        dt = t - onset_t
        is_martel = voice_id in MARTEL_VOICES

        if arco:
            # Glow held while bowed, then a short release fade.
            if 0.0 <= dt <= dur_s:
                str_glow[si] = max(str_glow[si], 1.0)
            elif dt > dur_s and (dt - dur_s) < GLOW_DECAY:
                str_glow[si] = max(str_glow[si], 1.0 - (dt - dur_s) / GLOW_DECAY)
        elif 0.0 <= dt <= GLOW_DECAY:
            str_glow[si] = max(str_glow[si], 1.0 - dt / GLOW_DECAY)

        if dt > 0.0:
            if arco:
                # Continuous vibration while bowed; release after the note ends.
                amp = 1.0 if dt <= dur_s else math.exp(-(dt - dur_s) / TAU_ARCO_REL)
            else:
                tau = TAU_MARTEL if is_martel else TAU_PIZZ
                amp = math.exp(-dt / tau)
                if dt > dur_s:
                    cutoff = 0.10 if is_martel else 0.18
                    amp *= max(0.0, 1.0 - (dt - dur_s) / cutoff)
            if amp > str_vib[si]:
                str_vib[si] = amp
                str_onset[si] = onset_t
                str_pitch[si] = pitch

        # Note currently under the bow (sustained), latest onset wins.
        if arco and 0.0 <= dt < dur_s:
            if bow_note is None or onset_t > bow_note[0]:
                bow_note = (onset_t, dur_s, si)

        app_t = BOW_APP_T if is_martel else PLK_APP_T
        total_gest = ((BOW_APP_T + BOW_DWL_T + BOW_RET_T) if is_martel
                      else (PLK_APP_T + PLK_DWL_T + PLK_RET_T))
        if -app_t <= dt <= total_gest:
            if last_gest is None or onset_t > last_gest[0]:
                last_gest = (onset_t, si, voice_id)

    return dict(str_glow=str_glow, str_vib=str_vib, str_onset=str_onset,
                str_pitch=str_pitch, last_gest=last_gest, bow_note=bow_note)


def update_pluck_finger(pluck_obj, gest, contact_sxs, contact_z, contact_y, t):
    """contact_z/contact_y/contact_sxs are the point a little above the
    bridge (CONTACT_ABOVE_BRIDGE_FRAC) where the pluck actually happens —
    not the bridge itself, which is a node and wouldn't sound."""
    if gest is None:
        pluck_obj.hide_render = True
        return
    onset_t, si, _voice_id = gest
    dt = t - onset_t
    total = PLK_APP_T + PLK_DWL_T + PLK_RET_T
    if not (-PLK_APP_T <= dt <= total):
        pluck_obj.hide_render = True
        return

    sx_active = contact_sxs[si]
    if dt < 0:          # approaching from the side
        ph = ((dt + PLK_APP_T) / PLK_APP_T) ** 1.5
        gx = sx_active + PLK_ARM * (1.0 - ph)
    elif dt < PLK_DWL_T:   # at the string
        gx = sx_active
    else:                # retracting
        ph = min(1.0, (dt - PLK_DWL_T) / PLK_RET_T) ** 0.7
        gx = sx_active + PLK_ARM * ph
    pluck_obj.location = (gx, contact_y - 0.008, contact_z)
    pluck_obj.hide_render = False


def update_bow(bow_pivot, bow_parts, gest, contact_sxs, contact_z, contact_y, t):
    """See update_pluck_finger — same reasoning, just above the bridge."""
    if gest is None:
        for p in bow_parts:
            p.hide_render = True
        return
    onset_t, si, _voice_id = gest
    dt = t - onset_t
    total = BOW_APP_T + BOW_DWL_T + BOW_RET_T
    if not (-BOW_APP_T <= dt <= total):
        for p in bow_parts:
            p.hide_render = True
        return

    sx_active = contact_sxs[si]
    if dt < 0:              # approaching
        ph = (dt + BOW_APP_T) / BOW_APP_T
        bx = sx_active - BOW_SWEEP * 0.5 * ph
    elif dt < BOW_DWL_T:     # the stroke itself, sliding across
        ph = dt / BOW_DWL_T
        bx = sx_active - BOW_SWEEP * 0.5 + BOW_SWEEP * ph
    else:                    # lifting off
        bx = sx_active + BOW_SWEEP * 0.5

    # Pitching the stick around Y means only the contact point (the pivot,
    # placed exactly on the target string) actually meets the string
    # plane — the rest of the hair's length lifts away in Z, so the bow
    # visibly touches just this one string instead of lying flat across
    # all four.
    bow_pivot.location = (bx, contact_y - 0.008, contact_z)
    bow_pivot.rotation_euler = (0.0, math.radians(BOW_TILT_DEG), 0.0)
    for p in bow_parts:
        p.hide_render = False


def update_bow_sustained(bow_pivot, bow_parts, note, contact_sxs, contact_z, contact_y, t):
    """Sustained (arco) bow: stays on the sounding string for the whole note,
    drawing back and forth in a long continuous stroke (triangle wave) — not
    the quick one-shot flick of update_bow. `note` is (onset, dur, string)."""
    if note is None:
        for p in bow_parts:
            p.hide_render = True
        return
    onset, _dur, si = note
    sx = contact_sxs[si]
    phase = ((t - onset) / BOW_STROKE_T) % 2.0        # 0..2
    tri = phase if phase <= 1.0 else 2.0 - phase       # 0..1..0 triangle (down-bow/up-bow)
    # The contact point is fixed on the string — a real bow doesn't drag its
    # contact sideways. What travels is the BOW, sliding along its own length
    # through that point: tri=0 puts the frog on the string, tri=1 the tip.
    off = BOW_SUSTAIN_SWEEP * (0.5 - tri)
    bow_pivot.location = (sx, contact_y - 0.008, contact_z)
    bow_pivot.rotation_euler = (0.0, math.radians(BOW_TILT_DEG), 0.0)
    for p in bow_parts:
        p.location.x = p["bow_x0"] + off
        p.hide_render = False


def main():
    args = parse_args()
    t0 = time.time()

    clear_scene()
    string_mat = make_string_glow_material()

    notes = load_string_voices(args.npy, args.tempo)
    player_note_sets = build_player_note_sets(notes, PLAYERS)

    geoms = {}
    for pl in PLAYERS:
        pl['_notes'] = player_note_sets[pl['id']]
        geoms[pl['id']] = build_player(pl, string_mat)

    total_w = (PLAYERS[-1]['x'] - PLAYERS[0]['x']) + INST_SPEC['cello']['body_w'] * 2
    top_z = max(INST_SPEC[pl['inst']]['body_len'] / 2.0 + INST_SPEC[pl['inst']]['neck_len']
                + INST_SPEC[pl['inst']]['scroll_r'] * 2 for pl in PLAYERS)
    bottom_z = -max(INST_SPEC[pl['inst']]['body_len'] / 2.0 * 0.95 for pl in PLAYERS)
    build_stage(total_w, top_z, bottom_z)

    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 960
    scene.render.resolution_y = 540
    scene.render.fps = FPS
    scene.view_settings.view_transform = 'Standard'
    scene.render.image_settings.file_format = 'PNG'

    out_dir = Path(args.out)
    out_dir.mkdir(exist_ok=True)

    n_frames = int(np.ceil(args.duration * FPS))
    print(f"[blender pizzicato] {n_frames} frames, {len(PLAYERS)} players, {len(notes)} notes")

    render_t0 = time.time()
    for fi in range(n_frames):
        t = fi / FPS
        for pl in PLAYERS:
            geom = geoms[pl['id']]
            state = compute_player_state(t, pl['_notes'], pl['inst'])
            glow, vib = state['str_glow'], state['str_vib']
            st_on, st_pitch = state['str_onset'], state['str_pitch']

            for si, s in enumerate(geom['strings']):
                g, a = glow[si], vib[si]

                g_col = STRING_REST_COLOR[si]
                if g > 0.02:
                    base = np.array(STRING_REST_COLOR[si])
                    g_col = base + g * (np.array(STRING_GLOW_COLOR) - base)
                s.color = (*g_col, float(g))

                stopf = geom['stop_fingers'][si]
                if a > 0.005:
                    onset_t = st_on[si]
                    dt = t - onset_t
                    phase = 2.0 * math.pi * VIB_FREQ * dt
                    pitch = st_pitch[si]
                    length_frac = (sl.vibrating_length_fraction(pitch, geom['open_cents'][si])
                                   if not math.isnan(pitch) else 1.0)
                    vib_top_z = geom['bridge_z'] + length_frac * (geom['str_top'] - geom['bridge_z'])
                    update_string_curve(s, geom['str_zs'][si], geom['str_xs'][si], geom['str_ys'][si],
                                         geom['bridge_z'], vib_top_z, a, phase)
                    if length_frac < 0.98 and g > 0.05:
                        stop_x = string_rest_x(vib_top_z, geom['str_top'], geom['bridge_z'],
                                                geom['sxs'][si], geom['bridge_sxs'][si])
                        stop_y = geom['front_y'] - dome_bump(vib_top_z, geom['bh'], geom['arch_depth']) - 0.006
                        stopf.location = (stop_x, stop_y, vib_top_z)
                        stopf.hide_render = False
                    else:
                        stopf.hide_render = True
                else:
                    reset_string_curve(s, geom['str_zs'][si], geom['str_xs'][si], geom['str_ys'][si])
                    stopf.hide_render = True

            if geom['pluck'] is not None:
                update_pluck_finger(geom['pluck'], state['last_gest'],
                                     geom['contact_sxs'], geom['contact_z'], geom['contact_y'], t)
            if geom['bow_pivot'] is not None:
                update_bow(geom['bow_pivot'], geom['bow_parts'], state['last_gest'],
                            geom['contact_sxs'], geom['contact_z'], geom['contact_y'], t)

        scene.render.filepath = str(out_dir / f"frame_{fi:06d}.png")
        bpy.ops.render.render(write_still=True)
        if fi % 30 == 0:
            elapsed = time.time() - render_t0
            print(f"  frame {fi}/{n_frames}  t={t:.2f}s  elapsed={elapsed:.1f}s")

    render_total = time.time() - render_t0
    print(f"[blender pizzicato] done: {n_frames} frames in {render_total:.1f}s "
          f"({render_total / max(n_frames, 1):.3f}s/frame), "
          f"total script time {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
