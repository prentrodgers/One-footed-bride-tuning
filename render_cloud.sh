#!/usr/bin/env bash
# render_cloud.sh — a Concert Stage render on a RENTED NVIDIA machine instead of the Arc farm in the
# closet: render_farm.sh's job, for any Linux box with NVIDIA GPUs that answers ssh (RunPod, Vast.ai, a
# cloud VM). Nothing here is tied to one provider; you rent the machine and give its address.
#
#   HOST=root@203.0.113.7 PORT=40122 BLEND=Alcorcon_Recital.blend ./render_cloud.sh \
#       --npy Uploads/b858r_recital.npy --tempo 60 --duration 225.70 --out frames_b858r_recital_v2 --title none
#   ./render_cloud.sh --progress      # frames done, rate, eta, each process, the cards
#   ./render_cloud.sh --wait          # --progress every minute until it finishes, then --fetch
#   ./render_cloud.sh --fetch         # the mp4, here (FRAMES=1: the frames as well)
#   ./render_cloud.sh --stop          # end the render on the machine (frames stay there)
#   ./render_cloud.sh --dry-run ...   # what would be copied and started; no ssh
#
# The arguments are concert_stage.py's, as render_farm.sh takes them (--engine cycles is implied; add
# --res-x 1920 --res-y 1080, --samples, --motion-blur ... as wanted). --progress, --wait, --fetch and
# --stop remember the last launch (HOST, PORT, the directory, --out), so they need no arguments.
#
# What it does: tars the concert_*.py scripts, the .blend and the piece (.npy, .mp3, .title.txt,
# .recital.json: about 20 MB, not the 3.7 GB repo) to the machine and starts render_cloud_box.sh there,
# detached, so the render survives this shell and the ssh session. That script installs Blender 5.3 if
# the machine has none, runs PER_GPU processes on every card, muxes the mp4 and says when it is done;
# its header has the detail. The frames are shared between the processes by concert_stage.py
# --claim-block, not sliced by a rate table: any mix of cards finishes together.
#
# Environment:
#   HOST=user@host  the machine (required at launch).  PORT=22.  SSH_OPTS="-i ~/.ssh/key" for more.
#   BLEND=...       the stage (default Concert_Stage.blend, as render_farm.sh)
#   REMOTE_DIR=ofb-render   where on the machine, relative to its home (on RunPod use
#                   /workspace/ofb-render: the volume that outlives a stopped pod)
#   PER_GPU=2       Blender processes per card. The recital measured 0.04 s of Python per frame and
#                   about 2 s of scene export against 7-15 s of sampling on a B580: on a fast card the
#                   export is a real share of a frame, and a second process overlaps it.
#   GPUS="0 1"      only these cards (default: all nvidia-smi lists)
#   DEVICE=optix    concert_stage.py --render-device (cuda if the driver is too old for OptiX)
#   BLOCK=30        frames per claimed block
#   AFTER='...'     a command run ON the machine once the result is fetched (or 20 minutes after the
#                   render ends, GRACE, if nobody fetched it): the provider's way to stop the machine,
#                   e.g. AFTER='runpodctl stop pod $RUNPOD_POD_ID'. Unset: the machine keeps running,
#                   AND BILLING, until you stop it in the provider's console.
#   MUX=0           do not mux on the machine.   FRAMES=1  --fetch brings the frames too.
#   BLENDER_VERSION=5.3.0   BLENDER_URL=...  another build or mirror
set -euo pipefail
cd "$(dirname "$0")"
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/render_cloud.last
usage(){ sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }

MODE=launch; DRY=0; NPY=; OUT=; TITLE=; ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0;;
    --progress|--wait|--fetch|--stop) MODE=${1#--};;
    --dry-run) DRY=1;;
    --npy)   NPY=$2;   ARGS+=("$1" "$2"); shift;;
    --out)   OUT=$2;   ARGS+=("$1" "$2"); shift;;
    --title) TITLE=$2; ARGS+=("$1" "$2"); shift;;
    --engine) [ "$2" = cycles ] || { echo "render_cloud.sh renders with Cycles only (--engine $2)" >&2; exit 2; }; shift;;
    --render-device|--claim-block|--gpu-name)
      echo "$1 is set by render_cloud.sh (DEVICE=, BLOCK=): leave it out" >&2; exit 2;;
    *) ARGS+=("$1");;
  esac
  shift
