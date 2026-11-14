"""Multi-Character Cloud + Offline Neural TTS & Vosk Speech Recognition Service.

Synthesis priority (`synthesize_speech`):
1. Cloud Hyper-Realistic Multi-Character Neural TTS (Primary when online):
   - Optional Commercial Cloud Neural TTS (`OPENAI_TTS_API_KEY`) with character voices.
   - Microsoft Edge Multi-Character Neural TTS (`edge-tts`) covering warm baritone Uncle Bear,
     gentle female teachers, genuine EN/ZH child voices (Lingling, Peter), cute mascot (Dino),
     and 34 distinct island residents with per-character pitch/rate prosody, decoded to 16-bit PCM WAV.
   - Automatic 20s offline circuit-breaker so offline play never lags waiting for network timeouts.
2. Local Offline Multi-Model Piper VITS Neural ONNX (Seamless Offline Fallback):
   - Uses 7 distinct local neural models (`en_US-amy`, `en_US-ryan`, `en_US-kristin`,
     `en_US-arctic` 18-speaker, `zh_CN-huayan`, `zh_CN-chaowen` male, `zh_CN-xiao_ya` girl)
     plus formant/pitch resampling with `length_scale` pace compensation.
3. Windows SAPI5 offline voice fallback (gender-matched when installed).
4. Soft marimba chime WAV fallback on headless CI without voice packs.

Offline Recognition (`evaluate_follow_along`):
1. Real offline Vosk Kaldi ASR (`vosk-model-small-en-us-0.15`) on 16kHz/22kHz PCM WAV (`wav_base64`).
2. Envelope/rhythm & shy-silent inclusive fallback when no microphone audio is attached.
"""
from __future__ import annotations

import asyncio
import base64
from difflib import SequenceMatcher
import hashlib
import io
import json
import math
import os
import re
import struct
import subprocess
import time
import wave
from pathlib import Path
from typing import Any

import httpx

from .voice_profiles import (
    format_edge_pitch,
    format_edge_rate,
    resolve_voice_profile,
)

ROOT = Path(__file__).resolve().parents[2]
CACHE_DIR = ROOT / ".local" / "tts_cache"
MODELS_DIR = ROOT / ".local" / "models"
PIPER_DIR = MODELS_DIR / "piper"
PIPER_DEFAULT_EN = PIPER_DIR / "en_US-amy-medium.onnx"
PIPER_DEFAULT_ZH = PIPER_DIR / "zh_CN-huayan-medium.onnx"
VOSK_EN_DIR = MODELS_DIR / "vosk-en"

_PIPER_VOICES: dict[str, Any] = {}
_PIPER_LOAD_ATTEMPTED: set[str] = set()
_VOSK_MODEL: Any = None
_VOSK_LOAD_ATTEMPTED: bool = False
_CLOUD_BACKOFF_UNTIL: float = 0.0
_CLOUD_CONSEC_FAILS: int = 0


def reset_cloud_backoff() -> None:
    global _CLOUD_BACKOFF_UNTIL, _CLOUD_CONSEC_FAILS
    _CLOUD_BACKOFF_UNTIL = 0.0
    _CLOUD_CONSEC_FAILS = 0


def _norm_lang(lang: str) -> str:
    return "en" if (lang or "en").lower().startswith("en") else "zh"


def _cache_path(text: str, lang: str, voice_key: str, tier: str) -> Path:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    nlang = _norm_lang(lang)
    safe_voice = re.sub(r"[^a-z0-9_]+", "_", voice_key.lower()).strip("_")[:28] or "warm"
    digest = hashlib.sha256(f"v51|{tier}|{nlang}|{voice_key}|{text.strip()}".encode("utf-8")).hexdigest()[:22]
    return CACHE_DIR / f"tts_v51_{tier}_{nlang}_{safe_voice}_{digest}.wav"


def _get_piper_model_by_filename(filename: str, fallback: Path) -> Any:
    candidate = PIPER_DIR / filename
    if not candidate.is_file():
        candidate = fallback
    key = str(candidate.resolve())
    if key in _PIPER_VOICES:
        return _PIPER_VOICES[key]
    if key in _PIPER_LOAD_ATTEMPTED:
        return None
    _PIPER_LOAD_ATTEMPTED.add(key)
    if not candidate.is_file():
        return None
    try:
        from piper.voice import PiperVoice

        voice = PiperVoice.load(str(candidate), download_dir=PIPER_DIR)
        _PIPER_VOICES[key] = voice
        return voice
    except Exception:
        return None


