# StudyGame RPG 主体验重构项目计划

> 日期：2026-05-28  
> 当前阶段：RPG 主体验重构 P0  
> 产品方向：儿童英语学习冒险 RPG  
> 技术基线：Vite + React + Phaser 3 + 本地存储  
> 项目原则：保留已跑通的学习任务、奖励和进度系统，重构玩家第一眼看到和第一手操作的 RPG 主体验。

## 一、项目结论

- [x] 旧 P0 已完成：3 个英语委托、奖励结算、经验、星片、章节完成反馈可以跑通。
- [x] 旧 P0 的问题是主体验仍像“学习任务面板 + RPG 包装”，不是孩子直觉中的 RPG。
- [x] 新阶段不推翻底层任务系统，不重写 75 个任务，不重做所有内容。
- [x] 新阶段优先重构首屏体验：小镇地图、角色移动、NPC/地点交互、主画面目标提示。
- [x] 主线故事、目标、奖励必须成为游戏世界的一部分，而不是只在侧边面板里解释。
- [x] 2026-05-29 视觉方向补充：操作骨架参考“轻松小镇探索型生活游戏”，强调斜俯视小镇、低压力点击移动、走近即互动、地点本身讲故事；美术气质切换为女孩向梦幻时尚风，面向喜欢甜美、精致、换装感和童话感的小玩家。

## 二、RPG 主体验定义

### 核心玩法闭环

- [x] 玩家进入游戏后首先看到星光小镇地图。
- [x] 玩家角色可以在小镇地图上移动。
- [x] 地图上可见故事钟塔、邮局、花园、镇口等关键地点。
- [x] 当前主线目标以 HUD / 任务追踪形式显示在主画面。
- [x] NPC、钟塔或地点标记提示玩家下一步要去哪里。
- [x] 玩家走近或点击交互点后触发对话、委托或进入学习挑战。
- [x] 学习挑战仍复用现有 `TaskRuntime`。
- [x] 完成委托后回到小镇，地图发生可见变化。
- [x] 完成 3 个星片后，钟塔第一圈星路在地图上点亮。证据：`npm run verify:rpg-map` 连续完成 3 个地图委托并断言最终 HUD 为 `第一圈星路已点亮`。

### 第一阶段不做

- [ ] 不做战斗系统、血量伤害、失败惩罚。
- [ ] 不做开放世界大地图。
- [ ] 不做复杂寻路、碰撞、任务分支。
- [ ] 不做完整背包、图鉴、徽章经济。
- [ ] 不做排行榜、社交、公会、开放聊天。
- [ ] 不做抽卡、内购、广告、外链。
- [ ] 不一次性改造 75 个任务。

## 三、当前 P0 范围

### 必须覆盖的体验

- [x] 主地图：星光小镇作为第一屏和冒险起点。
- [x] 玩家：角色可在地图上移动，至少支持点击目的地移动或方向键移动其中一种稳定方案。
- [x] 交互点：至少 3 个可交互对象。
  - [x] 故事钟塔：展示主线原因和星路状态。
  - [x] Keeper Ray / 公告牌：发出第一个委托。
  - [x] 邮局入口：进入第一个学习挑战场景。
- [x] 主画面 HUD：持续展示当前目标、下一步地点、奖励预览。
- [x] 背景信息：故事原因、主线目标、奖励用途在主画面轻量提示，详细信息进入冒险日志。
- [x] 委托流程：从小镇接取 `小镇门口见面礼`，进入邮局书房，完成挑战，回到小镇看到变化。
- [x] 地图反馈：完成第一个委托后，钟塔或星片状态发生可见变化。
- [x] 继续能力：第一个委托跑通后，可以扩展到现有 3 个 P0 委托。证据：`npm run verify:rpg-map` 覆盖 `task_eng_g3b_u01_main -> task_eng_g3b_u02_main -> task_eng_g3b_u03_main` 连续地图流程。

### P0 成功标准

