"""Build + export the Goober Breach update props for Roblox.

Run inside Blender:
    exec(open(r"<repo>/Assets/BlenderSource/scripts/export_hub.py").read())
    run()

Exports Assets/Exports/SAG_Hub.fbx (all four, for one Import 3D) plus one FBX
per asset in Assets/Exports/Hub/, and merges slot colours / triangle counts /
dimensions / slot centres into Assets/AssetDocumentation/palette.json and
native_parts.json (existing entries are kept). These props have no eyes or
paired round features, so nothing needs rebuilding as native parts.
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
goober_lib.NATIVE_EXPORT = True
goober_lib.NATIVE.clear()

H = {"__file__": os.path.join(SCRIPTS, "export_halloween.py"), "__name__": "exph"}
exec(open(H["__file__"], encoding="utf-8").read(), H)
collect, export_fbx = H["collect"], H["export_fbx"]


def run():
    g = {"__file__": os.path.join(SCRIPTS, "hub_props.py"), "__name__": "hubprops"}
    exec(open(g["__file__"], encoding="utf-8").read().replace("importlib.reload(goober_lib)\n", ""), g)
    col = g["build_all"]()
    doc = os.path.join(REPO, "Assets", "AssetDocumentation")
    pal_path = os.path.join(doc, "palette.json")
    nat_path = os.path.join(doc, "native_parts.json")
    pal = json.load(open(pal_path, encoding="utf-8"))
    nat = json.load(open(nat_path, encoding="utf-8"))
    info = collect(col)
    for aid, i in info.items():
        pal["palette"][aid] = i["palette"]
        pal["tris"][aid] = i["tris"]
        pal["dims"][aid] = i["dims"]
        nat["native"][aid] = goober_lib.NATIVE.get(aid, [])
        nat["slotCenters"][aid] = i["centers"]
    json.dump(pal, open(pal_path, "w", encoding="utf-8"), indent=1)
    json.dump(nat, open(nat_path, "w", encoding="utf-8"), indent=1)
    exports = os.path.join(REPO, "Assets", "Exports")
    per = os.path.join(exports, "Hub")
    os.makedirs(per, exist_ok=True)
    export_fbx(os.path.join(exports, "SAG_Hub.fbx"), list(col.objects))
    for root in [o for o in col.objects if o.parent is None]:
        export_fbx(os.path.join(per, root.name + ".fbx"), [root] + list(root.children))
    return {aid: i["tris"] for aid, i in info.items()}
