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
from mathutils import Vector


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


@goober
def G02_SirPuddle(a: Asset):
    """A flat, wobbly blue puddle with a tiny top hat, monocle and moustache."""
    a.colors.update(pal(Body="#4FA8FF", Hat="#1E1B2E", Band="#E8364F", Gold="#FFC93C", Stache="#5A3A22"))
    rx, ry, rz, cz = 1.3, 1.15, 0.5, 0.45

    def puddle(c):
        # wavy rim and a flat underside
        ang = math.atan2(c.y, c.x)
        k = 1 + 0.07 * math.sin(ang * 5) * (1 - abs(c.z))
        z = c.z if c.z > 0 else c.z * 0.35
        return Vector((c.x * k, c.y * k, z))

    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=40, rings=16, deform=puddle)
    # eyes peek out of the top of the puddle
    a.eye((-0.38, -0.6, 1.0), size=0.28, look=(0.1, 0.4), flat=0.7)
    a.eye((0.38, -0.6, 1.0), size=0.28, look=(-0.1, 0.4), flat=0.7)
    a.torus("Gold", R=0.27, r=0.035, loc=(0.38, -0.8, 1.0), rot=(90, 0, 0), seg=20, sides=6)
    a.tube("Gold", [(0.64, -0.78, 0.93), (0.76, -0.74, 0.7), (0.74, -0.66, 0.5)], r=0.015, sides=5)
    # handlebar moustache
    for sx in (-1, 1):
        a.tube("Stache", [(0, -1.0, 0.58), (sx * 0.2, -1.02, 0.55), (sx * 0.38, -0.98, 0.6), (sx * 0.48, -0.92, 0.72)], r=0.07, r_end=0.03, sides=8)
    # top hat, slightly tipped
    a.cyl("Hat", r=0.48, depth=0.06, loc=(0.05, 0.05, 0.98), rot=(0, 8, 0), seg=24, smooth=False)
    a.cyl("Hat", r=0.3, r2=0.33, depth=0.62, loc=(0.09, 0.05, 1.3), rot=(0, 8, 0), seg=24, smooth=False)
    a.cyl("Band", r=0.315, depth=0.12, loc=(0.065, 0.05, 1.08), rot=(0, 8, 0), seg=24, smooth=False)


@goober
def G03_Toastie(a: Asset):
    """A slice of toast on stubby legs with a pat of butter sliding off."""
    a.colors.update(pal(Crust="#A8642A", Bread="#F2C77E", Butter="#FFE680", Dark="#4A2A12"))
    # classic bread silhouette: rounded box + two top lobes
    a.box("Crust", size=(1.7, 0.5, 1.55), loc=(0, 0, 1.25), round_e=0.32)
    for sx in (-1, 1):
        a.sphere("Crust", r=0.48, loc=(sx * 0.48, 0, 2.05), scale=(1, 0.52, 0.85), seg=24, rings=12)
    a.box("Bread", size=(1.48, 0.5, 1.35), loc=(0, -0.04, 1.24), round_e=0.3)
    for sx in (-1, 1):
        a.sphere("Bread", r=0.4, loc=(sx * 0.46, -0.04, 2.0), scale=(1, 0.55, 0.8), seg=24, rings=12)
    a.box("Butter", size=(0.45, 0.42, 0.14), loc=(0.42, -0.05, 2.36), rot=(0, -20, 15), round_e=0.4)
    a.eye((-0.32, -0.3, 1.6), size=0.24, look=(0.2, 0.1), flat=0.5)
    a.eye((0.32, -0.3, 1.6), size=0.24, look=(-0.2, 0.1), flat=0.5)
    a.smile((0, -0.31, 1.25), width=0.42, thick=0.06)
    # legs + arms
    for sx in (-1, 1):
        a.cyl("Dark", r=0.08, depth=0.5, loc=(sx * 0.38, 0, 0.3), seg=10)
        a.sphere("Dark", r=0.18, loc=(sx * 0.38, -0.08, 0.08), scale=(1, 1.4, 0.55), seg=12, rings=8)
        a.tube("Dark", [(sx * 0.82, 0, 1.25), (sx * 1.05, -0.1, 1.05), (sx * 1.1, -0.15, 0.85)], r=0.06, sides=8)
        a.sphere("Dark", r=0.1, loc=(sx * 1.1, -0.16, 0.8), seg=10, rings=6)


@goober
def G04_Gumbo(a: Asset):
    """A sugary pink gumdrop with buck teeth."""
    a.colors.update(pal(Body="#FF6FB5", Sugar="#FFE6F4", Tooth="#FFFFFF", Dark="#B03A78"))
    a.sphere("Body", r=1, loc=(0, 0, 0.9), scale=(1.0, 0.95, 1.05), seg=32, rings=18,
             deform=chain(taper(top=0.55, bottom=1.05), lambda c: Vector((c.x, c.y, c.z if c.z > -0.2 else -0.2 + (c.z + 0.2) * 0.4))))
    rnd = __import__("random").Random(4)
    for _ in range(26):
        th = rnd.uniform(0, 2 * math.pi)
        zz = rnd.uniform(0.3, 1.7)
        k = 1.0 - 0.45 * (zz - 0.2) / 1.6
        a.ico("Sugar", r=0.05, loc=(math.cos(th) * k * 0.98, math.sin(th) * k * 0.93, zz), sub=0)
    a.eye((-0.3, -0.62, 1.25), size=0.27, look=(0.3, 0.3))
    a.eye((0.3, -0.62, 1.25), size=0.27, look=(-0.3, 0.3))
    a.smile((0, -0.86, 0.82), width=0.5, thick=0.06)
    for sx in (-1, 1):
        a.box("Tooth", size=(0.15, 0.08, 0.2), loc=(sx * 0.085, -0.9, 0.72), round_e=0.5)
    a.feet("Dark", spread=0.42, size=0.24, y=-0.15)


