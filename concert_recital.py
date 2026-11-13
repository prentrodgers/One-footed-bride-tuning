"""
concert_recital.py - a recital in the Alcorcón hall: an audience in the seats, a garnet house curtain
that parts, a short title on the closed curtain, applause, and now and then a look at the house.

Build the stage once, from the piano stage (concert_piano.py), into a new file:

    blender --background Alcorcon_Piano.blend --python concert_recital.py -- --out Alcorcon_Recital.blend
    blender --background Alcorcon_Piano.blend --python concert_recital.py -- --out Alcorcon_Recital.blend \
        --preview /tmp/recital_stills         # also a still from each new camera (EEVEE)

then make the recital's soundtrack, notes and timeline with make_recital.py, and render as any piece,
with BLEND=Alcorcon_Recital.blend. concert_stage.py finds Uploads/<recital>.recital.json beside the .npy
and hands the timeline to Recital (below): render_farm.sh and concert_mux.sh see an ordinary piece whose
mp3 already holds the applause, so there is no title card and no audio delay.

The timeline (video seconds, all in the .recital.json):
  * 0 .. title_end: the curtain is closed and the title (the piece and the hall, half the size of the
    usual title card) fades in and out on it, seen from the stalls over the first rows' heads;
  * curtain_open: the curtain parts while the applause starts; the music begins as the applause dies;
  * the pieces play one after another, no applause between them; the cameras follow the pianist as on
    the piano stage, and every AUDIENCE_EVERY seconds or so (and in the pause between pieces) a shot
    takes in the house: a pan from the pianist across the stalls, or the pianist over the heads;
  * after the last note the applause again, the house lights come up and the curtain closes.

The audience is built once (fixed seed): about three quarters of the stalls filled, fewer upstairs, each
patron a seated figure of a few primitives in one of a dozen coats, four skin tones and five hair
colours, merged into one mesh per level. They do not move.
"""
import argparse
import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

REPO_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_DIR))
import concert_stagekit as sk        # noqa: E402

# ─────────────────────────────── the curtain ───────────────────────────────
# The house curtain (a traveller in two halves) hangs just upstage of the tied-back legs and the valance
# that concert_hall.py built (they are at y -4.05, 0.17 thick), so they frame it as in a real house.
PROSC_HALF_W, PROSC_H = 7.5, 8.0         # concert_hall's opening
CURTAIN_Y = -3.70                        # centre line of the folds
CURTAIN_FOLD = 0.34                      # fold wavelength (m) when closed
CURTAIN_DEPTH = 0.07                     # fold amplitude
CURTAIN_OVERLAP = 0.15                   # the halves overlap at the centre
CURTAIN_GATHER = 0.13                    # open: each half gathered to this share of its width
CURTAIN_NAMES = ("Recital Curtain L", "Recital Curtain R")

# ─────────────────────────────── the audience ───────────────────────────────
FILL = (0.78, 0.55, 0.35)                # share of seats taken: stalls, amphitheatre, gallery
FRONT_ROWS_FULL = 6                      # the first rows of the stalls are full (the title shot sees them)
SEED = 356
COATS = [(0.05, 0.05, 0.06), (0.08, 0.09, 0.14), (0.20, 0.20, 0.22), (0.32, 0.06, 0.07), (0.12, 0.18, 0.12),
         (0.42, 0.35, 0.26), (0.55, 0.52, 0.48), (0.10, 0.12, 0.24), (0.36, 0.22, 0.12), (0.60, 0.58, 0.56),
         (0.22, 0.10, 0.20), (0.03, 0.03, 0.03)]
SKINS = [(0.80, 0.60, 0.48), (0.66, 0.46, 0.34), (0.48, 0.32, 0.22), (0.30, 0.19, 0.13)]
HAIRS = [(0.03, 0.025, 0.02), (0.16, 0.09, 0.05), (0.42, 0.30, 0.16), (0.50, 0.50, 0.50), (0.82, 0.80, 0.76)]
TROUSERS = [(0.04, 0.04, 0.05), (0.10, 0.10, 0.12), (0.18, 0.16, 0.14)]

