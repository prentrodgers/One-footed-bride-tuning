#!/usr/bin/env python3
"""Chord numbers for the --rondo_* arguments of WreckingCrew.py, by measure and phrase.

    python rondo_plan.py bwv354
    python rondo_plan.py bwv{354..365}

WreckingCrew's chords are the columns of stream_to_midi_array: one per
sixteenth of the score as written, counted from 0 at the first note.  So a
4/4 measure is 16 chords, and the chord numbers are found from the measures
in chorale_pdf.py's PDF, numbered the same way (0 at the first measure,
pickup or not; a pickup's number in parentheses).

For each chorale this prints

  * every measure's chords [first, last];
  * every phrase (ending at a soprano fermata) as a [START, END) range for
    --rondo_section_*, and the chord to give --rondo_insert_*_after to put a
    section right after that phrase (END - 1);
  * a suggestion to start from: A = the opening phrase (two if the first is
    short), B = the phrase nearest the middle, A inserted after the phrase
    ends nearest a third and two thirds of the way through, B after the one
    nearest half way.

Repeat signs: the arrays follow the score as written, and repeats are not
expanded, so a repeated passage is played (and numbered) once.  Measures
carrying a repeat sign are flagged so the PDF and the numbers can be lined up.

WreckingCrew skips an insertion within 16 chords of the end, so phrase ends
there are marked and never suggested.  The numbers are for the whole piece:
with --include_slice or --chaconne_* the rondo indices count the piece after
those, and do not match this table.
"""

from __future__ import annotations

import argparse
import math
from fractions import Fraction

import music21 as m21

import adaptive_tuning_util as atu

MIN_MARGIN = 16       # WreckingCrew skips insertions within this many chords of the end
SHORT_PHRASE = 24     # an opening phrase shorter than this takes the next one into section A


def slot(t) -> int:
    """stream_to_midi_array's sixteenth slot for score time t (quarter notes)."""
    return math.ceil(Fraction(t).limit_denominator(64) * 4)


def has_fermata(n) -> bool:
    return any(isinstance(e, m21.expressions.Fermata) for e in n.expressions)


def plan(name: str) -> None:
    score = atu.parse_score(atu.score_name(name))
    rows = atu.score_rows(score)
    first = min(a for spans, _ in rows for a, _, _ in spans)
    n = max(b for spans, _ in rows for _, b, _ in spans) - first
    soprano = score.parts[0]

    # Measures, numbered as chorale_pdf.py prints them.
    measures = list(soprano.getElementsByClass(m21.stream.Measure))
    base = measures[0].number
    rows_m = []
    for m in measures:
        a = slot(m.getOffsetInHierarchy(soprano)) - first
        b = slot(m.getOffsetInHierarchy(soprano) + m.duration.quarterLength) - first
        a, b = max(a, 0), min(b, n)
        if b <= a:
            continue
        short = m.duration.quarterLength < m.barDuration.quarterLength   # its own meter: some change mid-piece
        label = f'({m.number - base})' if short and a == 0 or m.paddingLeft else f'{m.number - base}'
        repeat = any(isinstance(bl, m21.bar.Repeat) for bl in (m.leftBarline, m.rightBarline))
        rows_m.append((label, a, b, short, repeat))

    # Phrases end where the soprano holds a fermata; the last ends with the piece.
    ends = sorted({slot(x.getOffsetInHierarchy(soprano) + x.duration.quarterLength) - first
                   for x in soprano.recurse().notes if has_fermata(x)})
    ends = [e for e in ends if 0 < e < n] + [n]
    phrases = list(zip([0] + ends[:-1], ends))
    cutoff = n - 1 - MIN_MARGIN       # insert-after values must be below this

    def measures_of(a, b):
        inside = [lab for lab, ma, mb, _, _ in rows_m if ma < b and mb > a]
        return inside[0] if len(inside) == 1 else f'{inside[0]}-{inside[-1]}'

    ts = soprano.recurse().getElementsByClass(m21.meter.TimeSignature).first()
    pickup = rows_m[0][1] == 0 and rows_m[0][3]
    print(f'== {name}   {ts.ratioString if ts else "?"}, {n} chords (sixteenths), '
          f'{"pickup of " + str(rows_m[0][2]) + " chords" if pickup else "no pickup"}; '
          f'an insert-after of {cutoff} or more is skipped')
    print('measure  chords')
    for lab, a, b, short, repeat in rows_m:
        print(f'  {lab:>5}  {a:4}-{b - 1:<4}{"  short" if short and a else ""}'
              f'{"  repeat sign (played once)" if repeat else ""}')
    print('phrase   --rondo_section_*   measures     --rondo_insert_*_after')
    for i, (a, b) in enumerate(phrases, 1):
        after = f'{b - 1}' if b - 1 < cutoff else f'{b - 1}  (too near the end)'
        print(f'  {i:>3}    {a:4} {b:<4}            {measures_of(a, b):<12} {after}')

    # A starting point.
    a_end = phrases[0][1]
    if a_end < SHORT_PHRASE and len(phrases) > 2:
        a_end = phrases[1][1]
    a_sec = (0, a_end)
    later = [p for p in phrases if p[0] >= a_end and p[1] < n]
    b_sec = min(later, key=lambda p: abs((p[0] + p[1]) / 2 - n / 2)) if later else None
    points = [b - 1 for _, b in phrases if a_end <= b - 1 < cutoff]

    def nearest(frac, taken):
        free = [p for p in points if p not in taken]
        return min(free, key=lambda p: abs(p - frac * n)) if free else None

    ins_a = sorted({p for p in (nearest(1 / 3, []), nearest(2 / 3, [])) if p is not None})
    # Not right before or after B's own phrase: either plays it twice in a row.
    ins_b = nearest(1 / 2, ins_a + [b_sec[0] - 1, b_sec[1] - 1]) if b_sec else None
    print('suggestion:')
    if not ins_a:
        print('  no phrase end leaves room for an insertion')
        return
    cmd = f'--rondo_section_a {a_sec[0]} {a_sec[1]} --rondo_insert_a_after {" ".join(map(str, ins_a))}'
    if b_sec and ins_b is not None:
        cmd += f' --rondo_section_b {b_sec[0]} {b_sec[1]} --rondo_insert_b_after {ins_b}'
    print(f'  {cmd}')
    print()


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('chorales', nargs='+', help='corpus names, e.g. bwv354 (or bwv{354..365})')
    for name in ap.parse_args().chorales:
        plan(name)


if __name__ == '__main__':
    main()
