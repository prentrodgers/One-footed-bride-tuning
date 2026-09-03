#!/usr/bin/env python3
"""temporal_smooth.py — take the shimmer out of a restyled sequence.

A diffusion model re-invents surface texture every frame, so the still parts
of the picture crawl. That noise is independent frame to frame while the
picture underneath is not, which is exactly the case a short temporal filter
fixes: averaging three consecutive frames cancels the noise and leaves the
picture.

The cost is that anything genuinely moving gets smeared, so this offers two
kernels:

    mean    0.25/0.5/0.25 over three frames — strongest noise reduction,
            and a moving edge picks up a half-frame of blur, which at 30fps
            reads as motion blur rather than as error.
    median  per-pixel median of three — leaves moving edges alone (the
            middle value is usually the true one) and still kills the
            frame-to-frame texture crawl, at slightly less smoothing.

    ./temporal_smooth.py --in styled_shot5 --out smoothed --kernel median
"""
import argparse, pathlib, sys


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--in", dest="src", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--kernel", choices=("mean", "median"), default="median")
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--end", type=int, default=10 ** 9)
    a = ap.parse_args()

    from PIL import Image, ImageChops

    def num(p):
        d = "".join(c for c in p.stem if c.isdigit())
        return int(d) if d else -1

    files = [p for p in sorted(pathlib.Path(a.src).glob("*.png"))
             if a.start <= num(p) <= a.end]
    if len(files) < 3:
        sys.exit(f"need at least 3 consecutive frames, found {len(files)}")
    out = pathlib.Path(a.out)
    out.mkdir(parents=True, exist_ok=True)

    # Only smooth where the neighbours really are neighbours: a gap in the
    # numbering means the frames either side are not adjacent in time, and
    # blending them would ghost.
    for i, f in enumerate(files):
        if i == 0 or i == len(files) - 1 or num(files[i + 1]) != num(f) + 1 \
                or num(files[i - 1]) != num(f) - 1:
            Image.open(f).save(out / f.name)
            continue
        prev = Image.open(files[i - 1]).convert("RGB")
        cur = Image.open(f).convert("RGB")
        nxt = Image.open(files[i + 1]).convert("RGB")
        if a.kernel == "mean":
            blend = Image.blend(Image.blend(prev, nxt, 0.5), cur, 0.5)
        else:
            # per-pixel median of three, from lighter/darker: the middle value
            # is max(min(a,b), min(max(a,b), c))
            lo = ImageChops.darker(prev, nxt)
            hi = ImageChops.lighter(prev, nxt)
            blend = ImageChops.lighter(lo, ImageChops.darker(hi, cur))
        blend.save(out / f.name)
    print(f"wrote {len(files)} frames to {out} ({a.kernel})")


if __name__ == "__main__":
    main()
