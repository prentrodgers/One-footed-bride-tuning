#!/usr/bin/env python
"""WreckingCrew_v2 plays the score note for note at the tuned pitches.

Run: .venv/bin/python test_wreckingcrew_v2.py   (no Csound needed: nothing is rendered)
"""
import collections
import logging
import os
import re
import sys
import types
import unittest

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
logging.disable(logging.CRITICAL)

import adaptive_tuning_util as atu  # noqa: E402
import WreckingCrew_v2 as wc2  # noqa: E402

ARGS = types.SimpleNamespace(legato=1.0, overlap_ms=30.0, glides=True, glide_slots=1, max_glide=45.0)
TEMPO = 60
MS = TEMPO / 60000.0                    # beats per millisecond


def held_end(r):
    """Beat at which a note's envelope starts to fade."""
    return r[1] + r[2] * wc2.RELEASE_AT[int(r[8])]
PIECES = ('bwv262', 'bwv846', 'bwv190.7-inst')   # 4 voices; keyboard in 6 rows; 15 rows with continuo


def synthetic_tuning(midi, seed=0, spread=20.0):
    """12-TET plus a different offset in every cell, so held notes move and need glides."""
    rng = np.random.default_rng(seed)
    return (midi % 12) * 100.0 + rng.uniform(-spread, spread, midi.shape)


def sounding_cents(r):
    """A note row's pitch in MIDI cents: p6 is in ball9.csd's numbering, an octave below MIDI."""
    return (r[5] + wc2.CSD_OCTAVE_OFFSET) * 1200 + r[4]


def struck_notes(stream):
    """Per part, the notes the score strikes, as (first slot, end slot, midi).

    Straight from the notes and their tie marks: a tie 'stop' or 'continue'
    lengthens the note of that pitch in the same voice that ends where it starts.
    """
    out = collections.defaultdict(list)
    for i, part in enumerate(stream.parts):
        open_notes = {}                         # (voice, midi) -> index into out[i] of the note it would extend
        items = []
        for n in part.recurse().notes:
            on = n.getOffsetInHierarchy(part)
            a, b = wc2._slot(on), wc2._slot(on + n.duration.quarterLength)
            voice = n.activeSite.id if n.activeSite.__class__.__name__ == 'Voice' else None
            for note in (n.notes if n.isChord else [n]):
                items.append((a, b, note.pitch.midi, voice, note.tie.type if note.tie else None))
        for a, b, midi, voice, tie in sorted(items):
            if b <= a:
                continue
            k = open_notes.get((voice, midi))
            if tie in ('stop', 'continue') and k is not None and out[i][k][1] == a:
                out[i][k] = (out[i][k][0], b, midi)
                continue
            out[i].append((a, b, midi))
            open_notes[(voice, midi)] = len(out[i]) - 1
    return out


class Piece:
    cache = {}

    @classmethod
    def get(cls, name, pedal=None):
        key = (name, pedal)
        if key not in cls.cache:
            stream = wc2.load_score(name)
            rows = wc2.rows_by_part(stream)
            midi = atu.stream_to_midi_array(name)[0]
            first = min(a for spans, _p, _i in rows for a, _b, _m in spans)
            parts = wc2.plan_parts(stream, {}, {}, pedal=pedal)
            tuning = synthetic_tuning(midi)
            glides = wc2.GlideTables()
            report = dict(glides=0, max_glide=0.0, wide_glides=0, out_of_range={})
            last = max(b for spans, _p, _i in rows for _a, b, _m in spans) - first
            bars = wc2.barlines(stream, first) + [last]
            notes = wc2.build_notes(rows, tuning, first, parts, ARGS, glides, report, tempo=TEMPO, bars=bars)
            cls.cache[key] = types.SimpleNamespace(stream=stream, rows=rows, midi=midi, first=first, parts=parts,
                                                    tuning=tuning, glides=glides, report=report, notes=notes,
                                                    bars=bars)
        return cls.cache[key]


