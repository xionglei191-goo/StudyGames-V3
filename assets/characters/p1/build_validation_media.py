"""Assemble native Godot screenshots without altering the captured scene pixels."""
from __future__ import annotations

import json
from collections import OrderedDict
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent / "validation"
capture = json.loads((ROOT / "capture-report.json").read_text(encoding="utf-8"))
groups: dict[str, list[dict]] = OrderedDict()
for row in capture["frames"]:
    groups.setdefault(f"{row['actor']}_{row['action']}", []).append(row)

for name, rows in groups.items():
    images = [Image.open(Path(row["path"])).convert("RGB").resize((640, 400), Image.Resampling.LANCZOS) for row in rows]
    images[0].save(
        ROOT / f"{name}.gif",
        save_all=True,
        append_images=images[1:],
        duration=[1000] + [50] * (len(images) - 2) + [1000],
        loop=0,
        disposal=2,
        optimize=False,
    )
    for image in images:
        image.close()

font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 16)
sets = [
    ("human-animal-actions.jpg", list(groups)[:5]),
    ("dino-wheelchair-actions.jpg", list(groups)[5:]),
]
for target, names in sets:
    sheet = Image.new("RGB", (1280, len(names) * 224), "#e5eae3")
    draw = ImageDraw.Draw(sheet)
    for y, name in enumerate(names):
        rows = groups[name]
        for x, target_time in enumerate([0.0, 0.65, 1.1, rows[-1]["time"]]):
            row = min(rows, key=lambda item: abs(float(item["time"]) - target_time))
            with Image.open(Path(row["path"])) as source:
                sheet.paste(source.convert("RGB").resize((320, 200), Image.Resampling.LANCZOS), (x * 320, y * 224))
            draw.text((x * 320 + 5, y * 224 + 202), f"{name} {row['time']:.2f}s", fill="#1d3028", font=font)
    sheet.save(ROOT / target, quality=92)

print(json.dumps({"frames": len(capture["frames"]), "gifs": len(groups), "contact_sheets": len(sets)}))
