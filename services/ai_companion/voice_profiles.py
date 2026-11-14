"""Multi-Character Voice Archetype & Persona Prosody Registry for StudyGames V5.

Maps every island NPC, textbook classmate/teacher, landmark & campus resident,
and storybook narrator to a distinct vocal timbre across:
1. Hyper-realistic Cloud Neural Voices (`edge-tts` + optional DashScope CosyVoice / OpenAI TTS)
   with per-character pitch (`Hz`) and speaking-rate (`%`) micro-prosody.
2. Offline Multi-Model Piper VITS Neural ONNX (`amy`, `ryan`, `kristin`, `arctic` 18-speaker,
   `huayan`, `chaowen`, `xiao_ya`) with vocal-tract formant/pitch resampling & pace compensation.
"""
from __future__ import annotations

from typing import Any

VOICE_ARCHETYPES: dict[str, dict[str, Any]] = {
    "uncle_warm": {
        "profile_id": "uncle_warm",
        "label_zh": "暖厚大叔音",
        "edge_en": "en-US-BrianNeural",
        "edge_zh": "zh-CN-YunjianNeural",
        "rate_pct": -4,
        "pitch_hz": -5,
        "openai_voice": "onyx",
        "dashscope_voice": "longshu",
        "piper_en_model": "en_US-ryan-medium.onnx",
        "piper_en_speaker": None,
        "piper_zh_model": "zh_CN-chaowen-medium.onnx",
        "piper_zh_speaker": None,
        "piper_pace": 1.05,
        "piper_pitch_shift": 0.94,
        "sapi_gender": "Male",
    },
    "elder_wise": {
        "profile_id": "elder_wise",
        "label_zh": "慈祥智者音",
        "edge_en": "en-US-RogerNeural",
        "edge_zh": "zh-CN-YunyangNeural",
        "rate_pct": -6,
        "pitch_hz": -4,
        "openai_voice": "fable",
        "dashscope_voice": "longcheng",
        "piper_en_model": "en_US-arctic-medium.onnx",
        "piper_en_speaker": 2,
        "piper_zh_model": "zh_CN-chaowen-medium.onnx",
        "piper_zh_speaker": None,
        "piper_pace": 1.08,
        "piper_pitch_shift": 0.91,
        "sapi_gender": "Male",
    },
    "artisan_male": {
        "profile_id": "artisan_male",
        "label_zh": "阳光男匠人音",
        "edge_en": "en-US-AndrewNeural",
        "edge_zh": "zh-CN-YunxiNeural",
        "rate_pct": 0,
        "pitch_hz": 0,
        "openai_voice": "echo",
        "dashscope_voice": "longxiaochun",
        "piper_en_model": "en_US-ryan-medium.onnx",
        "piper_en_speaker": None,
        "piper_zh_model": "zh_CN-chaowen-medium.onnx",
        "piper_zh_speaker": None,
        "piper_pace": 0.99,
        "piper_pitch_shift": 1.02,
        "sapi_gender": "Male",
    },
    "teacher_gentle": {
        "profile_id": "teacher_gentle",
        "label_zh": "温柔女老师音",
        "edge_en": "en-US-EmmaNeural",
        "edge_zh": "zh-CN-XiaoxiaoNeural",
        "rate_pct": -3,
        "pitch_hz": 0,
        "openai_voice": "nova",
        "dashscope_voice": "longwan",
        "piper_en_model": "en_US-amy-medium.onnx",
        "piper_en_speaker": None,
        "piper_zh_model": "zh_CN-huayan-medium.onnx",
        "piper_zh_speaker": None,
        "piper_pace": 1.02,
        "piper_pitch_shift": 1.00,
        "sapi_gender": "Female",
    },
    "storyteller": {
        "profile_id": "storyteller",
        "label_zh": "绘本讲故事音",
        "edge_en": "en-US-JennyNeural",
        "edge_zh": "zh-CN-XiaoxiaoNeural",
        "rate_pct": -5,
        "pitch_hz": 2,
        "openai_voice": "shimmer",
        "dashscope_voice": "longyue",
        "piper_en_model": "en_US-amy-medium.onnx",
        "piper_en_speaker": None,
        "piper_zh_model": "zh_CN-huayan-medium.onnx",
        "piper_zh_speaker": None,
        "piper_pace": 1.05,
        "piper_pitch_shift": 1.02,
        "sapi_gender": "Female",
    },
    "grandma_warm": {
        "profile_id": "grandma_warm",
        "label_zh": "慈爱长辈女音",
        "edge_en": "en-GB-SoniaNeural",
        "edge_zh": "zh-CN-XiaoxiaoNeural",
        "rate_pct": -6,
        "pitch_hz": -4,
        "openai_voice": "shimmer",
        "dashscope_voice": "longwan",
        "piper_en_model": "en_US-arctic-medium.onnx",
        "piper_en_speaker": 4,
        "piper_zh_model": "zh_CN-huayan-medium.onnx",
        "piper_zh_speaker": None,
        "piper_pace": 1.07,
        "piper_pitch_shift": 0.95,
        "sapi_gender": "Female",
    },
    "artisan_female": {
        "profile_id": "artisan_female",
        "label_zh": "明快女达人音",
        "edge_en": "en-US-AriaNeural",
        "edge_zh": "zh-CN-XiaoyiNeural",
        "rate_pct": 1,
        "pitch_hz": -2,
        "openai_voice": "nova",
        "dashscope_voice": "longxiaoxia",
        "piper_en_model": "en_US-kristin-medium.onnx",
        "piper_en_speaker": None,
        "piper_zh_model": "zh_CN-xiao_ya-medium.onnx",
        "piper_zh_speaker": None,
        "piper_pace": 1.00,
        "piper_pitch_shift": 0.99,
        "sapi_gender": "Female",
    },
    "girl_bright": {
        "profile_id": "girl_bright",
        "label_zh": "元气小女孩音",
        "edge_en": "en-US-AnaNeural",
        "edge_zh": "zh-CN-XiaoyiNeural",
        "rate_pct": 2,
        "pitch_hz": 6,
        "openai_voice": "nova",
        "dashscope_voice": "longtong",
        "piper_en_model": "en_US-kristin-medium.onnx",
        "piper_en_speaker": None,
        "piper_zh_model": "zh_CN-xiao_ya-medium.onnx",
        "piper_zh_speaker": None,
        "piper_pace": 0.97,
        "piper_pitch_shift": 1.10,
        "sapi_gender": "Female",
    },
    "boy_sunny": {
        "profile_id": "boy_sunny",
        "label_zh": "阳光小男孩音",
        "edge_en": "en-US-AnaNeural",
        "edge_zh": "zh-CN-YunxiaNeural",
        "rate_pct": 4,
        "pitch_hz": -5,
        "openai_voice": "alloy",
        "dashscope_voice": "longjielidou",
        "piper_en_model": "en_US-arctic-medium.onnx",
        "piper_en_speaker": 0,
        "piper_zh_model": "zh_CN-xiao_ya-medium.onnx",
        "piper_zh_speaker": None,
        "piper_pace": 0.96,
        "piper_pitch_shift": 1.06,
        "sapi_gender": "Female",
    },
    "mascot_dino": {
        "profile_id": "mascot_dino",
        "label_zh": "俏皮萌宠音",
        "edge_en": "en-GB-MaisieNeural",
        "edge_zh": "zh-CN-YunxiaNeural",
        "rate_pct": 6,
        "pitch_hz": 10,
        "openai_voice": "shimmer",
        "dashscope_voice": "longjielidou",
        "piper_en_model": "en_US-kristin-medium.onnx",
        "piper_en_speaker": None,
        "piper_zh_model": "zh_CN-xiao_ya-medium.onnx",
        "piper_zh_speaker": None,
        "piper_pace": 0.94,
        "piper_pitch_shift": 1.16,
        "sapi_gender": "Female",
    },
}

