#!/usr/bin/env python3
"""V10 Core Island Speech Corpus Extractor for StudyGames.

Reads StudyGames data & GDScript dialogue catalogs (read-only) and extracts all
core spoken utterances mapped to their exact V10 `(archetype, lang, synth_text)`
plus all normalized lookup `alias_keys` matching `game/core/ai_companion_bridge.gd`.

Outputs:
  assets/voice_bank_v10/corpus.json
"""
from __future__ import annotations

import ast
import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from services.ai_companion.voice_profiles import (  # noqa: E402
    PURE_ANIMAL_KEYS,
    VOICE_ARCHETYPES,
    resolve_voice_profile,
    strip_animal_interjection,
)

OUT_DIR = ROOT / "assets" / "voice_bank_v10"
CORPUS_PATH = OUT_DIR / "corpus.json"

ALL_13_ARCHETYPES: tuple[str, ...] = (
    "mother_affectionate",
    "father_warm",
    "teacher_gentle",
    "storyteller",
    "boy_sunny",
    "girl_bright",
    "uncle_warm",
    "elder_wise",
    "grandma_warm",
    "artisan_male",
    "artisan_female",
    "mascot_dino",
    "mascot_parrot",
)

BUNDLED_TARGET_ARCHETYPES: tuple[str, ...] = (
    "mother_affectionate",
    "father_warm",
    "teacher_gentle",
    "storyteller",
    "boy_sunny",
    "girl_bright",
    "uncle_warm",
    "mascot_dino",
    "mascot_parrot",
)

ZH_UI_SYMBOLS: tuple[str, ...] = ("★", "☆", "◈", "◇", "♪", "·", "【", "】")


def norm_text_for_bank(raw: str) -> str:
    s = raw.replace("\r", " ").replace("\n", " ").replace("\t", " ")
    s = " ".join(s.split()).strip().lower()
    return s


def bank_entry_key(archetype: str, lang: str, raw_text: str) -> str:
    nlang = "en" if (lang or "en").lower().startswith("en") else "zh"
    norm = norm_text_for_bank(raw_text)
    digest = hashlib.sha1(norm.encode("utf-8")).hexdigest()[:20]
    return f"{archetype}|{nlang}|{digest}"


def clean_emoji_prefix(raw: str) -> str:
    buf: list[str] = []
    for ch in raw:
        cp = ord(ch)
        if cp >= 0x1F000 or cp in (0x2726, 0x2727, 0x2728, 0xFE0E, 0xFE0F):
            continue
        buf.append(ch)
    return "".join(buf).strip()


def clean_zh_for_tts(raw_zh: str) -> str:
    s = raw_zh
    for sym in ZH_UI_SYMBOLS:
        s = s.replace(sym, " ")
    return " ".join(s.split()).strip()


def normalize_hint(npc_or_hint: str) -> str:
    key = (npc_or_hint or "warm").strip().lower()
    if key.startswith("actor:"):
        key = key[len("actor:") :].strip()
    return key or "warm"


def archetype_for_hint(npc_or_hint: str) -> str:
    key = normalize_hint(npc_or_hint)
    if key in PURE_ANIMAL_KEYS:
        return "storyteller"
    return str(resolve_voice_profile(key)["profile_id"])


def npc_for_room(room_id: str) -> str:
    if room_id.startswith("landmark_"):
        return "resident_" + room_id[len("landmark_") :].lower()
    campus_map = {
        "school": "textbook_lingling",
        "classroom": "textbook_miss_li",
        "music_room": "textbook_miss_lin",
        "art_room": "textbook_lingling",
        "science_room": "textbook_mr_chen",
        "canteen": "textbook_dongdong",
        "playground": "textbook_peter",
        "football_field": "textbook_mr_wang",
        "village": "npc_bear_uncle",
        "home": "textbook_role_lingling_mother",
        "home_kitchen": "textbook_role_lingling_mother",
        "home_bedroom": "textbook_role_lingling_mother",
        "home_bathroom": "textbook_role_lingling_mother",
        "home_balcony": "textbook_role_lingling_mother",
        "home_study": "textbook_role_lingling_father",
        "home_dining": "textbook_role_lingling_father",
        "home_estate": "textbook_role_lingling_father",
    }
    if room_id in campus_map:
        return campus_map[room_id]
    if room_id.startswith("home"):
        return "textbook_role_lingling_mother"
    return "warm"


