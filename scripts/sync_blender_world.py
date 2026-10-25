"""Export/synchronize the editable Blender island without touching its v05 source.

python scripts/sync_blender_world.py --export
python scripts/sync_blender_world.py
python scripts/sync_blender_world.py --verify-only
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/blender/alphabet_island"
SOURCE = ART / "alphabet_island_layout_v05.blend"
WORKING = ART / "alphabet_island_layout_v06_game.blend"
GLB = ART / "alphabet_island_layout_v06_game.glb"
MANIFEST = ART / "game_map_manifest.json"
if MANIFEST.is_file():
    _current_manifest = json.loads(MANIFEST.read_text(encoding="utf-8-sig"))
    WORKING = (ROOT / _current_manifest.get("working_blend", str(WORKING.relative_to(ROOT)))).resolve()
    WORKING.relative_to(ART.resolve())
    GLB = WORKING.with_suffix(".glb")
RUNTIME = ROOT / "game/assets/world/island.glb"
RUNTIME_MANIFEST = RUNTIME.with_name("manifest.json")
REQUIRED = {*(f"SG_DOOR_{chr(65+i)}" for i in range(26)), "SG_DOOR_HOME", "SG_DOOR_SCHOOL", "SG_SPAWN", "SG_NPC_BEAR", "SG_NPC_RABBIT", "SG_APPLE_TREE", "SG_BAKERY_SHOP"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def blender_path(explicit: str | None) -> Path:
    candidates = [explicit, os.environ.get("BLENDER_EXE"), shutil.which("blender"), r"F:\Tools\Blender\blender-5.2.2-windows-x64\blender.exe"]
    for value in candidates:
        if value and Path(value).is_file():
            return Path(value)
    raise RuntimeError("Blender not found; pass --blender with its executable path")


def validate(*, check_runtime: bool) -> dict:
    for path in (SOURCE, WORKING, GLB, MANIFEST):
        if not path.is_file():
            raise RuntimeError(f"Missing {path.relative_to(ROOT)}; run with --export first")
    report = json.loads(MANIFEST.read_text(encoding="utf-8-sig"))
    if sha256(SOURCE) != report["source_v05_sha256"]:
        raise RuntimeError("Original v05 source hash differs from the export record")
    if report.get("source_v05_glb_sha256") and sha256(ART / "alphabet_island_layout_v05.glb") != report["source_v05_glb_sha256"]:
        raise RuntimeError("Original v05 GLB hash differs from the export record")
    if sha256(GLB) != report["glb_sha256"]:
        raise RuntimeError("Exported GLB hash differs from its manifest")
    if report.get("working_blend_sha256") and sha256(WORKING) != report["working_blend_sha256"]:
        raise RuntimeError("The current editable blend changed after export; rerun with --export")
    with GLB.open("rb") as handle:
        header = handle.read(20)
        magic, version, total, length, chunk_type = struct.unpack("<4sIIII", header)
        if magic != b"glTF" or version != 2 or total != GLB.stat().st_size or chunk_type != 0x4E4F534A:
            raise RuntimeError("Invalid GLB header")
        payload = json.loads(handle.read(length))
    names = {node.get("name", "") for node in payload.get("nodes", [])}
    missing = REQUIRED - names
    if missing:
        raise RuntimeError(f"GLB missing required gameplay markers: {sorted(missing)}")
    if check_runtime:
        if not RUNTIME.is_file() or sha256(RUNTIME) != report["glb_sha256"]:
            raise RuntimeError("Runtime island.glb is absent or out of sync")
        if not RUNTIME_MANIFEST.is_file() or sha256(RUNTIME_MANIFEST) != sha256(MANIFEST):
            raise RuntimeError("Runtime manifest is absent or out of sync")
    return {"ok": True, "marker_count": report["marker_count"], "nodes": len(payload.get("nodes", [])), "meshes": len(payload.get("meshes", [])), "glb_bytes": GLB.stat().st_size, "source_v05_preserved": True, "working_blend": str(WORKING.relative_to(ROOT)), "runtime": str(RUNTIME.relative_to(ROOT)), "collision_counts": report["collision_counts"]}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--export", action="store_true", help="Export the manifest's current editable version, or initialize v06 once from v05")
    parser.add_argument("--verify-only", action="store_true", help="Validate existing files without writes")
    parser.add_argument("--blender", help="Path to the Blender executable")
    options = parser.parse_args()
    if options.export and options.verify_only:
        parser.error("--export and --verify-only cannot be combined")
    if options.export:
        executable = blender_path(options.blender)
        input_file = WORKING if WORKING.exists() else SOURCE
        command = [str(executable), "--background", str(input_file), "--python-exit-code", "1", "--python", str(ART / "export_game_map.py")]
        print(f"Exporting {input_file.relative_to(ROOT)}", flush=True)
        process = subprocess.run(command, cwd=ROOT, creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        if process.returncode:
            raise RuntimeError(f"Blender export failed with exit code {process.returncode}")
    result = validate(check_runtime=options.verify_only)
    if not options.verify_only:
        RUNTIME.parent.mkdir(parents=True, exist_ok=True)
        for source, destination in [(GLB, RUNTIME), (MANIFEST, RUNTIME_MANIFEST)]:
            temporary = destination.with_suffix(destination.suffix + ".sync-tmp")
            shutil.copy2(source, temporary)
            os.replace(temporary, destination)
        result = validate(check_runtime=True)
    result["mode"] = "verify-only" if options.verify_only else "export-and-sync" if options.export else "sync"
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        print(f"WORLD_SYNC_ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
