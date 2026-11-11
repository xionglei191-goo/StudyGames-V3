"""Synchronize the verified own16 environment bundle without replacing game code.

The bundle is downloaded and hash-verified before this command is run. Dry-run is
the default. Existing source files are retained; conflicting source paths abort.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/verification/drive-model-sync-own16-20261027"
FOLDER_URL = "https://drive.google.com/drive/folders/1bqluU1N8p1e_igYxvX7enMd_YrlbvydR"
SIDECAR_PATHS = ["game/assets/world/island.glb.import"] + [
    f"game/assets/interiors/{rid}.glb.import" for rid in ("landmark_A", "landmark_N", "playground")
]


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def child(root: Path, relative: str) -> Path:
    path = (root / relative).resolve()
    path.relative_to(root.resolve())
    return path


def copy_exact(source: Path, target: Path) -> None:
    if target.is_file() and digest(source) == digest(target):
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    temp = target.with_name(target.name + ".drive-sync-tmp")
    shutil.copy2(source, temp)
    assert digest(temp) == digest(source), str(target)
    temp.replace(target)


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".drive-sync-tmp")
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temp.replace(path)


def load_local(name: str, path: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def subresources(text: str) -> tuple[int, int]:
    start = text.index("_subresources=")
    end = text.index("\ngltf/", start)
    return start, end


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, default=ROOT / ".local/imports/drive-own16-20261027")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    bundle = args.bundle.resolve()
    art = bundle / "source-extracted/StudyGames-V3-own16-sources"
    runtime = bundle / "runtime-extracted/StudyGames-V3-own16"
    index = read_json(bundle / "metadata/SOURCE-INDEX44.json")
    ledger = read_json(bundle / "metadata/SCENE-LEDGER44.json")
    runtime_manifest = read_json(runtime / "game/data/interiors_manifest.json")
    world_manifest = read_json(runtime / "game/assets/world/manifest.json")
    source_manifest = read_json(ROOT / "assets/blender/interiors/interiors_manifest.json")
    sync = load_local("drive_sync_interior_checks", "scripts/sync_blender_interiors.py")
    geometry = load_local("drive_sync_geometry", "assets/blender/interiors/scripts/validate_interiors.py")
    assert index["revision"] == "own16" and index["scene_count"] == 44
    assert {e["room_id"] for e in index["sources"]} == sync.EXPECTED | {"island"}
    assert {e["room_id"] for e in runtime_manifest["rooms"]} == sync.EXPECTED
    remote_rooms = {e["room_id"]: e for e in runtime_manifest["rooms"]}
    local_rooms = {e["room_id"]: e for e in source_manifest["rooms"]}
    ledger_rows = {e["room_id"]: e for e in ledger["rows"]}
    copies = []
    rows = []
    for source in index["sources"]:
        rid = source["room_id"]
        files = {Path(f["path"]).suffix: f for f in source["files"]}
        assert set(files) == {".blend", ".glb", ".png"}, rid
        for record in source["files"]:
            path = child(art, record["path"])
            assert path.stat().st_size == record["bytes"] and digest(path) == record["sha256"], str(path)
            dest = child(ROOT, record["path"])
            # Versioned source files must never replace a different local source.
            assert not dest.exists() or digest(dest) == record["sha256"], f"Source conflict: {dest}"
            copies.append((path, dest))
        entry = ledger_rows[rid]
        glb = child(art, files[".glb"]["path"])
        incoming = child(runtime, entry["runtime_path"])
        sha = files[".glb"]["sha256"]
        assert sha == entry["runtime_sha256"] == digest(incoming), rid
        target = child(ROOT, entry["runtime_path"])
        row = {"room_id": rid, "runtime_path": entry["runtime_path"], "previous_sha256": digest(target),
               "incoming_sha256": sha, "source_blend": files[".blend"]["path"],
               "source_glb": files[".glb"]["path"], "preview": files[".png"]["path"],
               "bytes_before": target.stat().st_size, "bytes_after": incoming.stat().st_size}
        copies.append((incoming, target))
        if rid != "island":
            row["structure"] = sync.inspect_glb(glb, rid)
            remote = remote_rooms[rid]
            assert remote["source_sha256"] == sha and remote["source_glb"] == files[".glb"]["path"]
            assert remote["source_blend"] == files[".blend"]["path"]
            updated = local_rooms[rid]
            updated.update({"blend": files[".blend"]["path"], "glb": files[".glb"]["path"],
                            "preview": files[".png"]["path"], "glb_sha256": sha,
                            "bounds": remote["bounds"], "triangles": remote["triangles"],
                            "refinement_revision": "own-16", "model_version": remote["model_version"],
                            "source_recovery": source["source_recovery"]})
            data, _ = geometry.glb(glb)
            nodes, matrices = geometry.world_nodes(data)
            names = {node.get("name"): i for i, node in enumerate(nodes)}
            for anchor in updated.get("anchors", []):
                idx = names[anchor["name"]]
                x, y, z = geometry.transform(matrices[idx], [0, 0, 0])
                anchor["position_godot"] = [x, y, z]
                anchor["position_blender"] = [x, -z, y]
        else:
            assert world_manifest["glb_sha256"] == sha
            assert world_manifest["working_blend"] == files[".blend"]["path"]
            assert world_manifest["working_blend_sha256"] == files[".blend"]["sha256"]
        rows.append(row)

    # These are the only four sidecars with model-specific import policy changes.
    merged_sidecars = {}
    for relative in SIDECAR_PATHS:
        local = (ROOT / relative).read_text(encoding="utf-8")
        remote = (runtime / relative).read_text(encoding="utf-8")
        assert 'import_script/path=""' in remote
        a, b = subresources(local)
        c, d = subresources(remote)
        merged_sidecars[relative] = local[:a] + remote[c:d] + local[b:]
    for rid in sync.EXPECTED - {"landmark_A", "landmark_N", "playground"}:
        remote = (runtime / f"game/assets/interiors/{rid}.glb.import").read_text(encoding="utf-8")
        a, b = subresources(remote)
        assert remote[a:b].strip() == "_subresources={}", rid

    source_manifest["sync_origin"] = {"revision": "own16", "folder_url": FOLDER_URL,
        "source_index": "docs/verification/drive-model-sync-own16-20261027/cloud/SOURCE-INDEX44.json"}
    report = {"mode": "applied" if args.apply else "dry-run", "revision": "own16", "folder_url": FOLDER_URL,
              "runtime_models": len(rows), "source_files": len(index["sources"]) * 3,
              "models_changed": sum(r["previous_sha256"] != r["incoming_sha256"] for r in rows),
              "source_policy": "Versioned source paths added; all different pre-existing source files are preserved.",
              "import_policy_merged": SIDECAR_PATHS, "models": rows}
    if args.apply:
        assert (OUT / "before.zip").is_file() and (OUT / "supplemental-before.zip").is_file()
        baseline = read_json(OUT / "baseline.json")
        # Preserve local edits and persistent saves; do not read their contents.
        protected = [f for f in baseline["files"] if f["category"] in {"dirty_code", "shared_profile", "appdata_persistent"}]
        for file in protected:
            assert digest(Path(file["path"])) == file["sha256"], f"Concurrent change: {file['relative_path']}"
        for source, target in copies:
            copy_exact(source, target)
        copy_exact(runtime / "game/data/interiors_manifest.json", ROOT / "game/data/interiors_manifest.json")
        copy_exact(runtime / "game/assets/world/manifest.json", ROOT / "game/assets/world/manifest.json")
        copy_exact(runtime / "game/assets/world/manifest.json", ROOT / "assets/blender/alphabet_island/game_map_manifest.json")
        write_json(ROOT / "assets/blender/interiors/interiors_manifest.json", source_manifest)
        for relative, text in merged_sidecars.items():
            (ROOT / relative).write_text(text, encoding="utf-8")
        for p in (bundle / "metadata").iterdir():
            if p.is_file():
                copy_exact(p, OUT / "cloud" / p.name)
        for file in protected:
            assert digest(Path(file["path"])) == file["sha256"], file["path"]
        for file in baseline["source_files"]:
            assert digest(Path(file["path"])) == file["sha256"], file["path"]
        report["protected_persistent_and_dirty_files"] = len(protected)
        report["old_source_files_preserved"] = len(baseline["source_files"])
        report["runtime_hashes_verified_after_copy"] = all(digest(ROOT / r["runtime_path"]) == r["incoming_sha256"] for r in rows)
    write_json(OUT / ("sync-report.json" if args.apply else "preflight.json"), report)
    print(json.dumps({k: v for k, v in report.items() if k != "models"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