done

if [ "$MODE" != launch ]; then                               # the last launch, unless the environment says otherwise
  [ -f "$STATE" ] && { h=${HOST:-}; p=${PORT:-}; d=${REMOTE_DIR:-}; o=$OUT; . "$STATE"
                       HOST=${h:-$HOST}; PORT=${p:-$PORT}; REMOTE_DIR=${d:-$REMOTE_DIR}; OUT=${o:-$OUT}; }
  : "${HOST:?no earlier launch on record: set HOST (and PORT, REMOTE_DIR, OUT)}" "${OUT:?which render? set OUT}"
fi
PORT=${PORT:-22}; REMOTE_DIR=${REMOTE_DIR:-ofb-render}
SSH=(ssh -p "$PORT" -o ServerAliveInterval=30 ${SSH_OPTS:-} "${HOST:-}")
box(){ "${SSH[@]}" "cd $(printf %q "$REMOTE_DIR") && OUT=$(printf %q "$OUT") bash render_cloud_box.sh $*"; }

fetch(){
  local st; st=$("${SSH[@]}" "cat $(printf %q "$REMOTE_DIR/.render_cloud/${OUT//\//_}/finished") 2>/dev/null" || true)
  [ -n "$st" ] || { echo "not finished yet: ./render_cloud.sh --progress" >&2; return 1; }
  echo "finished: $st"
  if "${SSH[@]}" "test -f $(printf %q "$REMOTE_DIR/$OUT.mp4")"; then
    scp -q -P "$PORT" ${SSH_OPTS:-} "$HOST:$REMOTE_DIR/$OUT.mp4" "$OUT.mp4" && echo "fetched $OUT.mp4 ($(du -h "$OUT.mp4" | cut -f1))"
  else
    echo "no $OUT.mp4 on the machine (MUX=0, or the mux failed)"; FRAMES=1
  fi
  if [ "${FRAMES:-0}" = 1 ]; then
    mkdir -p "$OUT"
    "${SSH[@]}" "cd $(printf %q "$REMOTE_DIR") && tar cf - --exclude='.claims' --exclude='.part_*' $(printf %q "$OUT")" | tar xf -
    echo "fetched $(find "$OUT" -maxdepth 1 -name 'frame_*.png' | wc -l) frames into $OUT/"
  fi
  "${SSH[@]}" "touch $(printf %q "$REMOTE_DIR/.render_cloud/${OUT//\//_}/fetched")"
  if [ -n "${AFTER:-}" ]; then echo "the machine now runs its AFTER command ($AFTER)"
  else echo "THE MACHINE IS STILL RUNNING and billed by the hour: stop it in the provider's console."; fi
}

case "$MODE" in
  progress) box --progress; exit;;
  stop)     box --stop; exit;;
  fetch)    fetch; exit;;
  wait)     while :; do
              out=$(box --progress) || { echo "$out"; exit 1; }
              echo "$(date +%T) $(echo "$out" | head -1)"
              echo "$out" | grep -q '^state   running' || { echo "$out" | tail -n +2; break; }
              sleep "${POLL:-60}"
            done
            echo "$out" | grep -q '^state   finished' && fetch
            exit;;
esac

