# 八册单词策划协作约定

日期：2026-10-22。产物均为策划稿，禁止改动游戏、教材源库、模型或发布产物。

2026-10-23补充：用户要求全库故事更通顺并完整扩展。教材与原作者字段继续作为来源底稿；当前叙事正文以 `authoring/narrative_v2/output_*.json` 为扩写输入，规范见该目录 `CONTRACT.md`。每条beats对应原字母位置，由构建器统一更新正文、steps、frames、意义桥及帮助提示，不能把旧g*.json短动作当作最新朗读稿。启用标记要求全部核心与补充义项齐备，缺稿时构建失败，不静默退回旧故事。

已归档扩写前的完整策划包。entry/lexeme/story/sense-scene ID、词义与存放位置保持；content_revision随文案更新。阅读入口是各册cards和《故事扩写对照》，源底稿与归档仅供追溯。自动结构核验和助手语义抽查分开记录，人工编辑与儿童试用仍待完成。

相同词义的重复记录经 `authoring/narrative_v2/reuse_aliases.json` 指向同一正文，再统一生成 `data/catalog.json`。`root_review_batch*.json` 是抽读时的稿件快照，可能保留已修正句子；`partial_structural_review.json` 只记录过程中已完成的部分。最终正文与核验结论以构建后的cards、catalog和review/narrative_validation.json为准。

## 范围与证据

逐册覆盖正式 `Vocabulary` / `Word List` / `Word List I` / `Word List II` 的并集。按单元的表与按字母的表相互对账。正式表中的黑体与蓝体/星号词均收录，保留教材要求等级；不把课文任意英文碎片自动升级为词条。人名、专名、词组、缩略形式独立标记。表外内容只记范围目录，不声称已做全书所有语句。

所有正式词表页必须看实际页面图；JSON 的 `sourceVerified` / `reviewed` 只保存原值，不等于本次人工复核。每条保留印刷页、文件页、region_ids、图片路径、表内引用的课文页以及原始表面形式。合并区域可由多条共享，并用 `row_label` 定位。源 OCR 错误在本目录修正，不回写源库。

## 作者交付格式

各年级只写 `authoring/g{grade}.json` 和需要的 `authoring/g{grade}-notes.md` / 辅助脚本。JSON 顶层：

```json
{
  "grade": 3,
  "books": [
    {
      "book_id": "xiangshao-g3-1",
      "visual_reviewed_file_pages": [73,74,75,76,77,78,79],
      "entries": [
        {
          "spelling": "nose",
          "meaning_zh": "鼻子",
          "kind": "word",
          "requirement": "listen_speak_read_write",
          "sources": [{"file_page": 77,"region_ids": ["p77-r1"],"row_label": "nose 鼻子","listed_lesson_page": 31,"section": "Word List"}],
          "unit_numbers": [6],
          "surface_group": "nose",
          "variant_relation": null,
          "notes": ""
        }
      ],
      "exclusions": [],
      "corrections": []
    }
  ],
  "stories": {
    "nose": {
      "meaning_anchor": "猫头鹰的大鼻子闻一闻后打喷嚏，明确指出鼻子。",
      "setting": "家中镜子旁",
      "actions": ["摇出一只猫头鹰", "用大鼻子顶起星星", "被喷嚏吹进蛋壳", "接住星星，壳上留下鼻子印"],
      "transfer": "为新玩偶洗脸时听 nose 指出鼻子，和 mouth、ear 区分。",
      "contrast": "四个字母；没有把 /z/ 的读音写成 z。"
    }
  }
}
```

`actions` 必须与拼写中 ASCII 字母数量严格一致。第 i 项的执行者自动绑定第 i 个字母的固定形象；动作文字不要重新指定不同主角。每一步与前后相连，围绕本词的具体含义，不使用全表同一句“传球/举牌/照亮”的空泛替换。允许自然地让下一个形象接力，也允许全链共同操作清楚的意义物体。长词逐字母分镜，空格和标点由总编自动插入独立事件。`transfer` 必须是新情境中使用目标义项的可操作任务；功能词用明确指代、数量、关系或语言动作情境。专名不伪造词义。

同一作者两个册子的同拼写复用同一个故事；不同义项可以在同一核心故事中添加可辨的意义分支，记录在 `sense_extensions`，不得随册随机重置。跨年级重复将由总编按首次出现的故事统一。

