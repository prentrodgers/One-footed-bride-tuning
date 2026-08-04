#!/usr/bin/env python3
"""
plot_activity.py — chart who is playing, and how loudly, to author
blender_stage.py's CAMERA_CUES against.

The Blender stage knows which csound voices each camera target covers; it
writes that out with --dump-activity, and this draws it. Two steps, because
matplotlib doesn't exist inside Blender's bundled Python and bpy doesn't
exist outside it:

    blender --background --python blender_stage.py -- \\
        --npy Uploads/ball9-t56c_..._t118.npy --tempo 118 --duration 475.0 \\
        --dump-activity activity.json

    .venv/bin/python plot_activity.py activity.json -o activity.png

Every row is a name you can put straight into CAMERA_CUES. Bar THICKNESS is
volume (features column 14, weighted by how much of each second is sounding),
so a fat bar means loud and busy and a hairline means technically playing but
barely there. Presence alone would be nearly useless here — most sections
sound almost continuously.

Sections and individual players are scaled separately: a section sums several
voices, so on one shared scale every solo player would look like a whisper.
Compare rows within a group, not across.
"""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

SECTION_COLORS = {
    "pizz": "#e06c75", "bowed_strings": "#c678dd", "bass": "#d19a66",
    "finger_piano": "#e5c07b", "marimba": "#98c379", "brass": "#61afef",
    "woodwind": "#56b6c2", "melody": "#abb2bf", "conductor": "#7f848e",
}


def mmss(x, _pos=None):
    return f"{int(x // 60)}:{int(x % 60):02d}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("json_path")
    ap.add_argument("-o", "--out", default="activity.png")
    ap.add_argument("--sections-only", action="store_true",
                    help="drop the per-player rows, keep the sections")
    args = ap.parse_args()

    data = json.loads(Path(args.json_path).read_text())
    levels = {k: np.asarray(v) for k, v in data["levels"].items()}
    bucket = data.get("bucket", 1.0)
    duration = data.get("duration") or max(len(v) for v in levels.values()) * bucket

    names = [n for n in levels if not args.sections_only or "." not in n]
    names.sort(key=lambda n: (n.split(".")[0], "." in n, n))

    # Separate scales: a section sums several voices and would otherwise
    # dwarf every solo player into invisibility.
    sec_max = max((levels[n].max() for n in names if "." not in n), default=1.0) or 1.0
    ply_max = max((levels[n].max() for n in names if "." in n), default=1.0) or 1.0

    fig, ax = plt.subplots(figsize=(17, 0.36 * len(names) + 2.4))
    t = np.arange(len(next(iter(levels.values())))) * bucket

    for i, name in enumerate(names):
        colour = SECTION_COLORS.get(name.split(".")[0], "#888888")
        is_section = "." not in name
        h = levels[name] / (sec_max if is_section else ply_max)
        h = np.clip(h, 0.0, 1.0) * 0.86
        ax.bar(t, h, bottom=i - h / 2.0, width=bucket, align="edge",
               color=colour, alpha=0.95 if is_section else 0.7, linewidth=0)
        ax.axhline(i, color=colour, lw=0.3, alpha=0.35, zorder=0)

    # Cues past the end of the piece would print their labels out in the
    # margin with no line under them — the cue sheet in blender_stage.py is
    # usually still the one written for some longer piece.
    for tc, label in data.get("cues", []):
        if tc > data["duration"]:
            continue
        ax.axvline(tc, color="#222222", lw=1.0, ls="--", alpha=0.7, zorder=3)
        ax.text(tc, len(names) - 0.2, f" {label}", rotation=90, va="bottom",
                ha="left", fontsize=6, color="#222222")

    ax.set_yticks(range(len(names)))
    ax.set_yticklabels(names, fontsize=8, fontfamily="monospace")
    ax.set_ylim(-0.9, len(names) + 3.2)
    ax.set_xlim(0, duration)
    ax.xaxis.set_major_locator(plt.MultipleLocator(30))
    ax.xaxis.set_minor_locator(plt.MultipleLocator(10))
    ax.xaxis.set_major_formatter(plt.FuncFormatter(mmss))
    ax.grid(axis="x", which="major", alpha=0.35)
    ax.grid(axis="x", which="minor", alpha=0.15)
    ax.set_xlabel("time (m:ss)   — bar thickness = volume")
    ax.set_title(f"Who is playing, and how loudly — {Path(args.json_path).stem} "
                 f"({mmss(duration)})", fontsize=11)
    fig.tight_layout()
    fig.savefig(args.out, dpi=110)
    print(f"wrote {args.out}  ({len(names)} rows, {mmss(duration)})")


if __name__ == "__main__":
    main()
