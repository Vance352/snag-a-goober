"""Snag A Goober - Halloween Island props, built in code.

Same conventions as environment.py: 1 unit = 1 stud, origin at bottom centre,
front faces -Y, one object per material slot named <AssetId>__<Slot>.
Glowing slots (Glow, Swirl, Flame, Window) are switched to Neon in Roblox by
tools/process_import.luau's NEON_SLOTS list.
"""
import math
import os
import random
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


def ribbed(c, n=10, depth=0.07):
    ang = math.atan2(c.y, c.x)
    k = 1 - depth * (0.5 + 0.5 * math.cos(ang * n))
    return Vector((c.x * k, c.y * k, c.z))


def carve(a, cx, cy_front, cz, s, slot="Glow"):
    """Jack-o'-lantern face (triangle eyes, nose, toothy grin) facing -Y."""
    for sx in (-1, 1):
        a.cone(slot, r=0.32 * s, depth=0.2 * s, loc=(cx + sx * 0.42 * s, cy_front, cz + 0.28 * s), rot=(90, 0, 0), seg=3, smooth=False)
    a.cone(slot, r=0.14 * s, depth=0.2 * s, loc=(cx, cy_front, cz + 0.02 * s), rot=(90, 0, 0), seg=3, smooth=False)
    for k in range(6):
        x = cx + (-0.55 + k * 0.22) * s
        z = cz - 0.32 * s + (0.07 * s if k % 2 else -0.05 * s)
        a.box(slot, size=(0.2 * s, 0.2 * s, 0.13 * s), loc=(x, cy_front, z), rot=(0, 25 if k % 2 else -25, 0))


# ================================================================ PORTAL
@prop
def P_SpookyPortal(a: Asset):
    """Stone gothic arch crowned with a jack-o'-lantern; a purple swirl fills the opening."""
    a.colors.update(pal(Stone="#4A4458", StoneDark="#2E2A3A", Swirl="#B04BFF", Glow="#FFB020", Pumpkin="#FF7A1A", Vine="#2F6B2A", Bat="#140F1E"))
    # pillars
    for sx in (-1, 1):
        a.box("Stone", size=(2.2, 2.2, 10), loc=(sx * 5.2, 0, 5), round_e=0.15)
        a.box("StoneDark", size=(2.8, 2.8, 1.0), loc=(sx * 5.2, 0, 0.5))
        a.box("StoneDark", size=(2.6, 2.6, 0.8), loc=(sx * 5.2, 0, 10.2))
        a.cone("StoneDark", r=1.2, depth=2.2, loc=(sx * 5.2, 0, 11.7), seg=4, rot=(0, 0, 45), smooth=False)
        a.tube("Vine", [(sx * 4.1, -1.15, 0.3), (sx * 4.4, -1.2, 3), (sx * 4.0, -1.18, 6), (sx * 4.3, -1.2, 9)], r=0.18, sides=6)
    # pointed arch from stacked blocks
    for k in range(13):
        t = k / 12
        ang = math.pi * t
        x = -5.0 * math.cos(ang)
        z = 10 + 4.2 * math.sin(ang) * (1 - 0.15 * abs(math.cos(ang)))
        a.box("Stone", size=(1.9, 2.0, 1.6), loc=(x, 0, z), rot=(0, -math.degrees(ang) + 90, 0), round_e=0.3)
    # the swirl (a thin disc, spun in game)
    a.cyl("Swirl", r=4.2, depth=0.25, loc=(0, 0.15, 7.8), rot=(90, 0, 0), seg=40, scale=(1, 1, 1.45))
    for k in range(3):
        a.torus("Glow", R=1.2 + k * 1.1, r=0.1, loc=(0, -0.05, 7.8), rot=(90, 0, k * 40), scale=(1, 1.4, 1), seg=36, sides=6, arc=270)
    # keystone jack-o'-lantern
    a.sphere("Pumpkin", r=1.6, loc=(0, -0.3, 14.8), scale=(1.15, 1, 0.9), seg=30, rings=16, deform=lambda c: ribbed(c, 10, 0.1))
    carve(a, 0, -1.85, 14.8, 1.4)
    a.tube("Vine", [(0, -0.3, 16.2), (0.2, -0.3, 16.9), (0.6, -0.2, 17.1)], r=0.22, r_end=0.12, sides=8)
    # little bats on the arch
    for x, z in ((-3.5, 13.6), (3.8, 13.2), (2.0, 15.6)):
        a.sphere("Bat", r=0.3, loc=(x, -1.0, z), seg=10, rings=6)
        for sx in (-1, 1):
            a.cone("Bat", r=0.35, depth=0.9, loc=(x + sx * 0.55, -1.0, z + 0.1), rot=(0, sx * 70, 0), scale=(1, 0.15, 1), seg=3, smooth=False)


