#!/usr/bin/env python3
"""V10 Local GPU Voice Design Studio & Offline Pre-Baked Voice Bank Generator.

Runs on local RTX 4070 using `F:\\LLM\\Qwen3-TTS\\.venv\\Scripts\\python.exe` and
`F:\\LLM\\VoxCPM\\runtime\\ffmpeg\\bin\\ffmpeg.exe` without modifying `F:\\LLM\\`.

Pipeline:
  Stage 1: Sculpt 26 Golden Character Voice Anchors (13 archetypes x EN + ZH)
           using `Qwen3-TTS-12Hz-1.7B-VoiceDesign` (`bfloat16`, `sdpa`), validate
           duration/RMS/clipping, save `anchors/<arch>_<lang>.wav` +
           `anchors/anchors_manifest.json`, and fully release `VoiceDesign` VRAM.
  Stage 2: Load `Qwen3-TTS-12Hz-1.7B-Base` (`bfloat16`, `sdpa`), pre-compute
           `create_voice_clone_prompt(..., x_vector_only_mode=False)` once per
           `(archetype, lang)`, synthesize all corpus utterances in length-sorted
           GPU batches, gently trim dead air + peak-normalize to `-2.5 dBFS`,
           encode `clips/<id>.ogg` + pitch-preserving `atempo=0.80` `clips_slow/<id>.ogg`
           via FFmpeg worker threads, and save `manifest.json` incrementally!
"""
from __future__ import annotations

import argparse
import gc
import json
import math
import os
import re
import subprocess
import sys
import time
from concurrent.futures import Future, ThreadPoolExecutor
from pathlib import Path
from typing import Any

# Configure offline & local tool paths BEFORE importing torch / qwen_tts / huggingface
QWEN_ROOT = Path(r"F:\LLM\Qwen3-TTS")
VOXCPM_ROOT = Path(r"F:\LLM\VoxCPM")
FFMPEG_EXE = VOXCPM_ROOT / "runtime" / "ffmpeg" / "bin" / "ffmpeg.exe"
VOICE_DESIGN_DIR = QWEN_ROOT / "models" / "Qwen3-TTS-12Hz-1.7B-VoiceDesign"
BASE_MODEL_DIR = QWEN_ROOT / "models" / "Qwen3-TTS-12Hz-1.7B-Base"

SOX_DIR = QWEN_ROOT / "runtime" / "audio" / "sox-14.4.2"
AUDIO_RUNTIME_DIR = QWEN_ROOT / "runtime" / "audio"

os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["TRANSFORMERS_OFFLINE"] = "1"
os.environ["HF_HUB_DISABLE_TELEMETRY"] = "1"
os.environ["TOKENIZERS_PARALLELISM"] = "false"
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "max_split_size_mb:128"
os.environ["PATH"] = os.pathsep.join(
    [
        str(FFMPEG_EXE.parent),
        str(AUDIO_RUNTIME_DIR),
        str(SOX_DIR),
        os.environ.get("PATH", ""),
    ]
)

import numpy as np  # noqa: E402
import soundfile as sf  # noqa: E402
import torch  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
BANK_DIR = ROOT / "assets" / "voice_bank_v10"
ANCHORS_DIR = BANK_DIR / "anchors"
CLIPS_DIR = BANK_DIR / "clips"
CLIPS_SLOW_DIR = BANK_DIR / "clips_slow"
CORPUS_PATH = BANK_DIR / "corpus.json"
ANCHORS_MANIFEST_PATH = ANCHORS_DIR / "anchors_manifest.json"
CLIP_META_CACHE_PATH = BANK_DIR / "baked_clips_meta.json"
MANIFEST_PATH = BANK_DIR / "manifest.json"

TARGET_SR = 24000
TARGET_PEAK = float(10.0 ** (-2.5 / 20.0))  # -2.5 dBFS (~0.74989)

