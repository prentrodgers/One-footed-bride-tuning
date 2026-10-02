#!/usr/bin/env python3
"""
concert_stage.py - animate Concert_Stage.blend from a note array and render frames.

Same contract as blender_stage.py, so render_farm.sh can drive either one:
the animation is procedural (frame N is at t = N/FPS whoever renders it),
frames land in --out as frame_%06d.png, and the mp3 is muxed afterwards with
ffmpeg exactly as before.

    blender --background Concert_Stage.blend --python concert_stage.py -- \
        --npy Uploads/x.npy --tempo 104 --duration 10 --out frames_concert \
        [--frame-start 0 --frame-end 299] [--engine cycles] [--camera "Cam 1 Audience Wide"]

The stage itself was built over Blender MCP (concert_stagekit.py); the players
are puppets posed by concert_poses.py from a per-frame musical state. Notes use
the nearest 12-tone equal-tempered pitch for fingering, frets, bars and tines.
"""
import argparse
import math
import random
import sys
import time
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

REPO_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_DIR))
import concert_poses as cp          # noqa: E402  (imports concert_stagekit)

FPS = 30

# csound voice -> (player, articulation).  Unlisted voices are reported and not shown.
VOICES = {
    1: ("Finger Piano", "pluck"), 24: ("Bass Finger Piano", "pluck"),
    5: ("Marimba", "strike"), 7: ("Vibraphone", "strike"),
    20: ("Baritone Flying V", "pick"),
    17: ("Violin", "arco"), 9: ("Violin", "martele"), 2: ("Violin", "pizz"),
    18: ("Viola", "arco"), 10: ("Viola", "martele"), 3: ("Viola", "pizz"),
    19: ("Cello", "arco"), 11: ("Cello", "martele"), 4: ("Cello", "pizz"),
    14: ("Flute", "wind"), 13: ("Clarinet", "wind"), 15: ("Oboe", "wind"), 12: ("Bassoon", "wind"),
    25: ("Trumpet", "valves"), 39: ("Trumpet", "valves"), 27: ("Tuba", "valves"),
    16: ("French Horn", "valves"), 26: ("Trombone", "slide"),
}
# Voices with 8 instruments playing at once in the activity array, too many for one player: each note goes
# to one of two players by its stereo position (col 7, 1..16): below 8 (the audience's left) the stage-right
# player, 8 and up the stage-left one. voice -> (stage right player, stage left player)
SPLIT = {5: ("Marimba 2", "Marimba"), 1: ("Finger Piano 2", "Finger Piano")}
PAN_COL, PAN_SPLIT = 7, 8
VOICE_NAMES = {6: "xylophone", 8: "harp", 21: "Super Slinky", 22: "long string", 23: "original string",
               28: "triangle wave", 29: "Bosendorfer"}

# camera shots that feature each player (the first is preferred), and the wide shots
PLAYER_CAMS = {
    "Marimba": ["Cam 4 Marimba Player POV", "Cam 33 Marimba Player (side, full figure)"],
    "Marimba 2": ["Cam 35 Marimba 2 Player POV", "Cam 36 Marimba 2 Player (side, full figure)"],
    "Vibraphone": ["Cam 25 Vibraphone Player View"],
    "Violin": ["Cam 12 Violin Close", "Cam 21 Viola & Violin"], "Viola": ["Cam 21 Viola & Violin"],
    "Cello": ["Cam 13 Cello Close", "Cam 5 Cello & Violin"],
    "Baritone Flying V": ["Cam 18 Flying V & Amp", "Cam 20 Baritone Full String Length", "Cam 11 Fretboard Close"],
    "Finger Piano": ["Cam 10 Finger Piano (player view)", "Cam 29 Finger Piano Hands (front)", "Cam 6 Finger Pianos"],
    "Finger Piano 2": ["Cam 37 Finger Piano 2 (player view)", "Cam 38 Finger Piano 2 Hands (front)"],
    "Bass Finger Piano": ["Cam 19 Bass Finger Piano Overhead", "Cam 16 Bass Finger Piano (player view)"],
    "Flute": ["Cam 28 Flute (second row)"], "Clarinet": ["Cam 15 Bassoon & Clarinet (riser)"], "Oboe": ["Cam 34 Oboe Player", "Cam 7 Oboe Keys"],
    "Bassoon": ["Cam 23 Bassoon Close", "Cam 15 Bassoon & Clarinet (riser)"],
    "Trumpet": ["Cam 22 Trumpet Hands", "Cam 9 Trumpet & Trombone (riser)"], "Trombone": ["Cam 27 Trombone", "Cam 9 Trumpet & Trombone (riser)"],
    "Tuba": ["Cam 14 Tuba Close", "Cam 24 Tuba Side"], "French Horn": ["Cam 26 French Horn"],
}
WIDE_CAMS = ["Cam 1 Audience Wide", "Cam 2 Front Row Left", "Cam 8 Stage Right Side", "Cam 3 Overhead"]
SPECIAL_LIGHT = {  # player -> spotlight object
    "Baritone Flying V": "Special 1 Baritone Flying V", "Violin": "Special 2 Violin", "Finger Piano": "Special 3 Finger Piano",
    "Bass Finger Piano": "Special 4 Bass Finger Piano", "Flute": "Special 5 Flute", "Clarinet": "Special 6 Clarinet",
    "Oboe": "Special 7 Oboe", "Marimba": "Special 8 Marimba", "Cello": "Special 9 Cello", "Trumpet": "Special 10 Trumpet",
    "Tuba": "Special 11 Tuba", "Bassoon": "Special 12 Bassoon", "Viola": "Special 13 Viola", "French Horn": "Special 14 French Horn",
    "Trombone": "Special 15 Trombone", "Vibraphone": "Special 16 Vibraphone",
    "Marimba 2": "Special 17 Marimba 2", "Finger Piano 2": "Special 18 Finger Piano 2",
}


# ─────────────────────────────── notes ───────────────────────────────
def load_notes(npy, tempo):
    """-> {player: structured list of notes} using the nearest 12-TET pitch (C4 = 4800 cents = MIDI 60).
    Octave (col 5) 0 is WreckingCrew's silence marker, so those rows are not notes - the same
    filter the section modules use (blender_marimba_poc.load_notes)."""
    arr = np.load(npy)
    bps = tempo / 60.0
    aud = (arr[:, 5] > 0) & (arr[:, 14] > 0) & (arr[:, 3] > 0) & (arr[:, 2] > 0)
    arr = arr[aud]
    per, unmapped = {}, {}
    vmax = {}
    for row in arr:
        v = int(row[6])
        if v not in VOICES:
            unmapped[v] = unmapped.get(v, 0) + 1
            continue
        player, art = VOICES[v]
        if v in SPLIT:
            player = SPLIT[v][0] if row[PAN_COL] < PAN_SPLIT else SPLIT[v][1]
        cents = row[5] * 1200 + row[4]
        n = dict(t0=row[1] / bps, dur=row[2] / bps, midi=int(round(cents / 100.0)) + 12, cents=float(cents),
                 vol=float(row[14]), art=art, voice=v)
        n["t1"] = n["t0"] + n["dur"]
        per.setdefault(player, []).append(n)
        vmax[player] = max(vmax.get(player, 0.0), n["vol"])
    for player, ns in per.items():
        ns.sort(key=lambda n: (n["t0"], n["midi"]))
        for n in ns:
            n["lvl"] = n["vol"] / vmax[player] if vmax[player] > 0 else 1.0
    for v, c in sorted(unmapped.items()):
        print(f"[concert] voice {v} ({VOICE_NAMES.get(v, '?')}): {c} notes not shown on stage")
    for player in sorted(per):
        ns = per[player]
        print(f"[concert] {player:18s} {len(ns):5d} notes  MIDI {min(n['midi'] for n in ns)}-{max(n['midi'] for n in ns)}")
    return per


def sounding(ns, t):
    return [n for n in ns if n["t0"] <= t < n["t1"]]


def last_onset(ns, t):
    prev = None
    for n in ns:
        if n["t0"] > t:
            break
        prev = n
    return prev


