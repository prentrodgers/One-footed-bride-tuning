#!/usr/bin/env bash
# Grid search over limit_max, tolerance and ratio_factor — one tuning cell and
# one chorale at a time.
#
# Two ways to run it, sharing one run_cell() so the tuning command lives in
# exactly one place:
#
#   CHORALES=bwv267 bash grid_search.sh
#   CHORALES="bwv265 bwv266 bwv267" bash grid_search.sh
#       The grid below, every cell x every chorale in CHORALES, serially, then
#       the ranking table.  Chorales come from the environment or --chorale,
#       always with the bwv prefix; the script refuses to run without one so
#       a stale default can never tune the wrong piece.  VITERBI_WORKERS
#       defaults to 16 here.
#
#   bash grid_search.sh --limit_max 19 --tolerance 2 --ratio 1.50 --chorale bwv262 [--job_id N]
#       One cell, one chorale, no ranking table.  This is what each Kubernetes
#       job runs: k8s-grid-search-job-template.yaml calls this script with the
#       placeholders generate-grid-search-jobs.sh fills in.  It is also what
#       each Ray task runs (ray_ratchet.py).  The cross-chorale table is then
#       select_best_and_render.py over Archive/straw-man, run by hand once
#       every job has finished.
#
#   --dry_run prints the commands instead of running them.
#
# Intermediate numpy files are written to Archive/straw-man/t{t}_r{r}_lm{lm}/.
# Pass the ratio exactly as the directory should be named: 1.50 and 1.5 are
# two different cells.
#
# NOTE: snap_tolerance > 0 is disabled. Independent per-voice snapping breaks
# inter-voice intervals at tolerance=1 (even a 2-cent error per voice creates
# a 4-cent interval error, exceeding the 1-cent JI matching window).

set -euo pipefail

# ── The grid (default mode) ─────────────────────────────────────────────────
# Which chorales: from the environment, or --chorale below.  Never a default.
#   CHORALES=bwv267                    one
#   CHORALES="$(echo bwv{253..264})"   the original twelve
CHORALES="${CHORALES:-}"
# replace the ones that I deleted due to scores in the thousands
# rm -r Archive/straw-man/t3_r1.75_lm17 Archive/straw-man/t3_r1.75_lm19
LIMIT_MAXES=(17 19)
TOLERANCES=(1 2 3)
RATIOS=(1.25 1.375 1.50 1.625 1.75 )  

# ── Not searched over ───────────────────────────────────────────────────────
# Held fixed and passed through to the tuner.  None of these is part of the
# directory name, so changing one silently overwrites the previous result
# rather than starting a new cell.
ROLLS=4
STABILITY_FACTOR=0
MAX_DELTA=33
SPREAD=7
INITIAL_TEMP=3.0
MAX_GAP=33 # tried 12 but that caused unrelated problems with enforce_continuity

# Viterbi threads.  16 is the workstation default.  In the Kubernetes job this
# MUST equal the pod's cpu limit (4): workers above the limit only contend, so
# the template sets VITERBI_WORKERS=4 in its env block next to the resources,
# and that value wins over this default.
VITERBI_WORKERS="${VITERBI_WORKERS:-16}"

# FRESH=1 wipes the chorale's result files and saves this run's output
# unconditionally.  FRESH=0 keeps them and lets the keep-previous ratchet
# accumulate the best result across repeated runs.
#
# Prefer FRESH=0 when hunting for a good tuning.  The ratchet compares
# mean_score + spread_weight * max-circular-MAD + gap_weight * max-adjacent-gap,
# so repeated passes over one cell keep the smallest pitch-class jumps rather
# than whichever run drew the luckiest seed.  That matters because mean_score
# alone cannot tell these runs apart: four passes over t3_r1.375_lm19 spanned
# 56.2-57.9 mean while ten different cells spanned 56.0-57.6.  The tuner also
# seeds the Viterbi trellis with the saved tuning, so a pass starts from the
# path already on disk instead of rebuilding from 12-TET; wiping the file
# first removes the thing that makes repeated passes converge — with it in
# place eight of eight bwv261 cells improved and were accepted, against 12 of
# 115 without.  Use FRESH=1 only when you want this run's output regardless of
# what came before.
FRESH="${FRESH:-0}"

# ── Arguments ───────────────────────────────────────────────────────────────
LIMIT_MAX=""; TOLERANCE=""; RATIO=""; JOB_ID=""; DRY_RUN=0
while [ $# -gt 0 ]; do
    case "$1" in
        --limit_max) LIMIT_MAX=$2; shift 2;;
        --tolerance) TOLERANCE=$2; shift 2;;
        --ratio)     RATIO=$2; shift 2;;
        --chorale)   CHORALES=$2; shift 2;;   # one name, or several in quotes
        --job_id)    JOB_ID=$2; shift 2;;
        --fresh)     FRESH=1; shift;;
        --dry_run)   DRY_RUN=1; shift;;
        -h|--help)   sed -n '2,25p' "$0"; exit 0;;
        *) echo "unknown argument: $1" >&2; exit 2;;
    esac
done
if [ -n "$LIMIT_MAX$TOLERANCE$RATIO" ] && [ -z "$LIMIT_MAX" -o -z "$TOLERANCE" -o -z "$RATIO" ]; then
    echo "--limit_max, --tolerance and --ratio go together" >&2; exit 2
