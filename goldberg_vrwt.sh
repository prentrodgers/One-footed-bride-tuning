#!/bin/bash
# The Goldberg Variations (Scores/bwv988.mxl), every movement once through without its repeats, in Secor's vrwt.
#
# bwv988.mxl holds each movement once, with repeat signs (it does not write the repeats out the way
# bwv988-a.mxl does), so --measures is just the movement's bars. Five movements have first and second
# endings: those leave the first ending out and play the second (Var. 2, 4, 6, 16, 25), so the music
# goes straight on into the next half. Bars checked note by note against the score, 18 Nov 2026.
#
# --letter=-NNa names the files b988-NNa_vrwt_d.._t...mp3, like the earlier b988-25a and b988-26a
# (the = is needed: argparse would read a bare -15a as an option). The Quodlibet keeps qa.
# Tempo (quarter notes a minute) and velocity are starting points: faster movements louder, slower
# ones quieter, as with Var. 15 (40, 64) and Var. 21 (96, 68). Adjust each before rendering.
#
# Var. 16 is two renders, -16a the 2/2 overture and -16b the 3/8 fughetta, each at its own tempo; play
# them back to back. Var. 1's right hand runs onto the bass staff in bar 36, so its bar there is short:
# --measures lays every bar out at its longest hand, as the full score does (fixed 18 Nov). The Aria da capo (bars 959-990) is the Aria again: reuse it.
#
# --level_by_velocity: the quieter velocities come out quieter too (64 peaks 6 dB under 78).
# Run one line at a time, or the whole file: bash goldberg_vrwt.sh
set -e
cd "$(dirname "$0")"
WC() { .venv/bin/python WreckingCrew_v2.py --chorale bwv988 --temperament vrwt --velocity_random 5 --accent 1 \
       --ornaments --trill_glide 0.2 --level_by_velocity "$@"; }

WC --letter=-aa  --measures 1-32                     --tempo  56 --velocity 62 --rubato_ms 25  # Aria
WC --letter=-01a --measures 33-64                    --tempo 100 --velocity 70 --rubato_ms 20  # Var. 1
WC --letter=-02a --measures 65-79,81-96,98           --tempo  80 --velocity 66 --rubato_ms 20  # Var. 2
WC --letter=-03a --measures 99-114                   --tempo  80 --velocity 64 --rubato_ms 25  # Var. 3, # canon at the unison (12/8)
WC --letter=-04a --measures 115-129,131-146,148      --tempo 120 --velocity 70 --rubato_ms 20  # Var. 4 (3/# 8)
WC --letter=-05a --measures 149-180                  --tempo 126 --velocity 72 --rubato_ms 20  # Var. 5
WC --letter=-06a --measures 181-195,198-213,216      --tempo  96 --velocity 66 --rubato_ms 20  # Var. 6, # canon at the second (3/8)
WC --letter=-07a --measures 217-248                  --tempo  90 --velocity 68 --rubato_ms 20  # Var. 7, # al tempo di giga (6/8)
WC --letter=-08a --measures 249-280                  --tempo 116 --velocity 72 --rubato_ms 20  # Var. 8
WC --letter=-09a --measures 281-296                  --tempo  72 --velocity 64 --rubato_ms 25  # Var. 9, # canon at the third
WC --letter=-10a --measures 297-328                  --tempo 144 --velocity 70 --rubato_ms 20  # Var. 10, # fughetta (2/2)
WC --letter=-11a --measures 329-360                  --tempo 108 --velocity 68 --rubato_ms 20  # Var. 11 # (12/16)
WC --letter=-12a --measures 361-392                  --tempo  84 --velocity 66 --rubato_ms 20  # Var. 12, # canon at the fourth
WC --letter=-13a --measures 393-424                  --tempo  60 --velocity 62 --rubato_ms 25  # Var. 13
WC --letter=-14a --measures 425-456                  --tempo 104 --velocity 72 --rubato_ms 20  # Var. 14
WC --letter=-15a --measures 457-488                  --tempo  40 --velocity 64 --rubato_ms 25  # Var. 15, canon at the fifth, G minor
WC --letter=-16a --measures 489-504                  --tempo  60 --velocity 68 --rubato_ms 25  # Var. 16, Ouverture: the 2/2 overture
WC --letter=-16b --measures 505-535,538              --tempo 120 --velocity 72 --rubato_ms 20  # Var. 16, Ouverture: the 3/8 fughetta
WC --letter=-17a --measures 539-570                  --tempo 108 --velocity 70 --rubato_ms 20  # Var. 17
WC --letter=-18a --measures 571-602                  --tempo 120 --velocity 68 --rubato_ms 20  # Var. 18, canon at the sixth (2/2)
WC --letter=-19a --measures 603-634                  --tempo  90 --velocity 66 --rubato_ms 20  # Var. 19 (3/8)
WC --letter=-20a --measures 635-666                  --tempo 108 --velocity 72 --rubato_ms 20  # Var. 20
WC --letter=-21a --measures 667-682                  --tempo  96 --velocity 68 --rubato_ms 20  # Var. 21, canon at the seventh, G minor
WC --letter=-22a --measures 683-714                  --tempo 112 --velocity 68 --rubato_ms 20  # Var. 22, alla breve
WC --letter=-23a --measures 715-746                  --tempo 100 --velocity 72 --rubato_ms 20  # Var. 23
WC --letter=-24a --measures 747-778                  --tempo  96 --velocity 66 --rubato_ms 20  # Var. 24, canon at the octave (9/8)
WC --letter=-25a --measures 779-793,795-810,812      --tempo  58 --velocity 60 --rubato_ms 30  # Var. 25, Adagio, G minor
# Var. 26 from its own score: bwv988.mxl writes the 18/16 hand as 18 plain sixteenths (4.5 beats, no
# triplets) against the other hand's 3/4, so every bar is half as long again and the 3/4 hand stops for
# 1.5 beats in each (1:53 at 84 instead of 1:14). No choice of bars fixes that; Scores/bwv988-26.mxl,
# your MuseScore 3 copy with real triplets, is right.
WC --chorale bwv988-26 --letter a                    --tempo  84 --velocity 70 --rubato_ms 20  # Var. 26
WC --letter=-27a --measures 845-876                  --tempo  84 --velocity 66 --rubato_ms 20  # Var. 27, canon at the ninth (6/8)
WC --letter=-28a --measures 877-908                  --tempo  92 --velocity 70 --rubato_ms 20  # Var. 28
WC --letter=-29a --measures 909-940                  --tempo 100 --velocity 74 --rubato_ms 20  # Var. 29
WC --letter=qa   --measures 941-958                  --tempo  96 --velocity 68 --rubato_ms 20  # Var. 30, Quodlibet