# 13 Bilingual Golden Character Voice Design Master Specs
GOLDEN_ANCHOR_SPECS: dict[str, dict[str, dict[str, Any]]] = {
    "mother_affectionate": {
        "en": {
            "seed": 1011,
            "ref_text": "Welcome home, sweetie... Come sit on the soft sofa, and tell Mom about your sunny day.",
            "instruct": (
                "A gentle, affectionate young mother in her early thirties speaking lovingly to her child. "
                "Warm, soft, smiling maternal voice, unhurried storybook pace about fifteen percent slower "
                "than broadcast, clear and soothing."
            ),
        },
        "zh": {
            "seed": 2011,
            "ref_text": "欢迎回家呀宝贝，快过来坐到柔软的沙发上，跟妈妈说说今天开心的事吧。",
            "instruct": (
                "温柔慈爱的年轻妈妈声音，三十岁左右，面带微笑地对孩子轻声说话，"
                "音色柔和温暖、充满母爱，语速比播音慢约百分之十五，吐字圆润舒缓。"
            ),
        },
    },
    "father_warm": {
        "en": {
            "seed": 1023,
            "ref_text": "Hey champ, pull up your wooden chair... Let's open this storybook and read it slowly together.",
            "instruct": (
                "A warm, patient, encouraging young father in his thirties reading with his child. "
                "Gentle baritone timbre with a friendly smile, calm and unhurried pace about fifteen percent "
                "slower than normal broadcast, clear articulation."
            ),
        },
        "zh": {
            "seed": 2023,
            "ref_text": "嗨宝贝，把小木椅拉过来坐好，爸爸陪你一起慢慢翻开这本有趣的故事书吧。",
            "instruct": (
                "温暖耐心的年轻爸爸声音，三十多岁温和男中音，带着鼓励的微笑陪孩子读书，"
                "声音醇厚亲切，语速从容放慢约百分之十五，清晰自然。"
            ),
        },
    },
    "teacher_gentle": {
        "en": {
            "seed": 1037,
            "ref_text": "Good morning, class... Please open your English books, and let's read this warm sentence together.",
            "instruct": (
                "A kind, patient elementary school female English teacher in her late twenties. "
                "Bright yet gentle smiling timbre, crystal-clear pronunciation for young learners, "
                "unhurried pace about fifteen percent slower than broadcast."
            ),
        },
        "zh": {
            "seed": 2037,
            "ref_text": "同学们早上好呀，请翻开课桌上的英语书，跟老师一起轻轻读出这个句子吧。",
            "instruct": (
                "亲切耐心的小学年轻女老师声音，二十八岁左右，面带微笑、温柔鼓励，"
                "普通话标准清亮而不刺耳，语速舒缓放慢约百分之十五，适合儿童跟读。"
            ),
        },
    },
    "storyteller": {
        "en": {
            "seed": 1049,
            "ref_text": "Once upon a sunny morning... little Kitty curled up softly in a warm patch of golden light.",
            "instruct": (
                "An expressive, dreamy picture-book narrator sister reading a cozy fairy tale to children. "
                "Warm, lyrical, smiling young female voice with gentle breathing pauses and an unhurried, "
                "soothing storybook cadence."
            ),
        },
        "zh": {
            "seed": 2049,
            "ref_text": "在暖洋洋的晨光里，可爱的小猫咪蜷在柔软的垫子上，安静地听着故事呢。",
            "instruct": (
                "生动温柔的绘本故事姐姐声音，年轻甜美又富有画面感，像在给小朋友面对面讲童话故事，"
                "轻柔微笑，语速舒缓，停顿自然温暖。"
            ),
        },
    },
    "boy_sunny": {
        "en": {
            "seed": 1061,
            "ref_text": "Hey buddy, nice to see you at school! Let's pass the football and play on the green grass!",
            "instruct": (
                "A cheerful, friendly ten-year-old elementary school boy speaking happily to his classmate. "
                "Genuine youthful boy timbre, bright and sunny smile, clear and unhurried child-friendly "
                "pace without shouting."
            ),
        },
        "zh": {
            "seed": 2061,
            "ref_text": "嘿好伙伴，在学校见到你真开心！下课后我们一起去绿茵操场上踢足球吧！",
            "instruct": (
                "阳光开朗的十岁小学小男孩声音，清脆朝气的少年童声，热情友善、面带笑容，"
                "吐字清晰自然，语速适中偏舒缓，不尖锐不吵闹。"
            ),
        },
    },
    "girl_bright": {
        "en": {
            "seed": 1073,
            "ref_text": "Hi my friend, look at the colourful flowers! Let's draw a bright picture and learn English together!",
            "instruct": (
                "A sweet, lively nine-year-old elementary school girl chatting warmly with her best friend. "
                "Clear, bright, smiling young girl voice, gentle and unhurried storybook rhythm, crisp pronunciation."
            ),
        },
        "zh": {
            "seed": 2073,
            "ref_text": "嗨好朋友，快看那边五颜六色的花朵！我们一起画画、一起开心学英语吧！",
            "instruct": (
                "元气甜美的九岁小学小女孩声音，清脆干净的女童音色，带着开心纯真的微笑，"
                "语速温和从容、吐字清楚好听。"
            ),
        },
    },
    "uncle_warm": {
        "en": {
            "seed": 1087,
            "ref_text": "Good morning, little neighbour... Fresh apple cakes and warm bread are waiting right out of the oven.",
            "instruct": (
                "A jolly, big-hearted village baker uncle in his forties. Rich, rounded, cozy deep male voice "
                "full of warmth and hospitality, smiling kindly, relaxed and unhurried pace."
            ),
        },
        "zh": {
            "seed": 2087,
            "ref_text": "早上好呀小邻居，刚出炉的热面包和金黄苹果蛋糕，正冒着甜甜的香气呢。",
            "instruct": (
                "憨厚温暖的面包房大叔声音，四十多岁圆润醇厚的暖男低音，热情慈祥、笑呵呵地招呼小朋友，"
                "语速慢悠悠、让人倍感安心。"
            ),
        },
    },
    "elder_wise": {
        "en": {
            "seed": 1093,
            "ref_text": "Welcome to our quiet reading hall, young explorer... Every book holds a bright star of wisdom.",
            "instruct": (
                "A kind, wise, grandfatherly school principal and librarian in his sixties. "
                "Gentle, resonant, scholarly older male voice, calm and patient smile, slow and soothing "
                "storytelling cadence."
            ),
        },
        "zh": {
            "seed": 2093,
            "ref_text": "欢迎来到静谧书屋呀小探索家，每一本故事书里，都藏着闪闪发光的智慧呢。",
            "instruct": (
                "慈祥睿智的老爷爷与老校长声音，六十岁左右温和儒雅的长辈男声，眼神慈爱、"
                "声音沉稳柔和，语速缓慢从容，充满书卷气。"
            ),
        },
    },
    "grandma_warm": {
        "en": {
            "seed": 1103,
            "ref_text": "Come into the sunny greenhouse, dear child... Look how softly the little yellow flowers are blooming.",
            "instruct": (
                "A loving, gentle grandmother in her sixties tending a flower garden. "
                "Soft, affectionate, comforting older female voice with a warm smile and a slow, "
                "unhurried lullaby-like storybook pace."
            ),
        },
        "zh": {
            "seed": 2103,
            "ref_text": "快进阳光花房来吧好孩子，看看这些金黄色的小花朵，开得多么温柔漂亮呀。",
            "instruct": (
                "慈爱温和的花婆婆奶奶声音，六十岁左右亲切慈祥的长辈女声，带着疼爱孩子的微笑，"
                "声音轻柔舒缓，慢条斯理、温暖人心。"
            ),
        },
    },
    "artisan_male": {
        "en": {
            "seed": 1117,
            "ref_text": "Welcome to our sunny island workshop... Take a close look at the bright stars and handmade crafts.",
            "instruct": (
                "A friendly, upbeat young male island craftsman in his late twenties. "
                "Warm, clear, approachable tenor voice with an encouraging smile, steady and unhurried "
                "pace for children."
            ),
        },
        "zh": {
            "seed": 2117,
            "ref_text": "欢迎来到阳光海岛手工坊，快走近看看这些闪亮的星星和精致的小手作吧。",
            "instruct": (
                "阳光爽朗的年轻男手艺人声音，二十多岁干净温暖的青年男中音，乐观亲切、面带微笑，"
                "语速平稳舒缓，吐字清晰有力。"
            ),
        },
    },
    "artisan_female": {
        "en": {
            "seed": 1129,
            "ref_text": "Step into our cozy craft studio, friend... Let's light a warm lantern and build something wonderful.",
            "instruct": (
                "A cheerful, capable young female artisan and coach in her late twenties. "
                "Warm mezzo-soprano voice, lively yet gentle smile, crisp articulation and unhurried "
                "child-friendly rhythm."
            ),
        },
        "zh": {
            "seed": 2129,
            "ref_text": "欢迎来到温暖的手作工坊呀好朋友，我们一起点亮小灯笼，动手做件有趣的作品吧。",
            "instruct": (
                "明快干练又温柔的年轻女达人声音，二十多岁清亮温和的青年女中音，充满活力与亲和力，"
                "面带微笑，语速从容清晰。"
            ),
        },
    },
    "mascot_dino": {
        "en": {
            "seed": 1151,
            "ref_text": "Hello little friend, I am Dino! Let's count the shining stars and read fun words together!",
            "instruct": (
                "An adorable, playful baby dinosaur cartoon mascot friend for kids. "
                "Cute, rounded, bubbly childlike voice full of wonder and friendliness, soft and pleasant "
                "without harsh squeaking, unhurried pace."
            ),
        },
        "zh": {
            "seed": 2151,
            "ref_text": "嗨好朋友，我是可爱的小恐龙！我们一起数一数亮晶晶的星星，慢慢读英语吧！",
            "instruct": (
                "呆萌可爱的卡通小恐龙伙伴声音，圆润讨喜、充满好奇心的童趣萌音，柔和欢快而不刺耳，"
                "带着微笑陪小朋友慢速学说话。"
            ),
        },
    },
    "mascot_parrot": {
        "en": {
            "seed": 1163,
            "ref_text": "Hello sunny friend, what a nice hat! Follow me closely, and let's say each word with a smile!",
            "instruct": (
                "A cheerful, musical little parrot mascot companion for children. "
                "Bright, bouncy, playful young cartoon voice with a happy smile, crisp syllable "
                "pronunciation and friendly unhurried rhythm."
            ),
        },
        "zh": {
            "seed": 2163,
            "ref_text": "你好呀阳光小宝贝，你的小帽子真好看！跟着小鹦鹉一起微笑着大声读出来吧！",
            "instruct": (
                "俏皮灵动的卡通小鹦鹉伙伴声音，清脆欢快、富有音乐节奏感的萌趣童声，甜美讨喜不尖锐，"
                "吐字格外清楚，语速温和易跟读。"
            ),
        },
    },
}


