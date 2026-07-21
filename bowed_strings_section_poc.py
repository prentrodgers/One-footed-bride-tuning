#!/usr/bin/env python3
"""
bowed_strings_section_poc.py — 8 invisible bowed-string players on the
same stage (front row, left).

Instruments (matching WreckingCrew's bowed_strings section):
  Back row (4, csound_voice 17 — violin with vibrato):
    Seat 0  violin  Vl.I
    Seat 1  violin  Vl.II
    Seat 2  violin  Vl.III
    Seat 3  violin  Vl.IV
  Front row (2 violas + 2 cellos):
    Seat 4  viola  Va.I   csound_voice 18
    Seat 5  viola  Va.II  csound_voice 18
    Seat 6  cello  Vc.I   csound_voice 19
    Seat 7  cello  Vc.II  csound_voice 19

Unlike the pizzicato string section (string_section_poc.py), every instrument
here is bowed — a bow sweeps across the strings for the duration of each
note, with a gentle vibrato on the string glow.  The players are invisible,
behind the instruments, facing the conductor.

Renders transparent frames (no background) meant to be composited onto
string_section_poc.py's frames by compose_stage_merge.py.

Usage:
  python bowed_strings_section_poc.py --npy bwv261_features_array.npy \\\\
      --tempo 106 --duration 25.1
"""

import argparse
import math
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.transforms as mtransforms
from matplotlib.patches import Polygon as MplPolygon, Circle, Rectangle, Ellipse

import marimba_poc as mp
import stage_layout as stage

import logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%d %H:%M")
log = logging.getLogger(__name__)

# ── Constants ──────────────────────────────────────────────────────────────────
FRAMES_DIR = "bowed8_frames"
FPS        = 30

# Voice numbers (from adaptive_tuning_util.init_voice_time)
VOICE_VIOLIN = 17
VOICE_VIOLA  = 18
VOICE_CELLO  = 19
ALL_BOW_VOICES = (VOICE_VIOLIN, VOICE_VIOLA, VOICE_CELLO)

# Canvas (inherited from marimba_poc)
W, H, DPI = mp.W, mp.H, mp.DPI

# ── Layout ─────────────────────────────────────────────────────────────────────
# Bowed strings occupy the LEFT of the front row (stage.FRONT_X[0] = 280).
# y-up data space (ax.set_ylim(0, H)), so data-y = H - screen.
BOW_Y_BACK  = stage.yup(stage.ROW_FRONT_Y_FAR)   # back row  (screen 517)
BOW_Y_FRONT = stage.yup(stage.ROW_FRONT_Y_NEAR)  # front row (screen 617)
BOW_X_STEP  = 62
BOW_X_START = int(stage.FRONT_X[0] - 1.5 * BOW_X_STEP)  # centres at 280

# scale factors — back row smaller (farther), front row larger (closer)
SCALE_BACK  = 0.55
SCALE_FRONT = 0.70

# Instrument specs (at scale=1.0) — reused from string_section_poc
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
                   wood=(0.50, 0.30, 0.10), scroll_r=6,
                   open_cents=[2400, 3100, 3800, 4500]),
}

# Instrument tilt: 30° back + 20° left (same as pizz strings)
BACK_TILT = 30
LEFT_TILT = 20
_TILT_SX = np.cos(np.radians(BACK_TILT)) * np.sin(np.radians(LEFT_TILT))
_TILT_SY = np.cos(np.radians(BACK_TILT)) * np.cos(np.radians(LEFT_TILT))

# Bow parameters
BOW_H        = 6       # px — hair thickness
BOW_SWEEP    = 44      # px — horizontal sweep distance
BOW_RIGHT_REACH = 16   # px — extra length on the string-side edge only, so the
                        # bow's rightward sweep excursion (biased larger than
                        # the leftward one, see BOW_SWEEP split below) doesn't
                        # carry it clear off the strings
BOW_APP_T    = 0.028   # approach time
BOW_DWL_T    = 0.052   # dwell (sweep) time
BOW_RET_T    = 0.080   # retract time

# Sustained-note bow speed: the bow's back-and-forth sweep rate scales with the
# note duration so long, sustained notes get slow, singing bow strokes (and
# short notes stay quick).  BOW_REF_DUR is the duration that maps to the
# original fixed 3.0 Hz; the rate is clamped so very long notes still move and
# very short notes don't look frantic.
BOW_REF_DUR   = 0.5    # seconds — duration at which sweep_rate == 3.0 (the old fixed rate)
BOW_RATE_MIN  = 0.5    # slowest phase-advance rate (long sustained notes)
BOW_RATE_MAX  = 6.0    # fastest phase-advance rate (very short notes)