括号变体如 `mother (mum)` 拆成 mother 与 mum 两个拼写目标，保留共同 `surface_group`。等式如 `I'm=I am` 拆成 `I'm` 与 `I am`，并注明 contraction / expansion 关系；等号和括号是表的说明符，不进拼写。大小写保留；印刷弯撇号规范为 ASCII `'` 并记录。书名地名与人名按专名标记。拼写不按词根或构词法拆解。

`requirement` 可取 `listen_speak_read_write`（听说读写）、`recognition`（认读）、`listen_speak_read`（听说认读）、`listen_speak`（仅听说）、`not_distinguished`（未区分）。旧作者稿的 `listen_speak_recognize` 仅作为输入别名，发布时规范为 `listen_speak_read`。不确定时不猜，写 notes。`kind` 发布值包含 word / phrase / contraction / proper_name / abbreviation / notation / pattern；如果后续新增 letter_name，应先补规范和核验，不把字段名当现有实例数。

教学要求属于每一册内 occurrence，不属于整个 lexeme 或跨册故事。当前共708条听说读写、358条认读、146条听说认读、102条仅听说。仅听说不自动升级为认读；后三类都不能因为有逐字母故事而升级为强制拼写。所有故事可跳过，四会词的拼写练习也不控制章节通行。允许的观察维度及提示证据见 `data/integration_contract.json.requirement_permissions`。

## 固定地标

A 苹果 Apple；B 小船 Boat；C 蛋糕 Cake；D 鼓 Drum；E 蛋壳 Egg；F 花朵 Flower；G 地球仪 Globe；H 帽子 Hat；I 冰淇淋 Ice cream；J 罐子 Jar；K 风筝 Kite；L 灯笼 Lantern；M 蘑菇 Mushroom；N 鸟巢 Nest；O 猫头鹰 Owl；P 南瓜 Pumpkin；Q 拼布被 Quilt；R 机器人 Robot；S 星星 Star；T 火车 Train；U 雨伞 Umbrella；V 火山 Volcano；W 鲸鱼 Whale；X 木琴 Xylophone；Y 毛线 Yarn；Z 斑马 Zebra。

重复字母使用同地标的第几次出现实例，不换映射。字母形象是想象里的缩影，不要求跑完所有地标；故事存放位置独立且稳定。

E 的英文地标名仍为 Egg；教材词义标签为“鸡蛋”，固定代表物为“蛋壳（完整蛋形）”。既有 `anchor_zh=蛋壳` 保留兼容，不把 Egg 释为碎壳，也不改变已有字母故事。26个序章入口来自 `alphabet_prologue.json` 的真实 `scene_ref.learning_node`，只用于认识代表物；完整词故事的 `storage_slot` 是回忆册内容索引，不是新建的 SG_MEMORY 节点。作者 `setting` 是故事画面/位置建议，不构成新增地图场所或物理坐标。

## 与主线和美术的发布接口

作者稿继续维护原条目、动作及来源；总编脚本生成 `data/catalog.json`（schema_version=2）和 `data/mainline_entries.json` 适配表。稳定 `entry_id` 取册内 `occurrences.id`，`lexeme_id` 取拼写ID，`sense_id=story_id` 取核心故事页ID。不得把规范化中文 `sense_key` 当跨版本稳定ID。`unit_ids` 由 `unit_numbers` 对真实教材 chapter ID 校验；一条可属于多个单元，调用必须选其中一个，不能由词表 `sources.chapter_id` 推断教学单元。

主线引用 `content_revision` 与 `codebook_revision`，只保存引用和真实行为；不复制改写原故事。补充义项使用 `sense-scene-*` 和 `ref_letter_positions`，不把补充镜头重复计为新的字母位置。H0–H5六级依次为自主、位置与意义、第一步、缺口接续、逐步搭桥、完整示范；等级表示提供什么，不表示学会程度。主动打开历史故事也记录线索，H0不能自动判为独立。

首版默认用图卡/分镜，26种固定形象资源复用，重复字母是独立槽位实例。每镜最多4个活动形象、每可见分组最多5张故事页；它们是待试玩的预算，不是性能保证。长词可以静态展开全串，不要求25个蒙皮角色同时表演。夸张动作属于助记想象，不得当作真实动物结构、地理历史或教材人物经历；R的通用机器人不自动绑定Robbie，恐龙模型不自动绑定Dino。具名NPC、实义/地理素材和故事专用例外均须单独审校。

## 审核边界

自动检查 / 本次智能助手页面核对 / 独立编辑人工复核 / 儿童试用分开记录。后两项始终待完成，除非获得真实证据。现成源库语音与游戏已接入语音分开；不得生成语音或宣称已全部接入。
