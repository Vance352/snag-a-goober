"""Snag A Goober - Goober Breach update props, built in code.

Same conventions as environment.py: 1 unit = 1 stud, origin at bottom centre,
front faces -Y, one object per material slot named <AssetId>__<Slot>.
Glowing slots (Glow, Slime, Core) become Neon in Roblox (process_import.luau).

  P_GooberBreach  the reactor frame: tiered base, vents, four curling claws,
                  slime tanks (the spinning ring and core are separate)
  P_BreachRing    the gyroscope ring the claws hold (spun by the client)
  P_GooBlaster    the Goober Blaster (held at the hip)
  P_MartStall     the Goober Mart game-pass stall
"""
import math
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else None
if SCRIPT_DIR and SCRIPT_DIR not in sys.path:
    sys.path.append(SCRIPT_DIR)

import importlib
import goober_lib
importlib.reload(goober_lib)
from goober_lib import Asset, clear_collection, hex_rgb, taper, tri_count
from mathutils import Vector

PROPS = {}


def prop(fn):
    PROPS[fn.__name__] = fn
    return fn


def pal(**kw):
    return {k: hex_rgb(v) for k, v in kw.items()}


def arc_points(start, end, bulge, n=10):
    """Points along a curve from start to end bowing outward by `bulge` (Vector)."""
    pts = []
    s, e = Vector(start), Vector(end)
    for i in range(n + 1):
        u = i / n
        p = s.lerp(e, u) + Vector(bulge) * (4 * u * (1 - u))
        pts.append(tuple(p))
    return pts


# ============================================================ THE BREACH
@prop
def P_GooberBreach(a: Asset):
    """Unstable dimensional reactor: a tiered machine base with vents and rune
    inlays, four claws that curl up and in to cradle the ring, slime tanks."""
    a.colors.update(pal(Metal="#3E3460", MetalDark="#272040", Trim="#FFC43D", Glow="#7BE35A", Slime="#9CF27A", Bolt="#8C7AC0", Hose="#5A2E8C"))
    # tiered base
    a.cyl("MetalDark", r=13.0, r2=12.4, depth=1.2, loc=(0, 0, 0.6), seg=48, smooth=False)
    a.cyl("Metal", r=11.6, r2=11.0, depth=1.1, loc=(0, 0, 1.75), seg=48, smooth=False)
    a.cyl("MetalDark", r=8.0, r2=7.4, depth=0.8, loc=(0, 0, 2.7), seg=40, smooth=False)
    a.torus("Trim", R=12.7, r=0.22, loc=(0, 0, 1.22), seg=64, sides=6)
    a.torus("Trim", R=11.3, r=0.2, loc=(0, 0, 2.32), seg=64, sides=6)
    a.torus("Glow", R=9.6, r=0.18, loc=(0, 0, 2.32), seg=64, sides=6)
    a.torus("Glow", R=7.7, r=0.16, loc=(0, 0, 3.12), seg=48, sides=6)
    # central emitter: the dish the core floats above
    a.cyl("MetalDark", r=3.2, r2=2.6, depth=1.6, loc=(0, 0, 3.9), seg=24, smooth=False)
    a.cyl("Trim", r=2.4, r2=1.0, depth=1.4, loc=(0, 0, 5.4), seg=24)
    a.torus("Glow", R=2.7, r=0.16, loc=(0, 0, 4.72), seg=32, sides=6)
    a.cyl("Glow", r=0.7, depth=0.4, loc=(0, 0, 6.2), seg=16)
    # vents and rune plates around the base
    for i in range(12):
        ang = i / 12 * 2 * math.pi
        x, y = math.cos(ang), math.sin(ang)
        a.box("MetalDark", size=(2.2, 0.5, 0.8), loc=(x * 12.75, y * 12.75, 0.75), rot=(0, 0, math.degrees(ang) + 90))
        a.box("Glow", size=(1.5, 0.12, 0.25), loc=(x * 13.02, y * 13.02, 0.8), rot=(0, 0, math.degrees(ang) + 90))
    for i in range(8):
        ang = i / 8 * 2 * math.pi + math.pi / 8
        x, y = math.cos(ang), math.sin(ang)
        a.cyl("Bolt", r=0.32, depth=0.25, loc=(x * 10.2, y * 10.2, 2.35), seg=8, smooth=False)
    # four claws: thick at the base, curling up and inward to cradle the ring (ring at z=12.5, R=7.2)
    for i in range(4):
        ang = i / 4 * 2 * math.pi + math.pi / 4
        d = Vector((math.cos(ang), math.sin(ang), 0))
        foot = d * 9.6 + Vector((0, 0, 2.6))
        tip = d * 7.6 + Vector((0, 0, 13.6))
        pts = arc_points(foot, tip, d * 3.6 + Vector((0, 0, 0.5)), n=14)
        a.tube("Metal", pts, r=1.35, r_end=0.55, sides=10)
        # glowing spine on the outside of each claw
        spine = [tuple(Vector(p) + d * 1.05) for p in pts[1:-2]]
        a.tube("Glow", spine, r=0.22, sides=6)
        # claw hand: a pad that the ring rests against
        a.box("Trim", size=(1.6, 1.6, 0.5), loc=tuple(Vector(tip) + Vector((0, 0, -0.9))), rot=(0, 0, math.degrees(ang)))
        # armour plates down the claw
        for k in (3, 6, 9):
            p = Vector(pts[k])
            a.box("MetalDark", size=(2.0, 2.0, 0.5), loc=tuple(p + d * 0.4), rot=(0, 25 + k * 3, math.degrees(ang)))
        # foot clamp
        a.box("MetalDark", size=(3.4, 3.4, 1.6), loc=tuple(foot + Vector((0, 0, 0.1))), rot=(0, 0, math.degrees(ang)), round_e=0.3)
    # slime tanks between the claws, with hoses into the base
    for i in range(4):
        ang = i / 4 * 2 * math.pi
        d = Vector((math.cos(ang), math.sin(ang), 0))
        c = d * 10.4
        a.cyl("MetalDark", r=1.25, depth=0.5, loc=(c.x, c.y, 2.55), seg=16, smooth=False)
        a.cyl("Slime", r=1.0, depth=3.4, loc=(c.x, c.y, 4.5), seg=16)
        a.cyl("MetalDark", r=1.2, depth=0.45, loc=(c.x, c.y, 6.35), seg=16, smooth=False)
        a.torus("Trim", R=1.05, r=0.1, loc=(c.x, c.y, 4.5), seg=16, sides=5)
        hose = arc_points((c.x, c.y, 6.4), tuple(d * 6.4 + Vector((0, 0, 3.2))), Vector((0, 0, 2.2)), n=8)
        a.tube("Hose", hose, r=0.28, sides=8)


