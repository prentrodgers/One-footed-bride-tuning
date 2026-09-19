#!/usr/bin/env python3
"""Print the chords of one tuned numpy array: cents, note names, score, ratios.

The same report Chorale-info.ipynb produces, for a single file named outright
rather than a suffix matched against a hand-maintained list of directories.

    python chord_report.py --input_numpy_file Archive/straw-man/t3_r1.50_lm19/bwv262-opt.npy
    python chord_report.py --input_numpy_file Archive/straw-man/viterbi-tunings-8-24c/bwv262_t3_r1.500_lm19-opt.npy

The chorale name is the leading bwvNNN of the filename; --chorale overrides it
for a file named some other way.  Tolerance and limit_max are read from the path — from the filename when it
carries them (bwv262_t3_r1.500_lm19-opt.npy) and otherwise from the directory
name (t3_r1.50_lm19).  --tolerance / --limit_max override, and are the only way
to report on a file whose path encodes neither.

In the listing a ratio built on 11 or higher is marked *, and a cent value
that moved more than a cent from the same pitch class in the previous chord
is printed in red, since those moves are what the ear catches between chords.
The red needs a terminal: --color auto (the default) uses it only when stdout
is one, so a report written to a file stays plain text; --color always or
never overrides.

After the chords comes a histogram of the primes in the ratios: how many
numerators and denominators carry each prime, and how much of the piece rests
on the high ones (11, 13, 17, 19).  --histogram_only prints that alone, which
is the quick way to compare chorales:

    for f in Archive/straw-man/best-tunings/*-opt.npy; do
        python chord_report.py --input_numpy_file "$f" --histogram_only | tail -3
    done
"""
import argparse
import os
import re
import sys
from itertools import combinations, count

import numpy as np

base_dir = os.path.dirname(os.path.abspath(__file__))
if base_dir not in sys.path:
    sys.path.insert(0, base_dir)

import adaptive_tuning_util as atu
from select_best_and_render import collect_gaps, parse_dir_params

# The notebook's settings block, kept as constants: these never varied in use.
MEASURE = 0                     # 0 means print all measures
PRINT_INDIVIDUAL_CHORDS = True
RATIOS = True
PRINT_TOP_NOTES = True
PRINT_HITS_MISSES = False
USE_WERCK_TOP_NOTES = False

# The primes the histogram reports on, and the ones counted as "high": a 13/11
# is a different creature from a 3/2, and the point of the tuning is knowing
# how often the piece leans on them.
HIGH_PRIMES = (11, 13, 17, 19)
HIGH_MARK = '*'          # against a ratio in the chord listing

# A pitch class that moved more than this many cents between adjacent chords
# is a gap: the same threshold select_best_and_render's GapSum counts, and
# the tuner's own idea of "no movement".
GAP_CENTS = 1.0
RED, BOLD_RED, RESET = '\033[31m', '\033[1;31m', '\033[0m'

# Archived collections encode the parameters in the filename.
FILE_PARAMS = re.compile(r'_t(\d+)_r([\d.]+)_lm(\d+)')
# Every layout leads with the chorale: bwv262-opt.npy, bwv262_t3_r1.500_lm19-opt.npy,
# bwv264_t3_r1.500_lm17-trans-sa-opt.npy.
FILE_CHORALE = re.compile(r'^(bwv\d+)')


def chorale_for(path):
    """The chorale name leading the filename, or None."""
    m = FILE_CHORALE.match(os.path.basename(path))
    return m.group(1) if m else None


def params_for(path, tolerance, limit_max):
    """(tolerance, limit_max) from the filename, else the directory, else the args."""
    m = FILE_PARAMS.search(os.path.basename(path))
    if m:
        return int(m.group(1)), int(m.group(3))
    d = parse_dir_params(os.path.dirname(os.path.abspath(path)))
    if d:
        return d['tolerance'], d['limit_max']
    return tolerance, limit_max


def odd_prime_factors(n):
    """The odd prime factors of n, with multiplicity (2 is ignored: an octave
    does not change what a ratio is made of)."""
    n = int(n)
    out = []
    while n % 2 == 0 and n > 0:
        n //= 2
    f = 3
    while f * f <= n:
        while n % f == 0:
            out.append(f)
            n //= f
        f += 2
    if n > 1:
        out.append(n)
    return out


