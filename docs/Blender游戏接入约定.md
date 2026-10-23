# Blender 地图与游戏的接入约定

地图的几何、摆放和交互定位以 Blender 工程为源；Godot 管理角色、碰撞、寻路、界面、任务和存档。保存 Blender 工程后，需要导出 GLB、同步资源并重新构建游戏，才能更新已经发布的 Windows 版本。

## 主地图

保留 `assets/blender/alphabet_island/alphabet_island_layout_v05.blend` 和原始模型。首次接入从 v05 创建独立的游戏编辑版本；后续导出始终读取这份新工程，保留人工修改。游戏只加载完整导出的岛屿，不重新生成地形和建筑布局。

主地图标记使用稳定的名字：`SG_SPAWN`、`SG_DOOR_A` 至 `SG_DOOR_Z`、`SG_DOOR_SCHOOL`、`SG_DOOR_HOME`，以及 NPC 和采集点标记。建筑入口应位于可行走空地，并作为对应地标根节点的子对象；移动整座建筑时，入口随之移动。编辑时不要更名或删除标记。

Blender 坐标 Z 向上，GLB/Godot 坐标 Y 向上。游戏使用导入后的节点变换，不手动填写坐标转换结果。碰撞和导航根据当前导入的几何及代理重新生成。角色通过物理碰撞走坡道和桥面。

主地图已有网格带有 `sg_collision` 自定义属性。新增网格可在 Blender 中设置为 `ground`（地面）、`building`（建筑）、`trunk`（树干）、`barrier`（围栏）、`water`（水域）或 `none`（无碰撞装饰），随 GLB 一并导出。新增可走楼面必须有朝外的顶面法线；新增通道还要检查人物宽度。入口位置调整无需修改 Godot 坐标。

## 二级场所与三级校园房间

共 35 个 room_id。二级场所为 `landmark_A` 至 `landmark_Z`、`school` 和 `home`，共 28 个。学校三级场景为 `classroom`、`music_room`、`art_room`、`science_room`、`canteen`、`playground`、`football_field`，共 7 个。

学校采用“主岛 `village` → 完整校园 `school` → 七处功能场所”的层级。校园包括可步行的道路、建筑、花园和运动区；各三级场景呈现对应场所的详细活动空间。计划数据中的 `scene_level`、`parent_room`、`return_to` 与 `model_bindings.doors` 描述层级和门的绑定。运行时从 Blender 读取门位置，三级出口返回校园对应门前。

场景资产放在 `assets/blender/interiors/<room_id>/`，包含独立 `.blend`、`.glb` 和预览图。总清单为 `assets/blender/interiors/interiors_manifest.json`。游戏工作副本放在 `game/assets/interiors/<room_id>.glb`，由同步脚本复制，不在该目录手改美术。

校园当前源文件是 `school/school_v03.blend`，旧 `school_v01.blend`、`school_v02.blend` 保留；其余场景使用各自 `_v01.blend`。日常导出必须读取清单里的 `blend/glb/preview` 路径，不能把保存的新校园重新导出到旧 v01 路径。

每个场景使用真实摆放且可走到的以下节点：

| 节点 | 用途 |
|---|---|
| `SG_SPAWN` | 玩家进入场景的位置 |
| `SG_EXIT` | 返回主地图或校园的交互位置 |
| `SG_MEMORY_01` 至 `SG_MEMORY_05` | 五个固定记忆位置，对应具体道具和生活动作 |
| `SG_NPC_HOST` | 场所主人的站位 |
| `SG_FLOOR_*` | 有可行走表面的地面网格 |
| `SG_COLLIDER_*` | 简化障碍网格，游戏隐藏外观并生成碰撞 |

学校额外使用 `SG_DOOR_CLASSROOM`、`SG_DOOR_MUSIC_ROOM`、`SG_DOOR_ART_ROOM`、`SG_DOOR_SCIENCE_ROOM`、`SG_DOOR_CANTEEN`、`SG_DOOR_PLAYGROUND`、`SG_DOOR_FOOTBALL_FIELD`。七个门应放在相应建筑或活动区的可站立入口；NPC 和记忆点应与门保持足够距离，防止互动提示互相遮盖。家园额外使用 `SG_BED`、`SG_WARDROBE`、`SG_DECOR_FLOWER_BOX`、`SG_DECOR_PICNIC`、`SG_DECOR_LAMP`，三个可显隐装饰的几何根节点命名为 `SG_DECOR_MODEL_FLOWER_BOX`、`SG_DECOR_MODEL_PICNIC`、`SG_DECOR_MODEL_LAMP`。

材质采用可导出到 glTF 的基础颜色、粗糙度和贴图。碰撞代理应导出为网格，不能只有未导出的 Blender 显示边框。光照由游戏配置。室内应能从倾斜镜头看清角色和主要工作区，避免前墙或完整屋顶遮住活动空间。

五个记忆位置的策划见 [二级地图制作策划](二级地图制作策划.md)。固定编号与含义保持一致，新增装饰不随意改变它们；具体教材、语音和任务脚本独立更新。

## 验证

同步前检查 GLB 文件、贴图、必需节点及稳定编号；同步后确认源文件与游戏副本哈希相同。游戏验收还要实际检查入口可达、地形落地、碰撞不堵门、进出后返回正确入口、任务和旧存档继续可用。模型导出成功仅代表资源有效，不能代替这些游玩检查。
