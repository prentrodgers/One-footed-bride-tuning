#!/usr/bin/env python3
"""
conductor_section_poc.py — an invisible conductor with a large white baton.

The conductor stands at the front centre of the stage (between the bowed
strings and the melody section) and indicates which beat of the original
chorale the orchestra is playing.  The baton points:

    beat 0 (chord 0)  → DOWN   (the ictus / downbeat)
    beat 1 (chord 4)  → LEFT
    beat 2 (chord 8)  → RIGHT
    beat 3 (chord 12) → UP

The beat is computed from the frame time and tempo:
    time_in_beats = t * tempo / 60
    beat_in_measure = int(time_in_beats) % 4

(4 chords per beat, 16 chords per measure in 4/4 — matching the chord-index
metadata the user described: beats at positions 0, 4, 8, 12 in the chord list.)

The conductor is invisible — only the baton is drawn.  Between beats the
baton smoothly flicks to the next position (a quick preparatory gesture).

Usage:
  python conductor_section_poc.py --npy bwv261_features_array.npy \\\\
      --tempo 106 --duration 25.1
"""

import argparse
import math
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Circle

import marimba_poc as mp
import stage_layout as stage

import logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%d %H:%M")
log = logging.getLogger(__name__)

FRAMES_DIR = "conductor_frames"
FPS        = 30
W, H, DPI = mp.W, mp.H, mp.DPI

# Conductor position — front centre, between bowed strings and melody
CONDUCTOR_X = 640
CONDUCTOR_Y = stage.yup(590)   # screen 590 (near bottom, in front)

# Baton dimensions (px at scale 1.0)
BATON_LEN  = 60       # was 80 — shortened 25%
BATON_W    = 5
BATON_CLR  = (1.0, 1.0, 1.0)
BATON_EDGE = (0.85, 0.85, 0.85)
HANDLE_LEN = 12       # was 16 — shortened to match
HANDLE_W   = 8

# Beat → baton angle (degrees from straight down = 0°, clockwise positive
# in screen space due to the cy - L*cos(θ) term in _draw_baton).
# The conductor faces the orchestra (toward the back of the stage), so:
#   conductor's left  = screen left  = smaller x
#   conductor's right = screen right = larger x
#   beat 0 → down   =   0°  (ictus / downbeat)
#   beat 1 → left   = -90°  (conductor's left = stage left)
#   beat 2 → right  =  90°  (conductor's right = stage right)
#   beat 3 → up     = 180°
BEAT_ANGLES = {0: 0.0, 1: -90.0, 2: 90.0, 3: 180.0}

# Preparation time: the baton starts moving toward the NEXT beat this many
# seconds before the beat arrives, and arrives exactly at the beat onset.
PREP_T = 0.25

# Column 15 of the features array = chord_idx (the original chorale chord
# index each note was derived from, added by WreckingCrew.py).
CHORD_IDX_COL = 15


def _build_chord_timeline(npy_file, tempo):
    """Load the features array and build a sorted (start_s, chord_idx) timeline.

    Returns an (N, 2) array of [start_time_seconds, chord_idx] sorted by
    start time.  Each audible note's start time and its chord_idx (col 15)
    are extracted.  The conductor uses this to know which chord is playing
    at any given moment, accounting for the variable repeat expansion.
    """
    arr = np.load(npy_file)
    bps = tempo / 60.0
    # Filter audible notes (same mask as the section POCs)
    mask = (arr[:, 5] > 0) & (arr[:, 2] > 0) & (arr[:, 14] > 0) & (arr[:, 3] > 0)
    audible = arr[mask]
    if len(audible) == 0:
        return np.zeros((0, 2))
    start_s = audible[:, 1] / bps
    chord_idx = audible[:, CHORD_IDX_COL].astype(int) if audible.shape[1] > CHORD_IDX_COL else np.zeros(len(audible))
    timeline = np.column_stack([start_s, chord_idx])
    timeline = timeline[timeline[:, 0].argsort()]
    return timeline


def _chord_at_time(t, timeline):
    """Return the chord_idx active at time t (the most recent note's chord)."""
    if len(timeline) == 0:
        return 0
    # Find the last note that started at or before t
    idx = np.searchsorted(timeline[:, 0], t, side='right') - 1
    if idx < 0:
        return int(timeline[0, 1])  # before first note → first chord
    return int(timeline[idx, 1])


