"""Snag A Goober - Halloween update roster (H01-H16), modelled in code.

Same conventions as goobers.py: 1 unit = 1 stud, front faces -Y, feet on
Z = 0, one mesh per material slot named <AssetId>__<Slot>. Eyes and pupils are
recorded as native-part specs (goober_lib.NATIVE_SLOTS), never exported as
meshes (Roblox moderation rejects paired white spheres).

Run inside Blender:
    exec(open(r"<repo>/Assets/BlenderSource/scripts/halloween_goobers.py").read())
    build_all()
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


def front(x, z, rx, ry, rz, cz, cy=0.0, inset=0.04):
    k = 1 - (x / rx) ** 2 - ((z - cz) / rz) ** 2
    return cy - ry * math.sqrt(max(0.0, k)) + inset


def pal(**kw):
    return {k: hex_rgb(v) for k, v in kw.items()}


ROSTER = {}


def goober(fn):
    ROSTER[fn.__name__] = fn
    return fn


def ribbed(c, n=8, depth=0.07):
    """Pumpkin ribs: pinch the surface along n meridians."""
    ang = math.atan2(c.y, c.x)
    k = 1 - depth * (0.5 + 0.5 * math.cos(ang * n))
    return Vector((c.x * k, c.y * k, c.z))


def jack_face(a, cz, ry, slot="Carve", scale=1.0, y_off=0.0):
    """Carved triangle eyes + zig-zag mouth on the front of a pumpkin."""
    s = scale
    for sx in (-1, 1):
        a.cone(slot, r=0.17 * s, depth=0.12, loc=(sx * 0.32 * s, -ry * 0.93 + y_off, cz + 0.22 * s), rot=(90, 0, 0), seg=3, smooth=False)
    for k in range(5):
        x = (-0.4 + k * 0.2) * s
        z = cz - 0.2 * s + (0.06 * s if k % 2 else -0.04 * s)
        a.box(slot, size=(0.17 * s, 0.1, 0.1 * s), loc=(x, -ry * 0.95 + y_off, z), rot=(0, 30 if k % 2 else -30, 0))


# =============================================================== COMMON
@goober
def H01_PumpkinPip(a: Asset):
    """A round little pumpkin with a curly stem, a leaf and a gap-toothed grin."""
    a.colors.update(pal(Body="#FF8A1F", Stem="#5A3A1A", Leaf="#5CC24A", Mouth="#3B1A05"))
    rx, ry, rz, cz = 1.05, 1.0, 0.82, 0.85
    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=40, rings=18, deform=lambda c: ribbed(c, 8, 0.08))
    a.tube("Stem", [(0, 0, 1.6), (0.05, 0, 1.85), (0.2, 0.05, 2.0), (0.32, 0.12, 1.92)], r=0.11, r_end=0.05, sides=8)
    a.sphere("Leaf", r=0.3, loc=(-0.25, 0.05, 1.68), scale=(1.2, 0.5, 0.12), rot=(0, -20, 30), seg=12, rings=6)
    a.eye((-0.33, front(-0.33, 1.1, rx, ry, rz, cz), 1.1), size=0.24, look=(0.2, 0.3))
    a.eye((0.33, front(0.33, 1.1, rx, ry, rz, cz), 1.1), size=0.24, look=(-0.2, 0.3))
    a.smile((0, front(0, 0.62, rx, ry, rz, cz) + 0.02, 0.62), width=0.55, thick=0.07)
    a.box("Mouth", size=(0.12, 0.08, 0.1), loc=(0.08, front(0.08, 0.52, rx, ry, rz, cz), 0.5))
    a.feet("Stem", spread=0.48, size=0.26, y=-0.2)


@goober
def H02_CandyCorny(a: Asset):
    """A tall candy-corn cone in white, orange and yellow bands, very pleased with itself."""
    a.colors.update(pal(Yellow="#FFD23C", Orange="#FF8A1F", Tip="#FFF6E0", Mouth="#5A2A0A", Feet="#C9601A"))
    a.cyl("Yellow", r=0.95, depth=0.7, loc=(0, 0, 0.55), seg=28, scale=(1, 0.85, 1))
    a.cone("Orange", r=0.95, depth=1.2, loc=(0, 0, 1.5), seg=28, tip=0.48, scale=(1, 0.85, 1))
    a.cone("Tip", r=0.47, depth=0.9, loc=(0, 0, 2.55), seg=24, tip=0.06, scale=(1, 0.85, 1))
    a.sphere("Yellow", r=0.95, loc=(0, 0, 0.22), scale=(1, 0.85, 0.3), seg=28, rings=8)
    a.eye((-0.27, -0.72, 1.45), size=0.21, look=(0.1, 0.2))
    a.eye((0.27, -0.72, 1.45), size=0.21, look=(-0.1, 0.2))
    a.smile((0, -0.8, 1.05), width=0.45, thick=0.06)
    a.feet("Feet", spread=0.5, size=0.26, y=-0.2)


@goober
def H03_BooBlob(a: Asset):
    """A small floating sheet-ghost with a wavy hem and tiny waving arms."""
    a.colors.update(pal(Body="#F2F4FF", Mouth="#2A2140", Cheek="#FF9EC7"))
    rx, ry, rz, cz = 0.9, 0.85, 1.0, 1.55

    def sheet(c):
        if c.z < 0:
            wave = 0.12 * math.sin(math.atan2(c.y, c.x) * 6)
            return Vector((c.x * (1 + 0.25 * -c.z), c.y * (1 + 0.25 * -c.z), c.z * 1.25 + wave))
        return c
    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=36, rings=18, deform=sheet)
    for sx in (-1, 1):
        a.tube("Body", [(sx * 0.75, -0.1, 1.45), (sx * 1.05, -0.2, 1.65), (sx * 1.15, -0.25, 1.95)], r=0.16, r_end=0.07, sides=10)
    a.eye((-0.3, front(-0.3, 1.85, rx, ry, rz, cz), 1.85), size=0.22, look=(0, 0.1))
    a.eye((0.3, front(0.3, 1.85, rx, ry, rz, cz), 1.85), size=0.22, look=(0, 0.1))
    a.sphere("Mouth", r=0.13, loc=(0, front(0, 1.45, rx, ry, rz, cz), 1.45), scale=(1, 0.4, 1.3), seg=12, rings=8)
    for sx in (-1, 1):
        a.sphere("Cheek", r=0.1, loc=(sx * 0.52, front(sx * 0.52, 1.6, rx, ry, rz, cz) + 0.02, 1.6), scale=(1, 0.3, 0.7), seg=10, rings=6)


# ============================================================= UNCOMMON
@goober
def H04_BatBrat(a: Asset):
    """A fuzzy purple bat with huge ears, fangs and leathery scalloped wings."""
    a.colors.update(pal(Body="#5E3A8C", Wing="#2E1B4A", Ear="#FF8FC7", Fang="#FFFFFF", Feet="#2E1B4A"))
    rx, ry, rz, cz = 0.8, 0.75, 0.85, 1.25
    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=30, rings=16)
    for sx in (-1, 1):
        a.cone("Body", r=0.32, depth=0.75, loc=(sx * 0.42, 0.05, 2.15), rot=(0, sx * -18, 0), seg=12, tip=0.02)
        a.cone("Ear", r=0.18, depth=0.5, loc=(sx * 0.43, -0.1, 2.12), rot=(0, sx * -18, 0), seg=10, tip=0.02, scale=(1, 0.4, 1))
        # scalloped wing: three fingers + membrane blobs
        for k, (wx, wz) in enumerate(((1.3, 1.65), (1.55, 1.2), (1.35, 0.75))):
            a.tube("Wing", [(sx * 0.7, 0.1, 1.3), (sx * wx, 0.15, wz)], r=0.05, sides=6)
            a.sphere("Wing", r=0.4, loc=(sx * (0.7 + wx) / 2, 0.15, (1.3 + wz) / 2), scale=(1.2, 0.12, 0.7), rot=(0, sx * (30 - k * 30), 0), seg=14, rings=6)
    a.eye((-0.28, front(-0.28, 1.45, rx, ry, rz, cz), 1.45), size=0.23, look=(0.15, 0.1))
    a.eye((0.28, front(0.28, 1.45, rx, ry, rz, cz), 1.45), size=0.23, look=(-0.15, 0.1))
    for sx in (-1, 1):
        a.cone("Fang", r=0.06, depth=0.16, loc=(sx * 0.12, front(sx * 0.12, 1.02, rx, ry, rz, cz) - 0.02, 1.0), rot=(180, 0, 0), seg=6)
    a.smile((0, front(0, 1.08, rx, ry, rz, cz) + 0.02, 1.08), width=0.38, slot="Wing", thick=0.045)
    a.feet("Feet", spread=0.32, size=0.2, y=-0.1)


@goober
def H05_Midnight(a: Asset):
    """A sleek black-cat goober with green eyes, a curled tail and a bell collar."""
    a.colors.update(pal(Body="#1E1A2B", Inner="#FF8FC7", Collar="#E8364F", Bell="#FFC93C", Nose="#FF8FC7", Whisker="#D9D9E8"))
    rx, ry, rz, cz = 0.85, 0.8, 0.95, 1.0
    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=30, rings=16, deform=taper(top=0.92, bottom=1.0))
    for sx in (-1, 1):
        a.cone("Body", r=0.3, depth=0.55, loc=(sx * 0.45, 0.0, 1.95), rot=(0, sx * -15, 0), seg=4, tip=0.02, smooth=False)
        a.cone("Inner", r=0.16, depth=0.36, loc=(sx * 0.45, -0.12, 1.9), rot=(0, sx * -15, 0), seg=4, tip=0.02, smooth=False, scale=(1, 0.3, 1))
        for k in (-1, 1):
            a.tube("Whisker", [(sx * 0.3, front(sx * 0.3, 1.0, rx, ry, rz, cz) - 0.02, 1.0 + k * 0.04), (sx * 0.85, -0.75, 1.02 + k * 0.12)], r=0.015, sides=4)
    a.eye((-0.3, front(-0.3, 1.32, rx, ry, rz, cz), 1.32), size=0.24, look=(0.1, 0.0), pupil=0.4)
    a.eye((0.3, front(0.3, 1.32, rx, ry, rz, cz), 1.32), size=0.24, look=(-0.1, 0.0), pupil=0.4)
    a.cone("Nose", r=0.07, depth=0.07, loc=(0, front(0, 1.06, rx, ry, rz, cz) - 0.02, 1.06), rot=(-90, 0, 0), seg=3)
    a.torus("Collar", R=0.72, r=0.07, loc=(0, 0.02, 0.62), seg=28, sides=8)
    a.sphere("Bell", r=0.12, loc=(0, -0.76, 0.52), seg=12, rings=8)
    a.tube("Body", [(0.2, 0.7, 0.35), (0.6, 0.95, 0.6), (0.75, 0.9, 1.15), (0.5, 0.75, 1.45), (0.3, 0.8, 1.3)], r=0.12, r_end=0.07, sides=8)
    a.feet("Body", spread=0.42, size=0.25, y=-0.15)


@goober
def H06_MummyWrap(a: Asset):
    """A mummy wrapped in loose bandages with one peeking eye and a trailing strip."""
    a.colors.update(pal(Body="#E8DFC4", Wrap="#CFC3A0", Dark="#3A2E22", Mouth="#3A2E22"))
    rx, ry, rz, cz = 0.85, 0.8, 1.05, 1.1
    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=30, rings=18)
    for k in range(7):
        z = 0.35 + k * 0.27
        tilt = 12 if k % 2 else -9
        rr = math.sqrt(max(0.05, 1 - ((z - cz) / rz) ** 2))
        a.torus("Wrap", R=rx * rr * 1.0, r=0.06, loc=(0, 0, z), rot=(tilt, 0, k * 25), scale=(1, ry / rx, 1), seg=26, sides=5)
    a.box("Dark", size=(0.95, 0.1, 0.26), loc=(0, front(0, 1.45, rx, ry, rz, cz) - 0.01, 1.45), round_e=0.5)
    a.eye((-0.22, front(-0.22, 1.45, rx, ry, rz, cz) - 0.04, 1.45), size=0.18, look=(0.2, 0))
    a.tube("Wrap", [(0.6, -0.3, 1.0), (0.95, -0.4, 0.75), (1.1, -0.2, 0.35), (1.25, 0.05, 0.1)], r=0.06, sides=5)
    a.smile((0.05, front(0.05, 0.9, rx, ry, rz, cz) + 0.02, 0.9), width=0.32, thick=0.04, frown=True)
    a.feet("Wrap", spread=0.4, size=0.25, y=-0.1)


# ================================================================= RARE
@goober
def H07_Bonejangles(a: Asset):
    """A dancing skeleton goober: skull head, ribcage, bone arms and a bow tie."""
    a.colors.update(pal(Bone="#F3EEDD", Socket="#2A2140", Tie="#FF8A1F", Joint="#D9D1B8"))
    # skull
    a.sphere("Bone", r=0.72, loc=(0, 0, 2.15), scale=(1, 0.95, 0.9), seg=28, rings=16)
    a.box("Bone", size=(0.75, 0.6, 0.35), loc=(0, -0.05, 1.62), round_e=0.6)
    for sx in (-1, 1):
        a.sphere("Socket", r=0.2, loc=(sx * 0.26, -0.6, 2.2), scale=(1, 0.4, 1.15), seg=14, rings=8)
    a.cone("Socket", r=0.08, depth=0.12, loc=(0, -0.66, 1.92), rot=(90, 0, 0), seg=3, smooth=False)
    for k in range(5):
        a.box("Socket", size=(0.03, 0.08, 0.14), loc=(-0.24 + k * 0.12, -0.36, 1.62))
    # neck + ribcage
    a.cyl("Joint", r=0.12, depth=0.3, loc=(0, 0, 1.38), seg=10)
    a.cyl("Bone", r=0.07, depth=0.95, loc=(0, 0.1, 0.85), seg=8)
    for k in range(4):
        z = 1.15 - k * 0.2
        w = 0.48 - k * 0.04
        a.torus("Bone", R=w, r=0.045, loc=(0, 0, z), scale=(1, 0.65, 1), seg=22, sides=5, arc=300, rot=(0, 0, 240))
    a.box("Bone", size=(0.75, 0.45, 0.2), loc=(0, 0, 0.32), round_e=0.6)  # pelvis
    # bow tie
    for sx in (-1, 1):
        a.cone("Tie", r=0.14, depth=0.24, loc=(sx * 0.12, -0.42, 1.32), rot=(0, sx * 90, 0), seg=3, smooth=False)
    a.sphere("Tie", r=0.06, loc=(0, -0.43, 1.32), seg=8, rings=6)
    # arms in a dance pose
    a.tube("Bone", [(-0.45, 0, 1.15), (-0.85, -0.1, 1.45), (-0.95, -0.15, 1.9)], r=0.06, sides=6)
    a.tube("Bone", [(0.45, 0, 1.15), (0.85, -0.1, 0.9), (1.05, -0.2, 0.65)], r=0.06, sides=6)
    a.sphere("Joint", r=0.12, loc=(-0.95, -0.15, 1.98), seg=10, rings=6)
    a.sphere("Joint", r=0.12, loc=(1.07, -0.2, 0.58), seg=10, rings=6)
    for sx in (-1, 1):
        a.tube("Bone", [(sx * 0.22, 0, 0.3), (sx * 0.3, -0.05, 0.08)], r=0.07, sides=6)
    a.feet("Joint", spread=0.32, size=0.22, y=-0.15)


@goober
def H08_Zomblob(a: Asset):
    """A green zombie blob with stitches, a patchy shirt and arms stuck forward."""
    a.colors.update(pal(Body="#8FC46A", Patch="#5C8A45", Shirt="#6A5ACD", Stitch="#2A2A2A", Brain="#FF9EC7", Mouth="#2A2A2A"))
    rx, ry, rz, cz = 0.95, 0.9, 1.0, 1.1
    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=30, rings=16)
    a.sphere("Shirt", r=1, loc=(0, 0, 0.82), scale=(rx * 1.03, ry * 1.03, 0.55), seg=30, rings=12)
    a.sphere("Patch", r=0.22, loc=(0.45, front(0.45, 1.45, rx, ry, rz, cz) + 0.02, 1.45), scale=(1, 0.2, 0.8), seg=12, rings=6)
    # exposed brain bump + stitches across the forehead
    a.sphere("Brain", r=0.38, loc=(-0.25, 0.1, 1.98), scale=(1.1, 1, 0.55), seg=16, rings=8)
    for k in range(5):
        a.box("Stitch", size=(0.03, 0.06, 0.16), loc=(-0.55 + k * 0.12, front(-0.55 + k * 0.12, 1.72, rx, ry, rz, cz) + 0.01, 1.72), rot=(0, 20, 0))
    a.tube("Stitch", [(-0.65, front(-0.65, 1.72, rx, ry, rz, cz), 1.72), (0.0, front(0.0, 1.74, rx, ry, rz, cz) - 0.03, 1.74)], r=0.02, sides=4)
    a.eye((-0.3, front(-0.3, 1.38, rx, ry, rz, cz), 1.38), size=0.2, look=(0.4, -0.2))
    a.eye((0.32, front(0.32, 1.32, rx, ry, rz, cz), 1.32), size=0.26, look=(-0.3, 0.3))
    a.smile((0, front(0, 1.0, rx, ry, rz, cz) + 0.02, 1.0), width=0.5, thick=0.05, tilt=-10)
    for sx in (-1, 1):
        a.tube("Body", [(sx * 0.6, -0.4, 1.0), (sx * 0.55, -1.0, 1.05), (sx * 0.5, -1.35, 1.0)], r=0.15, r_end=0.12, sides=8)
    a.feet("Patch", spread=0.45, size=0.27, y=-0.15)


@goober
def H09_Hex(a: Asset):
    """A witch goober with a crooked pointy hat, a buckle, a broom and a bubbling look."""
    a.colors.update(pal(Body="#9BE07A", Hat="#2A1245", Band="#FF8A1F", Buckle="#FFC93C", Hair="#E8364F", Wood="#7A4A22", Straw="#E8C35A", Mouth="#2A1245"))
    rx, ry, rz, cz = 0.85, 0.8, 0.85, 0.95
    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=28, rings=16)
    a.cyl("Hat", r=1.1, depth=0.08, loc=(0, 0, 1.6), seg=32)
    a.cone("Hat", r=0.62, depth=1.15, loc=(0, 0.05, 2.2), seg=26, tip=0.18)
    a.tube("Hat", [(0, 0.05, 2.72), (-0.1, 0.15, 3.05), (-0.4, 0.3, 3.2)], r=0.17, r_end=0.03, sides=12)
    a.cyl("Band", r=0.63, depth=0.14, loc=(0, 0.04, 1.72), seg=26)
    a.box("Buckle", size=(0.24, 0.06, 0.18), loc=(0, -0.6, 1.72))
    for sx in (-1, 1):
        a.tube("Hair", [(sx * 0.62, -0.1, 1.55), (sx * 0.85, -0.05, 1.1), (sx * 0.8, 0.0, 0.75)], r=0.12, r_end=0.05, sides=8)
    a.eye((-0.27, front(-0.27, 1.22, rx, ry, rz, cz), 1.22), size=0.21, look=(0.3, 0.1))
    a.eye((0.27, front(0.27, 1.22, rx, ry, rz, cz), 1.22), size=0.21, look=(0.3, 0.1))
    a.cone("Body", r=0.09, depth=0.3, loc=(0.05, front(0.05, 1.0, rx, ry, rz, cz) - 0.12, 1.0), rot=(80, 0, 0), seg=8)  # pointy nose
    a.smile((0, front(0, 0.78, rx, ry, rz, cz) + 0.02, 0.78), width=0.4, thick=0.045, tilt=8)
    # broom leaning on the side
    a.tube("Wood", [(1.0, -0.1, 0.05), (1.15, -0.1, 2.3)], r=0.05, sides=6)
    a.cone("Straw", r=0.3, depth=0.6, loc=(1.0, -0.1, 0.25), rot=(180, 0, 0), seg=12, tip=0.08)
    a.feet("Hat", spread=0.38, size=0.24, y=-0.15)


# ================================================================= EPIC
@goober
def H10_CountGoobula(a: Asset):
    """A vampire goober: slicked widow's peak, high-collared cape, fangs and a red gem."""
    a.colors.update(pal(Body="#D9D2F2", Hair="#1A1426", Cape="#1A1426", Lining="#C2182B", Gem="#FF2B4E", Fang="#FFFFFF", Mouth="#1A1426"))
    rx, ry, rz, cz = 0.82, 0.78, 0.92, 1.25
    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=30, rings=18)
    a.sphere("Hair", r=1, loc=(0, 0.05, cz + 0.25), scale=(rx * 1.04, ry * 1.04, rz * 0.75), seg=30, rings=14,
             deform=lambda c: c if c.z > 0.15 or c.y > -0.2 else Vector((c.x, c.y, 0.15 + (c.z - 0.15) * 0.2)))
    a.cone("Hair", r=0.15, depth=0.35, loc=(0, -0.72, 1.62), rot=(180, 0, 0), seg=4, scale=(1, 0.3, 1))  # widow's peak
    # cape: a wide flared cone behind with a tall collar
    a.cone("Cape", r=1.25, depth=1.7, loc=(0, 0.62, 0.85), seg=24, tip=0.65, scale=(1, 0.42, 1))
    a.cone("Lining", r=1.18, depth=1.65, loc=(0, 0.6, 0.86), seg=24, tip=0.6, scale=(1, 0.4, 1))
    a.sphere("Body", r=1, loc=(0, 0, 0.55), scale=(0.75, 0.7, 0.5), seg=24, rings=12)  # torso under the head
    for sx in (-1, 1):
        a.box("Cape", size=(0.6, 0.08, 0.8), loc=(sx * 0.55, 0.15, 1.85), rot=(-15, 0, sx * 25), round_e=0.3)
    a.eye((-0.28, front(-0.28, 1.4, rx, ry, rz, cz), 1.4), size=0.21, look=(0.1, -0.1), pupil=0.45)
    a.eye((0.28, front(0.28, 1.4, rx, ry, rz, cz), 1.4), size=0.21, look=(-0.1, -0.1), pupil=0.45)
    a.smile((0, front(0, 1.02, rx, ry, rz, cz) + 0.02, 1.02), width=0.42, thick=0.045)
    for sx in (-1, 1):
        a.cone("Fang", r=0.05, depth=0.15, loc=(sx * 0.1, front(sx * 0.1, 0.97, rx, ry, rz, cz) - 0.02, 0.94), rot=(180, 0, 0), seg=6)
    a.ico("Gem", r=0.12, loc=(0, -0.72, 0.62), sub=0)
    a.feet("Cape", spread=0.38, size=0.24, y=-0.1)


