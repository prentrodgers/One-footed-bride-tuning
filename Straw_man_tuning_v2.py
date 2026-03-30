#!/usr/bin/env python
# coding: utf-8

# ## Building "Straw Man" Chords v2 — SA-based tuning
# <p>This version uses simulated annealing to probabilistically choose which ratio to use per interval,
# lets the full chord build complete before evaluating (no mid-chord rejection unless score > 1000),
# and uses SA accept/reject on the completed chord.</p>
# <p>We show to additional cells to illustrate how we score chords, and a heavily commented version of how we choose intervals in this base case. </p>
# <p>Why choose permutations, which counts intervals twice, up and down? I've found that it works better empirically. If you use combinations, which check 6 intervals, we force the initial note in the chord to never move. If it's allowed to drift like all the other notes in the chord, the results are better</p>
# <p>The outcome of this process is a chord that can be transposed to improve on horizontal consistency, that is choose a transposition that keeps cent values of pitch classes of adjacent chords in place, if possible. If it's not possible, then I build a glissando in csound to hide the change, to a certain degree. In this way we hear ideal intervals for every chord, at the expense of some effort of some voices to move from one cent value to another for the same pitch class, to optimize the current chord.</p>
#

import argparse, logging, os, sys, time
import multiprocessing
import numpy as np
from math import exp
from importlib import reload
from collections import Counter, defaultdict
from importlib import reload
base_dir = os.path.dirname(os.path.abspath(__file__))
numpy_dir = os.path.join(base_dir, 'Archive', 'straw-man')
import diamond_music_utils as dmu
import adaptive_tuning_util as atu
from itertools import count, combinations, permutations
rng = np.random.default_rng()

np.set_printoptions(legacy='1.25')

def start_logger(logfile: str, level=logging.INFO):
    # Reset the root logger
    root = logging.getLogger()
    root.handlers.clear()
    root.setLevel(level)

    # File handler only
    fh = logging.FileHandler(logfile, mode='w')
    fh.setLevel(level)

    formatter = logging.Formatter(
        fmt='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%d'
    )
    fh.setFormatter(formatter)

    root.addHandler(fh)

    root.info(f"Logger started, writing to {logfile}, level={logging.getLevelName(level)}")
    return root

start_logger(os.path.join(base_dir, 'test.log'), level = logging.INFO)
reload(atu)

def _choose_probabilities(num_choices, r=0.3):
    """
    Generate weighted probabilities favoring earlier (better) ratios.
    Borrowed from optimize_chords_sa_v2.py.
    """
    r = np.clip(r, 0.00001, 0.99999)
    probs = np.logspace(0.01, 10, num=num_choices, base=r)
    return probs / sum(probs)

def find_cent_value_prev_target(pitch_class_target, pitch_class_chord_prev, cent_value_chord_prev, chord_num):
    if pitch_class_target in pitch_class_chord_prev:
        cent_value_target = np.unique(cent_value_chord_prev[np.where(pitch_class_chord_prev==pitch_class_target)])[0]
        logging.debug(f'chord#: {chord_num} found {pitch_class_target in pitch_class_chord_prev = }, {cent_value_target = }, {pitch_class_chord_prev = }')
    else:
        logging.debug(f'chord#: {chord_num} not found {pitch_class_target in pitch_class_chord_prev = }, {pitch_class_chord_prev = }')
        cent_value_target = None
    return cent_value_target

