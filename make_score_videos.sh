#!/usr/bin/env bash
# make_score_videos.sh — a scrolling-score video per chorale (score_video.py).
#
#     ./make_score_videos.sh bwv261
#     ./make_score_videos.sh bwv{427..438}
#     DRY_RUN=1 ./make_score_videos.sh bwv{427..438}
#     SUFFIX=_slow ./make_score_videos.sh bwv434      -> score_bwv434_slow.mp4
#     MP3=ball9-t34a_..._t022.mp3 SUFFIX=_slow ./make_score_videos.sh bwv434
#
# SUFFIX keeps a second version of a chorale beside the first -- a slower
# rendering, say -- instead of overwriting it.  MP3 pins one rendering by
# name when the newest is not the one you mean; it takes a basename in
# Uploads or a full path on the PVC, and suits a single chorale at a time.
#
# For each chorale it finds the newest --short_repeats rendering on the PVC
# (Uploads/ball9-t<NNN>a_*.mp3, NNN the BWV number; older files have two digits),
# reads the tempo out of its filename (..._t034.mp3 -> 34), writes the chord
# report for the tuning in best-tunings, renders the video, and copies it back
# to the PVC as score_<chorale>.mp4.
#
# It runs HERE, not in the pod: LilyPond is installed on fs2 only.  The mp3 is
# fetched to WORK if it is not already local.  fs2's ffmpeg has no libx264, so
# score_video.py encodes AV1, which Fedora's VLC plays and its H.264 does not.
#
# The "a" renderings are the plain chorale — no rhythmic alteration — which is
# what the scrolling score shows.  Re-render one with WreckingCrew's
# --short_repeats if it predates the tuning you want to see.
set -uo pipefail
cd "$(dirname "$0")"

POD=${POD:-one-footed-bride-pod}
REPO=/home/prent/Repos/One-footed-bride-tuning
TUNINGS=Archive/straw-man/best-tunings
WORK=${WORK:-score_videos}
DRY_RUN=${DRY_RUN:-0}
SUFFIX=${SUFFIX:-}
MP3=${MP3:-}
[ $# -gt 0 ] || { sed -n '2,12p' "$0"; exit 2; }
mkdir -p "$WORK"

run() { if [ "$DRY_RUN" = 1 ]; then echo "+ $*"; else "$@"; fi; }
fail=0

for chorale in "$@"; do
    case "$chorale" in bwv*) ;; *) echo "chorale names need the bwv prefix: $chorale" >&2; fail=1; continue;; esac
    # WreckingCrew names the track after the BWV number: all three digits
    # since 19 Sep 2026 (t433a), the last two before (t33a).  Look for both.
    track=${chorale#bwv}; track2=${track: -2}

    if [ -n "$MP3" ]; then
        case "$MP3" in /*) mp3=$MP3;; *) mp3=$REPO/Uploads/$MP3;; esac
        ssh -n "$POD" "test -f '$mp3'" 2>/dev/null || { echo "$chorale: no $mp3 on the PVC" >&2; fail=1; continue; }
    else
        mp3=$(ssh -n "$POD" "ls -t $REPO/Uploads/ball9-t${track}a_*.mp3 $REPO/Uploads/ball9-t${track2}a_*.mp3 2>/dev/null | head -1" 2>/dev/null)
    fi
    if [ -z "$mp3" ]; then
        echo "$chorale: no Uploads/ball9-t${track}a_*.mp3 (or t${track2}a) on the PVC — render one with --short_repeats first" >&2
        fail=1; continue
    fi
    base=$(basename "$mp3")
    # ..._t034.mp3 -> 34 (the tempo WreckingCrew rendered it at)
    tempo=$(sed -n 's/.*_t\([0-9]\{3\}\)\.mp3$/\1/p' <<<"$base"); tempo=$((10#$tempo))
    if [ "$tempo" -le 0 ]; then
        echo "$chorale: no tempo in $base" >&2; fail=1; continue
    fi

    tuning=$(ls "$TUNINGS/${chorale}_"*-opt.npy 2>/dev/null | head -1)
    if [ -z "$tuning" ]; then
        echo "$chorale: no tuning in $TUNINGS" >&2; fail=1; continue
    fi

    [ -f "$WORK/$base" ] || run scp -q "$POD:$mp3" "$WORK/$base"
    report=$WORK/chord_report_${chorale}.txt
    echo "== $chorale  tempo $tempo  $(basename "$tuning")"
    if [ "$DRY_RUN" = 1 ]; then
        echo "+ python chord_report.py --input_numpy_file $tuning > $report"
    else
        # chord_report warns on stdout if the tuning does not play the score;
        # surface that rather than burying it in the report file.
        python chord_report.py --input_numpy_file "$tuning" > "$report" 2>/dev/null || { echo "$chorale: chord_report failed" >&2; fail=1; continue; }
        grep -m1 '^WARNING' "$report" && { echo "$chorale: stale tuning — skipping" >&2; fail=1; continue; }
    fi

    out=score_${chorale}${SUFFIX}.mp4
    run python score_video.py --chorale "$chorale" --tempo "$tempo" \
        --mp3 "$WORK/$base" --report "$report" --out "$out" --work "$WORK/${chorale}_work" \
        || { echo "$chorale: score_video.py failed" >&2; fail=1; continue; }
    run scp -q "$out" "$POD:$REPO/$out"
    [ "$DRY_RUN" = 1 ] || echo "   wrote $out ($(du -h "$out" | cut -f1)) and copied it to the PVC"
done

exit $fail
