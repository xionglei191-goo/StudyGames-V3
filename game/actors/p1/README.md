# P1 角色动作样片

这组资源把人物、动物、Dino 和轮椅角色的动作保存为可编辑的 Godot `AnimationLibrary`，由同一暂停时钟驱动。当前造型仍是 `Skeleton3D + BoneAttachment3D` 的刚性原型，`skinned_meshes = 0`；本交付不等于最终蒙皮、教材全部角色完成或 Mixamo/Tripo 资源验收。

## 源文件与资源

- [p1_action_source.gd](../p1_action_source.gd)：骨骼局部角度关键帧、动作时长、接触时刻、家族限制和普通/减少动态变体。
- [build_p1_animation_libraries.gd](../build_p1_animation_libraries.gd)：从上述源文件生成当前目录的 8 个 `.tres` 与 [action_manifest.json](action_manifest.json)。
- [textbook_actor.gd](../../scripts/textbook_actor.gd)：角色骨架、手部挂点、手动 AnimationPlayer、物理移动与事件接口。
- [living_world.gd](../../scripts/living_world.gd)：角色注册、暂停状态、动态交互位置及环境展示。
- [test_p1_actor_animation.gd](../../tests/test_p1_actor_animation.gd)：独立原生组件验证。
- [capture_p1_actor_actions.gd](../capture_p1_actor_actions.gd)：现有校园 GLB 中的固定游戏角度动作取证；水果和篮子是接触检查道具。

`humanoid`、`animal`、`dino` 各有 14 段普通动作及相应减少动态版本；`wheelchair` 各有 11 段。轮椅库没有 `walk`、`carry_walk`、`pick_item`，运行时也拒绝站立、步行与路径移动。Jim 的座椅、轮子、腿和脚踏支撑在上肢动作中保留。

| 正式动作 ID | 兼容短名 | 时长 / 循环 | 接触时刻 |
| --- | --- | --- | --- |
| `idle` | `idle` | 3.2 秒循环 | 无 |
| `walk` | `walk` | 1.12 秒循环 | 无 |
| `carry_item` | `carry` | 2.0 秒循环 | 无 |
| `carry_walk` | `carry_walk` | 1.12 秒循环 | 无 |
| `greet_wave` | `wave` / `greet` | 2.2 秒 | 无 |
| `reach_target` | `reach` | 2.2 秒 | 1.1 秒 |
| `pick_item` | `pick` | 2.2 秒 | 1.1 秒 |
| `place_item` | `place` | 2.2 秒 | 1.1 秒 |
| `give_item` | `give` | 2.2 秒 | 1.1 秒 |
| `take_item` | `take` | 2.2 秒 | 1.1 秒 |
| `pose_photo` | `photo` | 2.4 秒 | 无 |
| `point_target` | `point` | 2.0 秒 | 无 |
| `talk_gesture` | `talk` | 2.2 秒 | 无 |
| `listen_nod` | `nod` | 1.8 秒 | 无 |

## 调用与接触契约

```gdscript
actor.face(target_position, true)
var local_contact: Transform3D = actor.get_action_contact_transform("pick")
var world_contact: Transform3D = actor.global_transform * local_contact
actor.play_action("pick", "scene-instance:apple-01:pick")
```

`get_action_contact_transform` 返回角色局部坐标，查询不会跳播或改变当前动作。`get_hand_socket_transform` 返回当前世界坐标。实际 `hand_socket` / `left_hand_socket` 节点会在接触信号之前同步骨骼，挂载道具可直接使用节点；不要再补一帧猜测偏移。

`action_started` 与 `action_phase_changed` 带本次 `invocation_id`。带接触的动作依次经过 `anticipation`、`reach`、`contact`、`recover`；完成后发出 `action_finished`，再切回持物或待机。流程应等待完整的 `action_finished`，不能在 1.1 秒转移道具后立即结束 2.2 秒的表演。

- `action_contact(character_id, action_id, event_key, invocation_id, socket_world)`：每次有效视觉播放发出一次，用于对齐与转移展示道具。
- `semantic_event(character_id, action_id, event_key)`：同一个角色实例内，相同非空 `action_id + event_key` 只发出一次；重播仍有视觉接触。空 key 保留旧调用行为，每次播放都发出。
- 动作层不修改任务奖励、学习记录或持久化物品所有权。存档幂等仍由剧情/任务层负责，不能用进程内去重替代存档判断。
- `get_action_spec`、`get_action_duration`、`get_action_phase` 供流程查询；短名和正式 ID 均可。
- `pick` / `take` 完成后保持持物姿势，`place` / `give` 完成后恢复待机；移动中自动使用 `carry_walk`，道具由调用方维护。

拾取/放篮使用现有 A 地标接触尺寸。当前兔兔局部接触点为拾取 `(0.3360, 1.0931, 0.6686)`、放置 `(0.3299, 0.6258, 0.7897)` 米；放置前倾同时反向转腿，保持脚落地。不同目标高度应另建明确动作或定位方案，不应任意缩放整个人物。

## 暂停、减少动态与移除

普通环境与非参与者跟随世界时钟；当前剧情参与者可在对话中继续表演。暂停、后台及 SceneTree 暂停会冻结动作与挂点。减少动态使用同一动作时长和接触时刻，静止待机并缩小重复摆动，切换设置时保留动作进度。

`living.remove_actor(id)` 会同步移除已注册交互数组中的动态角色条目，再释放节点，原有 NPC 条目保留。`refresh_interactions` 在转换节点类型前检查引用有效性，能清除已释放或已经替换的旧实例；切换房间前使用 `prepare_room_change` 清理旧世界展示引用。

性能比较可调用 `living.set_environment_effects_enabled(false)`，只关闭风、水和雨的附加展示，保留环境基准照明、天气/时钟、演员和碰撞。恢复为 `true` 后按当前时钟恢复展示。

## 重建与验证

在仓库根目录 PowerShell 执行：

```powershell
& 'F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path 'F:/LoveStudy/game' --script res://actors/build_p1_animation_libraries.gd
& 'F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path 'F:/LoveStudy/game' --script res://tests/test_p1_actor_animation.gd -- --test-harness --report=F:/LoveStudy/game/actors/p1/animation-test-report.json
```

当前 [组件报告](animation-test-report.json) 为 **623 项检查通过、68 次普通/减少动态动作测量、0 项失败**。覆盖 Peter、Lingling、兔兔、Dino、Jim，包含真实手部节点接触、时长、结束信号、重播幂等、暂停、减少动态、脚底支撑、轮椅限制、Dino 翼尾、真实 CharacterBody 避障/水边，以及角色释放后的交互引用。

动作测量的最大接触位置误差为约 `0.000002` 米，站姿脚底最低约 `0.005` 米，时长误差低于一帧；这些是程序化原型的几何与时序测量，不是最终蒙皮质量或帧率结论。GPU 性能和完整剧情由独立集成报告覆盖。

原生动作图像与 GIF 位于 [动作验证目录](../../../assets/characters/p1/validation/)。先阅读该目录的视觉核查说明再使用截图；单张图不能证明接触顺序或动态流畅性。
