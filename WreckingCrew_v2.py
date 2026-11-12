#!/usr/bin/env python
"""
WreckingCrew_v2.py - play a tuned score note for note.

Each note Bach wrote is played once, at his rhythm, by the instrument of its
part, at the pitch the tuner gave it.  Nothing is added: no doubling, no
arpeggios, no chord masking, no repeats, no octave drop, no random timbre
or stereo.  WreckingCrew.py is untouched and still does all of that for the
chorale arrangements.  The one exception is a part the ensemble file gives two
or more players: every player after the first starts each note 0 to
--double_delay_ms (20) late, a new random delay for every note.  Two real players
never strike together, and without the delay the two sound as one.

    score  (music21 corpus or Scores/<name>.*)  -> notes: onset, length, MIDI number, row
    tuning (<numpy_dir>/<name>-opt.npy, voices x slots, cents per pitch class;
            slots are sixteenths unless the score has shorter notes: atu.slots_per_quarter)
                                                 -> each note's pitch, to 0.01 cent
    ensemble (ensembles/<name>.yaml, optional)   -> each part's instrument, seat, level

Notes come from the score's spans (atu.score_rows), not from runs of equal
cells in the tuning, so a note struck again at the same pitch is struck again
(8-28% of the notes in the chorales and bwv846), a rest is silent, and a tie
is one note.

A note held while the harmony moves under it can be given a different value in
the next chord.  It glides there at the chord change (over --glide_slots
sixteenths) through a GEN -7 table of frequency multipliers read across the
note, numbered from 5000 as in WreckingCrew.py.

Legato: ball9.csd's envelopes scale with the note (p3) and fade over its last
part (f293, e5, the last 12.5%), so a note played at its written length fades
out before the next one starts.  Each note is lengthened so that the fade
begins --overlap_ms after the written end, and the notes cross-fade.  Piano,
harpsichord and harp (f298, which fades over only its last 3%) instead get a
damper release of --release_ms (100) after that point, from a table of their own.

Sustain pedal (off unless asked for: --pedal for every piano part, or a part's
`pedal: true` in the ensemble file; --no-pedal overrides the file): the pedal goes
down at each barline and comes up 1 ms before the next one, so a note sounds
until the barline after its written end.  A key struck again in the same
measure stops the earlier sound, as the hammer does on a real piano.

--merge_adjacent puts back one thing WreckingCrew.py does: a note that starts
where the one before it in its voice ends, at the same pitch, is joined to it,
tied or not, and glides to its own tuned value at the chord change instead of
being struck again.  Everything else stays note for note.

Pitch is sent to Csound in hundredths of a cent (p5 1199.99 at most).
ball9.csd reads p5 with tablei, which interpolates its line f3 exactly.

Output: Uploads/b<number><letter>_t<tol>_d<mm_ss>_t<tempo>_lm<n>_r<ratio>.mp3
(b244.10a_..., b1048a_...; the full BWV number, so decimal chorales no longer
collide) and the same stem .npy: the 15 Csound p-fields of every note, the
array make_score_videos.sh and the Blender stage read.

    .venv/bin/python WreckingCrew_v2.py --chorale bwv262 --numpy_dir Archive/straw-man/t2_r1.50_lm19
    .venv/bin/python WreckingCrew_v2.py --chorale bwv846 --tempo 66 --instrument "Piano=harpsichord"
    .venv/bin/python WreckingCrew_v2.py --chorale bwv846 --tempo 66 --pedal       # Bosendorfer, pedalled
    .venv/bin/python WreckingCrew_v2.py --chorale bwv262 --merge_adjacent --letter m   # repeats held and glided
    .venv/bin/python WreckingCrew_v2.py --chorale bwv262 --list     # show the part -> instrument table only
"""
import argparse
import glob
import logging
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import types
from fractions import Fraction

import numpy as np

REPO = os.path.dirname(os.path.abspath(__file__))
if REPO not in sys.path:
    sys.path.insert(0, REPO)

import adaptive_tuning_util as atu  # noqa: E402

CSD_FILE = os.path.join(REPO, 'ball9.csd')
CSD_C_FILE = os.path.join(REPO, 'ball9c.csd')
TRIM_SCRIPT = os.path.join(REPO, 'trim.sh')
UPLOADS_DIR = os.path.join(REPO, 'Uploads')
ENSEMBLE_DIR = os.path.join(REPO, 'ensembles')
WAVE_DIR = os.environ.get('OFB_WAVE_DIR') or os.path.expanduser(os.path.join('~', 'Music', 'sflib'))  # Csound SFDIR
OUTPUT_CSD = 'new_output_v2.csd'      # in REPO; WreckingCrew.py writes new_output.csd
CSOUND_LOG = 'csound_v2.log'

# ball9.csd numbers notes an octave below standard MIDI: its sample tables call the
# Bosendorfer's A0 9 (MIDI 21) and the violin's G3 43 (MIDI 55), and it plays p6 octave
# and p5 cents as that note.  So a note's p6 is midi // 12 - 1.  WreckingCrew.py gets
# the same octave by taking one off in each part ("take down the octave by one").
CSD_OCTAVE_OFFSET = 1

# ball9.csd voices (table f1) used here: number -> (samples, lowest and highest recorded note,
# in ball9.csd's numbering: add 12 for MIDI).
# A note outside the range still plays, from the nearest sample, transposed; v2 reports it.
VOICES = {
    1: ('finger piano', 12, 72),
    4: ('cello pizzicato', 36, 74),
    8: ('harp', 13, 83),
    12: ('bassoon', 22, 52),
    13: ('Bb clarinet', 38, 74),
    14: ('flute, no vibrato', 48, 84),
    15: ('oboe', 46, 76),
    16: ('French horn', 26, 62),
    17: ('violin, vibrato', 44, 81),
    18: ('viola, vibrato', 37, 73),
    19: ('cello, vibrato', 25, 63),
    23: ('string ensemble', 39, 75),
    24: ('bass finger piano', 7, 62),
    25: ('trumpet in C', 42, 74),
    26: ('tenor trombone', 28, 58),
    27: ('tuba', 24, 55),
    29: ('Bosendorfer', 9, 96),     # 29-38 are velocity layers: ball9.csd picks the layer from p4
    39: ('Bach trumpet', 49, 77),
}

