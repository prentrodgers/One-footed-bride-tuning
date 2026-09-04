#!/usr/bin/env python3
"""
blender_stage.py — prototype single shared 3D scene that places the three
existing Blender sections (marimba, pizzicato strings, bass) on ONE stage,
under one camera/floor.

The three section modules were each authored at their own arbitrary world
scale and centred on the origin (marimba ~20 units wide, pizz ~2.4, bass
~1.7), each with its own floor/camera/lights baked into a build_stage().
This script does NOT call those build_stage()s. Instead it:

  1. builds each section's *instruments* into the shared scene,
  2. collects the objects that build created,
  3. parents them under one Empty per section, and
  4. scales + translates that Empty so the section is normalised to a
     common on-stage height and dropped into its own non-overlapping slot,
     bottom sitting on the z=0 floor.

Layout concept — real orchestra staging: the wide, low marimba spans the
BACK of the stage; the taller string + bass sections sit in FRONT of it,
side by side. Uses the depth (Y) axis, which is the whole reason for going
3D in the first place.

This is a STATIC layout prototype (no per-frame animation yet) — its only
job is to prove the sections can share one stage without overlapping and
still read clearly. Animation wiring comes once the layout is agreed.

    blender --background --python blender_stage.py -- --out stage_proto.png
"""
import os
import argparse
import math
import random
import sys
import time
from pathlib import Path

import bpy
import mathutils
import numpy as np

REPO_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_DIR))

import blender_marimba_poc as marimba
import blender_pizzicato_poc as pizz
import blender_bass_section_poc as bass
import blender_finger_piano_poc as fingerpiano
import blender_woodwind_poc as woodwind
import blender_brass_poc as brass
import blender_bowed_strings_poc as bowedstrings
import blender_melody_poc as melody
import blender_conductor_poc as conductor
import pitch_bucket as pb
import string_length as sl

FPS = 30


# Each section is placed by a DIRECT scale + a floor position (cx, cy) — no
# auto-fit. A bigger `scale` makes a section genuinely bigger on screen,
# because the camera below is FIXED and never pulls back to re-fit the stage.
# cy is depth: larger = further back = higher up the frame. Tune these with
# the stage_layout_editor artifact, which writes exactly this block.
SECTIONS = {
    "pizz":          dict(cx=-16.0, cy=15.0, scale=6.60),   # +20%
    "marimba":       dict(cx=11.5,  cy=4.0,  scale=0.90),
    "bass":          dict(cx=-2.7,  cy=3.7,  scale=4.50),   # guitar side sits just left of the marimba
    "finger_piano":  dict(cx=-15.3, cy=4.5,  scale=8.00),   # nudged right to follow the bass finger piano
    "woodwind":      dict(cx=-10.0, cy=-7.0, scale=1.80),
    # cx is larger than the marimba's 11.5 because the brass sits further back:
    # at that depth it takes more X to land on the same spot on screen.
    "brass":         dict(cx=14.7,  cy=16.0, scale=2.25),   # back row, directly above the marimba
    "bowed_strings": dict(cx=1.0,   cy=15.0, scale=5.60),   # +40%
    "melody":        dict(cx=10.0,  cy=-7.0, scale=1.80),
    "conductor":     dict(cx=0.0,   cy=-6.5, scale=1.50),
}

# Fixed camera — shared verbatim with the stage_layout_editor artifact so its
# preview matches the render. (position, look-at target, focal length mm,
# sensor width mm.)
CAM_POS = (0.0, -36.0, 18.0)
CAM_TARGET = (0.0, 4.0, 3.0)
CAM_LENS = 38.0
CAM_SENSOR = 36.0

# ── Camera cue sheet ────────────────────────────────────────────────────────
# (time_in_seconds, target[, move_seconds]) in ascending time order.
#
#   time         seconds (90) or "m:ss" ("1:30", "1:30.5") — activity.png is
#                labelled in m:ss, so you can copy times straight off it.
#   target       "wide", a section key, a player key ("brass.tuba"), or a
#                tuple of any of those framed together as one shot.
#   move_seconds 0 (the default) CUTS to the shot; >0 eases to it over that
#                many seconds, STARTING at the cue time.
#
# ("overhead", a, b) is the one target form that breaks the fixed viewing
# angle: it looks down on `a` from a high oblique and travels to over `b`.
# Its restrictions:
#
#   * exactly two names after the marker — ("overhead", a, b, c) raises, and a
#     single name has nothing to travel to. Each must be one plain target
#     name; neither may itself be a tuple.
#   * move_seconds does NOT drive the travel, only the ease-in from the
#     previous shot. The travel always spans the shot's whole hold, so the gap
#     to the NEXT cue sets how slow the move is — put the next cue 20s later
#     for a slow drift, 4s later and it's a swoop.
#   * as the last cue in the sheet there is no next cue to measure against, so
#     it falls back to sum(CAMERA_HOLD) * 2 seconds of travel.
#
# Run blender_stage.py with --list-targets to print every name available.
#
# Times are wall-clock against one specific render. Re-running WreckingCrew
# re-randomises chord repeats and arpeggiation, so a cue sheet is only valid
# for the audio it was authored against.

# rewritten 8/1/26 based on activity.png on bwv256 mp3 & npy
# All changes are cuts unless explicitly marked for a pan (eased over t, X, 2.5)
# times must be in "m:ss" format - with quotes!
# An overhead, and the cue AFTER it setting how slowly it travels:
#     ("2:10", ("overhead", "marimba", "bass.guitar")),
#     ("2:30", "bowed_strings"),

# this list is from bwv256 from 8/1/26, subsequently lost. 
# CAMERA_CUES = [
#     ("0:00", "wide"),
#     ("0:06", ("pizz", "finger_piano")),
#     ("0:30", "marimba", 4),
#     ("0:45", "bass", 4),
#     ("1:00", ("pizz", "finger_piano"), 5),
#     ("1:25", 'marimba', 4),
#     ("1:45", "bass", 4),
#     ("2:10", ("overhead", "marimba", "bass.guitar")),
#     ("2:30", "melody"),
#     ("2:45", "pizz"),
#     ("3:00", "marimba"),
#     ("3:15", "pizz"),
#     ("3:30", "melody", 5),
#     ("3:50", "bass", 5),
#     ("4:00", "woodwind"),
#     ("4:15", ("overhead", "marimba", "bass.guitar")),
#     ("4:30", "melody", 5),
#     ("4:45", "woodwind", 4),
#     ("5:00", "brass", 5),
#     ("5:15", ("marimba", "melody")),
#     ("5:30", "brass", 4),
#     ("5:40", "pizz", 4),
#     ("5:50", "bass"),
#     ("6:00", "pizz", 4),
#     ("6:15", "marimba"),
#     ("6:30", "pizz", 5),
#     ("6:45", ("overhead", "woodwind", "finger_piano")),
#     ("7:00", "wide")
# ]

# bwv257 — Uploads/ball9-t57c_lm19_r1.12_df5_t3_d05_07_t106.{npy,mp3}
# tempo 106, 302.4s (5:02) = 9072 frames. Authored 8/8/26 against activity_bwv257.png.
#
# Dense and near-continuous — almost everything plays the whole way, so
# there are few entries to cut ON. Leans on shot-size variety instead, plus
# the one real hole: bowed_strings drop out 2:50-3:15, which is where the
# overhead goes.
# bwv256 — Uploads/ball9-t56d_lm17_r1.25_df5_t1_d04_46_t104.{npy,mp3}
# tempo 104, 281.7s (4:42) = 8451 frames.  Rebuilt 9/1/26 with the
# instruments at 37 positions.
#
# NOT hand-authored: the bwv256 sheet from 8/1/26 was lost (see the note
# above), and the sheet below it belongs to bwv257 — a different piece at a
# different tempo, whose cuts would land nowhere in particular here.  So the
# shots come from CAMERA_AUTOGEN instead, which is gated on the volume data
# from this render's own npy: the generator will not cut to a player that
# is not sounding.  Only the opening wide is by hand.
CAMERA_CUES = [
    ("0:00", "wide"),
]

# The bwv257 sheet, kept for when that chorale is rendered again:
# CAMERA_CUES = [
#     ("0:00", "wide"),
#     ("0:12", ("pizz", "bass")),
#     ("0:26", "marimba", 4),
#     ("0:40", "bowed_strings"),
#     ("0:52", "brass"),
#     ("1:06", "bass.guitar"),
#     ("1:18", "finger_piano"),
#     ("1:30", "wide"),
#     ("1:42", "melody.trumpet"),
#     ("1:56", "marimba", 3),
#     ("2:10", ("pizz", "finger_piano")),
#     ("2:24", "woodwind"),
#     ("2:38", "melody"),
#     ("2:52", ("overhead", "marimba", "bass.guitar")),
#     ("3:14", "bowed_strings"),
#     ("3:28", "brass", 3),
#     ("3:42", "melody.trumpet"),
#     ("3:56", "marimba", 4),
#     ("4:10", ("pizz", "bass")),
#     ("4:24", "woodwind", 3),
#     ("4:38", "bass.guitar"),
#     ("4:50", "wide", 3),
# ]

# bwv259 — Uploads/ball9-t59c_lm19_r1.12_df2_t3_d05_21_t088.{npy,mp3}
# tempo 88, 313.2s (5:13) = 9396 frames. Authored 8/8/26 against activity_bwv259.png.
#
# 
# CAMERA_CUES = [
#     ("0:00", "wide"),
#     ("0:12", "woodwind", 4),
#     ("0:26", "brass"),
#     ("0:40", ("marimba", "bass")),
#     ("0:56", "brass", 3),
#     ("1:10", "melody.vibraphone"),
#     ("1:22", "woodwind"),
#     ("1:38", "melody.trumpet"),
#     ("1:52", ("pizz", "marimba")),
#     ("2:06", "wide"),
#     ("2:20", "woodwind", 3),
#     ("2:34", "brass"),
#     ("2:48", "melody"),
#     ("3:02", "bowed_strings", 3),
#     ("3:16", "bass.guitar"),
#     ("3:28", "brass", 3),
#     ("3:42", "melody.trumpet"),
#     ("3:54", ("overhead", "marimba", "finger_piano")),
#     ("4:14", "pizz"),
#     ("4:28", "brass"),
#     ("4:42", "bowed_strings"),
#     ("4:56", "wide", 4),
# ]

