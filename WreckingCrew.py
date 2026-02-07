#!/usr/bin/env python
# coding: utf-8
import sys 
import os
# Add directories to path for imports
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  
diamond_music_dir = os.path.join(os.path.dirname(parent_dir), 'Diamond_Music')  # Tutorials/Diamond_Music/
local_dir = os.path.dirname(os.path.abspath(__file__))  # One-footed-bride-tuning/

for d in [local_dir, parent_dir, diamond_music_dir]:
    if d not in sys.path:
        sys.path.insert(0, d)

user = '~'
base_dir = os.path.join(user, 'One-footed-bride-tuning') 
WAVE_DIR = os.path.join(user, 'Music', 'sflib')
from datetime import datetime
import numpy as np
import adaptive_tuning_util as atu
import diamond_music_utils as dmu 
rng = np.random.default_rng()
import os
import time
from importlib import reload
import music21 as m21
import logging
from itertools import count # , combinations, permutations
import matplotlib.pyplot as plt
import pprint as pp
import platform

from fractions import Fraction
import multiprocessing as mp
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


# keep track of all the voice features, and where they are in time
voice_time = atu.init_voice_time()
# pp.pprint(voice_time, sort_dicts=False)


# # This function and the pitch_in_scale function were copied from the muspy library source code
def _get_scale(root, mode):
      if mode == "major":
            c_scale = np.array([1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1], bool)
      elif mode == "minor":
            c_scale = np.array([1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0], bool)
      else:
            raise ValueError("`mode` must be either 'major' or 'minor'.")
      return np.roll(c_scale, root)

def pitch_in_scale(chord, root, mode):
      scale = _get_scale(root, mode.lower())
      note_count = 0
      in_scale_count = 0
      for note in chord:
            note_count += 1
            if scale[note % 12]:
                  in_scale_count += 1
      if note_count < 1:
            return math.nan
      return in_scale_count / note_count

def get_keysig(root, mode):
      #             ['C♮','C♯','D♮','D♯','E♮','F♮','F♯','G♮','G♯','A♮','A♯','B♮']
      major_keys = np.array([[0,   0,   2,   0,   4,   0,   6,   1,   0,   3,   0,   5 ],  # sharps
                  [0,   5,   0,   3,   0,   1,   6,   0,   4,   0,   2,   0 ]])  # flats
      minor_keys = np.array([[0,   4,   0,   6,   1,   0,   3,   0,   5,   0,   0,   2 ],  # sharps
                  [3,   0,   1,   6,   0,   4,   0,   2,   0,   0,   5,   0 ]])  # flats
      if mode == 'major':
            accidentals = np.array([major_keys[0][root],major_keys[1][root]])
      elif mode == 'minor':
            accidentals = np.array([minor_keys[0][root],minor_keys[1][root]])
      return np.max(accidentals), np.argmax(accidentals) # how many sharps or flats, flats set to true if it should be flats instead of sharps


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

def print_scores(version, chorale, limit_max):
      cent_file_name = os.path.join(numpy_dir, f'{version}-cents.npy')
      chorale_in_cents = np.load(cent_file_name)
      # print(f'after np.load {cent_file_name = }, {chorale_in_cents.shape = }')

      tonal_diamond = np.array(atu.build_tonal_diamond(limit_max, penalize_7_11=False)) 
      new_scores = np.zeros(chorale_in_cents.shape[1],dtype=int)
      for inx, chord in zip(count(0,1), chorale_in_cents.T):
            new_scores[inx] = atu.score_chord_cents_v2(chord, tonal_diamond)
                  # print(f'{inx}: {chord = }, {new_scores[inx] = }')


      print(f'{chorale.shape = }, {chorale_in_cents.shape = }, {top_notes.shape = }')
      print(f'{version = }, Average score: {round(np.average(new_scores),1)}, Max score: {np.max(new_scores)}, Max chord: {np.argmax(new_scores)}')
      return round(np.average(new_scores),1), np.max(new_scores)


# Create oscillating density mask that varies from sparse to dense multiple times
from random import seed
from argon2 import Parameters


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

import random
from typing import Optional

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

    Parameters
    ----------
    chords : np.ndarray
        Shape (voices, time_steps).  Only the shape matters.
    min_run, max_run : int
        Minimum/maximum run length for a single pattern segment.
    seed : int | None
        Seed for the RNG; pass a different value for each instrument to
        get different starting phases.
    verbose : bool
        When True the final mask is printed.
    sparsity_min, sparsity_max : float
        Bounds on how many 1-entries will be removed per run
        (0-→-all ones, 1-→-all zeros).
    num_cycles : int
        Full [min-→-max] oscillations over the entire rhythm.
    phase_offset : float | None
        Fraction (0-→-1) of the cycle that the first run should
        start at.  If None, a random offset is drawn for this call.

    mutation_factor : float
        Probability (0.0-1.0) that a voice's pattern will be flipped
        between runs (default 0.05). Replaces the previous hard-coded
        0.2 mutation probability.

    base_waveform : str
        One of ['sine', 'triangle', 'sawtooth_rise', 'sawtooth_fall', 'pulse']
        Selects the waveform controlling sparsity variation across time.
        'sine' replicates the original behavior; sawtooth gives a linear
        ramp per cycle (useful for quick drop/rise behavior).
    invert_waveform : bool
        If True, invert the waveform (flip low/high), useful for making
        density increase instead of decrease.
    duty : float
        Pulse duty cycle (fraction 0..1) used when `base_waveform` is
        'pulse'/'square'. Defaults to 0.5 (50% on).

    Returns
    -------
    np.ndarray
        Binary mask of shape (voices, time_steps).
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
            num_active = rng.choice([0, 1, 2, 3], p=[0.10, 0.50, 0.30, 0.10])
            if num_active > 0:
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
        logging.info(f'In arpeggio_mask_variable_runs. Started new run at {t = }, {num_cycles = }, {run_length = }, {sparsity = :.2f}, {np.sum(base_pattern) = }')
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
    try:
        import matplotlib.pyplot as plt
    except Exception as e:
        raise RuntimeError("matplotlib required for plotting (pip install matplotlib)") from e

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


