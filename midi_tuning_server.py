#!/usr/bin/env python
"""
Live MIDI-to-Csound Tuning Web Application with WreckingCrew Engine

Reads MIDI from a keyboard, optionally tunes chords using build_straw_man_chord,
orchestrates them across 8 instrument sections (density masks, octave stretching,
volume evolution), and sends score events to a running Csound instance via libcsound.
A web UI controls all parameters in real time.

Usage:
    conda activate csound
    python midi_tuning_server.py
    # Open http://localhost:8000 in a browser
"""

import os, sys, time, logging, threading, json, asyncio
from collections import deque
from contextlib import asynccontextmanager

import numpy as np
import mido
import libcsound
import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse

# Add this directory to path for local imports
local_dir = os.path.dirname(os.path.abspath(__file__))
if local_dir not in sys.path:
    sys.path.insert(0, local_dir)

import adaptive_tuning_util as atu
import diamond_music_utils as dmu
from itertools import combinations
from grid_search_tuning import build_straw_man_chord
from optimize_chords_sa_v2 import build_straw_man_chord_simulated_annealing, roll_and_tune
from live_engine import (LiveEngine, LiveEngineConfig, SECTION_NAMES,
                         VOICE_TYPE_NAMES, VOICE_TYPE_REGISTRY,
                         SECTION_VOICES, DEFAULT_SECTION_VOICES,
                         VOLUME_PRESETS, VOLUME_PRESET_NAMES,
                         generate_random_volume_preset,
                         set_section_instrument, reset_section_voices)

# Set up logging independently — don't rely on diamond_music_utils.start_logger.
# grid_search_tuning.py calls logging.disable(CRITICAL) at import time — undo that.
logging.disable(logging.NOTSET)
# Close and remove all existing handlers (start_logger leaves an unclosed FileHandler)
for _h in logging.root.handlers[:]:
    _h.close()
    logging.root.removeHandler(_h)
_log_path = os.path.join(local_dir, 'slide_tuning.log')
_fmt = logging.Formatter('%(asctime)s %(levelname)s %(message)s', datefmt='%d %H:%M:%S')
_fh = logging.FileHandler(_log_path, mode='w')
_fh.setFormatter(_fmt)
logging.root.addHandler(_fh)
logging.root.setLevel(logging.INFO)
logger = logging.getLogger(__name__)
logger.info("midi_tuning_server starting — log file: %s", _log_path)

# ── Tuning engine setup ──────────────────────────────────────────────────────

VALID_LIMIT_MAX = [17, 19, 23, 29, 31, 37, 41, 43, 47, 53]
keys = atu.set_accidentals(True)  # flats


def _build_tuning_objects(limit_max):
    """Rebuild tonal_diamond, chord_scorer, low_number_ratios for a given limit_max."""
    td = atu.build_tonal_diamond(limit_max)[:-1]
    cs = atu.ChordScorer(td)
    lnr = atu.LowNumberRatioIntervals(td)
    return td, cs, lnr


def build_chord_info(active_midi, tuned_cents):
    """Build chord analysis dict for the UI: cents, note names, pitch classes, intervals."""
    n = len(active_midi)
    note_names = [keys[int(m) % 12] for m in active_midi]
    pitch_classes = [int(m) % 12 for m in active_midi]
    cents_list = [int(round(c)) for c in tuned_cents]
    if state.deep_tune_enabled:
        scorer, tol = state.dt_chord_scorer, state.dt_tolerance
    else:
        scorer, tol = state.chord_scorer, state.tolerance
    score = float(scorer.score_chord(np.array(tuned_cents, dtype=int), tol))

    intervals = []
    for i1, i2 in combinations(range(n), 2):
        delta = abs(tuned_cents[i1] - tuned_cents[i2])
        delta = int(round(delta)) % 1200
        ratio = dmu.cents_to_ratio(delta, limit_denominator=50)
        intervals.append({
            'from': note_names[i1],
            'to': note_names[i2],
            'cents': delta,
            'ratio': ratio,
        })

    return {
        'cents': cents_list,
        'note_names': note_names,
        'pitch_classes': pitch_classes,
        'score': score,
        'intervals': intervals,
    }


# ── Shared application state ────────────────────────────────────────────────