# ─────────────────────────────── cameras ───────────────────────────────
# name -> (location, target, lens). The title shot stands in the centre aisle of the stalls, behind the
# seventh row, so the closed curtain fills the frame over the first rows' heads.
CURTAIN_CAM = "Cam 70 Curtain over the Front Rows"
STILL_CAMS = {
    CURTAIN_CAM: ((0.0, -14.6, 1.55), (0.0, -3.9, 3.1), 22),
    "Cam 71 Pianist over the Heads": ((-2.0, -12.6, 1.30), (-0.6, 0.3, 1.0), 55),
    # the stage-side cameras stand on the apron, between the curtain (y -3.7) and the footlights (-4.3),
    # inside the tied-back legs (x +-5.75 .. 7.05)
    "Cam 72 House from Stage Left": ((5.3, -4.25, 2.0), (-2.5, -11.0, 0.2), 26),
}
# Pans: (location, target at the start, target at the end, lens); the target glides from one to the
# other over the shot, eased at both ends.
PAN_CAMS = {
    "Cam 73 Pan Pianist to House": ((-5.3, -4.25, 2.2), (-0.4, 0.4, 1.0), (1.5, -12.0, 0.4), 30),
    "Cam 74 Pan House to Pianist": ((10.2, -8.6, 1.9), (-3.5, -12.5, 0.4), (-0.5, 0.3, 1.0), 32),
}
AUDIENCE_CAMS = ["Cam 71 Pianist over the Heads", "Cam 73 Pan Pianist to House", "Cam 72 House from Stage Left",
                 "Cam 74 Pan House to Pianist"]
OUTRO_CAM = "Cam 71 Pianist over the Heads"
AUDIENCE_EVERY = (35.0, 55.0)            # seconds between looks at the house during the music
AUDIENCE_HOLD = (6.0, 8.0)               # how long one lasts
CLEAR_OF_START = 8.0                     # not in the first seconds of a piece
MIN_SHOT = 2.5                           # a shot cut back to after a look at the house lasts at least this

# house lights (the "house" dimmer): up before the show, down for the music, up for the bows
HOUSE_PRESHOW, HOUSE_SHOW, HOUSE_BOWS = 2.4, 0.9, 2.0

# ─────────────────────────────── title ───────────────────────────────
TITLE_Z = 4.4                            # the heading's top on the curtain
TITLE_Y = CURTAIN_Y - 0.30               # just in front of the folds
TITLE_SCALE = 0.5                        # on screen, of the usual title card's size (concert_cameras.TITLE_PARTS)
CARD_VIEW_W = 13.2                       # how much of the backdrop the usual title camera sees (m)


# ═══════════════════════════════ building ═══════════════════════════════
def _materials():
    M = {"velvet": bpy.data.materials["Hall Curtain Garnet"]}
    for group, cols, rough in (("coat", COATS, 0.85), ("skin", SKINS, 0.55), ("hair", HAIRS, 0.7),
                               ("trousers", TROUSERS, 0.8)):
        M[group] = [sk.mat(f"Patron {group.title()} {i}", c, rough=rough, spec=0.3) for i, c in enumerate(cols)]
    return M


def curtain(M, C):
    """The two halves, each a sheet of soft folds hung from its outer edge (the object's origin), so
    scaling it in x gathers it toward the side."""
    obs = []
    for name, s in zip(CURTAIN_NAMES, (-1, 1)):
        width = PROSC_HALF_W + CURTAIN_OVERLAP
        n = int(width / 0.04)
        bm = bmesh.new()
        rows = []
        for z in (-0.05, PROSC_H):
            row = []
            for i in range(n + 1):
                u = i / n * width                         # from the outer edge toward the centre
                y = CURTAIN_DEPTH * math.sin(2 * math.pi * u / CURTAIN_FOLD)
                row.append(bm.verts.new((-s * u, y, z)))
            rows.append(row)
        for i in range(n):
            bm.faces.new((rows[0][i], rows[0][i + 1], rows[1][i + 1], rows[1][i]))
        ob = sk.mesh_obj(name, bm, loc=(s * PROSC_HALF_W, CURTAIN_Y, 0.0), mats=[M["velvet"]], collection=C,
                         smooth=True)
        sol = ob.modifiers.new("Thickness", 'SOLIDIFY')
        sol.thickness = 0.03
        obs.append(ob)
    return obs


