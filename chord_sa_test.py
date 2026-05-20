#!/usr/bin/env python3
"""
chord_sa_test.py

Test harness for single-chord simulated annealing tuning.
Tries every combination of limit_max and tolerance for a given chord.

Usage:
    python chord_sa_test.py --pitches 0 3 6 9 --limit_max 17 19 --tolerances 1 2 3
"""

import argparse
import logging
import os
import sys
import time
import numpy as np
from itertools import combinations

# Add project directory to path
local_dir = os.path.dirname(os.path.abspath(__file__))
if local_dir not in sys.path:
    sys.path.insert(0, local_dir)

import adaptive_tuning_util as atu
from optimize_chords_sa_v2 import build_straw_man_chord_simulated_annealing, roll_and_tune


def pitch_classes_to_cents(pitch_classes):
    """Convert pitch class array to 12-TET cent values (pc * 100)."""
    return np.array([pc * 100 for pc in pitch_classes], dtype=float)


KEYS_FLATS = atu.set_accidentals(flats=True)   # ['C♮','D♭','D♮','E♭','E♮','F♮','G♭','G♮','A♭','A♮','B♭','B♮']


def cents_to_note_name(c):
    """Return nearest note name (with ♮/♭) for a cent value."""
    c_int = int(round(c)) % 1200
    pc = (c_int // 100) % 12
    offset = c_int - pc * 100
    if offset > 50:
        pc = (pc + 1) % 12
    return KEYS_FLATS[pc]


def format_chord_cents(cents):
    """Return (cents_str, names_str) for a chord."""
    cents_str = '  '.join(f"{int(round(c)):>4}" for c in cents)
    names_str = '  '.join(f"{cents_to_note_name(c):<3}" for c in cents)
    return cents_str, names_str


def format_intervals(tuned_cents, pitch_classes, chord_scorer, tonal_diamond, tolerance):
    """Print the 6 pairwise intervals in two rows of 3, matching Chorale-info.ipynb style."""
    keys = KEYS_FLATS
    intervals = []
    for i, j in combinations(range(len(tuned_cents)), 2):
        pair = np.array([tuned_cents[i], tuned_cents[j]], dtype=float)
        delta, _, _ = atu.cent_value_interval(pair)
        best_idx = chord_scorer.find_best_interval(delta, tolerance)[0]
        ratio = str(atu.limit_format(tonal_diamond[best_idx])[0]).strip()
        n1 = keys[pitch_classes[i] % 12]
        n2 = keys[pitch_classes[j] % 12]
        intervals.append((n1, n2, int(round(delta)), ratio))

    def fmt(iv, idx):
        n1, n2, cents, ratio = iv
        return f"{idx:>2} {n1:>2} {n2:>2} {cents:>5}  {ratio:<6}"

    header = " # Fr/To Cents Ratio\t # Fr/To Cents Ratio\t # Fr/To Cents Ratio"
    print(header)
    print("   ".join(fmt(iv, i + 1)     for i, iv in enumerate(intervals[:3])))
    print("   ".join(fmt(iv, i + 1 + 3) for i, iv in enumerate(intervals[3:])))


def run_test(pitch_classes, limit_max_values, tolerances,
             rolls=5, max_iterations=1000, initial_temperature=2.5,
             cooling_rate=0.999, spread=7):

    print(f"\nChord pitch classes: {pitch_classes}")
    print(f"12-TET start (cents): {pitch_classes_to_cents(pitch_classes)}")
    print(f"limit_max values: {limit_max_values}")
    print(f"tolerances: {tolerances}")
    print()

    n = len(pitch_classes)
    cents_width = n * 6 - 2   # 4 chars per value + 2 spaces between
    names_width = n * 5 - 2
    header = (f"{'limit_max':>10}  {'tol':>4}  {'score':>8}  {'time(s)':>8}"
              f"  {'tuned cents':<{cents_width}}  note names")
    print(header)
    print('-' * (len(header) + names_width))

    initial_cents = pitch_classes_to_cents(pitch_classes)
    prev_cents = np.zeros(len(pitch_classes), dtype=float)  # no previous chord

    for limit_max in limit_max_values:
        tonal_diamond = atu.build_tonal_diamond(limit_max)[:-1]
        low_number_ratios = atu.LowNumberRatioIntervals(tonal_diamond)
        chord_scorer = atu.ChordScorer(tonal_diamond)

        for tolerance in tolerances:
            chord_scorer.reset_cache()

            t0 = time.time()
            tuned, score = roll_and_tune(
                initial_cents.copy(),
                prev_cents.copy(),
                chord_num=0,
                tolerance=tolerance,
                chord_scorer=chord_scorer,
                low_number_ratios=low_number_ratios,
                tonal_diamond=tonal_diamond,
                initial_temperature=initial_temperature,
                cooling_rate=cooling_rate,
                max_iterations=max_iterations,
                spread=spread,
                rolls=rolls,
            )
            elapsed = time.time() - t0

            tuned_int = np.array([int(round(c)) for c in tuned])
            cents_str, names_str = format_chord_cents(tuned_int)
            print(f"{limit_max:>10}  {tolerance:>4}  {score:>8.1f}  {elapsed:>8.3f}"
                  f"  {cents_str}  {names_str}")
            format_intervals(tuned_int, pitch_classes, chord_scorer, tonal_diamond, tolerance)
            print()

    print()


def main():
    parser = argparse.ArgumentParser(
        description='SA tuning test for a single chord across tolerances and limit_max values'
    )
    parser.add_argument('--pitches', nargs='+', type=int, required=True,
                        help='Pitch classes (0-11), e.g. 0 3 6 9')
    parser.add_argument('--limit_max', nargs='+', type=int, default=[17, 19],
                        help='Prime limit values to test, e.g. 17 19')
    parser.add_argument('--tolerances', nargs='+', type=int, default=[1, 2, 3],
                        help='Tolerance values to test, e.g. 1 2 3')
    parser.add_argument('--rolls', type=int, default=5,
                        help='Number of SA rolls per chord (default: 5)')
    parser.add_argument('--max_iterations', type=int, default=1000,
                        help='Max SA iterations per roll (default: 1000)')
    parser.add_argument('--initial_temperature', type=float, default=2.5,
                        help='SA initial temperature (default: 2.5)')
    parser.add_argument('--cooling_rate', type=float, default=0.999,
                        help='SA cooling rate (default: 0.999)')
    parser.add_argument('--spread', type=int, default=7,
                        help='Perturbation spread (default: 7)')
    parser.add_argument('--verbose', action='store_true',
                        help='Enable DEBUG logging')
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.WARNING,
        format='%(levelname)s %(message)s'
    )

    if len(args.pitches) < 2:
        parser.error('Need at least 2 pitch classes')

    run_test(
        pitch_classes=args.pitches,
        limit_max_values=args.limit_max,
        tolerances=args.tolerances,
        rolls=args.rolls,
        max_iterations=args.max_iterations,
        initial_temperature=args.initial_temperature,
        cooling_rate=args.cooling_rate,
        spread=args.spread,
    )


if __name__ == '__main__':
    main()