def _get_vosk_model() -> Any:
    global _VOSK_MODEL, _VOSK_LOAD_ATTEMPTED
    if _VOSK_MODEL is not None:
        return _VOSK_MODEL
    if _VOSK_LOAD_ATTEMPTED:
        return None
    _VOSK_LOAD_ATTEMPTED = True
    if not (VOSK_EN_DIR / "conf").exists():
        return None
    try:
        from vosk import Model, SetLogLevel

        SetLogLevel(-1)
        _VOSK_MODEL = Model(str(VOSK_EN_DIR))
        return _VOSK_MODEL
    except Exception:
        return None


def _write_pcm16_wav(pcm_bytes: bytes, sample_rate: int, target: Path) -> bool:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    with wave.open(str(target), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(pcm_bytes)
    return target.is_file() and target.stat().st_size > 256


def _decode_encoded_audio_to_wav(raw_bytes: bytes, target: Path, sample_rate: int = 22050) -> bool:
    if len(raw_bytes) > 44 and raw_bytes[:4] == b"RIFF" and raw_bytes[8:12] == b"WAVE":
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw_bytes)
        return True
    try:
        import miniaudio

        decoded = miniaudio.decode(
            raw_bytes,
            output_format=miniaudio.SampleFormat.SIGNED16,
            nchannels=1,
            sample_rate=sample_rate,
        )
        pcm_bytes = decoded.samples.tobytes()
        if len(pcm_bytes) < 256:
            return False
        return _write_pcm16_wav(pcm_bytes, sample_rate, target)
    except Exception:
        return False


def _resample_pitch_shift_pcm16(pcm_bytes: bytes, pitch_shift: float) -> bytes:
    """Shift pitch and vocal-tract formants by `pitch_shift` via clean time-domain resampling.

    Paired with Piper `length_scale = pace * pitch_shift`, the resampled output keeps the exact
    intended speaking rate `pace` with zero phase-vocoder metallic artifacts.
    """
    if abs(pitch_shift - 1.0) < 0.015 or len(pcm_bytes) < 64:
        return pcm_bytes
    try:
        import numpy as np

        samples = np.frombuffer(pcm_bytes, dtype=np.int16).astype(np.float32)
        in_len = samples.shape[0]
        out_len = max(32, int(round(in_len / pitch_shift)))
        x_old = np.linspace(0.0, 1.0, num=in_len, endpoint=False)
        x_new = np.linspace(0.0, 1.0, num=out_len, endpoint=False)
        resampled = np.interp(x_new, x_old, samples)
        clipped = np.clip(np.round(resampled), -32767, 32767).astype(np.int16)
        return clipped.tobytes()
    except Exception:
        return pcm_bytes


def synthesize_piper_sync(
    text: str,
    lang: str,
    target: Path,
    profile: dict[str, Any] | None = None,
) -> tuple[bool, str]:
    spec = profile or resolve_voice_profile("warm")
    nlang = _norm_lang(lang)
    model_file = str(spec["piper_en_model"] if nlang == "en" else spec["piper_zh_model"])
    speaker_id = spec["piper_en_speaker"] if nlang == "en" else spec["piper_zh_speaker"]
    fallback = PIPER_DEFAULT_EN if nlang == "en" else PIPER_DEFAULT_ZH

    # If the preferred multi-speaker/gender model isn't installed, smoothly fall back
    actual_model_name = model_file if (PIPER_DIR / model_file).is_file() else fallback.name
    if actual_model_name != model_file:
        speaker_id = None

    voice = _get_piper_model_by_filename(actual_model_name, fallback)
    if voice is None:
        return False, ""

    pace = float(spec.get("piper_pace", 1.0))
    pitch_shift = float(spec.get("piper_pitch_shift", 1.0))
    effective_length = max(0.72, min(1.45, pace * pitch_shift))

    def _run_model(v_obj: Any, spk: Any, tag_base: str) -> tuple[bool, str]:
        from piper.config import SynthesisConfig

        syn_cfg = SynthesisConfig(
            speaker_id=int(spk) if spk is not None else None,
            length_scale=effective_length,
        )
        buf = io.BytesIO()
        with wave.open(buf, "wb") as wf:
            v_obj.synthesize_wav(text, wf, syn_config=syn_cfg)

        raw_wav = buf.getvalue()
        if abs(pitch_shift - 1.0) >= 0.015:
            with wave.open(io.BytesIO(raw_wav), "rb") as rf:
                sr = rf.getframerate()
                pcm = rf.readframes(rf.getnframes())
            shifted = _resample_pitch_shift_pcm16(pcm, pitch_shift)
            ok = _write_pcm16_wav(shifted, sr, target)
        else:
            CACHE_DIR.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw_wav)
            ok = target.is_file() and target.stat().st_size > 256

        v_tag = tag_base.removesuffix(".onnx")
        if spk is not None:
            v_tag = f"{v_tag}#spk{spk}"
        return ok, v_tag

    try:
        return _run_model(voice, speaker_id, actual_model_name)
    except Exception:
        if actual_model_name != fallback.name:
            fb_voice = _get_piper_model_by_filename(fallback.name, fallback)
            if fb_voice is not None:
                try:
                    return _run_model(fb_voice, None, fallback.name)
                except Exception:
                    return False, ""
        return False, ""


