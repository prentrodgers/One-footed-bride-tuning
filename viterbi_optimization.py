#!/usr/bin/env python
# coding: utf-8

"""
viterbi_optimization.py

Viterbi-like dynamic programming optimization for chorale tuning.
Generates K candidate tunings per chord, then selects the optimal path
through the candidate trellis that minimizes both vertical (chord quality)
and horizontal (pitch-class consistency) costs.
"""

import logging
import numpy as np
from collections import defaultdict
import adaptive_tuning_util as atu


def generate_k_candidates(cent_value_chord, cent_value_chord_prev, chord_num,
                         chord_scorer, low_number_ratios, tonal_diamond,
                         tolerance=1, K=10, rolls=4, sa_iterations=100,
                         initial_temperature=2.0, cooling_rate=0.995,
                         ratio_factor=1.0, stability_factor=0.0, spread=7,
                         rng=None, build_chord_sa_func=None):
    """
    Generate K diverse candidate tunings for a single chord.
    
    Uses different random seeds and temperature variations to explore
    the solution space and generate diverse high-quality candidates.
    
    Parameters
    ----------
    cent_value_chord : np.ndarray
        Initial cent values for the chord (4 notes).
    cent_value_chord_prev : np.ndarray
        Cent values from the previous chord (for context).
    chord_num : int
        Chord index in the chorale.
    chord_scorer : atu.ChordScorer
        Scorer object for evaluating chord quality.
    low_number_ratios : atu.LowNumberRatioIntervals
        Ratio selector object.
    tonal_diamond : np.ndarray
        Tonal diamond array [ratio, cents, limit_score].
    tolerance : int, optional
        Cent tolerance for ratio matching (default: 1).
    K : int, optional
        Number of candidates to generate (default: 10).
    rolls : int, optional
        Number of rolls per SA run (default: 4).
    sa_iterations : int, optional
        SA iterations per roll (default: 100).
    initial_temperature : float, optional
        Starting SA temperature (default: 2.0).
    cooling_rate : float, optional
        Temperature decay rate (default: 0.995).
    ratio_factor : float, optional
        Consonance/stability trade-off (default: 1.0).
    stability_factor : float, optional
        Weight for previous chord proximity (default: 0.0).
    spread : int, optional
        Gaussian noise std dev in cents (default: 7).
    rng : np.random.Generator, optional
        Random number generator (default: None, creates new one).
    build_chord_sa_func : callable, optional
        SA chord building function (default: None, must be provided).
    
    Returns
    -------
    list of tuples
        List of (cent_values, score) tuples, sorted by score (best first).
        Length is min(K, actual_unique_candidates).
    """
    if rng is None:
        rng = np.random.default_rng()
    
    if build_chord_sa_func is None:
        raise ValueError("build_chord_sa_func must be provided")
    
    candidates = []
    seen_tunings = set()  # Track unique tunings to avoid duplicates
    
    base_seed = rng.integers(0, 2**31)
    
    for k in range(K * 2):  # Generate extra to account for duplicates
        # Vary temperature and seed for diversity
        temp_variation = 1.0 + 0.3 * (k / K - 0.5)  # Range: 0.85 to 1.15
        temp = initial_temperature * temp_variation
        seed = base_seed + k
        candidate_rng = np.random.default_rng(seed)
        
        # Vary spread slightly for additional diversity
        spread_variation = max(0, spread + rng.integers(-2, 3))
        
        tuned_chord, _, _, _ = build_chord_sa_func(
            cent_value_chord, cent_value_chord_prev, chord_num,
            chord_scorer, low_number_ratios, tonal_diamond,
            tolerance=tolerance, print_values=False, rolls=rolls,
            sa_iterations=sa_iterations, initial_temperature=temp,
            cooling_rate=cooling_rate, rng=candidate_rng,
            ratio_factor=ratio_factor, stability_factor=stability_factor,
            spread=spread_variation)
        
        # Create a hashable representation to check for duplicates
        tuning_key = tuple(np.round(tuned_chord, 1))  # Round to 0.1 cent
        
        if tuning_key not in seen_tunings:
            seen_tunings.add(tuning_key)
            score = chord_scorer.score_chord(tuned_chord, tolerance=tolerance)
            candidates.append((tuned_chord.copy(), float(score)))
            
            if len(candidates) >= K:
                break
    
    # Sort by score (lower is better)
    candidates.sort(key=lambda x: x[1])
    
    logging.info(f'chord {chord_num}: generated {len(candidates)} unique candidates '
                f'(scores: {[f"{s:.1f}" for _, s in candidates[:5]]}...)')
    
    return candidates[:K]


