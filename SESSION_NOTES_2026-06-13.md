# Session Notes — 2026-06-13

## Changes Made

### 1. `select_best_and_render.py` — tolerance no longer required as CLI arg

**Problem:** The grid-search-aggregation Kubernetes job calls `select_best_and_render.py`
without `--tolerance`, causing it to abort. The `parser.error()` guard was added in
commit `99a6dc9` but `args.tolerance` is never actually used — the script already reads
`tolerance` per-directory from the directory name (e.g. `t1_r1.375_lm17_tmp3.0`) via
`parse_dir_params()`, and passes it to `score_array()` as `tol = params['tolerance']`.

**Fix:** Removed lines 150–151 (the `parser.error()` guard). Updated the `--tolerance`
help text to say it is ignored and tolerance comes from the directory name.

**File:** `select_best_and_render.py`, lines 125–151.

---

### 2. `WreckingCrew.py` — Rondo / Leitmotif Feature

**Goal:** Allow the composer to designate named sections of the original chorale (by chord
index range) and insert copies of them at arbitrary points in the final piece — enabling
rondo form (A B A C A) or leitmotif recall.

#### CLI Arguments

```
--rondo_section_a 0 16          # section A = original chords [0, 16)  (end exclusive)
--rondo_section_b 48 64         # section B = original chords [48, 64)
--rondo_insert_a_after 32 80    # insert A after chord 32, and again after chord 80
--rondo_insert_b_after 64       # insert B after chord 64
```

Validation:
- END must be > START or the script exits with an error message.
- `--rondo_insert_x_after` requires the corresponding `--rondo_section_x` to be defined.

#### What Was Added

**Two standalone helper functions** (inserted just before `expand_chorale`, ~line 1733):

- **`_chord_idx_from_boundaries(notes_15, boundaries, tpq)`**
  Appends chord_idx as column 15 to the (N×15) notes array.  Before `fix_start_times`,
  column 1 is duration in tpq units.  For each voice (column 6), accumulates durations
  to reconstruct each note's piano-roll start step, then binary-searches into `boundaries`
  to assign a chord index.

- **`apply_rondo(notes_16, sections, insertions)`**
  Splices named-section copies into the (N×16) notes array (col 15 = chord_idx).
  For each voice in original order:
  - Walk insertion points in ascending chord order
  - Collect notes up through `after_chord`, then append a copy of the named section's rows
  - Append any remaining notes after the last insertion point
  Returns a new N×16 array (wider because of inserted rows).

**Insertion seam in `expand_chorale`** (after auto-normalize loop, before `fix_start_times`):

```python
if rondo_sections and rondo_insertions:
    _n_steps = chorale_in_cents_slides.shape[1]
    _chord_changes = np.where(
        np.any(np.diff(chorale_in_cents_slides[:4, :, 0], axis=1) != 0, axis=0)
    )[0] + 1
    _boundaries = np.concatenate(([0], _chord_changes, [_n_steps]))
    _tpq = tpq if tpq != 0 else 0.25
    notes_16 = _chord_idx_from_boundaries(notes_features_15, _boundaries, _tpq)
    notes_16 = apply_rondo(notes_16, rondo_sections, rondo_insertions)
    notes_features_15 = notes_16[:, :15]   # strip temp column before fix_start_times
```

The chord-boundary formula (`np.diff` + `chord_changes`) is identical to what `bass_part`
and `finger_piano_part` already use internally.  `fix_start_times` accumulates durations
in row order, so the splice lands correctly in time automatically — no manual time-shifting
needed.

**Signature changes** — `rondo_sections=None, rondo_insertions=None` added to:
- `expand_chorale()`
- `chorale_to_wave_v4()`
- `mainline()`

All three pass the args through; the argparse block builds and validates the dicts before
calling `mainline()`.

#### Architecture Notes

- Chord boundaries are derived from `chorale_in_cents_slides[:4, :, 0]` in the main
  context, before any bass-part voice-doubling or soprano/alto overwriting that happens
  inside the individual part functions.  This is the correct source of truth for all parts.
