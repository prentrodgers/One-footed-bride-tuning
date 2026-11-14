#!/usr/bin/env bash
# ray-ratchet-vm.sh — ray-ratchet.sh's run on ONE rented Linux VM instead of the
# KubeRay cluster: the same ray_ratchet.py job, the same image, Ray as a single
# node in one container.  No Kubernetes, no PVC, no power profiles.
#
#     VM=user@host ./ray-ratchet-vm.sh --chorales bwv846f bwv847f     # anything ray_ratchet.py takes
#     VM=user@host ./ray-ratchet-vm.sh --attach        # follow a run this shell lost; collect when it ends
#     VM=user@host ./ray-ratchet-vm.sh --stop          # stop the job, collect what it has, power off
#     ./ray-ratchet-vm.sh --chorales bwv846f --dry_run # the plan only; no VM
#     ./ray-ratchet-vm.sh --help
#
# The VM: any stock Linux with docker or podman and ssh key login.  Its cores set
# the task slots (cores / 4), so nothing here assumes the home cluster's 29.
# The home cluster's 28 tasks x (4 CPU + 2.5 GiB) want 112 cores and 80 GiB;
# fewer cores is the same run, slower.
#
# Environment:
#   VM=user@host        the VM (ssh).  VM=local runs the VM half on this machine.
#   VM_SSH_OPTS="-p 2222 -i ~/.ssh/key"
#   IMAGE=quay.io/prentrodgers/python-music:0.11
#   IMAGE_HOST=fs2      a host whose podman holds IMAGE: the image is streamed
#                       from there to the VM (the quay.io repository is private,
#                       so a new VM cannot pull it unless it has been logged in:
#                       ssh $VM docker login quay.io).  Without IMAGE_HOST the
#                       VM pulls.
#   RESULTS_HOST=one-footed-bride-pod   where the tunings live: the PVC checkout
#                       the cluster's workers write (Archive/straw-man/ is not in
#                       git).  RESULTS_HOST=local means this machine.
#   RESULTS_REPO=...    that checkout (default Repos/One-footed-bride-tuning
#                       there; this checkout when RESULTS_HOST=local)
#   KEEP_VM=1           do not power the VM off at the end
#   WATCHDOG_MIN=60     with no launcher attached when the job ends, the VM packs
#                       the results on its own disk and powers itself off this
#                       many minutes later.  0 = never on its own.
#   AFTER_CMD='...'     a command run HERE once the results are safely here, e.g.
#                       the provider's CLI to delete the server (see Billing)
#   VM_POWEROFF_CMD='...'  what the VM runs to power itself off, instead of
#                       `shutdown -h +1` (as root or through sudo -n), e.g. a
#                       container pod's own stop command
#   RAY_CPUS=N          give Ray N cores instead of all of them
#   DIRTY=1             ship uncommitted changes to the tracked *.py / *.sh too
#   FORCE=1             start although the VM holds an earlier run's uncollected results
#   MERGE=force         write returned tunings over ones that changed at RESULTS_HOST meanwhile
#
# In order:
#   1. the plan, printed here by ray_ratchet.py --dry_run, as ray-ratchet.sh does.
#   2. the code: `git archive HEAD` of the root *.py and *.sh and Scores/ (about
#      1 MB; not samples/, not .git).  HEAD, pushed or not — the commit is
#      printed.  A requested chorale's score that is not committed is shipped
#      from the working tree, and said so.
#   3. the tunings the ratchet starts from: every cell's <chorale>-opt.npy and
#      -opt.txt for the chorales in the plan, from RESULTS_HOST.  FRESH=0's
#      keep-previous ratchet reads exactly these, and the end-of-run report
#      reads every cell, so every cell is shipped, not only this run's grid.
#   4. the image, the container, Ray; the job, submitted on the VM and detached
#      from this shell.  Ctrl-c or a dropped ssh stops the following, not the run.
#   5. when the job ends, whatever its status: the results are packed on the VM,
#      copied here, checksum-verified, and written back to RESULTS_HOST.  Only
#      then is the VM powered off.
#
# Coming back (5): a tuning is written to RESULTS_HOST only if the file there is
# still the one that was shipped.  One that changed meanwhile (a cluster run on
# the same chorale) is left alone and listed; the VM's copy stays in the state
# directory printed at the end.  The ratchet keeps the better of two tunings,
# and a blind overwrite could put the worse one back.  To take the VM's anyway:
#     tar -C <state>/returned -cf - -T <state>/held.txt | ssh one-footed-bride-pod 'tar -C Repos/One-footed-bride-tuning -xf - --no-same-owner'
# The state directory is ~/.cache/ofb-vm/<job id>/ (OFB_VM_STATE moves it): what
# was shipped, what came back, and the lists of what was written and held.
#
# Billing: "powered off" is `shutdown -h` inside the VM.  On AWS and GCP that
# stops the compute charge (not the disk's); on Hetzner a powered-off server
# still bills until it is DELETED, and container "pods" (RunPod, Vast.ai) cannot
# shut themselves down at all.  For those, set AFTER_CMD to the provider's
# delete or stop command (run here), or VM_POWEROFF_CMD (run on the VM).  And on a VM set to TERMINATE on shutdown (AWS spot,
# by default) the disk goes with it: the unattended power-off (WATCHDOG_MIN)
# would take uncollected results along, so use WATCHDOG_MIN=0 there, or --attach
# before the hour is up.
set -euo pipefail
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$REPO"
VM=${VM:-}; VM_SSH_OPTS=${VM_SSH_OPTS:-}; VM_BASE=${VM_BASE:-ofb-tuning}
IMAGE=${IMAGE:-quay.io/prentrodgers/python-music:0.11}; IMAGE_HOST=${IMAGE_HOST:-}
RESULTS_HOST=${RESULTS_HOST:-one-footed-bride-pod}
if [ "$RESULTS_HOST" = local ]; then RESULTS_REPO=${RESULTS_REPO:-$REPO}; else RESULTS_REPO=${RESULTS_REPO:-Repos/One-footed-bride-tuning}; fi
KEEP_VM=${KEEP_VM:-0}; WATCHDOG_MIN=${WATCHDOG_MIN:-60}; AFTER_CMD=${AFTER_CMD:-}
RAY_CPUS=${RAY_CPUS:-}; DIRTY=${DIRTY:-0}; FORCE=${FORCE:-0}; MERGE=${MERGE:-}; VM_POWEROFF_CMD=${VM_POWEROFF_CMD:-}
STATE=${OFB_VM_STATE:-$HOME/.cache/ofb-vm}
# VM_BASE is relative to the VM user's home, where ssh lands; VM=local lands here.
if [ "$VM" = local ]; then case "$VM_BASE" in /*) ;; *) VM_BASE=$HOME/$VM_BASE;; esac; fi
log(){ echo "$(date +%T) $*"; }
die(){ echo "$*" >&2; exit 2; }

case " $* " in *" -h "*|*" --help "*)
    sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
    echo "---- ray_ratchet.py options (all pass straight through) ----"
    python3 ray_ratchet.py --help | sed -n '/^options:/,$p'
    exit 0;;
esac
# --dry_run needs no VM: the plan is printed by the driver locally.
case " $* " in *" --dry_run "*) exec python3 ray_ratchet.py "$@";; esac

# ── the two other machines ───────────────────────────────────────────────────
# vm "<command>": on the VM.  All of the VM's side is agent.sh's subcommands.
vm(){
    if [ "$VM" = local ]; then bash -c "$1"
    else
        # shellcheck disable=SC2086
        ssh -o BatchMode=yes -o ServerAliveInterval=30 -o StrictHostKeyChecking=accept-new $VM_SSH_OPTS "$VM" "$1"
    fi
}
agent(){ vm "bash $VM_BASE/agent.sh $*"; }
# res "<command>": in the results checkout.
res(){
    if [ "$RESULTS_HOST" = local ]; then (cd "$RESULTS_REPO" && bash -c "$1")
    else ssh -o BatchMode=yes -o LogLevel=ERROR "$RESULTS_HOST" "cd '$RESULTS_REPO' && $1"; fi
}
# The tunings of the chorales in $1 (space-separated), every cell: paths on stdout.
list_cmd(){ echo "{ for c in $1; do ls Archive/straw-man/t*_r*_lm*/\$c-opt.npy Archive/straw-man/t*_r*_lm*/\$c-opt.txt 2>/dev/null; done; true; }"; }
sums(){ [ -d "$1/Archive" ] || return 0; (cd "$1" && find Archive -type f | LC_ALL=C sort | xargs -r sha256sum); }

