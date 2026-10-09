"""Build + export the Halloween update assets for Roblox.

Run inside Blender:
    exec(open(r"<repo>/Assets/BlenderSource/scripts/export_halloween.py").read())

What it does:
  1. Builds halloween_goobers (H01-H16) and halloween_env props with
     NATIVE_EXPORT on: eyes, pupils and every other paired round face feature
     (cheeks, eye sockets, button eyes, glowing eyes) are NOT exported as
     meshes. Roblox's automatic mesh moderation rejected paired white spheres
     last time; these are rebuilt in Studio from plain Parts instead.
  2. Exports Assets/Exports/SAG_Halloween.fbx (everything, for one Import 3D)
     plus one FBX per asset in Assets/Exports/Halloween/.
  3. Merges slot colours, triangle counts, dimensions, native-part specs and
     slot centres into Assets/AssetDocumentation/palette.json and
     native_parts.json (existing entries are kept).
"""
import json
import os
import sys

REPO = r"C:\Users\vance\snag-a-goober"
SCRIPTS = os.path.join(REPO, "Assets", "BlenderSource", "scripts")
if SCRIPTS not in sys.path:
    sys.path.append(SCRIPTS)

import bpy
import importlib
import goober_lib
importlib.reload(goober_lib)

# paired round face features are never uploaded as meshes
goober_lib.NATIVE_SLOTS = {"Eye", "Pupil", "Cheek", "Socket", "Button", "EyeGlow"}
goober_lib.NATIVE_EXPORT = True
goober_lib.NATIVE.clear()

# remember every asset's colour table (native slots have no mesh to read it from)
COLORS = {}
_orig_build = goober_lib.Asset.build


def _build(self, offset=(0, 0, 0)):
    COLORS[self.id] = dict(self.colors)
    return _orig_build(self, offset)


goober_lib.Asset.build = _build


def _load(name):
    g = {"__file__": os.path.join(SCRIPTS, name), "__name__": name}
    src = open(os.path.join(SCRIPTS, name), encoding="utf-8").read().replace("importlib.reload(goober_lib)\n", "")
    exec(src, g)
    return g


def lin2srgb(c):
    return round(255 * (12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055))


def collect(collection):
    """palette / tris / dims / slot centres for every asset root in a collection."""
    out = {}
    for root in [o for o in collection.objects if o.parent is None]:
        aid = root.name
        pal, centers, tris = {}, {}, 0
        mn = [1e9, 1e9, 1e9]
        mx = [-1e9, -1e9, -1e9]
        for ob in root.children:
            if ob.type != "MESH":
                continue
            slot = ob.name.split("__", 1)[1]
            mat = ob.data.materials[0] if ob.data.materials else None
            if mat and mat.use_nodes:
                bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
                col = bsdf.inputs["Base Color"].default_value if bsdf else mat.diffuse_color
            else:
                col = mat.diffuse_color if mat else (0.8, 0.8, 0.8, 1)
            pal[slot] = [lin2srgb(col[0]), lin2srgb(col[1]), lin2srgb(col[2])]
            vs = [v.co for v in ob.data.vertices]
            smn = [min(v[i] for v in vs) for i in range(3)]
            smx = [max(v[i] for v in vs) for i in range(3)]
            centers[slot] = [round((smn[i] + smx[i]) / 2, 4) for i in range(3)]
            for i in range(3):
                mn[i] = min(mn[i], smn[i])
                mx[i] = max(mx[i], smx[i])
            tris += sum(len(p.vertices) - 2 for p in ob.data.polygons)
        out[aid] = {"palette": pal, "centers": centers, "tris": tris,
                    "dims": {"size": [round(mx[i] - mn[i], 3) for i in range(3)], "minz": round(mn[2], 3)}}
    return out


def export_fbx(path, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.hide_set(False)
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"EMPTY", "MESH"},
                             axis_forward="-Z", axis_up="Y", apply_unit_scale=True,
                             apply_scale_options="FBX_SCALE_UNITS", mesh_smooth_type="FACE",
                             use_mesh_modifiers=True, add_leaf_bones=False, bake_anim=False)


def run():
    gob = _load("halloween_goobers.py")
    env = _load("halloween_env.py")
    gob["build_all"]()
    env["build_all"]()
    cols = [bpy.data.collections["HalloweenGoobers"], bpy.data.collections["HalloweenProps"]]

    # palette.json + native_parts.json (merge)
    doc = os.path.join(REPO, "Assets", "AssetDocumentation")
    pal_path = os.path.join(doc, "palette.json")
    nat_path = os.path.join(doc, "native_parts.json")
    pal = json.load(open(pal_path, encoding="utf-8"))
    nat = json.load(open(nat_path, encoding="utf-8"))
    for col in cols:
        for aid, info in collect(col).items():
            native = goober_lib.NATIVE.get(aid, [])
            colors = dict(info["palette"])
            for slot in {n["slot"] for n in native}:  # native slots: colour from the asset's table
                c = COLORS.get(aid, {}).get(slot, (1.0, 1.0, 1.0))
                colors[slot] = [lin2srgb(c[0]), lin2srgb(c[1]), lin2srgb(c[2])]
            pal["palette"][aid] = colors
            pal["tris"][aid] = info["tris"]
            pal["dims"][aid] = info["dims"]
            nat["native"][aid] = native
            nat["slotCenters"][aid] = info["centers"]
    json.dump(pal, open(pal_path, "w", encoding="utf-8"), indent=1)
    json.dump(nat, open(nat_path, "w", encoding="utf-8"), indent=1)

    # FBX: one combined file + one per asset
    exports = os.path.join(REPO, "Assets", "Exports")
    per = os.path.join(exports, "Halloween")
    os.makedirs(per, exist_ok=True)
    allobs = [o for c in cols for o in c.objects]
    export_fbx(os.path.join(exports, "SAG_Halloween.fbx"), allobs)
    for col in cols:
        for root in [o for o in col.objects if o.parent is None]:
            export_fbx(os.path.join(per, root.name + ".fbx"), [root] + list(root.children))
    return {"assets": sum(len([o for o in c.objects if o.parent is None]) for c in cols),
            "native_specs": sum(len(v) for v in goober_lib.NATIVE.values())}
