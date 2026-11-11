"""Show the synchronized environment models using this machine's native captures."""
import json
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
current = json.loads((ROOT / "assets/blender/interiors/interiors_manifest.json").read_text(encoding="utf-8-sig"))
if all(r.get("refinement_revision") == "texture-world-20261105" for r in current["rooms"]):
    runpy.run_path(str(ROOT / "scripts/texture_world_20261105/gallery.py"), run_name="__main__")
    raise SystemExit(0)
if all(r.get("refinement_revision") == "cozy-world-20261105" for r in current["rooms"]):
    runpy.run_path(str(ROOT / "scripts/cozy_world_20261105/gallery.py"), run_name="__main__")
    raise SystemExit(0)
PROOF = ROOT / "docs/verification/drive-model-sync-own16-20261027"
sync = json.loads((PROOF / "sync-report.json").read_text(encoding="utf-8"))
interiors = json.loads((ROOT / "game/data/interiors_manifest.json").read_text(encoding="utf-8"))
names = {r["room_id"]: r["name"] for r in interiors["rooms"]}
names["island"] = "字母岛 · 主岛"
rows = []
for model in sync["models"]:
    rid = model["room_id"]
    group = "主岛" if rid == "island" else "家庭" if rid.startswith("home") else "字母场景" if rid.startswith("landmark_") else "校园"
    camera_id = "village" if rid == "island" else rid
    rows.append({"id": rid, "name": names[rid], "group": group,
        "play": f"verification/drive-model-sync-own16-20261027/native/{camera_id}-play.png",
        "overview": f"verification/drive-model-sync-own16-20261027/native/{camera_id}-overview.png",
        "source": "../" + model["preview"], "blend": "../" + model["source_blend"],
        "version": Path(model["source_blend"]).stem,
        "sha256": model["incoming_sha256"]})