- Section end index is **exclusive**: `--rondo_section_a 0 16` gives chords 0–15.
- "Insert after chord 32" captures all rows where `chord_idx <= 32` for that voice,
  including all `repeats_average` elaborations of that chord.
- The temporary column 15 (chord_idx) is stripped from `notes_features_15` before
  `fix_start_times` is called, so downstream code (CSD output, audibility filter, .npy
  save) is unaffected.
- **`after_chord` is 0-based**: `--rondo_insert_a_after 63` inserts after the 64th chord
  (indices 0–63). This is intentionally Pythonic; subtract 1 from the human-readable
  measure number when setting this argument.

---

### 3. `WreckingCrew.py` — Rondo Bug Fixes (2026-06-17/18)

Three bugs discovered and fixed during testing with `--short_repeats --rondo_*`:

#### Bug 1: Insert point shifted late by glide count

**Problem:** Chord boundaries were detected via `np.diff(chorale_in_cents_slides[:4,:,0])`.
`build_glides_array` modifies cents in-place — for glide pairs it copies chord A's value
into chord B — so `np.diff` misses those step transitions.  Each glide before an insert
point shifted the insert 1 chord too late.

**Fix:** Compute `_boundaries` directly from the `repeats` array instead of diff-detecting:
```python
if len(repeats) == 1:   # --short_repeats: one step per original chord
    _boundaries = np.arange(chorale_in_cents_slides.shape[1] + 1, dtype=float)
else:                   # standard: cumsum of per-chord repeat counts
    _boundaries = np.concatenate(([0.0], np.cumsum(repeats, dtype=float)))
```

#### Bug 2: Voices out of sync after insert

**Problem:** `piano_roll_to_notes_features` merges identical adjacent chord steps into one
longer note (e.g. soprano holding a pitch across chords 62–65 → one note, duration=4×tpq,
chord_idx=62).  When the insert cut was at `after_chord=64`, that merged note was included
whole in the first chunk (chord_idx 62 ≤ 64), giving soprano 1 extra step of duration.
Alto (with separate notes at 62, 63, 64) had 1 step less.  The offset persisted for the
remainder of the piece.

**Fix:** Added `_split_voice_at_steps(vrows, cut_steps, boundaries, tpq)` — splits any
note whose duration straddles a cut boundary into two shorter notes, each with the correct
`chord_idx`.  Called per-voice inside `apply_rondo` before the chunk/copy/tail slicing.
Cut steps include all insertion boundaries **and** section-copy end boundaries.

#### Bug 3: Csound note bleed at split point (4–8 click overlap)

**Problem:** Each note carries a `hold` value (col 2 ≈ `duration × 1.01`) that controls
how long Csound sustains the note.  `_split_voice_at_steps` was copying the original
(full) `hold` into both split parts.  The shorter tail part then had `hold >> duration`,
so Csound sustained it across the section boundary — audible as 4–8 clicks of overlap.

**Fix:** Compute `hold_ratio = col[2] / col[1]` before splitting; set
`part[2] = part[1] * hold_ratio` for each split part so hold stays proportional to the
new (trimmed) duration.

#### New helper functions added

- **`_split_voice_at_steps(vrows, cut_steps, boundaries, tpq)`** — note-splitting helper
- **`apply_rondo`** updated: new `boundaries` and `tpq` parameters; builds complete cut
  step set; pre-splits each voice before slicing

#### Also: `--tolerance` made optional in `WreckingCrew.py`

Tolerance is read from the `--cent_file_partial` filename when encoded there.  The
`raise SystemExit` guard that fired when tolerance was still `None` was replaced with a
default of 1.  Updated help text accordingly.

---

## Investigated (No Code Changes)

- **Tuba rescue confirmed working** in `bwv258_features_array.npy` and `new_output.csd`:
  14 notes got f307 (1-oct drop), 5 got f308 (2-oct drop), ~74/26% split as designed.
  `TUBA_RESCUE_IMPLEMENTATION.md` is not dead code.

- **`tmp` in directory names** (e.g. `t1_r1.375_lm17_tmp3.0`) stands for
  `INITIAL_TEMP` — the initial simulated annealing temperature. Set in
  `k8s-grid-search-job-template.yaml` line 90.
