#!/usr/bin/env python3
"""
marimba_poc.py — Animusic-style marimba POC animation.

Pipeline (each stage caches intermediate files):
  Stage 1  Load note events  → poc_notes.npy
  Stage 2  Render frames     → poc_frames/frame_NNNNNN.png
  Stage 3  Assemble video    → poc_marimba_POC.mp4  (frames + audio)

Stage 1 sources (choose one):
  --npy FILE --tempo BPM [--voice N]   Read directly from a WreckingCrew
                                       *_features_array.npy (preferred).
  --mp3 FILE                           Fall back to librosa audio analysis.

features_array column layout (after fix_start_times):
  0 Inst  1 Start(beats)  2 Hold(beats)  3 Vel(dB)  4 Ton(cents)
  5 Oct   6 Voice         7 Ste  8 En1  9 Gls  10 Ups  11 Ren
  12 2gl  13 3gl          14 Vol

poc_notes.npy written by Stage 1: N × 5
  [start_s, pitch_cents, duration_s, velocity, volume]
  pitch_cents = col[5]*1200 + col[4]   (monotone pitch ordering)
"""

import argparse
import os
import subprocess
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import Ellipse, Polygon as MplPolygon
import librosa

# ── Config ────────────────────────────────────────────────────────────────────
DEFAULT_MP3   = "Uploads/marimba_example_POC.mp3"
DEFAULT_NPY   = None          # e.g. "bwv261_features_array.npy"
DEFAULT_TEMPO = 110.0         # BPM — only used when reading from .npy
DEFAULT_VOICE = 5             # Csound voice to animate (5=finger_piano)
FRAMES_DIR    = "poc_frames"
NOTES_FILE    = "poc_notes.npy"
VIDEO_OUT     = "poc_marimba_POC.mp4"

FPS = 30
W, H = 1280, 720
DPI  = 96

# Oblique (cabinet) projection — depth direction in scene maps to screen as:
#   screen_x += depth * DEPTH_AX   (rightward)
#   screen_y += depth * DEPTH_AY   (upward — farther back = higher on screen)
DEPTH_AX     = 0.60
DEPTH_AY     = 0.46

# Bar geometry
BAR_FRONT_Y  = 290    # y of front-bottom edge of all bars
BAR_THICKNESS = 14    # height of front face (thin from this elevated angle)
DEPTH_LOW    = 100    # bar depth (px) for lowest note  (long physical bar)
DEPTH_HIGH   = 34     # bar depth (px) for highest note (short physical bar)
MARGIN_L     = 86
MARGIN_R     = 86

# Mallet pendulum geometry
# The pivot sits ARM pixels behind the bar centre in the scene's depth direction,
# at the same height — representing the invisible player's hand.
# theta is a rotation FROM the natural strike direction (pivot→bar centre):
#   theta =  0    → head at bar top-centre (strike)
#   theta > 0     → head raised above bar (rest)
#   theta < 0     → head past bar going forward (follow-through)
NODE_FRAC    = 0.2242  # kept for reference; supports not drawn
MALLET_ARM   = 87      # 58 * 1.5 — 50% longer handle
_depth_mag   = (DEPTH_AX**2 + DEPTH_AY**2) ** 0.5
BACK_DX      = DEPTH_AX / _depth_mag   # unit depth direction x (right)
BACK_DY      = DEPTH_AY / _depth_mag   # unit depth direction y (up in scene)
THETA_REST   = 70.0    # degrees; clockwise from strike → head ~100 px above bar
THETA_OVER   = -10.0   # counterclockwise follow-through past bar

# Invisible player's body position — behind and centred on the instrument.
# Every mallet stem is drawn as exactly MALLET_ARM px from the head toward
# this point, so handles always appear to originate near the middle regardless
# of which bar is struck.
PLAYER_X     = W // 2
PLAYER_Y     = 440

# Animation timing (seconds)
APPROACH_T = 0.075
DWELL_T    = 0.045   # ~1.4 frames — head clearly dwells at bar centre
OVER_T     = 0.030
REBOUND_T  = 0.160
GLOW_DECAY = 0.24