def split_ratio(text):
    """'13/11' -> (13, 11); '1/1' -> (1, 1)."""
    if '/' in text:
        a, _, b = text.partition('/')
        try:
            return int(a), int(b)
        except ValueError:
            return None
    try:
        return int(text), 1
    except ValueError:
        return None


def ratio_primes(text):
    """Every odd prime in a ratio, numerator side and denominator side."""
    parts = split_ratio(text)
    if parts is None:
        return [], []
    return odd_prime_factors(parts[0]), odd_prime_factors(parts[1])


def is_high(text):
    """Does this ratio use a prime of 11 or more?"""
    num, den = ratio_primes(text)
    return any(p >= min(HIGH_PRIMES) for p in num + den)


def gap_voices(cents):
    """{(chord index, voice): cents moved} for every voice whose pitch class was
    in the previous chord more than GAP_CENTS away.  Held chords (identical
    columns) are skipped, so 'previous' means the previous distinct chord."""
    return {(i, v): gap for gap, i, v, _pc, _prev, _curr in collect_gaps(cents)
            if gap > GAP_CENTS}


def format_chord_cents(chord_in_cents, inx, gaps, color):
    """The four cent values as format_chord prints them, a moved one in red."""
    parts = []
    for v, val in enumerate(chord_in_cents):
        text = f'{int(val):4d}'
        if color and (inx, v) in gaps:
            text = f'{BOLD_RED}{text}{RESET}'
        parts.append(text)
    return ' '.join(parts)


def print_prime_histogram(intervals, n_chords, chorale=''):
    """How the piece's ratios are built: which primes, and how often.

    `intervals` is [(chord number, note name, note name, cents, ratio)] for
    every interval of every chord the listing covered — six per chord.
    """
    if not intervals:
        print('\nno intervals to count')
        return
    total = len(intervals)
    num_count, den_count, with_prime, limits = {}, {}, {}, {}
    for _inx, _n1, _n2, _cents, ratio in intervals:
        num, den = ratio_primes(ratio)
        for p in set(num):
            num_count[p] = num_count.get(p, 0) + num.count(p)
        for p in set(den):
            den_count[p] = den_count.get(p, 0) + den.count(p)
        for p in set(num + den):
            with_prime[p] = with_prime.get(p, 0) + 1
        top = max(num + den, default=1)
        limits[top] = limits.get(top, 0) + 1

    primes = sorted(set(num_count) | set(den_count))
    widest = max(with_prime.values(), default=1)
    print(f'\nPrime content of {total} intervals in {n_chords} chords (six per chord). '
          f'An interval counts under every prime it uses, so 13/11 is in both rows.')
    print(' prime   numerators  denominators   intervals   share')
    for p in primes:
        n = with_prime.get(p, 0)
        bar = '#' * int(round(30 * n / widest))
        print(f'{p:>6}   {num_count.get(p, 0):>10}  {den_count.get(p, 0):>12}   '
              f'{n:>9}  {100 * n / total:>5.1f}%  {bar}')

    print('\n Prime limit of each interval (its largest odd prime)')
    for p in sorted(limits):
        n = limits[p]
        note = '  (unisons and octaves)' if p == 1 else ''
        bar = '#' * int(round(30 * n / max(limits.values())))
        print(f'{p:>6}   {n:>9}  {100 * n / total:>5.1f}%  {bar}{note}')

    high_intervals = [iv for iv in intervals if is_high(iv[4])]
    high_chords = {iv[0] for iv in high_intervals}
    print(f'\n High primes {HIGH_PRIMES}: {len(high_intervals)} of {total} intervals '
          f'({100 * len(high_intervals) / total:.1f}%), in {len(high_chords)} of '
          f'{n_chords} chords ({100 * len(high_chords) / max(1, n_chords):.1f}%)')
    for p in HIGH_PRIMES:
        n = with_prime.get(p, 0)
        if n:
            ratios = {}
            for iv in intervals:
                if p in set(sum(ratio_primes(iv[4]), [])):
                    ratios[iv[4]] = ratios.get(iv[4], 0) + 1
            spread = ', '.join(f'{r} x{c}' for r, c in
                               sorted(ratios.items(), key=lambda kv: -kv[1]))
            print(f'   {p:>2}: {n:>4} intervals   {spread}')
        else:
            print(f'   {p:>2}:    none')
    if high_intervals:
        print('\n Chords using them (chord: interval, ratio)')
        for inx, n1, n2, cents_, ratio in high_intervals:
            print(f'   {inx:>5}: {n1:>2} {n2:>2} {cents_:>5}  {ratio}')
    # One line to compare chorales with: `... --histogram_only | tail -1`
    counts = ' '.join(f'{p}:{with_prime.get(p, 0)}' for p in HIGH_PRIMES)
    print(f'\nSUMMARY {chorale:<8} high {100 * len(high_intervals) / total:>5.1f}%  '
          f'{counts}  chords {len(high_chords)}/{n_chords}  intervals {total}')


