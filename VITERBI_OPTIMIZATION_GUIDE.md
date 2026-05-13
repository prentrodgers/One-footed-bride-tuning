# Viterbi Optimization for Chorale Tuning

## Overview

The Viterbi optimization feature implements a dynamic programming approach to chorale tuning that optimizes both **vertical** (chord quality) and **horizontal** (pitch-class consistency) aspects simultaneously. This addresses the limitation of the original per-chord optimization which could create discontinuities between adjacent chords.

## How It Works

### 1. K-Candidate Generation

For each chord in the chorale, the system generates K diverse candidate tunings (default K=10) using simulated annealing with varied parameters:

- Different random seeds for exploration
- Temperature variations (0.85× to 1.15× base temperature)
- Slight spread variations for additional diversity

Each candidate is scored for chord quality (sum of numerator + denominator for all intervals).

### 2. Viterbi Path Selection

Using dynamic programming, the algorithm finds the optimal path through the candidate trellis that minimizes:

```
total_cost = α × Σ(chord_scores) + β × Σ(transition_costs)
```

Where:
- **α** (vertical_weight): Weight for chord quality scores
- **β** (horizontal_weight): Weight for pitch-class consistency between adjacent chords

The transition cost penalizes cent jumps for shared pitch classes between consecutive chords.

### 3. Hierarchical Optimization (Optional)

When phrase boundaries are detected (via repeated chords/fermatas), the optimization runs in two stages:

1. **Phrase level**: Strong horizontal constraints within musical phrases
2. **Piece level**: Weaker constraints for global smoothing across phrase boundaries

## Usage

### Basic Usage

Enable Viterbi optimization with default settings:

```bash
python Straw_man_tuning_v2.py \
    --chorale_list bwv253 \
    --use_viterbi \
    --k_candidates 10
```

### Recommended Settings

For best results balancing vertical and horizontal quality:

```bash
python Straw_man_tuning_v2.py \
    --chorale_list bwv253 bwv254 bwv255 \
    --use_viterbi \
    --k_candidates 15 \
    --viterbi_vertical_weight 1.0 \
    --viterbi_horizontal_weight 0.5 \
    --detect_phrases \
    --phrase_horizontal_weight 1.0 \
    --limit_max 19 \
    --tolerance 1 \
    --ratio_factor 1.5 \
    --rolls 8 \
    --sa_iterations 1000
```

### Parameter Guide

#### Core Viterbi Parameters

- `--use_viterbi`: Enable Viterbi optimization (flag, no value needed)
- `--k_candidates`: Number of candidate tunings per chord (default: 10)
  - Higher values (15-20) provide more diversity but increase computation time
  - Lower values (5-8) are faster but may miss optimal solutions

#### Weight Parameters

- `--viterbi_vertical_weight`: Weight for chord quality (default: 1.0)
  - Higher values prioritize consonant intervals within each chord
  - Typical range: 0.5 to 2.0

- `--viterbi_horizontal_weight`: Weight for pitch-class consistency (default: 0.5)
  - Higher values prioritize smooth transitions between chords
  - Typical range: 0.3 to 1.5
  - **Key insight**: Start with 0.5 and adjust based on results

- `--phrase_horizontal_weight`: Horizontal weight for phrase-level optimization (default: 1.0)
  - Used when `--detect_phrases` is enabled
  - Higher values create more stable tunings within phrases

#### Penalty Type

- `--viterbi_penalty_type`: Type of horizontal penalty
  - `pitch_class_jump` (default): Penalize cent distance for shared pitch classes
  - `voice_leading`: Penalize MIDI note movement
  - `combined`: Use both penalties (weighted 1.0 for PC, 0.5 for voice leading)

#### Phrase Detection

- `--detect_phrases`: Auto-detect phrase boundaries (flag)
  - Detects fermatas (repeated chords) as phrase boundaries
  - Enables hierarchical optimization

## Comparison with Original Method

### Original Method (Per-Chord SA)
- ✅ Excellent vertical tuning (low-integer ratios per chord)
- ❌ Can create horizontal discontinuities
- ❌ Requires post-hoc `enforce_continuity()` fixes
- ⚡ Fast (single SA pass per chord)

### Viterbi Method
- ✅ Excellent vertical tuning (same SA algorithm)
- ✅ Optimizes horizontal consistency during tuning
- ✅ Guaranteed optimal path given K candidates
- ✅ Explicit control over vertical/horizontal tradeoff
- ⏱️ Slower (generates K candidates per chord)

## Computational Cost

Time complexity: **O(K² × N)** where:
- K = number of candidates per chord
- N = number of chords in the chorale

Typical timing (on modern CPU):
- K=10, N=50 chords: ~30-60 seconds
- K=15, N=50 chords: ~60-120 seconds
- K=20, N=50 chords: ~120-240 seconds

## Example Workflows

### Workflow 1: Quick Test

```bash
# Fast test with small K
python Straw_man_tuning_v2.py \
    --chorale_list bwv253 \
    --use_viterbi \
    --k_candidates 8 \
    --viterbi_horizontal_weight 0.5 \
    --no-print_values --no-print_finals --no-print_initial
```

