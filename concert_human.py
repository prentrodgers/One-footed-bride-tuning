#!/usr/bin/env python3
"""
concert_human.py - a MakeHuman person at the piano, in place of the procedural puppet.

The puppet (concert_poses.build_body / build_puppet) is spheres, tubes and a head; this is a rigged,
skinned, clothed human made by MPFB (the MakeHuman plugin for Blender) and driven by the SAME musical
state: PianoPlayer's fingering plan and concert_poses.hands_piano's targets are untouched, and only what
they move is different - 163 bones instead of 50 loose parts.

Four jobs, four ways in:

  1. BUILD the person (needs MPFB and its asset packs, which live in their own Blender profile so that
     nobody's own Blender is touched):

       BLENDER_USER_RESOURCES=~/.local/share/ofb-mpfb/userres \\
           blender --background --python concert_human.py -- build --out Pianist_Human.blend

     LOOK below is the person: body sliders, skin, hair, clothes. The .blend packs its textures and
     needs no add-on afterwards: the render pods and a rented machine open it as it is.

     DRESS him (part of build; again on its own after a change to SUIT, HAIR or SKIN, without MPFB):
     concert black, strand hair, skin - see "1b. dress" below.

       blender --background Pianist_Human.blend --python concert_human.py -- dress --out Pianist_Human.blend

  2. SEAT that person on a piano stage (Alcorcon_Piano.blend, Alcorcon_Recital.blend): the puppet is
     hidden, not deleted (the stage's cameras and the head planner still look it up by name), the bench
     moves back for the longer arms, and the rig is named "Human - Piano":

       blender --background Alcorcon_Recital.blend --python concert_human.py -- \\
           seat --human Pianist_Human.blend --out Alcorcon_Recital.blend

  3. POSE at render time: concert_poses.pose() finds "Human - <player>" on the stage and hands the
     player's state to HumanPianist.pose(). No MPFB, no solver, no constraints: plain forward kinematics
     worked out here (class FK), about a millisecond a frame, and - like everything else on the stage -
     a pure function of the music time, so frames can be rendered in any order by anybody.

Measured against the puppet (14 Nov 2026, CPU, one still): no slower to render; 2.1 GB instead of 1.05.
"""
import math
import sys
import time
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

UP = Vector((0, 0, 1))
PROFILE = Path.home() / ".local/share/ofb-mpfb/userres"      # MPFB 2.0.18 + asset packs (see build)

# The pianist, chosen from the contact sheets of 14 Nov 2026: a middle-aged woman (sheet tile P06; first P15,
# a man, until the user asked for a woman), hair H08 (long01), the suit of tile B04 (male suit 3, fitted to
# her by MPFB) - the suit in concert black and the hair as strands, by dress().
LOOK = {
    "Piano": dict(sex="female", age=0.66, race="caucasian", muscle=0.5, weight=0.5, height=0.55, proportions=0.6,
                  skin="middleage_caucasian_female", hair="long01", hair_colour=None, eyebrows="eyebrow006",
                  clothes=["toigo_male_suit_3", "shoes01"], brown_eyes=False),
}
# (saturation, value, multiply) on a hairstyle's own texture; None leaves it as the pack made it
HAIR_COLOURS = {"black": (0.25, 1.0, (0.10, 0.085, 0.08)), "brown": (1.0, 1.0, (0.55, 0.40, 0.28)),
                "grey": (0.0, 1.9, (0.80, 0.80, 0.83))}


def rig_name(key):
    return f"Human - {key}"


# ─────────────────────────────── 1. build ───────────────────────────────
def build(key, out):
    """Make LOOK[key] with MPFB and save it, textures packed. Run under the MPFB profile (see the top)."""
    import addon_utils
    mod = "bl_ext.user_default.mpfb"
    if not addon_utils.check(mod)[1]:
        bpy.ops.preferences.addon_enable(module=mod)
    from bl_ext.user_default.mpfb.services.faceservice import FaceService
    from bl_ext.user_default.mpfb.services.humanservice import HumanService
    from bl_ext.user_default.mpfb.services.locationservice import LocationService
    from bl_ext.user_default.mpfb.services.objectservice import ObjectService
    data = Path(LocationService.get_user_data())
    look = LOOK[key]

    def asset(kind, name):
        hit = sorted((data / kind / name).glob("*.mhclo")) if name else []
        if name and not hit:
            raise SystemExit(f"[human] no {kind} asset {name!r} under {data / kind}")
        return str(hit[0].relative_to(data / kind)) if hit else ""

    for o in list(bpy.data.objects):                         # the factory cube, camera and light
        bpy.data.objects.remove(o, do_unlink=True)
    info = HumanService._create_default_human_info_dict()
    ph = info["phenotype"]
    ph.update(gender=1.0 if look["sex"] == "male" else 0.0, age=look["age"], muscle=look["muscle"],
              weight=look["weight"], height=look["height"], proportions=look["proportions"])
    ph["race"] = {r: (1.0 if r == look["race"] else 0.0) for r in ("asian", "caucasian", "african")}
    info.update(
        name="Pianist", rig="default",                       # the default rig: three bones a finger, a twist bone a forearm
        eyes="high-poly/high-poly.mhclo", eyebrows=asset("eyebrows", look["eyebrows"]),
        eyelashes=asset("eyelashes", "eyelashes01"), teeth=asset("teeth", "teeth_base"), tongue=asset("tongue", "tongue01"),
        hair=asset("hair", look["hair"]), clothes=[asset("clothes", c) for c in look["clothes"]],
        skin_mhmat=f"{look['skin']}/{look['skin']}.mhmat", skin_material_type="ENHANCED_SSS",
        eyes_material_type="PROCEDURAL_EYES",
        # the hands01 pack: fingers that bend where the bones are, and a player's knuckles
        targets=[{"target": "mindfront_hand_fingers_correction", "value": 1.0},
                 {"target": "jujube_knobby_knuckles", "value": 0.5}])
    settings = HumanService.get_default_deserialization_settings()
    settings["subdiv_levels"] = 1
    body = HumanService.deserialize_from_dict(info, settings)
    rig = ObjectService.find_object_of_type_amongst_nearest_relatives(body, "Skeleton")
    # 52 ARKit-style face units as shape keys (blink, brows, mouth), copied to the brows, lashes and hair
    # so they follow the skin when it moves
    FaceService.load_targets(body, load_microsoft_visemes=False, load_meta_visemes=False, load_arkit_faceunits=True)
    FaceService.interpolate_targets(body)
    _colour(look)
    for im in bpy.data.images:                               # the packs' textures: into the .blend
        if im.source == "FILE" and im.filepath and not im.packed_file:
            im.pack()
    dress(key)
    rig["ofb_human"] = key
    bpy.ops.wm.save_as_mainfile(filepath=str(out), compress=True)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    print(f"[human] {key}: {len(rig.data.bones)} bones, {len(meshes)} meshes, "
          f"{sum(len(o.data.polygons) for o in meshes)} faces, {len(bpy.data.images)} images packed -> {out} "
          f"({Path(out).stat().st_size / 1e6:.1f} MB)")


def _colour(look):
    """MPFB leaves the procedural eyes blue and each hairstyle the colour its texture was painted."""
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        for sl in o.material_slots:
            nt = sl.material.node_tree if sl.material else None
            if not nt:
                continue
            for n in nt.nodes:
                if n.bl_idname == "ShaderNodeGroup" and "IrisMajorColor" in n.inputs and look.get("brown_eyes"):
                    n.inputs["IrisMajorColor"].default_value = (0.20, 0.09, 0.03, 1)
                    n.inputs["IrisMinorColor"].default_value = (0.07, 0.03, 0.012, 1)
            mix, bsdf = nt.nodes.get("diffuseIntensity"), nt.nodes.get("Principled BSDF")
            if mix and bsdf and look["hair"] in o.name and look.get("hair_colour"):
                sat, val, tint = HAIR_COLOURS[look["hair_colour"]]
                hs = nt.nodes.new("ShaderNodeHueSaturation")
                hs.inputs["Saturation"].default_value = sat; hs.inputs["Value"].default_value = val
                mul = nt.nodes.new("ShaderNodeMixRGB"); mul.blend_type = "MULTIPLY"
                mul.inputs[0].default_value = 1.0; mul.inputs[2].default_value = (*tint, 1)
                nt.links.new(mix.outputs[0], hs.inputs["Color"]); nt.links.new(hs.outputs[0], mul.inputs[1])
                nt.links.new(mul.outputs[0], bsdf.inputs["Base Color"])


