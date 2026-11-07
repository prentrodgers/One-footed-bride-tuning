#!/usr/bin/env python3
"""stream_to_midi_array must read the score by part, on the sixteenth grid.

For every column, each row must hold the MIDI number its voice is sounding at
that sixteenth (or, over a rest, the note it held before).  The greedy version
that dealt notes into rows regardless of voice passed only for chorales whose
four voices move in lockstep; bwv437, bwv432 and bwv424 are the ones that
caught it (rests, dotted rhythms, a silent first beat).

    python test_stream_to_midi_array.py
"""
import collections
import logging
import math
import os
import tempfile
from fractions import Fraction

import numpy as np
from music21 import corpus, meter, note, stream

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

# tuning_matches_score: a tuning made from the old greedy reader must be
# rejected even when it has the right number of columns (bwv432's did).
chorale, *_ = atu.stream_to_midi_array('bwv432')
twelve_tet = (chorale % 12) * 100.0
assert atu.tuning_matches_score(twelve_tet, chorale) == 1.0
assert atu.tuning_matches_score(twelve_tet + 50.0, chorale) == 1.0    # a quarter-tone chord still counts
assert atu.tuning_matches_score(twelve_tet + 60.0, chorale) < 1.0
rolled = np.roll(twelve_tet, 1, axis=1)                               # right length, wrong chords
assert 0.0 < atu.tuning_matches_score(rolled, chorale) < 1.0
assert atu.tuning_matches_score(twelve_tet[:, :-4], chorale) == 0.0   # wrong length
print('ok tuning_matches_score')

# The score sets the number of rows.  bwv846 has one right-hand line, two
# left-hand voices in one staff, and chords in its last bar.
chorale, *_ = atu.stream_to_midi_array('bwv846')
rows = atu.score_rows(corpus.parse('bach/bwv846'))
assert chorale.shape[0] == len(rows) >= 3, chorale.shape
assert chorale.shape[1] == 136 * 4, chorale.shape
assert (chorale > 0).all()
assert {60, 64} <= {int(m) for m in chorale[:, 0]}, chorale[:, 0]   # C4 and E4 sound in bar 1
# Bar 1's right hand reaches G4, C5 and E5 in one row: a line, not three voices.
assert {67, 72, 76} <= set(chorale[:, :16].flatten().tolist())
for v, (_spans, parent) in enumerate(rows):
    if parent is not None:                                          # divisi rows double their line
        assert (chorale[v, 0] == chorale[parent, 0]), (v, parent)
print(f'ok bwv846: {chorale.shape[0]} voices, {chorale.shape[1]} columns')

# A file in SCORES_DIR is read in place of the corpus, MIDI or MusicXML, with as
# many voices as it holds, and an unknown name still goes to the corpus.
saved_scores_dir = atu.SCORES_DIR
with tempfile.TemporaryDirectory() as atu.SCORES_DIR:
    assert atu.score_file('bwv1046test') is None
    score = stream.Score()
    pitches = [60, 64, 67, 72, 76, 79]
    for midi in pitches:
        part = stream.Part()
        part.append(meter.TimeSignature('4/4'))
        part.append(note.Note(midi, quarterLength=4.0))
        score.append(part)
    for suffix, fmt in (('.musicxml', 'musicxml'), ('.mid', 'midi')):
        name = f'bwv1046test{suffix[1:4]}'
        score.write(fmt, fp=os.path.join(atu.SCORES_DIR, name + suffix))
        chorale, root, mode, time_sig, _s = atu.stream_to_midi_array(name)
        assert chorale.shape == (6, 16), (suffix, chorale.shape)
        assert sorted(chorale[:, 0].tolist()) == pitches, (suffix, chorale[:, 0])
        cents, _top, *_rest = atu.load_chorale_in_cents(name, None)
        assert cents.shape == (6, 16), (suffix, cents.shape)
        assert atu.measure_columns(name)[0] == (1, 0, 16), (suffix, atu.measure_columns(name))
        print(f'ok {suffix} from SCORES_DIR: 6 voices')
    # A MIDI track has no voices: bwv846's left hand holds C while E is struck
    # a sixteenth later.  Read back from MIDI, every sixteenth must SOUND the
    # same notes as the corpus score (before overlapping notes were split into
    # rows, the held C was overwritten in every column).  Only sounding notes
    # are compared: what fills a silence differs by design (the corpus's second
    # left-hand voice holds its own note, a split-off MIDI row doubles the line).
    # Ties are merged first: music21's own MIDI round trip keeps only the first
    # note of a tie (bwv846's tied C2 pedal in bars 32-33 comes back half as
    # long), which is the writer's problem, not this reader's.
    corpus.parse('bach/bwv846').stripTies().write('midi', fp=os.path.join(atu.SCORES_DIR, 'wtc1c.mid'))

    def sounding(score):
        slots = collections.defaultdict(set)
        for spans, _parent in atu.score_rows(score):
            for a, b, midi in spans:
                for k in range(a, b):
                    slots[k].add(midi)
        return slots

    from_score = sounding(corpus.parse('bach/bwv846'))
    from_midi = sounding(atu.parse_score('wtc1c'))
    differ = [k for k in sorted(set(from_score) | set(from_midi)) if from_score[k] != from_midi[k]]
    assert not differ, (len(differ), differ[:5], from_midi[differ[0]], from_score[differ[0]])
    rows = len(atu.score_rows(atu.parse_score('wtc1c')))
    print(f'ok bwv846 from MIDI: {rows} rows, all {len(from_score)} sixteenths sound the corpus notes')
atu.SCORES_DIR = saved_scores_dir

# Twenty voices must not reach anything that enumerates their permutations.
midi = np.array([[48 + v] * 4 for v in range(20)])
assert atu.mismatch_check((midi % 12) * 100, midi) is False
assert atu.mismatch_check((midi[::-1] % 12) * 100, midi) is False   # the same notes, other voices
assert atu.mismatch_check(((midi + 1) % 12) * 100, midi) is True    # different notes
print('ok mismatch_check on 20 voices')
