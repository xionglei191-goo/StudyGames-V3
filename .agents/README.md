# LoveStudy 项目技能

本目录安装了 [awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) 中约定的 12 个技能，仅用于本项目。

来源版本：`38a4c2500eeb5ff9ac084336b8f66108069d2f8d`。安装日期：2026-10-22。

## 已安装

- 路由：`router`
- Godot 基础：`godot-gdscript`、`godot-nodes-scenes`、`godot-signals-groups`、`godot-resources`
- 交互与表现：`godot-physics`、`godot-ui-control`、`godot-animation`
- 检查与导出：`godot-gdscript-headless-testing`、`godot-export`
- 原型与素材：`prototype-fast`、`create-game-assets`

## 使用

在本项目后续对话中，技能可以按任务自动选用，也可以显式使用 `$router`、`$godot-gdscript` 等名称。

技能目录是 `.agents/skills/<技能名>/`；Godot 游戏目录是 `game/`。运行配套脚本时，从项目根目录使用完整的技能脚本路径，例如：

```powershell
py -3 .agents/skills/godot-nodes-scenes/scripts/check_godot_project.py game
```

素材检查与预览脚本需要 Python 3.10+ 和 Pillow 10–12；安装时检测到本机 `py -3` 为 Python 3.14.0，Pillow 为 12.1.1。

## 来源与维护

具体清单和上游文件校验值见 [gamedev-skills.lock.json](gamedev-skills.lock.json)。34 个技能原文件复制后均与上游 Git blob 校验值一致。

安装适配只在 `router/SKILL.md` 增加了明确标注的本地路径说明；上游完整路由表仍保留为参考。版本说明、[LICENSE](skills/LICENSE) 和 [NOTICE](skills/NOTICE) 已一并保存。

更新时应保持本次选择的技能范围，先检查本地改动，再比较来源版本并重新应用路径适配。
