# 56 个新增模型：命名、绑定与游戏接入

2026-11-12。用户生成的 **48 个优先模型 + 8 个章节候选**已全部处理：**40 个带骨架角色、16 件道具**。按参考图逐个确认身份后修改原始 GLB 文件名，56 个文件改名前后的 SHA-256 一致；本轮没有调用 Tripo 生成接口。

[打开素材预览与下载](../verification/textbook-expansion-v1/index.html) · [连续动作视频](../verification/textbook-expansion-v1/expansion-motion.mp4) · [原名与新名对照 CSV](../../assets/tripo/generation_selection_20261112/model-renaming.csv) · [完整检查索引](../verification/textbook-expansion-v1/review.json)

## 交付内容

| 素材 | 数量 | 处理与动作 |
|---|---:|---|
| 人物、直立拟人动物 | 28 | 按体型拟合双足骨架；每个角色 14 个动作，含行走、招呼、指向、接递物与放物 |
| Robbie 机器人 | 1 | 按机械身体比例拟合关节；14 个动作 |
| 自然四足动物 | 8 | 区分前后腿、头颈、尾巴、耳朵，Ella 另有象鼻控制；6 个适配动作 |
| 鸟类 | 2 | 鸟类骨架、翅膀与尾部；6 个适配动作 |
| Fendi 鱼类 | 1 | 鱼类骨架、鱼鳍与摆尾游泳；6 个适配动作 |
| 场景、穿戴和手持道具 | 16 | 校准尺寸、朝向、底部原点与挂点；通过帽子、背包、手持和家具的既有工厂载入 |

所有角色保留 `rigged.blend`、带蒙皮与动作的 `character.glb`、拟合参数及来源。四足、鸟和鱼的动作包括待机、行走/游泳、招呼、点头、说话姿态与拍照姿态；游戏会拒绝这些角色不适用的人类接递物动作。

角色采用本地 Mesh2Motion 求解器，随后按人体、衣袖、裙摆及动物解剖区域调整连续权重。40 个原始角色共约 5,717 万三角面，工作副本共 1,279,954 面，单角色约 3.2 万面；道具为每件约 1.2 万或 1.6 万面。道具使用静态网格与挂点，穿戴、持物时跟随对应骨骼运动。

原始模型已按 `textbook_角色名.glb`、`prop_道具名.glb` 命名，仍位于用户放入的 `assets/tripo/generation_selection_20261112/` 下。CSV 和 JSON 同时保存原 UUID 文件名、新名、角色身份、路径及哈希。

## 复查中修正的问题

- 长袍下摆原先部分跟随小腿，弯腰和行走时牵拉。按网格连接关系重新区分衣摆与鞋脚，加入独立裙摆骨骼、较小步幅和骨盆转动补偿。
- 孔子的宽袖、Old Macdonald 的背带裤侧边及部分短腿角色出现局部权重突变。9 个角色改为最多 8 个骨骼影响，并加强相邻顶点权重过渡；其余角色保留已有配置。
- 孔子、Spot 和屠呦呦的指向动作仍超出衣袖适合的活动范围，已收小对应手臂幅度，保留原动作时长和接触时点。
- 普通/减少动态模式均纳入检查；39 个陆地角色完成贴地烘焙，Fendi 使用游泳动作。

## 验证结果

| 检查 | 结果 | 记录 |
|---|---|---|
| 56 个原始模型、身份、命名及来源 | 数量与清单一致，56 个哈希保持一致 | [命名 JSON](../../assets/tripo/generation_selection_20261112/model-renaming.json) |
| 40 个角色实际蒙皮、权重、动作和脚底 | 全量 **1,304 项通过** | [全量报告](../verification/textbook-expansion-v1/full-tests/characters.json) |
| 全量检查后修正的 9 个角色 | **335 项通过**，这些角色的最终结果以复查为准 | [复查报告](../verification/textbook-expansion-v1/recheck-tests/characters.json) |
| 40 个角色、全部允许动作、两种动态模式、每动作 17 个时点 | **16,048 个变形采样**；高拉伸标记角色从 9 个降为 0 个，当前网格资源哈希已核对 | [最终量化记录](../verification/textbook-expansion-v1/final-metrics/summary.json) |
| 39 个陆地角色、全部允许动作、两种模式、每动作 49 个时点 | **45,668 个支撑采样**；最终最大脚底误差约 **2.6 毫米** | [合并结果与范围](../verification/textbook-expansion-v1/review.json) |
| 16 个道具工厂及 12 种玩家穿戴/持物组合 | **62 项通过**；84 张正/侧/背面截图 | [道具报告](../verification/textbook-expansion-v1/props/props.json) |
| 正式主场景逐个生成 40 个角色，检查名字、交互、允许动作、持物或拒绝不适用动作、移除 | **718 项通过**；40 张实际场景截图，隔离测试存档，正式存档哈希未变 | [主场景报告](../verification/textbook-expansion-v1/world/world.json) |
| 原有核心角色动作回归 | **623 项通过** | [动作回归](../verification/textbook-expansion-v1/core-animation-regression.json) |
| 原有 34 个建筑居民房间接入回归 | **378 项通过** | [房间回归](../verification/textbook-expansion-v1/resident-regression/rooms.json) |
| 本地素材预览页 | 379 个链接有效，624 张切换图片成功解码；搜索、筛选、视频播放与跳转、390 px 移动布局通过 | [预览页检查](../verification/textbook-expansion-v1/gallery-checks.json) |

