#!/usr/bin/env bash
# Generate 20 Kubernetes Job manifests for grid search parallelization
# Each job runs one parameter combination independently

set -euo pipefail

TEMPLATE="k8s-grid-search-job-template.yaml"
OUTPUT_DIR="k8s-jobs"

# Parameter arrays (matching grid_search.sh)
LIMIT_MAXES=(17 19)
TOLERANCES=(1 2)
RATIOS=(1.125 1.25 1.375 1.5 1.625)

echo "Generating Kubernetes Job manifests..."
echo "Template: $TEMPLATE"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Counter for job IDs
job_counter=1

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
            
            echo "[$job_num/20] Generated: $output_file"
            echo "         Parameters: limit_max=$limit_max, tolerance=$tolerance, ratio=$ratio"
            
            ((job_counter++))
        done
    done
done

echo ""
echo "✓ Generated $((job_counter - 1)) Job manifests in $OUTPUT_DIR/"
echo ""
echo "Next steps:"
echo "  1. Review the generated manifests in $OUTPUT_DIR/"
echo "  2. Deploy all jobs: ./deploy-grid-search-jobs.sh"
echo "  3. Monitor progress: kubectl get jobs -l app=grid-search"
echo "  4. After all complete, run the aggregation job"

# Made with Bob
