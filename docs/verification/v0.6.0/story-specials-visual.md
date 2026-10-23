# P1 特殊样例：原生画面与恢复核查

2026-10-22，使用当前产品 `main.tscn`、真实词故事控制器、引擎派发的鼠标输入和隔离验证存档完成。没有替换教学组件或状态保存接口。原生输出为 1440×900，Godot 4.7.2 / OpenGL Compatibility / NVIDIA RTX 4070。

| 验证 | 结果 | 证据 |
| --- | --- | --- |
| 无界面完整流程 | PASS，452 项检查、70 个实际 Tween 采样 | [结构化报告](story-specials-headless-report.json)、[运行日志](story-specials-headless-run.log) |
| 原生渲染完整流程 | PASS，533 项检查、70 个实际 Tween 采样、80 张 PNG | [结构化报告](story-specials-native-report.json)、[运行日志](story-specials-native-run.log)、[空错误日志](story-specials-native-errors.log) |
| 生产数据保护 | 原生产存档与 `.bak` 的 SHA-256 均未变化 | 两份结构化报告的 `production_save_and_backup_unchanged` |

## 实际检查的样例

| 样例 | 已验证行为 | 代表画面 |
| --- | --- | --- |
| `I'm` | 大写 I、小写 m 与中间撇号保留；只有两个字母角色，撇号作为原位符号保存；两步真实播放，UI 动作文字与权威 cue 一致 | [字母与撇号](../../screenshots/v0.6.0/story-specials/im-page1-position1-1.png) |
| `café` | é 显示重音并保持 E 的形象编码；四步真实播放；H3 仅显示位置 1、3，隐藏位置的资源、原始动作句与 cue 不出现 | [重音与第四步](../../screenshots/v0.6.0/story-specials/cafe-page1-position4-1.png)、[H3 缺口](../../screenshots/v0.6.0/story-specials/cafe-h3.png) |
| `International Children's Day` | 通过“下一页”逐页播放全部七页、25 个原始字母位置，每页最多四个角色；两个空格、撇号和专名大小写保留 | [第七页位置 25](../../screenshots/v0.6.0/story-specials/long-page7-position25-1.png) |
| 长词中断恢复 | 第 4 页、第 14 个字母动作进行到 phase `0.408882230520248` 时点暂停，再点“以后再练”；从磁盘重载存档并打开同一 invocation，仍在原页、原动作、原 phase，角色与道具姿态一致，保持暂停；实际点“继续播放”后完成后续页面 | [暂停](../../screenshots/v0.6.0/story-specials/long-page4-paused.png)、[磁盘重载后](../../screenshots/v0.6.0/story-specials/long-page4-restored.png) |
| `rain` | 产品主场景进入词故事后冻结世界时钟与 3D 雨滴位置，教学舞台四步动画继续；“雨；下雨”和对应动作文字持续可见，实际播放 cue 与当前字母位置一致 | [苹果滚动前段](../../screenshots/v0.6.0/story-specials/rain-page1-position2-0.png)、[苹果滚动后段](../../screenshots/v0.6.0/story-specials/rain-page1-position2-1.png) |

雨天原生证据中，世界时间始终为 `1.25`，被探测的真实雨滴实例位置始终为 `[-7.5, 4.25494956970215, -5.89805841445923]`；表演时钟从 `83.2333333333299` 推进到 `92.7666666666627`。该读取来自实际 LivingWorld 和 MultiMesh 实例，不能用无界面渲染器返回的空变换替代。两张代表画面中苹果姿态和词义卡位置发生变化，外围世界保持冻结。

四个样例均实际点击 H3、H0、H1，并核对 UI、当前角色资源与保存的 cue：H0/H1 没有故事舞台及可见拼写字母，H3 不通过相邻动作文字泄露隐藏格。长词第七页只有一个位置时，H3 保持空格且不播放未揭示角色。

本轮还回归了“看完整字母串 → 切换帮助级别 → 退出 → 打开下一词”的实际 UI 路径。曾暴露的 `show_sequence=true` 与较低帮助级别瞬态冲突已修复；当前完整流程可以保存和退出，先前 H5 暴露历史仍然保留。

## 证据边界

这些特殊词使用来源动作分类驱动的通用教学舞台，不等同于 hello、nose、book、football 的专属动作链。上述画面证明特殊词形、分镜顺序、恢复位置、世界与教学动画时钟分离、可见线索记录和当前 UI 可读性；不宣称每句故事均已有专属场景资产，也不证明儿童已经理解或记住目标词。

80 张 PNG 包含每个字母动作的两次实际播放采样，以及帮助模式和恢复画面。它们是帧序列证据，不是连续视频或性能采样。`--fixed-fps 60` 用于可重复推进测试时间，不能据此声称游戏达到 60 FPS。本轮只覆盖 1440×900 的这组故事窗口；其他尺寸、其他设备及其余词条不能由这四组样例推定通过。

## 复跑

在仓库根目录运行：

```powershell
& 'F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --fixed-fps 60 --path game --script res://tests/test_p1_story_specials.gd -- --test-harness
```

原生采样使用相同脚本，去掉 `--headless`，在 `--test-harness` 后添加 `--capture`。需要与正式性能采样串行执行。报告写入本目录，图片写入 `docs/screenshots/v0.6.0/story-specials/`；测试程序要求 `--test-harness` 并检查生产主备存档哈希。
