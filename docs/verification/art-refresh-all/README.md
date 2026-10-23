# v0.6.2-dev · 全套二维学习素材本地验收

2026-10-22，26 张字母学习插图与 10 张故事道具完成接入。B/O/K 复用已确认的 v1 PNG，新增 23 张字母图和 10 张道具；全部实际加载为透明 PNG。当前直接运行本地 Godot 工程，本轮没有导出 EXE 或创建 ZIP。

双击根目录[启动字母岛.cmd](../../../启动字母岛.cmd)，从「旅行册 → 教材里的词故事」打开 `book`、`hello`、`nose` 或 `football`，选择「我们一起看」并播放。全套字母图同时用于补接候选、字母体验页与发现卡。

![Godot 实际纹理 A–Z 总览](../../screenshots/art-refresh-all/1440x900/00-alphabet-gallery.png)

## 最终检查

| 检查 | 结果 | 证据 |
|---|---|---|
| PNG 原图与导入 | 36 项；33 新图＋3 复用；原图、副本摘要和实际 RGBA 一致 | [原图检查](preparation-report.json)、[完整素材清单](../../../assets/art/storybook_v2/manifest.json) |
| 无界面专项检查 | 1,121 项通过 | [报告](headless-1440x900-report.json)、[日志](headless-run.log) |
| 1440×900 原生窗口 | 1,198 项通过；76 张截图；45 次 UI 输入 | [报告](native-1440x900-report.json)、[日志](native-1440x900-run.log) |
| 960×640 原生窗口 | 1,197 项通过；75 张截图；45 次 UI 输入 | [报告](native-960x640-report.json)、[日志](native-960x640-run.log) |
| 最终产物复核 | 151 张 PNG 解码、尺寸与 SHA 一致；最终源码修改时间早于三份报告 | [审计记录](final-artifact-audit.json) |
| 原有三维资产与地图 | 94 个原件摘要未变 | [保护记录](protected-originals.json) |

960×640 窗口延续工程原有的 16:10 逻辑视口，截图内容为 960×600。两轮原生窗口错误输出均为空。所有测试在独立存档路径运行，生产存档及备份的 SHA 均未改变。

[逐页视觉复核](focused-visual.md)另外记录门窗透明合成、猫头鹰翅膀接点、书页前后姿态及小窗口检查。

## 验证范围

- 逐项比较 26 张字母图、10 张道具的源文件和游戏加载后的像素；验证 1/2/3 倍字母图缩放、缓存及缺图 SVG 回退。道具缺失时回退原绘制，书的三层缺任一张时整书回退。
- 六个真实词的 52 个字母位置覆盖 A–Z 和 13 类通用动作；每类执行真实播放、暂停输入并采样 Tween。
- `hello/nose/book/football/dog/wood` 共 28 个源动作逐项定位姿态并实际绘制，10 张道具均有实际绘制记录。书封、翻页纸比较前后四边形，确认书页跨过书脊；这些重点词记录是离散姿态采样，不是全程录像。
- 检查 H0/H1 隐藏图片、H3 不加载未揭示答案的图片及道具、H4 补接输入、26 张共享字母体验图，以及旧会话的实际磁盘保存与恢复。
- 教材目录与字母体验数据的文件摘要、学习版本和字母编码版本保持不变。看故事不会被当作独立掌握。

## 实际画面与修正

[翻书](../../screenshots/art-refresh-all/1440x900/props-book-position3.png)、[书页翻转前](../../screenshots/art-refresh-all/1440x900/book-position3-phase20.png)、[书页翻转后](../../screenshots/art-refresh-all/1440x900/book-position3-phase80.png)、[窗前问候](../../screenshots/art-refresh-all/1440x900/props-hello-position2.png)、[球门](../../screenshots/art-refresh-all/1440x900/props-football-position8.png)、[小窗口展翅](../../screenshots/art-refresh-all/960x640/props-hello-position5.png)、[小窗口翻书](../../screenshots/art-refresh-all/960x640/props-book-position3.png)均来自实际 Godot 窗口。

书与阅读桌共同上移 12 个舞台单位，保留接触关系并避开字母标签；球门原程序网格只在 PNG 缺失时绘制。首次接入的裁切数据类型错误已修复，早期失败记录保留为 `initial-failed-*`；上表是这些修正后的最终结果。

完整原始 PNG、提示词和参考图路径见[素材说明](../../../assets/art/storybook_v2/README.md)。最终报告中的清单摘要对应验收时的候选清单；验收后仅更新清单状态和验证链接，图像摘要不变。

本轮为素材与受影响交互的专项验证，没有重跑全部地图、完整性能测试或 1,314 条故事的逐条播放，也没有制作新成品包。三维角色、美术骨骼及完整课程主线的后续工作沿用原计划。
