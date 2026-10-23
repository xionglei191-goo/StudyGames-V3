# 五年级两册词汇编写与核对记录

日期：2026-10-22。主稿是 `g5.json`，仅供内容策划整合，没有修改游戏、教材源库或语音。

## 范围和数量

| 册别 | 正式词表范围（印刷页 / 文件页） | 原始表面行并集 | 拆开明确变体后的拼写目标 | 普通单词 | 词组 | 缩略形式 | 专名/月份/称呼 |
|---|---|---:|---:|---:|---:|---:|---:|
| 五上 | Vocabulary 68–70 / 75–77；Word List 71–74 / 78–81 | 212 | 218 | 185 | 29 | 1 | 3 |
| 五下 | Word List I 67–69 / 74–76；Word List II 70–73 / 77–80 | 182 | 184 | 144 | 19 | 2 | 19 |

这里的“普通单词/词组/专名”按互斥 `kind` 分组，专名词组（如 the Spring Festival）只列在专名类，不会再计入词组类。`Indian` 作为国家派生词放在专名相关类，`Mrs` 为称呼；都不伪造成普通物品词。

两册合计 402 个册内拼写目标，377 个唯一拼写，25 个重复拼写使用同一故事键。全套有 2,223 条逐字母动作，逐条与字母数量核对一致。重音字母 `é` 算一个字母，映射 E；标点和空格由总编单列事件。

跨册复现：Mrs、active、ask、email、fan、find、floor、idea、information、kind、laugh、listen to、need、next、question、serious、shop、show、talk about、tell、think、try、win、work、year。

五上 107 个目标是听说读写，111 个是认读。五下 105 个目标是听说认读，79 个只要求听说。五下书页并没有要求这里全部词条都默写，策划不能用一律拼写考试替代教材等级。逐字母故事可作为自愿、有支持的记忆材料；目标等级需保留。

## 词条和来源规则

实际逐页查看了两册共 14 张正式词表图。按单元表与字母表互相对账，字母表黑体、蓝体/白体均收录。表外任意英文碎片没有加入。各词条保留印刷页、文件页、图片、原 region ID、其原始文本与 `sourceVerified/reviewed` 值；这些值不能替代本次页面核对，更不代表独立编辑的人工审核。

`chip (pl. chips)`、`glass (pl. glasses)`、`regard (pl. regards)`、`shoe (pl. shoes)`、`sock (pl. socks)`各拆两个完整拼写目标，原表面行用 `surface_group` 相连。`I'd like=I would like`、`don't=do not`、`I'll=I will`也分别展开，不把等号当字母。括号中的 `pl.` 是元信息，不收成词。

每个同词条的来源可能包含单元词表和字母词表两处；页内存在合并区域时，多个词共享同一 region，需结合 `row_label` 定位。`unit_numbers` 保留单元表归属与字母表引用单元的并集，不能把两个来源误算成两个新词。

## 纠错与待复核处

- 五下印刷70 / 文件77：原 JSON `p77-r45` 为 `door`，实际印刷是 `floor`，已按页面修正并保留原 region 原文。`door` 不增列为本页词汇。
- 五下实际页面有但 JSON 无独立行的 6 个词：fifth（文件77）、inn/life（文件78）、tell/try/win（文件80）。这些条目使用 `image_only_row=true`，region_ids 为空，保留准确页图与行标签；未捏造 region ID。
- 五下 a box of、a piece of、bus stop、on time、over there、shopping centre、put on、get on 在 OCR 中被切散或缺一个片段，已按同一印刷行恢复；不能将 box of、there 等碎片另计成正式词。
- 五下 was/were 释义中的 are/is/am 为语法说明。`books[].exclusions` 对文件76的 `p76-r29/p76-r34/p76-r36` 及文件80的 `p80-r12/p80-r21` 作了逐项说明。
- 五上 beef 的字母表印刷71页写课文页3，而 Vocabulary 把它放在 Unit 2。两份证据原样保留；该教材内部索引差异待独立编辑检查课文，未擅改为“正确页”。
- 五上 glass/glasses 原行并列“玻璃杯；眼镜”。glass 条只取玻璃杯，glasses 有眼镜与玻璃杯复数分支，避免把单数 glass 误释眼镜。
- café 的 é 原样保留；不可机械去掉重音后宣称准确拼写。印刷弯撇号在目标拼写中统一为 ASCII `'`，原 region 文本仍保存。

## 故事与义项

377 个故事均逐条编写具体动作；脚本只附来源、做数量与锚点检查，不用“所有角色依次举牌”等通用动作填满词库。每一动作的执行形象由总编按照该位置的字母绑定，保持顺序与重复字母的第几次出现。

各条提供明确存放位置和新情境使用任务。长词组例如 International Children's Day 逐字母保留 25 个动作，不改作词根/构词记忆。月份故事用对应月份格作意义目标，每个完整词仍按固定字母序列记忆。源内容中的 country、month、title 大小写保留。

fan（迷/扇子）、take（带往/乘）、glasses（眼镜/杯子复数）、email（发送/邮件）、visit（拜访/参观）、back（返回/回应）等使用 `sense_extensions`。分支保留同一个存放位置；每个分支有 `meaning_anchor`、`setting`、`transfer`，有新动作的分支也逐字母核验。不会为了新册随机重置同拼写的基础故事。

## 验证与边界

执行 `python -X utf8 docs/planning/vocabulary/authoring/g5-work/build_g5.py` 可重新生成 g5.json 并核验：册内无重复拼写、每词都有故事、逐字母动作数量、源 region 存在、印刷页与文件页对应。`g5-work/rows.tsv` 是逐页抄录稿，`stories.tsv` 是逐词原创分镜稿。

自动核验通过只证明结构和可追溯性；本次页面核对由智能助手完成。独立编辑人工复核和真实儿童试用均未完成，不宣称记忆效果已验证。没有制作或接入新语音；源库存在的语音是否为完整单词须另查，不能将合并区域朗读或既有18条语音说成完整词库音频。
