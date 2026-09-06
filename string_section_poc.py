#!/usr/bin/env python3
"""
string_section_poc.py — 8 invisible string players on a concert stage.

Each player holds a floating instrument (violin / viola / cello).  When a
note fires, a bow sweeps across the strings (martelé) or a fingertip
approaches and plucks (pizzicato).  The players themselves are invisible.

Voice map (from adaptive_tuning_util.init_voice_time):
  2 = vlip*   violin  pizzicato   → 3 violin  seats, split by pitch
  3 = vlap*   viola   pizzicato   → 2 viola   seats, split by pitch
  4 = celp*   cello   pizzicato   → 2 cello   seats, split by pitch
  9 = vlim*   violin  martelé     → 1 martelé seat  (all pitches)

Usage:
  python string_section_poc.py --npy bwv261_features_array.npy --tempo 110
  python string_section_poc.py --stage 2           # re-render frames only
  python string_section_poc.py --stage 3 --mp3 …            # explicit audio
  python string_section_poc.py --stage 3 --chorale bwv261   # newest Uploads mp3
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.transforms as mtransforms
from matplotlib.patches import Polygon as MplPolygon, Ellipse, Circle, Rectangle
import librosa

import uploads_lookup
import stage_layout as stage
import string_length as sl

import logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%d %H:%M")
log = logging.getLogger(__name__)

# ── Constants ─────────────────────────────────────────────────────────────────
DEFAULT_NPY   = "bwv261_features_array.npy"
DEFAULT_TEMPO = 110.0
DEFAULT_MP3   = None

FRAMES_DIR = "str_frames"
NOTES_FILE = "str_notes.npy"
VIDEO_OUT  = "str_poc.mp4"

FPS = 30
W, H = 1280, 720
DPI  = 96
# Output frames are rasterized at 2x density (2560x1440) for a sharper
# render — see marimba_poc.SAVE_DPI for why only this (not W/H/DPI/figsize)
# changes.
SAVE_DPI = DPI * 2

# Instrument tilt: 30° back (foreshortening) + 20° left (neck leans upper-left)
BACK_TILT = 30   # degrees — face of instrument tilts away from audience
LEFT_TILT = 20   # degrees — neck tilts toward player's left shoulder

# Pre-computed: where the body bottom lands in screen space (for label placement)
_TILT_SX = np.cos(np.radians(BACK_TILT)) * np.sin(np.radians(LEFT_TILT))  # ≈ 0.296
_TILT_SY = np.cos(np.radians(BACK_TILT)) * np.cos(np.radians(LEFT_TILT))  # ≈ 0.814

BG_COLOR   = (0.06, 0.07, 0.09)
STAGE_CLR  = (0.10, 0.11, 0.14)   # subtle stage floor behind instruments
LABEL_CLR  = (0.44, 0.48, 0.58)

PIZZ_VOICES   = frozenset([2, 3, 4])
MARTEL_VOICES = frozenset([9])
ALL_VOICES    = PIZZ_VOICES | MARTEL_VOICES

# ── Player seats ──────────────────────────────────────────────────────────────
# Consolidated from 8 seats (3 violin pizz + 2 viola pizz + 2 cello pizz + 1
# martelé, each a pitch-band slice of its voice) down to 4 — one per voice.
# Every instrument's existing per-note string-selection logic (_note_to_str,
# which favors the lowest string that can reach a note within a realistic
# fingerboard position) already handles a full pitch range across just 4
# strings, so one seat per voice needs no p_lo/p_hi pitch-band splitting.
# Layout: y=0 at top; back row (cello/viola) above the front row
# (martelé/violin pizz). sc = perspective scale factor, except viola/cello
# no longer share the violin/martelé's — the string family's real
# proportions (viola ~15% bigger-bodied than violin, cello bigger still)
# now win over back-row-is-farther-so-smaller perspective.
SCALE_VIOLIN = 0.85
SCALE_VIOLA  = SCALE_VIOLIN * 1.15   # ~15% bigger than the violins
SCALE_CELLO  = SCALE_VIOLIN * 1.35   # comfortably bigger than the viola

# stage.ROW_BACK_Y_FAR (75) is shared with marimba_section_poc.py, so it's
# left untouched; the back row here uses its own, much lower, local cy
# instead — at the old cy the enlarged cello's scroll/neck (~144 units of
# headroom needed above its centre) was clipped off the top of the canvas
# (y=0).
#
# That doesn't leave room to also push the front row down far enough to
# clear the (now much taller) back row vertically before running into
# finger_piano_section_poc.py's tine rack (its topmost content measured at
# screen_y ~264, right below this section). Instead the front row stays at
# a modest cy and gets pulled well clear *horizontally* of the back-row
# instrument in its path instead — the two rows' bounding boxes overlap in
# y, but never in x, so nothing actually touches regardless. x-ranges below
# are the actual rendered bounding boxes (post-tilt-transform, measured via
# get_window_extent — the tilt rotation shifts an instrument's footprint
# well past its raw cx +/- bw): Cello 80-178, Viola 238-300, Martele 16-63,
# Violin 184-231 — each with >5px clearance from its neighbours.
STR_BACK_Y  = 150
STR_FRONT_Y = 200

PLAYERS = [
    dict(id=0, name='Cello',  voice=4, inst='cello',  cx=130, cy=STR_BACK_Y,  sc=SCALE_CELLO, p_lo=None, p_hi=None),
    dict(id=1, name='Viola',  voice=3, inst='viola',  cx=270, cy=STR_BACK_Y,  sc=SCALE_VIOLA, p_lo=None, p_hi=None),
    # Pulled clear of the back row's x-span (see note above) rather than
    # just nudged off it — the old 40-unit stagger isn't enough at these
    # bigger sizes.
    dict(id=2, name='Martele', voice=9, inst='violin', cx=40,  cy=STR_FRONT_Y, sc=SCALE_VIOLIN, p_lo=None, p_hi=None),
    dict(id=3, name='Violin', voice=2, inst='violin', cx=208, cy=STR_FRONT_Y, sc=SCALE_VIOLIN, p_lo=None, p_hi=None),
]

# ── Instrument specs (at scale=1.0) ──────────────────────────────────────────
# bw/bh = half body width/height; neck_w/h = half-width/height of neck
# str_s = spacing between adjacent strings
# open_cents = approx open-string pitches G/D/A/E (or C/G/D/A)
INST_SPEC = {
    'violin': dict(bw=19, bh=52, neck_w=6,  neck_h=24, waist=0.50,
                   str_s=5.5, n_str=4,
                   wood=(0.62, 0.40, 0.18), scroll_r=4,
                   open_cents=[4300, 5000, 5700, 6400]),
    'viola':  dict(bw=22, bh=60, neck_w=7,  neck_h=28, waist=0.51,
                   str_s=6.2, n_str=4,
                   wood=(0.58, 0.36, 0.14), scroll_r=5,
                   open_cents=[3600, 4300, 5000, 5700]),
    'cello':  dict(bw=30, bh=78, neck_w=10, neck_h=36, waist=0.52,
                   str_s=8.0, n_str=4,
                   wood=(0.52, 0.32, 0.12), scroll_r=7,
                   open_cents=[2400, 3100, 3800, 4500]),
}

# ── Gesture timing ────────────────────────────────────────────────────────────
GLOW_DECAY   = 0.26   # seconds

# Pizzicato pluck — a small fingertip shape (elongated ellipse), not a
# plain circle, and smaller than the old fixed radius.
PLK_ARM      = 46     # px — finger rest distance to right of body edge
PLK_FINGER_W = 3.5    # px — fingertip width at scale=1.0
PLK_FINGER_H = 7.0     # px — fingertip length at scale=1.0
PLK_APP_T    = 0.055
PLK_DWL_T    = 0.025
PLK_RET_T    = 0.130

# Martelé bow
BOW_H        = 6      # px — hair thickness
BOW_SWEEP    = 44     # px — horizontal sweep distance
BOW_APP_T    = 0.028
BOW_DWL_T    = 0.052
BOW_RET_T    = 0.075

# String vibration
VIB_FREQ     = 8.0    # visual Hz (same for all strings; looks good)
TAU_PIZZ     = 0.28
TAU_MARTEL   = 0.10


# ── Stage 1: load notes ───────────────────────────────────────────────────────

def load_string_voices(npy_file, tempo, voices=None):
    """Load all string section voices → N×6 array.
    Columns: [start_s, pitch_cents, dur_s, vel, vol, voice_id]
    """
    if voices is None:
        voices = ALL_VOICES
    log.info(f"\n[Stage 1] Loading {npy_file}")
    arr = np.load(npy_file)

    # Audibility + voice filter
    mask = (arr[:, 5] > 0) & (arr[:, 2] > 0) & (arr[:, 14] > 0) & (arr[:, 3] > 0)
    vm = np.zeros(len(arr), dtype=bool)
    for v in voices:
        vm |= (arr[:, 6].astype(int) == v)
    mask &= vm
    arr = arr[mask]
    if not len(arr):
        log.warning(f"  no notes found for voices {voices} — section will render empty")
        notes = np.zeros((0, 6))
        np.save(NOTES_FILE, notes)
        return notes, 2.0

    bps = tempo / 60.0
    notes = np.column_stack([
        arr[:, 1] / bps,           # start_s
        arr[:, 5] * 1200 + arr[:, 4],  # pitch_cents
        arr[:, 2] / bps,           # dur_s
        arr[:, 3],                  # velocity
        arr[:, 14],                 # volume
        arr[:, 6],                  # voice_id
    ])
    notes = notes[notes[:, 0].argsort()]
    np.save(NOTES_FILE, notes)

    duration = float(notes[:, 0].max() + notes[:, 2].max()) + 2.0
    voice_names = {2:'Vl.Pizz', 3:'Va.Pizz', 4:'Vc.Pizz', 9:'Martelé'}
    for v in sorted(voices):
        n = (notes[:, 5].astype(int) == v).sum()
        log.info(f"  voice {v} ({voice_names.get(v,'?')}): {n} notes")
    log.info(f"  total {len(notes)} notes,  duration {duration:.1f}s")
    return notes, duration


def build_player_note_sets(notes, players):
    """Route each note to the player that owns its voice+pitch range."""
    sets = {p['id']: [] for p in players}
    for row in notes:
        v = int(row[5])
        p = float(row[1])
        for pl in players:
            if pl['voice'] != v:
                continue
            lo = pl.get('p_lo')
            hi = pl.get('p_hi')
            if (lo is None or p >= lo) and (hi is None or p < hi):
                sets[pl['id']].append(row)
                break
    return {k: (np.array(v) if v else np.zeros((0, 6))) for k, v in sets.items()}


# ── Instrument geometry ───────────────────────────────────────────────────────

def _body_outline(cx, cy, bw, bh, waist):
    """Polygon points for a simplified violin/viola/cello body (hourglass)."""
    w = waist  # waist half-width as fraction of bw
    # Right-side key points (dx, dy) relative to body centre
    # dy positive = downward (y=0 at top convention)
    rp = np.array([
        [0.00,   -bh   ],   # top centre
        [0.42*bw,-bh*.84],  # top shoulder
        [bw,     -bh*.54],  # upper bout
        [bw,     -bh*.30],
        [w*bw,   -bh*.06],  # upper waist
        [w*bw,    bh*.06],  # lower waist
        [bw,      bh*.22],
        [bw,      bh*.52],  # lower bout
        [0.80*bw, bh*.82],
        [0.32*bw, bh   ],   # bottom shoulder
        [0.00,    bh   ],   # bottom centre
    ])
    right = rp + np.array([cx, cy])
    left  = right.copy()
    left[:, 0] = 2*cx - right[:, 0]
    return np.vstack([right, np.flipud(left[1:-1])])


def _str_xs(cx, spec, scale):
    """X positions of the 4 strings on an instrument."""
    s = spec['str_s'] * scale
    return [cx + (i - 1.5) * s for i in range(4)]


OPEN_SLACK = 50  # cents a note may sit below an open pitch and still be that open string


def _note_to_str(pitch_cents, inst_type):
    """Which of the 4 strings (0=lowest) a player would use for this pitch.

    The HIGHEST string whose open pitch is at or below the note, so the stop
    lands as near the nut as possible; a player shifts up a low string only
    when no higher string reaches the note. Notes below the lowest open
    string fall back to that string, played open.
    """
    opens = INST_SPEC[inst_type]['open_cents']
    for i in range(len(opens) - 1, -1, -1):
        if pitch_cents >= opens[i] - OPEN_SLACK:
            return i
    return 0


def _make_tilt_xform(cx, cy, ax):
    """
    Affine transform that tilts a vertical instrument into playing position:
      • foreshorten y by cos(BACK_TILT)  — back-tilt makes body look shallower
      • rotate −LEFT_TILT degrees          — in screen coords (y=0 at top) a
        negative rotation tilts the neck toward upper-left, as a player holds it
    Transform is in data space and composed with ax.transData.
    """
    return (mtransforms.Affine2D()
            .translate(-cx, -cy)
            .scale(1.0, np.cos(np.radians(BACK_TILT)))
            .rotate_deg(-LEFT_TILT)
            .translate(cx, cy)
            + ax.transData)


# ── State computation ─────────────────────────────────────────────────────────

def compute_state(t, player_notes_sets, players):
    """Return per-player state dict: glow, vib_amp, vib_onset, gesture."""
    states = {}
    for pl in players:
        pid      = pl['id']
        notes    = player_notes_sets[pid]
        inst     = pl['inst']

        str_glow  = np.zeros(4)
        str_vib   = np.zeros(4)  # amplitude 0..1
        str_onset = np.full(4, -999.0)  # last onset per string
        str_pitch = np.full(4, np.nan)  # pitch currently sounding on each string
        last_gest = None           # (onset_t, str_idx, voice_id)

        for row in notes:
            onset_t  = row[0]
            pitch    = float(row[1])
            dur_s    = row[2]
            voice_id = int(row[5])
            si       = _note_to_str(pitch, inst)
            dt       = t - onset_t

            # Glow
            if 0.0 <= dt <= GLOW_DECAY:
                str_glow[si] = max(str_glow[si], 1.0 - dt / GLOW_DECAY)

            # Vibration
            if dt > 0.0:
                tau = TAU_MARTEL if voice_id in MARTEL_VOICES else TAU_PIZZ
                amp = float(np.exp(-dt / tau))
                if dt > dur_s:
                    cutoff = 0.10 if voice_id in MARTEL_VOICES else 0.18
                    amp *= max(0.0, 1.0 - (dt - dur_s) / cutoff)
                if amp > str_vib[si]:
                    str_vib[si] = amp
                    str_onset[si] = onset_t
                    str_pitch[si] = pitch

            # Track most recent onset for gesture
            total_gest = (BOW_APP_T + BOW_DWL_T + BOW_RET_T
                          if voice_id in MARTEL_VOICES
                          else PLK_APP_T + PLK_DWL_T + PLK_RET_T)
            if -PLK_APP_T <= dt <= total_gest:
                if last_gest is None or onset_t > last_gest[0]:
                    last_gest = (onset_t, si, voice_id)

        states[pid] = dict(
            str_glow=str_glow, str_vib=str_vib, str_onset=str_onset,
            str_pitch=str_pitch, last_gest=last_gest,
        )
    return states


# ── Scene ─────────────────────────────────────────────────────────────────────

def _title_for_chorale(chorale):
    if chorale:
        m = re.match(r'bwv(\d+)', chorale, re.IGNORECASE)
        if m:
            return f"J.S. Bach BWV {m.group(1)}"
        return f"J.S. Bach {chorale}"
    return "J.S. Bach"


class Scene:
    def __init__(self, fig, ax, players, chorale=None):
        self.ax      = ax
        self.players = players
        self.chorale = chorale

        # Per-player dynamic objects
        self._strings  = {}   # pid → list of 4 Line2D
        self._str_glow = {}   # pid → list of 4 Ellipse halos
        self._bow      = {}   # pid → Rectangle (martelé only)
        self._pluck    = {}   # pid → Circle (pizzicato only)
        self._stop_dots = {}  # pid → list of 4 Circle (fret/stop position)
        self._body_pch = {}   # pid → body Polygon (to update color on activation)

        for pl in players:
            pid  = pl['id']
            inst = pl['inst']
            cx   = pl['cx']
            cy   = pl['cy']
            sc   = pl['sc']
            spec = INST_SPEC[inst]
            wood = spec['wood']

            bw = spec['bw'] * sc
            bh = spec['bh'] * sc
            nw = spec['neck_w'] * sc
            nh = spec['neck_h'] * sc
            waist = spec['waist']
            sxs   = _str_xs(cx, spec, sc)
            str_top = cy - bh            # nut position
            str_bot = cy + bh * 0.85    # tailpiece

            # ── Body ────────────────────────────────────────────────────────
            body_pts = _body_outline(cx, cy, bw, bh, waist)
            body = MplPolygon(body_pts, closed=True,
                              fc=wood, ec=_darken(wood, 0.45), lw=0.8, zorder=4)
            ax.add_patch(body)
            self._body_pch[pid] = body

            # Neck
            neck = Rectangle((cx - nw, cy - bh - nh), nw * 2, nh,
                              fc=wood, ec=_darken(wood, 0.45), lw=0.6, zorder=3)
            ax.add_patch(neck)

            # Scroll (tiny circle at top of neck)
            scroll_r = spec['scroll_r'] * sc
            scroll = Circle((cx, cy - bh - nh - scroll_r * 0.6),
                             radius=scroll_r,
                             fc=_darken(wood, 0.2), ec=_darken(wood, 0.5),
                             lw=0.5, zorder=3)
            ax.add_patch(scroll)

            # Bridge (thin rectangle at mid-body) — positioned so
            # nut:bridge to bridge:tailpiece is 6:1 (typical violin-family
            # proportions), not just a fixed fraction of body height.
            bridge_w = (sxs[-1] - sxs[0]) + 4 * sc
            bridge_y = str_top + (6.0 / 7.0) * (str_bot - str_top)
            bridge = Rectangle((sxs[0] - 2*sc, bridge_y - 1.5*sc),
                                bridge_w, 3.0*sc,
                                fc=_darken(wood, 0.3), ec='none', zorder=6)
            ax.add_patch(bridge)

            # Tailpiece (small dark shape at bottom)
            tail_w = (sxs[-1] - sxs[0]) + 2*sc
            tail = Rectangle((sxs[0] - sc, cy + bh*0.78),
                              tail_w, bh * 0.08,
                              fc=_darken(wood, 0.5), ec='none', zorder=6)
            ax.add_patch(tail)

            # ── Strings ─────────────────────────────────────────────────────
            str_clrs = [(0.80, 0.80, 0.80),   # G: silver
                        (0.75, 0.75, 0.75),   # D
                        (0.82, 0.78, 0.60),   # A: slightly warm
                        (0.90, 0.88, 0.68)]   # E: warm (gut/gold)
            self._strings[pid] = []
            for si, sx in enumerate(sxs):
                (line,) = ax.plot([sx, sx], [str_top, str_bot],
                                  color=str_clrs[si], lw=0.9 * sc, alpha=0.85,
                                  zorder=7, solid_capstyle='round')
                self._strings[pid].append(line)

            # ── String glow halos ────────────────────────────────────────────
            self._str_glow[pid] = []
            for si, sx in enumerate(sxs):
                glow = Ellipse((sx, cy), width=12*sc,
                               height=(str_bot - str_top) + 12,
                               fc=(0.95, 0.92, 0.70), alpha=0.0, zorder=5)
                ax.add_patch(glow)
                self._str_glow[pid].append(glow)

            # ── Fingerboard stop dots — mark where the finger presses the
            # string for a note above its open pitch (invisible otherwise) ──
            self._stop_dots[pid] = []
            for si, sx in enumerate(sxs):
                dot = Circle((sx, cy), radius=2.2 * sc,
                             fc=(0.90, 0.85, 0.75), ec=(0.30, 0.25, 0.20),
                             lw=0.4, alpha=0.0, zorder=8)
                ax.add_patch(dot)
                self._stop_dots[pid].append(dot)

            # ── Gesture: bow (martelé) or pluck circle (pizzicato) ──────────
            is_martel = pl['voice'] in MARTEL_VOICES

            if is_martel:
                # Bow: horizontal rectangle that sweeps across strings, at
                # bridge height (bowing happens right at the bridge)
                bow_len = (sxs[-1] - sxs[0]) + BOW_SWEEP + 20 * sc
                bow_y   = bridge_y - BOW_H / 2
                bow = Rectangle((cx - bow_len / 2, bow_y),
                                 bow_len, BOW_H * sc,
                                 fc=(0.92, 0.90, 0.76), ec=(0.70, 0.68, 0.55),
                                 lw=0.5, alpha=0.0, zorder=9)
                ax.add_patch(bow)
                self._bow[pid]   = bow
                self._pluck[pid] = None
            else:
                # Pluck fingertip: appears to the right of instrument body,
                # at bridge height (plucking happens close to the bridge)
                pluck = Ellipse((cx + bw + PLK_ARM * sc, bridge_y),
                                width=PLK_FINGER_W * sc, height=PLK_FINGER_H * sc,
                                fc=(0.85, 0.82, 0.75), ec='none',
                                alpha=0.0, zorder=9)
                ax.add_patch(pluck)
                self._bow[pid]   = None
                self._pluck[pid] = pluck

            # ── Apply tilt transform to every instrument artist ──────────────
            tilt = _make_tilt_xform(cx, cy, ax)
            body.set_transform(tilt)
            neck.set_transform(tilt)
            scroll.set_transform(tilt)
            bridge.set_transform(tilt)
            tail.set_transform(tilt)
            for line in self._strings[pid]:
                line.set_transform(tilt)
            for halo in self._str_glow[pid]:
                halo.set_transform(tilt)
            for dot in self._stop_dots[pid]:
                dot.set_transform(tilt)
            if self._bow[pid] is not None:
                self._bow[pid].set_transform(tilt)
            if self._pluck[pid] is not None:
                self._pluck[pid].set_transform(tilt)

            # ── Player label — positioned below the tilted instrument bottom ──
            # The body bottom (0, bh) after tilt lands at (bh*_SX, bh*_SY) rel centre
            label_x = cx + bh * _TILT_SX
            label_y = cy + bh * _TILT_SY + 13
            ax.text(label_x, label_y, pl['name'],
                    ha='center', va='top', fontsize=8, color=LABEL_CLR, zorder=10)

        # ── Stage floor band ─────────────────────────────────────────────────
        ax.add_patch(Rectangle((0, 0), W, H,
                               fc=BG_COLOR, ec='none', zorder=0))

        # ── Title ────────────────────────────────────────────────────────────
        ax.text(W / 2, H - 16,
                _title_for_chorale(self.chorale),
                ha='center', va='bottom', fontsize=10.5,
                color=(0.50, 0.60, 0.80), zorder=11)

    # ── Per-frame update ─────────────────────────────────────────────────────

    def update(self, t, states):
        for pl in self.players:
            pid   = pl['id']
            inst  = pl['inst']
            cx    = pl['cx']
            cy    = pl['cy']
            sc    = pl['sc']
            spec  = INST_SPEC[inst]
            bw    = spec['bw'] * sc
            bh    = spec['bh'] * sc
            sxs   = _str_xs(cx, spec, sc)
            str_top = cy - bh
            str_bot = cy + bh * 0.85
            # Matches the drawn bridge (6:1 nut:bridge to bridge:tailpiece)
            # — the true fixed end of the *vibrating* length; str_bot is
            # the tailpiece, past the bridge, which never vibrates.
            bridge_y = str_top + (6.0 / 7.0) * (str_bot - str_top)
            state = states[pid]
            glow  = state['str_glow']
            vib   = state['str_vib']
            st_on = state['str_onset']
            st_pitch = state['str_pitch']
            gest  = state['last_gest']
            open_cents = spec['open_cents']

            # ── Update each string ───────────────────────────────────────────
            for si, sx in enumerate(sxs):
                g = glow[si]
                a = vib[si]
                line = self._strings[pid][si]
                halo = self._str_glow[pid][si]
                dot = self._stop_dots[pid][si]

                if a > 0.005:
                    # Vibrating: compute standing-wave x-offsets. A note
                    # stopped above the string's open pitch only vibrates
                    # over the fraction of the string between the finger
                    # and the bridge — length ∝ 1/frequency. The fixed end
                    # is the bridge (bridge_y), not the tailpiece (str_bot):
                    # the afterlength past the bridge never vibrates, and
                    # anchoring to str_bot let the "stopped" segment (and
                    # the stop dot) render past the bridge for short lengths.
                    onset_t = st_on[si]
                    dt  = t - onset_t
                    ph  = 2.0 * np.pi * VIB_FREQ * dt

                    pitch = st_pitch[si]
                    length_frac = (sl.vibrating_length_fraction(pitch, open_cents[si])
                                   if not np.isnan(pitch) else 1.0)
                    vib_top = bridge_y - length_frac * (bridge_y - str_top)

                    ys  = np.linspace(str_top, str_bot, 30)
                    rel = np.clip((ys - vib_top) / max(bridge_y - vib_top, 1e-6), 0.0, 1.0)
                    wave_shape = np.where(ys >= vib_top, np.sin(np.pi * rel), 0.0)
                    xs  = sx + a * 9 * sc * wave_shape * np.cos(ph)
                    line.set_data(xs, ys)

                    # Glow halo follows the shortened vibrating segment
                    # (finger stop -> bridge, not down to the tailpiece)
                    halo.set_center((sx, (vib_top + bridge_y) / 2))
                    halo.set_height((bridge_y - vib_top) + 12)

                    # Stop dot: only shown for an actually-stopped note
                    # (length_frac < 1 — an open string has no finger down)
                    if length_frac < 0.98:
                        dot.set_center((sx, vib_top))
                        dot.set_alpha(g if g > 0.05 else 0.0)
                    else:
                        dot.set_alpha(0.0)
                else:
                    line.set_data([sx, sx], [str_top, str_bot])
                    halo.set_center((sx, cy))
                    halo.set_height((str_bot - str_top) + 12)
                    dot.set_alpha(0.0)

                # String brightness on glow
                lw_base = 0.9 * sc
                line.set_linewidth(lw_base + g * 1.8)
                if g > 0.08:
                    bright = tuple(min(1.0, c + g * 0.5) for c in line.get_color())
                    line.set_color(bright)
                else:
                    line.set_color(self._string_rest_color(si))

                # Halo
                halo.set_alpha(g * 0.38 if g > 0.04 else 0.0)

            # ── Gesture ──────────────────────────────────────────────────────
            is_martel = pl['voice'] in MARTEL_VOICES

            if gest is None:
                if self._bow[pid]:   self._bow[pid].set_alpha(0.0)
                if self._pluck[pid]: self._pluck[pid].set_alpha(0.0)
                continue

            onset_t, str_idx, voice_id = gest
            dt = t - onset_t
            sx_active = sxs[str_idx]

            if is_martel:
                bow = self._bow[pid]
                total = BOW_APP_T + BOW_DWL_T + BOW_RET_T
                if -BOW_APP_T <= dt <= total:
                    bow_y = bridge_y - (BOW_H * sc) / 2
                    bow.set_y(bow_y)
                    # Sweep: bow moves rightward starting left of strings
                    sweep_lo = sx_active - BOW_SWEEP * 0.45
                    sweep_hi = sx_active + BOW_SWEEP * 0.55
                    bow_len  = (sxs[-1] - sxs[0]) + 16 * sc
                    if dt < 0:   # approaching
                        ph    = (dt + BOW_APP_T) / BOW_APP_T
                        bx    = sweep_lo - 18 + 18 * ph
                        alpha = ph
                    elif dt < BOW_DWL_T:  # sweeping
                        ph    = dt / BOW_DWL_T
                        bx    = sweep_lo + (sweep_hi - sweep_lo) * ph
                        alpha = 1.0
                    else:        # lifting
                        ph    = min(1.0, (dt - BOW_DWL_T) / BOW_RET_T)
                        bx    = sweep_hi
                        alpha = max(0.0, 1.0 - ph)
                    bow.set_x(bx - bow_len / 2)
                    bow.set_width(bow_len)
                    bow.set_alpha(alpha)
                else:
                    bow.set_alpha(0.0)

            else:
                pluck = self._pluck[pid]
                total = PLK_APP_T + PLK_DWL_T + PLK_RET_T
                if -PLK_APP_T <= dt <= total:
                    if dt < 0:        # approaching from right
                        ph = ((dt + PLK_APP_T) / PLK_APP_T) ** 1.5
                        gx = sx_active + (PLK_ARM + bw) * sc * (1.0 - ph)
                    elif dt < PLK_DWL_T:  # at string
                        gx = sx_active
                    else:             # retracting
                        ph = min(1.0, (dt - PLK_DWL_T) / PLK_RET_T) ** 0.7
                        gx = sx_active + (PLK_ARM + bw) * sc * ph
                    gy = bridge_y
                    pluck.center = (gx, gy)
                    pluck.set_facecolor(VOICE_CLR.get(voice_id, (0.8, 0.8, 0.7)))
                    pluck.set_alpha(1.0)
                else:
                    pluck.set_alpha(0.0)

    @staticmethod
    def _string_rest_color(si):
        return [(0.78, 0.78, 0.78), (0.74, 0.74, 0.74),
                (0.80, 0.76, 0.60), (0.88, 0.86, 0.66)][si]


# ── Color helpers ─────────────────────────────────────────────────────────────

def _darken(rgb, frac):
    return tuple(c * (1.0 - frac) for c in rgb)


VOICE_CLR = {
    2: (0.80, 0.70, 0.55),   # violin pizz — warm ivory
    3: (0.65, 0.72, 0.60),   # viola pizz — muted sage
    4: (0.70, 0.58, 0.45),   # cello pizz — warm tan
    9: (0.70, 0.72, 0.90),   # martelé — cool steel blue
}

VIB_FREQ = 8.0  # visual vibration frequency for all strings


# ── Stage 2: render frames ────────────────────────────────────────────────────

def render_frames(notes, duration, chorale=None):
    log.info(f"\n[Stage 2] Rendering {FRAMES_DIR}/")
    Path(FRAMES_DIR).mkdir(exist_ok=True)

    player_note_sets = build_player_note_sets(notes, PLAYERS)
    for pl in PLAYERS:
        n = len(player_note_sets[pl['id']])
        log.info(f"  {pl['name']:6s}  {n:4d} notes")

    n_frames = int(np.ceil(duration * FPS))
    log.info(f"  {n_frames} frames ({duration:.1f}s @ {FPS}fps)")

    fig, ax = plt.subplots(figsize=(W / DPI, H / DPI), dpi=DPI)
    fig.patch.set_facecolor(BG_COLOR)
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    ax.set_facecolor(BG_COLOR)
    ax.set_xlim(0, W)
    ax.set_ylim(H, 0)    # y=0 at top (canvas coords)
    ax.set_aspect('equal')
    ax.axis('off')

    scene = Scene(fig, ax, PLAYERS, chorale=chorale)

    for fi in range(n_frames):
        t = fi / FPS
        states = compute_state(t, player_note_sets, PLAYERS)
        scene.update(t, states)
        fig.savefig(f"{FRAMES_DIR}/frame_{fi:06d}.png", dpi=SAVE_DPI,
                    facecolor=BG_COLOR, bbox_inches=None)
        if fi % 60 == 0:
            log.info(f"  {fi}/{n_frames}  t={t:.1f}s")

    plt.close(fig)
    log.info(f"  Done — {n_frames} frames written.")


# ── Stage 3: video assembly ───────────────────────────────────────────────────

def assemble_video(mp3_file):
    log.info(f"\n[Stage 3] Assembling → {VIDEO_OUT}")
    if mp3_file:
        cmd = ['ffmpeg', '-y',
               '-framerate', str(FPS),
               '-i', f'{FRAMES_DIR}/frame_%06d.png',
               '-i', mp3_file,
               '-c:v', 'libx264', '-preset', 'fast', '-crf', '18',
               '-pix_fmt', 'yuv420p',
               '-c:a', 'aac', '-b:a', '192k',
               '-shortest', VIDEO_OUT]
    else:
        cmd = ['ffmpeg', '-y',
               '-framerate', str(FPS),
               '-i', f'{FRAMES_DIR}/frame_%06d.png',
               '-c:v', 'libx264', '-preset', 'fast', '-crf', '18',
               '-pix_fmt', 'yuv420p', VIDEO_OUT]
    log.info(' '.join(cmd))
    subprocess.run(cmd, check=True)
    size_mb = os.path.getsize(VIDEO_OUT) / 1024 / 1024
    log.info(f"  Done — {VIDEO_OUT} ({size_mb:.1f} MB)")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="String section POC animator")
    parser.add_argument('--npy',   default=DEFAULT_NPY)
    parser.add_argument('--tempo', type=float, default=DEFAULT_TEMPO)
    parser.add_argument('--mp3',   default=DEFAULT_MP3,
                        help='Audio file for Stage 3 (optional)')
    parser.add_argument('--chorale', default=None,
                        help='Chorale name (e.g. bwv261).  When --mp3 is not '
                             'given, the newest Uploads/*.mp3 matching this '
                             'chorale is used for Stage 3 audio.')
    parser.add_argument('--stage', choices=['1', '2', '3', '12', 'all'], default='all',
                        help="'12' runs Stage 1+2 (notes + frames) without Stage 3's "
                             "standalone str_poc.mp4 assembly — what gen-video.sh uses, "
                             "since compose_stage_merge.py builds the real output "
                             "from these same frames.")
    parser.add_argument('--duration', type=float, default=None,
                        help='Override computed duration (seconds), e.g. to '
                             'match a shared timeline with another sequence')
    args = parser.parse_args()

    if args.stage in ('1', '12', 'all'):
        if not args.npy:
            parser.error("--npy required for Stage 1")
        notes, duration = load_string_voices(args.npy, args.tempo)
    else:
        notes = np.load(NOTES_FILE)
        duration = float(notes[:, 0].max() + notes[:, 2].max()) + 2.0

    if args.duration is not None:
        duration = args.duration

    if args.stage in ('2', '12', 'all'):
        render_frames(notes, duration, chorale=args.chorale)

    if args.stage in ('3', 'all'):
        # Resolve the audio track: an explicit --mp3 wins; otherwise look up
        # the newest Uploads MP3 for --chorale.  Neither is required — if no
        # track is found, Stage 3 simply produces a silent video.
        mp3 = uploads_lookup.resolve_mp3(
            mp3=args.mp3, chorale=args.chorale, required=False)
        if mp3:
            log.info(f"Audio track    : {mp3}")
        else:
            log.warning("No audio track (--mp3 not given and no matching Uploads MP3 "
                        "found); Stage 3 will produce a silent video.")
        assemble_video(mp3)


if __name__ == '__main__':
    main()
