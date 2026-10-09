"""Snag A Goober - Halloween store art (game icon + thumbnail).

Reuses the helpers in renders.py and the Halloween models (halloween_goobers.py,
halloween_env.py). Writes:
  Assets/StorePage/icon_halloween_512.png
  Assets/StorePage/thumb_halloween_1920x1080.png

Run inside Blender:
    exec(open(r"<repo>/Assets/BlenderSource/scripts/halloween_store.py").read())
    render_halloween_store()
"""
import math
import os
import sys

import bpy
from mathutils import Euler

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.append(SCRIPT_DIR)

R = {"__file__": os.path.join(SCRIPT_DIR, "renders.py"), "__name__": "renders_h"}
exec(open(R["__file__"]).read(), R)
H = {"__file__": os.path.join(SCRIPT_DIR, "halloween_goobers.py"), "__name__": "hgoobers_r"}
exec(open(H["__file__"]).read(), H)
HE = {"__file__": os.path.join(SCRIPT_DIR, "halloween_env.py"), "__name__": "henv_r"}
exec(open(HE["__file__"]).read(), HE)
R["ROSTER"].update(H["ROSTER"])
R["PROPS"].update(HE["PROPS"])

import goober_lib
goober_lib.NATIVE_EXPORT = False  # renders show the eyes as geometry (the Halloween scripts reset this)

hex_rgb = R["hex_rgb"]
text, setup, render, mat, shot_collection = R["text"], R["setup"], R["render"], R["mat"], R["shot_collection"]
ROOT = R["ROOT"]
OUT = os.path.join(ROOT, "Assets", "StorePage")

GLOW_SLOTS = ("Carve", "Glow", "EyeGlow", "Flame", "Window", "Swirl", "GlowB", "Brew", "Fire")


def place(col, aid, loc=(0, 0, 0), rot_z=0.0, scale=1.0, tilt=(0, 0)):
    root = R["place"](col, aid, loc, rot_z, scale, tilt)
    # glowing slots (pumpkin faces, windows, eyes) light up like in game
    for ch in root.children_recursive:
        if ch.type == "MESH" and any(ch.name.endswith("__" + s) for s in GLOW_SLOTS):
            for m in ch.data.materials:
                bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
                bsdf.inputs["Emission Color"].default_value = bsdf.inputs["Base Color"].default_value
                bsdf.inputs["Emission Strength"].default_value = 3.0
    return root


def night_backdrop(col, size=60, y=12):
    """Night sky card: deep purple at the top fading to magenta low down, dark ground."""
    m = bpy.data.materials.new("NightBackdrop")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    # night purple, a touch of magenta low down so orange pumpkins pop against it
    ramp.color_ramp.elements[0].position = 0.38
    ramp.color_ramp.elements[0].color = (*hex_rgb("#8A2E9E"), 1)
    ramp.color_ramp.elements[1].position = 0.6
    ramp.color_ramp.elements[1].color = (*hex_rgb("#2A0E4A"), 1)
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Y"], ramp.inputs[0])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 0.9
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, y, size / 4))
    p = bpy.context.active_object
    p.rotation_euler = (math.radians(90), 0, 0)
    p.data.materials.append(m)
    for c in p.users_collection:
        c.objects.unlink(p)
    col.objects.link(p)
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    fl = bpy.context.active_object
    fl.data.materials.append(mat("NightFloor", hex_rgb("#3A2450"), rough=0.7))
    for c in fl.users_collection:
        c.objects.unlink(fl)
    col.objects.link(fl)


def moon(col, loc, r):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=48, ring_count=24)
    mo = bpy.context.active_object
    mo.data.materials.append(mat("Moon", hex_rgb("#FFE9A8"), emission=1.1))
    for c in mo.users_collection:
        c.objects.unlink(mo)
    col.objects.link(mo)
    return mo


def candy(col, loc, rot=(0, 0, 0), s=1.0):
    root = place(col, "P_CandyPickup", loc, scale=s)
    root.rotation_euler = Euler([math.radians(v) for v in rot])
    return root


def lights(warm=4.5, rim=3.0):
    for name, energy, color in (("ShotKey", warm, (1.0, 0.86, 0.7)), ("ShotRim", rim, (0.7, 0.5, 1.0))):
        L = bpy.data.objects.get(name)
        if L:
            L.data.energy = energy
            L.data.color = color


