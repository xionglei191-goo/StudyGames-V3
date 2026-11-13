# 入户即客厅 · 模型替换交付

完成日期：2026-11-13。对应用户确认：“那继续完成模型修改，并进行替换”。

当前本地游戏已经采用方正客厅作为家庭中心：字母岛 → 小院 → 正门 → 客厅 → 六个原有房间。左侧依次是书房、卧室、浴室；右侧是厨房、餐厅、阳台。各房间出口回到客厅对应的门边，客厅前部玄关可返回小院。旧 `home_hall` 引用自动进入客厅。

## 打开与查看

- 双击项目根目录 `F:\LoveStudy\启动字母岛.cmd`，运行当前本地工程。
- 在岛上进入“家”，走到住宅正门按 **E**；客厅内可点地图选择目的地，再在门前按 **E**。
- 可编辑 Blender：`assets/blender/interiors/home/home_v08_living_hub.blend`。
- 配套导出：`assets/blender/interiors/home/home_v08_living_hub.glb`。
- 已替换的游戏模型：`game/assets/interiors/home.glb`。
- `overview.png`：实际 Godot 场景，使用明确的全景复核镜头并隐藏 HUD。
- `entry.png`、`door-home_*.png`、`bedroom-door-960.png`：实际行走后的生产镜头与 HUD。
- `map-1440.png`、`map-960.png`：两档窗口的实际地图界面。

本次替换作用于当前本地工程；独立旧 EXE/PCK 和网页导出包未重建。默认启动脚本使用当前工程。

## 模型与保留范围

- 从现有 `home_v07_own.blend` 修改，另存为 v08；方正底板为 20.4 × 15.6 米。
- 六个房门嵌在连续侧墙中，门洞宽 2.2 米，包含门框、门楣、门板、门把手、用途牌和碰撞体。阳台门使用玻璃分格。
- 入口设置门槛、地垫和换鞋凳。现有家具、装饰及学习点中 496 个对象的几何、UV、材料引用、变换和属性通过前后指纹对比。
- 保留原客厅 `.blend` / `.glb`，六个子房间的源模型与游戏模型均未改写；既有七个功能房间、40 个家庭记忆点和八项生活任务保留。
- 使用项目已有材质及贴图；GLB 内嵌 15 张图像，导出 244,968 个实例三角形，无外部贴图缺失。
- 实施前 349 份家庭资产中，只有授权替换的 `game/assets/interiors/home.glb` 改变。五份正式存档/资料文件的 SHA-256 保持一致。
- 工作区原有的其他未提交修改保持原样。

## 验证证据

| 检查 | 结果 | 文件 |
|---|---|---|
| 模型导出与原对象保留 | 496 个保留对象无变化，必需节点齐全，源/游戏 GLB 哈希一致 | `model-report.json`、`installation.json` |
| Godot 无界面实际物理与输入检查 | 168 项通过；26 条行走路线、19 次场景切换 | `runtime-report.json`、`runtime.log` |
| Godot 原生窗口实际输入与画面 | 179 项通过；26 条行走路线、19 次切换、11 张截图 | `native-report.json`、`native.stdout.log` |
| 八项生活互动回归 | 171 项通过，0 失败 | `household/results.json`、`household/runtime.log` |
| Godot 资源引用检查 | 1,943 个文件，0 错误、0 警告 | `reference-check.json` |
| 原资产、存档和其他修改保护 | 仅预期的运行客厅模型改变 | `preservation-check.json`、`delivery.json` |

物理检查覆盖岛上入户、六房间逐一往返、门口回程落点、门板碰撞、五个客厅记忆点、去卧室快捷操作、跨房间连续行走、旧门厅引用兼容，以及小窗口地图点击。地图按钮和门前 E 键均通过引擎输入事件分发；行走使用生产导航和 CharacterBody3D 碰撞。兼容入口测试单独使用直接场景请求，不计入实际行走路线。

原生截图与生活测试使用隔离存档。生活回归保留正式测试脚本原文，仅将输出目录改到本次目录，来源及原始 SHA-256 见 `household/source.json`。没有执行全项目所有玩法测试。

第一轮检查记录保留在 `runtime-attempt-1.*`。其失败来自测试未等待场景淡入完成、小窗口使用了未换算的窗口坐标、碰撞探针从门侧墙边而非门洞中心发出；修正测试后重新执行并通过。生产代码没有通过跳过碰撞或传送角色来规避检查。

## 复现与回退依据

修改脚本位于 `scripts/home_living_hub_20261113/`：`prepare.py`、`inspect_source.py`、`build_model.py`、`install.py`、`finalize.py`。Blender MCP 中先单独打开受保护的 v07 源文件，再运行建模脚本，让加载后的窗口上下文完成切换。

专项测试为 `game/tests/test_home_living_hub.gd`，要求 `-- --test-harness`；追加 `--hub-capture` 可输出原生截图。

`baseline.json` 记录实施前哈希；`before.zip` 是前一次准备备份，`before-resumed.zip` 是此次实施前备份；`scoped-code.patch` 只记录本次对既有代码的增量。回退时按具体文件核对备份与当前修改，原始模型始终保留。

上述 `baseline.json`、`before*.zip`、工作区原始差异和状态清单仅保存在本机，未上传 GitHub；压缩包包含个人存档。GitHub 版本保留当前代码、运行模型、可编辑源文件及验证结果。
