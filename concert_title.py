#!/usr/bin/env python3
"""
concert_title.py - write the title card for a concert-stage video: Uploads/<piece>.title.txt.

concert_stage.py (and the Blender preview) show that file on the backdrop for the first and last
8 seconds. The text is score_video.py's title card: the chorale, the credits, and chord_report.py's
summary of the tuning that was rendered.

    python concert_title.py Uploads/b425f_df5_t2_d08_00_t096_ap3_lm19_r1.50

The chorale and its tuning come from the piece's name: b425f..._t2_..._lm19_r1.50 is bwv425 tuned with
Archive/straw-man/best-tunings/bwv425_t2_r1.500_lm19-opt.npy. Override with --chorale / --tuning.
The rest of the name goes on the hyperparameters line: b392g_df5_t3_d04_05_t104_ap3_... adds
"density 5, duration 4:05, tempo 104, rhythm set ap 3".
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


# The Well-Tempered Clavier (Scores/bwv846f etc.): the heading names the piece, not a chorale
WTC = {846: ("C major", 1), 847: ("C minor", 2), 848: ("C-sharp major", 3), 849: ("C-sharp minor", 4),
       850: ("D major", 5), 851: ("D minor", 6), 852: ("E-flat major", 7), 853: ("E-flat minor", 8),
       854: ("E major", 9), 855: ("E minor", 10), 856: ("F major", 11), 857: ("F minor", 12),
       858: ("F-sharp major", 13), 859: ("F-sharp minor", 14), 860: ("G major", 15), 861: ("G minor", 16),
       862: ("A-flat major", 17), 863: ("G-sharp minor", 18), 864: ("A major", 19), 865: ("A minor", 20),
       866: ("B-flat major", 21), 867: ("B-flat minor", 22), 868: ("B major", 23), 869: ("B minor", 24)}
VENUE = "Teatro Buero Vallejo, Alcorcon (Madrid): the hall's impulse response measured by Angelo Farina"


def heading_for(chorale):
    m = re.match(r"bwv(\d+)([pf])?$", chorale)
    if m and int(m.group(1)) in WTC and m.group(2):
        key, n = WTC[int(m.group(1))]
        kind = "Prelude" if m.group(2) == "p" else "Fugue"
        return f"J. S. Bach, The Well-Tempered Clavier I: {kind} No. {n} in {key}, BWV {m.group(1)}"
    return HEADING.format(chorale=chorale.upper())


def temperament_lines(name):
    """The body lines for a fixed temperament (WreckingCrew_v2 --temperament): its pitch classes in cents."""
    import WreckingCrew_v2 as wc2
    cents = wc2.TEMPERAMENTS[name]
    names = ("C", "C#", "D", "Eb", "E", "F", "F#", "G", "G#", "A", "Bb", "B")
    pretty = name.replace("_", " ").replace("werckmeister", "Werckmeister")
    text = f"Tuning: {pretty}, cents above C: " + ", ".join(f"{n} {c:g}" for n, c in zip(names, cents))
    return [("body", ln) for ln in textwrap.wrap(text, WRAP)]


def temperament_in(stem):
    """The temperament a piece name carries (b846ft_werck3_...), or None."""
    import WreckingCrew_v2 as wc2
    name = os.path.basename(stem)
    for temperament, tag in wc2.TEMPERAMENT_TAGS.items():
        if f"_{tag}_" in name or name.endswith(f"_{tag}"):
            return temperament
    return None


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


def piece_details(stem):
    """The rendering choices in a piece's name, worded as on the title cards:
    b392g_df5_t3_d04_05_t104_ap3_lm19_r1.25 -> "density 5, duration 4:05, tempo 104, rhythm set ap 3"."""
    name = os.path.basename(stem)
    parts = []
    m = re.search(r"_df(\d+)", name)
    if m:
        parts.append(f"density {m.group(1)}")
    m = re.search(r"_d(\d+)_(\d\d)(?=_)", name)
    if m:
        parts.append(f"duration {int(m.group(1))}:{m.group(2)}")
    m = re.search(r"_t(\d{2,3})(?=_|$)", name)          # tempo; the tolerance is the one-digit _t3_
    if m:
        parts.append(f"tempo {int(m.group(1))}")
    m = re.search(r"_ap(\d+)", name)
    if m:
        parts.append(f"rhythm set ap {m.group(1)}")
    return ", ".join(parts)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    ap.add_argument("piece", help="Uploads/<piece> (with or without .npy)")
    ap.add_argument("--chorale", default=None, help="e.g. bwv425")
    ap.add_argument("--tuning", default=None, help="the -opt.npy that was rendered")
    ap.add_argument("--out", default=None, help="default: <piece>.title.txt")
    args = ap.parse_args()
    stem = args.piece[:-4] if args.piece.endswith(".npy") else args.piece
    temperament = temperament_in(stem)
    if temperament or (args.tuning and "/" not in args.tuning and not args.tuning.endswith(".npy")):
        # a fixed temperament: no chord report; the card names the piece, the temperament and the hall
        temperament = args.tuning or temperament
        name = os.path.basename(stem)
        m = re.match(r"b(\d+)([pf]?)[a-z]?_", name)
        chorale = args.chorale or (f"bwv{m.group(1)}{m.group(2)}" if m else None)
        if not chorale:
            raise SystemExit(f"can't read the piece from {name!r}; give --chorale")
        out = [("big", heading_for(chorale)), ("mid", BY.replace("Extended", "Realised")), ("mid", CREDIT)]
        out += temperament_lines(temperament)
        extra = piece_details(stem)
        if extra:
            out.append(("body", "Rendered by WreckingCrew_v2 note for note from the score, " + extra))
        out += [("body", ln) for ln in textwrap.wrap(VENUE, WRAP)]
        path = args.out or stem + ".title.txt"
        with open(path, "w", encoding="utf-8") as f:
            f.write("".join(f"{s}\t{t}\n" for s, t in out))
        print(f"{path}: {chorale}, {temperament}")
        for s, t in out:
            print(f"  {s:5} {t}")
        return
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
    extra = piece_details(stem)
    if extra:                                           # the hyperparameters line, then how it was rendered
        out = [(s, t + ", " + extra if t.lstrip().startswith("Hyperparameters:") else t) for s, t in out]
    path = args.out or stem + ".title.txt"
    with open(path, "w", encoding="utf-8") as f:
        f.write("".join(f"{s}\t{t}\n" for s, t in out))
    print(f"{path}: {chorale}, {os.path.basename(tuning)}")
    for s, t in out:
        print(f"  {s:5} {t}")


if __name__ == "__main__":
    main()
