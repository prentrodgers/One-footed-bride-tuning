#!/usr/bin/env python
"""
SA tuning hyperparameter evaluator.

Takes a JSON config on stdin or as argv[1], runs N trials of SA tuning on
test chords, and prints results as JSON to stdout.

Usage:
    echo '{"ratio_factor": 4.0, "rolls": 5}' | python train.py
    python train.py '{"ratio_factor": 4.0, "rolls": 5}'
"""

import os, sys, time, json, logging
import numpy as np
import argparse

local_dir = os.path.dirname(os.path.abspath(__file__))
if local_dir not in sys.path:
    sys.path.insert(0, local_dir)

# Suppress logging noise from imports
logging.disable(logging.CRITICAL)
import adaptive_tuning_util as atu
from optimize_chords_sa_v2 import build_straw_man_chord_simulated_annealing, roll_and_tune
logging.disable(logging.NOTSET)
logging.root.handlers.clear()
logging.root.setLevel(logging.WARNING)

# ── Test chords ─────────────────────────────────────────────────────────────

CHORDS = {
    'dom7':   np.array([0, 400, 700, 1000], dtype=float),   # C E G Bb
    'dim7':   np.array([0, 300, 600, 900], dtype=float),     # C Eb Gb A
    'maj':    np.array([0, 400, 700, 0], dtype=float),       # C E G C
    'min7':   np.array([0, 300, 700, 1000], dtype=float),    # C Eb G Bb
}

N_TRIALS = 20

# ── Default hyperparameters ─────────────────────────────────────────────────

DEFAULTS = {
    # SA core
    'initial_temperature': 2.5,
    'cooling_rate': 0.95,
    'max_iterations': 200,
    'max_no_improve': 20,
    'spread': 7,
    'elbow_percent': 0.5,
    'r_value': 0.3,
    # Ratio selection
    'max_delta': 33,
    'ratio_factor': 1.0,
    'stability_factor': 0.0,
    # Tuning system
    'tolerance': 4,
    'limit_max': 19,
    # Rolls (0 = single SA, >0 = roll_and_tune)
    'rolls': 0,
    'min_repeats': 3,
}


def build_tuning_objects(limit_max):
    td = atu.build_tonal_diamond(limit_max)[:-1]
    cs = atu.ChordScorer(td)
    lnr = atu.LowNumberRatioIntervals(td)
    return td, cs, lnr


def evaluate(hp, chords=None, collect_traces=False):
    """Run SA on each chord N_TRIALS times. Return per-chord results."""
    if chords is None:
        chords = CHORDS

    td, cs, lnr = build_tuning_objects(hp['limit_max'])
    results = {}
    traces = {} if collect_traces else None

    sa_kwargs = dict(
        tolerance=hp['tolerance'], chord_scorer=cs,
        low_number_ratios=lnr, tonal_diamond=td,
        initial_temperature=hp['initial_temperature'],
        cooling_rate=hp['cooling_rate'],
        max_iterations=hp['max_iterations'],
        max_no_improve=hp['max_no_improve'],
        spread=hp['spread'],
        elbow_percent=hp['elbow_percent'],
        r_value=hp['r_value'],
        max_delta=hp['max_delta'],
        ratio_factor=hp['ratio_factor'],
        stability_factor=hp['stability_factor'],
    )

    for name, cents in chords.items():
        scores, times = [], []
        chord_traces = [] if collect_traces else None
        for trial in range(N_TRIALS):
            prev = np.zeros(len(cents))
            trial_trace = [] if collect_traces else None
            t0 = time.perf_counter()

            if hp['rolls'] > 0:
                tuned, score = roll_and_tune(
                    cents.copy(), prev, chord_num=trial,
                    rolls=hp['rolls'], min_repeats=hp['min_repeats'],
                    trace=trial_trace,
                    **sa_kwargs,
                )
            else:
                tuned, score = build_straw_man_chord_simulated_annealing(
                    cents.copy(), prev, chord_num=trial,
                    trace=trial_trace,
                    **sa_kwargs,
                )

            elapsed = (time.perf_counter() - t0) * 1000
            scores.append(float(score))
            times.append(elapsed)

            if collect_traces and trial_trace:
                chord_traces.append({
                    'chord_name': name,
                    'trial': trial,
                    'initial_cents': cents.tolist(),
                    'final_cents': tuned.tolist(),
                    'initial_score': float(chord_scorer_score(cs, cents, hp['tolerance'])),
                    'final_score': float(score),
                    'events': trial_trace,
                })

        results[name] = {
            'median_score': float(np.median(scores)),
            'min_score': float(np.min(scores)),
            'max_score': float(np.max(scores)),
            'median_ms': round(float(np.median(times)), 2),
            'p90_ms': round(float(np.percentile(times, 90)), 2),
            'scores': [float(s) for s in scores],
        }
        if collect_traces:
            traces[name] = chord_traces

    if collect_traces:
        return results, traces
    return results


