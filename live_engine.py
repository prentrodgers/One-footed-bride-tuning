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
_WOODWIND_SECTIONS = {'wood_winds'}
_BRASS_SECTIONS_SET = {'brass_section'}
_BOWED_SECTIONS = {'bowed_strings'}
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


# ── Volume presets ────────────────────────────────────────────────────────────

VOLUME_PRESETS = {
    'Winds Forward': {
        'finger_pianos': 3, 'wood_winds': 12, 'pizz_strings': 2, 'bowed_strings': 0,
        'brass_section': 8, 'perc_guitar': 3, 'bass_section': 6, 'melody_section': 5,
    },
    'Strings Dominant': {
        'finger_pianos': 2, 'wood_winds': 0, 'pizz_strings': 8, 'bowed_strings': 14,
        'brass_section': 0, 'perc_guitar': 4, 'bass_section': 7, 'melody_section': 3,
    },
    'Percussion Heavy': {
        'finger_pianos': 12, 'wood_winds': 2, 'pizz_strings': 10, 'bowed_strings': 0,
        'brass_section': 3, 'perc_guitar': 14, 'bass_section': 5, 'melody_section': 2,
    },
    'Full Orchestra': {
        'finger_pianos': 6, 'wood_winds': 7, 'pizz_strings': 5, 'bowed_strings': 6,
        'brass_section': 7, 'perc_guitar': 5, 'bass_section': 6, 'melody_section': 6,
    },
    'Melody Solo': {
        'finger_pianos': 1, 'wood_winds': 3, 'pizz_strings': 0, 'bowed_strings': 2,
        'brass_section': 0, 'perc_guitar': 0, 'bass_section': 4, 'melody_section': 14,
    },
    'Sparse Texture': {
        'finger_pianos': 4, 'wood_winds': 5, 'pizz_strings': 0, 'bowed_strings': 3,
        'brass_section': 0, 'perc_guitar': 2, 'bass_section': 3, 'melody_section': 0,
    },
    'Bass & Brass': {
        'finger_pianos': 0, 'wood_winds': 2, 'pizz_strings': 0, 'bowed_strings': 0,
        'brass_section': 13, 'perc_guitar': 3, 'bass_section': 12, 'melody_section': 4,
    },
}

VOLUME_PRESET_NAMES = list(VOLUME_PRESETS.keys()) + ['Random']


def generate_random_volume_preset() -> dict:
    """Generate a balanced random volume preset following WreckingCrew constraints."""
    vols = {s: int(rng.integers(0, 16)) for s in SECTION_NAMES}

    # Constraint: if wood+brass > 10, silence bowed; otherwise bowed gets 10-15
    if vols['wood_winds'] + vols['brass_section'] > 10:
        vols['bowed_strings'] = 0
    else:
        vols['bowed_strings'] = int(rng.integers(10, 16))

    # Constraint: arpeggio sections sum <= 25
    arp_keys = ['finger_pianos', 'pizz_strings', 'perc_guitar']
    arp_sum = sum(vols[k] for k in arp_keys)
    while arp_sum > 25:
        k = rng.choice(arp_keys)
        vols[k] = max(0, vols[k] - 1)
        arp_sum = sum(vols[k] for k in arp_keys)

    # Constraint: sustained sections sum <= 25
    sus_keys = ['wood_winds', 'bowed_strings', 'brass_section', 'melody_section']
    sus_sum = sum(vols[k] for k in sus_keys)
    while sus_sum > 25:
        k = rng.choice(sus_keys)
        vols[k] = max(0, vols[k] - 1)
        sus_sum = sum(vols[k] for k in sus_keys)

    # Constraint: total sum >= 10
    while sum(vols.values()) < 10:
        k = rng.choice(SECTION_NAMES)
        vols[k] = min(15, vols[k] + 1)

    return vols


# ── Configuration ────────────────────────────────────────────────────────────

