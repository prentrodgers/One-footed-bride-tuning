#!/usr/bin/env python3
"""
select_best_and_render.py

Report on every tuned-array directory under --numpy_dir_root: chord quality and
a detailed picture of the adjacent-chord pitch-class gaps, so the trade-off
between the two is visible rather than collapsed into a single number.

This used to pick a winner with a hinge metric:

    combined = 10 * (gaps >= max_cents_slide) + 0.1 * mean_hard_gap + mean_score

That hinge is gone.  It had two problems.  First, it was blind below the
threshold: a tuning whose worst gap was 15¢ and one whose worst was 31¢ scored
identically, so the ranking always came down to a few tenths of chord score.
Second, `enforce_continuity` repairs a gap by shifting it to land on *exactly*
max_gap, and the hinge counted `gap >= max_cents_slide` — so a repaired 33¢ gap
was scored as a hard failure and buried, while an untouched 32¢ gap passed as
clean.  The threshold was measuring the repair step, not the music.

So this now reports instead of deciding.  For each directory it shows the gap
count, sum, mean, median, p90 and max, plus how many gaps exceed 10/20/30¢, and
then lists the largest individual gaps with their chord index, voice and note
name so they can be found by ear in the rendered audio.

--sort_by only orders the rows; it does not declare anything best.

Usage:
    python select_best_and_render.py \
        --numpy_dir_root Archive/straw-man \
        --chorale_list bwv256 \
        --suffix=-opt.npy \
        --sort_by gapsum --top_gaps 10
"""

import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
import time

import numpy as np

base_dir = os.path.dirname(os.path.abspath(__file__))
if base_dir not in sys.path:
    sys.path.insert(0, base_dir)

import adaptive_tuning_util as atu

NOTE_NAMES = atu.set_accidentals(False)   # sharps: C♮ C♯ D♮ ...


def parse_dir_params(dirname):
    """Pull tuning parameters out of a directory name.

    Each field is read independently rather than by matching a fixed layout, so
    every naming convention this project has used still parses:
      t1_r1.25_lm17               current: tolerance, ratio and limit only
      t1_r1.25_s0_md33_sn0_lm17   stability / max_delta / snap encoded
      t2_r1.125_lm17_tmp3.0       temperature encoded
    Absent fields fall back to the values those runs used.  Returns None when the
    name carries no tolerance/ratio pair at all, so unrelated directories are
    left to the caller's defaults.
    """
    name = os.path.basename(dirname)
    tolerance = re.search(r'(?:^|_)t(\d+)(?:_|$)', name)
    ratio = re.search(r'_r([\d.]+?)(?:_|$)', name)
    if not tolerance or not ratio:
        return None

    limit_max = re.search(r'_lm(\d+)(?:_|$)', name)
    stability = re.search(r'_s([\d.]+)(?:_|$)', name)
    max_delta = re.search(r'_md(\d+)(?:_|$)', name)
    snap = re.search(r'_sn(\d+)(?:_|$)', name)
    return {
        'tolerance': int(tolerance.group(1)),
        'ratio_factor': float(ratio.group(1)),
        'limit_max': int(limit_max.group(1)) if limit_max else 23,
        'stability_factor': float(stability.group(1)) if stability else 0.0,
        'max_delta': int(max_delta.group(1)) if max_delta else 33,
        'snap_tolerance': int(snap.group(1)) if snap else 0,
    }


def find_tuning_files(d, version, suffix, fallback):
    """Every tuned array for `version` in directory `d`, with its parameters.

    Two layouts are in use: grid-search directories hold `{version}{suffix}` and
    encode the parameters in the directory name, while the archived collections
    hold `{version}_t{t}_r{r}_lm{lm}{suffix}` and encode them in the filename.
    Returns a list of (path, params); filename parameters win when present.
    """
    # Anchored so that '-opt.npy' does not also swallow '-trans-sa-opt.npy',
    # which a plain '*-opt.npy' glob would.
    pattern = re.compile(
        rf'^{re.escape(version)}(?:_t(\d+)_r([\d.]+)_lm(\d+))?{re.escape(suffix)}$')
    found = []
    for name in sorted(os.listdir(d)):
        m = pattern.match(name)
        if not m:
            continue
        params = dict(fallback)
        if m.group(1):
            params.update(tolerance=int(m.group(1)), ratio_factor=float(m.group(2)),
                          limit_max=int(m.group(3)))
        found.append((os.path.join(d, name), params))
    return found


