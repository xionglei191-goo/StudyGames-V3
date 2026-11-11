"""3-Parameter Logistic IRT (3PL) Stealth Assessment & Spaced Retrieval Scheduler.

Models latent proficiency `theta` in [-3.0, +3.0] from natural in-world actions
without ever subjecting the child to stressful pop-up tests. Distinguishes
unassisted retrieval (`H0`) from scaffolded play (`H1..H5`)!
"""
from __future__ import annotations

import math
import time
from typing import Any

# Support weight multiplier: H0 unassisted carries full psychometric evidence;
# H5 demonstration counts as gentle exposure rather than independent mastery.
SUPPORT_WEIGHTS: dict[int, float] = {
    0: 1.00,
    1: 0.72,
    2: 0.58,
    3: 0.38,
    4: 0.24,
    5: 0.08,
}


def irt_3pl_prob(theta: float, a: float = 1.25, b: float = 0.0, c: float = 0.20) -> float:
    """3PL probability of unassisted success: P(theta) = c + (1 - c) / (1 + exp(-a*(theta - b)))."""
    z = max(-12.0, min(12.0, a * (theta - b)))
    return c + (1.0 - c) / (1.0 + math.exp(-z))


def estimate_word_difficulty(word: str) -> float:
    """Heuristic item difficulty `b` in [-1.5, +1.8] based on orthographic length & morphology."""
    cleaned = word.strip()
    length = len(cleaned)
    if length <= 3:
        return -0.9
    if length <= 5:
        return -0.25
    if length <= 8:
        return 0.45
    return min(1.6, 0.45 + (length - 8) * 0.18)


def update_irt_mastery(events: list[dict[str, Any]], prior_theta: float = 0.0) -> dict[str, Any]:
    theta = max(-3.0, min(3.0, float(prior_theta)))
    word_stats: dict[str, dict[str, Any]] = {}
    now = time.time()

    for ev in events:
        word = str(ev.get("word") or "").strip().lower()
        if not word:
            continue
        support = max(0, min(5, int(ev.get("support_level", 0))))
        correct = bool(ev.get("correct", True))
        ts = float(ev.get("timestamp") or now)

        weight = SUPPORT_WEIGHTS.get(support, 0.25)
        b = estimate_word_difficulty(word)
        a = 1.30
        c = 0.20 if support >= 2 else 0.08
        p = irt_3pl_prob(theta, a=a, b=b, c=c)

        # Effective outcome: unassisted correct pushes toward 1.0; heavily assisted correct nudges gently
        effective_y = (0.55 + 0.45 * weight) if correct else 0.0
        grad = a * weight * (effective_y - p)
        theta = max(-3.0, min(3.0, theta + 0.34 * grad))

        st = word_stats.setdefault(
            word,
            {
                "word": word,
                "exposures": 0,
                "independent_hits": 0,
                "scaffolded_hits": 0,
                "last_seen": ts,
                "half_life_hours": 12.0,
            },
        )
        st["exposures"] += 1
        st["last_seen"] = max(float(st["last_seen"]), ts)
        if correct and support == 0:
            st["independent_hits"] += 1
            st["half_life_hours"] = min(336.0, float(st["half_life_hours"]) * 2.1)
        elif correct:
            st["scaffolded_hits"] += 1
            st["half_life_hours"] = min(168.0, float(st["half_life_hours"]) * 1.35)
        else:
            st["half_life_hours"] = max(4.0, float(st["half_life_hours"]) * 0.65)

    due_revisits: list[dict[str, Any]] = []
    independent_words: list[str] = []
    sprouting_words: list[str] = []

    for word, st in word_stats.items():
        elapsed_h = max(0.0, (now - float(st["last_seen"])) / 3600.0)
        hl = float(st["half_life_hours"])
        recall_prob = math.pow(2.0, -elapsed_h / max(1.0, hl))
        if int(st["independent_hits"]) >= 1:
            independent_words.append(word)
        else:
            sprouting_words.append(word)
        due_revisits.append(
            {
                "word": word,
                "recall_probability": round(recall_prob, 3),
                "next_revisit_in_hours": round(max(0.0, hl * 0.85 - elapsed_h), 1),
                "status": "independent" if int(st["independent_hits"]) >= 1 else "scaffolded",
            }
        )

    due_revisits.sort(key=lambda item: float(item["recall_probability"]))
    # Normalize theta [-3, +3] into a warm 0..100 Growth Flourish Index for parents
    flourish_index = int(round(100.0 / (1.0 + math.exp(-0.85 * theta))))

    return {
        "theta": round(theta, 3),
        "flourish_index": flourish_index,
        "tracked_word_count": len(word_stats),
        "independent_words": sorted(independent_words),
        "sprouting_words": sorted(sprouting_words),
        "recommended_revisits": due_revisits[:6],
    }


def build_parent_weekly_report(payload: dict[str, Any]) -> dict[str, Any]:
    events = payload.get("stealth_events") if isinstance(payload.get("stealth_events"), list) else []
    book_title = str(payload.get("book_title") or "湘少版三年级上册")
    unit_id = str(payload.get("unit_id") or "unit-1")
    visited_landmarks = int(payload.get("visited_landmarks", 0))
    outfit = str(payload.get("outfit_zh") or "晨光柠檬背带装")

    summary = update_irt_mastery(events)
    ind_list = summary["independent_words"]
    spr_list = summary["sprouting_words"]

    if ind_list:
        highlight = f"孩子在自然游玩与 3D 立体翻翻书中，已经在无提示状态下主动运用了 {', '.join(ind_list[:5])} 等表达！"
    elif spr_list:
        highlight = f"孩子通过果园采摘、换装与绘本立体剧场接触了 {', '.join(spr_list[:5])}，正在从情境感知走向熟悉。"
    else:
        highlight = "孩子刚刚开启字母岛的生活探索，正在熟悉小岛庭院、穿搭镜台与伙伴问候。"

    revisit_tip = (
        f"下次散步或吃水果时，可以随口和孩子玩一句关于「{summary['recommended_revisits'][0]['word']}」的小接龙，无需考问拼写。"
        if summary["recommended_revisits"]
        else "建议陪孩子去 A 苹果果园捧起红苹果，或者打开一本 3D 立体翻翻书演一演纸偶故事！"
    )

    narrative = (
        f"【当前同步册次】{book_title}（{unit_id.upper()}）\n"
        f"【小岛生活足迹】已走访 {visited_landmarks} / 26 处字母记忆地标 · 今日偏爱穿搭：{outfit}\n"
        f"【隐性成长观察】{highlight}\n"
        f"【家庭温和互动建议】{revisit_tip}"
    )

    return {
        "ok": True,
        "summary": summary,
        "narrative_zh": narrative,
        "note": "本报告基于游戏内行为线索（IRT 隐性能力模型与 H0-H5 脚手架分级）自动生成，不代表标准化纸笔测验分数。",
    }
