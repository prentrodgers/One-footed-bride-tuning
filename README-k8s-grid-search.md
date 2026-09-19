# Tuning grid on the cluster

The grid searches `limit_max` × `tolerance` × `ratio_factor` — 24 cells — over
a set of chorales, one tuning per (cell, chorale). Each tuning is
`grid_search.sh` in single-cell mode, which runs `Straw_man_tuning_v2.py` with
`--keep_previous` (FRESH=0): the result is written to
`Archive/straw-man/t{t}_r{ratio}_lm{lm}/{chorale}-opt.npy` only if it beats
what is already there, and the next run of the same cell is seeded from that
file. So a cell can be re-run indefinitely and only ever holds or improves —
the *ratchet*. Getting a good tuning is a matter of giving every cell enough
passes to stall.

Two ways to run it on the cluster. Both run the same command from the same
checkout on the shared `dropbox-pvc`; they differ in how the work is
scheduled.

## Ray (the current way)

```bash
./ray-ratchet.sh                                          # 24 cells × bwv415..426, ratchet until still
./ray-ratchet.sh --chorales bwv415 bwv419 --patience 3    # anything ray_ratchet.py accepts
./ray-ratchet.sh --cells_file ratchet-cells.txt           # a hand-picked list: "lm t ratio chorale" lines
./ray-ratchet.sh --dry_run                                # print the plan, start nothing
./ray-ratchet.sh --attach                                 # follow a run this shell lost
```

`ray-ratchet.sh` syncs the PVC checkout to `origin/main`
(`k8s-git-sync-job.yaml` — **unpushed commits do not run**), switches the
fleet to powersave-gpu, applies `k8s-ray-cluster.yaml` (one worker pod per
node on fs2–fs9, 28 four-CPU task slots), submits `ray_ratchet.py` as a Ray
job on the head, follows its log, and deletes the cluster when the job ends.
The job runs on the head, so a dropped ssh session does not stop it;
`--attach` picks the log back up. Environment knobs: `SKIP_SYNC=1`,
`KEEP_CLUSTER=1`, `POWER=0`.

`ray_ratchet.py` is the driver. It submits every (cell, chorale) once, then
re-submits each one as its previous pass finishes, until that cell has been
rejected by the ratchet `--patience` passes in a row (default 2), or reaches
`--max_passes` (default 8), or its GapSum is 0. Every cell gets its pass *N*
before any cell gets pass *N+1*. It prints one line per finished pass, a
status table every `--status_every` seconds, and at the end runs
`select_best_and_render.py --sort_by gapsum`. Every pass is also appended to
`Archive/straw-man/ray-ratchet-<start>.tsv`.

A pass takes about 5½ minutes on 4 CPUs (bwv415). The full default grid to
stall — 288 cells × ~5 passes — is roughly 4–5 hours.

Dashboard while it runs: `kubectl port-forward svc/tuning-head-svc 8265:8265`,
then http://localhost:8265 — per-task CPU and memory, worker logs.

Pieces:

| file | what |
|---|---|
| `install-kuberay.sh` | one-time: the KubeRay operator (v1.7.0, namespace `default`) |
| `parallel-jobs/build-image.sh` | builds `python-music:<tag>` on fs2; 0.11 added Ray 2.58.0 |
| `k8s-ray-cluster.yaml` | the RayCluster: head + three worker groups sized to each node's free CPU/memory (table in the file) |
| `ray_ratchet.py` | the driver; `run_cell` is the task |
| `ray-ratchet.sh` | brings it all up and down |
| `k8s-git-sync-job.yaml` | the one-shot sync of the PVC checkout, run before every batch |

If a worker pod stays Pending, something new is resident on its node and
the sizes in `k8s-ray-cluster.yaml` no longer fit:
`kubectl describe node fsN | grep -A12 Allocated`.

## Kubernetes Jobs (the previous way, kept for single cells by hand)

```bash
./generate-grid-search-jobs.sh                        # k8s-jobs/*.yaml, one per (cell, chorale)
CELLS_FILE=ratchet-cells.txt ./generate-grid-search-jobs.sh
INTERVAL=30 ./deploy-grid-search-jobs.sh              # submit one every INTERVAL seconds
PASSES=4 ./ratchet-passes.sh                          # repeat the whole batch PASSES times
./ratchet-until-still.sh bwv415 bwv419                # re-run each chorale's TOP=3 cells until none improves
```

One Job per (cell, chorale), from `k8s-grid-search-job-template.yaml`. Each
Job is a fresh pod, and pod start-up here is expensive (the comments in the
template say why), so `deploy-grid-search-jobs.sh` submits at a fixed rate
and 288 jobs take over an hour just to submit. The ratchet scripts re-run
only the best few cells per chorale and cost a full delete/deploy/wait cycle
per round. This is what the Ray path replaces; it still works, and is the
simplest way to run one cell once:

```bash
kubectl apply -f k8s-git-sync-job.yaml && kubectl wait --for=condition=complete job/grid-search-git-sync
kubectl apply -f k8s-jobs/grid-search-job-001-lm17-t1-r1-25-bwv415.yaml
```

## Reading the results

Nothing on the cluster picks a winner. When a run is done:

```bash
python select_best_and_render.py --numpy_dir_root Archive/straw-man \
    --chorale_list bwv415 bwv416 --suffix=-opt.npy --sort_by gapsum
```

`--sort_by` only orders the rows (`gapsum`, `p90`, `maxgap`, `over20`,
`score`, `name`); the script's docstring explains why it stopped declaring a
best. `--copy_npy_to DIR` copies each chorale's leading row.

## How a job decides whether to keep or replace a tuning

`Straw_man_tuning_v2.py` runs SA candidate generation, the Viterbi path
selection and `enforce_continuity`, and only then — last — compares the
finished array with the one on disk (`load_and_merge_previous`). The
comparison is `mean_score + spread_weight × max circular MAD + gap_weight ×
max adjacent gap`; the lower wins and is what gets saved. The sidecar
`{chorale}-opt.txt` records `last_improved`, which changes only when the new
tuning won — `ray_ratchet.py` reads it before and after a pass to know
whether the ratchet accepted.

The comparison is per file, so the twelve chorales of one cell can run at
once in the same directory; two passes of the *same* (cell, chorale) must not
overlap, and the driver never lets them.

## Cleanup

```bash
kubectl delete raycluster tuning                 # if a run left it up (KEEP_CLUSTER=1, or a failure)
kubectl delete jobs -l app=grid-search           # old-style jobs
rm -rf k8s-jobs/
```