declare -A F
facts(){
    local k v out
    out=$(agent facts) || die "could not run the agent on $VM (see above)"
    while IFS='=' read -r k v; do [ -n "$k" ] && F[$k]=$v; done <<<"$out"
}

[ -n "$VM" ] || die "which VM?  VM=user@host ./ray-ratchet-vm.sh ...   (./ray-ratchet-vm.sh --help)"
vm true 2>/dev/null || die "cannot reach $VM over ssh (ssh $VM_SSH_OPTS $VM true)"
# The agent first: everything below asks it.
vm "mkdir -p $VM_BASE/run && cat > $VM_BASE/agent.sh" < "$REPO/ray-ratchet-vm-agent.sh"
facts
[ -z "$VM_POWEROFF_CMD" ] || F[can_poweroff]=yes
# Never power off the machine this is typed on (VM=local, or ssh to itself).
SAME=0
if [ "$VM" = local ] || [ "${F[machine_id]}" = "$(cat /etc/machine-id 2>/dev/null)" ]; then SAME=1; fi

# ── the end of a run: collect, write back, power off ─────────────────────────
# The order is the point: nothing stops or powers off until the results are on
# this machine with the VM's checksum.
finish(){
    local id=$1 status=$2 dir="$STATE/$1" sha got take n
    mkdir -p "$dir"
    log "job $id: $status"
    # `watch` on the VM packs when the job ends; give it a moment, else pack now.
    for _ in $(seq 1 12); do [ "$(vm "test -f $VM_BASE/run/done && echo y || echo n")" = y ] && break; sleep 5; done
    [ "$(vm "test -f $VM_BASE/results-$id.tar.gz.sha256 && echo y || echo n")" = y ] || agent pack | sed 's/^/    /'
    agent results "$id" > "$dir/returned.tar.gz"
    sha=$(vm "cat $VM_BASE/results-$id.tar.gz.sha256"); got=$(sha256sum "$dir/returned.tar.gz" | awk '{print $1}')
    if [ "$sha" != "$got" ]; then
        echo "the results copy does not match the VM's checksum ($got here, $sha there)." >&2
        echo "NOTHING was stopped or powered off: the results are on the VM in $VM_BASE/results-$id.tar.gz; run --attach again." >&2
        exit 1
    fi
    rm -rf "$dir/returned"; mkdir -p "$dir/returned"
    tar -C "$dir/returned" -xzf "$dir/returned.tar.gz"
    vm "touch $VM_BASE/run/collected"
    log "results here, checksum verified: $dir/returned.tar.gz ($(du -h "$dir/returned.tar.gz" | cut -f1))"
    [ -s "$dir/returned/$id.log" ] && [ ! -s "$REPO/$id.log" ] && cp "$dir/returned/$id.log" "$REPO/$id.log"

    # Write back.  A failure here loses nothing (the copy above stays), so the
    # VM is powered off either way.
    if writeback "$id"; then :; else
        echo "the results were NOT written to $RESULTS_HOST:$RESULTS_REPO (see above); they are in $dir/returned/" >&2
        echo "to write them:  tar -C $dir/returned -cf - Archive | ssh $RESULTS_HOST 'tar -C $RESULTS_REPO -xf - --no-same-owner'" >&2
    fi

    agent down
    if [ "$KEEP_VM" = 1 ]; then log "KEEP_VM=1 — the VM ($VM) is still up, and billing"
    elif [ "$SAME" = 1 ]; then log "the VM is this machine: not powering it off"
    elif [ "${F[can_poweroff]}" != yes ]; then log "CANNOT power the VM off (no root, no passwordless sudo on $VM): stop it yourself"
    else agent poweroff --yes >/dev/null 2>&1 || true; log "the VM is powering off (in a minute).  See Billing in --help: off is not always unbilled."
    fi
    if [ -n "$AFTER_CMD" ]; then log "AFTER_CMD: $AFTER_CMD"; bash -c "$AFTER_CMD" || log "AFTER_CMD failed ($?)"; fi
    case "$status" in SUCCEEDED) return 0;; *) return 1;; esac
}