@prop
def P_BreachRing(a: Asset):
    """The gyroscope ring held by the claws (lies flat; spins around its axis).
    Origin at its centre (not the bottom) so it spins cleanly."""
    a.colors.update(pal(Trim="#FFC43D", Metal="#3E3460", Glow="#7BE35A"))
    a.torus("Trim", R=7.2, r=0.62, seg=64, sides=12)
    a.torus("Metal", R=7.2, r=0.75, loc=(0, 0, 0), scale=(1, 1, 0.45), seg=64, sides=10)
    a.torus("Glow", R=6.35, r=0.2, seg=64, sides=6)
    a.torus("Glow", R=8.05, r=0.16, seg=64, sides=6)
    # six gem studs (single, not paired round features)
    for i in range(6):
        ang = i / 6 * 2 * math.pi
        a.ico("Glow", r=0.5, loc=(math.cos(ang) * 7.2, math.sin(ang) * 7.2, 0.75), sub=1)
        a.box("Metal", size=(1.6, 0.6, 1.0), loc=(math.cos(ang) * 7.2, math.sin(ang) * 7.2, -0.2), rot=(0, 0, math.degrees(ang) + 90))


# =========================================================== THE BLASTER
@prop
def P_GooBlaster(a: Asset):
    """Chunky slime blaster: purple body, a goo tank on top, gold nozzle. Points -Y."""
    a.colors.update(pal(Body="#8B5CF0", BodyDark="#4A2E8C", Trim="#FFC43D", Slime="#7BE35A", Grip="#2A1E40"))
    a.box("Body", size=(1.4, 3.6, 1.5), loc=(0, 0.2, 1.6), round_e=0.35)
    a.box("BodyDark", size=(1.0, 1.0, 1.7), loc=(0, 1.0, 0.65), rot=(-15, 0, 0), round_e=0.4)  # grip
    a.box("Grip", size=(1.05, 0.8, 0.5), loc=(0, 1.15, 0.0), round_e=0.5)
    a.cyl("Trim", r=0.55, depth=1.4, loc=(0, -2.1, 1.6), rot=(90, 0, 0), seg=18)
    a.cyl("BodyDark", r=0.72, depth=0.35, loc=(0, -1.55, 1.6), rot=(90, 0, 0), seg=18)
    a.torus("Trim", R=0.62, r=0.12, loc=(0, -2.8, 1.6), rot=(90, 0, 0), seg=18, sides=6)
    # goo tank: one big glass dome with a bubble inside
    a.sphere("Slime", r=0.95, loc=(0, 0.45, 2.75), scale=(1, 1.15, 0.85))
    a.cyl("BodyDark", r=0.75, depth=0.25, loc=(0, 0.45, 2.3), seg=16)
    # side fins
    for sx in (-1, 1):
        a.box("Trim", size=(0.18, 1.6, 0.6), loc=(sx * 0.75, 0.6, 1.9))


