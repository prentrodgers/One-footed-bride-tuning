#!/usr/bin/env python3
"""Convert WreckingCrew notes_features numpy arrays into a LilyPond SATB score.

The exporter reduces dense orchestral rows to one monophonic line per staff
at each onset (S, A, T, B) so the engraving reads like chorale voices.

Expected input schema is WreckingCrew notes_features (N, 15):
- col 1: start time (beats) after fix_start_times
- col 2: hold duration (beats * 1.01)
- col 3: velocity
- col 4: cent value in octave [0,1200)
- col 5: octave
"""

from __future__ import annotations

import argparse
from collections import defaultdict
import math
from pathlib import Path
import re

import numpy as np

PC_NAMES_12 = ["c", "cis", "d", "dis", "e", "f", "fis", "g", "gis", "a", "ais", "b"]
PC_NAMES_24 = [
    "c", "cih", "cis", "cisih",
    "d", "dih", "dis", "disih",
    "e", "eih", "f", "fih",
    "fis", "fisih", "g", "gih",
    "gis", "gisih", "a", "aih",
    "ais", "aisih", "b", "bih",
]

# Cent-distance mapping provided by user. Glyphs are Sagittal font PUA codepoints.
SAGITTAL_OFFSET_TABLE = [
    {"cents": 8.1, "up": "E300", "down": "E301", "description": "kleisma"},
    {"cents": 22.0, "up": "E302", "down": "E303", "description": "comma"},
    {"cents": 27.264, "up": "E304", "down": "E305", "description": ""},
    {"cents": 43.013, "up": "E306", "down": "E307", "description": "small diesis"},
    {"cents": 48.770, "up": "E308", "down": "E309", "description": "medium diesis"},
    {"cents": 53.273, "up": "E30A", "down": "E30B", "description": "enharmonic diesis"},
    {"cents": 60.413, "up": "E30C", "down": "E30D", "description": "large diesis"},
    {"cents": 64.015, "up": "E30E", "down": "E30F", "description": "chromatic semitone"},
]

# Quarter-length to lilypond duration token.
DUR_MAP = {
    0.25: "16",
    0.5: "8",
    0.75: "8.",
    1.0: "4",
    1.5: "4.",
    2.0: "2",
    3.0: "2.",
    4.0: "1",
}

MEASURE_BEATS = 4.0
EPS = 1e-9

KRUMHANSL_MAJOR = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
KRUMHANSL_MINOR = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])

MAJOR_KEY_ACCIDENTAL_COUNT = {
    "c": 0,
    "g": 1,
    "d": 2,
    "a": 3,
    "e": 4,
    "b": 5,
    "fis": 6,
    "cis": 7,
    "f": -1,
    "ais": -2,
    "dis": -3,
    "gis": -4,
}

MINOR_KEY_ACCIDENTAL_COUNT = {
    "a": 0,
    "e": 1,
    "b": 2,
    "fis": 3,
    "cis": 4,
    "gis": 5,
    "dis": 6,
    "ais": 7,
    "d": -1,
    "g": -2,
    "c": -3,
    "f": -4,
}

# Preferred SATB mapping for short_repeats woodwind section in WreckingCrew:
# flut1=14 (S), clar1=13 (A), oboe1=15 (T), basn1=12 (B)
SHORT_REPEATS_SATB_MAP = {14: "S", 13: "A", 15: "T", 12: "B"}


def parse_csv_ints(text: str) -> set[int]:
    """Parse comma-separated ints into a set."""
    out: set[int] = set()
    for raw in str(text).split(","):
        token = raw.strip()
        if not token:
            continue
        out.add(int(token))
    return out


def parse_voice_lane_specs(specs: list[str] | None) -> dict[int, str]:
    """Parse specs like ['15:low', '12:high', '27:ignore'] into a mapping."""
    if not specs:
        return {}

    out: dict[int, str] = {}
    for spec in specs:
        text = str(spec).strip()
        if not text:
            continue
        if ":" not in text:
            raise ValueError(
                f"Invalid --voice_lane_filter '{text}'. Use '<voice_id>:<low|high|ignore>'"
            )
        left, right = text.split(":", 1)
        vid = int(left.strip())
        lane = right.strip().lower()
        if lane not in {"low", "high", "ignore"}:
            raise ValueError(
                f"Invalid lane '{lane}' in --voice_lane_filter '{text}'. Use low, high, or ignore"
            )
        out[vid] = lane
    return out