# Instruments a part can be given: name -> (csound voice, envelope p9, octave shift, stand-in note).
# Envelope 5 (f293) holds the sample to the end of the note with a short release; 0 (f298)
# is the same with the sharpest attack, for samples that decay by themselves.
INSTRUMENTS = {
    'violin': (17, 5, 0, None),
    'violino piccolo': (17, 5, 0, 'violin samples'),
    'viola': (18, 5, 0, None),
    'cello': (19, 5, 0, None),
    'gamba': (19, 5, 0, 'no viola da gamba samples: cello'),
    'double bass': (19, 5, 0, 'no double bass samples: cello at written pitch'),
    'oboe': (15, 5, 0, None),
    'flute': (14, 5, 0, None),
    'recorder': (14, 5, 0, 'no recorder samples: flute'),
    'clarinet': (13, 5, 0, None),
    'bassoon': (12, 5, 0, None),
    'horn': (16, 5, 0, None),
    'trumpet': (39, 5, 0, None),            # the Bach trumpet samples
    'bach trumpet': (39, 5, 0, None),
    'trumpet in c': (25, 5, 0, None),
    'trombone': (26, 5, 0, None),
    'tuba': (27, 5, 0, None),
    'strings': (23, 5, 0, None),
    'organ': (23, 5, 0, 'no organ samples: string ensemble'),
    'piano': (29, 0, 0, None),
    'harpsichord': (29, 0, 0, 'no harpsichord samples: Bosendorfer'),
    'harp': (8, 0, 0, None),
    'finger piano': (1, 0, 0, None),        # the tines decay by themselves, as the harp's strings do
    'bass finger piano': (24, 0, 0, None),
    'timpani': (4, 0, 0, 'no timpani samples: cello pizzicato'),
}
# What a part named this plays, first match wins (part name, then the score's instrument name).
# Continuo is two players, as Bach scored it: a keyboard and a bass string on the same line.
PART_KEYWORDS = [
    ('violino piccolo', ['violino piccolo']), ('violin', ['violin']), ('violino', ['violin']),
    ('viola da gamba', ['gamba']), ('gamba', ['gamba']), ('viola', ['viola']),
    ('violoncell', ['cello']), ('cello', ['cello']),
    ('violone', ['double bass']), ('contrabass', ['double bass']), ('double bass', ['double bass']),
    ('continuo', ['harpsichord', 'gamba']), ('cembalo', ['harpsichord']), ('harpsichord', ['harpsichord']),
    ('piano', ['piano']), ('organ', ['organ']), ('oboe', ['oboe']), ('hautbois', ['oboe']),
    ('flauto dolce', ['recorder']), ('recorder', ['recorder']), ('flute', ['flute']), ('traverso', ['flute']),
    ('clarinet', ['clarinet']), ('bassoon', ['bassoon']), ('fagott', ['bassoon']),
    ('horn', ['horn']), ('corno', ['horn']), ('trumpet', ['trumpet']), ('tromba', ['trumpet']),
    ('trombone', ['trombone']), ('tuba', ['tuba']), ('timpani', ['timpani']), ('harp', ['harp']),
    # Voices: the chorales' default ensemble is a string quartet.
    ('soprano', ['violin']), ('alto', ['violin']), ('tenor', ['viola']), ('bass', ['cello']),
]
DEFAULT_INSTRUMENT = 'strings'

TEMPOS = {                      # quarter notes per minute, when neither --tempo nor the ensemble file says
    'bwv846': 66,
}
DEFAULT_TEMPO = 60
VELOCITY = 70                   # ball9.csd works best at 60-80
LOUDNESS_BUDGET = 20.0          # sum of p15 over all players; trim.sh normalises the mix afterwards
GLIDE_TABLE_START = 5000        # above every sample table in ball9.csd, as in WreckingCrew.py
GLIDE_TABLE_SIZE = 1024         # GEN -7 points (+1 guard point)
TAIL_SECONDS = 4.0              # room for the last note's release and the reverb
# Where each envelope (p9) starts to fade, as a fraction of p3, from its ball9.csd table:
# f298 (e0) is 1 1 496 496 of 1024, then the release; f293 (e5) is 1 1 447 447.
RELEASE_AT = {0: 994 / 1024, 5: 896 / 1024}
OVERLAP_MS = 30.0               # a note sustains this far past the next note's start
# Struck instruments (envelope 0: piano, harpsichord, harp) fade like a damper falling:
# full level to the fade point, then down over RELEASE_MS, whatever the note's length.
# f298 itself fades over its last 3% of p3, 8 ms for a sixteenth at 66 BPM, while the
# Bosendorfer samples take 13-30 ms to speak, so the old note was cut off as the new one
# was still arriving.  Each such note gets its own table, numbered from ENV_TABLE_START
# by its fade point in 1024ths of p3; p9 = 298 - table, as ball9.csd reads p9.
RELEASE_MS = 100.0
FERMATA = 1.5                   # a final chord under a fermata is held this many times its written length
FINAL_RELEASE_MS = 1500.0       # the last notes die away over this, not the damper's RELEASE_MS
ENV_TABLE_START = 9000
ENV_TABLE_SIZE = 1024
PEDAL_LIFT_MS = 1.0             # the pedal comes up this long before the barline
CENT_PLACES = 2                 # p5 precision: hundredths of a cent


# --------------------------------------------------------------------------- score and tuning

def load_score(version):
    return atu.parse_score(atu.score_name(version))


def _slot(t, spq=4):
    """atu.score_rows's grid: spq slots per quarter (atu.slots_per_quarter, 4 = sixteenths)."""
    return atu.grid_slot(t, spq)


def tie_continuations(part, spq=4):
    """{(slot, midi)} of the notes in a part that continue a tie (tie 'stop' or 'continue').

    Read from each note's own tie mark (per chord note).  music21's stripTies
    is not used: in bwv846's last bars it ends the tied pedal C early and joins
    the C above it across a bar instead.
    """
    out = set()
    for n in part.recurse().notes:
        a = _slot(n.getOffsetInHierarchy(part), spq)
        for note in (n.notes if n.isChord else [n]):
            if note.tie is not None and note.tie.type in ('stop', 'continue'):
                out.add((a, note.pitch.midi))
    return out