def parse_gd_const_dict(gd_path: Path, const_name: str) -> dict[str, Any]:
    """Extract a top-level `const NAME := { ... }` literal from a GDScript file."""
    src = gd_path.read_text(encoding="utf-8")
    m = re.search(rf"\bconst\s+{re.escape(const_name)}\s*:?=\s*\{{", src)
    if not m:
        raise ValueError(f"Could not find `const {const_name}` in {gd_path}")
    start = m.end() - 1
    depth = 0
    in_str = False
    esc = False
    end = -1
    out_chars: list[str] = []
    i = start
    n = len(src)
    while i < n:
        ch = src[i]
        if in_str:
            out_chars.append(ch)
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            i += 1
            continue
        if ch == '"':
            in_str = True
            out_chars.append(ch)
            i += 1
            continue
        if ch == "#":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                out_chars.append(ch)
                end = i + 1
                break
        out_chars.append(ch)
        i += 1

    if end < 0:
        raise ValueError(f"Unclosed brace for `const {const_name}` in {gd_path}")

    literal = "".join(out_chars)
    tokens = re.split(r'("(?:\\.|[^"\\])*")', literal)
    for idx in range(0, len(tokens), 2):
        tokens[idx] = re.sub(r"\btrue\b", "True", tokens[idx])
        tokens[idx] = re.sub(r"\bfalse\b", "False", tokens[idx])
        tokens[idx] = re.sub(r"\bnull\b", "None", tokens[idx])
    py_lit = "".join(tokens)
    parsed = ast.literal_eval(py_lit)
    if not isinstance(parsed, dict):
        raise ValueError(f"`const {const_name}` did not evaluate to dict")
    return parsed


class CorpusBuilder:
    def __init__(self) -> None:
        self.items: dict[str, dict[str, Any]] = {}
        self.key_owner: dict[str, str] = {}
        self.source_counts: Counter[str] = Counter()

    def add(
        self,
        npc_or_hint: str,
        lang: str,
        synth_text: str,
        source: str,
        extra_raw_aliases: list[str] | None = None,
    ) -> None:
        hint = normalize_hint(npc_or_hint)
        nlang = "en" if (lang or "en").lower().startswith("en") else "zh"
        arch = archetype_for_hint(hint)

        raw_candidates: list[str] = [synth_text]
        if extra_raw_aliases:
            raw_candidates.extend(extra_raw_aliases)

        spoke_text = synth_text.strip()
        if not spoke_text:
            return

        # Pure animals strip leading cries ("Meow! ", "Woof woof! ", "喵～", "汪汪！")
        if hint in PURE_ANIMAL_KEYS:
            stripped = strip_animal_interjection(spoke_text)
            if stripped:
                spoke_text = stripped

        if nlang == "zh":
            em_clean = clean_emoji_prefix(spoke_text)
            zh_clean = clean_zh_for_tts(em_clean)
            if zh_clean:
                spoke_text = zh_clean

        norm_primary = norm_text_for_bank(spoke_text)
        if not norm_primary:
            return

        primary_digest = hashlib.sha1(norm_primary.encode("utf-8")).hexdigest()[:20]
        clip_id = f"{arch}_{nlang}_{primary_digest}"
        primary_key = f"{arch}|{nlang}|{primary_digest}"

        alias_texts: list[str] = [spoke_text]
        for rc in raw_candidates:
            if not rc or not rc.strip():
                continue
            alias_texts.append(rc)
            if nlang == "zh":
                ec = clean_emoji_prefix(rc)
                zc = clean_zh_for_tts(ec)
                if ec:
                    alias_texts.append(ec)
                if zc:
                    alias_texts.append(zc)
            if hint in PURE_ANIMAL_KEYS:
                st = strip_animal_interjection(rc)
                if st:
                    alias_texts.append(st)
                    if nlang == "zh":
                        alias_texts.append(clean_zh_for_tts(clean_emoji_prefix(st)))

        if clip_id not in self.items:
            self.items[clip_id] = {
                "clip_id": clip_id,
                "archetype": arch,
                "lang": nlang,
                "text": spoke_text,
                "norm_text": norm_primary,
                "primary_key": primary_key,
                "alias_keys": [],
                "sources": [],
            }
            self.source_counts[source] += 1

        rec = self.items[clip_id]
        if source not in rec["sources"]:
            rec["sources"].append(source)

        for at in alias_texts:
            nt = norm_text_for_bank(at)
            if not nt:
                continue
            ak = bank_entry_key(arch, nlang, at)
            owner = self.key_owner.get(ak)
            if owner is None:
                self.key_owner[ak] = clip_id
                if ak not in rec["alias_keys"]:
                    rec["alias_keys"].append(ak)
            elif owner == clip_id and ak not in rec["alias_keys"]:
                rec["alias_keys"].append(ak)