# The returned files that are new or changed, written to RESULTS_HOST unless the
# file there has changed since it was shipped.
writeback(){
    local id=$1 dir="$STATE/$1" chorales
    chorales=$(cat "$dir/chorales" 2>/dev/null || true)
    sums "$dir/returned" > "$dir/returned.sha256"
    if [ ! -f "$dir/shipped.sha256" ] || [ -z "$chorales" ]; then
        [ "$MERGE" = force ] || { echo "no record here of what was shipped for $id (another machine launched it?): cannot tell what changed at $RESULTS_HOST since. MERGE=force writes everything back." >&2; return 1; }
        : > "$dir/shipped.sha256"
    fi
    res "$(list_cmd "$chorales") | xargs -r sha256sum" > "$dir/dest.sha256" || { echo "could not reach $RESULTS_HOST" >&2; return 1; }
    MERGE=$MERGE python3 - "$dir" <<'EOF' || return 1
import os, re, sys
d = sys.argv[1]
def load(name):
    out = {}
    for line in open(os.path.join(d, name)):
        h, p = line.rstrip('\n').split(None, 1)
        out[p.lstrip('*')] = h
    return out
shipped, returned, dest = load('shipped.sha256'), load('returned.sha256'), load('dest.sha256')
force = os.environ.get('MERGE') == 'force'
tuning = re.compile(r'-opt\.(npy|txt)$')
stem = lambda p: tuning.sub('', p)
changed = {p for p in returned if not (tuning.search(p) and shipped.get(p) == returned[p])}
# A tuning is its .npy and its .txt together: one conflict holds back both.
conflict = {stem(p) for p in changed if tuning.search(p) and dest.get(p) != shipped.get(p) and dest.get(p) != returned[p]}
if force:
    conflict = set()
take = sorted(p for p in changed if not (tuning.search(p) and stem(p) in conflict))
with open(os.path.join(d, 'take.txt'), 'w') as f:
    f.write(''.join(p + '\n' for p in take))
tunings = {stem(p) for p in take if tuning.search(p)}
new = {s for s in tunings if s + '-opt.npy' not in shipped}
same = {stem(p) for p in returned if tuning.search(p)} - tunings - conflict
print(f'    tunings: {len(tunings) - len(new)} updated, {len(new)} new, {len(same)} unchanged, '
      f'{len(conflict)} held back; {len(take) - sum(1 for p in take if tuning.search(p))} logs')
for s in sorted(conflict):
    print(f'    HELD BACK (changed at the destination since it was shipped): {s}')
with open(os.path.join(d, 'held.txt'), 'w') as f:
    f.write(''.join(f'{s}-opt.npy\n{s}-opt.txt\n' for s in sorted(conflict)))
EOF
    [ -s "$dir/held.txt" ] && echo "    the VM's copies of those are in $dir/returned/ — compare, and to take the VM's:  tar -C $dir/returned -cf - -T $dir/held.txt | (the tar -x in --help's 'Coming back')"
    if [ -s "$dir/take.txt" ]; then
        # g+w: as the cluster's workers leave them on the PVC
        tar -C "$dir/returned" --mode=g+w -czf - -T "$dir/take.txt" | res "umask 002; tar -xzf - --no-same-owner" || return 1
        # read them back: what is there must be what the VM made
        res "$(list_cmd "$chorales") | xargs -r sha256sum" > "$dir/dest-after.sha256" || return 1
        python3 - "$dir" <<'EOF' || { echo "the tunings at $RESULTS_HOST do not read back as written" >&2; return 1; }
import os, re, sys
d = sys.argv[1]
load = lambda n: {l.split(None, 1)[1].strip().lstrip('*'): l.split()[0] for l in open(os.path.join(d, n)) if l.strip()}
returned, after = load('returned.sha256'), load('dest-after.sha256')
bad = [p for p in open(os.path.join(d, 'take.txt')).read().split('\n')
       if re.search(r'-opt\.(npy|txt)$', p) and after.get(p) != returned[p]]
sys.exit(1 if bad else 0)
EOF
    fi
    log "written to $RESULTS_HOST:$RESULTS_REPO/Archive/straw-man/ and read back"
}

