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
from itertools import combinations

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


def score_array(cent_4n, tonal_diamond, tolerance, index_map=None):
    """Return (mean_score, max_score, max_chord_idx) for a (4, N) array."""
    chord_scorer = atu.ChordScorer(tonal_diamond)
    scores = np.array([
        chord_scorer.score_chord(cent_4n[:, i], tolerance=tolerance)
        for i in range(cent_4n.shape[1])
    ])
    max_local = int(np.argmax(scores))
    max_idx = int(index_map[max_local]) if index_map is not None else max_local
    p80, p90 = np.percentile(scores, [80, 90]).astype(int)
    return float(np.mean(scores)), float(np.max(scores)), max_idx, p80, p90


def print_chords_analysis(
    version,
    cent_4n,
    chorale,
    keys,
    tonal_diamond,
    tolerance,
    include_set=None,
    print_individual_chords=False,
    ratios=False,
):
    """Print notebook-style per-chord diagnostics from tuned cent arrays.

    Mirrors the core behavior of Chorale-info.ipynb print_chords for chord and
    ratio interval reporting. Top-note and cache-hit outputs are intentionally
    excluded.
    """
    if not (print_individual_chords or ratios):
        return

    chord_scorer = atu.ChordScorer(tonal_diamond)
    if print_individual_chords:
        print('\n#          cents       note names   chord score')

    prev_chord = np.zeros(4, dtype=int)
    header = ' # Fr/To Cents Ratio\t # Fr/To Cents Ratio\t # Fr/To Cents Ratio'
    cents_int = np.rint(cent_4n).astype(int)

    for chord_idx, (chord_in_cents, chord_12) in enumerate(zip(cents_int.T, chorale.T)):
        if include_set is not None and chord_idx not in include_set:
            continue
        if np.array_equal(prev_chord, chord_in_cents):
            continue

        tuned_pcs = np.array(atu.pitch_class_from_cents(chord_in_cents), dtype=int) % 12

        if print_individual_chords:
            pitches = ' '.join(map(str, keys[tuned_pcs]))
            score = chord_scorer.score_chord(chord_in_cents, tolerance=tolerance)
            print(f'{chord_idx}: {atu.format_chord(chord_in_cents, 4)}\t{pitches}\t{score}')

        if ratios:
            print(header)
            intervals = []
            for inx1, inx2 in combinations(np.arange(4), 2):
                cent_value_interval_pair = np.array([chord_in_cents[inx1], chord_in_cents[inx2]])
                cent_value_delta, _, _ = atu.cent_value_interval(cent_value_interval_pair)
                best_idx = chord_scorer.find_best_interval(cent_value_delta, tolerance)[0]
                ratio = str(atu.limit_format(tonal_diamond[best_idx])[0]).strip()
                n1 = keys[tuned_pcs[inx1]]
                n2 = keys[tuned_pcs[inx2]]
                intervals.append((n1, n2, cent_value_delta, ratio))

            def fmt(iv, idx):
                n1, n2, cents, ratio = iv
                return f'{idx:>2} {n1:>2} {n2:>2} {cents:>5} {ratio:^6}'

            print('   '.join(fmt(iv, i + 1) for i, iv in enumerate(intervals[:3])))
            print('   '.join(fmt(iv, i + 4) for i, iv in enumerate(intervals[3:])))

        prev_chord = chord_in_cents.copy()


def select_chord_subset(cent_4n, chorale, include_list):
    """Return arrays restricted to the requested chord indices.

    Raises ValueError if indices are out of range or no valid indices are left.
    """
    n_chords = cent_4n.shape[1]
    if include_list is None:
        return cent_4n, chorale, np.arange(n_chords, dtype=int)

    include_idx = np.array(include_list, dtype=int)
    if include_idx.size == 0:
        return cent_4n, chorale, np.arange(n_chords, dtype=int)
    bad = include_idx[(include_idx < 0) | (include_idx >= n_chords)]
    if bad.size > 0:
        raise ValueError(
            f'--include_list has out-of-range chord index/indices {bad.tolist()} for n_chords={n_chords}'
        )
    include_idx = np.unique(include_idx)
    return cent_4n[:, include_idx], chorale[:, include_idx], include_idx


