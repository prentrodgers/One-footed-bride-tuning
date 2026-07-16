#!/usr/bin/env python3
"""
bass_section_poc.py — bass finger piano (4 tine seats) + baritone guitar
(4 instruments) on the same stage as string_section_poc.py,
marimba_section_poc.py, and finger_piano_section_poc.py.

WreckingCrew.py's "bass_section" (see include_sections in WreckingCrew.py,
around line 2395) combines baritone guitar (csound_voice 20) and bass
finger piano (csound_voice 24) — the latter shares its csound_voice with
regular finger piano's low register, so voice 24 belongs to *either*
finger_pianos or bass_section depending on which named sub-voice
(bfin1/2 vs bfin3/4/5) generated it; since that identity isn't preserved
per-note, voice 24 is assigned entirely to bass_section here and excluded
from finger_piano_section_poc.py, avoiding double-counting the same notes
in two sections.

Bass finger piano reuses finger_piano_section_poc.py's tine/vibration
geometry (mechanically the same thing, just lower/heavier), with 4 seats
(2 back + 2 front) rather than 8. Baritone guitar is a separate instrument
entirely — 4 large 6-string guitars (not tines), body/neck running
horizontally, plucked strings vibrating as a standing wave (see
GuitarScene) rather than the tine's cantilever motion.

Usage:
  python bass_section_poc.py --npy bwv261_features_array.npy \
      --tempo 92 --duration 21.2
"""
import argparse
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Circle, Ellipse

import marimba_poc as mp
import finger_piano_section_poc as fp

FRAMES_DIR = "bass8_frames"
FPS = 30
TINE_VOICES = (24,)     # bass finger piano only — bgui (20) is the guitar below
GUITAR_VOICE = 20

# Positioned right of the marimba/finger-piano column ("to the right as
# they are now" — x unchanged), but at the SAME row heights as the
# marimba (not finger-piano's lower band anymore) so the two sections read
# as one wide top row. Values below are copied exactly from
# marimba_section_poc.py's BACK_BASE_Y/FRONT_BASE_Y (430/358 + the same
# H//3 up-shift) for precise alignment.
# Scaled 1.5x from the original 0.18/0.23 — same ROW_X0/ROW_DX below, so
# the instruments got bigger without spreading the seats apart (tighter).
# Only 4 seats now (2 back + 2 front), not 8 — WreckingCrew.py's
# include_sections (line ~2395) lists the bass_section instrument roster;
# the bass-finger-piano sub-voices there (bfin3/bfin4/bfin5/bfin6) are the
# ones that belong here, matched 1:1 with 4 seats.
BASS_Y_SHIFT = mp.H // 3
BACK_SCALE, FRONT_SCALE = 0.345, 0.27   # back row larger (longer tines), matches finger-piano
BACK_NODE_Y, FRONT_NODE_Y = 430 + BASS_Y_SHIFT, 358 + BASS_Y_SHIFT   # = marimba's rows
ROW_X0 = dict(back=700, front=725)
ROW_DX = 62
N_TINE_SEATS = 4

BASE_SLOT_W = 26.0
MAX_TINE_LEN, MIN_TINE_LEN = 105.0, 82.0
# Bass tines are heavier/wider spring steel than the regular finger piano —
# model them noticeably wider (wider half-strip) to look like bass instruments.
TINE_WIDTH_LOW, TINE_WIDTH_HIGH = 12.0, 8.0   # px at scale=1.0, filled-polygon width

SEAT_LABEL_CLR = (0.55, 0.30, 0.32, 1.0)

