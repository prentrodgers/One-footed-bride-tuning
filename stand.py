#!/usr/bin/env python3
"""
stand.py — shared 3-D stand (a rectangular platform on 2x2 caster-wheeled
legs) drawn beneath the consolidated single-instrument sections (marimba,
finger piano, ...).

The platform is a proper connected box: a near (front) edge and a far
(back) edge — offset from each other along the same oblique depth
direction the instruments themselves use (marimba_poc.BACK_DX/.BACK_DY) —
joined by a top surface and two end walls, so it reads as one solid
rectangular stand rather than two floating rails. The instrument's own
tines/bars sit at the *middle* of that depth span (mid_y, half way between
near and far), so they visually emerge from the middle of the stand's top
surface instead of hanging off its front edge. The near legs are longer
than the far ones, and the far edge/legs are dimmed a touch — together
giving a 3-D "receding" look consistent with the instruments' own
perspective. Purely static (no per-frame animation); callers add it once
and get back the lowest y reached (for label placement below it).
"""
from matplotlib.patches import Rectangle, Circle, Polygon

import marimba_poc as mp

CLR      = (0.35, 0.35, 0.38)
CLR_DK   = (0.18, 0.18, 0.20)
CLR_TOP  = (0.42, 0.42, 0.45)   # top surface — a touch lighter, catches the light
WHEEL_CLR     = (0.12, 0.12, 0.13)
WHEEL_HIGHLIGHT_CLR = (0.55, 0.55, 0.58)


def _add_leg(ax, lx, top_y, length, leg_w, wheel_r, zorder, dim=1.0):
    """One leg + caster wheel, top-anchored at (lx, top_y). dim<1 mutes the
    color a touch for the back legs, reinforcing the receding-into-depth look."""
    fc = tuple(c * dim for c in CLR)
    bot_y = top_y - length
    ax.add_patch(Rectangle((lx - leg_w / 2, bot_y), leg_w, length,
                            fc=fc, ec=CLR_DK, lw=0.6, zorder=zorder))
    ax.add_patch(Circle((lx, bot_y), wheel_r,
                         fc=WHEEL_CLR, ec=CLR_DK, lw=0.6, zorder=zorder))
    ax.add_patch(Circle((lx - wheel_r * 0.3, bot_y + wheel_r * 0.3),
                         wheel_r * 0.35, fc=WHEEL_HIGHLIGHT_CLR, ec='none',
                         alpha=0.7 * dim, zorder=zorder + 1))
    return bot_y - wheel_r


def add_stand(ax, cx, mid_y, rail_w, rail_h, scale, leg_len_ref,
              front_len_frac=0.20, back_len_frac=0.15,
              leg_w=5.0, wheel_r=9.0, leg_depth=45.0):
    """Draw a rectangular platform (near/far edges joined by a top surface
    and two end walls) on 4 caster-wheeled legs, beneath something of width
    rail_w whose tines/bars sit at mid_y — the middle of the platform's
    depth, not its near edge. front_len_frac/back_len_frac are fractions of
    leg_len_ref (typically the instrument's own on-stage width, so leg
    length scales with the instrument rather than just its scale). Returns
    the lowest y reached."""
    rail_h = rail_h * scale
    leg_w = leg_w * scale
    wheel_r = wheel_r * scale
    front_len = front_len_frac * leg_len_ref
    back_len = back_len_frac * leg_len_ref

    depth = leg_depth * scale
    half_dx = 0.5 * depth * mp.BACK_DX
    half_dy = 0.5 * depth * mp.BACK_DY

    near_x0 = cx - rail_w / 2 - half_dx
    near_top = mid_y - half_dy
    near_bot = near_top - rail_h

    far_x0 = cx - rail_w / 2 + half_dx
    far_top = mid_y + half_dy
    far_bot = far_top - rail_h

    # Top surface: the flat panel the tines/bars actually sit on, spanning
    # from the near edge to the far edge — this is what makes them look
    # like they emerge from the middle of the stand rather than its front.
    top_pts = [(near_x0, near_top), (near_x0 + rail_w, near_top),
               (far_x0 + rail_w, far_top), (far_x0, far_top)]
    ax.add_patch(Polygon(top_pts, closed=True, fc=CLR_TOP, ec=CLR_DK, lw=0.6, zorder=3))

    # End walls (left, right): thin quads connecting near to far, so the
    # platform reads as one solid box instead of two disconnected rails.
    left_pts = [(near_x0, near_bot), (near_x0, near_top),
                (far_x0, far_top), (far_x0, far_bot)]
    right_pts = [(near_x0 + rail_w, near_bot), (near_x0 + rail_w, near_top),
                 (far_x0 + rail_w, far_top), (far_x0 + rail_w, far_bot)]
    ax.add_patch(Polygon(left_pts, closed=True, fc=CLR_DK, ec=CLR_DK, lw=0.5, zorder=1))
    ax.add_patch(Polygon(right_pts, closed=True, fc=CLR_DK, ec=CLR_DK, lw=0.5, zorder=1))

    # Far face drawn first (further away -> lower zorder), then near face
    # on top, matching how the instruments layer their own back/front faces.
    ax.add_patch(Rectangle((far_x0, far_bot), rail_w, rail_h,
                            fc=CLR_DK, ec=CLR_DK, lw=0.6, zorder=2))
    ax.add_patch(Rectangle((near_x0, near_bot), rail_w, rail_h,
                            fc=CLR, ec=CLR_DK, lw=0.8, zorder=4))

    leg_inset = leg_w
    lowest = near_bot
    for lx in (far_x0 + leg_inset, far_x0 + rail_w - leg_inset):
        lowest = min(lowest, _add_leg(ax, lx, far_bot, back_len,
                                       leg_w, wheel_r * 0.85, zorder=1, dim=0.75))
    for lx in (near_x0 + leg_inset, near_x0 + rail_w - leg_inset):
        lowest = min(lowest, _add_leg(ax, lx, near_bot, front_len,
                                       leg_w, wheel_r, zorder=4))
    return lowest