def next_onset(ns, t):
    for n in ns:
        if n["t0"] > t:
            return n
    return None


def envelope(ns, t, decay=0.6):
    """0..1 activity for lights and camera: held notes sustain, released ones decay."""
    e = 0.0
    for n in ns:
        if n["t0"] > t:
            break
        if t < n["t1"]:
            e = max(e, n["lvl"])
        else:
            e = max(e, n["lvl"] * math.exp(-(t - n["t1"]) / decay))
    return e


# ─────────────────────────────── mallets (marimba / vibraphone) ───────────────────────────────
BAR_SPECS = {  # rig, lowest MIDI, count, L0, w_low, w_high, gap, centre gap, top natural, top accidental
    "Marimba": ("Marimba", 45, 52, 0.52, 0.068, 0.044, 0.010, 0.020, 0.90, 0.92),
    "Marimba 2": ("Marimba 2", 45, 52, 0.52, 0.068, 0.044, 0.010, 0.020, 0.90, 0.92),
    "Vibraphone": ("Vibraphone", 53, 37, 0.37, 0.057, 0.043, 0.009, 0.020, 0.86, 0.86),
}
_ACC = {1, 3, 6, 8, 10}


def bar_points(key):
    """MIDI -> world point where a mallet strikes that bar (same layout maths the stage was built with)."""
    rig, m0, K, L0, wl, wh, gap, cen, tn, ta = BAR_SPECS[key]
    notes = []
    for k in range(K):
        midi = m0 + k
        notes.append(dict(midi=midi, acc=(midi % 12) in _ACC, L=L0 * 2 ** (-k / 24), w=wl - (wl - wh) * k / (K - 1)))
    nat = [n for n in notes if not n["acc"]]
    x = (sum(n["w"] for n in nat) + gap * (len(nat) - 1)) / 2
    for n in nat:
        n["x"] = x - n["w"] / 2; x -= n["w"] + gap
    for i, n in enumerate(notes):
        if n["acc"]:
            n["x"] = (notes[i - 1]["x"] + notes[i + 1]["x"]) / 2
    mw = bpy.data.objects[rig].matrix_world
    pts = {}
    for n in notes:
        if n["acc"]:
            y, z = -(cen + 0.30 * n["L"]), ta          # accidentals: struck on the end nearest the player
        else:
            y, z = cen + 0.50 * n["L"], tn
        pts[n["midi"]] = mw @ Vector((n["x"], y, z))
    return pts


def fold(midi, lo, hi):
    while midi < lo:
        midi += 12
    while midi > hi:
        midi -= 12
    return midi


