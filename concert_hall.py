"""
concert_hall.py - the house of the Teatro Municipal Buero Vallejo (Alcorcón, Madrid) built around the
stage of Concert_Stage.blend, so the piano videos play in the room whose impulse response they are
convolved with (ball9c.csd: Angelo Farina's measurement; he also designed the hall's acoustic correction).

    blender --background Concert_Stage.blend --python concert_hall.py -- --out Alcorcon_Hall.blend
    blender --background Concert_Stage.blend --python concert_hall.py -- --out Alcorcon_Hall.blend \
        --preview /tmp/hall_stills            # also renders a still from each hall camera

Concert_Stage.blend itself is not changed. What is known of the hall (the 1994 building, the 1999
acoustic correction, Envés arquitectos' 2012 renovation photos and plans, es.wikipedia):

  * a proscenium house "a la italiana": 912 seats in the stalls (patio de butacas), the amphitheatre
    (anfiteatro) above the back of the stalls, and the gallery (paraíso) above that;
  * the building is red brick with semicircular brick arches; the 1999 work was needed because the
    ceiling was too high and the brick around the stalls swallowed the sound, so reflectors hang over
    the stalls and the lower walls are panelled;
  * the 2012 seats shade from blue-grey at the front through taupe to red at the back; the curtain is
    garnet ("telón de color granate"); ten lighting battens over the stage.

Coordinates as in the stage: the audience looks along +y, +x is their right, the stage deck's top is
z 0 and its lip is at y -4.5. The house sits in front of it, y -4.5 .. -32, x +-11.5, floor -1 at the
front rising with the rake. Everything goes in the "Hall" collection; the rig gets a "house" group of
dim warm lights on the "Stage Controls" dimmers (house x master), so concert_lighting's looks dim the
room along with the stage.
"""
import argparse
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

REPO_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(REPO_DIR))
import concert_stagekit as sk        # noqa: E402
import concert_cameras as cc         # noqa: E402

# ─────────────────────────────── the room ───────────────────────────────
HALF_W = 11.5            # half the hall's width
Y_LIP = -4.5             # the stage lip; the proscenium wall is y -5.0 .. -4.5
Y_BACK = -32.0           # the rear wall
Z_FLOOR = -1.0           # stalls floor at the front (the deck is 1 m up)
Z_CEIL = 12.5            # the (too high) ceiling
RAKE_FROM, RAKE_TO, RAKE_RISE = -6.5, -27.5, 2.6     # the stalls floor climbs 2.6 m over the rake
PROSC_HALF_W, PROSC_H = 7.5, 8.0                      # the opening: x +-7.5, z -1 .. 8

SEAT_PITCH, ROW_PITCH = 0.55, 0.92
STALLS_ROWS, STALLS_PER_SIDE = 24, 12                # 576, two blocks either side of the centre aisle
CROSS_AISLE_AFTER, CROSS_AISLE = 9, 1.6              # a cross aisle for the side doors
AMPH = dict(front=-19.5, rows=8, per_side=12, z0=5.2, rise=0.42, first=-20.6)   # 192, over the back stalls
PARA = dict(front=-25.5, rows=6, per_side=12, z0=9.2, rise=0.42, first=-26.6)   # 144, over the amphitheatre
# 576 + 192 + 144 = 912

ARCH_YS = (-9.5, -15.5, -21.5)       # the three arches each side
ARCH_Z, ARCH_R = 7.6, 2.3            # springing line and radius
DADO_H = 4.5                         # the panelled lower wall

SEAT_FRONT = (0.30, 0.34, 0.44)      # blue-grey
SEAT_MID = (0.56, 0.50, 0.40)        # taupe
SEAT_BACK = (0.72, 0.12, 0.10)       # red
BANDS = 7

HALL_CAMS = {                        # name -> (location, target, lens)
    "Cam 57 Hall Amphitheatre": ((0.0, -22.5, 7.7), (0.0, 0.5, 1.0), 28),
    "Cam 58 House from the Stage": ((0.0, 3.0, 2.2), (0.0, -18.0, 4.0), 22),
    "Cam 59 Hall Side Arch": ((-9.6, -12.5, 4.8), (0.0, 0.5, 1.2), 32),
}


