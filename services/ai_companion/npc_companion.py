"""Controlled-vocabulary (i+1) Cozy NPC Companion Engine.

Supports pluggable cloud LLM gateways (DashScope Qwen / OpenAI / Gemini via httpx)
and an expressive, zero-key Offline Cozy Roleplay Engine aware of the player's
outfit, headwear, held item, weather, room, and active textbook unit words!
"""
from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Any

import httpx

from .guardrails import check_child_input, sanitize_npc_output

NPC_PERSONAS: dict[str, dict[str, str]] = {
    "npc_bear_uncle": {
        "name_zh": "熊叔",
        "name_en": "Uncle Bear",
        "role": "warm village baker who loves baking sweet apple cakes and greeting neighbors",
        "catchphrase": "Smells like warm apple cake!",
    },
    "npc_rabbit_gardener": {
        "name_zh": "兔兔园丁",
        "name_en": "Bunny Gardener",
        "role": "cheerful orchard gardener tending red and golden apples under sunny trees",
        "catchphrase": "Look at these shiny red apples!",
    },
    "textbook_lingling": {
        "name_zh": "玲玲",
        "name_en": "Lingling",
        "role": "friendly primary school classmate who loves drawing stars and welcoming friends",
        "catchphrase": "Hello! Nice to meet you!",
    },
    "textbook_peter": {
        "name_zh": "彼得",
        "name_en": "Peter",
        "role": "helpful classmate who enjoys football, travel books, and exploring landmarks",
        "catchphrase": "Let's explore together!",
    },
    "textbook_anne": {
        "name_zh": "安妮",
        "name_en": "Anne",
        "role": "gentle classmate who loves ribbons, music, and sharing picnic snacks",
        "catchphrase": "What a lovely outfit!",
    },
    "textbook_miss_li": {
        "name_zh": "李老师",
        "name_en": "Miss Li",
        "role": "encouraging storybook teacher who turns every English word into a playful adventure",
        "catchphrase": "You are doing wonderful!",
    },
}

# Read the same authored identities as the game; retain the established cast.
_RESIDENT_CATALOG = Path(__file__).resolve().parents[2] / "game/assets/characters/building_residents_v1/catalog.json"
if _RESIDENT_CATALOG.is_file():
    _residents = json.loads(_RESIDENT_CATALOG.read_text(encoding="utf-8"))
    for _resident_id, _resident in _residents.get("residents", {}).items():
        NPC_PERSONAS[_resident_id] = {
            "name_zh": _resident["name"],
            "name_en": _resident["name_en"],
            "role": f"friendly {_resident['role']} who welcomes visitors to {_resident['building_name']}",
            "catchphrase": f"I'm {_resident['name_en']}. Let's explore together!",
        }

OUTFIT_COMPLIMENTS: dict[str, tuple[str, str]] = {
    "yellow": ("your sunny yellow outfit", "向日葵黄背带装"),
    "pink": ("your sweet pink outfit", "蜜桃粉套装"),
    "blue": ("your sky blue outfit", "晴空蓝水手装"),
    "mint": ("your fresh green garden outfit", "薄荷绿园艺装"),
    "lavender": ("your dreamy purple star outfit", "薰衣草礼服"),
    "caramel": ("your cozy brown bakery outfit", "焦糖烘焙装"),
}

HAT_COMPLIMENTS: dict[str, tuple[str, str]] = {
    "straw_hat": ("that cute straw hat", "田园草帽"),
    "ribbon_bow": ("that pretty pink ribbon", "蜜桃蝴蝶结"),
    "star_beret": ("that starry beret", "摘星贝雷帽"),
    "bunny_ears": ("those fluffy rabbit ears", "暖绒兔耳发箍"),
}


async def generate_npc_reply(payload: dict[str, Any]) -> dict[str, Any]:
    npc_id = str(payload.get("npc_id") or "npc_bear_uncle")
    player_text = str(payload.get("message") or "")
    context = payload.get("context") if isinstance(payload.get("context"), dict) else {}

    guard = check_child_input(player_text)
    if not guard.allowed:
        return {
            "ok": True,
            "blocked": True,
            "reason": guard.reason,
            "npc_id": npc_id,
            "reply_en": guard.redirect_en,
            "reply_zh": guard.redirect_zh,
            "suggestions": ["Hello!", "Good morning!", "Look at my hat!"],
            "engine": "kidrails_guard",
        }

    # Try cloud LLM if configured; seamlessly fall back to deterministic cozy engine
    cloud = await _try_cloud_llm(npc_id, guard.sanitized_text, context)
    if cloud is not None:
        return cloud

    return _offline_cozy_reply(npc_id, guard.sanitized_text, context)


