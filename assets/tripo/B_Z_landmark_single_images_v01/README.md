# B—Z 地标单图参考素材

已完成剩余 **25 个地标，每个仅一张独立 PNG**，用于 Tripo 单图生成 3D 模型。统一为白色背景、完整地标、圆润暖色的 3D 游戏美术；大写字母融入门窗、支架、采光窗、编织或楼梯结构。

图片使用**内置图像生成工具**逐张生成，并检查了对应对象与字形。原始生成图片未经裁剪、拼接或后期改画。所有图片均为 **1254 × 1254**。

上传 Tripo 时，从 `images/` 中为每个模型选择对应的一张图片即可。A 苹果屋沿用已有参考图；本包只包含 B—Z，不重复生成 A。

## 图片与提示词

| 字母 | 地标 | 英文对象 | 单张图片 | 生成提示词 |
|---|---|---|---|---|
| B | 船屋码头 | Boat | [PNG](images/B_boat_house.png) | [提示词](prompts/B_boat_house.txt) |
| C | 蛋糕烘焙坊 | Cake | [PNG](images/C_cake_bakery.png) | [提示词](prompts/C_cake_bakery.txt) |
| D | 鼓屋音乐厅 | Drum | [PNG](images/D_drum_music_hall.png) | [提示词](prompts/D_drum_music_hall.txt) |
| E | 蛋壳孵化屋 | Egg | [PNG](images/E_egg_hatchery.png) | [提示词](prompts/E_egg_hatchery.txt) |
| F | 巨花温室 | Flower | [PNG](images/F_flower_greenhouse.png) | [提示词](prompts/F_flower_greenhouse.txt) |
| G | 地球仪旅行馆 | Globe | [PNG](images/G_globe_travel_hall.png) | [提示词](prompts/G_globe_travel_hall.txt) |
| H | 帽子裁缝店 | Hat | [PNG](images/H_hat_tailor_shop.png) | [提示词](prompts/H_hat_tailor_shop.txt) |
| I | 冰淇淋驿亭 | Ice cream | [PNG](images/I_ice_cream_kiosk.png) | [提示词](prompts/I_ice_cream_kiosk.txt) |
| J | 玻璃罐收藏馆 | Jar | [PNG](images/J_jar_collection_museum.png) | [提示词](prompts/J_jar_collection_museum.txt) |
| K | 风筝工坊 | Kite | [PNG](images/K_kite_workshop.png) | [提示词](prompts/K_kite_workshop.txt) |
| L | 灯笼驿站 | Lantern | [PNG](images/L_lantern_waystation.png) | [提示词](prompts/L_lantern_waystation.txt) |
| M | 蘑菇邻居屋 | Mushroom | [PNG](images/M_mushroom_cottage.png) | [提示词](prompts/M_mushroom_cottage.txt) |
| N | 鸟巢观察屋 | Nest | [PNG](images/N_nest_observation_house.png) | [提示词](prompts/N_nest_observation_house.txt) |
| O | 猫头鹰图书馆 | Owl | [PNG](images/O_owl_library.png) | [提示词](prompts/O_owl_library.txt) |
| P | 南瓜农场屋 | Pumpkin | [PNG](images/P_pumpkin_farmhouse.png) | [提示词](prompts/P_pumpkin_farmhouse.txt) |
| Q | 拼布故事馆 | Quilt | [PNG](images/Q_quilt_story_house.png) | [提示词](prompts/Q_quilt_story_house.txt) |
| R | 机器人工坊 | Robot | [PNG](images/R_robot_workshop.png) | [提示词](prompts/R_robot_workshop.txt) |
| S | 星形天文台 | Star | [PNG](images/S_star_observatory.png) | [提示词](prompts/S_star_observatory.txt) |
| T | 火车车站 | Train | [PNG](images/T_train_station.png) | [提示词](prompts/T_train_station.txt) |
| U | 雨伞气象屋 | Umbrella | [PNG](images/U_umbrella_weather_house.png) | [提示词](prompts/U_umbrella_weather_house.txt) |
| V | 休眠火山观察站 | Volcano | [PNG](images/V_volcano_observation_station.png) | [提示词](prompts/V_volcano_observation_station.txt) |
| W | 鲸鱼海洋馆 | Whale | [PNG](images/W_whale_aquarium.png) | [提示词](prompts/W_whale_aquarium.txt) |
| X | 木琴海边舞台 | Xylophone | [PNG](images/X_xylophone_stage.png) | [提示词](prompts/X_xylophone_stage.txt) |
| Y | 毛线手作屋 | Yarn | [PNG](images/Y_yarn_craft_house.png) | [提示词](prompts/Y_yarn_craft_house.txt) |
| Z | 斑马邮局 | Zebra | [PNG](images/Z_zebra_post_office.png) | [提示词](prompts/Z_zebra_post_office.txt) |

## 文件组织

- `images/`：25 张最终图片，每个字母一张。
- `prompts/`：25 份对应的完整英文图像生成提示词。
- [manifest.json](manifest.json)：名称、尺寸、文件大小与校验和。
- [gallery.html](gallery.html)：本地图片总览，点击缩略图可打开原图。

这些是单视角建模参考图；生成 3D 后的背面、拓扑、尺寸和可通行门洞仍需在 Blender 中检查。当前包不含新的 3D 模型。