# Colours
BG_COLOR   = (0.005, 0.015, 0.060)
MALLET_CLR = (0.82, 0.90, 0.97)
STEM_CLR   = (0.50, 0.60, 0.72)
LABEL_CLR  = (0.34, 0.47, 0.60)


# ── Colour helpers ────────────────────────────────────────────────────────────

def bar_base_color(i, n):
    """Amber/warm (low, i=0) → steel-blue (high, i=n-1)."""
    t = i / max(n - 1, 1)
    if t < 0.5:
        s = t * 2
        return (0.80 - s * 0.40, 0.38 + s * 0.28, 0.02 + s * 0.30)
    else:
        s = (t - 0.5) * 2
        return (0.40 - s * 0.28, 0.66 - s * 0.22, 0.32 + s * 0.52)


def blended(base, intensity):
    """Blend base colour toward white-cyan on impact."""
    glow = np.array([0.45, 0.88, 1.00])
    b = np.array(base)
    return tuple(np.clip(b + intensity * (glow - b + 0.55 * glow), 0, 1))


def top_color(base):
    """Lighter version of base for the top face (facing viewer)."""
    return tuple(np.clip(np.array(base) * 1.18 + 0.04, 0, 1))


def front_color(base):
    """Darker version of base for the thin front face."""
    return tuple(np.array(base) * 0.65)


# ── Stage 1a: Features-array loader (preferred) ───────────────────────────────

def load_features_array(npy_file, tempo, voice=None):
    """Build note events from a WreckingCrew *_features_array.npy.

    Columns used:
      1 start (beats)  2 hold (beats)  3 velocity(dB)
      4 tonality(cents within oct)  5 octave  6 csound voice  14 volume

    Returns (notes, duration) where notes is N×5:
      [start_s, pitch_cents, duration_s, velocity, volume]
    """
    print(f"\n[Stage 1] Loading features array: {npy_file}")
    arr = np.load(npy_file)
    print(f"  Raw shape: {arr.shape}")

    # Apply the same audibility filters as send_to_csound_file
    mask = (arr[:, 5] > 0) & (arr[:, 2] > 0) & (arr[:, 14] > 0) & (arr[:, 3] > 0)
    if voice is not None:
        mask &= (arr[:, 6].astype(int) == int(voice))
    arr = arr[mask]
    print(f"  After filter (oct>0, hold>0, vol>0, vel>0"
          + (f", voice={voice}" if voice else "") + f"): {arr.shape[0]} rows")

    beats_per_sec = tempo / 60.0
    start_s    = arr[:, 1] / beats_per_sec
    duration_s = arr[:, 2] / beats_per_sec
    # pitch_cents = octave*1200 + tonality_cents — gives a monotone pitch ordering
    pitch_cents = arr[:, 5] * 1200.0 + arr[:, 4]
    velocity    = arr[:, 3]
    volume      = arr[:, 14]

    notes = np.column_stack([start_s, pitch_cents, duration_s, velocity, volume])
    notes = notes[notes[:, 0].argsort()]   # sort by start time

    n_unique = len(np.unique(np.round(pitch_cents).astype(int)))
    print(f"  {len(notes)} events, {n_unique} unique pitches, "
          f"pitch range {pitch_cents.min():.0f}–{pitch_cents.max():.0f} cents")

    np.save(NOTES_FILE, notes)
    print(f"  Saved {NOTES_FILE}")

    duration = float(notes[:, 0].max() + notes[:, 2].max()) + 2.0  # +2s reverb tail
    return notes, duration


# ── Stage 1b: Audio analysis fallback ─────────────────────────────────────────