fi
if [ -z "$CHORALES" ]; then
    echo "no chorale given: set CHORALES=bwvNNN in the environment or pass --chorale bwvNNN" >&2; exit 2
fi
for c in $CHORALES; do
    case "$c" in bwv*) ;; *) echo "chorale names need the bwv prefix: got '$c'" >&2; exit 2;; esac
done

run() { if [ "$DRY_RUN" = 1 ]; then echo "+ $*"; else "$@"; fi; }

# ── One cell, one chorale ───────────────────────────────────────────────────
run_cell() {
    local limit_max=$1 tolerance=$2 ratio=$3 chorale=$4
    # The directory scheme WreckingCrew.py parses for tolerance/ratio/limit_max.
    local dir="Archive/straw-man/t${tolerance}_r${ratio}_lm${limit_max}"

    echo "========================================"
    [ -n "$JOB_ID" ] && echo "Job ${JOB_ID} starting"
    echo "chorale=${chorale}"
    echo "limit_max=${limit_max}  tolerance=${tolerance}  ratio_factor=${ratio}"
    echo "initial_temp=${INITIAL_TEMP}  stability_factor=${STABILITY_FACTOR}  max_delta=${MAX_DELTA}  spread=${SPREAD}  sa_iterations=1000"
    echo "dir=${dir}"
    echo "========================================"

    mkdir -p "$dir"
    mkdir -p ~/Music/sflib

    # Scoped to ${chorale} throughout: the twelve per-chorale jobs for one
    # cell share $dir, so a wildcard would have each job delete the other
    # eleven's results.  The ratchet is likewise per-file, so leaving the
    # incumbent in place costs the other jobs nothing.
    local keep_flag
    if [ "$FRESH" = "1" ]; then
        run rm -f "$dir/${chorale}-opt.npy" "$dir/${chorale}-opt.txt"
        keep_flag="--no-keep_previous"
    else
        keep_flag="--keep_previous"
    fi

    # Step 1: tune with SA and viterbi optimization
    echo "Step 1: Running Straw_man_tuning_v2.py..."
    time run python Straw_man_tuning_v2.py \
        --no-print_values --no-print_finals --no-print_initial \
        --rolls "$ROLLS" --workers 1 --runs 1 \
        --limit_max "$limit_max" \
        --chorale_list "$chorale" \
        --ratio_factor "$ratio" \
        --tolerance "$tolerance" \
        --max_delta "$MAX_DELTA" \
        --numpy_dir "$dir" \
        --max_gap "$MAX_GAP" --retune_on_gaps 5 \
        "$keep_flag" \
        --stability_factor "$STABILITY_FACTOR" \
        --sa_iterations 1000 \
        --cooling_rate 0.999 \
        --initial_temp "$INITIAL_TEMP" \
        --spread "$SPREAD" \
        --use_viterbi \
        --k_candidates 15 \
        --viterbi_vertical_weight 1.0 \
        --viterbi_verbose \
        --viterbi_verbose_threshold 80 \
        --detect_phrases \
        --phrase_horizontal_weight 8.0 \
        --viterbi_workers "$VITERBI_WORKERS"

    # Step 2: spread analysis
    # (The old horizontal_transpose.py pass is gone: the Viterbi DP now
    # considers pitch-class-preserving whole-chord transpositions on every
    # transition and at phrase seams, so the greedy post-pass has nothing
    # left to shift.)
    #
    # Both analyses cover only this chorale.
    echo "Step 2: Running analyze_spread.py..."
    run python analyze_spread.py \
        --numpy_dir "$dir" \
        --chorale_list "$chorale" \
        --suffix="-opt.npy"

    # Step 3: adjacent-chord spread analysis
    echo "Step 3: Running analyze_adjacent_spread.py..."
    run python analyze_adjacent_spread.py \
        --numpy_dir "$dir" \
        --chorale_list "$chorale" \
        --suffix="-opt.npy" \
        --gap_threshold 15 \
        --top 20

    echo "========================================"
    [ -n "$JOB_ID" ] && echo "Job ${JOB_ID} complete!"
    echo "Done: limit_max=${limit_max}  tolerance=${tolerance}  ratio_factor=${ratio}  (${chorale})"
    echo "Results saved to: $dir (${chorale})"
    echo "========================================"
}

# ── Single cell (the Kubernetes job) ────────────────────────────────────────
if [ -n "$LIMIT_MAX" ]; then
    for chorale in $CHORALES; do
        run_cell "$LIMIT_MAX" "$TOLERANCE" "$RATIO" "$chorale"
    done
    exit 0
fi

# ── The grid ────────────────────────────────────────────────────────────────
for limit_max in "${LIMIT_MAXES[@]}"; do
    for tolerance in "${TOLERANCES[@]}"; do
        for ratio in "${RATIOS[@]}"; do
            for chorale in $CHORALES; do
                run_cell "$limit_max" "$tolerance" "$ratio" "$chorale"
            done
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
run python select_best_and_render.py \
    --numpy_dir_root Archive/straw-man \
    --chorale_list $CHORALES \
    --suffix="-opt.npy" \
    --sort_by p90

echo "========================================"
echo "Done."
echo "========================================"
