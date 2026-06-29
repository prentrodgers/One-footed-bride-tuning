#!/usr/bin/env python3
"""
analyze_adjacent_spread.py

Report the largest cent jumps for shared pitch classes between consecutive
chords in a tuned chorale numpy array.  This is the adjacency-aware companion
to analyze_spread.py, which only reports whole-chorale range per pitch class.

For each consecutive chord pair that shares at least one pitch class, the
worst (largest) PC cent-gap is recorded.  The script then reports:

  - A histogram of gap sizes across the whole chorale
  - The N worst individual jumps with chord index and note name
  - Per-pitch-class summary: how often each PC jumps and by how much

Usage:
    python analyze_adjacent_spread.py \
        --numpy_dir Archive/straw-man/t3_r1.5_lm17_tmp3.0 \
        --chorale_list bwv253 bwv254 \
        --suffix=-opt.npy \
        --top 20 \
        --gap_threshold 15
"""

import argparse
import os
import sys
import numpy as np
from collections import Counter, defaultdict

base_dir = os.path.dirname(os.path.abspath(__file__))
if base_dir not in sys.path:
    sys.path.insert(0, base_dir)

import adaptive_tuning_util as atu


def analyze_adjacent_spread(numpy_dir, version, suffix,
                             gap_threshold=15, top_n=20):
    input_file = os.path.join(numpy_dir, f'{version}{suffix}')
    try:
        cent_value_chorale = np.load(input_file)   # shape (4, N)
    except Exception as e:
        print(f'Could not load {input_file}: {e}')
        return

    try:
        _, _, chorale, root, mode, keys = atu.load_chorale_in_cents(
            version, numpy_dir, twelve_tet=True, save_top_notes=False)
    except Exception as e:
        print(f'Could not load chorale {version}: {e}')
        return

    n_chords = cent_value_chorale.shape[1]
    print(f'\n{input_file}')
    print(f'Original chorale key: {keys[root]} {mode}  ({n_chords} chords)')

    # ------------------------------------------------------------------ #
    # Collect every adjacent-pair PC gap                                   #
    # ------------------------------------------------------------------ #
    # Each entry: (gap_cents, chord_idx, pc, prev_cents, curr_cents)
    all_gaps = []

    # Per-PC tracking: list of (chord_idx, gap)
    pc_gaps = defaultdict(list)

    for i in range(1, n_chords):
        prev_col = cent_value_chorale[:, i - 1]
        curr_col = cent_value_chorale[:, i]

        # Skip exact duplicates (held notes / repeated chords)
        if np.array_equal(prev_col, curr_col):
            continue

        prev_pcs = atu.pitch_class_from_cents(prev_col)
        curr_pcs = atu.pitch_class_from_cents(curr_col)

        # Build prev PC -> cent mapping
        prev_map = defaultdict(list)
        for pc, cv in zip(prev_pcs, prev_col):
            prev_map[int(pc)].append(float(cv))

        for pc, cv in zip(curr_pcs, curr_col):
            pc = int(pc)
            if pc not in prev_map:
                continue
            gap = min(atu.cent_distance_mod_1200(cv, p) for p in prev_map[pc])
            if gap > 0.5:   # ignore sub-cent numerical noise
                all_gaps.append((gap, i, pc, prev_map[pc][0], float(cv)))
                pc_gaps[pc].append((i, gap))

    if not all_gaps:
        print('No adjacent pitch-class gaps found.')
        return

    gaps_only = [g for g, *_ in all_gaps]

    # ------------------------------------------------------------------ #
    # Summary statistics                                                   #
    # ------------------------------------------------------------------ #
    print(f'\nAdjacent-chord PC gap summary ({len(all_gaps)} shared-PC transitions):')
    print(f'  Mean gap : {np.mean(gaps_only):6.1f} ¢')
    print(f'  Median   : {np.median(gaps_only):6.1f} ¢')
    print(f'  Max gap  : {np.max(gaps_only):6.1f} ¢')
    print(f'  > {gap_threshold:2d} ¢   : {sum(g > gap_threshold for g in gaps_only):4d}  '
          f'({100*sum(g > gap_threshold for g in gaps_only)/len(gaps_only):.1f}%)')

    # ------------------------------------------------------------------ #
    # Histogram                                                            #
    # ------------------------------------------------------------------ #
    bins = [0, 5, 10, 15, 20, 30, 50, float('inf')]
    labels = ['0-5', '5-10', '10-15', '15-20', '20-30', '30-50', '>50']
    counts = [0] * len(labels)
    for g in gaps_only:
        for idx, (lo, hi) in enumerate(zip(bins, bins[1:])):
            if lo <= g < hi:
                counts[idx] += 1
                break
    print(f'\n  Gap histogram (¢):')
    for label, count in zip(labels, counts):
        bar = '█' * (count * 40 // max(counts, default=1))
        print(f'  {label:>6}  {count:4d}  {bar}')

    # ------------------------------------------------------------------ #
    # Worst individual gaps                                                #
    # ------------------------------------------------------------------ #
    all_gaps.sort(reverse=True)
    print(f'\n  Top {min(top_n, len(all_gaps))} largest adjacent PC gaps:')
    print(f'  {"Chord":>6}  {"Note":<5}  {"Gap":>6}  {"Prev":>6}  {"Curr":>6}')
    print(f'  {"-----":>6}  {"----":<5}  {"---":>6}  {"----":>6}  {"----":>6}')
    for gap, chord_idx, pc, prev_cv, curr_cv in all_gaps[:top_n]:
        flag = ' <--' if gap > gap_threshold else ''
        print(f'  {chord_idx:>6}  {keys[pc]:<5}  {gap:>6.1f}  {prev_cv:>6.1f}  {curr_cv:>6.1f}{flag}')

    # ------------------------------------------------------------------ #
    # Per-pitch-class summary                                              #
    # ------------------------------------------------------------------ #
    pitch_class_counts = Counter((chorale % 12).flatten())
    print(f'\n  Per-pitch-class adjacent gap summary (threshold={gap_threshold}¢):')
    print(f'  {"Note":<5}  {"Occurs":>7}  {"Jumps":>6}  {"Jump%":>6}  {"MeanGap":>8}  {"MaxGap":>7}')
    print(f'  {"----":<5}  {"------":>7}  {"-----":>6}  {"-----":>6}  {"-------":>8}  {"------":>7}')
    for pc, _ in pitch_class_counts.most_common():
        jumps = [g for _, g in pc_gaps.get(pc, []) if g > gap_threshold]
        all_pc = [g for _, g in pc_gaps.get(pc, [])]
        if not all_pc:
            continue
        pct = 100.0 * len(jumps) / len(all_pc) if all_pc else 0.0
        flag = ' <--' if len(jumps) > 0 else ''
        print(f'  {keys[pc]:<5}  {pitch_class_counts[pc]:>7}  {len(jumps):>6}  {pct:>5.1f}%'
              f'  {np.mean(all_pc):>8.1f}  {np.max(all_pc):>7.1f}{flag}')


def main():
    parser = argparse.ArgumentParser(
        description='Analyze adjacent-chord pitch-class cent gaps in a tuned chorale')
    parser.add_argument('--numpy_dir', type=str, required=True,
                        help='Directory containing the tuned numpy files')
    parser.add_argument('--chorale_list', type=str, nargs='+', default=['bwv253'],
                        help='Chorale versions to analyze (default: bwv253)')
    parser.add_argument('--suffix', type=str, default='-opt.npy',
                        help='File suffix to analyze (default: -opt.npy)')
    parser.add_argument('--gap_threshold', type=int, default=15,
                        help='Flag gaps larger than this many cents (default: 15)')
    parser.add_argument('--top', type=int, default=20,
                        help='Number of worst gaps to list (default: 20)')
    args = parser.parse_args()

    numpy_dir = (args.numpy_dir if os.path.isabs(args.numpy_dir)
                 else os.path.join(base_dir, args.numpy_dir))

    for version in args.chorale_list:
        analyze_adjacent_spread(numpy_dir, version, args.suffix,
                                gap_threshold=args.gap_threshold,
                                top_n=args.top)


if __name__ == '__main__':
    main()