# ─────────────────────────────── 1b. dress: concert black, hair, skin ───────────────────────────────
# What MPFB's packs give, tuned for the stage (14 Nov 2026). dress() works on a built person with or without
# MPFB and can be run again: every change starts from what the packs gave (kept in the .blend), so
#
#     blender --background Pianist_Human.blend --python concert_human.py -- dress --out Pianist_Human.blend
#
# re-dresses him after a change here without rebuilding.

# Concert black. The suit pack has one texture for the whole outfit: navy pinstripe jacket and trousers,
# a pale blue shirt and a red patterned tie. Recoloured from that texture (sRGB values): black wool with no
# stripe, a white shirt, a black tie. Black cloth is not 0: wool reflects a few percent, and under the
# stage lights a jacket of 0 would be a hole in the picture.
SUIT = dict(cloth=0.075, shirt=(0.93, 0.93, 0.91), tie=0.06, sheen=0.07, rough=0.72)

# The hair: strands, not the pack's painted shells. The long01 hairstyle is an outer shell over the head
# and 17 sheets inside it, each painted with hair that runs down its texture. A strand is laid along a
# shell or a sheet the way its texture runs - from the crown (the top of the painted hair) to where the
# paint fades out - bound to the triangles it crosses, so it rides on the shell as the armature moves it
# (a geometry-nodes modifier rebuilds every strand from the shell's evaluated vertices, every frame,
# with no Python), and a few children are scattered round each one, coming together toward the tip as
# hair clumps. The shell stays under them, darkened, so no scalp shows between strands.
HAIR = dict(guides=7000, points=18, children=6, root_r=0.00005, tip_r=0.000016, clump=0.0035,
            strays=0.03, stray_out=0.012, frizz=0.0012, frizz_scale=60.0,
            lift=(0.0004, 0.0030), sheet_lift=0.0012, inner_share=0.45, shell_dark=0.40,
            melanin=0.62, redness=0.17, roughness=0.26, radial=0.32, random_colour=0.12, seed=11)

# Skin: MPFB's "enhanced SSS" skin, with its inputs set here (input name -> value). As the pack set it, light
# went 0.5 mm into the skin and at a fifth strength: the hands read as hard and wet, with bright spots
# on the knuckles. Measured human skin scatters red light about 3.7 mm, green 1.4 and blue 0.7 (Jensen
# et al., 2001); the group multiplies these by the Principled BSDF's subsurface scale of 5 mm.
SKIN = {"SSS strength": 1.0, "SSS radius scale": 0.73, "SSS radius R": 1.0, "SSS radius G": 0.37, "SSS radius B": 0.19,
        "Pore strength": 0.35, "Roughness": 0.45, "Clearcoat": 0.05}


def dress(key):
    look = LOOK[key]
    _concert_black(look)
    _strand_hair(look)
    _skin(look)


def _concert_black(look):
    import numpy as np
    ob = next(o for o in bpy.data.objects if o.type == "MESH" and look["clothes"][0] in o.name)
    mat = ob.material_slots[0].material
    nt = mat.node_tree
    tex = nt.nodes["diffuseTexture"]
    src = bpy.data.images.get(mat.get("ofb_suit_src", "")) or tex.image
    mat["ofb_suit_src"] = src.name
    src.use_fake_user = True                                 # kept in the .blend, unused, for the next dress()
    W, H = src.size
    px = np.empty(W * H * 4, np.float32)
    src.pixels.foreach_get(px)
    px = px.reshape(H, W, 4)
    rgb = px[..., :3]
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)

    def dilate(m, r):
        out = m.copy()
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    out |= np.roll(np.roll(m, dy, 0), dx, 1)
        return out

    def blur(a, r):                                          # a box blur, both ways
        k = 2 * r + 1
        c = np.cumsum(np.pad(a, ((0, 0), (r + 1, r))), 1); a = (c[:, k:] - c[:, :-k]) / k
        c = np.cumsum(np.pad(a, ((r + 1, r), (0, 0))), 0); return (c[k:] - c[:-k]) / k

    red = (rgb[..., 0] > 0.30) & (rgb[..., 0] > 1.6 * rgb[..., 1]) & (rgb[..., 0] > 1.6 * rgb[..., 2])
    tie = dilate(red, 7)                                     # the tie's white dots are inside its red
    shirt = (lum > 0.50) & ~tie
    cloth = ~(shirt | tie)
    out = np.empty_like(px)
    out[..., 3] = px[..., 3]
    # the cloth: the pinstripes blurred away, a little of the weave's light and dark kept
    soft = blur(lum, 7)
    var = np.clip((soft / max(np.median(soft[cloth]), 1e-4)) ** 0.5, 0.85, 1.15)
    out[..., :3] = (SUIT["cloth"] * var)[..., None]
    sv = np.clip(lum / max(np.median(lum[shirt]), 1e-4), 0.80, 1.06)[..., None]
    out[..., :3] = np.where(shirt[..., None], np.array(SUIT["shirt"], np.float32) * sv, out[..., :3])
    tv = SUIT["tie"] * (0.8 + 0.4 * np.clip(lum / max(np.percentile(lum[tie], 90), 1e-4), 0, 1))
    out[..., :3] = np.where(tie[..., None], tv[..., None], out[..., :3])
    name = src.name.rsplit(".", 1)[0] + " concert black"
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)
    img = bpy.data.images.new(name, W, H, alpha=True)
    img.pixels.foreach_set(out.ravel())
    img.file_format = "PNG"
    img.pack()
    tex.image = img
    bsdf = nt.nodes["Principled BSDF"]
    # The pinstripe is in the pack's normal and specular maps too: the jacket kept its stripes in relief
    # and in its shine. Wool instead: one roughness, a fine weave in the bump.
    for inp in ("Roughness", "Normal"):
        for l in list(bsdf.inputs[inp].links):
            nt.links.remove(l)
    bsdf.inputs["Roughness"].default_value = SUIT["rough"]
    weave = nt.nodes.get("OFB weave") or nt.nodes.new("ShaderNodeTexNoise")
    weave.name = "OFB weave"; weave.inputs["Scale"].default_value = 900.0; weave.inputs["Detail"].default_value = 2.0
    bump = nt.nodes.get("OFB weave bump") or nt.nodes.new("ShaderNodeBump")
    bump.name = "OFB weave bump"; bump.inputs["Strength"].default_value = 0.08; bump.inputs["Distance"].default_value = 0.0004
    nt.links.new(weave.outputs["Fac"], bump.inputs["Height"]); nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Sheen Weight"].default_value = SUIT["sheen"]   # wool's soft edge light
    bsdf.inputs["Sheen Roughness"].default_value = 0.4
    bsdf.inputs["Specular IOR Level"].default_value = 0.35
    print(f"[human] concert black: {cloth.mean():.0%} of the suit texture cloth, {shirt.mean():.1%} shirt, "
          f"{tie.mean():.1%} tie -> '{name}'")


def _islands(me):
    """The island (connected piece) of every polygon."""
    parent = list(range(len(me.vertices)))

    def root(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]; x = parent[x]
        return x
    for p in me.polygons:
        vs = list(p.vertices)
        for v in vs[1:]:
            parent[root(v)] = root(vs[0])
    ids, out = {}, []
    for p in me.polygons:
        out.append(ids.setdefault(root(p.vertices[0]), len(ids)))
    return out


