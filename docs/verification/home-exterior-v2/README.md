# 住宅外观与小院 v2 · 验证记录

按用户确认的“完整住宅外观＋院落，进门后再选房间”实现。二级 `home_estate` 从剖面格子布局改为完整三体量住宅：青绿坡屋顶、屋谷接合、凹入门窗、石基与木门廊；庭院包含石径、低墙、开敞院门、花境、信箱、日程板、长椅和照料物件。

[新旧对比与游戏截图](../../home-exterior-gallery.html) · [新版 Blender 预览](../../../assets/blender/interiors/home_estate/preview_v02.png) · [源文件](../../../assets/blender/interiors/home_estate/home_estate_v02.blend)

## 操作

主岛家门 → 小院 → 正门 → 入户导览 → 七个三级房间。地图可以引导角色走到正门；门前按 E 或点击交互提示，选择客厅、卧室、厨房、餐厅、浴室、书房或家务阳台。三级房间出口返回住宅正门，小院院门返回字母岛。

小院保留五个生活位置。第三处随身篮移至门廊旁，其他家庭引用和生活任务保持既有内容。旧七个 `SG_DOOR_*` 标记仅用于资产兼容，不绑定院落中的入口；唯一有效正门是 `SG_HOUSE_ENTRY` / `house_entry`。进入房间的动作要求角色实际到达门前。

## 受影响范围验证

| 范围 | 结果 | 证据 |
|---|---|---|
| 新入口、七房间、五点与家务流程 | 598项通过；56段实际行走、16次切换；40生活点、8项任务与保存/取消/重做；小窗七按钮完整可见 | [home-exterior-report.json](home-exterior-report.json) |
| 原有移动与校园/家庭回归 | 229项通过；39段路线、26次切换、1次真实碰撞探针 | [movement-report.json](movement-report.json) |
| GLB、锚点、地面、可达性与源文件保护 | 86项通过；208份既有资产、8册教材JSON哈希未变 | [asset-report.json](asset-report.json) |
| 原生画面与小窗口输入 | 31项通过、8张截图；960窗口实际点击阳台并返回正门，生产存档未变 | [native/report.json](native/report.json) |
| Godot项目静态检查 | 803文件，0错误、0警告 | [project-check.log](project-check.log) |

使用 Godot 4.7.2 / GL Compatibility 和 Blender 5.2.2。全部为受影响范围检查，未运行整个游戏的全量测试。

正常游玩镜头、同前版的44米总览镜头、正门前人物和960入户面板均实际查看。小窗口设置为960×640，保持游戏画面比例后的捕获纹理为960×600，两者均记录在原生报告中。修复了翼楼内侧檐边露出主楼屋面的拼接问题；翼楼屋顶向主楼内部延伸，内端斜檐省略。七个房间按钮在最小窗口完整显示。

首次原生小窗口测试把UI逻辑坐标直接交给屏幕输入，误点到相邻返回按钮；最终使用 `Viewport.push_input(..., true)` 注入正确的局部坐标，保留生产控件和处理逻辑，重新完整运行通过。该失败尝试不计为验收。

## 本机渲染样本

最终原生运行在 RTX 4070、1440×900、VSync开启的条件下采集120个实际绘制帧：1.641秒，平均约73.14fps，中位帧间隔12.99ms；平均5755次绘制调用，671048个渲染图元。原始逐帧记录在原生报告中。样本包含当前游戏场景、界面与阴影，未使用 `--fixed-fps`，不代表目标设备、移动端或长期稳定帧率验收。

最终GLB为18,417,868字节、2267节点、422560个实例化三角形。材质与几何均原创，无外部纹理；可编辑Blender工程保留各结构和庭院部件。尚未做移动端LOD与静态材质合批。

## 文件保护与复现

- 新工程另存为 `home_estate/home_estate_v02.blend` 和同名GLB；v01剖面工程、预览以及七个三级房间模型均保留。
- 教材、缓存语音、旧客厅ID和既有生活记录保留；全部引擎测试使用隔离验证存档，并比较生产存档及备份哈希。
- 修改前文件备份：[before.zip](before.zip)、[before.json](before.json)、[flow-before.zip](flow-before.zip)、[flow-before.json](flow-before.json)。
- `test_home_hierarchy.gd` 现在是新家庭专项的兼容入口；新报告输出到v2目录，v1历史报告与截图没有被覆盖。

```powershell
python -X utf8 scripts/sync_blender_interiors.py --verify-only --require-all
python -X utf8 scripts/verify_home_exterior.py
$godotBin = 'F:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godotBin --headless --path game --import
& $godotBin --headless --fixed-fps 60 --path game --script res://tests/test_home_exterior.gd -- --test-harness
& $godotBin --path game --script res://tests/capture_home_exterior.gd -- --test-harness
python -X utf8 scripts/build_home_exterior_gallery.py
```

`scripts/build_home_exterior.py` 与 `scripts/home_courtyard_detail.py` 是本版原创建模脚本。显式运行会重建v02工程；手工编辑之后应沿用保存工程再导出的工作流，避免用生成器覆盖人工修改。来源核对和学习效果边界见[家庭内容说明](../../planning/home-hierarchy/README.md)。
