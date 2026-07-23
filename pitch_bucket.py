#!/usr/bin/env python3
"""
pitch_bucket.py — shared pitch-class mapping for the consolidated
"one instrument, N fixed positions" sections (marimba, finger piano, bass,
and whichever of strings/woodwinds/brass/melody follow the same pattern).

Folds an arbitrary performed pitch (cents = octave*1200 + tonality_cents,
with C4 = 4800 per marimba_poc._pitch_label) onto one of 49 fixed
positions spanning 4 octaves chromatically (12 pitch classes each) plus
one extra top C — the same layout as a 49-key keyboard. This is a
many-to-one mapping: many performed pitches land on the same position,
not the old one-position-per-unique-pitch layout.

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

N_OCTAVES = 4
DEFAULT_BOTTOM_OCTAVE = 4                                    # marimba/finger piano: C4..C8
N_BUCKETS = N_OCTAVES * 12 + 1                                # 49

# Kept for backward compatibility with callers that used the old fixed names.
BOTTOM_OCTAVE = DEFAULT_BOTTOM_OCTAVE
TOP_EXTRA_OCTAVE = BOTTOM_OCTAVE + N_OCTAVES                  # 8


def bucket_cents(pitch_cents, bottom_octave=DEFAULT_BOTTOM_OCTAVE):
    """Return the representative cents value (always an exact multiple of
    100) for the fixed position this pitch folds onto. Octave/pitch-class
    recovered directly from cents since cents == absolute_semitone*100 by
    construction."""
    top_extra_octave = bottom_octave + N_OCTAVES
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


def representative_cents(bottom_octave=DEFAULT_BOTTOM_OCTAVE):
    """The 49 fixed representative cents values, sorted low to high."""
    top_extra_octave = bottom_octave + N_OCTAVES
    reps = []
    for octave in range(bottom_octave, top_extra_octave):
        for pitch_class in range(12):
            reps.append(octave * 1200 + pitch_class * 100)
    reps.append(top_extra_octave * 1200)   # the extra top C
    return reps