class AppState:
    def __init__(self):
        self.tuning_enabled = True
        self.running = True
        self.one_hot_note = np.zeros(128)
        self.cent_value_chord_prev = np.zeros(2)
        self.prev_chord_size = 0
        self.lock = threading.Lock()
        self.shutdown = False
        self.midi_port_name = None
        self.cs = None
        self.csound_thread = None
        self.connected_websockets: list[WebSocket] = []
        self.event_loop = None  # set at startup for cross-thread scheduling

        # Tuning parameters (mutable)
        self.limit_max = 19
        self.tolerance = 4
        self.rolls = 1
        self.deep_tune_enabled = True
        self.chord_num = 0  # counter for SA logging
        td, cs, lnr = _build_tuning_objects(self.limit_max)
        self.tonal_diamond = td
        self.chord_scorer = cs
        self.low_number_ratios = lnr
        # Deep tune parameters (mutable, winning defaults from train.py)
        self.dt_ratio_factor = 1.375
        self.dt_rolls = 5
        self.dt_tolerance = 1
        self.dt_max_iterations = 40
        self.dt_cooling_rate = 0.85
        self.dt_spread = 5
        self.dt_limit_max = 17
        # Deep tune tuning objects (built from dt_limit_max)
        dt_td, dt_cs, dt_lnr = _build_tuning_objects(self.dt_limit_max)
        self.dt_tonal_diamond = dt_td
        self.dt_chord_scorer = dt_cs
        self.dt_low_number_ratios = dt_lnr

        # Live engine state
        self.engine = LiveEngine()
        self.engine_config = LiveEngineConfig()
        self.prepared_chord = None      # atomic reference, swapped by processor
        self.current_step = 0           # ticker position
        self.chord_changed = threading.Event()
        self.engine_enabled = True      # master toggle for the orchestration engine
        self.prev_active_snapshot = np.array([], dtype=int)  # track chord changes

        # Background SA refinement state
        self.sa_thread: threading.Thread | None = None
        self.sa_cancel = threading.Event()
        self.current_tuned_cents: np.ndarray | None = None
        self.glide_ftable_cache: dict = {}   # ratio (rounded) -> ftable_number
        self.next_glide_ftable: int = 5000
        self.missing_ftables_log: list = []  # ftable definition strings


state = AppState()


# ── MIDI port detection ─────────────────────────────────────────────────────

def find_midi_port():
    """Find a MIDI input port, preferring LPK25."""
    names = mido.get_input_names()
    if not names:
        return None
    logger.info(f"Available MIDI ports: {names}")
    for name in names:
        if 'LPK25' in name:
            return name
    for name in names:
        if 'Through' not in name:
            return name
    return names[0]


# ── Tuning logic ────────────────────────────────────────────────────────────

def tune_chord(active_midi_notes):
    """
    Tune a chord of 2+ notes using build_straw_man_chord or simulated annealing.
    Returns a dict mapping MIDI note -> tuned cent value.
    """
    n = len(active_midi_notes)
    tet_cents = np.array([(note % 12) * 100 for note in active_midi_notes])

    with state.lock:
        if n != state.prev_chord_size:
            prev = np.zeros(n)
            state.prev_chord_size = n
        else:
            prev = state.cent_value_chord_prev.copy()
        tolerance = state.tolerance
        rolls = state.rolls
        chord_scorer = state.chord_scorer
        low_number_ratios = state.low_number_ratios
        tonal_diamond = state.tonal_diamond
        deep_tune = state.deep_tune_enabled
        state.chord_num += 1
        chord_num = state.chord_num

    if deep_tune and n <= 6:
        with state.lock:
            dt_cs = state.dt_chord_scorer
            dt_lnr = state.dt_low_number_ratios
            dt_td = state.dt_tonal_diamond
            dt_rf = state.dt_ratio_factor
            dt_rolls = state.dt_rolls
            dt_tol = state.dt_tolerance
            dt_mi = state.dt_max_iterations
            dt_cr = state.dt_cooling_rate
            dt_sp = state.dt_spread
        tuned, _score = roll_and_tune(
            tet_cents, prev, chord_num,
            tolerance=dt_tol, chord_scorer=dt_cs,
            low_number_ratios=dt_lnr,
            tonal_diamond=dt_td,
            initial_temperature=1.0, cooling_rate=dt_cr,
            max_iterations=dt_mi, max_no_improve=12,
            spread=dt_sp, elbow_percent=0.4, r_value=0.3,
            ratio_factor=dt_rf, rolls=dt_rolls, min_repeats=2,
        )
    else:
        tuned = build_straw_man_chord(
            tet_cents, prev, tolerance, rolls,
            chord_scorer, low_number_ratios, tonal_diamond
        )

    with state.lock:
        state.cent_value_chord_prev = tuned.copy()

    return dict(zip(active_midi_notes, tuned))