# bwv261 — Uploads/ball9-t61c_lm19_r1.25_df4_t3_d08_04_t118.{npy,mp3}
# tempo 118, 480.6s (8:00) = 14418 frames. Authored 8/8/26 against activity_bwv261.png.
#
# Long, so it needs the most shots. Two big tutti returns at 1:55 and
# 4:00, brass running unbroken from 5:30, and bowed_strings absent
# 5:55-7:15 — the longest hole in any of these pieces. The overhead sits
# at 3:36 where marimba is thin and the guitar and finger piano carry.
# CAMERA_CUES = [
#     ("0:00", "wide"),
#     ("0:12", ("pizz", "bass")),
#     ("0:24", "bowed_strings", 4),
#     ("0:38", "melody.trumpet"),
#     ("0:52", "bass.guitar"),
#     ("1:04", "brass", 3),
#     ("1:18", "marimba", 4),
#     ("1:34", ("pizz", "finger_piano")),
#     ("1:48", "wide"),
#     ("1:58", "melody"),
#     ("2:12", "bowed_strings", 3),
#     ("2:26", "brass"),
#     ("2:40", "marimba", 4),
#     ("2:54", "finger_piano"),
#     ("3:08", "pizz"),
#     ("3:22", "bass.guitar"),
#     ("3:36", ("overhead", "bass.guitar", "finger_piano")),
#     ("3:58", "wide"),
#     ("4:12", "woodwind", 4),
#     ("4:26", "brass"),
#     ("4:40", ("pizz", "marimba")),
#     ("4:54", "melody"),
#     ("5:08", "bowed_strings", 3),
#     ("5:22", "bass"),
#     ("5:34", "brass", 3),
#     ("5:48", "marimba"),
#     ("6:02", "pizz"),
#     ("6:16", "finger_piano"),
#     ("6:30", ("marimba", "melody")),
#     ("6:44", "brass", 3),
#     ("6:58", "pizz"),
#     ("7:12", "woodwind"),
#     ("7:26", "bowed_strings", 4),
#     ("7:40", "wide", 4),
# ]
# bwv258 — Uploads/ball9-t58c_lm17_r1.75_df3_t3_d04_02_t092.{npy,mp3}
# tempo 92, 238.2s (3:58). Authored 8/7/26 against activity_bwv258.png.
# CAMERA_CUES = [
#     ("0:00", "wide"),
#     ("0:12", "bowed_strings", 4),
#     ("0:26", ("pizz", "bass")),
#     ("0:38", "finger_piano"),
#     ("0:50", "melody.trumpet"),
#     ("1:04", "bowed_strings", 3),
#     ("1:18", "bass.guitar"),
#     ("1:30", ("pizz", "finger_piano")),
#     ("1:43", "wide"),
#     ("1:52", "brass"),
#     ("2:02", "bass", 3),
#     ("2:10", "wide"),
#     ("2:18", "melody"),
#     ("2:28", "woodwind", 3),
#     ("2:38", "marimba", 4),
#     ("2:52", ("overhead", "marimba", "bass.guitar")),
#     ("3:12", "bowed_strings"),
#     ("3:26", "brass", 3),
#     ("3:40", "wide", 4),
# ]
# Time ranges the shot generator fills in around the hand-authored cues:
# (start_s, end_s, seed). Deterministic per seed, so a render repeats exactly.
# Hand cues always win — generated shots are dropped near them.
# (start, end, seed) ranges the generator fills.  Starts at 0:10 so the
# opening wide holds first; generated shots run 10-15s each.
CAMERA_AUTOGEN = [(10.0, 281.7, 7)]
    # CAMERA_AUTOGEN = [
    # (50.0, 470.0, 7),
    # ]

# ── Backdrop ────────────────────────────────────────────────────────────────
# A cyclorama standing behind the orchestra, emissive so it reads as a lit
# screen rather than a wall we have to light. It fades through these colours,
# BACKDROP_HOLD seconds each, looping — the slow colour programme is what keeps
# an hour of the same stage from going stale.
BACKDROP_Y = 32.0        # depth: well behind the brass, whose bbox ends at 20.9
BACKDROP_W = 120.0
BACKDROP_H = 18.0
BACKDROP_COLORS = [
    (0.42, 0.02, 0.05),   # deep red
    (0.78, 0.32, 0.02),   # amber
    (0.60, 0.48, 0.03),   # yellow
    (0.30, 0.02, 0.10),   # crimson
    (0.05, 0.09, 0.32),   # deep blue
    (0.38, 0.03, 0.22),   # magenta-red
]
BACKDROP_HOLD = 150.0    # seconds per colour (2.5 min)
BACKDROP_STRENGTH = 1.1

# ── Colour wash ─────────────────────────────────────────────────────────────
# Contrasting coloured spots. These DO cast shadows — two differently coloured
# sources from different sides is the whole mechanism behind coloured shadows,
# where one light is blocked and only the other's colour lands.
# (name, colour, energy W, position, aim point, cone degrees, casts shadow)
WASH_SPOTS = [
    ("WashL", (1.00, 0.12, 0.35), 170000.0, (-46.0, -22.0, 30.0), (-8.0, 8.0, 2.0), 55.0, True),
    ("WashR", (0.10, 0.60, 1.00), 170000.0, (46.0, -22.0, 30.0), (8.0, 8.0, 2.0), 55.0, True),
    ("WashB", (1.00, 0.62, 0.15), 110000.0, (0.0, 34.0, 26.0), (0.0, 10.0, 2.0), 60.0, False),
]

# ── Key / fill ──────────────────────────────────────────────────────────────
# (name, colour, energy, pitch°, yaw°, angular diameter°, casts shadow).
# pitch is the tilt off straight-down: positive throws the light away from the
# camera (source in FRONT of the stage), negative throws it toward the camera
# (source BEHIND). yaw swings that around; negative = source on stage left.
#
#   Key  — warm, high, front-left. Does the modelling and the one shadow.
#   Fill — cool, low, front-right. Lifts the shadow side so instruments stop
#          going to black; deliberately dim so it doesn't flatten the key out.
SUNS = [
    ("KeyLight",  (1.00, 0.93, 0.80), 1.1,  50.0, -25.0, 4.0, True),
    ("FillLight", (0.72, 0.80, 1.00), 0.22, 65.0,  35.0, 8.0, False),
]

# ── Follow spot ─────────────────────────────────────────────────────────────
# Rides the cue sheet: whatever the camera is on gets picked out of the wash.
# Snaps on a cut, travels on a move, exactly like the camera.
FOLLOW_OFFSET = (0.0, -14.0, 18.0)    # position relative to the shot's centre
FOLLOW_ENERGY = 15000.0
FOLLOW_COLOR = (1.00, 0.95, 0.88)     # warm white, to read against the wash
FOLLOW_CONE_MARGIN = 1.4              # cone spread relative to the shot's size

# How often the generator should reach for each target. The instruments worth
# watching are the ones whose MOVEMENT causes the sound — a drawn bow, a
# plucking finger, a struck bar, a plucked tine. A wind body can only glow and
# sway, so it says nothing about why you are hearing what you hear. Weights
# apply to a section and to every player in it; an exact name wins over its
# section, which is how the vibraphone is singled out of the melody row.
# What a section has to SHOW, which is not the same as how loud it is. The
# generator weights its picks by this, so a 3.0 section comes up three times
# as often as a 1.0 one.
#
# brass and woodwind were 1.0 while all they did was glow and sway. Now that
# their tone holes, pistons and slide spell out the pitch class (see
# blender_woodwind_poc.hole_coverage and blender_brass_poc.valve_throws),
# they have as much to say as anything except the mallet instruments, and
# they are raised to 2.0 to match.
VISUAL_INTEREST = {
    "pizz": 3.0,            # plucking and martele bowing
    "bowed_strings": 3.0,   # sustained bows travelling the string
    "marimba": 3.0,         # mallets striking, bars flexing
    "bass": 3.0,            # baritone guitar + finger-piano tines
    "finger_piano": 3.0,
    "melody.vibraphone": 3.0,
    "brass": 2.0,           # pistons and the trombone slide, since 9/2/26
    "woodwind": 2.0,        # nine tone holes apiece, since 9/2/26
}
DEFAULT_INTEREST = 1.0

CAMERA_HOLD = (10.0, 15.0)   # generated shot length range, seconds
CAMERA_MARGIN = 1.25         # framing headroom: 1.0 = target exactly fills frame
CAMERA_MOVE_CHANCE = 0.25    # fraction of generated transitions that move, not cut
CAMERA_MOVE_T = 2.5          # seconds for a generated move


def _pick_eevee_engine():
    """Pick a valid EEVEE render-engine enum for whatever Blender is running.
    The scenes were authored on 5.1.2 (engine 'BLENDER_EEVEE'), but the render
    pod may run 5.2 LTS or later where EEVEE has been renamed before (4.x used
    'BLENDER_EEVEE_NEXT'). Try the known names in order and use the first the
    running build actually offers, so a Blender version bump doesn't break the
    render with a cryptic enum error."""
    try:
        items = bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items
        available = {e.identifier for e in items}
    except Exception:
        available = set()
    for name in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
        if name in available:
            return name
    # Last resort: whatever EEVEE-ish engine exists, else leave the default.
    for e in available:
        if 'EEVEE' in e:
            return e
    return bpy.context.scene.render.engine


def _configure_engine(scene, args):
    """The render engine enum for this run, with Cycles set up for the Intel
    GPUs when asked for. Fails loudly rather than falling back to the CPU:
    a CPU Cycles render on the farm would run for days without saying why."""
    if args.engine != "cycles":
        return _pick_eevee_engine()
    prefs = bpy.context.preferences.addons["cycles"].preferences
    try:
        prefs.compute_device_type = "ONEAPI"
    except TypeError:
        raise SystemExit("[stage] this Blender has no oneAPI Cycles backend")
    prefs.refresh_devices()
    if hasattr(prefs, "use_oneapirt"):
        prefs.use_oneapirt = bool(args.cycles_hw_rt)
    chosen = []
    for d in prefs.devices:
        d.use = d.type == "ONEAPI" and args.gpu_name in d.name
        if d.use:
            chosen.append(d.name)
    if not chosen:
        seen = [f"{d.type}:{d.name}" for d in prefs.devices]
        raise SystemExit(f"[stage] no oneAPI GPU matching {args.gpu_name!r} "
                         f"— Cycles saw {seen}. Is the Level Zero stack "
                         f"installed (python-music:0.10) and /dev/dri passed in?")
    scene.cycles.device = "GPU"
    scene.cycles.samples = args.samples
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = "OPENIMAGEDENOISE"
    print(f"[stage] Cycles on {chosen}, {args.samples} samples, "
          f"{'hardware' if args.cycles_hw_rt else 'software'} ray tracing")
    return "CYCLES"