def parse_satb_voice_map(text: str) -> dict[int, str] | None:
    """Parse 'S:14,A:13,T:15,B:12' into a voice->SATB mapping."""
    raw = str(text).strip()
    if not raw:
        return None

    part_to_voice: dict[str, int] = {}
    for token in raw.split(","):
        item = token.strip()
        if not item:
            continue
        if ":" not in item:
            raise ValueError(
                f"Invalid --satb_voice_map token '{item}'. Use '<S|A|T|B>:<voice_id>'"
            )
        part, voice = item.split(":", 1)
        p = part.strip().upper()
        if p not in {"S", "A", "T", "B"}:
            raise ValueError(f"Invalid SATB part '{p}' in --satb_voice_map")
        if p in part_to_voice:
            raise ValueError(f"Duplicate SATB part '{p}' in --satb_voice_map")
        part_to_voice[p] = int(voice.strip())

    required = {"S", "A", "T", "B"}
    if set(part_to_voice.keys()) != required:
        missing = sorted(required - set(part_to_voice.keys()))
        raise ValueError(f"--satb_voice_map must define all parts S,A,T,B; missing: {', '.join(missing)}")

    voice_ids = list(part_to_voice.values())
    if len(set(voice_ids)) != 4:
        raise ValueError("--satb_voice_map must use 4 distinct voice IDs")

    return {vid: part for part, vid in part_to_voice.items()}


def to_lily_octave(octave: int) -> str:
    """Map scientific octave to lilypond octave marks.

    LilyPond's c' is middle C (C4), so marks = octave - 3.
    """
    marks = octave - 3
    if marks > 0:
        return "'" * marks
    if marks < 0:
        return "," * (-marks)
    return ""


def signed_deviation_from_12tet(cent_value: float) -> float:
    """Return signed deviation in cents from nearest 12-TET pitch class."""
    wrapped = float(cent_value) % 1200.0
    return ((wrapped + 50.0) % 100.0) - 50.0


def pick_sagittal_glyph_hex(deviation_cents: float, tolerance_cents: float = 3.0) -> str | None:
    """Pick closest Sagittal offset-glyph hex code for a signed cent deviation."""
    if abs(float(deviation_cents)) < 1e-9:
        return None

    target = abs(float(deviation_cents))
    best = min(SAGITTAL_OFFSET_TABLE, key=lambda row: abs(float(row["cents"]) - target))
    if abs(float(best["cents"]) - target) > float(tolerance_cents):
        return None
    if deviation_cents > 0:
        return str(best["up"])
    return str(best["down"])


def pick_sagittal_glyph_hex_with_near_12tet(
    deviation_cents: float,
    tolerance_cents: float = 3.0,
    near_12tet_cents: float = 13.6,
    force_closest_if_unmatched: bool = True,
) -> str | None:
    """Pick Sagittal glyph with fallback around 12-TET anchor.

    If a deviation is very close to 12-TET (<= near_12tet_cents), force
    E300/E301 so near-equal notes still display a Sagittal sign.
    """
    dev = float(deviation_cents)
    if abs(dev) < 1e-9:
        return None

    if abs(dev) <= float(near_12tet_cents):
        return "E300" if dev > 0 else "E301"

    picked = pick_sagittal_glyph_hex(dev, tolerance_cents=tolerance_cents)
    if picked is not None or not force_closest_if_unmatched:
        return picked

    # If strict tolerance misses, still assign the closest Sagittal offset so
    # microtonal notes keep an explicit non-12TET sign.
    target = abs(dev)
    best = min(SAGITTAL_OFFSET_TABLE, key=lambda row: abs(float(row["cents"]) - target))
    return str(best["up"] if dev > 0 else best["down"])


def cent_to_pitch_and_dev(cent_value: float, octave: int, micro_step_cents: float = 100.0) -> tuple[str, int]:
    """Return lilypond pitch token and cent deviation from snapped pitch grid.

    For 100-cent steps (default), this anchors note names to 12-TET pitch classes.
    For 50-cent steps, emits Dutch quarter-tone suffixes.
    """
    step = float(micro_step_cents)
    if step <= 0:
        raise ValueError("micro_step_cents must be > 0")

    steps_per_oct = int(round(1200.0 / step))
    abs_cents = float(octave) * 1200.0 + float(cent_value)
    abs_steps = int(np.rint(abs_cents / step))
    out_oct = int(np.floor(abs_steps / steps_per_oct))
    pc_step = int(abs_steps % steps_per_oct)

    if steps_per_oct == 24:
        pitch = f"{PC_NAMES_24[pc_step]}{to_lily_octave(out_oct)}"
        snapped_cent = float((pc_step * step) % 1200.0)
        nearest_12 = int(np.floor((snapped_cent + 50.0) / 100.0)) % 12
        dev = int(round(snapped_cent - nearest_12 * 100.0))
        return pitch, dev

    # 12-TET (and non-quarter fallback): nearest semitone anchor.
    abs_cents_12 = float(octave) * 1200.0 + float(cent_value)
    abs_semitones = int(np.rint(abs_cents_12 / 100.0))
    out_oct_12 = int(np.floor(abs_semitones / 12.0))
    pc12 = int(abs_semitones % 12)
    dev = int(round(signed_deviation_from_12tet(float(cent_value))))
    pitch = f"{PC_NAMES_12[pc12]}{to_lily_octave(out_oct_12)}"
    return pitch, dev