def rows_by_part(stream, spq=None):
    """atu.score_rows, plus the part each row belongs to: [(spans, parent, part_index)].

    The rows are exactly the tuner's, on the same grid (the whole score's
    slots_per_quarter, not each part's).  score_rows reads each tied piece as a
    note of its own; here a span that continues the one before it at the same
    pitch, and that the score marks as the end of a tie, is joined to it, so a
    tie is one note.
    """
    spq = spq or atu.slots_per_quarter(stream)
    out = []
    for i, part in enumerate(stream.parts):
        base = len(out)
        tied = tie_continuations(part, spq)
        for spans, parent in atu.score_rows(types.SimpleNamespace(parts=[part]), spq):
            joined = []
            for a, b, midi in spans:
                if joined and joined[-1][1] == a and joined[-1][2] == midi and (a, midi) in tied:
                    joined[-1] = (joined[-1][0], b, midi)
                else:
                    joined.append((a, b, midi))
            out.append((joined, None if parent is None else parent + base, i))
    return out


def merge_adjacent(rows):
    """--merge_adjacent: join a note to the one before it in its row when it starts where
    that one ends at the same MIDI note, tied or not, as WreckingCrew.py does.

    The joined note is struck once and glides to each new tuned value at the chord
    change (build_notes reads the tuning across the whole span).  A different
    octave or a rest between them keeps them apart.
    """
    out = []
    for spans, parent, p in rows:
        joined = []
        for a, b, midi in spans:
            if joined and joined[-1][1] == a and joined[-1][2] == midi:
                joined[-1] = (joined[-1][0], b, midi)
            else:
                joined.append((a, b, midi))
        out.append((joined, parent, p))
    return out


def part_names(stream):
    names = []
    for i, part in enumerate(stream.parts):
        inst = part.getInstrument(returnDefault=False)
        names.append((part.partName or (inst.partName if inst else None) or f'Part {i + 1}',
                      (inst.instrumentName if inst else '') or ''))
    return names


def absolute_cents(tuned, midi):
    """Pitch in cents above MIDI 0 for a tuned pitch-class value and the score's MIDI note.

    The tuning holds cents within the octave (0-1200, 12-TET C = 0); the score
    says which octave.  The result is the tuned value nearest the written note.
    """
    return midi * 100.0 + ((np.asarray(tuned, dtype=float) - (midi % 12) * 100.0 + 600.0) % 1200.0 - 600.0)


def find_tuning(version, numpy_dir, partial):
    path = os.path.join(numpy_dir, f'{version}{partial}')
    if os.path.exists(path):
        return path
    for sfx in (partial, '-opt.npy', '-trans-sa-opt.npy'):
        hits = sorted(glob.glob(os.path.join(numpy_dir, f'{version}_t*_r*_lm*{sfx}')))
        if hits:
            return hits[0]
    raise FileNotFoundError(f'no tuning for {version} in {numpy_dir} ({partial})')


# Fixed temperaments, cents above C for C C# D Eb E F F# G G# A Bb B: every C# the same pitch
# wherever it falls, in every key, as on an organ tuned once.  Werckmeister's numbers as in
# WreckingCrew.txt (6/18/25), to the thousandth (Orgel-Probe, 1681/1698):
TEMPERAMENTS = {
    '12-TET': [0, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100],
    # I (III), "correct temperament": C-G, G-D, D-A and B-F# narrowed by 1/4 Pythagorean comma
    'werckmeister_I': [0, 90.225, 192.180, 294.135, 390.225, 498.045, 588.270, 696.090,
                       792.180, 888.270, 996.090, 1092.180],
    # II (IV): fifths narrowed by 1/3 comma
    'werckmeister_II': [0, 82.405, 196.090, 294.135, 392.180, 498.045, 588.270, 694.135,
                        784.360, 890.225, 1003.910, 1086.315],
    # III (V): 1/4 comma, distributed differently from I
    'werckmeister_III': [0, 96.090, 203.910, 300.000, 396.090, 503.910, 600.000, 701.955,
                         792.180, 900.000, 1001.955, 1098.045],
    # IV (VI), Septenarius: string lengths in 196ths
    'werckmeister_IV': [0, 91.700, 196.300, 298.000, 395.100, 498.000, 595.000, 698.200,
                        793.700, 893.300, 1000.000, 1097.300],
}


# The temperament as the render's file name gives it: b846fa_werck3_d01_54_t060.mp3
TEMPERAMENT_TAGS = {'12-TET': '12tet', 'werckmeister_I': 'werck1', 'werckmeister_II': 'werck2',
                    'werckmeister_III': 'werck3', 'werckmeister_IV': 'werck4'}


def temperament_tuning(name, midi):
    """A (voices, slots) tuning that plays every note of `midi` at its pitch class's value in TEMPERAMENTS[name]."""
    return np.asarray(TEMPERAMENTS[name], dtype=float)[np.asarray(midi, dtype=int) % 12]


def tuning_params(path):
    """tolerance, ratio_factor, limit_max from the tuning's directory or file name, else None."""
    m = re.search(r'(?:^|[/_])t(\d+)_r([\d.]+)_lm(\d+)', path or '')
    return (int(m.group(1)), float(m.group(2)), int(m.group(3))) if m else None


# --------------------------------------------------------------------------- ensemble

def load_ensemble(version, path=None):
    """The piece's ensemble file (ensembles/<version>.yaml), or {} when there is none.

        tempo: 66
        pedal_last_bars: 2             # when the pedal is on, the final 2 measures share one pedal
        parts:
          Piano:                       # part name as the score gives it, or its number from 1
            instrument: harpsichord    # or a list: [harpsichord, gamba]
            seat: [-0.4, 0.3]          # x: -1 the audience's left .. +1 their right; y: depth
                                       # or one per player: [[-0.4, 0.0], [-0.4, 0.5]]
            velocity: 70
            volume: 1.0                # balance against the other parts
            octave: 0                  # shift, for a part written an octave from where it sounds
            pedal: true                # sustain pedal, down at each barline (default off; --pedal / --no-pedal)
    """
    path = path or os.path.join(ENSEMBLE_DIR, f'{version}.yaml')
    if not os.path.exists(path):
        return {}
    import yaml
    with open(path) as f:
        return yaml.safe_load(f) or {}