def setup_cuda_fastpaths() -> None:
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True
    if hasattr(torch.backends.cuda, "enable_flash_sdp"):
        torch.backends.cuda.enable_flash_sdp(True)
    if hasattr(torch.backends.cuda, "enable_mem_efficient_sdp"):
        torch.backends.cuda.enable_mem_efficient_sdp(True)


def upgrade_tokenizer_attn(tts_wrapper: Any) -> None:
    """Switch Qwen3TTSTokenizerV2 internal model to SDPA in-memory if supported."""
    try:
        st_model = getattr(tts_wrapper.model.speech_tokenizer, "model", None)
        if st_model is not None and hasattr(st_model, "set_attn_implementation"):
            st_model.set_attn_implementation("sdpa")
    except Exception:
        pass


def trim_and_normalize_wav(
    raw_wav: np.ndarray,
    sr: int,
    lead_ms: float = 60.0,
    tail_ms: float = 120.0,
    min_dur_sec: float = 0.42,
) -> tuple[np.ndarray, dict[str, float]]:
    """Gently trim dead leading/trailing silence, apply soft cosine fades, and peak-normalize to -2.5 dBFS."""
    w = np.asarray(raw_wav, dtype=np.float32).reshape(-1)
    if w.size == 0:
        w = np.zeros(int(sr * min_dur_sec), dtype=np.float32)
    w = np.nan_to_num(w, nan=0.0, posinf=0.0, neginf=0.0)
    w = w - float(np.mean(w))

    peak_raw = float(np.max(np.abs(w))) if w.size > 0 else 0.0
    win = max(64, int(sr * 0.020))  # 20ms window
    if w.size >= win and peak_raw > 1e-5:
        n_frames = w.size // win
        framed = w[: n_frames * win].reshape(n_frames, win)
        frame_rms = np.sqrt(np.mean(framed * framed, axis=1))
        thresh = max(0.0035, peak_raw * 0.020)
        active = np.flatnonzero(frame_rms >= thresh)
        if active.size > 0:
            lead_samples = int(sr * (lead_ms / 1000.0))
            tail_samples = int(sr * (tail_ms / 1000.0))
            start_idx = max(0, int(active[0]) * win - lead_samples)
            end_idx = min(w.size, int(active[-1] + 1) * win + tail_samples)
            w = w[start_idx:end_idx].copy()

    # Soft cosine fade-in (15ms) and fade-out (35ms)
    fade_in = min(int(sr * 0.015), w.size // 4)
    fade_out = min(int(sr * 0.035), w.size // 3)
    if fade_in > 4:
        ramp = 0.5 * (1.0 - np.cos(np.linspace(0.0, math.pi, fade_in, dtype=np.float32)))
        w[:fade_in] *= ramp
    if fade_out > 4:
        ramp = 0.5 * (1.0 + np.cos(np.linspace(0.0, math.pi, fade_out, dtype=np.float32)))
        w[-fade_out:] *= ramp

    # Guarantee minimum playable duration (>0.25s in Godot OGG loader)
    min_samples = int(sr * min_dur_sec)
    if w.size < min_samples:
        pad = np.zeros(min_samples - w.size, dtype=np.float32)
        w = np.concatenate([w, pad], axis=0)

    peak = float(np.max(np.abs(w)))
    if peak > 1e-5:
        w = w * (TARGET_PEAK / peak)
    w = np.clip(w, -0.98, 0.98)

    rms = float(np.sqrt(np.mean(w * w)))
    final_peak = float(np.max(np.abs(w)))
    dur_sec = round(float(w.size) / float(sr), 4)

    # Compute active frame ratio for QA
    active_ratio = 1.0
    if w.size >= win:
        nf = w.size // win
        fr = np.sqrt(np.mean(w[: nf * win].reshape(nf, win) ** 2, axis=1))
        active_ratio = float(np.mean(fr >= 0.012))

    return w, {
        "duration_sec": dur_sec,
        "rms": round(rms, 5),
        "peak": round(final_peak, 5),
        "active_ratio": round(active_ratio, 4),
    }


def validate_anchor_metrics(metrics: dict[str, float]) -> tuple[bool, str]:
    dur = metrics["duration_sec"]
    rms = metrics["rms"]
    peak = metrics["peak"]
    act = metrics["active_ratio"]
    if dur < 2.2 or dur > 9.0:
        return False, f"duration={dur:.2f}s out of [2.2, 9.0]"
    if rms <= 0.015:
        return False, f"rms={rms:.4f} <= 0.015"
    if peak > 0.99 or peak < 0.25:
        return False, f"peak={peak:.4f} out of bounds"
    if act < 0.35:
        return False, f"active_ratio={act:.2f} < 0.35 (excessive dead silence)"
    return True, "ok"


def estimate_expected_seconds(text: str, lang: str) -> float:
    cjk_chars = len(re.findall(r"[\u4e00-\u9fff]", text))
    en_words = len(re.findall(r"[A-Za-z0-9']+", text))
    pauses = len(re.findall(r"[,.!?;:，。！？；：、—…]", text))
    if lang == "en" and cjk_chars == 0:
        if en_words <= 1:
            return 0.95
        return 0.50 + en_words * 0.34 + pauses * 0.22
    return 0.50 + cjk_chars * 0.26 + en_words * 0.40 + pauses * 0.22


def compute_batch_max_new_tokens(batch_items: list[dict[str, Any]], lang: str) -> int:
    max_sec = max(estimate_expected_seconds(it["text"], lang) for it in batch_items)
    max_text_len = max(len(it["text"]) for it in batch_items)
    # 12.5 codec tokens/sec; 1.42x safety margin + 12 tokens gives ~2x actual speech ceiling without runaway silence
    est_tokens = int(math.ceil(max_sec * 12.5 * 1.42)) + 12
    if max_text_len <= 14 and lang == "en":
        return max(34, min(52, est_tokens))
    return max(48, min(200, est_tokens))


def encode_clip_pair_ffmpeg(
    clip_id: str,
    pcm_s16le: bytes,
    sr: int,
    nat_dur_sec: float,
    rms: float,
) -> dict[str, Any]:
    nat_out = CLIPS_DIR / f"{clip_id}.ogg"
    slow_out = CLIPS_SLOW_DIR / f"{clip_id}.ogg"
    nat_tmp = CLIPS_DIR / f"{clip_id}.tmp.ogg"
    slow_tmp = CLIPS_SLOW_DIR / f"{clip_id}.tmp.ogg"

    cmd = [
        str(FFMPEG_EXE),
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-f",
        "s16le",
        "-ar",
        str(sr),
        "-ac",
        "1",
        "-i",
        "pipe:0",
        "-ar",
        str(TARGET_SR),
        "-ac",
        "1",
        "-c:a",
        "libvorbis",
        "-q:a",
        "6",
        str(nat_tmp),
        "-af",
        "atempo=0.80",
        "-ar",
        str(TARGET_SR),
        "-ac",
        "1",
        "-c:a",
        "libvorbis",
        "-q:a",
        "6",
        str(slow_tmp),
    ]
    proc = subprocess.run(cmd, input=pcm_s16le, capture_output=True, check=False)
    if proc.returncode != 0 or not nat_tmp.is_file() or not slow_tmp.is_file():
        err_msg = proc.stderr.decode("utf-8", errors="replace")
        raise RuntimeError(f"FFmpeg failed for {clip_id}: {err_msg}")

    os.replace(nat_tmp, nat_out)
    os.replace(slow_tmp, slow_out)

    # Probe exact decoded sample count via soundfile so durations in manifest are 100% exact
    nat_info = sf.info(str(nat_out))
    slow_info = sf.info(str(slow_out))
    exact_nat_dur = round(float(nat_info.frames) / float(max(1, nat_info.samplerate)), 4)
    exact_slow_dur = round(float(slow_info.frames) / float(max(1, slow_info.samplerate)), 4)

    return {
        "clip_id": clip_id,
        "natural": f"clips/{clip_id}.ogg",
        "slow": f"clips_slow/{clip_id}.ogg",
        "duration_sec": exact_nat_dur if exact_nat_dur > 0 else nat_dur_sec,
        "slow_duration_sec": exact_slow_dur if exact_slow_dur > 0 else round(nat_dur_sec / 0.80, 4),
        "rms": rms,
        "nat_bytes": nat_out.stat().st_size,
        "slow_bytes": slow_out.stat().st_size,
    }


def write_json_atomic(path: Path, payload: dict[str, Any]) -> None:
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    tmp_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp_path, path)


def save_manifest_snapshot(
    corpus_items_by_id: dict[str, dict[str, Any]],
    baked_meta: dict[str, dict[str, Any]],
) -> int:
    write_json_atomic(CLIP_META_CACHE_PATH, baked_meta)

    entries: dict[str, dict[str, Any]] = {}
    for clip_id, meta in baked_meta.items():
        citem = corpus_items_by_id.get(clip_id)
        if not citem:
            continue
        entry_val = {
            "natural": meta["natural"],
            "slow": meta["slow"],
            "duration_sec": meta["duration_sec"],
            "slow_duration_sec": meta["slow_duration_sec"],
            "archetype": citem["archetype"],
            "lang": citem["lang"],
            "rms": meta["rms"],
        }
        for ak in citem.get("alias_keys", [citem["primary_key"]]):
            if ak not in entries:
                entries[ak] = entry_val

    manifest_payload = {
        "schema_version": 10,
        "engine": "local_llm_voice_bank",
        "generator": "Qwen3-TTS-12Hz-1.7B-VoiceDesign + Qwen3-TTS-12Hz-1.7B-Base",
        "sample_rate": TARGET_SR,
        "format": "ogg_vorbis_q6",
        "slow_atempo": 0.80,
        "baked_clip_count": len(baked_meta),
        "entry_key_count": len(entries),
        "entries": entries,
    }
    write_json_atomic(MANIFEST_PATH, manifest_payload)
    return len(entries)


def run_stage1_anchors(force_rebuild: bool = False) -> dict[str, dict[str, Any]]:
    from qwen_tts import Qwen3TTSModel

    ANCHORS_DIR.mkdir(parents=True, exist_ok=True)
    existing_manifest: dict[str, Any] = {}
    if ANCHORS_MANIFEST_PATH.is_file() and not force_rebuild:
        try:
            existing_manifest = json.loads(ANCHORS_MANIFEST_PATH.read_text(encoding="utf-8")).get("anchors", {})
        except Exception:
            existing_manifest = {}

    anchors_out: dict[str, dict[str, Any]] = {}
    todo: list[tuple[str, str, dict[str, Any]]] = []

    for arch, lang_map in GOLDEN_ANCHOR_SPECS.items():
        for lang in ("en", "zh"):
            spec = lang_map[lang]
            akey = f"{arch}_{lang}"
            wav_path = ANCHORS_DIR / f"{akey}.wav"
            reusable = False
            if not force_rebuild and wav_path.is_file() and akey in existing_manifest:
                prev = existing_manifest[akey]
                if prev.get("ref_text") == spec["ref_text"]:
                    try:
                        w_disk, sr_disk = sf.read(str(wav_path), dtype="float32")
                        _, m_disk = trim_and_normalize_wav(w_disk, sr_disk, lead_ms=50.0, tail_ms=100.0)
                        ok, _ = validate_anchor_metrics(m_disk)
                        if ok and sr_disk == TARGET_SR:
                            anchors_out[akey] = prev
                            reusable = True
                    except Exception:
                        reusable = False
            if not reusable:
                todo.append((arch, lang, spec))

    if not todo:
        print(f"[Stage 1] All {len(anchors_out)} Golden Voice Design anchors verified on disk!", flush=True)
        return anchors_out

    print(f"[Stage 1] Loading {VOICE_DESIGN_DIR.name} on cuda:0 (bfloat16, sdpa) for {len(todo)} anchors...", flush=True)
    t0 = time.perf_counter()
    vd = Qwen3TTSModel.from_pretrained(
        str(VOICE_DESIGN_DIR),
        device_map="cuda:0",
        dtype=torch.bfloat16,
        attn_implementation="sdpa",
        local_files_only=True,
    )
    upgrade_tokenizer_attn(vd)
    print(
        f"[Stage 1] Loaded VoiceDesign in {time.perf_counter() - t0:.2f}s "
        f"(VRAM={torch.cuda.memory_allocated() / 1e6:.0f} MB)",
        flush=True,
    )

    # First pass: batch by 4 for speed, then retry any QA failures individually
    batch_sz = 4
    retry_queue: list[tuple[str, str, dict[str, Any]]] = []

    for b_start in range(0, len(todo), batch_sz):
        chunk = todo[b_start : b_start + batch_sz]
        texts = [c[2]["ref_text"] for c in chunk]
        langs = ["English" if c[1] == "en" else "Chinese" for c in chunk]
        instructs = [c[2]["instruct"] for c in chunk]
        torch.manual_seed(int(chunk[0][2]["seed"]))
        torch.cuda.manual_seed_all(int(chunk[0][2]["seed"]))

        tb = time.perf_counter()
        wavs, sr = vd.generate_voice_design(
            text=texts,
            language=langs,
            instruct=instructs,
            max_new_tokens=118,
            temperature=0.76,
            top_p=0.92,
            repetition_penalty=1.08,
        )
        torch.cuda.synchronize()
        dt = time.perf_counter() - tb

        for idx, (arch, lang, spec) in enumerate(chunk):
            akey = f"{arch}_{lang}"
            clean_w, metrics = trim_and_normalize_wav(wavs[idx], sr, lead_ms=50.0, tail_ms=100.0, min_dur_sec=2.3)
            ok, reason = validate_anchor_metrics(metrics)
            if ok:
                wav_path = ANCHORS_DIR / f"{akey}.wav"
                sf.write(str(wav_path), clean_w, TARGET_SR, subtype="PCM_16")
                anchors_out[akey] = {
                    "anchor_id": akey,
                    "archetype": arch,
                    "lang": lang,
                    "wav_file": f"anchors/{akey}.wav",
                    "ref_text": spec["ref_text"],
                    "instruct": spec["instruct"],
                    "seed": int(spec["seed"]),
                    "sample_rate": TARGET_SR,
                    **metrics,
                }
                print(
                    f"  [OK] {akey:26s} dur={metrics['duration_sec']:.2f}s rms={metrics['rms']:.4f} (batch {dt:.1f}s)",
                    flush=True,
                )
            else:
                print(f"  [RETRY] {akey} failed initial QA ({reason}); queuing re-seed...", flush=True)
                retry_queue.append((arch, lang, spec))

    # Individual re-seed loop for any anchor needing a cleaner take
    for arch, lang, spec in retry_queue:
        akey = f"{arch}_{lang}"
        lang_full = "English" if lang == "en" else "Chinese"
        best_w: np.ndarray | None = None
        best_metrics: dict[str, float] = {}
        chosen_seed = int(spec["seed"])
        for attempt in range(1, 8):
            try_seed = int(spec["seed"]) + attempt * 997
            torch.manual_seed(try_seed)
            torch.cuda.manual_seed_all(try_seed)
            wavs, sr = vd.generate_voice_design(
                text=spec["ref_text"],
                language=lang_full,
                instruct=spec["instruct"],
                max_new_tokens=126,
                temperature=0.72,
                top_p=0.90,
                repetition_penalty=1.09,
            )
            clean_w, metrics = trim_and_normalize_wav(wavs[0], sr, lead_ms=50.0, tail_ms=100.0, min_dur_sec=2.3)
            ok, reason = validate_anchor_metrics(metrics)
            best_w, best_metrics, chosen_seed = clean_w, metrics, try_seed
            if ok:
                print(
                    f"  [RE-SEED OK] {akey:22s} attempt={attempt} dur={metrics['duration_sec']:.2f}s rms={metrics['rms']:.4f}",
                    flush=True,
                )
                break
            print(f"  [RE-SEED {attempt}] {akey}: {reason}", flush=True)

        assert best_w is not None
        wav_path = ANCHORS_DIR / f"{akey}.wav"
        sf.write(str(wav_path), best_w, TARGET_SR, subtype="PCM_16")
        anchors_out[akey] = {
            "anchor_id": akey,
            "archetype": arch,
            "lang": lang,
            "wav_file": f"anchors/{akey}.wav",
            "ref_text": spec["ref_text"],
            "instruct": spec["instruct"],
            "seed": chosen_seed,
            "sample_rate": TARGET_SR,
            **best_metrics,
        }

    write_json_atomic(
        ANCHORS_MANIFEST_PATH,
        {
            "schema_version": 10,
            "model": VOICE_DESIGN_DIR.name,
            "anchor_count": len(anchors_out),
            "anchors": dict(sorted(anchors_out.items())),
        },
    )

    # Strictly unload VoiceDesign from GPU VRAM before Stage 2
    del vd
    gc.collect()
    torch.cuda.empty_cache()
    if hasattr(torch.cuda, "ipc_collect"):
        torch.cuda.ipc_collect()
    print(
        f"[Stage 1] Unloaded VoiceDesign -> PyTorch CUDA allocated = {torch.cuda.memory_allocated() / 1e6:.1f} MB",
        flush=True,
    )
    return anchors_out


def run_stage2_clone_bake(
    anchors: dict[str, dict[str, Any]],
    batch_size: int = 10,
    max_clips: int = 0,
) -> dict[str, Any]:
    from qwen_tts import Qwen3TTSModel

    if not CORPUS_PATH.is_file():
        raise FileNotFoundError(f"Missing {CORPUS_PATH} — run extract_voice_corpus_v10.py first!")

    CLIPS_DIR.mkdir(parents=True, exist_ok=True)
    CLIPS_SLOW_DIR.mkdir(parents=True, exist_ok=True)

    corpus_data = json.loads(CORPUS_PATH.read_text(encoding="utf-8"))
    all_items: list[dict[str, Any]] = corpus_data["items"]
    items_by_id: dict[str, dict[str, Any]] = {it["clip_id"]: it for it in all_items}

    baked_meta: dict[str, dict[str, Any]] = {}
    if CLIP_META_CACHE_PATH.is_file():
        try:
            baked_meta = json.loads(CLIP_META_CACHE_PATH.read_text(encoding="utf-8"))
        except Exception:
            baked_meta = {}

    # Verify disk presence for cached clips; recover any valid clips on disk missing from cache
    verified_meta: dict[str, dict[str, Any]] = {}
    for cid, citem in items_by_id.items():
        nat_p = CLIPS_DIR / f"{cid}.ogg"
        slow_p = CLIPS_SLOW_DIR / f"{cid}.ogg"
        if nat_p.is_file() and slow_p.is_file() and nat_p.stat().st_size > 400 and slow_p.stat().st_size > 400:
            if cid in baked_meta:
                verified_meta[cid] = baked_meta[cid]
            else:
                nat_info = sf.info(str(nat_p))
                slow_info = sf.info(str(slow_p))
                verified_meta[cid] = {
                    "clip_id": cid,
                    "natural": f"clips/{cid}.ogg",
                    "slow": f"clips_slow/{cid}.ogg",
                    "duration_sec": round(float(nat_info.frames) / float(max(1, nat_info.samplerate)), 4),
                    "slow_duration_sec": round(float(slow_info.frames) / float(max(1, slow_info.samplerate)), 4),
                    "rms": 0.10,
                    "nat_bytes": nat_p.stat().st_size,
                    "slow_bytes": slow_p.stat().st_size,
                }
    baked_meta = verified_meta

    pending_items = [it for it in all_items if it["clip_id"] not in baked_meta]
    if max_clips > 0:
        pending_items = pending_items[:max_clips]

    print(
        f"[Stage 2] Corpus={len(all_items)} unique clips | Already baked={len(baked_meta)} | Pending={len(pending_items)}",
        flush=True,
    )
    if not pending_items:
        n_keys = save_manifest_snapshot(items_by_id, baked_meta)
        return {"baked_count": len(baked_meta), "entry_keys": n_keys, "newly_baked": 0}

    # Group pending by (archetype, lang) and sort within each group by estimated speech duration
    grouped: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for it in pending_items:
        gkey = (it["archetype"], it["lang"])
        grouped.setdefault(gkey, []).append(it)
    for (arch, lang), glist in grouped.items():
        glist.sort(key=lambda x: (estimate_expected_seconds(x["text"], lang), len(x["text"]), x["clip_id"]))

    print(f"[Stage 2] Loading {BASE_MODEL_DIR.name} on cuda:0 (bfloat16, sdpa)...", flush=True)
    t_load = time.perf_counter()
    base = Qwen3TTSModel.from_pretrained(
        str(BASE_MODEL_DIR),
        device_map="cuda:0",
        dtype=torch.bfloat16,
        attn_implementation="sdpa",
        local_files_only=True,
    )
    upgrade_tokenizer_attn(base)
    print(
        f"[Stage 2] Loaded Base in {time.perf_counter() - t_load:.2f}s "
        f"(VRAM={torch.cuda.memory_allocated() / 1e6:.0f} MB)",
        flush=True,
    )

    newly_baked = 0
    since_last_save = 0
    t_stage2 = time.perf_counter()
    pending_futures: list[Future[dict[str, Any]]] = []

    def _drain_completed(wait_all: bool = False) -> None:
        nonlocal newly_baked, since_last_save
        still_running: list[Future[dict[str, Any]]] = []
        for fut in pending_futures:
            if wait_all or fut.done():
                res = fut.result()
                baked_meta[res["clip_id"]] = res
                newly_baked += 1
                since_last_save += 1
            else:
                still_running.append(fut)
        pending_futures.clear()
        pending_futures.extend(still_running)
        if since_last_save >= 50:
            n_k = save_manifest_snapshot(items_by_id, baked_meta)
            elapsed = time.perf_counter() - t_stage2
            rate = newly_baked / max(0.1, elapsed)
            rem = (len(pending_items) - newly_baked) / max(0.05, rate)
            vram_res = torch.cuda.memory_reserved() / 1e6
            print(
                f"  [Checkpoint] Baked={len(baked_meta)}/{len(all_items)} (keys={n_k}) | "
                f"speed={rate:.2f} clips/s | VRAM_res={vram_res:.0f}MB | ETA={rem / 60.0:.1f}m",
                flush=True,
            )
            since_last_save = 0

    for tmp_f in list(CLIPS_DIR.glob("*.tmp.ogg")) + list(CLIPS_SLOW_DIR.glob("*.tmp.ogg")):
        tmp_f.unlink(missing_ok=True)

    with ThreadPoolExecutor(max_workers=8) as pool:
        for (arch, lang), glist in grouped.items():
            akey = f"{arch}_{lang}"
            anchor_info = anchors[akey]
            anchor_wav_path = BANK_DIR / anchor_info["wav_file"]
            anchor_ref_text = anchor_info["ref_text"]
            lang_full = "English" if lang == "en" else "Chinese"

            # Pre-compute ICL voice-clone prompt ONCE per (archetype, lang)
            clone_prompt = base.create_voice_clone_prompt(
                ref_audio=str(anchor_wav_path),
                ref_text=anchor_ref_text,
                x_vector_only_mode=False,
            )
            print(
                f"[Stage 2] Synthesizing {akey:24s}: {len(glist):4d} clips (adaptive batch <= {batch_size})...",
                flush=True,
            )

            b_idx = 0
            while b_idx < len(glist):
                probe = glist[b_idx : b_idx + batch_size]
                probe_tok = compute_batch_max_new_tokens(probe, lang)
                cur_bs = min(batch_size, 10) if probe_tok <= 90 else min(batch_size, 8)
                batch = glist[b_idx : b_idx + cur_bs]
                b_texts = [it["text"] for it in batch]
                b_langs = [lang_full] * len(batch)
                max_tok = compute_batch_max_new_tokens(batch, lang)
                b_idx_cur = b_idx
                b_idx += len(batch)

                torch.manual_seed(4070 + b_idx_cur)
                wavs, sr = base.generate_voice_clone(
                    text=b_texts,
                    language=b_langs,
                    voice_clone_prompt=clone_prompt,
                    max_new_tokens=max_tok,
                    temperature=0.78,
                    top_p=0.92,
                    repetition_penalty=1.08,
                )
                torch.cuda.empty_cache()

                for i, it in enumerate(batch):
                    clean_w, m = trim_and_normalize_wav(wavs[i], sr, lead_ms=60.0, tail_ms=120.0, min_dur_sec=0.42)
                    # Single-clip retry if rare silent/degenerate sample occurs
                    if m["rms"] < 0.008 or m["duration_sec"] < 0.28:
                        torch.manual_seed(9090 + b_idx + i)
                        rw, rsr = base.generate_voice_clone(
                            text=it["text"],
                            language=lang_full,
                            voice_clone_prompt=clone_prompt,
                            max_new_tokens=min(280, max_tok + 36),
                            temperature=0.72,
                            top_p=0.90,
                            repetition_penalty=1.10,
                        )
                        clean_w, m = trim_and_normalize_wav(rw[0], rsr, lead_ms=60.0, tail_ms=120.0, min_dur_sec=0.42)

                    pcm_i16 = np.clip(np.round(clean_w * 32767.0), -32768, 32767).astype("<i2").tobytes()
                    fut = pool.submit(
                        encode_clip_pair_ffmpeg,
                        it["clip_id"],
                        pcm_i16,
                        sr,
                        m["duration_sec"],
                        m["rms"],
                    )
                    pending_futures.append(fut)

                _drain_completed(wait_all=False)
                # Prevent unbounded memory queue if FFmpeg ever lags
                if len(pending_futures) >= 48:
                    _drain_completed(wait_all=True)

            del clone_prompt
            torch.cuda.empty_cache()

        _drain_completed(wait_all=True)

    final_keys = save_manifest_snapshot(items_by_id, baked_meta)

    del base
    gc.collect()
    torch.cuda.empty_cache()
    if hasattr(torch.cuda, "ipc_collect"):
        torch.cuda.ipc_collect()
    print(
        f"[Stage 2] Unloaded Base -> PyTorch CUDA allocated = {torch.cuda.memory_allocated() / 1e6:.1f} MB",
        flush=True,
    )
    return {
        "baked_count": len(baked_meta),
        "entry_keys": final_keys,
        "newly_baked": newly_baked,
        "stage2_sec": round(time.perf_counter() - t_stage2, 2),
    }


def compute_bank_summary() -> dict[str, Any]:
    nat_files = list(CLIPS_DIR.glob("*.ogg"))
    slow_files = list(CLIPS_SLOW_DIR.glob("*.ogg"))
    anc_files = list(ANCHORS_DIR.glob("*.wav"))
    total_bytes = (
        sum(f.stat().st_size for f in nat_files)
        + sum(f.stat().st_size for f in slow_files)
        + sum(f.stat().st_size for f in anc_files)
        + (MANIFEST_PATH.stat().st_size if MANIFEST_PATH.is_file() else 0)
        + (CORPUS_PATH.stat().st_size if CORPUS_PATH.is_file() else 0)
    )
    meta = json.loads(CLIP_META_CACHE_PATH.read_text(encoding="utf-8")) if CLIP_META_CACHE_PATH.is_file() else {}
    durs = [float(v["duration_sec"]) for v in meta.values()] if meta else [0.0]
    slow_durs = [float(v["slow_duration_sec"]) for v in meta.values()] if meta else [0.0]
    rmss = [float(v["rms"]) for v in meta.values()] if meta else [0.0]
    ratios = [
        float(v["slow_duration_sec"]) / max(0.05, float(v["duration_sec"]))
        for v in meta.values()
    ] if meta else [1.25]
    return {
        "anchor_wav_count": len(anc_files),
        "natural_ogg_count": len(nat_files),
        "slow_ogg_count": len(slow_files),
        "total_disk_mb": round(total_bytes / (1024.0 * 1024.0), 2),
        "nat_dur_min_avg_max": (round(min(durs), 3), round(sum(durs) / len(durs), 3), round(max(durs), 3)),
        "slow_dur_min_avg_max": (round(min(slow_durs), 3), round(sum(slow_durs) / len(slow_durs), 3), round(max(slow_durs), 3)),
        "slow_ratio_min_avg": (round(min(ratios), 3), round(sum(ratios) / len(ratios), 3)),
        "rms_min_avg_max": (round(min(rmss), 4), round(sum(rmss) / len(rmss), 4), round(max(rmss), 4)),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage1-only", action="store_true", help="Sculpt 26 Golden Anchors only.")
    parser.add_argument("--force-anchors", action="store_true", help="Re-generate all 26 Golden Anchors.")
    parser.add_argument("--batch-size", type=int, default=10, help="GPU clone batch size (default: 10).")
    parser.add_argument("--max-clips", type=int, default=0, help="Optional limit of clips to bake in Stage 2.")
    args = parser.parse_args()

    t_all = time.perf_counter()
    setup_cuda_fastpaths()

    anchors = run_stage1_anchors(force_rebuild=args.force_anchors)
    if args.stage1_only:
        print(f"[Done Stage 1] {len(anchors)} anchors ready in {time.perf_counter() - t_all:.1f}s.", flush=True)
        return

    s2 = run_stage2_clone_bake(anchors, batch_size=args.batch_size, max_clips=args.max_clips)
    summary = compute_bank_summary()
    wall_sec = round(time.perf_counter() - t_all, 2)
    print("\n================ V10 VOICE BANK SUMMARY ================", flush=True)
    print(f"  Wall-clock time      : {wall_sec:.1f}s ({wall_sec / 60.0:.2f} min)", flush=True)
    print(f"  Golden Anchors       : {summary['anchor_wav_count']} WAVs", flush=True)
    print(f"  Baked Clips          : {summary['natural_ogg_count']} natural + {summary['slow_ogg_count']} slow OGGs", flush=True)
    print(f"  Manifest Entry Keys  : {s2['entry_keys']}", flush=True)
    print(f"  Total Disk Size      : {summary['total_disk_mb']} MB", flush=True)
    print(f"  Natural Duration (s) : min={summary['nat_dur_min_avg_max'][0]} avg={summary['nat_dur_min_avg_max'][1]} max={summary['nat_dur_min_avg_max'][2]}", flush=True)
    print(f"  Slow Duration (s)    : min={summary['slow_dur_min_avg_max'][0]} avg={summary['slow_dur_min_avg_max'][1]} max={summary['slow_dur_min_avg_max'][2]}", flush=True)
    print(f"  Slow/Nat Ratio       : min={summary['slow_ratio_min_avg'][0]}x avg={summary['slow_ratio_min_avg'][1]}x", flush=True)
    print(f"  RMS Energy           : min={summary['rms_min_avg_max'][0]} avg={summary['rms_min_avg_max'][1]} max={summary['rms_min_avg_max'][2]}", flush=True)
    print("========================================================", flush=True)


if __name__ == "__main__":
    main()