# ============================================================ BUILDINGS
@prop
def P_HauntedHouse(a: Asset):
    """A crooked two-storey haunted house with a tall roof, glowing windows and a chimney."""
    a.colors.update(pal(Wall="#5A4A6E", Trim="#2E2440", Roof="#2A1A3A", Window="#FFB43A", Door="#3A2414", Porch="#4A3426", Chimney="#6A5A5A"))
    a.box("Wall", size=(14, 10, 7), loc=(0, 0, 3.5))
    a.box("Wall", size=(12, 9, 6), loc=(0.4, 0, 9.8), rot=(0, 2.5, 0))
    for z in (0.3, 7.1, 12.85):
        a.box("Trim", size=(14.6 if z < 7 else 12.8, 10.6 if z < 7 else 9.6, 0.5), loc=(0, 0, z))
    # steep roof (two slanted slabs + ridge)
    for sx in (-1, 1):
        a.box("Roof", size=(8.6, 10.4, 0.6), loc=(sx * 2.9 + 0.4, 0, 15.9), rot=(0, sx * 50, 0))
    a.box("Roof", size=(0.8, 10.6, 0.8), loc=(0.4, 0, 18.4))
    a.box("Wall", size=(0.5, 9.2, 5.4), loc=(-5.6, 0, 15.0), rot=(0, 2.5, 0))  # gable ends
    a.box("Wall", size=(0.5, 9.2, 5.4), loc=(6.4, 0, 15.0), rot=(0, 2.5, 0))
    a.box("Chimney", size=(1.6, 1.6, 6), loc=(4.0, 2.0, 18.0), rot=(0, 4, 0))
    # windows (glowing) with crooked frames
    for x, z, tilt in ((-4.2, 4.2, 3), (4.2, 4.2, -2), (-3.2, 10.2, -4), (3.8, 10.4, 5), (0.4, 15.5, 0)):
        a.box("Window", size=(2.2, 0.3, 2.6), loc=(x, -5.05 if z < 14 else -4.7, z), rot=(0, tilt, 0))
        a.box("Trim", size=(2.6, 0.2, 0.3), loc=(x, -5.2 if z < 14 else -4.85, z), rot=(0, tilt, 0))
        a.box("Trim", size=(0.3, 0.2, 2.9), loc=(x, -5.2 if z < 14 else -4.85, z), rot=(0, tilt, 0))
    # door + porch
    a.box("Door", size=(2.6, 0.4, 4.4), loc=(0, -5.1, 2.2))
    a.sphere("Window", r=0.18, loc=(0.8, -5.35, 2.2), seg=8, rings=6)
    a.box("Porch", size=(6, 3, 0.5), loc=(0, -6.4, 0.25))
    for sx in (-1, 1):
        a.cyl("Porch", r=0.25, depth=4.5, loc=(sx * 2.7, -7.6, 2.5), seg=8)
    a.box("Roof", size=(6.6, 3.6, 0.4), loc=(0, -6.6, 4.9), rot=(-10, 0, 0))


