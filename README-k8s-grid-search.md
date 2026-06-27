# Kubernetes Grid Search Parallelization

This directory contains Kubernetes manifests and scripts to parallelize the grid search across your cluster, reducing execution time from ~60 hours to ~3 hours.

## Overview

The grid search tests 20 parameter combinations:
- 2 LIMIT_MAXES: 17, 19
- 2 TOLERANCES: 1, 2
- 5 RATIOS: 1.125, 1.25, 1.375, 1.5, 1.625

Each combination runs independently for ~3 hours on 1 core, processing 12 chorales (bwv253-264).

## Architecture

- **20 Kubernetes Jobs**: One per parameter combination, running in parallel
- **Shared Storage**: All jobs write to `dropbox-pvc` at `/home/prent/Repos/One-footed-bride-tuning/Archive/straw-man/`
- **Multi-node Distribution**: K8s scheduler spreads jobs across available nodes
- **Aggregation Job**: Runs after all 20 jobs complete to rank results

## Files

- `k8s-grid-search-job-template.yaml` - Template for individual parameter combination jobs
- `generate-grid-search-jobs.sh` - Generates 20 job manifests from template
- `deploy-grid-search-jobs.sh` - Deploys all jobs to cluster
- `k8s-grid-search-aggregation-job.yaml` - Final aggregation job
- `k8s-jobs/` - Directory containing generated job manifests (created by script)

## Usage

### Step 1: Generate Job Manifests

```bash
./generate-grid-search-jobs.sh
```

This creates 20 YAML files in `k8s-jobs/`, one for each parameter combination.

### Step 2: Deploy Jobs to Cluster

```bash
./deploy-grid-search-jobs.sh
```

This applies all 20 job manifests to your Kubernetes cluster. Jobs will start immediately and run in parallel.

### Step 3: Monitor Progress

```bash
# Watch job status in real-time
kubectl get jobs -l app=grid-search -w

# List all jobs
kubectl get jobs -l app=grid-search

# Count completed jobs
kubectl get jobs -l app=grid-search --field-selector status.successful=1 | wc -l

# View logs from a specific job
kubectl logs -l job-name=grid-search-01-lm17-t1-r1-125 --tail=100

# View logs from all running jobs
kubectl logs -l app=grid-search --tail=50
```

### Step 4: Run Aggregation (After All Jobs Complete)

Once all 20 jobs show `COMPLETIONS: 1/1`, run the aggregation job:

```bash
kubectl apply -f k8s-grid-search-aggregation-job.yaml
```

This runs `select_best_and_render.py` to rank all parameter combinations by their combined score and spread.

### Step 5: View Results

```bash
# Check aggregation job logs
kubectl logs -l job-type=aggregation

# Or access the results directly from the shared volume
# Results are in Archive/straw-man/t{t}_r{r}_s{s}_md{md}_sn{sn}_lm{lm}/
```

## Resource Requirements

Each job requests:
- **CPU**: 1 core (limit: 2 cores)
- **Memory**: 4Gi (limit: 8Gi)

For 20 parallel jobs:
- **Total CPU**: 20 cores minimum (40 cores for limits)
- **Total Memory**: 80Gi minimum (160Gi for limits)

Your cluster with multiple 20+ core nodes can easily handle this.

## Cleanup

```bash
# Delete all grid search jobs
kubectl delete jobs -l app=grid-search

# Delete aggregation job
kubectl delete job grid-search-aggregation

# Remove generated manifests
rm -rf k8s-jobs/
```

## Troubleshooting

### Job Failed

```bash
# View job details
kubectl describe job <job-name>

# View pod logs
kubectl logs -l job-name=<job-name>

# Delete and re-run failed job
kubectl delete job <job-name>
kubectl apply -f k8s-jobs/<job-file>.yaml
```

### Insufficient Resources

If jobs are pending due to insufficient resources:

```bash
# Check node resources
kubectl top nodes

# Check pending pods
kubectl get pods -l app=grid-search --field-selector status.phase=Pending

# Reduce parallelism by deleting some jobs and running them later
```

### Storage Issues

All jobs share the same PVC (`dropbox-pvc`). Ensure:
- PVC has sufficient space for all results
- PVC access mode supports `ReadWriteMany` for multi-node access

## Performance

- **Sequential (original)**: ~60 hours (20 combinations × 3 hours each)
- **Parallel (20 jobs)**: ~3 hours (all combinations run simultaneously)
- **Speedup**: 20x faster

## Notes

- Each job writes to a unique directory, so there are no conflicts
- Jobs can run on different nodes thanks to shared storage
- The aggregation job must run AFTER all 20 jobs complete
- Failed jobs can be retried independently without affecting others

## How jobs decide whether to keep or replace existing numpy arrays

Each job runs three steps. The keep/discard logic differs by step.

### Step 1 — `Straw_man_tuning_v2.py` produces `{version}-opt.npy`

Before saving, the script calls `load_and_merge_previous()` (defined at line 313 of
`Straw_man_tuning_v2.py`). It loads the existing `.npy` file (if present), rescores both
the old and new result using a combined metric:

```
combined = mean_score + spread_weight * weighted_spread
```

`spread_weight` defaults to **0.5** and is not overridden in the job YAML, so both score
and pitch-class spread matter equally. Whichever result has the lower combined value is
what gets written to disk. If the old file was better, its data is written back unchanged.

### Step 2 — `horizontal_transpose.py` produces `{version}-trans-sa-opt.npy`

This step always overwrites unconditionally (`np.save(dest, adjusted)` at line 261 of
`horizontal_transpose.py`). There is no comparison with a previous file. This is safe
because it merely re-derives a horizontal-consistency pass from the `-opt.npy` that won
in Step 1, so the `-trans-sa-opt.npy` always reflects the current best tuning.

### Step 3 — `analyze_spread.py`

Read-only analysis; writes no `.npy` files.

### Bottom line

The selection is fully handled inside each job. You do **not** need to run
`select_best_and_render.py` to protect against regression — that already happened.
`select_best_and_render.py` is for ranking the 24 parameter combinations against each
other after all jobs finish, not for guarding individual files.