@goober
def G05_PebblePete(a: Asset):
    """A sleepy rock with a sprout growing out of its head."""
    a.colors.update(pal(Body="#9AA0AA", Moss="#6FBF5A", Leaf="#5BD45B", Dark="#5E636E"))
    rnd = __import__("random").Random(11)

    def lumpy(c):
        n = 1 + 0.09 * math.sin(c.x * 5.1 + 1) * math.cos(c.y * 4.3) + 0.06 * math.sin(c.z * 7.0)
        z = c.z if c.z > -0.3 else -0.3 + (c.z + 0.3) * 0.3
        return Vector((c.x * n, c.y * n, z * n))

    a.sphere("Body", r=1, loc=(0, 0, 0.75), scale=(1.15, 0.95, 0.85), seg=18, rings=12, deform=lumpy, smooth=False)
    a.sphere("Moss", r=0.5, loc=(-0.45, 0.1, 1.3), scale=(1, 1, 0.3), seg=14, rings=8)
    a.eye((-0.36, -0.84, 0.95), size=0.27, look=(0, -0.25), flat=0.6)
    a.eye((0.36, -0.84, 0.95), size=0.27, look=(0, -0.25), flat=0.6)
    for sx in (-1, 1):  # heavy sleepy lids
        a.sphere("Dark", r=0.29, loc=(sx * 0.36, -0.86, 1.04), scale=(1, 0.62, 0.55), seg=16, rings=8)
    a.smile((0, -0.95, 0.6), width=0.3, thick=0.05)
    # sprout
    a.tube("Leaf", [(0.15, 0, 1.45), (0.18, -0.02, 1.7), (0.12, 0, 1.9)], r=0.035, sides=6)
    for sx, rot in ((-1, -35), (1, 35)):
        a.sphere("Leaf", r=0.18, loc=(0.12 + sx * 0.17, 0, 1.95), scale=(1.4, 0.35, 0.7), rot=(0, rot, 0), seg=12, rings=8)


@goober
def G06_Nugget(a: Asset):
    """A crunchy chicken nugget wearing its dipping-sauce cup as a hat."""
    a.colors.update(pal(Body="#D99A3E", Crumb="#B5762A", Cup="#FFFFFF", Sauce="#E8364F", Dark="#7A4A1A"))

    def nugget(c):
        n = 1 + 0.08 * math.sin(c.x * 6 + c.z * 3) + 0.05 * math.cos(c.y * 7)
        return Vector((c.x * n, c.y * n, c.z * n))

    a.sphere("Body", r=1, loc=(0, 0, 0.95), scale=(1.05, 0.7, 0.9), seg=28, rings=16, deform=chain(superellipsoid(0.8, 0.9), nugget))
    rnd = __import__("random").Random(7)
    for _ in range(30):
        th = rnd.uniform(-math.pi, 0)
        zz = rnd.uniform(0.3, 1.6)
        a.ico("Crumb", r=rnd.uniform(0.04, 0.07), loc=(math.cos(th) * 0.95 * (1 - abs(zz - 0.95) * 0.5), math.sin(th) * 0.66, zz), sub=0)
    a.eye((-0.32, -0.63, 1.15), size=0.24, look=(0.2, 0.2))
    a.eye((0.32, -0.63, 1.15), size=0.24, look=(-0.2, 0.2))
    a.smile((0, -0.68, 0.78), width=0.45, thick=0.06)
    # sauce cup hat, tilted
    a.cyl("Cup", r=0.36, r2=0.44, depth=0.42, loc=(0.2, 0.05, 1.98), rot=(10, 18, 0), seg=20)
    a.cyl("Sauce", r=0.41, depth=0.05, loc=(0.27, 0.01, 2.2), rot=(10, 18, 0), seg=20)
    a.feet("Dark", spread=0.45, size=0.22, y=-0.1)


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


@goober
def G07_Wobblesworth(a: Asset):
    """A tall, translucent cherry jelly in a bow tie, with a visible jelly core."""
    a.colors.update(pal(Jelly="#FF4D6D", Core="#B3122E", Bow="#2B2B6E", Plate="#F4F4F4"))
    a.cyl("Plate", r=1.0, r2=0.95, depth=0.12, loc=(0, 0, 0.06), seg=32)
    a.sphere("Jelly", r=1, loc=(0, 0, 1.35), scale=(0.8, 0.8, 1.25), seg=28, rings=18,
             deform=chain(superellipsoid(0.85, 0.7), taper(top=0.82, bottom=1.0)))
    a.sphere("Core", r=0.38, loc=(0, 0.05, 1.2), seg=16, rings=10)
    for z in (0.6, 1.25, 1.9):  # moulded ridges
        a.torus("Jelly", R=0.78 - (z - 0.6) * 0.06, r=0.07, loc=(0, 0, z), seg=28, sides=8)
    a.eye((-0.27, -0.66, 1.75), size=0.22, look=(0.2, 0.1))
    a.eye((0.27, -0.66, 1.75), size=0.22, look=(-0.2, 0.1))
    a.smile((0, -0.76, 1.45), width=0.3, thick=0.05)
    for sx in (-1, 1):
        a.cone("Bow", r=0.16, depth=0.32, loc=(sx * 0.17, -0.76, 1.12), rot=(0, sx * -90, 0), seg=10, tip=0.03)
    a.sphere("Bow", r=0.07, loc=(0, -0.8, 1.12), seg=10, rings=6)


@goober
def G09_Snorkel(a: Asset):
    """A round teal fish-goober that never takes off its snorkel mask."""
    a.colors.update(pal(Body="#2EC4B6", Fin="#1A8C82", Mask="#FFD23F", Glass="#BFEFFF", Tube="#FF8C42", Belly="#C8FFF4"))
    a.sphere("Body", r=1, loc=(0, 0.1, 1.1), scale=(0.85, 1.05, 0.85), seg=28, rings=16)
    a.sphere("Belly", r=1, loc=(0, -0.25, 0.85), scale=(0.62, 0.6, 0.5), seg=20, rings=12)
    # tail + fins
    a.cone("Fin", r=0.55, depth=0.7, loc=(0, 1.35, 1.15), rot=(-90, 0, 0), scale=(0.25, 1, 1), seg=4, tip=0.0, smooth=False)
    for sx in (-1, 1):
        a.sphere("Fin", r=0.35, loc=(sx * 0.85, 0.1, 0.95), scale=(0.25, 0.9, 0.55), rot=(0, sx * 25, 0), seg=14, rings=8)
    a.cone("Fin", r=0.3, depth=0.45, loc=(0, 0.35, 2.0), rot=(-25, 0, 0), scale=(0.25, 1, 1), seg=4, smooth=False)
    # mask: frame + glass, eyes behind it
    a.eye((-0.26, -0.78, 1.35), size=0.22, look=(0.3, 0.2))
    a.eye((0.26, -0.78, 1.35), size=0.22, look=(-0.3, 0.2))
    a.box("Mask", size=(0.95, 0.12, 0.5), loc=(0, -0.92, 1.36), round_e=0.45)
    a.box("Glass", size=(0.85, 0.06, 0.4), loc=(0, -0.99, 1.36), round_e=0.45)
    a.tube("Mask", [(-0.45, -0.85, 1.38), (-0.8, -0.3, 1.45), (-0.82, 0.3, 1.4)], r=0.04, sides=6)
    a.tube("Mask", [(0.45, -0.85, 1.38), (0.8, -0.3, 1.45), (0.82, 0.3, 1.4)], r=0.04, sides=6)
    # snorkel tube from mouth up past the head
    a.tube("Tube", [(0.25, -0.9, 0.95), (0.55, -0.8, 1.05), (0.72, -0.55, 1.5), (0.72, -0.45, 2.1), (0.68, -0.45, 2.35)], r=0.07, sides=10)
    a.cyl("Tube", r=0.1, depth=0.12, loc=(0.68, -0.45, 2.4), seg=12)
    a.feet("Fin", spread=0.4, size=0.24, y=-0.15)


