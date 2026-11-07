#!/usr/bin/env python3
"""Rests are honored by default: a resting voice is left out of its chord.

The MIDI array keeps filling a rest with the note before it, so no later note
moves; sounding_mask says where the voice is really silent.  --hold_rests
(hold_rests=True) is the old reading, where every cell counts.

    python test_rests.py
"""
import logging
import math
from fractions import Fraction

import numpy as np
from music21 import corpus, note

import adaptive_tuning_util as atu
import Straw_man_tuning_v2 as smt
import viterbi_optimization as viterbi

logging.disable(logging.CRITICAL)
TOL = 3
diamond = atu.build_tonal_diamond(19)[:-1]


def score_grid(version):
    """(4, sixteenths) MIDI numbers straight from the parts, -1 where a part rests."""
    s = corpus.parse(f'bach/{version}')
    parts = [list(p.flatten().notesAndRests) for p in s.parts]
    total = max(n.offset + n.duration.quarterLength for p in parts for n in p)
    grid = -np.ones((4, math.ceil(total * 4)), dtype=int)
    for v, p in enumerate(parts):
        for n in p:
            if isinstance(n, note.Note):
                a = math.ceil(Fraction(n.offset).limit_denominator(64) * 4)
                b = math.ceil(Fraction(n.offset + n.duration.quarterLength).limit_denominator(64) * 4)
                grid[v, a:b] = n.pitch.midi
    anyone = (grid >= 0).any(axis=0)
    first, last = np.flatnonzero(anyone)[[0, -1]]
    return grid[:, first:last + 1]


# The mask is exactly where the parts have notes, and never moves a note.
for version in ['bwv437', 'bwv424', 'bwv262']:
    midi = atu.stream_to_midi_array(version)[0]
    mask = atu.sounding_mask(version)
    grid = score_grid(version)
    assert mask.shape == midi.shape == grid.shape, (version, mask.shape, midi.shape)
    assert (mask == (grid >= 0)).all(), version
    assert (midi[mask] == grid[mask]).all(), version
    assert atu.sounding_mask(version, hold_rests=True).all()
    print(f'ok {version}: {int((~mask).sum())} resting cells, every note in its own column')

# A resting voice takes no part in its chord's score.
scorer = atu.ChordScorer(diamond)
cents = np.array([[0, 0], [386, 386], [702, 702], [1100, 1100]], dtype=float)   # C E G B
rest_b = np.array([[True, True], [True, True], [True, True], [True, False]])
scores = atu.score_columns(scorer, cents, rest_b, TOL)
assert scores[1] == scorer.score_chord(np.array([0, 386, 702]), tolerance=TOL)
assert scores[0] == scorer.score_chord(cents[:, 0], tolerance=TOL) > scores[1]
assert (atu.score_columns(scorer, cents, None, TOL) == scores[0]).all()
print('ok score_columns: a resting voice is left out')

# Placeholders: a resting cell holds a sounding note's tuned value with its own
# MIDI note, so the array still plays the score.
midi = atu.stream_to_midi_array('bwv437')[0]
mask = atu.sounding_mask('bwv437')
tet = (midi % 12) * 100.0
holes = tet.copy()
holes[~mask] = np.nan
filled = atu.fill_rests(holes, midi, mask)
assert not np.isnan(filled).any()
assert atu.tuning_matches_score(filled, midi) == 1.0
assert (filled[mask] == tet[mask]).all()
print('ok fill_rests: placeholders play the score, sounding cells untouched')

# Through the Viterbi tuner: resting cells come back NaN, sounding ones tuned.
chorale = np.array([[72, 72, 74, 76], [67, 67, 67, 67], [64, 64, 65, 64], [48, 48, 43, 48]])
sounding = np.ones_like(chorale, dtype=bool)
sounding[0, 1:3] = False          # the soprano rests for two columns
cents0 = (chorale % 12) * 100
lnr = atu.LowNumberRatioIntervals(diamond)
tuning, _p, _pp = viterbi.hierarchical_viterbi_optimization(
    chorale, cents0, scorer, lnr, diamond, tolerance=TOL, K=3, rolls=2, sa_iterations=40,
    rng=np.random.default_rng(3), build_chord_sa_func=smt.build_straw_man_chord_sa,
    sounding=sounding)
assert np.isnan(tuning.T[~sounding]).all() and not np.isnan(tuning.T[sounding]).any()
filled = atu.fill_rests(tuning.T, chorale, sounding)
assert atu.tuning_matches_score(filled, chorale) == 1.0
fixed = smt.enforce_continuity(filled.T, chorale, scorer, lnr, diamond, TOL, rolls=1,
                               sa_iterations=5, initial_temperature=1.0, cooling_rate=0.99,
                               ratio_factor=1.0, rng=np.random.default_rng(1), max_gap=1,
                               retune_on_gaps=1, sounding=sounding)
assert (fixed.T[~sounding] == filled[~sounding]).all()     # resting cells untouched
print('ok Viterbi and continuity: resting voices left out, placeholders untouched')
