#!/usr/bin/env python3
"""Spring tuning: an experiment for contrapuntal music (19 Nov 2026).

Straw_man_tuning_v2 tunes each chord to its best ratios and then looks for transpositions that keep
the lines steady.  That works for chorales.  In a fugue the result has whole steps anywhere from 119
to 267 cents and a pitch class wandering 90 cents over the piece, and the ear follows the lines.

This turns the order round.  It starts from a temperament, where every line is already right, and
lets the chords pull the notes toward just intervals only as far as the lines allow.  Every note
gets ONE pitch (a held note never moves), found in a single least-squares solve from three kinds
of spring:

  anchor    each note toward its pitch in the reference temperament (--reference, vrwt)
  melody    each step of a line toward the size it has in the reference (--melody), and the same
            pitch class heard again within a bar or so toward the same pitch (--memory)
  harmony   each pair of notes sounding together toward the just interval (octave, 3/2, 4/3, 5/4,
            6/5, 8/5, 5/3), in proportion to how long they sound together (--harmony).  Seconds,
            sevenths and tritones have no spring: a passing note is placed by its line.
  limit     (--limit, 40) no note may end more than this many cents from its equal-tempered pitch,
            so a note is never nearer its neighbour than itself.  A note that the chords pull past
            the limit has its anchor stiffened and the whole piece is solved again, until none is.
  pace      the harmony and anchor pulls grow with a note's length and the melody pulls do not,
            so the same --harmony would pull a piece in half notes far harder than one in eighths.
            Lengths are therefore measured against the piece's own ordinary note (--pace auto, the
            default since 19 Nov), and a slow fugue gets the treatment a quick one does.  --pace off
            measures every piece against an eighth, as the first arrays of 19 Nov were made.
  seventh   (--septimal) where the notes sounding are a major triad with its minor seventh, the chord
            is pulled to 4:5:6:7, the seventh 7/4 above the root (G B D F: F 969 cents above G).
            Where they are a minor triad with its major sixth, the mirror image, 1/(4:5:6:7): the
            sixth 12/7 above the root (F Ab C D: D 933 above F).  That chord is Bach's half-diminished
            seventh, D F Ab C.  Every pair in such a chord takes its size from the chord, so the
            seventh's 7/6 and 7/5 to its neighbours replace the 6/5 it would otherwise be pulled to.

  diamond   (--diamond 15, 20 Nov) in place of the fixed table above, every ratio of the tonality
            diamond with identities (N+1)/2 to N (diamond_music_utils.build_all_ratios) is a target, so
            seconds, sevenths and tritones get springs too.  A ratio's spring is as strong as
            ((n+d)/5)^-p (--exponent p, 2): 3/2 is 1, 5/4 0.31, 7/4 0.21, 16/15 0.03, 1/1 6.25.
            Springs on one pair of notes would only average, so each pair chooses ONE ratio: the
            deepest well where the pair now stands, a well being its strength times
            exp(-(cents away / --width)^2 / 2).  The piece is solved, every pair chooses again, and so
            on until none changes its mind.  The seventh-chord rule is not used: 7/4, 7/5 and 12/7
            compete like the rest.  Only ratios within --limit of their 12-TET size are offered.

  fold      (--fold, the default since 20 Nov) notes of the same pitch class sounding together share
            one pitch, in any octave or voice, and so does any chain of such overlaps (a held bass G
            and the G's that sound over it): the octave folding of Straw_man_tuning_v2, done in the
            solve.  The shared pitch is solved with every spring on every note of the group, so no
            note "wins".  --no-fold gives each note its own pitch, as the arrays of 19 Nov were made.

--harmony 0 gives the reference temperament exactly.  Raising it buys purer thirds and fifths and
pays in less even steps; the report line shows both, so the dial can be set by ear with the numbers
beside it.  The idea is John deLaubenfels's (vertical, horizontal and grounding springs, tuning list
c. 2000); Stange, Wick and Hinrichsen, Computer Music Journal 2018, solve the same kind of system.

    spring_tuning.py --chorale bwv846f --sweep                      # the trade-off, nothing written
    spring_tuning.py --chorale bwv846f --harmony 2 --out_dir Archive/spring/h2
    WreckingCrew_v2.py --chorale bwv846f --numpy_dir Archive/spring/h2 --letter s --tempo 58
"""
import argparse
import math
import os
import warnings

