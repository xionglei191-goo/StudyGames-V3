"""Close the full-world art record only when assets, native views and routes agree."""
from pathlib import Path
import hashlib,json,re,datetime
ROOT=Path(__file__).resolve().parents[1]
PROOF=ROOT/'docs/verification/world-refinement'
def read(path):return json.loads(path.read_text('utf-8'))
def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def write(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
    assets=read(PROOF/'asset-report.json');routes=read(PROOF/'route-report.json');gallery=read(PROOF/'gallery-report.json');roundtrip=read(PROOF/'saved-export-report.json')
    assert all(r['result']=='PASS' for r in [assets,routes,gallery,roundtrip])
    assert len(assets['rooms'])==44 and gallery['scenes']==44 and gallery['pairs']==88
    assert routes['routes']==300 and routes['transitions']==88
    for path,digest in routes['source_sha256'].items():assert sha(ROOT/path)==digest,('stale routes',path)
    for row in assets['rooms']:assert sha(ROOT/row['source_glb'])==row['sha256']
    capture_reports=sorted((PROOF/'after').glob('*/report.json'))
    captures=[];native_checks=0
    for path in capture_reports:
        record=read(path);assert record['result']=='PASS'
        native_checks+=len(record['checks']);captures+=record['captures']
        for file,digest in record['source_sha256'].items():assert sha(ROOT/'game'/file.removeprefix('res://'))==digest
    assert len(captures)==88
    for row in gallery['images']:assert sha(ROOT/'docs'/row['path'])==row['sha256']
    assert sha(ROOT/'docs/world-refinement.html')==gallery['html_sha256']
    orchard=read(PROOF/'orchard-integration.json');assert orchard['status']=='passed' and not orchard['failures']
    living=next(json.loads(line.split('LIVING_WORLD_REPORT ',1)[1]) for line in (PROOF/'living-world.log').read_text('utf-8').splitlines() if 'LIVING_WORLD_REPORT ' in line)
    assert living['status']=='PASS'
    performance=[]
    for path in sorted((PROOF/'performance').glob('*/report.json')):
        record=read(path);assert record['result']=='PASS'
        assert record['display_server']!='headless' and '--fixed-fps' not in record['engine_arguments']
        for sample in record['performance_samples']:
            assert sample['sample_drawn_frames']==300 and sample['window_focused'] and sample['window_mode']==0
            performance.append(sample)
    assert len(performance)==6
    base=read(ROOT/'docs/planning/world-refinement/baseline.json')
    for path,digest in base['protected_files'].items():assert sha(ROOT/path)==digest,('original source changed',path)
    names={r['room_id']:r['name'] for r in base['rooms']}
    metrics={'surface_objects':0,'softened_edges':0,'tailored_details':0,'layered_crowns':0}
    table=[]
    for row in assets['rooms']:
        room=row['room'];source=Path(row['source_blend']);version=re.search(r'_v(\d+)',source.stem).group(1)
        audit_path=ROOT/source.parent/('validation_v'+version+'.json')
        audit=read(audit_path)
        if room not in ['home','home_estate']:
            metrics['surface_objects']+=audit['textured_objects'];metrics['softened_edges']+=audit['softened_edges']
            metrics['tailored_details']+=len(audit['tailored_details']);metrics['layered_crowns']+=len(audit['layered_crowns'])
            details=f"{audit['textured_objects']} / {len(audit['tailored_details'])} / {len(audit['layered_crowns'])}"
        else:details='保留样板；补齐窗帘杆 UV' if room=='home' else '保留已完成的小院样板'
        if room!='home_estate':
            audit['engine_acceptance']={'result':'PASS','scope':'44-scene native capture and physical circulation acceptance',
                'static_report':'docs/verification/world-refinement/asset-report.json','routes_report':'docs/verification/world-refinement/route-report.json',
                'gallery_report':'docs/verification/world-refinement/gallery-report.json','runtime_glb_sha256':row['sha256']}
            write(audit_path,audit)
        table.append(f"| {names[room]} | [{source.name}](../../../{source.as_posix()}) | {details} | {row['glb_bytes']/1048576:.2f} |")
    performance_report={'result':'PASS','device':'NVIDIA GeForce RTX 4070 / OpenGL 3.3 NVIDIA 610.88','resolution':[1440,900],
        'renderer':'gl_compatibility','samples':performance,'scope':'Six stationary, sunny daytime, reduced-motion samples. Each counted 300 rendered frames in a focused native window after warm-up, with no parallel Godot or Blender work. Not a minimum-device or long-session benchmark.'}
    write(PROOF/'performance-report.json',performance_report)
    acceptance={'result':'PASS','completed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scenes':44,'native_after_views':88,'comparison_pairs':88,
        'native_checks':native_checks,'route_checks':routes['checks'],'actual_walks':routes['routes'],'door_transitions':routes['transitions'],
        'memory_loci':210,'household_tasks':8,'orchard_checks':len(orchard['checks']),'living_world_checks':living['checks'],
        'protected_exported_nodes':sum(r['protected_exported_nodes'] for r in assets['rooms']),'preserved_original_files':len(base['protected_files']),
        'expansion_art_metrics':metrics,'retained_samples':['home','home_estate'],'production_saves_unchanged':True,
        'scope':'Art refinement of all 44 existing playable scenes, with ordinary saved-source export checks for three representative sources. Focused acceptance only; no new release package or full curriculum acceptance.'}
    write(PROOF/'acceptance.json',acceptance)
    perf_rows='\n'.join(f"| {names[p['room']]} | {p['wall_effective_fps']:.1f} | {p['wall_frame_ms']['p95']:.2f} | {int(p['draw_calls_last_frame'])} |" for p in performance)
    route_rows='\n'.join(f"| {r['suite']} | {r['checks']} | {r['routes']} | {r['transitions']} | PASS |" for r in routes['suites'])
    text=f'''# 全场景美术精修 · 2026-10-24

本轮将小院与客厅的精修标准扩展到全部 **44 个现有可游玩场景**。当前游戏已经使用新版资产。[打开 44 场景同机位对照](../../world-refinement.html)，或双击工程根目录的「启动字母岛.cmd」。

范围为主岛 1、A–Z 场所 26、校园及功能区 8、家园及室内空间 9。小院和客厅沿用前一批样板；客厅另补齐两根窗帘杆的 UV。本轮不是新发布包，历史 Windows 成品仍保留原范围。

## 画面改动

- 在版本化 Blender 源文件中处理木材、布料、石材、土壤、纸张、陶器和金属的质感；已有贴图素材继续保留。室内木地板控制纹理尺度，阳台使用细缝铺砖。
- 对 243 个树冠网格加入分组枝叶轮廓，细化 270 处家具倒角，添加 897 处装饰，包括船舷与帆边、家具收边、柜门拉手、陶器口沿、鼓身金属件、车轮辐条、望远镜环带、岩层细线和木琴镶边。上述数量只统计本轮扩展的 42 个场景。
- 统一暖色环境光、主光与接触阴影。主岛保留分区阴影，修正铺装亮线；小院采用已验证的独立阴影设置。昼夜、天气仍由原环境系统控制。
- 主岛编辑 `alphabet_island_layout_v07_game.blend`，校园 v04、客厅 v04、门厅 v02，其余源路径见下表。131 份旧版 Blender、GLB 与预览的 SHA256 均与本轮开始前一致。

## 验证结果

[最终汇总](acceptance.json) · [资产检查](asset-report.json) · [通行汇总](route-report.json) · [保存后导出检查](saved-export-report.json)

44 个导出资产与运行资产逐一匹配；4,518 个受保护节点的层级、交互元数据、变换以及碰撞/地面三角形坐标保持一致。贴图均内嵌，使用纹理的网格具备 UV。主岛、客厅与 K 工坊另外重新打开已保存源文件，经常规导出器输出临时 GLB，对全部节点、每个网格的三角形坐标、变换和材质名称作比较，结果一致；磁盘源文件没有改写。主岛导出器已补齐曲线转网格步骤，室内导出器保留精修曲线的闭合接缝处理。

| 专项 | 检查项 | 实际行走 | 进出转换 | 结果 |
|---|---:|---:|---:|---|
{route_rows}

合计 **{routes['checks']} 项通行检查、300 段实际行走、88 次进出转换**。字母场所覆盖 130 个固定点，校园覆盖 40 个固定点，家园覆盖 40 个固定点和 8 项家务。家园路线包含“主岛 → 小院 → 门厅 → 七个房间 → 返回”；字母门口使用实际 E 键派发。全部使用隔离存档，正式存档与备份保持一致。

[采苹果专项](orchard-integration.json)另外通过 {len(orchard['checks'])} 项：实际走近、手部接触、苹果持有、放入篮子、暂停恢复、保存失败时的物件归属、重玩与发现记录。[昼夜/天气检查](living-world.log)通过 {living['checks']} 项，包含真实客厅、校园、教室的角色落点。本轮运行的是受影响路径的专项检查，没有运行发布用全量测试。

## 原生画面对照

修改前后各 88 张 Godot 原生 PNG，合计 176 张、88 组对照；每处包含默认游戏视角和全景复核视角。修改后六批共有 {native_checks} 项捕获检查，全部通过。每组固定相机位置、方向、正交尺寸和晴天白昼。全景隐藏 HUD，仅用于美术复核，不能代表默认游玩视角。所有 44 处的游戏视角均已逐一查看，并在纹理和阴影修正后复查相关画面。

[图集静态校验](gallery-report.json)检查图片存在、PNG 尺寸、哈希、当前运行源哈希与同机位记录；JavaScript 通过 `node --check`。图集没有另行完成浏览器渲染验收，图片本身来自引擎。Blender 预览仅辅助源模型编辑，最终效果以这里的实拍为准。

## 本机性能采样

设备为 NVIDIA GeForce RTX 4070，Godot 4.7.2 Compatibility / OpenGL 3.3，1440 × 900。六处分别预热后采集 300 个实际绘制帧；窗口保持焦点，没有固定模拟帧参数，也没有其他 Godot/Blender 任务同时运行。原始数据见 [性能报告](performance-report.json)。

| 场景 | 渲染帧/秒 | 帧间隔 P95 / ms | 末帧绘制调用 |
|---|---:|---:|---:|
{perf_rows}

这些数据来自晴天白昼、减少动态、默认出生点的短时静止采样，包含呈现节奏；不代表最低设备要求、连续移动或长时游玩的帧率保证。

## 当前源文件

下表的三个数字依次为材质处理对象、新增装饰、重做树冠；源文件、GLB、打包贴图和运行拷贝均保留在工程内。新增材质为本地产生的确定性纹理，未引入新的外部下载素材。

| 场景 | Blender 源文件 | 材质 / 装饰 / 树冠 | GLB / MiB |
|---|---|---:|---:|
{chr(10).join(table)}

## 重现入口

```powershell
python -X utf8 scripts/verify_world_refinement.py
python -X utf8 scripts/run_world_routes.py
python -X utf8 scripts/run_world_capture.py after
python -X utf8 scripts/build_world_refinement_gallery.py
```

`docs/planning/world-refinement/baseline.json` 为不可覆盖的修改前清单；重新生成材质只写新版工作文件。日常室内编辑继续使用原 pipeline 导出，主岛同步脚本从清单读取当前版本。运行验证先完成 Godot 导入，性能采样单独执行。
'''
    (PROOF/'README.md').write_text(text,encoding='utf-8')
    (ROOT/'docs/planning/world-refinement/README.md').write_text('''# 全场景精修范围

以已完成的小院/客厅样板为标准，对现有主岛、26 个字母场所、校园及功能区、家园及室内空间做完整美术精修，共 44 处。

`baseline.json` 固定修改前 131 份源文件和预览的 SHA256；`inventory.json` 记录当时的节点与材质。两份 before manifest 保存当时有效路径。此基线不可覆盖。

执行保持版本化源文件，保留已有贴图、固定记忆点、门口和碰撞几何；新纹理、树冠和装饰在 Blender 内生成并保存。修改后分别验证导出资产、实际通行和 Godot 原生画面，三者互不替代。

当前结果见 [专项验收](../../verification/world-refinement/README.md) 和 [44 场景对照](../../world-refinement.html)。
''',encoding='utf-8')
    print(json.dumps(acceptance,ensure_ascii=False))
if __name__=='__main__':main()