def compute_transition_cost(prev_cents, curr_cents, prev_midi, curr_midi,
                           penalty_type='pitch_class_jump'):
    """
    Compute horizontal penalty for transitioning between two chords.
    
    Penalizes pitch-class jumps for shared notes between adjacent chords.
    
    Parameters
    ----------
    prev_cents : np.ndarray
        Cent values of previous chord (4 notes).
    curr_cents : np.ndarray
        Cent values of current chord (4 notes).
    prev_midi : np.ndarray
        MIDI notes of previous chord (4 notes).
    curr_midi : np.ndarray
        MIDI notes of current chord (4 notes).
    penalty_type : str, optional
        Type of penalty: 'pitch_class_jump' (default), 'voice_leading', or 'combined'.
    
    Returns
    -------
    float
        Horizontal transition cost (lower is better).
    """
    prev_pcs = atu.pitch_class_from_cents(prev_cents)
    curr_pcs = atu.pitch_class_from_cents(curr_cents)
    
    # Build pitch-class to cent mapping for previous chord
    prev_pc_map = defaultdict(list)
    for pc, c in zip(prev_pcs, prev_cents):
        prev_pc_map[int(pc)].append(float(c))
    
    total_penalty = 0.0
    
    if penalty_type in ['pitch_class_jump', 'combined']:
        # Penalize cent distance for shared pitch classes
        for pc, c in zip(curr_pcs, curr_cents):
            pc = int(pc)
            if pc in prev_pc_map:
                # Find minimum distance to any occurrence of this PC in prev chord
                distances = [atu.cent_distance_mod_1200(c, prev_c) 
                           for prev_c in prev_pc_map[pc]]
                min_dist = min(distances)
                total_penalty += min_dist
    
    if penalty_type in ['voice_leading', 'combined']:
        # Additional penalty for voice leading (MIDI note movement)
        # This encourages smooth voice leading even when pitch classes differ
        for i in range(len(curr_midi)):
            if curr_midi[i] == prev_midi[i]:
                # Same MIDI note: penalize cent difference
                dist = atu.cent_distance_mod_1200(curr_cents[i], prev_cents[i])
                if penalty_type == 'combined':
                    total_penalty += dist * 0.5  # Weight less than PC jumps
                else:
                    total_penalty += dist
    
    return total_penalty


