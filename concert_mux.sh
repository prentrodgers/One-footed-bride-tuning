#!/usr/bin/env bash
# concert_mux.sh FRAMES PIECE OUT.mp4 - a Concert Stage render's frames plus the piece's mp3, as an mp4.
#
#   ./concert_mux.sh frames_concert_b425f_v4 Uploads/b425f_df5_t2_d08_00_t096_ap3_lm19_r1.50 concert_b425f_v4.mp4
#
# When the piece has a title card (PIECE.title.txt), the video has 8 s of title before the music and
# 8 s after it (concert_cameras.TITLE_SECONDS): the audio is delayed by 8 s and padded with silence to
# the end of the video. LEAD=0 (or another value) overrides the delay. Checks that no frame is missing
# first. Run it where ffmpeg has libx264: one-footed-bride-pod.
set -euo pipefail
[ $# -eq 3 ] || { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
FRAMES=$1; P=${2%.npy}; P=${P%.mp3}; V=$3
LEAD=${LEAD:-$([ -f "$P.title.txt" ] && echo 8 || echo 0)}
n=$(find "$FRAMES" -maxdepth 1 -name 'frame_*.png' | wc -l)
missing=$(for ((i = 0; i < n; i++)); do f=$(printf '%s/frame_%06d.png' "$FRAMES" $i); [ -s "$f" ] || echo $i; done | head)
[ -z "$missing" ] || { echo "missing frames: $missing" >&2; exit 1; }
ms=$(awk -v l="$LEAD" 'BEGIN{printf "%d", l * 1000}')
ffmpeg -nostdin -y -loglevel error -framerate 30 -i "$FRAMES/frame_%06d.png" -i "$P.mp3" \
  -af "adelay=delays=${ms}:all=1,apad" -c:v libx264 -pix_fmt yuv420p -crf 20 -c:a aac -shortest "$V"
echo "$V: $n frames, audio delayed ${LEAD} s and padded to the end, $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$V") s"