# ── Cross-thread WebSocket broadcast ────────────────────────────────────────

def broadcast_status(data):
    """Schedule a status message to all connected websockets via the event loop."""
    if state.event_loop is None:
        return
    msg = json.dumps({'type': 'status', **data})
    with state.lock:
        ws_list = state.connected_websockets[:]
    for ws_ref in ws_list:
        try:
            state.event_loop.call_soon_threadsafe(ws_ref._pending_sends.append, msg)
        except Exception:
            pass


# ── MIDI listener thread ────────────────────────────────────────────────────

def midi_loop():
    """Poll MIDI input, update one_hot_note, signal chord changes."""
    port_name = find_midi_port()
    if port_name is None:
        logger.error("No MIDI input ports found. MIDI listener not started.")
        state.midi_port_name = "none found"
        return

    state.midi_port_name = port_name
    logger.info(f"Opening MIDI port: {port_name}")
    port = mido.open_input(port_name)

    tuned_cache = {}

    while not state.shutdown:
        for msg in port.iter_pending():
            if msg.type == 'note_on' and msg.velocity > 0:
                with state.lock:
                    state.one_hot_note[msg.note] = msg.velocity
                    running = state.running
                    tuning_enabled = state.tuning_enabled

                if not running:
                    continue

                # Get currently active notes
                with state.lock:
                    active = np.where(state.one_hot_note > 0)[0].copy()

                # Tune the chord if enabled and 2+ notes held
                if tuning_enabled and len(active) >= 2:
                    tuned_cache = tune_chord(active)

                # Always play the immediate note via direct scoreEvent
                if tuning_enabled and msg.note in tuned_cache:
                    cent_value = int(tuned_cache[msg.note])
                else:
                    cent_value = (msg.note % 12) * 100

                octave_value = msg.note // 12
                velocity = int(np.clip(msg.velocity, 60, 70))

                state.csound_thread.scoreEvent(False, 'i', (
                    1, 0, 10, velocity, cent_value, octave_value,
                    1, 8, 2, 0, 0, 2, 0, 0, 10
                ))
                logger.info(f"note_on {msg.note} -> cent={cent_value} oct={octave_value} "
                            f"tuned={tuning_enabled}")

                # Signal chord change for the engine
                if not np.array_equal(active, state.prev_active_snapshot):
                    state.prev_active_snapshot = active.copy()
                    state.chord_changed.set()

                broadcast_status({'notes_held': int(np.sum(state.one_hot_note > 0))})

            elif msg.type == 'note_off' or (msg.type == 'note_on' and msg.velocity == 0):
                with state.lock:
                    state.one_hot_note[msg.note] = 0
                    notes_held = int(np.sum(state.one_hot_note > 0))
                    active = np.where(state.one_hot_note > 0)[0].copy()

                # Signal chord change
                if not np.array_equal(active, state.prev_active_snapshot):
                    state.prev_active_snapshot = active.copy()
                    state.chord_changed.set()

                broadcast_status({'notes_held': notes_held})

        time.sleep(0.001)  # 1ms polling

    port.close()
    logger.info("MIDI port closed.")


# ── Chord processor thread ────────────────────────────────────────────────