@goober
def H11_ScarecrowSam(a: Asset):
    """A burlap-sack scarecrow with a patched floppy hat, straw tufts and a crow friend."""
    a.colors.update(pal(Sack="#D9B26F", Hat="#7A4A22", Patch="#5CC24A", Straw="#F2D16B", Stitch="#3A2412", Crow="#1A1426", Beak="#FFB020", Shirt="#C2452B"))
    rx, ry, rz, cz = 0.85, 0.8, 0.9, 1.65
    a.sphere("Sack", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=26, rings=14, deform=taper(top=0.95, bottom=0.75))
    a.cyl("Shirt", r=0.6, depth=1.0, loc=(0, 0, 0.75), seg=20, scale=(1, 0.8, 1))
    a.tube("Shirt", [(-1.4, 0, 1.0), (1.4, 0, 1.0)], r=0.17, sides=8)  # arms on the crossbar
    for sx in (-1, 1):
        for k in range(3):
            a.cone("Straw", r=0.06, depth=0.35, loc=(sx * (1.5 + k * 0.03), -0.05 + k * 0.05, 1.0 - 0.1 + k * 0.1), rot=(0, sx * (80 + k * 10), 0), seg=5)
    a.cyl("Hat", r=1.05, depth=0.08, loc=(0, 0, 2.38), seg=28, rot=(6, -4, 0))
    a.cone("Hat", r=0.6, depth=0.7, loc=(0, 0.05, 2.72), seg=24, tip=0.3, rot=(10, 0, 0))
    a.box("Patch", size=(0.25, 0.06, 0.22), loc=(0.25, -0.5, 2.6), rot=(10, 0, 15))
    a.eye((-0.27, front(-0.27, 1.8, rx, ry, rz, cz), 1.8), size=0.19, look=(0.1, 0))
    a.eye((0.27, front(0.27, 1.8, rx, ry, rz, cz), 1.8), size=0.19, look=(-0.1, 0))
    # stitched smile
    a.tube("Stitch", [(-0.35, front(-0.35, 1.38, rx, ry, rz, cz), 1.4), (0, front(0, 1.3, rx, ry, rz, cz) - 0.02, 1.3), (0.35, front(0.35, 1.38, rx, ry, rz, cz), 1.4)], r=0.025, sides=4)
    for k in range(5):
        x = -0.28 + k * 0.14
        a.box("Stitch", size=(0.025, 0.06, 0.12), loc=(x, front(x, 1.34, rx, ry, rz, cz) - 0.02, 1.34))
    # crow perched on the left arm
    a.sphere("Crow", r=0.22, loc=(-1.05, 0, 1.3), scale=(1, 1.3, 1), seg=14, rings=8)
    a.sphere("Crow", r=0.14, loc=(-1.05, -0.2, 1.48), seg=12, rings=8)
    a.cone("Beak", r=0.05, depth=0.16, loc=(-1.05, -0.36, 1.48), rot=(90, 0, 0), seg=6)
    a.tube("Stitch", [(-0.15, 0, 0.25), (-0.18, 0, 0.0)], r=0.06, sides=6)
    a.tube("Stitch", [(0.15, 0, 0.25), (0.18, 0, 0.0)], r=0.06, sides=6)
    a.feet("Hat", spread=0.25, size=0.18, y=-0.1)