# ── Baritone guitars (csound_voice 20) ──────────────────────────────────────
# Four instruments (matching the bass_section instrument count in
# WreckingCrew.py's include_sections), not one. Each is still a full
# 6-string guitar (real baritone guitars have 6 strings) over its own
# slice of the voice-20 pitch range. Body/neck run left-to-right (strings
# horizontal) unlike every other instrument on this stage, which all have
# vertical strings/bars — deliberately distinct. Plucked strings vibrate
# as a standing wave (fixed at nut AND bridge, unlike the finger-piano's
# fixed-at-one-end tines) — same math as string_section_poc.py's
# pizzicato strings, transposed 90 degrees.
N_STRINGS = 6
N_GUITARS = 4
# Shrunk to roughly the same on-stage footprint as the 4 bass-finger-piano
# tine seats, and positioned just to their right at the SAME two row
# heights (GUITAR_ROW_DY = BACK_NODE_Y - FRONT_NODE_Y exactly, so the two
# guitar rows land precisely on the marimba/bass-tine row heights).
GUITAR_SCALE = 0.30
GUITAR_REGION_X0 = 830
GUITAR_REGION_CY = (BACK_NODE_Y + FRONT_NODE_Y) / 2
GUITAR_COL_DX = 98
GUITAR_ROW_DY = BACK_NODE_Y - FRONT_NODE_Y
# at scale=1.0 (the original single-guitar size); each instance below
# multiplies these by GUITAR_SCALE
HEAD_LEN, HEAD_H = 22, 30
NECK_LEN, NECK_H = 150, 20
BODY_W, BODY_H   = 120, 92
STRING_SPACING = 13
PLUCK_X_FRAC = 0.80      # fraction along nut->bridge where the pick hits

GUITAR_WOOD = (0.42, 0.20, 0.14)     # deep sunburst red-brown
GUITAR_WOOD_DK = (0.24, 0.11, 0.08)
STRING_CLRS = [
    (0.62, 0.60, 0.55), (0.66, 0.63, 0.56), (0.72, 0.68, 0.58),
    (0.78, 0.72, 0.55), (0.82, 0.78, 0.60), (0.86, 0.84, 0.70),
]

GTR_VIB_FREQ = 7.0
GTR_TAU = 0.30
GTR_GLOW_DECAY = 0.22
GTR_PLK_APP_T = 0.055
GTR_PLK_DWL_T = 0.025
GTR_PLK_RET_T = 0.140
GTR_PLK_RAD = 6.5


def bass_color(i, n):
    """Deep red (low) -> indigo (high) — distinct from the amber/cyan
    finger-piano and marimba palettes."""
    t = i / max(n - 1, 1)
    return (0.55 - t * 0.30, 0.14 + t * 0.08, 0.16 + t * 0.42)


def load_bass_voices(npy_file, tempo, voices):
    print(f"\n[Stage 1] Loading bass voices {voices} from {npy_file}")
    arr = np.load(npy_file)
    mask = (arr[:, 5] > 0) & (arr[:, 2] > 0) & (arr[:, 14] > 0) & (arr[:, 3] > 0)
    mask &= np.isin(arr[:, 6].astype(int), voices)
    arr = arr[mask]
    if not len(arr):
        raise ValueError(f"No audible notes for voices {voices}")

    bps = tempo / 60.0
    start_s    = arr[:, 1] / bps
    duration_s = arr[:, 2] / bps
    pitch_cents = arr[:, 5] * 1200.0 + arr[:, 4]
    notes = np.column_stack([start_s, pitch_cents, duration_s, arr[:, 3], arr[:, 14]])
    notes = notes[notes[:, 0].argsort()]
    n_unique = len(np.unique(np.round(pitch_cents).astype(int)))
    print(f"  {len(notes)} events, {n_unique} unique pitches, "
          f"pitch range {pitch_cents.min():.0f}-{pitch_cents.max():.0f} cents")
    return notes


def build_seats():
    seats = []
    for i in range(N_TINE_SEATS):
        is_back = i < N_TINE_SEATS // 2
        row_i = i if is_back else i - N_TINE_SEATS // 2
        scale = BACK_SCALE if is_back else FRONT_SCALE
        node_y = BACK_NODE_Y if is_back else FRONT_NODE_Y
        cx = ROW_X0['back' if is_back else 'front'] + row_i * ROW_DX
        seats.append(dict(id=i, name=f"Bs.{i + 1}", cx=cx, node_y=node_y, scale=scale))
    return seats


# ── Baritone guitar geometry/state/scene ─────────────────────────────────────

def build_guitar_grid_positions():
    """Anchor (x0, cy) for each of the N_GUITARS instances, packed into a
    2x2 grid roughly the same footprint the original single large guitar
    occupied. Reading order = ascending pitch: bottom-left -> bottom-right
    -> top-left -> top-right (matches the low-left/high-right convention
    used elsewhere on this stage)."""
    positions = []
    for i in range(N_GUITARS):
        col = i % 2
        row = i // 2
        x0 = GUITAR_REGION_X0 + col * GUITAR_COL_DX
        cy = GUITAR_REGION_CY + (row - 0.5) * GUITAR_ROW_DY
        positions.append((x0, cy))
    return positions