# ============================================================ THE MART
@prop
def P_MartStall(a: Asset):
    """Goober Mart: a candy-striped market stall with a counter, shelves of goo
    jars and a crate. Faces -Y (customers stand in front)."""
    a.colors.update(pal(Wood="#B9814F", WoodDark="#7A4E2E", Counter="#FFC43D", Top="#FFF0C8", StripeA="#FF5FA2", StripeB="#FFFFFF", Jar="#9CF27A", Lid="#8B5CF0", Post="#6E54A0"))
    a.box("Counter", size=(16, 3.6, 3.4), loc=(0, 0, 1.8), round_e=0.12)
    a.box("Top", size=(16.6, 4.0, 0.45), loc=(0, 0, 3.8))
    a.box("WoodDark", size=(15.4, 0.3, 2.6), loc=(0, -1.78, 1.6))
    # back wall with shelves of goo jars
    a.box("Wood", size=(16, 0.6, 9), loc=(0, 3.4, 4.5))
    for z in (3.2, 5.6):
        a.box("WoodDark", size=(15, 1.4, 0.3), loc=(0, 2.7, z))
        for k in range(9):
            x = -6.4 + k * 1.6
            a.cyl("Jar", r=0.42, depth=0.9, loc=(x, 2.6, z + 0.6), seg=12)
            a.cyl("Lid", r=0.46, depth=0.18, loc=(x, 2.6, z + 1.1), seg=12)
    # posts and a striped awning
    for sx in (-1, 1):
        a.box("Post", size=(0.8, 0.8, 11), loc=(sx * 7.6, -1.6, 5.5))
    for i in range(8):
        x = -7.6 + 15.2 * (i + 0.5) / 8
        a.box("StripeA" if i % 2 == 0 else "StripeB", size=(15.2 / 8 + 0.02, 7.0, 0.35), loc=(x, 0.6, 11.1), rot=(-12, 0, 0))
        # pennant edge (triangles - a row of round balls risks Roblox's mesh moderation)
        a.cone("StripeA" if i % 2 == 0 else "StripeB", r=0.95, depth=0.25, loc=(x, -2.75, 10.2), rot=(90, 0, 0), seg=3, smooth=False)
    # a crate of goo jars by the counter
    a.box("Wood", size=(2.6, 2.6, 2.2), loc=(9.6, -0.6, 1.1))
    for k in range(4):
        a.cyl("Jar", r=0.4, depth=0.8, loc=(9.0 + (k % 2) * 1.2, -1.2 + (k // 2) * 1.2, 2.6), seg=10)


def build(ids=None, collection_name="HubProps", spacing=34.0):
    col = clear_collection(collection_name)
    ids = ids or list(PROPS)
    for i, pid in enumerate(ids):
        a = Asset(pid, collection=col)
        PROPS[pid](a)
        a.build(offset=(i * spacing, 0, 0))
    return col


def build_all():
    return build()
