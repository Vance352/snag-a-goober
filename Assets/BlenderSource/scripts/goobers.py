"""Snag A Goober - the Goober roster, modelled in code.

Run inside Blender:  exec(open(r"<repo>/Assets/BlenderSource/scripts/goobers.py").read())
then call build_all() or build(["G01_Blorp", ...]).
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
from goober_lib import Asset, chain, clear_collection, hex_rgb, superellipsoid, taper, tri_count


def front(x, z, rx, ry, rz, cz, cy=0.0, inset=0.04):
    """Y of the front (-Y) surface of an ellipsoid body at (x, z)."""
    k = 1 - (x / rx) ** 2 - ((z - cz) / rz) ** 2
    return cy - ry * math.sqrt(max(0.0, k)) + inset


def pal(**kw):
    return {k: hex_rgb(v) for k, v in kw.items()}


ROSTER = {}


def goober(fn):
    ROSTER[fn.__name__] = fn
    return fn


# =============================================================== COMMON
@goober
def G01_Blorp(a: Asset):
    """Classic lime blob with mismatched googly eyes and a goo drip hat."""
    a.colors.update(pal(Body="#7BE35A", Accent="#4FB83A"))
    rx, ry, rz, cz = 1.05, 0.95, 0.9, 0.9
    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=32, rings=18,
             deform=lambda c: c if c.z > 0 else c.__class__((c.x * (1 + 0.12 * -c.z), c.y * (1 + 0.12 * -c.z), c.z * 0.85)))
    a.eye((-0.36, front(-0.36, 1.2, rx, ry, rz, cz), 1.2), size=0.3, look=(-0.6, 0.4))
    a.eye((0.4, front(0.4, 1.25, rx, ry, rz, cz), 1.25), size=0.24, look=(0.7, -0.5))
    a.smile((0, front(0, 0.72, rx, ry, rz, cz) + 0.02, 0.72), width=0.55, thick=0.07)
    a.cone("Accent", r=0.22, depth=0.55, loc=(0.1, 0.05, 1.95), rot=(0, 12, 0), seg=16)
    a.sphere("Accent", r=0.23, loc=(0.06, 0.05, 1.72), scale=(1, 1, 0.6), seg=16, rings=8)
    a.feet("Accent", spread=0.45, size=0.27, y=-0.25)


# ============================================================ UNCOMMON
@goober
def G08_ConeHead(a: Asset):
    """Tangerine pear-shaped goober permanently wearing a traffic cone."""
    a.colors.update(pal(Body="#FFB347", Accent="#FF5A1F", Stripe="#F4F4F4", Dark="#2B2B2B"))
    rx, ry, rz, cz = 0.85, 0.8, 0.95, 0.95
    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=28, rings=16,
             deform=taper(top=0.78, bottom=1.12))
    # cone hat sits slightly crooked
    a.cone("Accent", r=0.62, depth=1.35, loc=(0.05, 0, 2.35), rot=(0, -8, 0), seg=24, tip=0.06)
    a.cyl("Stripe", r=0.47, r2=0.37, depth=0.2, loc=(0.035, 0, 2.3), rot=(0, -8, 0), seg=24)
    a.box("Accent", size=(1.45, 1.45, 0.14), loc=(0.11, 0, 1.68), rot=(0, -8, 0), round_e=0.35)
    # one squinting eye peeking under the brim, one wide eye
    a.eye((-0.3, front(-0.3, 1.25, rx, ry, rz, cz), 1.25), size=0.25, look=(0.3, -0.2))
    a.eye((0.32, front(0.32, 1.2, rx, ry, rz, cz), 1.2), size=0.2, look=(-0.4, 0.2), lid="Body")
    a.sphere("Mouth", r=0.14, loc=(0, front(0, 0.78, rx, ry, rz, cz) + 0.02, 0.78), scale=(1.2, 0.5, 0.9), seg=14, rings=8)
    a.feet("Dark", spread=0.38, size=0.25, y=-0.2)


# =========================================================== LEGENDARY
@goober
def G21_Gooberzilla(a: Asset):
    """Pocket kaiju: chunky lizard body, back spikes, tiny useless arms, tail."""
    a.colors.update(pal(Body="#3FA34D", Belly="#C9F27B", Spike="#FFD23F", Tooth="#FFFFFF", Dark="#1E5C2A"))
    # body + head as one upright bean
    a.sphere("Body", r=1, loc=(0, 0.1, 1.15), scale=(0.95, 0.9, 1.15), seg=32, rings=18, deform=taper(top=0.85, bottom=1.1))
    a.sphere("Body", r=1, loc=(0, -0.3, 2.35), scale=(0.75, 0.8, 0.6), seg=28, rings=16)  # head
    a.sphere("Body", r=1, loc=(0, -0.95, 2.18), scale=(0.5, 0.45, 0.32), seg=20, rings=12)  # snout
    a.sphere("Belly", r=1, loc=(0, -0.62, 1.0), scale=(0.62, 0.35, 0.8), seg=24, rings=14)
    # teeth row along the snout
    for i, x in enumerate((-0.32, -0.16, 0.0, 0.16, 0.32)):
        a.cone("Tooth", r=0.06, depth=0.14, loc=(x, -1.28 + abs(x) * 0.35, 2.02), rot=(180, 0, 0), seg=8, smooth=False)
    a.box("Mouth", size=(0.72, 0.2, 0.05), loc=(0, -1.18, 2.08), round_e=0.4)
    a.eye((-0.36, -0.82, 2.62), size=0.22, look=(0.2, 0.3))
    a.eye((0.36, -0.82, 2.62), size=0.22, look=(-0.2, 0.3))
    # angry brows
    for sx in (-1, 1):
        a.box("Dark", size=(0.34, 0.1, 0.08), loc=(sx * 0.36, -0.9, 2.86), rot=(0, sx * 18, 0), round_e=0.5)
    # back spikes along the spine
    for i, (z, y, s) in enumerate(((2.7, 0.15, 0.32), (2.2, 0.75, 0.38), (1.6, 0.95, 0.4), (1.0, 0.95, 0.34), (0.5, 0.8, 0.26))):
        a.cone("Spike", r=s * 0.6, depth=s * 1.4, loc=(0, y + 0.1, z + 0.15), rot=(-60 + i * 10, 0, 0), seg=4, smooth=False)
    # tiny arms
    for sx in (-1, 1):
        a.tube("Body", [(sx * 0.75, -0.4, 1.6), (sx * 0.9, -0.65, 1.45), (sx * 0.85, -0.85, 1.38)], r=0.11, r_end=0.08)
        a.sphere("Body", r=0.1, loc=(sx * 0.85, -0.88, 1.36))
    # tail curling behind
    a.tube("Body", [(0, 0.8, 0.5), (0, 1.4, 0.35), (0.3, 1.9, 0.3), (0.6, 2.15, 0.45)], r=0.38, r_end=0.08, sides=12)
    # legs
    for sx in (-1, 1):
        a.sphere("Body", r=0.38, loc=(sx * 0.55, -0.05, 0.35), scale=(1, 1.1, 0.95), seg=18, rings=10)
        a.sphere("Dark", r=0.3, loc=(sx * 0.58, -0.35, 0.12), scale=(1, 1.3, 0.45), seg=14, rings=8)


# ========================================================== BUILD/EXPORT
def build(ids=None, collection_name="Goobers", spacing=4.5):
    import bpy
    col = clear_collection(collection_name)
    ids = ids or list(ROSTER.keys())
    report = []
    for i, gid in enumerate(ids):
        a = Asset(gid, collection=col)
        ROSTER[gid](a)
        root, objs = a.build(offset=(i * spacing, 0, 0))
        report.append((gid, tri_count(objs), len(objs)))
    return report


def build_all():
    return build(list(ROSTER.keys()))
