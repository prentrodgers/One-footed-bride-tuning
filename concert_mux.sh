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
[ -d "$FRAMES" ] || { echo "no frames directory $FRAMES" >&2; exit 1; }
[ -f "$P.mp3" ] || { echo "no audio $P.mp3" >&2; exit 1; }
echo "$(date +%T) $V: frames from $FRAMES, audio $P.mp3 (delayed ${LEAD} s)"
echo "$(date +%T) checking the frames..."
# One directory listing, not a stat per frame: on CephFS 14k separate stats took minutes.
# -size +0 leaves out empty files, so a frame that was started but never written counts as missing.
have=$(find "$FRAMES" -maxdepth 1 -name 'frame_*.png' -size +0 -printf '%f\n' | sort)
n=$(find "$FRAMES" -maxdepth 1 -name 'frame_*.png' | wc -l)
missing=$(comm -23 <(for ((i = 0; i < n; i++)); do printf 'frame_%06d.png\n' $i; done) <(echo "$have") \
          | sed 's/frame_0*\([0-9]\)/\1/; s/\.png//' | head || true)
[ -z "$missing" ] || { echo "missing frames: $missing" >&2; exit 1; }
echo "$(date +%T) $n frames, all present: $(awk -v n="$n" 'BEGIN{printf "%d:%02d", n/30/60, (n/30)%60}') of video at 30 fps"
echo "$(date +%T) encoding (libx264, crf 20) - the progress line below counts frames up to $n"
ms=$(awk -v l="$LEAD" 'BEGIN{printf "%d", l * 1000}')
ffmpeg -nostdin -y -loglevel error -stats -framerate 30 -i "$FRAMES/frame_%06d.png" -i "$P.mp3" \
  -af "adelay=delays=${ms}:all=1,apad" -c:v libx264 -pix_fmt yuv420p -crf 20 -c:a aac -shortest "$V"
echo "$(date +%T) done"
echo "$V: $n frames, audio delayed ${LEAD} s and padded to the end, $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$V") s"
