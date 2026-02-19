#!/usr/bin/env python3
"""Post-process tuned chorales to improve horizontal cent consistency.

Given a 4xN cent array (such as the output from new-tune-midi.py), this script
scans chords sequentially and, whenever adjacent chords share any pitch classes
per voice, searches for a single cent offset that can be applied to the entire
later chord so the shared pitch classes reuse the earlier cent values. The
search only accepts offsets that leave every pitch class unchanged, so the
harmonic spelling stays intact. Results are saved to a new .npy file alongside
an optional log of which chords were shifted.
"""

from __future__ import annotations

import argparse
import logging
import os
from dataclasses import dataclass
from typing import Iterable, List, Sequence, Tuple

import numpy as np

import adaptive_tuning_util as atu


@dataclass
class HorizontalTransposeConfig:
    source: str
    destination: str | None
    max_wrap_steps: int = 1
    log_level: str = "INFO"


def _candidate_deltas(prev: np.ndarray, curr: np.ndarray, matches: np.ndarray, wrap_steps: int) -> List[float]:
    """Return offsets that align shared pitch classes plus the no-op delta."""
    deltas = [0.0]
    shared_indices = np.where(matches)[0]
    for voice_idx in shared_indices:
        base = prev[voice_idx] - curr[voice_idx]
        for k in range(-wrap_steps, wrap_steps + 1):
            deltas.append(base + 1200.0 * k)
    return deltas


def _best_delta(prev: np.ndarray, curr: np.ndarray, wrap_steps: int) -> Tuple[float, float]:
    pcs_prev = atu.pitch_class_from_cents(prev)
    pcs_curr = atu.pitch_class_from_cents(curr)
    matches = pcs_prev == pcs_curr
    if not np.any(matches):
        return 0.0, np.inf

    best_delta = 0.0
    best_score = np.inf
    max_unmatched_shift = 35.0  # Align with max_gap threshold
    match_count = int(np.sum(matches))
    logging.debug("Evaluating chord: %d matches, wrap_steps=%d", match_count, wrap_steps)
    
    for delta in _candidate_deltas(prev, curr, matches, wrap_steps):
        shifted = np.mod(curr + delta, 1200.0)
        if not np.array_equal(atu.pitch_class_from_cents(shifted), pcs_curr):
            continue
        
        # Calculate the difference for matched voices only
        diff_matched = shifted[matches] - prev[matches]
        score_matched = float(np.sum(diff_matched * diff_matched))
        
        # Check unmatched voices: they should drift minimally or not at all
        if not np.all(matches):
            unmatched_indices = np.where(~matches)[0]
            diff_unmatched = shifted[unmatched_indices] - curr[unmatched_indices]
            max_unmatched_change = float(np.max(np.abs(diff_unmatched)))
            # Reject if ANY unmatched voice shifts by more than max_gap
            if max_unmatched_change > max_unmatched_shift:
                continue
            score = score_matched
        else:
            score = score_matched
            max_unmatched_change = 0.0
        
        logging.debug(
            "Candidate delta %+0.2f score=%0.3f unmatched_max=%+0.2f",
            delta,
            score,
            max_unmatched_change,
        )
        if score < best_score - 1e-6:
            logging.debug(
                "New best delta %+0.2f (score=%0.3f, matches=%d, unmatched_max=%+0.2f)",
                delta,
                score,
                match_count,
                max_unmatched_change,
            )
            best_score = score
            best_delta = delta
    return best_delta, best_score


def _wrap_delta(delta: float) -> float:
    """Limit shifts to the [-600, 600) range without changing effect modulo 1200."""
    return float(np.mod(delta + 600.0, 1200.0) - 600.0)


def compress_adjacent_chords(data: np.ndarray) -> Tuple[np.ndarray, List[int], List[int]]:
    """Collapse consecutive duplicate columns to speed up comparisons."""
    unique_cols = [data[:, 0]]
    counts = [1]
    start_indices = [0]
    for idx in range(1, data.shape[1]):
        column = data[:, idx]
        if np.array_equal(column, unique_cols[-1]):
            counts[-1] += 1
        else:
            unique_cols.append(column)
            counts.append(1)
            start_indices.append(idx)
    compressed = np.stack(unique_cols, axis=1)
    return compressed, counts, start_indices


def expand_chords(compressed: np.ndarray, counts: Sequence[int]) -> np.ndarray:
    columns = []
    for chord, repeat in zip(compressed.T, counts):
        columns.extend([chord.copy() for _ in range(repeat)])
    return np.stack(columns, axis=1)


