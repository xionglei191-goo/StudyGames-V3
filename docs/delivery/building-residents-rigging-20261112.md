# 34 位建筑居民：Mesh2Motion 绑定与游戏接入

2026-11-12。用户放入目录的 34 个 Tripo GLB 已逐一辨认，绑定骨架，并替换到 A–Z 建筑及 8 个校园区域。每位居民使用自己的模型、姓名和对话身份；点击或走近时可转向玩家并挥手。

同日追加了[动作变形复查](resident-deformation-review-20261112.md)，修正领口与袖子、髋膝关节、团团尾部及放物贴地。以下预览和资产已更新；最新的多角度对照位于[复查预览页](../verification/resident-deformation-review-20261112/index.html)。

运行项目根目录的 `启动字母岛.cmd` 或 `start-game.ps1`，使用当前源项目查看。[全部居民与动作预览](../verification/building-residents-v1/index.html)可搜索姓名、职业和建筑，并下载各自的 GLB 与 Blender 源文件。旧 Windows 导出包及网页构建尚未重新打包。

## 绑定方式与产物

- 使用本机 Mesh2Motion 引擎的真实蒙皮求解器，版本提交 `e66f13ccf00ba0afc07e82d876af016e40792422`，核心求解器未修改。未调用 Tripo 生成接口，未消耗剩余模型生成名额。
- 按每位居民的实际网格拟合人形双足语义骨架；这批动物都是双足拟人居民。骨架为 17 或 18 根骨骼，有尾巴的模型使用独立尾部区域。
- 在求解结果上增加身体、袖子、手臂和腿部的连接面约束，修正宽松外套、围裙、头部及尾巴的权重。第二轮进一步加入连续颈肩、髋部过渡和关节中心修正；仍保留大幅弯腰时的轻微衣褶变形。
- 统一原模型朝向，保留 PBR 材质的工作副本，单角色约 32,000 个三角面。34 个运行模型共 **1,087,979** 个三角面，原始模型共 **65,828,201** 个；原始 GLB 哈希全部保持一致。
- 每个 GLB 包含 14 个基础动作：待机、行走、持物、持物行走、挥手、点头、说话手势、指向、伸手、拾取、放下、递物、接物、拍照姿势。游戏接入既有普通/减少动态动作模式，以及鞋底贴地修正。

| 内容 | 路径 |
|---|---|
| 原始 34 个 Tripo 模型 | `assets/tripo/building_residents_v01/*.glb` |
| 人物身份与原文件对应 | [mapping.json](../../assets/characters/building_residents_v1/mapping.json) |
| 个体关节拟合参数 | [fitting.json](../../assets/characters/building_residents_v1/fitting.json) |
| 可编辑 Blender 文件 | `assets/characters/building_residents_v1/<resident_id>/rigged.blend` |
| 带骨架和动作的交换文件 | 同目录 `character.glb` |
| 求解输入、输出及来源 | 同目录 `solver-input.json`、`solver-output.json`、`rig.json` |
| Godot 正式运行资源 | `game/assets/characters/building_residents_v1/` |
| 身份、模型与房间目录 | 同目录 `catalog.json`、`manifest.json` |

## 游戏接入

房间 `SG_NPC_HOST` 标记绑定独立居民。模型、头顶姓名、交互提示、对话标题、章节委托及 AI 陪伴服务的身份目录使用相同居民 ID。果园、蛋糕坊、食堂和字母发现卡的原有操作保留在对应居民菜单中。

原有 12 个核心角色继续保留其身份与模型。建筑居民通过独立资源目录加载，不占用教材人物的 ID。当前居民仍采用原房间的固定站位；本次提供可驱动的行走动作，没有新增自主巡游日程。

## 验证结果

| 验证 | 结果与证据 |
|---|---|
| 原文件、身份映射、GLB 骨骼、动作和蒙皮 | [资产检查](../../assets/characters/building_residents_v1/asset-checks.json)：34 个来源唯一，原文件哈希未变，无漏绑顶点，每个 GLB 有 14 个动作 |
| 34 位居民原生资源与动作 | [角色报告](../verification/building-residents-v1/characters.json)：1,260 项通过；含全部顶点权重和索引检查、动作变形采样、全部 14 个动作的普通/减少动态贴地检查。之后米洛挥手调整的[定向 39 项](../verification/resident-deformation-review-20261112/c-recheck/characters.json)也通过 |
| 34 个实际房间接入 | [房间报告](../verification/building-residents-v1/rooms.json)：378 项通过；模型、名字、标记位置、交互、委托和正式对话分支身份一致 |
| 原生渲染 | 34 位居民 × 4 种姿势，共 136 张交付截图；追加 612 张三视角复查图。另有 6 个实际房间近景，[房间原生报告](../verification/building-residents-v1/native-rooms/rooms.json) 70 项通过 |
| 原有角色动作回归 | [回归报告](../verification/building-residents-v1/core-animation-regression.json)：623 项通过 |
| 陪伴服务身份 | 定向 pytest：2 项通过、4 项未选择；验证 34 位居民的离线回复使用各自名字，并保留熊叔身份 |

第二轮对全部 14 个动作进行了每模式 49 时点的鞋底检查，最大支撑面误差为 **0.002436 米，约 2.4 毫米**。测试使用隔离存档，并检查正式存档文件哈希。逐一复查了 34 位居民的三视角姿势图；更新后的连续预览展示 5 位代表居民的待机、行走、挥手和递物。

当前交付以身体动作和建筑接入为范围：未制作独立手指抓握、面部表情或口型，也未逐帧精修所有动作中的局部袖口褶皱；尚未进行长时间游玩、帧率性能验收和全项目测试。GLB 内为基础动作，Godot 的步态与鞋底修正位于运行适配层。

## 重建

工具：Blender `F:/Tools/Blender/blender-5.2.2-windows-x64/blender.exe`，Godot `F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe`。Mesh2Motion 默认位于 `F:/VideoMaker/experiments/mesh2motion-robots-20261027/engine`，可通过 `MESH2MOTION_ENGINE` 覆盖。MIT 许可副本保存在资产目录。

1. Blender 后台运行 `scripts/prepare_building_residents.py`，创建精简副本和身份检查图。已有完整副本会跳过。
2. 核对 `fitting.json`，再运行 `scripts/rig_building_residents.py`。可在 Blender 命令尾追加 `-- resident_classroom` 等 ID，仅重建选中居民。
3. 运行 `scripts/finalize_building_residents.py`，检查原始模型、GLB 与权重，生成对应表和游戏挥手曲线。
4. Godot 运行 `res://actors/bake_tripo_characters.gd`，追加 `-- --source=res://../assets/characters/building_residents_v1 --output=res://assets/characters/building_residents_v1`。
5. Godot 运行 `res://actors/bake_tripo_grounding.gd -- --residents`，重烘焙这批居民的鞋底曲线。
6. 运行 `res://tests/test_building_residents.gd` 与 `res://tests/test_building_resident_rooms.gd`，追加 `-- --test-harness`；原生截图再追加 `--capture`。连续预览脚本为 `res://tests/capture_building_residents.gd`，追加 `-- --test-harness --output=<帧目录>`。

本次改动和派生资源保留在当前工作区，未提交或推送 Git。
