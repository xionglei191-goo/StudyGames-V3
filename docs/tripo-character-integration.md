# 12 个 Tripo 角色：骨骼绑定与游戏接入

2026-10-23。当前项目已通过 `game/assets/characters/active-set.json` 使用 `tripo_v1` 的全部 12 个角色。

运行项目根目录的 `start-game.ps1`，即可查看新版。也可打开 [角色预览页](tripo-characters-gallery.html)，逐个切换静态、挥手、步行/接物和递物姿态。

## 已交付内容

8 位站立人形角色使用 Adobe Mixamo 完成自动绑定，原始下载 FBX 和 SHA-256 位于 `assets/characters/mixamo_v1/downloads/` 及 `input/manifest.json`。熊叔、兔兔、Dino、轮椅 Jim 使用 Blender 定制骨架和蒙皮。所有角色均保留可编辑 Blender 文件、带骨骼 GLB 和 Godot 原生网格资源。

| 角色 | 绑定方式 | 游戏骨骼数 | 三角面数 | 基础动作数 |
|---|---|---:|---:|---:|
| 旅行小女孩 | Mixamo | 17 | 35,999 | 14 |
| Lingling 玲玲 | Mixamo | 17 | 35,999 | 14 |
| Peter | Mixamo | 17 | 35,998 | 14 |
| Anne | Mixamo | 17 | 35,998 | 14 |
| Mingming 明明 | Mixamo | 17 | 35,999 | 14 |
| Dongdong 东东 | Mixamo | 17 | 35,998 | 14 |
| Tim | Mixamo | 17 | 36,000 | 14 |
| Miss Li 李老师 | Mixamo | 17 | 36,000 | 14 |
| Dino | Blender 定制骨架 | 22 | 48,000 | 14 |
| 熊叔 | Blender 定制骨架 | 17 | 35,998 | 14 |
| 兔兔园丁 | Blender 定制骨架 | 20 | 39,999 | 14 |
| Jim | Blender 定制骨架 | 22 | 60,368 | 11 |

总计 472,356 个运行时三角面；原始 12 个模型总计 12,163,285 个三角面。PBR 纹理使用 2048 像素工作副本。原始 GLB 均保留。

## 游戏适配

- 保留原角色 ID、剧情语义、动作时长、接触事件和存档接口。
- Mixamo 权重映射到游戏语义骨骼；完整 FBX 的手指和脚趾骨仍保留在下载原件中。游戏当前使用合并后的手掌/脚部权重。
- 新增真实的 Blink、Smile、Talk 形变目标，并接回暂停和减少动态效果设置。
- 玩家原有黄、粉、蓝三种换装使用独立材质参数和衣物遮罩；背包等附件保留原色。
- NPC 行走/持物行走使用 `grounding.json` 的鞋底采样修正。此文件由 `bake_tripo_grounding.gd` 生成，运行时只读取位置关键帧。
- 兔兔放篮动作在适配层校准肩部伸手角度；原 P1 动作库文件及其接触时间没有改写。
- 挥手采用逐角色拟合的屈肘姿势、前臂旋转与小幅摆手，手掌朝前；熊叔使用肩侧的小幅招手。曲线保存在 `gesture-overrides.json`，与 Blender/GLB 动作共用。所有动作都明确复位手腕，支持中途切换。
- 熊叔与兔兔的工作服重新约束到躯干，并在袖口、肩带处平滑过渡。[查看调整前后与完整挥手](tripo-wave-refinement.html)。
- Jim 的手掌与裤腿、手臂与轮椅粘连处已经分离并补面；身体与轮椅分别蒙皮，轮椅保持刚性。

## 验证与边界

| 检查 | 结果 | 报告 |
|---|---:|---|
| 12 角色蒙皮、表情、暂停、动作及换装 | 1098 项通过；403 张实际 Godot 截图 | [角色报告](verification/tripo-characters-v1/native-1440x900-characters.json) |
| P1 动作时序、接触位置、脚底及移动约束 | 623 项通过 | [动作报告](verification/tripo-characters-v1/p1-actor-animation.json) |
| 实际主场景、地图、家园、衣柜点击与旋转 | 38 项通过 | [界面报告](verification/tripo-characters-v1/native-1440x900-gameplay.json) |
| 实际果园摘取、搬运、放篮及存档边界 | 53 项通过 | [果园报告](verification/tripo-characters-v1/orchard-integration.json) |
| 11 位 NPC 普通/减少动态模式的手掌朝向、手腕连续性及动作中断 | 198 项通过 | [挥手报告](verification/tripo-wave-refinement/wave-regression.json) |
| 原始及旧版资产保护 | 115 个文件哈希一致 | [保护报告](verification/tripo-characters-v1/preservation.json) |

检查使用隔离存档。角色报告记录本次实际使用的资源和驱动代码哈希。脚底测试对新模型采样真实蒙皮鞋底，不再套用旧模型的固定椭球尺寸。

Jim 近景仍可见局部补面的材质和轮廓过渡，部分原生成模型的袖口也有精修空间。当前动作不含独立手指抓握。Blender/GLB 内保留基础动作与本次挥手修正；Godot 的行走贴地修正在引擎适配层应用。未进行帧率性能验收、项目全量测试或旧 Windows 安装包重打包。

## 文件与重建

- 原始模型：`assets/tripo/01_player.glb` 至 `12_jim.glb`。
- 可编辑源：`assets/characters/tripo_v1/<角色ID>/rigged.blend`。
- 交换文件：同目录 `character.glb`；参数和来源见 `rig.json`。
- 运行资源：`game/assets/characters/tripo_v1/<角色ID>/Body.res`，Jim 另有 `Wheelchair.res`。
- 新旧代码切换前备份：`assets/characters/tripo_v1/runtime-before.zip`。

重建顺序：`prepare_tripo_characters.py` → `rig_tripo_characters.py`（8 位人形加 `--mixamo` 使用已下载 FBX；4 位特殊角色使用本地骨架）→ `refine_tripo_gestures.py` → `bake_tripo_characters.gd` → `bake_tripo_grounding.gd` → 相关检查 → `finalize_tripo_characters.py`。不要不带角色参数混用两种绑定模式。挥手修正前的 64 个文件另存于 `docs/verification/tripo-wave-refinement/before.zip`，包含源绑定、运行网格、驱动及旧挥手截图。

Blender 可执行文件：`F:/Tools/Blender/blender-5.2.2-windows-x64/blender.exe`。Godot 可执行文件：`F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe`。Godot 命令使用 `--path F:/LoveStudy/game --script res://...`，测试追加 `-- --test-harness`。

## 回退

将 `game/assets/characters/active-set.json` 的 `manifest` 改回 `res://assets/characters/storybook_v3/manifest.json`，重新启动游戏。旧模型、旧动作库和原始 Tripo 文件未删除；原始及旧版资产已核对哈希。
