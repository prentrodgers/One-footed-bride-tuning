#!/usr/bin/env python
"""Check that the keep/discard ratchet keeps the tuning with the smaller jumps.

Run: python test_ratchet.py
"""
import os
import tempfile

import numpy as np

import adaptive_tuning_util as atu
from Straw_man_tuning_v2 import compute_gap_score, load_and_merge_previous

CHORD = np.array([0.0, 386.0, 702.0, 1088.0])


def _chorale(shift):
    """CHORD twice, the second copy transposed `shift` cents. Shape (4, 2).

    A whole-chord transposition costs nothing vertically — score_chord only sees
    pairwise deltas — so both tunings score identically and only the adjacent
    pitch-class jump separates them. That is the real case this term exists for.
    """
    return np.stack([CHORD, (CHORD + shift) % 1200], axis=1)


def main():
    smooth, jumpy = _chorale(2), _chorale(20)

    assert compute_gap_score(smooth) == 2, compute_gap_score(smooth)
    assert compute_gap_score(jumpy) == 20, compute_gap_score(jumpy)

    scorer = atu.ChordScorer(atu.build_tonal_diamond(17)[:-1])
    scores = np.array([scorer.score_chord(jumpy[:, i], tolerance=3) for i in range(2)])
    smooth_scores = np.array([scorer.score_chord(smooth[:, i], tolerance=3) for i in range(2)])
    assert np.array_equal(scores, smooth_scores), (scores, smooth_scores)

    with tempfile.TemporaryDirectory() as d:
        saved = os.path.join(d, 'prev-opt.npy')
        np.save(saved, smooth)                     # the lucky low-gap run, already on disk

        # Equal chord quality, 20¢ of jump against 2¢: the gap term must reject it.
        cents, _, improved = load_and_merge_previous(
            saved, jumpy.T, scores, scorer, tolerance=3,
            chorale=None, spread_weight=0.0, gap_weight=1.0)
        assert not improved, 'gap_weight=1 kept the jumpier tuning'
        assert compute_gap_score(cents.T) == 2, cents

        # With the term switched off the two tie on score and the new run wins,
        # which is how the good tuning used to get overwritten.
        _, _, improved = load_and_merge_previous(
            saved, jumpy.T, scores, scorer, tolerance=3,
            chorale=None, spread_weight=0.0, gap_weight=0.0)
        assert improved, 'gap_weight=0 should no longer consider the gap'

        # A wolf interval outranks any amount of adjacency. This candidate has a
        # perfect 0¢ jump but one chord with an out-of-diamond interval, which
        # averaged over the piece costs less than the gap term it saves.
        wolf = np.stack([CHORD, CHORD], axis=1).copy()
        wolf[2, :] = (CHORD[0] + 675.0) % 1200      # 27¢ flat fifth, both chords
        wolf_scores = np.array([scorer.score_chord(wolf[:, i], tolerance=3) for i in range(2)])
        assert wolf_scores.max() >= 1000, wolf_scores
        assert compute_gap_score(wolf) == 0, compute_gap_score(wolf)
        _, _, improved = load_and_merge_previous(
            saved, wolf.T, wolf_scores, scorer, tolerance=3,
            chorale=None, spread_weight=0.0, gap_weight=1.0)
        assert not improved, 'a wolf interval was accepted to buy a smaller jump'

    print('ratchet self-check passed')


if __name__ == '__main__':
    main()
