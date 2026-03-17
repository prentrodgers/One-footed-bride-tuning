#!/usr/bin/env python3
"""
detect_sample_tuning.py

Scans all audio samples in the samples/ directory, detects the fundamental
frequency of each sample using FFT + Harmonic Product Spectrum (HPS),
compares to the expected 12-TET pitch parsed from the filename, and reports
the cent offset.

Interpretation:
  cent_offset = 1200 * log2(detected_hz / expected_hz)
  Positive  → sample plays SHARP (above 12-TET)
  Negative  → sample plays FLAT  (below 12-TET)

To correct in ball9.csd f603 table: enter the same value as cent_offset.
  e.g. if a sample is +8 cents sharp, put +8 in f603 for that sample.
  ball9.csd line 103: ibascps = cpsoct(ibasoct + (icent/1200))
  A positive icent raises ibascps → lowers playback rate → lowers pitch.

Usage:
    python3 detect_sample_tuning.py [--dir samples] [--output sample_tuning_report.csv]
"""

import re
import subprocess
import argparse
import csv
import numpy as np
from pathlib import Path

# ---------------------------------------------------------------------------
# Tuning parameters
# ---------------------------------------------------------------------------
SAMPLE_RATE    = 22050   # resample rate for analysis (Hz)
SKIP_SEC       = 0.15    # skip this many seconds at start (attack transient)
ANALYSIS_SEC   = 2.0     # maximum seconds to analyze (sustained portion)
N_HARMONICS    = 5       # harmonics to use in Harmonic Product Spectrum
FFT_ZERO_PAD   = 8       # zero-padding factor (higher = finer Hz resolution)
FMIN           = 40.0    # minimum detectable frequency (Hz)
FMAX           = 5500.0  # maximum detectable frequency (Hz)

# ---------------------------------------------------------------------------
# Note name → semitone (C = 0)
# ---------------------------------------------------------------------------
NOTE_SEMITONE = {
    'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3,
    'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8,
    'A': 9, 'A#': 10, 'Bb': 10, 'B': 11,
}

# Matches e.g. "C4", "A#3", "G#5", "Bb2" — optionally followed by "-f" or "-p" suffixes
# (forte/piano variants in McGill naming like "CLARBB A#3-f.aif")
NOTE_PATTERN = re.compile(r'([A-G][#b]?)(\d)(?:-[a-z]+)?$')

# ---------------------------------------------------------------------------
# Audio loading via sox
# ---------------------------------------------------------------------------

def load_audio_mono(path: Path) -> np.ndarray | None:
    """
    Use sox to load any audio file as mono float64 at SAMPLE_RATE.
    Returns normalized [-1, 1] numpy array, or None on error.
    """
    cmd = [
        'sox', str(path),
        '-t', 'raw',
        '-e', 'signed-integer', '-b', '16',
        '-r', str(SAMPLE_RATE),
        '-c', '1',
        '-',
    ]
    result = subprocess.run(cmd, capture_output=True)
    if result.returncode != 0 or not result.stdout:
        return None
    data = np.frombuffer(result.stdout, dtype=np.int16).astype(np.float64) / 32768.0
    return data

# ---------------------------------------------------------------------------
# Pitch detection: FFT + Harmonic Product Spectrum
# ---------------------------------------------------------------------------

def detect_pitch(signal: np.ndarray) -> float | None:
    """
    Detect the fundamental frequency (Hz) of a monophonic signal.

    Strategy:
      1. Skip the attack transient (first SKIP_SEC seconds).
      2. Apply a Hann window to the sustain segment.
      3. Zero-pad and compute magnitude spectrum.
      4. Build Harmonic Product Spectrum to identify the fundamental
         even when higher harmonics are stronger.
      5. Refine the peak location with parabolic interpolation.

    Returns Hz, or None if detection fails.
    """
    skip   = int(SKIP_SEC    * SAMPLE_RATE)
    length = int(ANALYSIS_SEC * SAMPLE_RATE)

    # Fall back to full signal if it's very short
    if len(signal) <= skip + 1024:
        segment = signal
    else:
        segment = signal[skip: skip + length]

    if len(segment) < 1024:
        return None

    # Hann window to suppress spectral leakage
    windowed = segment * np.hanning(len(segment))

    # Zero-pad → finer frequency bins
    n_fft    = 2 ** int(np.ceil(np.log2(len(windowed) * FFT_ZERO_PAD)))
    spectrum = np.abs(np.fft.rfft(windowed, n=n_fft))
    freqs    = np.fft.rfftfreq(n_fft, d=1.0 / SAMPLE_RATE)

    # Frequency index bounds for the fundamental search
    i_low  = int(np.searchsorted(freqs, FMIN))
    i_high = int(np.searchsorted(freqs, FMAX))
    if i_high <= i_low:
        return None

    # Harmonic Product Spectrum — MUST operate on the full spectrum from bin 0.
    # hps[k] = spectrum[k] * spectrum[2k] * spectrum[3k] * ...
    # Using decimation: spectrum[::h][k] == spectrum[k*h], which is correct
    # only when the array starts at index 0.
    hps = spectrum.copy()
    for h in range(2, N_HARMONICS + 1):
        n_valid = len(hps) // h
        if n_valid < 1:
            break
        hps[:n_valid] *= spectrum[::h][:n_valid]

    # Find peak only within the fundamental frequency range
    peak_abs = i_low + int(np.argmax(hps[i_low:i_high]))

    # Parabolic interpolation for sub-bin accuracy
    if 0 < peak_abs < len(spectrum) - 1:
        y1, y2, y3 = spectrum[peak_abs - 1], spectrum[peak_abs], spectrum[peak_abs + 1]
        denom = y1 - 2 * y2 + y3
        delta = 0.5 * (y1 - y3) / denom if denom != 0 else 0.0
        refined = peak_abs + delta
    else:
        refined = float(peak_abs)

    detected = refined * SAMPLE_RATE / n_fft
    return detected if FMIN <= detected <= FMAX else None