import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.linalg import lsqr

warnings.filterwarnings('ignore')
import adaptive_tuning_util as atu          # noqa: E402
import WreckingCrew_v2 as wc                # noqa: E402

# Just intervals in cents by size in semitones within the octave; the rest have no spring.
JUST = {0: 0.0, 3: 315.641, 4: 386.314, 5: 498.045, 7: 701.955, 8: 813.686, 9: 884.359}
HARMONY_WEIGHT = {0: 2.0, 3: 1.0, 4: 1.0, 5: 1.0, 7: 1.0, 8: 1.0, 9: 1.0}
# Chords of the seventh harmonic, by semitones above the root: (name, cents above the root for
# each member, the members that must sound for the chord to be read, the member that is the 7).
# The fifth of 4:5:6:7 may be missing, as it often is in four parts.  The minor chord needs all
# four: without its fifth it is a diminished triad, which could as well be the top of a 4:5:6:7.
SEVENTH_CHORDS = (
    ('4:5:6:7', {0: 0.0, 4: 386.314, 7: 701.955, 10: 968.826}, (0, 4, 10), 10),
    ('1/(4:5:6:7)', {0: 0.0, 3: 315.641, 7: 701.955, 9: 933.129}, (0, 3, 7, 9), 9),
)
PACE_REFERENCE = 0.5         # the ordinary note of bwv846f, in quarters: what the dials were set by ear on
LIMIT_ROUNDS = 40            # how many times the anchors of notes past --limit are stiffened
MEMORY_QUARTERS = 4.0        # the same pitch class is tied to itself this far back
MEMORY_DECAY = 2.0           # ... with a weight that falls by e every this many quarters
STEP_GAP = 1.0               # two notes of a line are a step when at most this many quarters apart
DIAMOND_ROUNDS = 40          # how many times the pairs may choose their ratios again


def diamond_targets(odd_limit, exponent=2.0, limit=40.0):
    """The tonality diamond as spring targets: {semitones: [(cents from the 12-TET size, strength, 'n/d')]},
    each ratio reduced to the octave and filed under the step it is nearest, those further than `limit`
    from it left out.  Strength ((n+d)/5)^-exponent, so 3/2 is 1."""
    from fractions import Fraction
    import diamond_music_utils as dmu
    seen = set()
    for r in dmu.build_all_ratios(limit_value=odd_limit):
        f = Fraction(r).limit_denominator(1000)
        while f >= 2:
            f /= 2
        while f < 1:
            f *= 2
        seen.add(f)
    out = {}
    for f in sorted(seen):
        cents = 1200.0 * math.log2(f)
        size = int(round(cents / 100.0))
        off = cents - 100.0 * size
        if limit is None or abs(off) <= limit:
            out.setdefault(size % 12, []).append((off, ((f.numerator + f.denominator) / 5.0) ** -exponent,
                                                  f'{f.numerator}/{f.denominator}'))
    return out


def choose(candidates, offset, width):
    """The ratio whose well is deepest at this interval (cents from its 12-TET size): its index."""
    depth = [w * math.exp(-0.5 * ((offset - t) / width) ** 2) for t, w, _r in candidates]
    return int(np.argmax(depth))


def load(name):
    stream = wc.load_score(name)
    spq = atu.slots_per_quarter(stream)
    rows = wc.rows_by_part(stream, spq)
    first = min(a for spans, _p, _i in rows for a, _b, _m in spans)
    midi = atu.stream_to_midi_array(atu.score_name(name))[0]
    notes = [(v, a - first, b - first, m) for v, (spans, _p, _i) in enumerate(rows) for a, b, m in spans]
    return dict(name=name, spq=spq, midi=np.asarray(midi, dtype=int), notes=notes)


def reference_offsets(reference):
    """Cents from 12-TET for each pitch class in the reference temperament."""
    return np.asarray(wc.TEMPERAMENTS[reference], dtype=float) - 100.0 * np.arange(12)


def seventh_chord(pcs):
    """The seventh chord these pitch classes spell: (name, {pitch class: cents above the root}, the 7), or None."""
    for name, members, needed, seven in SEVENTH_CHORDS:
        for root in sorted(pcs):
            if all((root + k) % 12 in pcs for k in needed):
                return name, {(root + k) % 12: c for k, c in members.items()}, (root + seven) % 12
    return None


