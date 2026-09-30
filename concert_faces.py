"""
concert_faces.py - heads, faces and hair for the Concert Stage musicians.

A head is lofted from a profile (chin to crown) rather than a scaled sphere: a jaw and chin narrower
than the cranium, cheekbones, a brow ridge, the eyes set slightly under it. On that: eyeballs with iris
and pupil, upper and lower lids, eyebrows, a nose (bridge, tip, nostril wings), lips, ears. Hair is a
shell following the skull out to a hairline that differs per style; long styles hang from the head.

The mouth sits where concert_stagekit.head_mouth() says (0.055 m below and 0.105 m in front of the head
centre) so every wind mouthpiece still meets the lips.

build_head(B, hc, right, f, key, i) adds everything to a Builder; face_materials(i) gives the extra
materials in the order the MI indices below expect.
"""
import math

import bpy
from mathutils import Matrix, Vector

import concert_stagekit as sk

UP = Vector((0, 0, 1))
# material indices in the body mesh: see concert_poses.build_body
MI = dict(skin=0, hair=4, pupil=5, sclera=7, iris=8, lips=9, lens=10, frame=11)
GLASSES = {"Baritone Flying V"}      # dark glasses

# head profile: (z above the head centre, half-width, front depth, back depth, forward offset of the ring)
PROFILE = [(-0.120, 0.012, 0.008, 0.008, 0.070), (-0.110, 0.034, 0.018, 0.030, 0.062), (-0.095, 0.052, 0.028, 0.058, 0.048),
           (-0.075, 0.062, 0.042, 0.076, 0.040), (-0.055, 0.067, 0.050, 0.086, 0.036), (-0.030, 0.071, 0.056, 0.090, 0.032),
           (-0.005, 0.075, 0.058, 0.094, 0.028), (0.022, 0.077, 0.052, 0.097, 0.024), (0.045, 0.078, 0.060, 0.099, 0.020),
           (0.075, 0.074, 0.064, 0.098, 0.014), (0.100, 0.063, 0.058, 0.088, 0.008), (0.118, 0.041, 0.040, 0.062, 0.004),
           (0.128, 0.010, 0.010, 0.016, 0.002)]
Z_TOP = PROFILE[-1][0]

# player -> (hair style, beard)
STYLES = {
    "Baritone Flying V": ("long", None), "Violin": ("short", None), "Finger Piano": ("bun", None),
    "Bass Finger Piano": ("short", "full"), "Flute": ("short", None), "Clarinet": ("bob", None),
    "Oboe": ("bald", None), "Marimba": ("ponytail", None), "Cello": ("long", None), "Trumpet": ("short", None),
    "Tuba": ("bun", None), "Bassoon": ("bob", None), "Viola": ("ponytail", None), "French Horn": ("short", "full"),
    "Trombone": ("short", None), "Vibraphone": ("long", None),
}
IRIS = [(0.16, 0.08, 0.03), (0.10, 0.22, 0.42), (0.12, 0.24, 0.10), (0.22, 0.14, 0.05), (0.06, 0.035, 0.02),
        (0.18, 0.20, 0.24)]


def _prof(z):
    z = max(PROFILE[0][0], min(Z_TOP, z))
    for p0, p1 in zip(PROFILE[:-1], PROFILE[1:]):
        if p0[0] <= z <= p1[0]:
            u = (z - p0[0]) / (p1[0] - p0[0])
            return [a + (b - a) * u for a, b in zip(p0[1:], p1[1:])]
    return list(PROFILE[-1][1:])


def head_point(hc, right, f, th, z, off=0.0):
    a, bf, bb, yc = _prof(z)
    s = math.sin(th)
    b = bf if s > 0 else bb
    lift = off * max(0.0, z / Z_TOP) ** 3                    # hair stands up off the crown a little
    return hc + right * ((a + off) * math.cos(th)) + f * (yc + (b + off) * s) + UP * (z + lift)


def front_y(x, z):
    a, bf, bb, yc = _prof(z)
    return yc + bf * math.sqrt(max(0.0, 1 - (x / a) ** 2))


def _interp(table, s):
    for (s0, h0), (s1, h1) in zip(table[:-1], table[1:]):
        if s0 <= s <= s1:
            return h0 + (h1 - h0) * (s - s0) / (s1 - s0)
    return table[0][1] if s < table[0][0] else table[-1][1]


