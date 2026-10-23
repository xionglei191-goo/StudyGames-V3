# 本地学习素材开发流程

当前默认从 Godot 工程运行，不导出 EXE，也不制作 ZIP。

## 启动当前改动

- 双击项目根目录 `启动字母岛.cmd`，或运行 `./start-game.ps1`：直接启动 `game/project.godot` 所在工程。
- 运行 `./start-game.ps1 -Editor`：打开当前工程编辑器。
- 只有明确需要查看已有成品时使用 `./start-game.ps1 -Built`。该开关只运行已存在的 EXE/PCK，不创建新包；它可能早于当前源码。
- `-GodotPath` 继续用于指定引擎路径，`-Editor` 与 `-Built` 不能同时指定。

## 复制生成素材并检查原图

每次生成记录写入 `.local/art_refresh_all_generation.json`，条目包含 `id`、`kind`（`letter` 或 `prop`）、`prompt`、`generated_source` 和实际使用的 `referenced_image_paths`。23 个新增字母与故事道具按选定生成结果逐项登记；已验收 B/O/K 保持 v1 原文件，v2 清单只引用它们。

```powershell
uv run --with pillow python -X utf8 scripts/prepare_learning_art.py
```

脚本将新 PNG 原样复制到 `assets/art/storybook_v2/source/` 和 `game/assets/learning/storybook_v2/`，道具位于各自的 `props/` 子目录。它检查实际 PNG 解码、RGBA、256–4096 像素的边长、透明四角、可见主体边界，以及源图与副本 SHA-256；字母要求方形画布，道具允许横向或纵向画布。它不改变任何图片像素。已存在且摘要相同的文件直接复用。若目标被另行改动且不匹配既有登记摘要，脚本会停止，避免覆盖。

检查结果写入 `docs/verification/art-refresh-all/preparation-report.json`，完整提示词、源文件摘要和 alpha≥128 的包围框写入 `assets/art/storybook_v2/manifest.json`。该清单保持候选状态，原图检查通过不代表已通过游戏视觉验收。

首次由 Godot 导入 PNG 后，配置已生成的纹理 sidecar：

```powershell
uv run --with pillow python -X utf8 scripts/prepare_learning_art.py --configure-imports
```

此开关只设置已存在的 v2 `.png.import`：无损压缩、关闭 mipmap、关闭透明边缘颜色重写与预乘 alpha。没有导入 sidecar 的文件记作 `not_imported_yet`。后续需由单独的 Godot 导入步骤应用设置；脚本本身不会启动引擎。

整批到齐后加 `--require-complete`，要求 26 个字母与 10 张计划道具均已登记。之后再做受影响路径的本地组件/窗口验证。生成源图、旧 SVG、v1 资料和已有成品均保留。
