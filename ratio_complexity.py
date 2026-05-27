#!/usr/bin/env python3
"""
Count pairwise intervals in cent-tuning arrays that require numerator or
denominator > THRESHOLD to express as a just ratio, then plot a summary chart.

Usage:
    python ratio_complexity.py
    python ratio_complexity.py --threshold 11 --tolerance 2
    python ratio_complexity.py --tuning_dir Archive/straw-man/best-tunings
    python ratio_complexity.py --tuning_dir Archive/12-TET --suffix=-12-TET-cents.npy
"""
import argparse
import fractions
import sys
from collections import defaultdict
from itertools import combinations
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.ticker import ScalarFormatter

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


def high_ratio_count(
    cent_array: np.ndarray,
    threshold: int,
    tolerance: int,
    limit_denominator: int,
    tonal_diamond: np.ndarray,
):
    """Return (n_high, n_total_intervals, n_chords, n_closest_fallback) for a (4, N) cent array.

    For each chord (column), all pairwise intervals are matched to the best
    tonal-diamond ratio within the given tolerance. An interval is 'high' if
    the selected ratio's numerator OR denominator exceeds threshold.
    """
    voices, n_chords = cent_array.shape
    voice_pairs = list(combinations(range(voices), 2))
    n_high = 0
    n_total = 0
    n_closest_fallback = 0
    cents_values = tonal_diamond[:, 1]
    for chord in cent_array.T:          # iterate over columns
        for i, j in voice_pairs:
            delta = atu.cent_distance_mod_1200(float(chord[i]), float(chord[j]))
            rounded_delta = int(round(delta))

            # Mirror best_ratio_index search criterion to detect fallback use.
            found_exact_within_tolerance = False
            for gap in range(-tolerance, tolerance + 1):
                target = rounded_delta + gap
                insert_at = min(np.searchsorted(cents_values, target), len(cents_values) - 1)
                if cents_values[insert_at] == target:
                    found_exact_within_tolerance = True
                    break

            idx = atu.best_ratio_index(rounded_delta, tolerance, tonal_diamond)
            matched_ratio = tonal_diamond[idx, 0]
            f = fractions.Fraction(float(matched_ratio)).limit_denominator(limit_denominator)
            if f.numerator > threshold or f.denominator > threshold:
                n_high += 1
            if not found_exact_within_tolerance:
                n_closest_fallback += 1
            n_total += 1
    return n_high, n_total, n_chords, n_closest_fallback


def main():
    parser = argparse.ArgumentParser(description='Ratio complexity of cent-tuning arrays')
    parser.add_argument('--tuning_dir', default='Archive/straw-man/best-tunings',
                        help='Directory containing *-trans-sa-opt.npy files')
    parser.add_argument('--suffix', default='-trans-sa-opt.npy',
                        help='Filename suffix after chorale name (default: -trans-sa-opt.npy)')
    parser.add_argument('--threshold', type=int, default=9,
                        help='Flag ratios where numerator or denominator exceeds this (default: 9)')
    parser.add_argument('--tolerance', type=int, default=1,
                        help='Cent tolerance used by best_ratio_index when matching intervals (default: 1)')
    parser.add_argument('--limit_max', type=int, default=17,
                        help='Prime-limit used to build tonal_diamond via build_tonal_diamond (default: 17)')
    parser.add_argument('--limit_denominator', type=int, default=50,
                        help='Max denominator when approximating ratios (default: 50)')
    args = parser.parse_args()

    tuning_dir = Path(args.tuning_dir)
    if not tuning_dir.is_dir():
        sys.exit(f'Directory not found: {tuning_dir}')

    tonal_diamond = atu.build_tonal_diamond(
        limit_value=args.limit_max,
        limit_denominator=args.limit_denominator,
    )

    rows = []
    for chorale in CHORALE_ORDER:
        matches = sorted(tuning_dir.glob(f'{chorale}*{args.suffix}'))
        if not matches:
            print(f'  missing: {tuning_dir}/{chorale}*{args.suffix}')
            continue
        path = matches[0]
        arr = np.load(path)
        n_high, n_total, n_chords, n_closest_fallback = high_ratio_count(
            arr,
            args.threshold,
            args.tolerance,
            args.limit_denominator,
            tonal_diamond,
        )
        pct = 100.0 * n_high / n_total if n_total else 0.0
        fallback_pct = 100.0 * n_closest_fallback / n_total if n_total else 0.0
        spread = pitch_class_spread(arr)
        rows.append((chorale, n_high, n_total, n_chords, pct, spread, n_closest_fallback, fallback_pct))
        print(f'{chorale}: {n_high}/{n_total} high-ratio intervals ({pct:.1f}%)  —  {n_chords} chords  —  spread {spread:.1f} cents')
        print(f'         closest-below fallback: {n_closest_fallback}/{n_total} ({fallback_pct:.1f}%)')

    if not rows:
        sys.exit('No data found.')

    # --- chart ---
    labels   = [r[0] for r in rows]
    n_high   = [r[1] for r in rows]
    n_chords = [r[3] for r in rows]
    pcts     = [r[4] for r in rows]
    spreads  = [r[5] for r in rows]
    # Clamp floating-point noise so exact-12TET cases plot as true zero.
    spreads = [0.0 if abs(s) < 1e-9 else s for s in spreads]
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
    spread_max = max(spreads) if spreads else 0.0
    ax3.set_ylim(0, spread_max * 1.4 if spread_max > 0 else 1.0)
    ax3.yaxis.set_major_formatter(ScalarFormatter(useOffset=False))
    ax3.ticklabel_format(axis='y', style='plain')

    fig.suptitle(
        f'Ratio complexity in {tuning_dir.name}  '
        f'(threshold: num or denom > {args.threshold}, tolerance={args.tolerance}, '
        f'limit_max={args.limit_max}, limit_denominator={args.limit_denominator})',
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
