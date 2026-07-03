#!/usr/bin/env python
# coding: utf-8
# all imports in one spot:
import os, sys

# Add directories to path for imports
# parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  
# diamond_music_dir = os.path.join(os.path.dirname(parent_dir), 'Diamond_Music') 
local_dir = os.path.dirname(os.path.abspath(__file__))  # One-footed-bride-tuning/

for d in [local_dir]: # , parent_dir, diamond_music_dir might also be required
    if d not in sys.path:
        sys.path.insert(0, d)

import matplotlib.pyplot as plt
from datetime import datetime
from fractions import Fraction
# from importlib import reload
from itertools import count 
from random import seed
from typing import Optional
import music21 as m21
import pprint as pp
import numpy as np
import logging, argparse, math, platform, random, time
       
import adaptive_tuning_util as atu
import diamond_music_utils as dmu 

user = '~'
base_dir = os.path.join(user, 'One-footed-bride-tuning') 
WAVE_DIR = os.path.join(user, 'Music', 'sflib')
os.makedirs(os.path.expanduser(WAVE_DIR), exist_ok=True)
rng = np.random.default_rng()

def parse_params_from_filename(filename):
    """Extract tolerance, ratio_factor, and limit_max from filename.
    
    Expected format: bwv###_t#_r#.###_lm##-trans-sa-opt.npy
    Returns dict with 'tolerance', 'ratio_factor', 'limit_max' or None if not found.
    """
    import re
    basename = os.path.basename(filename)
    # Match pattern: _t(\d+)_r([\d.]+)_lm(\d+)
    match = re.search(r'_t(\d+)_r([\d.]+)_lm(\d+)', basename)
    if match:
        return {
            'tolerance': int(match.group(1)),
            'ratio_factor': float(match.group(2)),
            'limit_max': int(match.group(3))
        }
    return None

stringify = lambda x: '1/1' if x == 1 else str(Fraction(x).limit_denominator(65))
np.set_printoptions(legacy='1.21', precision=3) # don't print the datatypes (np.str_, np.float64() etc, and only 3 decimal places)
# np.set_printoptions(legacy=False) # don't print the datatypes (np.str_, np.float64() etc, and only 3 decimal places)
flats = True # set this to False if the key uses sharps. It will later get set based on reading the key signature from the corpus.
keys = atu.set_accidentals(flats)
# Use local directory for all files
local_dir = os.path.dirname(os.path.abspath(__file__))
CSD_FILE = os.path.join(local_dir, 'ball9.csd')
CSD_C_FILE = os.path.join(local_dir, 'ball9c.csd')
JUPYTER_LOG = os.path.join(local_dir, 'slide_tuning.log')
dmu.start_logger(JUPYTER_LOG, log_level = 'info')
CS_LOGNAME = 'slide_tuning.log' # this doesn't need any directory. 
MIDI_DIR = '.' 
UPLOADS_DIR = os.path.join(local_dir, 'Uploads') 
TRIM_SCRIPT = os.path.join(local_dir, 'trim.sh')
CS_SOURCE_DIR = local_dir
numpy_dir = os.path.join(local_dir, 'Archive', 'opt')

# Density levels 0 (sparsest) to 5 (densest).
# Columns: bass_hold_scale, bass_hold_swing, fp_hold_scale, fp_density_map_index, num_primes
# num_primes controls how many entries from [1,3,5,11,17,31,47,71] are used for chord repeats.
# Sparse → shortest (4-5 primes); moderate → longer (6-7); dense → moderate length (6-7).
# 7/1/26: bass_hold_scale/fp_hold_scale spread doubled around their old centroid (~1.12) so the
# extremes saturate the [1,6]-click duration clamp much more consistently — sparsest levels sit at
# the long-note ceiling almost every draw, densest levels sit at the short-note floor almost every
# draw. bass_part's own internal clip was widened to match (see hold_scale in bass_part).
DENSITY_LEVELS = [
    (2.38, 0.12, 2.38, 5, 4),  # 0: sparsest
    (1.78, 0.22, 1.78, 4, 5),  # 1: sparse
    (1.08, 0.45, 1.08, 3, 7),  # 2: moderate-sparse
    (0.78, 0.55, 0.78, 2, 8),  # 3: moderate-dense
    (0.48, 0.72, 0.48, 1, 7),  # 4: dense
    (0.18, 0.80, 0.18, 0, 6),  # 5: densest
]
# Staccato thinning ratio per density level: sparse → thin more, dense → thin less.
# 7/1/26: pushed toward the valid [0,1] extremes (was 0.9..0.2) for a much more audible contrast.
# 7/1/26 pm: nudged level 5 down a bit further (less thinning = a bit busier) per listening feedback.
FATIGUE_THIN_RATIOS = [0.95, 0.77, 0.59, 0.41, 0.23, 0.02]
FP_DENSITY_MAPS = [
    {'finger_pianos': 'dense',    'pizz_strings': 'dense',    'marimbas': 'dense'},
    {'finger_pianos': 'dense',    'pizz_strings': 'dense',    'marimbas': 'dense'},
    {'finger_pianos': 'moderate', 'pizz_strings': 'moderate', 'marimbas': 'moderate'},
    {'finger_pianos': 'moderate', 'pizz_strings': 'moderate', 'marimbas': 'moderate'},
    {'finger_pianos': 'sparse',   'pizz_strings': 'sparse',   'marimbas': 'sparse'},
    {'finger_pianos': 'sparse',   'pizz_strings': 'sparse',   'marimbas': 'sparse'},
]

# keep track of all the voice features, and where they are in time
voice_time = atu.init_voice_time()
# pp.pprint(voice_time, sort_dicts=False)

