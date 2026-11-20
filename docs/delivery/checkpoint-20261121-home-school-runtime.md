# 当前工程检查点 · 2026-11-21

仓库：`xionglei191-goo/StudyGames-V3`；分支：`v4/foundation`；标签：`checkpoint-20261121-home-school-runtime`。

本检查点保存当前源码、可编辑 Blender 文件、运行资源、制作脚本及验证材料，覆盖家园与学校互动、空间词群、等级与奖励记录、手作工坊、角色和道具美术，以及语音和存档运行修复。模型、贴图和字体沿用仓库的 Git LFS 规则保存。

## 本版验证依据

- [运行优化与验证](../verification/runtime-maintenance-20261121/README.md)：17 组相关验证通过；4 份现有存档的前后 SHA-256 一致。提交前重新核对记录中的 9 个源码文件哈希，均与受测版本一致。
- [家园与学校美术记录](../verification/asset-realism-20261120/README.md)：保留同机位对照、107 件学习和手作模型检查、15 个角色资源检查及相关回归材料。

本次保存复用上述已完成的验证结果，未重新执行整套测试。Windows/Web 历史导出包未随本次 Git 检查点重建。

## 恢复与启动

安装 Git LFS 后，克隆仓库并恢复标签：

```powershell
git clone https://github.com/xionglei191-goo/StudyGames-V3.git
cd StudyGames-V3
git switch --detach checkpoint-20261121-home-school-runtime
git lfs pull
```

按项目 README 配置 Godot 和伴学依赖，然后通过根目录的 `启动字母岛.cmd` 运行源码工程。云端伴学需要自行将 `.env.example` 复制为 `.env` 并配置；本地语音模型、虚拟环境与生成缓存需在恢复环境中单独准备。

个人存档、实际密钥、`.local/` 缓存、历史构建包及含存档的回退压缩包保留在原机器，不包含在该 Git 检查点中。
