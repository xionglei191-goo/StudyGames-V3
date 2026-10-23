# v0.8.0-dev · P0–P2 本地实施与验收

2026-10-23。本轮按 [GDD §21](../../../GDD.md) 的项目阶段完成 P0–P2 工程范围：家园准备 → 五街区短旅 → 全部 26 字母体验 → 三上 U1 欢迎会 → U2 邀请投递 → U3 年龄与人数情境。当前交付为本机 Godot 工程，不导出 EXE/ZIP。最终运行结果见 [执行汇总](final-run.json) 与[证据索引](verification-summary.json)，当前设备的性能记录单独列在下文。

## 已接通的玩法

| 范围 | 当前实际行为 | 证据与边界 |
|---|---|---|
| P0 策划整合 | 八册、81 单元、1,314 条出现记录与 26 个编码的联合静态检查通过；未知人物与标题级事件继续登记 | `p0-1.log` 至 `p0-5.log`。Windows 缺少时区包时，策划验证器使用明确的 UTC+8 回退。静态检查不代替正文审校 |
| P1 资产与交互样板 | 继续使用实际蒙皮角色和保存的动作库，验证人形、兔兔、Dino、Jim 轮椅坐姿；真实果园接触、暂停、保存失败恢复；词故事动作、H0–H5、可选记忆与恢复 | [角色动作 623 项](actor-animation.json)、[果园 50 项](orchard-integration.json)、[故事动画 3,030 项](story-animation.json)。故事夹具按原构建命令使用 `--fixed-fps 60` |
| 家园 | 花朵/星星实时预览，确认、取消或稍后再选；拿旅行册打开实际地图 | 两种尺寸的新档旅程，预览不写入，确认才保存；替换预览不叠加旧装饰 |
| 26 站 | A 为已有三维果园；B–Z 为对应对象的可操作观察卡。点击按钮可替代拖动；操作步骤、选择、帮助与放置位置保存 | [26 站动作表](landmark-actions.md)。不是 26 个完整三维经营小游戏 |
| 字形观察 | 每站显示原始模型的正面/侧面取景与字形提示，实际查看后才完成新发现页 | [52 张模型取景清单](../../../game/assets/learning/landmark_views/manifest.json)。原 GLB、节点、镜头、PNG SHA 可追溯，不改原地图几何 |
| 短旅与回想 | 五街区选一到三站，路线保存、向导陪同、下一站及回家；大小写、形象对应、尝试说字母名三种可选回想 | 选第四站不会增加；可跳过、重试和示范。尝试说话仅记录自述，不评分；示范后再试不算首次独立 |
| U1 | 名牌/欢迎角、Peter 实际递书、动作接触与收回手后提交；欢迎问候、可选 hello 故事、合照、回家展示与重拍 | [新档完整旅程](journey-game-1440x900-native.json)。重拍更新图片/相框，不重复首次纪念或整章记录 |
| U1 跨情境 | 到花园与兔兔再次回应，保存独立情境的尝试/提示与实际时间 | 同日跨情境不称为延迟回忆；书面情境选择不外推听说能力 |
| U2 | 熊叔、Lingling、Tim、Anne 在实际场景出现；询问姓名，按同名信箱投递两张邀请，回家收回信 | 拖放或先选信再点信箱；错误可重试；帮助不能降级；旧存档进入新章节 |
| U3 | Miss Li、Mingming、Dongdong、Tim 与 Anne 在教室相遇；年龄卡、三人/四人的座位卡、字母与十以内数词复习 | 年龄卡是游戏情境设定，不宣称教材人物的真实年龄；座位按人数而非年龄计数，可加减到十张 |
| 保存与证据 | 进度、实际音轨播放、帮助、示范、自述、跳过、纪念记录分别保存；失败时不提前提交 | [P2 状态 284 项](state-report.json)、旧旅程状态 727 项、记忆事件 38 项、旧经济与存档检查；无新增英语分数或叶币奖励 |

## 真实输入与画面复核

测试串行运行 Godot 原生窗口，使用引擎输入事件触发按钮、拖放及真实场景行走，使用隔离存档。没有把直接设置章节夹具当成新档通关：`test_journey_game.gd` 从家园走完 26 站与 U1；`test_p2_chapters.gd` 明确从 U1 已完成夹具起步，验证 U2/U3、回想、跨情境和重拍。

| 专项 | 1440×900 窗口 | 960×640 窗口 |
|---|---|---|
| B–Z 操作、源模型观察与恢复 | [504 项](ui-1440x900-native.json) | [504 项](ui-960x640-native.json) |
| U2/U3、投递拖放、人数、回想、重拍、街区选路 | [499 项](chapters-1440x900-native.json) | [499 项](chapters-960x640-native.json) |
| 新档家园、A 果园、26 站、U1、照片与故事恢复 | [189 项](journey-game-1440x900-native.json) | [189 项](journey-game-960x640-native.json) |

960×640 是窗口尺寸，保持 16:10 内容比例，原生视口 PNG 为 960×600；1440×900 窗口与内容均为 1440×900。截图目录为 `native-landmarks-*`、`native-chapters-*` 和 `native-journey-*`，共 256 张。每个字母保留操作前、操作后与原模型字形观察；B/M/I/J/K/T 另有中间步骤。截图在 Godot 中直接捕获，联络表仅缩放排列供复核，未替代原图。

