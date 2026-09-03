#!/usr/bin/env python3
"""flicker_check.py — does a restyled sequence shimmer against itself?

The thing that decides whether an AI restyle is usable for video is not how
good one frame looks: it is whether consecutive frames agree. A diffusion
model re-imagines texture every frame, and the eye reads that as boiling.

Comparing raw frame-to-frame difference tells you little, because a moving
camera changes every pixel too. Comparing medians does not work either: a
CGI render holds most pixels EXACTLY still, so its median change is 0.00 and
every ratio against it is meaningless.

So the source is used as the referee. For each consecutive pair, the pixels
the render left untouched are the ones that ought to be untouched in the
styled version too:

    still mask   pixels where the source changed by <= 1 level
    flicker      mean |change| of the STYLED sequence inside that mask
    motion       mean |change| of the styled sequence outside it, for scale

Flicker is in grey levels out of 255. Under about 2 the eye reads it as
grain; by 5 it boils.

    ./flicker_check.py --a stage_frames_v3 --b styled_shot5 --start 1665 --end 1973
"""
import argparse, pathlib, statistics, sys


def frames(d, lo, hi):
    out = []
    for f in sorted(pathlib.Path(d).glob("*.png")):
        n = "".join(c for c in f.stem if c.isdigit())
        if n and lo <= int(n) <= hi:
            out.append(f)
    return out


def compare(src, sty, step=1, still=1):
    """Per consecutive pair: (flicker, motion, still %) — the styled
    sequence's change inside and outside the source's still mask."""
    from PIL import Image, ImageChops, ImageStat
    rows = []
    pa = pb = None
    for a, b in list(zip(src, sty))[::step]:
        ia, ib = Image.open(a).convert("L"), Image.open(b).convert("L")
        if pa is not None:
            d_src = ImageChops.difference(ia, pa)
            d_sty = ImageChops.difference(ib, pb)
            still_mask = d_src.point(lambda v: 255 if v <= still else 0)
            moved_mask = d_src.point(lambda v: 0 if v <= still else 255)
            frac = ImageStat.Stat(still_mask).mean[0] / 255.0
            f = ImageStat.Stat(d_sty, mask=still_mask).mean[0] if frac > 0.01 else 0.0
            m = ImageStat.Stat(d_sty, mask=moved_mask).mean[0] if frac < 0.99 else 0.0
            rows.append((f, m, frac))
        pa, pb = ia, ib
    return rows


def summarise(name, rows):
    if not rows:
        return None
    f = statistics.mean(r[0] for r in rows)
    m = statistics.mean(r[1] for r in rows)
    s = statistics.mean(r[2] for r in rows)
    print(f"  {name:22s} flicker {f:6.2f}   motion {m:6.2f}   "
          f"still {100*s:4.1f}% of frame   ({len(rows)} pairs)")
    return f, m, s


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--a", required=True, help="source frame dir")
    ap.add_argument("--b", required=True, help="styled frame dir")
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--end", type=int, default=10 ** 9)
    ap.add_argument("--step", type=int, default=1)
    args = ap.parse_args()

    fa, fb = frames(args.a, args.start, args.end), frames(args.b, args.start, args.end)
    have = {p.name for p in fa} & {p.name for p in fb}
    fa = [p for p in fa if p.name in have]
    fb = [p for p in fb if p.name in have]
    if len(fa) < 2:
        sys.exit(f"need at least 2 frames present in both dirs (found {len(fa)})")
    print(f"comparing {len(fa)} frames present in both\n")
    ref = summarise("source vs itself", compare(fa, fa, args.step))
    got = summarise("styled", compare(fa, fb, args.step))
    if got:
        print()
        f = got[0]
        print("  verdict:", "steady — cuts as video" if f < 2 else
              "visible shimmer in still areas" if f < 5 else
              "boiling — not usable frame by frame")
        print(f"  (source's own flicker in the same mask: {ref[0]:.2f} — "
              f"that is the floor)")


if __name__ == "__main__":
    main()
