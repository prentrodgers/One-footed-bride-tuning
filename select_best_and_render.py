#!/usr/bin/env python3
"""
select_best_and_render.py

Scan all tuned-array directories under --numpy_dir_root, compute per-chorale
combined metric (mean_score + spread_weight * weighted_spread), print a ranked
table, and optionally render the winning directory per chorale with WreckingCrew.py.

Usage:
    python select_best_and_render.py \
        --numpy_dir_root Archive/straw-man \
        --chorale_list bwv253 bwv254 \
        --suffix=-trans-sa-opt.npy \
        --spread_weight 0.5 \
        --tolerance 1 \
        --limit_max 23

    # To also render winners:
    python select_best_and_render.py ... --render
"""

import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
from collections import Counter, defaultdict

import numpy as np

base_dir = os.path.dirname(os.path.abspath(__file__))
if base_dir not in sys.path:
    sys.path.insert(0, base_dir)

import adaptive_tuning_util as atu


def parse_dir_params(dirname):
    """Parse t{t}_r{r}_s{s}_md{md}_sn{sn}[_lm{lm}] directory name into a dict.
    Returns None if the name does not match."""
    m = re.match(r't(\d+)_r([\d.]+)_s([\d.]+)_md(\d+)_sn(\d+)(?:_lm(\d+))?',
                 os.path.basename(dirname))
    if not m:
        return None
    return {
        'tolerance': int(m.group(1)),
        'ratio_factor': float(m.group(2)),
        'stability_factor': float(m.group(3)),
        'max_delta': int(m.group(4)),
        'snap_tolerance': int(m.group(5)),
        'limit_max': int(m.group(6)) if m.group(6) else 23,
    }


def compute_spread_score(cent_value_chorale_4n, chorale):
    """Frequency-weighted average pitch-class cent spread (lower is better).

    Parameters
    ----------
    cent_value_chorale_4n : np.ndarray, shape (4, N)
    chorale              : np.ndarray, shape (4, N)  original MIDI notes
    """
    pitch_class_counts = Counter((chorale % 12).flatten().tolist())
    total_count = sum(pitch_class_counts.values())
    pc_cents = defaultdict(list)
    for chord_cents in cent_value_chorale_4n.T:      # iterate over N chords
        pcs = atu.pitch_class_from_cents(chord_cents)
        for pc, cv in zip(pcs, chord_cents):
            pc_cents[int(pc)].append(float(cv))
    weighted_spread = 0.0
    for pc, count in pitch_class_counts.items():
        cvs = pc_cents.get(pc, [])
        if len(cvs) < 2:
            continue
        weighted_spread += atu.circular_span(cvs)[0] * (count / total_count)
    return weighted_spread


def score_array(cent_4n, tonal_diamond, tolerance):
    """Return (mean_score, max_score, max_chord_idx) for a (4, N) array."""
    chord_scorer = atu.ChordScorer(tonal_diamond)
    scores = np.array([
        chord_scorer.score_chord(cent_4n[:, i], tolerance=tolerance)
        for i in range(cent_4n.shape[1])
    ])
    return float(np.mean(scores)), float(np.max(scores)), int(np.argmax(scores))


