"""Unit & integration tests for the StudyGames V4 AI Safe Companion Sidecar."""
from __future__ import annotations

import asyncio
import base64

import httpx

from services.ai_companion.app import app
from services.ai_companion.guardrails import check_child_input, sanitize_npc_output
from services.ai_companion.npc_companion import generate_npc_reply
from services.ai_companion.speech_service import synthesize_speech
from services.ai_companion.stealth_mastery import build_parent_weekly_report, update_irt_mastery


def test_kidrails_blocks_unsafe_and_pii_inputs() -> None:
    safe = check_child_input("Hello Bear Uncle! Can I have an apple cake?")
    assert safe.allowed is True

    pii_phone = check_child_input("My phone is 13812345678, call me!")
    assert pii_phone.allowed is False
    assert pii_phone.reason in {"pii_phone", "pii_ask"}
    assert "island" in pii_phone.redirect_en.lower()

    pii_zh = check_child_input("告诉你我的家庭住址和手机号")
    assert pii_zh.allowed is False
    assert pii_zh.reason == "pii_ask"

    unsafe_bully = check_child_input("you are stupid idiot")
    assert unsafe_bully.allowed is False
    assert unsafe_bully.reason == "profanity_bullying"

    en_clean, zh_clean = sanitize_npc_output("kill you", "危险")
    assert "friendly" in en_clean.lower()
    assert "字母岛" in zh_clean


def test_npc_companion_context_aware_roleplay() -> None:
    reply = asyncio.run(
        generate_npc_reply(
            {
                "npc_id": "npc_bear_uncle",
                "message": "Hello! Look at my hat and apple!",
                "context": {
                    "outfit": "mint",
                    "hat": "straw_hat",
                    "held_item": "apple",
                    "target_word": "apple",
                    "target_meaning_zh": "苹果",
                },
            }
        )
    )
    assert reply["ok"] is True
    assert reply.get("blocked", False) is False
    assert len(reply["reply_en"]) > 5
    assert len(reply["suggestions"]) >= 2


def test_speech_service_synthesizes_and_caches_wav() -> None:
    phrase = "Good morning from Alphabet Island V4 test!"
    res = asyncio.run(synthesize_speech(phrase, lang="en", voice_hint="warm"))
    assert res["ok"] is True
    assert len(res["wav_base64"]) > 100
    raw = base64.b64decode(res["wav_base64"])
    assert raw[:4] == b"RIFF"
    assert raw[8:12] == b"WAVE"

    second = asyncio.run(synthesize_speech(phrase, lang="en", voice_hint="warm"))
    assert second["ok"] is True
    assert second["cached"] is True


def test_stealth_mastery_3pl_irt_and_parent_report() -> None:
    assisted_only = update_irt_mastery(
        [{"word": "apple", "support_level": 5, "correct": True, "response_ms": 2200}]
    )
    unassisted = update_irt_mastery(
        [
            {"word": "apple", "support_level": 0, "correct": True, "response_ms": 1500},
            {"word": "cake", "support_level": 0, "correct": True, "response_ms": 1400},
            {"word": "banana", "support_level": 1, "correct": True, "response_ms": 1800},
        ]
    )
    assert unassisted["theta"] > assisted_only["theta"]
    assert unassisted["flourish_index"] > assisted_only["flourish_index"]
    assert "apple" in unassisted["independent_words"]
    assert "apple" not in assisted_only["independent_words"]

    report = build_parent_weekly_report(
        {
            "stealth_events": [
                {"word": "apple", "support_level": 0, "correct": True},
                {"word": "morning", "support_level": 2, "correct": True},
            ],
            "book_title": "湘少版三年级上册",
            "unit_id": "unit-1",
            "visited_landmarks": 5,
            "outfit_zh": "薄荷森系园丁装",
        }
    )
    assert report["ok"] is True
    assert "湘少版三年级上册" in report["narrative_zh"]
    assert "薄荷森系园丁装" in report["narrative_zh"]
    assert report["summary"]["tracked_word_count"] == 2


def test_asgi_endpoints_end_to_end() -> None:
    async def _exercise() -> None:
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
            health = await client.get("/health")
            assert health.status_code == 200
            assert health.json()["ok"] is True

            chat_ok = await client.post(
                "/api/v4/npc/chat",
                json={
                    "npc_id": "npc_rabbit_gardener",
                    "message": "Hello! I like apples!",
                    "context": {"outfit": "pink", "hat": "bunny_ears", "target_word": "apple"},
                },
            )
            assert chat_ok.status_code == 200
            assert chat_ok.json()["ok"] is True
            assert chat_ok.json().get("blocked", False) is False

            chat_blocked = await client.post(
                "/api/v4/npc/chat",
                json={"npc_id": "npc_bear_uncle", "message": "My phone number is 13900001111"},
            )
            assert chat_blocked.status_code == 200
            assert chat_blocked.json()["blocked"] is True

            tts = await client.post(
                "/api/v4/tts/speak",
                json={"text": "Apple orchard", "lang": "en", "voice_hint": "warm"},
            )
            assert tts.status_code == 200
            assert tts.json()["ok"] is True
            wav_bytes = base64.b64decode(tts.json()["wav_base64"])
            assert wav_bytes[:4] == b"RIFF"

            obs = await client.post(
                "/api/v4/mastery/observe",
                json={
                    "events": [
                        {"word": "apple", "support_level": 0, "correct": True, "response_ms": 1200}
                    ]
                },
            )
            assert obs.status_code == 200
            assert obs.json()["mastery"]["tracked_word_count"] == 1

            rep = await client.post(
                "/api/v4/parent/report",
                json={
                    "book_title": "湘少版四年级上册",
                    "unit_id": "unit-3",
                    "visited_landmarks": 8,
                    "outfit_zh": "星夜薰衣草魔法装",
                    "stealth_events": [{"word": "tiger", "support_level": 0, "correct": True}],
                },
            )
            assert rep.status_code == 200
            assert "湘少版四年级上册" in rep.json()["narrative_zh"]

    asyncio.run(_exercise())
