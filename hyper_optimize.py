#!/usr/bin/env python3
"""
Systematic hyperparameter optimization for Straw_man_tuning_v4.py.

Runs up to 50 iterations, changing one hyperparameter at a time.
After each run, evaluates with analyze_tuned_arrays.py and records results.
The on-disk .npy is only overwritten if the new result is better (v4 merge logic).
"""

import subprocess
import sys
import time
import re
import csv
import json
import os
import copy

CHORALE = "bwv264"
NPY_DIR = "Archive/straw-man"
NPY_FILE = f"{NPY_DIR}/{CHORALE}-opt.npy"
RESULTS_CSV = "hyper_optimize_results.csv"
MAX_ITERS = 50
TIME_WARN_SECS = 300  # warn if a run exceeds 5 minutes

# Starting hyperparameters (from user's command)
BASE_PARAMS = {
    "chorale_list": CHORALE,
    "limit_max": 17,
    "tolerance": 1,
    "ratio_factor": 1.25,
    "max_delta": 33,
    "rolls": 5,
    "sa_iters": 40,
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

# Parameter exploration schedule: list of (param_name, values_to_try)
# Ordered by expected impact. We try each value; if it improves, we keep it
# and optionally push further. If not, the on-disk file stays at its best.
EXPLORATION_SCHEDULE = [
    # Tier 1: SA engine parameters (highest impact on score)
    ("sa_iters",            [60, 80, 100, 120]),
    ("rolls",               [7, 10, 8]),
    ("sa_restarts",         [16, 20, 24]),
    ("parallel_restarts",   [16, 20]),
    ("sa_max_alpha",        [10.0, 6.0, 12.0, 5.0]),
    # Tier 2: Ratio/stability (balance score vs spread)
    ("ratio_factor",        [1.5, 1.0, 1.75, 0.75]),
    ("stability_factor",    [0.75, 1.0, 0.25, 1.5]),
    ("max_delta",           [40, 25, 50]),
    # Tier 3: Post-processing (primarily spread)
    ("max_gap",             [30.0, 25.0, 50.0, 20.0]),
    ("snap_tolerance",      [1.0, 2.0, 3.0]),
    ("tolerance",           [2, 3]),
    # Tier 4: Multi-worker exploration
    ("workers",             [4, 8]),
]


def build_command(params):
    """Build the Straw_man_tuning_v4.py command from params dict."""
    cmd = [sys.executable, "Straw_man_tuning_v4.py"]
    cmd += ["--chorale_list", str(params["chorale_list"])]
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


def evaluate():
    """Run analyze_tuned_arrays.py and parse Mean, Spread, Combined."""
    cmd = [
        sys.executable, "analyze_tuned_arrays.py",
        "--files", NPY_FILE,
        "--tolerance", "1",
        "--limit_max", "17",
        "--spread_weight", "0.5",
        "--suffix=-opt.npy",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    output = result.stdout + result.stderr
    # Parse the table row. Format:
    #   straw-man/bwv264-opt.npy    69.4   3096    111   47   67     79.2      109.0
    for line in output.split("\n"):
        if f"{CHORALE}-opt.npy" in line:
            parts = line.split()
            # Find the filename part, then the numbers after it
            idx = None
            for i, p in enumerate(parts):
                if f"{CHORALE}-opt.npy" in p:
                    idx = i
                    break
            if idx is not None:
                nums = parts[idx + 1:]
                # nums: Mean, Max, MaxCh, p80, p90, Spread, Combined
                if len(nums) >= 7:
                    mean_s = float(nums[0])
                    max_s = float(nums[1])
                    spread = float(nums[5])
                    combined = float(nums[6])
                    return {
                        "mean": mean_s,
                        "max": max_s,
                        "max_ch": int(nums[2]),
                        "p80": float(nums[3]),
                        "p90": float(nums[4]),
                        "spread": spread,
                        "combined": combined,
                    }
    print(f"  WARNING: Could not parse evaluation output:\n{output}")
    return None


def run_iteration(params):
    """Run one tuning iteration. Returns (metrics_dict, elapsed_seconds)."""
    cmd = build_command(params)
    print(f"  CMD: {' '.join(cmd[:6])}... (truncated)")
    t0 = time.time()
    result = subprocess.run(cmd, capture_output=True, text=True)
    elapsed = time.time() - t0

    # Print key lines from output
    for line in result.stdout.split("\n"):
        if any(kw in line for kw in ["better", "mean:", "Continuity", "snap_pitch"]):
            print(f"  > {line.strip()}")

    if result.returncode != 0:
        print(f"  ERROR (rc={result.returncode}): {result.stderr[-500:]}")

    metrics = evaluate()
    return metrics, elapsed


def main():
    print("=" * 90)
    print("Hyperparameter Optimization for Straw_man_tuning_v4.py")
    print(f"Chorale: {CHORALE} | Max iterations: {MAX_ITERS} | Time warning: {TIME_WARN_SECS}s")
    print("=" * 90)

    # Phase 0: baseline
    print("\n--- Iteration 0: Baseline ---")
    baseline = evaluate()
    if baseline is None:
        print("FATAL: Cannot evaluate baseline. Exiting.")
        sys.exit(1)
    print(f"  Mean={baseline['mean']:.1f}  Spread={baseline['spread']:.1f}  "
          f"Combined={baseline['combined']:.1f}  Max={baseline['max']:.0f} (ch {baseline['max_ch']})")

    # Initialize results log
    results = []
    results.append({
        "iter": 0,
        "param": "(baseline)",
        "value": "-",
        "mean": baseline["mean"],
        "spread": baseline["spread"],
        "combined": baseline["combined"],
        "max": baseline["max"],
        "delta": 0.0,
        "time_s": 0,
        "decision": "baseline",
    })

    # Write CSV header
    with open(RESULTS_CSV, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=results[0].keys())
        w.writeheader()
        w.writerow(results[0])

    current_params = copy.deepcopy(BASE_PARAMS)
    best_combined = baseline["combined"]
    iteration = 0

    # Flatten the schedule into individual trials
    trials = []
    for param_name, values in EXPLORATION_SCHEDULE:
        for val in values:
            trials.append((param_name, val))

    trial_idx = 0
    last_improving_param = None
    consecutive_no_improve = 0

    while iteration < MAX_ITERS and trial_idx < len(trials):
        iteration += 1
        param_name, new_value = trials[trial_idx]
        old_value = current_params[param_name]

        # If we've failed 2+ times on the same param, skip remaining values of that param
        if consecutive_no_improve >= 2 and param_name == last_improving_param:
            # Skip ahead to next different parameter
            while trial_idx < len(trials) and trials[trial_idx][0] == param_name:
                trial_idx += 1
            consecutive_no_improve = 0
            last_improving_param = None
            continue

        # Apply the change
        test_params = copy.deepcopy(current_params)
        test_params[param_name] = new_value

        # If workers > 1, also set runs=2 for broader exploration
        if param_name == "workers" and new_value > 1:
            test_params["runs"] = 2

        print(f"\n--- Iteration {iteration}: {param_name} = {new_value} (was {old_value}) ---")

        metrics, elapsed = run_iteration(test_params)

        if metrics is None:
            print(f"  FAILED to evaluate. Skipping.")
            trial_idx += 1
            continue

        delta = metrics["combined"] - best_combined
        improved = delta < -0.1  # meaningful improvement threshold

        if elapsed > TIME_WARN_SECS:
            print(f"  *** WARNING: Run took {elapsed:.0f}s (>{TIME_WARN_SECS}s limit) ***")

        if improved:
            decision = f"IMPROVED (keeping {param_name}={new_value})"
            current_params[param_name] = new_value
            if param_name == "workers" and new_value > 1:
                current_params["runs"] = 2
            best_combined = metrics["combined"]
            last_improving_param = param_name
            consecutive_no_improve = 0
        else:
            decision = f"no improvement (keeping {param_name}={old_value})"
            if param_name == (last_improving_param or param_name):
                consecutive_no_improve += 1
            else:
                consecutive_no_improve = 1
            last_improving_param = param_name

        print(f"  Mean={metrics['mean']:.1f}  Spread={metrics['spread']:.1f}  "
              f"Combined={metrics['combined']:.1f}  Max={metrics['max']:.0f}  "
              f"Delta={delta:+.1f}  Time={elapsed:.0f}s")
        print(f"  -> {decision}")

        row = {
            "iter": iteration,
            "param": param_name,
            "value": new_value,
            "mean": metrics["mean"],
            "spread": metrics["spread"],
            "combined": metrics["combined"],
            "max": metrics["max"],
            "delta": round(delta, 2),
            "time_s": round(elapsed),
            "decision": decision,
        }
        results.append(row)

        # Append to CSV
        with open(RESULTS_CSV, "a", newline="") as f:
            w = csv.DictWriter(f, fieldnames=row.keys())
            w.writerow(row)

        trial_idx += 1

    # If we still have iterations left, re-run best config for additional exploration
    while iteration < MAX_ITERS:
        iteration += 1
        print(f"\n--- Iteration {iteration}: Re-run best config (more SA exploration) ---")
        metrics, elapsed = run_iteration(current_params)
        if metrics is None:
            continue
        delta = metrics["combined"] - best_combined
        if delta < -0.1:
            best_combined = metrics["combined"]
            decision = "IMPROVED (same config re-run)"
        else:
            decision = "no improvement (stochastic re-run)"

        print(f"  Mean={metrics['mean']:.1f}  Spread={metrics['spread']:.1f}  "
              f"Combined={metrics['combined']:.1f}  Max={metrics['max']:.0f}  "
              f"Delta={delta:+.1f}  Time={elapsed:.0f}s")
        print(f"  -> {decision}")

        row = {
            "iter": iteration,
            "param": "(re-run best)",
            "value": "-",
            "mean": metrics["mean"],
            "spread": metrics["spread"],
            "combined": metrics["combined"],
            "max": metrics["max"],
            "delta": round(delta, 2),
            "time_s": round(elapsed),
            "decision": decision,
        }
        results.append(row)
        with open(RESULTS_CSV, "a", newline="") as f:
            w = csv.DictWriter(f, fieldnames=row.keys())
            w.writerow(row)

    # Final summary
    print("\n" + "=" * 90)
    print("FINAL SUMMARY")
    print("=" * 90)
    final = evaluate()
    if final:
        print(f"  Baseline:  Mean={baseline['mean']:.1f}  Spread={baseline['spread']:.1f}  "
              f"Combined={baseline['combined']:.1f}  Max={baseline['max']:.0f}")
        print(f"  Final:     Mean={final['mean']:.1f}  Spread={final['spread']:.1f}  "
              f"Combined={final['combined']:.1f}  Max={final['max']:.0f}")
        print(f"  Delta:     Combined {final['combined'] - baseline['combined']:+.1f}  "
              f"Mean {final['mean'] - baseline['mean']:+.1f}  "
              f"Spread {final['spread'] - baseline['spread']:+.1f}")

    improving = [r for r in results if "IMPROVED" in r.get("decision", "")]
    print(f"\n  Improving iterations: {len(improving)} / {len(results) - 1}")
    if improving:
        print("  Parameters that helped:")
        for r in improving:
            print(f"    iter {r['iter']}: {r['param']}={r['value']} -> combined={r['combined']:.1f} (delta={r['delta']:+.1f})")

    print(f"\n  Best params: {json.dumps({k: v for k, v in current_params.items() if k != 'chorale_list'}, indent=2)}")
    print(f"\n  Results saved to {RESULTS_CSV}")
    total_time = sum(r["time_s"] for r in results)
    print(f"  Total time: {total_time // 60:.0f}m {total_time % 60:.0f}s")


if __name__ == "__main__":
    main()
