#!/usr/bin/env bash
# ray-ratchet-vm-agent.sh — the half of ray-ratchet-vm.sh that runs ON the VM.
#
# ray-ratchet-vm.sh copies this to <VM_BASE>/agent.sh (default ~/ofb-tuning) and
# calls its subcommands over ssh.  Nothing here needs typing by hand, though all
# of it can be:   bash ~/ofb-tuning/agent.sh facts
#
# What is on the VM, all under <VM_BASE>:
#   agent.sh                       this file
#   home/                          the container's /home/prent (writable, like the
#                                  emptyDir in k8s-ray-cluster.yaml)
#   home/Repos/One-footed-bride-tuning/
#                                  the code (root *.py, *.sh, Scores/) and
#                                  Archive/straw-man/ with the tunings shipped in
#   run/env                        what the launcher decided: IMAGE, RAY_CPUS,
#                                  VITERBI_WORKERS, TZ_NAME, POWEROFF_CMD
#   run/id                         the submitted job's id
#   run/done                       the job's final status, written by `watch`
#                                  once the results are packed
#   run/collected                  the launcher has the results (checksum verified)
#   results-<id>.tar.gz(.sha256)   Archive/straw-man and the driver log, packed
#                                  when the job ends
#
# One container, no Kubernetes: `ray start --head` with every core as the one
# node, and the same image, environment and paths as the KubeRay pods, so
# grid_search.sh and the tuner cannot tell the difference.
set -euo pipefail
BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RUN=$BASE/run
HOMED=$BASE/home
REPO=$HOMED/Repos/One-footed-bride-tuning            # on the VM's disk
REPO_IN=/home/prent/Repos/One-footed-bride-tuning    # the same directory, inside the container
NAME=${OFB_CONTAINER:-ofb-ray}
DASH=http://127.0.0.1:8265                           # inside the container only: never published
mkdir -p "$RUN"
# shellcheck disable=SC1091
[ -f "$RUN/env" ] && . "$RUN/env"
IMAGE=${IMAGE:-quay.io/prentrodgers/python-music:0.11}