def _strand_hair(look):
    import numpy as np
    rng = np.random.default_rng(HAIR["seed"])
    shell = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.endswith("." + look["hair"]))
    name = shell.name + " strands"
    for nm in (name, name + " binding"):                     # dressed before: out with the old ones
        old = bpy.data.objects.get(nm)
        if old:
            data = old.data; bpy.data.objects.remove(old)
            (bpy.data.meshes if isinstance(data, bpy.types.Mesh) else bpy.data.hair_curves).remove(data)
    # The strands are bound to the shell's vertices as it is evaluated, so the shell is smoothed by geometry
    # nodes (always on the CPU, at one level, in the viewport and the render alike) instead of the Subsurf
    # modifier (level 0 in the viewport, 1 in the render, and on the GPU in the viewport): the vertices the
    # strands are bound to are then the same everywhere. Bound to the bare shell they would lie on its
    # flat faces, and look it.
    for m in [m for m in shell.modifiers if m.type == "SUBSURF"]:
        shell.modifiers.remove(m)
    if "Smooth" not in shell.modifiers:
        shell.modifiers.new("Smooth", "NODES").node_group = _smooth_nodes()
    dg = bpy.context.evaluated_depsgraph_get()
    me = shell.evaluated_get(dg).to_mesh()                  # the rig is at rest: the shell as it is built
    me.calc_loop_triangles()
    nt_ = len(me.loop_triangles)
    V = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get("co", V); V = V.reshape(-1, 3)
    NV = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get("normal", NV); NV = NV.reshape(-1, 3)
    UV = np.empty(len(me.loops) * 2, np.float32); me.uv_layers.active.data.foreach_get("uv", UV); UV = UV.reshape(-1, 2)
    TL = np.empty(nt_ * 3, np.int32); me.loop_triangles.foreach_get("loops", TL); TL = TL.reshape(-1, 3)
    TV = np.empty(nt_ * 3, np.int32); me.loop_triangles.foreach_get("vertices", TV); TV = TV.reshape(-1, 3)
    TP = np.empty(nt_, np.int32); me.loop_triangles.foreach_get("polygon_index", TP)
    isl_of_poly = np.array(_islands(me))
    TI = isl_of_poly[TP]
    mat = shell.material_slots[0].material
    img = mat.node_tree.nodes["diffuseTexture"].image
    IW, IH = img.size
    A = np.empty(IW * IH * 4, np.float32); img.pixels.foreach_get(A); A = A.reshape(IH, IW, 4)[..., 3]

    def alpha(u, v):
        return A[np.clip((v * IH).astype(int), 0, IH - 1), np.clip((u * IW).astype(int), 0, IW - 1)]

    tri_area = 0.5 * np.linalg.norm(np.cross(V[TV[:, 1]] - V[TV[:, 0]], V[TV[:, 2]] - V[TV[:, 0]]), axis=1)
    counts = np.bincount(TI); outer = int(np.argmax(counts))     # the shell; the rest are the sheets inside
    isl_ids = np.unique(TI)
    weight = np.array([tri_area[TI == i].sum() * (1.0 if i == outer else HAIR["inner_share"]) for i in isl_ids])
    n_isl = np.maximum(1, np.round(HAIR["guides"] * weight / weight.sum())).astype(int)
    P = HAIR["points"]
    pts_i, pts_w, pts_off, pts_t = [], [], [], []
    made = 0
    for isl, n in zip(isl_ids, n_isl):
        tris = np.where(TI == isl)[0]
        uvt = UV[TL[tris]]                                   # (k, 3, 2)
        lo, hi = uvt.reshape(-1, 2).min(0), uvt.reshape(-1, 2).max(0)
        R = 400
        grid = -np.ones((R, R), np.int32)
        cell = (hi - lo) / R
        for k, t in enumerate(tris):                         # which triangle covers each cell of the island's UVs
            a, b, c = (uvt[k] - lo) / cell
            x0, y0 = np.floor(np.minimum(np.minimum(a, b), c)).astype(int)
            x1, y1 = np.ceil(np.maximum(np.maximum(a, b), c)).astype(int)
            xs, ys = np.meshgrid(np.arange(max(x0, 0), min(x1, R)) + 0.5, np.arange(max(y0, 0), min(y1, R)) + 0.5)
            d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if xs.size == 0 or abs(d) < 1e-12:
                continue
            l1 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
            l2 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
            inside = (l1 >= -1e-6) & (l2 >= -1e-6) & (1 - l1 - l2 >= -1e-6)
            grid[ys[inside].astype(int), xs[inside].astype(int)] = t
        rows_v = lo[1] + (np.arange(R) + 0.5) * cell[1]
        got, tries = 0, 0
        while got < n and tries < n * 20:
            tries += 1
            col = rng.integers(0, R)
            u = lo[0] + (col + rng.random()) * cell[0]
            ca = alpha(np.full(R, u), rows_v)
            ok = (grid[:, col] >= 0) & (ca > 0.5)
            if not ok.any():
                continue
            top = int(np.where(ok)[0].max())                 # the crown end: the highest painted cell
            bad = np.where(~((grid[:top + 1, col] >= 0) & (ca[:top + 1] > 0.2)))[0]
            r = int(bad.max()) + 1 if bad.size else 0        # ... down to where the paint fades out
            if top - r < 6:
                continue
            v0, v1 = rows_v[top], rows_v[r]
            v1 = v0 + (v1 - v0) * rng.uniform(0.80, 1.0)     # ragged ends
            vs = np.linspace(v0, v1, P)
            rows = np.clip(((vs - lo[1]) / cell[1]).astype(int), 0, R - 1)
            ts = grid[rows, col]
            if (ts < 0).any():
                continue
            q = UV[TL[ts]]
            a, b, c = q[:, 0], q[:, 1], q[:, 2]
            pu = np.stack([np.full(P, u), vs], 1)
            d = (b[:, 1] - c[:, 1]) * (a[:, 0] - c[:, 0]) + (c[:, 0] - b[:, 0]) * (a[:, 1] - c[:, 1])
            l1 = ((b[:, 1] - c[:, 1]) * (pu[:, 0] - c[:, 0]) + (c[:, 0] - b[:, 0]) * (pu[:, 1] - c[:, 1])) / d
            l2 = ((c[:, 1] - a[:, 1]) * (pu[:, 0] - c[:, 0]) + (a[:, 0] - c[:, 0]) * (pu[:, 1] - c[:, 1])) / d
            w = np.clip(np.stack([l1, l2, 1 - l1 - l2], 1), 0, 1)
            w /= w.sum(1, keepdims=True)
            if isl == outer:                                 # above the shell, by a little more toward the tip
                off = rng.uniform(*HAIR["lift"]) * (0.6 + 0.4 * np.linspace(0, 1, P))
            else:                                            # either side of a sheet
                off = np.full(P, rng.uniform(-1, 1) * HAIR["sheet_lift"])
            pts_i.append(TV[ts]); pts_w.append(w); pts_off.append(off); pts_t.append(np.linspace(0, 1, P))
            got += 1
        made += got
    shell.evaluated_get(dg).to_mesh_clear()
    I = np.concatenate(pts_i).astype(np.int32); Wt = np.concatenate(pts_w).astype(np.float32)
    OFF = np.concatenate(pts_off).astype(np.float32); TT = np.concatenate(pts_t).astype(np.float32)
    # the outer shell's normals must point out of the head, or "above" it is inside it
    rest = (V[I] * Wt[..., None]).sum(1)
    nrm = (NV[I] * Wt[..., None]).sum(1)
    axis = np.stack([np.zeros(len(rest)), np.full(len(rest), V[:, 1].mean()), rest[:, 2]], 1)
    if (np.einsum("ij,ij->i", nrm, rest - axis) < 0).mean() > 0.5:
        OFF = -OFF
    rest = rest + nrm / np.linalg.norm(nrm, axis=1, keepdims=True) * OFF[:, None]

    # Where every strand point is bound (vertices, with the binding as attributes, and edges along the
    # strands): a mesh that is never seen. The strands themselves are a hair-curves object whose geometry
    # nodes make them from it: curves made by geometry nodes on a MESH object are taken for plain curves
    # with no bevel, and Cycles renders nothing of them.
    sm = bpy.data.meshes.new(name + " binding")
    sm.vertices.add(len(rest))
    sm.vertices.foreach_set("co", rest.ravel())
    e = np.arange(len(rest)).reshape(-1, P)
    edges = np.stack([e[:, :-1].ravel(), e[:, 1:].ravel()], 1)
    sm.edges.add(len(edges))
    sm.edges.foreach_set("vertices", edges.ravel().astype(np.int32))
    for k in range(3):
        sm.attributes.new(f"i{k}", "INT", "POINT").data.foreach_set("value", I[:, k])
        sm.attributes.new(f"w{k}", "FLOAT", "POINT").data.foreach_set("value", Wt[:, k])
    sm.attributes.new("off", "FLOAT", "POINT").data.foreach_set("value", OFF)
    sm.attributes.new("t", "FLOAT", "POINT").data.foreach_set("value", TT)
    sm.update()
    bind = bpy.data.objects.new(name + " binding", sm)
    hc = bpy.data.hair_curves.new(name)
    ob = bpy.data.objects.new(name, hc)
    for o in (bind, ob):
        for c in shell.users_collection:
            c.objects.link(o)
        o.parent = shell
        o.matrix_parent_inverse.identity()
        o.matrix_basis.identity()
    bind.hide_viewport = bind.hide_render = True              # still evaluated: the strands depend on it
    hm = _hair_material(shell)
    hc.materials.append(hm)
    gn = ob.modifiers.new("Hair strands", "NODES")
    gn.node_group = _hair_nodes(shell, bind, hm)
    _darken_shell(mat)
    print(f"[human] hair: {made} strands along the shell and its {len(isl_ids) - 1} sheets, "
          f"{len(rest)} points, x{HAIR['children'] + 1} at render -> '{name}'")