@dataclass
class LiveEngineConfig:
    tempo: int = 80
    n_steps: int = 200
    sections_enabled: dict = field(default_factory=lambda: {s: True for s in SECTION_NAMES})
    section_volumes: dict = field(default_factory=lambda: {s: 8 for s in SECTION_NAMES})
    density_style: str = 'arpeggio'
    density_cycles: int = 5
    sparsity_min: float = 0.10
    sparsity_max: float = 0.30
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
                      config: LiveEngineConfig,
                      glide_ftables: dict | None = None) -> PreparedChord:
        """
        Generate a full orchestration for one chord.

        glide_ftables: optional dict mapping note_index -> ftable_number for
        glissando on the first emitted events (from background SA refinement).
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

        # Build glide map: voice_index (0-7) -> ftable_number
        # Each note_index maps to 2 voices (duplicated)
        # Local to this call — not instance state — to avoid races between threads
        glide_map = {}
        if glide_ftables:
            for note_idx, ftable_num in glide_ftables.items():
                voice_idx = (note_idx % 4) * 2
                glide_map[voice_idx] = ftable_num
                glide_map[voice_idx + 1] = ftable_num
        glide_used = set()

        step_events = [[] for _ in range(n_steps)]

        for section_name in SECTION_NAMES:
            if not config.sections_enabled.get(section_name, False):
                continue

            voice_names = SECTION_VOICES[section_name]
            section_vol = config.section_volumes.get(section_name, 8)
            phase = _SECTION_PHASE.get(section_name, 0.0)

            # Section volume envelope (fades in/out over time)
            vol_envelope = self._build_section_volume(n_steps, section_vol, phase)

            _gargs = (glide_map, glide_used)

            if section_name in _PERCUSSION_SECTIONS:
                self._emit_percussion(
                    step_events, cents_8, octaves_8, voice_names,
                    vol_envelope, seconds_per_tick, config, n_steps, section_name,
                    *_gargs)
            elif section_name in _WOODWIND_SECTIONS:
                self._emit_woodwinds(
                    step_events, cents_8, octaves_8, voice_names,
                    vol_envelope, seconds_per_tick, config, n_steps, section_name,
                    *_gargs)
            elif section_name in _BRASS_SECTIONS_SET:
                self._emit_brass_section(
                    step_events, cents_8, octaves_8, voice_names,
                    vol_envelope, seconds_per_tick, config, n_steps, section_name,
                    *_gargs)
            elif section_name in _BOWED_SECTIONS:
                self._emit_bowed(
                    step_events, cents_8, octaves_8, voice_names,
                    vol_envelope, seconds_per_tick, config, n_steps, section_name,
                    config.section_volumes, *_gargs)
            elif section_name in _BASS_SECTIONS:
                # Bass: use lower notes only
                bass_cents = np.array([cents_4[2], cents_4[3], cents_4[2], cents_4[3],
                                       cents_4[2], cents_4[3], cents_4[2], cents_4[3]])
                bass_octs = np.array([octaves_4[2], octaves_4[3], octaves_4[2], octaves_4[3],
                                      octaves_4[2], octaves_4[3], octaves_4[2], octaves_4[3]])
                self._emit_bass(
                    step_events, bass_cents, bass_octs, voice_names,
                    vol_envelope, seconds_per_tick, config, n_steps, section_name,
                    *_gargs)
            elif section_name in _MELODY_SECTIONS:
                # Melody: use upper notes only (lower 4 voices silent)
                mel_cents = np.array([cents_4[0], cents_4[1], cents_4[0], cents_4[1],
                                      0, 0, 0, 0])
                mel_octs = np.array([octaves_4[0], octaves_4[1], octaves_4[0], octaves_4[1],
                                     0, 0, 0, 0])
                self._emit_melody(
                    step_events, mel_cents, mel_octs, voice_names,
                    vol_envelope, seconds_per_tick, config, n_steps, section_name,
                    *_gargs)

        return PreparedChord(step_events=step_events, n_steps=n_steps,
                             chord_cents=tuned_cents)

    # ── Volume with section activity phasing ─────────────────────────────────

    def _build_section_volume(self, n_steps: int, section_vol: int,
                              phase: float) -> np.ndarray:
        """Flat volume array at the preset level."""
        return np.full(n_steps, float(section_vol))

    # ── Helper: build a scoreEvent tuple ─────────────────────────────────────

    def _make_event(self, cent_value: float, octave: int, voice_name: str,
                    hold: float, volume: float, section_name: str = '',
                    gliss: int = 0) -> tuple:
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
               f"lenv={envelope} renv={envelope} ups={upsample} ster={stereo} "
               f"gliss={gliss}")
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
            int(gliss),         # gliss ftable number (0 = no glide)
            int(upsample),
            int(envelope),      # r-envelope
            0,                  # 2nd gliss
            0,                  # 3rd gliss
            int(volume),
        )

    @staticmethod
    def _consume_glide(voice_idx: int, glide_map: dict, glide_used: set) -> int:
        """Return the glide ftable number for this voice if available (first use only)."""
        if voice_idx in glide_map and voice_idx not in glide_used:
            glide_used.add(voice_idx)
            return glide_map[voice_idx]
        return 0

    # ── Percussion: short, fast, per-voice patterns ──────────────────────────

    def _emit_percussion(self, step_events, cents_8, octaves_8, voice_names,
                          vol_envelope, seconds_per_tick, config, n_steps, section_name,
                          glide_map, glide_used):
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

        # WreckingCrew: finger_piano_part uses octave_stretch=5, octave_reduce=1
        oct_delta_arr = self._build_octave_alteration_array(
            n_steps, voices, octave_stretch=5, octave_reduce=1, stay=7)

        for v in range(voices):
            base_oct = int(octaves_8[v])
            cent = float(cents_8[v])
            if cent == 0 and base_oct == 0:
                continue

            for step in range(n_steps):
                if mask[v, step] == 0:
                    continue
                vol = vol_envelope[step]
                if vol < 0.1:
                    continue
                octave = base_oct + oct_delta_arr[v, step]
                if octave <= 0:
                    continue
                perc_vol = min(15, vol + 5)
                gliss = self._consume_glide(v, glide_map, glide_used)
                event = self._make_event(cent, octave, voice_names[v], hold, perc_vol,
                                          section_name, gliss=gliss)
                step_events[step].append(event)

    # ── Woodwinds: long overlapping sustained notes ─────────────────────────

    def _emit_woodwinds(self, step_events, cents_8, octaves_8, voice_names,
                         vol_envelope, seconds_per_tick, config, n_steps, section_name,
                         glide_map, glide_used):
        """
        Woodwinds: long overlapping sustained notes with build_long_mask_v2-style
        silence patterns, wide octave alteration, smooth envelopes.
        """
        voices = len(voice_names)
        silence_mask = self._build_long_activity_mask(
            n_steps, voices, p_silence=0.5, stay=7, variability=0.5)
        oct_deltas = self._build_octave_alteration_array(
            n_steps, voices, octave_stretch=4, octave_reduce=0, stay=9)

        for v in range(voices):
            cent = float(cents_8[v])
            base_oct = int(octaves_8[v])
            if cent == 0 and base_oct == 0:
                continue

            pos = 0
            while pos < n_steps:
                if silence_mask[v, pos] == 0 or vol_envelope[pos] < 0.5:
                    pos += 1
                    continue

                current_oct = base_oct + oct_deltas[v, pos]
                if current_oct <= 0:
                    pos += 1
                    continue

                end = pos + 1
                while end < n_steps:
                    if (silence_mask[v, end] == 0 or vol_envelope[end] < 0.5 or
                            base_oct + oct_deltas[v, end] != current_oct):
                        break
                    end += 1

                hold = (end - pos) * seconds_per_tick
                vol = max(0, float(np.mean(vol_envelope[pos:end])) - 3)
                gliss = self._consume_glide(v, glide_map, glide_used)
                event = self._make_event(cent, int(current_oct), voice_names[v],
                                          hold, vol, section_name, gliss=gliss)
                step_events[pos].append(event)
                pos = end

    # ── Brass: shorter punchier holds ─────────────────────────────────────

    def _emit_brass_section(self, step_events, cents_8, octaves_8, voice_names,
                             vol_envelope, seconds_per_tick, config, n_steps, section_name,
                             glide_map, glide_used):
        """
        Brass: shorter punchier holds, wider octave spread, higher activity,
        attack-style envelopes.
        """
        voices = len(voice_names)
        # WreckingCrew: brass uses octave_stretch=5, octave_reduce=1 (same as finger_piano)
        oct_delta_arr = self._build_octave_alteration_array(
            n_steps, voices, octave_stretch=5, octave_reduce=1, stay=7)

        for v in range(voices):
            cent = float(cents_8[v])
            base_oct = int(octaves_8[v])
            if cent == 0 and base_oct == 0:
                continue

            activity = self._random_activity_mask(n_steps, p_active=0.65,
                                                   hold_min=8, hold_max=15)

            pos = 0
            while pos < n_steps:
                if activity[pos] == 0 or vol_envelope[pos] < 0.5:
                    pos += 1
                    continue

                current_oct = base_oct + oct_delta_arr[v, pos]
                if current_oct <= 0:
                    pos += 1
                    continue

                end = pos + 1
                while end < n_steps:
                    if (activity[end] == 0 or vol_envelope[end] < 0.5 or
                            base_oct + oct_delta_arr[v, end] != current_oct):
                        break
                    end += 1

                hold = (end - pos) * seconds_per_tick
                vol = max(0, float(np.mean(vol_envelope[pos:end])) - 3)
                gliss = self._consume_glide(v, glide_map, glide_used)
                event = self._make_event(cent, int(current_oct), voice_names[v],
                                          hold, vol, section_name, gliss=gliss)
                step_events[pos].append(event)
                pos = end

    # ── Bowed strings: very long sustains, sits behind other sustained ────

    def _emit_bowed(self, step_events, cents_8, octaves_8, voice_names,
                     vol_envelope, seconds_per_tick, config, n_steps, section_name,
                     section_volumes, glide_map, glide_used):
        """
        Bowed strings: very long sustains, smooth octave walks.
        Volume reduced by -6 normally; boosted +3 when winds+brass are quiet.
        """
        voices = len(voice_names)
        winds_brass_vol = (section_volumes.get('wood_winds', 0)
                           + section_volumes.get('brass_section', 0))
        vol_offset = -3 if winds_brass_vol < 6 else -6

        silence_mask = self._build_long_activity_mask(
            n_steps, voices, p_silence=0.6, stay=9, variability=0.4)
        # WreckingCrew: bowed strings use smooth wide-range octaves (woodwinds-like)
        oct_delta_arr = self._build_octave_alteration_array(
            n_steps, voices, octave_stretch=4, octave_reduce=0, stay=9)

        for v in range(voices):
            cent = float(cents_8[v])
            base_oct = int(octaves_8[v])
            if cent == 0 and base_oct == 0:
                continue

            pos = 0
            while pos < n_steps:
                if silence_mask[v, pos] == 0 or vol_envelope[pos] < 0.5:
                    pos += 1
                    continue

                current_oct = base_oct + oct_delta_arr[v, pos]
                if current_oct <= 0:
                    pos += 1
                    continue

                end = pos + 1
                while end < n_steps:
                    if (silence_mask[v, end] == 0 or vol_envelope[end] < 0.5 or
                            base_oct + oct_delta_arr[v, end] != current_oct):
                        break
                    end += 1

                hold = (end - pos) * seconds_per_tick
                vol = max(0, float(np.mean(vol_envelope[pos:end])) + vol_offset)
                gliss = self._consume_glide(v, glide_map, glide_used)
                event = self._make_event(cent, int(current_oct), voice_names[v],
                                          hold, vol, section_name, gliss=gliss)
                step_events[pos].append(event)
                pos = end

    # ── Bass: sparse, low octaves ────────────────────────────────────────────

    def _emit_bass(self, step_events, cents_8, octaves_8, voice_names,
                    vol_envelope, seconds_per_tick, config, n_steps, section_name,
                    glide_map, glide_used):
        """Bass section: sparse density, octaves clamped to 0-4."""
        voices = len(voice_names)

        density = create_oscillating_density_mask(
            voices, n_steps,
            num_cycles=rng.choice(np.arange(5, 9)),
            min_prob=0.01, max_prob=0.09,
            min_active=0, correlated=True, smooth_kernel_size=15)
        # WreckingCrew: bass_part uses octave_stretch=4, octave_reduce=5, clipped [0, 4]
        oct_delta_arr = self._build_octave_alteration_array(
            n_steps, voices, octave_stretch=4, octave_reduce=5, stay=7)

        for v in range(voices):
            cent = float(cents_8[v])
            base_oct = int(octaves_8[v])
            if cent == 0 and base_oct == 0:
                continue

            # Find sustained segments within the sparse density
            pos = 0
            while pos < n_steps:
                if density[v, pos] == 0 or vol_envelope[pos] < 0.5:
                    pos += 1
                    continue

                current_oct = np.clip(base_oct + oct_delta_arr[v, pos], 0, 4)
                if current_oct <= 0:
                    pos += 1
                    continue

                end = pos + 1
                while end < n_steps:
                    if (density[v, end] == 0 or vol_envelope[end] < 0.5 or
                            np.clip(base_oct + oct_delta_arr[v, end], 0, 4) != current_oct):
                        break
                    end += 1

                hold = (end - pos) * seconds_per_tick
                vol = float(np.mean(vol_envelope[pos:end])) + 1  # bass +1 volume
                gliss = self._consume_glide(v, glide_map, glide_used)
                event = self._make_event(cent, int(current_oct), voice_names[v],
                                          hold, vol, section_name, gliss=gliss)
                step_events[pos].append(event)
                pos = end

    # ── Melody: upper voices, sparse, long ───────────────────────────────────

    def _emit_melody(self, step_events, cents_8, octaves_8, voice_names,
                      vol_envelope, seconds_per_tick, config, n_steps, section_name,
                      glide_map, glide_used):
        """Melody: upper voices only, long sustained notes, sparse."""
        voices = len(voice_names)
        # WreckingCrew: melody_part uses octave_stretch=5, octave_reduce=2, stay=7
        oct_delta_arr = self._build_octave_alteration_array(
            n_steps, voices, octave_stretch=5, octave_reduce=2, stay=7)

        for v in range(voices):
            cent = float(cents_8[v])
            base_oct = int(octaves_8[v])
            if cent == 0 and base_oct == 0:
                continue

            activity = self._random_activity_mask(n_steps, p_active=0.60,
                                                   hold_min=15, hold_max=30)

            pos = 0
            while pos < n_steps:
                if activity[pos] == 0 or vol_envelope[pos] < 0.5:
                    pos += 1
                    continue

                current_oct = base_oct + oct_delta_arr[v, pos]
                if current_oct <= 0:
                    pos += 1
                    continue

                end = pos + 1
                while end < n_steps:
                    if (activity[end] == 0 or vol_envelope[end] < 0.5 or
                            base_oct + oct_delta_arr[v, end] != current_oct):
                        break
                    end += 1

                hold = (end - pos) * seconds_per_tick
                vol = float(np.mean(vol_envelope[pos:end]))
                gliss = self._consume_glide(v, glide_map, glide_used)
                event = self._make_event(cent, current_oct, voice_names[v],
                                          hold, vol, section_name, gliss=gliss)
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
            p_sum = np.sum(p)
            p = p / p_sum if p_sum > 0 else np.ones(spread) / spread
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

    def _build_long_activity_mask(self, n_steps: int, voices: int,
                                   p_silence: float = 0.5, stay: int = 7,
                                   variability: float = 0.5) -> np.ndarray:
        """
        Binary activity mask with long segments, modeled after build_long_mask_v2.

        Each voice gets a phase-shifted copy of a base pattern built from
        alternating silence/activity segments with per-segment probability
        perturbation.

        Returns shape (voices, n_steps).
        """
        # Segment duration weights (longer segments more likely)
        p2 = np.array([0.1, 0.1, 0.2, 0.2, 0.2, 0.1, 0.1])
        p2 = p2[:min(stay, len(p2))]
        p2 = p2 / p2.sum()
        base_repeat = max(1, n_steps // 20)

        # Build one base row
        base = np.zeros(n_steps, dtype=int)
        pos = 0
        while pos < n_steps:
            # Perturb silence probability per segment
            p_sil = np.clip(p_silence + rng.uniform(-variability, variability), 0.1, 0.9)
            active = 0 if rng.random() < p_sil else 1
            seg_len = (1 + rng.choice(len(p2), p=p2)) * base_repeat
            end = min(pos + seg_len, n_steps)
            base[pos:end] = active
            pos = end

        # Each voice is a rolled copy
        result = np.zeros((voices, n_steps), dtype=int)
        for v in range(voices):
            result[v] = np.roll(base, v * base_repeat)
        return result

    def _build_octave_alteration_array(self, n_steps: int, voices: int,
                                        octave_stretch: int = 4,
                                        octave_reduce: int = 0,
                                        stay: int = 9) -> np.ndarray:
        """
        Octave delta array with long held segments, modeled after
        build_octave_alteration_mask.

        Each voice gets a phase-shifted copy of a base octave walk where
        octave values are drawn from a normal distribution and held for
        long segments.

        Returns shape (voices, n_steps) of integer octave deltas.
        """
        p2 = np.array([0.1, 0.1, 0.2, 0.2, 0.2, 0.1, 0.1])
        p2 = p2[:min(stay, len(p2))]
        p2 = p2 / p2.sum()
        base_repeat = max(1, n_steps // 20)

        # Octave selection probabilities (normally distributed, centered)
        mu, sd = 6, 2
        p1 = np.array([max(0.0, rng.normal(mu, sd)) for _ in range(octave_stretch)])
        p1_sum = p1.sum()
        p1 = p1 / p1_sum if p1_sum > 0 else np.ones(octave_stretch) / octave_stretch

        # Build one base row
        base = np.zeros(n_steps, dtype=int)
        pos = 0
        while pos < n_steps:
            delta = int(rng.choice(octave_stretch, p=p1)) - octave_reduce
            seg_len = (1 + rng.choice(len(p2), p=p2)) * base_repeat
            end = min(pos + seg_len, n_steps)
            base[pos:end] = delta
            pos = end

        # Each voice is a rolled copy
        result = np.zeros((voices, n_steps), dtype=int)
        for v in range(voices):
            result[v] = np.roll(base, v * base_repeat)
        return result
