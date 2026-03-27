#!/usr/bin/env python
# coding: utf-8
"""
Straw Man tuning v4

Combines v3's SA engine (permutations, exponential probability weighting,
normalized temperature, missing-interval fallback, SA restarts with canonical
chord early-stop, parallel restarts) with v2's post-processing pipeline
(continuity enforcement, pitch-class snapping, stability_factor, spread-weighted
merge, multi-worker full-chorale runs, Gaussian spread perturbation, iteration-
based early stopping, metadata sidecar files).

Usage: python Straw_man_tuning_v4.py --chorale_list bwv253 bwv254 ...
"""

import argparse
import logging
import os
import sys
import time
import multiprocessing
import numpy as np
from math import exp
from importlib import reload
from collections import Counter, defaultdict
from itertools import count, permutations
from concurrent.futures import ProcessPoolExecutor, as_completed

base_dir = os.path.dirname(os.path.abspath(__file__))
numpy_dir = os.path.join(base_dir, 'Archive', 'straw-man')

import adaptive_tuning_util as atu

rng = np.random.default_rng()

np.set_printoptions(legacy='1.25')


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


start_logger(os.path.join(base_dir, 'test_v4.log'), level=logging.INFO)
reload(atu)


# ---------------------------------------------------------------------------
# v3's SA engine
# ---------------------------------------------------------------------------

def _choose_interval_choice_probabilistic(indices_size: int, t_norm: float, max_alpha: float = 5.0):
    """Choose an index in [0, indices_size-1] probabilistically.

    - t_norm in [0,1]: 1.0 => uniform selection; 0.0 => strongly prefer 0
    - max_alpha controls how steep the bias becomes at low temperature.
    """
    if indices_size <= 1:
        return 0
    alpha = (1.0 - t_norm) * float(max_alpha)
    weights = np.exp(-alpha * np.arange(indices_size, dtype=float))
    probs = weights / weights.sum()
    return int(rng.choice(np.arange(indices_size), p=probs))


