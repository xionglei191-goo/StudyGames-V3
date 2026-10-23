"""Record verified Tripo integration and build a local, source-linked gallery."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / 'docs/verification/tripo-characters-v1'
ASSETS = ROOT / 'assets/characters/tripo_v1'
NAMES = {
    'player':'旅行小女孩', 'textbook_lingling':'Lingling 玲玲',
    'textbook_peter':'Peter', 'textbook_anne':'Anne',
    'textbook_mingming':'Mingming 明明', 'textbook_dongdong':'Dongdong 东东',
    'textbook_tim':'Tim', 'textbook_miss_li':'Miss Li 李老师',
    'textbook_dino':'Dino', 'npc_bear_uncle':'熊叔',
    'npc_rabbit_gardener':'兔兔园丁', 'textbook_jim':'Jim',
}

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def write(path, value):
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def sha(path):
    return hashlib.file_digest(path.open('rb'),'sha256').hexdigest()

def main():
    reports = {name:read(REPORTS/file) for name,file in {
        'characters':'native-1440x900-characters.json',
        'actions':'p1-actor-animation.json',
        'gameplay':'native-1440x900-gameplay.json',
        'orchard':'orchard-integration.json',
        'preservation':'preservation.json',
        'greeting':'../tripo-wave-refinement/wave-regression.json',
    }.items()}
    for name,report in reports.items():
        assert report['status'].lower() in ('pass','passed'),f'{name} is not passing'
    assert reports['characters']['tested_character_count']==12
    for path,expected in reports['characters']['runtime_sha256'].items():
        actual = ROOT/'game'/path.removeprefix('res://')
        assert actual.is_file() and sha(actual)==expected,f'Validation is stale: {path}'
    originals = read(ASSETS/'preservation-before.json')
    assert all(sha(ROOT/row['path'])==row['sha256'] for row in originals)
    manifest = read(ROOT/'game/assets/characters/tripo_v1/manifest.json')
    assert set(manifest['characters'])==set(NAMES)
    rows=[]
    for character_id,name in NAMES.items():
        rig_path=ASSETS/character_id/'rig.json'
        rig=read(rig_path)
        entry=manifest['characters'][character_id]
        provider=rig.get('rigging_provider',{})
        mixamo=provider.get('provider')=='Adobe Mixamo'
        if mixamo:
            assert sha(ROOT/provider['source_file'])==provider['source_sha256']
        assert rig['unweighted_vertices']==0
        for filename in ('rigged.blend','character.glb'):
            assert (ASSETS/character_id/filename).stat().st_size>1000
        rig['status']='validated_in_godot'
        rig['validation']={
            'engine':'Godot 4.7.2',
            'native_report':'docs/verification/tripo-characters-v1/native-1440x900-characters.json',
            'scope':'real skin arrays, expressions, action and UI integration; native screenshot review',
        }
        write(rig_path,rig)
        runtime_triangles=int(sum(group['triangles'] for group in entry['groups']))
        row={
            'id':character_id,'name':name,'provider':'Mixamo' if mixamo else 'Blender 定制骨架',
            'bones':len(rig['bones']),'triangles':runtime_triangles,'clips':len(rig['actions']),
            'source':rig['source'],'editable':rig['editable_source'],'glb':rig['export_glb'],
            'source_triangles':rig['source_triangles'],
        }
        if mixamo: row['mixamo_fbx']=provider['source_file']
        base=f'screenshots/tripo-characters-v1/1440x900/characters/{character_id}'
        row['views']=[{'name':'静态','path':base+'-idle.png'}]
        if character_id=='player':
            row['views'] += [
                {'name':'步行','path':base+'-walk/frame-007.png'},
                {'name':'粉色换装','path':base+'-outfit-pink.png'},
                {'name':'蓝色换装','path':base+'-outfit-blue.png'},
            ]
        else:
            pose='take' if character_id=='textbook_jim' else 'walk'
            row['views'] += [
                {'name':'挥手','path':base+'-wave.png'},
                {'name':'接物' if pose=='take' else '步行','path':base+'-'+pose+'.png'},
                {'name':'递物','path':base+'-give.png'},
            ]
        assert all((ROOT/'docs'/view['path']).is_file() for view in row['views'])
        rows.append(row)
    mixamo_count=sum(row['provider']=='Mixamo' for row in rows)
    assert mixamo_count==8
    checks={name:(report['checks'] if isinstance(report.get('checks'),int) else len(report.get('checks',[]))) for name,report in reports.items() if name!='preservation'}
    summary={
        'status':'PASS','date':'2026-10-23','active_manifest':'game/assets/characters/tripo_v1/manifest.json',
        'characters':rows,'mixamo_count':8,'custom_rig_count':4,'checks':checks,
        'original_files_unchanged':len(originals),
        'source_triangles_total':sum(row['source_triangles'] for row in rows),
        'runtime_triangles_total':sum(row['triangles'] for row in rows),
        'native_character_captures':len(reports['characters']['captures']),
        'gesture_revision':'anatomical-wave-v2',
        'gesture_comparison':'docs/tripo-wave-refinement.html',
        'limitations':[
            'Jim 原模型的手掌/裤腿及手臂/轮椅接触处做了网格分离与补面；近景仍可见局部材质和轮廓过渡，可继续美术精修。',
            '完整 Mixamo FBX 保留原始下载骨架；游戏使用 17 骨语义映射，暂不提供独立手指抓握。',
            '行走贴地修正存放于 Godot grounding.json；Blender/GLB 的基础动作可编辑，运行时的贴地修正在引擎适配层应用。',
            '挥手已按体形校正手掌朝向并减小抬肩幅度；熊叔采用肩侧的小幅招手。原生成模型的袖口近景仍有美术精修空间。',
            '本次验证覆盖本地角色和关联流程，未运行项目全量测试，也未更新旧 Windows 安装包。',
        ],
        'reports':{name:str((REPORTS/file).relative_to(ROOT)).replace('\\','/') for name,file in {
            'characters':'native-1440x900-characters.json','actions':'p1-actor-animation.json',
            'gameplay':'native-1440x900-gameplay.json','orchard':'orchard-integration.json',
            'preservation':'preservation.json',
            'greeting':'../tripo-wave-refinement/wave-regression.json',
        }.items()},
    }
    write(REPORTS/'asset-integration.json',summary)
    build_docs(summary)
    build_gallery(summary)
    print(json.dumps({k:summary[k] for k in ['status','mixamo_count','custom_rig_count','checks','original_files_unchanged','runtime_triangles_total']},ensure_ascii=False))

def build_docs(summary):
    table='\n'.join(f"| {r['name']} | {r['provider']} | {r['bones']} | {r['triangles']:,} | {r['clips']} |" for r in summary['characters'])
    checks=summary['checks']
    content=f'''# 12 个 Tripo 角色：骨骼绑定与游戏接入

2026-10-23。当前项目已通过 `game/assets/characters/active-set.json` 使用 `tripo_v1` 的全部 12 个角色。

运行项目根目录的 `start-game.ps1`，即可查看新版。也可打开 [角色预览页](tripo-characters-gallery.html)，逐个切换静态、挥手、步行/接物和递物姿态。

## 已交付内容

8 位站立人形角色使用 Adobe Mixamo 完成自动绑定，原始下载 FBX 和 SHA-256 位于 `assets/characters/mixamo_v1/downloads/` 及 `input/manifest.json`。熊叔、兔兔、Dino、轮椅 Jim 使用 Blender 定制骨架和蒙皮。所有角色均保留可编辑 Blender 文件、带骨骼 GLB 和 Godot 原生网格资源。

| 角色 | 绑定方式 | 游戏骨骼数 | 三角面数 | 基础动作数 |
|---|---|---:|---:|---:|
{table}

总计 {summary['runtime_triangles_total']:,} 个运行时三角面；原始 12 个模型总计 {summary['source_triangles_total']:,} 个三角面。PBR 纹理使用 2048 像素工作副本。原始 GLB 均保留。

## 游戏适配

- 保留原角色 ID、剧情语义、动作时长、接触事件和存档接口。
- Mixamo 权重映射到游戏语义骨骼；完整 FBX 的手指和脚趾骨仍保留在下载原件中。游戏当前使用合并后的手掌/脚部权重。
- 新增真实的 Blink、Smile、Talk 形变目标，并接回暂停和减少动态效果设置。
- 玩家原有黄、粉、蓝三种换装使用独立材质参数和衣物遮罩；背包等附件保留原色。
- NPC 行走/持物行走使用 `grounding.json` 的鞋底采样修正。此文件由 `bake_tripo_grounding.gd` 生成，运行时只读取位置关键帧。
- 兔兔放篮动作在适配层校准肩部伸手角度；原 P1 动作库文件及其接触时间没有改写。
- 挥手采用逐角色拟合的屈肘姿势、前臂旋转与小幅摆手，手掌朝前；熊叔使用肩侧的小幅招手。曲线保存在 `gesture-overrides.json`，与 Blender/GLB 动作共用。所有动作都明确复位手腕，支持中途切换。
- 熊叔与兔兔的工作服重新约束到躯干，并在袖口、肩带处平滑过渡。[查看调整前后与完整挥手](tripo-wave-refinement.html)。
- Jim 的手掌与裤腿、手臂与轮椅粘连处已经分离并补面；身体与轮椅分别蒙皮，轮椅保持刚性。

## 验证与边界

| 检查 | 结果 | 报告 |
|---|---:|---|
| 12 角色蒙皮、表情、暂停、动作及换装 | {checks['characters']} 项通过；{summary['native_character_captures']} 张实际 Godot 截图 | [角色报告](verification/tripo-characters-v1/native-1440x900-characters.json) |
| P1 动作时序、接触位置、脚底及移动约束 | {checks['actions']} 项通过 | [动作报告](verification/tripo-characters-v1/p1-actor-animation.json) |
| 实际主场景、地图、家园、衣柜点击与旋转 | {checks['gameplay']} 项通过 | [界面报告](verification/tripo-characters-v1/native-1440x900-gameplay.json) |
| 实际果园摘取、搬运、放篮及存档边界 | {checks['orchard']} 项通过 | [果园报告](verification/tripo-characters-v1/orchard-integration.json) |
| 11 位 NPC 普通/减少动态模式的手掌朝向、手腕连续性及动作中断 | {checks['greeting']} 项通过 | [挥手报告](verification/tripo-wave-refinement/wave-regression.json) |
| 原始及旧版资产保护 | {summary['original_files_unchanged']} 个文件哈希一致 | [保护报告](verification/tripo-characters-v1/preservation.json) |

检查使用隔离存档。角色报告记录本次实际使用的资源和驱动代码哈希。脚底测试对新模型采样真实蒙皮鞋底，不再套用旧模型的固定椭球尺寸。

Jim 近景仍可见局部补面的材质和轮廓过渡，部分原生成模型的袖口也有精修空间。当前动作不含独立手指抓握。Blender/GLB 内保留基础动作与本次挥手修正；Godot 的行走贴地修正在引擎适配层应用。未进行帧率性能验收、项目全量测试或旧 Windows 安装包重打包。

## 文件与重建

- 原始模型：`assets/tripo/01_player.glb` 至 `12_jim.glb`。
- 可编辑源：`assets/characters/tripo_v1/<角色ID>/rigged.blend`。
- 交换文件：同目录 `character.glb`；参数和来源见 `rig.json`。
- 运行资源：`game/assets/characters/tripo_v1/<角色ID>/Body.res`，Jim 另有 `Wheelchair.res`。
- 新旧代码切换前备份：`assets/characters/tripo_v1/runtime-before.zip`。

重建顺序：`prepare_tripo_characters.py` → `rig_tripo_characters.py`（8 位人形加 `--mixamo` 使用已下载 FBX；4 位特殊角色使用本地骨架）→ `refine_tripo_gestures.py` → `bake_tripo_characters.gd` → `bake_tripo_grounding.gd` → 相关检查 → `finalize_tripo_characters.py`。不要不带角色参数混用两种绑定模式。挥手修正前的 64 个文件另存于 `docs/verification/tripo-wave-refinement/before.zip`，包含源绑定、运行网格、驱动及旧挥手截图。

Blender 可执行文件：`F:/Tools/Blender/blender-5.2.2-windows-x64/blender.exe`。Godot 可执行文件：`F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe`。Godot 命令使用 `--path F:/LoveStudy/game --script res://...`，测试追加 `-- --test-harness`。

## 回退

将 `game/assets/characters/active-set.json` 的 `manifest` 改回 `res://assets/characters/storybook_v3/manifest.json`，重新启动游戏。旧模型、旧动作库和原始 Tripo 文件未删除；原始及旧版资产已核对哈希。
'''
    (ROOT/'docs/tripo-character-integration.md').write_text(content,encoding='utf-8')
    (ASSETS/'README.md').write_text('# Tripo 角色绑定输出\n\n已接入全部 12 个角色。详细来源、验证、重建与回退说明见 [接入文档](../../../docs/tripo-character-integration.md)，实际游戏截图见 [预览页](../../../docs/tripo-characters-gallery.html)。\n\n每个角色目录保留 `prepared.blend`、`rigged.blend`、`character.glb`、`preparation.json` 和 `rig.json`。根目录日志包含迭代诊断；最终结果以 `docs/verification/tripo-characters-v1/asset-integration.json` 为准。\n',encoding='utf-8')
    (ROOT/'assets/characters/mixamo_v1/README.md').write_text('# Mixamo 绑定原件\n\n8 位站立人形角色均已上传、绑定并下载，清单和 SHA-256 见 `input/manifest.json`。`downloads/<角色ID>/t_pose.fbx` 保留下载原件，游戏映射与材质恢复后的可编辑文件位于相邻 `tripo_v1` 目录。\n\n熊叔、兔兔、Dino 和轮椅 Jim 使用本地定制骨架，不属于这 8 个 Mixamo 下载。\n',encoding='utf-8')

def build_gallery(summary):
    data=json.dumps(summary,ensure_ascii=False).replace('</','<\\/')
    template=r'''<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>字母岛 · 12 角色绑定预览</title>
<style>
:root{font-family:"Microsoft YaHei",system-ui,sans-serif;color:#273d36;background:#f5f3e8;color-scheme:light}*{box-sizing:border-box}body{margin:0}main{max-width:1440px;margin:auto;padding:36px 32px 60px}a{color:#2e6559}header{display:flex;justify-content:space-between;gap:30px;align-items:end;margin-bottom:28px}.eyebrow{font-size:13px;letter-spacing:.14em;color:#63776b}h1{font-size:38px;letter-spacing:-.04em;margin:8px 0 12px}p{line-height:1.7;margin:8px 0}.lede{max-width:770px;color:#56675d}.counts{white-space:nowrap;text-align:right;color:#4b6355;font-size:14px}.counts strong{font-size:34px;color:#254f3f}.toolbar{display:flex;gap:10px;align-items:center;padding:16px 0 20px;border-top:1px solid #d6ddce}.toolbar span{margin-left:auto;color:#68776b;font-size:13px}button{font:inherit;border:1px solid #b9c9bb;border-radius:7px;background:#fffdf4;color:#294e40;cursor:pointer;padding:8px 13px}button:hover,button:focus-visible{border-color:#426d53;background:#e8efdf;outline-offset:3px}button.active{background:#2e5944;color:#fff;border-color:#2e5944}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:22px}.card{overflow:hidden;background:#fffdf5;border:1px solid #dbe1d3;border-radius:12px}.image-button{display:block;width:100%;border:0;border-radius:0;padding:0;background:#eeecd7}.image-button img{display:block;width:100%;aspect-ratio:1.6;object-fit:contain}.info{padding:18px 19px}.topline{display:flex;justify-content:space-between;align-items:center;gap:10px}.topline h2{margin:0;font-size:20px}.badge{font-size:11px;padding:4px 7px;border-radius:4px;background:#e6eddf;white-space:nowrap}.meta{font-size:12px;color:#768074;margin:9px 0 15px}.views{display:flex;gap:6px;flex-wrap:wrap}.views button{font-size:12px;padding:6px 10px}.source{display:flex;gap:15px;margin-top:14px;font-size:12px}.evidence{margin-top:42px;padding:24px;background:#e8eddf;border-radius:12px}.evidence h2{font-size:22px;margin:0 0 14px}.report-links{display:flex;flex-wrap:wrap;gap:14px;margin:15px 0}.scene-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:20px;margin-top:24px}.scene-grid img{width:100%;display:block;border-radius:8px}.scene-grid figcaption{margin-top:8px;font-size:13px;color:#657568}figure{margin:0}.note{font-size:13px;color:#657568}.footer{font-size:12px;margin-top:30px;color:#7b8376}dialog{border:0;padding:0;border-radius:12px;max-width:95vw;max-height:95vh;background:#f5f3e8}dialog::backdrop{background:#142b26b8}dialog img{display:block;width:min(1440px,92vw);height:auto;max-height:82vh;object-fit:contain}dialog .caption{display:flex;justify-content:space-between;align-items:center;padding:12px 18px}@media(max-width:1000px){.grid{grid-template-columns:repeat(2,1fr)}header{align-items:start}.counts{font-size:12px}}@media(max-width:650px){main{padding:24px 14px}.grid,.scene-grid{grid-template-columns:1fr}h1{font-size:29px}header{display:block}.counts{text-align:left;margin-top:18px}.toolbar{flex-wrap:wrap}.toolbar span{margin-left:0;width:100%}}
@media(min-width:1300px){.grid{grid-template-columns:repeat(4,minmax(0,1fr))}.topline h2{font-size:18px}.info{padding:14px 15px}.source{gap:10px;font-size:11px}}
</style>
<main><header><div><div class="eyebrow">ALPHABET ISLAND / CHARACTER ART</div><h1>12 位新伙伴，已经来到字母岛</h1><p class="lede">这里展示实际 Godot 运行截图。点击每位角色的姿态按钮查看绑定效果，点击图片放大；可编辑模型和原始 Mixamo 文件可直接打开。</p></div><div class="counts"><strong>8</strong> Mixamo 人形<br><strong>4</strong> 定制骨架<br>2026.10.23 · 本地项目已启用</div></header>
<div class="toolbar"><button id="all-idle" class="active">静态造型</button><button id="all-action">动作姿态</button><a href="tripo-wave-refinement.html">挥手修正对比</a><span>全部图片来自原生渲染 · 可查看源文件</span></div>
<section class="grid" id="cards" aria-label="角色预览"></section>
<section class="evidence"><h2>已接回游戏中的操作</h2><p id="checks"></p><p class="note">Jim 的手掌、裤腿与轮椅接触网格已分离补面，近景局部过渡仍可继续美术精修。游戏当前使用语义骨架，独立手指抓握未实现。</p><div class="report-links"><a href="tripo-character-integration.md">接入与回退说明</a><a href="verification/tripo-characters-v1/asset-integration.json">完整检查汇总</a><a href="verification/tripo-characters-v1/preservation.json">原件保护记录</a><a href="screenshots/mixamo-v1/miss-li-t-pose.jpg">Mixamo 网页记录</a></div><div class="scene-grid"><figure><img src="screenshots/tripo-characters-v1/1440x900/gameplay/01-island-hud.png" alt="新版玩家实际岛屿画面" loading="lazy"><figcaption>当前项目中的玩家与岛屿</figcaption></figure><figure><img src="screenshots/tripo-characters-v1/1440x900/gameplay/04-wardrobe-pink.png" alt="实际衣柜粉色换装" loading="lazy"><figcaption>原有衣柜点击换装与旋转预览</figcaption></figure></div></section>
<p class="footer">从项目根目录运行 start-game.ps1 查看新版。预览不代表帧率验收；本次未重打包旧 Windows 安装包。</p></main>
<dialog id="viewer"><img id="large" alt="角色大图"><div class="caption"><span id="caption"></span><button id="close">关闭</button></div></dialog>
<script>
const data=__DATA__;
const cards=document.querySelector('#cards');
const controllers=[];
const viewer=document.querySelector('#viewer');
for(const character of data.characters){
 const card=document.createElement('article');card.className='card';
 const button=document.createElement('button');button.className='image-button';
 const img=document.createElement('img');img.loading='lazy';button.append(img);card.append(button);
 const info=document.createElement('div');info.className='info';
 const topline=document.createElement('div');topline.className='topline';
 const title=document.createElement('h2');title.textContent=character.name;
 const badge=document.createElement('span');badge.className='badge';badge.textContent=character.provider;
 topline.append(title,badge);info.append(topline);
 const meta=document.createElement('p');meta.className='meta';meta.textContent=`${character.bones} 骨骼 · ${character.triangles.toLocaleString()} 三角面 · ${character.clips} 基础动作`;info.append(meta);
 const views=document.createElement('div');views.className='views';info.append(views);
 let active=0;
 const buttons=character.views.map((view,index)=>{const b=document.createElement('button');b.textContent=view.name;b.onclick=()=>select(index);views.append(b);return b});
 function select(index){active=index;const view=character.views[index];img.src=view.path+'?rev='+data.gesture_revision;img.alt=character.name+' / '+view.name;button.setAttribute('aria-label','放大 '+img.alt);buttons.forEach((b,i)=>{b.classList.toggle('active',i===index);b.setAttribute('aria-pressed',String(i===index))})}
 button.onclick=()=>{document.querySelector('#large').src=img.src;document.querySelector('#large').alt=img.alt;document.querySelector('#caption').textContent=img.alt;viewer.showModal()};
 const source=document.createElement('div');source.className='source';
 for(const [name,path] of [['Blender 源文件',character.editable],['GLB',character.glb],...(character.mixamo_fbx?[['Mixamo FBX',character.mixamo_fbx]]:[])]){const a=document.createElement('a');a.textContent=name;a.href='../'+path;source.append(a)}
 info.append(source);card.append(info);cards.append(card);select(0);controllers.push(select);
}
function selectAll(index){controllers.forEach(select=>select(index));document.querySelector('#all-idle').classList.toggle('active',index===0);document.querySelector('#all-action').classList.toggle('active',index===1)}
document.querySelector('#all-idle').onclick=()=>selectAll(0);document.querySelector('#all-action').onclick=()=>selectAll(1);
document.querySelector('#close').onclick=()=>viewer.close();viewer.onclick=e=>{if(e.target===viewer)viewer.close()};
document.querySelector('#checks').textContent=`角色检查 ${data.checks.characters} 项、动作回归 ${data.checks.actions} 项、挥手专项 ${data.checks.greeting} 项、界面操作 ${data.checks.gameplay} 项、果园流程 ${data.checks.orchard} 项均通过。${data.original_files_unchanged} 个原始及旧版文件哈希一致。`;
</script></html>'''
    (ROOT/'docs/tripo-characters-gallery.html').write_text(template.replace('__DATA__',data),encoding='utf-8')

if __name__=='__main__':
    main()
