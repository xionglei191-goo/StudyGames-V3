# 北侧学校 · 独立世界素材

2026-10-22。学校位于字母岛北侧高地，建筑原点为 `(0, 54.2, 10.35)` 米；玩家家园在湖泊南侧 `(-3, -14)`。学校不占用 A—Z 字母编号，S 星形天文台保留。

![校园素材](school_campus_preview_v01.png)

## 文件

- [下载独立学校素材包](school_asset_pack_v01.zip)。
- [独立校园 Blender 工程](school_campus_v01.blend)：教学楼、校园道具和预览灯光，可直接继续编辑。
- [教学楼 GLB](school_building_v01.glb)：钟楼、主楼、侧翼、门窗、屋瓦与花箱。
- [完整校园 GLB](school_campus_v01.glb)：包含教学楼、操场、篮架、围栏、门柱、长椅、公告栏与种植箱。
- [独立预览](school_campus_preview_v01.png) · [坐标和路线清单](school_asset_manifest_v01.json) · [导出检查](school_export_validation_v01.json)。
- [校园在地图中的位置](../alphabet_island/alphabet_island_school_v04.png) · [家园与学校的空间关系](../alphabet_island/alphabet_island_home_school_route_v04.png)。

## 放置与尺寸

独立资产已归零，建筑原点为地面基准，底板稍微向下延伸；Blender 使用 Z 向上、正面朝 -Y，GLB 按标准 Y 向上导出。校园占地约 27 × 11 米。教学楼和校园是两个独立根对象，方便单独缩放、替换或编辑。室内尚未搭建。

在世界地图中，家园至学校直线相距约 68.3 米；从家门前广场按当前路线中心线，经 K 风筝工坊、L 灯笼驿站到学校，最短规划路线约 99.6 米。学校还通过另一条支路连接 M 蘑菇村，形成环路。这个距离是地图几何估算，没有经过角色行走或导航网格测试。

## 素材规格

教学楼约 33,196 三角面、1.50 MB；完整校园约 50,390 三角面、2.29 MB。使用 Blender 几何、材质与顶点色，不依赖外部贴图，也不是 Tripo 生成模型。门、窗、屋瓦、操场与道具保留可编辑结构；门的动画、碰撞和交互未设置。

校门、教室前、图书角、操场与食堂窗口预留五个空对象定位点。它们使用 `school_anchor_sequence`，与字母地标原有的 130 个记忆锚点分开。定位点仅是素材预留，不表示房间、学习任务或故事已经实现。

## 制作记录

[build_school_v01.py](build_school_v01.py) 记录校园建模、北侧地形适配、植被清理与支路；[plan_school_roads.py](plan_school_roads.py) 合并道路；[finish_school_v01.py](finish_school_v01.py) 记录道路贴地和独立导出。脚本依赖现有地图模块，属于分阶段制作记录，不能当作独立模型文件的一键重建入口。继续修改优先使用交付的 `.blend`。

本轮仅制作世界地图素材。教材与故事编排留待后续。
