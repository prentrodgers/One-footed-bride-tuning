#!/usr/bin/env python3
"""comfy_restyle.py — push Blender stage frames through ComfyUI img2img.

The Blender render already has what AI video can't: correct instruments and
note-accurate timing driven from the Csound score.  This adds what Blender is
expensive at — photoreal texture and lighting — by restyling each rendered
frame at low denoise, so composition and motion stay exactly where Blender put
them.

One global prompt is not enough: SDXL sees the marimba's long row of bars and
paints a PIANO, and does much the same to the finger-piano tine racks.  So
every frame is labelled first.  stage_boxes.py projects each section's world
box through the same camera that rendered the frame; the instruments' own
silhouette is cut out of that box; and each silhouette carries its own prompt
("a marimba, one long row of tuned rosewood bars...") through
ConditioningSetMask.  The model is told what it is looking at, region by
region, instead of guessing.

The silhouette matters: --labels box confines a prompt to the plain
rectangle instead, and the empty stage floor inside that rectangle grows a
phantom orchestra out of the dark.  --labels none is the old single-prompt
behaviour, for comparison.

Frames are sampled at --scale (1920x1088 by default) and brought back down.
SDXL is trained near 1024x1024 and a 960x536 Blender frame is far enough
below that to come back soft and vague.

Structure is held by a ControlNet fed the frame's own canny edges (fs5 now
has controlnet-union-sdxl-promax, plus dedicated canny and depth SDXL models,
in the PVC's controlnet dir).  The division of labour is: the masks say what
each thing IS, the edges say where it STAYS, the denoise says how much paint
goes on top.  Without the ControlNet, 0.50 already melts the marimba bars
into blobs and 0.60 turned the whole marimba into a row of bottles.

Two settings matter more than they look:
  --scale     a marimba bar is ~13px wide at 1280 and rounds into an oval
              whatever else you do; at 1920 the bars stay bars.
  --cn-end    stopping the edges early frees the last steps to add texture,
              and they spend it rounding off exactly those thin bars.

Measured on stage_full_bwv257.mp4 frame 90, ControlNet on: 0.50 is barely a
polish, 0.70 gives painted-canvas backdrop and varnished violin wood while
every instrument stays put, 0.85 repaints the backdrop as a wooden wall.  So
0.70 is the default.

Labels earn their keep at that denoise, and their WORDING matters: the bar
colours encode pitch, and while the label said "rosewood bars" the model
dutifully drained them to bone white.  Naming the rainbow brought them back.

Frames can come from a frame directory or straight out of a finished mp4:

    ffmpeg -i ~/Dropbox/Uploads/stage_full_bwv257.mp4 frames257/frame_%06d.png

The frame NUMBER is what picks the camera, so keep ffmpeg's numbering (it is
1-based; frame_000001.png is t=0, half a frame of camera error — harmless).
The cue sheet in stage_layout.json is per-chorale: the dump in this repo is
the bwv257 sheet, and bwv258/259/261 need their own CAMERA_CUES block active
in blender_stage.py when the layout is dumped.

Cost: about 70s/frame at 1920 and 25s at 1280, one B70.  A whole chorale is
9000-odd frames, so a full pass is days, not hours — preview with --every,
and see the note on the second GPU in llm-scaler-omni-comfyui-fs5.yaml.

    ./comfy_restyle.py --frames stage_proto.png --out styled_frames --every 30
    ./comfy_restyle.py --frames stage_proto.png --out styled_frames --denoise 0.45
    ./comfy_restyle.py --frames stage_proto.png --limit 1 --dump-boxes   # check labels
    ./comfy_restyle.py --frames stage_proto.png --limit 1 --labels none  # compare

Then mux as usual:
    ffmpeg -y -framerate 30 -i styled_frames/frame_%06d.png -i <mp3> \
        -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest styled.mp4

ComfyUI runs on fs5 (see llm-scaler-omni-comfyui-fs5.yaml), NodePort 30034.
"""
import argparse, json, pathlib, re, sys, time, urllib.parse, urllib.request

import stage_boxes

SERVER = "http://192.168.68.10:30034"
CKPT = "sd_xl_base_1.0.safetensors"
FPS = 30

PROMPT = ("professional concert hall photograph, orchestra performing on stage, "
          "warm stage lighting, polished wood instruments, cinematic, "
          "shallow depth of field, 35mm film, highly detailed")