async def _try_edge_neural_tts(
    text: str,
    lang: str,
    target: Path,
    profile: dict[str, Any],
) -> tuple[bool, str]:
    global _CLOUD_BACKOFF_UNTIL, _CLOUD_CONSEC_FAILS
    if time.monotonic() < _CLOUD_BACKOFF_UNTIL:
        return False, ""
    try:
        import edge_tts

        nlang = _norm_lang(lang)
        voice_name = str(profile["edge_en"] if nlang == "en" else profile["edge_zh"])
        rate_str = format_edge_rate(int(profile.get("rate_pct", 0)))
        pitch_str = format_edge_pitch(int(profile.get("pitch_hz", 0)))

        async def _fetch_mp3() -> bytes:
            comm = edge_tts.Communicate(text, voice_name, rate=rate_str, pitch=pitch_str)
            mp3_buf = bytearray()
            async for chunk in comm.stream():
                if chunk.get("type") == "audio":
                    mp3_buf.extend(chunk["data"])
            return bytes(mp3_buf)

        mp3_bytes = await asyncio.wait_for(_fetch_mp3(), timeout=7.5)
        if len(mp3_bytes) < 200:
            _CLOUD_CONSEC_FAILS += 1
            if _CLOUD_CONSEC_FAILS >= 2:
                _CLOUD_BACKOFF_UNTIL = time.monotonic() + 20.0
            return False, ""
        if _decode_encoded_audio_to_wav(mp3_bytes, target, sample_rate=22050):
            _CLOUD_CONSEC_FAILS = 0
            _CLOUD_BACKOFF_UNTIL = 0.0
            return True, f"{voice_name}({rate_str},{pitch_str})"
        return False, ""
    except Exception:
        _CLOUD_CONSEC_FAILS += 1
        if _CLOUD_CONSEC_FAILS >= 2:
            _CLOUD_BACKOFF_UNTIL = time.monotonic() + 20.0
        return False, ""


async def _try_commercial_cloud_tts(
    text: str,
    lang: str,
    target: Path,
    profile: dict[str, Any],
) -> tuple[bool, str]:
    api_key = os.environ.get("OPENAI_TTS_API_KEY") or os.environ.get("STUDYGAMES_CLOUD_TTS_KEY")
    if not api_key:
        return False, ""
    base_url = os.environ.get("OPENAI_TTS_BASE_URL", "https://api.openai.com/v1")
    voice_name = str(profile.get("openai_voice") or ("nova" if _norm_lang(lang) == "en" else "shimmer"))
    model_name = os.environ.get("OPENAI_TTS_MODEL", "tts-1")
    try:
        async with httpx.AsyncClient(timeout=4.2) as client:
            resp = await client.post(
                f"{base_url.rstrip('/')}/audio/speech",
                headers={"Authorization": f"Bearer {api_key}"},
                json={
                    "model": model_name,
                    "voice": voice_name,
                    "response_format": "wav",
                    "input": text,
                },
            )
            resp.raise_for_status()
            if len(resp.content) > 200 and _decode_encoded_audio_to_wav(resp.content, target, sample_rate=22050):
                return True, f"{model_name}:{voice_name}"
    except Exception:
        return False, ""
    return False, ""