def analyze_audio(mp3_file):
    print(f"\n[Stage 1] Analyzing: {mp3_file}")
    y, sr = librosa.load(mp3_file, sr=None, mono=True)
    duration = librosa.get_duration(y=y, sr=sr)
    print(f"  Duration {duration:.2f}s  sr={sr}")

    onset_env = librosa.onset.onset_strength(y=y, sr=sr)
    onset_frames = librosa.onset.onset_detect(
        onset_envelope=onset_env, sr=sr, units='frames', backtrack=True,
        pre_max=3, post_max=3, pre_avg=5, post_avg=5, delta=0.18,
    )
    onset_times = librosa.frames_to_time(onset_frames, sr=sr)

    hop = 512
    f0, _, _ = librosa.pyin(
        y,
        fmin=librosa.note_to_hz('C2'),
        fmax=librosa.note_to_hz('C7'),
        sr=sr, hop_length=hop,
    )
    pitch_times = librosa.frames_to_time(np.arange(len(f0)), sr=sr, hop_length=hop)

    pitches = []
    for t in onset_times:
        win = (pitch_times >= t) & (pitch_times <= t + 0.055)
        valid = f0[win]
        valid = valid[~np.isnan(valid)]
        pitches.append(float(np.median(valid)) if len(valid) else np.nan)

    onset_times = np.array(onset_times)
    pitches = np.array(pitches)
    mask = ~np.isnan(pitches)
    onset_times, pitches = onset_times[mask], pitches[mask]

    midi = np.round(librosa.hz_to_midi(pitches)).astype(int)
    print(f"  {len(onset_times)} pitched onsets  "
          f"MIDI {midi.min()}–{midi.max()} "
          f"({len(np.unique(midi))} unique notes)")

    # Save in the same N×5 format as load_features_array for downstream compatibility.
    # Audio analysis has no duration/velocity/volume info, so use placeholder values.
    dur_placeholder = np.full(len(onset_times), 0.25)
    vel_placeholder = np.full(len(onset_times), 69.0)
    vol_placeholder = np.full(len(onset_times), 11.0)
    notes = np.column_stack([onset_times, midi.astype(float),
                             dur_placeholder, vel_placeholder, vol_placeholder])
    np.save(NOTES_FILE, notes)
    print(f"  Saved {NOTES_FILE}")
    return notes, duration


# ── Stage 2: Frame rendering ──────────────────────────────────────────────────

def _pitch_label(pitch_cents):
    """Approximate note name from pitch_cents (oct*1200 + ton_cents).
    Reference: C4 = 4800 cents → 261.63 Hz.  JI vs ET difference is small."""
    hz = 261.63 * 2.0 ** ((pitch_cents - 4800.0) / 1200.0)
    return librosa.hz_to_note(hz, octave=True)


BASE_SLOT_W = 25.8   # px/bar at scale=1.0 — matches the original 43-bar layout