@goober
def G10_Mushy(a: Asset):
    """A cheerful toadstool: cream stem body, big spotted red cap."""
    a.colors.update(pal(Stem="#FFF1D6", Cap="#E8364F", Spot="#FFFFFF", Dark="#B08960"))
    a.sphere("Stem", r=1, loc=(0, 0, 0.75), scale=(0.62, 0.58, 0.8), seg=24, rings=14, deform=taper(top=0.82, bottom=1.08))
    # domed cap
    a.sphere("Cap", r=1, loc=(0, 0, 1.55), scale=(1.15, 1.1, 0.75),
             seg=32, rings=16, deform=lambda c: Vector((c.x, c.y, max(c.z, -0.1) if c.z > -0.1 else -0.1 + (c.z + 0.1) * 0.15)))
    a.cyl("Dark", r=1.02, depth=0.06, loc=(0, 0, 1.47), seg=32)
    rnd = __import__("random").Random(3)
    for i in range(9):
        th = i / 9 * 2 * math.pi + rnd.uniform(-0.2, 0.2)
        el = rnd.uniform(0.25, 0.85)
        x = math.cos(th) * math.cos(el) * 1.13
        y = math.sin(th) * math.cos(el) * 1.08
        z = 1.55 + math.sin(el) * 0.74
        n = Vector((x, y, (z - 1.55) * 1.5)).normalized()
        rx = math.degrees(math.atan2(math.hypot(n.x, n.y), n.z))
        rz = math.degrees(math.atan2(n.y, n.x)) + 90
        a.sphere("Spot", r=rnd.uniform(0.13, 0.2), loc=(x, y, z), scale=(1, 1, 0.3), rot=(rx, 0, rz), seg=12, rings=6)
    a.sphere("Spot", r=0.22, loc=(0, 0, 2.3), scale=(1, 1, 0.3), seg=12, rings=6)
    a.eye((-0.22, -0.5, 1.02), size=0.19, look=(0.1, 0.3))
    a.eye((0.22, -0.5, 1.02), size=0.19, look=(-0.1, 0.3))
    a.smile((0, -0.55, 0.74), width=0.3, thick=0.045)
    for sx in (-1, 1):
        a.tube("Stem", [(sx * 0.55, -0.05, 0.8), (sx * 0.78, -0.2, 0.65), (sx * 0.85, -0.25, 0.5)], r=0.07, sides=8)
    a.feet("Dark", spread=0.32, size=0.22, y=-0.1)


@goober
def G11_BeanBoi(a: Asset):
    """A kidney bean that will not stop waving at you."""
    a.colors.update(pal(Body="#C2453A", Shine="#E8786E", Dark="#6E1E18"))

    def bean(c):
        # bend the egg into a kidney shape (curve in X with height)
        return Vector((c.x - 0.28 * (c.z ** 2) + 0.14, c.y, c.z))

    a.sphere("Body", r=1, loc=(0, 0, 1.2), scale=(0.72, 0.62, 1.15), seg=28, rings=18, deform=bean)
    a.sphere("Shine", r=0.18, loc=(0.25, -0.5, 1.75), scale=(0.6, 0.4, 1.3), seg=12, rings=8)
    a.eye((-0.2, -0.57, 1.55), size=0.21, look=(0.4, 0.2))
    a.eye((0.2, -0.57, 1.58), size=0.21, look=(0.4, 0.2))
    a.smile((0.02, -0.6, 1.2), width=0.42, thick=0.06)
    a.sphere("Mouth", r=0.11, loc=(0.02, -0.6, 1.12), scale=(1.4, 0.5, 0.7), seg=12, rings=6)
    # waving arm up, other arm relaxed
    a.tube("Body", [(0.55, -0.1, 1.35), (0.85, -0.2, 1.7), (0.95, -0.25, 2.15)], r=0.09, sides=10)
    a.sphere("Body", r=0.15, loc=(0.97, -0.26, 2.25), seg=12, rings=8)
    a.tube("Body", [(-0.55, -0.1, 1.15), (-0.8, -0.2, 0.9), (-0.85, -0.22, 0.7)], r=0.08, sides=10)
    a.sphere("Body", r=0.12, loc=(-0.86, -0.23, 0.65), seg=12, rings=8)
    a.feet("Dark", spread=0.33, size=0.24, y=-0.12)


