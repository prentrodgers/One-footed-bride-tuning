#!/usr/bin/env python3
"""
blender_melody_poc.py — the melody section: flute, clarinet, vibraphone
(back) and oboe, bassoon, trumpet (front), csound voices 14/13/7/15/12/25.

Reuses the woodwind clarinet/oboe/bassoon builders and the brass trumpet
builder wholesale; adds a simple silver flute and a compact vibraphone.
Static placement pass — the sway/lean/glow animation is wired the same way
the woodwind/brass sections are, once positioned.
"""
import math
import numpy as np
import sys
from pathlib import Path

import bpy
import mathutils

REPO_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_DIR))

import blender_bass_section_poc as bass
import blender_woodwind_poc as ww
import blender_brass_poc as brass
import blender_marimba_poc as marimba

BODY_CLR = {
    'flute':      (0.82, 0.84, 0.88),   # silver
    'clarinet':   (0.14, 0.12, 0.10),   # ebony
    'vibraphone': (0.80, 0.82, 0.86),   # aluminium bars
    'oboe':       (0.12, 0.10, 0.08),   # grenadilla
    'bassoon':    (0.20, 0.11, 0.05),   # dark stained maple, at rest
    'trumpet':    (0.82, 0.68, 0.22),   # brass
}
GLOW_CLR = {
    'flute':      (0.88, 0.92, 1.00),
    'clarinet':   (0.55, 0.65, 0.90),
    'vibraphone': (0.90, 0.95, 1.00),
    'oboe':       (0.55, 0.65, 0.90),
    'bassoon':    (0.76, 0.55, 0.31),   # light brown while playing
    'trumpet':    (1.00, 0.90, 0.50),
}
PLAY_LEAN_DEG = {'flute': 8.0, 'clarinet': 8.0, 'vibraphone': 0.0,
                 'oboe': 7.0, 'bassoon': 6.0, 'trumpet': 9.0}
SWAY_FREQS = [0.24, 0.21, 0.19, 0.26, 0.225, 0.27]
SWAY_PHASES = [0.0, 1.2, 2.4, 0.6, 1.8, 3.0]


def build_flute(body_mat):
    """A slim silver flute held horizontally: bore along X, lip plate + a row
    of keys on top, closed crown at the left end."""
    key = ww.make_solid("MelFluteKey", (0.70, 0.72, 0.76), roughness=0.3, metallic=0.7)
    z, r = 1.35, 0.024
    # Proportions (12 Sep 2026): the tube is 1.13 long, 20% more than the
    # 0.94 it was, with all of the extra between the lip plate and the
    # first tone hole; the lip plate sits halfway from its old spot to the
    # crown; the holes begin just left of the tube's middle.
    x0, x1 = -0.48, 0.648
    bore = brass._tube((x0, 0.0, z), (x1, 0.0, z), r, r, body_mat)
    crown = brass._tube((x0, 0.0, z), (x0 - 0.06, 0.0, z), r + 0.002, r + 0.002, key)
    lip = ww._ball(-0.39, z + 0.02, 0.03, key, scale=(1.4, 0.6, 1.0))
    # Nine tone holes on TOP of the tube, the woodwinds' count, driven by
    # the same coverage rule (blender_woodwind_poc apply_fingering): the
    # first hole is nearest the embouchure, as the clarinet's first is
    # nearest the mouthpiece, and holes fill from there.
    mid = (x0 + x1) / 2.0
    xs = [(mid - 0.03) + (x1 - 0.05 - (mid - 0.03)) * i / (ww.N_HOLES - 1) for i in range(ww.N_HOLES)]
    holes = [ww._ball(kx, z + r, 0.017, ww.make_pad_material(), y=0.0, scale=(1, 1, 0.5))
             for kx in xs]
    return [bore, crown, lip] + holes, [bore], {"holes": holes}


