"""Upgrade spatial_word_clusters_v6.json with V8 2-3 step coherent tactile tidy-up sequences (`placement_steps`).

Preserves existing `placement_task` (Step 1) 100% intact for V6 backward compatibility while adding
`placement_steps` (2 steps for 3-item anchors, 3 steps for 4-5 item anchors) with verified surface/rod coordinates.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLUSTERS_PATH = ROOT / "game" / "data" / "learning" / "spatial_word_clusters_v6.json"

HANGING_SHAPES = {"coat", "shirt", "dress"}


def dist_xz(a: list[float], b: list[float]) -> float:
    return math.hypot(a[0] - b[0], a[2] - b[2])


def round_v3(v: list[float]) -> list[float]:
    return [round(float(v[0]), 3), round(float(v[1]), 3), round(float(v[2]), 3)]


def build_step_prompt(item: dict, anchor_word: str, anchor_zh: str, is_wardrobe: bool, is_hanging: bool, step_num: int) -> tuple[str, str]:
    w = str(item.get("word", "item"))
    zh = str(item.get("zh", w))
    w_low = w.lower()

    if is_wardrobe and is_hanging:
        return (
            f"Hang the {w_low} neatly on the {anchor_word.lower()} rod.",
            f"把{zh}（{w}）挂上{anchor_zh}挂衣杆",
        )
    if is_wardrobe:
        return (
            f"Put the {w_low} neatly on the {anchor_word.lower()} shelf.",
            f"把{zh}（{w}）整理到{anchor_zh}隔板上",
        )

    verbs_en = ["Place", "Set", "Arrange"]
    verb = verbs_en[step_num % len(verbs_en)]
    prep = "in" if anchor_word.lower() in {"basket", "box", "drawer", "sink", "washbasin", "bath", "bucket"} else "on"
    return (
        f"{verb} the {w_low} neatly {prep} the {anchor_word.lower()}.",
        f"把{zh}（{w}）整齐摆到{anchor_zh}指定位置",
    )


def compute_tidy_target(
    idx: int,
    slots: list[list[float]],
    used_targets: list[list[float]],
    is_wardrobe: bool,
    is_hanging: bool,
) -> list[float]:
    base = list(slots[idx]) if idx < len(slots) else [0.0, 0.85, 0.0]
    same_tier = [s for s in slots if abs(float(s[1]) - float(base[1])) <= 0.16]
    if not same_tier:
        same_tier = [base]

    cx = sum(s[0] for s in same_tier) / len(same_tier)
    cz = sum(s[2] for s in same_tier) / len(same_tier)

    candidates: list[list[float]] = []
    if is_wardrobe and is_hanging:
        # Slide along the closet rod X-axis to a distinct tidy spot >= 0.24m from initial slot
        for dx in (-0.28, 0.28, -0.42, 0.42, 0.0):
            cand_x = cx + dx
            candidates.append([cand_x, base[1], base[2]])
    elif is_wardrobe:
        for dx in (-0.26, 0.26, 0.0, -0.38, 0.38):
            candidates.append([cx + dx, base[1], base[2] + 0.03])
    else:
        # Surface tidy zone: slightly forward/inward on the furniture surface, clearly distinct from start slot
        for ox, oz in [
            (0.24, 0.14),
            (-0.24, 0.14),
            (0.0, 0.18),
            (0.28, -0.12),
            (-0.28, -0.12),
            (0.18, 0.22),
            (-0.18, 0.22),
        ]:
            tx = 0.55 * base[0] + 0.45 * cx + ox
            tz = 0.55 * base[2] + 0.45 * cz + oz
            candidates.append([tx, base[1], tz])

    best = [base[0] + 0.22, base[1], base[2] + 0.10]
    best_score = -1e9
    for cand in candidates:
        move_d = dist_xz(cand, base)
        min_used = min((dist_xz(cand, u) for u in used_targets), default=1.0)
        # Keep within furniture bounds (close to convex hull of same_tier slots)
        center_d = math.hypot(cand[0] - cx, cand[2] - cz)
        score = min(move_d, 0.42) * 2.2 + min(min_used, 0.40) * 3.0 - max(0.0, center_d - 0.68) * 2.5
        if move_d >= 0.16 and min_used >= 0.20 and score > best_score:
            best_score = score
            best = cand

    return round_v3(best)


def main() -> None:
    data = json.loads(CLUSTERS_PATH.read_text(encoding="utf-8"))
    rooms = data.get("rooms", {})
    anchor_total = 0
    step_total = 0

    for room_id, cluster in rooms.items():
        for anchor in cluster.get("macro_items", []):
            anchor_total += 1
            anchor_word = str(anchor.get("word", "table"))
            anchor_zh = str(anchor.get("zh", "台面"))
            items = anchor.get("layer2_items", [])
            ptask = anchor.get("placement_task", {})
            spec = anchor.get("stage_spec", {})
            slots = spec.get("slots", [])
            is_wardrobe = str(spec.get("mode", "surface")) == "wardrobe"

            first_item_key = str(ptask.get("item", "")).strip().lower()
            first_prompt_en = str(ptask.get("prompt_en", ""))
            first_prompt_zh = str(ptask.get("prompt_zh", ""))
            first_target = round_v3(spec.get("target_pos", slots[0] if slots else [0.0, 0.85, 0.0]))

            steps: list[dict] = []
            used_keys: set[str] = set()
            used_targets: list[list[float]] = []

            if first_item_key:
                steps.append(
                    {
                        "item": first_item_key,
                        "prompt_en": first_prompt_en,
                        "prompt_zh": first_prompt_zh,
                        "target_pos": first_target,
                    }
                )
                used_keys.add(first_item_key)
                used_targets.append(first_target)

            desired_steps = 2 if len(items) <= 3 else 3
            prompt_lower = first_prompt_en.lower()

            for idx, it in enumerate(items):
                if len(steps) >= desired_steps:
                    break
                w_key = str(it.get("word", "")).strip().lower()
                if not w_key or w_key in used_keys:
                    continue
                # Avoid moving a container item that Step 1 placed something into (e.g., pencil-box)
                if w_key in prompt_lower and len(items) - len(used_keys) > (desired_steps - len(steps)):
                    continue

                is_hanging = is_wardrobe and (str(it.get("shape", "")) in HANGING_SHAPES or w_key in HANGING_SHAPES)
                tpos = compute_tidy_target(idx, slots, used_targets, is_wardrobe, is_hanging)
                pen, pzh = build_step_prompt(it, anchor_word, anchor_zh, is_wardrobe, is_hanging, len(steps) + 1)
                steps.append(
                    {
                        "item": w_key,
                        "prompt_en": pen,
                        "prompt_zh": pzh,
                        "target_pos": tpos,
                    }
                )
                used_keys.add(w_key)
                used_targets.append(tpos)

            anchor["placement_steps"] = steps
            step_total += len(steps)

    data["schema_version"] = 9
    CLUSTERS_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[V8Tasks] Upgraded {anchor_total} anchors with {step_total} total tidy-up steps (avg {step_total / max(1, anchor_total):.2f}/anchor).")


if __name__ == "__main__":
    main()