# This will display the stacked bar of sections volume levels across all the time sgments
def display_volumes(volume_function, include_sections, save_path: str | None = None, version: str | None = None, dpi: int = 150):
      """Display or save a stacked bar of sections volume levels across time slots.

      If `version` is provided and `save_path` is None, the plot will be saved to
      `{version}.jpg` in the current working directory. If `save_path` is provided
      it will be used directly. If neither is provided, the plot is shown interactively.
      """
      instrument_labels = list(include_sections.keys())
      x = np.arange(volume_function.shape[1])  # x-axis values - number of time slots
      fig, ax = plt.subplots()
      for i in range(len(instrument_labels)):
            print(f'{instrument_labels[i]}\t{volume_function[i]}')
            y = volume_function[i]
            ax.bar(x, y, bottom=np.sum(volume_function[:i], axis=0), label=instrument_labels[i])
      box = ax.get_position()
      ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])
      ax.legend(instrument_labels, loc='center left', bbox_to_anchor=(1, 0.5))
      plt.xticks(range(0,volume_function.shape[1], max(1, volume_function.shape[1]//10))) # what if there are too many to print, can I print every other label?

      plt.tight_layout()
      # Determine output path
      out_path = save_path
      if out_path is None and version is not None:
            out_path = f"{version}.jpg"

      if out_path:
            outdir = os.path.dirname(out_path)
            if outdir:
                  os.makedirs(outdir, exist_ok=True)
            fig.savefig(out_path, dpi=dpi, bbox_inches='tight')
            plt.close(fig)
      else:
            plt.show()
            
# I think I need to get rid of this function and just concentrate on Chorale-info.ipynb.
# def print_scores(version, chorale, limit_max):
#       cent_file_name = os.path.join(numpy_dir, f'{version}-cents.npy')
#       chorale_in_cents = np.load(cent_file_name)
#       # print(f'after np.load {cent_file_name = }, {chorale_in_cents.shape = }')

#       tonal_diamond = np.array(atu.build_tonal_diamond(limit_max, penalize_7_11=False)) 
#       new_scores = np.zeros(chorale_in_cents.shape[1],dtype=int)
#       for inx, chord in zip(count(0,1), chorale_in_cents.T):
#             new_scores[inx] = atu.score_chord_cents_v2(chord, tonal_diamond)
#                   # print(f'{inx}: {chord = }, {new_scores[inx] = }')


#       print(f'{chorale.shape = }, {chorale_in_cents.shape = }, {top_notes.shape = }')
#       print(f'{version = }, Average score: {round(np.average(new_scores),1)}, Max score: {np.max(new_scores)}, Max chord: {np.argmax(new_scores)}')
#       return round(np.average(new_scores),1), np.max(new_scores)


# Create oscillating density mask that varies from sparse to dense multiple times
def create_oscillating_density_probs(n_notes, num_cycles=3, min_prob=0.05, max_prob=0.35, noise_level=0.015, smooth_kernel_size=None):
    """
    Create probability values that oscillate from sparse (low prob) to dense (high prob) 
    multiple times over the course of the piece.

    Args:
        n_notes: Total number of notes/time steps
        num_cycles: How many sparse→dense→sparse cycles
        min_prob: Minimum probability (sparse sections)
        max_prob: Maximum probability (dense sections)
        noise_level: Uniform noise to add to probs (reduce for less randomness)
        smooth_kernel_size: If provided (>1), smooth probs using a moving average of this size

    Returns:
        Array of shape (n_notes,) with oscillating probability values
    """
    # Create a sine wave that oscillates num_cycles times
    t = np.linspace(0, num_cycles * 2 * np.pi, n_notes)
    # Sine goes from -1 to 1, normalize to go from 0 to 1
    oscillation = (np.sin(t) + 1) / 2
    # Scale to go from min_prob to max_prob
    probs = min_prob + oscillation * (max_prob - min_prob)
    # Add some randomness to avoid being too predictable
    if noise_level and noise_level > 0:
        noise = rng.uniform(-noise_level, noise_level, n_notes)
        probs = np.clip(probs + noise, min_prob, max_prob)
    # Optional smoothing to extend dense/sparse runs
    if smooth_kernel_size and smooth_kernel_size > 1:
        kernel = np.ones(smooth_kernel_size) / smooth_kernel_size
        probs = np.convolve(probs, kernel, mode='same')
        probs = np.clip(probs, min_prob, max_prob)
    return probs


def create_oscillating_density_mask(voices, n_notes, num_cycles=3, min_prob=0.05, max_prob=0.35,
                                    noise_level=0.015, min_active=2, correlated=False,
                                    per_voice_bias=None, smooth_kernel_size=None):
    """
    Create a density mask that varies from sparse to dense multiple times.
    Uses the oscillating probability function to generate 0/1 masks.

    New features added:
      - noise_level: control randomness magnitude
      - min_active: ensure at least this many voices are active per time-step
      - correlated: if True, choose exactly k voices per time-step instead of independent Bernoulli draws
      - per_voice_bias: array-like (voices,) to bias some voices to be more/less likely
      - smooth_kernel_size: passed to probs for temporal smoothing

    Args:
        voices: Number of voices
        n_notes: Number of notes/time steps  
        num_cycles: How many sparse→dense→sparse cycles
        min_prob, max_prob: probability range

    Returns:
        Array of shape (voices, n_notes) with 0s and 1s
    """
    probs = create_oscillating_density_probs(n_notes, num_cycles, min_prob, max_prob, noise_level, smooth_kernel_size)

    # Prepare per-voice bias (1.0 means no bias)
    if per_voice_bias is None:
        per_voice_bias = np.ones(voices)
    else:
        per_voice_bias = np.array(per_voice_bias)
        if per_voice_bias.shape[0] != voices:
            # Broadcast or trim/pad to voices
            if per_voice_bias.shape[0] < voices:
                per_voice_bias = np.pad(per_voice_bias, (0, voices - per_voice_bias.shape[0]), 'constant', constant_values=1.0)
            else:
                per_voice_bias = per_voice_bias[:voices]

    density_mask = np.zeros((voices, n_notes), dtype=int)

    for t, p_t in enumerate(probs):
        if correlated:
            # decide how many voices should play at time t
            k = max(min_active, int(round(p_t * voices)))
            k = min(k, voices)
            chosen = rng.choice(np.arange(voices), size=k, replace=False)
            density_mask[chosen, t] = 1
        else:
            # Independent Bernoulli per voice but with per-voice bias applied
            ps = np.clip(p_t * per_voice_bias, min_prob, max_prob)
            draws = rng.random(voices) < ps
            density_mask[:, t] = draws.astype(int)
            # enforce minimum active voices
            active = np.sum(density_mask[:, t])
            if active < min_active:
                need = int(min_active - active)
                candidates = np.where(density_mask[:, t] == 0)[0]
                if candidates.size > 0:
                    add = rng.choice(candidates, size=min(need, candidates.size), replace=False)
                    density_mask[add, t] = 1
    return density_mask


def build_density_multiplier_profile(
    n_steps: int,
    min_block: int = 48,
    max_block: int = 220,
    transition_steps_min: int = 5,
    transition_steps_max: int = 6,
    transition_fraction: float = 0.60,
) -> np.ndarray:
    """Build a piece-level density profile in [1.0, 3.0] with gradual ramps.

    Density targets still orbit around {1, 2, 3}, but moves between them are
    staircase transitions over 5-6 intermediate steps for subtler form changes.
    """
    n_steps = max(1, int(n_steps))
    min_block = max(8, int(min_block))
    max_block = max(min_block, int(max_block))
    transition_steps_min = max(2, int(transition_steps_min))
    transition_steps_max = max(transition_steps_min, int(transition_steps_max))
    transition_fraction = float(np.clip(transition_fraction, 0.20, 0.90))

    profile = np.ones(n_steps, dtype=float)
    current = 1.0
    t = 0

    while t < n_steps:
        target = float(rng.choice([1.0, 2.0, 3.0], p=[0.45, 0.35, 0.20]))
        block = int(rng.integers(min_block, max_block + 1))
        block = min(block, n_steps - t)
        if block <= 0:
            break

        if target == current:
            profile[t:t + block] = current
            t += block
            continue

        transition_steps = int(rng.integers(transition_steps_min, transition_steps_max + 1))
        transition_steps = min(transition_steps, block)
        transition_len = int(round(block * transition_fraction))
        transition_len = max(transition_steps, min(block, transition_len))

        ramp_values = np.linspace(current, target, num=transition_steps + 1, dtype=float)[1:]
        reps = np.full(transition_steps, transition_len // transition_steps, dtype=int)
        reps[:transition_len % transition_steps] += 1

        idx = t
        for value, rep in zip(ramp_values, reps):
            if rep <= 0:
                continue
            end_idx = min(idx + int(rep), t + block)
            profile[idx:end_idx] = float(value)
            idx = end_idx
            if idx >= t + block:
                break

        if idx < t + block:
            profile[idx:t + block] = target

        current = target
        t += block

    return profile


def apply_density_multiplier(mask: np.ndarray, density_profile: np.ndarray | None, min_active_base: int = 1) -> np.ndarray:
    """Increase local activity in mask using a smooth piece-level profile.

    The profile can be fractional in [1.0, 3.0], allowing gradual transitions.
    Higher levels increase temporal dilation and minimum active voices.
    """
    if density_profile is None:
        return mask
    voices, n_steps = mask.shape
    if density_profile.shape[0] < n_steps:
        last = float(density_profile[-1]) if density_profile.shape[0] > 0 else 1.0
        density_profile = np.pad(density_profile.astype(float), (0, n_steps - density_profile.shape[0]), constant_values=last)
    profile = np.clip(density_profile[:n_steps].astype(float), 1.0, 3.0)

    out = mask.copy().astype(int)
    for t in range(n_steps):
        level = float(profile[t])
        span_f = level - 1.0
        span_base = int(np.floor(span_f))
        span_frac = float(span_f - span_base)
        span = span_base + int(rng.random() < span_frac)
        if span > 0:
            lo = max(0, t - span)
            hi = min(n_steps, t + span + 1)
            out[:, t] = np.max(mask[:, lo:hi], axis=1)

        target_f = float(min_active_base) + span_f
        target_base = int(np.floor(target_f))
        target_frac = float(target_f - target_base)
        target_active = target_base + int(rng.random() < target_frac)
        target_active = min(voices, max(min_active_base, target_active))
        active = int(np.sum(out[:, t]))
        if active < target_active:
            candidates = np.where(out[:, t] == 0)[0]
            if candidates.size > 0:
                need = min(target_active - active, candidates.size)
                add = rng.choice(candidates, size=need, replace=False)
                out[add, t] = 1
    return out

def arpeggio_mask_variable_runs(
    chords: np.ndarray,
    min_run: int = 3,
    max_run: int = 7,
    seed: int | None = None,
    verbose: bool = False,
    sparsity_min: float = 0.05,
    sparsity_max: float = 0.40,
    num_cycles: int = 5,
    mutation_factor: float = 0.05,               # probability to mutate a voice between runs
    base_waveform: str = "sine",                 # 'sine','triangle','sawtooth_rise','sawtooth_fall','pulse'
    invert_waveform: bool = False,               # invert waveform
    duty: float = 0.5,                             # duty cycle for pulse wave (fraction 0..1)
    phase_offset: Optional[float] = None,   # <0-1 relative-phase, None → random
) -> np.ndarray:
    """
    Generate a binary mask whose *sparsity* oscillates from
    `sparsity_min` to `sparsity_max` in `num_cycles` full swing over the
    entire chorale.  Instruments can start at arbitrary points in the
    cycle by passing a `phase_offset`.
    """
    rng = np.random.default_rng(seed)
    random.seed(seed)

    voices, time_steps = chords.shape # (8, 3216 or similar)
    mask = np.zeros((voices, time_steps), dtype=int)

    # --------------------------------------------------------------------
    # Phase offset – if none, pick a *random* value in [0, 1)
    # --------------------------------------------------------------------
    if phase_offset is None:
        phase_offset = rng.random()
    else:
        if not (0.0 <= phase_offset <= 1.0):
            raise ValueError("phase_offset must be in [0, 1]")

    t = 0
    while t < time_steps:
        # 1️⃣ Run-length
        run_length = rng.integers(min_run, max_run + 1)
        run_length = min(run_length, time_steps - t)

        # 2️⃣ Compute the *current* sparsity value
        # The center of this run in “time-fraction” terms
        center_frac = (t + run_length / 2.0) / time_steps
        # Offset the full cycle and compute position inside a single cycle (0..1)
        current_frac = (phase_offset + center_frac) % 1.0
        cycle_pos = (num_cycles * current_frac) % 1.0

        # Map the cycle position to a normalized value in [0, 1] depending on waveform
        if base_waveform == "sine":
            phase = np.sin(2 * np.pi * cycle_pos)
            normalized = (phase + 1.0) / 2.0
        elif base_waveform == "triangle":
            if cycle_pos < 0.5:
                normalized = 2.0 * cycle_pos
            else:
                normalized = 2.0 * (1.0 - cycle_pos)
        elif base_waveform == "sawtooth_rise":
            normalized = cycle_pos
        elif base_waveform == "sawtooth_fall":
            normalized = 1.0 - cycle_pos
        elif base_waveform in ("pulse", "square"):
            if not (0.0 <= duty <= 1.0):
                raise ValueError("duty must be in [0, 1]")
            normalized = 1.0 if cycle_pos < duty else 0.0
        else:
            raise ValueError(f"Unknown base_waveform: {base_waveform}")

        if invert_waveform:
            normalized = 1.0 - normalized

        sparsity = sparsity_min + (sparsity_max - sparsity_min) * normalized

        # 3️⃣ Create a base pattern for this run
        base_pattern = np.zeros((voices, run_length), dtype=int)
        for step in range(run_length):
            # Denser default for percussive/arpeggiated sections so they do not thin out too much.
            num_active = rng.choice([2, 3, 4, 5], p=[0.10, 0.35, 0.35, 0.20])
            active_rows = rng.choice(voices, size=num_active, replace=False)
            base_pattern[active_rows, step] = 1

        # 4️⃣ Apply the computed sparsity (remove that many 1-bits)
        total_ones = base_pattern.sum()
        n_zeros_to_add = int(round(total_ones * sparsity))
        if n_zeros_to_add > 0:
            ones_indices = np.argwhere(base_pattern == 1)
            zero_indices = rng.choice(ones_indices.shape[0],
                                      size=n_zeros_to_add,
                                      replace=False)
            base_pattern[ones_indices[zero_indices, 0],
                         ones_indices[zero_indices, 1]] = 0

        # 5️⃣ Insert the run into the global mask
        mask[:, t : t + run_length] = base_pattern
        logging.debug(f'In arpeggio_mask_variable_runs. Started new run at {t = }, {num_cycles = }, {run_length = }, {sparsity = :.2f}, {np.sum(base_pattern) = }')
        # 6️⃣ Subtle mutation for next run
        if t + run_length < time_steps:
            for v in range(voices):
                if rng.random() < mutation_factor:  # flip a note’s state # chance of flipping 0 to 1 or 1 to 0
                    base_pattern[v, :] = 1 - base_pattern[v, :]

        t += run_length

    if verbose:
        print(f"Generated arpeggio mask with phase_offset={phase_offset}:\n{mask}")

    return mask


def plot_sparsity_waveform(
    time_steps: int = 400,
    num_cycles: int = 5,
    base_waveform: str = "sine",
    duty: float = 0.5,
    invert_waveform: bool = False,
    sparsity_min: float = 0.05,
    sparsity_max: float = 0.40,
    phase_offset: float = 0.0,
    figsize: tuple = (10, 3),
    save_path: str | None = None,
):
    """Plot waveform (normalized) and mapped sparsity over time.

    Useful to visualize how `base_waveform` and `duty` (for pulse)
    affect the sparsity function.
    """
    
    normalized_vals = []
    for t in range(time_steps):
        center_frac = (t + 0.5) / time_steps
        current_frac = (phase_offset + center_frac) % 1.0
        cycle_pos = (num_cycles * current_frac) % 1.0

        if base_waveform == "sine":
            phase = np.sin(2 * np.pi * cycle_pos)
            normalized = (phase + 1.0) / 2.0
        elif base_waveform == "triangle":
            if cycle_pos < 0.5:
                normalized = 2.0 * cycle_pos
            else:
                normalized = 2.0 * (1.0 - cycle_pos)
        elif base_waveform == "sawtooth_rise":
            normalized = cycle_pos
        elif base_waveform == "sawtooth_fall":
            normalized = 1.0 - cycle_pos
        elif base_waveform in ("pulse", "square"):
            if not (0.0 <= duty <= 1.0):
                raise ValueError("duty must be in [0, 1]")
            normalized = 1.0 if cycle_pos < duty else 0.0
        else:
            raise ValueError(f"Unknown base_waveform: {base_waveform}")

        if invert_waveform:
            normalized = 1.0 - normalized

        normalized_vals.append(normalized)

    normalized_vals = np.array(normalized_vals)
    sparsity = sparsity_min + (sparsity_max - sparsity_min) * normalized_vals

    fig, axes = plt.subplots(1, 2, figsize=figsize)
    axes[0].plot(normalized_vals, lw=1.5)
    axes[0].set_title(f"Normalized waveform: {base_waveform} (duty={duty})")
    axes[0].set_ylim(-0.05, 1.05)
    axes[0].set_ylabel('normalized')

    axes[1].plot(sparsity, lw=1.5)
    axes[1].set_title('Sparsity (mapped)')
    axes[1].set_ylim(-0.05, 1.05)
    axes[1].set_ylabel('sparsity')

    plt.tight_layout()
    if save_path:
        outdir = os.path.dirname(save_path)
        if outdir:
            os.makedirs(outdir, exist_ok=True)
        fig.savefig(save_path, dpi=150)
        plt.close(fig)
    else:
        plt.show()



def thin_staccato_chains(
    notes_features: np.ndarray,
    min_chain_len: int = 6,
    thin_ratio: float = 0.5,
    preserve_head: int = 2,
    preserve_tail: int = 1,
    density_threshold: int = 2,
) -> np.ndarray:
    """Silence notes inside long runs of 0.25-duration events by setting octave (col 5) to 0.

    Notes are never removed — their time-slot position is preserved so downstream
    start-time sequencing stays intact.  Only the octave field is zeroed, which
    subsequent processes treat as silence.

    Phase 1 — per-voice: finds chains of consecutive 0.25-duration notes within each
    voice (col 6) independently, preventing false chains at voice boundaries.

    Phase 2 — cross-voice temporal: computes per-voice start times by accumulating
    durations, bins notes onto a 0.25 grid, then finds runs of consecutive time bins
    where >= density_threshold voices are all playing staccato simultaneously.  The
    interior bins of qualifying runs are thinned the same way as Phase 1 chains.

    Args:
        notes_features:    Shape (N, 15) array from piano_roll_to_notes_features.
        min_chain_len:     Minimum consecutive qualifying events before thinning starts.
                           Phase 1: consecutive 0.25-duration notes per voice.
                           Phase 2: consecutive dense time bins.
        thin_ratio:        Fraction of interior audible notes to silence (0.0=off, 1.0=all).
        preserve_head:     Events at the start of each chain/run that are always kept.
        preserve_tail:     Events at the end of each chain/run that are always kept.
        density_threshold: (Phase 2 only) Minimum simultaneous staccato voices per time
                           bin for that bin to be considered dense (default 2).

    Returns:
        Modified copy of notes_features with some octaves zeroed.
    """
    if thin_ratio <= 0.0 or notes_features.shape[0] == 0:
        return notes_features
    out = notes_features.copy()
    zeros_before = int(np.sum(out[:, 5] == 0))
    p1_silenced = 0

    # --- Phase 1: per-voice chain detection ---
    for voice_num in np.unique(out[:, 6].astype(int)):
        indices = np.where(out[:, 6].astype(int) == voice_num)[0]
        durations = np.round(out[indices, 1], 2)
        n = len(durations)
        i = 0
        while i < n:
            if durations[i] == 0.25:
                j = i
                while j < n and durations[j] == 0.25:
                    j += 1
                chain_len = j - i
                if chain_len >= min_chain_len:
                    interior_start = i + preserve_head
                    interior_end = j - preserve_tail
                    if interior_end > interior_start:
                        interior = np.arange(interior_start, interior_end)
                        audible = interior[out[indices[interior], 5] != 0]
                        n_thin = math.ceil(len(audible) * thin_ratio)
                        if n_thin > 0:
                            chosen = rng.choice(audible, size=n_thin, replace=False)
                            out[indices[chosen], 5] = 0
                            p1_silenced += n_thin
                i = j
            else:
                i += 1
    logging.info(f'thin_staccato_chains phase1: silenced {p1_silenced} notes')

    # --- Phase 2: cross-voice temporal density ---
    tick = 0.25
    p2_silenced = 0
    # Compute per-voice start times by accumulating durations
    start_times = np.zeros(len(out))
    for voice_num in np.unique(out[:, 6].astype(int)):
        v_idx = np.where(out[:, 6].astype(int) == voice_num)[0]
        durs = out[v_idx, 1]
        start_times[v_idx] = np.concatenate([[0.0], np.cumsum(durs[:-1])])

    # Collect audible staccato rows (after Phase 1 may have zeroed some)
    staccato_mask = (np.round(out[:, 1], 2) == tick) & (out[:, 5] != 0)
    staccato_idx = np.where(staccato_mask)[0]
    logging.info(
        f'thin_staccato_chains phase2: {len(staccato_idx)} audible staccato notes '
        f'(density_threshold={density_threshold}, min_chain_len={min_chain_len})'
    )

    p2_qualifying_runs = 0
    p2_interior_bins = 0
    if len(staccato_idx) > 0:
        # Bin to integer tick grid to avoid float comparison issues
        int_ticks = np.round(start_times[staccato_idx] / tick).astype(int)
        # Build map: tick_bin -> list of row indices
        bin_map: dict[int, list[int]] = {}
        for row_idx, t in zip(staccato_idx, int_ticks):
            bin_map.setdefault(int(t), []).append(int(row_idx))
        # Dense bins have >= density_threshold simultaneous staccato voices
        dense_bins = sorted(t for t, rows in bin_map.items() if len(rows) >= density_threshold)
        logging.info(
            f'thin_staccato_chains phase2: {len(bin_map)} total bins, '
            f'{len(dense_bins)} dense bins (>={density_threshold} voices)'
        )
        # Find runs of consecutive dense bins (gap of exactly 1 tick)
        if len(dense_bins) >= min_chain_len:
            runs: list[list[int]] = []
            run: list[int] = [dense_bins[0]]
            for t in dense_bins[1:]:
                if t - run[-1] == 1:
                    run.append(t)
                else:
                    runs.append(run)
                    run = [t]
            runs.append(run)
            qualifying_runs = [r for r in runs if len(r) >= min_chain_len]
            p2_qualifying_runs = len(qualifying_runs)
            logging.info(
                f'thin_staccato_chains phase2: {len(runs)} runs found, '
                f'{p2_qualifying_runs} qualify (>={min_chain_len} bins)'
            )
            for run in qualifying_runs:
                interior = run[preserve_head: len(run) - preserve_tail]
                p2_interior_bins += len(interior)
                for t in interior:
                    candidates = np.array(bin_map[t])
                    n_thin = math.ceil(len(candidates) * thin_ratio)
                    if n_thin > 0:
                        chosen = rng.choice(candidates, size=n_thin, replace=False)
                        out[chosen, 5] = 0
                        p2_silenced += n_thin
        else:
            logging.info(
                f'thin_staccato_chains phase2: {len(dense_bins)} dense bins — '
                f'need {min_chain_len} consecutive to qualify, no runs triggered'
            )
    logging.info(
        f'thin_staccato_chains phase2: silenced {p2_silenced} notes '
        f'across {p2_qualifying_runs} runs ({p2_interior_bins} interior bins)'
    )

    zeros_after = int(np.sum(out[:, 5] == 0))
    logging.info(
        f'thin_staccato_chains total: silenced {p1_silenced + p2_silenced} notes '
        f'(zero-octave rows: {zeros_before} -> {zeros_after} of {len(out)})'
    )
    return out


# define the functions for the bass instruments, much like the finger_piano_part, except it only includes tenor and bass voices
# chorale is already had repeats applied to it when it arrives here.
def bass_part(chorale, glides, repeats, voice_names, voice_time, tpq, volume_function, probs = None, fp_volume = 1, bass_sustain=15,
              bass_hold_scale=1.0, bass_hold_swing=0.75, bass_hold_cycles=4, density_profile: np.ndarray | None = None,
              rescue_probability=0.5, ftable_308_prob=0.25,
              deep_bass_backoff=1.0, back_off_clicks=0.0):
    # set the default value for probs if it is not passed as a keyword argument.
    if probs is None:
        probs = [[0.99, 0.01], [0.95627622, 0.04372378]]
    logging.info(f'in bass_part at the start of the function. {chorale.shape = }, {glides.shape = }')
    print(f'probs of getting a one: {sum(probs) = }, values: {[round(i[1],4) for i in probs]}') 
    voices = voice_names.shape[0] # if you want it to last twice as long, make twice as many voices: voice_names.shape[0] * 2, or increase the value of repeats
    bass_chorale_in_cents_octaves = chorale.copy()
    copy_mask = rng.random(chorale.shape[1]) < 0.8  # each chord independently: 80% chance soprano/alto replaced by tenor/bass
    bass_chorale_in_cents_octaves[:2, copy_mask, :] = chorale[2:, copy_mask, :]
    chorale = bass_chorale_in_cents_octaves.copy()
    chorale = np.repeat(chorale, voices // 4, axis = 0) # double the number of voices
    glides = np.repeat(glides, voices // 4, axis = 0) # double the number of voices
    logging.debug(f'after doubling voices: {chorale.shape = }, {glides.shape = }') # (8, 3216, 2)
    # revised volume_array use a spline function 5/21/23
    logging.debug(f'{volume_function = }') # array([7, 7, 1, 3, 1, 1, 1, 4, 6]) # approximately 9 values
    sustain = bass_sustain  # Influences how quickly the volume changes. Higher values = slower changes.
    # this next line needs to have an integer value for repeats. That will require everyone calling bass_part (and all the other xxx_part functions) to pass the average of the repeats as an integer. That would be repeats_average. I pass repeats_average and this function calls it repeats. 
    # volume_function in the xx_part functions is just the slice of the global volume_function that applies to that part
    vol_arr_size = volume_function.shape[0] * rng.choice([1,2,3,4]) # make the volume array size a multiple of the number of sections in the part
    logging.info(f'In bass_part. About to smooth the volume function using build_density_function with {volume_function.shape = }, {vol_arr_size = }')
    logging.info(f'{volume_function = }')
    volume_array = dmu.build_density_function(volume_function, vol_arr_size) 
    logging.info(f'{volume_array.shape = }')
    logging.info(f'{volume_array = }')
    n_cycles = rng.choice([3, 4])
    t = np.linspace(0, n_cycles, volume_array.shape[0])
    sustain_ramp = np.round(1 + (sustain - 1) * (1 - np.abs(2 * (t % 1) - 1))).astype(int)
    volume_array = np.clip(np.repeat(volume_array, repeats * sustain_ramp, axis=0), 0, 14)
    volume_array = volume_array[:chorale.shape[1]] # truncate to the length of the chorale
    volume_array = volume_array[:-24] # truncate so percussion ends before sustained instruments
    logging.debug(f'after repeat & clip: {volume_array.shape = }, {repeats = }, {sustain = }')
    # revised 3/22/23 - 3/28/23
    # revise 4/7/23 to move build_notes_features earlier in the stack.
    logging.debug(f'{chorale.shape = }') # all must be the same shape, (2,2), (3,2) etc. 
    gls = np.array([[0, 0], [0, 0], [0, 0], [0, 0]]) # no slides for the you here. See atu.add_features_glides below
    gls_p = np.array([[.5, .5], [.5, .5], [.5, .5], [.5, .5]])
    ups = np.array([[-1, 0], [-2, 1], [1, 2], [-2, -1]])
    ups_p = np.array([[.5, .5], [.5, .5], [.5, .5], [.5, .5]])
    env = np.array([[1, 0], [2, 8], [16, 17], [2, 8]])
    env_p = np.array([[.5, .5], [.8, .2], [.5, .5], [.5, .5] ])
    vel = np.array([[71, 74], [74, 77], [76, 79], [73, 76]])
    vel -= 3 # lower the volume on the bass parts to avoid clipping
    vel_p = np.array([[.5, .5], [.5, .5], [.5, .5], [.5, .5]])
    guev_array = np.stack((gls, gls_p, ups, ups_p, env, env_p, vel, vel_p), axis = 0)
    rng.shuffle(guev_array, axis=1)
    logging.debug(f'In bass_part. feature array after stack. {guev_array.shape = }') # guev_array.shape = (8, 3, 2)
    notes_features_6 = atu.add_features_glides(chorale, glides, guev_array) # start with the chorale, which is (notes, octaves), and add the gls, ups, env, & vel arrays
    logging.debug(f'after loading notes_features_6.{notes_features_6.shape = }')
    logging.debug([np.unique(feature, return_counts = True) for feature in notes_features_6])
    octave_array = notes_features_6[1] # all the octaves for all the voices, notes
    # create an array to mask some notes. This will be used to set octave = 0, which makes them silent
    # Structured arpeggio density (same direction as finger_piano_part), but denser:
    # two interleaved streams in each quartet for roughly 2x bass activity.
    n_steps = chorale.shape[1]
    density_function = np.zeros((voices, n_steps), dtype=int)
    hold_scale = float(np.clip(bass_hold_scale, 0.15, 2.5))  # 7/1/26: widened to match the doubled DENSITY_LEVELS spread
    hold_cycles = max(1, int(bass_hold_cycles))
    mode_phase = {'dense': 0, 'moderate': 2, 'sparse': 4}
    base_patterns = np.array([
        [0, 1, 2, 3, 0, 1, 2, 3],
        [0, 2, 1, 3, 0, 2, 1, 3],
        [0, 1, 3, 2, 0, 1, 3, 2],
        [0, 2, 3, 1, 0, 2, 3, 1],
    ], dtype=int)

    # Use hold_swing as a soft selector for start mode.
    if bass_hold_swing > 0.66:
        density_mode = 'dense'
    elif bass_hold_swing < 0.33:
        density_mode = 'sparse'
    else:
        density_mode = 'moderate'

    chord_changes = np.where(np.any(np.diff(chorale[:4, :, 0], axis=1) != 0, axis=0))[0] + 1
    boundaries = np.concatenate(([0], chord_changes, [n_steps]))
    pattern = base_patterns[1].copy()
    hold_chords_target = int(rng.integers(2, 5))
    held_chords = 0

    # Evolving mixed click durations (1..6), with one-slot morphing.
    rhythm_mix = rng.integers(1, 7, size=6).astype(int)
    rhythm_hold_chords = max(1, int(round(rng.integers(1, 11) / min(3, hold_cycles))))
    rhythm_chords_used = 0
    rhythm_event_num = 0

    for chord_idx in range(boundaries.shape[0] - 1):
        start = int(boundaries[chord_idx])
        end = int(boundaries[chord_idx + 1])
        seg_len = max(0, end - start)
        if seg_len == 0:
            continue

        if held_chords >= hold_chords_target:
            mutate_inx = int(rng.integers(0, pattern.shape[0]))
            step_dir = -1 if rng.random() < 0.5 else 1
            pattern[mutate_inx] = (pattern[mutate_inx] + step_dir) % 4
            hold_chords_target = int(rng.integers(2, 5))
            held_chords = 0
        held_chords += 1

        if rhythm_chords_used >= rhythm_hold_chords:
            mutate_rhythm_inx = int(rng.integers(0, rhythm_mix.shape[0]))
            delta = -1 if rng.random() < 0.5 else 1
            rhythm_mix[mutate_rhythm_inx] = int(np.clip(rhythm_mix[mutate_rhythm_inx] + delta, 1, 6))
            rhythm_hold_chords = max(1, int(round(rng.integers(1, 11) / min(3, hold_cycles))))
            rhythm_chords_used = 0
        rhythm_chords_used += 1

        phase = (mode_phase.get(density_mode, 2) + chord_idx) % pattern.shape[0]
        twin_offset = 1 if (chord_idx % 2 == 1) else 0
        pos = 0
        while pos < seg_len:
            base_dur = int(rhythm_mix[rhythm_event_num % rhythm_mix.shape[0]])
            dur = int(np.clip(round(base_dur * hold_scale), 1, 6))
            dur = min(dur, seg_len - pos)
            lo = start + pos
            hi = lo + dur

            # Stream A
            pvoice_a = int(pattern[(phase + rhythm_event_num) % pattern.shape[0]])
            density_function[pvoice_a, lo:hi] = 1
            density_function[(pvoice_a + twin_offset) % 4 + 4, lo:hi] = 1
            # Stream B (interleaved) -> raises density approximately 2x; skipped in sparse mode
            if density_mode != 'sparse':
                pvoice_b = int(pattern[(phase + rhythm_event_num + 2) % pattern.shape[0]])
                density_function[pvoice_b, lo:hi] = 1
                density_function[(pvoice_b + twin_offset) % 4 + 4, lo:hi] = 1

            pos += dur
            rhythm_event_num += 1
    density_function = apply_density_multiplier(density_function, density_profile, min_active_base=2)
    logging.info(f'bass arpeggio-density: {np.sum(density_function) = }, {np.sum(density_function == 0) = }, {hold_scale = }, {hold_cycles = }, {density_mode = }')

    logging.info(f'after first creation: {density_function.shape = }') # after first creation: density_function.shape = 
    logging.info(f'after creation: {np.sum(density_function) = }, {np.sum(density_function == 0) = }, {np.sum(density_function == 1) = }, Percentage of ones: {np.sum(density_function == 1) / np.sum(density_function == 0) * 100:.1f}%')

    logging.info(f'{octave_array.shape = }, {np.sum(octave_array) = } {density_function.shape = }, {np.sum(density_function) = }') # octave_array.shape = (8, 6480), density_function.shape = (8, 6500)
    # changed on 5/21/23 - make sure it doesn't mess up the octaves as zeros
    octave_stretch = 4 # if 3, you might get -1, 0, 1 or just 2 numbers
    stay = 16 # maximum time you might stay with the same octave * repeats (increased from 7 for longer bass note durations)
    octave_reduce = 4  # stretch=4, reduce=4: range is now -4,-3,-2,-1; 4 only reachable from base-5 notes (rare, ~63% of those)
    octave_alteration_mask = atu.build_octave_alteration_mask(repeats, voices, chorale, octave_reduce=octave_reduce,\
        octave_stretch=octave_stretch, stay=stay) # set the probability of each octave being used. Some very low, some very high, but most in the middle 3 choices
    logging.info('bass_part. octave_alteration_mask buckets: values, counts')
    logging.debug(f'{octave_alteration_mask.shape = }')
    logging.info(f'octave_array prior to spread:  {np.unique(octave_array, return_counts=True)}')
    # don't touch an octave that is already zero, but alter the others. Zero means silence, so don't change it.
    for voice in np.arange(octave_array.shape[0]):
        for note in np.arange(octave_array.shape[1]):
                if octave_array[voice, note] > 0: octave_array[voice, note] += octave_alteration_mask[voice, note]
    logging.info(f'before masking: {np.sum(octave_array) = }')
    logging.info(f'about to mask the octave array with the density_function: {density_function[:, :octave_array.shape[1]].shape = }')
    octave_array = octave_array * density_function[:, :octave_array.shape[1]] # make the octave go to zero for some percent of the notes
    logging.info(f'after masking. {np.sum(octave_array) = }')
    logging.info(f'octave_array after spread: {np.unique(octave_array, return_counts=True)}')
    octave_array = np.clip(octave_array, 0, 4) # clip octaves: 0=silence, max 4 (5 removed)
    logging.info(f'after clipping negatives to 0: {np.unique(octave_array, return_counts=True)}')
    logging.info(f'{notes_features_6.shape = }') #                             0      1        2      3         4         5
    notes_features_6[1] = octave_array #  add_features returns this :np.stack((notes, octaves, gliss, upsample, envelope, velocity), axis = 0)
    volume_array += fp_volume
    notes_features_15 = dmu.piano_roll_to_notes_features(notes_features_6, volume_array, voice_names, tpq, voice_time)
    notes_features_15 = atu.clip_note_features(notes_features_15, voice_time) # make sure the octaves are in range and the volume adjusted per the voice_time dictionary
    # notes_features_15 contains one row for every note: note, oct, glis, ups, env, vel, vol, voice,
    logging.debug(f'{notes_features_15.shape = }')
    # Bass finger piano notes at octave 0 would be silenced by the row[5]>0 filter.
    # At this stage column 6 contains time_tracker_number (not final csound_voice),
    # so derive the relevant tracker IDs from the incoming voice names.
    # Density-aware rescue: bump to octave 1, apply glissando (f307 or f308) to drop back 1 or 2 octaves.
    # Rescue probability varies by local density: 75% sparse, 50% medium, 25% dense.
    bfin_trackers = np.array(
        [
            voice_time[v]["time_tracker_number"]
            for v in voice_names
            if voice_time[v]["csound_voice"] == 24
        ],
        dtype=int,
    )
    bfin_oct0 = np.isin(notes_features_15[:, 6].astype(int), bfin_trackers) & (notes_features_15[:, 5] == 0)
    
    if np.any(bfin_oct0):
        oct0_indices = np.where(bfin_oct0)[0]
        num_oct0_notes = len(oct0_indices)
        
        # Calculate density-aware rescue probabilities
        rescue_probs = np.zeros(num_oct0_notes)
        density_window = 50  # Look at ±50 notes for local density
        
        for i, idx in enumerate(oct0_indices):
            # Calculate local density (fraction of sounding notes in window)
            window_start = max(0, idx - density_window)
            window_end = min(len(notes_features_15), idx + density_window)
            local_notes = notes_features_15[window_start:window_end]
            local_density = np.mean(local_notes[:, 5] > 0)
            
            # Density-based rescue probability
            if local_density < 0.3:      # Sparse
                rescue_probs[i] = 0.75
            elif local_density > 0.6:    # Dense
                rescue_probs[i] = 0.25
            else:                        # Medium
                rescue_probs[i] = 0.50
        
        # Apply back_off_clicks: skip rescue entirely for short-duration notes (col 1 = duration).
        if back_off_clicks > 0:
            short_dur = notes_features_15[oct0_indices, 1] <= back_off_clicks
            rescue_probs[short_dur] = 0.0
        # Apply deep_bass_backoff: scale all rescue probabilities down.
        rescue_probs *= deep_bass_backoff
        # Apply rescue based on probabilities
        rescue_mask = rng.random(num_oct0_notes) < rescue_probs
        rescue_indices = oct0_indices[rescue_mask]
        num_rescued = len(rescue_indices)
        
        if num_rescued > 0:
            # Set octave to 1 for all rescued notes
            notes_features_15[rescue_indices, 5] = 1
            
            # Randomly choose between f307 (75%) and f308 (25%) for each rescued note
            ftable_choices = rng.random(num_rescued) < ftable_308_prob
            
            # Apply f307 (1-octave drop) to 75% of rescued notes
            f307_indices = rescue_indices[~ftable_choices]
            notes_features_15[f307_indices, 10] = 252  # upsample: 4 slots lower (256-4)
            notes_features_15[f307_indices, 12] = 307  # glissando: f307 constant 0.5 (one octave down)
            
            # Apply f308 (2-octave drop) to 25% of rescued notes
            f308_indices = rescue_indices[ftable_choices]
            notes_features_15[f308_indices, 10] = 248  # upsample: 8 slots lower (256-8)
            notes_features_15[f308_indices, 12] = 308  # glissando: f308 constant 0.25 (two octaves down)
            
            # Logging
            num_f307 = len(f307_indices)
            num_f308 = len(f308_indices)
            avg_rescue_prob = rescue_probs[rescue_mask].mean()
            
            logging.info(f'bass_part: octave-0 rescue applied to {num_rescued}/{num_oct0_notes} notes ({num_rescued/num_oct0_notes*100:.1f}%)')
            logging.info(f'  - f307 (1-oct): {num_f307} notes ({num_f307/num_rescued*100:.1f}%)')
            logging.info(f'  - f308 (2-oct): {num_f308} notes ({num_f308/num_rescued*100:.1f}%)')
            logging.info(f'  - avg rescue probability: {avg_rescue_prob:.2f}')
    # np.save('bass_part_notes_features.npy', notes_features_15)
    return notes_features_15
# end of bass_part


def bwv846_mask_patterned(
    chorale_pc: np.ndarray,
    swap_ones_for_zeros: float = 0.1,
    extend_set: float = 0.1,
    rng: np.random.Generator | None = None
) -> np.ndarray:
    """
    Generate a BWV846-style activation mask for an SATBSATB chorale array,
    with optional random inversion and optional 12-step block extensions.

    Guarantees:
    • Always returns an array of shape (8, N)
    • No early None returns
    • No broadcasting errors
    • No short final blocks
    """

    if rng is None:
        rng = np.random.default_rng()

    voices, N = chorale_pc.shape
    assert voices == 8, "Expected shape (8, N)."

    # --- Base BWV 846 8-step SATB pattern ---
    soprano = np.array([0,0,0,1, 1,0,0,1])
    alto    = np.array([0,0,1,0, 0,0,1,0])
    tenor   = np.array([0,1,1,1, 0,1,0,0])
    bass    = np.array([1,1,1,1, 1,1,1,0])  # last step zero

    pattern = np.stack([soprano, alto, tenor, bass])  # shape (4, 8)

    # --- Build blocks until we exceed N ---
    blocks = []
    total_len = 0

    while total_len < N:
        block = pattern.copy()

        # Mutation 1: inversion of half-block
        if rng.random() < swap_ones_for_zeros:
            cols = slice(0, 4) if rng.random() < 0.5 else slice(4, 8)
            block[:, cols] ^= 1

        # Mutation 2: extend to 12 steps
        if rng.random() < extend_set:
            block = np.concatenate([block, block[:, 4:8]], axis=1)

        blocks.append(block)
        total_len += block.shape[1]

    # --- Concatenate blocks ---
    base = np.concatenate(blocks, axis=1)

    # --- Ensure at least N columns ---
    if base.shape[1] < N:
        # Pad with zeros (or could repeat pattern if preferred)
        pad = np.zeros((4, N - base.shape[1]), dtype=int)
        base = np.concatenate([base, pad], axis=1)

    # --- Trim to exactly N ---
    base = base[:, :N]

    # --- Duplicate SATB → SATB ---
    mask = np.zeros((8, N), dtype=int)
    mask[0:4, :] = base
    mask[4:8, :] = base

    return mask


# define the functions for the arpeggiated parts, finger piano, pizzicato strings, guitars, harp, etc.
def finger_piano_part(chorale, glides, repeats, voice_names, voice_time, tpq, volume_function, probs = None, fp_volume = 0,
                      density_start: str = 'moderate', density_profile: np.ndarray | None = None, fp_hold_scale: float = 1.0):
    # set the default value for probs if it is not passed as a keyword argument.
    if probs is None:
        probs = [[0.99, 0.01], [0.95627622, 0.04372378]]
    logging.info(f'in finger_piano_part. {chorale.shape = }, {glides.shape = }, {repeats = }, {voice_names = }, {probs = }')
    print(f'probs of getting a one: {sum(probs) = }, values: {[round(i[1],4) for i in probs]}') 
    voices = voice_names.shape[0] # if you want it to last twice as long, make twice as many voices: voice_names.shape[0] * 2, or increase the value of repeats

    logging.debug(f'after repeating each note {1 = }: {chorale.shape = }, {glides.shape = }')
    chorale = np.repeat(chorale, voices // 4, axis = 0) # double the number of voices
    glides = np.repeat(glides, voices // 4, axis = 0) # double the number of voices
    logging.debug(f'after doubling voices: {chorale.shape = }, {glides.shape = }') # (8, 3216, 2)
    # revised volume_array use a spline function 5/21/23
    logging.debug(f'{volume_function = }') # array([7, 7, 1, 3, 1, 1, 1, 4, 6]) # 9 elements, could be another number
    sustain = 15 # was 8 - how long to make the repeating mask.
    vol_arr_size = volume_function.shape[0] * rng.choice([1,2,3,4]) # make the volume array size a multiple of the number of sections
    logging.info(f'in finger_piano_part. About to call build_density_function with {volume_function.shape = }, {vol_arr_size = }')
    logging.info(f'{volume_function = }')
    volume_array = dmu.build_density_function(volume_function, vol_arr_size) 
    logging.info(f'{volume_array.shape = }')
    logging.info(f'Percentage of zeros:  {(np.sum(volume_array < 0.1) / volume_array.shape[0]) * 100:.1f}%')
    volume_array = np.clip(np.repeat(volume_array, repeats * sustain, axis=0), 0, 10)
    volume_array = volume_array[:chorale.shape[1]] # truncate to the length of the chorale
    volume_array = volume_array[:-24] # truncate so percussion ends before sustained instruments
    logging.info(f'{volume_array.shape = }') # 4288
    logging.info(f'Percentage of zeros:  {(np.sum(volume_array < 0.1) / volume_array.shape[0]) * 100:.1f}%') # 8% to 25% zeros
    logging.debug(f'after repeat & clip: {volume_array.shape = }, {repeats = }, {sustain = }')
    # revised 3/22/23 - 3/28/23
    # revise 4/7/23 to move build_notes_features earlier in the stack.
    logging.debug(f'{chorale.shape = }') # all must be the same shape, (2,2), (3,2) etc. 
    gls = np.array([[0, 0], [0, 0], [0, 0], [0, 0]]) # no slides here. See below for add_features_glides
    gls_p = np.array([[.5, .5], [.5, .5], [.5, .5], [.5, .5]])
    ups = np.array([[-1, 0], [-2, 1], [1, 2], [-2, -1]])
    ups_p = np.array([[.5, .5], [.5, .5], [.5, .5], [.5, .5]])
    env = np.array([[1, 0], [2, 8], [16, 17], [2, 8]])
    env_p = np.array([[.5, .5], [.8, .2], [.5, .5], [.5, .5] ])
    vel = np.array([[71, 74], [74, 77], [76, 79], [73, 76]])
    vel -= 2 # lower the volume on the finger piano parts to avoid clipping
    vel_p = np.array([[.5, .5], [.5, .5], [.5, .5], [.5, .5]])
    guev_array = np.stack((gls, gls_p, ups, ups_p, env, env_p, vel, vel_p), axis = 0)
    rng.shuffle(guev_array, axis=1)
    logging.debug(f'In finger piano. feature array after stack. {guev_array.shape = }') # g
    notes_features_6 = atu.add_features_glides(chorale, glides, guev_array) # start with the chorale, which is (notes, octaves), and add the gls, ups, env, vel arrays
    logging.debug(f'after loading notes_features_6.{notes_features_6.shape = }')
    logging.debug([np.unique(feature, return_counts = True) for feature in notes_features_6])
    octave_array = notes_features_6[1] # all the octaves for all the voices, notes
    # Build a lower-randomness arpeggio mask:
    # - Keep a repeating 4-note pattern for multiple chords.
    # - Move to the next pattern by mutating only one pattern position.
    # - Use section-specific start phase (dense/moderate/sparse) to offset peaks.
    print(f'{chorale.shape = }, {chorale[:,:,0].shape = }')
    density_mode = str(density_start).lower()
    mode_phase = {'dense': 0, 'moderate': 2, 'sparse': 4}
    mode_pattern = {'dense': 0, 'moderate': 1, 'sparse': 2}
    base_patterns = np.array([
        [0, 1, 2, 3, 0, 1, 2, 3],
        [0, 2, 1, 3, 0, 2, 1, 3],
        [0, 1, 3, 2, 0, 1, 3, 2],
        [0, 2, 3, 1, 0, 2, 3, 1],
    ], dtype=int)

    n_steps = chorale.shape[1]
    density_function = np.zeros((voices, n_steps), dtype=int)

    # Detect chord boundaries from first SATB quartet; this keeps pattern shifts tied to harmony.
    chord_changes = np.where(np.any(np.diff(chorale[:4, :, 0], axis=1) != 0, axis=0))[0] + 1
    boundaries = np.concatenate(([0], chord_changes, [n_steps]))

    pattern = base_patterns[mode_pattern.get(density_mode, 1)].copy()
    hold_chords_target = int(rng.integers(2, 5))
    held_chords = 0

    # Rhythmic mix engine:
    # - stay on one mixed-duration pattern for 1..10 chords
    # - morph to the next mix by changing only one duration slot
    # - keep all durations in a musical 1..6 click range
    rhythm_mix = rng.integers(1, 7, size=6).astype(int)
    rhythm_hold_chords = int(rng.integers(1, 11))
    rhythm_chords_used = 0
    rhythm_event_num = 0

    for chord_idx in range(boundaries.shape[0] - 1):
        start = int(boundaries[chord_idx])
        end = int(boundaries[chord_idx + 1])
        seg_len = max(0, end - start)
        if seg_len == 0:
            continue

        # Change pattern only occasionally, and by one slot at a time.
        if held_chords >= hold_chords_target:
            mutate_inx = int(rng.integers(0, pattern.shape[0]))
            step_dir = -1 if rng.random() < 0.5 else 1
            pattern[mutate_inx] = (pattern[mutate_inx] + step_dir) % 4
            hold_chords_target = int(rng.integers(2, 5))
            held_chords = 0
        held_chords += 1

        # Morph to a neighboring rhythmic mix by changing one slot at a time.
        if rhythm_chords_used >= rhythm_hold_chords:
            mutate_rhythm_inx = int(rng.integers(0, rhythm_mix.shape[0]))
            delta = -1 if rng.random() < 0.5 else 1
            rhythm_mix[mutate_rhythm_inx] = int(np.clip(rhythm_mix[mutate_rhythm_inx] + delta, 1, 6))
            rhythm_hold_chords = int(rng.integers(1, 11))
            rhythm_chords_used = 0
        rhythm_chords_used += 1

        phase = (mode_phase.get(density_mode, 2) + chord_idx) % pattern.shape[0]
        twin_offset = 1 if (chord_idx % 2 == 1) else 0

        # Fill this harmonic segment with variable-duration arpeggio events.
        pos = 0
        while pos < seg_len:
            dur = min(int(np.clip(round(rhythm_mix[rhythm_event_num % rhythm_mix.shape[0]] * fp_hold_scale), 1, 6)), seg_len - pos)
            pvoice = int(pattern[(phase + rhythm_event_num) % pattern.shape[0]])
            lo = start + pos
            hi = lo + dur
            density_function[pvoice, lo:hi] = 1
            if density_mode != 'sparse':
                density_function[(pvoice + twin_offset) % 4 + 4, lo:hi] = 1

            # Occasional accent doubling in dense mode.
            if density_mode == 'dense' and ((rhythm_event_num + chord_idx) % 5 == 0):
                accent_voice = int(pattern[(phase + rhythm_event_num + 1) % pattern.shape[0]])
                density_function[accent_voice, lo:hi] = 1

            pos += dur
            rhythm_event_num += 1
    density_function = apply_density_multiplier(density_function, density_profile, min_active_base=2)
    logging.info(f'after creation: {np.sum(density_function) = }, {np.sum(density_function == 0) = }, {np.sum(density_function == 1) = }, Percentage of ones: {np.sum(density_function == 1) / np.sum(density_function == 0) * 100:.1f}%')

    logging.info(f'after first creation: {chorale[:,:,0].shape = }, {density_function.shape = }') # 

    # changed on 5/21/23 - make sure it doesn't mess up the octaves as zeros
    octave_alteration_mask = atu.build_octave_alteration_mask(repeats, voices, chorale, octave_reduce=1, octave_stretch=5, stay=7) # set the probability of each octave being used. Some very low, some very high, but most in the middle 3 choices
    logging.info(f'alteration mask: {np.unique(octave_alteration_mask, return_counts=True)}')
    logging.info(f'finger_piano_part. octave_array prior to octave alteration mask: {np.unique(octave_array, return_counts=True)}')
    logging.debug(f'{octave_alteration_mask.shape = }')
    for voice in np.arange(octave_array.shape[0]):
        for note in np.arange(octave_array.shape[1]):
                if octave_array[voice, note] > 0: octave_array[voice, note] += octave_alteration_mask[voice, note]
    logging.info(f'finger_piano_part. octave_array after octave alteration mask: {np.unique(octave_array, return_counts=True)}')
    logging.info(f'before masking: {np.sum(octave_array) = }')
    logging.info(f'about to mask the octave array with the density_function: {density_function[:, :octave_array.shape[1]].shape = }')
    logging.info(f'{octave_array.shape = }, {np.sum(octave_array) = } {density_function.shape = }, {np.sum(density_function) = }') 
    octave_array = octave_array * density_function[:, :octave_array.shape[1]] # make the octave go to zero for some percent of the notes. Not all of them!
    logging.info(f'after masking. {np.sum(octave_array) = }')
    logging.info(f'finger_piano_part. after applying density function: {np.unique(octave_array, return_counts=True)}')
    logging.debug(f'{notes_features_6.shape = }') #                             0      1        2      3         4         5
    volume_array += fp_volume
    notes_features_6[1] = octave_array #  add_features returns this :np.stack((notes, octaves, gliss, upsample, envelope, velocity), axis = 0)
    notes_features_15 = dmu.piano_roll_to_notes_features(notes_features_6, volume_array, voice_names, tpq, voice_time)
    notes_features_15 = atu.clip_note_features(notes_features_15, voice_time) # make sure the octaves are in range and the volume adjusted per the voice_time dictionary
    # notes_features_15 contains one row for every note: note, oct, glis, ups, env, vel, vol, voice, 
    logging.debug(f'{notes_features_15.shape = }')
    # np.save('fp_part_notes_features.npy', notes_features_15)
    return notes_features_15
# end of finger_piano_part


# define the functions for the long held parts, horns, winds, bowed strings, brass, etc.
def woodwinds_part(chorale_in_cents_slides, glides, repeats, voice_names, voice_time, tpq,\
    volume_function, mask=True, prob_silence=None, octave_reduce=0, woodwinds_volume=5, density_profile: np.ndarray | None = None,
    rescue_probability=0.5, ftable_308_prob=0.25):

    if prob_silence is None:
        prob_silence = [.5, .5]
    if octave_reduce == 0: 
        octave_reduce = -2
    logging.debug(f'in woodwinds_part. {chorale_in_cents_slides.shape = }, {glides = }, {repeats = }, {voice_names = } {prob_silence = }')
    voices = voice_names.shape[0] # if you want it to last twice as long, pretend there are twice as many voices: voice_names.shape[0] * 2
    chorale_in_cents_slides = np.repeat(chorale_in_cents_slides, 1, axis = 1) # make each note repeats making it n times as long on each note.
    glides = np.repeat(glides, 1, axis = 1)
    logging.debug(f'after repeating each note {repeats = }: {glides.shape = }')
    chorale_in_cents_slides = np.repeat(chorale_in_cents_slides, voices // 4, axis = 0) # make the proper number of voices so each voice gets one track. 
    glides = np.repeat(glides, voices // 4, axis = 0) # to to glides what you just did to chorale_in_cents_slides
    logging.debug(f'after doubling voices: {chorale_in_cents_slides.shape = }, {glides.shape = }')      
    logging.debug(f'{volume_function = }')

    sustain = 15
    vol_arr_size = volume_function.shape[0] * rng.choice([1,2,3,4])
    logging.info(f'{volume_function.shape = }, {chorale_in_cents_slides.shape[1] = }, {repeats = }, {sustain = }, {vol_arr_size = }')
    logging.info(f'{volume_function = }')
    volume_array = dmu.build_density_function(volume_function, vol_arr_size) 
    logging.debug(f'{volume_array.shape = }')
    volume_array = np.clip(np.repeat(volume_array, repeats * sustain, axis=0), 0, 10)
    volume_array = volume_array[:chorale_in_cents_slides.shape[1]] # truncate to the length of the chorale
    logging.debug(f'after repeat and clip. {volume_array.shape = }') # volume_array.shape = (1656,), repeats = 12, sustain = 15
    # revised 3/22/23 revised again 5/21/23 to give more control over relative volume of each instrument
    # revised 4/6/23 to move midi_to_notes_octaves earlier in the stack

    gls = np.array([[0, 0], [0, 0], [0, 0], [0, 0]]) # this needs to be replaced with one slide for every note in every chord in the piece.
    gls_p = np.array([[.5, .5], [.5, .5], [.5, .5], [.5, .5]])
    ups = np.array([[2, 1],[2, 1],[1, 0],[0, 1]])
    ups_p = np.array([[.5, .5], [.5, .5], [.5, .5], [.5, .5]])
    env = np.array([[1, 16], [6, 9], [0, 5], [9, 6]])
    env_p = np.array([[.5, .5], [.5, .5], [.5, .5], [.5, .5]])
    vel = np.array([[64, 66], [64, 69], [63, 70], [64, 69]]) # how loud the note will be.
    vel -= 3 # lower the volume on the woodwinds parts to avoid clipping
    vel_p = np.array([[.5, .5], [.5, .5], [.5, .5], [.5, .5]])

    if mask:
        guev_array = np.stack((gls, gls_p, ups, ups_p, env, env_p, vel, vel_p), axis = 0)
        rng.shuffle(guev_array, axis=2)
    else: guev_array = np.stack((gls[0], gls_p[0], ups[0], ups_p[0], env[0], env_p[0], vel[0], vel_p[0]), axis = 0).reshape(8,1,2) # no content for these variables if mask is False

    logging.debug(f'{guev_array = }')
    logging.debug(f'In woodwinds. feature array after stack. {guev_array.shape = }') # guev_array.shape = (8, 1, 2)
    # revised 9/1/23 Here is where can I include glides
    # print(f'in woodwinds_part. {chorale_in_cents_slides.shape = }, {glides.shape = }, {repeats = }')
    notes_features_6 = atu.add_features_glides(chorale_in_cents_slides, glides, guev_array)
    logging.debug(f'feature values and counts in this order: notes, octaves, gliss, upsample, envelope, velocity (values, counts)')
    logging.debug([np.unique(feature, return_counts=True) for feature in notes_features_6])
    logging.debug(f'{notes_features_6.shape = }') # notes_features_6.shape = (8, 915, 6) (voices, notes, features)
    if mask:
        octave_array = notes_features_6[1] # all the octaves for all the voices, notes, taken down
        octave_stretch = 4
        octave_reduce = 0
        stay = 9
        logging.info(f'in woodwinds_part. {octave_reduce = }, {octave_stretch = }, {stay = }')
        # assert octave_reduce == 1, 'octave_reduce must be 1 for woodwinds_part'
        octave_alteration_mask = atu.build_octave_alteration_mask(repeats, voices, chorale_in_cents_slides,\
                octave_reduce=octave_reduce, octave_stretch=octave_stretch, stay=stay) 
        logging.info(f'woodwinds part. octave_alteration_mask buckets: values, counts: {np.unique(octave_alteration_mask, return_counts=True)}')
        logging.debug(f'{octave_alteration_mask.shape = }')
        logging.info(f'octave_array prior to spread (values, counts): {np.unique(octave_array, return_counts=True)}')
        for voice in np.arange(octave_array.shape[0]):
                for note in np.arange(octave_array.shape[1]):
                    if octave_array[voice, note] > 0: octave_array[voice, note] += octave_alteration_mask[voice, note]
        logging.debug(f'after spread: {np.sum(octave_array) = }')
        logging.info(f'octave_array after spread (values, counts): {np.unique(octave_array, return_counts=True)}')
        # octave_silence_mask = atu.build_long_mask(repeats, voices, chorale_in_cents_slides) 
        # Scale prob_silence by density profile mean so denser regions have more activity
        # without fragmenting the long-block structure (arpeggio dilator is wrong here).
        if density_profile is not None and density_profile.shape[0] > 0:
            density_mean = float(np.mean(density_profile))
            # density_mean in [1,3]: map to silence reduction factor [1.0, 0.55]
            silence_scale = 1.0 - 0.225 * (density_mean - 1.0)
            scaled_silence = [float(np.clip(p * silence_scale, 0.05, 0.99)) for p in prob_silence]
        else:
            scaled_silence = list(prob_silence)
        logging.info(f'woodwinds: density-scaled prob_silence: {prob_silence} -> {scaled_silence}')
        logging.info(f'before build_long_mask_v2. {repeats = }, {voices = }, {chorale_in_cents_slides.shape = }, {scaled_silence = } ')
        octave_silence_mask = atu.build_long_mask_v2(repeats, voices, chorale_in_cents_slides, p1 = scaled_silence) # build long chains of zeros, followed by long chains of ones so the notes sound for a long time, then go silent.
        logging.info(f'before masking octave_array. {np.average(octave_array) = }')  
        logging.info(f'octave_array (values, counts): {np.unique(octave_array, return_counts=True)}')
        logging.info(f'octave_silence_mask (values, counts): {np.unique(octave_silence_mask, return_counts=True)}, {np.average(octave_silence_mask) = }')
        octave_array = octave_array * octave_silence_mask     
        logging.info(f'after masking octave_array. {np.average(octave_array) = }')  
        logging.info(f'octave_array (values, counts): {np.unique(octave_array,  return_counts=True)}')
        notes_features_6[1] = octave_array
    else: 
        notes_features_6[1] -= 1 # take down the octave by one
        # print(f'before incrementing: {volume_array.shape = }, {volume_array[:10] = }')
        volume_array += woodwinds_volume # increase the volume by some value when woodwinds is the only note generating function.
        # print(f'after  incrementing: {volume_array.shape = }, {volume_array[:10] = }')
    logging.debug(f'{notes_features_6.shape = }')
    notes_features_15 = dmu.piano_roll_to_notes_features(notes_features_6, volume_array, voice_names, tpq, voice_time)
    notes_features_15 = atu.clip_note_features(notes_features_15, voice_time) # make sure the octaves are in range and the volume adjusted per the voice_time dictionary
    logging.debug(f'{notes_features_15.shape = }')
    
    # Tuba octave-0 rescue with simple 50% probability.
    # Similar to bass_part rescue but without density-awareness.
    # Column 6 still contains time_tracker_number here; map from voice names.
    tuba_trackers = np.array(
        [
            voice_time[v]["time_tracker_number"]
            for v in voice_names
            if voice_time[v]["csound_voice"] == 27
        ],
        dtype=int,
    )
    tuba_oct0 = np.isin(notes_features_15[:, 6].astype(int), tuba_trackers) & (notes_features_15[:, 5] == 0)
    
    if np.any(tuba_oct0):
        oct0_indices = np.where(tuba_oct0)[0]
        num_oct0_notes = len(oct0_indices)
        
        # Apply simple 50% rescue probability (not density-aware)
        rescue_mask = rng.random(num_oct0_notes) < rescue_probability
        rescue_indices = oct0_indices[rescue_mask]
        num_rescued = len(rescue_indices)
        
        if num_rescued > 0:
            # Set octave to 1 for all rescued notes
            notes_features_15[rescue_indices, 5] = 1
            
            # Randomly choose between f307 (75%) and f308 (25%) for each rescued note
            ftable_choices = rng.random(num_rescued) < ftable_308_prob
            
            # Apply f307 (1-octave drop) to 75% of rescued notes
            f307_indices = rescue_indices[~ftable_choices]
            notes_features_15[f307_indices, 10] = 252  # upsample: 4 slots lower (256-4)
            notes_features_15[f307_indices, 12] = 307  # glissando: f307 constant 0.5 (one octave down)
            
            # Apply f308 (2-octave drop) to 25% of rescued notes
            f308_indices = rescue_indices[ftable_choices]
            notes_features_15[f308_indices, 10] = 248  # upsample: 8 slots lower (256-8)
            notes_features_15[f308_indices, 12] = 308  # glissando: f308 constant 0.25 (two octaves down)
            
            # Logging
            num_f307 = len(f307_indices)
            num_f308 = len(f308_indices)
            
            logging.info(f'woodwinds_part (tuba): octave-0 rescue applied to {num_rescued}/{num_oct0_notes} notes ({num_rescued/num_oct0_notes*100:.1f}%)')
            logging.info(f'  - f307 (1-oct): {num_f307} notes ({num_f307/num_rescued*100:.1f}%)')
            logging.info(f'  - f308 (2-oct): {num_f308} notes ({num_f308/num_rescued*100:.1f}%)')
    
    # np.save('wood_part_notes_features.npy', notes_features_15)
    return notes_features_15
# end of woodwinds_part

# define the functions for the melody part
def melody_part(chorale_in_cents_slides, glides, repeats, voice_names, voice_time, tpq,\
    volume_function, mask = True, prob_silence = None, octave_reduce = 0,\
    woodwinds_volume = 4, sustain=15, density_profile: np.ndarray | None = None):

    if prob_silence is None:
        prob_silence = [.5, .5]
    if octave_reduce == 0:
        octave_reduce = 2
    logging.debug(f'in melody_part. {chorale_in_cents_slides.shape = }, {glides = }, {repeats = }, {voice_names = } {prob_silence = }')
    voices = voice_names.shape[0] # if you want it to last twice as long, pretend there are twice as many voices: voice_names.shape[0] * 2
    # assign the 1st and second voices to replace the 3rd and 4th voices as melody_chorale_in_cents_octaves
    melody_chorale_in_cents_octaves = chorale_in_cents_slides.copy()
    # melody_chorale_in_cents_octaves[2:, :, :] = chorale_in_cents_slides[:2, :, :] # This used to set the lower two voices to the same cents as the upper two, but I decided that made it to heavy on the top two voices.
    melody_chorale_in_cents_octaves[:, :, 1][2:, :] = 0 # set the octave for the 2 lower voices to zero, making them silent. 
    chorale_in_cents_slides = np.repeat(melody_chorale_in_cents_octaves, 1, axis = 1) # make each note repeats making it n times as long on each note.
    glides = np.repeat(glides, 1, axis = 1)
    logging.debug(f'after repeating each note {1 = }: {glides.shape = }')
    chorale_in_cents_slides = np.repeat(chorale_in_cents_slides, voices // 4, axis = 0) # make the proper number of voices so each voice gets one track. 
    glides = np.repeat(glides, voices // 4, axis = 0) # to to glides what you just did to chorale_in_cents_slides
    logging.debug(f'after doubling voices: {chorale_in_cents_slides.shape = }, {glides.shape = }')      
    sustain = 15
    vol_arr_size = volume_function.shape[0] * rng.choice([1,2,3,4])
    logging.info(f'About to call build_density_function: passing in {volume_function.shape = }, {vol_arr_size = }, {repeats = }, {sustain = }')
    volume_array = dmu.build_density_function(volume_function, vol_arr_size)
    logging.debug(f'{volume_array.shape = }')
    volume_array = np.clip(np.repeat(volume_array, repeats * sustain, axis=0), 0, 10)
    volume_array = volume_array[:chorale_in_cents_slides.shape[1]] # truncate to the length of the chorale
    logging.debug(f'after repeat and clip. {volume_array.shape = }') # volume_array.shape = (1656,), repeats = 12, sustain = 15
    # revised 3/22/23 revised again 5/21/23 to give more control over relative volume of each instrument
    # revised 4/6/23 to move midi_to_notes_octaves earlier in the stack

    gls = np.array([[0, 0], [0, 0], [0, 0], [0, 0]]) # this needs to be replaced with one slide for every note in every chord in the piece.
    gls_p = np.array([[.5, .5], [.5, .5], [.5, .5], [.5, .5]])
    ups = np.array([[2, 1],[2, 1],[1, 0],[0, 1]])
    ups_p = np.array([[.5, .5], [.5, .5], [.5, .5], [.5, .5]])
    env = np.array([[1, 16], [6, 9], [0, 5], [9, 6]])
    env_p = np.array([[.5, .5], [.5, .5], [.5, .5], [.5, .5]])
    vel = np.array([[64, 66], [64, 69], [63, 70], [64, 69]]) # how loud the note will be.
    vel -= 3 # lower the volume on the melody parts to avoid clipping
    vel_p = np.array([[.5, .5], [.5, .5], [.5, .5], [.5, .5]])

    if mask:
        guev_array = np.stack((gls, gls_p, ups, ups_p, env, env_p, vel, vel_p), axis = 0)
        rng.shuffle(guev_array, axis=2)
    else: guev_array = np.stack((gls[0], gls_p[0], ups[0], ups_p[0], env[0], env_p[0], vel[0], vel_p[0]), axis = 0).reshape(8,1,2) # no content for these variables if mask is False

    logging.debug(f'{guev_array = }')
    logging.debug(f'In woodwinds. feature array after stack. {guev_array.shape = }') # guev_array.shape = (8, 1, 2)
    # revised 9/1/23 Here is where can I include glides
    notes_features_6 = atu.add_features_glides(chorale_in_cents_slides, glides, guev_array)
    logging.debug(f'feature values and counts in this order: notes, octaves, gliss, upsample, envelope, velocity (values, counts)')
    logging.debug([np.unique(feature, return_counts=True) for feature in notes_features_6])
    logging.debug(f'{notes_features_6.shape = }') # notes_features_6.shape = (8, 915, 6) (voices, notes, features)
    if mask:
        octave_array = notes_features_6[1] # all the octaves for all the voices, notes, taken down
        octave_reduce = 2
        octave_stretch = 5
        logging.info(f'in melody_part. {octave_reduce = }, {octave_stretch = }')
        # assert octave_reduce == 1, 'octave_reduce must be 1 for woodwinds_part'
        octave_alteration_mask = atu.build_octave_alteration_mask(repeats, voices, chorale_in_cents_slides, octave_reduce=octave_reduce, octave_stretch=octave_stretch) 
        logging.info(f'melody part. octave_alteration_mask buckets: values, counts: {np.unique(octave_alteration_mask, return_counts=True)}')
        logging.debug(f'{octave_alteration_mask.shape = }')
        logging.info(f'octave_array prior to spread (values, counts): {np.unique(octave_array, return_counts=True)}') 
        for voice in np.arange(octave_array.shape[0]):
                for note in np.arange(octave_array.shape[1]):
                    if octave_array[voice, note] > 0: octave_array[voice, note] += octave_alteration_mask[voice, note]
        logging.info(f'octave_array after spread (values, counts): {np.unique(octave_array, return_counts=True)}')
        # Scale prob_silence by density profile mean — preserves long-block structure for melody.
        if density_profile is not None and density_profile.shape[0] > 0:
            density_mean = float(np.mean(density_profile))
            silence_scale = 1.0 - 0.225 * (density_mean - 1.0)
            scaled_silence = [float(np.clip(p * silence_scale, 0.05, 0.99)) for p in prob_silence]
        else:
            scaled_silence = list(prob_silence)
        logging.info(f'melody: density-scaled prob_silence: {prob_silence} -> {scaled_silence}')
        logging.info(f'before build_long_mask_v2. {repeats = }, {voices = }, {chorale_in_cents_slides.shape = }, {scaled_silence = } ')
        octave_silence_mask = atu.build_long_mask_v2(repeats, voices, chorale_in_cents_slides, p1 = scaled_silence) # build long chains of zeros, followed by long chains of ones so the notes sound for a long time, then go silent.
        logging.info(f'before masking octave_array. {np.average(octave_array) = }')  
        logging.info(f'octave_array (values, counts): {np.unique(octave_array, return_counts=True)}')
        logging.info(f'octave_silence_mask (values, counts): {np.unique(octave_silence_mask, return_counts=True)}, {np.average(octave_silence_mask) = }')
        octave_array = octave_array * octave_silence_mask 
    else: 
        notes_features_6[1] -= 1 # take down the octave by one
        # print(f'before incrementing: {volume_array.shape = }, {volume_array[:10] = }')
        volume_array += woodwinds_volume # increase the volume by some number
        # print(f'after  incrementing: {volume_array.shape = }, {volume_array[:10] = }')
    logging.debug(f'{notes_features_6.shape = }')
    notes_features_15 = dmu.piano_roll_to_notes_features(notes_features_6, volume_array, voice_names, tpq, voice_time)
    notes_features_15 = atu.clip_note_features(notes_features_15, voice_time) # make sure the octaves are in range and the volume adjusted per the voice_time dictionary
    logging.debug(f'{notes_features_15.shape = }')
    # np.save('melody_part_notes_features.npy', notes_features_15)
    return notes_features_15
# end of melody_part


# chorale, voice_time, keys = initialize_chorale_and_instruments(chorale, root, mode, version, repeats, double_ending = False) 
def initialize_chorale_and_instruments(chorale, root, mode, version, repeats, double_ending = True):
    logging.debug(f'In initialize_chorale_and_instruments. {chorale.shape = }, {version = }')
    if mode == 'minor': # D G C F Bb Eb
        if root in ([2,7,0,5,10,3]): # minor keys notated with flats d, g, c, f, bb, eb
            keys = atu.set_accidentals(True) # True = flats False = sharps
        else: keys = atu.set_accidentals(False) 
    else:    
        if root in ([7,2,9,4,11,6]): # major keys notated with sharps" G D A E B, F#
            keys = atu.set_accidentals(False) # True = flats False = sharps
        else: keys = atu.set_accidentals(True) 

    logging.debug(f'{chorale.shape = }, {keys[root] = }, {mode = }')
    # chorale = chorale[:,0:32] # if you want only some notes [102, 132, 140, 141]
    # chorale = np.array([[0, 7, 4, 0], [9, 4, 0, 9], [2, 9, 5, 2], [7, 7, 2, 11],[0, 7, 4, 0]]).T + 60 # keenan comma pump
    logging.debug(f'sliced chorale: {chorale.shape = }')
    logging.debug(f'you should have successfully read the corpus into a numpy array by this point.')
    voice_time = atu.init_voice_time()
    logging.debug(f'average midi number for each voice (SATB): {[round(np.average(voice),2) for voice in chorale] = }') # sanity check
    logging.debug(f'{repeats.shape = }')
    # repeats = 2 # set it to 2 for testing to make sure it sounds good.
    # remember to come back here and uncomment this next line that creates an extended duration ending
    logging.debug(f'This is what will be added at the end of the chorale. {chorale.shape = }, {chorale[:,-1]= }')
    if double_ending: 
        chorale = np.concatenate((chorale, np.repeat(chorale[:,-1], repeats, axis = 0).reshape(4, repeats)), axis = 1) # add a bit at the end so you make sure you have a nice bunch of repeated chords at the end. Fade out later
    logging.debug(f'after adding the last bit. {chorale.shape = }')
    # initialize the instrument arrays
    dmu.init_voice_start_times(voice_time) # start from the beginning - set all instruments to start at time zero

    # Choose the notes that you would like to anchor in place and not allow to drift
    unique_note_names, count_of_note_names = np.unique(np.array([voice % 12 for voice in chorale]), return_counts=True)
    logging.debug(f'all notes used in this MIDI file: {unique_note_names}\nNames of the notes: {keys[unique_note_names]}\nHow often each note appears in the chorale: {count_of_note_names}')
    return(chorale, voice_time, keys)
# end of initialize_chorale_and_instruments

def set_probabilities(mask):        # (repeats, quantization): # we no longer use repeats in this function and quanitzation is gone
    # set the probabilities that notes will sound using subtractive synthesis
    # probs only affects the finger_piano_part and bass_part prob_silence only affects the woodwinds_part and melody_part
    start = 0.0001
    stop = 0.15 # was 0.20 7/22/25 making it more sparse
    step = rng.uniform(low = 0.02, high = 0.07) # all values are equally likely.
    if rng.integers(15) == 0: # for every 15 (was 8) pieces, up the odds by 3x make finger_piano_part more dense
        step *= 3
        stop *= 3
        stop = np.clip(stop, 0, 1)
        logging.debug(f'increased the finger_piano_part of probs odds by 3. {round(stop,4) = }')
    elif rng.integers(20) == 0: # for every 20 (was 10) pieces, up the odds by 6x
        step *= 6
        stop *= 6
        stop = np.clip(stop, 0, 1)
        logging.debug(f'increased the finger_piano_part odds of probs by 6. {round(stop,4) = }')
    elif rng.integers(8) == 0: # for every 8 pieces, decrease the odds by some factor
        step /= 4
        stop /= 4
        logging.debug(f'decreased the finger_piano_part odds of probs by 4, {round(stop,4) = }')
    probs = np.array([(1 - prob, prob) for prob in np.arange(start, stop, step)])
    if probs.shape[0] < 5: 
        probs = np.tile(probs, (2, 1))
        logging.debug(f'probs had too few elements. Tiled by 2: {probs.shape = }')
    probs = rng.permutation(probs, axis = 0) # permute it before using it.
    sum_of_probs = np.array([np.sum(prob) for prob in probs])
    assert sum_of_probs.all() == 1, logging.info(f'{probs = } needs to sum each of the elements to 1. Failed') 
    assert (np.max(probs[:,1]) < 1 and np.min(probs[:,1]) > 0), logging.info(f'{probs = } make sure probabilities do not include numbers greater than 1 or less than 0.\n Failed. {start = }, {stop = }, {round(step,4) = }')

    # prob_silence only affects woodwinds_part, melody_part 
    max_silence = rng.uniform(low = 0.60, high = 0.85) # was 0.98-1.0: at that level silence positions were all promoted to min_oct by clip_note_features (now fixed), leaving woodwinds silent
    if rng.integers(5) == 0: # 20% of the time reduce the silence by 0.05
        max_silence -= .05
        logging.debug(f'decreased woodwinds_part odds. reduced max_silence by .05. {round(max_silence,4) = }')
    elif rng.integers(10) == 0: # 10% of the time reduce it by 0.2
        max_silence -= .2
        logging.debug(f'decreased woodwinds_part odds. reduced max_silence by .2. {round(max_silence,4) = }')
    max_silence = np.clip(max_silence, 0.0, 0.95) # guard against going out of range

    if mask: prob_silence = [max_silence, 1 - max_silence] 
    else: 
        max_silence = 0
        prob_silence = [1, 0] # if mask is False, then there is no masking of notes
    assert np.sum(prob_silence) == 1.0, logging.debug(f'prob_silence needs to sum to 1. {np.sum(prob_silence) = }, {prob_silence = }') 
    assert (np.max(prob_silence) <= 1 and np.min(prob_silence) >= 0), logging.debug(f'{prob_silence = } needs to make sure probabilities do not include numbers greater than 1 or less than 0. Failed. {max_silence = }')
    return probs, step, prob_silence, max_silence       
# end set_probabilities


def generate_random_volumes(time_slots = 8, max_value=25, sections = 8, max_section_sum = 70, max_voice_value = 10, min_time_slot_sum = 10, sparse_mode = False):
      # time_slots: The piece has several equal length time slots. The more slots, the smaller each is
      # max_value: 12. one more than the max random value assigned at the initialization. Final result is clipped to this 
      # max_voice_value: 6. If the sum of wood and bras sections exceed this, set bows to zero. If less than this, let the bowed value stay as set at the initialization. 
      # sections: 8. How many instrument sections. Currently fixed at 8 sections. Should be multiple of SATB 
      # max_section_sum: 40. Each section over the entire piece (every time slot) should not sum to greater than this
      logging.info(f'{time_slots = }, {max_value = }, {max_section_sum = }, {max_voice_value = }')
      volume_function = rng.integers(0, max_value, size=(sections, time_slots)) # start with random values for the array of dimensions (8,time_slots) values between 0 and 1 less than max_value (12)
      logging.info(f'{volume_function.shape = }')
      fing = 0; wood = 1; pizz = 2; bows = 3; bras = 4; guit = 5; bass = 6; meld = 7
      sect_names = np.array(['fing', 'wood', 'pizz', 'bows', 'bras', 'guit', 'bass','meld'])

      # first dimension of volume function is the section, second dimension is the time_slot. 
      for time_slot in np.arange(time_slots):
            # if brass and woodwinds are playing, set bowed instruments to zero
            sum_of_held_notes = volume_function[wood, time_slot] + volume_function[bras, time_slot] 
            if sum_of_held_notes > max_voice_value:
                  volume_function[bows, time_slot] = 0
                  logging.debug(f'Set the bows to 0 because wood + bras sum to {sum_of_held_notes} which is > {max_voice_value}')
            else: # if brass and woodwinds are quiet or zero, set bowed instruments to a prominent value
                  volume_function[bows, time_slot] = rng.integers(max_voice_value, max_value)
                  logging.debug(f'Set the bows to {volume_function[bows, time_slot]} because the {sum_of_held_notes} is not > {max_voice_value}')

            if np.sum(volume_function[:, time_slot]) < max_voice_value: # if the sum of all sections is less than max_voice_value, increase some random section by a random amount
                  volume_function[bows, time_slot] += rng.integers(max_voice_value, max_value)

            # Make sure there aren't too many playing the arpeggios at the same time   
            while volume_function[fing, time_slot] + volume_function[guit, time_slot] + volume_function[pizz, time_slot] > max_value:
                  # maybe just reduce some by 1, or make one of them silent 
                  section_to_reduce = rng.choice([fing, guit, pizz])
                  if rng.integers(4): # 75% of the time it is more than zero so true
                        volume_function[section_to_reduce, time_slot] = 0
                        logging.debug(f'zeroed out one of the arpeggio part {sect_names[section_to_reduce]}')
                  else: 
                        if volume_function[section_to_reduce, time_slot] > 0:
                              volume_function[section_to_reduce, time_slot] -= 1
                              logging.debug(f'reduced the one arpeggio parts by one in {sect_names[section_to_reduce]}')
            # Make sure not too many voices of held notes are playing at once
            while volume_function[wood, time_slot] + volume_function[bows, time_slot] + volume_function[bras, time_slot] + volume_function[meld, time_slot] > max_value:
                  section_to_reduce = rng.choice([wood, bows, bras, meld])
                  if rng.integers(2): # 50% of the time it is true
                        volume_function[section_to_reduce, time_slot] = 0
                        logging.debug(f'zeroed out one of the held parts {sect_names[section_to_reduce]}')
                  else:
                        if volume_function[section_to_reduce, time_slot] > 0:
                              volume_function[section_to_reduce, time_slot] -= 1
                              logging.debug(f'reduced the voices in the hold notes parts by one in {sect_names[section_to_reduce]}')

      for section in np.arange(sections): # make sure no section dominates the piece
            logging.debug(f'section {sect_names[section]} value before reductions: {np.sum(volume_function[section])}, {max_section_sum}')
            while np.sum(volume_function[section]) > max_section_sum:
                  # time_slot = rng.choice(time_slots) # choose a time_slot to reduce this section
                  # print(f'{volume_function[section] = }')
                  time_slot = np.argmax(volume_function[section]) # loudest slot played by this section
                  if rng.integers(4): # 75% of the time it is more than zero so true
                        if volume_function[section, time_slot] > 0:
                              volume_function[section][time_slot] -= 2
                              logging.debug(f'Set the volume for section {sect_names[section]} down by 2 in {time_slot = }')
                  else:

                        volume_function[section][time_slot] = 0
                        logging.debug(f'zeroed out section {sect_names[section]} in {time_slot = }')
            
      
      # Set the final time slot uniformly - creates a cohesive ending
      final_value = max_section_sum // time_slots
      logging.info(f'Setting final time_slot {time_slots - 1} to uniform value {final_value}')
      volume_function[:, time_slots - 1] = final_value

      # Ensure no time slot is too soft: boost sections until each time slot sum >= min_time_slot_sum
      # Use flexible minimum and add varied amounts to keep the sound interesting
      assert min_time_slot_sum >= 0, "min_time_slot_sum must be non-negative"
      max_possible = sections * max_value
      if min_time_slot_sum > max_possible:
            logging.warning(f'min_time_slot_sum {min_time_slot_sum} is larger than max possible {max_possible}; clipping to {max_possible}')
            min_time_slot_sum = max_possible

      for ts in range(time_slots - 1):  # skip the final time slot - it's already set for the ending
            # Use a flexible minimum for each time slot to avoid uniformity
            flexible_min = min_time_slot_sum + rng.choice([-3, -2, -1, 0, 1, 2, 3, 4, 5])
            flexible_min = max(0, flexible_min)  # don't go negative
            total = int(np.sum(volume_function[:, ts]))
            if total < flexible_min:
                  deficit = int(flexible_min - total)
                  logging.info(f'Time slot {ts} total {total} < flexible_min {flexible_min}; increasing by {deficit}')

                  # shuffle the preferred order to add variety
                  preferred = [bows, bass, bras, wood, fing, pizz, guit, meld]
                  rng.shuffle(preferred)
                  for sec in preferred:
                        if deficit <= 0:
                              break
                        available = int(max_value - volume_function[sec, ts])
                        if available <= 0:
                              continue
                        # add a random portion of the deficit, not all of it
                        add = rng.choice(range(1, min(deficit, available) + 1))
                        volume_function[sec, ts] += add
                        deficit -= add
                        logging.debug(f'Added {add} to section {sect_names[sec]} at ts {ts}; remaining deficit {deficit}')

                  # if still deficit, fill randomly with varied amounts
                  attempts = 0
                  while deficit > 0 and attempts < sections * 5:
                        sec = int(rng.integers(sections))
                        available = int(max_value - volume_function[sec, ts])
                        if available > 0:
                              add = rng.choice(range(1, min(deficit, available, 4) + 1))
                              volume_function[sec, ts] += add
                              deficit -= add
                        attempts += 1

                  if deficit > 0:
                        logging.debug(f'Could not fully satisfy flexible_min for ts {ts}; remaining deficit {deficit}')

      if sparse_mode:
            # Allow only a limited number of sections to sound simultaneously per time slot.
            # sparse_mode is a (lo, hi) tuple controlling the range of active sections.
            # Zero all others so sections take turns rather than layering constantly.
            lo, hi = sparse_mode if isinstance(sparse_mode, tuple) else (2, 3)
            for ts in range(time_slots - 1):  # leave the final slot (cohesive ending) alone
                  n_active = int(rng.integers(lo, hi + 1))
                  active_secs = rng.choice(sections, size=n_active, replace=False)
                  keep = np.zeros(sections, dtype=bool)
                  keep[active_secs] = True
                  volume_function[~keep, ts] = 0
                  for sec in active_secs:
                        if volume_function[sec, ts] == 0:
                              volume_function[sec, ts] = int(rng.integers(3, max_voice_value))
            logging.info(f'sparse_mode post-pass {lo}-{hi}: active sections per slot = {[int(np.sum(volume_function[:, ts] > 0)) for ts in range(time_slots)]}')

      logging.info(f'Sum before final clip: {np.sum(volume_function) = }')
      final_answer = np.clip(volume_function, 0, max_value)
      logging.info(f'Sum after final clip: {np.sum(final_answer) = }')
      return final_answer


def _chord_idx_from_boundaries(notes_15: np.ndarray, boundaries: np.ndarray, tpq: float) -> np.ndarray:
    """Append chord_idx as column 15 to notes_15.

    Before fix_start_times, col 1 = duration in tpq units.  Accumulate per-voice
    durations to reconstruct each note's piano-roll start step, then binary-search
    into boundaries to find the chord index.
    """
    chord_idx_col = np.zeros(notes_15.shape[0], dtype=float)
    for voice_id in np.unique(notes_15[:, 6].astype(int)):
        rows = np.where(notes_15[:, 6].astype(int) == voice_id)[0]
        durations = notes_15[rows, 1]
        starts_steps = np.concatenate(([0.0], np.cumsum(durations[:-1]))) / tpq
        cidx = np.searchsorted(boundaries, starts_steps, side='right') - 1
        chord_idx_col[rows] = np.clip(cidx, 0, len(boundaries) - 2).astype(float)
    return np.column_stack([notes_15, chord_idx_col])


def _split_voice_at_steps(vrows: np.ndarray, cut_steps: list, boundaries: np.ndarray, tpq: float) -> np.ndarray:
    """Split notes in a single voice wherever their duration would straddle a cut_step.

    cut_steps – list of float step values (in boundaries-space) where cuts are needed
    Returns a new array with the same columns; notes that straddle a cut are replaced
    by two shorter notes whose durations sum to the original.
    """
    cut_set = set(cut_steps)
    if not cut_set or len(vrows) == 0:
        return vrows

    durations = vrows[:, 1]
    vstarts = np.concatenate(([0.0], np.cumsum(durations[:-1]))) / tpq

    hold_ratio = vrows[:, 2] / np.where(vrows[:, 1] != 0, vrows[:, 1], 1.0)

    new_rows: list = []
    for i in range(len(vrows)):
        row = vrows[i]
        start = vstarts[i]
        dur = row[1]
        end = start + dur / tpq
        splits = sorted(cs for cs in cut_set if start < cs < end)
        if not splits:
            new_rows.append(row)
            continue
        ratio = hold_ratio[i]
        cur = start
        for cs in splits:
            part = row.copy()
            part[1] = (cs - cur) * tpq
            part[2] = part[1] * ratio   # scale hold proportionally so Csound doesn't bleed over
            part[15] = float(np.searchsorted(boundaries, cur, side='right') - 1)
            new_rows.append(part)
            cur = cs
        tail = row.copy()
        tail[1] = (end - cur) * tpq
        tail[2] = tail[1] * ratio
        tail[15] = float(np.searchsorted(boundaries, cur, side='right') - 1)
        new_rows.append(tail)

    return np.array(new_rows)


def apply_rondo(notes_16: np.ndarray,
                sections: dict,
                insertions: list,
                boundaries: np.ndarray | None = None,
                tpq: float = 0.25) -> np.ndarray:
    """Splice named section copies into notes_16 (N×16, col 15 = chord_idx).

    sections   – dict mapping label → (start_chord_idx, end_chord_idx)  [start, end)
    insertions – list of (after_chord_idx, label) in ascending chord order
    boundaries – step-index boundaries array (from _boundaries in expand_chorale); used to
                 split notes that straddle cut points so all voices stay in sync.
    tpq        – time-per-quarter-note step size (same value used in _chord_idx_from_boundaries)

    Returns a new N×16 array.  Strip col 15 before fix_start_times.
    """
    insertions_sorted = sorted(insertions, key=lambda x: x[0])

    # Build the complete set of step values where we must split notes:
    # insertion cut boundaries and section-copy end boundaries.
    cut_steps: list = []
    if boundaries is not None:
        for after_chord, _ in insertions_sorted:
            idx = min(after_chord + 1, len(boundaries) - 1)
            cut_steps.append(float(boundaries[idx]))
        for s_start, s_end in sections.values():
            for chord in (s_start, s_end):
                idx = min(chord, len(boundaries) - 1)
                cut_steps.append(float(boundaries[idx]))

    # Preserve original voice ordering
    seen: dict = {}
    for vid in notes_16[:, 6].astype(int).tolist():
        seen[vid] = None
    voice_ids = list(seen.keys())

    result_blocks = []
    for voice_id in voice_ids:
        vrows = notes_16[notes_16[:, 6].astype(int) == voice_id].copy()
        if boundaries is not None and cut_steps:
            vrows = _split_voice_at_steps(vrows, cut_steps, boundaries, tpq)
        cidx = vrows[:, 15]
        chunks = []
        prev_cut = -1
        for after_chord, label in insertions_sorted:
            chunk = vrows[(cidx > prev_cut) & (cidx <= after_chord)]
            chunks.append(chunk)
            s_start, s_end = sections[label]
            sec_copy = vrows[(cidx >= s_start) & (cidx < s_end)].copy()
            chunks.append(sec_copy)
            prev_cut = after_chord
        chunks.append(vrows[cidx > prev_cut])
        non_empty = [c for c in chunks if c.shape[0] > 0]
        if non_empty:
            result_blocks.append(np.vstack(non_empty))

    return np.vstack(result_blocks) if result_blocks else notes_16[:0]


# this function takes the original chorale array and expands it dramatically. It is only called once per chorale.
def expand_chorale(repeats, chorale_in_cents_slides, glides, stored_gliss, voice_time,\
    include_sections, mod, ratio_factor, mask=True, tpq=0, octave_reduce=0, woodwinds_volume=8,\
    include_instruments=[], print_only=10, limit=0, melody_sustain=15, bass_sustain=15,
    bass_hold_scale=1.0, bass_hold_swing=0.75, bass_hold_cycles=4, tolerance=1,\
    stability_factor=0.0, max_delta=33, spread=7, fp_density_starts=None, fp_hold_scale=1.0, density_level=None,
    fatigue_thin_ratio=0.0, fatigue_min_chain=2, fatigue_density_threshold=1, version='',
    deep_bass_backoff=1.0, back_off_clicks=0.0,
    rondo_sections=None, rondo_insertions=None):
    # As of 1/10/26 the chorale_in_cents_slides has already been repeated according to the repeats array. (no longer an integer)
    # send the arrays to the file new_output.csd which csound will convert to a wave file to make music
    # duration, volume_function = expand_chorale(repeats, chorale_in_cents, chorale_in_cents_slides, glides, stored_gliss, voice_time, \
    # finger_pianos, wood_winds, pizz_strings, bowed_strings, brass_section, perc_guitar, \
    #     mask = mask, fing = fing, wood = wood, octave_reduce = octave_reduce, woodwinds_volume = woodwinds_volume)
    # set the time per quarter note if not specified in the default parameter tpq   
    logging.info(f'In expand_chorale. {chorale_in_cents_slides.shape = }, {glides.shape = }, {stored_gliss.shape = } {include_instruments = },')
    if tpq == 0:
        tpq = 0.25
    # set the default value for octave_reduce
    if octave_reduce == 0:
        octave_reduce = 2
    quantization = 7 # this is only used to influence the tempo, it's not actually quantizing anything. 8 went too far (fast)
    # choose the tempo based on how many times the notes are repeated
    repeats_average = int(round(np.average(repeats)))
    logging.info(f'{repeats.shape = }, {repeats_average = }, {quantization = }')
    if repeats_average == 2:
        tempo = rng.choice(np.arange(30, 40, 4))
    elif repeats_average * quantization > 65:
        tempo = rng.choice(np.arange(106, 124, 4)) 
    elif repeats_average * quantization > 40:
        tempo = rng.choice(np.arange(80, 105, 4)) 
    elif repeats_average * quantization > 30:
        tempo = rng.choice(np.arange(60, 80, 4)) 
    else: tempo = rng.choice(np.arange(56, 63, 4))

    logging.info(f'{repeats_average * quantization = }, {tempo = }')  
    # set the probabilities that notes will sound using subtractive synthesis
    probs, step, prob_silence, max_silence = set_probabilities(mask) 
    # logging.info(f'probabilities: steps\tstep\tarp max\tarp avg\twinds odds')
    logging.info(f'probabilities: {probs.shape[0] = }, {round(step,4) = }, {round(np.max(probs[:,1]),4) = }, {round(np.average(probs[:,1]),4) = }, {round(1 - max_silence, 4) = }')

    logging.debug(f'{mask = }')
    if mask: # 
        _prime_count = len(np.unique(repeats))  # recovers prime_count: repeats cycles through primes, so unique values = prime_count
        _total_expanded = int(np.sum(repeats))   # total expanded chord count; scales with both chorale length and prime magnitudes
        time_slots = int(np.clip(_total_expanded // 52, 6, 80))
        max_value = 11 # how loud can each instrument go
        logging.info(f'{time_slots = }, {_prime_count = }, {_total_expanded = }, {repeats.shape = }, {repeats_average = }')
        # 7/1/26: previously only levels 0-2 restricted simultaneous active sections (3-5 were
        # all unrestricted/identical on this axis). Now every level gets a distinct range so the
        # sparse end plays fewer of the 8 sections at once and the dense end is pushed to nearly
        # all of them, widening the audible gap between e.g. density_level 1 and density_level 5.
        # 7/1/26 pm: level 5 bumped from (7,8) to (8,8) — force every time slot to use the full
        # ensemble, a small further push per listening feedback ("come up a small amount").
        _sparse_range = {0: (1, 2), 1: (2, 3), 2: (3, 4), 3: (5, 6), 4: (6, 7), 5: (8, 8)}.get(density_level, False)
        volume_function = generate_random_volumes(time_slots=time_slots, sparse_mode=_sparse_range)
        logging.info(f'{volume_function.shape = }')
        logging.info(f'sums of each time_slot: ')
        total_sums = 0
        for i in np.arange(time_slots):
            logging.info(f'{i}: {np.sum(volume_function.T[i])}')
            total_sums += np.sum(volume_function.T[i])
        logging.info(f'Average sums: {total_sums // time_slots}')
    else: volume_function = np.full((8, 14), 2, dtype = int)
    
    # 5/30/25 Expanded from shape 8,9 to shape 8,12, then to 8,14
    # 9/20/23, reduced the upper numbers by 1. 8 became 7, and so forth. Prevent clipping.
    # 3/31/25, changed to 8 instrument sections from original 6. You have to use a multiple of 4 since there are 4 voices in a chorale: S,A,T,B. 

    logging.info(f'before shuffle: {[np.sum(vol) for vol in volume_function.T] = }')
    end_value = volume_function.T[-1].reshape(-1,1)
    volume_function = volume_function[:,np.random.permutation(volume_function.shape[1] - 1)]
    volume_function = np.concatenate((volume_function, end_value), axis = 1)
    logging.info(f'after shuffle: {[np.sum(vol) for vol in volume_function.T] = }')

    density_profile = build_density_multiplier_profile(chorale_in_cents_slides.shape[1])
    logging.info(
        'global density profile range/mean: '
        f'min={np.min(density_profile):.2f}, max={np.max(density_profile):.2f}, '
        f'mean={np.mean(density_profile):.2f}'
    )

    def _save_section_npy(section_name: str, rows: np.ndarray) -> None:
        pass

    def _section_density_sum(rows: np.ndarray) -> float:
        if rows.size == 0:
            return 0.0
        hold = rows[:, 2].astype(float)
        vel = np.clip(rows[:, 3].astype(float), 50.0, 90.0)
        vol = rows[:, 14].astype(float)
        return float(np.sum(hold * ((10 ** (vel / 20.0)) * vol / 5.0)))

    notes_features_15 = np.empty((0,15), dtype = float) # start with an empty array you can concatenate onto.
    section_slices: dict[str, tuple[int, int]] = {}
    if fp_density_starts is None:
        fp_density_starts = {'finger_pianos': 'moderate', 'pizz_strings': 'moderate', 'marimbas': 'moderate'}
    fp_volumes = {'finger_pianos': 2, 'pizz_strings': 3, 'marimbas': 3}
    for sec_num, section in zip(count(0,1), include_sections): 
        if include_sections[section][0]: # if the dictionary value for this instrument section is set to True
            print(f'{sec_num}: {section}, includes instruments: {include_sections[section][1]}')
            _rows_before = notes_features_15.shape[0]
            if section in ['pizz_strings', 'marimbas', 'finger_pianos']:
                print(f'playing {section}')
                notes_features_15 = np.concatenate((notes_features_15, finger_piano_part(chorale_in_cents_slides, glides, repeats_average, include_sections[section][1], voice_time, tpq, volume_function[sec_num], probs = probs,
                    fp_volume=fp_volumes.get(section, 2), density_start=fp_density_starts.get(section, 'moderate'), density_profile=density_profile, fp_hold_scale=fp_hold_scale)), axis = 0)
                logging.info(f'octaves before change: {np.unique(notes_features_15[:, 5].astype(int),return_counts=True)}')
                # if section == 'pizz_strings':
                    # notes_features_15[:, 5] += 1 # raise the octaves by one to prevent mud
                    # notes_features_15[:, 5] = np.clip(notes_features_15[:, 5], 1, 7) # clip at 7 max to prevent chirps
                logging.info(f'octaves after change: {np.unique(notes_features_15[:, 5].astype(int),return_counts=True)}')
                if fatigue_thin_ratio > 0:
                    logging.info(f'before fatigue thinning {section}: zero-octave rows = {int(np.sum(notes_features_15[_rows_before:, 5] == 0))} of {notes_features_15.shape[0] - _rows_before}')
                    notes_features_15[_rows_before:] = thin_staccato_chains(
                        notes_features_15[_rows_before:], min_chain_len=fatigue_min_chain, thin_ratio=fatigue_thin_ratio, density_threshold=fatigue_density_threshold)
                    logging.info(f'after fatigue thinning {section}: zero-octave rows = {int(np.sum(notes_features_15[_rows_before:, 5] == 0))} of {notes_features_15.shape[0] - _rows_before}')
                _save_section_npy(section, notes_features_15[_rows_before:])
            elif section in ['melody_section']:
                print(f'playing {section}')
                notes_features_15 = np.concatenate((notes_features_15, melody_part(chorale_in_cents_slides, glides, repeats_average, include_sections[section][1], voice_time, tpq, volume_function[sec_num], mask=mask, prob_silence=prob_silence, octave_reduce=octave_reduce, woodwinds_volume=woodwinds_volume, sustain=melody_sustain, density_profile=density_profile)), axis = 0)
                _save_section_npy(section, notes_features_15[_rows_before:])
            elif section in ['wood_winds', 'brass_section', 'bowed_strings']:
                print(f'playing {section}')
                notes_features_15 = np.concatenate((notes_features_15, woodwinds_part(chorale_in_cents_slides, glides, repeats_average, include_sections[section][1], voice_time, tpq, volume_function[sec_num], mask=mask, prob_silence=prob_silence, octave_reduce=0, woodwinds_volume=woodwinds_volume, density_profile=density_profile)), axis = 0)
                _save_section_npy(section, notes_features_15[_rows_before:])
            elif section in ['bass_section']:
                print(f'playing {section}')
                notes_features_15 = np.concatenate((notes_features_15, bass_part(chorale_in_cents_slides, glides, repeats_average, include_sections[section][1], voice_time, tpq, volume_function[sec_num], probs = probs, bass_sustain=bass_sustain, fp_volume=3,
                    bass_hold_scale=bass_hold_scale, bass_hold_swing=bass_hold_swing, bass_hold_cycles=bass_hold_cycles, density_profile=density_profile,
                    deep_bass_backoff=deep_bass_backoff, back_off_clicks=back_off_clicks)), axis = 0)
                if fatigue_thin_ratio > 0:
                    logging.info(f'before fatigue thinning bass_section: zero-octave rows = {int(np.sum(notes_features_15[_rows_before:, 5] == 0))} of {notes_features_15.shape[0] - _rows_before}')
                    notes_features_15[_rows_before:] = thin_staccato_chains(
                        notes_features_15[_rows_before:], min_chain_len=fatigue_min_chain, thin_ratio=fatigue_thin_ratio, density_threshold=fatigue_density_threshold)
                    logging.info(f'after fatigue thinning bass_section: zero-octave rows = {int(np.sum(notes_features_15[_rows_before:, 5] == 0))} of {notes_features_15.shape[0] - _rows_before}')
                _save_section_npy(section, notes_features_15[_rows_before:])
            section_slices[section] = (_rows_before, notes_features_15.shape[0])
            print(f'{section}: {[(inst, voice_time[inst]["start"]) for inst in include_sections[section][1]]}')
            logging.debug(f'{notes_features_15.shape = }')
            print(f'after concatenating {section = }, {notes_features_15.shape = }')

    # Auto-normalize sustained sections to comparable density per render.
    sustained_sections = ['wood_winds', 'bowed_strings', 'brass_section', 'melody_section']
    available_sustained = [s for s in sustained_sections if s in section_slices]
    for _ in range(2):
        sustained_sums = {}
        for section in available_sustained:
            start, end = section_slices[section]
            sustained_sums[section] = _section_density_sum(notes_features_15[start:end])
        nonzero = [v for v in sustained_sums.values() if v > 0]
        if len(nonzero) < 2:
            break
        target_sum = float(np.median(nonzero))
        logging.info(f'sustained auto-balance: {sustained_sums = }, {target_sum = }')
        for section, current_sum in sustained_sums.items():
            if current_sum <= 0:
                continue
            scale = float(np.clip(target_sum / current_sum, 0.25, 4.00))
            start, end = section_slices[section]
            notes_features_15[start:end, 14] = np.clip(
                notes_features_15[start:end, 14].astype(float) * scale,
                0,
                14,
            )

    for section in available_sustained:
        start, end = section_slices[section]
        _save_section_npy(section, notes_features_15[start:end])

    # Rondo / leitmotif splice — must happen before fix_start_times so timing accumulates correctly
    if rondo_sections and rondo_insertions:
        # Build boundaries from repeats rather than diff-detecting from chorale_in_cents_slides.
        # build_glides_array modifies cents in-place (copies chord-A value into chord-B for glide
        # pairs), so np.diff misses those steps and the boundary count comes out too small,
        # shifting every rondo insert point by the number of glides that precede it.
        if len(repeats) == 1:
            # short_repeats path: choral_octaves_repeated was NOT expanded; one step per chord.
            _boundaries = np.arange(chorale_in_cents_slides.shape[1] + 1, dtype=float)
        else:
            # standard path: each entry in repeats is how many steps that chord occupies.
            _boundaries = np.concatenate(([0.0], np.cumsum(repeats, dtype=float)))
        _tpq = tpq if tpq != 0 else 0.25

        # Reject insertions inside the last measure: voices commonly taper off
        # (fewer notes) heading into the final cadence, so a chunk ending there
        # doesn't reach its nominal boundary time for every voice. That desyncs
        # the spliced-in section's re-entry point across voices by several beats.
        # Require insertions to land at least 16 chords before the ending.
        _last_chord_idx = len(_boundaries) - 2
        _min_margin_chords = 16
        _cutoff_chord_idx = _last_chord_idx - _min_margin_chords
        _skipped_insertions = [(a, l) for a, l in rondo_insertions if a >= _cutoff_chord_idx]
        rondo_insertions = [(a, l) for a, l in rondo_insertions if a < _cutoff_chord_idx]
        if _skipped_insertions:
            logging.warning(f'Skipping rondo insertions within {_min_margin_chords} chords of the ending ({_last_chord_idx}): {_skipped_insertions}')

        if rondo_insertions:
            notes_16 = _chord_idx_from_boundaries(notes_features_15, _boundaries, _tpq)
            notes_16 = apply_rondo(notes_16, rondo_sections, rondo_insertions, _boundaries, _tpq)
            notes_features_15 = notes_16[:, :15]
            logging.info(f'rondo applied: {notes_features_15.shape[0]} rows after splice')

    # now that you have the voices, assign note start times from durations of notes in a voice
    notes_features_final, voice_time = dmu.fix_start_times(notes_features_15, voice_time)
    print(f'{notes_features_final.shape = }') # notes_features_final.shape = (16495, 15)

    # 7/1/26 pm: the hold_scale/thin_ratio/sparse_range knobs above still left density_level 0-2
    # too busy, so directly drop a random fraction of notes for those levels only. Safe to do here
    # (post fix_start_times) since column 1 is now each note's own absolute start time, not a
    # duration other rows depend on — dropping rows doesn't shift anything else's timing.
    # 7/2/26: column 6 now holds the csound instrument voice number (fix_start_times overwrites
    # the tracker id with it above). Long-held sustained sections read as "dropped notes" rather
    # than natural sparseness when thinned at the same rate as busy arpeggio/bass material, so
    # give wood_winds/bowed_strings/brass_section csound voices a keep fraction that's a multiple
    # of that level's base rate (capped at 1.0 = untouched). Levels with no base filter (3, 4, 5)
    # default their base rate to 1.0, so a multiplier there only has effect if a base filter is
    # added for that level later.
    _SUSTAINED_CSOUND_VOICES = {12, 13, 14, 15, 16, 17, 18, 19, 25, 26, 27}  # wood_winds, bowed_strings, brass_section
    _SPARSE_KEEP_FRACTION = {0: 1 / 2.0, 1: 1 / 1.75, 2: 1 / 1.5}  # 2x/1.75x/1.5x fewer notes
    _SUSTAINED_BOOST_MULTIPLIER = {0: 2.0, 1: 2.0, 2: 1.5, 3: 1.15}  # relative to that level's base keep rate
    _base_keep_fraction = _SPARSE_KEEP_FRACTION.get(density_level, 1.0)
    _sustained_multiplier = _SUSTAINED_BOOST_MULTIPLIER.get(density_level)
    if density_level in _SPARSE_KEEP_FRACTION or _sustained_multiplier is not None:
        _n_before = notes_features_final.shape[0]
        _keep_prob = np.full(_n_before, _base_keep_fraction)
        if _sustained_multiplier is not None:
            _is_sustained = np.isin(notes_features_final[:, 6].astype(int), list(_SUSTAINED_CSOUND_VOICES))
            _sustained_keep_fraction = min(1.0, _base_keep_fraction * _sustained_multiplier)
            _keep_prob[_is_sustained] = _sustained_keep_fraction
            logging.info(f'sparse note-count filter: {int(np.sum(_is_sustained))} sustained-section rows at keep={_sustained_keep_fraction:.3f} (vs base {_base_keep_fraction:.3f})')
        _keep_mask = rng.random(_n_before) < _keep_prob
        notes_features_final = notes_features_final[_keep_mask]
        logging.info(f'sparse note-count filter (density_level={density_level}, base keep={_base_keep_fraction:.3f}): {_n_before} -> {notes_features_final.shape[0]} rows')
        print(f'sparse note-count filter (density_level={density_level}, base keep={_base_keep_fraction:.3f}): {_n_before} -> {notes_features_final.shape[0]} rows')

    # Filter inaudible notes: ampdb(velocity) * volume / 5 >= 1 matches Csound iamp = ampdb(iVel) * p15 / 5
    _velocity = notes_features_final[:, 3]
    _volume   = notes_features_final[:, 14]
    _audible  = (10 ** (_velocity / 20)) * _volume / 5 >= 1.0
    notes_features_audible = notes_features_final[_audible]
    _discarded = notes_features_final.shape[0] - notes_features_audible.shape[0]
    print(f'Audibility filter: {notes_features_final.shape[0]} -> {notes_features_audible.shape[0]} rows ({_discarded} inaudible discarded)')
    if version:
        np.save(f'{version}_features_array.npy', notes_features_audible)
        print(f'Saved {version}_features_array.npy ({notes_features_audible.shape[0]} rows)')

    # send the arrays to the file new_output.csd which csound will convert to a wave file to make sounds
    logging.debug(f'about to update_gliss_table with {stored_gliss.shape = }')
    tables = dmu.update_gliss_table(stored_gliss, stored_gliss.shape[0])
    logging.debug(f'back from update_gliss_table with {stored_gliss = }, {tables = }')
    print(f"Final list of notes with all features: {notes_features_audible.shape = }, and {include_instruments = }. {CSD_FILE = }")
    result = dmu.send_to_csound_file(notes_features_audible, voice_time, CSD_FILE, tempos = 't0 ' + str(tempo),\
        limit = limit, tempo = tempo, print_only = print_only, include_instruments = include_instruments)
    print(f'Back from send_to_csound_file. {result.shape = }')
    # report how long each instrument cluster plays 
    inst_durations = np.zeros((8,8), dtype=int) # start from time 0
    for section_num, section in zip(count(0,1), include_sections): # for each section
        if include_sections[section][0]: # if this section is to be played
                print(f'{section_num}: list of instruments in section: {include_sections[section][1]}')
                for inst_num, inst in zip(count(0,1), include_sections[section][1]):
                    # print the click count for each instrument
                    print(f'{inst_num}: voice_time[{inst}][total_clicks] = {voice_time[inst]["start"]}')
                    inst_durations[section_num, inst_num] = voice_time[inst]['start']
    # how many seconds will it take to play the piece
    print(f'{np.max(inst_durations) = }, {tempo = }, {np.max(inst_durations) * 60 / tempo + 6 = }')
    # calculate the longest playing instrument in seconds
    duration = round(np.max(inst_durations) * 60 / tempo + 6,0)
    print(f'duration in seconds: {duration}, min:sec {str(dmu.format_seconds_to_minutes(duration))[3:8]}')
    dur_short = str(dmu.format_seconds_to_minutes(duration))[3:8]
    # dur_short = dur_short[3:8] # 00:24:59.000 just the minutes and seconds
    logging.debug(f'duration: {dur_short}, {tempo = }')
    avg_probs = round(np.average(probs[:,1]),3)
    # avg_probs = 1.0 # why was this set to 1.0?
    # I want to switch the mod string to include the ratio_factor instead of avg_probs
    # and I want to switch the round(1 - max_silence, 2) to tolerance.
    density_tag = f'_df{density_level}' if density_level is not None else f'_md{int(max_delta):02d}'
    mod = f'{mod}_r{ratio_factor:.2f}{density_tag}_t{tolerance}_d{dur_short}_t{tempo:03}'
    mod = atu.windows_compliant_filename(mod) # get rid of the windows invalid characters in the file name
    print(f'{mod = }')
    return duration, volume_function, mod
# end of expand_chorale

def play_csound(csound = True, play = False):
    # os.system(f'play ~/Music/starting_csound.wav')
    result = 0
    if csound:
        logging.debug(f'logging csound output to csound_{CS_LOGNAME}')
        os.environ['SFDIR'] = os.path.expanduser(WAVE_DIR)
        result = os.system(f'csound new_output.csd -Ocsound_{CS_LOGNAME}') 
        result = os.system(f"grep 'invalid|replacing|range|error|cannot|rtevent|overall' -E csound_{CS_LOGNAME}") # inspect the log for important information
    if play: result = os.system(f'play {WAVE_DIR}/ball8.wav')

    return result


def trim_csound(version, duration, trim = True, mp3=True):
    logging.debug(f'{version = }')
    result = 0
    # Use a local variable so we don't shadow the module-level UPLOADS_DIR constant
    uploads_dir = UPLOADS_DIR
    if not mp3:
          uploads_dir = None

    if trim: # replace the duration and the input directory, then convolve and convert to mp3. 
        print(f'In trim_csound. {duration = }')
        result = os.system(f"sed -i 's/@replaceme@/{duration}/' {CSD_C_FILE}") 
        print(f"Sent this to os.system. sed -i s/@replaceme@/{duration}/ {CSD_C_FILE}. {result = }")
        command = f'sh {TRIM_SCRIPT} ball9 {version} {CS_SOURCE_DIR} {uploads_dir or ""}'
        print(f'sending command to execute the trim script:\n{command}')
        result = os.system(command) 
        result = os.system(f"sed -i 's/{duration}/@replaceme@/' {CSD_C_FILE}") 
        print(f'Sent this to os.system. sed -i s/{duration}/@replaceme@/ {CSD_C_FILE}. {result = }')
    else: print(f'Please note that you set {trim = } which means it will not be convolved.') 
    return result


def create_repeat_array_pattern(chorale_array, pattern=None, axis=1):
    """
    Repeat each chord according to a fixed pattern.

    Args:
        chorale_array: Input array. Expected shape (voices, time_steps, features) so chords are on axis=1.
        pattern: List of repeat counts. If None, uses default prime pattern.
        axis: The axis containing the chords/time steps (default 1).

    Returns:
        Expanded array with repeated chords, and the repeat_values used (array length = number of chords).
    """
    # Determine number of chords along the requested axis
    num_chords = chorale_array.shape[axis]

    if pattern is None:
        # Default: use prime numbers
        pattern = np.array([3, 5, 11, 17, 31], dtype=int)
    else:
        pattern = np.array(pattern, dtype=int)
    logging.info(f'Using repeat pattern: {pattern = }')
    # rng.shuffle(pattern)  # Shuffle the pattern for randomness
    pattern = rng.choice(pattern, size=pattern.shape[0], replace=True) # much more random the piece will be. 
    logging.info(f'After shuffle: {pattern = }')
    # Create repeat sequence by cycling through pattern to length num_chords
    repeat_values = np.tile(pattern, int(np.ceil(num_chords / len(pattern))))[:num_chords].astype(int)

    # Sanity checks
    assert repeat_values.shape[0] == num_chords, "repeat_values must have one entry per chord"

    # Repeat the chorale along the chord axis
    repeated_chords = np.repeat(chorale_array, repeat_values, axis=axis)

    # Return repeated array and the repeat pattern used
    return repeated_chords, repeat_values


def chorale_to_wave_v4(version, album, include_sections, ratio_factor, limit_max=47,\
      short_repeats=True, include_list=np.array([]), csound=True,\
      convolve=True, mod_letter='a', max_cents_slide=48, print_only=0,\
      limit=0, use_opt_file=True, \
      cent_file_partial='-cents.npy', show_volumes=False, woodwinds_volume=15,\
    melody_sustain=15, bass_sustain=15, bass_hold_scale=1.0, bass_hold_swing=0.75, bass_hold_cycles=4,
    use_werck_top_notes=False, mp3=True, tolerance=1,\
      stability_factor=0.0, max_delta=33, spread=7, fp_density_starts=None, fp_hold_scale=1.0, prime_count=8, density_level=5,
        fatigue_min_chain=2, fatigue_density_threshold=1, include_slice=None,
        deep_bass_backoff=1.0, back_off_clicks=0.0,
        rondo_sections=None, rondo_insertions=None):

    print(f'In chorale_to_wave_v4. {version = }, {limit_max = }, {short_repeats = }, {ratio_factor = }')
    if short_repeats: # if you just want a straight woodwind/brass chorale, set short_repeats = True
        mask = False # no complex algorithm to create different repeating arpeggio patterns
        woodwinds_volume = 13
    else:
        mask = True

    # assign the list of valid intervals from a tonality diamond.
    tonal_diamond = np.array(atu.build_tonal_diamond(limit_max, penalize_7_11=False)) 

    # Load the chorale and some metadata - Since we already have the chorale in cents in a numpy file.

    cent_file_name = os.path.join(numpy_dir, f'{version}{cent_file_partial}') # fills out to the actual cent file name
    
    # If the file doesn't exist, try to find a file with encoded parameters.
    # Also try alternative suffixes so a mixed directory (some -opt.npy, some
    # -trans-sa-opt.npy) works without specifying --cent_file_partial per chorale.
    if not os.path.exists(cent_file_name):
        import glob
        alt_suffixes = [cent_file_partial, '-trans-sa-opt.npy', '-opt.npy']
        matches = []
        for sfx in alt_suffixes:
            pattern = os.path.join(numpy_dir, f'{version}_t*_r*_lm*{sfx}')
            matches = glob.glob(pattern)
            if matches:
                break
        if matches:
            # Use the first match (there should only be one per chorale)
            cent_file_name = matches[0]
            print(f'File not found with basic name, using encoded filename: {os.path.basename(cent_file_name)}')
            # Extract parameters from the found filename
            file_params = parse_params_from_filename(cent_file_name)
            if file_params:
                # Update the parameters that will be used
                tolerance = file_params['tolerance']
                ratio_factor = file_params['ratio_factor']
                limit_max = file_params['limit_max']
                print(f'Extracted from filename: tolerance={tolerance}, ratio_factor={ratio_factor}, limit_max={limit_max}')
        else:
            print(f'Warning: Could not find {cent_file_name} or any encoded variant')
    
    print(f'About to load {cent_file_name = }')
    cent_value_chorale = np.load(cent_file_name)
    # print(f'{chorale_in_cents.shape = }, {chorale_in_cents[:,10:12] = }')
    print(f'after np.load {cent_file_name = }, {cent_value_chorale.shape = }')
    if use_werck_top_notes:
        top_notes_file = os.path.join(numpy_dir, f'{version}-w-top_notes.npy')
    elif use_opt_file:
        top_notes_file = os.path.join(numpy_dir, f'{version[:6]}top-notes.npy')
    else: 
        top_notes_file = os.path.join(numpy_dir, f'{version}top-notes.npy')
    try:
        top_notes = np.load(top_notes_file)
    except FileNotFoundError:
        print(f"Warning: {top_notes_file} not found. Using default top notes.")
        top_notes = None
    _, top_notes, chorale, root, mode, keys = atu.load_chorale_in_cents(version, numpy_dir)
    print(f'root key: {keys[root]}, {mode = }')
    print(f'After loading top_notes for {version = } by reading numpy file: {version}top-notes.npy')
    atu.log_top_notes(top_notes)

    n_chords_raw = cent_value_chorale.shape[1]
    effective_include = list(include_list) if include_list is not None else []
    if include_slice is not None:
        start, end = include_slice
        if end <= start:
            raise SystemExit(f'--include_slice expects END > START, got START={start}, END={end}')
        if start < 0 or end > n_chords_raw:
            raise SystemExit(
                f'--include_slice expects [START, END) within 0..{n_chords_raw}, '
                f'got START={start}, END={end}'
            )
        effective_include.extend(range(start, end))

    # Keep deterministic ordering and remove duplicates if both args were used.
    effective_include = sorted(set(effective_include))

    if len(effective_include) > 0:
        cent_value_chorale = cent_value_chorale[:, effective_include]
        chorale = chorale[:, effective_include]
    if len(effective_include) < chorale.shape[1]:
        print(f'{effective_include = }')

    # we don't need to score the chords at this point.
    # print(f'About to score the chorale as loaded. {chorale_in_cents.shape = }')
    # new_scores = np.zeros(cent_value_chorale.shape[1],dtype=int)
    # for inx, chord in zip(count(0,1), cent_value_chorale.T):
    #     new_scores[inx] = atu.score_chord_cents_v2(chord, tonal_diamond)
        # print(f'{inx}: {chord = }, {new_scores[inx] = }')

    # tell me about the chorale you are about to use as the basis for the piece of music.
    logging.info(f'{version = }, {chorale.shape = }, {cent_value_chorale.shape = }, {top_notes.shape = }, {short_repeats = }')

    # create a string of the key variables for use in the name of the MP3 file.    
    mod = f'{version[-2:]}{mod_letter}_lm{limit_max}'

    # initialize some values based on other values
    # if you are just playing a chorale straight as Bach wrote it, only repeats=2, otherwise many more repeats
    octave = chorale // 12
    print(f'{cent_value_chorale.shape = }, {octave.shape = }')
    chorale_in_cents_octaves = np.stack((cent_value_chorale, octave), axis=2)  # shape (time_steps, 2)
    if short_repeats: 
        repeats = np.array([2]) # How many times to repeat each chord. 
        choral_octaves_repeated = chorale_in_cents_octaves # keep original 4 SATB voices
        logging.info(f'{chorale_in_cents_octaves.shape = }, {choral_octaves_repeated.shape = }')
    else: 
        # here is where we need to set the repeats. We want the repeats to be different numbers, not an integer. 
        # all_primes = np.array([1, 3, 5, 11, 17, 31, 47, 71])
        # all_primes = np.array([1, 2, 4, 8, 16, 32, 48, 72])
        # all_primes = rng.choice([np.array([1, 2, 4, 8, 16, 32, 48, 72]), np.array([1, 3, 5, 11, 17, 31, 47, 71])])
        all_primes = rng.choice([np.array([1, 2, 4, 8, 16, 32]), np.array([1, 3, 5, 11, 17, 31])])
        
        primes = all_primes[:int(np.clip(prime_count, 1, all_primes.shape[0]))]
        # the previous line is just a super-safe way to slice the all_primes array to the first prime_count elements of the prime_count array. 
        choral_octaves_repeated, repeats = create_repeat_array_pattern(chorale_in_cents_octaves, pattern=primes)
        logging.info(f'created repeats pattern using primes. {primes = }, {prime_count = }, {repeats[:primes.shape[0]] = }')

    logging.info(f'{repeats.shape = }, after merging octaves and cents {chorale_in_cents_octaves.shape = }, after repeats applied: {choral_octaves_repeated.shape = }')

    chorale, voice_time, keys = initialize_chorale_and_instruments(chorale, root, mode, version, repeats, double_ending = False) 

    logging.info(f'Before fixing octave values based on 1150+ cent values: {np.unique(chorale_in_cents_octaves[:,:,1].T, return_counts = True)}')
    # We need to handle the case of the 1150+ cent values requiring lowering the octave for that chord by one. 
    # print(f'{chorale_in_cents.shape = }, {octave.shape = }, {chorale_in_cents_octaves.shape = }')
    for chord_num, chord in zip(count(0,1),chorale_in_cents_octaves[:,:,0].T):
        for voice_num, note in zip(count(0,1), chord):
                if note > 1150: 
                    chorale_in_cents_octaves[voice_num, chord_num, 1] -= 1
    logging.info(f'After fixing octave values based on 1150+ cent values: {np.unique(chorale_in_cents_octaves[:,:,1].T, return_counts = True)}')

    print(f'{choral_octaves_repeated.shape = }, {tonal_diamond.shape = }')

    logging.info(f'about to call build_glides_array with {choral_octaves_repeated.shape = }')
    # build the glides arrays - look for pairs of notes that need to have slide between them
    # if they have the same midi value but a different cent value, up to a limit of a certain number of cents
    chorale_in_cents_slides, glides, stored_gliss, t_num = \
        atu.build_glides_array(choral_octaves_repeated, keys, max_cents_slide=max_cents_slide)
    logging.info(f'Back in main line. back from build_glides_array. {glides.shape = }, {stored_gliss.shape = }, {t_num = }')
    #     atu.build_glides_report(chorale_in_cents_slides, glides, stored_gliss) 
    logging.info(f'about to call expand_chorale with {choral_octaves_repeated.shape = }\n{chorale_in_cents_slides.shape = }')

    # Staccato thinning ratio is derived from density_level: sparse levels thin more, dense levels thin less
    _level = density_level if density_level is not None else len(FATIGUE_THIN_RATIOS) - 1
    fatigue_thin_ratio = FATIGUE_THIN_RATIOS[int(np.clip(_level, 0, len(FATIGUE_THIN_RATIOS) - 1))]
    logging.info(f'fatigue_thin_ratio={fatigue_thin_ratio} derived from density_level={density_level}')

    # apply the repeats to increase the density and length of the piece, select which instruments will play, and other tasks
    duration, volume_function, mod = expand_chorale(repeats, chorale_in_cents_slides,\
        glides, stored_gliss, voice_time, include_sections, mod, ratio_factor, mask=mask,\
        octave_reduce=1, woodwinds_volume=woodwinds_volume, print_only=print_only,\
        limit=limit, melody_sustain=melody_sustain, bass_sustain=bass_sustain,
        bass_hold_scale=bass_hold_scale, bass_hold_swing=bass_hold_swing, bass_hold_cycles=bass_hold_cycles, tolerance=tolerance,\
        stability_factor=stability_factor, max_delta=max_delta, spread=spread,
        fp_density_starts=fp_density_starts, fp_hold_scale=fp_hold_scale, density_level=density_level,
        fatigue_thin_ratio=fatigue_thin_ratio, fatigue_min_chain=fatigue_min_chain, fatigue_density_threshold=fatigue_density_threshold, version=version,
        deep_bass_backoff=deep_bass_backoff, back_off_clicks=back_off_clicks,
        rondo_sections=rondo_sections, rondo_insertions=rondo_insertions)

    if csound: # send the results to csound
        result_of_call = play_csound(csound = True, play = False)
        if result_of_call != 0: print(f'possible failure in play_csound function. {result_of_call = }')         
    logging.info(f'about to call trim_csound. {mod = }, {duration = }')    
    if convolve: # convolve the results 
        result_of_call = trim_csound(mod, duration, trim = True, mp3=mp3)
        if result_of_call != 0: print(f'possible failure in convolution using trim_csound. {result_of_call = }')

    if show_volumes: # show a graph of the volume function
        save_path = 'plots'
        os.makedirs(save_path, exist_ok=True)
        display_volumes(volume_function, include_sections, save_path=os.path.join(save_path, f'{version}.jpg'))

    logging.info(f'End of song generation step') 
    return(chorale)
# end of chorale_to_wave_v4


# mainline - this cell tunes and creates music
################################################################################
################################################################################
#### Take an already tuned chorale and make a full piece of music out of it ####
################################################################################
################################################################################
def mainline(chorale_override=None, short_repeats=False, just_triangle=False, include_list=None, csound=True, convolve=True, \
             mp3=True, max_cents_slide=35, melody_sustain=3, bass_sustain=15,
             bass_hold_scale=1.0, bass_hold_swing=0.75, bass_hold_cycles=4, cent_file_partial='-trans-sa-opt.npy', \
             show_volumes=True, mod_letter='a', album=3, use_werck_top_notes=False, tolerance=1, ratio_factor=0.75, \
             numpy_dir_arg=None, stability_factor=0.0, max_delta=33, spread=7, limit_max=23, auto_density=False, prime_count=8, density_level=None, shuffle_density=False, auto_density_weights=None,
             fatigue_min_chain=2, fatigue_density_threshold=1, include_slice=None,
             deep_bass_backoff=1.0, back_off_clicks=0.0,
             rondo_sections=None, rondo_insertions=None):
      if include_list is None:
            include_list = []

      # Keep level 5 as the effective default, but allow --auto_density to operate
      # when density_level is not explicitly provided.
      if density_level is None and not auto_density:
            density_level = 5

      # Override numpy_dir: use explicit argument if provided, otherwise use tolerance-specific directory
      global numpy_dir
      if numpy_dir_arg is not None:
            numpy_dir = os.path.join(local_dir, numpy_dir_arg) if not os.path.isabs(numpy_dir_arg) else numpy_dir_arg
      else:
            numpy_dir = os.path.join(local_dir, 'Archive', 'opt', f'tolerance-{tolerance}')
      
      total_cache_count_sr = 0
      non_cached_count_sr = 0
      cache_s= {}
      total_cache_count_fi = 0
      non_cached_count_fi = 0
      cache_fi = {}
      total_cache_count_sc = 0
      non_cached_count_sc = 0
      cache_sc = {}
      total_cache_count_fc = 0
      non_cached_count_fc = 0
      cache_fc = {}

      dmu.start_logger(JUPYTER_LOG, log_level = 'info')
      print(f'{platform.uname() = }')
      woodwinds_volume = 16 # only used if short_repeats = True
      
      # Set the instrument sections based on mode combinations
      # Priority: just_triangle determines instrument choice, short_repeats determines complexity
      if just_triangle and short_repeats:
            # Both flags: Triangle samples with straight chorale (no complex patterns)
            include_sections = {
                  # section --      play or not --    instruments in the section
                  'finger_pianos': [False, np.array(['fing1', 'fing2', 'fing3', 'fing4', 'fing5', 'fing6', 'bfin1', 'bfin2'])],
                  'wood_winds':    [True, np.array(['trian1', 'trian2', 'trian3', 'trian4', 'trian5', 'trian6', 'trian7', 'trian8'])],
                  'pizz_strings':  [False, np.array(['vlip1', 'vlip2', 'vlip3', 'vlip4', 'vlap1', 'vlap2', 'celp1', 'celp2'])],
                  'bowed_strings': [False, np.array(['vliv1', 'vliv2', 'vliv3', 'vliv4', 'vlav1', 'vlav2', 'celv1', 'celv2'])],
                  'brass_section': [False, np.array(['trmp1', 'trmp2', 'trmp3', 'trmp4', 'trmb1', 'trmb2', 'tuba1', 'tuba2'])],
                  'marimbas':   [False, np.array(['xylp1', 'mari1', 'vibp1', 'harp1', 'ebss1', 'stri1', 'bgui1', 'long1'])],
                  'bass_section':  [False, np.array(['bfin3', 'bfin4', 'celp3', 'celp4', 'bgui3', 'bgui2', 'long2', 'long3'])],
                  'melody_section':[False, np.array(['flut2', 'flut3', 'clar2', 'vibp1', 'oboe3', 'basn4', 'trmp5', 'frnh3'])]}
      elif just_triangle:
            # Triangle only: Triangle samples with complex arpeggio patterns
            include_sections = {
                  # section --      play or not --    instruments in the section
                  'finger_pianos': [False, np.array(['fing1', 'fing2', 'fing3', 'fing4', 'fing5', 'fing6', 'bfin1', 'bfin2'])],
                  'wood_winds':    [True, np.array(['trian1', 'trian2', 'trian3', 'trian4', 'trian5', 'trian6', 'trian7', 'trian8'])],
                  'pizz_strings':  [False, np.array(['vlip1', 'vlip2', 'vlip3', 'vlip4', 'vlap1', 'vlap2', 'celp1', 'celp2'])],
                  'bowed_strings': [False, np.array(['vliv1', 'vliv2', 'vliv3', 'vliv4', 'vlav1', 'vlav2', 'celv1', 'celv2'])],
                  'brass_section': [False, np.array(['trmp1', 'trmp2', 'trmp3', 'trmp4', 'trmb1', 'trmb2', 'tuba1', 'tuba2'])],
                  'marimbas':   [False, np.array(['xylp1', 'mari1', 'vibp1', 'harp1', 'ebss1', 'stri1', 'bgui1', 'long1'])],
                  'bass_section':  [False, np.array(['bfin3', 'bfin4', 'celp3', 'celp4', 'bgui3', 'bgui2', 'long2', 'long3'])],
                  'melody_section':[True, np.array(['flut2', 'flut3', 'clar2', 'vibp1', 'oboe3', 'basn4', 'trmp5', 'frnh3'])]}
      elif short_repeats:
            # Short repeats only: McGill samples with straight chorale (no complex patterns)
            include_sections = {
                  # define a dictionary where each key
                  # represents a section of a musical ensemble and the corresponding value is a list
                  # containing a boolean indicating whether the section plays instruments or not, and
                  # a NumPy array listing the instruments in that section.
                  # section --      play or not --    instruments in the section
                  # Use high-range instruments for S/A (tracks 0-3), low-range for T/B (tracks 4-7)
                  # think SS AA TT BB
                  'finger_pianos': [False, np.array(['fing1', 'fing2', 'fing3', 'fing4', 'fing5', 'fing6', 'bfin1', 'bfin2'])],
                  'wood_winds':    [True, np.array(['flut1', 'clar1', 'oboe1', 'oboe2', 'frnh1', 'frnh2', 'basn1', 'basn2'])],
                  'pizz_strings':  [False, np.array(['vlip1', 'vlip2', 'vlip3', 'vlip4', 'vlap1', 'vlap2', 'celp1', 'celp2'])],
                  'bowed_strings': [False, np.array(['vliv1', 'vliv2', 'vliv3', 'vliv4', 'vlav1', 'vlav2', 'celv1', 'celv2'])],
                  'brass_section': [True, np.array(['trmp1', 'trmp2', 'trmp3', 'trmp4', 'trmb1', 'trmb2', 'tuba1', 'tuba2'])],
                  'marimbas':   [False, np.array(['xylp1', 'mari1', 'vibp1', 'harp1', 'ebss1', 'stri1', 'bgui1', 'long1'])],
                  'bass_section':  [False, np.array(['bfin3', 'bfin4', 'celp3', 'celp4', 'bgui3', 'bgui2', 'long2', 'long3'])],
                  'melody_section':[False, np.array(['flut2', 'flut3', 'clar2', 'mari2', 'oboe3', 'basn4', 'trmp5', 'frnh3'])]}
      else:
            # Neither flag: Full mode with all McGill instruments and complex arpeggio patterns
            include_sections = {
                  # section --      play or not --    instruments in the section
                  'finger_pianos': [True, np.array(['fing1', 'fing2', 'fing3', 'bfin1', 'fing4', 'fing5', 'fing6', 'bfin2'])],
                  'wood_winds':    [True, np.array(['flut1', 'clar1', 'oboe1', 'oboe2', 'frnh1', 'frnh2', 'basn1', 'basn2'])],
                  'pizz_strings':  [True, np.array(['vlip1', 'vlip2', 'vlap1', 'celp1', 'vlim1', 'vlim2', 'vlap2', 'celp2',])],
                  'bowed_strings': [True, np.array(['vliv1', 'vliv2', 'vliv3', 'vliv4', 'vlav1', 'vlav2', 'celv1', 'celv2'])],
                  'brass_section': [True, np.array(['trmp1', 'trmp2', 'trmp3', 'trmp4', 'trmb1', 'trmb2', 'tuba1', 'tuba2'])],
                  'marimbas':   [True, np.array(['mari1', 'mari2', 'mari3', 'mari4', 'mari5', 'mari6', 'mari7', 'mari8'])],
                  'bass_section':  [True, np.array(['bgui1', 'bgui2', 'bgui3', 'bfin3', 'bfin4', 'bgui4', 'bfin5', 'bgui5'])],
                  'melody_section':[True, np.array(['flut2', 'flut3', 'clar2', 'vibp1', 'oboe3', 'basn4', 'trmp5', 'vibp2'])]}
      
      limit = 0 # how many seconds to produce. 0 means no limit.
      penalize_7_11 = False # if true then double the value of all the intervals in the atu.build_tonal_diamond function which calls _find_limit to do the deed
      print_only = 10 # how many lines of csound code should be printed to the log file.
      total_averages = 0
      max_overall_score = 0
      # limit_max is now a parameter (was hardcoded to 19)

      chorale_list = ['bwv253','bwv254','bwv255','bwv256','bwv257','bwv258','bwv259','bwv260','bwv261','bwv262','bwv263','bwv264']
      # allow override from command-line: single name, comma-separated names, or 'all'
      if chorale_override:
            if isinstance(chorale_override, list):
                  chorale_list = chorale_override
            elif isinstance(chorale_override, str):
                  s = chorale_override.strip()
                  if s.lower() in ('all', '*'):
                        pass
                  elif ',' in s:
                        chorale_list = [c.strip() for c in s.split(',') if c.strip()]
                  else:
                        chorale_list = [s]
      else:
            chorale_list.reverse()

      #   chorale_list=['bwv253']
      if auto_density and density_level is None:
            n = len(chorale_list)
            if auto_density_weights is None:
                weighted_levels = list(range(len(DENSITY_LEVELS)))
            else:
                weighted_levels = []
                for level, weight in enumerate(auto_density_weights):
                    weighted_levels.extend([level] * int(weight))
            repeats_needed = (n + len(weighted_levels) - 1) // len(weighted_levels)
            level_sequence = (weighted_levels * repeats_needed)[:n]
            if shuffle_density:
                rng.shuffle(level_sequence)
      else:
            level_sequence = None

      for inx, version in enumerate(chorale_list):
            if density_level is not None:
                  _active_level = int(np.clip(density_level, 0, len(DENSITY_LEVELS) - 1))
                  _bhs, _bhsw, _fhs, _fdi, _np = DENSITY_LEVELS[_active_level]
                  _fp_starts = FP_DENSITY_MAPS[_fdi]
                  print(f'{version}: fixed density level {_active_level} — bass_hold_scale={_bhs}, bass_hold_swing={_bhsw}, fp_hold_scale={_fhs}, num_primes={_np}, fp_density={_fp_starts}')
            elif auto_density:
                  _active_level = level_sequence[inx]
                  _bhs, _bhsw, _fhs, _fdi, _np = DENSITY_LEVELS[_active_level]
                  _fp_starts = FP_DENSITY_MAPS[_fdi]
                  print(f'{version}: auto density level {_active_level} — bass_hold_scale={_bhs}, bass_hold_swing={_bhsw}, fp_hold_scale={_fhs}, num_primes={_np}, fp_density={_fp_starts}')
            else:
                  _active_level = None
                  _bhs, _bhsw, _fhs, _fp_starts, _np = bass_hold_scale, bass_hold_swing, 1.0, None, prime_count
            print(f'Running {version}')
            chorale = chorale_to_wave_v4(version, album, include_sections, ratio_factor, limit_max=limit_max,\
                  print_only=print_only, short_repeats=short_repeats, include_list=include_list,\
                  csound=csound, convolve=convolve, mod_letter=mod_letter, \
                  max_cents_slide=max_cents_slide, show_volumes=show_volumes, \
                  woodwinds_volume=woodwinds_volume, melody_sustain=melody_sustain, bass_sustain=bass_sustain, \
                bass_hold_scale=_bhs, bass_hold_swing=_bhsw, bass_hold_cycles=bass_hold_cycles,
                  cent_file_partial=cent_file_partial, use_werck_top_notes=use_werck_top_notes, mp3=mp3,\
                  tolerance=tolerance, stability_factor=stability_factor, max_delta=max_delta,\
                  spread=spread, fp_density_starts=_fp_starts, fp_hold_scale=_fhs, prime_count=_np, density_level=_active_level,
                                    fatigue_min_chain=fatigue_min_chain, fatigue_density_threshold=fatigue_density_threshold,
                                    include_slice=include_slice,
                                    deep_bass_backoff=deep_bass_backoff, back_off_clicks=back_off_clicks,
                                    rondo_sections=rondo_sections, rondo_insertions=rondo_insertions)

      # Generate a playlist of all the pieces in this album. This never worked correctly in the pod.
      print(f' {UPLOADS_DIR = }')
      now = datetime.now()
      if csound and convolve:
            for n in [album]: # if album is a list
                  print(f'album: {n}{mod_letter}')
                  # create a playlist of this set of pieces in the uploads directory sorted by duration, shortest first.
                  target_dir = os.path.join(UPLOADS_DIR, f'{mod_letter}{n}-{now.strftime("%m-%d-%y")}' )
                  # try to create it and if it already exists, continue
                  print(f'Album target directory: {target_dir}')


if __name__ == "__main__":
      parser = argparse.ArgumentParser(description='Generate chorale audio and plots')
      parser.add_argument("--chorale_list", "--chorale_name", "--chorale", dest="chorale_name",
                          nargs='+',
                          help="One or more chorale names, e.g. --chorale_list bwv253 bwv254 (default: all 12)",
                          default=None)
      parser.add_argument("--short_repeats", dest="short_repeats", action="store_true",
                          help="Play a straight woodwind/brass chorale without complex arpeggio patterns")
      parser.add_argument("--just_triangle", dest="just_triangle", action="store_true",
                      help="Use triangle samples instead of McGill samples (no finger pianos or complex patterns)")
      parser.add_argument("--include_list", dest="include_list", nargs='+', type=int, default=[],
                      help="List of chord numbers to include in the piece (default: empty list for all chords)")
      parser.add_argument("--include_slice", dest="include_slice", nargs=2, type=int, metavar=('START', 'END'), default=None,
                      help="Raw chord slice [START, END) on loaded uncompressed arrays, e.g. --include_slice 228 273")
      parser.add_argument("--csound", dest="csound", action="store_true", default=True,
                          help="Run the generated .csd file through csound to create a .wav file (default: True)")
      parser.add_argument("--no_csound", dest="csound", action="store_false",
                          help="Disable csound processing")
      parser.add_argument("--convolve", dest="convolve", action="store_true", default=True,
                          help="Apply convolution to the output (default: True)")
      parser.add_argument("--no_convolve", dest="convolve", action="store_false",
                          help="Disable convolution")
      parser.add_argument("--mp3", dest="mp3", action="store_true", default=True,
                          help="Generate MP3 output (default: True)")
      parser.add_argument("--no_mp3", dest="mp3", action="store_false",
                          help="Disable MP3 generation")
      parser.add_argument("--max_cents_slide", dest="max_cents_slide", type=float, default=35,
                          help="Maximum cents slide (keep under 50 to avoid annoying glides) (default: 35)")
      parser.add_argument("--melody_sustain", dest="melody_sustain", type=float, default=3,
                          help="Melody sustain duration (default: 3)")
      parser.add_argument("--bass_sustain", dest="bass_sustain", type=int, default=15,
                          help="Bass sustain duration — lower values reduce simultaneous bass voices (default: 15)")
      parser.add_argument("--bass_hold_scale", dest="bass_hold_scale", type=float, default=1.0,
                        help="Average bass hold-time multiplier for active/silent run lengths (default: 1.0)")
      parser.add_argument("--bass_hold_swing", dest="bass_hold_swing", type=float, default=0.5,
                        help="How strongly bass hold lengths oscillate faster/slower over time, 0.0-0.95 (default: 0.5)")
      parser.add_argument("--bass_hold_cycles", dest="bass_hold_cycles", type=int, default=4,
                        help="How many faster/slower bass hold sweeps occur over the piece (default: 4)")
      parser.add_argument("--cent_file_partial", dest="cent_file_partial", type=str, 
                          default='-trans-sa-opt.npy',
                          help="Partial name of the cent file (default: '-trans-sa-opt.npy')")
      parser.add_argument("--show_volumes", dest="show_volumes", action="store_true", default=True,
                          help="Display volume plots (default: True)")
      parser.add_argument("--no_show_volumes", dest="show_volumes", action="store_false",
                          help="Disable volume plots")
      parser.add_argument("--mod_letter", dest="mod_letter", type=str, default='a',
                          help="Letter to append to output file name (default: 'a')")
      parser.add_argument("--album", dest="album", type=int, default=3,
                          help="Album number to distinguish sets (default: 3)")
      parser.add_argument("--use_werck_top_notes", dest="use_werck_top_notes", action="store_true",
                          help="Use Werckmeister top notes (default: False)")
      parser.add_argument("--tolerance", dest="tolerance", type=int, default=None,
                          help="Tolerance level for matching intervals (1, 2, 3, or 4). Read from filename if encoded there; defaults to 1 otherwise.")
      parser.add_argument("--ratio_factor", dest="ratio_factor", type=float, default=1.5,
                          help="ratio_factor used to create the array of cents (default: 1.5)")
      parser.add_argument("--numpy_dir", dest="numpy_dir", type=str, default='Archive/straw-man/best-tunings',
                          help="Directory containing the numpy cent arrays (default: Archive/straw-man/best-tunings)")
      parser.add_argument("--stability_factor", dest="stability_factor", type=float, default=0.0,
                          help="stability_factor used when tuning (label only; included in filename as _sfX.XX) (default: 0.0)")
      parser.add_argument("--max_delta", dest="max_delta", type=int, default=33,
                          help="max_delta used when tuning (label only; included in filename as _mdXX) (default: 33)")
      parser.add_argument("--spread", dest="spread", type=int, default=7,
                          help="spread used when tuning (label only; included in filename as _spXX) (default: 7)")
      parser.add_argument("--limit_max", dest="limit_max", type=int, default=17,
                          help="Tonal diamond limit_max for scoring (default: 17)")
      parser.add_argument("--auto_density", dest="auto_density", action="store_true", default=False,
                          help="Automatically cycle through 6 density levels across chorales (default: False)")
      parser.add_argument("--shuffle_density", dest="shuffle_density", action="store_true", default=False,
                          help="Randomly shuffle density level assignments each run (use with --auto_density; default: False)")
      parser.add_argument("--auto_density_weights", dest="auto_density_weights", type=str, default=None,
                          help="Comma-separated weights for density levels 0..5 when using --auto_density (default: equal weights). Example: 1,1,1,2,3,4")
      parser.add_argument("--density_level", dest="density_level", type=int, default=None,
                          help="Pin all chorales to one density level 0-5 (0=sparsest, 5=densest). Overrides --auto_density. If omitted, defaults to 5 unless --auto_density is set.")
      parser.add_argument("--prime_count", dest="prime_count", type=int, default=8,
                          help="How many primes from [1,3,5,11,17,31,47,71] to use for chord repeats (1-8, default: 8); overridden per-chorale when --auto_density is set")
      parser.add_argument("--fatigue_min_chain", dest="fatigue_min_chain", type=int, default=2,
                          help="Minimum consecutive 0.25-duration notes/bins before staccato thinning is applied (default: 2)")
      parser.add_argument("--fatigue_density_threshold", dest="fatigue_density_threshold", type=int, default=1,
                          help="Phase 2 thinning: minimum simultaneous staccato voices per time bin to be considered dense (default: 1)")
      parser.add_argument("--deep_bass_backoff", dest="deep_bass_backoff", type=float, default=1.0,
                          help="Scale factor (0.0-1.0) applied to all bass finger piano rescue probabilities; 0.5 rescues half as many deep bass notes, 0.0 disables rescue entirely (default: 1.0)")
      parser.add_argument("--back_off_clicks", dest="back_off_clicks", type=float, default=0.0,
                          help="Skip bass rescue for notes whose duration (in clicks) is <= this value; 0.25 suppresses rescue of short staccato notes (default: 0.0 = no threshold)")
      parser.add_argument("--rondo_section_a", dest="rondo_section_a", type=int, nargs=2, default=None,
                          metavar=('START', 'END'),
                          help="Section A chord range [START, END) for rondo/leitmotif recall, e.g. --rondo_section_a 0 16")
      parser.add_argument("--rondo_section_b", dest="rondo_section_b", type=int, nargs=2, default=None,
                          metavar=('START', 'END'),
                          help="Section B chord range [START, END) for rondo/leitmotif recall, e.g. --rondo_section_b 48 64")
      parser.add_argument("--rondo_insert_a_after", dest="rondo_insert_a_after", type=int, nargs='+', default=None,
                          metavar='CHORD',
                          help="Insert section A after each listed chord index, e.g. --rondo_insert_a_after 32 80")
      parser.add_argument("--rondo_insert_b_after", dest="rondo_insert_b_after", type=int, nargs='+', default=None,
                          metavar='CHORD',
                          help="Insert section B after each listed chord index, e.g. --rondo_insert_b_after 64")
      args = parser.parse_args()

      # Try to extract parameters from cent_file_partial filename if it contains them
      # This allows parameters to be encoded in the filename instead of passed as arguments
      file_params = None
      if args.cent_file_partial:
            file_params = parse_params_from_filename(args.cent_file_partial)
            if file_params:
                  # Use file parameters as defaults if command-line args are still at their defaults
                  if args.tolerance is None:
                        args.tolerance = file_params['tolerance']
                        logging.info(f'Using tolerance={args.tolerance} from filename')
                  if args.ratio_factor == 1.5:  # default value
                        args.ratio_factor = file_params['ratio_factor']
                        logging.info(f'Using ratio_factor={args.ratio_factor} from filename')
                  if args.limit_max == 17:  # default value
                        args.limit_max = file_params['limit_max']
                        logging.info(f'Using limit_max={args.limit_max} from filename')

      if args.tolerance is None:
            args.tolerance = 1
            logging.info('tolerance not specified; defaulting to 1')

      parsed_auto_density_weights = None
      if args.auto_density_weights is not None:
            try:
                  parsed_auto_density_weights = [int(part.strip()) for part in args.auto_density_weights.split(',')]
            except ValueError as exc:
                  raise SystemExit(f'Invalid --auto_density_weights value: {args.auto_density_weights}') from exc
            if len(parsed_auto_density_weights) != len(DENSITY_LEVELS):
                  raise SystemExit(f'--auto_density_weights must provide exactly {len(DENSITY_LEVELS)} integers for levels 0..{len(DENSITY_LEVELS)-1}')
            if any(weight < 0 for weight in parsed_auto_density_weights):
                  raise SystemExit('--auto_density_weights cannot include negative values')
            if sum(parsed_auto_density_weights) == 0:
                  raise SystemExit('--auto_density_weights cannot all be zero')

      include_list = list(args.include_list) if args.include_list is not None else []

      # Build rondo_sections / rondo_insertions from the four --rondo_* args
      rondo_sections: dict | None = None
      rondo_insertions: list | None = None
      _rondo_raw = {
          'a': (args.rondo_section_a, args.rondo_insert_a_after),
          'b': (args.rondo_section_b, args.rondo_insert_b_after),
      }
      _sec: dict = {}
      _ins: list = []
      for label, (sec_range, insert_after) in _rondo_raw.items():
          if sec_range is not None:
              if sec_range[1] <= sec_range[0]:
                  raise SystemExit(f'--rondo_section_{label}: END ({sec_range[1]}) must be > START ({sec_range[0]})')
              _sec[label] = tuple(sec_range)
          if insert_after is not None:
              if sec_range is None:
                  raise SystemExit(f'--rondo_insert_{label}_after requires --rondo_section_{label} to be defined')
              for chord in insert_after:
                  _ins.append((chord, label))
      if _sec:
          rondo_sections = _sec
          rondo_insertions = sorted(_ins, key=lambda x: x[0])

      mainline(chorale_override=args.chorale_name, short_repeats=args.short_repeats,
               just_triangle=args.just_triangle, include_list=include_list, csound=args.csound, convolve=args.convolve,
               mp3=args.mp3, max_cents_slide=args.max_cents_slide, melody_sustain=args.melody_sustain, bass_sustain=args.bass_sustain,
               bass_hold_scale=args.bass_hold_scale, bass_hold_swing=args.bass_hold_swing, bass_hold_cycles=args.bass_hold_cycles,
               cent_file_partial=args.cent_file_partial, show_volumes=args.show_volumes,
               mod_letter=args.mod_letter, album=args.album, use_werck_top_notes=args.use_werck_top_notes,
               tolerance=args.tolerance, ratio_factor=args.ratio_factor, numpy_dir_arg=args.numpy_dir,
               stability_factor=args.stability_factor, max_delta=args.max_delta,
               spread=args.spread, limit_max=args.limit_max, auto_density=args.auto_density, prime_count=args.prime_count, density_level=args.density_level, shuffle_density=args.shuffle_density,
               auto_density_weights=parsed_auto_density_weights,
               fatigue_min_chain=args.fatigue_min_chain, fatigue_density_threshold=args.fatigue_density_threshold,
               include_slice=args.include_slice,
               deep_bass_backoff=args.deep_bass_backoff, back_off_clicks=args.back_off_clicks,
               rondo_sections=rondo_sections, rondo_insertions=rondo_insertions)


