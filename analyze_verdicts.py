#!/usr/bin/env python3
"""Census the ratchet's keep/discard decisions across a whole batch.

Straw_man_tuning_v2 marks the two run-defining lines with '>>>' in each cell's
per-chorale log, so a batch can be summarised without touching pod logs (which
vanish with the pod, cap at five pods, and abandon the whole read when one pod
is still starting).

    ssh one-footed-bride-pod \\
      'grep -H "result is better" Repos/One-footed-bride-tuning/Archive/straw-man/*/straw-man-tuning-*.log' \\
      | python3 analyze_verdicts.py

    # or locally
    grep -H "result is better" Archive/straw-man/*/straw-man-tuning-*.log | python3 analyze_verdicts.py

Reads those lines on stdin.  The log always prints the WINNER first, so this
maps each line back to old-vs-new explicitly rather than assuming a column
order — getting that backwards inverts every 'Previous' verdict.
"""
import re
import sys

PATTERN = re.compile(
    r'straw-man/([^/]+)/straw-man-tuning-(bwv\d+)\.log:.*>>> (Current|Previous) result.*?'
    r'score ([\d.]+) vs ([\d.]+); spread ([\d.]+) vs ([\d.]+)¢; max gap ([\d.]+) vs ([\d.]+)¢')


def parse(stream):
    for line in stream:
        m = PATTERN.search(line)
        if not m:
            continue
        cell, chorale, winner = m.group(1), m.group(2), m.group(3)
        v = [float(x) for x in m.groups()[3:]]
        first, second = (v[0], v[2], v[4]), (v[1], v[3], v[5])
        new, old = (first, second) if winner == 'Current' else (second, first)
        yield (winner == 'Current', cell, chorale, old, new)


def main():
    rows = list(parse(sys.stdin))
    if not rows:
        print('No verdict lines found. Expect grep -H output over '
              'straw-man-tuning-*.log', file=sys.stderr)
        return 1

    improved = [r for r in rows if r[0]]
    # The ratchet scores mean + spread_weight*spread + gap_weight*max_gap, so a
    # spread gain can outbid a gap regression.  Count when that actually happens
    # — comparing what was KEPT against what was DISCARDED, which depends on the
    # verdict.  Comparing new-against-old instead inverts every 'Previous' line
    # and reports healthy decisions as failures.
    regressions = []
    for won, cell, ch, old, new in rows:
        kept, discarded = (new, old) if won else (old, new)
        if kept[2] > discarded[2]:
            regressions.append((cell, ch, kept[2], discarded[2]))

    print(f'{len(rows)} verdicts   improved: {len(improved)}   '
          f'unchanged: {len(rows) - len(improved)}   '
          f'kept a WORSE max gap: {len(regressions)}\n')

    print(f'{"cell":24} {"chorale":8} {"score":>15} {"spread":>15} {"max gap":>15}')
    print(f'{"-"*24} {"-"*8} {"-"*15} {"-"*15} {"-"*15}')
    for _, cell, ch, o, n in sorted(improved, key=lambda r: r[4][2] - r[3][2]):
        flag = '   <-- gap worse' if n[2] > o[2] else ''
        print(f'{cell:24} {ch:8} {o[0]:6.1f}→{n[0]:<8.1f} '
              f'{o[1]:6.1f}→{n[1]:<8.1f} {o[2]:6.1f}→{n[2]:<8.1f}{flag}')

    gains = [r[3][2] - r[4][2] for r in improved if r[4][2] < r[3][2]]
    if gains:
        print(f'\n{len(gains)} cells reduced their worst gap, '
              f'by {min(gains):.0f}-{max(gains):.0f}¢ (mean {sum(gains)/len(gains):.1f}¢)')
    if regressions:
        print(f'\n{len(regressions)} verdict(s) kept the LARGER max gap — the spread or '
              f'score term outbid it:')
        for cell, ch, kept, disc in sorted(regressions, key=lambda r: r[3] - r[2]):
            print(f'    {cell:24} {ch:8} kept {kept:.0f}¢, discarded {disc:.0f}¢')
        print('  Raise --gap_weight (currently 1.0 against spread_weight 0.5) if '
              'that is not what you want.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
