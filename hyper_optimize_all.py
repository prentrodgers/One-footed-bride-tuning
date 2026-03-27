#!/usr/bin/env python3
"""
Multi-chorale hyperparameter optimization for Straw_man_tuning_v4.py.

Starting from the optimized defaults (sa_iters=100, rolls=7, etc.),
runs 50 iterations per chorale to see if any need custom parameter values.
Chorales are processed sequentially. Results are saved per-chorale and
to a combined summary CSV.
"""

import subprocess
import sys
import time
import re
import csv
import json
import os
import copy
import shutil

NPY_DIR = "Archive/straw-man"
SUMMARY_CSV = "hyper_optimize_all_summary.csv"
MAX_ITERS = 50
TIME_WARN_SECS = 300

CHORALES = [
    "bwv253", "bwv254", "bwv255", "bwv256", "bwv257", "bwv258",
    "bwv259", "bwv260", "bwv261", "bwv262", "bwv263",
]

# Starting params = the new v4 defaults (optimized on bwv264)
BASE_PARAMS = {
    "limit_max": 17,
    "tolerance": 1,
    "ratio_factor": 1.25,
    "max_delta": 33,
    "rolls": 7,
    "sa_iters": 100,
    "sa_max_alpha": 8.0,
    "sa_restarts": 12,
    "parallel_restarts": 12,
    "restart_repeat_threshold": 2,
    "spread_weight": 0.5,
    "stability_factor": 0.5,
    "spread": 7,
    "max_gap": 40.0,
    "snap_tolerance": 0.0,
    "workers": 1,
    "runs": 1,
}

# Exploration schedule: params that might still help individual chorales.
# Shorter than bwv264 search since defaults are already tuned.
EXPLORATION_SCHEDULE = [
    # SA engine - push further
    ("sa_iters",            [150, 200]),
    ("rolls",               [10, 5]),
    # SA restarts - push further
    ("sa_restarts",         [16, 20]),
    ("parallel_restarts",   [16, 20]),
    ("sa_max_alpha",        [10.0, 6.0]),
    # Ratio/stability
    ("ratio_factor",        [1.5, 1.0, 1.75]),
    ("stability_factor",    [0.75, 1.0, 0.25]),
    ("max_delta",           [40, 25]),
    # Post-processing
    ("max_gap",             [30.0, 50.0]),
    ("snap_tolerance",      [1.0]),
    # Limit & tolerance (different chorales may prefer different values)
    ("limit_max",           [19, 23]),
    ("tolerance",           [2]),
]


def build_command(chorale, params):
    """Build the Straw_man_tuning_v4.py command from params dict."""
    cmd = [sys.executable, "Straw_man_tuning_v4.py"]
    cmd += ["--chorale_list", chorale]
    cmd += ["--limit_max", str(params["limit_max"])]
    cmd += ["--tolerance", str(params["tolerance"])]
    cmd += ["--ratio_factor", str(params["ratio_factor"])]
    cmd += ["--max_delta", str(params["max_delta"])]
    cmd += ["--rolls", str(params["rolls"])]
    cmd += ["--sa_iters", str(params["sa_iters"])]
    cmd += ["--sa_max_alpha", str(params["sa_max_alpha"])]
    cmd += ["--sa_restarts", str(params["sa_restarts"])]
    cmd += ["--parallel_restarts", str(params["parallel_restarts"])]
    cmd += ["--restart_repeat_threshold", str(params["restart_repeat_threshold"])]
    cmd += ["--spread_weight", str(params["spread_weight"])]
    cmd += ["--stability_factor", str(params["stability_factor"])]
    cmd += ["--spread", str(params["spread"])]
    cmd += ["--max_gap", str(params["max_gap"])]
    cmd += ["--snap_tolerance", str(params["snap_tolerance"])]
    cmd += ["--numpy_dir", NPY_DIR]
    cmd += ["--no-print_values"]
    if params["workers"] > 1:
        cmd += ["--workers", str(params["workers"])]
    if params["runs"] > 1:
        cmd += ["--runs", str(params["runs"])]
    return cmd