def harvest_spatial_clusters(cb: CorpusBuilder) -> None:
    path = ROOT / "game" / "data" / "learning" / "spatial_word_clusters_v6.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    rooms: dict[str, Any] = data.get("rooms", {})

    for room_id, cluster in rooms.items():
        comp_npc = str(cluster.get("companion_npc_id", "warm"))
        room_host = npc_for_room(room_id)
        macros: list[dict[str, Any]] = cluster.get("macro_items", [])

        all_room_items: list[dict[str, Any]] = []
        for macro in macros:
            all_room_items.append(macro)
            for l2 in macro.get("layer2_items", []):
                all_room_items.append(l2)

            ptask = macro.get("placement_task") or {}
            if ptask.get("prompt_en"):
                cb.add(comp_npc, "en", str(ptask["prompt_en"]), "spatial_placement_prompt")
            for step in macro.get("placement_steps", []):
                if step.get("prompt_en"):
                    cb.add(comp_npc, "en", str(step["prompt_en"]), "spatial_placement_prompt")

        for item in all_room_items:
            word = str(item.get("word", "")).strip()
            zh = str(item.get("zh", "")).strip()
            sent_en = str(item.get("sentence_en", "")).strip()
            sent_zh = str(item.get("sentence_zh", "")).strip()
            if not word:
                continue

            # a) Standalone English word
            cb.add(comp_npc, "en", word, "spatial_word_en")
            if archetype_for_hint(room_host) != archetype_for_hint(comp_npc):
                cb.add(room_host, "en", word, "spatial_word_room_host_en")

            # b) Warm paused word + sentence_en, aliasing both "... " and ". "
            if sent_en:
                paused = f"{word}... {sent_en}"
                dotted = f"{word}. {sent_en}"
                cb.add(
                    comp_npc,
                    "en",
                    paused,
                    "spatial_word_sentence_en",
                    extra_raw_aliases=[dotted],
                )

            # c) Chinese explanation
            if zh and sent_zh:
                zh_exp = f"{word}，意思是{zh}。{sent_zh}"
                cb.add(comp_npc, "zh", zh_exp, "spatial_explanation_zh")

            # e) Bench errand prompts
            cb.add(comp_npc, "en", f"Can you find the {word} here?", "spatial_errand_prompt_en")
            cb.add(comp_npc, "en", f"Can you find the {word} for me?", "spatial_errand_prompt_en")