def build_layout(notes, base_x=None, base_y=None, avail=None, scale=1.0,
                  player_x=None, player_y=None, idx_offset=0):
    """Return bar dicts (with oblique geometry) and pitch→bar_index map.

    notes col 1 is pitch_cents (features-array path) or MIDI int (audio path).
    Both are treated as a monotone pitch key; bars are sorted low→high.

    base_x/base_y: where this instrument's bar rack sits (front-left corner
      of the lowest bar / front-bottom edge). Defaults reproduce the
      original single, full-width marimba.
    avail: total width for the bar rack. Defaults to a full-width layout;
      pass an explicit value to fit N bars into a small on-stage seat.
    scale: linear scale applied to bar thickness/depth/mallet arm, so a
      seat's instrument and gesture are proportioned like the full-size one.
    player_x/player_y: the invisible player's position this seat's mallet
      stems point toward. Defaults to the module-level PLAYER_X/PLAYER_Y.
    idx_offset: starting bar index, so multiple seats can be merged into
      one combined bars list / pitch_to_idx map with distinct indices.
    """
    if base_x is None:
        base_x = MARGIN_L
    if base_y is None:
        base_y = BAR_FRONT_Y
    if player_x is None:
        player_x = PLAYER_X
    if player_y is None:
        player_y = PLAYER_Y

    pitch_vals = np.sort(np.unique(np.round(notes[:, 1]).astype(int)))
    n = len(pitch_vals)
    pitch_to_idx = {p: i + idx_offset for i, p in enumerate(pitch_vals)}

    if avail is None:
        avail = W - MARGIN_L - MARGIN_R
    slot_w = avail / n

    bar_thickness = BAR_THICKNESS * scale
    depth_low     = DEPTH_LOW * scale
    depth_high    = DEPTH_HIGH * scale
    mallet_arm    = MALLET_ARM * scale

    bars = []
    for i, pitch in enumerate(pitch_vals):
        t   = i / max(n - 1, 1)           # 0 = lowest note, 1 = highest
        bw  = slot_w * (0.82 - t * 0.20)  # lower bars slightly wider
        cx  = base_x + slot_w * (i + 0.5)
        depth = depth_low + (depth_high - depth_low) * t  # lower notes longer

        # Oblique projection: compute corners of top face (parallelogram)
        # Front edge at y = base_y + bar_thickness (top of front face)
        front_top_y = base_y + bar_thickness
        # Back edge shifts right and up by the depth vector
        back_top_y  = front_top_y + depth * DEPTH_AY
        back_x_off  = depth * DEPTH_AX    # x-shift for back corners

        top_face_pts = np.array([
            [cx - bw/2,            front_top_y],   # front-left
            [cx + bw/2,            front_top_y],   # front-right
            [cx + bw/2 + back_x_off, back_top_y],  # back-right
            [cx - bw/2 + back_x_off, back_top_y],  # back-left
        ])
        front_face_pts = np.array([
            [cx - bw/2, base_y],
            [cx + bw/2, base_y],
            [cx + bw/2, front_top_y],
            [cx - bw/2, front_top_y],
        ])

        # Centre of top face in screen space (for glow halo positioning)
        cx_top = cx + back_x_off / 2
        cy_top = front_top_y + depth * DEPTH_AY / 2

        # Pivot: mallet_arm px behind bar top-centre in the depth direction.
        # The invisible player's hand is at this point; the head reaches
        # (cx_top, cy_top) when theta = 0 (strike position).
        pivot_x = cx_top + mallet_arm * BACK_DX
        pivot_y = cy_top + mallet_arm * BACK_DY
        # Strike arm vector (pivot → bar centre)
        vsx = cx_top - pivot_x   # = -mallet_arm * BACK_DX
        vsy = cy_top - pivot_y   # = -mallet_arm * BACK_DY

        # Rest head position: rotate strike arm by THETA_REST (clockwise)
        tr = np.radians(THETA_REST)
        cos_r, sin_r = np.cos(tr), np.sin(tr)
        rest_hx = pivot_x + vsx * cos_r + vsy * sin_r
        rest_hy = pivot_y - vsx * sin_r + vsy * cos_r

        # Label: if pitch looks like a raw MIDI int (<= 127) use midi_to_note,
        # otherwise treat as pitch_cents and compute approximate note name.
        if pitch <= 127:
            label = librosa.midi_to_note(int(pitch))
        else:
            label = _pitch_label(float(pitch))

        bars.append(dict(
            pitch=pitch, idx=i + idx_offset, cx=cx, width=bw, depth=depth,
            cx_top=cx_top, cy_top=cy_top,
            vsx=vsx, vsy=vsy,
            pivot_x=pivot_x, pivot_y=pivot_y,
            rest_hx=rest_hx, rest_hy=rest_hy,
            top_pts=top_face_pts,
            front_pts=front_face_pts,
            note=label,
            base=bar_base_color(i, n),
            base_y=base_y, scale=scale, mallet_arm=mallet_arm,
            player_x=player_x, player_y=player_y,
        ))
    return bars, pitch_to_idx


def build_multi_layout(notes, seats):
    """Combine per-seat build_layout() calls into one bars list / pitch map.

    seats: list of dicts, each with a 'p_lo'/'p_hi' pitch_cents band (like
      string_section_poc's PLAYERS) plus base_x/base_y/scale/player_x/
      player_y for that seat's on-stage instrument. avail is computed from
      the seat's own bar count so bar width stays consistent across seats.
    """
    all_bars = []
    pitch_to_idx = {}
    idx = 0
    for seat in seats:
        lo, hi = seat.get('p_lo'), seat.get('p_hi')
        mask = np.ones(len(notes), dtype=bool)
        if lo is not None:
            mask &= notes[:, 1] >= lo
        if hi is not None:
            mask &= notes[:, 1] < hi
        sub = notes[mask]
        if len(sub) == 0:
            continue
        n_bars = len(np.unique(np.round(sub[:, 1]).astype(int)))
        avail = n_bars * BASE_SLOT_W * seat['scale']
        base_x = seat['cx'] - avail / 2
        bars, p2i = build_layout(
            sub, base_x=base_x, base_y=seat['base_y'], avail=avail,
            scale=seat['scale'], player_x=seat['player_x'],
            player_y=seat['player_y'], idx_offset=idx,
        )
        for b in bars:
            b['seat_name'] = seat['name']
        all_bars.extend(bars)
        pitch_to_idx.update(p2i)
        idx += len(bars)
    return all_bars, pitch_to_idx


