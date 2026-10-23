from __future__ import annotations
import hashlib
import json
import zipfile
from datetime import datetime
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
plan = json.loads((ROOT / "generation-plan.json").read_text(encoding="utf-8"))
records = json.loads((ROOT / "generation-records.json").read_text(encoding="utf-8"))
by_id = {row["id"]: row for row in records}
assert len(plan["characters"]) == len(by_id) == 12
expected_files = {row["file"] for row in plan["characters"]}
assert {p.name for p in ROOT.glob("[0-9][0-9]_*.png")} == expected_files

def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

notes = {
    "player": "棕色马尾、奶油色上衣和黄色短背带裤；正面站立，手脚完整。",
    "textbook_lingling": "黑色双马尾、粉色翻领上衣和玫红色裙子；双手与裙摆分开。",
    "textbook_peter": "金色卷发、白黄配色上衣和黄色短裤；蓝色护膝清楚。",
    "textbook_anne": "铜色高马尾、浅蓝色连衣裙和淡紫色开衫；正面站立。",
    "textbook_mingming": "黑色侧分短发、蓝黄篮球服叠穿白色上衣；无篮球遮挡。",
    "textbook_dongdong": "黑色短发、两道白条黄色上衣和红色短裤；全身完整。",
    "textbook_tim": "栗色卷发、白色与青绿色 Polo 服装；正面站立。",
    "textbook_miss_li": "黑色短发、粉色翻领及膝裙；成年人身形比例。",
    "textbook_dino": "绿色身体、奶油色口鼻与腹部；两翼、双臂、双足和侧弯尾巴完整。",
    "npc_bear_uncle": "蜂蜜棕色熊、奶油色厨师帽、灰青色围裙工作服；无手持物。",
    "npc_rabbit_gardener": "奶油色兔、粉色耳内、草帽和鼠尾草绿工作服；两耳完整。",
    "textbook_jim": "正面坐姿；人物、左右大轮、前脚轮和脚踏完整。双手位于腿前，人物与轮椅为整体参考。",
}
manifest_rows = []
for spec in plan["characters"]:
    p = ROOT / spec["file"]
    record = by_id[spec["id"]]
    with Image.open(p) as im:
        im.verify()
    with Image.open(p) as im:
        width, height = im.size
        mode = im.mode
        fmt = im.format
    assert width == height and width >= 1024, (p.name, width, height)
    assert fmt == "PNG", (p.name, fmt)
    digest = sha256(p)
    assert digest == sha256(Path(record["source"])), p.name
    assert record["status"] == "visual_review_passed"
    manifest_rows.append({
        "id": spec["id"],
        "name": spec["name"],
        "file": spec["file"],
        "width": width,
        "height": height,
        "mode": mode,
        "bytes": p.stat().st_size,
        "sha256": digest,
        "source_image_sha256_matches": True,
        "identity_reference": spec["reference"],
        "generation_method": "built_in_image_gen",
        "status": "front_reference_visually_reviewed",
        "visual_review_note": notes[spec["id"]],
        "pose": "seated_front_with_wheelchair" if spec["id"] == "textbook_jim" else "standing_front",
    })
assert len({r["sha256"] for r in manifest_rows}) == 12
manifest = {
    "schema_version": 1,
    "date": "2026-10-23",
    "stage": "front_reference_images_ready",
    "count": 12,
    "generator": "built_in_image_gen",
    "scope": "12 independent front-view images for user-led Tripo 3D generation",
    "background": "white",
    "original_png_bytes_preserved": True,
    "three_d_models_generated": False,
    "game_character_models_replaced": False,
    "validation": [
        "12 unique files and IDs",
        "PNG decoding and square resolution verified",
        "copied files match original image-generation output hashes",
        "visual review: identity cues, coherent style, front framing, complete subject",
        "no rig, topology, hidden geometry, or game-engine validation performed at reference-image stage",
    ],
    "characters": manifest_rows,
}
(ROOT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

# Build a review layout from copies in memory; independent reference PNGs are not modified.
PREVIEW = ROOT / "preview"
PREVIEW.mkdir(exist_ok=True)
font_path = "C:/Windows/Fonts/msyh.ttc"
font = lambda size: ImageFont.truetype(font_path, size)
pad, gap, cell_w, cell_h, header, footer = 40, 24, 390, 462, 150, 76
width = pad * 2 + 4 * cell_w + 3 * gap
height = header + 3 * cell_h + 2 * gap + footer
sheet = Image.new("RGB", (width, height), "#F5F3ED")
draw = ImageDraw.Draw(sheet)
draw.text((pad, 30), "字母岛 · 12 位核心角色", font=font(44), fill="#243E39")
draw.text((pad, 94), "正面建模参考  /  v01  /  2026.10.23", font=font(24), fill="#68736B")
for idx, spec in enumerate(plan["characters"]):
    x = pad + (idx % 4) * (cell_w + gap)
    y = header + (idx // 4) * (cell_h + gap)
    draw.rounded_rectangle((x, y, x + cell_w, y + cell_h), radius=15, fill="white", outline="#DCDDD5", width=1)
    with Image.open(ROOT / spec["file"]) as im:
        thumb = im.convert("RGB")
        thumb.thumbnail((cell_w - 22, 368), Image.Resampling.LANCZOS)
    sheet.paste(thumb, (x + (cell_w - thumb.width) // 2, y + 9 + (368 - thumb.height) // 2))
    draw.text((x + 19, y + 386), f'{idx + 1:02d}  {spec["name"]}', font=font(27), fill="#263D36")
    draw.text((x + 19, y + 428), spec["file"], font=font(16), fill="#7B827B")
draw.text((pad, height - 49), "上传 Tripo 时请选择单张角色 PNG  ·  总览缩略尺寸不代表角色身高", font=font(22), fill="#68736B")
overview = PREVIEW / "overview.png"
sheet.save(overview, optimize=True)

archive = ROOT.parent / (ROOT.name + ".zip")
pack_files = [ROOT / p["file"] for p in plan["characters"]]
pack_files += [ROOT / "README.md", ROOT / "manifest.json", ROOT / "generation-plan.json", ROOT / "generation-records.json", overview]
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
    for p in pack_files:
        zf.write(p, p.relative_to(ROOT).as_posix())
with zipfile.ZipFile(archive) as zf:
    assert zf.testzip() is None
    assert len(zf.namelist()) == len(pack_files) == 17
    for row in manifest_rows:
        assert hashlib.sha256(zf.read(row["file"])).hexdigest() == row["sha256"]
checks = {
    "completed_at": datetime.now().astimezone().isoformat(timespec="seconds"),
    "character_png_count": 12,
    "overview_count": 1,
    "dimensions": sorted({f'{r["width"]}x{r["height"]}' for r in manifest_rows}),
    "all_original_hashes_match": True,
    "archive_crc_passed": True,
    "archive_images_match_originals": True,
    "archive_file_count": 17,
    "archive_bytes": archive.stat().st_size,
    "archive_sha256": sha256(archive),
    "archive_path": str(archive),
    "overview_path": str(overview),
}
(ROOT / "delivery-checks.json").write_text(json.dumps(checks, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(checks, ensure_ascii=False, indent=2))

