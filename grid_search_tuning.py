#!/usr/bin/env python3
"""
Grid search for optimal straw-man tuning parameters.

Searches over:
  limit_max : prime numbers 17–53
  tolerance : [1, 2, 3, 4]
  rolls     : [1, 2, 3, 4]
  spread    : std-dev (cents) of the normal perturbation applied to the
              initial 12-TET cent values before tuning (spread=0 = no
              randomisation).  Because spread>0 is stochastic, each
              (limit_max, tolerance, rolls, spread>0) combination is
              repeated N_TRIALS times and the scores are averaged.

For each combination, runs all 12 chorales and records
  - mean/median/p90 score  (averaged across trials when spread>0)
  - score_std              (std across trials; 0 when spread=0)
  - mean/median/p90/max time per unique chord (ms)

Usage:
  conda activate csound
  python grid_search_tuning.py
"""

import os, sys, time
import numpy as np
import pandas as pd
from itertools import count, permutations

# ── paths ──────────────────────────────────────────────────────────────────
BASE_DIR    = os.path.dirname(os.path.abspath(__file__))
NUMPY_DIR   = os.path.join(BASE_DIR, 'Archive', 'straw-man')
RESULTS_CSV = os.path.join(BASE_DIR, 'grid_search_results.csv')

if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

import adaptive_tuning_util as atu


# ── constants ───────────────────────────────────────────────────────────────
CHORALE_LIST = [
    'bwv253', 'bwv254', 'bwv255', 'bwv256', 'bwv257', 'bwv258',
    'bwv259', 'bwv260', 'bwv261', 'bwv262', 'bwv263', 'bwv264',
]
PRIME_LIMITS     = [17, 19, 23]
TOLERANCE_VALUES = [1, 2, 3, 4]
ROLLS_VALUES     = [0, 1, 5, 8]
SPREAD_VALUES    = [0]   # cents; add more values (e.g. 3, 14) as desired
N_TRIALS         = 5        # repeated runs per combination when spread > 0


# ── core algorithm (from Straw_man_tuning.ipynb) ────────────────────────────

def _find_cent_value_prev_target(pitch_class_target,
                                  pitch_class_chord_prev,
                                  cent_value_chord_prev):
    """Return the cent value of pitch_class_target in the previous chord, or None."""
    if pitch_class_target in pitch_class_chord_prev:
        return np.unique(
            cent_value_chord_prev[np.where(pitch_class_chord_prev == pitch_class_target)]
        )[0]
    return None


def build_straw_man_chord(cent_value_chord, cent_value_chord_prev,
                           tolerance, rolls,
                           chord_scorer, low_number_ratios, tonal_diamond):
    """
    Tune one chord using low-number ratios without simulated annealing.

    Parameters
    ----------
    cent_value_chord       : np.ndarray shape (4,) – 12-TET cents for this chord
    cent_value_chord_prev  : np.ndarray shape (4,) – tuned cents from previous chord
    tolerance              : int   – ratio search tolerance
    rolls                  : int   – number of cyclic rolls to try (np.arange(rolls))
    chord_scorer           : atu.ChordScorer
    low_number_ratios      : atu.LowNumberRatioIntervals
    tonal_diamond          : np.ndarray

    Returns
    -------
    np.ndarray shape (4,) – tuned cent values (pitch-class order restored)
    """
    initial_midi_chord        = atu.pitch_class_from_cents(cent_value_chord)
    best_cent_value_chord     = cent_value_chord.copy()
    best_score                = 9999.0
    pitch_class_chord_prev    = atu.pitch_class_from_cents(cent_value_chord_prev)

    for roll_amount in np.arange(rolls):
        proposed = np.roll(cent_value_chord, roll_amount).copy()
        chord_size = proposed.shape[0]
        pitch_class_chord = atu.pitch_class_from_cents(proposed)

        for interval_inx in permutations(np.arange(chord_size), 2):
            i0, i1 = interval_inx
            pc_interval   = np.array([pitch_class_chord[i0], pitch_class_chord[i1]])
            cent_interval = np.array([proposed[i0], proposed[i1]])

            _, _, pitch_class_target = atu.pitch_class_interval(pc_interval)
            _, cent_moves, _         = atu.cent_value_interval(cent_interval)

            cent_prev_target = _find_cent_value_prev_target(
                pitch_class_target, pitch_class_chord_prev, cent_value_chord_prev)

            indices, _ = low_number_ratios.select_ratios(
                cent_interval, cent_prev_target, tolerance)

            if indices.size == 0:
                continue

            saved = proposed.copy()
            proposed[i1] = (proposed[i0] + tonal_diamond[indices[0], 1] * cent_moves) % 1200

            new_score = chord_scorer.score_chord(proposed, tolerance=tolerance)
            if new_score >= best_score:
                proposed = saved          # revert
            else:
                best_cent_value_chord = proposed.copy()
                best_score            = new_score

    result, _ = atu.rearrange_notes(best_cent_value_chord, initial_midi_chord)
    return result


