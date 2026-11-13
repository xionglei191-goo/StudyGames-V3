"""Pre-bake warm neural ONNX voice WAVs for all unique words, world objects,
Memory Palace sentences, Situational Roleplays, Bilingual Activities, and core
Chinese fairy-tale narrations in StudyGames V5.0.

Run:
    .local/ai-companion-venv/Scripts/python.exe tools/prebake_v4_voice_bank.py
"""
from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from services.ai_companion.speech_service import _cache_path, synthesize_piper_sync


def clean_zh_beat(raw_zh: str) -> str:
    s = raw_zh.replace("◈", "").replace("✦", "").strip()
    s = re.sub(r"【([^【】]*?)[A-Z]】", r"\1", s)
    s = s.replace("【？神秘精灵】", "神秘小精灵").replace("【", "").replace("】", "")
    return s.strip()


def main() -> None:
    catalog_path = ROOT / "game" / "data" / "learning" / "catalog.json"
    arcs_path = ROOT / "game" / "data" / "learning" / "curriculum_arcs_v4.json"
    prologue_path = ROOT / "game" / "data" / "learning" / "prologue.json"

    utterances: list[tuple[str, str, str]] = []
    seen: set[tuple[str, str, str]] = set()

    def add_item(txt: str, lang: str = "en", hint: str = "warm") -> None:
        cleaned = " ".join((txt or "").strip().split())[:220]
        if not cleaned:
            return
        key = (cleaned, lang, hint)
        if key not in seen:
            seen.add(key)
            utterances.append(key)

    # 1. All 26 alphabet anchors
    if prologue_path.is_file():
        pro = json.loads(prologue_path.read_text(encoding="utf-8"))
        for rec in pro.get("letters", []):
            w = str(rec.get("anchor", {}).get("canonical_word", ""))
            add_item(w, "en", "warm")
            add_item(w, "en", "storyteller")

    # 2. All 1,314 catalog entries
    cat_entries = []
    if catalog_path.is_file():
        cat = json.loads(catalog_path.read_text(encoding="utf-8"))
        cat_entries = cat.get("entries", [])
        for entry in cat_entries:
            w = str(entry.get("spelling_display", ""))
            add_item(w, "en", "warm")
            add_item(w, "en", "storyteller")

    # 3. All 81 chapter stage-1 greetings
    if arcs_path.is_file():
        arcs = json.loads(arcs_path.read_text(encoding="utf-8"))
        for unit in arcs.get("units", []):
            src_title = str(unit.get("source_title", "Island Story"))
            lead_w = str(unit.get("lead_word", "hello"))
            add_item(f'Welcome to "{src_title}"! Today let\'s share "{lead_w}" together!', "en", "warm")

    # 4. All 210 calibrated 3D scene object phrases (V5)
    world_v5_path = ROOT / "game" / "data" / "world_object_semantics_v5.json"
    if world_v5_path.is_file():
        world_v5 = json.loads(world_v5_path.read_text(encoding="utf-8"))
        for spec in world_v5.get("anchors", {}).values():
            if isinstance(spec, dict):
                spoken = str(spec.get("spoken_en", spec.get("english", ""))).replace(" / ", ", ")
                add_item(spoken, "en", "warm")
                add_item(str(spec.get("english", "")), "en", "warm")

    # 5. All 1,096 authentic Memory Palace example sentences + core Chinese fairy-tale narrations
    palace_v5_path = ROOT / "game" / "data" / "learning" / "memory_palace_v5.json"
    if palace_v5_path.is_file():
        palace_v5 = json.loads(palace_v5_path.read_text(encoding="utf-8"))
        stories_map = palace_v5.get("stories", {})
        for st in stories_map.values():
            add_item(str(st.get("example_en", "")), "en", "storyteller")

        # Pre-bake Chinese storyteller narrations for Unit 1 & showcase words
        priority_words = {
            "amazing", "umbrella", "basket", "magnet", "apple", "cake",
            "hello", "good morning", "teacher", "dinner", "book", "milk", "football"
        }
        baked_sids: set[str] = set()
        for entry in cat_entries:
            w_low = str(entry.get("spelling_display", "")).strip().lower()
            src = entry.get("source_unit", {})
            is_g3_u1 = (src.get("book_id") == "xiangshao-g3-1" and "unit-1" in src.get("unit_ids", []))
            if w_low in priority_words or is_g3_u1:
                sid = str(entry.get("story_id", ""))
                if sid in stories_map and sid not in baked_sids:
                    baked_sids.add(sid)
                    st = stories_map[sid]
                    beats = st.get("beats_zh", [])
                    climax = str(st.get("meaning_climax_zh", "")).strip()
                    for idx_b, b_txt in enumerate(beats):
                        cleaned = clean_zh_beat(str(b_txt))
                        if idx_b == len(beats) - 1 and climax:
                            add_item(f"{cleaned} {climax}", "zh", "storyteller")
                        else:
                            add_item(cleaned, "zh", "storyteller")

    # 6. Situational Roleplay lines + Bilingual Campus & Household lines
    rp_path = ROOT / "game" / "gameplay" / "situational_roleplay.gd"
    if rp_path.is_file():
        rp_src = rp_path.read_text(encoding="utf-8")
        for m in re.finditer(r'"(?:en|finale_en)"\s*:\s*"([^"%\n]+)"', rp_src):
            add_item(m.group(1), "en", "warm")

    bilingual_lines = [
        ("Good morning! Three memory palace letters are waiting in your mailbox!", "storyteller"),
        ("Let's play a sunny melody!", "warm"),
        ("Wonderful music! Well done!", "warm"),
        ("Let's paint a sunny postcard!", "warm"),
        ("What a lovely postcard!", "warm"),
        ("Let's mix colours together!", "warm"),
        ("Yellow and blue make green!", "warm"),
        ("Red and yellow make orange!", "warm"),
        ("Red and blue make purple!", "warm"),
        ("green", "warm"), ("red", "warm"), ("yellow", "warm"), ("blue", "warm"), ("purple", "warm"),
        ("Let's set the mats, plates, and cups!", "warm"),
        ("Let's set the tea cups and fruit plate!", "warm"),
        ("Fold the soft quilt and make the bed!", "warm"),
        ("Put the picture books back neatly!", "warm"),
        ("Hang the clean socks in the sun!", "warm"),
        ("Wash the fresh green vegetables!", "warm"),
        ("Wash your hands with soap and water!", "warm"),
        ("Water the colourful garden flowers!", "warm"),
        ("All clean and tidy! Great job!", "warm"),
        ("Let's kick the football into the goal!", "warm"),
        ("Goal! Great shot!", "warm"),
        ("Nice try! Kick again!", "warm"),
        ("Five shots finished! Fantastic job!", "warm"),
    ]
    for txt, hint in bilingual_lines:
        add_item(txt, "en", hint)

    t0 = time.perf_counter()
    newly_baked = 0
    cached_hits = 0
    for idx, (text, lang, hint) in enumerate(utterances, 1):
        out = _cache_path(text, lang, hint)
        if out.is_file() and out.stat().st_size > 256:
            cached_hits += 1
        else:
            if synthesize_piper_sync(text, lang, out):
                newly_baked += 1
        if idx % 200 == 0 or idx == len(utterances):
            elapsed = time.perf_counter() - t0
            print(f"[{idx}/{len(utterances)}] baked={newly_baked} cached={cached_hits} elapsed={elapsed:.1f}s", flush=True)

    manifest = {
        "version": "5.1.0",
        "engines": [
            "piper_neural_onnx:en_US-amy-medium",
            "piper_neural_onnx:zh_CN-huayan-medium",
        ],
        "total_utterances_ready": newly_baked + cached_hits,
        "newly_baked": newly_baked,
        "cached_hits": cached_hits,
    }
    manifest_path = ROOT / "game" / "data" / "learning" / "voice_manifest_v4.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print("VOICE_BANK_COMPLETE:", json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    main()
