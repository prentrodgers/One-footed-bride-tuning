#!/usr/bin/env python3
"""
analyze_spread.py

Report the cent-value spread per pitch class for a tuned chorale numpy array.
Mirrors the final cell of Chorale-info.ipynb; designed to be called from grid_search.sh.

Usage:
    python analyze_spread.py --numpy_dir Archive/straw-man/t1_r1.0_s0_md33_sn0 \
        --chorale_list bwv253 --suffix="-trans-sa-opt.npy"
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


def analyze_spread(numpy_dir, version, suffix, wide_spread_threshold=50):
    input_file = os.path.join(numpy_dir, f'{version}{suffix}')
    try:
        cent_value_chorale = np.load(input_file)
    except Exception as e:
        print(f'Could not load {input_file}: {e}')
        return

    try:
        # twelve_tet=True bypasses top_notes lookup; we only need chorale/root/mode/keys
        _, _, chorale, root, mode, keys = atu.load_chorale_in_cents(
            version, numpy_dir, twelve_tet=True, save_top_notes=False)
    except Exception as e:
        print(f'Could not load chorale {version}: {e}')
        return

    print(f'\n{input_file}')
    print(f'Original chorale key: {keys[root]} {mode}')

    pitch_class_counts = Counter((chorale % 12).flatten())
    print('Pitch classes sorted by frequency in original chorale:')
    for note, freq in pitch_class_counts.most_common(5):
        print(f'{keys[note]}: {freq}', end='\t')
    print()

    pc_cent_values = defaultdict(list)
    for chord_cents in cent_value_chorale.T:
        pcs = atu.pitch_class_from_cents(chord_cents)
        for pc, cv in zip(pcs, chord_cents):
            pc_cent_values[int(pc)].append(float(cv))

    print(f'{"Note":<5} {"Occurs":>7}  {"Min":>6}  {"Max":>6}  {"Range":>6}  Unique cent values (rounded)')
    print('-' * 90)
    for note, occurrences in pitch_class_counts.most_common():
        cvs_raw = pc_cent_values.get(note, [])
        if not cvs_raw:
            continue
        cvs = sorted(set(round(v) for v in cvs_raw))
        spread, lo, hi = atu.circular_span(cvs)
        spread = round(spread)
        flag = ' <-- wide spread' if spread > wide_spread_threshold else ''
        print(f'{keys[note]:<5} {occurrences:>7}  {lo:>6}  {hi:>6}  {spread:>6}  {cvs}{flag}')


def main():
    parser = argparse.ArgumentParser(
        description='Analyze cent value spread per pitch class in a tuned chorale numpy array')
    parser.add_argument('--numpy_dir', type=str, required=True,
                        help='Directory containing the tuned numpy files')
    parser.add_argument('--chorale_list', type=str, nargs='+', default=['bwv253'],
                        help='Chorale versions to analyze (default: bwv253)')
    parser.add_argument('--suffix', type=str, default='-opt.npy',
                        help='File suffix to analyze (default: -opt.npy)')
    parser.add_argument('--wide_spread_threshold', type=int, default=50,
                        help='Flag spreads wider than this many cents (default: 50)')
    args = parser.parse_args()

    numpy_dir = args.numpy_dir if os.path.isabs(args.numpy_dir) else os.path.join(base_dir, args.numpy_dir)

    for version in args.chorale_list:
        analyze_spread(numpy_dir, version, args.suffix, args.wide_spread_threshold)


if __name__ == '__main__':
    main()