def quantize_duration(beats: float) -> float:
    """Quantize to the closest duration supported by DUR_MAP."""
    keys = np.array(list(DUR_MAP.keys()), dtype=float)
    idx = int(np.argmin(np.abs(keys - beats)))
    return float(keys[idx])


def split_beats_to_tokens(beats: float) -> list[float]:
    """Split a beat span into LilyPond duration-token beat values."""
    remaining = float(beats)
    if remaining <= EPS:
        return []

    out: list[float] = []
    choices = sorted(DUR_MAP.keys(), reverse=True)
    guard = 0
    while remaining > EPS and guard < 64:
        guard += 1
        chosen = None
        for c in choices:
            if c <= remaining + EPS:
                chosen = c
                break
        if chosen is None:
            chosen = quantize_duration(remaining)
        out.append(float(chosen))
        remaining -= float(chosen)
    return out


def beats_to_barline(time_beats: float, measure_beats: float = MEASURE_BEATS) -> float:
    rem = measure_beats - (float(time_beats) % measure_beats)
    if rem <= EPS:
        rem = measure_beats
    return rem


def estimate_key_signature(features: np.ndarray) -> tuple[str, str]:
    """Estimate key from pitch-class distribution using Krumhansl profiles."""
    audible = features[(features[:, 5] > 0) & (features[:, 3] > 0)]
    if audible.size == 0:
        return "c", "major"

    pc_counts = np.zeros(12, dtype=float)
    for r in audible:
        pc = int(np.rint(float(r[4]) / 100.0)) % 12
        pc_counts[pc] += 1.0

    if np.sum(pc_counts) <= EPS:
        return "c", "major"

    best_mode = "major"
    best_tonic = 0
    best_score = -1e18
    for tonic in range(12):
        major_score = float(np.dot(pc_counts, np.roll(KRUMHANSL_MAJOR, tonic)))
        minor_score = float(np.dot(pc_counts, np.roll(KRUMHANSL_MINOR, tonic)))
        if major_score > best_score:
            best_score = major_score
            best_mode = "major"
            best_tonic = tonic
        if minor_score > best_score:
            best_score = minor_score
            best_mode = "minor"
            best_tonic = tonic

    tonic_name = PC_NAMES_12[best_tonic]
    return tonic_name, best_mode


def parse_key_signature(text: str) -> tuple[str, str]:
    """Parse a key signature string like 'd major' or 'fis minor'."""
    parts = text.strip().lower().split()
    if len(parts) != 2:
        raise ValueError("--key_signature must look like '<tonic> <major|minor>'")
    tonic, mode = parts
    if tonic not in set(PC_NAMES_12):
        raise ValueError(f"Unsupported tonic '{tonic}'. Use one of: {', '.join(PC_NAMES_12)}")
    if mode not in {"major", "minor"}:
        raise ValueError("Mode must be 'major' or 'minor'")
    return tonic, mode


def row_pitch_number(row: np.ndarray) -> float:
    """Approximate chromatic pitch number from cents+octave for ordering."""
    cent = float(row[4])
    octv = int(round(float(row[5])))
    pc = int(np.floor((cent + 50.0) / 100.0)) % 12
    return float(octv * 12 + pc)


def key_signature_altered_pcs(key_signature: tuple[str, str]) -> set[int]:
    """Return pitch classes altered by key signature (sharps/flats set)."""
    tonic, mode = key_signature
    mode_l = str(mode).lower()
    tonic_l = str(tonic).lower()

    if mode_l == "major":
        count = int(MAJOR_KEY_ACCIDENTAL_COUNT.get(tonic_l, 0))
    else:
        count = int(MINOR_KEY_ACCIDENTAL_COUNT.get(tonic_l, 0))

    sharp_order = [5, 0, 7, 2, 9, 4, 11]  # F C G D A E B
    flat_order = [11, 4, 9, 2, 7, 0, 5]   # B E A D G C F

    if count > 0:
        return set(sharp_order[:count])
    if count < 0:
        return set(flat_order[:(-count)])
    return set()

def sagittal_glyph_lookup() -> dict[str, tuple[float, str]]:
    """Map Sagittal glyph hex code to signed cent offset and description."""
    out: dict[str, tuple[float, str]] = {}
    for row in SAGITTAL_OFFSET_TABLE:
        cents = float(row["cents"])
        desc = str(row.get("description", "")).strip()
        out[str(row["up"])] = (cents, desc)
        out[str(row["down"])] = (-cents, desc)
    return out