def chord_processor_loop():
    """Watch for chord changes, fast-tune immediately, then optionally refine via SA."""
    while not state.shutdown:
        triggered = state.chord_changed.wait(timeout=0.5)
        if not triggered:
            continue
        state.chord_changed.clear()

        # Cancel any running background SA and reset chart
        state.sa_cancel.set()
        if state.sa_thread and state.sa_thread.is_alive():
            state.sa_thread.join(timeout=1.0)
        state.sa_cancel.clear()
        broadcast_status({'sa_progress': None})  # clear the chart

        with state.lock:
            engine_enabled = state.engine_enabled
            running = state.running
            tuning_enabled = state.tuning_enabled
            active = np.where(state.one_hot_note > 0)[0].copy()
            config = _snapshot_engine_config()

        if not engine_enabled or not running:
            continue

        if len(active) == 0:
            state.prepared_chord = None
            state.current_step = 0
            continue

        # Phase 1: Fast tuning with build_straw_man_chord (immediate)
        if tuning_enabled and len(active) >= 2:
            tet_cents = np.array([(n % 12) * 100 for n in active])
            with state.lock:
                n = len(active)
                if n != state.prev_chord_size:
                    prev = np.zeros(n)
                    state.prev_chord_size = n
                else:
                    prev = state.cent_value_chord_prev.copy()
                tolerance = state.tolerance
                rolls = state.rolls
                scorer = state.chord_scorer
                lnr = state.low_number_ratios
                td = state.tonal_diamond
            fast_cents = build_straw_man_chord(
                tet_cents, prev, tolerance, rolls, scorer, lnr, td)
            with state.lock:
                state.cent_value_chord_prev = fast_cents.copy()
        else:
            fast_cents = np.array([(n % 12) * 100 for n in active], dtype=float)

        # Generate orchestration and start playing immediately
        try:
            prepared = state.engine.prepare_chord(fast_cents, active, config)
            with state.lock:
                state.current_tuned_cents = fast_cents.copy()
                state.prepared_chord = prepared
                state.current_step = 0
            logger.info(f"Chord processed (fast): {len(active)} notes, "
                        f"{sum(len(s) for s in prepared.step_events)} total events")
            chord_info = build_chord_info(active, fast_cents)
            broadcast_status({'chord_info': chord_info})
        except Exception as e:
            logger.error(f"Chord processing error: {e}", exc_info=True)
            continue

        # Phase 2: Background SA refinement (if deep_tune enabled)
        with state.lock:
            deep_tune = state.deep_tune_enabled
        if deep_tune and tuning_enabled and 2 <= len(active) <= 6:
            state.sa_thread = threading.Thread(
                target=_background_sa_refine,
                args=(active.copy(), fast_cents.copy(), config),
                daemon=True)
            state.sa_thread.start()
            broadcast_status({'sa_running': True})

    logger.info("Chord processor stopped.")


def _snapshot_engine_config() -> LiveEngineConfig:
    """Take a snapshot of the current engine config under lock (caller holds lock)."""
    return LiveEngineConfig(
        tempo=state.engine_config.tempo,
        n_steps=state.engine_config.n_steps,
        sections_enabled=dict(state.engine_config.sections_enabled),
        section_volumes=dict(state.engine_config.section_volumes),
        density_style=state.engine_config.density_style,
        density_cycles=state.engine_config.density_cycles,
        sparsity_min=state.engine_config.sparsity_min,
        sparsity_max=state.engine_config.sparsity_max,
        waveform=state.engine_config.waveform,
    )


# ── Background SA refinement ──────────────────────────────────────────────

