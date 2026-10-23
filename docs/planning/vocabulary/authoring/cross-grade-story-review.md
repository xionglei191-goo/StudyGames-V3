# 全库长词与书写边界抽查

日期：2026-10-22。本报告是智能助手对总编构建产物的交叉检查，不是人类编辑验收或儿童试用。本审阅者曾编写四年级原稿，因此四年级原稿部分属于作者再检查，不能算独立的人类二审。未修改总编目录或catalog。

审阅基准：`data/catalog.json`，`planning_version=v1`，1073个拼写、1125个故事页。初次完整检查快照SHA-256：`63bd2657d834c29f007bbf807769125d039fe65e6828ede453b476b9a1665039`。后续重建核验结果另记于本文末尾。

当前结论：截至末次复验快照`c3cfec16ede3901a66e3b47510c1c93e01747c13845897d238d1e097d84ee9c3`，本报告所列三个原发现均已修复并核验。以下保留问题证据和两次重建核验记录；此结论不扩大为全库人工语义验收。

## 检查过程中发现的问题

### R1：同义项因整串中文释义变化而换用新核心故事

定位：`data/catalog.json` 的下列story_id及其引用的册内occurrence。`authoring/g3.json`、`g4.json`、`g5.json`中各自原稿故事均存在，问题出在合并后的复用关系。

| 拼写 | 最早故事页 | 后册故事页 | 已重复的同义部分 |
|---|---|---|---|
| park | `story-e6afb9362996`，四下“公园；停放” | `story-ba1f6511b54f`，五下“公园” | “公园”已包含在最早义项中，却改用另一套P-A-R-K动作 |
| with | `story-f8173475fa0e`，四上“和……一起；具有；用” | `story-11e1c6026565`，五下“用……；与……一起” | “和……一起/与……一起”及“用”属于已有义项，但出游故事改成制作故事 |
| make | `story-3a1981bd1099`，三下“制作；让” | `story-f35da80ba34c`，四下“制作；制定” | 新增“制定”应补相邻意义场景；已有“制作”不应重新编一套核心动作 |

可复现的具体差别：park原页P→A是“南瓜滚入公园绿地模型→苹果沿园中小路走”，后册变成“推出有树和长凳的绿地模型→滚到步道入口”；with原页是“鲸鱼等在码头→把两人一同接走”，后册换成“邀请同伴一起做纸船→共同完成”。这些并非两个不同的英语义项。

当前`root_location`虽然仍保留首见位置，核心动作已变化；单纯共用根位置不能满足“同义故事不随册重置”。尤其每条卡当前仍显示同义不重置的复用声明，会让审阅者误以为已完成该约束。

建议：把一个复合中文释义拆成可识别的义项集合，或对已确认包含/近义关系的这几词显式配置复用规则。复用最早已覆盖义项的核心动作；把“停放/具有/用/让/制定”等作为命名的相邻意义场景保留。不能为了减少页数把真正不同义项一律合并，也不能只比较整串中文是否完全相同。

状态：已修复并复验。park、with、make均已复用首次核心故事；with的“用”补充意义镜头也已合并为首次动作和位置。详细核验记录见本文末尾。

## 已核查范围

按catalog `letter_chain`数量降序、同长度按拼写排序，逐步阅读前30个目标的所有动作、固定场景、含义连接和迁移任务：

| 序号 | 目标 | 字母数 |
|---:|---|---:|
|1|International Children's Day|25|
|2|the Mid-Autumn Festival|20|
|3|the Golden Gate Bridge|19|
|4|Dragon Boat Festival|18|
|5|take online lessons|17|
|6|the Spring Festival|17|
|7|Shibadong Village|16|
|8|places of interest|16|
|9|Tian'anmen Square|15|
|10|Tree Planting Day|15|
|11|weather forecast|15|
|12|be interested in|14|
|13|congratulation|14|
|14|railway station|14|
|15|shopping centre|14|
|16|the Eiffel Tower|14|
|17|police station|13|
|18|primary school|13|
|19|Children's Day|12|
|20|You're welcome.|12|
|21|space station|12|
|22|the Great Wall|12|
|23|after-school|11|
|24|countryside|11|
|25|firecracker|11|
|26|grandfather|11|
|27|grandmother|11|
|28|grandparent|11|
|29|hide-and-seek|11|
|30|information|11|

另逐步核查12个书写边界/重复字母样例：café、from... to...、between... and...、1st、5th、No.、p.m.、football、school、book、apple、ice cream。

另核查12个近形、近音或标点对照目标：thirteen、thirty、Tuesday、Thursday、short、shirt、night、right、light、o'clock、T-shirt、don't。light的名词“灯”和动作“点燃；点亮”分别阅读，未把它们当同义。

另定向核查6个多义合并目标：fish、with、make、park、litter、fly；对照了`authoring/g3.json`、`g4.json`、`g5.json`、`g6.json`中的结构，以及其中相关的`actions`、`sense_extensions`与catalog输出。上述范围合计60个不同拼写，包含部分目标的多个意义页。