def make_sagittal_legend_markup(
    used_glyphs: set[str],
    glyph_font: str,
    glyph_font_size: int,
) -> str:
    """Build LilyPond markup block listing Sagittal glyphs used in score."""
    if not used_glyphs:
        return ""

    lookup = sagittal_glyph_lookup()
    known = [g for g in used_glyphs if g in lookup]
    if not known:
        return ""

    known.sort(key=lambda g: (abs(lookup[g][0]), lookup[g][0]))

    legend_size = max(0, int(glyph_font_size) - 1)
    lines = [
        "sagittalLegend = \\markup \\column {",
        "  \\vspace #1",
        "  \\line { \\bold \"Sagittal Legend (used in this score)\" }",
    ]
    for glyph in known:
        cents, desc = lookup[glyph]
        desc_txt = f" {desc}" if desc else ""
        lines.append(
            "  \\line { "
            + f"\\override #'(font-name . \"{glyph_font}\") "
            + f"\\fontsize #{legend_size} "
            + f"\\char ##x{glyph}"
            + f" \" = {cents:+.3f}c{desc_txt}\""
            + " }"
        )
    lines.append("}")
    return "\n".join(lines)


def parse_gliss_ratio_map_from_csd(csd_path: str) -> dict[int, float]:
    """Parse Csound f-table gliss definitions and return table_id -> ratio change.

    For lines like:
    f5000.0 ... -6.0 1.0 128.0 1.000867 128.0 1.001734
    the ratio change is interpreted as end/start = 1.001734 / 1.0.
    """
    p = Path(csd_path)
    if not p.exists():
        return {}

    out: dict[int, float] = {}
    line_re = re.compile(r"^\s*f(\d+(?:\.\d+)?)\s+(.*)$")

    for line in p.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = line_re.match(line)
        if not m:
            continue
        try:
            table_id = int(float(m.group(1)))
        except ValueError:
            continue

        tail_vals: list[float] = []
        for tok in m.group(2).split():
            try:
                tail_vals.append(float(tok))
            except ValueError:
                tail_vals = []
                break
        if len(tail_vals) < 6:
            continue

        # GEN routine number is the 3rd numeric arg after table id.
        gen_num = int(round(abs(tail_vals[2])))
        if gen_num != 6:
            continue

        shape = tail_vals[3:]
        if len(shape) < 2:
            continue
        start = float(shape[0])
        end = float(shape[-1])
        if abs(start) < 1e-12:
            continue
        out[table_id] = end / start

    return out


def gliss_ratio_markup(ratio_change: float) -> str:
    """Return LilyPond markup attachment for gliss cents-only label."""
    rc = float(ratio_change)
    cents = 1200.0 * math.log2(rc) if rc > 0 else 0.0
    return f'^\\markup \\tiny \\italic "{cents:+.2f}c"'


def build_events_from_rows(
    rows: np.ndarray,
    micro_step_cents: float = 100.0,
    sagittal_tolerance_cents: float = 3.0,
    near_12tet_cents: float = 13.6,
    use_sagittal_offsets: bool = True,
    force_closest_sagittal: bool = True,
) -> list[dict]:
    """Build time-ordered note/chord events from a subset of notes_features rows."""
    if rows.size == 0:
        return []

    by_start: dict[float, list[np.ndarray]] = defaultdict(list)
    for row in rows:
        start = round(float(row[1]), 6)
        by_start[start].append(row)

    events = []
    for start in sorted(by_start.keys()):
        ev_rows = by_start[start]
        pitches = []
        devs = []
        glyph_hexes = []
        pcs = []
        gliss_ids = []
        hold = max(float(r[2]) for r in ev_rows) / 1.01
        q_hold = quantize_duration(hold)

        for r in ev_rows:
            raw_dev = signed_deviation_from_12tet(float(r[4]))
            pitch, dev = cent_to_pitch_and_dev(
                float(r[4]),
                int(round(r[5])),
                micro_step_cents=micro_step_cents,
            )
            pitches.append(pitch)
            devs.append(dev)
            pcs.append(int(np.rint(float(r[4]) / 100.0)) % 12)
            gliss_ids.append(int(round(float(r[9]))))
            if use_sagittal_offsets:
                glyph_hexes.append(
                    pick_sagittal_glyph_hex_with_near_12tet(
                        raw_dev,
                        tolerance_cents=sagittal_tolerance_cents,
                        near_12tet_cents=near_12tet_cents,
                        force_closest_if_unmatched=force_closest_sagittal,
                    )
                )
            else:
                glyph_hexes.append(None)

        pitches = sorted(set(pitches))
        events.append({
            "start": start,
            "dur_beats": q_hold,
            "pitches": pitches,
            "devs": devs,
            "glyph_hexes": glyph_hexes,
            "pcs": pcs,
            "gliss_ids": gliss_ids,
        })

    return events