def _smooth_nodes():
    name = "OFB Smooth"
    ng = bpy.data.node_groups.get(name)
    if ng is None:
        ng = bpy.data.node_groups.new(name, "GeometryNodeTree")
        ng.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
        ng.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
        gi, go = ng.nodes.new("NodeGroupInput"), ng.nodes.new("NodeGroupOutput")
        sd = ng.nodes.new("GeometryNodeSubdivisionSurface"); sd.inputs["Level"].default_value = 1
        ng.links.new(gi.outputs[0], sd.inputs["Mesh"]); ng.links.new(sd.outputs[0], go.inputs[0])
    return ng


def _hair_nodes(shell, binding, material):
    name = "OFB Hair Strands"
    old = bpy.data.node_groups.get(name)
    if old:
        bpy.data.node_groups.remove(old)
    ng = bpy.data.node_groups.new(name, "GeometryNodeTree")
    ng.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    ng.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    N, link = ng.nodes, ng.links.new

    def attr(nm, typ):
        n = N.new("GeometryNodeInputNamedAttribute"); n.data_type = typ; n.inputs["Name"].default_value = nm
        return n.outputs["Attribute"]

    def vmath(op, a, b=None, scale=None):
        n = N.new("ShaderNodeVectorMath"); n.operation = op
        link(a, n.inputs[0])
        if b is not None:
            link(b, n.inputs[1])
        if scale is not None:
            if isinstance(scale, (int, float)):
                n.inputs["Scale"].default_value = scale
            else:
                link(scale, n.inputs["Scale"])
        return n.outputs[0]

    def math(op, a, b):
        n = N.new("ShaderNodeMath"); n.operation = op
        for i, x in enumerate((a, b)):
            if isinstance(x, (int, float)):
                n.inputs[i].default_value = x
            else:
                link(x, n.inputs[i])
        return n.outputs[0]

    go = N.new("NodeGroupOutput")
    bi = N.new("GeometryNodeObjectInfo"); bi.transform_space = "RELATIVE"
    bi.inputs["Object"].default_value = binding
    m2c = N.new("GeometryNodeMeshToCurve"); link(bi.outputs["Geometry"], m2c.inputs["Mesh"])
    info = N.new("GeometryNodeObjectInfo"); info.transform_space = "RELATIVE"
    info.inputs["Object"].default_value = shell
    pos, nrm = N.new("GeometryNodeInputPosition").outputs[0], N.new("GeometryNodeInputNormal").outputs[0]
    P = Nn = None
    for k in range(3):
        idx, w = attr(f"i{k}", "INT"), attr(f"w{k}", "FLOAT")
        terms = []
        for field in (pos, nrm):
            s = N.new("GeometryNodeSampleIndex"); s.data_type = "FLOAT_VECTOR"; s.domain = "POINT"
            link(info.outputs["Geometry"], s.inputs["Geometry"]); link(field, s.inputs["Value"]); link(idx, s.inputs["Index"])
            terms.append(vmath("SCALE", s.outputs[0], scale=w))
        P = terms[0] if P is None else vmath("ADD", P, terms[0])
        Nn = terms[1] if Nn is None else vmath("ADD", Nn, terms[1])
    bound = vmath("ADD", P, vmath("SCALE", vmath("NORMALIZE", Nn), scale=attr("off", "FLOAT")))
    sp = N.new("GeometryNodeSetPosition")
    link(m2c.outputs[0], sp.inputs["Geometry"]); link(bound, sp.inputs["Position"])
    # the children: copies of each strand, scattered round it, closer toward the tip
    dup = N.new("GeometryNodeDuplicateElements"); dup.domain = "SPLINE"
    dup.inputs["Amount"].default_value = HAIR["children"] + 1
    link(sp.outputs[0], dup.inputs["Geometry"])
    sid = N.new("GeometryNodeFieldOnDomain"); sid.domain = "CURVE"; sid.data_type = "INT"
    link(N.new("GeometryNodeInputIndex").outputs[0], sid.inputs[0])
    rnd = N.new("FunctionNodeRandomValue"); rnd.data_type = "FLOAT_VECTOR"
    rnd.inputs["Min"].default_value = (-1, -1, -1); rnd.inputs["Max"].default_value = (1, 1, 1)
    link(sid.outputs[0], rnd.inputs["ID"])
    t = attr("t", "FLOAT")
    first = math("COMPARE", dup.outputs["Duplicate Index"], 0.0)      # copy 0 is the strand itself
    spread = math("MULTIPLY", math("SUBTRACT", 1.0, math("MULTIPLY", t, 0.6)), HAIR["clump"])
    # now and then a stray, a long way out from its clump past the middle of its length
    stray = N.new("FunctionNodeRandomValue"); stray.data_type = "BOOLEAN"
    stray.inputs["Probability"].default_value = HAIR["strays"]
    link(sid.outputs[0], stray.inputs["ID"]); stray.inputs["Seed"].default_value = 7
    spread = math("ADD", spread, math("MULTIPLY", math("MULTIPLY", stray.outputs[0], math("MULTIPLY", t, t)), HAIR["stray_out"]))
    spread = math("MULTIPLY", spread, math("SUBTRACT", 1.0, first))
    # frizz: every strand wanders a little off its line, more toward the tip
    pos2 = N.new("GeometryNodeInputPosition").outputs[0]
    noise = N.new("ShaderNodeTexNoise"); noise.noise_dimensions = "4D"
    noise.inputs["Scale"].default_value = HAIR["frizz_scale"]
    link(pos2, noise.inputs["Vector"])
    link(math("MULTIPLY", sid.outputs[0], 0.37), noise.inputs["W"])          # each strand its own
    sub = N.new("ShaderNodeVectorMath"); sub.operation = "SUBTRACT"
    link(noise.outputs["Color"], sub.inputs[0]); sub.inputs[1].default_value = (0.5, 0.5, 0.5)
    frizz = vmath("SCALE", sub.outputs[0], scale=math("MULTIPLY", math("POWER", t, 1.5), HAIR["frizz"] * 2))
    off = N.new("GeometryNodeSetPosition")
    link(dup.outputs["Geometry"], off.inputs["Geometry"])
    link(vmath("ADD", vmath("SCALE", rnd.outputs["Value"], scale=spread), frizz), off.inputs["Offset"])
    rad = N.new("GeometryNodeSetCurveRadius"); link(off.outputs[0], rad.inputs["Curve"])
    link(math("ADD", HAIR["root_r"], math("MULTIPLY", t, HAIR["tip_r"] - HAIR["root_r"])), rad.inputs["Radius"])
    sm = N.new("GeometryNodeSetMaterial"); link(rad.outputs[0], sm.inputs["Geometry"])
    sm.inputs["Material"].default_value = material
    link(sm.outputs[0], go.inputs[0])
    return ng