def instruments_for(name, inst_name):
    text = f'{name} {inst_name}'.lower()
    for key, insts in PART_KEYWORDS:
        if key in text:
            return list(insts)
    return [DEFAULT_INSTRUMENT]


def plan_parts(stream, ensemble, overrides, pedal=None):
    """One entry per part: name, the instruments that play it, seat, velocity, volume, octave, pedal.

    pedal (--pedal / --no-pedal): None leaves it to the ensemble file's `pedal:`
    (off when absent); True puts it down for every part played on piano; False
    keeps it up everywhere, whatever the file says.
    """
    names = part_names(stream)
    conf = ensemble.get('parts') or {}
    # Default seats: one per distinct part name (a keyboard's two staves sit together),
    # spread across the stage in score order, the audience's left to right.
    distinct = list(dict.fromkeys(name for name, _ in names))
    parts = []
    for i, (name, inst_name) in enumerate(names):
        c = dict(conf.get(name) or conf.get(str(i + 1)) or conf.get(i + 1) or {})
        if name in overrides:
            c['instrument'] = overrides[name]
        elif str(i + 1) in overrides:
            c['instrument'] = overrides[str(i + 1)]
        insts = c.get('instrument') or instruments_for(name, inst_name)
        insts = [insts] if isinstance(insts, str) else list(insts)
        for inst in insts:
            if inst not in INSTRUMENTS:
                raise ValueError(f'part {name!r}: unknown instrument {inst!r}; known: {", ".join(sorted(INSTRUMENTS))}')
        n, j = len(distinct), distinct.index(name)
        x = -0.8 + 1.6 * j / (n - 1) if n > 1 else 0.0
        seat = c.get('seat') or [x, 0.0]
        if seat and isinstance(seat[0], (list, tuple)):
            # One seat per player: [[x, y], [x, y], ...], in the order of `instrument:`.
            if len(seat) != len(insts):
                raise ValueError(f'part {name!r}: {len(seat)} seats for {len(insts)} instruments')
            seats = [[float(s[0]), float(s[1])] for s in seat]
            pans = [pan_for(s[0], 0, 1) for s in seats]
        else:
            # One seat for the part: its players sit side by side there.
            seats = [[float(seat[0]), float(seat[1])]] * len(insts)
            pans = [pan_for(seats[0][0], k, len(insts)) for k in range(len(insts))]
        if pedal is None:
            down = bool(c.get('pedal', False))
        else:
            down = pedal and 'piano' in insts
        parts.append(dict(name=name, instruments=insts, seat=seats[0], seats=seats, pans=pans,
                          velocity=int(c.get('velocity', VELOCITY)), volume=float(c.get('volume', 1.0)),
                          octave=int(c.get('octave', 0)), pedal=down))
    return parts


def barlines(stream, first, spq=4):
    """Slots (from the first note) where measures start, from the first part."""
    if not stream.parts:
        return []
    return sorted({_slot(m.getOffsetInHierarchy(stream.parts[0]), spq) - first
                   for m in stream.parts[0].getElementsByClass('Measure')})


def pedal_changes(bars, last_bars=1):
    """Where the pedal is changed: every barline, except that the final last_bars
    measures share one pedal (bwv846: the last two ring together over the held C).

    bars: barline slots with the piece's end appended, as build_notes takes them.
    """
    n = int(last_bars or 1)
    if n <= 1 or len(bars) < 2:
        return list(bars)
    return bars[:max(len(bars) - n, 1)] + [bars[-1]]


def final_chord(stream, rows, first, spq=4):
    """(start, end) in beats of the piece's last chord, and whether the score marks it with
    a fermata (bwv846's last C major chord, a chorale's last chord)."""
    end = max(b for spans, _p, _i in rows for _a, b, _m in spans)
    start = max(a for spans, _p, _i in rows for a, b, _m in spans if b == end)
    fermata = False
    for part in stream.parts:
        for n in part.recurse().notes:
            on = _slot(n.getOffsetInHierarchy(part), spq)
            if on == start and any(type(e).__name__ == 'Fermata' for e in n.expressions):
                fermata = True
    return (start - first) / spq, (end - first) / spq, fermata


def ending_for(stream, rows, first, args, spq=4):
    """build_notes' `ending`: notes still sounding at the piece's end hold to the end of the
    final chord, lengthened by --fermata when the score marks one, then die away over
    --final_release_ms instead of the damper."""
    start, end, fermata = final_chord(stream, rows, first, spq)
    factor = getattr(args, 'fermata', FERMATA) if fermata else 1.0
    return dict(end=end, extra=(factor - 1.0) * (end - start), fermata=fermata,
                release_ms=getattr(args, 'final_release_ms', FINAL_RELEASE_MS))


def pan_for(seat_x, k, of):
    """ball9.csd p8 (0 = left, 16 = right) for a seat; players sharing a seat sit side by side."""
    x = seat_x + (k - (of - 1) / 2) * 0.06
    return float(np.clip(8.0 + 8.0 * x, 0.0, 16.0))


# --------------------------------------------------------------------------- notes

class GlideTables:
    """GEN -7 frequency-multiplier tables, one per distinct glide shape, numbered from 5000."""

    def __init__(self, start=GLIDE_TABLE_START):
        self.start = start
        self.tables = {}                      # key -> (number, GEN -7 argument string)

    def table_for(self, points):
        """points: [(position 0..1 of the note, multiplier)], holding between them is the caller's job."""
        args, prev = [], 0
        for pos, ratio in points:
            idx = int(round(pos * GLIDE_TABLE_SIZE))
            idx = min(max(idx, prev), GLIDE_TABLE_SIZE)
            if args:
                args.append(str(idx - prev))
            args.append(f'{ratio:.7f}')
            prev = idx
        if prev < GLIDE_TABLE_SIZE:
            args += [str(GLIDE_TABLE_SIZE - prev), args[-1]]
        # GEN07 wants every segment length > 0: drop zero-length ones (they repeat a value).
        clean = [args[0]]
        for length, value in zip(args[1::2], args[2::2]):
            if int(length) > 0:
                clean += [length, value]
        key = ' '.join(clean)
        if key not in self.tables:
            self.tables[key] = (self.start + len(self.tables), key)
        return self.tables[key][0]

    def lines(self):
        return [f'f{num} 0 {GLIDE_TABLE_SIZE + 1} -7 {args}' for num, args in self.tables.values()]


