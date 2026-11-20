# Spring tuning

Notes on the work of 19–20 Nov 2026: why the WTC fugues needed a different tuner, what `spring_tuning.py`
does, the tonality-diamond springs tried on the Goldberg Aria, what is in `Archive/spring/`, the grace
notes, turns and arpeggios added to WreckingCrew_v2, and how to reproduce the renders.

## Why a new tuner

`Straw_man_tuning_v2.py` tunes each chord to its best ratios, then uses Viterbi to keep the lines as
steady as it can. That suits chorales, where a chord lasts long enough for its purity to be heard. In
the fugues the lines carry the music, a sonority lasts about a third of a beat, and half the time a
second, seventh or tritone is sounding. The best fugue tunings had whole steps from 119 to 267 cents,
a pitch class wandering up to 90 cents, and held notes retuned in mid-note. The lines sounded wrong.

`spring_tuning.py` turns the order round. It starts from a temperament (VRWT), where every line is
already right, and lets the chords pull notes toward just intervals only as far as the lines allow.

## How it works

**A pitch for every note, not a temperament.** The result is not 12 pitch classes but one cent value
for each note of the piece (399 in the Aria), held for the whole note, so a held note never bends.
Two F♯s in different bars may differ by a few cents; two sounding together never do (the fold,
below). VRWT is
only the starting point and the anchor: at `--harmony 0` every note sits on it exactly. The `.npy`
is laid out like the score (a row per voice, a column per time slot) and every slot under a note
holds that note's value. The report's "a pitch class moves" says how far one pitch class spreads.

All the pitches are found at once by minimising a total "pain" made of springs, each costing
`strength × (actual − wanted)²`. There are two families, pulling against each other.

**Line springs** (horizontal: one voice moving through time). A "line" is a voice as MuseScore engraved
it, one row of the array; the Aria has 7. The program knows nothing of themes: subject, countersubject
and free voice are treated alike, and each entry of a subject keeps VRWT's step sizes in its own key.

| Spring | Connects | Wants | Strength |
|---|---|---|---|
| Anchor | one note | its VRWT pitch | the note's length |
| Melody | a note and the next in its voice (within about a beat; repeated notes skipped) | the size that step has in VRWT | `--melody` (1) |
| Memory | a note and a later note of the same pitch class, in any voice, within about a bar | the same pitch | `--memory` (1), fading with the gap |

**Chord springs** (vertical: notes sounding together in different voices).

| Spring | Connects | Wants | Strength |
|---|---|---|---|
| Harmony | two notes a third, fourth, fifth, sixth or octave apart | the just interval (6/5, 5/4, 4/3, 3/2, 8/5, 5/3, 2/1) | `--harmony` × the time they overlap (octaves doubled) |
| Seventh | the notes of a major triad with its minor seventh, or a minor triad with its major sixth | 4:5:6:7 (seventh at 7/4) or its mirror (sixth at 12/7) | `--septimal` × `--harmony` × overlap |
| Diamond (`--diamond N`, replaces the two above) | any two notes sounding together | one ratio of the tonality diamond, chosen by the pair | `--harmony` × `((n+d)/5)^-p` × overlap |

Without `--diamond`, seconds, sevenths and tritones outside those seventh chords get no spring: a
passing note is placed by its line. Because every cost is a square, the minimum is a set of linear
equations, solved exactly in under a second per piece on fs1. There is no randomness and no cluster:
the same score and settings always give the same array.

The idea is John deLaubenfels's spring method (https://www.adaptune.com/spring_method.htm: vertical,
ground and horizontal springs, pain as the square of deviation). His page gives no targets or
strengths, so those here are this project's own. Differences: his held notes may move at a cost, his
strengths follow loudness, and he iterates; here held notes are fixed, strengths follow duration, and
the system is solved directly.

### The fold: one pitch per pitch class at a time (20 Nov)

Notes of the same pitch class that sound together, in any octave or voice, share one pitch: the
octave folding of `Straw_man_tuning_v2.py` (fold into one octave, merge duplicates, restore), done
inside the solve. Before each solve the notes are grouped: two notes of one pitch class that overlap
at all join a group, and so does a chain of overlaps (a held bass G and the G's that sound over it in
turn). Each group is one unknown. Nobody "wins": the shared pitch is solved with every spring on every
note of the group, so it lands where the chords and lines of all of them are best served. Correcting
afterwards would have had to pick one note's pitch and throw away what the other's springs had found.

Without the fold the splits were small with the diamond, whose octaves pull hard (1/1 is 6.25), and
audible with the old method:

