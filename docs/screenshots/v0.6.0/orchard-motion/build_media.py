"""Join the native orchard PNG sequence; preserve measured simulation timings."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
output_rows = []
font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 17)

for directory in [ROOT / "1440x900", ROOT / "960x640"]:
    capture = json.loads((directory / "capture-report.json").read_text(encoding="utf-8"))
    rows = capture["frames"]
    initial = Image.open(directory / "01-initial-ui.png").convert("RGB")
    target_size = (960, round(initial.height * 960 / initial.width))
    images = [initial.resize(target_size, Image.Resampling.LANCZOS)]
    durations = [1000]
    actual_sizes = set()
    for index, row in enumerate(rows):
        with Image.open(row["path"]) as frame:
            actual_sizes.add(frame.size)
            images.append(frame.convert("RGB").resize(target_size, Image.Resampling.LANCZOS))
        elapsed = rows[index + 1]["time"] - row["time"] if index + 1 < len(rows) else 1.0
        durations.append(max(20, round(elapsed * 1000)))
    gif_path = directory / "orchard-demonstration.gif"
    images[0].save(gif_path, save_all=True, append_images=images[1:], duration=durations, loop=0, disposal=2, optimize=False)
    for image in images:
        image.close()
    selected = []
    for phase in ["walking_pick", "picking", "lifting", "carrying", "walking_place", "placing", "deposited"]:
        matching = [row for row in rows if row["phase"] == phase]
        if matching:
            selected.append(matching[len(matching) // 2])
    selected.append(rows[-1])
    thumb_size = (480, round(target_size[1] / 2))
    cell_height = thumb_size[1] + 24
    sheet = Image.new("RGB", (thumb_size[0] * 2, cell_height * 4), "#e5eae3")
    draw = ImageDraw.Draw(sheet)
    for index, row in enumerate(selected):
        x, y = (index % 2) * thumb_size[0], (index // 2) * cell_height
        with Image.open(row["path"]) as frame:
            sheet.paste(frame.convert("RGB").resize(thumb_size, Image.Resampling.LANCZOS), (x, y))
        draw.text((x + 6, y + thumb_size[1] + 2), f"{row['phase']} / {row['time']:.2f}s", font=font, fill="#203b2d")
    sheet.save(directory / "phase-contact-sheet.jpg", quality=93)
    output_rows.append({
        "resolution": directory.name,
        "native_frame_count": len(rows),
        "native_image_sizes": sorted(actual_sizes),
        "simulated_duration_seconds": capture["duration"],
        "mean_capture_interval_seconds": (rows[-1]["time"] - rows[0]["time"]) / max(1, len(rows)-1),
        "gif": str(gif_path),
        "gif_pixels": target_size,
        "gif_bytes": gif_path.stat().st_size,
        "initial_hold_ms": 1000,
        "final_hold_ms": 1000,
        "pixels": "native screenshots resized only; no frame interpolation or generated replacement frames",
    })
result = {"status": "MEDIA_ASSEMBLED", "clips": output_rows}
(ROOT / "media-report.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(result, ensure_ascii=False))
