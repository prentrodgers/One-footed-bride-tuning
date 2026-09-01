#!/usr/bin/env python3
"""stage_boxes.py — where each section lands ON SCREEN, in pure Python.

blender_stage.py --dump-layout already writes every camera target's world
bounding box, the camera (pos/target/lens/sensor) and the resolved cue sheet
into stage_layout.json.  That is enough to work out, without Blender, which
rectangle of a rendered frame holds the marimba, which holds the brass, and
so on.  comfy_restyle.py uses those rectangles to tell the diffusion model
what each part of the picture actually is — otherwise SDXL sees a big wooden
keyboard-shaped thing and paints a piano.

    ./stage_boxes.py --time 0 --print
    ./stage_boxes.py --overlay stage_proto.png/frame_000000.png --out boxed.png

The camera maths mirrors blender_stage.py's _framing/_shot_framing and
stage_preview.html's framing() — same lens, sensor, margin and cue sheet, so
a shot framed here is the shot that rendered.
"""
import argparse
import json
import math
import pathlib
import sys

FPS = 30
LAYOUT = "stage_layout.json"


# ── small vector helpers (no numpy on every node) ───────────────────────────
def _sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def _add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def _mul(a, s): return (a[0] * s, a[1] * s, a[2] * s)
def _dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def _cross(a, b): return (a[1] * b[2] - a[2] * b[1],
                          a[2] * b[0] - a[0] * b[2],
                          a[0] * b[1] - a[1] * b[0])


def _norm(a):
    n = math.sqrt(_dot(a, a))
    return (a[0] / n, a[1] / n, a[2] / n) if n else (0.0, 0.0, 0.0)


def _lerp(a, b, s): return tuple(x + (y - x) * s for x, y in zip(a, b))


def _smoothstep(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3.0 - 2.0 * x)


def _centre(b):
    return ((b[0] + b[1]) / 2.0, (b[2] + b[3]) / 2.0, (b[4] + b[5]) / 2.0)


# ── camera: which shot is live at time t ────────────────────────────────────
def _half_fovs(cam, aspect):
    """(horizontal, vertical) half-FOV in radians. Blender's AUTO sensor fit
    puts the sensor width on the long axis, which for 16:9 is horizontal."""
    half_h = math.atan((cam["sensor"] / 2.0) / cam["lens"])
    half_v = math.atan((cam["sensor"] / aspect / 2.0) / cam["lens"])
    return half_h, half_v


