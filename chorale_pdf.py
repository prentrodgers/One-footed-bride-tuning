#!/usr/bin/env python3
"""Engrave a Bach chorale from music21's corpus as a compact PDF score.

    python chorale_pdf.py bwv267                 -> Chorale-pdf/bwv267.pdf
    python chorale_pdf.py bwv265 bwv266 bwv267   -> one PDF each
    python chorale_pdf.py path/to/score.mxl      -> Chorale-pdf/score.pdf

Anything music21 can parse works as input: a corpus name such as bwv267
(looked up under bach/), or a path to a MusicXML, .mxl, MIDI or .krn file.

The four voices go on four staves linked by a choir bracket, engraved small
and packed tightly (staff size, margins and system spacing are all set
below) so a chorale fits on one page, with about a staff's height of air
between staves and about three between systems.  Every measure carries
its number, counting from 0 at the first measure (pickup or not) rather
than the engraver's 1; with a pickup that is exactly music21's own measure
numbering.  The corpus's phrase seams, a bar line mid-measure with the
next pickup after it, are joined so each numbered measure is drawn as
one.  Lyrics are left out unless asked for, since the words roughly
double a system's height.

LilyPond does the engraving: music21 writes the LilyPond source, this
script adds the compaction and runs `lilypond`, which must be on PATH
(Fedora: dnf install lilypond).  The title block carries the BWV number,
the chorale's own title from the corpus metadata when it has one, and the
composer.

Options:
    --include-lyrics  keep the hymn text (the corpus carries it under the soprano)
    --staff-size N    LilyPond global staff size (default 15; LilyPond's own
                      default is 20)
    --out_dir DIR     where the PDFs go (default: Chorale-pdf, created if absent)
    --paper SIZE      letter (default) or a4
    --keep_ly         also keep the LilyPond source next to the PDF
    --force           re-engrave even if the PDF already exists
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

from music21 import corpus, converter, layout, metadata
from music21.lily import translate as lily_translate


def load(name_or_path: str):
    """A music21 score for a corpus name (bwv267 or bach/bwv267) or a file."""
    p = Path(name_or_path)
    if p.suffix and p.exists():
        return converter.parse(p), p.stem
    name = name_or_path if "/" in name_or_path else f"bach/{name_or_path}"
    try:
        return corpus.parse(name), Path(name).name
    except Exception as exc:   # music21 raises several types for a bad name
        sys.exit(f"{name_or_path}: not a file and not in music21's corpus ({exc})")


def title_block(score, stem: str) -> None:
    """Fill the metadata LilyPond prints at the top of the page."""
    if score.metadata is None:
        score.metadata = metadata.Metadata()
    md = score.metadata
    own = (md.title or "").strip()
    bwv = stem.upper().replace("BWV", "BWV ") if stem.lower().startswith("bwv") else stem
    md.title = f"{bwv}  {own}" if own and own.lower() != stem.lower() else bwv
    if not md.composer:
        md.composer = "J. S. Bach"


def strip_layout(score) -> None:
    """Drop the corpus's own system and page breaks so LilyPond breaks lines
    to fit the compact staff size; left in, they force a new page after two
    short systems."""
    for lo in list(score.recurse().getElementsByClass(layout.LayoutBase)):
        lo.activeSite.remove(lo)


def strip_lyrics(score) -> None:
    for n in score.recurse().notesAndRests:
        if n.lyrics:
            n.lyrics = []


# A bar line music21 wrote INSIDE a measure, followed by the partial that
# starts the next phrase's pickup: the corpus's phrase seam.
_SEAM = re.compile(r'\\bar\s*"[^"]*"\s*%\{ end measure \d+ %\}\s*\\partial\s+\S+\s*')


def join_split_measures(text: str) -> str:
    """Draw each measure whole across the corpus's phrase seams.

    The corpus ends a phrase with a bar line (often a double one) after,
    say, the third beat and starts the next phrase's pickup in the same
    measure.  music21 writes that as a \\bar plus a mid-piece \\partial, and
    LilyPond then engraves the one measure as two.  Removing the pair (in
    every staff) lets the pickup finish the measure it belongs to; the
    fermata still marks the phrase end.  The opening pickup has no bar
    line before it, so it is untouched."""
    return _SEAM.sub("", text)


_BAR = re.compile(r'\\bar\s*"[^"]*"\s*%\{ end measure (\d+) %\}')


def number_measures(text: str) -> str:
    """Print music21's measure number over every measure.

    LilyPond's own count cannot be trusted here: the corpus breaks a chorale
    into phrases, each closing with a final bar line on a short measure and
    opening the next with a pickup, and music21 writes every one of those as
    a mid-piece \\partial.  LilyPond then skips the short measure and never
    numbers the pickup, so its numbers drift from music21's (0 for the first
    pickup, then every measure counted) after each phrase.  music21 marks
    each bar line with an "end measure N" comment, so the number of the
    measure starting at every bar line is set explicitly from those, in the
    first staff (the property is Score-wide).  A pickup's number prints in
    parentheses, LilyPond's mark for a partial measure."""
    m_first = re.search(r'\\new Staff\s*=\s*\S+\s*\\with\s*\{[^}]*\}\s*\{', text)
    if not m_first:
        return text
    m_second = re.search(r'\\new Staff\s*=', text[m_first.end():])
    end = m_first.end() + (m_second.start() if m_second else len(text) - m_first.end())
    staff = text[m_first.end():end]
    bars = list(_BAR.finditer(staff))
    if not bars:
        return text
    # music21 numbers a pickup 0 but a full first measure 1; the page always
    # starts at 0, so the first measure's number is the offset.
    base = int(bars[0].group(1))
    out, pos = [], 0
    for this, nxt in zip(bars, bars[1:]):
        out.append(staff[pos:this.start()])
        out.append(f'\\set Score.currentBarNumber = #{int(nxt.group(1)) - base} ')
        pos = this.start()
    out.append(staff[pos:])
    return (text[:m_first.end()] + ' \\set Score.currentBarNumber = #0 '
            + "".join(out) + text[end:])


