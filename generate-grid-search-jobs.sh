#!/usr/bin/env bash
# Generate Kubernetes Job manifests for grid search parallelization
# Each job runs one parameter combination independently
# lm19 and r1.125 dropped: lm17 dominates (57 vs 31 improvements), r1.125 weakest ratio

set -euo pipefail
TEMPLATE="k8s-grid-search-job-template.yaml"
OUTPUT_DIR="k8s-jobs"

# Parameter arrays
LIMIT_MAXES=(17)
TOLERANCES=(3)
RATIOS=(1.5)


echo "Generating Kubernetes Job manifests..."
echo "Template: $TEMPLATE"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Counter for job IDs
job_counter=1
total_jobs=$(( ${#LIMIT_MAXES[@]} * ${#TOLERANCES[@]} * ${#RATIOS[@]} ))

# Generate a manifest for each parameter combination
for limit_max in "${LIMIT_MAXES[@]}"; do
    for tolerance in "${TOLERANCES[@]}"; do
        for ratio in "${RATIOS[@]}"; do
            # Create a unique job ID
            job_id=$(printf "lm%d-t%d-r%s" "$limit_max" "$tolerance" "$ratio" | tr '.' '-')
            job_num=$(printf "%02d" "$job_counter")
            
            # Output filename
            output_file="${OUTPUT_DIR}/grid-search-job-${job_num}-${job_id}.yaml"
            
            # Generate the manifest by replacing placeholders
            sed -e "s/JOBID/${job_num}-${job_id}/g" \
                -e "s/LIMIT_MAX_VALUE/${limit_max}/g" \
                -e "s/TOLERANCE_VALUE/${tolerance}/g" \
                -e "s/RATIO_VALUE/${ratio}/g" \
                "$TEMPLATE" > "$output_file"
            
            echo "[$job_num/$(printf "%02d" "$total_jobs")] Generated: $output_file"
            echo "         Parameters: limit_max=$limit_max, tolerance=$tolerance, ratio=$ratio"
            
            ((job_counter++))
        done
    done
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
