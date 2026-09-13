#!/usr/bin/env python3
"""Best cell per chorale from a select_best_and_render.py report (sorted by
gapsum): prints TSV  chorale cell chordavg gaps gapsum p90 max.
With --top N also prints the N lowest-GapSum cells per chorale as cells-file
lines (limit_max tolerance ratio chorale) to the file named by --cells."""
import argparse, re, sys
ap = argparse.ArgumentParser()
ap.add_argument("report"); ap.add_argument("--top", type=int, default=0); ap.add_argument("--cells")
a = ap.parse_args()
rows, ch = {}, None
for line in open(a.report, errors="replace"):
    m = re.match(r"Chorale: (bwv\d+)", line)
    if m: ch = m.group(1); rows[ch] = []; continue
    m = re.match(r"\s+(t(\d)_r([\d.]+)_lm(\d+))\s+opt\s+\d\s+[\d.]+\s+\d+\s+([\d.]+)\s+\d+\s+\|\s+(\d+)\s+(\d+)\s+[\d.]+\s+[\d.]+\s+([\d.]+)\s+([\d.]+)", line)
    if m and ch:
        rows[ch].append(dict(cell=m.group(1), t=m.group(2), r=m.group(3), lm=m.group(4), avg=float(m.group(5)),
                             n=int(m.group(6)), sum=int(m.group(7)), p90=float(m.group(8)), mx=float(m.group(9))))
for c in sorted(rows):
    if rows[c]:
        b = rows[c][0]
        print(f"{c}\t{b['cell']}\t{b['avg']}\t{b['n']}\t{b['sum']}\t{b['p90']}\t{b['mx']}")
if a.top and a.cells:
    with open(a.cells, "w") as f:
        f.write("# written by ratchet_best.py: lowest-GapSum cells per chorale\n")
        for c in sorted(rows):
            for b in rows[c][:a.top]:
                f.write(f"{b['lm']} {b['t']} {b['r']} {c}     # {b['sum']} / {b['n']} / {b['p90']} / {b['avg']}\n")