def viterbi_select_path(all_candidates, chorale_midi, vertical_weight=1.0,
                       horizontal_weight=0.5, penalty_type='pitch_class_jump'):
    """
    Select optimal path through candidate trellis using dynamic programming.
    
    Implements a Viterbi-like algorithm to find the sequence of chord tunings
    that minimizes the combined vertical (chord quality) and horizontal
    (pitch-class consistency) costs.
    
    Parameters
    ----------
    all_candidates : list of lists
        all_candidates[i] contains K candidates for chord i, each as
        (cent_values, vertical_score) tuple.
    chorale_midi : np.ndarray
        Shape (4, N), original MIDI notes for the chorale.
    vertical_weight : float, optional
        Weight for chord quality scores (default: 1.0).
    horizontal_weight : float, optional
        Weight for transition costs (default: 0.5).
    penalty_type : str, optional
        Type of horizontal penalty (default: 'pitch_class_jump').
    
    Returns
    -------
    tuple
        (selected_tunings, path, total_cost)
        - selected_tunings: np.ndarray, shape (N, 4), selected cent values
        - path: list of int, indices of selected candidates for each chord
        - total_cost: float, total cost of the selected path
    """
    n_chords = len(all_candidates)
    if n_chords == 0:
        return np.array([]), [], 0.0
    
    K = len(all_candidates[0])
    
    # DP table: dp[chord_idx][candidate_idx] = (min_cost, prev_candidate_idx)
    dp = [[None for _ in range(K)] for _ in range(n_chords)]
    
    # Initialize first chord (no transition cost)
    for k in range(len(all_candidates[0])):
        cent_vals, v_score = all_candidates[0][k]
        dp[0][k] = (vertical_weight * v_score, -1)
    
    # Fill DP table
    for i in range(1, n_chords):
        K_curr = len(all_candidates[i])
        K_prev = len(all_candidates[i-1])
        
        for k_curr in range(K_curr):
            curr_cents, curr_v_score = all_candidates[i][k_curr]
            min_cost = float('inf')
            best_prev = -1
            
            for k_prev in range(K_prev):
                prev_cents, _ = all_candidates[i-1][k_prev]
                prev_cost, _ = dp[i-1][k_prev]
                
                # Compute transition cost (horizontal penalty)
                h_cost = compute_transition_cost(
                    prev_cents, curr_cents,
                    chorale_midi[:, i-1], chorale_midi[:, i],
                    penalty_type=penalty_type)
                
                total_cost = (prev_cost +
                            vertical_weight * curr_v_score +
                            horizontal_weight * h_cost)
                
                if total_cost < min_cost:
                    min_cost = total_cost
                    best_prev = k_prev
            
            dp[i][k_curr] = (min_cost, best_prev)
    
    # Backtrack to find optimal path
    path = []
    best_final_k = min(range(len(all_candidates[-1])),
                      key=lambda k: dp[n_chords-1][k][0])
    
    k = best_final_k
    for i in range(n_chords - 1, -1, -1):
        path.append(k)
        _, k = dp[i][k]
    
    path.reverse()
    
    # Extract selected tunings
    selected_tunings = np.array([
        all_candidates[i][path[i]][0] for i in range(n_chords)
    ])
    
    total_cost = dp[n_chords-1][best_final_k][0]
    
    logging.info(f'Viterbi path selection complete: total_cost={total_cost:.1f}, '
                f'path diversity={len(set(path))}/{K} candidates used')
    
    return selected_tunings, path, total_cost


