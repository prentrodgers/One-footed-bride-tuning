#!/usr/bin/env python3
"""ray_ratchet.py — the tuning grid as Ray tasks, ratcheted until every cell
has stopped improving.

One task = one (limit_max, tolerance, ratio) cell for one chorale, running the
same `grid_search.sh` single-cell command a Kubernetes Job did.  The driver
submits every cell once, and then keeps re-running each one — FRESH=0, so the
tuner's keep-previous ratchet holds whichever result is better and seeds the
next pass from it — until that cell has gone PATIENCE passes in a row without
the ratchet accepting a new tuning, or has hit MAX_PASSES, or its GapSum is 0.

This is the thoroughness the hand ratchet lacked.  ratchet-until-still.sh
re-ran only the TOP=3 cells per chorale by GapSum, so 21 of 24 cells never got
a second pass, and every round paid a full delete / deploy / poll / report
cycle.  Here every cell runs until it individually stalls, and each result is
acted on the moment it lands.

Usage (normally via ray-ratchet.sh, which brings the cluster up and down):

    python ray_ratchet.py                                  # 24 cells x bwv415..426
    python ray_ratchet.py --chorales bwv415 bwv419 --patience 3 --max_passes 12
    python ray_ratchet.py --cells_file ratchet-cells.txt   # lines: lm t ratio chorale
    python ray_ratchet.py --dry_run                        # the plan, no cluster

The tuner's own accept decision is what counts as progress: a pass is
"accepted" when the ratchet wrote a new tuning, read off the sidecar's
last_improved timestamp before and after.  GapSum, gap count, p90, max and
chord average are computed for every pass as well (with the same functions
select_best_and_render.py uses) and logged to
Archive/straw-man/ray-ratchet-<start>.tsv, one line per pass.

Ratios are strings, spelled as the cell directory is named: 1.50, not 1.5.
"""
import argparse
import collections
import datetime
import os
import subprocess
import sys
import time

REPO = os.path.dirname(os.path.abspath(__file__))
RESULTS = os.path.join(REPO, 'Archive', 'straw-man')

Key = collections.namedtuple('Key', 'lm t r chorale')


def cell_dir(k):
    return f't{k.t}_r{k.r}_lm{k.lm}'


def read_sidecar(path):
    """The {chorale}-opt.txt the tuner writes: 'name: value' lines."""
    out = {}
    try:
        with open(path) as f:
            for line in f:
                if ':' in line:
                    name, value = line.split(':', 1)
                    out[name.strip()] = value.strip()
    except OSError:
        pass
    return out