# Vibrato
VIB_FREQ   = 6.5     # visual Hz (slower than pizz, more singing)
TAU_BOW    = 0.40    # glow decay after note ends

LABEL_CLR  = (0.44, 0.48, 0.58)
BG_COLOR   = (0.06, 0.07, 0.09)   # not used (transparent), kept for compat

# Player seats: back row = 2 violas + 2 cellos (lower), front row = 4 violins
# (higher).  Lower voices sit farther back — matching standard orchestral
# layout.  Pitch ranges (p_lo/p_hi in cents) split each voice across its
# seats by register, matching the actual pitch ranges in the features arrays.
PLAYERS = [
    # Back row: violas + cellos (lower)
    dict(id=0, name='Va.I',   voice=VOICE_VIOLA,  inst='viola',  cx=BOW_X_START + 0*BOW_X_STEP, cy=BOW_Y_BACK,  sc=SCALE_BACK, p_lo=6000, p_hi=None),
    dict(id=1, name='Va.II',  voice=VOICE_VIOLA,  inst='viola',  cx=BOW_X_START + 1*BOW_X_STEP, cy=BOW_Y_BACK,  sc=SCALE_BACK, p_lo=None, p_hi=6000),
    dict(id=2, name='Vc.I',   voice=VOICE_CELLO,  inst='cello',  cx=BOW_X_START + 2*BOW_X_STEP, cy=BOW_Y_BACK,  sc=SCALE_BACK, p_lo=5300, p_hi=None),
    dict(id=3, name='Vc.II',  voice=VOICE_CELLO,  inst='cello',  cx=BOW_X_START + 3*BOW_X_STEP, cy=BOW_Y_BACK,  sc=SCALE_BACK, p_lo=None, p_hi=5300),
    # Front row: violins (higher)
    dict(id=4, name='Vl.I',   voice=VOICE_VIOLIN, inst='violin', cx=BOW_X_START + 0*BOW_X_STEP, cy=BOW_Y_FRONT, sc=SCALE_FRONT, p_lo=8200, p_hi=None),
    dict(id=5, name='Vl.II',  voice=VOICE_VIOLIN, inst='violin', cx=BOW_X_START + 1*BOW_X_STEP, cy=BOW_Y_FRONT, sc=SCALE_FRONT, p_lo=7600, p_hi=8200),
    dict(id=6, name='Vl.III', voice=VOICE_VIOLIN, inst='violin', cx=BOW_X_START + 2*BOW_X_STEP, cy=BOW_Y_FRONT, sc=SCALE_FRONT, p_lo=7000, p_hi=7600),
    dict(id=7, name='Vl.IV',  voice=VOICE_VIOLIN, inst='violin', cx=BOW_X_START + 3*BOW_X_STEP, cy=BOW_Y_FRONT, sc=SCALE_FRONT, p_lo=None, p_hi=7000),
]


# ── Colour helpers ─────────────────────────────────────────────────────────────
def _darken(c, f=0.35):
    return tuple(max(0.0, x - f * x) for x in c)

def _body_outline(cx, cy, bw, bh, waist):
    """Violin-family body outline — the same distinctive hourglass silhouette
    as string_section_poc.py's pizzicato strings (angular bouts + shoulders,
    not the smooth sine peanut).  Key-point polygon, mirrored about cx.

    dy is relative to cy; the neck/scroll attach at the cy-bh end (preserving
    this section's existing orientation), so the body reads as a true violin
    hourglass whichever way the row is drawn."""
    w = waist  # waist half-width as fraction of bw
    # Right-side key points (dx, dy) relative to body centre
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


def _make_tilt_xform(cx, cy, ax):
    """Tilt transform: 30° back + 20° left, pivoting at (cx, cy)."""
    return (mtransforms.Affine2D()
            .translate(-cx, -cy)
            .rotate_deg(-LEFT_TILT)
            .scale(1.0, np.cos(np.radians(BACK_TILT)))
            .translate(cx, cy)
            + ax.transData)


