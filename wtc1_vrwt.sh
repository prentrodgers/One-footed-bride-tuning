#!/bin/bash
# The Well-Tempered Clavier, Book I (BWV 846-869), every prelude and fugue in Secor's vrwt.
#
# Scores: the Open Well-Tempered Clavier (MuseScore team, 2015, public domain), Scores/bwvNNNp.mxl
# and bwvNNNf.mxl.  2, 3 and 13 and Fugue 1 were downloaded singly; the rest came as one file a
# number (prelude-and-fugue-N-openwtc.mxl) and were cut with split_score.py, 18 Nov 2026, each
# piece checked note for note against its bars in the combined file.  Prelude 1 is bwv846p, the
# Open WTC's 35 bars, not the corpus's bwv846 (34 bars, another edition).  Only 24's prelude has repeats.
#
# Preludes quiet and slow, fugues louder and faster, each a different tempo (quarter notes a minute,
# so 12/8 at 60 is a dotted quarter at 40) and velocity.  --letter a names the files b849pa_vrwt_...,
# b849fa_vrwt_..., like the earlier b846fa.  --level_by_velocity makes the quieter ones quieter too.
# Starting points: adjust each before rendering.  Run one line at a time, or: bash wtc1_vrwt.sh
set -e
cd "$(dirname "$0")"
WC() { local bwv=$1; shift
       .venv/bin/python WreckingCrew_v2.py --chorale "$bwv" --letter a --temperament vrwt --velocity_random 5 \
       --accent 1 --ornaments --trill_glide 0.2 --level_by_velocity "$@"; }

