# 人物步态调整 · 2026-11-12

已应用到当前 Godot 项目的玩家和 10 位可步行 NPC。重新运行项目根目录的 `启动字母岛.cmd` 或 `start-game.ps1` 即可使用。

## 调整内容

- 玩家原先用大腿摆角按比例驱动膝盖，理论最大屈膝仅约 20°，脚踝没有步行动作。现在使用连续的落脚、承重、蹬地、屈膝摆腿曲线；摆腿峰值约 62°，支撑阶段保留轻微屈膝。
- 脚踝抵消大腿、小腿的累计转角，再叠加脚掌滚动，避免鞋子僵硬地跟随整条腿转动。
- 玩家和 NPC 共用步态曲线；NPC 普通行走和持物行走的贴地数据已重新烘焙。非行走动作明确复位脚踝，避免动作切换后残留角度。
- 玩家起停使用与帧率无关的混合，保留距离驱动步相。全速步态周期由约 0.53 秒调整到约 0.71 秒；人物移动速度不变。
- 去除蒙皮角色整体上下浮动与整身倾斜，改由骨盆和脊柱表现重心变化。按真实蒙皮鞋底校准骨盆，同时补偿碰撞体底部与人物原点之间的 5 厘米高度差。
- 持物、挥手、伸手、踢腿和减少动态效果继续可用；轮椅角色保留原有动作限制。

## 预览

- [调整前后动画](../verification/walk-refinement-20261112/walk-before-after.gif)：同一模型、相机和受控步频下，左侧为调整前，右侧为调整后；各展示侧面和斜前方。此处是原地步态检查台，不是位移录像。
- [连续姿势对照](../verification/walk-refinement-20261112/player-contact-sheet.jpg)。
- [真实岛屿近景](../verification/walk-refinement-20261112/gameplay-walk.png)：运行正式主场景，通过原有导航行走，仅测试相机拉近并隐藏 HUD。

## 验证

| 检查 | 最终结果 | 记录 |
|---|---:|---|
| 玩家及 10 位 NPC 的膝盖、脚底、抬脚、循环连续性、动作复位；玩家 30/60/120 Hz 起停、慢走、全速、转向、持物、撞墙、减少动态 | 391 项通过 | [gait.json](../verification/walk-refinement-20261112/gait.json) |
| 现有角色动作、语义接触、暂停、轮椅与移动约束 | 623 项通过 | [actor-animation.json](../verification/walk-refinement-20261112/actor-animation.json) |
| 真实地图移动 | 244 项通过；41 条路线、28 次场景切换、1 个碰撞探测 | [movement.json](../verification/walk-refinement-20261112/movement.json) |

玩家完整控制器的平地鞋底最大支撑误差为约 4.1 毫米；步态采样中双膝峰值为 62°。地图测试确认正式存档未改变。验证过程中曾发现 5 厘米碰撞体高度偏差，已修复并重新运行上述最终检查；撞墙用例也改为正向接触，区分沿墙滑动与真正静止。

测试引擎为 Godot 4.7.2，原生画面使用 Forward+ / RTX 4070。脚底误差数值来自平地测试；斜坡、台阶尚未增加逐脚地形 IK。此次未进行全仓库测试、长期性能验收或旧 Windows/Web 包重新导出。

## 维护入口

- 步态曲线：`game/actors/walk_gait.gd`。
- 玩家骨骼及鞋底采样：`game/actors/player_visual_v3.gd`、`game/actors/foot_support.gd`。
- 玩家步频及视觉高度：`game/scripts/player.gd`。
- NPC 动画适配：`game/actors/character_art_v3.gd`。
- 修改步态曲线后，运行 `godot --headless --path game --script res://actors/bake_tripo_grounding.gd`，同步 `game/assets/characters/tripo_v1/grounding.json`。
- 专项检查：`godot --headless --fixed-fps 60 --path game --script res://tests/test_walk_gait.gd -- --test-harness --report=<绝对报告路径>`。
- 原生取景：`game/tests/capture_walk_cycle.gd`，参数 `-- --test-harness --capture-dir=<绝对目录>`；增加 `--gameplay` 可采集正式岛屿场景。

本次调整在 Godot 动画层完成。原始模型、蒙皮、Blender/GLB 动作和 P1 源动作库未改写。
