# 建筑居民动作变形复查

2026-11-12。针对用户提供的团团挥手截图，重新检查了 34 位居民。确认旧版本仍有领口和袖子牵拉、团团尾部串权重、关节中心偏向表面、拍照抬臂过高及放物动作离地等问题，已修正并更新源项目中的正式运行资源。

[打开前后对照与全部三视角](../verification/resident-deformation-review-20261112/index.html) · [更新后的连续动作预览](../verification/building-residents-v1/residents-motion.mp4) · [完整资产交付](building-residents-rigging-20261112.md)

## 发现与修正

| 问题 | 修正 |
|---|---|
| 头部按高度硬切权重，弯腰和抬臂时领口、肩膀出现折断和尖角 | 改为连续颈肩过渡，保持上半脸刚性；用连接网格平滑局部权重 |
| 宽松袖子与躯干牵连，腋下局部被拉长 | 扩宽肩部过渡，保留明确的手臂和躯干区域；对宽衣角色加强平滑及连续关节约束 |
| 团团的短尾巴受到腿部骨骼影响，走路或弯腰时拉成长条 | 加入独立尾骨和限定尾部区域，修正臀部与双腿之间的权重 |
| 网格顶点密度使髋、膝中心偏向前后表面 | 使用对向表面分位边界的中点拟合关节；重新检查全部居民侧面动作 |
| 拍照动作的大幅抬臂挤向大头角色的脸，部分挥手牵拉袖口 | 为居民制作肩部附近的拍照姿势；分别调整团团、绵姨、布爷爷和米洛的挥手角度 |
| 放下物品时过度伸臂，同时部分鞋底离地或陷地 | 保留接触和恢复时点，收小右上臂角度；为居民的放物动作增加 60 Hz 鞋底校正。复查过程中发现的最大脚底偏差约 7.4 厘米 |
| 跳跳屈膝时存在局部网格突变 | 加强膝部周围的连续权重平滑，并重新检查行走和持物行走 |

![团团挥手前后对照](../verification/resident-deformation-review-20261112/tuantuan-wave-before-after.jpg)

![团团尾部前后对照](../verification/resident-deformation-review-20261112/tuantuan-tail-before-after.jpg)

## 验证范围与结果

测试针对实际 Godot 蒙皮、骨骼变换及运行时动作库。图像使用本机 Godot 4.7.2 / Vulkan Forward+ 原生渲染。34 个原始 GLB 的哈希仍保持一致；这轮没有调用模型生成接口。

| 检查 | 结果 |
|---|---|
| 34 位居民 × 14 个动作 × 普通/减少动态 × 每动作 17 个时点 | **16,184 个变形采样**；高拉伸标记角色从 33 位降至 0 位 |
| 全部动作的鞋底支撑，每动作每模式 49 个时点 | **46,648 个支撑采样**；最大误差 **0.002436 米，约 2.4 毫米** |
| 正式角色资源、全部顶点权重、动作与脚底检查 | [全量 1,260 项通过](../verification/building-residents-v1/characters.json) |
| 全量检查后，米洛挥手角度的最后调整 | [定向 39 项通过](../verification/resident-deformation-review-20261112/c-recheck/characters.json)；其截图、量化结果已更新为定向复查版本 |
| 34 个房间的模型、名字、交互及对话身份 | [378 项通过](../verification/building-residents-v1/rooms.json) |
| 6 个实际房间原生复查，包含团团所在 M 建筑 | [70 项通过](../verification/building-residents-v1/native-rooms/rooms.json) |
| 原有角色动作回归 | [623 项通过](../verification/building-residents-v1/core-animation-regression.json) |
| 视觉复查 | 34 位居民 × 待机、挥手、拍照、放物、持物行走、行走 × 正/侧/背面，共 **612 张图**；最后的放物姿势、跳跳和米洛再次检查 |
| 连续预览 | 5 位代表居民，201 帧，24 fps，8.375 秒；重新编码并验证可完整解码 |

高拉伸标记定义：只检查静止长度大于 6 毫米的网格边；变形后超过原长 3 倍，并增加超过 45 毫米。较轻标记使用超过 2 倍且增加超过 25 毫米。标记用于定位可疑变形，结合视觉复查判断；未把“没有标记”当作所有画面完全无缺陷的证明。当前仍有大幅弯腰时的局部衣褶压缩和轻微拉伸，较轻标记最多为单角色单个采样中的 38 条边。

本轮已消除所检查视图中的明显拉尖、尾部异常拉长和脚底偏移。没有新增布料模拟、独立手指抓握、面部表情或口型，也没有逐帧穷举全部插值状态或自动检测全部自穿插。未进行长时间游玩、全项目测试与帧率性能验收。

## 使用与复现

运行项目根目录的 `启动字母岛.cmd` 或 `start-game.ps1`，重新启动源项目即可加载更新后的角色。旧 Windows 导出包与网页构建没有重新打包。GLB 保存基础动作；Godot 的步态和贴地校正仍由运行适配层提供，因此独立打开 GLB 的动作表现可能与游戏内不同。

本轮主要文件：

- `scripts/rig_building_residents.py`、`assets/characters/building_residents_v1/fitting.json`：关节拟合、连续蒙皮和居民动作。
- `scripts/finalize_building_residents.py`：资产检查，保留普通和减少动态模式下的挥手、拍照及放物曲线。
- `game/actors/bake_tripo_grounding.gd`、`game/actors/character_art_v3.gd`：居民放物贴地适配。
- `game/tests/export_resident_deformations.gd`、`scripts/audit_resident_deformations.py`：导出实际蒙皮变换，并测量变形和支撑面。
- `game/tests/capture_resident_review.gd`、`game/tests/test_building_residents.gd`：原生三视角与全动作检查。

重建沿用完整交付文档的顺序：绑定 → `finalize_building_residents.py` → `bake_tripo_characters.gd` → `bake_tripo_grounding.gd -- --residents`。必须等角色资源烘焙完成后再烘焙贴地数据。随后运行角色、房间和动作回归检查。

[复查记录及最终配置哈希](../verification/resident-deformation-review-20261112/review.json)保存了检查范围、结果和限制；[逐角色量化结果](../verification/resident-deformation-review-20261112/final-metrics/summary.json)可回查具体动作。修正前的派生资源保存在同目录 `before-rigs.zip`，原始模型未改动。测试使用隔离存档，正式存档哈希检查通过。

改动保留在当前工作区，未提交或推送 Git。
