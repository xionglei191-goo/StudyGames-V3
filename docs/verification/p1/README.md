# P1 交互与资产样板验收

依据为 [GDD 第 21 节](../../../GDD.md)、[动态美术总策划第 8–9 节](../../planning/art/动态美术总策划.md)、[角色样板要求](../../planning/art/角色制作与替换管线.md)和[环境对照要求](../../planning/art/环境动态与天气昼夜策划.md)。本目录记录实际实现与证据；策划中历史的 planned 描述不作为实现通过凭据。

本轮结论：**9 项 P1 样板门槛通过**。见[最终验收](final-acceptance.md)及其[机器可读结论](final-acceptance.json)；更广环境矩阵、画质档和儿童试玩仍单列未测。

## 验收口径

| 门槛 | 本轮需交付的证据 | 当前记录 |
|---|---|---|
| 一个真实街区片段 | A 果园取物→携物移动→放置；距离、遮挡、携物挂点、接触时刻、中断重进与幂等；实际世界画面 | [专项交互](../v0.6.0/orchard-integration.json)与[双尺寸连续演出](../v0.6.0/orchard-motion-visual.md)通过 |
| 词故事组件 | nose 词义桥接；book 两个 O 独立；I'm、café 符号/重音；长词分镜暂停续看；rain 世界冻结时教学场景可理解 | [专属动画 3,094 项](../v0.6.0/story-animation-native-report.json)、[特殊样例 533 项](../v0.6.0/story-specials-visual.md)、[960×640 原生补验 839 项](../v0.6.0/story-narrow-visual.md)通过 |
| 提示可靠 | H0–H5 的实际展示与证据一致；H3 隐藏字母不因动画泄露；回看、示范、无音频不写成独立掌握 | 状态、真实 UI 提示与动画可见性记录通过；全序列回看切换 H3/H0 可保存退出 |
| 四类动作样板 | 教材人形、熊叔/兔兔、Dino、Jim 轮椅分别记录动作；走路/转身/招手/递接；Dino 翼尾；Jim 坐姿、脚踏、礼物接触和视线 | [623 项动作检查、364 张 PNG、8 段 GIF](../../../assets/characters/p1/validation/视觉核查.md)通过；刚性骨骼样板范围 |
| 动作与碰撞一致 | 步行角色脚底、携物及递接挂点；事件不提前或重复；轮椅不套站立步行动作；地图碰撞与 SG 锚点不随风水移动 | 动作、果园和六组风水开关结构配对通过 |
| 动态可暂停 | 世界/演出两套时钟；菜单、后台、对话、减少动态；恢复不跨过未确认交接；词故事恢复默认暂停 | 动作、果园、故事播放和磁盘恢复路径通过；真实 rain 世界冻结、教学舞台继续已记录 |
| 风水样区 | 原材质保留、根部固定、错相摆动、湖面细纹；动态开关不改变任务与碰撞 | [243 张原生帧与视觉核查通过](environment-visual-review.md)；果园水样本为洗果盆，校园仅风 |
| 真实性能记录 | 同设备/分辨率/镜头/存档，关闭/开启各预热 10 秒、采样 60 秒；CPU/GPU、帧时、draw calls、内存和硬件信息 | [12 阶段、6 配对有效](performance-20261022-193930/performance-review.md)，保留原始 CSV、实际硬件和指标边界 |

机器可读状态见 [acceptance-matrix.json](acceptance-matrix.json)。passed_logic 只表示所列逻辑检查通过，pending_native 不允许被总检查数或退出码替代。最终完成状态以本目录的最终验收报告和对应原始记录为准。

## 已有证据及使用边界

v0.5.0 的[集成报告](../v0.5.0/integration-report.json)、[完整旅程](../v0.5.0/journey-game-report.json)、[词故事报告](../v0.5.0/memory-story-report.json)、[地图行走报告](../v0.5.0/blender-world-report.json)、[导出包冒烟](../v0.5.0/release-smoke-report.json)均有实际文件。它们证明对应版本中记录的内容；新增 P1 动作、取放、动画恢复与性能需要本轮重新验证。