# ── the studio look ──────────────────────────────────────────────────────────
# What made the stage read as tiles rather than instruments, and what this
# pass does about each, without touching the nine section modules:
#
#   * every wind and brass body is SELF-LIT: make_body_material wires the
#     object colour into Emission at 0.45, so instruments glow faintly from
#     inside and the key light's modelling is flattened. Cut to a trace.
#   * strings and bass tines are pure Emission - no diffuse, no specular, no
#     shadow. Rebuilt as metal that keeps its per-object colour and a little
#     of its glow, the same fix the marimba bars had.
#   * wood has no varnish. Principled's Coat is a varnish layer.
#   * brass is smooth metal with nothing to reflect. Give it anisotropy and,
#     below, a world that is not black.
#   * the floor is near-black and fully matte; a stage floor is a dark
#     semi-gloss, and its reflections are half of what says "stage".
#   * the backdrop's emission is what LIGHTS the scene under Cycles, which
#     is right, but at 1.1 it blows out. Halved.
#   * three large area lights wrap the instruments in soft light; the sun and
#     wash rig stays, turned down, since bounced light now does some of its
#     work.
#   * 'Standard' clips highlights like a phone; AgX rolls them off like film.
#
# Everything here is engine-agnostic, so EEVEE benefits too, but it is
# tuned by eye under Cycles.
LOOK_BODY_EMISSION = 0.08
LOOK_WASH_SCALE = 0.55
LOOK_AREA_LIGHTS = [
    # name, colour, watts, size(m), position, aim
    # First pass was 60/22/40 kW and blew the floor out into a light source;
    # half that keeps the wrap and lets the washes still colour the picture.
    ("KeyArea",  (1.00, 0.95, 0.86), 30000.0, 12.0, (-22.0, -30.0, 26.0), (0.0, 6.0, 2.0)),
    ("FillArea", (0.82, 0.88, 1.00), 10000.0, 16.0, ( 26.0, -26.0, 16.0), (0.0, 6.0, 2.0)),
    ("RimArea",  (1.00, 0.85, 0.70), 18000.0, 14.0, (  6.0,  30.0, 20.0), (0.0, 4.0, 2.0)),
]


def _principled(mat):
    if not mat.use_nodes:
        return None
    for n in mat.node_tree.nodes:
        if n.bl_idname == "ShaderNodeBsdfPrincipled":
            return n
    return None


def _set(bsdf, name, value):
    """Set a Principled input if this Blender has it under that name."""
    sock = bsdf.inputs.get(name)
    if sock is not None and not sock.is_linked:
        sock.default_value = value
        return True
    return False


def _rebuild_emissive_as_metal(mat):
    """A material whose surface is a bare Emission fed by Object Info (the
    strings, the bass tines) becomes Principled metal with the same
    per-object colour and a trace of the glow, so it is lit and shadowed."""
    nt = mat.node_tree
    out = next((n for n in nt.nodes if n.bl_idname == "ShaderNodeOutputMaterial"), None)
    emis = next((n for n in nt.nodes if n.bl_idname == "ShaderNodeEmission"), None)
    info = next((n for n in nt.nodes if n.bl_idname == "ShaderNodeObjectInfo"), None)
    if not (out and emis and info):
        return False
    strength = emis.inputs["Strength"].default_value
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(info.outputs["Color"], bsdf.inputs["Base Color"])
    _set(bsdf, "Metallic", 1.0)
    _set(bsdf, "Roughness", 0.38)
    if bsdf.inputs.get("Emission Color") is not None:
        nt.links.new(info.outputs["Color"], bsdf.inputs["Emission Color"])
        _set(bsdf, "Emission Strength", min(0.25, strength * 0.2))
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    nt.nodes.remove(emis)
    return True


def _apply_look(scene):
    counts = {"metal": 0, "wood": 0, "rebuilt": 0, "body": 0, "other": 0}
    for mat in bpy.data.materials:
        name = mat.name
        if name == "BackdropMat":
            for n in mat.node_tree.nodes:
                if n.bl_idname == "ShaderNodeEmission":
                    n.inputs["Strength"].default_value = BACKDROP_STRENGTH * 0.5
            continue
        b = _principled(mat)
        if b is None:
            if _rebuild_emissive_as_metal(mat):
                counts["rebuilt"] += 1
            continue
        if name == "FloorMat":
            _set(b, "Base Color", (0.012, 0.012, 0.015, 1.0))
            _set(b, "Roughness", 0.52)          # dark semi-gloss: a reflection, not a mirror
            _set(b, "Specular IOR Level", 0.5)
            counts["other"] += 1
            continue
        metallic = b.inputs["Metallic"].default_value if b.inputs.get("Metallic") else 0.0
        if b.inputs.get("Emission Strength") is not None and b.inputs["Emission Color"].is_linked:
            # a self-lit body (winds, brass, melody): keep the glow-on-note cue faint
            _set(b, "Emission Strength", LOOK_BODY_EMISSION)
            counts["body"] += 1
        if metallic >= 0.5:
            # brass (the 0.7 bodies) polished and anisotropic; everything else
            # metal - resonators, pads, keys, tines - brushed, or it turns to
            # chrome under the areas and reads as a mirror strip
            brass = "BrBody" in name or "MelBody" in name and "Metal" in name
            _set(b, "Roughness", 0.26 if brass else 0.40)
            _set(b, "Anisotropic", 0.45 if brass else 0.15)
            counts["metal"] += 1
        else:
            # wood, pads, mallets, frames: a varnish coat over whatever colour
            # and grain the section gave it
            # a light varnish only: on flat-coloured, ungrained bodies a hard
            # gloss reads as plastic, and that is a geometry/texture problem
            # this pass cannot solve
            _set(b, "Coat Weight", 0.30)
            _set(b, "Coat Roughness", 0.22)
            r = b.inputs["Roughness"]
            if not r.is_linked and r.default_value > 0.5:
                r.default_value = 0.42
            counts["wood"] += 1

    # lights: soft wrap from three big areas, the existing rig turned down
    for name, col, watts, size, pos, aim in LOOK_AREA_LIGHTS:
        data = bpy.data.lights.new(name, type='AREA')
        data.energy, data.color, data.size = watts, col, size
        data.shape = 'SQUARE'
        obj = bpy.data.objects.new(name, data)
        obj.location = pos
        point_camera_at(obj, aim)
        scene.collection.objects.link(obj)
    for obj in scene.objects:
        if obj.type == 'LIGHT' and obj.data.type == 'SPOT':
            obj.data.energy *= LOOK_WASH_SCALE
    world = scene.world
    if world and world.use_nodes:
        bg = world.node_tree.nodes.get("Background")
        if bg:
            bg.inputs["Color"].default_value = (0.045, 0.048, 0.060, 1.0)
            bg.inputs["Strength"].default_value = 1.0

    # tone: film-like roll-off instead of clipping
    try:
        scene.view_settings.view_transform = 'AgX'
        # Punchy restores the saturation AgX otherwise trades away in the
        # brights - the racks' pitch colours are information, not decoration
        for look in ('AgX - Punchy', 'AgX - Medium High Contrast', 'None'):
            try:
                scene.view_settings.look = look
                break
            except TypeError:
                continue
    except TypeError:
        scene.view_settings.view_transform = 'Filmic'
    scene.view_settings.exposure = -0.25
    print(f"[look] studio: {counts}, {len(LOOK_AREA_LIGHTS)} area lights, "
          f"washes x{LOOK_WASH_SCALE}, view {scene.view_settings.view_transform}")


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    # With --npy the stage animates: --out is a frame directory. Without it,
    # a single static still is written to --out (the layout-check path).
    p.add_argument("--npy", default=None)
    p.add_argument("--tempo", type=float, default=None)
    p.add_argument("--duration", type=float, default=None)
    p.add_argument("--out", default="stage_proto.png")
    # --mp4 PATH writes an .mp4 directly (Blender's bundled ffmpeg) instead of
    # a PNG frame directory — handy for quick short previews. Video-only (no
    # audio); mux the chorale mp3 separately if you want sound.
    p.add_argument("--mp4", default=None)
    p.add_argument("--res-x", type=int, default=1280)
    p.add_argument("--res-y", type=int, default=720)
    # Which renderer. EEVEE is the default and what every render so far used.
    # Cycles runs on the Intel GPUs through oneAPI — python-music:0.10 carries
    # the Level Zero loader, Intel's driver and the hardware ray-tracing
    # library it needs. Measured on a B70 at 1280x720, 64 samples + denoise:
    # EEVEE 1.50 s/frame, Cycles 2.39 (software BVH), 2.95 (hardware RT). The
    # hardware path loses on this scene because its per-frame BVH setup
    # outweighs the tracing it saves; it should win once the geometry is
    # richer, which is why it is a flag and not a fact.
    p.add_argument("--engine", choices=("eevee", "cycles"), default="eevee")
    p.add_argument("--samples", type=int, default=64,
                   help="Cycles samples per pixel (denoised)")
    p.add_argument("--cycles-hw-rt", action="store_true",
                   help="use Intel's hardware ray tracing (Embree on GPU)")
    # Substring of the device name Cycles should use. "Arc" matches the B70,
    # B580 and B50 and skips the Arrow Lake iGPU, which shows up as plain
    # "Intel(R) Graphics" and would otherwise be picked too.
    p.add_argument("--gpu-name", default="Arc")
    # A post-build look pass, off by default so every existing render is
    # reproducible. "studio" is the materials-and-light pass: see _apply_look.
    p.add_argument("--look", choices=("stage", "studio"), default="stage")
    # Render only part of the clip, so two Blender processes (one per GPU) can
    # split the work. Frame numbers and the animation clock stay absolute —
    # frame N is at t = N/FPS whichever process renders it — so both halves
    # write frame_%06d.png into the SAME --out dir and need no merge step.
    p.add_argument("--frame-start", type=int, default=0)
    p.add_argument("--frame-end", type=int, default=None)   # inclusive
    # Print every name CAMERA_CUES can target, then exit.
    p.add_argument("--list-targets", action="store_true")
    # Write who-is-playing-when as JSON, for plot_activity.py to chart while
    # you author CAMERA_CUES. Needs --npy and --tempo.
    p.add_argument("--dump-activity", default=None)
    # Write the stage — every target's box, the camera and the whole light rig
    # — for stage_preview.html to draw. Needs no notes, so it runs on a static
    # build in seconds.
    p.add_argument("--dump-layout", default=None)
    # Write the built stage as a .glb for stage_preview.html to render instead
    # of proxy boxes. Exported rather than re-modelled in three.js because the
    # section builders are a couple of thousand lines of bpy mesh code that a
    # hand port would drift away from.
    p.add_argument("--export-gltf", default=None)
    return p.parse_args(argv)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mesh_bounds(objs):
    """World-space (min_x,max_x,min_y,max_y,min_z,max_z) over all the mesh
    verts in objs — before any grouping transform, so it's the section's
    own authored footprint."""
    xs, ys, zs = [], [], []
    for o in objs:
        if o.type != 'MESH':
            continue
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            xs.append(w.x); ys.append(w.y); zs.append(w.z)
    return min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)


