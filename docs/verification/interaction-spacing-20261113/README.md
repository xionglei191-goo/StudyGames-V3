# 交互点位间距与防误选修复 · 2026-11-13

已接入当前本地工程。从项目根目录 `启动字母岛.cmd` 重新启动即可使用；此前已经打开的游戏进程仍需正常退出再启动。

## 调整内容

- 43 个场景共检查 345 个交互目标。将 29 处与固定点位过近的居民站位移至旁边可行走的空地，同时检查碰撞、地面、水面与俯视镜头下的遮挡；固定记忆位置和 Blender 原始资产保持原样。
- 按人物、门口、地面物件分别设置点击区域。多个区域相交时，比较它们在画面中的目标中心，避免高大的邻居点击框抢走地面点位。
- 鼠标悬停显示目标名称；按 E 或点击底部互动按钮，只操作底部明确显示的附近目标。开始手动行走、关闭面板和切换场景会清除旧悬停状态。
- 附近有多个目标时，可用 Q 或“换一个”按钮轮换。果树、床、客厅装饰与欢迎桌等一处兼有两种操作的位置，会列出明确选项。
- 同时调整家人、同学的安全出场间距，避免重新生成角色时挤回固定交互点。

## 验证结果

| 检查 | 结果 | 记录 |
| --- | --- | --- |
| 43 个实际场景的自动检查 | 1,897 项通过，进程退出码 0 | [完整报告](headless/report.json) |
| 原生渲染窗口，5 个重点场景及真实输入事件 | 251 项通过，进程退出码 0 | [原生报告](native/report.json) |
| 六个房间往返、地图入口、门口碰撞和旧入口兼容 | 168 项通过；26 条实际行走路线、19 次场景切换；退出码 0 | [房间通行报告](home-compat/runtime-report.json) |

场景检查包含 1,035 次目标中心及左右偏移点击、345 个导航可达性检查、210 个记忆锚点检查，以及人物站位与出场安全检查。输入检查通过 Godot 输入事件执行鼠标点击、自动走近后打开、E 键、防止旧悬停误选、Q 键和“换一个”按钮，并实际点击共用位置的选项。原生截图覆盖 1440×900 与 960×640 窗口。

全部交互测试使用 `--test-harness` 的独立验证存档；正式旧存档及备份的 SHA-256 前后相同。本轮没有重建独立 EXE/PCK 或网页导出包；根目录启动入口直接运行当前工程。

未执行全项目测试。附加运行的 `test_living_world.gd` 有两项旧光照颜色断言失败，当前组件与提交 `b697772` 中的 `living_world.gd` 对照均为相同的 2/91 项失败：`story dawn overrides guide and applies while dialogue paused`、`clearing story phase restores guided daylight`。相关默认角色出场检查均通过。详见 [当前输出](living-compat/stdout.log) 与 [原组件对照输出](living-baseline/stdout.log)。这些结果没有计入上表的通过项。

无界面交互测试结束时仍会输出一条 Godot dummy renderer 的 `Parameter "material" is null`，进程退出码为 0；原生渲染检查没有 stderr 输出。详见 [无界面日志](headless/stderr.log)、[原生日志](native/stderr.log) 和 [进程退出码与源码哈希](process-results.json)。

## 画面

果园中人物与门前篮子分开：

![果园实际游戏画面](native/landmark_A.png)

同一物件的操作选择，960×640 窗口：

![同一物件的操作选择](native/shared-actions-960.png)

## 复测入口

```powershell
& 'F:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe' --headless --path 'F:\LoveStudy\game' --fixed-fps 60 --script res://tests/test_interaction_access.gd -- --test-harness --access-output=F:/LoveStudy/.local/interaction-spacing-retest
```

去掉 `--headless`，并在 `--` 后增加 `--access-capture --access-rooms=landmark_A,landmark_C,landmark_I,home_dining,home` 可复测原生画面。测试未带 `--test-harness` 时会拒绝运行，避免进入正常存档流程。

房间通行复测使用 `test_home_living_hub.gd` 的副本，仅替换报告输出目录，测试断言和路线未改动。生活世界对照使用同一测试，仅替换 `Living` 组件为上述提交的原文件。
