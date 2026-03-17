#!/usr/bin/env python3
"""
optimize_chords_sa_v2.py

Simulated-annealing chord tuning (cleaned single-copy version).
Defaults: reduced logging (INFO), rotating log file, --tolerance default 1.
"""

import logging
from logging.handlers import RotatingFileHandler
import os
import sys
import time
import numpy as np
from math import exp
from itertools import permutations, combinations
import argparse
from pathlib import Path
from collections import defaultdict


def setup_paths(tolerance=1):
    """
    Configure Python path and data directories.
    
    Finds the project root intelligently:
    - If current directory has Archive/, use it
    - If script directory has Archive/, use it
    - Otherwise use script directory's parent
    
    Data goes to: {project_root}/Archive/opt/tolerance-{N}/
    Logs go to: {project_root} or /tmp if in Kubernetes
    
    Args:
        tolerance: tolerance level (1-4), determines subdirectory name
    
    Returns:
        dict with keys: script_dir, project_dir, numpy_dir, log_dir
    """
    if not (1 <= tolerance <= 4):
        raise ValueError(f"tolerance must be 1-4, got {tolerance}")
    
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    cwd = os.getcwd()
    
    # Determine project root intelligently
    project_dir = None
    
    # Check current directory first (most specific)
    if os.path.isdir(os.path.join(cwd, 'Archive')):
        project_dir = cwd
    # Check script directory next
    elif os.path.isdir(os.path.join(script_dir, 'Archive')):
        project_dir = script_dir
    # Check script directory's parent
    elif os.path.isdir(os.path.join(os.path.dirname(script_dir), 'Archive')):
        project_dir = os.path.dirname(script_dir)
    # Final fallback: use script directory
    else:
        project_dir = script_dir
    
    # Data directory: Archive/opt/tolerance-{tolerance}/
    numpy_dir = os.path.join(project_dir, 'Archive', 'opt', f'tolerance-{tolerance}')
    
    # Use /tmp for logs when running in Kubernetes container, otherwise use project directory
    log_dir = '/tmp' if os.getenv('KUBERNETES_SERVICE_HOST') else project_dir
    
    # Add project directory to path so we can import local modules
    if project_dir not in sys.path:
        sys.path.insert(0, project_dir)
    
    return {
        'script_dir': script_dir,
        'project_dir': project_dir,
        'numpy_dir': numpy_dir,
        'log_dir': log_dir
    }


