# Presentation Charts - One-Footed Bride Tuning

High-quality presentation charts optimized for 16:9 projector screens (1920×1080 resolution).

## Charts Included

### Chart 1: Technology of Tuning
- Compares 12-Tone Equal Temperament vs Just Intonation
- Introduces Harry Partch's Tonality Diamond concept
- Shows project approach: MIDI → Diamond → SA → Csound
- **Aspect ratio:** 16:9 | **File:** `chart_1_tuning_systems.png`

### Chart 2: Harry Partch's Tonality Diamond
- Construction process: Prime limit → Ratios → Cents → Scores
- Otonality (overtone) and Utonality (undertone) series
- Example: 11-limit diamond with key ratios
- Implementation in `adaptive_tuning_util.py`
- **Aspect ratio:** 16:9 | **File:** `chart_2_partch_diamond.png`

### Chart 3: Simulated Annealing Optimization
- Complete algorithm flowchart for chord optimization
- Temperature weighting: Early exploration → Late refinement
- Chord scoring method and decision points
- 4-note chord with 6 interval pairs
- **Aspect ratio:** 16:9 | **File:** `chart_3_simulated_annealing.png`

### Chart 4: Bach Chorale Tuning Pipeline
- End-to-end MIDI processing workflow
- Music21 analysis → Diamond building → SA optimization
- Caching strategy (~80% hit rate)
- Continuity enforcement with glissandi
- BWV 253-264 (Wedding Chorales)
- **Aspect ratio:** 16:9 | **File:** `chart_4_bach_pipeline.png`

### Chart 5: Csound Sample-Based Synthesis
- Audio rendering pipeline from tuned chords
- Note feature extraction and instrument assignment
- Glissando implementation for smooth transitions
- Sample library integration
- Csound opcodes and just intonation features
- **Aspect ratio:** 16:9 | **File:** `chart_5_csound_synthesis.png`

### Chart 6: Complete Workflow Overview
- System-level integration of all components
- INPUT → THEORY → OPTIMIZE → SYNTHESIS → OUTPUT
- Key innovations and project files
- Metrics: 214 ratios, ~80% cache hit, pure JI
- GitHub repository link
- **Aspect ratio:** 16:9 | **File:** `chart_6_complete_workflow.png`

## Usage

### In Presentations
- All charts are **1920×1080 pixels** (native 16:9)
- Created with matplotlib for crisp, scalable graphics
- Black and white design for professional appearance
- Can be embedded in PowerPoint, Google Slides, or Keynote

### Viewing
```bash
# View individual charts
feh presentation_charts/chart_*.png

# Or open with your image viewer
open presentation_charts/chart_1_tuning_systems.png
```

### Regenerating Charts
If you modify the visualization script:
```bash
mamba activate csound
python generate_presentation_charts.py
```

Charts will be regenerated in this directory.

## Technical Notes

- **Resolution:** 1920×1080 pixels (100 DPI)
- **Aspect Ratio:** 16:9 (standard projector/monitor)
- **Format:** PNG (high quality, lossless)
- **colors:** Black & white with light gray accents
- **Font:** Sans-serif, optimized for projection
- **Size:** ~80-100 KB per chart

## Related Files

- Script to generate charts: `../generate_presentation_charts.py`
- Markdown version: `../One-Footed-Bride-Presentation.md` (Mermaid diagrams)
- Repository: https://github.com/prentrodgers/One-footed-bride-tuning

---

Created: February 13, 2026
