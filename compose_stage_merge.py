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
"""
import os
import subprocess
from pathlib import Path

from PIL import Image

STR_DIR     = "str_frames"
MARIMBA_DIR = "marimba8_frames"
FINGER_DIR  = "finger8_frames"
BASS_DIR    = "bass8_frames"
WW_DIR      = "ww8_frames"
OUT_DIR     = "merged_frames"
VIDEO_OUT   = "merged_poc.mp4"
MP3         = "Uploads/ball9-t61d_lm19_r1.25_df5_t3_d00_29_t118.mp3"
FPS = 30


def main():
    Path(OUT_DIR).mkdir(exist_ok=True)
    str_frames = sorted(Path(STR_DIR).glob("frame_*.png"))
    n = len(str_frames)
    print(f"Compositing {n} frames...")

    for i, str_path in enumerate(str_frames):
        name = str_path.name
        base = Image.open(str_path).convert("RGBA")
        for layer_dir in (MARIMBA_DIR, FINGER_DIR, BASS_DIR, WW_DIR):
            layer = Image.open(Path(layer_dir) / name).convert("RGBA")
            base.alpha_composite(layer)
        base.convert("RGB").save(Path(OUT_DIR) / name)
        if i % 200 == 0:
            print(f"  {i}/{n}")

    print("Done compositing.")

    print(f"\nAssembling -> {VIDEO_OUT}")
    cmd = [
        "ffmpeg", "-y",
        "-framerate", str(FPS),
        "-i", f"{OUT_DIR}/frame_%06d.png",
        "-i", MP3,
        "-c:v", "libx264", "-preset", "fast", "-crf", "18",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k",
        "-shortest",
        VIDEO_OUT,
    ]
    print(" ".join(cmd))
    subprocess.run(cmd, check=True)
    size_mb = os.path.getsize(VIDEO_OUT) / 1024 / 1024
    print(f"Done — {VIDEO_OUT} ({size_mb:.1f} MB)")


if __name__ == "__main__":
    main()