| Array | longest split, no fold | with the fold | cost of the fold |
|---|---|---|---|
| Aria, `d15h32` | 0.7 cents, 22 of 96 quarters | 0 | none measurable |
| Aria, `h32s4` | 10.4 cents | 0 | thirds 0.0, steps within 1 cent |
| `bwv846f`, `h32s4` | 14.7 cents | 0 | thirds 0.0, half steps 61–129 instead of 59–128 |
| `bwv849f`, `h32s4` | 21.2 cents, 245 of 460 quarters | 0 | thirds 7.7 instead of 7.5, furthest note 38.5 instead of 35.9 |

`--fold` is the default; `--no-fold` gives each note its own pitch and reproduces the arrays of 19 Nov
exactly. The report line ends with "one pitch class split", the widest such split anywhere in the
piece, and the run prints how many notes were folded into another (74 of the Aria's 399).

### What h, s and the other dials do

- **h, `--harmony`**: how strong the chord springs are against the line springs, which are always 1.
  It is the tug of war. 0 gives plain VRWT; higher gives purer chords and less even lines. In the Aria
  (diamond 15): h 32 gives thirds 3.5 cents from just and whole steps 187–202; h 64 gives 2.5 and
  185–203.
- **s, `--septimal`**: the old method only. A multiplier on h for the seventh-chord springs alone:
  `h32s4` pulls toward 7/4 and 12/7 with 4 × 32. Ignored with `--diamond`.
- **`--pace auto`** does not override h; it rescales it. The chords pull with h × 0.5 ÷ the piece's
  ordinary note in quarters (0.5, an eighth, is Fugue 1's, where the dials were first set by ear). The
  Aria's ordinary note is a quarter, so its h 32 pulls as 16 would with `--pace off`; `bwv849f`'s is a
  half note, so h 32 pulls as 8. The anchors are scaled the same way, so only melody and memory keep
  full strength, and the memory window and the gap that still counts as one line stretch with the
  note length. Within one piece, h 64 is always twice h 32; across pieces, the same h gives about the
  same evenness. (The "pace:" line prints the conversion for the default harmony 2, not the h given.)
- **`--diamond N`**: which ratios are on offer (below). **`--exponent p`**: how h is shared among
  them. **`--width`**: how a pair chooses between them.

### The options

| Option | Default | What it does |
|---|---|---|
| `--chorale` | (required) | the score name, as for WreckingCrew_v2 (`bwv849f`, `bwv988-00`) |
| `--harmony` | 2 | pull of the chord springs against the line springs. 0 gives VRWT exactly |
| `--septimal` | 1 | pull of the seventh chords toward 7/4 and 12/7, as a share of `--harmony`. 0 turns them off. Not used with `--diamond` |
| `--diamond` | (off) | N: target every ratio of the tonality diamond of identities (N+1)/2 to N (15: 8 to 15) instead of the fixed table and `--septimal` |
| `--exponent` | 2 | with `--diamond`: a ratio n/d pulls with strength `((n+d)/5)^-p`, so 3/2 is 1 |
| `--width` | 15 | with `--diamond`: the width in cents of each ratio's well, for choosing between ratios |
| `--pace` | `auto` | measure note lengths against the piece's own ordinary note, so a slow piece is pulled no harder than a quick one. `off`: against an eighth note for every piece. A number: that note length in quarters |
| `--fold` | on | same-pitch-class notes sounding together share one pitch. `--no-fold`: each note its own, as on 19 Nov |
| `--limit` | 40 | no note may end more than this many cents from its equal-tempered pitch, so a note is never nearer its neighbour than itself. A note pulled past it has its anchor stiffened and the piece is solved again |
| `--reference` | `vrwt` | the temperament the anchors and melody springs come from |
| `--melody`, `--memory` | 1, 1 | the line springs |
| `--out_dir` | | write `<chorale>-opt.npy` and a `.txt` record of the settings there |
| `--sweep` | | print the trade-off for harmony 0.25 to 64, writing nothing |
| `--compare` | | report other tuning files beside it |

Each run prints a report line: thirds and fifths in cents from just, the range of half and whole steps,
how far a pitch class moves, how close the seventh chords come to 7/4 and 12/7, and the furthest note
from 12-TET, and the widest split of one pitch class sounding at two pitches. With `--diamond` it also prints how many rounds the pairs took to settle and which ratio
each interval chose, as shares of the time that interval sounds.

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
  pulls as 8 would, and its whole steps run 160 to 236. For Fugue 1, whose ordinary note is an eighth,
  nothing changes. 26 of the 44 pieces are unchanged by it.

## The diamond springs (20 Nov)

`--diamond N` replaces the fixed table and `--septimal` with every ratio of the tonality diamond of
identities (N+1)/2 to N (overtones up, undertones down, as `diamond_music_utils.build_all_ratios`
builds it), reduced to the octave. Only ratios within `--limit` of a 12-TET step are offered; the
others could only be reached by a note crossing into its neighbour's pitch class.

### Strength by n+d

Each ratio pulls with `((n+d)/5)^-p`. Dividing by 5 fixes 3/2 at 1 for every p, so raising p does not
make the simple ratios pull harder: it makes every ratio with n+d above 5 weaker (and only 1/1, n+d 2,
stronger), widening the gap. To keep the thirds' overall pull while raising p, raise h too.

| Ratio | n+d | p = 1 | p = 2 | p = 3 |
|---|---|---|---|---|
| 1/1 | 2 | 2.5 | 6.25 | 15.6 |
| 3/2 | 5 | 1 | 1 | 1 |
| 4/3 | 7 | 0.71 | 0.51 | 0.36 |
| 5/4 | 9 | 0.56 | 0.31 | 0.17 |
| 6/5, 7/4 | 11 | 0.45 | 0.21 | 0.094 |
| 9/8 | 17 | 0.29 | 0.087 | 0.025 |
| 16/15 | 31 | 0.16 | 0.026 | 0.0042 |

### Choosing one ratio per pair

Two square-law springs on one pair add up to one spring toward their weighted mean: a minor third
pulled toward both 6/5 (316) and 7/6 (267) would sit at about 293, which is neither. So each pair
chooses ONE ratio. The rule is not the cheapest spring (weight × distance²): a complex ratio's weak
spring costs almost nothing however far away it is, so every pair would drift to the most complex
ratio on offer. Instead each ratio is a well whose depth is its strength and whose shape is a bell
curve `--width` cents wide, and a pair takes the deepest well where it stands. Simple ratios have wide
catchment; complex ones catch only what lands nearly on them. The piece is solved, every pair chooses
again, and so on until none changes its mind (at most 40 rounds); the Aria settles in 3 or 4.

### What each limit offers

Ratios within 40 cents of a step; each limit adds these to the one above.

| N | Ratios | Added |
|---|---|---|
| 5 | 7 | 1/1 6/5 5/4 4/3 3/2 8/5 5/3 |
| 7 | 13 | 8/7 7/6 7/5 10/7 12/7 7/4 |
| 9 | 19 | 10/9 9/8 9/7 14/9 16/9 9/5 |
| 11 | 23 | 11/10 14/11 11/7 20/11 |
| 13 | 31 | 14/13 13/12 13/11 18/13 13/9 22/13 24/13 13/7 |
| 15 | 37 | 16/15 15/14 15/11 22/15 28/15 15/8 |
| 17 | 51 | 14 ratios of 17 |
| 19 | 65 | 14 ratios of 19 |
| 21 | 77 | 12 ratios of 21 or 7/3 |

What to expect, before listening:

- **5**: the old 5-limit table; seconds, sevenths and tritones unsprung.
- **7**: 7/4 is the only minor seventh on offer, so every minor seventh is pulled to it: septimal
  sevenths without a chord rule. But 8/7 (231) is the only major second, so clashing whole steps are
  pulled wide, if weakly (0.11).
- **9**: brings 9/8 and 9/5, which the Aria chose at 15; probably much like 15.
- **11–15**: mostly ratios with large n+d, weak springs whose wells rarely win.
- **17 and up**: little change expected.

The 11-limit neutral ratios (11/8, 11/9, 12/11...) sit about 50 cents from any key and are never offered.

### The Aria

`Scores/bwv988-00.mxl` is bars 1–32 of `bwv988`, cut with `split_score.py` (445 notes, checked against
the full score), because WreckingCrew_v2 plays `--measures` only with `--temperament`, not with a
tuning array.

At diamond 15, harmony 32 the pairs chose 1/1, 3/2, 4/3, 5/4, 6/5, 5/3 and 8/5 throughout (2% of minor
sixths 11/7), 9/5 for every minor seventh, 15/8 for the major sevenths, 9/8 (86%) or 10/9 for major
seconds, 15/14 (52%) or 16/15 for minor seconds, 7/5 (68%) or 10/7 for tritones. 7/4 was never chosen:
at 31 cents below 12-TET its well is too far from where the lines hold a seventh, and 9/5 (18 above)
wins. The Aria has only about 4 quarters of dominant seventh. For septimal sevenths try `--diamond 7`,
a wider `--width` (25), or a bonus on 7/4 in a recognised seventh chord (not built).

| Aria | thirds/sixths from just | fifths | whole steps | a pitch class moves (avg / max) |
|---|---|---|---|---|
| vrwt | 9.8 | 3.5 | 195–202 | 0 |
| `d15h32` (diamond 15, harmony 32) | 3.5 | 2.1 | 187–202 | 8.4 / 13.5 |
| `d15h64` | 2.5 | 1.7 | 185–203 | 10.8 / 18.7 |
| `h32s4` (the WTC method) | 2.8 | 2.4 | 173–230 | 28.8 / 42.0 |

The diamond gets thirds nearly as pure as `h32s4` while moving the lines a third as much. No note
needed `--limit`; the furthest is 18 cents from 12-TET.

```
python spring_tuning.py --chorale bwv988-00 --diamond 15 --harmony 32 --out_dir Archive/spring/d15h32
python WreckingCrew_v2.py --chorale bwv988-00 --numpy_dir Archive/spring/d15h32 --letter d15h32 --tempo 56 \
    --velocity 62 --rubato_ms 25 --velocity_random 5 --accent 1 --ornaments --trill_glide 0.2 --level_by_velocity
```

To try another limit, change N and the directory and letter together (`--diamond 7 ... d7h32`). The
renders are `Uploads/b988-00d15h32_d01_48_t056.mp3` (with the fold, grace notes, turn and arpeggio,
20 Nov) and `b988-00d15h64_d01_48_t056.mp3` (made before all three; its array has since been remade).

## Archive/spring/

The directory name is the recipe: `h32s4` is `--harmony 32 --septimal 4`; `d15h32` is
`--diamond 15 --harmony 32` (exponent 2 and width 15, the defaults).

| Directory | Pieces | Made with | Notes |
|---|---|---|---|
| **`h32s4`** | **all 44 preludes and fugues of WTC I Nos. 1–22, and the Aria** | `--harmony 32 --septimal 4`, pace auto, limit 40, no fold (made before it; remake with the fold if used again) | Every array matches its score exactly; the furthest note is 39.1 cents from 12-TET |
| **`d15h32`** | `bwv988-00` (the Aria) | `--diamond 15 --harmony 32`, exponent 2, width 15, pace auto, limit 40, fold | remade with the fold, 20 Nov |
| `d15h64` | `bwv988-00` | as `d15h32`, harmony 64 | remade with the fold |
| `h2`, `h8`, `h32` | `bwv846f`, `bwv847f` | harmony 2, 8, 32; no seventh springs, no pace, no limit | the first experiment |
| `h2s1`, `h2s4`, `h2s16` | `bwv846f`, `bwv847f` | harmony 2, septimal 1, 4, 16; no pace, no limit | seventh springs at low harmony |
| `h32s0.25`, `h32s1` | `bwv846f`, `bwv847f` | harmony 32, septimal 0.25, 1; no pace, no limit | |
| `h16s4`, `h8s4`, `h4s4` | `bwv849f` | harmony 16, 8, 4, septimal 4, limit 40, no pace | lower harmony for the slow C♯ minor fugue |
| `h32s4pace` | `bwv849f` | as `h32s4` | the first paced array; identical to `h32s4/bwv849f` now |

Fugue 1's array in `h32s4` (`b846fh32s4_d01_58_t058.mp3`, the one preferred by ear) is the same with
and without pace and limit, so the early render still stands for it. Eighteen pieces in `h32s4` were
remade when pace became the default: `bwv846p 847p 849p 849f 850f 852p 853p 853f 854p 855p 855f 856p
857p 857f 859p 859f 860p 867f`. An mp3 of any of those rendered from `h32s4` before 19 Nov 14:04 used
the older array. Adding `--diamond` and the fold left the old method untouched: re-running it with
`--no-fold` reproduces the committed arrays to within 0.0000002 cents. Every directory but `d15h32` and
`d15h64` was made without the fold; a `.txt` with no `fold:` line means no fold.

Each `.npy` has a `.txt` beside it recording every setting, including the pace it used (`pace: 2.0`
for `bwv849f`) and, for the diamond, `diamond`, `exponent` and `width`.

## Reproducing a render

Two steps: make the array, then play it.

```
python spring_tuning.py --chorale bwv849f --harmony 32 --septimal 4 --no-fold --out_dir Archive/spring/h32s4
python WreckingCrew_v2.py --chorale bwv849f --tempo 90 --numpy_dir Archive/spring/h32s4 --letter h32s4 \
    --velocity_random 5 --accent 1 --ornaments --trill_glide 0.2 --rubato_ms 25 --velocity 64
```

The first line is already done for all 44 pieces, so only the second is needed. Re-running the first
gives the same array exactly (`--no-fold`, as they were made; without it the fold is applied). For any other piece, change `bwv849f` in both lines.

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
| `--ornaments` | (on by default) | trills, mordents, turns and grace notes played as pitch steps (below) |
| `--trill_glide` | 0.2 | a fifth of each trill note spent sliding to the next |
| `--arpeggio` | `down` (default) | chords under an arpeggio sign rolled top to bottom (below) |

**Loudness:** `--velocity` alone changes the timbre, not the level. Every render is normalised to the
same peak (−1 dB), so velocity 64 sounds darker but just as loud as 78. To make the quieter velocity
quieter as well, add `--level_by_velocity`: 64 then peaks about 6 dB down, at half the amplitude.

## Ornaments and arpeggios in WreckingCrew_v2 (20 Nov)

Until 20 Nov, grace notes and turns were never played, in any render: not randomly, but always, by
design. In the Aria that left bars 2, 4, 6, 7 and 8 bare; the ornament heard near bar 6 was the
mordent on E5 at the end of bar 5. Now, under `--ornaments` (the default):

- **Grace notes** are taken on the beat at their written value, out of the main note's time, as
  appoggiaturas: the Aria's bar 2 plays A5 G5 F♯5 E5 D5 in sixteenths, bar 6 the same from E5. Like
  mordents they are pitch steps on the main note's single strike, so no tuning array changes. A grace
  a half or whole step away is tuned 16/15 or 9/8 from the tuned main note (the temperament's step
  under `--temperament`); a wider one gets the 12-TET interval. Graces that would take more than half
  the main note are shortened to fit in half. A grace before a note with a mordent plays both in
  order (bar 8: F♯4 for an eighth, then G4 with its mordent). Graces before a chord go to the chord
  note nearest them.
- **Turns**: upper neighbour, note, lower neighbour, note, the first three each a trill note long (or a
  quarter of the note if shorter); an inverted turn starts below. The Aria's bar 6 F♯5 plays G5 F♯5
  E5 F♯5.
- **Arpeggio signs** (the wavy vertical line before a chord) roll the chord: separate strikes,
  `--arpeggio_ms` (50) apart, each note still ending where it would. `--arpeggio down` (the default)
  rolls from the top, as Glenn Gould plays the Aria's bar 11 (G5 E5 B4 G4); `up` from the bottom, as
  Simone Dinnerstein does; `off` strikes the chord together. A sign the score marks up or down keeps
  its own direction. A sign on one staff rolls every note of that staff on that beat, whichever voice
  it is in; a sign across both staves rolls all the notes it spans.

The Aria has 27 grace notes, 9 mordents, 8 inverted mordents, 1 turn and 1 arpeggio. Any WTC or
Goldberg render made before 20 Nov lacks the grace notes, turns and rolls.

## The goal

**Decision, 19 Nov:** the Well-Tempered Clavier is rendered in plain VRWT (`wtc1_vrwt.sh`), since
exploring the temperament's key colours was Bach's point. The spring tuning, and now the diamond
springs, are for his other keyboard works, starting with the Goldberg Variations.

The aim for the WTC is Sviatoslav Richter's choices (Books I and II): tempo and touch from his
recording, with the slow fugues softer. The tempo and velocity of each piece are set by hand per
render; `wtc1_vrwt.sh` holds a first set for all 48 pieces of Book I. Prelude 24's repeats are on a
commented `--measures 1-17,1-47,18-47` line.

## Files

All committed: 10f773e (19 Nov), 6f2c19b (20 Nov: diamond, ornaments, arpeggio) and the fold after it.

| File | What |
|---|---|
| `spring_tuning.py` | the spring tuner, with `--diamond`, `--exponent`, `--width`, `--fold` |
| `Archive/spring/` | the arrays above |
| `WreckingCrew_v2.py` | grace notes, turns, `--arpeggio`, `--arpeggio_ms`; the refusal of a mismatched array counts the chords |
| `test_wreckingcrew_v2.py` | 43 tests, five of them for the graces, turns and arpeggio |
| `split_score.py`, `wtc1_vrwt.sh`, `Scores/bwv8*[pf].mxl` | the Book I scores (Nos. 1–24) and render list |
| `Scores/bwv988-00.mxl` | the Goldberg Aria on its own |
| `goldberg_vrwt.sh` | not committed: has stray `# ` inside ten comments, not made here |