def _background_sa_refine(active_midi: np.ndarray, current_cents: np.ndarray,
                           config: LiveEngineConfig):
    """Run SA tuning in background; if better result found, apply via glide."""
    tet_cents = np.array([(n % 12) * 100 for n in active_midi])

    with state.lock:
        dt_cs = state.dt_chord_scorer
        dt_lnr = state.dt_low_number_ratios
        dt_td = state.dt_tonal_diamond
        dt_rf = state.dt_ratio_factor
        dt_rolls = state.dt_rolls
        dt_tol = state.dt_tolerance
        dt_mi = state.dt_max_iterations
        dt_cr = state.dt_cooling_rate
        dt_sp = state.dt_spread
        state.chord_num += 1
        chord_num = state.chord_num

    if state.sa_cancel.is_set():
        return

    # Broadcast initial score so chart shows starting point
    initial_score = float(dt_cs.score_chord(np.array(current_cents, dtype=int), dt_tol))
    broadcast_status({'sa_progress': {'i': 0, 'cs': round(initial_score, 1),
                                      'bs': round(initial_score, 1), 't': 1.0}})

    def _sa_progress(iteration, candidate_score, best_score, temperature):
        if state.sa_cancel.is_set():
            return
        broadcast_status({'sa_progress': {
            'i': iteration,
            'cs': round(candidate_score, 1),
            'bs': round(best_score, 1),
            't': round(temperature, 4),
        }})

    sa_cents, sa_score = roll_and_tune(
        tet_cents, current_cents, chord_num,
        tolerance=dt_tol, chord_scorer=dt_cs,
        low_number_ratios=dt_lnr, tonal_diamond=dt_td,
        initial_temperature=1.0, cooling_rate=dt_cr,
        max_iterations=dt_mi, max_no_improve=12,
        spread=dt_sp, elbow_percent=0.4, r_value=0.3,
        ratio_factor=dt_rf, rolls=dt_rolls, min_repeats=2,
        progress_callback=_sa_progress,
    )

    if state.sa_cancel.is_set():
        return

    # Compare scores (lower is better)
    current_score = float(dt_cs.score_chord(np.array(current_cents, dtype=int), dt_tol))
    if sa_score >= current_score:
        logger.info(f"SA found no improvement: {sa_score:.1f} >= {current_score:.1f}")
        broadcast_status({'sa_running': False, 'sa_improved': False})
        return

    logger.info(f"SA improved chord: {current_score:.1f} -> {sa_score:.1f}")
    _apply_glide_transition(active_midi, current_cents, sa_cents, config)
    broadcast_status({'sa_running': False, 'sa_improved': True})


def _apply_glide_transition(active_midi: np.ndarray, old_cents: np.ndarray,
                             new_cents: np.ndarray, config: LiveEngineConfig):
    """Apply glide from old_cents to new_cents tuning, or restart without glide."""
    # Guard: discard if chord has changed since SA started
    with state.lock:
        current_active = np.where(state.one_hot_note > 0)[0]
    if not np.array_equal(np.sort(current_active), np.sort(active_midi)):
        logger.info("SA result discarded: chord changed before apply")
        return

    delta_cents = new_cents - old_cents
    ratios = np.power(2.0, delta_cents / 1200.0)

    # Try to create runtime glide ftables for each voice
    glide_ftables = {}  # note_index -> ftable_number
    for i, ratio in enumerate(ratios):
        if abs(ratio - 1.0) < 1e-6:
            continue
        ftable_num = _find_or_create_glide_ftable(ratio)
        if ftable_num is not None:
            glide_ftables[i] = ftable_num

    # Update tuned cents
    with state.lock:
        state.current_tuned_cents = new_cents.copy()
        state.cent_value_chord_prev = new_cents.copy()

    if glide_ftables:
        # Regenerate orchestration with glide on first events
        try:
            prepared = state.engine.prepare_chord(new_cents, active_midi, config,
                                                   glide_ftables=glide_ftables)
            with state.lock:
                state.prepared_chord = prepared
                state.current_step = 0
            logger.info(f"Glide transition applied with {len(glide_ftables)} ftable(s)")
        except Exception as e:
            logger.error(f"Glide orchestration error: {e}", exc_info=True)
    else:
        # No glide available — restart chord with new cents
        try:
            prepared = state.engine.prepare_chord(new_cents, active_midi, config)
            with state.lock:
                state.prepared_chord = prepared
                state.current_step = 0
            logger.info("SA restart (no glide): new cents applied")
        except Exception as e:
            logger.error(f"SA restart error: {e}", exc_info=True)

    chord_info = build_chord_info(active_midi, new_cents)
    broadcast_status({'chord_info': chord_info})


def _find_or_create_glide_ftable(ratio: float):
    """Look up or create a glide ftable for the given ratio. Returns ftable number or None."""
    # Round ratio for cache lookup
    rounded = round(ratio, 6)
    if rounded in state.glide_ftable_cache:
        return state.glide_ftable_cache[rounded]

    ftable_num = state.next_glide_ftable
    midpoint = (1.0 + ratio) / 2.0

    # Try to create the ftable at runtime via Csound scoreEvent
    # GEN06 cubic polynomial: f num 0 256 -6 1 128 midpoint 128 ratio
    ftable_params = (float(ftable_num), 0.0, 256.0, -6.0,
                     1.0, 128.0, midpoint, 128.0, ratio)
    try:
        state.csound_thread.scoreEvent(False, 'f', ftable_params)
        state.glide_ftable_cache[rounded] = ftable_num
        state.next_glide_ftable += 1
        logger.info(f"Created glide ftable f{ftable_num} ratio={ratio:.6f}")
        return ftable_num
    except Exception as e:
        # Log the missing ftable for post-performance appending
        ftable_str = (f"f{ftable_num} 0 256 -6 1 128 "
                      f"{midpoint} 128 {ratio}")
        state.missing_ftables_log.append(ftable_str)
        logger.warning(f"Could not create ftable at runtime: {e}. Logged: {ftable_str}")
        return None