本轮状态层新增果园事务与词故事动画快照，保持旧存档版本和原存档路径兼容。果园只允许 ready → carrying → deposited，本轮帮助方式从拿取即保存，完成时不能降低已观察的帮助等级，新轮才清空本轮方式；重复回执不重复推进；动画快照校验分镜、字母位置和进度，提示记录只能引用实际已揭示字母。已完成 727 项状态检查与原状态回归。这个结果不证明游戏内挂接或画面已经正确。

当前原生词故事证据为四组专属动作链（hello、nose、book、football）和四组特殊样例（I'm、café、International Children's Day、rain）。特殊样例使用来源动作分类驱动的通用舞台，已核对精确书写、全部七页顺序、长词第 4 页磁盘恢复、提示可见性及世界/教学时钟；不能推成其每句原文已有独立专属场景。默认窗口 1440×900 特殊样例完成 533 项检查；另在实际 960×640 窗口下完成 book 和特殊样例 839 项检查、53 次真实按钮点击及 90 张原生 PNG。窄窗口内容区因项目固定比例为 960×600，报告分别记录窗口、纹理和逻辑视口，未事后缩图代替原生运行。

正式性能记录保存于 [performance-20261022-193930](performance-20261022-193930/performance-review.md)：Ryzen 5 3600、RTX 4070、驱动 610.88、1440×900、GL Compatibility、4× MSAA。共 194,678 个帧间隔，12 个 60 秒阶段，6 组同条件配对；源文件和正式存档哈希不变，运行时错误为 0。实际 Windows 样本均为前台。该记录使用调试引擎运行产品主场景且关闭 VSync，不等于默认导出成品帧率或其他设备结论。

## 性能工具

在仓库根目录运行：

    python -X utf8 scripts/verify_p1.py inventory
    python -X utf8 scripts/verify_p1.py performance --rooms landmark_A,village,school --repeats 2

正式运行约需 14 分钟，不包含地图装载时间。每个场景重复两次，顺序为关→开、开→关，减少单一测试顺序带来的偏差。采样期间需要保持测试窗口在前台；失焦会使游戏暂停，所以任一采样帧失焦都会使该阶段失效。测试使用独立 validation-PID.json，记录正式存档哈希并核对不变。

也可添加 --allow-background 使用设置 NO_FOCUS 的专用原生测试窗口。该夹具仅在性能脚本内覆盖失焦暂停，并保留逐帧焦点、最小化、世界与演出暂停状态；最小化或暂停仍使记录失效。用户可以继续操作 Codex。Windows 的 GetForegroundWindow/GetWindowThreadProcessId 每 0.25 秒只读观察实际前台 PID，报告单独列出本游戏处于前台/后台的样本数，不能仅凭引擎 NO_FOCUS 或 focus 标志声称始终在后台。这样的结果称为“允许后台的原生渲染同条件开关对照”，不等同前台游戏体验，正式游戏的失焦暂停逻辑没有改变；操作系统对完全遮挡窗口的合成策略不单独测量。

添加 --motion-seconds 20 --motion-fps 4 可在每个场景的两轮完整开关配对全部结束后，重新启用动态并以目标 20 秒/4fps 采集 81 张原生 PNG。序列不会插在一对开启/关闭采样之间；图像读回和编码可能延长实际墙钟时间，游戏时钟也可能因单帧增量上限而慢于墙钟，因此逐帧保存实际时间，不宣称固定频率或实速录像。所有图像读回都在性能计时之外，序列只用于采样画面的变化核查。

工具调试可运行短采样：

    python -X utf8 scripts/verify_p1.py performance --pilot --duration 3 --warmup 2 --repeats 1 --rooms landmark_A

