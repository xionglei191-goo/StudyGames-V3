# 全场景美术精修 · 2026-10-24

本轮将小院与客厅的精修标准扩展到全部 **44 个现有可游玩场景**。当前游戏已经使用新版资产。[打开 44 场景同机位对照](../../world-refinement.html)，或双击工程根目录的「启动字母岛.cmd」。

范围为主岛 1、A–Z 场所 26、校园及功能区 8、家园及室内空间 9。小院和客厅沿用前一批样板；客厅另补齐两根窗帘杆的 UV。本轮不是新发布包，历史 Windows 成品仍保留原范围。

## 画面改动

- 在版本化 Blender 源文件中处理木材、布料、石材、土壤、纸张、陶器和金属的质感；已有贴图素材继续保留。室内木地板控制纹理尺度，阳台使用细缝铺砖。
- 对 243 个树冠网格加入分组枝叶轮廓，细化 270 处家具倒角，添加 897 处装饰，包括船舷与帆边、家具收边、柜门拉手、陶器口沿、鼓身金属件、车轮辐条、望远镜环带、岩层细线和木琴镶边。上述数量只统计本轮扩展的 42 个场景。
- 统一暖色环境光、主光与接触阴影。主岛保留分区阴影，修正铺装亮线；小院采用已验证的独立阴影设置。昼夜、天气仍由原环境系统控制。
- 主岛编辑 `alphabet_island_layout_v07_game.blend`，校园 v04、客厅 v04、门厅 v02，其余源路径见下表。131 份旧版 Blender、GLB 与预览的 SHA256 均与本轮开始前一致。

## 验证结果

[最终汇总](acceptance.json) · [资产检查](asset-report.json) · [通行汇总](route-report.json) · [保存后导出检查](saved-export-report.json)

44 个导出资产与运行资产逐一匹配；4,518 个受保护节点的层级、交互元数据、变换以及碰撞/地面三角形坐标保持一致。贴图均内嵌，使用纹理的网格具备 UV。主岛、客厅与 K 工坊另外重新打开已保存源文件，经常规导出器输出临时 GLB，对全部节点、每个网格的三角形坐标、变换和材质名称作比较，结果一致；磁盘源文件没有改写。主岛导出器已补齐曲线转网格步骤，室内导出器保留精修曲线的闭合接缝处理。

| 专项 | 检查项 | 实际行走 | 进出转换 | 结果 |
|---|---:|---:|---:|---|
| letters-A-M | 397 | 91 | 26 | PASS |
| letters-N-Z | 397 | 91 | 26 | PASS |
| campus | 352 | 56 | 16 | PASS |
| home | 942 | 62 | 20 | PASS |

合计 **2088 项通行检查、300 段实际行走、88 次进出转换**。字母场所覆盖 130 个固定点，校园覆盖 40 个固定点，家园覆盖 40 个固定点和 8 项家务。家园路线包含“主岛 → 小院 → 门厅 → 七个房间 → 返回”；字母门口使用实际 E 键派发。全部使用隔离存档，正式存档与备份保持一致。

[采苹果专项](orchard-integration.json)另外通过 53 项：实际走近、手部接触、苹果持有、放入篮子、暂停恢复、保存失败时的物件归属、重玩与发现记录。[昼夜/天气检查](living-world.log)通过 91 项，包含真实客厅、校园、教室的角色落点。本轮运行的是受影响路径的专项检查，没有运行发布用全量测试。

## 原生画面对照

修改前后各 88 张 Godot 原生 PNG，合计 176 张、88 组对照；每处包含默认游戏视角和全景复核视角。修改后六批共有 294 项捕获检查，全部通过。每组固定相机位置、方向、正交尺寸和晴天白昼。全景隐藏 HUD，仅用于美术复核，不能代表默认游玩视角。所有 44 处的游戏视角均已逐一查看，并在纹理和阴影修正后复查相关画面。

[图集静态校验](gallery-report.json)检查图片存在、PNG 尺寸、哈希、当前运行源哈希与同机位记录；JavaScript 通过 `node --check`。图集没有另行完成浏览器渲染验收，图片本身来自引擎。Blender 预览仅辅助源模型编辑，最终效果以这里的实拍为准。

## 本机性能采样

设备为 NVIDIA GeForce RTX 4070，Godot 4.7.2 Compatibility / OpenGL 3.3，1440 × 900。六处分别预热后采集 300 个实际绘制帧；窗口保持焦点，没有固定模拟帧参数，也没有其他 Godot/Blender 任务同时运行。原始数据见 [性能报告](performance-report.json)。

