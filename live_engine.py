#!/usr/bin/env python3
"""
Live WreckingCrew Engine

Generates multi-section orchestrations of MIDI chords in real time.
Each held chord produces a PreparedChord containing n_steps of note events
across up to 8 instrument sections. A playback ticker iterates through
the steps at tempo, sending scoreEvent calls to Csound.

Unlike the offline WreckingCrew pipeline, this engine directly generates
per-step events from density/octave masks rather than going through
piano_roll_to_notes_features (which collapses identical adjacent notes,
defeating the purpose for a static held chord).
"""

import logging
from dataclasses import dataclass, field

import numpy as np

import adaptive_tuning_util as atu
from WreckingCrew import (
    arpeggio_mask_variable_runs,
    create_oscillating_density_mask,
)

logger = logging.getLogger(__name__)
rng = np.random.default_rng()

# ── Section definitions ─────────────────────────────────────────────────────

# Default voice assignments per section
DEFAULT_SECTION_VOICES = {
    'finger_pianos':  ['fing1', 'fing2', 'fing3', 'fing4', 'fing5', 'fing6', 'bfin1', 'bfin2'],
    'wood_winds':     ['flut1', 'clar1', 'oboe1', 'oboe2', 'frnh1', 'frnh2', 'basn1', 'basn2'],
    'pizz_strings':   ['vlip1', 'vlip2', 'vlip3', 'vlip4', 'vlap1', 'vlap2', 'celp1', 'celp2'],
    'bowed_strings':  ['vliv1', 'vliv2', 'vliv3', 'vliv4', 'vlav1', 'vlav2', 'celv1', 'celv2'],
    'brass_section':  ['trmp1', 'trmp2', 'trmp3', 'trmp4', 'trmb1', 'trmb2', 'tuba1', 'tuba2'],
    'perc_guitar':    ['xylp1', 'mari1', 'vibp1', 'harp1', 'ebss1', 'stri1', 'bgui1', 'long1'],
    'bass_section':   ['bfin3', 'bfin4', 'celp3', 'celp4', 'bgui3', 'bgui2', 'long2', 'long3'],
    'melody_section': ['flut2', 'flut3', 'clar2', 'mari2', 'oboe3', 'basn4', 'trmp5', 'frnh3'],
}

# Mutable copy used at runtime — updated when user changes section instruments
SECTION_VOICES = {k: list(v) for k, v in DEFAULT_SECTION_VOICES.items()}

# ── Voice type registry ────────────────────────────────────────────────────
# Maps a human-readable instrument type to the list of voice_time keys.
# Built from voice_time at module load; each type needs >=8 keys to fill a section.

def _build_voice_type_registry():
    """Group voice_time keys by csound_voice number, label by full_name."""
    vt = atu.init_voice_time()
    by_voice_num = {}
    for key, info in vt.items():
        num = info['csound_voice']
        if num not in by_voice_num:
            # Derive type label from full_name: strip trailing digits and whitespace
            base = info['full_name'].rstrip('0123456789').strip()
            by_voice_num[num] = {'label': base, 'keys': []}
        by_voice_num[num]['keys'].append(key)
    # Return {label: [key1, key2, ...]} — all types should have >=8 keys now
    registry = {}
    for num, data in sorted(by_voice_num.items()):
        label = data['label']
        keys = data['keys']
        registry[label] = keys
    return registry

VOICE_TYPE_REGISTRY = _build_voice_type_registry()
VOICE_TYPE_NAMES = sorted(VOICE_TYPE_REGISTRY.keys())

_PERCUSSION_SECTIONS = {'finger_pianos', 'pizz_strings', 'perc_guitar'}
_SUSTAINED_SECTIONS = {'wood_winds', 'brass_section', 'bowed_strings'}
_BASS_SECTIONS = {'bass_section'}
_MELODY_SECTIONS = {'melody_section'}

SECTION_NAMES = list(DEFAULT_SECTION_VOICES.keys())


