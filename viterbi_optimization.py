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
import multiprocessing
import multiprocessing.pool
import numpy as np
from collections import defaultdict
import adaptive_tuning_util as atu

# Module-level state populated before forking so child processes inherit it
# without pickling.
_WORKER_STATE: dict = {}


def _worker_log_reinit():
    """Reset logging state after fork to prevent futex deadlock.

    fork() copies all threading.RLocks in whatever state the parent held them.
    Two separate locks can cause a deadlock:
      1. logging._lock  — module-level, acquired on every logging call before
                          dispatching to handlers.
      2. handler.lock   — per-handler, acquired when writing.
    If either was held at fork time the child's phantom-owner copy deadlocks
    any subsequent logging call.  We reinitialise both here, immediately after
    fork, before any task code runs.
    """
    import threading
    logging._lock = threading.RLock()   # reinitialise module-level lock
    root = logging.getLogger()
    for h in root.handlers[:]:
        try:
            h.close()
        except Exception:
            pass
    root.handlers.clear()
    root.addHandler(logging.NullHandler())  # suppress lastResort stderr fallback


def _parallel_candidate_worker(args):
    """Module-level worker: picklable, reads complex objects from _WORKER_STATE."""
    i, cent_col, seed = args
    s = _WORKER_STATE
    rng = np.random.default_rng(seed)
    candidates = generate_k_candidates(
        cent_col, np.zeros(4, dtype=int), i,
        s['chord_scorer'], s['low_number_ratios'], s['tonal_diamond'],
        tolerance=s['tolerance'], K=s['K'], rolls=s['rolls'],
        sa_iterations=s['sa_iterations'],
        initial_temperature=s['initial_temperature'],
        cooling_rate=s['cooling_rate'],
        ratio_factor=s['ratio_factor'],
        stability_factor=s['stability_factor'],
        spread=s['spread'],
        rng=rng,
        build_chord_sa_func=s['build_chord_sa_func'],
        candidate_max_no_improve=s['candidate_max_no_improve'])
    return i, candidates