def place_section(name, before_objs):
    """Group everything build() just created into one Empty, normalise it
    to SECTIONS[name]['target_h'], and drop it into its slot with its
    bottom on the floor. Returns the Empty and its post-transform world
    bounds (for camera framing)."""
    new = [o for o in bpy.data.objects if o not in before_objs]
    if not new:
        raise RuntimeError(f"section {name!r} created no objects")
    # Sections that re-parent their own pieces (the quartets' seat empties)
    # leave stale matrix_world values behind; mesh_bounds reads them.
    bpy.context.view_layer.update()

    min_x, max_x, min_y, max_y, min_z, max_z = mesh_bounds(new)
    cfg = SECTIONS[name]
    scale = cfg["scale"]   # direct scale, no auto-fit

    cx_src = (min_x + max_x) / 2.0
    cy_src = (min_y + max_y) / 2.0

    empty = bpy.data.objects.new(f"section_{name}", None)
    bpy.context.scene.collection.objects.link(empty)
    empty.scale = (scale, scale, scale)
    # Centre the section over its slot (x, y); sit its bottom on z=0.
    empty.location = (cfg["cx"] - cx_src * scale,
                      cfg["cy"] - cy_src * scale,
                      -min_z * scale)

    for o in new:
        if o.parent is None:
            o.parent = empty

    # Post-transform world bounds of this section's footprint corners.
    def w(x, y, z):
        return (x * scale + empty.location.x,
                y * scale + empty.location.y,
                z * scale + empty.location.z)
    corners = [w(x, y, z) for x in (min_x, max_x) for y in (min_y, max_y) for z in (min_z, max_z)]
    wb = (min(c[0] for c in corners), max(c[0] for c in corners),
          min(c[1] for c in corners), max(c[1] for c in corners),
          min(c[2] for c in corners), max(c[2] for c in corners))
    print(f"[stage] {name:8s} scale={scale:.3f}  "
          f"X[{wb[0]:.2f},{wb[1]:.2f}] Y[{wb[2]:.2f},{wb[3]:.2f}] Z[{wb[4]:.2f},{wb[5]:.2f}]")
    return empty, wb


# Each setup_* builds its section's instruments into the current scene,
# loads that section's notes from (npy, tempo), and returns an update(t)
# callback that drives one frame. The objects the build created get parented
# under the section's Empty afterwards (place_section); because the update
# callbacks only ever set obj.color / obj.location / obj.hide_render /
# obj.rotation_euler or edit mesh-local vertex coords — all of which compose
# through a parent transform — the animation rides the scale+translate for
# free, no matter where the section is placed on the stage.

def setup_marimba(npy, tempo):
    bars, pitch_to_idx, n_bars, bar_info, half_width = marimba.build_bars()
    post_l = bar_info[0]["x"] - marimba.FRAME_MARGIN
    post_r = bar_info[-1]["x"] + marimba.FRAME_MARGIN
    marimba.build_strings(bar_info, post_l, post_r)
    marimba.build_frame(bar_info, post_l, post_r)
    marimba.build_resonators(bar_info, n_bars)

    notes = marimba.load_features_array(npy, tempo, voice=5) if npy else np.zeros((0, 5))
    if len(notes):
        notes[:, 1] = [pb.bucket_cents(p) for p in notes[:, 1]]
    assignments, n_slots = marimba.assign_mallet_slots(notes, pitch_to_idx)
    pivots, sticks, heads = marimba.build_mallet_pool(n_slots)
    vibrating = set()

    def update(t):
        nonlocal vibrating
        glow = marimba.compute_bar_glow(t, notes, pitch_to_idx, n_bars)
        for i, obj in enumerate(bars):
            # RGB is the bar's pitch tint, alpha is how hard it was just
            # struck — see blender_marimba_poc.make_bar_material.
            obj.color = marimba.bar_object_color(i, n_bars, glow[i])
        last_onset = marimba.compute_last_onset(t, notes, pitch_to_idx, n_bars)
        still = set()
        for i in np.nonzero(~np.isnan(last_onset))[0]:
            dt = t - last_onset[i]
            if dt < marimba.VIB_CUTOFF:
                marimba.apply_bar_vibration(bars[i], dt)
                still.add(int(i))
        for i in vibrating - still:
            marimba.reset_bar_mesh(bars[i])
        vibrating = still
        marimba.update_mallet_pool(t, assignments, n_slots, pivots, sticks, heads, bar_info)

    return update


def _update_string_player(t, pl, geom):
    """One string player's per-frame update (glow, vibration, stop finger,
    pluck/bow) — shared by the pizzicato and bowed-string sections, which
    build identical violin/viola/cello geometry."""
    # Arco (sustained bowed strings) vs martele/pizzicato: a bowed player has
    # a bow but isn't a martele voice — it sounds continuously for the note.
    is_arco = geom['bow_pivot'] is not None and pl['voice'] not in pizz.MARTEL_VOICES
    state = pizz.compute_player_state(t, pl['_notes'], pl['inst'], arco=is_arco)
    glow, vib = state['str_glow'], state['str_vib']
    st_on, st_pitch = state['str_onset'], state['str_pitch']

    for si, s in enumerate(geom['strings']):
        g, a = glow[si], vib[si]
        g_col = pizz.STRING_REST_COLOR[si]
        if g > 0.02:
            base = np.array(pizz.STRING_REST_COLOR[si])
            g_col = base + g * (np.array(pizz.STRING_GLOW_COLOR) - base)
        s.color = (*g_col, 1.0)

        stopf = geom['stop_fingers'][si]
        if a > 0.005:
            dt = t - st_on[si]
            phase = 2.0 * math.pi * pizz.VIB_FREQ * dt
            pitch = st_pitch[si]
            length_frac = (sl.vibrating_length_fraction(pitch, geom['open_cents'][si])
                           if not math.isnan(pitch) else 1.0)
            vib_top_z = geom['bridge_z'] + length_frac * (geom['str_top'] - geom['bridge_z'])
            pizz.update_string_curve(s, geom['str_zs'][si], geom['str_xs'][si], geom['str_ys'][si],
                                     geom['bridge_z'], vib_top_z, a, phase)
            if length_frac < 0.98 and g > 0.05:
                stop_x = pizz.string_rest_x(vib_top_z, geom['str_top'], geom['bridge_z'],
                                            geom['sxs'][si], geom['bridge_sxs'][si])
                stop_y = geom['front_y'] - pizz.dome_bump(vib_top_z, geom['bh'], geom['arch_depth']) - 0.006
                stopf.location = (stop_x, stop_y, vib_top_z)
                stopf.hide_render = False
            else:
                stopf.hide_render = True
        else:
            pizz.reset_string_curve(s, geom['str_zs'][si], geom['str_xs'][si], geom['str_ys'][si])
            stopf.hide_render = True

    if geom['pluck'] is not None:
        pizz.update_pluck_finger(geom['pluck'], state['last_gest'],
                                 geom['contact_sxs'], geom['contact_z'], geom['contact_y'], t)
    if geom['bow_pivot'] is not None:
        if is_arco:
            pizz.update_bow_sustained(geom['bow_pivot'], geom['bow_parts'], state['bow_note'],
                                      geom['contact_sxs'], geom['contact_z'], geom['contact_y'], t)
        else:
            pizz.update_bow(geom['bow_pivot'], geom['bow_parts'], state['last_gest'],
                            geom['contact_sxs'], geom['contact_z'], geom['contact_y'], t)


def setup_pizz(npy, tempo):
    string_mat = pizz.make_string_glow_material()
    notes = pizz.load_string_voices(npy, tempo) if npy else np.zeros((0, 5))
    player_note_sets = pizz.build_player_note_sets(notes, pizz.PLAYERS)
    geoms = {}
    for pl in pizz.PLAYERS:
        pl['_notes'] = player_note_sets[pl['id']]
        geoms[pl['id']] = pizz.build_player(pl, string_mat)

    def update(t):
        for pl in pizz.PLAYERS:
            _update_string_player(t, pl, geoms[pl['id']])

    return update