WC bwv846p --tempo  60 --velocity 58 --rubato_ms 25  #  1 C major, prelude
WC bwv846f --tempo  72 --velocity 68 --rubato_ms 20  #  1 C major, fugue a 4
WC bwv847p --tempo  72 --velocity 60 --rubato_ms 25  #  2 C minor, prelude
WC bwv847f --tempo  84 --velocity 72 --rubato_ms 20  #  2 C minor, fugue a 3
WC bwv848p --tempo  80 --velocity 62 --rubato_ms 25  #  3 C# major, prelude (3/8)
WC bwv848f --tempo 100 --velocity 74 --rubato_ms 20  #  3 C# major, fugue a 3
WC bwv849p --tempo  54 --velocity 56 --rubato_ms 30  #  4 C# minor, prelude (6/4)
WC bwv849f --tempo  76 --velocity 70 --rubato_ms 20  #  4 C# minor, fugue a 5
WC bwv850p --tempo  72 --velocity 60 --rubato_ms 25  #  5 D major, prelude
WC bwv850f --tempo  66 --velocity 72 --rubato_ms 20  #  5 D major, fugue a 4 (French overture)
WC bwv851p --tempo  76 --velocity 58 --rubato_ms 25  #  6 D minor, prelude
WC bwv851f --tempo  80 --velocity 68 --rubato_ms 20  #  6 D minor, fugue a 3 (3/4)
WC bwv852p --tempo  64 --velocity 60 --rubato_ms 25  #  7 Eb major, prelude
WC bwv852f --tempo  96 --velocity 72 --rubato_ms 20  #  7 Eb major, fugue a 3
WC bwv853p --tempo  48 --velocity 54 --rubato_ms 30  #  8 Eb minor, prelude (3/2)
WC bwv853f --tempo  66 --velocity 66 --rubato_ms 20  #  8 D# minor, fugue a 3
WC bwv854p --tempo  60 --velocity 58 --rubato_ms 25  #  9 E major, prelude (12/8)
WC bwv854f --tempo 104 --velocity 74 --rubato_ms 20  #  9 E major, fugue a 3
WC bwv855p --tempo  64 --velocity 58 --rubato_ms 25  # 10 E minor, prelude (Presto from bar 23 at the same tempo)
WC bwv855f --tempo 120 --velocity 76 --rubato_ms 20  # 10 E minor, fugue a 2 (3/4)
WC bwv856p --tempo  72 --velocity 60 --rubato_ms 25  # 11 F major, prelude (12/8)
WC bwv856f --tempo  96 --velocity 72 --rubato_ms 20  # 11 F major, fugue a 3 (3/8, upbeat bar 0)
WC bwv857p --tempo  56 --velocity 58 --rubato_ms 25  # 12 F minor, prelude
WC bwv857f --tempo  76 --velocity 68 --rubato_ms 20  # 12 F minor, fugue a 4
WC bwv858p --tempo  54 --velocity 58 --rubato_ms 25  # 13 F# major, prelude (12/16)
WC bwv858f --tempo  88 --velocity 70 --rubato_ms 20  # 13 F# major, fugue a 3
WC bwv859p --tempo  64 --velocity 60 --rubato_ms 25  # 14 F# minor, prelude
WC bwv859f --tempo  72 --velocity 68 --rubato_ms 20  # 14 F# minor, fugue a 4 (6/4)
WC bwv860p --tempo  76 --velocity 62 --rubato_ms 25  # 15 G major, prelude
WC bwv860f --tempo 120 --velocity 76 --rubato_ms 20  # 15 G major, fugue a 3 (6/8)
WC bwv861p --tempo  54 --velocity 56 --rubato_ms 30  # 16 G minor, prelude
WC bwv861f --tempo  80 --velocity 70 --rubato_ms 20  # 16 G minor, fugue a 4
WC bwv862p --tempo  80 --velocity 62 --rubato_ms 25  # 17 Ab major, prelude (3/4)
WC bwv862f --tempo  88 --velocity 72 --rubato_ms 20  # 17 Ab major, fugue a 4
WC bwv863p --tempo  56 --velocity 56 --rubato_ms 30  # 18 G# minor, prelude (6/8)
WC bwv863f --tempo  72 --velocity 68 --rubato_ms 20  # 18 G# minor, fugue a 4
WC bwv864p --tempo  64 --velocity 60 --rubato_ms 25  # 19 A major, prelude
WC bwv864f --tempo  96 --velocity 72 --rubato_ms 20  # 19 A major, fugue a 3 (9/8)
WC bwv865p --tempo  72 --velocity 62 --rubato_ms 25  # 20 A minor, prelude (9/8)
WC bwv865f --tempo  92 --velocity 78 --rubato_ms 20  # 20 A minor, fugue a 4
WC bwv866p --tempo  76 --velocity 60 --rubato_ms 25  # 21 Bb major, prelude
WC bwv866f --tempo 108 --velocity 74 --rubato_ms 20  # 21 Bb major, fugue a 3 (3/4)
WC bwv867p --tempo  48 --velocity 54 --rubato_ms 30  # 22 Bb minor, prelude
WC bwv867f --tempo  66 --velocity 68 --rubato_ms 20  # 22 Bb minor, fugue a 5
# 23 and 24 were cut from prelude-and-fugue-23/24-openwtc.mxl on 19 Nov 2026 (868p 1-19, 868f 20-53;
# 869p 1-47, 869f 48-123), checked note for note.  WreckingCrew does not play repeat signs, so 24's
# prelude plays each half once; the line after it takes both repeats with --measures.
WC bwv868p --tempo  64 --velocity 60 --rubato_ms 25  # 23 B major, prelude
WC bwv868f --tempo  80 --velocity 72 --rubato_ms 20  # 23 B major, fugue a 4
WC bwv869p --tempo  60 --velocity 58 --rubato_ms 25  # 24 B minor, prelude (Andante), no repeats
# WC bwv869p --tempo  60 --velocity 58 --rubato_ms 25 --measures 1-17,1-47,18-47 --letter r  # with repeats
WC bwv869f --tempo  63 --velocity 68 --rubato_ms 20  # 24 B minor, fugue a 4 (Largo)
