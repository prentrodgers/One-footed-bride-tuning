#!/bin/bash
# The Well-Tempered Clavier, Book I (BWV 846-869), every prelude and fugue in Secor's vrwt.
#
# Scores: the Open Well-Tempered Clavier (MuseScore team, 2015, public domain), Scores/bwvNNNp.mxl
# and bwvNNNf.mxl.  2, 3 and 13 and Fugue 1 were downloaded singly; the rest came as one file a
# number (prelude-and-fugue-N-openwtc.mxl) and were cut with split_score.py, 18 Nov 2026, each
# piece checked note for note against its bars in the combined file.  Prelude 1 is bwv846p, the
# Open WTC's 35 bars, not the corpus's bwv846 (34 bars, another edition).  Only 24's prelude has repeats.
#
# Preludes quieter, fugues louder, each a different tempo (quarter notes a minute,
# so 12/8 at 60 is a dotted quarter at 40) and velocity.  --letter a names the files b849pa_vrwt_...,
# b849fa_vrwt_..., like the earlier b846fa.  --level_by_velocity makes the quieter ones quieter too.
# Tempos (23 Nov 2026): the median of four recordings (Gould, Richter, Landowska, Jarrett), each
# track's length in quarter notes divided by its time; see wtc1_tempos.tsv. "was" is the earlier guess.
# Starting points: adjust each before rendering.  Run one line at a time, or: bash wtc1_vrwt.sh
set -e
cd "$(dirname "$0")"
WC() { local bwv=$1; shift
       .venv/bin/python WreckingCrew_v2.py --chorale "$bwv" --letter a --temperament vrwt --velocity_random 5 \
       --accent 1 --ornaments --trill_glide 0.2 --level_by_velocity "$@"; }

