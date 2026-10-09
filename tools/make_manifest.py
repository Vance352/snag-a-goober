"""Writes tools/sync_manifest.json describing every script under src/.

Rojo-style naming:
    Foo.server.luau -> Script        Foo.client.luau -> LocalScript
    Foo.luau        -> ModuleScript  folders         -> Folder
The Studio side (tools/studio_sync.luau) fetches this manifest and the files
from a local `python -m http.server` rooted at the repo.
"""
import hashlib
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")


def classify(name):
    if name.endswith(".server.luau"):
        return name[: -len(".server.luau")], "Script"
    if name.endswith(".client.luau"):
        return name[: -len(".client.luau")], "LocalScript"
    if name.endswith(".luau"):
        return name[: -len(".luau")], "ModuleScript"
    return None, None


def main():
    entries = []
    for dirpath, _, files in os.walk(SRC):
        for f in sorted(files):
            inst, cls = classify(f)
            if not cls:
                continue
            full = os.path.join(dirpath, f)
            rel = os.path.relpath(full, ROOT).replace("\\", "/")
            parts = os.path.relpath(dirpath, SRC).replace("\\", "/").split("/")
            parts = [p for p in parts if p not in ("", ".")]
            with open(full, "rb") as fh:
                data = fh.read()
            entries.append({
                "file": rel,
                "path": parts,  # [Service, Folder, ...]
                "name": inst,
                "class": cls,
                "sha1": hashlib.sha1(data).hexdigest(),
            })
    out = os.path.join(ROOT, "tools", "sync_manifest.json")
    with open(out, "w", encoding="utf-8") as fh:
        json.dump({"entries": entries}, fh, indent=1)
    print(f"{len(entries)} scripts -> {out}")


if __name__ == "__main__":
    main()