def save_demo_plots(output_dir: str = "waveform_demos", time_steps: int = 400, num_cycles: int = 5, duty: float = 0.3):
    """Save demo PNGs for each supported waveform into `output_dir`.

    Returns a list of saved file paths.
    """
    waveforms = ["sine", "triangle", "sawtooth_rise", "sawtooth_fall", "pulse"]
    saved = []
    for wf in waveforms:
        filename = f"{wf}.png" if wf != 'pulse' else f"{wf}_duty{int(duty*100)}.png"
        path = os.path.join(output_dir, filename)
        plot_sparsity_waveform(time_steps=time_steps, num_cycles=num_cycles, base_waveform=wf, duty=duty if wf=='pulse' else 0.5, save_path=path)
        saved.append(path)
    return saved


if __name__ == "__main__":
    try:
        saved = save_demo_plots(output_dir="waveform_demos", time_steps=400, num_cycles=5, duty=30/100)
        print("Saved waveform demo PNGs:")
        for p in saved:
            print(" -", p)
    except Exception as e:
        print("Plotting demo failed:", e)

# define the functions for the bass instruments, much like the finger_piano_part, except it only includes tenor and bass voices
# chorale is already had repeats applied to it when it arrives here.
def bass_part(chorale, glides, repeats, voice_names, voice_time, tpq, volume_function, probs = None, fp_volume = 1):
    # set the default value for probs if it is not passed as a keyword argument.
    if probs is None:
        probs = [[0.99, 0.01], [0.95627622, 0.04372378]]
    logging.info(f'in bass_part at the start of the function. {chorale.shape = }, {glides.shape = }')
    print(f'probs of getting a one: {sum(probs) = }, values: {[round(i[1],4) for i in probs]}') 
    voices = voice_names.shape[0] # if you want it to last twice as long, make twice as many voices: voice_names.shape[0] * 2, or increase the value of repeats
    bass_chorale_in_cents_octaves = chorale.copy()
    bass_chorale_in_cents_octaves[:2, :, :] = chorale[2:, :, :] # copy the tenor and bass parts down to the alto and soprano parts
    chorale = bass_chorale_in_cents_octaves.copy()
    chorale = np.repeat(chorale, voices // 4, axis = 0) # double the number of voices
    glides = np.repeat(glides, voices // 4, axis = 0) # double the number of voices
    logging.debug(f'after doubling voices: {chorale.shape = }, {glides.shape = }') # (8, 3216, 2)
    # revised volume_array use a spline function 5/21/23
    logging.debug(f'{volume_function = }') # array([7, 7, 1, 3, 1, 1, 1, 4, 6]) # approximately 9 values
    sustain = 15 # Influences how quickly the volume changes. Higher values = slower changes.
    # this next line needs to have an integer value for repeats. That will require everyone calling bass_part (and all the other xxx_part functions) to pass the average of the repeats as an integer. That would be repeats_average. I pass repeats_average and this function calls it repeats. 
    # volume_function in the xx_part functions is just the slice of the global volume_function that applies to that part
    vol_arr_size = volume_function.shape[0] * rng.choice([1,2,3,4]) # make the volume array size a multiple of the number of sections in the part
    logging.info(f'In bass_part. About to smooth the volume function using build_density_function with {volume_function.shape = }, {vol_arr_size = }')
    logging.info(f'{volume_function = }')
    volume_array = dmu.build_density_function(volume_function, vol_arr_size) 
    logging.info(f'{volume_array.shape = }')
    logging.info(f'{volume_array = }')
    volume_array = np.clip(np.repeat(volume_array, repeats * sustain, axis=0), 0, 14)
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
    vel -= 2 # lower the volume on the finger piano parts to avoid clipping
    vel_p = np.array([[.5, .5], [.5, .5], [.5, .5], [.5, .5]])
    guev_array = np.stack((gls, gls_p, ups, ups_p, env, env_p, vel, vel_p), axis = 0)
    rng.shuffle(guev_array, axis=1)
    logging.debug(f'In bass_part. feature array after stack. {guev_array.shape = }') # guev_array.shape = (8, 3, 2)
    notes_features_6 = atu.add_features_glides(chorale, glides, guev_array) # start with the chorale, which is (notes, octaves), and add the gls, ups, env, & vel arrays
    logging.debug(f'after loading notes_features_6.{notes_features_6.shape = }')
    logging.debug([np.unique(feature, return_counts = True) for feature in notes_features_6])
    octave_array = notes_features_6[1] # all the octaves for all the voices, notes
    # create an array to mask some notes. This will be used to set octave = 0, which makes them silent
    # create a value for the number of cycles in a range of values 
    num_cycles = rng.choice(np.arange(5, 9)) # have a chance at a different number of cycles
    logging.info(f'number of cycles for density function: {num_cycles = }') #
    # replace create_oscillating_density_mask with arpeggio_mask_variable_runs

    density_function = create_oscillating_density_mask(voices, chorale.shape[1], num_cycles=num_cycles, min_prob=0.01, max_prob=0.09, min_active=0, correlated=True, smooth_kernel_size=15)

    logging.info(f'after first creation: {density_function.shape = }') # after first creation: density_function.shape = 
    logging.info(f'after creation: {np.sum(density_function) = }, {np.sum(density_function == 0) = }, {np.sum(density_function == 1) = }, Percentage of ones: {np.sum(density_function == 1) / np.sum(density_function == 0) * 100:.1f}%')

    logging.info(f'{octave_array.shape = }, {np.sum(octave_array) = } {density_function.shape = }, {np.sum(density_function) = }') # octave_array.shape = (8, 6480), density_function.shape = (8, 6500)
    # changed on 5/21/23 - make sure it doesn't mess up the octaves as zeros
    octave_stretch = 4 # if 3, you might get -1, 0, 1 or just 2 numbers
    stay = 7 # maximum time you might stay with the same octave * repeats
    octave_reduce = 5
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
    octave_array = np.clip(octave_array, 0, 4) # clip the octaves to be between 0 and 4
    logging.info(f'after clipping negatives to 0: {np.unique(octave_array, return_counts=True)}')
    logging.info(f'{notes_features_6.shape = }') #                             0      1        2      3         4         5
    notes_features_6[1] = octave_array #  add_features returns this :np.stack((notes, octaves, gliss, upsample, envelope, velocity), axis = 0)
    volume_array += fp_volume
    notes_features_15 = dmu.piano_roll_to_notes_features(notes_features_6, volume_array, voice_names, tpq, voice_time)
    notes_features_15 = atu.clip_note_features(notes_features_15, voice_time) # make sure the octaves are in range and the volume adjusted per the voice_time dictionary
    # notes_features_15 contains one row for every note: note, oct, glis, ups, env, vel, vol, voice, 
    logging.debug(f'{notes_features_15.shape = }')
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

    Parameters
    ----------
    chorale_pc : np.ndarray
        Shape (8, N). Pitch classes for 8 voices (SATBSATB).
    swap_ones_for_zeros : float
        Probability of inverting either columns 0–3 or 4–7 in a block.
    extend_set : float
        Probability of extending an 8-step block into a 12-step block.
    rng : np.random.Generator or None
        Optional RNG for reproducibility.

    Returns
    -------
    mask : np.ndarray
        Shape (8, N). Binary mask.
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
def finger_piano_part(chorale, glides, repeats, voice_names, voice_time, tpq, volume_function, probs = None, fp_volume = 0):
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
    # create an array to mask some notes so that octave = 0, which makes them silent
    # create an array to mask some notes. This will be used to set octave = 0, which makes them silent
    num_cycles = rng.choice(np.arange(6, 18)) # make it so all the sections that use this function have a chance at a different number of cycles
    logging.info(f'number of cycles for density function: {num_cycles = }') #
    # options to pass to create_oscillating_density_mask: noise_level=0.015, min_active=2, correlated=False, per_voice_bias=None, smooth_kernel_size=None
    # 
    # This function creates a mask the returned matrix has shape (voices, n_chords * repeats_per_chord)
    #
    # create_arpeggio_mask_from_chords(chords, repeats_per_chord=1, pattern='updown'):
    #
    # voices is number of voices. Chorale.shape[1] is the number of chords. This doesn't work with notes, it just builds a 0/1 mask array to apply to the octaves. 
    # replace create_oscillating_density_mask with arpeggio_mask_variable_runs to get a different effect.
    print(f'{chorale.shape = }, {chorale[:,:,0].shape = }')
    
    # these assignments set up cycles that overlap and aren't in sync
    min_run = rng.choice(np.arange(60,100))
#     min_run=120
    max_run = rng.choice(np.arange(100,120))
#     max_run=120
    swap_ones_for_zeros = rng.uniform(0.1, 0.7)
    extend_set = rng.uniform(0.1, 0.7)
    base_waveform = rng.choice(['sine', 'triangle', 'sawtooth_rise', 'sawtooth_fall', 'pulse'])
    density_function = arpeggio_mask_variable_runs(chords=chorale[:,:,0], min_run=min_run, max_run=max_run, seed=None, verbose=False, sparsity_min=0.05, sparsity_max=0.50, num_cycles=rng.choice(np.arange(3, 7)), mutation_factor=0.01, base_waveform=base_waveform)
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
    volume_function, mask=True, prob_silence=None, octave_reduce=0, woodwinds_volume=5):

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
    vel = np.array([[64, 66], [64, 69], [63, 70], [64, 69]]) # how loud the note will be at different points in the piece across all voices.
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
        logging.info(f'before build_long_mask_v2. {repeats = }, {voices = }, {chorale_in_cents_slides.shape = }, {prob_silence = } ')
        octave_silence_mask = atu.build_long_mask_v2(repeats, voices, chorale_in_cents_slides, p1 = prob_silence) # build long chains of zeros, followed by long chains of ones so the notes sound for a long time, then go silent. 
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
    # np.save('wood_part_notes_features.npy', notes_features_15)
    return notes_features_15
# end of woodwinds_part

# define the functions for the melody part
def melody_part(chorale_in_cents_slides, glides, repeats, voice_names, voice_time, tpq,\
    volume_function, mask = True, prob_silence = None, octave_reduce = 0,\
    woodwinds_volume = 4, sustain=15):

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
    vel = np.array([[64, 66], [64, 69], [63, 70], [64, 69]]) # how loud the note will be at different points in the piece across all voices.
    vel -= 3 # lower the volume on the woodwinds parts to avoid clipping
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
        logging.info(f'before build_long_mask_v2. {repeats = }, {voices = }, {chorale_in_cents_slides.shape = }, {prob_silence = } ')
        octave_silence_mask = atu.build_long_mask_v2(repeats, voices, chorale_in_cents_slides, p1 = prob_silence) # build long chains of zeros, followed by long chains of ones so the notes sound for a long time, then go silent. 
        logging.info(f'before masking octave_array. {np.average(octave_array) = }')  
        logging.info(f'octave_array (values, counts): {np.unique(octave_array, return_counts=True)}')
        logging.info(f'octave_silence_mask (values, counts): {np.unique(octave_silence_mask, return_counts=True)}, {np.average(octave_silence_mask) = }')
        octave_array = octave_array * octave_silence_mask     
        logging.info(f'after masking octave_array. {np.average(octave_array) = }')  
        logging.info(f'octave_array (values, counts): {np.unique(octave_array,  return_counts=True)}')
        # # octave_silence_mask = atu.build_long_mask(repeats, voices, chorale_in_cents_slides) 
        # octave_silence_mask = atu.build_long_mask(repeats, voices, chorale_in_cents_slides, p1 = prob_silence) # chance of silence is around 99%
        # octave_array = octave_array * octave_silence_mask     
        # logging.debug(f'octave_array after masking (values, counts): {np.unique(octave_array, return_counts=True)}') 
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
    max_silence = rng.uniform(low = 0.98, high = 1.0) # 7/30/25 raised from 0.97 to 0.98 It used to start at 0.93
    if rng.integers(5) == 0: # 20% of the time reduce the silence by 0.05 - was 0.1
        max_silence -= .05 
        logging.debug(f'decreased woodwinds_part odds. reduced max_silence by .1. {round(max_silence,4) = }')
    elif rng.integers(10) == 0: # 10% of the time reduce it by 0.2
        max_silence -= .2 
        logging.debug(f'decreased woodwinds_part odds. reduced max_silence by .2. {round(max_silence,4) = }')

    if mask: prob_silence = [max_silence, 1 - max_silence] 
    else: 
        max_silence = 0
        prob_silence = [1, 0] # if mask is False, then there is no masking of notes
    assert np.sum(prob_silence) == 1.0, logging.debug(f'prob_silence needs to sum to 1. {np.sum(prob_silence) = }, {prob_silence = }') 
    assert (np.max(prob_silence) <= 1 and np.min(prob_silence) >= 0), logging.debug(f'{prob_silence = } needs to make sure probabilities do not include numbers greater than 1 or less than 0. Failed. {max_silence = }')
    return probs, step, prob_silence, max_silence       
# end set_probabilities


def generate_random_volumes_v2(time_slots = 8, max_value=25, sections = 8, max_section_sum = 70, max_voice_value = 10, min_time_slot_sum = 10):
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
                  preferred = [bows, bras, wood, fing, pizz, guit, bass, meld]
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

      logging.info(f'Sum before final clip: {np.sum(volume_function) = }')
      final_answer = np.clip(volume_function, 0, max_value)
      logging.info(f'Sum after final clip: {np.sum(final_answer) = }')
      return final_answer


# this function takes the original chorale array and expands it dramatically. It is only called once per chorale.
def expand_chorale(repeats, chorale_in_cents_slides, glides, stored_gliss, voice_time,\
    include_sections, mod, mask=True, tpq=0, octave_reduce=0, woodwinds_volume=8,\
    include_instruments=[], print_only=10, limit=0, melody_sustain=15, just_fp=False):
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
    quantization = 3 # this is only used to influence the tempo, it's not actually quantizing anything. 8 went too far (fast)
    # choose the tempo based on how many times the notes are repeated
    repeats_average = int(round(np.average(repeats)))
    logging.info(f'{repeats.shape = }, {repeats_average = }, {quantization = }')
    if repeats_average * quantization > 65:
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
        start_time_slot = 5 # the minimum number of time_slots
        time_slots = np.max([start_time_slot, repeats_average]) * 2
        max_value = 11 # how loud can each instrument go
        logging.info(f'{time_slots = }, {start_time_slot = }, {repeats.shape = }, {repeats_average = }')
        volume_function = generate_random_volumes_v2(time_slots=time_slots)
        logging.info(f'{volume_function.shape = }')
        logging.info(f'sums of each time_slot: ')
        total_sums = 0
        for i in np.arange(time_slots):
            logging.info(f'{i}: {np.sum(volume_function.T[i])}')
            total_sums += np.sum(volume_function.T[i])
        logging.info(f'Average sums: {total_sums // time_slots}')
    else: volume_function = np.full((8, 14), 2, dtype = int)
    if just_fp:
        volume_function = np.full((8, 14), 8, dtype = int)
    # 5/30/25 Expanded from shape 8,9 to shape 8,12, then to 8,14
    # 9/20/23, reduced the upper numbers by 1. 8 became 7, and so forth. Prevent clipping.
    # 3/31/25, changed to 8 instrument sections from original 6. You have to use a multiple of 4 since there are 4 voices in a chorale: S,A,T,B. 

    logging.info(f'before shuffle: {[np.sum(vol) for vol in volume_function.T] = }')
    end_value = volume_function.T[-1].reshape(-1,1)
    volume_function = volume_function[:,np.random.permutation(volume_function.shape[1] - 1)]
    volume_function = np.concatenate((volume_function, end_value), axis = 1)
    logging.info(f'after shuffle: {[np.sum(vol) for vol in volume_function.T] = }')

    notes_features_15 = np.empty((0,15), dtype = int) # start with an empty array you can concatenate onto.
    for sec_num, section in zip(count(0,1), include_sections): 
        if include_sections[section][0]: # if the dictionary value for this instrument section is set to True
            print(f'{sec_num}: {section}, includes instruments: {include_sections[section][1]}')
            if section in ['pizz_strings', 'perc_guitar', 'finger_pianos']:
                print(f'playing {section}')
                notes_features_15 = np.concatenate((notes_features_15, finger_piano_part(chorale_in_cents_slides, glides, repeats_average, include_sections[section][1], voice_time, tpq, volume_function[sec_num], probs = probs)), axis = 0)
                np.save(f'perc_part_{section}.npy', notes_features_15)
            elif section in ['melody_section']:
                print(f'playing {section}')
                notes_features_15 = np.concatenate((notes_features_15, melody_part(chorale_in_cents_slides, glides, repeats_average, include_sections[section][1], voice_time, tpq, volume_function[sec_num], mask=mask, prob_silence=prob_silence, octave_reduce=octave_reduce, woodwinds_volume=woodwinds_volume, sustain=melody_sustain)), axis = 0)
                np.save(f'melody_part_{section}.npy', notes_features_15)
            elif section in ['wood_winds', 'brass_section', 'bowed_strings']:
                print(f'playing {section}')
                notes_features_15 = np.concatenate((notes_features_15, woodwinds_part(chorale_in_cents_slides, glides, repeats_average, include_sections[section][1], voice_time, tpq, volume_function[sec_num], mask=mask, prob_silence=prob_silence, octave_reduce=0, woodwinds_volume=woodwinds_volume)), axis = 0)
                np.save(f'winds_part_{section}.npy', notes_features_15)
            elif section in ['bass_section']:
                print(f'playing {section}')
                notes_features_15 = np.concatenate((notes_features_15, bass_part(chorale_in_cents_slides, glides, repeats_average, include_sections[section][1], voice_time, tpq, volume_function[sec_num], probs = probs)), axis = 0)
                np.save(f'bass_part_{section}.npy', notes_features_15)
            print(f'{section}: {[(inst, voice_time[inst]["start"]) for inst in include_sections[section][1]]}')
            logging.debug(f'{notes_features_15.shape = }')
            print(f'after concatenating {section = }, {notes_features_15.shape = }')

    # now that you have the voices, assign note start times from durations of notes in a voice
    notes_features_final, voice_time = dmu.fix_start_times(notes_features_15, voice_time)
    print(f'{notes_features_final.shape = }') # notes_features_final.shape = (16495, 15)
    # send the arrays to the file new_output.csd which csound will convert to a wave file to make sounds
    logging.debug(f'about to update_gliss_table with {stored_gliss.shape = }')
    tables = dmu.update_gliss_table(stored_gliss, stored_gliss.shape[0])
    logging.debug(f'back from update_gliss_table with {stored_gliss = }, {tables = }')
    print(f"Final list of notes with all features: {notes_features_final.shape = }, and {include_instruments = }. {CSD_FILE = }")
    result = dmu.send_to_csound_file(notes_features_final, voice_time, CSD_FILE, tempos = 't0 ' + str(tempo),\
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
    mod = f'{mod}_a{avg_probs:.2f}_w{round(1 - max_silence, 2):.2f}_d{dur_short}_t{tempo:03}'
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
    pattern = rng.choice(pattern, size=pattern.shape[0], replace=True) # much more randomsdfsdfsdg the piece will be. 
    logging.info(f'After shuffle: {pattern = }')
    # Create repeat sequence by cycling through pattern to length num_chords
    repeat_values = np.tile(pattern, int(np.ceil(num_chords / len(pattern))))[:num_chords].astype(int)

    # Sanity checks
    assert repeat_values.shape[0] == num_chords, "repeat_values must have one entry per chord"

    # Repeat the chorale along the chord axis
    repeated_chords = np.repeat(chorale_array, repeat_values, axis=axis)

    # Return repeated array and the repeat pattern used
    return repeated_chords, repeat_values


def chorale_to_wave_v4(version, album, include_sections, limit_max=47,\
      short_repeats=True, include_list=np.array([]), csound=True,\
      convolve=True, mod_letter='a', max_cents_slide=48, print_only=0,\
      limit=0, use_opt_file=True, just_fp=False, \
      cent_file_partial='-cents.npy', show_volumes=False, woodwinds_volume=15,\
      melody_sustain=15, use_werck_top_notes=False, mp3=True):

    print(f'In chorale_to_wave_v4. {version = }, {limit_max = }, {short_repeats = }')
    if short_repeats: # if you just want a straight woodwind/brass chorale, set short_repeats = True
        mask = False # no complex algorithm to create different repeating arpeggio patterns
        woodwinds_volume = 13
    else:
        mask = True

    # assign the list of valid intervals from a tonality diamond.
    tonal_diamond = np.array(atu.build_tonal_diamond(limit_max, penalize_7_11=False)) 

    # Load the chorale and some metadata - Since we already have the chorale in cents in a numpy file.

    cent_file_name = os.path.join(numpy_dir, f'{version}{cent_file_partial}') # fills out to the actual cent file name
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

    if len(include_list) > 0:
        cent_value_chorale = cent_value_chorale[:,include_list]
        chorale = chorale[:,include_list]
    if len(include_list) < chorale.shape[1]: 
        print(f'{include_list = }')

    # print(f'About to score the chorale as loaded. {chorale_in_cents.shape = }')
    new_scores = np.zeros(cent_value_chorale.shape[1],dtype=int)
    for inx, chord in zip(count(0,1), cent_value_chorale.T):
        new_scores[inx] = atu.score_chord_cents_v2(chord, tonal_diamond)
        # print(f'{inx}: {chord = }, {new_scores[inx] = }')

    # tell me about the chorale you are about to use as the basis for the piece of music.
    logging.info(f'{version = }, {chorale.shape = }, {cent_value_chorale.shape = }, {top_notes.shape = }, {short_repeats = }')

    # create a string of the key variables for use in the name of the MP3 file.    
    mod = f'{version[-2:]}{mod_letter}' # need to add some more information once you have it.

    # initialize some values based on other values
    # if you are just playing a chorale straight as Bach wrote it, only repeats=2, otherwise many more repeats
    octave = chorale // 12
    print(f'{cent_value_chorale.shape = }, {octave.shape = }')
    chorale_in_cents_octaves = np.stack((cent_value_chorale, octave), axis=2)  # shape (time_steps, 2)
    if short_repeats: 
        repeats = np.array([2])
        # Don't repeat here - woodwinds_part will expand 4 voices to 8 voices internally
        choral_octaves_repeated = chorale_in_cents_octaves  # keep original 4 SATB voices
        # choral_octaves_repeated = np.repeat(chorale_in_cents_octaves, repeats, axis=0) # this was the culprit.
    else: 
        # here is where we need to set the repeats. We want the repeats to be different numbers, not an integer. 
        primes = np.array([1, 3, 5, 11, 17, 31, 47, 71])
        choral_octaves_repeated, repeats = create_repeat_array_pattern(chorale_in_cents_octaves, pattern=primes)
        logging.info(f'created repeats pattern using primes. {primes = }, {repeats[:primes.shape[0]] = }')

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

    # apply the repeats to increase the density and length of the piece, select which instruments will play, and other tasks
    duration, volume_function, mod = expand_chorale(repeats, chorale_in_cents_slides,\
        glides, stored_gliss, voice_time, include_sections, mod, mask=mask,\
        octave_reduce=1, woodwinds_volume=woodwinds_volume, print_only=print_only,\
        limit=limit, melody_sustain=melody_sustain, just_fp=just_fp)

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
def mainline(chorale_override=None):
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

      reload(atu)
      dmu.start_logger(JUPYTER_LOG, log_level = 'info')
      print(f'{platform.uname() = }')
      short_repeats = False # If True, get a basic chorale. Play it straight. If false, then use the arpeggio patterns to create a more complex piece of music.
      woodwinds_volume = 16 # only used if short_repeats = True
      #include_list = np.arange(172, 204, 1) # which chords to include in the piece
      include_list = []
      # set the instrument sections you want to include to True in the following dictionary
      just_sustained = False # for debugging purposes if you only want the sustained instruments to play
      just_fp = False # for debugging purposes if you only want the finger pianos to play
      just_prent_samples = True # this is set so that I have a version that runs without the McGill samples
      if short_repeats:
            include_sections = {
                  # The above code appears to be defining a dictionary in Python where each key
                  # represents a section of a musical ensemble and the corresponding value is a list
                  # containing a boolean indicating whether the section plays instruments or not, and
                  # a NumPy array listing the instruments in that section.
                  # section --      play or not --    instruments in the section
                  # np.repeat creates: Track 0,1=Soprano, 2,3=Alto, 4,5=Tenor, 6,7=Bass
                  # Use high-range instruments for S/A (tracks 0-3), low-range for T/B (tracks 4-7)
                  'finger_pianos': [False, np.array(['fing1', 'fing2', 'fing3', 'fing4', 'fing5', 'fing6', 'bfin1', 'bfin2'])],
                  'wood_winds':    [True,  np.array(['flut1', 'flut2', 'clar1', 'clar2', 'frnh1', 'frnh2', 'basn1', 'basn2'])],
                  'pizz_strings':  [False, np.array(['vlip1', 'vlip2', 'vlip3', 'vlip4', 'vlap1', 'vlap2', 'celp1', 'celp2'])],
                  'bowed_strings': [False, np.array(['vliv1', 'vliv2', 'vliv3', 'vliv4', 'vlav1', 'vlav2', 'celv1', 'celv2'])],
                  'brass_section': [True,  np.array(['trmp1', 'trmp2', 'trmp3', 'trmp4', 'trmb1', 'trmb2', 'tuba1', 'tuba2'])], 
                  'perc_guitar':   [False, np.array(['xylp1', 'mari1', 'vibp1', 'harp1', 'ebss1', 'stri1', 'bgui1', 'long1'])],
                  'bass_section':  [False, np.array(['bfin3', 'bfin4', 'celp3', 'celp4', 'bgui3', 'bgui2', 'long2', 'long3'])],
                  'melody_section':[False, np.array(['flut2', 'flut3', 'clar2', 'mari2', 'oboe3', 'basn4', 'trmp5', 'frnh3'])]}
      elif just_sustained:
            include_sections = {
                  # section --      play or nocelp4t --    instruments in the section
                  'finger_pianos': [False, np.array(['fing1', 'fing2', 'fing3', 'fing4', 'fing5', 'fing6', 'bfin1', 'bfin2'])],
                  'wood_winds':    [True, np.array(['flut1', 'clar1', 'oboe1', 'oboe2', 'frnh1', 'frnh2', 'basn1', 'basn2'])],
                  'pizz_strings':  [False, np.array(['vlip1', 'vlip2', 'vlip3', 'vlip4', 'vlap1', 'vlap2', 'celp1', 'celp2'])],
                  'bowed_strings': [True, np.array(['vliv1', 'vliv2', 'vliv3', 'vliv4', 'vlav1', 'vlav2', 'celv1', 'celv2'])],
                  'brass_section': [True, np.array(['trmp1', 'trmp2', 'trmp3', 'trmp4', 'trmb1', 'trmb2', 'tuba1', 'tuba2'])], 
                  'perc_guitar':   [False, np.array(['xylp1', 'mari1', 'vibp1', 'harp1', 'ebss1', 'stri1', 'bgui1', 'long1'])],
                  'bass_section':  [False, np.array(['bfin3', 'bfin4', 'celp3', 'celp4', 'bgui3', 'bgui2', 'long2', 'long3'])],
                  'melody_section':[True, np.array(['flut2', 'flut3', 'clar2', 'vibp1', 'oboe3', 'basn4', 'trmp5', 'frnh3'])]}
      elif just_fp:
            include_sections = {
                  # section --      play or not --    instruments in the section
                  'finger_pianos': [False, np.array(['fing1', 'fing2', 'fing3', 'fing4', 'fing5', 'fing6', 'fing7', 'fing8'])],
                  'wood_winds':    [False, np.array([])],
                  'pizz_strings':  [False, np.array(['ebss1', 'ebss2', 'ebss3', 'ebss4', 'ebss5', 'ebss6', 'ebss7', 'ebss8'])],
                  'bowed_strings': [False, np.array([])],
                  'brass_section': [False, np.array([])], 
                  'perc_guitar':   [True, np.array(['bgui1', 'bgui2', 'bgui3', 'bgui4', 'bgui5', 'bgui6', 'bgui7', 'bgui8'])],
                  'bass_section':  [True, np.array(['bfin1', 'bfin2', 'bfin3', 'bfin4', 'bfin5', 'bfin6', 'bfin7', 'bfin8'])], 
                  'melody_section':[False, np.array([])]}
      elif just_prent_samples:
            include_sections = {
                  # section --      play or not --    instruments in the section
                  'finger_pianos': [True, np.array(['fing1', 'fing2', 'fing3', 'fing4', 'fing5', 'fing6', 'bfin1', 'bfin2'])],
                  'wood_winds':    [True, np.array(['flut1', 'clar1', 'oboe1', 'oboe2', 'frnh1', 'frnh2', 'basn1', 'basn2'])],
                  'pizz_strings':  [True, np.array(['vlip1', 'vlip2', 'vlip3', 'vlip4', 'vlap1', 'vlap2', 'celp1', 'celp2'])],
                  'bowed_strings': [True, np.array(['vliv1', 'vliv2', 'vliv3', 'vliv4', 'vlav1', 'vlav2', 'celv1', 'celv2'])],
                  'brass_section': [True, np.array(['trmp1', 'trmp2', 'trmp3', 'trmp4', 'trmb1', 'trmb2', 'tuba1', 'tuba2'])], 
                  'perc_guitar':   [True, np.array(['mari1', 'mari2', 'mari3', 'mari4', 'mari5', 'mari6', 'mari7', 'mari8'])],
                  'bass_section':  [True, np.array(['bfin5', 'bfin6', 'bfin7', 'bfin8', 'celp5', 'celp6', 'celp7', 'bgui1'])],
                  'melody_section':[True, np.array(['flut2', 'flut3', 'clar2', 'vibp1', 'oboe3', 'basn4', 'trmp5', 'frnh3'])]}
      else:
            include_sections = {
                  # section --      play or not --    instruments in the section
                  'finger_pianos': [True, np.array(['fing1', 'fing2', 'fing3', 'fing4', 'fing5', 'fing6', 'bfin1', 'bfin2'])],
                  'wood_winds':    [True, np.array(['flut1', 'clar1', 'oboe1', 'oboe2', 'frnh1', 'frnh2', 'basn1', 'basn2'])],
                  'pizz_strings':  [True, np.array(['vlip1', 'vlip2', 'vlip3', 'vlip4', 'vlap1', 'vlap2', 'celp1', 'celp2'])],
                  'bowed_strings': [True, np.array(['vliv1', 'vliv2', 'vliv3', 'vliv4', 'vlav1', 'vlav2', 'celv1', 'celv2'])],
                  'brass_section': [True, np.array(['trmp1', 'trmp2', 'trmp3', 'trmp4', 'trmb1', 'trmb2', 'tuba1', 'tuba2'])], 
                  'perc_guitar':   [True, np.array(['mari1', 'mari2', 'mari3', 'mari4', 'mari5', 'mari6', 'mari7', 'mari8'])],
                  'bass_section':  [True, np.array(['bfin5', 'bfin6', 'bfin7', 'bfin8', 'celp5', 'celp6', 'celp7', 'bgui1'])],
                  'melody_section':[True, np.array(['flut2', 'flut3', 'clar2', 'vibp1', 'oboe3', 'basn4', 'trmp5', 'frnh3'])]}
      csound = True # run the generated .csd file through csound to create a .wav file
      convolve = csound 
      mp3 = True # csound convolution impulse response using Teatro Alcorcon in Madrid made by Angelo Farina
      limit = 0 # how many seconds to produce. 0 means no limit.
      penalize_7_11 = False # if true then double the value of all the intervals in the atu.build_tonal_diamond function which calls _find_limit to do the deed
      max_cents_slide = 35 # was 34 until 8-7-25 # keep this under 50 or you get some very annoying glides
      melody_sustain = 3 # was 4 changed on 9/8/25 to 3. was 5 was 7. 6/26/25 if this is too low, then you hear too many restarts on notes
      cent_file_partial = '-trans-sa-opt-best.npy' # Archive/opt/bwv264-trans-sa-opt-best.npy
      show_volumes = True
      print_only = 10 # how many lines of csound code should be printed to the log file.
      mod_letter = 'a' # append a letter to the output file name to help distinguish between different runs through.
      album = 3 # append a number to distinguish sets
      total_averages = 0
      max_overall_score = 0
      use_werck_top_notes = False
      limit_max = 19 # I don't think I need this. 

      chorale_list = ['bwv253','bwv254','bwv255','bwv256','bwv257','bwv258','bwv259','bwv260','bwv261','bwv262','bwv263','bwv264']
      # allow override from command-line: single name, comma-separated names, or 'all'
      if chorale_override:
            if isinstance(chorale_override, str):
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
      for inx, version in enumerate(chorale_list):
            print(f'Running {version}')
            chorale = chorale_to_wave_v4(version, album, include_sections, limit_max=limit_max,\
                  print_only=print_only, short_repeats=short_repeats, include_list=include_list,\
                  csound=csound, convolve=convolve, mod_letter=mod_letter, just_fp=just_fp, \
                  max_cents_slide=max_cents_slide, show_volumes=show_volumes, \
                  woodwinds_volume=woodwinds_volume, melody_sustain=melody_sustain, \
                  cent_file_partial=cent_file_partial, use_werck_top_notes=use_werck_top_notes,mp3=mp3)

      # Generate a playlist of all the pieces in this album. This never worked correctly in the pod.
      print(f' {UPLOADS_DIR = }')
      now = datetime.now()
      if csound and convolve:
            for n in [album]: # if album is a list
                  print(f'album: {n}{mod_letter}')
                  # create a playlist of this set of pieces in the uploads directory sorted by duration, shortest first.
                  target_dir = os.path.join(UPLOADS_DIR, f'{mod_letter}{n}-{now.strftime("%m-%d-%y")}' )
                  # try to create it and if it already exists, continue
                  if not os.path.exists(target_dir):
                        os.makedirs(target_dir)
                  else: print(f'{target_dir} exists, no need to create it')


if __name__ == "__main__":
      import argparse
      parser = argparse.ArgumentParser(description='Generate chorale audio and plots')
      parser.add_argument("--chorale_name", "--chorale", dest="chorale_name", help="chorale name or comma-separated list (default: ['bwv253','bwv254','bwv255','bwv256','bwv257','bwv258','bwv259','bwv260','bwv261','bwv262','bwv263','bwv264'])'", default=None)
      args = parser.parse_args()
      mainline(chorale_override=args.chorale_name)


