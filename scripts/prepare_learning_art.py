"""Copy selected generated story art unchanged and audit it without running Godot.

Run with: uv run --with pillow python -X utf8 scripts/prepare_learning_art.py
This script performs no image edits. Optional import changes only affect Godot's
sidecar settings; the engine must subsequently reimport them in a separate step.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path
from typing import Any

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REUSED = {"B", "O", "K"}
PROP_IDS = {
    "book_open_base", "book_cover", "book_page_leaf", "football",
    "greeting_door", "greeting_window", "reading_table", "football_goal_frame",
    "owl_wing", "drumstick",
}
IMPORT_SETTINGS = {
    "compress/mode": "0",
    "mipmaps/generate": "false",
    "process/fix_alpha_border": "false",
    "process/premult_alpha": "false",
}


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def image_qa(path: Path, expected_size: list[int] | None = None, *, square: bool = True) -> dict[str, Any]:
    with Image.open(path) as picture:
        if picture.format != "PNG" or picture.mode != "RGBA":
            raise ValueError(f"Expected a PNG with an actual RGBA channel: {path}")
        picture.load()  # Decode the whole file, not only its header.
        width, height = picture.size
        if not (256 <= width <= 4096 and 256 <= height <= 4096) or (square and width != height):
            layout = "square " if square else ""
            raise ValueError(f"Expected a {layout}256..4096 source canvas, got {picture.size}: {path}")
        if expected_size and list(picture.size) != expected_size:
            raise ValueError(f"Explicit expected_size {expected_size} differs from {picture.size}: {path}")
        alpha = picture.getchannel("A")
        histogram = alpha.histogram()
        corners = [alpha.getpixel(point) for point in [(0, 0), (width-1, 0), (0, height-1), (width-1, height-1)]]
        # Existing accepted sprites have incidental alpha=1 in a few corners.
        if max(corners) > 2 or histogram[0] == 0:
            raise ValueError(f"The canvas background is not transparent at its corners: {path}")
        binary = alpha.point(lambda value: 255 if value >= 128 else 0)
        bounds = binary.getbbox()
        if bounds is None or sum(histogram[128:]) < width * height * 0.005:
            raise ValueError(f"No meaningful visible subject at alpha >=128: {path}")
        left, top, right, bottom = bounds
        if left <= 0 or top <= 0 or right >= width or bottom >= height:
            raise ValueError(f"Visible subject touches the canvas edge: {path}")
        margins = [left/width, top/height, (width-right)/width, (height-bottom)/height]
        warnings = []
        if min(margins) < 0.04:
            warnings.append("Visible silhouette has less than 4 percent padding on at least one edge; inspect in game.")
        return {
            "format": "PNG", "mode": "RGBA", "size": [width, height],
            "alpha_bbox_128": list(bounds),
            "alpha_bbox_128_uv": [left/width, top/height, right/width, bottom/height],
            "alpha_bbox_128_rect_uv": [left/width, top/height, (right-left)/width, (bottom-top)/height],
            "corner_alpha": corners,
            "fully_transparent_pixels": histogram[0],
            "semi_transparent_pixels": sum(histogram[1:255]),
            "fully_opaque_pixels": histogram[255],
            "near_transparent_pixels_alpha_1_to_5": sum(histogram[1:6]),
            "visible_pixels_alpha_128_plus": sum(histogram[128:]),
            "transparent_padding_fraction": margins,
            "warnings": warnings,
        }


def copy_unchanged(source: Path, target: Path, source_hash: str, old_hash: str | None) -> str:
    if target.exists():
        existing_hash = digest(target)
        if existing_hash == source_hash:
            return "already_identical"
        if old_hash is None or existing_hash != old_hash:
            raise ValueError(f"Refusing to overwrite an unrecorded or locally modified file: {target}")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    if digest(target) != source_hash:
        raise ValueError(f"Copied bytes differ from original: {target}")
    return "copied_unchanged"


def configure_import(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"path": path.relative_to(ROOT).as_posix(), "status": "not_imported_yet", "changed": False}
    source = path.read_text(encoding="utf-8-sig")
    if "[params]" not in source:
        raise ValueError(f"Unexpected Godot import sidecar: {path}")
    result = source
    for key, value in IMPORT_SETTINGS.items():
        pattern = rf"(?m)^{re.escape(key)}=.*$"
        if re.search(pattern, result):
            result = re.sub(pattern, f"{key}={value}", result)
        else:
            result = result.replace("[params]", f"[params]\n{key}={value}", 1)
    changed = result != source
    if changed:
        path.write_text(result, encoding="utf-8")
    return {"path": path.relative_to(ROOT).as_posix(), "status": "configured", "changed": changed, "settings": IMPORT_SETTINGS}


def prepare(records_path: Path, configure: bool, require_complete: bool) -> dict[str, Any]:
    manifest_root = ROOT / "assets/art/storybook_v2"
    manifest_path = manifest_root / "manifest.json"
    previous = read_json(manifest_path) if manifest_path.exists() else {}
    previous_by_key = {(item.get("kind", "letter"), item.get("id", item.get("letter"))): item for item in previous.get("assets", [])}
    records = read_json(records_path)
    if not isinstance(records, list):
        raise ValueError("Generation records must be a JSON array.")
    plans = []
    seen: set[tuple[str, str]] = set()
    for record in records:
        kind, identity = record.get("kind"), record.get("id")
        if kind == "letter":
            if not isinstance(identity, str) or not re.fullmatch(r"[A-Z]", identity) or identity in REUSED:
                raise ValueError(f"Expected a new A-Z letter excluding reused B/O/K: {identity}")
        elif kind == "prop":
            if identity not in PROP_IDS:
                raise ValueError(f"Unknown story prop id: {identity}")
        else:
            raise ValueError(f"Unknown asset kind: {kind}")
        key = (kind, identity)
        if key in seen:
            raise ValueError(f"Duplicate generation record: {kind}/{identity}")
        seen.add(key)
        source = Path(record["generated_source"]).resolve(strict=True)
        prompt = record.get("prompt", "")
        if not isinstance(prompt, str) or not prompt.strip():
            raise ValueError(f"Missing provenance prompt: {kind}/{identity}")
        relative = Path("props") / f"{identity}.png" if kind == "prop" else Path(f"{identity}.png")
        original_copy = Path("source") / relative
        runtime = ROOT / "game/assets/learning/storybook_v2" / relative
        item = {
            "id": identity, "kind": kind, "origin": "generated_this_batch",
            "generated_source": source.as_posix(), "original_copy": original_copy.as_posix(),
            "runtime_path": runtime.relative_to(ROOT).as_posix(), "prompt": prompt,
            "referenced_image_paths": record.get("referenced_image_paths", [(ROOT / "assets/art/storybook_v1/source/style-board.png").as_posix()]),
            "sha256": digest(source), "bytes": source.stat().st_size,
            "normalization": "Generated PNG copied unchanged; no pixel edits. Runtime rendering preserves the original file.",
            **image_qa(source, record.get("expected_size"), square=kind == "letter"),
        }
        if kind == "letter":
            item["letter"] = identity
        plans.append((item, source, manifest_root/original_copy, runtime))

    # Reuse the already accepted B/O/K originals; never copy or edit the v1 set.
    old_manifest_path = ROOT / "assets/art/storybook_v1/manifest.json"
    old_manifest = read_json(old_manifest_path)
    reused = []
    for prior in old_manifest["assets"]:
        letter = prior["letter"]
        if letter not in REUSED:
            continue
        runtime = ROOT / prior["runtime_path"]
        original = old_manifest_path.parent / prior["original_copy"]
        if digest(runtime) != prior["sha256"] or digest(original) != prior["sha256"]:
            raise ValueError(f"Previously accepted {letter} files have changed.")
        item = {
            **prior, "id": letter, "kind": "letter", "origin": "reused_accepted_storybook_v1",
            "source_manifest": "../storybook_v1/manifest.json",
            "original_copy": "../storybook_v1/" + prior["original_copy"],
            "bytes": runtime.stat().st_size, **image_qa(runtime),
        }
        reused.append(item)
    if {item["id"] for item in reused} != REUSED:
        raise ValueError("The accepted v1 manifest must contain B/O/K.")

    assets = reused + [plan[0] for plan in plans]
    letters = sorted(item["id"] for item in assets if item["kind"] == "letter")
    props = sorted(item["id"] for item in assets if item["kind"] == "prop")
    missing_letters = sorted(set("ABCDEFGHIJKLMNOPQRSTUVWXYZ") - set(letters))
    missing_props = sorted(PROP_IDS - set(props))
    if require_complete and (missing_letters or missing_props):
        raise ValueError(f"Incomplete batch: letters={missing_letters}, props={missing_props}")
    copies = []
    imports = []
    for item, source, original, runtime in plans:
        previous_item = previous_by_key.get((item["kind"], item["id"]), {})
        old_hash = previous_item.get("sha256")
        for destination in [original, runtime]:
            copies.append({"path": destination.relative_to(ROOT).as_posix(), "status": copy_unchanged(source, destination, item["sha256"], old_hash)})
        if configure:
            imports.append(configure_import(runtime.with_name(runtime.name + ".import")))
    assets.sort(key=lambda item: (item["kind"] != "letter", item["id"]))
    manifest = {
        "schema_version": 2, "art_revision": "storybook-v2", "generator": "built-in image_gen",
        "status": "candidate_pending_in_game_validation",
        "reference": "../storybook_v1/source/style-board.png", "semantic_change": False,
        "preparation": "Unchanged source copies and read-only PNG/alpha inspection. No image editing, engine launch, export, or archive creation.",
        "source_records": records_path.resolve().relative_to(ROOT).as_posix() if records_path.resolve().is_relative_to(ROOT) else records_path.resolve().as_posix(),
        "letters": letters, "props": props, "missing_letters": missing_letters, "missing_props": missing_props,
        "assets": assets,
        "engine_import": {"compression": "lossless", "mipmaps": False, "fix_alpha_border": False, "premultiplied_alpha": False, "source_pixels_unchanged": True},
    }
    write_json(manifest_path, manifest)
    report = {
        "status": "PASS", "scope": "Source integrity, PNG decoding, RGBA, dimensions, transparent margins, byte-identical copies, and optional import settings only; native visual acceptance is separate.",
        "generated_count": len(plans), "reused_count": len(reused), "letter_count": len(letters), "prop_count": len(props),
        "missing_letters": missing_letters, "missing_props": missing_props,
        "source_pixels_unchanged": True, "reused_v1_files_unchanged": True,
        "copies": copies, "imports": imports,
        "assets": [{key: item[key] for key in ["id", "kind", "sha256", "size", "alpha_bbox_128", "alpha_bbox_128_rect_uv", "corner_alpha", "warnings"]} for item in assets],
        "manifest": manifest_path.relative_to(ROOT).as_posix(),
    }
    write_json(ROOT / "docs/verification/art-refresh-all/preparation-report.json", report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--records", type=Path, default=ROOT/".local/art_refresh_all_generation.json")
    parser.add_argument("--configure-imports", action="store_true", help="Set existing v2 .png.import files to lossless, straight alpha, no border rewrite and no mipmaps. Does not run Godot.")
    parser.add_argument("--require-complete", action="store_true", help="Require all 26 letters and all 10 planned story props before copying.")
    args = parser.parse_args()
    try:
        report = prepare(args.records, args.configure_imports, args.require_complete)
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(json.dumps({"status": "FAIL", "error": str(error)}, ensure_ascii=False), file=sys.stderr)
        return 1
    print(json.dumps({key: report[key] for key in ["status", "generated_count", "reused_count", "letter_count", "prop_count", "missing_letters", "missing_props", "manifest"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
