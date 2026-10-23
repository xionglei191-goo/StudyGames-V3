# 字母岛场所、校园与家庭房间

42 个可独立加载的场景：`landmark_A`—`landmark_Z`、`school`、`home_estate` 为 28 个二级场所；另有七个校园三级场景与七个家庭三级房间。家庭包括 `home` 客厅、`home_bedroom`、`home_kitchen`、`home_dining`、`home_bathroom`、`home_study`、`home_balcony`。校园编辑 `school/school_v03.blend`，客厅编辑 `home/home_v02.blend`，其余路径以总清单为准。各目录提供可编辑 Blender 工程、GLB、预览和验证记录。

校园 v03 在已完成的 v02 校园东侧增加足球运动区与连通道路，七处三级入口在相应功能区。旧 school_v01 房间和 school_v02 校园保留为历史素材。新增音乐、美术、科学房间拥有分别建模的专业陈设和五个固定探索位置。

总入口：[interiors_manifest.json](interiors_manifest.json)。当前住宅外观编辑 `home_estate/home_estate_v02.blend`，v01剖面原稿保留。当前家庭专项：[外观、入口与素材保护](../../../docs/verification/home-exterior-v2/README.md)。前版房间证据：[家庭层级v1](../../../docs/verification/home-hierarchy-v1/README.md)。此前35场景资产检查：[validation_report.json](reports/validation_report.json)；此前同步记录：[production_status.json](reports/production_status.json)。原31场景回环记录：[roundtrip_report.json](reports/roundtrip_report.json)；校园 v03 与足球场保存后导出记录见 [v0.3.1 证据](../../../docs/verification/v0.3.1/saved-blend-export.log)。历史报告保留其原验证范围。

## 看图

- [住宅外观v2与前版对比](../../../docs/home-exterior-gallery.html) · [家庭三级房间预览](../../../docs/home-hierarchy-gallery.html) · [小院住宅 Blender 预览](home_estate/preview_v02.png) · [新客厅](home/preview_v02.png)
- [完整校园 v03](school/preview_v03.png) · [独立足球场](football_field/preview.png) · [音乐教室](music_room/preview.png) · [美术教室](art_room/preview.png) · [科学教室](science_room/preview.png)
- [原 v01：A— I 接触表](reports/contact_sheet_01.jpg)
- [原 v01：J— R 接触表](reports/contact_sheet_02.jpg)
- [原 v01：S—Z 与旧学校接触表](reports/contact_sheet_03.jpg)
- [原 v01：教室、食堂、操场、家园接触表](reports/contact_sheet_04.jpg)

每张单图为 Blender 实际渲染；原 v01 图为 1100 × 968，新教室为 1400 × 1232，校园 v03 为 1920 × 1280。室内前墙和顶面保持开放，便于俯视观察。预览灯光、相机、背景不导入游戏；游戏光照由 Godot 配置。

## A 果园继承

A 从 `assets/blender/A_orchard/A_orchard_with_apple_house_v02.blend` 复制，不规则岛台、原环路、真实 Tripo 苹果屋、五棵果树、溪流、小桥与 `A_LOCUS_01...05` 均保留。整场统一下移 0.65 米，使原草地基准成为 Blender Z=0，X/Y 布局没有重排。

`SG_MEMORY_*` 放在原道具旁的可站立位置。完整旧点、偏移和理由见 [source_adaptation.json](landmark_A/source_adaptation.json)：篮子前移 0.8 米、果树旁偏移 1.05 米、分拣台前移 0.95 米、洗果池前移 1.05 米、礼物架前移 0.85 米。原五点 Empty 同时保留；两个桥头增加短坡面。

## 空间与内容

固定五点含义以 `game/data/landmark_interiors.json` 为依据，共210点。家庭40点的课本来源与活动另见 `game/data/home_hierarchy.json`。建模采用各场所的生活道具：船和码头、料理岛和烤箱、鼓台、蛋壳照料湾、花床温室、旅行地球仪、穿戴镜、收藏转台、风筝骨架、蘑菇暖炉、枝巢、双翼书架、瓜藤与比较秤、拼布桌、机器人维修臂、天球仪与望远镜、车厢、气象庭院、岩层窗、鲸鱼比例地毯、木琴、绕线器与织机、邮袋与邮戳墙。

