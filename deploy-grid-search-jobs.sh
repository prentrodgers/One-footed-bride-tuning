#!/usr/bin/env bash
# Deploy grid search Kubernetes Jobs at a fixed rate: one every INTERVAL seconds.
#
#     INTERVAL=180 ./deploy-grid-search-jobs.sh      # one job every 3 minutes
#     INTERVAL=30  ./deploy-grid-search-jobs.sh      # one every 30s
#     SKIP_SYNC=1  ./deploy-grid-search-jobs.sh      # repo already current
#
# Earlier versions watched the cluster and submitted when a slot looked free.
# That kept deadlocking: a pod wedged in CreateContainerError reports
# status.phase=Pending, so it held its slot forever, and the loop either waited
# on dots indefinitely or gave up after ten minutes having submitted 38 of 120.
# Reading cluster state to decide when to submit means cluster trouble stops
# submission entirely, which is backwards — Kubernetes is perfectly happy to
# queue Pending pods and start them as capacity appears.
#
# So: submit blind, at a rate you choose, and let the scheduler do its job.
#
# Picking INTERVAL.  Roughly, concurrent_jobs ~= job_duration / INTERVAL.  A job
# is about 2-3 minutes, so INTERVAL=180 gives ~1 at a time (and 120 jobs takes 6
# hours), INTERVAL=60 gives ~3, INTERVAL=30 gives ~5-6.  Start slow while the
# cluster is unwell and work down until pods stop wedging.

set -euo pipefail

JOBS_DIR="k8s-jobs"
INTERVAL="${INTERVAL:-180}"
SKIP_SYNC="${SKIP_SYNC:-0}"

job_count=$(find "$JOBS_DIR" -name "grid-search-job-*.yaml" 2>/dev/null | wc -l)
if [ "$job_count" -eq 0 ]; then
    echo "ERROR: no job manifests in $JOBS_DIR/ — run ./generate-grid-search-jobs.sh" >&2
    exit 1
fi

echo "$job_count jobs, one every ${INTERVAL}s"
echo "estimated submission time: $(( job_count * INTERVAL / 60 )) minutes"
echo ""

# Sync the shared checkout ONCE.  The grid jobs carry no git-sync container, so
# every one of them runs whatever this leaves behind — a failed sync means the
# whole batch runs stale code.
if [ "$SKIP_SYNC" = "1" ]; then
    echo "SKIP_SYNC=1 — not syncing; jobs will run whatever is already on the volume"
else
    echo "Syncing the repo on the cluster..."
    kubectl delete job grid-search-git-sync --ignore-not-found >/dev/null 2>&1
    kubectl apply -f k8s-git-sync-job.yaml >/dev/null
    if ! kubectl wait --for=condition=complete --timeout=300s job/grid-search-git-sync >/dev/null 2>&1; then
        echo "ERROR: git-sync did not complete — the batch would run stale code." >&2
        echo "  kubectl describe pod -l app=grid-search-sync | grep -A15 Events" >&2
        echo "  (if the checkout is already current, rerun with SKIP_SYNC=1)" >&2
        exit 1
    fi
    kubectl logs -l app=grid-search-sync --tail=3 2>/dev/null | sed 's/^/  /'
fi
echo ""

i=0
for job_file in "$JOBS_DIR"/grid-search-job-*.yaml; do
    i=$((i + 1))
    name=$(basename "$job_file" .yaml)
    printf '[%3d/%3d] %-46s ' "$i" "$job_count" "$name"
    if kubectl apply -f "$job_file" >/dev/null 2>&1; then
        # Counts are for tuning INTERVAL, not for gating submission.
        counts=$(kubectl get po -l app=grid-search --no-headers 2>/dev/null \
                 | awk '{c[$3]++} END {printf "run=%d pend=%d done=%d err=%d",
                         c["Running"]+0, c["Pending"]+0, c["Completed"]+0,
                         NR-c["Running"]-c["Pending"]-c["Completed"]}')
        echo "OK   $counts"
    else
        echo "FAILED"
    fi
    [ "$i" -lt "$job_count" ] && sleep "$INTERVAL"
done

echo ""
echo "All $job_count submitted. Monitor with:"
echo "  kubectl get po -l app=grid-search -o wide --sort-by=.status.phase"
echo "  kubectl get jobs -l app=grid-search --field-selector status.successful=1 --no-headers | wc -l"
echo "  ssh one-footed-bride-pod 'ls Repos/One-footed-bride-tuning/Archive/straw-man/*/bwv*-opt.npy | wc -l'"
