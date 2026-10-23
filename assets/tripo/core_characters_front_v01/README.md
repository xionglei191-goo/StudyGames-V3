# 字母岛 · 12 个核心角色正面参考图 v01

生成日期：2026-10-23。用于下一步由你上传 Tripo 生成角色 3D 模型。

## 使用方法

1. 从本文件夹选取对应角色的独立 `*_front.png`，每次上传一个角色。
2. `preview/overview.png` 是 12 人总览，只用于看画风和对照名字。
3. 生成后的 3D 模型按下表角色 ID 保存，便于后续替换游戏中的临时模型。

图片均为白色背景、完整角色正面、无文字。站立角色双臂略向外展开；Jim 保留轮椅坐姿。角色图保留内置图像生成工具输出的原始 PNG 文件，未重新压缩或裁切。

## 文件与角色

| 编号 | 角色 | 游戏角色 ID | 独立图片 |
|---|---|---|---|
| 01 | 玩家 · 小岛旅人 | `player` | [01_player_front.png](01_player_front.png) |
| 02 | Lingling | `textbook_lingling` | [02_lingling_front.png](02_lingling_front.png) |
| 03 | Peter | `textbook_peter` | [03_peter_front.png](03_peter_front.png) |
| 04 | Anne | `textbook_anne` | [04_anne_front.png](04_anne_front.png) |
| 05 | Mingming | `textbook_mingming` | [05_mingming_front.png](05_mingming_front.png) |
| 06 | Dongdong | `textbook_dongdong` | [06_dongdong_front.png](06_dongdong_front.png) |
| 07 | Tim | `textbook_tim` | [07_tim_front.png](07_tim_front.png) |
| 08 | Miss Li | `textbook_miss_li` | [08_miss_li_front.png](08_miss_li_front.png) |
| 09 | Dino | `textbook_dino` | [09_dino_front.png](09_dino_front.png) |
| 10 | 熊叔 | `npc_bear_uncle` | [10_bear_uncle_front.png](10_bear_uncle_front.png) |
| 11 | 兔兔 | `npc_rabbit_gardener` | [11_rabbit_gardener_front.png](11_rabbit_gardener_front.png) |
| 12 | Jim | `textbook_jim` | [12_jim_front.png](12_jim_front.png) |

## 设计依据

- 统一为圆润、柔和、带体积感的童话游戏角色画风；Lingling 是整套图片的画风参照。
- Lingling、Peter、Anne、Mingming、Dongdong、Tim、Miss Li 和 Dino 的主要身份特征、发型与服装配色来自项目关联的湘少版教材参考页。
- 玩家、熊叔、兔兔和 Jim 结合已有游戏角色参考重新呈现。Jim 使用现有游戏中的奶油色与灰蓝色配色，并调整为长裤，是游戏设计版本。
- 球、风筝、书本、浇水壶等手持物未放入人物图，以便看清角色本体。
- Jim 图中包含人物与完整轮椅，双手自然位于腿前。若后续需要独立驱动人物、车轮和扶手，应在模型阶段拆分和检查这些部件。
- Dino 已完整展示两只翅膀和侧弯尾巴，后续模型仍需检查背部连接和活动空间。

## 包内记录

- `manifest.json`：图片尺寸、文件哈希、角色 ID、参考来源和目视检查记录。
- `generation-plan.json`：完整提示词、共同画风约束和参考路径。
- `generation-records.json`：内置图像生成工具的输出记录。
- `preview/overview.png`：对照总览，缩略图大小不代表角色真实身高。

本次交付阶段为“正面参考图已生成并检查”。3D 生成、拓扑整理、骨骼绑定、动画与 Godot 导入验收在后续模型阶段进行。

