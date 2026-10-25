"""Build an offline gallery from the 44 verified native before/after scene pairs."""
from pathlib import Path
import hashlib,json,re,struct

ROOT=Path(__file__).resolve().parents[1]
PROOF=ROOT/'docs/verification/world-refinement'

def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def main():
    base=json.loads((ROOT/'docs/planning/world-refinement/baseline.json').read_text('utf-8'))
    names={r['room_id']:r['name'] for r in base['rooms']}
    scenes=[];all_images=[]
    for folder in sorted((PROOF/'after').iterdir()):
        if not re.fullmatch(r'\d\d',folder.name):continue
        after=json.loads((folder/'report.json').read_text('utf-8'))
        before=json.loads((PROOF/'before'/folder.name/'report.json').read_text('utf-8'))
        assert after['result']==before['result']=='PASS'
        assert after['rooms']==before['rooms']
        checks={c['id']:c['passed'] for c in after['checks']}
        for path,digest in after['source_sha256'].items():
            assert sha(ROOT/'game'/path.removeprefix('res://'))==digest,('Stale native capture',path)
        for room in after['rooms']:
            item={'id':room,'name':names[room],'group':'字母场所' if room.startswith('landmark_') else '家园' if room.startswith('home') else '主岛' if room=='village' else '校园','views':{}}
            for view in ['production','overview']:
                cid=room+'-'+view
                assert checks['same_camera_as_before/'+cid]
                pair={}
                for stage in ['before','after']:
                    path=PROOF/stage/folder.name/(cid+'.png')
                    with path.open('rb') as stream:
                        header=stream.read(24)
                    assert header[:8]==b'\x89PNG\r\n\x1a\n' and header[12:16]==b'IHDR'
                    assert struct.unpack('>II',header[16:24])==(1440,900)
                    pair[stage]=path.relative_to(ROOT/'docs').as_posix()
                    all_images.append({'path':pair[stage],'sha256':sha(path)})
                item['views'][view]=pair
            scenes.append(item)
    assert len(scenes)==44 and len({s['id'] for s in scenes})==44
    page='''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>字母岛 · 全场景精修对照</title>
<style>
:root{font-family:"Segoe UI","Microsoft YaHei",sans-serif;color:#2c4036;background:#f5f2e9}*{box-sizing:border-box}body{margin:0}main{max-width:1540px;margin:auto;padding:30px 24px 45px}h1{font-size:29px;font-weight:600;margin:8px 0}p{color:#617064;line-height:1.7}header{display:flex;align-items:end;justify-content:space-between;gap:20px}.eyebrow{font-size:12px;letter-spacing:3px;color:#7a8b76}.badge{font-size:13px;border:1px solid #bfcbbd;border-radius:8px;padding:10px 14px;white-space:nowrap}.layout{display:grid;grid-template-columns:224px 1fr;gap:20px;margin-top:25px}aside{max-height:740px;overflow:auto;padding:0 9px 0 0}button,select{font:inherit;color:inherit;background:#fffcf4;border:1px solid #cdd4c5;border-radius:6px;padding:9px 12px;cursor:pointer}button[aria-pressed=true]{color:#fff;background:#4a6e55;border-color:#4a6e55}button:hover{border-color:#7a9479}button:focus-visible,input:focus-visible,select:focus-visible,a:focus-visible{outline:3px solid #c18d4f;outline-offset:3px}select{width:100%;margin-bottom:10px}.room{display:block;width:100%;text-align:left;margin:5px 0;font-size:14px}.room small{color:inherit;opacity:.7;font-size:11px;margin-right:5px}.toolbar{display:flex;align-items:center;gap:9px;flex-wrap:wrap;margin-bottom:12px}.toolbar strong{font-size:18px;margin-right:auto}.viewer{position:relative;aspect-ratio:8/5;background:#dde2d7;border:1px solid #d1d8c9;border-radius:10px;overflow:hidden}.viewer img{position:absolute;width:100%;height:100%;object-fit:contain}.viewer .after{clip-path:inset(0 0 0 var(--split,50%))}.line{position:absolute;inset:0 auto 0 var(--split,50%);width:2px;background:#fff;pointer-events:none}.tag{position:absolute;top:14px;background:#fcfaf3ef;padding:6px 10px;border-radius:5px;font-size:12px}.left{left:14px}.right{right:14px;background:#4a6e55ed;color:#fff}.controls{display:flex;align-items:center;gap:15px;margin-top:15px;font-size:14px}input{flex:1;accent-color:#4a6e55;min-width:60px}.links{display:flex;gap:20px;flex-wrap:wrap;font-size:13px}a{color:#426c50;text-underline-offset:3px}.note{font-size:13px;margin:13px 0}.scope{border-top:1px solid #d1d8c9;margin-top:25px;padding-top:14px;font-size:13px}.count{font-size:12px;margin:6px 0;color:#71816f}
@media(max-width:800px){main{padding:20px 12px}.layout{display:block}header{display:block}.badge{display:inline-block}aside{max-height:158px;display:flex;gap:6px;flex-wrap:wrap;margin-bottom:18px;padding:0}aside select{width:100%;margin:0}.room{width:auto;margin:0;padding:7px 9px;font-size:12px}.count{display:none}h1{font-size:25px}.toolbar strong{width:100%}.tag{top:8px}.left{left:8px}.right{right:8px}}
</style></head><body><main><header><div><div class="eyebrow">ALPHABET ISLAND / WORLD REFINEMENT</div><h1>从小院，走到整座字母岛</h1><p>44 个现有场景的模型、材质与灯光精修。选择地点，拖动滑杆查看同机位前后画面。</p></div><span class="badge">44 场景 · 88 组对照 · 原生实拍</span></header>
<div class="layout"><aside aria-label="场景目录"><select id="group" aria-label="筛选地点"><option>全部地点</option><option>主岛</option><option>字母场所</option><option>校园</option><option>家园</option></select><div class="count" id="count"></div><div id="rooms"></div></aside><section aria-label="画面对照"><div class="toolbar"><strong id="title"></strong><button id="production" aria-pressed="true">游戏镜头</button><button id="overview" aria-pressed="false">全景复核</button></div>
<div class="viewer" id="viewer"><img id="before" alt="本轮精修前的游戏画面"><img class="after" id="after" alt="本轮精修后的游戏画面"><div class="line"></div><span class="tag left">本轮之前</span><span class="tag right">精修之后</span></div><div class="controls"><label for="split">左右对照</label><input id="split" type="range" min="0" max="100" value="50"><output for="split" id="percent">50%</output></div><p class="note" id="note"></p><div class="links"><a id="full-before" target="_blank">打开修改前原图</a><a id="full-after" target="_blank">打开精修后原图</a><a href="verification/world-refinement/README.md">查看验收记录</a><a href="verification/world-refinement/asset-report.json">查看资产检查</a></div></section></div>
<div class="scope"><p>全部图片为 Godot 1440 × 900 原生截图，固定晴天白昼、同一机位，使用隔离存档。全景复核隐藏界面，用于看清场景；游戏镜头保留默认入场视角。相机一致性均已通过数值校验。</p><p>小院与客厅沿用上一批样板，本轮以其完成状态作为基线。其余场景细化树冠、木材、布料、石材、家具收边及主题道具；碰撞、门口和固定记忆点经过独立通行检查。这里记录现有 44 个场景的美术范围。</p></div></main>
<script id="scene-data" type="application/json">__SCENES__</script><script>
const scenes=JSON.parse(document.querySelector('#scene-data').textContent);let index=0,view='production';const q=s=>document.querySelector(s);
function render(){const s=scenes[index],p=s.views[view];q('#title').textContent=s.name;q('#before').src=p.before;q('#after').src=p.after;q('#full-before').href=p.before;q('#full-after').href=p.after;q('#before').alt=s.name+' · 本轮精修前';q('#after').alt=s.name+' · 精修后';q('#note').textContent=view==='production'?'默认入场镜头，保留游戏界面。相机位置、朝向与正交尺寸一致。':'固定全景复核镜头，隐藏界面；用于检查场景完整性。相机位置、朝向与正交尺寸一致。';for(const mode of ['production','overview'])q('#'+mode).setAttribute('aria-pressed',String(view===mode));for(const b of q('#rooms').children)b.setAttribute('aria-pressed',String(Number(b.dataset.index)===index));location.hash=scenes[index].id+'/'+view}
function list(){const group=q('#group').value;const items=scenes.map((s,i)=>({s,i})).filter(x=>group==='全部地点'||x.s.group===group);q('#rooms').replaceChildren();q('#count').textContent=items.length+' 个地点';for(const {s,i} of items){const b=document.createElement('button');b.className='room';b.dataset.index=i;b.textContent=s.name;b.setAttribute('aria-pressed',String(i===index));b.onclick=()=>{index=i;render()};q('#rooms').append(b)}}
q('#group').onchange=list;for(const mode of ['production','overview'])q('#'+mode).onclick=()=>{view=mode;render()};q('#split').oninput=e=>{q('#viewer').style.setProperty('--split',e.target.value+'%');q('#percent').value=e.target.value+'%'};
const initial=location.hash.slice(1).split('/');const found=scenes.findIndex(s=>s.id===initial[0]);if(found>=0)index=found;if(initial[1]==='overview')view='overview';list();render();
</script></body></html>'''
    output=ROOT/'docs/world-refinement.html'
    output.write_text(page.replace('__SCENES__',json.dumps(scenes,ensure_ascii=False).replace('<','\\u003c')),encoding='utf-8')
    report={'result':'PASS','scenes':len(scenes),'pairs':len(scenes)*2,'images':all_images,'same_camera_pairs':len(scenes)*2,'html_sha256':sha(output),'validation':'Static image existence, dimensions, SHA256, capture pass state, current runtime source hashes and recorded camera checks; no browser rendering claim.'}
    (PROOF/'gallery-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'scenes':len(scenes),'pairs':len(scenes)*2,'native_images':len(all_images),'path':str(output)},ensure_ascii=False))

if __name__=='__main__':main()
