# One-footed-bride-tuning

A compact implementation of Harry Partch's "One-Footed Bride" tonality diamond tuning applied to Bach chorales.
[![One‑footed Bride](/one-footed-bride-pic.jpeg)](/one-footed-bride-pic.jpeg)

## Overview ✅
This project finds cent tunings for four-note chords that favor low-number rational intervals (small numerator+denominator). It uses:
- A tonality diamond (variable limit) to enumerate candidate ratios
- Simulated annealing to search for low‑score chord tunings
- Optional post-processing (glissandi/slide smoothing) and Csound rendering

## Features ✨
- Computes valid interval ratios for each chord (limits configurable)
- Simulated annealing search with configurable temperature and cooling
- Permutes chord orders to reduce local minima effects
- Caching and chord compression to speed repeated work
- Parallel processing support to use multiple CPU cores
- Exports data for visualization and Csound performance

## Quick start ▶️
Requirements: Python 3.10+, numpy, scipy, matplotlib, (Csound optional)

1. Recommended: create a minimal mamba environment (fast and reproducible):
   ```bash
   # first install miniforge: https://github.com/conda-forge/miniforge
   # then if you want to realize the resulting .csd files, install csound: https://github.com/csound/csound
   mamba create -n csound python jupyterlab matplotlib numpy scipy music21
   mamba activate csound
   ```

2. Or install dependencies with pip (project root or this subfolder):
   ```bash
   pip install -r requirements.txt
   ```

3. Run the main script:
   ```bash
   python WreckingCrew.py
   ```

4. Examples
   - Quick run (default list of Bach Wedding Chorales bwv253 through bwv264). It uses pre-tuned cent values:
     ```bash
     python WreckingCrew.py 
     ```
   - Tune a single chorale with the optimizer script:
     ```bash
     python optimize_chords_sa_v2.py --chorale bwv253
     ```
   - Show generated plots and volumes (saved to `plots/`):
     Run `python WreckingCrew.py` and inspect `plots/{version}.jpg`

5. Use the notebook `Chorale-info.ipynb` for exploration and printing results.

Configuration is in `WreckingCrew.py` and supporting helper modules (e.g., `diamond_music_utils.py`, `adaptive_tuning_util.py`). Tweak limits and annealing parameters to experiment.

## Key parameters ⚙️
- `limit` (tonality diamond limit): controls the largest numerator/denominator allowed in candidate ratios. Common useful values are **31** or **47**.
- `initial_temperature` / `temperature` (simulated annealing): typical sensible defaults used in the project are **64.0** for the starting temperature and a **cooling factor ~0.998** per iteration (lower values cool faster).
- `caching`: the code caches valid-ratio lookups and chord scores to speed repeated tuning. Enable/inspect caching to improve performance (hit rates commonly >80%).

> Tip: Start with the default parameters and run a single chorale to get a feel for runtime and output before performing longer grid searches.
## Notes & Tips 💡
- Typical useful tonality diamond limits: 19, 23, or 31 (experiment with smaller/larger limits)
- If adjacent chords produce slight cent differences for the same MIDI pitch, the pipeline applies short slides (glissandi) to smooth transitions
- Caching and compressing unique chords dramatically speeds tuning (often >80% cache hit rates)

## Contributing & License
If you find bugs or want to propose improvements, open an issue or a PR. See the LICENSE file for licensing details.


— End of README —

