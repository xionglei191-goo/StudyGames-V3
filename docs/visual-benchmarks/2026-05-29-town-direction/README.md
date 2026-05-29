# 2026-05-29 小镇视觉方向基准图

> 日期：2026-05-29  
> 当前阶段：RPG 主体验重构 P0 / R3.6 视觉方向升级  
> Owner：PM + UI / 美术组 + ImageGen 基准资产流程  
> 状态：已出稿 / 待资产深化与代码替换  
> 用途：为后续地图资产、角色替换、HUD 重绘提供统一的视觉参考。

## 文件说明

- `01-town-overview-benchmark.png`
  - 用途：确定小镇总览的空间关系、配色和“可逛小镇”的整体气质。
- `02-heroine-character-benchmark.png`
  - 用途：确定主角是否足够像女孩向梦幻时尚冒险主角，并评估后续是否适合缩成 sprite。
- `03-hud-ui-benchmark.png`
  - 用途：确定顶部 HUD、奖励预览、任务按钮、冒险日志卡片的层级和装饰方向。

## 方向关键词

- 操作骨架：`top-down town exploration`, `cozy life-sim feel`, `walk-up interaction`
- 视觉气质：`girl-friendly fantasy`, `dreamy fashion adventure`, `storybook town`, `boutique dollhouse world`
- 配色：`pastel pink`, `blush peach`, `cream white`, `mint green`, `sky blue`, `soft gold accents`
- 负面约束：`rustic farm`, `muddy palette`, `gritty realism`, `busy school app UI`, `exam app feeling`

## 使用建议

- 这 3 张图是“方向基准”，不是最终可直接上线资产。
- 后续如果继续用 `imagegen`，应优先围绕这 3 张图做局部深化和拆件生成，而不是再回到无约束重生成。
- 代码替换前，先判断新资产是否仍满足 `todo.md` 与 `docs/P0开发看板.md` 的地图可读性、交互点落位和 HUD 不遮挡要求。

## 提示词留档

- `prompts/01-town-overview.txt`
  - 小镇总览基准图提示词留档。
- `prompts/02-heroine-character.txt`
  - 主角角色设定图提示词留档。
- `prompts/03-hud-ui.txt`
  - HUD / UI 风格图提示词留档。

## 当前判断

- 小镇总览图已经满足“斜俯视可逛小镇 + 女孩向梦幻时尚风”的方向基线，可作为后续地图重绘的空间与配色参考。
- 主角图已经明确了可爱、可收藏、可换装感的角色气质，并附带小尺寸 sprite 预览，适合后续拆成行走帧参考。
- HUD 图已经证明“地图仍是第一视觉，UI 只做轻量包边和目标追踪”的层级方向成立。
- 当前不足仍然是：这些图尚未切成实际可用的地图分层、角色 sprite sheet 和 UI 组件资产。