@prop
def P_Crypt(a: Asset):
    """A small stone mausoleum with columns, a pointed roof and a glowing doorway."""
    a.colors.update(pal(Stone="#6E6A7A", StoneDark="#4A4656", Roof="#3A3646", Glow="#7BFF9E", Moss="#4F7A3A"))
    a.box("StoneDark", size=(9, 8, 1), loc=(0, 0, 0.5))
    a.box("Stone", size=(8, 7, 6), loc=(0, 0.5, 4))
    for sx in (-1, 1):
        a.cyl("Stone", r=0.45, depth=6, loc=(sx * 3.2, -3.4, 4), seg=12)
    a.box("Roof", size=(9, 8.5, 0.6), loc=(0, 0.2, 7.3))
    a.cone("Roof", r=5.6, depth=3.2, loc=(0, 0.2, 9.2), seg=4, rot=(0, 0, 45), scale=(1, 0.95, 1), smooth=False)
    a.box("Glow", size=(2.6, 0.2, 4), loc=(0, -3.05, 3.0))
    a.cone("Glow", r=1.3, depth=1.0, loc=(0, -3.05, 5.4), rot=(90, 0, 0), seg=3, scale=(1, 1, 1), smooth=False)
    a.box("StoneDark", size=(3.4, 0.3, 0.4), loc=(0, -3.3, 6.3))
    for x, z in ((-2.5, 1.4), (2.8, 5.8), (-3.6, 6.9)):
        a.sphere("Moss", r=0.6, loc=(x, -3.0, z), scale=(1.3, 0.4, 0.6), seg=10, rings=6)


@prop
def P_CastleTower(a: Asset):
    """The Phantom Castle landmark: a tall crooked tower with battlements and a glowing window."""
    a.colors.update(pal(Stone="#3E3650", StoneDark="#28223A", Roof="#5B1E8C", Window="#C04BFF", Flag="#FF6A00", Pole="#1A1426"))
    a.cyl("StoneDark", r=7.5, depth=2, loc=(0, 0, 1), seg=24)
    a.cyl("Stone", r=6.2, r2=5.4, depth=26, loc=(0, 0, 14), seg=24)
    a.cyl("StoneDark", r=6.6, depth=1.6, loc=(0, 0, 27.6), seg=24)
    for k in range(12):
        ang = k / 12 * 2 * math.pi
        a.box("Stone", size=(1.8, 1.8, 2.0), loc=(math.cos(ang) * 6.0, math.sin(ang) * 6.0, 29.2), rot=(0, 0, math.degrees(ang)))
    a.cone("Roof", r=6.0, depth=10, loc=(0, 0, 33), seg=24, tip=0.2, rot=(4, -3, 0))
    a.cyl("Pole", r=0.18, depth=5, loc=(0.6, -0.4, 39.5), seg=8)
    a.cone("Flag", r=1.6, depth=3.4, loc=(2.3, -0.4, 41.2), rot=(0, 90, 0), scale=(1, 0.12, 1), seg=3, smooth=False)
    for z, w in ((8, 2.2), (16, 2.0), (23, 1.8)):
        y = -6.05 + (z - 8) * 0.031  # the tower tapers, so windows step inwards
        a.box("Window", size=(w, 0.4, w * 1.4), loc=(0, y, z))
        a.cyl("Window", r=w / 2, depth=0.4, loc=(0, y, z + w * 0.7), rot=(90, 0, 0), seg=16)  # arched top
        a.box("StoneDark", size=(w + 0.5, 0.5, 0.3), loc=(0, y - 0.1, z - w * 0.7 - 0.1))  # sill
    a.box("StoneDark", size=(4, 1, 6), loc=(0, -6.3, 3))  # gate