### Workflow 2: High-Quality Production

```bash
# Best quality with phrase detection
python Straw_man_tuning_v2.py \
    --chorale_list bwv253 bwv254 bwv255 bwv256 \
    --use_viterbi \
    --k_candidates 20 \
    --viterbi_vertical_weight 1.0 \
    --viterbi_horizontal_weight 0.7 \
    --detect_phrases \
    --phrase_horizontal_weight 1.2 \
    --limit_max 19 \
    --tolerance 1 \
    --ratio_factor 1.5 \
    --rolls 8 \
    --sa_iterations 1000 \
    --workers 1 \
    --no-print_values --no-print_finals --no-print_initial
```

### Workflow 3: Grid Search with Viterbi

```bash
# Test different horizontal weights
for h_weight in 0.3 0.5 0.7 1.0; do
    python Straw_man_tuning_v2.py \
        --chorale_list bwv253 \
        --use_viterbi \
        --k_candidates 12 \
        --viterbi_horizontal_weight $h_weight \
        --numpy_dir "Archive/straw-man/viterbi_hw${h_weight}" \
        --no-print_values --no-print_finals --no-print_initial
done
```

## Interpreting Results

The Viterbi optimization reports:

```
Viterbi complete: mean_score=45.2, spread=12.3¢, path_diversity=8/10
```

- **mean_score**: Average chord quality score (lower is better)
- **spread**: Maximum pitch-class inconsistency in cents (lower is better)
- **path_diversity**: How many different candidates were used (higher = more diverse)

### Good Results
- mean_score: 40-50 (depends on limit_max and tolerance)
- spread: < 15¢ (tight pitch-class consistency)
- path_diversity: 60-80% of K (good exploration)

### Tuning Suggestions

If **spread is too high** (>20¢):
- Increase `--viterbi_horizontal_weight` (try 0.7 or 1.0)
- Enable `--detect_phrases` for phrase-level consistency
- Increase `--k_candidates` for more options

If **mean_score is too high** (>60):
- Increase `--viterbi_vertical_weight` (try 1.5 or 2.0)
- Increase `--k_candidates` for better chord quality options
- Adjust `--ratio_factor` (try 1.5 or 1.75)

If **path_diversity is too low** (<40%):
- Increase `--k_candidates` for more diversity
- Adjust `--spread` parameter (try 10 or 12)
- Check if horizontal_weight is too high (try reducing)

## Integration with Existing Workflow

The Viterbi optimization integrates seamlessly:

1. **Before Viterbi**: Standard SA tuning generates initial candidates
2. **Viterbi**: Selects optimal path through candidates
3. **After Viterbi**: Existing post-processing still works:
   - `--max_gap` continuity enforcement (optional, may not be needed)
   - `--snap_tolerance` pitch-class snapping (optional)

You can combine Viterbi with all existing parameters:
- `--limit_max`, `--tolerance`, `--ratio_factor`
- `--rolls`, `--sa_iterations`, `--initial_temperature`
- `--stability_factor`, `--spread`

## Technical Details

### Algorithm Complexity

The Viterbi algorithm guarantees finding the globally optimal path given:
1. The K candidates generated for each chord
2. The cost function (vertical + horizontal weights)

It does NOT guarantee finding the absolute best tuning possible (that would require exhaustive search), but it finds the best path through the candidate space efficiently.

### Candidate Diversity

Candidates are generated with:
- Temperature variation: ±15% around base temperature
- Random seed variation: K different seeds
- Spread variation: ±2 cents around base spread

This ensures diverse exploration while maintaining quality.

### Transition Cost Calculation

For `pitch_class_jump` penalty:
```python
for each pitch_class in current_chord:
    if pitch_class in previous_chord:
        cost += min_cent_distance(current, previous)
```

This penalizes movement of pitch classes between chords while allowing different voicings.

## Future Enhancements

Potential improvements:
1. **Adaptive K**: Vary K based on chord complexity
2. **Beam search**: Prune unlikely paths early for speed
3. **Multi-objective optimization**: Pareto frontier of vertical/horizontal tradeoffs
4. **Machine learning**: Learn optimal weights from best tunings

## Troubleshooting

**Error: "build_chord_sa_func must be provided"**
- This is an internal error. The function should be passed automatically.
- Check that `build_straw_man_chord_sa` is defined in Straw_man_tuning_v2.py

**Viterbi is very slow**
- Reduce `--k_candidates` (try 8 or 10)
- Reduce `--sa_iterations` (try 500 or 750)
- Reduce `--rolls` (try 4 or 6)

**Results are not better than original**
- Try different `--viterbi_horizontal_weight` values
- Enable `--detect_phrases` for phrase-aware optimization
- Increase `--k_candidates` for more options

## Citation

If you use this Viterbi optimization in your work, please cite:

```
Viterbi-like Dynamic Programming Optimization for Adaptive Just Intonation
Implemented in One-footed-bride-tuning repository
https://github.com/[your-repo]/One-footed-bride-tuning
```

## Contact

For questions or issues with the Viterbi optimization, please open an issue on GitHub or contact the repository maintainer.