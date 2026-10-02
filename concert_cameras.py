"""
concert_cameras.py - group shots, dolly shots along each row, and the title card on the backdrop.

build() makes (or remakes) the cameras and the title-card objects in Concert_Stage.blend. They are
saved with the .blend like the other cameras, so run it once in Blender after changing anything here
and save both .blend copies:
    import concert_cameras as cc; cc.build()

concert_stage.py uses the rest at render time (and so does the viewport preview):
  * place_dollies() moves each dolly camera along its row: it crosses from one end to the other in
    DOLLY_SECONDS, starting when its shot starts, and alternates direction each time it is used.
  * TitleCard reads Uploads/<piece>.title.txt (written by concert_title.py) and shows it on the
    backdrop for the first and last TITLE_SECONDS, with a fade, while the title camera holds.

Directions: the audience looks along +y, so +x is the audience's right ("stage left").
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector

import concert_poses as cp

TITLE_CAM = "Cam 39 Title (backdrop)"
TITLE_SECONDS = 8.0
TITLE_FADE = 1.0
DOLLY_SECONDS = 30.0

# Group shots: camera -> (players framed, azimuth, elevation, lens). The azimuth is in degrees from
# straight out front, + toward the audience's right; the elevation is how far the camera looks down.
GROUP_CAMS = {
    "Cam 40 Strings (finger piano 2, cello, violin, viola)":
        (("Finger Piano 2", "Cello", "Violin", "Viola"), -18, 12, 35),
    "Cam 41 Centre (viola, oboe, horn, vibraphone)":
        (("Viola", "Oboe", "French Horn", "Vibraphone"), 0, 14, 35),
    "Cam 42 Front Right (oboe, finger piano, flute, bass finger piano)":
        (("Oboe", "Finger Piano", "Flute", "Bass Finger Piano"), 18, 12, 35),
    "Cam 43 Riser (trumpet, clarinet, trombone, bassoon)":           # high enough to clear the vibraphonist
        (("Trumpet", "Clarinet", "Trombone", "Bassoon"), 0, 38, 40),
    "Cam 44 Low Brass (tuba, marimba 2, trombone, horn)":
        (("Tuba", "Marimba 2", "Trombone", "French Horn"), -32, 20, 35),
    "Cam 45 Bass Side (marimba, bassoon, baritone, bass finger piano)":
        (("Marimba", "Bassoon", "Baritone Flying V", "Bass Finger Piano"), 32, 20, 35),
    # (the woodwinds as one group stretch from the front row to the back of the riser: too wide a shot)
    "Cam 46 Riser Right (clarinet, bassoon, marimba)":
        (("Clarinet", "Bassoon", "Marimba"), 15, 26, 40),
    "Cam 47 Mallets (marimba 2, vibraphone, marimba)":
        (("Marimba 2", "Vibraphone", "Marimba"), 0, 28, 35),
    "Cam 48 Low End (finger piano 2, cello, tuba)":
        (("Finger Piano 2", "Cello", "Tuba"), -40, 14, 35),
    "Cam 49 Riser Left (trumpet, trombone, marimba 2)":
        (("Trumpet", "Trombone", "Marimba 2"), -15, 26, 40),
}

# Dolly shots, one per row: camera -> (camera y, z, target y, z, x from, x to, lens). The camera and
# its target slide together along x, so the camera looks square onto the row as it passes.
DOLLY_CAMS = {
    "Cam 50 Dolly Front Row": (-5.2, 1.55, -1.6, 1.05, -5.5, 5.5, 26),
    "Cam 51 Dolly Second Row": (-3.0, 3.6, 0.3, 1.35, -5.5, 5.5, 26),   # over the front row's heads
    "Cam 52 Dolly Riser": (-1.0, 3.7, 3.4, 1.6, -4.5, 4.5, 26),         # the riser ends past the marimbas (+-3.7)
}

# ─────────────────────────────── building ───────────────────────────────
FIT = 0.82            # the group fills this share of the frame, width or height, whichever is tighter


def _camera(name, lens):
    """The camera and its "<name> Target" empty with a Track To, like the hand-placed cameras."""
    ref = bpy.data.objects["Cam 1 Audience Wide"]
    coll = ref.users_collection[0]
    cam = bpy.data.objects.get(name)
    if cam is None:
        cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
        coll.objects.link(cam)
    cam.data.lens = lens
    cam.data.sensor_width = ref.data.sensor_width
    cam.data.clip_start, cam.data.clip_end = ref.data.clip_start, ref.data.clip_end
    cam.rotation_euler = (0, 0, 0)
    tgt = bpy.data.objects.get(name + " Target")
    if tgt is None:
        tgt = bpy.data.objects.new(name + " Target", None)
        tgt.empty_display_size = 0.2
        coll.objects.link(tgt)
    for c in list(cam.constraints):
        cam.constraints.remove(c)
    tr = cam.constraints.new('TRACK_TO')
    tr.target = tgt
    tr.track_axis, tr.up_axis = 'TRACK_NEGATIVE_Z', 'UP_Y'
    return cam, tgt


def _player_points(key):
    """Corners of the player's body, plus the floor under it, in world space."""
    ob = bpy.data.objects[cp.body_name(key)]
    pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    base = min(p.z for p in pts)
    cx = sum(p.x for p in pts) / 8; cy = sum(p.y for p in pts) / 8
    floor = 0.5 if base >= 0.45 else 0.0                      # the riser is 0.5 m up
    return pts + [Vector((cx, cy, floor))]