## 范围内未发现的问题与限制

前30长词逐步阅读未发现字母位置与动作主角明确冲突；故事可在所述固定场景中按顺序演出，不需要改变26字母映射。想象中物品会说话、变形、飞行，不能仅因非现实而判错；这也不证明适龄性或记忆效果。

book两次O、apple两次P、school两次O、football两次O与两次L都保留了独立位置。thirteen与thirty分别是十加三、三个十；Tuesday与Thursday分别定位星期二与星期四；short/shirt的O/I以及night/right/light的N/R/L均正确对应不同地标，未见借错相似词地标链。

café保留原é字符，字母编码为E并另记重音符号事件；两个省略号模式保留可填槽位，不把点变成字母；1st/5th的数字与英文字母分开记录。上述仅为本快照的具体检查结果。

全库还执行了动作开头显式主角的候选扫描：在1125个故事页中，未找到“动作开头明确指向另一固定地标”的候选。此扫描不能识别省略主语、隐含对象或故事中段的误指，不能代替逐条语义阅读；本报告没有将字母数相等或扫描无候选当作全库语义通过。

## 重建核验记录

审阅过程中已单独反馈的两个构建问题：缩略点被误作句末/语气标点；作者原稿的`sense_extensions`未进入catalog。

2026-10-22重建复验：`data/catalog.json` SHA-256为`aaeab0464663695a521ac5a48c2d0af77346ba036b174dd447580ed25d70d533`；1073个拼写、1096个核心意义故事页、1314条册内记录、50个补充意义镜头。本次只复验三个原发现，未扩大抽查范围。

| 原发现 | 首次重建复验结果 |
|---|---|
| No./p.m.缩略点误分类 | 已修复。No.第3字符、p.m.第2和第4字符均为`abbreviation_point`；对应书写事件为“保留缩略点；它不是句子结束或语气标记”，不占字母位置。 |
| 原稿补充意义镜头未进入catalog | 已修复。fish保留“鱼肉/钓鱼”，with保留“具有/用”，make保留“制作/让/制定”。逐项对照相应作者原稿，动作顺序和迁移任务均未遗漏。 |
| park/with/make因复合释义变化重置核心 | 核心部分已修复。park两册共用`story-92fb75704fb0`；with两册共用`story-a96482912777`；make两册共用`story-db6f1bcef02e`。三者逐步动作分别与四年级、四年级、三年级的首见原稿完全相同。首次重建时with“用”补充镜头尚有下述残留；末次重建已修复。 |

### 首次重建的R1残留：with的同义工具分支仍按册换动作

精确定位：`story-a96482912777.sense_extensions`中，四上`book_id=xiangshao-g4-1`、`meaning_zh=用`与五下`book_id=xiangshao-g5-2`、`meaning_zh=用……`。

- 四上W-I-T-H为“托来待画的卡→棒充当画笔→载着笔沿卡片画线→展示用笔完成的画”；意义画面定位“同出游台附工具层”。
- 五下W-I-T-H改为“摆尾铺平要剪的纸→滑出指定剪刀模型→运来需要使用的工具→指明用这件工具完成操作”；意义画面定位“沿用合作制作桌”。

两者都是with表示使用工具的同一义项。首次重建时，共用核心story_id已经解决“和某人一起”的核心重置，但该工具义补充故事仍形成两套动作和场景。已向总编建议五下复用四上既有工具义镜头，把剪刀场景保留为新情境迁移任务。此项在下述末次重建中已修复。

### 末次重建复验：三个原发现均已修复

2026-10-22末次复验快照：`data/catalog.json` SHA-256为`c3cfec16ede3901a66e3b47510c1c93e01747c13845897d238d1e097d84ee9c3`。计数为1073个拼写、1096个核心意义故事页、1314条册内记录、46个固定补充意义镜头、50条册内补充义引用。计数仅用于明确所检查的版本，不是语义通过的依据。

with工具义现在只有一个`sense-scene-a4c3f6323963`，`meaning_key=用`。它的`book_ids`同时包含四上和五下，`meaning_labels`保留“用”及“用……”，固定意义画面仍为四上出游台工具层，四步动作逐项与四上原稿一致：托来画卡、充当画笔、沿卡画线、展示完成的画。五下剪刀任务保留在`transfer_variants`中，没有另外一套剪刀记忆动作。

还读取了`cards/g4-1.md`与`cards/g5-2.md`中with的完整卡片：两册显示同一套工具义动作；剪刀文本明确出现在“该义项迁移练习（xiangshao-g5-2）”条目中。R1的最后残留已修复。

同时确认原先两项修复保持有效：No./p.m.的所有缩略点仍为`abbreviation_point`；fish的“鱼肉/钓鱼”、with的“具有/用”、make的“制作/让/制定”均保留具体动作和迁移任务。park、with、make的跨册核心story_id仍统一，逐步动作仍与各自首次作者原稿相同。本次仅复验原发现，没有扩大抽查范围，也没有将此结果标为独立人类编辑验收或儿童学习效果验证。
