#!/usr/bin/env bash
# render_farm.sh — one stage render, split across every Battlemage GPU in the
# cluster: two B70s on fs5, a B580 each on fs6 and fs9, a B50 on fs3.
#
# It works because blender_stage.py's animation is procedural, not keyframed:
# frame N is at t = N/FPS whoever renders it, so the slices need no merge step.
# Every pod mounts dropbox-pvc, so all five write frame_%06d.png into the SAME
# directory on CephFS and the repo they run is the one copy on the PVC.
#
# The rates below are full-run averages from the 8451-frame bwv256 render of
# 9/3/26, not spot probes: each node carries a resident OpenVINO model server
# (granite on fs6/fs9, qwen3-14b on fs3) and the two B70s share fs5 with
# ComfyUI, so a GPU's useful rate here is what it does alongside its
# neighbours. fs3 probes at 1.81 on its own and delivers 2.13 in company,
# which is why its slice is the smallest.
#
# They still land within 30% of each other across three very different cards,
# which says this render is paced by the per-frame Python (mallet slots, tine
# bends, sway, mesh edits) rather than by the GPU. Adding NODES helps; buying
# a better card would not.
#
#   ./render_farm.sh --npy Uploads/x.npy --tempo 104 --duration 281.7 --out frames
#   ./render_farm.sh ... --engine cycles          # anything else --x goes to blender_stage.py
#   ./render_farm.sh ... --dry-run                # the slices, no pods
#   ./render_farm.sh --status                     # the pods
#   ./render_farm.sh --progress                   # per-slice frames done, rate, eta
#   ./render_farm.sh --stop                       # delete the pods, fleet back to balanced
#   ./render_farm.sh --only b70a ...              # relaunch one slice (same args as the launch)
#   ./render_farm.sh --help
#
# Environment:
#   PER_CARD=2      two Blender processes per card instead of one (see below)
#   IGPU=1          add the Core Ultra iGPUs (IGPU_RATE_EEVEE / IGPU_RATE_CYC)
#   POWER=0         leave the tuned profiles alone
#   STAGGER=45      seconds between pod launches
#   IMAGE=...       another image tag
#
# The fleet rests on tuned's balanced profile; a launch switches it to
# powersave-gpu (./power-save-all.sh) and a detached waiter switches it back
# once every pod has finished (--stop does too). POWER=0 skips both.
#
# PER_CARD. A Blender process renders a frame in two strictly serial phases:
# the per-frame Python (mallet slots, tine bends, sway, mesh edits — one CPU
# thread) and then the GPU render. The card idles through the first, the CPU
# through the second; on Grafana it shows as CPU and GPU taking turns.
# PER_CARD=2 launches two pods on each card, each with half the card's slice,
# so one's Python phase overlaps the other's render and the card stays busy.
# Cycles takes concurrent contexts on one card without complaint. The cost
# is memory — a Blender process is 1-2 GB plus its VRAM — so fs5, which
# holds two B70s beside ComfyUI, is the node to watch. Not yet measured
# (added 20 Sep 2026): the rate table is per single process, so a card's
# slice is the same size either way and the two pods split it; expect them
# to finish early, then re-measure the rates with two per card and update the
# table. Pods are named <label>-1, <label>-2; --only takes either one of
# those or the bare label for both, and needs the same PER_CARD as the launch
# so the frame ranges come out identical.
#
# Pods are started one at a time, STAGGER seconds apart. "Mounting" the
# CephFS volume takes ~60-90s per pod, and five at once put every one of them
# past the kubelet's CreateContainer deadline: all five died with "context
# deadline exceeded" while a single pod was fine.
#
# What that time actually is (found 6 Sep 2026, when eight pods plus an MDS
# failover left four of them stuck for good): CRI-O relabels every file
# under a mounted volume for SELinux (lsetxattr, one MDS round trip each)
# before the container starts, and the PVC root holds the whole Dropbox —
# 763k objects. So the pod mounts only the two subtrees it needs, the repo
# and the SYCL kernel cache, and the walk covers ~25k files instead.
#
# Needs: kubectl context on this cluster, and the repo present on the PVC.
# Anything else on the command line that starts with -- is passed straight
# through to blender_stage.py, so a Cycles render is just
#   ./render_farm.sh ... --engine cycles
# IMAGE can be overridden from the environment to try another tag. 0.10 is
# the first image with the Level Zero stack Cycles needs; on 0.9 (Vulkan
# EEVEE only) blender_stage.py says so and stops.
set -euo pipefail