NEGATIVE = ("piano, grand piano, upright piano, keyboard, organ, harpsichord, "
            "synthesizer, drum kit, cartoon, cgi render, plastic, lowres, "
            "blurry, watermark, text, deformed hands, extra limbs")

# What each camera target actually IS, in the words the model needs to hear.
# Say only what the thing is: a positive prompt has no "not", and writing
# "not a piano" here puts the piano token straight into the conditioning.
# Keys are the section names in stage_layout.json's targets (blender_stage.py
# --list-targets prints them); anything without an entry stays unlabelled and
# is left to the global prompt.
LABELS = {
    # Bar wording tracks what Blender actually renders: the bars became
    # grained rosewood with only a faint pitch tint (blender_marimba_poc's
    # TINT_STRENGTH), so "rosewood" is now true — while it was false, saying
    # it drained the pitch colours to bone white.
    "marimba": "a marimba, two ranks of tuned rosewood bars faintly tinted "
               "from warm at the low end to cool at the high end, over metal "
               "resonator tubes, struck with yarn mallets",
    "finger_piano": "kalimba thumb pianos, a long pale wooden bench set with "
                    "rows of short upright metal tines in bright pastel "
                    "colours, plucked by the thumbs",
    "bass": "a baritone guitar beside a long bench of upright metal bass "
            "tines coloured violet and pink, deep register",
    "pizz": "a string section playing pizzicato, violins and violas and an "
            "upright double bass, fingers plucking the strings",
    "bowed_strings": "bowed strings, violins violas and cellos with horsehair "
                     "bows drawn across the strings",
    "brass": "a brass section, trumpets a trombone and a tuba, polished "
             "lacquered brass with flaring bells",
    "woodwind": "woodwinds, an oboe a clarinet a bassoon and a french horn",
    "melody": "solo melody instruments, flute oboe clarinet bassoon trumpet "
              "and a vibraphone with pale silver bars on a coloured frame",
    "conductor": "a conductor in black tails on a podium, baton raised",
}

# Appended to every regional prompt so a labelled box is styled like the rest
# of the frame rather than drifting into its own look.
REGION_STYLE = ", concert hall stage lighting, photorealistic, sharp focus"


def _region_nodes(wf, regions, clip_node="4", base_cond="6"):
    """Chain one CLIPTextEncode + a region node per label onto the base
    conditioning, and return the final CONDITIONING id.

    A region carries either a `mask` (an uploaded silhouette — what the
    instruments actually cover) or a `box` (the plain rectangle they sit in).
    A rectangle is the blunter tool: its empty corners are stage floor, and
    telling the model "a string section" over that floor is how a bare box
    grows a phantom orchestra in the dark.
    """
    out = base_cond
    for i, r in enumerate(regions):
        enc, reg, comb = f"1{i:02d}", f"2{i:02d}", f"3{i:02d}"
        wf[enc] = {"class_type": "CLIPTextEncode",
                   "inputs": {"text": r["text"] + REGION_STYLE,
                              "clip": [clip_node, 1]}}
        if r.get("mask"):
            wf[f"4{i:02d}"] = {"class_type": "LoadImageMask",
                               "inputs": {"image": r["mask"], "channel": "red"}}
            wf[reg] = {"class_type": "ConditioningSetMask",
                       "inputs": {"conditioning": [enc, 0],
                                  "mask": [f"4{i:02d}", 0],
                                  "strength": r["strength"],
                                  "set_cond_area": "default"}}
        else:
            x0, y0, x1, y1 = r["box"]
            wf[reg] = {"class_type": "ConditioningSetAreaPercentage",
                       "inputs": {"conditioning": [enc, 0],
                                  "x": round(x0, 3), "y": round(y0, 3),
                                  "width": round(x1 - x0, 3),
                                  "height": round(y1 - y0, 3),
                                  "strength": r["strength"]}}
        wf[comb] = {"class_type": "ConditioningCombine",
                    "inputs": {"conditioning_1": [out, 0],
                               "conditioning_2": [reg, 0]}}
        out = comb
    return out


# ControlNet union models take one extra node naming which hint they are
# being fed; a single-purpose canny or depth model must not get it.
UNION_TYPE = "canny/lineart/anime_lineart/mlsd"


