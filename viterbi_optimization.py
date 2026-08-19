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
    i, cent_col, seed, incumbent = args
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
        candidate_max_no_improve=s['candidate_max_no_improve'],
        incumbent=incumbent)
    return i, candidates


def polish_candidate(chord, chord_scorer, tolerance, radius=6, passes=3):
    """Nudge each voice a few cents to reach compromises an exact ratio chain cannot.

    SA builds a chord by writing exact diamond ratios pair by pair, so every interval
    it does not write directly is a *sum* of ratios and can land in a hole in the
    diamond.  bwv261 chord 2 (D G A E) is the clear case: a 4/3 D-G plus a 9/8 D-E
    leaves G-E at 294¢, and the lm17 diamond jumps 289 (13/11) to 316 (6/5), so that
    interval misses the tolerance window and takes the +1000 penalty (score 1079).
    SA therefore has to break a note by ~45¢ instead (E as 12/11, score 93).
    Moving G down 3¢ puts all six intervals inside a ±3¢ window at once — score 79,
    the tuning the June 2026 runs only reached by luck, when leftover SA perturbation
    noise happened to land there.

    Pitch classes are preserved: a voice is never moved outside its ±50¢ window.
    Returns (polished_chord, score).
    """
    best = np.asarray(chord, dtype=float).copy()
    best_score = chord_scorer.score_chord(best, tolerance=tolerance)
    pcs = [int(atu.pitch_class_from_cents(c)) for c in best]
    for _ in range(passes):
        improved = False
        for v in range(best.shape[0]):
            for delta in range(-radius, radius + 1):
                if delta == 0:
                    continue
                trial = best.copy()
                trial[v] = (best[v] + delta) % 1200
                if int(atu.pitch_class_from_cents(trial[v])) != pcs[v]:
                    continue
                score = chord_scorer.score_chord(trial, tolerance=tolerance)
                if score < best_score:
                    best_score, best, improved = score, trial, True
        if not improved:
            break
    return best, float(best_score)


def generate_k_candidates(cent_value_chord, cent_value_chord_prev, chord_num,
                         chord_scorer, low_number_ratios, tonal_diamond,
                         tolerance, K=10, rolls=4, sa_iterations=100,
                         initial_temperature=2.0, cooling_rate=0.995,
                         ratio_factor=1.0, stability_factor=0.0, spread=7,
                         rng=None, build_chord_sa_func=None,
                         candidate_max_no_improve=None,
                         max_duplicate_streak=5, incumbent=None):
    """
    Generate K diverse candidate tunings for a single chord.

    Uses different random seeds and temperature variations to explore
    the solution space and generate diverse high-quality candidates.

    When SA consistently converges to the same tuning (a strong local optimum),
    further attempts are wasteful.  ``max_duplicate_streak`` consecutive duplicate
    results trigger an early exit so those SA calls are skipped entirely.
    """
    if rng is None:
        rng = np.random.default_rng()
    
    if build_chord_sa_func is None:
        raise ValueError("build_chord_sa_func must be provided")
    
    candidates = []
    seen_tunings = set()  # Track unique tunings to avoid duplicates
    duplicate_streak = 0  # Consecutive attempts that produced only duplicates
    
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
        
        # Polish before de-duplication so near-identical SA results collapse to the
        # same key and the DP gets the compromise tunings on its menu.
        tuned_chord, score = polish_candidate(tuned_chord, chord_scorer, tolerance)

        # Create a hashable representation to check for duplicates
        tuning_key = tuple(np.round(tuned_chord, 1))  # Round to 0.1 cent

        if tuning_key not in seen_tunings:
            seen_tunings.add(tuning_key)
            duplicate_streak = 0
            candidates.append((tuned_chord.copy(), float(score)))
            
            if len(candidates) >= K:
                break
        else:
            duplicate_streak += 1
            if duplicate_streak >= max_duplicate_streak:
                logging.debug(
                    f'chord {chord_num}: stopping after {k+1} attempts '
                    f'({duplicate_streak} consecutive duplicates, '
                    f'{len(candidates)} unique candidates found)')
                break
    
    # Always offer the polished 12-TET chord as one candidate.  SA can only reach a
    # chord by chaining exact ratios, so where the diamond has a hole it never emits
    # the near-miss chord at all — it scores 1000+ mid-search and is rejected long
    # before anything could nudge it into the window.  Polishing the 12-TET start
    # instead reaches that compromise directly (bwv261 chord 2: 79 vs the 93 SA
    # settles for).  Everywhere else this candidate scores in the thousands and the
    # sort below drops it, so it costs one slot and a few hundred cached lookups.
    seed_chord, seed_score = polish_candidate(
        np.asarray(cent_value_chord, dtype=float), chord_scorer, tolerance)
    if tuple(np.round(seed_chord, 1)) not in seen_tunings:
        candidates.append((seed_chord, seed_score))

    # Sort by score (lower is better)
    candidates.sort(key=lambda x: x[1])
    chosen = candidates[:K]

    # The chord this cell already saved, offered unchanged and AFTER the trim so
    # the sort can never drop it.  With the previous tuning present at every chord
    # the trellis contains the previous path, so the DP's best path is at worst a
    # tie with it and the run can only move the piece forward.  Without this each
    # run rebuilt from 12-TET and had to beat the incumbent across the whole
    # chorale on one lucky draw — which is why 103 of 115 comparisons were
    # rejections.  It is offered unpolished on purpose: polishing each chord on its
    # own would change the cents and break the adjacency the saved path was chosen
    # for.  Costs one extra candidate slot.
    if incumbent is not None:
        inc = np.asarray(incumbent, dtype=float) % 1200.0
        if tuple(np.round(inc, 1)) not in {tuple(np.round(c, 1)) for c, _ in chosen}:
            chosen.append((inc, float(chord_scorer.score_chord(inc, tolerance=tolerance))))

    logging.info(f'chord {chord_num}: generated {len(chosen)} unique candidates '
                f'(scores: {[f"{s:.1f}" for _, s in chosen[:5]]}...)')

    return chosen


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