def _hair_material(shell):
    name = "OFB Hair"
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    h = nt.nodes.new("ShaderNodeBsdfHairPrincipled")
    h.model = "CHIANG"; h.parametrization = "MELANIN"
    h.inputs["Melanin"].default_value = HAIR["melanin"]
    h.inputs["Melanin Redness"].default_value = HAIR["redness"]
    h.inputs["Roughness"].default_value = HAIR["roughness"]
    h.inputs["Radial Roughness"].default_value = HAIR["radial"]
    h.inputs["Random Color"].default_value = HAIR["random_colour"]
    h.inputs["Random Roughness"].default_value = 0.15
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(h.outputs[0], out.inputs["Surface"])
    return m


def _darken_shell(mat):
    """The painted shell, darker, under the strands: the shade of hair seen deep between strands."""
    nt = mat.node_tree
    bsdf, mix = nt.nodes["Principled BSDF"], nt.nodes["diffuseIntensity"]
    mul = nt.nodes.get("OFB shell dark") or nt.nodes.new("ShaderNodeMixRGB")
    mul.name = "OFB shell dark"; mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    mul.inputs[2].default_value = (HAIR["shell_dark"],) * 3 + (1,)
    src = next((l.from_socket for l in bsdf.inputs["Base Color"].links), mix.outputs[0])
    if src.node is not mul:
        nt.links.new(src, mul.inputs[1])
    nt.links.new(mul.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6


def _skin(look):
    body = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.endswith(".body"))
    grp = next(n for n in body.material_slots[0].material.node_tree.nodes if n.bl_idname == "ShaderNodeGroup")
    for k, v in SKIN.items():
        grp.inputs[k].default_value = v


# ─────────────────────────────── forward kinematics ───────────────────────────────
class FK:
    """Pose an armature by armature-space matrices, with no depsgraph in the loop:
    posed(child) = posed(parent) @ rest(parent)^-1 @ rest(child) @ basis(child).
    Checked against Blender's own evaluation of the same pose: fingertips agree to 0.002 mm."""

    def __init__(self, rig):
        self.rig = rig
        self.rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
        self.parent = {b.name: b.parent.name if b.parent else None for b in rig.data.bones}
        self.kids = {b.name: [c.name for c in b.children] for b in rig.data.bones}
        self.len = {b.name: b.length for b in rig.data.bones}
        self.basis, self.cache = {}, {}

    def rest_head(self, n):
        return self.rest[n].translation.copy()

    def dist(self, a, b):
        return (self.rest_head(a) - self.rest_head(b)).length

    def m0(self, n):
        p = self.parent[n]
        return self.rest[n].copy() if p is None else self.pose(p) @ self.rest[p].inverted() @ self.rest[n]

    def pose(self, n):
        if n not in self.cache:
            self.cache[n] = self.m0(n) @ self.basis.get(n, Matrix.Identity(4))
        return self.cache[n]

    def _drop(self, n):
        self.cache.pop(n, None)
        for c in self.kids[n]:
            self._drop(c)

    def forget(self, names):
        """Back to wherever their parents leave them (before a hand is placed again)."""
        for n in names:
            self.basis.pop(n, None)
        self._drop(names[0])

    def set_rot(self, n, rot3):
        """Give bone n this armature-space orientation (its head stays where its parent puts it)."""
        m0 = self.m0(n)
        self.basis[n] = m0.inverted() @ (Matrix.Translation(m0.translation) @ rot3.to_4x4())
        self._drop(n)

    def head(self, n):
        return self.pose(n).translation.copy()

    def tail(self, n):
        return self.pose(n) @ Vector((0, self.len[n], 0))

    def aim(self, n, target, tip=None):
        """Turn bone n about its head, by the shortest arc, so that `tip` (a point that moves with it; its
        own tail by default) lies on the line to target."""
        M = self.pose(n); h = M.translation
        a = (tip if tip is not None else self.tail(n)) - h
        b = Vector(target) - h
        if a.length < 1e-9 or b.length < 1e-9:
            return
        self.set_rot(n, a.rotation_difference(b).to_matrix() @ M.to_3x3())

    def turn(self, n, axis, angle):
        """Rotate bone n about an armature-space axis through its head."""
        self.set_rot(n, Matrix.Rotation(angle, 3, Vector(axis)) @ self.pose(n).to_3x3())

    def apply(self):
        for n, B in self.basis.items():
            pb = self.rig.pose.bones[n]
            pb.rotation_mode = "QUATERNION"
            pb.matrix_basis = B


def two_bone(S, W, pole, La, Lf):
    """Elbow (and the wrist, pulled in if it is out of reach) for a shoulder S, a wrist W and a pole."""
    d = (W - S).length
    if d > La + Lf - 0.004:
        W = S + (W - S).normalized() * (La + Lf - 0.004); d = (W - S).length
    dv = (W - S).normalized()
    x = (La * La - Lf * Lf + d * d) / (2 * d)
    h = math.sqrt(max(La * La - x * x, 0.0))
    pp = pole - pole.dot(dv) * dv
    pp = pp.normalized() if pp.length > 1e-6 else Vector((0, 0, -1))
    return S + dv * x + pp * h, W


def frame3(d, l):
    d = d.normalized(); l = (l - l.dot(d) * d).normalized()
    return Matrix((d, l, d.cross(l))).transposed()           # columns: along the hand, index->pinky, d x l


# ─────────────────────────────── 3. the pianist, posed ───────────────────────────────
# A face at the keyboard: mild concentration (ARKit-style unit -> value). Blinks are added per frame.
FACE = {"browDownLeft": 0.25, "browDownRight": 0.25, "eyeSquintLeft": 0.15, "eyeSquintRight": 0.15,
        "mouthPressLeft": 0.25, "mouthPressRight": 0.25, "eyeLookDownLeft": 0.5, "eyeLookDownRight": 0.5}
SPINE_LEAN = (("spine05", 5.0), ("spine04", 4.0), ("spine03", 3.0), ("spine02", 2.0))   # degrees, toward the keys
HEAD_DOWN = (("head", 3.0),)     # degrees. The head planner already looks down at the hands (13 on average, up to 21),
                                 # and the spine leans 14: more than this on top and long hair hides the face
HEAD_SHARE = (("neck01", 0.2), ("neck02", 0.2), ("neck03", 0.2), ("head", 0.4))          # of the planner's yaw and pitch
PAD = 0.006                # a fingertip target is the pad of the finger, this far under the bone's tip
THUMB_FRONT = 0.030        # a thumb plays near the front edge of its key
# The hand over the keys, measured rather than scaled from the puppet's (14 Nov 2026). This hand's reach from
# knuckle to fingertip is 8.2, 9.5, 8.8 and 6.1 cm (index to little finger; the thumb 10.3): the little
# finger is as short as the puppet's while the others are a fifth longer, so the puppet's hand scaled up
# (the first attempt) put the knuckles 6 cm over a pressed key, out of the little finger's reach - the
# whole hand lunged at the key each time it played, and sprang back. A pianist's hand, then: the knuckles
# 4 cm behind the fingertips and a little lower than the puppet's, the hand rolled so the little finger's
# side is lower and turned in so its knuckle is forward. A pressed key then lies at 0.7-0.9 of each
# finger's reach: curved fingers, the little one nearly straight.
KNUCKLE_BACK = 0.018       # the knuckles' centre from the puppet's: further from the fallboard
KNUCKLE_UP = -0.0045       # ... and lower
HAND_ROLL = 0.21           # the little finger's side lower (tan of the angle: 12 degrees)
HAND_IN = 0.20             # the fingers turned toward the thumb's side (11 degrees)
REST_CURL = 0.80           # an idle finger's tip is this share of its reach from the knuckle
FRAME = 1 / 30.0           # concert_stage.FPS
SMOOTH = ((-1, 1.0), (0, 2.0), (1, 3.0), (2, 2.0), (3, 1.0))    # (frames from now, weight): see HumanPianist._hands.
                           # It leads by a frame: a finger is 0.9 of the way onto its key at the onset and there the
                           # frame after, and it leaves a held key a frame early, which nobody hears
