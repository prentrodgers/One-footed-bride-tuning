"""
concert_piano.py - a piano stage: one grand piano and its pianist, centre stage in the Alcorcón hall
(concert_hall.py), everyone else hidden; cameras framed on the pianist.

    blender --background Alcorcon_Hall.blend --python concert_piano.py -- --out Alcorcon_Piano.blend
    blender --background Alcorcon_Piano.blend --python concert_stage.py -- --npy Uploads/b846ft_....npy \
        --tempo 60 --duration 114 --out frames_piano_b846ft [--engine cycles --cycles-hw-rt]

The source .blend is not changed. The new file carries its cast in "Stage Controls" ensemble_json, as
concert_duo.py's does, so concert_stage.py poses only the pianist and picks shots from these cameras;
render_farm.sh renders it with BLEND=Alcorcon_Piano.blend. The pianist is "Piano" in
concert_poses.PLAYERS; voice 29 (the Bosendorfer) plays it (concert_stage.VOICES).

The pianist sits facing stage left (the audience's right), as pianists do, so the open lid throws the
sound into the house. The rig is the empty "Piano" at the middle of the keyboard's front edge: local X
runs from the bass (the player's left, upstage) to the treble, local Y into the piano, local Z up.
The 88 keys are its children ("Piano Key <midi>"), each hinged at its back end; the case, lid, legs,
pedal lyre, music desk and the inside (plate and strings) are built around it. The bench is a
child-free box under the seated pianist, built where the layout puts them.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

REPO_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_DIR))
import concert_stagekit as sk        # noqa: E402
import concert_poses as cp           # noqa: E402
import concert_cameras as cc         # noqa: E402
import concert_restage as rs         # noqa: E402
import concert_duo as duo            # noqa: E402

KEY = "Piano"
FACING = (1.0, 0.0, 0.0)             # toward stage left (the audience's right)
PLAYER_POS = (-1.25, 0.25, 0.0)      # where the pianist sits (stage floor)
KEY_HEIGHT = 0.735                   # top of the white keys above the floor
KEY_REACH = 0.37                     # keyboard front edge this far in front of the seated player
LID_ANGLE = 52.0                     # degrees open, on the long stick

# Proportions of a Bösendorfer concert grand (the 280VC: 2.8 m long, 1.6 m wide, about 1.0 m to the top
# of the closed case), checked against side and front photographs: the case top stands 27 cm above the
# keys, the belly 11 cm below them; the key-block arms rise 10 cm above the keys and sweep up into the rim
# behind the fallboard, which stands as a tall glossy face behind the keys with the name in gold.
CASE_W = 0.78                        # half width of the case at the keyboard
RIM_FRONT = 0.06                     # the rim starts here, just behind the fallboard face
# the rim's outline in rig coordinates (x across, y into the piano), from the keyboard's treble corner
# round the bend and tail to the bass corner, then back along the straight bass side
RIM = [(0.78, RIM_FRONT), (0.78, 1.00), (0.72, 1.27), (0.58, 1.53), (0.42, 1.73), (0.30, 1.95), (0.24, 2.17),
       (0.14, 2.39), (-0.06, 2.55), (-0.30, 2.59), (-0.54, 2.53), (-0.70, 2.39), (-0.78, 2.21), (-0.78, RIM_FRONT)]
RIM_TOP, RIM_BOTTOM = 0.25, -0.11    # of the rim, relative to the key tops
RIM_T = 0.045                        # the rim's thickness
KEYBED_UNDER = -0.07                 # underside of the key bed: the rim's front wall stops here, below the keys
ARM_IN = 0.616                       # the key-block arms run from just outside the keys (±0.611) to the case side
ARM_FRONT, ARM_TOP = -0.20, 0.10     # the arms' front face (flush with the key slip) and their top
FALL_H = 0.13                        # the open fallboard's face behind the keys, this tall above the key tops
DESK_BACK = 0.55                     # the block over the action (the music desk stands on it) ends here...
LID_FRONT = DESK_BACK                # ... where the raised lid begins; its front flap is folded back on top
FLOOR = -KEY_HEIGHT
PLATE_TOP = RIM_TOP - 0.08           # the iron frame's top face, the strings just under it
STRING_Z = RIM_TOP - 0.11
SOUNDBOARD_Z = RIM_TOP - 0.25

CAMS = {   # name -> (location, target) in rig coordinates, lens
    "Cam 61 Piano Hands (treble end)": ((1.00, -0.62, 0.80), (-0.12, -0.05, 0.0), 40),   # steep enough to see the keys past the block
    "Cam 66 Piano Keys (along the keyboard)": ((0.92, -0.46, 0.22), (-0.05, -0.03, 0.04), 45),  # low at the treble end: keys, hands, fallboard
    "Cam 62 Piano Over the Shoulder": ((0.95, -1.30, 1.15), (-0.25, 0.02, -0.05), 32),   # the right shoulder: the lid is on the left
}
FACE_CAM = ("Cam 63 Piano Face", (1.45, 1.00, 0.28), 85)   # from beyond the bend, past the music desk's treble end: offset from the head (rig axes), lens
FIT_CAMS = {   # name -> (azimuth, elevation, lens), framed on the pianist and the piano (concert_cameras._fit)
    "Cam 60 Piano Full (lid side)": (38, 12, 42),
    "Cam 64 Piano High": (-30, 42, 35),
    "Cam 65 Piano (front)": (0, 14, 40),
}
WIDE = ["Cam 1 Audience Wide", "Cam 57 Hall Amphitheatre", "Cam 59 Hall Side Arch", "Cam 58 House from the Stage"]
DOLLIES = ["Cam 50 Dolly Front Row"]
DOLLY_RUN = (-2.9, 1.9)


def rig_matrix():
    p = Vector(PLAYER_POS)
    f = Vector(FACING).normalized()
    up = Vector((0, 0, 1))
    left = up.cross(f).normalized()
    x = -left                                     # bass on the player's left
    origin = p + f * KEY_REACH + up * KEY_HEIGHT
    return Matrix((x, f, up)).transposed().to_4x4() @ Matrix.Translation((0, 0, 0)), origin


def materials():
    return {
        "black": sk.mat("Piano Black", (0.012, 0.012, 0.014), rough=0.12, coat=1.0, spec=0.7),
        "ivory": sk.mat("Piano Ivory", (0.93, 0.91, 0.85), rough=0.35, spec=0.4),
        "ebony": sk.mat("Piano Ebony", (0.02, 0.02, 0.022), rough=0.3),
        "felt": sk.mat("Piano Felt", (0.55, 0.05, 0.06), rough=0.95),
        "brass": sk.mat("Piano Brass", (0.80, 0.62, 0.30), metal=0.9, rough=0.3),
        "plate": sk.mat("Piano Frame Copper-Gold", (0.92, 0.55, 0.20), metal=0.35, rough=0.3, coat=0.6),   # the copper-gold frame
        "rim_wood": sk.wood("Piano Rim Mahogany", (0.36, 0.13, 0.06), (0.24, 0.08, 0.04), scale=30, rough=0.3, coat=0.6, axis='Z'),
        "action": sk.mat("Piano Action", (0.03, 0.03, 0.03), rough=0.8),
        "damper": sk.mat("Piano Damper Felt", (0.05, 0.05, 0.06), rough=0.9),
        "spruce": sk.wood("Piano Soundboard", (0.78, 0.62, 0.40), (0.68, 0.52, 0.32), scale=40, rough=0.5, coat=0.2, axis='Y'),
        "strings": sk.mat("Piano Strings", (0.75, 0.75, 0.72), metal=0.9, rough=0.25),
        "bench": sk.mat("Piano Bench Leather", (0.04, 0.03, 0.03), rough=0.5, coat=0.2),
    }


def smooth_rim(pts, per=6):
    """The rim outline with the bend and tail rounded (Catmull-Rom through the given points)."""
    out = []
    straight = {0, 1, len(pts) - 2, len(pts) - 1}
    for i in range(len(pts) - 1):
        if i in straight or i + 1 in straight:
            out.append(pts[i])
            continue
        p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, len(pts) - 1)]
        for k in range(per):
            t = k / per
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t * t
                       + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t ** 3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t * t
                       + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t ** 3)
            out.append((x, y))
    out.append(pts[-1])
    return out


def inset(outline, d):
    """The outline moved inward by d (a rough offset along each vertex's bisector; fine for a rim)."""
    n = len(outline)
    out = []
    for i in range(n):
        x0, y0 = outline[i - 1]; x1, y1 = outline[i]; x2, y2 = outline[(i + 1) % n]
        a = Vector((x1 - x0, y1 - y0)).normalized(); b = Vector((x2 - x1, y2 - y1)).normalized()
        na = Vector((a.y, -a.x)); nb = Vector((b.y, -b.x))        # outward normals of a counter-clockwise outline
        m = (na + nb)
        m = m.normalized() if m.length > 1e-6 else na
        scale = 1.0 / max(0.4, m.dot(na))
        out.append((x1 - m.x * d * scale, y1 - m.y * d * scale))
    return out


def case_bmesh(outer, inner):
    """The rim: outer skin minus inner skin, as a wall of quads, with a solid bottom (the piano's belly).
    The outline runs from the bass corner round the tail to the treble corner; the closing segment between
    the two corners runs behind the keys, so there the wall stops under the key bed (KEYBED_UNDER) and the
    keyboard and action sit open in front of it. The two rim ends are capped. Material 0 is the black
    case, material 1 the mahogany of the inner rim."""
    bm = bmesh.new()
    n = len(outer)
    ob_ = [bm.verts.new((x, y, RIM_BOTTOM)) for x, y in outer]
    ot = [bm.verts.new((x, y, RIM_TOP)) for x, y in outer]
    ib = [bm.verts.new((x, y, RIM_BOTTOM + 0.03)) for x, y in inner]
    it = [bm.verts.new((x, y, RIM_TOP)) for x, y in inner]
    for i in range(n - 1):
        j = i + 1
        bm.faces.new((ob_[i], ob_[j], ot[j], ot[i]))
        bm.faces.new((ot[i], ot[j], it[j], it[i]))
        bm.faces.new((it[i], it[j], ib[j], ib[i])).material_index = 1
    # the front, under the keys: a low wall from the treble corner back to the bass corner
    a, b = n - 1, 0
    oa = bm.verts.new((outer[a][0], outer[a][1], KEYBED_UNDER)); obv = bm.verts.new((outer[b][0], outer[b][1], KEYBED_UNDER))
    ia = bm.verts.new((inner[a][0], inner[a][1], KEYBED_UNDER)); ibv = bm.verts.new((inner[b][0], inner[b][1], KEYBED_UNDER))
    bm.faces.new((ob_[a], ob_[b], obv, oa))
    bm.faces.new((oa, obv, ibv, ia))
    bm.faces.new((ia, ibv, ib[b], ib[a]))
    # the rim's ends at the keyboard, from the low front wall up to the rim top (the arms close them off)
    bm.faces.new((oa, ot[a], it[a], ia))
    bm.faces.new((obv, ibv, it[b], ot[b]))
    bm.faces.new(list(reversed(ob_)))
    bm.faces.new(ib)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def clip_front(poly, y0):
    """The part of a closed outline with y >= y0 (Sutherland-Hodgman against one line)."""
    out = []
    n = len(poly)
    for i in range(n):
        p, q = poly[i], poly[(i + 1) % n]
        pin, qin = p[1] >= y0, q[1] >= y0
        if pin:
            out.append(p)
        if pin != qin:
            t = (y0 - p[1]) / (q[1] - p[1])
            out.append((p[0] + (q[0] - p[0]) * t, y0))
    return out


def arm_bmesh(x0, x1):
    """A key-block arm: its side profile (y, z) extruded across x0..x1. Square at the front, ARM_TOP high
    over the keys, then a cove sweeping up into the rim top at RIM_FRONT."""
    prof = [(ARM_FRONT, RIM_BOTTOM), (ARM_FRONT, ARM_TOP - 0.008), (ARM_FRONT + 0.008, ARM_TOP)]
    y_cove = RIM_FRONT - 0.10
    for k in range(9):
        a = math.radians(90 * k / 8)
        prof.append((y_cove + 0.10 * math.sin(a), RIM_TOP - (RIM_TOP - ARM_TOP) * math.cos(a)))
    prof.append((RIM_FRONT, RIM_BOTTOM))
    bm = bmesh.new()
    L = [bm.verts.new((x0, y, z)) for y, z in prof]
    R = [bm.verts.new((x1, y, z)) for y, z in prof]
    bm.faces.new(L)
    bm.faces.new(list(reversed(R)))
    n = len(prof)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((L[i], R[i], R[j], L[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def frustum(bm, cx, cy, z0, z1, h0, h1, mi=0):
    """A square tapered post from half-width h0 at z0 to h1 at z1, into bm."""
    lo = [bm.verts.new((cx + sx * h0, cy + sy * h0, z0)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    hi = [bm.verts.new((cx + sx * h1, cy + sy * h1, z1)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    fs = [bm.faces.new(list(reversed(lo))), bm.faces.new(hi)]
    for i in range(4):
        j = (i + 1) % 4
        fs.append(bm.faces.new((lo[i], lo[j], hi[j], hi[i])))
    for f in fs:
        f.material_index = mi


def flat_bar(B, p, q, w, z0, z1, mi=0):
    """A flat-topped strut of the iron frame from p to q (x, y), w wide, z0..z1."""
    p, q = Vector((p[0], p[1], 0)), Vector((q[0], q[1], 0))
    d = q - p
    rot = Matrix.Rotation(math.atan2(-d.x, d.y), 4, 'Z')
    c = (p + q) / 2
    B.box((c.x, c.y, (z0 + z1) / 2), (w, d.length + w, z1 - z0), mi=mi, rot=rot)


def along(poly, n, t0=0.0, t1=1.0):
    """n points spaced evenly by arc length along an open polyline, between fractions t0 and t1."""
    seg = [(Vector(poly[i]) - Vector(poly[i + 1])).length for i in range(len(poly) - 1)]
    total = sum(seg)
    out = []
    for k in range(n):
        s = total * (t0 + (t1 - t0) * (k + 0.5) / n)
        for i, L in enumerate(seg):
            if s <= L:
                out.append(Vector(poly[i]).lerp(Vector(poly[i + 1]), s / L if L else 0.0))
                break
            s -= L
    return out


def apply_difference(ob, cutter):
    """ob minus cutter, applied; the cutter is removed."""
    mod = ob.modifiers.new("cut", 'BOOLEAN')
    mod.operation, mod.solver, mod.object = 'DIFFERENCE', 'EXACT', cutter
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.remove(mod)
    while len(me.materials) > len(ob.data.materials):          # the cutter's faces bring an empty slot along
        me.materials.pop()
    for p in me.polygons:
        p.material_index = min(p.material_index, len(me.materials) - 1)
    old = ob.data
    ob.data = me
    me.name = ob.name
    bpy.data.meshes.remove(old)
    bpy.data.objects.remove(cutter)


def build_plate(M, rig, collection, rim):
    """The copper-gold iron frame, as on a Bösendorfer: a band round the inside of the rim with portholes
    along the bend, a wide bar across the front over the tuning pins, and flat struts fanning back from it
    (two of them crossing in an X). The strings lie just beneath it, the soundboard below them."""
    edge = inset(rim, RIM_T + 0.004)                    # rim: the counter-clockwise outline
    hole = clip_front(inset(rim, RIM_T + 0.10), 0.42)
    plate = sk.prism("Piano Plate", edge, PLATE_TOP - 0.022, PLATE_TOP, mats=[M["plate"]], collection=collection, parent=rig)
    C = sk.Builder()
    C.bm.free()
    C.bm = bmesh.new()
    cut = [C.bm.verts.new((x, y, PLATE_TOP - 0.05)) for x, y in hole]
    cut_t = [C.bm.verts.new((x, y, PLATE_TOP + 0.05)) for x, y in hole]
    C.bm.faces.new(list(reversed(cut)))
    C.bm.faces.new(cut_t)
    for i in range(len(hole)):
        j = (i + 1) % len(hole)
        C.bm.faces.new((cut[i], cut[j], cut_t[j], cut_t[i]))
    # portholes along the band, from the treble side round the bend toward the tail
    mid = inset(rim, RIM_T + 0.052)
    bend = [p for p in mid if p[0] > -0.10 and p[1] > 0.75]
    bend.sort(key=lambda p: p[1])
    for k, c in enumerate(along(bend, 7)):
        r = 0.034 if k % 2 == 0 else 0.026
        C.cyl((c.x, c.y, PLATE_TOP - 0.05), (c.x, c.y, PLATE_TOP + 0.05), r, seg=28)
    cutter = C.build("Piano Plate Cutter", [], collection=collection, parent=rig)
    bpy.context.view_layer.update()
    apply_difference(plate, cutter)
    # the struts
    S = sk.Builder()
    zt, zb = PLATE_TOP + 0.004, PLATE_TOP - 0.034
    for p, q in (((-0.22, 0.40), (-0.12, 2.48)),          # the long middle strut to the tail
                 ((0.22, 0.40), (0.33, 1.84)),            # the treble strut to the bend
                 ((-0.66, 0.72), (0.12, 2.28)),           # the X
                 ((-0.66, 1.95), (0.60, 0.80)),
                 ((-0.55, 0.40), (-0.66, 0.90))):         # the bass corner brace
        flat_bar(S, p, q, 0.05, zb, zt)
    S.build("Piano Plate Struts", [M["plate"]], collection=collection, parent=rig)
    # the strings: a fan of rods from the pins under the front bar back to the bridge
    St = sk.Builder()
    for k in range(44):
        u = k / 43
        x0 = -0.66 + 1.32 * u
        length = 2.10 - 1.75 * u ** 1.3
        x1 = x0 * 0.85
        St.cyl((x0, 0.20, STRING_Z), (x1, 0.20 + length, STRING_Z), 0.0012 if u > 0.3 else 0.002, mi=0, seg=4)
    St.build("Piano Strings", [M["strings"]], collection=collection, parent=rig)
    # the dampers: a row of dark felt blocks across the strings just behind the action
    D = sk.Builder()
    for k in range(40):
        x = -0.60 + 1.10 * k / 39
        D.box((x, DESK_BACK + 0.05, STRING_Z + 0.022), (0.022, 0.04, 0.035), mi=0)
    D.build("Piano Dampers", [M["damper"]], collection=collection, parent=rig)


def build_piano(M, rig, collection):
    """Everything but the keys, as children of the rig."""
    rim = smooth_rim(RIM)                              # counter-clockwise: inset() moves it inward
    outer = list(reversed(rim))                        # from the bass corner round the tail to the treble corner
    inner = list(reversed(inset(rim, RIM_T)))
    sk.mesh_obj("Piano Case", case_bmesh(outer, inner), mats=[M["black"], M["rim_wood"]], collection=collection,
                parent=rig, smooth=True)
    for s, side in ((-1, "Bass"), (1, "Treble")):
        x0, x1 = sorted((s * ARM_IN, s * CASE_W))
        sk.mesh_obj(f"Piano Arm {side}", arm_bmesh(x0, x1), mats=[M["black"]], collection=collection, parent=rig)
    sk.prism("Piano Soundboard", inset(rim, RIM_T + 0.004), SOUNDBOARD_Z, SOUNDBOARD_Z + 0.012, mats=[M["spruce"]],
             collection=collection, parent=rig)
    build_plate(M, rig, collection, rim)
    # the lid: the rim's outline behind the music desk, hinged along the bass side, open on the long stick;
    # its front flap is folded back on top of it, as for a concert
    lid_ol = [(x + CASE_W, y) for x, y in clip_front(rim, LID_FRONT)]   # local origin on the hinge line x = -CASE_W
    lid = sk.prism("Piano Lid", lid_ol, 0.0, 0.025, mats=[M["black"]], collection=collection, parent=rig)
    lid.location = (-CASE_W, 0.0, RIM_TOP)
    lid.rotation_euler = (0.0, -math.radians(LID_ANGLE), 0.0)
    flap_d = LID_FRONT - 0.23
    sk.box("Piano Lid Flap", (2 * CASE_W - 0.02, flap_d, 0.022), (CASE_W, LID_FRONT + flap_d / 2, 0.025 + 0.011),
           mat_=M["black"], collection=collection, parent=lid)
    a = math.radians(LID_ANGLE)
    foot = Vector((0.60, 1.05, RIM_TOP))
    span = (foot.x + CASE_W)                             # distance from the hinge, across
    top = Vector((-CASE_W + span * math.cos(a), 1.05, RIM_TOP + span * math.sin(a)))
    sk.rod("Piano Lid Stick", foot, top, 0.012, mat_=M["black"], collection=collection, parent=rig)
    # under and in front of the keys: the key bed and the key slip, between the arms
    sk.box("Piano Key Slip", (2 * ARM_IN, 0.04, 0.06), (0, -0.175, -0.035), mat_=M["black"], collection=collection, parent=rig)
    sk.box("Piano Key Bed", (2 * ARM_IN, 0.40, 0.05), (0, 0.02, -0.045), mat_=M["black"], collection=collection, parent=rig)
    # behind the keys: the red felt, then the open fallboard's tall glossy face with its rounded top rail and
    # the folded fallboard running back to the block over the action, on which the music desk stands
    sk.box("Piano Felt", (cp.N_WHITE * cp.WHITE_W, 0.004, 0.014), (0, 0.002, 0.005), mat_=M["felt"], collection=collection, parent=rig)
    sk.box("Piano Fallboard (open)", (2 * ARM_IN, 0.026, FALL_H + 0.01), (0, 0.004 + 0.013, (FALL_H - 0.01) / 2),
           mat_=M["black"], collection=collection, parent=rig)
    sk.cyl("Piano Fallboard Rail", 0.014, 2 * ARM_IN, (0, 0.022, FALL_H), rot=(0, math.radians(90), 0), mat_=M["black"],
           collection=collection, parent=rig, seg=20)
    sk.box("Piano Fallboard Top", (2 * ARM_IN, 0.20, 0.02), (0, 0.13, FALL_H - 0.002), mat_=M["black"], collection=collection, parent=rig)
    wi = CASE_W - RIM_T
    sk.box("Piano Desk Block", (2 * wi, DESK_BACK - 0.23, RIM_TOP - FALL_H + 0.01), (0, (0.23 + DESK_BACK) / 2, (RIM_TOP + FALL_H - 0.01) / 2),
           mat_=M["black"], collection=collection, parent=rig)
    sk.box("Piano Action", (2 * wi, DESK_BACK - 0.03, FALL_H - 0.04), (0, (0.03 + DESK_BACK) / 2, -0.02 + (FALL_H - 0.04) / 2),
           mat_=M["action"], collection=collection, parent=rig)
    logo(M, rig, collection)
    # the music desk: a broad panel leaning back, with a ledge for the music
    tilt = math.radians(15)
    dh = 0.30
    desk = sk.box("Piano Music Desk", (0.82, 0.014, dh), (0, 0.34 + math.sin(tilt) * dh / 2, RIM_TOP + 0.03 + math.cos(tilt) * dh / 2),
                  mat_=M["black"], collection=collection, parent=rig)
    desk.rotation_euler = (-tilt, 0, 0)
    sk.box("Piano Music Desk Ledge", (0.82, 0.05, 0.014), (0, 0.33, RIM_TOP + 0.03), mat_=M["black"], collection=collection, parent=rig)
    # legs: square, tapering, with brass ferrules and casters; two under the arms, one under the tail
    L = sk.Builder()
    for x, y in ((0.69, 0.30), (-0.69, 0.30), (-0.22, 2.25)):
        frustum(L.bm, x, y, FLOOR + 0.085, RIM_BOTTOM, 0.036, 0.068, mi=0)
        frustum(L.bm, x, y, FLOOR + 0.035, FLOOR + 0.085, 0.039, 0.038, mi=1)
        L.cyl((x - 0.012, y, FLOOR + 0.028), (x + 0.012, y, FLOOR + 0.028), 0.028, mi=1, seg=16)
    L.build("Piano Legs", [M["black"], M["brass"]], collection=collection, parent=rig)
    # the lyre: two posts down to the pedal box, a brace back to the belly, three brass pedals
    Ly = sk.Builder()
    yl = 0.40
    for x in (-0.075, 0.075):
        Ly.box((x, yl, (FLOOR + 0.08 + RIM_BOTTOM) / 2), (0.03, 0.03, RIM_BOTTOM - FLOOR - 0.08))
    Ly.box((0, yl, RIM_BOTTOM - 0.02), (0.26, 0.07, 0.04))
    Ly.box((0, yl, FLOOR + 0.045), (0.30, 0.12, 0.07))
    Ly.cyl((0, yl + 0.06, FLOOR + 0.07), (0, 0.66, RIM_BOTTOM), 0.009, seg=8)
    Ly.build("Piano Lyre", [M["black"]], collection=collection, parent=rig)
    for k, x in enumerate((-0.07, 0.0, 0.07)):
        sk.box(f"Piano Pedal {k + 1}", (0.026, 0.11, 0.012), (x, yl - 0.06 - 0.045, FLOOR + 0.06), mat_=M["brass"],
               collection=collection, parent=rig)


LOGO_FONT = "/usr/share/fonts/urw-base35/Z003-MediumItalic.otf"   # no blackletter installed; the nearest script


def logo(M, rig, collection):
    """The maker's name in gold on the fallboard face, centred over middle C."""
    cu = bpy.data.curves.new("Piano Logo", 'FONT')
    cu.body = "Bösendorfer"
    if Path(LOGO_FONT).exists():
        cu.font = bpy.data.fonts.load(LOGO_FONT, check_existing=True)
    cu.size = 0.055
    cu.align_x, cu.align_y = 'CENTER', 'CENTER'
    cu.extrude = 0.0006
    cu.materials.append(M["brass"])
    ob = bpy.data.objects.new("Piano Logo", cu)
    ob.location = (0.0, 0.0035, FALL_H * 0.55)
    ob.rotation_euler = (math.radians(90), 0, 0)
    sk._link(ob, collection, rig)


def build_keys(M, rig, collection):
    """88 keys, children of the rig, each hinged at its back end (rotation about local X dips the front).
    A key's mesh runs from its hinge (local y 0, the rig's y 0, just in front of the nameboard) forward
    to -length: a white key's front edge is 15 cm toward the player, a black key's 5.5 cm less."""
    for m in range(cp.PIANO_LOW, cp.PIANO_HIGH + 1):
        black = (m % 12) in cp._ACC
        if black:
            size = (cp.BLACK_W, cp.BLACK_L, cp.WHITE_T + cp.BLACK_RISE)
            centre = (0.0, -cp.BLACK_L / 2, (cp.BLACK_RISE - cp.WHITE_T) / 2)
        else:
            size = (cp.WHITE_W - cp.KEY_GAP, cp.WHITE_L, cp.WHITE_T)
            centre = (0.0, -cp.WHITE_L / 2, -cp.WHITE_T / 2)
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
        bmesh.ops.translate(bm, vec=Vector(centre), verts=bm.verts)
        sk.mesh_obj(f"{KEY} Key {m}", bm, loc=(cp.piano_key_x(m), 0.0, 0.0),
                    mats=[M["ebony"] if black else M["ivory"]], collection=collection, parent=rig)


def build_bench(M, collection):
    p, f, l, up = sk.frame_for(KEY)
    B = sk.Builder()
    Rb = Matrix((-l, f, up)).transposed().to_4x4()
    c = p + up * 0.47 - f * 0.02
    B.box(c, (0.92, 0.36, 0.06), mi=0, rot=Rb)
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = p + (-l) * (sx * 0.40) + f * (sy * 0.13 - 0.02)
            B.cyl(leg, leg + up * 0.44, 0.022, mi=1, seg=10)
    B.build(f"Bench - {KEY}", [M["bench"], bpy.data.materials["Piano Black"]], collection=collection)


def build_cams(rig):
    pts = cc._player_points(KEY)
    case = bpy.data.objects["Piano Case"]
    pts += [case.matrix_world @ Vector(c) for c in case.bound_box]
    lid = bpy.data.objects["Piano Lid"]
    pts += [lid.matrix_world @ Vector(c) for c in lid.bound_box]
    for name, (az, el, lens) in FIT_CAMS.items():
        cam, tgt = cc._camera(name, lens)
        cam.location, tgt.location = cc._fit(pts, az, el, lens)
    mw = rig.matrix_world
    for name, (loc, tgt_loc, lens) in CAMS.items():
        cam, tgt = cc._camera(name, lens)
        cam.location, tgt.location = mw @ Vector(loc), mw @ Vector(tgt_loc)
    head = bpy.data.objects[cp.body_name(KEY) + " Head"]
    centre = Vector(head["centre"])
    name, off, lens = FACE_CAM
    cam, tgt = cc._camera(name, lens)
    tgt.location = centre
    cam.location = centre + mw.to_3x3() @ Vector(off)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--out", default="Alcorcon_Piano.blend")
    args = p.parse_args(argv)

    cp.load_layout()
    sk.LAYOUT[KEY] = {"pos": list(PLAYER_POS), "seated": True, "facing": list(FACING)}
    bpy.data.objects["Stage Controls"]["layout_json"] = json.dumps(sk.LAYOUT)
    hidden = duo.hide_others({KEY})
    print(f"[piano] hid {len(hidden)} objects of the other players")
    for name in ("Riser", "Riser Skirt", "Riser Nosing Tape"):      # a recital: no orchestra riser
        ob = bpy.data.objects.get(name)
        if ob is not None:
            ob.hide_render = ob.hide_viewport = True

    M = materials()
    C = sk.coll("Piano", bpy.data.collections.get("Instruments") or bpy.data.collections.get("Concert Stage Set"))
    R, origin = rig_matrix()
    rig = sk.empty(KEY, loc=origin, collection=C, size=0.4, kind='ARROWS')
    rig.matrix_world = Matrix.Translation(origin) @ R
    build_piano(M, rig, C)
    build_keys(M, rig, C)
    build_bench(M, sk.coll("Furniture & Stands"))
    bpy.context.view_layer.update()

    rs.rebuild_players([KEY])                         # body, face, arms; posed at rest on the keys
    x, y, _z = PLAYER_POS
    light = sk.stage_light("Special 19 Piano", 'SPOT', (x + 0.6, -2.8, 7.3), (x + 0.45, y, 1.0), (1.0, 0.95, 0.88), 2600,
                           "specials", spot_deg=26, blend=0.45, size=0.15)
    print(f"[piano] {light.name} hung over the keyboard")
    bpy.context.view_layer.update()
    build_cams(rig)
    yz = cc.DOLLY_CAMS["Cam 50 Dolly Front Row"]
    ens = {
        "players": [KEY],
        "player_cams": {KEY: ["Cam 66 Piano Keys (along the keyboard)", "Cam 62 Piano Over the Shoulder",
                              "Cam 60 Piano Full (lid side)", "Cam 63 Piano Face"]},
        "group_cams": {name: [[KEY], az, el, lens] for name, (az, el, lens) in FIT_CAMS.items()},
        "wide_cams": WIDE,
        "dolly_cams": {"Cam 50 Dolly Front Row": [yz[0], yz[1], yz[2], yz[3], DOLLY_RUN[0], DOLLY_RUN[1], yz[6]]},
    }
    bpy.data.objects["Stage Controls"]["ensemble_json"] = json.dumps(ens)
    out = str((REPO_DIR / args.out).resolve()) if not Path(args.out).is_absolute() else args.out
    bpy.ops.wm.save_as_mainfile(filepath=out, copy=True)
    print(f"[piano] saved {out}")


if __name__ == "__main__":
    main()