follow(){   # follow <id>: the log until the job ends or the following stops; then the status
    local id=$1 status
    log "following the log (ctrl-c stops following, not the run; --attach resumes)"
    log "driver log copy: $id.log"
    trap 'echo; log "stopped following"' INT
    set +e
    agent logs "$id" 2>&1 | tee "$id.log"      # replays from the start: the copy is whole each time
    set -e
    trap - INT
    status=$(agent status "$id" 2>/dev/null || echo UNREACHABLE)
    case "$status" in
        RUNNING|PENDING|UNKNOWN|UNREACHABLE)
            log "job $id: $status — the VM is left as it is.  VM=$VM ./ray-ratchet-vm.sh --attach"
            exit 0;;
    esac
    finish "$id" "$status"
}

# ── --attach, --stop ─────────────────────────────────────────────────────────
if [ "${1:-}" = "--attach" ] || [ "${1:-}" = "--stop" ]; then
    id=${F[id]}
    [ -n "$id" ] || die "no job has been submitted on $VM"
    [ "${F[collected]}" = yes ] && [ "${1:-}" = "--attach" ] && die "job $id (${F[job]}) is already collected: $STATE/$id/"
    if [ "$1" = "--stop" ]; then
        case "${F[job]}" in RUNNING|PENDING) log "stopping job $id"; agent stopjob "$id" | sed 's/^/    /';; esac
        s=$(agent status "$id"); case "$s" in RUNNING|PENDING) s=STOPPED;; esac
        finish "$id" "$s" || true
        exit 0
    fi
    case "${F[job]}" in
        RUNNING|PENDING|UNKNOWN) follow "$id";;
        *) finish "$id" "${F[job]}";;
    esac
    exit $?