OVER_KEY = (0.006, 0.008)  # a fingertip this far to the side of its key's spot still holds it down; ... + this far, not at all
SPLAY = 0.028              # a finger holds a key this far to the side of its knuckle, and no further
SPLAY_FADE = 0.030         # ... and has let go of it by this much further
LET_GO_AFTER = 0.10        # seconds after its onset before a finger may let a key go: until then the hand goes to the key
THUMB_STRETCH = 0.010      # a thumb's key may be this far past its reach before it starts to let go
DIGIT_BONE = {0: 2, 1: 3, 2: 4, 3: 5, 4: 1}     # the plan's digit (0-3 index..pinky, 4 thumb) -> MPFB's finger number


class HumanPianist:
    def __init__(self, key, rig):
        import concert_poses as cp
        self.cp, self.key, self.rig = cp, key, rig
        self.fk = fk = FK(rig)
        self.meshes = [o for o in rig.children_recursive if o.type == "MESH" and o.data.shape_keys]
        piano = bpy.data.objects[key]
        PR = piano.matrix_world.to_3x3()
        self.Mi = rig.matrix_world.inverted()
        Ri = self.Mi.to_3x3()
        self.xk, self.yk, self.zk = [(Ri @ (PR @ Vector(v))).normalized() for v in ((1, 0, 0), (0, 1, 0), (0, 0, 1))]
        self.La, self.Lf = fk.dist("upperarm01.L", "lowerarm01.L"), fk.dist("lowerarm01.L", "wrist.L")
        # the hand is bigger than the puppet's: the knuckles ride higher and further back in proportion
        self.s_hand = sum(fk.len[f"finger3-{i}.L"] for i in (1, 2, 3)) / cp.HAND_STYLE[key]["flen"][1]
        self._static()
        self.static = dict(fk.basis)

    # --- what never moves: the lean toward the keys, the legs, the eyes
    def _static(self):
        fk = self.fk
        for n, deg in SPINE_LEAN:                            # +angle about armature +X leans toward -Y, the front
            fk.turn(n, (1, 0, 0), math.radians(deg))
        Lt, Ls = fk.dist("upperleg01.L", "lowerleg01.L"), fk.dist("lowerleg01.L", "foot.L")
        z_ank = fk.rest_head("foot.L").z + 0.02                # the ankle of a foot flat on the floor
        shin = math.sqrt(Ls * Ls - 0.07 ** 2)
        # the knee below the hip by whatever the bench height leaves (seat() measured the hips' height)
        knee_drop = max(-Lt * 0.5, min(Lt * 0.6, self.rig.get("hip_height", z_ank + shin) - (z_ank + shin)))
        reach = math.sqrt(Lt * Lt - knee_drop ** 2)
        for s, sx in (("L", 1.0), ("R", -1.0)):              # thighs forward, shins down, feet flat under the keyboard
            hip = fk.head(f"upperleg01.{s}")
            K = hip + Vector((sx * 0.035, -reach, -knee_drop))
            An = K + Vector((sx * 0.015, -0.07, -shin))
            fk.aim(f"upperleg01.{s}", K, tip=fk.head(f"lowerleg01.{s}"))
            fk.aim(f"lowerleg01.{s}", An, tip=fk.head(f"foot.{s}"))
            fd = fk.rest[f"foot.{s}"].to_3x3() @ Vector((0, 1, 0))
            fk.aim(f"foot.{s}", fk.head(f"foot.{s}") + fd)
        for n in ("eye.L", "eye.R"):
            fk.turn(n, (1, 0, 0), math.radians(20.0))

    def A(self, v):
        return self.Mi @ Vector(v)                           # a world point, in armature space

    # --- one hand: arm, forearm twist and wrist for the knuckle centre kc
    def _place_hand(self, s, sgn, kc, T):
        """T: {digit: target, armature space} for the digits on (or coming onto) a key.
        Returns how far, on average, the ones that cannot reach fall short."""
        fk, xk, yk, zk = self.fk, self.xk, self.yk, self.zk
        ac = xk * sgn                                        # index -> pinky
        d1 = (yk + zk * 0.10 - ac * HAND_IN).normalized()    # wrist -> knuckles: forward, the knuckles a little high
        F1 = frame3(d1, ac - zk * HAND_ROLL)
        mcp = [f"finger{n}-1.{s}" for n in (2, 3, 4, 5)]
        w0 = fk.rest_head(f"wrist.{s}")
        mcp0 = sum((fk.rest_head(n) for n in mcp), Vector()) / 4
        F0 = frame3(mcp0 - w0, fk.rest_head(mcp[3]) - fk.rest_head(mcp[0]))
        Rh = F1 @ F0.inverted()                              # the rest hand -> the hand over the keys
        Wt = kc - Rh @ (mcp0 - w0)                           # the wrist joint that puts the knuckles at kc
        S = fk.head(f"upperarm01.{s}")
        pole = -zk + xk * sgn * 0.55 - yk * 0.25             # elbows down, a little out and back
        E, W = two_bone(S, Wt, pole, self.La, self.Lf)
        self.out_of_reach[s] = max(self.out_of_reach.get(s, 0.0), (W - Wt).length)
        fk.aim(f"upperarm01.{s}", E, tip=fk.head(f"lowerarm01.{s}"))
        fk.aim(f"lowerarm01.{s}", W, tip=fk.head(f"wrist.{s}"))
        # pronation: most of the twist between the forearm and the hand goes to the forearm's twist bone
        want = Rh @ fk.rest[f"wrist.{s}"].to_3x3()
        m0 = fk.m0(f"wrist.{s}").to_3x3()
        q = (m0.inverted() @ want).to_quaternion()
        ax = (fk.head(f"wrist.{s}") - fk.head(f"lowerarm01.{s}")).normalized()
        twist = 2.0 * math.atan2(Vector((q.x, q.y, q.z)).dot(m0.inverted() @ ax), q.w)
        twist = (twist + math.pi) % (2 * math.pi) - math.pi
        fk.turn(f"lowerarm02.{s}", ax, twist * 0.75)
        fk.set_rot(f"wrist.{s}", want)
        short, k = Vector(), 0
        for j, t in T.items():                               # the thumb too: it plays from its own joint by the wrist
            b1, b2, b3 = (f"finger{DIGIT_BONE[j]}-{i}.{s}" for i in (1, 2, 3))
            reach = (fk.dist(b2, b1) + fk.dist(b3, b2) + fk.len[b3]) * 0.985
            v = t - fk.head(b1)
            need = v.normalized() * (v.length - reach) if v.length > reach else Vector()
            side = v.dot(ac)
            if j != 4 and abs(side) > SPLAY:                 # ... and a key too far to the side of its knuckle
                need += ac * math.copysign(abs(side) - SPLAY, side)
            if need.length > 0:
                short += need; k += 1
        return short / k if k else short

    def _thumb_target(self, hs):
        return self.A(hs["thumb"]) - self.zk * 0.004 - self.yk * THUMB_FRONT

    def _reach(self, s, j):
        b1, b2, b3 = (f"finger{DIGIT_BONE[j]}-{i}.{s}" for i in (1, 2, 3))
        return self.fk.dist(b2, b1) + self.fk.dist(b3, b2) + self.fk.len[b3]

    def _rest_tip(self, s, sgn, hs, j):
        """Where an idle digit rests, with the hand as it is posed now: ahead of its own knuckle, gently
        curved (REST_CURL of its reach), a hover above the keys; the thumb beside the index finger. It goes
        wherever the hand goes - the puppet's rest points are fixed to ITS knuckles, 4 cm from these."""
        fk, zk = self.fk, self.zk
        mcp = fk.head(f"finger2-1.{s}")
        pd = mcp - fk.head(f"wrist.{s}")
        pd = (pd - pd.dot(zk) * zk).normalized()             # the way the hand points, level
        if j == 4:
            return mcp - self.xk * sgn * 0.040 + pd * 0.035 - zk * (self.cp.PIANO_KC_UP * self.s_hand - 0.014)
        K = fk.head(f"finger{DIGIT_BONE[j]}-1.{s}")
        drop = (K - (self.A(hs["rest"][j]) - zk * PAD)).dot(zk)   # the knuckle above a hovering fingertip
        fwd = math.sqrt(max((REST_CURL * self._reach(s, j)) ** 2 - drop * drop, 0.02 ** 2))
        return K + pd * fwd - zk * drop

    def _targets(self, s, sgn, hs, digits):
        """{digit: target} for the digits on (or coming onto) a key, with the hand at its planned place.
        The plan keeps a finger "on" a held key while the hand glides away to the next note, up to 10 cm
        sideways in the fugue; a real finger lets go. So a key further to the side of its knuckle than a
        finger splays (SPLAY) is given up over the next SPLAY_FADE, the finger going back to rest; the
        thumb likewise, once its key is past its reach. A digit that has quite let go is not returned."""
        fk, zk = self.fk, self.zk
        ac = self.xk * sgn
        live = {}
        for j in digits:
            if j == 4:
                t = self._thumb_target(hs)
                over = (t - fk.head(f"finger1-1.{s}")).length - self._reach(s, 4) * 0.985 - THUMB_STRETCH
            else:
                t = self.A(hs["tips"][j]) - zk * PAD
                side = (t - fk.head(f"finger{DIGIT_BONE[j]}-1.{s}")).dot(ac)
                over = abs(side) - SPLAY
            if digits[j].get("age", 1.0) < LET_GO_AFTER:      # being played: the hand goes to it (_place_hand)
                over = 0.0
            elif over > 0 and j != 4:
                t = t - ac * math.copysign(over, side)
            if over > 0:
                w = min(1.0, over / SPLAY_FADE)
                if w >= 1.0:
                    continue
                t = t.lerp(self._rest_tip(s, sgn, hs, j), w * w * (3 - 2 * w))
            live[j] = t
        return live

    def _solve(self, st):
        """The hands for one instant: per side, where the knuckles' centre goes (after any pull toward a key
        out of reach) and each digit's target relative to it - on its key, letting go of it, or at rest."""
        cp, fk, yk, zk = self.cp, self.fk, self.yk, self.zk
        st = {k: v for k, v in st.items() if k in ("L", "R")}
        for s in "LR":                                       # the hand's path, taken over five frames (PianoPlayer._glide)
            if "glide" in st.get(s, {}):
                x, y, z = st[s]["glide"]
                st[s] = dict(st[s], x=x, y=y, z=z)
        hands, _ = cp.hands_piano(st, self.key)              # the puppet's own targets
        idle, _ = cp.hands_piano({s: {k: v for k, v in st.get(s, {}).items() if k != "digits"} for s in "LR"}, self.key)
        out = {}
        for s, sgn in (("L", -1.0), ("R", 1.0)):
            hs = dict(hands[s], rest=idle[s]["tips"])        # ... and where its fingers hover with nothing to play
            digits = st.get(s, {}).get("digits", {})
            kc = self.A(hs["kc"]) + zk * KNUCKLE_UP - yk * KNUCKLE_BACK
            arm = [f"{b}.{s}" for b in ("upperarm01", "lowerarm01", "lowerarm02", "wrist")]
            fk.forget(arm)
            self._place_hand(s, sgn, kc, {})                 # the hand where the plan has it
            live = self._targets(s, sgn, hs, digits)
            for _ in range(4):                               # a finger that cannot reach its key pulls the hand over
                fk.forget(arm)
                short = self._place_hand(s, sgn, kc, live)
                if short.length < 0.0008:
                    break
                kc = kc + short
            T = {j: (live[j] if j in live else self._rest_tip(s, sgn, hs, j)) - kc for j in range(5)}
            keys = {j: (self._thumb_target(hs) if j == 4 else self.A(hs["tips"][j]) - zk * PAD) for j in digits}
            out[s] = dict(kc=kc, T=T, keys=keys, live=set(live),
                          press={j: float(digits[j].get("press", 0.0)) for j in live})
        return out

    def _hands(self, st):
        """Both hands, as the weighted average of five instants around this one (SMOOTH). Taken one instant
        at a time a digit's target jumps the frame its note comes into the plan (0.08 s before the onset:
        from rest to its key, 3 cm), and so does the hand when a key out of reach pulls it; averaged, both
        take five frames and the pose stays a function of the music time alone. While its key is down a
        finger is put on it exactly, whatever the average says (it would start leaving two frames early):
        measured on the fugue, a third of the held notes were over 2 mm off their keys without that."""
        cp, fk, zk = self.cp, self.fk, self.zk
        at = st.get("at")
        sols = [(w, self._solve(st if k == 0 or at is None else at(k * FRAME))) for k, w in (SMOOTH if at else ((0, 1.0),))]
        wsum = sum(w for w, _ in sols)
        now = next(sol for (k, _w), (_w2, sol) in zip(SMOOTH if at else ((0, 1.0),), sols) if k == 0)
        digits = {s: st.get(s, {}).get("digits", {}) for s in "LR"}
        for s, sgn in (("L", -1.0), ("R", 1.0)):
            ac = self.xk * sgn
            kc = sum((sol[s]["kc"] * w for w, sol in sols), Vector()) / wsum
            arm = [f"{b}.{s}" for b in ("upperarm01", "lowerarm01", "lowerarm02", "wrist")]
            # how far down each key is now, eased: a key that is down has its finger on it exactly, and the
            # averaged hand, which may still be on its way in a fast passage, is pulled in as far as that takes
            # (how far down is itself averaged over the five instants, or the finger would snap onto the key
            # the frame it starts to move: 0.03 s takes a key down, one frame)
            down = {j: sum(w * sol[s]["press"].get(j, 0.0) for w, sol in sols) / wsum for j in now[s]["live"]}
            down = {j: a for j, a in down.items() if a > 0}
            for _ in range(5):
                fk.forget(arm)
                self._place_hand(s, sgn, kc, {})
                pull, n = Vector(), 0
                for j, a in down.items():
                    v = now[s]["kc"] + now[s]["T"][j] - fk.head(f"finger{DIGIT_BONE[j]}-1.{s}")
                    over = v.length - self._reach(s, j) * 0.985
                    if over > 0:
                        pull += v.normalized() * over * a; n += 1
                if n == 0 or pull.length / n < 0.0005:
                    break
                kc = kc + pull / n
            # digits: joint positions from concert_poses.finger_chain (fixed bone lengths), bones aimed at them
            pd = (fk.head(f"finger3-1.{s}") - fk.head(f"wrist.{s}")).normalized()
            palm = (-zk - (-zk).dot(pd) * pd).normalized()
            for j in range(5):
                b1, b2, b3 = (f"finger{DIGIT_BONE[j]}-{i}.{s}" for i in (1, 2, 3))
                T = sum((sol[s]["T"][j] * w for w, sol in sols), Vector()) / wsum
                if j in down:                                # the average only leads into and out of a held key
                    T = T.lerp(now[s]["kc"] + now[s]["T"][j] - kc, down[j])
                    if digits[s][j].get("press", 0.0) >= 1.0 and now[s]["T"][j] == now[s]["keys"][j] - now[s]["kc"]:
                        self.on_key[(s, j)] = now[s]["keys"][j]   # for the checks: held, and the hand has not left it
                T = kc + T
                lens = [fk.dist(b2, b1), fk.dist(b3, b2), fk.len[b3]]
                if j == 4:
                    pts = cp.finger_chain(fk.head(b1), T, ac - zk * 0.35, lens, pd, coupling=(0.45, 0.55))
                else:
                    pts = cp.finger_chain(fk.head(b1), T, palm - pd, lens, pd)
                fk.aim(b1, pts[1], tip=fk.head(b2)); fk.aim(b2, pts[2], tip=fk.head(b3)); fk.aim(b3, pts[3])
                tip = fk.tail(b3)
                self.tips[(s, j)] = (tip, now[s]["keys"].get(j, T), j in now[s]["keys"], j in now[s]["live"])
                if j in now[s]["keys"]:                      # how far this fingertip really has its key down
                    d = digits[s][j]
                    off = tip - now[s]["keys"][j]            # from where the plan has the fingertip, on the key
                    up = off.dot(zk)
                    side = (off - zk * up).length
                    held = 1.0 - min(1.0, max(0.0, (side - OVER_KEY[0]) / OVER_KEY[1]))
                    dip = max(0.0, min(d.get("press", 0.0), d.get("press", 0.0) - up / cp.KEY_DIP)) * held * held * (3 - 2 * held)
                    self.dips[d["m"]] = max(self.dips.get(d["m"], 0.0), dip)

    def pose(self, state=None):
        st = state or {}
        fk = self.fk
        fk.basis, fk.cache = dict(self.static), {}
        self.tips, self.out_of_reach, self.on_key, self.dips = {}, {}, {}, {}
        yaw, pitch = st.get("head") or (0.0, 0.0)            # + yaw toward the player's left, + pitch looking down
        base = dict(HEAD_DOWN)
        for n, share in HEAD_SHARE:
            fk.turn(n, (1, 0, 0), math.radians(base.get(n, 0.0)) + pitch * share)
            fk.turn(n, (0, 0, 1), yaw * share)
        self._hands(st)
        # The keys, last (_solve looked at other instants). A key is down as far as a fingertip has it down, and
        # not otherwise: the plan's own "dips" keep a key down for the whole note, up to 1.2 s, though the hand
        # has long gone to the next one - with real hands on the keys, a key held down by nobody.
        self.cp.set_key_dips(self.key, self.dips)
        fk.apply()
        blink = st.get("blink", 0.0)
        for ob in self.meshes:
            kb = ob.data.shape_keys.key_blocks
            for k, v in FACE.items():
                if k in kb:
                    kb[k].value = v
            for k in ("eyeBlinkLeft", "eyeBlinkRight"):
                if k in kb:
                    kb[k].value = max(0.12, blink)


