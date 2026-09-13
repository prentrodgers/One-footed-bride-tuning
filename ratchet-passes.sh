#!/usr/bin/env bash
# ratchet-passes.sh — run the manifests in k8s-jobs/ as a batch, wait for
# every job to finish, and repeat.  Each pass re-runs the same cells with
# FRESH=0, so the keep-previous ratchet in the tuner keeps whichever result
# is better; the original twelve chorales took about a dozen such passes to
# reach GapSum 0.  Generate the manifests first, e.g. for a hand-picked list:
#
#     CELLS_FILE=ratchet-cells.txt ./generate-grid-search-jobs.sh
#     PASSES=4 ./ratchet-passes.sh
#
# Between passes the finished jobs are deleted: a Job's spec is immutable, so
# re-applying an existing name would be a no-op instead of a new run.
# INTERVAL (default 30s) and SKIP_SYNC pass through to deploy-grid-search-jobs.sh;
# the sync only matters on the first pass, later ones skip it.
set -euo pipefail
PASSES="${PASSES:-1}"
INTERVAL="${INTERVAL:-30}"
# Power is handled once around all the passes, not per deploy: the fleet
# goes to powersave-gpu here and back to balanced at the end.
export POWER=0
n_jobs=$(ls k8s-jobs/grid-search-job-*.yaml 2>/dev/null | wc -l)
[ "$n_jobs" -gt 0 ] || { echo "no manifests in k8s-jobs/ — run generate-grid-search-jobs.sh first" >&2; exit 1; }

# RATCHET_POWER=0 leaves the profiles to the caller (ratchet-until-still.sh
# switches once around many short passes instead of on every one).
if [ "${RATCHET_POWER:-1}" = 1 ]; then
    ./power-save-all.sh | grep -E "all hosts|problems|FAILED|MISMATCH"
    trap './power-balanced.sh | grep -E "all hosts|problems"' EXIT
fi

for pass in $(seq 1 "$PASSES"); do
    echo "===== pass $pass of $PASSES: $n_jobs jobs  $(date +%F\ %T)"
    kubectl delete jobs -l app=grid-search --ignore-not-found --wait=true >/dev/null
    if [ "$pass" -gt 1 ]; then export SKIP_SYNC=1; fi
    INTERVAL="$INTERVAL" ./deploy-grid-search-jobs.sh
    # wait for every job to reach Complete or Failed
    while :; do
        done_n=$(kubectl get jobs -l app=grid-search --no-headers 2>/dev/null | awk '$2=="Complete"||$2=="Failed"' | wc -l)
        [ "$done_n" -ge "$n_jobs" ] && break
        sleep 30
    done
    echo "----- pass $pass finished $(date +%T): $(kubectl get jobs -l app=grid-search --no-headers | awk '{print $2}' | sort | uniq -c | tr '\n' ' ')"
done
echo "all $PASSES passes done"
