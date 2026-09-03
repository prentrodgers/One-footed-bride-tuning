#!/usr/bin/env bash
# comfy_farm.sh — one ComfyUI restyle pass, split across every Intel GPU in
# the cluster, the same way render_farm.sh splits a Blender render.
#
# The shape is different from the Blender farm, because ComfyUI is a SERVER,
# not a batch program. Each GPU runs a long-lived ComfyUI pod (see the
# comfyui-w* deployments in namespace vllm); the work is driven by
# comfy_restyle.py processes running inside the one-footed-bride pod, which
# is where the rendered frames actually live. One driver process per worker,
# each pointed at a different pod IP and given its own slice of frames.
#
# Two things MUST differ per worker, because every ComfyUI instance mounts
# the same CephFS input and output directories:
#   --prefix   SaveImage counts from each process's own memory, so a shared
#              prefix means two workers overwrite each other's output.
#   mask names comfy_restyle names masks per frame for the same reason.
#
#   ./comfy_farm.sh --frames stage_frames_v3 --out styled --frame-start 1665 --frame-end 1973
#   ./comfy_farm.sh --progress
#   ./comfy_farm.sh --stop
set -euo pipefail

NS=vllm
POD_NS=default
POD=deploy/one-footed-bride
REPO=/home/prent/Repos/One-footed-bride-tuning
FRAMES=stage_frames_v3
OUT=styled_frames
START=""; END=""
EXTRA=()

usage() { sed -n '2,25p' "$0"; exit 1; }

workers() {   # name<TAB>ip, ready pods only
  kubectl -n "$NS" get po -l app=comfyui-farm -o \
    jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.labels.worker}{"\t"}{.status.podIP}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' \
    | awk -F'\t' '$3=="true"{print $1"\t"$2}'
  kubectl -n "$NS" get po -l app=comfyui -o \
    jsonpath='{range .items[?(@.status.phase=="Running")]}w0{"\t"}{.status.podIP}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' \
    | awk -F'\t' '$3=="true"{print $1"\t"$2}'
}

case "${1:-}" in
  --progress)
    kubectl -n "$POD_NS" exec "$POD" -c pod-ssh -- bash -c '
      for f in /tmp/comfy_w*.log; do
        [ -e "$f" ] || continue
        w=$(basename "$f" .log); w=${w#comfy_}
        line=$(grep -E "^\[[0-9]+/" "$f" | tail -1)
        [ -z "$line" ] && line=$(tail -1 "$f")
        printf "  %-4s %s\n" "$w" "${line:0:96}"
      done' 2>/dev/null
    exit 0;;
  --stop)
    kubectl -n "$POD_NS" exec "$POD" -c pod-ssh -- pkill -f comfy_restyle.py || true
    echo "stopped"; exit 0;;
  --status) exec kubectl -n "$NS" get po -l 'app in (comfyui,comfyui-farm)' -o wide;;
  -h|--help) usage;;
esac

while [ $# -gt 0 ]; do
  case "$1" in
    --frames) FRAMES=$2; shift 2;;
    --out) OUT=$2; shift 2;;
    --frame-start) START=$2; shift 2;;
    --frame-end) END=$2; shift 2;;
    *) EXTRA+=("$1"); shift;;
  esac
done
[ -n "$START" ] && [ -n "$END" ] || { echo "need --frame-start and --frame-end" >&2; exit 1; }

mapfile -t W < <(workers)
[ ${#W[@]} -gt 0 ] || { echo "no ready ComfyUI workers — check ./comfy_farm.sh --status" >&2; exit 1; }

TOTAL=$((END - START + 1))
N=${#W[@]}
echo "restyle: $TOTAL frames over $N ComfyUI workers"

# Even split. The GPUs are within a factor of two of each other and a restyle
# frame costs far more than a Blender frame, so a measured-rate split like the
# Blender farm's would be refining the wrong end; --progress shows the spread
# and the slowest worker sets the finish.
i=0; lo=$START
for row in "${W[@]}"; do
  name=${row%%$'\t'*}; ip=${row##*$'\t'}
  remaining=$(( END - lo + 1 ))
  share=$(( (remaining + (N - i) - 1) / (N - i) ))
  hi=$(( lo + share - 1 )); [ $hi -gt "$END" ] && hi=$END
  printf "  %-4s %-15s frames %6d..%-6d (%d)\n" "$name" "$ip" "$lo" "$hi" "$share"
  kubectl -n "$POD_NS" exec "$POD" -c pod-ssh -- bash -c "
    cd $REPO
    setsid nohup python3 comfy_restyle.py \
      --server http://$ip:8188 --frames $FRAMES --out $OUT \
      --frame-start $lo --frame-end $hi --prefix $name \
      ${EXTRA[*]:-} > /tmp/comfy_$name.log 2>&1 < /dev/null &
    sleep 1"
  lo=$((hi + 1)); i=$((i + 1))
done
echo
echo "watch:  ./comfy_farm.sh --progress"