def build_guitar_strings(notes, x0, cy, scale):
    """6 strings spanning the nut->bridge length; each note is assigned to
    a string by dividing its pitch range into 6 equal parts."""
    head_len = HEAD_LEN * scale
    neck_len = NECK_LEN * scale
    body_w   = BODY_W * scale
    spacing  = STRING_SPACING * scale
    total_len = head_len + neck_len + body_w
    x_nut = x0 + head_len
    x_bridge = x0 + total_len
    pluck_x = x_nut + (x_bridge - x_nut) * PLUCK_X_FRAC

    y0 = cy - spacing * (N_STRINGS - 1) / 2.0
    strings = []
    for i in range(N_STRINGS):
        strings.append(dict(
            idx=i, y=y0 + i * spacing,
            x_nut=x_nut, x_bridge=x_bridge, pluck_x=pluck_x,
            color=STRING_CLRS[i], scale=scale,
        ))

    pitch_min, pitch_max = notes[:, 1].min(), notes[:, 1].max()
    edges = np.linspace(pitch_min, pitch_max, N_STRINGS + 1)
    return strings, edges


def pitch_to_string_idx(pitch_cents, edges):
    idx = np.searchsorted(edges[1:-1], pitch_cents, side='right')
    return int(np.clip(idx, 0, N_STRINGS - 1))


def build_guitars(notes):
    """Split voice-20 notes into N_GUITARS pitch bands (low->high) and
    build a positioned 6-string instance for each, packed into the same
    on-stage footprint the original single guitar used."""
    pitch_vals = np.sort(np.unique(np.round(notes[:, 1]).astype(int)))
    bands = np.array_split(pitch_vals, N_GUITARS)
    edges_g = [None] + [int(b[0]) for b in bands[1:]] + [None]
    positions = build_guitar_grid_positions()

    guitars = []
    for i in range(N_GUITARS):
        lo, hi = edges_g[i], edges_g[i + 1]
        mask = np.ones(len(notes), dtype=bool)
        if lo is not None:
            mask &= notes[:, 1] >= lo
        if hi is not None:
            mask &= notes[:, 1] < hi
        sub = notes[mask]
        if not len(sub):
            continue
        x0, cy = positions[i]
        strings, str_edges = build_guitar_strings(sub, x0, cy, GUITAR_SCALE)
        guitars.append(dict(
            name=f"Gtr.{i + 1}", notes=sub, strings=strings, edges=str_edges,
            x0=x0, cy=cy, scale=GUITAR_SCALE,
        ))
    return guitars


def compute_guitar_state(t, notes, edges):
    """Per-string glow, vibration amplitude/onset, and pluck-gesture onset —
    same shape of computation as string_section_poc.py's compute_state."""
    glow      = np.zeros(N_STRINGS)
    vib_amp   = np.zeros(N_STRINGS)
    vib_onset = np.full(N_STRINGS, -999.0)
    last_gest = {}

    total_gest = GTR_PLK_APP_T + GTR_PLK_DWL_T + GTR_PLK_RET_T
    for row in notes:
        onset_t, pitch, dur_s = row[0], row[1], row[2]
        si = pitch_to_string_idx(pitch, edges)
        dt = t - onset_t

        if 0.0 <= dt <= GTR_GLOW_DECAY:
            glow[si] = max(glow[si], 1.0 - dt / GTR_GLOW_DECAY)

        if dt > 0.0:
            amp = float(np.exp(-dt / GTR_TAU))
            if dt > dur_s:
                amp *= max(0.0, 1.0 - (dt - dur_s) / 0.18)
            if amp > vib_amp[si]:
                vib_amp[si] = amp
                vib_onset[si] = onset_t

        if -GTR_PLK_APP_T <= dt <= total_gest:
            if si not in last_gest or onset_t > last_gest[si]:
                last_gest[si] = onset_t

    return glow, vib_amp, vib_onset, last_gest


