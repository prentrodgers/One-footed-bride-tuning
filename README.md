# One-footed-bride-tuning

A compact implementation of Harry Partch's "One-Footed Bride" tonality diamond tuning applied to Bach chorales.
<br>
<a href="one-footed-bride-pic.jpeg"><img src="one-footed-bride-pic.jpeg" alt="One‑footed Bride" width="400"/></a>

## Overview
This project finds cent tunings for four-note chords that favor low-number rational intervals (small numerator+denominator). It uses:
- A tonality diamond (variable limit) to enumerate candidate ratios
- Simulated annealing to search for low‑score chord tunings
- Grid search across hyperparameters (limit, tolerance, ratio_factor, etc.)
- Optional post-processing (horizontal transposition, glissandi smoothing) and Csound rendering
- A live MIDI-to-Csound web application for real-time performance

## Main Programs

### grid_search_tuning.py
Tunes all 12 Bach chorales (bwv253–bwv264) across combinations of `limit_max`, `tolerance`, `rolls`, and `spread` to find the lowest-scoring chord tunings. Produces numpy arrays of cent values for each chord in each chorale, and writes results to `grid_search_results.csv`.

```bash
python grid_search_tuning.py
```

Key functions:
- `build_straw_man_chord()` — core per-chord tuning using permutation and roll search
- `run_chorale()` — tune all chords in one chorale with given parameters
- `grid_search()` — sweep all parameter combinations
- `analyze()` — summarize CSV results and recommend best parameters

### select_best_and_render.py
Scans directories of tuned numpy arrays, ranks them by a combined metric of mean chord score and pitch-class spread, and optionally renders the winners as audio via WreckingCrew.py and Csound.

```bash
# Rank all tunings for all chorales
python select_best_and_render.py \
  --numpy_dir_root Archive/straw-man \
  --chorale_list bwv253 bwv254 bwv255 bwv256 bwv257 bwv258 bwv259 bwv260 bwv261 bwv262 bwv263 bwv264 \
  --spread_weight 0.5

# Render winners as audio
python select_best_and_render.py \
  --numpy_dir_root Archive/straw-man \
  --chorale_list bwv253 --spread_weight 0.5 --render
```

Key arguments: `--spread_weight` (0–1, balance score vs. spread), `--render`, `--copy_mp3_to`, `--copy_npy_to`, `--bass_sustain`.

### midi_tuning_server.py
A live MIDI-to-Csound web application. Reads MIDI from a keyboard, tunes chords in real time using the straw-man algorithm or simulated annealing, orchestrates across 8 instrument sections (finger pianos, bass, winds, strings, percussion), and sends score events to Csound. A browser-based WebSocket UI controls tuning parameters, instrument assignments, density, octave stretch, envelopes, and volume in real time.

```bash
python midi_tuning_server.py
# Open http://localhost:8000
```

### WreckingCrew.py
The rendering engine. Takes tuned cent-value numpy arrays and generates Csound `.csd` files for audio synthesis. Manages instrument sections (finger pianos, bass, winds, melody, percussion), density masks, octave stretching, bass sustain shaping, and glissando smoothing between chords.

```bash
python WreckingCrew.py --short_repeats --chorale_name bwv253 \
  --cent_file_partial="-trans-sa-opt.npy" --numpy_dir best-npy
```

### train.py
SA tuning hyperparameter evaluator. Runs simulated annealing on test chords with configurable parameters and reports scores and timing as JSON. Supports `--animate` to generate an animated GIF showing SA convergence.

```bash
python train.py '{"ratio_factor": 4.0, "rolls": 5}'
python train.py --animate '{"max_iterations": 200}'
```

## Helper Modules

### adaptive_tuning_util.py
Core utility library with 50+ functions for the entire tuning pipeline:
- **I/O:** load chorales from MIDI files, music21 corpus, or numpy arrays
- **Tonal diamond:** `build_tonal_diamond()`, ratio lookups and scoring via `ChordScorer` and `LowNumberRatioIntervals`
- **Cent math:** modular cent arithmetic, pitch-class extraction, circular span
- **Chord operations:** rearrangement, pitch-class compression, perturbation, force-match
- **Rendering:** glide arrays, octave alteration masks, note feature clipping, density masks

### horizontal_transpose.py
Post-processes tuned chorales to improve horizontal (temporal) consistency. When adjacent chords share pitch classes, applies offsets so shared pitches reuse earlier cent values, minimizing pitch drift across the chorale.

```bash
python horizontal_transpose.py Archive/straw-man/bwv253-opt.npy \
  --destination Archive/straw-man/bwv253-trans-sa-opt.npy --log-level DEBUG
```

### diamond_music_utils.py
Utilities for tonality diamond music: ratio construction, scale building, cent/ratio conversion, chord and glissando generation, and Csound file I/O.

## Notebooks

### Straw_man_tuning.ipynb
Illustrates the greedy (non-SA) tuning algorithm. Quickly tunes chords using permutation and roll search — useful for understanding the core algorithm and for live-performance latency testing.

### compare_horizontal_chords.ipynb
Compares chords before and after `horizontal_transpose.py`. Checks for pitch-class mismatches and analyzes chord-level gap statistics.

### Chorale-info.ipynb
Scores and studies tuned cent-value arrays. Computes per-pitch-class spread analysis, identifies the most important (frequent) pitch classes, and reports score statistics across the chorale.

## Quick Start

**Prerequisites:** Python 3.10+, numpy, scipy, matplotlib, sox, Csound (optional for audio)

```bash
# Create environment
mamba create -n csound python jupyterlab matplotlib numpy scipy music21
mamba activate csound
pip install -r requirements.txt

# Tune chorales
python grid_search_tuning.py

# Find the best tunings and render audio
python select_best_and_render.py \
  --numpy_dir_root Archive/straw-man \
  --chorale_list bwv253 --spread_weight 0.5 --render

# Or run the live MIDI server
python midi_tuning_server.py
```

## Key Parameters
- `limit_max` — tonality diamond limit; controls largest numerator/denominator in candidate ratios. Common values: 17, 19, 23.
- `tolerance` — how many cents away from an exact ratio is still accepted [1–4]
- `ratio_factor` — weight favoring lower-number ratios in selection (higher = more consonant)
- `stability_factor` — weight favoring pitch stability across adjacent chords
- `spread` — Gaussian noise σ for per-roll perturbation (default 7)
- `max_delta` — maximum cent distance from 12-TET for candidate ratios (default 33)

## Contributing & License
If you find bugs or want to propose improvements, open an issue or a PR. See the LICENSE file for licensing details.


— End of README —