def split_satb_rows(
    features: np.ndarray,
    include_voice_ids: set[int] | None = None,
    voice_lane_filters: dict[int, str] | None = None,
    satb_voice_map: dict[int, str] | None = None,
) -> dict[str, np.ndarray]:
    """Split rows into SATB groups.

    Primary mode: group by csound voice ranges inferred from median pitch per
    csound voice (quartiles over voices).

    Fallback: when fewer than 4 unique csound voices are present, split each
    simultaneous chord by pitch rank into SATB to avoid empty staves.
    """
    audible = features[(features[:, 5] > 0) & (features[:, 3] > 0)]
    if audible.size == 0:
        return {"S": np.empty((0, features.shape[1])), "A": np.empty((0, features.shape[1])),
                "T": np.empty((0, features.shape[1])), "B": np.empty((0, features.shape[1]))}

    if include_voice_ids:
        audible = audible[np.isin(audible[:, 6].astype(int), list(include_voice_ids))]

    if audible.size == 0:
        return {"S": np.empty((0, features.shape[1])), "A": np.empty((0, features.shape[1])),
                "T": np.empty((0, features.shape[1])), "B": np.empty((0, features.shape[1]))}

    lane_filters = voice_lane_filters or {}
    if lane_filters:
        by_start_voice: dict[tuple[float, int], list[np.ndarray]] = defaultdict(list)
        for r in audible:
            key = (round(float(r[1]), 6), int(r[6]))
            by_start_voice[key].append(r)

        filtered_rows: list[np.ndarray] = []
        for (_, vid), rows in sorted(by_start_voice.items(), key=lambda kv: (kv[0][0], kv[0][1])):
            lane = lane_filters.get(int(vid))
            if lane == "ignore":
                continue
            if lane in {"low", "high"} and len(rows) > 1:
                ranked = sorted(rows, key=row_pitch_number)
                filtered_rows.append(ranked[0] if lane == "low" else ranked[-1])
            else:
                filtered_rows.extend(rows)

        audible = np.array(filtered_rows, dtype=float).reshape((-1, features.shape[1])) if filtered_rows else np.empty((0, features.shape[1]))
        if audible.size == 0:
            return {"S": np.empty((0, features.shape[1])), "A": np.empty((0, features.shape[1])),
                    "T": np.empty((0, features.shape[1])), "B": np.empty((0, features.shape[1]))}

    voice_ids = sorted(set(audible[:, 6].astype(int).tolist()))
    out = {"S": [], "A": [], "T": [], "B": []}

    def pick_for_part(rows: list[np.ndarray], part: str) -> np.ndarray | None:
        if not rows:
            return None
        ranked = sorted(rows, key=row_pitch_number)
        if part in ("S", "A"):
            return ranked[-1]
        return ranked[0]

    def append_one_per_onset(by_start: dict[float, list[np.ndarray]], voice_to_satb: dict[int, str]) -> None:
        for _, rows in sorted(by_start.items()):
            part_rows = {"S": [], "A": [], "T": [], "B": []}
            for r in rows:
                satb = voice_to_satb.get(int(r[6]))
                if satb is not None:
                    part_rows[satb].append(r)

            chosen = {}
            for part in ("S", "A", "T", "B"):
                pick = pick_for_part(part_rows[part], part)
                if pick is not None:
                    chosen[part] = pick

            for part, pick in chosen.items():
                out[part].append(pick)

    if satb_voice_map is not None:
        mapped_ids = set(satb_voice_map.keys())
        mapped = audible[np.isin(audible[:, 6].astype(int), list(mapped_ids))]
        by_start: dict[float, list[np.ndarray]] = defaultdict(list)
        for r in mapped:
            by_start[round(float(r[1]), 6)].append(r)
        append_one_per_onset(by_start, satb_voice_map)
    else:
        preferred_ids = set(SHORT_REPEATS_SATB_MAP.keys())
        if preferred_ids.issubset(set(voice_ids)):
        # Deterministic SATB routing for short_repeats woodwinds.
            mapped = audible[np.isin(audible[:, 6].astype(int), list(preferred_ids))]
            by_start: dict[float, list[np.ndarray]] = defaultdict(list)
            for r in mapped:
                by_start[round(float(r[1]), 6)].append(r)
            append_one_per_onset(by_start, SHORT_REPEATS_SATB_MAP)
        elif len(voice_ids) >= 4:
            med_by_voice = []
            for vid in voice_ids:
                rows = audible[audible[:, 6].astype(int) == vid]
                med_pitch = float(np.median([row_pitch_number(r) for r in rows]))
                med_by_voice.append((vid, med_pitch))
            med_by_voice.sort(key=lambda x: x[1])

            # Low->High mapped to B,T,A,S
            chunks = np.array_split([v for v, _ in med_by_voice], 4)
            labels = ["B", "T", "A", "S"]
            voice_to_satb = {}
            for label, chunk in zip(labels, chunks):
                for vid in chunk:
                    voice_to_satb[int(vid)] = label

            by_start: dict[float, list[np.ndarray]] = defaultdict(list)
            for r in audible:
                by_start[round(float(r[1]), 6)].append(r)
            append_one_per_onset(by_start, voice_to_satb)
        else:
            # Fallback split by pitch rank at each start time.
            by_start: dict[float, list[np.ndarray]] = defaultdict(list)
            for r in audible:
                by_start[round(float(r[1]), 6)].append(r)

            for _, rows in sorted(by_start.items()):
                ranked = sorted(rows, key=row_pitch_number)
                # Low->High to B,T,A,S
                slots = ["B", "T", "A", "S"]
                for i, r in enumerate(ranked[:4]):
                    out[slots[i]].append(r)

    cols = features.shape[1]
    return {
        "S": np.array(out["S"], dtype=float).reshape((-1, cols)) if out["S"] else np.empty((0, cols)),
        "A": np.array(out["A"], dtype=float).reshape((-1, cols)) if out["A"] else np.empty((0, cols)),
        "T": np.array(out["T"], dtype=float).reshape((-1, cols)) if out["T"] else np.empty((0, cols)),
        "B": np.array(out["B"], dtype=float).reshape((-1, cols)) if out["B"] else np.empty((0, cols)),
    }


