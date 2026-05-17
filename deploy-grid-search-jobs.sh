#!/usr/bin/env bash
# Deploy all grid search Kubernetes Jobs to the cluster
# This script applies all 20 job manifests in parallel

set -euo pipefail

JOBS_DIR="k8s-jobs"

echo "========================================"
echo "Grid Search Kubernetes Deployment"
echo "========================================"
echo ""

# Check if jobs directory exists
if [ ! -d "$JOBS_DIR" ]; then
    echo "ERROR: Jobs directory '$JOBS_DIR' not found!"
    echo "Please run ./generate-grid-search-jobs.sh first."
    exit 1
fi

# Count job manifests
job_count=$(find "$JOBS_DIR" -name "grid-search-job-*.yaml" | wc -l)

if [ "$job_count" -eq 0 ]; then
    echo "ERROR: No job manifests found in $JOBS_DIR/"
    echo "Please run ./generate-grid-search-jobs.sh first."
    exit 1
fi

echo "Found $job_count job manifests in $JOBS_DIR/"
echo ""

# Confirm deployment
read -p "Deploy all $job_count jobs to Kubernetes cluster? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Deploying jobs..."
echo ""

# Apply all job manifests
deployed=0
failed=0

for job_file in "$JOBS_DIR"/grid-search-job-*.yaml; do
    job_name=$(basename "$job_file" .yaml)
    echo -n "Deploying $job_name... "
    
    if kubectl apply -f "$job_file" > /dev/null 2>&1; then
        echo "✓"
        ((deployed++))
    else
        echo "✗ FAILED"
        ((failed++))
    fi
done

echo ""
echo "========================================"
echo "Deployment Summary"
echo "========================================"
echo "Successfully deployed: $deployed jobs"
echo "Failed: $failed jobs"
echo ""

if [ "$failed" -gt 0 ]; then
    echo "WARNING: Some jobs failed to deploy. Check kubectl logs for details."
    echo ""
fi

echo "Monitoring commands:"
echo "  • Watch job status:    kubectl get jobs -l app=grid-search -w"
echo "  • List all jobs:       kubectl get jobs -l app=grid-search"
echo "  • View job details:    kubectl describe job <job-name>"
echo "  • View pod logs:       kubectl logs -l app=grid-search --tail=50"
echo "  • Count completed:     kubectl get jobs -l app=grid-search --field-selector status.successful=1 | wc -l"
echo ""
echo "After all jobs complete (20/20), run the aggregation job:"
echo "  kubectl apply -f k8s-grid-search-aggregation-job.yaml"
echo ""
echo "To delete all jobs:"
echo "  kubectl delete jobs -l app=grid-search"
echo ""

# Made with Bob