class MalletPlayer:
    """Four mallets that never cross: ORDER runs low -> high pitch, which on these instruments is +x -> -x
    (low notes on the player's left). Each chord is dealt to mallets in that order, the idle mallets are
    carried along so the order and each hand's reach hold, and the player steps sideways to follow."""
    ORDER = [("L", 1), ("L", 0), ("R", 0), ("R", 1)]          # L outer, L inner, R inner, R outer
    GAP = 0.05                                                # min spacing between neighbouring heads (x)
    SPAN = 0.40                                               # max spread of the two mallets in one hand
    HEAD_R = 0.021
    LIFT = 0.07                                               # hover height above the bars

    ORDER2 = [("L", 0), ("R", 0)]                             # one mallet per hand (cp.MALLETS_PER_HAND)
    GAP2 = 0.08                                               # one per hand: the hands keep apart

    def __init__(self, key, notes):
        import itertools
        self.key = key
        if cp.MALLETS_PER_HAND.get(key, 2) == 1:
            self.ORDER, self.GAP = self.ORDER2, self.GAP2
        n_m = len(self.ORDER)
        self.pts = bar_points(key)
        lo, hi = min(self.pts), max(self.pts)
        rest = cp.mallet_heads_rest(key)
        self.rest = {(s, i): rest[s][i] for s, i in self.ORDER}
        self.rest_cx = sum(p.x for p in self.rest.values()) / n_m
        self.bar_z = sum(p.z for p in self.pts.values()) / len(self.pts)
        pos = {k: Vector(p) for k, p in self.rest.items()}
        self.ev = {k: [] for k in self.ORDER}                   # mallet -> [(t, point, strike)]
        i = 0
        while i < len(notes):                                  # a chord = notes starting within 30 ms
            chord = [notes[i]]
            while i + len(chord) < len(notes) and notes[i + len(chord)]["t0"] - notes[i]["t0"] < 0.03:
                chord.append(notes[i + len(chord)])
            i += len(chord)
            t0 = chord[0]["t0"]
            targets = sorted({fold(n["midi"], lo, hi) for n in chord})
            if len(targets) > n_m:                              # more notes than mallets: the outer voices
                targets = targets[:n_m] if n_m == 4 else [targets[0], targets[-1]]
            tp = [self.pts[m] for m in targets]                 # low -> high pitch = high -> low x
            def cost(c):
                x = [pos[k].x for k in self.ORDER]
                for j, p in zip(c, tp):
                    x[j] = p.x
                over = max(0.0, x[0] - x[1] - self.SPAN) + max(0.0, x[2] - x[3] - self.SPAN) if n_m == 4 else 0.0
                return sum(abs(pos[self.ORDER[j]].x - p.x) for j, p in zip(c, tp)) + 10.0 * over
            best = min(itertools.combinations(range(n_m), len(tp)), key=cost)
            fixed, fmid = {}, {}
            lvl = {fold(n["midi"], lo, hi): n["lvl"] for n in chord}
            for j, p, m in zip(best, tp, targets):
                fixed[j] = p; fmid[j] = m
            x = [pos[k].x for k in self.ORDER]
            for j, p in fixed.items():
                x[j] = p.x
            for _ in range(3):                                  # carry the idle mallets: keep order and reach
                for j in range(n_m):
                    if j in fixed:
                        continue
                    if n_m == 4:
                        partner = {0: 1, 1: 0, 2: 3, 3: 2}[j]
                        x[j] = max(min(x[j], x[partner] + self.SPAN), x[partner] - self.SPAN)
                    if j > 0:                                   # order wins over reach
                        x[j] = min(x[j], x[j - 1] - self.GAP)
                    if j < n_m - 1:
                        x[j] = max(x[j], x[j + 1] + self.GAP)
            for j, k in enumerate(self.ORDER):
                if j in fixed:
                    self.ev[k].append((t0, fixed[j], True, fmid[j], lvl.get(fmid[j], 1.0))); pos[k] = fixed[j]
                elif abs(x[j] - pos[k].x) > 1e-4:
                    carried = Vector((x[j], pos[k].y, pos[k].z))
                    self.ev[k].append((t0, carried, False, None, 0.0)); pos[k] = carried
        self.strikes = sorted((e[0], e[3], e[4]) for k in self.ORDER for e in self.ev[k] if e[2])

    # ---- the stroke: the mallet pivots at the grip (wrist and fingers); the hand stays at playing height ----
    TH_HOVER = math.radians(8)      # head ~3.5 cm over the bars between notes
    TH_TOP = math.radians(40)       # full stroke: the head starts from about hand level
    TH_REBOUND = math.radians(20)
    T_DOWN, T_REB = 0.07, 0.06      # the downstroke takes two frames: it lands hard

    def _neighbours(self, k, t):
        prev = nxt = None
        for e in self.ev[k]:
            if e[0] <= t:
                prev = e
            else:
                nxt = e
                break
        return prev, nxt

    def head(self, k, t):
        """Where the head WOULD touch the bar (x, y and contact height): the stroke itself is theta()."""
        prev, nxt = self._neighbours(k, t)
        base = prev[1] if prev else self.rest[k]
        xy = Vector((base.x, base.y, 0.0))
        if nxt:                                               # travel to the next bar during the lift
            gap = nxt[0] - (prev[0] if prev else nxt[0] - 1.0)
            move = min(0.30, max(0.05, gap * 0.7))
            end = nxt[0] - (self.T_DOWN if nxt[2] else 0.0)
            u = (t - (end - move)) / move
            if u > 0:
                u = min(1.0, u); u = u * u * (3 - 2 * u)
                xy = xy.lerp(Vector((nxt[1].x, nxt[1].y, 0.0)), u)
        h = Vector((xy.x, xy.y, self.bar_z + self.HEAD_R))
        w = self._rest_weight(k, t)                           # resting: back to the starting position
        if w > 0:
            h = h.lerp(Vector((self.rest[k].x, self.rest[k].y, self.bar_z + self.HEAD_R)), w)
        return h

    def theta(self, k, t):
        """Stroke angle about the grip: 0 = head on the bar."""
        prev, nxt = self._neighbours(k, t)
        sm = lambda v: (lambda c: c * c * (3 - 2 * c))(max(0.0, min(1.0, v)))
        th = self.TH_HOVER
        if prev and prev[2]:                                  # rebound off the bar, settling to a hover
            a = t - prev[0]
            if a < self.T_REB:
                th = self.TH_REBOUND * math.sin(0.5 * math.pi * a / self.T_REB)
            else:
                th = self.TH_HOVER + (self.TH_REBOUND - self.TH_HOVER) * math.exp(-(a - self.T_REB) / 0.07)
        if nxt and nxt[2]:
            gap = nxt[0] - (prev[0] if prev else nxt[0] - 2.0)
            top = max(math.radians(16), min(self.TH_TOP, math.radians(12) + gap * math.radians(90)))
            t_down = nxt[0] - self.T_DOWN
            t_lift = max(nxt[0] - 0.40, (prev[0] + self.T_REB * 0.8) if prev else -9.0)
            if t >= t_down:                                   # accelerating down onto the bar
                u = (t - t_down) / self.T_DOWN
                th = top * (1 - u * u)
            elif t >= t_lift and t_down > t_lift:             # lift from wherever the last rebound left it
                th = th + (top - th) * sm((t - t_lift) / (t_down - t_lift))
        w = self._rest_weight(k, t)
        return th + (self.TH_HOVER - th) * w

    def bars(self, t):
        """{midi: signed displacement} for bars still ringing from a stroke."""
        out = {}
        amp0 = 0.0016 if self.key.startswith("Marimba") else 0.0010
        for t0, m, lvl in self.strikes:
            if t0 > t:
                break
            age = t - t0
            tau = 0.8 if self.key == "Vibraphone" else 0.25 + 0.35 * (1 - (m - min(self.pts)) / max(1, max(self.pts) - min(self.pts)))
            if age > 5 * tau:
                continue
            f = 9.0 + 0.07 * (m % 24)
            d = amp0 * (0.5 + 0.5 * lvl) * math.exp(-age / tau) * math.cos(2 * math.pi * f * age)
            if abs(d) > 2e-5 and abs(d) >= abs(out.get(m, 0.0)):
                out[m] = d
        return out

    REST_GAP, REST_OUT, REST_IN = 2.0, 0.7, 0.55

    def _rest_weight(self, k, t):
        if not hasattr(self, "_strokes"):
            self._strokes = sorted({e[0] for kk in self.ORDER for e in self.ev[kk] if e[2]})
        ts = self._strokes
        if not ts:
            return 1.0
        sm = lambda v: (lambda c: c * c * (3 - 2 * c))(max(0.0, min(1.0, v)))
        import bisect
        i = bisect.bisect_right(ts, t)
        prev = ts[i - 1] if i > 0 else None
        nxt = ts[i] if i < len(ts) else None
        if prev is not None and nxt is not None and nxt - prev <= self.REST_GAP:
            return 0.0
        w_out = 1.0 if prev is None else sm((t - prev - 0.35) / self.REST_OUT)
        w_in = 1.0 if nxt is None else sm((nxt - self.REST_IN - 0.15 - t) / self.REST_IN)
        return min(w_out, w_in)

    def _striking(self, k, t):
        return any(e[2] and -0.12 < e[0] - t < 0.16 for e in self.ev[k])

    def _heads(self, t):
        hs = [self.head(k, t) for k in self.ORDER]
        # mallets travel on their own clocks and could pass each other mid-flight: push neighbours apart,
        # letting a mallet that is on (or about to hit) its bar hold its place
        w = [10.0 if self._striking(k, t) else 1.0 for k in self.ORDER]
        for _ in range(4):
            for j in range(1, len(hs)):
                short = self.GAP - (hs[j - 1].x - hs[j].x)
                if short > 0:
                    hs[j - 1].x += short * w[j] / (w[j - 1] + w[j])
                    hs[j].x -= short * w[j - 1] / (w[j - 1] + w[j])
        return hs

    # ---- feet: planted; the body leans; a real step only when a note is out of lean-and-reach ----
    LEAN_MAX = 0.12          # shoulders can shift this far sideways by leaning from the hips (~14 deg)
    STEP_AT = 0.30           # how far the mallets may stay from the stance before she steps
    STEP_T = 0.45            # seconds for a step: the leading foot, then the trailing foot follows
    STEP_LIFT = 0.045

    def _cx(self, t):
        hs = self._heads(t)
        return sum(h.x for h in hs) / len(hs) - self.rest_cx           # +x is the player's left

    def _plan_steps(self):
        t_end = max((e[0] for k in self.ORDER for e in self.ev[k]), default=0.0) + 1.0
        self.steps = []                                         # (t0, t1, from, to)
        stance, free_at, t = 0.0, -9.0, 0.0
        while t < t_end:
            # where the mallets are about to spend the next 0.8 s, not where they flick for one note:
            # a quick reach is done by leaning, only a sustained move out of range earns a step
            ahead = [self._cx(t + dt) - stance for dt in (0.0, 0.2, 0.4, 0.6, 0.8)]
            need = sum(ahead) / len(ahead)
            if abs(need) > self.STEP_AT and min(abs(a) for a in ahead) > 0.6 * self.STEP_AT and t >= free_at:
                to = max(-1.0, min(1.0, stance + need - math.copysign(0.05, need)))   # to just short of under the hands
                t0 = max(t - 0.6 * self.STEP_T, free_at)           # start early so she arrives in time
                self.steps.append((t0, t0 + self.STEP_T, stance, to))
                stance, free_at = to, t0 + self.STEP_T + 0.25
            t += 0.05

    def _stance(self, t):
        sm = lambda v: (lambda c: c * c * (3 - 2 * c))(max(0.0, min(1.0, v)))
        x = 0.0
        for t0, t1, a, b in self.steps:
            if t >= t1:
                x = b; continue
            if t < t0:
                break
            u = (t - t0) / (t1 - t0)
            lead, trail = ("L", "R") if b > a else ("R", "L")
            ul, ut = sm(u / 0.6), sm((u - 0.4) / 0.6)
            feet = {lead: (a + (b - a) * ul, self.STEP_LIFT * math.sin(math.pi * ul)),
                    trail: (a + (b - a) * ut, self.STEP_LIFT * math.sin(math.pi * ut))}
            return feet, (feet["L"][0] + feet["R"][0]) / 2
        return {"L": (x, 0.0), "R": (x, 0.0)}, x

    def state(self, t):
        if not hasattr(self, "steps"):
            self._plan_steps()
        hs = self._heads(t)
        th = [self.theta(k, t) for k in self.ORDER]
        if len(hs) == 4:
            heads = {"L": (hs[1], hs[0]), "R": (hs[2], hs[3])}     # (inner, outer)
            theta = {"L": (th[1], th[0]), "R": (th[2], th[3])}
        else:                                                     # one per hand: "outer" mirrors "inner"
            heads = {"L": (hs[0], hs[0]), "R": (hs[1], hs[1])}
            theta = {"L": (th[0], th[0]), "R": (th[1], th[1])}
        feet, px = self._stance(t)
        cx = sum(h.x for h in hs) / len(hs) - self.rest_cx
        lean = max(-self.LEAN_MAX, min(self.LEAN_MAX, (cx - px) * 0.5))
        # body_shift is for the over-the-shoulder camera, which rides along with her stance
        return {"heads": heads, "theta": theta, "bars": self.bars(t),
                "stance": feet, "lean": lean, "body_shift": (px, 0.0, 0.0)}