def events_to_lily(
    events: list[dict],
    glyph_font: str = "Bravura Text",
    glyph_font_size: int = 3,
    glyph_y_offset: float = -0.8,
    key_signature: tuple[str, str] = ("c", "major"),
    gliss_ratio_map: dict[int, float] | None = None,
    show_gliss_labels: bool = True,
) -> str:
    """Render events into LilyPond syntax with bar-aware split/ties."""
    if not events:
        return "r1\n  \\bar \"|.\""

    out = []
    t = 0.0
    altered_pcs = key_signature_altered_pcs(key_signature)

    def emit_rest_span(span_beats: float) -> None:
        nonlocal t
        remaining = float(span_beats)
        while remaining > EPS:
            chunk = min(remaining, beats_to_barline(t))
            for tok in split_beats_to_tokens(chunk):
                out.append(f"r{DUR_MAP[float(tok)]}")
                t += float(tok)
            remaining -= chunk

    for ev in events:
        start = float(ev["start"])
        if start > t + EPS:
            emit_rest_span(start - t)

        dur_beats = float(ev["dur_beats"])
        pitches = ev["pitches"]

        if len(pitches) == 1:
            note = pitches[0]
        else:
            note = "<" + " ".join(pitches) + ">"

        glyph_hexes = [g for g in ev.get("glyph_hexes", []) if g]
        pcs = [int(pc) for pc in ev.get("pcs", [])]
        gliss_ids = [int(g) for g in ev.get("gliss_ids", [])]
        event_pc = pcs[0] if pcs else None
        base_glyph = None
        if glyph_hexes and len(pitches) == 1:
            base_glyph = glyph_hexes[0]

        gliss_attachment = ""
        if show_gliss_labels and gliss_ratio_map and len(pitches) == 1:
            gliss_id = next((g for g in gliss_ids if g > 0), 0)
            if gliss_id in gliss_ratio_map:
                gliss_attachment = gliss_ratio_markup(gliss_ratio_map[gliss_id])

        remaining = dur_beats
        first_chunk = True
        while remaining > EPS:
            chunk = min(remaining, beats_to_barline(t))
            chunk_tokens = split_beats_to_tokens(chunk)
            for i, tok in enumerate(chunk_tokens):
                tie_needed = (remaining - tok) > EPS or i < (len(chunk_tokens) - 1)
                tie = "~" if tie_needed else ""

                # Replace the accidental glyph itself (left of notehead) on the
                # first chunk of a note, instead of drawing a symbol above note.
                if first_chunk and base_glyph and len(pitches) == 1:
                    keep_standard_acc = event_pc in altered_pcs if event_pc is not None else False
                    if keep_standard_acc:
                        out.append(
                            "\\once \\override Accidental.stencil = "
                            "#(lambda (grob) "
                            "(let* ((orig (ly:accidental-interface::print grob)) "
                            "(sag (grob-interpret-markup grob "
                            "#{ \\markup \\translate #'(0 . "
                            + str(float(glyph_y_offset))
                            + ") \\override #'(font-name . \""
                            + glyph_font
                            + "\") \\fontsize #"
                            + str(int(glyph_font_size))
                            + " \\char ##x"
                            + base_glyph
                            + " #})))"
                            "(ly:stencil-add orig (ly:stencil-translate-axis sag 0.9 X))))"
                        )
                    else:
                        out.append(
                            "\\once \\override Accidental.stencil = "
                            "#(lambda (grob) "
                            "(grob-interpret-markup grob "
                            "#{ \\markup \\translate #'(0 . "
                            + str(float(glyph_y_offset))
                            + ") \\override #'(font-name . \""
                            + glyph_font
                            + "\") \\fontsize #"
                            + str(int(glyph_font_size))
                            + " \\char ##x"
                            + base_glyph
                            + " #}))"
                        )
                    # Force accidental object so the stencil override always has
                    # a target grob; visual clutter is controlled by the stencil.
                    out.append(f"{note}!{DUR_MAP[float(tok)]}{gliss_attachment}{tie}")
                else:
                    out.append(f"{note}{DUR_MAP[float(tok)]}{gliss_attachment}{tie}")
                gliss_attachment = ""
                first_chunk = False
                t += float(tok)
                remaining -= float(tok)

    out.append('\\bar "|."')
    return "\n  ".join(out)