@goober
def H12_LanternLurker(a: Asset):
    """A cursed iron lantern with a ghostly green flame-goober glowing inside."""
    a.colors.update(pal(Iron="#3A3446", Glass="#7BFFB0", Flame="#C8FF5A", Ring="#FFB020", Mouth="#1E3A22"))
    a.box("Iron", size=(1.3, 1.3, 0.22), loc=(0, 0, 0.12), round_e=0.3)
    a.box("Iron", size=(1.1, 1.1, 0.18), loc=(0, 0, 2.05), round_e=0.3)
    a.cone("Iron", r=0.85, depth=0.6, loc=(0, 0, 2.45), seg=4, tip=0.12, rot=(0, 0, 45), smooth=False)
    a.torus("Ring", R=0.25, r=0.06, loc=(0, 0, 2.95), rot=(90, 0, 0), seg=16, sides=6)
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.cyl("Iron", r=0.07, depth=1.85, loc=(sx * 0.55, sy * 0.55, 1.08), seg=8)
    # ghost-flame goober body inside the glass
    a.sphere("Glass", r=0.48, loc=(0, 0, 1.05), scale=(1, 1, 1.25), seg=24, rings=14,
             deform=lambda c: c if c.z < 0.2 else Vector((c.x * (1 - 0.5 * c.z), c.y * (1 - 0.5 * c.z), c.z * 1.4)))
    a.cone("Flame", r=0.22, depth=0.55, loc=(0.05, 0, 1.82), seg=12, tip=0.02)
    a.eye((-0.17, -0.42, 1.12), size=0.14, look=(0, 0.2))
    a.eye((0.17, -0.42, 1.12), size=0.14, look=(0, 0.2))
    a.smile((0, -0.46, 0.9), width=0.22, thick=0.03)
    a.feet("Iron", spread=0.45, size=0.18, y=-0.15)


