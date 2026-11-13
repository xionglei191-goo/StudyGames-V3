# Tripo 剩余 70 个名额的素材筛选

2026-11-12。已对照 34 位建筑居民、12 位核心角色，检查全部 139 张新增人物参考图与 24 张道具图。

建议先生成 **48 个：32 个角色 + 16 件道具、家具与配饰**；另列 **12 个条件候选：8 个角色 + 4 件物品**，保留 **10 个名额**用于补缺或返工。48 项优先清单面向后续教材章节和游戏美术扩充，章节配戏仍以现有策划状态为准。

## 交付入口

- [带图片、可搜索的筛选页](../../assets/tripo/generation_selection_20261112/index.html)
- [48 个优先素材 ZIP](../../assets/tripo/generation_selection_20261112/01_priority_48.zip)
- [12 个条件候选 ZIP](../../assets/tripo/generation_selection_20261112/02_optional_12.zip)
- [全部 163 项决定与复用建议](../../assets/tripo/generation_selection_20261112/selection.csv)
- [完整说明及推荐 GLB 名称](../../assets/tripo/generation_selection_20261112/README.md)
- [32 个角色总览](../../assets/tripo/generation_selection_20261112/preview/priority_characters.jpg) · [16 件物品总览](../../assets/tripo/generation_selection_20261112/preview/priority_props.jpg)

两个 ZIP 均包含独立原图、命名表和选取理由；原图字节保持不变，模型名称沿用已有资产 ID。既有 34 位居民的独立设计继续保留。

## 主要取舍

| 范围 | 优先 | 条件候选 | 复用/本地制作建议 | 保留图片暂缓 |
|---|---:|---:|---:|---:|
| 新增角色 | 32 | 8 | 80 | 19 |
| 物品 | 16 | 4 | 4 | 0 |
| 合计 | 48 | 12 | 84 | 19 |

优先角色补齐职业制服、家庭与儿童基础造型、自然四足宠物、象、鱼、鸟、鹦鹉、年兽、机器人和有明显服装差异的故事角色。物品优先选常驻家具、具有立体纹理的拾取物及能给多个人物使用的帽子、书包。

Lily/Lucy 先生成一个；Kathy/Kent/Karen 三只幼犬先生成一个；六只大小比较鸟先生成 Baker，再调整大小、羽色与局部羽形。Doggie 可作为其他相近四足犬的改装起点。重复的普通同学、教师和家长逐项注明可参考的基础身体和服装改动。

共用网格或骨架时，人物 ID、姓名、对白、比较数据和来源记录继续分别保存。复用建议尚未执行；衣服与头发若和身体合并，仍可能需要拆分或局部重建。中高工作量项在具体场景要求严格还原时，可以使用保留名额独立生成。拟人动物与自然四足动物、成人与儿童比例分别处理。

身份核对：Mr Wang 是环卫工人，Miss Lin 是车站服务员，Li Jie 是兽医，Mr Chen 是交警；幼年张衡使用儿童形象。

## 已有模型与检查

`assets/tripo/building_residents_v01/` 中找到 34 个 GLB；项目还保留原有 12 个核心角色 GLB。34 份新文件哈希各不相同，全部通过 GLB 2.0 容器长度、JSON/BIN 分块及网格记录检查。UUID 文件名尚未逐个与居民身份和参考图匹配，此次筛选以用户报告的完成状态和居民参考设计为基础。

- 163 项决定、ID、图片路径及所有复用目标已核对。
- 60 张打包 PNG 可解码，复制后及 ZIP 内文件 SHA-256 均与原图相同；两个 ZIP 完整性通过。
- 浏览页 163 张缩略图全部加载；五类决定与角色/物品组合计数通过，ID 搜索、空结果和 Lucy→Lily 对应通过。
- 331 个本地链接存在；1440×960 与 390×844 页面无横向溢出、无 JavaScript 错误，桌面与手机截图已复看。
- 没有调用 Tripo、消耗生成名额、修改既有模型、执行换色改模或更改游戏运行代码。

证据：[图片与 ZIP 检查](../../assets/tripo/generation_selection_20261112/delivery-checks.json)、[浏览页检查](../../assets/tripo/generation_selection_20261112/gallery-checks.json)、[模型文件盘点](../../assets/tripo/generation_selection_20261112/existing-model-inventory.json)。

参考：原人物和道具 manifest、建筑居民 manifest、`docs/planning/art/textbook_characters.json`、`docs/planning/mainline/curriculum_arcs.json`、`game/actors/modular_wardrobe.gd`、`game/gameplay/free_grid_decor_studio.gd`。