def print_chords(version, input_file, numpy_dir, measure, tolerance,
                 chord_scorer, tonal_diamond, keys, top_notes, root, mode,
                 cents, offset=0, listing=True, color=False):
    """Print the chords, and return (intervals, chord count) for the histogram.

    The ratios are worked out whether or not they are printed, so
    --histogram_only counts exactly what the listing would have shown."""
    if PRINT_TOP_NOTES and listing:
        top_notes = top_notes.copy()
        top_notes[1] = top_notes[1] + offset
        print(f'Key: {keys[root]} {mode}')
        print('\ntop notes:')
        print(*[inx for inx in np.arange(12)], sep='\t')
        print(*[note for note in top_notes[0]], sep='\t')
        print(*[keys[note] for note in top_notes[0]], sep='\t')
        print(*[cent_value for cent_value in top_notes[1]], sep='\t')
    if PRINT_INDIVIDUAL_CHORDS and listing:
        print('\n#          cents       note names   chord score')
    if measure > 0 and listing:
        print(f'\nprinting only measure {measure}')

    header1 = ' # Fr/To Cents Ratio\t # Fr/To Cents Ratio\t # Fr/To Cents Ratio'
    if measure > 0:
        # The bar's columns as the score has them (music21's measure numbers),
        # not a fixed sixteen per measure: a chorale whose first beat is silent
        # starts the array a beat into bar 1.
        bars = {n: (a, b) for n, a, b in atu.measure_columns(version)}
        if measure not in bars:
            print(f'no measure {measure}: the score has measures {min(bars)}-{max(bars)}')
            return [], 0
        first_col, end_col = bars[measure]
    else:
        first_col, end_col = 0, cents.shape[1]
    all_intervals, n_chords = [], 0
    gaps = gap_voices(cents)
    if listing and gaps:
        moved = sorted({i for i, _v in gaps})
        shown = [i for i in moved if first_col <= i < end_col]
        print(f'{len(gaps)} cent values moved more than {GAP_CENTS:g} cent from the same pitch '
              f'class in the previous chord, in {len(moved)} chords'
              + (f' ({len(shown)} of them in this measure)' if measure > 0 else '')
              + (': shown in red' if color else '; --color always shows them in red'))
    prev_chord = np.zeros(4, dtype=int)
    for inx, chord_in_cents in zip(count(0, 1), cents.T):
        if not np.array_equal(prev_chord, chord_in_cents):
            if first_col <= inx < end_col:
                n_chords += 1
                tuned_pcs = np.array(atu.pitch_class_from_cents(chord_in_cents), dtype=int) % 12
                if PRINT_INDIVIDUAL_CHORDS and listing:
                    # Tuned note names (from cents), not original MIDI pitch classes.
                    pitches = ' '.join(map(str, keys[tuned_pcs]))
                    print(f'{inx}: {format_chord_cents(chord_in_cents, inx, gaps, color)}\t{pitches}\t'
                          f'{chord_scorer.score_chord(chord_in_cents, tolerance=tolerance)}')
                intervals = []
                for inx1, inx2 in combinations(np.arange(4), 2):
                    pair = np.array([chord_in_cents[inx1], chord_in_cents[inx2]])
                    cent_value_delta, _moves, _target = atu.cent_value_interval(pair)
                    best_idx = chord_scorer.find_best_interval(cent_value_delta, tolerance)[0]
                    ratio = str(atu.limit_format(tonal_diamond[best_idx])[0]).strip()
                    intervals.append((keys[tuned_pcs[inx1]], keys[tuned_pcs[inx2]],
                                      cent_value_delta, ratio))
                all_intervals += [(inx,) + iv for iv in intervals]
                if RATIOS and listing:
                    print(header1)

                    def fmt(iv, idx):
                        n1, n2, cents_, ratio = iv
                        # a ratio built on 11 or higher is marked, so the high
                        # primes can be found by eye or by grep
                        mark = HIGH_MARK if is_high(ratio) else ' '
                        return f'{idx:>2} {n1:>2} {n2:>2} {cents_:>5} {ratio:^6}{mark}'

                    print('  '.join(fmt(iv, i + 1) for i, iv in enumerate(intervals[:3])))
                    print('  '.join(fmt(iv, i + 4) for i, iv in enumerate(intervals[3:])))
        prev_chord = chord_in_cents.copy()
    return all_intervals, n_chords


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0],
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--chorale', help='Chorale name, e.g. bwv262. Defaults to the '
                                     'leading bwvNNN of the filename')
    p.add_argument('--input_numpy_file', required=True,
                   help='The tuned (4, N) cent array to report on')
    p.add_argument('--measure', type=int, default=MEASURE,
                   help='Print only this measure; 0 prints all (default: 0)')
    p.add_argument('--histogram_only', action='store_true',
                   help='print only the prime histogram, not the chords')
    p.add_argument('--color', choices=('auto', 'always', 'never'), default='auto',
                   help='red for cent values that moved between adjacent chords: '
                        'auto (default) only when printing to a terminal')
    p.add_argument('--tolerance', type=int, default=1,
                   help='Used only when the path encodes no tolerance (default: 1)')
    p.add_argument('--limit_max', type=int, default=17,
                   help='Used only when the path encodes no limit_max (default: 17)')
    args = p.parse_args()

    path = args.input_numpy_file
    if not os.path.exists(path):
        print(f'No such file: {path}', file=sys.stderr)
        return 1
    chorale = args.chorale or chorale_for(path)
    if not chorale:
        print(f'Cannot tell the chorale from {os.path.basename(path)} — '
              'it does not start with bwvNNN. Pass --chorale.', file=sys.stderr)
        return 1
    tolerance, limit_max = params_for(path, args.tolerance, args.limit_max)

    tonal_diamond = atu.build_tonal_diamond(limit_max)
    chord_scorer = atu.ChordScorer(tonal_diamond)
    chord_scorer.reset_cache()

    numpy_dir = os.path.dirname(os.path.abspath(path))
    # save_top_notes=False: this only reports, and the default would write a
    # top-notes file into a collection directory that has none.
    _, top_notes, _chorale, root, mode, keys = atu.load_chorale_in_cents(
        chorale, numpy_dir, save_top_notes=False,
        werck_top_notes=USE_WERCK_TOP_NOTES)

    cents = np.rint(np.load(path, allow_pickle=True)).astype(int)
    match = atu.tuning_matches_score(cents, _chorale)
    if match < 1.0:
        print(f'WARNING: {os.path.basename(path)} plays {100 * match:.1f}% of the chords in '
              f'{chorale} ({cents.shape[1]} chords against {_chorale.shape[1]} sixteenths). '
              f'It was tuned from the pre-14 Sep 2026 reading of the score (voices dealt into '
              f'rows, rests ignored), so the chords below are not the ones in the measures; '
              f're-tune {chorale} before trusting it.')
    scores = np.array([chord_scorer.score_chord(c, tolerance=tolerance) for c in cents.T])

    if not args.histogram_only:
        print('_' * 40)
    print(f'{chorale}  {os.path.basename(path)}')
    print(f'{numpy_dir}')
    print(f'tolerance: {tolerance}, limit_max: {limit_max}, '
          f'tonal diamond: {tonal_diamond.shape}, chords: {cents.shape[1]}')
    print(f'Average score: {round(np.average(scores), 1)}, max score: {np.max(scores)}, '
          f'max chord: {np.argmax(scores)}')

    color = args.color == 'always' or (args.color == 'auto' and sys.stdout.isatty())
    intervals, n_chords = print_chords(
        chorale, path, numpy_dir, args.measure, tolerance, chord_scorer,
        tonal_diamond, keys, top_notes, root, mode, cents,
        listing=not args.histogram_only, color=color)
    print_prime_histogram(intervals, n_chords, chorale)

    if PRINT_HITS_MISSES:
        print(f'hits and misses: {chord_scorer.return_cache_results()}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