def setup_logger(log_file, verbose=False):
    """Setup logging configuration."""
    root = logging.getLogger()
    root.handlers.clear()

    # Default to INFO; enable DEBUG only when verbose requested
    root.setLevel(logging.DEBUG if verbose else logging.INFO)

    # File handler: rotating handler; log INFO by default, DEBUG when verbose
    file_level = logging.DEBUG if verbose else logging.INFO
    fh = RotatingFileHandler(log_file, mode='w', maxBytes=256 * 1024, backupCount=1)
    fh.setLevel(file_level)

    formatter = logging.Formatter(
        fmt='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    fh.setFormatter(formatter)
    root.addHandler(fh)

    # Do NOT redirect stdout/stderr — keep print() output going to the console.
    try:
        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__
    except Exception:
        pass


def _choose_probabilities(indices, r=0.3):
    """
    Generate weighted probabilities favoring earlier (better) ratios.
    """
    r = np.clip(r, 0.00001, 0.99999)
    probs = np.logspace(0.01, 10, num=indices, base=r)
    return probs / sum(probs)


def find_cent_value_prev_target(pitch_class_target, pitch_class_chord_prev, 
                                 cent_value_chord_prev, chord_num):
    """Find cent values in previous chord for target pitch class."""
    mask = pitch_class_chord_prev == pitch_class_target
    if np.any(mask):
        cent_value_targets = np.unique(cent_value_chord_prev[mask])
        logging.debug(
            f'chord#: {chord_num} found previous cents for pitch class {pitch_class_target}: '
            f'{cent_value_targets.tolist()}'
        )
        return cent_value_targets.tolist()
    logging.debug(
        f'chord#: {chord_num} no previous cents for pitch class {pitch_class_target}'
    )
    return []


def build_straw_man_chord_simulated_annealing(cent_value_chord, cent_value_chord_prev, chord_num,
                                              tolerance=1, chord_scorer=None,
                                              low_number_ratios=None, tonal_diamond=None,
                                              initial_temperature=2.5, cooling_rate=0.999,
                                              max_iterations=1000, min_repeats=5,
                                              elbow_percent=0.5, r_value=0.3, spread=7,
                                              roll_num=None, time_limit=0, max_no_improve=None,
                                              max_delta=33, ratio_factor=1.0, stability_factor=0.0,
                                              trace=None):
    """
    Build a straw man chord using simulated annealing with temperature-weighted choices.
    """
    logging.info(f'chord#{chord_num} Starting SA optimization (tolerance={tolerance})')
    
    import adaptive_tuning_util as atu
    
    rng = np.random.default_rng()
    
    # Perturb incoming chord for randomization
    cent_value_chord_perturbed, inverse = atu.perturb(cent_value_chord, spread=spread)
    chord_size = cent_value_chord_perturbed.shape[0]
    
    pitch_class_chord_current = atu.pitch_class_from_cents(cent_value_chord)
    pitch_class_chord_prev = atu.pitch_class_from_cents(cent_value_chord_prev)
    pitch_class_chord = atu.pitch_class_from_cents(cent_value_chord_perturbed)
    
    current_solution = cent_value_chord_perturbed.copy()
    current_score = chord_scorer.score_chord(current_solution[inverse], tolerance=tolerance)
    
    best_cent_value_chord_so_far = current_solution.copy()
    best_score = current_score
    
    # Early stopping tracking: count iterations since last improvement
    iterations_since_improvement = 0
    prev_best_score = best_score

    # Determine default for max_no_improve if not provided: use a fraction of max_iterations
    if max_no_improve is None:
        try:
            max_no_improve = max(10, int(max_iterations / 10))
        except Exception:
            max_no_improve = 50
    
    start_time = time.time()
    temperature = initial_temperature
    iteration = 0
    
    while temperature > 0.05 and iteration < max_iterations:
        if time_limit and (time.time() - start_time) > time_limit:
            rn = f' roll#{roll_num}' if roll_num is not None else ''
            logging.info(f'chord#{chord_num}{rn} Early stop: time limit {time_limit}s exceeded')
            break
        new_solution = current_solution.copy()
        
        # Process all interval pairs
        for inx in combinations(np.arange(chord_size, dtype=int), 2):
            interval = np.array([new_solution[inx[0]], new_solution[inx[1]]])
            pitch_class_interval = np.array([pitch_class_chord[inx[0]], pitch_class_chord[inx[1]]])
            pitch_class_target = pitch_class_chord[inx[1]]
            
            cent_value_target = find_cent_value_prev_target(
                pitch_class_target, pitch_class_chord_prev, cent_value_chord_prev, chord_num
            )
            
            interval_indices, cent_moves = low_number_ratios.select_ratios(
                interval, cent_value_target, tolerance,
                max_delta=max_delta, ratio_factor=ratio_factor,
                stability_factor=stability_factor
            )
            
            choose_from = min(len(interval_indices), 15)
            
            if choose_from > 1:
                # Temperature-weighted probability: narrow search as we cool
                if temperature < initial_temperature * elbow_percent:
                    # Past elbow: favor better ratios more strongly
                    suggested_inx = rng.choice(
                        np.arange(choose_from), 
                        p=_choose_probabilities(choose_from, r=r_value)
                    )
                else:
                    # Before elbow: more uniform exploration
                    suggested_inx = rng.choice(np.arange(choose_from))
            elif choose_from == 1:
                suggested_inx = 0
            else:
                continue
            
            if len(interval_indices) > 0:
                suggested_interval = tonal_diamond[interval_indices[suggested_inx], 1] * cent_moves
                new_solution[inx[1]] = (interval[0] + suggested_interval) % 1200
        
        new_score = chord_scorer.score_chord(new_solution[inverse], tolerance=tolerance)

        # Accept decision with SA probability
        accepted = False
        improved = False
        if new_score < current_score or rng.random() < np.exp((current_score - new_score) / temperature):
            current_solution = new_solution.copy()
            current_score = new_score
            accepted = True

            if new_score < best_score:
                best_cent_value_chord_so_far = new_solution.copy()
                best_score = new_score
                improved = True
                logging.debug(f'chord#{chord_num} SA: new best {new_score:.1f}')

        # Record trace event if collecting
        if trace is not None:
            trace.append({
                'event': 'attempt',
                'attempt': iteration,
                'candidate_score': float(new_score),
                'best_score': float(best_score),
                'temperature': float(temperature),
                'accept': accepted,
                'improved_best': improved,
            })

        # Early-stop: detect lack of improvement for consecutive iterations
        if best_score < prev_best_score:
            prev_best_score = best_score
            iterations_since_improvement = 0
        else:
            iterations_since_improvement += 1
            if iterations_since_improvement >= max_no_improve:
                rn = f' roll#{roll_num}' if roll_num is not None else ''
                logging.info(f'chord#{chord_num}{rn} Early stop: no improvement for {iterations_since_improvement} iterations (max_no_improve={max_no_improve})')
                break
        
        # Update SA loop variables
        temperature *= cooling_rate
        iteration += 1
    
    if iteration >= max_iterations:
        logging.debug(f'chord#{chord_num} Reached max iterations {max_iterations}')

    # Decompress if needed (perturb may have compressed duplicate pitch classes)
    if best_cent_value_chord_so_far.shape[0] < len(cent_value_chord):
        best_cent_value_chord_so_far = best_cent_value_chord_so_far[inverse]

    # Rearrange and force pitch class match
    proposed_cent_value_chord, _ = atu.rearrange_notes(
        best_cent_value_chord_so_far, pitch_class_chord_current
    )
    proposed_cent_value_chord = atu.force_pitch_class_match(
        proposed_cent_value_chord, pitch_class_chord_current
    )

    final_score = chord_scorer.score_chord(proposed_cent_value_chord, tolerance=tolerance)

    logging.info(f'chord#{chord_num} SA complete: score={final_score:.1f} after {iteration} iterations')

    return proposed_cent_value_chord, final_score


def roll_and_tune(cent_value_chord, cent_value_chord_prev, chord_num,
                  tolerance=1, chord_scorer=None, low_number_ratios=None,
                  tonal_diamond=None, initial_temperature=2.5, cooling_rate=0.999,
                  max_iterations=1000, min_repeats=5, elbow_percent=0.5,
                  r_value=0.3, spread=7, rolls=5, time_limit=0, max_no_improve=None,
                  max_delta=33, ratio_factor=1.0, stability_factor=0.0, trace=None):
    """
    Run SA optimization multiple times with rolled chords, keeping best result.
    """
    import adaptive_tuning_util as atu

    temp_cents = np.zeros((rolls, len(cent_value_chord)), dtype=float)
    temp_scores = np.full(rolls, np.inf, dtype=float)

    rolls_without_improvement = 0
    best_score_so_far = float('inf')

    for roll_num in range(rolls):
        rolled_chord = np.roll(cent_value_chord, roll_num)

        temp_cents[roll_num], temp_scores[roll_num] = build_straw_man_chord_simulated_annealing(
            rolled_chord, cent_value_chord_prev, chord_num,
            tolerance=tolerance, chord_scorer=chord_scorer,
            low_number_ratios=low_number_ratios, tonal_diamond=tonal_diamond,
            initial_temperature=initial_temperature, cooling_rate=cooling_rate,
            max_iterations=max_iterations, min_repeats=min_repeats,
            elbow_percent=elbow_percent, r_value=r_value, spread=spread,
            roll_num=roll_num + 1, time_limit=time_limit, max_no_improve=max_no_improve,
            max_delta=max_delta, ratio_factor=ratio_factor, stability_factor=stability_factor,
            trace=trace
        )

        # Count consecutive non-improving rolls and stop after min_repeats
        if temp_scores[roll_num] + 1e-12 < best_score_so_far:
            best_score_so_far = temp_scores[roll_num]
            rolls_without_improvement = 0
        else:
            rolls_without_improvement += 1
            if rolls_without_improvement >= min_repeats:
                logging.debug(f'chord#{chord_num} Roll early stop after {roll_num + 1} rolls due to {rolls_without_improvement} consecutive non-improving rolls')
                break

    best_idx = np.argmin(temp_scores[:roll_num + 1])
    best_chord = temp_cents[best_idx]
    best_score = temp_scores[best_idx]

    logging.info(f'chord#{chord_num} Best roll: {best_idx + 1}/{roll_num + 1}, score={best_score:.1f}')

    return best_chord, best_score


def _max_pitch_class_gap(prev_chord_cents, curr_chord_cents):
    import adaptive_tuning_util as atu

    if prev_chord_cents is None or len(prev_chord_cents) == 0:
        return 0.0, None, None, None, None

    prev_map = defaultdict(list)
    for pc, cents in zip(atu.pitch_class_from_cents(prev_chord_cents), prev_chord_cents):
        prev_map[int(pc)].append(float(cents))

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
        deltas = [atu.cent_distance_mod_1200(cents, prev_cent) for prev_cent in prev_list]
        min_gap = float(np.min(deltas))
        if min_gap > worst_gap:
            worst_gap = min_gap
            worst_pc = pc
            worst_curr = float(cents)
            worst_prev = float(prev_list[int(np.argmin(deltas))])
            worst_idx = idx

    return worst_gap, worst_pc, worst_curr, worst_prev, worst_idx


def enforce_pitch_class_continuity(sa_cent_value_chorale, chorale, chord_scorer,
                                   low_number_ratios, tonal_diamond, tolerance,
                                   initial_temperature, cooling_rate, max_iterations,
                                   min_repeats, elbow_percent, r_value, spread, rolls,
                                   max_gap=40, retune_on_gaps=3, time_limit=0, max_no_improve=None):
    # Note: this function calls roll_and_tune; if a time_limit is needed it will be passed via closure
    import adaptive_tuning_util as atu

    adjusted = np.array(sa_cent_value_chorale, dtype=float, copy=True)
    fixes = 0

    for chord_idx in range(1, adjusted.shape[0]):
        prev_chord = adjusted[chord_idx - 1]
        curr_chord = adjusted[chord_idx]

        gap_value, pc, curr_cent, prev_cent, voice_idx = _max_pitch_class_gap(prev_chord, curr_chord)

        if gap_value <= max_gap:
            continue

        logging.info(
            f'chord {chord_idx}: pitch class {pc} gap {round(gap_value, 1)}¢ exceeds max_gap {max_gap}¢. Retuning.'
        )

        retries = 0
        while gap_value > max_gap and retries < retune_on_gaps:
            retries += 1
            fixes += 1

            retuned, _ = roll_and_tune(
                curr_chord, prev_chord, chord_idx,
                tolerance=tolerance, chord_scorer=chord_scorer,
                low_number_ratios=low_number_ratios, tonal_diamond=tonal_diamond,
                initial_temperature=initial_temperature, cooling_rate=cooling_rate,
                max_iterations=max_iterations, min_repeats=min_repeats,
                elbow_percent=elbow_percent, r_value=r_value, spread=spread, rolls=rolls,
                time_limit=time_limit, max_no_improve=max_no_improve
            )

            adjusted[chord_idx] = retuned
            curr_chord = retuned
            gap_value, pc, curr_cent, prev_cent, voice_idx = _max_pitch_class_gap(prev_chord, curr_chord)

        if gap_value > max_gap and voice_idx is not None and prev_cent is not None:
            delta = curr_cent - prev_cent
            direction = 1 if delta >= 0 else -1
            target_cent = prev_cent + direction * max_gap
            shift_value = target_cent - curr_cent

            if abs(shift_value) > 0.1:
                logging.info(
                    f'Applying uniform shift of {round(shift_value, 1)}¢ to chord {chord_idx}'
                )
                adjusted[chord_idx] = (curr_chord + shift_value + 1200) % 1200
                curr_chord = adjusted[chord_idx]
                gap_value, pc, curr_cent, prev_cent, voice_idx = _max_pitch_class_gap(prev_chord, curr_chord)

        if gap_value > max_gap and voice_idx is not None and prev_cent is not None:
            logging.warning(
                f'chord {chord_idx}: Forcing voice {voice_idx} (PC {pc}) to previous cent {round(prev_cent, 1)}'
            )
            adjusted[chord_idx, voice_idx] = prev_cent

    if fixes > 0:
        logging.info(f'Pitch-class continuity: made {fixes} retuning attempts')

    return adjusted


def process_chorale(version, numpy_dir, output_dir=None, tolerance=1, limit_max=19,
                    initial_temperature=2.5, cooling_rate=0.999, max_iterations=1000,
                    rolls=5, min_repeats=5, elbow_percent=0.5, r_value=0.3, spread=7,
                    max_gap=40, retune_on_gaps=3, dry_run=False, time_limit=0, max_no_improve=None):
    if output_dir is None:
        output_dir = numpy_dir
    import adaptive_tuning_util as atu

    logging.info(f"Processing {version}...")

    try:
        cent_value_chorale, _, chorale, _, _, _ = atu.load_chorale_in_cents(
            version, numpy_dir, werck_top_notes=False, twelve_tet=True)
    except Exception as e:
        logging.error(f"Failed to load {version}: {e}")
        return None

    tonal_diamond = atu.build_tonal_diamond(limit_max)[:-1]
    chord_scorer = atu.ChordScorer(tonal_diamond)
    low_number_ratios = atu.LowNumberRatioIntervals(tonal_diamond)

    sa_cent_value_chorale = np.zeros_like(chorale.T, dtype=float)
    sa_scores = np.zeros(chorale.T.shape[0])

    cent_value_chord_prev = np.zeros(4)
    prev_midi_chord = np.zeros(4, dtype=int)

    for chord_num in range(cent_value_chorale.shape[1]):
        initial_cent_value_chord = cent_value_chorale[:, chord_num].copy()
        initial_midi_chord = chorale[:, chord_num]

        if not np.array_equal(prev_midi_chord, initial_midi_chord):
            tuned_cent_value_chord, score = roll_and_tune(
                initial_cent_value_chord, cent_value_chord_prev, chord_num,
                tolerance=tolerance, chord_scorer=chord_scorer,
                low_number_ratios=low_number_ratios, tonal_diamond=tonal_diamond,
                initial_temperature=initial_temperature, cooling_rate=cooling_rate,
                max_iterations=max_iterations, min_repeats=min_repeats,
                elbow_percent=elbow_percent, r_value=r_value, spread=spread, rolls=rolls,
                time_limit=time_limit, max_no_improve=max_no_improve
            )

            # Rearrange to match original MIDI pitch class order
            tuned_cent_value_chord, _ = atu.rearrange_notes(tuned_cent_value_chord, initial_midi_chord)
            tuned_cent_value_chord = atu.force_pitch_class_match(tuned_cent_value_chord, initial_midi_chord)

            prev_midi_chord = initial_midi_chord.copy()
            cent_value_chord_prev = tuned_cent_value_chord.copy()

        sa_cent_value_chorale[chord_num] = cent_value_chord_prev.copy()
        sa_scores[chord_num] = chord_scorer.score_chord(cent_value_chord_prev, tolerance=tolerance)

    if retune_on_gaps > 0:
        sa_cent_value_chorale = enforce_pitch_class_continuity(
            sa_cent_value_chorale, chorale, chord_scorer, low_number_ratios, tonal_diamond,
            tolerance, initial_temperature, cooling_rate, max_iterations, min_repeats,
            elbow_percent, r_value, spread, rolls, max_gap=max_gap, retune_on_gaps=retune_on_gaps,
            time_limit=time_limit, max_no_improve=max_no_improve
        )
        # Rearrange all chords to match original MIDI pitch class order after continuity enforcement
        for chord_num in range(sa_cent_value_chorale.shape[0]):
            midi_chord = chorale[:, chord_num]
            rearranged, _ = atu.rearrange_notes(sa_cent_value_chorale[chord_num], midi_chord)
            sa_cent_value_chorale[chord_num] = atu.force_pitch_class_match(rearranged, midi_chord)
            sa_scores[chord_num] = chord_scorer.score_chord(
                sa_cent_value_chorale[chord_num], tolerance=tolerance
            )
    
    # Final verification: ensure all chords match original MIDI pitch class order
    for chord_num in range(sa_cent_value_chorale.shape[0]):
        midi_chord = chorale[:, chord_num]
        rearranged, _ = atu.rearrange_notes(sa_cent_value_chorale[chord_num], midi_chord)
        sa_cent_value_chorale[chord_num] = atu.force_pitch_class_match(rearranged, midi_chord)
        sa_scores[chord_num] = chord_scorer.score_chord(
            sa_cent_value_chorale[chord_num], tolerance=tolerance
        )

    mean_score = np.mean(sa_scores)
    max_score = np.max(sa_scores)
    min_score = np.min(sa_scores)
    median_score = np.median(sa_scores)
    # Calculate deciles (10th, 20th, ..., 90th percentiles)
    deciles = list(np.percentile(sa_scores, [10, 20, 30, 40, 50, 60, 70, 80, 90]))

    output_file = os.path.join(output_dir, f'{version}-sa-opt.npy')
    meta_file = os.path.join(output_dir, f'{version}-sa-opt.txt')
    
    logging.info("=== SAVE LOGIC v2.2 for %s ===", version)
    logging.info("output_dir: %s", output_dir)
    logging.info("output_file: %s", output_file)

    # Check if previous result exists and compare
    previous_mean = None
    is_improvement = True
    files_exist = os.path.exists(output_file) and os.path.exists(meta_file)

    if files_exist:
        try:
            with open(meta_file, 'r') as f:
                for line in f:
                    lower = line.strip().lower()
                    if lower.startswith('mean:'):
                        previous_mean = float(lower.split('mean:')[1].split()[0])
        except Exception as e:
            logging.warning("Failed to read previous result for %s: %s", version, e)
            previous_mean = None
    else:
        logging.info("No previous files found for %s, will save as baseline", version)
        previous_mean = None

    if previous_mean is None:
        is_improvement = True
    else:
        is_improvement = mean_score < previous_mean
        if not is_improvement:
            logging.info("%s: No improvement. mean=%0.1f vs previous=%0.1f", version, mean_score, previous_mean)

    if not dry_run:
        logging.debug("is_improvement=%s, dry_run=%s", is_improvement, dry_run)
        if is_improvement:
            try:
                # Ensure directory exists
                os.makedirs(output_dir, exist_ok=True)
                logging.debug("Created/verified dir %s, dir exists: %s", output_dir, os.path.isdir(output_dir))
                
                # Save numpy file
                np.save(output_file, sa_cent_value_chorale.T)
                logging.debug("Saved numpy to %s, file exists: %s", output_file, os.path.exists(output_file))
                
                # Save metadata file
                with open(meta_file, 'w') as f:
                    f.write(f"version: {version}\n")
                    f.write(f"mean: {mean_score:.1f}\n")
                    f.write(f"median: {median_score:.1f}\n")
                    f.write(f"min: {min_score:.1f}\n")
                    f.write(f"max: {max_score:.1f}\n")
                    f.write(f"deciles: {' '.join([f'{d:.0f}' for d in deciles])}\n")
                logging.debug("Saved metadata to %s, file exists: %s", meta_file, os.path.exists(meta_file))
                
                logging.info("%s: Saved to %s", version, output_file)
            except Exception as e:
                print(f"✗ {version}: FAILED to save! {output_file} - Error: {e}")
                logging.error("%s: FAILED to save! %s - Error: %s", version, output_file, e)
                import traceback
                logging.error(traceback.format_exc())
                print(traceback.format_exc())
        else:
            logging.info("%s: Keeping previous best (mean=%0.1f)", version, previous_mean)
    else:
        logging.info(f"{version}: Would save to {output_file} (dry-run mode)")

    return {
        'version': version,
        'mean': mean_score,
        'max': max_score,
        'min': min_score,
        'median': median_score,
        'deciles': deciles,
        'path': output_file,
        'shape': sa_cent_value_chorale.T.shape,
        'is_improvement': is_improvement,
        'previous_mean': previous_mean,
        'saved_to': output_file if (is_improvement and not dry_run) else None
    }


def main():
    parser = argparse.ArgumentParser(
        description='Chord tuning optimization using simulated annealing (v2)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--verbose', action='store_true')
    parser.add_argument('--tolerance', type=int, default=1, 
                       help='Tolerance level (1-4) for data directory. Default: 1')
    parser.add_argument('--limit-max', type=int, default=19)
    # Convenience alias: accept underscore form used by some callers
    parser.add_argument('--limit_max', dest='limit_max', type=int, help=argparse.SUPPRESS)
    parser.add_argument('--initial-temperature', type=float, default=2.5)
    parser.add_argument('--cooling-rate', type=float, default=0.999)
    parser.add_argument('--max-iterations', type=int, default=1000)
    parser.add_argument('--rolls', type=int, default=8)
    parser.add_argument('--min-repeats', type=int, default=5)
    parser.add_argument('--elbow-percent', type=float, default=0.5)
    parser.add_argument('--r-value', type=float, default=0.3)
    parser.add_argument('--spread', type=int, default=7)
    parser.add_argument('--max-gap', type=int, default=40)
    parser.add_argument('--retune-on-gaps', type=int, default=3)
    # Convenience alias for callers that use underscores
    parser.add_argument('--retune_on_gaps', dest='retune_on_gaps', type=int, help=argparse.SUPPRESS)
    parser.add_argument('--quick', action='store_true', help='Use quick, low-cost defaults for testing')
    parser.add_argument('--time-limit', type=float, default=0.0, help='Per-roll time limit in seconds (0 = disabled)')
    parser.add_argument('--max-no-improve', type=int, default=50, help='Per-roll max consecutive iterations without improvement (early stop)')
    # Convenience alias for callers that use underscores
    parser.add_argument('--max_no_improve', dest='max_no_improve', type=int, help=argparse.SUPPRESS)
    parser.add_argument('--chorale', type=str, default=None)
    parser.add_argument('--runs', type=int, default=1, help='Number of times to process the chorales sequentially')
    args = parser.parse_args()

    # Validate tolerance
    if not (1 <= args.tolerance <= 4):
        print(f"Error: tolerance must be 1-4, got {args.tolerance}", file=sys.stderr)
        sys.exit(1)

    paths = setup_paths(tolerance=args.tolerance)
    numpy_dir = paths['numpy_dir']
    log_dir = paths['log_dir']
    output_dir = numpy_dir
    
    # Use chorale-specific log file when running single chorale (for parallel runs)
    if args.chorale:
        log_file = os.path.join(log_dir, f'optimize_chords_sa_v2_{args.chorale}.log')
    else:
        log_file = os.path.join(log_dir, 'optimize_chords_sa_v2.log')
    setup_logger(log_file, verbose=args.verbose)

    try:
        os.makedirs(output_dir, exist_ok=True)
    except Exception:
        pass

    logging.info("=" * 80)
    logging.info("CHORD TUNING OPTIMIZATION - SIMULATED ANNEALING V2")
    logging.info("=" * 80)
    logging.info(f"Mode: {'DRY-RUN' if args.dry_run else 'PRODUCTION'}")
    logging.info(f"Tolerance: {args.tolerance}")
    logging.info(f"Data directory: {numpy_dir}")

    if args.chorale:
        chorale_list = [args.chorale]
    else:
        chorale_list = ['bwv253','bwv254','bwv255','bwv256','bwv257','bwv258','bwv259','bwv260','bwv261','bwv262','bwv263','bwv264']

    # Allow quick/testing mode to override heavy defaults
    if args.runs < 1:
        print(f"Error: runs must be >= 1, got {args.runs}", file=sys.stderr)
        sys.exit(1)

    if args.quick:
        args.max_iterations = min(args.max_iterations, 200)
        args.rolls = min(args.rolls, 2)
        args.min_repeats = min(args.min_repeats, 3)
        if args.time_limit <= 0:
            args.time_limit = 5.0

    sa_params = {
        'tolerance': args.tolerance,
        'limit_max': args.limit_max,
        'initial_temperature': args.initial_temperature,
        'cooling_rate': args.cooling_rate,
        'max_iterations': args.max_iterations,
        'rolls': args.rolls,
        'min_repeats': args.min_repeats,
        'elbow_percent': args.elbow_percent,
        'r_value': args.r_value,
        'spread': args.spread,
        'max_gap': args.max_gap,
        'retune_on_gaps': args.retune_on_gaps,
        'time_limit': args.time_limit,
        'max_no_improve': args.max_no_improve,
    }

    logging.info(f"Processing {len(chorale_list)} chorales")
    logging.info(f"SA parameters: {sa_params}")

    params_str = ", ".join([f"{k}={v}" for k, v in sa_params.items()])

    for run_idx in range(1, args.runs + 1):
        if args.runs > 1:
            logging.info("Starting run %d/%d", run_idx, args.runs)
        print("\n" + "=" * 80)
        print(f"PROCESSING CHORALES (SA v2) run {run_idx}/{args.runs}" if args.runs > 1 else "PROCESSING CHORALES (SA v2)")
        print("=" * 80)
        print(f"Parameters: {params_str}")
        print()

        results = {}
        improved_count = 0

        for version in chorale_list:
            result = process_chorale(version, numpy_dir, output_dir=output_dir, dry_run=args.dry_run, **sa_params)
            if result:
                results[version] = result
                if result.get('is_improvement', False):
                    improved_count += 1

        print("\n" + "=" * 80)
        print(f"SUMMARY run {run_idx}/{args.runs}" if args.runs > 1 else "SUMMARY")
        print("=" * 80)
        if results:
            means = [r['mean'] for r in results.values()]
            print(f"Processed: {len(results)} chorales")
            print(f"Improved:  {improved_count}")
            print(f"Average mean score: {np.mean(means):.1f}")
            for version, result in results.items():
                deciles_str = ' '.join([f"{d:3.0f}" for d in result['deciles']])
                prev_str = f" (was {result['previous_mean']:.1f})" if result.get('previous_mean') else " (first run)"
                status = "✓" if result.get('is_improvement', False) else " "
                saved_str = f"  Saved to {result['saved_to']}" if result.get('saved_to') else ""
                print(f"{status} {version:12} mean: {result['mean']:6.1f}  max: {result['max']:6.1f}  median: {result['median']:6.1f}  min: {result['min']:6.1f}  deciles [{deciles_str}]{prev_str}")
                if saved_str:
                    print(f"  {saved_str}")


if __name__ == '__main__':
    main()