# ================================================================ NATURE
@prop
def P_SpookyTree(a: Asset):
    """A twisted leafless tree with gnarled branches and a hollow."""
    a.colors.update(pal(Bark="#3A2A24", BarkDark="#241812", Hollow="#0E0A0A", EyeGlow="#FFB020"))
    rnd = random.Random(31)
    trunk = [(0, 0, 0), (0.6, 0.2, 3), (-0.4, 0.0, 6), (0.5, -0.3, 9), (0.0, 0.0, 11)]
    a.tube("Bark", trunk, r=1.3, r_end=0.45, sides=12)
    for k in range(5):
        ang = k / 5 * 2 * math.pi + rnd.uniform(-0.3, 0.3)
        a.tube("BarkDark", [(0, 0, 0.4), (math.cos(ang) * 1.8, math.sin(ang) * 1.8, 0.1), (math.cos(ang) * 2.6, math.sin(ang) * 2.6, 0.0)], r=0.5, r_end=0.12, sides=8)
    for k, z in enumerate((5.5, 7.5, 9.0, 10.5)):
        ang = k * 2.3 + 0.6
        d = 3.2 - k * 0.4
        p0 = (math.cos(ang) * 0.4, math.sin(ang) * 0.4, z)
        p1 = (math.cos(ang) * d * 0.6, math.sin(ang) * d * 0.6, z + 1.2)
        p2 = (math.cos(ang + 0.4) * d, math.sin(ang + 0.4) * d, z + 1.0)
        p3 = (math.cos(ang + 0.7) * d * 1.25, math.sin(ang + 0.7) * d * 1.25, z + 2.0)
        a.tube("Bark", [p0, p1, p2, p3], r=0.42, r_end=0.07, sides=8)
        a.tube("Bark", [p1, (p1[0] * 1.2, p1[1] * 1.2 + 0.6, p1[2] + 1.6)], r=0.18, r_end=0.05, sides=6)
    a.sphere("Hollow", r=0.6, loc=(0.25, -0.9, 3.0), scale=(0.8, 0.5, 1.2), seg=12, rings=8)
    for sx in (-1, 1):
        a.sphere("EyeGlow", r=0.09, loc=(0.25 + sx * 0.2, -1.12, 3.1), seg=8, rings=6)


@prop
def P_Pumpkin(a: Asset):
    """A big uncarved pumpkin with a curly vine (scaled in game for variety)."""
    a.colors.update(pal(Pumpkin="#FF8A1F", PumpkinDark="#E0661A", Stem="#4A6A1A", Leaf="#4FAE3A"))
    a.sphere("Pumpkin", r=1, loc=(0, 0, 1.0), scale=(1.5, 1.4, 1.0), seg=36, rings=16, deform=lambda c: ribbed(c, 10, 0.1))
    a.tube("Stem", [(0, 0, 1.8), (0.1, 0, 2.3), (0.35, 0.1, 2.5)], r=0.2, r_end=0.12, sides=8)
    a.tube("Leaf", [(0.2, 0.1, 1.9), (0.8, 0.5, 2.0), (1.2, 0.3, 1.6), (1.5, -0.2, 1.7)], r=0.06, sides=5)
    a.sphere("Leaf", r=0.5, loc=(-0.5, 0.3, 1.95), scale=(1.2, 0.8, 0.12), rot=(0, -10, 30), seg=12, rings=6)


@prop
def P_JackLantern(a: Asset):
    """A carved glowing jack-o'-lantern hanging from a crooked lamp post (island lighting)."""
    a.colors.update(pal(Post="#241812", Iron="#2E2A3A", Pumpkin="#FF7A1A", Glow="#FFD23C"))
    a.tube("Post", [(0, 0, 0), (0.2, 0, 4), (0, 0, 7), (0.8, 0, 8.2), (2.0, 0, 8.4)], r=0.28, r_end=0.18, sides=8)
    a.box("Iron", size=(1.4, 1.4, 0.4), loc=(0, 0, 0.2))
    a.tube("Iron", [(2.0, 0, 8.4), (2.0, 0, 7.6)], r=0.05, sides=5)
    a.sphere("Pumpkin", r=0.85, loc=(2.0, 0, 6.9), scale=(1.15, 1.05, 0.9), seg=24, rings=12, deform=lambda c: ribbed(c, 8, 0.1))
    carve(a, 2.0, -0.92, 6.9, 0.7)