- [x] 孩子进入游戏 10 秒内能看出“这是一个可以探索的小镇”。证据：`verify:rpg-layout` 首屏无开场遮挡，桌面/手机截图均为小镇地图。
- [x] 孩子能让角色移动到目标点附近。证据：`TownScene` 点击/键盘移动与 `verify:rpg-map` 地图点击流程通过。
- [x] 孩子能从主画面知道下一步去哪里，而不是只看右侧任务面板。证据：地图 HUD 显示当前目标、下一步地点、奖励预览。
- [x] 交互点有明确反馈，不需要乱点猜测。证据：钟塔、Keeper Ray / 公告牌、邮局入口均有标记、光圈、气泡/反馈。
- [x] 完成任务后能看到小镇地图变化和奖励用途。证据：`verify:rpg-map` 完成第一个委托后回到小镇并验证星片/回镇变化。
- [x] 桌面和手机视口不出现人物变形、文字出框、按钮漂浮、点击偏移。证据：`verify:rpg-layout` 覆盖 `1440x900`、`1280x720`、`390x844`、`360x740`。

## 四、阶段路线图

### R0：体验冻结与地图规格

- [x] 冻结 P0 目标：只做可移动小镇地图 + 第一个委托完整闭环。
- [x] 定义小镇地图首版布局：钟塔、邮局、花园、镇口、玩家出生点。
- [x] 定义移动方式：点击移动优先，必要时补方向键。
- [x] 定义 3 个 P0 交互点的触发规则和反馈文案。
- [x] 定义主画面 HUD 信息层级：当前目标、下一步地点、奖励预览。
- [x] 输出截图验收标准，避免再次出现“看起来不是 RPG”的偏差。

### R1：小镇地图与角色移动

- [x] Phaser 默认进入 `scene_town`，不直接展示任务场景。
- [x] 小镇地图占据主视觉区域，侧边面板降为辅助。
- [x] 玩家角色可移动，移动时角色比例稳定。
- [x] 目标点有地图标记、靠近提示或点击反馈。
- [x] 移动和交互在桌面、手机都可用。

### R2：地图交互与第一个委托

- [x] 钟塔交互展示“第一圈星路变暗”的主线背景。
- [x] Keeper Ray / 公告牌交互发出 `小镇门口见面礼`。
- [x] 邮局入口交互进入学习挑战。
- [x] 冒险日志只展示详细信息，不替代地图引导。
- [x] 完成挑战后返回小镇，地图显示第一个星片或钟塔微亮。

### R3：三任务主线接入

- [x] R3 三任务地图化产品与内容方案已补齐：第 1 个 `小镇门口见面礼` 已接入，第 2 个 `帮 Mina 赶上铃声`、第 3 个 `天气出门准备` 的目标点、触发方式、HUD 文案、回镇变化和验收流程已写入 `docs/P0开发看板.md`。
- [x] 将 `帮 Mina 赶上铃声` 接入小镇地图流程。证据：`verify:rpg-map` 从 `mina_bell` 触发 `task_eng_g3b_u02_main` 并完成回镇。
- [x] 将 `天气出门准备` 接入小镇地图流程。证据：`verify:rpg-map` 从 `weather_station` 触发 `task_eng_g3b_u03_main` 并完成回镇。
- [x] 3 个星片分别对应地图上的可见修复进度。证据：小镇地图显示问候、铃声、天气三格进度，`verify:rpg-map` 断言 1/3、2/3、3/3 星片回镇状态。
- [x] 完成 3 个委托后，钟塔第一圈星路点亮。证据：`verify:rpg-map` 断言最终 `3/3 星片`、无 P0 待办、HUD 显示 `第一圈星路已点亮`。

### R4：扩展与试玩验证

- [ ] 组织儿童试玩，重点观察是否会移动、是否知道下一步、是否理解奖励。
- [ ] 根据试玩结果决定是否扩展第一章 10 个任务。
- [ ] 背包、图鉴、徽章、区域解锁继续放到 P1。

## 五、P0 必做任务

### 产品与体验

- [x] 将“星光小镇地图”定义为主页面，而不是一个信息面板。
- [x] 明确玩家出生点、目标点、可交互点。
- [x] 将故事原因拆成短 HUD 提示、NPC 对话、冒险日志详情三层。
- [x] 明确第一个委托的地图路径：出生点 -> 钟塔 / Ray -> 邮局 -> 学习挑战 -> 回小镇。
- [x] 明确完成第一个委托后的地图变化。
- [x] 明确 R3 三任务连续地图路径：完成第 1 个委托后从小镇继续去钟塔铃台找 Mina，完成第 2 个委托后从小镇继续去天气台 / 花园入口，完成第 3 个委托后回钟塔点亮第一圈星路。

### 技术与数据

