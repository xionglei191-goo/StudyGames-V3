"""Build the local, source-backed native before/after comparison."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / 'docs/verification/visual-refinement'


def main():
    before = json.loads((EVIDENCE / 'before/report.json').read_text('utf-8'))
    after = json.loads((EVIDENCE / 'after/report.json').read_text('utf-8'))
    if before['result'] != 'PASS' or after['result'] != 'PASS':
        raise SystemExit('Cannot publish a comparison with failed native capture checks.')
    checks = {item['id']: item['passed'] for item in after['checks']}
    layout_path = ROOT / 'docs/verification/home-display-layout/report.json'
    layout_captures = {}
    if layout_path.is_file() and layout_path.stat().st_mtime > (EVIDENCE / 'after/report.json').stat().st_mtime:
        layout = json.loads(layout_path.read_text('utf-8'))
        if not layout['passed']:
            raise SystemExit('The newer home display layout has failed native checks.')
        layout_captures = {item['id']: item for item in layout['captures']}
        checks.update({item['id']: item['passed'] for item in layout['checks']})
    pairs = []
    for item in after['captures']:
        capture_id = item['id']
        latest_home = capture_id in layout_captures
        if not any(value['id'] == capture_id for value in before['captures']):
            raise SystemExit(f'Missing baseline capture: {capture_id}')
        before_image = EVIDENCE / 'before' / f'{capture_id}.png'
        after_image = (layout_path.parent if latest_home else EVIDENCE / 'after') / f'{capture_id}.png'
        if not before_image.is_file() or not after_image.is_file():
            raise SystemExit(f'Missing comparison image: {capture_id}')
        room, view = capture_id.split('-', 1)
        pairs.append({'id': capture_id,
                      'name': ('小院' if room == 'home_estate' else '客厅') + ' · ' + {'production': '游戏镜头', 'overview': '全景复核', 'detail': '细节复核'}[view],
                      'note': '原生游戏默认入场镜头，包含 HUD。' if view == 'production' else '固定美术复核镜头，隐藏 HUD；不是默认游玩视角。',
                      'same_camera': checks.get('same_camera_as_before/' + capture_id, False),
                      'before': f'verification/visual-refinement/before/{capture_id}.png',
                      'after': after_image.relative_to(ROOT / 'docs').as_posix()})
    html = '''<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>字母岛 · 家园画质样板</title><style>
:root{font-family:"Segoe UI","Microsoft YaHei",sans-serif;color:#283c35;background:#f6f3ec}*{box-sizing:border-box}
body{margin:0}main{max-width:1280px;margin:auto;padding:36px 24px 60px}header{display:flex;justify-content:space-between;gap:24px;align-items:end}
h1{font-size:30px;letter-spacing:1px;margin:10px 0}p{color:#62746a;line-height:1.7;margin:8px 0}.eyebrow{font-size:12px;letter-spacing:3px;color:#6b806f}
.status{font-size:13px;padding:10px 14px;border:1px solid #c9d5ca;border-radius:8px;white-space:nowrap}
nav{display:flex;gap:8px;flex-wrap:wrap;margin:26px 0 18px}button{font:inherit;background:transparent;border:1px solid #c8d0c7;color:#435c4d;padding:10px 14px;border-radius:7px;cursor:pointer}
button[aria-pressed=true]{background:#456c55;border-color:#456c55;color:white}button:focus-visible,input:focus-visible{outline:3px solid #bf9253;outline-offset:3px}
.viewer{position:relative;aspect-ratio:8/5;background:#dce1d7;border-radius:12px;overflow:hidden;border:1px solid #d1d7cb}
.viewer img{position:absolute;width:100%;height:100%;object-fit:contain}.viewer .after{clip-path:inset(0 0 0 var(--split,50%))}
.line{position:absolute;top:0;bottom:0;left:var(--split,50%);width:2px;background:white;box-shadow:0 0 0 1px #394e4944;pointer-events:none}
.tag{position:absolute;top:18px;background:#fbfaf5ee;padding:7px 12px;border-radius:6px;font-size:13px;box-shadow:0 2px 6px #0001}.left{left:18px}.right{right:18px;background:#456c55ee;color:white}
.controls{display:flex;gap:18px;align-items:center;margin:18px 0;font-size:14px}input{flex:1;accent-color:#456c55;cursor:ew-resize;min-width:80px}.links{display:flex;flex-wrap:wrap;gap:20px;margin-top:24px}a{color:#456c55;text-underline-offset:4px}
.scope{border-top:1px solid #d8ded4;margin-top:28px;padding-top:18px;font-size:13px}.stats{font-size:13px;font-variant-numeric:tabular-nums}
@media(max-width:680px){main{padding:24px 14px}header{display:block}h1{font-size:25px}.status{display:inline-block}button{font-size:13px;padding:9px}.tag{top:9px}.left{left:9px}.right{right:9px}}
</style><main><header><div><div class="eyebrow">ALPHABET ISLAND / VISUAL STUDY 01</div><h1>把小院与客厅打磨细一点</h1><p>模型、材质与光照的同机位实机对照。拖动下方滑杆，查看修改前后。</p></div><div class="status">Godot 原生截图 · 1440 × 900</div></header>
<nav aria-label="选择对比场景" id="tabs"></nav>
<div class="viewer" id="viewer"><img id="before" alt="修改前的游戏画面"><img class="after" id="after" alt="精修后的游戏画面"><div class="line"></div><span class="tag left">修改前</span><span class="tag right">精修后</span></div>
<div class="controls"><label for="split">左右对照</label><input id="split" type="range" min="0" max="100" value="50" aria-label="修改前画面占比"><output id="percent" for="split">50%</output></div>
<p id="note"></p><p class="stats" id="camera"></p>
<div class="links"><a id="full-before" target="_blank">打开修改前原图</a><a id="full-after" target="_blank">打开精修后原图</a><a href="verification/visual-refinement/README.md">查看验收说明</a><a href="verification/visual-refinement/asset-report.json">源资产检查</a></div>
<div class="scope"><p>本批样板：院子树冠、地表与材质；客厅软装、木地板与小物件；两室明暗层次。保留旧版 Blender 源文件。</p><p>截图使用隔离存档并固定晴天白昼。图片用于美术对比，通行与交互由单独的运行报告验证。全景与细节是复核镜头，游戏镜头页才是默认游玩视角。性能数据仅代表本机采样。</p></div></main>
<script>const pairs=__PAIRS__;const viewer=document.querySelector('#viewer');const tabs=document.querySelector('#tabs');
function select(index){const p=pairs[index];document.querySelector('#before').src=p.before;document.querySelector('#after').src=p.after;document.querySelector('#full-before').href=p.before;document.querySelector('#full-after').href=p.after;document.querySelector('#note').textContent=p.note;document.querySelector('#camera').textContent='相机位置、角度、正交尺寸：'+(p.same_camera?'一致':'请参阅验收记录的浮点容差校验');[...tabs.children].forEach((b,i)=>b.setAttribute('aria-pressed',String(i===index)));}
pairs.forEach((p,i)=>{const b=document.createElement('button');b.textContent=p.name;b.addEventListener('click',()=>select(i));tabs.append(b)});document.querySelector('#split').addEventListener('input',e=>{viewer.style.setProperty('--split',e.target.value+'%');document.querySelector('#percent').value=e.target.value+'%'});select(pairs.findIndex(p=>p.id==='home-detail'));</script></html>'''
    path = ROOT / 'docs/visual-refinement.html'
    path.write_text(html.replace('__PAIRS__', json.dumps(pairs, ensure_ascii=False)), encoding='utf-8')
    print(path)


if __name__ == '__main__':
    main()