# ================================================================ RARE
@goober
def G12_CaptainSpork(a: Asset):
    """A purple pirate goober with an eyepatch, a tricorn and a spork sword."""
    a.colors.update(pal(Body="#8E5BE8", Hat="#1E1B2E", Trim="#FFC93C", Skull="#FFFFFF", Metal="#C9CED6", Coat="#B3122E", Dark="#2A1A45"))
    rx, ry, rz, cz = 0.95, 0.88, 0.95, 1.05
    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=30, rings=16)
    a.sphere("Coat", r=1, loc=(0, 0.02, 0.72), scale=(0.98, 0.9, 0.55), seg=30, rings=12,
             deform=lambda c: Vector((c.x, c.y, min(c.z, 0.35))))
    for z in (0.62, 0.9):
        a.sphere("Trim", r=0.06, loc=(0, -0.9, z), seg=8, rings=6)
    a.eye((0.3, front(0.3, 1.32, rx, ry, rz, cz), 1.32), size=0.26, look=(-0.3, 0.1))
    # eyepatch + strap
    a.cyl("Hat", r=0.2, depth=0.06, loc=(-0.3, front(-0.3, 1.32, rx, ry, rz, cz) - 0.02, 1.32), rot=(90, 0, 0), seg=16)
    a.torus("Hat", R=0.97, r=0.025, loc=(0, 0, 1.38), rot=(0, -14, 0), scale=(1, 0.93, 1), seg=40, sides=6)
    a.smile((0.05, front(0.05, 0.98, rx, ry, rz, cz) + 0.02, 1.0), width=0.4, thick=0.05, tilt=10)
    # tricorn: flattened three-lobed brim + crown
    for k in range(3):
        ang = math.radians(90 + k * 120)
        a.sphere("Hat", r=0.5, loc=(math.cos(ang) * 0.35, math.sin(ang) * 0.35 - 0.05, 1.98), scale=(1.1, 0.55, 0.32),
                 rot=(0, 0, math.degrees(ang) + 90), seg=16, rings=8)
    a.sphere("Hat", r=0.48, loc=(0, 0, 2.05), scale=(1, 1, 0.62), seg=20, rings=10)
    a.torus("Trim", R=0.47, r=0.035, loc=(0, 0, 1.95), seg=30, sides=6)
    a.sphere("Skull", r=0.12, loc=(0, -0.48, 2.1), scale=(1, 0.5, 1), seg=12, rings=8)
    # spork sword in the right hand
    a.tube("Body", [(0.85, -0.1, 1.05), (1.05, -0.35, 0.95)], r=0.09, sides=8)
    a.sphere("Body", r=0.13, loc=(1.08, -0.4, 0.95), seg=10, rings=6)
    a.tube("Metal", [(1.08, -0.42, 0.75), (1.08, -0.42, 1.9)], r=0.04, sides=8)
    a.sphere("Metal", r=0.16, loc=(1.08, -0.42, 2.02), scale=(1, 0.35, 1.3), seg=14, rings=8)
    for dx in (-0.08, 0.0, 0.08):
        a.cone("Metal", r=0.025, depth=0.18, loc=(1.08 + dx, -0.42, 2.27), seg=6, smooth=False)
    a.box("Trim", size=(0.36, 0.08, 0.08), loc=(1.08, -0.42, 0.98), round_e=0.5)
    a.feet("Dark", spread=0.42, size=0.26, y=-0.18)


@goober
def G13_Fluffernaut(a: Asset):
    """A fluffy cloud goober in a glass space helmet with a jetpack."""
    a.colors.update(pal(Cloud="#F4F7FF", Glass="#9ED8FF", Metal="#9AA3B5", Suit="#FF8C42", Light="#7BE35A"))
    puffs = [(0, 0, 1.0, 0.75), (-0.5, 0.05, 0.85, 0.5), (0.5, 0.05, 0.85, 0.5), (0, 0.35, 1.0, 0.55),
             (-0.3, -0.25, 0.55, 0.42), (0.3, -0.25, 0.55, 0.42), (0, 0.1, 1.45, 0.48)]
    for x, y, z, r in puffs:
        a.sphere("Cloud", r=r, loc=(x, y, z), seg=20, rings=12)
    # helmet: a ring collar and a glass bubble around the face
    a.torus("Metal", R=0.62, r=0.09, loc=(0, -0.05, 1.32), rot=(-20, 0, 0), seg=30, sides=8)
    a.sphere("Glass", r=0.72, loc=(0, -0.12, 1.75), seg=28, rings=16)
    a.sphere("Cloud", r=0.52, loc=(0, -0.08, 1.72), seg=20, rings=12)
    a.eye((-0.2, -0.6, 1.8), size=0.17, look=(0.1, 0.3))
    a.eye((0.2, -0.6, 1.8), size=0.17, look=(-0.1, 0.3))
    a.smile((0, -0.6, 1.58), width=0.24, thick=0.04)
    # jetpack + antenna light
    a.box("Suit", size=(0.9, 0.45, 0.85), loc=(0, 0.75, 1.1), round_e=0.35)
    for sx in (-1, 1):
        a.cyl("Metal", r=0.15, r2=0.2, depth=0.3, loc=(sx * 0.25, 0.8, 0.55), seg=12)
    a.tube("Metal", [(0.25, -0.05, 2.4), (0.3, -0.05, 2.75)], r=0.025, sides=6)
    a.sphere("Light", r=0.08, loc=(0.3, -0.05, 2.8), seg=10, rings=6)


@goober
def G14_DiscoDan(a: Asset):
    """A mirror-ball goober with an afro, shades and platform shoes."""
    a.colors.update(pal(Mirror="#D8DEE9", Afro="#3B2416", Shades="#111111", Platform="#B05BFF", Lips="#FF5FA2"))
    a.ico("Mirror", r=0.95, loc=(0, 0, 1.25), sub=2, smooth=False)
    rnd = __import__("random").Random(9)
    for i in range(16):
        th = rnd.uniform(0, 2 * math.pi)
        el = rnd.uniform(0.15, 1.2)
        x, y = math.cos(th) * math.cos(el) * 0.85, math.sin(th) * math.cos(el) * 0.8 + 0.12
        z = 2.0 + math.sin(el) * 0.5
        a.sphere("Afro", r=rnd.uniform(0.3, 0.42), loc=(x, y, z), seg=12, rings=8)
    # shades
    for sx in (-1, 1):
        a.box("Shades", size=(0.36, 0.08, 0.22), loc=(sx * 0.24, -0.92, 1.5), rot=(0, sx * -8, 0), round_e=0.45)
    a.box("Shades", size=(0.2, 0.06, 0.05), loc=(0, -0.93, 1.55))
    a.sphere("Lips", r=0.16, loc=(0, -0.92, 1.0), scale=(1.3, 0.45, 0.6), seg=12, rings=8)
    for sx in (-1, 1):
        a.cyl("Platform", r=0.1, depth=0.45, loc=(sx * 0.35, 0, 0.45), seg=10)
        a.box("Platform", size=(0.38, 0.6, 0.28), loc=(sx * 0.35, -0.1, 0.14), round_e=0.35)
        a.tube("Mirror", [(sx * 0.85, 0, 1.3), (sx * 1.1, -0.1, 1.6), (sx * 1.25, -0.15, 1.95)], r=0.07, sides=8)