- [x] 保留现有 `progressStore`、`TaskRuntime`、奖励结算逻辑。
- [x] 增加最小地图状态字段或从现有进度推导地图状态。
- [x] Phaser 增加玩家移动控制、目标点交互、地图状态刷新。
- [x] React 侧保留顶部成长状态和冒险日志，但不再把右侧日志作为唯一引导。
- [x] 增加或更新自动验证脚本，覆盖第一个 RPG 地图闭环。

### UI 与视觉

- [x] 主画面第一视觉必须是小镇地图。
- [x] HUD 不遮挡地图关键内容。
- [x] 当前目标提示短而稳定，不出现大段文本压图。
- [x] 交互点使用地图标记、光圈、NPC 气泡等游戏化提示。
- [x] 移动角色不变形，停靠点不漂浮。
- [x] 手机端保留可点击目标和足够触控尺寸。

### 内容与美术

- [x] 小镇地图首版可以复用现有场景图，但必须让钟塔、邮局、花园、镇口关系清楚。
- [x] Keeper Ray 可先用现有角色或公告牌表达，不阻塞代码组。
- [x] 所有儿童端文案避免“答题、正确答案、分数、考试”等强学习词。
- [x] 地图目标文案要像冒险提示，例如“去邮局找见面礼线索”，不写“开始练习”。
- [ ] 小镇整体视觉升级到“轻松探索骨架 + 女孩向梦幻时尚风”：
  说明：操作体验参考斜俯视小镇探索类生活游戏，视觉不走朴素乡村路线，改为甜美、闪亮、时尚、童话橱窗感。
- [x] 产出 3 张新的视觉基准图：
  说明：1. 小镇总览平面图；2. 主角角色设定；3. HUD / UI 风格基准图。
- [x] 用统一美术关键词驱动后续资产生成、UI 落版和 QA 验收：
  说明：`cozy top-down town`, `storybook town`, `pastel pink`, `mint`, `cream`, `sky blue`, `gold accents`, `cute fashion adventure`, `girl-friendly`, `dream boutique`, `toy-like architecture`, `soft glow`, `sparkle details`, `clean readable game UI`, `no clutter`, `not rustic`, `not realistic gritty`.

### 美术关键词与 ImageGen 提示词基线

#### 美术关键词

- 操作体验关键词：`top-down town exploration`, `cozy life-sim feel`, `low-pressure interaction`, `walk-up interaction`, `clean readable paths`, `discoverable landmarks`
- 视觉气质关键词：`girl-friendly fantasy`, `dreamy fashion adventure`, `storybook charm`, `boutique dollhouse town`, `playful elegance`, `soft magical sparkle`
- 配色关键词：`pastel pink`, `blush peach`, `cream white`, `mint green`, `sky blue`, `lavender accents`, `soft gold accents`
- 建筑关键词：`toy-like architecture`, `storybook post office`, `fairytale clock tower`, `garden weather station`, `cute signboard`, `polished surfaces`
- 角色关键词：`chibi heroine`, `fashionable little adventurer`, `large expressive eyes`, `cute silhouette`, `small walking sprite proportions`, `dress-up friendly`
- UI 关键词：`rounded cards`, `sticker-like badges`, `soft highlight glow`, `clean quest tracker`, `gentle shadows`, `readable without clutter`
- 负面关键词：`rustic farm look`, `muddy colors`, `realistic gritty textures`, `busy mobile UI`, `dark survival mood`, `flat learning app panels`, `exam app feeling`

#### ImageGen 提示词 1：小镇总览平面图

```text
Use case: illustration-story
Asset type: game concept art benchmark for town map
Primary request: create a top-down or slightly angled top-down town overview for a children's learning adventure game
Scene/backdrop: a compact magical town plaza with a central path, side paths, clock tower, post office, garden weather station, bulletin board, entry gate, flower beds, shallow river edge
Subject: the town should feel explorable like a cozy life-sim town, but visually styled for girls who love dreamy fashion and dollhouse-like worlds
Style/medium: polished storybook game concept art, cute toy-like architecture, soft magical glow
Composition/framing: wide map overview, clearly readable roads and walkable zones, landmarks separated cleanly, suitable as a game map reference
Lighting/mood: bright daytime, cheerful, warm, safe, inviting
Color palette: pastel pink, cream, mint green, sky blue, soft gold accents
Materials/textures: smooth painted surfaces, charming signs, soft sparkles, flower details, boutique window feeling
Constraints: must look like a playable town map, not a poster illustration; roads, entrances, and standing areas must be readable; no combat tone; no clutter
Avoid: rustic farm feeling, muddy brown palette, gritty realism, flat app-like panels, hidden hotspots
```

