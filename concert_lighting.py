"""
concert_lighting.py - the lighting plan: how the stage light changes over the course of a piece.

The rig's lights are driven (base watts x level x group x master, from the "Stage Controls" empty), and the
backdrop's glow follows master x backdrop. The plan sets the master, the four group levels (front wash,
specials, rim, footlights), the backdrop level and each group's colour from moment to moment, the way the
backdrop's hue already drifts: a new LOOK roughly every minute, cross-fading over FADE seconds. After the
opening title the stage drops dark (players in their specials under a deep blue) and grows through the
first minute; then colour looks follow, and the title cards have their own soft look. Nothing is as bright
as the rig at full (everything at 1), which read as overexposed.

Performance.apply calls LightingPlan.apply(t) every frame; restore() puts the rig back at full and white
before the .blend is saved.
"""
import bpy

FADE = 8.0                  # seconds to cross-fade from one look to the next
LOOK_SECONDS = 60.0         # a new look about this often
GROUPS = ("front_wash", "specials", "rim", "footlights", "backdrop")
PREFIX = {"front_wash": "Front Wash", "rim": "Rim ", "footlights": "Footlight", "specials": "Special "}
# the rig's own colours, for restore()
BASE_COLOUR = {"front_wash": (1.0, 0.90, 0.78), "rim": (1.0, 0.55, 0.12), "footlights": (1.0, 0.82, 0.62),
               "specials": (1.0, 0.95, 0.85)}

# name: levels (master, front wash, specials, rim, footlights, backdrop) and colours (front wash, rim, footlights).
# The specials stay near white, tinted a fifth of the way toward the front wash.
LOOKS = {
    "title":     ((0.55, 0.50, 0.60, 0.60, 0.40, 0.80), ((1.0, 0.88, 0.74), (1.0, 0.55, 0.15), (1.0, 0.80, 0.60))),
    "dark":      ((0.38, 0.12, 0.85, 0.45, 0.00, 0.30), ((0.35, 0.45, 1.00), (0.40, 0.30, 1.00), (0.40, 0.40, 1.00))),
    "rise":      ((0.70, 0.62, 0.90, 0.80, 0.50, 0.80), ((1.0, 0.86, 0.70), (1.0, 0.55, 0.15), (1.0, 0.80, 0.60))),
    "amber":     ((0.72, 0.70, 0.80, 1.00, 0.55, 0.85), ((1.0, 0.78, 0.50), (1.0, 0.42, 0.06), (1.0, 0.70, 0.40))),
    "blue":      ((0.62, 0.55, 0.90, 1.00, 0.30, 0.70), ((0.62, 0.72, 1.00), (0.20, 0.40, 1.00), (0.55, 0.65, 1.00))),
    "full":      ((0.82, 0.85, 0.90, 0.90, 0.75, 1.00), ((1.0, 0.92, 0.82), (1.0, 0.60, 0.20), (1.0, 0.84, 0.66))),
    "magenta":   ((0.64, 0.45, 0.90, 1.00, 0.40, 0.80), ((1.0, 0.70, 0.90), (0.90, 0.20, 0.70), (1.0, 0.60, 0.85))),
    "low_warm":  ((0.46, 0.30, 0.85, 0.70, 0.20, 0.50), ((1.0, 0.70, 0.45), (1.0, 0.35, 0.10), (1.0, 0.65, 0.40))),
    "teal":      ((0.62, 0.50, 0.85, 0.90, 0.30, 0.70), ((0.70, 1.00, 0.95), (0.10, 0.80, 0.70), (0.60, 0.95, 0.90))),
}
# after the first minute (dark, growing to "rise"), one look a minute in this order, repeating; the last
# minute of the music always "full"
SEQUENCE = ("amber", "blue", "full", "magenta", "low_warm", "teal")


def _lerp(a, b, u):
    return tuple(x + (y - x) * u for x, y in zip(a, b))


def _mix(look_a, look_b, u):
    la, ca = LOOKS[look_a]; lb, cb = LOOKS[look_b]
    return _lerp(la, lb, u), tuple(_lerp(x, y, u) for x, y in zip(ca, cb))


class LightingPlan:
    """The looks over one piece: video times, the music from `lead` to `lead + duration`."""

    def __init__(self, duration, lead=0.0, tail=0.0):
        self.lead, self.end_music, self.end = lead, lead + duration, lead + duration + tail
        # (start, look): the music's first look grows from "dark" to "rise" over its whole first minute
        first = min(LOOK_SECONDS, duration / 3)
        self.keys = [(lead + first, "rise")]
        t, i = lead + first, 0
        while t + LOOK_SECONDS < self.end_music - LOOK_SECONDS * 0.5:
            t += LOOK_SECONDS
            self.keys.append((t, SEQUENCE[i % len(SEQUENCE)])); i += 1
        if self.end_music - lead > 2 * LOOK_SECONDS:
            self.keys.append((max(t + LOOK_SECONDS * 0.5, self.end_music - LOOK_SECONDS), "full"))
        ctrl = bpy.data.objects["Stage Controls"]
        self.ctrl = ctrl
        self.lights = {g: [o for o in bpy.data.objects if o.type == 'LIGHT' and o.name.startswith(p)]
                       for g, p in PREFIX.items()}

    def state(self, t):
        """(levels, colours) at video time t."""
        if t < self.lead or t >= self.end_music:            # the title cards
            if t < self.lead:                                # into the dark look as the opening title fades
                u = max(0.0, (t - (self.lead - 1.0)) / 1.0)
                return _mix("title", "dark", u)
            u = min(1.0, (t - self.end_music) / 2.0)
            return _mix(self.keys[-1][1] if self.keys else "rise", "title", u)
        first_end, first_look = self.keys[0]
        if t < first_end:                                    # the first minute: dark, slowly growing
            u = (t - self.lead) / max(1e-6, first_end - self.lead)
            return _mix("dark", first_look, u * u * (3 - 2 * u))
        cur, prev = first_look, None
        for k, (t0, look) in enumerate(self.keys):
            if t >= t0:
                cur, prev, start = look, (self.keys[k - 1][1] if k else first_look), t0
        u = min(1.0, (t - start) / FADE) if prev else 1.0
        return _mix(prev or cur, cur, u * u * (3 - 2 * u))

    def apply(self, t):
        levels, colours = self.state(t)
        master, *grp = levels
        self.ctrl["master"] = master
        for g, v in zip(GROUPS, grp):
            self.ctrl[g] = v
        front, rim, foot = colours
        special = _lerp((1.0, 0.95, 0.88), front, 0.2)
        for g, c in (("front_wash", front), ("rim", rim), ("footlights", foot), ("specials", special)):
            for o in self.lights[g]:
                o.data.color = c

    def restore(self):
        self.ctrl["master"] = 1.0
        for g in GROUPS:
            self.ctrl[g] = 1.0
        for g, c in BASE_COLOUR.items():
            for o in self.lights[g]:
                o.data.color = c

    def describe(self):
        return ", ".join(f"{int(t0 // 60)}:{t0 % 60:04.1f} {look}" for t0, look in [(self.lead, "dark")] + self.keys)