class Scene:
    """Pre-allocated artists updated each frame (avoids full redraw cost)."""

    def __init__(self, fig, ax, bars, show_title=True, show_labels=True):
        self.ax   = ax
        self.bars = bars
        self._top_polys   = []
        self._front_polys = []
        self._halos       = []
        self._stems       = []
        self._heads       = []

        for b in bars:
            base = b['base']

            # Front face (thin, darker)
            ff = MplPolygon(b['front_pts'], closed=True,
                            fc=front_color(base), ec='none', zorder=4)
            ax.add_patch(ff)
            self._front_polys.append(ff)

            # Top face (parallelogram, lighter — main visible surface)
            tf = MplPolygon(b['top_pts'], closed=True,
                            fc=top_color(base),
                            ec=(0.7, 0.7, 1.0, 0.20), lw=0.6, zorder=5)
            ax.add_patch(tf)
            self._top_polys.append(tf)

            # Glow halo — zorder 6 puts it ON TOP of bar faces so the
            # centred impact flash is clearly visible.
            halo = Ellipse(
                (b['cx_top'], b['cy_top']),
                width=b['width'] * 2.0, height=40,
                fc=base, alpha=0.0, zorder=6,
            )
            ax.add_patch(halo)
            self._halos.append(halo)

            # Mallet stem — mallet_arm px from head toward this seat's
            # player position, so the handle always points back toward
            # the (possibly per-seat) invisible player.
            sc = b.get('scale', 1.0)
            arm = b.get('mallet_arm', MALLET_ARM)
            px  = b.get('player_x', PLAYER_X)
            py  = b.get('player_y', PLAYER_Y)
            dhx = px - b['rest_hx']
            dhy = py - b['rest_hy']
            dd  = max((dhx*dhx + dhy*dhy)**0.5, 1.0)
            hend_x = b['rest_hx'] + arm * dhx / dd
            hend_y = b['rest_hy'] + arm * dhy / dd
            (stem,) = ax.plot(
                [hend_x, b['rest_hx']],
                [hend_y, b['rest_hy']],
                color=STEM_CLR, lw=2.2 * sc, solid_capstyle='round', zorder=7,
            )
            self._stems.append(stem)

            # Mallet head
            head = Ellipse(
                (b['rest_hx'], b['rest_hy']), width=16 * sc, height=13 * sc,
                fc=MALLET_CLR, ec=(0.55, 0.65, 0.78), lw=1.0, zorder=8,
            )
            ax.add_patch(head)
            self._heads.append(head)

            # Note label below bar front edge
            if show_labels:
                ax.text(
                    b['cx'], BAR_FRONT_Y - 12, b['note'],
                    ha='center', va='top', fontsize=7,
                    color=LABEL_CLR, zorder=9,
                )

        # Title
        if show_title:
            ax.text(
                W / 2, H - 20, "J.S. Bach · Just Intonation Marimba",
                ha='center', va='top', fontsize=11,
                color=(0.30, 0.46, 0.64), zorder=9,
            )

    def update(self, bar_glow, mallet_heads, mallet_visible):
        for b in self.bars:
            i = b['idx']
            g = bar_glow[i]
            hx, hy = mallet_heads[i]
            visible = bool(mallet_visible[i])

            # Bar colours
            tc = blended(top_color(b['base']), g)
            fc_col = blended(front_color(b['base']), g * 0.5)
            self._top_polys[i].set_facecolor(tc)
            self._front_polys[i].set_facecolor(fc_col)

            # Glow halo — rendered above bar faces; brighter alpha so the
            # centred impact flash is unmistakeable.
            sc = b.get('scale', 1.0)
            if g > 0.04:
                self._halos[i].set_alpha(g * 0.55)
                self._halos[i].set_facecolor(tc)
                self._halos[i].set_width(b['width'] * (2.0 + g * 1.2))
                self._halos[i].set_height((40 + g * 55) * sc)
            else:
                self._halos[i].set_alpha(0.0)

            # Mallet — only shown during approach/strike/rebound
            self._stems[i].set_visible(visible)
            self._heads[i].set_visible(visible)
            if visible:
                # Stem: fixed length (this seat's mallet_arm) from head
                # toward this seat's player position.
                arm = b.get('mallet_arm', MALLET_ARM)
                px  = b.get('player_x', PLAYER_X)
                py  = b.get('player_y', PLAYER_Y)
                dhx = px - hx
                dhy = py - hy
                dd  = max((dhx*dhx + dhy*dhy)**0.5, 1.0)
                hend_x = hx + arm * dhx / dd
                hend_y = hy + arm * dhy / dd
                self._stems[i].set_data(
                    [hend_x, hx], [hend_y, hy]
                )
                self._stems[i].set_color((0.75, 0.85, 1.0) if g > 0.25 else STEM_CLR)
                self._heads[i].set_center((hx, hy))
                hw = (14 + g * 5) * sc
                self._heads[i].set_width(hw * 1.3)
                self._heads[i].set_height(hw)
                self._heads[i].set_facecolor(
                    (1.0, 1.0, 1.0) if g > 0.45 else MALLET_CLR
                )