@goober
def G15_Chonk(a: Asset):
    """An enormous, extremely content orange cat-goober."""
    a.colors.update(pal(Body="#FF9F43", Stripe="#D9701A", Belly="#FFE0B8", Nose="#FF5FA2", Dark="#5A3A22"))
    rx, ry, rz, cz = 1.3, 1.1, 0.95, 0.95
    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=32, rings=18,
             deform=lambda c: Vector((c.x, c.y, c.z if c.z > -0.3 else -0.3 + (c.z + 0.3) * 0.45)))
    a.sphere("Belly", r=1, loc=(0, -0.55, 0.7), scale=(0.85, 0.55, 0.6), seg=24, rings=12)
    for i, x in enumerate((-0.45, 0, 0.45)):
        a.sphere("Stripe", r=0.5, loc=(x, 0.1, 1.82), scale=(0.18, 1.0, 0.12), rot=(0, 0, 0), seg=12, rings=8)
    for sx in (-1, 1):
        a.cone("Body", r=0.32, depth=0.5, loc=(sx * 0.68, 0.0, 1.85), rot=(0, sx * 18, 0), scale=(1, 0.55, 1), seg=12, tip=0.04)
        a.cone("Nose", r=0.18, depth=0.3, loc=(sx * 0.66, -0.12, 1.83), rot=(0, sx * 18, 0), scale=(1, 0.3, 1), seg=10, tip=0.02)
    # happy closed eyes (^ ^) and a cat mouth
    for sx in (-1, 1):
        a.smile((sx * 0.38, front(sx * 0.38, 1.25, rx, ry, rz, cz) + 0.02, 1.25), width=0.3, thick=0.045, frown=True)
    a.sphere("Nose", r=0.08, loc=(0, front(0, 1.1, rx, ry, rz, cz), 1.1), scale=(1.3, 0.6, 0.8), seg=10, rings=6)
    for sx in (-1, 1):
        a.smile((sx * 0.1, front(sx * 0.1, 0.98, rx, ry, rz, cz) + 0.02, 0.98), width=0.2, thick=0.03)
        for dz in (-0.05, 0.06):
            a.tube("Dark", [(sx * 0.35, front(0.35, 1.05, rx, ry, rz, cz) - 0.02, 1.05 + dz), (sx * 0.85, front(0.35, 1.05, rx, ry, rz, cz) - 0.08, 1.05 + dz * 2.5)], r=0.012, sides=4)
    a.tube("Body", [(0.9, 0.7, 0.4), (1.3, 0.8, 0.6), (1.45, 0.5, 1.0), (1.3, 0.25, 1.25)], r=0.16, r_end=0.1, sides=10)
    for sx in (-1, 1):
        a.sphere("Belly", r=0.22, loc=(sx * 0.5, -0.85, 0.15), scale=(1, 1.2, 0.55), seg=12, rings=8)


@goober
def G16_BubblesMcGee(a: Asset):
    """A sky-blue goober blowing a huge, slightly worrying gum bubble."""
    a.colors.update(pal(Body="#5BC0FF", Bubble="#FF8FC8", Cheek="#FF5FA2", Dark="#2A5C8C"))
    rx, ry, rz, cz = 0.95, 0.9, 0.95, 1.05
    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=30, rings=16)
    a.eye((-0.32, front(-0.32, 1.45, rx, ry, rz, cz), 1.45), size=0.24, look=(0.4, -0.4))
    a.eye((0.32, front(0.32, 1.45, rx, ry, rz, cz), 1.45), size=0.24, look=(-0.4, -0.4))
    for sx in (-1, 1):
        a.sphere("Cheek", r=0.17, loc=(sx * 0.6, front(sx * 0.6, 1.0, rx, ry, rz, cz) + 0.04, 1.0), scale=(1, 0.4, 0.8), seg=12, rings=8)
    a.sphere("Bubble", r=0.62, loc=(0, -1.35, 0.95), seg=30, rings=18)
    a.sphere("Bubble", r=0.16, loc=(0, -0.85, 0.95), scale=(1, 0.6, 1), seg=12, rings=8)
    for x, y, z, r in ((0.8, -0.9, 1.8, 0.12), (-0.75, -0.7, 2.1, 0.09), (0.5, -0.5, 2.35, 0.07)):
        a.sphere("Bubble", r=r, loc=(x, y, z), seg=12, rings=8)
    a.feet("Dark", spread=0.42, size=0.26, y=-0.15)


# ================================================================ EPIC
@goober
def G17_GrandpaGoob(a: Asset):
    """A hunched old goober: huge beard, round specs, flat cap and a cane."""
    a.colors.update(pal(Body="#8FB996", Beard="#F4F4F4", Cap="#6B4F3A", Wood="#8A5A2B", Glass="#DDF3FF", Frame="#3A3A3A"))
    rx, ry, rz, cz = 0.95, 0.9, 1.0, 1.1
    a.sphere("Body", r=1, loc=(0, 0.1, cz), scale=(rx, ry, rz), rot=(12, 0, 0), seg=30, rings=16)
    # beard: a soft cone of puffs
    for i, (x, z, r) in enumerate(((0, 0.95, 0.42), (-0.3, 1.05, 0.3), (0.3, 1.05, 0.3), (0, 0.6, 0.32), (-0.18, 0.4, 0.2), (0.18, 0.4, 0.2), (0, 0.25, 0.14))):
        a.sphere("Beard", r=r, loc=(x, -0.78 + (1.0 - z) * 0.1, z), scale=(1, 0.7, 1), seg=16, rings=10)
    # moustache
    for sx in (-1, 1):
        a.sphere("Beard", r=0.2, loc=(sx * 0.18, -0.95, 1.22), scale=(1.4, 0.7, 0.6), rot=(0, sx * -15, 0), seg=14, rings=8)
    a.sphere("Body", r=0.13, loc=(0, -1.0, 1.36), scale=(1, 1, 0.9), seg=12, rings=8)  # nose
    for sx in (-1, 1):
        a.eye((sx * 0.3, -0.86, 1.6), size=0.17, look=(0, 0.1), flat=0.6)
        a.torus("Frame", R=0.22, r=0.03, loc=(sx * 0.3, -0.98, 1.6), rot=(90, 0, 0), seg=20, sides=6)
        a.cyl("Glass", r=0.2, depth=0.02, loc=(sx * 0.3, -0.99, 1.6), rot=(90, 0, 0), seg=18)
        a.box("Beard", size=(0.3, 0.12, 0.08), loc=(sx * 0.3, -0.9, 1.86), rot=(0, sx * -12, 0), round_e=0.5)  # brows
    a.box("Frame", size=(0.16, 0.04, 0.04), loc=(0, -0.99, 1.62))
    # flat cap
    a.sphere("Cap", r=0.72, loc=(0, 0.05, 2.0), scale=(1, 1.05, 0.38), seg=24, rings=10)
    a.box("Cap", size=(0.9, 0.5, 0.08), loc=(0, -0.62, 1.95), rot=(-12, 0, 0), round_e=0.5)
    # cane
    a.tube("Wood", [(0.95, -0.55, 0.0), (0.95, -0.55, 1.35)], r=0.05, sides=8)
    a.torus("Wood", R=0.16, r=0.05, loc=(0.79, -0.55, 1.35), rot=(90, 0, 0), seg=14, sides=8, arc=180)
    a.tube("Body", [(0.75, -0.2, 1.05), (0.92, -0.5, 1.2)], r=0.09, sides=8)
    a.feet("Cap", spread=0.4, size=0.26, y=-0.15)