def select_chord_subset_with_slice(cent_4n, chorale, include_list, include_slice):
    """Return arrays restricted by raw include_list and raw include_slice.

    include_list is interpreted as raw chord indices.
    include_slice is interpreted as raw [START, END) indices on uncompressed
    arrays.
    """
    n_chords = cent_4n.shape[1]
    if include_list is None and include_slice is None:
        return cent_4n, chorale, np.arange(n_chords, dtype=int)

    selected_raw = set()

    if include_list is not None:
        include_idx = np.array(include_list, dtype=int)
        if include_idx.size > 0:
            bad = include_idx[(include_idx < 0) | (include_idx >= n_chords)]
            if bad.size > 0:
                raise ValueError(
                    f'--include_list has out-of-range chord index/indices {bad.tolist()} for n_chords={n_chords}'
                )
            selected_raw.update(np.unique(include_idx).tolist())

    if include_slice is not None:
        start, end = include_slice
        if start < 0 or end > n_chords:
            raise ValueError(
                f'--include_slice expects raw [START, END) in 0..{n_chords}, got START={start}, END={end}'
            )
        if end <= start:
            raise ValueError(
                f'--include_slice expects END > START, got START={start}, END={end}'
            )
        selected_raw.update(range(start, end))

    if not selected_raw:
        raise ValueError('No chord indices selected after applying --include_list/--include_slice')

    include_idx = np.array(sorted(selected_raw), dtype=int)
    return cent_4n[:, include_idx], chorale[:, include_idx], include_idx


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
                m = re.match(r'^(bwv\d+)', f)
                if m:
                    chorales.add(m.group(1))
    return sorted(chorales)


def resolve_input_file(directory, version, suffix):
    """Resolve a chorale file in directory using exact or wildcard suffix match.

    Priority:
    1. exact: {version}{suffix}
    2. wildcard: {version}*{suffix} (lexicographically first)
    """
    exact = os.path.join(directory, f'{version}{suffix}')
    if os.path.exists(exact):
        return exact, 1

    matches = sorted(
        os.path.join(directory, f)
        for f in os.listdir(directory)
        if f.startswith(version) and f.endswith(suffix)
    )
    if not matches:
        return None, 0
    return matches[0], len(matches)


def parse_params_from_filename(file_path):
    """Extract tolerance and limit_max from filename tokens like _t3_ and _lm19."""
    name = os.path.basename(file_path)
    tol_match = re.search(r'(?:^|_)t(\d+)', name)
    lm_match = re.search(r'(?:^|_)lm(\d+)', name)
    tolerance = int(tol_match.group(1)) if tol_match else None
    limit_max = int(lm_match.group(1)) if lm_match else None
    return tolerance, limit_max


def resolve_analysis_params(file_path, args, cli_tolerance_explicit, cli_limit_max_explicit):
    """Resolve per-file analysis params with filename-derived values when available.

    Priority:
    1) Explicit CLI values for --tolerance/--limit_max.
    2) Filename tokens _tN / _lmN.
    3) Arg defaults.
    """
    t_from_name, lm_from_name = parse_params_from_filename(file_path)

    tolerance = args.tolerance if cli_tolerance_explicit else (
        t_from_name if t_from_name is not None else args.tolerance
    )
    limit_max = args.limit_max if cli_limit_max_explicit else (
        lm_from_name if lm_from_name is not None else args.limit_max
    )
    return tolerance, limit_max


