"""
concert_restage.py - move a player (and everything that belongs to them) or clone one, over Blender MCP.

A player's things: the instrument rig with all its children, the extra objects listed in OWNED
(stand, stool, amp, cables), its cameras (with their Target empties) and its special light (with
its Aim empty). Every player faces the point (0, -12) unless they face straight downstage
(stagekit FACE_FORWARD), so moving someone is a rotation about their position plus a translation;
everything they own gets the same transform. The seat layout ("Stage Controls" layout_json) is
updated, and the body is rebuilt where it now stands.

Cloning copies those objects under a new name (the rig, its children, cameras, light, owned
objects); the parts that are generated per player are then rebuilt by the usual builders: body and
arms (concert_poses.build_all), mallets and live bars (marimba), tines (finger piano).

Used to give the stage two marimbas (ends of the riser) and two treble finger pianos (one on each
side), for splitting those voices by stereo position (see concert_stage.SPLIT), and on 2 Oct 2026 to
put the vibraphone in the back row of the riser and move the violin, oboe and horn upstage.
"""
import json
import math

import bpy
from mathutils import Matrix, Vector

import concert_stagekit as sk
import concert_poses as cp

# objects a player owns besides the rig (exact names); cameras and lights are found by name
OWNED = {
    "Marimba": [],
    "Finger Piano": ["Finger Piano Stand", "Stool - Finger Piano", "Stool Footring - Finger Piano",
                     "Pignose Amp - Finger Piano", "Cable - Finger Piano", "Cable - Finger Piano Plugs"],
    "Trumpet": [], "Clarinet": [],
    "Violin": ["Violin Bow"], "Oboe": [], "French Horn": ["Stool - French Horn"], "Vibraphone": [],
}
CAMS = {
    "Marimba": ["Cam 4 Marimba Player POV", "Cam 33 Marimba Player (side, full figure)"],
    "Finger Piano": ["Cam 10 Finger Piano (player view)", "Cam 29 Finger Piano Hands (front)"],
    "Trumpet": ["Cam 22 Trumpet Hands"], "Clarinet": [],
    "Violin": ["Cam 12 Violin Close"], "Oboe": ["Cam 34 Oboe Player", "Cam 7 Oboe Keys"],
    "French Horn": ["Cam 26 French Horn"], "Vibraphone": ["Cam 25 Vibraphone Player View"],
}
# cameras that frame this player and someone who stays put: they move half as far, so both stay in shot
SHARED_CAMS = {
    "Violin": ["Cam 21 Viola & Violin", "Cam 5 Cello & Violin"],
    "Trumpet": ["Cam 9 Trumpet & Trombone (riser)"], "Clarinet": ["Cam 15 Bassoon & Clarinet (riser)"],
}
LIGHTS = {"Marimba": "Special 8 Marimba", "Finger Piano": "Special 3 Finger Piano",
          "Trumpet": "Special 10 Trumpet", "Clarinet": "Special 6 Clarinet",
          "Violin": "Special 2 Violin", "Oboe": "Special 7 Oboe", "French Horn": "Special 14 French Horn",
          "Vibraphone": "Special 16 Vibraphone"}


def _yaw(f):
    return math.atan2(f.y, f.x)


def player_transform(key, new_pos):
    """World transform carrying the player at their LAYOUT position to new_pos, turned to face as a
    player standing there would."""
    p0, f0, _l, _u = sk.frame_for(key)
    old = sk.LAYOUT[key]["pos"]
    sk.LAYOUT[key]["pos"] = list(new_pos)
    p1, f1, _l, _u = sk.frame_for(key)
    sk.LAYOUT[key]["pos"] = old
    return Matrix.Translation(p1) @ Matrix.Rotation(_yaw(f1) - _yaw(f0), 4, 'Z') @ Matrix.Translation(-p0)


def owned_objects(key, with_generated=True):
    """Top-level objects that belong to a player (children come along with their parents)."""
    names = [key] + OWNED.get(key, []) + [LIGHTS[key], LIGHTS[key] + " Aim"]
    for c in CAMS.get(key, []):
        names += [c, c + " Target"]
    obs = [bpy.data.objects[n] for n in names if n in bpy.data.objects]
    if with_generated and key in cp.MALLET_SETS:
        obs += [o for o in bpy.data.objects if o.name.startswith(f"{key} Mallet ")]
    return [o for o in obs if o.parent is None or o.parent not in obs]


def _carry_rest(ob, T):
    """A wind rig keeps its at-the-lips matrix (concert_poses.lower_instrument); move that too."""
    if "rest_matrix" in ob:
        r = list(ob["rest_matrix"])
        R = T @ Matrix([r[0:4], r[4:8], r[8:12], r[12:16]])
        ob["rest_matrix"] = [v for row in R for v in row]


