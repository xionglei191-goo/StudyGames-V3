# own16 云端模型同步 · 2026-10-27

已将用户提供的 [Google Drive 目录](https://drive.google.com/drive/folders/1bqluU1N8p1e_igYxvX7enMd_YrlbvydR) 中的 own16 环境模型同步到当前 `F:\LoveStudy` 工程：44个运行GLB全部更新，44套Blender/GLB/预览共132个源文件按原版本名保存。另9个角色等模型与云端相同，无需替换。

[最新本地图册](../../models-latest-gallery.html) · [完整替换清单](sync-report.json) · [云端源索引](cloud/SOURCE-INDEX44.json) · [备份恢复说明](baseline-notes.md)

## 使用

运行项目根目录的 `start-game.ps1` 默认入口即可使用当前模型。此入口使用当前工程；旧 Windows EXE 和网页打包文件本次没有重新导出。编辑时使用源索引或 [室内资产说明](../../../assets/blender/interiors/README.md) 列出的当前 `.blend` 文件。

主岛源文件为 `assets/blender/alphabet_island/alphabet_island_layout_v13_own.blend`。家庭仍按“小院正门 → 室内门厅 → 步行到房门 → 进入房间”运行。

## 校验与回归

| 范围 | 本机结果 | 证据 |
|---|---|---|
| 下载与模型一致性 | 67个分片、两个归档SHA/CRC校验；132源文件与44运行模型逐项SHA一致 | [下载验证](download-verification.json)、[同步报告](sync-report.json) |
| A–Z | 787检查；182段行走、52次转场、130处记忆点 | [运行汇总](headless-validation-summary.json) |
| 校园 | 352检查；56段行走、16次转场 | 同上 |
| 家庭 | 942检查；62段行走、20次转场；40生活点与8家务 | 同上 |
| 移动碰撞 | 244检查；41段行走、28次转场、1次实体碰撞探针 | 同上 |
| 原生渲染 | 44场景、97张截图、3511检查通过；6段额外家庭实走及6次E门转换 | [原生报告](native/report.json) |
| 导入与静态检查 | Godot导入exit0、stderr为空；项目静态1776文件0错误0警告 | [导入日志](import.stdout.log)、[静态记录](project-check.log) |

本机为 Windows / Godot 4.7.2 / GL Compatibility / RTX 4070。四套定向运行验证均exit0，stderr为空，联合覆盖44个场景。原生检查确认2938个碰撞代理均不可见，1238条材质纹理引用尺寸有效。88张场景截图分别使用正常游玩镜头与明确标注的总览镜头；另9张家庭路线图经过真实行走及门交互。

97张截图已分工逐图复核，未见空场景、明显缺材质或代理块遮挡：[字母场景52张](native/review/visual-letters-review.json)、[主岛与校园18张](visual-campus-review.json)、[住宅18张与实走9张](native/review-home.md)。这些视觉结论限定于所记录的画面，通行和任务验证另见定向运行报告。

这是模型同步的受影响范围验证，未运行整个仓库的全量测试，也未进行目标设备性能基准测试。远端报告不代替本机结果。

## 必要适配与保护

- 同步主岛的渲染/碰撞分类清单、43室内清单和当前源路径；403个玩法锚点均保留。六个家庭房间的41处位置随新模型调整，已实际验证行走与交互。
- 仅向4个本地 `.glb.import` 合并树冠网格的导入策略，保留本地UID和Godot 4.7默认设置。
- `imported_world.gd` 仅加入3行 `render_hidden_nodes` 处理，支持新版地表的显示约定。其余当前游戏代码不从云端整包覆盖。
- 6个既有脏文件、11个持久存档/配置文件、206份旧Blender源文件按基线哈希保护。替换前198个文件已可恢复备份；另单独保存资产README原文。
- 部分云端Blender源是从GLB恢复的可编辑网格/材质，未恢复完整原始修改器和创作历史。本地原版源文件保留。本次未重新导出云端 `.blend`。

旧资产校验器的原始结果保留为 [asset-validation.json](asset-validation.json)：3张云端预览为960×666，低于原700像素高度门槛；厨房/浴室7个代理材质不透明，而当前导入器会隐藏所有代理。以上10项是旧校验规则差异，不修改云端文件来绕过。43室内没有其他结构或保守可达性错误；代理隐藏已由本机原生运行确认。详见 [规则差异说明](asset-policy-notes.json)。

首次原生捕获的测试脚本使用了不受支持的相对父目录遍历，修正为绝对路径后完整重跑通过；首轮日志保留在 `native/attempt01/`，不计入验收。

## 复现与恢复

```powershell
python -X utf8 scripts/sync_blender_interiors.py --verify-only --require-all
python -X utf8 scripts/sync_blender_world.py --verify-only
powershell -File game/tests/drive_model_sync/run-headless-suites.ps1
python -X utf8 scripts/build_models_latest_gallery.py
```

下载分片、校验清单和两个完整归档保留在 `.local/imports/drive-own16-20261027/`；不执行远端包的恢复脚本。实际集成脚本为 `scripts/sync_drive_models.py`，默认只预检，`--apply` 执行明确列出的资源同步。回退请按 [baseline-notes.md](baseline-notes.md) 选择性恢复并重新导入；不要覆盖后来产生的新存档或其他工作。
