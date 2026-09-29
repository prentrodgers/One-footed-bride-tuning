"""
concert_poses.py - players for Concert_Stage.blend, posed by musical state.

Each musician is a static BODY mesh (torso, head, legs, shoulders) plus two
PUPPET arms: upper arm, forearm, wrist, palm, four three-joint fingers and a
thumb, every piece its own object sharing a handful of unit meshes. Posing a
player is then just setting ~76 object matrices (microseconds), where
rebuilding a musician mesh costs ~0.6 s - far too slow to do per frame on the
render farm.

The per-instrument functions below (hands_<instrument>) turn a musical state
(frets and strings, bow position, keys down, mallet targets, slide position)
into hand targets {kc, tips[4], thumb, optional wrist/elbow} in world space,
exactly as the stage was hand-posed over Blender MCP. With no state they give
that rest pose.

Used two ways:
  * interactively (Blender MCP):  build_all() converts the musicians to puppets
  * per frame (concert_stage.py): pose(key, state) moves one player
"""
import json
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import concert_stagekit as sk

UP = Vector((0, 0, 1))
UA, FA = 0.29, 0.27

# player key -> (musician index, lean, knee_spread)
PLAYERS = {
    "Baritone Flying V": (0, 0.05, 0.04), "Violin": (1, 0.0, 0.04), "Finger Piano": (2, 0.10, 0.08),
    "Bass Finger Piano": (3, 0.10, 0.08), "Flute": (4, 0.0, 0.04), "Clarinet": (5, 0.0, 0.04),
    "Oboe": (6, 0.0, 0.04), "Marimba": (7, 0.07, 0.04), "Cello": (8, 0.03, 0.15), "Trumpet": (9, 0.0, 0.04),
    "Tuba": (10, 0.02, 0.10), "Bassoon": (11, 0.02, 0.20), "Viola": (12, 0.0, 0.04), "French Horn": (13, 0.03, 0.04),
    "Trombone": (14, 0.0, 0.04), "Vibraphone": (15, 0.05, 0.04),
}


def load_layout():
    ctrl = bpy.data.objects["Stage Controls"]
    sk.LAYOUT = json.loads(ctrl["layout_json"])
    return sk.LAYOUT


def body_name(key):
    return f"Musician {PLAYERS[key][0] + 1} - {key}"


def frame(key):
    return sk.frame_for(key)


def shoulders(key):
    p, f, l, up = frame(key)
    idx, lean, _ = PLAYERS[key]
    seated = sk.LAYOUT[key]["seated"]
    pel = p + UP * (0.53 if seated else 0.96) + (f * 0.02 if seated else Vector())
    neckb = pel + UP * ((0.50 if seated else 0.47) + 0.04) + f * lean
    return {"L": neckb - UP * 0.05 + l * 0.19, "R": neckb - UP * 0.05 - l * 0.19}


def _mats(i):
    return [sk.mat(f"Skin {i}", sk.SKINS[i % 12], rough=0.45), sk.mat(f"Shirt {i}", sk.SHIRTS[i % 12], rough=0.75),
            sk.mat("Concert Black Cloth", (0.03, 0.03, 0.035), rough=0.85), sk.mat("Shoe Leather", (0.015, 0.012, 0.01), rough=0.35),
            sk.mat(f"Hair {i}", sk.HAIRS[i % 12], rough=0.55), sk.mat("Eye Dark", (0.01, 0.01, 0.01), rough=0.2)]


# ─────────────────────────────── body ───────────────────────────────
def build_body(key, leg_style="normal"):
    """Torso, head, legs and shoulder caps - everything that does not move while playing."""
    idx, lean, knee_spread = PLAYERS[key]
    p, f, l, up = frame(key); right = -l
    seated = sk.LAYOUT[key]["seated"]
    B = sk.Builder()
    Rb = Matrix((right, f, UP)).transposed().to_4x4()
    pel = p + UP * (0.53 if seated else 0.96) + (f * 0.02 if seated else Vector())
    neckb = pel + UP * ((0.50 if seated else 0.47) + 0.04) + f * lean
    axis = (neckb - pel).normalized()
    Rt = Matrix((right, axis.cross(right).normalized(), axis)).transposed().to_4x4()
    B.sphere(pel + UP * 0.02, 1.0, mi=2, scale=(0.17, 0.12, 0.12), rot=Rb, seg=20, rings=10)
    B.sphere(pel.lerp(neckb, 0.52), 1.0, mi=1, scale=(0.19, 0.12, 0.27), rot=Rt, seg=24, rings=12)
    head = neckb + UP * 0.155 + f * (0.01 + lean * 0.5)
    B.cyl(neckb - UP * 0.02, head - UP * 0.06, 0.048, mi=0, seg=12)
    B.sphere(head, 0.105, mi=0, scale=(0.9, 1.0, 1.12), rot=Rb, seg=24, rings=14)
    B.sphere(head - f * 0.02 + UP * 0.03, 0.104, mi=4, scale=(0.95, 0.98, 1.08), rot=Rb, seg=24, rings=14)
    B.sphere(head + f * 0.1 - UP * 0.01, 0.018, mi=0, scale=(0.8, 1.2, 1.3), rot=Rb, seg=10, rings=6)
    for s in (-1, 1):
        B.sphere(head + f * 0.088 + l * s * 0.035 + UP * 0.02, 0.011, mi=5, seg=10, rings=6)
    for S in shoulders(key).values():
        B.sphere(S, 0.052, mi=1, seg=14, rings=8)
    for side in (1, -1):
        hip = pel + l * side * 0.095
        if seated:
            knee = hip + f * 0.44 + UP * 0.03 + l * side * knee_spread
            lift = 0.15 if (leg_style == "footstool" and side == 1) else 0.0
            if lift:
                knee = knee + UP * 0.12
            ankle = Vector((knee.x, knee.y, p.z + 0.09 + lift)) + f * 0.04
        else:
            knee = hip - UP * 0.44 + f * 0.02 + l * side * 0.02
            ankle = Vector((knee.x, knee.y, p.z + 0.09)) + l * side * 0.02
        B.cyl(hip, knee, 0.075, mi=2, seg=14, r2=0.056); B.sphere(knee, 0.056, mi=2, seg=12, rings=8)
        B.cyl(knee, ankle, 0.052, mi=2, seg=14, r2=0.042)
        B.box(ankle + f * 0.06 - UP * 0.05, (0.10, 0.27, 0.08), mi=3, rot=Rb)
    ob = B.build(body_name(key), _mats(idx), collection=sk.coll("Musicians"), smooth=True)
    ob["player"] = key
    return ob