SLOTS = ("trousers", "coat", "skin", "hair")           # the prototypes' material slots, in this order
STYLES = ("short", "long", "bald")


def _patron(B, x, y, z, style, h=1.0, lean=0.0, mi=(1, 2, 3, 0)):
    """One seated figure facing +y on a seat whose floor is at z (concert_hall's seat: cushion top z+0.49,
    back leaning behind y-0.24)."""
    coat, skin, hair, trousers = mi
    seat = z + 0.50
    # legs: thighs forward along the cushion, shins down to the floor
    for a in (-1, 1):
        B.box((x + a * 0.10, y + 0.12, seat + 0.07), (0.15, 0.42, 0.14), mi=trousers)
        B.box((x + a * 0.10, y + 0.33, z + 0.27), (0.13, 0.13, 0.50), mi=trousers)
        B.box((x + a * 0.10, y + 0.38, z + 0.04), (0.11, 0.24, 0.08), mi=0)     # shoes: the black trousers
    # torso: a tapered cylinder from the hips up, flattened front to back by its width
    hip = Vector((x, y - 0.08, seat + 0.05))
    neck = Vector((x + lean, y - 0.12, seat + 0.62 * h))
    B.cyl(hip, neck, 0.17 * h, mi=coat, seg=14, r2=0.20 * h)
    B.sphere(neck + Vector((0, 0, -0.03)), 0.21 * h, mi=coat, scale=(1.0, 0.6, 0.35), seg=14, rings=6)
    # arms: shoulders down to the lap, hands resting on the thighs
    for a in (-1, 1):
        sh = neck + Vector((a * 0.19 * h, 0.0, -0.06))
        el = Vector((x + a * 0.21 * h, y + 0.02, seat + 0.25))
        hd = Vector((x + a * 0.09, y + 0.24, seat + 0.17))
        B.cyl(sh, el, 0.055 * h, mi=coat, seg=8)
        B.cyl(el, hd, 0.05 * h, mi=coat, seg=8)
        B.sphere(hd, 0.045, mi=skin, scale=(1.0, 1.3, 0.6), seg=8, rings=4)
    # neck, head, hair (the hair sits back on the head, so the face shows from the stage)
    B.cyl(neck, neck + Vector((0, 0.01, 0.10)), 0.05, mi=skin, seg=8)
    head = neck + Vector((0, 0.02, 0.21 * h))
    B.sphere(head, 0.105 * h, mi=skin, scale=(0.88, 1.0, 1.15), seg=14, rings=8)
    if style != "bald":                               # the hair sits back on the head, so the face shows
        B.sphere(head + Vector((0, -0.025, 0.035)), 0.112 * h, mi=hair,
                 scale=(0.92, 0.98, 1.0 if style == "short" else 1.12), seg=14, rings=8)


def audience(M, C):
    """Patrons in the seats: a few prototype meshes, one object per patron sharing them, each with its own
    coat, skin, hair and trousers (object-level materials), size and a little sideways lean.
    Returns how many. (One merged mesh took minutes to build: bmesh ops slow down as the mesh grows.)"""
    import concert_hall as ch
    rng = random.Random(SEED)
    protos = {}
    for style in STYLES:
        B = sk.Builder()
        _patron(B, 0.0, 0.0, 0.0, style)
        ob = B.build(f"Recital Patron ({style})", [M["trousers"][0], M["coat"][0], M["skin"][0], M["hair"][0]],
                     collection=C, smooth=True)
        protos[style] = ob.data
        bpy.data.objects.remove(ob)                    # the mesh stays, used by the patrons
    weights = (0.5, 0.38, 0.12)
    count = 0
    for x, y, z, lv, row, _t in ch.seat_positions():
        full = lv == 0 and row < FRONT_ROWS_FULL
        if not full and rng.random() > FILL[lv]:
            continue
        style = rng.choices(STYLES, weights)[0]
        ob = bpy.data.objects.new(f"Patron {count:03d}", protos[style])
        C.objects.link(ob)
        h = rng.uniform(0.92, 1.06)
        ob.location = (x, y, z)
        ob.scale = (h, h, h)
        ob.rotation_euler = (0.0, rng.uniform(-0.04, 0.04), rng.uniform(-0.08, 0.08))
        for slot, group in zip(ob.material_slots, SLOTS):
            slot.link = 'OBJECT'
            slot.material = rng.choice(M[group])
        count += 1
    return count


