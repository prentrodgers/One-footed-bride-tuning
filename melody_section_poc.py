#!/usr/bin/env python3
"""
melody_section_poc.py — 6 invisible players in the front row (right)
(was 8 — one flute and one vibraphone now instead of two each).

A mixed ensemble:
  Back row (higher):  flute (csound_voice 14), clarinet (13), vibraphone (7)
  Front row (lower):  oboe (15), bassoon (12), trumpet (25)

Each instrument reuses the draw functions from woodwind_section_poc /
brass_section_poc where possible; the vibraphone is new.  All instruments
have idle sway + playing glow.  Renders transparent frames for compositing.

Usage:
  python melody_section_poc.py --npy bwv261_features_array.npy \\\\
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
from matplotlib.patches import (
    Ellipse, Circle, Rectangle, Arc,
    Polygon as MplPolygon,
)

import marimba_poc as mp
import stage_layout as stage

import logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%d %H:%M")
log = logging.getLogger(__name__)
import woodwind_section_poc as ww   # draw_flute, draw_clarinet, draw_oboe, draw_bassoon
import brass_section_poc as br      # draw_trumpet

# ── Constants ──────────────────────────────────────────────────────────────────
FRAMES_DIR = "melody8_frames"
FPS        = 30

# Voice numbers
VOICE_FLUTE     = 14
VOICE_CLARINET  = 13
VOICE_VIBRAPHONE = 7
VOICE_OBOE      = 15
VOICE_BASSOON   = 12
VOICE_TRUMPET   = 25
ALL_MELODY_VOICES = (VOICE_FLUTE, VOICE_CLARINET, VOICE_VIBRAPHONE,
                     VOICE_OBOE, VOICE_BASSOON, VOICE_TRUMPET)

W, H, DPI = mp.W, mp.H, mp.DPI
SAVE_DPI  = mp.SAVE_DPI

# ── Layout ─────────────────────────────────────────────────────────────────────
# Melody occupies the RIGHT of the front row (stage.FRONT_X[1]),
# aligned with the brass column (MID_X[2]) in the 2nd row.
MEL_Y_BACK  = stage.yup(stage.ROW_FRONT_Y_FAR)   # back row  (screen 517)
MEL_Y_FRONT = stage.yup(stage.ROW_FRONT_Y_NEAR)  # front row (screen 617)
MEL_X_STEP  = 110   # widened now that only 3 seats/row need to span the section
MEL_X_START = int(stage.FRONT_X[1] - 1.0 * MEL_X_STEP)  # 3 columns, centred at FRONT_X[1]
# Oboe/bassoon (front row) are staggered this much right of flute/clarinet
# (back row) — the tall pipe shapes were colliding stacked in the same
# column; vibraphone/trumpet stay column-aligned (compact shapes, no
# stacking risk).
MEL_X_STAGGER = MEL_X_STEP / 2
# Trumpet nudged further right, clear of the (staggered) bassoon to its left.
MEL_TRUMPET_X_SHIFT = 30

# Scaled back down a bit (from 1.00/1.15) to help the staggered layout fit.
SCALE_BACK  = 0.85
SCALE_FRONT = 0.95

# ── Colours ────────────────────────────────────────────────────────────────────
# Vibraphone colours (new — not in woodwind/brass modules)
CLR_VIB_BARS  = (0.75, 0.82, 0.88)    # silver aluminium bars
CLR_VIB_BARS_DK = (0.50, 0.58, 0.65)
CLR_VIB_FRAME = (0.40, 0.42, 0.45)    # dark frame
CLR_VIB_MALLET = (0.82, 0.90, 0.97)
LABEL_CLR = (0.50, 0.55, 0.65, 1.0)

# Glow targets per kind
GLOW_CLR = {
    'flute':      (0.92, 0.96, 1.00),
    'clarinet':   (0.55, 0.65, 0.90),
    'vibraphone': (0.90, 0.95, 1.00),
    'oboe':       (0.55, 0.65, 0.90),
    'bassoon':    (0.85, 0.70, 0.45),
    'trumpet':    (1.00, 0.90, 0.50),
}

# ── Timing ────────────────────────────────────────────────────────────────────
GLOW_DECAY   = 0.65
PLAY_LEAN_T  = 0.06
PLAY_RELAX_T = 0.55

SWAY_AMP_DEG = 5.0   # ± degrees — doubled so players sway ~2× more (vibraphone exempted in update)
SWAY_FREQS   = [0.20, 0.25, 0.225, 0.275, 0.1875, 0.2625]  # 25% faster
SWAY_PHASES  = [0.0,  1.3,  2.7,  0.5,  3.8,  1.9]
# Sway fades out after an instrument's been silent for a while
# (SWAY_ENV_TAU_OUT) and fades back in once it starts playing again
# (SWAY_ENV_TAU_IN, quicker) — see BrassScene's trombone slide for the same
# exponential-smoothing technique.
SWAY_ENV_TAU_IN  = 0.4    # seconds
SWAY_ENV_TAU_OUT = 3.0    # seconds

# Playing lean: extra tilt toward mouthpiece when a note is held.
# Doubled (≈2×) so the players move more while enjoying the music.  Vibraphone
# lean is 0 — it stays in place (see mallet strike below).
PLAY_LEAN_DEG = {
    'flute': 10.0, 'clarinet': 8.0, 'vibraphone': 0.0,
    'oboe': 7.0, 'bassoon': 6.0, 'trumpet': 10.0,
}

# Vibraphone mallet strike (marimba-style) on each note onset: one of the two
# mallet circles drops onto the bars, dwells, and rebounds.  Vibraphone does
# NOT sway/lean (it remains in place) — the mallet strike is its onset gesture.
VIB_STRIKE_APP_T    = 0.055   # drop time  (rest → bar contact)
VIB_STRIKE_DWL_T    = 0.045   # contact dwell
VIB_STRIKE_REB_T    = 0.16    # rebound    (bar contact → rest)
VIB_STRIKE_REST_OFF = 16.0    # mallet rest height above bar top, in sc units

# Vibraphone mallet — marimba-style rod + head that swings down to strike the
# bars.  Each of the two mallets pivots directly above its strike point; the
# head traces an arc from a raised, outward-splayed rest position down to the
# bar top (theta -> 0) on each note onset, and the rod (stem) is the fixed-
# length arm from pivot to head — the same construction as marimba_poc.py.
VIB_MALLET_ARM    = 24.0    # px rod length at sc=1
VIB_MALLET_HEAD_W = 11.0    # px head ellipse width  at sc=1
VIB_MALLET_HEAD_H = 9.0     # px head ellipse height at sc=1
VIB_THETA_REST    = 55.0    # degrees — head raised & splayed outward at rest
VIB_STEM_CLR      = (0.60, 0.66, 0.74)
VIB_HEAD_EC       = (0.55, 0.65, 0.78)

# Brass trumpet base tilt (reuse from brass_section_poc) — trumpets up-and-left
BASE_TILT_TRUMPET = br.BASE_TILT_TRUMPET


# ── Vibraphone draw function ──────────────────────────────────────────────────
def draw_vibraphone(ax, cx, cy, sc):
    """Vibraphone — horizontal metal bars arranged like a small marimba,
    with a resonator tube below each bar and two mallets."""
    patches = []
    n_bars = 8
    bar_w = 6 * sc
    bar_h = 28 * sc
    bar_gap = 7 * sc
    total_w = n_bars * bar_w + (n_bars - 1) * bar_gap
    left = cx - total_w / 2

    # Bars
    for i in range(n_bars):
        bx = left + i * (bar_w + bar_gap)
        bar = Rectangle((bx, cy - bar_h/2), bar_w, bar_h,
                        fc=CLR_VIB_BARS, ec=CLR_VIB_BARS_DK, lw=0.5, zorder=5)
        ax.add_patch(bar)
        patches.append(bar)

    # Resonator tubes (below bars)
    tube_h = 16 * sc
    tube_w = bar_w * 0.8
    for i in range(n_bars):
        bx = left + i * (bar_w + bar_gap) + (bar_w - tube_w) / 2
        tube = Rectangle((bx, cy + bar_h/2 + 2*sc), tube_w, tube_h,
                         fc=CLR_VIB_FRAME, ec='none', zorder=4)
        ax.add_patch(tube)
        patches.append(tube)

    # Frame rails (top and bottom)
    rail_w = total_w + 4 * sc
    for ry in (cy - bar_h/2 - 3*sc, cy + bar_h/2 + tube_h + 3*sc):
        rail = Rectangle((cx - rail_w/2, ry), rail_w, 2*sc,
                         fc=CLR_VIB_FRAME, ec='none', zorder=3)
        ax.add_patch(rail)
        patches.append(rail)

    # Two mallets (marimba-style rod + head).  Each mallet pivots directly
    # above its strike point; the head rests raised & splayed outward and
    # swings down to the bar top on a note onset (animated in MelodyScene).
    # Rest head = pivot + rotate(strike_arm=(0,+arm), ±VIB_THETA_REST):
    # CCW for the left mallet -> head up-left, CW for the right -> up-right.
    bar_top_y = cy - bar_h / 2
    arm = VIB_MALLET_ARM * sc
    tr = math.radians(VIB_THETA_REST)
    for mx_off, sign in ((-total_w * 0.2, +1.0), (total_w * 0.2, -1.0)):
        sx = cx + mx_off                  # strike x (above a bar)
        pivot_x, pivot_y = sx, bar_top_y - arm
        hx = pivot_x - arm * math.sin(sign * tr)
        hy = pivot_y + arm * math.cos(sign * tr)
        (stem,) = ax.plot([pivot_x, hx], [pivot_y, hy],
                          color=VIB_STEM_CLR, lw=2.0 * sc,
                          solid_capstyle='round', zorder=7, alpha=0.45)
        head = Ellipse((hx, hy), width=VIB_MALLET_HEAD_W * sc,
                       height=VIB_MALLET_HEAD_H * sc,
                       fc=CLR_VIB_MALLET, ec=VIB_HEAD_EC, lw=0.8,
                       zorder=8, alpha=0.45)
        ax.add_patch(head)
        patches.append(stem)
        patches.append(head)

    return patches, (cx, cy), 0.0


# ── Seat definitions ──────────────────────────────────────────────────────────
def make_seats():
    """6 seats: back row (flute, clarinet, vibraphone), front row (oboe,
    bassoon, trumpet) — one seat per instrument instead of two for flute
    and vibraphone."""
    specs = [
        # name,         kind,        voice,             cx,                         cy,            scale
        ('Flute',      'flute',     VOICE_FLUTE,      MEL_X_START + 0*MEL_X_STEP,                 MEL_Y_BACK,  SCALE_BACK),
        ('Clarinet',   'clarinet',  VOICE_CLARINET,   MEL_X_START + 1*MEL_X_STEP,                 MEL_Y_BACK,  SCALE_BACK),
        ('Vibraphone', 'vibraphone',VOICE_VIBRAPHONE, MEL_X_START + 2*MEL_X_STEP,                 MEL_Y_BACK,  SCALE_BACK),
        ('Oboe',       'oboe',      VOICE_OBOE,       MEL_X_START + 0*MEL_X_STEP + MEL_X_STAGGER, MEL_Y_FRONT, SCALE_FRONT),
        ('Bassoon',    'bassoon',   VOICE_BASSOON,    MEL_X_START + 1*MEL_X_STEP + MEL_X_STAGGER, MEL_Y_FRONT, SCALE_FRONT),
        ('Trumpet',    'trumpet',   VOICE_TRUMPET,    MEL_X_START + 2*MEL_X_STEP + MEL_TRUMPET_X_SHIFT, MEL_Y_FRONT, SCALE_FRONT),
    ]
    seats = []
    for i, (name, kind, voice, cx, cy, sc) in enumerate(specs):
        seats.append(dict(
            id=i, name=name, kind=kind, voice=voice,
            cx=cx, cy=cy, sc=sc,
            sway_freq=SWAY_FREQS[i], sway_phase=SWAY_PHASES[i],
        ))
    return seats


# ── Data loading ──────────────────────────────────────────────────────────────
def load_melody_voices(npy_file, tempo):
    log.info(f"\n[melody] Loading {npy_file}")
    arr = np.load(npy_file)
    mask = (arr[:, 5] > 0) & (arr[:, 2] > 0) & (arr[:, 14] > 0) & (arr[:, 3] > 0)
    mask &= np.isin(arr[:, 6].astype(int), ALL_MELODY_VOICES)
    arr = arr[mask]
    if not len(arr):
        log.warning("  no melody notes found — section will render silent")
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
    for v in ALL_MELODY_VOICES:
        n = int((notes[:, 5].astype(int) == v).sum())
        name = {14:'flute', 13:'clarinet', 7:'vibraphone', 15:'oboe',
                12:'bassoon', 25:'trumpet'}[v]
        log.info(f"  voice {v} ({name}): {n} notes")
    log.info(f"  total {len(notes)} notes")
    return notes


def route_notes(notes, seats):
    """Split notes to seats by voice; round-robin for voices with 2 seats."""
    sets = {s['id']: [] for s in seats}
    voice_seats = {}
    for s in seats:
        voice_seats.setdefault(s['voice'], []).append(s['id'])
    voice_turn = {v: 0 for v in voice_seats}

    for row in notes:
        v = int(row[5])
        seat_ids = voice_seats.get(v, [])
        if not seat_ids:
            continue
        turn = voice_turn[v] % len(seat_ids)
        sets[seat_ids[turn]].append(row)
        voice_turn[v] += 1

    return {k: (np.array(v) if v else np.zeros((0, 6))) for k, v in sets.items()}


# ── State computation ─────────────────────────────────────────────────────────
def compute_state(t, seat_note_sets, seats):
    states = {}
    for s in seats:
        sid = s['id']
        notes = seat_note_sets[sid]
        glow = 0.0
        playing = False
        last_off = -999.0
        last_onset = -999.0   # most recent note onset <= t (for vib mallet strike)
        onset_count = 0       # number of onsets <= t (alternates the two mallets)

        for row in notes:
            onset, dur = row[0], row[2]
            note_end = onset + dur
            if onset <= t:
                onset_count += 1
                if onset > last_onset:
                    last_onset = onset
            if onset <= t <= note_end:
                playing = True
                glow = max(glow, 1.0)
            elif t > note_end:
                decay = (t - note_end) / GLOW_DECAY
                if decay < 1.0:
                    glow = max(glow, 1.0 - decay)
                if note_end > last_off:
                    last_off = note_end

        states[sid] = dict(glow=glow, playing=playing, last_off=last_off,
                           last_onset=last_onset, onset_count=onset_count)
    return states


# Which of each draw_*()'s returned patches share the base body colour and
# should join the playing-glow (indices into that patch list) — bassoon's
# body is two same-coloured tubes and trumpet's is split top/bottom around
# the valve cluster (leadpipe + v_tube); lighting only index 0 left the
# other piece looking unlit. See woodwind_section_poc.py/brass_section_poc.py
# (these draw_fns are imported from there) for the full patch-order notes.
GLOW_PATCH_IDX = {
    'flute':      (0,),
    'clarinet':   (0,),
    'vibraphone': (0,),
    'oboe':       (0,),
    'bassoon':    (0, 1),
    'trumpet':    (0, 9),
}


def _set_patch_color(patch, color):
    """Arc never fills (matplotlib forces fill=False on it), so its visible
    colour is the edge/line colour, not facecolor — set whichever actually
    renders."""
    if isinstance(patch, Arc):
        patch.set_edgecolor(color)
    else:
        patch.set_facecolor(color)


# ── Scene ─────────────────────────────────────────────────────────────────────
class MelodyScene:
    """Manages per-seat transforms (sway + lean) and glow for the mixed ensemble."""

    def __init__(self, fig, ax, seats):
        self.fig = fig
        self.ax = ax
        self.seats = seats
        self._seat_patches  = {}
        self._seat_pivot    = {}
        self._seat_lean_dir = {}
        self._body_patches  = {}
        self._vib_stems     = {}   # sid -> [stem_left, stem_right] (Line2D)
        self._vib_mallets   = {}   # sid -> [head_left, head_right]  (Ellipse)
        self._vib_geom      = {}   # sid -> [per-mallet pivot/arm/rest-theta dict]
        self._sway_env      = {}   # sid → current sway envelope (0..1, eased toward playing state)

        draw_fn = {
            'flute':      ww.draw_flute,
            'clarinet':   ww.draw_clarinet,
            'vibraphone': draw_vibraphone,
            'oboe':       ww.draw_oboe,
            'bassoon':    ww.draw_bassoon,
            'trumpet':    br.draw_trumpet,
        }

        for s in seats:
            fn = draw_fn[s['kind']]
            # br.draw_trumpet returns a 4th "extra" dict (used by
            # brass_section_poc.py's trombone slide animation); melody's
            # trumpet seat doesn't need it.
            patches, pivot, lean_dir, *_extra = fn(ax, s['cx'], s['cy'], s['sc'])

            self._seat_patches[s['id']]   = patches
            self._seat_pivot[s['id']]     = pivot
            self._seat_lean_dir[s['id']]  = lean_dir
            self._body_patches[s['id']]   = [patches[i] for i in GLOW_PATCH_IDX[s['kind']]]
            self._sway_env[s['id']]       = 0.0   # starts still; fades in on first note

            # Vibraphone: keep references to its two mallet rods + heads (the
            # last four patches draw_vibraphone returns: stemL, headL, stemR,
            # headR) plus per-mallet pivot/arm/rest-theta for the strike arc.
            if s['kind'] == 'vibraphone':
                self._vib_stems[s['id']]   = [patches[-4], patches[-2]]
                self._vib_mallets[s['id']] = [patches[-3], patches[-1]]  # heads
                sc_g = s['sc']
                bar_top = s['cy'] - (28.0 * sc_g) / 2
                arm_g = VIB_MALLET_ARM * sc_g
                total_w_g = (8 * 6 * sc_g) + (7 * 7 * sc_g)  # n_bars*bar_w + gaps
                offs = (-total_w_g * 0.2, total_w_g * 0.2)
                signs = (+1.0, -1.0)
                self._vib_geom[s['id']] = [
                    dict(pivot_x=s['cx'] + off, pivot_y=bar_top - arm_g,
                         arm=arm_g, strike_y=bar_top,
                         rest_theta=sign * VIB_THETA_REST)
                    for off, sign in zip(offs, signs)
                ]

            xf = mtransforms.Affine2D() + ax.transData
            for p in patches:
                p.set_transform(xf)

            # Vibraphone label stays put (short instrument, no overlap risk).
            # Back row (flute/clarinet) needs more upward clearance than the
            # old fixed offset gave — labels used to sit right on the tip.
            # Front row (oboe/bassoon/trumpet) moves below the instrument
            # instead, since pushing it further up would run into the back
            # row's own labels/instruments.
            if s['kind'] == 'vibraphone':
                label_y = s['cy'] + 55 * s['sc']
            elif s['cy'] == MEL_Y_BACK:
                label_y = s['cy'] + 90 * s['sc']
            else:
                label_y = s['cy'] - 70 * s['sc']
            ax.text(s['cx'], label_y, s['name'],
                    ha='center', va='top', fontsize=8,
                    color=LABEL_CLR, zorder=12)

    @staticmethod
    def _get_base_color(kind):
        colors = {
            'flute':      ww.CLR_FLUTE,
            'clarinet':   ww.CLR_CLARINET,
            'vibraphone': CLR_VIB_BARS,
            'oboe':       ww.CLR_OBOE,
            'bassoon':    ww.CLR_BASSOON,
            'trumpet':    br.CLR_BRASS,
        }
        return colors.get(kind, (0.5, 0.5, 0.5))

    def update(self, t, states):
        for s in self.seats:
            sid   = s['id']
            state = states[sid]
            glow  = state['glow']
            playing = state['playing']
            last_off = state['last_off']

            px, py = self._seat_pivot[sid]
            lean_max = PLAY_LEAN_DEG[s['kind']]
            lean_dir = self._seat_lean_dir[sid]

            is_vib = (s['kind'] == 'vibraphone')
            # Idle sway — vibraphone stays in place (no sway); others sway
            # ~2x more, faded by an envelope that eases toward 1 (playing)
            # or 0 (been silent a while) so they settle to stillness after
            # resting rather than swaying forever.
            if is_vib:
                sway_angle = 0.0
            else:
                sway_tau = SWAY_ENV_TAU_IN if playing else SWAY_ENV_TAU_OUT
                sway_alpha = 1.0 - math.exp(-(1.0 / FPS) / sway_tau)
                target_env = 1.0 if playing else 0.0
                self._sway_env[sid] += (target_env - self._sway_env[sid]) * sway_alpha
                sway_angle = (SWAY_AMP_DEG * self._sway_env[sid]
                              * math.sin(2 * math.pi * s['sway_freq'] * t + s['sway_phase']))

            # Playing lean
            if playing:
                lean_angle = lean_max
            else:
                dt_off = t - last_off
                if 0 <= dt_off < PLAY_RELAX_T:
                    phase = dt_off / PLAY_RELAX_T
                    phase = phase * phase * (3.0 - 2.0 * phase)
                    lean_angle = lean_max * (1.0 - phase)
                else:
                    lean_angle = 0.0

            # Trumpet gets the brass base tilt; others don't
            base_tilt = BASE_TILT_TRUMPET if s['kind'] == 'trumpet' else 0.0
            total_angle = base_tilt + sway_angle + lean_angle * math.copysign(1, lean_dir)

            # Glow
            if glow > 0.02:
                base_c = self._get_base_color(s['kind'])
                tint   = GLOW_CLR[s['kind']]
                blended = tuple(
                    base_c[i] + glow * (tint[i] - base_c[i])
                    for i in range(3)
                )
                color = blended
            else:
                color = self._get_base_color(s['kind'])
            for p in self._body_patches[sid]:
                _set_patch_color(p, color)

            # Apply transform
            xf = (mtransforms.Affine2D()
                  .translate(-px, -py)
                  .rotate_deg(total_angle)
                  .translate(px, py)
                  + self.ax.transData)
            for p in self._seat_patches[sid]:
                p.set_transform(xf)

            # Vibraphone: marimba-style mallet strike on each note onset.
            # total_angle is 0 for vibraphone (no sway/lean), so the mallets
            # are positioned directly in data coords.  Each head swings along
            # an arc from its raised rest (theta = rest_theta) down to the bar
            # top (theta = 0); the rod is the fixed-length arm pivot -> head.
            if is_vib:
                stems = self._vib_stems[sid]
                heads = self._vib_mallets[sid]
                geoms = self._vib_geom[sid]
                last_onset = state.get('last_onset', -999.0)
                onset_count = state.get('onset_count', 0)
                dt_s = t - last_onset
                total_s = VIB_STRIKE_APP_T + VIB_STRIKE_DWL_T + VIB_STRIKE_REB_T
                striking = 0.0 <= dt_s <= total_s
                idx = onset_count % 2  # alternate left/right mallet per onset
                for mi, (stem, head, g) in enumerate(zip(stems, heads, geoms)):
                    rest_theta = g['rest_theta']
                    if striking and mi == idx:
                        if dt_s < VIB_STRIKE_APP_T:
                            p = (dt_s / VIB_STRIKE_APP_T) ** 1.6    # ease-in
                            theta = rest_theta * (1.0 - p)
                            a = 0.95
                        elif dt_s < VIB_STRIKE_APP_T + VIB_STRIKE_DWL_T:
                            theta = 0.0
                            a = 1.0
                        else:
                            p = (dt_s - VIB_STRIKE_APP_T - VIB_STRIKE_DWL_T) / VIB_STRIKE_REB_T
                            p = 1.0 - (1.0 - p) ** 2                 # ease-out rebound
                            theta = rest_theta * p
                            a = max(0.0, 0.95 * (1.0 - p))
                    else:
                        theta = rest_theta
                        a = 0.45 if glow > 0.05 else 0.30
                    tr = math.radians(theta)
                    hx = g['pivot_x'] - g['arm'] * math.sin(tr)
                    hy = g['pivot_y'] + g['arm'] * math.cos(tr)
                    head.set_center((hx, hy))
                    head.set_alpha(a)
                    stem.set_data([g['pivot_x'], hx], [g['pivot_y'], hy])
                    stem.set_alpha(a)


# ── Render ────────────────────────────────────────────────────────────────────
def render(npy_file, tempo, duration):
    notes = load_melody_voices(npy_file, tempo)
    seats = make_seats()
    seat_notes = route_notes(notes, seats)

    Path(FRAMES_DIR).mkdir(exist_ok=True)
    n_frames = int(math.ceil(duration * FPS))
    log.info(f"[melody] {n_frames} frames ({duration:.1f}s @ {FPS}fps)")

    fig, ax = plt.subplots(figsize=(W / DPI, H / DPI), dpi=DPI)
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    ax.set_xlim(0, W)
    ax.set_ylim(0, H)
    ax.set_aspect('equal')
    ax.axis('off')
    fig.patch.set_alpha(0.0)
    ax.patch.set_alpha(0.0)

    scene = MelodyScene(fig, ax, seats)

    for fi in range(n_frames):
        t = fi / FPS
        states = compute_state(t, seat_notes, seats)
        scene.update(t, states)
        fig.savefig(f"{FRAMES_DIR}/frame_{fi:06d}.png",
                    dpi=SAVE_DPI, transparent=True)
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


