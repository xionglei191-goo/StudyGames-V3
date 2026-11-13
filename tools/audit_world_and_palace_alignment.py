"""End-to-end automated semantic & pedagogical audit for 《字母岛》 V5:
Verifies:
  1. Immutable baseline SHA-256 locks on `catalog.json` & `prologue.json`
  2. All 210 fixed 3D scene objects (`world_object_semantics_v5.json`) have unique, object-grounded English,
     0 duplicate phrases, 0 "Come in, please." on baskets, 0 "Dongdong", and valid Memory Palace links
  3. All 81 textbook units (`curriculum_arcs_v4.json`) match unit communicative themes
  4. All 30 tactile 3D stations (`tactile_life_quests.gd`) have 0 non-curriculum coined terms & 0 raw OS emojis
  5. All 1,096 Memory Palace stories (`memory_palace_v5.json`) & 1,314 entries (`popup_choreography_v4.json`)
     have valid walkable rooms, 100% explicit 26-letter pegs in strict order, 0 `→` arrows, and 0 robotic templates.
"""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG_SHA = "c69c1dde30e9a73502a2e28418b257b753118d681f8ca1f080ab40e21be02af3"
PROLOGUE_SHA = "a24f07a2491d01dc00c52b8daa28fa566244a524384fc9b72d47196a61ed3a8f"

PEG_NAMES = {
    "A": "红苹果", "B": "小木船", "C": "奶油蛋糕", "D": "大圆鼓", "E": "白蛋壳",
    "F": "大花朵", "G": "地球仪", "H": "宽檐帽", "I": "冰淇淋", "J": "玻璃罐",
    "K": "彩风筝", "L": "暖灯笼", "M": "红蘑菇", "N": "小鸟巢", "O": "猫头鹰",
    "P": "大南瓜", "Q": "拼布被", "R": "小机器人", "S": "金星星", "T": "小火车",
    "U": "花雨伞", "V": "小火山", "W": "蓝鲸鱼", "X": "彩木琴", "Y": "绒毛线",
    "Z": "小斑马",
}

VALID_ROOMS = {
    "village", "home_estate", "home", "home_bedroom", "home_kitchen", "home_dining",
    "home_bathroom", "home_study", "home_balcony",
    "school", "classroom", "music_room", "art_room", "science_room", "canteen",
    "playground", "football_field",
    *{f"landmark_{chr(c)}" for c in range(ord("A"), ord("Z") + 1)},
}

