#!/usr/bin/env python3
"""
woodwind_section_poc.py — 8 invisible woodwind players on the same stage.

Instruments (matching WreckingCrew's full-mode wood_winds section):
  Seat 0  flute          csound_voice 14  — silver transverse tube
  Seat 1  clarinet       csound_voice 13  — black cylindrical, single reed
  Seat 2  oboe           csound_voice 15  — brown conical, double reed
  Seat 3  oboe           csound_voice 15  — second oboe
  Seat 4  french horn    csound_voice 16  — coiled brass, bell right
  Seat 5  french horn    csound_voice 16  — second horn
  Seat 6  bassoon        csound_voice 12  — tall doubled-over brown tube
  Seat 7  bassoon        csound_voice 12  — second bassoon

Each instrument has:
  • A static silhouette drawn once at setup (polygons / lines / ellipses)
  • An idle-sway transform — a slow sinusoidal rotation (±2–4°) applied to the
    whole instrument, giving the sense of an invisible player breathing and
    shifting weight. Each seat has its own phase offset so they don't all
    move in lockstep.
  • A playing-lean: when a note fires the instrument tips slightly (3–6°)
    toward the mouthpiece/embouchure, then recovers over ~0.5 s.
  • A glow on the instrument body (colour blend toward bright) for the
    duration of the held note.

Voice map (from adaptive_tuning_util.init_voice_time):
  12 = bassoon, 13 = clarinet, 14 = flute, 15 = oboe, 16 = french horn

Usage:
  python woodwind_section_poc.py --npy bwv261_features_array.npy \\
      --tempo 118 --duration 25.1
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
    FancyArrowPatch, Polygon as MplPolygon,
)

import marimba_poc as mp   # W, H, DPI, blended

# ── Constants ──────────────────────────────────────────────────────────────────
FRAMES_DIR = "ww8_frames"
FPS        = 30

# Voice numbers
VOICE_BASSOON  = 12
VOICE_CLARINET = 13
VOICE_FLUTE    = 14
VOICE_OBOE     = 15
VOICE_HORN     = 16
ALL_WW_VOICES  = (VOICE_BASSOON, VOICE_CLARINET, VOICE_FLUTE,
                  VOICE_OBOE, VOICE_HORN)

# Canvas (inherited from marimba_poc)
W, H, DPI = mp.W, mp.H, mp.DPI

# ── Layout ─────────────────────────────────────────────────────────────────────
# Woodwinds occupy x:960-1280 (the open right strip noted in session notes),
# arranged in two rows of 4, y-down convention (matches string_section_poc).
# Back row (smaller/farther): y ~ 210.  Front row (larger/closer): y ~ 360.
# Within each row instruments are spaced 80 px apart.
WW_Y_BACK  = 210
WW_Y_FRONT = 370
WW_X_START = 970
WW_X_STEP  = 80

# scale factors — back row slightly smaller (perspective)
SCALE_BACK  = 0.85
SCALE_FRONT = 1.00

# ── Timing ────────────────────────────────────────────────────────────────────
GLOW_DECAY   = 0.55    # sustained notes glow longer than struck ones
PLAY_LEAN_T  = 0.06    # seconds to reach full lean on note-on
PLAY_RELAX_T = 0.50    # seconds to relax back after note-off

# Idle sway: slow sinusoidal rock, each seat has its own frequency + phase
SWAY_AMP_DEG = 2.8     # ± degrees
SWAY_FREQS   = [0.18, 0.21, 0.19, 0.23, 0.17, 0.22, 0.20, 0.24]  # Hz per seat
SWAY_PHASES  = [0.0,  1.1,  2.3,  0.7,  3.5,  1.8,  4.2,  2.9]   # radians

# Playing lean: extra tilt toward mouthpiece when a note is held
PLAY_LEAN_DEG = {
    'flute':   4.0,   # leans left (transverse, held horizontal)
    'clarinet':3.5,
    'oboe':    3.5,
    'horn':    5.0,   # bell-right horns tip their bell up
    'bassoon': 3.0,
}

# ── Colour palette ─────────────────────────────────────────────────────────────
BG_ALPHA       = 0.0                       # transparent layer

# instrument body colours at rest
CLR_FLUTE      = (0.82, 0.84, 0.88)       # silver
CLR_FLUTE_DK   = (0.55, 0.58, 0.65)
CLR_CLARINET   = (0.14, 0.12, 0.10)       # ebony black
CLR_CLARINET_DK= (0.06, 0.05, 0.04)
CLR_CLARINET_SILVER = (0.70, 0.72, 0.76)  # keywork
CLR_OBOE       = (0.45, 0.28, 0.12)       # grenadilla wood
CLR_OBOE_DK    = (0.28, 0.17, 0.07)
CLR_HORN       = (0.82, 0.68, 0.22)       # unlacquered brass
CLR_HORN_DK    = (0.55, 0.42, 0.10)
CLR_HORN_BELL  = (0.88, 0.74, 0.28)
CLR_BASSOON    = (0.50, 0.32, 0.14)       # maple wood
CLR_BASSOON_DK = (0.30, 0.18, 0.08)
CLR_SILVER_KEY = (0.72, 0.74, 0.78)       # shared keywork colour
CLR_REED       = (0.62, 0.55, 0.35)       # cane reed colour

LABEL_CLR = (0.50, 0.55, 0.65, 1.0)

# glow targets per instrument family
GLOW_CLR = {
    'flute':    (0.92, 0.96, 1.00),
    'clarinet': (0.55, 0.65, 0.90),
    'oboe':     (0.80, 0.65, 0.40),
    'horn':     (1.00, 0.88, 0.40),
    'bassoon':  (0.85, 0.70, 0.45),
}


# ── Seat definitions ──────────────────────────────────────────────────────────
def make_seats():
    """Return list of 8 seat dicts ordered back-left → back-right,
    front-left → front-right, matching the include_sections instrument order:
    flute, clarinet, oboe×2, horn×2, bassoon×2."""
    specs = [
        # name,      kind,       voice,          cx,                          cy,         scale
        ('Fl.',  'flute',    VOICE_FLUTE,    WW_X_START + 0*WW_X_STEP, WW_Y_BACK,  SCALE_BACK),
        ('Cl.',  'clarinet', VOICE_CLARINET, WW_X_START + 1*WW_X_STEP, WW_Y_BACK,  SCALE_BACK),
        ('Ob.I', 'oboe',     VOICE_OBOE,     WW_X_START + 2*WW_X_STEP, WW_Y_BACK,  SCALE_BACK),
        ('Ob.II','oboe',     VOICE_OBOE,     WW_X_START + 3*WW_X_STEP, WW_Y_BACK,  SCALE_BACK),
        ('Hr.I', 'horn',     VOICE_HORN,     WW_X_START + 0*WW_X_STEP, WW_Y_FRONT, SCALE_FRONT),
        ('Hr.II','horn',     VOICE_HORN,     WW_X_START + 1*WW_X_STEP, WW_Y_FRONT, SCALE_FRONT),
        ('Bn.I', 'bassoon',  VOICE_BASSOON,  WW_X_START + 2*WW_X_STEP, WW_Y_FRONT, SCALE_FRONT),
        ('Bn.II','bassoon',  VOICE_BASSOON,  WW_X_START + 3*WW_X_STEP, WW_Y_FRONT, SCALE_FRONT),
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
def load_ww_voices(npy_file, tempo):
    print(f"\n[woodwinds] Loading {npy_file}")
    arr = np.load(npy_file)
    mask = (arr[:, 5] > 0) & (arr[:, 2] > 0) & (arr[:, 14] > 0) & (arr[:, 3] > 0)
    mask &= np.isin(arr[:, 6].astype(int), ALL_WW_VOICES)
    arr  = arr[mask]
    if not len(arr):
        print("  WARNING: no woodwind notes found — section will render silent")
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
    for v in ALL_WW_VOICES:
        n = int((notes[:, 5].astype(int) == v).sum())
        name = {12:'bassoon',13:'clarinet',14:'flute',15:'oboe',16:'horn'}[v]
        print(f"  voice {v} ({name}): {n} notes")
    print(f"  total {len(notes)} notes")
    return notes


def route_notes(notes, seats):
    """Split notes to seats: each seat owns its voice; for voices with
    multiple seats (oboe×2, horn×2, bassoon×2), alternate by onset time
    so consecutive notes interleave across the two seats — simulates
    independent players sharing parts."""
    sets = {s['id']: [] for s in seats}
    # Count seats per voice
    voice_seats = {}
    for s in seats:
        voice_seats.setdefault(s['voice'], []).append(s['id'])

    voice_turn = {v: 0 for v in voice_seats}  # round-robin counter per voice

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
    """Per seat: glow (0..1), is_playing (bool), last_note_off (float)."""
    states = {}
    for s in seats:
        sid    = s['id']
        notes  = seat_note_sets[sid]
        glow   = 0.0
        playing = False
        last_off = -999.0

        for row in notes:
            onset, dur = row[0], row[2]
            dt = t - onset
            note_end = onset + dur

            # Currently sounding
            if onset <= t <= note_end:
                playing = True
                glow = max(glow, 1.0)
            # Decay after note ends
            elif t > note_end:
                decay = (t - note_end) / GLOW_DECAY
                if decay < 1.0:
                    glow = max(glow, 1.0 - decay)
                if note_end > last_off:
                    last_off = note_end

        states[sid] = dict(glow=glow, playing=playing, last_off=last_off)
    return states


# ── Instrument geometry ───────────────────────────────────────────────────────
# Each draw_*() function adds patches to ax and returns a list of all patches
# (body + keys + reed etc.) that belong to this seat, plus a 'pivot' (cx, cy)
# and 'lean_axis' — the direction (in degrees) the instrument leans when played.

def _darken(c, f=0.35):
    return tuple(max(0.0, x - f * x) for x in c)

def _lighten(c, f=0.25):
    return tuple(min(1.0, x + f * (1 - x)) for x in c)


def draw_flute(ax, cx, cy, sc):
    """Silver transverse tube held horizontally.  Left end = embouchure,
    right end = open end.  Key cups along the body."""
    patches = []
    tube_w  = 130 * sc
    tube_h  =  11 * sc
    # Main tube body
    body = Rectangle((cx - tube_w / 2, cy - tube_h / 2), tube_w, tube_h,
                      fc=CLR_FLUTE, ec=CLR_FLUTE_DK, lw=1.0, zorder=5)
    ax.add_patch(body)
    patches.append(body)
    # Left crown cap — rounded end
    cap_l = Ellipse((cx - tube_w / 2, cy), tube_h * 1.15, tube_h * 1.15,
                    fc=CLR_FLUTE_DK, ec='none', zorder=6)
    ax.add_patch(cap_l)
    patches.append(cap_l)
    # Right open end
    cap_r = Ellipse((cx + tube_w / 2, cy), tube_h * 0.9, tube_h,
                    fc=CLR_FLUTE_DK, ec='none', zorder=6)
    ax.add_patch(cap_r)
    patches.append(cap_r)
    # Embouchure plate — oval hole on top, left-of-centre
    emb_x = cx - tube_w * 0.28
    emb = Ellipse((emb_x, cy - tube_h * 0.48), 11 * sc, 7 * sc,
                  fc=CLR_FLUTE_DK, ec=CLR_FLUTE_DK, lw=0.7, zorder=7)
    ax.add_patch(emb)
    patches.append(emb)
    # Key cups — four groups of two pads, top and bottom of tube
    for kx_frac in (-0.02, 0.14, 0.28, 0.42):
        kx = cx + kx_frac * tube_w
        for ky_sign in (-1, 1):
            k = Ellipse((kx, cy + ky_sign * tube_h * 0.52),
                        8 * sc, 5 * sc,
                        fc=CLR_SILVER_KEY, ec=CLR_FLUTE_DK, lw=0.5, zorder=7)
            ax.add_patch(k)
            patches.append(k)
    # Pivot is body centre; lean is CCW (embouchure toward player's left face)
    return patches, (cx, cy), -15.0


def draw_clarinet(ax, cx, cy, sc):
    """Black cylindrical body, mouthpiece + barrel at top, bell at bottom."""
    patches = []
    body_h  = 100 * sc
    body_w  =  10 * sc
    bell_h  =  18 * sc
    barrel_h=  12 * sc
    mpc_h   =  10 * sc

    # Main body
    body = Rectangle((cx - body_w / 2, cy - body_h / 2),
                      body_w, body_h,
                      fc=CLR_CLARINET, ec=CLR_CLARINET_DK, lw=0.7, zorder=5)
    ax.add_patch(body)
    patches.append(body)

    # Barrel (lighter ring between mouthpiece and upper joint)
    barrel_y = cy - body_h / 2 - barrel_h
    barrel = Rectangle((cx - body_w * 0.55, barrel_y),
                        body_w * 1.1, barrel_h,
                        fc=_darken(CLR_CLARINET, 0.2),
                        ec=CLR_CLARINET_DK, lw=0.6, zorder=6)
    ax.add_patch(barrel)
    patches.append(barrel)

    # Mouthpiece + reed
    mpc_y = barrel_y - mpc_h
    mpc = Rectangle((cx - body_w * 0.45, mpc_y),
                     body_w * 0.9, mpc_h,
                     fc=CLR_CLARINET_DK, ec='none', zorder=7)
    ax.add_patch(mpc)
    patches.append(mpc)
    reed = Rectangle((cx - body_w * 0.20, mpc_y + mpc_h * 0.15),
                      body_w * 0.4, mpc_h * 0.85,
                      fc=CLR_REED, ec='none', zorder=8)
    ax.add_patch(reed)
    patches.append(reed)

    # Bell — flared bottom, wider than body
    bell_pts = np.array([
        [cx - body_w / 2, cy + body_h / 2],
        [cx + body_w / 2, cy + body_h / 2],
        [cx + body_w * 1.0, cy + body_h / 2 + bell_h],
        [cx - body_w * 1.0, cy + body_h / 2 + bell_h],
    ])
    bell = MplPolygon(bell_pts, closed=True,
                      fc=CLR_CLARINET, ec=CLR_CLARINET_DK, lw=0.7, zorder=5)
    ax.add_patch(bell)
    patches.append(bell)

    # Key rings — thin silver bands at intervals
    for frac in (0.25, 0.45, 0.65):
        ky = cy - body_h / 2 + frac * body_h
        ring = Rectangle((cx - body_w * 0.6, ky - 1.5 * sc),
                          body_w * 1.2, 3 * sc,
                          fc=CLR_CLARINET_SILVER, ec='none', zorder=6)
        ax.add_patch(ring)
        patches.append(ring)

    # Key pads — 4 small ellipses down the front face
    for frac in (0.15, 0.35, 0.55, 0.75):
        ky = cy - body_h / 2 + frac * body_h
        pad = Ellipse((cx, ky), body_w * 0.7, 5 * sc,
                      fc=CLR_CLARINET_SILVER, ec=CLR_CLARINET_DK, lw=0.4, zorder=7)
        ax.add_patch(pad)
        patches.append(pad)

    return patches, (cx, cy - body_h * 0.1), 4.0   # slight lean forward


def draw_oboe(ax, cx, cy, sc):
    """Grenadilla-wood conical bore; narrower than clarinet, same vertical
    orientation.  Double reed at top (two small flat strips side by side)."""
    patches = []
    body_h  =  90 * sc
    w_top   =   7 * sc    # narrow top (conical)
    w_bot   =  11 * sc    # wider bottom

    # Tapered body using a trapezoid polygon
    body_pts = np.array([
        [cx - w_top / 2, cy - body_h / 2],
        [cx + w_top / 2, cy - body_h / 2],
        [cx + w_bot / 2, cy + body_h / 2],
        [cx - w_bot / 2, cy + body_h / 2],
    ])
    body = MplPolygon(body_pts, closed=True,
                      fc=CLR_OBOE, ec=CLR_OBOE_DK, lw=0.7, zorder=5)
    ax.add_patch(body)
    patches.append(body)

    # Bell rim at bottom
    bell_rim = Ellipse((cx, cy + body_h / 2), w_bot * 1.3, 6 * sc,
                       fc=CLR_OBOE_DK, ec='none', zorder=6)
    ax.add_patch(bell_rim)
    patches.append(bell_rim)

    # Bocal / staple — short curved tube above the body
    bocal_y = cy - body_h / 2 - 6 * sc
    bocal = Rectangle((cx - 2 * sc, bocal_y), 4 * sc, 6 * sc,
                      fc=CLR_SILVER_KEY, ec=CLR_OBOE_DK, lw=0.4, zorder=6)
    ax.add_patch(bocal)
    patches.append(bocal)

    # Double reed — two thin overlapping strips at the very top
    reed_y = bocal_y - 8 * sc
    for dx in (-1.2 * sc, 1.2 * sc):
        r = Rectangle((cx + dx - 1.5 * sc, reed_y), 3 * sc, 8 * sc,
                       fc=CLR_REED, ec=CLR_OBOE_DK, lw=0.3, zorder=8)
        ax.add_patch(r)
        patches.append(r)

    # Key rings + pads
    for frac in (0.20, 0.42, 0.62):
        w = w_top + (w_bot - w_top) * frac
        ky = cy - body_h / 2 + frac * body_h
        ring = Rectangle((cx - w * 0.65, ky - 1.5 * sc),
                          w * 1.3, 3 * sc,
                          fc=CLR_SILVER_KEY, ec='none', zorder=6)
        ax.add_patch(ring)
        patches.append(ring)

    for frac in (0.18, 0.38, 0.58, 0.76):
        w = w_top + (w_bot - w_top) * frac
        ky = cy - body_h / 2 + frac * body_h
        pad = Ellipse((cx, ky), w * 0.8, 4 * sc,
                      fc=CLR_SILVER_KEY, ec=CLR_OBOE_DK, lw=0.4, zorder=7)
        ax.add_patch(pad)
        patches.append(pad)

    return patches, (cx, cy), 3.5


def draw_horn(ax, cx, cy, sc):
    """French horn — coiled brass tube.  Nested arcs forming the
    characteristic circular coil, with the bell opening facing right.
    Sized to fit within an 80 px seat column."""
    patches = []
    # Keep the coil tight so two horns side-by-side don't overlap.
    r_outer = 28 * sc
    r_inner = 14 * sc
    lw_tube  = 4.5 * sc

    # Outer coil arc — most of a circle, gap at right (bell exit)
    coil_o = Arc((cx, cy), r_outer * 2, r_outer * 2,
                 angle=0, theta1=20, theta2=320,
                 color=CLR_HORN, lw=lw_tube, zorder=5)
    ax.add_patch(coil_o)
    patches.append(coil_o)

    # Middle coil
    r_mid = (r_outer + r_inner) / 2
    coil_m = Arc((cx, cy), r_mid * 2, r_mid * 2,
                 angle=0, theta1=15, theta2=330,
                 color=CLR_HORN, lw=lw_tube * 0.75, zorder=5)
    ax.add_patch(coil_m)
    patches.append(coil_m)

    # Inner coil arc
    coil_i = Arc((cx, cy), r_inner * 2, r_inner * 2,
                 angle=0, theta1=10, theta2=340,
                 color=CLR_HORN_DK, lw=lw_tube * 0.55, zorder=5)
    ax.add_patch(coil_i)
    patches.append(coil_i)

    # Bell — flared opening to the right
    bell_r = r_outer * 1.22
    bell = Arc((cx, cy), bell_r * 2, bell_r * 1.4,
               angle=0, theta1=-28, theta2=28,
               color=CLR_HORN_BELL, lw=lw_tube * 1.5, zorder=6)
    ax.add_patch(bell)
    patches.append(bell)

    # Mouthpiece entering from upper-left
    mpc_x = cx - r_outer - 6 * sc
    mpc = Rectangle((mpc_x, cy - 1.6 * sc), 8 * sc, 3.2 * sc,
                    fc=CLR_SILVER_KEY, ec=CLR_HORN_DK, lw=0.5, zorder=6)
    ax.add_patch(mpc)
    patches.append(mpc)

    # Rotary valves — 3 small rectangles clustered inside the coil
    for vy_off in (-6 * sc, 0, 6 * sc):
        vx = cx - r_inner * 0.45 - 3 * sc
        v = Rectangle((vx, cy + vy_off - 2.5 * sc), 6 * sc, 5 * sc,
                       fc=CLR_HORN_DK, ec=CLR_HORN, lw=0.5, zorder=7)
        ax.add_patch(v)
        patches.append(v)

    # Pivot at centre of coil; lean tips bell upward (CCW)
    return patches, (cx, cy), -6.0


def draw_bassoon(ax, cx, cy, sc):
    """Bassoon — tall doubled-over wooden tube.  Left tube (wing + butt)
    descends from the top; right tube (long + bell joint) rises from the
    bottom U-bend; bocal curves up-left from the top of the left tube."""
    patches = []

    tube_w  = 10 * sc
    h_down  = 85 * sc   # descending (left) tube length
    h_up    = 80 * sc   # ascending (right) tube length
    sep     = 16 * sc   # horizontal gap between the two tubes
    u_r     = sep / 2   # U-bend radius

    # Left tube (wing + butt joint) — descends from cy - h_down/2 downward
    lx = cx - sep / 2
    rx = cx + sep / 2
    top_y  = cy - h_down / 2
    bend_y = top_y + h_down      # bottom of left tube = top of U

    ltube = Rectangle((lx - tube_w / 2, top_y), tube_w, h_down,
                       fc=CLR_BASSOON, ec=CLR_BASSOON_DK, lw=0.7, zorder=5)
    ax.add_patch(ltube)
    patches.append(ltube)

    # Right tube (long + bell joint) — ascends from bend_y upward
    rtube_top = bend_y - h_up
    rtube = Rectangle((rx - tube_w / 2, rtube_top), tube_w, h_up,
                       fc=CLR_BASSOON, ec=CLR_BASSOON_DK, lw=0.7, zorder=5)
    ax.add_patch(rtube)
    patches.append(rtube)

    # U-bend at the bottom
    ubend = Arc((cx, bend_y), sep + tube_w, (sep + tube_w) * 0.85,
                angle=0, theta1=180, theta2=360,
                color=CLR_BASSOON_DK, lw=tube_w * 1.5, zorder=5)
    ax.add_patch(ubend)
    patches.append(ubend)

    # Bell at top of right tube — slightly flared
    bell = Ellipse((rx, rtube_top), tube_w * 1.6, 8 * sc,
                   fc=CLR_BASSOON_DK, ec=CLR_BASSOON_DK, lw=0.5, zorder=6)
    ax.add_patch(bell)
    patches.append(bell)

    # Bocal — thin curved metal crook at top of left tube, bends left.
    # Drawn as a filled polygon strip (not ax.plot) so it joins the
    # patches list and receives the per-frame affine sway transform.
    bocal_base_y = top_y
    boc_hw = 2.2 * sc   # half-width of the bocal strip
    # Three centreline control points approximating a gentle J-curve
    boc_cx = np.array([lx,          lx - 5 * sc,   lx - 12 * sc])
    boc_cy = np.array([bocal_base_y, bocal_base_y - 9 * sc, bocal_base_y - 14 * sc])
    # Build a thick polyline polygon: left edge forward, right edge back
    boc_left  = np.column_stack([boc_cx - boc_hw, boc_cy])
    boc_right = np.column_stack([boc_cx + boc_hw, boc_cy])
    boc_poly_pts = np.vstack([boc_left, boc_right[::-1]])
    bocal = MplPolygon(boc_poly_pts, closed=True,
                       fc=CLR_SILVER_KEY, ec=CLR_OBOE_DK, lw=0.4, zorder=7)
    ax.add_patch(bocal)
    patches.append(bocal)
    # Small reed at bocal tip
    reed_x = boc_cx[-1]
    reed_y = boc_cy[-1]
    reed = Ellipse((reed_x, reed_y), 5 * sc, 3 * sc,
                   fc=CLR_REED, ec=CLR_BASSOON_DK, lw=0.4, zorder=8)
    ax.add_patch(reed)
    patches.append(reed)

    # Key rings on both tubes
    for frac in (0.25, 0.55, 0.75):
        ky = top_y + frac * h_down
        ring = Rectangle((lx - tube_w * 0.65, ky - 1.5 * sc),
                          tube_w * 1.3, 3 * sc,
                          fc=CLR_SILVER_KEY, ec='none', zorder=6)
        ax.add_patch(ring)
        patches.append(ring)

    for frac in (0.20, 0.50, 0.72):
        ky = rtube_top + frac * h_up
        ring = Rectangle((rx - tube_w * 0.65, ky - 1.5 * sc),
                          tube_w * 1.3, 3 * sc,
                          fc=CLR_SILVER_KEY, ec='none', zorder=6)
        ax.add_patch(ring)
        patches.append(ring)

    # Pivot at centre of instrument; lean is forward (CW)
    return patches, (cx, cy), 3.0


# ── Scene class ───────────────────────────────────────────────────────────────

class WoodwindScene:
    """Pre-builds all instrument patches; applies per-seat affine transform
    each frame for sway + playing lean."""

    def __init__(self, fig, ax, seats):
        self.fig   = fig
        self.ax    = ax
        self.seats = seats
        self._seat_patches  = {}   # sid → list of Patch
        self._seat_pivot    = {}   # sid → (px, py) in data coords
        self._seat_lean_dir = {}   # sid → degrees, direction of playing lean
        self._seat_xforms   = {}   # sid → current Affine2D (updated each frame)
        self._body_patches  = {}   # sid → the main body patch (for glow colour)

        draw_fn = {
            'flute':    draw_flute,
            'clarinet': draw_clarinet,
            'oboe':     draw_oboe,
            'horn':     draw_horn,
            'bassoon':  draw_bassoon,
        }

        for s in seats:
            fn = draw_fn[s['kind']]
            patches, pivot, lean_dir = fn(ax, s['cx'], s['cy'], s['sc'])

            self._seat_patches[s['id']]   = patches
            self._seat_pivot[s['id']]     = pivot
            self._seat_lean_dir[s['id']]  = lean_dir
            self._body_patches[s['id']]   = patches[0]  # first patch = main body

            # Apply initial identity transform (will be updated each frame)
            xf = mtransforms.Affine2D() + ax.transData
            for p in patches:
                p.set_transform(xf)
            self._seat_xforms[s['id']] = xf

            # Seat label below instrument
            ax.text(s['cx'], s['cy'] + 55 * s['sc'], s['name'],
                    ha='center', va='top', fontsize=7.5,
                    color=LABEL_CLR, zorder=12)

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

            # ── Sway: slow sinusoidal idle rock ──────────────────────────────
            sway_angle = (SWAY_AMP_DEG
                          * math.sin(2 * math.pi * s['sway_freq'] * t
                                     + s['sway_phase']))

            # ── Playing lean ─────────────────────────────────────────────────
            # Blend toward lean_max while playing; ease back after note-off
            if playing:
                lean_angle = lean_max
            else:
                dt_off = t - last_off
                if dt_off < PLAY_RELAX_T and dt_off >= 0:
                    phase = dt_off / PLAY_RELAX_T
                    # smoothstep ease-out
                    phase = phase * phase * (3.0 - 2.0 * phase)
                    lean_angle = lean_max * (1.0 - phase)
                else:
                    lean_angle = 0.0

            total_angle = sway_angle + lean_angle * math.copysign(1, lean_dir)

            # ── Glow: tint body colour ────────────────────────────────────────
            if glow > 0.02:
                base_c = self._get_base_color(s['kind'])
                tint   = GLOW_CLR[s['kind']]
                blended = tuple(
                    base_c[i] + glow * (tint[i] - base_c[i])
                    for i in range(3)
                )
                self._body_patches[sid].set_facecolor(blended)
            else:
                self._body_patches[sid].set_facecolor(
                    self._get_base_color(s['kind']))

            # ── Apply combined affine transform ───────────────────────────────
            xf = (mtransforms.Affine2D()
                  .translate(-px, -py)
                  .rotate_deg(total_angle)
                  .translate(px, py)
                  + self.ax.transData)
            for p in self._seat_patches[sid]:
                p.set_transform(xf)

    @staticmethod
    def _get_base_color(kind):
        return {
            'flute':    CLR_FLUTE,
            'clarinet': CLR_CLARINET,
            'oboe':     CLR_OBOE,
            'horn':     CLR_HORN,
            'bassoon':  CLR_BASSOON,
        }[kind]


# ── Render ────────────────────────────────────────────────────────────────────

def render(npy_file, tempo, duration):
    notes = load_ww_voices(npy_file, tempo)
    seats = make_seats()
    seat_notes = route_notes(notes, seats)

    Path(FRAMES_DIR).mkdir(exist_ok=True)
    n_frames = int(math.ceil(duration * FPS))
    print(f"[woodwinds] {n_frames} frames ({duration:.1f}s @ {FPS}fps)")

    fig, ax = plt.subplots(figsize=(W / DPI, H / DPI), dpi=DPI)
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    ax.set_xlim(0, W)
    ax.set_ylim(0, H)
    ax.set_aspect('equal')
    ax.axis('off')
    fig.patch.set_alpha(0.0)
    ax.patch.set_alpha(0.0)

    scene = WoodwindScene(fig, ax, seats)

    for fi in range(n_frames):
        t = fi / FPS
        states = compute_state(t, seat_notes, seats)
        scene.update(t, states)
        fig.savefig(f"{FRAMES_DIR}/frame_{fi:06d}.png",
                    dpi=DPI, transparent=True)
        if fi % 200 == 0:
            print(f"  {fi}/{n_frames}  t={t:.1f}s", flush=True)

    plt.close(fig)
    print(f"  Done — {n_frames} frames written to {FRAMES_DIR}/")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--npy',      required=True)
    parser.add_argument('--tempo',    type=float, required=True)
    parser.add_argument('--duration', type=float, required=True)
    args = parser.parse_args()
    render(args.npy, args.tempo, args.duration)


if __name__ == '__main__':
    main()