def _beat_from_chord(chord_idx):
    """Map a chord index to a beat-in-measure (0-3).

    The chorale has 4 chords per beat (sixteenth notes in 4/4), so:
        beat 0 = chords 0,4,8,12,...  (chord_idx // 4) % 4 == 0
        beat 1 = chords 1,5,9,13,...  (chord_idx // 4) % 4 == 1  — but the
        user specified beat 1 = chord 4, beat 2 = chord 8, beat 3 = chord 12,
        which means beat = (chord_idx // 4) % 4.
    """
    return (chord_idx // 4) % 4


def _baton_angle(t, tempo, timeline):
    """Compute the baton angle (degrees from down) at time t.

    Uses the chord_idx from the features array (col 15) to determine which
    beat is currently playing, accounting for the variable repeat expansion.
    The baton sits at the current beat's position, then starts a smooth
    preparation gesture toward the next beat's position PREP_T seconds
    before the next beat arrives, arriving exactly at the beat onset.
    """
    chord_idx = _chord_at_time(t, timeline)
    beat_in_measure = _beat_from_chord(chord_idx)

    # Find when the next beat starts by scanning forward in the timeline
    # for the first note whose chord maps to a different beat.
    current_beat = beat_in_measure
    next_beat_time = None
    if len(timeline) > 0:
        for i in range(len(timeline)):
            if timeline[i, 0] > t:
                next_chord = int(timeline[i, 1])
                next_beat = _beat_from_chord(next_chord)
                if next_beat != current_beat:
                    next_beat_time = timeline[i, 0]
                    break

    current_angle = BEAT_ANGLES[current_beat]

    # If no next beat found, just hold at current angle
    if next_beat_time is None or next_beat_time <= t:
        return current_angle

    # Next beat's angle
    next_beat_idx = (current_beat + 1) % 4
    next_angle = BEAT_ANGLES[next_beat_idx]

    # Shorter angular path for wrap-around (beat 3 → beat 0)
    diff = next_angle - current_angle
    if diff > 180:
        next_adj = current_angle + diff - 360
    elif diff < -180:
        next_adj = current_angle + diff + 360
    else:
        next_adj = next_angle

    # Preparation: starts PREP_T before the next beat, arrives at beat onset
    prep_start = next_beat_time - PREP_T
    if t < prep_start:
        return current_angle
    else:
        ph = (t - prep_start) / PREP_T
        ph = min(1.0, max(0.0, ph))
        ph = ph * ph * (3.0 - 2.0 * ph)  # smoothstep ease
        return current_angle + (next_adj - current_angle) * ph


def _draw_baton(ax, cx, cy, angle_deg, scale=1.0):
    """Draw the baton as a thick white line + handle, pivoting at (cx, cy)."""
    patches = []
    angle_rad = math.radians(angle_deg)

    tip_x = cx + BATON_LEN * scale * math.sin(angle_rad)
    tip_y = cy - BATON_LEN * scale * math.cos(angle_rad)
    handle_x = cx - HANDLE_LEN * scale * math.sin(angle_rad)
    handle_y = cy + HANDLE_LEN * scale * math.cos(angle_rad)

    # Baton shaft — thick white line
    shaft, = ax.plot([handle_x, tip_x], [handle_y, tip_y],
                     color=BATON_CLR, lw=BATON_W * scale, alpha=0.95,
                     solid_capstyle='round', zorder=10)
    patches.append(shaft)

    # Handle — slightly thicker, darker segment near the pivot
    handle, = ax.plot([cx, handle_x], [cy, handle_y],
                      color=BATON_EDGE, lw=HANDLE_W * scale, alpha=0.9,
                      solid_capstyle='round', zorder=11)
    patches.append(handle)

    # Small white circle at the pivot (the conductor's hand)
    hand = Circle((cx, cy), radius=4 * scale,
                  fc=BATON_CLR, ec='none', alpha=0.9, zorder=12)
    ax.add_patch(hand)
    patches.append(hand)

    return patches


def render(npy_file, tempo, duration):
    Path(FRAMES_DIR).mkdir(exist_ok=True)
    n_frames = int(math.ceil(duration * FPS))
    log.info(f"[conductor] {n_frames} frames ({duration:.1f}s @ {FPS}fps)")

    # Build the chord timeline from the features array (col 15 = chord_idx)
    timeline = _build_chord_timeline(npy_file, tempo)
    log.info(f"  chord timeline: {len(timeline)} notes, chord_idx range "
             f"{int(timeline[:,1].min())}..{int(timeline[:,1].max())}" if len(timeline) else "  (empty timeline)")
    log.info(f"  beat = (chord_idx // 4) % 4, read from features array col {CHORD_IDX_COL}")

    fig, ax = plt.subplots(figsize=(W / DPI, H / DPI), dpi=DPI)
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    ax.set_xlim(0, W)
    ax.set_ylim(0, H)
    ax.set_aspect('equal')
    ax.axis('off')
    fig.patch.set_alpha(0.0)
    ax.patch.set_alpha(0.0)

    for fi in range(n_frames):
        t = fi / FPS
        angle = _baton_angle(t, tempo, timeline)

        for p in ax.patches[:]:
            p.remove()
        for ln in ax.lines[:]:
            ln.remove()
        for txt in ax.texts[:]:
            txt.remove()

        _draw_baton(ax, CONDUCTOR_X, CONDUCTOR_Y, angle, scale=1.0)

        chord_idx = _chord_at_time(t, timeline)
        beat_in_measure = _beat_from_chord(chord_idx)
        ax.text(CONDUCTOR_X, 30, f"beat {beat_in_measure + 1}/4  (chord {chord_idx})",
                ha='center', va='bottom', fontsize=9,
                color=(0.7, 0.7, 0.7), alpha=0.5, zorder=15)

        fig.savefig(f"{FRAMES_DIR}/frame_{fi:06d}.png",
                    dpi=DPI, transparent=True)
        if fi % 200 == 0:
            log.info(f"  {fi}/{n_frames}  t={t:.1f}s  beat={beat_in_measure + 1}/4  "
                     f"chord={chord_idx}  angle={angle:.1f}°")

    plt.close(fig)
    log.info(f"  Done — {n_frames} frames written to {FRAMES_DIR}/")


def main():
    parser = argparse.ArgumentParser(
        description="Conductor with beat-indicating baton.")
    parser.add_argument('--npy', required=True,
                        help='Features array (unused, kept for gen-video.sh compatibility)')
    parser.add_argument('--tempo', type=float, required=True)
    parser.add_argument('--duration', type=float, required=True)
    args = parser.parse_args()
    render(args.npy, args.tempo, args.duration)


if __name__ == '__main__':
    main()