# ─────────────────────────────── puppet arms ───────────────────────────────
# (part, kind, material 0=skin 1=shirt, base radius, taper)
_FINGER_R = [(0.0092, 0.0086, 0.0080, 0.0074)] * 3 + [(0.0080, 0.0075, 0.0070, 0.0066)]
_FINGER_L = (0.080, 0.088, 0.083, 0.066)


def _parts():
    parts = [("upper", "cyl", 1, 0.047, 0.040 / 0.047), ("elbow", "sph", 1, 0.040, 1), ("forearm", "cyl", 1, 0.038, 0.029 / 0.038),
             ("wrist", "sph", 0, 0.024, 1), ("palm", "sph", 0, 1.0, 1)]
    for i in range(4):
        rr = _FINGER_R[i]
        parts.append((f"f{i}k", "sph", 0, 0.0095, 1))
        for j in range(3):
            parts.append((f"f{i}s{j}", "cyl", 0, rr[j], rr[j + 1] / rr[j]))
            parts.append((f"f{i}j{j}", "sph", 0, rr[j + 1], 1))
    parts += [("t0", "cyl", 0, 0.0115, 0.0098 / 0.0115), ("tj0", "sph", 0, 0.0098, 1),
              ("t1", "cyl", 0, 0.0098, 0.0085 / 0.0098), ("tj1", "sph", 0, 0.0085, 1)]
    return parts


def _unit_mesh(kind, taper):
    name = f"PUP {kind} {taper:.3f}" if kind == "cyl" else "PUP sph"
    me = bpy.data.meshes.get(name)
    if me:
        return me
    bm = bmesh.new()
    if kind == "cyl":       # unit length along +Z from 0 to 1, radius 1 at the base
        bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=1.0, radius2=taper, depth=1.0,
                              matrix=Matrix.Translation((0, 0, 0.5)))
    else:
        bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=1.0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    me.materials.append(None)
    return me


def build_puppet(key):
    """Create (or recreate) the 2 x 38 arm/hand objects for a player."""
    idx = PLAYERS[key][0]
    mats = _mats(idx)
    col = sk.coll("Musicians")
    pup = {}
    for side in ("L", "R"):
        for part, kind, mi, r, taper in _parts():
            name = f"{body_name(key)} {side} {part}"
            old = bpy.data.objects.get(name)
            if old:
                bpy.data.objects.remove(old, do_unlink=True)
            ob = bpy.data.objects.new(name, _unit_mesh(kind, taper))
            col.objects.link(ob)
            ob.material_slots[0].link = 'OBJECT'
            ob.material_slots[0].material = mats[mi]
            ob["r"] = r
            pup[(side, part)] = ob
    return pup


def get_puppet(key):
    return {(side, part): bpy.data.objects[f"{body_name(key)} {side} {part}"] for side in ("L", "R") for part, *_ in _parts()}


def _seg(ob, a, b):
    d = b - a
    r = ob["r"]
    ob.matrix_world = Matrix.Translation(a) @ sk.look_rot(d) @ Matrix.Diagonal((r, r, max(d.length, 1e-4), 1.0))


def _ball(ob, c, scale=1.0, rot=None):
    r = ob["r"] * scale
    ob.matrix_world = Matrix.Translation(c) @ (rot if rot is not None else Matrix.Identity(4)) @ Matrix.Diagonal((r, r, r, 1.0))


def _bez(p0, c, p1, t):
    return (1 - t) ** 2 * p0 + 2 * (1 - t) * t * c + t * t * p1


def _elbow(S, H, pole):
    d = (H - S).length
    if d > UA + FA - 0.005:
        H = S + (H - S).normalized() * (UA + FA - 0.005); d = (H - S).length
    dv = (H - S).normalized()
    x = (UA * UA - FA * FA + d * d) / (2 * d); h = math.sqrt(max(UA * UA - x * x, 0.0))
    pp = pole - pole.dot(dv) * dv
    pp = pp.normalized() if pp.length > 1e-6 else Vector((0, 0, -1))
    return S + dv * x + pp * h, H


def _wrist_for(S, spec):
    if "wrist" in spec:
        return Vector(spec["wrist"])
    kc = Vector(spec["kc"])
    return kc + ((S - kc).normalized() - UP * 0.45).normalized() * 0.085