fi

# ── 1. the plan ──────────────────────────────────────────────────────────────
echo "== plan"
plan=$(python3 ray_ratchet.py "$@" --dry_run) \
    || die "ray_ratchet.py rejected the arguments or found no score for a name (see above) — nothing started (./ray-ratchet-vm.sh --help)"
echo "$plan" | sed '/^dry run/d; s/^/    /'
chorales=$(echo "$plan" | sed -n 's/^  chorales: //p')
[ -n "$chorales" ] || die "could not read the chorales out of the plan"
task_cpus=4; prev=""
for a in "$@"; do [ "$prev" = --task_cpus ] && task_cpus=$a; prev=$a; done
echo

case "${F[job]}" in RUNNING|PENDING) die "job ${F[id]} is ${F[job]} on $VM:  --attach follows it, --stop ends it";; esac
if [ -n "${F[id]}" ] && [ "${F[collected]}" != yes ] && [ "$FORCE" != 1 ]; then
    die "$VM holds the results of ${F[id]} (${F[job]}), not collected yet:  --attach collects them (FORCE=1 starts over them)"
fi
[ "${F[runtime]}" != none ] || die "$VM has neither docker nor podman this user can run"
cpus=${RAY_CPUS:-${F[cores]}}; slots=$((cpus / task_cpus))
[ "$slots" -ge 1 ] || die "$VM has $cpus cores: fewer than one task's $task_cpus"
log "VM ${F[host]}: ${F[cores]} cores, ${F[mem_gib]} GiB (${F[avail_gib]} free), ${F[runtime]} — $slots task slots of $task_cpus CPU (the home cluster runs 29)"
need=$(awk -v s="$slots" 'BEGIN {printf "%.0f", s * 2.5 + 4}')
[ "${F[avail_gib]}" -ge "$need" ] || log "NOTE: $slots tasks declare $need GiB with Ray's own; ${F[avail_gib]} are free.  Ray will run fewer at once."
[ "$SAME" = 1 ] && log "the VM is this machine: it will not be powered off"
[ "$SAME" = 1 ] || [ "$KEEP_VM" = 1 ] || [ "${F[can_poweroff]}" = yes ] \
    || log "NOTE: no root or passwordless sudo on $VM — it CANNOT be powered off from here; stop it yourself when the run ends"

