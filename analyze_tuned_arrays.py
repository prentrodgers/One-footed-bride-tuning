#!/usr/bin/env python3
"""
analyze_tuned_arrays.py

Analyze tuned numpy cent-value arrays for ratio score and spread, regardless
of directory naming convention. Works with Archive/opt or any directory layout.

Usage:
    # Analyze all chorales across Archive/opt tolerance directories:
    python analyze_tuned_arrays.py Archive/opt/tolerance-*

    # Analyze specific chorales:
    python analyze_tuned_arrays.py Archive/opt/tolerance-* --chorale_list bwv253 bwv254

    # Analyze specific files directly:
    python analyze_tuned_arrays.py --files Archive/opt/tolerance-1/bwv253-trans-sa-opt.npy \
                                           Archive/opt/tolerance-2/bwv253-trans-sa-opt.npy

    # Custom suffix and limit_max:
    python analyze_tuned_arrays.py Archive/opt/tolerance-* --suffix=-sa-opt.npy --limit_max 19
"""

import argparse
import os
import re
import sys
from collections import Counter, defaultdict

import numpy as np

base_dir = os.path.dirname(os.path.abspath(__file__))
if base_dir not in sys.path:
    sys.path.insert(0, base_dir)

import adaptive_tuning_util as atu


def compute_spread_score(cent_value_chorale_4n, chorale):
    """Worst-case pitch-class tuning consistency (lower is better).

    Returns the maximum circular MAD across all pitch classes — the single most
    inconsistently-tuned note name in the piece.
    """
    pitch_class_counts = Counter((chorale % 12).flatten().tolist())
    pc_cents = defaultdict(list)
    for chord_cents in cent_value_chorale_4n.T:
        pcs = atu.pitch_class_from_cents(chord_cents)
        for pc, cv in zip(pcs, chord_cents):
            pc_cents[int(pc)].append(float(cv))
    max_mad = 0.0
    for pc in pitch_class_counts:
        cvs = pc_cents.get(pc, [])
        if len(cvs) < 2:
            continue
        max_mad = max(max_mad, atu.circular_mad(cvs))
    return max_mad


def score_array(cent_4n, tonal_diamond, tolerance):
    """Return (mean_score, max_score, max_chord_idx) for a (4, N) array."""
    chord_scorer = atu.ChordScorer(tonal_diamond)
    scores = np.array([
        chord_scorer.score_chord(cent_4n[:, i], tolerance=tolerance)
        for i in range(cent_4n.shape[1])
    ])
    p80, p90 = np.percentile(scores, [80, 90]).astype(int)
    return float(np.mean(scores)), float(np.max(scores)), int(np.argmax(scores)), p80, p90


def check_pitch_classes(cent_4n, chorale):
    """Check that tuned cent values match the original MIDI pitch classes.

    Returns (n_mismatches, total_notes, mismatch_details) where mismatch_details
    is a list of (chord_idx, voice_idx, expected_pc, actual_pc) tuples.
    """
    n_chords = cent_4n.shape[1]
    mismatches = []
    total = 0
    for chord_idx in range(n_chords):
        midi_chord = chorale.T[chord_idx]
        expected_pcs = midi_chord % 12
        actual_pcs = atu.pitch_class_from_cents(cent_4n[:, chord_idx])
        for voice_idx in range(cent_4n.shape[0]):
            total += 1
            if int(actual_pcs[voice_idx]) != int(expected_pcs[voice_idx]):
                mismatches.append((chord_idx, voice_idx,
                                   int(expected_pcs[voice_idx]),
                                   int(actual_pcs[voice_idx])))
    return len(mismatches), total, mismatches


def discover_chorales(directories, suffix):
    """Find all chorale names available across the given directories."""
    chorales = set()
    for d in directories:
        if not os.path.isdir(d):
            continue
        for f in os.listdir(d):
            if f.endswith(suffix):
                name = f[:-len(suffix)]
                chorales.add(name)
    return sorted(chorales)