# Maps character / hint IDs -> (archetype_id, delta_rate_pct, delta_pitch_hz)
CHARACTER_VOICE_MAP: dict[str, tuple[str, int, int]] = {
    # Generic hints
    "warm": ("teacher_gentle", 0, 0),
    "storyteller": ("storyteller", 0, 0),
    "narrator": ("storyteller", 0, 0),
    "player": ("girl_bright", 1, 2),
    # Core island & textbook cast
    "npc_bear_uncle": ("uncle_warm", 0, -1),
    "npc_rabbit_gardener": ("girl_bright", 2, 3),
    "npc_owl_tutor": ("elder_wise", 0, 1),
    "textbook_miss_li": ("teacher_gentle", 0, 0),
    "textbook_lingling": ("girl_bright", 0, 1),
    "textbook_anne": ("girl_bright", -2, -1),
    "textbook_peter": ("boy_sunny", 0, 0),
    "textbook_mingming": ("boy_sunny", 1, 2),
    "textbook_dongdong": ("boy_sunny", 2, -2),
    "textbook_tim": ("boy_sunny", -1, 1),
    "textbook_jim": ("boy_sunny", -2, -1),
    "textbook_dino": ("mascot_dino", 1, 3),
    # 26 Alphabet Landmark Residents (A-Z)
    "resident_a": ("girl_bright", -1, -3),
    "resident_b": ("uncle_warm", 2, 2),
    "resident_c": ("artisan_male", 1, 2),
    "resident_d": ("mascot_dino", 3, -2),
    "resident_e": ("grandma_warm", 1, 2),
    "resident_f": ("grandma_warm", -2, -2),
    "resident_g": ("artisan_male", 0, -2),
    "resident_h": ("artisan_female", 0, 1),
    "resident_i": ("mascot_dino", 0, 2),
    "resident_j": ("artisan_male", 2, 3),
    "resident_k": ("boy_sunny", 1, -2),
    "resident_l": ("artisan_female", -2, -1),
    "resident_m": ("uncle_warm", -4, 1),
    "resident_n": ("artisan_female", -1, 2),
    "resident_o": ("elder_wise", -1, 1),
    "resident_p": ("boy_sunny", 2, 2),
    "resident_q": ("elder_wise", -2, -3),
    "resident_r": ("artisan_female", 3, 2),
    "resident_s": ("artisan_male", -2, -1),
    "resident_t": ("uncle_warm", 2, 3),
    "resident_u": ("mascot_dino", 2, 1),
    "resident_v": ("artisan_female", -1, -2),
    "resident_w": ("girl_bright", -1, -2),
    "resident_x": ("artisan_male", -2, 3),
    "resident_y": ("grandma_warm", -1, 1),
    "resident_z": ("artisan_male", 4, 3),
    # 8 School Campus Residents
    "resident_school": ("elder_wise", -1, 0),
    "resident_classroom": ("teacher_gentle", 2, 2),
    "resident_music_room": ("artisan_male", -1, 1),
    "resident_art_room": ("girl_bright", -1, -2),
    "resident_science_room": ("teacher_gentle", 1, 1),
    "resident_canteen": ("uncle_warm", -1, 2),
    "resident_playground": ("boy_sunny", 3, -1),
    "resident_football_field": ("artisan_female", 4, -2),
    # Textbook Expansion Cast
    "textbook_amy": ("girl_bright", 0, 0),
    "textbook_daisy": ("girl_bright", -1, 1),
    "textbook_kathy": ("girl_bright", 1, 2),
    "textbook_kelly": ("girl_bright", 0, -1),
    "textbook_lily": ("girl_bright", -1, 2),
    "textbook_li_jie": ("artisan_female", 0, 0),
    "textbook_dan": ("boy_sunny", 0, -1),
    "textbook_harry": ("boy_sunny", 1, 1),
    "textbook_robbie": ("boy_sunny", 2, 0),
    "textbook_miss_lin": ("teacher_gentle", 1, 1),
    "textbook_aunt_carol": ("grandma_warm", 1, 2),
    "textbook_role_lingling_mother": ("teacher_gentle", -1, -1),
    "textbook_role_lingling_father": ("uncle_warm", 0, 1),
    "textbook_uncle_ben": ("uncle_warm", 1, 0),
    "textbook_mr_wang": ("artisan_male", -1, -2),
    "textbook_mr_chen": ("elder_wise", 1, 1),
    "textbook_old_macdonald": ("uncle_warm", 2, -2),
    "textbook_santa_claus": ("uncle_warm", -3, -4),
    "textbook_confucius": ("elder_wise", -3, -3),
    "textbook_socrates": ("elder_wise", -2, -2),
    "textbook_yu_gong": ("elder_wise", -4, -4),
    "textbook_jade_emperor": ("elder_wise", -3, -2),
    "textbook_qu_yuan": ("artisan_male", -3, -2),
    "textbook_zhang_heng": ("elder_wise", -1, -1),
    "textbook_yuan_longping": ("elder_wise", -2, -1),
    "textbook_tu_youyou": ("grandma_warm", -1, 0),
    "textbook_wang_yaping": ("teacher_gentle", 1, 0),
    "textbook_chang_e": ("storyteller", -2, 2),
    "textbook_andy_armstrong": ("artisan_male", 1, 0),
    "textbook_bob_weather_photo": ("artisan_male", 2, 1),
    "textbook_bunny": ("girl_bright", 3, 4),
    "textbook_kitty": ("girl_bright", 2, 5),
    "textbook_baker_bird": ("mascot_dino", 2, 4),
    "textbook_doggie": ("mascot_dino", 2, -2),
    "textbook_spot": ("mascot_dino", 3, -1),
    "textbook_elephant_ella": ("grandma_warm", -2, -1),
    "textbook_fendi": ("mascot_dino", 1, 2),
    "textbook_nian": ("uncle_warm", -2, -4),
    "textbook_qinmou": ("artisan_male", 0, 0),
    "textbook_role_xiaoxiao_parrot": ("mascot_dino", 4, 5),
}


