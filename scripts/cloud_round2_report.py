"""Assemble untouched render pairs, an evidence index, and a compact review PDF."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from reportlab.pdfgen import canvas
import json,argparse,shutil,hashlib,subprocess
P=argparse.ArgumentParser();P.add_argument('--evidence',required=True);P.add_argument('--deliverables',required=True);P.add_argument('--commit',default='');a=P.parse_args();ROOT=Path(__file__).resolve().parents[1];EV=Path(a.evidence);DEST=Path(a.deliverables);DEST.mkdir(parents=True,exist_ok=True);DOC=ROOT/'docs/verification/cloud-refinement-round2-20261025';COMP=DOC/'comparisons';COMP.mkdir(parents=True,exist_ok=True)
plan=json.loads((ROOT/'docs/planning/cloud-refinement-round2-20261025.json').read_text());report=json.loads((EV/'asset_validation.json').read_text());fontfile='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
assert report['passed'] and json.loads((EV/'saved_blend_validation.json').read_text())['passed']
export_checks=json.loads((DOC/'export-checks.json').read_text())['results'];runtime_checks=json.loads((DOC/'runtime-checks.json').read_text())['results']
assert all(r['passed'] for r in export_checks)
assert all(r['passed'] for r in runtime_checks if r['name']!='state-after')
before_native=json.loads((DOC/'native/before/round2/report.json').read_text());after_native=json.loads((DOC/'native/after/round2/report.json').read_text());assert before_native['result']==after_native['result']=='PASS'
native_conditions=[];before_captures={c['id']:c for c in before_native['captures']}
for c in after_native['captures']:
 old=before_captures[c['id']];keys=['day_phase','weather'];same=all(c['weather'].get(k)==old['weather'].get(k) for k in keys)
 assert same and c['weather']['day_phase']=='day' and c['weather']['weather']=='clear'
 native_conditions.append({'id':c['id'],'same_day_and_weather':same,'before':{k:old['weather'][k] for k in keys},'after':{k:c['weather'][k] for k in keys}})
(DOC/'native-comparison-conditions.json').write_text(json.dumps({'passed':True,'captures':native_conditions},indent=2)+'\n')
def font(n):return ImageFont.truetype(fontfile,n)
bg='#f3efe5';ink='#203f36';green='#386c55'
def pair(name,title,before,after,note):
 ims=[Image.open(p).convert('RGB') for p in [before,after]];assert ims[0].size==ims[1].size,(name,ims[0].size,ims[1].size)
 for im in ims:im.thumbnail((1360,1000),Image.Resampling.LANCZOS)
 w=2800;h=max(i.height for i in ims)+170;sheet=Image.new('RGB',(w,h),bg);d=ImageDraw.Draw(sheet);d.rectangle((0,0,w,10),fill=green);d.text((30,24),title,font=font(42),fill=ink);d.text((30,80),'第一轮 · d30c4f57',font=font(29),fill=ink);d.text((1420,80),'第二轮 · cloud-09',font=font(29),fill=ink)
 for i,im in enumerate(ims):sheet.paste(im,(30+i*1390,124))
 d.text((30,h-36),note,font=font(24),fill=ink);p=COMP/(name+'.jpg');sheet.save(p,quality=87,optimize=True,subsampling=0);return p
items=[]
for r in plan['rooms']:
 rid=r['room_id'];p=pair(rid,r['name']+'｜Blender 同机位对照',EV/rid/'before.png',EV/rid/'after.png','相机、光源、世界环境与曝光保持一致；实际场景渲染，未重绘或调色。');items.append({'room_id':rid,'image':str(p.relative_to(ROOT))})
 if rid in ['island','school','home_kitchen']:pair(rid+'-detail',r['name']+'｜形体近景',EV/rid/'before-detail.png',EV/rid/'after-detail.png','固定近景相机；展示实际导出的几何与材质。')
 if rid=='island':pair('island-neighborhood','主岛入口｜住宅与岸线',EV/rid/'before-neighborhood.png',EV/rid/'after-neighborhood.png','第一轮与第二轮固定相机、固定照明。')
for rid,name in [('village','主岛入口'),('school','校园'),('home_kitchen','厨房'),('home','客厅')]:
 view='overview' if rid=='school' else 'production';pair('native-'+rid,name+'｜Godot 实际游戏画面',DOC/'native/before/round2'/(rid+'-'+view+'.png'),DOC/'native/after/round2'/(rid+'-'+view+'.png'),'Godot 4.6.3 · OpenGL Compatibility / llvmpipe；固定白昼晴天与相同相机。')
for fname in ['asset_validation.json','saved_blend_validation.json','ground-face-order.json','state-before.log','state-before-result.json','baseline-route-UV.log','route-UV.log','terrain-route-UV.log']:
 shutil.copy2(EV/fname,DOC/fname)
(DOC/'changes').mkdir(exist_ok=True)
for r in plan['rooms']:shutil.copy2(EV/r['room_id']/'changes.json',DOC/'changes'/(r['room_id']+'.json'))
(DOC/'gallery.json').write_text(json.dumps({'base_commit':plan['base_commit'],'pairs':items,'native_captures_per_phase':36},ensure_ascii=False,indent=2)+'\n')
oldtri=sum(r['first_triangles'] for r in report['rooms']);newtri=sum(r['exported_triangles'] for r in report['rooms']);oldbytes=sum(r['first_bytes'] for r in report['rooms']);newbytes=sum(r['glb_bytes'] for r in report['rooms']);protected=sum(r['protected_exported_nodes'] for r in report['rooms']);reshaped=sum(r['reshaped_objects'] for r in report['rooms'])
sha=a.commit or subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip();branchurl='https://github.com/xionglei191-goo/StudyGames-V3/tree/'+(a.commit or 'codex/blender-refinement-20261025')
lines=['# 场景精修 · 第二轮','',f'基准：`{plan["base_commit"]}`。本轮对 18 个第一轮 `.blend` 进行真实 Blender 编辑，另存新版本并更新游戏实际加载资源。原始 5.2 文件及第一轮资产均保留。','',
'主岛 v09、校园与客厅 v06、院落 v05，其余房间 v04；版本后缀均为 `_cloud`。', '',
'## 具体修改','',
'- 主岛：完整山墙门廊、圆窗阁楼、加深窗框与窗台、分层树冠、地形坡面材质和贴合地形的浅岸线。靠近字母入口的树冠高度不超过第一轮。',
'- 校园：音乐阁楼、美术屋顶采光间、科学观察亭、入口雨棚、路径边缘和中央花园层次。',
'- 生活与教学空间：圆角桌板/座面、圆润柜体和家具边缘、床头弧形轮廓、窗帘与织物、打包木纹贴图，以及放在现有家具上的茶具、绘画/书写用品、面包、毛巾和育苗盆。',
'- 运动空间：器材架与挂环、圆润长凳、既有球队长凳上的弧形遮阳棚，保留原有水瓶，避免重复堆叠。',
'- 复审修正：面包移离果篮；香草盆移出水槽；排烟罩后改用收起的窗帘；教室悬空装饰窗安装到后墙；客厅保留既有窗帘，避免叠加；主岛瓦片改成有厚度的错层搭接，消除原有重面条纹。', '',
'## 真实对照与验证','',
'`comparisons/` 有 18 场景总览、3 个固定近景、主岛入口对照及 4 组原生游戏代表画面。`native/before/round2/` 与 `native/after/round2/` 各含 36 张 1440×900 原始截图及相机/光照状态记录。Blender 对照同机位同光照，不用后期调色掩盖几何差异。','',
f'- {protected:,} 个受保护节点：名字、层级、属性、变换和三角形位置校验保持一致（几何比较精度 1e-5）。',
f'- {reshaped:,} 个原有可见网格重塑；18 个保存文件重新打开并检查修改网格和打包贴图。',
f'- 总三角形：{oldtri:,} → {newtri:,}（{(newtri/oldtri-1)*100:+.2f}%）。',
f'- 18 个 GLB 总大小：{oldbytes:,} → {newbytes:,} 字节（{(newbytes/oldbytes-1)*100:+.2f}%）。源资源与运行时副本内容相同，不重复计算。','',
'普通导出、同步、实际物理路线、当前存档测试的命令、退出码和原始报告见 `export-checks.json`、`runtime-checks.json`。不得把已知失败的存档测试记为 PASS。','',
'![主岛住宅固定近景](comparisons/island-detail.jpg)','',
'![厨房实际游戏相机](comparisons/native-home_kitchen.jpg)','',
'| 检查 | 实际结果 |','|---|---|',
*[f'| {r["name"]} | '+('PASS' if r['passed'] else 'FAIL：与首轮相同的 reviews 存档断言')+f'；退出码 {r["exit_code"]} |' for r in export_checks+runtime_checks],
f'| 原生游戏截图 | 前后各 {len(before_native["captures"])} 张；相同相机检查与固定白昼晴天通过 |','',
'实际路线检查与截图检查分别记录。直接载入房间截图不冒充实际步行验证。','',
'常规同步脚本也已更新：版本化房间的面数、预览、版本及源路径会随同步保留并校验；主岛普通导出保留现有预览和来源字段，并重新计算实际实例化三角形数量。不是仅靠本轮专用脚本维持清单。','',
'复验中发现并修复一处 U→V 导航回归：地形材质重新分组改变了导入后的地面处理，虽三角形坐标集合相同，实际路线仍失败。已改为独立、无碰撞的坡面表层，保留原地形材质分组与精确面顺序。`route-baseline-UV-report.json`、`route-initial-UV-report.json`、`route-corrected-UV-report.json` 分别保留首轮通过、中间失败和修正通过；最终全字母结果见 `letters-report.json`。','',
'| 场景 | 三角形：首轮 → 本轮 | 材质：首轮 → 本轮 | GLB 字节：首轮 → 本轮 | 对照 |','|---|---:|---:|---:|---|']
for r in report['rooms']:
 name=next(x['name'] for x in plan['rooms'] if x['room_id']==r['room_id']);lines.append(f'| {name} | {r["first_triangles"]:,} → {r["exported_triangles"]:,} | {r["first_materials"]} → {r["materials"]} | {r["first_bytes"]:,} → {r["glb_bytes"]:,} | [{r["room_id"]}](comparisons/{r["room_id"]}.jpg) |')
lines+=['','## 保真边界与质量判断','',
'18 个场景第一轮均从当时实际加载的 GLB 导入，因已安装 Blender 4.3.2 无法打开原 Blender 5.2 作者文件。第二轮直接编辑第一轮保存的 `.blend`，未再次用 GLB 重建。原始修改器、曲线与作者操作历史无法由 GLB 还原；第一轮 GLB 的动画/骨骼数均为 0，家务状态仍由原 HOME_TASK 分组驱动。','',
'当前版本、统计、预览和加载路径以更新后的四份源/运行时清单及 `cloud_refinement_revision` 为准。GLB 继承的早期场景自定义注释（例如旧 `output_version`、`sg_game_export_version` 与旧检查说明）属于历史来源记录，不作为本轮版本或验收依据。','',
'本轮有意替换部分装饰网格与材质。原贴图保留/替换数量逐场景记录在 `asset_validation.json`，不宣称全部材质逐字节不变。碰撞代理、导航相关地形和交互节点按受保护集合比较；道路薄边、墙面装饰及屋顶细节不增加地面障碍。','',
'以《动物森友会》的完成度作为审查方向，而非复制其素材或声称已等同商业成品。轮廓厚度、家具曲线、植被层次和生活细节本轮有实际模型改善；原有角色、房间尺度、教学标识和玩法保留。通过真实游戏截图检查可见效果，不把 Blender 渲染当作游戏画面。','',
'| 审查维度 | 本轮达到的可核验结果 / 边界 |','|---|---|',
'| 建筑与家具轮廓 | 门廊、阁楼、窗框深度、桌椅圆角和床头弧线已经进入实际资源；屋瓦共面条纹已修复。 |',
'| 材质与色板 | 木纹、织物、叶面贴图打包入 GLB，金属/陶器粗糙度分开；保留原游戏对家务状态道具的着色，因此 Blender 与游戏的任务道具颜色可能不同。 |',
'| 地形与植被 | 树冠高低和体块重新组织，岸线与坡面层次可见；碰撞地形的精确面顺序保留。 |',
'| 生活布景与通路 | 道具依附现有家具，已排除发现的桌面重叠；300 条实际路线、88 次转换通过。 |',
'| 实际镜头 | 18 场景均有原生游戏远景/生产相机，代表性样板补充固定 Blender 近景。 |',
'| 商业成品等同 | 未把一次迭代、面数或自动检查当作等同商业团队成品的证据；角色动画、完整演出及目标硬件性能不属于本轮已验收结论。 |','',
'已运行的原生画面使用 Godot 4.6.3、X11 和 llvmpipe 软件渲染。项目声明的 Godot 4.7、目标设备 GPU 帧时、人工长时间游玩验收未运行；当前证据不证明这些验收通过。','',
'存档基准测试在首轮 d30c4f57 上重新失败：`_test_life_compatibility_and_transactions` → `Legacy save preserves field: reviews`（`test_state.gd:178` 的断言，汇总打印于第 26 行）。本轮后结果见 `state-after.log`；没有修改学习或存档逻辑。','',
'## 复现','',
'```bash',
'python3 scripts/cloud_round2_runner.py --evidence /tmp/studygames-round2 --workers 2',
'python3 scripts/cloud_round2_validate.py --evidence /tmp/studygames-round2',
'blender --python-exit-code 1 -b -P scripts/cloud_round2_saved.py -- "$PWD" /tmp/studygames-round2',
'python3 scripts/cloud_round2_integrate.py --evidence /tmp/studygames-round2',
'python3 scripts/cloud_round2_checks.py --phase export --evidence /tmp/studygames-round2',
'python3 scripts/cloud_round2_checks.py --phase runtime --evidence /tmp/studygames-round2',
'```','',
'原生截图需可用图形显示，使用 `game/tests/capture_cloud_round2.gd`。先在 d30c4f57 上录制 `before`，再在新资源上录制 `after`；后者读取前者相机记录并进行比较。仅修改了测试截图入口，未修改游戏核心逻辑。','',
'远程只提交到既有独立分支；不合并、不部署，不重试此前被拒绝的 PR 创建。']
(DOC/'README.md').write_text('\n'.join(lines)+'\n')
# Small shareable board: complete actual screenshots, scaled only.
choices=['native-village','native-school','native-home_kitchen'];cards=[]
for name in choices:
 im=Image.open(COMP/(name+'.jpg')).convert('RGB');im.thumbnail((1540,900),Image.Resampling.LANCZOS);cards.append(im)
h=175+sum(im.height for im in cards)+110+40;board=Image.new('RGB',(1600,h),bg);d=ImageDraw.Draw(board);d.rectangle((0,0,1600,9),fill=green);d.text((30,25),'StudyGames V3 · 第二轮实际游戏对照',font=font(43),fill=ink);d.text((32,88),'左：第一轮 d30c4f57　右：第二轮 cloud-09｜原始相机、白昼晴天',font=font(26),fill=ink);y=150
for im in cards:board.paste(im,((1600-im.width)//2,y));y+=im.height+20
d.text((32,h-95),'完整 18 场景、原生截图、模型和验证报告见分支。',font=font(25),fill=ink);d.text((32,h-53),'Godot 4.6.3 / llvmpipe 实拍；未宣称商业成品等同或目标 GPU 性能通过。',font=font(23),fill=ink)
jpeg=DEST/'StudyGames-Round2-Final-Overview.jpg';board.save(jpeg,quality=85,optimize=True,subsampling=0)
# Direct JPEG embedding avoids the oversized lossless PDF conversion from the first delivery.
pdf=DEST/'StudyGames-Round2-Final-Preview.pdf';c=canvas.Canvas(str(pdf),pagesize=(1200,650));c.setTitle('StudyGames V3 · 第二轮精修与实际游戏对照');c.setAuthor('StudyGames scene refinement')
selected=['native-village','island-detail','native-school','school-detail','native-home_kitchen','home_kitchen-detail','native-home']
for i,name in enumerate(selected):
 path=COMP/(name+'.jpg');im=Image.open(path);w,h=im.size;scale=min(1160/w,570/h);dw,dh=w*scale,h*scale;c.setFillColorRGB(.953,.937,.898);c.rect(0,0,1200,650,fill=1,stroke=0);c.drawImage(str(path),(1200-dw)/2,65+(570-dh)/2,width=dw,height=dh)
 c.setFont('Helvetica',10);c.setFillColorRGB(.13,.25,.21);c.drawString(24,37,'18 scenes | original files and round-one sources preserved | Godot 4.6.3 / llvmpipe');c.drawString(24,19,'Base d30c4f57 | Delivery '+sha[:12]+' | Full assets, native captures and measured checks in repository');c.drawRightString(1175,18,f'{i+1} / {len(selected)}');c.linkURL(branchurl+'/docs/verification/cloud-refinement-round2-20261025',(20,12,1178,53));c.showPage()
c.save();files=[]
for p in [pdf,jpeg]:
 assert p.stat().st_size<10_000_000;files.append({'path':str(p),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(DEST/'preview-files.json').write_text(json.dumps({'commit':sha,'files':files},indent=2));print(json.dumps({'files':files,'triangles':[oldtri,newtri],'bytes':[oldbytes,newbytes]},indent=2))