def stalls_z(y):
    """Floor height of the stalls at y."""
    if y >= RAKE_FROM:
        return Z_FLOOR
    return Z_FLOOR + min(1.0, (RAKE_FROM - y) / (RAKE_FROM - RAKE_TO)) * RAKE_RISE


# ─────────────────────────────── materials ───────────────────────────────
def brick(name, facing):
    """Brick on a wall whose normal is along `facing` ('x' or 'y'): the brick texture is laid in the
    wall's own plane (object coordinates), 24 cm courses of 6.5 cm."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = sk.mat(name, (0.52, 0.22, 0.15), rough=0.85)
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    b = N["Principled BSDF"]
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ")
    com = N.new("ShaderNodeCombineXYZ")
    L.new(tc.outputs["Object"], sep.inputs["Vector"])
    along = "Y" if facing == "x" else "X"
    L.new(sep.outputs[along], com.inputs["X"])
    L.new(sep.outputs["Z"], com.inputs["Y"])
    bt = N.new("ShaderNodeTexBrick")
    bt.inputs["Scale"].default_value = 2.1
    bt.inputs["Mortar Size"].default_value = 0.012
    bt.inputs["Mortar Smooth"].default_value = 0.2
    bt.inputs["Bias"].default_value = 0.0
    bt.inputs["Brick Width"].default_value = 0.5
    bt.inputs["Row Height"].default_value = 0.14
    bt.inputs["Color1"].default_value = (0.50, 0.21, 0.14, 1)
    bt.inputs["Color2"].default_value = (0.42, 0.17, 0.12, 1)
    bt.inputs["Mortar"].default_value = (0.55, 0.50, 0.44, 1)
    L.new(com.outputs["Vector"], bt.inputs["Vector"])
    L.new(bt.outputs["Color"], b.inputs["Base Color"])
    return m


def materials():
    M = {
        "brick_x": brick("Hall Brick (side walls)", "x"),
        "brick_y": brick("Hall Brick (end walls)", "y"),
        "dado": sk.wood("Hall Dado Oak", (0.46, 0.30, 0.16), (0.36, 0.22, 0.11), scale=30, rough=0.45,
                        coat=0.15, axis='Z'),
        "carpet": sk.mat("Hall Carpet", (0.10, 0.07, 0.08), rough=0.95),
        "ceiling": sk.mat("Hall Ceiling", (0.05, 0.05, 0.06), rough=0.9),
        "plaster": sk.mat("Hall Plaster", (0.86, 0.84, 0.80), rough=0.7),
        "parapet": sk.mat("Hall Parapet", (0.80, 0.78, 0.74), rough=0.6),
        "rail": sk.wood("Hall Rail Oak", (0.40, 0.25, 0.12), (0.30, 0.18, 0.09), scale=24, rough=0.35,
                        coat=0.4, axis='X'),
        "frame": sk.mat("Hall Proscenium Frame", (0.03, 0.03, 0.03), rough=0.8),
        "velvet": sk.mat("Hall Curtain Garnet", (0.33, 0.03, 0.06), rough=0.95, spec=0.2),
        "arch_glow": sk.mat("Hall Arch Glow", (0.90, 0.72, 0.50), rough=0.9, emit=(1.0, 0.75, 0.45),
                            emit_strength=0.35),
        "reflector": sk.mat("Hall Reflector", (0.92, 0.92, 0.90), rough=0.5),
        "seat_frame": sk.mat("Hall Seat Frame", (0.08, 0.08, 0.09), rough=0.6),
        "exit": sk.mat("Hall Exit Sign", (0.1, 0.9, 0.3), emit=(0.2, 1.0, 0.4), emit_strength=4.0),
        "stage_black": sk.mat("Hall Stage Black", (0.015, 0.015, 0.015), rough=0.95),
    }
    for i in range(BANDS):
        t = i / (BANDS - 1)
        c = [SEAT_FRONT[k] + (SEAT_MID[k] - SEAT_FRONT[k]) * t * 2 for k in range(3)] if t < 0.5 else \
            [SEAT_MID[k] + (SEAT_BACK[k] - SEAT_MID[k]) * (t - 0.5) * 2 for k in range(3)]
        M[f"seat{i}"] = sk.mat(f"Hall Seat {i}", c, rough=0.9, spec=0.25)
    return M


# ─────────────────────────────── geometry ───────────────────────────────
def slab(name, profile, x0, x1, mat_, collection, flip=False):
    """A YZ profile (list of (y, z), counter-clockwise seen from +x) extruded from x0 to x1."""
    bm = bmesh.new()
    a = [bm.verts.new((x0, y, z)) for y, z in profile]
    b = [bm.verts.new((x1, y, z)) for y, z in profile]
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    n = len(profile)
    for i in range(n):
        bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    bm.normal_update()
    if flip:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    return sk.mesh_obj(name, bm, mats=[mat_], collection=collection)


def arch_outline(cy, z0, zt, r, n=24):
    """(y, z) outline of a round-headed arch: a rectangle from z0 up to the springing zt, a semicircle above."""
    pts = [(cy - r, z0), (cy + r, z0)]
    for k in range(n + 1):
        a = math.pi * k / n
        pts.append((cy + r * math.cos(a), zt + r * math.sin(a)))
    return pts


def floors(M, C):
    """The stalls floor (flat forecourt, then the rake), the two balcony slabs and the rear wall."""
    y_top = RAKE_TO
    prof = [(Y_LIP - 0.5, Z_FLOOR), (RAKE_FROM, Z_FLOOR), (y_top, stalls_z(y_top)), (Y_BACK, stalls_z(y_top)),
            (Y_BACK, Z_FLOOR - 2.0), (Y_LIP - 0.5, Z_FLOOR - 2.0)]
    slab("Hall Stalls Floor", prof, -HALF_W, HALF_W, M["carpet"], C)
    for key, lvl in (("Amphitheatre", AMPH), ("Gallery", PARA)):
        y0, z0 = lvl["front"], lvl["z0"]
        prof = [(y0, z0 - 0.6), (y0, z0)]
        y, z = y0, z0
        for r in range(lvl["rows"]):          # steps, one per row
            y1 = lvl["first"] - (r + 0.5) * ROW_PITCH - ROW_PITCH / 2
            prof += [(y1, z), (y1, z + lvl["rise"])]
            y, z = y1, z + lvl["rise"]
        prof += [(Y_BACK, z), (Y_BACK, z0 - 0.6)]
        slab(f"Hall {key} Floor", prof, -HALF_W, HALF_W, M["carpet"], C)
        # the parapet with a rail
        sk.box(f"Hall {key} Parapet", (2 * HALF_W, 0.35, 1.05), (0, y0 + 0.15, z0 + 0.52), mat_=M["parapet"],
               collection=C)
        sk.box(f"Hall {key} Rail", (2 * HALF_W, 0.45, 0.06), (0, y0 + 0.15, z0 + 1.07), mat_=M["rail"],
               collection=C)
        # the underside is the ceiling of the level below
        sk.box(f"Hall {key} Soffit", (2 * HALF_W, Y_BACK - y0, 0.05), (0, (y0 + Y_BACK) / 2, z0 - 0.62),
               mat_=M["ceiling"], collection=C)
    sk.box("Hall Rear Wall", (2 * HALF_W + 1, 0.5, Z_CEIL - Z_FLOOR + 3), (0, Y_BACK - 0.25, (Z_CEIL + Z_FLOOR - 3) / 2),
           mat_=M["brick_y"], collection=C)
    sk.box("Hall Ceiling", (2 * HALF_W + 1, Y_LIP - Y_BACK + 1, 0.3), (0, (Y_LIP + Y_BACK) / 2, Z_CEIL + 0.15),
           mat_=M["ceiling"], collection=C)


def side_walls(M, C):
    length = Y_LIP - Y_BACK
    for s, side in ((-1, "Left"), (1, "Right")):
        x = s * HALF_W
        sk.box(f"Hall Side Wall {side}", (0.5, length, Z_CEIL - Z_FLOOR + 3), (x + s * 0.25, (Y_LIP + Y_BACK) / 2,
               (Z_CEIL + Z_FLOOR - 3) / 2), mat_=M["brick_x"], collection=C)
        # the panelled dado, proud of the brick, following the rake
        prof = [(Y_LIP, Z_FLOOR - 1.5), (Y_LIP, Z_FLOOR + DADO_H), (RAKE_FROM, Z_FLOOR + DADO_H),
                (RAKE_TO, stalls_z(RAKE_TO) + DADO_H), (Y_BACK, stalls_z(RAKE_TO) + DADO_H), (Y_BACK, Z_FLOOR - 1.5)]
        slab(f"Hall Dado {side}", prof, x - s * 0.08 - 0.04, x - s * 0.08 + 0.04, M["dado"], C)
        # three lit brick arches above the dado
        for k, cy in enumerate(ARCH_YS):
            ol = arch_outline(cy, ARCH_Z - 1.8, ARCH_Z, ARCH_R)
            ring = arch_outline(cy, ARCH_Z - 1.8, ARCH_Z, ARCH_R + 0.35)
            bm = bmesh.new()
            inner = [bm.verts.new((0, y, z)) for y, z in ol]
            outer = [bm.verts.new((0, y, z)) for y, z in ring]
            n = len(ol)
            for i in range(n - 1):
                bm.faces.new((inner[i], outer[i], outer[i + 1], inner[i + 1]))
            bm.faces.new((inner[-1], outer[-1], outer[0], inner[0]))
            geom = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
            verts = [e for e in geom["geom"] if isinstance(e, bmesh.types.BMVert)]
            bmesh.ops.translate(bm, vec=(-s * 0.22, 0, 0), verts=verts)
            bm.normal_update()
            frame = sk.mesh_obj(f"Hall Arch {side} {k + 1}", bm, loc=(x, 0, 0), mats=[M["brick_x"]], collection=C)
            frame.scale.x = 1.0
            bm = bmesh.new()
            face = bm.faces.new([bm.verts.new((0, y, z)) for y, z in ol])
            geom = bmesh.ops.extrude_face_region(bm, geom=[face])
            verts = [e for e in geom["geom"] if isinstance(e, bmesh.types.BMVert)]
            bmesh.ops.translate(bm, vec=(-s * 0.06, 0, 0), verts=verts)
            bm.normal_update()
            sk.mesh_obj(f"Hall Arch Panel {side} {k + 1}", bm, loc=(x - s * 0.02, 0, 0), mats=[M["arch_glow"]],
                        collection=C)
        # exit sign by the side door near the stage
        sk.box(f"Hall Exit Sign {side}", (0.05, 0.4, 0.18), (x - s * 0.1, -7.5, Z_FLOOR + 2.4), mat_=M["exit"],
               collection=C)


def proscenium(M, C):
    y = Y_LIP - 0.25
    h_pier = Z_CEIL - Z_FLOOR + 3
    for s in (-1, 1):
        w = HALF_W - PROSC_HALF_W
        sk.box(f"Hall Proscenium Pier {'L' if s < 0 else 'R'}", (w + 0.5, 0.5, h_pier),
               (s * (PROSC_HALF_W + w / 2 + 0.25), y, (Z_CEIL + Z_FLOOR - 3) / 2), mat_=M["brick_y"], collection=C)
    sk.box("Hall Proscenium Header", (2 * PROSC_HALF_W, 0.5, Z_CEIL - PROSC_H + 0.3),
           (0, y, (Z_CEIL + PROSC_H) / 2 + 0.15), mat_=M["brick_y"], collection=C)
    # the black frame of the opening, proud of the brick on the house side
    t = 0.45
    for s in (-1, 1):
        sk.box(f"Hall Proscenium Frame {'L' if s < 0 else 'R'}", (t, 0.3, PROSC_H - Z_FLOOR + t),
               (s * (PROSC_HALF_W + t / 2), Y_LIP - 0.6, (PROSC_H + Z_FLOOR + t) / 2), mat_=M["frame"], collection=C)
    sk.box("Hall Proscenium Frame Top", (2 * PROSC_HALF_W + 2 * t, 0.3, t), (0, Y_LIP - 0.6, PROSC_H + t / 2),
           mat_=M["frame"], collection=C)
    # the garnet curtain, tied open: a leg each side and the valance, in soft folds
    B = sk.Builder()
    for s in (-1, 1):
        x0 = s * (PROSC_HALF_W - 1.1)
        for k in range(7):
            x = x0 - s * 0.16 * (k - 3)
            B.cyl((x, Y_LIP + 0.45 + 0.05 * (k % 2), Z_FLOOR + 0.05), (x, Y_LIP + 0.45 + 0.05 * (k % 2), PROSC_H),
                  0.17, seg=14)
    n = int(2 * PROSC_HALF_W / 0.3)
    for k in range(n + 1):
        x = -PROSC_HALF_W + 0.3 * k
        B.cyl((x, Y_LIP + 0.45 + 0.04 * (k % 2), PROSC_H - 1.3), (x, Y_LIP + 0.45 + 0.04 * (k % 2), PROSC_H + 0.2),
              0.17, seg=14)
    B.build("Hall Curtain", [M["velvet"]], collection=C, smooth=True)
    # the stage house: black walls and a ceiling behind the proscenium, so nothing looks out into the void
    sk.box("Hall Stage Ceiling", (22, 12, 0.3), (0, 1.0, 9.6), mat_=M["stage_black"], collection=C)
    for s in (-1, 1):
        sk.box(f"Hall Stage Wall {'L' if s < 0 else 'R'}", (0.3, 12, 11), (s * 10.5, 1.0, 4.5), mat_=M["stage_black"],
               collection=C)


def reflectors(M, C):
    """The acoustic correction: white panels hung over the stalls, tilted toward the stage."""
    B = sk.Builder()
    for j, y in enumerate((-8.0, -12.0, -16.0)):
        for x in (-8.0, -4.0, 0.0, 4.0, 8.0):
            rot = Matrix.Rotation(math.radians(14), 4, 'X')
            B.box((x, y, Z_CEIL - 2.0 - 0.3 * j), (3.4, 2.2, 0.08), rot=rot)
            B.cyl((x - 1.4, y, Z_CEIL - 2.0 - 0.3 * j), (x - 1.4, y, Z_CEIL), 0.012, seg=6)
            B.cyl((x + 1.4, y, Z_CEIL - 2.0 - 0.3 * j), (x + 1.4, y, Z_CEIL), 0.012, seg=6)
    B.build("Hall Reflectors", [M["reflector"]], collection=C)


def seats(M, C):
    """912 seats in three levels, each level shading front to back from blue-grey through taupe to red,
    one mesh per colour band (a seat is a cushion, a back, two arms and a pedestal)."""
    levels = []
    stalls = []
    for r in range(STALLS_ROWS):
        y = -7.0 - r * ROW_PITCH - (CROSS_AISLE if r >= CROSS_AISLE_AFTER else 0.0)
        stalls.append((y, stalls_z(y), r / (STALLS_ROWS - 1), STALLS_PER_SIDE, 0.6 if r % 2 else 0.0))
    levels.append(stalls)
    for lvl in (AMPH, PARA):
        rows = []
        for r in range(lvl["rows"]):
            rows.append((lvl["first"] - r * ROW_PITCH, lvl["z0"] + r * lvl["rise"], r / max(1, lvl["rows"] - 1),
                         lvl["per_side"], 0.6 if r % 2 else 0.0))
        levels.append(rows)
    builders = [sk.Builder() for _ in range(BANDS)]
    count = 0
    back_rot = Matrix.Rotation(math.radians(10), 4, 'X')        # the back leans away from the stage
    for rows in levels:
        for y, z, t, per_side, stagger in rows:
            band = min(BANDS - 1, int(t * BANDS))
            B = builders[band]
            for s in (-1, 1):
                for k in range(per_side):
                    x = s * (0.85 + k * SEAT_PITCH + SEAT_PITCH / 2) + (stagger * SEAT_PITCH * 0.5 if s > 0 else -stagger * SEAT_PITCH * 0.5)
                    # the sitter faces the stage (+y), so the back is on the -y side, behind them
                    B.box((x, y, z + 0.44), (0.48, 0.46, 0.10), mi=0)
                    B.box((x, y - 0.24, z + 0.76), (0.48, 0.07, 0.62), mi=0, rot=back_rot)
                    for a in (-1, 1):
                        B.box((x + a * 0.255, y - 0.02, z + 0.62), (0.05, 0.42, 0.04), mi=1)
                    B.box((x, y - 0.05, z + 0.2), (0.10, 0.10, 0.40), mi=1)
                    count += 1
    for i, B in enumerate(builders):
        B.build(f"Hall Seats {i}", [M[f"seat{i}"], M["seat_frame"]], collection=C)
    return count


def house_lights():
    """Dim warm light in the arches and under the balconies: the house at show level. Group "house"."""
    ctrl = bpy.data.objects["Stage Controls"]
    if "house" not in ctrl:
        ctrl["house"] = 1.0
        ctrl.id_properties_ui("house").update(min=0.0, max=2.0, soft_min=0.0, soft_max=2.0,
                                              description="House lights (the arches and the balconies)")
    lights = []
    for s, side in ((-1, "Left"), (1, "Right")):
        for k, cy in enumerate(ARCH_YS):
            lights.append(sk.stage_light(f"House Arch {side} {k + 1}", 'AREA', (s * (HALF_W - 0.5), cy, ARCH_Z + 0.4),
                                         (s * 2.0, cy, Z_FLOOR + 0.5), (1.0, 0.78, 0.55), 320, "house", fixture=False))
    for key, lvl in (("Amphitheatre", AMPH), ("Gallery", PARA)):
        for x in (-6.0, 6.0):
            lights.append(sk.stage_light(f"House Soffit {key} {'L' if x < 0 else 'R'}", 'AREA', (x, lvl["front"] - 4.0,
                                         lvl["z0"] - 0.75), (x, lvl["front"] - 4.0, lvl["z0"] - 4.0),
                                         (1.0, 0.85, 0.65), 180, "house", fixture=False))
    for x in (-5.0, 5.0):                   # a soft wash over the stalls from above the reflectors
        lights.append(sk.stage_light(f"House Stalls {'L' if x < 0 else 'R'}", 'AREA', (x, -13.0, Z_CEIL - 0.3),
                                     (x, -14.0, Z_FLOOR), (1.0, 0.85, 0.68), 400, "house", fixture=False))
    for ob in lights:
        ob.data.size = 1.2
    lights[-1].data.size = lights[-2].data.size = 6.0
    return lights


def cameras():
    for name, (loc, tgt, lens) in HALL_CAMS.items():
        cam, t = cc._camera(name, lens)
        cam.location, t.location = loc, tgt


def build():
    hall = sk.coll("Hall", bpy.data.collections.get("Concert Stage Set"))
    M = materials()
    floors(M, hall)
    side_walls(M, hall)
    proscenium(M, hall)
    reflectors(M, hall)
    n = seats(M, hall)
    lights = house_lights()
    cameras()
    print(f"[hall] {n} seats, {len(lights)} house lights, {len(hall.objects)} objects in the Hall collection")
    return hall


def preview(out_dir, cams, samples=32, res=(1280, 720)):
    """A still from each camera, EEVEE, to look the room over."""
    sc = sk.scene()
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.engine = 'BLENDER_EEVEE'
    sc.eevee.taa_render_samples = samples
    sc.render.image_settings.file_format = 'PNG'
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    for name in cams:
        sc.camera = bpy.data.objects[name]
        sc.render.filepath = str(out_dir / (name.split(" ")[1] + ".png"))
        bpy.ops.render.render(write_still=True)
        print(f"[hall] wrote {sc.render.filepath}")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--out", default="Alcorcon_Hall.blend")
    p.add_argument("--preview", default=None, help="directory for a still from each hall camera")
    p.add_argument("--preview-cams", default="Cam 1 Audience Wide,Cam 57 Hall Amphitheatre,"
                   "Cam 58 House from the Stage,Cam 59 Hall Side Arch")
    p.add_argument("--samples", type=int, default=32)
    args = p.parse_args(argv)
    build()
    bpy.context.view_layer.update()
    out = str((REPO_DIR / args.out).resolve()) if not Path(args.out).is_absolute() else args.out
    bpy.ops.wm.save_as_mainfile(filepath=out, copy=True)
    print(f"[hall] saved {out}")
    if args.preview:
        preview(args.preview, args.preview_cams.split(","), samples=args.samples)


if __name__ == "__main__":
    main()
