#!/usr/bin/env bash
# ray-ratchet.sh — run the tuning grid on a Ray cluster and ratchet every cell
# until it stops improving.  The Ray-era replacement for
# generate-grid-search-jobs.sh + deploy-grid-search-jobs.sh + ratchet-passes.sh
# + ratchet-until-still.sh.
#
#     ./ray-ratchet.sh                                       # 24 cells x bwv415..426
#     ./ray-ratchet.sh --chorales bwv415 bwv419 --patience 3 # anything ray_ratchet.py takes
#     ./ray-ratchet.sh --dry_run                             # the plan only; no cluster
#     ./ray-ratchet.sh --attach                              # follow a run this shell lost
#     SKIP_SYNC=1    ./ray-ratchet.sh ...                    # the PVC checkout is already current
#     KEEP_CLUSTER=1 ./ray-ratchet.sh ...                    # leave the cluster up afterwards
#     POWER=0        ./ray-ratchet.sh ...                    # don't touch the tuned profiles
#
# In order:
#   1. sync the PVC checkout to origin/main (k8s-git-sync-job.yaml) — the
#      worker pods run grid_search.sh and the tuner FROM THAT CHECKOUT, so a
#      commit that is not pushed does not run.  Same job the Job-based deploy
#      used, same reason.
#   2. fleet to powersave-gpu (power-save-all.sh), back to balanced at the end
#      or on interrupt.
#   3. kubectl apply k8s-ray-cluster.yaml and wait for head and workers.
#   4. submit ray_ratchet.py as a Ray job on the head and follow its log.  The
#      job runs on the head, not in this shell: if the ssh session drops, the
#      run continues and `./ray-ratchet.sh --attach` picks the log back up.
#   5. delete the RayCluster — its pods hold most of what fs2-fs9 have free.
#
# Dashboard while it runs:  kubectl port-forward svc/tuning-head-svc 8265:8265
# then http://localhost:8265 (per-task CPU and memory, worker logs).
set -euo pipefail
CLUSTER=tuning
REPO=/home/prent/Repos/One-footed-bride-tuning
SKIP_SYNC="${SKIP_SYNC:-0}"; KEEP_CLUSTER="${KEEP_CLUSTER:-0}"; POWER="${POWER:-1}"
log(){ echo "$(date +%T) $*"; }

head_pod(){ kubectl get pod -l "ray.io/cluster=$CLUSTER,ray.io/node-type=head" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null; }
rayx(){ kubectl exec "$(head_pod)" -c ray-head -- "$@"; }   # run on the head
DASH=http://127.0.0.1:8265                                   # the dashboard, from the head itself

# --attach: follow the newest job on a cluster that is already up.
if [ "${1:-}" = "--attach" ]; then
    [ -n "$(head_pod)" ] || { echo "no $CLUSTER cluster is running" >&2; exit 1; }
    id=$(rayx curl -s "$DASH/api/jobs/" | python3 -c 'import json,sys; j=json.load(sys.stdin); print(sorted(j, key=lambda x: x.get("start_time") or 0)[-1]["submission_id"])')
    log "following job $id (ctrl-c leaves it running)"
    exec kubectl exec -it "$(head_pod)" -c ray-head -- ray job logs --address "$DASH" -f "$id"
fi

# --dry_run needs no cluster: the plan is printed by the driver locally.
case " $* " in *" --dry_run "*) exec python3 ray_ratchet.py "$@";; esac

# 1. sync
if [ "$SKIP_SYNC" = 1 ]; then
    log "SKIP_SYNC=1 — the workers run whatever is on the PVC checkout now"
