# 首版内容与语音来源

本包读取现有 Englishbook 项目的 `public/library.json` 与 `public/books/*.json`，不修改该项目。导入脚本为 `scripts/import_curriculum.py`，运行时只读取本游戏中的 JSON 与 MP3，不连接网络。

## 本次实装范围

教材目录索引含三至六年级上下册共八册。**实际可玩的教材主线只有三年级上册开场三个单元的核心表达与九个新编情境题**，没有宣称八册内容已经游戏化，也没有完整覆盖字母书写、所有听力或所有单元活动。

| 主线 | 教材标题 | 印刷页 | 源文件页 | 本版练习 |
|---|---|---|---|---|
| Unit 1 | Hello! | 1–5 | 8–12 | 问候、早安、感谢 |
| Unit 2 | What's your name? | 6–10 | 13–17 | 问名字、自我介绍、告别 |
| Unit 3 | How old are you? | 11–15 | 18–22 | 问年龄、八岁与九岁 |

`source.page` 是教材印刷页，`source.file_page` 是 Englishbook 文件页；`region_id` 是其点读区域 ID。主要问候、姓名、年龄和感谢文字已对照源文件页 8、11、13、18、19 的页面图核对。中文释义为本游戏新编，不伪称教材译文。

九道题的场景、选项、干扰项均为游戏新编，`source.kind=authored_adaptation`，其锚点只为目标表达提供来源。`u1_goodbye` 是沿用的稳定程序 ID，内容为离开前说感谢，锚定 Unit 1 的 `Thank you.`，并非提前教授 Unit 2 的告别课。`u3_birthday` 只在生日名牌场景练习 Unit 3 的 `I'm eight.`，没有把 Unit 10 的生日课算入第三单元。

## 生活词汇预览

apple、cake、milk、bread、please、I like apples 为小镇生活场景预览，均有精确教材来源，但不属于开场三课的完整主线范围，也不计入主线过关要求：

| 词语 | 来源 |
|---|---|
| apple | 三上 Unit 9，印刷 52 页，`p59-r6` |
| cake | 三上 Unit 10，印刷 58 页，`p65-r24` |
| milk | 三上 Unit 4，印刷 23 页，`p30-r9` |
| bread | 四上词汇表，印刷 68 页，`p75-r17` |
| please | 三下词汇表，印刷 66 页，`p73-r4` |
| I like apples. | 三上 Unit 9，印刷 53 页，`p60-r4` |

`My name is Lulu.` 是教材示例人物自我介绍，不代表玩家的真实姓名。

## 离线语音

18 个 MP3 全部从 Englishbook 已有缓存按字节复制。声线是 **Edge TTS `en-US-JennyNeural`，语速 `-10%`**，属于合成语音，**不是教材原版配音，也不声称来自母语者录音**。导入过程没有重新生成语音；游戏不需要联网朗读。

`content_manifest.json` 保存每条缓存位置、大小、源与目标 SHA-256，以及课程 JSON 校验值。复制源和目标哈希必须一致。原有整单元教材录音未包含在这个轻量包中。

## 记录口径

独立完成须首次作答正确，且本题未打开中文提示或接受答案辅助；提示后正确、错后重试正确应另计辅助完成。正常重播听力不算中文/答案辅助。解锁与记录由游戏状态模块执行。九道选择题仅用于当前游戏进度，不代表标准化英语水平评价或真实学习效果验证。

## 重建与核验

```powershell
python scripts/import_curriculum.py --source D:\Project\Englishbook
python scripts/import_curriculum.py --source D:\Project\Englishbook --verify-only
```

导入会对精确区域文字、三个单元页码、缓存存在和声音类型做检查；源内容发生变化会报错，不会悄悄替换来源。校验模式不会修改内容。源教材页图和整册 PDF 没有复制到游戏包。
