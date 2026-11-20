# Spring tuning for the Well-Tempered Clavier

Notes on the work of 19 Nov 2026: why the fugues needed a different tuner, what `spring_tuning.py` does,
what is in `Archive/spring/`, and how to reproduce the renders.

## Why a new tuner

`Straw_man_tuning_v2.py` tunes each chord to its best ratios, then uses Viterbi to keep the lines as
steady as it can. That suits chorales, where a chord lasts long enough for its purity to be heard. In
the fugues the lines carry the music, a sonority lasts about a third of a beat, and half the time a
second, seventh or tritone is sounding. The best fugue tunings had whole steps from 119 to 267 cents,
a pitch class wandering up to 90 cents, and held notes retuned in mid-note. The lines sounded wrong.

`spring_tuning.py` turns the order round. It starts from a temperament (VRWT), where every line is
already right, and lets the chords pull notes toward just intervals only as far as the lines allow.

## How it works

Every note gets one pitch, so a held note never moves. All the pitches are found at once by
minimising a total "pain" made of springs, each costing `strength × (actual − wanted)²`:

| Spring | Connects | Wants | Strength |
|---|---|---|---|
| Anchor | one note | its VRWT pitch | the note's length |
| Harmony | two notes sounding together a third, fourth, fifth, sixth or octave apart | the just interval (6/5, 5/4, 4/3, 3/2, 8/5, 5/3, 2/1) | `--harmony` × the time they overlap (octaves doubled) |
| Seventh | the notes of a major triad with its minor seventh, or a minor triad with its major sixth | 4:5:6:7 (seventh at 7/4) or its mirror (sixth at 12/7) | `--septimal` × `--harmony` × overlap |
| Melody | a note and the next in its line | the size that step has in VRWT | `--melody` (1) |
| Memory | a note and a later note of the same pitch class within about a bar | the same pitch | `--memory` (1), fading with the gap |

Seconds, sevenths and tritones outside those seventh chords get no spring: a passing note is placed by
its line. Because every cost is a square, the minimum is a set of linear equations, solved exactly in
under a second per piece on fs1. There is no randomness and no cluster: the same score and settings
always give the same array.

The idea is John deLaubenfels's spring method (https://www.adaptune.com/spring_method.htm: vertical,
ground and horizontal springs, pain as the square of deviation). His page gives no targets or
strengths, so those here are this project's own. Differences: his held notes may move at a cost, his
strengths follow loudness, and he iterates; here held notes are fixed, strengths follow duration, and
the system is solved directly.

### The options

| Option | Default | What it does |
|---|---|---|
| `--chorale` | (required) | the score name, as for WreckingCrew_v2 (`bwv849f`) |
| `--harmony` | 2 | pull toward just intervals. 0 gives VRWT exactly; higher buys purer chords and less even steps |
| `--septimal` | 1 | pull of the seventh chords toward 7/4 and 12/7, as a share of `--harmony`. 0 turns them off |
| `--pace` | `auto` | measure note lengths against the piece's own ordinary note, so a slow fugue is pulled no harder than a quick one. `off`: against an eighth note for every piece. A number: that note length in quarters |
| `--limit` | 40 | no note may end more than this many cents from its equal-tempered pitch, so a note is never nearer its neighbour than itself. A note pulled past it has its anchor stiffened and the piece is solved again |
| `--reference` | `vrwt` | the temperament the anchors and melody springs come from |
| `--melody`, `--memory` | 1, 1 | the line springs |
| `--out_dir` | | write `<chorale>-opt.npy` and a `.txt` record of the settings there |
| `--sweep` | | print the trade-off for harmony 0.25 to 64, writing nothing |
| `--compare` | | report other tuning files beside it |

Each run prints a report line: thirds and fifths in cents from just, the range of half and whole steps,
how far a pitch class moves, how close the seventh chords come to 7/4 and 12/7, and the furthest note
from 12-TET.

### Three things learned on the way

- **Higher harmony clanged until the sevenths had springs.** Without them, purifying the thirds of a
  seventh chord dragged the unsprung seventh to odd sizes (minor sevenths from 186 to 230 cents at
  harmony 32). The seventh springs fix that.
- **`--limit` (default 40).** At harmony 32 a few notes in `bwv849f` and `bwv852p` were pulled 51 to 55
  cents from 12-TET, nearer the next semitone than their own. WreckingCrew_v2 takes such a note for a
  wrong note and refuses the array without `--force`. The limit stops this; no array needs `--force`.
- **`--pace auto` (the default).** Harmony and anchor springs grow with note length and the melody
  springs do not, so the same `--harmony` pulled a fugue in half notes four times as hard as one in
  eighths. `bwv849f` came out with whole steps from 150 to 257 cents. With `--pace auto` its harmony 32
  pulls as 8 would (its ordinary note is a half note), and its whole steps run 160 to 236. For Fugue 1,
  whose ordinary note is an eighth, nothing changes. 26 of the 44 pieces are unchanged by it.

## Archive/spring/

The directory name is the recipe: `h32s4` is `--harmony 32 --septimal 4`.

