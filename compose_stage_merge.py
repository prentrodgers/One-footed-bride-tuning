#!/usr/bin/env python3
"""
compose_stage_merge.py — paste the 8-seat marimba, finger-piano, and bass
sections onto the string section frames, then assemble the merged video.

Requires str_frames/, marimba8_frames/, finger8_frames/, and bass8_frames/
(all transparent except str_frames, from string_section_poc.py /
marimba_section_poc.py / finger_piano_section_poc.py /
bass_section_poc.py) to already contain the same number of frames on the
same 30fps timeline (see SESSION_NOTES). Every seat in every section is
already laid out in absolute on-stage coordinates, so no per-frame
resize/paste-offset is needed — a straight full-frame alpha composite of
each layer is enough.

Audio track: pass --mp3 PATH, or --chorale bwvNNN to auto-select the
newest matching Uploads/*.mp3 (see uploads_lookup.py).  The previous
hardcoded MP3 path has been removed.
"""
import argparse
import os
import subprocess
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

from PIL import Image

import uploads_lookup

import logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%d %H:%M")
log = logging.getLogger(__name__)

STR_DIR     = "str_frames"
MARIMBA_DIR = "marimba8_frames"
FINGER_DIR  = "finger8_frames"
BASS_DIR    = "bass8_frames"
WW_DIR      = "ww8_frames"
BRASS_DIR   = "brass8_frames"
BOWED_DIR   = "bowed8_frames"
MELODY_DIR  = "melody8_frames"
CONDUCTOR_DIR = "conductor_frames"
OUT_DIR     = "merged_frames"
DEFAULT_VIDEO_OUT = "merged_poc.mp4"
FPS = 30
LAYER_DIRS = (MARIMBA_DIR, FINGER_DIR, BASS_DIR, WW_DIR, BRASS_DIR, BOWED_DIR, MELODY_DIR, CONDUCTOR_DIR)


def _composite_frame(name):
    """Composite one frame across all layers and save it. Module-level (not
    a closure) so it can be pickled and sent to worker processes — each call
    only touches its own frame filename, so frames composite independently
    and in any order."""
    base = Image.open(Path(STR_DIR) / name).convert("RGBA")
    for layer_dir in LAYER_DIRS:
        layer = Image.open(Path(layer_dir) / name).convert("RGBA")
        base.alpha_composite(layer)
    base.convert("RGB").save(Path(OUT_DIR) / name)
    return name


def main():
    parser = argparse.ArgumentParser(
        description="Composite the section frame layers and assemble the merged video.")
    parser.add_argument("--mp3", default=None,
                        help="Audio track for the merged video. If omitted, the "
                             "newest MP3 in Uploads/ matching --chorale is used.")
    parser.add_argument("--chorale", default=None,
                        help="Chorale name (e.g. bwv261) used to locate the audio "
                             "track when --mp3 is not given.")
    parser.add_argument("--uploads-dir", default=uploads_lookup.DEFAULT_UPLOADS_DIR,
                        help="Directory to search for the chorale MP3 "
                             f"(default: {uploads_lookup.DEFAULT_UPLOADS_DIR})")
    parser.add_argument("--out", default=DEFAULT_VIDEO_OUT,
                        help="Output video filename "
                             f"(default: {DEFAULT_VIDEO_OUT}). gen-video.sh passes "
                             "one that encodes the chorale, tempo, and duration.")
    args = parser.parse_args()
    video_out = args.out

    mp3 = uploads_lookup.resolve_mp3(
        mp3=args.mp3, chorale=args.chorale,
        uploads_dir=args.uploads_dir, required=True)
    log.info(f"Audio track    : {mp3}")

    Path(OUT_DIR).mkdir(exist_ok=True)
    names = [p.name for p in sorted(Path(STR_DIR).glob("frame_*.png"))]
    n = len(names)
    workers = os.cpu_count() or 1
    log.info(f"Compositing {n} frames across {workers} processes...")

    with ProcessPoolExecutor(max_workers=workers) as ex:
        for i, _ in enumerate(ex.map(_composite_frame, names, chunksize=16)):
            if i % 200 == 0:
                log.info(f"  {i}/{n}")

    log.info("Done compositing.")

    log.info(f"\nAssembling -> {video_out}")
    cmd = [
        "ffmpeg", "-y",
        "-framerate", str(FPS),
        "-i", f"{OUT_DIR}/frame_%06d.png",
        "-i", mp3,
        "-c:v", "libx264", "-preset", "fast", "-crf", "18",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k",
        "-shortest",
        video_out,
    ]
    log.info(" ".join(cmd))
    subprocess.run(cmd, check=True)
    size_mb = os.path.getsize(video_out) / 1024 / 1024
    log.info(f"Done — {video_out} ({size_mb:.1f} MB)")


if __name__ == "__main__":
    main()
