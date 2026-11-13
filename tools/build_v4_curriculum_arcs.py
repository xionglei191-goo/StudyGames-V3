"""Compile `docs/planning/mainline/curriculum_arcs.json` + `game/data/learning/catalog.json`
into a semantically calibrated V5 8-Book / 81-Unit Storyline dataset:
`game/data/learning/curriculum_arcs_v4.json`.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARCS_PATH = ROOT / "docs/planning/mainline/curriculum_arcs.json"
CATALOG_PATH = ROOT / "game/data/learning/catalog.json"
OUT_PATH = ROOT / "game/data/learning/curriculum_arcs_v4.json"

VALID_ROOMS = {
    "village",
    "school",
    "classroom",
    "music_room",
    "art_room",
    "science_room",
    "canteen",
    "playground",
    "football_field",
    "home",
    "home_estate",
    "home_hall",
    "home_bedroom",
    "home_study",
    "home_kitchen",
    "home_dining",
    "home_bathroom",
    "home_balcony",
    *{f"landmark_{chr(c)}" for c in range(ord("A"), ord("Z") + 1)},
}

STOP_WORDS = {
    "a", "an", "the", "am", "is", "are", "was", "were", "be", "been",
    "i", "you", "he", "she", "it", "we", "they", "my", "your", "his", "her", "our", "their",
    "this", "that", "these", "those", "what", "what's", "who", "where", "when", "why", "how",
    "do", "does", "did", "don't", "doesn't", "isn't", "aren't", "can't", "won't",
    "to", "in", "on", "at", "of", "for", "with", "about", "and", "or", "but", "not", "some", "any",
}

ROOM_SPEAKERS = {
    "village": ("npc_bear_uncle", "熊叔 · 晨光广场"),
    "home": ("npc_bear_uncle", "熊叔 · 温馨客厅"),
    "home_estate": ("npc_rabbit_gardener", "兔兔园丁 · 阳光小院"),
    "school": ("textbook_lingling", "Lingling · 山丘学园"),
    "classroom": ("textbook_miss_li", "李老师 · 阳光故事圈"),
    "music_room": ("textbook_anne", "Anne · 音乐工坊"),
    "art_room": ("textbook_peter", "Peter · 美术画室"),
    "science_room": ("textbook_mingming", "Mingming · 科学观察角"),
    "canteen": ("npc_bear_uncle", "餐点主厨 · 暖香食堂"),
    "playground": ("textbook_tim", "Tim · 青草操场"),
    "football_field": ("textbook_dongdong", "Dongdong · 绿茵球场"),
    "landmark_A": ("npc_rabbit_gardener", "兔兔园丁 · A 苹果果园"),
    "landmark_C": ("npc_bear_uncle", "熊叔 · C 蛋糕烘焙坊"),
}

THEME_HINTS: list[tuple[str, set[str]]] = [
    (r"how old", {"old", "eight", "nine", "ten", "seven", "six", "five"}),
    (r"how are you", {"fine", "good", "well", "glad", "happy"}),
    (r"what time", {"time", "clock", "o'clock", "day", "night", "eleven", "twelve"}),
    (r"what's this|farm|农场", {"cow", "duck", "horse", "cat", "dog", "sheep", "hen", "goose"}),
    (r"colour|color", {"colour", "red", "blue", "yellow", "green", "white", "black", "pink", "orange"}),
    (r"weather", {"weather", "sunny", "rainy", "windy", "cloudy", "snowy", "warm", "cold", "cool", "hot"}),
]


def _speaker_for_room(room_id: str) -> tuple[str, str]:
    if room_id in ROOM_SPEAKERS:
        return ROOM_SPEAKERS[room_id]
    if room_id.startswith("landmark_"):
        letter = room_id.split("_", 1)[1]
        return (f"host_{letter}", f"{letter} 馆长伙伴 · 字母工坊")
    return ("npc_bear_uncle", "小岛伙伴")


def _en_tokens(text: str) -> set[str]:
    raw = {t.lower() for t in re.findall(r"[a-zA-Z']+", text)}
    expanded = set(raw)
    for tok in list(raw):
        if tok.endswith("s") and len(tok) > 3:
            expanded.add(tok[:-1])
        if tok.endswith("es") and len(tok) > 4:
            expanded.add(tok[:-2])
    return expanded - STOP_WORDS


def _zh_bigrams(text: str) -> set[str]:
    cjk = "".join(re.findall(r"[\u4e00-\u9fff]+", text))
    return {cjk[i : i + 2] for i in range(len(cjk) - 1)}


def score_unit_word(entry: dict, source_title: str, event_title: str, player_goal: str) -> tuple[int, int, int, str]:
    word = str(entry.get("spelling_display", "")).strip()
    w_low = word.lower()
    meaning = str(entry.get("meaning_zh", ""))

    title_tokens = _en_tokens(source_title)
    zh_probe = f"{event_title} {player_goal}"
    zh_bgs = _zh_bigrams(zh_probe)
    meaning_cjk = "".join(re.findall(r"[\u4e00-\u9fff]+", meaning))

    # Penalty for pure function/stop words or contractions
    is_stop_or_contraction = 1 if (w_low in STOP_WORDS or "'" in w_low or " " in w_low and w_low.startswith(("is ", "do "))) else 0

    semantic_tier = 4
    # Tier 0: Exact content word in unit English title!
    w_tokens = _en_tokens(w_low)
    if (w_low in title_tokens) or (w_tokens and w_tokens & title_tokens):
        semantic_tier = 0
    else:
        # Tier 1: Explicit communicative theme hint match
        combined_probe = f"{source_title} {event_title}".lower()
        for pat, pref_set in THEME_HINTS:
            if re.search(pat, combined_probe) and w_low in pref_set:
                semantic_tier = 1
                break
        # Tier 2: Chinese concept overlap with unit event_title / player_goal
        if semantic_tier > 2:
            if (len(meaning_cjk) >= 2 and any(bg in zh_bgs for bg in _zh_bigrams(meaning_cjk))) or (
                len(meaning_cjk) == 1 and meaning_cjk in event_title
            ):
                semantic_tier = 2
            elif not is_stop_or_contraction and len(word) >= 3:
                semantic_tier = 3

    req_tier = 0 if entry.get("requirement") in ("listen_speak_read_write", "listen_speak_read") else 1
    return (is_stop_or_contraction, semantic_tier, req_tier, w_low)


def main() -> None:
    arcs = json.loads(ARCS_PATH.read_text(encoding="utf-8"))
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))

    books_meta = {b["book_id"]: b for b in arcs.get("books", [])}
    entries_by_unit: dict[tuple[str, str], list[dict]] = {}
    entries_by_book: dict[str, list[dict]] = {}

    for entry in catalog.get("entries", []):
        su = entry.get("source_unit", {})
        bid = str(su.get("book_id", ""))
        entries_by_book.setdefault(bid, []).append(entry)
        for uid in su.get("unit_ids", []):
            entries_by_unit.setdefault((bid, str(uid)), []).append(entry)

    out_books = [
        {
            "book_id": b["book_id"],
            "book_title": b["book_title"],
            "arc_title": b["arc_title"],
            "grade": b["grade"],
            "volume": b["volume"],
            "edition": b["edition"],
            "unit_count": b["unit_count"],
        }
        for b in arcs.get("books", [])
    ]

    out_units = []
    for u in arcs.get("units", []):
        bid = str(u["book_id"])
        uid = str(u["unit_id"])
        u_num = int(uid.replace("unit-", ""))
        b_meta = books_meta[bid]

        raw_rooms = [r for r in u.get("room_ids", []) if r in VALID_ROOMS]
        if not raw_rooms:
            raw_rooms = ["village", "school"]
        primary_room = raw_rooms[0]
        for cand in raw_rooms:
            if cand != "village":
                primary_room = cand
                break

        npc_id, speaker = _speaker_for_room(primary_room)

        unit_words = entries_by_unit.get((bid, uid), [])
        if not unit_words:
            book_pool = entries_by_book.get(bid, [])
            if book_pool:
                start = ((u_num - 1) * 4) % len(book_pool)
                unit_words = [book_pool[(start + i) % len(book_pool)] for i in range(min(6, len(book_pool)))]

        src_title = str(u["source_title"])
        ev_title = str(u["event_title"])
        p_goal = str(u["player_goal"])

        sorted_words = sorted(unit_words, key=lambda e: score_unit_word(e, src_title, ev_title, p_goal))

        # Deduplicate by lowercase spelling while picking top 4
        featured = []
        seen_spellings = set()
        for w in sorted_words:
            sp = str(w["spelling_display"])
            if sp.lower() in seen_spellings:
                continue
            seen_spellings.add(sp.lower())
            featured.append(
                {
                    "entry_id": str(w["entry_id"]),
                    "word": sp,
                    "zh": str(w["meaning_zh"]),
                }
            )
            if len(featured) >= 4:
                break

        raw_actions = u.get("actions", [])
        stage_texts = [str(a.get("text", "")) for a in raw_actions[:3]]
        while len(stage_texts) < 3:
            stage_texts.append("与伙伴分享今天的故事，并在小岛留下温暖纪念。")

        lead_word = featured[0]["word"] if featured else src_title
        lead_zh = featured[0]["zh"] if featured else ev_title

        out_units.append(
            {
                "order": int(u["order"]),
                "chapter_key": f"{bid}/{uid}",
                "book_id": bid,
                "book_title": str(b_meta["book_title"]),
                "arc_title": str(b_meta["arc_title"]),
                "unit_id": uid,
                "unit_number": u_num,
                "source_title": src_title,
                "event_title": ev_title,
                "player_goal": p_goal,
                "primary_room": primary_room,
                "room_ids": raw_rooms,
                "host_npc_id": npc_id,
                "host_speaker": speaker,
                "lead_entry_id": featured[0]["entry_id"] if featured else "",
                "lead_word": lead_word,
                "lead_zh": lead_zh,
                "featured_words": featured,
                "stages": [
                    {"stage": 1, "title": "聆听伙伴心愿", "text": stage_texts[0]},
                    {"stage": 2, "title": "亲手共创体验", "text": stage_texts[1]},
                    {"stage": 3, "title": "点亮小岛回响", "text": stage_texts[2]},
                ],
                "world_keepsake": str(u.get("world_change", {}).get("description", f"{u['event_title']}纪念展牌已常驻小岛。")),
            }
        )

    payload = {
        "schema_version": 5,
        "book_count": len(out_books),
        "unit_count": len(out_units),
        "books": out_books,
        "units": out_units,
    }
    OUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Compiled {len(out_books)} books, {len(out_units)} units -> {OUT_PATH} ({OUT_PATH.stat().st_size} bytes)")
    for u in out_units[:12]:
        print(f"  {u['chapter_key']} | {u['source_title']} -> lead={u['lead_word']} ({u['lead_zh']}) | {[w['word'] for w in u['featured_words']]}")


if __name__ == "__main__":
    main()
