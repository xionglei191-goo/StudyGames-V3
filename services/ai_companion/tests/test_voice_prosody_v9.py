"""V9 Multi-Character Voice Prosody, Animal Storyteller Routing & Speed-Mode Tests."""
from __future__ import annotations

import asyncio
import base64
import io
import subprocess
import wave

import edge_tts
import httpx

from services.ai_companion import speech_service as speech
from services.ai_companion.app import TTSRequest, app
from services.ai_companion.voice_profiles import (
    CHARACTER_VOICE_MAP,
    PURE_ANIMAL_KEYS,
    TALKING_MASCOT_KEYS,
    VOICE_ARCHETYPES,
    resolve_voice_profile,
    strip_animal_interjection,
)


def _wav_duration_seconds(raw_wav: bytes) -> float:
    with wave.open(io.BytesIO(raw_wav), "rb") as rf:
        return rf.getnframes() / float(rf.getframerate())


def test_v9_archetypes_character_mappings_and_slower_defaults() -> None:
    expected_labels = {
        "mother_affectionate": "温柔妈妈音",
        "father_warm": "暖心爸爸音",
        "teacher_gentle": "亲切女老师音",
        "storyteller": "绘本姐姐音",
        "boy_sunny": "阳光小男孩音",
        "girl_bright": "元气小女孩音",
        "mascot_dino": "奇幻小恐龙音",
        "mascot_parrot": "俏皮小鹦鹉音",
        "uncle_warm": "暖厚大叔音",
        "elder_wise": "慈祥智者音",
        "grandma_warm": "慈爱长辈女音",
        "artisan_male": "阳光男匠人音",
        "artisan_female": "明快女达人音",
    }
    for arch_id, label_zh in expected_labels.items():
        assert arch_id in VOICE_ARCHETYPES
        spec = VOICE_ARCHETYPES[arch_id]
        assert spec["label_zh"] == label_zh
        assert -20 <= int(spec["rate_pct"]) <= -11, f"{arch_id} rate_pct not slowed: {spec['rate_pct']}"
        assert 1.14 <= float(spec["piper_pace"]) <= 1.30, f"{arch_id} piper_pace not slowed: {spec['piper_pace']}"

    # Boy vs Girl bug fix: boy_sunny must NOT share en-US-AnaNeural with girl_bright
    assert VOICE_ARCHETYPES["boy_sunny"]["edge_en"] != VOICE_ARCHETYPES["girl_bright"]["edge_en"]
    assert VOICE_ARCHETYPES["boy_sunny"]["edge_en"] != "en-US-AnaNeural"
    assert VOICE_ARCHETYPES["girl_bright"]["edge_en"] == "en-US-AnaNeural"

    # Dedicated family, teacher & mascot mappings
    assert resolve_voice_profile("textbook_role_lingling_mother")["profile_id"] == "mother_affectionate"
    assert resolve_voice_profile("textbook_role_lingling_father")["profile_id"] == "father_warm"
    assert resolve_voice_profile("textbook_miss_li")["profile_id"] == "teacher_gentle"
    assert resolve_voice_profile("textbook_miss_lin")["profile_id"] == "teacher_gentle"
    assert resolve_voice_profile("warm")["profile_id"] == "teacher_gentle"
    assert resolve_voice_profile("textbook_dino")["profile_id"] == "mascot_dino"
    assert resolve_voice_profile("textbook_role_xiaoxiao_parrot")["profile_id"] == "mascot_parrot"

    # Pure animals vs talking mascots
    assert PURE_ANIMAL_KEYS == frozenset(
        {
            "textbook_kitty",
            "textbook_doggie",
            "textbook_spot",
            "textbook_bunny",
            "textbook_baker_bird",
            "textbook_elephant_ella",
            "textbook_fendi",
        }
    )
    assert TALKING_MASCOT_KEYS == frozenset({"textbook_dino", "textbook_role_xiaoxiao_parrot"})
    for animal_key in PURE_ANIMAL_KEYS:
        assert CHARACTER_VOICE_MAP[animal_key] == ("storyteller", -1, 1)
        prof = resolve_voice_profile(animal_key)
        assert prof["profile_id"] == "storyteller"
        assert prof["label_zh"] == "绘本姐姐音"


def test_all_edge_voice_names_are_valid_in_edge_tts_catalog() -> None:
    voices = asyncio.run(edge_tts.list_voices())
    valid_short_names = {v["ShortName"] for v in voices}
    for arch_id, spec in VOICE_ARCHETYPES.items():
        assert spec["edge_en"] in valid_short_names, f"Invalid edge_en on {arch_id}: {spec['edge_en']}"
        assert spec["edge_zh"] in valid_short_names, f"Invalid edge_zh on {arch_id}: {spec['edge_zh']}"