NS=default
IMAGE=${IMAGE:-quay.io/prentrodgers/python-music:0.11}
PULL_SECRET=regcred
REPO=/home/prent/Repos/One-footed-bride-tuning
FPS=30
RES_X=1280
RES_Y=720

# label   node  device-select  card-ordinal  s/frame-eevee  s/frame-cycles
#
# The Cycles column is used when --engine cycles is passed through. Its
# spread is not EEVEE's: EEVEE is paced by the per-frame Python and the
# cards land within 30%, while Cycles is paced by the card and the B580s
# fall 40% behind the B70s. Full-run averages from the 8451-frame bwv256
# --look studio render of 4 Sep 2026 (1280x720, 64 samples + OpenImageDenoise),
# replacing the ~30-frame probes of 3 Sep, which carried each pod's JIT.
#
# The two B70s share a PCI id, so MESA_VK_DEVICE_SELECT cannot tell them
# apart, and Cycles would happily take both. Each pod therefore keeps ONE
# render node and bind-mounts /dev/null over every other one, inside its own
# container. The node to keep is found by PCI device id at pod start, not
# named here: an earlier version named renderD129/renderD130, but on fs5
# those are the iGPU and one B70 (the B70s are D128 and D130), so the pod
# that "hid" D129 was hiding the iGPU and could see both cards. The
# card-ordinal column says which matching card a pod takes, in sysfs order.
# Cycles column re-measured on the 11,325-frame bwv260 render of 6 Sep 2026,
# the first under the powersave-gpu tuned profile (CPU turbo off, powersave
# governor): the B70s and the B50 lost 40-65% against the 4 Sep numbers
# (2.38/2.50/3.33/3.70/3.47) because the per-frame Python paces them and
# their nodes' CPUs are now slower, while the B580s barely moved. The fleet
# stays on powersave, so these are the rates to size slices by.
# 12 Sep 2026: the B50 moved from fs3 to fs4 and fs3 got a third B580.
# Their Cycles rates are from the bwv432 render that evening (6188
# frames, powersave-gpu): the B580 on fs3 runs 15-20% behind the ones on
# fs6/fs9 (fs3 carries the Ceph MDS and an OSD, and its PCIe link is
# pinned to Gen4), and the B50 on fs4 is slower than it was on fs3
# because it now shares fs4's CPU with the iGPU worker. The iGPUs did
# 39-40 s/frame on that run: pass IGPU_RATE_CYC=40.
WORKERS=(
  "b70a   fs5  8086:e223  0           1.701  3.995"
  "b70b   fs5  8086:e223  1           1.751  3.992"
  "b580f6 fs6  8086:e20b  -           1.651  3.821"
  "b580f9 fs9  8086:e20b  -           1.829  3.688"
  "b580f3 fs3  8086:e20b  -           1.740  4.323"
  "b50f4  fs4  8086:e212  -           2.129  4.793"
)
# The Core Ultra iGPUs (Xe-LPG, PCI 0x7d67), opt-in with IGPU=1. fs4 now
# also carries the B50, so it fields two workers; each pod keeps only the
# render node matching its own PCI id, so they do not collide. Rates probed on fs4 on 5 Sep 2026 (steady state,
# after the first frame's ~140 s Cycles kernel compile): a fifth of a B70
# on Cycles, ~40% of one on EEVEE. Three of them add ~16% to the farm's
# Cycles throughput and ~35% to EEVEE's. fs2 is left out: it is the
# workstation, with 15Gi.
#
# Those rates are with the iGPU free to boost to 1.9-2.0 GHz. Under the
# powersave-gpu tuned profile (power-save-all.sh) it is pinned to 550 MHz,
# so pass the slower per-frame rates in through the environment or the
# slices sized for the fast clock finish hours after the cards:
#   IGPU=1 IGPU_RATE_CYC=40 ./render_farm.sh ...
IGPU_RATE_EEVEE=${IGPU_RATE_EEVEE:-3.89}
IGPU_RATE_CYC=${IGPU_RATE_CYC:-11.3}
if [ "${IGPU:-0}" = 1 ]; then WORKERS+=(
  "igpuf4 fs4  8086:7d67  0           $IGPU_RATE_EEVEE   $IGPU_RATE_CYC"
  "igpuf7 fs7  8086:7d67  0           $IGPU_RATE_EEVEE   $IGPU_RATE_CYC"
  "igpuf8 fs8  8086:7d67  0           $IGPU_RATE_EEVEE   $IGPU_RATE_CYC"
); fi

