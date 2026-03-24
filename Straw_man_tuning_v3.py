#!/usr/bin/env python
# coding: utf-8
"""
Straw Man tuning (v2)

This module is a variant of `Straw_man_tuning.py` that applies simulated
annealing per chord.  Instead of greedily accepting individual interval
changes, we build a full candidate chord by iterating through the
interval-permutations (choosing interval candidates probabilistically)
and then accept/reject the whole chord using a simulated-annealing
criterion.

Key changes vs original:
- probabilistic `interval_choice` (uniform at high temperature,
  increasingly biased to the lowest index as temperature falls)
- simulated annealing applied per-chord (accept/reject after permutations
  complete for that chord)
- very-bad-score guard: `if proposed_chord_score >= 1000:` (reject)

Usage: largely the same CLI as the original script; new flags:
  --sa_iters    number of SA iterations per chord (default: 20)
  --sa_max_alpha  controls how strongly interval-choice is biased at low T (default: 5.0)

"""

import argparse
import logging
import os
import sys
from importlib import reload
from itertools import count, permutations
from math import exp
from concurrent.futures import ProcessPoolExecutor, as_completed

import numpy as np

import adaptive_tuning_util as atu

# local utilities
base_dir = os.path.dirname(os.path.abspath(__file__))
numpy_dir = os.path.join(base_dir, 'Archive', 'straw-man')

# random generator
rng = np.random.default_rng()


def start_logger(logfile: str, level=logging.INFO):
    root = logging.getLogger()
    root.handlers.clear()
    root.setLevel(level)
    fh = logging.FileHandler(logfile, mode='w')
    fh.setLevel(level)
    formatter = logging.Formatter(fmt='%(asctime)s - %(levelname)s - %(message)s', datefmt='%d')
    fh.setFormatter(formatter)
    root.addHandler(fh)
    root.info(f"Logger started, writing to {logfile}, level={logging.getLevelName(level)}")
    return root


start_logger(os.path.join(base_dir, 'test_v2.log'), level=logging.INFO)
reload(atu)


def _choose_interval_choice_probabilistic(indices_size: int, t_norm: float, max_alpha: float = 5.0):
    """Choose an index in [0, indices_size-1] probabilistically.

    - t_norm in [0,1]: 1.0 => uniform selection; 0.0 => strongly prefer 0
    - max_alpha controls how steep the bias becomes at low temperature.

    Returns an integer index into the `indices_to_tonal_diamond` array.
    """
    if indices_size <= 1:
        return 0
    # alpha scales from 0 (uniform when t_norm==1.0) to max_alpha (when t_norm==0)
    alpha = (1.0 - t_norm) * float(max_alpha)
    weights = np.exp(-alpha * np.arange(indices_size, dtype=float))
    probs = weights / weights.sum()
    return int(rng.choice(np.arange(indices_size), p=probs))


def _sa_restart_worker(seed_restart,
                       initial_cent_value_chord_compressed,
                       cent_value_chord_prev,
                       chord_num,
                       tolerance,
                       sa_iters,
                       sa_max_alpha,
                       rolls,
                       tonal_diamond,
                       ratio_factor=1.0):
    """Worker wrapper executed in a separate process for one SA restart.

    Returns: (tuned_chord_compressed, changed, unchanged, score, canonical)
    """
    # Each worker MUST have its own RNG — forked processes inherit the
    # parent's state, so without reseeding all workers produce identical results.
    local_rng = np.random.default_rng(seed_restart)
    global rng
    rng = local_rng
    try:
        atu.rng = rng
    except Exception:
        pass

    chord_scorer_local = atu.ChordScorer(tonal_diamond)
    low_number_ratios_local = atu.LowNumberRatioIntervals(tonal_diamond)

    tuned, changed, unchanged = build_straw_man_chord_v2(
        initial_cent_value_chord_compressed,
        cent_value_chord_prev,
        chord_num,
        chord_scorer_local,
        low_number_ratios_local,
        tonal_diamond,
        tolerance=tolerance,
        print_values=False,
        rolls=rolls,
        sa_iters=sa_iters,
        sa_max_alpha=sa_max_alpha,
        ratio_factor=ratio_factor,
    )
    score = chord_scorer_local.score_chord(tuned, tolerance=tolerance)
    canon = tuple(((tuned - tuned.min()) % 1200).astype(int))
    return tuned, changed, unchanged, score, canon


