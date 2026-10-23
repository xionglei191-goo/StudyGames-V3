# 字母岛 Blender 地图版验收记录

## v0.3.2 柔和自然配色

2026-10-22 更新。降低强直射光与大面积黄绿色的刺激感，背景调整为浅青灰；主岛保留环境填光，校园及室内保留米色道路、木色家具和白色装饰的层次。实际比较原版、低照度 Linear、AgX、ACES 与最终自然配色后，采用当前运行时光照配置。Blender 源资产、地图布局、碰撞、交互和存档格式未调整。

采集五个主岛视点、35 个场景与校园/足球场总览，共 42 张实际引擎画面；独立视觉复查覆盖主岛、校园、足球场、果园、烘焙坊、星形天文台、休眠火山观察站与家园八个代表场景。Windows v0.3.2 成品实际运行通过 66 项集成检查，错误日志为空。本轮为渲染调整，未重复 v0.3.1 的 210 段物理行走回归。

证据：[配色判断与方向](美术风格与配色方向.md)、[主岛画面](screenshots/v0.3.2/world_home.png)、[校园总览](screenshots/v0.3.2/school_overview.png)、[球场画面](screenshots/v0.3.2/native-football_field.png)、[Windows 集成报告](verification/v0.3.2/native-integration-report.json)、[构建信息](verification/v0.3.2/build-info.json)、[安装包校验](verification/v0.3.2/package-report.json)。

## v0.3.1 校园足球场

2026-10-22 更新。校园在 v02 基础上向东增加足球运动区与连接道路，另存 `school_v03.blend`，总范围为 76 × 40 米。原建筑、六处旧入口和五个校园记忆点的位置保留。新增第七入口 `SG_DOOR_FOOTBALL_FIELD`，进入独立三级场景 `football_field`，退出回到校园相同入口。

独立足球场为 34 × 28 米园区，其中草地为 26 × 18 米的小型校园比例。包含双球门与球网、边线、中线、中圈、禁区、角旗、装备架、传球锥桶、看台和示例比分牌。五个探索点分别为装备区、开球中圈、射门球门、传球练习区、看台/计分牌。当前提供行走探索和器材介绍，足球及比分牌是静态道具，未实现比赛系统。

| 检查 | 本轮结果 |
|---|---|
| 校园层级与菜单 | 352 项检查、56 段真实行走、16 次转换通过；实际鼠标操作九项校园导航，走过校园及七个子场景的 40 处固定点 |
| 35 场景回归 | 2224 项检查通过，实际经过 175 个固定点和 35 个出口，共 210 段路线；36 份主图/场景导入缓存与源资源对应 |
| 生活路线 | 209 项检查、35 段路线、22 次转换及喷泉碰撞检查通过 |
| 足球场往返 | 五点与出口均实际走通；从球场退出回到校园新入口，落点与入口偏差约 0.354 米 |
| 状态与界面 | 状态测试通过；80 项鼠标界面检查通过，覆盖 1440×900 和 960×640；测试使用独立存档，生产存档保持不变 |
| Windows 成品 | 实际运行 v0.3.1 EXE/PCK，66 项集成检查通过，包含足球场进入、三级层级和同门返回 |
| Blender 与资产 | 35 场景资产检查通过，115 个原始素材哈希不变；从保存的校园 v03 和足球场 v01 重新导出成功，两份 Blender 源文件均未改变 |
| 画面 | 复核校园总览、新入口、校园导览、足球场入场与全景、探索卡片及 Windows 成品实际画面；新增源场景截图共八张 |

当前源文件为 `assets/blender/interiors/school/school_v03.blend` 和 `assets/blender/interiors/football_field/football_field_v01.blend`。旧校园 v01、v02 及字母岛主图保留。日常更新仍通过“保存 Blender → 更新Blender地图.cmd → 重新启动游戏”。

证据：[校园路线](verification/v0.3.1/school-hierarchy-report.json)、[35 场景回归](verification/v0.3.1/blender-world-report.json)、[Windows 成品集成](verification/v0.3.1/native-integration-report.json)、[源文件保护](verification/v0.3.1/protected-originals.json)、[校园总览](screenshots/v0.3.1/school_overview.png)、[独立球场](screenshots/v0.3.1/football_overview.png)。本轮未验证低性能设备帧率或 Web 发布。

## v0.3.0 完整校园与三级场景

