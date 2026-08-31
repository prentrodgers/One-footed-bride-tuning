# Chasing the Sore Thumb: Three Weeks of Tuning Fixes

Since the last post I've spent most of my time not on making chords *prettier*, but on
figuring out which defect actually bothers a listener — and then rebuilding the machinery
around that answer. The short version: I was measuring the wrong thing, and once I fixed
the measurement, a pile of other problems either solved themselves or finally became
visible.

## The wrong yardstick

Here's the setup, briefly. Simulated annealing tunes each chord on its own, hunting for
pure ratios. Viterbi then picks a path through those candidate chords so that a note held
across two chords doesn't lurch in pitch. Every run is scored, and if the new run beats the
saved one, it replaces it. I call that the ratchet — it's only supposed to click forward.

The ratchet was comparing the *average* chord score. That turned out to be useless. I ran
the same parameter cell four times on BWV 261 and got averages spanning 56.2 to 57.9 —
while ten *different* parameter settings spanned 56.0 to 57.6. The noise between repeats of
one setting was wider than the entire grid I was searching. The ratchet wasn't keeping the
best tuning, it was keeping whichever run drew the luckiest random seed.

What *did* separate those four runs was pitch jumps: worst single jump ranged from 3 cents
to 14. And that's the thing you actually hear. A tuning that drifts slowly across a whole
chorale is inaudible; one note that lurches 30 cents between two adjacent chords is a sore
thumb. So the ratchet now scores on the largest single adjacent jump — the worst one, not
an average, because a mean over 280 chords hides exactly the lurch you'd notice.

Confirming this was satisfying and slightly horrifying. Two of those four runs scored
*better* on the old average but jumped worse, and would have overwritten the good tuning.
Which is precisely how a 3-cent result I'd found earlier vanished without my noticing.

The same argument then applied one level up. The closing report used to rank parameter
cells by *total* gap across the piece. Sorting by worst-single-jump instead promotes a
different winner — 11 cents worst / 44 total, over 14 worst / 32 total — and that's the one
that sounded right when I listened. A lower total doesn't buy back a bigger lurch.

## Runs that improve instead of re-rolling

With a metric worth trusting, the acceptance rate became embarrassing: 103 of 115 runs
rejected. Every run rebuilt from scratch starting at 12-TET, so to be kept it had to beat
the incumbent across the whole chorale on a single lucky draw.

The fix is obvious in hindsight. The tuning already saved for a cell is now offered back to
Viterbi as a candidate at every chord — appended *after* the trim that keeps the top
fifteen, so the sort can never drop it (the incumbent's individual chord scores are often
worse than fresh candidates; that's the whole point of keeping it). With the previous path
present in the trellis, the best path through it is, at worst, a tie with what I already
had. Runs can now only improve a cell.

Alongside it, the cost of a pitch jump gained a hinge: above 10 cents it goes quadratic
(10 costs 10, 15 costs 21, 20 costs 45, 30 costs 130). A plain linear cost minimizes the
*sum* of jumps, so the algorithm would happily buy one 20-cent lurch to save fifteen
1-cent ones — and then the ratchet, which judges on the worst jump, threw the entire run
away. Now one 20-cent gap costs more than two 10-cent gaps, and the two halves of the
system finally want the same thing.

Eight cells on BWV 261 that still had headroom: all eight improved, all eight accepted.

    t3_r1.375_lm17   21 -> 8      t1_r1.25_lm19    15 -> 4
    t3_r1.75_lm17    25 -> 14     t3_r1.375_lm19   14 -> 3
    t3_r1.75_lm19    22 -> 11     t2_r1.625_lm19   14 -> 10
    t2_r1.375_lm19   19 -> 16     t2_r1.625_lm17   17 -> 14

(worst adjacent jump, in cents). The first one had been stuck at 21 across four previous
passes. Average chord quality moved by at most half a point anywhere, so this isn't buying
smoothness by sacrificing consonance.

## Holes in the diamond

A separate bug, and my favorite of the batch. Simulated annealing builds a chord by
chaining exact ratios, so any interval it doesn't write *directly* comes out as a sum of
two ratios — and can land in a hole in the tuning lattice. BWV 261's second chord (D G A E)
is the clean example: an exact 4/3 from D to G plus an exact 9/8 from D to E leaves G-E
sitting at 294 cents, in the gap between 289 (13/11) and 316 (6/5). Nothing matches, the
chord takes a large penalty, and annealing rejects it mid-search — settling instead for
bending a note 45 cents out. That's the sour chord I'd been hearing.

The fix nudges each voice by up to 6 cents, preserving its pitch class, and keeps the
result only if it's strictly better. Applied to the plain 12-TET version of the chord, it
walks straight to the compromise: all six intervals within 3 cents of a real ratio, score
93 down to 79. That's the tuning my June runs occasionally hit by pure luck, when leftover
random noise happened to land in the window. It's now reachable on purpose.

## Two things I got wrong

Honest accounting, since this is a log and not a sales pitch.

**A knob that did nothing.** `--viterbi_horizontal_weight` had been threaded through the
whole pipeline and never actually read. Phrase seams are already optimized inside the
phrase pass, and the piece level is a bare concatenation. It looked like a control for seam
continuity while having no effect whatsoever. Deleted.

**Tightening the screws made it worse.** I forced the continuity limit down from 33 cents
to 12, on the theory that if jumps are the audible defect, I should just forbid the big
ones. What actually happens is that the enforcement step clamps individual voices, breaking
intervals the annealer had built exactly — and out come wolf intervals, a D-A fifth landing
27 cents flat. Same cell, same budget: at 33 the final tuning has zero wolves; at 12 it has
four, and the average chord score collapses from 56.6 to 79.9. Back to 33. The ratchet now
also compares the *count* of unmatched intervals before anything else, because a wolf is a
categorical failure, not a quantity you're allowed to trade a few cents of smoothness for.

## Running it faster

Less musical, but it's what makes the above possible. A grid search job used to tune all
twelve chorales in a serial loop; the chorales are independent, so it now emits one job per
(setting × chorale). A 10-cell grid goes from about four and a half hours to twenty-odd
minutes on the cluster. Submission runs at a fixed rate instead of watching for free slots
(a wedged pod used to hold its slot forever and stall the whole batch at 38 of 120), the
repository syncs once per batch instead of 360 pods fighting over one checkout, and a small
script now reads the logs afterward to count how many runs actually improved their cell —
and how often the ratchet kept the larger gap, which is the next open question.

## Where that leaves it

The system now measures the defect I can hear, keeps runs that fix it, and improves
monotonically across passes instead of re-rolling the dice. The open question is the trade
weighting: a 9-cent spread improvement currently pays for a 4-cent gap regression, and I'm
not convinced that's the right exchange rate. That's what I'm listening for next.