def compute_state(t, notes, pitch_to_idx, n_bars, bars):
    """Bar glow and mallet head (hx, hy) per bar at time t."""
    bar_glow   = np.zeros(n_bars)
    last_onset = {}

    for row in notes:
        onset_t = row[0]
        pitch   = int(round(row[1]))   # col 1: pitch_cents or MIDI int
        idx = pitch_to_idx.get(pitch)
        if idx is None:
            continue
        dt = t - onset_t

        if 0.0 <= dt <= GLOW_DECAY:
            bar_glow[idx] = max(bar_glow[idx], 1.0 - dt / GLOW_DECAY)

        total = APPROACH_T + DWELL_T + OVER_T + REBOUND_T
        if -APPROACH_T <= dt <= total:
            if idx not in last_onset or onset_t > last_onset[idx]:
                last_onset[idx] = onset_t

    mallet_visible = np.zeros(n_bars, dtype=bool)
    mallet_heads = []
    for i, b in enumerate(bars):
        if i in last_onset:
            mallet_visible[i] = True
            dt = t - last_onset[i]
            if dt < 0:
                # Approaching: THETA_REST → 0, ease-in
                phase = (dt + APPROACH_T) / APPROACH_T   # 0→1
                phase = phase ** 1.7
                theta = THETA_REST * (1.0 - phase)
            elif dt < DWELL_T:
                theta = 0.0
            elif dt < DWELL_T + OVER_T:
                # Swing-through: 0 → THETA_OVER
                phase = (dt - DWELL_T) / OVER_T
                theta = THETA_OVER * phase
            else:
                # Rebound: THETA_OVER → THETA_REST (smoothstep ease-in-out)
                phase = min(1.0, (dt - DWELL_T - OVER_T) / REBOUND_T)
                phase = phase * phase * (3.0 - 2.0 * phase)
                theta = THETA_OVER + (THETA_REST - THETA_OVER) * phase
        else:
            theta = THETA_REST

        # Rotate the strike arm vector by theta (clockwise = raise, CCW = follow-through)
        tr = np.radians(theta)
        cos_t, sin_t = np.cos(tr), np.sin(tr)
        hx = b['pivot_x'] + b['vsx'] * cos_t + b['vsy'] * sin_t
        hy = b['pivot_y'] - b['vsx'] * sin_t + b['vsy'] * cos_t
        mallet_heads.append((hx, hy))

    return bar_glow, mallet_heads, mallet_visible


