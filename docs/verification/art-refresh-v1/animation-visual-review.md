# B / O / K 图片更新：四词动画原生复核

2026-10-22，`storybook-v1` 的小船、猫头鹰、风筝接入后，复用既有真实 Tween 验证流程检查 `hello`、`nose`、`book`、`football`。**最终两尺寸均通过，每个尺寸 3,222 项检查、63 个实际播放采样、64 张原生 PNG；错误日志为空，生产存档和备份未变。** 两份最终报告均对应修正鼻喙锚点后的同一份舞台代码。

| 实际窗口 | 原生内容图 | 最终报告与日志 |
| --- | --- | --- |
| 1440×900 | 1440×900 | [报告](native-1440x900/report.json) / [日志](native-1440x900/run.log) / [错误日志](native-1440x900/errors.log) |
| 960×640 | 960×600，项目原有 16:10 留边 | [报告](native-960x640/report.json) / [日志](native-960x640/run.log) / [错误日志](native-960x640/errors.log) |

每个尺寸覆盖四词共 21 个专属动作，每动作取真实播放进度约 0.08、0.50、0.94 的三张图，另有一张减少动态模式的 book 关键画面。未修改动作顺序、提示等级、曝光记录、暂停/恢复或存档时序。[文件复核](animation-artifact-audit.json)确认 128 张 PNG 全部可解码、尺寸符合对应窗口，SHA-256 与报告一致；当前舞台和内容代码哈希也与两份报告一致。

## 发现并修正的唯一绘制失配

新猫头鹰的喙在脸中部，旧 SVG 的长鼻根坐标落在新图右翅旁。首轮中间采集确认该问题后，仅为实际加载成功、带有新 O 图片路径 metadata 的纹理调整鼻根，在 112×112 舞台绘制坐标中使用 `(2,-8)`、`(3,-1)`，并应用演员已有的缩放和旋转。星星轨迹、接续进度及动作时间保持原值；SVG 回退继续使用原鼻根坐标。

修正后的 [默认窗口中段](../../screenshots/art-refresh-v1/native-1440x900/nose-frame1-position2-1.png)、[默认窗口后段](../../screenshots/art-refresh-v1/native-1440x900/nose-frame1-position2-2.png)和[小窗口中段](../../screenshots/art-refresh-v1/native-960x640/nose-frame1-position2-1.png)中，长鼻从喙部连出，没有遮住双眼。修前中间采集不计入上表最终结果。

## 画面结论

| 样例 | 核查结果与代表帧 |
| --- | --- |
| hello | 新 O 的闭翼主体与既有挥翼示意线兼容，招呼气泡及眼睛清楚；没有新增横向裁切。[1440](../../screenshots/art-refresh-v1/native-1440x900/hello-frame2-position5-1.png) / [960](../../screenshots/art-refresh-v1/native-960x640/hello-frame2-position5-1.png) |
| nose | 猫头鹰从鸟巢移出、长鼻托起星星、喷嚏送入蛋壳的动作链保留；新鼻根已校正，未再调整其它轨迹。[960](../../screenshots/art-refresh-v1/native-960x640/nose-frame1-position2-1.png) |
| book | 双 O 保持两个独立位置，开封面和翻页仍可区分，书页没有覆盖脸部；B 船体、K 风筝及提书线可辨。[开封面](../../screenshots/art-refresh-v1/native-1440x900/book-frame1-position2-1.png) / [翻页](../../screenshots/art-refresh-v1/native-960x640/book-frame1-position3-1.png) / [风筝提书](../../screenshots/art-refresh-v1/native-960x640/book-frame1-position4-2.png) |
| football | 两只 O 的停球、传球及后续小船动作保留，球的前景绘制与新主体没有新增异常遮挡。[停球前段](../../screenshots/art-refresh-v1/native-960x640/football-frame1-position2-0.png) / [传球中段](../../screenshots/art-refresh-v1/native-1440x900/football-frame1-position3-1.png) |

在上述默认和小窗口原生画面中，三张新图的奶油、木色和灰绿色主体清楚，半透明轮廓没有可见的红黄色晕或矩形底色；猫头鹰眼睛、船帆和风筝尾部在小尺寸仍可辨。保留原有二维舞台的示意接触方式，没有把图片替换描述为新增骨骼动作或物理接触模拟。

## 复现与边界

独立 [采集脚本](capture_story_art.gd)保留在本目录，原有测试和 v0.6.0 证据未被覆盖。示例命令：

```powershell
& 'F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path 'F:/LoveStudy/game' --fixed-fps 60 --resolution 1440x900 --script 'F:/LoveStudy/docs/verification/art-refresh-v1/capture_story_art.gd' -- --test-harness --capture --art-window=1440x900
& 'F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path 'F:/LoveStudy/game' --fixed-fps 60 --resolution 960x640 --script 'F:/LoveStudy/docs/verification/art-refresh-v1/capture_story_art.gd' -- --test-harness --capture --art-window=960x640
```

固定模拟步长用于可重复的功能和画面验证，不用于测量性能；三相位截图不是连续视频。本次只复核这批三张贴图及四词复用场景，不推定其余 23 张图已完成更新、全部词故事已获得独立美术或儿童学习效果已经验证。
