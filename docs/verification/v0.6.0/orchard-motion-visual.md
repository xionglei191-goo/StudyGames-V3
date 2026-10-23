# 真实果园连续示范核查

2026-10-22，使用实际 `main.tscn`、A 地标和 `orchard_pick.gd`，通过合法 H01—H04 前置后调用真实 `start_demonstration()`。没有替换背景、跳到假动作、手动推进骨骼或修改苹果运动。角色、路径、接触挂点、状态保存、发现卡和相机均由游戏本身执行。

**结论：两种窗口尺寸均跑通完整示范，89 项检查通过，原生错误日志为空。** 原生帧、相位拼图和初末界面已目视检查；枝头苹果、兔兔动作、搬运中的苹果和真实篮子可见，发现卡在放置动作恢复后出现。

## 查看录像

- [1440×900 窗口示范 GIF](../../screenshots/v0.6.0/orchard-motion/1440x900/orchard-demonstration.gif)
- [960×640 窗口示范 GIF](../../screenshots/v0.6.0/orchard-motion/960x640/orchard-demonstration.gif)
- [1440×900 初始界面](../../screenshots/v0.6.0/orchard-motion/1440x900/01-initial-ui.png) / [最终界面](../../screenshots/v0.6.0/orchard-motion/1440x900/02-final-ui.png)
- [960×640 初始界面](../../screenshots/v0.6.0/orchard-motion/960x640/01-initial-ui.png) / [最终界面](../../screenshots/v0.6.0/orchard-motion/960x640/02-final-ui.png)
- [原生检查与逐帧报告](orchard-motion.json) / [媒体汇总信息](../../screenshots/v0.6.0/orchard-motion/media-report.json)

每个尺寸记录 **91 帧、9.033 秒**，连续截图平均间隔 **0.100 秒**。GIF 首尾各停留 1 秒便于阅读；中间时长采用实际记录的帧间时间，不做插帧或补画。大尺寸 GIF 缩至 960×600，小尺寸内容保持 960×600；原始大尺寸 PNG 保留 1440×900。

项目固定 16:10 内容比例。小窗口实际为 **960×640**，游戏内容渲染为 **960×600**，逻辑 UI 坐标为 **1440×900**；原生纹理截图只包含内容区，未人为补黑边。这个区别同时保存在报告的窗口、视口、图片尺寸字段中。

## 相位与接触

两个尺寸的真实相位顺序与时间一致，以下时间相对示范开始：

| 相位 | 时间 | 可见行为 |
| --- | ---: | --- |
| `ready` | 0.000 秒 | 苹果在低枝，初始提示和四个按钮可见 |
| `walking_pick` | 0.017 秒 | 兔兔沿实际导航路线走向苹果 |
| `picking` | 1.300 秒 | 伸手摘取 |
| `lifting` | 2.383 秒 | 接触后苹果挂到手部，继续完成拿稳动作 |
| `carrying` | 3.483 秒 | 站稳持物，留出短暂停顿 |
| `walking_place` | 4.133 秒 | 持物走向实际 `A_Entrance_Basket` |
| `placing` | 6.050 秒 | 弯身放置 |
| `deposited` | 7.133 秒 | 已保存后松手，苹果落入篮子；动作恢复结束后显示发现卡 |

拾取接触时手部挂点到苹果目标中心距离为 **0.139514 米**；放置接触时为 **0.136881 米**，均低于游戏的 0.22 米接触允许值。报告另存每次动作的 `invocation_id`、实际动画时间、挂点/目标世界坐标和苹果父节点变化。最后苹果与真实篮内静置点距离小于 0.01 米。

![真实果园完整相位](../../screenshots/v0.6.0/orchard-motion/1440x900/phase-contact-sheet.jpg)

## 界面与保存检查

两个尺寸均检查初始四个按钮、结束页八个按钮的可见视口边界、父容器边界、最小文字尺寸和两两重叠，全部通过。目视检查低分辨率下的“摘苹果 / 请兔兔示范 / 暂停 / 下次再来”以及“听一听 A / 听一听 Apple / 收下这次发现 / 再玩一次”，均完整显示。

本次使用 `user://validation-<进程号>.json` 隔离保存；生产存档及其备份 SHA256 前后相同。保存的完成方式为 `demonstration_viewed`，金币仍为 30，未写课程独立掌握记录。发现卡保留在画面中供核查，本次录制不点击“收下这次发现”，该按钮的实际点击流程由果园集成测试另行覆盖。

## 复现与范围

```powershell
& 'F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path 'F:/LoveStudy/game' --fixed-fps 60 --script res://tests/capture_p1_orchard_demo.gd -- --test-harness
& 'C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -X utf8 'F:/LoveStudy/docs/screenshots/v0.6.0/orchard-motion/build_media.py'
```

固定 60 帧模拟步长仅用于可复现录像，截图每 6 个渲染帧读回一次；本记录不提供性能结论。原生录制与 GIF 量化均已结束，性能采样应单独进行。本次覆盖每个尺寸的首次完整示范，退出、暂停、重玩和失败保存的交互分支以 [果园集成报告](orchard-integration.json) 为准。