def _build_response(
    target: Path,
    *,
    cached: bool,
    engine: str,
    profile: dict[str, Any],
    voice_id: str,
) -> dict[str, Any]:
    raw = target.read_bytes()
    return {
        "ok": True,
        "cached": cached,
        "engine": engine,
        "voice_profile": str(profile["profile_id"]),
        "voice_key": str(profile["voice_key"]),
        "voice_label_zh": str(profile["label_zh"]),
        "voice_id": voice_id,
        "audio_path": str(target),
        "wav_base64": base64.b64encode(raw).decode("ascii") if len(raw) < 950_000 else "",
    }


async def synthesize_speech(
    text: str,
    lang: str = "en",
    voice_hint: str = "warm",
    *,
    prefer_offline: bool = False,
) -> dict[str, Any]:
    cleaned = " ".join((text or "").strip().split())[:260]
    if not cleaned:
        return {"ok": False, "error": "empty_text"}

    profile = resolve_voice_profile(voice_hint)
    voice_key = str(profile["voice_key"])
    tts_mode = os.environ.get("STUDYGAMES_TTS_MODE", "cloud_first").strip().lower()
    offline_only = prefer_offline or (tts_mode == "offline")

    cloud_target = _cache_path(cleaned, lang, voice_key, "cloud")
    local_target = _cache_path(cleaned, lang, voice_key, "local")

    # 0. Instant hit on previously cached hyper-realistic cloud voice (works even offline!)
    if not offline_only and cloud_target.is_file() and cloud_target.stat().st_size > 256:
        nlang = _norm_lang(lang)
        v_id = str(profile["edge_en"] if nlang == "en" else profile["edge_zh"])
        return _build_response(
            cloud_target,
            cached=True,
            engine="cloud_disk_cache",
            profile=profile,
            voice_id=v_id,
        )

    # 1. Cloud Hyper-Realistic Multi-Character Neural TTS (Primary when online)
    if not offline_only:
        comm_ok, comm_voice = await _try_commercial_cloud_tts(cleaned, lang, cloud_target, profile)
        if comm_ok and cloud_target.is_file():
            return _build_response(
                cloud_target,
                cached=False,
                engine="cloud_neural_tts",
                profile=profile,
                voice_id=comm_voice,
            )

        edge_ok, edge_voice = await _try_edge_neural_tts(cleaned, lang, cloud_target, profile)
        if edge_ok and cloud_target.is_file():
            return _build_response(
                cloud_target,
                cached=False,
                engine="edge_neural_tts",
                profile=profile,
                voice_id=edge_voice,
            )

    # 2. Local Offline Multi-Model Disk Cache
    if local_target.is_file() and local_target.stat().st_size > 256:
        nlang = _norm_lang(lang)
        v_id = str(profile["piper_en_model"] if nlang == "en" else profile["piper_zh_model"]).removesuffix(".onnx")
        return _build_response(
            local_target,
            cached=True,
            engine="neural_disk_cache",
            profile=profile,
            voice_id=v_id,
        )

    # 3. Local Offline Multi-Model Piper VITS Neural ONNX (sub-50ms multi-character fallback)
    piper_ok, piper_voice = synthesize_piper_sync(cleaned, lang, local_target, profile)
    if piper_ok and local_target.is_file():
        return _build_response(
            local_target,
            cached=False,
            engine="piper_neural_onnx",
            profile=profile,
            voice_id=piper_voice,
        )

    # 4. Local Windows SAPI Voice Synthesis (gender-aware)
    if _try_windows_sapi_wav(cleaned, lang, local_target, str(profile.get("sapi_gender", "Female"))) and local_target.is_file():
        return _build_response(
            local_target,
            cached=False,
            engine="windows_sapi_voice",
            profile=profile,
            voice_id=f"sapi:{profile.get('sapi_gender', 'Female')}",
        )

    # 5. Pure-Python soft marimba chime fallback (guarantees valid WAV on any OS)
    _write_chime_wav(cleaned, local_target)
    return _build_response(
        local_target,
        cached=False,
        engine="melodic_chime_fallback",
        profile=profile,
        voice_id="marimba_chime",
    )


