#!/usr/bin/env bash
# Grid search over limit_max, tolerance, ratio_factor, stability_factor, and max_delta.
# Usage: bash grid_search.sh [chorale]   (default: all bwv253-264)
#
# Produces one audio file per combination (all renders happen inside the loop).
# A ranking summary is printed at the end via select_best_and_render.py (no re-render).
# Intermediate numpy files are written to Archive/straw-man/t{t}_r{r}_s{s}_md{md}_sn{sn}_lm{lm}/
#
# NOTE: snap_tolerance > 0 is disabled. Independent per-voice snapping breaks
# inter-voice intervals at tolerance=1 (even a 2-cent error per voice creates
# a 4-cent interval error, exceeding the 1-cent JI matching window).

set -euo pipefail

mkdir -p ~/Music/sflib

# CHORALES="${1:-bwv253}"
CHORALES="${1:-$(echo bwv{253..264})}"

LIMIT_MAXES=(17 19)
TOLERANCES=(1 2 4)
RATIOS=(1.25 1.5 1.75)
STABILITY_FACTORS=(0)
MAX_DELTAS=(33)

for limit_max in "${LIMIT_MAXES[@]}"; do
    for tolerance in "${TOLERANCES[@]}"; do
        for stability_factor in "${STABILITY_FACTORS[@]}"; do
            for max_delta in "${MAX_DELTAS[@]}"; do
                for ratio in "${RATIOS[@]}"; do
                    snap_tolerance=0
                    spread=7
                    dir="Archive/straw-man/t${tolerance}_r${ratio}_s${stability_factor}_md${max_delta}_sn${snap_tolerance}_lm${limit_max}"
                    echo "========================================"
                    echo "limit_max=${limit_max}  tolerance=${tolerance}  ratio_factor=${ratio}  stability_factor=${stability_factor}  max_delta=${max_delta}  spread=${spread}  sa_iterations=1000"
                    echo "dir=${dir}"
                    echo "========================================"

                    mkdir -p "$dir"
                    # rm -f "$dir"/*-opt.npy "$dir"/*-trans-sa-opt.npy

                    # Step 1: tune with SA
                    time python Straw_man_tuning_v2.py \
                        --no-print_values --no-print_finals --no-print_initial \
                        --rolls 8 --workers 12 --runs 6 \
                        --limit_max "$limit_max" \
                        --chorale_list $CHORALES \
                        --ratio_factor "$ratio" \
                        --tolerance "$tolerance" \
                        --max_delta "$max_delta" \
                        --numpy_dir "$dir" \
                        --max_gap 33 --retune_on_gaps 5 \
                        --stability_factor "$stability_factor" \
                        --sa_iterations 1000 \
                        --cooling_rate 0.999 \
                        --initial_temp 3.0 \
                        --spread "$spread"

                    # Step 2: horizontal consistency pass
                    for c in $CHORALES; do
                        python horizontal_transpose.py \
                            --destination "${dir}/${c}-trans-sa-opt.npy" \
                            "${dir}/${c}-opt.npy" \
                            --log-level DEBUG
                    done

                    # Step 3: spread analysis
                    python analyze_spread.py \
                        --numpy_dir "$dir" \
                        --chorale_list $CHORALES \
                        --suffix="-trans-sa-opt.npy"

                    # Step 4: render all combinations (one chorale at a time)
                    # for c in $CHORALES; do
                    #     python WreckingCrew.py \
                    #         --short_repeats \
                    #         --chorale_name "$c" \
                    #         --cent_file_partial="-trans-sa-opt.npy" \
                    #         --no_show_volumes \
                    #         --album 4 \
                    #         --tolerance "$tolerance" \
                    #         --ratio_factor "$ratio" \
                    #         --stability_factor "$stability_factor" \
                    #         --max_delta "$max_delta" \
                    #         --limit_max "$limit_max" \
                    #         --numpy_dir "$dir" \
                    #         --spread "$spread" \
                    #         --max_cents_slide 50
                    # done

                    echo "Done: limit_max=${limit_max}  tolerance=${tolerance}  ratio_factor=${ratio}  stability_factor=${stability_factor}  max_delta=${max_delta}  spread=${spread}"
                done
            done
        done
    done
done

echo "========================================"
echo "Grid search complete. Printing ranking summary..."
echo "========================================"

# Final summary: rank all directories by combined score+spread (no re-render).
python select_best_and_render.py \
    --numpy_dir_root Archive/straw-man \
    --chorale_list $CHORALES \
    --spread_weight 0.5

echo "========================================"
echo "Done."
echo "========================================"