def _fit(points, az, el, lens, aspect=16 / 9):
    """Camera location and target that frame the points from the given direction."""
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    tgt = (lo + hi) / 2
    a, e = math.radians(az), math.radians(el)
    back = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    fwd = -back
    right = fwd.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(fwd)
    th = 18.0 / lens                                          # tan(half horizontal fov), 36 mm sensor
    tv = th / aspect

    def fits(d):
        c = tgt + back * d
        for p in points:
            v = p - c
            z = v.dot(fwd)
            if z <= 0.3 or abs(v.dot(right)) / z > FIT * th or abs(v.dot(up)) / z > FIT * tv:
                return False
        return True

    near, far = 0.5, 60.0
    for _ in range(40):
        mid = (near + far) / 2
        near, far = (near, mid) if fits(mid) else (mid, far)
    return tgt + back * far, tgt


def build_group_cams():
    # a group camera renamed or dropped from GROUP_CAMS goes, with its target
    for ob in [o for o in bpy.data.objects if o.type == 'CAMERA' and o.name[:7] in {f"Cam {n} " for n in range(40, 50)}
               and o.name not in GROUP_CAMS]:
        tgt = bpy.data.objects.get(ob.name + " Target")
        data = ob.data
        bpy.data.objects.remove(ob)
        bpy.data.cameras.remove(data)
        if tgt:
            bpy.data.objects.remove(tgt)
    for name, (players, az, el, lens) in GROUP_CAMS.items():
        pts = [p for key in players for p in _player_points(key)]
        loc, tloc = _fit(pts, az, el, lens)
        cam, tgt = _camera(name, lens)
        cam.location, tgt.location = loc, tloc


def build_dolly_cams():
    for name, (y, z, ty, tz, x0, x1, lens) in DOLLY_CAMS.items():
        cam, tgt = _camera(name, lens)
        cam.location, tgt.location = (x0, y, z), (x0, ty, tz)


def build_title_cam():
    # high enough that the riser players' heads stay below the text on the backdrop
    cam, tgt = _camera(TITLE_CAM, 34)
    cam.location, tgt.location = (0.0, -7.5, 6.0), (0.0, 5.0, 4.6)


# ─────────────────────────────── dollies at render time ───────────────────────────────
def dolly_directions(shots):
    """{shot start: +1 or -1}: each dolly camera alternates direction every time it is used."""
    uses, dirs = {}, {}
    for t0, cam in shots:
        if cam in DOLLY_CAMS:
            n = uses.get(cam, 0)
            dirs[t0] = 1 if n % 2 == 0 else -1
            uses[cam] = n + 1
    return dirs