def collect_gaps(cent_4n):
    """Every shared-pitch-class cent gap between adjacent chords.

    For each voice of each chord whose pitch class also appears in the previous
    chord, record the distance to the nearest occurrence of that pitch class.
    Returns a list of (gap, chord_idx, voice_idx, pitch_class, prev_cent, curr_cent).
    Gaps of 1¢ or less are dropped as rounding noise, matching what
    WreckingCrew's build_glides_array() treats as no movement.
    """
    out = []
    for i in range(1, cent_4n.shape[1]):
        prev_col, curr_col = cent_4n[:, i - 1], cent_4n[:, i]
        if np.array_equal(prev_col, curr_col):
            continue                      # held chord: same cents, no transition
        prev_pcs = atu.pitch_class_from_cents(prev_col)
        curr_pcs = atu.pitch_class_from_cents(curr_col)
        for v, (pc, cv) in enumerate(zip(curr_pcs, curr_col)):
            same_pc = [float(p) for p, ppc in zip(prev_col, prev_pcs) if ppc == pc]
            if not same_pc:
                continue
            prev_cent = min(same_pc, key=lambda p: atu.cent_distance_mod_1200(float(cv), p))
            gap = atu.cent_distance_mod_1200(float(cv), prev_cent)
            if gap > 1.0:
                out.append((gap, i, v, int(pc), prev_cent, float(cv)))
    return out


def summarize_gaps(gaps, max_cents_slide):
    """Reduce a gap list to the summary columns shown in the table."""
    if not gaps:
        return dict(n=0, total=0.0, mean=0.0, median=0.0, p90=0.0, mx=0.0,
                    over10=0, over20=0, over30=0, at_slide=0)
    g = np.array([x[0] for x in gaps])
    return dict(
        n=len(g), total=float(g.sum()), mean=float(g.mean()),
        median=float(np.median(g)), p90=float(np.percentile(g, 90)), mx=float(g.max()),
        over10=int((g > 10).sum()), over20=int((g > 20).sum()),
        over30=int((g > 30).sum()), at_slide=int((g >= max_cents_slide).sum()))


def score_array(cent_4n, tonal_diamond, tolerance):
    """Return (mean_score, max_score, max_chord_idx) for a (4, N) array."""
    chord_scorer = atu.ChordScorer(tonal_diamond)
    scores = np.array([
        chord_scorer.score_chord(cent_4n[:, i], tolerance=tolerance)
        for i in range(cent_4n.shape[1])
    ])
    return float(np.mean(scores)), float(np.max(scores)), int(np.argmax(scores))


SORT_KEYS = {
    'score':  lambda r: r['mean_score'],
    'gapsum': lambda r: r['g']['total'],
    # Worst single jump first, total gap as the tie-break.  The worst jump is what
    # gets heard: on bwv261 this ordering put t3_r1.625_lm19 (max 11¢, sum 44) above
    # t3_r1.375_lm19 (max 14¢, sum 32), and the 11¢ tuning was the one that sounded
    # right — so a lower total does not make up for a bigger lurch.
    'maxgap': lambda r: (r['g']['mx'], r['g']['total']),
    'p90':    lambda r: r['g']['p90'],
    'over20': lambda r: (r['g']['over20'], r['g']['total']),
    'name':   lambda r: r['dir'],
}


