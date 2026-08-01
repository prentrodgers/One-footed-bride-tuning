#!/usr/bin/env python3
"""
plot_activity.py — chart who is playing when, to author blender_stage.py's
CAMERA_CUES against.

The Blender stage knows which csound voices each camera target covers; it
writes that out with --dump-activity, and this draws it. Run in two steps
because matplotlib doesn't exist inside Blender's bundled Python and bpy
doesn't exist outside it:

    blender --background --python blender_stage.py -- \\
        --npy Uploads/ball9-t56c_..._t118.npy --tempo 118 --duration 475.0 \\
        --dump-activity activity.json

    .venv/bin/python plot_activity.py activity.json -o activity.png

Every row is a name you can put straight into CAMERA_CUES. Bars are where that
target actually sounds, so a cue is only worth writing where its row is solid.
Existing cues are drawn as vertical lines, which makes it obvious when one has
landed on a silence.
"""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

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
                    help="drop the per-player rows, keep the 9 sections")
    args = ap.parse_args()

    data = json.loads(Path(args.json_path).read_text())
    targets = data["targets"]
    duration = data.get("duration") or max(
        (b for iv in targets.values() for _, b in iv), default=60.0)

    names = [n for n in targets if not args.sections_only or "." not in n]
    # Sections first, then their players, so related rows sit together.
    names.sort(key=lambda n: (n.split(".")[0], "." in n, n))

    fig, ax = plt.subplots(figsize=(16, 0.34 * len(names) + 2.2))
    for i, name in enumerate(names):
        colour = SECTION_COLORS.get(name.split(".")[0], "#888888")
        is_section = "." not in name
        ax.broken_barh([(a, max(b - a, 0.15)) for a, b in targets[name]],
                       (i - 0.38, 0.76),
                       facecolors=colour, alpha=1.0 if is_section else 0.55,
                       edgecolor="none")

    for t, label in data.get("cues", []):
        ax.axvline(t, color="#222222", lw=1.0, ls="--", alpha=0.7, zorder=3)
        ax.text(t, len(names) - 0.2, f" {label}", rotation=90, va="bottom",
                ha="left", fontsize=6, color="#222222")

    ax.set_yticks(range(len(names)))
    ax.set_yticklabels(names, fontsize=8, fontfamily="monospace")
    ax.set_ylim(-0.8, len(names) + 3.0)
    ax.set_xlim(0, duration)
    ax.xaxis.set_major_locator(plt.MultipleLocator(30))
    ax.xaxis.set_minor_locator(plt.MultipleLocator(10))
    ax.xaxis.set_major_formatter(plt.FuncFormatter(mmss))
    ax.grid(axis="x", which="major", alpha=0.35)
    ax.grid(axis="x", which="minor", alpha=0.15)
    ax.set_xlabel("time (m:ss)")
    ax.set_title(f"Who is playing when — {Path(args.json_path).stem} "
                 f"({mmss(duration)})", fontsize=11)
    fig.tight_layout()
    fig.savefig(args.out, dpi=110)
    print(f"wrote {args.out}  ({len(names)} rows, {mmss(duration)})")


if __name__ == "__main__":
    main()
