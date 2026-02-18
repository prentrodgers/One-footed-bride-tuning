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
        logging.info(f'chord#: {chord_num} found {pitch_class_target in pitch_class_chord_prev = }, {cent_value_target = }, {pitch_class_chord_prev = }')
    else:
        logging.info(f'chord#: {chord_num} not found {pitch_class_target in pitch_class_chord_prev = }, {pitch_class_chord_prev = }')
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
                              rng=None):
    if rng is None:
        rng = np.random.default_rng()
    logging.info(f'chord#: {chord_num} In build_straw_man_chord_sa. {tolerance = }, {sa_iterations = }, {initial_temperature = }, {cooling_rate = }')
    initial_midi_chord = atu.pitch_class_from_cents(cent_value_chord)
    best_cent_value_chord_so_far = cent_value_chord.copy()
    best_score = 9999
    pitch_class_chord_prev = atu.pitch_class_from_cents(cent_value_chord_prev)
    changed_cent_value_count = 0
    unchanged_cent_value_count = 0

    for roll_amount in range(rolls):
        rolled_chord = np.roll(cent_value_chord, roll_amount)
        chord_size = rolled_chord.shape[0]
        pitch_class_chord = atu.pitch_class_from_cents(rolled_chord)
        temperature = initial_temperature
        current_solution = rolled_chord.copy()
        current_score = chord_scorer.score_chord(current_solution, tolerance=tolerance)
        logging.info(f'chord#: {chord_num} roll_amount: {roll_amount}, initial score: {current_score}')

        for sa_iter in range(sa_iterations):
            proposed = current_solution.copy()

            for interval_inx in permutations(np.arange(chord_size), 2):
                pitch_class_interval = np.array([pitch_class_chord[interval_inx[0]], pitch_class_chord[interval_inx[1]]])
                cent_value_interval = np.array([proposed[interval_inx[0]], proposed[interval_inx[1]]])
                pitch_class_delta, pitch_class_moves, pitch_class_target = atu.pitch_class_interval(pitch_class_interval)
                cent_value_delta, cent_value_moves, cent_value_target = atu.cent_value_interval(cent_value_interval)

                cent_value_target = find_cent_value_prev_target(pitch_class_target, pitch_class_chord_prev, cent_value_chord_prev, chord_num)
                indices_to_tonal_diamond, _ = low_number_ratios.select_ratios(cent_value_interval, cent_value_target, tolerance)

                if indices_to_tonal_diamond.size == 0:
                    continue

                num_available = min(len(indices_to_tonal_diamond), 15)

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

                # Apply the interval change
                proposed[interval_inx[1]] = (proposed[interval_inx[0]] + tonal_diamond[indices_to_tonal_diamond[interval_choice]][1] * cent_value_moves) % 1200

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
                    logging.info(f'chord#: {chord_num} new best: roll={roll_amount}, sa_iter={sa_iter}, score={best_score}')
            else:
                unchanged_cent_value_count += 1

            temperature *= cooling_rate

        if print_values:
            print(f'  roll {roll_amount}: best_score so far = {best_score}')

    proposed_cent_value_chord, _ = atu.rearrange_notes(best_cent_value_chord_so_far, initial_midi_chord)
    return proposed_cent_value_chord, changed_cent_value_count, unchanged_cent_value_count


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

    chord_scorer = atu.ChordScorer(tonal_diamond)
    low_number_ratios = atu.LowNumberRatioIntervals(tonal_diamond)

    prev_midi_chord = np.zeros(4, dtype=int)
    cent_value_chord_prev = np.zeros(4, dtype=int)
    final_cent_value_chorale = np.zeros_like(chorale.T)
    final_score = np.zeros(chorale.T.shape[0])

    tuned_cent_value_chord = cent_value_chorale.T[0].copy()

    for inx, initial_midi_chord, initial_cent_value_chord in zip(count(0, 1), chorale.T, cent_value_chorale.T):
        if not np.array_equal(prev_midi_chord, initial_midi_chord):
            initial_pitch_class_chord = initial_midi_chord % 12
            initial_pitch_class_chord_compressed, pitch_class_inverse = atu.perturb(initial_pitch_class_chord, spread=0)
            initial_cent_value_chord_compressed, cent_value_inverse = atu.perturb(initial_cent_value_chord, spread=0)

            tuned_cent_value_chord_compressed, changed, unchanged = build_straw_man_chord_sa(
                initial_cent_value_chord_compressed, cent_value_chord_prev, inx,
                chord_scorer, low_number_ratios, tonal_diamond,
                tolerance=tolerance, print_values=False, rolls=rolls,
                sa_iterations=sa_iterations, initial_temperature=initial_temperature, cooling_rate=cooling_rate,
                rng=worker_rng)
            tuned_cent_value_chord = tuned_cent_value_chord_compressed[cent_value_inverse]

        final_cent_value_chorale[inx] = tuned_cent_value_chord.copy()
        final_score[inx] = chord_scorer.score_chord(tuned_cent_value_chord, tolerance=tolerance)
        prev_midi_chord = initial_midi_chord.copy()
        cent_value_chord_prev = tuned_cent_value_chord.copy()

    return final_cent_value_chorale, final_score