def harvest_cast_and_residents(cb: CorpusBuilder) -> None:
    cast_gd = ROOT / "game" / "gameplay" / "home_school_cast_director.gd"
    res_json = ROOT / "game" / "assets" / "characters" / "building_residents_v1" / "catalog.json"

    prox_greetings = parse_gd_const_dict(cast_gd, "PROXIMITY_GREETINGS")
    landmark_themes = parse_gd_const_dict(cast_gd, "LANDMARK_THEMES")
    actor_personas = parse_gd_const_dict(cast_gd, "ACTOR_PERSONAS")
    residents_catalog: dict[str, dict[str, Any]] = json.loads(
        res_json.read_text(encoding="utf-8")
    ).get("residents", {})

    # a) PROXIMITY_GREETINGS
    for scoped_key, pool in prox_greetings.items():
        speaker_id = scoped_key.split("@", 1)[0]
        for entry in pool:
            if entry.get("en"):
                cb.add(speaker_id, "en", str(entry["en"]), "cast_proximity_en")
            if entry.get("zh"):
                cb.add(speaker_id, "zh", str(entry["zh"]), "cast_proximity_zh")

    # b) ACTOR_PERSONAS + default fallback persona for mascots & generic hints
    for actor_id, persona in actor_personas.items():
        if persona.get("open_en"):
            cb.add(actor_id, "en", str(persona["open_en"]), "cast_persona_en")
        if persona.get("open_zh"):
            cb.add(actor_id, "zh", str(persona["open_zh"]), "cast_persona_zh")

    for hint in ("warm", "storyteller", "textbook_dino", "textbook_role_xiaoxiao_parrot", "npc_owl_tutor"):
        cb.add(
            hint,
            "en",
            "Hello, my friend! Let's explore the words around us and practise speaking together!",
            "cast_default_persona_en",
        )
        cb.add(
            hint,
            "zh",
            "你好呀好朋友！我们一起看看身边的物品，用英语自然聊聊天吧！",
            "cast_default_persona_zh",
        )
        cb.add(
            hint,
            "en",
            "Hello! What a sunny day to learn English together!",
            "cast_default_greeting_en",
        )
        cb.add(
            hint,
            "zh",
            "你好呀！今天阳光真好，一起在生活场景里感受英语吧！",
            "cast_default_greeting_zh",
        )

    # c) All 34 Building Residents: `resident_opening` + `pick_proximity_greeting` variants
    for resident_id, res in residents_catalog.items():
        name_en = str(res.get("name_en", "Friend"))
        name_zh = str(res.get("name", "伙伴"))
        role_zh = str(res.get("role", "主理人"))
        bname = str(res.get("building_name", "小屋"))

        if resident_id in prox_greetings and prox_greetings[resident_id]:
            first = prox_greetings[resident_id][0]
            open_en = f"Hi, I'm {name_en}! {first.get('en', '')}"
            open_zh = f"你好，我是{name_zh}（{role_zh}）！{first.get('zh', '')}"
            cb.add(resident_id, "en", open_en, "resident_opening_en")
            cb.add(resident_id, "zh", open_zh, "resident_opening_zh")
        elif resident_id in landmark_themes:
            lm = landmark_themes[resident_id]
            letter = resident_id[len("resident_") :].upper()
            word = str(lm.get("word", "star"))
            wzh = str(lm.get("zh", "星星"))
            spot = str(lm.get("spot", "studio"))
            open_en = f'Hi, I\'m {name_en} at the {spot}! Let\'s explore letter {letter} and "{word}" after school!'
            open_zh = f"你好呀，我是{bname}的{role_zh}{name_zh}！课余时间来这里认识字母 {letter} 与「{word}」（{wzh}）最有趣啦！"
            cb.add(resident_id, "en", open_en, "resident_opening_en")
            cb.add(resident_id, "zh", open_zh, "resident_opening_zh")
        else:
            open_en = f"Warm greetings from {name_en}! Take your time looking around {bname}!"
            open_zh = f"你好，我是{name_zh}，这里的{role_zh}。欢迎在{bname}慢慢探索！"
            cb.add(resident_id, "en", open_en, "resident_opening_en")
            cb.add(resident_id, "zh", open_zh, "resident_opening_zh")

        if resident_id in landmark_themes:
            lm = landmark_themes[resident_id]
            letter = resident_id[len("resident_") :].upper()
            word = str(lm.get("word", "apple"))
            wzh = str(lm.get("zh", "好物"))
            spot = str(lm.get("spot", "cozy corner"))
            word_cap = " ".join(part.capitalize() for part in word.split(" "))
            v0_en = f'Welcome to our {spot}! "{word_cap}" starts with {letter}!'
            v0_zh = f"欢迎来到{bname}！「{word}」（{wzh}）是以字母 {letter} 开头的好词哦！"
            v1_en = f'Hi! I\'m {name_en} — come spot "{word}" with me!'
            v1_zh = f"嗨！我是{name_zh}——快来{bname}和我一起发现「{word}」（{wzh}）吧！"
            cb.add(resident_id, "en", v0_en, "landmark_proximity_en")
            cb.add(resident_id, "zh", v0_zh, "landmark_proximity_zh")
            cb.add(resident_id, "en", v1_en, "landmark_proximity_en")
            cb.add(resident_id, "zh", v1_zh, "landmark_proximity_zh")


