"""Unit & integration tests for the StudyGames V4 AI Safe Companion Sidecar."""
from __future__ import annotations

import asyncio
import base64

import httpx

from services.ai_companion.app import app
from services.ai_companion.guardrails import check_child_input, sanitize_npc_output
from services.ai_companion.npc_companion import NPC_PERSONAS, _offline_cozy_reply, generate_npc_reply
from services.ai_companion.speech_service import reset_cloud_backoff, synthesize_speech
from services.ai_companion.stealth_mastery import build_parent_weekly_report, update_irt_mastery
from services.ai_companion.voice_profiles import CHARACTER_VOICE_MAP, VOICE_ARCHETYPES, resolve_voice_profile


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


def test_building_residents_keep_their_own_chat_identity() -> None:
    residents = {key: value for key, value in NPC_PERSONAS.items() if key.startswith("resident_")}
    assert len(residents) == 34
    assert len({row["name_zh"] for row in residents.values()}) == 34
    for npc_id, persona in residents.items():
        reply = _offline_cozy_reply(npc_id, "Hello!", {"target_word": "apple"})
        assert reply["npc_id"] == npc_id
        assert reply["speaker_zh"] == persona["name_zh"]
        assert persona["name_en"] in reply["reply_en"]
    assert NPC_PERSONAS["npc_bear_uncle"]["name_zh"] == "熊叔"


def test_speech_service_synthesizes_and_caches_wav() -> None:
    reset_cloud_backoff()
    phrase = "Good morning from Alphabet Island V5 voice test!"
    res = asyncio.run(synthesize_speech(phrase, lang="en", voice_hint="textbook_miss_li"))
    assert res["ok"] is True
    assert res["engine"] in {"edge_neural_tts", "cloud_neural_tts", "cloud_disk_cache", "piper_neural_onnx", "neural_disk_cache"}
    assert res["voice_profile"] == "teacher_gentle"
    assert len(res["wav_base64"]) > 100
    raw = base64.b64decode(res["wav_base64"])
    assert raw[:4] == b"RIFF"
    assert raw[8:12] == b"WAVE"

    second = asyncio.run(synthesize_speech(phrase, lang="en", voice_hint="textbook_miss_li"))
    assert second["ok"] is True
    assert second["cached"] is True

    zh_res = asyncio.run(synthesize_speech("早上好，欢迎来到字母岛！", lang="zh", voice_hint="npc_bear_uncle"))
    assert zh_res["ok"] is True
    assert zh_res["engine"] in {"edge_neural_tts", "cloud_neural_tts", "cloud_disk_cache", "piper_neural_onnx", "neural_disk_cache"}
    assert zh_res["voice_profile"] == "uncle_warm"
    assert len(zh_res["wav_base64"]) > 100