class GuitarScene:
    def __init__(self, ax, strings, x0, cy, scale):
        self.ax = ax
        self.strings = strings

        head_len, head_h = HEAD_LEN * scale, HEAD_H * scale
        neck_len, neck_h = NECK_LEN * scale, NECK_H * scale
        bw, bh = BODY_W * scale, BODY_H * scale

        # Body — simplified offset-double-cutaway silhouette, wide end
        # toward the bridge (right).
        bx = x0 + head_len + neck_len
        body = Ellipse((bx + bw * 0.55, cy), width=bw * 1.15, height=bh,
                       fc=GUITAR_WOOD, ec=GUITAR_WOOD_DK, lw=1.2, zorder=3)
        ax.add_patch(body)
        cutaway = Ellipse((bx + bw * 0.18, cy - bh * 0.30), width=bw * 0.5, height=bh * 0.5,
                          fc=(0.06, 0.07, 0.09), ec='none', zorder=4)
        ax.add_patch(cutaway)

        # Neck + headstock
        neck = Rectangle((x0 + head_len, cy - neck_h / 2), neck_len, neck_h,
                          fc=GUITAR_WOOD, ec=GUITAR_WOOD_DK, lw=1.0, zorder=3)
        ax.add_patch(neck)
        head = Rectangle((x0, cy - head_h / 2), head_len, head_h,
                          fc=GUITAR_WOOD_DK, ec=GUITAR_WOOD_DK, lw=1.0, zorder=3)
        ax.add_patch(head)

        # Pickups (bridge area detail)
        for pu_x in (bx + bw * 0.42, bx + bw * 0.62):
            ax.add_patch(Rectangle((pu_x, cy - bh * 0.28), bw * 0.10, bh * 0.56,
                                    fc=(0.08, 0.08, 0.09), ec=(0.35, 0.35, 0.38),
                                    lw=0.6, zorder=5))

        self._strings = []
        self._halos = []
        self._fingers = []
        for s in strings:
            (line,) = ax.plot([s['x_nut'], s['x_bridge']], [s['y'], s['y']],
                               color=s['color'], lw=2.0 * scale, solid_capstyle='round', zorder=6)
            self._strings.append(line)

            halo = Ellipse((s['pluck_x'], s['y']), width=26 * scale, height=10 * scale,
                           fc=s['color'], alpha=0.0, zorder=7)
            ax.add_patch(halo)
            self._halos.append(halo)

            finger = Circle((s['pluck_x'], s['y']), radius=GTR_PLK_RAD * scale,
                             fc=(0.85, 0.78, 0.68), ec='none', alpha=0.0, zorder=9)
            ax.add_patch(finger)
            self._fingers.append(finger)

    def update(self, t, glow, vib_amp, vib_onset, last_gest):
        n_pts = 30
        for i, s in enumerate(self.strings):
            sc = s['scale']
            g, a, onset = glow[i], vib_amp[i], vib_onset[i]
            xs = np.linspace(s['x_nut'], s['x_bridge'], n_pts)
            L = s['x_bridge'] - s['x_nut']

            if a > 0.005:
                dt = t - onset
                ph = 2.0 * np.pi * GTR_VIB_FREQ * dt
                # Standing wave: zero displacement at nut AND bridge (both
                # ends fixed), same shape as string_section_poc's strings.
                ys = s['y'] + a * 10.0 * sc * np.sin(np.pi * (xs - s['x_nut']) / L) * np.cos(ph)
            else:
                ys = np.full(n_pts, s['y'])
            self._strings[i].set_data(xs, ys)

            lw = (2.0 + g * 2.2) * sc
            self._strings[i].set_linewidth(lw)
            if g > 0.06:
                bright = tuple(min(1.0, c + g * 0.5) for c in s['color'])
                self._strings[i].set_color(bright)
            else:
                self._strings[i].set_color(s['color'])
            self._halos[i].set_alpha(g * 0.35 if g > 0.05 else 0.0)

            gest_onset = last_gest.get(i)
            if gest_onset is None:
                self._fingers[i].set_alpha(0.0)
                continue
            dt = t - gest_onset
            total = GTR_PLK_APP_T + GTR_PLK_DWL_T + GTR_PLK_RET_T
            if -GTR_PLK_APP_T <= dt <= total:
                # Pick approaches from below the string, touches, retracts.
                if dt < 0:
                    ph = ((dt + GTR_PLK_APP_T) / GTR_PLK_APP_T) ** 1.5
                    off = 16.0 * sc * (1.0 - ph)
                    alpha = ph
                elif dt < GTR_PLK_DWL_T:
                    off = 0.0
                    alpha = 1.0
                else:
                    ph = min(1.0, (dt - GTR_PLK_DWL_T) / GTR_PLK_RET_T) ** 0.7
                    off = 16.0 * sc * ph
                    alpha = max(0.0, 1.0 - ph)
                self._fingers[i].center = (s['pluck_x'], s['y'] - off)
                self._fingers[i].set_alpha(alpha)
            else:
                self._fingers[i].set_alpha(0.0)