# Vibraphone bar geometry. Bars are supported only at their vibrational
# nodes — NODE_FRAC in from each end, where the fundamental bending mode is
# stationary — so the ends and the middle stay free to ring. Nothing crosses
# over the top of the bars: a rail there would both damp them and hide them
# from the overhead shot.
VIB_N = 13
VIB_X0, VIB_X1, VIB_Z = -0.52, 0.52, 0.80
VIB_BAR_LEN_LOW, VIB_BAR_LEN_HIGH = 0.20, 0.14
VIB_BAR_THICK = 0.014
VIB_NODE_FRAC = 0.2
VIB_RAIL_DROP = 0.05     # rails run this far below the bars
# Quarter-wave tubes go as 1/f while bar length goes as 1/sqrt(f), so tube
# length tracks the SQUARE of bar length. The absolute lengths are not tuned
# to anything — the visible ramp from long to short is the whole point.
VIB_RES_LEN_LOW = 0.46


def build_vibraphone(body_mat):
    """A compact vibraphone: aluminium bars resting on felt pads at their
    nodes, over a resonator per bar whose length grows with its bar's."""
    frame = ww.make_solid("MelVibeFrame", (0.13, 0.13, 0.15), roughness=0.55)
    felt = ww.make_solid("MelVibeFelt", (0.32, 0.09, 0.11), roughness=0.9)
    reson = ww.make_solid("MelVibeReson", (0.55, 0.56, 0.60), roughness=0.35, metallic=0.6)
    span = VIB_BAR_LEN_LOW - VIB_BAR_LEN_HIGH
    half_t = VIB_BAR_THICK / 2.0
    rail_z = VIB_Z - VIB_RAIL_DROP
    bars, others, rails = [], [], ([], [])
    for i in range(VIB_N):
        f = i / (VIB_N - 1)
        bx = VIB_X0 + (VIB_X1 - VIB_X0) * f
        blen = VIB_BAR_LEN_LOW - span * f
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx, 0.0, VIB_Z))
        b = bpy.context.object
        b.scale = (0.032, blen, VIB_BAR_THICK)
        b.data.materials.append(body_mat)
        bars.append(b)

        for k, sign in enumerate((-1, 1)):
            ny = sign * blen * (0.5 - VIB_NODE_FRAC)
            rails[k].append((bx, ny, rail_z))
            bpy.ops.mesh.primitive_cylinder_add(
                radius=0.011, depth=VIB_RAIL_DROP - half_t,
                location=(bx, ny, (rail_z + VIB_Z - half_t) / 2.0))
            pad = bpy.context.object
            pad.data.materials.append(felt)
            others.append(pad)

        rlen = VIB_RES_LEN_LOW * (blen / VIB_BAR_LEN_LOW) ** 2
        rrad = 0.012 + 0.014 * (blen - VIB_BAR_LEN_HIGH) / span
        bpy.ops.mesh.primitive_cylinder_add(
            radius=rrad, depth=rlen,
            location=(bx, 0.0, VIB_Z - half_t - 0.02 - rlen / 2.0))
        t = bpy.context.object
        t.data.materials.append(reson)
        others.append(t)

    # Two rails threaded through the node points — they taper inward as the
    # bars shorten — each carried on a leg at either end.
    for pts in rails:
        run = ([(VIB_X0 - 0.06, pts[0][1], rail_z)] + pts
               + [(VIB_X1 + 0.06, pts[-1][1], rail_z)])
        others.append(ww._curve_tube(run, 0.010, frame, name="MelVibeRail"))
        for lx, ly, _ in (run[0], run[-1]):
            others.append(brass._tube((lx, ly, 0.0), (lx, ly, rail_z), 0.014, 0.014, frame))
    # Bar centres in the seat's own frame, for the mallets.
    bar_info = [dict(x=VIB_X0 + (VIB_X1 - VIB_X0) * i / (VIB_N - 1), y=0.0, z=VIB_Z)
                for i in range(VIB_N)]
    return bars + others, bars, dict(bars=bar_info)