def icon(path):
    col = shot_collection()
    night_backdrop(col, size=30, y=6)
    moon(col, (3.3, 5.0, 4.9), 1.5)
    place(col, "H01_PumpkinPip", (0, -0.6, 1.25), rot_z=-10, scale=2.0)
    place(col, "H03_BooBlob", (-3.1, 0.4, 3.6), rot_z=20, scale=1.0, tilt=(0, 12))
    place(col, "P_Pumpkin", (3.7, 0.6, 0.0), rot_z=-25, scale=0.85)
    for x, z, rot in ((-2.8, 1.9, (30, 0, 40)), (2.9, 2.6, (-20, 10, -30))):
        candy(col, (x, -1.3, z), rot, 0.85)
    text(col, "SNAG A", (0, -2.2, 8.15), 1.0, hex_rgb("#FFFFFF"))
    text(col, "GOOBER", (0, -2.2, 6.85), 1.5, hex_rgb("#C8FF6A"))
    text(col, "HALLOWEEN", (0, -3.6, 1.05), 1.05, hex_rgb("#FF9A2E"))
    setup((512, 512), False, bg=(0.12, 0.04, 0.2), cam_loc=(0, -13.5, 4.4), target=(0, 0, 4.0), lens=45, sun=(55, 0, 25))
    lights()
    return render(path)


def thumbnail(path):
    col = shot_collection()
    night_backdrop(col, size=90, y=18)
    moon(col, (11, 17, 17), 3.4)
    place(col, "P_GreatPumpkin", (0, 17, 0), scale=0.5)
    place(col, "P_CastleTower", (-15, 16, 0), scale=0.7)
    place(col, "P_CastleTower", (-10, 18, 0), scale=0.45)
    for x, y, s in ((16, 13, 1.1), (-22, 11, 1.0), (22, 15, 0.9)):
        place(col, "P_SpookyTree", (x, y, 0), rot_z=x * 7, scale=s)
    for x, y in ((-16, 4), (16, 4)):
        place(col, "P_JackLantern", (x, y, 0), rot_z=-x * 3, scale=1.0)
    for x, y, s in ((-6, 8, 0.9), (6.5, 8, 1.1), (11, 7, 0.8), (-11, 8, 1.2)):
        place(col, "P_Pumpkin", (x, y, 0), rot_z=x * 20, scale=s)
    # the Halloween Goober line-up (big, in front)
    place(col, "H16_GrimGoober", (0, -1.0, 0), rot_z=0, scale=2.3)
    place(col, "H10_CountGoobula", (-6.4, -0.4, 0), rot_z=-18, scale=2.0)
    place(col, "H14_HeadlessGoobman", (6.6, -0.3, 0), rot_z=18, scale=1.95)
    place(col, "H01_PumpkinPip", (-12.2, -2.6, 0), rot_z=-25, scale=1.8)
    place(col, "H09_Hex", (12.3, -2.4, 0), rot_z=25, scale=1.75)
    place(col, "H03_BooBlob", (-3.6, -5.0, 3.6), rot_z=-8, scale=1.3, tilt=(0, -10))
    place(col, "H04_BatBrat", (4.0, -4.6, 5.0), rot_z=12, scale=1.3)
    for x, z, rot in ((-9.5, 6.4, (20, 10, 30)), (9.8, 7.0, (-30, 20, -20)), (-15.5, 4.2, (50, 0, 10)), (15.8, 4.6, (10, 40, 60))):
        candy(col, (x, -3.0, z), rot, 1.3)
    text(col, "SNAG A GOOBER", (0, -1.0, 13.6), 2.5, hex_rgb("#C8FF6A"))
    text(col, "HALLOWEEN UPDATE!", (0, -1.2, 11.2), 1.75, hex_rgb("#FF9A2E"))
    setup((1920, 1080), False, bg=(0.12, 0.04, 0.2), cam_loc=(0, -33, 9.0), target=(0, 0, 6.6), lens=38, sun=(50, 0, 20))
    lights(4.0, 3.2)
    return render(path)


def render_halloween_store():
    os.makedirs(OUT, exist_ok=True)
    out = [icon(os.path.join(OUT, "icon_halloween_512.png")), thumbnail(os.path.join(OUT, "thumb_halloween_1920x1080.png"))]
    R["clear_collection"]("Shot")
    for c in bpy.data.collections:
        c.hide_render = False
    return out