def pose_arm(pup, side, S, spec, pole):
    W = _wrist_for(S, spec)
    if "elbow" in spec:
        E = Vector(spec["elbow"])
    else:
        E, W2 = _elbow(S, W, pole)
        if (W2 - W).length > 1e-4:          # out of reach: slide the hand toward the shoulder
            dlt = W2 - W
            spec = dict(kc=Vector(spec["kc"]) + dlt, tips=[Vector(t) + dlt for t in spec["tips"]], thumb=Vector(spec["thumb"]) + dlt)
            W = W2
    g = lambda part: pup[(side, part)]
    _seg(g("upper"), S, E); _ball(g("elbow"), E); _seg(g("forearm"), E, W)
    wr = g("wrist"); rw = wr["r"]
    wr.matrix_world = Matrix.Translation(W) @ sk.look_rot(W - E) @ Matrix.Diagonal((rw * 1.3, rw, rw, 1.0))
    kc = Vector(spec["kc"]); tips = [Vector(t) for t in spec["tips"]]; th = Vector(spec["thumb"])
    pd = kc - W; plen = pd.length; pd.normalize()
    ac = tips[3] - tips[0]; ac = ac - ac.dot(pd) * pd
    if ac.length < 1e-5:
        ac = pd.orthogonal()
    ac.normalize()
    ny = pd.cross(ac).normalized()
    Rp = Matrix((ac, ny, pd)).transposed().to_4x4()
    g("palm").matrix_world = Matrix.Translation((W + kc) / 2) @ Rp @ Matrix.Diagonal((0.041, 0.016, plen / 2 + 0.010, 1.0))
    for i in range(4):
        k = kc + ac * (-0.027 + 0.018 * i)
        t = tips[i]
        if (t - k).length > _FINGER_L[i]:
            t = k + (t - k).normalized() * _FINGER_L[i]
        c = k + pd * min(0.045, (t - k).length * 0.65)
        pts = [_bez(k, c, t, s) for s in (0.0, 0.42, 0.78, 1.0)]
        _ball(g(f"f{i}k"), k)
        for j in range(3):
            _seg(g(f"f{i}s{j}"), pts[j], pts[j + 1]); _ball(g(f"f{i}j{j}"), pts[j + 1])
    base = W + pd * 0.028 - ac * 0.030
    if (th - base).length > 0.075:
        th = base + (th - base).normalized() * 0.075
    c = base + pd * 0.022 - ac * 0.012
    pts = [_bez(base, c, th, s) for s in (0.0, 0.5, 1.0)]
    _seg(g("t0"), pts[0], pts[1]); _ball(g("tj0"), pts[1]); _seg(g("t1"), pts[1], pts[2]); _ball(g("tj1"), pts[2])


# ─────────────────────────────── helpers shared by the instruments ───────────────────────────────
def _M(name):
    mw = bpy.data.objects[name].matrix_world
    return mw, (lambda v: mw @ Vector(v))


def _lift(pts, direction, lifts):
    return [Vector(p) + direction * (lifts[i] if lifts else 0.0) for i, p in enumerate(pts)]


def _side_hand(key, side, tips, thumb, front, axis):
    """Woodwind hand: knuckles on the hand's own side of the tube, a little behind it."""
    c = sum(tips, Vector()) / 4
    lat = shoulders(key)[side] - c
    lat -= lat.dot(axis) * axis; lat -= lat.dot(front) * front; lat.normalize()
    return dict(kc=c + lat * 0.050 - front * 0.020, tips=tips, thumb=thumb)


def _radial(mw, pts_local, extra=0.0075, lifts=None):
    out = []
    for i, q in enumerate(pts_local):
        q = Vector(q); a = mw @ Vector((q.x, 0, 0)); w = mw @ q
        out.append(w + (w - a).normalized() * (extra + (lifts[i] if lifts else 0.0)))
    return out


# ─────────────────────────────── instruments ───────────────────────────────
# Every function: (state dict or None) -> (hands {"L": spec, "R": spec}, pole {"L": v, "R": v})
# plus it may move its own auxiliary objects (bows, mallets, slide).

# ---- baritone Flying V (27" scale, joins at fret 16) ----
_V_SCALE = 0.686
_V_XN = _V_SCALE * (1 - 2 ** (-16 / 12)); _V_XS = _V_XN - _V_SCALE
_vfx = lambda n: _V_XN - _V_SCALE * (1 - 2 ** (-n / 12))


def guitar_string_point(x, i):
    t = (_V_XN - x) / (_V_XN - _V_XS)
    yn = 0.018 - 0.0072 * i; ys = 0.026 - 0.0104 * i
    return Vector((x, yn + (ys - yn) * t, 0.0125 + 0.0055 * t))


def hands_guitar(state=None):
    st = state or {}
    key = "Baritone Flying V"
    mw, M = _M(key)
    Zg = (mw.to_3x3() @ Vector((0, 0, 1))).normalized()
    p, f, l, up = frame(key)
    stops = st.get("stops", [(5, 0), (6, 3), (7, 1), (7, 2)])        # (fret, string) for index..pinky; fret 0 = lifted
    lifts = st.get("lifts", [0.0] * 4)
    tips = []
    for (n, s), lift in zip(stops, lifts):
        n = max(n, 1)
        x = _vfx(n) + 0.25 * (_vfx(n - 1) - _vfx(n))
        tips.append(mw @ guitar_string_point(x, s) + Zg * (0.0078 + lift))
    ref = max(1, stops[1][0])
    lh = dict(kc=M((_vfx(ref), -0.052, -0.004)), tips=tips, thumb=M((_vfx(ref) + 0.01, 0.012, -0.026)))
    dz = st.get("pick_dy", 0.0)                                         # strumming: pick travels across the strings (local y)
    xs = _V_XS
    rh = dict(elbow=M((-0.40, 0.205, 0.045)), wrist=M((-0.225, 0.080 + dz * 0.6, 0.080)),
              kc=M((xs + 0.150, 0.035 + dz, 0.070)),
              tips=[M((xs + 0.116, 0.010 + dz, 0.027)), M((xs + 0.135, -0.010 + dz, 0.030)), M((xs + 0.150, -0.024 + dz, 0.027)),
                    M((xs + 0.166, -0.042 + dz * 0.3, 0.012))],
              thumb=M((xs + 0.112, 0.016 + dz, 0.019)))
    pick = bpy.data.objects.get("Baritone Flying V Pick")
    if pick:
        pick.location = Vector((0, dz, 0))
    return {"L": lh, "R": rh}, {"L": -UP + l * 0.9 + f * 0.2}


# ---- violin / viola (viola = violin geometry scaled 1.15 by its rig) ----
_vol = None


