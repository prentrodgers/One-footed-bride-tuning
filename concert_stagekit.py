"""concert_stagekit.py - geometry helpers for Concert_Stage.blend (exported from the
stagekit.py text block inside the .blend; later definitions deliberately override earlier ones).
Used interactively over Blender MCP to build the stage, and by concert_poses.py / concert_stage.py."""

import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler

SCENE_NAME = "Concert Stage"

def scene():
    return bpy.data.scenes[SCENE_NAME]

def coll(name, parent=None):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        (parent or scene().collection).children.link(c)
    return c

# ---------- materials ----------
def mat(name, color, metal=0.0, rough=0.5, emit=None, emit_strength=0.0, alpha=1.0, coat=0.0, spec=0.5):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    col = tuple(color) + (1.0,) if len(color) == 3 else tuple(color)
    b.inputs["Base Color"].default_value = col
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if "Coat Weight" in b.inputs: b.inputs["Coat Weight"].default_value = coat
    if emit is not None:
        b.inputs["Emission Color"].default_value = tuple(emit) + (1.0,)
        b.inputs["Emission Strength"].default_value = emit_strength
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
    m.diffuse_color = col
    m.metallic = metal
    m.roughness = rough
    return m

def wood(name, c1, c2, scale=18.0, rough=0.4, coat=0.3, axis='X'):
    """Procedural wood grain: stretched noise -> wave bands."""
    m = bpy.data.materials.get(name)
    if m: return m
    m = mat(name, c1, rough=rough, coat=coat)
    nt = m.node_tree; N = nt.nodes; L = nt.links
    b = N.get("Principled BSDF")
    tc = N.new("ShaderNodeTexCoord")
    mp = N.new("ShaderNodeMapping")
    s = {'X': (1, scale, scale), 'Y': (scale, 1, scale), 'Z': (scale, scale, 1)}[axis]
    mp.inputs["Scale"].default_value = s
    wv = N.new("ShaderNodeTexWave")
    wv.wave_type = 'BANDS'; wv.bands_direction = 'X'
    wv.inputs["Scale"].default_value = 2.0
    wv.inputs["Distortion"].default_value = 6.0
    wv.inputs["Detail"].default_value = 3.0
    ramp = N.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = tuple(c1) + (1,)
    ramp.color_ramp.elements[1].color = tuple(c2) + (1,)
    L.new(tc.outputs["Object"], mp.inputs["Vector"])
    L.new(mp.outputs["Vector"], wv.inputs["Vector"])
    L.new(wv.outputs["Fac"], ramp.inputs["Fac"])
    L.new(ramp.outputs["Color"], b.inputs["Base Color"])
    return m

# ---------- object helpers ----------
def _link(ob, collection, parent):
    (collection or scene().collection).objects.link(ob)
    if parent is not None:
        ob.parent = parent
        ob.matrix_parent_inverse = Matrix.Identity(4)
    return ob