def segments(score):
    """Stretches over which the same notes sound: [(note numbers, first slot, slots)]."""
    slots = score['midi'].shape[1]
    on = [[] for _ in range(slots)]
    for i, (_v, a, b, _m) in enumerate(score['notes']):
        for c in range(a, b):
            on[c].append(i)
    out = []
    for c, now in enumerate(on):
        if out and out[-1][0] == now and out[-1][1] + out[-1][2] == c:
            out[-1][2] += 1
        else:
            out.append([now, c, 1])
    return out


def pair_target(mlo, mhi, chord):
    """(cents from the 12-TET size, weight, is it a seventh-chord spring) for two notes sounding together, or None."""
    size = (mhi - mlo) % 12
    if chord and mlo % 12 in chord[1] and mhi % 12 in chord[1]:
        cents = (chord[1][mhi % 12] - chord[1][mlo % 12]) % 1200.0
        septimal = chord[2] in (mlo % 12, mhi % 12) and size != 0
        return (cents - 100.0 * size + 600.0) % 1200.0 - 600.0, None if septimal else HARMONY_WEIGHT.get(size, 1.0), septimal
    if size in JUST:
        return JUST[size] - 100.0 * size, HARMONY_WEIGHT[size], False
    return None


def fold_groups(score):
    """One pitch variable for each set of same-pitch-class notes that sound together (chained through
    any overlap): a group number for every note, numbered 0.. in note order."""
    notes = score['notes']
    parent = list(range(len(notes)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for now, _c, _length in segments(score):
        first = {}
        for i in now:
            pc = notes[i][3] % 12
            if pc in first:
                parent[find(i)] = find(first[pc])
            else:
                first[pc] = i
    roots = [find(i) for i in range(len(notes))]
    number = {}
    return np.array([number.setdefault(r, len(number)) for r in roots], int)


def ordinary_note(score):
    """The piece's ordinary note length in quarters: half its sounding time is in notes this long or longer."""
    d = np.sort(np.array([(b - a) / score['spq'] for _v, a, b, _m in score['notes']]))
    return float(d[np.searchsorted(np.cumsum(d) / d.sum(), 0.5)])


def solve(score, reference='vrwt', harmony=2.0, melody=1.0, memory=1.0, anchor=1.0, septimal=1.0, limit=40.0,
          pace=None, diamond=None, width=15.0, fold=True):
    """One offset from 12-TET per note, in cents, none further than `limit`.  score['held'] counts
    the notes whose anchors had to be stiffened to keep them inside it.  With `diamond` (from
    diamond_targets) the pairs choose their ratios, and score['chosen'] has {ratio: quarters} by size.
    With `fold`, same-pitch-class notes sounding together share one pitch (fold_groups); score['folded']
    counts the notes that joined another."""
    notes, spq = score['notes'], score['spq']
    ref = reference_offsets(reference)
    if limit is not None and limit <= np.abs(ref).max():
        raise SystemExit(f'--limit {limit:g} is inside the {reference} temperament itself '
                         f'(its furthest note is {np.abs(ref).max():.1f} cents from 12-TET)')
    n = len(notes)
    group = fold_groups(score) if fold else np.arange(n)
    score['folded'] = int(n - (group.max() + 1)) if n else 0
    ri, ci, val, rhs = [], [], [], []
    # --pace: lengths count in the piece's ordinary notes.  Twice as slow a piece has its harmony
    # and anchor pulls halved and remembers a pitch class for twice as many quarters.
    slow = (pace / PACE_REFERENCE) if pace else 1.0
    harmony, anchor = harmony / slow, anchor / slow
    memory_quarters, memory_decay, step_gap = MEMORY_QUARTERS * slow, MEMORY_DECAY * slow, STEP_GAP * max(slow, 1.0)

    def spring(i, j, target, weight):
        """weight * ((x_j - x_i) - target)^2, or with i None: weight * (x_j - target)^2."""
        if weight <= 0 or (i is not None and group[i] == group[j]):
            return                                        # one pitch already: nothing to pull
        w = math.sqrt(weight)
        r = len(rhs)
        if i is not None:
            ri.append(r); ci.append(group[i]); val.append(-w)
        ri.append(r); ci.append(group[j]); val.append(w)
        rhs.append(w * target)

    for i, (_v, a, b, m) in enumerate(notes):
        spring(None, i, ref[m % 12], anchor * (b - a) / spq)

    order = sorted(range(n), key=lambda i: notes[i][1])
    for k, i in enumerate(order):
        vi, ai, bi, mi = notes[i]
        for j in order[k + 1:]:
            vj, aj, bj, mj = notes[j]
            if aj >= bi + memory_quarters * spq:
                break
            overlap = min(bi, bj) - aj
            if overlap <= 0 and mi % 12 == mj % 12:       # the same pitch class again
                spring(i, j, 0.0, memory * math.exp(-(aj - bi) / spq / memory_decay))

    lines = {}
    for i, (v, a, b, m) in enumerate(notes):
        lines.setdefault(v, []).append(i)
    for v, idx in lines.items():
        for i, j in zip(idx, idx[1:]):
            if notes[j][1] - notes[i][2] <= step_gap * spq and notes[i][3] != notes[j][3]:
                spring(i, j, ref[notes[j][3] % 12] - ref[notes[i][3] % 12], melody)

    if diamond is not None:
        return solve_diamond(score, ri, ci, val, rhs, group, harmony, limit, diamond, width,
                             np.array([ref[m % 12] for _v, _a, _b, m in notes]))

    together = {}                                         # sounding together, a stretch at a time
    for now, _c, length in segments(score) if harmony > 0 else ():
        chord = seventh_chord({notes[i][3] % 12 for i in now}) if septimal > 0 else None
        for x, i in enumerate(now):
            for j in now[x + 1:]:
                lo, hi = (i, j) if notes[i][3] <= notes[j][3] else (j, i)
                found = pair_target(notes[lo][3], notes[hi][3], chord)
                if found:
                    target, weight, seventh = found
                    key = (lo, hi, round(target, 3))
                    together[key] = together.get(key, 0.0) + harmony * (septimal if seventh else weight) * length / spq
    for (lo, hi, target), weight in together.items():
        spring(lo, hi, target, weight)
    x, held = limited_solve(ri, ci, val, rhs, group, limit)
    score['held'] = int(held.sum())
    return x


def solve_diamond(score, ri, ci, val, rhs, group, harmony, limit, diamond, width, start):
    """The harmony springs of --diamond added to the line springs already in ri..rhs, the pairs choosing
    their ratios afresh after each solve until none changes."""
    notes, spq = score['notes'], score['spq']
    pairs = {}                                            # (lo, hi): quarters sounding together
    for now, _c, length in segments(score) if harmony > 0 else ():
        for x, i in enumerate(now):
            for j in now[x + 1:]:
                lo, hi = (i, j) if notes[i][3] <= notes[j][3] else (j, i)
                if (notes[hi][3] - notes[lo][3]) % 12 in diamond and group[lo] != group[hi]:
                    pairs[(lo, hi)] = pairs.get((lo, hi), 0.0) + length / spq
    keys = list(pairs)
    size = [(notes[hi][3] - notes[lo][3]) % 12 for lo, hi in keys]
    lo_i = np.array([k[0] for k in keys], int)
    hi_i = np.array([k[1] for k in keys], int)
    quarters = np.array([pairs[k] for k in keys])
    base = len(rhs)
    x, picks, rounds, settled = start, None, 0, False
    for rounds in range(1, DIAMOND_ROUNDS + 1):
        got = x[hi_i] - x[lo_i]
        new = [choose(diamond[s], g, width) for s, g in zip(size, got)]
        if new == picks:
            settled = True
            break
        picks = new
        r = np.arange(base, base + len(keys))
        w = np.sqrt([harmony * diamond[s][k][1] * q for s, k, q in zip(size, picks, quarters)])
        t = np.array([diamond[s][k][0] for s, k in zip(size, picks)])
        x, held = limited_solve(ri + list(r) + list(r), ci + list(group[lo_i]) + list(group[hi_i]),
                                list(val) + list(-w) + list(w), list(rhs) + list(w * t), group, limit)
    chosen = {}
    for s, k, q in zip(size, picks or [], quarters):
        label = diamond[s][k][2]
        chosen.setdefault(s, {}).setdefault(label, 0.0)
        chosen[s][label] += q
    score.update(held=int(held.sum()), chosen=chosen, rounds=rounds, settled=settled)
    return x


def limited_solve(ri, ci, val, rhs, group, limit):
    """Least squares for the springs, with the limit kept: (an offset for each note, which notes had to
    be held).  The unknowns are the fold groups' pitches; group[i] is note i's."""
    # The anchors are the first n springs, one a note and in note order, so val[i] and rhs[i]
    # are note i's.  A note past the limit gets an anchor four times as stiff, and all the notes
    # are solved again: its neighbours give way with it, which clipping it alone would not do.
    val, rhs = np.array(val, dtype=float), np.array(rhs, dtype=float)
    held = np.zeros(len(group), bool)
    for _ in range(LIMIT_ROUNDS):
        A = coo_matrix((val, (ri, ci)), shape=(len(rhs), int(group.max()) + 1)).tocsr()
        x = lsqr(A, rhs, atol=1e-10, btol=1e-10, iter_lim=20000)[0][group]
        over = np.flatnonzero(np.abs(x) > limit) if limit is not None else np.array([], int)
        if not over.size:
            break
        held[over] = True
        val[over] *= 2.0
        rhs[over] *= 2.0
    else:
        raise SystemExit(f'--limit {limit:g}: {over.size} notes are still past it after {LIMIT_ROUNDS} rounds')
    return x, held


def to_array(score, offsets, reference='vrwt'):
    """The (rows, slots) array of cents within the octave that WreckingCrew_v2 plays."""
    midi = score['midi']
    T = (midi % 12) * 100.0 + reference_offsets(reference)[midi % 12]
    for (v, a, b, m), x in zip(score['notes'], offsets):
        T[v, a:b] = (m % 12) * 100.0 + x
    return T % 1200.0


def report(score, T):
    """How the lines and the chords of a tuning array measure up."""
    notes, spq, midi = score['notes'], score['spq'], score['midi']
    R, N = midi.shape
    sounding = np.zeros((R, N), bool)
    for v, a, b, _m in notes:
        sounding[v, a:b] = True
    pitch = wc.absolute_cents(T, midi)
    dev = pitch - 100.0 * midi
    wander = [np.ptp(dev[(midi % 12 == pc) & sounding]) for pc in range(12) if ((midi % 12 == pc) & sounding).any()]
    steps = {1: [], 2: []}
    lines, moved = {}, 0
    for v, a, b, m in notes:
        lines.setdefault(v, []).append((a, b, m))
        moved += np.ptp(pitch[v, a:b]) > 5
    for v, spans in lines.items():
        for (a1, b1, m1), (a2, b2, m2) in zip(spans, spans[1:]):
            if a2 - b1 <= spq and abs(m2 - m1) in (1, 2):
                steps[abs(m2 - m1)].append(abs(pitch[v, a2] - pitch[v, b1 - 1]))
    err = {'thirds': [0.0, 0.0], 'fifths': [0.0, 0.0]}
    for c in range(N):
        on = np.flatnonzero(sounding[:, c])
        for x in range(len(on)):
            for y in range(x + 1, len(on)):
                size = abs(int(midi[on[y], c]) - int(midi[on[x], c])) % 12
                if size in (3, 4, 8, 9, 5, 7):
                    got = abs(pitch[on[y], c] - pitch[on[x], c]) % 1200.0
                    e = err['fifths' if size in (5, 7) else 'thirds']
                    e[0] += abs(got - JUST[size]); e[1] += 1
    split = 0.0                                   # the same pitch class sounding at two pitches at once
    for c in range(N):
        on = np.flatnonzero(sounding[:, c])
        for pc in set(midi[on, c] % 12):
            d = dev[on[midi[on, c] % 12 == pc], c]
            if d.size > 1:
                split = max(split, float(np.ptp(d)))
    sevenths = {name: [0.0, 0.0] for name, *_ in SEVENTH_CHORDS}      # cents off, quarters
    for now, c, length in segments(score):
        chord = seventh_chord({notes[i][3] % 12 for i in now})
        if not chord:
            continue
        root = next(pc for pc, cents in chord[1].items() if cents == 0.0)
        roots = [i for i in now if notes[i][3] % 12 == root]
        sevens = [i for i in now if notes[i][3] % 12 == chord[2]]
        off = [abs((pitch[notes[j][0], c] - pitch[notes[i][0], c] - chord[1][chord[2]] + 600.0) % 1200.0 - 600.0)
               for i in roots for j in sevens]
        sevenths[chord[0]][0] += float(np.mean(off)) * length / spq
        sevenths[chord[0]][1] += length / spq
    h, w = np.array(steps[1]), np.array(steps[2])
    return dict(furthest=float(np.abs(dev[sounding]).max()), split=split, sevenths={k: (off / q if q else 0.0, q) for k, (off, q) in sevenths.items()},
                wander=float(np.mean(wander)), wander_max=float(np.max(wander)),
                half=(h.min(), h.max(), h.std()), whole=(w.min(), w.max(), w.std()), moved=int(moved),
                thirds=err['thirds'][0] / max(err['thirds'][1], 1), fifths=err['fifths'][0] / max(err['fifths'][1], 1))


def line(label, r):
    return (f'{label:22s} thirds and sixths {r["thirds"]:4.1f}  fifths {r["fifths"]:4.1f} cents from just | '
            f'half steps {r["half"][0]:3.0f}-{r["half"][1]:3.0f} (sd {r["half"][2]:4.1f})  '
            f'whole steps {r["whole"][0]:3.0f}-{r["whole"][1]:3.0f} (sd {r["whole"][2]:4.1f}) | '
            f'a pitch class moves {r["wander"]:4.1f} avg {r["wander_max"]:4.1f} max | held notes moved: {r["moved"]} | '
            f'7/4 off by {r["sevenths"]["4:5:6:7"][0]:4.1f}, 12/7 off by {r["sevenths"]["1/(4:5:6:7)"][0]:4.1f} | '
            f'furthest note {r["furthest"]:4.1f} from 12-TET | one pitch class split {r["split"]:4.1f}')


STEP_NAMES = ['unisons and octaves', 'minor seconds', 'major seconds', 'minor thirds', 'major thirds', 'fourths',
              'tritones', 'fifths', 'minor sixths', 'major sixths', 'minor sevenths', 'major sevenths']


def chosen_table(chosen):
    """Which ratios the pairs chose, by interval, as shares of the time that interval sounds."""
    out = []
    for s in sorted(chosen):
        total = sum(chosen[s].values())
        parts = sorted(chosen[s].items(), key=lambda kv: -kv[1])
        out.append(f'  {STEP_NAMES[s]:20s} {total:6.1f} q  ' +
                   '  '.join(f'{r} {100 * q / total:.0f}%' for r, q in parts))
    return '\n'.join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--chorale', required=True, help='score name, as for WreckingCrew_v2')
    ap.add_argument('--reference', default='vrwt', choices=sorted(wc.TEMPERAMENTS))
    ap.add_argument('--harmony', type=float, default=2.0, help='pull toward just intervals (0: the reference itself)')
    ap.add_argument('--melody', type=float, default=1.0, help='pull of each melodic step toward its reference size')
    ap.add_argument('--memory', type=float, default=1.0, help='pull of a pitch class toward where it just was')
    ap.add_argument('--septimal', type=float, default=1.0,
                    help='pull of a seventh toward 7/4 in a major chord and a sixth toward 12/7 in a minor one, '
                         'as a share of --harmony (0: no seventh chords, the 5-limit springs only)')
    ap.add_argument('--pace', default='auto',
                    help="'auto' (the default): measure note lengths against this piece's ordinary note, so a slow "
                         "piece is pulled no harder than a quick one; a number: that note length in quarters; "
                         "'off': against an eighth whatever the piece")
    ap.add_argument('--limit', type=float, default=40.0,
                    help='no note may be further than this many cents from its equal-tempered pitch')
    ap.add_argument('--diamond', type=int, default=None, metavar='N',
                    help='pull toward the ratios of the tonality diamond of identities (N+1)/2 to N (15: 8 to 15) '
                         'instead of the fixed 5-limit table and --septimal')
    ap.add_argument('--exponent', type=float, default=2.0,
                    help='with --diamond: a ratio n/d pulls with strength ((n+d)/5)^-exponent, 3/2 being 1')
    ap.add_argument('--width', type=float, default=15.0,
                    help='with --diamond: the width of each ratio\'s well in cents, for choosing between ratios')
    ap.add_argument('--fold', action=argparse.BooleanOptionalAction, default=True,
                    help='notes of the same pitch class sounding together share one pitch, in any octave or '
                         'voice (default); --no-fold: each note its own, as the arrays of 19 Nov')
    ap.add_argument('--out_dir', help='write <chorale>-opt.npy and .txt here')
    ap.add_argument('--sweep', action='store_true', help='print the trade-off for a range of --harmony')
    ap.add_argument('--compare', nargs='*', default=[], help='other tuning files to report beside it')
    args = ap.parse_args()

    score = load(args.chorale)
    print(f'{args.chorale}: {len(score["notes"])} notes, {score["midi"].shape[0]} rows, reference {args.reference}')
    found = report(score, wc.temperament_tuning(args.reference, score['midi']))['sevenths']
    print(f'seventh chords: 4:5:6:7 sounds for {found["4:5:6:7"][1]:.1f} quarters, 1/(4:5:6:7) for '
          f'{found["1/(4:5:6:7)"][1]:.1f}, of {score["midi"].shape[1] / score["spq"]:.0f}')
    pace = None if args.pace == 'off' else ordinary_note(score) if args.pace == 'auto' else float(args.pace)
    if pace:
        print(f'pace: the ordinary note is {pace:g} quarters ({PACE_REFERENCE:g} in bwv846f), so --harmony {args.harmony:g} '
              f'pulls as {args.harmony * PACE_REFERENCE / pace:g} would without --pace')
    for name in ('12-TET', 'werckmeister_III', 'vrwt'):
        print(line(name, report(score, wc.temperament_tuning(name, score['midi']))))
    for path in args.compare:
        print(line(os.path.basename(os.path.dirname(path)) or path, report(score, np.load(path))))
    diamond = diamond_targets(args.diamond, args.exponent, args.limit) if args.diamond else None
    if diamond:
        print(f'diamond {args.diamond}: {sum(map(len, diamond.values()))} ratios within {args.limit:g} cents of a step, '
              f'strength ((n+d)/5)^-{args.exponent:g}, wells {args.width:g} cents wide')
    for h in ([0.25, 0.5, 1, 2, 4, 8, 16, 64] if args.sweep else [args.harmony]):
        x = solve(score, args.reference, h, args.melody, args.memory, septimal=args.septimal, limit=args.limit, pace=pace,
                  diamond=diamond, width=args.width, fold=args.fold)
        T = to_array(score, x, args.reference)
        label = f'diamond {args.diamond} h {h:g} e {args.exponent:g}' if diamond else f'spring, h {h:g} s {args.septimal:g}'
        print(line(label, report(score, T)))
        if args.fold:
            print(f'  fold: {score["folded"]} of {len(x)} notes share a pitch with the same pitch class sounding with them')
        if score['held']:
            print(f'  --limit {args.limit:g}: {score["held"]} of {len(x)} notes were held inside it')
        if diamond:
            print(f'  the pairs settled after {score["rounds"]} rounds' if score['settled'] else
                  f'  the pairs were still changing their minds after {DIAMOND_ROUNDS} rounds')
            if not args.sweep:
                print(chosen_table(score['chosen']))
    if args.out_dir and not args.sweep:
        os.makedirs(args.out_dir, exist_ok=True)
        path = os.path.join(args.out_dir, f'{args.chorale}-opt.npy')
        np.save(path, T)
        with open(os.path.splitext(path)[0] + '.txt', 'w') as f:
            f.write(f'version: {args.chorale}\nmethod: spring_tuning\nreference: {args.reference}\n'
                    f'harmony: {args.harmony}\n'
                    + (f'diamond: {args.diamond}\nexponent: {args.exponent}\nwidth: {args.width}\n' if diamond else
                       f'septimal: {args.septimal}\n')
                    + f'melody: {args.melody}\nmemory: {args.memory}\nlimit: {args.limit}\npace: {pace}\nfold: {args.fold}\n'
                    f'voices: {T.shape[0]}\nrests: honored\n')
        print(f'wrote {path}')
        if atu.tuning_matches_score(T, score['midi']) < 1.0:
            # WreckingCrew_v2 takes a note more than 50 cents from its written pitch for a wrong note.
            # Only a --limit above 50 lets one through.
            print(f'  some notes are more than 50 cents from 12-TET (the furthest {np.abs(x).max():.0f}): '
                  f'WreckingCrew_v2 will refuse this.  Lower --limit.')


if __name__ == '__main__':
    main()