def resolve_voice_profile(voice_hint: str | None) -> dict[str, Any]:
    """Resolve any `npc_id` or `voice_hint` into a concrete synthesis spec."""
    raw = (voice_hint or "warm").strip()
    key = raw.lower()
    if key in VOICE_ARCHETYPES:
        arch = dict(VOICE_ARCHETYPES[key])
        arch["voice_key"] = key
        return arch

    if key in CHARACTER_VOICE_MAP:
        arch_id, d_rate, d_pitch = CHARACTER_VOICE_MAP[key]
        base = dict(VOICE_ARCHETYPES[arch_id])
        rate = max(-25, min(25, int(base["rate_pct"]) + d_rate))
        pitch = max(-20, min(20, int(base["pitch_hz"]) + d_pitch))
        base["rate_pct"] = rate
        base["pitch_hz"] = pitch
        base["piper_pitch_shift"] = round(
            max(0.84, min(1.22, float(base["piper_pitch_shift"]) * (1.0 + d_pitch * 0.004))),
            3,
        )
        base["piper_pace"] = round(
            max(0.85, min(1.20, float(base["piper_pace"]) * (1.0 - d_rate * 0.004))),
            3,
        )
        base["voice_key"] = key
        return base

    # Deterministic fallback for any custom/future resident IDs
    fallback_arch = "teacher_gentle"
    if "bear" in key or "uncle" in key or "father" in key:
        fallback_arch = "uncle_warm"
    elif "boy" in key or "peter" in key:
        fallback_arch = "boy_sunny"
    elif "girl" in key or "rabbit" in key:
        fallback_arch = "girl_bright"
    elif "dino" in key or "bird" in key:
        fallback_arch = "mascot_dino"
    spec = dict(VOICE_ARCHETYPES[fallback_arch])
    spec["voice_key"] = key or "warm"
    return spec


def format_edge_rate(rate_pct: int) -> str:
    return f"+{rate_pct}%" if rate_pct >= 0 else f"{rate_pct}%"


def format_edge_pitch(pitch_hz: int) -> str:
    return f"+{pitch_hz}Hz" if pitch_hz >= 0 else f"{pitch_hz}Hz"