order = {"主岛": 0, "家庭": 1, "校园": 2, "字母场景": 3}
rows.sort(key=lambda r: (order[r["group"]], r["id"]))
missing = [r[k] for r in rows for k in ("play", "overview") if not (ROOT / "docs" / r[k]).is_file()]
assert not missing, f"Native captures missing: {missing}"
template = '''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>字母岛 · 最新本地模型</title><style>
:root{color-scheme:light;--ink:#2e4339;--muted:#63766a;--green:#567b65;--line:#d9ddcf}*{box-sizing:border-box}body{margin:0;background:#f5f3e9;color:var(--ink);font:16px/1.65 "Microsoft YaHei",system-ui,sans-serif}main{max-width:1450px;margin:auto;padding:38px 4vw 60px}.kicker{font-size:12px;letter-spacing:.17em;color:var(--green)}h1{font-size:clamp(30px,4vw,48px);line-height:1.3;margin:12px 0 14px}h2{font-size:25px;margin:0}p{margin:0 0 18px}.intro{max-width:800px;color:var(--muted)}.status{display:flex;gap:25px;flex-wrap:wrap;font-size:14px;padding:16px 0;border-block:1px solid var(--line);margin:24px 0 28px}a{color:#3e7054}button{font:inherit;cursor:pointer;color:var(--ink);background:#fffdf6;border:1px solid var(--line);border-radius:7px;padding:8px 14px}button[aria-pressed=true]{color:white;background:var(--green);border-color:var(--green)}button:focus-visible,a:focus-visible{outline:3px solid #ba8f4c;outline-offset:4px}.viewer-heading{display:flex;gap:20px;justify-content:space-between;align-items:end;margin-bottom:12px}.modes,.filters{display:flex;gap:8px;flex-wrap:wrap}.hero{display:block;width:100%;aspect-ratio:8/5;object-fit:contain;background:#dfdfd0;border-radius:8px}.caption{font-size:13px;color:var(--muted);margin:10px 0 22px}.source-row{display:flex;gap:18px;flex-wrap:wrap;align-items:center;font-size:13px;margin-bottom:32px}.source-row code{overflow-wrap:anywhere;color:#758277}.filters{border-top:1px solid var(--line);padding-top:26px;margin:26px 0 18px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:22px}.tile{text-align:left;padding:0;overflow:hidden;border-radius:8px}.tile img{display:block;width:100%;aspect-ratio:8/5;object-fit:contain;background:#dfdfd0}.tile span{display:block;padding:12px 14px;font-size:15px}.tile small{display:block;color:var(--muted);font-size:12px}.tile.selected{outline:3px solid var(--green);outline-offset:2px}.links{display:flex;flex-wrap:wrap;gap:20px;border-top:1px solid var(--line);padding-top:25px;margin-top:32px;font-size:14px}.notice{font-size:13px;color:var(--muted);margin-top:18px}@media(max-width:850px){.viewer-heading{display:block}.modes{margin-top:13px}.grid{grid-template-columns:repeat(2,minmax(0,1fr))}main{padding:24px 18px}}@media(max-width:520px){.grid{grid-template-columns:1fr}.status{gap:12px}button{font-size:14px}}
</style></head><body><main>
<div class="kicker">ALPHABET ISLAND / LOCAL MODEL COLLECTION</div><h1>最新模型，已同步到本地。</h1>
<p class="intro">2026年10月27日 own16 版本：主岛、家庭、校园和26个字母场景，共44套环境模型。下方画面来自替换后在本机运行的 Godot 工程，可以切换正常游玩镜头、场景总览和 Blender 源预览。</p>
<div class="status"><span>44 / 44 运行模型与云端哈希一致</span><span>44套 Blender / GLB / 预览已保存</span><span>旧源文件与存档保留</span></div>
<section id="viewer"><div class="viewer-heading"><div><div id="group" class="kicker"></div><h2 id="name"></h2></div><nav class="modes" aria-label="选择查看镜头"><button data-mode="overview" aria-pressed="true">场景总览</button><button data-mode="play" aria-pressed="false">正常游玩镜头</button><button data-mode="source" aria-pressed="false">Blender 源预览</button></nav></div><a id="full" target="_blank"><img id="hero" class="hero" alt="最新模型画面"></a><p id="caption" class="caption" aria-live="polite"></p><div class="source-row"><a id="blend">打开 Blender 源文件</a><span id="version"></span><code id="hash"></code></div></section>
<nav class="filters" aria-label="按区域筛选"><button data-group="全部" aria-pressed="true">全部 · 44</button><button data-group="主岛" aria-pressed="false">主岛 · 1</button><button data-group="家庭" aria-pressed="false">家庭 · 9</button><button data-group="校园" aria-pressed="false">校园 · 8</button><button data-group="字母场景" aria-pressed="false">字母场景 · 26</button></nav><div id="grid" class="grid"></div>
<div class="links"><a href="verification/drive-model-sync-own16-20261027/README.md">本次同步与验证记录</a><a href="verification/drive-model-sync-own16-20261027/sync-report.json">44个模型与源文件清单</a><a href="verification/drive-model-sync-own16-20261027/headless-validation.md">实际行走与房间交互验证</a><a href="verification/drive-model-sync-own16-20261027/baseline-notes.md">替换前备份与恢复说明</a><a href="https://drive.google.com/drive/folders/1bqluU1N8p1e_igYxvX7enMd_YrlbvydR" target="_blank">云端交付目录</a></div>
<p class="notice">总览使用检视镜头，正常游玩镜头保留游戏界面；场景图用于检查模型显示，实际门链、行走和家务由独立运行验证覆盖。Blender源预览使用云端交付的原图。own16是本次同步批次，各场景保留各自版本号。</p>
</main><script>
const models=__DATA__;let selected=models[0],mode='overview',filter='全部';const captions={overview:'本机 Godot 原生截图 · 检视镜头，隐藏界面，查看场景整体。',play:'本机 Godot 原生截图 · 正常游玩镜头与游戏界面。',source:'云端交付的 Blender 源预览 · 与当前可编辑工程配套。'};function show(row){selected=row;document.getElementById('name').textContent=row.name;document.getElementById('group').textContent=row.group;document.getElementById('hero').src=row[mode];document.getElementById('hero').alt=row.name+' · '+captions[mode];document.getElementById('full').href=row[mode];document.getElementById('caption').textContent=captions[mode];document.getElementById('blend').href=row.blend;document.getElementById('version').textContent=row.version;document.getElementById('hash').textContent='SHA256 '+row.sha256.slice(0,16)+'…';document.querySelectorAll('[data-mode]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.mode===mode)));document.querySelectorAll('[data-id]').forEach(b=>b.classList.toggle('selected',b.dataset.id===row.id))}function render(){const grid=document.getElementById('grid');grid.replaceChildren();models.filter(r=>filter==='全部'||r.group===filter).forEach(row=>{const button=document.createElement('button');button.className='tile';button.dataset.id=row.id;const image=document.createElement('img');image.src=row.overview;image.alt=row.name+'总览';image.loading='lazy';const label=document.createElement('span');label.textContent=row.name;const sub=document.createElement('small');sub.textContent=row.group+' / '+row.id;label.append(sub);button.append(image,label);button.onclick=()=>{show(row);document.getElementById('viewer').scrollIntoView({behavior:'smooth',block:'start'})};grid.append(button)});show(selected)}document.querySelectorAll('[data-mode]').forEach(button=>button.onclick=()=>{mode=button.dataset.mode;show(selected)});document.querySelectorAll('[data-group]').forEach(button=>button.onclick=()=>{filter=button.dataset.group;document.querySelectorAll('[data-group]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));render()});render();</script></body></html>'''
output = ROOT / "docs/models-latest-gallery.html"
output.write_text(template.replace("__DATA__", json.dumps(rows, ensure_ascii=False)), encoding="utf-8")
print(json.dumps({"output": str(output), "models": len(rows), "native_images": len(rows) * 2}, ensure_ascii=False))