原生画面使用 Godot 4.7.2 / Vulkan Forward+ / RTX 4070。已逐个复看 40 位角色的最终三视角，包含 816 张动作图：双足角色重点检查待机、行走、招呼、拍照、递物、放物和持物行走；动物检查适配动作，并增加修正角色的可疑时点。7 位代表角色另有 **414 帧、24 fps、17.25 秒**连续预览，视频已完整解码验证。

高拉伸标记针对静止长度超过 6 毫米的网格边：变形后超过原长 3 倍，且增加超过 45 毫米。较轻标记为超过 2 倍且增加超过 25 毫米。标记用于定位可疑位置，配合原生画面判断。最终较轻标记最多为单角色单时点 37 条边；部分袖口、外套仍有轻微压缩和拉伸，例如 Spot 抬臂时衣服会跟随肩部变化。

没有新增布料模拟、独立手指抓握、面部表情或口型。脚底数据来自平地采样；没有新增逐脚地形 IK，也未穷举所有自穿插情况。本次没有进行全项目测试、长期游玩或 GPU 帧率性能验收。

## 在游戏中使用

重新启动根目录的 `启动字母岛.cmd` 或 `start-game.ps1`，即可加载更新后的源项目资源。16 件道具接入了既有穿戴、持物与家具入口。40 个新角色已能通过正式角色加载器生成和执行动作，并已在主场景逐个验证；本次没有为所有新角色逐章编写出场剧情。素材预览页可以直接查看全套角色与道具，不必逐章寻找。

旧 Windows 导出包与网页构建未重新打包。GLB 保存基础动作，Godot 中的步态、裙摆和贴地适配还会参与游戏内动作，因此独立播放 GLB 与游戏内效果可能不同。

## 文件与复现

- 原始模型与命名表：`assets/tripo/generation_selection_20261112/`。
- 角色源文件、求解结果与参数：`assets/characters/textbook_expansion_v1/<角色ID>/`；统一参数在 `catalog.json`、`fitting.json`。
- 角色运行资源：`game/assets/characters/textbook_expansion_v1/`。
- 道具可编辑源：`assets/props/tripo_expansion_v1/<道具ID>/`；运行资源：`game/assets/props/tripo_expansion_v1/`。
- 运行适配：`character_art_v3.gd`、`expansion_animation.gd`、`textbook_actor.gd`、`tripo_prop_library.gd`；穿戴和家具继续使用原工厂入口。

重建时使用项目当前的 Blender 5.2.2 与 Godot 4.7.2。顺序如下，骨骼资源烘焙完成后才能烘焙贴地数据：

```powershell
$assetBlender = 'F:/Tools/Blender/blender-5.2.2-windows-x64/blender.exe'
$assetGodot = 'F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe'
$assetPython = 'F:/ComfyUI/.venv312/Scripts/python.exe'

# 在 F:/LoveStudy 中运行。已有 prepared.blend 可直接用于重新绑定。
& $assetBlender -b --python scripts/rig_textbook_expansion.py
& $assetBlender -b --python scripts/rig_expansion_creatures.py
& $assetBlender -b --python scripts/prepare_expansion_props.py
& $assetPython scripts/finalize_textbook_expansion.py
& $assetGodot --headless --path game --script res://actors/bake_tripo_characters.gd -- --source=res://../assets/characters/textbook_expansion_v1 --output=res://assets/characters/textbook_expansion_v1
& $assetGodot --headless --path game --script res://actors/bake_tripo_grounding.gd -- --test-harness --expansion
& $assetGodot --headless --editor --path game --import
```

角色检查使用 `test_building_residents.gd -- --test-harness --expansion --output=<绝对目录>`；道具与正式场景使用 `test_expansion_props.gd`、`test_expansion_world.gd`，追加 `--capture` 可保存原生截图。变形导出使用 `export_resident_deformations.gd` 的 `--expansion` 参数，再由 `scripts/audit_resident_deformations.py` 测量。三视角与连续预览入口分别是 `capture_resident_review.gd`、`capture_expansion_motion.gd`。修改资源后需重新生成相应验证记录；`scripts/finalize_expansion_review.py` 会核对记录中的资源哈希，拒绝把旧检查当作新资源的结果。

改动保留在当前工作区，未提交或推送 Git。