# ── Vibraphone mallets ──────────────────────────────────────────────────────
# The marimba's mallet mechanism (blender_marimba_poc: slot allocation,
# strike curve, timing) reused for the vibraphone. Only the geometry differs:
# these live in the vibraphone seat's frame, parented to its empty — which is
# scaled 2.0 and sits in a section scaled 1.8 onto the stage — so the sizes
# below are seat-local. A 0.30 rod is 1.1 m on stage, the head 8 cm across.
VMALLET_LEN     = 0.30
VMALLET_HEAD_R  = 0.022
VMALLET_STICK_R = 0.005
# The swing lies in the picture plane (X-Z), not the depth plane: a stick
# tilted toward the camera foreshortens to near-vertical from the front,
# which read as the mallet hitting the bar end-on. The hand sits to one
# side of the bar (even slots from the left, odd from the right, like two
# hands) and the stick reaches across at VMALLET_STRIKE_DEG above
# horizontal at contact. Between notes it flattens to VMALLET_REST_DEG,
# which with the hand above the bar lifts the head about 5 cm and a little
# past the bar — a wrist stroke that starts close to the bars.
VMALLET_STRIKE_DEG = 45.0
VMALLET_REST_DEG   = 30.0
# Bar glow: a bar lights on its own strike and fades, on top of the seat's
# whole-instrument glow, so the eye can find the note being played.
VBAR_GLOW_DECAY = 0.45   # seconds


def vib_pitch_to_idx(notes):
    """Semitone -> bar index for one voice: its range spread across the 13
    bars, low notes on the long bars at the left. Keys are cents (multiples
    of 100), the way assign_mallet_slots looks them up."""
    if not len(notes):
        return {}
    semis = np.round(notes[:, 1] / 100.0).astype(int)
    lo, hi = int(semis.min()), int(semis.max())
    span = max(hi - lo, 1)
    return {s * 100: int(round((s - lo) / span * (VIB_N - 1))) for s in range(lo, hi + 1)}


def build_vib_mallets(n_slots, empty):
    """A pool of mallets parented to the seat empty: pivot (hand) with a
    stick and head hanging straight down, hidden until a strike."""
    mat = marimba.make_mallet_material()
    pivots, sticks, heads = [], [], []
    for s in range(n_slots):
        pivot = bpy.data.objects.new(f"vib_mallet_pivot_{s}", None)
        bpy.context.scene.collection.objects.link(pivot)
        pivot.parent = empty
        pivot.location = (0.0, 0.0, 0.0)
        bpy.ops.mesh.primitive_cylinder_add(
            radius=VMALLET_STICK_R, depth=VMALLET_LEN, location=(0.0, 0.0, -VMALLET_LEN / 2.0))
        stick = bpy.context.object
        stick.name = f"vib_mallet_stick_{s}"
        stick.data.materials.append(mat)
        stick.hide_render = True
        stick.parent = pivot          # location above is now relative to the pivot
        bpy.ops.mesh.primitive_uv_sphere_add(radius=VMALLET_HEAD_R, location=(0.0, 0.0, -VMALLET_LEN))
        head = bpy.context.object
        head.name = f"vib_mallet_head_{s}"
        head.data.materials.append(mat)
        head.hide_render = True
        head.parent = pivot
        pivots.append(pivot); sticks.append(stick); heads.append(head)
    return pivots, sticks, heads


def arm_vibraphone_mallets(geom, seat_notes):
    """Once the stage has the notes: map the vibraphone voice onto the bars,
    allocate mallet slots the marimba's way, build that many mallets."""
    for seat in geom['seats']:
        if seat['kind'] != 'vibraphone' or 'bar_info' not in seat:
            continue
        notes = np.array(seat_notes[seat['id']], dtype=float)
        p2i = vib_pitch_to_idx(notes)
        if len(notes):
            notes = notes.copy()
            notes[:, 1] = np.round(notes[:, 1] / 100.0) * 100.0
        assignments, n_slots = marimba.assign_mallet_slots(notes, p2i)
        pivots, sticks, heads = build_vib_mallets(n_slots, seat['empty'])
        seat['mallets'] = dict(assignments=assignments, n_slots=n_slots, pivots=pivots,
                               sticks=sticks, heads=heads, notes=notes, p2i=p2i)