def hierarchical_viterbi_optimization(chorale, cent_value_chorale,
                                     chord_scorer, low_number_ratios,
                                     tonal_diamond, tolerance=1,
                                     K=10, rolls=4, sa_iterations=100,
                                     initial_temperature=2.0, cooling_rate=0.995,
                                     ratio_factor=1.0, stability_factor=0.0,
                                     spread=7, rng=None,
                                     phrase_boundaries=None,
                                     vertical_weight_phrase=1.0,
                                     horizontal_weight_phrase=1.0,
                                     vertical_weight_piece=1.0,
                                     horizontal_weight_piece=0.3,
                                     build_chord_sa_func=None):
    """
    Apply Viterbi optimization hierarchically at phrase and piece levels.
    
    Optimizes in two stages:
    1. Phrase level: Strong horizontal constraints within musical phrases
    2. Piece level: Weaker constraints for global smoothing
    
    Parameters
    ----------
    chorale : np.ndarray
        Shape (4, N), original MIDI notes.
    cent_value_chorale : np.ndarray
        Shape (4, N), initial cent values (e.g., 12-TET).
    chord_scorer : atu.ChordScorer
        Scorer for chord quality.
    low_number_ratios : atu.LowNumberRatioIntervals
        Ratio selector.
    tonal_diamond : np.ndarray
        Tonal diamond array.
    tolerance : int, optional
        Cent tolerance (default: 1).
    K : int, optional
        Candidates per chord (default: 10).
    rolls : int, optional
        SA rolls (default: 4).
    sa_iterations : int, optional
        SA iterations (default: 100).
    initial_temperature : float, optional
        SA temperature (default: 2.0).
    cooling_rate : float, optional
        SA cooling (default: 0.995).
    ratio_factor : float, optional
        Consonance weight (default: 1.0).
    stability_factor : float, optional
        Previous chord weight (default: 0.0).
    spread : int, optional
        Noise std dev (default: 7).
    rng : np.random.Generator, optional
        RNG (default: None).
    phrase_boundaries : list of tuples, optional
        List of (start, end) indices for phrases (default: None, treat as one phrase).
    vertical_weight_phrase : float, optional
        Vertical weight for phrase-level optimization (default: 1.0).
    horizontal_weight_phrase : float, optional
        Horizontal weight for phrase-level optimization (default: 1.0).
    vertical_weight_piece : float, optional
        Vertical weight for piece-level optimization (default: 1.0).
    horizontal_weight_piece : float, optional
        Horizontal weight for piece-level optimization (default: 0.3).
    build_chord_sa_func : callable, optional
        SA chord building function (required).
    
    Returns
    -------
    tuple
        (final_tuning, phrase_paths, piece_path)
        - final_tuning: np.ndarray, shape (N, 4), optimized cent values
        - phrase_paths: list of lists, candidate paths for each phrase
        - piece_path: list of int, final path through piece-level candidates
    """
    if rng is None:
        rng = np.random.default_rng()
    
    if build_chord_sa_func is None:
        raise ValueError("build_chord_sa_func must be provided")
    
    n_chords = chorale.shape[1]
    
    # Default: treat entire piece as one phrase
    if phrase_boundaries is None:
        phrase_boundaries = [(0, n_chords)]
    
    logging.info(f'Hierarchical Viterbi: {len(phrase_boundaries)} phrase(s), '
                f'{n_chords} chords, K={K}')
    
    # Level 1: Optimize within phrases
    phrase_solutions = []
    phrase_paths = []
    
    for phrase_idx, (start, end) in enumerate(phrase_boundaries):
        logging.info(f'Phrase {phrase_idx+1}/{len(phrase_boundaries)}: '
                    f'chords {start}-{end-1}')
        
        phrase_candidates = []
        prev_cents = np.zeros(4, dtype=int)
        
        for i in range(start, end):
            candidates = generate_k_candidates(
                cent_value_chorale[:, i], prev_cents, i,
                chord_scorer, low_number_ratios, tonal_diamond,
                tolerance=tolerance, K=K, rolls=rolls,
                sa_iterations=sa_iterations,
                initial_temperature=initial_temperature,
                cooling_rate=cooling_rate, ratio_factor=ratio_factor,
                stability_factor=stability_factor, spread=spread,
                rng=rng, build_chord_sa_func=build_chord_sa_func)
            phrase_candidates.append(candidates)
            
            # Update prev_cents with best candidate for next iteration
            if candidates:
                prev_cents = candidates[0][0].copy()
        
        # High horizontal weight within phrases for consistency
        phrase_tuning, path, cost = viterbi_select_path(
            phrase_candidates, chorale[:, start:end],
            vertical_weight=vertical_weight_phrase,
            horizontal_weight=horizontal_weight_phrase)
        
        phrase_solutions.append(phrase_tuning)
        phrase_paths.append(path)
        
        logging.info(f'Phrase {phrase_idx+1} optimized: cost={cost:.1f}, '
                    f'{len(path)} chords')
    
    # Concatenate phrase solutions
    if len(phrase_solutions) == 1:
        # Single phrase: return directly
        final_tuning = phrase_solutions[0]
        piece_path = phrase_paths[0]
    else:
        # Multiple phrases: optionally run piece-level optimization
        # For now, just concatenate (could add transition smoothing here)
        final_tuning = np.vstack(phrase_solutions)
        piece_path = []
        for path in phrase_paths:
            piece_path.extend(path)
        
        logging.info(f'Phrases concatenated: {final_tuning.shape[0]} total chords')
    
    return final_tuning, phrase_paths, piece_path


def detect_phrase_boundaries(chorale, fermata_threshold=2):
    """
    Detect phrase boundaries in a chorale based on repeated chords (fermatas).
    
    Parameters
    ----------
    chorale : np.ndarray
        Shape (4, N), MIDI notes.
    fermata_threshold : int, optional
        Minimum number of consecutive identical chords to mark a phrase boundary
        (default: 2).
    
    Returns
    -------
    list of tuples
        List of (start, end) indices for each phrase.
    """
    n_chords = chorale.shape[1]
    boundaries = []
    phrase_start = 0
    
    prev_chord = None
    repeat_count = 0
    
    for i in range(n_chords):
        curr_chord = tuple(chorale[:, i])
        
        if prev_chord is not None and curr_chord == prev_chord:
            repeat_count += 1
        else:
            if repeat_count >= fermata_threshold and i > phrase_start + 1:
                # End of phrase detected
                boundaries.append((phrase_start, i))
                phrase_start = i
            repeat_count = 0
        
        prev_chord = curr_chord
    
    # Add final phrase
    if phrase_start < n_chords:
        boundaries.append((phrase_start, n_chords))
    
    logging.info(f'Detected {len(boundaries)} phrase(s): {boundaries}')
    return boundaries

# Made with Bob
