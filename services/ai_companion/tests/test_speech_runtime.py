"""Deterministic speech regressions: no network, real credentials or user cache."""
from __future__ import annotations

import asyncio
import base64
from contextlib import suppress
import importlib
import io
import threading
import time
import wave

import httpx
import pytest

from services.ai_companion import speech_service as speech

app_module = importlib.import_module("services.ai_companion.app")


def wav_bytes(*, rate=22050, seconds=0.1, channels=1, sample=0):
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)
        wf.setframerate(rate)
        wf.writeframes(int(sample).to_bytes(2, "little", signed=True) * int(rate * seconds) * channels)
    return buf.getvalue()


@pytest.fixture(autouse=True)
def isolated_speech(monkeypatch, tmp_path):
    monkeypatch.setattr(speech, "CACHE_DIR", tmp_path)
    monkeypatch.setenv("STUDYGAMES_TTS_MODE", "offline")
    monkeypatch.setattr(speech, "_get_vosk_model", lambda: None)
    monkeypatch.setattr(speech, "_try_windows_sapi_wav", lambda *args: False)
    speech.reset_cloud_backoff()
    yield
    speech.reset_cloud_backoff()


def test_offline_synthesis_keeps_health_responsive(monkeypatch):
    release = threading.Event()
    started = threading.Event()

    def slow_synthesis(text, lang, target, profile):
        started.set()
        release.wait(1.5)
        target.write_bytes(wav_bytes(sample=500))
        return True, "fixture-voice"

    monkeypatch.setattr(speech, "synthesize_piper_sync", slow_synthesis)

    async def run():
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app_module.app), base_url="http://test") as client:
            task = asyncio.create_task(client.post("/api/v4/tts/speak", json={"text":"Hello"}))
            try:
                await asyncio.to_thread(started.wait, 2)
                health = await client.get("/health")
                assert health.status_code == 200
                assert not task.done(), "synthesis blocked the event loop until it finished"
            finally:
                release.set()
                response = await task
            assert response.json()["ok"]

    asyncio.run(run())


def test_concurrent_identical_cloud_requests_share_one_synthesis(monkeypatch):
    calls = []
    monkeypatch.setenv("STUDYGAMES_TTS_MODE", "cloud_first")

    async def cloud(text, lang, target, profile):
        calls.append(text)
        await asyncio.sleep(0.02)
        target.write_bytes(wav_bytes(sample=1000))
        return True, "test-cloud"

    monkeypatch.setattr(speech, "_try_commercial_cloud_tts", cloud)

    async def run():
        results = await asyncio.gather(*(speech.synthesize_speech("Good morning") for _ in range(8)))
        assert all(r["ok"] for r in results)
        assert len({r["wav_base64"] for r in results}) == 1
        assert len(calls) == 1

    asyncio.run(run())


def test_silent_recording_is_not_reported_as_speech():
    result = speech.evaluate_follow_along({"target_text":"apple", "wav_base64":base64.b64encode(wav_bytes(seconds=1)).decode()})
    assert result["voice_detected"] is False
    assert result["match_tier"] == "no_voice"
    assert result["similarity"] is None


def test_no_recording_does_not_invent_pronunciation_similarity():
    result = speech.evaluate_follow_along({"target_text":"apple", "rms_energy":0.05, "duration_ms":900})
    assert result["voice_detected"] is True
    assert result["similarity"] is None


def test_silent_mode_does_not_claim_a_perfect_match():
    result = speech.evaluate_follow_along({"target_text":"apple", "mode":"shy"})
    assert result["voice_detected"] is False
    assert result["similarity"] is None


