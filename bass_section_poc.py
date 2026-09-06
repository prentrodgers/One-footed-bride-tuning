#!/usr/bin/env python3
"""
bass_section_poc.py — one consolidated bass finger piano + one consolidated
baritone guitar (was 4 tine seats + 4 guitars), on the same stage as
string_section_poc.py, marimba_section_poc.py, and
finger_piano_section_poc.py.

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
geometry (mechanically the same thing, just lower/heavier) and the same
consolidated "one instrument, 49 fixed positions" pattern as marimba/finger
piano — but with its own, lower register window (see pitch_bucket.py):
bass notes skew well below C4, so reusing marimba's C4..C8 window would
bunch almost everything onto the bottom few positions.

Baritone guitar is a separate instrument entirely — a large 6-string
guitar (not tines), body/neck running horizontally, plucked strings
vibrating as a standing wave (see GuitarScene) rather than the tine's
cantilever motion. Its 6 strings already span the full observed pitch
range via band-splitting (see build_guitar_strings) rather than a fixed
bucket scheme, so consolidating it to one instrument is just a matter of
not splitting its notes across 4 separate instances any more.

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
from matplotlib.patches import Rectangle, Circle, Ellipse, Polygon as MplPolygon

import marimba_poc as mp
import finger_piano_section_poc as fp
import marimba_section_poc as ms   # ms.BASE_Y — keeps the bass stand level-matched to the marimba's
import stage_layout as stage
import pitch_bucket as pb
import stand
import string_length as sl

import logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%d %H:%M")
log = logging.getLogger(__name__)

FRAMES_DIR = "bass8_frames"
FPS = 30
TINE_VOICES = (24,)     # bass finger piano only — bgui (20) is the guitar below
GUITAR_VOICE = 20

# Bass notes run much lower than marimba/finger piano, so its 49-position
# window (C1..C5) stays independent of marimba/finger piano's C4..C8 —
# otherwise most notes would fold below the window and bunch onto its
# bottom few positions.
TINE_BOTTOM_OCTAVE = 1

# One consolidated instrument each, positioned side by side within the same
# overall footprint (roughly x:808-1226, y:573-645) the old 4 tine seats +
# 4 guitars used to occupy. Shrunk 20% from the initial 0.42/190 — at that
# size the stands' depth-offset back edges overlapped the marimba to the
# left and the guitar to the right.
TINE_CX = 905
TINE_NODE_Y = ms.BASE_Y   # matches the marimba's stand level (was a lower, separate 609)
TINE_SCALE = 0.42 * 0.8
TINE_AVAIL = 190 * 0.8

BASE_SLOT_W = 26.0
# 30% shorter than the initial 105.0/82.0 — sized down along with everything
# else in this section.
MAX_TINE_LEN, MIN_TINE_LEN = 105.0 * 0.7, 82.0 * 0.7
# Bass tines are heavier/wider spring steel than the regular finger piano —
# model them noticeably wider (wider half-strip) to look like bass instruments.
TINE_WIDTH_LOW, TINE_WIDTH_HIGH = 12.0, 8.0   # px at scale=1.0, filled-polygon width

LABEL_CLR = (0.55, 0.30, 0.32, 1.0)

# ── Baritone guitar (csound_voice 20) ───────────────────────────────────────
# One instrument now (was 4, each a slice of the pitch range) — its 6
# strings cover the full observed pitch range via real string tuning (see
# GUITAR_OPEN_CENTS) rather than a pitch-range slice, so one instance covers
# everything. Body/neck run left-to-right (strings horizontal) unlike every
# other instrument on this stage. Plucked strings vibrate as a standing
# wave (fixed at nut AND bridge, unlike the finger-piano's fixed-at-one-end
# tines) — same math as string_section_poc.py's pizzicato strings,
# transposed 90 degrees.
N_STRINGS = 6
GUITAR_SCALE = 0.62 * 0.8 * 1.5   # one big instrument now (was 0.30 x4 in a 2x2 grid), shrunk 20% to clear the bass finger piano beside it, then bumped 50% bigger
GUITAR_X0 = 1015      # nut/head position (left edge)
GUITAR_CY = 609       # kept independent of TINE_NODE_Y — the guitar didn't need to move

# Baritone guitar standard tuning, low to high string (cents; C4=4800 per
# marimba_poc._pitch_label, so e.g. B1 = (1*12+11)*100 = 2300).
# B1  E2  A2  D3  F#3  B3 — a perfect fourth below standard EADGBE.
GUITAR_OPEN_CENTS = [2300, 2800, 3300, 3800, 4200, 4700]
GUITAR_OPEN_SLACK = 50       # cents a note may sit below an open pitch and still be that open string


def _note_to_guitar_string(pitch_cents):
    """Which of the 6 strings (0=lowest) a guitarist would use for this
    pitch — the HIGHEST string whose open pitch is at or below the note, so
    the stop lands as near the nut as possible (same rule as
    string_section_poc.py's _note_to_str)."""
    for i in range(len(GUITAR_OPEN_CENTS) - 1, -1, -1):
        if pitch_cents >= GUITAR_OPEN_CENTS[i] - GUITAR_OPEN_SLACK:
            return i
    return 0
# at scale=1.0 (the original single-guitar size); multiplied by GUITAR_SCALE
HEAD_LEN, HEAD_H = 22, 30
NECK_LEN, NECK_H = 150, 20
BODY_W, BODY_H   = 120, 92
STRING_SPACING = 9      # px between strings at scale=1.0
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
GTR_PLK_RAD = 2.0   # "radius" (overall scale) of the pick shape — smaller
                     # than the fretboard stop dot (GTR_STOP_DOT_RAD)
GTR_STOP_DOT_RAD = 2.6
GTR_STOP_DOT_CLR = (0.85, 0.65, 0.25)    # warm amber — fretting hand
GTR_PICK_CLR     = (0.85, 0.90, 0.97)    # pale/cool — plectrum, distinct from the stop dot

# Guitar pick outline (unit shape, tip pointing +y toward the string) —
# scaled by GTR_PLK_RAD * scale and translated to the current position.
GTR_PICK_PTS = np.array([
    [ 0.00,  1.00], [ 0.42,  0.55], [ 0.62,  0.05], [ 0.55, -0.45],
    [ 0.28, -0.85], [ 0.00, -1.00], [-0.28, -0.85], [-0.55, -0.45],
    [-0.62,  0.05], [-0.42,  0.55],
])


def _pick_points(cx, cy, r):
    return GTR_PICK_PTS * r + np.array([cx, cy])


def bass_color(i, n):
    """Deep red (low) -> indigo (high) — distinct from the amber/cyan
    finger-piano and marimba palettes."""
    t = i / max(n - 1, 1)
    return (0.55 - t * 0.30, 0.14 + t * 0.08, 0.16 + t * 0.42)


def load_bass_voices(npy_file, tempo, voices):
    log.info(f"\n[Stage 1] Loading bass voices {voices} from {npy_file}")
    arr = np.load(npy_file)
    mask = (arr[:, 5] > 0) & (arr[:, 2] > 0) & (arr[:, 14] > 0) & (arr[:, 3] > 0)
    mask &= np.isin(arr[:, 6].astype(int), voices)
    arr = arr[mask]
    if not len(arr):
        log.warning(f"  no notes found for voices {voices} — that part of the bass section will be empty")
        return np.zeros((0, 5))

    bps = tempo / 60.0
    start_s    = arr[:, 1] / bps
    duration_s = arr[:, 2] / bps
    pitch_cents = arr[:, 5] * 1200.0 + arr[:, 4]
    notes = np.column_stack([start_s, pitch_cents, duration_s, arr[:, 3], arr[:, 14]])
    notes = notes[notes[:, 0].argsort()]
    n_unique = len(np.unique(np.round(pitch_cents).astype(int)))
    log.info(f"  {len(notes)} events, {n_unique} unique pitches, "
             f"pitch range {pitch_cents.min():.0f}-{pitch_cents.max():.0f} cents")
    return notes


def build_seat():
    return [dict(id=0, name="Bass Finger Piano", cx=TINE_CX, node_y=TINE_NODE_Y, scale=TINE_SCALE)]


# ── Baritone guitar geometry/state/scene ─────────────────────────────────────

def build_guitar_strings(x0, cy, scale):
    """6 strings spanning the nut->bridge length, tuned per GUITAR_OPEN_CENTS
    (each note is assigned to a string by _note_to_guitar_string)."""
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
            color=STRING_CLRS[i], scale=scale, open_cents=GUITAR_OPEN_CENTS[i],
        ))
    return strings


