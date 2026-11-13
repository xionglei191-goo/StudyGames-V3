# 34 位建筑居民的绑定资产

已使用 Mesh2Motion 的本地蒙皮求解器生成真实骨架权重，并按个体体型修正。正式角色验证和 34 个房间接入验证均通过。

- [查看全部人物与连续动作](../../../docs/verification/building-residents-v1/index.html)
- [交付说明与重建步骤](../../../docs/delivery/building-residents-rigging-20261112.md)
- [原文件、居民 ID、房间和模型对应表](mapping.json)
- [文件、骨架与权重检查](asset-checks.json)

每个 `resident_*` 目录包含可编辑的 `rigged.blend`、带 14 个基础动作的 `character.glb`、骨骼与来源说明 `rig.json`、Mesh2Motion 求解输入输出，以及 Blender 检查图。`rig.json` 保留生成阶段状态；最终 Godot 验证见上方交付说明中的报告。

原始用户 GLB 位于 `assets/tripo/building_residents_v01/`，未改写。游戏运行资产位于 `game/assets/characters/building_residents_v1/`，实际动作预览以 Godot 运行资源为准。
