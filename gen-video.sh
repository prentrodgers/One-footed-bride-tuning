#!/usr/bin/env bash
# gen-video.sh — render merged_poc.mp4 for a given chorale.
#
# Usage:
#   ./gen-video.sh bwv261
#
# The script:
#   1. Locates the most-recently-modified MP3 in Uploads/ whose name matches
#      the chorale (ball9-t<NN><letter>_*.mp3, NN = last two BWV digits), via
#      uploads_lookup.py — the same helper compose_stage_merge.py and
#      string_section_poc.py use, so all three agree on the file.
#   2. Extracts the tempo (BPM) from the _t<N> token at the end of the
#      filename, e.g. "ball9-t61d_lm19_r1.25_df5_t3_d00_43_t106.mp3" → 106.
#   3. Computes the render duration from the features array + tempo via
#      Python (last note end + 2 s reverb tail), then rounds up to one
#      decimal place.
#   4. Clears the per-section frame directories and re-renders all four
#      sections (strings, marimba, finger piano, bass) in parallel, then
#      composites them into merged_poc.mp4.
#
# Prerequisites: .venv must exist in the repo root (created by the project's
# standard setup).  ffprobe is used only for an informational duration check
# and is not required.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── 1. Parse arguments ────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <chorale>  e.g.  $0 bwv261" >&2
    exit 1
fi
CHORALE="$1"

# ── 2. Activate venv ─────────────────────────────────────────────────────────
if [[ ! -f .venv/bin/activate ]]; then
    echo "ERROR: .venv not found in $SCRIPT_DIR" >&2
    exit 1
fi
# shellcheck source=/dev/null
source .venv/bin/activate

# ── 3. Locate features array ──────────────────────────────────────────────────
NPY="${CHORALE}_features_array.npy"
if [[ ! -f "$NPY" ]]; then
    echo "ERROR: features array not found: $NPY" >&2
    exit 1
fi
echo "Features array : $NPY"

# ── 4. Find newest MP3 for this chorale ───────────────────────────────────────
# Use the shared uploads_lookup helper so gen-video.sh, compose_stage_merge.py,
# and string_section_poc.py all agree on "the MP3 for this chorale": the
# most-recently-modified Uploads/*.mp3 whose name matches the chorale
# (ball9-t<NN><letter>_*.mp3, where NN = last two digits of the BWV number).
# Exits with a clear message if WreckingCrew hasn't rendered one yet.
if ! MP3="$(python3 uploads_lookup.py "$CHORALE")"; then
    # helper already printed a readable "no MP3 matching chorale ..." message
    exit 1
fi
echo "MP3 (newest)   : $MP3"

# ── 5. Extract tempo from _t<N> suffix ───────────────────────────────────────
# Tempo is the trailing _t<BPM>.mp3 token (zero-padded to 3 digits by
# WreckingCrew).  Read it from the same helper so the parse lives in one place.
if ! TEMPO="$(python3 uploads_lookup.py "$CHORALE" --tempo)"; then
    exit 1
fi
echo "Tempo          : ${TEMPO} BPM"

# ── 6. Compute render duration from the npy array ────────────────────────────
DURATION="$(python3 - "$NPY" "$TEMPO" <<'PYEOF'
import sys, math
import numpy as np

npy_file, tempo = sys.argv[1], float(sys.argv[2])
arr = np.load(npy_file)
mask = (arr[:, 5] > 0) & (arr[:, 2] > 0) & (arr[:, 14] > 0) & (arr[:, 3] > 0)
a = arr[mask]
if not len(a):
    print("0.0")
    sys.exit(0)

bps = tempo / 60.0
end_s = float((a[:, 1] + a[:, 2]).max()) / bps
# Add 2 s reverb tail, round up to one decimal place
duration = math.ceil((end_s + 2.0) * 10) / 10
print(f"{duration:.1f}")
PYEOF
)"
echo "Render duration: ${DURATION}s"

# Output filename encodes chorale, tempo, and duration, e.g.
# merged_bwv261_t056_289s.mp4 — makes renders from different takes/tempos
# distinguishable instead of all overwriting merged_poc.mp4.
OUT_MP4="merged_${CHORALE}_t$(printf '%03d' "$TEMPO")_${DURATION%.*}s.mp4"
echo "Output file    : ${OUT_MP4}"

# ── 7. Wipe old frame directories ────────────────────────────────────────────
echo ""
echo "Clearing old frames..."
rm -rf str_frames marimba8_frames finger8_frames bass8_frames ww8_frames brass8_frames bowed8_frames melody8_frames conductor_frames merged_frames
mkdir -p str_frames logs
rm -f str_notes.npy poc_notes.npy str_poc.mp4

# ── 8. Render sections ────────────────────────────────────────────────────────
# String section is the only one that needs the mp3 (for audio) and
# produces the opaque background frames.  The other three render
# transparent overlay layers and are fully independent of each other —
# run them in parallel with the string render to save time.
#
# Each renderer's own per-frame progress logging is verbose (one line every
# ~200 frames, so thousands of lines over a full-length render) — send it to
# logs/<section>.log instead of the console; only the high-level "=== ... ==="
# status below stays on screen.  `time`'s own output goes to the same file.