2026-10-22 更新。学校由旧的房间尺度场景调整为 48 × 40 米完整校园，复用原钟楼教学楼及校园道具，连接普通教室、音乐教室、美术教室、科学教室、餐厅和操场六处三级场景。中央花园、主路和环路组织功能区，六处入口位于各自建筑或活动区门前。

音乐、美术和科学教室新增独立可编辑 Blender 工程与专用陈设，原普通教室、餐厅、操场继续作为三级场景使用。全项目主岛外共有 28 个二级场景和 6 个三级场景、170 个固定探索点。进入各房间后退出会回到校园同一门前，离开校园才回到字母岛校门。

| 检查 | 本轮结果 |
|---|---|
| 学校完整路线 | 313 项检查、49 段真实行走、14 次场景转换通过；实际鼠标选择校园八项导航及五点子页，逐门进入六室并返回原门 |
| 34 场景回归 | 2158 项检查通过，角色实际经过 170 个固定点和 34 个出口，共 204 段路线；最近交互、父级、返回门及导入缓存均验证 |
| 生活路线 | 193 项检查、32 条路线、20 次场景转换和喷泉碰撞检查通过 |
| 状态与界面 | 状态测试通过；80 项实际鼠标界面检查通过，覆盖 1440×900 与 960×640 窗口 |
| Windows 发布成品 | 实际运行 v0.3.0 EXE/PCK，64 项集成检查通过，输出 11 张实际画面；新增三室进入及返回校园同门均通过 |
| 资产检查 | 34 场景结构、标记、计划标签和代理通行检查通过，115 个原始资产哈希不变 |
| 日常编辑导出 | 从保存的校园 v02 和三个新教室工程重新导出成功，四份 Blender 源文件均未改变，清单保留 v02 路径 |
| 实际画面 | 复核游戏引擎中的完整校园、入校视角、校园导览、音乐、美术和科学教室画面；保留晴天光照 |

校园日常编辑文件为 `assets/blender/interiors/school/school_v02.blend`。旧 `school_v01.blend/glb`、原校园 `school_campus_v01.blend` 和字母岛主图保持原样。测试使用独立存档，生产存档未改动。

证据：[学校路线](verification/v0.3.0/school-hierarchy-report.json)、[34 场景回归](verification/v0.3.0/blender-world-report.json)、[生活路线](verification/v0.3.0/movement-report.json)、[原生 Windows 集成](verification/v0.3.0/native-integration-report.json)、[原件哈希](verification/v0.3.0/protected-originals.json)、[校园总览](screenshots/v0.3.0/school_overview.png)。

本次完成空间层级、建模和探索接入。新教室目前提供地点与器材介绍，完整演奏、绘画、实验玩法及对应课程尚未实现；已有普通教室英语任务继续使用。

## v0.2.1 晴天光照更新

2026-10-22 更新。提亮主岛环境光，背景改为浅蓝，阳光略暖并减淡投影。主岛与浅色二级地图分别配置光照，避免室内地砖、蛋糕台面和白墙过曝。Blender 几何、地图布局、交互规则与存档格式沿用 v0.2.0。

本次实际生成 36 张引擎画面，复查主岛、果园、烘焙坊、小屋和教室；Windows 发布成品另生成 8 张画面，57 项集成检查全部通过。检查包含 32 条主岛路线规划、任务奖励、三课完成、18 条语音解码和存档往返。本次为光照调整，未重复 v0.2.0 的 186 段物理实走与完整界面测试；下文的大范围验收仍对应 v0.2.0。

- [新版主岛实际画面](screenshots/v0.2.1/world_home.png)、[果园](screenshots/v0.2.1/landmark_A.png)、[烘焙坊](screenshots/v0.2.1/landmark_C.png)
- [v0.2.1 原生 Windows 集成报告](verification/v0.2.1/native-integration-report.json)
- [v0.2.1 构建信息](verification/v0.2.1/build-info.json)、[安装包哈希与 CRC 检查](verification/v0.2.1/package-report.json)

## v0.2.0 地图接入验收

验收日期：2026-10-22。制作环境：Windows、Godot 4.7.2、Blender 5.2.2；实际渲染设备为 NVIDIA RTX 4070。本记录覆盖已交付的本地 Windows 版本。

## 交付范围

主岛完整导入原 v05 地形、道路、建筑与材质，另存为 `alphabet_island_layout_v06_game.blend`，保留原件。游戏读取 33 个 Blender 交互标记的实际变换，不再用 Godot 重建地图布局。