def damper_p9(index):
    """p9 for the damper envelope that holds to index/1024 of p3, then releases."""
    return 298 - (ENV_TABLE_START + index)


def fade_fraction(p9):
    """Where a note's envelope starts to fade, as a fraction of p3 (any p9 v2 writes)."""
    p9 = int(round(p9))
    if p9 in RELEASE_AT:
        return RELEASE_AT[p9]
    return (298 - p9 - ENV_TABLE_START) / ENV_TABLE_SIZE


def damper_tables(indexes):
    """f-statements for the damper envelopes in use: a 2-point attack as f298 has, full
    level to the fade point, then a falling curve (to .35, .1, 0) over the rest of p3."""
    lines = []
    for idx in sorted(indexes):
        rel = ENV_TABLE_SIZE - idx
        a = max(1, round(0.30 * rel))
        b = max(1, round(0.35 * rel))
        c = rel - a - b
        if c >= 1:
            fall = f'{a} 0.35 {b} 0.1 {c} 0'
        else:
            fall = f'{rel} 0'
        lines.append(f'f{ENV_TABLE_START + idx} 0 {ENV_TABLE_SIZE + 1} -7 0 2 1 {idx - 2} 1 {fall}')
    return lines


def sounding_end(start, written_end, part, midi, args, ms, bars, strikes, spq=4):
    """Beat at which a note's envelope starts to fade (the dampers fall, or the player lets go).

    Without pedal: --overlap_ms after the written end (scaled by --legato), so it
    overlaps the next note.  With pedal: 1 ms before the barline at or after the
    written end, but no later than just past the same key's next strike in the part.
    bars and strikes are slots, spq to a beat.
    """
    if not part['pedal'] or not bars:
        return start + (written_end - start) * args.legato + getattr(args, 'overlap_ms', OVERLAP_MS) * ms
    slot = written_end * spq
    bar = next((x for x in bars if x >= slot - 1e-9), bars[-1])
    end = max(bar / spq - PEDAL_LIFT_MS * ms, written_end - PEDAL_LIFT_MS * ms)
    again = next((s for s in strikes.get((part['name'], midi), ()) if s > start * spq + 1e-9), None)
    if again is not None and again / spq < end:
        end = again / spq + getattr(args, 'overlap_ms', OVERLAP_MS) * ms
    return end


def note_velocity(base, slot, downbeats, spread, rng, accent=None):
    """p4 for one note.  --accent: base + accent on the first beat of a measure (default
    spread / 2).  --velocity_random: every other note a random whole number from
    base - spread to base + spread - 1, held to no louder than a downbeat.

    p4 is decibels in ball9.csd (ampdb), so an accent of 1.5 is 1.5 dB.  Until 12 Nov 2026
    the accent was the whole spread (base + 3 at --velocity_random 3), too strong."""
    if accent is None:
        accent = spread / 2
    if slot in downbeats:
        return base + accent
    if not spread:
        return base
    return min(int(rng.integers(base - spread, base + spread)), base + accent)


def build_notes(rows, tuning, first, parts, args, glides, report, tempo=DEFAULT_TEMPO, bars=None,
                downbeats=None, ending=None, spq=4):
    """The (n, 15) p-field array, one row per note per player, sorted by start time.

    Columns as in WreckingCrew.py's features array (ball9.csd p1..p15):
    0 instr, 1 start (beats), 2 duration (beats), 3 velocity, 4 cents 0-1199.99, 5 octave,
    6 voice, 7 pan, 8 envelope, 9 glide table, 10 upsample, 11 right envelope, 12-13 more
    glides (unused), 14 volume.

    Column 2 is p3, the length Csound plays, envelope release included: longer than
    the written note (see sounding_end).  bars: barline slots, from barlines(),
    with the piece's end appended; needed only for pedalled parts.  spq: slots per
    beat of the rows and the tuning (atu.slots_per_quarter).
    """
    ms = tempo / 60000.0                                  # beats per millisecond
    glide_len = max(1, round(args.glide_slots * spq / 4))  # --glide_slots counts sixteenths
    players = sum(len(parts[p]['instruments']) for _s, _par, p in rows)
    level = LOUDNESS_BUDGET / max(players, 1)
    strikes = {}                                          # (part name, midi) -> onset slots, for re-struck keys
    for spans, _parent, p in rows:
        for a, _b, midi in spans:
            strikes.setdefault((parts[p]['name'], midi), []).append(a - first)
    for v in strikes.values():
        v.sort()
    spread = int(getattr(args, 'velocity_random', 0) or 0)
    accent = getattr(args, 'accent', None)
    rng = np.random.default_rng(getattr(args, 'seed', 0))
    # Its own stream, so turning the delays on or off leaves --velocity_random's draws alone.
    delay_max = float(getattr(args, 'double_delay_ms', 0) or 0) * ms
    delay_rng = np.random.default_rng([getattr(args, 'seed', 0), 1])
    downbeats = set(downbeats if downbeats is not None else (bars or ()))
    notes = []
    for v, (spans, _parent, p) in enumerate(rows):
        part = parts[p]
        for k, inst in enumerate(part['instruments']):
            voice, env, inst_oct, _note = INSTRUMENTS[inst]
            lo, hi = VOICES[voice][1:]
            pan = part['pans'][k]
            shift = 1200 * (part['octave'] + inst_oct)
            for a, b, midi in spans:
                c0, c1 = a - first, b - first
                pitch = absolute_cents(tuning[v, c0:c1], midi) + shift
                start = c0 / spq
                end = sounding_end(start, c1 / spq, part, midi, args, ms, bars, strikes, spq)
                p9 = env
                release_ms = getattr(args, 'release_ms', RELEASE_MS)
                if ending and end >= ending['end'] - 2 * PEDAL_LIFT_MS * ms:
                    # Still sounding at the end of the piece: hold through the fermata, then die away.
                    end = max(end, ending['end']) + ending['extra']
                    release_ms = ending['release_ms']
                if env == 0 and release_ms > 0:
                    # Fade point on the 1024ths grid, p3 chosen so it falls exactly at `end`.
                    held = end - start
                    idx = int(round(ENV_TABLE_SIZE * held / (held + release_ms * ms)))
                    idx = min(max(idx, 3), ENV_TABLE_SIZE - 1)
                    dur = held * ENV_TABLE_SIZE / idx
                    p9 = damper_p9(idx)
                else:
                    dur = (end - start) / RELEASE_AT.get(env, 1.0)
                p0 = round(float(pitch[0]), CENT_PLACES)
                octave, cents = divmod(p0, 1200.0)
                octave, cents = int(octave) - CSD_OCTAVE_OFFSET, round(cents, CENT_PLACES)
                table = 0
                moves = np.flatnonzero(np.abs(np.diff(pitch)) > 0.5) + 1 if args.glides else []
                if len(moves):
                    # Hold, glide over --glide_slots at each chord change, hold: as multipliers of the
                    # written start pitch, so the table also carries the start's sub-cent remainder.
                    pts = [(0.0, 2 ** ((pitch[0] - p0) / 1200))]
                    for j, m in enumerate(moves):
                        nxt = moves[j + 1] if j + 1 < len(moves) else len(pitch)
                        end = min(m + glide_len, nxt)
                        pts.append((m / spq / dur, pts[-1][1]))
                        pts.append((end / spq / dur, 2 ** ((pitch[m] - p0) / 1200)))
                        step = abs(pitch[m] - pitch[m - 1])
                        report['glides'] += 1
                        report['max_glide'] = max(report['max_glide'], step)
                        if step > args.max_glide:
                            report['wide_glides'] += 1
                    table = glides.table_for(pts)
                written = (midi * 100 + shift) / 100 - 12 * CSD_OCTAVE_OFFSET   # in ball9.csd's numbering
                if not lo - 2 <= written <= hi + 2:
                    report['out_of_range'].setdefault(f"{part['name']} ({inst})", [lo, hi, 0])[2] += 1
                vel = note_velocity(part['velocity'], c0, downbeats, spread, rng, accent)
                if k > 0 and delay_max > 0:
                    # A doubling player: the whole note a little late, a new delay every note.
                    start += delay_rng.uniform(0.0, delay_max)
                    report['delayed'] = report.get('delayed', 0) + 1
                notes.append([1, start, dur, vel, cents, octave, voice, pan, p9, table,
                              0, p9, 0, 0, part['volume'] * level])
    notes.sort(key=lambda r: (r[1], r[6], -r[5], -r[4]))
    return np.array(notes, dtype=float)


