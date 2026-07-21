#!/usr/bin/env python3
"""
finger_piano_section_poc.py — 8 invisible finger-piano players on the same
stage as string_section_poc.py and marimba_section_poc.py.

Unlike the marimba (struck bars + mallets), a finger piano (kalimba/mbira)
has tines fixed at a shared bridge (the node) at the back, free at the
front, arranged low-to-high left-to-right. A pluck sets the free end
vibrating up and down while the node stays still — a cantilever, not a
standing wave — so the visual language here is deliberately different from
marimba_poc.py's bars.

Combines csound voices 1 (finger piano) and 24 (bass finger piano) — both
named "finger piano" in adaptive_tuning_util.init_voice_time, just
different registers — and splits their pitches into 8 bands, one per seat.

Positioned in the lower/foreground band of the stage, below both the
string section and the marimba section.

Usage:
  python finger_piano_section_poc.py --npy bwv261_features_array.npy \
      --tempo 118 --duration 39.7
"""
import argparse
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Polygon as MplPolygon
import matplotlib.transforms as mtransforms

import marimba_poc as mp  # W, H, DPI, BACK_DX, BACK_DY, bar_base_color, blended
import stage_layout as stage

import logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%d %H:%M")
log = logging.getLogger(__name__)

FRAMES_DIR = "finger8_frames"
FPS = 30
VOICES = (1,)   # regular finger piano only — bass finger piano (24) now
                 # belongs to bass_section_poc.py, paired with bgui (20),
                 # since both collapse to the same csound_voice per-note
                 # (no way to split them post-hoc without double-counting)

# Back row: farther but LARGER (longer tines) — front row is smaller
# (shorter tines). Placed lower on the stage (smaller data-y, y-up space)
# than both the strings and the marimba section, in the previously-empty
# band above the title text.
# Scaled 1.5x from the original 0.18/0.23 — same ROW_X0/ROW_DX below, so
# the instruments got bigger without spreading the seats apart (tighter).
# Shrunk back down (0.65x) from 0.414/0.324: at the larger size, dense
# chorales (many unique pitches per seat -> wide tine racks) combined with
# the 45 degree per-seat tilt below made neighboring seats' tine racks
# overlap (e.g. FP.3/FP.5, FP.4/FP.6). Verified against all bwv25x-bwv264
# feature arrays to keep several px of clearance both between seats and
# between adjacent tines within a seat.
BACK_SCALE, FRONT_SCALE = 0.27, 0.21
# Row elevations from stage_layout (middle-row level with the woodwinds),
# then nudged DOWN and RIGHT.  The 45° per-seat tilt (TILT_DEG below) sends
# each tine rack up-and-to-the-left of its node, which pushed the section's
# top tines into the back-row pizzicato strings and the leftmost tines off
# the left canvas edge.  FP_DOWN_PX lowers the whole section on screen so
# the tines clear the pizzicato; FP_RIGHT_PX shifts it inboard off the edge.
# y-up data space here, so data-y = H - screen.
FP_DOWN_PX  = 45   # extra screen-y downward (clears pizzicato above)
FP_RIGHT_PX = 60   # extra x rightward (clears left canvas edge)
BACK_NODE_Y  = stage.yup(stage.ROW_MID_Y_FAR  + FP_DOWN_PX)   # back row  (screen 300)
FRONT_NODE_Y = stage.yup(stage.ROW_MID_Y_NEAR + FP_DOWN_PX)   # front row (screen 400)
                                        # node_y = fixed "bridge" y — same for
                                        # every tine in the row; tines rise up-screen
                                        # from it (tip upstage/farther, node downstage)
# Middle-row left column (under the pizz strings), shifted right by
# FP_RIGHT_PX so the tilted tine racks stay on canvas.  Back-row centre
# = (67 + FP_RIGHT_PX) + 3*ROW_DX/2 = 127 + 112.5 ≈ 240.
# Widened from 62 to 75 px so the 4-seat row spans ~225 px, giving the
# section a total footprint (~285 px) close to the woodwinds/brass width.
ROW_X0 = dict(back=67 + FP_RIGHT_PX, front=92 + FP_RIGHT_PX)
ROW_DX = 75