def generate_k_candidates(cent_value_chord, cent_value_chord_prev, chord_num,
                         chord_scorer, low_number_ratios, tonal_diamond,
                         tolerance, K=10, rolls=4, sa_iterations=100,
                         initial_temperature=2.0, cooling_rate=0.995,
                         ratio_factor=1.0, stability_factor=0.0, spread=7,
                         rng=None, build_chord_sa_func=None,
                         candidate_max_no_improve=None):
    """
    Generate K diverse candidate tunings for a single chord.

    Uses different random seeds and temperature variations to explore
    the solution space and generate diverse high-quality candidates.
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
            spread=spread_variation,
            max_no_improve=candidate_max_no_improve)
        
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


def _update_pc_accum(accum, cents_array, octave=1200.0):
    """Return a new accumulator with the four notes in cents_array folded in."""
    new_accum = accum.copy()
    pcs = atu.pitch_class_from_cents(cents_array)
    for pc, cv in zip(pcs, cents_array):
        theta = 2.0 * np.pi * float(cv) / octave
        new_accum[pc, 0] += np.sin(theta)
        new_accum[pc, 1] += np.cos(theta)
        new_accum[pc, 2] += 1.0
    return new_accum


def _accum_mad_cost(accum, cents_array, octave=1200.0):
    """Sum of circular distances from each note to its running PC mean.

    Returns 0 for pitch classes not yet seen (no prior history to deviate from).
    """
    pcs = atu.pitch_class_from_cents(cents_array)
    total = 0.0
    for pc, cv in zip(pcs, cents_array):
        count = accum[pc, 2]
        if count < 1:
            continue
        angle = np.arctan2(accum[pc, 0], accum[pc, 1]) % (2.0 * np.pi)
        mean_cv = angle * octave / (2.0 * np.pi)
        diff = abs(float(cv) - mean_cv) % octave
        total += min(diff, octave - diff)
    return total


def _mad_optimal_delta(cents_array, pc_accum, octave=1200.0, max_shift=50.0):
    """Find a single cent offset for the whole chord that reduces MAD cost.

    Tries shifting the chord toward each voice's running pitch-class circular
    mean.  Only accepts shifts that leave every pitch class unchanged (hard
    constraint from horizontal_transpose logic).  Returns (delta, shifted) if
    an improvement is found, otherwise (0.0, None).
    """
    pcs = atu.pitch_class_from_cents(cents_array)
    base_cost = _accum_mad_cost(pc_accum, cents_array, octave)

    candidate_deltas = []
    for pc, cv in zip(pcs, cents_array):
        if pc_accum[pc, 2] < 1:
            continue
        angle = np.arctan2(pc_accum[pc, 0], pc_accum[pc, 1]) % (2.0 * np.pi)
        mean_cv = angle * octave / (2.0 * np.pi)
        delta = float(np.mod(mean_cv - float(cv) + 600.0, 1200.0) - 600.0)
        candidate_deltas.append(delta)

    best_delta = 0.0
    best_cost = base_cost

    for delta in candidate_deltas:
        if abs(delta) < 1e-6 or abs(delta) > max_shift:
            continue
        shifted = np.mod(cents_array + delta, octave)
        if not np.array_equal(atu.pitch_class_from_cents(shifted), pcs):
            continue
        cost = _accum_mad_cost(pc_accum, shifted, octave)
        if cost < best_cost - 1e-6:
            best_cost = cost
            best_delta = delta

    if abs(best_delta) < 1e-6:
        return 0.0, None
    return best_delta, np.mod(cents_array + best_delta, octave)


def compute_transition_cost(prev_cents, curr_cents, prev_midi, curr_midi,
                           penalty_type='pitch_class_jump'):
    """
    Compute horizontal penalty for transitioning between two chords.

    Penalizes pitch-class jumps for shared notes between adjacent chords.
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
                       horizontal_weight=0.5, penalty_type='pitch_class_jump',
                       mad_weight=0.0, verbose=False, verbose_threshold=None):
    """
    Select optimal path through candidate trellis using dynamic programming.

    Implements a Viterbi-like algorithm to find the sequence of chord tunings
    that minimizes the combined vertical (chord quality), horizontal
    (pitch-class jump between adjacent chords), and global MAD consistency costs.

    Each DP state carries a running pitch-class accumulator (circular sin/cos
    sums per pitch class) representing all chords committed to along the best
    path to that state.  When mad_weight > 0, each candidate is penalised by
    how far its notes deviate from the running circular mean for their pitch
    class — catching global tuning drift that the adjacent-only horizontal cost
    cannot see.
    """
    n_chords = len(all_candidates)
    if n_chords == 0:
        return np.array([]), [], 0.0

    # DP state: (min_cost, prev_candidate_idx, pc_accum, used_cents)
    # used_cents is the actual chord cents committed to at this state — may differ
    # from the raw candidate if a MAD-reducing transposition was applied.
    dp = [[None for _ in range(len(all_candidates[i]))] for i in range(n_chords)]

    # Initialise first chord — no transition cost, seed the accumulator
    for k in range(len(all_candidates[0])):
        cent_vals, v_score = all_candidates[0][k]
        # Try transposition even at chord 0 (no prior history → no-op, but safe)
        accum = _update_pc_accum(np.zeros((12, 3), dtype=float), cent_vals)
        dp[0][k] = (vertical_weight * v_score, -1, accum, cent_vals)

    # Fill DP table left to right
    for i in range(1, n_chords):
        K_curr = len(all_candidates[i])
        K_prev = len(all_candidates[i-1])

        for k_curr in range(K_curr):
            curr_cents, curr_v_score = all_candidates[i][k_curr]
            min_cost = float('inf')
            best_prev = -1
            best_accum = None
            best_used_cents = curr_cents

            for k_prev in range(K_prev):
                prev_cost, _, prev_accum, prev_used = dp[i-1][k_prev]

                # Consider original and MAD-transposed variant
                variants = [curr_cents]
                if mad_weight > 0:
                    _, trans = _mad_optimal_delta(curr_cents, prev_accum)
                    if trans is not None:
                        variants.append(trans)

                for used_cents in variants:
                    h_cost = compute_transition_cost(
                        prev_used, used_cents,
                        chorale_midi[:, i-1], chorale_midi[:, i],
                        penalty_type=penalty_type)

                    m_cost = (_accum_mad_cost(prev_accum, used_cents)
                              if mad_weight > 0 else 0.0)

                    total_cost = (prev_cost
                                  + vertical_weight * curr_v_score
                                  + horizontal_weight * h_cost
                                  + mad_weight * m_cost)

                    if total_cost < min_cost:
                        min_cost = total_cost
                        best_prev = k_prev
                        best_accum = _update_pc_accum(prev_accum, used_cents)
                        best_used_cents = used_cents

            dp[i][k_curr] = (min_cost, best_prev, best_accum, best_used_cents)

    # Backtrack to find optimal path
    path = []
    best_final_k = min(range(len(all_candidates[-1])),
                       key=lambda k: dp[n_chords-1][k][0])

    k = best_final_k
    for i in range(n_chords - 1, -1, -1):
        path.append(k)
        _, k, _, _ = dp[i][k]

    path.reverse()

    # Extract used_cents (may be transposed) rather than raw candidate cents
    selected_tunings = np.array([
        dp[i][path[i]][3] for i in range(n_chords)
    ])

    total_cost = dp[n_chords-1][best_final_k][0]

    max_candidates = max(len(all_candidates[i]) for i in range(n_chords))
    logging.info(f'Viterbi path selection complete: total_cost={total_cost:.1f}, '
                 f'path diversity={len(set(path))}/{max_candidates} candidates used')

    if verbose:
        rows = []
        for i in range(n_chords):
            chosen_k = path[i]
            chosen_score = all_candidates[i][chosen_k][1]
            best_score = min(s for _, s in all_candidates[i])
            k_count = len(all_candidates[i])
            if verbose_threshold is not None and chosen_score < verbose_threshold:
                continue
            note = ''
            if chosen_score > best_score + 0.5:
                note = f'<-- spread/h drove choice (best={best_score:.1f})'
            all_scores = sorted(s for _, s in all_candidates[i])
            scores_str = ' '.join(f'{s:.0f}' for s in all_scores[:5])
            if k_count > 5:
                scores_str += ' ...'
            rows.append((i, chosen_k, chosen_score, best_score, k_count, note, scores_str))
        if rows:
            print(f'\n  {"Chord":>6}  {"Chosen":>6}  {"Chosen score":>12}  {"Best score":>10}  {"K":>4}  Note')
            print(f'  {"-----":>6}  {"------":>6}  {"------------":>12}  {"----------":>10}  {"--":>4}  ----')
            for i, chosen_k, chosen_score, best_score, k_count, note, scores_str in rows:
                print(f'  {i:>6}  {chosen_k:>6}  {chosen_score:>12.1f}  {best_score:>10.1f}  {k_count:>4}  {note}')
                print(f'  {"":>6}  {"":>6}  {"all scores:":>12}  {scores_str}')

    return selected_tunings, path, total_cost