def main():
    parser = argparse.ArgumentParser(
        description='Rank tuned-array directories by combined score+spread and optionally render winners')
    parser.add_argument('--numpy_dir_root', type=str, default='Archive/straw-man',
                        help='Root directory containing tuned-array subdirectories')
    parser.add_argument('--chorale_list', type=str, nargs='+', default=['bwv253'],
                        help='Chorale names to evaluate')
    parser.add_argument('--suffix', type=str, default='-trans-sa-opt.npy',
                        help='File suffix to evaluate (default: -trans-sa-opt.npy)')
    parser.add_argument('--spread_weight', type=float, default=0.5,
                        help='Weight of spread in combined metric: mean_score + spread_weight * spread (default: 0.5)')
    parser.add_argument('--tolerance', type=int, default=1,
                        help='Cent tolerance for ChordScorer (default: 1)')
    parser.add_argument('--limit_max', type=int, default=23,
                        help='Tonal diamond limit_max (default: 23)')
    parser.add_argument('--render', action='store_true',
                        help='Run WreckingCrew.py for the best directory per chorale')
    parser.add_argument('--album', type=int, default=4,
                        help='WreckingCrew album number (default: 4)')
    parser.add_argument('--max_cents_slide', type=int, default=50,
                        help='WreckingCrew max_cents_slide (default: 50)')
    parser.add_argument('--bass_sustain', type=int, default=15,
                        help='Bass sustain duration passed to WreckingCrew.py (default: 15)')
    parser.add_argument('--spread_render', type=int, default=7,
                        help='WreckingCrew spread argument (default: 7)')
    parser.add_argument('--copy_mp3_to', type=str, default=None,
                        help='Copy winning MP3s to this directory (e.g. ~/Dropbox/Uploads)')
    parser.add_argument('--uploads_dir', type=str, default='Uploads',
                        help='Directory to search for MP3s (default: Uploads)')
    parser.add_argument('--copy_npy_to', type=str, default=None,
                        help='Copy winning .npy files for each chorale to this directory')
    parser.add_argument('--short_repeats', action='store_true',
                        help='Pass --short_repeats to WreckingCrew.py')
    parser.add_argument('--trim', action='store_true',
                        help='Delete all non-winning directories from numpy_dir_root after scoring')
    args = parser.parse_args()

    root = (args.numpy_dir_root if os.path.isabs(args.numpy_dir_root)
            else os.path.join(base_dir, args.numpy_dir_root))

    # Find all matching subdirectories, sorted by name
    dirs = []
    for name in sorted(os.listdir(root)):
        full = os.path.join(root, name)
        if os.path.isdir(full) and parse_dir_params(name) is not None:
            dirs.append(full)

    if not dirs:
        print(f'No matching directories found under {root}')
        return

    # Tonal diamonds are built per-directory (limit_max varies); cache by value.
    tonal_diamond_cache = {}

    winners = []  # (version, best_dir, best_params) for rendering

    for version in args.chorale_list:
        print(f'\n{"=" * 78}')
        print(f'Chorale: {version}  (suffix: {args.suffix}, spread_weight: {args.spread_weight})')
        print(f'{"=" * 78}')
        print(f'  {"Directory":<42} {"lm":>4} {"Mean":>6} {"Max":>6} {"MaxCh":>6} {"Spread":>8} {"Combined":>10}')
        print(f'  {"-" * 42} {"--":>4} {"-----":>6} {"-----":>6} {"-----":>6} {"-------":>8} {"---------":>10}')

        results = []
        for d in dirs:
            params = parse_dir_params(d)
            input_file = os.path.join(d, f'{version}{args.suffix}')
            if not os.path.exists(input_file):
                continue
            try:
                cent_4n = np.load(input_file, allow_pickle=True)  # shape (4, N)
                _, _, chorale, _, _, _ = atu.load_chorale_in_cents(
                    version, d, twelve_tet=True, save_top_notes=False)
            except Exception as e:
                print(f'  {os.path.basename(d)}: could not load — {e}')
                continue

            lm = params['limit_max']
            if lm not in tonal_diamond_cache:
                tonal_diamond_cache[lm] = atu.build_tonal_diamond(lm)
            mean_sc, max_sc, max_ch = score_array(cent_4n, tonal_diamond_cache[lm], args.tolerance)
            spread = compute_spread_score(cent_4n, chorale)
            combined = mean_sc + args.spread_weight * spread
            results.append((combined, mean_sc, max_sc, max_ch, spread, d, params))

        if not results:
            print(f'  No results found for {version}')
            continue

        results.sort(key=lambda x: x[0])
        for i, (combined, mean_sc, max_sc, max_ch, spread, d, params) in enumerate(results):
            marker = ' <-- BEST' if i == 0 else ''
            lm = params['limit_max']
            print(f'  {os.path.basename(d):<42} {lm:>4} {mean_sc:>6.1f} {max_sc:>6.0f} {max_ch:>6} {spread:>8.1f} {combined:>10.1f}{marker}')

        best = results[0]
        best_combined, best_mean, best_max, best_maxch, best_spread, best_dir, best_params = best
        print(f'\n  Winner: {os.path.basename(best_dir)}')
        print(f'    mean={best_mean:.1f}, max={best_max:.0f} at chord {best_maxch}, '
              f'spread={best_spread:.1f}, combined={best_combined:.1f}')
        winners.append((version, best_dir, best_params))

    print(f'\n{"=" * 78}')

    if args.trim and winners:
        winning_dirs = {best_dir for _, best_dir, _ in winners}
        # Map each winning dir to the chorales it won
        dir_winners = defaultdict(set)
        for version, best_dir, _ in winners:
            dir_winners[best_dir].add(version)

        # Delete non-winning directories entirely
        to_delete = [d for d in dirs if d not in winning_dirs]
        if to_delete:
            print(f'\nDeleting {len(to_delete)} non-winning directories ...')
            for d in to_delete:
                shutil.rmtree(d)
                print(f'  deleted {os.path.basename(d)}')

        # Within winning directories, keep only the suffix file for winning chorales
        all_chorales = set(args.chorale_list)
        print(f'\nPruning files within winning directories ...')
        for d in sorted(winning_dirs):
            losers = all_chorales - dir_winners[d]
            removed = []
            # Delete all files for losing chorales
            for version in losers:
                for f in glob.glob(os.path.join(d, f'{version}*')):
                    os.remove(f)
                    removed.append(os.path.basename(f))
            # For winning chorales, keep only the suffix file
            for version in dir_winners[d]:
                for f in glob.glob(os.path.join(d, f'{version}*')):
                    if not f.endswith(args.suffix):
                        os.remove(f)
                        removed.append(os.path.basename(f))
            kept = sorted(dir_winners[d])
            print(f'  {os.path.basename(d)}: kept {kept}, removed {len(removed)} file(s)')

        print(f'\nDone. {len(winning_dirs)} director{"y" if len(winning_dirs) == 1 else "ies"} remaining.')

    if args.render:
        print('\nRendering winners with WreckingCrew.py...\n')
        for version, best_dir, params in winners:
            print(f'  {version}  →  {os.path.basename(best_dir)}')
            cmd = [
                sys.executable, os.path.join(base_dir, 'WreckingCrew.py'),
                '--chorale_name', version,
                f'--cent_file_partial={args.suffix}',
                '--no_show_volumes',
                '--album', str(args.album),
                '--tolerance', str(params['tolerance']),
                '--ratio_factor', str(params['ratio_factor']),
                '--stability_factor', str(params['stability_factor']),
                '--max_delta', str(params['max_delta']),
                '--limit_max', str(params['limit_max']),
                '--numpy_dir', best_dir,
                '--spread', str(args.spread_render),
                '--max_cents_slide', str(args.max_cents_slide),
                '--bass_sustain', str(args.bass_sustain),
            ]
            if args.short_repeats:
                cmd.append('--short_repeats')
            subprocess.run(cmd, check=True)
        print('\nDone rendering.')
    else:
        print('\nRun with --render to produce audio for the winners.')

    if args.copy_mp3_to:
        uploads = (args.uploads_dir if os.path.isabs(args.uploads_dir)
                   else os.path.join(base_dir, args.uploads_dir))
        dest = os.path.expanduser(args.copy_mp3_to)
        os.makedirs(dest, exist_ok=True)
        print(f'\nCopying winning MP3s to {dest} ...\n')
        for version, best_dir, params in winners:
            tol = params['tolerance']
            lm  = params['limit_max']
            rf  = params['ratio_factor']
            sf  = params['stability_factor']
            md  = params['max_delta']
            bwv_num = version[-2:]   # '53' for bwv253, '60' for bwv260
            # Match any mod_letter and any spread/duration/tempo suffix
            pattern = os.path.join(
                uploads,
                f'ball9-t{bwv_num}?_lm{lm}_r{rf:.2f}_sf{sf:.2f}_md{md:02d}_sp??_t{tol}_*.mp3'
            )
            matches = glob.glob(pattern)
            if not matches:
                print(f'  {version}: no MP3 found matching {os.path.basename(pattern)}')
            else:
                for src in matches:
                    shutil.copy2(src, dest)
                    print(f'  {version}  →  {os.path.basename(src)}')
        print('\nDone copying.')

    if args.copy_npy_to:
        dest = os.path.expanduser(args.copy_npy_to)
        os.makedirs(dest, exist_ok=True)
        print(f'\nCopying winning .npy files to {dest} ...\n')
        for version, best_dir, params in winners:
            src = os.path.join(best_dir, f'{version}{args.suffix}')
            if not os.path.exists(src):
                print(f'  {version}: not found — {src}')
            else:
                shutil.copy2(src, dest)
                print(f'  {version}  →  {os.path.basename(src)}  (from {os.path.basename(best_dir)})')
        print('\nDone copying.')


if __name__ == '__main__':
    main()
