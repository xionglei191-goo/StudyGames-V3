# 进屋后的室内行走 v3 · 验证记录

住宅正门现在直接进入可行走的门厅与走廊。玩家可以沿室内通道走到七扇实体房门，再进入客厅、卧室、厨房、餐厅、浴室、书房或家务阳台；从房间出来会站在室内对应房门前。

[实际进屋过程图册](../../home-indoor-gallery.html) · [正常进门画面](native/02-hall-entry-play.png) · [门厅布局](../../planning/home-indoor-v3/layout.md) · [可编辑模型](../../../assets/blender/interiors/home_hall/home_hall_v01.blend)

## 操作与空间关系

主岛家门 → 小院 → 住宅正门 → 室内门厅与走廊 → 七个三级房间。点击地面或使用方向键移动，走到门前按 E 或点击交互提示进入。室内地图上的按钮只引导角色走到相应房门，到门前后再交互进入。

七个房间的出口返回 `home_hall` 中各自的 `<room_id>_gate`；门厅的 `courtyard_exit` 返回 `home_estate` 的 `house_entry`；小院的 `village_exit` 返回主岛家门。客厅中的“去卧室”生活操作也经过客厅出口、门厅和卧室门。

`home_hall` 是同一住宅的二级室内通行状态，不增加学习层级。门厅有出生、出口与七个房门共9个锚点，不设记忆点或家务任务。家庭仍是8个活动空间、40处生活位置和8项家务。旅行/故事系统的既有快速前往功能未在本次改动中扩展。

## 验证结果

| 范围 | 结果 | 证据 |
|---|---|---|
| 正门进入门厅、七房门及各自返回、原生活点与家务 | 942项通过；62段实际行走、20次切换；40处生活点、8项任务及保存/取消/重做 | [home-indoor-report.json](home-indoor-report.json) |
| 原移动、校园及家庭路径回归 | 244项通过；41段路线、28次切换、1次实际碰撞探针 | [movement-report.json](movement-report.json) |
| 模型、源/运行时一致性、地面朝向与保守可达性 | 94项通过；212份既有资产、8册教材JSON哈希未变 | [asset-report.json](asset-report.json) |
| Godot原生窗口与真实输入路径 | 131项通过；13张截图、7段行走、5次切换；生产存档及备份哈希未变 | [native/report.json](native/report.json) |
| 项目静态检查 | 808文件，0错误、0警告 | [project-check.log](project-check.log) |

使用 Godot 4.7.2 / GL Compatibility、Blender 5.2.2。上述引擎检查退出码均为0，标准错误输出为空。本次完成受影响范围验证，未运行全游戏测试，也未进行新门厅的目标设备性能验收。

原生画面实际检查了进门、客厅/卧室/厨房门前、卧室内部、返回对应门前以及960小窗口游玩和地图。`03-hall-overview.png` 单独使用34米检视镜头并隐藏界面，其余截图保留生产游玩镜头。窗口960×640保持游戏比例后的捕获纹理为960×600，报告同时记录两种尺寸。正常跟随镜头到厨房一侧时，远端墙顶部分超出画面，人物、当前房门与行走通道仍可见。

首次原生尝试在院落地图按钮输入前没有等待嵌套容器完成绘制，点击未启动行走；捕获脚本补充实际布局/绘制等待后完整重跑通过。修正仅位于测试捕获脚本，没有修改生产输入逻辑。失败尝试不计为验收。

## 模型与文件保护

新门厅为原创Blender几何：连续护墙、七扇带用途图标的房门、拼接木地板与T形地毯、鞋凳挂衣、穿衣镜、伞篮、家庭照片、长椅和植物。28×20米地板使用25个简化碰撞代理，家具位于通道边缘。最终GLB为6,798,512字节、760个节点、172,236个实例化三角形，SHA-256 为 `2d14671f9248afcf43fa9090b142d737be77bbb90217ac7113c29b80593ab6b7`。

- 原住宅v01/v02、七个房间模型、教材源、40份绑定语音和历史报告保留。
- 测试使用隔离存档，并比较生产主档及备份哈希。
- 修改前备份：[before.zip](before.zip)、[before.json](before.json)、[flow-before.zip](flow-before.zip)、[flow-before.json](flow-before.json)、[test-before.zip](test-before.zip)、[test-before.json](test-before.json)。
- `test_home_hierarchy.gd` 是当前室内专项的兼容入口，报告写入v3目录；v1/v2证据保留原范围。

## 复现

```powershell
python -X utf8 scripts/sync_blender_interiors.py --verify-only --require-all
python -X utf8 scripts/verify_home_indoor.py
$godotBin = 'F:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godotBin --headless --path game --import
& $godotBin --headless --fixed-fps 60 --path game --script res://tests/test_home_indoor.gd -- --test-harness
& $godotBin --headless --fixed-fps 60 --path game --script res://tests/test_movement.gd -- --test-harness
& $godotBin --path game --script res://tests/capture_home_indoor.gd -- --test-harness
python -X utf8 scripts/build_home_indoor_gallery.py
```

移动回归默认报告位于 `.local/validation/movement-report.json`；本目录保留本次通过版本的副本。原生捕获请单独运行，避免两个游戏窗口争用输入焦点。

`scripts/build_home_hall.py` 可在Blender中运行以重建门厅。人工编辑已有工程后，应保存工程并使用 `export_existing.py` 再导出，避免生成器覆盖手工修改。管线已识别门厅的专用9锚点约定。
