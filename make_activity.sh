#!/usr/bin/env bash
# Chart who is playing and how loudly, to author blender_stage.py's
# CAMERA_CUES against. Wraps the two halves of the job — bpy only exists
# inside Blender, matplotlib only outside it — so you run one thing:
#
#     ./make_activity.sh Uploads/ball9-t57c_lm19_r1.12_df5_t3_d05_07_t106.npy
#
# writes activity_bwv257.json + activity_bwv257.png.
#
# Everything is read off the filename and the audio, because typing the
# tempo by hand is how you get a chart that silently disagrees with the
# render. Tempo is the trailing _t<NNN>; the piece number is the t<NN>c;
# duration is the real length of the mp3 sitting beside the .npy (the
# d<mm>_<ss> in the name is close but rounded, and being 3s out shifts
# every cue you read off the chart). Pass a second argument to override
# the output basename.
set -eu

npy=${1:?usage: make_activity.sh <features.npy> [out_basename]}
mp3="${npy%.npy}.mp3"
[ -f "$mp3" ] || { echo "make_activity: no mp3 beside $npy" >&2; exit 1; }

base=$(basename "$npy")
tempo=$(printf '%s' "$base" | sed -n 's/.*_t\([0-9]\{1,\}\)\.npy$/\1/p')
piece=$(printf '%s' "$base" | sed -n 's/^ball9-t\([0-9]\{1,\}\)c_.*/\1/p')
[ -n "$tempo" ] || { echo "make_activity: no _t<tempo> in $base" >&2; exit 1; }
out=${2:-${piece:+activity_bwv2$piece}}
[ -n "$out" ] || { echo "make_activity: no t<NN>c in $base — pass a name" >&2; exit 1; }

dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$mp3")
echo "make_activity: $out  tempo=$tempo  duration=${dur}s"

blender -b -P blender_stage.py -- --npy "$npy" --tempo "$tempo" \
    --duration "$dur" --dump-activity "$out.json" 2>&1 | grep '^\[stage\] wrote' || {
        echo "make_activity: blender failed — rerun without the grep to see why" >&2
        exit 1
    }
.venv/bin/python plot_activity.py "$out.json" -o "$out.png"
