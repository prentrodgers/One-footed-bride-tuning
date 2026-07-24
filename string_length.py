#!/usr/bin/env python3
"""
string_length.py — shared physics for "stopped" (fingered/fretted) string
length, used by bowed_strings_section_poc.py, string_section_poc.py, and
bass_section_poc.py's baritone guitar.

A string's vibrating length is inversely proportional to its frequency for
fixed tension/mass (L = L0 * f0/f). A note played on a given open string,
some number of cents above that string's open pitch, therefore vibrates
over only a fraction of the string's full length — the rest is damped by
the finger/fret. An octave above the open string (1200 cents) vibrates at
half length; a fifth above (700 cents) at ~0.67 length.
"""

MIN_LENGTH_FRAC = 0.2   # safety floor so an unusually high stopped note
                         # never collapses the vibrating segment to ~nothing


def vibrating_length_fraction(pitch_cents, open_cents, min_frac=MIN_LENGTH_FRAC):
    """Fraction (0, 1] of the string's full length that actually vibrates
    for a note `pitch_cents` played on a string whose open pitch is
    `open_cents`. Notes at or below the open pitch (shouldn't normally
    occur — that string wouldn't have been chosen — but may from a nearest-
    string fallback) return 1.0 (full length, no shortening)."""
    cents_above = max(0.0, pitch_cents - open_cents)
    return max(min_frac, min(1.0, 2.0 ** (-cents_above / 1200.0)))