# ── Playback ticker thread ────────────────────────────────────────────────

def playback_ticker_loop():
    """Step through prepared chord events at tempo, sending scoreEvents to Csound."""
    while not state.shutdown:
        with state.lock:
            running = state.running
            engine_enabled = state.engine_enabled
            tempo = state.engine_config.tempo

        if not running or not engine_enabled:
            time.sleep(0.01)
            continue

        with state.lock:
            prepared = state.prepared_chord
            current_step = state.current_step
        if prepared is None or prepared.n_steps == 0:
            time.sleep(0.01)
            continue

        step = current_step % prepared.n_steps
        events = prepared.step_events[step]

        # Send all events at this step to Csound
        for event in events:
            try:
                state.csound_thread.scoreEvent(False, 'i', event)
                logger.debug(f"step={step} scoreEvent: {event}")
            except Exception as e:
                logger.error(f"scoreEvent error: {e}")

        with state.lock:
            state.current_step = (step + 1) % prepared.n_steps

        # Broadcast current step for UI
        if step % 10 == 0:
            broadcast_status({'current_step': step, 'n_steps': prepared.n_steps})

        # 4 ticks per beat (matches offline tpq=0.25)
        seconds_per_tick = 60.0 / tempo / 4.0
        time.sleep(seconds_per_tick)

    logger.info("Playback ticker stopped.")


# ── FastAPI application ─────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start Csound, MIDI, chord processor, and ticker on startup."""
    state.event_loop = asyncio.get_running_loop()

    # Start Csound
    cs = libcsound.Csound()
    cs.setOption('-d -odac -m0')
    csd_path = os.path.join(local_dir, 'ball10.csd')
    cs.compileCsd(csd_path)
    csound_thread = cs.performanceThread()
    csound_thread.play()
    state.cs = cs
    state.csound_thread = csound_thread
    logger.info(f"Csound started with {csd_path}")

    # Start threads
    midi_thread = threading.Thread(target=midi_loop, daemon=True)
    midi_thread.start()

    processor_thread = threading.Thread(target=chord_processor_loop, daemon=True)
    processor_thread.start()

    ticker_thread = threading.Thread(target=playback_ticker_loop, daemon=True)
    ticker_thread.start()

    yield

    # Shutdown
    state.shutdown = True
    state.sa_cancel.set()  # cancel any running SA
    state.chord_changed.set()  # unblock processor
    midi_thread.join(timeout=2.0)
    processor_thread.join(timeout=2.0)
    ticker_thread.join(timeout=2.0)
    csound_thread.stop()
    csound_thread.join()
    del state.cs
    logger.info("Csound stopped.")

    # Write missing ftables log if any
    if state.missing_ftables_log:
        ftable_log_path = os.path.join(local_dir, 'missing_ftables.log')
        with open(ftable_log_path, 'w') as f:
            f.write('\n'.join(state.missing_ftables_log) + '\n')
        logger.info(f"Wrote {len(state.missing_ftables_log)} missing ftable(s) to {ftable_log_path}")


app = FastAPI(lifespan=lifespan)