def _pc_preserving_shifts(cents, octave=1200.0, max_shift=50.0):
    """Every whole-chord integer offset that leaves all pitch classes unchanged.

    ``score_chord`` only looks at pairwise deltas, so transposing all voices by
    the same amount is free vertically — it moves only the horizontal and MAD
    terms.  The full legal range is offered rather than a targeted handful, and
    the DP picks with the complete objective.

    An earlier version proposed only the offsets that land each shared pitch
    class exactly on its previous value.  That averaged 0.86 candidates per
    transition out of ~78 legal ones, and never offered the compromise shift
    when two shared pitch classes pulled in different directions — which is
    where the stubborn 20-40¢ gaps lived.
    """
    pcs = atu.pitch_class_from_cents(cents)

    # Widest offset keeping every voice inside its ±49¢ pitch-class window.
    lo, hi = -int(max_shift), int(max_shift)
    for pc, cv in zip(pcs, cents):
        deviation = (float(cv) - pc * 100.0 + octave / 2) % octave - octave / 2
        lo = max(lo, int(np.ceil(-49.0 - deviation)))
        hi = min(hi, int(np.floor(49.0 - deviation)))

    variants = []
    for delta in range(lo, hi + 1):
        if delta == 0:
            continue
        shifted = np.mod(cents + delta, octave)
        if np.array_equal(atu.pitch_class_from_cents(shifted), pcs):
            variants.append(shifted)
    return variants


# A gap costs its size, plus a quadratic surcharge on whatever part of it sits
# above GAP_HINGE.  The linear term alone minimises the SUM of gaps, but the
# ratchet in Straw_man_tuning_v2 keeps a run on its WORST single gap, and
# listening agreed with the ratchet: t3_r1.625_lm19 (max 11, sum 44) beat
# t3_r1.375_lm19 (max 14, sum 32).  Summing alone, the DP will buy one 20¢ jump
# to save fifteen 1¢ ones and the ratchet then discards the whole run.  The
# surcharge makes one 20¢ gap cost more than two 10¢ gaps (45 vs 20 at weight
# 0.25), so the path search chases the same thing the keep/discard step does.
# GAP_HINGE is 10¢ because that is the threshold the ear settled on.
GAP_HINGE = 10.0
GAP_HINGE_WEIGHT = 0.25