@goober
def G18_MoaiGoob(a: Asset):
    """A stone head statue with a very serious face and tiny feet."""
    a.colors.update(pal(Stone="#8C8578", StoneDark="#5E584E", Topknot="#B5452F", Moss="#6FBF5A", Feet="#5E584E"))
    a.sphere("Stone", r=1, loc=(0, 0, 1.75), scale=(0.75, 0.68, 1.5), seg=20, rings=14, deform=superellipsoid(0.55, 0.6), smooth=False)
    # heavy brow, long nose, lips, chin
    a.box("StoneDark", size=(1.2, 0.35, 0.25), loc=(0, -0.62, 2.3), round_e=0.6)
    a.cone("Stone", r=0.22, depth=0.95, loc=(0, -0.72, 1.85), rot=(-8, 0, 0), scale=(1, 1.4, 1), seg=4, tip=0.12, smooth=False)
    a.box("StoneDark", size=(0.62, 0.22, 0.12), loc=(0, -0.72, 1.18), round_e=0.6)
    a.box("Stone", size=(0.8, 0.4, 0.35), loc=(0, -0.55, 0.75), round_e=0.6)
    for sx in (-1, 1):
        a.box("StoneDark", size=(0.36, 0.12, 0.18), loc=(sx * 0.3, -0.64, 2.1), round_e=0.6)  # deep-set eyes
        a.sphere("Eye", r=0.07, loc=(sx * 0.3, -0.7, 2.1), seg=8, rings=6)
        a.box("Stone", size=(0.18, 0.4, 0.75), loc=(sx * 0.78, -0.05, 1.95), round_e=0.6)  # long ears
    a.cyl("Topknot", r=0.48, r2=0.52, depth=0.42, loc=(0, 0.05, 3.42), seg=16, smooth=False)
    a.sphere("Moss", r=0.35, loc=(0.4, 0.3, 3.0), scale=(1, 1, 0.3), seg=12, rings=6)
    for sx in (-1, 1):
        a.sphere("Feet", r=0.17, loc=(sx * 0.32, -0.2, 0.08), scale=(1, 1.5, 0.55), seg=12, rings=8)
        a.cyl("Feet", r=0.08, depth=0.2, loc=(sx * 0.32, -0.05, 0.22), seg=8)


@goober
def G19_OctoGoob(a: Asset):
    """A grinning octopus goober (six arms, it counts anyway) in a tiny crown."""
    a.colors.update(pal(Body="#E86AB0", Spots="#B33F86", Sucker="#FFC2E2", Gold="#FFC93C", Gem="#3DA5FF"))
    a.sphere("Body", r=1, loc=(0, 0.05, 1.55), scale=(0.95, 0.95, 1.0), seg=30, rings=16,
             deform=lambda c: Vector((c.x, c.y, c.z if c.z > -0.4 else -0.4 + (c.z + 0.4) * 0.6)))
    for x, z in ((-0.5, 2.1), (0.55, 1.95), (0.15, 2.4), (-0.2, 1.8)):
        a.sphere("Spots", r=0.12, loc=(x, 0.6, z), scale=(1, 0.5, 1), seg=10, rings=6)
    for k in range(6):
        ang = math.radians(-90 + (k - 2.5) * 50)
        pts = []
        for i in range(7):
            t = i / 6
            rr = 0.55 + t * 1.15
            curl = math.sin(t * math.pi) * 0.25
            pts.append((math.cos(ang) * rr + math.cos(ang + 1.57) * curl * 0.4, math.sin(ang) * rr + math.sin(ang + 1.57) * curl * 0.4,
                        0.85 - t * 0.7 + (0.35 * t * t if t > 0.75 else 0)))
        a.tube("Body", pts, r=0.22, r_end=0.06, sides=10)
        for i in (2, 4):
            px, py, pz = pts[i]
            a.sphere("Sucker", r=0.06, loc=(px, py, pz - 0.13), scale=(1, 1, 0.4), seg=8, rings=4)
    a.eye((-0.35, -0.78, 1.7), size=0.28, look=(0.2, 0.3))
    a.eye((0.35, -0.78, 1.7), size=0.28, look=(-0.2, 0.3))
    a.smile((0, -0.92, 1.3), width=0.5, thick=0.06)
    # tilted crown
    a.cyl("Gold", r=0.34, depth=0.25, loc=(0.25, 0, 2.6), rot=(0, 15, 0), seg=14, cap=False, smooth=False)
    for k in range(5):
        ang = k / 5 * 2 * math.pi
        a.cone("Gold", r=0.08, depth=0.2, loc=(0.25 + math.cos(ang) * 0.33 + 0.07, math.sin(ang) * 0.33, 2.8), rot=(0, 15, 0), seg=4, smooth=False)
    a.sphere("Gem", r=0.07, loc=(0.2, -0.33, 2.6), seg=8, rings=6)


