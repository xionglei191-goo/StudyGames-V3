# v0.8.1-dev · 我的朋友角：首个 U2 可玩样板

日期：2026-10-23。范围：将 U2 邀请任务接到「选择样式 → 投递 → 收回信 → 回家布置 → 朋友记得」的完整过程。当前工程可直接本地运行，未导出 EXE / ZIP。

## 怎么玩

1. 双击根目录的[启动字母岛.cmd](../../../启动字母岛.cmd)，打开当前工程。
2. 在「旅行册 → 我的朋友角 · 小岛心愿」查看目标。还没完成 U1 时，主旅程继续原有前置内容；不会提前发放 U2 回信。
3. 到 U2 邮局准备邀请时，为两张邀请各选原色、花朵或星星。问清名字，再把信送进对应信格。寄出后保留当时选择。
4. 完成 U2 后收下两封回信和展示用信夹。可以立即回家摆放，也可以主动继续 U3 欢迎桌或先自由活动。
5. 点击回信再点击挂点，或直接拖过去。三个挂点可换位，花朵/星星信夹可切换；「先收进册里」保留信件。确认后家中的实体展示板同步更新。
6. 「下次接着摆」保留试摆；「放弃这次试摆」恢复原展示。点回信可以大字阅读；回访 Lingling 或 Tim，他们会回应实际寄来的邀请样式。已挂好的回信还会引出对应回应。

已完成 U2 的旧档直接获得原章节对应的展示资格，不需要重新投递。当前用户存档未替换成测试进度。截图来自隔离的 U1 已完成测试存档；测试照片由游戏实际拍摄。

![确认后的小屋朋友角](1440x900/05-saved-friend-corner.png)

## 已完成的规则

- 回信与信夹使用同一 U2 完成事务和唯一凭据；重进、回访、改摆与取消均不再次奖励。新增叶币为 0，新增必需花费为 0。
- 独立回应和使用完整示范的路径均能完成章节并获得相同的生活成果；提示、示范和独立表现继续分别记录。
- 试摆与已确认展示分开保存。关闭、重开可恢复试摆；保存失败时回滚内存变化，保留原展示，允许重试。
- 合照沿用真实 U1 照片及原照片/整章两项凭据；照片未实际生成时只显示占位，不伪造一张测试合照到用户存档。
- 实体朋友角使用原家园展示位置，点击走近或 E 可打开。U3 需要的演员交互优先于普通朋友回访。
- 旧档迁移继承原 U2 凭据时间。未知的历史邀请样式保留为原色，不补造过去的选择、摆放或学习表现。

## 验证结果

Godot 4.7.2，Windows，GL Compatibility，NVIDIA RTX 4070。本轮运行以下相关检查，均退出 0：

| 检查 | 结果 | 证据 |
|---|---|---|
| 新增朋友角状态、旧 U2 档迁移、重复事件、坏数据、保存失败与重试 | 91 项，0 失败 | [state.json](state.json) |
| 原 P2 状态与事务回归 | 284 项，0 失败 | [p2-state.json](p2-state.json) |
| 原旅程、照片凭据、词故事状态与存档回归 | 727 项，0 失败 | [journey-state.log](journey-state.log) |
| 1440×900 实际窗口，含完整示范的 U2 路径与朋友角 | 240 项，0 失败 | [报告](1440x900/report.json) |
| 960×640 实际窗口，独立回应的 U2 路径与朋友角 | 231 项，0 失败 | [报告](960x640/report.json) |
| 原 U2→U3 连续章节、投递、座位、跨情境回应、可选回想和重拍 | 509 项，0 失败 | [回归报告](regression/chapters-1440x900-native.json) |
| 原经济、背包、学习记录、旧档与购买事务 | PASS | [legacy-state.log](legacy-state.log) |

有计数的检查合计 2,082 项。UI 检查使用引擎原生鼠标输入，包含真实拖放、点击替代、人物和房间切换、实际文件保存、从角色当前位置走近展示板，以及界面按钮边界检查。两种窗口的邀请卡、试摆、确认展示和回访画面均做过图片复查；已修复邀请标题竖排和选中按钮对比度问题。

当前项目保持 1440×900 的 16:10 逻辑画面。960×640 窗口内的引擎抓图为 960×600 有效画面，其余为留边；目录名标记窗口尺寸。[视口实测](viewport-sizes.json)记录实际窗口、逻辑画面与抓图尺寸。完整信件可在独立的大字阅读页查看。

测试前后的用户正式存档、备份及两张已有照片均按 SHA-256 比较；结果见[文件核对](artifact-checks.json)。测试进度使用独立路径，测试产生的临时存档和照片在结束时清理。预先备份保留在本机 `.local/backups/friend-corner-v1/`。

## 复现命令

在项目根目录的 PowerShell 中运行。原生窗口测试顺序执行，避免窗口抢焦点。

```powershell
$godotExe = 'F:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godotExe --headless --path game --script res://tests/test_friend_corner_state.gd
& $godotExe --headless --path game --script res://tests/test_p2_state.gd
& $godotExe --headless --path game --script res://tests/test_journey_state.gd
& $godotExe --headless --path game --script res://tests/test_state.gd
& $godotExe --path game --script res://tests/test_friend_corner_game.gd -- --test-harness --friend-size=1440x900
& $godotExe --path game --script res://tests/test_friend_corner_game.gd -- --test-harness --friend-size=960x640 --independent
& $godotExe --path game --script res://tests/test_p2_chapters.gd -- --test-harness --p2-size=1440x900 --report-dir=F:/LoveStudy/docs/verification/friend-corner/regression --capture=F:/LoveStudy/docs/verification/friend-corner/regression/1440x900
```

## 范围与后续

本轮完成[任务卡](../../planning/tasks-rewards/首版任务卡.md)中的 TR-04、TR-05 以及 TR-08 的回信布置部分，并复用 U1 合照。它是首个 U2 样板，未将八张任务卡、八册课程或整个奖励系统标记为完成。新的街区旅行成果、U3 聚会结尾演出、真实间隔复现调度及统一家长观察页仍待制作。

原生流程从 U1 已完成的隔离前置开始，本轮未重跑全量测试或重新导出安装包。新增回信和关系对白属于游戏原创；自动检查与成人画面复查不等于教学审校、儿童可用性或长期学习效果验证。

主要实现：[奖励与状态](../../../game/scripts/friend_corner_progress.gd)、[流程与世界展示](../../../game/scripts/friend_corner_controller.gd)、[回信板](../../../game/ui/friend_corner_board.gd)、[原创对白](../../../game/data/learning/friend_corner.json)。
