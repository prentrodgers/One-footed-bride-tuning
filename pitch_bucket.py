#!/usr/bin/env python3
"""
pitch_bucket.py — shared pitch-class mapping for the consolidated
"one instrument, N fixed positions" sections (marimba, finger piano, bass,
and whichever of strings/woodwinds/brass/melody follow the same pattern).

Folds an arbitrary performed pitch (cents = octave*1200 + tonality_cents,
with C4 = 4800 per marimba_poc._pitch_label) onto one of N_BUCKETS fixed
positions spanning N_OCTAVES chromatically (12 pitch classes each) plus
one extra top C — the same layout as a keyboard. This is a many-to-one
mapping: many performed pitches land on the same position, not the old
one-position-per-unique-pitch layout.

The 4-octave window's bottom octave is a parameter (default 4, i.e.
C4..C8) rather than fixed, since different instruments sit in different
registers — bass, for instance, needs a lower window or most of its notes
would fall below C2 and bunch onto the bottom few positions, wasting the
top of the rack. Notes below the window fold up onto its bottom octave by
pitch class; notes above fold down onto its second-from-top octave (a note
that's exactly the top C gets the lone extra 49th position).

DEFAULT_BOTTOM_OCTAVE was 2 (C2..C6); checked against actual note
distributions in bwv259/bwv263, octaves 2-3 combined were only ~4-12% of
marimba/finger-piano notes while octave 7 (folding down onto octave 5
under the old window) was 7-20% — moved the window up to C4..C8 so it
actually covers where the notes are.
"""

# 4 octaves (49 positions) was the original window. Dropped to 3 (37) on
# 9/1/26: at stage framing 49 bars are ~13px wide apiece and blend into one
# stripe — both to the eye and to the diffusion pass in comfy_restyle.py,
# which read the row as a piano keyboard. A census of two chorales
# (bwv256/bwv259) found only 19-23 of the 49 marimba positions carrying 1%
# or more of the notes, so the row was mostly showing empty positions.
#
# The cost is at the top: with the window at C4..C7, notes in octave 7 and
# above fold down onto octave 6 — 8% of marimba notes in bwv259, 21% in
# bwv256. Set this back to 4 to undo the whole change.
N_OCTAVES = 3
DEFAULT_BOTTOM_OCTAVE = 4                                    # marimba/finger piano: C4..C7
N_BUCKETS = N_OCTAVES * 12 + 1                                # 37

# Kept for backward compatibility with callers that used the old fixed names.
BOTTOM_OCTAVE = DEFAULT_BOTTOM_OCTAVE
TOP_EXTRA_OCTAVE = BOTTOM_OCTAVE + N_OCTAVES                  # 8


def bucket_cents(pitch_cents, bottom_octave=DEFAULT_BOTTOM_OCTAVE,
                 n_octaves=None):
    """Return the representative cents value (always an exact multiple of
    100) for the fixed position this pitch folds onto. Octave/pitch-class
    recovered directly from cents since cents == absolute_semitone*100 by
    construction."""
    top_extra_octave = bottom_octave + (N_OCTAVES if n_octaves is None
                                        else n_octaves)
    semitone = int(round(pitch_cents / 100.0))
    octave, pitch_class = divmod(semitone, 12)

    if octave == top_extra_octave and pitch_class == 0:
        bucket_octave = top_extra_octave          # the lone extra top-C position
    elif octave < bottom_octave:
        bucket_octave = bottom_octave              # fold below the window up to its bottom octave
    elif octave >= top_extra_octave:
        bucket_octave = top_extra_octave - 1        # fold above the window down to its 2nd-from-top octave
    else:
        bucket_octave = octave

    return float(bucket_octave * 1200 + pitch_class * 100)


def representative_cents(bottom_octave=DEFAULT_BOTTOM_OCTAVE,
                         n_octaves=None):
    """The N_BUCKETS fixed representative cents values, low to high."""
    top_extra_octave = bottom_octave + (N_OCTAVES if n_octaves is None
                                        else n_octaves)
    reps = []
    for octave in range(bottom_octave, top_extra_octave):
        for pitch_class in range(12):
            reps.append(octave * 1200 + pitch_class * 100)
    reps.append(top_extra_octave * 1200)   # the extra top C
    return reps