def harvest_situational_roleplay(cb: CorpusBuilder) -> None:
    rp_gd = ROOT / "game" / "gameplay" / "situational_roleplay.gd"
    v6_json = ROOT / "game" / "data" / "learning" / "home_school_dialogues_v6.json"

    # 1. V6 Home & School 4-stage scenarios (`home_school_dialogues_v6.json`)
    v6_data = json.loads(v6_json.read_text(encoding="utf-8")).get("scenarios", {})
    for _sid, raw in v6_data.items():
        npc_id = str(raw.get("npc_id", "textbook_role_lingling_mother"))
        stage_num = int(raw.get("stage", 1))
        grade_label = str(raw.get("grade_label", "三年级基础"))
        grammar_tag = str(raw.get("grammar_tag", ""))
        grammar_tip = str(raw.get("grammar_tip", "")).strip()
        turns: list[dict[str, Any]] = raw.get("turns", [])
        n_turns = len(turns)

        for t_idx, rt in enumerate(turns):
            npc_en = str(rt.get("npc_en", "")).strip()
            npc_zh = str(rt.get("npc_zh", "")).strip()
            if npc_en:
                cb.add(npc_id, "en", npc_en, "v6_roleplay_npc_en")
            if npc_zh:
                step_tag = f"第{stage_num}阶·{grade_label} ({t_idx + 1}/{n_turns})｜{grammar_tag}"
                ui_zh = f"【{step_tag}】\n{npc_zh}"
                ui_zh_with_tip = f"{ui_zh}\n· 语法小锦囊：{grammar_tip}" if (t_idx == 0 and grammar_tip) else ui_zh
                cb.add(
                    npc_id,
                    "zh",
                    npc_zh,
                    "v6_roleplay_npc_zh",
                    extra_raw_aliases=[ui_zh, ui_zh_with_tip],
                )

        fin_en = f"Awesome job! You just used Stage {stage_num} English naturally in real life!"
        fin_zh = f"太棒啦！你在真实场景对话里自然运用了【{grade_label} · {grammar_tag}】！"
        cb.add(npc_id, "en", fin_en, "v6_roleplay_finale_en")
        cb.add(npc_id, "zh", fin_zh, "v6_roleplay_finale_zh")

    # 2. Classic V5 situational scenarios (`SCENARIOS` in `situational_roleplay.gd`)
    v5_scenarios = parse_gd_const_dict(rp_gd, "SCENARIOS")
    for _sid, scen in v5_scenarios.items():
        npc_id = str(scen.get("npc_id", "npc_bear_uncle"))
        turns = scen.get("turns", [])
        n_turns = len(turns)
        for t_idx, td in enumerate(turns):
            en_txt = str(td.get("en", "")).strip()
            zh_txt = str(td.get("zh", "")).strip()
            if en_txt:
                cb.add(npc_id, "en", en_txt, "v5_roleplay_npc_en")
            if zh_txt:
                step_tag = f"情境对话第 {t_idx + 1} / {n_turns} 轮"
                ui_zh = f"【{step_tag}】\n{zh_txt}"
                cb.add(npc_id, "zh", zh_txt, "v5_roleplay_npc_zh", extra_raw_aliases=[ui_zh])

        if scen.get("finale_en"):
            cb.add(npc_id, "en", str(scen["finale_en"]), "v5_roleplay_finale_en")
        if scen.get("finale_zh"):
            cb.add(npc_id, "zh", str(scen["finale_zh"]), "v5_roleplay_finale_zh")