# ─────────────────────────────── finger pianos ───────────────────────────────
class FingerPianoPlayer:
    """Piano-style: each hand keeps a five-tine position that follows its notes. A note is PLUCKED:
    the finger comes down onto the tine tip, pushes it down, slides off the end toward the player at
    the note's onset, and lifts back; the tine follows the finger down, then rings. A real tine rings
    at hundreds of Hz - far beyond 30 fps - so the ring is drawn as a visible decaying wobble."""
    DESCEND, PRESS, SLIP, RETURN = 0.06, 0.06, 0.05, 0.18      # seconds: approach, push, slide off, lift back
    F_VIS = 9.0                                                  # Hz: readable wobble at 30 fps
    RING_GAIN = 2.0          # the ring is drawn at twice the real few-mm swing, so it reads at camera distance

    def __init__(self, key, notes):
        self.key = key
        self.tines = cp.fp_tines(key)
        self.byname = {n["midi"]: n for n in self.tines}
        self.midis = [n["midi"] for n in self.tines]
        self.nat = [n["midi"] for n in self.tines if not n["acc"]]
        lo, hi = self.midis[0], self.midis[-1]
        self.split = (lo + hi) // 2
        self.notes = [dict(n, m=fold(n["midi"], lo, hi)) for n in notes]
        K = self.K = cp.FP_SPEC[key][0]
        self.hover = 0.010 * min(K, 2.0)                     # finger height above an idle tine
        self.slip = 0.007 * K                                # how far the finger slides past the tip
        self.dmax = 0.004 * K
        self.tau_scale = 1.0 if K < 2 else 1.6               # the long bass tines ring longer
        self.window = self.DESCEND + self.PRESS
        self._plan()

    SPAN = 0.10                                              # widest chord one hand plucks at once (m)

    def _plan(self):
        """Fingering: per hand, a list of plucks (t0, hand_x, {digit: note}). Each single note goes to the
        finger that moves the hand least; a chord goes to adjacent fingers in pitch order, as wide as a
        hand spans (any further notes still ring, unfingered)."""
        tx = {n["midi"]: n["x"] for n in self.tines}
        dx = cp.FP_DIGIT_X
        nat = [n for n in self.tines if not n["acc"]]
        self.plan = {"L": [], "R": []}
        hand = {"L": nat[9]["x"], "R": nat[18]["x"]}
        i = 0
        while i < len(self.notes):
            chord = [self.notes[i]]
            while i + len(chord) < len(self.notes) and self.notes[i + len(chord)]["t0"] - self.notes[i]["t0"] < 0.03:
                chord.append(self.notes[i + len(chord)])
            i += len(chord)
            for side in ("L", "R"):
                ns = sorted({n["m"]: n for n in chord if (n["m"] < self.split) == (side == "L")}.values(), key=lambda n: n["m"])
                if not ns:
                    continue
                sgn = 1.0 if side == "R" else -1.0
                while len(ns) > 1 and abs(tx[ns[-1]["m"]] - tx[ns[0]["m"]]) > self.SPAN:
                    ns = ns[1:] if side == "L" else ns[:-1]       # keep the notes nearest the hand's centre
                ns = ns[:4]
                if self.K >= 2 and len(ns) > 1:                  # bass tines are 3x apart and the sharps sit 6.6 cm back:
                    keep = ns[-1] if side == "L" else ns[0]      # a hand holds two neighbouring tines in one row at most
                    row = self.byname[keep["m"]]["acc"]
                    ns = [n for n in ns if self.byname[n["m"]]["acc"] == row
                          and abs(tx[n["m"]] - tx[keep["m"]]) <= 0.05][:2]
                if len(ns) == 1:
                    x = tx[ns[0]["m"]]
                    fingers_ok = range(3) if self.K >= 2 else range(4)   # no pinky for a deep bass pluck
                    j = min(fingers_ok, key=lambda j: abs((x - sgn * dx[j]) - hand[side]) + (0.02 if j == 3 else 0.0))
                    fingers = {j: ns[0]}
                else:                                        # adjacent fingers, index at the low end (R) / high end (L)
                    order = ns if side == "R" else list(reversed(ns))
                    fingers = {j: n for j, n in enumerate(order)}
                hx = sum(tx[n["m"]] - sgn * dx[j] for j, n in fingers.items()) / len(fingers)
                hand[side] = hx
                self.plan[side].append((chord[0]["t0"], hx, fingers))

    def _hand(self, side, t):
        """(hand_x, active digits) at time t: plucks under way, and the hand easing to the next one."""
        pl = self.plan[side]
        digits = {}
        prev = nxt = None
        live = [p for p in pl if p[0] - self.window <= t <= p[0] + self.RETURN]
        if live:                                             # in a fast run the next pluck starts before the last lifts off:
            lead = live[-1]                                  # the newest one sets the hand, a finger from an earlier
            for p in live:                                   # pluck stays only if the hand has not moved from it
                if abs(p[1] - lead[1]) > 0.012:
                    continue
                for j, n in p[2].items():
                    dy, dz, ride = self.gesture(n, t)
                    digits[j] = {"m": n["m"], "dy": dy, "dz": dz, "ride": ride}
        for p in pl:
            if p[0] - self.window <= t:
                prev = p
            elif nxt is None:
                nxt = p
        if prev is None:
            return (nxt[1] if nxt else None), digits
        hx = prev[1]
        if nxt:                                              # glide toward the next pluck before it starts
            t_leave = max(prev[0] + self.RETURN * 0.5, nxt[0] - self.window - 0.35)
            t_arrive = nxt[0] - self.window
            if t > t_leave and t_arrive > t_leave:
                u = min(1.0, (t - t_leave) / (t_arrive - t_leave))
                hx = hx + (nxt[1] - hx) * u * u * (3 - 2 * u)
        return hx, digits

    def depth(self, m):
        """How far a pluck pushes this tine's tip down: longer tines bend further."""
        return min(max(0.07 * self.byname[m]["L"], 0.0025), self.dmax)

    def bend(self, n, t):
        u = t - n["t0"]
        D = self.depth(n["m"])
        if -self.PRESS <= u < 0:                             # finger pushing the tip down
            return D * (u + self.PRESS) / self.PRESS
        if u >= 0:                                           # released: decaying ring
            if u > 5 * self.tau(n):
                return 0.0
            return self.RING_GAIN * D * self.ring(n, t) * math.cos(2 * math.pi * self.F_VIS * u)
        return 0.0

    def tau(self, n):
        return min(max(n["dur"], 0.3), 1.2) * self.tau_scale

    def ring(self, n, t):
        """0..1: how loudly the tine is still ringing (drives the vibration and the glow)."""
        u = t - n["t0"]
        return math.exp(-u / self.tau(n)) if u >= 0 else 0.0

    def gesture(self, n, t):
        """(dy, dz, ride) of the plucking fingertip relative to its tine tip."""
        u = t - n["t0"]
        sm = lambda x: max(0.0, min(1.0, x)) ** 2 * (3 - 2 * max(0.0, min(1.0, x)))
        if u < -self.PRESS:                                  # coming down onto the tip
            return 0.0, self.hover * (1 - sm((u + self.window) / self.DESCEND)), False
        if u < 0:                                            # pressing: rides the bending tip
            return 0.0, 0.0, True
        if u < self.SLIP:                                    # slides off the end toward the player
            s = sm(u / self.SLIP)
            return -self.slip * s, -self.depth(n["m"]) * 0.6 * s, False
        s = sm((u - self.SLIP) / (self.RETURN - self.SLIP))  # lifts back over the tine
        return -self.slip * (1 - s), -self.depth(n["m"]) * 0.6 * (1 - s) + self.hover * s, False

    def state(self, t):
        # every tine still moving: pressed by a finger or ringing after release
        bends, glow = {}, {}
        for n in self.notes:
            if n["t0"] - self.PRESS > t:
                break
            b = self.bend(n, t)
            if b and abs(b) > abs(bends.get(n["m"], 0.0)):
                bends[n["m"]] = b
            g = self.ring(n, t) * n["lvl"]
            if g > 0.02 and g > glow.get(n["m"], 0.0):
                glow[n["m"]] = g
        st = {"bend": bends, "glow": glow, "hover": self.hover}
        for side in ("L", "R"):
            hx, digits = self._hand(side, t)
            st[side] = {"digits": digits} if hx is None else {"x": hx, "digits": digits}
        return st


