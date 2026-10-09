"""Snag A Goober - promotional renders and store icons.

Builds each shot from the same model code as the game assets (goobers.py /
environment.py), renders with EEVEE and writes PNGs:
  Assets/ReferenceRenders/thumbnail_1920x1080.png, icon_512.png
  Assets/Textures/Icons/<key>.png   (store icons, transparent background)
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.append(SCRIPT_DIR)
import importlib
import goober_lib
importlib.reload(goober_lib)
from goober_lib import Asset, clear_collection, hex_rgb

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(SCRIPT_DIR)))
FONT = r"C:\Windows\Fonts\seguibl.ttf"

g = {"__file__": os.path.join(SCRIPT_DIR, "goobers.py"), "__name__": "goobers_r"}
exec(open(g["__file__"]).read(), g)
e = {"__file__": os.path.join(SCRIPT_DIR, "environment.py"), "__name__": "env_r"}
exec(open(e["__file__"]).read(), e)
ROSTER, PROPS = g["ROSTER"], e["PROPS"]
# renders show eyes as real geometry (in game they are native parts)
goober_lib.NATIVE_EXPORT = False


def shot_collection():
    col = clear_collection("Shot")
    for c in bpy.data.collections:
        c.hide_render = c.name != "Shot"
    return col


def place(col, aid, loc=(0, 0, 0), rot_z=0.0, scale=1.0, tilt=(0, 0)):
    a = Asset(aid, collection=col)
    (ROSTER.get(aid) or PROPS[aid])(a)
    root, objs = a.build(offset=loc)
    root.rotation_euler = Euler((math.radians(tilt[0]), math.radians(tilt[1]), math.radians(rot_z)))
    root.scale = (scale, scale, scale)
    for o in objs:
        for m in o.data.materials:
            bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            bsdf.inputs["Roughness"].default_value = 0.38
            if aid.endswith("Slot") or "Gold" in o.name or "Chain" in o.name:
                bsdf.inputs["Metallic"].default_value = 0.9
                bsdf.inputs["Roughness"].default_value = 0.25
    return root


def mat(name, color, emission=0.0, metallic=0.0, rough=0.4):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    return m


def text(col, body, loc, size, color, outline=(0.08, 0.04, 0.16), rot=(90, 0, 0), extrude=0.12, align="CENTER"):
    out = []
    for i, (c, off, ext) in enumerate(((color, 0.0, extrude), (outline, size * 0.07, extrude * 0.6))):
        cu = bpy.data.curves.new(f"txt_{body}_{i}", type="FONT")
        cu.body = body
        cu.font = bpy.data.fonts.load(FONT, check_existing=True)
        cu.size = size
        cu.align_x = align
        cu.align_y = "CENTER"
        cu.extrude = ext
        cu.bevel_depth = size * 0.015
        cu.offset = off
        ob = bpy.data.objects.new(f"txt_{body}_{i}", cu)
        ob.location = Vector(loc) + Vector((0, 0.08 * size * i, 0))
        ob.rotation_euler = Euler([math.radians(r) for r in rot])
        ob.data.materials.append(mat(f"txtmat_{i}_{c}", c, emission=0.25 if i == 0 else 0))
        col.objects.link(ob)
        out.append(ob)
    return out


def coin(col, loc, r=0.6, rot=(90, 0, 0)):
    a = Asset("Coin", collection=col)
    a.colors.update({"Gold": hex_rgb("#FFC93C"), "Rim": hex_rgb("#E0A21C")})
    a.cyl("Gold", r=r, depth=r * 0.22, seg=36)
    a.torus("Rim", R=r * 0.98, r=r * 0.08, loc=(0, 0, r * 0.11), seg=36, sides=8)
    a.torus("Rim", R=r * 0.98, r=r * 0.08, loc=(0, 0, -r * 0.11), seg=36, sides=8)
    root, objs = a.build(offset=loc)
    root.rotation_euler = Euler([math.radians(v) for v in rot])
    for o in objs:
        bsdf = next(n for n in o.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Metallic"].default_value = 0.95
        bsdf.inputs["Roughness"].default_value = 0.22
    t = text(col, "$", (0, 0, 0), r * 1.1, hex_rgb("#FFF3B0"), outline=hex_rgb("#C98A12"), rot=(0, 0, 0), extrude=r * 0.05)
    for ob in t:
        ob.parent = root
        ob.location = (0, 0, r * 0.12 + (0.0 if ob.name.endswith("_0") else -0.01))
    return root


def setup(res, transparent, bg=(0.35, 0.18, 0.6), cam_loc=(0, -10, 3), target=(0, 0, 1.5), lens=50, sun=(55, 0, 25)):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = transparent
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
    try:
        sc.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    world = sc.world or bpy.data.worlds.new("World")
    sc.world = world
    world.use_nodes = True
    bgn = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bgn.inputs["Color"].default_value = (*bg, 1)
    bgn.inputs["Strength"].default_value = 0.9
    cam = bpy.data.objects.get("ShotCam")
    if cam is None:
        cam = bpy.data.objects.new("ShotCam", bpy.data.cameras.new("ShotCam"))
        sc.collection.objects.link(cam)
    cam.location = cam_loc
    d = Vector(target) - Vector(cam_loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    sc.camera = cam
    for name, rot, energy, color in (("ShotKey", sun, 4.0, (1, 0.97, 0.92)), ("ShotRim", (60, 0, 200), 2.5, (0.75, 0.6, 1.0))):
        L = bpy.data.objects.get(name)
        if L is None:
            L = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
            sc.collection.objects.link(L)
        L.rotation_euler = Euler([math.radians(v) for v in rot])
        L.data.energy = energy
        L.data.color = color
        L.data.angle = math.radians(8)
    for o in sc.objects:
        if o.type == "LIGHT" and not o.name.startswith("Shot"):
            o.hide_render = True
    return cam


def render(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def backdrop(col, color_top, color_bottom, size=60, y=12):
    """A big curved card behind the subject with a vertical gradient."""
    m = bpy.data.materials.new("Backdrop")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*color_bottom, 1)
    ramp.color_ramp.elements[1].color = (*color_top, 1)
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Y"], ramp.inputs[0])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 0.6
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, y, size / 4))
    p = bpy.context.active_object
    p.rotation_euler = (math.radians(90), 0, 0)
    p.data.materials.append(m)
    for c in p.users_collection:
        c.objects.unlink(p)
    col.objects.link(p)
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    fl = bpy.context.active_object
    fl.data.materials.append(mat("Floor", hex_rgb("#7ED678"), rough=0.6))
    for c in fl.users_collection:
        c.objects.unlink(fl)
    col.objects.link(fl)


# ------------------------------------------------------------------ shots
def thumbnail():
    col = shot_collection()
    backdrop(col, hex_rgb("#7A3FC2"), hex_rgb("#FF5FA2"))
    # conveyor running across the frame
    for i, x in enumerate((-20, -12, -4, 4, 12, 20)):
        place(col, "P_BeltSegment", (x, 5.0, 0), rot_z=90)
    place(col, "G21_Gooberzilla", (-6.0, 5.0, 2.4), rot_z=-18, scale=1.5)
    place(col, "G22_GoldenNugget", (6.0, 5.0, 2.4), rot_z=20, scale=1.45)
    place(col, "G23_WizardGoob", (12.5, 5.5, 2.4), rot_z=28, scale=1.3)
    place(col, "G15_Chonk", (-12.5, 5.5, 2.4), rot_z=-30, scale=1.2)
    # hero: Blorp bounding toward the camera, mid-snag
    place(col, "G01_Blorp", (0.0, -3.5, 0.6), rot_z=0, scale=2.2, tilt=(-10, 0))
    place(col, "G08_ConeHead", (-5.2, -4.5, 0), rot_z=-25, scale=1.2)
    place(col, "G24_Glitch", (5.4, -4.2, 0.1), rot_z=25, scale=1.05)
    for i, (x, z) in enumerate(((-3.8, 7.0), (4.0, 7.6), (-9.0, 8.6), (9.5, 8.3), (0.8, 9.6))):
        coin(col, (x, 0.0, z), r=0.6, rot=(80 + i * 7, 15 * i, i * 20))
    text(col, "SNAG A GOOBER!", (0, 0.5, 12.6), 2.9, hex_rgb("#C8FF6A"))
    setup((1920, 1080), False, cam_loc=(0, -33, 9.5), target=(0, 0, 6.6), lens=38)
    return render(os.path.join(ROOT, "Assets", "ReferenceRenders", "thumbnail_1920x1080.png"))


def icon():
    col = shot_collection()
    backdrop(col, hex_rgb("#7A3FC2"), hex_rgb("#FF5FA2"), size=30, y=6)
    place(col, "G01_Blorp", (0, 0, 0.2), rot_z=-12, scale=2.3)
    for x, z in ((-2.6, 4.6), (2.7, 5.1), (2.2, 1.0)):
        coin(col, (x, -1.2, z), r=0.6, rot=(80, 20, x * 10))
    text(col, "SNAG!", (0, -2.0, 6.6), 2.0, hex_rgb("#C8FF6A"))
    setup((512, 512), False, cam_loc=(0, -12.5, 4.2), target=(0, 0, 3.4), lens=45)
    return render(os.path.join(ROOT, "Assets", "ReferenceRenders", "icon_512.png"))


def store_icon(key, build):
    col = shot_collection()
    build(col)
    setup((512, 512), True, cam_loc=(0, -11, 3.6), target=(0, 0, 1.9), lens=48)
    return render(os.path.join(ROOT, "Assets", "Textures", "Icons", key + ".png"))


def _vip(col):
    place(col, "G22_GoldenNugget", (0, 0, -0.2), rot_z=-10, scale=1.7)
    text(col, "VIP", (0, -2.2, 4.1), 1.6, hex_rgb("#FFD24A"))


def _double(col):
    coin(col, (-0.9, 0, 2.2), r=1.4, rot=(80, -10, -15))
    coin(col, (1.0, -0.6, 1.7), r=1.4, rot=(80, 10, 20))
    text(col, "2x", (0, -2.0, 4.4), 1.8, hex_rgb("#C8FF6A"))


def _slots(col):
    for x in (-2.6, 0, 2.6):
        place(col, "P_Stand", (x, 0.6, 0.4), scale=0.75)
    place(col, "G04_Gumbo", (0, 0.4, 1.2), scale=1.05)
    text(col, "+4", (0, -1.4, 4.1), 2.3, hex_rgb("#C8FF6A"))


def _boots(col):
    a = Asset("Boot", collection=col)
    a.colors.update({"Shoe": hex_rgb("#FF5A1F"), "Sole": hex_rgb("#FFFFFF"), "Lace": hex_rgb("#2A1A45"), "Wing": hex_rgb("#BFEFFF")})
    a.box("Shoe", size=(1.6, 3.2, 1.3), loc=(0, -0.2, 1.0), round_e=0.45)
    a.box("Shoe", size=(1.4, 1.4, 1.8), loc=(0, 0.9, 1.9), round_e=0.5)
    a.box("Sole", size=(1.75, 3.5, 0.45), loc=(0, -0.15, 0.3), round_e=0.4)
    for i in range(3):
        a.box("Lace", size=(1.2, 0.15, 0.12), loc=(0, -0.6 + i * 0.5, 1.72 + i * 0.12), rot=(-15, 0, 0), round_e=0.5)
    for sx in (-1, 1):
        a.sphere("Wing", r=0.8, loc=(sx * 1.0, 1.0, 2.4), scale=(0.15, 1.2, 0.5), rot=(0, 0, sx * 25), seg=14, rings=8)
    root, _ = a.build(offset=(0, 0, 0.3))
    root.rotation_euler = Euler((0, 0, math.radians(-35)))


def _auto(col):
    a = Asset("Magnet", collection=col)
    a.colors.update({"Red": hex_rgb("#E8364F"), "Tip": hex_rgb("#C9CED6")})
    a.torus("Red", R=1.2, r=0.45, loc=(0, 0, 2.6), rot=(90, 0, 0), seg=28, sides=14, arc=180)
    for sx in (-1, 1):
        a.cyl("Red", r=0.45, depth=0.8, loc=(sx * 1.2, 0, 2.2), seg=16)
        a.cyl("Tip", r=0.46, depth=0.45, loc=(sx * 1.2, 0, 1.6), seg=16)
    root, _ = a.build(offset=(0, 0, 0.6))
    root.rotation_euler = Euler((math.radians(180), 0, math.radians(-20)))
    root.location = (0, 0, 5.4)
    for i, (x, z) in enumerate(((-1.2, 0.8), (0.3, 0.4), (1.5, 1.0))):
        coin(col, (x, -0.4, z), r=0.6, rot=(70 + i * 10, 0, i * 25))


def _lucky(col):
    a = Asset("Clover", collection=col)
    a.colors.update({"Leaf": hex_rgb("#3FBF4D"), "Stem": hex_rgb("#2E8C3A")})
    for k in range(4):
        ang = k * math.pi / 2 + math.pi / 4
        for s in (-1, 1):
            a.sphere("Leaf", r=0.75, loc=(math.cos(ang) * 1.0 + math.cos(ang + s * 0.6) * 0.3, -0.1, 2.6 + math.sin(ang) * 1.0 + math.sin(ang + s * 0.6) * 0.3),
                     scale=(1, 0.25, 1), seg=18, rings=10)
    a.tube("Stem", [(0, 0, 2.6), (0.3, 0, 1.4), (0.9, 0, 0.6)], r=0.12, sides=8)
    a.build(offset=(0, 0.4, 0.4))
    place(col, "G16_BubblesMcGee", (1.7, -0.9, 0), rot_z=-15, scale=0.65)


def _sack(col):
    a = Asset("Sack", collection=col)
    a.colors.update({"Sack": hex_rgb("#C9A06A"), "Tie": hex_rgb("#8A5A2B"), "Slop": hex_rgb("#7BE35A")})
    a.sphere("Sack", r=1.6, loc=(0, 0, 1.6), scale=(1, 0.95, 1.05), seg=28, rings=16)
    a.cyl("Sack", r=0.55, r2=0.8, depth=0.7, loc=(0, 0, 3.3), seg=20)
    a.torus("Tie", R=0.55, r=0.12, loc=(0, 0, 3.05), seg=20, sides=8)
    a.build(offset=(0, 0.2, 0))
    text(col, "$", (0, -1.55, 1.6), 1.6, hex_rgb("#FFD24A"))
    coin(col, (1.8, -0.8, 0.5), r=0.55, rot=(70, 0, 30))


def _barrel(col):
    place(col, "P_SlopBarrel", (0, 0, 0), rot_z=-20, scale=1.2)
    for i, (x, z) in enumerate(((-1.3, 4.3), (0.4, 4.8), (1.5, 4.1), (-0.4, 3.9))):
        coin(col, (x, 0, z), r=0.6, rot=(30 + i * 20, 20, i * 40))


def _tanker(col):
    place(col, "P_SlopBarrel", (-1.4, 0.6, 0), scale=0.95)
    place(col, "P_SlopBarrel", (1.4, 0.6, 0), scale=0.95)
    place(col, "P_SlopBarrel", (0, -0.4, 0), scale=1.05)
    for i in range(7):
        coin(col, (-2 + i * 0.65, -1.4, 3.8 + (i % 2) * 0.5), r=0.5, rot=(60 + i * 9, 10, i * 30))


def _boost(col):
    a = Asset("Bolt", collection=col)
    a.colors.update({"Bolt": hex_rgb("#FFD23F")})
    pts = [(-0.3, 4.2), (1.2, 4.2), (0.3, 2.6), (1.4, 2.6), (-0.8, 0.0), (0.1, 2.0), (-1.0, 2.0)]
    import bmesh
    bm = bmesh.new()
    vs = [bm.verts.new((x, -0.25, z)) for x, z in pts] + [bm.verts.new((x, 0.25, z)) for x, z in pts]
    n = len(pts)
    bm.faces.new(vs[:n][::-1])
    bm.faces.new(vs[n:])
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((vs[i], vs[j], vs[n + j], vs[n + i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("BoltMesh")
    bm.to_mesh(me)
    ob = bpy.data.objects.new("BoltObj", me)
    ob.data.materials.append(mat("BoltMat", hex_rgb("#FFD23F"), emission=1.5))
    ob.location = (0, 0, 0.2)
    col.objects.link(ob)
    text(col, "2x", (1.5, -0.8, 0.9), 1.3, hex_rgb("#C8FF6A"))


# ------------------------------------------------------- store page art
RARITY_HEX = {"Common": "#C9CED6", "Uncommon": "#5BD45B", "Rare": "#3DA5FF", "Epic": "#B05BFF", "Legendary": "#FFB627", "Secret": "#FF3DA5"}
RARITY_OF = {
    "G01_Blorp": "Common", "G02_SirPuddle": "Common", "G03_Toastie": "Common", "G04_Gumbo": "Common", "G05_PebblePete": "Common", "G06_Nugget": "Common",
    "G07_Wobblesworth": "Uncommon", "G08_ConeHead": "Uncommon", "G09_Snorkel": "Uncommon", "G10_Mushy": "Uncommon", "G11_BeanBoi": "Uncommon",
    "G12_CaptainSpork": "Rare", "G13_Fluffernaut": "Rare", "G14_DiscoDan": "Rare", "G15_Chonk": "Rare", "G16_BubblesMcGee": "Rare",
    "G17_GrandpaGoob": "Epic", "G18_MoaiGoob": "Epic", "G19_OctoGoob": "Epic", "G20_SlimeKing": "Epic",
    "G21_Gooberzilla": "Legendary", "G22_GoldenNugget": "Legendary", "G23_WizardGoob": "Legendary",
    "G24_Glitch": "Secret", "G25_ChaosGoob": "Secret",
}


def stand(col, loc, rarity=None, scale=1.0):
    root = place(col, "P_Stand", loc, scale=scale)
    if rarity:
        for ch in root.children:
            if ch.name.endswith("__Rim"):
                ch.data.materials.clear()
                ch.data.materials.append(mat("Rim_" + rarity, hex_rgb(RARITY_HEX[rarity]), emission=0.6))
    return root


def avatar(col, loc, rot_z, shirt, pants, arms_up=False, lean=0, stride=22, name="Avatar"):
    """A simple blocky player character (our own model) for action shots.
    Front faces -Y; mid-stride legs; arms either raised (carrying) or reaching."""
    a = Asset(name, collection=col)
    a.colors.update({"Shirt": hex_rgb(shirt), "Pants": hex_rgb(pants), "Skin": hex_rgb("#F2C79A"), "Pupil": hex_rgb("#1E1B2E"), "Mouth": hex_rgb("#7A2E3A")})
    for sx, sgn in ((-0.5, 1), (0.5, -1)):
        a.box("Pants", size=(0.95, 0.95, 2.0), loc=(sx, sgn * 0.35, 1.0), rot=(sgn * stride, 0, 0), round_e=0.3)
    a.box("Shirt", size=(2.0, 1.0, 2.0), loc=(0, 0, 3.0), round_e=0.3)
    if arms_up:
        for sx in (-1, 1):
            a.box("Shirt", size=(0.95, 0.95, 2.0), loc=(sx * 1.5, 0, 4.6), rot=(0, sx * -10, 0), round_e=0.3)
    else:
        for sx in (-1, 1):
            a.box("Shirt", size=(0.95, 0.95, 2.0), loc=(sx * 1.5, -0.8, 3.5), rot=(75, 0, 0), round_e=0.3)
    a.box("Skin", size=(1.2, 1.2, 1.2), loc=(0, 0, 4.65), round_e=0.35)
    for sx in (-1, 1):
        a.sphere("Pupil", r=0.11, loc=(sx * 0.25, -0.6, 4.8), scale=(1, 0.5, 1.4), seg=10, rings=6)
    a.smile((0, -0.61, 4.45), width=0.45, thick=0.06, frown=not arms_up)
    root, _ = a.build(offset=loc)
    root.rotation_euler = Euler((math.radians(lean), 0, math.radians(rot_z)))
    return root


def thumb(name, build, cam_loc, target, lens=40):
    col = shot_collection()
    build(col)
    setup((1920, 1080), False, cam_loc=cam_loc, target=target, lens=lens)
    return render(os.path.join(ROOT, "Assets", "ReferenceRenders", "store", name + ".png"))


def _icon_title(col):
    backdrop(col, hex_rgb("#7A3FC2"), hex_rgb("#FF5FA2"), size=30, y=6)
    place(col, "G01_Blorp", (0, -0.5, 0.4), rot_z=-10, scale=2.2)
    for x, z, r in ((-2.9, 3.6, 0.55), (2.9, 4.0, 0.6), (2.5, 1.0, 0.5), (-2.6, 1.2, 0.45)):
        coin(col, (x, -1.0, z), r=r, rot=(80, 20, x * 10))
    text(col, "SNAG A", (0, -2.2, 7.7), 1.15, hex_rgb("#FFFFFF"))
    text(col, "GOOBER", (0, -2.2, 6.25), 1.65, hex_rgb("#C8FF6A"))


def _collect(col):
    backdrop(col, hex_rgb("#3B2A7A"), hex_rgb("#7ED6FF"), size=90, y=16)
    ids = sorted(RARITY_OF.keys())
    rows = [ids[0:9], ids[9:17], ids[17:25]]
    for r, row in enumerate(rows):
        y = r * 4.2
        z = r * 1.6
        n = len(row)
        for i, gid in enumerate(row):
            x = (i - (n - 1) / 2) * 3.9
            stand(col, (x, y, z), RARITY_OF[gid], scale=0.85)
            place(col, gid, (x, y, z + 0.95), rot_z=0, scale=0.95)
        if r < 2:
            bpy.ops.mesh.primitive_cube_add(size=1, location=(0, y + 2.1, z + 0.8))
            step = bpy.context.active_object
            step.scale = (40, 4.2, 1.6)
            step.data.materials.append(mat("Step", hex_rgb("#5B3E8C"), rough=0.5))
            for c in step.users_collection:
                c.objects.unlink(step)
            col.objects.link(step)
    text(col, "25 GOOBERS TO COLLECT!", (0, 6, 11.2), 2.4, hex_rgb("#FFE27A"))


def _steal(col):
    backdrop(col, hex_rgb("#FF8C42"), hex_rgb("#FF5FA2"), size=80, y=14)
    # the victim's base: stands, one now empty
    for x, gid in ((-11, "G13_Fluffernaut"), (-7, None), (-3, "G16_BubblesMcGee")):
        stand(col, (x, 5, 0.0), "Rare" if gid else "Legendary")
        if gid:
            place(col, gid, (x, 5, 1.0), rot_z=0)
    # thief sprinting toward the camera with a Legendary held overhead
    avatar(col, (5.5, -1.5, 0), 25, "#2E9E3A", "#1E1B2E", arms_up=True, lean=-6, name="Thief")
    place(col, "G21_Gooberzilla", (5.5, -1.5, 5.9), rot_z=20, scale=0.85)
    # owner chasing from behind
    avatar(col, (-1.5, 1.0, 0), 35, "#3DA5FF", "#5B3E8C", arms_up=False, lean=-12, name="Owner")
    text(col, "STEAL...", (-5.0, -2, 10.2), 1.9, hex_rgb("#FFFFFF"))
    text(col, "OR GET CAUGHT!", (-3.2, -2, 8.3), 1.9, hex_rgb("#C8FF6A"))


def _base(col):
    backdrop(col, hex_rgb("#7A3FC2"), hex_rgb("#7ED6FF"), size=90, y=22)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 6, 0.3))
    floor = bpy.context.active_object
    floor.scale = (34, 26, 0.6)
    floor.data.materials.append(mat("PlotFloor", hex_rgb("#FFB3C7"), rough=0.6))
    for c in floor.users_collection:
        c.objects.unlink(floor)
    col.objects.link(floor)
    picks = ["G21_Gooberzilla", "G22_GoldenNugget", "G23_WizardGoob", "G20_SlimeKing", "G19_OctoGoob", "G17_GrandpaGoob",
             "G15_Chonk", "G14_DiscoDan", "G12_CaptainSpork", "G13_Fluffernaut", "G10_Mushy", "G08_ConeHead"]
    i = 0
    for row, y in enumerate((14, 9, 4)):
        for x in (-12, -6, 6, 12):
            gid = picks[i]
            i += 1
            stand(col, (x, y, 0.6), RARITY_OF[gid], scale=0.95)
            place(col, gid, (x, y, 1.55), rot_z=0, scale=1.0)
    place(col, "P_Trophy", (0, 16, 0.6), scale=1.3)
    # cash pad bursting with coins
    bpy.ops.mesh.primitive_cylinder_add(radius=3.2, depth=0.3, location=(0, -2, 0.75))
    pad = bpy.context.active_object
    pad.data.materials.append(mat("Pad", hex_rgb("#7BE35A"), emission=1.4))
    for c in pad.users_collection:
        c.objects.unlink(pad)
    col.objects.link(pad)
    rnd = __import__("random").Random(5)
    for k in range(14):
        coin(col, (rnd.uniform(-3, 3), rnd.uniform(-3.5, -0.5), rnd.uniform(2.5, 7.5)), r=rnd.uniform(0.4, 0.6), rot=(rnd.uniform(0, 180), rnd.uniform(0, 180), 0))
    text(col, "BUILD YOUR GOOBER EMPIRE!", (0, 2, 11.4), 2.2, hex_rgb("#FFE27A"))


def _chaos(col):
    backdrop(col, hex_rgb("#14081F"), hex_rgb("#C04BFF"), size=80, y=16)
    place(col, "P_ChaosRift", (0, 6, 0), scale=0.85)
    place(col, "G25_ChaosGoob", (0, -1.5, 2.2), rot_z=0, scale=1.9)
    place(col, "G24_Glitch", (-7, 0, 0.5), rot_z=25, scale=1.25)
    place(col, "G23_WizardGoob", (7, 0, 0), rot_z=-25, scale=1.15)
    text(col, "GOOBER CHAOS EVENTS!", (0, -2, 10.4), 2.2, hex_rgb("#FF8FE0"))
    text(col, "chaos rifts  •  slop storms  •  golden hours", (0, -2, 8.7), 0.8, hex_rgb("#FFFFFF"))


def render_store_page():
    out = []
    col = shot_collection()
    _icon_title(col)
    setup((512, 512), False, cam_loc=(0, -13.5, 4.6), target=(0, 0, 4.0), lens=45)
    out.append(render(os.path.join(ROOT, "Assets", "ReferenceRenders", "store", "icon_title_512.png")))
    out.append(thumbnail())
    out.append(thumb("thumb2_collect", _collect, cam_loc=(0, -30, 13), target=(0, 3, 4.6), lens=36))
    out.append(thumb("thumb3_steal", _steal, cam_loc=(0, -24, 7.5), target=(0, 0, 5.4), lens=38))
    out.append(thumb("thumb4_base", _base, cam_loc=(0, -27, 18), target=(0, 6, 5.0), lens=36))
    out.append(thumb("thumb5_chaos", _chaos, cam_loc=(0, -25, 7.5), target=(0, 0, 5.4), lens=38))
    clear_collection("Shot")
    for c in bpy.data.collections:
        c.hide_render = False
    return out


STORE = {
    "VIP": _vip, "DoubleCoins": _double, "ExtraSlots": _slots, "SprintBoots": _boots, "AutoCollect": _auto, "Lucky": _lucky,
    "CoinsSmall": _sack, "CoinsMedium": _barrel, "CoinsLarge": _tanker, "Boost": _boost,
}


def render_all():
    out = [thumbnail(), icon()]
    for key, fn in STORE.items():
        out.append(store_icon(key, fn))
    clear_collection("Shot")
    for c in bpy.data.collections:
        c.hide_render = False
    return out