def workflow(image_name, denoise, seed, prompt, negative, regions=(),
             steps=20, cfg=6.5, scale=None, orig=None, control=None,
             prefix="restyle"):
    """SDXL img2img graph in ComfyUI's /prompt API format.

    `scale` is (w, h) to resample the frame to before encoding. SDXL was
    trained around 1024x1024 and gets soft and vague well below that, and a
    Blender frame is 960x536 — so the frames are sampled up into the model's
    own range and brought back down at the end.

    `control` is the ControlNet settings dict (see `--controlnet`). It feeds
    the sampler the frame's own canny edges, which is what stops the marimba
    melting at a denoise high enough to be worth doing: the prompts say what
    each thing IS, the edges say where it STAYS."""
    wf = {
        "4":  {"class_type": "CheckpointLoaderSimple",
               "inputs": {"ckpt_name": CKPT}},
        "10": {"class_type": "LoadImage",
               "inputs": {"image": image_name, "upload": "image"}},
        "12": {"class_type": "VAEEncode",
               "inputs": {"pixels": ["11" if scale else "10", 0],
                          "vae": ["4", 2]}},
        "6":  {"class_type": "CLIPTextEncode",
               "inputs": {"text": prompt, "clip": ["4", 1]}},
        "7":  {"class_type": "CLIPTextEncode",
               "inputs": {"text": negative, "clip": ["4", 1]}},
        "8":  {"class_type": "VAEDecode",
               "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        # The prefix is per-worker. Every ComfyUI instance mounts the SAME
        # CephFS output directory and numbers its files from its own in-memory
        # counter, so two workers both writing restyle_00001_.png will
        # overwrite each other's frame between generation and fetch.
        "9":  {"class_type": "SaveImage",
               "inputs": {"images": ["13" if scale else "8", 0],
                          "filename_prefix": prefix}},
    }
    if scale:
        wf["11"] = {"class_type": "ImageScale",
                    "inputs": {"image": ["10", 0], "width": scale[0],
                               "height": scale[1], "upscale_method": "lanczos",
                               "crop": "disabled"}}
        # Back to the Blender frame size, so styled and raw frames mux
        # interchangeably into the same ffmpeg command.
        wf["13"] = {"class_type": "ImageScale",
                    "inputs": {"image": ["8", 0], "width": orig[0],
                               "height": orig[1], "upscale_method": "lanczos",
                               "crop": "disabled"}}
    positive, negative_id, pos_slot, neg_slot = _region_nodes(wf, regions), "7", 0, 0
    if control:
        src = "11" if scale else "10"
        wf["20"] = {"class_type": "Canny",
                    "inputs": {"image": [src, 0],
                               "low_threshold": control["low"],
                               "high_threshold": control["high"]}}
        wf["21"] = {"class_type": "ControlNetLoader",
                    "inputs": {"control_net_name": control["name"]}}
        cnet = "21"
        if control.get("union"):
            wf["22"] = {"class_type": "SetUnionControlNetType",
                        "inputs": {"control_net": ["21", 0],
                                   "type": control.get("type", UNION_TYPE)}}
            cnet = "22"
        wf["23"] = {"class_type": "ControlNetApplyAdvanced",
                    "inputs": {"positive": [positive, 0],
                               "negative": [negative_id, 0],
                               "control_net": [cnet, 0], "image": ["20", 0],
                               "strength": control["strength"],
                               "start_percent": control["start"],
                               "end_percent": control["end"]}}
        positive = negative_id = "23"
        pos_slot, neg_slot = 0, 1
    wf["3"] = {"class_type": "KSampler",
               "inputs": {"model": ["4", 0], "positive": [positive, pos_slot],
                          "negative": [negative_id, neg_slot],
                          "latent_image": ["12", 0],
                          "seed": seed, "steps": steps, "cfg": cfg,
                          "sampler_name": "dpmpp_2m", "scheduler": "karras",
                          "denoise": denoise}}
    return wf


def png_size(path):
    """(width, height) from the PNG's IHDR — no image library needed."""
    b = pathlib.Path(path).read_bytes()[16:24]
    return int.from_bytes(b[:4], "big"), int.from_bytes(b[4:], "big")


def _frame_no(png):
    """The frame number in frame_000123.png, or -1 if it has none."""
    m = re.search(r"(\d+)", png.stem)
    return int(m.group(1)) if m else -1


def frame_time(png, fps=FPS):
    """Seconds into the clip for frame_000123.png — how the camera, and so
    every box, is looked up. Unnumbered names are treated as t=0."""
    m = re.search(r"(\d+)", png.stem)
    return int(m.group(1)) / fps if m else 0.0


def instrument_mask(png, margin=8, grow=5, blur=2.0):
    """White where the instruments are, black over the empty stage.

    The Blender stage is a flat dark floor with brightly lit instruments on
    it and no alpha to separate them, so the silhouette comes from luminance:
    anything `margin` above the floor's median grey, grown a little to catch
    edges and mallet sticks, then softened so the conditioning has no hard
    seam to draw along.
    """
    from PIL import Image, ImageFilter, ImageStat
    im = Image.open(png).convert("L")
    floor = ImageStat.Stat(im).median[0]
    m = im.point(lambda v: 255 if v > floor + margin else 0)
    if grow:
        m = m.filter(ImageFilter.MaxFilter(2 * grow + 1))
    return m.filter(ImageFilter.GaussianBlur(blur)) if blur else m


def _mask_for(mask, box, size, path):
    """The silhouette, cropped to one section's rectangle, as a PNG the size
    the sampler runs at. Written to `path`; returns it."""
    from PIL import Image
    W, H = mask.size
    out = Image.new("L", mask.size, 0)
    r = (int(box[0] * W), int(box[1] * H), int(box[2] * W), int(box[3] * H))
    out.paste(mask.crop(r), r[:2])
    out.resize(size, Image.LANCZOS).convert("RGB").save(path)
    return path


def regions_for(layout, t, pad, strength, min_area,
                frame=None, size=None, mask_dir=None):
    """The labelled regions visible at time t.

    With `frame` (and a mask_dir to write into) each region is cut to the
    instruments' own silhouette; without one it stays a rectangle.
    """
    boxes = stage_boxes.boxes_at(layout, t, pad=pad, min_area=min_area)
    named = [(n, b) for n, b in boxes.items() if n in LABELS]
    sil = instrument_mask(frame) if frame else None
    out = []
    for n, b in named:
        r = {"text": LABELS[n], "box": b, "strength": strength}
        if sil is not None:
            # Named per FRAME as well as per section: the workers share one
            # ComfyUI input directory, so a bare mask_marimba.png from worker
            # A would be overwritten by worker B's before A's job ran.
            r["mask"] = _mask_for(sil, b, size or sil.size,
                                  pathlib.Path(mask_dir) /
                                  f"mask_{frame.stem}_{n}.png")
        out.append(r)
    return out


def _post(path, data, headers=None):
    req = urllib.request.Request(SERVER + path, data=data,
                                 headers=headers or {})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.loads(r.read())


def _get(path):
    with urllib.request.urlopen(SERVER + path, timeout=600) as r:
        return r.read()


def controlnets_available():
    """The ControlNet files the server will actually load, asked of it rather
    than assumed — the models live on fs5's PVC, not in this repo."""
    d = json.loads(_get("/object_info/ControlNetLoader"))
    return list(d["ControlNetLoader"]["input"]["required"]["control_net_name"][0])


def pick_controlnet(want="auto"):
    """Resolve --controlnet to a filename on the server, or None."""
    if want in ("none", "off", ""):
        return None
    have = controlnets_available()
    if want != "auto":
        if want not in have:
            sys.exit(f"no such ControlNet on the server: {want}\nhave: {have}")
        return want
    if not have:
        return None
    # A union model covers canny and depth both, so prefer it; otherwise take
    # whatever canny model is installed.
    for key in ("union", "canny"):
        for n in have:
            if key in n.lower():
                return n
    return None


def upload(png):
    """POST an image to ComfyUI's input dir; returns the name LoadImage wants."""
    b = b"----comfy"
    body = (b"--" + b + b"\r\nContent-Disposition: form-data; name=\"image\"; "
            b"filename=\"" + png.name.encode() + b"\"\r\n"
            b"Content-Type: image/png\r\n\r\n" + png.read_bytes() +
            b"\r\n--" + b + b"\r\nContent-Disposition: form-data; "
            b"name=\"overwrite\"\r\n\r\ntrue\r\n--" + b + b"--\r\n")
    r = _post("/upload/image", body,
              {"Content-Type": b"multipart/form-data; boundary=" + b})
    return f"{r['subfolder']}/{r['name']}" if r.get("subfolder") else r["name"]


def run(wf):
    """Queue a workflow, wait for it, return the output PNG bytes."""
    pid = _post("/prompt", json.dumps({"prompt": wf}).encode(),
                {"Content-Type": "application/json"})["prompt_id"]
    while True:
        hist = json.loads(_get(f"/history/{pid}"))
        if pid in hist:
            status = hist[pid].get("status", {})
            if status.get("status_str") == "error":
                raise RuntimeError(json.dumps(status)[:2000])
            img = hist[pid]["outputs"]["9"]["images"][0]
            return _get("/view?" + urllib.parse.urlencode(
                {"filename": img["filename"], "subfolder": img["subfolder"],
                 "type": img["type"]}))
        time.sleep(1)


def main():
    global SERVER
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--frames", default="stage_proto.png", help="input frame dir")
    p.add_argument("--server", default=SERVER,
                   help="ComfyUI base URL; one worker per GPU (see comfy_farm.sh)")
    p.add_argument("--frame-start", type=int,
                   help="first frame NUMBER to restyle (from the filename)")
    p.add_argument("--frame-end", type=int, help="last frame number, inclusive")
    p.add_argument("--prefix", default="restyle",
                   help="SaveImage prefix; must differ per worker, since they "
                        "share one output directory")
    p.add_argument("--out", default="styled_frames", help="output frame dir")
    p.add_argument("--every", type=int, default=1,
                   help="restyle every Nth frame (use a big N to preview)")
    p.add_argument("--limit", type=int, help="stop after N frames")
    p.add_argument("--denoise", type=float, default=0.70,
                   help="how far from the Blender frame the sampler may go. "
                        "With the ControlNet holding structure, 0.70 is where "
                        "the paint actually arrives and 0.85 is too far — it "
                        "turns the backdrop into a wooden wall. Without the "
                        "ControlNet, 0.50 already melts the marimba bars")
    p.add_argument("--steps", type=int, default=20)
    p.add_argument("--seed", type=int, default=1234,
                   help="fixed across frames — varying it guarantees flicker")
    p.add_argument("--prompt", default=PROMPT)
    p.add_argument("--negative", default=NEGATIVE)
    # ── instrument labelling ────────────────────────────────────────────────
    p.add_argument("--layout", default=stage_boxes.LAYOUT,
                   help="stage_layout.json, the source of the section boxes")
    p.add_argument("--labels", choices=("mask", "box", "none"), default="mask",
                   help="mask: each section's prompt is confined to the "
                        "instruments' own silhouette; box: to its rectangle, "
                        "whose empty floor grows phantom players; none: one "
                        "global prompt, the way the marimba became a piano")
    p.add_argument("--no-labels", action="store_true",
                   help="shorthand for --labels none")
    p.add_argument("--fps", type=int, default=FPS,
                   help="frame number -> time, to follow the camera cues")
    p.add_argument("--mask-margin", type=int, default=8,
                   help="how far above the floor's grey counts as instrument")
    p.add_argument("--mask-grow", type=int, default=5,
                   help="pixels to grow the silhouette by, to catch edges")
    p.add_argument("--pad", type=float, default=0.01,
                   help="grow every box by this fraction of the frame")
    p.add_argument("--region-strength", type=float, default=0.7,
                   help="weight of a regional prompt against the global "
                        "one; the boxes overlap, so >1 stacks guidance and "
                        "smears the stage")
    p.add_argument("--min-area", type=float, default=0.004,
                   help="skip boxes smaller than this fraction of the frame")
    p.add_argument("--scale", default="1920x1088",
                   help="resample to WxH for sampling. SDXL goes soft below "
                        "its ~1024x1024 training size, and a marimba bar is "
                        "only ~13px wide at 1280 — too thin to survive as a "
                        "bar. 1280x720 is ~2.5x faster if you need it; "
                        "'none' samples at the frame's own size")
    # ── structure lock ──────────────────────────────────────────────────────
    p.add_argument("--controlnet", default="auto",
                   help="ControlNet file on the server, 'auto' for the best "
                        "installed one, or 'none'")
    p.add_argument("--cn-strength", type=float, default=1.0,
                   help="how hard the edges hold the geometry")
    p.add_argument("--cn-start", type=float, default=0.0)
    p.add_argument("--cn-end", type=float, default=1.0,
                   help="below 1.0 the last steps run free of the edges, "
                        "which adds texture but rounds thin bars into blobs")
    p.add_argument("--cn-type", default=UNION_TYPE,
                   help="which hint a union ControlNet is being given")
    p.add_argument("--canny-low", type=float, default=0.1)
    p.add_argument("--canny-high", type=float, default=0.3,
                   help="Blender's flat shading gives weak edges; lower "
                        "thresholds than the node's defaults catch them")
    p.add_argument("--dump-boxes", action="store_true",
                   help="also write frame_NNNNNN.boxes.png showing the labels")
    a = p.parse_args()

    SERVER = a.server.rstrip("/")

    frames = sorted(pathlib.Path(a.frames).glob("*.png"))
    if a.frame_start is not None or a.frame_end is not None:
        lo = a.frame_start if a.frame_start is not None else -1
        hi = a.frame_end if a.frame_end is not None else 10 ** 9
        frames = [f for f in frames if lo <= _frame_no(f) <= hi]
    frames = frames[::a.every]
    if a.limit:
        frames = frames[:a.limit]
    if not frames:
        sys.exit(f"no PNGs in {a.frames}")
    out = pathlib.Path(a.out)
    out.mkdir(exist_ok=True)

    scale = None
    if a.scale.lower() not in ("none", "0", ""):
        scale = tuple(int(v) for v in a.scale.lower().split("x"))
    cn = pick_controlnet(a.controlnet)
    control = cn and {"name": cn, "union": "union" in cn.lower(),
                      "type": a.cn_type, "strength": a.cn_strength,
                      "start": a.cn_start, "end": a.cn_end,
                      "low": a.canny_low, "high": a.canny_high}
    print(f"controlnet: {cn or 'none — geometry is only held by the denoise'}")
    mode = "none" if a.no_labels else a.labels
    layout = None if mode == "none" else stage_boxes.load(a.layout)
    masks = out / "masks" if mode == "mask" else None
    if masks:
        masks.mkdir(exist_ok=True)
    if layout:
        n = len(stage_boxes.boxes_at(layout, frame_time(frames[0], a.fps),
                                     pad=a.pad, min_area=a.min_area))
        print(f"labelling {n} sections per frame ({mode}) from {a.layout}")

    t0 = time.time()
    for i, f in enumerate(frames, 1):
        dest = out / f.name
        if dest.exists():
            continue
        t = frame_time(f, a.fps)
        regions = ()
        if layout:
            regions = regions_for(layout, t, a.pad, a.region_strength,
                                  a.min_area, frame=f if masks else None,
                                  size=scale or png_size(f), mask_dir=masks)
            for r in regions:            # the mask has to be on the server too
                if r.get("mask"):
                    r["mask"] = upload(pathlib.Path(r["mask"]))
        if a.dump_boxes and layout:
            stage_boxes.overlay(f, out / f"{f.stem}.boxes.png", layout, t, a.pad)
        png = run(workflow(upload(f), a.denoise, a.seed, a.prompt, a.negative,
                           regions, steps=a.steps, scale=scale,
                           orig=png_size(f), control=control, prefix=a.prefix))
        dest.write_bytes(png)
        rate = (time.time() - t0) / i
        print(f"[{i}/{len(frames)}] {f.name}  {rate:.1f}s/frame  "
              f"eta {rate * (len(frames) - i) / 60:.1f}m", flush=True)
    print(f"Done: {out}")


def _selfcheck():
    """Every node input that references another node must name a real node."""
    layout = stage_boxes.load(stage_boxes.LAYOUT)
    regions = regions_for(layout, 0.0, 0.01, 0.7, 0.004)
    assert len(regions) >= 8, len(regions)
    wf = workflow("x.png", 0.4, 1, "a", "b", regions)
    for nid, node in wf.items():
        for k, v in node["inputs"].items():
            if isinstance(v, list):
                assert v[0] in wf, f"node {nid}.{k} -> missing node {v[0]}"
    assert wf["3"]["inputs"]["denoise"] == 0.4
    # Sampling upscaled: encode reads the upscale, save reads the way back.
    up = workflow("x.png", 0.4, 1, "a", "b", scale=(1280, 720), orig=(960, 536))
    assert up["12"]["inputs"]["pixels"] == ["11", 0]
    assert up["9"]["inputs"]["images"] == ["13", 0]
    assert up["13"]["inputs"]["width"] == 960
    for nid, node in up.items():
        for k, v in node["inputs"].items():
            if isinstance(v, list):
                assert v[0] in up, f"node {nid}.{k} -> missing node {v[0]}"
    assert png_size("stage_proto.png/frame_000000.png") == (960, 540)
    # The sampler must read the END of the region chain, not the bare prompt.
    assert wf["3"]["inputs"]["positive"][0] != "6"
    # Every area stays inside the frame, and the marimba is one of them.
    texts = []
    for node in wf.values():
        if node["class_type"] == "ConditioningSetAreaPercentage":
            n = node["inputs"]
            assert 0 <= n["x"] and n["x"] + n["width"] <= 1.0, n
            assert 0 <= n["y"] and n["y"] + n["height"] <= 1.0, n
            texts.append(wf[node["inputs"]["conditioning"][0]]["inputs"]["text"])
    assert any("marimba" in t for t in texts), texts
    assert not any(" not " in t for t in texts), "no negation in a positive prompt"
    # Mask mode: every label is a silhouette the server can load, and the
    # silhouette really is mostly empty — instruments, not a filled rectangle.
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        frame = pathlib.Path("stage_proto.png/frame_000000.png")
        masked = regions_for(layout, 0.0, 0.01, 0.7, 0.004, frame=frame,
                             size=(1280, 720), mask_dir=d)
        mwf = workflow("x.png", 0.4, 1, "a", "b", masked)
        for nid, node in mwf.items():
            for k, v in node["inputs"].items():
                if isinstance(v, list):
                    assert v[0] in mwf, f"node {nid}.{k} -> missing {v[0]}"
        assert any(n["class_type"] == "ConditioningSetMask"
                   for n in mwf.values())
        assert all(pathlib.Path(r["mask"]).exists() for r in masked)
        from PIL import Image, ImageStat
        cover = [ImageStat.Stat(Image.open(r["mask"]).convert("L")).mean[0] / 255
                 for r in masked]
        assert 0 < max(cover) < 0.25, cover      # silhouettes, not rectangles
    # ControlNet: the sampler takes both conditionings from the apply node,
    # positive off slot 0 and negative off slot 1, and the edges are taken
    # from the UPSCALED frame so hint and latent are the same shape.
    ctl = {"name": "u.safetensors", "union": True, "type": "depth",
           "strength": 0.8, "start": 0.0, "end": 0.8, "low": 0.2, "high": 0.5}
    cwf = workflow("x.png", 0.4, 1, "a", "b", regions, scale=(1280, 720),
                   orig=(960, 536), control=ctl)
    assert cwf["3"]["inputs"]["positive"] == ["23", 0]
    assert cwf["3"]["inputs"]["negative"] == ["23", 1]
    assert cwf["23"]["inputs"]["control_net"] == ["22", 0]
    assert cwf["22"]["inputs"]["type"] == "depth"
    assert cwf["20"]["inputs"]["image"] == ["11", 0]
    for nid, node in cwf.items():
        for k, v in node["inputs"].items():
            if isinstance(v, list):
                assert v[0] in cwf, f"node {nid}.{k} -> missing node {v[0]}"
    # A single-purpose model gets no union node.
    plain_cn = dict(ctl, name="canny.safetensors", union=False)
    pwf = workflow("x.png", 0.4, 1, "a", "b", control=plain_cn)
    assert "22" not in pwf and pwf["23"]["inputs"]["control_net"] == ["21", 0]
    assert pwf["20"]["inputs"]["image"] == ["10", 0]
    # No labels -> the old single-prompt graph, sampler straight off node 6.
    assert workflow("x.png", 0.4, 1, "a", "b")["3"]["inputs"]["positive"] == ["6", 0]
    # Frame number drives the camera clock.
    assert frame_time(pathlib.Path("frame_000090.png"), 30) == 3.0
    print("selfcheck ok")


if __name__ == "__main__":
    if "--selfcheck" in sys.argv:
        _selfcheck()
    else:
        main()