echo ""
echo "=== Rendering string section (background) ==="
# --stage 12: frames only, skips Stage 3's standalone str_poc.mp4 assembly —
# compose_stage_merge.py builds the real output (with audio) from these same
# frames a few steps down, so a second, redundant video here is just wasted
# encode time. --chorale is still needed for the title-card text (Stage 2).
{ time python3 string_section_poc.py \
    --npy "$NPY" --tempo "$TEMPO" --duration "$DURATION" \
    --stage 12 --chorale "$CHORALE" ; } > logs/string.log 2>&1 &
STR_PID=$!

echo "=== Rendering marimba section (transparent, parallel) ==="
{ time python3 marimba_section_poc.py \
    --npy "$NPY" --tempo "$TEMPO" --duration "$DURATION" ; } > logs/marimba.log 2>&1 &
MARIMBA_PID=$!

echo "=== Rendering finger piano section (transparent, parallel) ==="
{ time python3 finger_piano_section_poc.py \
    --npy "$NPY" --tempo "$TEMPO" --duration "$DURATION" ; } > logs/finger_piano.log 2>&1 &
FP_PID=$!

echo "=== Rendering bass section (transparent, parallel) ==="
{ time python3 bass_section_poc.py \
    --npy "$NPY" --tempo "$TEMPO" --duration "$DURATION" ; } > logs/bass.log 2>&1 &
BASS_PID=$!

echo "=== Rendering woodwind section (transparent, parallel) ==="
{ time python3 woodwind_section_poc.py \
    --npy "$NPY" --tempo "$TEMPO" --duration "$DURATION" ; } > logs/woodwind.log 2>&1 &
WW_PID=$!

echo "=== Rendering brass section (transparent, parallel) ==="
{ time python3 brass_section_poc.py \
    --npy "$NPY" --tempo "$TEMPO" --duration "$DURATION" ; } > logs/brass.log 2>&1 &
BRASS_PID=$!

echo "=== Rendering bowed strings section (transparent, parallel) ==="
{ time python3 bowed_strings_section_poc.py \
    --npy "$NPY" --tempo "$TEMPO" --duration "$DURATION" ; } > logs/bowed_strings.log 2>&1 &
BOWED_PID=$!

echo "=== Rendering melody section (transparent, parallel) ==="
{ time python3 melody_section_poc.py \
    --npy "$NPY" --tempo "$TEMPO" --duration "$DURATION" ; } > logs/melody.log 2>&1 &
MELODY_PID=$!

echo "=== Rendering conductor (baton, parallel) ==="
{ time python3 conductor_section_poc.py \
    --npy "$NPY" --tempo "$TEMPO" --duration "$DURATION" ; } > logs/conductor.log 2>&1 &
CONDUCTOR_PID=$!

# Wait for all nine to finish, propagating any failure
FAILED=0
declare -A PID_LOG=(
    [$STR_PID]=logs/string.log [$MARIMBA_PID]=logs/marimba.log
    [$FP_PID]=logs/finger_piano.log [$BASS_PID]=logs/bass.log
    [$WW_PID]=logs/woodwind.log [$BRASS_PID]=logs/brass.log
    [$BOWED_PID]=logs/bowed_strings.log [$MELODY_PID]=logs/melody.log
    [$CONDUCTOR_PID]=logs/conductor.log
)
for PID in $STR_PID $MARIMBA_PID $FP_PID $BASS_PID $WW_PID $BRASS_PID $BOWED_PID $MELODY_PID $CONDUCTOR_PID; do
    if ! wait "$PID"; then
        echo "ERROR: a section renderer exited with an error (pid=$PID) — see ${PID_LOG[$PID]}" >&2
        FAILED=1
    fi
done
if [[ $FAILED -ne 0 ]]; then
    echo "Aborting — one or more section renders failed." >&2
    exit 1
fi

# ── 9. Composite and assemble final video ─────────────────────────────────────
echo ""
echo "=== Compositing layers and assembling ${OUT_MP4} ==="
{ time python3 compose_stage_merge.py --mp3 "$MP3" --out "$OUT_MP4" ; } > logs/compose.log 2>&1 \
    || { echo "ERROR: compositing failed — see logs/compose.log" >&2; exit 1; }

# ── 10. Move the finished video alongside the source MP3s ────────────────────
mkdir -p Uploads
mv "$OUT_MP4" "Uploads/$OUT_MP4"
OUT_MP4="Uploads/$OUT_MP4"

echo ""
echo "Done.  Output: ${OUT_MP4}"
if command -v ffprobe &>/dev/null; then
    ACTUAL_DUR="$(ffprobe -v quiet -show_entries format=duration \
        -of csv=p=0 "$OUT_MP4" 2>/dev/null || echo '?')"
    echo "       Duration: ${ACTUAL_DUR}s"
fi