def setup_bass(npy, tempo):
    # Finger piano on the left (enlarged FP_SCALE bigger than the guitar),
    # baritone guitar on the right, separated in X.
    FP_SCALE = 1.5
    # How far the finger piano is lifted off this section's floor, in section
    # units. The bass section is scaled 4.5 onto the stage, so this lands the
    # rack at about the marimba's bar height — a standing player's hands.
    FP_STAND_DROP = 0.30
    fp_total_w = bass.TINE_RACK_W * FP_SCALE
    gtr_total_len = bass.HEAD_LEN + bass.NECK_LEN + bass.BODY_W
    gap = 0.3   # narrower gap between the bass finger piano and the guitar
    fp_x0 = -(fp_total_w + gap + gtr_total_len) / 2.0 + fp_total_w / 2.0
    gtr_x0 = fp_x0 + fp_total_w / 2.0 + gap

    # Build the finger piano, then group its objects under an empty and scale
    # it up in place (pivot at fp_x0, floor level). The animation still
    # composes through the extra parent transform, exactly as the whole
    # section's scale does.
    # Its stand reaches the floor the GUITAR sets, not its own: the guitar is
    # the lowest thing in this section, so that is where the section's floor
    # ends up, and legs stopping anywhere above it would hover.
    before_fp = set(bpy.data.objects)
    fp_geom = bass.build_bass_finger_piano(fp_x0, stand_floor_z=-FP_STAND_DROP / FP_SCALE)
    fp_objs = [o for o in bpy.data.objects if o not in before_fp]
    fp_empty = bpy.data.objects.new("bass_fp_group", None)
    bpy.context.scene.collection.objects.link(fp_empty)
    fp_empty.location = (fp_x0, 0.0, FP_STAND_DROP)
    bpy.context.view_layer.update()
    pinv = fp_empty.matrix_world.inverted()   # keep objects in place when parenting
    for o in fp_objs:
        if o.parent is None:
            o.parent = fp_empty
            o.matrix_parent_inverse = pinv
    fp_empty.scale = (FP_SCALE, FP_SCALE, FP_SCALE)

    # Group the guitar under its own empty too — not to transform it (the
    # empty stays at the origin), purely so it registers as the camera target
    # "bass.guitar" and can be framed apart from the finger piano.
    before_gtr = set(bpy.data.objects)
    gtr_geom = bass.build_baritone_guitar(gtr_x0, bass.BASE_HEIGHT / 2.0 + bass.BODY_H * 0.15)
    gtr_empty = bpy.data.objects.new("bass_guitar", None)
    bpy.context.scene.collection.objects.link(gtr_empty)
    for o in bpy.data.objects:
        if o not in before_gtr and o is not gtr_empty and o.parent is None:
            o.parent = gtr_empty

    tine_notes = bass.load_voices(npy, tempo, (24,)) if npy else np.zeros((0, 5))
    if len(tine_notes):
        tine_notes[:, 1] = [pb.bucket_cents(p, bottom_octave=bass.TINE_BOTTOM_OCTAVE,
                                            n_octaves=bass.TINE_N_OCTAVES)
                            for p in tine_notes[:, 1]]
    guitar_notes = bass.load_voices(npy, tempo, (20,)) if npy else np.zeros((0, 5))

    def update(t):
        bass.update_bass_finger_piano(t, fp_geom, tine_notes)
        bass.update_baritone_guitar(t, gtr_geom, guitar_notes)

    return update


def setup_finger_piano(npy, tempo):
    geom = fingerpiano.build_finger_piano(0.0)
    notes = fingerpiano.load_notes(npy, tempo) if npy else np.zeros((0, 5))

    def update(t):
        fingerpiano.update_finger_piano(t, geom, notes)

    return update


def setup_woodwind(npy, tempo):
    geom = woodwind.build_woodwinds(0.0)
    seat_sets = woodwind.load_seat_notes(npy, tempo, geom['seats'])

    def update(t):
        woodwind.update_woodwinds(t, geom, seat_sets)

    return update


def setup_brass(npy, tempo):
    geom = brass.build_brass(0.0)
    seat_sets = brass.load_seat_notes(npy, tempo, geom['seats'])

    def update(t):
        brass.update_brass(t, geom, seat_sets)

    return update


def setup_bowed_strings(npy, tempo):
    geom = bowedstrings.build_bowed_strings(0.0)
    voices = tuple(p['voice'] for p in bowedstrings.PLAYERS)
    notes = pizz.load_string_voices(npy, tempo, voices) if npy else np.zeros((0, 5))
    sets = pizz.build_player_note_sets(notes, bowedstrings.PLAYERS)
    for pl in bowedstrings.PLAYERS:
        pl['_notes'] = sets[pl['id']]

    def update(t):
        for pl in bowedstrings.PLAYERS:
            _update_string_player(t, pl, geom['geoms'][pl['id']])

    return update


def setup_melody(npy, tempo):
    geom = melody.build_melody(0.0)
    seat_notes = melody.load_seat_notes(npy, tempo, geom['seats'])

    def update(t):
        melody.update_melody(t, geom, seat_notes)

    return update


def setup_conductor(npy, tempo):
    geom = conductor.build_conductor_section(0.0)
    # The baton follows the ORIGINAL-chorale chord index (features col 15),
    # not wall-clock tempo — so it marks the source beat the orchestra is
    # actually on, through all the random chord repetitions.
    timeline = conductor.load_beat_timeline(npy, tempo) if npy else None
    # Start already on the downbeat (chord 0 -> beat 0 -> down) so the baton
    # doesn't swing into place at t=0.
    state = {'dir': list(conductor.BEAT_DIRS[0])}   # smoothed direction, persists across frames

    def update(t):
        conductor.update_conductor(t, geom, timeline, state)

    return update


def point_camera_at(cam, target):
    d = mathutils.Vector(target) - mathutils.Vector(cam.location)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


def _obj_world_bounds(root):
    """World bounds of every mesh under `root` (inclusive), read AFTER the
    section transforms are in place — so it's where the player really is on
    the finished stage."""
    objs, stack = [], [root]
    while stack:
        o = stack.pop()
        objs.append(o)
        stack.extend(o.children)
    return mesh_bounds(objs)


def _target_key(section, empty_name):
    """'seat_Violin I' in bowed_strings -> 'bowed_strings.violin_i'. Blender
    dedupes duplicate names with a '.001' suffix (both string sections build a
    'seat_Cello'), so strip that and qualify with the section instead."""
    n = empty_name.split('.')[0]
    for prefix in ("seat_", "ww_", "brass_", "mel_", "cond_", "bass_"):
        if n.startswith(prefix):
            n = n[len(prefix):]
            break
    return f"{section}.{n.lower().replace(' ', '_')}"


def cue_seconds(t):
    """Cue times as seconds, from either a number or a "m:ss" string.

    activity.png is labelled in m:ss, so converting in your head on the way
    into this file is a reliable way to put a cue in the wrong bar. Accepts
    90, 90.5, "1:30", "1:30.5" and "1:02:03"."""
    if isinstance(t, (int, float)):
        return float(t)
    total = 0.0
    for part in str(t).split(':'):
        total = total * 60.0 + float(part)
    return total


def interest(name):
    """VISUAL_INTEREST for a target: its own entry if it has one, else its
    section's, else the default."""
    if name in VISUAL_INTEREST:
        return VISUAL_INTEREST[name]
    return VISUAL_INTEREST.get(name.split('.')[0], DEFAULT_INTEREST)


def shot_names(focus):
    """The target names a shot actually refers to, with any form marker (the
    leading "overhead") stripped off."""
    names = (focus,) if isinstance(focus, str) else tuple(focus)
    return names[1:] if names and names[0] == "overhead" else names


def voice_map():
    """target name -> the csound voices it shows. Read from each section's own
    seat tables rather than restated here, so adding a player or moving a voice
    can't leave this map quietly wrong."""
    m = {"marimba": (5,), "bass": (24, 20), "conductor": (),
         "finger_piano": tuple(fingerpiano.VOICES),
         "bass.fp_group": (24,), "bass.guitar": (20,)}
    for pl in pizz.PLAYERS:
        m[f"pizz.{pl['name'].lower().replace(' ', '_')}"] = (pl['voice'],)
    for pl in bowedstrings.PLAYERS:
        m[f"bowed_strings.{pl['name'].lower().replace(' ', '_')}"] = (pl['voice'],)
    for sid, _k, voices, *_ in brass.SEATS_SPEC:
        m[f"brass.{sid}"] = tuple(voices)
    for sid, _k, voices, *_ in woodwind.SEATS_SPEC:
        m[f"woodwind.{sid}"] = tuple(voices)
    for sid, _k, voice, *_ in melody.SEATS_SPEC:
        m[f"melody.{sid}"] = (voice,)
    # A section shows everything its players do.
    for section in ("pizz", "bowed_strings", "brass", "woodwind", "melody"):
        m[section] = tuple(sorted({v for k, vs in m.items()
                                   if k.startswith(section + '.') for v in vs}))
    return m


def load_activity(npy, tempo):
    """(start, end, voice, volume) for every audible note, for the shot-selection
    volume gate. Column 14 is overall volume — a note recorded at volume 0 is
    in the array but silent in the mix, and pointing the camera at it is
    exactly the mistake we're trying to avoid."""
    arr = np.load(npy)
    bps = tempo / 60.0
    audible = (arr[:, 14] > 0) & (arr[:, 3] > 0) & (arr[:, 2] > 0)
    arr = arr[audible]
    start = arr[:, 1] / bps
    return start, start + arr[:, 2] / bps, arr[:, 6].astype(int), arr[:, 14]


def is_playing(focus, t0, t1, vmap, activity, min_fraction=0.25):
    """Does everything in this shot actually sound for a decent share of
    [t0, t1)? Measured as sounding TIME, not note count: a flute holding one
    long note is as audible as a marimba playing thirty short ones, and a
    note-count threshold would quietly bias the edit toward the busy
    sections."""
    if activity is None or focus == "wide":
        return True
    start, end, voice, _vol = activity
    span = t1 - t0
    for n in shot_names(focus):
        voices = vmap.get(n)
        if not voices:            # conductor, or an unmapped pivot: never gates
            continue
        m = np.isin(voice, voices)
        overlap = np.minimum(end[m], t1) - np.maximum(start[m], t0)
        if float(overlap[overlap > 0].sum()) < min_fraction * span:
            return False
    return True


def _framing_overhead(name, targets, res_x, res_y):
    """Looking down on one target from above — a different angle from every
    other shot, which is the point. Tilted slightly back toward the audience
    rather than straight down, so the aim never goes degenerate and the
    instruments keep a little of their own height. A near-vertical look at a
    thin row of instruments is mostly floor; a high oblique keeps them tall
    enough to read."""
    b = targets[name]
    centre = mathutils.Vector(((b[0] + b[1]) / 2.0, (b[2] + b[3]) / 2.0, (b[4] + b[5]) / 2.0))
    half_h_fov = math.atan((CAM_SENSOR / 2.0) / CAM_LENS)
    sensor_y = CAM_SENSOR * res_y / res_x
    half_v_fov = math.atan((sensor_y / 2.0) / CAM_LENS)
    half_w = (b[1] - b[0]) / 2.0 * CAMERA_MARGIN
    half_d = (b[3] - b[2]) / 2.0 * CAMERA_MARGIN
    height = max(half_w / math.tan(half_h_fov), half_d / math.tan(half_v_fov), 8.0)
    return centre + mathutils.Vector((0.0, -height * 0.75, height * 0.85)), centre


