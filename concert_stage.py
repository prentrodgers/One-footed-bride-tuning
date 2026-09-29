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
VOICE_NAMES = {6: "xylophone", 8: "harp", 21: "Super Slinky", 22: "long string", 23: "original string",
               28: "triangle wave", 29: "Bosendorfer"}

# camera shots that feature each player (the first is preferred), and the wide shots
PLAYER_CAMS = {
    "Marimba": ["Cam 4 Marimba Player POV"], "Vibraphone": ["Cam 25 Vibraphone Player View"],
    "Violin": ["Cam 12 Violin Close", "Cam 21 Viola & Violin"], "Viola": ["Cam 21 Viola & Violin"],
    "Cello": ["Cam 13 Cello Close", "Cam 5 Cello & Violin"],
    "Baritone Flying V": ["Cam 18 Flying V & Amp", "Cam 20 Baritone Full String Length", "Cam 11 Fretboard Close"],
    "Finger Piano": ["Cam 10 Finger Piano (player view)", "Cam 6 Finger Pianos"],
    "Bass Finger Piano": ["Cam 19 Bass Finger Piano Overhead", "Cam 16 Bass Finger Piano (player view)"],
    "Flute": ["Cam 28 Flute (second row)"], "Clarinet": ["Cam 15 Bassoon & Clarinet (riser)"], "Oboe": ["Cam 7 Oboe Keys"],
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
    """Four mallets (L outer, L inner, R inner, R outer); each note goes to the nearest free mallet."""
    ORDER = [("L", 1), ("L", 0), ("R", 0), ("R", 1)]          # (side, 0=inner 1=outer), low to high pitch

    def __init__(self, key, notes):
        self.key = key
        self.pts = bar_points(key)
        lo, hi = min(self.pts), max(self.pts)
        rest = cp.mallet_heads_rest(key)
        self.rest = {(s, i): rest[s][i] for s in ("L", "R") for i in (0, 1)}
        self.top = {m: p.z for m, p in self.pts.items()}
        pos = dict(self.rest)
        self.strikes = {k: [] for k in self.rest}               # mallet -> [(t, point)]
        busy = {k: -1.0 for k in self.rest}
        i = 0
        while i < len(notes):                                  # chords: notes starting within 30 ms
            chord = [notes[i]]
            while i + len(chord) < len(notes) and notes[i + len(chord)]["t0"] - notes[i]["t0"] < 0.03:
                chord.append(notes[i + len(chord)])
            i += len(chord)
            chord.sort(key=lambda n: n["midi"])
            free = [k for k in self.ORDER]
            for n in chord:
                p = self.pts[fold(n["midi"], lo, hi)]
                # pitch low -> high runs +x -> -x on these instruments (low notes on the player's left)
                k = min(free, key=lambda k: (pos[k] - p).length + (0.5 if busy[k] > n["t0"] - 0.08 else 0.0))
                free.remove(k)
                self.strikes[k].append((n["t0"], p)); pos[k] = p; busy[k] = n["t0"]
                if not free:
                    break

    def head(self, k, t):
        hs = self.strikes[k]
        rest = self.rest[k]
        hover = rest.z - (min(self.top.values()))              # hover height above the bars
        prev = None; nxt = None
        for s in hs:
            if s[0] <= t:
                prev = s
            else:
                nxt = s; break
        base = prev[1] if prev else rest
        xy = Vector((base.x, base.y, 0))
        if nxt:
            gap = nxt[0] - (prev[0] if prev else nxt[0] - 1.0)
            move = min(0.25, gap * 0.6)
            u = (t - (nxt[0] - move)) / move
            if u > 0:
                u = u * u * (3 - 2 * u)
                xy = xy.lerp(Vector((nxt[1].x, nxt[1].y, 0)), u)
        contact_z = (nxt[1].z if nxt else base.z) + 0.021
        z = (base.z if prev else rest.z - hover) + hover
        if nxt and 0 < nxt[0] - t < 0.15:                     # backswing then strike
            u = 1 - (nxt[0] - t) / 0.15
            z = contact_z + (z - contact_z) * (1 - u) + 0.07 * math.sin(math.pi * u)
        elif prev and t - prev[0] < 0.12:                     # rebound
            u = (t - prev[0]) / 0.12
            z = (prev[1].z + 0.021) + ((prev[1].z + hover) - (prev[1].z + 0.021)) * u
        return Vector((xy.x, xy.y, z))

    def state(self, t):
        return {"heads": {s: (self.head((s, 0), t), self.head((s, 1), t)) for s in ("L", "R")}}


# ─────────────────────────────── finger pianos ───────────────────────────────
class FingerPianoPlayer:
    """Piano-style: each hand keeps a five-tine position that follows its notes; the finger on a sounding tine presses it."""

    def __init__(self, key, notes):
        self.key = key
        self.tines = cp.fp_tines(key)
        self.midis = [n["midi"] for n in self.tines]
        self.nat = [n["midi"] for n in self.tines if not n["acc"]]
        lo, hi = self.midis[0], self.midis[-1]
        self.split = (lo + hi) // 2
        self.notes = [dict(n, m=fold(n["midi"], lo, hi)) for n in notes]

    def _window(self, side, t):
        near = [n["m"] for n in self.notes if abs(n["t0"] - t) < 0.6 and ((n["m"] < self.split) == (side == "L"))]
        if side == "L":
            anchor = min(near) if near else self.nat[7]
            j = max(0, min(len(self.nat) - 5, max(i for i, m in enumerate(self.nat) if m <= anchor)))
            return self.nat[j:j + 5]
        anchor = max(near) if near else self.nat[20]
        j = min(len(self.nat) - 1, min(i for i, m in enumerate(self.nat) if m >= anchor))
        j = max(4, j)
        return self.nat[j - 4:j + 1]

    def state(self, t):
        st = {"press": {}}
        for side in ("L", "R"):
            win = self._window(side, t)                      # five naturals, low to high
            if side == "L":                                   # pinky lowest, thumb highest
                fingers, thumb = list(reversed(win[:4])), win[4]
            else:                                             # thumb lowest, pinky highest
                fingers, thumb = win[1:], win[0]
            for n in sounding(self.notes, t):
                if (n["m"] < self.split) != (side == "L"):
                    continue
                m = n["m"]
                if m in fingers or m == thumb:
                    pass
                else:                                         # an accidental or out-of-window note: nearest finger takes it
                    k = min(range(4), key=lambda i: abs(fingers[i] - m))
                    fingers[k] = m
                age = t - n["t0"]
                st["press"][m] = max(st["press"].get(m, 0.0), 1.0 if age < 0.15 else 0.6)
            st[side] = fingers; st[side + "_thumb"] = thumb
        return st


# ─────────────────────────────── strings ───────────────────────────────
OPEN = {"Violin": [55, 62, 69, 76], "Viola": [48, 55, 62, 69], "Cello": [36, 43, 50, 57],
        "Baritone Flying V": [35, 40, 45, 50, 54, 59]}
SCALE_LEN = {"Violin": 0.328, "Viola": 0.328, "Cello": 0.690}        # in each rig's own units (viola rig is scaled 1.15)


def string_for(opens, midi):
    s = 0
    for i, o in enumerate(opens):
        if midi >= o:
            s = i
    return s


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

    def state(self, t):
        cur = [p for p in self.plan if p[0]["t0"] <= t < p[0]["t1"] + 0.05]
        st = {}
        if cur:
            n, a, b = cur[-1]
            u = min(1.0, (t - n["t0"]) / max(n["dur"], 1e-3))
            st["frog_dist"] = a + (b - a) * u
            s = string_for(self.opens, n["midi"])
            st["bow_string"] = s
            semis = n["midi"] - self.opens[s]
            if semis > 0:
                d = SCALE_LEN[self.key] * (1 - 2 ** (-semis / 12))
                finger = min(3, max(0, (semis - 1) // 2))
                shift = max(0.0, d - [0.034, 0.060, 0.084, 0.104][finger] * (SCALE_LEN[self.key] / 0.328))
                stops = []
                for i in range(4):
                    if i == finger:
                        stops.append((d, s, 0.0))
                    else:
                        di = max(0.01, d + (i - finger) * 0.025 * SCALE_LEN[self.key] / 0.328)
                        stops.append((di, s, 0.010))
                st["stops"] = stops; st["shift"] = shift
        else:
            prev = last_onset([p[0] for p in self.plan], t)
            if prev is not None:
                pl = [p for p in self.plan if p[0] is prev][0]
                st["frog_dist"] = pl[2]
        return st


class GuitarPlayer:
    def __init__(self, notes):
        self.notes = notes

    def state(self, t):
        st = {}
        cur = sounding(self.notes, t)
        if cur:
            n = max(cur, key=lambda n: n["midi"])
            opens = OPEN["Baritone Flying V"]
            s = string_for(opens, n["midi"])
            fret = n["midi"] - opens[s]
            while fret > 20 and s < 5:
                s += 1; fret = n["midi"] - opens[s]
            fret = max(0, min(22, fret))
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
        return st


# ─────────────────────────────── winds and brass ───────────────────────────────
# fingers down (0-6: LH index, middle, ring, RH index, middle, ring) for each semitone above the instrument's
# lowest all-fingers-down note, repeating each octave - a simplified chromatic chart
_WIND_DOWN = [6, 6, 5, 5, 4, 3, 3, 2, 2, 1, 1, 0]
_WIND_BASE = {"Flute": 62, "Clarinet": 55, "Oboe": 62, "Bassoon": 46}


class WindPlayer:
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


class BrassPlayer:
    def __init__(self, key, notes):
        self.key = key; self.notes = notes

    def state(self, t):
        cur = sounding(self.notes, t)
        n = max(cur, key=lambda n: n["midi"]) if cur else last_onset(self.notes, t)
        if n is None:
            return {}
        s = semis_below_partial(self.key, n["midi"])
        if self.key == "Trombone":
            return {"slide": 0.085 * s}                        # 1st..7th position
        if self.key == "Tuba":
            return {"valves": list(_VALVES4[s]) if cur else [0, 0, 0, 0]}
        v = list(_VALVES3[s]) if cur else [0, 0, 0]
        if self.key == "French Horn":
            return {"valves": v + [0]}
        return {"valves": v}


def make_player(key, notes):
    if key in ("Marimba", "Vibraphone"):
        return MalletPlayer(key, notes)
    if key in ("Finger Piano", "Bass Finger Piano"):
        return FingerPianoPlayer(key, notes)
    if key in ("Violin", "Viola", "Cello"):
        return BowedPlayer(key, notes)
    if key == "Baritone Flying V":
        return GuitarPlayer(notes)
    if key in ("Flute", "Clarinet", "Oboe", "Bassoon"):
        return WindPlayer(key, notes)
    return BrassPlayer(key, notes)


# ─────────────────────────────── camera ───────────────────────────────
def build_shots(per, duration, seed, fixed=None):
    """[(t_start, camera name)]: the loudest players get the close shots, a wide every third shot."""
    if fixed:
        return [(0.0, fixed)]
    rng = random.Random(seed)
    shots = [(0.0, WIDE_CAMS[0])]
    t = min(4.0, duration / 3)
    k = 1
    while t < duration - 1.0:
        hold = rng.uniform(4.0, 8.0)
        if k % 3 == 0:
            shots.append((t, rng.choice(WIDE_CAMS[:3])))
        else:
            loud = []
            for player, ns in per.items():
                if player not in PLAYER_CAMS:
                    continue
                e = sum(n["lvl"] * max(0.0, min(n["t1"], t + hold) - max(n["t0"], t)) for n in ns)
                if e > 0:
                    loud.append((e, player))
            loud.sort(reverse=True)
            if loud:
                player = rng.choice([p for _, p in loud[:3]])
                cam = rng.choice(PLAYER_CAMS[player])
                if cam == shots[-1][1]:
                    cam = WIDE_CAMS[0]
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


def main():
    args = parse_args()
    t_start = time.time()
    if args.list_voices:
        for v, (pl, art) in sorted(VOICES.items()):
            print(f"  voice {v:3d} -> {pl} ({art})")
        return
    scene = bpy.data.scenes["Concert Stage"]
    if bpy.context.window_manager.windows:                    # interactive session; --background has none
        bpy.context.window_manager.windows[0].scene = scene
    cp.load_layout()
    per = load_notes(args.npy, args.tempo)
    players = {key: make_player(key, ns) for key, ns in per.items() if key in cp.PLAYERS}
    puppets = {key: cp.get_puppet(key) for key in cp.PLAYERS}
    shots = build_shots(per, args.duration, args.seed, args.camera)
    print("[concert] camera shots: " + ", ".join(f"{int(t0 // 60)}:{t0 % 60:04.1f} {c}" for t0, c in shots))
    lights = {k: bpy.data.objects.get(v) for k, v in SPECIAL_LIGHT.items()}

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
    r0 = time.time()
    for fi in range(f0, f1 + 1):
        t = fi / FPS
        scene.frame_set(fi)                                   # backdrop colour runs off the frame number
        for key in cp.PLAYERS:
            pl = players.get(key)
            cp.pose(key, pl.state(t) if pl else None, puppets[key])
            lt = lights.get(key)
            if lt:
                lt["level"] = 0.45 + 1.1 * (envelope(per[key], t) if key in per else 0.0)
        scene.camera = bpy.data.objects[shot_at(shots, t)]
        scene.render.filepath = str(out / f"frame_{fi:06d}.png")
        bpy.ops.render.render(write_still=True, scene=scene.name)
        if fi % 30 == 0:
            print(f"  frame {fi}/{n_frames}  t={t:.2f}s  elapsed={time.time() - r0:.1f}s")
    total = time.time() - r0
    n = f1 - f0 + 1
    print(f"[stage] done: {n} frames in {total:.1f}s ({total / max(n, 1):.3f}s/frame), total {time.time() - t_start:.1f}s")


if __name__ == "__main__":
    main()
