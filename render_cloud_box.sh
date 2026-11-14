#!/usr/bin/env bash
# render_cloud_box.sh — the half of render_cloud.sh that runs ON the rented machine. render_cloud.sh
# copies it there with the scripts, the .blend and the piece, and starts it detached; its settings are
# environment variables and its arguments go to concert_stage.py unchanged.
#
#   render_cloud_box.sh <concert_stage.py arguments>    render, mux, run $AFTER
#   render_cloud_box.sh --progress                      frames done, rate, eta, what each process is on
#   render_cloud_box.sh --stop                          end the render (frames stay)
#
# In order:
#   1. the libraries Blender needs even with --background, and ffmpeg (apt, when root on Debian/Ubuntu,
#      which is what the GPU clouds hand out), then Blender $BLENDER_VERSION itself, downloaded once into
#      this directory: the SAME version that saved the .blend. (The farm pods' 5.2 open a 5.3 file with
#      "File written by newer Blender binary, expect loss of data".)
#   2. PER_GPU Blender processes per GPU, each tied to its card by CUDA_VISIBLE_DEVICES and ALL given
#      the whole frame range: they share it out with concert_stage.py --claim-block, so there are no
#      slices to size and no rate table, and nobody waits on a slow slice. The first process starts
#      alone and the rest follow its first frame, so the OptiX kernels are built once, not once each.
#   3. when they have all exited, anything missing (a process that died held a block) is rendered in
#      another pass: up to 3.
#   4. concert_mux.sh makes $OUT.mp4 (MUX=0 to skip), and "finished" is written.
#   5. $AFTER, if set — the provider's own way to stop this machine, e.g.
#      AFTER='runpodctl stop pod $RUNPOD_POD_ID' — once render_cloud.sh has fetched the video, or after
#      GRACE minutes (20) if it has not come for it. A rented card bills by the hour until it is stopped.
set -uo pipefail
cd "$(dirname "$0")"
log(){ echo "$(date +%T) $*"; }
: "${OUT:?OUT (the frames directory) is not set}"
PER_GPU=${PER_GPU:-2}; DEVICE=${DEVICE:-optix}; BLOCK=${BLOCK:-30}; MUX=${MUX:-1}
AFTER=${AFTER:-}; GRACE=${GRACE:-20}; BLENDER_VERSION=${BLENDER_VERSION:-5.3.0}
RUN=.render_cloud/$(echo "$OUT" | tr '/' '_')                 # this render's logs, pid, state
frames_have(){ find "$OUT" -maxdepth 1 -name 'frame_*.png' -size +0 2>/dev/null | wc -l; }
expected(){ sed -n 's/.*animating frames \([0-9]*\)\.\.\([0-9]*\) of \([0-9]*\).*/\1 \2/p' "$RUN"/*.log 2>/dev/null | head -1; }
missing(){                                                    # how many frames of the range are not there
  local a b; read -r a b <<<"$(expected)"; [ -n "${b:-}" ] || { echo -1; return; }
  comm -23 <(seq -f 'frame_%06g.png' "$a" "$b") \
           <(find "$OUT" -maxdepth 1 -name 'frame_*.png' -size +0 -printf '%f\n' 2>/dev/null | sort) | wc -l
}
alive(){ [ -f "$RUN/pid" ] && kill -0 "$(cat "$RUN/pid")" 2>/dev/null; }

case "${1:-}" in
--progress)
  [ -d "$RUN" ] || { echo "no render of $OUT has been started here"; exit 1; }
  read -r t0 n0 <"$RUN/started"; now=$(date +%s); have=$(frames_have)
  read -r a b <<<"$(expected)"
  if [ -z "${b:-}" ]; then
    alive && echo "state   starting (Blender is being set up or is loading the stage): $(tail -1 "$RUN/supervisor.log" 2>/dev/null)" \
          || echo "state   STOPPED before rendering: $(tail -3 "$RUN/supervisor.log" 2>/dev/null)"
    exit 0
  fi
  total=$(( b - a + 1 ))
  awk -v h="$have" -v n0="$n0" -v tot="$total" -v el=$((now - t0)) 'BEGIN{
    r = (el > 0) ? (h - n0) / el : 0; left = tot - h
    printf "frames  %d/%d (%.1f%%)  elapsed %dm%02ds  %.2f frames/s  eta %s\n", h, tot, tot ? 100*h/tot : 0,
           el/60, el%60, r, (r > 0 && left > 0) ? sprintf("%dm", left/r/60 + 1) : (left > 0 ? "?" : "-") }'
  for f in "$RUN"/g*.log; do
    printf '  %-6s %s\n' "$(basename "$f" .log)" "$(grep -E '^  frame |\[stage\] done|Error|rror:' "$f" | tail -1 | cut -c1-110)"
  done
  command -v nvidia-smi >/dev/null && nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,power.draw \
      --format=csv,noheader 2>/dev/null | sed 's/^/  gpu /'
  if [ -f "$RUN/finished" ]; then echo "state   finished: $(cat "$RUN/finished")"
  elif alive; then echo "state   running"
  else echo "state   STOPPED without finishing (see $RUN/supervisor.log)"; fi
  exit 0;;
--stop)
  alive || { echo "nothing running for $OUT"; exit 0; }
  pid=$(cat "$RUN/pid")                                     # the supervisor and its Blenders: one process group
  kill -TERM -- "-$pid" 2>/dev/null || { pkill -TERM -P "$pid"; kill -TERM "$pid" 2>/dev/null; }; sleep 1
  echo "stopped; $(frames_have) frames are in $OUT"; exit 0;;
esac

: "${PIECE:?PIECE (Uploads/<name>, no extension) is not set}" "${BLEND:?BLEND is not set}"
mkdir -p "$RUN" "$OUT"
alive && { log "a render of $OUT is already running here (pid $(cat "$RUN/pid")): --stop it first"; exit 2; }
echo $$ >"$RUN/pid"; rm -f "$RUN"/finished "$RUN"/fetched "$RUN"/g*.log
echo "$(date +%s) $(frames_have)" >"$RUN/started"

# 1. libraries, ffmpeg, Blender
if command -v apt-get >/dev/null && [ "$(id -u)" = 0 ]; then
  want=()
  for p in libxi6 libxxf86vm1 libxfixes3 libxrender1 libxkbcommon0 libsm6 libice6 libgl1 libegl1 xz-utils curl ffmpeg; do
    dpkg -s "$p" >/dev/null 2>&1 || want+=("$p")
  done
  if [ ${#want[@]} -gt 0 ]; then
    log "installing ${want[*]}"
    apt-get update -qq >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "${want[@]}" >/dev/null \
      || log "apt could not install some of them; carrying on"
  fi
fi
series=${BLENDER_VERSION%.*}
find_blender(){
  local b
  for b in "${BLENDER:-}" "$PWD/blender-$BLENDER_VERSION-linux-x64/blender" "$(command -v blender || true)"; do
    [ -n "$b" ] && [ -x "$b" ] && "$b" --version 2>/dev/null | head -1 | grep -q "^Blender $series" \
      && { BLENDER=$b; return 0; }
  done
  return 1
}
if ! find_blender; then
  # download.blender.org answers a script with 403; its mirrors do not.
  for u in ${BLENDER_URL:-} \
           "https://mirrors.ocf.berkeley.edu/blender/release/Blender$series/blender-$BLENDER_VERSION-linux-x64.tar.xz" \
           "https://mirror.clarkson.edu/blender/release/Blender$series/blender-$BLENDER_VERSION-linux-x64.tar.xz"; do
    log "downloading Blender $BLENDER_VERSION from $u"
    curl -fsSL --retry 3 -o blender.tar.xz "$u" && tar -xJf blender.tar.xz && rm -f blender.tar.xz && break
  done
  find_blender || { log "no Blender $series here and the download failed (its libraries? run: $PWD/blender-$BLENDER_VERSION-linux-x64/blender --version)"; exit 3; }
fi
log "$("$BLENDER" --version | head -1) at $BLENDER"

# 2. the cards
if [ -z "${GPUS:-}" ]; then
  GPUS=$(nvidia-smi --query-gpu=index --format=csv,noheader 2>/dev/null | tr '\n' ' ')
  [ -n "$GPUS" ] || { [ "$DEVICE" = cpu ] && GPUS=0; }
fi
[ -n "$GPUS" ] || { log "nvidia-smi lists no GPU on this machine: nothing to render on"; exit 3; }
command -v nvidia-smi >/dev/null && nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader | sed 's/^/         gpu /'
log "render: $OUT on GPUs [ $GPUS], $PER_GPU processes each, $DEVICE, blocks of $BLOCK frames"

start(){                                                      # start GPU PART: one Blender on one card
  CUDA_VISIBLE_DEVICES=$1 "$BLENDER" --background "$BLEND" --python concert_stage.py -- "${ARGS[@]}" \
      --engine cycles --render-device "$DEVICE" --gpu-name any --claim-block "$BLOCK" \
      >>"$RUN/g$1-$2.log" 2>&1 &
}
ARGS=("$@")
for pass in 1 2 3; do
  rm -rf "$OUT/.claims"; rm -f "$OUT"/.part_*                 # nothing is rendering: no claim is live
  first=1
  for g in $GPUS; do
    for ((p = 1; p <= PER_GPU; p++)); do
      start "$g" "$p"
      if [ "$first" = 1 ]; then                               # let the first build the kernels and cache them
        first=0; lead=$!
        for ((i = 0; i < 600; i++)); do
          grep -q '^  frame ' "$RUN/g$g-$p.log" 2>/dev/null && break
          kill -0 "$lead" 2>/dev/null || break
          sleep 1
        done
        [ "$pass" = 1 ] && log "first frame after ${i}s; starting the other processes"
      else
        sleep 2
      fi
    done
  done
  wait
  m=$(missing)
  [ "$m" = 0 ] && break
  if [ "$m" = -1 ]; then
    log "Blender never got as far as rendering. The end of its log:"; tail -15 "$RUN"/g*.log | cut -c1-200
    echo "failed: Blender did not start rendering" >"$RUN/finished"; exit 4
  fi
  log "pass $pass ended with $m frames missing (a process died: grep -l Error $RUN/g*.log)"
done
read -r t0 n0 <"$RUN/started"; el=$(( $(date +%s) - t0 )); have=$(frames_have)
summary="$have frames in $OUT, $((have - n0)) of them rendered in $((el / 60))m$((el % 60))s"
[ "$m" = 0 ] || summary="INCOMPLETE ($m frames missing after 3 passes): $summary"
log "$summary"

# 4. the video
if [ "$m" = 0 ] && [ "$MUX" = 1 ]; then
  read -r a b <<<"$(expected)"
  if [ "$a" != 0 ]; then log "a partial range ($a..$b): not muxed"
  elif ./concert_mux.sh "$OUT" "$PIECE" "$OUT.mp4"; then summary="$summary; video $OUT.mp4"
  else log "the mux failed (ffmpeg without libx264?): fetch the frames instead (FRAMES=1 ./render_cloud.sh --fetch)"; fi
fi
echo "$summary" >"$RUN/finished"

# 5. stop paying for the machine
if [ -n "$AFTER" ]; then
  for ((i = 0; i < GRACE * 6; i++)); do [ -f "$RUN/fetched" ] && break; sleep 10; done
  [ -f "$RUN/fetched" ] || log "nobody fetched the result in $GRACE minutes"
  log "AFTER: $AFTER"; bash -c "$AFTER"
else
  log "THIS MACHINE IS STILL RUNNING, and billed by the hour: fetch the result and stop it"
fi