STAGGER=${STAGGER:-45}
PER_CARD=${PER_CARD:-1}
case "$PER_CARD" in 1|2|3|4) ;; *) echo "PER_CARD must be 1-4, got '$PER_CARD'" >&2; exit 2;; esac
NPY=""; TEMPO=""; DURATION=""; OUT=""; DRYRUN=0; ONLY=""; EXTRA=()
while [ $# -gt 0 ]; do
  case "$1" in
    # The header, comment markers stripped: usage, the environment knobs, and
    # the notes on how the slicing and the cards work.
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0;;
    --npy) NPY=$2; shift 2;;
    --tempo) TEMPO=$2; shift 2;;
    --duration) DURATION=$2; shift 2;;
    --out) OUT=$2; shift 2;;
    --dry-run) DRYRUN=1; shift;;
    # Re-launch a single slice by label, keeping its frame range identical —
    # for when one pod loses the race to mount the volume and the other four
    # are already rendering.
    --only) ONLY=$2; shift 2;;
    --status) exec kubectl -n "$NS" get po -l job=blender-farm -o wide;;
    # Per-slice progress. Everything comes from the pods themselves — each
    # one's frame range out of its own args, its latest frame out of its log —
    # so this needs none of the render's parameters restated.
    #
    # Note for doing it by hand: "kubectl logs -l <selector>" quietly defaults
    # to --tail=10 PER POD, which is why a bare `logs -l job=blender-farm`
    # returns 50 lines and looks like nothing is happening. --tail=-1 gets the
    # lot; --tail=1 --prefix gets each worker's last line, which is the useful
    # one.
    --progress)
      kubectl -n "$NS" get po -l job=blender-farm -o \
        jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.spec.nodeName}{"\t"}{.spec.containers[0].args[0]}{"\n"}{end}' \
        | while IFS=$'\t' read -r pod phase node args; do
            first=$(sed -n 's/.*--frame-start \([0-9]*\).*/\1/p' <<<"$args")
            last=$(sed -n 's/.*--frame-end \([0-9]*\).*/\1/p' <<<"$args")
            line=$(kubectl -n "$NS" logs "$pod" --tail=1 2>/dev/null)
            cur=$(sed -n "s/.*frame_0*\([0-9][0-9]*\)\.png.*/\1/p" <<<"$line")
            clock=$(awk '{print $1}' <<<"$line")
            awk -v pod="${pod#blender-farm-}" -v node="$node" -v phase="$phase" \
                -v a="$first" -v b="$last" -v c="${cur:-}" -v clk="$clock" 'BEGIN{
              span = b - a + 1
              if (c == "") { printf "  %-7s %-4s %-10s   %6d frames, not started\n", pod, node, phase, span; exit }
              done = c - a + 1
              n = split(clk, t, ":")
              secs = (n == 3) ? t[1]*3600 + t[2]*60 + t[3] : t[1]*60 + t[2]
              rate = (secs > 0) ? done / secs : 0
              eta = (rate > 0) ? (span - done) / rate / 60 : 0
              bars = int(20 * done / span)
              bar = ""
              for (i = 0; i < 20; i++) bar = bar (i < bars ? "#" : ".")
              printf "  %-7s %-4s %s %5.1f%%  %5d/%-5d  %.2fs/frame  eta %2.0fm\n", \
                     pod, node, bar, 100*done/span, done, span, (rate>0?1/rate:0), eta
            }'
          done
      exit 0;;
    # Stopping ends the load, so the fleet goes back to balanced here too
    # (the waiter spawned at launch would do it, but not if POWER=0).
    --stop) kubectl -n "$NS" delete po -l job=blender-farm --wait=false
            [ "${POWER:-1}" = 1 ] && ./power-balanced.sh; exit 0;;
    # Spawned detached by a launch: waits for every farm pod to finish, prints
    # each slice's timing, and returns the fleet to balanced.
    --wait-then-balanced)
      while kubectl -n "$NS" get po -l job=blender-farm --no-headers 2>/dev/null \
              | awk '{print $3}' | grep -qE "Running|Pending|ContainerCreating|Init"; do
        sleep 60
      done
      echo "$(date +%T) farm finished:"
      for pod in $(kubectl -n "$NS" get po -l job=blender-farm --no-headers 2>/dev/null | awk '{print $1}'); do
        printf "  %-22s %s  %s\n" "${pod#blender-farm-}" \
               "$(kubectl -n "$NS" get po "$pod" --no-headers | awk '{print $3}')" \
               "$(kubectl -n "$NS" logs "$pod" 2>/dev/null | grep -a '\[stage\] done' | sed 's/.*done: //' | cut -c1-50)"
      done
      ./power-balanced.sh
      exit 0;;
    # Pass-through for blender_stage.py: the flag, plus its value if the next
    # token is not itself a flag (--engine cycles, --samples 96, --cycles-hw-rt).
    --*) EXTRA+=("$1"); shift
         if [ $# -gt 0 ] && [[ "$1" != --* ]]; then EXTRA+=("$1"); shift; fi;;
    *) echo "unknown argument: $1" >&2; exit 2;;
  esac