# ── The task ─────────────────────────────────────────────────────────────────
def run_cell(k, fresh, task_id):
    """Runs on a worker.  One pass of grid_search.sh for one cell and chorale,
    then the pass's metrics.  Raises if the tuner failed."""
    import numpy as np
    os.chdir(REPO)
    sys.path.insert(0, REPO)
    import select_best_and_render as sbr
    import adaptive_tuning_util as atu

    d = os.path.join(RESULTS, cell_dir(k))
    sidecar = os.path.join(d, f'{k.chorale}-opt.txt')
    npy = os.path.join(d, f'{k.chorale}-opt.npy')
    before = read_sidecar(sidecar).get('last_improved')

    env = dict(os.environ, FRESH='1' if fresh else '0')
    env.setdefault('VITERBI_WORKERS', '4')
    t0 = time.time()
    proc = subprocess.run(
        ['bash', 'grid_search.sh',
         '--limit_max', str(k.lm), '--tolerance', str(k.t), '--ratio', k.r,
         '--chorale', k.chorale, '--job_id', task_id],
        env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    seconds = time.time() - t0
    if proc.returncode != 0:
        tail = '\n'.join(proc.stdout.splitlines()[-25:])
        raise RuntimeError(f'grid_search.sh exited {proc.returncode} after {seconds:.0f}s\n{tail}')

    after = read_sidecar(sidecar)
    arr = np.load(npy)                                     # (4, N)
    diamond = atu.build_tonal_diamond(k.lm)[:-1]
    mean_sc, max_sc, _ = sbr.score_array(arr, diamond, k.t)
    g = sbr.summarize_gaps(sbr.collect_gaps(arr), 33.0)
    return dict(accepted=after.get('last_improved') != before, seconds=seconds,
                chordavg=mean_sc, chordmax=max_sc,
                n=g['n'], gapsum=g['total'], p90=g['p90'], mx=g['mx'])


# ── The plan ─────────────────────────────────────────────────────────────────
def build_keys(a):
    if a.cells_file:
        keys = []
        with open(a.cells_file) as f:
            for line in f:
                fields = line.split('#', 1)[0].split()
                if len(fields) != 4:
                    continue
                lm, t, r, chorale = fields
                keys.append(Key(int(lm), int(t), r, chorale))
        return keys
    return [Key(lm, t, r, c) for lm in a.limit_maxes for t in a.tolerances
            for r in a.ratios for c in a.chorales]


def parse_args():
    p = argparse.ArgumentParser(description=__doc__.split('\n\n')[0],
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--chorales', nargs='+', default=[f'bwv{n}' for n in range(415, 427)])
    p.add_argument('--limit_maxes', nargs='+', type=int, default=[17, 19])
    p.add_argument('--tolerances', nargs='+', type=int, default=[1, 2, 3])
    p.add_argument('--ratios', nargs='+', default=['1.25', '1.375', '1.50', '1.625'],
                   help='spelled as the cell directory: 1.50 not 1.5')
    p.add_argument('--cells_file', help='lines of "limit_max tolerance ratio chorale" instead of the product above')
    p.add_argument('--patience', type=int, default=2,
                   help='retire a cell after this many consecutive passes the ratchet rejected (default 2)')
    p.add_argument('--max_passes', type=int, default=8, help='hard cap per cell (default 8)')
    p.add_argument('--fresh_first', action='store_true',
                   help='FRESH=1 on each cell\'s FIRST pass: wipe its saved tuning and start over. '
                        'Later passes ratchet as usual.  Default keeps what is on disk.')
    p.add_argument('--task_cpus', type=int, default=4, help='CPUs per task; keep equal to VITERBI_WORKERS (default 4)')
    p.add_argument('--task_memory_gb', type=float, default=2.5, help='memory a task declares to Ray (default 2.5)')
    p.add_argument('--max_retries', type=int, default=2, help='re-submit a failed pass this many times (default 2)')
    p.add_argument('--status_every', type=int, default=300, help='seconds between status tables (default 300)')
    p.add_argument('--no_report', action='store_true', help='skip select_best_and_render.py at the end')
    p.add_argument('--dry_run', action='store_true')
    a = p.parse_args()
    for c in a.chorales:
        if not c.startswith('bwv'):
            p.error(f'chorale names need the bwv prefix: got {c!r}')
    return a


# ── The driver ───────────────────────────────────────────────────────────────
def main():
    a = parse_args()
    keys = build_keys(a)
    chorales = sorted({k.chorale for k in keys})
    cells = sorted({cell_dir(k) for k in keys})
    print(f'{len(keys)} (cell, chorale) tasks: {len(cells)} cells x {len(chorales)} chorales')
    print(f'  chorales: {" ".join(chorales)}')
    print(f'  cells:    {" ".join(cells)}')
    print(f'  patience {a.patience}, max_passes {a.max_passes}, '
          f'{a.task_cpus} CPU + {a.task_memory_gb}GiB per task'
          + (', FRESH=1 on first pass' if a.fresh_first else ''))
    if a.dry_run:
        print('dry run — nothing submitted')
        return

    import ray
    ray.init(address='auto', log_to_driver=False)
    cpus = int(ray.cluster_resources().get('CPU', 0))
    slots = cpus // a.task_cpus
    print(f'cluster: {cpus} CPU across {len(ray.nodes())} nodes = {slots} task slots\n', flush=True)
    if slots == 0:
        sys.exit('no worker CPUs — are the worker pods Running?')

    remote = ray.remote(num_cpus=a.task_cpus, memory=int(a.task_memory_gb * 1024 ** 3),
                        max_retries=0)(run_cell)

    start = datetime.datetime.now()
    tsv_path = os.path.join(RESULTS, f'ray-ratchet-{start:%Y%m%d-%H%M}.tsv')
    tsv = open(tsv_path, 'w', buffering=1)
    tsv.write('time\tchorale\tcell\tpass\taccepted\tseconds\tchordavg\tn\tgapsum\tp90\tmax\tstatus\n')

    # Per-key state.  A key sits in exactly one of: ready (deque), inflight
    # (dict ref->key), or retired (reason set).
    st = {k: dict(passes=0, stall=0, failures=0, last=None, retired=None) for k in keys}
    ready = collections.deque(keys)
    inflight = {}
    # Enough in flight to keep every slot busy with a queue behind it, but not
    # everything at once: keys come off the deque in order and go back on the
    # end, so with a bounded queue every cell gets its pass N before any cell
    # gets pass N+1 — the fairness the hand ratchet did not have.
    max_inflight = slots * 2
    done_passes = 0
    last_status = time.time()

    def submit(k):
        s = st[k]
        fresh = a.fresh_first and s['passes'] == 0
        task_id = f'ray-{k.chorale}-{cell_dir(k)}-p{s["passes"] + 1}'
        ref = remote.options(name=task_id).remote(k, fresh, task_id)
        inflight[ref] = k

    def retire(k, reason):
        st[k]['retired'] = reason

    def status():
        active = sum(1 for s in st.values() if s['retired'] is None)
        print(f'\n-- {datetime.datetime.now():%H:%M:%S}  passes done {done_passes}, '
              f'inflight {len(inflight)}, ready {len(ready)}, cells active {active}/{len(keys)}')
        print(f'   {"chorale":<8} {"best cell":<18} {"GapSum":>6} {"n":>3} {"p90":>5} {"max":>5} {"avg":>5}  active  retired')
        for c in chorales:
            rows = [(k, s) for k, s in st.items() if k.chorale == c and s['last']]
            act = sum(1 for k, s in st.items() if k.chorale == c and s['retired'] is None)
            ret = sum(1 for k, s in st.items() if k.chorale == c and s['retired'])
            if not rows:
                print(f'   {c:<8} {"(no pass finished yet)":<18}{"":>34}  {act:>6}  {ret:>7}')
                continue
            k, s = min(rows, key=lambda ks: (ks[1]['last']['gapsum'], ks[1]['last']['mx']))
            m = s['last']
            print(f'   {c:<8} {cell_dir(k):<18} {m["gapsum"]:>6.0f} {m["n"]:>3} {m["p90"]:>5.1f} '
                  f'{m["mx"]:>5.1f} {m["chordavg"]:>5.1f}  {act:>6}  {ret:>7}')
        print(flush=True)

    while ready or inflight:
        while ready and len(inflight) < max_inflight:
            submit(ready.popleft())

        done, _ = ray.wait(list(inflight), num_returns=1, timeout=30)
        if time.time() - last_status >= a.status_every:
            status()
            last_status = time.time()
        if not done:
            continue

        for ref in done:
            k = inflight.pop(ref)
            s = st[k]
            label = f'{k.chorale} {cell_dir(k):<18} pass {s["passes"] + 1}'
            try:
                m = ray.get(ref)
            except Exception as e:                      # tuner failed, or the worker died
                s['failures'] += 1
                first = str(e).strip().splitlines()[0] if str(e).strip() else type(e).__name__
                if s['failures'] > a.max_retries:
                    retire(k, 'failed')
                    print(f'{label}: FAILED {s["failures"]}x, retired — {first}', flush=True)
                else:
                    ready.append(k)
                    print(f'{label}: failed ({s["failures"]}/{a.max_retries}), will retry — {first}', flush=True)
                tsv.write(f'{datetime.datetime.now():%F %T}\t{k.chorale}\t{cell_dir(k)}\t{s["passes"] + 1}'
                          f'\t\t\t\t\t\t\t\tfailed\n')
                continue

            s['passes'] += 1
            done_passes += 1
            prev = s['last']
            s['last'] = m
            if m['accepted']:
                s['stall'] = 0
            else:
                s['stall'] += 1

            if m['gapsum'] == 0:
                retire(k, 'GapSum 0')
            elif s['stall'] >= a.patience:
                retire(k, f'stalled {s["stall"]}')
            elif s['passes'] >= a.max_passes:
                retire(k, f'max passes {a.max_passes}')
            else:
                ready.append(k)

            delta = f'{prev["gapsum"]:.0f}->' if prev else ''
            verdict = 'accepted' if m['accepted'] else f'rejected ({s["stall"]}/{a.patience})'
            tail = f'  RETIRED: {s["retired"]}' if s['retired'] else ''
            print(f'{label}: {verdict:<15} GapSum {delta}{m["gapsum"]:.0f} n {m["n"]} '
                  f'p90 {m["p90"]:.1f} max {m["mx"]:.1f} avg {m["chordavg"]:.1f}  ({m["seconds"]:.0f}s){tail}',
                  flush=True)
            tsv.write(f'{datetime.datetime.now():%F %T}\t{k.chorale}\t{cell_dir(k)}\t{s["passes"]}'
                      f'\t{int(m["accepted"])}\t{m["seconds"]:.0f}\t{m["chordavg"]:.1f}\t{m["n"]}'
                      f'\t{m["gapsum"]:.0f}\t{m["p90"]:.1f}\t{m["mx"]:.1f}\t{s["retired"] or "active"}\n')

    tsv.close()
    status()
    elapsed = datetime.datetime.now() - start
    reasons = collections.Counter(s['retired'] for s in st.values())
    print(f'done in {elapsed}: {done_passes} passes over {len(keys)} cells; '
          f'retired: ' + ', '.join(f'{n} {r}' for r, n in reasons.most_common()))
    print(f'per-pass log: {os.path.relpath(tsv_path, REPO)}')

    if not a.no_report:
        print('\nselect_best_and_render.py, sorted by gapsum (a report, not a verdict):\n', flush=True)
        subprocess.run([sys.executable, 'select_best_and_render.py',
                        '--numpy_dir_root', 'Archive/straw-man',
                        '--chorale_list', *chorales,
                        '--suffix=-opt.npy', '--sort_by', 'gapsum', '--top_gaps', '0'],
                       cwd=REPO)


if __name__ == '__main__':
    main()