def _violin_geo():
    global _vol
    if _vol is None:
        ol, cx = sk.outline((-0.262, 0.094, 0.102), (-0.086, 0.086, 0.083), n=96, k=0.025)
        _vol = dict(x_b=-0.195, x_n=0.133, fb_end=0.133 - 0.270, z_sn=0.0265,
                    z_bt=sk.arch_z(ol, cx, -0.195, 0, 0.0155, 0.0155) + 0.033, sp_b=0.0113, sp_n=0.0055)
    return _vol


_cel = None


def _cello_geo():
    global _cel
    if _cel is None:
        ol, cx = sk.outline((-0.555, 0.20, 0.220), (-0.180, 0.18, 0.172), n=96, k=0.05)
        _cel = dict(x_b=-0.40, x_n=0.29, fb_end=0.29 - 0.58, z_sn=0.081,
                    z_bt=sk.arch_z(ol, cx, -0.40, 0, 0.06, 0.026) + 0.09, sp_b=0.0155, sp_n=0.0078)
    return _cel


def bowed_string_point(G, x, i):
    t = (G["x_n"] - x) / (G["x_n"] - G["x_b"])
    yn = G["sp_n"] * (1.5 - i); yb = G["sp_b"] * (1.5 - i)
    return Vector((x, yn + (yb - yn) * t, G["z_sn"] + (G["z_bt"] - G["z_sn"]) * t))


def pose_bow(bow_name, frog, along, normal):
    ob = bpy.data.objects.get(bow_name)
    if not ob:
        return
    a = along.normalized(); n = (normal - normal.dot(a) * a).normalized(); s = a.cross(n).normalized()
    ob.matrix_world = Matrix.Translation(frog) @ Matrix((s, a, n)).transposed().to_4x4()


def bow_grip(frog, along, normal, player_fwd):
    a = Vector(along).normalized(); n = Vector(normal); n = (n - n.dot(a) * a).normalized()
    s = a.cross(n).normalized()
    if s.dot(player_fwd) < 0:
        s = -s
    G = Vector(frog) + n * 0.017 - a * 0.030
    tips = [G - a * 0.040 + s * 0.010 - n * 0.004, G - a * 0.020 + s * 0.012 - n * 0.006,
            G - a * 0.002 + s * 0.010 - n * 0.005, G + a * 0.016 + n * 0.008]
    return dict(kc=G + n * 0.040 - s * 0.030 - a * 0.012, tips=tips, thumb=G - n * 0.010 + a * 0.004 - s * 0.004)


def hands_violin(state=None, key="Violin"):
    st = state or {}
    G = _violin_geo()
    mw, M = _M(key)
    R3 = mw.to_3x3()
    Zw = (R3 @ Vector((0, 0, 1))).normalized(); Yw = (R3 @ Vector((0, 1, 0))).normalized()
    p, f, l, up = frame(key); right = -l
    stops = st.get("stops", [(0.034, 2, 0.0), (0.060, 3, 0.004), (0.084, 1, 0.0), (0.104, 2, 0.006)])   # (dist from nut, string, lift)
    shift = st.get("shift", 0.0)                                                                       # hand position along the neck
    tips = [mw @ bowed_string_point(G, G["x_n"] - d, s) + Zw * (0.0065 + lift) for d, s, lift in stops]
    lh = dict(kc=M((G["x_n"] - 0.068 - shift, -0.044, 0.004)), tips=tips, thumb=M((G["x_n"] - 0.036 - shift, 0.017, 0.011)))
    xc = G["x_b"] + (G["fb_end"] - G["x_b"]) * 0.4
    bow_string = st.get("bow_string", 1.5)
    contact = mw @ (bowed_string_point(G, xc, bow_string) + Vector((0, 0, 0.0005)))
    along = Yw if Yw.dot(right) > 0 else -Yw
    tilt = (bow_string - 1.5) * 0.12                         # lower strings -> bow arm rises
    along = (along + Zw * tilt).normalized()
    frog = contact + along * st.get("frog_dist", 0.22)       # bow position: 0.05 (at the frog) .. 0.70 (at the tip)
    pose_bow(f"{key} Bow", frog, along, Zw)
    rh = bow_grip(frog, along, Zw, f)
    return {"L": lh, "R": rh}, {"L": -UP + right * 0.5 + f * 0.1, "R": -UP + right * 0.9}


def hands_viola(state=None):
    return hands_violin(state, key="Viola")


def hands_cello(state=None):
    st = state or {}
    G = _cello_geo()
    key = "Cello"
    mw, M = _M(key)
    R3 = mw.to_3x3()
    Zc = (R3 @ Vector((0, 0, 1))).normalized(); Yc = (R3 @ Vector((0, 1, 0))).normalized()
    p, f, l, up = frame(key); right = -l
    a_side = -1 if Yc.dot(l) < 0 else 1
    stops = st.get("stops", [(0.074, 2, 0.0), (0.110, 2, 0.0), (0.142, 2, 0.0), (0.174, 2, 0.0)])
    shift = st.get("shift", 0.0)
    tips = [mw @ bowed_string_point(G, G["x_n"] - d, s) + Zc * (0.0085 + lift) for d, s, lift in stops]
    lh = dict(kc=M((G["x_n"] - 0.125 - shift, 0.062 * a_side, 0.058)), tips=tips, thumb=M((G["x_n"] - 0.11 - shift, 0.0, 0.031)))
    xc = G["x_b"] + (G["fb_end"] - G["x_b"]) * 0.35
    bow_string = st.get("bow_string", 1.5)
    contact = mw @ (bowed_string_point(G, xc, bow_string) + Vector((0, 0, 0.0008)))
    along = Yc if Yc.dot(right) > 0 else -Yc
    along = (along - UP * 0.15 + Zc * (bow_string - 1.5) * 0.12).normalized()
    frog = contact + along * st.get("frog_dist", 0.30)
    pose_bow("Cello Bow", frog, along, Zc)
    rh = bow_grip(frog, along, Zc, f)
    return {"L": lh, "R": rh}, {"L": l * 1.0 - UP * 0.25, "R": -UP + right * 0.7}


