"""Dual-layer child safety guardrails (KidRails) for ages 7-12.

Blocks PII solicitation/leakage, profanity, bullying, horror, self-harm,
violence, and off-topic adult themes in both English and Chinese.
"""
from __future__ import annotations

import re
from dataclasses import dataclass

BLOCKED_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("pii_phone", re.compile(r"\b1[3-9]\d{9}\b|\b\d{3}[-\s]?\d{4}[-\s]?\d{4}\b")),
    ("pii_ask", re.compile(r"(真实姓名|家庭住址|住在哪里|手机号|微信号|密码|身份证|real\s+address|phone\s+number|password|credit\s+card)", re.I)),
    ("unsafe_violence", re.compile(r"(杀人|自杀|自残|流血|恐怖|鬼怪|炸弹|枪支|kill\s+you|suicide|self[\s-]?harm|murder|blood|terror|weapon|gun)", re.I)),
    ("unsafe_adult", re.compile(r"(色情|裸体|赌博|毒品|porn|naked|sex|gambling|drugs|alcohol)", re.I)),
    ("profanity_bullying", re.compile(r"(笨蛋|蠢货|去死|滚开|傻瓜|白痴|stupid|idiot|shut\s+up|hate\s+you|loser|dumb)", re.I)),
]

GENTLE_REDIRECT_EN = "Let's keep our island warm and friendly! Would you like to talk about apples, outfits, or stories?"
GENTLE_REDIRECT_ZH = "让我们一起守护温暖友善的字母岛吧！要不要聊聊今天的穿搭、红苹果，或者翻翻书里的故事呀？"


@dataclass
class GuardrailResult:
    allowed: bool
    reason: str = "ok"
    sanitized_text: str = ""
    redirect_en: str = ""
    redirect_zh: str = ""


def check_child_input(text: str) -> GuardrailResult:
    cleaned = " ".join((text or "").strip().split())[:240]
    if not cleaned:
        return GuardrailResult(
            allowed=False,
            reason="empty",
            sanitized_text="",
            redirect_en="Say \"Hello!\" anytime you want to chat!",
            redirect_zh="随时可以说一句 Hello 跟伙伴打招呼哦！",
        )
    for tag, pattern in BLOCKED_PATTERNS:
        if pattern.search(cleaned):
            return GuardrailResult(
                allowed=False,
                reason=tag,
                sanitized_text="",
                redirect_en=GENTLE_REDIRECT_EN,
                redirect_zh=GENTLE_REDIRECT_ZH,
            )
    return GuardrailResult(allowed=True, reason="ok", sanitized_text=cleaned)


def sanitize_npc_output(reply_en: str, reply_zh: str) -> tuple[str, str]:
    en = " ".join((reply_en or "").strip().split())[:220]
    zh = " ".join((reply_zh or "").strip().split())[:220]
    for _, pattern in BLOCKED_PATTERNS:
        if pattern.search(en) or pattern.search(zh):
            return GENTLE_REDIRECT_EN, GENTLE_REDIRECT_ZH
    if not en:
        en = "Hello, little explorer! What a sunny day on Alphabet Island!"
    if not zh:
        zh = "你好呀小探险家！今天字母岛的阳光真暖和！"
    return en, zh