def set_section_instrument(section_name: str, voice_type_label: str) -> bool:
    """Replace all 8 voices in a section with voices of the given type.
    Returns True on success, False if type not found or section unknown."""
    if section_name not in SECTION_VOICES:
        return False
    if voice_type_label not in VOICE_TYPE_REGISTRY:
        return False
    keys = VOICE_TYPE_REGISTRY[voice_type_label]
    # Fill 8 slots, cycling if the type has more than 8
    SECTION_VOICES[section_name] = [keys[i % len(keys)] for i in range(8)]
    return True


def reset_section_voices(section_name: str):
    """Reset a section to its default voice assignment."""
    if section_name in DEFAULT_SECTION_VOICES:
        SECTION_VOICES[section_name] = list(DEFAULT_SECTION_VOICES[section_name])

# Phase offsets so sections take turns dominating (0.0–1.0)
_SECTION_PHASE = {
    'finger_pianos': 0.0, 'wood_winds': 0.25, 'pizz_strings': 0.50,
    'bowed_strings': 0.75, 'brass_section': 0.40, 'perc_guitar': 0.60,
    'bass_section': 0.15, 'melody_section': 0.85,
}


# ── Configuration ────────────────────────────────────────────────────────────

@dataclass
class LiveEngineConfig:
    tempo: int = 80
    n_steps: int = 200
    sections_enabled: dict = field(default_factory=lambda: {s: True for s in SECTION_NAMES})
    section_volumes: dict = field(default_factory=lambda: {s: 8 for s in SECTION_NAMES})
    density_style: str = 'arpeggio'
    density_cycles: int = 5
    sparsity_min: float = 0.05
    sparsity_max: float = 0.50
    waveform: str = 'sine'


@dataclass
class PreparedChord:
    """Pre-computed note events ready for step-by-step playback."""
    step_events: list       # list[list[tuple]]  — one list per step
    n_steps: int
    chord_cents: np.ndarray


# ── Live Engine ──────────────────────────────────────────────────────────────

