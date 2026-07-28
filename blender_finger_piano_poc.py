#!/usr/bin/env python3
"""
blender_finger_piano_poc.py — the regular finger piano (kalimba, csound
voice 1, register C4..C8) as a Blender stage section.

Geometrically this IS the bass finger piano: the same consolidated
49-position two-rank tine rack (pitch_bucket.py), the same cantilever pluck
vibration. So rather than duplicate ~200 lines of tine/mesh/animation code,
this module reuses the machinery from blender_bass_section_poc, passing a
higher register (bottom octave 4 instead of 1) and its own colour scheme,
and skips the baritone guitar. The bass finger piano (voice 24) stays
paired with the guitar in blender_bass_section_poc.py.

Standalone smoke test (renders one still):
    blender --background --python blender_finger_piano_poc.py -- --still out.png
"""
import argparse
import math
import sys
from pathlib import Path

import bpy
import mathutils

REPO_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_DIR))

import blender_bass_section_poc as bass
import pitch_bucket as pb

VOICES = (1,)                              # regular finger piano only
BOTTOM_OCTAVE = pb.DEFAULT_BOTTOM_OCTAVE   # C4..C8


def fp_color(i, n):
    """Amber (low) -> teal (high) — deliberately distinct from the bass
    finger piano's deep-red -> indigo so the two read as different
    instruments when both are on the shared stage."""
    t = i / max(n - 1, 1)
    return (0.85 - t * 0.55, 0.55 + t * 0.12, 0.20 + t * 0.48)


def build_finger_piano(x0):
    """Build the tine rack at x0. Returns the same geom dict the bass finger
    piano returns (update_finger_piano feeds it straight back). Uses real
    piano keyboard geometry (naturals in a row, accidentals in the gaps)."""
    return bass.build_bass_finger_piano(x0, bottom_octave=BOTTOM_OCTAVE,
                                        color_fn=fp_color, piano_layout=True)


def update_finger_piano(t, geom, notes):
    bass.update_bass_finger_piano(t, geom, notes)


def load_notes(npy, tempo):
    """Voice-1 notes, bucketed onto the C4..C8 rack (same bottom octave the
    layout was built with, so pitch_to_idx keys line up)."""
    notes = bass.load_voices(npy, tempo, VOICES)
    if len(notes):
        notes[:, 1] = [pb.bucket_cents(p, bottom_octave=BOTTOM_OCTAVE) for p in notes[:, 1]]
    return notes


def _smoke_test(out_path):
    """Standalone: build the rack, drop a plain camera/light in front, render
    a single still to eyeball the geometry + colours."""
    bass.clear_scene()
    geom = build_finger_piano(0.0)
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 40
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0.0, -1.2, 0.9)
    direction = mathutils.Vector((0.0, 0.0, 0.1)) - mathutils.Vector(cam.location)
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    scene.camera = cam
    sun_data = bpy.data.lights.new("Sun", type='SUN')
    sun_data.energy = 2.5
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(52), 0, math.radians(20))
    scene.collection.objects.link(sun)
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.view_settings.view_transform = 'Standard'
    scene.render.filepath = str(Path(out_path).resolve())
    bpy.ops.render.render(write_still=True)
    print(f"[finger piano] wrote {out_path}")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--still", default="finger_piano_smoke.png")
    args = p.parse_args(argv)
    _smoke_test(args.still)