async def _try_cloud_llm(npc_id: str, player_text: str, context: dict[str, Any]) -> dict[str, Any] | None:
    api_key = os.environ.get("DASHSCOPE_API_KEY") or os.environ.get("OPENAI_API_KEY")
    if not api_key:
        return None
    base_url = os.environ.get(
        "AI_COMPANION_BASE_URL",
        "https://dashscope.aliyuncs.com/compatible-mode/v1" if os.environ.get("DASHSCOPE_API_KEY") else "https://api.openai.com/v1",
    )
    model = os.environ.get("AI_COMPANION_MODEL", "qwen-plus" if os.environ.get("DASHSCOPE_API_KEY") else "gpt-4o-mini")
    persona = NPC_PERSONAS.get(npc_id, NPC_PERSONAS["npc_bear_uncle"])
    unit_words = context.get("unit_words") or ["hello", "apple", "good morning", "thank you", "friend"]
    system_prompt = (
        f"You are {persona['name_en']} ({persona['name_zh']}), a {persona['role']} on Alphabet Island "
        "for children aged 7-12. Speak in 1-2 short, warm A1 English sentences using simple primary-school words "
        f"(especially {', '.join(str(w) for w in unit_words[:8])}). Never test or grade the child; gently recast "
        "their idea in natural English. Return strict JSON: "
        '{"reply_en":"...","reply_zh":"...","suggestions":["...","...","..."]}.'
    )
    try:
        async with httpx.AsyncClient(timeout=4.5) as client:
            resp = await client.post(
                f"{base_url.rstrip('/')}/chat/completions",
                headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
                json={
                    "model": model,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": f"Context: {json.dumps(context, ensure_ascii=False)}\nChild says: {player_text}"},
                    ],
                    "temperature": 0.6,
                    "max_tokens": 180,
                },
            )
            resp.raise_for_status()
            raw_content = resp.json()["choices"][0]["message"]["content"]
            match = re.search(r"\{.*\}", raw_content, re.S)
            parsed = json.loads(match.group(0) if match else raw_content)
            en, zh = sanitize_npc_output(str(parsed.get("reply_en", "")), str(parsed.get("reply_zh", "")))
            sugs = [str(s)[:36] for s in (parsed.get("suggestions") or [])[:3] if str(s).strip()]
            return {
                "ok": True,
                "blocked": False,
                "npc_id": npc_id,
                "reply_en": en,
                "reply_zh": zh,
                "suggestions": sugs or ["Thank you!", "Let's play!", "See you!"],
                "engine": f"cloud:{model}",
            }
    except Exception:
        return None


def _offline_cozy_reply(npc_id: str, text: str, context: dict[str, Any]) -> dict[str, Any]:
    persona = NPC_PERSONAS.get(npc_id, NPC_PERSONAS["npc_bear_uncle"])
    lower = text.lower()
    outfit = str(context.get("outfit") or "yellow")
    hat = str(context.get("hat") or "none")
    held = str(context.get("held_item") or "")
    target_word = str(context.get("target_word") or "apple")
    target_zh = str(context.get("target_meaning_zh") or "红苹果")

    outfit_en, outfit_zh = OUTFIT_COMPLIMENTS.get(outfit, OUTFIT_COMPLIMENTS["yellow"])
    hat_en, hat_zh = HAT_COMPLIMENTS.get(hat, ("", ""))

    if any(k in lower for k in ("hat", "dress", "outfit", "look", "wear", "帽", "衣", "裙", "好看", "穿搭")):
        if hat_en:
            en = f"Wow, I love {outfit_en} and {hat_en}! You look like a storybook star!"
            zh = f"哇，我好喜欢你的{outfit_zh}和{hat_zh}！看起来就像童话书里的小明星！"
        else:
            en = f"Oh! {outfit_en.capitalize()} looks so bright and cozy today!"
            zh = f"哇！你今天穿的{outfit_zh}既明亮又暖和！"
        sugs = ["Thank you!", "Do you like apples?", "Let's play together!"]

    elif any(k in lower for k in ("apple", "fruit", "cake", "pie", "hungry", "eat", "苹果", "蛋糕", "饿", "果园")):
        if held:
            en = f"Ooh, you are carrying a sweet {held.replace('_', ' ')}! Let's put it in the basket!"
            zh = "哇，你手里正捧着香甜的果实呢！快把它放进藤编果篮里吧！"
        else:
            en = "Fresh red apples make the best warm cake! Would you like to pick three apples with me?"
            zh = "新鲜的红苹果能烤出最香甜的蛋糕！要和我一起摘三颗苹果吗？"
        sugs = ["Yes, three red apples!", "I love apple cake!", "Thank you!"]

    elif any(k in lower for k in ("morning", "hello", "hi", "hey", "你好", "早安", "早上好", "嗨")):
        if hat_en:
            en = f"Hello, my friend! Good morning! I really like {hat_en}!"
            zh = f"你好呀好朋友！早上好！你的{hat_zh}真好看！"
        else:
            en = f"Hello! Good morning! {persona['catchphrase']} Today's fun word is \"{target_word}\"!"
            zh = f"你好呀！早上好！今天我们的趣味伙伴词是「{target_word}」（{target_zh}）哦！"
        sugs = ["Good morning!", f"Tell me about {target_word}!", "Look at my outfit!"]

    elif any(k in lower for k in ("thank", "thanks", "谢谢")):
        en = "You are very welcome, little explorer! My door is always open for you."
        zh = "不客气呀，小探险家！随时欢迎你来找我玩。"
        sugs = ["Goodbye!", "What can we do today?", "Look at my hat!"]

    elif any(k in lower for k in ("bye", "see you", "再见", "拜拜")):
        en = "Goodbye! Have a sunny walk around Alphabet Island!"
        zh = "再见啦！祝你在字母岛上散步开心！"
        sugs = ["See you tomorrow!", "Hello again!"]

    else:
        # Gentle bilingual i+1 recast!
        en = f"That sounds wonderful! On our island, we love saying \"{target_word}\" while wearing {outfit_en}!"
        zh = f"听起来真棒呀！在小岛上，大家穿着{outfit_zh}的时候，最喜欢一起分享「{target_word}」（{target_zh}）啦！"
        sugs = [f"I know {target_word}!", "Let's open the pop-up book!", "Thank you!"]

    clean_en, clean_zh = sanitize_npc_output(en, zh)
    return {
        "ok": True,
        "blocked": False,
        "npc_id": npc_id,
        "speaker_zh": persona["name_zh"],
        "reply_en": clean_en,
        "reply_zh": clean_zh,
        "suggestions": sugs,
        "engine": "cozy_i_plus_1_local",
    }