# --------------------------------------------------------------------------- Csound

def load_orchestra():
    """ball9.csd up to its score's notes: options, orchestra and the f tables (as dmu.load_csd)."""
    keep = []
    with open(CSD_FILE) as f:
        for line in f:
            if line.startswith(('f0', '</CsScore', '</CsoundS', 'i', 't')):
                continue
            keep.append(line)
    return ''.join(keep)


def write_csd(notes, glides, tempo, path):
    with open(path, 'w') as f:
        f.write(load_orchestra())
        f.write('\n; WreckingCrew_v2: glide tables\n')
        for line in glides.lines():
            f.write(line + '\n')
        dampers = {298 - int(round(p)) - ENV_TABLE_START for p in notes[:, 8] if int(round(p)) not in RELEASE_AT}
        if dampers:
            f.write('; WreckingCrew_v2: damper envelopes (p9 = 298 - table)\n')
            for line in damper_tables(dampers):
                f.write(line + '\n')
        f.write(f't0 {tempo}\n')
        f.write(';Inst\tSta\tHold\tVel\tTon\tOct\tVoi\tSte\tEn1\tGls\tUps\tRen\t2gl\t3gl\tVol\n')
        for r in notes:
            f.write('i ' + '\t'.join(
                f'{r[i]:.5f}' if i in (1, 2, 7, 14) else f'{r[i]:.{CENT_PLACES}f}' if i == 4
                else str(int(round(r[i]))) for i in range(15)) + '\n')
        f.write('</CsScore>\n</CsoundSynthesizer>\n')


def run_csound(csd):
    env = dict(os.environ, SFDIR=WAVE_DIR)
    r = subprocess.run(['csound', csd, f'-O{CSOUND_LOG}'], cwd=REPO, env=env)
    subprocess.run(['grep', '-E', 'invalid|replacing|range|error|cannot|overall', CSOUND_LOG], cwd=REPO)
    return r.returncode


def convolve_and_publish(stem, seconds, mp3=True):
    """trim.sh (alcorcon reverb, trim silence, normalise, mp3 to Uploads) on a temp copy of ball9c.csd."""
    with tempfile.TemporaryDirectory() as tmp:
        with open(CSD_C_FILE) as f:
            text = f.read().replace('@replaceme@', f'{seconds:.1f}')
        with open(os.path.join(tmp, 'ball9c.csd'), 'w') as f:
            f.write(text)
        cmd = ['sh', TRIM_SCRIPT, 'ball9', stem, tmp] + ([UPLOADS_DIR] if mp3 else [])
        return subprocess.run(cmd, cwd=REPO).returncode


def mm_ss(seconds):
    m, s = divmod(int(round(seconds)), 60)
    return f'{m:02}_{s:02}'


def render_name(version, letter, params, seconds, tempo, tag=None):
    number = version[3:] if version.lower().startswith('bwv') else version
    name = f'{number}{letter}'
    if tag:                                   # a temperament: 846fa_werck3_d01_54_t060
        name += f'_{tag}'
    if params:
        tol, ratio, lm = params
        name += f'_t{tol}_d{mm_ss(seconds)}_t{tempo:03}_lm{lm}_r{ratio:.2f}'
    else:
        name += f'_d{mm_ss(seconds)}_t{tempo:03}'
    return atu.windows_compliant_filename(name)


# --------------------------------------------------------------------------- main

BOSENDORFER_LAYERS = [25, 31, 39, 47, 63, 78, 85, 99, 113, 127]   # recorded velocity of voices 29-38


def bosendorfer_layer(p4):
    """The recorded velocity of the Bosendorfer layer ball9.csd plays for p4 (its lines 43-47)."""
    vel = min(max(p4, 50), 90)
    return BOSENDORFER_LAYERS[min(int(29 + max(vel - 60, 0) / 2 + 0.5), 38) - 29]


