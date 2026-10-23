# 四年级两册词汇策划交付说明

日期：2026-10-22。作者核对为智能助手看图核对，独立编辑人工复核和真实儿童试用均待完成。所有内容为策划，未修改游戏、源教材、语音或模型。

## 口径与覆盖

读取 `D:/Project/Englishbook/public/books/xiangshao-g4-1.json`、`xiangshao-g4-2.json`，并实际查看两册文件页 75–81 的全部 14 张原页面图。每册文件 75–77 / 印刷 68–70 是按单元排列的 Vocabulary，文件 78–81 / 印刷 71–74 是按字母排列的 Word List。

按单元词表与按字母词表取并集。全部 Vocabulary 词条均已在 Word List 中找到；Word List 的黑体听说读写词与蓝体认读词都保留。源区域常把多行合并，条目以 `row_label`、页号和 `region_ids` 共同定位。`listed_lesson_page` 是词表列出的课文页，与该词表自身的 `page` / `file_page` 分开保存。

| 册次 | 正式印刷行 | 展开后的拼写目标 | 备注 |
|---|---:|---:|---|
| 四上 | 172 | 176 | can't/cannot、they're/they are、noodle/noodles、first/1st 各展开一项 |
| 四下 | 168 | 172 | where's/where is、No./number、leaf/leaves、fifth/5th 各展开一项 |
| 两册合计 | 340 | 348 | 其中9个拼写跨册复用，合并为339条故事 |

跨册重复的9项：Monday、fly、interesting、litter、on、read、river、village、where。同拼写使用同一核心故事与存放位置；litter 的“乱扔垃圾”和“垃圾”、fly 的“飞”和“放飞”保留义项分支，未当作同义混用。

Word List中 `has` 的释义含 `have`（四上 `p79-r5`），`does` 的释义含 `do`（四下 `p78-r10`）。这些是解释中的词，不另计新词表行；正式表中的 do 本身照常收录。字母分栏、表头、单元标题、页码不是目标。

## 逐字母内容

`g4.json` 包含339条不同拼写的原创行动分镜，共1873个基本字母动作，另有多义分支。每个动作逐位置对应A–Z固定地标。尤其 football 保留第2/3位的两个O、第7/8位的两个L；Wednesday保留读音不显著的D，英语完整读音另教。

每条故事含明确的意义画面、建议固定位置、具体逐字母动作与新情境使用任务。抽象词用范围、指代、先后、归属、完成动作、日历或证据关系呈现。星期的指定活动只属于当前剧情，不宣称“每周二必须做某事”；Sunday在示例采用周一开始的周历，遇到其他周历先说明版式。

`sense_extensions` 为 fish、home、fly、with、litter、be、make、park、do、way保留同场所的意义分支。单复数、序数数字形式、缩写展开分别有独立字母链，且有 `variant_relation` 连接。它们的目标数与原书印刷行数分开统计。

所有 story.setting 都是独立故事的“位置方案”。总编整合时应分配稳定slot_id和可扩容子位置，避免几百个词随机挤在一个家具点上；原地图26地标不移动。孩子动作、提示梯度、重复次数及标点独立事件由总编统一字段展开。

## 保留与纠错

- 四上 `p80-r10` 的OCR `o f` 看图确认为 `of`；仅修本策划。
- 词表 `noodle (pl. noodles)` 与 `leaf (pl. leaves)` 的 `pl.` 是复数说明，不进入字母链；复数本身独立保留。
- first(1st)、fifth(5th)的数字形式 `kind=notation`；数字原样保留，1st的s/t仍有两个动作，不给数字发明字母地标。
- `from... to...`、`between... and...` 是 `kind=pattern`，省略号是填入内容的槽位；不当成普通英文单词。
- `TV`、`PE`、`No.`、`p.m.` 是 `kind=abbreviation`，保留大小写与句点。No.与number是缩写/展开关系，不是语法缩约。
- Hurry up!保留开头大写及感叹号。印刷弯撇号规范为ASCII撇号，`source_surface` 保留原书形式。
- congratulation按词表单数列头保留；日常祝贺常用的Congratulations仅作为提示，不偷改教材词表目标。
- equals行没有单列中文译文时，中文“他们是”“不能”等标为策划语法释义，不伪称逐字教材译文。

`sourceVerified`、`reviewed`原字段均保存在来源区域中。看图核对不将这些状态改为人工审核通过。

## 自动核验

复现：在本目录运行 `python -B -X utf8 g4_finalize.py`。脚本只生成同目录的 `g4.json`、`g4-audit.json`，不写源库和游戏。

核验覆盖：目标与故事集合完全相等；每个拼写的ASCII字母数等于动作数；分支动作数量；每册目标无重名；来源区域存在；图片文件存在；印刷页与文件页分开且值正确；14页所有非表头区域都有条目归属或有说明性排除。页面图与源JSON的SHA-256写入数据。

当前自动核验通过。该结果只证明结构与列示覆盖，不能证明适龄性、教材教学验收或记忆效果。339条故事仍需编辑通读和儿童试用；本次没有制作、试听或接入词库语音。
