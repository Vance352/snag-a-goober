"""Snag A Goober - environment and prop models, built in code.

Same conventions as goobers.py: 1 unit = 1 stud, origin at bottom centre,
one object per material slot named <AssetId>__<Slot>.
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
from goober_lib import Asset, clear_collection, hex_rgb, superellipsoid, taper, tri_count
from mathutils import Vector

PROPS = {}


def prop(fn):
    PROPS[fn.__name__] = fn
    return fn


def pal(**kw):
    return {k: hex_rgb(v) for k, v in kw.items()}


@prop
def P_Stand(a: Asset):
    """Goober display pedestal. Rim is re-coloured by rarity in game."""
    a.colors.update(pal(Base="#5B3E8C", Top="#EDE6FF", Rim="#B0B7C3", Goo="#7BE35A"))
    a.cyl("Base", r=1.75, r2=1.55, depth=0.5, loc=(0, 0, 0.25), seg=32)
    a.cyl("Base", r=1.35, r2=1.45, depth=0.35, loc=(0, 0, 0.67), seg=32)
    a.cyl("Top", r=1.5, depth=0.18, loc=(0, 0, 0.93), seg=32)
    a.torus("Rim", R=1.5, r=0.12, loc=(0, 0, 1.0), seg=40, sides=10)
    # goo drips running down the base
    for i in range(7):
        ang = i / 7 * 2 * math.pi + 0.3
        x, y = math.cos(ang) * 1.62, math.sin(ang) * 1.62
        L = 0.25 + 0.18 * ((i * 37) % 5) / 4
        a.sphere("Goo", r=0.13, loc=(x, y, 0.5 - L), scale=(1, 1, 1.0 + L * 2.5), seg=10, rings=8)
    a.torus("Goo", R=1.68, r=0.1, loc=(0, 0, 0.5), seg=36, sides=8)


@prop
def P_BeltSegment(a: Asset):
    """One 8-stud tile of the Goober conveyor frame (belt surface is a Roblox part)."""
    a.colors.update(pal(Frame="#4A2F7A", Rail="#FFC93C", Roller="#9AA3B5", Stripe="#2A1A45"))
    W, L, H = 12.0, 8.0, 2.4
    for sx in (-1, 1):
        a.box("Frame", size=(0.8, L, H), loc=(sx * (W / 2 + 0.4), 0, H / 2), round_e=0.25)
        a.box("Rail", size=(0.5, L, 0.35), loc=(sx * (W / 2 + 0.4), 0, H + 0.1), round_e=0.4)
        # hazard stripes on the outer face
        for k in range(4):
            a.box("Stripe", size=(0.06, 0.7, 1.2), loc=(sx * (W / 2 + 0.83), -3 + k * 2, H * 0.48), rot=(30, 0, 0))
    for k in range(4):
        a.cyl("Roller", r=0.45, depth=W, loc=(0, -3 + k * 2, H - 0.6), rot=(0, 90, 0), seg=16)
    a.box("Frame", size=(W, L, 0.5), loc=(0, 0, 0.25))


@prop
def P_Gusher(a: Asset):
    """The Goober Gusher: the machine that spits Goobers onto the Slop Line.
    Front (-Y) is the output chute. ~30 wide so it caps both belt ends."""
    a.colors.update(pal(Body="#5B3E8C", BodyDark="#3A2660", Lime="#7BE35A", Pipe="#FFC93C", Glass="#BFFFB0", Metal="#9AA3B5", Light="#FF5FA2"))
    a.box("Body", size=(30, 12, 10), loc=(0, 0, 5), round_e=0.18)
    a.box("BodyDark", size=(30.6, 12.6, 1.2), loc=(0, 0, 0.6), round_e=0.3)
    # funnel on top, full of goo
    a.cyl("Body", r=7.5, r2=3.2, depth=6, loc=(0, 1, 13), rot=(180, 0, 0), seg=32, cap=False)
    a.cyl("BodyDark", r=7.3, r2=3.0, depth=6, loc=(0, 1, 13.05), rot=(180, 0, 0), seg=32, cap=False, flip=True)
    a.torus("Lime", R=7.5, r=0.6, loc=(0, 1, 16), seg=40, sides=10)
    a.cyl("Lime", r=7.1, depth=0.3, loc=(0, 1, 15.7), seg=32)
    for x, y in ((-2.5, 0), (2.8, 2.2), (0.5, -2.4), (-4.5, 3.2)):
        a.sphere("Glass", r=1.0, loc=(x, 1 + y, 16.2), scale=(1, 1, 0.6), seg=14, rings=8)
    # output chute toward the belt
    a.box("BodyDark", size=(13, 6, 4.5), loc=(0, -6.5, 2.4), round_e=0.3)
    a.box("Lime", size=(12, 1, 0.6), loc=(0, -9.6, 0.9), round_e=0.4)
    # big glass tank with bubbles
    a.cyl("Glass", r=2.4, depth=7, loc=(-10, -1, 6.5), seg=24)
    a.torus("Metal", R=2.4, r=0.35, loc=(-10, -1, 3.1), seg=28, sides=8)
    a.torus("Metal", R=2.4, r=0.35, loc=(-10, -1, 10), seg=28, sides=8)
    a.cyl("Lime", r=2.2, depth=4.5, loc=(-10, -1, 5.3), seg=24)
    # pipes looping over the top
    a.tube("Pipe", [(10, -4, 9.8), (10, -4, 14), (6, -2, 16.5), (3, 0, 16.2)], r=0.7, sides=12)
    a.tube("Pipe", [(-10, 3, 9.8), (-9, 3, 13.5), (-5.5, 2.5, 15.8)], r=0.6, sides=12)
    # cartoon gauges + lights on the front face
    for x in (6, 9.5, 13):
        a.cyl("Metal", r=1.1, depth=0.4, loc=(x, -6.1, 7.5), rot=(90, 0, 0), seg=20)
        a.cyl("Light", r=0.8, depth=0.2, loc=(x, -6.35, 7.5), rot=(90, 0, 0), seg=20)
    for x in range(-13, 14, 3):
        a.sphere("Light", r=0.35, loc=(x, -6.05, 10.6), seg=10, rings=6)


@prop
def P_SlopVat(a: Asset):
    """Giant tub of slop at the far end of the line. Front (-Y) faces the belt."""
    a.colors.update(pal(Tub="#5B3E8C", Rim="#FFC93C", Slop="#7BE35A", SlopDark="#4FB83A", Metal="#9AA3B5"))
    a.cyl("Tub", r=13, r2=14, depth=9, loc=(0, 0, 4.5), seg=48, cap=False)
    a.cyl("Tub", r=13, depth=0.4, loc=(0, 0, 0.2), seg=48)
    a.cyl("Tub", r=12.6, r2=13.6, depth=9, loc=(0, 0, 4.55), seg=48, cap=False, flip=True)
    a.torus("Rim", R=14, r=0.8, loc=(0, 0, 9), seg=56, sides=10)
    for z in (2.5, 6):
        a.torus("Metal", R=13.6 - (6 - z) * 0.05, r=0.35, loc=(0, 0, z), seg=56, sides=8)
    a.cyl("Slop", r=13.4, depth=0.5, loc=(0, 0, 8.6), seg=48)
    rnd = __import__("random").Random(5)
    for _ in range(12):
        th, rr = rnd.uniform(0, 6.28), rnd.uniform(1, 11)
        a.sphere("SlopDark", r=rnd.uniform(0.6, 1.4), loc=(math.cos(th) * rr, math.sin(th) * rr, 8.9), scale=(1, 1, 0.4), seg=14, rings=8)
    for k in range(10):
        ang = k / 10 * 2 * math.pi
        L = 1 + (k % 3) * 0.8
        a.sphere("Slop", r=0.7, loc=(math.cos(ang) * 14.1, math.sin(ang) * 14.1, 8.6 - L), scale=(1, 1, 1 + L), seg=10, rings=8)
    # intake ramp on the belt side
    a.box("Metal", size=(12, 6, 1), loc=(0, -14, 6.5), rot=(-25, 0, 0), round_e=0.3)


@prop
def P_SlopOMatic(a: Asset):
    """Upgrade vending machine in every base. Front (-Y) has the screen."""
    a.colors.update(pal(Body="#6E46BE", BodyDark="#3A2660", Screen="#7BE35A", Glass="#BFFFB0", Slop="#7BE35A", Metal="#C9CED6", Button="#FF5FA2", Gold="#FFC93C"))
    a.box("Body", size=(4.6, 3.6, 6.2), loc=(0, 0, 3.1), round_e=0.22)
    a.box("BodyDark", size=(4.9, 3.9, 0.6), loc=(0, 0, 0.3), round_e=0.3)
    a.box("BodyDark", size=(3.8, 0.3, 2.4), loc=(0, -1.75, 4.3), round_e=0.3)
    a.box("Screen", size=(3.4, 0.2, 2.0), loc=(0, -1.9, 4.3), round_e=0.3)
    # arrow glyph on the screen
    a.cone("BodyDark", r=0.6, depth=0.7, loc=(0, -2.02, 4.55), rot=(90, 0, 0), scale=(1, 1, 0.2), seg=3, smooth=False)
    a.box("BodyDark", size=(0.4, 0.06, 0.7), loc=(0, -2.02, 3.95))
    # slop tank on top
    a.cyl("Glass", r=1.4, depth=2.2, loc=(0, 0.2, 7.3), seg=24)
    a.cyl("Slop", r=1.3, depth=1.3, loc=(0, 0.2, 6.85), seg=24)
    a.torus("Metal", R=1.4, r=0.15, loc=(0, 0.2, 8.4), seg=24, sides=8)
    a.sphere("Gold", r=0.4, loc=(0, 0.2, 8.65), seg=12, rings=8)
    # buttons + lever + coin slot
    for i, x in enumerate((-1.2, -0.4, 0.4, 1.2)):
        a.cyl("Button", r=0.28, depth=0.25, loc=(x, -1.85, 2.4), rot=(90, 0, 0), seg=14)
    a.box("Gold", size=(0.9, 0.2, 0.25), loc=(0, -1.85, 1.5), round_e=0.4)
    a.tube("Metal", [(2.4, -0.5, 3.5), (2.9, -0.6, 4.4), (3.0, -0.6, 5.1)], r=0.12, sides=8)
    a.sphere("Button", r=0.35, loc=(3.0, -0.6, 5.3), seg=12, rings=8)


@prop
def P_RebirthShrine(a: Asset):
    """A glowing ring portal on a round dais - the rebirth landmark."""
    a.colors.update(pal(Stone="#EDE6FF", StoneDark="#9C8FC9", Glow="#C04BFF", Gold="#FFC93C"))
    a.cyl("StoneDark", r=10, r2=9.5, depth=1.2, loc=(0, 0, 0.6), seg=40)
    a.cyl("Stone", r=8, r2=7.6, depth=1.2, loc=(0, 0, 1.8), seg=40)
    a.torus("Gold", R=7.8, r=0.3, loc=(0, 0, 2.4), seg=48, sides=8)
    a.torus("Stone", R=5.5, r=0.9, loc=(0, 0, 8.6), rot=(90, 0, 0), seg=48, sides=12)
    a.torus("Glow", R=5.5, r=0.45, loc=(0, -0.7, 8.6), rot=(90, 0, 0), seg=48, sides=10)
    for sx in (-1, 1):
        a.box("Stone", size=(2, 2, 3.6), loc=(sx * 5.5, 0, 4.2), round_e=0.3)
        a.cone("Gold", r=0.8, depth=2, loc=(sx * 8.5, 0, 3.4), seg=4, smooth=False)
    a.ico("Glow", r=1.2, loc=(0, 0, 15.3), sub=1)
    for k in range(8):  # rebirth arrows circling the dais
        ang = k / 8 * 2 * math.pi
        a.cone("Glow", r=0.5, depth=0.9, loc=(math.cos(ang) * 9, math.sin(ang) * 9, 1.25), rot=(90, 0, math.degrees(ang)), scale=(1, 1, 0.3), seg=3, smooth=False)


@prop
def P_ChaosRift(a: Asset):
    """Twisted spires around a floating rift - the Goober Chaos landmark."""
    a.colors.update(pal(Rock="#2A1245", RockLight="#4A2A6E", Glow="#C04BFF", Pink="#FF3DA5"))
    a.cyl("Rock", r=8, r2=9, depth=1.5, loc=(0, 0, 0.75), seg=12, smooth=False)
    for k in range(5):
        ang = k / 5 * 2 * math.pi
        x, y = math.cos(ang) * 6.5, math.sin(ang) * 6.5
        a.tube("Rock", [(x, y, 1), (x * 1.05, y * 1.05, 6), (x * 0.9, y * 0.9, 10), (x * 0.6, y * 0.6, 13)], r=1.2, r_end=0.15, sides=6, smooth=False)
        a.ico("Pink", r=0.6, loc=(x * 0.6, y * 0.6, 13.3), sub=0)
    a.torus("Glow", R=3.8, r=0.35, loc=(0, 0, 8), rot=(90, 0, 0), seg=40, sides=8)
    a.torus("Pink", R=3.0, r=0.25, loc=(0, 0, 8), rot=(80, 25, 0), seg=40, sides=8)
    a.ico("Glow", r=1.5, loc=(0, 0, 8), sub=1)


@prop
def P_LampPost(a: Asset):
    """Curly lamp post with a glowing goo bulb."""
    a.colors.update(pal(Metal="#3A2660", Bulb="#C8FF9E", Gold="#FFC93C"))
    a.cyl("Metal", r=0.7, r2=0.5, depth=0.6, loc=(0, 0, 0.3), seg=16)
    a.tube("Metal", [(0, 0, 0.5), (0, 0, 7), (0.6, 0, 8.4), (1.6, 0, 8.6), (2.1, 0, 8.0)], r=0.22, sides=10)
    a.sphere("Bulb", r=0.75, loc=(2.1, 0, 7.3), scale=(1, 1, 1.2), seg=16, rings=10)
    a.cone("Metal", r=0.75, depth=0.6, loc=(2.1, 0, 8.05), seg=16, tip=0.2)
    a.torus("Gold", R=0.4, r=0.08, loc=(0, 0, 3), seg=16, sides=6)


@prop
def P_SlopBarrel(a: Asset):
    """A leaky barrel of slop."""
    a.colors.update(pal(Wood="#A8642A", Band="#5E636E", Slop="#7BE35A"))
    a.sphere("Wood", r=1, loc=(0, 0, 1.6), scale=(1.15, 1.15, 1.6), seg=20, rings=12, deform=lambda c: Vector((c.x, c.y, max(-0.92, min(0.92, c.z)))))
    for z in (0.55, 2.65):
        a.torus("Band", R=1.12, r=0.09, loc=(0, 0, z), seg=28, sides=6)
    a.cyl("Slop", r=1.0, depth=0.15, loc=(0, 0, 3.05), seg=24)
    a.sphere("Slop", r=0.35, loc=(0.5, -0.95, 2.7), scale=(1, 0.5, 2), seg=10, rings=8)
    a.cyl("Slop", r=0.9, depth=0.05, loc=(0.6, -1.2, 0.03), scale=(1.3, 1, 1), seg=20)


@prop
def P_MushTree(a: Asset):
    """Giant spotted mushroom tree for the meadow."""
    a.colors.update(pal(Stem="#FFF1D6", Cap="#B05BFF", Spot="#FFFFFF", Gill="#7A3FC2"))
    a.tube("Stem", [(0, 0, 0), (0.4, 0, 3), (0.2, 0, 6), (0.6, 0, 8.5)], r=1.1, r_end=0.8, sides=14)
    a.sphere("Cap", r=1, loc=(0.6, 0, 9.2), scale=(4.2, 4.2, 2.4), seg=32, rings=16, deform=lambda c: Vector((c.x, c.y, max(c.z, -0.15))))
    a.cyl("Gill", r=4.0, depth=0.15, loc=(0.6, 0, 8.85), seg=32)
    rnd = __import__("random").Random(8)
    for i in range(8):
        th, el = rnd.uniform(0, 6.28), rnd.uniform(0.3, 1.1)
        a.sphere("Spot", r=0.55, loc=(0.6 + math.cos(th) * math.cos(el) * 4.1, math.sin(th) * math.cos(el) * 4.1, 9.2 + math.sin(el) * 2.35),
                 scale=(1, 1, 0.35), rot=(math.degrees(1.57 - el), 0, math.degrees(th) + 90), seg=10, rings=6)


@prop
def P_Trophy(a: Asset):
    """Golden Goober trophy shown in bases that have rebirthed."""
    a.colors.update(pal(Gold="#FFC93C", Base="#3A2660", Gem="#FF5FA2"))
    a.box("Base", size=(3, 3, 1.4), loc=(0, 0, 0.7), round_e=0.3)
    a.cyl("Gold", r=0.5, r2=0.8, depth=1.6, loc=(0, 0, 2.2), seg=16)
    a.sphere("Gold", r=1.4, loc=(0, 0, 4.2), scale=(1, 0.95, 0.9), seg=24, rings=14)  # goober blob
    for sx in (-1, 1):
        a.sphere("Base", r=0.25, loc=(sx * 0.5, -1.2, 4.5), seg=10, rings=6)
        a.torus("Gold", R=0.6, r=0.15, loc=(sx * 1.6, 0, 4.2), rot=(90, 0, 0), seg=16, sides=6, arc=180)
    a.cone("Gold", r=0.3, depth=0.8, loc=(0, 0, 5.7), seg=12)
    a.sphere("Gem", r=0.35, loc=(0, -1.4, 2.4), seg=10, rings=6)


@prop
def P_Flag(a: Asset):
    """Pennant flag for base decoration (cloth recoloured to the plot colour)."""
    a.colors.update(pal(Pole="#3A2660", Cloth="#FF5FA2", Gold="#FFC93C"))
    a.cyl("Pole", r=0.15, depth=8, loc=(0, 0, 4), seg=10)
    a.sphere("Gold", r=0.3, loc=(0, 0, 8.1), seg=10, rings=6)
    a.cone("Cloth", r=1.2, depth=3.2, loc=(1.6, 0, 6.8), rot=(0, 90, 0), scale=(1, 0.12, 1), seg=3, smooth=False)


def build(ids=None, collection_name="Props", spacing=14.0):
    col = clear_collection(collection_name)
    ids = ids or list(PROPS.keys())
    report = []
    for i, pid in enumerate(ids):
        a = Asset(pid, collection=col)
        PROPS[pid](a)
        root, objs = a.build(offset=(i * spacing, 12, 0))
        report.append((pid, tri_count(objs), len(objs)))
    return report