def render(npy_file, tempo, duration):
    tine_notes = load_bass_voices(npy_file, tempo, TINE_VOICES)
    seats = build_seats()
    tines, pitch_to_idx = fp.build_tine_layout(
        tine_notes, seats, base_slot_w=BASE_SLOT_W,
        len_range=(MAX_TINE_LEN, MIN_TINE_LEN),
        width_range=(TINE_WIDTH_LOW, TINE_WIDTH_HIGH),
        color_fn=bass_color,
    )
    n_tines = len(tines)
    print(f"[bass section] {n_tines} tines across {len(seats)} seats")
    for seat in seats:
        n = sum(1 for tn in tines if tn['seat_name'] == seat['name'])
        print(f"  {seat['name']}: {n} tines @ (cx={seat['cx']}, node_y={seat['node_y']}, scale={seat['scale']})")

    guitar_notes = load_bass_voices(npy_file, tempo, (GUITAR_VOICE,))
    guitars = build_guitars(guitar_notes)
    print(f"[baritone guitars] {len(guitars)} instruments x {N_STRINGS} strings each")
    for gt in guitars:
        print(f"  {gt['name']}: {len(gt['notes'])} notes @ (x0={gt['x0']:.0f}, "
              f"cy={gt['cy']:.0f}, scale={gt['scale']}), edges="
              f"{', '.join(f'{e:.0f}' for e in gt['edges'])}")

    Path(FRAMES_DIR).mkdir(exist_ok=True)
    n_frames = int(np.ceil(duration * FPS))
    print(f"  {n_frames} frames ({duration:.1f}s @ {FPS}fps)")

    fig, ax = plt.subplots(figsize=(mp.W / mp.DPI, mp.H / mp.DPI), dpi=mp.DPI)
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    ax.set_xlim(0, mp.W)
    ax.set_ylim(0, mp.H)
    ax.set_aspect('equal')
    ax.axis('off')
    fig.patch.set_alpha(0.0)
    ax.patch.set_alpha(0.0)

    tine_scene = fp.TineScene(ax, tines)
    guitar_scenes = [GuitarScene(ax, gt['strings'], gt['x0'], gt['cy'], gt['scale'])
                      for gt in guitars]

    for seat in seats:
        # Node is now the downstage (lowest-image-row) point since tines
        # point backward/upstage from it — label goes just below the node.
        label_y = seat['node_y'] - 6 * seat['scale']
        ax.text(seat['cx'], label_y, seat['name'], ha='center', va='top',
                 fontsize=7, color=SEAT_LABEL_CLR, zorder=10)
    for gt in guitars:
        total_len = (HEAD_LEN + NECK_LEN + BODY_W) * gt['scale']
        label_y = gt['cy'] - BODY_H * gt['scale'] * 0.7
        ax.text(gt['x0'] + total_len / 2, label_y, gt['name'],
                 ha='center', va='top', fontsize=6.5,
                 color=SEAT_LABEL_CLR, zorder=10)

    for fi in range(n_frames):
        t = fi / FPS
        glow, vib_amp, vib_onset, last_gest = fp.compute_state(t, tine_notes, pitch_to_idx, n_tines)
        tine_scene.update(t, glow, vib_amp, vib_onset, last_gest)
        for gt, gscene in zip(guitars, guitar_scenes):
            g_glow, g_vib_amp, g_vib_onset, g_last_gest = compute_guitar_state(t, gt['notes'], gt['edges'])
            gscene.update(t, g_glow, g_vib_amp, g_vib_onset, g_last_gest)
        fig.savefig(f"{FRAMES_DIR}/frame_{fi:06d}.png", dpi=mp.DPI, transparent=True)
        if fi % 200 == 0:
            print(f"  {fi}/{n_frames}  t={t:.1f}s", flush=True)

    plt.close(fig)
    print(f"  Done — {n_frames} frames written.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--npy', required=True)
    parser.add_argument('--tempo', type=float, required=True)
    parser.add_argument('--duration', type=float, required=True)
    args = parser.parse_args()
    render(args.npy, args.tempo, args.duration)


if __name__ == '__main__':
    main()