def _framing(focus, targets, res_x, res_y):
    """(camera position, look-at target) that frames `focus`.

    Every framing keeps the wide shot's viewing DIRECTION and focal length and
    only moves along that axis — so a move reads as a push-in toward one
    section, never as a change of angle, and the layout tuning (which is all
    relative to this one viewpoint) still holds."""
    if focus == "wide":
        return mathutils.Vector(CAM_POS), mathutils.Vector(CAM_TARGET)

    boxes = [targets[n] for n in shot_names(focus)]
    min_x = min(b[0] for b in boxes); max_x = max(b[1] for b in boxes)
    min_y = min(b[2] for b in boxes); max_y = max(b[3] for b in boxes)
    min_z = min(b[4] for b in boxes); max_z = max(b[5] for b in boxes)
    target = mathutils.Vector(((min_x + max_x) / 2.0,
                               (min_y + max_y) / 2.0,
                               (min_z + max_z) / 2.0))

    # Distance at which the section's width AND height both fit the frame.
    half_h_fov = math.atan((CAM_SENSOR / 2.0) / CAM_LENS)
    sensor_y = CAM_SENSOR * res_y / res_x
    half_v_fov = math.atan((sensor_y / 2.0) / CAM_LENS)
    half_w = (max_x - min_x) / 2.0 * CAMERA_MARGIN
    half_t = (max_z - min_z) / 2.0 * CAMERA_MARGIN
    dist = max(half_w / math.tan(half_h_fov), half_t / math.tan(half_v_fov), 6.0)

    axis = (mathutils.Vector(CAM_POS) - mathutils.Vector(CAM_TARGET)).normalized()
    pos = target + axis * dist
    # Never dip below the stage floor, however tight the framing gets.
    pos.z = max(pos.z, 1.5)
    return pos, target


def _smoothstep(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3.0 - 2.0 * x)


def _cue_index(t, cues):
    i = 0
    while i + 1 < len(cues) and t >= cues[i + 1][0]:
        i += 1
    return i


def _shot_focus(focus, targets):
    """(centre, radius) of a shot — the point the follow spot aims at and the
    half-extent its cone has to cover."""
    if focus == "wide":
        boxes = [b for k, b in targets.items() if '.' not in k]
    else:
        boxes = [targets[n] for n in shot_names(focus)]   # both ends of a pan
    min_x = min(b[0] for b in boxes); max_x = max(b[1] for b in boxes)
    min_y = min(b[2] for b in boxes); max_y = max(b[3] for b in boxes)
    min_z = min(b[4] for b in boxes); max_z = max(b[5] for b in boxes)
    centre = mathutils.Vector(((min_x + max_x) / 2.0,
                               (min_y + max_y) / 2.0,
                               (min_z + max_z) / 2.0))
    return centre, max((max_x - min_x) / 2.0, (max_z - min_z) / 2.0)


def update_follow(spot, t, cues, targets):
    """Aim the follow spot at whatever shot is live, widening its cone to suit
    the shot's size — tight on a solo player, open on a wide."""
    i = _cue_index(t, cues)
    cue_t, focus, move_t = cues[i]
    centre, radius = _shot_focus(focus, targets)
    if i > 0 and move_t > 0.0:
        blend = _smoothstep((t - cue_t) / move_t)
        if blend < 1.0:
            c0, r0 = _shot_focus(cues[i - 1][1], targets)
            centre = c0.lerp(centre, blend)
            radius = r0 + (radius - r0) * blend
    offset = mathutils.Vector(FOLLOW_OFFSET)
    spot.location = centre + offset
    _aim(spot, centre)
    # Keep the pool matched to the subject: cone half-angle = atan(r / throw).
    spot.data.spot_size = min(math.radians(140.0),
                              2.0 * math.atan(radius * FOLLOW_CONE_MARGIN / offset.length))


def build_follow_spot():
    data = bpy.data.lights.new("FollowSpot", type='SPOT')
    data.energy = FOLLOW_ENERGY
    data.color = FOLLOW_COLOR
    data.spot_blend = 0.55       # soft edge, so the pool doesn't read as a disc
    data.shadow_soft_size = 1.0
    # No shadow: it would be a fourth caster for ~5% more render time, and
    # coming from front-and-above it has little to cast onto that the key
    # light isn't already shadowing.
    data.use_shadow = False
    obj = bpy.data.objects.new("FollowSpot", data)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _shot_progress(i, t, cues):
    """How far through its own hold this shot is, 0..1 — only pans use it."""
    if i + 1 >= len(cues):
        return _smoothstep((t - cues[i][0]) / sum(CAMERA_HOLD) * 2.0)
    span = cues[i + 1][0] - cues[i][0]
    return _smoothstep((t - cues[i][0]) / span) if span > 0 else 0.0


def _shot_framing(focus, targets, res_x, res_y, progress=0.0):
    """Framing for a shot. ("overhead", a, b) looks down from above and travels
    from over `a` to over `b` across the shot's whole hold — every other shot
    form is static and ignores progress."""
    if isinstance(focus, tuple) and focus and focus[0] == "overhead":
        _, a, b = focus
        pa, ta = _framing_overhead(a, targets, res_x, res_y)
        pb, tb = _framing_overhead(b, targets, res_x, res_y)
        return pa.lerp(pb, progress), ta.lerp(tb, progress)
    return _framing(focus, targets, res_x, res_y)


def update_camera(cam, t, cues, targets, res_x, res_y):
    """Place the camera for time t. A cue with move_seconds == 0 cuts; one with
    a positive value eases from the previous shot over that many seconds, on
    both position and aim so the move arcs instead of snapping its aim."""
    i = _cue_index(t, cues)
    cue_t, focus, move_t = cues[i]
    pos, target = _shot_framing(focus, targets, res_x, res_y, _shot_progress(i, t, cues))
    if i > 0 and move_t > 0.0:
        blend = _smoothstep((t - cue_t) / move_t)
        if blend < 1.0:
            p0, t0 = _shot_framing(cues[i - 1][1], targets, res_x, res_y, 1.0)
            pos = p0.lerp(pos, blend)
            target = t0.lerp(target, blend)
    cam.location = pos
    point_camera_at(cam, target)


# Sections with no per-player split, so a "solo" shot on them is the section.
_UNSPLIT = ("marimba", "bass", "finger_piano")


def generate_cues(t0, t1, seed, targets, vmap=None, activity=None):
    """Invent shots for [t0, t1) in the Reich-video pattern: hold 10-15s, vary
    the shot size, cut most of the time and occasionally drift. Deterministic
    for a given seed so a re-render reproduces the edit exactly."""
    rng = random.Random(seed)
    # Some registered empties are bare pivots (a mallet, the baton) rather than
    # players; framing one fills the screen with a stick. They stay addressable
    # by hand, but the generator skips anything too small to be a shot.
    def shootable(k):
        b = targets[k]
        return (b[1] - b[0]) >= 0.8 or (b[5] - b[4]) >= 2.0
    players = sorted(k for k in targets if '.' in k and shootable(k))
    sections = sorted(k for k in targets if '.' not in k)
    by_section = {}
    for p in players:
        by_section.setdefault(p.split('.')[0], []).append(p)

    def weighted(pool):
        """Pick one, favouring the instruments whose motion shows the sound."""
        return rng.choices(pool, weights=[interest(n) for n in pool])[0]

    def solo():
        return weighted(players) if players else weighted(sections)

    def pair():
        sec = weighted([s for s in by_section if len(by_section[s]) >= 2])
        return tuple(rng.sample(by_section[sec], 2))

    def group():
        return weighted(sections)

    def duo_section():
        a = weighted(sections)
        b = weighted([s for s in sections if s != a])
        return (a, b)

    # Drawn from a shuffled bag rather than independently at random: every shot
    # size appears once per cycle before any repeats, so the edit always works
    # through one-player / two-player / section / two-section / wide instead of
    # leaving a size out for two minutes at a stretch.
    kinds = [solo, pair, group, duo_section, lambda: "wide"]

    def overhead():
        # Slow travelling look down the middle row. Ordered, not sampled, so it
        # always reads as a journey across the stage rather than a jump.
        row = [s for s in ("marimba", "bass", "finger_piano") if s in targets]
        if len(row) < 2:
            return group()
        a, b = (row[0], row[-1]) if rng.random() < 0.5 else (row[-1], row[0])
        return ("overhead", a, b)

    kinds = kinds + [overhead]

    cues, t, recent, bag = [], t0, [], []
    while t < t1:
        hold = rng.uniform(*CAMERA_HOLD)
        # Reject anything used in the last few shots, not just the previous one
        # — otherwise the same cello close-up comes round twice a minute — and
        # anything that isn't actually sounding during the shot.
        shot = None
        for attempt in range(14):
            if not bag:
                bag = kinds[:]
                rng.shuffle(bag)
            cand = bag.pop()()
            if cand in recent:
                continue
            if is_playing(cand, t, t + hold, vmap, activity):
                shot = cand
                break
            shot = shot or cand      # keep the first non-repeat as a fallback
        # A passage where almost nothing sounds (or every candidate is silent)
        # falls back to the wide, which is always true to the music.
        if shot is None or not is_playing(shot, t, t + hold, vmap, activity):
            shot = "wide"
        move = CAMERA_MOVE_T if rng.random() < CAMERA_MOVE_CHANCE else 0.0
        cues.append((round(t, 2), shot, move))
        recent = (recent + [shot])[-4:]
        t += hold
    return cues