done
[ -n "$NPY$TEMPO$DURATION$OUT" ] || { sed -n '2,/^#   IMAGE=/p' "$0" | sed 's/^# \{0,1\}//'; echo "(--help for the rest)"; exit 2; }
# Which rate column to split by: 6 (Cycles) when the pass-through asks for
# it, else 5 (EEVEE).
RATE_COL=5; case " ${EXTRA[*]:-} " in *" cycles "*) RATE_COL=6;; esac

# Frame count exactly as blender_stage.py computes it: ceil(duration * FPS).
TOTAL=$(awk -v d="$DURATION" -v f="$FPS" 'BEGIN{t=d*f; c=int(t); if (t-c>1e-9) c++; print c}')

# Slices in proportion to each worker's measured rate, contiguous, with the
# last one taking the remainder so no frame is missed or rendered twice.
weights=(); total_w=0
for w in "${WORKERS[@]}"; do
  read -r _ _ _ _ rate_eevee rate_cycles <<<"$w"
  rate=$rate_eevee; [ "$RATE_COL" -eq 6 ] && rate=$rate_cycles
  weight=$(awk -v r="$rate" 'BEGIN{print 1/r}')
  weights+=("$weight")
  total_w=$(awk -v a="$total_w" -v b="$weight" 'BEGIN{print a+b}')
done

echo "render: $TOTAL frames over ${#WORKERS[@]} GPUs$([ "$PER_CARD" -gt 1 ] && echo ", $PER_CARD processes per card")  "\
"($(awk -v w="$total_w" 'BEGIN{printf "%.2f", w}') frames/s at one per card, "\
"eta $(awk -v t="$TOTAL" -v w="$total_w" 'BEGIN{printf "%.0f", t/w/60}') min)"

start=0
# Power: the fleet rests on tuned's balanced profile and renders under
# powersave-gpu (power-save-all.sh) — the office circuit cannot take the
# farm at full clocks. Switched here at launch and back by the detached
# waiter once every pod is done. POWER=0 leaves the profiles alone.
if [ "$DRYRUN" -eq 0 ] && [ "${POWER:-1}" = 1 ] && [ -z "$ONLY" ]; then
  echo "== fleet to powersave-gpu for the render"
  ./power-save-all.sh | tail -n +2 | grep -vE "^$|^== verify"
  echo
fi