def print_plan(parts, rows):
    counts = {}
    for _s, _par, p in rows:
        counts[p] = counts.get(p, 0) + 1
    print(f'{"part":24} rows  {"instrument":22} voice  pan   note')
    for i, part in enumerate(parts):
        for k, inst in enumerate(part['instruments']):
            voice, _env, _oct, note = INSTRUMENTS[inst]
            if voice == 29:
                layer = f'p4 {part["velocity"]}: the velocity-{bosendorfer_layer(part["velocity"])} recordings'
                note = f'{note}; {layer}' if note else layer
            print(f'{part["name"] if k == 0 else "":24} {counts.get(i, 0) if k == 0 else "":>4}  {inst:22} '
                  f'{voice:>5} {part["pans"][k]:5.1f}  {note or ""}')


def render(args):
    version = args.chorale
    stream = load_score(version)
    spq = atu.slots_per_quarter(stream)
    rows = rows_by_part(stream, spq)
    if not rows:
        raise SystemExit(f'{version}: the score has no pitched notes')
    first = min(a for spans, _p, _i in rows for a, _b, _m in spans)
    ensemble = load_ensemble(version, args.ensemble)
    overrides = dict(o.split('=', 1) for o in args.instrument)
    parts = plan_parts(stream, ensemble, overrides, pedal=args.pedal)
    if getattr(args, 'velocity', None) is not None:
        for part in parts:
            part['velocity'] = args.velocity
    grid = {4: 'sixteenths', 8: '32nds', 16: '64ths', 12: 'sixteenth triplets'}.get(spq, f'1/{spq} beats')
    print(f'{version}: {len(stream.parts)} parts, {len(rows)} rows, on a grid of {grid}')
    print_plan(parts, rows)
    if args.list:
        return None

    midi = atu.stream_to_midi_array(atu.score_name(version))[0]
    temperament = getattr(args, 'temperament', None)
    if temperament:
        tuning_path = None
        tuning = temperament_tuning(temperament, midi)
        print(f'tuning: {temperament}, ' + ' '.join(
            f'{n}{c:g}' for n, c in zip(('C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'G#', 'A', 'Bb', 'B'),
                                        TEMPERAMENTS[temperament])))
    else:
        tuning_path = find_tuning(version, args.numpy_dir, args.cent_file_partial)
        tuning = np.load(tuning_path)
        if tuning.shape != midi.shape:
            raise SystemExit(f'{tuning_path}: shape {tuning.shape}, but the score reads as {midi.shape}')
        match = atu.tuning_matches_score(tuning, midi)
        if match < 1.0 and not args.force:
            raise SystemExit(f'{tuning_path} plays only {match:.0%} of the score\'s chords; --force to render anyway')
        print(f'tuning {tuning_path} ({atu.rests_mode_from_sidecar(tuning_path)} rests in the tuner)')

    tempo = int(args.tempo or ensemble.get('tempo') or TEMPOS.get(version, DEFAULT_TEMPO))
    glides = GlideTables()
    report = dict(glides=0, max_glide=0.0, wide_glides=0, out_of_range={})
    last = max(b for spans, _p, _i in rows for _a, b, _m in spans) - first
    downbeats = barlines(stream, first, spq)
    bars = downbeats + [last]
    last_bars =args.pedal_last_bars or ensemble.get('pedal_last_bars') or 1
    bars = pedal_changes(bars, last_bars)
    score_notes = sum(len(spans) for spans, _p, _i in rows)
    if args.merge_adjacent:
        rows = merge_adjacent(rows)
        merged = score_notes - sum(len(spans) for spans, _p, _i in rows)
        print(f'merge_adjacent: {merged} of {score_notes} score notes joined to the note before them')
        score_notes -= merged
    ending = ending_for(stream, rows, first, args, spq)
    notes = build_notes(rows, tuning, first, parts, args, glides, report, tempo=tempo, bars=bars,
                        downbeats=downbeats, ending=ending, spq=spq)
    struck = any(INSTRUMENTS[i][1] == 0 for x in parts for i in x['instruments'])
    print(f'ending: the last chord {"has a fermata, held %gx, " % args.fermata if ending["fermata"] else ""}'
          f'sounds to beat {ending["end"] + ending["extra"]:g}'
          + (f', then dies away over {ending["release_ms"]:g} ms' if struck else ''))
    accent = args.velocity_random / 2 if args.accent is None else args.accent
    if args.velocity_random or accent:
        vels, counts = np.unique(notes[:, 3], return_counts=True)
        piano = any(INSTRUMENTS[i][0] == 29 for x in parts for i in x['instruments'])
        print(f'velocity: +-{args.velocity_random} (seed {args.seed}), downbeats +{accent:g}: ' + ', '.join(
            f'{v:g}x{n}' + (f' (vel-{bosendorfer_layer(v)})' if piano else '') for v, n in zip(vels, counts)))
    pedalled = [x['name'] for x in parts if x['pedal']]
    if pedalled:
        held = f'; the last {last_bars} measures under one pedal' if int(last_bars) > 1 else ''
        print(f'sustain pedal: {", ".join(dict.fromkeys(pedalled))}, changed at {len(bars) - 1} barlines{held}')
    beats = float((notes[:, 1] + notes[:, 2]).max())
    seconds = beats * 60.0 / tempo
    print(f'{score_notes} score notes -> {len(notes)} Csound notes ({len(notes) - score_notes} by continuo '
          f'and other parts with two players), {beats:g} beats at {tempo} BPM = {mm_ss(seconds).replace("_", ":")}')
    if report.get('delayed'):
        print(f'doubling: {report["delayed"]} notes of the second and later players delayed 0-'
              f'{args.double_delay_ms:g} ms at random (--double_delay_ms)')
    print(f'glides: {report["glides"]} at chord changes in held notes, widest {report["max_glide"]:.1f} cents, '
          f'{report["wide_glides"]} over {args.max_glide:g}; {len(glides.tables)} tables')
    for who, (lo, hi, n) in report['out_of_range'].items():
        print(f'  {who}: {n} notes outside its samples (MIDI {lo + 12 * CSD_OCTAVE_OFFSET}-'
              f'{hi + 12 * CSD_OCTAVE_OFFSET}), played from the nearest sample')

    stem = render_name(version, args.letter, tuning_params(tuning_path), seconds + TAIL_SECONDS, tempo,
                       tag=TEMPERAMENT_TAGS.get(temperament))
    csd = os.path.join(REPO, OUTPUT_CSD)
    write_csd(notes, glides, tempo, csd)
    print(f'wrote {csd}: b{stem}')
    if args.notes_out:
        np.save(args.notes_out, notes)
    if args.no_csound:
        return notes
    if run_csound(OUTPUT_CSD) != 0:
        raise SystemExit('csound failed; see ' + os.path.join(REPO, CSOUND_LOG))
    if args.no_convolve:
        return notes
    if convolve_and_publish(stem, seconds + TAIL_SECONDS, mp3=not args.no_mp3) != 0:
        raise SystemExit('trim.sh failed')
    if not args.no_mp3:
        os.makedirs(UPLOADS_DIR, exist_ok=True)
        np.save(os.path.join(UPLOADS_DIR, f'b{stem}.npy'), notes)
        print(f'Uploads/b{stem}.mp3 and .npy')
    return notes


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--chorale', required=True, help='score name: a corpus work (bwv244.10) or Scores/<name>.*')
    ap.add_argument('--numpy_dir', default='Archive/straw-man/best-tunings', help='where the tuning is')
    ap.add_argument('--cent_file_partial', default='-opt.npy', help='tuning file suffix after the name')
    ap.add_argument('--temperament', choices=sorted(TEMPERAMENTS), default=None,
                    help='play in a fixed temperament instead of a tuning file (no --numpy_dir needed)')
    ap.add_argument('--tempo', type=int, default=None, help='quarter notes per minute')
    ap.add_argument('--letter', default='a', help='render-set letter in the file name (b262a_...)')
    ap.add_argument('--ensemble', default=None, help='ensemble YAML (default ensembles/<chorale>.yaml)')
    ap.add_argument('--instrument', action='append', default=[], metavar='PART=INSTRUMENT',
                    help='give a part (by name or number from 1) an instrument; repeatable')
    ap.add_argument('--legato', type=float, default=1.0,
                    help='held length / written length, before the overlap (pedalled parts ignore it)')
    ap.add_argument('--overlap_ms', type=float, default=OVERLAP_MS,
                    help='a note holds this long past the next one\'s start before it fades (default %(default)g)')
    ap.add_argument('--pedal', action=argparse.BooleanOptionalAction, default=None,
                    help='sustain pedal for piano parts, down at each barline; --no-pedal overrides the '
                         'ensemble file. Default: off, unless the ensemble file gives a part pedal: true')
    ap.add_argument('--pedal_last_bars', type=int, default=None,
                    help='the final N measures share one pedal (default: the ensemble file\'s '
                         'pedal_last_bars, else 1: a change at every barline)')
    ap.add_argument('--release_ms', type=float, default=RELEASE_MS,
                    help='piano, harpsichord, harp: the damper falls over this long after the overlap '
                         '(default %(default)g; 0 = ball9.csd\'s f298, which fades over the last 3%% of the note)')
    ap.add_argument('--fermata', type=float, default=FERMATA,
                    help='hold a final chord marked with a fermata this many times its written length; the '
                         'pedal stays down through it (default %(default)g; 1 = as written)')
    ap.add_argument('--final_release_ms', type=float, default=FINAL_RELEASE_MS,
                    help='the notes sounding at the end die away over this long (default %(default)g)')
    ap.add_argument('--velocity', type=int, default=None,
                    help='p4 for every part, over the ensemble file (default %d). The Bosendorfer picks its '
                         'recording from it: 60 or less -> the velocity-25 layer, 64 -> 39, 66 -> 47, 68 -> 63, '
                         '70 -> 78, 72 -> 85, 74 -> 99, 76 -> 113, 78+ -> 127' % VELOCITY)
    ap.add_argument('--velocity_random', type=int, default=0, metavar='N',
                    help='vary p4 around each part\'s velocity: a random value from base-N to base+N-1, '
                         'never above a downbeat (default 0: every note at base)')
    ap.add_argument('--accent', type=float, default=None, metavar='A',
                    help='the first note of every measure at base+A; p4 is dB, so A=1.5 is 1.5 dB louder '
                         '(default half of --velocity_random, 0 without it). Works without --velocity_random')
    ap.add_argument('--double_delay_ms', type=float, default=20.0, metavar='MAX',
                    help='in a part with two or more players, every player after the first starts each note '
                         'a random 0 to MAX ms late, drawn anew for every note, so the doubling is heard as '
                         'two players (default %(default)g; 0 = all players strike together)')
    ap.add_argument('--seed', type=int, default=0,
                    help='random seed for --velocity_random and --double_delay_ms, so a render can be '
                         'repeated (default %(default)s)')
    ap.add_argument('--merge_adjacent', action='store_true',
                    help='join a note to the one before it in its voice when they are the same pitch and '
                         'touch, tied or not (as WreckingCrew.py); the joined note glides to the new tuning')
    ap.add_argument('--glides', action=argparse.BooleanOptionalAction, default=True,
                    help='glide a held note to its new value at a chord change (--no-glides holds the first)')
    ap.add_argument('--glide_slots', type=int, default=1, help='glide length in sixteenths')
    ap.add_argument('--max_glide', type=float, default=45.0, help='report glides wider than this (cents)')
    ap.add_argument('--force', action='store_true', help='render a tuning that does not match the score')
    ap.add_argument('--list', action='store_true', help='print the part -> instrument table and stop')
    ap.add_argument('--no_csound', action='store_true', help='write the .csd only')
    ap.add_argument('--no_convolve', action='store_true', help='stop after the dry Csound render')
    ap.add_argument('--no_mp3', action='store_true', help='convolve but leave the wav in ~/Music/sflib')
    ap.add_argument('--notes_out', default=None, help='also save the note array here')
    args = ap.parse_args(argv)
    if not os.path.isabs(args.numpy_dir):
        args.numpy_dir = os.path.join(REPO, args.numpy_dir) if not os.path.isdir(args.numpy_dir) else args.numpy_dir
    logging.basicConfig(level=logging.WARNING)
    render(args)


if __name__ == '__main__':
    main()