# ── Data loading ──────────────────────────────────────────────────────────────
def load_bowed_voices(npy_file, tempo):
    log.info(f"\n[bowed strings] Loading {npy_file}")
    arr = np.load(npy_file)
    mask = (arr[:, 5] > 0) & (arr[:, 2] > 0) & (arr[:, 14] > 0) & (arr[:, 3] > 0)
    mask &= np.isin(arr[:, 6].astype(int), ALL_BOW_VOICES)
    arr = arr[mask]
    if not len(arr):
        log.warning("  no bowed-string notes found — section will render silent")
        return np.zeros((0, 6))
    bps = tempo / 60.0
    notes = np.column_stack([
        arr[:, 1] / bps,              # start_s
        arr[:, 5] * 1200 + arr[:, 4], # pitch_cents
        arr[:, 2] / bps,              # dur_s
        arr[:, 3],                    # velocity
        arr[:, 14],                   # volume
        arr[:, 6],                    # voice_id
    ])
    notes = notes[notes[:, 0].argsort()]
    for v in ALL_BOW_VOICES:
        n = int((notes[:, 5].astype(int) == v).sum())
        name = {17:'violin', 18:'viola', 19:'cello'}[v]
        log.info(f"  voice {v} ({name}): {n} notes")
    log.info(f"  total {len(notes)} notes")
    return notes


def build_player_note_sets(notes, players):
    """Route each note to the player whose voice + pitch range matches."""
    sets = {p['id']: [] for p in players}
    for row in notes:
        pitch = row[1]
        voice = int(row[5])
        for p in players:
            if p['voice'] != voice:
                continue
            lo = p.get('p_lo')
            hi = p.get('p_hi')
            if (lo is None or pitch >= lo) and (hi is None or pitch < hi):
                sets[p['id']].append(row)
                break
        else:
            # No pitch-range match → assign to first player of that voice
            for p in players:
                if p['voice'] == voice:
                    sets[p['id']].append(row)
                    break
    return {k: np.array(v) if v else np.zeros((0, 6)) for k, v in sets.items()}


# ── State computation ─────────────────────────────────────────────────────────
def compute_state(t, player_note_sets, players):
    """Per player: per-string glow, vibrato amp, onset time, last gesture."""
    states = {}
    for p in players:
        pid = p['id']
        notes = player_note_sets[pid]
        spec = INST_SPEC[p['inst']]
        n_str = spec['n_str']
        open_cents = spec['open_cents']

        str_glow = np.zeros(n_str)
        str_vib = np.zeros(n_str)
        str_onset = np.full(n_str, -999.0)
        last_gest = None

        for row in notes:
            onset, pitch, dur = row[0], row[1], row[2]
            note_end = onset + dur
            # Find nearest string
            si = int(np.argmin(np.abs(np.array(open_cents) - pitch)))
            si = max(0, min(si, n_str - 1))

            if onset <= t <= note_end:
                str_glow[si] = max(str_glow[si], 1.0)
                str_vib[si] = max(str_vib[si], 1.0)
                str_onset[si] = onset
                last_gest = (onset, si, int(row[5]), float(dur))
            elif t > note_end:
                decay = (t - note_end) / TAU_BOW
                if decay < 1.0:
                    g = 1.0 - decay
                    str_glow[si] = max(str_glow[si], g)
                    str_vib[si] = max(str_vib[si], g * 0.7)
                if last_gest is None or note_end > last_gest[0]:
                    last_gest = (onset, si, int(row[5]), float(dur))

        states[pid] = dict(str_glow=str_glow, str_vib=str_vib,
                           str_onset=str_onset, last_gest=last_gest)
    return states


