# StudyGames V3 · 字母岛

面向小学生英语学习的世界地图与三维素材项目。当前阶段专注地图和素材制作，包含 26 个字母地标、130 个记忆锚点、家园，以及位于北侧高地的独立学校。

![字母岛当前地图](assets/blender/alphabet_island/alphabet_island_overview_v05.png)

当前地图为 v05：统一环境与地标的材质，细化家园、烘焙坊、图书馆和校门，并提供第三人称及 1.35 米眼高的静态检查预览。

## 当前成果

- [世界地图 v05 与完整说明](assets/blender/alphabet_island/README.md)：Blender 工程、GLB、预览、地标清单和路线数据。
- [独立学校素材](assets/blender/school/README.md)：教学楼、操场、校园道具及独立素材包。
- [世界设计文档](docs/字母地标与记忆宫殿世界设计.md)：字母地标、街区与记忆空间设计。
- `assets/tripo/`：地标原始模型、参考图和生成记录。
- `docs/小学英语重点分析/`：现有教材分析资料。

学校与家园直线相距约 68 米，沿规划道路约 100 米，并通过另一条支路连接蘑菇村。当前交付是可继续编辑的世界素材；角色控制、碰撞、寻路、室内和学习交互尚未实现，教材故事线暂未开发。

## 获取完整素材

`.blend`、`.glb` 和 `.zip` 文件使用 Git LFS。克隆前安装 [Git LFS](https://git-lfs.com/)，然后运行：

```sh
git lfs install
git clone https://github.com/xionglei191-goo/StudyGames-V3.git
cd StudyGames-V3
git lfs pull
```

用 Blender 打开 `assets/blender/alphabet_island/alphabet_island_layout_v05.blend` 可继续编辑当前地图。GLB 可用于后续引擎导入；模型制作脚本与检查结果保留在对应素材目录，完整从零重建流程尚未验证。

历史地图版本和原始模型一并保留。Blender 自动备份、Python 缓存和本机临时文件不纳入版本控制。