# ─────────────────────────────── materials ───────────────────────────────
def skin_upgrade(m):
    """Subsurface scattering, so light glows through the skin instead of bouncing off plastic."""
    b = m.node_tree.nodes.get("Principled BSDF")
    if b is None or m.get("skin_v2"):
        return
    b.inputs["Subsurface Weight"].default_value = 0.25
    b.inputs["Subsurface Radius"].default_value = (1.0, 0.35, 0.20)
    b.inputs["Subsurface Scale"].default_value = 0.006
    b.inputs["Roughness"].default_value = 0.52
    b.inputs["Specular IOR Level"].default_value = 0.35
    m["skin_v2"] = 1


def hair_upgrade(m):
    """Strand streaks: a noise stretched along the hair's fall, darkening and lightening the colour."""
    nt = m.node_tree
    if m.get("hair_v2"):
        return
    N, L = nt.nodes, nt.links
    b = N["Principled BSDF"]
    base = tuple(b.inputs["Base Color"].default_value)
    tc = N.new("ShaderNodeTexCoord"); mp = N.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (90.0, 90.0, 4.0)
    nz = N.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 1.0; nz.inputs["Detail"].default_value = 4.0
    rp = N.new("ShaderNodeValToRGB")
    rp.color_ramp.elements[0].position = 0.3; rp.color_ramp.elements[0].color = tuple(c * 0.55 for c in base[:3]) + (1,)
    rp.color_ramp.elements[1].position = 0.75; rp.color_ramp.elements[1].color = tuple(min(1, c * 1.35 + 0.02) for c in base[:3]) + (1,)
    L.new(tc.outputs["Object"], mp.inputs["Vector"]); L.new(mp.outputs["Vector"], nz.inputs["Vector"])
    L.new(nz.outputs["Fac"], rp.inputs["Fac"]); L.new(rp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.58
    b.inputs["Coat Weight"].default_value = 0.0
    b.inputs["Specular IOR Level"].default_value = 0.3
    m["hair_v2"] = 1


def hair_texture(m):
    """Stronger strands: highlights that show even on near-black hair, and a bump from the same streaks
    so the surface catches light like hair rather than a painted shell."""
    if m.get("hair_v3"):
        return
    hair_upgrade(m)
    nt = m.node_tree; N, L = nt.nodes, nt.links
    b = N["Principled BSDF"]
    rp = next(n for n in N if n.type == 'VALTORGB')
    nz = next(n for n in N if n.type == 'TEX_NOISE')
    mp = next(n for n in N if n.type == 'MAPPING')
    mp.inputs["Scale"].default_value = (160.0, 160.0, 6.0)
    base = m.get("hair_base") or tuple(rp.color_ramp.elements[1].color)[:3]
    base = tuple(base)
    m["hair_base"] = base
    rp.color_ramp.elements[0].position = 0.25
    rp.color_ramp.elements[0].color = tuple(c * 0.35 for c in base) + (1,)
    rp.color_ramp.elements[1].position = 0.80
    rp.color_ramp.elements[1].color = tuple(min(1.0, c * 1.7 + 0.03) for c in base) + (1,)
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.6
    bump.inputs["Distance"].default_value = 0.002
    L.new(nz.outputs["Fac"], bump.inputs["Height"])
    L.new(bump.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.50
    b.inputs["Specular IOR Level"].default_value = 0.45
    m["hair_v3"] = 1


def face_materials(i, skin_color):
    sclera = sk.mat("Eye Sclera", (0.82, 0.80, 0.76), rough=0.12)
    iris = sk.mat(f"Iris {i}", IRIS[i % len(IRIS)], rough=0.10, coat=1.0)
    lips = sk.mat(f"Lips {i}", tuple(c * k for c, k in zip(skin_color, (0.80, 0.52, 0.52))), rough=0.35)
    lens = sk.mat("Sunglass Lens", (0.012, 0.012, 0.016), metal=0.3, rough=0.04, coat=1.0)
    frame = sk.mat("Sunglass Frame", (0.01, 0.01, 0.01), rough=0.25)
    return [sclera, iris, lips, lens, frame]


# ─────────────────────────────── the head ───────────────────────────────
def build_head(B, hc, right, f, key, i, seg=32):
    style, beard = STYLES.get(key, ("short", None))
    Rb = Matrix((right, f, UP)).transposed().to_4x4()
    P = lambda x, y, z: hc + right * x + f * y + UP * z
    # skull and face
    bm = B.bm
    rings = []
    for z, *_ in PROFILE:
        rings.append([bm.verts.new(head_point(hc, right, f, 2 * math.pi * k / seg, z)) for k in range(seg)])
    for r0, r1 in zip(rings[:-1], rings[1:]):
        for k in range(seg):
            bm.faces.new((r0[k], r0[(k + 1) % seg], r1[(k + 1) % seg], r1[k])).material_index = MI["skin"]
    for ring, up_ in ((rings[0], False), (rings[-1], True)):
        c = bm.verts.new(sum((v.co for v in ring), Vector()) / seg)
        for k in range(seg):
            vs = (ring[k], ring[(k + 1) % seg], c) if up_ else (ring[(k + 1) % seg], ring[k], c)
            bm.faces.new(vs).material_index = MI["skin"]
    # eyes: eyeball, iris, pupil, lids
    for s in (-1, 1):
        ex = s * 0.032
        ec = P(ex, front_y(ex, 0.022) - 0.0065, 0.022)
        B.sphere(ec, 0.0125, mi=MI["sclera"], seg=16, rings=10)
        B.disc(ec + f * 0.0121, 0.0058, normal=f, mi=MI["iris"], seg=18, thick=0.0010)
        B.disc(ec + f * 0.0127, 0.0026, normal=f, mi=MI["pupil"], seg=12, thick=0.0006)
        B.sphere(ec + UP * 0.0070 + f * 0.0010, 1.0, mi=MI["skin"], scale=(0.0140, 0.0131, 0.0066), rot=Rb, seg=18, rings=8)
        B.sphere(ec - UP * 0.0092 + f * 0.0004, 1.0, mi=MI["skin"], scale=(0.0134, 0.0124, 0.0036), rot=Rb, seg=18, rings=8)
        # eyebrow: one smooth arc, thicker toward the nose, flattened against the brow
        xs = [0.013 + 0.0055 * j for j in range(8)]
        pts = [P(s * x, front_y(s * x, 0.043) + 0.0018, 0.041 + 0.0055 * math.sin(math.pi * (x - 0.013) / 0.045)) for x in xs]
        _tube(B, pts, [0.0030 - 0.0014 * j / 7 for j in range(8)], MI["hair"], seg=8, flat=0.45, flat_axis=f)
        # ear
        B.sphere(P(s * 0.078, -0.006, 0.008), 1.0, mi=MI["skin"], scale=(0.009, 0.021, 0.030),
                 rot=Rb @ Matrix.Rotation(math.radians(-12 * s), 4, 'Z'), seg=14, rings=10)
        # nostril wing, tucked against the tip
        B.sphere(P(s * 0.0092, 0.0905, -0.0195), 1.0, mi=MI["skin"], scale=(0.0062, 0.0078, 0.0056), rot=Rb, seg=14, rings=8)
    # nose: a narrow bridge flattened side to side, widening into the tip
    root, tip = P(0, front_y(0, 0.030) - 0.001, 0.030), P(0, 0.097, -0.012)
    _tube(B, [root.lerp(tip, u) for u in (0.0, 0.3, 0.6, 0.85, 1.0)], [0.0060, 0.0068, 0.0082, 0.0098, 0.0090],
          MI["skin"], seg=12, flat=0.75, flat_axis=right)
    B.sphere(P(0, 0.0975, -0.0165), 1.0, mi=MI["skin"], scale=(0.0110, 0.0100, 0.0090), rot=Rb, seg=16, rings=10)
    # lips: tapered - full at the centre, thin at the corners; upper lip with a slight cupid's bow
    yl = front_y(0.0, -0.052)
    xs = [-0.024 + 0.006 * j for j in range(9)]
    up_pts = [P(x, yl + 0.0038 - 45 * x * x, -0.0478 - 1.6 * x * x + 0.0009 * math.cos(math.pi * x / 0.008) * (abs(x) < 0.008)) for x in xs]
    lo_pts = [P(x, yl + 0.0042 - 45 * x * x, -0.0582 + 4.0 * x * x) for x in xs]
    taper = lambda r: [r * (0.35 + 0.65 * math.cos(math.pi * x / 0.052)) for x in xs]
    _tube(B, up_pts, taper(0.0040), MI["lips"], seg=10, flat=0.8, flat_axis=f)
    _tube(B, lo_pts, taper(0.0052), MI["lips"], seg=10, flat=0.8, flat_axis=f)
    mouth = [P(x, yl + 0.0005 - 45 * x * x, -0.0530 + 1.0 * x * x) for x in xs[1:-1]]
    _tube(B, mouth, [0.0009] * len(mouth), MI["pupil"], seg=6)
    if key in GLASSES:                  # 60s wayfarer-ish shades: dark lenses, black frame, temples to the ears
        for s in (-1, 1):
            lc = P(s * 0.032, front_y(s * 0.032, 0.022) + 0.011, 0.021)
            B.sphere(lc, 1.0, mi=MI["lens"], scale=(0.022, 0.004, 0.017), rot=Rb, seg=20, rings=8)
            ring = [lc + right * (0.023 * math.cos(2 * math.pi * k / 20)) + UP * (0.018 * math.sin(2 * math.pi * k / 20)) for k in range(21)]
            _tube(B, ring, [0.0022] * len(ring), MI["frame"], seg=6)
            hinge = lc + right * (s * 0.024) + UP * 0.006
            ear = P(s * 0.080, -0.012, 0.018)
            _tube(B, [hinge, hinge.lerp(ear, 0.5) + right * (s * 0.004), ear], [0.0020] * 3, MI["frame"], seg=6)
        _tube(B, [P(-0.010, front_y(0, 0.030) + 0.010, 0.028), P(0, front_y(0, 0.030) + 0.012, 0.030),
                  P(0.010, front_y(0, 0.030) + 0.010, 0.028)], [0.0022] * 3, MI["frame"], seg=6)
    # hair and beard
    _hair(B, hc, right, f, style)
    if style == "bun":
        B.sphere(P(0, -0.095, 0.080), 0.036, mi=MI["hair"], scale=(1.0, 0.85, 0.9), seg=18, rings=12)
    if style == "ponytail":
        tie = P(0, -0.094, 0.055)
        tail = [tie + f * 0.004, tie - f * 0.006, P(0, -0.108, 0.020), P(0, -0.110, -0.030), P(0, -0.102, -0.085), P(0, -0.094, -0.125)]
        _tube(B, tail, [0.016, 0.017, 0.016, 0.014, 0.011, 0.004], MI["hair"], seg=12, flat=0.7, flat_axis=f)
        B.cyl(tie - f * 0.006, tie + f * 0.006, 0.019, mi=MI["pupil"], seg=14)
    if beard:
        _beard(B, hc, right, f)


def _tube(B, pts, radii, mi, seg=10, flat=1.0, flat_axis=None):
    """A smooth tapered tube through pts (closed ends). flat < 1 squashes it along flat_axis."""
    bm = B.bm
    pts = [Vector(p) for p in pts]
    rings = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a = flat_axis if flat_axis is not None else t.orthogonal()
        a = (a - a.dot(t) * t).normalized()
        b = t.cross(a).normalized()
        rings.append([bm.verts.new(p + radii[i] * (math.cos(2 * math.pi * k / seg) * a * flat + math.sin(2 * math.pi * k / seg) * b))
                      for k in range(seg)])
    for r0, r1 in zip(rings[:-1], rings[1:]):
        for k in range(seg):
            bm.faces.new((r0[k], r0[(k + 1) % seg], r1[(k + 1) % seg], r1[k])).material_index = mi
    for ring, rev in ((rings[0], True), (rings[-1], False)):
        c = bm.verts.new(sum((v.co for v in ring), Vector()) / seg)
        for k in range(seg):
            vs = (ring[(k + 1) % seg], ring[k], c) if rev else (ring[k], ring[(k + 1) % seg], c)
            bm.faces.new(vs).material_index = mi


def _grid(B, cols, rows, point, closed, mi):
    bm = B.bm
    grid = [[bm.verts.new(point(c, r)) for r in range(rows)] for c in range(cols)]
    n = cols if closed else cols - 1
    for c in range(n):
        c1 = (c + 1) % cols
        for r in range(rows - 1):
            bm.faces.new((grid[c][r], grid[c1][r], grid[c1][r + 1], grid[c][r + 1])).material_index = mi
    return grid


def _hair(B, hc, right, f, style):
    """A shell over the skull from the hairline up. Long styles continue below the head as a curtain
    that falls behind the ears and onto the shoulders."""
    hang_end = {"long": -0.235, "bob": -0.095}.get(style)
    if style == "bald":                                # a fringe round the back and sides
        th0, th1, cols = math.radians(188), math.radians(352), 40          # round the back, ear to ear
        H = lambda s: -0.032
        top = lambda s: 0.030 + 0.010 * max(0.0, -s)
        thick = lambda s, z: 0.0055
    else:
        th0, th1, cols = 0.0, 2 * math.pi, 64
        if hang_end is None:                           # short / bun / ponytail: ears showing, nape at the neck
            table = [(-1.0, -0.040), (-0.30, -0.034), (-0.10, 0.036), (0.25, 0.042), (0.55, 0.064), (1.0, 0.070)]
        else:                                          # long / bob: frames the face, covers the ears
            table = [(-1.0, hang_end), (-0.02, hang_end), (0.22, 0.030), (0.50, 0.062), (1.0, 0.068)]
        H = lambda s: _interp(table, s)
        top = lambda s: Z_TOP
        thick = lambda s, z: (0.009 if hang_end else 0.0065) + 0.008 * max(0.0, z) / Z_TOP
    rows = 26

    def point(c, r):
        th = th0 + (th1 - th0) * c / (cols if th1 - th0 >= 2 * math.pi - 1e-6 else cols - 1)
        s = math.sin(th)
        z0, z1 = H(s), top(s)
        v = r / (rows - 1)
        z = z0 + (z1 - z0) * v ** 0.8
        t = thick(s, z)
        if z > -0.005 or not hang_end:     # thin to nothing at the hairline, so hair grows out of the scalp
            t *= min(1.0, 0.15 + v * 5.0)
        if style == "bald":                # a fringe thins out at its top edge and at both ends too
            t *= min(1.0, 0.15 + (1 - v) * 4.0) * min(1.0, 0.2 + 5.0 * min(c, cols - 1 - c) / cols)
        if z >= -0.005:
            return head_point(hc, right, f, th, z, t)
        # below the head's widest ring the hair hangs, flaring slightly and falling back from the neck
        base = head_point(hc, right, f, th, -0.005, t)
        drop = -0.005 - z
        out = (right * math.cos(th) + f * (0.6 * s)).normalized() if abs(s) < 0.99 else f * s
        return base + out * (0.12 * drop) - f * (0.25 * drop) + UP * (z + 0.005)
    closed = th1 - th0 >= 2 * math.pi - 1e-6
    grid = _grid(B, cols, rows, point, closed, MI["hair"])
    if closed:                                         # close the crown (it was a ring - a hole in the top)
        top_ring = [grid[c][rows - 1] for c in range(cols)]
        cen = B.bm.verts.new(sum((v.co for v in top_ring), Vector()) / cols + UP * 0.004)
        for c in range(cols):
            B.bm.faces.new((top_ring[c], top_ring[(c + 1) % cols], cen)).material_index = MI["hair"]


def _beard(B, hc, right, f):
    """Jaw, chin and sideburns, stopping below the lower lip; a moustache over the upper lip."""
    th0, th1, cols, rows = math.radians(-12), math.radians(192), 40, 12
    table = [(-0.25, 0.022), (0.30, 0.000), (0.62, -0.046), (0.86, -0.066), (1.0, -0.066)]

    def point(c, r):
        th = th0 + (th1 - th0) * c / (cols - 1)
        s = math.sin(th)
        z1 = _interp(table, s)
        z = -0.121 + (z1 + 0.121) * r / (rows - 1)
        return head_point(hc, right, f, th, z, 0.0055)
    _grid(B, cols, rows, point, False, MI["hair"])
    P = lambda x, y, z: hc + right * x + f * y + UP * z
    xs = [-0.027 + 0.0054 * j for j in range(11)]
    pts = [P(x, front_y(x, -0.041) + 0.0040 - 20 * x * x, -0.0405 - 9.0 * x * x) for x in xs]
    _tube(B, pts, [0.0048 * (0.45 + 0.55 * math.cos(math.pi * x / 0.058)) for x in xs], MI["hair"], seg=8, flat=0.6, flat_axis=f)