def mesh_obj(name, bm, loc=(0,0,0), rot=(0,0,0), mats=None, collection=None, parent=None, smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    if smooth:
        for p in me.polygons: p.use_smooth = True
    for m_ in (mats or []):
        me.materials.append(m_)
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    if isinstance(rot, Matrix):
        ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = rot.to_quaternion()
    else:
        ob.rotation_euler = rot
    return _link(ob, collection, parent)

def empty(name, loc=(0,0,0), rot=(0,0,0), collection=None, parent=None, size=0.3, kind='PLAIN_AXES'):
    ob = bpy.data.objects.new(name, None)
    ob.empty_display_type = kind; ob.empty_display_size = size
    ob.location = loc; ob.rotation_euler = rot
    return _link(ob, collection, parent)

def box(name, size, loc=(0,0,0), rot=(0,0,0), mat_=None, **kw):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    return mesh_obj(name, bm, loc, rot, [mat_] if mat_ else None, **kw)

def cyl(name, r, depth, loc=(0,0,0), rot=(0,0,0), mat_=None, seg=24, r2=None, smooth=True, **kw):
    """Cylinder/cone along local Z, centered."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                          radius1=r, radius2=(r if r2 is None else r2), depth=depth)
    return mesh_obj(name, bm, loc, rot, [mat_] if mat_ else None, smooth=smooth, **kw)

def sphere(name, r, loc=(0,0,0), mat_=None, scale=(1,1,1), seg=24, rings=12, rot=(0,0,0), **kw):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    return mesh_obj(name, bm, loc, rot, [mat_] if mat_ else None, smooth=True, **kw)

def look_rot(direction, up=Vector((0,0,1))):
    """Rotation matrix whose local Z points along direction."""
    d = Vector(direction).normalized()
    return d.to_track_quat('Z', 'Y').to_matrix().to_4x4()

def rod(name, p1, p2, r, mat_=None, seg=12, r2=None, **kw):
    """Cylinder from p1 to p2 (coords in parent space)."""
    p1 = Vector(p1); p2 = Vector(p2)
    d = p2 - p1
    ob = cyl(name, r, d.length, (p1 + p2) / 2, look_rot(d), mat_, seg=seg, r2=r2, **kw)
    return ob

def tube_mesh(name, pts, radii, mat_=None, seg=20, cap=True, **kw):
    """Swept tube through points with per-point radius (parallel-transport frames)."""
    pts = [Vector(p) for p in pts]
    bm = bmesh.new()
    rings = []
    n = len(pts)
    tan = []
    for i in range(n):
        a = pts[max(i-1, 0)]; b = pts[min(i+1, n-1)]
        tan.append((b - a).normalized())
    # initial normal
    ref = Vector((0,0,1)) if abs(tan[0].z) < 0.9 else Vector((1,0,0))
    nrm = tan[0].cross(ref).normalized()
    for i in range(n):
        if i > 0:
            axis = tan[i-1].cross(tan[i])
            if axis.length > 1e-8:
                ang = tan[i-1].angle(tan[i])
                nrm = (Matrix.Rotation(ang, 3, axis.normalized()) @ nrm)
        bin_ = tan[i].cross(nrm).normalized()
        ring = []
        for k in range(seg):
            t = 2*math.pi*k/seg
            v = pts[i] + radii[i]*(math.cos(t)*nrm + math.sin(t)*bin_)
            ring.append(bm.verts.new(v))
        rings.append(ring)
    for i in range(n-1):
        for k in range(seg):
            a = rings[i][k]; b = rings[i][(k+1)%seg]; c = rings[i+1][(k+1)%seg]; d = rings[i+1][k]
            bm.faces.new((a, b, c, d))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    return mesh_obj(name, bm, (0,0,0), (0,0,0), [mat_] if mat_ else None, smooth=True, **kw)

def prism(name, outline, z0, z1, mats=None, top_mat_index=0, side_mat_index=0, bottom_mat_index=0, loc=(0,0,0), rot=(0,0,0), **kw):
    """Extrude a 2D outline (list of (x,y)) from z0 to z1."""
    bm = bmesh.new()
    bot = [bm.verts.new((x, y, z0)) for x, y in outline]
    top = [bm.verts.new((x, y, z1)) for x, y in outline]
    fb = bm.faces.new(list(reversed(bot))); fb.material_index = bottom_mat_index
    ft = bm.faces.new(top); ft.material_index = top_mat_index
    n = len(outline)
    for i in range(n):
        f = bm.faces.new((bot[i], bot[(i+1)%n], top[(i+1)%n], top[i]))
        f.material_index = side_mat_index
    bm.normal_update()
    return mesh_obj(name, bm, loc, rot, mats, **kw)

def world_point(ob, local):
    return ob.matrix_world @ Vector(local)


class Builder:
    """Accumulate many primitives into ONE mesh object (keeps object count low)."""
    def __init__(self):
        self.bm = bmesh.new()
    def _tag(self, geom, mi):
        faces = set()
        for v in geom['verts']:
            faces.update(v.link_faces)
        for f in faces:
            f.material_index = mi
    def cyl(self, p1, p2, r, mi=0, seg=12, r2=None):
        p1 = Vector(p1); p2 = Vector(p2); d = p2 - p1
        M = Matrix.Translation((p1 + p2) / 2) @ look_rot(d)
        g = bmesh.ops.create_cone(self.bm, cap_ends=True, segments=seg, radius1=r,
                                  radius2=(r if r2 is None else r2), depth=d.length, matrix=M)
        self._tag(g, mi); return g
    def box(self, center, size, mi=0, rot=None):
        M = Matrix.Translation(center) @ (rot if rot is not None else Matrix.Identity(4)) @ Matrix.Diagonal(Vector(size)).to_4x4()
        g = bmesh.ops.create_cube(self.bm, size=1.0, matrix=M)
        self._tag(g, mi); return g
    def sphere(self, center, r, mi=0, scale=(1,1,1), seg=16, rings=8, rot=None):
        M = Matrix.Translation(center) @ (rot if rot is not None else Matrix.Identity(4)) @ Matrix.Diagonal(Vector(scale)).to_4x4()
        g = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=r, matrix=M)
        self._tag(g, mi); return g
    def disc(self, center, r, normal=(0,0,1), mi=0, seg=24, thick=0.0005):
        n = Vector(normal).normalized()
        return self.cyl(Vector(center) - n*thick/2, Vector(center) + n*thick/2, r, mi, seg)
    def build(self, name, mats, loc=(0,0,0), rot=(0,0,0), collection=None, parent=None, smooth=False):
        return mesh_obj(name, self.bm, loc, rot, mats, collection=collection, parent=parent, smooth=smooth)


def wood(name, c1, c2, scale=18.0, rough=0.4, coat=0.3, axis='X'):
    """Procedural wood grain running along `axis` (object space)."""
    m = bpy.data.materials.get(name)
    if m: return m
    m = mat(name, c1, rough=rough, coat=coat)
    nt = m.node_tree; N = nt.nodes; L = nt.links
    b = N.get("Principled BSDF")
    tc = N.new("ShaderNodeTexCoord")
    mp = N.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = {'X': (0.08, 1, 1), 'Y': (1, 0.08, 1), 'Z': (1, 1, 0.08)}[axis]
    wv = N.new("ShaderNodeTexWave")
    wv.wave_type = 'BANDS'; wv.bands_direction = {'X': 'Y', 'Y': 'X', 'Z': 'X'}[axis]
    wv.inputs["Scale"].default_value = scale
    wv.inputs["Distortion"].default_value = 4.0
    wv.inputs["Detail"].default_value = 3.0
    ramp = N.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = tuple(c1) + (1,)
    ramp.color_ramp.elements[1].color = tuple(c2) + (1,)
    L.new(tc.outputs["Object"], mp.inputs["Vector"])
    L.new(mp.outputs["Vector"], wv.inputs["Vector"])
    L.new(wv.outputs["Fac"], ramp.inputs["Fac"])
    L.new(ramp.outputs["Color"], b.inputs["Base Color"])
    return m


def _hexa(self, v, mi=0):
    vs = [self.bm.verts.new(p) for p in v]
    for f in ((3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        self.bm.faces.new([vs[i] for i in f]).material_index = mi
Builder.hexa = _hexa
_old_build = Builder.build
def _build(self, *a, **k):
    bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
    return _old_build(self, *a, **k)
Builder.build = _build

def smin(a, b, k):
    h = max(k - abs(a - b), 0.0) / k
    return min(a, b) - h * h * k * 0.25

def outline(lo, up, n=96, k=0.06):
    """Two-bout body outline (guitar / violin family) by polar ray-marching a smooth union of two ellipses."""
    def f(x, y):
        e1 = (math.hypot((x - lo[0]) / lo[1], y / lo[2]) - 1) * min(lo[1], lo[2])
        e2 = (math.hypot((x - up[0]) / up[1], y / up[2]) - 1) * min(up[1], up[2])
        return smin(e1, e2, k)
    cx = (lo[0] - lo[1] + up[0] + up[1]) / 2
    pts = []
    for i in range(n):
        th = 2 * math.pi * i / n
        a, b = 0.0, 1.0
        for _ in range(40):
            m = (a + b) / 2
            if f(cx + m * math.cos(th), m * math.sin(th)) < 0: a = m
            else: b = m
        pts.append((cx + a * math.cos(th), a * math.sin(th)))
    return pts, cx

def arch_z(ol, cx, x, y, zt, arch):
    """Height of an arched plate (built by arched_body) above point (x, y)."""
    th = math.atan2(y, x - cx) % (2 * math.pi)
    n = len(ol); i = int(th / (2 * math.pi) * n) % n
    re = math.hypot(ol[i][0] - cx, ol[i][1])
    s = min(math.hypot(x - cx, y) / re, 1.0)
    t = min((1 - s) / 0.97, 1.0)
    return zt + arch * (1 - (1 - t) ** 2)

def arched_body(name, ol, cx, zt, zb, at, ab, mats, rings=8, collection=None, parent=None):
    """Violin-family body: arched top (mat 0), ribs and arched back (mat 1)."""
    bm = bmesh.new(); n = len(ol)
    def ring(t, z0, arch, sgn):
        s = 1 - 0.97 * t; h = arch * (1 - (1 - t) ** 2)
        return [bm.verts.new((cx + s * (x - cx), s * y, z0 + sgn * h)) for x, y in ol]
    top = [ring(j / rings, zt, at, 1) for j in range(rings + 1)]
    bot = [ring(j / rings, zb, ab, -1) for j in range(rings + 1)]
    for R, mi in ((top, 0), (bot, 1)):
        for j in range(rings):
            for i in range(n):
                bm.faces.new((R[j][i], R[j][(i + 1) % n], R[j + 1][(i + 1) % n], R[j + 1][i])).material_index = mi
        c = bm.verts.new((cx, 0, R[-1][0].co.z))
        for i in range(n):
            bm.faces.new((R[-1][i], R[-1][(i + 1) % n], c)).material_index = mi
    for i in range(n):
        bm.faces.new((bot[0][i], bot[0][(i + 1) % n], top[0][(i + 1) % n], top[0][i])).material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, mats=mats, collection=collection, parent=parent, smooth=True)

def basis(X, Zhint):
    X = Vector(X).normalized(); Z = Vector(Zhint); Z = (Z - Z.dot(X) * X).normalized(); Y = Z.cross(X)
    return Matrix((X, Y, Z)).transposed().to_4x4()

def place(rig, R, anchor_world, anchor_local):
    rig.matrix_world = Matrix.Translation(Vector(anchor_world) - R.to_3x3() @ Vector(anchor_local)) @ R


SKINS = [(0.80, 0.60, 0.46), (0.55, 0.36, 0.24), (0.33, 0.20, 0.12), (0.92, 0.74, 0.60), (0.62, 0.43, 0.30), (0.42, 0.26, 0.16),
         (0.86, 0.66, 0.52), (0.25, 0.15, 0.10), (0.70, 0.50, 0.36), (0.95, 0.80, 0.68), (0.48, 0.30, 0.19), (0.76, 0.55, 0.40)]
SHIRTS = [(0.02, 0.35, 0.38), (0.45, 0.04, 0.08), (0.75, 0.55, 0.08), (0.08, 0.15, 0.55), (0.08, 0.30, 0.12), (0.35, 0.10, 0.40),
          (0.85, 0.82, 0.74), (0.60, 0.20, 0.05), (0.55, 0.05, 0.25), (0.10, 0.40, 0.45), (0.50, 0.40, 0.20), (0.20, 0.20, 0.50)]
HAIRS = [(0.02, 0.015, 0.01), (0.25, 0.12, 0.05), (0.01, 0.01, 0.01), (0.55, 0.45, 0.35), (0.03, 0.02, 0.02), (0.12, 0.07, 0.04),
         (0.6, 0.6, 0.6), (0.02, 0.02, 0.02), (0.35, 0.18, 0.08), (0.75, 0.6, 0.35), (0.01, 0.01, 0.01), (0.45, 0.45, 0.45)]
UA, FA = 0.29, 0.27

def frame_for(key):
    p = Vector(LAYOUT[key]["pos"])
    f = (Vector((0, -12, 0)) - p); f.z = 0; f.normalize()
    if key == "Marimba": f = Vector((0, -1, 0))
    up = Vector((0, 0, 1)); l = up.cross(f).normalized()
    return p, f, l, up

def head_mouth(key):
    """Mouth position that musician() will produce for this seat (used to place wind mouthpieces)."""
    p, f, l, up = frame_for(key)
    seated = LAYOUT[key]["seated"]
    pel = p + up * (0.53 if seated else 0.96) + (f * 0.02 if seated else Vector())
    neckb = pel + up * ((0.50 if seated else 0.47) + 0.04)
    head = neckb + up * 0.155 + f * 0.01
    return head - up * 0.055 + f * 0.105

def _elbow(S, H, pole):
    d = (H - S).length
    if d > UA + FA - 0.005:
        H = S + (H - S).normalized() * (UA + FA - 0.005); d = (H - S).length
    dv = (H - S).normalized()
    x = (UA * UA - FA * FA + d * d) / (2 * d); h = math.sqrt(max(UA * UA - x * x, 0.0))
    pp = pole - pole.dot(dv) * dv
    pp = pp.normalized() if pp.length > 1e-6 else Vector((0, 0, -1))
    return S + dv * x + pp * h, H

def musician(i, key, hands, lean=0.0, knee_spread=0.04, leg_style="normal", collection=None):
    p, f, l, up = frame_for(key); right = -l
    seated = LAYOUT[key]["seated"]
    B = Builder()
    Rb = Matrix((right, f, up)).transposed().to_4x4()
    pel = p + up * (0.53 if seated else 0.96) + (f * 0.02 if seated else Vector())
    neckb = pel + up * ((0.50 if seated else 0.47) + 0.04) + f * lean
    axis = (neckb - pel).normalized()
    Rt = Matrix((right, axis.cross(right).normalized(), axis)).transposed().to_4x4()
    B.sphere(pel + up * 0.02, 1.0, mi=2, scale=(0.17, 0.12, 0.12), rot=Rb, seg=20, rings=10)
    B.sphere(pel.lerp(neckb, 0.52), 1.0, mi=1, scale=(0.19, 0.12, 0.27), rot=Rt, seg=24, rings=12)
    head = neckb + up * 0.155 + f * (0.01 + lean * 0.5)
    B.cyl(neckb - up * 0.02, head - up * 0.06, 0.048, mi=0, seg=12)
    B.sphere(head, 0.105, mi=0, scale=(0.9, 1.0, 1.12), rot=Rb, seg=24, rings=14)
    B.sphere(head - f * 0.02 + up * 0.03, 0.104, mi=4, scale=(0.95, 0.98, 1.08), rot=Rb, seg=24, rings=14)
    B.sphere(head + f * 0.1 - up * 0.01, 0.018, mi=0, scale=(0.8, 1.2, 1.3), rot=Rb, seg=10, rings=6)
    for s in (-1, 1):
        B.sphere(head + f * 0.088 + l * s * 0.035 + up * 0.02, 0.011, mi=5, seg=10, rings=6)
    for side, kh in ((1, "L"), (-1, "R")):
        S = neckb - up * 0.05 + l * side * 0.19
        E, H2 = _elbow(S, Vector(hands[kh]), -up + l * side * 0.8 - f * 0.3)
        B.sphere(S, 0.052, mi=1, seg=14, rings=8)
        B.cyl(S, E, 0.047, mi=1, seg=14, r2=0.040); B.sphere(E, 0.040, mi=1, seg=12, rings=8)
        B.cyl(E, H2, 0.038, mi=1, seg=14, r2=0.031)
        fa = (H2 - E).normalized(); Rh = look_rot(fa)
        B.sphere(H2 + fa * 0.045, 1.0, mi=0, scale=(0.045, 0.024, 0.06), rot=Rh, seg=14, rings=8)
        B.sphere(H2 + fa * 0.03 + fa.cross(up).normalized() * 0.03 * side, 0.013, mi=0, scale=(1, 1, 2.2), rot=Rh, seg=10, rings=6)
    for side in (1, -1):
        hip = pel + l * side * 0.095
        if seated:
            knee = hip + f * 0.44 + up * 0.03 + l * side * knee_spread
            lift = 0.15 if (leg_style == "footstool" and side == 1) else 0.0
            if lift: knee = knee + up * 0.12
            ankle = Vector((knee.x, knee.y, p.z + 0.09 + lift)) + f * 0.04
        else:
            knee = hip - up * 0.44 + f * 0.02 + l * side * 0.02
            ankle = Vector((knee.x, knee.y, p.z + 0.09)) + l * side * 0.02
        B.cyl(hip, knee, 0.075, mi=2, seg=14, r2=0.056); B.sphere(knee, 0.056, mi=2, seg=12, rings=8)
        B.cyl(knee, ankle, 0.052, mi=2, seg=14, r2=0.042)
        B.box(ankle + f * 0.06 - up * 0.05, (0.10, 0.27, 0.08), mi=3, rot=Rb)
    mats = [mat(f"Skin {i}", SKINS[i % 12], rough=0.45), mat(f"Shirt {i}", SHIRTS[i % 12], rough=0.75),
            mat("Concert Black Cloth", (0.03, 0.03, 0.035), rough=0.85), mat("Shoe Leather", (0.015, 0.012, 0.01), rough=0.35),
            mat(f"Hair {i}", HAIRS[i % 12], rough=0.55), mat("Eye Dark", (0.01, 0.01, 0.01), rough=0.2)]
    return B.build(f"Musician {i+1} - {key}", mats, collection=collection or coll("Musicians"), smooth=True)

def stool(key, height=0.46):
    p, f, l, up = frame_for(key)
    steel_m = mat("Stand Steel Black", (0.02, 0.02, 0.02), metal=0.8, rough=0.4)
    seat_m = mat("Stool Seat Vinyl", (0.05, 0.03, 0.03), rough=0.5)
    S = Builder()
    S.cyl(p + up * (height - 0.02), p + up * (height + 0.02), 0.19, mi=1, seg=32)
    for a in range(4):
        d = Vector((math.cos(a * math.pi / 2 + 0.785), math.sin(a * math.pi / 2 + 0.785), 0))
        S.cyl(p + d * 0.12 + up * (height - 0.02), p + d * 0.21, 0.013, mi=0, seg=8)
    for k in range(24):
        a0, a1 = 2 * math.pi * k / 24, 2 * math.pi * (k + 1) / 24
        S.cyl(p + Vector((math.cos(a0), math.sin(a0), 0)) * 0.17 + up * 0.18, p + Vector((math.cos(a1), math.sin(a1), 0)) * 0.17 + up * 0.18, 0.008, mi=0, seg=6)
    return S.build(f"Stool - {key}", [steel_m, seat_m], collection=coll("Furniture & Stands"), smooth=True)

def music_stand(key, offset_f, offset_r, height):
    p, f, l, up = frame_for(key); right = -l
    steel_m = mat("Stand Steel Black", (0.02, 0.02, 0.02), metal=0.8, rough=0.4)
    sheet = bpy.data.materials["Sheet Music"]
    base = p + f * offset_f + right * offset_r
    tp = (p - base); tp.z = 0; tp.normalize()
    S = Builder()
    for a in range(3):
        d = Matrix.Rotation(a * 2 * math.pi / 3, 3, 'Z') @ tp
        S.cyl(base + up * 0.25, base + d * 0.28 + up * 0.005, 0.007, mi=0, seg=6)
    S.cyl(base + up * 0.02, base + up * height, 0.011, mi=0, seg=10)
    n = (tp * math.cos(0.35) + up * math.sin(0.35)).normalized(); side = up.cross(tp).normalized(); vup = n.cross(side).normalized()
    Rd = Matrix((side, n, vup)).transposed().to_4x4()
    dc = base + up * (height + 0.16)
    S.box(dc, (0.52, 0.01, 0.34), mi=0, rot=Rd); S.box(dc - vup * 0.17 + n * 0.02, (0.52, 0.04, 0.012), mi=0, rot=Rd)
    for sx in (-0.11, 0.11):
        S.box(dc + side * sx + n * 0.008 + vup * 0.01, (0.215, 0.002, 0.28), mi=1, rot=Rd)
    return S.build(f"Music Stand - {key}", [steel_m, sheet], collection=coll("Furniture & Stands"))

def stage_light(name, kind, loc, target, color, watts, group, spot_deg=30, blend=0.35, size=0.25, fixture=True):
    ctrl = bpy.data.objects["Stage Controls"]; CL = coll("Lights")
    ld = bpy.data.lights.new(name, kind); ld.color = color; ld.energy = watts; ld.use_shadow = True
    if kind == 'SPOT': ld.spot_size = math.radians(spot_deg); ld.spot_blend = blend; ld.shadow_soft_size = size
    ob = bpy.data.objects.new(name, ld); CL.objects.link(ob); ob.location = loc
    tgt = empty(name + " Aim", target, collection=CL, size=0.12, kind='SINGLE_ARROW'); tgt.hide_render = True
    con = ob.constraints.new('TRACK_TO'); con.target = tgt; con.track_axis = 'TRACK_NEGATIVE_Z'; con.up_axis = 'UP_Y'
    ob["level"] = 1.0; ob["base_watts"] = float(watts); ob["group"] = group
    ob.id_properties_ui("level").update(min=0.0, max=3.0, soft_min=0.0, soft_max=3.0, description="This light's own dimmer")
    d = ld.driver_add("energy").driver; d.type = 'SCRIPTED'
    for vn, idob, path in (("base", ob, '["base_watts"]'), ("lvl", ob, '["level"]'), ("grp", ctrl, '["%s"]' % group), ("master", ctrl, '["master"]')):
        v = d.variables.new(); v.name = vn; v.type = 'SINGLE_PROP'
        v.targets[0].id_type = 'OBJECT'; v.targets[0].id = idob; v.targets[0].data_path = path
    d.expression = "base * lvl * grp * master"
    if fixture:
        F = Builder()
        F.cyl((0, 0, 0.02), (0, 0, 0.42), 0.12, mi=0, seg=20, r2=0.10); F.disc((0, 0, 0.012), 0.105, mi=1, seg=20, thick=0.01)
        F.box((0, 0, 0.30), (0.30, 0.03, 0.03), mi=0)
        fx = F.build(name + " Fixture", [bpy.data.materials["Fixture Body"], bpy.data.materials["Fixture Lens"]], collection=CL, parent=ob)
        fx.visible_shadow = False
    return ob

def special_for(idx, key, tint=(1.0, 0.95, 0.88)):
    p = Vector(LAYOUT[key]["pos"])
    y_truss = -2.6 if p.y < 1.0 else 1.6
    return stage_light(f"Special {idx} {key}", 'SPOT', (p.x * 1.05, y_truss - 0.2, 7.3), (p.x, p.y, p.z + 1.0), tint, 2600, "specials", spot_deg=20, blend=0.45, size=0.15)

def bow(name, contact, along, normal, frog_dist, length, collection, stick_m, hair_m, frog_m, tip_m):
    """Bow whose hair touches `contact`; `along` points from contact toward the frog; stick sits on the `normal` side."""
    along = Vector(along).normalized(); normal = Vector(normal); normal = (normal - normal.dot(along) * along).normalized()
    frog = Vector(contact) + along * frog_dist; tip = frog - along * length
    side = along.cross(normal).normalized()
    B = Builder()
    hair_mid = (frog + tip) / 2
    Rb = Matrix((side, along, normal)).transposed().to_4x4()
    B.box(hair_mid + normal * 0.0005, (0.009 if length < 0.73 else 0.012, length - 0.02, 0.0012), mi=1, rot=Rb)      # hair ribbon
    B.cyl(frog + normal * 0.018, tip + normal * 0.012, 0.0043, mi=0, seg=10, r2=0.0028)                          # stick (slight camber)
    B.box(frog + normal * 0.010 - along * 0.005, (0.012, 0.045, 0.018), mi=2, rot=Rb)                              # frog
    B.cyl(frog + normal * 0.010 - along * 0.005 + side * 0.0062, frog + normal * 0.010 - along * 0.005 + side * 0.0066, 0.004, mi=3, seg=12)  # pearl eye
    B.cyl(frog + normal * 0.018 + along * 0.02, frog + normal * 0.018 + along * 0.035, 0.0048, mi=3, seg=10)      # screw button
    B.box(tip + normal * 0.008 + along * 0.004, (0.008, 0.012, 0.018), mi=3, rot=Rb)                               # tip plate
    B.build(name, [stick_m, hair_m, frog_m, tip_m], collection=collection, smooth=True)
    return frog + normal * 0.02


def catmull(points, per=12):
    P = [Vector(p) for p in points]
    P = [P[0] + (P[0] - P[1])] + P + [P[-1] + (P[-1] - P[-2])]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(per):
            t = k / per
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(P[-2])
    return out

def instrument_cable(name, jack, jack_dir, amp_jack, via, collection):
    """1/4-inch cable: straight plug out of the instrument jack, sagging down to the floor, up into the amp's top jack."""
    jd = Vector(jack_dir).normalized()
    blk = mat("Cable Black", (0.012, 0.012, 0.014), rough=0.45)
    chrome = mat("Chrome", (0.9, 0.9, 0.92), metal=1.0, rough=0.08)
    B = Builder()
    p_end = Vector(jack) + jd * 0.055
    B.cyl(Vector(jack) - jd * 0.004, Vector(jack) + jd * 0.022, 0.0048, mi=1, seg=14)       # plug barrel
    B.cyl(Vector(jack) + jd * 0.022, p_end, 0.0060, mi=0, seg=14, r2=0.004)                 # strain relief
    a_top = Vector(amp_jack) + Vector((0, 0, 0.055))
    B.cyl(Vector(amp_jack) - Vector((0, 0, 0.004)), Vector(amp_jack) + Vector((0, 0, 0.022)), 0.0048, mi=1, seg=14)
    B.cyl(Vector(amp_jack) + Vector((0, 0, 0.022)), a_top, 0.0060, mi=0, seg=14, r2=0.004)
    B.build(name + " Plugs", [blk, chrome], collection=collection, smooth=True)
    pts = [p_end, p_end + jd * 0.05] + [Vector(v) for v in via] + [a_top + Vector((0, 0, 0.06)), a_top]
    path = catmull(pts, 10)
    # the spline overshoots between its control points and dipped the cable into the stage floor:
    # keep it resting on top of the floor (the deck under the lowest via point)
    floor_z = min(Vector(v).z for v in via) - 0.004
    for q in path:
        q.z = max(q.z, floor_z + 0.0034)
    return tube_mesh(name, path, [0.0034] * len(path), blk, seg=8, cap=True, collection=collection)

def pignose_amp(name, loc, facing, collection):
    """Small portable 'Pignose'-style practice amp. facing = direction the speaker points."""
    f = Vector(facing); f.z = 0; f.normalize(); up = Vector((0, 0, 1)); side = up.cross(f).normalized()
    R = Matrix((side, -f, up)).transposed().to_4x4()          # local -Y = front
    tolex = mat("Amp Tolex Black", (0.018, 0.018, 0.018), rough=0.85)
    grille = mat("Amp Grille Cloth", (0.05, 0.05, 0.055), rough=0.95)
    pink = mat("Pig Nose Knob Pink", (0.95, 0.45, 0.55), rough=0.35)
    dark = mat("Soundhole Dark", (0.005, 0.004, 0.003), rough=1.0)
    chrome = mat("Chrome", (0.9, 0.9, 0.92), metal=1.0, rough=0.08)
    badge = mat("Amp Badge Cream", (0.92, 0.88, 0.78), rough=0.4)
    W, D, H = 0.235, 0.145, 0.185
    B = Builder()
    B.box((0, 0, H / 2 + 0.008), (W, D, H), mi=0)
    B.box((0, -D / 2 - 0.001, H / 2 + 0.004), (W - 0.03, 0.004, H - 0.04), mi=1)                # grille
    B.box((0.055, -D / 2 - 0.004, H - 0.03), (0.05, 0.003, 0.018), mi=5)                       # badge
    B.box((0, 0, H + 0.0085), (W - 0.004, D - 0.004, 0.002), mi=0)                             # top seam
    nose = Vector((-0.07, -0.02, H + 0.009))
    B.cyl(nose, nose + Vector((0, 0, 0.016)), 0.029, mi=2, seg=32)                             # the pig nose
    for dx in (-0.009, 0.009):
        B.sphere(nose + Vector((dx, 0, 0.0162)), 1.0, mi=3, scale=(0.0045, 0.0075, 0.0015), seg=12, rings=6)   # nostrils
    jack = Vector((0.07, 0.035, H + 0.009))
    B.cyl(jack, jack + Vector((0, 0, 0.004)), 0.009, mi=4, seg=18)
    B.disc(jack + Vector((0, 0, 0.0042)), 0.0048, mi=3, seg=14)
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.cyl((sx * (W / 2 - 0.02), sy * (D / 2 - 0.02), 0.0), (sx * (W / 2 - 0.02), sy * (D / 2 - 0.02), 0.008), 0.011, mi=0, seg=12)  # feet
            B.sphere((sx * W / 2, sy * D / 2, H + 0.008), 0.009, mi=4, seg=10, rings=6)       # corner caps
    for sx in (-1, 1):
        B.cyl((sx * 0.07, 0, H + 0.008), (sx * 0.07, 0, H + 0.020), 0.006, mi=4, seg=10)       # handle anchors
    ob = B.build(name, [tolex, grille, pink, dark, chrome, badge], loc=loc, collection=collection, smooth=True)
    ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = R.to_quaternion()
    hp = [Vector((sx * 0.07, 0, H + 0.02 + 0.03 * math.sin(math.pi * (sx + 1) / 2))) for sx in (-1, -0.5, 0, 0.5, 1)]
    hp = [Vector((0.07 * t, 0, H + 0.02 + 0.028 * (1 - t * t))) for t in (-1, -0.6, -0.2, 0.2, 0.6, 1)]
    h = tube_mesh(name + " Handle", hp, [0.006] * len(hp), tolex, seg=8, collection=collection, parent=ob)
    h.scale = (1, 1.9, 0.55); h.location = (0, 0, H * 0.45)
    bpy.context.view_layer.update()
    return ob, ob.matrix_world @ jack


def _bez(p0, c, p1, t):
    return (1 - t) ** 2 * p0 + 2 * (1 - t) * t * c + t * t * p1

def build_hand(B, W, spec, mi_skin=0):
    """Articulated hand: palm from wrist W to knuckle centre, 4 two-joint fingers to spec['tips'], thumb to spec['thumb']."""
    kc = Vector(spec["kc"]); tips = [Vector(t) for t in spec["tips"]]; th = Vector(spec["thumb"])
    pd = (kc - W); plen = pd.length; pd.normalize()
    ac = tips[3] - tips[0]; ac = ac - ac.dot(pd) * pd
    if ac.length < 1e-5: ac = pd.orthogonal()
    ac.normalize()
    ny = pd.cross(ac).normalized()
    Rp = Matrix((ac, ny, pd)).transposed().to_4x4()
    B.sphere((W + kc) / 2, 1.0, mi=mi_skin, scale=(0.041, 0.016, plen / 2 + 0.010), rot=Rp, seg=16, rings=10)
    for i in range(4):
        k = kc + ac * (-0.027 + 0.018 * i)
        t = tips[i]
        L = (0.080, 0.088, 0.083, 0.066)[i]
        if (t - k).length > L: t = k + (t - k).normalized() * L
        c = k + pd * min(0.045, (t - k).length * 0.65)
        pts = [_bez(k, c, t, s) for s in (0.0, 0.42, 0.78, 1.0)]
        rr = (0.0092, 0.0086, 0.0080, 0.0074) if i < 3 else (0.0080, 0.0075, 0.0070, 0.0066)
        for j in range(3):
            B.cyl(pts[j], pts[j + 1], rr[j], mi=mi_skin, seg=10, r2=rr[j + 1])
            B.sphere(pts[j + 1], rr[j + 1], mi=mi_skin, seg=10, rings=6)
        B.sphere(k, 0.0095, mi=mi_skin, seg=10, rings=6)
    base = W + pd * 0.028 - ac * 0.030
    if (th - base).length > 0.075: th = base + (th - base).normalized() * 0.075
    c = base + pd * 0.022 - ac * 0.012
    pts = [_bez(base, c, th, s) for s in (0.0, 0.5, 1.0)]
    B.cyl(pts[0], pts[1], 0.0115, mi=mi_skin, seg=10, r2=0.0098); B.sphere(pts[1], 0.0098, mi=mi_skin, seg=10, rings=6)
    B.cyl(pts[1], pts[2], 0.0098, mi=mi_skin, seg=10, r2=0.0085); B.sphere(pts[2], 0.0085, mi=mi_skin, seg=10, rings=6)

def wrist_for(S, spec, up=Vector((0, 0, 1))):
    if "wrist" in spec: return Vector(spec["wrist"])
    kc = Vector(spec["kc"])
    d = (S - kc).normalized() - up * 0.45
    return kc + d.normalized() * 0.085

def musician2(i, key, hands, lean=0.0, knee_spread=0.04, leg_style="normal", pole=None):
    """Like musician(), but hands are specs {kc, tips[4], thumb, (wrist)} and get articulated fingers."""
    p, f, l, up = frame_for(key); right = -l
    seated = LAYOUT[key]["seated"]
    B = Builder()
    Rb = Matrix((right, f, up)).transposed().to_4x4()
    pel = p + up * (0.53 if seated else 0.96) + (f * 0.02 if seated else Vector())
    neckb = pel + up * ((0.50 if seated else 0.47) + 0.04) + f * lean
    axis = (neckb - pel).normalized()
    Rt = Matrix((right, axis.cross(right).normalized(), axis)).transposed().to_4x4()
    B.sphere(pel + up * 0.02, 1.0, mi=2, scale=(0.17, 0.12, 0.12), rot=Rb, seg=20, rings=10)
    B.sphere(pel.lerp(neckb, 0.52), 1.0, mi=1, scale=(0.19, 0.12, 0.27), rot=Rt, seg=24, rings=12)
    head = neckb + up * 0.155 + f * (0.01 + lean * 0.5)
    B.cyl(neckb - up * 0.02, head - up * 0.06, 0.048, mi=0, seg=12)
    B.sphere(head, 0.105, mi=0, scale=(0.9, 1.0, 1.12), rot=Rb, seg=24, rings=14)
    B.sphere(head - f * 0.02 + up * 0.03, 0.104, mi=4, scale=(0.95, 0.98, 1.08), rot=Rb, seg=24, rings=14)
    B.sphere(head + f * 0.1 - up * 0.01, 0.018, mi=0, scale=(0.8, 1.2, 1.3), rot=Rb, seg=10, rings=6)
    for s in (-1, 1):
        B.sphere(head + f * 0.088 + l * s * 0.035 + up * 0.02, 0.011, mi=5, seg=10, rings=6)
    for side, kh in ((1, "L"), (-1, "R")):
        S = neckb - up * 0.05 + l * side * 0.19
        spec = hands[kh]
        W = wrist_for(S, spec)
        pl = (pole[kh] if pole and kh in pole else (-up + l * side * 0.8 - f * 0.3))
        E, W2 = _elbow(S, W, pl)
        if (W2 - W).length > 1e-4:           # out of reach: slide the whole hand toward the shoulder
            dlt = W2 - W
            spec = dict(kc=Vector(spec["kc"]) + dlt, tips=[Vector(t) + dlt for t in spec["tips"]], thumb=Vector(spec["thumb"]) + dlt)
            W = W2
        B.sphere(S, 0.052, mi=1, seg=14, rings=8)
        B.cyl(S, E, 0.047, mi=1, seg=14, r2=0.040); B.sphere(E, 0.040, mi=1, seg=12, rings=8)
        B.cyl(E, W, 0.038, mi=1, seg=14, r2=0.029)
        B.sphere(W, 0.024, mi=0, scale=(1.3, 1.0, 1.0), rot=look_rot(W - E), seg=12, rings=8)
        build_hand(B, W, spec, mi_skin=0)
    for side in (1, -1):
        hip = pel + l * side * 0.095
        if seated:
            knee = hip + f * 0.44 + up * 0.03 + l * side * knee_spread
            lift = 0.15 if (leg_style == "footstool" and side == 1) else 0.0
            if lift: knee = knee + up * 0.12
            ankle = Vector((knee.x, knee.y, p.z + 0.09 + lift)) + f * 0.04
        else:
            knee = hip - up * 0.44 + f * 0.02 + l * side * 0.02
            ankle = Vector((knee.x, knee.y, p.z + 0.09)) + l * side * 0.02
        B.cyl(hip, knee, 0.075, mi=2, seg=14, r2=0.056); B.sphere(knee, 0.056, mi=2, seg=12, rings=8)
        B.cyl(knee, ankle, 0.052, mi=2, seg=14, r2=0.042)
        B.box(ankle + f * 0.06 - up * 0.05, (0.10, 0.27, 0.08), mi=3, rot=Rb)
    mats = [mat(f"Skin {i}", SKINS[i % 12], rough=0.45), mat(f"Shirt {i}", SHIRTS[i % 12], rough=0.75),
            mat("Concert Black Cloth", (0.03, 0.03, 0.035), rough=0.85), mat("Shoe Leather", (0.015, 0.012, 0.01), rough=0.35),
            mat(f"Hair {i}", HAIRS[i % 12], rough=0.55), mat("Eye Dark", (0.01, 0.01, 0.01), rough=0.2)]
    return B.build(f"Musician {i+1} - {key}", mats, collection=coll("Musicians"), smooth=True)

def bow_grip(frog, along, normal, player_fwd):
    """Hand spec for a bow hold at the frog: fingers draped over the stick, thumb under it."""
    a = Vector(along).normalized(); n = Vector(normal); n = (n - n.dot(a) * a).normalized()
    s = a.cross(n).normalized()
    if s.dot(player_fwd) < 0: s = -s                      # fingers wrap to the far side
    G = Vector(frog) + n * 0.017 - a * 0.030
    tips = [G - a * 0.040 + s * 0.010 - n * 0.004, G - a * 0.020 + s * 0.012 - n * 0.006,
            G - a * 0.002 + s * 0.010 - n * 0.005, G + a * 0.016 + n * 0.008]
    return dict(kc=G + n * 0.040 - s * 0.030 - a * 0.012, tips=tips, thumb=G - n * 0.010 + a * 0.004 - s * 0.004)


_musician2_orig = musician2
def musician2(i, key, hands, lean=0.0, knee_spread=0.04, leg_style="normal", pole=None):
    """Same as before, but a hand spec may pin the elbow ('elbow') and wrist ('wrist') exactly."""
    global _elbow
    base_elbow = _elbow
    pinned = {kh: Vector(s["elbow"]) for kh, s in hands.items() if "elbow" in s}
    if not pinned:
        return _musician2_orig(i, key, hands, lean, knee_spread, leg_style, pole)
    def pinned_elbow(S, H, pl):
        for kh, E in pinned.items():
            if (Vector(hands[kh].get("wrist", H)) - H).length < 1e-6 and "wrist" in hands[kh]:
                return E, H
        return base_elbow(S, H, pl)
    _elbow = pinned_elbow
    try:
        return _musician2_orig(i, key, hands, lean, knee_spread, leg_style, pole)
    finally:
        _elbow = base_elbow


FACE_FORWARD = {"Marimba", "Vibraphone"}          # players who face straight down-stage (behind a mallet instrument)
def frame_for(key):
    p = Vector(LAYOUT[key]["pos"])
    f = (Vector((0, -12, 0)) - p); f.z = 0; f.normalize()
    if key in FACE_FORWARD: f = Vector((0, -1, 0))
    up = Vector((0, 0, 1)); l = up.cross(f).normalized()
    return p, f, l, up