def cameras():
    import concert_cameras as cc
    for name, (loc, tgt, lens) in STILL_CAMS.items():
        cam, t = cc._camera(name, lens)
        cam.location, t.location = loc, tgt
    for name, (loc, t0, _t1, lens) in PAN_CAMS.items():
        cam, t = cc._camera(name, lens)
        cam.location, t.location = loc, t0


def build():
    C = sk.coll("Recital", bpy.data.collections.get("Concert Stage Set"))
    M = _materials()
    curtain(M, C)
    n = audience(M, C)
    cameras()
    print(f"[recital] curtain, {n} patrons, {len(STILL_CAMS) + len(PAN_CAMS)} cameras")


def preview(out_dir, samples=32, res=(1280, 720), closed=True):
    sc = sk.scene()
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.engine = 'BLENDER_EEVEE'
    sc.eevee.taa_render_samples = samples
    sc.render.image_settings.file_format = 'PNG'
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    for name in [CURTAIN_CAM] + [c for c in AUDIENCE_CAMS]:
        set_curtain(0.0 if (closed and name == CURTAIN_CAM) else 1.0)
        sc.camera = bpy.data.objects[name]
        sc.render.filepath = str(out_dir / (name.split(" ")[1] + ".png"))
        bpy.ops.render.render(write_still=True)
        print(f"[recital] wrote {sc.render.filepath}")
    set_curtain(1.0)