else
    ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo '?')
    [ "$ahead" = 0 ] || log "NOTE: $ahead local commit(s) not pushed — the workers will not run them"
    log "syncing the PVC checkout to origin/main"
    kubectl delete job grid-search-git-sync --ignore-not-found >/dev/null 2>&1
    kubectl apply -f k8s-git-sync-job.yaml >/dev/null
    kubectl wait --for=condition=complete --timeout=300s job/grid-search-git-sync >/dev/null \
        || { echo "git-sync did not complete: kubectl logs job/grid-search-git-sync" >&2; exit 1; }
    kubectl logs job/grid-search-git-sync --tail=2 | sed 's/^/    /'
fi

# 2. power, and the teardown that undoes everything on exit
cleanup(){
    rc=$?
    if [ "$KEEP_CLUSTER" = 1 ]; then
        log "KEEP_CLUSTER=1 — cluster left up:  kubectl delete raycluster $CLUSTER"
    else
        log "deleting the RayCluster"
        kubectl delete raycluster "$CLUSTER" --ignore-not-found --wait=false >/dev/null
    fi
    [ "$POWER" = 1 ] && ./power-balanced.sh | grep -E "all hosts|problems" || true
    exit $rc
}
trap cleanup EXIT
if [ "$POWER" = 1 ]; then
    ./power-save-all.sh | grep -E "all hosts|problems|FAILED|MISMATCH"
fi

# 3. the cluster
log "applying k8s-ray-cluster.yaml"
kubectl apply -f k8s-ray-cluster.yaml >/dev/null
want=$(kubectl get raycluster "$CLUSTER" -o jsonpath='{range .spec.workerGroupSpecs[*]}{.replicas}{"\n"}{end}' | awk '{s+=$1} END {print s}')
for i in $(seq 1 60); do
    ready=$(kubectl get pod -l "ray.io/cluster=$CLUSTER" -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null | grep -c true || true)
    [ "$ready" -ge $((want + 1)) ] && break
    [ $((i % 6)) -eq 0 ] && log "  $ready/$((want + 1)) pods ready... $(kubectl get pod -l "ray.io/cluster=$CLUSTER" --no-headers 2>/dev/null | awk '{c[$3]++} END {for (k in c) printf "%s=%d ", k, c[k]}')"
    sleep 10
done
if [ "$ready" -lt $((want + 1)) ]; then
    echo "only $ready/$((want + 1)) pods ready after 10 minutes:" >&2
    kubectl get pod -l "ray.io/cluster=$CLUSTER" -o wide >&2
    echo "a Pending worker usually means its node has less free CPU/memory than k8s-ray-cluster.yaml assumes:" >&2
    echo "  kubectl describe pod <pod> | grep -A5 Events" >&2
    exit 1
fi
log "cluster up: 1 head + $want workers"
rayx ray status 2>/dev/null | sed -n '/Resources/,/Demands/p' | grep -E "CPU|memory" | sed 's/^/    /'

# 4. the job — on the head, detached from this shell
id="ratchet-$(date +%Y%m%d-%H%M%S)"
log "submitting $id: python ray_ratchet.py $*"
rayx ray job submit --address "$DASH" --submission-id "$id" --no-wait \
    -- bash -c "cd $REPO && exec python ray_ratchet.py $*" | grep -v '^$' | sed 's/^/    /'
echo
log "following the log (ctrl-c stops following, not the run; ./ray-ratchet.sh --attach resumes)"
set +e
kubectl exec "$(head_pod)" -c ray-head -- ray job logs --address "$DASH" -f "$id"
# The job's state from the dashboard API, not the CLI: `ray job status`
# prints through its logger to stderr, decorated, and is awkward to parse.
status=$(rayx curl -s "$DASH/api/jobs/$id" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status", "UNKNOWN"))' 2>/dev/null || echo UNKNOWN)
set -e
log "job $id: $status"
case "$status" in
    SUCCEEDED) ;;
    RUNNING|PENDING) KEEP_CLUSTER=1; log "still running — cluster left up; ./ray-ratchet.sh --attach";;
    *) log "job did not succeed ($status); cluster left up for a look:  ./ray-ratchet.sh --attach"
       KEEP_CLUSTER=1; exit 1;;
esac