BASE_SLOT_W = 22.0     # px between tine centres at scale=1.0
# Real tines: low and high tines are close in length because a blob of
# solder on each tip (see SOLDER_RADIUS) adds mass and does most of the
# tuning, not tine length — so the visual length spread is intentionally
# small.  The sampled instrument's tines are only 1-3" long, so the
# modelled tines are short (and wide, below).
MAX_TINE_LEN, MIN_TINE_LEN = 52.8, 40.0   # −20% (was 66/50): low note=long, high=short, px at scale=1.0
# Real tines are 3/16" spring steel — substantial flat strips, not needles.
# Modelled as filled rectangles (polygon, not a line) so the width is
# visually meaningful.  LOW = widest (lowest note, longest tine), HIGH = narrowest.
# The sampled tines are wider than a needle, so these are wide flat strips.
TINE_WIDTH_LOW, TINE_WIDTH_HIGH = 11.2, 7.2  # −20% (was 14/9), px at scale=1.0

# Tines point straight away from the viewer (up-screen/backward), as if
# plucked by an invisible player standing behind the instrument — not
# obliquely back like the marimba bars/mallets, and not toward the viewer
# either. The node (fixed end) is the downstage/closer point; the tip
# (free, plucked end) is upstage/farther.
TINE_DIR = np.array([0.0, -1.0])

# Each instrument is tilted this many degrees (CCW in the y-up data space)
# around its node-centre so the low tines lean toward the front of the stage
# and the high tines lean up-and-to-the-right.  The diagonal splay spreads
# adjacent instruments along a 45° axis so their tine racks no longer overlap
# horizontally — the denser voicings from the longer chorale render (up to
# ~22 tines per seat) fit without collision.  Applied per-seat in TineScene.
TILT_DEG = 45

VIB_FREQ   = 7.0     # visual Hz
TAU        = 0.42    # decay time constant (kalimba tines ring longer than a pluck)
GLOW_DECAY = 0.22

PLK_APP_T = 0.055
PLK_DWL_T = 0.025
PLK_RET_T = 0.150
PLK_RAD   = 4.4       # −20% (was 5.5) finger circle radius at scale=1.0

# 1/8" drop of solder on every tine tip — same physical size regardless of
# pitch (it's what lets the shorter/higher tines still ring low), and what
# tunes the overtones ~2 octaves above the fundamental for that sweet tone.
# Solder blob: sized to sit visually on top of the (now wider) tine tip.
SOLDER_RADIUS = 7.2    # −20% (was 9.0) px at scale=1.0 — scales with the narrower tines

SEAT_LABEL_CLR = (0.50, 0.40, 0.60, 1.0)
NODE_CLR = (0.35, 0.33, 0.30, 0.9)
FINGER_CLR = (0.85, 0.78, 0.68)
SOLDER_CLR = (0.74, 0.75, 0.78)


def load_finger_piano_voices(npy_file, tempo):
    log.info(f"\n[Stage 1] Loading finger-piano voices {VOICES} from {npy_file}")
    arr = np.load(npy_file)
    mask = (arr[:, 5] > 0) & (arr[:, 2] > 0) & (arr[:, 14] > 0) & (arr[:, 3] > 0)
    mask &= np.isin(arr[:, 6].astype(int), VOICES)
    arr = arr[mask]
    if not len(arr):
        log.warning(f"  no notes found for voices {VOICES} — section will render empty")
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


def build_seats():
    seats = []
    for i in range(8):
        is_back = i < 4
        row_i = i if is_back else i - 4
        scale = BACK_SCALE if is_back else FRONT_SCALE
        node_y = BACK_NODE_Y if is_back else FRONT_NODE_Y
        cx = ROW_X0['back' if is_back else 'front'] + row_i * ROW_DX
        seats.append(dict(id=i, name=f"FP.{i + 1}", cx=cx, node_y=node_y, scale=scale))
    return seats