# ── test harness for one chorale ─────────────────────────────────────────────

def run_chorale(version, tolerance, rolls, spread,
                chord_scorer, low_number_ratios, tonal_diamond):
    """
    Tune all chords in one chorale and return per-unique-chord scores & times.

    Parameters
    ----------
    spread : int
        Std-dev in cents for the normal perturbation applied to the initial
        12-TET cent values (spread=0 means no perturbation, deterministic).
        Applied only to cent values, not pitch-class compression.

    Returns
    -------
    scores : np.ndarray  – final score for every chord position
    times  : np.ndarray  – ms elapsed per unique chord computation
    """
    _, _, chorale, _, _, _ = atu.load_chorale_in_cents(
        version, NUMPY_DIR, werck_top_notes=False)

    # Convert to 12-TET cents (same as the notebook)
    cent_value_chorale = np.array(
        [(chord % 12) * 100 for chord in chorale.T]).T.astype(int)

    prev_midi_chord        = np.zeros(4, dtype=int)
    cent_value_chord_prev  = np.zeros(4, dtype=int)
    tuned_cent_value_chord = np.zeros(4, dtype=int)

    scores = []
    times  = []

    for inx, midi_chord, tet_chord in zip(
            count(0), chorale.T, cent_value_chorale.T):

        if not np.array_equal(prev_midi_chord, midi_chord):
            pc_chord = midi_chord % 12
            # pitch-class perturb: compress only, never spread
            pc_compressed, pc_inv = atu.perturb(pc_chord, spread=0)
            # cent-value perturb: apply requested spread
            cv_compressed, cv_inv = atu.perturb(tet_chord, spread=spread)

            t0 = time.perf_counter()
            tuned_compressed = build_straw_man_chord(
                cv_compressed, cent_value_chord_prev,
                tolerance, rolls,
                chord_scorer, low_number_ratios, tonal_diamond)
            elapsed_ms = (time.perf_counter() - t0) * 1000

            tuned_cent_value_chord = tuned_compressed[cv_inv]
            times.append(elapsed_ms)

            prev_midi_chord       = midi_chord.copy()
            cent_value_chord_prev = tuned_cent_value_chord.copy()

        scores.append(
            chord_scorer.score_chord(tuned_cent_value_chord, tolerance=tolerance))

    return np.array(scores), np.array(times)


# ── grid search ──────────────────────────────────────────────────────────────

def grid_search():
    param_combos = [
        (lm, tol, r, sp)
        for lm  in PRIME_LIMITS
        for tol in TOLERANCE_VALUES
        for r   in ROLLS_VALUES
        for sp  in SPREAD_VALUES
    ]
    total = len(param_combos)
    trials_note = f"(spread>0 averaged over {N_TRIALS} trials)"
    print(f"Grid search: {total} combinations × {len(CHORALE_LIST)} chorales  {trials_note}\n")

    hdr = (f"{'#':>4} {'lim':>4} {'tol':>4} {'rls':>4} {'spd':>4} | "
           f"{'mean_sc':>8} {'med_sc':>7} {'p90_sc':>7} {'sc_std':>7} | "
           f"{'ms/ch':>7} {'p90ms':>7} {'maxms':>7}")
    print(hdr)
    print("-" * len(hdr))

    results = []

    for n, (limit_max, tolerance, rolls, spread) in enumerate(param_combos, 1):
        tonal_diamond     = atu.build_tonal_diamond(limit_max)[:-1]
        chord_scorer      = atu.ChordScorer(tonal_diamond)
        low_number_ratios = atu.LowNumberRatioIntervals(tonal_diamond)

        n_trials = N_TRIALS if spread > 0 else 1
        trial_means = []   # mean score per trial (for std-across-trials)
        all_scores  = []
        all_times   = []

        for _ in range(n_trials):
            trial_scores = []
            for version in CHORALE_LIST:
                scores, times = run_chorale(
                    version, tolerance, rolls, spread,
                    chord_scorer, low_number_ratios, tonal_diamond)
                trial_scores.extend(scores.tolist())
                all_times.extend(times.tolist())
            all_scores.extend(trial_scores)
            trial_means.append(float(np.mean(trial_scores)))

        sc = np.array(all_scores)
        ms = np.array(all_times)

        row = dict(
            limit_max     = limit_max,
            tolerance     = tolerance,
            rolls         = rolls,
            spread        = spread,
            n_trials      = n_trials,
            mean_score    = float(np.mean(sc)),
            median_score  = float(np.median(sc)),
            min_score     = float(np.min(sc)),
            max_score     = float(np.max(sc)),
            p10_score     = float(np.percentile(sc, 10)),
            p90_score     = float(np.percentile(sc, 90)),
            score_std     = float(np.std(trial_means)),  # variability across trials
            mean_ms       = float(np.mean(ms)),
            median_ms     = float(np.median(ms)),
            p90_ms        = float(np.percentile(ms, 90)),
            max_ms        = float(np.max(ms)),
            n_chords      = len(sc),
        )
        results.append(row)

        print(f"{n:>4} {limit_max:>4} {tolerance:>4} {rolls:>4} {spread:>4} | "
              f"{row['mean_score']:>8.1f} {row['median_score']:>7.1f} "
              f"{row['p90_score']:>7.1f} {row['score_std']:>7.1f} | "
              f"{row['mean_ms']:>7.2f} {row['p90_ms']:>7.2f} {row['max_ms']:>7.2f}")

    return pd.DataFrame(results)