@prop
def P_GlowShroom(a: Asset):
    """A cluster of glowing teal and purple mushrooms."""
    a.colors.update(pal(Stem="#E8E0D0", Glow="#5BFFE0", GlowB="#C77BFF"))
    for x, y, h, r, slot in ((0, 0, 2.4, 1.1, "Glow"), (1.4, 0.5, 1.4, 0.7, "GlowB"), (-1.1, 0.7, 1.1, 0.55, "Glow"), (0.6, -1.0, 0.8, 0.45, "GlowB")):
        a.tube("Stem", [(x, y, 0), (x + 0.1, y, h * 0.6), (x, y, h)], r=r * 0.28, r_end=r * 0.22, sides=8)
        a.sphere(slot, r=r, loc=(x, y, h), scale=(1, 1, 0.55), seg=18, rings=8, deform=lambda c: Vector((c.x, c.y, max(c.z, -0.1))))


@prop
def P_HayBale(a: Asset):
    """A round hay bale for the pumpkin patch."""
    a.colors.update(pal(Hay="#E8C35A", HayDark="#C9A040"))
    a.cyl("Hay", r=1.6, depth=2.4, loc=(0, 0, 1.6), rot=(90, 0, 0), seg=24)
    for y in (-0.6, 0.6):
        a.torus("HayDark", R=1.62, r=0.08, loc=(0, y, 1.6), rot=(90, 0, 0), seg=28, sides=5)


# ============================================================= GRAVEYARD
@prop
def P_Tombstone(a: Asset):
    """A rounded tombstone with a carved cross and a little moss."""
    a.colors.update(pal(Stone="#8A8698", StoneDark="#5A5668", Moss="#4F7A3A"))
    a.box("Stone", size=(2.4, 0.7, 2.6), loc=(0, 0, 1.3))
    a.cyl("Stone", r=1.2, depth=0.7, loc=(0, 0, 2.6), rot=(90, 0, 0), seg=20)
    a.box("StoneDark", size=(3.0, 1.2, 0.4), loc=(0, 0, 0.2))
    a.box("StoneDark", size=(0.25, 0.15, 1.3), loc=(0, -0.38, 2.2))
    a.box("StoneDark", size=(0.9, 0.15, 0.25), loc=(0, -0.38, 2.45))
    a.sphere("Moss", r=0.4, loc=(-0.8, -0.3, 0.6), scale=(1.3, 0.5, 0.6), seg=10, rings=6)


@prop
def P_StoneCross(a: Asset):
    """A leaning stone cross grave marker."""
    a.colors.update(pal(Stone="#7A7688", StoneDark="#4A4658"))
    a.box("StoneDark", size=(2, 1.2, 0.5), loc=(0, 0, 0.25))
    a.box("Stone", size=(0.6, 0.5, 3.6), loc=(0.15, 0, 2.1), rot=(0, 7, 0))
    a.box("Stone", size=(2.0, 0.5, 0.55), loc=(0.3, 0, 2.9), rot=(0, 7, 0))


@prop
def P_IronFence(a: Asset):
    """An 8-stud wrought-iron fence segment with spear tips (tiles end to end)."""
    a.colors.update(pal(Iron="#1E1A26", Tip="#3A3446"))
    for z in (0.6, 3.4):
        a.box("Iron", size=(8, 0.2, 0.2), loc=(0, 0, z))
    for k in range(9):
        x = -4 + k
        a.cyl("Iron", r=0.08, depth=4.2, loc=(x, 0, 2.1), seg=6)
        a.cone("Tip", r=0.16, depth=0.45, loc=(x, 0, 4.4), seg=4, smooth=False)
    for x in (-4, 4):
        a.box("Iron", size=(0.45, 0.45, 4.8), loc=(x, 0, 2.4))