# ─────────────────────────────── strings ───────────────────────────────
OPEN = {"Violin": [55, 62, 69, 76], "Viola": [48, 55, 62, 69], "Cello": [36, 43, 50, 57],
        "Baritone Flying V": [35, 40, 45, 50, 54, 59]}
SCALE_LEN = {"Violin": 0.328, "Viola": 0.328, "Cello": 0.690}        # in each rig's own units (viola rig is scaled 1.15)


def string_for(opens, midi):
    """The highest string whose open pitch is at or below the note: the lowest position on the fingerboard."""
    s = 0
    for i, o in enumerate(opens):
        if midi >= o:
            s = i
    return s


def stop_distance(scale, semis):
    """Distance from the nut of a stop `semis` equal-tempered semitones above the open string."""
    return scale * (1 - 2 ** (-semis / 12)) if semis > 0 else 0.0


# Visible string vibration. A real string swings hundreds of times a second - far beyond 30 fps - so it
# is drawn as a quick shimmer (a different rate per string so neighbours do not move in step), with an
# amplitude a little larger than life so it reads on camera: bowed strings sustain while the bow moves,
# plucked ones (pizzicato, guitar) ring down.
STRING_AMP = {"Violin": 0.0011, "Viola": 0.0011, "Cello": 0.0020, "Baritone Flying V": 0.0016}
STRING_HZ = (11.3, 13.1, 14.7, 12.2, 15.9, 10.4)


def string_disp(key, s, amp, t):
    return amp * math.cos(2 * math.pi * STRING_HZ[s % 6] * t + 1.3 * s)