# ============================================================ LEGENDARY
@goober
def H13_DollyDread(a: Asset):
    """A haunted porcelain doll: cracked face, button eyes, pigtails and a frilly dress."""
    a.colors.update(pal(Face="#F7E9E4", Hair="#3B2416", Dress="#7B2FBF", Frill="#F2F4FF", Bow="#FF3DA5", Crack="#5A4A55", Cheek="#FF9EC7", Button="#1A1426"))
    rx, ry, rz, cz = 0.75, 0.72, 0.78, 2.3
    a.sphere("Face", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=30, rings=16)
    a.sphere("Hair", r=1, loc=(0, 0.08, cz + 0.1), scale=(rx * 1.07, ry * 1.06, rz * 0.92), seg=30, rings=14,
             deform=lambda c: c if c.y > -0.35 or c.z > 0.4 else Vector((c.x, c.y, 0.4 + (c.z - 0.4) * 0.2)))
    for sx in (-1, 1):
        a.tube("Hair", [(sx * 0.7, 0.05, 2.45), (sx * 1.0, 0.1, 2.1), (sx * 0.95, 0.15, 1.65)], r=0.17, r_end=0.08, sides=10)
        a.sphere("Bow", r=0.16, loc=(sx * 0.78, 0.0, 2.55), scale=(1.4, 0.6, 1), seg=12, rings=6)
        a.sphere("Cheek", r=0.11, loc=(sx * 0.4, front(sx * 0.4, 2.1, rx, ry, rz, cz) + 0.02, 2.1), scale=(1, 0.3, 0.7), seg=10, rings=6)
        # button eyes (dark discs, not white spheres)
        a.cyl("Button", r=0.15, depth=0.06, loc=(sx * 0.26, front(sx * 0.26, 2.4, rx, ry, rz, cz) - 0.02, 2.4), rot=(90, 0, 0), seg=16)
        for k in range(2):
            a.cyl("Frill", r=0.025, depth=0.07, loc=(sx * 0.26 + (k - 0.5) * 0.09, front(sx * 0.26, 2.4, rx, ry, rz, cz) - 0.05, 2.4), rot=(90, 0, 0), seg=6)
    a.tube("Crack", [(0.15, front(0.15, 2.85, rx, ry, rz, cz), 2.85), (0.3, front(0.3, 2.65, rx, ry, rz, cz) - 0.02, 2.65), (0.18, front(0.18, 2.55, rx, ry, rz, cz) - 0.02, 2.55), (0.35, front(0.35, 2.35, rx, ry, rz, cz) - 0.02, 2.35)], r=0.018, sides=4)
    a.smile((0, front(0, 1.98, rx, ry, rz, cz) + 0.02, 1.98), width=0.3, thick=0.035, slot="Crack")
    # dress + frills
    a.cone("Dress", r=0.95, depth=1.45, loc=(0, 0, 0.85), seg=28, tip=0.4)
    a.torus("Frill", R=0.95, r=0.09, loc=(0, 0, 0.16), seg=32, sides=6)
    a.torus("Frill", R=0.42, r=0.07, loc=(0, 0, 1.55), seg=24, sides=6)
    for k in range(3):
        a.sphere("Button", r=0.06, loc=(0, -0.55 + k * -0.08, 1.3 - k * 0.3), seg=8, rings=6)
    for sx in (-1, 1):
        a.tube("Face", [(sx * 0.4, 0, 1.4), (sx * 0.75, -0.2, 1.05)], r=0.09, sides=8)
    a.feet("Button", spread=0.32, size=0.2, y=-0.1)


