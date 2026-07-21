#!/usr/bin/env python3
"""
stage_layout.py — canonical on-stage layout for the 8-section orchestra.

All positions are in SCREEN space: y-down, 0 = top of canvas, H = bottom
(matching how the final composited merged_poc.mp4 frames are read).

Sections render in one of two coordinate systems:
  y-up   (ax.set_ylim(0, H)): marimba, finger_piano, bass, woodwind
         -> convert a screen row `s` to data-y via yup(s) = H - s
  y-down (ax.set_ylim(H, 0)): string_section_poc
         -> data-y == screen row (use ydown(s), which is the identity)

The orchestra is three rows of sections, each section having a far
(back / farther / smaller) and near (front / closer / larger) sub-row:

      back row   (3 sections): pizz strings | marimbas | bass
      middle row (3 sections): finger pianos | woodwinds | brass
      front row  (2 sections): bowed strings | melody

Every section in a row shares the same far/near elevations, so the rows
line up across sections.  Future sections import this module and place
their rows at ROW_*_Y_FAR / ROW_*_Y_NEAR and their columns at the
matching *_X slot, and they will align automatically.
"""
W, H, DPI = 1280, 720, 96   # must match marimba_poc.W / .H / .DPI

# ── Row elevations (screen rows; smaller = higher on screen = farther) ────────
# The back row sits a little below the very top so the tall string instruments
# (neck + body) clear the canvas edge; marimbas/bass are short and could sit
# higher, but sharing the elevation keeps the back row aligned.  Adjust these
# three lines to re-space the whole orchestra — every section follows.
ROW_BACK_Y_FAR,  ROW_BACK_Y_NEAR  = 75, 147    # back row:   strings, marimbas, bass
ROW_MID_Y_FAR,   ROW_MID_Y_NEAR   = 255, 355   # middle row: finger pianos, woodwinds, <future>
ROW_FRONT_Y_FAR, ROW_FRONT_Y_NEAR = 517, 617   # front row:  bowed strings, melody  (+72 px = 10% of H, toward bottom)

# ── Column x-centres for each slot within a row (left / centre / right) ───────
# BACK_X[2] is nominal/unused: bass_section_poc.py hardcodes its own ROW_X0/
# GUITAR_REGION_X0 (shifted left of this column to avoid tine-rack overlap)
# instead of reading BACK_X, so it's documentation only at this point.
BACK_X  = (180, 640, 1100)   # strings, marimbas, bass
# MID_X[2] / FRONT_X[1] = 1024: the actual x-centre of bass_section_poc.py's
# instrument cluster (mean of its 4 tine-piano seats + 4 baritone-guitar
# centres), not the original nominal 1100 — brass and melody are pulled in
# to sit under bass now that bass itself has drifted left.
MID_X   = (180, 640, 1024)   # finger pianos, woodwinds, brass
FRONT_X = (280, 1024)      # bowed strings, melody (melody aligned with brass column MID_X[2])


def yup(screen_y):
    """Screen row -> y-up data-y (for sections using ax.set_ylim(0, H))."""
    return H - screen_y


def ydown(screen_y):
    """Screen row -> y-down data-y (for the string section, ax.set_ylim(H, 0))."""
    return screen_y