整体包含不规则果园、圆角厅、开放庭院、菱形构架工坊、星形地坪、横长站台与舞台、窄长服务亭、学校枢纽与住宅。它们共享温暖的材质和家具工艺；每图的实物用途不同。v01 为可接入的风格化模型，精细装饰、角色表演和设备性能调优可在用户审阅后继续。

## 保存 Blender 后导出

正常更新只运行 [export_existing.py](scripts/export_existing.py)。它读取已保存的工程，导出并刷新预览与清单，不导入生成器，也不重新保存或覆盖 `.blend`。

```powershell
$blenderExe = 'F:\Tools\Blender\blender-5.2.2-windows-x64\blender.exe'
& $blenderExe --background --factory-startup --python 'F:\LoveStudy\assets\blender\interiors\scripts\export_existing.py' -- --room home
& $blenderExe --background --factory-startup --python 'F:\LoveStudy\assets\blender\interiors\scripts\export_existing.py' -- --all
```

`--no-render` 可保留现有预览以便快速集成；正常美术交付应重新渲染。`--verify-only` 将回环输出写到验收目录，并检查正式 GLB 与 `.blend` 的哈希保持不变。

[build_interiors.py](scripts/build_interiors.py) 是显式重建工具，只适用于重建程序化初版。默认跳过已存在的工程；`--overwrite` 会替换目标工程，因此不应放进日常“保存 Blender → 更新游戏”入口。

```powershell
& $blenderExe --background --factory-startup --python 'F:\LoveStudy\assets\blender\interiors\scripts\build_interiors.py' -- --room landmark_C
```

## 编辑约定

- Blender 单位为米，Z 向上；GLB 标准 Y 向上。清单 `bounds` 使用 Godot XZ 的 `[xmin,zmin,width,depth]`。
- 保留 `SG_SPAWN`、`SG_EXIT`、`SG_NPC_HOST` 和 `SG_MEMORY_01...05`。学校与住宅各保留七个 `SG_DOOR_*`；卧室保留床和衣柜点，客厅保留原五点与三组装饰点。
- 每个家庭场景的 `HOME_TASK_BEFORE`、`HOME_TASK_MIDDLE`、`HOME_TASK_AFTER` 为独立道具状态根。运行时依据活动或存档选择显示，不能在导出时遗漏隐藏状态。
- `SG_FLOOR_*` 和 `SG_COLLIDER_*` 都是真实网格。代理材质透明、Blender 渲染隐藏，但会导出；引擎按名称生成简化碰撞并隐藏它们。
- `SG_DECOR_MODEL_FLOWER_BOX`、`SG_DECOR_MODEL_PICNIC`、`SG_DECOR_MODEL_LAMP` 分别是独立父节点，可整体显隐。装饰不是同一个盆栽的占位替身。
- 移动物件时同时检查对应交互 Empty 和简化碰撞代理。交互点是旁侧站位，不应放到桌子、柜子或墙内部。重新导出后运行校验器。
- A 的苹果屋贴图已内嵌。其他场景使用 glTF 基础颜色与粗糙度，不依赖外部贴图或仅 Blender 可用的程序材质。

## 校验与边界

```powershell
& 'C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'F:\LoveStudy\assets\blender\interiors\scripts\validate_interiors.py' --contact-sheets
```

校验器检查42场景的 GLB 结构、必需节点、实际地面/碰撞网格、有限坐标、内嵌纹理、PNG 尺寸、210点的策划标签、关联道具以及原资产哈希。通行检查使用0.32米人物半径、0.20米网格，从出生点到各交互点验证二维连通性；不代替 Godot 角色物理、上下坡和场景返回测试。家庭专项可运行 `python -X utf8 scripts/verify_home_hierarchy.py`，另核对八场景地面朝向、196份原素材、八册教材源与40份绑定语音哈希。

S 地面曾因星形轮廓的顺时针顶点顺序导致顶面反向，现已仅重算法线与面朝向，保留顶点及全部 SG 锚点。校验器增加了 S 导出 GLB 的索引三角面朝向检查，以及 8 个锚点下方的单面地面命中检查；具体见 [S 地板修复记录](reports/S_floor_fix/repair_report.json)。Godot 行走复测由游戏接入会话负责。

本目录仅交付美术、入口标记、代理碰撞和工具。NPC 行为、语音、任务流程、存档、运行时碰撞与性能验收由游戏接入负责。本次未提交或推送 Git。