def _framing(focus, L):
    """(camera position, look-at) for a plain shot — the wide camera's angle
    and lens, pushed in along its own axis until `focus` fills the frame."""
    cam, targets = L["cam"], L["targets"]
    if focus == ["wide"] or focus == "wide":
        return tuple(cam["pos"]), tuple(cam["target"])

    boxes = [targets[n] for n in shot_names(focus)]
    x0 = min(b[0] for b in boxes); x1 = max(b[1] for b in boxes)
    y0 = min(b[2] for b in boxes); y1 = max(b[3] for b in boxes)
    z0 = min(b[4] for b in boxes); z1 = max(b[5] for b in boxes)
    target = ((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)

    half_h, half_v = _half_fovs(cam, L["aspect"])
    half_w = (x1 - x0) / 2.0 * L["margin"]
    half_t = (z1 - z0) / 2.0 * L["margin"]
    dist = max(half_w / math.tan(half_h), half_t / math.tan(half_v), 6.0)
    axis = _norm(_sub(cam["pos"], cam["target"]))
    pos = _add(target, _mul(axis, dist))
    return (pos[0], pos[1], max(pos[2], 1.5)), target


def _framing_overhead(name, L):
    """The one shot form that leaves the fixed angle: a high oblique looking
    down on one target, tilted back toward the audience."""
    cam = L["cam"]
    c = _centre(L["targets"][name])
    b = L["targets"][name]
    half_h, half_v = _half_fovs(cam, L["aspect"])
    half_w = (b[1] - b[0]) / 2.0 * L["margin"]
    half_d = (b[3] - b[2]) / 2.0 * L["margin"]
    h = max(half_w / math.tan(half_h), half_d / math.tan(half_v), 8.0)
    return _add(c, (0.0, -h * 0.75, h * 0.85)), c


def shot_names(focus):
    """The target names a shot refers to, minus any leading form marker."""
    names = [focus] if isinstance(focus, str) else list(focus)
    return names[1:] if names and names[0] == "overhead" else names


def _shot_framing(focus, L, progress=0.0):
    names = [focus] if isinstance(focus, str) else list(focus)
    if names and names[0] == "overhead":
        pa, ta = _framing_overhead(names[1], L)
        pb, tb = _framing_overhead(names[2], L)
        return _lerp(pa, pb, progress), _lerp(ta, tb, progress)
    return _framing(focus, L)


def _cue_index(t, cues):
    i = 0
    while i + 1 < len(cues) and t >= cues[i + 1]["t"]:
        i += 1
    return i


def _shot_progress(i, t, cues, hold):
    """How far through its own hold a shot is, 0..1 — only pans use it."""
    if i + 1 >= len(cues):
        return _smoothstep((t - cues[i]["t"]) / sum(hold) * 2.0)
    span = cues[i + 1]["t"] - cues[i]["t"]
    return _smoothstep((t - cues[i]["t"]) / span) if span > 0 else 0.0


def camera_at(L, t):
    """(position, look-at) of the render camera at time t, cue sheet and all."""
    cues = L.get("cues")
    if not cues:
        return tuple(L["cam"]["pos"]), tuple(L["cam"]["target"])
    i = _cue_index(t, cues)
    cue = cues[i]
    pos, target = _shot_framing(cue["focus"], L,
                                _shot_progress(i, t, cues, L["hold"]))
    move = cue.get("move") or 0.0
    if i > 0 and move > 0.0:
        blend = _smoothstep((t - cue["t"]) / move)
        if blend < 1.0:
            p0, t0 = _shot_framing(cues[i - 1]["focus"], L, 1.0)
            pos, target = _lerp(p0, pos, blend), _lerp(t0, target, blend)
    return pos, target


# ── projection: world point -> fraction of the frame ────────────────────────
def _basis(pos, target):
    """Camera axes, Z-up world: forward, right, up."""
    fwd = _norm(_sub(target, pos))
    right = _norm(_cross(fwd, (0.0, 0.0, 1.0)))
    return fwd, right, _cross(right, fwd)


def project(point, pos, target, cam, aspect):
    """(x, y, depth): x/y in 0..1 across the frame, y down. depth <= 0 is
    behind the camera and the x/y are meaningless."""
    fwd, right, up = _basis(pos, target)
    v = _sub(point, pos)
    depth = _dot(v, fwd)
    if depth <= 1e-6:
        return 0.0, 0.0, depth
    half_h, half_v = _half_fovs(cam, aspect)
    ndc_x = (_dot(v, right) / depth) / math.tan(half_h)
    ndc_y = (_dot(v, up) / depth) / math.tan(half_v)
    return (ndc_x + 1.0) / 2.0, (1.0 - ndc_y) / 2.0, depth


def _corners(b):
    return [(x, y, z) for x in b[0:2] for y in b[2:4] for z in b[4:6]]


def box_on_screen(world_box, pos, target, cam, aspect, pad=0.0):
    """Screen rectangle (x0, y0, x1, y1) in 0..1 covering a world AABB, or
    None when it is behind the camera or entirely out of frame."""
    pts = [project(c, pos, target, cam, aspect) for c in _corners(world_box)]
    if any(p[2] <= 0 for p in pts):        # straddles the camera plane
        return None
    x0 = min(p[0] for p in pts) - pad; x1 = max(p[0] for p in pts) + pad
    y0 = min(p[1] for p in pts) - pad; y1 = max(p[1] for p in pts) + pad
    x0, y0 = max(0.0, x0), max(0.0, y0)
    x1, y1 = min(1.0, x1), min(1.0, y1)
    return (x0, y0, x1, y1) if x1 > x0 and y1 > y0 else None


def load(path=LAYOUT):
    return json.loads(pathlib.Path(path).read_text())


def boxes_at(L, t=0.0, names=None, pad=0.0, min_area=0.0):
    """{target name: (x0, y0, x1, y1)} for time t, nearest section last.

    Defaults to the eight section-level targets (no dotted player names) plus
    the conductor — the granularity the prompts are written at.
    """
    pos, target = camera_at(L, t)
    if names is None:
        names = [k for k in L["targets"] if "." not in k]
    out = {}
    for n in names:
        b = box_on_screen(L["targets"][n], pos, target, L["cam"],
                          L["aspect"], pad)
        if b and (b[2] - b[0]) * (b[3] - b[1]) >= min_area:
            out[n] = b
    # Far sections first, so a nearer one's conditioning is applied over it.
    order = {n: _dot(_sub(_centre(L["targets"][n]), pos),
                     _basis(pos, target)[0]) for n in out}
    return {n: out[n] for n in sorted(out, key=lambda k: -order[k])}


# ── overlay, for checking the boxes land where the instruments are ──────────
HUE = {"pizz": (224, 108, 117), "bowed_strings": (198, 120, 221),
       "bass": (209, 154, 102), "finger_piano": (229, 192, 123),
       "marimba": (152, 195, 121), "brass": (97, 175, 239),
       "woodwind": (86, 182, 194), "melody": (171, 178, 191),
       "conductor": (127, 132, 142)}


def overlay(frame_png, out_png, L, t=0.0, pad=0.0):
    from PIL import Image, ImageDraw
    im = Image.open(frame_png).convert("RGB")
    W, H = im.size
    d = ImageDraw.Draw(im)
    for n, (x0, y0, x1, y1) in boxes_at(L, t, pad=pad).items():
        c = HUE.get(n.split(".")[0], (255, 255, 255))
        d.rectangle([x0 * W, y0 * H, x1 * W, y1 * H], outline=c, width=3)
        d.text((x0 * W + 5, y0 * H + 4), n, fill=c)
    im.save(out_png)
    return out_png


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--layout", default=LAYOUT)
    p.add_argument("--time", type=float, default=0.0, help="seconds")
    p.add_argument("--frame", type=int, help="frame number (overrides --time)")
    p.add_argument("--pad", type=float, default=0.0,
                   help="grow every box by this fraction of the frame")
    p.add_argument("--print", action="store_true", dest="show")
    p.add_argument("--overlay", help="frame PNG to draw the boxes on")
    p.add_argument("--out", default="stage_boxes_overlay.png")
    a = p.parse_args()

    L = load(a.layout)
    t = a.frame / FPS if a.frame is not None else a.time
    if a.overlay:
        print("wrote", overlay(a.overlay, a.out, L, t, a.pad))
    if a.show or not a.overlay:
        pos, tgt = camera_at(L, t)
        print(f"t={t:.2f}s  cam={tuple(round(v, 2) for v in pos)} "
              f"-> {tuple(round(v, 2) for v in tgt)}")
        for n, b in boxes_at(L, t, pad=a.pad).items():
            print(f"  {n:16s} x {b[0]:.3f}..{b[2]:.3f}   y {b[1]:.3f}..{b[3]:.3f}")


def _selfcheck():
    L = load(LAYOUT)
    # The wide shot is the authored camera, verbatim.
    pos, tgt = camera_at(L, 0.0)
    assert pos == tuple(L["cam"]["pos"]), pos
    assert tgt == tuple(L["cam"]["target"]), tgt
    # Every section lands somewhere inside the frame, in order back to front.
    b = boxes_at(L, 0.0)
    assert len(b) >= 8, sorted(b)
    for n, r in b.items():
        assert 0.0 <= r[0] < r[2] <= 1.0 and 0.0 <= r[1] < r[3] <= 1.0, (n, r)
    # Stage geography: pizz is left of marimba, the conductor is downstage
    # (lowest in frame) and brass, at the back, sits above the marimba.
    assert b["pizz"][0] < b["marimba"][0], (b["pizz"], b["marimba"])
    assert b["conductor"][3] > b["brass"][3]
    assert b["brass"][1] < b["marimba"][1]
    # A push-in on one section puts the camera closer than the wide shot.
    close, _ = camera_at(L, 26.0 + 8.0)
    assert close[1] > L["cam"]["pos"][1], close
    # Projection round-trip: the look-at point is the centre of the frame.
    x, y, dz = project(tgt, pos, tgt, L["cam"], L["aspect"])
    assert abs(x - 0.5) < 1e-9 and abs(y - 0.5) < 1e-9 and dz > 0
    print("selfcheck ok")


if __name__ == "__main__":
    if "--selfcheck" in sys.argv:
        _selfcheck()
    else:
        main()