# docker if this user can talk to it, else podman, else docker through sudo
# (Ubuntu cloud images: docker installed, login user not in the docker group).
RT=()
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then RT=(docker)
elif command -v podman >/dev/null 2>&1; then RT=(podman)
elif command -v docker >/dev/null 2>&1 && sudo -n docker info >/dev/null 2>&1; then RT=(sudo -n docker)
fi
need_rt(){ [ ${#RT[@]} -gt 0 ] || { echo "no docker or podman on $(hostname) (or this user cannot use it)" >&2; exit 3; }; }
running(){ [ ${#RT[@]} -gt 0 ] && [ -n "$("${RT[@]}" ps -q --filter "name=^${NAME}\$" 2>/dev/null)" ]; }
in_c(){ "${RT[@]}" exec -w "$REPO_IN" "$NAME" "$@"; }
job_id(){ cat "$RUN/id" 2>/dev/null || true; }

# The job's state from the dashboard API, as ray-ratchet.sh reads it.  LOST =
# the container is gone (so is the job); UNKNOWN = it is up but did not answer.
live_status(){
    local id=${1:-$(job_id)}
    [ -n "$id" ] || { echo NOJOB; return; }
    running || { echo LOST; return; }
    in_c python -c '
import json, sys, urllib.request
try:
    print(json.load(urllib.request.urlopen(sys.argv[1], timeout=20)).get("status", "UNKNOWN"))
except Exception:
    print("UNKNOWN")' "$DASH/api/jobs/$id" 2>/dev/null || echo UNKNOWN
}

pack(){
    local id; id=$(job_id)
    [ -n "$id" ] || { echo "no job has been submitted here" >&2; return 1; }
    local out=$BASE/results-$id.tar.gz
    # The driver's log is the only place a task failure's reason is printed, and
    # it goes with the container: keep a copy beside the results.
    if running; then in_c ray job logs --address "$DASH" "$id" > "$REPO/$id.log" 2>/dev/null || true; fi
    local extra=(); [ -s "$REPO/$id.log" ] && extra=("$id.log")
    tar -C "$REPO" -czf "$out.tmp" Archive/straw-man "${extra[@]}"
    mv "$out.tmp" "$out"
    sha256sum "$out" | awk '{print $1}' > "$out.sha256"
    sync
    echo "packed=$out bytes=$(stat -c %s "$out") sha256=$(cat "$out.sha256")"
}

cmd=${1:-}; [ $# -gt 0 ] && shift
case "$cmd" in
facts)   # key=value lines for the launcher
    echo "host=$(hostname)"
    echo "machine_id=$(cat /etc/machine-id 2>/dev/null || echo none)"
    echo "cores=$(nproc)"
    echo "mem_gib=$(awk '/MemTotal/ {printf "%.0f", $2/1048576}' /proc/meminfo)"
    echo "avail_gib=$(awk '/MemAvailable/ {printf "%.0f", $2/1048576}' /proc/meminfo)"
    echo "runtime=${RT[*]:-none}"
    if [ -n "${POWEROFF_CMD:-}" ] || [ "$(id -u)" = 0 ] || sudo -n true 2>/dev/null; then echo "can_poweroff=yes"; else echo "can_poweroff=no"; fi
    if [ ${#RT[@]} -gt 0 ] && "${RT[@]}" image inspect "$IMAGE" >/dev/null 2>&1; then echo "image=present"; else echo "image=absent"; fi
    echo "id=$(job_id)"
    if [ -f "$RUN/done" ]; then echo "job=$(cat "$RUN/done")"; else echo "job=$(live_status)"; fi
    if [ -e "$RUN/collected" ]; then echo "collected=yes"; else echo "collected=no"; fi
    ;;
pull)    need_rt; "${RT[@]}" pull "$IMAGE" ;;
load)    need_rt; "${RT[@]}" load ;;                      # an image archive on stdin
up)      # the container, Ray in it, and wait until the dashboard answers
    need_rt
    "${RT[@]}" rm -f "$NAME" >/dev/null 2>&1 || true
    mkdir -p "$REPO/Archive/straw-man" "$HOMED/Music/sflib"
    cpus=${RAY_CPUS:-$(nproc)}
    # Files the tuner writes must belong to the login user, or the results
    # cannot be packed (docker's root) or land under a sub-uid (rootless podman).
    user=()
    if [ "$(id -u)" != 0 ]; then
        user=(--user "$(id -u):$(id -g)")
        [ "${RT[0]}" = podman ] && user+=(--userns=keep-id)
    fi
    # label=disable: an SELinux host would otherwise deny the bind mount.
    # pids-limit: podman's default 2048 is fewer threads than 28 Ray workers use.
    # No -p, and never --network host: Ray's dashboard and GCS are unauthenticated
    # remote code execution, so they stay inside the container's own network,
    # where no other machine can reach them.  (The dashboard is on the container's
    # loopback; the GCS binds the container's address whatever it is told --
    # Ray 2.58 turns --node-ip-address=127.0.0.1 back into that address.)
    "${RT[@]}" run -d --name "$NAME" --entrypoint bash \
        --security-opt label=disable --pids-limit=-1 --shm-size=1g "${user[@]}" \
        -e HOME=/home/prent -e LOGNAME=prent -e USER=prent \
        -e FRESH=0 -e VITERBI_WORKERS="${VITERBI_WORKERS:-4}" \
        -e SFDIR=/home/prent/Music/sflib -e SSDIR=/home/prent/Music/sflib \
        -e TZ="${TZ_NAME:-America/Los_Angeles}" \
        -v "$HOMED:/home/prent" -w "$REPO_IN" \
        "$IMAGE" -c "exec ray start --head --num-cpus=$cpus --object-store-memory=500000000 --dashboard-host=127.0.0.1 --dashboard-port=8265 --disable-usage-stats --block" >/dev/null
    for i in $(seq 1 60); do
        running || { echo "the Ray container exited:" >&2; "${RT[@]}" logs --tail 30 "$NAME" >&2 || true; exit 1; }
        in_c curl -sf "$DASH/api/gcs_healthz" >/dev/null 2>&1 && break
        [ "$i" = 60 ] && { echo "Ray's dashboard did not come up in 2 minutes:" >&2; "${RT[@]}" logs --tail 30 "$NAME" >&2 || true; exit 1; }
        sleep 2
    done
    in_c ray status 2>/dev/null | sed -n '/Resources/,/Demands/p' | grep -E "CPU|memory" | sed 's/^/    /' || true
    ;;
submit)  # submit <id> <ray_ratchet.py arguments...>
    id=$1; shift
    rm -f "$RUN/done" "$RUN/collected"
    echo "$id" > "$RUN/id"
    args=$(printf '%q ' "$@")
    in_c ray job submit --address "$DASH" --submission-id "$id" --no-wait \
        -- bash -c "cd $REPO_IN && exec python ray_ratchet.py $args" | grep -v '^$' | sed 's/^/    /'
    ;;
status)  if [ -f "$RUN/done" ]; then cat "$RUN/done"; else live_status "${1:-}"; fi ;;
logs)    id=${1:-$(job_id)}; exec "${RT[@]}" exec "$NAME" ray job logs --address "$DASH" -f "$id" ;;
stopjob) id=${1:-$(job_id)}; running && in_c ray job stop --address "$DASH" "$id" 2>&1 | tail -2 || true ;;
pack)    pack ;;
results) id=${1:-$(job_id)}; cat "$BASE/results-$id.tar.gz" ;;   # the packed results, to stdout
watch)   # watch <minutes> <poweroff 0|1>: detached on the VM, so the run ends properly with no launcher attached
    minutes=${1:-60}; poweroff=${2:-0}; unknown=0
    while :; do
        s=$(live_status)
        case "$s" in
            RUNNING|PENDING) unknown=0;;
            UNKNOWN) unknown=$((unknown + 1)); [ "$unknown" -ge 30 ] && break;;   # ten minutes of no answer
            *) break;;
        esac
        sleep 20
    done
    echo "$(date '+%F %T') job $(job_id): $s"
    pack
    echo "$s" > "$RUN/done"
    if [ "$poweroff" != 1 ] || [ "$minutes" -le 0 ]; then echo "no unattended power-off asked for"; exit 0; fi
    echo "$(date '+%F %T') results are packed; powering off in $minutes minutes unless the launcher collects them first"
    deadline=$(( $(date +%s) + minutes * 60 ))
    while [ "$(date +%s)" -lt "$deadline" ]; do
        # collected: the launcher is here and powers the VM off itself.  keep: asked to stay up.
        if [ -e "$RUN/collected" ] || [ -e "$RUN/keep" ]; then echo "$(date '+%F %T') launcher took over"; exit 0; fi
        sleep 15
    done
    echo "$(date '+%F %T') nobody collected: powering off with the results in $BASE/results-$(job_id).tar.gz"
    "${RT[@]}" rm -f "$NAME" >/dev/null 2>&1 || true
    exec bash "$BASE/agent.sh" poweroff --yes
    ;;
down)    [ ${#RT[@]} -gt 0 ] && "${RT[@]}" rm -f "$NAME" >/dev/null 2>&1 || true ;;
poweroff)
    [ "${1:-}" = "--yes" ] || { echo "poweroff needs --yes" >&2; exit 2; }
    sync
    # POWEROFF_CMD (run/env, from the launcher's VM_POWEROFF_CMD): what stops the
    # billing from inside where `shutdown` cannot, e.g. a container pod's own CLI.
    if [ -n "${POWEROFF_CMD:-}" ]; then echo "poweroff: $POWEROFF_CMD"; bash -c "$POWEROFF_CMD"
    # +1: a minute's notice, so the ssh session that asked returns cleanly.
    elif [ "$(id -u)" = 0 ]; then shutdown -h +1 || poweroff
    else sudo -n shutdown -h +1 || sudo -n poweroff; fi
    ;;
*)  echo "usage: agent.sh facts|pull|load|up|submit|status|logs|stopjob|pack|results|watch|down|poweroff" >&2; exit 2 ;;
esac
