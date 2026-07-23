#!/usr/bin/env python3
"""
marimba_section_poc.py — one consolidated marimba on stage (was 8 small
scattered instruments, one per pitch band).

Rather than splitting the full pitch range across 8 seats (which spread
attention thin and gave some seats only a handful of bars), every note is
now folded onto a fixed 49-bar rack spanning C4..C8 chromatically (4 octaves
x 12 pitch classes + one extra top C) — same layout as a 49-key keyboard.
Notes below C4 or above C8 fold onto the nearest edge octave by pitch class
(octave clamped to [4, 7]; a note that's exactly C8 gets the extra 49th bar,
anything else above C8 folds onto C7..B7). This is a many-to-one mapping —
many performed pitches can land on the same bar — not the old one-bar-per-
unique-pitch layout. Each of the 49 bars keeps its own mallet, exactly like
before, just consolidated onto one instrument instead of scattered across 8.

Window bumped from C2..C6 to C4..C8: checked against actual note
distributions (see pitch_bucket.py), octaves 2-3 were barely used while
octave 7 carried a real share of notes and was folding down onto octave 5.

Renders transparent frames (no title/background) meant to be composited
onto string_section_poc.py's frames by compose_stage_merge.py.

Usage:
  python marimba_section_poc.py --npy bwv261_features_array.npy \
      --tempo 122 --duration 74.5
"""
import argparse
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

import marimba_poc as mp
import stage_layout as stage
import pitch_bucket as pb
import stand
import finger_piano_section_poc as fp   # fp.AVAIL — shared stand leg-length reference

import logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%d %H:%M")
log = logging.getLogger(__name__)

FRAMES_DIR = "marimba8_frames"
FPS = 30

# One instrument, positioned/scaled where the old 8-seat back row used to
# sit. avail controls the rack's total on-stage width directly (bar width =
# avail/49); scale controls depth/mallet proportions (see marimba_poc.
# build_layout — the two are independent).
CX = 560
BASE_Y = stage.yup(stage.ROW_BACK_Y_FAR + 12)   # +12 clears the mallet stems at the top edge, as before
# 30% smaller than the initial 760/0.85 (that size encroached on the
# pizzicato strings/bass finger piano), then another 20% smaller — even
# after the first shrink, the stand's depth-offset back edge still
# overlapped the bass finger piano's stand to its right.
AVAIL = 532 * 0.8
SCALE = 0.6 * 0.8
PLAYER_Y_OFFSET = 150

LABEL_CLR = (0.34, 0.47, 0.60, 1.0)

# Stand (see stand.py): rail is a bit narrower than the bars (no overhang);
# front/back leg lengths are fractions of avail (the bar rack's own width).
STAND_GAP        = 3.0    # gap between a bar's underside and the front rail top
STAND_RAIL_H     = 5.0
STAND_RAIL_INSET_FRAC = 0.05   # rail is this much narrower than the bars (no overhang)


def build_bars():
    """The 49 fixed bars (C4..B7 chromatically, plus one extra C8), built
    via marimba_poc.build_layout so the oblique geometry/mallet-pivot math
    is identical to the old per-seat instruments — just fed a fixed
    representative pitch per bar instead of whatever pitches were observed."""
    reps = pb.representative_cents()
    fake_notes = np.zeros((len(reps), 5))
    fake_notes[:, 1] = reps

    base_x = CX - AVAIL / 2
    return mp.build_layout(
        fake_notes, base_x=base_x, base_y=BASE_Y, avail=AVAIL, scale=SCALE,
        player_x=CX, player_y=BASE_Y + PLAYER_Y_OFFSET * SCALE,
    )


def render(npy_file, tempo, duration):
    notes, _ = mp.load_features_array(npy_file, tempo, voice=5)
    notes[:, 1] = [pb.bucket_cents(p) for p in notes[:, 1]]

    bars, pitch_to_idx = build_bars()
    n_bars = len(bars)
    n_used = len(set(pitch_to_idx[int(round(p))] for p in notes[:, 1]))
    log.info(f"[marimba section] one instrument, {n_bars} bars (C4..C8), "
             f"{n_used} in use by this chorale")

    Path(FRAMES_DIR).mkdir(exist_ok=True)
    n_frames = int(np.ceil(duration * FPS))
    log.info(f"  {n_frames} frames ({duration:.1f}s @ {FPS}fps)")

    fig, ax = plt.subplots(figsize=(mp.W / mp.DPI, mp.H / mp.DPI), dpi=mp.DPI)
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    ax.set_xlim(0, mp.W)
    ax.set_ylim(0, mp.H)
    ax.set_aspect('equal')
    ax.axis('off')
    fig.patch.set_alpha(0.0)
    ax.patch.set_alpha(0.0)

    scene = mp.Scene(fig, ax, bars, show_title=False, show_labels=False)

    stand.add_stand(
        ax, CX, BASE_Y - STAND_GAP * SCALE,
        rail_w=AVAIL * (1.0 - STAND_RAIL_INSET_FRAC), rail_h=STAND_RAIL_H,
        scale=SCALE, leg_len_ref=fp.AVAIL,
    )

    # Matches Baritone Guitar's label height in bass_section_poc.py
    # (GUITAR_CY - BODY_H*GUITAR_SCALE*0.7 == 577.06) so the two line up.
    label_y = 577.06
    ax.text(CX, label_y, "Marimba", ha='center', va='top',
             fontsize=8, color=LABEL_CLR, zorder=10)

    for fi in range(n_frames):
        t = fi / FPS
        bar_glow, mallet_heads, mallet_visible = mp.compute_state(
            t, notes, pitch_to_idx, n_bars, bars)
        scene.update(bar_glow, mallet_heads, mallet_visible)
        fig.savefig(f"{FRAMES_DIR}/frame_{fi:06d}.png", dpi=mp.SAVE_DPI,
                    transparent=True)
        if fi % 200 == 0:
            log.info(f"  {fi}/{n_frames}  t={t:.1f}s")

    plt.close(fig)
    log.info(f"  Done — {n_frames} frames written.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--npy', required=True)
    parser.add_argument('--tempo', type=float, required=True)
    parser.add_argument('--duration', type=float, required=True)
    args = parser.parse_args()
    render(args.npy, args.tempo, args.duration)


if __name__ == '__main__':
    main()