# ---- chromatic finger pianos (49 tines, piano layout) ----
NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
_ACC = {1, 3, 6, 8, 10}
FP_SPEC = {   # K (size), lowest MIDI, tine width, thickness, solder radius, natural pitch
    "Finger Piano": (1.0, 48, 0.0055, 0.0012, 0.0022, 0.0145),
    "Bass Finger Piano": (3.0, 24, 0.013, 0.0030, 0.0066, 0.0435),
}


def tine_length(f, b, h, m_tip, E=200e9, rho=7850.0):
    I = b * h ** 3 / 12; A = b * h; lo, hi = 0.004, 0.8
    for _ in range(60):
        L = (lo + hi) / 2
        fL = math.sqrt((3 * E * I / L ** 3) / (m_tip + 0.2357 * rho * A * L)) / (2 * math.pi)
        lo, hi = (L, hi) if fL > f else (lo, L)
    return (lo + hi) / 2


_fp_cache = {}


def fp_tines(key):
    """Every tine of a finger piano, low to high: name, midi, acc, x, tip point (rig-local), bridge y."""
    if key in _fp_cache:
        return _fp_cache[key]
    K, midi0, b, h, sr, pn = FP_SPEC[key]
    m_tip = 8400.0 * (4 / 3) * math.pi * sr ** 3 * 0.6
    notes = []
    for k in range(49):
        midi = midi0 + k; pc = midi % 12
        f = 440.0 * 2 ** ((midi - 69) / 12)
        notes.append(dict(name=f"{NAMES[pc]}{midi // 12 - 1}", midi=midi, acc=pc in _ACC, L=tine_length(f, b, h, m_tip)))
    nat = [n for n in notes if not n["acc"]]
    for j, n in enumerate(nat):
        n["x"] = (j - (len(nat) - 1) / 2) * pn
    for i, n in enumerate(notes):
        if n["acc"]:
            n["x"] = (notes[i - 1]["x"] + notes[i + 1]["x"]) / 2
    Lmax = max(n["L"] for n in notes)
    D = 0.030 * K + 0.022 * K + Lmax + 0.020 * K + 0.022 * K
    Hb = 0.035 * K
    y_tn = -D / 2 + 0.030 * K
    for n in notes:
        tier = 1 if n["acc"] else 0
        dz = 0.010 * K * tier
        y_tip = y_tn + 0.022 * K * tier
        y_b = y_tip + n["L"]
        z0 = Hb + 0.011 * K + h / 2 + dz
        n["y_bridge"] = y_b; n["z0"] = z0
        n["tip"] = Vector((n["x"], y_tip + 0.011 * K, z0 + 0.10 * (y_b - (y_tip + 0.011 * K)) + h / 2))
    _fp_cache[key] = notes
    return notes


def hands_finger_piano(state=None, key="Finger Piano"):
    """state: {"L": [midi index..pinky], "L_thumb": midi, "R": [...], "R_thumb": midi, "press": {midi: depth}}"""
    st = state or {}
    notes = fp_tines(key); by_midi = {n["midi"]: n for n in notes}
    nat = [n for n in notes if not n["acc"]]
    mw = bpy.data.objects[key].matrix_world
    R3 = mw.to_3x3()
    Yk = (R3 @ Vector((0, 1, 0))).normalized(); Zk = (R3 @ Vector((0, 0, 1))).normalized()
    press = st.get("press", {})

    def tip(midi):
        n = by_midi[midi]
        return mw @ n["tip"] + Zk * (0.0085 - press.get(midi, 0.0) * 0.004 + (0.012 if press and midi not in press else 0.0))
    defaults = {"L": [nat[j]["midi"] for j in (10, 9, 8, 7)], "L_thumb": nat[11]["midi"],
                "R": [nat[j]["midi"] for j in (17, 18, 19, 20)], "R_thumb": nat[16]["midi"]}
    hands = {}
    for side in ("L", "R"):
        ms = st.get(side, defaults[side]); th = st.get(side + "_thumb", defaults[side + "_thumb"])
        tips = [tip(m) for m in ms]
        c = sum(tips, Vector()) / 4
        hands[side] = dict(kc=c + Zk * 0.05 - Yk * 0.035, tips=tips, thumb=tip(th))
    return hands, {}


def hands_bass_finger_piano(state=None):
    return hands_finger_piano(state, key="Bass Finger Piano")


# ---- marimba / vibraphone (4 mallets, Stevens grip) ----
MALLET_SETS = {"Marimba": ("Marimba", 0.90, 0.55, 0.18, 0.34, -0.30, 0.075, 0.035),
               "Vibraphone": ("Vibraphone", 0.86, 0.44, 0.19, 0.28, -0.26, 0.070, 0.030)}
# key: (rig, bar top z, hand y offset, head y offset, L hand x, R hand x, mallet spread, head height)


def mallet_heads_rest(key):
    rig, top, hy, heady, xl, xr, spread, hz = MALLET_SETS[key]
    o = bpy.data.objects[rig].matrix_world.translation
    tz = o.z + top
    return {"L": (Vector((xl - spread, o.y + heady, tz + hz)), Vector((xl + spread, o.y + heady, tz + hz))),
            "R": (Vector((xr + spread, o.y + heady, tz + hz)), Vector((xr - spread, o.y + heady, tz + hz)))}   # (inner, outer)