def test_multi_character_cloud_and_offline_timbres_are_distinct() -> None:
    assert len(VOICE_ARCHETYPES) >= 10
    # Verify all 34 building & campus residents map cleanly in CHARACTER_VOICE_MAP
    resident_keys = [k for k in NPC_PERSONAS if k.startswith("resident_")]
    assert len(resident_keys) == 34
    for rkey in resident_keys:
        assert rkey in CHARACTER_VOICE_MAP, f"Missing resident voice mapping for {rkey}"

    cast = [
        ("npc_bear_uncle", "uncle_warm"),
        ("textbook_miss_li", "teacher_gentle"),
        ("textbook_lingling", "girl_bright"),
        ("textbook_peter", "boy_sunny"),
        ("textbook_dino", "mascot_dino"),
        ("npc_owl_tutor", "elder_wise"),
        ("storyteller", "storyteller"),
    ]
    for npc_id, expected_arch in cast:
        spec = resolve_voice_profile(npc_id)
        assert spec["profile_id"] == expected_arch

    # 1. Offline multi-model Piper synthesis produces distinct models & waveforms across cast (EN & ZH)
    en_line = "Hello friend, welcome to Alphabet Island!"
    zh_line = "你好呀小伙伴，欢迎来到温暖的字母岛！"

    bear_en_off = asyncio.run(synthesize_speech(en_line, lang="en", voice_hint="npc_bear_uncle", prefer_offline=True))
    girl_en_off = asyncio.run(synthesize_speech(en_line, lang="en", voice_hint="textbook_lingling", prefer_offline=True))
    boy_en_off = asyncio.run(synthesize_speech(en_line, lang="en", voice_hint="textbook_peter", prefer_offline=True))
    owl_en_off = asyncio.run(synthesize_speech(en_line, lang="en", voice_hint="npc_owl_tutor", prefer_offline=True))

    for item in (bear_en_off, girl_en_off, boy_en_off, owl_en_off):
        assert item["ok"] is True
        assert item["engine"] in {"piper_neural_onnx", "neural_disk_cache"}

    assert bear_en_off["wav_base64"] != girl_en_off["wav_base64"]
    assert girl_en_off["wav_base64"] != boy_en_off["wav_base64"]
    assert bear_en_off["wav_base64"] != owl_en_off["wav_base64"]

    bear_zh_off = asyncio.run(synthesize_speech(zh_line, lang="zh", voice_hint="npc_bear_uncle", prefer_offline=True))
    girl_zh_off = asyncio.run(synthesize_speech(zh_line, lang="zh", voice_hint="textbook_lingling", prefer_offline=True))
    teacher_zh_off = asyncio.run(synthesize_speech(zh_line, lang="zh", voice_hint="textbook_miss_li", prefer_offline=True))

    for item in (bear_zh_off, girl_zh_off, teacher_zh_off):
        assert item["ok"] is True
        assert item["engine"] in {"piper_neural_onnx", "neural_disk_cache"}

    assert bear_zh_off["wav_base64"] != girl_zh_off["wav_base64"]
    assert bear_zh_off["wav_base64"] != teacher_zh_off["wav_base64"]
    assert girl_zh_off["wav_base64"] != teacher_zh_off["wav_base64"]

    # 2. Cloud hyper-realistic synthesis produces distinct character voices when online
    reset_cloud_backoff()
    bear_zh_cloud = asyncio.run(synthesize_speech("早上好，快来尝尝热苹果蛋糕！", lang="zh", voice_hint="npc_bear_uncle"))
    boy_zh_cloud = asyncio.run(synthesize_speech("早上好，快来尝尝热苹果蛋糕！", lang="zh", voice_hint="textbook_peter"))
    girl_zh_cloud = asyncio.run(synthesize_speech("早上好，快来尝尝热苹果蛋糕！", lang="zh", voice_hint="textbook_lingling"))
    assert bear_zh_cloud["ok"] and boy_zh_cloud["ok"] and girl_zh_cloud["ok"]
    assert bear_zh_cloud["wav_base64"] != boy_zh_cloud["wav_base64"]
    assert boy_zh_cloud["wav_base64"] != girl_zh_cloud["wav_base64"]


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

            enc_voice = await client.post(
                "/api/v4/speech/encourage",
                json={"target_text": "Good morning!", "mode": "voice", "rms_energy": 0.045, "duration_ms": 950},
            )
            assert enc_voice.status_code == 200
            assert enc_voice.json()["ok"] is True
            assert enc_voice.json()["voice_detected"] is True
            assert "Good morning!" in enc_voice.json()["reply_en"]

            enc_shy = await client.post(
                "/api/v4/speech/encourage",
                json={"target_text": "Good morning!", "mode": "shy"},
            )
            assert enc_shy.status_code == 200
            assert enc_shy.json()["ok"] is True
            assert enc_shy.json()["mode"] == "shy"

            # Real offline Vosk ASR roundtrip: feed Piper WAV for "good morning" & mismatch check
            gm_tts = await synthesize_speech("good morning", lang="en", voice_hint="warm")
            asr_exact = await client.post(
                "/api/v4/speech/encourage",
                json={
                    "target_text": "good morning",
                    "mode": "voice",
                    "rms_energy": 0.08,
                    "duration_ms": 1100,
                    "wav_base64": gm_tts["wav_base64"],
                },
            )
            assert asr_exact.status_code == 200
            exact_body = asr_exact.json()
            assert exact_body["ok"] is True
            assert exact_body["asr_engine"] == "vosk_offline_asr"
            assert "morning" in exact_body["transcript"]
            assert exact_body["match_tier"] in {"exact", "close"}

            asr_gentle = await client.post(
                "/api/v4/speech/encourage",
                json={
                    "target_text": "watermelon",
                    "mode": "voice",
                    "rms_energy": 0.08,
                    "duration_ms": 1100,
                    "wav_base64": gm_tts["wav_base64"],
                },
            )
            assert asr_gentle.status_code == 200
            gentle_body = asr_gentle.json()
            assert gentle_body["ok"] is True
            assert gentle_body["asr_engine"] == "vosk_offline_asr"
            assert gentle_body["match_tier"] == "gentle_model"

    asyncio.run(_exercise())
