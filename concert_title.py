#!/usr/bin/env python3
"""
concert_title.py - write the title card for a concert-stage video: Uploads/<piece>.title.txt.

concert_stage.py (and the Blender preview) show that file on the backdrop for the first and last
8 seconds. The text is score_video.py's title card: the chorale, the credits, and chord_report.py's
summary of the tuning that was rendered.

    python concert_title.py Uploads/b425f_df5_t2_d08_00_t096_ap3_lm19_r1.50

The chorale and its tuning come from the piece's name: b425f..._t2_..._lm19_r1.50 is bwv425 tuned with
Archive/straw-man/best-tunings/bwv425_t2_r1.500_lm19-opt.npy. Override with --chorale / --tuning.
Needs chord_report.py's and score_video.py's modules (numpy, music21, Pillow): run it on
one-footed-bride-pod, then copy the .title.txt to the other repo copies.

File format: one line per text line, "style<TAB>text", style big / mid / body.
"""
import argparse
import glob
import os
import re
import subprocess
import sys
import tempfile
import textwrap

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
BEST = os.path.join(HERE, "Archive", "straw-man", "best-tunings")
# the concert videos' own wording for score_video.py's first three lines
HEADING = "Chorale Prelude based on Bach Chorale {chorale}"
BY = "Extended by Prent Rodgers"
CREDIT = "with considerable help from Claude Code Opus"
WRAP = 84                # about as wide as the tuning-information lines


def tuning_for(stem):
    """(chorale, path of the -opt.npy) for a piece name like b425f_df5_t2_..._lm19_r1.50."""
    name = os.path.basename(stem)
    m = re.match(r"b(\d+)[a-z]?_", name)
    t, lm, r = (re.search(p, name) for p in (r"_t(\d)_", r"_lm(\d+)", r"_r([\d.]+)$"))
    if not (m and t and lm and r):
        raise SystemExit(f"can't read the chorale and tuning from {name!r}; give --chorale and --tuning")
    chorale = f"bwv{m.group(1)}"
    cands = glob.glob(os.path.join(BEST, f"{chorale}_t{t.group(1)}_r*_lm{lm.group(1)}-opt.npy"))
    if not cands:
        raise SystemExit(f"no tuning for {chorale} t{t.group(1)} lm{lm.group(1)} in {BEST}")

    def ratio(p):                     # the piece name rounds the ratio factor: r1.38 is r1.375
        return float(re.search(r"_r([\d.]+)_lm", p).group(1))
    return chorale, min(cands, key=lambda p: abs(ratio(p) - float(r.group(1))))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    ap.add_argument("piece", help="Uploads/<piece> (with or without .npy)")
    ap.add_argument("--chorale", default=None, help="e.g. bwv425")
    ap.add_argument("--tuning", default=None, help="the -opt.npy that was rendered")
    ap.add_argument("--out", default=None, help="default: <piece>.title.txt")
    args = ap.parse_args()
    stem = args.piece[:-4] if args.piece.endswith(".npy") else args.piece
    chorale, tuning = (args.chorale, args.tuning) if args.chorale and args.tuning else tuning_for(stem)
    chorale, tuning = args.chorale or chorale, args.tuning or tuning

    import score_video as sv
    with tempfile.NamedTemporaryFile("w+", suffix=".txt", delete=False, encoding="utf-8") as f:
        subprocess.run([sys.executable, os.path.join(HERE, "chord_report.py"), "--input_numpy_file", tuning],
                       stdout=f, check=True, cwd=HERE)
    try:
        _, header, _ = sv.parse_report(f.name)
    finally:
        os.unlink(f.name)

    out = []
    for text, style in sv.title_text(chorale, header):
        if text.startswith("Bach Chorale"):
            text = HEADING.format(chorale=chorale.upper())
        elif text.startswith("Tuned by"):
            text = BY
        elif text.startswith("with considerable help"):
            text = CREDIT
        if style == "wrap":
            out += [("body", ln) for ln in textwrap.wrap(text, WRAP)]
        else:
            out.append((style, text))
    path = args.out or stem + ".title.txt"
    with open(path, "w", encoding="utf-8") as f:
        f.write("".join(f"{s}\t{t}\n" for s, t in out))
    print(f"{path}: {chorale}, {os.path.basename(tuning)}")
    for s, t in out:
        print(f"  {s:5} {t}")


if __name__ == "__main__":
    main()
