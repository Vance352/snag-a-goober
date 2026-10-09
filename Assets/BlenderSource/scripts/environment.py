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
