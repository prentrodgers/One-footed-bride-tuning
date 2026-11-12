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

CASE_W = 0.78                        # half width of the case at the keyboard
# the rim's outline in rig coordinates (x across, y into the piano), from the keyboard's treble corner
# round the bend and tail to the bass corner, then back along the straight bass side
RIM = [(0.78, -0.08), (0.78, 0.95), (0.72, 1.22), (0.58, 1.48), (0.42, 1.68), (0.30, 1.90), (0.24, 2.12),
       (0.14, 2.34), (-0.06, 2.50), (-0.30, 2.54), (-0.54, 2.48), (-0.70, 2.34), (-0.78, 2.16), (-0.78, -0.08)]
RIM_TOP, RIM_BOTTOM = 0.035, -0.26   # of the rim, relative to the key tops
RIM_T = 0.045                        # the rim's thickness

CAMS = {   # name -> (location, target) in rig coordinates, lens
    "Cam 61 Piano Hands (treble end)": ((1.00, -0.62, 0.80), (-0.12, -0.05, 0.0), 40),   # steep enough to see the keys past the block
    "Cam 62 Piano Over the Shoulder": ((0.95, -1.30, 1.15), (-0.25, 0.02, -0.05), 32),   # the right shoulder: the lid is on the left
}
FACE_CAM = ("Cam 63 Piano Face", (1.05, 1.35, 0.18), 85)   # from inside the bend, over the music desk: offset from the head (rig axes), lens
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
        "plate": sk.mat("Piano Plate Gold", (0.72, 0.55, 0.22), metal=0.6, rough=0.45),
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