# ── analysis ─────────────────────────────────────────────────────────────────

def analyze(df):
    sep = "=" * 80
    print(f"\n{sep}")
    print("ANALYSIS")
    print(sep)

    # ── latency filter ───────────────────────────────────────────────────────
    fast = df[df['p90_ms'] < 100.0].copy()
    n_fast = len(fast)
    print(f"\n{n_fast}/{len(df)} combinations meet p90 < 100 ms latency target.")
    if fast.empty:
        print("WARNING: no combination meets 100 ms target; analysing all.")
        fast = df.copy()

    fast_sorted = fast.sort_values('mean_score').reset_index(drop=True)

    cols_show = ['limit_max', 'tolerance', 'rolls', 'spread',
                 'mean_score', 'median_score', 'p90_score', 'score_std',
                 'mean_ms', 'p90_ms', 'max_ms']

    print("\nTop 15 combinations by mean score (p90_ms < 100 ms):")
    print(fast_sorted[cols_show].head(15).to_string(index=False))

    best = fast_sorted.iloc[0]
    print(f"\n{'─'*60}")
    print("RECOMMENDED PARAMETERS:")
    print(f"  limit_max  = {int(best['limit_max'])}")
    print(f"  tolerance  = {int(best['tolerance'])}")
    print(f"  rolls      = {int(best['rolls'])}")
    print(f"  spread     = {int(best['spread'])} cents")
    print(f"  mean_score = {best['mean_score']:.2f}  (lower is more consonant)")
    print(f"  score_std  = {best['score_std']:.2f}  (across {int(best['n_trials'])} trials)")
    print(f"  mean ms/chord = {best['mean_ms']:.2f} ms")
    print(f"  p90  ms/chord = {best['p90_ms']:.2f} ms")
    print(f"  max  ms/chord = {best['max_ms']:.2f} ms")
    print(f"{'─'*60}")

    # ── marginal effects ─────────────────────────────────────────────────────
    def show_group(label, col):
        g = df.groupby(col)[['mean_score', 'score_std', 'mean_ms', 'p90_ms', 'max_ms']].mean()
        print(f"\nEffect of {label} (averaged over all other parameters):")
        print(g.round(2).to_string())

    show_group('spread',    'spread')
    show_group('rolls',     'rolls')
    show_group('tolerance', 'tolerance')
    show_group('limit_max', 'limit_max')

    # ── spread comparison: score distribution per spread value ───────────────
    print("\nScore distribution by spread value:")
    for sp, grp in df.groupby('spread'):
        label = f"spread={sp:>2}"
        sc_vals = grp['mean_score']
        print(f"  {label}: mean={sc_vals.mean():.1f}, "
              f"min={sc_vals.min():.1f}, max={sc_vals.max():.1f}, "
              f"avg_score_std={grp['score_std'].mean():.2f}")

    # ── speed–score trade-off table ──────────────────────────────────────────
    print("\nPareto-optimal front (lowest mean_score for each max_ms bucket):")
    df_s = fast_sorted.copy()
    df_s['ms_bucket'] = pd.cut(df_s['p90_ms'],
                               bins=[0, 5, 10, 20, 50, 100],
                               labels=['<5', '5-10', '10-20', '20-50', '50-100'])
    pareto = (df_s.groupby('ms_bucket', observed=True)
                  .apply(lambda g: g.nsmallest(1, 'mean_score'), include_groups=False)
                  .reset_index(level=0)
                  .reset_index(drop=True))
    print(pareto[['ms_bucket'] + cols_show].to_string(index=False))

    return fast_sorted


# ── entry point ───────────────────────────────────────────────────────────────

if __name__ == '__main__':
    print("Starting grid search for straw-man tuning parameters.")
    print(f"limit_max values : {PRIME_LIMITS}")
    print(f"tolerance values : {TOLERANCE_VALUES}")
    print(f"rolls values     : {ROLLS_VALUES}")
    print(f"spread values    : {SPREAD_VALUES}  (N_TRIALS={N_TRIALS} for spread>0)")
    print(f"chorales         : {CHORALE_LIST}\n")

    t0 = time.perf_counter()
    df = grid_search()
    elapsed = time.perf_counter() - t0

    df.to_csv(RESULTS_CSV, index=False)
    print(f"\nResults saved to {RESULTS_CSV}")
    print(f"Total wall time : {elapsed/60:.1f} min")

    analyze(df)