def hands_mallets(state=None, key="Marimba"):
    """state: {"heads": {"L": (inner, outer), "R": (inner, outer)}} world head positions; hands follow their mallets."""
    st = state or {}
    rig, top, hy, heady, xl, xr, spread, hz = MALLET_SETS[key]
    o = bpy.data.objects[rig].matrix_world.translation
    tz = o.z + top
    heads = st.get("heads") or mallet_heads_rest(key)
    p, f, l, up = frame(key)
    hands = {}
    for side in ("L", "R"):
        inner, outer = heads[side]
        inward = Vector((-1 if side == "L" else 1, 0, 0))
        mid = (inner + outer) / 2
        H = Vector((mid.x, o.y + hy, tz + 0.10 + max(0.0, max(inner.z, outer.z) - (tz + hz)) * 0.6))
        gi = H + Vector((0, -0.030, -0.018)) + inward * 0.018
        go = H + Vector((0, -0.020, -0.022)) - inward * 0.040
        for g, h, tag in ((gi, inner, "inner"), (go, outer, "outer")):
            ob = bpy.data.objects.get(f"{key} Mallet {side} {tag}")
            if ob:
                ob.matrix_world = Matrix.Translation(h) @ sk.look_rot(g - h)
        hands[side] = dict(kc=H + Vector((0, -0.055, 0.020)),
                           tips=[gi + Vector((0, -0.012, -0.010)), (gi + go) / 2 + Vector((0, -0.010, -0.018)),
                                 go + Vector((0, -0.006, -0.011)), go + Vector((0, 0.012, -0.012))],
                           thumb=gi + Vector((0, -0.004, 0.011)) + inward * 0.004)
    return hands, {"L": -UP + l * 0.8 - f * 0.3, "R": -UP - l * 0.8 - f * 0.3}


def hands_marimba(state=None):
    return hands_mallets(state, "Marimba")


def hands_vibraphone(state=None):
    return hands_mallets(state, "Vibraphone")


# ---- woodwinds: fingers on the keys; state {"lifts": {"L": [4], "R": [4]}} metres above the key ----
def hands_flute(state=None):
    st = state or {}
    key = "Flute"
    mw, M = _M(key)
    R0 = 0.0095
    kx = lambda n: 0.06 + 0.61 * 2 ** (-n / 12)
    top = lambda x, ang=0.0: (x, math.sin(math.radians(ang)) * (R0 + 0.0050), math.cos(math.radians(ang)) * (R0 + 0.0050))
    R3 = mw.to_3x3(); ax = (R3 @ Vector((1, 0, 0))).normalized(); fr = (R3 @ Vector((0, 0, 1))).normalized()
    lifts = st.get("lifts", {})
    lh = _side_hand(key, "L", _radial(mw, [top(kx(11)), top(kx(9)), top(kx(7)), top(kx(8), 35)], lifts=lifts.get("L")), M((0.385, -0.004, -0.013)), fr, ax)
    rh = _side_hand(key, "R", _radial(mw, [top(kx(5)), top(kx(4)), top(kx(2)), top(kx(3), -25)], lifts=lifts.get("R")), M((0.530, 0.004, -0.013)), fr, ax)
    p, f, l, up = frame(key)
    return {"L": lh, "R": rh}, {"L": -UP + l * 0.6 - f * 0.2, "R": -UP - l * 0.9 - f * 0.4}


def hands_clarinet(state=None):
    st = state or {}
    key = "Clarinet"
    mw, M = _M(key)
    p, f, l, up = frame(key)
    hx = lambda n: 0.584 * 2 ** (-n / 12) + 0.02
    rr = lambda x: 0.0125 if x < 0.39 else 0.0130
    fr_ = lambda x, ang=0.0: (x, math.sin(math.radians(ang)) * (rr(x) + 0.0020), math.cos(math.radians(ang)) * (rr(x) + 0.0020))
    latL = 1 if (mw.to_3x3().inverted() @ l).y > 0 else -1
    R3 = mw.to_3x3(); ax = (R3 @ Vector((1, 0, 0))).normalized(); fr = (R3 @ Vector((0, 0, 1))).normalized()
    lifts = st.get("lifts", {})
    lh = _side_hand(key, "L", _radial(mw, [fr_(hx(12)), fr_(hx(10)), fr_(hx(8)), fr_(0.372, 70 * latL)], lifts=lifts.get("L")), M(fr_(hx(13), 180)), fr, ax)
    rh = _side_hand(key, "R", _radial(mw, [fr_(hx(7)), fr_(hx(5)), fr_(hx(3)), fr_(0.550, -75 * latL)], lifts=lifts.get("R")), M((0.432, 0, -0.024)), fr, ax)
    return {"L": lh, "R": rh}, {"L": -UP + l * 0.7, "R": -UP - l * 0.7}


_OBOE_PROF = [(0.070, 0.0092), (0.075, 0.0118), (0.30, 0.0128), (0.31, 0.0135), (0.54, 0.0148), (0.55, 0.0158),
              (0.585, 0.0180), (0.615, 0.0200), (0.640, 0.0240), (0.655, 0.0305), (0.662, 0.0345)]


def _orad(x):
    for (x0, r0), (x1, r1) in zip(_OBOE_PROF[:-1], _OBOE_PROF[1:]):
        if x0 <= x <= x1:
            return r0 + (r1 - r0) * (x - x0) / (x1 - x0)
    return _OBOE_PROF[-1][1]


def hands_oboe(state=None):
    st = state or {}
    key = "Oboe"
    mw, M = _M(key)
    p, f, l, up = frame(key)
    ox = lambda n: 0.735 * 2 ** (-n / 12) - 0.075
    of = lambda x, ang=0.0, lift=0.0048: (x, math.sin(math.radians(ang)) * (_orad(x) + lift), math.cos(math.radians(ang)) * (_orad(x) + lift))
    latL = 1 if (mw.to_3x3().inverted() @ l).y > 0 else -1
    R3 = mw.to_3x3(); ax = (R3 @ Vector((1, 0, 0))).normalized(); fr = (R3 @ Vector((0, 0, 1))).normalized()
    lifts = st.get("lifts", {})
    lh = _side_hand(key, "L", _radial(mw, [of(ox(13)), of(ox(11)), of(ox(9)), of(0.300, 75 * latL, 0.004)], lifts=lifts.get("L")), M(of(0.205, 180, 0.012)), fr, ax)
    rh = _side_hand(key, "R", _radial(mw, [of(ox(8)), of(ox(6)), of(ox(4)), of(0.49, -90 * latL, 0.005)], lifts=lifts.get("R")), M(of(0.40, 180, 0.020)), fr, ax)
    return {"L": lh, "R": rh}, {"L": -UP + l * 0.7, "R": -UP - l * 0.7}