def harvest_bundled_and_core_fixed(cb: CorpusBuilder) -> None:
    # 1. BUNDLED_PHRASE_MAP phrases across main archetypes + mascots
    bundled_specs: list[tuple[str, list[str]]] = [
        ("Hello!", ["hello", "Hello."]),
        ("Good morning!", ["good morning", "Good morning."]),
        ("Goodbye!", ["goodbye", "Goodbye."]),
        ("Thank you!", ["thank you", "Thank you."]),
        ("apple", ["Apple", "apple."]),
        ("milk", ["Milk", "milk."]),
        ("bread", ["Bread", "bread."]),
        ("cake", ["Cake", "cake."]),
        ("How old are you?", ["how old are you"]),
        ("I'm nine.", ["i'm nine", "I'm nine!"]),
    ]
    for arch in BUNDLED_TARGET_ARCHETYPES:
        for spoken, aliases in bundled_specs:
            cb.add(arch, "en", spoken, "bundled_phrase_en", extra_raw_aliases=aliases)

    # 2. Core fixed interactions in `main.gd`, `morning_wake_mailbox.gd`, `household_activity.gd`, mascots
    fixed_lines: list[tuple[str, str, str]] = [
        ("storyteller", "en", "Good morning! Three memory palace letters are waiting in your mailbox!"),
        ("teacher_gentle", "en", "All clean and tidy! Great job!"),
        ("resident_football_field", "en", "Goal! Great shot!"),
        ("resident_football_field", "en", "Nice try! Kick again!"),
        ("resident_football_field", "en", "Five shots finished! Fantastic job!"),
        ("resident_football_field", "en", "Let's kick the football into the goal!"),
        ("textbook_dino", "en", "Hello! Let's count stars together!"),
        ("textbook_dino", "en", "Hello, friend! Let's count bright stars and read English words together!"),
        ("textbook_dino", "zh", "嗨好朋友！先听小恐龙欢快叫一声，再用奇幻小恐龙音陪你慢慢读英语吧！"),
        ("textbook_role_xiaoxiao_parrot", "en", "Hello! Nice sunny hat!"),
        ("textbook_role_xiaoxiao_parrot", "en", "Hello, friend! Repeat after me and let's speak English clearly!"),
        ("textbook_role_xiaoxiao_parrot", "zh", "你好呀好伙伴！跟着小鹦鹉一起响亮开口说英语吧！"),
        (
            "npc_rabbit_gardener",
            "en",
            "Hello! Sweet apples are ripe on the grass — pick one in your hands and bring it to my basket!",
        ),
        (
            "npc_rabbit_gardener",
            "zh",
            "你好呀！香甜的 3D 红苹果已经掉落在草地上了，走过去双手捧起来放进发光藤篮，或者接一个今日单元小委托吧！",
        ),
        (
            "textbook_miss_li",
            "en",
            "Good morning, class! Look at our blackboard, desks, and English books — ready to practise speaking together?",
        ),
        (
            "textbook_miss_li",
            "zh",
            "同学们早上好！在阳光教室里没有枯燥考卷：你可以和李老师演练 1～4 阶课本语法对话，或者走近课桌特写台把书本、铅笔、直尺全部串起来！",
        ),
        (
            "resident_canteen",
            "en",
            "Welcome to our sunny canteen! Pick up a clean lunch tray to learn roast chicken, sandwiches, juice, and milk!",
        ),
        (
            "resident_canteen",
            "zh",
            "欢迎来到校园阳光餐厅！可以打开点餐托盘特写台把美味食物摆上托盘，也可以和东东、玲玲练习礼貌点餐对话（I'd like..., please）！",
        ),
        (
            "textbook_peter",
            "en",
            "Hey friend! Look at Anne jumping rope and Dongdong running fast! Come check our sports box or play together!",
        ),
        (
            "textbook_peter",
            "zh",
            "嗨好搭档！快看同学们正在操场上跳绳和奔跑！一起来练「现在进行时与运动能力」课本对话，或者打开运动器材台认识球类和风筝吧！",
        ),
        (
            "textbook_role_lingling_mother",
            "en",
            "Good night, sweetie! Sleep tight in your cozy bed — Mom and Dad wish you sweet dreams!",
        ),
        (
            "textbook_role_lingling_mother",
            "zh",
            "晚安呀宝贝！在温暖的小床上安心睡一觉吧，所有家庭装扮、叶币和成长足迹都会稳稳保存。",
        ),
        (
            "npc_bear_uncle",
            "en",
            "Good morning! Welcome to Alphabet Island! Would you like to help me bake an apple cake today?",
        ),
        (
            "npc_bear_uncle",
            "zh",
            "早上好！欢迎搬来晨光村！今天愿意帮熊叔一起烤一份香喷喷的苹果蛋糕吗？",
        ),
    ]
    for hint, lg, txt in fixed_lines:
        cb.add(hint, lg, txt, "core_fixed_dialogue")


