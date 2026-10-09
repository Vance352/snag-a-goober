# Blender → Roblox asset pipeline

1. **Model in code.** `Assets/BlenderSource/scripts/goobers.py` (25 Goobers) and
   `environment.py` (12 props) build every asset from primitives using
   `goober_lib.py`. Conventions: 1 Blender unit = 1 stud, front faces -Y, feet on
   Z = 0, one mesh object per material slot named `<AssetId>__<Slot>`, all
   parented to an Empty named `<AssetId>`.
2. **Build + export** (in Blender via MCP or the Scripting tab):
   `exec(open(".../goobers.py").read())` → `build()`, same for `environment.py`,
   then export FBX (axis forward -Z, up Y, apply unit scale). Outputs:
   `Assets/Exports/SAG_AllAssets.fbx` plus one FBX per asset in
   `Assets/Exports/Goobers|Props`. Editable source: `Assets/BlenderSource/SAG_AllAssets.blend`.
3. **Metadata.** Blender writes `Assets/AssetDocumentation/palette.json`
   (slot colours + dimensions) and `native_parts.json` (eye/pupil specs).
4. **Import (manual, Studio UI).** File → Import 3D → `SAG_AllAssets.fbx`.
   Studio's importer can't be scripted. After processing, the raw import is kept
   in `ServerStorage.RawImport` so `process_import` can be re-run without
   re-importing.
5. **Process.** Run `tools/process_import.luau` in Edit mode (local server on
   :34873). It colours parts from the palette, verifies orientation/scale, builds
   the Root/Pivot/Anim skeleton and writes templates to
   `ReplicatedStorage.Assets.Goobers` and `.Props`.
6. **Map.** `require(ServerStorage.Tools.MapBuilder).Build()` places props.

Axis mapping (verified on P_Gusher): Blender (x, y, z) → Roblox (-x, z, y).

## Moderation lesson (2026-10-08)

Roblox's automated mesh moderation **rejected all 10 "Eye" meshes** (pairs of
white spheres) as false positives; 216 other meshes were approved. Fix: eyes and
pupils are no longer meshes. `goober_lib.NATIVE_SLOTS = {"Eye", "Pupil"}`
records those primitives as specs instead of geometry, and `process_import`
rebuilds them from native Parts (sphere SpecialMesh / blocks), which are never
uploaded or moderated. **Do not export paired-sphere shapes as standalone
meshes.** Check moderation with the Assets API
(`apis.roblox.com/assets/user-auth/v1/assets/<id>?readMask=moderationResult`)
after every import.