LIGHT_TRUSSES = ("Truss Front", "Truss Mid")   # the specials hang from these, never the upstage truss
LIGHT_HANG = (-0.2, 7.3)                       # 0.2 m in front of the truss, at this height


def hang_light(key):
    """Re-hang a player's special light (and its fixture) on the nearest truss in front of the player,
    keeping its x; the Aim empty travels with the player, so the light still points at them."""
    L = bpy.data.objects.get(LIGHTS.get(key, ""))
    if L is None:
        return
    py = sk.LAYOUT[key]["pos"][1]
    ys = []
    for n in LIGHT_TRUSSES:
        bb = [bpy.data.objects[n].matrix_world @ Vector(c) for c in bpy.data.objects[n].bound_box]
        ys.append(sum(p.y for p in bb) / 8)
    front = [y for y in ys if y < py] or [min(ys)]
    L.location.y = max(front) + LIGHT_HANG[0]
    L.location.z = LIGHT_HANG[1]


def _save_layout():
    bpy.data.objects["Stage Controls"]["layout_json"] = json.dumps(sk.LAYOUT)


def move_player(key, new_pos, rebuild=True):
    half = (Vector(new_pos) - Vector(sk.LAYOUT[key]["pos"])) / 2
    T = player_transform(key, new_pos)
    for ob in owned_objects(key):
        ob.matrix_world = T @ ob.matrix_world
        _carry_rest(ob, T)
    for c in SHARED_CAMS.get(key, []):
        for n in (c, c + " Target"):
            ob = bpy.data.objects.get(n)
            if ob is not None and ob.parent is None:
                ob.location += half
    sk.LAYOUT[key]["pos"] = list(new_pos)
    _save_layout()
    hang_light(key)
    if rebuild:
        rebuild_players([key])
    return T


def rebuild_players(keys):
    """Body, face, arms (and legs) where the layout now says; skin face map re-centred on the head."""
    import concert_faces as cf
    cp.load_layout()
    for key in keys:
        m = bpy.data.materials.get(f"Skin {cp.PLAYERS[key][0]}")
        if m is not None:
            cf.reset_skin(m)
        for ob in [o for o in bpy.data.objects if o.name.startswith(cp.body_name(key) + " ") or o.name == cp.body_name(key)]:
            bpy.data.objects.remove(ob, do_unlink=True)
        cp.build_body(key)
        cp.build_puppet(key)
        if key in cp.STEPPERS:
            cp.build_legs(key)
    bpy.context.view_layer.update()
    for key in keys:
        cp.pose(key)


def _rename(name, src, dst):
    return name.replace(src, dst, 1) if src in name else f"{name} ({dst})"


def clone_player(src, dst, new_pos, cam_names=None, light_name=None, skip=lambda ob: False):
    """Copy src's rig, owned objects, cameras and light as dst's, placed at new_pos. cam_names maps
    each source camera to its new name; light_name names the new special light. Objects for which
    skip(ob) is true (generated per player: tines, bars) are not copied."""
    T = player_transform(src, new_pos)
    cam_names = cam_names or {}
    tops = owned_objects(src, with_generated=False)
    allobs = []
    for t in tops:
        allobs += [t] + [c for c in t.children_recursive]
    allobs = [o for o in allobs if not skip(o)]
    mapping = {}
    for ob in allobs:
        new = ob.copy()
        if ob.data is not None and ob.type in ('LIGHT', 'CAMERA'):
            new.data = ob.data.copy()
        if ob.name in cam_names:
            new.name = cam_names[ob.name]
        elif ob.name.endswith(" Target") and ob.name[:-7] in cam_names:
            new.name = cam_names[ob.name[:-7]] + " Target"
        elif ob.name == LIGHTS[src]:
            new.name = light_name
        elif ob.name == LIGHTS[src] + " Aim":
            new.name = light_name + " Aim"
        else:
            new.name = _rename(ob.name, src, dst)
        for c in ob.users_collection:
            c.objects.link(new)
        mapping[ob] = new
    for ob, new in mapping.items():
        if ob.parent in mapping:
            new.parent = mapping[ob.parent]
            new.matrix_parent_inverse = ob.matrix_parent_inverse.copy()
        for c in new.constraints:
            if getattr(c, "target", None) in mapping:
                c.target = mapping[c.target]
        for idb in (new, new.data if new.type == 'LIGHT' else None):
            ad = idb.animation_data if idb is not None else None
            for fc in (ad.drivers if ad else []):
                for v in fc.driver.variables:
                    for tg in v.targets:
                        if tg.id in mapping:
                            tg.id = mapping[tg.id]
    for ob, new in mapping.items():
        if ob.parent not in mapping:
            new.matrix_world = T @ ob.matrix_world
    sk.LAYOUT[dst] = dict(sk.LAYOUT[src]); sk.LAYOUT[dst]["pos"] = list(new_pos)
    _save_layout()
    return mapping
