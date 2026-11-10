"""
concert_duo.py - make a small-ensemble stage from Concert_Stage.blend: the chosen players moved together
near centre stage, everyone else hidden, cameras framed on the ensemble.

    blender --background Concert_Stage.blend --python concert_duo.py -- --out FingerPiano_Duo.blend

Concert_Stage.blend itself is not changed. The new file carries its cast in the "Stage Controls" object
(ensemble_json); concert_stage.py reads it, poses only the cast and picks shots only from the ensemble's
cameras, so the farm renders it with the usual command and BLEND=FingerPiano_Duo.blend.

Default: the two treble finger pianos (BWV 846 on two finger pianos, Nov 2026). Finger Piano 2 takes the
notes panned to the audience's left (concert_stage.SPLIT), so it sits on their left (-x).
"""
import argparse
import json
import re
import sys
from pathlib import Path

import bpy

REPO_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_DIR))
import concert_stagekit as sk        # noqa: E402
import concert_poses as cp           # noqa: E402
import concert_cameras as cc         # noqa: E402
import concert_restage as rs         # noqa: E402

# player -> new position (x, y, floor z). Both face (0, -12) like the rest of the front row, so a little
# inward; 2.8 m apart keeps the amps and stools clear of each other.
DUO = {"Finger Piano 2": (-1.4, -1.0, 0.0), "Finger Piano": (1.4, -1.0, 0.0)}

# the ensemble's cameras: name -> (azimuth, elevation, lens), framed by concert_cameras._fit on both players
# (azimuth 0 is from the audience; + from the audience's right)
DUO_CAMS = {
    "Cam 53 Duo (front)": (0, 10, 40),
    "Cam 54 Duo (from the right)": (35, 14, 45),
    "Cam 55 Duo (from the left)": (-35, 14, 45),
    "Cam 56 Duo (high)": (0, 45, 35),
}
WIDE = ["Cam 1 Audience Wide", "Cam 2 Front Row Left", "Cam 8 Stage Right Side"]
DOLLIES = ["Cam 50 Dolly Front Row"]          # the other two pass over empty rows
DOLLY_MARGIN = 0.5    # the dolly runs from this far outside the end players to the same past the other end:
                      # the 26 mm lens sees ~5 m of the row, so a player is in frame the whole way


def owner(name):
    """The player an object belongs to, by the stage's naming (or None: stage, house lights, cameras)."""
    m = re.match(r"Musician (\d+) - ", name)
    if m:
        i = int(m.group(1)) - 1
        return next((k for k, v in cp.PLAYERS.items() if v[0] == i), None)
    rest = re.sub(r"^(Special \d+ |Stool Footring - |Stool - |Pignose Amp - |Cable - |Music Stand - )", "", name)
    keys = [k for k in cp.PLAYERS if rest == k or rest.startswith(k + " ")]
    return max(keys, key=len) if keys else None


def hide_others(cast):
    """Hide (render and viewport) everything owned by players not in the cast, children included."""
    hidden = set()
    for ob in bpy.data.objects:
        if ob.type == 'CAMERA' or ob.name.endswith(" Target"):
            continue
        k = owner(ob.name)
        if k is not None and k not in cast:
            hidden.add(ob)
            hidden.update(ob.children_recursive)
    for ob in hidden:
        ob.hide_render = ob.hide_viewport = True
    return hidden


def build_cams(cast):
    pts = []
    for key in cast:
        pts += cc._player_points(key)              # the body's box holds the instrument in the lap too
    for name, (az, el, lens) in DUO_CAMS.items():
        cam, tgt = cc._camera(name, lens)
        cam.location, tgt.location = cc._fit(pts, az, el, lens)


def dollies(cast):
    """The ensemble's dollies, each bracketed to the cast: {name: concert_cameras.DOLLY_CAMS tuple}."""
    xs = [sk.LAYOUT[k]["pos"][0] for k in cast]
    out = {}
    for name in DOLLIES:
        y, z, ty, tz, _x0, _x1, lens = cc.DOLLY_CAMS[name]
        out[name] = [y, z, ty, tz, min(xs) - DOLLY_MARGIN, max(xs) + DOLLY_MARGIN, lens]
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--out", default="FingerPiano_Duo.blend")
    args = p.parse_args(argv)

    cp.load_layout()
    for key, pos in DUO.items():
        rs.move_player(key, pos)
        print(f"[duo] {key} -> {pos}")
    hidden = hide_others(set(DUO))
    print(f"[duo] hid {len(hidden)} objects of the other players")
    bpy.context.view_layer.update()
    build_cams(list(DUO))
    ens = {
        "players": list(DUO),
        "player_cams": {k: [c for c in rs.CAMS[k]] for k in DUO},
        "group_cams": {name: [list(DUO), az, el, lens] for name, (az, el, lens) in DUO_CAMS.items()},
        "wide_cams": WIDE,
        "dolly_cams": dollies(list(DUO)),
    }
    bpy.data.objects["Stage Controls"]["ensemble_json"] = json.dumps(ens)
    out = str((REPO_DIR / args.out).resolve()) if not Path(args.out).is_absolute() else args.out
    bpy.ops.wm.save_as_mainfile(filepath=out, copy=True)
    print(f"[duo] saved {out}")


if __name__ == "__main__":
    main()