def dolly_place(name, u, direction=1):
    """Put a dolly camera u (0..1) of the way along its row."""
    y, z, ty, tz, x0, x1, _ = DOLLY_CAMS[name]
    if direction < 0:
        x0, x1 = x1, x0
    u = max(0.0, min(1.0, u))
    u = u * u * (3 - 2 * u)                                    # ease in and out at the ends
    x = x0 + (x1 - x0) * u
    cam, tgt = bpy.data.objects.get(name), bpy.data.objects.get(name + " Target")
    if cam and tgt:
        cam.location, tgt.location = (x, y, z), (x, ty, tz)


def place_dollies(shots, dirs, t):
    """The dolly on screen at time t moves along its row; the others wait at their start."""
    t0, cam = shots[0]
    for s0, c in shots:
        if s0 <= t:
            t0, cam = s0, c
    for name in DOLLY_CAMS:
        if name == cam:
            dolly_place(name, (t - t0) / DOLLY_SECONDS, dirs.get(t0, 1))
        else:
            dolly_place(name, 0.0)


def home_dollies():
    for name in DOLLY_CAMS:
        dolly_place(name, 0.0)


# ─────────────────────────────── title card ───────────────────────────────
TITLE_FONT_SANS = r"\\wsl.localhost\FedoraLinux-44\usr\share\fonts\adwaita-sans-fonts\AdwaitaSans-Regular.ttf"
TITLE_FONT_MONO = r"\\wsl.localhost\FedoraLinux-44\usr\share\fonts\adwaita-mono-fonts\AdwaitaMono-Regular.ttf"
TITLE_PARTS = {          # object -> (font, size, line spacing, glyph thickening)
    "Title Heading": ("sans", 0.75, 1.0, 0.012),
    "Title Credits": ("sans", 0.40, 1.2, 0.004),
    "Title Details": ("mono", 0.24, 1.12, 0.0),     # the first paragraph of the body lines
    "Title Info": ("mono", 0.24, 1.12, 0.0),        # the rest: left-aligned as a block, indents kept
}
GLYPH = {"sans": 0.68, "mono": 0.53}                # height of one line of text at size 1 (measured)
MONO_ADVANCE = 0.3346                               # Adwaita Mono character width at size 1 (measured)
TITLE_PLANE_Y = 5.0      # just in front of the backdrop (its front face is at y = 5.12)
TITLE_TOP_Z = 6.75       # under the upstage truss and its lights (z 6.9-7.5, right at the backdrop)
TITLE_GAP = 0.30         # between the heading, the credits and the body; a blank line is 0.6 of this


def _font(which):
    """The packed font: packed into the .blend so the farm's Linux pods render the same glyphs."""
    name = {"sans": "Adwaita Sans Title", "mono": "Adwaita Mono Title"}[which]
    f = bpy.data.fonts.get(name)
    if f is None:
        f = bpy.data.fonts.load(TITLE_FONT_SANS if which == "sans" else TITLE_FONT_MONO)
        f.name = name
        f.pack()
    return f