WC bwv846p --tempo  64 --velocity 58 --rubato_ms 25  #  1 C major, prelude, was 60
WC bwv846f --tempo  58 --velocity 68 --rubato_ms 20  #  1 C major, fugue a 4, was 72
WC bwv847p --tempo  80 --velocity 60 --rubato_ms 25  #  2 C minor, prelude, was 72
WC bwv847f --tempo  75 --velocity 72 --rubato_ms 20  #  2 C minor, fugue a 3, was 84
WC bwv848p --tempo 122 --velocity 62 --rubato_ms 25  #  3 C# major, prelude (3/8), was 80
WC bwv848f --tempo 101 --velocity 74 --rubato_ms 20  #  3 C# major, fugue a 3, was 100
WC bwv849p --tempo  84 --velocity 56 --rubato_ms 30  #  4 C# minor, prelude (6/4), was 54
WC bwv849f --tempo 100 --velocity 70 --rubato_ms 20  #  4 C# minor, fugue a 5, was 76
WC bwv850p --tempo 119 --velocity 60 --rubato_ms 25  #  5 D major, prelude, was 72
WC bwv850f --tempo  62 --velocity 72 --rubato_ms 20  #  5 D major, fugue a 4 (French overture), was 66
WC bwv851p --tempo  70 --velocity 58 --rubato_ms 25  #  6 D minor, prelude, was 76
WC bwv851f --tempo  70 --velocity 68 --rubato_ms 20  #  6 D minor, fugue a 3 (3/4), was 80
WC bwv852p --tempo  68 --velocity 60 --rubato_ms 25  #  7 Eb major, prelude, was 64
WC bwv852f --tempo  87 --velocity 72 --rubato_ms 20  #  7 Eb major, fugue a 3, was 96
WC bwv853p --tempo  67 --velocity 54 --rubato_ms 30  #  8 Eb minor, prelude (3/2), was 48
WC bwv853f --tempo  60 --velocity 66 --rubato_ms 20  #  8 D# minor, fugue a 3, was 66
WC bwv854p --tempo 100 --velocity 58 --rubato_ms 25  #  9 E major, prelude (12/8), was 60
WC bwv854f --tempo 100 --velocity 74 --rubato_ms 20  #  9 E major, fugue a 3, was 104
WC bwv855p --tempo  72 --velocity 58 --rubato_ms 25  # 10 E minor, prelude (Presto from bar 23 at the same tempo; 72 averages the two), was 64
WC bwv855f --tempo 116 --velocity 76 --rubato_ms 20  # 10 E minor, fugue a 2 (3/4), was 120
WC bwv856p --tempo 112 --velocity 60 --rubato_ms 25  # 11 F major, prelude (12/8), was 72
WC bwv856f --tempo  79 --velocity 72 --rubato_ms 20  # 11 F major, fugue a 3 (3/8, upbeat bar 0), was 96
WC bwv857p --tempo  38 --velocity 58 --rubato_ms 25  # 12 F minor, prelude, was 56
WC bwv857f --tempo  55 --velocity 68 --rubato_ms 20  # 12 F minor, fugue a 4, was 76
WC bwv858p --tempo  60 --velocity 58 --rubato_ms 25  # 13 F# major, prelude (12/16), was 54
WC bwv858f --tempo  68 --velocity 70 --rubato_ms 20  # 13 F# major, fugue a 3, was 88
WC bwv859p --tempo 100 --velocity 60 --rubato_ms 25  # 14 F# minor, prelude, was 64
WC bwv859f --tempo  59 --velocity 68 --rubato_ms 20  # 14 F# minor, fugue a 4 (6/4), was 72
WC bwv860p --tempo  92 --velocity 62 --rubato_ms 25  # 15 G major, prelude, was 76
WC bwv860f --tempo 100 --velocity 76 --rubato_ms 20  # 15 G major, fugue a 3 (6/8), was 120
WC bwv861p --tempo  36 --velocity 56 --rubato_ms 30  # 16 G minor, prelude, was 54
WC bwv861f --tempo  52 --velocity 70 --rubato_ms 20  # 16 G minor, fugue a 4, was 80
WC bwv862p --tempo  99 --velocity 62 --rubato_ms 25  # 17 Ab major, prelude (3/4), was 80
WC bwv862f --tempo  54 --velocity 72 --rubato_ms 20  # 17 Ab major, fugue a 4, was 88
WC bwv863p --tempo  63 --velocity 56 --rubato_ms 30  # 18 G# minor, prelude (6/8), was 56
WC bwv863f --tempo  64 --velocity 68 --rubato_ms 20  # 18 G# minor, fugue a 4, was 72
WC bwv864p --tempo  81 --velocity 60 --rubato_ms 25  # 19 A major, prelude, was 64
WC bwv864f --tempo  95 --velocity 72 --rubato_ms 20  # 19 A major, fugue a 3 (9/8), was 96
WC bwv865p --tempo 108 --velocity 62 --rubato_ms 25  # 20 A minor, prelude (9/8), was 72
WC bwv865f --tempo  81 --velocity 78 --rubato_ms 20  # 20 A minor, fugue a 4, was 92
WC bwv866p --tempo  65 --velocity 60 --rubato_ms 25  # 21 Bb major, prelude, was 76
WC bwv866f --tempo  98 --velocity 74 --rubato_ms 20  # 21 Bb major, fugue a 3 (3/4), was 108
WC bwv867p --tempo  32 --velocity 54 --rubato_ms 30  # 22 Bb minor, prelude, was 48
WC bwv867f --tempo  72 --velocity 68 --rubato_ms 20  # 22 Bb minor, fugue a 5, was 66
# 23 and 24 were cut from prelude-and-fugue-23/24-openwtc.mxl on 19 Nov 2026 (868p 1-19, 868f 20-53;
# 869p 1-47, 869f 48-123), checked note for note.  WreckingCrew does not play repeat signs, so 24's
# prelude plays each half once; the line after it takes both repeats with --measures.
WC bwv868p --tempo  78 --velocity 60 --rubato_ms 25  # 23 B major, prelude, was 64
WC bwv868f --tempo  66 --velocity 72 --rubato_ms 20  # 23 B major, fugue a 4, was 80
WC bwv869p --tempo  64 --velocity 58 --rubato_ms 25  # 24 B minor, prelude (Andante), no repeats, was 60
# WC bwv869p --tempo  64 --velocity 58 --rubato_ms 25 --measures 1-17,1-47,18-47 --letter r  # with repeats, was 60
WC bwv869f --tempo  46 --velocity 68 --rubato_ms 20  # 24 B minor, fugue a 4 (Largo), was 63