def render_frames(notes, duration, transparent=False):
    print(f"\n[Stage 2] Rendering {FRAMES_DIR}/")
    Path(FRAMES_DIR).mkdir(exist_ok=True)

    bars, pitch_to_idx = build_layout(notes)
    n_bars   = len(bars)
    n_frames = int(np.ceil(duration * FPS))
    print(f"  {n_bars} bars, {n_frames} frames ({duration:.1f}s @ {FPS}fps)")

    fig, ax = plt.subplots(figsize=(W / DPI, H / DPI), dpi=DPI)
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    ax.set_xlim(0, W)
    ax.set_ylim(0, H)
    ax.set_aspect('equal')
    ax.axis('off')
    if transparent:
        fig.patch.set_alpha(0.0)
        ax.patch.set_alpha(0.0)
    else:
        fig.patch.set_facecolor(BG_COLOR)
        ax.set_facecolor(BG_COLOR)

    scene = Scene(fig, ax, bars, show_title=not transparent, show_labels=not transparent)

    savefig_kwargs = dict(dpi=DPI, bbox_inches=None)
    if transparent:
        savefig_kwargs.update(transparent=True)
    else:
        savefig_kwargs.update(facecolor=BG_COLOR)

    for fi in range(n_frames):
        t = fi / FPS
        bar_glow, mallet_heads, mallet_visible = compute_state(t, notes, pitch_to_idx, n_bars, bars)
        scene.update(bar_glow, mallet_heads, mallet_visible)
        fig.savefig(f"{FRAMES_DIR}/frame_{fi:06d}.png", **savefig_kwargs)
        if fi % 60 == 0:
            print(f"  {fi}/{n_frames}  t={t:.1f}s", flush=True)

    plt.close(fig)
    print(f"  Done — {n_frames} frames written.")


# ── Stage 3: Video assembly ───────────────────────────────────────────────────

def assemble_video(mp3_file):
    print(f"\n[Stage 3] Assembling → {VIDEO_OUT}")
    cmd = [
        'ffmpeg', '-y',
        '-framerate', str(FPS),
        '-i', f'{FRAMES_DIR}/frame_%06d.png',
        '-i', mp3_file,
        '-c:v', 'libx264', '-preset', 'fast', '-crf', '18',
        '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '192k',
        '-shortest',
        VIDEO_OUT,
    ]
    print(' '.join(cmd))
    subprocess.run(cmd, check=True)
    size_mb = os.path.getsize(VIDEO_OUT) / 1024 / 1024
    print(f"  Done — {VIDEO_OUT} ({size_mb:.1f} MB)")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--mp3',   default=DEFAULT_MP3)
    parser.add_argument('--npy',   default=DEFAULT_NPY,
                        help='Path to *_features_array.npy (skips audio analysis)')
    parser.add_argument('--tempo', type=float, default=DEFAULT_TEMPO,
                        help='Tempo in BPM (required with --npy)')
    parser.add_argument('--voice', type=int, default=DEFAULT_VOICE,
                        help='Csound voice number to filter (required with --npy)')
    parser.add_argument('--stage', choices=['1', '2', '3', 'all'], default='all')
    parser.add_argument('--duration', type=float, default=None,
                        help='Override computed duration (seconds), e.g. to '
                             'match a shared timeline with another sequence')
    parser.add_argument('--transparent', action='store_true',
                        help='Render frames with a transparent background '
                             'and no title/note labels, for compositing')
    args = parser.parse_args()

    if args.stage in ('1', 'all'):
        if args.npy:
            notes, duration = load_features_array(args.npy, args.tempo, args.voice)
        else:
            notes, duration = analyze_audio(args.mp3)
    else:
        notes = np.load(NOTES_FILE)
        if args.npy:
            duration = float(notes[:, 0].max() + notes[:, 2].max()) + 2.0
        else:
            y, sr = librosa.load(args.mp3, sr=None, mono=True)
            duration = librosa.get_duration(y=y, sr=sr)

    if args.duration is not None:
        duration = args.duration

    if args.stage in ('2', 'all'):
        render_frames(notes, duration, transparent=args.transparent)

    if args.stage in ('3', 'all'):
        assemble_video(args.mp3)


if __name__ == '__main__':
    main()