def build_tine_layout(notes, seats, base_slot_w=BASE_SLOT_W,
                       len_range=(MAX_TINE_LEN, MIN_TINE_LEN),
                       width_range=(TINE_WIDTH_LOW, TINE_WIDTH_HIGH),
                       color_fn=None, max_avail=None):
    """Split notes across seats by pitch band; return one flat tines list
    (node fixed per-seat, tip position + length varying low->high) and a
    pitch->tine-index map.

    base_slot_w/len_range/width_range/color_fn let other sections (e.g.
    bass_section_poc.py) reuse this geometry with their own proportions —
    defaults reproduce the regular finger-piano look.
    """
    if not len(notes):
        return [], {}

    max_len, min_len = len_range
    width_low, width_high = width_range
    color_fn = color_fn or mp.bar_base_color

    pitch_vals_all = np.sort(np.unique(np.round(notes[:, 1]).astype(int)))
    bands = np.array_split(pitch_vals_all, len(seats))
    edges = [None] + [int(b[0]) for b in bands[1:]] + [None]

    tines = []
    pitch_to_idx = {}
    idx = 0
    for si, seat in enumerate(seats):
        lo, hi = edges[si], edges[si + 1]
        mask = np.ones(len(notes), dtype=bool)
        if lo is not None:
            mask &= notes[:, 1] >= lo
        if hi is not None:
            mask &= notes[:, 1] < hi
        sub = notes[mask]
        if not len(sub):
            continue
        pitch_vals = np.sort(np.unique(np.round(sub[:, 1]).astype(int)))
        n = len(pitch_vals)
        scale = seat['scale']
        avail = n * base_slot_w * scale
        if max_avail is not None:
            avail = min(avail, max_avail)
        slot_w = avail / n
        base_x = seat['cx'] - avail / 2
        node_y = seat['node_y']

        for i, pitch in enumerate(pitch_vals):
            t = i / max(n - 1, 1)   # 0 = lowest (left, long tine), 1 = highest (right, short)
            cx = base_x + slot_w * (i + 0.5)
            length = (min_len + (max_len - min_len) * (1 - t)) * scale
            node = np.array([cx, node_y])
            tip  = node - length * TINE_DIR
            width = (width_low - t * (width_low - width_high)) * scale
            tines.append(dict(
                pitch=pitch, idx=idx, node=node, tip=tip, length=length,
                width=width, scale=scale, base=color_fn(i, n),
                seat_name=seat['name'],
            ))
            pitch_to_idx[pitch] = idx
            idx += 1
    return tines, pitch_to_idx


def compute_state(t, notes, pitch_to_idx, n_tines):
    """Per-tine glow, vibration amplitude/onset, and pluck-gesture onset."""
    glow      = np.zeros(n_tines)
    vib_amp   = np.zeros(n_tines)
    vib_onset = np.full(n_tines, -999.0)
    last_gest = {}

    total_gest = PLK_APP_T + PLK_DWL_T + PLK_RET_T
    for row in notes:
        onset_t = row[0]
        pitch   = int(round(row[1]))
        idx = pitch_to_idx.get(pitch)
        if idx is None:
            continue
        dt = t - onset_t

        if 0.0 <= dt <= GLOW_DECAY:
            glow[idx] = max(glow[idx], 1.0 - dt / GLOW_DECAY)

        if dt >= 0.0:
            amp = float(np.exp(-dt / TAU))
            if amp > vib_amp[idx]:
                vib_amp[idx] = amp
                vib_onset[idx] = onset_t

        if -PLK_APP_T <= dt <= total_gest:
            if idx not in last_gest or onset_t > last_gest[idx]:
                last_gest[idx] = onset_t

    return glow, vib_amp, vib_onset, last_gest


