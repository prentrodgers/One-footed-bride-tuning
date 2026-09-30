"""
concert_woods.py - procedural violin-family woods for Concert_Stage.blend.

Spruce top: fine growth-ring lines along the length (1.5-2 mm apart, wandering a little), under an
amber varnish whose colour varies across the plate. Maple back and sides: book-matched flame - the
stripes run across the back and chevron out from the centre joint (u = x + k|y|) - over a faint
straight grain. A satin coat and a whisper of bump from the grain. Object coordinates, so each
instrument's grain follows its own body (the viola's rig is the violin's scaled 1.15).

    import concert_woods; concert_woods.apply_all()
"""
import bpy


def _clear(m):
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    return nt, nt.nodes, nt.links


def _ramp(N, stops, x=0, y=0):
    r = N.new("ShaderNodeValToRGB"); r.location = (x, y)
    els = r.color_ramp.elements
    els[0].position, els[0].color = stops[0][0], tuple(stops[0][1]) + (1,)
    els[1].position, els[1].color = stops[-1][0], tuple(stops[-1][1]) + (1,)
    for pos, col in stops[1:-1]:
        e = els.new(pos); e.color = tuple(col) + (1,)
    return r


def _bsdf(N, L, color_socket, grain_socket, rough=0.48, coat=0.12):
    b = N.new("ShaderNodeBsdfPrincipled"); b.location = (900, 0)
    L.new(color_socket, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Specular IOR Level"].default_value = 0.25
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = 0.28
    bump = N.new("ShaderNodeBump"); bump.location = (700, -300)
    bump.inputs["Strength"].default_value = 0.25
    bump.inputs["Distance"].default_value = 0.0006
    L.new(grain_socket, bump.inputs["Height"])
    L.new(bump.outputs["Normal"], b.inputs["Normal"])
    out = N.new("ShaderNodeOutputMaterial"); out.location = (1150, 0)
    L.new(b.outputs["BSDF"], out.inputs["Surface"])
    return b


def spruce_top(name, varnish_light, varnish_dark, line):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    nt, N, L = _clear(m)
    tc = N.new("ShaderNodeTexCoord"); tc.location = (-900, 0)
    # growth rings: straight lines along the body (bands vary across Y), gently wandering
    # Growth rings: straight lines along the body (bands vary across Y) that wander a little. Spacing
    # ~2 mm at the centre joint (Scale 60 in these wave units), widening toward the edges as real
    # spruce tops do, with sharp dark "winter" lines. Too fine, and they average out to one colour.
    sep = N.new("ShaderNodeSeparateXYZ"); sep.location = (-900, 300)
    L.new(tc.outputs["Object"], sep.inputs[0])
    ay = N.new("ShaderNodeMath"); ay.operation = 'ABSOLUTE'; ay.location = (-760, 300)
    L.new(sep.outputs["Y"], ay.inputs[0])
    widen = N.new("ShaderNodeMath"); widen.operation = 'POWER'; widen.location = (-620, 300)   # |y|^0.8: rings wider outward
    L.new(ay.outputs[0], widen.inputs[0]); widen.inputs[1].default_value = 0.8
    comb = N.new("ShaderNodeCombineXYZ"); comb.location = (-480, 300)
    L.new(sep.outputs["X"], comb.inputs["X"]); L.new(widen.outputs[0], comb.inputs["Y"]); L.new(sep.outputs["Z"], comb.inputs["Z"])
    wave = N.new("ShaderNodeTexWave"); wave.location = (-600, 150)
    wave.wave_type = 'BANDS'; wave.bands_direction = 'Y'; wave.wave_profile = 'SAW'
    # Coarser than life (~5 mm) and high contrast: at stage-camera distance a pixel is 1-2 mm, and real
    # 2 mm rings average out into one flat colour - which is what read as "painted plastic".
    wave.inputs["Scale"].default_value = 26.0
    wave.inputs["Distortion"].default_value = 3.0
    wave.inputs["Detail"].default_value = 2.0
    wave.inputs["Detail Scale"].default_value = 0.5
    L.new(comb.outputs[0], wave.inputs["Vector"])
    rings = _ramp(N, [(0.0, (1, 1, 1)), (0.40, (0.85, 0.85, 0.85)), (0.72, (0.10, 0.10, 0.10)), (1.0, (0.30, 0.30, 0.30))], -350, 150)
    L.new(wave.outputs["Fac"], rings.inputs["Fac"])
    # varnish: uneven amber, lighter and darker patches across the plate
    noise = N.new("ShaderNodeTexNoise"); noise.location = (-600, -150)
    noise.inputs["Scale"].default_value = 5.0; noise.inputs["Detail"].default_value = 6.0; noise.inputs["Roughness"].default_value = 0.55
    L.new(tc.outputs["Object"], noise.inputs["Vector"])
    varnish = _ramp(N, [(0.30, varnish_dark), (0.70, varnish_light)], -350, -150)
    L.new(noise.outputs["Fac"], varnish.inputs["Fac"])
    mix = N.new("ShaderNodeMix"); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'; mix.location = (300, 50)
    mix.inputs["Factor"].default_value = 1.0
    L.new(varnish.outputs["Color"], mix.inputs[6])
    tint = N.new("ShaderNodeMix"); tint.data_type = 'RGBA'; tint.blend_type = 'MIX'; tint.location = (100, 150)
    tint.inputs[7].default_value = tuple(line) + (1,)                  # ring colour under the varnish
    inv = N.new("ShaderNodeInvert"); inv.location = (-100, 250)
    L.new(rings.outputs["Color"], inv.inputs["Color"])
    L.new(inv.outputs["Color"], tint.inputs["Factor"])
    tint.inputs[6].default_value = (1, 1, 1, 1)
    L.new(tint.outputs[2], mix.inputs[7])
    _bsdf(N, L, mix.outputs[2], wave.outputs["Fac"])
    m.diffuse_color = tuple(varnish_light) + (1,)
    return m


def flamed_maple(name, light, dark, varnish_tint):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    nt, N, L = _clear(m)
    tc = N.new("ShaderNodeTexCoord"); tc.location = (-1300, 0)
    sep = N.new("ShaderNodeSeparateXYZ"); sep.location = (-1100, 0)
    L.new(tc.outputs["Object"], sep.inputs[0])
    ay = N.new("ShaderNodeMath"); ay.operation = 'ABSOLUTE'; ay.location = (-900, -60)
    L.new(sep.outputs["Y"], ay.inputs[0])
    u = N.new("ShaderNodeMath"); u.operation = 'MULTIPLY_ADD'; u.location = (-720, 60)   # u = |y| * 0.45 + x
    L.new(ay.outputs[0], u.inputs[0]); u.inputs[1].default_value = 0.45; L.new(sep.outputs["X"], u.inputs[2])
    comb = N.new("ShaderNodeCombineXYZ"); comb.location = (-540, 60)
    L.new(u.outputs[0], comb.inputs["X"]); L.new(sep.outputs["Y"], comb.inputs["Y"]); L.new(sep.outputs["Z"], comb.inputs["Z"])
    # flame: stripes across the back, chevroned from the centre joint
    flame = N.new("ShaderNodeTexWave"); flame.location = (-340, 150)
    flame.wave_type = 'BANDS'; flame.bands_direction = 'X'; flame.wave_profile = 'SIN'
    flame.inputs["Scale"].default_value = 20.0          # ~15 mm flames
    flame.inputs["Distortion"].default_value = 4.0
    flame.inputs["Detail"].default_value = 2.5
    flame.inputs["Detail Scale"].default_value = 1.5
    L.new(comb.outputs[0], flame.inputs["Vector"])
    # faint straight grain along the length
    grain = N.new("ShaderNodeTexWave"); grain.location = (-340, -150)
    grain.wave_type = 'BANDS'; grain.bands_direction = 'Y'
    grain.inputs["Scale"].default_value = 300.0; grain.inputs["Distortion"].default_value = 2.0
    L.new(tc.outputs["Object"], grain.inputs["Vector"])
    fl = _ramp(N, [(0.10, dark), (0.50, light), (0.90, dark)], -100, 150)
    L.new(flame.outputs["Fac"], fl.inputs["Fac"])
    # the figure is strong in some places and fades out in others
    patch = N.new("ShaderNodeTexNoise"); patch.location = (-340, 380)
    patch.inputs["Scale"].default_value = 3.0; patch.inputs["Detail"].default_value = 2.0
    L.new(tc.outputs["Object"], patch.inputs["Vector"])
    pr = N.new("ShaderNodeMapRange"); pr.location = (-100, 380)
    pr.inputs["From Min"].default_value = 0.35; pr.inputs["From Max"].default_value = 0.65
    pr.inputs["To Min"].default_value = 0.65; pr.inputs["To Max"].default_value = 1.0
    L.new(patch.outputs["Fac"], pr.inputs["Value"])
    fig = N.new("ShaderNodeMix"); fig.data_type = 'RGBA'; fig.location = (60, 250)
    fig.inputs[6].default_value = tuple((a + b) / 2 for a, b in zip(light, dark)) + (1,)
    L.new(pr.outputs["Result"], fig.inputs["Factor"]); L.new(fl.outputs["Color"], fig.inputs[7])
    gm = N.new("ShaderNodeMix"); gm.data_type = 'RGBA'; gm.blend_type = 'MULTIPLY'; gm.location = (150, 50)
    gm.inputs["Factor"].default_value = 0.18
    L.new(fig.outputs[2], gm.inputs[6]); L.new(grain.outputs["Color"], gm.inputs[7])
    noise = N.new("ShaderNodeTexNoise"); noise.location = (-340, -380)
    noise.inputs["Scale"].default_value = 4.0; noise.inputs["Detail"].default_value = 5.0
    L.new(tc.outputs["Object"], noise.inputs["Vector"])
    var = _ramp(N, [(0.3, tuple(c * 0.8 for c in varnish_tint)), (0.7, varnish_tint)], -100, -380)
    L.new(noise.outputs["Fac"], var.inputs["Fac"])
    vm = N.new("ShaderNodeMix"); vm.data_type = 'RGBA'; vm.blend_type = 'MULTIPLY'; vm.location = (400, 50)
    vm.inputs["Factor"].default_value = 1.0
    L.new(gm.outputs[2], vm.inputs[6]); L.new(var.outputs["Color"], vm.inputs[7])
    _bsdf(N, L, vm.outputs[2], flame.outputs["Fac"], rough=0.40, coat=0.25)
    m.diffuse_color = tuple(light) + (1,)
    return m


def natural_wood(name, light, dark, line, axis='X', ring=12.0, rings_per=12.0, contrast=0.35, rough=0.45, coat=0.15):
    """Irregular grain: rings are the fractional part of a stretched noise field, so their spacing,
    curvature and direction wander the way real growth rings do - no symmetry, no repeat. Broad colour
    variation from a second noise; `contrast` sets how strongly the ring lines show."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    nt, N, L = _clear(m)
    tc = N.new("ShaderNodeTexCoord"); tc.location = (-1200, 0)
    mp = N.new("ShaderNodeMapping"); mp.location = (-1000, 0)
    mp.inputs["Scale"].default_value = {'X': (0.02, 1, 1), 'Y': (1, 0.02, 1), 'Z': (1, 1, 0.02)}[axis]
    mp.inputs["Location"].default_value = (0.37, 0.19, 0.53)          # off-centre: no mirror line down the middle
    L.new(tc.outputs["Object"], mp.inputs["Vector"])
    nz = N.new("ShaderNodeTexNoise"); nz.location = (-800, 150)
    nz.inputs["Scale"].default_value = ring; nz.inputs["Detail"].default_value = 1.0
    nz.inputs["Roughness"].default_value = 0.45; nz.inputs["Distortion"].default_value = 0.10
    L.new(mp.outputs["Vector"], nz.inputs["Vector"])
    mul = N.new("ShaderNodeMath"); mul.operation = 'MULTIPLY'; mul.location = (-600, 150); mul.inputs[1].default_value = rings_per
    L.new(nz.outputs["Fac"], mul.inputs[0])
    fr = N.new("ShaderNodeMath"); fr.operation = 'FRACT'; fr.location = (-450, 150)
    L.new(mul.outputs[0], fr.inputs[0])
    rl = _ramp(N, [(0.0, (1, 1, 1)), (0.70, (1, 1, 1)), (0.88, (0, 0, 0)), (1.0, (0.6, 0.6, 0.6))], -300, 150)
    L.new(fr.outputs[0], rl.inputs["Fac"])
    inv = N.new("ShaderNodeInvert"); inv.location = (-60, 200)
    L.new(rl.outputs["Color"], inv.inputs["Color"])
    k = N.new("ShaderNodeMath"); k.operation = 'MULTIPLY'; k.location = (80, 200); k.inputs[1].default_value = contrast
    L.new(inv.outputs["Color"], k.inputs[0])
    broad = N.new("ShaderNodeTexNoise"); broad.location = (-800, -200)
    broad.inputs["Scale"].default_value = 2.5; broad.inputs["Detail"].default_value = 4.0
    L.new(mp.outputs["Vector"], broad.inputs["Vector"])
    base = _ramp(N, [(0.3, dark), (0.7, light)], -450, -200)
    L.new(broad.outputs["Fac"], base.inputs["Fac"])
    mix = N.new("ShaderNodeMix"); mix.data_type = 'RGBA'; mix.location = (300, 50)
    mix.inputs[7].default_value = tuple(line) + (1,)
    L.new(k.outputs[0], mix.inputs["Factor"]); L.new(base.outputs["Color"], mix.inputs[6])
    b = _bsdf(N, L, mix.outputs[2], fr.outputs[0], rough=rough, coat=coat)
    bump = next(n for n in N if n.type == 'BUMP'); bump.inputs["Strength"].default_value = 0.05
    m.diffuse_color = tuple(light) + (1,)
    return m


def apply_all():
    # violin (and cello, which shares these): classic golden-orange-brown varnish
    # (linear colour values: sRGB (0.45, 0.20, 0.07), a typical golden-brown varnish, is (0.17, 0.033, 0.006))
    # tops (violin and cello share one; viola darker): irregular, soft growth lines under the varnish
    natural_wood("Violin Varnish Spruce", (0.30, 0.11, 0.028), (0.22, 0.075, 0.018), (0.10, 0.032, 0.008),
                 axis='X', ring=14.0, rings_per=10.0, contrast=0.68, rough=0.45, coat=0.15)
    natural_wood("Viola Varnish Spruce", (0.20, 0.060, 0.016), (0.14, 0.040, 0.010), (0.06, 0.016, 0.004),
                 axis='X', ring=14.0, rings_per=10.0, contrast=0.68, rough=0.45, coat=0.15)
    flamed_maple("Flamed Maple Varnish", (0.38, 0.14, 0.035), (0.12, 0.035, 0.008), (1.0, 0.85, 0.66))
    flamed_maple("Viola Flamed Maple", (0.28, 0.08, 0.022), (0.09, 0.024, 0.006), (0.95, 0.72, 0.58))
    # finger piano boards
    natural_wood("Acacia Koa", (0.50, 0.26, 0.11), (0.38, 0.18, 0.07), (0.22, 0.09, 0.03),
                 axis='X', ring=10.0, rings_per=10.0, contrast=0.72, rough=0.35, coat=0.5)
    natural_wood("Mukwa (African Teak)", (0.30, 0.13, 0.05), (0.22, 0.09, 0.035), (0.12, 0.045, 0.015),
                 axis='Y', ring=6.0, rings_per=10.0, contrast=0.72, rough=0.45, coat=0.2)