@goober
def G20_SlimeKing(a: Asset):
    """A big drippy jelly king with a gold crown, red cape and sceptre."""
    a.colors.update(pal(Slime="#5BD45B", SlimeDark="#2E9E3A", Gold="#FFC93C", Gem="#E8364F", Cape="#B3122E", Fur="#F4F4F4"))

    def slime(c):
        z = c.z if c.z > -0.25 else -0.25 + (c.z + 0.25) * 0.35
        k = 1 + (0.18 if c.z < -0.1 else 0) * (1 - abs(c.z))
        return Vector((c.x * k, c.y * k, z))

    a.sphere("Slime", r=1, loc=(0, 0, 1.15), scale=(1.15, 1.05, 1.15), seg=32, rings=18, deform=slime)
    for k in range(9):  # drips running down the sides
        ang = k / 9 * 2 * math.pi + 0.2
        L = 0.1 + (k % 3) * 0.08
        a.sphere("SlimeDark", r=0.12, loc=(math.cos(ang) * 1.12, math.sin(ang) * 1.02, 0.95 - L), scale=(1, 1, 1.6 + L * 3), seg=10, rings=8)
    a.cyl("SlimeDark", r=1.45, r2=1.35, depth=0.08, loc=(0, 0, 0.04), seg=32)  # puddle
    a.sphere("SlimeDark", r=0.35, loc=(0.2, 0.15, 1.1), seg=14, rings=10)  # core blob
    a.eye((-0.38, -0.85, 1.45), size=0.27, look=(0.15, 0.1))
    a.eye((0.38, -0.85, 1.45), size=0.27, look=(-0.15, 0.1))
    a.smile((0, -0.98, 1.05), width=0.55, thick=0.06)
    # crown
    a.cyl("Gold", r=0.5, depth=0.32, loc=(0, 0, 2.38), seg=16, cap=False, smooth=False)
    a.torus("Fur", R=0.5, r=0.08, loc=(0, 0, 2.24), seg=24, sides=8)
    for k in range(6):
        ang = k / 6 * 2 * math.pi
        a.cone("Gold", r=0.12, depth=0.3, loc=(math.cos(ang) * 0.47, math.sin(ang) * 0.47, 2.68), seg=4, smooth=False)
        a.sphere("Gem", r=0.06, loc=(math.cos(ang) * 0.51, math.sin(ang) * 0.51, 2.38), seg=8, rings=6)
    # cape behind
    a.sphere("Cape", r=1, loc=(0, 0.45, 1.25), scale=(1.15, 0.7, 1.15), seg=24, rings=14,
             deform=lambda c: Vector((c.x, max(c.y, 0.25), c.z)))
    a.torus("Fur", R=0.8, r=0.13, loc=(0, 0.3, 1.75), rot=(-60, 0, 0), scale=(1, 0.7, 1), seg=24, sides=8, arc=180)
    # sceptre
    a.tube("Gold", [(1.2, -0.5, 0.2), (1.2, -0.5, 2.2)], r=0.05, sides=8)
    a.sphere("Gem", r=0.17, loc=(1.2, -0.5, 2.3), seg=14, rings=10)
    a.tube("Slime", [(1.0, -0.15, 1.2), (1.15, -0.45, 1.3)], r=0.12, sides=8)


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


@goober
def G22_GoldenNugget(a: Asset):
    """A smug solid-gold nugget in shades and a chunky chain."""
    a.colors.update(pal(Gold="#FFC93C", GoldDark="#C98A12", Shades="#111111", Chain="#FFE27A", Gem="#9EF0FF"))

    def nug(c):
        n = 1 + 0.12 * math.sin(c.x * 4.3 + 1.2) * math.cos(c.y * 3.7) + 0.08 * math.sin(c.z * 6.1 + 0.4)
        z = c.z if c.z > -0.35 else -0.35 + (c.z + 0.35) * 0.3
        return Vector((c.x * n, c.y * n, z * n))

    a.sphere("Gold", r=1, loc=(0, 0, 0.8), scale=(1.05, 0.95, 1.05), seg=20, rings=14, deform=nug, smooth=False)
    for sx in (-1, 1):
        a.box("Shades", size=(0.42, 0.1, 0.22), loc=(sx * 0.27, -0.95, 1.1), rot=(0, sx * -10, 0), round_e=0.4)
    a.box("Shades", size=(0.2, 0.06, 0.05), loc=(0, -0.98, 1.16))
    a.smile((0.12, -0.98, 0.7), width=0.36, thick=0.05, tilt=-14)
    # chain + medallion
    for k in range(14):
        ang = math.radians(200 + k * 10)
        a.torus("Chain", R=0.07, r=0.025, loc=(math.cos(ang) * 0.8, math.sin(ang) * 0.75, 0.48 + abs(math.cos(ang)) * 0.12),
                rot=(90, 0, math.degrees(ang) + (90 if k % 2 else 0)), seg=8, sides=5)
    a.cyl("Chain", r=0.2, depth=0.06, loc=(0, -0.93, 0.28), rot=(80, 0, 0), seg=16, smooth=False)
    a.sphere("Gem", r=0.08, loc=(0, -0.97, 0.28), seg=8, rings=6)
    for x, y, z in ((-0.95, -0.4, 1.7), (0.9, -0.5, 1.55), (0.4, -0.6, 2.0)):
        a.ico("Gem", r=0.09, loc=(x, y, z), sub=0)
    