def evaluate(chorale, params):
    """Run analyze_tuned_arrays.py and parse Mean, Spread, Combined."""
    npy_file = f"{NPY_DIR}/{chorale}-opt.npy"
    cmd = [
        sys.executable, "analyze_tuned_arrays.py",
        "--files", npy_file,
        "--tolerance", str(params["tolerance"]),
        "--limit_max", str(params["limit_max"]),
        "--spread_weight", str(params["spread_weight"]),
        "--suffix=-opt.npy",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    output = result.stdout + result.stderr
    for line in output.split("\n"):
        if f"{chorale}-opt.npy" in line:
            parts = line.split()
            idx = None
            for i, p in enumerate(parts):
                if f"{chorale}-opt.npy" in p:
                    idx = i
                    break
            if idx is not None:
                nums = parts[idx + 1:]
                if len(nums) >= 7:
                    return {
                        "mean": float(nums[0]),
                        "max": float(nums[1]),
                        "max_ch": int(nums[2]),
                        "spread": float(nums[5]),
                        "combined": float(nums[6]),
                    }
    return None


def run_iteration(chorale, params):
    """Run one tuning iteration. Returns (metrics_dict, elapsed_seconds)."""
    cmd = build_command(chorale, params)
    t0 = time.time()
    result = subprocess.run(cmd, capture_output=True, text=True)
    elapsed = time.time() - t0
    for line in result.stdout.split("\n"):
        if any(kw in line for kw in ["better", "mean:", "Continuity"]):
            print(f"    > {line.strip()}")
    if result.returncode != 0:
        print(f"    ERROR (rc={result.returncode}): {result.stderr[-300:]}")
    metrics = evaluate(chorale, params)
    return metrics, elapsed


def optimize_one_chorale(chorale):
    """Run the full optimization cycle for a single chorale. Returns summary dict."""
    npy_file = f"{NPY_DIR}/{chorale}-opt.npy"
    results_csv = f"hyper_optimize_{chorale}.csv"

    print(f"\n{'=' * 90}")
    print(f"  CHORALE: {chorale}")
    print(f"{'=' * 90}")

    # Phase 0: establish baseline — run once with defaults to create the -opt.npy
    current_params = copy.deepcopy(BASE_PARAMS)
    print(f"  Creating initial tuning with default params...")
    metrics, elapsed = run_iteration(chorale, current_params)

    if metrics is None:
        print(f"  FATAL: Could not create initial tuning for {chorale}. Skipping.")
        return None

    baseline = metrics.copy()
    best_combined = baseline["combined"]
    print(f"  Initial: Mean={baseline['mean']:.1f}  Spread={baseline['spread']:.1f}  "
          f"Combined={baseline['combined']:.1f}  Max={baseline['max']:.0f}  Time={elapsed:.0f}s")

    results = [{
        "iter": 0, "param": "(initial)", "value": "-",
        "mean": baseline["mean"], "spread": baseline["spread"],
        "combined": baseline["combined"], "max": baseline["max"],
        "delta": 0.0, "time_s": round(elapsed), "decision": "initial",
    }]
    with open(results_csv, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=results[0].keys())
        w.writeheader()
        w.writerow(results[0])

    # Flatten trials
    trials = []
    for param_name, values in EXPLORATION_SCHEDULE:
        for val in values:
            trials.append((param_name, val))

    iteration = 0
    trial_idx = 0
    last_param = None
    consec_fail = 0

    while iteration < MAX_ITERS and trial_idx < len(trials):
        iteration += 1
        param_name, new_value = trials[trial_idx]
        old_value = current_params[param_name]

        # Skip remaining values of a param after 2 consecutive failures
        if consec_fail >= 2 and param_name == last_param:
            while trial_idx < len(trials) and trials[trial_idx][0] == param_name:
                trial_idx += 1
            consec_fail = 0
            last_param = None
            continue

        test_params = copy.deepcopy(current_params)
        test_params[param_name] = new_value

        print(f"\n  [{chorale}] Iter {iteration}: {param_name} = {new_value} (was {old_value})")

        metrics, elapsed = run_iteration(chorale, test_params)

        if metrics is None:
            print(f"    FAILED to evaluate. Skipping.")
            trial_idx += 1
            continue

        delta = metrics["combined"] - best_combined
        improved = delta < -0.1

        if elapsed > TIME_WARN_SECS:
            print(f"    *** WARNING: {elapsed:.0f}s (>{TIME_WARN_SECS}s) ***")

        if improved:
            decision = f"IMPROVED ({param_name}={new_value})"
            current_params[param_name] = new_value
            best_combined = metrics["combined"]
            last_param = param_name
            consec_fail = 0
        else:
            decision = f"no improvement (keeping {param_name}={old_value})"
            if param_name == (last_param or param_name):
                consec_fail += 1
            else:
                consec_fail = 1
            last_param = param_name

        tag = "***" if improved else "   "
        print(f"  {tag} Mean={metrics['mean']:.1f}  Spread={metrics['spread']:.1f}  "
              f"Combined={metrics['combined']:.1f}  Max={metrics['max']:.0f}  "
              f"Delta={delta:+.1f}  Time={elapsed:.0f}s  {decision}")

        row = {
            "iter": iteration, "param": param_name, "value": new_value,
            "mean": metrics["mean"], "spread": metrics["spread"],
            "combined": metrics["combined"], "max": metrics["max"],
            "delta": round(delta, 2), "time_s": round(elapsed), "decision": decision,
        }
        results.append(row)
        with open(results_csv, "a", newline="") as f:
            w = csv.DictWriter(f, fieldnames=row.keys())
            w.writerow(row)

        trial_idx += 1

    # Fill remaining iterations with re-runs of best config
    while iteration < MAX_ITERS:
        iteration += 1
        print(f"\n  [{chorale}] Iter {iteration}: Re-run best config")
        metrics, elapsed = run_iteration(chorale, current_params)
        if metrics is None:
            continue
        delta = metrics["combined"] - best_combined
        if delta < -0.1:
            best_combined = metrics["combined"]
            decision = "IMPROVED (re-run)"
        else:
            decision = "no improvement (re-run)"

        print(f"    Mean={metrics['mean']:.1f}  Spread={metrics['spread']:.1f}  "
              f"Combined={metrics['combined']:.1f}  Max={metrics['max']:.0f}  "
              f"Delta={delta:+.1f}  Time={elapsed:.0f}s  {decision}")

        row = {
            "iter": iteration, "param": "(re-run)", "value": "-",
            "mean": metrics["mean"], "spread": metrics["spread"],
            "combined": metrics["combined"], "max": metrics["max"],
            "delta": round(delta, 2), "time_s": round(elapsed), "decision": decision,
        }
        results.append(row)
        with open(results_csv, "a", newline="") as f:
            w = csv.DictWriter(f, fieldnames=row.keys())
            w.writerow(row)

    # Final evaluation
    final = evaluate(chorale, current_params)

    # Determine which params differ from defaults
    changed = {}
    for k, v in current_params.items():
        if v != BASE_PARAMS[k]:
            changed[k] = v

    total_time = sum(r["time_s"] for r in results)
    improving = [r for r in results if "IMPROVED" in r.get("decision", "")]

    print(f"\n  [{chorale}] DONE — Initial: {baseline['combined']:.1f}  Final: {final['combined']:.1f}  "
          f"Delta: {final['combined'] - baseline['combined']:+.1f}  "
          f"Improvements: {len(improving)}  Time: {total_time // 60:.0f}m{total_time % 60:.0f}s")
    if changed:
        print(f"  [{chorale}] Custom params needed: {changed}")
    else:
        print(f"  [{chorale}] Defaults are optimal — no custom params needed")

    return {
        "chorale": chorale,
        "initial_combined": baseline["combined"],
        "initial_mean": baseline["mean"],
        "initial_spread": baseline["spread"],
        "initial_max": baseline["max"],
        "final_combined": final["combined"],
        "final_mean": final["mean"],
        "final_spread": final["spread"],
        "final_max": final["max"],
        "delta": round(final["combined"] - baseline["combined"], 2),
        "improvements": len(improving),
        "custom_params": json.dumps(changed) if changed else "",
        "total_time_s": total_time,
    }


def main():
    print("=" * 90)
    print("Multi-Chorale Hyperparameter Optimization")
    print(f"Chorales: {', '.join(CHORALES)}")
    print(f"Max iterations per chorale: {MAX_ITERS}")
    print(f"Starting params (v4 defaults optimized on bwv264)")
    print("=" * 90)

    summaries = []
    for chorale in CHORALES:
        summary = optimize_one_chorale(chorale)
        if summary:
            summaries.append(summary)

    # Write combined summary
    if summaries:
        with open(SUMMARY_CSV, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=summaries[0].keys())
            w.writeheader()
            w.writerows(summaries)

    # Print final table
    print("\n" + "=" * 90)
    print("FINAL SUMMARY — All Chorales")
    print("=" * 90)
    print(f"  {'Chorale':<10} {'Init Comb':>10} {'Final Comb':>11} {'Delta':>8} "
          f"{'Mean':>7} {'Spread':>8} {'Max':>6} {'Improv':>7} {'Custom Params'}")
    print(f"  {'-'*10} {'-'*10} {'-'*11} {'-'*8} {'-'*7} {'-'*8} {'-'*6} {'-'*7} {'-'*30}")
    for s in summaries:
        print(f"  {s['chorale']:<10} {s['initial_combined']:>10.1f} {s['final_combined']:>11.1f} "
              f"{s['delta']:>+8.1f} {s['final_mean']:>7.1f} {s['final_spread']:>8.1f} "
              f"{s['final_max']:>6.0f} {s['improvements']:>7} {s['custom_params']}")

    total_time = sum(s["total_time_s"] for s in summaries)
    print(f"\n  Total time: {total_time // 60:.0f}m {total_time % 60:.0f}s")
    print(f"  Summary saved to {SUMMARY_CSV}")

    # Highlight trouble chorales
    needs_custom = [s for s in summaries if s["custom_params"]]
    if needs_custom:
        print(f"\n  Chorales needing custom parameters:")
        for s in needs_custom:
            print(f"    {s['chorale']}: {s['custom_params']}")
    else:
        print(f"\n  All chorales work best with the default parameters!")


if __name__ == "__main__":
    main()