@app.get("/", response_class=HTMLResponse)
async def index():
    html_path = os.path.join(local_dir, 'templates', 'index.html')
    with open(html_path) as f:
        return HTMLResponse(content=f.read())


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()

    # Attach a thread-safe pending sends deque for broadcast
    websocket._pending_sends = deque()
    with state.lock:
        state.connected_websockets.append(websocket)

    # Send current state on connect
    await websocket.send_json({
        'type': 'state',
        'tuning_enabled': state.tuning_enabled,
        'running': state.running,
        'engine_enabled': state.engine_enabled,
        'tempo': state.engine_config.tempo,
        'sections_enabled': state.engine_config.sections_enabled,
        'section_volumes': state.engine_config.section_volumes,
        'density_style': state.engine_config.density_style,
        'density_cycles': state.engine_config.density_cycles,
        'sparsity_min': state.engine_config.sparsity_min,
        'sparsity_max': state.engine_config.sparsity_max,
        'waveform': state.engine_config.waveform,
        'tolerance': state.tolerance,
        'limit_max': state.limit_max,
        'deep_tune_enabled': state.deep_tune_enabled,
        'dt_params': {
            'ratio_factor': state.dt_ratio_factor,
            'rolls': state.dt_rolls,
            'tolerance': state.dt_tolerance,
            'max_iterations': state.dt_max_iterations,
            'cooling_rate': state.dt_cooling_rate,
            'spread': state.dt_spread,
            'limit_max': state.dt_limit_max,
        },
        'voice_type_names': VOICE_TYPE_NAMES,
        'section_voices': {s: SECTION_VOICES[s] for s in SECTION_NAMES},
        'volume_preset_names': VOLUME_PRESET_NAMES,
    })
    await websocket.send_json({
        'type': 'status',
        'midi_port': state.midi_port_name or 'detecting...',
        'notes_held': int(np.sum(state.one_hot_note > 0)),
        'running': state.running,
    })

    try:
        while True:
            # Drain any pending broadcast messages
            while websocket._pending_sends:
                msg = websocket._pending_sends.popleft()
                await websocket.send_text(msg)

            try:
                raw = await asyncio.wait_for(websocket.receive_text(), timeout=0.1)
            except asyncio.TimeoutError:
                continue

            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                logger.warning("Received invalid JSON from websocket")
                continue

            if data['type'] == 'play':
                with state.lock:
                    state.running = True
                logger.info("PLAY")
                await websocket.send_json({'type': 'status', 'running': True})

            elif data['type'] == 'stop':
                with state.lock:
                    state.running = False
                logger.info("STOP")
                await websocket.send_json({'type': 'status', 'running': False})

            elif data['type'] == 'tuning':
                with state.lock:
                    state.tuning_enabled = data.get('value', True)
                logger.info(f"Straw man tuning {'enabled' if state.tuning_enabled else 'disabled'}")

            elif data['type'] == 'deep_tune':
                with state.lock:
                    state.deep_tune_enabled = data.get('value', False)
                logger.info(f"Deep tune (SA) {'enabled' if state.deep_tune_enabled else 'disabled'}")

            elif data['type'] == 'engine_toggle':
                with state.lock:
                    state.engine_enabled = data.get('value', True)
                logger.info(f"Engine {'enabled' if state.engine_enabled else 'disabled'}")

            elif data['type'] == 'tempo':
                with state.lock:
                    state.engine_config.tempo = max(40, min(200, int(data.get('value', 80))))
                logger.info(f"Tempo = {state.engine_config.tempo}")

            elif data['type'] == 'section_toggle':
                section = data.get('section', '')
                value = data.get('value', True)
                with state.lock:
                    if section in state.engine_config.sections_enabled:
                        state.engine_config.sections_enabled[section] = value
                # Trigger regeneration
                state.chord_changed.set()
                logger.info(f"Section {section} = {'on' if value else 'off'}")

            elif data['type'] == 'section_volume':
                section = data.get('section', '')
                value = int(data.get('value', 8))
                with state.lock:
                    if section in state.engine_config.section_volumes:
                        state.engine_config.section_volumes[section] = value
                state.chord_changed.set()
                logger.info(f"Section volume {section} = {value}")

            elif data['type'] == 'volume_preset':
                preset_name = data.get('value', 'Random')
                if preset_name == 'Random':
                    volumes = generate_random_volume_preset()
                else:
                    volumes = VOLUME_PRESETS.get(preset_name)
                    if volumes is None:
                        volumes = generate_random_volume_preset()
                with state.lock:
                    state.engine_config.section_volumes = dict(volumes)
                state.chord_changed.set()
                await websocket.send_json({'type': 'state', 'section_volumes': volumes})
                logger.info(f"Volume preset = {preset_name}")

            elif data['type'] == 'density_style':
                with state.lock:
                    state.engine_config.density_style = data.get('value', 'arpeggio')
                state.chord_changed.set()
                logger.info(f"Density style = {state.engine_config.density_style}")

            elif data['type'] == 'density_cycles':
                with state.lock:
                    state.engine_config.density_cycles = max(1, min(20, int(data.get('value', 5))))
                state.chord_changed.set()
                logger.info(f"Density cycles = {state.engine_config.density_cycles}")

            elif data['type'] == 'waveform':
                with state.lock:
                    state.engine_config.waveform = data.get('value', 'sine')
                state.chord_changed.set()
                logger.info(f"Waveform = {state.engine_config.waveform}")

            elif data['type'] == 'sparsity':
                with state.lock:
                    state.engine_config.sparsity_min = max(0.0, min(1.0, float(data.get('min', 0.05))))
                    state.engine_config.sparsity_max = max(0.0, min(1.0, float(data.get('max', 0.50))))
                state.chord_changed.set()
                logger.info(f"Sparsity = [{state.engine_config.sparsity_min}, {state.engine_config.sparsity_max}]")

            elif data['type'] == 'tolerance':
                val = max(1, min(4, int(data.get('value', 4))))
                with state.lock:
                    state.tolerance = val
                state.chord_changed.set()
                logger.info(f"Tolerance = {val}")

            elif data['type'] == 'limit_max':
                val = int(data.get('value', 19))
                if val in VALID_LIMIT_MAX:
                    td, cs, lnr = _build_tuning_objects(val)
                    with state.lock:
                        state.limit_max = val
                        state.tonal_diamond = td
                        state.chord_scorer = cs
                        state.low_number_ratios = lnr
                    state.chord_changed.set()
                    logger.info(f"Limit max = {val}")
                else:
                    logger.warning(f"Invalid limit_max: {val}")

            elif data['type'] == 'dt_param':
                param = data.get('param', '')
                value = data.get('value')
                with state.lock:
                    if param == 'ratio_factor':
                        state.dt_ratio_factor = max(0.5, min(8.0, float(value)))
                    elif param == 'rolls':
                        state.dt_rolls = max(1, min(8, int(value)))
                    elif param == 'tolerance':
                        state.dt_tolerance = max(1, min(4, int(value)))
                    elif param == 'max_iterations':
                        state.dt_max_iterations = max(10, min(200, int(value)))
                    elif param == 'cooling_rate':
                        state.dt_cooling_rate = max(0.70, min(0.99, float(value)))
                    elif param == 'spread':
                        state.dt_spread = max(0, min(15, int(value)))
                    elif param == 'limit_max':
                        new_lm = int(value)
                        if new_lm in VALID_LIMIT_MAX and new_lm != state.dt_limit_max:
                            state.dt_limit_max = new_lm
                    else:
                        logger.warning(f"Unknown dt_param: {param}")
                # Rebuild dt tuning objects outside the lock if limit_max changed
                if param == 'limit_max':
                    new_lm = int(value)
                    if new_lm in VALID_LIMIT_MAX:
                        dt_td, dt_cs, dt_lnr = _build_tuning_objects(new_lm)
                        with state.lock:
                            state.dt_tonal_diamond = dt_td
                            state.dt_chord_scorer = dt_cs
                            state.dt_low_number_ratios = dt_lnr
                logger.info(f"Deep tune {param} = {value}")

            elif data['type'] == 'section_instrument':
                section = data.get('section', '')
                voice_type = data.get('voice_type', '')
                if voice_type == 'default':
                    reset_section_voices(section)
                    logger.info(f"Section {section} voices reset to default")
                elif set_section_instrument(section, voice_type):
                    logger.info(f"Section {section} instrument -> {voice_type}")
                else:
                    logger.warning(f"Invalid section_instrument: {section} / {voice_type}")
                state.chord_changed.set()

    except WebSocketDisconnect:
        pass
    finally:
        with state.lock:
            if websocket in state.connected_websockets:
                state.connected_websockets.remove(websocket)


# ── Entry point ─────────────────────────────────────────────────────────────

if __name__ == '__main__':
    uvicorn.run(app, host='0.0.0.0', port=8000, log_config=None)