def main():
    parser = argparse.ArgumentParser(
        description='Analyze tuned numpy arrays for ratio score and spread')
    parser.add_argument('directories', nargs='*',
                        help='Directories containing tuned .npy files')
    parser.add_argument('--files', nargs='+', default=None,
                        help='Analyze specific .npy files directly (alternative to directories)')
    parser.add_argument('--chorale_list', nargs='+', default=None,
                        help='Chorale names to evaluate (default: auto-discover all)')
    parser.add_argument('--suffix', type=str, default='-trans-sa-opt.npy',
                        help='File suffix for tuned arrays (default: -trans-sa-opt.npy)')
    parser.add_argument('--spread_weight', type=float, default=0.5,
                        help='Weight of spread in combined metric (default: 0.5)')
    parser.add_argument('--tolerance', type=int, default=1,
                        help='Cent tolerance for ChordScorer (default: 1)')
    parser.add_argument('--limit_max', type=int, default=23,
                        help='Tonal diamond limit_max (default: 23)')
    args = parser.parse_args()

    if not args.directories and not args.files:
        parser.error('Provide either directories or --files')

    tonal_diamond = atu.build_tonal_diamond(args.limit_max)[:-1]

    # Mode 1: analyze specific files directly
    if args.files:
        print(f'\n{"=" * 90}')
        print(f'Analyzing {len(args.files)} file(s)  (tolerance={args.tolerance}, '
              f'limit_max={args.limit_max}, spread_weight={args.spread_weight})')
        print(f'{"=" * 90}')
        print(f'  {"File":<55} {"Mean":>6} {"Max":>6} {"MaxCh":>6} {"Top2dec":>10} {"Spread":>8} {"Combined":>10} {"PCerr":>6}')
        print(f'  {"-" * 55} {"-----":>6} {"-----":>6} {"-----":>6} {"--------":>10} {"-------":>8} {"---------":>10} {"-----":>6}')

        results = []
        for fpath in args.files:
            fpath = os.path.abspath(fpath)
            if not os.path.exists(fpath):
                print(f'  {fpath}: not found')
                continue
            # Extract chorale name from filename
            fname = os.path.basename(fpath)
            if not fname.endswith(args.suffix):
                print(f'  {fname}: does not match suffix {args.suffix}')
                continue
            version = fname[:-len(args.suffix)]
            d = os.path.dirname(fpath)
            try:
                cent_4n = np.load(fpath, allow_pickle=True)
                _, _, chorale, _, _, _ = atu.load_chorale_in_cents(
                    version, d, twelve_tet=True, save_top_notes=False)
            except Exception as e:
                print(f'  {fname}: could not load -- {e}')
                continue

            mean_sc, max_sc, max_ch, p80, p90 = score_array(cent_4n, tonal_diamond, args.tolerance)
            spread = compute_spread_score(cent_4n, chorale)
            combined = mean_sc + args.spread_weight * spread
            n_pc_err, _, pc_details = check_pitch_classes(cent_4n, chorale)
            label = os.path.join(os.path.basename(d), fname)
            results.append((combined, mean_sc, max_sc, max_ch, p80, p90, spread, label, n_pc_err, pc_details))

        results.sort(key=lambda x: x[0])
        for i, (combined, mean_sc, max_sc, max_ch, p80, p90, spread, label, n_pc_err, pc_details) in enumerate(results):
            marker = ' <-- BEST' if i == 0 and len(results) > 1 else ''
            pc_str = f'{n_pc_err:>6}' if n_pc_err == 0 else f'{n_pc_err:>5}!'
            print(f'  {label:<55} {mean_sc:>6.1f} {max_sc:>6.0f} {max_ch:>6} {p80:>4} {p90:>4} {spread:>8.1f} {combined:>10.1f} {pc_str}{marker}')
            if n_pc_err > 0:
                for chord_idx, voice_idx, exp_pc, act_pc in pc_details[:10]:
                    print(f'      chord {chord_idx}, voice {voice_idx}: expected PC {exp_pc}, got PC {act_pc}')
                if n_pc_err > 10:
                    print(f'      ... and {n_pc_err - 10} more')
        return

    # Mode 2: scan directories for chorales
    dirs = []
    for d in args.directories:
        d = d if os.path.isabs(d) else os.path.join(base_dir, d)
        if os.path.isdir(d):
            dirs.append(d)
        else:
            print(f'Warning: {d} is not a directory, skipping')

    if not dirs:
        print('No valid directories found')
        return

    chorale_list = args.chorale_list or discover_chorales(dirs, args.suffix)
    if not chorale_list:
        print(f'No files matching suffix "{args.suffix}" found in the given directories')
        return

    print(f'\nFound {len(chorale_list)} chorale(s) across {len(dirs)} directory/directories')
    print(f'\n{"=" * 90}')
    print(f'Options: tolerance={args.tolerance}, limit_max={args.limit_max}, '
          f'spread_weight={args.spread_weight}')
    print(f'{"=" * 90}')

    # When multiple directories, show per-directory breakdown per chorale
    if len(dirs) > 1:
        print(f'  {"Chorale":<10} {"Directory":<45} {"Mean":>6} {"Max":>6} {"MaxCh":>6} {"Top2dec":>10} {"Spread":>8} {"Combined":>10} {"PCerr":>6}')
        print(f'  {"-" * 10} {"-" * 45} {"-----":>6} {"-----":>6} {"-----":>6} {"--------":>10} {"-------":>8} {"---------":>10} {"-----":>6}')

        for version in chorale_list:
            results = []
            for d in dirs:
                input_file = os.path.join(d, f'{version}{args.suffix}')
                if not os.path.exists(input_file):
                    continue
                try:
                    cent_4n = np.load(input_file, allow_pickle=True)
                    _, _, chorale, _, _, _ = atu.load_chorale_in_cents(
                        version, d, twelve_tet=True, save_top_notes=False)
                except Exception as e:
                    print(f'  {version:<10} {os.path.basename(d):<45} could not load -- {e}')
                    continue

                mean_sc, max_sc, max_ch, p80, p90 = score_array(cent_4n, tonal_diamond, args.tolerance)
                spread = compute_spread_score(cent_4n, chorale)
                combined = mean_sc + args.spread_weight * spread
                n_pc_err, _, pc_details = check_pitch_classes(cent_4n, chorale)
                results.append((combined, mean_sc, max_sc, max_ch, p80, p90, spread, d, n_pc_err, pc_details))

            if not results:
                print(f'  {version:<10} No results found')
                continue

            results.sort(key=lambda x: x[0])
            for i, (combined, mean_sc, max_sc, max_ch, p80, p90, spread, d, n_pc_err, pc_details) in enumerate(results):
                marker = ' <-- BEST' if i == 0 and len(results) > 1 else ''
                pc_str = f'{n_pc_err:>6}' if n_pc_err == 0 else f'{n_pc_err:>5}!'
                print(f'  {version:<10} {os.path.basename(d):<45} {mean_sc:>6.1f} {max_sc:>6.0f} {max_ch:>6} {p80:>4} {p90:>4} {spread:>8.1f} {combined:>10.1f} {pc_str}{marker}')
                if n_pc_err > 0:
                    for chord_idx, voice_idx, exp_pc, act_pc in pc_details[:10]:
                        print(f'      chord {chord_idx}, voice {voice_idx}: expected PC {exp_pc}, got PC {act_pc}')
                    if n_pc_err > 10:
                        print(f'      ... and {n_pc_err - 10} more')
    else:
        # Single directory: one line per chorale
        print(f'  {"Chorale":<10} {"Mean":>6} {"Max":>6} {"MaxCh":>6} {"Top2dec":>10} {"Spread":>8} {"Combined":>10} {"PCerr":>6}')
        print(f'  {"-" * 10} {"-----":>6} {"-----":>6} {"-----":>6} {"--------":>10} {"-------":>8} {"---------":>10} {"-----":>6}')

        for version in chorale_list:
            d = dirs[0]
            input_file = os.path.join(d, f'{version}{args.suffix}')
            if not os.path.exists(input_file):
                print(f'  {version:<10} not found')
                continue
            try:
                cent_4n = np.load(input_file, allow_pickle=True)
                _, _, chorale, _, _, _ = atu.load_chorale_in_cents(
                    version, d, twelve_tet=True, save_top_notes=False)
            except Exception as e:
                print(f'  {version:<10} could not load -- {e}')
                continue

            mean_sc, max_sc, max_ch, p80, p90 = score_array(cent_4n, tonal_diamond, args.tolerance)
            spread = compute_spread_score(cent_4n, chorale)
            combined = mean_sc + args.spread_weight * spread
            n_pc_err, _, pc_details = check_pitch_classes(cent_4n, chorale)
            pc_str = f'{n_pc_err:>6}' if n_pc_err == 0 else f'{n_pc_err:>5}!'
            print(f'  {version:<10} {mean_sc:>6.1f} {max_sc:>6.0f} {max_ch:>6} {p80:>4} {p90:>4} {spread:>8.1f} {combined:>10.1f} {pc_str}')
            if n_pc_err > 0:
                for chord_idx, voice_idx, exp_pc, act_pc in pc_details[:10]:
                    print(f'      chord {chord_idx}, voice {voice_idx}: expected PC {exp_pc}, got PC {act_pc}')
                if n_pc_err > 10:
                    print(f'      ... and {n_pc_err - 10} more')

    print()


if __name__ == '__main__':
    main()
