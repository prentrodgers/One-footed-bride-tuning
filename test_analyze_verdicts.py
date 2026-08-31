#!/usr/bin/env python3
"""The winner-matching in analyze_verdicts.py: cell name vs copied filename."""
import io, os, tempfile
import analyze_verdicts as av

# r1.25 (directory) and r1.250 (copied file) are the same cell.
assert av.cell_key('t1_r1.25_lm17') == (1, 1.25, 17)
assert av.cell_key('viterbi-tunings-8-23') is None

with tempfile.TemporaryDirectory() as d:
    for n in ['bwv261_t1_r1.250_lm17-opt.npy', 'bwv262_t3_r1.625_lm19-opt.npy', 'notes.txt']:
        open(os.path.join(d, n), 'w').close()
    win = av.read_winners(d)
assert win == {'bwv261': (1, 1.25, 17), 'bwv262': (3, 1.625, 19)}, win
assert win['bwv261'] == av.cell_key('t1_r1.25_lm17')
assert win['bwv262'] != av.cell_key('t3_r1.50_lm19')

LINE = ('Archive/straw-man/t1_r1.25_lm17/straw-man-tuning-bwv261.log:19 - INFO - '
        '>>> Current result is better: score 41.0 vs 45.0; spread 30.0 vs 33.0¢; '
        'max gap 12.0 vs 18.0¢')
(won, cell, ch, old, new), = av.parse(io.StringIO(LINE))
assert (won, cell, ch) == (True, 't1_r1.25_lm17', 'bwv261')
assert new == (41.0, 30.0, 12.0) and old == (45.0, 33.0, 18.0)
print('ok')