def compute_guitar_state(t, notes):
    """Per-string glow, vibration amplitude/onset, currently-sounding pitch,
    and pluck-gesture onset — same shape of computation as
    string_section_poc.py's compute_state."""
    glow      = np.zeros(N_STRINGS)
    vib_amp   = np.zeros(N_STRINGS)
    vib_onset = np.full(N_STRINGS, -999.0)
    vib_pitch = np.full(N_STRINGS, np.nan)
    last_gest = {}

    total_gest = GTR_PLK_APP_T + GTR_PLK_DWL_T + GTR_PLK_RET_T
    for row in notes:
        onset_t, pitch, dur_s = row[0], row[1], row[2]
        si = _note_to_guitar_string(pitch)
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
                vib_pitch[si] = pitch

        if -GTR_PLK_APP_T <= dt <= total_gest:
            if si not in last_gest or onset_t > last_gest[si]:
                last_gest[si] = onset_t

    return glow, vib_amp, vib_onset, vib_pitch, last_gest


class GuitarScene:
    def __init__(self, ax, strings, x0, cy, scale):
        self.ax = ax
        self.strings = strings

        head_len, head_h = HEAD_LEN * scale, HEAD_H * scale
        neck_len, neck_h = NECK_LEN * scale, NECK_H * scale
        bw, bh = BODY_W * scale, BODY_H * scale

        # Body — simplified offset-double-cutaway silhouette, wide end
        # toward the bridge (right). Bumped 10% bigger than its footprint
        # (bw/bh, which still positions the pickups/pegs/bridge) so the
        # cutaway accent scales up with it.
        body_bump = 1.1
        bx = x0 + head_len + neck_len
        body = Ellipse((bx + bw * 0.55, cy), width=bw * 1.15 * body_bump, height=bh * body_bump,
                       fc=GUITAR_WOOD, ec=GUITAR_WOOD_DK, lw=1.2, zorder=3)
        ax.add_patch(body)
        cutaway = Ellipse((bx + bw * 0.18, cy - bh * 0.30), width=bw * 0.5 * body_bump, height=bh * 0.5 * body_bump,
                          fc=(0.06, 0.07, 0.09), ec='none', zorder=4)
        ax.add_patch(cutaway)

        # Neck + headstock
        neck = Rectangle((x0 + head_len, cy - neck_h / 2), neck_len, neck_h,
                          fc=GUITAR_WOOD, ec=GUITAR_WOOD_DK, lw=1.0, zorder=3)
        ax.add_patch(neck)
        head = Rectangle((x0, cy - head_h / 2), head_len, head_h,
                          fc=GUITAR_WOOD_DK, ec=GUITAR_WOOD_DK, lw=1.0, zorder=3)
        ax.add_patch(head)

        # Pickups
        for pu_x in (bx + bw * 0.42, bx + bw * 0.62):
            ax.add_patch(Rectangle((pu_x, cy - bh * 0.28), bw * 0.10, bh * 0.56,
                                    fc=(0.08, 0.08, 0.09), ec=(0.35, 0.35, 0.38),
                                    lw=0.6, zorder=5))

        # Tuning pegs — small knobs at the headstock's left (far) edge, one
        # per string.
        y_lo, y_hi = strings[0]['y'], strings[-1]['y']
        peg_r = 3.0 * scale
        for s in strings:
            ax.add_patch(Circle((x0 - peg_r * 0.8, s['y']), radius=peg_r,
                                 fc=(0.75, 0.75, 0.78), ec=GUITAR_WOOD_DK,
                                 lw=0.5, zorder=4))

        # Bridge — raised bar where the strings terminate at the body,
        # spanning the full string width.
        bridge_w = 5.0 * scale
        bridge_pad = 8.0 * scale
        x_bridge = strings[0]['x_bridge']
        bridge = Rectangle((x_bridge - bridge_w / 2, y_lo - bridge_pad),
                            bridge_w, (y_hi - y_lo) + 2 * bridge_pad,
                            fc=GUITAR_WOOD_DK, ec=(0.05, 0.03, 0.02),
                            lw=0.6, zorder=6)
        ax.add_patch(bridge)

        self._strings = []
        self._halos = []
        self._fingers = []
        self._stop_dots = []
        for s in strings:
            (line,) = ax.plot([s['x_nut'], s['x_bridge']], [s['y'], s['y']],
                               color=s['color'], lw=2.0 * scale, solid_capstyle='round', zorder=6)
            self._strings.append(line)

            halo = Ellipse((s['pluck_x'], s['y']), width=26 * scale, height=10 * scale,
                           fc=s['color'], alpha=0.0, zorder=7)
            ax.add_patch(halo)
            self._halos.append(halo)

            # Pick — small guitar-pick-shaped marker for the plucking hand,
            # smaller than the fretboard stop dot and a distinct (cool/pale)
            # colour from it (warm amber).
            pick = MplPolygon(_pick_points(s['pluck_x'], s['y'], GTR_PLK_RAD * scale),
                               closed=True, fc=GTR_PICK_CLR, ec=(0.4, 0.45, 0.5),
                               lw=0.4, alpha=0.0, zorder=9)
            ax.add_patch(pick)
            self._fingers.append(pick)

            # Fretboard stop dot — marks where the fretting hand stops the
            # string for a note above its open pitch (invisible otherwise);
            # held at full opacity for as long as the string keeps vibrating.
            dot = Circle((s['x_nut'], s['y']), radius=GTR_STOP_DOT_RAD * scale,
                         fc=GTR_STOP_DOT_CLR, ec=(0.30, 0.25, 0.20),
                         lw=0.4, alpha=0.0, zorder=8)
            ax.add_patch(dot)
            self._stop_dots.append(dot)

    def update(self, t, glow, vib_amp, vib_onset, vib_pitch, last_gest):
        n_pts = 30
        for i, s in enumerate(self.strings):
            sc = s['scale']
            g, a, onset = glow[i], vib_amp[i], vib_onset[i]
            xs = np.linspace(s['x_nut'], s['x_bridge'], n_pts)

            if a > 0.005:
                dt = t - onset
                ph = 2.0 * np.pi * GTR_VIB_FREQ * dt
                # A note fretted above the string's open pitch only
                # vibrates over the fraction of the string between the
                # fret and the bridge (x_bridge end) — length ∝ 1/frequency.
                # vib_nut is that boundary, moving from x_nut (open string,
                # full length) toward x_bridge as pitch rises.
                pitch = vib_pitch[i]
                length_frac = (sl.vibrating_length_fraction(pitch, s['open_cents'])
                               if not np.isnan(pitch) else 1.0)
                L_full = s['x_bridge'] - s['x_nut']
                vib_nut = s['x_nut'] + (1.0 - length_frac) * L_full
                L_vib = s['x_bridge'] - vib_nut

                # Standing wave: zero displacement at the fret AND bridge
                # (both ends fixed), same shape as string_section_poc's strings.
                rel = np.clip((xs - vib_nut) / max(L_vib, 1e-6), 0.0, 1.0)
                wave_shape = np.where(xs >= vib_nut, np.sin(np.pi * rel), 0.0)
                ys = s['y'] + a * 10.0 * sc * wave_shape * np.cos(ph)

                # Stop dot: only shown for an actually-fretted note
                # (length_frac < 1 — an open string has no finger down);
                # held at full opacity for as long as the string is still
                # vibrating (a > 0.005), not faded with the glow.
                if length_frac < 0.98:
                    self._stop_dots[i].center = (vib_nut, s['y'])
                    self._stop_dots[i].set_alpha(1.0)
                else:
                    self._stop_dots[i].set_alpha(0.0)
            else:
                ys = np.full(n_pts, s['y'])
                self._stop_dots[i].set_alpha(0.0)
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
                self._fingers[i].set_xy(_pick_points(s['pluck_x'], s['y'] - off, GTR_PLK_RAD * sc))
                self._fingers[i].set_alpha(alpha)
            else:
                self._fingers[i].set_alpha(0.0)