| Directory | Pieces | Made with | Notes |
|---|---|---|---|
| **`h32s4`** | **all 44 preludes and fugues of Nos. 1–22** | `--harmony 32 --septimal 4`, pace auto, limit 40 | **the current set.** Every array matches its score exactly; the furthest note is 39.1 cents from 12-TET |
| `h2`, `h8`, `h32` | `bwv846f`, `bwv847f` | harmony 2, 8, 32; no seventh springs, no pace, no limit | the first experiment |
| `h2s1`, `h2s4`, `h2s16` | `bwv846f`, `bwv847f` | harmony 2, septimal 1, 4, 16; no pace, no limit | seventh springs at low harmony |
| `h32s0.25`, `h32s1` | `bwv846f`, `bwv847f` | harmony 32, septimal 0.25, 1; no pace, no limit | |
| `h16s4`, `h8s4`, `h4s4` | `bwv849f` | harmony 16, 8, 4, septimal 4, limit 40, no pace | lower harmony for the slow C♯ minor fugue |
| `h32s4pace` | `bwv849f` | as `h32s4` | the first paced array; identical to `h32s4/bwv849f` now |

Fugue 1's array in `h32s4` (`b846fh32s4_d01_58_t058.mp3`, the one preferred by ear) is the same with
and without pace and limit, so the early render still stands for it. Eighteen pieces in `h32s4` were
remade when pace became the default: `bwv846p 847p 849p 849f 850f 852p 853p 853f 854p 855p 855f 856p
857p 857f 859p 859f 860p 867f`. An mp3 of any of those rendered from `h32s4` before 19 Nov 14:04 used
the older array.

Each `.npy` has a `.txt` beside it recording every setting, including the pace it used (`pace: 2.0`
for `bwv849f`).

## Reproducing a render

Two steps: make the array, then play it.

```
python spring_tuning.py --chorale bwv849f --harmony 32 --septimal 4 --out_dir Archive/spring/h32s4
python WreckingCrew_v2.py --chorale bwv849f --tempo 90 --numpy_dir Archive/spring/h32s4 --letter h32s4 \
    --velocity_random 5 --accent 1 --ornaments --trill_glide 0.2 --rubato_ms 25 --velocity 64
```

The first line is already done for all 44 pieces, so only the second is needed. Re-running the first
gives the same array exactly. For any other piece, change `bwv849f` in both lines.

### The WreckingCrew_v2 options in that command

| Option | Value | What it does |
|---|---|---|
| `--chorale` | `bwv849f` | the score: Fugue 4, C♯ minor, a 5 |
| `--tempo` | 90 | quarter notes a minute (5:10 for this fugue) |
| `--numpy_dir` | `Archive/spring/h32s4` | where the tuning array is |
| `--letter` | `h32s4` | goes into the file name: `b849fh32s4_d05_14_t090`. A new letter keeps an earlier render from being overwritten |
| `--velocity` | 64 | the Bösendorfer layer: 64 plays the velocity-39 recordings, a softer timbre. 60 or less: 25; 66: 47; 68: 63; 70: 78; 72: 85; 74: 99; 76: 113; 78 and up: 127 |
| `--velocity_random` | 5 | each note's velocity varies from base−5 to base+4, never above a downbeat |
| `--accent` | 1 | the first note of every bar 1 dB louder |
| `--rubato_ms` | 25 | each onset up to 25 ms late, chords staying together |
| `--ornaments` | (on by default) | trills and mordents played as pitch steps |
| `--trill_glide` | 0.2 | a fifth of each trill note spent sliding to the next |

**Loudness:** `--velocity` alone changes the timbre, not the level. Every render is normalised to the
same peak (−1 dB), so velocity 64 sounds darker but just as loud as 78. To make the quieter velocity
quieter as well, add `--level_by_velocity`: 64 then peaks about 6 dB down, at half the amplitude.

## The goal

**Decision, 19 Nov:** the Well-Tempered Clavier is rendered in plain VRWT (`wtc1_vrwt.sh`), since
exploring the temperament's key colours was Bach's point. The spring tuning is kept for his other
keyboard works.

The aim is Sviatoslav Richter's choices in the Well-Tempered Clavier (Books I and II), in new tunings:
tempo and touch from his recording, with the slow fugues softer. The tempo and velocity of each piece
are set by hand per render; `wtc1_vrwt.sh` holds a first set for Book I in plain VRWT, which can be
pointed at the spring arrays with `--numpy_dir Archive/spring/h32s4` in place of `--temperament vrwt`.

## Files

| File | State |
|---|---|
| `spring_tuning.py` | new, uncommitted |
| `Archive/spring/` | new, uncommitted |
| `WreckingCrew_v2.py` | the refusal message for a mismatched array now counts the chords instead of rounding to "100%"; uncommitted |
| `split_score.py`, `wtc1_vrwt.sh`, `Scores/bwv8*[pf].mxl` | the Book I scores and render list; uncommitted |
| Nos. 23 and 24 (BWV 868, 869) | split into `Scores/bwv868p/f.mxl` and `bwv869p/f.mxl`; no spring arrays made |