def test_cancelled_listener_does_not_cancel_shared_audio(monkeypatch):
    monkeypatch.setenv("STUDYGAMES_TTS_MODE", "cloud_first")

    async def run():
        started, release = asyncio.Event(), asyncio.Event()
        calls = []

        async def cloud(text, lang, target, profile):
            calls.append(text)
            started.set()
            await release.wait()
            target.write_bytes(wav_bytes(sample=1000))
            return True, "fixture"

        monkeypatch.setattr(speech, "_try_commercial_cloud_tts", cloud)
        first = asyncio.create_task(speech.synthesize_speech("Shared phrase"))
        await started.wait()
        second = asyncio.create_task(speech.synthesize_speech("Shared phrase"))
        await asyncio.sleep(0)
        first.cancel()
        with suppress(asyncio.CancelledError):
            await first
        release.set()
        result = await second
        assert result["ok"] and calls == ["Shared phrase"]
        await asyncio.sleep(0)
        assert not speech._INFLIGHT

    asyncio.run(run())


def test_partial_cloud_audio_is_not_published(monkeypatch):
    monkeypatch.setenv("STUDYGAMES_TTS_MODE", "cloud_first")
    final_path = speech._cache_path("Atomic audio", "en", speech.resolve_voice_profile("warm")["voice_key"], "cloud")

    async def cloud(text, lang, target, profile):
        target.write_bytes(b"RIFF partial audio")
        await asyncio.sleep(0)
        assert not final_path.exists()
        target.write_bytes(wav_bytes(sample=1000))
        return True, "fixture"

    monkeypatch.setattr(speech, "_try_commercial_cloud_tts", cloud)
    result = asyncio.run(speech.synthesize_speech("Atomic audio"))
    assert result["ok"] and speech._valid_wav(final_path)
    assert not list(speech.CACHE_DIR.glob(".tts-*.wav"))


def test_truncated_cache_is_repaired(monkeypatch):
    phrase = "Repair cache"
    target = speech._cache_path(phrase, "en", speech.resolve_voice_profile("warm")["voice_key"], "local")
    raw = wav_bytes(sample=1000)
    target.write_bytes(raw[:-50])
    calls = []

    def piper(text, lang, path, profile):
        calls.append(text)
        path.write_bytes(raw)
        return True, "fixture"

    monkeypatch.setattr(speech, "synthesize_piper_sync", piper)
    result = asyncio.run(speech.synthesize_speech(phrase))
    assert result["ok"] and result["cached"] is False
    assert target.read_bytes() == raw and calls == [phrase]


def test_chime_fallback_does_not_poison_neural_cache(monkeypatch):
    monkeypatch.setattr(speech, "synthesize_piper_sync", lambda *args: (False, ""))
    first = asyncio.run(speech.synthesize_speech("Retry when voice is ready"))
    assert first["engine"] == "melodic_chime_fallback"

    def piper(text, lang, path, profile):
        path.write_bytes(wav_bytes(sample=1000))
        return True, "installed-voice"

    monkeypatch.setattr(speech, "synthesize_piper_sync", piper)
    second = asyncio.run(speech.synthesize_speech("Retry when voice is ready"))
    assert second["engine"] == "piper_neural_onnx"
    assert second["voice_id"] == "installed-voice"
    assert second["wav_base64"] != first["wav_base64"]


def test_shared_local_model_is_not_used_concurrently(monkeypatch):
    active = 0
    peak = 0

    def piper(text, lang, path, profile):
        nonlocal active, peak
        active += 1
        peak = max(peak, active)
        time.sleep(0.02)
        path.write_bytes(wav_bytes(sample=1000))
        active -= 1
        return True, "fixture"

    monkeypatch.setattr(speech, "synthesize_piper_sync", piper)

    async def run():
        return await asyncio.gather(*(speech.synthesize_speech(f"Phrase {i}") for i in range(4)))

    assert all(item["ok"] for item in asyncio.run(run()))
    assert peak == 1