# ── Scene ─────────────────────────────────────────────────────────────────────
class BowedScene:
    """Manages all 8 bowed-string instruments: body, strings, bow animation."""

    def __init__(self, fig, ax, players):
        self.fig = fig
        self.ax = ax
        self.players = players
        self._body_pch = {}
        self._strings = {}
        self._str_glow = {}
        self._bow = {}

        for pl in players:
            pid = pl['id']
            cx, cy, sc = pl['cx'], pl['cy'], pl['sc']
            spec = INST_SPEC[pl['inst']]
            bw = spec['bw'] * sc
            bh = spec['bh'] * sc
            nw = spec['neck_w'] * sc
            nh = spec['neck_h'] * sc
            waist = spec['waist']
            wood = spec['wood']
            n_str = spec['n_str']
            str_s = spec['str_s'] * sc

            sxs = [cx - str_s * (n_str - 1) / 2 + i * str_s for i in range(n_str)]
            str_top = cy - bh
            str_bot = cy + bh * 0.85

            # Body
            body_pts = _body_outline(cx, cy, bw, bh, waist)
            body = MplPolygon(body_pts, closed=True,
                              fc=wood, ec=_darken(wood, 0.45), lw=0.8, zorder=4)
            ax.add_patch(body)
            self._body_pch[pid] = body

            # Neck
            neck = Rectangle((cx - nw, cy - bh - nh), nw * 2, nh,
                             fc=wood, ec=_darken(wood, 0.45), lw=0.6, zorder=3)
            ax.add_patch(neck)

            # Scroll
            scroll_r = spec['scroll_r'] * sc
            scroll = Circle((cx, cy - bh - nh - scroll_r * 0.6),
                            radius=scroll_r,
                            fc=_darken(wood, 0.2), ec=_darken(wood, 0.5),
                            lw=0.5, zorder=3)
            ax.add_patch(scroll)

            # Bridge
            bridge_w = (sxs[-1] - sxs[0]) + 4 * sc
            bridge_y = cy + bh * 0.12
            bridge = Rectangle((sxs[0] - 2*sc, bridge_y - 1.5*sc),
                               bridge_w, 3.0*sc,
                               fc=_darken(wood, 0.3), ec='none', zorder=6)
            ax.add_patch(bridge)

            # Tailpiece
            tail_w = (sxs[-1] - sxs[0]) + 2*sc
            tail = Rectangle((sxs[0] - sc, cy + bh*0.78),
                             tail_w, bh * 0.08,
                             fc=_darken(wood, 0.5), ec='none', zorder=6)
            ax.add_patch(tail)

            # Strings
            str_clrs = [(0.80, 0.80, 0.80), (0.75, 0.75, 0.75),
                        (0.82, 0.78, 0.60), (0.90, 0.88, 0.68)]
            self._strings[pid] = []
            for si, sx in enumerate(sxs):
                (line,) = ax.plot([sx, sx], [str_top, str_bot],
                                  color=str_clrs[si], lw=0.9 * sc, alpha=0.85,
                                  zorder=7, solid_capstyle='round')
                self._strings[pid].append(line)

            # String glow halos
            self._str_glow[pid] = []
            for si, sx in enumerate(sxs):
                glow = Ellipse((sx, cy), width=12*sc,
                               height=(str_bot - str_top) + 12,
                               fc=(0.95, 0.92, 0.70), alpha=0.0, zorder=5)
                ax.add_patch(glow)
                self._str_glow[pid].append(glow)

            # Bow — horizontal rectangle that sweeps across strings
            bow_len = (sxs[-1] - sxs[0]) + BOW_SWEEP + 20 * sc
            bow_y = cy + bh * 0.12 - BOW_H * sc / 2
            bow = Rectangle((cx - bow_len / 2, bow_y),
                            bow_len, BOW_H * sc,
                            fc=(0.92, 0.90, 0.76), ec=(0.70, 0.68, 0.55),
                            lw=0.5, alpha=0.0, zorder=9)
            ax.add_patch(bow)
            self._bow[pid] = bow

            # Apply tilt transform to all artists
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
            bow.set_transform(tilt)

            # Player label
            label_x = cx + bh * _TILT_SX
            label_y = cy + bh * _TILT_SY + 13
            ax.text(label_x, label_y, pl['name'],
                    ha='center', va='top', fontsize=8, color=LABEL_CLR, zorder=10)

    def update(self, t, states):
        for pl in self.players:
            pid = pl['id']
            cx, cy, sc = pl['cx'], pl['cy'], pl['sc']
            spec = INST_SPEC[pl['inst']]
            bw = spec['bw'] * sc
            bh = spec['bh'] * sc
            n_str = spec['n_str']
            str_s = spec['str_s'] * sc
            sxs = [cx - str_s * (n_str - 1) / 2 + i * str_s for i in range(n_str)]
            str_top = cy - bh
            str_bot = cy + bh * 0.85
            state = states[pid]
            glow = state['str_glow']
            vib = state['str_vib']
            st_on = state['str_onset']
            gest = state['last_gest']

            for si, sx in enumerate(sxs):
                g = glow[si]
                a = vib[si]
                line = self._strings[pid][si]
                halo = self._str_glow[pid][si]

                if a > 0.005:
                    onset_t = st_on[si]
                    dt = t - onset_t
                    ph = 2.0 * np.pi * VIB_FREQ * dt
                    ys = np.linspace(str_top, str_bot, 30)
                    L = str_bot - str_top
                    xs = sx + a * 9 * sc * np.sin(np.pi * (ys - str_top) / L) * np.cos(ph)
                    line.set_data(xs, ys)
                else:
                    line.set_data([sx, sx], [str_top, str_bot])

                lw_base = 0.9 * sc
                line.set_linewidth(lw_base + g * 1.8)
                halo.set_alpha(g * 0.38 if g > 0.04 else 0.0)

            # Bow — sustained back-and-forth sweep while note is active
            bow = self._bow[pid]
            if gest is None:
                bow.set_alpha(0.0)
                continue

            onset_t, str_idx, voice_id, note_dur = gest
            dt = t - onset_t
            sx_active = sxs[str_idx]

            if glow[str_idx] > 0.02:
                bow_y = cy + bh * 0.12 - (BOW_H * sc) / 2
                bow.set_y(bow_y)
                sweep_lo = sx_active - BOW_SWEEP * 0.45
                sweep_hi = sx_active + BOW_SWEEP * 0.55
                bow_len = (sxs[-1] - sxs[0]) + 16 * sc
                # The sweep is biased toward sx_active + BOW_SWEEP*0.55 (right)
                # vs -0.45 (left, below), so a bow rectangle split evenly
                # around its center used to swing clear off the strings on
                # the right side of the stroke while the left side stayed
                # planted. BOW_RIGHT_REACH extends only the string-side
                # (left) edge so the bow keeps contact through the whole
                # rightward excursion — the tip-side (right) edge, which
                # was never the problem, is untouched.
                bow_left_half  = bow_len / 2 + BOW_RIGHT_REACH
                bow_right_half = bow_len / 2
                # Slower bow for sustained notes: scale the back-and-forth
                # sweep rate by the note duration so long notes get long, slow
                # bow strokes (and short notes stay quick).  The rate is the
                # phase-advance speed (phase 0→2 = one full back-and-forth).
                sweep_rate = 3.0 * BOW_REF_DUR / max(note_dur, 0.05)
                sweep_rate = min(BOW_RATE_MAX, max(BOW_RATE_MIN, sweep_rate))
                phase = (dt * sweep_rate) % 2.0
                if phase < 1.0:
                    bx = sweep_lo + (sweep_hi - sweep_lo) * phase
                else:
                    bx = sweep_hi - (sweep_hi - sweep_lo) * (phase - 1.0)
                bow.set_x(bx - bow_left_half)
                bow.set_width(bow_left_half + bow_right_half)
                bow.set_alpha(min(1.0, glow[str_idx] * 1.2))
            elif dt < BOW_RET_T:
                bow.set_alpha(max(0.0, 1.0 - dt / BOW_RET_T))
            else:
                bow.set_alpha(0.0)