def build_straw_man_chord_v4(cent_value_chord, cent_value_chord_prev, chord_num,
                              chord_scorer, low_number_ratios, tonal_diamond,
                              tolerance=1, print_values=False, rolls=4,
                              sa_iters=20, sa_max_alpha=5.0,
                              ratio_factor=1.0, stability_factor=0.0,
                              spread=7, max_no_improve=None,
                              rng_local=None):
    """Build a tuned chord using v3's SA with v2's spread perturbation and early stopping.

    Returns (best_cent_value_chord, changed_count, unchanged_count, early_stop_iters)
    """
    global rng
    if rng_local is not None:
        rng = rng_local

    logging.info(f'chord#: {chord_num} In build_straw_man_chord_v4. {tolerance = }, {sa_iters = }')
    initial_midi_chord = atu.pitch_class_from_cents(cent_value_chord)

    best_cent_value_chord_so_far = cent_value_chord.copy()
    best_cent_value_score = chord_scorer.score_chord(best_cent_value_chord_so_far, tolerance=tolerance)

    changed_cent_value_count = 0
    unchanged_cent_value_count = 0
    reject_1000_count = 0
    early_stop_count = 0
    early_stop_iters = []

    pitch_class_chord_prev = atu.pitch_class_from_cents(cent_value_chord_prev)

    # Default max_no_improve: fraction of sa_iters
    if max_no_improve is None:
        max_no_improve = max(10, sa_iters // 5)

    for roll_idx in range(rolls):
        rolled_chord = np.roll(cent_value_chord, roll_idx)

        # v2's Gaussian spread perturbation per roll
        if spread > 0:
            noise = np.array([
                int(round(np.clip(rng.normal(0, scale=spread), -49, 49)))
                for _ in range(rolled_chord.shape[0])
            ])
            current_cent_value_chord = (rolled_chord + noise) % 1200
        else:
            current_cent_value_chord = rolled_chord.copy()

        chord_size = current_cent_value_chord.shape[0]
        current_score = chord_scorer.score_chord(current_cent_value_chord, tolerance=tolerance)
        reject_logged = False
        iterations_since_improvement = 0
        prev_roll_best = current_score

        logging.info(f'chord#: {chord_num} roll_amount: {roll_idx}, starting chord: {current_cent_value_chord}, score: {current_score}')

        # v3's normalized temperature SA iterations
        for it in range(max(1, sa_iters)):
            t_norm = 1.0 - (it / float(max(1, sa_iters - 1))) if sa_iters > 1 else 0.0
            temp_scale = 1.0 + 100.0 * t_norm

            candidate = current_cent_value_chord.copy()

            # v3: permutations (all directed interval pairs)
            for interval_inx in permutations(np.arange(chord_size), 2):
                pitch_class_interval = np.array([candidate[interval_inx[0]] % 1200 // 100,
                                                  candidate[interval_inx[1]] % 1200 // 100])
                cent_value_interval = np.array([candidate[interval_inx[0]], candidate[interval_inx[1]]])

                pitch_class_delta, pitch_class_moves, pitch_class_target = atu.pitch_class_interval(pitch_class_interval)
                cent_value_delta, cent_value_moves, cent_value_target = atu.cent_value_interval(cent_value_interval)

                # Hint from previous chord
                cent_value_target_hint = None
                if pitch_class_target in pitch_class_chord_prev:
                    cent_value_target_hint = np.unique(cent_value_chord_prev[np.where(pitch_class_chord_prev == pitch_class_target)])[0]

                # v2's stability_factor in ratio selection
                indices_to_tonal_diamond, _ = low_number_ratios.select_ratios(
                    cent_value_interval, cent_value_target_hint, tolerance,
                    ratio_factor=ratio_factor, stability_factor=stability_factor)

                if indices_to_tonal_diamond.size == 0:
                    continue

                # v3: filter out ratios that create missing intervals or change pitch class
                required_pc = int(initial_midi_chord[interval_inx[1]])
                valid_candidate_indices = []
                for idx in indices_to_tonal_diamond:
                    new_cent = (candidate[interval_inx[0]] + tonal_diamond[int(idx)][1] * cent_value_moves) % 1200
                    if int(atu.pitch_class_from_cents(new_cent)) != required_pc:
                        continue
                    ok = True
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

                # v3: fallback for very bad scores (>=1000)
                if len(valid_candidate_indices) == 0:
                    if current_score >= 1000:
                        valid_candidate_indices = [
                            int(i) for i in indices_to_tonal_diamond
                            if int(atu.pitch_class_from_cents(
                                (candidate[interval_inx[0]] + tonal_diamond[int(i)][1] * cent_value_moves) % 1200)) == required_pc
                        ]
                        if len(valid_candidate_indices) == 0:
                            continue
                    else:
                        continue

                # v3: probabilistic choice biased toward lower indices
                pick_inx = _choose_interval_choice_probabilistic(
                    len(valid_candidate_indices), t_norm=t_norm, max_alpha=sa_max_alpha)
                chosen_ratio_idx = valid_candidate_indices[pick_inx]

                candidate[interval_inx[1]] = (candidate[interval_inx[0]] + tonal_diamond[chosen_ratio_idx][1] * cent_value_moves) % 1200

            # Score completed candidate
            proposed_chord_score = chord_scorer.score_chord(candidate, tolerance=tolerance)

            # v3: guard against >=1000 when current is good
            if proposed_chord_score >= 1000 and current_score < 1000:
                accepted = False
                reject_1000_count += 1
                if not reject_logged:
                    logging.info(f'chord#: {chord_num} SA-it {it}: proposed score {proposed_chord_score} >= 1000 -> reject')
                    reject_logged = True
                improvement = False
            else:
                delta = proposed_chord_score - current_score
                improvement = (delta < 0)
                if improvement:
                    accepted = True
                else:
                    try:
                        accept_prob = np.exp(-delta / temp_scale)
                    except OverflowError:
                        accept_prob = 0.0
                    accepted = rng.random() < accept_prob

            if accepted:
                current_cent_value_chord = candidate.copy()
                current_score = proposed_chord_score
                changed_cent_value_count += 1
                if current_score < best_cent_value_score:
                    best_cent_value_score = current_score
                    best_cent_value_chord_so_far = current_cent_value_chord.copy()
            else:
                unchanged_cent_value_count += 1

            # v2: early stopping per roll
            if current_score < prev_roll_best:
                prev_roll_best = current_score
                iterations_since_improvement = 0
            else:
                iterations_since_improvement += 1
                if iterations_since_improvement >= max_no_improve:
                    early_stop_count += 1
                    early_stop_iters.append(it + 1)
                    logging.debug(f'chord#: {chord_num} roll {roll_idx}: early stop at iter {it + 1}/{sa_iters}')
                    break

    logging.info(
        f'chord#: {chord_num} SA summary: rejects>=1000={reject_1000_count}, '
        f'rejected={unchanged_cent_value_count}, accepted={changed_cent_value_count}, '
        f'best_score={best_cent_value_score}, early_stops={early_stop_count}/{rolls}'
    )

    proposed_cent_value_chord, _ = atu.rearrange_notes(best_cent_value_chord_so_far, initial_midi_chord)
    return proposed_cent_value_chord, changed_cent_value_count, unchanged_cent_value_count, early_stop_iters


# ---------------------------------------------------------------------------
# SA restart worker (v3 parallel restarts using v4 chord builder)
# ---------------------------------------------------------------------------

def _sa_restart_worker(seed_restart, initial_cent_value_chord_compressed,
                       cent_value_chord_prev, chord_num, tolerance,
                       sa_iters, sa_max_alpha, rolls, tonal_diamond,
                       ratio_factor=1.0, stability_factor=0.0,
                       spread=7, max_no_improve=None):
    """Worker for one SA restart in a separate process."""
    local_rng = np.random.default_rng(seed_restart)
    global rng
    rng = local_rng
    try:
        atu.rng = rng
    except Exception:
        pass

    chord_scorer_local = atu.ChordScorer(tonal_diamond)
    low_number_ratios_local = atu.LowNumberRatioIntervals(tonal_diamond)

    tuned, changed, unchanged, es_iters = build_straw_man_chord_v4(
        initial_cent_value_chord_compressed, cent_value_chord_prev, chord_num,
        chord_scorer_local, low_number_ratios_local, tonal_diamond,
        tolerance=tolerance, print_values=False, rolls=rolls,
        sa_iters=sa_iters, sa_max_alpha=sa_max_alpha,
        ratio_factor=ratio_factor, stability_factor=stability_factor,
        spread=spread, max_no_improve=max_no_improve,
        rng_local=local_rng,
    )
    score = chord_scorer_local.score_chord(tuned, tolerance=tolerance)
    canon = tuple(((tuned - tuned.min()) % 1200).astype(int))
    return tuned, changed, unchanged, score, canon, es_iters


# ---------------------------------------------------------------------------
# v2's multi-worker full-chorale tuning
# ---------------------------------------------------------------------------

def tune_chorale_worker(args_dict):
    """Top-level function for multiprocessing. Each worker tunes the full chorale independently."""
    seed = args_dict['seed']
    worker_rng = np.random.default_rng(seed)
    global rng
    rng = worker_rng
    try:
        atu.rng = rng
    except Exception:
        pass

    tonal_diamond = args_dict['tonal_diamond']
    chorale = args_dict['chorale']
    cent_value_chorale = args_dict['cent_value_chorale']
    tolerance = args_dict['tolerance']
    rolls = args_dict['rolls']
    sa_iters = args_dict['sa_iters']
    sa_max_alpha = args_dict['sa_max_alpha']
    ratio_factor = args_dict.get('ratio_factor', 1.0)
    stability_factor = args_dict.get('stability_factor', 0.0)
    spread = args_dict.get('spread', 7)
    max_no_improve = args_dict.get('max_no_improve', None)
    sa_restarts = args_dict.get('sa_restarts', 1)
    restart_repeat_threshold = args_dict.get('restart_repeat_threshold', 3)

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
            initial_cent_value_chord_compressed, cent_value_inverse = atu.perturb(initial_cent_value_chord, spread=0)

            # Run SA restarts for this chord
            best_score = float('inf')
            best_result = None
            best_changed = best_unchanged = 0
            repeat_counts = {}
            early_stop_thresh = max(1, restart_repeat_threshold)

            for restart in range(max(1, sa_restarts)):
                restart_rng = np.random.default_rng(int(worker_rng.integers(0, 2**31)))
                tuned_compressed, changed, unchanged, es_iters = build_straw_man_chord_v4(
                    initial_cent_value_chord_compressed, cent_value_chord_prev, inx,
                    chord_scorer, low_number_ratios, tonal_diamond,
                    tolerance=tolerance, print_values=False, rolls=rolls,
                    sa_iters=sa_iters, sa_max_alpha=sa_max_alpha,
                    ratio_factor=ratio_factor, stability_factor=stability_factor,
                    spread=spread, max_no_improve=max_no_improve,
                    rng_local=restart_rng,
                )
                all_early_stop_iters.extend(es_iters)

                canon = tuple(((tuned_compressed - tuned_compressed.min()) % 1200).astype(int))
                repeat_counts[canon] = repeat_counts.get(canon, 0) + 1

                score_tuned = chord_scorer.score_chord(tuned_compressed, tolerance=tolerance)
                if score_tuned < best_score:
                    best_score = score_tuned
                    best_result = tuned_compressed.copy()
                    best_changed = changed
                    best_unchanged = unchanged

                if repeat_counts[canon] >= early_stop_thresh:
                    break

            tuned_cent_value_chord = best_result[cent_value_inverse]

        final_cent_value_chorale[inx] = tuned_cent_value_chord.copy()
        final_score[inx] = chord_scorer.score_chord(tuned_cent_value_chord, tolerance=tolerance)
        prev_midi_chord = initial_midi_chord.copy()
        cent_value_chord_prev = tuned_cent_value_chord.copy()

    return final_cent_value_chorale, final_score, all_early_stop_iters


def merge_results(all_results):
    """Select the single run with the lowest total score."""
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


# ---------------------------------------------------------------------------
# v2's post-processing: continuity enforcement
# ---------------------------------------------------------------------------

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
                       tonal_diamond, tolerance, rolls, sa_iters, sa_max_alpha,
                       ratio_factor, stability_factor, spread,
                       max_gap=40, retune_on_gaps=3, max_no_improve=None):
    """Post-hoc pass: re-tune chords whose pitch classes jump more than max_gap cents."""
    adjusted = np.array(final_cent_value_chorale, dtype=float, copy=True)
    fixes = 0
    prev_midi_chord = np.zeros(4, dtype=int)

    for chord_idx in range(1, adjusted.shape[0]):
        curr_midi = chorale.T[chord_idx]
        if np.array_equal(curr_midi, prev_midi_chord):
            adjusted[chord_idx] = adjusted[chord_idx - 1]
            prev_midi_chord = curr_midi.copy()
            continue

        prev_chord = adjusted[chord_idx - 1]
        curr_chord = adjusted[chord_idx]
        gap_value, pc, curr_cent, prev_cent, voice_idx = _max_pitch_class_gap(prev_chord, curr_chord)

        if gap_value <= max_gap:
            prev_midi_chord = curr_midi.copy()
            continue

        logging.info(f'chord {chord_idx}: PC {pc} gap {gap_value:.1f}¢ > {max_gap}¢ — retuning')

        retries = 0
        while gap_value > max_gap and retries < retune_on_gaps:
            retries += 1
            fixes += 1
            curr_compressed, inv = atu.perturb(curr_chord, spread=0)
            retuned_compressed, _, _, _ = build_straw_man_chord_v4(
                curr_compressed, prev_chord, chord_idx,
                chord_scorer, low_number_ratios, tonal_diamond,
                tolerance=tolerance, print_values=False, rolls=rolls,
                sa_iters=sa_iters, sa_max_alpha=sa_max_alpha,
                ratio_factor=ratio_factor, stability_factor=stability_factor,
                spread=spread, max_no_improve=max_no_improve)
            retuned = retuned_compressed[inv]
            adjusted[chord_idx] = retuned
            curr_chord = retuned
            gap_value, pc, curr_cent, prev_cent, voice_idx = _max_pitch_class_gap(prev_chord, curr_chord)

        # Fallback 1: uniform shift toward previous pitch class
        if gap_value > max_gap and voice_idx is not None and prev_cent is not None:
            direction = 1 if (curr_cent - prev_cent) >= 0 else -1
            shift_value = (prev_cent + direction * max_gap) - curr_cent
            if abs(shift_value) > 0.1:
                logging.info(f'chord {chord_idx}: uniform shift {shift_value:+.1f}¢')
                adjusted[chord_idx] = (curr_chord + shift_value + 1200) % 1200
                curr_chord = adjusted[chord_idx]
                gap_value, pc, curr_cent, prev_cent, voice_idx = _max_pitch_class_gap(prev_chord, curr_chord)

        # Fallback 2: force the offending voice to the previous cent value
        if gap_value > max_gap and voice_idx is not None and prev_cent is not None:
            logging.warning(f'chord {chord_idx}: forcing voice {voice_idx} (PC {pc}) to prev cent {prev_cent:.1f}¢')
            adjusted[chord_idx, voice_idx] = prev_cent

        prev_midi_chord = curr_midi.copy()

    if fixes > 0:
        logging.info(f'Continuity enforcement: {fixes} SA retune attempt(s)')
    return adjusted


# ---------------------------------------------------------------------------
# v2's post-processing: snap pitch classes to mode
# ---------------------------------------------------------------------------

def snap_pitch_classes_to_mode(final_cent_value_chorale, chorale, snap_tolerance):
    """Snap pitch-class cent values toward the modal cent for that pitch class."""
    if snap_tolerance <= 0:
        return final_cent_value_chorale

    adjusted = np.array(final_cent_value_chorale, dtype=float, copy=True)
    n_chords, n_voices = adjusted.shape

    pc_cents = {pc: [] for pc in range(12)}
    for chord_idx in range(n_chords):
        for v in range(n_voices):
            c = float(adjusted[chord_idx, v]) % 1200
            pc = int(atu.pitch_class_from_cents(c))
            pc_cents[pc].append(c)

    pc_mode = {}
    for pc, cents_list in pc_cents.items():
        if not cents_list:
            continue
        rounded = [round(c / 5) * 5 for c in cents_list]
        counts = {}
        for v in rounded:
            counts[v] = counts.get(v, 0) + 1
        pc_mode[pc] = max(counts, key=counts.__getitem__)

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


# ---------------------------------------------------------------------------
# v2's spread scoring and load/merge
# ---------------------------------------------------------------------------

def compute_spread_score(cent_value_chorale_4n, chorale):
    """Frequency-weighted average pitch-class cent spread across the chorale."""
    pitch_class_counts = Counter((chorale % 12).flatten().tolist())
    total_count = sum(pitch_class_counts.values())

    pc_cents = defaultdict(list)
    for chord_cents in cent_value_chorale_4n.T:
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
    """Keep whichever result has the lower combined metric: mean_score + spread_weight * spread."""
    if not os.path.exists(output_file):
        return best_cents, best_scores

    prev = np.load(output_file)
    prev_chords = (prev.T) % 1200
    prev_scores = np.array([chord_scorer.score_chord(prev_chords[i], tolerance)
                             for i in range(prev_chords.shape[0])])

    if chorale is not None and spread_weight > 0:
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


# ---------------------------------------------------------------------------
# Early-stop histogram (from v2)
# ---------------------------------------------------------------------------

def _print_early_stop_histogram(iters, sa_iters, bucket_size=5):
    """Print a one-line bucketed histogram of early-stop iteration counts."""
    if not iters:
        return
    n_buckets = (sa_iters + bucket_size - 1) // bucket_size
    counts = [0] * n_buckets
    for it in iters:
        b = min((it - 1) // bucket_size, n_buckets - 1)
        counts[b] += 1
    parts = []
    for i, c in enumerate(counts):
        if c:
            lo = i * bucket_size + 1
            hi = min((i + 1) * bucket_size, sa_iters)
            parts.append(f"{lo}-{hi}: {c}")
    print(f"  Early stops ({len(iters)} total): {', '.join(parts)}")


# ---------------------------------------------------------------------------
# CLI argument parser
# ---------------------------------------------------------------------------

def parse_args():
    parser = argparse.ArgumentParser(description='Straw Man tuning v4 — v3 SA engine + v2 post-processing')
    # Tuning system
    parser.add_argument('--limit_max', type=int, default=17)
    parser.add_argument('--max_delta', type=int, default=33)
    parser.add_argument('--tolerance', type=int, default=1)
    # SA core (v3 style)
    parser.add_argument('--rolls', type=int, default=7)
    parser.add_argument('--sa_iters', type=int, default=150, help='SA iterations per chord per roll (default: 150)')
    parser.add_argument('--sa_max_alpha', type=float, default=8.0, help='Max alpha for interval-choice biasing (default: 8.0)')
    parser.add_argument('--max_no_improve', type=int, default=None, help='Early-stop roll after this many iterations without improvement (default: sa_iters/5)')
    # SA restarts (v3)
    parser.add_argument('--sa_restarts', type=int, default=16, help='Number of SA restarts per chord (default: 16)')
    parser.add_argument('--parallel_restarts', type=int, default=12, help='Run SA restarts in parallel (default: 12)')
    parser.add_argument('--restart_repeat_threshold', type=int, default=2, help='Early-stop restarts on canonical chord repetition (default: 2)')
    # Ratio selection (v2 additions)
    parser.add_argument('--ratio_factor', type=float, default=1.25)
    parser.add_argument('--stability_factor', type=float, default=0.5, help='Weight for cent distance from previous chord (default: 0.5)')
    parser.add_argument('--spread', type=int, default=7, help='Gaussian noise std dev per roll start (default: 7)')
    parser.add_argument('--spread_weight', type=float, default=0.5, help='Spread weight in save comparison (default: 0.5)')
    # Post-processing (v2)
    parser.add_argument('--max_gap', type=float, default=40.0, help='Max cent jump for continuity enforcement; 0 disables (default: 40)')
    parser.add_argument('--retune_on_gaps', type=int, default=3, help='SA retune attempts for large gaps (default: 3)')
    parser.add_argument('--snap_tolerance', type=float, default=0.0, help='Snap to modal cent within this distance; 0 disables (default: 0)')
    # Multi-worker (v2)
    parser.add_argument('--workers', type=int, default=1, help='Parallel workers, each tuning the full chorale (default: 1)')
    parser.add_argument('--runs', type=int, default=1, help='Sequential batches of --workers runs (default: 1)')
    # I/O
    parser.add_argument('--numpy_dir', type=str, default=None, help='Directory for numpy files (default: Archive/straw-man)')
    parser.add_argument('--include_list', type=str, default=None, help='Slice of chords, e.g. "8:17"')
    parser.add_argument('--chorale_list', type=str, nargs='+', default=['bwv253'])
    parser.add_argument('--print_values', action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument('--print_finals', action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument('--print_initial', action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument('--seed', type=int, default=None, help='RNG seed for reproducibility')
    return parser.parse_args()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    global numpy_dir, rng
    args = parse_args()
    print(' '.join(f'--{arg} {value}' for arg, value in vars(args).items()))

    reload(atu)
    start_logger(os.path.join(base_dir, 'test_v4.log'), level=logging.INFO)

    if args.numpy_dir is not None:
        numpy_dir = args.numpy_dir if os.path.isabs(args.numpy_dir) else os.path.join(base_dir, args.numpy_dir)
        os.makedirs(numpy_dir, exist_ok=True)
    print(f'{numpy_dir = }')

    if args.seed is not None:
        rng = np.random.default_rng(args.seed)
        try:
            atu.rng = rng
        except Exception:
            pass
        logging.info(f'RNG seeded with {args.seed}')

    limit_max = args.limit_max
    tonal_diamond = atu.build_tonal_diamond(limit_max)[:-1]
    print(f'{limit_max = }, {tonal_diamond.shape = }')
    tolerance = args.tolerance
    rolls = args.rolls
    chord_scorer = atu.ChordScorer(tonal_diamond)
    low_number_ratios = atu.LowNumberRatioIntervals(tonal_diamond)

    if args.include_list is not None:
        parts = args.include_list.split(':')
        include_list = slice(int(parts[0]), int(parts[1]) if len(parts) > 1 else None)
    else:
        include_list = None

    workers = args.workers
    num_runs = args.runs

    for version in args.chorale_list:
        cent_value_chorale, top_notes, chorale, root, mode, keys = atu.load_chorale_in_cents(version, numpy_dir, werck_top_notes=False)
        if include_list is not None:
            cent_value_chorale = cent_value_chorale[:, include_list]
            chorale = chorale[:, include_list]
        cent_value_chorale = np.array([(chord % 12) * 100 for chord in chorale.T]).T.astype(int)

        if workers == 1 and num_runs == 1:
            # Single worker: run directly
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

                    proposed_chord_score = chord_scorer.score_chord(initial_cent_value_chord, tolerance=tolerance)
                    if args.print_initial:
                        print(f'{inx:>2}: initial chord. pitch class: {atu.format_chord(initial_pitch_class_chord,2)}, cent_values: {atu.format_chord(initial_cent_value_chord_compressed,4)}, initial score: {proposed_chord_score}')

                    # SA restarts (v3)
                    best_score = float('inf')
                    best_result = None
                    best_changed = best_unchanged = 0
                    repeat_counts = {}
                    early_stop_thresh = max(1, args.restart_repeat_threshold)

                    if args.parallel_restarts > 1 and args.sa_restarts > 1:
                        max_w = min(args.parallel_restarts, args.sa_restarts, os.cpu_count() or 1)
                        restart_index = 0
                        early_stop = False
                        with ProcessPoolExecutor(max_workers=max_w) as ex:
                            while restart_index < args.sa_restarts and not early_stop:
                                batch = min(max_w, args.sa_restarts - restart_index)
                                futures = {}
                                for r in range(batch):
                                    seed_restart = args.seed + restart_index if args.seed is not None else int(rng.integers(0, 2**31))
                                    fut = ex.submit(
                                        _sa_restart_worker, seed_restart,
                                        initial_cent_value_chord_compressed, cent_value_chord_prev,
                                        inx, tolerance, args.sa_iters, args.sa_max_alpha, rolls,
                                        tonal_diamond, args.ratio_factor, args.stability_factor,
                                        args.spread, args.max_no_improve,
                                    )
                                    futures[fut] = restart_index
                                    restart_index += 1

                                for fut in as_completed(futures):
                                    tuned_compressed, changed, unchanged, score_tuned, canon, es_iters = fut.result()
                                    all_early_stop_iters.extend(es_iters)
                                    repeat_counts[canon] = repeat_counts.get(canon, 0) + 1
                                    if repeat_counts[canon] >= early_stop_thresh:
                                        early_stop = True
                                    if score_tuned < best_score:
                                        best_score = score_tuned
                                        best_result = tuned_compressed.copy()
                                        best_changed = changed
                                        best_unchanged = unchanged
                                if early_stop:
                                    break
                    else:
                        for restart in range(max(1, args.sa_restarts)):
                            if args.seed is not None and args.sa_restarts > 1:
                                restart_rng = np.random.default_rng(args.seed + restart)
                            else:
                                restart_rng = np.random.default_rng(int(rng.integers(0, 2**31)))

                            tuned_compressed, changed, unchanged, es_iters = build_straw_man_chord_v4(
                                initial_cent_value_chord_compressed, cent_value_chord_prev, inx,
                                chord_scorer, low_number_ratios, tonal_diamond,
                                tolerance=tolerance, print_values=args.print_values, rolls=rolls,
                                sa_iters=args.sa_iters, sa_max_alpha=args.sa_max_alpha,
                                ratio_factor=args.ratio_factor, stability_factor=args.stability_factor,
                                spread=args.spread, max_no_improve=args.max_no_improve,
                                rng_local=restart_rng,
                            )
                            all_early_stop_iters.extend(es_iters)

                            canon = tuple(((tuned_compressed - tuned_compressed.min()) % 1200).astype(int))
                            repeat_counts[canon] = repeat_counts.get(canon, 0) + 1

                            score_tuned = chord_scorer.score_chord(tuned_compressed, tolerance=tolerance)
                            if score_tuned < best_score:
                                best_score = score_tuned
                                best_result = tuned_compressed.copy()
                                best_changed = changed
                                best_unchanged = unchanged

                            if repeat_counts[canon] >= early_stop_thresh:
                                break

                    tuned_cent_value_chord_compressed = best_result
                    tuned_cent_value_chord = tuned_cent_value_chord_compressed[cent_value_inverse]
                    tuned_pitch_class_chord = atu.pitch_class_from_cents(tuned_cent_value_chord)

                    if args.print_finals:
                        print(f'{inx:>2}:   final chord. pitch class: {atu.format_chord(tuned_pitch_class_chord,2)}, note names: {" ".join(keys[note] for note in tuned_pitch_class_chord)}, cent values: {atu.format_chord(tuned_cent_value_chord,4)}, final_score: {chord_scorer.score_chord(tuned_cent_value_chord, tolerance=tolerance)}, changed: {best_changed}, unchanged: {best_unchanged}')

                    if not np.array_equal(initial_pitch_class_chord, tuned_pitch_class_chord):
                        print(f'{inx}: Mismatch. {initial_pitch_class_chord[pitch_class_inverse], tuned_pitch_class_chord[pitch_class_inverse] = }')

                final_cent_value_chorale[inx] = tuned_cent_value_chord.copy()
                final_score[inx] = chord_scorer.score_chord(tuned_cent_value_chord, tolerance=tolerance)
                prev_midi_chord = initial_midi_chord.copy()
                cent_value_chord_prev = tuned_cent_value_chord.copy()

            _print_early_stop_histogram(all_early_stop_iters, args.sa_iters)

            # Compare with previous save
            output_file = os.path.join(numpy_dir, f'{version}-opt.npy')
            final_cent_value_chorale, final_score = load_and_merge_previous(
                output_file, final_cent_value_chorale, final_score, chord_scorer, tolerance,
                chorale=chorale, spread_weight=args.spread_weight)

        else:
            # Multi-worker: run parallel batches
            overall_best_cents = None
            overall_best_scores = None
            overall_early_stop_iters = []
            total_runs = workers * num_runs
            print(f"Running {total_runs} total tuning passes ({workers} workers x {num_runs} batch(es)) for {version}")

            for run_batch in range(num_runs):
                seeds = [int(rng.integers(0, 2**31)) for _ in range(workers)]
                worker_args = [{
                    'seed': s,
                    'tonal_diamond': tonal_diamond,
                    'chorale': chorale,
                    'cent_value_chorale': cent_value_chorale,
                    'tolerance': tolerance,
                    'rolls': rolls,
                    'sa_iters': args.sa_iters,
                    'sa_max_alpha': args.sa_max_alpha,
                    'ratio_factor': args.ratio_factor,
                    'stability_factor': args.stability_factor,
                    'spread': args.spread,
                    'max_no_improve': args.max_no_improve,
                    'sa_restarts': args.sa_restarts,
                    'restart_repeat_threshold': args.restart_repeat_threshold,
                } for s in seeds]

                t0 = time.time()
                with multiprocessing.Pool(workers) as pool:
                    results = pool.map(tune_chorale_worker, worker_args)
                elapsed = time.time() - t0

                batch_best_cents, batch_best_scores, batch_iters = merge_results(results)
                overall_early_stop_iters.extend(batch_iters)
                print(f"  Batch {run_batch+1}/{num_runs}: {workers} workers in {elapsed:.1f}s — "
                      f"merged mean: {np.mean(batch_best_scores):.1f}, max: {np.max(batch_best_scores):.0f}")
                _print_early_stop_histogram(batch_iters, args.sa_iters)

                if overall_best_cents is None:
                    overall_best_cents, overall_best_scores = batch_best_cents, batch_best_scores
                else:
                    overall_best_cents, overall_best_scores, _ = merge_results([
                        (overall_best_cents, overall_best_scores, []),
                        (batch_best_cents, batch_best_scores, [])])

            final_cent_value_chorale = overall_best_cents
            final_score = overall_best_scores

            # Compare with previous save
            output_file = os.path.join(numpy_dir, f'{version}-opt.npy')
            final_cent_value_chorale, final_score = load_and_merge_previous(
                output_file, final_cent_value_chorale, final_score, chord_scorer, tolerance,
                chorale=chorale, spread_weight=args.spread_weight)

        # Post-hoc continuity enforcement (v2)
        if args.max_gap > 0:
            print(f"Running continuity enforcement (max_gap={args.max_gap}¢, retune_on_gaps={args.retune_on_gaps})...")
            final_cent_value_chorale = enforce_continuity(
                final_cent_value_chorale, chorale, chord_scorer, low_number_ratios,
                tonal_diamond, tolerance, rolls, args.sa_iters, args.sa_max_alpha,
                args.ratio_factor, args.stability_factor, args.spread,
                max_gap=args.max_gap, retune_on_gaps=args.retune_on_gaps,
                max_no_improve=args.max_no_improve)
            final_score = np.array([chord_scorer.score_chord(final_cent_value_chorale[i], tolerance)
                                    for i in range(final_cent_value_chorale.shape[0])])

        # Post-hoc pitch-class snap (v2)
        if args.snap_tolerance > 0:
            print(f"Running snap_pitch_classes_to_mode (snap_tolerance={args.snap_tolerance}¢)...")
            final_cent_value_chorale = snap_pitch_classes_to_mode(
                final_cent_value_chorale, chorale, args.snap_tolerance)
            final_score = np.array([chord_scorer.score_chord(final_cent_value_chorale[i], tolerance)
                                    for i in range(final_cent_value_chorale.shape[0])])

        print(f'{version = }, chords: {final_cent_value_chorale.shape[0]}, {tolerance = }, {rolls = }, '
              f'{limit_max = }, sa_iters={args.sa_iters}, ratio_factor={args.ratio_factor}, '
              f'stability_factor={args.stability_factor}, spread={args.spread}')
        print(
            f"mean: {np.round(np.mean(final_score),1)}, ",
            f"median: {np.median(final_score)}, ",
            f"min: {np.min(final_score)}, ",
            f"max: {np.max(final_score)}, ",
            f"argmax: {np.argmax(final_score)}, ",
            f"last 2 decile values: {np.percentile(final_score, [80, 90]).astype(int)}"
        )
        np.save(os.path.join(numpy_dir, f'{version}-opt'), final_cent_value_chorale.T)

        # Save metadata sidecar (v2)
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
            f.write(f"sa_iters: {args.sa_iters}\n")
            f.write(f"sa_max_alpha: {args.sa_max_alpha}\n")
            f.write(f"sa_restarts: {args.sa_restarts}\n")
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