def test_strip_animal_interjection_and_child_friendly_breathing_text() -> None:
    cases = [
        ("Meow! Kitty is resting on the soft warm sofa!", "Kitty is resting on the soft warm sofa!"),
        ("Meow~ Little Kitty loves milk.", "Little Kitty loves milk."),
        ("Woof woof! Look, Doggie loves running!", "Look, Doggie loves running!"),
        ("Woof, woof! Doggie brings you to the garden!", "Doggie brings you to the garden!"),
        ("Woof! Let's run on the green grass!", "Let's run on the green grass!"),
        ("Tweet! Little bird sings in the tree.", "Little bird sings in the tree."),
        ("Chirp! Bunny hops beside the flowers.", "Bunny hops beside the flowers."),
        ("喵呜～小猫正窝在柔软温暖的沙发上休息呢！", "小猫正窝在柔软温暖的沙发上休息呢！"),
        ("喵～快来摸摸小猫吧！", "快来摸摸小猫吧！"),
        ("汪汪！快看，小狗最喜欢在阳光花园里奔跑啦！", "快看，小狗最喜欢在阳光花园里奔跑啦！"),
        ("啾啾！小鸟在枝头唱歌！", "小鸟在枝头唱歌！"),
    ]
    for raw, expected in cases:
        assert strip_animal_interjection(raw) == expected

    # Non-interjection sentences remain intact
    assert strip_animal_interjection("Chirping birds sing happily.") == "Chirping birds sing happily."

    # prepare_child_friendly_text: strips animal cry ONLY for PURE_ANIMAL_KEYS + adds vocab pause
    assert (
        speech.prepare_child_friendly_text("Woof woof! Look at Doggie!", "en", "textbook_doggie")
        == "Look at Doggie!"
    )
    assert (
        speech.prepare_child_friendly_text("pen. A blue pen is on the desk.", "en", "textbook_miss_li")
        == "pen... A blue pen is on the desk."
    )
    assert (
        speech.prepare_child_friendly_text("pen... A blue pen is on the desk.", "en", "textbook_miss_li")
        == "pen... A blue pen is on the desk."
    )
    assert (
        speech.prepare_child_friendly_text("Mr. Wang is a kind teacher.", "en", "textbook_mr_wang")
        == "Mr. Wang is a kind teacher."
    )
    assert (
        speech.prepare_child_friendly_text("苹果。红彤彤的大苹果。", "zh", "textbook_miss_li")
        == "苹果…… 红彤彤的大苹果。"
    )


def test_v90_cache_key_speed_mode_sapi_rate_and_cloud_budget(monkeypatch, tmp_path) -> None:
    monkeypatch.setattr(speech, "CACHE_DIR", tmp_path)
    assert speech.CLOUD_ATTEMPT_BUDGET_SECONDS == 6.5
    assert speech.CLOUD_FAIL_BACKOFF_THRESHOLD == 3

    p_nat = speech._cache_path("apple", "en", "warm", "cloud", "natural")
    p_slow = speech._cache_path("apple", "en", "warm", "cloud", "slow")
    assert p_nat.name.startswith("tts_v90_cloud_natural_en_warm_")
    assert p_slow.name.startswith("tts_v90_cloud_slow_en_warm_")
    assert p_nat != p_slow

    # Edge rate clamping & Piper pace scaling in slow mode
    base = resolve_voice_profile("warm")
    slow_prof = speech._apply_speed_mode(base, "slow")
    assert slow_prof["speed_mode"] == "slow"
    assert slow_prof["rate_pct"] == max(-35, min(10, base["rate_pct"] - 14))
    assert abs(slow_prof["piper_pace"] - min(1.55, base["piper_pace"] * 1.22)) < 1e-3

    extreme = {"rate_pct": -28, "piper_pace": 1.40}
    clamped = speech._apply_speed_mode(extreme, "slow")
    assert clamped["rate_pct"] == -35
    assert clamped["piper_pace"] == 1.55

    # Piper SynthesisConfig expressiveness
    syn_cfg = speech.build_piper_synthesis_config(speaker_id=None, length_scale=1.22, speed_mode="natural")
    assert syn_cfg.noise_scale == speech.PIPER_NOISE_SCALE
    assert syn_cfg.noise_w_scale == speech.PIPER_NOISE_W_SCALE

    # Windows SAPI rate: -2 for natural, -3 for slow
    captured_cmds: list[str] = []

    def fake_run(cmd, **kwargs):
        captured_cmds.append(" ".join(cmd))
        raise subprocess.CalledProcessError(1, cmd)

    monkeypatch.setattr(speech.subprocess, "run", fake_run)
    if speech.os.name == "nt":
        speech._try_windows_sapi_wav("apple", "en", tmp_path / "a.wav", "Female", "natural")
        speech._try_windows_sapi_wav("apple", "en", tmp_path / "b.wav", "Female", "slow")
        assert "$s.Rate = -2;" in captured_cmds[0]
        assert "$s.Rate = -3;" in captured_cmds[1]


