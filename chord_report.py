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
from select_best_and_render import parse_dir_params

# The notebook's settings block, kept as constants: these never varied in use.
MEASURE = 0                     # 0 means print all measures
PRINT_INDIVIDUAL_CHORDS = True
RATIOS = True
PRINT_TOP_NOTES = True
PRINT_HITS_MISSES = False
USE_WERCK_TOP_NOTES = False

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


def print_chords(version, input_file, numpy_dir, measure, tolerance,
                 chord_scorer, tonal_diamond, keys, top_notes, root, mode,
                 cents, offset=0):
    if PRINT_TOP_NOTES:
        top_notes = top_notes.copy()
        top_notes[1] = top_notes[1] + offset
        print(f'Key: {keys[root]} {mode}')
        print('\ntop notes:')
        print(*[inx for inx in np.arange(12)], sep='\t')
        print(*[note for note in top_notes[0]], sep='\t')
        print(*[keys[note] for note in top_notes[0]], sep='\t')
        print(*[cent_value for cent_value in top_notes[1]], sep='\t')
    if PRINT_INDIVIDUAL_CHORDS:
        print('\n#          cents       note names   chord score')
    if measure > 0:
        print(f'\nprinting only measure {measure}')

    header1 = ' # Fr/To Cents Ratio\t # Fr/To Cents Ratio\t # Fr/To Cents Ratio'
    prev_chord = np.zeros(4, dtype=int)
    for inx, chord_in_cents in zip(count(0, 1), cents.T):
        if not np.array_equal(prev_chord, chord_in_cents):
            if measure == 0 or 16 * (measure - 1) <= inx < 16 * measure:
                tuned_pcs = np.array(atu.pitch_class_from_cents(chord_in_cents), dtype=int) % 12
                if PRINT_INDIVIDUAL_CHORDS:
                    # Tuned note names (from cents), not original MIDI pitch classes.
                    pitches = ' '.join(map(str, keys[tuned_pcs]))
                    print(f'{inx}: {atu.format_chord(chord_in_cents, 4)}\t{pitches}\t'
                          f'{chord_scorer.score_chord(chord_in_cents, tolerance=tolerance)}')
                if RATIOS:
                    print(header1)
                    intervals = []
                    for inx1, inx2 in combinations(np.arange(4), 2):
                        pair = np.array([chord_in_cents[inx1], chord_in_cents[inx2]])
                        cent_value_delta, _moves, _target = atu.cent_value_interval(pair)
                        best_idx = chord_scorer.find_best_interval(cent_value_delta, tolerance)[0]
                        ratio = str(atu.limit_format(tonal_diamond[best_idx])[0]).strip()
                        intervals.append((keys[tuned_pcs[inx1]], keys[tuned_pcs[inx2]],
                                          cent_value_delta, ratio))

                    def fmt(iv, idx):
                        n1, n2, cents_, ratio = iv
                        return f'{idx:>2} {n1:>2} {n2:>2} {cents_:>5} {ratio:^6}'

                    print('   '.join(fmt(iv, i + 1) for i, iv in enumerate(intervals[:3])))
                    print('   '.join(fmt(iv, i + 4) for i, iv in enumerate(intervals[3:])))
        prev_chord = chord_in_cents.copy()


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0],
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--chorale', help='Chorale name, e.g. bwv262. Defaults to the '
                                     'leading bwvNNN of the filename')
    p.add_argument('--input_numpy_file', required=True,
                   help='The tuned (4, N) cent array to report on')
    p.add_argument('--measure', type=int, default=MEASURE,
                   help='Print only this measure; 0 prints all (default: 0)')
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
    scores = np.array([chord_scorer.score_chord(c, tolerance=tolerance) for c in cents.T])

    print('_' * 40)
    print(f'{chorale}  {os.path.basename(path)}')
    print(f'{numpy_dir}')
    print(f'tolerance: {tolerance}, limit_max: {limit_max}, '
          f'tonal diamond: {tonal_diamond.shape}, chords: {cents.shape[1]}')
    print(f'Average score: {round(np.average(scores), 1)}, max score: {np.max(scores)}, '
          f'max chord: {np.argmax(scores)}')

    print_chords(chorale, path, numpy_dir, args.measure, tolerance,
                 chord_scorer, tonal_diamond, keys, top_notes, root, mode, cents)

    if PRINT_HITS_MISSES:
        print(f'hits and misses: {chord_scorer.return_cache_results()}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