| 场景 | 渲染帧/秒 | 帧间隔 P95 / ms | 末帧绘制调用 |
|---|---:|---:|---:|
| 字母岛 | 217.8 | 5.18 | 2171 |
| 苹果果园屋 | 359.8 | 3.28 | 1285 |
| 山丘学园 | 278.9 | 4.03 | 1438 |
| 教室 | 410.9 | 2.83 | 703 |
| 客厅 | 416.2 | 2.87 | 839 |
| 家里 · 门厅与走廊 | 260.4 | 4.51 | 1807 |

这些数据来自晴天白昼、减少动态、默认出生点的短时静止采样，包含呈现节奏；不代表最低设备要求、连续移动或长时游玩的帧率保证。

## 当前源文件

下表的三个数字依次为材质处理对象、新增装饰、重做树冠；源文件、GLB、打包贴图和运行拷贝均保留在工程内。新增材质为本地产生的确定性纹理，未引入新的外部下载素材。

| 场景 | Blender 源文件 | 材质 / 装饰 / 树冠 | GLB / MiB |
|---|---|---:|---:|
| 字母岛 | [alphabet_island_layout_v07_game.blend](../../../assets/blender/alphabet_island/alphabet_island_layout_v07_game.blend) | 776 / 0 / 157 | 136.80 |
| 苹果果园屋 | [landmark_A_v02.blend](../../../assets/blender/interiors/landmark_A/landmark_A_v02.blend) | 382 / 0 / 20 | 18.28 |
| 船屋码头 | [landmark_B_v02.blend](../../../assets/blender/interiors/landmark_B/landmark_B_v02.blend) | 63 / 4 / 0 | 3.54 |
| 蛋糕烘焙坊 | [landmark_C_v02.blend](../../../assets/blender/interiors/landmark_C/landmark_C_v02.blend) | 197 / 36 / 0 | 7.23 |
| 鼓屋音乐厅 | [landmark_D_v02.blend](../../../assets/blender/interiors/landmark_D/landmark_D_v02.blend) | 197 / 21 / 0 | 7.48 |
| 蛋壳孵化屋 | [landmark_E_v02.blend](../../../assets/blender/interiors/landmark_E/landmark_E_v02.blend) | 147 / 33 / 0 | 5.02 |
| 巨花温室 | [landmark_F_v02.blend](../../../assets/blender/interiors/landmark_F/landmark_F_v02.blend) | 433 / 31 / 0 | 6.94 |
| 地球仪旅行馆 | [landmark_G_v02.blend](../../../assets/blender/interiors/landmark_G/landmark_G_v02.blend) | 166 / 23 / 0 | 4.78 |
| 帽子裁缝店 | [landmark_H_v02.blend](../../../assets/blender/interiors/landmark_H/landmark_H_v02.blend) | 169 / 26 / 0 | 4.84 |
| 冰淇淋驿亭 | [landmark_I_v02.blend](../../../assets/blender/interiors/landmark_I/landmark_I_v02.blend) | 88 / 14 / 0 | 3.58 |
| 玻璃罐收藏馆 | [landmark_J_v02.blend](../../../assets/blender/interiors/landmark_J/landmark_J_v02.blend) | 299 / 30 / 0 | 6.28 |
| 风筝工坊 | [landmark_K_v02.blend](../../../assets/blender/interiors/landmark_K/landmark_K_v02.blend) | 92 / 7 / 0 | 4.03 |
| 灯笼驿站 | [landmark_L_v02.blend](../../../assets/blender/interiors/landmark_L/landmark_L_v02.blend) | 214 / 27 / 0 | 6.55 |
| 蘑菇邻居屋 | [landmark_M_v02.blend](../../../assets/blender/interiors/landmark_M/landmark_M_v02.blend) | 184 / 33 / 0 | 5.81 |
| 鸟巢观察屋 | [landmark_N_v02.blend](../../../assets/blender/interiors/landmark_N/landmark_N_v02.blend) | 187 / 3 / 8 | 6.25 |
| 猫头鹰图书馆 | [landmark_O_v02.blend](../../../assets/blender/interiors/landmark_O/landmark_O_v02.blend) | 165 / 29 / 0 | 6.63 |
| 南瓜农场屋 | [landmark_P_v02.blend](../../../assets/blender/interiors/landmark_P/landmark_P_v02.blend) | 195 / 10 / 0 | 4.87 |
| 拼布故事馆 | [landmark_Q_v02.blend](../../../assets/blender/interiors/landmark_Q/landmark_Q_v02.blend) | 274 / 57 / 0 | 9.14 |
| 机器人工坊 | [landmark_R_v02.blend](../../../assets/blender/interiors/landmark_R/landmark_R_v02.blend) | 193 / 34 / 0 | 5.67 |
| 星形天文台 | [landmark_S_v02.blend](../../../assets/blender/interiors/landmark_S/landmark_S_v02.blend) | 153 / 5 / 0 | 3.29 |
| 火车车站 | [landmark_T_v02.blend](../../../assets/blender/interiors/landmark_T/landmark_T_v02.blend) | 78 / 23 / 0 | 4.99 |
| 雨伞气象屋 | [landmark_U_v02.blend](../../../assets/blender/interiors/landmark_U/landmark_U_v02.blend) | 277 / 12 / 0 | 5.33 |
| 休眠火山观察站 | [landmark_V_v02.blend](../../../assets/blender/interiors/landmark_V/landmark_V_v02.blend) | 74 / 3 / 0 | 4.54 |
| 鲸鱼海洋馆 | [landmark_W_v02.blend](../../../assets/blender/interiors/landmark_W/landmark_W_v02.blend) | 118 / 24 / 0 | 3.88 |
| 木琴海边舞台 | [landmark_X_v02.blend](../../../assets/blender/interiors/landmark_X/landmark_X_v02.blend) | 100 / 10 / 0 | 6.14 |
| 毛线手作屋 | [landmark_Y_v02.blend](../../../assets/blender/interiors/landmark_Y/landmark_Y_v02.blend) | 411 / 24 / 0 | 10.24 |
| 斑马邮局 | [landmark_Z_v02.blend](../../../assets/blender/interiors/landmark_Z/landmark_Z_v02.blend) | 296 / 23 / 0 | 7.55 |
| 山丘学园 | [school_v04.blend](../../../assets/blender/interiors/school/school_v04.blend) | 419 / 7 / 54 | 14.54 |
| 教室 | [classroom_v02.blend](../../../assets/blender/interiors/classroom/classroom_v02.blend) | 165 / 34 / 0 | 7.24 |
| 音乐教室 | [music_room_v02.blend](../../../assets/blender/interiors/music_room/music_room_v02.blend) | 213 / 23 / 0 | 7.52 |
| 美术教室 | [art_room_v02.blend](../../../assets/blender/interiors/art_room/art_room_v02.blend) | 182 / 30 / 0 | 6.06 |
| 科学教室 | [science_room_v02.blend](../../../assets/blender/interiors/science_room/science_room_v02.blend) | 208 / 34 / 0 | 7.51 |
| 食堂 | [canteen_v02.blend](../../../assets/blender/interiors/canteen/canteen_v02.blend) | 155 / 39 / 0 | 6.96 |
| 操场 | [playground_v02.blend](../../../assets/blender/interiors/playground/playground_v02.blend) | 38 / 1 / 4 | 4.34 |
| 校园足球场 | [football_field_v02.blend](../../../assets/blender/interiors/football_field/football_field_v02.blend) | 223 / 3 / 0 | 6.36 |
| 客厅 | [home_v04.blend](../../../assets/blender/interiors/home/home_v04.blend) | 保留样板；补齐窗帘杆 UV | 6.77 |
| 家务阳台 | [home_balcony_v02.blend](../../../assets/blender/interiors/home_balcony/home_balcony_v02.blend) | 123 / 10 / 0 | 3.61 |
| 清爽浴室 | [home_bathroom_v02.blend](../../../assets/blender/interiors/home_bathroom/home_bathroom_v02.blend) | 102 / 37 / 0 | 5.71 |
| 温暖卧室 | [home_bedroom_v02.blend](../../../assets/blender/interiors/home_bedroom/home_bedroom_v02.blend) | 116 / 27 / 0 | 3.95 |
| 家庭餐厅 | [home_dining_v02.blend](../../../assets/blender/interiors/home_dining/home_dining_v02.blend) | 182 / 33 / 0 | 4.85 |
| 家园院落 | [home_estate_v03.blend](../../../assets/blender/interiors/home_estate/home_estate_v03.blend) | 保留已完成的小院样板 | 23.96 |
| 家里 · 门厅与走廊 | [home_hall_v02.blend](../../../assets/blender/interiors/home_hall/home_hall_v02.blend) | 461 / 10 / 0 | 10.10 |
| 明亮厨房 | [home_kitchen_v02.blend](../../../assets/blender/interiors/home_kitchen/home_kitchen_v02.blend) | 171 / 33 / 0 | 6.06 |
| 窗边书房 | [home_study_v02.blend](../../../assets/blender/interiors/home_study/home_study_v02.blend) | 124 / 34 / 0 | 4.19 |

## 重现入口

```powershell
python -X utf8 scripts/verify_world_refinement.py
python -X utf8 scripts/run_world_routes.py
python -X utf8 scripts/run_world_capture.py after
python -X utf8 scripts/build_world_refinement_gallery.py
```

`docs/planning/world-refinement/baseline.json` 为不可覆盖的修改前清单；重新生成材质只写新版工作文件。日常室内编辑继续使用原 pipeline 导出，主岛同步脚本从清单读取当前版本。运行验证先完成 Godot 导入，性能采样单独执行。