def hierarchical_viterbi_optimization(chorale, cent_value_chorale,
                                     chord_scorer, low_number_ratios,
                                     tonal_diamond, tolerance,
                                     K=10, rolls=4, sa_iterations=100,
                                     initial_temperature=2.0, cooling_rate=0.995,
                                     ratio_factor=1.0, stability_factor=0.0,
                                     spread=7, rng=None,
                                     phrase_boundaries=None,
                                     vertical_weight_phrase=1.0,
                                     horizontal_weight_phrase=1.0,
                                     vertical_weight_piece=1.0,
                                     horizontal_weight_piece=0.3,
                                     mad_weight=0.0,
                                     verbose=False, verbose_threshold=None,
                                     candidate_max_no_improve=None,
                                     n_workers=1,
                                     build_chord_sa_func=None):
    """
    Apply Viterbi optimization hierarchically at phrase and piece levels.

    Optimizes in two stages:
    1. Phrase level: Strong horizontal constraints within musical phrases
    2. Piece level: Weaker constraints for global smoothing
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
    
    # Populate module-level state before forking so workers inherit it
    if n_workers > 1:
        _WORKER_STATE.update({
            'chord_scorer': chord_scorer,
            'low_number_ratios': low_number_ratios,
            'tonal_diamond': tonal_diamond,
            'tolerance': tolerance,
            'K': K,
            'rolls': rolls,
            'sa_iterations': sa_iterations,
            'initial_temperature': initial_temperature,
            'cooling_rate': cooling_rate,
            'ratio_factor': ratio_factor,
            'stability_factor': stability_factor,
            'spread': spread,
            'build_chord_sa_func': build_chord_sa_func,
            'candidate_max_no_improve': candidate_max_no_improve,
        })

    # Level 1: Optimize within phrases
    phrase_solutions = []
    phrase_paths = []

    for phrase_idx, (start, end) in enumerate(phrase_boundaries):
        logging.info(f'Phrase {phrase_idx+1}/{len(phrase_boundaries)}: '
                    f'chords {start}-{end-1}')
        
        phrase_indices = list(range(start, end))

        if n_workers > 1:
            base_seed = int(rng.integers(0, 2**31))
            tasks = [(i, cent_value_chorale[:, i].copy(), base_seed + i)
                     for i in phrase_indices]
            ctx = multiprocessing.get_context('fork')
            with multiprocessing.pool.Pool(processes=n_workers, context=ctx,
                                           initializer=_worker_log_reinit) as pool:
                results_list = pool.map(_parallel_candidate_worker, tasks)
            phrase_candidates = [cands for _, cands in sorted(results_list)]
        else:
            phrase_candidates = []
            prev_cents = np.zeros(4, dtype=int)
            for i in phrase_indices:
                candidates = generate_k_candidates(
                    cent_value_chorale[:, i], prev_cents, i,
                    chord_scorer, low_number_ratios, tonal_diamond,
                    tolerance=tolerance, K=K, rolls=rolls,
                    sa_iterations=sa_iterations,
                    initial_temperature=initial_temperature,
                    cooling_rate=cooling_rate, ratio_factor=ratio_factor,
                    stability_factor=stability_factor, spread=spread,
                    rng=rng, build_chord_sa_func=build_chord_sa_func,
                    candidate_max_no_improve=candidate_max_no_improve)
                phrase_candidates.append(candidates)
                if candidates:
                    prev_cents = candidates[0][0].copy()
        
        # High horizontal weight within phrases for consistency
        phrase_tuning, path, cost = viterbi_select_path(
            phrase_candidates, chorale[:, start:end],
            vertical_weight=vertical_weight_phrase,
            horizontal_weight=horizontal_weight_phrase,
            mad_weight=mad_weight,
            verbose=verbose, verbose_threshold=verbose_threshold)
        
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
    """Detect phrase boundaries in a chorale based on repeated chords (fermatas)."""
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