def check_cues(cues, targets):
    """Everything wrong with a cue sheet that is visible before rendering.

    Name and shape errors are fatal — they would crash mid-render, an hour in.
    A zero-length shot is only a warning: it renders fine, it just never
    appears, which is usually a typo but is yours to make."""
    unknown = {n for _, f, _ in cues for n in shot_names(f)
               if n != "wide" and n not in targets}
    if unknown:
        raise SystemExit(f"CAMERA_CUES names no such target: {sorted(unknown)}\n"
                         f"run with --list-targets to see the valid names")
    bad = [f for _, f, _ in cues
           if isinstance(f, tuple) and f[:1] == ("overhead",) and len(f) != 3]
    if bad:
        raise SystemExit(f"overhead shots take exactly two targets: {bad}")
    for a, b in zip(cues, cues[1:]):
        if b[0] - a[0] < 0.5:
            print(f"[stage] WARNING: {a[1]} at {_mmss(a[0])} is on screen for "
                  f"{b[0] - a[0]:.2f}s before {b[1]} replaces it")
        if b[2] > b[0] - a[0]:
            print(f"[stage] WARNING: move onto {b[1]} at {_mmss(b[0])} takes "
                  f"{b[2]}s but the previous shot is only {b[0] - a[0]:.2f}s long")


def _mmss(t):
    return f"{int(t // 60)}:{t % 60:05.2f}"


def build_cue_sheet(targets, vmap=None, activity=None):
    """Hand-authored CAMERA_CUES merged with generated shots for each
    CAMERA_AUTOGEN range. A generated shot landing within one hold of a hand
    cue is dropped — you asked for that moment, the generator doesn't get to
    step on it."""
    hand = [(cue_seconds(c[0]), c[1], c[2] if len(c) > 2 else 0.0)
            for c in CAMERA_CUES]
    generated = []
    for t0, t1, seed in CAMERA_AUTOGEN:
        generated += generate_cues(cue_seconds(t0), cue_seconds(t1), seed,
                                   targets, vmap, activity)
    guard = CAMERA_HOLD[0]
    generated = [g for g in generated
                 if all(abs(g[0] - h[0]) > guard for h in hand)]
    cues = sorted(hand + generated, key=lambda c: c[0])
    if not cues or cues[0][0] > 0.0:
        cues.insert(0, (0.0, "wide", 0.0))
    return cues


def _sun(name, color, energy, pitch_deg, yaw_deg, angle_deg, shadow):
    """One directional light. pitch_deg is the tilt off straight-down: positive
    values throw the light away from the camera (source in FRONT of the stage),
    negative values throw it toward the camera (source BEHIND). yaw_deg swings
    that around, negative = source on stage left."""
    data = bpy.data.lights.new(name, type='SUN')
    data.energy = energy
    data.color = color
    data.angle = math.radians(angle_deg)   # angular diameter: bigger = softer edges
    data.use_shadow = shadow
    obj = bpy.data.objects.new(name, data)
    obj.rotation_euler = (math.radians(pitch_deg), 0.0, math.radians(yaw_deg))
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_backdrop():
    """Emissive cyclorama behind the orchestra. Returns the Emission colour
    socket so update_backdrop can retint it per frame. EEVEE doesn't bounce
    light off it, which is what we want — it colours the picture without
    washing out the instrument lighting we tuned."""
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0.0, BACKDROP_Y, BACKDROP_H / 2.0))
    bd = bpy.context.object
    bd.name = "Backdrop"
    bd.rotation_euler = (math.radians(90.0), 0.0, 0.0)   # stand it up, facing -Y
    bd.scale = (BACKDROP_W, BACKDROP_H, 1.0)
    mat = bpy.data.materials.new("BackdropMat")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    emis = nt.nodes.new("ShaderNodeEmission")
    emis.inputs["Strength"].default_value = BACKDROP_STRENGTH
    nt.links.new(emis.outputs["Emission"], nt.nodes["Material Output"].inputs["Surface"])
    bd.data.materials.append(mat)
    return emis.inputs["Color"]


def update_backdrop(socket, t):
    """Cross-fade around BACKDROP_COLORS on a BACKDROP_HOLD cycle."""
    n = len(BACKDROP_COLORS)
    pos = (t / BACKDROP_HOLD) % n
    i = int(pos)
    blend = _smoothstep(pos - i)
    a = BACKDROP_COLORS[i]
    b = BACKDROP_COLORS[(i + 1) % n]
    socket.default_value = (*(a[k] + (b[k] - a[k]) * blend for k in range(3)), 1.0)


def _aim(obj, target):
    d = mathutils.Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


def build_wash():
    """The contrasting coloured spots."""
    for name, colour, energy, pos, aim, cone, shadow in WASH_SPOTS:
        data = bpy.data.lights.new(name, type='SPOT')
        data.energy = energy
        data.color = colour
        data.spot_size = math.radians(cone)
        data.spot_blend = 0.5
        data.shadow_soft_size = 1.5
        data.use_shadow = shadow
        obj = bpy.data.objects.new(name, data)
        obj.location = pos
        bpy.context.scene.collection.objects.link(obj)
        _aim(obj, aim)


def _build_light_rig():
    """Warm key + cool fill. Suns rather than area lights because the stage is
    ~44 units wide and only a directional source covers it evenly. Only the KEY
    casts shadows — two shadow-casting lights would give every instrument two
    overlapping floor shadows, which reads as mud at this scale.

    No rim light: it was tried from behind at pitch -70/-50/-30 and energies up
    to 4.5, and contributed nothing visible. A rim reads as a bright edge
    against a lighter background, but here the camera looks DOWN on mostly
    flat, camera-facing instruments over a near-black floor — the surfaces a
    back light reaches are the ones we can't see. Revisit if the camera ever
    drops toward stage level, or if the materials get more specular."""
    for spec in SUNS:
        _sun(*spec)


