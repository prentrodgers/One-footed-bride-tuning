#!/usr/bin/env python3
"""
uploads_lookup.py — find the latest rendered MP3 in Uploads/ for a given chorale.

WreckingCrew.py writes its rendered MP3s into the Uploads/ directory with names
built (see WreckingCrew.py ~line 2221 and trim.sh) like:

    ball9-t<NN><letter>_lm<lm>_r<rf><density_tag>_t<tol>_d<dur>_t<tempo:03>.mp3

where:
    <NN>        = last two digits of the BWV number  (bwv261 -> 61, bwv253 -> 53,
                  bwv846 -> 46)  — WreckingCrew.py:  mod = f'{version[-2:]}...'
    <letter>    = a single density/mod letter (a, b, c, d, ...)
    <tempo:03>  = tempo zero-padded to 3 digits, e.g. 106 -> "106"

Given a chorale name such as "bwv261", this module finds the most-recently-
modified MP3 in Uploads/ whose name matches that chorale — i.e. the file
WreckingCrew.py just wrote for the current render.

gen-video.sh, compose_stage_merge.py, and string_section_poc.py all import this
module so they share ONE definition of "the MP3 for this chorale" instead of each
hardcoding a filename or grabbing the newest *.mp3 regardless of chorale.

CLI
---
    python3 uploads_lookup.py bwv261            # print newest matching MP3 path
    python3 uploads_lookup.py bwv261 --tempo    # print just the tempo (BPM)
    python3 uploads_lookup.py bwv261 --all      # list all matches, oldest first
    python3 uploads_lookup.py bwv261 --uploads-dir /path/to/Uploads
"""
from __future__ import annotations

import argparse
import logging
import os
import re
import sys
from glob import glob

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%d %H:%M",
                     stream=sys.stderr)
log = logging.getLogger(__name__)

DEFAULT_UPLOADS_DIR = "Uploads"


def chorale_number(chorale: str) -> str:
    """'bwv261' -> '61', 'bwv253' -> '53', 'bwv846' -> '46' (last two BWV digits)."""
    m = re.fullmatch(r"\s*bwv(\d+)\s*", chorale, re.IGNORECASE)
    if not m:
        raise ValueError(f"Not a BWV chorale name (expected 'bwv###'): {chorale!r}")
    return m.group(1)[-2:].zfill(2)


def _mp3_regex(chorale: str) -> re.Pattern:
    # ball9-t<NN><letter>_....mp3  — <letter> is a single non-digit (density tag).
    # Anchored so "t61" never accidentally matches "t610" or "t611".
    num = re.escape(chorale_number(chorale))
    return re.compile(rf"^ball9-t{num}[A-Za-z]_.*\.mp3$")


def list_mp3s_for_chorale(chorale: str, uploads_dir: str = DEFAULT_UPLOADS_DIR) -> list[str]:
    """All top-level MP3s in uploads_dir matching chorale, sorted oldest-first."""
    regex = _mp3_regex(chorale)
    matches = [
        p for p in glob(os.path.join(uploads_dir, "*.mp3"))
        if regex.match(os.path.basename(p))
    ]
    matches.sort(key=os.path.getmtime)
    return matches


def latest_mp3_for_chorale(chorale: str, uploads_dir: str = DEFAULT_UPLOADS_DIR) -> str | None:
    """Newest MP3 in uploads_dir matching chorale, or None if there are none."""
    matches = list_mp3s_for_chorale(chorale, uploads_dir)
    return matches[-1] if matches else None


def _not_found_message(chorale: str, uploads_dir: str) -> str:
    num = chorale_number(chorale)
    return (
        f"No MP3 matching chorale {chorale!r} "
        f"(ball9-t{num}[a-z]_*.mp3) found in {uploads_dir!r}. "
        f"Render one first, e.g.:  python WreckingCrew.py --chorale_name {chorale} ..."
    )


def latest_mp3_for_chorale_strict(chorale: str, uploads_dir: str = DEFAULT_UPLOADS_DIR) -> str:
    """Like latest_mp3_for_chorale but raises FileNotFoundError if none match."""
    mp3 = latest_mp3_for_chorale(chorale, uploads_dir)
    if mp3 is None:
        raise FileNotFoundError(_not_found_message(chorale, uploads_dir))
    return mp3


def tempo_from_mp3_name(path: str) -> int:
    """Extract tempo from the trailing '_t<NNN>.mp3' token, e.g. '..._t106.mp3' -> 106."""
    base = os.path.basename(path)
    m = re.search(r"_t(\d+)\.mp3$", base)
    if not m:
        raise ValueError(
            f"Could not extract tempo from {base!r} (expected '..._t<BPM>.mp3')")
    return int(m.group(1))


def resolve_mp3(mp3: str | None = None, chorale: str | None = None,
                uploads_dir: str = DEFAULT_UPLOADS_DIR, required: bool = True) -> str | None:
    """Pick an MP3 path: an explicit `mp3` wins; otherwise look up by `chorale`.

    If `required` is True and nothing resolves, raise (FileNotFoundError if a
    chorale was given but had no match, ValueError if neither arg was given).
    If `required` is False, return None when nothing resolves.
    """
    if mp3:
        return mp3
    if chorale:
        found = latest_mp3_for_chorale(chorale, uploads_dir)
        if found is None and required:
            raise FileNotFoundError(_not_found_message(chorale, uploads_dir))
        return found
    if required:
        raise ValueError("No MP3 specified: provide --mp3 or --chorale.")
    return None


# ── CLI ───────────────────────────────────────────────────────────────────────
def _cli(argv=None) -> int:
    p = argparse.ArgumentParser(
        description="Find the latest MP3 in Uploads/ for a BWV chorale.")
    p.add_argument("chorale", help="chorale name, e.g. bwv261")
    p.add_argument("--uploads-dir", default=DEFAULT_UPLOADS_DIR,
                   help=f"directory to search (default: {DEFAULT_UPLOADS_DIR})")
    g = p.add_mutually_exclusive_group()
    g.add_argument("--tempo", action="store_true", help="print only the tempo (BPM)")
    g.add_argument("--all", action="store_true", help="list all matches, oldest first")
    args = p.parse_args(argv)

    if args.all:
        matches = list_mp3s_for_chorale(args.chorale, args.uploads_dir)
        if not matches:
            log.error(_not_found_message(args.chorale, args.uploads_dir))
            return 1
        for m in matches:
            print(m)
        return 0

    mp3 = latest_mp3_for_chorale(args.chorale, args.uploads_dir)
    if mp3 is None:
        log.error(_not_found_message(args.chorale, args.uploads_dir))
        return 1
    if args.tempo:
        try:
            print(tempo_from_mp3_name(mp3))
        except ValueError as e:
            log.error(str(e))
            return 1
    else:
        print(mp3)
    return 0


if __name__ == "__main__":
    sys.exit(_cli())
