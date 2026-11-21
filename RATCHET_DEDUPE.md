# A faster ratchet: chord deduplication and a vectorised Viterbi step

21 November 2026. Commit `945ba6c`, plus the launcher and cluster fixes listed at the end.

`ray-ratchet.sh` tunes every chorale over a grid of 24 cells (limit_max × tolerance × ratio).
It re-runs each cell until the keep-previous ratchet stops accepting new tunings. A 12-chorale run
took 3–4 hours of the cluster at about 950 W. These two changes cut a pass from about 330 s to
60–100 s on bwv261, and the tunings came out smoother.

## What one pass does, and where the time went

Each pass of a cell is one run of `Straw_man_tuning_v2.py --use_viterbi`, through `grid_search.sh`:

1. **Candidates.** For every time slot of the chorale (bwv261: 308 sixteenth-note slots),
   `viterbi_optimization.generate_k_candidates` anneals the chord up to 30 times. It uses 4 rolls
   × up to 1000 SA iterations each time, polishes each result and keeps the 15 best distinct
   tunings. It also offers the polished 12-TET chord, plus the slot's tuning from the previous pass
   (the *incumbent*, which is what makes the ratchet converge).
2. **Path.** `viterbi_select_path` runs one phrase at a time. It chooses one candidate per slot, and
   one pitch-class-preserving transposition of it, minimising vertical cost (chord score) plus
   horizontal cost (pitch-class jumps between neighbouring slots, with a quadratic surcharge above
   10 ¢).
3. **Continuity** enforcement and the keep/discard comparison with the saved tuning.

A profiled pass of bwv261 (t3_r1.25_lm17, 4 workers):

| Stage | Time |
|---|---:|
| Candidates (4 workers) | 278 s |
| Viterbi path (one core, 3.7 million transition-cost calls) | ~69 s |
| Everything else | ~1 s |

## Change 1: `--dedupe_chords`

bwv261's 308 slots hold only **85 distinct chords**. A chord sounding for a half note fills
8 slots, and every slot got its own full annealing run. So 72% of the candidate work repeated work
already done.

In the parallel path, which the ratchet always uses (`--viterbi_workers 4`), a slot's candidates
already depended only on its own notes. `_parallel_candidate_worker` starts every chord from zeros,
not from the previous chord. So candidates for two slots holding the same chord are draws from the
same distribution. With `dedupe` (`hierarchical_viterbi_optimization(..., dedupe=True)`,
`Straw_man_tuning_v2.py --dedupe_chords`, on in `grid_search.sh`):

- the chords are grouped by their sounding 12-TET notes, voice by voice;
- each distinct chord is annealed once, as the first slot that holds it;
- every slot holding it gets that same candidate list, and then **its own incumbent** is added,
  exactly as `generate_k_candidates` would. So the trellis still contains the previous pass's path,
  and a pass can still only move the piece forward.

The candidate stage drops from 308 annealing jobs to 85.

### Why this works where the old dedupe did not

The earlier attempt, `compress_chorale` / `decompress_chorale` in `adaptive_tuning_util.py`, tuned
each distinct chord **once, to one tuning**, and copied that tuning back to every slot holding the
chord. A chord was then identical every time it came back, whatever came before or after it. The
gap between neighbouring chords was never part of the choice, so the gaps were wherever they fell.

The new dedupe shares the **menu**, not the meal. Each distinct chord gets 15–17 candidate tunings,
and the Viterbi pass still chooses per slot, in order. A chord can take one candidate before a
cadence and another after it, and each candidate can be transposed by whole cents without changing
its pitch classes. That's how the path keeps the gaps small.

### Where the order of the chords still matters

The **annealing** no longer needs the chords in score order: a chord's candidates don't depend on
where it sits. That's why each chord can be annealed once and its slots handed the result.

The **Viterbi pass** still needs the order, and it is the only place it is needed. Its horizontal
cost compares each slot with the one before it, and phrases are cut at the fermatas, so it walks
the chorale exactly as `stream_to_midi_array` lays it out from music21 or MusicXML. Taking the
order out of the candidate stage is safe because the order is still applied in the Viterbi pass.
The old dedupe had no such pass after it.

### A side effect: repeated chords hold still

Before, the 8 slots of a half-note chord had 8 different random candidate lists. If the best tuning
appeared in only some of them, Viterbi had to change the chord's tuning partway through the half
note, which shows up as a small gap. With shared candidates every slot offers the same tunings, so
the path can hold the chord still. This is why the gaps fell as well as the time.

## Change 2: the vectorised Viterbi step (`_transition_costs`)

For each pair of candidates (previous slot, this slot), the DP tried every pitch-class-preserving
transposition of the current candidate, up to about ±49 ¢. It called `compute_transition_cost`
once per transposition, in Python. `_transition_costs` now scores all the transpositions of a
candidate in one numpy step.