def main():
    parser = argparse.ArgumentParser(
        description='Analyze tuned numpy arrays for ratio score and spread')
    parser.add_argument('input_directory_positional', nargs='*',
                        help='Directory/directories containing tuned .npy files')
    parser.add_argument('--input_directory', nargs='+', default=None,
                        help='Directory/directories containing tuned .npy files')
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
    parser.add_argument('--include_list', nargs='+', type=int, default=None,
                        help='Raw chord indices to include for all scores/metrics (e.g., --include_list 224 225)')
    parser.add_argument('--include_slice', nargs=2, type=int, metavar=('START', 'END'), default=None,
                        help='Raw chord slice [START, END) on uncompressed arrays (e.g., --include_slice 228 280)')
    parser.add_argument('--print_individual_chords', action='store_true',
                        help='Print notebook-style per-chord tuned cents, note names, and chord score')
    parser.add_argument('--ratios', action='store_true',
                        help='Print six interval ratios per printed chord (notebook style)')
    args = parser.parse_args()

    cli_tolerance_explicit = '--tolerance' in sys.argv
    cli_limit_max_explicit = '--limit_max' in sys.argv

    include_list = list(args.include_list) if args.include_list is not None else []
    include_list = include_list or None
    include_slice = args.include_slice
    if include_slice is not None:
        start, end = include_slice
        if end <= start:
            parser.error(f'--include_slice expects END > START, got START={start}, END={end}')

    input_directories = args.input_directory if args.input_directory is not None else args.input_directory_positional

    if not input_directories and not args.files:
        parser.error('Provide either --input_directory arg(s), input_directory positional arg(s), or --files')

    # Mode 1: analyze specific files directly
    if args.files:
        print(f'\n{"=" * 90}')
        print(f'Analyzing {len(args.files)} file(s)  (default tolerance={args.tolerance}, '
              f'default limit_max={args.limit_max}, spread_weight={args.spread_weight}; '
              f'per-file _tN/_lmN filename overrides enabled)')
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
                _, _, chorale, root, mode, keys = atu.load_chorale_in_cents(
                    version, d, twelve_tet=True, save_top_notes=False)
                cent_eval, chorale_eval, include_idx = select_chord_subset_with_slice(
                    cent_4n, chorale, include_list, include_slice
                )
            except Exception as e:
                print(f'  {fname}: could not load -- {e}')
                continue

            tolerance_local, limit_max_local = resolve_analysis_params(
                fpath, args, cli_tolerance_explicit, cli_limit_max_explicit
            )
            tonal_diamond_local = atu.build_tonal_diamond(limit_max_local)

            mean_sc, max_sc, max_ch, p80, p90 = score_array(
                cent_eval,
                tonal_diamond_local,
                tolerance_local,
                index_map=include_idx,
            )
            spread = compute_spread_score(cent_eval, chorale_eval)
            combined = mean_sc + args.spread_weight * spread
            n_pc_err, _, pc_details = check_pitch_classes(cent_eval, chorale_eval)
            label = os.path.join(os.path.basename(d), fname)
            results.append((combined, mean_sc, max_sc, max_ch, p80, p90, spread, label, n_pc_err, pc_details))

            if args.print_individual_chords or args.ratios:
                print(f'\nversion: {version}, tolerance={tolerance_local}, limit_max={limit_max_local}, '
                      f'Average score: {mean_sc:.1f}, max score: {max_sc:.0f} max chord: {max_ch}')
                print_chords_analysis(
                    version=version,
                    cent_4n=cent_4n,
                    chorale=chorale,
                    keys=keys,
                    tonal_diamond=tonal_diamond_local,
                    tolerance=tolerance_local,
                    include_set=set(include_idx.tolist()) if (include_list or include_slice) else None,
                    print_individual_chords=args.print_individual_chords,
                    ratios=args.ratios,
                )

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
    for d in input_directories:
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
    print(f'Options: default tolerance={args.tolerance}, default limit_max={args.limit_max}, '
          f'spread_weight={args.spread_weight} (per-file _tN/_lmN filename overrides enabled)')
    print(f'{"=" * 90}')

    # When multiple directories, show per-directory breakdown per chorale
    if len(dirs) > 1:
        print(f'  {"Chorale":<10} {"Directory":<45} {"Mean":>6} {"Max":>6} {"MaxCh":>6} {"Top2dec":>10} {"Spread":>8} {"Combined":>10} {"PCerr":>6}')
        print(f'  {"-" * 10} {"-" * 45} {"-----":>6} {"-----":>6} {"-----":>6} {"--------":>10} {"-------":>8} {"---------":>10} {"-----":>6}')
        selected_sources = []

        for version in chorale_list:
            results = []
            for d in dirs:
                input_file, n_matches = resolve_input_file(d, version, args.suffix)
                if not input_file:
                    continue
                selected_sources.append((version, os.path.basename(d), input_file, n_matches))
                try:
                    cent_4n = np.load(input_file, allow_pickle=True)
                    _, _, chorale, root, mode, keys = atu.load_chorale_in_cents(
                        version, d, twelve_tet=True, save_top_notes=False)
                    cent_eval, chorale_eval, include_idx = select_chord_subset_with_slice(
                        cent_4n, chorale, include_list, include_slice
                    )
                except Exception as e:
                    print(f'  {version:<10} {os.path.basename(d):<45} could not load -- {e}')
                    continue

                tolerance_local, limit_max_local = resolve_analysis_params(
                    input_file, args, cli_tolerance_explicit, cli_limit_max_explicit
                )
                tonal_diamond_local = atu.build_tonal_diamond(limit_max_local)

                mean_sc, max_sc, max_ch, p80, p90 = score_array(
                    cent_eval,
                    tonal_diamond_local,
                    tolerance_local,
                    index_map=include_idx,
                )
                spread = compute_spread_score(cent_eval, chorale_eval)
                combined = mean_sc + args.spread_weight * spread
                n_pc_err, _, pc_details = check_pitch_classes(cent_eval, chorale_eval)
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

                if args.print_individual_chords or args.ratios:
                    print(f'\nversion: {version}, tolerance={tolerance_local}, limit_max={limit_max_local}, '
                          f'Average score: {mean_sc:.1f}, max score: {max_sc:.0f} max chord: {max_ch}')
                    print_chords_analysis(
                        version=version,
                        cent_4n=cent_4n,
                        chorale=chorale,
                        keys=keys,
                        tonal_diamond=tonal_diamond_local,
                        tolerance=tolerance_local,
                        include_set=set(include_idx.tolist()) if (include_list or include_slice) else None,
                        print_individual_chords=args.print_individual_chords,
                        ratios=args.ratios,
                    )

        if selected_sources:
            print('\nSelected source file(s):')
            for version, dname, input_file, n_matches in selected_sources:
                flag = ' (from multiple matches)' if n_matches > 1 else ''
                print(f'  {version:<10} {dname:<45} {input_file}{flag}')
    else:
        # Single directory: one line per chorale
        print(f'  {"Chorale":<10} {"Mean":>6} {"Max":>6} {"MaxCh":>6} {"Top2dec":>10} {"Spread":>8} {"Combined":>10} {"PCerr":>6}')
        print(f'  {"-" * 10} {"-----":>6} {"-----":>6} {"-----":>6} {"--------":>10} {"-------":>8} {"---------":>10} {"-----":>6}')
        selected_sources = []

        for version in chorale_list:
            d = dirs[0]
            input_file, n_matches = resolve_input_file(d, version, args.suffix)
            if not input_file:
                print(f'  {version:<10} not found')
                continue
            selected_sources.append((version, input_file, n_matches))
            try:
                cent_4n = np.load(input_file, allow_pickle=True)
                _, _, chorale, root, mode, keys = atu.load_chorale_in_cents(
                    version, d, twelve_tet=True, save_top_notes=False)
                cent_eval, chorale_eval, include_idx = select_chord_subset_with_slice(
                    cent_4n, chorale, include_list, include_slice
                )
            except Exception as e:
                print(f'  {version:<10} could not load -- {e}')
                continue

            tolerance_local, limit_max_local = resolve_analysis_params(
                input_file, args, cli_tolerance_explicit, cli_limit_max_explicit
            )
            tonal_diamond_local = atu.build_tonal_diamond(limit_max_local)

            mean_sc, max_sc, max_ch, p80, p90 = score_array(
                cent_eval,
                tonal_diamond_local,
                tolerance_local,
                index_map=include_idx,
            )
            spread = compute_spread_score(cent_eval, chorale_eval)
            combined = mean_sc + args.spread_weight * spread
            n_pc_err, _, pc_details = check_pitch_classes(cent_eval, chorale_eval)
            pc_str = f'{n_pc_err:>6}' if n_pc_err == 0 else f'{n_pc_err:>5}!'
            print(f'  {version:<10} {mean_sc:>6.1f} {max_sc:>6.0f} {max_ch:>6} {p80:>4} {p90:>4} {spread:>8.1f} {combined:>10.1f} {pc_str}')
            if n_pc_err > 0:
                for chord_idx, voice_idx, exp_pc, act_pc in pc_details[:10]:
                    print(f'      chord {chord_idx}, voice {voice_idx}: expected PC {exp_pc}, got PC {act_pc}')
                if n_pc_err > 10:
                    print(f'      ... and {n_pc_err - 10} more')

            if args.print_individual_chords or args.ratios:
                print(f'\nversion: {version}, tolerance={tolerance_local}, limit_max={limit_max_local}, '
                      f'Average score: {mean_sc:.1f}, max score: {max_sc:.0f} max chord: {max_ch}')
                print_chords_analysis(
                    version=version,
                    cent_4n=cent_4n,
                    chorale=chorale,
                    keys=keys,
                    tonal_diamond=tonal_diamond_local,
                    tolerance=tolerance_local,
                    include_set=set(include_idx.tolist()) if (include_list or include_slice) else None,
                    print_individual_chords=args.print_individual_chords,
                    ratios=args.ratios,
                )

        if selected_sources:
            print('\nSelected source file(s):')
            for version, input_file, n_matches in selected_sources:
                flag = ' (from multiple matches)' if n_matches > 1 else ''
                print(f'  {version:<10} {input_file}{flag}')

    print()


if __name__ == '__main__':
    main()
