#!/usr/bin/env python3
"""Census the ratchet's keep/discard decisions across a whole batch.

Straw_man_tuning_v2 marks the two run-defining lines with '>>>' in each cell's
per-chorale log, so a batch can be summarised without touching pod logs (which
vanish with the pod, cap at five pods, and abandon the whole read when one pod
is still starting).

    ssh one-footed-bride-pod 'grep -H "result is better" Repos/One-footed-bride-tuning/Archive/straw-man/*/straw-man-tuning-*.log' | python3 analyze_verdicts.py

    # or locally
    grep -H "result is better" Archive/straw-man/*/straw-man-tuning-*.log | python3 analyze_verdicts.py

    # Only the cells select_best_and_render.py --sort_by p90 actually picked.
    # --winners is read locally, so fetch the pod's copy first (the destination is
    # the parent: scp into an existing viterbi-tunings-8-23 would nest a second one):
    scp -r one-footed-bride-pod:Repos/One-footed-bride-tuning/Archive/straw-man/viterbi-tunings-8-23 Archive/straw-man/
    ssh one-footed-bride-pod 'grep -H "result is better" Repos/One-footed-bride-tuning/Archive/straw-man/*/straw-man-tuning-*.log' | python3 analyze_verdicts.py --winners Archive/straw-man/viterbi-tunings-8-23

Reads those lines on stdin.  The log always prints the WINNER first, so this
maps each line back to old-vs-new explicitly rather than assuming a column
order — getting that backwards inverts every 'Previous' verdict.
"""
import argparse
import os
import re
import sys

PATTERN = re.compile(
    r'straw-man/([^/]+)/straw-man-tuning-(bwv\d+)\.log:.*>>> (Current|Previous) result.*?'
    r'score ([\d.]+) vs ([\d.]+); spread ([\d.]+) vs ([\d.]+)¢; max gap ([\d.]+) vs ([\d.]+)¢')


# Grid-search cell directory, e.g. t1_r1.25_lm17.
CELL = re.compile(r'^t(\d+)_r([\d.]+)_lm(\d+)$')
# What select_best_and_render.py --copy_npy_to writes, e.g. bwv261_t1_r1.625_lm17-opt.npy.
WINNER = re.compile(r'^(bwv\d+)_t(\d+)_r([\d.]+)_lm(\d+)')


def cell_key(cell):
    m = CELL.match(cell)
    # Ratio compared as a float: the cell directory writes r1.25, the copied
    # winner writes r1.250, and as strings those never match.
    return (int(m.group(1)), float(m.group(2)), int(m.group(3))) if m else None


def read_winners(d):
    """chorale -> (tolerance, ratio, limit_max) for each file select_best copied."""
    out = {}
    for name in sorted(os.listdir(d)):
        m = WINNER.match(name)
        if m:
            out[m.group(1)] = (int(m.group(2)), float(m.group(3)), int(m.group(4)))
    return out


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
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--winners', metavar='DIR',
                    help="select_best_and_render.py's --copy_npy_to directory: report "
                         'only the cell it picked for each chorale, and drop every '
                         'improvement that did not win its chorale.')
    args = ap.parse_args()

    rows = list(parse(sys.stdin))
    if not rows:
        print('No verdict lines found. Expect grep -H output over '
              'straw-man-tuning-*.log', file=sys.stderr)
        return 1

    if args.winners:
        win = read_winners(args.winners)
        if not win:
            print(f'No {args.winners}/bwvNNN_tN_rN.NNN_lmNN* files — is that the '
                  '--copy_npy_to directory?', file=sys.stderr)
            return 1
        rows = [r for r in rows if win.get(r[2]) == cell_key(r[1])]
        missing = sorted(set(win) - {r[2] for r in rows})
        print(f'Restricted to the {len(win)} winners in {args.winners}.')
        if missing:
            print(f'  no verdict line for: {" ".join(missing)}   '
                  '(their winning cell logged no comparison)')
        # Two directory names can parse to the same cell — t3_r1.50_lm19 and
        # t3_r1.5_lm19 are separate lineages with separate ratchets, but the copied
        # winner is named r1.500 and matches both.  Only one of them produced the
        # file, so their verdicts cannot be told apart: say so rather than
        # crediting a frozen cell with another cell's improvement.
        cells = {}
        for _, cell, ch, _, _ in rows:
            cells.setdefault(ch, set()).add(cell)
        split = {ch: sorted(c) for ch, c in cells.items() if len(c) > 1}
        if split:
            print(f'\n  WARNING: {len(split)} chorale(s) matched more than one cell '
                  'directory. Those directories are the same parameters spelled two\n'
                  '  ways, so they are separate lineages and only one of them holds the '
                  'winning file. The verdicts below cannot be attributed:')
            for ch, cs in sorted(split.items()):
                print(f'    {ch:8} {"  ".join(cs)}')
            print('  Fix the grid to use one spelling, then re-run.')
        print()
        if not rows:
            return 0

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