def main() -> None:
    missing_arch = [a for a in ALL_13_ARCHETYPES if a not in VOICE_ARCHETYPES]
    if missing_arch:
        raise RuntimeError(f"Missing archetypes in voice_profiles.py: {missing_arch}")

    cb = CorpusBuilder()
    harvest_spatial_clusters(cb)
    harvest_cast_and_residents(cb)
    harvest_situational_roleplay(cb)
    harvest_bundled_and_core_fixed(cb)

    sorted_items = sorted(
        cb.items.values(),
        key=lambda x: (x["archetype"], x["lang"], len(x["text"]), x["clip_id"]),
    )

    by_arch_lang: dict[str, int] = defaultdict(int)
    for it in sorted_items:
        by_arch_lang[f"{it['archetype']}|{it['lang']}"] += 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": 10,
        "archetypes": list(ALL_13_ARCHETYPES),
        "unique_clip_count": len(sorted_items),
        "total_alias_key_count": len(cb.key_owner),
        "counts_by_archetype_lang": dict(sorted(by_arch_lang.items())),
        "counts_by_source": dict(sorted(cb.source_counts.items())),
        "items": sorted_items,
    }
    CORPUS_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"[extract_voice_corpus_v10] Wrote {CORPUS_PATH}")
    print(f"  Unique utterances to synthesize : {len(sorted_items)}")
    print(f"  Total manifest alias keys       : {len(cb.key_owner)}")
    print("  Breakdown by source:")
    for src, cnt in sorted(cb.source_counts.items()):
        print(f"    - {src}: {cnt}")
    print("  Breakdown by archetype|lang:")
    for k, cnt in sorted(by_arch_lang.items()):
        print(f"    - {k}: {cnt}")


if __name__ == "__main__":
    main()