It uses the same arithmetic in the same order, so it gives the same floats, and the same
first-minimum tie-breaking, so it picks the same path. On real bwv261 chords, with rests, with
whole and fractional cents, and with and without `unique_pitch_classes`, it gave identical paths,
cents and costs, 11–23× faster. It's on by default. `VITERBI_SLOW=1` brings back the original loop.
The MAD term (`mad_weight > 0`) and other penalty types still use the loop.

## Is `scipy.sparse.linalg.lsqr` involved?

No. `lsqr` is used only by `spring_tuning.py` (`limited_solve`), where every spring makes the error
a sum of squares that one least-squares solve minimises. The ratchet's tuner chooses discrete ratios
by simulated annealing and then a path by dynamic programming (Viterbi). No continuous solve is
involved, and nothing here touches `spring_tuning.py`.

## Results

### Side by side: the same command, four passes, two cells (fs1, 3 workers each)

The first pass was fresh and the other three ratcheted. *Today's code* passes 2–4 already had the
faster Viterbi step (each pass reloads the module).

| Cell | Version | Seconds per pass | Chord average | GapSum | Largest gap |
|---|---|---|---:|---:|---:|
| t3_r1.25_lm17 | today's code | 330, 271, 239, 233 | 51.1 | 36 | 13 ¢ |
| t3_r1.25_lm17 | dedupe | 150, 104, 94, 99 | 51.2 | **13** | **3 ¢** |
| t1_r1.50_lm19 | today's code | 340, 250, 230, 246 | 51.5 | 62 | 18 ¢ |
| t1_r1.50_lm19 | dedupe | 153, 107, 96, 106 | 51.7 | **15** | **5 ¢** |

The data and scripts are in `Archive/straw-man/dedupe-test-20261121/`. Columns: pass, seconds,
chord average, chord max, gap count, GapSum, p90, max gap, high-prime %.

### The full grid on the cluster: `./ray-ratchet.sh --chorales bwv261 --fresh_first`

- 24 cells; passes took 53–115 s. The resumed run did 73 passes in 6 min 45 s, after about
  4 minutes of an interrupted one, so roughly 11 minutes of passes in all. The old code took
  roughly 30–40 minutes for one chorale.
- Each cell retired after 2–5 passes: 19 stalled, 4 dominated, 1 outclassed.
- 14 of the 24 cells finished with GapSum 0, and no cell has a gap over 11 ¢.

| Cell | Chord average | High primes | GapSum | Largest gap |
|---|---:|---:|---:|---:|
| t3_r1.50_lm17 (leader under `--sort_by best`) | 51.4 | 4.8% | 8 | 2 ¢ |
| t3_r1.50_lm19 (lowest chord average) | 51.0 | 5.7% | 0 | 0 ¢ |
| September best, t3_r1.25_lm17 (rests held then) | 54.7 | 5.0% | 12 | 3 ¢ |

The September cell tunings are kept in
`Archive/straw-man/saved-tunings/bwv261-before-dedupe-20261121/` on the PVC.

Renders of the leader: `Uploads/b261a_df3_t3_d09_51_t110_ap1_lm17_r1.50.mp3` (WreckingCrew, album 4)
and `Uploads/b261o_t3_d01_22_t060_lm17_r1.50.mp3` (WreckingCrew_v2, `ensembles/bwv262-octet.yaml`).
By ear: still spicy.

## Caveats

- The side-by-side test is two cells with one random draw each, on one chorale. The full grid
  agrees, but a second chorale with long held chords would make the case stronger.
- The September scores came from the old rest rule (rests held), so compare them only roughly.
- `test_viterbi.py` passes 3 of 4. `test_candidate_generation`'s stand-in SA function has no
  `max_no_improve` argument. It fails the same way at the previous commit, so these changes didn't
  cause it.

## Launcher and cluster fixes from the same run

- **`ray-ratchet.sh`:** waits up to 3 minutes for the Ray dashboard's job API (`/api/version`)
  before submitting. A submit 2 s after "cluster up" got a 500 and the run tore itself down.
- **`k8s-ray-cluster.yaml`:** no Ray pods on fs1. The head goes on fs4 or fs9, and the w12 group
  is 2 workers on fs2 and fs8 (26 task slots, against 29). fs1's desktop holds about 21 GiB of its
  30 GiB, which the kubelet doesn't count, and there is no swap. A w12 worker there ran it out of
  memory twice: the desktop froze, the node went NotReady, and the kernel killed Grafana and the
  Ray head.

## Turning it off

- `grid_search.sh`: remove `--dedupe_chords` (it's off by default in `Straw_man_tuning_v2.py`).
- `VITERBI_SLOW=1` in the tuner's environment brings back the original Viterbi loop.