# SA-based version of build_straw_man_chord.
# Instead of greedily accepting the lowest ratio, we use simulated annealing to:
# 1. Probabilistically choose which ratio to use per interval (temperature-dependent)
# 2. Let the full chord build complete before evaluating (only reject degenerate mid-chord)
# 3. Use SA accept/reject on the completed chord
def build_straw_man_chord_sa(cent_value_chord, cent_value_chord_prev, chord_num,
                              chord_scorer, low_number_ratios, tonal_diamond,
                              tolerance=1, print_values=False, rolls=4,
                              sa_iterations=100, initial_temperature=2.0, cooling_rate=0.995,
                              rng=None, ratio_factor=1.0, stability_factor=0.0, spread=7):
    if rng is None:
        rng = np.random.default_rng()
    logging.info(f'chord#: {chord_num} In build_straw_man_chord_sa. {tolerance = }, {sa_iterations = }, {initial_temperature = }, {cooling_rate = }')
    initial_midi_chord = atu.pitch_class_from_cents(cent_value_chord)
    best_cent_value_chord_so_far = cent_value_chord.copy()
    best_score = 9999
    pitch_class_chord_prev = atu.pitch_class_from_cents(cent_value_chord_prev)
    changed_cent_value_count = 0
    unchanged_cent_value_count = 0
    early_stop_count = 0
    early_stop_iters = []
    max_no_improve = max(10, sa_iterations // 10)

    for roll_amount in range(rolls):
        rolled_chord = np.roll(cent_value_chord, roll_amount)
        # Perturb starting position freshly for each roll so each roll explores a different neighbourhood
        if spread > 0:
            noise = np.array([
                int(round(np.clip(rng.normal(0, scale=spread), -49, 49)))
                for _ in range(rolled_chord.shape[0])
            ])
            perturbed_chord = (rolled_chord + noise) % 1200
        else:
            perturbed_chord = rolled_chord.copy()
        chord_size = perturbed_chord.shape[0]
        pitch_class_chord = atu.pitch_class_from_cents(rolled_chord)  # pitch classes from unperturbed chord
        temperature = initial_temperature
        current_solution = perturbed_chord.copy()
        current_score = chord_scorer.score_chord(current_solution, tolerance=tolerance)
        logging.debug(f'chord#: {chord_num} roll_amount: {roll_amount}, initial score: {current_score}')
        prev_roll_best = current_score
        iterations_since_improvement = 0

        for sa_iter in range(sa_iterations):
            proposed = current_solution.copy()

            for interval_inx in combinations(np.arange(chord_size), 2):
                pitch_class_interval = np.array([pitch_class_chord[interval_inx[0]], pitch_class_chord[interval_inx[1]]])
                cent_value_interval = np.array([proposed[interval_inx[0]], proposed[interval_inx[1]]])
                pitch_class_delta, pitch_class_moves, pitch_class_target = atu.pitch_class_interval(pitch_class_interval)
                cent_value_delta, cent_value_moves, cent_value_target = atu.cent_value_interval(cent_value_interval)

                cent_value_target = find_cent_value_prev_target(pitch_class_target, pitch_class_chord_prev, cent_value_chord_prev, chord_num)
                indices_to_tonal_diamond, _ = low_number_ratios.select_ratios(cent_value_interval, cent_value_target, tolerance, ratio_factor=ratio_factor, stability_factor=stability_factor)

                if indices_to_tonal_diamond.size == 0:
                    continue

                # Filter to only ratios that preserve the pitch class of the target voice (hard constraint)
                required_pc = int(initial_midi_chord[interval_inx[1]])
                pc_valid = [
                    idx for idx in indices_to_tonal_diamond[:min(len(indices_to_tonal_diamond), 15)]
                    if int(atu.pitch_class_from_cents((proposed[interval_inx[0]] + tonal_diamond[idx][1] * cent_value_moves) % 1200)) == required_pc
                ]
                if len(pc_valid) == 0:
                    continue  # no ratio preserves pitch class; skip this interval

                num_available = len(pc_valid)

                # Temperature-dependent ratio selection
                if num_available > 1:
                    if temperature > initial_temperature * 0.5:
                        # High temperature: uniform random exploration
                        interval_choice = rng.integers(0, num_available)
                    else:
                        # Low temperature: weighted toward lower (better) ratios
                        interval_choice = rng.choice(num_available, p=_choose_probabilities(num_available))
                else:
                    interval_choice = 0

                # Apply the interval change (pitch class is guaranteed preserved)
                proposed[interval_inx[1]] = (proposed[interval_inx[0]] + tonal_diamond[pc_valid[interval_choice]][1] * cent_value_moves) % 1200

            # SA accept/reject on the COMPLETED chord
            new_score = chord_scorer.score_chord(proposed, tolerance=tolerance)
            delta = new_score - current_score
            if delta < 0 or (temperature > 0 and rng.random() < exp(-delta / temperature)):
                current_solution = proposed.copy()
                current_score = new_score
                changed_cent_value_count += 1
                if new_score < best_score:
                    best_score = new_score
                    best_cent_value_chord_so_far = proposed.copy()
                    logging.debug(f'chord#: {chord_num} new best: roll={roll_amount}, sa_iter={sa_iter}, score={best_score}')
            else:
                unchanged_cent_value_count += 1

            # Early stopping: break if this roll hasn't improved for max_no_improve consecutive iters
            if current_score < prev_roll_best:
                prev_roll_best = current_score
                iterations_since_improvement = 0
            else:
                iterations_since_improvement += 1
                if iterations_since_improvement >= max_no_improve:
                    early_stop_count += 1
                    early_stop_iters.append(sa_iter + 1)
                    logging.debug(f'chord#: {chord_num} roll {roll_amount}: early stop at iter {sa_iter + 1}/{sa_iterations}')
                    break

            temperature *= cooling_rate

        if print_values:
            print(f'  roll {roll_amount}: best_score so far = {best_score}')

    proposed_cent_value_chord, _ = atu.rearrange_notes(best_cent_value_chord_so_far, initial_midi_chord)
    logging.info(f'chord#: {chord_num} done. best_score={best_score}, changed={changed_cent_value_count}, unchanged={unchanged_cent_value_count}, early_stops={early_stop_count}/{rolls}')
    return proposed_cent_value_chord, changed_cent_value_count, unchanged_cent_value_count, early_stop_iters


def tune_chorale_worker(args_dict):
    """Top-level function for multiprocessing. Each worker tunes the full chorale independently."""
    seed = args_dict['seed']
    worker_rng = np.random.default_rng(seed)
    tonal_diamond = args_dict['tonal_diamond']
    chorale = args_dict['chorale']
    cent_value_chorale = args_dict['cent_value_chorale']
    tolerance = args_dict['tolerance']
    rolls = args_dict['rolls']
    sa_iterations = args_dict['sa_iterations']
    initial_temperature = args_dict['initial_temperature']
    cooling_rate = args_dict['cooling_rate']
    ratio_factor = args_dict.get('ratio_factor', 1.0)
    stability_factor = args_dict.get('stability_factor', 0.0)
    spread = args_dict.get('spread', 7)

    chord_scorer = atu.ChordScorer(tonal_diamond)
    low_number_ratios = atu.LowNumberRatioIntervals(tonal_diamond)

    prev_midi_chord = np.zeros(4, dtype=int)
    cent_value_chord_prev = np.zeros(4, dtype=int)
    final_cent_value_chorale = np.zeros_like(chorale.T)
    final_score = np.zeros(chorale.T.shape[0])

    tuned_cent_value_chord = cent_value_chorale.T[0].copy()
    all_early_stop_iters = []

    for inx, initial_midi_chord, initial_cent_value_chord in zip(count(0, 1), chorale.T, cent_value_chorale.T):
        if not np.array_equal(prev_midi_chord, initial_midi_chord):
            initial_pitch_class_chord = initial_midi_chord % 12
            initial_pitch_class_chord_compressed, pitch_class_inverse = atu.perturb(initial_pitch_class_chord, spread=0)
            initial_cent_value_chord_compressed, cent_value_inverse = atu.perturb(initial_cent_value_chord, spread=0)

            tuned_cent_value_chord_compressed, changed, unchanged, es_iters = build_straw_man_chord_sa(
                initial_cent_value_chord_compressed, cent_value_chord_prev, inx,
                chord_scorer, low_number_ratios, tonal_diamond,
                tolerance=tolerance, print_values=False, rolls=rolls,
                sa_iterations=sa_iterations, initial_temperature=initial_temperature, cooling_rate=cooling_rate,
                rng=worker_rng, ratio_factor=ratio_factor, stability_factor=stability_factor, spread=spread)
            tuned_cent_value_chord = tuned_cent_value_chord_compressed[cent_value_inverse]
            all_early_stop_iters.extend(es_iters)

        final_cent_value_chorale[inx] = tuned_cent_value_chord.copy()
        final_score[inx] = chord_scorer.score_chord(tuned_cent_value_chord, tolerance=tolerance)
        prev_midi_chord = initial_midi_chord.copy()
        cent_value_chord_prev = tuned_cent_value_chord.copy()

    return final_cent_value_chorale, final_score, all_early_stop_iters


def merge_results(all_results):
    """Select the single run with the lowest total score.

    Per-chord best selection was removed because it mixes chords from independent
    tuning runs, breaking the continuity that each run carefully builds chord-by-chord.
    """
    best_total = None
    best_cents = None
    best_scores = None
    all_iters = []
    for cents, scores, es_iters in all_results:
        total = float(np.sum(scores))
        all_iters.extend(es_iters)
        if best_total is None or total < best_total:
            best_total = total
            best_cents = cents.copy()
            best_scores = scores.copy()
    return best_cents, best_scores, all_iters


def _print_early_stop_histogram(iters, sa_iterations, bucket_size=100):
    """Print a one-line bucketed histogram of early-stop iteration counts."""
    if not iters:
        return
    n_buckets = (sa_iterations + bucket_size - 1) // bucket_size
    counts = [0] * n_buckets
    for it in iters:
        b = min((it - 1) // bucket_size, n_buckets - 1)
        counts[b] += 1
    parts = []
    for i, c in enumerate(counts):
        if c:
            lo = i * bucket_size + 1
            hi = min((i + 1) * bucket_size, sa_iterations)
            parts.append(f"{lo}-{hi}: {c}")
    print(f"  Early stops ({len(iters)} total): {', '.join(parts)}")


def compute_spread_score(cent_value_chorale_4n, chorale):
    """Frequency-weighted average pitch-class cent spread across the chorale (lower is better).

    Parameters
    ----------
    cent_value_chorale_4n : np.ndarray, shape (4, N)
        Tuned cent values, one column per chord.
    chorale : np.ndarray, shape (4, N)
        Original MIDI notes, used to compute pitch-class occurrence frequencies.
    """
    pitch_class_counts = Counter((chorale % 12).flatten().tolist())
    total_count = sum(pitch_class_counts.values())

    pc_cents = defaultdict(list)
    for chord_cents in cent_value_chorale_4n.T:          # iterate over N chords
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


def load_and_merge_previous(output_file, best_cents, best_scores, chord_scorer, tolerance,
                             chorale=None, spread_weight=0.5):
    """Keep whichever result has the lower combined metric: mean_score + spread_weight * spread.

    spread_weight=0 falls back to score-only comparison.
    Per-chord merging is intentionally absent: mixing chords from independent runs
    breaks the adjacency continuity each run carefully builds.
    """
    if not os.path.exists(output_file):
        return best_cents, best_scores

    prev = np.load(output_file)          # shape (4, N)
    prev_chords = (prev.T) % 1200        # shape (N, 4)
    prev_scores = np.array([chord_scorer.score_chord(prev_chords[i], tolerance)
                             for i in range(prev_chords.shape[0])])

    if chorale is not None and spread_weight > 0:
        # best_cents is (N, 4); transpose to (4, N) for compute_spread_score
        curr_spread = compute_spread_score(best_cents.T, chorale)
        prev_spread = compute_spread_score(prev, chorale)
        curr_combined = np.mean(best_scores) + spread_weight * curr_spread
        prev_combined = np.mean(prev_scores) + spread_weight * prev_spread
        if prev_combined < curr_combined:
            print(f"  Previous result is better — keeping previous"
                  f" (combined {prev_combined:.2f} vs {curr_combined:.2f};"
                  f" score {np.mean(prev_scores):.1f} vs {np.mean(best_scores):.1f};"
                  f" spread {prev_spread:.1f} vs {curr_spread:.1f}¢)")
            return prev_chords, prev_scores
        else:
            print(f"  Current result is better — keeping current"
                  f" (combined {curr_combined:.2f} vs {prev_combined:.2f};"
                  f" score {np.mean(best_scores):.1f} vs {np.mean(prev_scores):.1f};"
                  f" spread {curr_spread:.1f} vs {prev_spread:.1f}¢)")
    else:
        if np.sum(prev_scores) < np.sum(best_scores):
            print(f"  Previous result is better (total {np.sum(prev_scores):.1f} vs {np.sum(best_scores):.1f}) — keeping previous")
            return prev_chords, prev_scores
        else:
            print(f"  Current result is better (total {np.sum(best_scores):.1f} vs {np.sum(prev_scores):.1f}) — keeping current")
    return best_cents, best_scores


def _max_pitch_class_gap(prev_chord_cents, curr_chord_cents):
    """Return the largest cent distance between shared pitch classes in adjacent chords."""
    if prev_chord_cents is None or len(prev_chord_cents) == 0:
        return 0.0, None, None, None, None

    prev_map = {}
    for pc, cents in zip(atu.pitch_class_from_cents(prev_chord_cents), prev_chord_cents):
        pc = int(pc)
        prev_map.setdefault(pc, []).append(float(cents))

    worst_gap = 0.0
    worst_pc = None
    worst_curr = None
    worst_prev = None
    worst_idx = None

    for idx, (pc, cents) in enumerate(zip(atu.pitch_class_from_cents(curr_chord_cents), curr_chord_cents)):
        pc = int(pc)
        prev_list = prev_map.get(pc)
        if not prev_list:
            continue
        deltas = [atu.cent_distance_mod_1200(cents, p) for p in prev_list]
        min_gap = float(min(deltas))
        if min_gap > worst_gap:
            worst_gap = min_gap
            worst_pc = pc
            worst_curr = float(cents)
            worst_prev = prev_list[int(np.argmin(deltas))]
            worst_idx = idx

    return worst_gap, worst_pc, worst_curr, worst_prev, worst_idx


def enforce_continuity(final_cent_value_chorale, chorale, chord_scorer, low_number_ratios,
                       tonal_diamond, tolerance, rolls, sa_iterations, initial_temperature,
                       cooling_rate, ratio_factor, rng, max_gap=40, retune_on_gaps=3,
                       stability_factor=0.0, spread=7):
    """Post-hoc pass: re-tune chords whose pitch classes jump more than max_gap cents
    compared to the previous chord.  Three escalating fallbacks are tried:
      1. Re-run SA (up to retune_on_gaps times)
      2. Uniform shift of the whole chord toward the previous pitch class values
      3. Force the worst-offending voice to the previous chord's cent value
    """
    adjusted = np.array(final_cent_value_chorale, dtype=float, copy=True)
    fixes = 0
    sa_solved = 0       # SA retune closed the gap
    fallback1_used = 0  # uniform shift needed
    fallback2_used = 0  # force voice needed
    prev_midi_chord = np.zeros(4, dtype=int)

    for chord_idx in range(1, adjusted.shape[0]):
        curr_midi = chorale.T[chord_idx]
        if np.array_equal(curr_midi, prev_midi_chord):
            # Held note (identical consecutive MIDI chord): copy any re-tuning
            # that was applied to the previous chord position so that both
            # positions of the same held note always share the same cent values.
            adjusted[chord_idx] = adjusted[chord_idx - 1]
            prev_midi_chord = curr_midi.copy()
            continue

        prev_chord = adjusted[chord_idx - 1]
        curr_chord = adjusted[chord_idx]
        gap_value, pc, curr_cent, prev_cent, voice_idx = _max_pitch_class_gap(prev_chord, curr_chord)

        if gap_value <= max_gap:
            prev_midi_chord = curr_midi.copy()
            continue

        logging.info(
            f'chord {chord_idx}: PC {pc} gap {gap_value:.1f}¢ > {max_gap}¢ — retuning'
        )

        retries = 0
        while gap_value > max_gap and retries < retune_on_gaps:
            retries += 1
            fixes += 1
            curr_compressed, inv = atu.perturb(curr_chord, spread=0)
            retuned_compressed, _, _, _ = build_straw_man_chord_sa(
                curr_compressed, prev_chord, chord_idx,
                chord_scorer, low_number_ratios, tonal_diamond,
                tolerance=tolerance, print_values=False, rolls=rolls,
                sa_iterations=sa_iterations, initial_temperature=initial_temperature,
                cooling_rate=cooling_rate, rng=rng, ratio_factor=ratio_factor,
                stability_factor=stability_factor, spread=spread)
            retuned = retuned_compressed[inv]
            adjusted[chord_idx] = retuned
            curr_chord = retuned
            gap_value, pc, curr_cent, prev_cent, voice_idx = _max_pitch_class_gap(prev_chord, curr_chord)

        if gap_value <= max_gap:
            sa_solved += 1
            logging.info(f'chord {chord_idx}: SA solved gap in {retries} attempt(s), residual {gap_value:.1f}¢')

        # Fallback 1: uniform shift toward previous pitch class
        if gap_value > max_gap and voice_idx is not None and prev_cent is not None:
            direction = 1 if (curr_cent - prev_cent) >= 0 else -1
            shift_value = (prev_cent + direction * max_gap) - curr_cent
            if abs(shift_value) > 0.1:
                fallback1_used += 1
                logging.info(f'chord {chord_idx}: SA exhausted {retries} attempts, uniform shift {shift_value:+.1f}¢')
                adjusted[chord_idx] = (curr_chord + shift_value + 1200) % 1200
                curr_chord = adjusted[chord_idx]
                gap_value, pc, curr_cent, prev_cent, voice_idx = _max_pitch_class_gap(prev_chord, curr_chord)

        # Fallback 2: force the offending voice to the previous cent value
        if gap_value > max_gap and voice_idx is not None and prev_cent is not None:
            fallback2_used += 1
            logging.warning(
                f'chord {chord_idx}: forcing voice {voice_idx} (PC {pc}) to prev cent {prev_cent:.1f}¢'
            )
            adjusted[chord_idx, voice_idx] = prev_cent

        prev_midi_chord = curr_midi.copy()

    if fixes > 0:
        total_gaps = sa_solved + fallback1_used + fallback2_used
        logging.info(
            f'Continuity enforcement: {total_gaps} gap(s) found, '
            f'{sa_solved} solved by SA ({fixes} total attempts), '
            f'{fallback1_used} uniform shift, {fallback2_used} forced'
        )
    return adjusted


def snap_pitch_classes_to_mode(final_cent_value_chorale, chorale, snap_tolerance):
    """Snap pitch-class cent values toward the modal cent for that pitch class.

    For each of the 12 pitch classes, compute the modal cent value (most common
    value, rounded to the nearest 5¢) across the whole chorale.  Then, for each
    voice in each chord, if the cent value is within snap_tolerance of the mode,
    snap it to the mode — but only if doing so preserves the original pitch class.

    Parameters
    ----------
    final_cent_value_chorale : np.ndarray, shape (N_chords, 4)
        Tuned cent values, one row per chord.
    chorale : np.ndarray, shape (4, N_chords)
        Original MIDI notes (used only to skip repeated chords, not for PC checks).
    snap_tolerance : float
        Maximum cent distance from the mode to trigger a snap.  0 disables snapping.

    Returns
    -------
    np.ndarray, shape (N_chords, 4)
        Updated cent value array with snapped values where applicable.
    """
    if snap_tolerance <= 0:
        return final_cent_value_chorale

    adjusted = np.array(final_cent_value_chorale, dtype=float, copy=True)
    n_chords, n_voices = adjusted.shape

    # Collect all cent values per pitch class
    pc_cents = {pc: [] for pc in range(12)}
    for chord_idx in range(n_chords):
        for v in range(n_voices):
            c = float(adjusted[chord_idx, v]) % 1200
            pc = int(atu.pitch_class_from_cents(c))
            pc_cents[pc].append(c)

    # Compute mode for each pitch class (rounded to nearest 5¢)
    pc_mode = {}
    for pc, cents_list in pc_cents.items():
        if not cents_list:
            continue
        rounded = [round(c / 5) * 5 for c in cents_list]
        # find most common rounded value
        counts = {}
        for v in rounded:
            counts[v] = counts.get(v, 0) + 1
        pc_mode[pc] = max(counts, key=counts.__getitem__)

    # Snap values that are within snap_tolerance of their pitch class mode
    snapped = 0
    reverted = 0
    for chord_idx in range(n_chords):
        for v in range(n_voices):
            orig_c = float(adjusted[chord_idx, v]) % 1200
            orig_pc = int(atu.pitch_class_from_cents(orig_c))
            mode_c = pc_mode.get(orig_pc)
            if mode_c is None:
                continue
            dist = atu.cent_distance_mod_1200(orig_c, mode_c)
            if dist <= snap_tolerance:
                new_c = float(mode_c) % 1200
                new_pc = int(atu.pitch_class_from_cents(new_c))
                if new_pc == orig_pc:
                    adjusted[chord_idx, v] = new_c
                    snapped += 1
                else:
                    reverted += 1

    logging.info(f'snap_pitch_classes_to_mode: snapped={snapped}, reverted (PC mismatch)={reverted}')
    return adjusted


def parse_args():
    parser = argparse.ArgumentParser(description='Straw Man tuning v2 — SA-based chord tuning using lowest number ratios')
    parser.add_argument('--limit_max', type=int, default=23, help='Maximum limit for tonal diamond (default: 23)')
    parser.add_argument('--max_delta', type=int, default=35, help='Maximum delta (default: 35)')
    parser.add_argument('--tolerance', type=int, default=1, help='Tolerance for chord scoring (default: 1)')
    parser.add_argument('--rolls', type=int, default=1, help='Number of rolls for chord permutations (default: 1)')
    parser.add_argument('--sa_iterations', type=int, default=100, help='Number of SA iterations per chord per roll (default: 100)')
    parser.add_argument('--initial_temperature', type=float, default=2.0, help='Starting SA temperature (default: 2.0)')
    parser.add_argument('--cooling_rate', type=float, default=0.995, help='Temperature multiplier per iteration (default: 0.995)')
    parser.add_argument('--ratio_factor', type=float, default=1.0, help='Consonance/stability trade-off: high favours low-limit ratios, low favours staying near the current interval; balance point ~1.7 (default: 1.0)')
    parser.add_argument('--stability_factor', type=float, default=0.5, help='Weight for cent distance from previous chord in the sort key; reduces cumulative pitch-class drift (default: 0.5)')
    parser.add_argument('--spread', type=int, default=7, help='Std dev of Gaussian noise (cents) added to each note at the start of each SA roll; 0 disables perturbation (default: 7)')
    parser.add_argument('--spread_weight', type=float, default=0.5, help='Weight of pitch-class spread in the keep/discard comparison: combined = mean_score + spread_weight * weighted_spread; 0 disables spread comparison (default: 0.5)')
    parser.add_argument('--include_list', type=str, default=None,
                        help='Slice of chords to include, e.g. "8:17" (default: None, use all chords)')
    parser.add_argument('--chorale_list', type=str, nargs='+', default=['bwv253'],
                        help='List of chorale versions to process (default: bwv253)')
    parser.add_argument('--print_values', action=argparse.BooleanOptionalAction, default=True,
                        help='Print interval details (default: True)')
    parser.add_argument('--print_finals', action=argparse.BooleanOptionalAction, default=True,
                        help='Print final chord results (default: True)')
    parser.add_argument('--print_initial', action=argparse.BooleanOptionalAction, default=True,
                        help='Print initial chord info (default: True)')
    parser.add_argument('--workers', type=int, default=1,
                        help='Number of parallel workers, each tuning the full chorale independently (default: 1)')
    parser.add_argument('--runs', type=int, default=1,
                        help='Number of sequential batches of --workers parallel runs. Total runs = workers × runs (default: 1)')
    parser.add_argument('--numpy_dir', type=str, default=None,
                        help='Directory to read/write chorale numpy files (default: Archive/straw-man)')
    parser.add_argument('--max_gap', type=float, default=40.0,
                        help='Maximum allowed cent jump between shared pitch classes in adjacent chords; 0 disables continuity enforcement (default: 40)')
    parser.add_argument('--retune_on_gaps', type=int, default=3,
                        help='Number of SA retune attempts for chords that exceed max_gap (default: 3)')
    parser.add_argument('--snap_tolerance', type=float, default=0.0,
                        help='Snap pitch-class cent values within this distance (¢) of the modal cent to the mode; 0 disables (default: 0)')
    return parser.parse_args()

def main():
    args = parse_args()
    print(' '.join(f'--{arg} {value}' for arg, value in vars(args).items()))

    reload(atu)
    start_logger(os.path.join(base_dir, 'test.log'), level = logging.INFO)
    global numpy_dir
    if args.numpy_dir is not None:
        numpy_dir = args.numpy_dir if os.path.isabs(args.numpy_dir) else os.path.join(base_dir, args.numpy_dir)
        os.makedirs(numpy_dir, exist_ok=True)
    print(f'{numpy_dir = }')
    limit_max = args.limit_max
    max_delta = args.max_delta
    tonal_diamond = atu.build_tonal_diamond(limit_max)[:-1] # stop using the 2 at the end.
    print(f'{limit_max = }, {tonal_diamond.shape = }')
    tolerance = args.tolerance
    rolls = args.rolls
    sa_iterations = args.sa_iterations
    initial_temperature = args.initial_temperature
    cooling_rate = args.cooling_rate
    chord_scorer = atu.ChordScorer(tonal_diamond)
    low_number_ratios = atu.LowNumberRatioIntervals(tonal_diamond)
    # parse include_list from string like "8:17" into a slice
    if args.include_list is not None:
        parts = args.include_list.split(':')
        include_list = slice(int(parts[0]), int(parts[1]) if len(parts) > 1 else None)
    else:
        include_list = None
    chorale_list = args.chorale_list
    print_values = args.print_values
    print_finals = args.print_finals
    print_initial = args.print_initial
    workers = args.workers
    num_runs = args.runs
    for version in chorale_list:
        cent_value_chorale, top_notes, chorale, root, mode, keys = atu.load_chorale_in_cents(version, numpy_dir, werck_top_notes=False)
        logging.info(f'cent value based on top_notes')
        for i in range(min(10, cent_value_chorale.shape[1])):
            logging.info(f'Chord {i}: {cent_value_chorale[:,i]}')
        if include_list is not None:
            cent_value_chorale = cent_value_chorale[:, include_list]
            chorale = chorale[:, include_list]
        cent_value_chorale = np.array([(chord % 12) * 100 for chord in chorale.T]).T.astype(int) # convert to cents
        logging.info(f'{cent_value_chorale.shape = }, {chorale.shape = }, {keys[root]} {mode}')
        logging.info(f'cent value based on 12 TET')
        for i in range(min(10, cent_value_chorale.shape[1])):
            logging.info(f'Chord {i}: {cent_value_chorale[:,i]}')
        logging.info(f'{cent_value_chorale.shape = }, {chorale.shape = }, {keys[root]} {mode}')
        atu.log_top_notes(top_notes)

        if workers == 1 and num_runs == 1:
            # Single worker: run directly, preserving original print behavior
            mismatch_count = 0
            drift_count = 0
            prev_midi_chord = np.zeros(4, dtype=int)
            cent_value_chord_prev = np.zeros(4, dtype=int)
            final_cent_value_chorale = np.zeros_like(chorale.T)
            final_score = np.zeros(chorale.T.shape[0])
            tuned_cent_value_chord = cent_value_chorale.T[0].copy()
            single_worker_early_stop_iters = []
            for inx, initial_midi_chord, initial_cent_value_chord in zip(count(0,1), chorale.T, cent_value_chorale.T):
                chord_num = inx
                if not np.array_equal(prev_midi_chord, initial_midi_chord):
                    initial_pitch_class_chord = initial_midi_chord % 12
                    initial_pitch_class_chord_compressed, pitch_class_inverse = atu.perturb(initial_pitch_class_chord, spread=0) # just to compress, not spread.
                    initial_cent_value_chord_compressed, cent_value_inverse = atu.perturb(initial_cent_value_chord, spread=0)
                    logging.info(f'In test harness. {chord_num = }, {initial_pitch_class_chord = }, {initial_cent_value_chord_compressed = }')
                    # score the uncompressed chord
                    proposed_chord_score = chord_scorer.score_chord(initial_cent_value_chord, tolerance=tolerance)
                    if print_initial:
                        print(f'{inx:>2}: initial chord. pitch class: {atu.format_chord(initial_pitch_class_chord,2)}, note names: {" ".join(keys[note] for note in initial_pitch_class_chord)}, cent_values: {atu.format_chord(initial_cent_value_chord_compressed,4)}, initial score: {proposed_chord_score}')

                    # build the chord using SA-based method
                    tuned_cent_value_chord_compressed, changed, unchanged, es_iters = build_straw_man_chord_sa(
                        initial_cent_value_chord_compressed, cent_value_chord_prev, inx,
                        chord_scorer, low_number_ratios, tonal_diamond,
                        tolerance=tolerance, print_values=print_values, rolls=rolls,
                        sa_iterations=sa_iterations, initial_temperature=initial_temperature, cooling_rate=cooling_rate,
                        rng=rng, ratio_factor=args.ratio_factor, stability_factor=args.stability_factor,
                        spread=args.spread)
                    single_worker_early_stop_iters.extend(es_iters)
                    # decompress it
                    tuned_cent_value_chord = tuned_cent_value_chord_compressed[cent_value_inverse]
                    tuned_pitch_class_chord = atu.pitch_class_from_cents(tuned_cent_value_chord)
                    if print_finals:
                        print(f'{inx:>2}:   final chord. pitch class: {atu.format_chord(tuned_pitch_class_chord,2)}, note names: {" ".join(keys[note] for note in tuned_pitch_class_chord)}, cent values: {atu.format_chord(tuned_cent_value_chord,4)}, final_score: {chord_scorer.score_chord(tuned_cent_value_chord, tolerance=tolerance)}, changed: {changed}, unchanged: {unchanged}')

                    # ensure you didn't change the pitch class
                    if not np.array_equal(initial_pitch_class_chord, tuned_pitch_class_chord):
                        print(f'{inx}: Mismatch. {initial_pitch_class_chord[pitch_class_inverse], tuned_pitch_class_chord[pitch_class_inverse] = }')
                        mismatch_count += 1

                final_cent_value_chorale[inx] = tuned_cent_value_chord.copy()
                final_score[inx] = chord_scorer.score_chord(tuned_cent_value_chord, tolerance=tolerance)
                prev_midi_chord = initial_midi_chord.copy()
                cent_value_chord_prev = tuned_cent_value_chord.copy()
            if mismatch_count > 0: print(f'{mismatch_count = }')
            if drift_count > 0: print(f'{drift_count = }')
            _print_early_stop_histogram(single_worker_early_stop_iters, sa_iterations)

            # Compare with previously saved file
            output_file = os.path.join(numpy_dir, f'{version}-opt.npy')
            final_cent_value_chorale, final_score = load_and_merge_previous(
                output_file, final_cent_value_chorale, final_score, chord_scorer, tolerance,
                chorale=chorale, spread_weight=args.spread_weight)

        else:
            # Multi-worker: run parallel batches, merge per-chord bests
            overall_best_cents = None
            overall_best_scores = None
            overall_early_stop_iters = []
            total_runs = workers * num_runs
            print(f"Running {total_runs} total tuning passes ({workers} workers x {num_runs} batch(es)) for {version}")

            for run_batch in range(num_runs):
                seeds = [rng.integers(0, 2**31) for _ in range(workers)]
                worker_args = [{
                    'seed': int(s),
                    'tonal_diamond': tonal_diamond,
                    'chorale': chorale,
                    'cent_value_chorale': cent_value_chorale,
                    'tolerance': tolerance,
                    'rolls': rolls,
                    'sa_iterations': sa_iterations,
                    'initial_temperature': initial_temperature,
                    'cooling_rate': cooling_rate,
                    'ratio_factor': args.ratio_factor,
                    'stability_factor': args.stability_factor,
                    'spread': args.spread,
                } for s in seeds]

                t0 = time.time()
                with multiprocessing.Pool(workers) as pool:
                    results = pool.map(tune_chorale_worker, worker_args)
                elapsed = time.time() - t0

                batch_best_cents, batch_best_scores, batch_iters = merge_results(results)
                overall_early_stop_iters.extend(batch_iters)
                print(f"  Batch {run_batch+1}/{num_runs}: {workers} workers in {elapsed:.1f}s — "
                      f"merged mean: {np.mean(batch_best_scores):.1f}, max: {np.max(batch_best_scores):.0f}")
                _print_early_stop_histogram(batch_iters, sa_iterations)

                # Merge with running best
                if overall_best_cents is None:
                    overall_best_cents, overall_best_scores = batch_best_cents, batch_best_scores
                else:
                    overall_best_cents, overall_best_scores, _ = merge_results([
                        (overall_best_cents, overall_best_scores, []),
                        (batch_best_cents, batch_best_scores, [])])


            final_cent_value_chorale = overall_best_cents
            final_score = overall_best_scores

            # Compare with previously saved file
            output_file = os.path.join(numpy_dir, f'{version}-opt.npy')
            final_cent_value_chorale, final_score = load_and_merge_previous(
                output_file, final_cent_value_chorale, final_score, chord_scorer, tolerance,
                chorale=chorale, spread_weight=args.spread_weight)

        # Post-hoc continuity enforcement: re-tune chords with large adjacent jumps
        if args.max_gap > 0:
            print(f"Running continuity enforcement (max_gap={args.max_gap}¢, retune_on_gaps={args.retune_on_gaps})...")
            final_cent_value_chorale = enforce_continuity(
                final_cent_value_chorale, chorale, chord_scorer, low_number_ratios,
                tonal_diamond, tolerance, rolls, sa_iterations, initial_temperature,
                cooling_rate, args.ratio_factor, rng,
                max_gap=args.max_gap, retune_on_gaps=args.retune_on_gaps,
                stability_factor=args.stability_factor, spread=args.spread)
            final_score = np.array([chord_scorer.score_chord(final_cent_value_chorale[i], tolerance)
                                    for i in range(final_cent_value_chorale.shape[0])])

        # Post-hoc pitch-class snap: reduce residual spread toward the modal cent value
        if args.snap_tolerance > 0:
            print(f"Running snap_pitch_classes_to_mode (snap_tolerance={args.snap_tolerance}¢)...")
            final_cent_value_chorale = snap_pitch_classes_to_mode(
                final_cent_value_chorale, chorale, args.snap_tolerance)
            final_score = np.array([chord_scorer.score_chord(final_cent_value_chorale[i], tolerance)
                                    for i in range(final_cent_value_chorale.shape[0])])

        print(f'{version = }, chords: {final_cent_value_chorale.shape[0]}, {tolerance = }, {rolls = }, {limit_max = }, {sa_iterations = }, {initial_temperature = }, {cooling_rate = }, {args.ratio_factor = }, {args.stability_factor = }')

        print(
            f"mean: {np.round(np.mean(final_score),1)}, ",
            f"median: {np.median(final_score)}, ",
            f"min: {np.min(final_score)}, ",
            f"max: {np.max(final_score)}, ",
            f"argmax: {np.argmax(final_score)}, ",
            f"deciles: {np.percentile(final_score, np.arange(0, 100, 10))}"
        )
        np.save(os.path.join(numpy_dir, f'{version}-opt'), final_cent_value_chorale.T)

        # Save metadata sidecar
        meta_file = os.path.join(numpy_dir, f'{version}-opt.txt')
        with open(meta_file, 'w') as f:
            f.write(f"version: {version}\n")
            f.write(f"mean: {np.mean(final_score):.1f}\n")
            f.write(f"median: {np.median(final_score):.1f}\n")
            f.write(f"min: {np.min(final_score):.1f}\n")
            f.write(f"max: {np.max(final_score):.0f}\n")
            f.write(f"argmax: {np.argmax(final_score)}\n")
            f.write(f"workers: {workers}\n")
            f.write(f"runs: {num_runs}\n")
            f.write(f"sa_iterations: {sa_iterations}\n")
            f.write(f"rolls: {rolls}\n")
            f.write(f"tolerance: {tolerance}\n")
            f.write(f"limit_max: {limit_max}\n")
            f.write(f"ratio_factor: {args.ratio_factor}\n")
            f.write(f"stability_factor: {args.stability_factor}\n")
            f.write(f"spread: {args.spread}\n")
            f.write(f"spread_weight: {args.spread_weight}\n")
            f.write(f"snap_tolerance: {args.snap_tolerance}\n")
            f.write(f"max_gap: {args.max_gap}\n")
            f.write(f"retune_on_gaps: {args.retune_on_gaps}\n")

if __name__ == '__main__':
    main()