# ── Render ────────────────────────────────────────────────────────────────────
def render(npy_file, tempo, duration):
    notes = load_bowed_voices(npy_file, tempo)
    player_note_sets = build_player_note_sets(notes, PLAYERS)

    for pl in PLAYERS:
        n = len(player_note_sets[pl['id']])
        log.info(f"  {pl['name']:6s}  {n:4d} notes")

    Path(FRAMES_DIR).mkdir(exist_ok=True)
    n_frames = int(math.ceil(duration * FPS))
    log.info(f"[bowed strings] {n_frames} frames ({duration:.1f}s @ {FPS}fps)")

    fig, ax = plt.subplots(figsize=(W / DPI, H / DPI), dpi=DPI)
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    ax.set_xlim(0, W)
    ax.set_ylim(0, H)
    ax.set_aspect('equal')
    ax.axis('off')
    fig.patch.set_alpha(0.0)
    ax.patch.set_alpha(0.0)

    scene = BowedScene(fig, ax, PLAYERS)

    for fi in range(n_frames):
        t = fi / FPS
        states = compute_state(t, player_note_sets, PLAYERS)
        scene.update(t, states)
        fig.savefig(f"{FRAMES_DIR}/frame_{fi:06d}.png",
                    dpi=DPI, transparent=True)
        if fi % 200 == 0:
            log.info(f"  {fi}/{n_frames}  t={t:.1f}s")

    plt.close(fig)
    log.info(f"  Done — {n_frames} frames written to {FRAMES_DIR}/")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--npy',      required=True)
    parser.add_argument('--tempo',    type=float, required=True)
    parser.add_argument('--duration', type=float, required=True)
    args = parser.parse_args()
    render(args.npy, args.tempo, args.duration)


if __name__ == '__main__':
    main()

