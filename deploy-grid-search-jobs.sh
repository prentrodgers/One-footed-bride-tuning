#!/usr/bin/env bash
# Deploy grid search Kubernetes Jobs one at a time.
# Waits for each pod to reach Running before submitting the next job.

set -euo pipefail

JOBS_DIR="k8s-jobs"

echo "========================================"
echo "Grid Search Kubernetes Deployment"
echo "========================================"
echo ""

if [ ! -d "$JOBS_DIR" ]; then
    echo "ERROR: Jobs directory '$JOBS_DIR' not found!"
    echo "Please run ./generate-grid-search-jobs.sh first."
    exit 1
fi

job_count=$(find "$JOBS_DIR" -name "grid-search-job-*.yaml" | wc -l)

if [ "$job_count" -eq 0 ]; then
    echo "ERROR: No job manifests found in $JOBS_DIR/"
    echo "Please run ./generate-grid-search-jobs.sh first."
    exit 1
fi

echo "Found $job_count job manifests in $JOBS_DIR/"
echo ""

read -p "Deploy all $job_count jobs to Kubernetes cluster? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""

wait_for_running() {
    local job_name="$1"
    echo -n "  Waiting for pod to reach Running..."
    while true; do
        not_ready=$(kubectl get po -l app=grid-search \
            --field-selector='status.phase!=Running,status.phase!=Succeeded,status.phase!=Failed' \
            --no-headers 2>/dev/null | wc -l)
        if [ "$not_ready" -eq 0 ]; then
            echo " Running."
            return
        fi
        echo -n "."
        sleep 10
    done
}

deployed=0
failed=0

for job_file in "$JOBS_DIR"/grid-search-job-*.yaml; do
    job_name=$(basename "$job_file" .yaml)
    echo -n "Deploying $job_name... "

    if kubectl apply -f "$job_file" > /dev/null 2>&1; then
        echo "OK"
        deployed=$((deployed + 1))
    else
        echo "FAILED"
        failed=$((failed + 1))
        continue
    fi

    # Wait for this pod to be Running before submitting the next job
    remaining=$(( job_count - deployed - failed ))
    if [ "$remaining" -gt 0 ]; then
        wait_for_running "$job_name"
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
echo "  Watch job status:    kubectl get jobs -l app=grid-search -w"
echo "  List all jobs:       kubectl get jobs -l app=grid-search"
echo "  Pod status:          kubectl get po -l app=grid-search -o wide"
echo "  View pod logs:       kubectl logs -l app=grid-search --tail=50"
echo "  Count completed:     kubectl get jobs -l app=grid-search --field-selector status.successful=1 | wc -l"
echo ""
echo "To delete all jobs:"
echo "  kubectl delete jobs -l app=grid-search"
echo ""

# Made with Bob