_HUMANS = {}


def human_for(key):
    """The HumanPianist for a player whose stage has a human on it, else None (the puppet plays)."""
    rig = bpy.data.objects.get(rig_name(key))
    if rig is None:
        return None
    h = _HUMANS.get(key)
    if h is None or h.rig != rig:                            # another .blend opened in the same session
        h = _HUMANS[key] = HumanPianist(key, rig)
    return h


# ─────────────────────────────── 2. seat ───────────────────────────────
def seat(key, human_blend):
    """Append the built person to the open stage and sit them at the instrument."""
    import concert_poses as cp
    cp.load_layout()
    scene = bpy.data.scenes["Concert Stage"]
    old = bpy.data.collections.get(rig_name(key))
    if old:                                                  # seated before: out with the old one
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    with bpy.data.libraries.load(str(human_blend), link=False) as (src, dst):
        dst.objects = list(src.objects)
    col = bpy.data.collections.new(rig_name(key)); scene.collection.children.link(col)
    objs = [o for o in dst.objects if o is not None]
    for o in objs:
        col.objects.link(o)
        if o.type != "ARMATURE":
            o.name = f"{rig_name(key)} {o.name.split('.', 1)[-1]}"
    rig = next(o for o in objs if o.type == "ARMATURE")
    rig.name = rig_name(key)
    for o in bpy.data.objects:                               # the puppet stays, unseen
        if o.name.startswith(cp.body_name(key)):
            o.hide_render = True; o.hide_viewport = True
    bench = bpy.data.objects[f"Bench - {key}"]
    if "x_before_human" in bench:                            # seated before: the bench back where the puppet had it
        bench.location.x = bench["x_before_human"]
    bench["x_before_human"] = bench.location.x
    bpy.context.view_layer.update()

    fk = FK(rig)
    for n, deg in SPINE_LEAN:
        fk.turn(n, (1, 0, 0), math.radians(deg))
    hands, _ = cp.hands_piano(None, key)
    piano = bpy.data.objects[key]
    Yk = (piano.matrix_world.to_3x3() @ Vector((0, 1, 0))).normalized()
    pts = [bench.matrix_world @ Vector(c) for c in bench.bound_box]
    bench_top, bench_x = max(p.z for p in pts), sum(p.x for p in pts) / 8
    z_hip = bench_top + 0.085                                # the hip joints of someone sitting on it
    La, Lf = fk.dist("upperarm01.L", "lowerarm01.L"), fk.dist("lowerarm01.L", "wrist.L")
    hip0 = (fk.rest_head("upperleg01.L") + fk.rest_head("upperleg01.R")) / 2
    shoulders = (fk.head("upperarm01.L") + fk.head("upperarm01.R")) / 2
    sh_fwd = -(shoulders.y - hip0.y)                         # shoulders ahead of the hips, with the lean
    wrist_x = sum((hands[s]["kc"] - Yk * 0.11).x for s in "LR") / 2
    # level forearms: the hips far enough from the keys that the elbows hang a little ahead of the shoulders
    x_hip = wrist_x - (Lf * 0.98 + La * math.sin(math.radians(16))) - sh_fwd
    p_, _f, _l, _u = cp.frame(key)
    Rz = Matrix.Rotation(math.pi / 2, 4, "Z")                # MPFB faces -Y; the player faces +X
    rig.matrix_world = Matrix.Translation(Vector((x_hip, p_[1], z_hip))) @ Rz @ Matrix.Translation(-hip0)
    rig["hip_height"] = z_hip - p_[2]                        # above the floor; HumanPianist._static sets the legs by it
    bench.location.x += (x_hip - 0.03) - bench_x
    bpy.context.view_layer.update()
    h = human_for(key)
    h.pose(None)
    _cameras(key, h, x_hip - p_[0])
    print(f"[human] {key}: seated, hips at x={x_hip:.3f} z={z_hip:.3f}; the bench moved {(x_hip - 0.03) - bench_x:+.3f} m; "
          f"{len(objs)} objects in '{col.name}'; the puppet is hidden")
    return rig


