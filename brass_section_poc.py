#!/usr/bin/env python3
"""
brass_section_poc.py — 4 invisible brass players on the same stage
(was 8 — one trombone and one tuba now instead of two each).

Instruments:
  Back row (lower): trombone (csound_voice 26), tuba (csound_voice 27)
  Front row (higher): 2 trumpets (csound_voice 25)

Each instrument has:
  • A static silhouette drawn once at setup (tubes, valves, bell)
  • An idle-sway transform — slow sinusoidal rotation, per-seat phase
  • A playing-lean — tips toward the mouthpiece when a note fires
  • A glow on the brass body for the duration of the held note

Renders transparent frames (no background) meant to be composited onto
string_section_poc.py's frames by compose_stage_merge.py.

Usage:
  python brass_section_poc.py --npy bwv261_features_array.npy \\\\
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

import marimba_poc as mp   # W, H, DPI
import stage_layout as stage

import logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%d %H:%M")
log = logging.getLogger(__name__)

# ── Constants ──────────────────────────────────────────────────────────────────
FRAMES_DIR = "brass8_frames"
FPS        = 30

# Voice numbers (from adaptive_tuning_util.init_voice_time)
VOICE_TRUMPET   = 25
VOICE_TROMBONE  = 26
VOICE_TUBA      = 27
ALL_BRASS_VOICES = (VOICE_TRUMPET, VOICE_TROMBONE, VOICE_TUBA)

# Canvas (inherited from marimba_poc)
W, H, DPI = mp.W, mp.H, mp.DPI
SAVE_DPI  = mp.SAVE_DPI

# ── Layout ─────────────────────────────────────────────────────────────────────
# Brass occupies the right of the middle row (stage.MID_X[2]), in two rows
# of 4 (back + front).  y-up data space (ax.set_ylim(0, H)), so
# data-y = H - screen.  Row elevations shared with finger pianos / woodwinds
# via stage_layout so the middle row lines up across sections.
# BRASS_Y_PAD pulls the back row down a bit more than the shared stage row:
# the bass finger piano's label sits at x~905/y~534, close to the trombone's
# own label above it at x~954 — the bigger trombone/tuba (see SCALE_BACK
# below) needs the extra clearance.
BRASS_Y_PAD   = 25
BRASS_Y_BACK  = stage.yup(stage.ROW_MID_Y_FAR) - BRASS_Y_PAD   # back row  (screen 255)
BRASS_Y_FRONT = stage.yup(stage.ROW_MID_Y_NEAR)                # front row (screen 355)
BRASS_X_STEP  = 140   # widened now that only 2 seats/row need to span the section
BRASS_X_LEFT  = int(stage.MID_X[2] - 0.5 * BRASS_X_STEP)   # two columns, centred at MID_X[2]
BRASS_X_RIGHT = int(stage.MID_X[2] + 0.5 * BRASS_X_STEP)

# scale factors — back row smaller (farther), front row larger (closer).
# Bumped up (~35%) now that each row holds 2 seats instead of 4.
SCALE_BACK  = 1.05
SCALE_FRONT = 1.25

# ── Colour palette ─────────────────────────────────────────────────────────────
CLR_BRASS      = (0.82, 0.68, 0.22)       # brass body
CLR_BRASS_DK   = (0.55, 0.42, 0.10)       # dark brass (edges, shadows)
CLR_BRASS_BELL = (0.90, 0.78, 0.32)       # bell interior (bright)
CLR_VALVE      = (0.72, 0.74, 0.78)       # silver piston/rotary valves
CLR_SLIDE      = (0.78, 0.80, 0.82)       # silver slide tubes
CLR_MPC        = (0.65, 0.63, 0.60)       # mouthpiece (dark metal)

LABEL_CLR = (0.55, 0.50, 0.35, 1.0)

# Base tilt per brass family.  The instrument is drawn vertical (mouthpiece
# at the top, bell at the bottom); rotate_deg is CCW in the y-up data space.
#   -45° (clockwise) swings the mouthpiece to the upper-right and the bell to
#   the lower-left (down-and-to-the-left) — the trombone/tuba pose.
#  -135° swings the mouthpiece to the lower-right and the bell to the
#   upper-left (up-and-to-the-left) — the trumpet pose.
BASE_TILT          = -45.0    # tubas:                bell down-and-to-the-left
BASE_TILT_TRUMPET  = -135.0   # trumpets / trombones:  bell up-and-to-the-left

# Trombone slide travel.  Drawn (rest) at SLIDE_RETRACT_Y*sc above the bell —
# the retracted, high-note position — and slides down toward
# SLIDE_RETRACT_Y - SLIDE_EXTEND_PX (extended, low-note position) in
# BrassScene.update(). SLIDE_TAU sets how quickly it glides to a new target.
SLIDE_RETRACT_Y  = 10     # px at scale=1 above the bell, at rest (matches old fixed position)
SLIDE_EXTEND_PX  = 22     # px at scale=1 of additional downward travel, fully extended
SLIDE_TAU        = 0.12   # seconds — smoothing time constant for slide motion

# glow targets per instrument family
GLOW_CLR = {
    'trumpet':  (1.00, 0.90, 0.50),
    'trombone': (1.00, 0.85, 0.42),
    'tuba':     (1.00, 0.82, 0.35),
}

# ── Timing ────────────────────────────────────────────────────────────────────
GLOW_DECAY   = 0.65    # sustained notes glow longer than struck ones
PLAY_LEAN_T  = 0.06    # seconds to reach full lean on note-on
PLAY_RELAX_T = 0.55    # seconds to relax back after note-off

# Idle sway: slow sinusoidal rock, each seat its own frequency + phase.
# The sway itself fades out after an instrument's been silent for a while
# (SWAY_ENV_TAU_OUT) and fades back in once it starts playing again
# (SWAY_ENV_TAU_IN, quicker) — an exponentially-smoothed envelope on the
# sway amplitude (same technique as the trombone slide below), rather than
# an instant on/off.
SWAY_AMP_DEG = 5.0     # ± degrees — doubled so players sway ~2× more
SWAY_FREQS   = [0.1875, 0.2375, 0.2125, 0.2625]  # 25% faster
SWAY_PHASES  = [0.0,  1.3,  2.7,  0.5]
SWAY_ENV_TAU_IN  = 0.4    # seconds — fades in fairly quickly once playing resumes
SWAY_ENV_TAU_OUT = 3.0    # seconds — fades out slowly after falling silent

# Playing lean: extra tilt toward mouthpiece when a note is held.
# Doubled (≈2×) so the players move more while enjoying the music.
PLAY_LEAN_DEG = {
    'trumpet':  10.0,
    'trombone': 8.0,
    'tuba':      5.0,
}


# ── Colour helpers ─────────────────────────────────────────────────────────────
def _darken(c, f=0.35):
    return tuple(max(0.0, x - f * x) for x in c)

def _lighten(c, f=0.25):
    return tuple(min(1.0, x + f * (1 - x)) for x in c)


# Which of each draw_*()'s returned patches share CLR_BRASS and should join
# the playing-glow (indices into that patch list) — trombone's single main
# tube is one patch, but trumpet's tube is split top/bottom around the valve
# cluster (leadpipe + v_tube) and tuba's coil has two same-coloured rings
# (outer + middle); lighting only one piece left the rest looking unlit.
GLOW_PATCH_IDX = {
    'trumpet':  (0, 9),   # leadpipe + v_tube
    'trombone': (0,),     # main tube
    'tuba':     (0, 1),   # outer + middle coil
}


def _set_patch_color(patch, color):
    """Arc never fills (matplotlib forces fill=False on it), so its visible
    colour is the edge/line colour, not facecolor — set whichever actually
    renders."""
    if isinstance(patch, Arc):
        patch.set_edgecolor(color)
    else:
        patch.set_facecolor(color)


# ── Seat definitions ──────────────────────────────────────────────────────────
def make_seats():
    """Return list of 4 seat dicts in two rows of 2 (back + front) — one
    trombone and one tuba instead of two each; two trumpets instead of four.
    Lower instruments (trombone, tuba) are at the BACK; higher instruments
    (trumpets) are at the FRONT — matching orchestral layout where lower
    voices sit farther back."""
    # Tuba's coil top sits well below the trombone's bell at the same cy
    # (measured from the two draw_*() functions' actual bounding boxes:
    # trombone bell top ~55.0, tuba coil top ~32.7 at SCALE_BACK=1.05) — this
    # raises the tuba seat so the two tops line up.
    TUBA_Y_RAISE = 22.35
    specs = [
        # name,        kind,       voice,           cx,             cy,                          scale
        # Back row (lower): trombone, tuba
        ('Trombone',   'trombone', VOICE_TROMBONE, BRASS_X_LEFT,  BRASS_Y_BACK,                  SCALE_BACK),
        ('Tuba',       'tuba',     VOICE_TUBA,     BRASS_X_RIGHT, BRASS_Y_BACK + TUBA_Y_RAISE,    SCALE_BACK),
        # Front row (higher): two trumpets
        ('Trumpet I',  'trumpet',  VOICE_TRUMPET,  BRASS_X_LEFT,  BRASS_Y_FRONT,                  SCALE_FRONT),
        ('Trumpet II', 'trumpet',  VOICE_TRUMPET,  BRASS_X_RIGHT, BRASS_Y_FRONT,                  SCALE_FRONT),
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
def load_brass_voices(npy_file, tempo):
    log.info(f"\n[brass] Loading {npy_file}")
    arr = np.load(npy_file)
    mask = (arr[:, 5] > 0) & (arr[:, 2] > 0) & (arr[:, 14] > 0) & (arr[:, 3] > 0)
    mask &= np.isin(arr[:, 6].astype(int), ALL_BRASS_VOICES)
    arr  = arr[mask]
    if not len(arr):
        log.warning("  no brass notes found — section will render silent")
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
    for v in ALL_BRASS_VOICES:
        n = int((notes[:, 5].astype(int) == v).sum())
        name = {25:'trumpet', 26:'trombone', 27:'tuba'}[v]
        log.info(f"  voice {v} ({name}): {n} notes")
    log.info(f"  total {len(notes)} notes")
    return notes


def route_notes(notes, seats):
    """Split notes to seats: each seat owns its voice; for voices with
    multiple seats (trumpet×4, trombone×2, tuba×2), alternate by onset
    time so consecutive notes interleave — simulates independent players."""
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
    """Per seat: glow (0..1), is_playing (bool), last_note_off (float),
    pitch (cents of the currently-playing note, or None)."""
    states = {}
    for s in seats:
        sid    = s['id']
        notes  = seat_note_sets[sid]
        glow   = 0.0
        playing = False
        last_off = -999.0
        pitch = None

        for row in notes:
            onset, pitch_cents, dur = row[0], row[1], row[2]
            dt = t - onset
            note_end = onset + dur

            if onset <= t <= note_end:
                playing = True
                glow = max(glow, 1.0)
                pitch = pitch_cents
            elif t > note_end:
                decay = (t - note_end) / GLOW_DECAY
                if decay < 1.0:
                    glow = max(glow, 1.0 - decay)
                if note_end > last_off:
                    last_off = note_end

        states[sid] = dict(glow=glow, playing=playing, last_off=last_off, pitch=pitch)
    return states


# ── Instrument geometry ───────────────────────────────────────────────────────
# Each draw_*() adds patches to ax and returns (patches, pivot, lean_dir).

def draw_trumpet(ax, cx, cy, sc):
    """Trumpet — vertical brass tube with 3 piston valves and a flared
    bell at the BOTTOM.  Mouthpiece at the TOP (where the player's lips are).
    The -45° base tilt applied by BrassScene swings the bell to the lower-left."""
    patches = []
    tube_len   = 58 * sc   # vertical length
    tube_w     =  7 * sc   # horizontal width
    bell_h     = 18 * sc   # bell extends below the tube
    bell_w     = 16 * sc   # bell flare width
    valve_w    =  6 * sc
    valve_h    = 14 * sc

    top = cy + tube_len / 2    # mouthpiece end (TOP in y-up)
    bot = cy - tube_len / 2    # bell tube end (BOTTOM)

    # Leadpipe (top section, from mouthpiece down to valves)
    lead_len = tube_len * 0.35
    leadpipe = Rectangle((cx - tube_w/2, top - lead_len), tube_w, lead_len,
                         fc=CLR_BRASS, ec=CLR_BRASS_DK, lw=0.6, zorder=5)
    ax.add_patch(leadpipe); patches.append(leadpipe)

    # Tuning slide — small U-bend bulging to the right of the leadpipe
    slide_r = tube_w * 0.8
    slide = Arc((cx + tube_w*0.3, top - 4*sc), slide_r*2, slide_r*2,
                angle=0, theta1=-90, theta2=90,
                color=CLR_BRASS_DK, lw=tube_w*0.7, zorder=4)
    ax.add_patch(slide); patches.append(slide)

    # Mouthpiece (tapered cup at the very top)
    mpc = MplPolygon(np.array([
        [cx - 2.5*sc, top + 5*sc], [cx - tube_w*0.45, top],
        [cx + tube_w*0.45, top],   [cx + 2.5*sc, top + 5*sc],
        [cx, top + 7*sc],
    ]), closed=True, fc=CLR_MPC, ec=CLR_BRASS_DK, lw=0.4, zorder=6)
    ax.add_patch(mpc); patches.append(mpc)

    # Valve cluster (3 pistons, sticking out to the right of the tube)
    valve_y0 = top - lead_len
    valve_area_h = tube_len * 0.38
    for i in range(3):
        vy = valve_y0 - i * (valve_area_h / 3) - 2*sc
        valve = Rectangle((cx + tube_w*0.2, vy - valve_h), valve_w, valve_h,
                          fc=CLR_VALVE, ec=CLR_BRASS_DK, lw=0.4, zorder=7)
        ax.add_patch(valve); patches.append(valve)
        cap = Ellipse((cx + tube_w*0.2 + valve_w/2, vy),
                      valve_w*1.1, 3*sc, fc=CLR_BRASS_DK, ec='none', zorder=8)
        ax.add_patch(cap); patches.append(cap)

    # Main tube (from valves down to bell tube)
    v_tube = Rectangle((cx - tube_w/2, bot),
                       tube_w, valve_y0 - bot,
                       fc=CLR_BRASS, ec=CLR_BRASS_DK, lw=0.6, zorder=5)
    ax.add_patch(v_tube); patches.append(v_tube)

    # Bell — flared opening at the bottom
    bell = MplPolygon(np.array([
        [cx - tube_w/2, bot], [cx + tube_w/2, bot],
        [cx + bell_w/2, bot - bell_h],
        [cx - bell_w/2, bot - bell_h],
    ]), closed=True, fc=CLR_BRASS_BELL, ec=CLR_BRASS_DK, lw=0.7, zorder=6)
    ax.add_patch(bell); patches.append(bell)
    rim = Ellipse((cx, bot - bell_h), bell_w, 3*sc,
                  fc=CLR_BRASS_DK, ec='none', zorder=7)
    ax.add_patch(rim); patches.append(rim)

    # Finger hook — small arc to the left of the valve cluster
    hook = Arc((cx - tube_w*0.5 - 3*sc, valve_y0 - valve_area_h*0.5),
               5*sc, 5*sc, angle=0, theta1=-90, theta2=90,
               color=CLR_BRASS_DK, lw=1.5*sc, zorder=6)
    ax.add_patch(hook); patches.append(hook)

    return patches, (cx, cy), -3.0, {}


def draw_trombone(ax, cx, cy, sc):
    """Trombone — vertical brass tube with a slide (U-bend to the side)
    and a large bell at the BOTTOM.  Mouthpiece at the TOP.  The slide
    (lv/rv/ubend) is drawn at its fully-retracted rest position here;
    BrassScene.update() slides it out per-frame based on pitch."""
    patches = []
    tube_len = 76 * sc   # vertical length
    tube_w   =  8 * sc   # horizontal width
    bell_h   = 22 * sc   # bell extends below
    bell_w   = 22 * sc   # bell flare width

    top = cy + tube_len / 2    # mouthpiece end (TOP)
    bot = cy - tube_len / 2    # bell end (BOTTOM)

    # Main tube (vertical, slightly offset to the left to make room for the slide)
    main_x = cx - 3*sc
    upper = Rectangle((main_x - tube_w/2, bot), tube_w, tube_len,
                      fc=CLR_BRASS, ec=CLR_BRASS_DK, lw=0.6, zorder=5)
    ax.add_patch(upper); patches.append(upper)

    # Mouthpiece at the top
    mpc = MplPolygon(np.array([
        [main_x - 2.5*sc, top + 5*sc], [main_x - tube_w*0.45, top],
        [main_x + tube_w*0.45, top],   [main_x + 2.5*sc, top + 5*sc],
        [main_x, top + 7*sc],
    ]), closed=True, fc=CLR_MPC, ec=CLR_BRASS_DK, lw=0.4, zorder=6)
    ax.add_patch(mpc); patches.append(mpc)

    # Slide — two parallel silver tubes to the right of the main tube + U-bend
    # at the bottom.  slide_top is the fixed (body-anchored) end; slide_bot is
    # the end that travels — drawn here at SLIDE_RETRACT_Y (rest/retracted,
    # high-note position); BrassScene.update() moves slide_bot down toward
    # SLIDE_RETRACT_Y - SLIDE_EXTEND_PX*sc as notes get lower.
    slide_x = cx + 5*sc
    sw = 5 * sc
    slide_top = top - 3*sc
    slide_bot = bot + SLIDE_RETRACT_Y * sc
    slide_len = slide_top - slide_bot
    lv = Rectangle((slide_x - sw/2, slide_bot), sw, slide_len,
                   fc=CLR_SLIDE, ec=CLR_BRASS_DK, lw=0.4, zorder=5)
    ax.add_patch(lv); patches.append(lv)
    rv = Rectangle((slide_x + sw + 2*sc - sw/2, slide_bot), sw, slide_len,
                   fc=CLR_SLIDE, ec=CLR_BRASS_DK, lw=0.4, zorder=5)
    ax.add_patch(rv); patches.append(rv)
    # U-bend at the bottom of the slide (right-facing arc)
    ubend = Arc((slide_x + sw + sc, slide_bot),
                sw * 2 + 4*sc, (sw * 2 + 4*sc) * 0.85,
                angle=0, theta1=180, theta2=360,
                color=CLR_SLIDE, lw=sw, zorder=5)
    ax.add_patch(ubend); patches.append(ubend)

    # Bell (larger than trumpet) — flared opening at the bottom
    bell = MplPolygon(np.array([
        [main_x - tube_w/2, bot], [main_x + tube_w/2, bot],
        [main_x + bell_w/2, bot - bell_h],
        [main_x - bell_w/2, bot - bell_h],
    ]), closed=True, fc=CLR_BRASS_BELL, ec=CLR_BRASS_DK, lw=0.7, zorder=6)
    ax.add_patch(bell); patches.append(bell)
    rim = Ellipse((main_x, bot - bell_h), bell_w, 3*sc,
                  fc=CLR_BRASS_DK, ec='none', zorder=7)
    ax.add_patch(rim); patches.append(rim)

    extra = dict(slide_lv=lv, slide_rv=rv, slide_ubend=ubend,
                 slide_x=slide_x, sw=sw, slide_top=slide_top, bot=bot, sc=sc)
    return patches, (cx, cy), -2.5, extra


def draw_tuba(ax, cx, cy, sc):
    """Tuba — large coiled brass with a big bell and rotary valves.
    Mouthpiece at the TOP, bell pointing DOWNWARD.  The -45° base tilt
    swings the bell to the lower-left.  The coil itself is circular and
    doesn't change with orientation."""
    patches = []
    r_outer = 30 * sc
    r_inner = 15 * sc
    lw_tube = 5.5 * sc

    # Outer coil
    coil_o = Arc((cx, cy), r_outer*2, r_outer*2,
                 angle=0, theta1=30, theta2=330,
                 color=CLR_BRASS, lw=lw_tube, zorder=5)
    ax.add_patch(coil_o); patches.append(coil_o)

    # Middle coil
    r_mid = (r_outer + r_inner) / 2
    coil_m = Arc((cx, cy), r_mid*2, r_mid*2,
                 angle=0, theta1=25, theta2=335,
                 color=CLR_BRASS, lw=lw_tube*0.8, zorder=5)
    ax.add_patch(coil_m); patches.append(coil_m)

    # Inner coil
    coil_i = Arc((cx, cy), r_inner*2, r_inner*2,
                 angle=0, theta1=20, theta2=340,
                 color=CLR_BRASS_DK, lw=lw_tube*0.6, zorder=5)
    ax.add_patch(coil_i); patches.append(coil_i)

    # Large bell pointing downward
    bell_r = r_outer * 1.35
    bell = Arc((cx, cy), bell_r*2, bell_r*1.5,
               angle=0, theta1=250, theta2=290,
               color=CLR_BRASS_BELL, lw=lw_tube*1.8, zorder=6)
    ax.add_patch(bell); patches.append(bell)

    # Mouthpiece entering from the top
    mpc_y = cy + r_outer + 4*sc
    mpc = Rectangle((cx - 2*sc, mpc_y), 4*sc, 8*sc,
                    fc=CLR_MPC, ec=CLR_BRASS_DK, lw=0.5, zorder=6)
    ax.add_patch(mpc); patches.append(mpc)

    # Rotary valves (4 silver rectangles inside the coil)
    for vx_off in (-8*sc, -2*sc, 4*sc, 10*sc):
        vy = cy - r_inner*0.3 - 2.5*sc
        v = Rectangle((cx + vx_off, vy), 5*sc, 6*sc,
                      fc=CLR_VALVE, ec=CLR_BRASS_DK, lw=0.5, zorder=7)
        ax.add_patch(v); patches.append(v)

    return patches, (cx, cy), -1.5, {}


# ── Scene ─────────────────────────────────────────────────────────────────────
class BrassScene:
    """Manages the per-seat transforms (idle sway + playing lean) and glow,
    updating each frame for sway + playing lean."""

    def __init__(self, fig, ax, seats, trombone_pitch_range=(2400.0, 5000.0)):
        self.fig   = fig
        self.ax    = ax
        self.seats = seats
        self._seat_patches  = {}
        self._seat_pivot    = {}
        self._seat_lean_dir = {}
        self._seat_xforms   = {}
        self._body_patches  = {}
        self._seat_extra    = {}
        self._slide_frac    = {}
        self._sway_env      = {}   # sid → current sway envelope (0..1, eased toward playing state)
        self._trb_lo, self._trb_hi = trombone_pitch_range

        draw_fn = {
            'trumpet':  draw_trumpet,
            'trombone': draw_trombone,
            'tuba':     draw_tuba,
        }

        for s in seats:
            fn = draw_fn[s['kind']]
            patches, pivot, lean_dir, extra = fn(ax, s['cx'], s['cy'], s['sc'])

            self._seat_patches[s['id']]   = patches
            self._seat_pivot[s['id']]     = pivot
            self._seat_lean_dir[s['id']]  = lean_dir
            self._body_patches[s['id']]   = [patches[i] for i in GLOW_PATCH_IDX[s['kind']]]
            self._seat_extra[s['id']]     = extra
            self._slide_frac[s['id']]     = 0.0   # retracted at rest
            self._sway_env[s['id']]       = 0.0   # starts still; fades in on first note

            xf = mtransforms.Affine2D() + ax.transData
            for p in patches:
                p.set_transform(xf)
            self._seat_xforms[s['id']] = xf

            # Back row (trombone/tuba) label sits above the seat; front row
            # (trumpets) sits below — the trombone's bell (bigger now, after
            # the size bump) reaches down into where an above-seat front-row
            # label would otherwise sit.
            if s['cy'] == BRASS_Y_FRONT:
                label_y = s['cy'] - 60 * s['sc']
                va = 'bottom'
            else:
                # Anchored to BRASS_Y_BACK (not s['cy']) so the tuba's label
                # — raised along with its seat to align the tuba's top with
                # the trombone's bell — still lines up with the trombone's.
                # Trombone's mouthpiece cone (upper-right after the tilt)
                # reaches close to a same-x label at this scale; +70 instead
                # of +55 clears it.
                label_y = BRASS_Y_BACK + 70 * s['sc']
                va = 'top'
            ax.text(s['cx'], label_y, s['name'],
                    ha='center', va=va, fontsize=8,
                    color=LABEL_CLR, zorder=12)

    @staticmethod
    def _get_base_color(kind):
        return CLR_BRASS   # all brass instruments share the brass body colour

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

            # Idle sway, faded by an envelope that eases toward 1 (playing)
            # or 0 (been silent a while) — settles to stillness after
            # resting rather than swaying forever.
            sway_tau = SWAY_ENV_TAU_IN if playing else SWAY_ENV_TAU_OUT
            sway_alpha = 1.0 - math.exp(-(1.0 / FPS) / sway_tau)
            target_env = 1.0 if playing else 0.0
            self._sway_env[sid] += (target_env - self._sway_env[sid]) * sway_alpha

            sway_angle = SWAY_AMP_DEG * self._sway_env[sid] * math.sin(
                2 * math.pi * s['sway_freq'] * t + s['sway_phase'])

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

            base_tilt = BASE_TILT_TRUMPET if s['kind'] in ('trumpet', 'trombone') else BASE_TILT
            total_angle = base_tilt + sway_angle + lean_angle * math.copysign(1, lean_dir)

            # Trombone slide: extend for low notes, retract for high notes.
            # Local (pre-rotation) geometry only — the shared rigid transform
            # below carries it along with the rest of the instrument.
            if s['kind'] == 'trombone':
                extra = self._seat_extra[sid]
                pitch = state['pitch']
                if pitch is not None:
                    norm = (pitch - self._trb_lo) / max(1.0, self._trb_hi - self._trb_lo)
                    norm = min(1.0, max(0.0, norm))
                    target = 1.0 - norm   # low pitch -> extend (1), high pitch -> retract (0)
                else:
                    target = self._slide_frac[sid]   # hold last position
                alpha = 1.0 - math.exp(-(1.0 / FPS) / SLIDE_TAU)
                self._slide_frac[sid] += (target - self._slide_frac[sid]) * alpha

                sc = extra['sc']
                slide_bot = extra['bot'] + SLIDE_RETRACT_Y * sc - self._slide_frac[sid] * SLIDE_EXTEND_PX * sc
                slide_top = extra['slide_top']
                extra['slide_lv'].set_y(slide_bot)
                extra['slide_lv'].set_height(slide_top - slide_bot)
                extra['slide_rv'].set_y(slide_bot)
                extra['slide_rv'].set_height(slide_top - slide_bot)
                extra['slide_ubend'].set_center((extra['slide_x'] + extra['sw'] + sc, slide_bot))

            # Glow: tint body colour
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

            # Apply combined affine transform
            xf = (mtransforms.Affine2D()
                  .translate(-px, -py)
                  .rotate_deg(total_angle)
                  .translate(px, py)
                  + self.ax.transData)
            for p in self._seat_patches[sid]:
                p.set_transform(xf)


# ── Render ────────────────────────────────────────────────────────────────────
def render(npy_file, tempo, duration):
    notes = load_brass_voices(npy_file, tempo)
    seats = make_seats()
    seat_notes = route_notes(notes, seats)

    Path(FRAMES_DIR).mkdir(exist_ok=True)
    n_frames = int(math.ceil(duration * FPS))
    log.info(f"[brass] {n_frames} frames ({duration:.1f}s @ {FPS}fps)")

    trb_pitches = notes[notes[:, 5].astype(int) == VOICE_TROMBONE, 1] if len(notes) else np.array([])
    trombone_pitch_range = (float(trb_pitches.min()), float(trb_pitches.max())) \
        if len(trb_pitches) else (2400.0, 5000.0)

    fig, ax = plt.subplots(figsize=(W / DPI, H / DPI), dpi=DPI)
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    ax.set_xlim(0, W)
    ax.set_ylim(0, H)
    ax.set_aspect('equal')
    ax.axis('off')
    fig.patch.set_alpha(0.0)
    ax.patch.set_alpha(0.0)

    scene = BrassScene(fig, ax, seats, trombone_pitch_range=trombone_pitch_range)

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