def update_vib_mallets(t, seat):
    """Swing the mallets for every note mid-strike, and light the struck
    bars. Same window and curve as the marimba (marimba.strike_angle)."""
    m = seat.get('mallets')
    if not m:
        return
    active = [None] * m['n_slots']
    for start, end, onset, idx, slot in m['assignments']:
        if start <= t <= end:
            active[slot] = (onset, idx)
    e_strike = math.radians(VMALLET_STRIKE_DEG)
    for s in range(m['n_slots']):
        stick, head = m['sticks'][s], m['heads'][s]
        if active[s] is None:
            stick.hide_render = True
            head.hide_render = True
            continue
        onset, idx = active[s]
        info = seat['bar_info'][idx]
        bar_top = info['z'] + VIB_BAR_THICK / 2.0 + VMALLET_HEAD_R
        side = 1.0 if s % 2 == 0 else -1.0      # hand left of the bar, or right
        # The marimba's timing curve, taken as a 0..1 progress from rest to
        # contact (a touch past 1 on the follow-through), mapped onto this
        # mallet's own elevation range.
        a = marimba.strike_angle(t - onset)
        frac = (a - marimba.MALLET_REST_ANGLE) / (marimba.MALLET_STRIKE_ANGLE - marimba.MALLET_REST_ANGLE)
        elev = math.radians(VMALLET_REST_DEG + (VMALLET_STRIKE_DEG - VMALLET_REST_DEG) * frac)
        # Hand placed so the head lands on the bar's centre at the strike
        # elevation; the stick, built hanging down -Z, is rotated about Y to
        # reach across toward the bar.
        m['pivots'][s].location = (info['x'] - side * VMALLET_LEN * math.cos(e_strike),
                                   info['y'],
                                   bar_top + VMALLET_LEN * math.sin(e_strike))
        m['pivots'][s].rotation_euler = (0.0, -side * (math.pi / 2.0 - elev), 0.0)
        stick.hide_render = False
        head.hide_render = False

    # Per-bar glow from the most recent strike on each bar.
    notes, p2i = m['notes'], m['p2i']
    if len(notes):
        glow = np.zeros(VIB_N)
        recent = notes[(notes[:, 0] <= t) & (notes[:, 0] > t - VBAR_GLOW_DECAY)]
        for row in recent:
            idx = p2i.get(int(round(row[1])))
            if idx is not None:
                glow[idx] = max(glow[idx], 1.0 - (t - row[0]) / VBAR_GLOW_DECAY)
        base, tint = BODY_CLR['vibraphone'], GLOW_CLR['vibraphone']
        for i, bar in enumerate(seat['body']):
            if glow[i] > 0.02:
                bar.color = (*(base[k] + glow[i] * (tint[k] - base[k]) for k in range(3)), 1.0)


# Height (in the builder's own units) at which a held instrument is built;
# build_melody keeps it there whatever the seat's scale.
HELD_Z = {'flute': 1.35}

BUILDERS = {
    'flute': build_flute, 'clarinet': ww.build_clarinet, 'vibraphone': build_vibraphone,
    'oboe': ww.build_oboe, 'bassoon': ww.build_bassoon, 'trumpet': brass.build_trumpet,
}

# id, kind, voice, x, y (depth), roll, scale
SEATS_SPEC = [
    ('flute',      'flute',      14, -2.35, 0.6,  0.0,  1.5),  # 50% larger, moved left clear of the clarinet
    ('clarinet',   'clarinet',   13, -1.05, 0.7,  14.0, 1.0),  # pulled left, in under the flute
    ('vibraphone', 'vibraphone', 7,   2.5,  1.1,  0.0,  2.0),  # enlarged 1.5 -> 2.0, shifted right to keep the bassoon clear
    ('oboe',       'oboe',       15, -2.1, -0.7,  14.0, 1.0),  # under the flute, clear of the clarinet
    ('bassoon',    'bassoon',    12, -0.2, -0.5,  20.0, 1.0),  # tilt halved (40 -> 20)
    ('trumpet',    'trumpet',    25,  1.3, -1.9,  0.0,  1.0),  # further forward (-1.05 -> -1.9)
]


