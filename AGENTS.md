# StudyGame Agent Collaboration Guide

> Project: StudyGame  
> Current phase: RPG 主体验重构 P0  
> Source of truth: `todo.md`  
> Last updated: 2026-05-28

## 1. Core Rule

Agents communicate through project documents first.

Do not rely on chat memory as the source of truth. Before planning or coding, read:

1. `AGENTS.md`
2. `todo.md`
3. `docs/P0开发看板.md`
4. Any role-specific document assigned by the PM

If documents conflict, use this order:

1. `AGENTS.md` for collaboration rules
2. `todo.md` for product scope and priority
3. `docs/P0开发看板.md` for current task assignment
4. Other `docs/` files as reference only

## 2. Current Product Direction

The project has moved from RPG-lite task packaging to RPG main-experience reconstruction.

Current P0 is not "make the task panel nicer". Current P0 is:

- Show 星光小镇 as the first screen.
- Let the player character move on the town map.
- Add map interactions for 钟塔, Keeper Ray / 公告牌, and 邮局入口.
- Show current goal and next destination in the main game view.
- Trigger the first task from the map.
- Return to the town after task completion and show visible map change.

Keep existing learning task, reward, progress, and verification systems unless the task explicitly requires changing them.

## 3. Role Boundaries

### PM / Game Design Lead

Owns:

- Product scope
- Player experience flow
- Story, goal, reward logic
- Acceptance criteria
- Agent assignment and phase control

Must update:

- `todo.md`
- `docs/P0开发看板.md`
- Stage reports when a phase is accepted or rejected

### Architecture Agent

Owns:

- Module boundaries
- State flow
- Phaser / React / EventBus responsibility split
- Compatibility with existing `TaskRuntime`

Must produce or update:

- Architecture notes in `docs/P0开发看板.md` or a PM-approved architecture document
- Risk notes before broad code changes

Do not:

- Rewrite the task runtime without PM approval
- Introduce backend, global state libraries, or large new frameworks without PM approval

### Code Agent

Owns:

- Implementation
- Refactoring inside assigned scope
- Tests and verification commands
- Build health

Must:

- Read the current assignment before coding
- Keep changes scoped to the assigned subsystem
- Preserve existing P0 reward and task behavior
- Run required checks before reporting done
- Report files changed and verification results

Do not:

- Expand scope beyond the assignment
- Delete content, assets, docs, or scripts unless explicitly assigned
- Mark work complete without evidence

### UI / Art Agent

Owns:

- Visual hierarchy
- Layout quality
- Character proportion
- Map readability
- HUD, marker, bubble, and touch target quality

Must:

- Validate desktop and mobile screenshots
- Call out visual bugs directly
- Ensure text does not overflow or cover important art

Do not:

- Add decorative UI that weakens the RPG map first impression
- Hide product problems behind style changes

### Content / Narrative Agent

Owns:

- Child-facing wording
- NPC dialogue
- Quest motivation
- Reward meaning
- Learning content tone

Must:

- Keep wording adventure-like, not exam-like
- Separate short HUD text, NPC dialogue, and detailed adventure log text
- Preserve textbook learning intent

Avoid child-facing words such as:

- 答题
- 正确答案
- 分数
- 考试
- 测验

### QA / Playtest Agent

Owns:

- Full-flow verification
- Screenshot review
- Regression checks
- Playability notes

Must test:

- Desktop viewport
- Mobile viewport
- First RPG map loop
- Existing P0 task and reward loop

Do not accept a task only because build passes.

## 4. Document Standards

### Required Documents

- `AGENTS.md`: agent collaboration rules.
- `todo.md`: current product plan, scope, roadmap, acceptance criteria.
- `docs/P0开发看板.md`: active task board, assignments, blockers, verification flow.
- `docs/README.md`: explains document categories and which documents are historical.

### Historical Documents

Historical docs may be useful for context, but they are not execution authority.

Examples:

- `docs/RPG-lite P0开发任务书.md`
- `docs/P0阶段验收报告.md`
- Long-term research documents

If a historical document conflicts with `todo.md`, follow `todo.md`.

### Writing Rules

Every active planning or delivery document should include:

- Date
- Current phase
- Owner or responsible role
- Status
- Scope
- Acceptance criteria
- Verification evidence or expected verification commands

Use checkboxes for actionable work.

Use "历史 / 已完成 / 废弃 / 当前执行" labels clearly.

## 5. Handoff Standard

When an agent finishes work, update the relevant document or provide a handoff note with:

- What changed
- Files changed
- What was verified
- What remains
- Risks or assumptions
- Suggested next agent

Minimum handoff format:

```md
## Handoff

- Role:
- Task:
- Status:
- Files changed:
- Verification:
- Remaining issues:
- Next recommended owner:
```

If the work changes product direction, update `todo.md`.

If the work changes current assignments or blockers, update `docs/P0开发看板.md`.

## 6. Definition of Done

An item is done only when:

- It matches the current `todo.md` scope.
- It satisfies the acceptance criteria in `docs/P0开发看板.md`.
- It has been verified with required commands or screenshots.
- It does not regress the old P0 task and reward loop.
- The agent reports evidence, not just confidence.

Current standard verification commands:

```bash
npm run test
npm run build
npm run verify
```

For RPG map work, add a browser or screenshot verification record until a dedicated automated script exists.

## 7. Current P0 Acceptance Snapshot

Current P0 is accepted only when:

- The first screen is 星光小镇 map.
- The player character can move.
- At least 3 map interactions exist: 钟塔, Keeper Ray / 公告牌, 邮局入口.
- The main game view shows current goal and next destination.
- The first quest can be triggered from the map.
- The first learning challenge can be completed.
- Returning to town shows visible reward or repair change.
- Existing task rewards, XP, level, and star shard logic still pass verification.

## 8. Technical Baseline

- Runtime: official Homebrew Node 24
- Package manager: npm
- App stack: Vite + React + Phaser 3
- Data: local storage
- No backend in current P0
- No AI service integration in current P0

Expected local tools:

```bash
node --version
npm --version
npx --version
```

Project verification:

```bash
npm install
npm run test
npm run build
npm run verify
```

## 9. Scope Guards

Do not add these to P0 unless PM updates `todo.md` first:

- Battle system
- Open world map
- Advanced pathfinding
- Inventory economy
- Full badge system
- Full collection book
- Social features
- Backend services
- AI-generated dynamic content
- Monetization
- Expansion to all 75 tasks

## 10. Quality Bar

The project has already had visible quality issues: cluttered main page, distorted character, text overflow, floating props, unclear clicks, and unclear rewards.

Agents must actively guard against repeating those issues.

For any UI or game scene change, check:

- Is the main map or scene visually clear?
- Is the player goal visible without reading a long panel?
- Is text inside its container?
- Are buttons attached to clear UI containers?
- Is the character proportion correct?
- Are interactive objects grounded and clickable?
- Does mobile still work?

If the answer is uncertain, do not mark the task complete.
