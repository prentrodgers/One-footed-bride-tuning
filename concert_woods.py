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
    bump.inputs["Strength"].default_value = 0.06
    bump.inputs["Distance"].default_value = 0.0004
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
    wave = N.new("ShaderNodeTexWave"); wave.location = (-600, 150)
    wave.wave_type = 'BANDS'; wave.bands_direction = 'Y'; wave.wave_profile = 'SIN'
    wave.inputs["Scale"].default_value = 175.0          # ~1.8 mm between rings
    wave.inputs["Distortion"].default_value = 1.6
    wave.inputs["Detail"].default_value = 3.0
    wave.inputs["Detail Scale"].default_value = 0.6
    L.new(tc.outputs["Object"], wave.inputs["Vector"])
    rings = _ramp(N, [(0.0, (1, 1, 1)), (0.72, (1, 1, 1)), (0.88, (0.35, 0.35, 0.35)), (1.0, (0.55, 0.55, 0.55))], -350, 150)
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
    pr.inputs["To Min"].default_value = 0.25; pr.inputs["To Max"].default_value = 1.0
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


def apply_all():
    # violin (and cello, which shares these): classic golden-orange-brown varnish
    # (linear colour values: sRGB (0.45, 0.20, 0.07), a typical golden-brown varnish, is (0.17, 0.033, 0.006))
    spruce_top("Violin Varnish Spruce", (0.17, 0.048, 0.011), (0.095, 0.024, 0.005), (0.05, 0.012, 0.003))
    flamed_maple("Flamed Maple Varnish", (0.27, 0.085, 0.020), (0.07, 0.018, 0.004), (1.0, 0.85, 0.66))
    # viola: darker, redder brown so the two are told apart at a glance
    spruce_top("Viola Varnish Spruce", (0.105, 0.026, 0.007), (0.055, 0.013, 0.003), (0.03, 0.007, 0.002))
    flamed_maple("Viola Flamed Maple", (0.18, 0.047, 0.013), (0.045, 0.011, 0.003), (0.95, 0.72, 0.58))