def _tine_poly_pts(xs, ys, half_w):
    """Build a closed polygon (left edge down, right edge up) for a tine
    rendered as a flat rectangular strip of width 2*half_w.  The strip is
    perpendicular to TINE_DIR (i.e. horizontal, since TINE_DIR is vertical).
    xs/ys are the n_pts centreline samples from node to tip."""
    left_xs  = xs - half_w
    right_xs = xs + half_w
    # Polygon: left edge node→tip, then right edge tip→node (closed loop)
    poly_xs = np.concatenate([left_xs, right_xs[::-1]])
    poly_ys = np.concatenate([ys,      ys[::-1]])
    return np.column_stack([poly_xs, poly_ys])


class TineScene:
    def __init__(self, ax, tines, seats=None, tilt_deg=0.0):
        self.ax = ax
        self.tines = tines
        self._polys   = []   # filled strip polygon for the tine body
        self._edges   = []   # thin dark outline polygon (gives depth)
        self._nodes   = []
        self._solders = []
        self._fingers = []

        # Per-seat tilt transform (optional): rotates each instrument around its
        # node-centre (cx, node_y) so low tines lean toward the front and high
        # tines up-right, spreading adjacent instruments along a diagonal so they
        # don't overlap.  When seats is None (e.g. bass_section_poc reuses this
        # class) no tilt is applied — backward compatible.
        self._seat_xform = {}
        if seats is not None and tilt_deg != 0.0:
            for s in seats:
                px, py = s['cx'], s['node_y']
                self._seat_xform[s['name']] = (mtransforms.Affine2D()
                                               .translate(-px, -py)
                                               .rotate_deg(tilt_deg)
                                               .translate(px, py)
                                               + ax.transData)

        n_pts = 14
        svals = np.linspace(0.0, 1.0, n_pts)

        for tn in tines:
            node, tip = tn['node'], tn['tip']
            half_w = tn['width'] / 2.0

            # Static rest-position polygon (will be updated each frame)
            base_pts = node[None, :] + svals[:, None] * (tip - node)[None, :]
            pts = _tine_poly_pts(base_pts[:, 0], base_pts[:, 1], half_w)

            # Main face — slightly lighter than base for a polished-steel look
            face_c = mp.blended(tn['base'], 0.0)
            poly = MplPolygon(pts, closed=True,
                              fc=face_c, ec='none', zorder=6)
            ax.add_patch(poly)
            self._polys.append(poly)

            # Thin darker edge outline — gives the strip visual thickness
            edge_c = tuple(max(0.0, c - 0.18) for c in tn['base'])
            edge = MplPolygon(pts, closed=True,
                              fc='none', ec=edge_c, lw=0.7, zorder=7)
            ax.add_patch(edge)
            self._edges.append(edge)

            # Node clamp — slightly wider than the tine
            nd = Circle(node, radius=max(2.5, half_w * 1.4),
                        fc=NODE_CLR, ec='none', zorder=8)
            ax.add_patch(nd)
            self._nodes.append(nd)

            solder = Circle(tip, radius=SOLDER_RADIUS * tn['scale'],
                             fc=SOLDER_CLR, ec=NODE_CLR, lw=0.6, zorder=9)
            ax.add_patch(solder)
            self._solders.append(solder)

            finger = Circle(tip, radius=PLK_RAD * tn['scale'],
                             fc=FINGER_CLR, ec='none', alpha=0.0, zorder=10)
            ax.add_patch(finger)
            self._fingers.append(finger)

            # Apply this seat's tilt transform to all of the tine's artists so
            # the whole instrument rotates as one rigid body.  The per-frame
            # set_xy / set_center updates in update() happen in data coords and
            # are then rotated by this transform, so vibration + pluck gestures
            # carry through the tilt correctly.
            xf = self._seat_xform.get(tn['seat_name'])
            if xf is not None:
                poly.set_transform(xf)
                edge.set_transform(xf)
                nd.set_transform(xf)
                solder.set_transform(xf)
                finger.set_transform(xf)

    def update(self, t, glow, vib_amp, vib_onset, last_gest):
        n_pts = 14
        svals = np.linspace(0.0, 1.0, n_pts)
        shape = svals ** 2   # cantilever profile: 0 at node, max at tip

        for i, tn in enumerate(self.tines):
            node, tip = tn['node'], tn['tip']
            g, a, onset = glow[i], vib_amp[i], vib_onset[i]
            half_w = tn['width'] / 2.0

            base_pts = node[None, :] + svals[:, None] * (tip - node)[None, :]
            if a > 0.01:
                dt = t - onset
                ph = 2.0 * np.pi * VIB_FREQ * dt
                disp = a * 9.0 * tn['scale'] * shape * np.cos(ph)
                ys = base_pts[:, 1] + disp
            else:
                ys = base_pts[:, 1]
            xs = base_pts[:, 0]

            # Update filled strip polygon
            pts = _tine_poly_pts(xs, ys, half_w)
            face_c = mp.blended(tn['base'], g) if g > 0.04 else tn['base']
            self._polys[i].set_xy(pts)
            self._polys[i].set_facecolor(face_c)
            self._edges[i].set_xy(pts)

            self._solders[i].center = (xs[-1], ys[-1])
            solder_fc = mp.blended(SOLDER_CLR, g * 0.6) if g > 0.04 else SOLDER_CLR
            self._solders[i].set_facecolor(solder_fc)

            gest_onset = last_gest.get(i)
            if gest_onset is None:
                self._fingers[i].set_alpha(0.0)
                continue
            dt = t - gest_onset
            total = PLK_APP_T + PLK_DWL_T + PLK_RET_T
            if -PLK_APP_T <= dt <= total:
                # Finger approaches from beyond the tip (continuing the
                # tine's own downward direction), touches, retracts.
                approach_vec = -TINE_DIR
                if dt < 0:
                    ph = ((dt + PLK_APP_T) / PLK_APP_T) ** 1.5
                    off = (18.0 * tn['scale']) * (1.0 - ph)
                    alpha = ph
                elif dt < PLK_DWL_T:
                    off = 0.0
                    alpha = 1.0
                else:
                    ph = min(1.0, (dt - PLK_DWL_T) / PLK_RET_T) ** 0.7
                    off = (18.0 * tn['scale']) * ph
                    alpha = max(0.0, 1.0 - ph)
                fx, fy = tip + approach_vec * off
                self._fingers[i].center = (fx, fy)
                self._fingers[i].set_alpha(alpha)
            else:
                self._fingers[i].set_alpha(0.0)