def _try_windows_sapi_wav(text: str, lang: str, target: Path, preferred_gender: str = "Female") -> bool:
    if os.name != "nt":
        return False
    try:
        culture_prefix = _norm_lang(lang)
        ps_script = (
            "Add-Type -AssemblyName System.Speech; "
            "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
            "$pref = $env:SG_TTS_LANG; "
            "$gen = $env:SG_TTS_GENDER; "
            "$chosen = $null; "
            "foreach ($v in $s.GetInstalledVoices()) { "
            "  if ($v.Enabled -and $v.VoiceInfo.Culture.Name.ToLower().StartsWith($pref)) { "
            "    if (-not $chosen) { $chosen = $v.VoiceInfo.Name } "
            "    if ($v.VoiceInfo.Gender.ToString() -eq $gen) { $chosen = $v.VoiceInfo.Name; break } "
            "  } "
            "} "
            "if ($chosen) { $s.SelectVoice($chosen) } "
            "$s.Rate = -1; $s.Volume = 95; "
            "$s.SetOutputToWaveFile($env:SG_TTS_OUT); "
            "$s.Speak($env:SG_TTS_TEXT); "
            "$s.Dispose()"
        )
        env = os.environ.copy()
        env["SG_TTS_TEXT"] = text
        env["SG_TTS_OUT"] = str(target)
        env["SG_TTS_LANG"] = culture_prefix
        env["SG_TTS_GENDER"] = preferred_gender
        creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
        subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", ps_script],
            env=env,
            timeout=6.0,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=creationflags,
        )
        return target.is_file() and target.stat().st_size > 256
    except Exception:
        return False