launched=0
for i in "${!WORKERS[@]}"; do
  read -r label node select ordinal _ _ <<<"${WORKERS[$i]}"
  # This card's slice, from its rate.
  if [ "$i" -eq $((${#WORKERS[@]} - 1)) ]; then
    card_end=$((TOTAL - 1))
  else
    share=$(awk -v w="${weights[$i]}" -v tw="$total_w" -v t="$TOTAL" 'BEGIN{printf "%d", (w/tw)*t}')
    card_end=$((start + share - 1))
  fi
  card_start=$start
  start=$((card_end + 1))
  card_span=$((card_end - card_start + 1))

  # Keep the Nth render node whose PCI device id matches this worker's
  # card; hide all the others (dGPU siblings and iGPUs alike). Runs inside
  # the pod, where sysfs is the host's and /dev/dri is the passed-through
  # directory, so the choice is made against what is actually there.  The
  # same ordinal for every part of a card: that is what puts them on one GPU.
  [ "$ordinal" = "-" ] && ordinal=0
  hide_cmd="dev=0x${select#*:}; keep=''; n=0; for s in /sys/class/drm/renderD*; do [ \"\$(cat \$s/device/device)\" = \"\$dev\" ] || continue; [ \$n -eq $ordinal ] && keep=\$(basename \$s); n=\$((n+1)); done; [ -n \"\$keep\" ] || { echo \"[farm] no card \$dev ordinal $ordinal on this node\" >&2; exit 3; }; for d in /dev/dri/renderD*; do [ \"\$(basename \$d)\" = \"\$keep\" ] || mount --bind /dev/null \$d; done; echo \"[farm] rendering on \$keep\"; "

  # PER_CARD contiguous parts of the card's slice, the last taking the
  # remainder.  With PER_CARD=1 the part is the whole slice and the pod
  # keeps its old name, so --progress and --only work as before.
  for ((p = 1; p <= PER_CARD; p++)); do
    part_start=$((card_start + (p - 1) * card_span / PER_CARD))
    if [ "$p" -eq "$PER_CARD" ]; then part_end=$card_end
    else part_end=$((card_start + p * card_span / PER_CARD - 1)); fi
    name=$label; [ "$PER_CARD" -gt 1 ] && name="$label-$p"
    if [ -n "$ONLY" ] && [ "$ONLY" != "$label" ] && [ "$ONLY" != "$name" ]; then
      continue
    fi
    printf "  %-9s %-4s %-11s frames %6d..%-6d (%d)%s\n" "$name" "$node" "$select" "$part_start" "$part_end" \
           $((part_end - part_start + 1)) "${EXTRA[*]:+  ${EXTRA[*]}}"
    [ "$DRYRUN" -eq 0 ] || continue

    # Let the previous pod's volume finish mounting before asking for this one.
    [ "$launched" -gt 0 ] && sleep "$STAGGER"
    launched=$((launched + 1))
    kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: blender-farm-$name
  namespace: $NS
  labels: {job: blender-farm, card: $label}
spec:
  restartPolicy: Never
  nodeSelector: {kubernetes.io/hostname: $node}
  imagePullSecrets: [{name: $PULL_SECRET}]
  securityContext: {supplementalGroups: [991]}
  containers:
  - name: blender
    image: $IMAGE
    securityContext: {privileged: true, runAsUser: 0}
    env:
    - {name: MESA_VK_DEVICE_SELECT, value: "$select"}
    - {name: SYCL_CACHE_DIR, value: /home/prent/.cache/sycl}
    command: ["bash","-c"]
    args:
    - ${hide_cmd}cd $REPO && exec blender --background --gpu-backend vulkan
      --python blender_stage.py -- --npy $NPY --tempo $TEMPO --duration $DURATION
      --res-x $RES_X --res-y $RES_Y --out $OUT --frame-start $part_start --frame-end $part_end
      --gpu-name any ${EXTRA[*]:-}
    volumeMounts:
    # subPaths, not the PVC root: see the relabel note at the top.
    - {name: ceph, mountPath: $REPO, subPath: ${REPO#/home/prent/}}
    - {name: ceph, mountPath: /home/prent/.cache/sycl, subPath: .cache/sycl}
    - {name: dri, mountPath: /dev/dri}
  volumes:
  - {name: ceph, persistentVolumeClaim: {claimName: dropbox-pvc}}
  - {name: dri, hostPath: {path: /dev/dri}}
YAML
  done
done

[ "$DRYRUN" -eq 1 ] && exit 0
if [ "${POWER:-1}" = 1 ] && [ -z "$ONLY" ]; then
  WAITLOG=${TMPDIR:-/tmp}/render_farm_wait_${OUT##*/}.log
  setsid nohup "$0" --wait-then-balanced > "$WAITLOG" 2>&1 < /dev/null &
  echo
  echo "power:  back to balanced when the farm finishes (log: $WAITLOG)"
fi
echo
echo "watch:  ./render_farm.sh --status"
echo "count:  kubectl -n $NS exec deploy/one-footed-bride -c pod-ssh -- ls $REPO/$OUT | wc -l"
echo "stop:   ./render_farm.sh --stop"