def main():
    parser = argparse.ArgumentParser(
        description='Report chord quality and adjacent pitch-class gap detail for tuned-array directories')
    parser.add_argument('--numpy_dir_root', type=str, default='Archive/straw-man',
                        help='Root directory containing tuned-array subdirectories')
    parser.add_argument('--chorale_list', type=str, nargs='+', default=['bwv253'],
                        help='Chorale names to evaluate')
    parser.add_argument('--suffix', type=str, default='-opt.npy',
                        help='File suffix to report on (default: -opt.npy)')
    parser.add_argument('--alt_suffix', type=str, default='',
                        help='Second suffix to report as its own row when present, e.g. '
                             '-trans-sa-opt.npy. Both are reported side by side rather than '
                             'one being silently chosen (default: none)')
    parser.add_argument('--max_cents_slide', type=float, default=33.0,
                        help='Glissando reference: WreckingCrew slides a gap only below this '
                             'value. Shown as the final bucket column; it no longer discards '
                             'anything (default: 33)')
    parser.add_argument('--sort_by', type=str, default='score', choices=sorted(SORT_KEYS),
                        help='Row ordering only — implies no judgement of quality. '
                             'score=mean chord score, gapsum=total gap cents, maxgap, p90, '
                             'over20=count of gaps above 20¢, name (default: score)')
    parser.add_argument('--top_gaps', type=int, default=10,
                        help='List this many largest individual gaps per detailed directory; '
                             '0 disables the detail section (default: 10)')
    parser.add_argument('--detail_dirs', type=int, default=3,
                        help='Show the largest-gap detail for this many leading rows (default: 3)')
    parser.add_argument('--tolerance', type=int, default=1,
                        help='Chord-scoring tolerance for directories whose name does not encode '
                             'it (default: 1)')
    parser.add_argument('--limit_max', type=int, default=17,
                        help='Tonal diamond limit_max for directories whose name does not encode '
                             'it (default: 17)')
    parser.add_argument('--copy_npy_to', type=str, default=None,
                        help='Copy the leading row per chorale (under --sort_by) to this '
                             'directory. Ordering is not a quality verdict — check the report first.')
    # Kept for when selection is trustworthy again; unused for now.
    parser.add_argument('--render', action='store_true',
                        help='Run WreckingCrew.py for the leading row per chorale')
    parser.add_argument('--album', type=int, default=4,
                        help='WreckingCrew album number (default: 4)')
    parser.add_argument('--bass_sustain', type=int, default=15,
                        help='Bass sustain duration passed to WreckingCrew.py (default: 15)')
    parser.add_argument('--spread_render', type=int, default=7,
                        help='WreckingCrew spread argument (default: 7)')
    parser.add_argument('--copy_mp3_to', type=str, default=None,
                        help='Copy rendered MP3s to this directory (e.g. ~/Dropbox/Uploads)')
    parser.add_argument('--uploads_dir', type=str, default='Uploads',
                        help='Directory to search for MP3s (default: Uploads)')
    parser.add_argument('--short_repeats', action='store_true',
                        help='Pass --short_repeats to WreckingCrew.py')
    args = parser.parse_args()

    root = (args.numpy_dir_root if os.path.isabs(args.numpy_dir_root)
            else os.path.join(base_dir, args.numpy_dir_root))

    suffixes = [args.suffix] + ([args.alt_suffix] if args.alt_suffix else [])

    # Any subdirectory holding a matching file is reportable.  Directories whose
    # name does not encode tolerance/limit_max fall back to the CLI defaults so
    # ad-hoc result directories can be inspected too.
    dirs = []
    for name in sorted(os.listdir(root)):
        full = os.path.join(root, name)
        if not os.path.isdir(full):
            continue
        if any(find_tuning_files(full, v, s, {})
               for v in args.chorale_list for s in suffixes):
            dirs.append(full)

    if not dirs:
        print(f'No directories under {root} contain {args.chorale_list} files '
              f'with suffix {suffixes}')
        return

    tonal_diamond_cache = {}
    leaders = []   # (version, dir, params, suffix) — leading row per chorale

    for version in args.chorale_list:
        print(f'\n{"=" * 108}')
        print(f'Chorale: {version}   sorted by {args.sort_by} (ordering only, not a ranking)')
        print(f'{"=" * 108}')

        rows = []
        for d in dirs:
            params = parse_dir_params(d) or {
                'tolerance': args.tolerance, 'limit_max': args.limit_max,
                'ratio_factor': 0.0, 'stability_factor': 0.0,
                'max_delta': 33, 'snap_tolerance': 0,
            }
            for sfx in suffixes:
                for path, fparams in find_tuning_files(d, version, sfx, params):
                    lm, tol = fparams['limit_max'], fparams['tolerance']
                    if lm not in tonal_diamond_cache:
                        # [:-1] drops the 2/1 octave row, matching Straw_man_tuning_v2.
                        tonal_diamond_cache[lm] = atu.build_tonal_diamond(lm)[:-1]
                    try:
                        arr = np.load(path, allow_pickle=True)
                    except Exception as e:
                        print(f'  {os.path.basename(d)}: could not load '
                              f'{os.path.basename(path)} — {e}')
                        continue
                    mean_sc, max_sc, max_ch = score_array(arr, tonal_diamond_cache[lm], tol)
                    gaps = collect_gaps(arr)
                    rows.append({
                        'dir': d, 'suffix': sfx, 'path': path, 'params': fparams,
                        'mean_score': mean_sc, 'max_score': max_sc, 'max_chord': max_ch,
                        'gaps': gaps, 'g': summarize_gaps(gaps, args.max_cents_slide),
                    })

        if not rows:
            print(f'  No results found for {version}')
            continue

        rows.sort(key=SORT_KEYS[args.sort_by])

        ms = int(args.max_cents_slide)
        print(f'  {"Directory":<30} {"sfx":<6} {"t":>2} {"ratio":>6} {"lm":>3} '
              f'{"ChordAvg":>8} {"ChordMax":>8} |'
              f' {"N":>4} {"GapSum":>7} {"Avg":>6} {"Med":>6} {"p90":>6} {"Max":>6} |'
              f' {">10":>4} {">20":>4} {">30":>4} {">=" + str(ms):>5}')
        print(f'  {"-" * 30} {"-" * 6} {"-" * 2} {"-" * 6} {"-" * 3} {"-" * 8} {"-" * 8} |'
              f' {"-" * 4} {"-" * 7} {"-" * 6} {"-" * 6} {"-" * 6} {"-" * 6} |'
              f' {"-" * 4} {"-" * 4} {"-" * 4} {"-" * 5}')
        for r in rows:
            g, p = r['g'], r['params']
            sfx_label = 'trans' if 'trans' in r['suffix'] else 'opt'
            print(f'  {os.path.basename(r["dir"])[:30]:<30} {sfx_label:<6} '
                  f'{p["tolerance"]:>2} {p["ratio_factor"]:>6.3f} {p["limit_max"]:>3} '
                  f'{r["mean_score"]:>8.1f} {r["max_score"]:>8.0f} |'
                  f' {g["n"]:>4} {g["total"]:>7.0f} {g["mean"]:>6.1f} {g["median"]:>6.1f} '
                  f'{g["p90"]:>6.1f} {g["mx"]:>6.1f} |'
                  f' {g["over10"]:>4} {g["over20"]:>4} {g["over30"]:>4} {g["at_slide"]:>5}')

        if args.top_gaps > 0:
            for r in rows[:max(0, args.detail_dirs)]:
                worst = sorted(r['gaps'], reverse=True)[:args.top_gaps]
                if not worst:
                    continue
                print(f'\n  Largest gaps — {os.path.basename(r["dir"])} '
                      f'[{"trans" if "trans" in r["suffix"] else "opt"}]')
                print(f'    {"chord":>6} {"voice":>6} {"note":<5} {"prev":>8} {"curr":>8} {"gap":>7}')
                for gap, chord_idx, voice, pc, prev_c, curr_c in worst:
                    print(f'    {chord_idx:>6} {voice:>6} {NOTE_NAMES[pc]:<5} '
                          f'{prev_c:>8.1f} {curr_c:>8.1f} {gap:>7.1f}')

        leaders.append((version, rows[0]['dir'], rows[0]['params'], rows[0]['suffix'],
                        rows[0]['path']))

    print(f'\n{"=" * 108}')
    print('Report only — no winner was chosen. Row order reflects --sort_by.')

    render_start_time = None
    if args.render:
        render_start_time = time.time()
        print('\nRendering leading rows with WreckingCrew.py...\n')
        for version, d, params, w_suffix, _path in leaders:
            print(f'  {version}  →  {os.path.basename(d)}  [{w_suffix}]')
            cmd = [
                sys.executable, os.path.join(base_dir, 'WreckingCrew.py'),
                '--chorale_name', version,
                f'--cent_file_partial={w_suffix}',
                '--no_show_volumes',
                '--album', str(args.album),
                '--tolerance', str(params['tolerance']),
                '--ratio_factor', str(params['ratio_factor']),
                '--stability_factor', str(params['stability_factor']),
                '--max_delta', str(params['max_delta']),
                '--limit_max', str(params['limit_max']),
                '--numpy_dir', d,
                '--spread', str(args.spread_render),
                '--max_cents_slide', str(args.max_cents_slide),
                '--bass_sustain', str(args.bass_sustain),
            ]
            if args.short_repeats:
                cmd.append('--short_repeats')
            subprocess.run(cmd, check=True)
        print('\nDone rendering.')

    if args.copy_mp3_to:
        uploads = (args.uploads_dir if os.path.isabs(args.uploads_dir)
                   else os.path.join(base_dir, args.uploads_dir))
        dest = os.path.expanduser(args.copy_mp3_to)
        os.makedirs(dest, exist_ok=True)
        print(f'\nCopying MP3s to {dest} ...\n')
        for version, d, params, _sfx, _path in leaders:
            bwv_num = version[-2:]   # '53' for bwv253, '60' for bwv260
            pattern = os.path.join(
                uploads,
                f'ball9-t{bwv_num}?_lm{params["limit_max"]}_r{params["ratio_factor"]:.2f}'
                f'_sf{params["stability_factor"]:.2f}_md{params["max_delta"]:02d}'
                f'_sp??_t{params["tolerance"]}_*.mp3'
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
        print(f'\nCopying the leading row per chorale (by {args.sort_by}) to {dest} ...')
        print('  Ordering is not a quality verdict — confirm against the report above.\n')
        for version, d, params, w_suffix, _path in leaders:
            src = _path
            if not os.path.exists(src):
                print(f'  {version}: not found — {src}')
                continue
            dest_filename = (f'{version}_t{params["tolerance"]}'
                             f'_r{params["ratio_factor"]:.3f}_lm{params["limit_max"]}{w_suffix}')
            shutil.copy2(src, os.path.join(dest, dest_filename))
            print(f'  {version}  →  {dest_filename}  (from {os.path.basename(d)})')
        print('\nDone copying.')


if __name__ == '__main__':
    main()