短采样只验证工具通路，即使退出成功也不属于正式性能验收。测试拒绝 headless、固定 FPS、人为帧延迟或禁用渲染。默认拒绝并行 Godot 游戏、编辑器和 Blender 进程；--allow-conflicts 仅供故障排查，报告仍判无效。

每次使用新的 .local/p1-performance-时间戳/ 目录，保留：

- hardware-preflight.json：CPU、GPU、驱动、系统、其他渲染进程。
- source-manifest-before/after.json：运行前后代码、字体、纹理、音频、导入配置等源文件 SHA-256；排除 Godot 缓存和测试报告。
- raw-report.json、每阶段 CSV 和 PNG：原始逐帧记录、固定镜头、分辨率、场景三角形、静态结构摘要、暂停/焦点状态。
- process-memory.csv：Windows 进程 Working Set、Private Commit、Peak Working Set、GetProcessTimes 进程 CPU 时间及机器/单核等效占比、实际前台 PID，每 0.25 秒采样。
- summary.json、summary.md：p50/p95/p99、同场景动态增量、有效性及限制原因。
- godot.stdout.log、godot.stderr.log：完整运行日志。即使退出码为 0，脚本错误仍使报告无效。

截图在预热后、正式采样前完成。帧行暂存在内存中，采样结束后写 CSV；Python 的内存采样成本和 Godot 计时器开销仍存在，开关两种模式使用相同采样方式。

配对检查同时比较相机、分辨率、天气/时段、网格数量、风水目标数量、演员身份/类型/根变换，以及去掉引擎自动实例编号后的碰撞/SG 签名；碰撞签名包含变换、形状类型与包围盒、碰撞层/遮罩/禁用状态。原始路径签名另用于单次阶段前后核对。演员生成失败、阶段内布局改变或同一对前台样本占比差超过 5 个百分点均使配对失效。

## 指标解释与未测范围

wall_frame_ms 是连续 frame_post_draw 的实时时间间隔。engine_process_ms、engine_physics_ms 是引擎每秒发布的峰值监视器，并非逐帧 CPU 时间；截图和装载峰值还可能留在缓存中，这两列只保留诊断，不作逐帧分位或 CPU 预算结论。已核对本机引擎同 commit 的 [main.cpp 实现](https://github.com/godotengine/godot/blob/ed1daf0bf/main/main.cpp#L4723-L4761)。viewport_render_cpu_ms 和 viewport_render_gpu_ms 是独立的根视口渲染计时，不表示整个进程全部 CPU/GPU 成本；全零 GPU 计时返回“不可用”，不伪写成 0 ms。接口边界见 [Godot RenderingServer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html)。

rendered_vertices_or_indices 包含渲染各遍中的顶点或索引数，不能直接改名为“三角形数”。独立的 scene_mesh_triangles 来自场景可见树中 MeshInstance3D 的网格拓扑，含屏幕外物件，不含 MultiMesh 粒子与重复渲染遍数。监视器部分数值可能滞后，详见 [Godot Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html)。

进程 Working Set 是驻留内存，Private Commit 是私有提交，Godot 静态分配和显存监视器另列。OS.get_memory_info() 只用于系统内存背景，不能替代进程内存，参见 [Godot OS](https://docs.godotengine.org/en/stable/classes/class_os.html)。

本轮原生性能记录只覆盖受测机器与当前 GL Compatibility 配置。代码尚无经过验收的低/标准/高画质档，因此不能称为“三档通过”，也不据此承诺其他设备帧率。规划表中的预算仍是待测目标。四天气×四时段、主岛/校园/果园/室内以及两个分辨率的完整环境矩阵单独登记；单个晴天风水样区不能代替该矩阵。儿童理解、喜好和长期学习效果仍需真实试玩观察。

环境关闭会复位树冠、撤除本模块的水面覆盖材质、隐藏雨滴；演员、世界时钟、天气照明、雾和已分配资源保留。因此晴天配对只测风与水展示的增量，不能称为整套天气/昼夜的总成本，也不能把工作集差值解释为卸载新资产所节省的内存。
