from __future__ import annotations
import argparse
import hashlib
import html
import json
import zipfile
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[2]

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def write_json(name: str, value: object) -> None:
    (ROOT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def build(package: bool = False) -> None:
    plan = json.loads((ROOT / "generation-plan.json").read_text(encoding="utf-8"))
    records = json.loads((ROOT / "generation-records.json").read_text(encoding="utf-8"))
    characters = plan["characters"]
    catalog = json.loads((PROJECT / "game/data/landmark_interiors.json").read_text(encoding="utf-8-sig"))
    rooms = {}
    for item in catalog["landmarks"]:
        if item["room_id"] == "home_estate":
            continue
        rooms[item["room_id"]] = item["name"]
        if item["room_id"] == "school":
            for area in item["areas"]:
                rooms[area["room_id"]] = area["name"]
    assert len(characters) == len(records) == len(rooms) == 34
    assert {c["room_id"]: c["building_name"] for c in characters} == rooms
    assert len({c["id"] for c in characters}) == 34
    assert len({c["name_zh"] for c in characters}) == 34
    assert len({c["name_en"] for c in characters}) == 34
    expected = {c["file"] for c in characters}
    assert {p.name for p in ROOT.glob("[0-9][0-9]_*.png")} == expected
    by_id = {r["id"]: r for r in records}
    assets = []
    for c in characters:
        record = by_id[c["id"]]
        path = ROOT / c["file"]
        with Image.open(path) as im:
            im.verify()
        with Image.open(path) as im:
            width, height = im.size
            mode, fmt = im.mode, im.format
        assert fmt == "PNG" and width == height and width >= 1024, (path, width, height, fmt)
        digest = sha(path)
        assert digest == sha(Path(record["source"])), c["id"]
        assert record["status"] == "visual_review_passed"
        c["status"] = "visual_review_passed"
        assets.append({
            "resident_id": c["id"], "room_id": c["room_id"], "building_name": c["building_name"],
            "name_zh": c["name_zh"], "name_en": c["name_en"], "type": c["type"], "role": c["role"],
            "palette": c["palette"], "design": c["design_zh"],
            "path": c["file"], "status": "concept_reference_checked",
            "model_filename": c["id"] + ".glb",
            "technical": {"width": width, "height": height, "format": fmt, "mode": mode,
                          "bytes": path.stat().st_size, "sha256": digest,
                          "background": "white", "views": 1, "frames": 1,
                          "source_bytes_preserved": True,
                          "collision_role": "none; 2D concept reference"},
            "source": {"kind": "AI-generated original concept", "tool": "built-in image_gen",
                       "date": plan["date"], "original_path": record["source"],
                       "references": c["references"], "prompt_record": "generation-plan.json",
                       "license_note": "Generated for this project; references are existing project character images."},
            "verification": {"visual_reviewed": True, "review_note": record["review_note"],
                             "technical_checks_passed": True, "reviewed_by": "Codex",
                             "in_engine_reviewed": False, "tripo_model_generated": False}
        })
    assert len({a["technical"]["sha256"] for a in assets}) == 34
    assert sum(c["type"] == "human" for c in characters) == 16
    assert sum(c["type"] == "animal" for c in characters) == 18
    plan["status"] = "reference_images_ready"
    write_json("generation-plan.json", plan)
    write_json("manifest.json", {"schema_version": 1, "date": plan["date"],
                               "art_direction_brief": "art-direction-brief.md",
                               "runtime_status": "concepts_only_not_integrated", "assets": assets})
    checks = {"date": plan["date"], "passed": True, "expected": 34, "png_verified": 34,
              "unique_images": 34, "unique_resident_ids": 34, "unique_room_ids": 34,
              "catalog_mapping_matches": True, "source_hashes_match": 34,
              "human_count": 16, "animal_count": 18, "visual_reviews": 34,
              "dimensions": sorted({str(a["technical"]["width"])+"x"+str(a["technical"]["height"]) for a in assets}),
              "original_image_bytes": sum(a["technical"]["bytes"] for a in assets),
              "runtime_changed": False, "model_validation": "not performed; awaiting user-generated models"}
    write_json("delivery-checks.json", checks)

    rows = []
    for c in characters:
        kind = "人物" if c["type"] == "human" else "动物"
        rows.append("| %02d | %s | %s · %s | %s | [%s](%s) | %s.glb |" %
                    (c["order"], c["building_name"], c["name_zh"], c["role"], kind,
                     c["file"], c["file"], c["id"]))
    readme = """# 字母岛 · 34 位建筑居民参考图 v01

已完成 26 座字母建筑和 8 个校园场所的独立角色图：**16 位人物、18 位动物**。生成日期：2026-11-12。

## 选图与生成

1. 打开 [角色总览](index.html)，可按姓名、建筑和职业搜索，也可筛选人物、动物与校园。
2. 每次向 Tripo3D 上传一张独立的 **`*_front.png`**。总览截图只用于对照。
3. 生成的 GLB 按下表最后一列命名，便于下一步将模型、房间和对话身份对应起来。

[整套总览图片](preview/overview.png) · [美术简报](art-direction-brief.md) · [完整生成提示词](generation-plan.json)

图片为白底、单角色、正面全身，双臂轻展、双手空置。原始 PNG 保留内置图像生成工具的输出，未裁切、重新编码或压缩。

## 建筑、角色与文件

| 编号 | 建筑 / 场所 | 角色 · 职业 | 类别 | Tripo 输入图片 | 建议模型文件名 |
|---|---|---|---|---|---|
""" + "\n".join(rows) + """

## 交付记录

- `manifest.json`：建筑、居民、图片、模型文件名映射，尺寸、哈希和逐图目视检查记录。
- `generation-plan.json`：34 个完整提示词、配色、造型设计与参考图路径。
- `generation-records.json`：每张图的原始生成路径和保存记录。
- `delivery-checks.json`：34 个场所覆盖、图片完整性、尺寸与原始字节一致性检查。
- `art-direction-brief.md`：画风、适用范围及模型交接要求。

现阶段交付为“参考图已生成并检查”。Tripo 模型尚待生成；场景 NPC、对话和任务仍待模型导入后统一接入。玩家住宅未配置新的居民。

白底、单主体、柔光及 A 姿势的选择参考 [Tripo 官方输入图指南](https://www.tripo3d.ai/help/features/how-to-get-better-image-to-3d-results)。正面图之外的侧背结构、尾巴连接、手指、关节和衣服厚度需在模型生成后检查。
"""
    (ROOT / "README.md").write_text(readme, encoding="utf-8")
    def card(c, prefix=""):
        e = html.escape
        section = "campus" if c["order"] > 26 else "island"
        search = e(" ".join([c["name_zh"],c["name_en"],c["building_name"],c["role"],c["id"],c["building_code"]]), quote=True)
        image_path = prefix + c["file"]
        return f"""<article class="card" data-type="{c['type']}" data-section="{section}" data-search="{search}">
<a class="picture" href="{image_path}" target="_blank" aria-label="查看 {e(c['name_zh'])} 原图"><img src="{image_path}" alt="{e(c['name_zh'])} · {e(c['role'])}" width="1254" height="1254"></a>
<div class="caption"><div class="place"><span class="number">{c['order']:02d}</span> {e(c['building_name'])}</div>
<h2>{e(c['name_zh'])}<small>{e(c['role'])}</small></h2>
<p class="design">{e(c['design_zh'])}</p>
<a class="download" href="{image_path}" download="{c['file']}">保存原图 ↗</a>
</div></article>"""

    style = """*{box-sizing:border-box}body{margin:0;background:#f7f4ee;color:#263b32;font-family:"Microsoft YaHei","Segoe UI",sans-serif}main{max-width:1460px;margin:auto;padding:48px 36px 60px}header{border-bottom:1px solid #d4dbd0;padding-bottom:25px;margin-bottom:24px}.eyebrow{font-size:12px;letter-spacing:3px;color:#7c6853}h1{font-size:38px;font-weight:650;margin:12px 0 9px;letter-spacing:1px}.intro{font-size:15px;color:#617066;line-height:1.9;margin:0}.links{margin-top:13px;display:flex;gap:22px;flex-wrap:wrap}a{color:#386955;text-decoration:none}a:hover{text-decoration:underline}a:focus-visible,button:focus-visible,input:focus-visible{outline:3px solid #d68d43;outline-offset:3px}.toolbar{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin-bottom:26px}input{font:inherit;flex:1;min-width:210px;max-width:450px;border:1px solid #cdd7cb;border-radius:5px;padding:11px 14px;background:#fff}button{font:inherit;border:1px solid #cdd7cb;border-radius:5px;padding:10px 18px;background:transparent;color:#386955;cursor:pointer}button[aria-pressed=true]{background:#376550;color:#fff;border-color:#376550}#count{font-size:13px;color:#69786b;margin-left:auto}.grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:28px 20px}.card{min-width:0;border-bottom:1px solid #d8ded4;padding-bottom:18px}.picture{display:block;background:white;border-radius:5px;overflow:hidden}.picture img{width:100%;height:auto;display:block;aspect-ratio:1;object-fit:contain}.caption{padding:13px 3px 0}.place{font-size:12px;color:#758274;white-space:nowrap}.number{color:#a78154;margin-right:4px;font-variant-numeric:tabular-nums}h2{font-size:22px;font-weight:650;margin:7px 0}h2 small{display:block;font-size:12px;font-weight:400;color:#5f7562;margin-top:6px}.design{font-size:12px;line-height:1.75;color:#667365;min-height:43px;margin:9px 0}.download{font-size:12px}.footer{padding-top:28px;font-size:12px;color:#7b8075;line-height:1.9}.card[hidden]{display:none}@media(max-width:1150px){.grid{grid-template-columns:repeat(4,minmax(0,1fr))}}@media(max-width:850px){main{padding:28px 20px}.grid{grid-template-columns:repeat(3,minmax(0,1fr))}}@media(max-width:580px){.grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:20px 14px}h1{font-size:29px}.place{white-space:normal}h2{font-size:19px}.design{min-height:65px}}"""
    scripts = """const q=document.getElementById('query');let mode='all';const cards=[...document.querySelectorAll('.card')];function update(){const needle=q.value.trim().toLowerCase();let count=0;for(const c of cards){const found=c.dataset.search.toLowerCase().includes(needle);const type=mode==='all'||c.dataset.type===mode||c.dataset.section===mode;c.hidden=!(found&&type);if(!c.hidden)count++}document.getElementById('count').textContent=count+' / 34 位';}q.addEventListener('input',update);document.querySelectorAll('button[data-mode]').forEach(b=>b.addEventListener('click',()=>{mode=b.dataset.mode;document.querySelectorAll('button[data-mode]').forEach(n=>n.setAttribute('aria-pressed',String(n===b)));update()}));update();"""
    top = """<header><div class="eyebrow">ALPHABET ISLAND · RESIDENTS V01</div><h1>字母岛的建筑居民</h1><p class="intro">34 个场所，34 位独立角色。16 位人物与 18 位动物，带着各自的职业和故事，住进字母岛。</p><div class="links"><a href="README.md">建筑与角色对照</a><a href="generation-plan.json">完整生成提示词</a><a href="preview/overview.png">查看整套总览</a></div></header>"""
    toolbar = """<div class="toolbar"><input id="query" type="search" placeholder="搜索名字、建筑或职业" aria-label="搜索角色"><button data-mode="all" aria-pressed="true">全部</button><button data-mode="human" aria-pressed="false">人物</button><button data-mode="animal" aria-pressed="false">动物</button><button data-mode="campus" aria-pressed="false">校园</button><span id="count" aria-live="polite">34 / 34 位</span></div>"""
    footer = """<p class="footer">点击角色查看独立原图。上传 Tripo3D 时，每次使用一张 *_front.png。当前为角色参考图；模型生成和游戏接入在后续阶段完成。<br>2026-11-12 · 内置图像生成工具 · PNG 原图保留</p>"""
    page = '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>字母岛 · 34 位建筑居民</title><style>'+style+'</style><main>'+top+toolbar+'<section class="grid" aria-label="角色图集">'+"".join(card(c) for c in characters)+'</section>'+footer+'</main><script>'+scripts+'</script></html>'
    (ROOT / "index.html").write_text(page,encoding="utf-8")
    preview = ROOT / "preview"
    preview.mkdir(exist_ok=True)
    overview_style = style + """main{max-width:none;padding:30px 32px 24px}header{padding-bottom:16px;margin-bottom:18px}h1{font-size:30px;margin:7px 0}.intro{font-size:13px}.grid{grid-template-columns:repeat(6,minmax(0,1fr));gap:16px 18px}.card{padding-bottom:10px}.caption{padding-top:8px}.place{font-size:12px}h2{font-size:18px;margin:5px 0 0;display:flex;align-items:baseline;gap:9px}h2 small{font-size:11px;margin-top:0}.picture{border-radius:3px}.design,.download,.links{display:none}.footer{padding-top:15px;font-size:11px;margin-bottom:0}"""
    overview_top = top.replace('href="README.md"','href="../README.md"')
    overview = '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>建筑居民总览</title><style>'+overview_style+'</style><main>'+overview_top+'<section class="grid">'+"".join(card(c,"../") for c in characters)+'</section><p class="footer">26 座字母建筑 + 8 个校园场所 · 角色正面参考图 · 上传 Tripo 时请使用独立 PNG</p></main></html>'
    (preview / "overview.html").write_text(overview,encoding="utf-8")
    if package:
        assert (preview / "overview.png").is_file(), "Render overview first"
        archive = ROOT.parent / (ROOT.name + ".zip")
        names = sorted([p for p in ROOT.rglob("*") if p.is_file() and "__pycache__" not in p.parts])
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
            for path in names:
                z.write(path, ROOT.name + "/" + path.relative_to(ROOT).as_posix())
        with zipfile.ZipFile(archive) as z:
            assert z.testzip() is None
            assert sum(n.endswith("_front.png") for n in z.namelist()) == 34
        print(json.dumps({"archive":str(archive),"bytes":archive.stat().st_size,"files":len(names)},ensure_ascii=False))
    print(json.dumps(checks,ensure_ascii=False))

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", action="store_true")
    build(parser.parse_args().package)
