#!/usr/bin/env bash
# Grid search over limit_max, tolerance, and ratio_factor.
# Usage: bash grid_search.sh [chorale]   (default: all bwv253-264)
#
# Produces one audio file per combination (all renders happen inside the loop).
# A ranking summary is printed at the end via select_best_and_render.py (no re-render).
# Intermediate numpy files are written to Archive/straw-man/t{t}_r{r}_lm{lm}/
#
# NOTE: snap_tolerance > 0 is disabled. Independent per-voice snapping breaks
# inter-voice intervals at tolerance=1 (even a 2-cent error per voice creates
# a 4-cent interval error, exceeding the 1-cent JI matching window).

set -euo pipefail

mkdir -p ~/Music/sflib

# CHORALES="${1:-$(echo bwv{253..264})}"

# LIMIT_MAXES=(17 19)
# TOLERANCES=(1 2)
# RATIOS=(1.125 1.25 1.375 1.5)
# STABILITY_FACTORS=(0)
# MAX_DELTAS=(33)

# test with just one:
CHORALES="bwv261"

LIMIT_MAXES=(17 19)
TOLERANCES=(3)
RATIOS=(1.25 1.375 1.50 1.625 1.75)
ROLLS=4

# Not searched over — held fixed and passed through to the tuner. They are no
# longer part of the directory name, so changing one silently overwrites the
# previous result rather than starting a new cell.
STABILITY_FACTOR=0
MAX_DELTA=33
SPREAD=7

# FRESH=1 wipes each result directory and saves this run's output unconditionally.
# FRESH=0 keeps the directory and lets the keep-previous ratchet accumulate the
# best result across repeated runs.
#
# Prefer FRESH=0 when hunting for a good tuning.  The ratchet now compares
# mean_score + spread_weight * max-circular-MAD + gap_weight * max-adjacent-gap,
# so repeated passes over one cell keep the smallest pitch-class jumps rather
# than whichever run drew the luckiest seed.  That matters because mean_score
# alone cannot tell these runs apart: four passes over t3_r1.375_lm19 spanned
# 56.2-57.9 mean while ten different cells spanned 56.0-57.6.  Use FRESH=1 only
# when you want this run's output regardless of what came before.
FRESH=0 # once you want to ratchet each run, set fresh=0 and keep the --keep_previous flag in the python call below
MAX_GAP=12

for limit_max in "${LIMIT_MAXES[@]}"; do
    for tolerance in "${TOLERANCES[@]}"; do
        for ratio in "${RATIOS[@]}"; do
            dir="Archive/straw-man/t${tolerance}_r${ratio}_lm${limit_max}"
            echo "========================================"
            echo "limit_max=${limit_max}  tolerance=${tolerance}  ratio_factor=${ratio}  stability_factor=${STABILITY_FACTOR}  max_delta=${MAX_DELTA}  spread=${SPREAD}  sa_iterations=1000"
            echo "dir=${dir}"
            echo "========================================"

            mkdir -p "$dir"
            if [ "$FRESH" = "1" ]; then
                rm -f "$dir"/*-opt.npy "$dir"/*-opt.txt
                keep_flag="--no-keep_previous"
            else
                keep_flag="--keep_previous"
            fi

            # Step 1: tune with SA
            time python Straw_man_tuning_v2.py \
                --no-print_values --no-print_finals --no-print_initial \
                --rolls "$ROLLS" --workers 1 --runs 1 \
                --limit_max "$limit_max" \
                --chorale_list $CHORALES \
                --ratio_factor "$ratio" \
                --tolerance "$tolerance" \
                --max_delta "$MAX_DELTA" \
                --numpy_dir "$dir" \
                --max_gap "$MAX_GAP" --retune_on_gaps 5 \
                "$keep_flag" \
                --stability_factor "$STABILITY_FACTOR" \
                --sa_iterations 1000 \
                --cooling_rate 0.999 \
                --initial_temp 3.0 \
                --spread "$SPREAD" \
                --use_viterbi \
                --k_candidates 15 \
                --viterbi_vertical_weight 1.0 \
                --detect_phrases \
                --phrase_horizontal_weight 8.0 \
                --viterbi_workers 16

            # Step 2: spread analysis
            # (The old horizontal_transpose.py pass is gone: the Viterbi DP
            # now considers pitch-class-preserving whole-chord transpositions
            # on every transition and at phrase seams, so the greedy post-pass
            # has nothing left to shift.)
            python analyze_spread.py \
                --numpy_dir "$dir" \
                --chorale_list $CHORALES \
                --suffix="-opt.npy"

            # Step 3: render all combinations (one chorale at a time)
            # for c in $CHORALES; do
            #     python WreckingCrew.py \
            #         --short_repeats \
            #         --chorale_name "$c" \
            #         --cent_file_partial="-opt.npy" \
            #         --no_show_volumes \
            #         --album 4 \
            #         --tolerance "$tolerance" \
            #         --ratio_factor "$ratio" \
            #         --stability_factor "$STABILITY_FACTOR" \
            #         --max_delta "$MAX_DELTA" \
            #         --limit_max "$limit_max" \
            #         --numpy_dir "$dir" \
            #         --spread "$SPREAD" \
            #         --max_cents_slide 50
            # done

            echo "Done: limit_max=${limit_max}  tolerance=${tolerance}  ratio_factor=${ratio}"
        done
    done
done

echo "========================================"
echo "Grid search complete. Printing ranking summary..."
echo "========================================"

# Final summary: gap and chord-quality report for every directory (no winner
# is chosen, and nothing is rendered — read the table and listen).
#
# Sorted by maxgap, not gapsum: the two disagree, and the worst single jump is
# the one that matches what gets heard.  Sorting by gapsum on bwv261 would have
# led with t3_r1.375_lm19 (max 14¢, sum 32) over t3_r1.625_lm19 (max 11¢, sum
# 44), and the 11¢ tuning was the better one.  ChordAvg is not worth sorting on
# at all — it varies more between runs of one cell than across the whole grid.
python select_best_and_render.py \
    --numpy_dir_root Archive/straw-man \
    --chorale_list $CHORALES \
    --suffix="-opt.npy" \
    --sort_by maxgap

echo "========================================"
echo "Done."
echo "========================================"