另用[独立选项夹具](fixtures/test_alternate_choices.gd)实际点击 F/H/P/R 的第二个选项，验证金色花瓣、棒球帽、小南瓜与机器人另一动作及磁盘恢复，[26 项通过](alternate-choices.json)，追加 4 张 `native-alternate-960/` 截图；原有 25 站完整报告保留。

![U2 邀请投递](native-chapters-960/U2-04-scene.png)

![U3 按四位来客摆座位](native-chapters-960/U3-07-correct-count.png)

![五街区自选短旅](native-chapters-960/trip-three-stops.png)

专项边界包括：空白点击不推进、真实拖放、错误后帮助、最高提示持久化、静音不记播放、两种音轨分别记录、应用失焦冻结、半途关闭与磁盘恢复、写入失败回滚、重复事件、连续 32 次错误后仍能示范退出。先前 `ui-960x600-*`、`state-roundtrip-debug.json` 等为开发诊断记录，不代表最终结果；以执行汇总与上表文件为准。`initial-story-animation-without-fixed-fps.log` 记录一次遗漏夹具固定帧率参数的失败，按原构建参数重跑通过。

## 当前设备性能

当前版本的 [12 段实测](performance-current/summary.md) 已完成，`summary.json` 的 `formal_record_valid=true`，六组配对均有效，前后工程源文件 SHA 一致。测量为果园、主岛、校园三个场景，动态环境开/关、两轮配对，每阶段预热 10 秒、采样 60 秒。原始帧数据、根视口 CPU/GPU 时间、进程内存、驱动、窗口与焦点状态均保存。

设备为 Ryzen 5 3600 / RTX 4070，Godot 4.7.2，GL Compatibility，1440×900。动态开启时，两轮帧耗时 p95：果园 2.776/2.805 ms，主岛 4.805/4.868 ms，校园 4.172/4.205 ms；根视口 GPU p95 分别为 0.880/0.884、1.518/1.525、1.351/1.358 ms。Windows 焦点记录确认本次全部为后台采样，因此不据此宣称正常前台操作帧率或游戏行走性能。

这是当前机器、当前 GL Compatibility 设置与静止镜头的测量，不代表低配电脑、所有画质、四天气×四时段、行走或词故事负载。后台测量夹具的焦点暂停覆盖仅用于比较，普通游戏仍在失焦时暂停。

## 来源、运行与保留工作

[来源保护核查](source-preservation.json)核对了 217 项原资产/课程输入/正式存档与备份，并验证 52 张模型取景。新增进度位于旧存档 `journey.p2` 子树，缺省旧档迁移，不清空旧物品、课程、经济或历史纪念。修改前代码副本在本地 `.local/p2-baseline`；没有清理无关工作或提交/合并。

双击根目录[启动字母岛.cmd](../../../启动字母岛.cmd)，或执行 `./start-game.ps1`。从「旅行册 → 继续我的旅程」继续现有进度；操作步骤与异常处理见[游玩说明](../../Blender地图版游玩说明.md)。

以下不属于已完成的工程验收：独立教学编辑审校、合成音频人工听审、儿童可用性试玩及长期记忆效果；八册全部 81 章的完整制作、144 条身份记录对应的全部人物与 P3/P4 扩展。当前 26 站的支持体验及三上前三单元的原创生活情境不等于英语掌握或教材全内容覆盖。

## 复核入口

在工程根目录运行下列命令；引擎测试使用隔离存档，正式存档哈希仍会被检查。原生测试需串行运行，不与性能采样同时启动。

```powershell
$p2Engine = 'F:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $p2Engine --headless --path game --script res://tests/test_p2_state.gd -- --test-harness
& $p2Engine --headless --path game --script res://tests/test_journey_state.gd -- --test-harness
& $p2Engine --headless --fixed-fps 60 --path game --script res://tests/test_p1_story_animation.gd -- --test-harness
& $p2Engine --path game --script res://tests/test_journey_game.gd -- --test-harness --journey-size=960x640
& $p2Engine --path game --script res://tests/test_p2_chapters.gd -- --test-harness --p2-size=960x640
& $p2Engine --path game --script res://tests/test_p2_ui.gd -- --test-harness --p2-size=960x640
python -X utf8 scripts/verify_p2_sources.py
```

其他原生尺寸改为 `1440x900`；需保存截图时，旅程夹具使用 `--journey-capture=<绝对目录>`，其他两个夹具使用 `--capture=<绝对目录>`。完整示范可在 `test_p2_ui.gd` 后添加 `--demonstrate`。测试默认写当前 `p2/` 报告，保留历史结果时先复制到新目录。

性能采样使用 `scripts/verify_p1.py performance --rooms landmark_A,village,school --repeats 2 --allow-background --output <新目录>`，不要覆盖已验收的目录。证据索引由 `scripts/build_p2_verification_summary.py` 生成，它同时核对报告结果、退出码、错误日志、来源保护与性能记录的有效性。