def compact(text: str, paper: str, staff_size: int) -> str:
    """Rewrite music21's LilyPond source for a tight one-page layout.

    music21 emits the staves bare inside \\score and an empty \\paper block;
    this wraps them in a ChoirStaff (one bracket, bar lines through all four)
    and sets the size, margins and spacing.  A second top-level \\layout
    block is legal LilyPond and merges with the one music21 writes."""
    head = (f'#(set-default-paper-size "{paper}")\n'
            f'#(set-global-staff-size {staff_size})\n')
    text, n = re.subn(r'(\\version\s+"[^"]+"\s*\n)', lambda m: m.group(1) + head, text, count=1)
    if n == 0:
        text = head + text
    text = re.sub(r'(\\score\s*\{\s*)<<', lambda m: m.group(1) + r'\new ChoirStaff <<', text, count=1)
    text = join_split_measures(text)
    text = number_measures(text)
    paper_block = r'''\paper {
  top-margin = 10\mm
  bottom-margin = 10\mm
  left-margin = 12\mm
  right-margin = 12\mm
  indent = 0\mm
  system-system-spacing.basic-distance = #22
  system-system-spacing.padding = #4
  ragged-bottom = ##t
  ragged-last-bottom = ##t
}
\layout {
  \context {
    \ChoirStaff
    \override StaffGrouper.staff-staff-spacing.basic-distance = #10
    \override StaffGrouper.staff-staff-spacing.padding = #1.5
  }
  \context {
    \Score
    % every measure start, and pickups (negative position); not the
    % mid-measure double bars the corpus puts at phrase ends
    barNumberVisibility = #(lambda (barnum mp) (<= (ly:moment-main mp) 0))
    \override BarNumber.break-visibility = #end-of-line-invisible
    \override BarNumber.self-alignment-X = #LEFT
  }
}'''
    text, n = re.subn(r'\\paper\s*\{\s*\}', lambda m: paper_block, text, count=1)
    if n == 0:
        text += "\n" + paper_block
    return text


def engrave(score, out_pdf: Path, lilypond: str, paper: str, staff_size: int,
            keep_ly: bool) -> Path:
    """Write the score as PDF via LilyPond; returns the PDF path."""
    conv = lily_translate.LilypondConverter()
    conv.loadFromMusic21Object(score)
    conv.headerScheme.content = ""      # what stream.write('lily.pdf') does too
    text = compact(str(conv.topLevelObject), paper, staff_size)
    base = out_pdf.with_suffix("")
    ly = base.with_suffix(".ly")
    ly.write_text(text, encoding="utf-8")
    run = subprocess.run([lilypond, "-dno-point-and-click", "-o", str(base), str(ly)],
                         capture_output=True, text=True)
    if run.returncode != 0 or not out_pdf.exists():
        raise RuntimeError("lilypond failed:\n" + run.stderr[-2000:])
    if not keep_ly:
        ly.unlink()
    return out_pdf


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("chorales", nargs="+", help="corpus names (bwv267) or score files")
    ap.add_argument("--include-lyrics", action="store_true")
    ap.add_argument("--staff-size", type=int, default=15)
    ap.add_argument("--out_dir", default="Chorale-pdf")
    ap.add_argument("--paper", default="letter", choices=["letter", "a4"])
    ap.add_argument("--keep_ly", action="store_true")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    lily = shutil.which("lilypond")
    if not lily:
        sys.exit("lilypond not found on PATH (Fedora: sudo dnf install lilypond)")

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    failed = 0
    for item in args.chorales:
        score, stem = load(item)
        out_pdf = out_dir / f"{stem}.pdf"
        if out_pdf.exists() and not args.force:
            print(f"{stem}: {out_pdf} exists, skipping (--force to redo)")
            continue
        title_block(score, stem)
        strip_layout(score)
        if not args.include_lyrics:
            strip_lyrics(score)
        try:
            engrave(score, out_pdf, lily, args.paper, args.staff_size, args.keep_ly)
        except Exception as exc:
            failed += 1
            print(f"{stem}: FAILED — {exc}", file=sys.stderr)
            continue
        parts = ", ".join(p.partName or "?" for p in score.parts)
        print(f"{stem}: {out_pdf}  ({parts})")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