# ---------------------------------------------------------------------------
# Note name helpers
# ---------------------------------------------------------------------------

def parse_note(stem: str):
    """
    Extract (note_name, octave_int) from a filename stem.
    Searches for the last occurrence of a note pattern.
    Returns (None, None) if no match.
    """
    m = NOTE_PATTERN.search(stem)
    if m:
        return m.group(1), int(m.group(2))
    return None, None


def note_to_midi(note_name: str, octave: int) -> int | None:
    semitone = NOTE_SEMITONE.get(note_name)
    if semitone is None:
        return None
    # C4 = MIDI 60: (octave + 1) * 12 + semitone
    return (octave + 1) * 12 + semitone


def midi_to_freq_12tet(midi: int) -> float:
    """12-TET frequency with A4 = 440 Hz."""
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description='Measure tuning offset of instrument samples vs 12-TET'
    )
    parser.add_argument('--dir',    default='samples',
                        help='Root samples directory (default: samples)')
    parser.add_argument('--output', default='sample_tuning_report.csv',
                        help='Output CSV filename (default: sample_tuning_report.csv)')
    parser.add_argument('--inst',   default=None,
                        help='Only process this instrument subdirectory name')
    args = parser.parse_args()

    samples_root = Path(args.dir)
    if not samples_root.is_dir():
        print(f'ERROR: directory not found: {samples_root}')
        return

    rows        = []
    skipped     = 0
    parse_fails = 0

    for inst_dir in sorted(samples_root.iterdir()):
        if not inst_dir.is_dir():
            continue
        if args.inst and inst_dir.name != args.inst:
            continue

        audio_files = sorted(
            list(inst_dir.glob('*.aif'))  +
            list(inst_dir.glob('*.aiff')) +
            list(inst_dir.glob('*.wav'))
        )
        if not audio_files:
            continue

        print(f'\n=== {inst_dir.name} ===')

        for apath in audio_files:
            note_name, octave = parse_note(apath.stem)

            if note_name is None:
                print(f'  {apath.name}: skip (cannot parse note name from "{apath.stem}")')
                parse_fails += 1
                continue

            midi = note_to_midi(note_name, octave)
            if midi is None:
                print(f'  {apath.name}: skip (unrecognized note "{note_name}")')
                parse_fails += 1
                continue

            expected_hz = midi_to_freq_12tet(midi)

            signal = load_audio_mono(apath)
            if signal is None:
                print(f'  {apath.name}: skip (sox failed to load file)')
                skipped += 1
                continue

            detected_hz = detect_pitch(signal)
            if detected_hz is None:
                print(f'  {apath.name}: skip (pitch detection failed)')
                skipped += 1
                continue

            cent_offset = 1200.0 * np.log2(detected_hz / expected_hz)

            # If offset is near a multiple of 1200 cents, the detector likely
            # landed on a harmonic instead of the fundamental.  Try rescaling.
            warning = ''
            for divisor in [2, 3, 4]:
                corrected = 1200.0 * np.log2(detected_hz / divisor / expected_hz)
                if abs(corrected) < abs(cent_offset) and abs(cent_offset) > 600:
                    cent_offset = corrected
                    warning = f' [NOTE: detected at {divisor}x harmonic — divided down]'
                    break

            sign = '+' if cent_offset >= 0 else ''
            print(
                f'  {apath.name}: '
                f'{note_name}{octave} '
                f'expected={expected_hz:.2f}Hz  '
                f'detected={detected_hz:.2f}Hz  '
                f'offset={sign}{cent_offset:.1f}c'
                f'{warning}'
            )

            rows.append({
                'instrument':  inst_dir.name,
                'file':        apath.name,
                'note':        f'{note_name}{octave}',
                'midi':        midi,
                'expected_hz': round(expected_hz, 3),
                'detected_hz': round(detected_hz, 3),
                'cent_offset': round(cent_offset, 2),
                'warning':     warning.strip('[] '),
            })

    # Write CSV report
    with open(args.output, 'w', newline='') as f:
        writer = csv.DictWriter(
            f,
            fieldnames=['instrument','file','note','midi','expected_hz','detected_hz','cent_offset','warning']
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f'\n{"="*60}')
    print(f'Processed : {len(rows)} samples')
    print(f'Skipped   : {skipped} (load/detection failures)')
    print(f'No note   : {parse_fails} (filename pattern not recognized)')
    print(f'Report    : {args.output}')
    print()
    print('cent_offset interpretation:')
    print('  Positive = sample plays SHARP above 12-TET')
    print('  Negative = sample plays FLAT  below 12-TET')
    print()
    print('To correct in ball9.csd f603: use the same value as cent_offset')
    print('  (positive icent raises ibascps → lowers playback rate → lowers pitch)')


if __name__ == '__main__':
    main()
