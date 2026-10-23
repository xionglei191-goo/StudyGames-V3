# 家庭二级住宅与七个三级房间 · 交付验证

实现并验证：主岛 `village` → 小院与住宅 `home_estate` → 客厅、卧室、厨房、餐厅、浴室、书房、家务阳台。三级出口回各自住宅房门，院门返回主岛家门。所有40处生活位置均可走到并交互；8个三步家务流程保存独立的生活体验。

[交互预览页](../../home-hierarchy-gallery.html) · [课本来源与设计](../../planning/home-hierarchy/README.md) · [源文件总清单](../../../assets/blender/interiors/interiors_manifest.json)

## 验证结果

| 范围 | 结果 | 证据 |
|---|---|---|
| 家庭层级、地图实际鼠标操作与角色行走 | 568项通过；56段实际路线、16次切换，40个点、8项家务，取消/重做/重载均通过 | [hierarchy-report.json](hierarchy-report.json) |
| 家务状态、旧存档兼容、210点发现容量 | 23项通过；未增加金币、课程完成或语言掌握 | [state-report.json](state-report.json) |
| GLB、地面朝向、站位、源与运行文件一致性 | 85项通过；8份家庭场景、40份绑定语音；196份原素材与8册教材JSON哈希未变 | [asset-report.json](asset-report.json) |
| 原有地图与校园、客厅装扮、卧室休息 | 231项通过；39段路线、26次切换、1次实际碰撞探测 | [movement-report.json](movement-report.json) |
| 原有开场、旅行册和剧情流程 | 189项通过 | [journey-report.json](journey-report.json) |
| 朋友角实际图形窗口 | 240项通过，原存档和备份未变 | [原生窗口报告](friend-compatibility-native/1440x900/report.json) |
| 家庭原生画面与面板 | 61项通过、28张截图；覆盖1440×900及960×640窗口 | [native/report.json](native/report.json) |
| Godot项目静态检查 | 792文件，0错误、0警告 | [project-check.log](project-check.log) |

Godot 4.7.2、GL Compatibility，当前本机 RTX 4070。最终导入、家庭专项及图形窗口日志没有脚本错误。采用受影响范围检查，未运行整个游戏的全部测试套件；也未测量目标设备帧率或儿童学习效果。

## 画面核对

实际查看八个空间的 Godot 总览，以及住宅游玩镜头、地图、教材出处、小窗口交互和整理床铺前后状态。总览与道具特写使用检视镜头并隐藏界面，文件名以 `-overview` 或 `bed-` 标识；`-play` 保留生产镜头和界面。图片是原生渲染，未使用概念图替代游戏截图。

家庭活动当前是三个按钮步骤、人物手势与三维道具状态切换，尚未制作每件物品的手部抓取和搬运动画。它们是可以保存和重做的生活体验，不等同于完整家务模拟或语言测评。

## 检查中修正的内容

- 主岛旧模型的家门目的地仍为 `home`：在运行接入层改为二级 `home_estate`，保留旧岛模型。
- 住宅相邻房门较近，初始交互半径会选中邻门：收紧到1米，实际地图寻路与最近交互重新通过。
- 门廊树的站位靠近厨房前缘：移动到院中可站立位置，静态连通性与真实角色行走均通过。
- 小窗口地图短标签变成“走进……”：改为客厅、卧室、厨房等明确名称。
- 厨房墙上储物罐、院中水壶补齐承托家具。

朋友角的首次无图形测试中有两个“邀请标题单行”检查未通过，其余236项通过。随后以实际图形窗口复核，全部240项通过。首次图形测试因失去焦点而在合照等待环节暂停；最终 [专用运行器](../../../game/tests/test_home_friend_compatibility.gd) 仅固定测试实例的前台时钟标志，沿用生产渲染、鼠标输入和全部流程检查，未修改朋友角产品代码。初次尝试不计为通过证据。

## 文件与保存边界

- 旧 `home/home_v01.blend` 与GLB保留，新客厅另存为 `home/home_v02.blend`。其余7个家庭新空间各有独立 `.blend`、GLB和预览。
- 旧客厅 `home` ID、五点坐标、旅行册、朋友角及家具装扮记录保留。床铺和休息功能移至卧室。
- 教材来自本地八册清单，40句逐条核对单元、页码和区域；仅四上印刷页51/52、五上印刷页42做过本轮页图人工查看。房屋布局、房间功能划分和活动步骤是原创设计。
- 所有集成检查使用 `user://validation-<pid>.json`，比较了生产存档及其备份哈希。初始受影响文件备份为 [before.zip](before.zip)，保护清单为 [before.json](before.json)。
- 家庭原始场景与主岛人物、其他地标原始素材分开维护。当前同步清单总计42个二/三级场景；本次家庭资产专项覆盖其中8个。

## 使用与复现

重新启动当前项目后，在主岛选择家门进入小院；从客厅出口也可以回到住宅走廊。打开地图选择房间，人物会先步行至门前；走近物件按E或点击提示即可开始。旧开场仍从客厅开始。

在 `F:\LoveStudy` 执行：

```powershell
python -X utf8 scripts/build_home_curriculum.py
python -X utf8 scripts/sync_blender_interiors.py --verify-only --require-all
python -X utf8 scripts/verify_home_hierarchy.py
$godotBin = 'F:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godotBin --headless --path game --import
& $godotBin --headless --fixed-fps 60 --path game --script res://tests/test_home_state.gd -- --test-harness
& $godotBin --headless --fixed-fps 60 --path game --script res://tests/test_home_hierarchy.gd -- --test-harness
& $godotBin --path game --script res://tests/capture_home_hierarchy.gd -- --test-harness
python -X utf8 scripts/build_home_gallery.py
```

`build_home_scenes.py` 用于显式重建本轮程序化初版，会更新本轮新工程。日常手工编辑后应使用已有 `export_existing.py` 从保存的Blender工程导出，避免覆盖后续人工编辑。