def _title_material():
    """White glow; "Title Fade" (0..1) mixes it with transparent for the fade."""
    m = bpy.data.materials.get("Title Text")
    if m is None:
        m = bpy.data.materials.new("Title Text")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1.0, 0.97, 0.9, 1.0)
    em.inputs["Strength"].default_value = 3.0
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    fade = nt.nodes.new("ShaderNodeValue"); fade.name = fade.label = "Title Fade"
    fade.outputs[0].default_value = 0.0
    nt.links.new(fade.outputs[0], mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    if hasattr(m, "surface_render_method"):
        m.surface_render_method = 'BLENDED'
    return m


def build_title():
    mat = _title_material()
    coll = bpy.data.objects["Cam 1 Audience Wide"].users_collection[0]
    for name, (font, size, spacing, offset) in TITLE_PARTS.items():
        ob = bpy.data.objects.get(name)
        if ob is None:
            ob = bpy.data.objects.new(name, bpy.data.curves.new(name, 'FONT'))
            coll.objects.link(ob)
        cu = ob.data
        cu.font = _font(font)
        cu.size, cu.space_line, cu.offset = size, spacing, offset
        cu.align_x, cu.align_y = ('LEFT' if name == "Title Info" else 'CENTER'), 'TOP'
        cu.materials.clear(); cu.materials.append(mat)
        ob.rotation_euler = (math.pi / 2, 0, 0)                # stand up, facing the audience
        ob.location = (0.0, TITLE_PLANE_Y, TITLE_TOP_Z)
        cu.body = name
        ob.hide_render = ob.hide_viewport = True


def build():
    """Make or remake every camera and the title card. Save both .blend copies afterwards."""
    cp.load_layout()
    build_group_cams()
    build_dolly_cams()
    build_title_cam()
    build_title()
    print(f"[cameras] {len(GROUP_CAMS)} group cameras, {len(DOLLY_CAMS)} dollies, title camera and card")


class TitleCard:
    """The title text for one piece, shown on the backdrop at the start and the end."""

    def __init__(self, lines, duration):
        self.parts = {name: [] for name in TITLE_PARTS}
        part = {"big": "Title Heading", "mid": "Title Credits"}
        body = []
        for style, text in lines:
            if style in part:
                self.parts[part[style]].append(text)
            else:
                body.append(text)
        # the body's first paragraph is centred; everything after its first blank line is the info block
        while body and not body[0].strip():
            body.pop(0)
        cut = body.index("") if "" in body else len(body)
        self.parts["Title Details"] = body[:cut]
        self.parts["Title Info"] = [ln for ln in body[cut:] if ln.strip()]
        self.seconds = min(TITLE_SECONDS, duration / 3)
        self.duration = duration
        self.obs = [bpy.data.objects.get(n) for n in TITLE_PARTS]
        self.fade = bpy.data.materials["Title Text"].node_tree.nodes["Title Fade"]
        self._layout()

    @classmethod
    def for_piece(cls, npy, duration, path=None):
        """From --title PATH, else Uploads/<piece>.title.txt next to the .npy; None for no card."""
        if path in ("none", ""):
            return None
        p = Path(path) if path else Path(str(npy)[:-4] + ".title.txt")
        if not p.is_file() or not all(bpy.data.objects.get(n) for n in TITLE_PARTS):
            return None
        lines = []
        for raw in p.read_text(encoding="utf-8").splitlines():
            style, _, text = raw.partition("\t")
            lines.append((style.strip(), text.rstrip()))
        return cls(lines, duration)

    def _layout(self):
        z = TITLE_TOP_Z
        for ob in self.obs:
            lines = self.parts[ob.name]
            ob.data.body = "\n".join(lines)
            ob.location.z = z
            if ob.name == "Title Info":                       # centre the left-aligned block
                ob.location.x = -max((len(ln) for ln in lines), default=0) * MONO_ADVANCE * ob.data.size / 2
            if lines:
                font = TITLE_PARTS[ob.name][0]
                z -= ob.data.size * (ob.data.space_line * (len(lines) - 1) + GLYPH[font])
                z -= TITLE_GAP * (0.6 if ob.name == "Title Details" else 1.0)

    def alpha(self, t):
        s, d, f = self.seconds, self.duration, TITLE_FADE
        if t < s:
            return max(0.0, min(1.0, (s - t) / f))
        if t >= d - s:
            return max(0.0, min(1.0, (t - (d - s)) / f))
        return 0.0

    def showing(self, t):
        return t < self.seconds or t >= self.duration - self.seconds

    def apply(self, t):
        a = self.alpha(t)
        self.fade.outputs[0].default_value = a
        for ob in self.obs:
            ob.hide_render = ob.hide_viewport = a <= 0.0 or not ob.data.body

    def hide(self):
        self.fade.outputs[0].default_value = 0.0
        for ob in self.obs:
            ob.hide_render = ob.hide_viewport = True
