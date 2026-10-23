"""Decode native character evidence and compare image hashes without modifying images."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2] / "game"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inspect_report(path: Path) -> dict:
    report = json.loads(path.read_text(encoding="utf-8"))
    checks = []
    resource_checks = []
    for resource_path, expected_sha in report["runtime_sha256"].items():
        local_path = PROJECT / resource_path.removeprefix("res://")
        actual_sha = digest(local_path) if local_path.is_file() else "missing"
        resource_checks.append({"resource":resource_path,"expected_sha256":expected_sha,"current_sha256":actual_sha,"passed":expected_sha == actual_sha})
    groups: dict[str, list[Path]] = {}
    for record in report["captures"]:
        image_path = Path(record["path"])
        with Image.open(image_path) as image:
            image.load()
            size_ok = list(image.size) == record["image_size"]
            # Sampled colour count is a corruption/blank-screen check, not a quality grade.
            sample = image.convert("RGB").resize((96, 60))
            colour_count = len(set(sample.getdata()))
        hash_ok = digest(image_path) == record["sha256"]
        checks.append({"file":str(image_path),"size_matches":size_ok,"sha_matches":hash_ok,"sampled_colours":colour_count,"passed":size_ok and hash_ok and colour_count > 64})
        if image_path.name.startswith("frame-"):
            groups.setdefault(image_path.parent.name, []).append(image_path)
    sequences = []
    for name, images in sorted(groups.items()):
        changed_pairs = 0
        largest_changed_bbox = None
        previous = None
        for image_path in sorted(images):
            with Image.open(image_path) as image:
                rgb = image.convert("RGB")
                # Exclude captions so elapsed-time text cannot satisfy visible motion.
                body = rgb.crop((0, rgb.height // 4, rgb.width, rgb.height))
            if previous is not None:
                box = ImageChops.difference(previous, body).getbbox()
                if box:
                    changed_pairs += 1
                    largest_changed_bbox = box
            previous = body
        sequences.append({"sequence":name,"frames":len(images),"changed_frame_pairs_outside_caption":changed_pairs,"last_changed_bbox":largest_changed_bbox,"passed":len(images) > 10 and changed_pairs > 3})
    return {"report":str(path),"source_report_pass":report["status"] == "PASS","runtime_resources":resource_checks,"images":checks,"sequences":sequences,"passed":bool(checks) and report["status"] == "PASS" and all(row["passed"] for row in resource_checks) and all(row["passed"] for row in checks) and len(sequences) == 6 and all(row["passed"] for row in sequences)}


if __name__ == "__main__":
    paths = [HERE / f"native-{size}-characters.json" for size in ["1440x900", "960x640"]]
    missing = [str(path) for path in paths if not path.is_file()]
    reports = [inspect_report(path) for path in paths if path.is_file()]
    result = {"status":"PASS" if not missing and all(row["passed"] for row in reports) else "FAIL","missing_reports":missing,"reports":reports,"scope":"Read-only current runtime resource SHA against captured report; PNG decoding, recorded dimensions and SHA, nonblank sampled colours, and visible changes outside captions. Does not replace human visual review."}
    (HERE / "character-image-audit.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"status":result["status"],"reports":len(reports),"missing_reports":missing,"images":sum(len(row["images"]) for row in reports)},ensure_ascii=False))
    raise SystemExit(0 if result["status"] == "PASS" else 1)
