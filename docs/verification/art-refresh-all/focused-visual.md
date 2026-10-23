# 全部二维学习素材：聚焦回归与原生画面复核

2026-10-22，本机开发验证完成。最终代码对应的三次验证均通过：headless **1121** 项，1440×900 原生 **1198** 项，960×640 原生 **1197** 项。两次原生运行共保存 **151 张 PNG**，文件 SHA 全部与运行报告一致；两份原生错误日志均为 0 字节，测试进程已退出。本轮没有导出 EXE、PCK 或 ZIP。

| 运行 | 结果 | 检查数 | 原生截图 | 运行报告 |
|---|---|---:|---:|---|
| Headless | PASS | 1121 | 0 | [报告](headless-1440x900-report.json) / [日志](headless-run.log) |
| 1440×900 | PASS | 1198 | 76 | [报告](native-1440x900-report.json) / [日志](native-1440x900-run.log) |
| 960×640 | PASS | 1197 | 75 | [报告](native-960x640-report.json) / [日志](native-960x640-run.log) |

[产物核对记录](focused-artifact-audit.json)保存了截图 SHA 核对、实际窗口与截图尺寸、最终测试及运行时代码 SHA。960×640 为真实窗口尺寸；项目的 16:10 内容视口输出 960×600 图像，逻辑视口仍为 1440×900，没有给截图添加边框或重新缩放。

## 资源与实际交互覆盖

- **36 个资源**：26 个字母 PNG 与 10 个故事道具。独立解码保留的原图，核对原图、运行时副本、manifest SHA，并逐字节比较运行时实际 RGBA。B/O/K 继续复用已接受的 v1；其他字母使用 v2。字母的 1×/2×/3×结果与独立 PNG 缩放一致；道具按各自 manifest 宽高验证，允许横向和纵向画布。
- **缺图分支**：逐个字母先建立 PNG 缓存，再把配置临时指向不存在的路径；实际结果回退到对应原 SVG。恢复路径后重新得到 PNG。书本注入缺失封面缓存时，整本书回退旧几何，恢复缓存后重新使用 PNG；没有修改源文件。
- **6 个真实通用故事**：Tian'anmen Square、amazing、job、expensive、difficulty、homework，共 52 个源字母位置，覆盖全部 A–Z 与 13 种通用动作。每种通用动作通过实际播放/暂停按钮驱动 Tween，确认相位前进。
- **6 个道具故事**：hello、nose、book、football、dog、wood，共 28 个源动作采样。10 个道具均进入真实 draw 调用；检查其源像素、UV、实际四边形和可见滚动区域。另采样 nose 各动作早晚相位，以及 book 两个 O 的封面/内页几何变化；翻页四边形确实由书脊右侧跨到左侧。
- **提示与共享图片**：H3 冷缓存只请求允许显示的 T/A，点第 2 格后只增加 I；未揭示的 N 与道具均未加载。H0/H1 不创建字母舞台或虚构字母 cue。H4 实际候选按钮使用新 PNG，真实点击推进一个位置。序章 26 个实际 TextureRect 与同一 PNG 来源一致并保持比例。
- **会话和存档**：固定的旧学习版本会话保留首次/后续作答、草稿、揭示格与动画位置；真实 State/EventSink 写盘再读盘后恢复同一会话及相位，并保持暂停。每次运行有 45 次可达 UI 输入。课程与序章文件 SHA、content/codebook revision，以及正式存档和备份 SHA 均未改变。测试首次可变调用前已切到独立 PID 存档。

## 画面复核

实际查看了字母总览、hello 门窗和翅膀、nose 顶起星星的早晚画面、book 打开封面与翻页、football 球门、dog 鼓槌、H3、恢复暂停页及序章代表图片。大窗口字母总览完整，暖色背景下没有发现明显彩色边缘或透明背景色块。小窗口字号较小但仍可辨认，按钮没有横向截断，底部卡片按现有滚动设计显示。

| 复核点 | 原生截图 |
|---|---|
| A–Z 总览 | [1440×900 字母总览](../../screenshots/art-refresh-all/1440x900/00-alphabet-gallery.png) |
| 门背景、翅膀连接肩侧 | [hello 第 5 位，小窗口](../../screenshots/art-refresh-all/960x640/props-hello-position5.png) |
| 窗框前后遮挡 | [hello 第 2 位，小窗口](../../screenshots/art-refresh-all/960x640/props-hello-position2.png) |
| 书桌接触、标签无遮挡 | [book 打开封面](../../screenshots/art-refresh-all/1440x900/props-book-position2.png) |
| 内页由右侧翻到左侧 | [20%](../../screenshots/art-refresh-all/960x640/book-position3-phase20.png) / [80%](../../screenshots/art-refresh-all/960x640/book-position3-phase80.png) |
| 足球门无旧网格叠加 | [football 第 8 位](../../screenshots/art-refresh-all/960x640/props-football-position8.png) |
| 未揭示字母不暴露 | [H3 小窗口](../../screenshots/art-refresh-all/960x640/h3-hidden-new-letters.png) |
| 共享序章图片比例 | [Z 斑马](../../screenshots/art-refresh-all/960x640/prologue-Z.png) |

首次运行发现 UV 表使用 Rect2 而读取代码要求 Array，导致道具绘制错误；修复后通过。原生复核又发现桌腿接近字母标签，以及新球门前仍绘制旧网格。最终运行时将书及桌共同上移 12 个舞台单位，保持接触关系，旧网格仅在 PNG 缺失时绘制。测试新增了实际桌子 quad 底边必须小于 215 的检查；最终两尺寸截图中标签无遮挡，书仍接触桌面。

首次错误的 [报告](initial-failed-report.json) 和 [日志](initial-failed-run.log)保留在本轮目录；布局修正前的成功报告和受影响截图保留在 `.local/validation/art-refresh-all/pre-layout-fix`，不覆盖此前 v1 验证历史。

## 复现与结论边界

测试入口为 [test_learning_art_all.gd](../../../game/tests/test_learning_art_all.gd)。使用 Godot 4.7.2，本机 OpenGL Compatibility / RTX 4070。Headless 参数：`--headless --fixed-fps 60 --path game --script res://tests/test_learning_art_all.gd -- --test-harness`。原生运行移除 `--headless`，添加 `--resolution 1440x900` 或 `960x640`，用户参数增加 `--capture --art-width=<宽> --art-height=<高>`。

这些结果证明本次资源、提示边界、源动作抽样、原生布局及旧会话恢复在测试环境中通过。13 种通用动作经过实际 Tween；道具故事使用离散相位采样和实际绘制数据，不作为连续视频或全部课程动作的逐帧验收。本轮没有做性能基准、学习效果评估或所有设备验证。