@goober
def H14_HeadlessGoobman(a: Asset):
    """The Headless Goobman: a tall caped knight-blob holding its own grinning jack-o'-lantern head."""
    a.colors.update(pal(Body="#5A4F7A", Armor="#8C84A8", Belt="#2A2440", Buckle="#FFC93C", Cape="#120E1F", Lining="#FF6A00", Pumpkin="#FF8A1F", Carve="#FFE27A", Stem="#3A5A1A", Flame="#7BFF9E"))
    # tall torso with a flat (headless) top
    a.sphere("Body", r=1, loc=(0, 0, 1.15), scale=(0.8, 0.72, 1.05), seg=28, rings=16,
             deform=lambda c: c if c.z < 0.75 else Vector((c.x, c.y, 0.75 + (c.z - 0.75) * 0.3)))
    a.cyl("Armor", r=0.5, depth=0.22, loc=(0, 0, 2.0), seg=20)  # neck plate
    a.cone("Flame", r=0.34, depth=0.75, loc=(0, 0, 2.45), seg=14, tip=0.02)
    a.cone("Flame", r=0.18, depth=0.5, loc=(0.14, -0.04, 2.4), rot=(0, 15, 0), seg=10, tip=0.02)
    for sx in (-1, 1):
        a.sphere("Armor", r=0.32, loc=(sx * 0.72, 0, 1.78), scale=(1.1, 1, 0.75), seg=16, rings=10)  # pauldrons
    a.torus("Belt", R=0.8, r=0.09, loc=(0, 0, 0.9), scale=(1, 0.92, 1), seg=28, sides=6)
    a.box("Buckle", size=(0.26, 0.08, 0.2), loc=(0, -0.7, 0.9))
    # cape hanging behind, flared at the bottom
    a.cone("Cape", r=1.25, depth=2.0, loc=(0, 0.62, 1.05), seg=24, tip=0.6, scale=(1, 0.42, 1))
    a.cone("Lining", r=1.17, depth=1.95, loc=(0, 0.6, 1.05), seg=24, tip=0.55, scale=(1, 0.4, 1))
    # arms holding the head out in front
    pcz, pr = 1.35, 0.5
    for sx in (-1, 1):
        a.tube("Armor", [(sx * 0.75, -0.05, 1.65), (sx * 0.75, -0.55, 1.4), (sx * 0.45, -0.9, 1.25)], r=0.13, r_end=0.11, sides=8)
    a.sphere("Pumpkin", r=pr, loc=(0, -1.05, pcz), scale=(1.1, 1, 0.9), seg=28, rings=14, deform=lambda c: ribbed(c, 8, 0.1))
    a.tube("Stem", [(0, -1.05, pcz + 0.42), (0.05, -1.02, pcz + 0.62)], r=0.06, sides=6)
    jack_face(a, pcz, pr, scale=0.55, y_off=-1.09)  # carved into the front of the held head
    a.feet("Belt", spread=0.4, size=0.27, y=-0.1)