def render(npy_file, tempo, duration):
    tine_notes = load_bass_voices(npy_file, tempo, TINE_VOICES)
    if len(tine_notes):
        tine_notes[:, 1] = [pb.bucket_cents(p, bottom_octave=TINE_BOTTOM_OCTAVE) for p in tine_notes[:, 1]]

    seat = build_seat()
    reps = pb.representative_cents(bottom_octave=TINE_BOTTOM_OCTAVE)
    fake_notes = np.zeros((len(reps), 5))
    fake_notes[:, 1] = reps
    tines, pitch_to_idx = fp.build_tine_layout(
        fake_notes, seat, base_slot_w=BASE_SLOT_W,
        len_range=(MAX_TINE_LEN, MIN_TINE_LEN),
        width_range=(TINE_WIDTH_LOW, TINE_WIDTH_HIGH),
        color_fn=bass_color, max_avail=TINE_AVAIL,
    )
    n_tines = len(tines)
    n_used = len(set(pitch_to_idx[int(round(p))] for p in tine_notes[:, 1])) if len(tine_notes) else 0
    log.info(f"[bass finger piano] one instrument, {n_tines} tines, "
             f"{n_used} in use by this chorale")

    guitar_notes = load_bass_voices(npy_file, tempo, (GUITAR_VOICE,))
    strings = build_guitar_strings(GUITAR_X0, GUITAR_CY, GUITAR_SCALE)
    log.info(f"[baritone guitar] one instrument x {N_STRINGS} strings, "
             f"{len(guitar_notes)} notes, open_cents={GUITAR_OPEN_CENTS}")

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

    tine_scene = fp.TineScene(ax, tines)
    guitar_scene = GuitarScene(ax, strings, GUITAR_X0, GUITAR_CY, GUITAR_SCALE)

    stand.add_stand(
        ax, TINE_CX, TINE_NODE_Y - 3.0 * TINE_SCALE,
        rail_w=TINE_AVAIL * 1.2, rail_h=26.0,
        scale=TINE_SCALE, leg_len_ref=fp.AVAIL,
    )

    guitar_total_len = (HEAD_LEN + NECK_LEN + BODY_W) * GUITAR_SCALE
    guitar_label_y = GUITAR_CY - BODY_H * GUITAR_SCALE * 0.7

    # Bass Finger Piano's label matches the Baritone Guitar's label height
    # (guitar_label_y) instead of hanging off its own stand_bottom, so the
    # two sit on the same line.
    ax.text(TINE_CX, guitar_label_y, "Bass Finger Piano",
             ha='center', va='top', fontsize=8, color=LABEL_CLR, zorder=10)
    ax.text(GUITAR_X0 + guitar_total_len / 2, guitar_label_y, "Baritone Guitar",
             ha='center', va='top', fontsize=8, color=LABEL_CLR, zorder=10)

    for fi in range(n_frames):
        t = fi / FPS
        glow, vib_amp, vib_onset, last_gest = fp.compute_state(t, tine_notes, pitch_to_idx, n_tines)
        tine_scene.update(t, glow, vib_amp, vib_onset, last_gest)
        g_glow, g_vib_amp, g_vib_onset, g_vib_pitch, g_last_gest = compute_guitar_state(t, guitar_notes)
        guitar_scene.update(t, g_glow, g_vib_amp, g_vib_onset, g_vib_pitch, g_last_gest)
        fig.savefig(f"{FRAMES_DIR}/frame_{fi:06d}.png", dpi=mp.SAVE_DPI, transparent=True)
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