# The two cameras that were placed on the puppet rather than on the instrument. The human sits further
# from the keys (longer arms) and taller: the over-the-shoulder camera moves back by as much, and the
# face camera is aimed at this head, from lower and further round to the front than the puppet's - a
# pianist looks down, and long hair hides the face from the side.
PLAYER_CAMS = {"Piano": {"shoulder": "Cam 62 Piano Over the Shoulder",
                         "face": ("Cam 63 Piano Face", (1.35, 1.30, 0.05))}}   # offset from the head, instrument axes


FACE_CAM_DROP = 0.09


def _cameras(key, h, back):
    spec = PLAYER_CAMS.get(key, {})
    cam = bpy.data.objects.get(spec.get("shoulder", ""))
    if cam is not None:
        if "loc_before_human" in cam:
            cam.location = Vector(cam["loc_before_human"])
        cam["loc_before_human"] = list(cam.location)
        cam.location.x += back
    name, off = spec.get("face", ("", None))
    cam, tgt = bpy.data.objects.get(name), bpy.data.objects.get(name + " Target")
    if cam is not None and tgt is not None:
        centre = h.rig.matrix_world @ h.fk.head("head").lerp(h.fk.tail("head"), 0.5)
        cam.location = centre + bpy.data.objects[key].matrix_world.to_3x3() @ Vector(off)
        # aimed below the head as it sits at rest: playing, the player looks down at the keys (13 degrees on
        # average, the head planner), and the face drops into the bottom of a frame centred on the rest pose
        tgt.location = centre - UP * FACE_CAM_DROP


def main():
    import argparse
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser(prog="concert_human.py")
    p.add_argument("job", choices=("build", "dress", "seat"))
    p.add_argument("--key", default="Piano")
    p.add_argument("--human", default="Pianist_Human.blend", help="seat: the built person")
    p.add_argument("--out", required=True, help="the .blend to write")
    a = p.parse_args(argv)
    t = time.time()
    if a.job == "build":
        build(a.key, Path(a.out).resolve())
    elif a.job == "dress":
        dress(a.key)
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(Path(a.out).resolve()), compress=True)
        print(f"[human] {a.key}: dressed -> {a.out} ({Path(a.out).stat().st_size / 1e6:.1f} MB)")
    else:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        seat(a.key, Path(a.human).resolve())
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(Path(a.out).resolve()))
    print(f"[human] {a.job} done in {time.time() - t:.1f}s")


if __name__ == "__main__":
    main()