# =============================================================== SECRET
@goober
def H15_PhantomKing(a: Asset):
    """A towering royal phantom with a jewelled crown, a regal cape and ghostly chains."""
    a.colors.update(pal(Body="#B9A8FF", Glow="#E2D8FF", Crown="#FFC93C", Gem="#FF3DA5", Cape="#4B1A8C", Fur="#F2F4FF", Chain="#8A86A0", Mouth="#2A1245"))
    rx, ry, rz, cz = 0.95, 0.9, 1.15, 2.0

    def phantom(c):
        if c.z < 0:
            t = -c.z
            return Vector((c.x * (1 - 0.35 * t), c.y * (1 - 0.35 * t), c.z * 1.6 + 0.1 * math.sin(math.atan2(c.y, c.x) * 5)))
        return c
    a.sphere("Body", r=1, loc=(0, 0, cz), scale=(rx, ry, rz), seg=36, rings=18, deform=phantom)
    a.sphere("Glow", r=0.5, loc=(0, 0.05, 0.25), scale=(1.2, 1.2, 0.3), seg=20, rings=8)
    # crown
    a.cyl("Crown", r=0.62, depth=0.32, loc=(0, 0, 3.05), seg=28)
    for k in range(6):
        ang = k / 6 * 2 * math.pi
        a.cone("Crown", r=0.14, depth=0.38, loc=(math.cos(ang) * 0.55, math.sin(ang) * 0.55, 3.38), seg=4, smooth=False)
        a.ico("Gem", r=0.07, loc=(math.cos(ang) * 0.6, math.sin(ang) * 0.6, 3.05), sub=0)
    a.ico("Gem", r=0.12, loc=(0, -0.62, 3.08), sub=1)
    # royal cape with fur trim
    a.cone("Cape", r=1.35, depth=2.2, loc=(0, 0.35, 1.6), seg=26, tip=0.75, scale=(1, 0.6, 1))
    a.torus("Fur", R=0.85, r=0.14, loc=(0, 0.05, 2.75), scale=(1, 0.9, 0.6), seg=28, sides=8)
    a.eye((-0.32, front(-0.32, 2.25, rx, ry, rz, cz), 2.25), size=0.24, look=(0, 0), pupil=0.6)
    a.eye((0.32, front(0.32, 2.25, rx, ry, rz, cz), 2.25), size=0.24, look=(0, 0), pupil=0.6)
    a.sphere("Mouth", r=0.16, loc=(0, front(0, 1.8, rx, ry, rz, cz), 1.8), scale=(1.3, 0.4, 0.8), seg=12, rings=8)
    # broken ghost chains on the wrists
    for sx in (-1, 1):
        a.tube("Body", [(sx * 0.85, -0.1, 2.0), (sx * 1.25, -0.25, 1.75), (sx * 1.4, -0.35, 1.45)], r=0.17, r_end=0.1, sides=10)
        for k in range(4):
            a.torus("Chain", R=0.08, r=0.025, loc=(sx * (1.45 + k * 0.08), -0.4, 1.3 - k * 0.14), rot=(90, 0, (k % 2) * 90), seg=8, sides=5)


