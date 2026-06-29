#!/usr/bin/env python3
"""
select_best_and_render.py

Scan all tuned-array directories under --numpy_dir_root, compute per-chorale
combined metric, print a ranked table, and optionally render the winning
directory per chorale with WreckingCrew.py.

Ranking metric
--------------
The primary concern is whether WreckingCrew.py can generate a glissando for
each adjacent-chord pitch-class transition.  build_glides_array() only creates
a slide when the cent gap is in the range (1, max_cents_slide).  Gaps above
max_cents_slide produce no slide — just an abrupt, audibly sour jump.

  combined = penalty_weight * hard_jump_count
           + penalty_weight * 0.1 * mean_hard_jump_cents
           + score_weight   * mean_chord_score

  hard_jump_count  — number of adjacent PC transitions whose gap exceeds
                     max_cents_slide (these will NOT be smoothed by a glissando)
  mean_hard_jump   — average gap size of those hard jumps (secondary penalty)
  mean_chord_score — vertical chord quality (tiebreaker)

A result with zero hard jumps and a slightly worse chord score always beats
one with even one hard jump.

Usage:
    python select_best_and_render.py \
        --numpy_dir_root Archive/straw-man \
        --chorale_list bwv253 bwv254 \
        --suffix=-trans-sa-opt.npy \
        --max_cents_slide 33 \
        --penalty_weight 10.0 \
        --score_weight 1.0

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
import time
from collections import Counter, defaultdict

import numpy as np

base_dir = os.path.dirname(os.path.abspath(__file__))
if base_dir not in sys.path:
    sys.path.insert(0, base_dir)

import adaptive_tuning_util as atu


def parse_dir_params(dirname):
    """Parse a tuning directory name into a params dict.

    Supports two naming conventions:
      Old: t{t}_r{r}_s{s}_md{md}_sn{sn}[_lm{lm}]
      New: t{t}_r{r}_lm{lm}_tmp{temp}   (stability=0, max_delta=33, snap=0 implied)

    Returns None if the name matches neither pattern.
    """
    name = os.path.basename(dirname)
    # New convention: t1_r1.375_lm17_tmp3.0
    m = re.match(r't(\d+)_r([\d.]+)_lm(\d+)_tmp([\d.]+)$', name)
    if m:
        return {
            'tolerance': int(m.group(1)),
            'ratio_factor': float(m.group(2)),
            'limit_max': int(m.group(3)),
            'stability_factor': 0.0,
            'max_delta': 33,
            'snap_tolerance': 0,
        }
    # Old convention: t1_r1.125_s0_md33_sn0_lm17
    m = re.match(r't(\d+)_r([\d.]+)_s([\d.]+)_md(\d+)_sn(\d+)(?:_lm(\d+))?', name)
    if m:
        return {
            'tolerance': int(m.group(1)),
            'ratio_factor': float(m.group(2)),
            'stability_factor': float(m.group(3)),
            'max_delta': int(m.group(4)),
            'snap_tolerance': int(m.group(5)),
            'limit_max': int(m.group(6)) if m.group(6) else 23,
        }
    return None


def compute_adjacency_metric(cent_4n, max_cents_slide):
    """Count adjacent-chord PC transitions that exceed max_cents_slide (lower is better).

    WreckingCrew's build_glides_array() only generates a glissando when the cent
    gap between the same pitch class in consecutive chords is in the range
    (1, max_cents_slide).  Gaps above that threshold produce no slide — just an
    abrupt audible jump.  This function returns:

        (hard_jump_count, mean_hard_jump_cents, max_gap_cents, total_transitions)

    hard_jump_count      — transitions above max_cents_slide (primary penalty)
    mean_hard_jump_cents — mean gap of those hard jumps (secondary penalty)
    max_gap_cents        — worst single gap anywhere in the piece
    total_transitions    — total shared-PC adjacent transitions found
    """
    n_chords = cent_4n.shape[1]
    hard_jumps = []
    all_gaps = []

    for i in range(1, n_chords):
        prev_col = cent_4n[:, i - 1]
        curr_col = cent_4n[:, i]
        if np.array_equal(prev_col, curr_col):
            continue
        prev_pcs = atu.pitch_class_from_cents(prev_col)
        curr_pcs = atu.pitch_class_from_cents(curr_col)
        prev_map = defaultdict(list)
        for pc, cv in zip(prev_pcs, prev_col):
            prev_map[int(pc)].append(float(cv))
        for pc, cv in zip(curr_pcs, curr_col):
            pc = int(pc)
            if pc not in prev_map:
                continue
            gap = min(atu.cent_distance_mod_1200(cv, p) for p in prev_map[pc])
            if gap > 1.0:
                all_gaps.append(gap)
                if gap >= max_cents_slide:
                    hard_jumps.append(gap)

    hard_jump_count = len(hard_jumps)
    mean_hard_jump = float(np.mean(hard_jumps)) if hard_jumps else 0.0
    max_gap = float(np.max(all_gaps)) if all_gaps else 0.0
    return hard_jump_count, mean_hard_jump, max_gap, len(all_gaps)


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
        description='Rank tuned-array directories by glissando-aware adjacency metric and optionally render winners')
    parser.add_argument('--numpy_dir_root', type=str, default='Archive/straw-man',
                        help='Root directory containing tuned-array subdirectories')
    parser.add_argument('--chorale_list', type=str, nargs='+', default=['bwv253'],
                        help='Chorale names to evaluate')
    parser.add_argument('--suffix', type=str, default='-trans-sa-opt.npy',
                        help='File suffix to evaluate (default: -trans-sa-opt.npy)')
    parser.add_argument('--max_cents_slide', type=float, default=33.0,
                        help='Glissando threshold: gaps above this value (cents) produce no slide in '
                             'WreckingCrew and count as hard jumps in the ranking metric. '
                             'Must match --max_cents_slide passed to WreckingCrew.py (default: 33)')
    parser.add_argument('--penalty_weight', type=float, default=10.0,
                        help='Weight applied to each hard jump (gap >= max_cents_slide) in the combined '
                             'metric; set high so even one hard jump outweighs chord-quality differences '
                             '(default: 10.0)')
    parser.add_argument('--score_weight', type=float, default=1.0,
                        help='Weight of mean chord quality score in combined metric; acts as tiebreaker '
                             'when hard_jump_count is equal (default: 1.0)')
    # kept for backward compatibility but no longer drives ranking
    parser.add_argument('--spread_weight', type=float, default=0.0,
                        help='(Legacy, ignored in ranking) Whole-chorale MAD spread weight (default: 0.0)')
    parser.add_argument('--tolerance', type=int, default=None,
                        help='Ignored — tolerance is read per-directory from the directory name.')
    parser.add_argument('--limit_max', type=int, default=23,
                        help='Tonal diamond limit_max (default: 23)')
    parser.add_argument('--render', action='store_true',
                        help='Run WreckingCrew.py for the best directory per chorale')
    parser.add_argument('--album', type=int, default=4,
                        help='WreckingCrew album number (default: 4)')
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
        print(f'Chorale: {version}  (suffix: {args.suffix})')
        print(f'  max_cents_slide={args.max_cents_slide}  penalty_weight={args.penalty_weight}  '
              f'score_weight={args.score_weight}')
        print(f'{"=" * 78}')
        print(f'  {"Directory":<42} {"lm":>4} {"Mean":>6} {"MaxGap":>7} {"HardJmp":>8} {"Combined":>10}')
        print(f'  {"-" * 42} {"--":>4} {"-----":>6} {"------":>7} {"-------":>8} {"---------":>10}')

        results = []
        for d in dirs:
            params = parse_dir_params(d)
            input_file = os.path.join(d, f'{version}{args.suffix}')
            if not os.path.exists(input_file):
                continue
            try:
                cent_4n = np.load(input_file, allow_pickle=True)  # shape (4, N)
            except Exception as e:
                print(f'  {os.path.basename(d)}: could not load — {e}')
                continue

            lm = params['limit_max']
            if lm not in tonal_diamond_cache:
                tonal_diamond_cache[lm] = atu.build_tonal_diamond(lm)
            tol = params['tolerance']
            mean_sc, max_sc, max_ch = score_array(cent_4n, tonal_diamond_cache[lm], tol)

            hard_count, mean_hard, max_gap, total_trans = compute_adjacency_metric(
                cent_4n, args.max_cents_slide)

            combined = (args.penalty_weight * hard_count
                        + args.penalty_weight * 0.1 * mean_hard
                        + args.score_weight * mean_sc)

            results.append((combined, mean_sc, max_sc, max_ch,
                             hard_count, mean_hard, max_gap, total_trans, d, params))

        if not results:
            print(f'  No results found for {version}')
            continue

        results.sort(key=lambda x: x[0])
        for i, (combined, mean_sc, max_sc, max_ch,
                hard_count, mean_hard, max_gap, total_trans, d, params) in enumerate(results):
            marker = ' <-- BEST' if i == 0 else ''
            lm = params['limit_max']
            hard_flag = f' ({hard_count} jumps)' if hard_count > 0 else ' (clean)'
            print(f'  {os.path.basename(d):<42} {lm:>4} {mean_sc:>6.1f} {max_gap:>7.1f} '
                  f'{hard_count:>8}{hard_flag:<12} {combined:>10.1f}{marker}')

        best = results[0]
        (best_combined, best_mean, best_max, best_maxch,
         best_hard_count, best_mean_hard, best_max_gap,
         best_total_trans, best_dir, best_params) = best
        print(f'\n  Winner: {os.path.basename(best_dir)}')
        print(f'    mean_score={best_mean:.1f}, max_gap={best_max_gap:.1f}¢, '
              f'hard_jumps={best_hard_count} (>{args.max_cents_slide:.0f}¢), '
              f'total_transitions={best_total_trans}, combined={best_combined:.1f}')
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

    render_start_time = None
    if args.render:
        render_start_time = time.time()
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
            if render_start_time is not None:
                matches = [m for m in matches if os.path.getmtime(m) >= render_start_time]
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
                # Encode parameters in the destination filename
                t = params['tolerance']
                r = params['ratio_factor']
                lm = params['limit_max']
                # Extract the suffix part (e.g., '-trans-sa-opt.npy')
                dest_filename = f'{version}_t{t}_r{r:.3f}_lm{lm}{args.suffix}'
                dest_path = os.path.join(dest, dest_filename)
                shutil.copy2(src, dest_path)
                print(f'  {version}  →  {dest_filename}  (from {os.path.basename(best_dir)})')
        print('\nDone copying.')


if __name__ == '__main__':
    main()