#### ImageGen 提示词 2：主角角色设定

```text
Use case: illustration-story
Asset type: character concept benchmark for player avatar
Primary request: create a chibi girl adventurer for a cozy top-down town exploration game
Scene/backdrop: neutral presentation background with soft fashion concept styling
Subject: a cute little heroine who feels collectible, dress-up friendly, brave but sweet, suitable for a girl's dream adventure town
Style/medium: polished character concept art for a stylized game, toy-like proportions, expressive face, clean silhouette
Composition/framing: full body front-facing character sheet style, include one or two small side pose hints if natural
Lighting/mood: soft studio glow, cheerful, magical, premium toy-box appeal
Color palette: pastel pink, cream, blush, mint, small gold sparkle accents
Materials/textures: soft fabric, ribbon details, glossy shoes, simple accessory charm
Constraints: should translate into a small walking sprite later; proportions should feel chibi and readable at small size; not too detailed to animate
Avoid: realistic teen fashion model, edgy attitude, gritty shading, oversized head-only doll, plain school uniform
```

#### ImageGen 提示词 3：HUD / UI 风格基准图

```text
Use case: ui-mockup
Asset type: game HUD style benchmark
Primary request: create a UI style mockup for a top-down cozy adventure game for girls
Scene/backdrop: overlay HUD on a soft blurred town-map backdrop
Subject: top HUD with current goal, next destination, reward preview, rounded action button, badge-like counters, adventure log card
Style/medium: polished game UI concept art, readable, soft premium casual game interface
Composition/framing: clean layout with map still visible as the main focus, minimal obstruction, desktop-friendly and mobile-friendly hierarchy
Lighting/mood: bright, airy, soft glow, delightful and gentle
Color palette: cream white, pastel pink, mint green, sky blue, rose accents, soft gold accents
Materials/textures: rounded glossy badges, sticker-like panels, soft shadows, subtle sparkle highlights
Text (verbatim): "当前目标", "下一步地点", "奖励预览"
Constraints: must feel like a real game HUD, not an educational app dashboard; map remains the hero; hierarchy must be clean and uncluttered
Avoid: heavy admin dashboard feel, giant white walls, overly dense text, dark fantasy UI, cluttered icons
```

## 六、P1 延后任务

- [ ] 完整背包系统。
- [ ] 完整徽章系统。
- [ ] 完整图鉴页。
- [ ] 区域解锁规则。
- [ ] 更多 NPC 对话。
- [ ] 第一章 10 个任务完整 RPG 化。
- [ ] 家长摘要 RPG 成长解释增强。
- [ ] 更精细的地图碰撞和寻路。

## 七、组织分工

### 产品 / 项目经理

- [x] 冻结 RPG 主体验 P0 范围。
- [x] 写清楚小镇地图、角色移动、交互点、任务追踪的验收标准。
- [x] 每轮版本按“进入小镇 -> 移动 -> 交互 -> 接委托 -> 完成挑战 -> 回小镇变化”验收。
- [x] 阻止 P0 期间扩展背包、图鉴、战斗、经济系统。
- [x] 明确 PM 只负责游戏策划、产品节奏、派工和验收，不直接承担代码开发。
- [x] 设置架构组、代码组、UI / 美术组的职责边界，并以 `docs/P0开发看板.md` 作为当前派工依据。
- [x] 建立 `lessons.md` 作为踩坑复盘与质量红线文档。

### 策划 / 内容

- [x] 输出第一个委托的地图路径和 NPC 对话。
- [x] 输出钟塔、Ray / 公告牌、邮局入口三类交互文案。
- [x] 输出 HUD 短提示和冒险日志详情文案。
- [x] 检查儿童端语气是否像冒险，不像考试。
- [x] 输出第 2、3 个委托的地图目标点、触发方式、HUD 短提示、地点气泡、回镇变化和验收口径。

### 架构组

- [x] 设计小镇地图状态和现有任务状态的连接方式。
- [x] 判断移动、交互、任务启动放在 Phaser / React / EventBus 的边界。
- [x] 明确哪些旧 UI 要降级、隐藏或保留。
- [x] 给代码组一份最小实现方案，避免重写任务系统。

### 代码组

- [x] 实现小镇地图默认入口。
- [x] 实现玩家角色移动。
- [x] 实现地图交互点和交互反馈。
- [x] 接入第一个委托从地图触发、完成后回地图变化。
- [x] 保持已有 `npm run test`、`npm run build`、`npm run verify` 通过。

