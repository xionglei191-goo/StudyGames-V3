"""Merge the 6 authored Memory Palace batches (`out_01.json` .. `out_06.json`) into:
  1. `game/data/learning/memory_palace_v5.json` (all 1,096 vivid fairy-tale stories + real spatial loci)
  2. `game/data/learning/popup_choreography_v4.json` (all 1,314 authentic usage sentences, 0 templates)
Leaves `game/data/learning/catalog.json` 100% untouched.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "game/data/learning/catalog.json"
PALACE_OUT_PATH = ROOT / "game/data/learning/memory_palace_v5.json"
CHOREO_OUT_PATH = ROOT / "game/data/learning/popup_choreography_v4.json"
DEFAULT_BATCH_DIR = Path(
    r"C:\Users\Administrator\.gemini\antigravity\brain\db322f3e-9594-4cdb-af2e-9a87ef01d9d2\scratch\palace_batches"
)


def main() -> int:
    batch_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_BATCH_DIR
    catalog = json.loads(CATALOG_PATH.read_text("utf-8"))

    stories_out: dict[str, dict] = {}
    for idx in range(1, 7):
        p = batch_dir / f"out_{idx:02d}.json"
        if not p.exists():
            print(f"ERROR: Missing batch output file {p}")
            return 1
        chunk = json.loads(p.read_text("utf-8"))
        for rec in chunk:
            sid = str(rec["story_id"])
            stories_out[sid] = {
                "story_id": sid,
                "title_zh": str(rec["title_zh"]).strip(),
                "palace_room_id": str(rec["palace_room_id"]).strip(),
                "palace_room_zh": str(rec["palace_room_zh"]).strip(),
                "palace_locus_zh": str(rec["palace_locus_zh"]).strip(),
                "beats_zh": [str(b).strip() for b in rec["beats_zh"]],
                "meaning_climax_zh": str(rec["meaning_climax_zh"]).strip(),
                "dance_style": str(rec["dance_style"]).strip(),
                "example_en": str(rec["example_en"]).strip(),
                "example_zh": str(rec["example_zh"]).strip(),
            }

    expected_sids = set(catalog["stories"].keys())
    if set(stories_out.keys()) != expected_sids:
        missing = expected_sids - set(stories_out.keys())
        extra = set(stories_out.keys()) - expected_sids
        print(f"ERROR: Story ID mismatch! missing={len(missing)}, extra={len(extra)}")
        return 1

    # Sync all 1,314 occurrences in `popup_choreography_v4.json`
    choreo_entries: dict[str, dict] = {}
    entry_to_story: dict[str, str] = {}
    for entry in catalog["entries"]:
        eid = str(entry["entry_id"])
        sid = str(entry["story_id"])
        st = stories_out[sid]
        entry_to_story[eid] = sid
        choreo_entries[eid] = {
            "word": str(entry["spelling_display"]),
            "meaning_zh": str(entry["meaning_zh"]),
            "dance_style": st["dance_style"],
            "example_en": st["example_en"],
            "example_zh": st["example_zh"],
            "palace_room_id": st["palace_room_id"],
            "palace_room_zh": st["palace_room_zh"],
            "palace_locus_zh": st["palace_locus_zh"],
            "curated": True,
        }

    palace_payload = {
        "schema_version": 5,
        "story_count": len(stories_out),
        "entry_count": len(entry_to_story),
        "stories": dict(sorted(stories_out.items())),
        "entry_to_story": entry_to_story,
    }
    PALACE_OUT_PATH.write_text(json.dumps(palace_payload, ensure_ascii=False, indent=2), encoding="utf-8")

    choreo_payload = {
        "schema_version": 5,
        "entry_count": len(choreo_entries),
        "entries": choreo_entries,
    }
    CHOREO_OUT_PATH.write_text(json.dumps(choreo_payload, ensure_ascii=False, indent=2), encoding="utf-8")

    print(
        f"Merged {len(stories_out)} Memory Palace stories -> {PALACE_OUT_PATH.name} ({PALACE_OUT_PATH.stat().st_size} bytes) "
        f"and {len(choreo_entries)} curated entries -> {CHOREO_OUT_PATH.name} ({CHOREO_OUT_PATH.stat().st_size} bytes)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