def render(npy_file, tempo, duration):
    notes = load_finger_piano_voices(npy_file, tempo)
    seats = build_seats()
    tines, pitch_to_idx = build_tine_layout(notes, seats)
    n_tines = len(tines)
    log.info(f"[finger piano section] {n_tines} tines across {len(seats)} seats")
    for seat in seats:
        n = sum(1 for tn in tines if tn['seat_name'] == seat['name'])
        log.info(f"  {seat['name']}: {n} tines @ (cx={seat['cx']}, node_y={seat['node_y']}, scale={seat['scale']})")

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

    scene = TineScene(ax, tines, seats, tilt_deg=TILT_DEG)

    for seat in seats:
        # Node is now the downstage (lowest-image-row) point since tines
        # point backward/upstage from it — label goes just below the node.
        label_y = seat['node_y'] - 8 * seat['scale']
        ax.text(seat['cx'], label_y, seat['name'], ha='center', va='top',
                 fontsize=8, color=SEAT_LABEL_CLR, zorder=10)

    for fi in range(n_frames):
        t = fi / FPS
        glow, vib_amp, vib_onset, last_gest = compute_state(t, notes, pitch_to_idx, n_tines)
        scene.update(t, glow, vib_amp, vib_onset, last_gest)
        fig.savefig(f"{FRAMES_DIR}/frame_{fi:06d}.png", dpi=mp.DPI, transparent=True)
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