id="vm-ratchet-$(date +%Y%m%d-%H%M%S)"
dir="$STATE/$id"; mkdir -p "$dir/shipped"
# Until the job is submitted nothing on the VM will ever power it off.
trap 'rc=$?; [ $rc = 0 ] || echo "NOTE: the launch stopped (exit $rc) with NOTHING running on $VM — it is still up and billing; fix the cause and launch again, or stop it." >&2' EXIT
echo "$chorales" > "$dir/chorales"

# ── 2. the code ──────────────────────────────────────────────────────────────
commit=$(git rev-parse --short HEAD)
paths=(':(glob)*.py' ':(glob)*.sh'); [ -n "$(git ls-files Scores | head -1)" ] && paths+=(Scores)
git archive --format=tar HEAD -- "${paths[@]}" > "$dir/code.tar"
mkdir -p "$dir/overlay"
for c in $chorales; do                      # a score in the plan that is not in HEAD as it stands
    for f in Scores/"$c".*; do
        [ -f "$f" ] || continue
        if ! git diff --quiet HEAD -- "$f" 2>/dev/null || ! git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
            mkdir -p "$dir/overlay/Scores"; cp "$f" "$dir/overlay/Scores/"
            log "NOTE: $f is not committed as it stands: shipped from the working tree"
        fi
    done
