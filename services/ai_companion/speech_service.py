"""Multi-Character Cloud + Offline Neural TTS & Vosk Speech Recognition Service.

Synthesis priority (`synthesize_speech`):
1. Cloud Hyper-Realistic Multi-Character Neural TTS (Primary when online):
   - Optional Commercial Cloud Neural TTS (`OPENAI_TTS_API_KEY`) with character voices.
   - Microsoft Edge Multi-Character Neural TTS (`edge-tts`) covering affectionate Mom,
     warm Dad, gentle teachers, expressive Storyteller Sister, genuine EN/ZH child voices
     (Lingling, Peter), cute mascots (Dino, Xiaoxiao Parrot), and 34 distinct island residents
     with child-friendly slower cadence and optional `"slow"` follow-along mode.
   - A shared 6.5s cloud-attempt budget and a 20s backoff after 3 consecutive failures.
2. Local Offline Multi-Model Piper VITS Neural ONNX (Seamless Offline Fallback):
   - Uses 7 distinct local neural models (`en_US-amy`, `en_US-ryan`, `en_US-kristin`,
     `en_US-arctic` 18-speaker, `zh_CN-huayan`, `zh_CN-chaowen` male, `zh_CN-xiao_ya` girl)
     with expressive `noise_scale`/`noise_w_scale`, natural sentence pauses (`0.38s`–`0.50s`),
     and formant/pitch resampling with `length_scale` pace compensation.
3. Windows SAPI5 offline voice fallback (gender-matched and rate-slowed when installed).
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
import inspect
import io
import json
import math
import os
import re
import struct
import subprocess
import tempfile
import threading
import time
import wave
from pathlib import Path
from typing import Any

import httpx

from .env_loader import load_dotenv_if_changed
from .voice_profiles import (
    PURE_ANIMAL_KEYS,
    format_edge_pitch,
    format_edge_rate,
    resolve_voice_profile,
    strip_animal_interjection,
)

ROOT = Path(__file__).resolve().parents[2]
_DEFAULT_CACHE_DIR = ROOT / ".local" / "tts_cache"
CACHE_DIR = _DEFAULT_CACHE_DIR
_DEFAULT_VOICE_BANK_DIR = ROOT / "assets" / "voice_bank_v10"
VOICE_BANK_DIR = _DEFAULT_VOICE_BANK_DIR
MODELS_DIR = ROOT / ".local" / "models"
PIPER_DIR = MODELS_DIR / "piper"
PIPER_DEFAULT_EN = PIPER_DIR / "en_US-amy-medium.onnx"
PIPER_DEFAULT_ZH = PIPER_DIR / "zh_CN-huayan-medium.onnx"
VOSK_EN_DIR = MODELS_DIR / "vosk-en"

_VOICE_BANK_LOCK = threading.Lock()
_VOICE_BANK_MANIFEST_PATH: Path | None = None
_VOICE_BANK_MTIME_NS: int = -1
_VOICE_BANK_ENTRIES: dict[str, Any] = {}
_UI_DECOR_SYMBOLS = ("★", "☆", "◈", "◇", "♪", "·", "▷", "【", "】")

_PIPER_VOICES: dict[str, Any] = {}
_PIPER_LOAD_ATTEMPTED: set[str] = set()
_VOSK_MODEL: Any = None
_VOSK_LOAD_ATTEMPTED: bool = False
_CLOUD_BACKOFF_UNTIL: float = 0.0
_CLOUD_CONSEC_FAILS: int = 0
CLOUD_ATTEMPT_BUDGET_SECONDS = 6.5
CLOUD_FAIL_BACKOFF_THRESHOLD = 3

PIPER_NOISE_SCALE = 0.68
PIPER_NOISE_W_SCALE = 0.82
PIPER_SENTENCE_SILENCE_NATURAL = 0.38
PIPER_SENTENCE_SILENCE_SLOW = 0.50

_LOCAL_SYNTHESIS_LOCK = threading.Lock()
_RECOGNITION_LOCK = threading.RLock()
_INFLIGHT: dict[tuple[asyncio.AbstractEventLoop, Path, bool], asyncio.Task] = {}
MAX_RECORDING_BYTES = 2_000_000

_HONORIFIC_ABBREVS = frozenset({"mr", "mrs", "ms", "miss", "dr", "st"})
_SINGLE_WORD_SENTENCE_EN_RE = re.compile(r"^([A-Za-z][A-Za-z'-]{0,24})\.\s+(\S.*)$")
_SINGLE_WORD_SENTENCE_ZH_RE = re.compile(r"^([\u4e00-\u9fff]{1,5})。\s*(\S.*)$")


def reset_cloud_backoff() -> None:
    global _CLOUD_BACKOFF_UNTIL, _CLOUD_CONSEC_FAILS
    _CLOUD_BACKOFF_UNTIL = 0.0
    _CLOUD_CONSEC_FAILS = 0


def _norm_lang(lang: str) -> str:
    return "en" if (lang or "en").lower().startswith("en") else "zh"


def norm_text_for_bank(raw: str) -> str:
    s = (raw or "").replace("\r", " ").replace("\n", " ").replace("\t", " ")
    return " ".join(s.split()).strip().lower()


def bank_entry_key(archetype: str, lang: str, raw_text: str) -> str:
    nlang = _norm_lang(lang)
    norm = norm_text_for_bank(raw_text)
    digest = hashlib.sha1(norm.encode("utf-8")).hexdigest()[:20]
    return f"{archetype}|{nlang}|{digest}"


def _candidate_bank_texts(raw_text: str, lang: str, voice_key: str) -> list[str]:
    out: list[str] = []

    def _push(val: str) -> None:
        n = norm_text_for_bank(val)
        if n and n not in out:
            out.append(n)

    vkey = (voice_key or "").strip().lower()
    if vkey in PURE_ANIMAL_KEYS:
        stripped = strip_animal_interjection(raw_text)
        if stripped:
            _push(stripped)
    _push(raw_text)

    for base_sym in list(out):
        sym_clean = base_sym
        for sym in _UI_DECOR_SYMBOLS:
            sym_clean = sym_clean.replace(sym, " ")
        _push(sym_clean)

    for base_s in list(out):
        if "... " in base_s:
            _push(base_s.replace("... ", ". "))
        if ". " in base_s:
            _push(base_s.replace(". ", "... "))
        if "……" in base_s:
            _push(base_s.replace("…… ", "。").replace("……", "。"))
            _push(base_s.replace("…… ", "。 ").replace("……", "。 "))
        if "。" in base_s:
            _push(base_s.replace("。 ", "…… ").replace("。", "…… "))
    return out


def _resolve_voice_bank_dir() -> Path:
    env_dir = os.environ.get("STUDYGAMES_VOICE_BANK_DIR", "").strip()
    if env_dir:
        return Path(env_dir)
    if VOICE_BANK_DIR != _DEFAULT_VOICE_BANK_DIR:
        return VOICE_BANK_DIR
    if CACHE_DIR != _DEFAULT_CACHE_DIR:
        return CACHE_DIR / "voice_bank_v10"
    return VOICE_BANK_DIR


def _reload_voice_bank_manifest(force: bool = False) -> tuple[Path, dict[str, Any]]:
    global _VOICE_BANK_MANIFEST_PATH, _VOICE_BANK_MTIME_NS, _VOICE_BANK_ENTRIES
    bank_dir = _resolve_voice_bank_dir()
    mpath = bank_dir / "manifest.json"
    with _VOICE_BANK_LOCK:
        if not mpath.is_file():
            if force or _VOICE_BANK_MANIFEST_PATH != mpath:
                _VOICE_BANK_MANIFEST_PATH = mpath
                _VOICE_BANK_MTIME_NS = -1
                _VOICE_BANK_ENTRIES = {}
            return bank_dir, _VOICE_BANK_ENTRIES
        try:
            st_ns = mpath.stat().st_mtime_ns
        except OSError:
            return bank_dir, _VOICE_BANK_ENTRIES
        if not force and _VOICE_BANK_MANIFEST_PATH == mpath and _VOICE_BANK_MTIME_NS == st_ns and _VOICE_BANK_ENTRIES:
            return bank_dir, _VOICE_BANK_ENTRIES
        try:
            parsed = json.loads(mpath.read_text(encoding="utf-8"))
        except Exception:
            return bank_dir, _VOICE_BANK_ENTRIES
        if not isinstance(parsed, dict):
            return bank_dir, _VOICE_BANK_ENTRIES
        if isinstance(parsed.get("entries"), dict):
            entries = parsed["entries"]
        elif isinstance(parsed.get("items"), dict):
            entries = parsed["items"]
        else:
            entries = {k: v for k, v in parsed.items() if isinstance(k, str) and "|" in k}
        _VOICE_BANK_MANIFEST_PATH = mpath
        _VOICE_BANK_MTIME_NS = st_ns
        _VOICE_BANK_ENTRIES = entries
        return bank_dir, _VOICE_BANK_ENTRIES


def find_prebaked_voice_clip(
    text: str,
    lang: str = "en",
    voice_hint: str = "warm",
    speed_mode: str = "natural",
) -> dict[str, Any]:
    smode = normalize_speed_mode(speed_mode)
    prof = resolve_voice_profile(voice_hint)
    arch = str(prof["profile_id"])
    voice_key = str(prof["voice_key"])
    nlang = _norm_lang(lang)
    cleaned = (text or "").strip()
    if not cleaned:
        return {"hit": False, "path": "", "archetype": arch, "speed_mode": smode, "duration_sec": 0.0}

    bank_dir, entries = _reload_voice_bank_manifest(False)
    if not entries:
        return {"hit": False, "path": "", "archetype": arch, "speed_mode": smode, "duration_sec": 0.0}

    for cand in _candidate_bank_texts(cleaned, nlang, voice_key):
        key = bank_entry_key(arch, nlang, cand)
        rec = entries.get(key)
        if rec is None:
            continue
        rel_path = ""
        dur_sec = 0.0
        if isinstance(rec, str):
            rel_path = rec
        elif isinstance(rec, dict):
            if smode == "slow":
                rel_path = str(
                    rec.get("slow")
                    or rec.get("clip_slow")
                    or rec.get("slow_path")
                    or rec.get("natural")
                    or rec.get("path")
                    or ""
                )
                if "slow_duration_sec" in rec:
                    dur_sec = float(rec.get("slow_duration_sec") or 0.0)
                elif "duration_slow_sec" in rec:
                    dur_sec = float(rec.get("duration_slow_sec") or 0.0)
                else:
                    dur_sec = float(rec.get("duration_sec") or 0.0) * 1.25
            else:
                rel_path = str(
                    rec.get("natural")
                    or rec.get("clip")
                    or rec.get("natural_path")
                    or rec.get("path")
                    or ""
                )
                dur_sec = float(rec.get("duration_sec") or rec.get("natural_duration_sec") or 0.0)
        if not rel_path:
            continue
        cand_path = Path(rel_path)
        abs_path = cand_path if cand_path.is_absolute() else (bank_dir / cand_path).resolve()
        if abs_path.is_file():
            return {
                "hit": True,
                "key": key,
                "path": str(abs_path),
                "archetype": arch,
                "speed_mode": smode,
                "duration_sec": dur_sec,
            }

    return {"hit": False, "path": "", "archetype": arch, "speed_mode": smode, "duration_sec": 0.0}


def _serve_prebaked_voice_bank_sync(
    cleaned: str,
    lang: str,
    profile: dict[str, Any],
    raw_text: str = "",
) -> dict[str, Any] | None:
    smode = normalize_speed_mode(str(profile.get("speed_mode", "natural")))
    voice_key = str(profile["voice_key"])
    hit: dict[str, Any] = {"hit": False}
    if raw_text and raw_text != cleaned:
        hit = find_prebaked_voice_clip(raw_text, lang, voice_key, smode)
    if not hit.get("hit"):
        hit = find_prebaked_voice_clip(cleaned, lang, voice_key, smode)
    if not hit.get("hit"):
        return None
    src_path = Path(str(hit["path"]))
    arch = str(hit["archetype"])
    bank_wav = _cache_path(f"{hit['key']}|{src_path.name}", lang, voice_key, "vbank10", smode)
    if _valid_wav(bank_wav):
        return _build_response(
            bank_wav,
            cached=True,
            engine="local_llm_voice_bank",
            profile=profile,
            voice_id=f"voice_bank_v10:{arch}",
            speed_mode=smode,
        )
    staging = _staging_path(bank_wav)
    try:
        raw_bytes = src_path.read_bytes()
        if _decode_encoded_audio_to_wav(raw_bytes, staging, sample_rate=24000) and _publish_audio(staging, bank_wav):
            return _build_response(
                bank_wav,
                cached=False,
                engine="local_llm_voice_bank",
                profile=profile,
                voice_id=f"voice_bank_v10:{arch}",
                speed_mode=smode,
            )
    except Exception:
        return None
    finally:
        staging.unlink(missing_ok=True)
    return None


def normalize_speed_mode(speed_mode: str | None) -> str:
    return "slow" if str(speed_mode or "").strip().lower() == "slow" else "natural"


def _apply_speed_mode(profile: dict[str, Any], speed_mode: str | None) -> dict[str, Any]:
    smode = normalize_speed_mode(speed_mode)
    spec = dict(profile)
    spec["speed_mode"] = smode
    base_rate = int(spec.get("rate_pct", 0))
    base_pace = float(spec.get("piper_pace", 1.18))
    if smode == "slow":
        spec["rate_pct"] = max(-35, min(10, base_rate - 14))
        spec["piper_pace"] = round(min(1.55, base_pace * 1.22), 3)
    else:
        spec["rate_pct"] = max(-35, min(10, base_rate))
        spec["piper_pace"] = round(min(1.55, base_pace), 3)
    return spec


def prepare_child_friendly_text(text: str, lang: str, voice_key: str) -> str:
    """Strip pure-animal cries and add gentle breathing cadence between vocab word and sentence."""
    out = " ".join((text or "").strip().split())
    if not out:
        return ""
    vkey = (voice_key or "").strip().lower()
    if vkey in PURE_ANIMAL_KEYS:
        out = strip_animal_interjection(out)
        if not out:
            return ""

    nlang = _norm_lang(lang)
    if nlang == "en":
        match = _SINGLE_WORD_SENTENCE_EN_RE.match(out)
        if match and match.group(1).lower() not in _HONORIFIC_ABBREVS:
            out = f"{match.group(1)}... {match.group(2)}"
    else:
        match_zh = _SINGLE_WORD_SENTENCE_ZH_RE.match(out)
        if match_zh:
            out = f"{match_zh.group(1)}…… {match_zh.group(2)}"
    return out


def _cache_path(
    text: str,
    lang: str,
    voice_key: str,
    tier: str,
    speed_mode: str = "natural",
) -> Path:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    nlang = _norm_lang(lang)
    smode = normalize_speed_mode(speed_mode)
    safe_voice = re.sub(r"[^a-z0-9_]+", "_", voice_key.lower()).strip("_")[:28] or "warm"
    digest = hashlib.sha256(
        f"v90|{tier}|{smode}|{nlang}|{voice_key}|{text.strip()}".encode("utf-8")
    ).hexdigest()[:22]
    return CACHE_DIR / f"tts_v90_{tier}_{smode}_{nlang}_{safe_voice}_{digest}.wav"


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


def _split_piper_breathing_segments(text: str, nlang: str) -> list[str]:
    """Split ellipsis pauses (`...` / `……`) into separate segments so Piper inserts real silence."""
    raw_parts = [seg.strip() for seg in re.split(r"(?:\.{2,}|…+)\s*", text) if seg.strip()]
    if not raw_parts:
        return [text]
    punct_end = ("." if nlang == "en" else "。")
    out: list[str] = []
    for seg in raw_parts:
        if seg[-1] not in ".!?。！？；;":
            out.append(seg + punct_end)
        else:
            out.append(seg)
    return out


def build_piper_synthesis_config(
    *,
    speaker_id: int | None,
    length_scale: float,
    speed_mode: str = "natural",
) -> Any:
    from piper.config import SynthesisConfig

    pause_sec = (
        PIPER_SENTENCE_SILENCE_SLOW
        if normalize_speed_mode(speed_mode) == "slow"
        else PIPER_SENTENCE_SILENCE_NATURAL
    )
    kwargs: dict[str, Any] = {
        "speaker_id": int(speaker_id) if speaker_id is not None else None,
        "length_scale": length_scale,
        "noise_scale": PIPER_NOISE_SCALE,
        "noise_w_scale": PIPER_NOISE_W_SCALE,
    }
    params = inspect.signature(SynthesisConfig).parameters
    if "sentence_silence" in params:
        kwargs["sentence_silence"] = pause_sec
    return SynthesisConfig(**kwargs)


def synthesize_piper_sync(
    text: str,
    lang: str,
    target: Path,
    profile: dict[str, Any] | None = None,
    speed_mode: str | None = None,
) -> tuple[bool, str]:
    spec = dict(profile) if profile is not None else resolve_voice_profile("warm")
    if speed_mode is not None and spec.get("speed_mode") != normalize_speed_mode(speed_mode):
        spec = _apply_speed_mode(spec, speed_mode)
    smode = normalize_speed_mode(str(spec.get("speed_mode", "natural")))

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

    pace = float(spec.get("piper_pace", 1.18))
    pitch_shift = float(spec.get("piper_pitch_shift", 1.0))
    effective_length = max(0.72, min(1.85, pace * pitch_shift))
    pause_sec = PIPER_SENTENCE_SILENCE_SLOW if smode == "slow" else PIPER_SENTENCE_SILENCE_NATURAL

    def _run_model(v_obj: Any, spk: Any, tag_base: str) -> tuple[bool, str]:
        syn_cfg = build_piper_synthesis_config(
            speaker_id=int(spk) if spk is not None else None,
            length_scale=effective_length,
            speed_mode=smode,
        )
        buf = io.BytesIO()
        with wave.open(buf, "wb") as wf:
            if hasattr(v_obj, "synthesize"):
                segments = _split_piper_breathing_segments(text, nlang)
                chunks = []
                for seg in segments:
                    chunks.extend(v_obj.synthesize(seg, syn_config=syn_cfg))
                if not chunks:
                    return False, ""
                sr_model = chunks[0].sample_rate
                sw = chunks[0].sample_width
                ch_count = chunks[0].sample_channels
                wf.setframerate(sr_model)
                wf.setsampwidth(sw)
                wf.setnchannels(ch_count)
                silence_frames = max(0, int(round(sr_model * pause_sec * pitch_shift)))
                silence_pcm = b"\x00" * (silence_frames * sw * ch_count)
                for idx, chunk in enumerate(chunks):
                    if idx > 0 and silence_pcm:
                        wf.writeframes(silence_pcm)
                    wf.writeframes(chunk.audio_int16_bytes)
            else:
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
        rate_val = max(-35, min(10, int(profile.get("rate_pct", 0))))
        rate_str = format_edge_rate(rate_val)
        pitch_str = format_edge_pitch(int(profile.get("pitch_hz", 0)))

        async def _fetch_mp3() -> bytes:
            comm = edge_tts.Communicate(text, voice_name, rate=rate_str, pitch=pitch_str)
            mp3_buf = bytearray()
            async for chunk in comm.stream():
                if chunk.get("type") == "audio":
                    mp3_buf.extend(chunk["data"])
            return bytes(mp3_buf)

        mp3_bytes = await asyncio.wait_for(_fetch_mp3(), timeout=8.5)
        if len(mp3_bytes) < 200:
            _CLOUD_CONSEC_FAILS += 1
            if _CLOUD_CONSEC_FAILS >= CLOUD_FAIL_BACKOFF_THRESHOLD:
                _CLOUD_BACKOFF_UNTIL = time.monotonic() + 20.0
            return False, ""
        if _decode_encoded_audio_to_wav(mp3_bytes, target, sample_rate=22050):
            _CLOUD_CONSEC_FAILS = 0
            _CLOUD_BACKOFF_UNTIL = 0.0
            return True, f"{voice_name}({rate_str},{pitch_str})"
        return False, ""
    except Exception:
        _CLOUD_CONSEC_FAILS += 1
        if _CLOUD_CONSEC_FAILS >= CLOUD_FAIL_BACKOFF_THRESHOLD:
            _CLOUD_BACKOFF_UNTIL = time.monotonic() + 20.0
        return False, ""


async def _try_commercial_cloud_tts(
    text: str,
    lang: str,
    target: Path,
    profile: dict[str, Any],
) -> tuple[bool, str]:
    load_dotenv_if_changed()
    enable_oai_tts = os.environ.get("OPENAI_ENABLE_TTS", "").strip().lower() in ("1", "true", "yes", "on")
    api_key = (
        os.environ.get("OPENAI_TTS_API_KEY")
        or os.environ.get("STUDYGAMES_CLOUD_TTS_KEY")
        or (os.environ.get("OPENAI_API_KEY") if enable_oai_tts else "")
        or ""
    ).strip()
    if not api_key:
        return False, ""
    base_url = os.environ.get("OPENAI_TTS_BASE_URL") or os.environ.get("AI_COMPANION_BASE_URL") or "https://api.openai.com/v1"
    voice_name = str(profile.get("openai_voice") or ("nova" if _norm_lang(lang) == "en" else "shimmer"))
    model_name = os.environ.get("OPENAI_TTS_MODEL", "tts-1")
    proxy_url = os.environ.get("OPENAI_PROXY", "").strip() or None
    smode = normalize_speed_mode(str(profile.get("speed_mode", "natural")))
    oai_speed = 0.76 if smode == "slow" else 0.88
    try:
        async with httpx.AsyncClient(timeout=6.5, proxy=proxy_url) as client:
            resp = await client.post(
                f"{base_url.rstrip('/')}/audio/speech",
                headers={"Authorization": f"Bearer {api_key}"},
                json={
                    "model": model_name,
                    "voice": voice_name,
                    "response_format": "wav",
                    "speed": oai_speed,
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
    speed_mode: str | None = None,
) -> dict[str, Any]:
    raw = target.read_bytes()
    smode = normalize_speed_mode(speed_mode or str(profile.get("speed_mode", "natural")))
    return {
        "ok": True,
        "cached": cached,
        "engine": engine,
        "speed_mode": smode,
        "voice_profile": str(profile["profile_id"]),
        "voice_key": str(profile["voice_key"]),
        "voice_label_zh": str(profile["label_zh"]),
        "voice_id": voice_id,
        "audio_path": str(target),
        "wav_base64": base64.b64encode(raw).decode("ascii") if len(raw) < 950_000 else "",
    }


def _valid_wav(path: Path) -> bool:
    """Only complete PCM audio can be served as a cache hit."""
    try:
        with wave.open(str(path), "rb") as reader:
            frames = reader.getnframes()
            return (
                reader.getsampwidth() == 2
                and reader.getnchannels() in (1, 2)
                and reader.getframerate() > 0
                and frames > 0
                and len(reader.readframes(frames)) == frames * reader.getnchannels() * 2
            )
    except (OSError, EOFError, wave.Error):
        return False


def _staging_path(target: Path) -> Path:
    handle, name = tempfile.mkstemp(prefix=".tts-", suffix=".wav", dir=target.parent)
    os.close(handle)
    return Path(name)


def _publish_audio(staging: Path, target: Path) -> bool:
    if not _valid_wav(staging):
        return False
    staging.replace(target)
    return True


async def synthesize_speech(
    text: str,
    lang: str = "en",
    voice_hint: str = "warm",
    prefer_offline: bool = False,
    speed_mode: str = "natural",
) -> dict[str, Any]:
    raw_cleaned = " ".join((text or "").strip().split())[:260]
    if not raw_cleaned:
        return {"ok": False, "error": "empty_text"}

    smode = normalize_speed_mode(speed_mode)
    base_profile = resolve_voice_profile(voice_hint)
    profile = _apply_speed_mode(base_profile, smode)
    voice_key = str(profile["voice_key"])
    cleaned = prepare_child_friendly_text(raw_cleaned, lang, voice_key)
    if not cleaned:
        # Pure animal cry with no trailing narration sentence: return clean silent WAV
        # so human TTS never awkwardly pronounces "Woof woof!" or "Meow!".
        silent_target = _cache_path("__animal_cry_only__", lang, voice_key, "silence", smode)
        if not _valid_wav(silent_target):
            staging = _staging_path(silent_target)
            try:
                _write_pcm16_wav(b"\x00\x00" * 3300, 22050, staging)
                _publish_audio(staging, silent_target)
            finally:
                staging.unlink(missing_ok=True)
        return _build_response(
            silent_target,
            cached=True,
            engine="animal_interjection_skipped",
            profile=profile,
            voice_id="animal_sfx_only",
            speed_mode=smode,
        )

    tts_mode = os.environ.get("STUDYGAMES_TTS_MODE", "cloud_first").strip().lower()
    offline_only = prefer_offline or (tts_mode == "offline")

    cloud_target = _cache_path(cleaned, lang, voice_key, "cloud", smode)
    local_target = _cache_path(cleaned, lang, voice_key, "local", smode)
    # Multiple playback requests for one phrase share work. Cancelling a client
    # cannot cancel audio still needed by another client or expose a partial WAV.
    raw_untruncated = (text or "").strip()
    key = (asyncio.get_running_loop(), cloud_target, offline_only)
    task = _INFLIGHT.get(key)
    if task is None:
        task = asyncio.create_task(
            _synthesize_speech_once(
                cleaned, lang, profile, cloud_target, local_target, offline_only, raw_untruncated
            )
        )
        _INFLIGHT[key] = task

        def finished(done: asyncio.Task) -> None:
            if _INFLIGHT.get(key) is done:
                _INFLIGHT.pop(key, None)
            if not done.cancelled():
                done.exception()  # Also retrieve errors when every caller disconnected.

        task.add_done_callback(finished)
    return await asyncio.shield(task)


async def _synthesize_speech_once(
    cleaned: str,
    lang: str,
    profile: dict[str, Any],
    cloud_target: Path,
    local_target: Path,
    offline_only: bool,
    raw_text: str = "",
) -> dict[str, Any]:
    global _CLOUD_BACKOFF_UNTIL, _CLOUD_CONSEC_FAILS

    # -1. Instant 0-VRAM hit on pre-baked V10 Local LLM Voice Bank (works offline & online!)
    prebaked_resp = await asyncio.to_thread(_serve_prebaked_voice_bank_sync, cleaned, lang, profile, raw_text)
    if prebaked_resp is not None:
        return prebaked_resp

    # 0. Instant hit on previously cached hyper-realistic cloud voice (works even offline!)
    if not offline_only and _valid_wav(cloud_target):
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
    if not offline_only and time.monotonic() >= _CLOUD_BACKOFF_UNTIL:
        try:
            result = await asyncio.wait_for(
                _synthesize_cloud_speech(cleaned, lang, profile, cloud_target),
                timeout=CLOUD_ATTEMPT_BUDGET_SECONDS,
            )
            if result is not None:
                _CLOUD_CONSEC_FAILS = 0
                _CLOUD_BACKOFF_UNTIL = 0.0
                return result
        except asyncio.TimeoutError:
            _CLOUD_CONSEC_FAILS += 1
            if _CLOUD_CONSEC_FAILS >= CLOUD_FAIL_BACKOFF_THRESHOLD:
                _CLOUD_BACKOFF_UNTIL = time.monotonic() + 20.0

    # Model loading, phonemization, inference and SAPI subprocesses all block.
    # Keep them off the ASGI loop, and serialize access to the shared Piper bank.
    return await asyncio.to_thread(_synthesize_local_speech, cleaned, lang, local_target, profile)


async def _synthesize_cloud_speech(
    cleaned: str, lang: str, profile: dict[str, Any], cloud_target: Path
) -> dict[str, Any] | None:
    staging = _staging_path(cloud_target)
    try:
        comm_ok, comm_voice = await _try_commercial_cloud_tts(cleaned, lang, staging, profile)
        if comm_ok and _publish_audio(staging, cloud_target):
            return _build_response(
                cloud_target, cached=False, engine="cloud_neural_tts", profile=profile, voice_id=comm_voice
            )

        edge_ok, edge_voice = await _try_edge_neural_tts(cleaned, lang, staging, profile)
        if edge_ok and _publish_audio(staging, cloud_target):
            return _build_response(
                cloud_target, cached=False, engine="edge_neural_tts", profile=profile, voice_id=edge_voice
            )
    finally:
        staging.unlink(missing_ok=True)
    return None


def _synthesize_local_speech(
    cleaned: str, lang: str, local_target: Path, profile: dict[str, Any]
) -> dict[str, Any]:
    with _LOCAL_SYNTHESIS_LOCK:
        return _synthesize_local_locked(cleaned, lang, local_target, profile)


def _synthesize_local_locked(
    cleaned: str, lang: str, local_target: Path, profile: dict[str, Any]
) -> dict[str, Any]:
    smode = normalize_speed_mode(str(profile.get("speed_mode", "natural")))
    voice_key = str(profile["voice_key"])

    # 2. Local Offline Multi-Model Disk Cache
    if _valid_wav(local_target):
        nlang = _norm_lang(lang)
        v_id = str(profile["piper_en_model"] if nlang == "en" else profile["piper_zh_model"]).removesuffix(".onnx")
        return _build_response(
            local_target,
            cached=True,
            engine="neural_disk_cache",
            profile=profile,
            voice_id=v_id,
        )

    staging = _staging_path(local_target)
    try:
        # 3. Local Offline Multi-Model Piper VITS Neural ONNX
        piper_ok, piper_voice = synthesize_piper_sync(cleaned, lang, staging, profile)
        if piper_ok and _publish_audio(staging, local_target):
            return _build_response(
                local_target, cached=False, engine="piper_neural_onnx", profile=profile, voice_id=piper_voice
            )

        # Fallbacks use distinct cache tiers: a chime must never become a
        # "neural speech" cache hit or prevent retrying an installed voice pack.
        sapi_gender = str(profile.get("sapi_gender", "Female"))
        sapi_target = _cache_path(cleaned, lang, voice_key, "sapi", smode)
        if _valid_wav(sapi_target):
            return _build_response(
                sapi_target, cached=True, engine="windows_sapi_voice", profile=profile, voice_id=f"sapi:{sapi_gender}"
            )
        if _try_windows_sapi_wav(cleaned, lang, staging, sapi_gender, smode) and _publish_audio(staging, sapi_target):
            return _build_response(
                sapi_target, cached=False, engine="windows_sapi_voice", profile=profile, voice_id=f"sapi:{sapi_gender}"
            )

        chime_target = _cache_path(cleaned, lang, voice_key, "chime", smode)
        _write_chime_wav(cleaned, staging)
        if _publish_audio(staging, chime_target):
            return _build_response(
                chime_target, cached=False, engine="melodic_chime_fallback", profile=profile, voice_id="marimba_chime"
            )
        return {"ok": False, "error": "audio_unavailable"}
    finally:
        staging.unlink(missing_ok=True)


def _try_windows_sapi_wav(
    text: str,
    lang: str,
    target: Path,
    preferred_gender: str = "Female",
    speed_mode: str = "natural",
) -> bool:
    if os.name != "nt":
        return False
    try:
        culture_prefix = _norm_lang(lang)
        sapi_rate = -3 if normalize_speed_mode(speed_mode) == "slow" else -2
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
            f"$s.Rate = {sapi_rate}; $s.Volume = 95; "
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


def _recording_measurements(raw: bytes) -> tuple[float, int]:
    with wave.open(io.BytesIO(raw), "rb") as reader:
        channels, rate, frames = reader.getnchannels(), reader.getframerate(), reader.getnframes()
        if reader.getsampwidth() != 2 or channels not in (1, 2) or not 8000 <= rate <= 96000 or frames > rate * 30:
            raise ValueError("unsupported_audio")
        pcm = reader.readframes(frames)
    if not frames or len(pcm) != frames * channels * 2:
        raise ValueError("incomplete_audio")
    energy = sum((sample[0] / 32768.0) ** 2 for sample in struct.iter_unpack("<h", pcm))
    return math.sqrt(energy / (frames * channels)), round(frames * 1000 / rate)


def evaluate_follow_along(payload: dict[str, Any]) -> dict[str, Any]:
    # The endpoint runs in a worker; the shared model must still be loaded once.
    with _RECOGNITION_LOCK:
        return _evaluate_follow_along(payload)


def _evaluate_follow_along(payload: dict[str, Any]) -> dict[str, Any]:
    """Tolerant, zero-stress speaking recognition & encouragement for 7-12yo learners."""
    target_text = " ".join(str(payload.get("target_text") or "Hello!").strip().split())[:120]
    target_norm = _normalize_words(target_text)
    mode = str(payload.get("mode") or "voice").strip().lower()
    try:
        rms_energy = float(payload.get("rms_energy", 0.0))
        duration_ms = int(payload.get("duration_ms", 0))
    except (TypeError, ValueError, OverflowError):
        return {"ok": False, "error": "invalid_audio_measurements"}
    if not math.isfinite(rms_energy) or not 0.0 <= rms_energy <= 1.0 or not 0 <= duration_ms <= 30000:
        return {"ok": False, "error": "invalid_audio_measurements"}
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
            "similarity": None,
            "cheer_badge": "🌿 安心默读星",
            "reply_en": f'Listening in your heart is great too! "{target_text}" stays with you!',
            "reply_zh": f"在心里轻轻默读「{target_text}」也很棒！不着急，想开口时随时都可以 ✨",
        }

    transcript = ""
    asr_used = False
    if wav_b64:
        try:
            if len(wav_b64) > (MAX_RECORDING_BYTES + 2) // 3 * 4:
                return {"ok": False, "error": "audio_too_large"}
            raw = base64.b64decode(wav_b64, validate=True)
            if len(raw) > MAX_RECORDING_BYTES:
                return {"ok": False, "error": "audio_too_large"}
            # Header chunks, sample rate and channel count vary between devices.
            # Measured audio replaces advisory metadata, including for silence.
            rms_energy, duration_ms = _recording_measurements(raw)
            if rms_energy >= 0.008 and target_norm:
                transcript = _transcribe_wav_offline(raw, target_norm)
                if _get_vosk_model() is not None:
                    asr_used = True
        except (ValueError, TypeError, EOFError, wave.Error, struct.error):
            return {"ok": False, "error": "invalid_audio"}

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
                "similarity_kind": "transcript_text",
                "cheer_badge": "🏆 词语小星星",
                "reply_en": f'I heard "{transcript}"! Let\'s say "{target_text}" together again!',
                "reply_zh": f"听到了「{transcript}」！我们再一起读一遍「{target_text}」吧 🌟",
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
                "similarity_kind": "transcript_text",
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
            "similarity_kind": "transcript_text",
            "cheer_badge": "💛 温暖领读星",
            "reply_en": f'Brave voice! Let\'s say "{target_text}" slowly together once more!',
            "reply_zh": f"听到你响亮的声音啦！不扣分，来跟着伙伴慢一点再读一遍：「{target_text}」💛",
        }

    if rms_energy >= 0.008 and duration_ms > 0:
        return {
            "ok": True,
            "mode": "voice",
            "target_text": target_text,
            "voice_detected": True,
            "asr_engine": "envelope_fallback",
            "transcript": "",
            "match_tier": "confident_voice",
            "similarity": None,
            "cheer_badge": "🌟 自信开口星",
            "reply_en": f'I heard your voice! Let\'s listen to "{target_text}" and try it together!',
            "reply_zh": f"听到你的声音啦！一起听听「{target_text}」，再轻松试一试吧 🌟",
        }

    return {
        "ok": True,
        "mode": "voice",
        "target_text": target_text,
        "voice_detected": False,
        "asr_engine": "envelope_fallback",
        "transcript": "",
        "match_tier": "no_voice",
        "similarity": None,
        "cheer_badge": "🌿 慢慢来就好",
        "reply_en": f'No hurry! Listen to "{target_text}" or read quietly with me.',
        "reply_zh": f"不着急，先听听「{target_text}」，也可以在心里一起读 🌿",
    }
