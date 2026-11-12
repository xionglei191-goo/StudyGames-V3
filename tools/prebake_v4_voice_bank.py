"""Pre-bake warm neural ONNX voice WAVs for all unique words & chapter lines in StudyGames V4.5.

Run:
    .local/ai-companion-venv/Scripts/python.exe tools/prebake_v4_voice_bank.py
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from services.ai_companion.speech_service import _cache_path, synthesize_piper_sync


def main() -> None:
    catalog_path = ROOT / "game" / "data" / "learning" / "catalog.json"
    arcs_path = ROOT / "game" / "data" / "learning" / "curriculum_arcs_v4.json"
    prologue_path = ROOT / "game" / "data" / "learning" / "prologue.json"

    phrases_en: list[tuple[str, str]] = []
    seen: set[tuple[str, str]] = set()

    def add_item(txt: str, hint: str = "warm") -> None:
        cleaned = " ".join((txt or "").strip().split())[:220]
        if not cleaned:
            return
        key = (cleaned, hint)
        if key not in seen:
            seen.add(key)
            phrases_en.append(key)

    # 1. All 26 alphabet anchors
    if prologue_path.is_file():
        pro = json.loads(prologue_path.read_text(encoding="utf-8"))
        for rec in pro.get("letters", []):
            w = str(rec.get("anchor", {}).get("canonical_word", ""))
            add_item(w, "warm")
            add_item(w, "storyteller")

    # 2. All 1,314 catalog entries (unique words/phrases for both warm & storyteller hints)
    if catalog_path.is_file():
        cat = json.loads(catalog_path.read_text(encoding="utf-8"))
        for entry in cat.get("entries", []):
            w = str(entry.get("spelling_display", ""))
            add_item(w, "warm")
            add_item(w, "storyteller")

    # 3. All 81 chapter stage-1 greetings
    if arcs_path.is_file():
        arcs = json.loads(arcs_path.read_text(encoding="utf-8"))
        for unit in arcs.get("units", []):
            src_title = str(unit.get("source_title", "Island Story"))
            lead_w = str(unit.get("lead_word", "hello"))
            add_item(f'Welcome to "{src_title}"! Today let\'s share "{lead_w}" together!', "warm")

    t0 = time.perf_counter()
    newly_baked = 0
    cached_hits = 0
    for idx, (text, hint) in enumerate(phrases_en, 1):
        out = _cache_path(text, "en", hint)
        if out.is_file() and out.stat().st_size > 256:
            cached_hits += 1
        else:
            if synthesize_piper_sync(text, "en", out):
                newly_baked += 1
        if idx % 200 == 0 or idx == len(phrases_en):
            elapsed = time.perf_counter() - t0
            print(f"[{idx}/{len(phrases_en)}] baked={newly_baked} cached={cached_hits} elapsed={elapsed:.1f}s", flush=True)

    manifest = {
        "version": "4.5.0",
        "engine": "piper_neural_onnx:en_US-amy-medium",
        "total_utterances_ready": newly_baked + cached_hits,
        "newly_baked": newly_baked,
        "cached_hits": cached_hits,
    }
    manifest_path = ROOT / "game" / "data" / "learning" / "voice_manifest_v4.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print("VOICE_BANK_COMPLETE:", json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    main()