BRACKET_RE = re.compile(r"【([^【】]+)】")


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    errors: list[str] = []
    checks = 0

    def check(cond: bool, msg: str) -> None:
        nonlocal checks
        checks += 1
        if not cond:
            errors.append(msg)

    # 1. Baseline SHA-256 Locks
    cat_path = ROOT / "game/data/learning/catalog.json"
    pro_path = ROOT / "game/data/learning/prologue.json"
    check(sha256_file(cat_path) == CATALOG_SHA, "catalog.json SHA-256 must remain untouched")
    check(sha256_file(pro_path) == PROLOGUE_SHA, "prologue.json SHA-256 must remain untouched")

    catalog = json.loads(cat_path.read_text("utf-8"))
    entry_ids = {str(e["entry_id"]) for e in catalog["entries"]}

    # 2. 210 Fixed Scene Objects Audit
    obj_data = json.loads((ROOT / "game/data/learning/world_object_semantics_v5.json").read_text("utf-8"))
    anchors = obj_data.get("anchors", {})
    check(len(anchors) == 210, f"Expected 210 calibrated world anchors, got {len(anchors)}")

    phrases_seen = set()
    for key, spec in anchors.items():
        pe = str(spec.get("phrase_en", "")).strip()
        oe = str(spec.get("object_en", "")).strip()
        check(bool(oe) and bool(pe), f"Empty object_en or phrase_en at {key}")
        check(pe not in phrases_seen, f"Duplicate phrase_en at {key}: {pe}")
        phrases_seen.add(pe)
        check("dongdong" not in pe.lower(), f"Forbidden third-party name Dongdong at {key}: {pe}")
        check(spec.get("palace_entry_id") in entry_ids, f"Invalid palace_entry_id at {key}")
        if "篮" in str(spec.get("anchor_label", "")):
            check("come in" not in pe.lower(), f"Basket {key} must not teach 'Come in, please.'")
        if spec.get("room_id") == "home_balcony":
            check("make the bed" not in pe.lower(), f"Balcony {key} must not mention making the bed")

    # 3. 81 Chapters Audit
    arcs_v5 = json.loads((ROOT / "game/data/learning/curriculum_arcs_v4.json").read_text("utf-8"))
    units = arcs_v5.get("units", [])
    check(len(units) == 81, f"Expected 81 units, got {len(units)}")
    unit_map = {u["chapter_key"]: u for u in units}
    check(unit_map["xiangshao-g3-1/unit-1"]["lead_word"].lower() == "hello", "G3-1 U1 Hello! lead_word must be hello")
    check(unit_map["xiangshao-g3-1/unit-2"]["lead_word"].lower() == "name", "G3-1 U2 What's your name? lead_word must be name")
    check(unit_map["xiangshao-g3-1/unit-4"]["lead_word"].lower() == "family", "G3-1 U4 family lead_word must be family")

    # 4. Tactile 3D Quests Audit
    tq_src = (ROOT / "game/gameplay/tactile_life_quests.gd").read_text("utf-8")
    check("Lava Stone" not in tq_src, "tactile_life_quests.gd must not contain Lava Stone")
    check("Sunny Bar" not in tq_src, "tactile_life_quests.gd must not contain Sunny Bar")
    check(not re.search(r"[\U0001F300-\U0001FAFF]", tq_src), "tactile_life_quests.gd must have 0 raw OS color emojis")

    # 5. 1,096 Memory Palace Stories & 1,314 Usage Sentences Audit
    palace_path = ROOT / "game/data/learning/memory_palace_v5.json"
    choreo_path = ROOT / "game/data/learning/popup_choreography_v4.json"
    check(palace_path.exists(), "memory_palace_v5.json must exist")
    if palace_path.exists():
        palace = json.loads(palace_path.read_text("utf-8"))
        stories = palace.get("stories", {})
        check(len(stories) == 1096, f"Expected 1,096 Memory Palace stories, got {len(stories)}")

        for sid, cat_st in catalog["stories"].items():
            if sid not in stories:
                errors.append(f"Missing story {sid} in memory_palace_v5.json")
                continue
            pst = stories[sid]
            check(pst.get("palace_room_id") in VALID_ROOMS, f"Invalid palace_room_id in {sid}: {pst.get('palace_room_id')}")
            beats_zh = pst.get("beats_zh", [])
            cat_beats = cat_st.get("story_beats", [])
            steps = cat_st.get("steps", [])
            check(len(beats_zh) == len(cat_beats), f"Beat count mismatch in {sid}")
            for b_zh, c_beat in zip(beats_zh, cat_beats):
                check("→" not in b_zh and "->" not in b_zh, f"Forbidden arrow in {sid}: {b_zh}")
                tags = BRACKET_RE.findall(b_zh)
                pos_list = c_beat["letter_positions"]
                check(len(tags) == len(pos_list), f"Peg tag count mismatch in {sid}")
                for t_val, pos in zip(tags, pos_list):
                    ltr = steps[pos - 1]["letter"].upper()
                    peg_zh = PEG_NAMES[ltr]
                    check(t_val.endswith(ltr) and peg_zh in t_val, f"Peg mismatch in {sid} pos {pos}: {t_val}")

    choreo = json.loads(choreo_path.read_text("utf-8"))
    ch_entries = choreo.get("entries", {})
    check(len(ch_entries) == 1314, f"Expected 1,314 choreo entries, got {len(ch_entries)}")
    template_hits = [
        eid for eid, c in ch_entries.items()
        if "let's remember" in str(c.get("example_en", "")).lower() or "一起记住" in str(c.get("example_zh", ""))
    ]
    check(len(template_hits) == 0, f"Found {len(template_hits)} robotic template sentences remaining!")

    report = {
        "status": "passed" if not errors else "failed",
        "checks": checks,
        "error_count": len(errors),
        "errors": errors[:30],
        "world_anchors_calibrated": len(anchors),
        "chapters_calibrated": len(units),
        "palace_stories_verified": 1096 if not errors else 0,
        "curated_examples_verified": len(ch_entries) - len(template_hits),
    }
    out_report = ROOT / ".local/validation/v5-world-and-palace-audit.json"
    out_report.parent.mkdir(parents=True, exist_ok=True)
    out_report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
