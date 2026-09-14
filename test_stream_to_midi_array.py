#!/usr/bin/env python3
"""stream_to_midi_array must read the score by part, on the sixteenth grid.

For every column, each row must hold the MIDI number its voice is sounding at
that sixteenth (or, over a rest, the note it held before).  The greedy version
that dealt notes into rows regardless of voice passed only for chorales whose
four voices move in lockstep; bwv437, bwv432 and bwv424 are the ones that
caught it (rests, dotted rhythms, a silent first beat).

    python test_stream_to_midi_array.py
"""
import logging
import math
from fractions import Fraction

import numpy as np
from music21 import corpus, note

import adaptive_tuning_util as atu

logging.disable(logging.CRITICAL)


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


for version in ['bwv262', 'bwv437', 'bwv432', 'bwv424']:
    chorale, *_ = atu.stream_to_midi_array(version)
    grid = score_grid(version)
    assert chorale.shape == grid.shape, (version, chorale.shape, grid.shape)
    sounding = grid >= 0
    assert (chorale[sounding] == grid[sounding]).all(), version
    # a leading rest takes the voice's first note, any other rest the previous column
    for v in range(4):
        row, ref = chorale[v], grid[v]
        for k in np.flatnonzero(ref < 0):
            expect = row[k - 1] if k > 0 else ref[np.flatnonzero(ref >= 0)[0]]
            assert row[k] == expect, (version, v, k)
    print(f'ok {version}: {chorale.shape[1]} columns, every sounding note in its own row')

bars = atu.measure_columns('bwv424')          # a silent first beat: bar 1 is 12 columns
assert bars[0] == (1, 0, 12), bars[0]
assert bars[1] == (2, 12, 28), bars[1]
bars = atu.measure_columns('bwv262')          # starts on the downbeat
assert bars[0] == (1, 0, 16), bars[0]
chorale, *_ = atu.stream_to_midi_array('bwv262')
assert bars[-1][2] == chorale.shape[1], (bars[-1], chorale.shape)
print('ok measure_columns')