@goober
def G23_WizardGoob(a: Asset):
    """A tiny wizard with an enormous starry hat, a long beard and a glowing staff."""
    a.colors.update(pal(Body="#6FA8FF", Hat="#5B2C9E", Star="#FFE27A", Beard="#F4F4F4", Wood="#8A5A2B", Orb="#7BE3FF"))
    rx, ry, rz, cz = 0.85, 0.8, 0.85, 0.95
    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=28, rings=16)
    # hat: wide brim + tall cone with a bent tip
    a.cyl("Hat", r=1.05, depth=0.08, loc=(0, 0, 1.62), seg=32)
    a.cone("Hat", r=0.68, depth=1.3, loc=(0, 0.05, 2.3), seg=28, tip=0.22)
    a.tube("Hat", [(0, 0.05, 2.9), (0.05, 0.15, 3.25), (0.3, 0.3, 3.45), (0.6, 0.35, 3.4)], r=0.21, r_end=0.04, sides=14)
    for k, (x, y, z, s) in enumerate(((0.35, -0.48, 2.15, 0.13), (-0.3, -0.5, 2.45, 0.1), (0.1, -0.38, 2.75, 0.08), (-0.45, -0.35, 1.9, 0.09))):
        for i in range(5):
            ang = math.radians(90 + i * 72)
            a.cone("Star", r=s * 0.35, depth=s, loc=(x + math.cos(ang) * s * 0.45, y, z + math.sin(ang) * s * 0.45),
                   rot=(0, -math.degrees(ang) + 90, 0), seg=4, smooth=False)
    a.eye((-0.27, front(-0.27, 1.3, rx, ry, rz, cz), 1.3), size=0.2, look=(0.2, 0.2))
    a.eye((0.27, front(0.27, 1.3, rx, ry, rz, cz), 1.3), size=0.2, look=(-0.2, 0.2))
    # beard flowing down
    a.cone("Beard", r=0.42, depth=1.0, loc=(0, -0.62, 0.6), rot=(180, 0, 0), scale=(1, 0.6, 1), seg=16, tip=0.05)
    a.sphere("Beard", r=0.35, loc=(0, -0.68, 1.05), scale=(1.2, 0.6, 0.6), seg=16, rings=8)
    # staff with glowing orb
    a.tube("Wood", [(-1.05, -0.4, 0.0), (-1.05, -0.4, 2.4)], r=0.06, sides=8)
    a.sphere("Orb", r=0.22, loc=(-1.05, -0.4, 2.55), seg=16, rings=10)
    a.torus("Wood", R=0.18, r=0.04, loc=(-1.05, -0.4, 2.4), seg=14, sides=6)
    a.tube("Body", [(-0.75, -0.1, 1.05), (-1.0, -0.38, 1.2)], r=0.09, sides=8)
    a.feet("Hat", spread=0.38, size=0.25, y=-0.15)


# ============================================================== SECRET
@goober
def G24_Glitch(a: Asset):
    """A goober that failed to load: misaligned voxels, missing-texture checker."""
    a.colors.update(pal(VoxA="#FF2BD6", VoxB="#111111", VoxC="#2BFFF0", Eye="#FFFFFF", Pupil="#111111"))
    rnd = __import__("random").Random(42)
    s = 0.36
    for ix in range(-3, 4):
        for iy in range(-2, 3):
            for iz in range(0, 7):
                cx, cy, cz = ix * s, iy * s, iz * s + s / 2
                d = (cx / 1.15) ** 2 + (cy / 0.8) ** 2 + ((cz - 1.2) / 1.2) ** 2
                if d > 1.0:
                    continue
                if d > 0.75 and rnd.random() < 0.35:
                    continue  # ragged edges
                slot = "VoxA" if (ix + iy + iz) % 2 == 0 else "VoxB"
                if rnd.random() < 0.1:
                    slot = "VoxC"
                jitter = (rnd.uniform(-0.05, 0.05), rnd.uniform(-0.05, 0.05), rnd.uniform(-0.03, 0.03))
                if rnd.random() < 0.06:
                    jitter = (rnd.uniform(-0.25, 0.25), rnd.uniform(-0.1, 0.1), rnd.uniform(-0.1, 0.1))
                a.box(slot, size=(s * 0.98, s * 0.98, s * 0.98), loc=(cx + jitter[0], cy + jitter[1], cz + jitter[2]))
    # one huge square eye
    a.box("Eye", size=(0.8, 0.1, 0.62), loc=(0.05, -0.92, 1.5))
    a.box("Pupil", size=(0.32, 0.1, 0.3), loc=(0.22, -0.98, 1.45))
    # floating stray voxels
    for x, y, z in ((1.4, -0.2, 2.2), (-1.35, 0.1, 1.9), (1.1, 0.3, 0.6), (-0.6, -0.6, 2.85)):
        a.box("VoxC", size=(0.2, 0.2, 0.2), loc=(x, y, z), rot=(rnd.uniform(0, 45), rnd.uniform(0, 45), 0))


@goober
def G25_ChaosGoob(a: Asset):
    """An event-only goober from the Chaos Rift: three eyes, horns, orbiting rings."""
    a.colors.update(pal(Body="#2A1245", Glow="#C04BFF", Ring="#FF3DA5", Horn="#14081F", Eye="#FFF06A", Pupil="#14081F"))
    a.sphere("Body", r=1, loc=(0, 0, 1.75), scale=(0.9, 0.85, 1.05), seg=30, rings=18, deform=taper(top=0.9, bottom=0.55))
    # wispy tail instead of feet (it floats)
    a.tube("Body", [(0, 0.05, 0.85), (0.15, 0.1, 0.5), (-0.1, 0.2, 0.25), (0.05, 0.35, 0.05)], r=0.42, r_end=0.04, sides=12)
    for sx in (-1, 1):
        a.tube("Horn", [(sx * 0.45, 0, 2.6), (sx * 0.7, 0, 3.0), (sx * 0.65, 0.1, 3.3)], r=0.13, r_end=0.02, sides=8)
    # three stacked eyes, the middle one biggest
    a.eye((0, -0.8, 2.25), size=0.2, look=(0, 0.2))
    a.eye((0, -0.85, 1.85), size=0.27, look=(0, 0))
    a.eye((0, -0.82, 1.42), size=0.18, look=(0, -0.2))
    a.smile((0, -0.7, 1.08), width=0.4, thick=0.05)
    for z in (0.95,):
        for t in range(5):
            a.cone("Pupil", r=0.04, depth=0.1, loc=(-0.14 + t * 0.07, -0.73, z + 0.04), rot=(180, 0, 0), seg=4, smooth=False)
    # orbiting rings
    a.torus("Ring", R=1.35, r=0.05, loc=(0, 0, 1.75), rot=(70, 20, 0), seg=40, sides=6)
    a.torus("Glow", R=1.15, r=0.04, loc=(0, 0, 1.75), rot=(-60, -30, 0), seg=40, sides=6)
    for k in range(3):
        ang = k / 3 * 2 * math.pi
        a.sphere("Glow", r=0.1, loc=(math.cos(ang) * 1.4, math.sin(ang) * 0.5, 1.75 + math.sin(ang) * 1.1), seg=10, rings=6)


# ========================================================== BUILD/EXPORT
def build(ids=None, collection_name="Goobers", spacing=4.5):
    import bpy
    col = clear_collection(collection_name)
    ids = ids or sorted(ROSTER.keys())
    report = []
    for i, gid in enumerate(ids):
        a = Asset(gid, collection=col)
        ROSTER[gid](a)
        root, objs = a.build(offset=(i * spacing, 0, 0))
        report.append((gid, tri_count(objs), len(objs)))
    return report


def build_all():
    return build(list(ROSTER.keys()))