def chord_scorer_score(cs, cents, tolerance):
    """Helper to score a chord."""
    return cs.score_chord(cents, tolerance=tolerance)


def generate_animation(traces, output_file='sa_animation.gif', fps=20, max_frames=200):
    """Generate an animated GIF showing SA convergence for the best trial of each chord."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import matplotlib.animation as animation

    # Pick the best trial (lowest final score) for each chord type
    best_trials = {}
    for chord_name, trial_list in traces.items():
        if not trial_list:
            continue
        best = min(trial_list, key=lambda t: t['final_score'])
        best_trials[chord_name] = best

    if not best_trials:
        print("No trace data collected, skipping animation.")
        return

    n_chords = len(best_trials)
    chord_names = list(best_trials.keys())

    fig = plt.figure(figsize=(14, 5 * n_chords))
    gs = fig.add_gridspec(n_chords, 2, hspace=0.4, wspace=0.3)

    # Pre-extract events per chord
    chord_events = {}
    for name in chord_names:
        trial = best_trials[name]
        events = trial['events']
        if max_frames and len(events) > max_frames:
            indices = np.linspace(0, len(events) - 1, max_frames, dtype=int)
            events = [events[i] for i in indices]
        chord_events[name] = events

    total_frames = max(len(evts) for evts in chord_events.values())

    # Create axes
    axes_score = {}
    axes_temp = {}
    for i, name in enumerate(chord_names):
        axes_score[name] = fig.add_subplot(gs[i, 0])
        axes_temp[name] = fig.add_subplot(gs[i, 1])

    def animate(frame_idx):
        for name in chord_names:
            ax_s = axes_score[name]
            ax_t = axes_temp[name]
            ax_s.clear()
            ax_t.clear()

            events = chord_events[name]
            idx = min(frame_idx, len(events) - 1)

            attempts = [e['attempt'] for e in events[:idx + 1]]
            scores = [e['candidate_score'] for e in events[:idx + 1]]
            bests = [e['best_score'] for e in events[:idx + 1]]

            # Score convergence plot
            ax_s.plot(attempts, scores, 'o-', color='#ff7f0e', alpha=0.6,
                      linewidth=1.5, markersize=2, label='Candidate')
            ax_s.plot(attempts, bests, 's-', color='#2ca02c', alpha=0.8,
                      linewidth=2, markersize=3, label='Best')
            ax_s.set_xlabel('Iteration')
            ax_s.set_ylabel('Score')
            trial = best_trials[name]
            ax_s.set_title(f'{name}  [{trial["initial_score"]:.0f} → {trial["final_score"]:.0f}]',
                           fontweight='bold')
            ax_s.legend(loc='upper right', fontsize=8)
            ax_s.grid(alpha=0.3)

            # Temperature plot
            temps = [e['temperature'] for e in events[:idx + 1]]
            ax_t.plot(attempts, temps, '-', color='#d62728', linewidth=2)
            ax_t.set_xlabel('Iteration')
            ax_t.set_ylabel('Temperature')
            ax_t.set_title(f'{name} — Temperature', fontweight='bold')
            ax_t.grid(alpha=0.3)

            event = events[idx]
            status = "IMPROVED" if event['improved_best'] else ("accepted" if event['accept'] else "rejected")
            ax_t.text(0.98, 0.95, f'Score: {event["candidate_score"]:.1f}  ({status})',
                      transform=ax_t.transAxes, ha='right', va='top', fontsize=9,
                      bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

    print(f"Generating animation with {total_frames} frames at {fps} fps...")
    anim = animation.FuncAnimation(fig, animate, frames=total_frames,
                                   interval=1000 / fps, repeat=False, blit=False)
    anim.save(output_file, writer='pillow', fps=fps)
    plt.close(fig)
    print(f"Animation saved to {output_file} ({total_frames / fps:.1f}s)")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='SA tuning hyperparameter evaluator')
    parser.add_argument('config', nargs='?', default=None,
                        help='JSON config string (or pipe via stdin)')
    parser.add_argument('--animate', action='store_true',
                        help='Generate sa_animation.gif showing convergence')
    parser.add_argument('--output', default='sa_animation.gif',
                        help='Output filename for animation (default: sa_animation.gif)')
    parser.add_argument('--fps', type=int, default=20,
                        help='Frames per second for animation (default: 20)')
    parser.add_argument('--max_frames', type=int, default=200,
                        help='Max frames per chord in animation (default: 200)')
    args = parser.parse_args()

    # Read config from argv or stdin
    if args.config:
        hp = json.loads(args.config)
    else:
        hp = json.loads(sys.stdin.read())

    # Merge with defaults
    config = {**DEFAULTS, **hp}

    if args.animate:
        results, traces = evaluate(config, collect_traces=True)
        output = {'config': config, 'results': results}
        print(json.dumps(output, indent=2))
        generate_animation(traces, output_file=args.output, fps=args.fps,
                           max_frames=args.max_frames)
    else:
        results = evaluate(config)
        output = {'config': config, 'results': results}
        print(json.dumps(output, indent=2))
