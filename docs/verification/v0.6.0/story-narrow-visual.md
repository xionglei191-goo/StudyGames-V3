# P1 故事动画：960×640 原生补验

2026-10-22，在正式性能采样结束、其 Godot 进程退出后串行运行。**839 项检查通过，78 个实际 Tween 播放采样，90 张原生 PNG，53 次真实按钮点击；错误日志为空。** 生产存档与备份哈希未变，原有产品源码和验证测试未改。采样进程已退出，90 张图片的 SHA-256 均与报告一致。

- [结构化报告](story-narrow-native-report.json)
- [运行日志](story-narrow-native-run.log) / [错误日志](story-narrow-native-errors.log)
- [本轮独立验证脚本](test_p1_story_narrow.gd)
- [1440×900 特殊样例证据](story-specials-visual.md)

## 实际尺寸与按钮

每张截图均读取并核对真实尺寸：Windows 窗口与 Godot 根窗口为 **960×640**；项目采用 `canvas_items` 和 16:10 内容比例，原生纹理为 **960×600**；逻辑 UI 视口为 **1440×900**。PNG 只保存内容区，没有人为添加留边或将 1440×900 图片事后缩小。

53 次按钮操作都由引擎派发鼠标输入，操作前按实际滚动容器滚动到按钮，检查按钮完整落在视口及所有滚动祖先的裁剪区域内、未禁用、尺寸足以容纳文字。包括播放、暂停、继续播放、下一页、帮助级别、完整拼写和退出。所有检查通过。可滚动页面无需同时显示全部按钮；下方按钮滚动后可达。

## 目视核查

| 样例 | 实际复核 | 原生画面 |
| --- | --- | --- |
| book 双 O | 位置 2、3 分别是第一、第二只猫头鹰，独立完成打开封面和翻内页，重复实例编号仍可辨认；播放按钮和画面没有横向裁切 | [位置 2 开书](../../screenshots/v0.6.0/story-narrow/book-page1-position2-1.png)、[位置 3 翻页](../../screenshots/v0.6.0/story-narrow/book-page1-position3-1.png) |
| `I'm` 与 `café` | 撇号、大小写与 é 重音完整显示；H3 隐藏格保持问号，没有显示缺失字母、角色或原动作句 | [I'm](../../screenshots/v0.6.0/story-narrow/im-page1-position1-1.png)、[café](../../screenshots/v0.6.0/story-narrow/cafe-page1-position4-1.png)、[H3](../../screenshots/v0.6.0/story-narrow/cafe-h3.png) |
| 长词七页 | 长标题完整显示，页码、位置编号和下一页按钮可读；七页全部通过实际翻页并播放，最后一页为位置 25 | [第七页](../../screenshots/v0.6.0/story-narrow/long-page7-position25-1.png) |
| 暂停后重进 | 第 4 页、第 14 个字母动作在 phase `0.408882230520248` 暂停，退出并从磁盘重载后仍为同一 invocation、页码、位置、phase 和角色/道具姿态；保持暂停，点击继续播放后完成剩余页面 | [暂停](../../screenshots/v0.6.0/story-narrow/long-page4-paused.png)、[重进](../../screenshots/v0.6.0/story-narrow/long-page4-restored.png) |
| rain | 外围世界保持冻结，教学舞台的苹果滚动及词义卡移动可见，“雨；下雨”和动作说明持续可读 | [滚动前段](../../screenshots/v0.6.0/story-narrow/rain-page1-position2-0.png)、[滚动后段](../../screenshots/v0.6.0/story-narrow/rain-page1-position2-1.png) |

rain 的真实世界时钟前后均为 `1.25`，实际雨滴实例位置均为 `[-7.5, 4.25494956970215, -5.89805841445923]`；表演时钟从 `83.2333333333299` 推进到 `92.7666666666627`。UI、实际舞台动作及权威保存的 cue 一致。五个样例也实际回归了 H0/H1 无故事舞台、H3 仅构造已显示角色资源以及完整拼写之后切换帮助级别的保存路径。

## 复现与范围

运行脚本最初准备于 `.local`，本目录保存完全相同的副本便于复核。脚本只调整验证窗口和证据路径，并调用现有产品的主场景、词故事控制器、UI 和保存接口；没有修改产品布局、渲染比例、动画或状态系统。

```powershell
& 'F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path 'F:/LoveStudy/game' --fixed-fps 60 --resolution 960x640 --script 'F:/LoveStudy/docs/verification/v0.6.0/test_p1_story_narrow.gd' -- --test-harness --capture
```

引擎为 Godot 4.7.2，渲染器为 OpenGL Compatibility，设备为 NVIDIA RTX 4070。固定模拟步长用于可重复的功能与画面验证，不是 FPS 测量；PNG 帧序列不是连续录像。这组证据补齐当前默认窗口与窄窗口的故事功能/原生画面检查，不推定其他设备、全部词条、儿童可用性或学习效果通过。特殊词仍是来源动作分类驱动的通用舞台，book 为专属动作链。