def merge_results(all_results):
    """Per-chord best across all workers."""
    best_cents = all_results[0][0].copy()
    best_scores = all_results[0][1].copy()
    for cents, scores in all_results[1:]:
        improved = scores < best_scores
        best_cents[improved] = cents[improved]
        best_scores[improved] = scores[improved]
    return best_cents, best_scores


def load_and_merge_previous(output_file, best_cents, best_scores, chord_scorer, tolerance):
    """Compare with previously saved results, keep per-chord best."""
    if os.path.exists(output_file):
        prev = np.load(output_file)  # shape (4, N)
        prev_improved = 0
        for i in range(prev.shape[1]):
            prev_score = chord_scorer.score_chord(prev[:, i] % 1200, tolerance)
            if prev_score < best_scores[i]:
                best_cents[i] = prev[:, i] % 1200
                best_scores[i] = prev_score
                prev_improved += 1
        if prev_improved > 0:
            print(f"  Kept {prev_improved} chord(s) from previous best")
    return best_cents, best_scores


def parse_args():
    parser = argparse.ArgumentParser(description='Straw Man tuning v2 — SA-based chord tuning using lowest number ratios')
    parser.add_argument('--limit_max', type=int, default=23, help='Maximum limit for tonal diamond (default: 23)')
    parser.add_argument('--max_delta', type=int, default=35, help='Maximum delta (default: 35)')
    parser.add_argument('--tolerance', type=int, default=1, help='Tolerance for chord scoring (default: 1)')
    parser.add_argument('--rolls', type=int, default=1, help='Number of rolls for chord permutations (default: 1)')
    parser.add_argument('--sa_iterations', type=int, default=100, help='Number of SA iterations per chord per roll (default: 100)')
    parser.add_argument('--initial_temperature', type=float, default=2.0, help='Starting SA temperature (default: 2.0)')
    parser.add_argument('--cooling_rate', type=float, default=0.995, help='Temperature multiplier per iteration (default: 0.995)')
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
    return parser.parse_args()

def main():
    args = parse_args()
    print(' '.join(f'--{arg} {value}' for arg, value in vars(args).items()))

    reload(atu)
    start_logger(os.path.join(base_dir, 'test.log'), level = logging.INFO)
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
                    tuned_cent_value_chord_compressed, changed, unchanged = build_straw_man_chord_sa(
                        initial_cent_value_chord_compressed, cent_value_chord_prev, inx,
                        chord_scorer, low_number_ratios, tonal_diamond,
                        tolerance=tolerance, print_values=print_values, rolls=rolls,
                        sa_iterations=sa_iterations, initial_temperature=initial_temperature, cooling_rate=cooling_rate,
                        rng=rng)
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

            # Compare with previously saved file
            output_file = os.path.join(numpy_dir, f'{version}-opt.npy')
            final_cent_value_chorale, final_score = load_and_merge_previous(
                output_file, final_cent_value_chorale, final_score, chord_scorer, tolerance)

        else:
            # Multi-worker: run parallel batches, merge per-chord bests
            overall_best_cents = None
            overall_best_scores = None
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
                } for s in seeds]

                t0 = time.time()
                with multiprocessing.Pool(workers) as pool:
                    results = pool.map(tune_chorale_worker, worker_args)
                elapsed = time.time() - t0

                batch_best_cents, batch_best_scores = merge_results(results)
                print(f"  Batch {run_batch+1}/{num_runs}: {workers} workers in {elapsed:.1f}s — "
                      f"merged mean: {np.mean(batch_best_scores):.1f}, max: {np.max(batch_best_scores):.0f}")

                # Merge with running best
                if overall_best_cents is None:
                    overall_best_cents, overall_best_scores = batch_best_cents, batch_best_scores
                else:
                    overall_best_cents, overall_best_scores = merge_results([
                        (overall_best_cents, overall_best_scores),
                        (batch_best_cents, batch_best_scores)])


            final_cent_value_chorale = overall_best_cents
            final_score = overall_best_scores

            # Compare with previously saved file
            output_file = os.path.join(numpy_dir, f'{version}-opt.npy')
            final_cent_value_chorale, final_score = load_and_merge_previous(
                output_file, final_cent_value_chorale, final_score, chord_scorer, tolerance)

        print(f'{version = }, chords: {final_cent_value_chorale.shape[0]}, {tolerance = }, {rolls = }, {limit_max = }, {sa_iterations = }, {initial_temperature = }, {cooling_rate = }')

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

if __name__ == '__main__':
    main()
