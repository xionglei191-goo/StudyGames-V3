# Narrative v2 cross review by g5 author

Reviewed `root_tail_g5.json` in full (10 records), plus all 13 records in `output_root.json` whose input spellings are `can`, `cold`, `with`, `make`, or `park`. This is an assistant editorial pass; no human or child validation is claimed. Files reviewed here were not edited by this author.

## Concrete issues to repair

1. **can / 能够 — successful action is ambiguous** (`story-175779efc9e8`, beat 3). The task is to throw the ball into a basket; beat 2 only says it flies toward the rim, and beat 3 says 鸟巢稳稳接住落下的球. Catching the ball does not explicitly establish that the throw reached the basket. Suggested repair: 鸟巢稳稳托住篮子，看见软球落进篮底，苹果终于高兴地说自己做到了. This keeps N as the actor and makes the ability outcome visible.

2. **can / 罐、听 — the recall question changes the prop state** (`story-646d2f1794a3`, recall question). Beat 1 introduces 一听饮料 and no beat opens or empties it; the question suddenly calls it 空罐. Replace 空罐 with 金属罐, or explicitly establish an empty demonstration can in the story.

3. **zoo — model scene switches to a live tour without an explicit transition** (`story-56385342667c`, beats 1–3). Beat 1 places 斑马 at 旅行馆的动物园入口模型前 with 小游客, while beats 2–3 lead the visitors into animal areas as though inside a full zoo. Clarify one consistent scale: make the tourists toy figures touring the model, or have the characters start at an actual zoo entrance. The landmark order can stay unchanged.

4. **park / 停放 — English phrase and Chinese assertion do not match** (`sense-scene-30ffdf7e2e82`, beat 4). `park the car` is an imperative/instruction, while the following 车已经停放好了 describes an accomplished state. Keep the beat in natural Chinese, or pair the English imperative with 把车停好; if retaining completed-state English, use a completed-state expression rather than this imperative.

5. **Several final beats step out of the story to explain vocabulary, leaving the same kind of awkward wording already removed from g5**. Keep the action and let `meaning_bridge` do the explicit gloss. Specific locations:
   - `story-175779efc9e8` can, beat 3: 这一次它真的做到了，can就是能够 → finish with the visible success and joy.
   - `story-a5f13bc9f88e` cold/感冒, beat 4: 这里的cold说的是感冒，不是窗外温度低 → finish with everyone quietly keeping the unwell friend company.
   - `story-ce1afcb84765` cold/冷的, beat 4: 记住这一次cold是冷的 → finish with the felt cold and relief after blocking the draft.
   - `story-39c867ca5640` you're, beat 5: quoted dialogue is followed by 你是队长，you're把听者和当前身份连了起来 → retain the direct address and the new captain's response; move the grammatical explanation to the existing bridge.
   - `story-8ba4de2f9437` yuan, beat 4: 大家记住价签上的元可以用yuan表示 → finish the paid-for purchase; leave the English currency-unit link in the bridge.

6. **make / 制定 — title introduces a weather detail the story never uses** (`sense-scene-9577b331518b`). 给野餐留出晴天的一格 promises choosing a sunny day, but the beats only order preparation, departure, eating and cleanup. A title such as 把野餐步骤排清楚 fits the actual plot without adding an unsupported weather subplot.

## 主作者落实记录（2026-10-24）

以上问题已全部修入手写源稿并重新生成输出：can 明确球落进篮底，罐的提问保持金属罐状态；zoo 全篇统一为玩偶参观模型；park 用车辆停稳、通道恢复结束；cold、you're、yuan 的末格恢复角色行动；make 制定的标题改为“把野餐步骤排清楚”。主作者已读取修订内容核对，发布记录见 `review/narrative_editorial_review.md`，本节不扩大原审读者的复核范围。