def test_real_synthesis_mom_peter_kitty_and_slow_mode() -> None:
    speech.reset_cloud_backoff()

    # 1. Mom, Peter, and Kitty real synthesis (cloud-first) + slow mode
    mom = asyncio.run(
        speech.synthesize_speech(
            "Good morning sweetie! Have a warm apple cake.",
            lang="en",
            voice_hint="textbook_role_lingling_mother",
            speed_mode="natural",
        )
    )
    peter = asyncio.run(
        speech.synthesize_speech(
            "Hello! I am Peter! Let us read together!",
            lang="en",
            voice_hint="textbook_peter",
            speed_mode="natural",
        )
    )
    kitty = asyncio.run(
        speech.synthesize_speech(
            "Meow! Kitty is resting on the soft warm sofa!",
            lang="en",
            voice_hint="textbook_kitty",
            speed_mode="natural",
        )
    )
    kitty_no_cry = asyncio.run(
        speech.synthesize_speech(
            "Kitty is resting on the soft warm sofa!",
            lang="en",
            voice_hint="textbook_kitty",
            speed_mode="natural",
        )
    )
    for res in (mom, peter, kitty, kitty_no_cry):
        assert res["ok"] is True
        assert len(res["wav_base64"]) > 200

    assert mom["voice_profile"] == "mother_affectionate"
    assert mom["voice_label_zh"] == "温柔妈妈音"
    assert mom["speed_mode"] == "natural"
    assert peter["voice_profile"] == "boy_sunny"
    assert peter["voice_label_zh"] == "阳光小男孩音"
    assert kitty["voice_profile"] == "storyteller"
    assert kitty["voice_label_zh"] == "绘本姐姐音"
    # Confirm "Meow! " was stripped before synthesis so both hit the exact same audio!
    assert kitty["audio_path"] == kitty_no_cry["audio_path"]

    # 2. Offline Piper natural vs slow duration + breathing pause verification
    phrase = "pen. A blue pen is on the desk."
    off_nat = asyncio.run(
        speech.synthesize_speech(
            phrase,
            lang="en",
            voice_hint="textbook_role_lingling_mother",
            prefer_offline=True,
            speed_mode="natural",
        )
    )
    off_slow = asyncio.run(
        speech.synthesize_speech(
            phrase,
            lang="en",
            voice_hint="textbook_role_lingling_mother",
            prefer_offline=True,
            speed_mode="slow",
        )
    )
    assert off_nat["ok"] and off_slow["ok"]
    assert off_nat["speed_mode"] == "natural"
    assert off_slow["speed_mode"] == "slow"
    dur_nat = _wav_duration_seconds(base64.b64decode(off_nat["wav_base64"]))
    dur_slow = _wav_duration_seconds(base64.b64decode(off_slow["wav_base64"]))
    assert dur_slow > dur_nat * 1.15, f"Expected slow ({dur_slow:.2f}s) > 1.15x natural ({dur_nat:.2f}s)"

    # 3. ASGI TTSRequest & /api/v4/tts/speak speed_mode roundtrip
    req_default = TTSRequest(text="apple")
    assert req_default.speed_mode == "natural"
    req_slow = TTSRequest(text="apple", speed_mode="slow")
    assert req_slow.speed_mode == "slow"

    async def _check_http() -> None:
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
            r_slow = await client.post(
                "/api/v4/tts/speak",
                json={
                    "text": "pen. A blue pen.",
                    "lang": "en",
                    "voice_hint": "textbook_miss_li",
                    "prefer_offline": True,
                    "speed_mode": "slow",
                },
            )
            assert r_slow.status_code == 200
            body = r_slow.json()
            assert body["ok"] is True
            assert body["speed_mode"] == "slow"
            assert body["voice_profile"] == "teacher_gentle"
            assert body["voice_label_zh"] == "亲切女老师音"

    asyncio.run(_check_http())
