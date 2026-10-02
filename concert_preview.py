"""
concert_preview.py - scrub a piece in the Blender viewport exactly as the farm renders it.

The stage's playing is computed by concert_stage.py frame by frame; nothing is keyframed, so the
Blender timeline on its own only ever shows the rest pose. Loading a piece here hooks the same
Performance.apply() the render uses into the timeline: scrubbing or pressing play poses every player,
cuts the cameras per the cue sheet, and moves the lights. The mp3 goes on the timeline as a sound
strip, so playback is heard in sync.

In Blender (Stage tab > Preview a Piece), or from the Python console:
    import concert_preview as pv
    pv.load("Uploads/b421g_df4_t1_d01_00_t106_ap4_lm19_r1.38", tempo=106, cues="b421g_56")
    pv.unload()          # handler off, sound strip removed, stage back at rest

To see the real materials (wood grain, skin, hair), switch the viewport to Material Preview or
Rendered shading - Solid shading draws each object in one flat colour.
"""
import math
import os
import sys
from pathlib import Path

import bpy

REPO = Path(__file__).resolve().parent
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))
import concert_stagekit
sys.modules.setdefault("stagekit", concert_stagekit)
import concert_poses as cp        # noqa: E402
import concert_stage as cs        # noqa: E402

STATE = {"perf": None, "busy": False}
SOUND_STRIP = "Preview Audio"


def _on_frame(scene, depsgraph=None):
    perf = STATE["perf"]
    if perf is None or STATE["busy"] or scene.name != "Concert Stage":
        return
    STATE["busy"] = True
    try:
        perf.apply(scene, scene.frame_current / cs.FPS, set_camera=STATE.get("cut", True))
    finally:
        STATE["busy"] = False


def _strips(scene):
    se = scene.sequence_editor or scene.sequence_editor_create()
    return se.strips if hasattr(se, "strips") else se.sequences     # 'strips' since Blender 4.4


def load(stem, tempo, cues=None, duration=None, follow_cues=True, shading='MATERIAL'):
    """stem: path (relative to the repo, or absolute) without the .npy/.mp3 extension."""
    unload(quiet=True)
    base = Path(stem)
    if not base.is_absolute():
        base = REPO / base
    npy, mp3 = str(base) + ".npy", str(base) + ".mp3"
    scene = bpy.data.scenes["Concert Stage"]
    if duration is None:                                   # length of the piece: last note + 1.5 s of ring
        per = cs.load_notes(npy, tempo)
        duration = max(n["t1"] for ns in per.values() for n in ns) + 1.5
    perf = STATE["perf"] = cs.Performance(npy, tempo, duration, cues)
    STATE["cut"] = follow_cues
    scene.render.fps = cs.FPS
    # with a title card the music (and its sound strip) starts perf.lead seconds in, as in the muxed video,
    # and the closing card runs perf.tail seconds past its end
    scene.frame_start, scene.frame_end = 0, int(math.ceil((duration + perf.lead + perf.tail) * cs.FPS)) - 1
    if os.path.exists(mp3):                                 # audio in sync with the timeline
        strips = _strips(scene)
        s = strips.new_sound(SOUND_STRIP, mp3, channel=1, frame_start=int(round(perf.lead * cs.FPS)))
        scene.sync_mode = 'AUDIO_SYNC'
    scene.render.use_sequencer = False                     # the strip is for listening only, never for rendering
    for h in list(bpy.app.handlers.frame_change_post):
        if getattr(h, "__name__", "") == "_on_frame":
            bpy.app.handlers.frame_change_post.remove(h)
    bpy.app.handlers.frame_change_post.append(_on_frame)
    for win in bpy.context.window_manager.windows:
        for area in win.screen.areas:
            if area.type == 'VIEW_3D' and shading:
                area.spaces.active.shading.type = shading
    scene.frame_set(0)
    print(f"[preview] {Path(npy).name}: {scene.frame_end + 1} frames, cues={cues or 'generated'}")
    return STATE["perf"]


def unload(quiet=False):
    for h in list(bpy.app.handlers.frame_change_post):
        if getattr(h, "__name__", "") == "_on_frame":
            bpy.app.handlers.frame_change_post.remove(h)
    scene = bpy.data.scenes["Concert Stage"]
    if scene.sequence_editor:
        strips = _strips(scene)
        for s in [s for s in strips if s.name.startswith(SOUND_STRIP)]:
            strips.remove(s)
    if STATE["perf"] is not None:
        STATE["perf"].restore()
    STATE["perf"] = None
    if not quiet:
        print("[preview] unloaded; stage at rest")