### UI / 美术

- [x] 定义小镇主地图首屏视觉重点。
- [x] 定义 HUD、目标标记、NPC 气泡、交互光圈样式。
- [x] 检查桌面和手机截图中的遮挡、比例、出框、点击偏移。

### QA / 试玩

- [x] 按完整 RPG 地图闭环试玩第一个委托。
- [x] 记录是否能移动、是否知道去哪里、是否知道为什么做任务。
- [x] 分桌面和手机截图验收。

## 八、验收标准

### 功能验收

- [x] 进入游戏默认看到小镇地图。
- [x] 玩家角色可以在地图上移动。
- [x] 至少 3 个地图交互点可触发反馈。
- [x] 可以从地图接取第一个委托。
- [x] 可以从地图进入邮局书房学习挑战。
- [x] 完成第一个委托后可以回到小镇。
- [x] 小镇地图能显示第一个奖励或修复变化。
- [x] R3 三任务地图化验收口径已定义：从小镇继续第 2、3 个委托，3 个星片回到钟塔后第一圈星路点亮。
- [x] 可以从小镇继续接取并完成 `帮 Mina 赶上铃声`。证据：`npm run verify:rpg-map`。
- [x] 可以从小镇继续接取并完成 `天气出门准备`。证据：`npm run verify:rpg-map`。
- [x] 完成 3 个星片后，钟塔第一圈星路在地图上点亮。证据：`npm run verify:rpg-map`。

### 视觉验收

- [x] 主地图是第一视觉，不被大面积面板抢走。
- [x] HUD 信息短、清楚、不遮挡目标。
- [x] 角色比例正常，移动时不变形。
- [x] 地图目标点不漂浮、不偏移。
- [x] 文本不出框，按钮不漂浮。
- [x] 手机端没有横向溢出和不可点击区域。

### 技术验收

- [x] `npm run test` 通过。
- [x] `npm run build` 通过。
- [x] `npm run verify` 通过。
- [x] 新增 RPG 地图闭环验证脚本或等价浏览器验收记录。
- [x] 旧 P0 三任务奖励逻辑不回退。

## 九、风险与决策记录

- [ ] 风险：继续只改 UI 名称，会变成“披着 RPG 皮的学习 App”。决策：P0 必须先做可移动小镇地图。
- [ ] 风险：自由地图移动范围过大。决策：只做小镇首屏小地图，不做开放世界。
- [ ] 风险：重做主体验影响已跑通任务。决策：保留 `TaskRuntime`，只重构进入任务前后的游戏世界层。
- [ ] 风险：移动端操作复杂。决策：点击移动优先，方向键只作为备选。
- [ ] 风险：美术资源不足。决策：首版可复用现有图，但必须通过布局和交互表达小镇关系。

## 十、2026-05-28 P0 主体验重构交付记录

- [x] 子 agent 模式已启用：架构/内容、游戏代码、UI/React 三个子 agent 并行交付，PM 负责整合和验收。
- [x] 环境问题已处理：npm 脚本显式使用 Homebrew Node 24，避免 Codex 内置 Node 加载 Rollup 原生包签名失败。
- [x] 新增 `npm run verify:rpg-map`：验证首屏小镇、钟塔、Keeper Ray / 公告牌、邮局入口、第一个委托完成、回小镇变化。
- [x] 新增 `npm run verify:rpg-layout`：验证 `1440x900`、`1280x720`、`390x844`、`360x740` 首屏布局并输出截图。
- [x] 验收命令已通过：`npm run test`、`npm run build`、`npm run verify`、`npm run verify:rpg-map`、`npm run verify:rpg-layout`。
- [x] 当前 P0 主体验闭环完成范围：星光小镇首屏、角色移动、3 个交互点、第一个委托地图触发、邮局书房挑战、完成后回小镇变化。
- [x] R3 三任务地图化文档方案已补齐：第 2、3 个委托的小镇目标点、触发方式、HUD 文案、回镇变化和验收流程已写入 `docs/P0开发看板.md`。
- [x] R3 三任务全地图化代码实现已完成：`帮 Mina 赶上铃声` 从钟塔铃台 / Mina 触发，`天气出门准备` 从天气台 / 花园入口触发，完成后第一圈星路点亮。
- [x] R3 验收命令已通过：`npm run test`、`npm run build`、`npm run verify`、`npm run verify:rpg-map`、`npm run verify:rpg-layout`。