def hands_bassoon(state=None):
    st = state or {}
    key = "Bassoon"
    mw, M = _M(key)
    R3 = mw.to_3x3()
    Zw = (R3 @ Vector((0, 0, 1))).normalized(); Yw = (R3 @ Vector((0, 1, 0))).normalized()
    p, f, l, up = frame(key)
    XW, XL = 0.0, 0.047
    lifts = st.get("lifts", {})

    def hand(side, tips_local, thumb_local):
        lf = lifts.get(side) or [0.0] * 4
        tips = [mw @ Vector(t) + Yw * (0.0078 + lf[i]) for i, t in enumerate(tips_local)]
        c = sum(tips, Vector()) / 4
        lat = shoulders(key)[side] - c; lat -= lat.dot(Zw) * Zw; lat -= lat.dot(Yw) * Yw; lat.normalize()
        return dict(kc=c + lat * 0.048 - Yw * 0.020, tips=tips, thumb=mw @ Vector(thumb_local))
    lh = hand("L", [(XW, 0.0182, 0.61), (XW, 0.0182, 0.565), (XW, 0.0182, 0.52), (XL + 0.028, 0.004, 0.47)], (XW, -0.030, 0.64))
    rh = hand("R", [(XW, 0.0306, 0.20), (XW, 0.0306, 0.16), (XW, 0.0306, 0.12), (XL + 0.02, 0.025, 0.07)], (0.02, -0.040, 0.17))
    return {"L": lh, "R": rh}, {"L": -UP + l * 0.8, "R": -UP - l * 0.8}


# ---- brass: state {"valves": [0/1 ...]} pressed; trombone {"slide": metres} ----
def hands_trumpet(state=None):
    st = state or {}
    key = "Trumpet"
    mw, T = _M(key)
    p, f, l, up = frame(key)
    v = st.get("valves", [1, 1, 1])
    press = lambda i: 0.0775 + (0.0 if v[i] else 0.010)
    rh = dict(kc=T((0.160, -0.040, 0.050)), tips=[T((0.130, 0.0, press(0))), T((0.155, 0.0, press(1))), T((0.180, 0.0, press(2))), T((0.206, -0.024, 0.018))],
              thumb=T((0.143, -0.018, -0.0148)))
    lh = dict(kc=T((0.190, 0.034, -0.046)), tips=[T((0.2045, -0.014, z)) for z in (-0.012, -0.035, -0.058, -0.080)], thumb=T((0.090, 0.002, -0.041)))
    return {"L": lh, "R": rh}, {"L": -UP + l * 0.8, "R": -UP - l * 0.9 - f * 0.2}


def hands_tuba(state=None):
    st = state or {}
    key = "Tuba"
    mw, M = _M(key)
    p, f, l, up = frame(key)
    BTN = 0.32 + 0.045
    v = st.get("valves", [1, 1, 1, 1])
    rh = dict(kc=M((0.0, -0.165, BTN + 0.075)),
              tips=[M((x, -0.10, BTN + 0.0078 + (0.0 if v[i] else 0.012))) for i, x in enumerate((-0.06, -0.02, 0.02, 0.06))],
              thumb=M((-0.086, -0.118, 0.17 + 0.10)))
    ang = math.radians(55); rb = 0.076 + 0.009
    lh = dict(kc=M((-0.215, -0.025, 0.445)), tips=[M((-0.10 + rb * math.cos(ang), rb * math.sin(ang), z)) for z in (0.49, 0.46, 0.43, 0.40)],
              thumb=M((-0.10 + rb * math.cos(-ang), rb * math.sin(-ang), 0.47)))
    return {"L": lh, "R": rh}, {"L": -UP + l * 0.9, "R": -UP - l * 0.9 - f * 0.2}


_HORN_PADDLES = [Vector((-0.100, -0.050, 0.120)), Vector((-0.076, -0.052, 0.135)), Vector((-0.052, -0.050, 0.145)), Vector((-0.135, -0.040, 0.050))]


def hands_horn(state=None):
    st = state or {}
    key = "French Horn"
    mw, M = _M(key)
    p, f, l, up = frame(key)
    v = st.get("valves", [1, 1, 1, 0])          # 3 finger levers + thumb (Bb side)
    tipsL = [mw @ (_HORN_PADDLES[i] + Vector((0, -0.012 - (0.0 if v[i] else 0.010), 0.004))) for i in (0, 1, 2)] + [M((-0.125, -0.030, 0.155))]
    lh = dict(kc=M((-0.115, -0.105, 0.150)), tips=tipsL, thumb=mw @ (_HORN_PADDLES[3] + Vector((0, -0.012 - (0.0 if v[3] else 0.010), 0))))
    rim = Vector((0.36, 0.024, -0.146)); bx = rim.x
    rh = dict(wrist=M((bx + 0.03, rim.y, rim.z - 0.06)), kc=M((bx - 0.03, rim.y, rim.z - 0.065)),
              tips=[M((bx - 0.10, rim.y + dy, rim.z - 0.055)) for dy in (-0.030, -0.010, 0.010, 0.030)],
              thumb=M((bx - 0.05, rim.y + 0.045, rim.z - 0.03)))
    return {"L": lh, "R": rh}, {"L": -UP + l * 0.9, "R": -UP - l * 0.8 + f * 0.1}


