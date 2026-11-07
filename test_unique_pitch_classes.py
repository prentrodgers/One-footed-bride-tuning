#!/usr/bin/env python3
"""Past four voices a chord is scored and tuned one note per pitch class.

C E G C scores C-E, C-G and E-G once each, doubled notes come out of the tuner
with one shared value, and a four-voice chorale keeps the every-pair rule.

    python test_unique_pitch_classes.py
"""
import logging

import numpy as np

import adaptive_tuning_util as atu
import chord_report
import Straw_man_tuning_v2 as smt
import viterbi_optimization as viterbi

logging.disable(logging.CRITICAL)
TOL = 3
diamond = atu.build_tonal_diamond(19)[:-1]

# The reduction keeps the first voice of each pitch class, in order.
reduced, inverse = atu.unique_pitch_class_chord(np.array([0, 400, 700, 0, 1100, 400]))
assert reduced.tolist() == [0, 400, 700, 1100], reduced
assert inverse.tolist() == [0, 1, 2, 0, 3, 1], inverse
assert (reduced[inverse] == [0, 400, 700, 0, 1100, 400]).all()

# Only the rule's own voice counts switch it on.
assert not atu.unique_pitch_classes_for(4)
assert atu.unique_pitch_classes_for(5) and atu.unique_pitch_classes_for(20)

# C E G C: the doubled C adds C-E and C-G again under the every-pair rule.
c_e_g_c = np.array([0, 386, 702, 0])
every_pair = atu.ChordScorer(diamond)
once = atu.ChordScorer(diamond, unique_pitch_classes=True)
triad = every_pair.score_chord(np.array([0, 386, 702]), tolerance=TOL)
assert once.score_chord(c_e_g_c, tolerance=TOL) == triad
assert every_pair.score_chord(c_e_g_c, tolerance=TOL) > triad
# Six voices of one triad score as the triad.
assert once.score_chord(np.array([0, 386, 702, 0, 386, 0]), tolerance=TOL) == triad
print('ok scoring: C E G C scores C-E, C-G, E-G once each')

# The chord report counts the same pairs the scorer scores.
assert len(list(chord_report.voice_pairs(c_e_g_c, False))) == 6
assert len(list(chord_report.voice_pairs(np.array([0, 386, 702, 0, 386, 0]), True))) == 3
print('ok chord_report pairs')

# The horizontal cost counts a doubled note's jump once.
prev, curr = np.array([0, 400, 700, 0, 0, 0]), np.array([10, 400, 700, 10, 10, 10])
midi = np.array([60, 64, 67, 48, 36, 72])
assert viterbi.compute_transition_cost(prev, curr, midi, midi) == 40
assert viterbi.compute_transition_cost(prev, curr, midi, midi, unique_pitch_classes=True) == 10
print('ok transition cost: one jump per pitch class')

# A six-row piece through the Viterbi tuner: doubled notes come out tied, every
# pitch class is kept, and the scores are the one-per-pitch-class scores.
chorale = np.array([
    [72, 72, 74, 76, 77, 76],
    [67, 67, 67, 67, 69, 67],
    [64, 64, 65, 64, 65, 64],
    [60, 60, 59, 60, 60, 60],
    [48, 48, 55, 48, 53, 48],
    [36, 36, 43, 36, 41, 36],
])
cents = (chorale % 12) * 100
lnr = atu.LowNumberRatioIntervals(diamond)
tuning, _paths, _path = viterbi.hierarchical_viterbi_optimization(
    chorale, cents, once, lnr, diamond, tolerance=TOL, K=4, rolls=2,
    sa_iterations=60, rng=np.random.default_rng(7),
    build_chord_sa_func=smt.build_straw_man_chord_sa)
assert tuning.shape == (chorale.shape[1], chorale.shape[0]), tuning.shape
assert atu.tuning_matches_score(tuning.T, chorale) == 1.0
for i, col in enumerate(chorale.T):
    for pc in set((col % 12).tolist()):
        values = tuning[i, col % 12 == pc]
        assert np.ptp(values) == 0, (i, pc, values)
print('ok six-row Viterbi: doubled notes tied, every chord plays the score')

# enforce_continuity's last resort forces a voice to the previous value; with
# doubles tied it must move every voice of that pitch class, not split them.
jumpy = np.array([[0, 400, 700, 0, 400, 0],
                  [45, 400, 745, 45, 400, 45]], dtype=float)   # C and G jump 45
two = np.array([[60, 64, 67, 48, 52, 36],                    # C E G C E C
                [72, 64, 67, 48, 52, 36]]).T                  # same pitch classes, new chord
fixed = smt.enforce_continuity(jumpy, two, once, lnr, diamond, TOL, rolls=1, sa_iterations=1,
                               initial_temperature=0.0, cooling_rate=1.0, ratio_factor=1.0,
                               rng=np.random.default_rng(1), max_gap=5, retune_on_gaps=0)
for pc in set((two[:, 1] % 12).tolist()):
    assert np.ptp(fixed[1, two[:, 1] % 12 == pc]) == 0, (pc, fixed[1])
print('ok enforce_continuity keeps doubles tied')