class BowedPlayer:
    def __init__(self, key, notes):
        self.key = key
        self.notes = notes
        self.opens = OPEN[key]
        # bow direction alternates note by note; position integrates speed
        self.plan = []
        pos, direction = 0.20, 1
        t_prev = notes[0]["t0"] if notes else 0.0
        for n in notes:
            if n["art"] == "pizz":
                self.plan.append((n, 0.12, 0.12)); continue
            travel = min(0.50, max(0.10, n["dur"] * (0.45 if n["art"] == "arco" else 0.9)))
            if n["art"] == "martele":
                travel = min(travel, 0.18)
            start = pos
            end = pos + direction * travel
            if end > 0.65 or end < 0.08:
                direction = -direction; end = pos + direction * travel
            end = max(0.08, min(0.65, end))
            self.plan.append((n, start, end)); pos, direction = end, -direction

    def _fingering(self, notes):
        """Up to two sounding notes -> [(string, stop distance, finger or None for open)], one finger each.
        Each note on the highest string at or below it (the lowest position); a second note that would
        land on the same string moves to the next lower one. Fingers are dealt in order along the neck."""
        L = SCALE_LEN[self.key]
        out, used = [], set()
        for n in sorted(notes, key=lambda n: -n["midi"])[:2]:
            s = string_for(self.opens, n["midi"])
            while s in used and s > 0 and n["midi"] >= self.opens[s - 1]:
                s -= 1
            if s in used:
                continue
            used.add(s)
            out.append([s, stop_distance(L, n["midi"] - self.opens[s]), None])
        stopped = sorted((o for o in out if o[1] > 0), key=lambda o: o[1])
        if stopped:
            d0 = stopped[0][1]
            semis0 = round(-12 * math.log2(1 - d0 / L))
            f0 = min(3, max(0, (semis0 - 1) // 2)) if len(stopped) == 1 else min(2, max(0, (semis0 - 1) // 2))
            gap = max(0.017 * L / 0.328, 0.025 * L / 0.328 * math.sqrt(1 - d0 / L))
            stopped[0][2] = f0
            for o in stopped[1:]:
                if o[1] - d0 > 3.3 * gap:                        # beyond one hand's span: that note is not fingered
                    out.remove(o); continue
                o[2] = max(f0 + 1, min(3, f0 + round((o[1] - d0) / gap)))
        return out

    def state(self, t):
        cur = [p for p in self.plan if p[0]["t0"] <= t < p[0]["t1"] + 0.05]
        st = {}
        if cur:
            n, a, b = cur[-1]
            u = min(1.0, (t - n["t0"]) / max(n["dur"], 1e-3))
            st["frog_dist"] = a + (b - a) * u
            fing = self._fingering([p[0] for p in cur])
            st["bow_string"] = sum(o[0] for o in fing) / len(fing)
            stopped = [o for o in fing if o[1] > 0]
            if stopped:
                L = SCALE_LEN[self.key]
                s0, d0, f0 = min(stopped, key=lambda o: o[1])
                # a finger's spacing: it narrows up the neck, but fingers never get closer than their width
                gap = max(0.017 * L / 0.328, 0.025 * L / 0.328 * math.sqrt(1 - d0 / L))
                # the hand's position: where its first finger would sit
                base_first = [0.034, 0.060, 0.084, 0.104][f0] * (L / 0.328)
                st["shift"] = max(0.0, d0 - base_first)
                stops = [None] * 4
                for s, d, fi in stopped:
                    stops[fi] = (d, s, 0.0)                        # a finger ON the string for each note
                fb = 0.270 * L / 0.328 if self.key != "Cello" else 0.58
                for i in range(4):                                 # the others curve just above, off the strings
                    if stops[i] is None:
                        stops[i] = (max(0.01, min(fb, d0 + (i - f0) * gap)), s0, 0.012)
                st["stops"] = stops
        else:
            prev = last_onset([p[0] for p in self.plan], t)
            if prev is not None:
                pl = [p for p in self.plan if p[0] is prev][0]
                st["frog_dist"] = pl[2]
        # the string that is sounding (or ringing on after its note): stopped where the finger is, vibrating
        notes = [p[0] for p in cur] if cur else [n for n in [last_onset([p[0] for p in self.plan], t)] if n]
        if notes:
            fing = self._fingering(notes)
            strings = {}
            for n in sorted(notes, key=lambda n: -n["midi"])[:2]:
                match = [o for o in fing if abs(stop_distance(SCALE_LEN[self.key], n["midi"] - self.opens[o[0]]) - o[1]) < 1e-9]
                if not match:
                    continue
                s, d, _f = match[0]
                u = t - n["t0"]
                A = STRING_AMP[self.key] * (0.4 + 0.6 * n["lvl"])
                if n["art"] == "pizz":
                    amp = 1.3 * A * math.exp(-u / 0.35)
                elif n["art"] == "martele":
                    amp = A * (0.7 + 0.6 * math.exp(-u / 0.12)) * min(1.0, u / 0.03)
                else:
                    amp = A * min(1.0, u / 0.06)
                if t > n["t1"] and n["art"] != "pizz":           # bow lifted: the string rings down quickly
                    amp *= math.exp(-(t - n["t1"]) / 0.10)
                d = d if cur else 0.0
                if amp > 1e-5 or d > 0:
                    strings[s] = {"d": d, "disp": string_disp(self.key, s, amp, t) if amp > 1e-5 else 0.0}
            if strings:
                st["strings"] = strings
        return st


class GuitarPlayer:
    tempo = None                      # set by Performance: beats per minute of the piece

    def __init__(self, notes):
        self.notes = notes
        self.onsets = [n["t0"] for n in notes]

    def groove(self, t):
        """Carol Kaye in the pocket: a sway from the hips across each two beats and a nod on every beat,
        while he is playing; still when he is not."""
        if not self.tempo:
            return (0.0, 0.0)
        import bisect
        i = bisect.bisect_right(self.onsets, t + 0.3)
        recent = [n for n in self.notes[max(0, i - 40):i] if n["t0"] <= t + 0.3]
        last_end = max((n["t1"] for n in recent), default=-9.0)
        nxt = self.onsets[i] if i < len(self.onsets) else 1e9
        e_out = max(0.0, min(1.0, 1.0 - (t - last_end - 0.4) / 1.2)) if t > last_end else 1.0
        e_in = max(0.0, min(1.0, 1.0 - (nxt - t - 0.3) / 0.6)) if not recent else 1.0
        e = min(1.0, max(e_out if recent else 0.0, e_in))
        e = e * e * (3 - 2 * e)
        beat = t * self.tempo / 60.0
        roll = math.radians(3.0) * math.sin(math.pi * beat)
        nod = math.radians(2.5) * max(0.0, math.cos(2 * math.pi * beat)) ** 3
        return (roll * e, nod * e)

    def state(self, t):
        st = {"sway": self.groove(t)}
        cur = sounding(self.notes, t)
        if cur:
            n = max(cur, key=lambda n: n["midi"])
            opens = OPEN["Baritone Flying V"]
            s = string_for(opens, n["midi"])                 # highest string, lowest fret
            fret = max(0, min(22, n["midi"] - opens[s]))
            if fret == 0:                                     # open string: fingers hover
                st["lifts"] = [0.012] * 4
                st["stops"] = [(5, s), (6, s), (7, s), (8, s)]
            else:
                st["stops"] = [(max(1, fret + i), min(5, s + (1 if i >= 2 else 0))) for i in range(4)]
                st["lifts"] = [0.0] + [0.010] * 3
        prev = last_onset(self.notes, t)
        if prev is not None:
            k = self.notes.index(prev)
            u = min(1.0, (t - prev["t0"]) / 0.09)
            a, b = (0.012, -0.012) if k % 2 == 0 else (-0.012, 0.012)
            st["pick_dy"] = a + (b - a) * u
            # the picked string rings from its fret to the saddle, dying away (quickly once released)
            opens = OPEN["Baritone Flying V"]
            s = string_for(opens, prev["midi"]); fret = max(0, min(22, prev["midi"] - opens[s]))
            age = t - prev["t0"]
            amp = STRING_AMP["Baritone Flying V"] * (0.4 + 0.6 * prev["lvl"]) * math.exp(-age / 0.9)
            if t > prev["t1"]:
                amp *= math.exp(-(t - prev["t1"]) / 0.12)
            held = t < prev["t1"]
            d = stop_distance(0.686, fret) if held else 0.0
            if amp > 1e-5 or d > 0:
                st["strings"] = {s: {"d": d, "disp": string_disp("Baritone Flying V", s, amp, t) if amp > 1e-5 else 0.0}}
        return st


# ─────────────────────────────── winds and brass ───────────────────────────────
# fingers down (0-6: LH index, middle, ring, RH index, middle, ring) for each semitone above the instrument's
# lowest all-fingers-down note, repeating each octave - a simplified chromatic chart
_WIND_DOWN = [6, 6, 5, 5, 4, 3, 3, 2, 2, 1, 1, 0]
_WIND_BASE = {"Flute": 62, "Clarinet": 55, "Oboe": 62, "Bassoon": 46}


class Breathing:
    """Wind and brass breathing: notes closer than PHRASE_GAP form a phrase; the player inhales just
    before it (up to half a second, less if the rest is short) and exhales steadily through it, then
    relaxes back to a resting breath. 0 = empty, 1 = full (the body's "Breath" shape key)."""
    PHRASE_GAP, REST, FULL, EMPTY = 0.35, cp.BREATH_REST, 1.0, 0.10

    def _phrases(self, notes):
        ph = []
        for n in sorted(notes, key=lambda n: n["t0"]):
            if ph and n["t0"] - ph[-1][1] < self.PHRASE_GAP:
                ph[-1][1] = max(ph[-1][1], n["t1"])
            else:
                ph.append([n["t0"], n["t1"]])
        return ph

    def _relaxed(self, t, prev_end):
        if prev_end is None:
            return self.REST
        return self.EMPTY + (self.REST - self.EMPTY) * min(1.0, max(0.0, t - prev_end) / 1.0)

    def breath(self, t):
        if not hasattr(self, "ph"):
            self.ph = self._phrases(self.notes)
        prev_end = None
        for s, e in self.ph:
            gap = s - (prev_end if prev_end is not None else -9.0)
            w = min(0.5, max(0.15, 0.8 * gap))
            if t < s - w:
                return self._relaxed(t, prev_end)
            if t < s:                                   # inhale
                base = self._relaxed(s - w, prev_end)
                u = (t - (s - w)) / w
                return base + (self.FULL - base) * u * u * (3 - 2 * u)
            if t < e:                                   # exhale through the phrase
                return self.FULL + (self.EMPTY - self.FULL) * (t - s) / max(e - s, 1e-3)
            prev_end = e
        return self._relaxed(t, prev_end)

    # Off the lips in a rest of at least LOWER_GAP s: down LOWER_AFTER s after the phrase ends (taking
    # LOWER_MOVE s), back up so it arrives LOWER_BEFORE s before the next phrase, ahead of the inhale.
    LOWER_GAP, LOWER_AFTER, LOWER_MOVE, LOWER_BEFORE = 1.6, 0.25, 0.6, 0.45

    def lowered(self, t):
        if not hasattr(self, "ph"):
            self.ph = self._phrases(self.notes)
        ss = lambda x: 0.0 if x <= 0 else 1.0 if x >= 1 else x * x * (3 - 2 * x)
        prev_end = None
        for s, e in self.ph + [[None, None]]:
            if s is None or t < s:
                if s is not None and prev_end is not None and s - prev_end < self.LOWER_GAP:
                    return 0.0
                down = 1.0 if prev_end is None else ss((t - prev_end - self.LOWER_AFTER) / self.LOWER_MOVE)
                up = 1.0 if s is None else ss((s - self.LOWER_BEFORE - t) / self.LOWER_MOVE)
                return min(down, up)
            if t < e:
                return 0.0
            prev_end = e
        return 0.0


class WindPlayer(Breathing):
    def __init__(self, key, notes):
        self.key = key; self.notes = notes

    def state(self, t):
        cur = sounding(self.notes, t)
        if not cur:
            return {"lifts": {"L": [0.004] * 4, "R": [0.004] * 4}}
        n = max(cur, key=lambda n: n["midi"])              # one note at a time: the top voice
        down = _WIND_DOWN[(n["midi"] - _WIND_BASE[self.key]) % 12]
        fl = [0.0 if i < down else 0.013 for i in range(6)]
        return {"lifts": {"L": fl[0:3] + [0.006], "R": fl[3:6] + [0.006]}}


# valve combinations for 0..6 semitones below an open partial
_VALVES3 = [(0, 0, 0), (0, 1, 0), (1, 0, 0), (1, 1, 0), (0, 1, 1), (1, 0, 1), (1, 1, 1)]
_VALVES4 = [(0, 0, 0, 0), (0, 1, 0, 0), (1, 0, 0, 0), (1, 1, 0, 0), (0, 1, 1, 0), (0, 0, 0, 1), (0, 1, 0, 1)]
_PARTIALS = {  # concert MIDI of the open-horn partials
    "Trumpet": [58, 65, 70, 74, 77, 80, 82, 84, 86, 87, 89],
    "Tuba": [34, 41, 46, 50, 53, 56, 58, 60, 62],
    "French Horn": [41, 48, 53, 57, 60, 63, 65, 67, 69, 70, 72, 74, 76, 77],
    "Trombone": [46, 53, 58, 62, 65, 68, 70, 72, 74],
}


def semis_below_partial(key, midi):
    parts = _PARTIALS[key]
    for p in parts:
        if 0 <= p - midi <= 6:
            return p - midi
    return 0


class BrassPlayer(Breathing):
    def __init__(self, key, notes):
        self.key = key; self.notes = notes

    def state(self, t):
        cur = sounding(self.notes, t)
        n = max(cur, key=lambda n: n["midi"]) if cur else last_onset(self.notes, t)
        if n is None:
            return {}
        s = semis_below_partial(self.key, n["midi"])
        if self.key == "Trombone":
            # 1st..7th position. A real slide moves ~8.5 cm per position; the puppet's arm cannot follow
            # that past 3rd, so the positions are drawn 3 cm apart and the hand stays on the brace.
            return {"slide": 0.03 * s}
        if self.key == "Tuba":
            return {"valves": list(_VALVES4[s]) if cur else [0, 0, 0, 0]}
        v = list(_VALVES3[s]) if cur else [0, 0, 0]
        if self.key == "French Horn":
            return {"valves": v + [0]}
        return {"valves": v}


def make_player(key, notes):
    if key in ("Marimba", "Marimba 2", "Vibraphone"):
        return MalletPlayer(key, notes)
    if key in ("Finger Piano", "Finger Piano 2", "Bass Finger Piano"):
        return FingerPianoPlayer(key, notes)
    if key in ("Violin", "Viola", "Cello"):
        return BowedPlayer(key, notes)
    if key == "Baritone Flying V":
        return GuitarPlayer(notes)
    if key in ("Flute", "Clarinet", "Oboe", "Bassoon"):
        return WindPlayer(key, notes)
    return BrassPlayer(key, notes)


# ─────────────────────────────── camera ───────────────────────────────
# Hand-authored cue sheets: --cues NAME, or inline --cues "0:00=Cam 1 Audience Wide;0:04.5=Cam 29 ..."
# Times are "m:ss" (or seconds); every camera must exist in the .blend (checked before rendering).
CUE_SHEETS = {
    # b421g (tempo 92, 21.4 s): both finger pianos play 0-15.5 s, then the piece rings out
    "finger_pianos": [
        ("0:00",   "Cam 6 Finger Pianos"),                       # both instruments, establishing
        ("0:02.5", "Cam 30 Bass Finger Piano Hands (front)"),    # bass busy at 1-3 s
        ("0:05",   "Cam 29 Finger Piano Hands (front)"),
        ("0:07.5", "Cam 19 Bass Finger Piano Overhead"),         # bass busy at 6-8 s
        ("0:09",   "Cam 10 Finger Piano (player view)"),         # treble's busiest second (11 notes)
        ("0:11.5", "Cam 16 Bass Finger Piano (player view)"),
        ("0:13.5", "Cam 29 Finger Piano Hands (front)"),
        ("0:15.5", "Cam 6 Finger Pianos"),                       # last plucks ringing out
        ("0:17.5", "Cam 1 Audience Wide"),
    ],
    # b421g: the marimba player's two steps (0.8 s, 1.5 s), leaning through the middle, step back at 11.7 s
    "marimba": [
        ("0:00",  "Cam 33 Marimba Player (side, full figure)"),
        ("0:04",  "Cam 4 Marimba Player POV"),
        ("0:08",  "Cam 1 Audience Wide"),
        ("0:10.5", "Cam 33 Marimba Player (side, full figure)"),
        ("0:15",  "Cam 4 Marimba Player POV"),
        ("0:18",  "Cam 1 Audience Wide"),
    ],
    # b421g_df4 (tempo 106, 56.2 s). Authored from each player's sounding time x level per 2 s:
    # strings open, horn and bassoon 10-22 s, tuba 24-30 s, marimba and finger pianos build from 24 s,
    # vibraphone and trumpet 34-50 s, flute and clarinet in the last bars.
    "b421g_56": [
        ("0:00",   "Cam 1 Audience Wide"),
        ("0:02",   "Cam 18 Flying V & Amp"),                     # guitar 0-4 s
        ("0:05",   "Cam 21 Viola & Violin"),
        ("0:08",   "Cam 32 Bass Section (guitar & bass finger piano)"),
        ("0:10.5", "Cam 26 French Horn"),                        # horn 10-16 s
        ("0:13.5", "Cam 13 Cello Close"),
        ("0:16",   "Cam 23 Bassoon Close"),                      # bassoon 12-22 s
        ("0:19",   "Cam 12 Violin Close"),
        ("0:22",   "Cam 19 Bass Finger Piano Overhead"),
        ("0:25",   "Cam 14 Tuba Close"),                         # tuba 24-30 s
        ("0:27.5", "Cam 33 Marimba Player (side, full figure)"), # marimba enters and builds
        ("0:30.5", "Cam 28 Flute (second row)"),                 # flute 30-34 s
        ("0:33",   "Cam 29 Finger Piano Hands (front)"),
        ("0:35.5", "Cam 25 Vibraphone Player View"),             # vibes 34-48 s
        ("0:38",   "Cam 1 Audience Wide"),
        ("0:40.5", "Cam 4 Marimba Player POV"),                  # marimba's loudest stretch
        ("0:43",   "Cam 12 Violin Close"),                       # violin's loudest stretch
        ("0:45",   "Cam 22 Trumpet Hands"),                      # trumpet 44-50 s
        ("0:47.5", "Cam 10 Finger Piano (player view)"),
        ("0:49.5", "Cam 34 Oboe Player"),                        # oboe's last phrase, then off the lips at 51.5 s
        ("0:52.5", "Cam 15 Bassoon & Clarinet (riser)"),         # clarinet 52-54 s
        ("0:54",   "Cam 1 Audience Wide"),
    ],
    # a tour of the players, for checking poses (b421g length; works for any piece of 20 s or more)
    "details": [
        ("0:00",  "Cam 32 Bass Section (guitar & bass finger piano)"),
        ("0:02.5", "Cam 29 Finger Piano Hands (front)"),
        ("0:05",  "Cam 28 Flute (second row)"),
        ("0:07",  "Cam 15 Bassoon & Clarinet (riser)"),
        ("0:09",  "Cam 7 Oboe Keys"),
        ("0:11",  "Cam 26 French Horn"),
        ("0:13",  "Cam 31 Trombone Hands"),
        ("0:15",  "Cam 18 Flying V & Amp"),
        ("0:17",  "Cam 21 Viola & Violin"),
        ("0:19",  "Cam 1 Audience Wide"),
    ],
}


def cue_seconds(s):
    s = str(s).strip()
    if ":" in s:
        m, sec = s.split(":", 1)
        return int(m) * 60 + float(sec)
    return float(s)


def parse_cues(spec):
    """A named sheet or an inline 'time=camera;time=camera' list -> [(seconds, camera)], checked."""
    if spec in CUE_SHEETS:
        cues = CUE_SHEETS[spec]
    else:
        cues = [tuple(x.split("=", 1)) for x in spec.split(";") if x.strip()]
    shots = sorted((cue_seconds(t), cam.strip()) for t, cam in cues)
    missing = [c for _, c in shots if c not in bpy.data.objects or bpy.data.objects[c].type != 'CAMERA']
    if missing:
        raise SystemExit(f"[concert] cue sheet names cameras not in the .blend: {missing}")
    return shots
def build_shots(per, duration, seed, fixed=None):
    """[(t_start, camera name)]: the loudest players get the close shots, a wide every third shot."""
    if fixed:
        return [(0.0, fixed)]
    rng = random.Random(seed)
    shots = [(0.0, WIDE_CAMS[0])]
    t = min(3.5, duration / 4)
    k = 1
    recent = []                                               # players featured lately, to spread the close-ups
    while t < duration - 1.5:
        hold = rng.uniform(3.0, 5.5)
        if k % 4 == 0:
            cam = rng.choice([c for c in WIDE_CAMS[:3] if c != shots[-1][1]])
        else:
            loud = []
            for player, ns in per.items():
                if player not in PLAYER_CAMS or player in recent[-2:]:
                    continue
                e = sum(n["lvl"] * max(0.0, min(n["t1"], t + hold) - max(n["t0"], t)) for n in ns)
                if e > 0.25 * hold:                           # sounding for a real share of the shot
                    loud.append((e, player))
            loud.sort(reverse=True)
            if not loud:
                cam = rng.choice([c for c in WIDE_CAMS[:3] if c != shots[-1][1]])
            else:
                player = rng.choice([p for _, p in loud[:3]])
                recent.append(player)
                cam = rng.choice([c for c in PLAYER_CAMS[player] if c != shots[-1][1]] or PLAYER_CAMS[player])
        shots.append((t, cam))
        t += hold; k += 1
    return shots


def shot_at(shots, t):
    cur = shots[0][1]
    for t0, cam in shots:
        if t0 <= t:
            cur = cam
    return cur


# ─────────────────────────────── main ───────────────────────────────
def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--npy", required=True)
    p.add_argument("--tempo", type=float, required=True)
    p.add_argument("--duration", type=float, required=True)
    p.add_argument("--out", default="frames_concert")
    p.add_argument("--res-x", type=int, default=1280)
    p.add_argument("--res-y", type=int, default=720)
    p.add_argument("--engine", choices=("eevee", "cycles"), default="eevee")
    p.add_argument("--samples", type=int, default=64)
    p.add_argument("--cycles-hw-rt", action="store_true")
    p.add_argument("--gpu-name", default="Arc")
    p.add_argument("--frame-start", type=int, default=0)
    p.add_argument("--frame-end", type=int, default=None)
    p.add_argument("--camera", default=None, help="hold one camera for the whole render")
    p.add_argument("--cues", default=None, help=f"cue sheet: one of {sorted(CUE_SHEETS)} or 'm:ss=Camera;m:ss=Camera'")
    p.add_argument("--seed", type=int, default=7, help="camera generator seed")
    p.add_argument("--autogen", action="append", default=None, help="accepted for render_farm.sh compatibility; start:end:seed")
    p.add_argument("--list-voices", action="store_true", help="print the voice map and exit")
    args, unknown = p.parse_known_args(argv)
    if unknown:
        print(f"[concert] ignoring blender_stage.py-only options: {' '.join(unknown)}")
    if args.autogen:
        args.seed = int(args.autogen[0].split(":")[2])
    return args


def configure_engine(scene, args):
    if args.engine != "cycles":
        for name in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
            try:
                scene.render.engine = name
                return
            except TypeError:
                continue
        return
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "ONEAPI"
    prefs.refresh_devices()
    if hasattr(prefs, "use_oneapirt"):
        prefs.use_oneapirt = bool(args.cycles_hw_rt)
    chosen = []
    for d in prefs.devices:
        d.use = d.type == "ONEAPI" and (args.gpu_name == "any" or args.gpu_name in d.name)
        if d.use:
            chosen.append(d.name)
    if not chosen:
        raise SystemExit(f"[concert] no oneAPI GPU matching {args.gpu_name!r}")
    scene.render.engine = "CYCLES"
    scene.cycles.device = "GPU"; scene.cycles.samples = args.samples
    scene.cycles.use_denoising = True; scene.cycles.denoiser = "OPENIMAGEDENOISE"
    print(f"[concert] Cycles on {chosen}, {args.samples} samples")


class Performance:
    """Everything needed to put the stage into the state of one moment of a piece. Used by the farm render
    (main, below) and by concert_preview.py, so the Blender viewport shows exactly what gets rendered."""

    def __init__(self, npy, tempo, duration, cues=None, seed=7, camera=None):
        cp.load_layout()
        self.per = load_notes(npy, tempo)
        self.players = {key: make_player(key, ns) for key, ns in self.per.items() if key in cp.PLAYERS}
        for pl in self.players.values():
            if isinstance(pl, GuitarPlayer):
                pl.tempo = tempo
        self.puppets = {key: cp.get_puppet(key) for key in cp.PLAYERS}
        self.shots = parse_cues(cues) if cues else build_shots(self.per, duration, seed, camera)
        self.lights = {k: bpy.data.objects.get(v) for k, v in SPECIAL_LIGHT.items()}
        # over-the-shoulder cameras ride along with a player who steps sideways
        self.follow = {PLAYER_CAMS[k][0]: k for k in ("Marimba", "Marimba 2", "Vibraphone") if k in cp.PLAYERS}
        self.follow_base = {c: bpy.data.objects[c].location.copy() for c in self.follow}

    def apply(self, scene, t, set_camera=True):
        for key in cp.PLAYERS:
            pl = self.players.get(key)
            st = pl.state(t) if pl else None
            if isinstance(pl, Breathing):
                st = dict(st or {}); st["breath"] = pl.breath(t); st["lower"] = pl.lowered(t)
            cp.pose(key, st, self.puppets[key])
            for cam, who in self.follow.items():
                if who == key:
                    bpy.data.objects[cam].location = self.follow_base[cam] + Vector((st or {}).get("body_shift", (0, 0, 0)))
            lt = self.lights.get(key)
            if lt:
                lt["level"] = 0.45 + 1.1 * (envelope(self.per[key], t) if key in self.per else 0.0)
        if set_camera:
            scene.camera = bpy.data.objects[shot_at(self.shots, t)]

    def restore(self):
        """Back to the rest pose, lights at level 1, cameras home (for saving the .blend)."""
        for key in cp.PLAYERS:
            cp.pose(key, None, self.puppets[key])
        for k in ("Finger Piano", "Finger Piano 2", "Bass Finger Piano"):
            cp.set_tine_bends(k, {})
        for cam, loc in self.follow_base.items():
            bpy.data.objects[cam].location = loc
        for lt in self.lights.values():
            if lt:
                lt["level"] = 1.0


def main():
    sys.stdout.reconfigure(line_buffering=True)               # so the pod log shows progress as it happens
    args = parse_args()
    t_start = time.time()
    if args.list_voices:
        for v, (pl, art) in sorted(VOICES.items()):
            print(f"  voice {v:3d} -> {pl} ({art})")
        return
    scene = bpy.data.scenes["Concert Stage"]
    if bpy.context.window_manager.windows:                    # interactive session; --background has none
        bpy.context.window_manager.windows[0].scene = scene
    scene.render.use_sequencer = False                        # a preview's sound strip must never replace the 3D render
    perf = Performance(args.npy, args.tempo, args.duration, args.cues, args.seed, args.camera)
    print("[concert] camera shots: " + ", ".join(f"{int(t0 // 60)}:{t0 % 60:04.1f} {c}" for t0, c in perf.shots))

    configure_engine(scene, args)
    scene.render.resolution_x, scene.render.resolution_y = args.res_x, args.res_y
    scene.render.resolution_percentage = 100
    scene.render.fps = FPS
    scene.render.image_settings.file_format = 'PNG'
    n_frames = int(math.ceil(args.duration * FPS - 1e-9))
    f0 = max(0, args.frame_start)
    f1 = n_frames - 1 if args.frame_end is None else min(args.frame_end, n_frames - 1)
    out = Path(args.out); out.mkdir(parents=True, exist_ok=True)
    print(f"[concert] animating frames {f0}..{f1} of {n_frames} ({args.duration:.1f}s @ {FPS}fps) -> {out}/")
    # Resume: frames already in --out are kept (a relaunched slice after a crash only renders what is
    # missing). The newest one in the range is redone, in case the crash cut its write short.
    have = {fi for fi in range(f0, f1 + 1) if (out / f"frame_{fi:06d}.png").is_file()
            and (out / f"frame_{fi:06d}.png").stat().st_size > 0}
    have.discard(max(have, default=-1))
    if have:
        print(f"[concert] {len(have)} frames already rendered in {f0}..{f1}: skipping them")
    r0 = time.time()
    for fi in range(f0, f1 + 1):
        if fi in have:
            continue
        t = fi / FPS
        scene.frame_set(fi)                                   # backdrop colour runs off the frame number
        perf.apply(scene, t)
        scene.render.filepath = str(out / f"frame_{fi:06d}.png")
        bpy.ops.render.render(write_still=True, scene=scene.name)
        if fi % 30 == 0:
            print(f"  frame {fi}/{n_frames}  t={t:.2f}s  elapsed={time.time() - r0:.1f}s")
    total = time.time() - r0
    n = f1 - f0 + 1
    print(f"[stage] done: {n} frames in {total:.1f}s ({total / max(n, 1):.3f}s/frame), total {time.time() - t_start:.1f}s")


if __name__ == "__main__":
    main()
