# 字母岛 · 绘本角色 v3

本组把当前游戏中实际使用的 12 个角色替换为可编辑的 Blender 网格和真实蒙皮：玩家、熊叔、兔兔、Lingling、Peter、Anne、Mingming、Dongdong、Tim、Dino、Miss Li、Jim。教材角色沿用工程已核对的身份、发型与服装配色记录；Jim 继续使用原先记录的中性服装配色，不把它称为教材服装颜色的最终复原。

## 形象与动作

采用暖色绘本玩偶的圆润比例，奶油色、草木绿、陶土色与低饱和服装。网格包含衣领、口袋、缝边、鞋底、鞋带、发型和面部细节。玩家背带服保留黄、粉、蓝三色换装，衬衣、扣子和背包不会跟着整身染色。

角色使用 11 根现有动作骨；Dino 增加尾巴和两翼，共 14 根。肘部、膝部与人形腰部含平滑混合权重。`Blink` 用于眨眼，`Smile` 用于招手与合影，`Talk` 用于说话动作中的小幅口型；它们是动作表情，不是对录音逐音素同步的口型。减少动态会关闭眨眼和循环口型，暂停时表情与动作一起停留。

Jim 的模型按原有坐姿骨架制作，轮椅包含扶手、脚踏、轮圈、辐条与前轮；继续拒绝站立、普通行走和低处拾取。模型替换不改变原动作库、手部挂点、接触时刻或语义回执规则。

## 可编辑来源与复现

- `storybook_characters_v3.blend`：分角色集合、Armature、顶点组、UV、材质与表情形态键。
- 每个角色的 `.glb`：用于 DCC 交换，保留蒙皮和表情；默认表情值为 0。
- `source/*.json`：Blender 导出的坐标、法线、UV、颜色、骨权重和表情源数据，仅用于离线构建。
- `manifest.json`：角色清单、几何预算、生成脚本哈希与来源说明。
- `../../../scripts/build_character_art_v3.py`：项目原创的可复现 Blender 建模脚本，不依赖外部商业模型库。
- `../../../game/actors/bake_character_art_v3.gd`：将源数据转换为 Godot 压缩 `.res`。运行目录仅携带这些资源和精简清单，不携带约 100 MB 的制作中间数据。

先用项目 Blender 执行 `--background --factory-startup --python scripts/build_character_art_v3.py`，再用 Godot 执行 `--headless --path game --script res://actors/bake_character_art_v3.gd -- --test-harness --bake-character-art`。不要通过修改现有 P1 动作关键帧来补偿造型问题。

运行时由 `game/actors/character_art_v3.gd` 将模型绑定到原骨架；玩家、NPC、对话肖像和衣橱预览共用本组模型。旧的程序几何身体不再作为正常渲染路径。原始地图、已确认的 26 字母插图、10 张故事道具、历史发布包和历史验收图继续保留。

## 验收边界

技术检查和原生画面复核见 [本轮记录](../../../docs/verification/art-finish-v3/README.md)。检查覆盖真实权重、骨骼与网格变形、表情数据、旧接触行为、实际取放、衣橱和多种画面尺寸。模型清单中的身份数量不等于课程登记的 144 条来源身份记录全部制作完成；也不代表儿童试玩、全设备性能或全部课程完成。