# ============================================================ MACHINERY
@prop
def P_Cauldron(a: Asset):
    """A huge bubbling witch's cauldron that brews Goobers onto the spooky belts."""
    a.colors.update(pal(Iron="#2A2633", Rim="#48425A", Brew="#7BFF5A", Bubble="#C8FF8A", Fire="#FF7A1A", Wood="#4A2E1A"))
    a.sphere("Iron", r=1, loc=(0, 0, 4.2), scale=(4.4, 4.4, 3.6), seg=32, rings=16, deform=lambda c: Vector((c.x, c.y, min(c.z, 0.55))))
    a.torus("Rim", R=3.95, r=0.45, loc=(0, 0, 6.2), seg=36, sides=10)
    a.cyl("Brew", r=3.75, depth=0.2, loc=(0, 0, 6.15), seg=36)
    rnd = random.Random(5)
    for k in range(7):
        ang = rnd.uniform(0, 6.28)
        d = rnd.uniform(0.5, 3.0)
        a.sphere("Bubble", r=rnd.uniform(0.3, 0.7), loc=(math.cos(ang) * d, math.sin(ang) * d, 6.35), scale=(1, 1, 0.6), seg=12, rings=6)
    for k in range(3):
        ang = k / 3 * 2 * math.pi
        a.box("Iron", size=(0.8, 0.8, 2.2), loc=(math.cos(ang) * 3.2, math.sin(ang) * 3.2, 1.0))
    for k in range(5):
        ang = k / 5 * 2 * math.pi
        a.tube("Wood", [(math.cos(ang) * 2.4, math.sin(ang) * 2.4, 0.3), (math.cos(ang) * 0.6, math.sin(ang) * 0.6, 0.9)], r=0.3, sides=6)
        a.cone("Fire", r=0.6, depth=1.6, loc=(math.cos(ang + 0.6) * 1.2, math.sin(ang + 0.6) * 1.2, 1.2), seg=8, tip=0.05)
    # drip spout facing -Y where Goobers drop out
    a.tube("Brew", [(0, -3.9, 6.0), (0, -4.6, 5.4), (0, -4.8, 4.2)], r=0.55, r_end=0.3, sides=10)


# ============================================================ LANDMARK
@prop
def P_GreatPumpkin(a: Asset):
    """The island hub landmark: a towering carved Great Pumpkin with a crooked witch hat."""
    a.colors.update(pal(Pumpkin="#FF7A1A", PumpkinDark="#D95A12", Glow="#FFD23C", Stem="#3E5A1A", Hat="#2A1245", Band="#B04BFF", Buckle="#FFC93C", Base="#3A2E26"))
    a.cyl("Base", r=11, r2=10, depth=2.0, loc=(0, 0, 1.0), seg=32)
    a.sphere("Pumpkin", r=1, loc=(0, 0, 10.5), scale=(11, 10, 8.5), seg=48, rings=24, deform=lambda c: ribbed(c, 12, 0.08))
    carve(a, 0, -9.55, 10.8, 8.0)
    a.tube("Stem", [(0, 0, 18.5), (0.6, 0, 20.5), (1.4, 0.4, 21.4)], r=1.3, r_end=0.8, sides=12)
    # crooked hat on top
    a.cyl("Hat", r=8.5, depth=0.6, loc=(0, 0, 19.6), rot=(4, -3, 0), seg=40)
    a.cone("Hat", r=5.0, depth=10, loc=(0.4, 0.2, 25), rot=(6, -4, 0), seg=32, tip=1.2)
    a.tube("Hat", [(0.9, 0.5, 29.8), (0.2, 1.0, 32.5), (-2.2, 1.6, 33.5)], r=1.25, r_end=0.2, sides=14)
    a.cyl("Band", r=5.05, depth=1.3, loc=(0.1, 0.05, 20.8), rot=(6, -4, 0), seg=32)
    a.box("Buckle", size=(2.0, 0.5, 1.6), loc=(0.1, -4.95, 20.7), rot=(6, 0, 0))