@pytest.mark.parametrize("rate,channels", [(16000, 1), (22050, 1), (44100, 2), (48000, 2)])
def test_recording_measurements_use_actual_wav_format(rate, channels):
    raw = wav_bytes(rate=rate, seconds=0.6, channels=channels, sample=1000)
    # A valid metadata chunk makes the PCM start later than the common 44 bytes.
    chunk = b"JUNK" + (4).to_bytes(4, "little") + b"meta"
    raw = raw[:4] + (len(raw) - 8 + len(chunk)).to_bytes(4, "little") + raw[8:12] + chunk + raw[12:]
    energy, duration = speech._recording_measurements(raw)
    assert duration == 600
    assert energy == pytest.approx(1000 / 32768)


def test_silent_audio_overrides_claimed_energy(monkeypatch):
    def unexpected_asr(*args):
        pytest.fail("silence should not be sent to ASR")

    monkeypatch.setattr(speech, "_transcribe_wav_offline", unexpected_asr)
    result = speech.evaluate_follow_along({"rms_energy":0.3, "duration_ms":2000, "wav_base64":base64.b64encode(wav_bytes(seconds=1)).decode()})
    assert result["voice_detected"] is False


def test_non_english_target_is_not_scored_by_english_asr(monkeypatch):
    def unexpected_asr(*args):
        pytest.fail("English-only recognizer cannot score a Chinese target")

    monkeypatch.setattr(speech, "_transcribe_wav_offline", unexpected_asr)
    result = speech.evaluate_follow_along({"target_text":"苹果", "wav_base64":base64.b64encode(wav_bytes(sample=1000)).decode()})
    assert result["voice_detected"] is True
    assert result["similarity"] is None and result["asr_engine"] == "envelope_fallback"


@pytest.mark.parametrize("payload", [{"wav_base64":"not a wav!"}, {"wav_base64":base64.b64encode(b"garbage").decode()}, {"rms_energy":"invalid"}, {"duration_ms":{}}, {"rms_energy":float("nan")}])
def test_invalid_recordings_return_controlled_errors(payload):
    assert speech.evaluate_follow_along(payload)["ok"] is False


def test_recognition_keeps_health_responsive(monkeypatch):
    started, release = threading.Event(), threading.Event()

    def slow_recognition(payload):
        started.set()
        release.wait(1.5)
        return {"ok":True}

    monkeypatch.setattr(app_module, "evaluate_follow_along", slow_recognition)

    async def run():
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app_module.app), base_url="http://test") as client:
            task = asyncio.create_task(client.post("/api/v4/speech/encourage", json={"target_text":"apple"}))
            try:
                assert await asyncio.to_thread(started.wait, 2)
                assert (await client.get("/health")).status_code == 200
                assert not task.done()
            finally:
                release.set()
                await task

    asyncio.run(run())


def test_cloud_deadline_falls_back_and_opens_backoff(monkeypatch):
    monkeypatch.setenv("STUDYGAMES_TTS_MODE", "cloud_first")
    monkeypatch.setattr(speech, "CLOUD_ATTEMPT_BUDGET_SECONDS", 0.03)
    attempts = []

    async def stalled_cloud(text, lang, target, profile):
        attempts.append(text)
        target.write_bytes(b"incomplete")
        await asyncio.sleep(2)
        pytest.fail("stalled cloud provider exceeded its deadline")

    def piper(text, lang, target, profile):
        target.write_bytes(wav_bytes(sample=1000))
        return True, "fixture"

    monkeypatch.setattr(speech, "_try_commercial_cloud_tts", stalled_cloud)
    monkeypatch.setattr(speech, "synthesize_piper_sync", piper)

    async def run():
        results = []
        for phrase in ("First timeout", "Second timeout", "Circuit is open"):
            results.append(await asyncio.wait_for(speech.synthesize_speech(phrase), timeout=0.5))
        return results

    assert all(r["engine"] == "piper_neural_onnx" for r in asyncio.run(run()))
    assert attempts == ["First timeout", "Second timeout"]
    assert not list(speech.CACHE_DIR.glob(".tts-*.wav"))
