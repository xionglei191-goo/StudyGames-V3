# B / O / K 图片替换：独立回归与原生画面复核

2026-10-22，Godot 4.7.2，Windows，OpenGL Compatibility / NVIDIA RTX 4070。

本次使用实际 `MemoryStory`、`PrologueActivity`、故事动画组件、`State` 和事件保存层，验证三张 PNG 替换后的图片、动作及数据行为。运行场景是独立组件回归场景；四个完整故事的接触关系另由四词原生采集记录覆盖。

| 运行 | 检查 | 实际动画采样 | PNG | 结果 |
|---|---:|---:|---:|---|
| Headless | 161 | 12 | 0 | PASS，无引擎错误 |
| 原生窗口 1440×900 | 180 | 12 | 17 | PASS，stderr 0 字节 |
| 原生窗口 960×640 | 180 | 12 | 17 | PASS，stderr 0 字节 |

两次原生运行各完成 11 次实际 UI 输入；点击中心均位于可见窗口和滚动裁剪区域内。报告同时核对 `root.size` 和 `DisplayServer.window_get_size()`。960×640 窗口中的游戏内容保持 16:10，实际截图为 960×600；1440×900 窗口截图为 1440×900。34 张截图的 SHA-256 全部与报告一致。

## 图片与兼容性结论

- 三张源图均为 1254×1254 RGBA；运行时原生尺寸纹理与源 PNG 的全部 RGBA 字节一致。报告保留源文件、原始像素、透明像素规范化后的像素哈希。非零 alpha 的 RGB 及所有 alpha 字节使用严格比对，没有容差豁免。
- 原有 `160 × raster_scale` 尺寸契约在 1、2、3 倍缩放下保持一致；实际舞台中的四个位置使用新 PNG，其中两个 O 为独立实例。
- 先将 B 图片放入缓存，再仅在内存中把其配置路径指向不存在的文件，实际调用正确回退到原嵌入 SVG；恢复路径后重新取得 PNG。A 继续使用原 SVG。
- H3 的实际舞台只创建已展示的 1、3 号位置，未提示 K 时不加载 K。揭示第 2 格只增加该 O；明确揭示第 4 格后才加载 K。H0/H1 不创建故事舞台、不请求新字母图，也不记录不存在的视觉提示。
- H4 实际点击两次“猫头鹰”后，下一项 K 候选按钮使用新 PNG；B/O/K 序章 `TextureRect` 均使用新图并保持比例。
- 课程、序章文件和学习修订号保持原值。固定的旧版存档样例保留 `bok` 首次错误、`book` 后续正确、草稿、已揭示格，以及第 2 步的 0.42 动画相位，并以暂停状态恢复。实际事件保存层另完成一次磁盘保存、重新加载及同 invocation 的位置/相位恢复。
- 三次运行均使用 PID 专属验证存档；正式存档及 `.bak` 的前后 SHA-256 相同。

首次运行定位了两项问题，修复后才形成上述最终 PASS：Godot 默认 `fix_alpha_border=true` 会修改 alpha 为 1–19 的源 RGB，三图导入设置已关闭此处理，源文件没有改动；H4 候选数组的条件表达式在当前引擎中生成无类型数组，现改为先建立 `Array[String]`、偶数位置再反转，保留原候选顺序。

## 动作和画面

`book` 四个动作各采集早、中、晚三个实际 Tween 画面。第一个 O 打开封面；第二个 O 在自己的步骤中接近书页，前一个 O 保持独立位置。原生测试额外比较仅含书页的区域：翻页中段与末段像素哈希不同，避免只依赖动作名称或恒定的“已打开”状态判断翻页。

已人工查看两个尺寸的开书、翻页、H3 缺格、暂停恢复，以及 B/O/K 序章代表帧。图像比例正常，暖色背景上未观察到明显红黄色晕；窄窗口内主按钮和字母位置完整可见，更多卡片通过滚动查看。这里的人工视觉结论限于列出的画面与设备。

- [1440×900 翻页中段](../../screenshots/art-refresh-v1/1440x900/book-position3-1.png)
- [1440×900 翻页末段](../../screenshots/art-refresh-v1/1440x900/book-position3-2.png)
- [960×640 窗口：第一个 O 开书完成](../../screenshots/art-refresh-v1/960x640/book-position2-2.png)
- [960×640 窗口：第二个 O 翻页中段](../../screenshots/art-refresh-v1/960x640/book-position3-1.png)
- [960×640 窗口：H3 仅显示位置 1、3](../../screenshots/art-refresh-v1/960x640/book-h3-hidden-o-k.png)
- [960×640 窗口：小船序章](../../screenshots/art-refresh-v1/960x640/prologue-B.png)
- [1440×900 猫头鹰序章](../../screenshots/art-refresh-v1/1440x900/prologue-O.png)
- [960×640 窗口：风筝序章](../../screenshots/art-refresh-v1/960x640/prologue-K.png)

## 记录与复现

- [测试源码](../../../game/tests/test_art_refresh.gd)，SHA-256：`42c35335f0bbc726da3147c9e315c63d4d4c8b8ef2af111e4a23dac5036bd5c6`
- [Headless 报告](headless-1440x900-report.json) / [日志](headless-run.log)
- [1440×900 原生报告](native-1440x900-report.json) / [日志](native-1440x900-run.log) / [stderr](native-1440x900-errors.log)
- [960×640 原生报告](native-960x640-report.json) / [日志](native-960x640-run.log) / [stderr](native-960x640-errors.log)
- [源图、生成提示词与素材核对记录](../../../assets/art/storybook_v1/manifest.json)

从仓库根目录运行：

```powershell
& 'F:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --fixed-fps 60 --path game --script res://tests/test_art_refresh.gd -- --test-harness
& 'F:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe' --fixed-fps 60 --resolution 1440x900 --path game --script res://tests/test_art_refresh.gd -- --test-harness --capture --art-width=1440 --art-height=900
& 'F:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe' --fixed-fps 60 --resolution 960x640 --path game --script res://tests/test_art_refresh.gd -- --test-harness --capture --art-width=960 --art-height=640
```

三条命令应顺序运行。原生采集使用固定模拟步长，结果属于功能与画面验证；PNG 为离散帧，不能作为连续视频、性能基准、儿童学习效果、所有设备兼容性或完整发布包通过的证明。
