#!/bin/bash
# The Goldberg Variations (BWV 988), the Aria and all thirty variations, in spring tunings pulled toward
# a tonality diamond (spring_tuning.py --diamond N --harmony 32; see SPRING_TUNING.md).
#
#   bash goldberg_diamond.sh                          every movement, diamond 7
#   bash goldberg_diamond.sh --diamond 9              every movement, diamond 9
#   bash goldberg_diamond.sh --diamond 9 bwv988v16a bwv988v16b    only these movements
#
# Each line tunes one movement, then renders it: the array goes to Archive/spring/d<N>h32/<score>-opt.npy
# (with the fold, pace auto, limit 40), the mp3 to Uploads/b988v05d7h32_d.._t126.mp3 and the like.
# Tuning takes seconds; re-running a movement remakes the same array.  A movement name that is not
# one of the lines below stops the script before anything runs.
#
# Scores: a tuning array cannot be played with --measures, so each movement is its own score, cut from
# Scores/bwv988.mxl with split_score.py on 20 Nov 2026 (Scores/bwv988vNN.mxl for Var. NN), each checked
# note for note against the bars goldberg_vrwt.sh plays. Each is played once through without its
# repeats; Vars. 2, 4, 6, 16 and 25 leave out the first ending and play the second. Var. 16 is two
# scores, v16a the 2/2 overture and v16b the 3/8 fughetta, played back to back. The Aria is
# Scores/bwv988-00.mxl (bars 1-32); the Aria da capo is the Aria again: reuse it. Var. 26 is your
# MuseScore 3 copy Scores/bwv988-26.mxl, whose 18/16 hand has real triplets (bwv988.mxl's does not).
# Scores/bwv988-25.mxl and bwv988q.mxl, your own copies, differ from bwv988.mxl and are not used.
#
# Tempo (quarter notes a minute) and velocity are goldberg_vrwt.sh's: starting points to adjust by ear.
# --level_by_velocity: the quieter velocities come out quieter too (64 peaks 6 dB under 78).
set -eo pipefail
cd "$(dirname "$0")"
DIAMOND=7
ONLY=()
while [ $# -gt 0 ]; do
    case $1 in
        --diamond) DIAMOND=$2; shift 2 ;;
        --diamond=*) DIAMOND=${1#*=}; shift ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        -*) echo "goldberg_diamond.sh: unknown option $1" >&2; exit 2 ;;
        *) ONLY+=("$1"); shift ;;
    esac
done
[[ $DIAMOND =~ ^[0-9]+$ ]] || { echo "goldberg_diamond.sh: --diamond takes a whole number, not '$DIAMOND'" >&2; exit 2; }
TAG=d${DIAMOND}h32
DIR=Archive/spring/$TAG
for m in "${ONLY[@]}"; do      # a typo stops here, not after an hour of other movements
    grep -qE "^G $m " "$0" || { echo "goldberg_diamond.sh: no movement $m (names: bwv988-00, bwv988v01 .. v30, v16a, v16b, bwv988-26)" >&2; exit 2; }
done
G() { local score=$1; shift
      if [ ${#ONLY[@]} -gt 0 ] && [[ ! " ${ONLY[*]} " == *" $score "* ]]; then return; fi
      .venv/bin/python spring_tuning.py --chorale "$score" --diamond "$DIAMOND" --harmony 32 --out_dir "$DIR" \
          | grep -E '^diamond|fold:|held|settled|changing|wrote|refuse'
      .venv/bin/python WreckingCrew_v2.py --chorale "$score" --numpy_dir "$DIR" --letter "$TAG" \
          --rubato_ms 25 --velocity_random 5 --accent 1 --ornaments --trill_glide 0.2 --level_by_velocity "$@"; }

G bwv988-00  --tempo  56 --velocity 62  # Aria
G bwv988v01  --tempo 100 --velocity 70  # Var. 1
G bwv988v02  --tempo  80 --velocity 66  # Var. 2
G bwv988v03  --tempo  80 --velocity 64  # Var. 3, canon at the unison (12/8)
G bwv988v04  --tempo 120 --velocity 70  # Var. 4 (3/8)
G bwv988v05  --tempo 126 --velocity 72  # Var. 5
G bwv988v06  --tempo  96 --velocity 66  # Var. 6, canon at the second (3/8)
G bwv988v07  --tempo  90 --velocity 68  # Var. 7, al tempo di giga (6/8)
G bwv988v08  --tempo 116 --velocity 72  # Var. 8
G bwv988v09  --tempo  72 --velocity 64  # Var. 9, canon at the third
G bwv988v10  --tempo 144 --velocity 70  # Var. 10, fughetta (2/2)
G bwv988v11  --tempo 108 --velocity 68  # Var. 11 (12/16)
G bwv988v12  --tempo  84 --velocity 66  # Var. 12, canon at the fourth
G bwv988v13  --tempo  60 --velocity 62  # Var. 13
G bwv988v14  --tempo 104 --velocity 72  # Var. 14
G bwv988v15  --tempo  40 --velocity 64  # Var. 15, canon at the fifth, G minor
G bwv988v16a --tempo  60 --velocity 68  # Var. 16, Ouverture: the 2/2 overture
G bwv988v16b --tempo 120 --velocity 72  # Var. 16, Ouverture: the 3/8 fughetta
G bwv988v17  --tempo 108 --velocity 70  # Var. 17
G bwv988v18  --tempo 120 --velocity 68  # Var. 18, canon at the sixth (2/2)
G bwv988v19  --tempo  90 --velocity 66  # Var. 19 (3/8)
G bwv988v20  --tempo 108 --velocity 72  # Var. 20
G bwv988v21  --tempo  96 --velocity 68  # Var. 21, canon at the seventh, G minor
G bwv988v22  --tempo 112 --velocity 68  # Var. 22, alla breve
G bwv988v23  --tempo 100 --velocity 72  # Var. 23
G bwv988v24  --tempo  96 --velocity 66  # Var. 24, canon at the octave (9/8)
G bwv988v25  --tempo  58 --velocity 60  # Var. 25, Adagio, G minor
G bwv988-26  --tempo  84 --velocity 70  # Var. 26 (your copy, with triplets)
G bwv988v27  --tempo  84 --velocity 66  # Var. 27, canon at the ninth (6/8)
G bwv988v28  --tempo  92 --velocity 70  # Var. 28
G bwv988v29  --tempo 100 --velocity 74  # Var. 29
G bwv988v30  --tempo  96 --velocity 68  # Var. 30, Quodlibet