class LiveEngine:
    def __init__(self):
        self.voice_time = atu.init_voice_time()

    def prepare_chord(self, tuned_cents: np.ndarray, midi_notes: np.ndarray,
                      config: LiveEngineConfig) -> PreparedChord:
        """
        Generate a full orchestration for one chord.

        Directly builds per-step events from density/octave masks rather than
        going through piano_roll_to_notes_features (which collapses identical
        adjacent notes and defeats the purpose for a static held chord).
        """
        n_notes = len(tuned_cents)
        n_steps = config.n_steps
        # 4 ticks per beat (matches offline tpq=0.25)
        seconds_per_tick = 60.0 / config.tempo / 4.0

        # Build base chord: cycle held notes across 4 voice slots
        cents_4 = np.array([tuned_cents[i % n_notes] for i in range(4)])
        octaves_4 = np.array([midi_notes[i % n_notes] // 12 for i in range(4)])

        # Expand to 8 voices (each of the 4 chord notes duplicated)
        cents_8 = np.repeat(cents_4, 2)
        octaves_8 = np.repeat(octaves_4, 2)

        step_events = [[] for _ in range(n_steps)]

        for section_name in SECTION_NAMES:
            if not config.sections_enabled.get(section_name, False):
                continue

            voice_names = SECTION_VOICES[section_name]
            section_vol = config.section_volumes.get(section_name, 8)
            phase = _SECTION_PHASE.get(section_name, 0.0)

            # Section volume envelope (fades in/out over time)
            vol_envelope = self._build_section_volume(n_steps, section_vol, phase)

            if section_name in _PERCUSSION_SECTIONS:
                self._emit_percussion(
                    step_events, cents_8, octaves_8, voice_names,
                    vol_envelope, seconds_per_tick, config, n_steps, section_name)
            elif section_name in _SUSTAINED_SECTIONS:
                self._emit_sustained(
                    step_events, cents_8, octaves_8, voice_names,
                    vol_envelope, seconds_per_tick, config, n_steps, section_name)
            elif section_name in _BASS_SECTIONS:
                # Bass: use lower notes only
                bass_cents = np.array([cents_4[2], cents_4[3], cents_4[2], cents_4[3],
                                       cents_4[2], cents_4[3], cents_4[2], cents_4[3]])
                bass_octs = np.array([octaves_4[2], octaves_4[3], octaves_4[2], octaves_4[3],
                                      octaves_4[2], octaves_4[3], octaves_4[2], octaves_4[3]])
                self._emit_bass(
                    step_events, bass_cents, bass_octs, voice_names,
                    vol_envelope, seconds_per_tick, config, n_steps, section_name)
            elif section_name in _MELODY_SECTIONS:
                # Melody: use upper notes only (lower 4 voices silent)
                mel_cents = np.array([cents_4[0], cents_4[1], cents_4[0], cents_4[1],
                                      0, 0, 0, 0])
                mel_octs = np.array([octaves_4[0], octaves_4[1], octaves_4[0], octaves_4[1],
                                     0, 0, 0, 0])
                self._emit_melody(
                    step_events, mel_cents, mel_octs, voice_names,
                    vol_envelope, seconds_per_tick, config, n_steps, section_name)

        return PreparedChord(step_events=step_events, n_steps=n_steps,
                             chord_cents=tuned_cents)

    # ── Volume with section activity phasing ─────────────────────────────────

    def _build_section_volume(self, n_steps: int, section_vol: int,
                              phase: float) -> np.ndarray:
        """
        Volume curve with extended silence gaps. Each section has a different
        phase so they take turns dominating.
        """
        # Slow sine envelope (1.5–2.5 cycles)
        n_cycles = rng.uniform(1.5, 2.5)
        t = np.linspace(0, 2 * np.pi * n_cycles, n_steps)
        envelope = (np.sin(t + phase * 2 * np.pi) + 1.0) / 2.0
        # Clamp values below 0.25 to zero → real silence gaps
        envelope = np.where(envelope < 0.25, 0.0, envelope)
        return np.clip(envelope * section_vol, 0, 15)

    # ── Helper: build a scoreEvent tuple ─────────────────────────────────────

    def _make_event(self, cent_value: float, octave: int, voice_name: str,
                    hold: float, volume: float, section_name: str = '') -> tuple:
        """Build a 15-element tuple for csound scoreEvent."""
        vt = self.voice_time[voice_name]
        csound_voice = vt["csound_voice"]
        # Clamp octave to voice range
        raw_octave = octave
        octave = max(vt["min_oct"], min(vt["max_oct"], octave))
        # High cent values at max octave get pushed down
        if octave == vt["max_oct"] and cent_value > 350:
            octave -= 1
        volume = max(0, volume + vt["volume_factor"])
        velocity = rng.integers(63, 73)
        stereo = rng.integers(1, 17)
        envelope = rng.choice([1, 2, 6, 8, 9, 16])
        upsample = rng.choice([-2, -1, 0, 1, 2])
        msg = (f"scoreEvent sect={section_name} voi={voice_name} cent={cent_value:.0f} "
               f"oct={raw_octave}->{octave} hold={hold:.2f} vol={volume:.0f} "
               f"vo_num={csound_voice} oct_ran=[{vt['min_oct']},{vt['max_oct']}] "
               f"lenv={envelope} renv={envelope} ups={upsample} ster={stereo}")
        if volume == 0:
            logger.debug(msg)
        else:
            logger.info(msg)
        return (
            1,                  # instrument
            0,                  # start (immediate)
            float(hold),        # hold duration
            int(velocity),
            float(cent_value),
            int(octave),
            int(csound_voice),
            int(stereo),
            int(envelope),
            0,                  # gliss
            int(upsample),
            int(envelope),      # r-envelope
            0,                  # 2nd gliss
            0,                  # 3rd gliss
            int(volume),
        )

    # ── Percussion: short, fast, per-voice patterns ──────────────────────────

    def _emit_percussion(self, step_events, cents_8, octaves_8, voice_names,
                          vol_envelope, seconds_per_tick, config, n_steps, section_name):
        """
        Fast percussion with per-voice density patterns.
        8 voices per section, each with a distinct rhythmic pattern.
        5 hits per step (offsets at 0, 1/5, 2/5, 3/5, 4/5 of a beat).
        Short runs, high sparsity → dense, rapid-fire percussion.
        """
        voices = len(voice_names)
        # Let percussion ring: 2-6 seconds regardless of tick rate
        hold = rng.uniform(2.0, 6.0)

        # Percussion always dense: floor at 0.5, cap at 0.95
        perc_sparsity_min = max(0.5, config.sparsity_min * 5)
        perc_sparsity_max = max(0.7, min(0.95, config.sparsity_max * 5))
        dummy_chords = np.tile(cents_8[:voices, np.newaxis], (1, n_steps))

        if config.density_style == 'arpeggio':
            mask = arpeggio_mask_variable_runs(
                chords=dummy_chords,
                min_run=rng.integers(4, 8),
                max_run=rng.integers(8, 15),
                sparsity_min=perc_sparsity_min,
                sparsity_max=perc_sparsity_max,
                num_cycles=max(1, config.density_cycles),
                mutation_factor=0.08,
                base_waveform=config.waveform,
            )
        else:
            mask = create_oscillating_density_mask(
                voices, n_steps,
                num_cycles=max(1, config.density_cycles),
                min_prob=perc_sparsity_min,
                max_prob=perc_sparsity_max,
            )

        for v in range(voices):
            base_oct = int(octaves_8[v])
            oct_deltas = self._random_octave_walk(n_steps, spread=5, reduce=1,
                                                   hold_min=3, hold_max=8)
            cent = float(cents_8[v])
            if cent == 0 and base_oct == 0:
                continue

            for step in range(n_steps):
                if mask[v, step] == 0:
                    continue
                vol = vol_envelope[step]
                if vol < 0.1:
                    continue
                octave = base_oct + oct_deltas[step]
                if octave <= 0:
                    continue
                perc_vol = min(15, vol + 5)
                event = self._make_event(cent, octave, voice_names[v], hold, perc_vol, section_name)
                step_events[step].append(event)

    # ── Sustained: long holds, independent octave drift ──────────────────────

    def _emit_sustained(self, step_events, cents_8, octaves_8, voice_names,
                         vol_envelope, seconds_per_tick, config, n_steps, section_name):
        """
        Sustained instruments: each voice holds for 10-20 steps then shifts
        octave independently. Voices phase in/out with long segments.
        """
        voices = len(voice_names)

        for v in range(voices):
            cent = float(cents_8[v])
            base_oct = int(octaves_8[v])
            if cent == 0 and base_oct == 0:
                continue

            # Independent octave walk: hold each octave for 10-20 steps
            oct_deltas = self._random_octave_walk(n_steps, spread=4, reduce=0,
                                                   hold_min=10, hold_max=20)

            # Independent activity mask: ~75% active, long segments
            activity = self._random_activity_mask(n_steps, p_active=0.75,
                                                   hold_min=12, hold_max=25)

            # Find note boundaries: wherever octave or activity changes
            pos = 0
            while pos < n_steps:
                if activity[pos] == 0 or vol_envelope[pos] < 0.5:
                    pos += 1
                    continue

                # Start of an active note — find how long it lasts
                current_oct = base_oct + oct_deltas[pos]
                if current_oct <= 0:
                    pos += 1
                    continue

                end = pos + 1
                while end < n_steps:
                    if (activity[end] == 0 or vol_envelope[end] < 0.5 or
                            base_oct + oct_deltas[end] != current_oct):
                        break
                    end += 1

                # Emit one long note spanning pos..end
                hold = (end - pos) * seconds_per_tick
                # Reduce sustained volume (-5) to sit behind percussion
                vol = max(0, float(np.mean(vol_envelope[pos:end])) - 5)
                event = self._make_event(cent, current_oct, voice_names[v],
                                          hold, vol, section_name)
                step_events[pos].append(event)
                pos = end

    # ── Bass: sparse, low octaves ────────────────────────────────────────────

    def _emit_bass(self, step_events, cents_8, octaves_8, voice_names,
                    vol_envelope, seconds_per_tick, config, n_steps, section_name):
        """Bass section: sparse density, octaves clamped to 0-4."""
        voices = len(voice_names)

        density = create_oscillating_density_mask(
            voices, n_steps,
            num_cycles=rng.choice(np.arange(5, 9)),
            min_prob=0.01, max_prob=0.09,
            min_active=0, correlated=True, smooth_kernel_size=15)

        for v in range(voices):
            cent = float(cents_8[v])
            base_oct = int(octaves_8[v])
            if cent == 0 and base_oct == 0:
                continue

            # Push octave down for bass
            oct_deltas = self._random_octave_walk(n_steps, spread=4, reduce=5,
                                                   hold_min=8, hold_max=15)

            # Find sustained segments within the sparse density
            pos = 0
            while pos < n_steps:
                if density[v, pos] == 0 or vol_envelope[pos] < 0.5:
                    pos += 1
                    continue

                current_oct = np.clip(base_oct + oct_deltas[pos], 0, 4)
                if current_oct <= 0:
                    pos += 1
                    continue

                end = pos + 1
                while end < n_steps:
                    if (density[v, end] == 0 or vol_envelope[end] < 0.5 or
                            np.clip(base_oct + oct_deltas[end], 0, 4) != current_oct):
                        break
                    end += 1

                hold = (end - pos) * seconds_per_tick
                vol = float(np.mean(vol_envelope[pos:end])) + 1  # bass +1 volume
                event = self._make_event(cent, int(current_oct), voice_names[v],
                                          hold, vol, section_name)
                step_events[pos].append(event)
                pos = end

    # ── Melody: upper voices, sparse, long ───────────────────────────────────

    def _emit_melody(self, step_events, cents_8, octaves_8, voice_names,
                      vol_envelope, seconds_per_tick, config, n_steps, section_name):
        """Melody: upper voices only, long sustained notes, sparse."""
        voices = len(voice_names)

        for v in range(voices):
            cent = float(cents_8[v])
            base_oct = int(octaves_8[v])
            if cent == 0 and base_oct == 0:
                continue

            # Higher range, longer holds
            oct_deltas = self._random_octave_walk(n_steps, spread=5, reduce=2,
                                                   hold_min=15, hold_max=30)
            activity = self._random_activity_mask(n_steps, p_active=0.60,
                                                   hold_min=15, hold_max=30)

            pos = 0
            while pos < n_steps:
                if activity[pos] == 0 or vol_envelope[pos] < 0.5:
                    pos += 1
                    continue

                current_oct = base_oct + oct_deltas[pos]
                if current_oct <= 0:
                    pos += 1
                    continue

                end = pos + 1
                while end < n_steps:
                    if (activity[end] == 0 or vol_envelope[end] < 0.5 or
                            base_oct + oct_deltas[end] != current_oct):
                        break
                    end += 1

                hold = (end - pos) * seconds_per_tick
                vol = float(np.mean(vol_envelope[pos:end]))
                event = self._make_event(cent, current_oct, voice_names[v],
                                          hold, vol, section_name)
                step_events[pos].append(event)
                pos = end

    # ── Mask builders ────────────────────────────────────────────────────────

    def _random_octave_walk(self, n_steps: int, spread: int = 4,
                             reduce: int = 0, hold_min: int = 10,
                             hold_max: int = 20) -> np.ndarray:
        """
        Generate an octave delta array where the value changes every
        hold_min..hold_max steps independently.

        Returns shape (n_steps,) of integer octave deltas.
        """
        result = np.zeros(n_steps, dtype=int)
        pos = 0
        mu, sd = 6, 2
        while pos < n_steps:
            # Weight toward center of spread range
            p = rng.normal(mu, sd, spread)
            p = np.where(p >= 0, p, 0.0)
            p = p / np.sum(p)
            delta = int(rng.choice(spread, p=p)) - reduce
            hold = rng.integers(hold_min, hold_max + 1)
            end = min(pos + hold, n_steps)
            result[pos:end] = delta
            pos = end
        return result

    def _random_activity_mask(self, n_steps: int, p_active: float = 0.75,
                               hold_min: int = 12,
                               hold_max: int = 25) -> np.ndarray:
        """
        Binary mask where each segment is independently active or inactive.
        """
        mask = np.zeros(n_steps, dtype=int)
        pos = 0
        while pos < n_steps:
            active = 1 if rng.random() < p_active else 0
            hold = rng.integers(hold_min, hold_max + 1)
            end = min(pos + hold, n_steps)
            mask[pos:end] = active
            pos = end
        return mask