# ============================================================ CANDY / DECOR
@prop
def P_CandyPickup(a: Asset):
    """A wrapped swirl candy - the collectible for the Candy Hunt."""
    a.colors.update(pal(Wrap="#FF3DA5", Swirl="#FFF6E0", Twist="#C2182B"))
    a.sphere("Wrap", r=0.7, loc=(0, 0, 0.9), scale=(1.2, 0.85, 0.85), seg=20, rings=12)
    a.torus("Swirl", R=0.42, r=0.09, loc=(0, -0.58, 0.9), rot=(90, 0, 0), seg=18, sides=6, arc=300)
    for sx in (-1, 1):
        a.cone("Twist", r=0.42, depth=0.6, loc=(sx * 1.05, 0, 0.9), rot=(0, sx * -90, 0), seg=10, tip=0.08)


@prop
def P_CandyCornGiant(a: Asset):
    """A giant candy-corn decoration for the village."""
    a.colors.update(pal(Yellow="#FFD23C", Orange="#FF8A1F", Tip="#FFF6E0"))
    a.cyl("Yellow", r=2.4, r2=2.0, depth=2.0, loc=(0, 0, 1.0), seg=24)
    a.cone("Orange", r=2.0, depth=3.0, loc=(0, 0, 3.5), seg=24, tip=1.0)
    a.cone("Tip", r=1.0, depth=2.0, loc=(0, 0, 6.0), seg=24, tip=0.1)


@prop
def P_Lollipop(a: Asset):
    """A tall swirl lollipop decoration."""
    a.colors.update(pal(Stick="#FFF6E0", Candy="#B04BFF", Swirl="#FF8A1F"))
    a.cyl("Stick", r=0.25, depth=7, loc=(0, 0, 3.5), seg=10)
    a.cyl("Candy", r=2.0, depth=0.6, loc=(0, 0, 8.0), rot=(90, 0, 0), seg=32)
    for k in range(3):
        a.torus("Swirl", R=0.5 + k * 0.5, r=0.14, loc=(0, -0.32, 8.0), rot=(90, 0, k * 60), seg=24, sides=6, arc=290)


@prop
def P_Signpost(a: Asset):
    """A wooden signpost with three crooked arrow boards (text added in game)."""
    a.colors.update(pal(Wood="#6A4426", Board="#8A5A32", Nail="#2E2A3A"))
    a.cyl("Wood", r=0.35, depth=8, loc=(0, 0, 4), seg=10)
    for z, ang, flip in ((6.6, 8, 1), (5.2, -6, -1), (3.8, 4, 1)):
        a.box("Board", size=(4.4, 0.3, 1.1), loc=(flip * 2.2, -0.35, z), rot=(0, ang, 0))
        a.cone("Board", r=0.78, depth=0.3, loc=(flip * 4.55, -0.35, z + flip * ang * -0.006), rot=(90, flip * 90, 0), seg=3, smooth=False)


def build(ids=None, collection_name="HalloweenProps", spacing=26.0):
    col = clear_collection(collection_name)
    ids = ids or list(PROPS.keys())
    report = []
    for i, pid in enumerate(ids):
        a = Asset(pid, collection=col)
        PROPS[pid](a)
        root, objs = a.build(offset=((i % 5) * spacing, 420 + (i // 5) * spacing, 0))
        report.append((pid, tri_count(objs), len(objs)))
    return report


def build_all():
    return build(list(PROPS.keys()))
