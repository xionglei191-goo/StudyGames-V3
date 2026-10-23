"""Read-only SHA audit of pre-v3 sources and the real save; never opens them for write."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def sha(path: Path) -> str:
    if not path.is_file():
        return "missing"
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def baseline() -> dict:
    selected: dict[str, str] = {}
    previous = json.loads((ROOT / "docs/verification/art-refresh-all/protected-originals.json").read_text(encoding="utf-8-sig"))
    for row in previous["items"]:
        selected[row["path"]] = "original_3d_source"
    manifest_path = ROOT / "assets/art/storybook_v2/manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    for row in manifest["assets"]:
        source = (manifest_path.parent / row["original_copy"]).resolve()
        selected[source.relative_to(ROOT).as_posix()] = "accepted_2d_source"
        selected[row["runtime_path"]] = "accepted_2d_runtime"
    for path in ["game/data/learning/catalog.json", "game/data/learning/prologue.json"]:
        if (ROOT / path).is_file():
            selected[path] = "learning_content"
    for path in (ROOT / "game/actors/p1").glob("*.tres"):
        selected[path.relative_to(ROOT).as_posix()] = "existing_animation_library"
    for path in ["game/actors/p1_action_source.gd", "game/assets/world/island.glb", "game/data/interiors_manifest.json"]:
        selected[path] = "existing_gameplay_source"
    for path in (ROOT / "game/assets/interiors").glob("*.glb"):
        selected[path.relative_to(ROOT).as_posix()] = "existing_runtime_map"
    records = []
    for path, category in sorted(selected.items()):
        source = ROOT / path
        records.append({"path": path, "category": category, "bytes": source.stat().st_size if source.is_file() else None, "sha256": sha(source)})
    save_root = Path(os.environ["APPDATA"]) / "Godot/app_userdata/字母岛 · 我的第一天"
    saves = []
    for name in ["island-save-v1.json", "island-save-v1.json.bak"]:
        path = save_root / name
        saves.append({"path": str(path), "bytes": path.stat().st_size if path.is_file() else None, "sha256": sha(path)})
    return {"created_utc": datetime.now(timezone.utc).isoformat(), "scope": "Pre-v3 protected sources and formal save bytes; no engine run", "files": records, "formal_saves": saves}


def audit() -> dict:
    before = json.loads((HERE / "protected-baseline.json").read_text(encoding="utf-8"))
    rows = []
    for record in before["files"] + before["formal_saves"]:
        path = Path(record["path"])
        if not path.is_absolute():
            path = ROOT / path
        digest = sha(path)
        rows.append({"path": record["path"], "before": record["sha256"], "after": digest, "unchanged": digest == record["sha256"]})
    return {"checked_utc": datetime.now(timezone.utc).isoformat(), "status": "PASS" if all(row["unchanged"] for row in rows) else "FAIL", "files": len(rows), "items": rows}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--create-baseline", action="store_true")
    args = parser.parse_args()
    path = HERE / ("protected-baseline.json" if args.create_baseline else "protected-final.json")
    if args.create_baseline and path.exists():
        raise SystemExit("Existing baseline is immutable; refusing overwrite")
    report = baseline() if args.create_baseline else audit()
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"report": str(path), "files": len(report["files"]) if isinstance(report["files"], list) else report["files"], "status": report.get("status", "BASELINE_CREATED")}, ensure_ascii=False))
    raise SystemExit(0 if report.get("status", "PASS") == "PASS" else 1)