def make_lilypond_satb(
    score_body_satb: dict[str, str],
    title: str,
    subtitle: str,
    key_signature: tuple[str, str],
    sagittal_legend_markup: str = "",
    use_ekmelily: bool = False,
    ekmelily_include: str = "ekmel.ily",
) -> str:
    ekmel_block = ""
    if use_ekmelily:
        ekmel_block = (
            f'\\include "{ekmelily_include}"\n'
            "\\ekmelicStyle sagittal\n"
        )

    tonic, mode = key_signature
    key_decl = f"\\key {tonic} \\{mode}"
    legend_call = "\\sagittalLegend" if str(sagittal_legend_markup).strip() else ""

    return f'''\\version "2.24.0"

% Enable Sagittal accidentals with Ekmelily by passing --use_ekmelily.
{ekmel_block}

\\language "nederlands"

\\header {{
  title = "{title}"
        subtitle = "{subtitle}"
    tagline = "Generated by features_to_lilypond.py coded by GitHub Copilot with assistance from Prent"
}}

\\paper {{
  indent = 0
}}

{sagittal_legend_markup}

sopMusic = {{ \\time 4/4 \\numericTimeSignature
    {key_decl}
    {score_body_satb['S']}
}}
altoMusic = {{ \\time 4/4 \\numericTimeSignature
    {key_decl}
    {score_body_satb['A']}
}}
tenorMusic = {{ \\time 4/4 \\numericTimeSignature
    {key_decl}
    {score_body_satb['T']}
}}
bassMusic = {{ \\time 4/4 \\numericTimeSignature
    {key_decl}
    {score_body_satb['B']}
}}

\\score {{
    \\new ChoirStaff <<
        \\new Staff = "soprano" \\with {{ instrumentName = "S" }} {{ \\clef treble \\sopMusic }}
        \\new Staff = "alto"    \\with {{ instrumentName = "A" }} {{ \\clef treble \\altoMusic }}
        \\new Staff = "tenor"   \\with {{ instrumentName = "T" }} {{ \\clef "treble_8" \\tenorMusic }}
        \\new Staff = "bass"    \\with {{ instrumentName = "B" }} {{ \\clef bass \\bassMusic }}
    >>
    \\layout {{
        \\context {{
            \\ChoirStaff
            \\consists "Span_bar_engraver"
        }}
  }}
}}

{legend_call}
'''


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert notes_features npy to LilyPond .ly")
    parser.add_argument("--input", required=True, help="Input features .npy file")
    parser.add_argument("--output", required=True, help="Output .ly file")
    parser.add_argument("--title", default="WreckingCrew Export", help="Score title")
    parser.add_argument(
        "--subtitle",
        default="SATB reduction from WreckingCrew features array",
        help="LilyPond subtitle text",
    )
    parser.add_argument(
        "--key_signature",
        default="",
        help="Optional explicit key signature: '<tonic> <major|minor>' (e.g. 'd major')",
    )
    parser.add_argument(
        "--use_ekmelily",
        action="store_true",
        help="Include Ekmelily preamble and set Sagittal style accidentals",
    )
    parser.add_argument(
        "--ekmelily_include",
        default="ekmel.ily",
        help="Path LilyPond should use in \\include for Ekmelily",
    )
    parser.add_argument(
        "--micro_step_cents",
        type=float,
        default=100.0,
        help="Microtonal spelling grid in cents (default: 100 for 12-TET anchors)",
    )
    parser.add_argument(
        "--sagittal_tolerance_cents",
        type=float,
        default=3.0,
        help="Tolerance when matching deviation to Sagittal offset table",
    )
    parser.add_argument(
        "--strict_sagittal_tolerance",
        action="store_true",
        help="Only show Sagittal when within tolerance/near-12TET fallback; disable nearest-glyph fallback",
    )
    parser.add_argument(
        "--near_12tet_cents",
        type=float,
        default=13.6,
        help="For deviations within this range, force E300/E301 near-12TET glyphs",
    )
    parser.add_argument(
        "--no_sagittal_offsets",
        action="store_true",
        help="Disable Sagittal offset-glyph mapping from 12-TET deviations",
    )
    parser.add_argument(
        "--sagittal_font",
        default="Bravura Text",
        help="Font family used for Sagittal glyph markups (default: Bravura Text)",
    )
    parser.add_argument(
        "--sagittal_font_size",
        type=int,
        default=3,
        help="LilyPond fontsize delta for Sagittal markups (default: 3)",
    )
    parser.add_argument(
        "--sagittal_y_offset",
        type=float,
        default=-0.8,
        help="Vertical offset (staff spaces) for Sagittal accidental glyph placement",
    )
    parser.add_argument(
        "--gliss_csd",
        default="new_output.csd",
        help="CSD file to read f-table gliss ratios from (default: new_output.csd)",
    )
    parser.add_argument(
        "--no_gliss_labels",
        action="store_true",
        help="Disable ratio/cents labels above notes that use gliss function tables",
    )
    parser.add_argument(
        "--include_voice_ids",
        default="",
        help="Optional comma-separated whitelist of csound voice IDs to keep (e.g. '12,13,14,15')",
    )
    parser.add_argument(
        "--voice_lane_filter",
        action="append",
        default=[],
        help="Per-voice filter: '<voice_id>:<low|high|ignore>' (repeatable)",
    )
    parser.add_argument(
        "--satb_voice_map",
        default="",
        help="Explicit SATB map '<S|A|T|B>:<voice_id>' entries, comma-separated (e.g. 'S:14,A:13,T:15,B:12')",
    )
    args = parser.parse_args()

    arr = np.load(args.input, allow_pickle=True)
    if arr.ndim != 2 or arr.shape[1] < 6:
        raise ValueError(f"Unexpected array shape {arr.shape}; expected (N, 15)-like notes_features")

    include_voice_ids = parse_csv_ints(str(args.include_voice_ids)) if str(args.include_voice_ids).strip() else None
    voice_lane_filters = parse_voice_lane_specs(list(args.voice_lane_filter))
    satb_voice_map = parse_satb_voice_map(str(args.satb_voice_map))

    satb_rows = split_satb_rows(
        arr,
        include_voice_ids=include_voice_ids,
        voice_lane_filters=voice_lane_filters,
        satb_voice_map=satb_voice_map,
    )
    glyph_font = str(args.sagittal_font)
    glyph_font_size = int(args.sagittal_font_size)
    glyph_y_offset = float(args.sagittal_y_offset)

    if str(args.key_signature).strip():
        key_signature = parse_key_signature(str(args.key_signature))
    else:
        key_signature = estimate_key_signature(arr)

    gliss_ratio_map = parse_gliss_ratio_map_from_csd(str(args.gliss_csd))

    satb_events = {
        part: build_events_from_rows(
            rows,
            micro_step_cents=float(args.micro_step_cents),
            sagittal_tolerance_cents=float(args.sagittal_tolerance_cents),
            near_12tet_cents=float(args.near_12tet_cents),
            use_sagittal_offsets=not bool(args.no_sagittal_offsets),
            force_closest_sagittal=not bool(args.strict_sagittal_tolerance),
        )
        for part, rows in satb_rows.items()
    }

    used_glyphs = {
        str(g)
        for events in satb_events.values()
        for ev in events
        for g in ev.get("glyph_hexes", [])
        if g
    }
    sagittal_legend_markup = make_sagittal_legend_markup(
        used_glyphs=used_glyphs,
        glyph_font=glyph_font,
        glyph_font_size=glyph_font_size,
    )

    satb_bodies = {
        part: events_to_lily(
            satb_events[part],
            glyph_font=glyph_font,
            glyph_font_size=glyph_font_size,
            glyph_y_offset=glyph_y_offset,
            key_signature=key_signature,
            gliss_ratio_map=gliss_ratio_map,
            show_gliss_labels=not bool(args.no_gliss_labels),
        )
        for part in satb_rows.keys()
    }
    ly_text = make_lilypond_satb(
        satb_bodies,
        args.title,
        subtitle=str(args.subtitle),
        key_signature=key_signature,
        sagittal_legend_markup=sagittal_legend_markup,
        use_ekmelily=bool(args.use_ekmelily),
        ekmelily_include=str(args.ekmelily_include),
    )

    out_path = Path(args.output)
    out_path.write_text(ly_text, encoding="utf-8")
    counts = {k: int(v.shape[0]) for k, v in satb_rows.items()}
    print(f"Wrote {out_path} with SATB rows {counts} and key {key_signature[0]} {key_signature[1]}")


if __name__ == "__main__":
    main()