# ── launch ──
[ -n "$NPY" ] && [ -n "$OUT" ] || { usage | sed -n '1,12p'; exit 2; }
BLEND=${BLEND:-Concert_Stage.blend}
PIECE=${NPY%.npy}
case "$NPY$OUT$BLEND" in /*|*..*) echo "paths are relative to the repo (no /abs, no ..)" >&2; exit 2;; esac
FILES=(concert_*.py concert_mux.sh render_cloud_box.sh "$BLEND" "$NPY" "$PIECE.mp3")
for f in "$BLEND" "$NPY" "$PIECE.mp3"; do [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }; done
RECITAL=0; [ -f "$PIECE.recital.json" ] && { RECITAL=1; FILES+=("$PIECE.recital.json"); }
if [ "$TITLE" != none ] && [ "$RECITAL" = 0 ]; then
  if [ -n "$TITLE" ]; then [ -f "$TITLE" ] || { echo "missing $TITLE" >&2; exit 1; }; FILES+=("$TITLE")
  elif [ -f "$PIECE.title.txt" ]; then FILES+=("$PIECE.title.txt")
  else
    echo "no $PIECE.title.txt. Make it where concert_title.py runs, then copy it here:" >&2
    echo "    ssh one-footed-bride-pod \"cd Repos/One-footed-bride-tuning && python concert_title.py '$PIECE'\"" >&2
    echo "or pass --title none for a render without a title card." >&2; exit 1
  fi
fi
ENVV=(OUT="$OUT" PIECE="$PIECE" BLEND="$BLEND" PER_GPU="${PER_GPU:-2}" DEVICE="${DEVICE:-optix}" BLOCK="${BLOCK:-30}"
      MUX="${MUX:-1}" GRACE="${GRACE:-20}" BLENDER_VERSION="${BLENDER_VERSION:-5.3.0}")
for v in AFTER GPUS BLENDER BLENDER_URL; do [ -n "${!v:-}" ] && ENVV+=("$v=${!v}"); done
RUN=.render_cloud/${OUT//\//_}                               # as render_cloud_box.sh names it
REMOTE_CMD="cd $(printf %q "$REMOTE_DIR") && mkdir -p $(printf %q "$RUN") && { setsid nohup env $(printf '%q ' "${ENVV[@]}") bash render_cloud_box.sh $(printf '%q ' "${ARGS[@]}") >$(printf %q "$RUN/supervisor.log") 2>&1 </dev/null & }"

echo "piece:   $PIECE ($([ "$RECITAL" = 1 ] && echo "a recital" || echo "title: ${TITLE:-$PIECE.title.txt}"))"
echo "stage:   $BLEND"
echo "payload: ${#FILES[@]} files, $(du -ch "${FILES[@]}" | tail -1 | cut -f1) -> ${HOST:-<HOST>}:$REMOTE_DIR"
echo "render:  ${ARGS[*]}  [${DEVICE:-optix}, ${PER_GPU:-2} per GPU]"
[ -n "${AFTER:-}" ] && echo "after:   $AFTER" || echo "after:   nothing (AFTER unset): the machine keeps running until you stop it"
if [ "$DRY" = 1 ]; then echo; echo "would run on the machine:"; echo "  $REMOTE_CMD"; exit 0; fi
: "${HOST:?set HOST=user@host (the rented machine)}"

echo "== the machine"
"${SSH[@]}" 'echo "   $(nproc) cores, $(awk "/MemTotal/{printf \"%d GiB\", \$2/1048576}" /proc/meminfo), $(df -h --output=avail . | tail -1 | tr -d " ") free"; nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader 2>/dev/null | sed "s/^/   gpu /" || echo "   no nvidia-smi"'
echo "== copying"
tar czf - "${FILES[@]}" | "${SSH[@]}" "mkdir -p $(printf %q "$REMOTE_DIR") && tar xzf - -C $(printf %q "$REMOTE_DIR")"
mkdir -p "$(dirname "$STATE")"
printf 'HOST=%q\nPORT=%q\nREMOTE_DIR=%q\nOUT=%q\n' "$HOST" "$PORT" "$REMOTE_DIR" "$OUT" >"$STATE"
echo "== starting"
"${SSH[@]}" "$REMOTE_CMD"
sleep 5
"${SSH[@]}" "tail -n 6 $(printf %q "$REMOTE_DIR/$RUN/supervisor.log")" | sed 's/^/   /'
echo
echo "watch:  ./render_cloud.sh --progress      (or --wait: follows it, then fetches the mp4)"
echo "stop:   ./render_cloud.sh --stop"
