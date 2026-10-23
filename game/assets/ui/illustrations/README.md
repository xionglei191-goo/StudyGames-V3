# UI 插画共享清单

16 个 UI 插画入口使用共享的真实 PNG。其中 11 个引用本轮新增图、5 个引用已验收 v2 图；这些是资源副本和引用，**不增加 182 张新增生成图的数量**。`science_flask` 仅在 UI 科学入口使用，没有课程故事见证步骤。

| 图标 ID | 用途 | 本目录运行文件 | 共享道具 ID | 原始运行资源 |
|---|---|---|---|---|
| `apple` | 苹果/学习 | `apple.png` | `apple` | `res://assets/learning/storybook_v2/A.png` |
| `cake` | 烘焙 | `cake.png` | `cake` | `res://assets/learning/storybook_v2/C.png` |
| `bag` | 背包 | `bag.png` | `backpack` | `res://assets/learning/story_props_v3/backpack.png` |
| `journal` | 旅行册 | `journal.png` | `travel_journal` | `res://assets/learning/story_props_v3/travel_journal.png` |
| `flower_box` | 园艺 | `flower_box.png` | `flower_box` | `res://assets/learning/story_props_v3/flower_box.png` |
| `home` | 家 | `home.png` | `cottage` | `res://assets/learning/story_props_v3/cottage.png` |
| `map` | 地图 | `map.png` | `folded_map` | `res://assets/learning/story_props_v3/folded_map.png` |
| `picnic` | 野餐 | `picnic.png` | `picnic_basket` | `res://assets/learning/story_props_v3/picnic_basket.png` |
| `science` | 科学 | `science.png` | `science_flask` | `res://assets/learning/story_props_v3/science_flask.png` |
| `art` | 美术 | `art.png` | `paint_palette` | `res://assets/learning/story_props_v3/paint_palette.png` |
| `music` | 音乐 | `music.png` | `xylophone` | `res://assets/learning/storybook_v2/X.png` |
| `outfit` | 衣橱 | `outfit.png` | `shirt` | `res://assets/learning/story_props_v3/shirt.png` |
| `sun` | 白天 | `sun.png` | `sun` | `res://assets/learning/story_props_v3/sun.png` |
| `leaf` | 叶币/叶子 | `leaf.png` | `leaf` | `res://assets/learning/story_props_v3/leaf.png` |
| `lamp` | 灯光 | `lamp.png` | `lantern` | `res://assets/learning/storybook_v2/L.png` |
| `football` | 足球 | `football.png` | `football` | `res://assets/learning/storybook_v2/props/football.png` |

每个本目录 PNG 均为共享来源的字节一致副本，SHA 和 alpha 区域见 `manifest.json`。`island_theme.gd` 的 `icon_asset_path()` 选择 PNG，`icon()` 从原图的有效区域生成 96×96 运行时缩略纹理并记录 `source_art_path`；不会回写图像文件。

关闭、勾选、方向箭头、设置、扬声器等功能符号继续使用既有 SVG，保持其小尺寸辨识度。插画替换不改变导航、按钮输入或学习状态。

原生验证见 `../../../../docs/verification/art-finish-v3/story-prop-assets-v3.json`：16 个插画 ID 均验证真实 PNG 路径、96×96 返回纹理和来源元数据，5 个功能符号验证 SVG。实际 HUD、地图和衣橱还由两种窗口尺寸的 gameplay 报告和截图验证。

本目录 manifest 与驱动在最终验证前冻结；验收状态和 SHA 统一记录于 `../../../../assets/art/story_props_v3/validation.json`。