def hands_trombone(state=None):
    st = state or {}
    key = "Trombone"
    mw, M = _M(key)
    p, f, l, up = frame(key)
    ext = st.get("slide", 0.16)
    outer = bpy.data.objects.get("Trombone Outer Slide Tubes")
    if outer:
        outer.location.x = ext
    YB = 0.13
    lh = dict(kc=M((0.195, 0.065, -0.035)), tips=[M((0.135, 0.004, 0.012)), M((0.165, -0.014, -0.030)), M((0.170, -0.014, -0.055)), M((0.175, -0.012, -0.078))],
              thumb=M((0.230, YB - 0.010, 0.016)))
    xb = 0.40 + ext
    rh = dict(kc=M((xb, -0.060, -0.045)), tips=[M((xb + 0.008, -0.009, -0.030)), M((xb + 0.004, -0.009, -0.048)), M((xb - 0.002, -0.011, -0.066)), M((xb - 0.010, -0.018, -0.082))],
              thumb=M((xb + 0.004, -0.004, -0.010)))
    return {"L": lh, "R": rh}, {"L": -UP + l * 0.9 - f * 0.2, "R": -UP - l * 0.9}


HANDS = {
    "Baritone Flying V": hands_guitar, "Violin": hands_violin, "Viola": hands_viola, "Cello": hands_cello,
    "Finger Piano": hands_finger_piano, "Bass Finger Piano": hands_bass_finger_piano,
    "Marimba": hands_marimba, "Vibraphone": hands_vibraphone,
    "Flute": hands_flute, "Clarinet": hands_clarinet, "Oboe": hands_oboe, "Bassoon": hands_bassoon,
    "Trumpet": hands_trumpet, "Tuba": hands_tuba, "French Horn": hands_horn, "Trombone": hands_trombone,
}


def pose(key, state=None, pup=None):
    """Pose one player (and its bow/mallets/slide) for a musical state."""
    hands, pole = HANDS[key](state)
    pup = pup or get_puppet(key)
    shift = Vector((state or {}).get("body_shift", (0.0, 0.0, 0.0)))   # e.g. a mallet player stepping sideways
    body = bpy.data.objects.get(body_name(key))
    if body:
        body.location = shift
    S = {side: s + shift for side, s in shoulders(key).items()}
    p, f, l, up = frame(key)
    default_pole = {"L": -UP + l * 0.8 - f * 0.3, "R": -UP - l * 0.8 - f * 0.3}
    for side in ("L", "R"):
        pose_arm(pup, side, S[side], hands[side], pole.get(side, default_pole[side]))


# ─────────────────────────────── auxiliary movable objects ───────────────────────────────
def build_mallets(key, shaft_mat, head_mats, length=0.40, head_r=0.021, shaft_r=0.0045):
    col = sk.coll(key if key in ("Marimba", "Vibraphone") else "Musicians")
    for side, hm in (("L", head_mats[0]), ("R", head_mats[1])):
        for tag in ("inner", "outer"):
            name = f"{key} Mallet {side} {tag}"
            old = bpy.data.objects.get(name)
            if old:
                bpy.data.objects.remove(old, do_unlink=True)
            B = sk.Builder()
            B.cyl((0, 0, 0), (0, 0, length), shaft_r, mi=0, seg=8)
            B.sphere((0, 0, 0), head_r, mi=1, scale=(1, 1, 0.92), seg=16, rings=10)
            B.build(name, [shaft_mat, hm], collection=col, smooth=True)


def build_bow(name, length, collection):
    """A bow in its own frame: frog at the origin, stick toward -Y (tip at -length), stick side +Z."""
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    stick = bpy.data.materials["Pernambuco Bow Stick"]; hair = bpy.data.materials["Horsehair"]
    ebony = bpy.data.materials["Ebony"]; pearl = bpy.data.materials["Mother of Pearl"]
    frog = Vector((0, 0, 0)); a = Vector((0, 1, 0)); n = Vector((0, 0, 1)); s = Vector((1, 0, 0))
    tip = frog - a * length
    B = sk.Builder()
    B.box((frog + tip) / 2 + n * 0.0005, (0.009 if length < 0.73 else 0.012, length - 0.02, 0.0012), mi=1)
    B.cyl(frog + n * 0.018, tip + n * 0.012, 0.0043, mi=0, seg=10, r2=0.0028)
    B.box(frog + n * 0.010 - a * 0.005, (0.012, 0.045, 0.018), mi=2)
    B.cyl(frog + n * 0.010 - a * 0.005 + s * 0.0062, frog + n * 0.010 - a * 0.005 + s * 0.0066, 0.004, mi=3, seg=12)
    B.cyl(frog + n * 0.018 + a * 0.02, frog + n * 0.018 + a * 0.035, 0.0048, mi=3, seg=10)
    B.box(tip + n * 0.008 + a * 0.004, (0.008, 0.012, 0.018), mi=3)
    return B.build(name, [stick, hair, ebony, pearl], collection=collection, smooth=True)


def build_all(keys=None):
    """Convert players to body + puppet (and movable bows / mallets), posed at rest. Run once, over MCP."""
    load_layout()
    keys = keys or list(PLAYERS)
    for key in keys:
        for ob in [o for o in bpy.data.objects if o.name.startswith(body_name(key))]:
            bpy.data.objects.remove(ob, do_unlink=True)
        build_body(key)
        build_puppet(key)
    for name, key, length in (("Violin Bow", "Violin", 0.745), ("Viola Bow", "Viola", 0.74), ("Cello Bow", "Cello", 0.715)):
        if key in keys:
            build_bow(name, length, sk.coll("Strings (bowed)"))
    if "Marimba" in keys:
        old = bpy.data.objects.get("Marimba Mallets (4)")
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        build_mallets("Marimba", bpy.data.materials["Birch Shaft"], [bpy.data.materials["Mallet Yarn Navy"], bpy.data.materials["Mallet Yarn Rust"]])
    if "Vibraphone" in keys:
        old = bpy.data.objects.get("Vibraphone Mallets (4)")
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        build_mallets("Vibraphone", bpy.data.materials["Rattan Shaft"], [bpy.data.materials["Mallet Cord Blue"], bpy.data.materials["Mallet Cord Purple"]],
                      length=0.38, head_r=0.019, shaft_r=0.004)
    bpy.context.view_layer.update()
    for key in keys:
        pose(key)
