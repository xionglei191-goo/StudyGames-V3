# 八册教材完整正式词表与逐字母记忆策划

日期：2026-10-24。版本：v2-narrative。状态：可审阅策划稿，本版故事未做游戏验收。

全局规则入口：[GDD](../../../GDD.md)。内容权威仍是本目录的教材来源、词条与故事，GDD不替代教材事实。整合问题与修改证据见[整合核查与修订](整合核查与修订.md)。

八册正式 Vocabulary / Word List / Word List I / Word List II 的并集已形成 1314 条册内策划、1073 个不同拼写目标、1096 个固定核心意义故事页，另有 46 个固定补充义项镜头（50 次册内引用）。共 52 张正式词表页由智能助手实际查看；独立人工编辑与儿童试用仍待进行。

“完整”严格指本项目现有八册的正式词表并集，包括认读词、词组、专名、括号形式和缩略式展开；不指全书每句课文的所有拆分词、人名、附录图板或全部语言知识点均已游戏化。计数不等于孩子必须拼写的词数。仅听说、认读词保留教材原要求，不升级为强制拼写关卡。

| 册 | 词表文件页 | 表面形式组 | 册内目标／唯一拼写 | 既有拼写复用 | 新见拼写 |
|---|---|---:|---:|---:|---:|
| [三年级上册](books/g3-1.md) | 73, 74, 75, 76, 77, 78, 79 | 178 | 197／197 | 0 | 197 |
| [三年级下册](books/g3-2.md) | 73, 74, 75, 76, 77, 78, 79 | 156 | 158／158 | 12 | 146 |
| [四年级上册](books/g4-1.md) | 75, 76, 77, 78, 79, 80, 81 | 172 | 176／176 | 26 | 150 |
| [四年级下册](books/g4-2.md) | 75, 76, 77, 78, 79, 80, 81 | 168 | 172／172 | 29 | 143 |
| [五年级上册](books/g5-1.md) | 75, 76, 77, 78, 79, 80, 81 | 212 | 218／218 | 38 | 180 |
| [五年级下册](books/g5-2.md) | 74, 75, 76, 77, 78, 79, 80 | 182 | 184／184 | 69 | 115 |
| [六年级上册](books/g6-1.md) | 75, 76, 77, 78, 79, 80, 81 | 143 | 145／145 | 40 | 105 |
| [六年级下册](books/g6-2.md) | 77, 78, 79 | 64 | 64／64 | 27 | 37 |

## 阅读入口

- [记忆故事与想象引导规范](记忆故事与想象引导规范.md)：固定地标、重复字母、空格、撇号、连字符、大小写、长词与四类困难。
- [重点样例](重点样例.md)：nose、book、apple、school、football 和复杂书写边界。
- [完整故事扩写对照](故事扩写对照.md)：先读自然连贯的正文，再看原稿与逐字母绑定；全库核心和补充义项均有完整扩写。
- 各册目录 `books/*.md` 可点击进入对应 `cards/*.md` 的完整故事卡；各册 JSON 自带来源和完整提示。
- [全库 JSON](data/catalog.json)、[全部册内 CSV](data/all_occurrences.csv)、[跨册复用关系](data/cross_book_reuse.json)。
- [主线接入合同](data/integration_contract.json)、[1314条真实词条适配表](data/mainline_entries.json)、[整合静态核验](review/integration_validation.json)：保持原entry/lexeme/story身份、六级帮助、任务许可与完整字符。
- [验证报告](验证报告.md)、[自动核验 JSON](review/validation.json)、[逐页来源审计](review/source_pages.json)、[源文件保护核验](review/source_preservation.json)。
- [v2叙事结构核验](review/narrative_validation.json)、[导出与原身份核验](review/narrative_publication_validation.json)、[v2叙事语义抽查](review/narrative_editorial_review.md)、[版本映射](data/narrative_revision_map.json)。
- 首轮v1记录：[样例核验](review/acceptance_examples.json)、[三年级复核](authoring/g3-independent-review.md)、[长词与跨册复用复核](authoring/cross-grade-story-review.md)；它们保留旧版发现和处理，不作为v2新文案的复核结论。
- [教材范围与计数口径](教材范围与计数口径.md)明确版本、表外内容边界和词形展开规则。

## 实装边界

本次读取到 `game/project.godot` 版本 0.10.0-dev。原有课程数据文件记录三上前三单元的 9 道情境题、18 条表达及 18 条合成语音；这些旧课程计数不代表当前游戏全部学习内容。

现有学习包构建记录包含1314条词条，内容版本为`vocabulary-75cc8eb5b90ed004`。本策划内容版本为`vocabulary-30fd870dcb72ae38`；两者版本是否一致：否。该记录不是运行验收结果。 本次只修订本目录的策划、故事和适配数据，没有重新生成游戏学习包或执行本版故事的运行验收，不能据策划文件存在宣称新文案已可玩。

音频字段只列文字完全相同且文件存在的候选。原库有缓存不等于游戏已接入；候选未听检，其他条目明确待制作或改编，全部故事旁白待制作。没有儿童试用数据，没有记忆提升率或效果结论。

## 可复现核验

```powershell
python -X utf8 F:/LoveStudy/docs/planning/vocabulary/scripts/build_package.py
python -X utf8 F:/LoveStudy/docs/planning/vocabulary/scripts/verify_narrative_revision.py
```

脚本只读取原教材及当前课程证据，只在本目录写输出；不用运行游戏、Blender、导入课程或发布。作者稿与修复记录保留在 `authoring/`。正式接入前应完成人工编辑复核、音频制作与听检、儿童可用性试用及单独的开发验收。