def build_straw_man_chord_v2(cent_value_chord,
                             cent_value_chord_prev,
                             chord_num,
                             chord_scorer,
                             low_number_ratios,
                             tonal_diamond,
                             tolerance=1,
                             print_values=False,
                             rolls=4,
                             sa_iters=20,
                             sa_max_alpha=5.0,
                             ratio_factor=1.0):
    """Build a tuned chord using simulated annealing over the whole chord.

    For each roll (like original), we run `sa_iters` simulated-annealing
    iterations.  Each SA iteration constructs a candidate chord by
    stepping through all interval permutations and selecting a ratio for
    each interval probabilistically according to the current (normalized)
    temperature. After finishing the permutations we compute the chord
    score and accept/reject the whole candidate based on the SA rule.

    Returns (best_cent_value_chord, changed_count, unchanged_count)
    """
    logging.info(f'chord#: {chord_num} In build_straw_man_chord_v2. {tolerance = }, {sa_iters = }')
    initial_midi_chord = atu.pitch_class_from_cents(cent_value_chord)

    # bookkeeping for the best found chord across rolls/SA iterations
    best_cent_value_chord_so_far = cent_value_chord.copy()
    best_cent_value_score = chord_scorer.score_chord(best_cent_value_chord_so_far, tolerance=tolerance)

    changed_cent_value_count = 0
    unchanged_cent_value_count = 0
    # count of immediate ">=1000" rejects for this chord (across all rolls)
    reject_1000_count = 0

    pitch_class_chord_prev = atu.pitch_class_from_cents(cent_value_chord_prev)

    for roll_idx, proposed_cent_value_chord in enumerate(np.array([np.roll(cent_value_chord, r) for r in np.arange(rolls)])):
        chord_size = proposed_cent_value_chord.shape[0]
        logging.info(f'chord#: {chord_num} roll_amount: {roll_idx}, starting chord: {proposed_cent_value_chord}')

        # initialize SA current state for this roll
        current_cent_value_chord = proposed_cent_value_chord.copy()
        current_score = chord_scorer.score_chord(current_cent_value_chord, tolerance=tolerance)
        # track whether we've already logged a ">=1000 -> reject" for this chord/roll
        reject_logged = False

        # SA iterations: temperature normalised t_norm in [1 -> 0]
        for it in range(max(1, sa_iters)):
            t_norm = 1.0 - (it / float(max(1, sa_iters - 1))) if sa_iters > 1 else 0.0
            # map t_norm to a temperature scale for SA acceptance (higher => more likely to accept worse)
            temp_scale = 1.0 + 100.0 * t_norm

            candidate = current_cent_value_chord.copy()

            # build a candidate chord by walking all interval permutations once
            for interval_inx in permutations(np.arange(chord_size), 2):
                pitch_class_interval = np.array([candidate[interval_inx[0]] % 1200 // 100, candidate[interval_inx[1]] % 1200 // 100])
                cent_value_interval = np.array([candidate[interval_inx[0]], candidate[interval_inx[1]]])

                pitch_class_delta, pitch_class_moves, pitch_class_target = atu.pitch_class_interval(pitch_class_interval)
                cent_value_delta, cent_value_moves, cent_value_target = atu.cent_value_interval(cent_value_interval)

                # Hint from previous chord (may be None)
                cent_value_target_hint = None
                if pitch_class_target in pitch_class_chord_prev:
                    cent_value_target_hint = np.unique(cent_value_chord_prev[np.where(pitch_class_chord_prev == pitch_class_target)])[0]

                indices_to_tonal_diamond, _ = low_number_ratios.select_ratios(cent_value_interval, cent_value_target_hint, tolerance, ratio_factor=ratio_factor)

                if indices_to_tonal_diamond.size == 0:
                    logging.debug(f'chord#: {chord_num} no ratios found for this interval. skipping. {pitch_class_interval = }, {cent_value_interval = }')
                    continue

                # Filter out any ratio choice that would create a "missing" interval
                # or change the pitch class of the target voice (hard constraint).
                required_pc = int(initial_midi_chord[interval_inx[1]])
                valid_candidate_indices = []
                for idx in indices_to_tonal_diamond:
                    # compute the new cent value for the target note if we used this ratio
                    new_cent = (candidate[interval_inx[0]] + tonal_diamond[int(idx)][1] * cent_value_moves) % 1200
                    # Enforce pitch class preservation (hard constraint — Bach chose them with God on his shoulder)
                    if int(atu.pitch_class_from_cents(new_cent)) != required_pc:
                        continue
                    ok = True
                    # check the new note against every other note in the candidate chord
                    for j in range(chord_size):
                        if j == interval_inx[1]:
                            continue
                        pair = np.array([candidate[j], new_cent])
                        delta, _, _ = atu.cent_value_interval(pair)
                        _, found = chord_scorer.find_best_interval(delta, tolerance)
                        if not found:
                            ok = False
                            break
                    if ok:
                        valid_candidate_indices.append(int(idx))

                if len(valid_candidate_indices) == 0:
                    if current_score >= 1000:
                        # Chord is already bad — fall back to unfiltered missing-interval check,
                        # but still enforce pitch class as a hard constraint.
                        valid_candidate_indices = [
                            int(i) for i in indices_to_tonal_diamond
                            if int(atu.pitch_class_from_cents((candidate[interval_inx[0]] + tonal_diamond[int(i)][1] * cent_value_moves) % 1200)) == required_pc
                        ]
                        if len(valid_candidate_indices) == 0:
                            logging.debug(f'chord#: {chord_num} no ratio preserves pitch class for {interval_inx}; skipping interval update')
                            continue
                        logging.debug(f'chord#: {chord_num} filter fallback: using pitch-class-preserving unfiltered ratios (current_score={current_score})')
                    else:
                        logging.debug(f'chord#: {chord_num} no valid ratio choices that avoid missing intervals for {interval_inx}; skipping interval update')
                        continue

                # probabilistic choice among valid candidates (bias towards lower indices as t_norm->0)
                pick_inx = _choose_interval_choice_probabilistic(len(valid_candidate_indices), t_norm=t_norm, max_alpha=sa_max_alpha)
                chosen_ratio_idx = valid_candidate_indices[pick_inx]

                # apply the chosen ratio into the candidate chord
                candidate[interval_inx[1]] = (candidate[interval_inx[0]] + tonal_diamond[chosen_ratio_idx][1] * cent_value_moves) % 1200

            # score the candidate chord (after all permutations)
            proposed_chord_score = chord_scorer.score_chord(candidate, tolerance=tolerance)

            # Guard: only hard-reject >= 1000 when the current chord is
            # GOOD (< 1000).  When the current chord is already bad, use
            # normal SA acceptance so improving-but-still-bad moves can
            # escape the bad state.
            if proposed_chord_score >= 1000 and current_score < 1000:
                accepted = False
                reject_1000_count += 1
                if not reject_logged:
                    logging.info(f'chord#: {chord_num} SA-it {it}: proposed score {proposed_chord_score} >= 1000 -> reject (protecting good chord)')
                    reject_logged = True
                else:
                    logging.debug(f'chord#: {chord_num} SA-it {it}: proposed score {proposed_chord_score} >= 1000 -> suppressed (already logged)')
                improvement = False
            else:
                delta = proposed_chord_score - current_score
                improvement = (delta < 0)
                if improvement:
                    accepted = True
                else:
                    # acceptance probability for worsening move
                    try:
                        accept_prob = np.exp(-delta / temp_scale)
                    except OverflowError:
                        accept_prob = 0.0
                    accepted = rng.random() < accept_prob

            if accepted:
                # log improvements at INFO, other accepted (worsening) at DEBUG
                if improvement:
                    logging.info(f'chord#: {chord_num} SA-it {it}: accepted improvement (score {proposed_chord_score} -> prev {current_score}) t_norm={t_norm:.3f} temp_scale={temp_scale:.3f}')
                else:
                    logging.debug(f'chord#: {chord_num} SA-it {it}: accepted worsening move (score {proposed_chord_score} -> prev {current_score}) t_norm={t_norm:.3f} temp_scale={temp_scale:.3f}')
                current_cent_value_chord = candidate.copy()
                current_score = proposed_chord_score
                changed_cent_value_count += 1
                # track global best for this roll
                if current_score < best_cent_value_score:
                    best_cent_value_score = current_score
                    best_cent_value_chord_so_far = current_cent_value_chord.copy()
            else:
                unchanged_cent_value_count += 1

            if print_values:
                # only log SA-it lines at INFO when they represent an improvement; otherwise DEBUG
                if proposed_chord_score < current_score:
                    logging.info(f'SA-it {it:>2}, t_norm={t_norm:.3f}, temp_scale={temp_scale:.2f}, proposed_score={proposed_chord_score:>6.1f}, current_score={current_score:>6.1f}, accepted={accepted}')
                else:
                    logging.debug(f'SA-it {it:>2}, t_norm={t_norm:.3f}, temp_scale={temp_scale:.2f}, proposed_score={proposed_chord_score:>6.1f}, current_score={current_score:>6.1f}, accepted={accepted}')

        # end of SA iterations for this roll
    # end of roll loop

    # log a concise SA summary for this chord
    logging.info(
        f'chord#: {chord_num} SA summary: rejects>=1000={reject_1000_count}, rejected_proposals={unchanged_cent_value_count}, accepted_changes={changed_cent_value_count}, best_score={best_cent_value_score}'
    )

    proposed_cent_value_chord, _ = atu.rearrange_notes(best_cent_value_chord_so_far, initial_midi_chord)
    return proposed_cent_value_chord, changed_cent_value_count, unchanged_cent_value_count


def parse_args():
    parser = argparse.ArgumentParser(description='Straw Man tuning v2 (simulated annealing per chord)')
    parser.add_argument('--limit_max', type=int, default=23, help='Maximum limit for tonal diamond (default: 23)')
    parser.add_argument('--max_delta', type=int, default=35, help='Maximum delta (default: 35)')
    parser.add_argument('--tolerance', type=int, default=1, help='Tolerance for chord scoring (default: 1)')
    parser.add_argument('--rolls', type=int, default=1, help='Number of rolls for chord permutations (default: 1)')
    parser.add_argument('--include_list', type=str, default=None, help='Slice of chords to include, e.g. "8:17"')
    parser.add_argument('--chorale_list', type=str, nargs='+', default=['bwv253'], help='List of chorale versions to process')
    parser.add_argument('--print_values', action=argparse.BooleanOptionalAction, default=True, help='Print interval / SA details')
    parser.add_argument('--print_finals', action=argparse.BooleanOptionalAction, default=True, help='Print final chord results')
    parser.add_argument('--print_initial', action=argparse.BooleanOptionalAction, default=True, help='Print initial chord info')
    # SA-specific
    parser.add_argument('--sa_iters', type=int, default=20, help='Simulated annealing iterations per chord (default: 20)')
    parser.add_argument('--sa_max_alpha', type=float, default=5.0, help='Max alpha for interval-choice biasing (default: 5.0)')
    parser.add_argument('--sa_restarts', type=int, default=1, help='Number of SA restarts per chord; best result is kept (default: 1)')
    parser.add_argument('--parallel_restarts', type=int, default=1, help='Run SA restarts in parallel across this many workers (default: 1)')
    parser.add_argument('--restart_repeat_threshold', type=int, default=3, help='Early-stop if the same (transposition-invariant) chord appears this many times across restarts (default: 3)')
    parser.add_argument('--seed', type=int, default=None, help='Optional RNG seed for reproducible runs')
    parser.add_argument('--ratio_factor', type=float, default=1.0, help='Consonance/stability trade-off: high favours low-limit ratios, low favours staying near the current interval; balance point ~1.7 (default: 1.0)')
    parser.add_argument('--numpy_dir', type=str, default=None, help='Directory for loading/saving numpy files (default: Archive/straw-man)')
    return parser.parse_args()


def main():
    global numpy_dir
    args = parse_args()
    print(' '.join(f'--{arg} {value}' for arg, value in vars(args).items()))

    if args.numpy_dir is not None:
        numpy_dir = args.numpy_dir
        os.makedirs(numpy_dir, exist_ok=True)

    reload(atu)
    start_logger(os.path.join(base_dir, 'test_v2.log'), level=logging.INFO)

    # set RNG seed for reproducibility (affects this module and adaptive_tuning_util)
    if args.seed is not None:
        global rng
        rng = np.random.default_rng(args.seed)
        try:
            atu.rng = rng
        except Exception:
            pass
        logging.info(f'RNG seeded with {args.seed}')

    limit_max = args.limit_max
    tonal_diamond = atu.build_tonal_diamond(limit_max)[:-1]
    tolerance = args.tolerance
    rolls = args.rolls
    chord_scorer = atu.ChordScorer(tonal_diamond)
    low_number_ratios = atu.LowNumberRatioIntervals(tonal_diamond)

    if args.include_list is not None:
        parts = args.include_list.split(':')
        include_list = slice(int(parts[0]), int(parts[1]) if len(parts) > 1 else None)
    else:
        include_list = None

    chorale_list = args.chorale_list
    for version in chorale_list:
        cent_value_chorale, top_notes, chorale, root, mode, keys = atu.load_chorale_in_cents(version, numpy_dir, werck_top_notes=False)
        if include_list is not None:
            cent_value_chorale = cent_value_chorale[:, include_list]
            chorale = chorale[:, include_list]
        cent_value_chorale = np.array([(chord % 12) * 100 for chord in chorale.T]).T.astype(int)

        prev_midi_chord = np.zeros(4, dtype=int)
        cent_value_chord_prev = np.zeros(4, dtype=int)
        final_cent_value_chorale = np.zeros_like(chorale.T)
        final_score = np.zeros(chorale.T.shape[0])

        for inx, initial_midi_chord, initial_cent_value_chord in zip(count(0, 1), chorale.T, cent_value_chorale.T):
            chord_num = inx
            if not np.array_equal(prev_midi_chord, initial_midi_chord):
                initial_pitch_class_chord = initial_midi_chord % 12
                initial_pitch_class_chord_compressed, pitch_class_inverse = atu.perturb(initial_pitch_class_chord, spread=0)
                initial_cent_value_chord_compressed, cent_value_inverse = atu.perturb(initial_cent_value_chord, spread=0)

                proposed_chord_score = chord_scorer.score_chord(initial_cent_value_chord, tolerance=tolerance)
                if args.print_initial:
                    logging.info(f'{inx:>2}: initial chord. pitch class: {atu.format_chord(initial_pitch_class_chord,2)}, cent_values: {atu.format_chord(initial_cent_value_chord_compressed,4)}, initial score: {proposed_chord_score}')

                # Optionally run multiple SA restarts and keep the best result (reduces variance)
                best_score = float('inf')
                best_result = None
                best_changed = best_unchanged = 0

                # map of canonical (transposition-invariant) chord -> count
                repeat_counts = {}
                early_stop_thresh = max(1, args.restart_repeat_threshold)

                # If parallel restarts requested, run worker processes in batches.
                if args.parallel_restarts > 1 and args.sa_restarts > 1:
                    max_workers = min(args.parallel_restarts, args.sa_restarts, os.cpu_count() or 1)
                    logging.info(f'chord#: {inx} running restarts in parallel: workers={max_workers}, total_restarts={args.sa_restarts}')
                    restart_index = 0
                    early_stop = False
                    with ProcessPoolExecutor(max_workers=max_workers) as ex:
                        while restart_index < args.sa_restarts and not early_stop:
                            batch = min(max_workers, args.sa_restarts - restart_index)
                            futures = {}
                            for r in range(batch):
                                # Always provide a unique seed so forked workers
                                # don't all share the same RNG state.
                                if args.seed is not None:
                                    seed_restart = args.seed + restart_index
                                else:
                                    seed_restart = int(rng.integers(0, 2**31))
                                fut = ex.submit(
                                    _sa_restart_worker,
                                    seed_restart,
                                    initial_cent_value_chord_compressed,
                                    cent_value_chord_prev,
                                    inx,
                                    tolerance,
                                    args.sa_iters,
                                    args.sa_max_alpha,
                                    rolls,
                                    tonal_diamond,
                                    args.ratio_factor,
                                )
                                futures[fut] = restart_index
                                restart_index += 1

                            for fut in as_completed(futures):
                                tuned_cent_value_chord_compressed, changed, unchanged, score_tuned, canon = fut.result()
                                repeat_counts[canon] = repeat_counts.get(canon, 0) + 1
                                r_idx = futures[fut]
                                logging.debug(f'chord#: {inx} restart={r_idx} score={score_tuned} canon_count={repeat_counts[canon]}')
                                if repeat_counts[canon] >= early_stop_thresh:
                                    logging.info(f'chord#: {inx} early-stop restarts after seeing same-transposed chord {repeat_counts[canon]} times (restart={r_idx})')
                                    early_stop = True
                                if score_tuned < best_score:
                                    best_score = score_tuned
                                    best_result = tuned_cent_value_chord_compressed.copy()
                                    best_changed = changed
                                    best_unchanged = unchanged
                            if early_stop:
                                break
                else:
                    for restart in range(max(1, args.sa_restarts)):
                        # if a seed is provided, derive per-restart generator for reproducibility
                        if args.seed is not None and args.sa_restarts > 1:
                            # reseed shared RNG deterministically per restart
                            seed_restart = args.seed + restart
                            rng = np.random.default_rng(seed_restart)
                            try:
                                atu.rng = rng
                            except Exception:
                                pass

                        tuned_cent_value_chord_compressed, changed, unchanged = build_straw_man_chord_v2(
                            initial_cent_value_chord_compressed, cent_value_chord_prev, inx,
                            chord_scorer, low_number_ratios, tonal_diamond,
                            tolerance=tolerance, print_values=args.print_values, rolls=rolls,
                            sa_iters=args.sa_iters, sa_max_alpha=args.sa_max_alpha,
                            ratio_factor=args.ratio_factor,
                        )

                        # canonicalize by transposition (subtract min and mod 1200)
                        canon = tuple(((tuned_cent_value_chord_compressed - tuned_cent_value_chord_compressed.min()) % 1200).astype(int))
                        repeat_counts[canon] = repeat_counts.get(canon, 0) + 1
                        if repeat_counts[canon] >= early_stop_thresh:
                            logging.info(f'chord#: {inx} early-stop restarts after seeing same-transposed chord {repeat_counts[canon]} times (restart={restart})')
                            # keep this tuned result (we still evaluate below)

                        score_tuned = chord_scorer.score_chord(tuned_cent_value_chord_compressed, tolerance=tolerance)
                        logging.debug(f'restart={restart} score={score_tuned} canon_count={repeat_counts[canon]}')

                        if score_tuned < best_score:
                            best_score = score_tuned
                            best_result = tuned_cent_value_chord_compressed.copy()
                            best_changed = changed
                            best_unchanged = unchanged

                        # early-stop outer restart loop when any canonical chord has repeated enough
                        if repeat_counts[canon] >= early_stop_thresh:
                            break

                tuned_cent_value_chord_compressed = best_result
                changed, unchanged = best_changed, best_unchanged

                tuned_cent_value_chord = tuned_cent_value_chord_compressed[cent_value_inverse]
                tuned_pitch_class_chord = atu.pitch_class_from_cents(tuned_cent_value_chord)

                if args.print_finals:
                    logging.info(f'{inx:>2}:   final chord. pitch class: {atu.format_chord(tuned_pitch_class_chord,2)}, note names: {" ".join(keys[note] for note in tuned_pitch_class_chord)}, cent values: {atu.format_chord(tuned_cent_value_chord,4)}, final_score: {chord_scorer.score_chord(tuned_cent_value_chord, tolerance=tolerance)}, changed: {changed}, unchanged: {unchanged}')

                if not np.array_equal(initial_pitch_class_chord, tuned_pitch_class_chord):
                    logging.info(f'{inx}: Mismatch. {initial_pitch_class_chord[pitch_class_inverse], tuned_pitch_class_chord[pitch_class_inverse] = }')

            final_cent_value_chorale[inx] = tuned_cent_value_chord.copy()
            final_score[inx] = chord_scorer.score_chord(tuned_cent_value_chord, tolerance=tolerance)
            prev_midi_chord = initial_midi_chord.copy()
            cent_value_chord_prev = tuned_cent_value_chord.copy()

        print(f'{version = }, chords: {final_cent_value_chorale.shape[0]}, {tolerance = }, {rolls = }, {limit_max = }')
        print(
            f"mean: {np.round(np.mean(final_score),1)}, ",
            f"median: {np.median(final_score)}, ",
            f"min: {np.min(final_score)}, ",
            f"max: {np.max(final_score)}, ",
            f"argmax: {np.argmax(final_score)}, ",
            f"deciles: {np.percentile(final_score, np.arange(0, 100, 10))}"
        )

        # --- Compare with previously saved result and keep the per-chord best ---
        save_path = os.path.join(numpy_dir, f'{version}-opt.npy')
        if os.path.exists(save_path):
            prev_chorale = np.load(save_path)  # shape (4, num_chords) as saved
            if prev_chorale.shape[1] == final_cent_value_chorale.shape[0]:
                prev_chorale_T = prev_chorale.T  # (num_chords, 4) to match final_cent_value_chorale
                prev_scores = np.array([
                    chord_scorer.score_chord(prev_chorale_T[i], tolerance=tolerance)
                    for i in range(prev_chorale_T.shape[0])
                ])
                # Per-chord: keep whichever version scored lower
                improved = 0
                kept_prev = 0
                for i in range(len(final_score)):
                    if prev_scores[i] < final_score[i]:
                        # Previous was better — keep it
                        final_cent_value_chorale[i] = prev_chorale_T[i]
                        final_score[i] = prev_scores[i]
                        kept_prev += 1
                    elif final_score[i] < prev_scores[i]:
                        improved += 1
                    # else: tie — keep new (no-op)

                print(f"  Compared with previous save: {improved} chords improved, "
                      f"{kept_prev} kept from previous, "
                      f"{len(final_score) - improved - kept_prev} tied")
                print(
                    f"  merged: mean: {np.round(np.mean(final_score),1)}, ",
                    f"median: {np.median(final_score)}, ",
                    f"min: {np.min(final_score)}, ",
                    f"max: {np.max(final_score)}, ",
                    f"argmax: {np.argmax(final_score)}"
                )
            else:
                logging.warning(f"Previous save shape mismatch ({prev_chorale.shape[1]} vs "
                                f"{final_cent_value_chorale.shape[0]} chords) — overwriting")
        else:
            print(f"  No previous save found — saving new result")

        np.save(os.path.join(numpy_dir, f'{version}-opt'), final_cent_value_chorale.T)


if __name__ == '__main__':
    main()
