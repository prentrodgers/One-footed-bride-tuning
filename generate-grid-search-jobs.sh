#!/usr/bin/env bash
# Generate Kubernetes Job manifests for grid search parallelization
# One job per (parameter cell x chorale).  The chorales are independent, so
# splitting them out multiplies the job count by 12 and removes the serial
# per-chorale loop — a job that tuned all twelve ran ~60s single-threaded per
# chorale with most of its cores idle.  All twelve jobs for a cell write into
# the same result directory, but each touches only its own {chorale}-opt.npy.
# lm19 and r1.125 dropped: lm17 dominates (57 vs 31 improvements), r1.125 weakest ratio

set -euo pipefail
TEMPLATE="k8s-grid-search-job-template.yaml"
OUTPUT_DIR="k8s-jobs"

# Parameter arrays
LIMIT_MAXES=(17 19)
TOLERANCES=(1 2 3)
# These literals ARE the cell directory name (t{T}_r{RATIO}_lm{LM} in the job
# template), so 1.5 and 1.50 are two different cells with two separate
# ratchets. Keep the spelling that the existing Archive/straw-man dirs use.
RATIOS=(1.25 1.375 1.50 1.625)
# Chorales: the first argument, else CHORALES in the environment, else the
# original twelve.  Space-separated, bwv prefix included:
#     ./generate-grid-search-jobs.sh "$(echo bwv{427..438})"
#     CHORALES="bwv262 bwv267" ./generate-grid-search-jobs.sh
CHORALES=(${1:-${CHORALES:-$(echo bwv{253..264})}})
for c in "${CHORALES[@]}"; do
    case "$c" in bwv*) ;; *) echo "chorale names need the bwv prefix: got '$c'" >&2; exit 2;; esac
done

# Or a hand-picked list instead of the full product — for ratcheting only
# the cells worth another pass.  CELLS_FILE names a file of lines
#     limit_max tolerance ratio chorale        e.g.   19 3 1.375 bwv432
# (blank lines and # comments ignored; the ratio spelled as the cell dir).
# The parameter arrays and CHORALES above are then not used.
CELLS_FILE="${CELLS_FILE:-}"

echo "Generating Kubernetes Job manifests..."
echo "Template: $TEMPLATE"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# One line per job, "limit_max tolerance ratio chorale", from the product of
# the arrays or straight from CELLS_FILE.
if [ -n "$CELLS_FILE" ]; then
    [ -r "$CELLS_FILE" ] || { echo "cannot read CELLS_FILE=$CELLS_FILE" >&2; exit 2; }
    # comments (# to end of line) dropped, exactly four fields kept
    mapfile -t CELLS < <(sed 's/#.*//' "$CELLS_FILE" | awk 'NF==4 {print $1, $2, $3, $4}')
    echo "Cells: ${#CELLS[@]} from $CELLS_FILE"
else
    CELLS=()
    for limit_max in "${LIMIT_MAXES[@]}"; do
        for tolerance in "${TOLERANCES[@]}"; do
            for ratio in "${RATIOS[@]}"; do
                for chorale in "${CHORALES[@]}"; do
                    CELLS+=("$limit_max $tolerance $ratio $chorale")
                done
            done
        done
    done
fi

# Counter for job IDs
job_counter=1
total_jobs=${#CELLS[@]}

# Generate a manifest for each cell
for cell in "${CELLS[@]}"; do
    read -r limit_max tolerance ratio chorale <<<"$cell"
    case "$chorale" in bwv*) ;; *) echo "bad cell line: '$cell'" >&2; exit 2;; esac
    {
        {
            {
                # Create a unique job ID.  k8s names are lowercase alphanumeric
                # and '-', so the ratio's '.' is translated out.
                job_id=$(printf "lm%d-t%d-r%s-%s" "$limit_max" "$tolerance" "$ratio" "$chorale" | tr '.' '-')
                job_num=$(printf "%03d" "$job_counter")

                # Output filename
                output_file="${OUTPUT_DIR}/grid-search-job-${job_num}-${job_id}.yaml"

                # Generate the manifest by replacing placeholders
                sed -e "s/JOBID/${job_num}-${job_id}/g" \
                    -e "s/LIMIT_MAX_VALUE/${limit_max}/g" \
                    -e "s/TOLERANCE_VALUE/${tolerance}/g" \
                    -e "s/RATIO_VALUE/${ratio}/g" \
                    -e "s/CHORALE_VALUE/${chorale}/g" \
                    "$TEMPLATE" > "$output_file"

                echo "[$job_num/$(printf "%03d" "$total_jobs")] Generated: $output_file"
                echo "         Parameters: limit_max=$limit_max, tolerance=$tolerance, ratio=$ratio, chorale=$chorale"

                ((job_counter++))
            }
        }
    }
done

echo ""
echo "✓ Generated $((job_counter - 1))/$total_jobs Job manifests in $OUTPUT_DIR/"
echo ""
echo "Next steps:"
echo "  1. Review the generated manifests in $OUTPUT_DIR/"
echo "  2. Deploy all jobs: ./deploy-grid-search-jobs.sh"
echo "  3. Monitor progress: kubectl get jobs -l app=grid-search"
echo "  4. After all complete, run the aggregation job"

# Made with Bob