def improve_horizontal_consistency(data: np.ndarray, config: HorizontalTransposeConfig) -> Tuple[np.ndarray, List[Tuple[int, float]]]:
    compressed, counts, start_indices = compress_adjacent_chords(data)
    adjusted = np.array(compressed, dtype=float, copy=True)
    applied: List[Tuple[int, float]] = []
    prev_chord = adjusted[:, 0]
    for chord_idx in range(1, adjusted.shape[1]):
        curr_chord = adjusted[:, chord_idx]
        delta, score = _best_delta(prev_chord, curr_chord, config.max_wrap_steps)
        if score < np.inf and abs(delta) > 1e-6:
            delta_wrapped = _wrap_delta(delta)
            if abs(delta_wrapped) <= 1e-6:
                prev_chord = curr_chord
                continue
            shifted = np.mod(curr_chord + delta_wrapped, 1200.0)

            # Safety check: the shift must not change any pitch class (hard constraint).
            if not np.array_equal(atu.pitch_class_from_cents(shifted), atu.pitch_class_from_cents(curr_chord)):
                logging.warning(
                    "Chord %d (orig idx %d): pitch class violated by shift of %+0.2f cents — skipping",
                    chord_idx,
                    start_indices[chord_idx],
                    delta_wrapped,
                )
                prev_chord = curr_chord
                continue

            adjusted[:, chord_idx] = shifted
            applied.append((start_indices[chord_idx], delta_wrapped))
            logging.debug(
                "Chord %d (original idx %d) shifted by %+0.2f cents (raw %+0.2f)",
                chord_idx,
                start_indices[chord_idx],
                delta_wrapped,
                delta,
            )
            pcs_prev = atu.pitch_class_from_cents(prev_chord)
            pcs_curr = atu.pitch_class_from_cents(curr_chord)
            matches = pcs_prev == pcs_curr
            matched_count = int(np.sum(matches))
            unmatched_indices = np.where(~matches)[0]
            max_unmatched_change = 0.0
            if unmatched_indices.size > 0:
                diff_unmatched = shifted[unmatched_indices] - curr_chord[unmatched_indices]
                max_unmatched_change = float(np.max(np.abs(diff_unmatched)))
            logging.info(
                "Chord %d (orig idx %d) shift=%+0.2f cents, matched=%d, unmatched max=%+0.2f, score=%0.3f",
                chord_idx,
                start_indices[chord_idx],
                delta_wrapped,
                matched_count,
                max_unmatched_change,
                score,
            )
            prev_chord = shifted
        else:
            prev_chord = curr_chord

    expanded = expand_chords(adjusted, counts)
    return expanded, applied


def parse_args(argv: Sequence[str]) -> HorizontalTransposeConfig:
    parser = argparse.ArgumentParser(description="Transpose chords for horizontal consistency")
    parser.add_argument("source", help="Path to the tuned cent .npy file")
    parser.add_argument(
        "--destination",
        help="Output path (defaults to <source>-horizontal.npy)",
    )
    parser.add_argument(
        "--max-wrap-steps",
        type=int,
        default=1,
        help="Number of +/- 1200-cent wraps to test when matching offsets",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging verbosity",
    )
    args = parser.parse_args(argv)
    base_name = os.path.splitext(os.path.basename(args.source))[0]
    prefix = base_name[:6] if base_name else "source"
    log_file = os.path.expanduser(f"~/{prefix}-trans.log")
    logger = logging.getLogger()
    logger.setLevel(getattr(logging, args.log_level))
    for handler in list(logger.handlers):
        logger.removeHandler(handler)
    file_handler = logging.FileHandler(log_file, mode="w")
    file_handler.setFormatter(
        logging.Formatter("%(asctime)s %(levelname)s %(message)s", datefmt="%d %H:%M")
    )
    logger.addHandler(file_handler)
    logging.info("Logging horizontal transpose run to %s", log_file)
    return HorizontalTransposeConfig(
        source=args.source,
        destination=args.destination,
        max_wrap_steps=args.max_wrap_steps,
        log_level=args.log_level,
    )


def main(argv: Sequence[str] | None = None) -> None:
    config = parse_args(argv or [])
    data = np.load(config.source)
    if data.shape[0] != 4:
        raise ValueError(f"Expected shape (4, N), got {data.shape}")

    adjusted, applied = improve_horizontal_consistency(data, config)

    # Final pitch class validation: every note in the adjusted array must have
    # the same pitch class as the corresponding note in the original.
    original_pcs = atu.pitch_class_from_cents(data)
    adjusted_pcs = atu.pitch_class_from_cents(adjusted)
    violated_chords = np.where(np.any(original_pcs != adjusted_pcs, axis=0))[0]
    if violated_chords.size == 0:
        logging.info("Pitch class validation: all %d chords preserved.", data.shape[1])
        print("Pitch class check: OK — all pitch classes preserved.")
    else:
        for chord_idx in violated_chords:
            logging.warning(
                "Pitch class violation at chord %d: original %s, adjusted %s",
                chord_idx,
                original_pcs[:, chord_idx],
                adjusted_pcs[:, chord_idx],
            )
        print(f"WARNING: {violated_chords.size} chord(s) have pitch class violations — see log.")

    dest = config.destination or f"{os.path.splitext(config.source)[0]}-horizontal.npy"
    np.save(dest, adjusted)
    save_msg = f"Saved adjusted chorale to {dest}"
    summary_msg = "Applied %d chord shifts; max delta %+0.2f" % (
        len(applied),
        max((abs(d) for _, d in applied), default=0.0),
    )
    logging.info(save_msg)
    logging.info(summary_msg)
    print(save_msg)
    print(summary_msg)


if __name__ == "__main__":
    import sys

    main(sys.argv[1:])
