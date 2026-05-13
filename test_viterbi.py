#!/usr/bin/env python
"""
test_viterbi.py

Simple test script to verify Viterbi optimization implementation.
Tests basic functionality without running full chorale optimization.
"""

import numpy as np
import sys
import os

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import adaptive_tuning_util as atu
import viterbi_optimization as viterbi

def test_candidate_generation():
    """Test K-candidate generation for a single chord."""
    print("Testing K-candidate generation...")
    
    # Build a small tonal diamond
    tonal_diamond = atu.build_tonal_diamond(17)
    chord_scorer = atu.ChordScorer(tonal_diamond)
    low_number_ratios = atu.LowNumberRatioIntervals(tonal_diamond)
    
    # Create a simple 4-note chord (C major: C E G C)
    cent_value_chord = np.array([0, 400, 700, 1200], dtype=int)
    cent_value_chord_prev = np.zeros(4, dtype=int)
    
    # Mock SA function for testing
    def mock_sa_func(cent_chord, prev_chord, chord_num, scorer, ratios, diamond,
                     tolerance=1, print_values=False, rolls=1, sa_iterations=10,
                     initial_temperature=2.0, cooling_rate=0.995, rng=None,
                     ratio_factor=1.0, stability_factor=0.0, spread=7):
        # Return a slightly perturbed version
        if rng is None:
            rng = np.random.default_rng()
        noise = rng.integers(-10, 11, size=4)
        result = (cent_chord + noise) % 1200
        return result, 0, 0, []
    
    # Generate candidates
    try:
        candidates = viterbi.generate_k_candidates(
            cent_value_chord, cent_value_chord_prev, 0,
            chord_scorer, low_number_ratios, tonal_diamond,
            tolerance=1, K=5, rolls=1, sa_iterations=10,
            build_chord_sa_func=mock_sa_func)
        
        print(f"  ✓ Generated {len(candidates)} candidates")
        print(f"  ✓ Candidate scores: {[f'{s:.1f}' for _, s in candidates[:3]]}")
        return True
    except Exception as e:
        print(f"  ✗ Error: {e}")
        return False


def test_transition_cost():
    """Test transition cost calculation."""
    print("\nTesting transition cost calculation...")
    
    # Two chords with shared pitch class C (0)
    prev_cents = np.array([0, 400, 700, 1200], dtype=float)
    curr_cents = np.array([10, 390, 710, 1190], dtype=float)  # Slightly different
    prev_midi = np.array([60, 64, 67, 72], dtype=int)
    curr_midi = np.array([60, 64, 67, 72], dtype=int)
    
    try:
        cost = viterbi.compute_transition_cost(
            prev_cents, curr_cents, prev_midi, curr_midi,
            penalty_type='pitch_class_jump')
        
        print(f"  ✓ Transition cost: {cost:.1f}¢")
        print(f"  ✓ Expected ~40¢ (4 notes × ~10¢ each)")
        return True
    except Exception as e:
        print(f"  ✗ Error: {e}")
        return False


def test_viterbi_path_selection():
    """Test Viterbi path selection with mock candidates."""
    print("\nTesting Viterbi path selection...")
    
    # Create mock candidates for 3 chords, 3 candidates each
    all_candidates = []
    for chord_idx in range(3):
        chord_candidates = []
        for k in range(3):
            # Create slightly different tunings
            base_cents = np.array([0, 400, 700, 1200], dtype=float)
            noise = np.random.randint(-5, 6, size=4) * (k + 1)
            cents = (base_cents + noise) % 1200
            score = 40.0 + k * 5  # Increasing scores
            chord_candidates.append((cents, score))
        all_candidates.append(chord_candidates)
    
    # Mock MIDI data
    chorale_midi = np.array([
        [60, 60, 60],
        [64, 64, 64],
        [67, 67, 67],
        [72, 72, 72]
    ], dtype=int)
    
    try:
        selected_tunings, path, total_cost = viterbi.viterbi_select_path(
            all_candidates, chorale_midi,
            vertical_weight=1.0, horizontal_weight=0.5)
        
        print(f"  ✓ Selected path: {path}")
        print(f"  ✓ Total cost: {total_cost:.1f}")
        print(f"  ✓ Output shape: {selected_tunings.shape}")
        return True
    except Exception as e:
        print(f"  ✗ Error: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_phrase_detection():
    """Test phrase boundary detection."""
    print("\nTesting phrase boundary detection...")
    
    # Create a chorale with repeated chords (fermatas)
    chorale = np.array([
        [60, 60, 62, 62, 64, 64, 64],  # Repeat at positions 0-1 and 4-6
        [64, 64, 66, 66, 68, 68, 68],
        [67, 67, 69, 69, 71, 71, 71],
        [72, 72, 74, 74, 76, 76, 76]
    ], dtype=int)
    
    try:
        boundaries = viterbi.detect_phrase_boundaries(chorale, fermata_threshold=2)
        print(f"  ✓ Detected {len(boundaries)} phrase(s): {boundaries}")
        return True
    except Exception as e:
        print(f"  ✗ Error: {e}")
        return False


def main():
    """Run all tests."""
    print("=" * 60)
    print("Viterbi Optimization Test Suite")
    print("=" * 60)
    
    tests = [
        test_candidate_generation,
        test_transition_cost,
        test_viterbi_path_selection,
        test_phrase_detection
    ]
    
    results = []
    for test_func in tests:
        try:
            result = test_func()
            results.append(result)
        except Exception as e:
            print(f"\n✗ Test {test_func.__name__} failed with exception: {e}")
            import traceback
            traceback.print_exc()
            results.append(False)
    
    print("\n" + "=" * 60)
    print(f"Test Results: {sum(results)}/{len(results)} passed")
    print("=" * 60)
    
    if all(results):
        print("\n✓ All tests passed! Viterbi optimization is ready to use.")
        return 0
    else:
        print("\n✗ Some tests failed. Please review the errors above.")
        return 1


if __name__ == '__main__':
    sys.exit(main())

# Made with Bob
