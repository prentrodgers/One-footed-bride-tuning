#!/usr/bin/env python3
"""
marimba_section_poc.py — 8 invisible marimba players on the same stage as
string_section_poc.py's 8 string players.

The 43 pitches played by voice 5 (finger_piano/marimba) in the features
array are split into 8 pitch bands; each band gets its own small on-stage
instrument (bars + mallet), positioned/scaled like a seat in the string
section — 4 "back row" seats (smaller/farther) and 4 "front row" seats
(larger/closer).

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

import logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%d %H:%M")
log = logging.getLogger(__name__)

FRAMES_DIR = "marimba8_frames"
FPS = 30

# Back row: smaller/farther, matches string section's cello/viola row height.
# Front row: larger/closer, matches string section's violin row height.
# Scaled 1.5x from the original 0.20/0.25 — same ROW_X0/ROW_DX below, so
# the instruments got bigger without spreading the seats apart (tighter).
BACK_SCALE, FRONT_SCALE = 0.36, 0.45   # +20% from 0.30/0.375 — bigger marimbas (seat spacing unchanged)
# Row elevations come from stage_layout (shared with bass/strings so the back
# row lines up across sections).  y-up data space here, so data-y = H - screen.
# The +20% scale-up above made the back-row mallets reach the top edge (their
# stems clipped at y=0), so nudge the whole marimba down 12 px to keep the
# mallets fully in frame.  Per-section offset (NOT via ROW_BACK_Y) so the bass
# and string sections keep their requested elevations unchanged.
MARIMBA_Y_NUDGE = 12   # px down, to clear the top edge after the +20% scale-up
BACK_BASE_Y  = stage.yup(stage.ROW_BACK_Y_FAR  + MARIMBA_Y_NUDGE)   # back row
FRONT_BASE_Y = stage.yup(stage.ROW_BACK_Y_NEAR + MARIMBA_Y_NUDGE)   # front row
# Seat spacing widened (ROW_DX 62→118) and the whole section shifted left
# (ROW_X0 547/572→343/384) so the denser voicings from the longer chorale
# render (many more marimba notes → up to 9 bars/seat) no longer overlap.
# MAX_SEAT_AVAIL caps each seat's bar-rack width so seats never overlap no
# matter how many notes land in one seat — extra bars just get thinner.
MAX_SEAT_AVAIL = 108   # px cap on per-seat rack width (front-row 9 bars ≈ 104.5)
ROW_X0 = dict(back=343, front=384)
ROW_DX = 118

# Target bar count per seat — how many unique pitches land in one seat's
# instrument.  Splitting the full pitch range into 8 equal-count bands
# (the old approach) gave only 5-6 bars per seat.  Instead we assign each
# seat one equal-width cents slice of the full range so that as the piece
# uses more distinct pitches, each seat automatically gets more bars.
# When the data is sparse (few unique pitches), seats may still end up with
# 5-6 bars; with denser voicings they can reach 10-15.
BARS_PER_SEAT_TARGET = 10   # used only to compute cents-slice width

SEAT_LABEL_CLR = (0.34, 0.47, 0.60, 1.0)


def build_players(notes):
    pitch_vals = np.sort(np.unique(np.round(notes[:, 1]).astype(int)))

    # Equal-COUNT bands (not equal-cents-width): pitch density is uneven
    # across the range, so an equal-width cents split left the lowest seat
    # with ~5 bars while others got 50-60 (one seat's slice just happened to
    # span a sparse stretch of the melody).  Splitting by pitch count instead
    # gives every seat roughly the same number of bars, and still scales up
    # naturally as a denser chorale uses more distinct pitches overall — same
    # approach as finger_piano_section_poc.py / bass_section_poc.py.
    n_seats = 8
    bands = np.array_split(pitch_vals, n_seats)
    edges = [None] + [int(b[0]) for b in bands[1:]] + [None]

    players = []
    for i in range(n_seats):
        is_back = i < 4
        row_i = i if is_back else i - 4
        scale = BACK_SCALE if is_back else FRONT_SCALE
        base_y = BACK_BASE_Y if is_back else FRONT_BASE_Y
        cx = ROW_X0['back' if is_back else 'front'] + row_i * ROW_DX
        players.append(dict(
            id=i, name=f"Mb.{i + 1}", p_lo=edges[i], p_hi=edges[i + 1],
            cx=cx, base_y=base_y, scale=scale, max_avail=MAX_SEAT_AVAIL,
            player_x=cx, player_y=base_y + 150 * scale,
        ))
    return players


def render(npy_file, tempo, duration):
    notes, _ = mp.load_features_array(npy_file, tempo, voice=5)
    players = build_players(notes)
    bars, pitch_to_idx = mp.build_multi_layout(notes, players)
    n_bars = len(bars)
    log.info(f"[marimba section] {n_bars} bars across {len(players)} seats")
    for pl in players:
        n = sum(1 for b in bars if b['seat_name'] == pl['name'])
        log.info(f"  {pl['name']}: {n} bars @ (cx={pl['cx']}, base_y={pl['base_y']}, scale={pl['scale']})")

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

    for pl in players:
        # y-up data space: subtract to place the label below the bar rack.
        label_y = pl['base_y'] - 10 * pl['scale']
        ax.text(pl['cx'], label_y, pl['name'], ha='center', va='top',
                 fontsize=8, color=SEAT_LABEL_CLR, zorder=10)

    for fi in range(n_frames):
        t = fi / FPS
        bar_glow, mallet_heads, mallet_visible = mp.compute_state(
            t, notes, pitch_to_idx, n_bars, bars)
        scene.update(bar_glow, mallet_heads, mallet_visible)
        fig.savefig(f"{FRAMES_DIR}/frame_{fi:06d}.png", dpi=mp.DPI,
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
