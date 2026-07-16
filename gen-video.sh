#!/usr/bin/env bash
# gen-video.sh — render merged_poc.mp4 for a given chorale.
#
# Usage:
#   ./gen-video.sh bwv261
#
# The script:
#   1. Locates the most-recently-modified MP3 in Uploads/ whose name
#      contains the chorale name (e.g. bwv261).
#   2. Extracts the tempo (BPM) from the _t<N> token at the end of the
#      filename, e.g. "ball9-t61d_lm19_r1.25_df5_t3_d00_29_t118.mp3" → 118.
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
# Pick the file with the most recent modification time (WreckingCrew always
# writes a fresh mp3 after each run; the newest is the one that matches the
# current npy on disk).
MP3="$(ls -t Uploads/*.mp3 2>/dev/null | head -1)"
if [[ -z "$MP3" ]]; then
    echo "ERROR: no MP3 files found in Uploads/" >&2
    exit 1
fi
echo "MP3 (newest)   : $MP3"

# ── 5. Extract tempo from _t<N> suffix ───────────────────────────────────────
# Filename pattern: ..._t<TEMPO>.mp3  (the LAST _t<digits> before the extension)
BASENAME="$(basename "$MP3" .mp3)"
TEMPO="$(echo "$BASENAME" | grep -oP '_t\K[0-9]+(?=[^_]*$)')"
if [[ -z "$TEMPO" ]]; then
    echo "ERROR: could not extract tempo from filename: $BASENAME" >&2
    echo "  Expected a trailing _t<BPM> token, e.g. _t118.mp3" >&2
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

# ── 7. Wipe old frame directories ────────────────────────────────────────────
echo ""
echo "Clearing old frames..."
rm -rf str_frames marimba8_frames finger8_frames bass8_frames ww8_frames merged_frames
mkdir -p str_frames
rm -f str_notes.npy poc_notes.npy str_poc.mp4

# ── 8. Render sections ────────────────────────────────────────────────────────
# String section is the only one that needs the mp3 (for audio) and
# produces the opaque background frames.  The other three render
# transparent overlay layers and are fully independent of each other —
# run them in parallel with the string render to save time.

echo ""
echo "=== Rendering string section (background + audio) ==="
python3 string_section_poc.py \
    --npy "$NPY" --tempo "$TEMPO" --duration "$DURATION" \
    --stage all --mp3 "$MP3" &
STR_PID=$!

echo "=== Rendering marimba section (transparent, parallel) ==="
python3 marimba_section_poc.py \
    --npy "$NPY" --tempo "$TEMPO" --duration "$DURATION" &
MARIMBA_PID=$!

echo "=== Rendering finger piano section (transparent, parallel) ==="
python3 finger_piano_section_poc.py \
    --npy "$NPY" --tempo "$TEMPO" --duration "$DURATION" &
FP_PID=$!

echo "=== Rendering bass section (transparent, parallel) ==="
python3 bass_section_poc.py \
    --npy "$NPY" --tempo "$TEMPO" --duration "$DURATION" &
BASS_PID=$!

echo "=== Rendering woodwind section (transparent, parallel) ==="
python3 woodwind_section_poc.py \
    --npy "$NPY" --tempo "$TEMPO" --duration "$DURATION" &
WW_PID=$!

# Wait for all five to finish, propagating any failure
FAILED=0
for PID in $STR_PID $MARIMBA_PID $FP_PID $BASS_PID $WW_PID; do
    if ! wait "$PID"; then
        echo "ERROR: a section renderer exited with an error (pid=$PID)" >&2
        FAILED=1
    fi
done
if [[ $FAILED -ne 0 ]]; then
    echo "Aborting — one or more section renders failed." >&2
    exit 1
fi

# ── 9. Composite and assemble final video ─────────────────────────────────────
echo ""
echo "=== Compositing layers and assembling merged_poc.mp4 ==="
python3 compose_stage_merge.py

echo ""
echo "Done.  Output: merged_poc.mp4"
if command -v ffprobe &>/dev/null; then
    ACTUAL_DUR="$(ffprobe -v quiet -show_entries format=duration \
        -of csv=p=0 merged_poc.mp4 2>/dev/null || echo '?')"
    echo "       Duration: ${ACTUAL_DUR}s"
fi