def build_piano(M, rig, collection):
    """Everything but the keys, as children of the rig."""
    rim = smooth_rim(RIM)
    rim_cw = list(reversed(rim))                       # prism wants a consistent winding; RIM runs clockwise
    outer = rim_cw
    inner = inset(outer, RIM_T)
    # the rim: outer skin minus inner skin, as a wall of quads, with a solid bottom (the piano's floor)
    bm = bmesh.new()
    n = len(outer)
    ob_ = [bm.verts.new((x, y, RIM_BOTTOM)) for x, y in outer]
    ot = [bm.verts.new((x, y, RIM_TOP)) for x, y in outer]
    ib = [bm.verts.new((x, y, RIM_BOTTOM + 0.03)) for x, y in inner]
    it = [bm.verts.new((x, y, RIM_TOP)) for x, y in inner]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ob_[i], ob_[j], ot[j], ot[i]))
        bm.faces.new((ot[i], ot[j], it[j], it[i]))
        bm.faces.new((it[i], it[j], ib[j], ib[i]))
    bm.faces.new(list(reversed(ob_)))
    bm.faces.new(ib)
    bm.normal_update()
    case = sk.mesh_obj("Piano Case", bm, mats=[M["black"]], collection=collection, parent=rig, smooth=True)
    # the inside: soundboard, the gold plate with its struts, and the strings as a fan of rods
    sb = inset(outer, RIM_T + 0.01)
    sk.prism("Piano Soundboard", sb, RIM_BOTTOM + 0.03, RIM_BOTTOM + 0.045, mats=[M["spruce"]], collection=collection,
             parent=rig)
    B = sk.Builder()
    for x0, y0, x1, y1 in ((-0.70, 0.30, 0.70, 0.30), (-0.70, 0.30, -0.60, 2.30), (0.70, 0.30, 0.52, 1.50),
                           (-0.30, 0.30, -0.40, 2.40), (0.20, 0.30, 0.10, 2.20)):
        B.cyl((x0, y0, RIM_BOTTOM + 0.10), (x1, y1, RIM_BOTTOM + 0.10), 0.022, mi=0, seg=10)
    B.box((0.0, 0.26, RIM_BOTTOM + 0.10), (1.45, 0.08, 0.05), mi=0)
    B.build("Piano Plate", [M["plate"]], collection=collection, parent=rig)
    S = sk.Builder()
    for k in range(44):                                 # one rod per two notes: the fan from the pins to the bridge
        u = k / 43
        x0 = -0.66 + 1.32 * u
        length = 2.05 - 1.75 * u ** 1.3
        x1 = x0 * 0.85
        S.cyl((x0, 0.34, RIM_BOTTOM + 0.065), (x1, 0.34 + length, RIM_BOTTOM + 0.065), 0.0012 if u > 0.3 else 0.002,
              mi=0, seg=4)
    S.build("Piano Strings", [M["strings"]], collection=collection, parent=rig)
    # the lid: the rim's outline, hinged along the bass side, open on the long stick
    lid_ol = [(x + CASE_W, y) for x, y in rim_cw]     # local origin on the hinge line x = -CASE_W
    lid = sk.prism("Piano Lid", lid_ol, 0.0, 0.03, mats=[M["black"]], collection=collection, parent=rig)
    lid.location = (-CASE_W, 0.0, RIM_TOP)
    lid.rotation_euler = (0.0, -math.radians(LID_ANGLE), 0.0)
    # the lid's front flap stays folded back on the lid; the prop stick from the treble rim to the lid
    a = math.radians(LID_ANGLE)
    foot = Vector((0.60, 1.05, RIM_TOP))
    along = (foot.x + CASE_W)                            # distance from the hinge, across
    top = Vector((-CASE_W + along * math.cos(a), 1.05, RIM_TOP + along * math.sin(a)))
    sk.rod("Piano Lid Stick", foot, top, 0.012, mat_=M["black"], collection=collection, parent=rig)
    # the key bed, slip, cheeks and the fallboard behind the keys; the red felt strip
    sk.box("Piano Key Slip", (2 * CASE_W, 0.05, 0.05), (0, -0.19, -0.045), mat_=M["black"], collection=collection, parent=rig)
    sk.box("Piano Key Bed", (2 * CASE_W, 0.40, 0.05), (0, 0.02, -0.045), mat_=M["black"], collection=collection, parent=rig)
    for s in (-1, 1):
        sk.box(f"Piano Cheek {'L' if s < 0 else 'R'}", (0.10, 0.36, 0.075), (s * (CASE_W - 0.05), 0.0, -0.012),
               mat_=M["black"], collection=collection, parent=rig)      # the key blocks: 2.5 cm above the keys
    # behind the keys only a low nameboard; the fallboard is open, folded back and sloping up toward the desk,
    # so the keys lie in full view
    sk.box("Piano Nameboard", (2 * CASE_W - 0.2, 0.04, 0.034), (0, 0.02, 0.017), mat_=M["black"], collection=collection, parent=rig)
    fall = sk.box("Piano Fallboard (open)", (2 * CASE_W - 0.2, 0.19, 0.012), (0, 0.135, 0.062), mat_=M["black"],
                  collection=collection, parent=rig)
    fall.rotation_euler = (math.radians(14), 0, 0)
    sk.box("Piano Felt", (cp.N_WHITE * cp.WHITE_W, 0.012, 0.004), (0, 0.004, 0.036), mat_=M["felt"], collection=collection, parent=rig)
    # the music desk, well back on the pin block and tilted back
    desk = sk.box("Piano Music Desk", (0.60, 0.012, 0.24), (0, 0.46, 0.21), mat_=M["black"], collection=collection, parent=rig)
    desk.rotation_euler = (math.radians(-20), 0, 0)
    sk.box("Piano Music Desk Ledge", (0.60, 0.05, 0.012), (0, 0.44, 0.10), mat_=M["black"], collection=collection, parent=rig)
    # legs and casters, the pedal lyre, the brass pedals
    floor = -KEY_HEIGHT
    for name, (x, y) in (("Piano Leg Treble", (0.64, 0.12)), ("Piano Leg Bass", (-0.64, 0.12)), ("Piano Leg Tail", (-0.28, 2.18))):
        sk.cyl(name, 0.055, RIM_BOTTOM - floor - 0.03, (x, y, (RIM_BOTTOM + floor) / 2), mat_=M["black"], collection=collection,
               parent=rig, seg=16)
        sk.cyl(name + " Caster", 0.035, 0.03, (x, y, floor + 0.02), mat_=M["brass"], collection=collection, parent=rig, seg=12)
    sk.box("Piano Lyre", (0.26, 0.05, RIM_BOTTOM - floor - 0.08), (0, 0.36, (RIM_BOTTOM + floor) / 2 - 0.02), mat_=M["black"],
           collection=collection, parent=rig)
    for k, x in enumerate((-0.06, 0.0, 0.06)):
        sk.box(f"Piano Pedal {k + 1}", (0.025, 0.09, 0.008), (x, 0.30, floor + 0.07), mat_=M["brass"], collection=collection, parent=rig)


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
        "player_cams": {KEY: ["Cam 61 Piano Hands (treble end)", "Cam 62 Piano Over the Shoulder",
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