@goober
def H16_GrimGoober(a: Asset):
    """A hooded reaper goober with a glowing face, a tiny scythe and a floating hourglass."""
    a.colors.update(pal(Robe="#14101F", Hood="#221A33", Void="#06040A", Glow="#7BFFE0", EyeGlow="#7BFFE0", Blade="#C9D6E8", Wood="#5A3A22", Sand="#FFC93C", Glass="#BDEBFF"))
    a.cone("Robe", r=1.05, depth=2.2, loc=(0, 0, 1.15), seg=28, tip=0.35)
    a.torus("Robe", R=1.0, r=0.08, loc=(0, 0, 0.08), seg=28, sides=6)  # hem
    a.sphere("Hood", r=0.75, loc=(0, 0.05, 2.45), scale=(1, 1, 1.1), seg=28, rings=16)
    a.cone("Hood", r=0.28, depth=0.6, loc=(0, 0.35, 3.15), rot=(-35, 0, 0), seg=16, tip=0.02)
    a.sphere("Void", r=0.55, loc=(0, -0.38, 2.38), scale=(0.95, 0.55, 1.05), seg=24, rings=12)
    # glowing eyes in the void (glow discs, not white spheres)
    for sx in (-1, 1):
        a.sphere("EyeGlow", r=0.12, loc=(sx * 0.2, -0.66, 2.45), scale=(1, 0.3, 1.4), seg=12, rings=8)
    a.torus("Glow", R=0.12, r=0.03, loc=(0, -0.66, 2.15), rot=(-90, 0, 0), seg=12, sides=5, arc=180)
    # scythe
    a.tube("Wood", [(1.1, -0.3, 0.1), (1.0, -0.3, 2.9)], r=0.06, sides=8)
    a.tube("Blade", [(1.0, -0.3, 2.9), (0.6, -0.35, 3.1), (0.1, -0.4, 2.95), (-0.25, -0.45, 2.6)], r=0.09, r_end=0.02, sides=6)
    a.tube("Robe", [(0.6, -0.2, 1.7), (1.02, -0.32, 1.55)], r=0.13, sides=8)
    # floating hourglass
    for sz in (-1, 1):
        a.cone("Glass", r=0.18, depth=0.25, loc=(-1.0, -0.4, 2.0 + sz * 0.13), rot=(0 if sz > 0 else 180, 0, 0), seg=12, tip=0.03)
        a.cyl("Wood", r=0.22, depth=0.05, loc=(-1.0, -0.4, 2.0 + sz * 0.27), seg=12)
    a.cone("Sand", r=0.12, depth=0.14, loc=(-1.0, -0.4, 1.92), seg=10, tip=0.02)


# ========================================================== BUILD/EXPORT
def build(ids=None, collection_name="HalloweenGoobers", spacing=4.5):
    import bpy
    col = clear_collection(collection_name)
    ids = ids or sorted(ROSTER.keys())
    report = []
    for i, gid in enumerate(ids):
        a = Asset(gid, collection=col)
        ROSTER[gid](a)
        root, objs = a.build(offset=(i * spacing, 30, 0))
        report.append((gid, tri_count(objs), len(objs)))
    return report


def build_all():
    return build(sorted(ROSTER.keys()))