class TestNoteForNote(unittest.TestCase):

    def test_rows_are_the_tuners(self):
        for name in PIECES:
            p = Piece.get(name)
            self.assertEqual(len(p.rows), p.midi.shape[0], name)

    def test_every_struck_note_once_per_player(self):
        """Same onsets and MIDI notes as the tied score; a two-player part plays each twice.

        Each is held past its written end: by --overlap_ms, or under the pedal to the barline.
        """
        for name, pedal in [(n, None) for n in PIECES] + [('bwv846', True)]:
            p = Piece.get(name, pedal)
            want, written = collections.Counter(), collections.defaultdict(list)
            for i, notes in struck_notes(p.stream).items():
                for a, b, m in notes:
                    want[(a - p.first, m)] += len(p.parts[i]['instruments'])
                    written[(a - p.first, m)].append((b - p.first) / 4.0)
            got = collections.Counter()
            for r in p.notes:
                a = int(round(r[1] * 4))
                midi = int(round(sounding_cents(r) / 100))   # within 20 cents of 12-TET here
                got[(a, midi)] += 1
                ends = written[(a, midi)]
                if p.parts[0]['pedal']:
                    self.assertTrue(any(held_end(r) >= e - 1.01 * MS for e in ends), (name, a, midi))
                else:
                    self.assertTrue(any(abs(held_end(r) - e - 30 * MS) < 1e-6 for e in ends), (name, a, midi))
            self.assertEqual(got, want, name)

    def test_legato_overlaps_the_next_note(self):
        """No gap: each note is still at full level 30 ms into the next one in its row."""
        p = Piece.get('bwv262')
        for v, (spans, _par, _i) in enumerate(p.rows):
            g = wc2.GlideTables()
            notes = wc2.build_notes([(spans, None, _i)], p.tuning[v:v + 1], p.first, p.parts, ARGS, g,
                                    dict(glides=0, max_glide=0.0, wide_glides=0, out_of_range={}))
            for x, y, (a0, b0, _m0), (a1, _b1, _m1) in zip(notes, notes[1:], spans, spans[1:]):
                if b0 == a1:
                    self.assertAlmostEqual(held_end(x) - y[1], 30 * MS)

    def test_pedal_holds_to_the_barline(self):
        """bwv846 --pedal: a note sounds until 1 ms before the barline after it, or until its key is struck again."""
        p = Piece.get('bwv846', pedal=True)
        self.assertTrue(all(x['pedal'] for x in p.parts))
        strikes = collections.defaultdict(list)
        for r in p.notes:
            strikes[int(round(sounding_cents(r) / 100))].append(r[1])
        at_bar = 0
        for r in p.notes:
            m = int(round(sounding_cents(r) / 100))
            end = held_end(r)
            if any(abs(end - (x / 4.0 - MS)) < 1e-6 for x in p.bars):
                at_bar += 1
                # no restrike of the key before the pedal comes up
                self.assertFalse([s for s in strikes[m] if r[1] + 1e-9 < s < end - MS], (r[1], m))
            else:
                again = min(s for s in strikes[m] if s > r[1] + 1e-9)
                self.assertAlmostEqual(end, again + 30 * MS)
        # Each measure plays its figure twice, so the first half's notes are struck again and
        # stop there; the second half's (and the held bass) ring to the barline.
        self.assertGreater(at_bar, len(p.notes) // 4)

    def test_pedal_is_an_option(self):
        """Off unless asked for; --pedal only reaches piano parts; --no-pedal beats the ensemble file."""
        stream = Piece.get('bwv846').stream
        self.assertFalse(any(x['pedal'] for x in wc2.plan_parts(stream, {}, {})))
        self.assertFalse(any(x['pedal'] for x in wc2.plan_parts(stream, {}, {}, pedal=False)))
        self.assertTrue(all(x['pedal'] for x in wc2.plan_parts(stream, {}, {}, pedal=True)))
        harpsichord = {name: 'harpsichord' for name, _ in wc2.part_names(stream)}
        self.assertFalse(any(x['pedal'] for x in wc2.plan_parts(stream, {}, harpsichord, pedal=True)))
        ens = {'parts': {'1': {'pedal': True}}}
        self.assertTrue(wc2.plan_parts(stream, ens, {})[0]['pedal'])
        self.assertFalse(wc2.plan_parts(stream, ens, {}, pedal=False)[0]['pedal'])
        quartet = wc2.plan_parts(Piece.get('bwv262').stream, {}, {}, pedal=True)
        self.assertFalse(any(x['pedal'] for x in quartet))       # strings: no pedal to press

    def test_doubled_parts_have_a_seat_each(self):
        """ensembles/bwv262-octet.yaml: winds in front, brass behind, each player panned by its own seat."""
        stream = Piece.get('bwv262').stream
        ens = wc2.load_ensemble('bwv262', os.path.join(wc2.ENSEMBLE_DIR, 'bwv262-octet.yaml'))
        parts = wc2.plan_parts(stream, ens, {})
        self.assertEqual([x['instruments'] for x in parts],
                         [['flute', 'bach trumpet'], ['oboe', 'trumpet in c'], ['clarinet', 'trombone'],
                          ['bassoon', 'tuba']])
        for x in parts:
            self.assertEqual(len(x['seats']), 2)
            self.assertLess(x['seats'][0][1], x['seats'][1][1])            # brass behind
            self.assertEqual(x['pans'], [8 + 8 * s[0] for s in x['seats']])
        self.assertEqual(wc2.INSTRUMENTS['bach trumpet'], wc2.INSTRUMENTS['trumpet'])
        rows = Piece.get('bwv262').rows
        notes = wc2.build_notes(rows, Piece.get('bwv262').tuning, Piece.get('bwv262').first, parts, ARGS,
                                wc2.GlideTables(), dict(glides=0, max_glide=0.0, wide_glides=0, out_of_range={}))
        self.assertEqual(len(notes), 2 * sum(len(s) for s, _p, _i in rows))
        self.assertEqual(sorted(set(notes[:, 6].astype(int))), [12, 13, 14, 15, 25, 26, 27, 39])
        with self.assertRaises(ValueError):
            wc2.plan_parts(stream, {'parts': {'Soprano': {'instrument': ['flute', 'tuba'], 'seat': [[0, 0]]}}}, {})

    def test_merge_adjacent(self):
        """Touching same-pitch notes in a voice become one note, struck once, gliding at the join."""
        for name in PIECES:
            p = Piece.get(name)
            merged = wc2.merge_adjacent(p.rows)
            self.assertEqual(len(merged), len(p.rows))
            joins = 0
            for (before, _a, i), (after, _b, j) in zip(p.rows, merged):
                self.assertEqual(i, j)
                cover = lambda spans: sorted((s, m) for a, b, m in spans for s in range(a, b))
                self.assertEqual(cover(before), cover(after), name)        # same slots sound, same pitches
                for (a0, b0, m0), (a1, _b1, m1) in zip(after, after[1:]):
                    self.assertFalse(b0 == a1 and m0 == m1, (name, a0, m0))
                joins += len(before) - len(after)
            self.assertGreater(joins, 0, name)
        # bwv262: build with the merged rows; each joined note glides where the second one began.
        p = Piece.get('bwv262')
        merged = wc2.merge_adjacent(p.rows)
        report = dict(glides=0, max_glide=0.0, wide_glides=0, out_of_range={})
        notes = wc2.build_notes(merged, p.tuning, p.first, p.parts, ARGS, wc2.GlideTables(), report)
        self.assertEqual(len(notes), sum(len(s) for s, _p, _i in merged))
        self.assertGreater(report['glides'], p.report['glides'])

    def test_cents_to_the_hundredth(self):
        rows = [([(0, 4, 60)], None, 0)]
        parts = [dict(name='Soprano', instruments=['flute'], seat=[0.0, 0.0], pans=[8.0], velocity=70, volume=5,
                      octave=0, pedal=False)]
        notes = wc2.build_notes(rows, np.array([[1199.996] * 4]), 0, parts, ARGS, wc2.GlideTables(),
                                dict(glides=0, max_glide=0.0, wide_glides=0, out_of_range={}))
        self.assertEqual((notes[0][4], notes[0][5]), (0.0, 4.0))    # rounds up to the next C, not to 1200
        notes = wc2.build_notes(rows, np.array([[3.86] * 4]), 0, parts, ARGS, wc2.GlideTables(),
                                dict(glides=0, max_glide=0.0, wide_glides=0, out_of_range={}))
        self.assertAlmostEqual(notes[0][4], 3.86)

    def test_repeated_notes_are_restruck(self):
        p = Piece.get('bwv262')
        restruck = sum(1 for spans, _p, _i in p.rows for x, y in zip(spans, spans[1:])
                       if x[1] == y[0] and x[2] == y[2])
        self.assertGreater(restruck, 20)        # 45 such notes merged in the old renderer

    def test_pitch_is_the_tuning_at_the_onset(self):
        for name in PIECES:
            p = Piece.get(name)
            onsets = {}
            for v, (spans, _par, _i) in enumerate(p.rows):
                for a, _b, m in spans:
                    onsets.setdefault((a - p.first, m), []).append(wc2.absolute_cents(p.tuning[v, a - p.first], m))
            for r in p.notes:
                a = int(round(r[1] * 4))
                cents = sounding_cents(r)
                m = int(round(cents / 100))
                self.assertLessEqual(abs(cents - m * 100), 21, name)
                self.assertTrue(any(abs(cents - c) <= 0.5 for c in onsets[(a, m)]), (name, a, m, cents))
                self.assertTrue(0 <= r[4] < 1200)

    def test_nothing_sounds_in_a_rest(self):
        for name in PIECES:
            p = Piece.get(name)
            sounding = atu.rest_map(name)
            for v, (spans, _par, _i) in enumerate(p.rows):
                for a, b, _m in spans:
                    self.assertTrue(sounding[v, a - p.first:b - p.first].all(), (name, v, a))

    def test_glides_follow_the_tuning(self):
        p = Piece.get('bwv846')
        self.assertGreater(p.report['glides'], 0)
        tables = {num: args for num, args in p.glides.tables.values()}
        for num, args in tables.items():
            vals = args.split()
            self.assertEqual(sum(int(x) for x in vals[1::2]), wc2.GLIDE_TABLE_SIZE, num)
        # Row by row (one player, notes in score order): a held note's multipliers start at its
        # tuned onset and end at the tuning of its last chord.
        checked = 0
        for v, row in enumerate(p.rows):
            g = wc2.GlideTables()
            notes = wc2.build_notes([row], p.tuning[v:v + 1], p.first, p.parts, ARGS, g,
                                    dict(glides=0, max_glide=0.0, wide_glides=0, out_of_range={}))
            shapes = {num: args.split() for num, args in g.tables.values()}
            self.assertEqual(len(notes), len(row[0]))
            for r, (a, b, m) in zip(notes, row[0]):
                pitch = wc2.absolute_cents(p.tuning[v, a - p.first:b - p.first], m)
                base = sounding_cents(r)
                if r[9] == 0:
                    self.assertTrue(np.all(np.abs(np.diff(pitch)) <= 0.5))
                    continue
                vals = shapes[int(r[9])]
                self.assertAlmostEqual(base + 1200 * np.log2(float(vals[0])), pitch[0], places=3)
                # Steps of half a cent or less are not glided, so the end can be that far off.
                self.assertAlmostEqual(base + 1200 * np.log2(float(vals[-1])), pitch[-1], delta=0.5)
                checked += 1
        self.assertGreater(checked, 10)

    def test_octave_is_ball9s_numbering(self):
        """ball9.csd's Bosendorfer table calls A0 (MIDI 21) note 9, so middle C (60) is p6 4."""
        rows = [([(0, 4, 60), (4, 8, 21)], None, 0)]
        tuning = np.array([[0.0] * 4 + [900.0] * 4])
        parts = [dict(name='Piano', instruments=['piano'], seat=[0.0, 0.0], pans=[8.0], velocity=70, volume=5, octave=0,
                      pedal=False)]
        report = dict(glides=0, max_glide=0.0, wide_glides=0, out_of_range={})
        notes = wc2.build_notes(rows, tuning, 0, parts, ARGS, wc2.GlideTables(), report)
        self.assertEqual([(int(r[5]), int(r[4])) for r in notes], [(4, 0), (0, 900)])
        self.assertEqual(round(notes[1][4] / 100) + 12 * notes[1][5], 9)   # ball9.csd's iMIDInumber for A0
        self.assertFalse(report['out_of_range'])

    def test_no_glides_holds_the_first_value(self):
        p = Piece.get('bwv846')
        args = types.SimpleNamespace(**dict(vars(ARGS), glides=False))
        glides = wc2.GlideTables()
        notes = wc2.build_notes(p.rows, p.tuning, p.first, p.parts, args, glides,
                                dict(glides=0, max_glide=0.0, wide_glides=0, out_of_range={}))
        self.assertFalse(glides.tables)
        self.assertTrue((notes[:, 9] == 0).all())


class TestEnsemble(unittest.TestCase):

    def test_chorale_is_a_string_quartet(self):
        p = Piece.get('bwv262')
        self.assertEqual([x['instruments'] for x in p.parts], [['violin'], ['violin'], ['viola'], ['cello']])
        pans = [wc2.pan_for(x['seat'][0], 0, 1) for x in p.parts]
        self.assertEqual(pans, sorted(pans))

    def test_keyboard_staves_share_a_seat(self):
        p = Piece.get('bwv846')
        self.assertEqual({tuple(x['seat']) for x in p.parts}, {(0.0, 0.0)})

    def test_continuo_is_keyboard_and_bass_string(self):
        p = Piece.get('bwv190.7-inst')
        cont = [x for x in p.parts if 'continuo' in x['name'].lower()]
        self.assertTrue(cont)
        self.assertEqual(cont[0]['instruments'], ['harpsichord', 'gamba'])

    def test_override_and_unknown_instrument(self):
        stream = Piece.get('bwv262').stream
        parts = wc2.plan_parts(stream, {'parts': {'Bass': {'instrument': 'bassoon', 'seat': [0.5, 1]}}},
                               {'Soprano': 'oboe', '2': 'flute'})
        self.assertEqual([x['instruments'][0] for x in parts], ['oboe', 'flute', 'viola', 'bassoon'])
        self.assertEqual(parts[3]['seat'], [0.5, 1.0])
        with self.assertRaises(ValueError):
            wc2.plan_parts(stream, {}, {'Soprano': 'kazoo'})


class TestNames(unittest.TestCase):

    def test_full_bwv_number(self):
        self.assertEqual(wc2.render_name('bwv244.10', 'a', (2, 1.5, 19), 125, 60), '244.10a_t2_d02_05_t060_lm19_r1.50')
        self.assertEqual(wc2.render_name('bwv1048', 'a', (2, 1.5, 19), 600, 80), '1048a_t2_d10_00_t080_lm19_r1.50')

    def test_make_score_videos_reads_it(self):
        """The track glob and tempo pattern make_score_videos.sh uses."""
        stem = 'b' + wc2.render_name('bwv244.10', 'a', (2, 1.5, 19), 125, 60) + '.mp3'
        self.assertTrue(stem.startswith('b' + 'bwv244.10'[3:] + 'a_'))
        m = re.search(r'_t([0-9]{3})_(ap[0-9]+_)?lm[0-9]+_r[0-9.]+\.mp3$', stem)
        self.assertEqual(m.group(1), '060')

    def test_score_name_keeps_decimal_chorales(self):
        self.assertEqual(atu.score_name('bwv245.14'), 'bwv245.14')
        self.assertEqual(atu.score_name('bwv244.62'), 'bwv244.62')
        self.assertEqual(atu.score_name('bwv262_t3_r1.500_lm19'), 'bwv262')
        a = atu.stream_to_midi_array('bwv244.62')[0]
        b = atu.assign_chorale('bwv244.62')[0]
        self.assertTrue(a.shape == b.shape and (a == b).all())


if __name__ == '__main__':
    unittest.main(verbosity=2)