# ═══════════════════════════════ render time ═══════════════════════════════
def _ease(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def set_curtain(openness):
    """0 closed, 1 open (gathered at the sides)."""
    s = 1.0 + (CURTAIN_GATHER - 1.0) * _ease(openness)
    for name in CURTAIN_NAMES:
        ob = bpy.data.objects.get(name)
        if ob:
            ob.scale.x = s


def has_stage():
    return all(bpy.data.objects.get(n) for n in CURTAIN_NAMES + (CURTAIN_CAM,))


class Recital:
    """The timeline of one recital (Uploads/<name>.recital.json, written by make_recital.py)."""

    def __init__(self, spec):
        self.spec = spec
        self.title_lines = spec["title"]
        self.title_end = spec["title_end"]
        self.title_fade = spec.get("title_fade", 1.0)
        self.curtain_open = spec["curtain_open"]
        self.curtain_close = spec.get("curtain_close")
        self.music_start, self.music_end, self.end = spec["music_start"], spec["music_end"], spec["end"]
        self.pieces = spec["pieces"]                          # [{name, start, end}] video seconds
        self.bows = spec["applause"][-1][0] if len(spec["applause"]) > 1 else self.end
        self.pans = {}                                        # shot start -> (pan camera, end of the shot)
        self.ctrl = bpy.data.objects["Stage Controls"]
        self._title_setup()

    @classmethod
    def for_piece(cls, npy):
        p = Path(str(npy)[:-4] + ".recital.json")
        if not p.is_file():
            return None
        if not has_stage():
            raise SystemExit(f"[recital] {p} needs Alcorcon_Recital.blend (concert_recital.py): this .blend has "
                             f"no house curtain")
        return cls(json.loads(p.read_text(encoding="utf-8")))

    # ── the title on the closed curtain ──
    def _title_setup(self):
        import concert_cameras as cc
        self.title_obs = {n: bpy.data.objects.get(n) for n in cc.TITLE_PARTS}
        self.fade = bpy.data.materials["Title Text"].node_tree.nodes["Title Fade"]
        heading, *rest = self.title_lines
        # half the usual card's size on screen: scaled by how much wider this shot sees than the card's
        cam = bpy.data.objects[CURTAIN_CAM]
        view_w = abs(cam.location.y - TITLE_Y) * cam.data.sensor_width / cam.data.lens
        k = TITLE_SCALE * view_w / CARD_VIEW_W
        z = TITLE_Z
        for name, lines in (("Title Heading", [heading]), ("Title Credits", rest), ("Title Details", []),
                            ("Title Info", [])):
            ob = self.title_obs[name]
            ob.data.body = "\n".join(lines)
            if not lines:
                continue
            base = cc.TITLE_PARTS[name][1]
            widest = max(len(ln) for ln in lines) * cc.SANS_ADVANCE
            ob.data.size = k * min(base, cc.TITLE_MAX_W / widest)
            ob.location = (0.0, TITLE_Y, z)
            ob.visible_shadow = False                         # the front wash would print it on the curtain
            z -= ob.data.size * (ob.data.space_line * (len(lines) - 1) + cc.GLYPH["sans"]) + k * cc.TITLE_GAP

    def title_alpha(self, t):
        fade_in = min(0.6, self.title_end / 4)
        return max(0.0, min(1.0, t / fade_in, (self.title_end - t) / self.title_fade))

    def showing_title(self, t):
        return t < self.title_end

    # ── per frame ──
    def apply(self, t, shots):
        a = self.title_alpha(t)
        self.fade.outputs[0].default_value = a
        for ob in self.title_obs.values():
            if ob:
                ob.hide_render = ob.hide_viewport = a <= 0.0 or not ob.data.body
        o0, o1 = self.curtain_open
        openness = (t - o0) / (o1 - o0)
        if self.curtain_close:
            c0, c1 = self.curtain_close
            if t >= c0:
                openness = 1.0 - (t - c0) / (c1 - c0)
        set_curtain(max(0.0, min(1.0, openness)))
        self.ctrl["house"] = self.house(t)
        self._place_pans(t, shots)

    def house(self, t):
        o0, o1 = self.curtain_open
        if t < o0:
            return HOUSE_PRESHOW
        if t < self.music_start:                              # down as the curtain opens and the applause dies
            return HOUSE_PRESHOW + (HOUSE_SHOW - HOUSE_PRESHOW) * _ease((t - o0) / max(0.1, self.music_start - o0))
        if t < self.bows:
            return HOUSE_SHOW
        return HOUSE_SHOW + (HOUSE_BOWS - HOUSE_SHOW) * _ease((t - self.bows) / 3.0)

    def _place_pans(self, t, shots):
        cur, t0, t1 = None, 0.0, self.end
        for k, (s0, cam) in enumerate(shots):
            if s0 <= t:
                cur, t0 = cam, s0
                t1 = shots[k + 1][0] if k + 1 < len(shots) else self.end
        for name, (loc, a, b, _lens) in PAN_CAMS.items():
            tgt = bpy.data.objects.get(name + " Target")
            if not tgt:
                continue
            u = _ease((t - t0) / max(0.1, t1 - t0)) if name == cur else 0.0
            tgt.location = Vector(a).lerp(Vector(b), u)

    def restore(self):
        """Curtain open, house at 1, pans home, the title hidden and back on the backdrop (for saving)."""
        import concert_cameras as cc
        set_curtain(1.0)
        self.ctrl["house"] = 1.0
        self.fade.outputs[0].default_value = 0.0
        for ob in self.title_obs.values():
            if ob:
                ob.hide_render = ob.hide_viewport = True
                ob.location = (0.0, cc.TITLE_PLANE_Y, cc.TITLE_TOP_Z)
                ob.data.size = cc.TITLE_PARTS[ob.name][1]
                ob.visible_shadow = True
        for name, (loc, a, _b, _lens) in PAN_CAMS.items():
            tgt = bpy.data.objects.get(name + " Target")
            if tgt:
                tgt.location = a

    # ── the shots ──
    def shots(self, music_shots, seed=7):
        """The intro and the bows around the music's shots (from build_shots, which framed the music with
        the title camera), with a look at the house now and then and in each pause between pieces."""
        import concert_cameras as cc
        rng = random.Random(seed * 31 + 7)
        inner = [(t, c) for t, c in music_shots if c != cc.TITLE_CAM and self.music_start <= t < self.music_end]
        # looks at the house: in each pause between pieces, and every so often during the music
        looks = []
        for a, b in zip(self.pieces, self.pieces[1:]):
            looks.append((a["end"] - 1.0, b["start"] + 2.5))
        t = self.music_start + rng.uniform(*AUDIENCE_EVERY)
        while t < self.music_end - 12.0:
            hold = rng.uniform(*AUDIENCE_HOLD)
            clear = all(not (p["start"] - 2.0 <= t < p["start"] + CLEAR_OF_START) for p in self.pieces)
            clear = clear and all(not (a - 4.0 < t < b + 4.0) for a, b in looks)
            if clear:
                looks.append((t, t + hold))
                t += hold + rng.uniform(*AUDIENCE_EVERY)
            else:
                t += 3.0
        looks.sort()
        n = 0
        for a, b in looks:
            before = [s for s in inner if s[0] <= b]
            resume = before[-1][1] if before else (inner[0][1] if inner else OUTRO_CAM)
            inner = [s for s in inner if not (a <= s[0] < b)]
            cam = AUDIENCE_CAMS[n % len(AUDIENCE_CAMS)]
            n += 1
            inner += [(a, cam), (b, resume)]
        inner.sort()
        out = [(0.0, CURTAIN_CAM)] + inner + [(self.music_end + 0.4, OUTRO_CAM)]
        if self.curtain_close:                                # the curtain closing, seen from the stalls
            out.append((self.curtain_close[0] - 0.5, CURTAIN_CAM))
        # no cut back to a shot for less than MIN_SHOT seconds: the next shot starts there instead
        out.sort()
        merged = []
        for k, (t0, cam) in enumerate(out):
            t1 = out[k + 1][0] if k + 1 < len(out) else self.end
            if merged and cam != CURTAIN_CAM and cam not in AUDIENCE_CAMS and t1 - t0 < MIN_SHOT:
                out[k + 1] = (t0, out[k + 1][1]) if k + 1 < len(out) else out[k + 1]
                continue
            if not merged or merged[-1][1] != cam:
                merged.append((t0, cam))
        return merged

    def describe(self):
        p = ", ".join(f"{x['name']} {x['start']:.1f}-{x['end']:.1f}" for x in self.pieces)
        return (f"title to {self.title_end:g} s, curtain opens {self.curtain_open[0]:g}-{self.curtain_open[1]:g} s, "
                f"music {self.music_start:.1f}-{self.music_end:.1f} s ({p}), applause at "
                f"{', '.join(f'{a:.1f}' for a, _ in self.spec['applause'])} s, video {self.end:.1f} s")


# ═══════════════════════════════ main ═══════════════════════════════
def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--out", default="Alcorcon_Recital.blend")
    p.add_argument("--preview", default=None, help="directory for a still from each new camera")
    p.add_argument("--samples", type=int, default=32)
    args = p.parse_args(argv)
    if bpy.data.objects.get(CURTAIN_NAMES[0]):
        raise SystemExit("[recital] this .blend already has the recital stage; build from Alcorcon_Piano.blend")
    build()
    bpy.context.view_layer.update()
    out = str((REPO_DIR / args.out).resolve()) if not Path(args.out).is_absolute() else args.out
    bpy.ops.wm.save_as_mainfile(filepath=out, copy=True)
    print(f"[recital] saved {out}")
    if args.preview:
        preview(args.preview, samples=args.samples)


if __name__ == "__main__":
    main()