已制作并接入 A—Z、学校、教室、食堂、操场和家园，共 31 个二级地图、155 个固定记忆位置。每图提供可编辑 Blender 工程、GLB 和预览。A 果园保留原工程的不规则岛台、苹果屋、溪流、小桥及原五点布局。

生活玩法保留问候、采摘、交付、烘焙与出售、三种家园装饰、换装、休息和前三单元课程。其他地标当前提供空间探索、地点介绍及固定位置卡片；策划中的完整行业经营任务尚未实现。

## 验证结果

| 检查 | 结果与范围 |
|---|---|
| 原始资产保护 | 115 个原资产哈希未变；主岛 v05 Blender/GLB 单独校验未改动 |
| Blender 更新流程 | 已保存工程重新导出、同步、字体更新、Godot 导入与 Windows 构建通过；日常入口不调用场景生成器 |
| 编辑保留 | 在隔离主岛副本中将 `SG_DOOR_A` 移动 0.375 米，导出后变换保持；真实 v05/v06 原件哈希未变 |
| 二级地图回环 | 31 份保存后的 Blender 工程重新打开并导出，节点变换及几何数量一致；正式源工程受保护 |
| 31 地图实走 | 1832 项检查通过；角色实际走过 155 个记忆点与 31 个出口，共 186 段，逐点检查最近交互并实际打开卡片或退出 |
| 导入缓存 | 主岛加 31 内景的导入缓存与当前 GLB 源文件一致，避免旧缓存造成假通过 |
| 返回位置 | 31 个内景返回对应主岛/校园入口，最大偏差约 0.421 米 |
| 主岛入口 | 出生点到 32 个交互位置实走通过；学校到家园反向实走单独通过；33 标记坐标核对零误差 |
| 水域 | 四方向持续向湖心移动，真实水面/陆地射线检查中站水帧数均为零；岸路仍可走通 |
| 完整生活路线 | 23 段真实步行、14 次场景转换、喷泉实体阻挡、家中睡觉与装扮按钮通过 |
| 状态与存档 | 持久化、备份恢复、奖励、库存、学习记录、格式守卫通过；测试使用隔离存档，生产存档未改动 |
| 界面 | 80 项实际鼠标派发检查通过，包含 1440×900 与 960×640 窗口 |
| Windows 成品 | 实际运行导出的 EXE/PCK，57 项集成检查通过；问候、交付、三课完成、18 条语音解码和存档往返通过 |
| 画面 | 引擎导出 36 张全岛/内景画面，原生 Windows 成品另导出 8 张；复查主岛、A/B/C/S、学校、家园及课程面板 |

本次修复了顶点色未启用、短地形台阶阻挡、家中记忆点遮住生活操作、水面误作可站地面，以及 S 天文台地板法线反向等实际问题。S 已在 Blender 源工程中修正，全部六段内景实走通过。

## 证据与复现

- [31 地图实走报告](verification/v0.2/blender-world-report.json)
- [生活路线报告](verification/v0.2/movement-report.json)
- [主岛 32 路线](verification/v0.2/main-navigation-report.json)、[学校返回家](verification/v0.2/school-home-report.json)、[水域检查](verification/v0.2/water-report.json)
- [原生 Windows 集成报告](verification/v0.2/native-integration-report.json)
- [主岛编辑保留实验](verification/v0.2/world-edit-roundtrip.json)
- [二级地图资产验收](../assets/blender/interiors/reports/acceptance_report.json)、[Blender 导出回环](../assets/blender/interiors/reports/roundtrip_report.json)
- [S 地板修复记录](../assets/blender/interiors/reports/S_floor_fix/repair_report.json)

运行 `build-game.ps1` 可重新执行状态、生活路线、31 地图、界面及集成检查后打包。`sync-blender-game.ps1` 在此前增加保存工程导出和资源同步；`-SyncOnly` 使用已经导出的 GLB。最终构建日志位于 `build/logs/`。

## 使用边界

原版 v0.1 包保留，当前启动脚本使用新的 v0.2 成品。玩家存档位置与格式沿用 v0.1。课程仍为三年级上册前三单元的 9 个新编情境和 18 条 Jenny 合成语音，未扩大为完整教材或口语测评。

本次未验证 Web、手机、低性能设备或长时间运行性能。Blender 预览与游戏使用不同的灯光配置；地图修改仍需完成导出、同步和重新打包，已发布 EXE 不会随着保存 `.blend` 自动变化。
