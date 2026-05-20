#!/usr/bin/env python3
"""
Count pairwise intervals in cent-tuning arrays that require numerator or
denominator > THRESHOLD to express as a just ratio, then plot a summary chart.

Usage:
    python ratio_complexity.py
    python ratio_complexity.py --threshold 11 --limit_denominator 100
    python ratio_complexity.py --tuning_dir Archive/straw-man/best-tunings
"""
import argparse
import sys
from collections import defaultdict
from fractions import Fraction
from itertools import combinations
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

import adaptive_tuning_util as atu


CHORALE_ORDER = [f'bwv{n}' for n in range(253, 265)]


def pitch_class_spread(cent_array: np.ndarray) -> float:
    """Worst-case circular MAD of tuning values per pitch class.

    Matches the spread metric in select_best_and_render.py: for every pitch
    class present in the piece, compute how consistently it is tuned (circular
    MAD in cents), then return the maximum — the single most inconsistently
    tuned note name drives the score.
    """
    pc_cents = defaultdict(list)
    for chord in cent_array.T:
        pcs = atu.pitch_class_from_cents(chord)
        for pc, cv in zip(pcs, chord):
            pc_cents[int(pc)].append(float(cv))
    if not pc_cents:
        return 0.0
    return max(atu.circular_mad(cvs) for cvs in pc_cents.values() if len(cvs) >= 2)


def high_ratio_count(cent_array: np.ndarray, threshold: int, limit_denominator: int):
    """Return (n_high, n_total_intervals, n_chords) for a (4, N) cent array.

    For each chord (column) all 6 pairwise absolute intervals are converted to
    the nearest just ratio.  An interval is 'high' if its numerator OR
    denominator exceeds threshold.
    """
    voices, n_chords = cent_array.shape
    voice_pairs = list(combinations(range(voices), 2))
    n_high = 0
    n_total = 0
    for chord in cent_array.T:          # iterate over columns
        for i, j in voice_pairs:
            delta = abs(float(chord[i]) - float(chord[j]))
            f = Fraction(2 ** (delta / 1200)).limit_denominator(limit_denominator)
            if f.numerator > threshold or f.denominator > threshold:
                n_high += 1
            n_total += 1
    return n_high, n_total, n_chords


def main():
    parser = argparse.ArgumentParser(description='Ratio complexity of cent-tuning arrays')
    parser.add_argument('--tuning_dir', default='Archive/straw-man/best-tunings',
                        help='Directory containing *-trans-sa-opt.npy files')
    parser.add_argument('--threshold', type=int, default=9,
                        help='Flag ratios where numerator or denominator exceeds this (default: 9)')
    parser.add_argument('--limit_denominator', type=int, default=50,
                        help='Max denominator when approximating ratios (default: 50)')
    args = parser.parse_args()

    tuning_dir = Path(args.tuning_dir)
    if not tuning_dir.is_dir():
        sys.exit(f'Directory not found: {tuning_dir}')

    rows = []
    for chorale in CHORALE_ORDER:
        matches = sorted(tuning_dir.glob(f'{chorale}*-trans-sa-opt.npy'))
        if not matches:
            print(f'  missing: {tuning_dir}/{chorale}*-trans-sa-opt.npy')
            continue
        path = matches[0]
        arr = np.load(path)
        n_high, n_total, n_chords = high_ratio_count(arr, args.threshold, args.limit_denominator)
        pct = 100.0 * n_high / n_total if n_total else 0.0
        spread = pitch_class_spread(arr)
        rows.append((chorale, n_high, n_total, n_chords, pct, spread))
        print(f'{chorale}: {n_high}/{n_total} high-ratio intervals ({pct:.1f}%)  —  {n_chords} chords  —  spread {spread:.1f} cents')

    if not rows:
        sys.exit('No data found.')

    # --- chart ---
    labels   = [r[0] for r in rows]
    n_high   = [r[1] for r in rows]
    n_chords = [r[3] for r in rows]
    pcts     = [r[4] for r in rows]
    spreads  = [r[5] for r in rows]
    x        = np.arange(len(labels))
    width    = 0.55

    fig, ax1 = plt.subplots(figsize=(13, 7.8))
    fig.subplots_adjust(right=0.82)

    bars = ax1.bar(x, n_high, width, color='steelblue', alpha=0.8, label='High-ratio intervals')
    ax1.set_ylabel(f'Intervals with num or denom > {args.threshold}', color='steelblue')
    ax1.tick_params(axis='y', labelcolor='steelblue')
    ax1.set_xticks(x)
    ax1.set_xticklabels(labels, rotation=30, ha='right')

    # annotate each bar: chord count on top, percentage inside
    for bar, nc, pct in zip(bars, n_chords, pcts):
        h = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width() / 2, h + 0.5,
                 f'{nc} chords', ha='center', va='bottom', fontsize=8, color='steelblue')
        if h > 2:
            ax1.text(bar.get_x() + bar.get_width() / 2, h / 2,
                     f'{pct:.0f}%', ha='center', va='center', fontsize=9,
                     color='white', fontweight='bold')

    ax2 = ax1.twinx()
    ax2.plot(x, pcts, 'o--', color='tomato', linewidth=1.5, markersize=6, label='% high-ratio')
    ax2.set_ylabel('% of intervals that are high-ratio', color='tomato')
    ax2.tick_params(axis='y', labelcolor='tomato')
    ax2.set_ylim(0, max(pcts) * 1.4 if pcts else 100)

    ax3 = ax1.twinx()
    ax3.spines['right'].set_position(('outward', 65))
    ax3.plot(x, spreads, 's-.', color='seagreen', linewidth=1.5, markersize=6, label='pitch-class spread (cents)')
    ax3.set_ylabel('Pitch-class spread (cents)', color='seagreen')
    ax3.tick_params(axis='y', labelcolor='seagreen')
    ax3.set_ylim(0, max(spreads) * 1.4 if spreads else 50)

    fig.suptitle(
        f'Ratio complexity in {tuning_dir.name}  '
        f'(threshold: num or denom > {args.threshold}, limit_denominator={args.limit_denominator})',
        fontsize=11
    )
    lines1, labels1 = ax1.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    lines3, labels3 = ax3.get_legend_handles_labels()
    ax1.legend(lines1 + lines2 + lines3, labels1 + labels2 + labels3, loc='upper left', fontsize=9)

    out_path = tuning_dir / 'ratio_complexity.png'
    fig.savefig(out_path, dpi=150)
    print(f'\nChart saved to {out_path}')
    plt.show()


if __name__ == '__main__':
    main()
