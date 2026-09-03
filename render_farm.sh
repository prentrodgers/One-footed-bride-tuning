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
#   ./render_farm.sh --status
#   ./render_farm.sh --progress
#   ./render_farm.sh --stop
#
# Pods are started one at a time, STAGGER seconds apart. Mounting the 2Ti
# CephFS volume takes ~60-90s per pod, and five at once put every one of them
# past the kubelet's CreateContainer deadline: all five died with "context
# deadline exceeded" while a single pod was fine.
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
IMAGE=${IMAGE:-quay.io/prentrodgers/python-music:0.10}
PULL_SECRET=regcred
REPO=/home/prent/Repos/One-footed-bride-tuning
FPS=30
RES_X=1280
RES_Y=720

# label   node  device-select  card-ordinal  seconds/frame
#
# The two B70s share a PCI id, so MESA_VK_DEVICE_SELECT cannot tell them
# apart, and Cycles would happily take both. Each pod therefore keeps ONE
# render node and bind-mounts /dev/null over every other one, inside its own
# container. The node to keep is found by PCI device id at pod start, not
# named here: an earlier version named renderD129/renderD130, but on fs5
# those are the iGPU and one B70 (the B70s are D128 and D130), so the pod
# that "hid" D129 was hiding the iGPU and could see both cards. The
# card-ordinal column says which matching card a pod takes, in sysfs order.
WORKERS=(
  "b70a   fs5  8086:e223  0           1.701"
  "b70b   fs5  8086:e223  1           1.751"
  "b580f6 fs6  8086:e20b  -           1.651"
  "b580f9 fs9  8086:e20b  -           1.829"
  "b50f3  fs3  8086:e212  -           2.129"
)

STAGGER=${STAGGER:-45}
NPY=""; TEMPO=""; DURATION=""; OUT=""; DRYRUN=0; ONLY=""; EXTRA=()
while [ $# -gt 0 ]; do
  case "$1" in
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
    --stop) kubectl -n "$NS" delete po -l job=blender-farm --wait=false; exit 0;;
    # Pass-through for blender_stage.py: the flag, plus its value if the next
    # token is not itself a flag (--engine cycles, --samples 96, --cycles-hw-rt).
    --*) EXTRA+=("$1"); shift
         if [ $# -gt 0 ] && [[ "$1" != --* ]]; then EXTRA+=("$1"); shift; fi;;
    *) echo "unknown argument: $1" >&2; exit 2;;
  esac
done
[ -n "$NPY$TEMPO$DURATION$OUT" ] || { sed -n '2,20p' "$0"; exit 2; }

# Frame count exactly as blender_stage.py computes it: ceil(duration * FPS).
TOTAL=$(awk -v d="$DURATION" -v f="$FPS" 'BEGIN{t=d*f; c=int(t); if (t-c>1e-9) c++; print c}')

# Slices in proportion to each worker's measured rate, contiguous, with the
# last one taking the remainder so no frame is missed or rendered twice.
weights=(); total_w=0
for w in "${WORKERS[@]}"; do
  read -r _ _ _ _ rate <<<"$w"
  weight=$(awk -v r="$rate" 'BEGIN{print 1/r}')
  weights+=("$weight")
  total_w=$(awk -v a="$total_w" -v b="$weight" 'BEGIN{print a+b}')
done

echo "render: $TOTAL frames over ${#WORKERS[@]} GPUs  ($(awk -v w="$total_w" 'BEGIN{printf "%.2f", w}') frames/s, "\
"eta $(awk -v t="$TOTAL" -v w="$total_w" 'BEGIN{printf "%.0f", t/w/60}') min)"

start=0
for i in "${!WORKERS[@]}"; do
  read -r label node select ordinal rate <<<"${WORKERS[$i]}"
  if [ "$i" -eq $((${#WORKERS[@]} - 1)) ]; then
    end=$((TOTAL - 1))
  else
    share=$(awk -v w="${weights[$i]}" -v tw="$total_w" -v t="$TOTAL" 'BEGIN{printf "%d", (w/tw)*t}')
    end=$((start + share - 1))
  fi
  if [ -n "$ONLY" ] && [ "$ONLY" != "$label" ]; then
    start=$((end + 1))
    continue
  fi
  printf "  %-7s %-4s %-11s frames %6d..%-6d (%d)%s\n" "$label" "$node" "$select" "$start" "$end" $((end - start + 1)) \
         "${EXTRA[*]:+  ${EXTRA[*]}}"

  if [ "$DRYRUN" -eq 0 ]; then
    # Keep the Nth render node whose PCI device id matches this worker's
    # card; hide all the others (dGPU siblings and iGPUs alike). Runs inside
    # the pod, where sysfs is the host's and /dev/dri is the passed-through
    # directory, so the choice is made against what is actually there.
    [ "$ordinal" = "-" ] && ordinal=0
    hide_cmd="dev=0x${select#*:}; keep=''; n=0; for s in /sys/class/drm/renderD*; do [ \"\$(cat \$s/device/device)\" = \"\$dev\" ] || continue; [ \$n -eq $ordinal ] && keep=\$(basename \$s); n=\$((n+1)); done; [ -n \"\$keep\" ] || { echo \"[farm] no card \$dev ordinal $ordinal on this node\" >&2; exit 3; }; for d in /dev/dri/renderD*; do [ \"\$(basename \$d)\" = \"\$keep\" ] || mount --bind /dev/null \$d; done; echo \"[farm] rendering on \$keep\"; "
    kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: blender-farm-$label
  namespace: $NS
  labels: {job: blender-farm}
spec:
  restartPolicy: Never
  nodeSelector: {kubernetes.io/hostname: $node}
  imagePullSecrets: [{name: $PULL_SECRET}]
  securityContext: {supplementalGroups: [991]}
  containers:
  - name: blender
    image: $IMAGE
    securityContext: {privileged: true, runAsUser: 0}
    env: [{name: MESA_VK_DEVICE_SELECT, value: "$select"}]
    command: ["bash","-c"]
    args:
    - ${hide_cmd}cd $REPO && exec blender --background --gpu-backend vulkan
      --python blender_stage.py -- --npy $NPY --tempo $TEMPO --duration $DURATION
      --res-x $RES_X --res-y $RES_Y --out $OUT --frame-start $start --frame-end $end ${EXTRA[*]:-}
    volumeMounts:
    - {name: ceph, mountPath: /home/prent}
    - {name: dri, mountPath: /dev/dri}
  volumes:
  - {name: ceph, persistentVolumeClaim: {claimName: dropbox-pvc}}
  - {name: dri, hostPath: {path: /dev/dri}}
YAML
  fi
  start=$((end + 1))
  # Let this pod's volume finish mounting before asking for the next one.
  if [ "$DRYRUN" -eq 0 ] && [ "$i" -lt $((${#WORKERS[@]} - 1)) ]; then
    sleep "$STAGGER"
  fi
done

[ "$DRYRUN" -eq 1 ] && exit 0
echo
echo "watch:  ./render_farm.sh --status"
echo "count:  kubectl -n $NS exec deploy/one-footed-bride -c pod-ssh -- ls $REPO/$OUT | wc -l"
echo "stop:   ./render_farm.sh --stop"