def compute_transition_cost(prev_cents, curr_cents, prev_midi, curr_midi,
                           penalty_type='pitch_class_jump'):
    """
    Compute horizontal penalty for transitioning between two chords.

    Penalizes pitch-class jumps for shared notes between adjacent chords, with a
    quadratic surcharge above GAP_HINGE so that large jumps cannot be paid for by
    shaving small ones.
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
                if min_dist > GAP_HINGE:
                    total_penalty += GAP_HINGE_WEIGHT * (min_dist - GAP_HINGE) ** 2
    
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
                       mad_weight=0.0, verbose=False, verbose_threshold=None,
                       prev_chord_cents=None, prev_chord_midi=None):
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

    # Initialise first chord.  When this trellis is one phrase of a larger piece,
    # prev_chord_cents is the last chord of the previous phrase, so the seam gets
    # the same transposition treatment as any interior transition.
    # ponytail: the PC accumulator still restarts at each phrase; only matters
    # when mad_weight > 0, thread it through if global drift needs tighter control.
    empty_accum = np.zeros((12, 3), dtype=float)
    for k in range(len(all_candidates[0])):
        cent_vals, v_score = all_candidates[0][k]
        variants = [cent_vals]
        if prev_chord_cents is not None:
            variants += _pc_preserving_shifts(cent_vals)

        best_cost, best_cents = float('inf'), cent_vals
        for used_cents in variants:
            h_cost = 0.0
            if prev_chord_cents is not None:
                h_cost = compute_transition_cost(
                    prev_chord_cents, used_cents, prev_chord_midi,
                    chorale_midi[:, 0], penalty_type=penalty_type)
            cost = vertical_weight * v_score + horizontal_weight * h_cost
            if cost < best_cost:
                best_cost, best_cents = cost, used_cents

        dp[0][k] = (best_cost, -1, _update_pc_accum(empty_accum, best_cents), best_cents)

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

            # The raw candidate plus every pitch-class-preserving transposition.
            # Transposition costs nothing vertically, so it is a free knob for the
            # horizontal and MAD terms.  These depend only on the candidate, so
            # build them once here instead of once per predecessor.
            variants = [curr_cents] + _pc_preserving_shifts(curr_cents)

            for k_prev in range(K_prev):
                prev_cost, _, prev_accum, prev_used = dp[i-1][k_prev]

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
                                     mad_weight=0.0,
                                     verbose=False, verbose_threshold=None,
                                     candidate_max_no_improve=None,
                                     n_workers=1,
                                     build_chord_sa_func=None,
                                     incumbent=None):
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
    
    # Candidate generation is independent per chord, so with workers do the whole
    # piece in a single pool.  Creating a pool inside the phrase loop capped
    # parallelism at the phrase length — chorales average well under ten chords
    # per phrase, so most cores sat idle.
    all_candidates = None

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

        base_seed = int(rng.integers(0, 2**31))
        tasks = [(i, cent_value_chorale[:, i].copy(), base_seed + i,
                  None if incumbent is None else incumbent[i].copy())
                 for i in range(n_chords)]
        ctx = multiprocessing.get_context('fork')
        with multiprocessing.pool.Pool(processes=n_workers, context=ctx,
                                       initializer=_worker_log_reinit) as pool:
            results_list = pool.map(_parallel_candidate_worker, tasks)
        all_candidates = [cands for _, cands in sorted(results_list)]
        logging.info(f'Generated candidates for {n_chords} chords on {n_workers} workers')

    # Level 1: Optimize within phrases
    phrase_solutions = []
    phrase_paths = []
    prev_tail_cents = None      # last chord of the previous phrase
    prev_tail_midi = None

    for phrase_idx, (start, end) in enumerate(phrase_boundaries):
        logging.info(f'Phrase {phrase_idx+1}/{len(phrase_boundaries)}: '
                    f'chords {start}-{end-1}')
        
        phrase_indices = list(range(start, end))

        if all_candidates is not None:
            phrase_candidates = all_candidates[start:end]
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
                    candidate_max_no_improve=candidate_max_no_improve,
                    incumbent=None if incumbent is None else incumbent[i])
                phrase_candidates.append(candidates)
                if candidates:
                    prev_cents = candidates[0][0].copy()
        
        # High horizontal weight within phrases for consistency
        phrase_tuning, path, cost = viterbi_select_path(
            phrase_candidates, chorale[:, start:end],
            vertical_weight=vertical_weight_phrase,
            horizontal_weight=horizontal_weight_phrase,
            mad_weight=mad_weight,
            verbose=verbose, verbose_threshold=verbose_threshold,
            prev_chord_cents=prev_tail_cents, prev_chord_midi=prev_tail_midi)

        phrase_solutions.append(phrase_tuning)
        phrase_paths.append(path)
        if len(phrase_tuning):
            prev_tail_cents = phrase_tuning[-1]
            prev_tail_midi = chorale[:, end - 1]

        logging.info(f'Phrase {phrase_idx+1} optimized: cost={cost:.1f}, '
                    f'{len(path)} chords')
    
    # Concatenate phrase solutions
    if len(phrase_solutions) == 1:
        # Single phrase: return directly
        final_tuning = phrase_solutions[0]
        piece_path = phrase_paths[0]
    else:
        # Concatenation is the whole of the piece level: phrase seams are already
        # optimized inside the phrase pass, which receives the previous phrase's
        # tail as prev_chord_cents and scores it at horizontal_weight_phrase.  A
        # separate piece-level weight existed here once and was never read — it
        # looked like a knob for seam continuity while doing nothing at all.
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

def _self_check():
    """Assert the DP transposes a chord when doing so closes an adjacent gap."""
    chord_a = np.array([0.0, 400.0, 700.0, 1000.0])
    chord_b = np.array([20.0, 420.0, 720.0, 1020.0])   # same PCs, 20¢ sharp
    midi = np.array([[60, 60], [64, 64], [67, 67], [70, 70]])

    shifts = _pc_preserving_shifts(chord_b)
    assert any(np.allclose(s, chord_a) for s in shifts), shifts
    for s in shifts:
        assert np.array_equal(atu.pitch_class_from_cents(s),
                              atu.pitch_class_from_cents(chord_b)), s

    tunings, _, _ = viterbi_select_path(
        [[(chord_a, 10.0)], [(chord_b, 10.0)]], midi, horizontal_weight=0.5)
    assert np.allclose(tunings[1], chord_a), tunings[1]

    # A phrase seam gets the same treatment: chord 0 transposes toward the tail
    # of the previous phrase instead of being taken as-is.
    seam, _, _ = viterbi_select_path(
        [[(chord_b, 10.0)]], midi[:, :1], horizontal_weight=0.5,
        prev_chord_cents=chord_a, prev_chord_midi=midi[:, 0])
    assert np.allclose(seam[0], chord_a), seam[0]

    # A shift big enough to change a pitch class must never be offered.
    near_edge = np.array([45.0, 445.0, 745.0, 1045.0])
    for s in _pc_preserving_shifts(near_edge):
        assert np.array_equal(atu.pitch_class_from_cents(s),
                              atu.pitch_class_from_cents(near_edge)), s

    # polish_candidate must reach the compromise an exact ratio chain misses:
    # bwv261 chord 2, D-G 4/3 + D-E 9/8 leaves G-E at 294¢ (a hole in the lm17
    # diamond) and scores 1079; nudging G 3¢ flat scores 79.
    scorer = atu.ChordScorer(atu.build_tonal_diamond(17)[:-1])
    chain = np.array([209.0, 707.0, 911.0, 413.0])
    assert scorer.score_chord(chain, tolerance=3) > 1000
    polished, score = polish_candidate(chain, scorer, tolerance=3)
    assert score < 100, (polished, score)
    assert np.array_equal(atu.pitch_class_from_cents(polished),
                          atu.pitch_class_from_cents(chain)), polished
    print('viterbi_optimization self-check passed')


if __name__ == '__main__':
    _self_check()

# Made with Bob