def build_stage_env(bounds):
    """Floor + FIXED camera + three-point lighting. The camera never re-fits to
    the content, so section scales map predictably to on-screen size."""
    floor_c = (0.0, 3.0, 0.0)
    bpy.ops.mesh.primitive_plane_add(size=140.0, location=floor_c)
    floor = bpy.context.object
    floor.name = "Floor"
    mat = bpy.data.materials.new("FloorMat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    # Darker than the old single-sun setup: the rig puts ~2x the light on the
    # floor, and a mid-grey floor kills the contrast the instruments read by.
    bsdf.inputs["Base Color"].default_value = (0.028, 0.028, 0.034, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.95
    floor.data.materials.append(mat)

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = CAM_LENS
    cam_data.sensor_width = CAM_SENSOR
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = CAM_POS
    point_camera_at(cam, CAM_TARGET)
    bpy.context.scene.camera = cam

    _build_light_rig()
    build_wash()
    follow = build_follow_spot()
    backdrop = build_backdrop()

    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.02, 0.03, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.4
    return cam, backdrop, follow


def main():
    args = parse_args()
    t0 = time.time()
    animate = args.npy is not None
    if animate and args.tempo is None:
        raise SystemExit("--tempo is required with --npy")

    clear_scene()

    bounds, updates = [], []
    targets = {}          # shot name -> world bounds
    player_empties = []   # (target key, empty) resolved to bounds after placement
    setups = (("pizz", setup_pizz), ("marimba", setup_marimba), ("bass", setup_bass),
              ("finger_piano", setup_finger_piano), ("woodwind", setup_woodwind),
              ("brass", setup_brass), ("bowed_strings", setup_bowed_strings),
              ("melody", setup_melody), ("conductor", setup_conductor))
    for name, setup in setups:
        before = set(bpy.data.objects)
        # Static build (no notes) when just checking layout; otherwise the
        # setup also loads notes and hands back a per-frame update callback.
        update_fn = setup(args.npy, args.tempo) if animate else _static_build(name, setup)
        # The per-seat empties each section makes are the individual players —
        # grab them before place_section parents them under the section empty.
        for o in bpy.data.objects:
            if o not in before and o.type == 'EMPTY' and o.parent is None:
                player_empties.append((_target_key(name, o.name), o))
        _, wb = place_section(name, before)
        bounds.append(wb)
        targets[name] = wb
        if update_fn is not None:
            updates.append(update_fn)

    # Player bounds must be read after every section transform is applied.
    bpy.context.view_layer.update()
    for key, empty in player_empties:
        try:
            targets[key] = _obj_world_bounds(empty)
        except ValueError:
            pass          # empty with no meshes under it (a bare pivot)

    cam, backdrop, follow = build_stage_env(bounds)

    if args.dump_layout:
        _dump_layout(args.dump_layout, targets, args.res_x, args.res_y)
        return

    if args.export_gltf:
        _export_gltf(args.export_gltf)
        return

    if args.list_targets:
        for k in sorted(targets):
            b = targets[k]
            print(f"  {k:28s} {b[1] - b[0]:6.2f} wide x {b[5] - b[4]:5.2f} tall")
        print(f"[stage] {len(targets)} targets (plus 'wide')")
        # Check the cue sheet here too: this is the one mode that builds every
        # target without rendering, so it is the cheapest place to find out a
        # cue names something that does not exist.
        cues = build_cue_sheet(targets)
        check_cues(cues, targets)
        for c in cues:
            print(f"    {_mmss(c[0])}  {c[1]}"
                  f"{'' if c[2] == 0 else f'  (move {c[2]}s)'}")
        print(f"[stage] cue sheet OK: {len(cues)} shots")
        return

    # Backdrop colour runs on wall-clock time, independent of the cue sheet.
    updates.append(lambda t: update_backdrop(backdrop, t))

    # Volume gate: the generator only points the camera at players that are
    # actually sounding. Hand cues are never gated — they are your call.
    vmap = voice_map()
    activity = load_activity(args.npy, args.tempo) if animate else None
    if args.dump_activity:
        _dump_activity(args.dump_activity, targets, vmap, activity, args.duration)
        return
    cues = build_cue_sheet(targets, vmap, activity)
    check_cues(cues, targets)
    if len(cues) > 1:
        cuts = sum(1 for c in cues if c[2] == 0.0)
        print(f"[stage] camera: {len(cues)} shots ({cuts} cuts, {len(cues) - cuts} moves)")
        for c in cues:
            print(f"    {int(c[0] // 60)}:{c[0] % 60:05.2f}  {c[1]}"
                  f"{'' if c[2] == 0 else f'  (move {c[2]}s)'}")
        updates.append(lambda t: update_camera(cam, t, cues, targets,
                                               args.res_x, args.res_y))
    # The follow spot rides the cue sheet even when there is only one shot.
    updates.append(lambda t: update_follow(follow, t, cues, targets))

    scene = bpy.context.scene
    if args.look == "studio":
        _apply_look(scene)
    scene.render.engine = _configure_engine(scene, args)
    scene.render.resolution_x = args.res_x
    scene.render.resolution_y = args.res_y
    scene.render.fps = FPS
    if args.look == "stage":
        scene.view_settings.view_transform = 'Standard'
    scene.render.image_settings.file_format = 'PNG'

    if not animate:
        update_backdrop(backdrop, 0.0)
        update_follow(follow, 0.0, cues, targets)
        scene.render.filepath = str(Path(args.out).resolve())
        bpy.ops.render.render(write_still=True)
        print(f"[stage] wrote still {args.out}")
        return

    n_frames = int(np.ceil(args.duration * FPS))
    f0 = max(0, args.frame_start)
    f1 = n_frames - 1 if args.frame_end is None else min(args.frame_end, n_frames - 1)
    if f1 < f0:
        raise SystemExit(f"empty frame range {f0}..{f1}")
    n_todo = f1 - f0 + 1
    render_t0 = time.time()

    if args.mp4:
        _render_video(scene, updates, f0, f1, args.mp4)
        print(f"[stage] done: {n_todo} frames -> {args.mp4} "
              f"in {time.time() - render_t0:.1f}s, total {time.time() - t0:.1f}s")
        return

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"[stage] animating frames {f0}..{f1} of {n_frames} "
          f"({args.duration:.1f}s @ {FPS}fps) -> {out_dir}/")
    for fi in range(f0, f1 + 1):
        t = fi / FPS
        for update in updates:
            update(t)
        scene.render.filepath = str(out_dir / f"frame_{fi:06d}.png")
        bpy.ops.render.render(write_still=True)
        if fi % 30 == 0:
            print(f"  frame {fi}/{n_frames}  t={t:.2f}s  elapsed={time.time() - render_t0:.1f}s")
    total = time.time() - render_t0
    print(f"[stage] done: {n_todo} frames in {total:.1f}s "
          f"({total / max(n_todo, 1):.3f}s/frame), total {time.time() - t0:.1f}s")


def _render_video(scene, updates, f0, f1, out_path):
    """Render straight to an .mp4 using Blender's bundled ffmpeg. Because the
    animation is procedural (each frame is computed in Python, not keyframed),
    a frame_change_pre handler runs the section updates for the current frame,
    then Blender's animation render encodes it into the movie. Video-only."""
    out_path = Path(out_path).resolve()
    r = scene.render
    # Some Blender builds ship without ffmpeg (notably Fedora's package, which
    # strips the patent-encumbered codecs) — 'FFMPEG' won't be in the enum.
    # Official blender.org builds (e.g. the pod's) have it.
    fmts = {e.identifier for e in
            bpy.types.ImageFormatSettings.bl_rna.properties['file_format'].enum_items}
    if 'FFMPEG' not in fmts:
        raise SystemExit(
            "[stage] --mp4 needs a Blender built with ffmpeg; this build has none "
            "(Fedora's package strips it). Render PNG frames (drop --mp4) and mux "
            "with external ffmpeg, or use an official blender.org build.")
    r.image_settings.file_format = 'FFMPEG'
    r.ffmpeg.format = 'MPEG4'
    r.ffmpeg.codec = 'H264'
    r.ffmpeg.constant_rate_factor = 'HIGH'
    r.ffmpeg.gopsize = 15
    scene.frame_start, scene.frame_end = f0, f1
    # Blender appends the frame range to movie filenames; write to a temp dir
    # then rename to the exact path the caller asked for.
    r.use_file_extension = True
    r.filepath = str(out_path.with_suffix(""))   # basename; Blender adds NNNN-NNNN.mp4
    print(f"[stage] animating frames {f0}..{f1} -> {out_path.name} (direct mp4)")

    def _frame_update(scn, *a):
        t = scn.frame_current / FPS
        for update in updates:
            update(t)

    bpy.app.handlers.frame_change_pre.append(_frame_update)
    try:
        bpy.ops.render.render(animation=True)
    finally:
        bpy.app.handlers.frame_change_pre.remove(_frame_update)

    # Rename Blender's <basename>0000-00NN.mp4 to the requested filename.
    stem = out_path.with_suffix("").name
    produced = sorted(out_path.parent.glob(f"{stem}*.mp4"))
    if produced and produced[-1] != out_path:
        produced[-1].replace(out_path)


def _dump_activity(path, targets, vmap, activity, duration, bucket=1.0):
    """Per-target volume over time -> JSON, for plot_activity.py.

    Not just on/off: most sections sound almost continuously, so a presence
    chart says little about who is worth cutting to. Each bucket holds the
    time-weighted volume (column 14 x seconds sounding / bucket), so a target
    reads loud when it is both playing a lot AND playing loudly."""
    import json
    start, end, voice, vol = activity
    n = int(math.ceil((duration or float(end.max())) / bucket))
    levels = {}
    for name in sorted(targets):
        voices = vmap.get(name)
        if not voices:
            continue
        m = np.isin(voice, voices)
        s_, e_, v_ = start[m], end[m], vol[m]
        row = np.zeros(n)
        for a, b, vv in zip(s_, e_, v_):
            lo, hi = int(a // bucket), min(int(b // bucket), n - 1)
            for k in range(max(lo, 0), hi + 1):
                overlap = min(b, (k + 1) * bucket) - max(a, k * bucket)
                if overlap > 0:
                    row[k] += vv * overlap / bucket
        levels[name] = [round(float(x), 3) for x in row]
    payload = {"duration": duration, "bucket": bucket, "levels": levels,
               "cues": [[c[0], str(c[1])] for c in build_cue_sheet(targets, vmap, activity)]}
    Path(path).write_text(json.dumps(payload))
    print(f"[stage] wrote {path}: {len(levels)} targets, {n} buckets of {bucket}s")


def _export_gltf(path):
    """Write the built stage to a .glb, and report the budget the browser
    inherits: object count drives draw calls, triangle count drives fill.
    Blender renders offline at ~0.8s/frame and does not care about either;
    a page holding 60fps does, so print them before anyone ports an animator."""
    per_section = {}
    tris = 0
    dg = bpy.context.evaluated_depsgraph_get()
    for o in bpy.data.objects:
        if o.type != 'MESH':
            continue
        root = o
        while root.parent is not None:
            root = root.parent
        section = root.name.split('.')[0]
        me = o.evaluated_get(dg).to_mesh()
        me.calc_loop_triangles()
        n = len(me.loop_triangles)
        o.evaluated_get(dg).to_mesh_clear()
        tris += n
        count, total = per_section.get(section, (0, 0))
        per_section[section] = (count + 1, total + n)

    # export_yup=False keeps Blender's Z-up instead of rotating to glTF's Y-up.
    # stage_preview.html runs the whole scene Z-up so its numbers match the ones
    # you paste back here, and an axis swap on the way out would need undoing on
    # the way in — exactly where sign errors breed.
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_yup=False)

    meshes = sum(c for c, _ in per_section.values())
    print(f"\n[gltf] {path}  —  {meshes} mesh objects, {tris:,} triangles")
    for name in sorted(per_section, key=lambda k: -per_section[k][1]):
        count, total = per_section[name]
        print(f"    {name:24s} {count:5d} objects  {total:9,d} tris")
    try:
        print(f"[gltf] file size: {os.path.getsize(path) / 1e6:.1f} MB")
    except OSError:
        pass


def _dump_layout(path, targets, res_x, res_y):
    """The stage as numbers, for stage_preview.html: one box per camera
    target plus the camera and every light. Written from the built scene, so
    it cannot drift from what actually renders the way a hand-copied table of
    box sizes does."""
    import json
    payload = {
        "dumped": time.strftime("%b %d %H:%M:%S"),
        "cue_count": len(CAMERA_CUES),
        "targets": {k: [round(v, 3) for v in b] for k, b in sorted(targets.items())},
        "sections": {k: dict(v) for k, v in SECTIONS.items()},
        "aspect": res_x / res_y,
        "cam": {"pos": list(CAM_POS), "target": list(CAM_TARGET),
                "lens": CAM_LENS, "sensor": CAM_SENSOR},
        "wash": [{"name": n, "color": list(c), "energy": e, "pos": list(p),
                  "aim": list(a), "cone": cone, "shadow": sh}
                 for n, c, e, p, a, cone, sh in WASH_SPOTS],
        "suns": [{"name": n, "color": list(c), "energy": e, "pitch": pi,
                  "yaw": ya, "angle": an, "shadow": sh}
                 for n, c, e, pi, ya, an, sh in SUNS],
        "follow": {"offset": list(FOLLOW_OFFSET), "energy": FOLLOW_ENERGY,
                   "color": list(FOLLOW_COLOR), "margin": FOLLOW_CONE_MARGIN},
        "backdrop": {"y": BACKDROP_Y, "w": BACKDROP_W, "h": BACKDROP_H,
                     "colors": [list(c) for c in BACKDROP_COLORS],
                     "hold": BACKDROP_HOLD, "strength": BACKDROP_STRENGTH},
        "margin": CAMERA_MARGIN,
        # _shot_progress falls back to sum(CAMERA_HOLD) * 2 for the last cue,
        # so the preview needs it to time a closing pan the same way.
        "hold": list(CAMERA_HOLD),
        # The resolved cue sheet, so the preview can step through the actual
        # shots. focus is always a list: ["wide"], ["pizz", "finger_piano"],
        # or ["overhead", a, b] — the marker stays in place, as in the tuple.
        "cues": [{"t": c[0], "move": c[2],
                  "focus": [c[1]] if isinstance(c[1], str) else list(c[1])}
                 for c in build_cue_sheet(targets)],
    }
    Path(path).write_text(json.dumps(payload, indent=1))
    print(f"[stage] wrote {path}: {len(payload['targets'])} boxes, "
          f"{len(WASH_SPOTS)} wash spots, {len(SUNS)} suns")


def _static_build(name, setup):
    """Layout-check path: run the section's setup with no notes so it just
    builds geometry (setup_* tolerate npy=None -> empty note arrays)."""
    setup(None, None)
    return None


if __name__ == "__main__":
    main()
