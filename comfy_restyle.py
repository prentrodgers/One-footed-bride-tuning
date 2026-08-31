#!/usr/bin/env python3
"""comfy_restyle.py — push Blender stage frames through ComfyUI img2img.

The Blender render already has what AI video can't: correct instruments and
note-accurate timing driven from the Csound score.  This adds what Blender is
expensive at — photoreal texture and lighting — by restyling each rendered
frame at low denoise, so composition and motion stay exactly where Blender put
them.

    ./comfy_restyle.py --frames stage_frames --out styled_frames --every 30
    ./comfy_restyle.py --frames stage_frames --out styled_frames --denoise 0.45

Then mux as usual:
    ffmpeg -y -framerate 30 -i styled_frames/frame_%06d.png -i <mp3> \
        -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest styled.mp4

ComfyUI runs on fs5 (see llm-scaler-omni-comfyui-fs5.yaml), NodePort 30034.
"""
import argparse, json, pathlib, sys, time, urllib.parse, urllib.request

SERVER = "http://192.168.68.10:30034"
CKPT = "sd_xl_base_1.0.safetensors"

PROMPT = ("professional concert hall photograph, orchestra performing on stage, "
          "warm stage lighting, polished wood instruments, cinematic, "
          "shallow depth of field, 35mm film, highly detailed")
NEGATIVE = ("cartoon, cgi render, plastic, lowres, blurry, watermark, text, "
            "deformed hands, extra limbs")


def workflow(image_name, denoise, seed, prompt, negative, steps=20, cfg=6.5):
    """SDXL img2img graph in ComfyUI's /prompt API format."""
    return {
        "4":  {"class_type": "CheckpointLoaderSimple",
               "inputs": {"ckpt_name": CKPT}},
        "10": {"class_type": "LoadImage",
               "inputs": {"image": image_name, "upload": "image"}},
        "12": {"class_type": "VAEEncode",
               "inputs": {"pixels": ["10", 0], "vae": ["4", 2]}},
        "6":  {"class_type": "CLIPTextEncode",
               "inputs": {"text": prompt, "clip": ["4", 1]}},
        "7":  {"class_type": "CLIPTextEncode",
               "inputs": {"text": negative, "clip": ["4", 1]}},
        "3":  {"class_type": "KSampler",
               "inputs": {"model": ["4", 0], "positive": ["6", 0],
                          "negative": ["7", 0], "latent_image": ["12", 0],
                          "seed": seed, "steps": steps, "cfg": cfg,
                          "sampler_name": "dpmpp_2m", "scheduler": "karras",
                          "denoise": denoise}},
        "8":  {"class_type": "VAEDecode",
               "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        "9":  {"class_type": "SaveImage",
               "inputs": {"images": ["8", 0], "filename_prefix": "restyle"}},
    }


def _post(path, data, headers=None):
    req = urllib.request.Request(SERVER + path, data=data,
                                 headers=headers or {})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.loads(r.read())


def _get(path):
    with urllib.request.urlopen(SERVER + path, timeout=600) as r:
        return r.read()


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
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--frames", default="stage_frames", help="input frame dir")
    p.add_argument("--out", default="styled_frames", help="output frame dir")
    p.add_argument("--every", type=int, default=1,
                   help="restyle every Nth frame (use a big N to preview)")
    p.add_argument("--limit", type=int, help="stop after N frames")
    p.add_argument("--denoise", type=float, default=0.40,
                   help="0.25 keeps Blender almost intact, 0.6 reinvents it")
    p.add_argument("--seed", type=int, default=1234,
                   help="fixed across frames — varying it guarantees flicker")
    p.add_argument("--prompt", default=PROMPT)
    p.add_argument("--negative", default=NEGATIVE)
    a = p.parse_args()

    frames = sorted(pathlib.Path(a.frames).glob("*.png"))[::a.every]
    if a.limit:
        frames = frames[:a.limit]
    if not frames:
        sys.exit(f"no PNGs in {a.frames}")
    out = pathlib.Path(a.out)
    out.mkdir(exist_ok=True)

    t0 = time.time()
    for i, f in enumerate(frames, 1):
        dest = out / f.name
        if dest.exists():
            continue
        png = run(workflow(upload(f), a.denoise, a.seed, a.prompt, a.negative))
        dest.write_bytes(png)
        rate = (time.time() - t0) / i
        print(f"[{i}/{len(frames)}] {f.name}  {rate:.1f}s/frame  "
              f"eta {rate * (len(frames) - i) / 60:.1f}m", flush=True)
    print(f"Done: {out}")


def _selfcheck():
    """Every node input that references another node must name a real node."""
    wf = workflow("x.png", 0.4, 1, "a", "b")
    for nid, node in wf.items():
        for k, v in node["inputs"].items():
            if isinstance(v, list):
                assert v[0] in wf, f"node {nid}.{k} -> missing node {v[0]}"
    assert wf["3"]["inputs"]["denoise"] == 0.4
    print("selfcheck ok")


if __name__ == "__main__":
    if "--selfcheck" in sys.argv:
        _selfcheck()
    else:
        main()