def build_melody(x0):
    metal_mat = ww.make_body_material("MelBodyMetal")
    wood_mat = ww.make_body_material("MelBodyWood", metallic=0.0, roughness=0.45)
    seats = []
    for i, (sid, kind, voice, sx, sy, roll, scale) in enumerate(SEATS_SPEC):
        # Silver flute, aluminium vibraphone bars and brass trumpet take the
        # metal response; the clarinet, oboe and bassoon are wood.
        body_mat = metal_mat if kind in ww.METAL_KINDS else wood_mat
        built = BUILDERS[kind](body_mat)
        all_objs, body_objs = built[0], built[1]
        moving = built[2] if len(built) > 2 else {}
        vib_bars = None
        if kind == 'vibraphone':
            vib_bars, moving = moving.get('bars'), {}
        for o in body_objs:
            o.color = (*BODY_CLR[kind], 1.0)
        empty = bpy.data.objects.new(f"mel_{sid}", None)
        bpy.context.scene.collection.objects.link(empty)
        # A seat scales about its empty at floor level, right for anything
        # standing on the floor. A held instrument would ride up with its
        # scale, so its empty drops to keep the instrument at HELD_Z.
        held_z = HELD_Z.get(kind, 0.0)
        empty.location = (x0 + sx, sy, held_z * (1.0 - scale))
        empty.scale = (scale, scale, scale)
        empty.rotation_euler = (0.0, math.radians(roll), 0.0)
        for o in all_objs:
            if o.parent is None:
                o.parent = empty
        seat = dict(id=sid, kind=kind, voice=voice, empty=empty, body=body_objs,
                    sway_freq=SWAY_FREQS[i], sway_phase=SWAY_PHASES[i],
                    sway_env=0.0, base_roll=roll)
        # These are the woodwind and brass builders, so the same pitch
        # mechanisms come free here — and this is the front row, where they
        # are most likely to be seen.
        if moving.get("valves") or moving.get("slide"):
            brass.arm_pitch_mechanism(seat, moving)
        else:
            ww._arm_fingering(seat, moving)
        if kind == 'vibraphone':
            seat['sway_amp'] = 0.0   # struck instrument — no tilt, no rock
            seat['bar_info'] = vib_bars   # mallets are armed once notes are known
        seats.append(seat)
    return dict(seats=seats)


def load_seat_notes(npy, tempo, seats):
    import numpy as np
    if not npy:
        return {s['id']: np.zeros((0, 5)) for s in seats}
    return {s['id']: bass.load_voices(npy, tempo, (s['voice'],)) for s in seats}


def update_melody(t, geom, seat_notes):
    ww.update_wind_seats(t, geom['seats'], seat_notes, BODY_CLR, GLOW_CLR, PLAY_LEAN_DEG)
    for seat in geom['seats']:
        if seat['kind'] == 'vibraphone':
            update_vib_mallets(t, seat)


def _smoke_test(out_path):
    bass.clear_scene()
    build_melody(0.0)
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("Cam"); cam_data.lens = 35
    cam = bpy.data.objects.new("Cam", cam_data); scene.collection.objects.link(cam)
    cam.location = (0.0, -4.2, 1.7)
    d = mathutils.Vector((0, 0, 0.9)) - mathutils.Vector(cam.location)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler(); scene.camera = cam
    sun = bpy.data.lights.new("Sun", type='SUN'); sun.energy = 2.6
    so = bpy.data.objects.new("Sun", sun); so.rotation_euler = (math.radians(55), 0, math.radians(20))
    scene.collection.objects.link(so)
    w = scene.world or bpy.data.worlds.new("W"); scene.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.5
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.view_settings.view_transform = 'Standard'
    scene.render.filepath = str(Path(out_path).resolve())
    bpy.ops.render.render(write_still=True)
    print(f"[melody] wrote {out_path}")


if __name__ == "__main__":
    import argparse
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser(); p.add_argument("--still", default="melody_smoke.png")
    _smoke_test(p.parse_args(argv).still)