done
prev=""
for a in "$@"; do
    if [ "$prev" = --cells_file ]; then
        case "$a" in /*|../*) die "--cells_file $a: give it as a path inside this checkout (it is shipped to the same place on the VM)";; esac
        [ -f "$a" ] || die "--cells_file $a: no such file"
        mkdir -p "$dir/overlay/$(dirname "$a")"; cp "$a" "$dir/overlay/$a"; log "cells file $a shipped"
    fi
    prev=$a
done
dirty=$(git status --porcelain -- ':(glob)*.py' ':(glob)*.sh' | awk '$1 ~ /M/ {print $2}' | tr '\n' ' ')
if [ -n "$dirty" ]; then
    if [ "$DIRTY" = 1 ]; then
        # shellcheck disable=SC2086
        cp $dirty "$dir/overlay/"; log "DIRTY=1: shipping the working tree's $dirty"
    else log "NOTE: uncommitted changes to $dirty are NOT shipped (DIRTY=1 ships them)"; fi
fi
tar -C "$dir/overlay" -rf "$dir/code.tar" . 2>/dev/null || true
gzip -f "$dir/code.tar"
log "code: commit $commit, root *.py *.sh and Scores/ ($(du -h "$dir/code.tar.gz" | cut -f1))"

# ── 3. the tunings to start from ─────────────────────────────────────────────
res "$(list_cmd "$chorales") | tar -czf - -T -" > "$dir/shipped.tar.gz" \
    || die "could not read the tunings from $RESULTS_HOST:$RESULTS_REPO"
tar -C "$dir/shipped" -xzf "$dir/shipped.tar.gz"
sums "$dir/shipped" > "$dir/shipped.sha256"
n=$(grep -c -- '-opt\.npy$' "$dir/shipped.sha256" || true)
log "tunings: $n from $RESULTS_HOST:$RESULTS_REPO for $(echo "$chorales" | wc -w) chorales ($(du -h "$dir/shipped.tar.gz" | cut -f1))"
[ "$n" -gt 0 ] || log "NOTE: none on record for these chorales: every cell starts from scratch"

# Onto the VM: a clean checkout, then the code, then the tunings.
vm "rm -rf $VM_BASE/home/Repos/One-footed-bride-tuning $VM_BASE/run/done $VM_BASE/run/collected $VM_BASE/run/keep $VM_BASE/run/id && mkdir -p $VM_BASE/home/Repos/One-footed-bride-tuning/Archive/straw-man"
vm "tar -C $VM_BASE/home/Repos/One-footed-bride-tuning -xzf -" < "$dir/code.tar.gz"
vm "tar -C $VM_BASE/home/Repos/One-footed-bride-tuning -xzf -" < "$dir/shipped.tar.gz"
vm "cat > $VM_BASE/run/env" <<EOF
IMAGE=$IMAGE
RAY_CPUS=$RAY_CPUS
VITERBI_WORKERS=$task_cpus
TZ_NAME=$(timedatectl show -p Timezone --value 2>/dev/null || echo America/Los_Angeles)
POWEROFF_CMD=$(printf '%q' "$VM_POWEROFF_CMD")
EOF
[ "$KEEP_VM" = 1 ] && vm "touch $VM_BASE/run/keep"
facts          # again, now that run/env names this run's image

# ── 4. the image, Ray, the job ───────────────────────────────────────────────
if [ "${F[image]}" = present ]; then log "image: $IMAGE is on the VM"
elif [ -n "$IMAGE_HOST" ]; then
    log "image: streaming $IMAGE from $IMAGE_HOST to the VM (about 4 GB before compression)"
    ssh -o BatchMode=yes "$IMAGE_HOST" "podman save $IMAGE | zstd -T0 -3 -c" | vm "zstd -d -c | bash $VM_BASE/agent.sh load" | tail -1 | sed 's/^/    /' \
        || die "the image did not arrive (zstd is needed on both $IMAGE_HOST and the VM)"
else
    log "image: pulling $IMAGE on the VM"
    agent pull 2>&1 | tail -2 | sed 's/^/    /' \
        || die "the VM could not pull $IMAGE — the repository is private.  Either  ssh $VM docker login quay.io  (or podman login), or IMAGE_HOST=fs2 to stream it from there."
fi
log "starting Ray on the VM"
agent up
log "submitting $id: python ray_ratchet.py $*"
agent submit "$id" "$(printf '%q ' "$@")"
# The watchdog: packs the results when the job ends whether or not this shell is
# still here, and powers the VM off if nobody comes for them.
wd_poweroff=1; { [ "$KEEP_VM" = 1 ] || [ "$SAME" = 1 ] || [ "${F[can_poweroff]}" != yes ]; } && wd_poweroff=0
vm "nohup setsid bash $VM_BASE/agent.sh watch $WATCHDOG_MIN $wd_poweroff > $VM_BASE/run/watch.log 2>&1 < /dev/null &"
if [ "$wd_poweroff" = 1 ] && [ "$WATCHDOG_MIN" -gt 0 ]; then
    log "if this shell goes away: the VM packs its results when the job ends and powers itself off $WATCHDOG_MIN minutes later"
else
    log "if this shell goes away: the VM packs its results when the job ends and STAYS UP (and billing) until --attach or --stop"
fi
trap - EXIT
echo
follow "$id"