def _write_chime_wav(text: str, target: Path) -> None:
    sr = 22050
    dur = 0.45
    n = int(sr * dur)
    base_freq = 440.0 + (sum(ord(c) for c in text) % 5) * 44.0
    frames = bytearray()
    for i in range(n):
        t = i / sr
        env = min(t / 0.01, 1.0) * math.exp(-t * 7.5)
        sample = math.sin(2.0 * math.pi * base_freq * t) * env * 0.35
        frames.extend(struct.pack("<h", max(-32767, min(32767, int(sample * 32767)))))
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    with wave.open(str(target), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(bytes(frames))


def _normalize_words(text: str) -> str:
    tokens = re.findall(r"[a-zA-Z']+", text.lower())
    return " ".join(tokens).strip()


def _transcribe_wav_offline(raw_wav: bytes, target_norm: str) -> str:
    model = _get_vosk_model()
    if model is None:
        return ""
    try:
        from vosk import KaldiRecognizer

        with wave.open(io.BytesIO(raw_wav), "rb") as rf:
            channels = rf.getnchannels()
            sampwidth = rf.getsampwidth()
            sr = rf.getframerate()
            pcm = rf.readframes(rf.getnframes())

        if sampwidth != 2 or sr < 8000:
            return ""
        if channels == 2:
            total_short = len(pcm) // 2
            shorts = struct.unpack(f"<{total_short}h", pcm[: total_short * 2])
            mono = [int((shorts[i] + shorts[i + 1]) * 0.5) for i in range(0, total_short - 1, 2)]
            pcm = struct.pack(f"<{len(mono)}h", *mono)

        rec = KaldiRecognizer(model, float(sr))
        rec.AcceptWaveform(pcm)
        res = json.loads(rec.FinalResult() or "{}")
        free_txt = str(res.get("text") or "").strip()
        if free_txt:
            return free_txt

        if target_norm:
            vocab = list(dict.fromkeys(target_norm.split() + ["hello", "good", "morning", "[unk]"]))
            rec_g = KaldiRecognizer(model, float(sr), json.dumps(vocab))
            rec_g.AcceptWaveform(pcm)
            res_g = json.loads(rec_g.FinalResult() or "{}")
            g_txt = str(res_g.get("text") or "").replace("[unk]", "").strip()
            return g_txt
    except Exception:
        return ""
    return ""


def evaluate_follow_along(payload: dict[str, Any]) -> dict[str, Any]:
    """Tolerant, zero-stress speaking recognition & encouragement for 7-12yo learners."""
    target_text = " ".join(str(payload.get("target_text") or "Hello!").strip().split())[:120]
    target_norm = _normalize_words(target_text)
    mode = str(payload.get("mode") or "voice").strip().lower()
    rms_energy = float(payload.get("rms_energy") or 0.0)
    duration_ms = int(payload.get("duration_ms") or 0)
    wav_b64 = str(payload.get("wav_base64") or "").strip()

    if mode == "shy":
        return {
            "ok": True,
            "mode": "shy",
            "target_text": target_text,
            "voice_detected": False,
            "asr_engine": "shy_silent",
            "transcript": "",
            "match_tier": "shy_silent",
            "similarity": 1.0,
            "cheer_badge": "🌿 安心默读星",
            "reply_en": f'Listening in your heart is great too! "{target_text}" stays with you!',
            "reply_zh": f"在心里轻轻默读「{target_text}」也很棒！不着急，想开口时随时都可以 ✨",
        }

    transcript = ""
    asr_used = False
    if wav_b64:
        try:
            raw = base64.b64decode(wav_b64)
            if len(raw) > 48:
                pcm = raw[44:]
                count = len(pcm) // 2
                if count > 0:
                    samples = struct.unpack(f"<{count}h", pcm[: count * 2])
                    sq = sum((s / 32768.0) ** 2 for s in samples)
                    rms_energy = max(rms_energy, math.sqrt(sq / count))
                    duration_ms = max(duration_ms, int(count / 16.0))
                transcript = _transcribe_wav_offline(raw, target_norm)
                if _get_vosk_model() is not None:
                    asr_used = True
        except Exception:
            pass

    if asr_used and transcript:
        trans_norm = _normalize_words(transcript)
        sim = SequenceMatcher(None, target_norm, trans_norm).ratio() if target_norm else 0.8
        target_tokens = set(target_norm.split())
        heard_tokens = set(trans_norm.split())
        token_hit = bool(target_tokens & heard_tokens)

        if sim >= 0.72 or (token_hit and sim >= 0.45):
            return {
                "ok": True,
                "mode": "voice",
                "target_text": target_text,
                "voice_detected": True,
                "asr_engine": "vosk_offline_asr",
                "transcript": transcript,
                "match_tier": "exact",
                "similarity": round(sim, 3),
                "cheer_badge": "🏆 清晰发音星",
                "reply_en": f'I heard "{transcript}" clearly! Your "{target_text}" sounds wonderful!',
                "reply_zh": f"听得超清楚！你刚刚读出的「{transcript}」又准又自然，太棒啦 🌟",
            }
        if sim >= 0.36 or token_hit:
            return {
                "ok": True,
                "mode": "voice",
                "target_text": target_text,
                "voice_detected": True,
                "asr_engine": "vosk_offline_asr",
                "transcript": transcript,
                "match_tier": "close",
                "similarity": round(sim, 3),
                "cheer_badge": "🌟 自信开口星",
                "reply_en": f'Nice try! I heard "{transcript}" — so close to "{target_text}"!',
                "reply_zh": f"勇敢开口超赞！我听到了「{transcript}」，离「{target_text}」已经非常接近啦 ✨",
            }
        return {
            "ok": True,
            "mode": "voice",
            "target_text": target_text,
            "voice_detected": True,
            "asr_engine": "vosk_offline_asr",
            "transcript": transcript,
            "match_tier": "gentle_model",
            "similarity": round(sim, 3),
            "cheer_badge": "💛 温暖领读星",
            "reply_en": f'Brave voice! Let\'s say "{target_text}" slowly together once more!',
            "reply_zh": f"听到你响亮的声音啦！不扣分，来跟着伙伴慢一点再读一遍：「{target_text}」💛",
        }

    if rms_energy >= 0.012 or duration_ms >= 550:
        return {
            "ok": True,
            "mode": "voice",
            "target_text": target_text,
            "voice_detected": True,
            "asr_engine": "envelope_fallback",
            "transcript": "",
            "match_tier": "confident_voice",
            "similarity": 0.85,
            "cheer_badge": "🌟 自信开口星",
            "reply_en": f'Sunny voice! You spoke "{target_text}" so warmly and bravely!',
            "reply_zh": f"声音真洪亮温暖！刚才跟读「{target_text}」超级自信，为你鼓掌 🌟",
        }

    return {
        "ok": True,
        "mode": "voice",
        "target_text": target_text,
        "voice_detected": True,
        "asr_engine": "envelope_fallback",
        "transcript": "",
        "match_tier": "gentle_voice",
        "similarity": 0.70,
        "cheer_badge": "✨ 勇敢轻声星",
        "reply_en": f'I heard your gentle voice trying "{target_text}"! Wonderful try!',
        "reply_zh": f"听到了你轻轻跟读「{target_text}」的声音！勇敢开口就是最棒的进步 ✨",
    }
