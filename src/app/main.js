import { taskConfigs, tasksById } from "../content/tasks.js";
import { englishStoryContentChapterRows, englishStoryContentRows, englishStoryContentUnitRows } from "../content/englishStoryContentTable.js";
import { englishCorpusBooks, englishCorpusByBook, englishCorpusStats } from "../content/englishCorpus.js";
import { knowledgeById } from "../content/knowledge.js";
import { validateContent } from "../content/validators.js";
import { sceneConfigs, scenesById } from "../content/scenes.js";
import { rewardsById } from "../content/rewards.js";
import { rewardAssetFile } from "../content/assetCatalog.js";
import { getVerticalSliceCompletedCount, isVerticalSliceComplete, verticalSliceGoal, verticalSliceTaskBeats, verticalSliceTaskIds } from "../content/verticalSlice.js";
import { getOutfitLabel, getReviewKnowledgeIds, loadProgress, loadSettings, loadTelemetry, resetAllData, saveProgress, saveSettings } from "../data/progressStore.js";
import { generateParentReport } from "../data/reportGenerator.js";
import { playSound } from "../game/AudioSystem.js";
import { createPhaserGame, navigateToScene } from "../game/PhaserGame.js?v=art-assets-2";
import { eventBus } from "../game/EventBus.js";
import { taskRuntime } from "../game/TaskRuntime.js";

const { createElement: h, useEffect, useMemo, useRef, useState } = React;
const { createRoot } = ReactDOM;

function App() {
  const [progress, setProgress] = useState(loadProgress);
  const [settings, setSettings] = useState(loadSettings);
  const [telemetry, setTelemetry] = useState(loadTelemetry);
  const [sceneId, setSceneId] = useState("scene_town");
  const [taskState, setTaskState] = useState(null);
  const [toast, setToast] = useState("");
  const [panel, setPanel] = useState("tasks");
  const [parentGate, setParentGate] = useState({ open: false, answer: "" });
  const [celebrating, setCelebrating] = useState(false);
  const [stepFeedback, setStepFeedback] = useState("");
  const [rewardMoment, setRewardMoment] = useState(null);
  const [introOpen, setIntroOpen] = useState(false);
  const gameRef = useRef(null);

  useEffect(() => {
    if (gameRef.current) return undefined;
    const contentIssues = validateContent();
    if (contentIssues.length) {
      setToast(`内容配置有 ${contentIssues.length} 个问题，已使用可恢复模式。`);
      console.warn("StudyGame content issues", contentIssues);
    }
    try {
      gameRef.current = createPhaserGame("game-canvas");
    } catch (error) {
      console.error("StudyGame Phaser failed", error);
      document.documentElement.dataset.studyGameStatus = "failed";
      document.documentElement.dataset.studyGameError = error.message;
      setToast(`游戏画面启动失败：${error.message}`);
    }
    const onProgress = (event) => setProgress(event.detail);
    const onTelemetry = () => setTelemetry(loadTelemetry());
    const onScene = (detail) => setSceneId(detail.sceneId);
    const onTask = (detail) => setTaskState(detail);
    const onStepCorrect = (detail) => {
      setStepFeedback(detail.completed ? "委托完成，场景已经更新。" : "做对了，场景里的目标点亮起来了。");
      window.setTimeout(() => setStepFeedback(""), 1500);
    };
    const onChoiceWrong = () => {
      setStepFeedback("这次不合适，目标点会轻轻晃一下。");
      window.setTimeout(() => setStepFeedback(""), 1500);
    };
    const onComplete = (detail) => {
      const finalStepIndex = Math.max(0, detail.task.steps.length - 1);
      setProgress(detail.progress);
      setTaskState({
        ...detail.state,
        task: detail.task,
        step: detail.task.steps[finalStepIndex],
        stepIndex: finalStepIndex,
        totalSteps: detail.task.steps.length,
        selectedIds: [],
        completed: true,
        review: Boolean(detail.review)
      });
      setToast(detail.review ? "回访完成，线索记得更稳了。" : detail.task.successCopy);
      setRewardMoment(buildRewardMoment(detail.task, detail.progress, Boolean(detail.review), detail.settlement));
      setCelebrating(true);
      window.setTimeout(() => setCelebrating(false), 1100);
      setPanel("tasks");
    };
    const onFocus = (detail) => startTask(detail.taskId);

    window.addEventListener("studygame:progress", onProgress);
    window.addEventListener("studygame:telemetry", onTelemetry);
    const unsubScene = eventBus.on("scene:changed", onScene);
    const unsubStart = eventBus.on("task:started", onTask);
    const unsubProgress = eventBus.on("task:progress", onTask);
    const unsubComplete = eventBus.on("task:completed", onComplete);
    const unsubFocus = eventBus.on("ui:focus-task", onFocus);
    const unsubStepCorrect = eventBus.on("task:step-correct", onStepCorrect);
    const unsubChoiceWrong = eventBus.on("task:choice-wrong", onChoiceWrong);
    const unsubSceneChoice = eventBus.on("scene:choose-option", (detail) => handleChoice(detail.optionId));
    const unsubSceneSubmit = eventBus.on("scene:submit-options", () => handleSubmit());

    return () => {
      window.removeEventListener("studygame:progress", onProgress);
      window.removeEventListener("studygame:telemetry", onTelemetry);
      unsubScene();
      unsubStart();
      unsubProgress();
      unsubComplete();
      unsubFocus();
      unsubStepCorrect();
      unsubChoiceWrong();
      unsubSceneChoice();
      unsubSceneSubmit();
      gameRef.current?.destroy(true);
      gameRef.current = null;
    };
  }, []);

  const activeTask = taskState?.completed ? taskRuntime.getCurrentTask(progress) : (taskState?.task || taskRuntime.getCurrentTask(progress));
  const report = useMemo(() => generateParentReport(progress, telemetry), [progress, telemetry]);
  const reviewKnowledgeIds = useMemo(() => getReviewKnowledgeIds(progress), [progress]);
  const mapHud = useMemo(() => buildMapHud(progress, activeTask, taskState, sceneId, rewardMoment), [progress, activeTask, taskState, sceneId, rewardMoment]);

  function openPanel(nextPanel) {
    if (nextPanel === "parent") {
      setParentGate({ open: true, answer: "" });
      return;
    }
    setPanel(nextPanel);
  }

  function submitParentGate() {
    const value = parentGate.answer.trim();
    if (value === "9") {
      setParentGate({ open: false, answer: "" });
      setPanel("parent");
      return;
    }
    setToast("家长入口需要大人帮忙打开。");
    setParentGate({ open: false, answer: "" });
  }

  function startTask(taskId) {
    const task = tasksById[taskId] || activeTask;
    if (!task) {
      navigateToScene("scene_town");
      setPanel("tasks");
      setToast("今天的小镇委托都完成了，可以看看房间变化。");
      return;
    }
    const storedProgress = loadProgress();
    const isReview = storedProgress.completedTaskIds?.includes(task.id);
    const next = saveProgress({ ...storedProgress, activeTaskId: isReview ? storedProgress.activeTaskId : task.id });
    setProgress(next);
    setTaskState(taskRuntime.start(task.id));
    navigateToScene(getTownTaskSceneId(task));
    setPanel("tasks");
    setToast(task.introCopy);
  }

  function handleChoice(optionId) {
    const result = taskRuntime.choose(optionId);
    if (result.completed) return;
    if (result.ok && !result.pending) setToast("好，这一步完成了。");
    if (!result.ok) setToast(result.message);
    const nextState = taskRuntime.getState();
    const step = nextState?.step;
    const selectedCount = nextState?.selectedIds?.length || 0;
    if (result.pending && step && step.type === "order" && selectedCount >= step.correctOptionIds.length) {
      window.setTimeout(() => handleSubmit(), 180);
    }
  }

  function previewOption(option) {
    eventBus.emit("ui:preview-option", { option });
  }

  function clearPreviewOption() {
    eventBus.emit("ui:preview-option", { option: null });
  }

function handleSubmit() {
    const result = taskRuntime.submitSelection();
    if (result.completed) return;
    setToast(result.ok ? "这组放好了。" : result.message);
  }

  function handleHint() {
    playSound("hint");
    setToast(taskRuntime.useHint() || "先看看任务里的线索。");
  }

  function changeOutfit(outfitId) {
    const next = saveProgress({ ...progress, selectedOutfitId: outfitId });
    setProgress(next);
    setToast(`换上了${getOutfitLabel(outfitId)}。`);
    navigateToScene(sceneId);
  }

  function updateAudio() {
    const next = saveSettings({ ...settings, audio: !settings.audio });
    setSettings(next);
  }

  function resetProgress() {
    const ok = window.confirm("确定要清除本地进度吗？这会重置任务、奖励和家长摘要。");
    if (!ok) return;
    const next = resetAllData();
    setProgress(next);
    setTelemetry([]);
    setTaskState(null);
    setToast("进度已经重置。");
    navigateToScene("scene_town");
  }

  function restartSlice() {
    const next = resetAllData();
    setProgress(next);
    setTelemetry([]);
    setRewardMoment(null);
    setIntroOpen(false);
    setTaskState(null);
    navigateToScene("scene_town");
    setPanel("tasks");
    setToast("试玩切片已回到第一步。");
  }

  return h("div", { className: "app-shell" },
    h(Header, { progress, sceneId, activeTask, onPanel: openPanel, panel }),
    h("main", { className: "main-layout" },
      h("section", { className: "game-stage", "aria-label": "StudyGame 游戏画面" },
        h("div", { id: "game-canvas" }),
        h(MapHud, { hud: mapHud }),
        toast && h("div", { className: "toast", role: "status" }, toast),
        celebrating && h("div", { className: "celebration", "aria-hidden": "true" },
          h("span", null, "★"),
          h("span", null, "♡"),
          h("span", null, "★")
        )
      ),
      h("aside", { className: "side-panel" },
        panel === "tasks" && h(TaskPanel, { taskState, activeTask, progress, reviewKnowledgeIds, stepFeedback, sceneId, onChoice: handleChoice, onSubmit: handleSubmit, onHint: handleHint, onStartTask: startTask, onRestartSlice: restartSlice, onPreview: previewOption, onPreviewEnd: clearPreviewOption }),
        panel === "map" && h(StoryMapPanel, { progress, activeTask, onStartTask: startTask }),
        panel === "corpus" && h(CorpusPanel),
        panel === "outfits" && h(OutfitPanel, { progress, onChange: changeOutfit }),
        panel === "parent" && h(ParentPanel, { report }),
        panel === "settings" && h(SettingsPanel, { settings, onAudio: updateAudio, onReset: resetProgress })
      )
    ),
    parentGate.open && h(ParentGate, {
      value: parentGate.answer,
      onChange: (answer) => setParentGate({ open: true, answer }),
      onCancel: () => setParentGate({ open: false, answer: "" }),
      onSubmit: submitParentGate
    }),
    introOpen && h(VerticalSliceIntro, { onClose: () => setIntroOpen(false), onStart: () => {
      setIntroOpen(false);
      startTask(progress.activeTaskId || verticalSliceTaskIds[0]);
    } }),
    rewardMoment && h(RewardMomentModal, { moment: rewardMoment, onClose: () => setRewardMoment(null), onNext: (taskId) => {
      setRewardMoment(null);
      if (taskId) startTask(taskId);
      else navigateToScene("scene_town");
    } })
  );
}

function MapHud({ hud }) {
  return h("div", { className: hud.isComplete ? "map-hud is-complete" : "map-hud", "aria-label": "小镇冒险提示" },
    h("span", null, h("strong", null, "当前目标"), h("em", null, hud.goal)),
    h("span", null, h("strong", null, "下一步地点"), h("em", null, hud.destination)),
    h("span", null, h("strong", null, "奖励预览"), h("em", null, hud.reward)),
    hud.worldChange && h("span", { className: "hud-change" }, h("strong", null, "回镇变化"), h("em", null, hud.worldChange))
  );
}

function buildMapHud(progress, activeTask, taskState, sceneId, rewardMoment) {
  const completedCount = getVerticalSliceCompletedCount(progress);
  const isComplete = isVerticalSliceComplete(progress);
  const currentTask = taskState?.task || activeTask;
  const beat = verticalSliceTaskBeats[currentTask?.id] || {};
  const taskSceneId = getTownTaskSceneId(currentTask);
  const scene = scenesById[taskSceneId || currentTask?.sceneId];
  const rewards = currentTask?.rewards?.map((grant) => rewardLabel(grant.rewardId)).join("、");
  const isTaskScene = Boolean(taskSceneId && sceneId === taskSceneId);

  if (rewardMoment) {
    return {
      goal: "回到星光小镇看新光点",
      destination: "故事钟塔",
      reward: rewardMoment.shardText || `${completedCount}/${verticalSliceTaskIds.length} 星片`,
      worldChange: rewardMoment.worldChange,
      isComplete: rewardMoment.sliceComplete
    };
  }

  if (taskState?.completed) {
    if (isComplete || taskState.task?.id === verticalSliceTaskIds[verticalSliceTaskIds.length - 1]) {
      return {
        goal: "第一圈星路已点亮",
        destination: "钟塔星路",
        reward: "校园星门线索",
        worldChange: "钟塔第一圈已经亮起。",
        isComplete: true
      };
    }
    return {
      goal: "委托完成，回镇确认变化",
      destination: "故事钟塔",
      reward: `${completedCount}/${verticalSliceTaskIds.length} 星片`,
      worldChange: beat.worldChange || "小镇保存了这次变化。",
      isComplete
    };
  }

  if (!currentTask) {
    return {
      goal: isComplete ? "第一圈星路已点亮" : "在小镇寻找新委托",
      destination: isComplete ? "钟塔星路" : "Keeper Ray / 公告牌",
      reward: isComplete ? "校园星门线索" : `${completedCount}/${verticalSliceTaskIds.length} 星片`,
      worldChange: isComplete ? "钟塔第一圈已经亮起。" : "",
      isComplete
    };
  }

  if (!isTaskScene) {
    const townPrompt = townPromptByTaskId[currentTask?.id];
    if (townPrompt) {
      return {
        goal: townPrompt.goal,
        destination: townPrompt.destination,
        reward: `${rewards || "星片"} · ${Math.min(completedCount + 1, verticalSliceTaskIds.length)}/${verticalSliceTaskIds.length} 星片`,
        worldChange: completedCount > 0 ? latestWorldChange(progress) : "",
        isComplete: false
      };
    }
  }

  return {
    goal: isTaskScene ? (beat.playerAction || currentTask.title) : `接取「${currentTask.title}」`,
    destination: isTaskScene ? (scene?.title || "任务地点") : firstTaskDestination(currentTask.id, scene),
    reward: `${rewards || "星片"} · ${Math.min(completedCount + 1, verticalSliceTaskIds.length)}/${verticalSliceTaskIds.length} 星片`,
    worldChange: completedCount > 0 ? latestWorldChange(progress) : "",
    isComplete: false
  };
}

const townPromptByTaskId = {
  task_eng_g3b_u01_main: { goal: "小镇门口见面礼：去邮局找见面礼线索", destination: "邮局入口" },
  task_eng_g3b_u02_main: { goal: "去钟塔铃台找 Mina", destination: "钟塔铃台" },
  task_eng_g3b_u03_main: { goal: "去天气台看看天空", destination: "天气台 / 花园入口" }
};

function firstTaskDestination(taskId, scene) {
  if (taskId === verticalSliceTaskIds[0]) return "邮局入口";
  if (taskId === verticalSliceTaskIds[1]) return "钟塔铃台";
  if (taskId === verticalSliceTaskIds[2]) return "天气台 / 花园入口";
  if (scene?.title) return scene.title;
  return "小镇目标点";
}

function getTownTaskSceneId(taskOrId) {
  const taskId = typeof taskOrId === "string" ? taskOrId : taskOrId?.id;
  return {
    task_eng_g3b_u01_main: "scene_study",
    task_eng_g3b_u02_main: "scene_kitchen",
    task_eng_g3b_u03_main: "scene_wardrobe"
  }[taskId] || (typeof taskOrId === "string" ? null : taskOrId?.sceneId);
}

function latestWorldChange(progress) {
  const completedIds = verticalSliceTaskIds.filter((taskId) => progress.completedTaskIds?.includes(taskId));
  const lastCompletedId = completedIds[completedIds.length - 1];
  return verticalSliceTaskBeats[lastCompletedId]?.worldChange || "";
}

function Header({ progress, sceneId, activeTask, onPanel, panel }) {
  const scene = scenesById[sceneId];
  const shardCount = progress.starShard?.collectedIds?.length || 0;
  const shardTotal = progress.starShard?.total || verticalSliceTaskIds.length;
  const xpToNextLevel = progress.xpToNextLevel || 100;
  const xpPercent = Math.max(0, Math.min(100, Math.round(((progress.xp || 0) / xpToNextLevel) * 100)));
  return h("header", { className: "topbar" },
    h("div", { className: "brand" },
      h("span", { className: "brand-mark" }, "S"),
      h("div", null,
        h("strong", null, progress.title || "星路修复员"),
        h("span", null, `${scene?.title || "星光小镇"} · ${activeTask?.title || "今日冒险完成"}`)
      )
    ),
    h("div", { className: "status-strip" },
      h("span", { className: "level-pill" }, h("strong", null, `Lv.${progress.level || 1}`), h("em", null, progress.title || "星路修复员")),
      h("span", { className: "xp-pill" },
        h("strong", null, `${progress.xp || 0}/${xpToNextLevel} XP`),
        h("b", { "aria-label": "经验进度" }, h("i", { style: { width: `${xpPercent}%` } }))
      ),
      h("span", { className: "stat-pill" }, h("img", { src: "src/assets/images/icon-star.png", alt: "" }), `${progress.stars || 0} 星星`),
      h("span", { className: "shard-pill" }, `${shardCount}/${shardTotal} 星片`)
    ),
    h("nav", { className: "top-actions", "aria-label": "功能入口" },
      navButton("委托", "tasks", panel, onPanel),
      navButton("地图", "map", panel, onPanel, true),
      navButton("教材库", "corpus", panel, onPanel, true),
      navButton("换装", "outfits", panel, onPanel, true),
      navButton("家长", "parent", panel, onPanel, true),
      navButton("设置", "settings", panel, onPanel, true)
    )
  );
}

function navButton(label, id, panel, onPanel, muted = false) {
  const className = [panel === id ? "is-active" : "", muted ? "is-muted" : ""].filter(Boolean).join(" ");
  return h("button", { className, onClick: () => onPanel(id) }, label);
}

function VerticalSliceIntro({ onClose, onStart }) {
  return h("div", { className: "modal-backdrop", role: "dialog", "aria-modal": "true", "aria-label": "试玩切片开场" },
    h("section", { className: "story-modal" },
      h("div", { className: "eyebrow" }, verticalSliceGoal.subtitle),
      h("h1", null, verticalSliceGoal.openingTitle),
      h("p", null, verticalSliceGoal.openingCopy),
      h("div", { className: "story-modal-grid" },
        h("span", null, h("strong", null, verticalSliceGoal.playerRole), h("em", null, "完成 3 个小委托，修复钟塔第一圈。")),
        h("span", null, h("strong", null, "清楚的奖励"), h("em", null, "每关都会告诉你拿到了什么、修复了哪里。"))
      ),
      h("div", { className: "modal-actions" },
        h("button", { className: "ghost", onClick: onClose }, "先看看"),
        h("button", { className: "primary", onClick: onStart }, "开始修复")
      )
    )
  );
}

function RewardMomentModal({ moment, onClose, onNext }) {
  return h("div", { className: "modal-backdrop", role: "dialog", "aria-modal": "true", "aria-label": "任务奖励" },
    h("section", { className: moment.sliceComplete ? "story-modal chapter-complete" : "story-modal reward-moment" },
      h("div", { className: "eyebrow" }, moment.sliceComplete ? "章末反馈" : "奖励结算"),
      h("h1", null, moment.title),
      h("p", null, moment.copy),
      h("div", { className: "reward-moment-grid" },
        h("span", null, h("strong", null, "XP"), h("em", null, moment.xpText)),
        h("span", null, h("strong", null, "等级"), h("em", null, moment.levelText)),
        h("span", null, h("strong", null, "星片进度"), h("em", null, moment.shardText)),
        h("span", null, h("strong", null, "奖励用途"), h("em", null, moment.rewardUse)),
        h("span", null, h("strong", null, "小镇变化"), h("em", null, moment.worldChange)),
        h("span", null, h("strong", null, "知识成长"), h("em", null, moment.knowledgeText))
      ),
      moment.sliceComplete && h("div", { className: "chapter-reward-card" },
        h("strong", null, verticalSliceGoal.chapterRewardTitle),
        h("span", null, verticalSliceGoal.chapterRewardCopy),
        h("em", null, verticalSliceGoal.nextStepCopy)
      ),
      h("div", { className: "modal-actions" },
        h("button", { className: "ghost", onClick: onClose }, "留在这里"),
        h("button", { className: "primary", onClick: () => onNext(moment.nextTaskId) }, "回小镇看变化")
      )
    )
  );
}

function buildRewardMoment(task, progress, review, settlement = null) {
  const beat = verticalSliceTaskBeats[task.id] || {};
  const starShard = progress.starShard || {};
  const normalizedSettlement = {
    xpGained: settlement?.xpGained ?? (review ? 0 : 0),
    levelBefore: settlement?.levelBefore ?? progress.level ?? 1,
    levelAfter: settlement?.levelAfter ?? progress.level ?? 1,
    leveledUp: settlement?.leveledUp ?? false,
    starShardCollectedCount: settlement?.starShardCollectedCount ?? starShard.collectedIds?.length ?? getVerticalSliceCompletedCount(progress),
    starShardTotal: settlement?.starShardTotal ?? starShard.total ?? verticalSliceTaskIds.length
  };
  const rewardText = review
    ? "掌握度更新"
    : task.rewards.map((grant) => rewardLabel(grant.rewardId)).join("、");
  const sliceComplete = !review && isVerticalSliceComplete(progress);
  const xpText = normalizedSettlement.xpGained > 0 ? `+${normalizedSettlement.xpGained} XP` : review ? "回访不重复发 XP" : "XP 已记录";
  const levelText = normalizedSettlement.leveledUp
    ? `Lv.${normalizedSettlement.levelBefore} → Lv.${normalizedSettlement.levelAfter}`
    : `Lv.${normalizedSettlement.levelAfter}`;
  const shardText = review
    ? `${normalizedSettlement.starShardCollectedCount}/${normalizedSettlement.starShardTotal} 已点亮`
    : `${normalizedSettlement.starShardCollectedCount}/${normalizedSettlement.starShardTotal} 星片`;
  const knowledgeText = review ? "回访线索更稳了" : "本关知识点掌握度已更新";
  if (sliceComplete) {
    return {
      title: verticalSliceGoal.completionTitle,
      copy: verticalSliceGoal.completionCopy,
      rewardText,
      xpText,
      levelText,
      shardText,
      rewardUse: verticalSliceGoal.chapterRewardCopy,
      worldChange: beat.worldChange || "星光小镇保存了这次变化。",
      knowledgeText,
      nextTaskId: null,
      sliceComplete: true
    };
  }
  return {
    title: task.successCopy || "委托完成",
    copy: beat.successResult || "奖励已经放进小镇。",
    rewardText,
    xpText,
    levelText,
    shardText,
    rewardUse: beat.rewardUse || "放进收藏，并推进星光小镇修复进度。",
    worldChange: beat.worldChange || "对应场景出现了新的变化。",
    knowledgeText,
    nextTaskId: null,
    sliceComplete: false
  };
}

function StoryMapPanel({ progress, activeTask, onStartTask }) {
  const completedTaskIds = new Set(progress.completedTaskIds || []);
  const activeTaskId = getCurrentMainTaskId(progress, activeTask);
  const completedCount = getVerticalSliceCompletedCount(progress);
  const sliceRows = englishStoryContentRows.filter((row) => verticalSliceTaskIds.includes(row.taskId));
  const contentRowsById = Object.fromEntries(englishStoryContentRows.map((row) => [row.id, row]));
  const unitRowsById = Object.fromEntries(englishStoryContentUnitRows.map((row) => [row.id, row]));
  const activeChapter = currentStoryChapter(activeTaskId, completedTaskIds);

  return h("div", { className: "story-map-panel" },
    h("section", { className: "story-map-summary" },
      h("div", { className: "eyebrow" }, "主线地图"),
      h("h1", null, "星光英语旅程"),
      h("div", { className: "map-summary-grid" },
        h("div", null, h("strong", null, completedCount), h("span", null, "已完成")),
        h("div", null, h("strong", null, verticalSliceTaskIds.length), h("span", null, "切片任务")),
        h("div", null, h("strong", null, `${Math.round((completedCount / verticalSliceTaskIds.length) * 100)}%`), h("span", null, "星路进度"))
      ),
      activeTask && h("p", { className: "map-current-task" }, `当前委托：${activeTask.title}`)
    ),
    activeChapter && h("section", { className: "story-act-panel" },
      h("div", { className: "eyebrow" }, "当前故事线"),
      h("h2", null, activeChapter.storyAct || activeChapter.title),
      h("p", { className: "story-act-goal" }, activeChapter.narrativeGoal || activeChapter.introCopy),
      h("div", { className: "story-act-beats" },
        h("span", null,
          h("strong", null, "小镇变化"),
          h("em", null, activeChapter.worldChange || activeChapter.theme)
        ),
        h("span", null,
          h("strong", null, "章末目标"),
          h("em", null, activeChapter.chapterClimax || activeChapter.completionCopy)
        )
      )
    ),
    h(SceneMaterialOverview, { rows: sliceRows }),
    englishStoryContentChapterRows.filter((chapter) => chapter.id === "arc_eng_g3b_new_town").map((chapter) => {
      const chapterRows = chapter.unitIds
        .map((unitId) => {
          const unitRow = unitRowsById[unitId];
          const contentRow = contentRowsById[unitRow?.contentRowId];
          return unitRow ? { ...contentRow, ...unitRow } : null;
        })
        .filter((row) => row && verticalSliceTaskIds.includes(row.taskId))
        .filter(Boolean);
      const chapterDoneCount = chapterRows.filter((row) => completedTaskIds.has(row.taskId)).length;
      const chapterStatus = chapterDoneCount === chapterRows.length
        ? "已完成"
        : chapterRows.some((row) => row.taskId === activeTaskId)
          ? "进行中"
          : chapterDoneCount > 0 ? "进行中" : "未解锁";
      return h("section", { key: chapter.id, className: `chapter-map-card status-${chapterStatusClass(chapterStatus)}` },
        h("div", { className: "chapter-map-header" },
          h("div", null,
            h("div", { className: "eyebrow" }, `${chapter.bookTitle} · ${chapter.mapRegion}`),
            h("h2", null, chapter.title),
            h("p", null, chapter.theme)
          ),
          h("div", { className: "chapter-progress-badge" },
            h("strong", null, `${chapterDoneCount}/${chapterRows.length}`),
            h("span", null, chapterStatus)
          )
        ),
        h("div", { className: "chapter-progress-bar", "aria-label": `${chapter.title}完成进度` },
          h("span", { style: { width: `${Math.round((chapterDoneCount / chapterRows.length) * 100)}%` } })
        ),
        h("p", { className: "chapter-story-copy" }, chapterDoneCount === chapterRows.length
          ? chapter.completionCopy
          : chapter.narrativeGoal
        ),
        h("div", { className: "chapter-scene-strip" },
          chapterSceneStats(chapterRows).map((item) => h("span", { key: item.sceneId },
            h("strong", null, scenesById[item.sceneId]?.title || item.sceneId),
            h("em", null, `${item.count}关`)
          ))
        ),
        h("div", { className: "unit-path" },
          chapterRows.map((row) => {
            const nodeState = unitNodeState(row, completedTaskIds, activeTaskId);
            const isActionable = nodeState === "done" || nodeState === "current";
            return h("button", {
              key: row.id,
              className: `unit-node ${nodeState}`,
              disabled: !isActionable,
              onClick: () => isActionable && onStartTask(row.taskId),
              "aria-label": `${row.displayCode} ${row.unitTitle} ${unitNodeLabel(nodeState)}`
            },
              h("span", { className: "unit-node-index" }, row.displayCode),
              h("span", { className: "unit-node-body" },
                h("strong", null, row.unitTitle),
                h("small", null, row.taskTitle),
                h("em", null, `${scenesById[row.sceneId]?.title || "任务场景"} · ${row.rewardTitle}`)
              ),
              h("span", { className: "unit-node-action" }, unitNodeLabel(nodeState))
            );
          })
        )
      );
    })
  );
}

function currentStoryChapter(activeTaskId, completedTaskIds) {
  const activeRow = englishStoryContentRows.find((row) => row.taskId === activeTaskId);
  if (activeRow) return englishStoryContentChapterRows.find((chapter) => chapter.id === activeRow.chapterId);

  const firstIncompleteRow = englishStoryContentRows.find((row) => !completedTaskIds.has(row.taskId));
  if (firstIncompleteRow) return englishStoryContentChapterRows.find((chapter) => chapter.id === firstIncompleteRow.chapterId);

  return englishStoryContentChapterRows[englishStoryContentChapterRows.length - 1];
}

function SceneMaterialOverview({ rows }) {
  const sceneRows = sceneConfigs
    .filter((scene) => scene.id !== "scene_town")
    .map((scene) => ({
      scene,
      count: rows.filter((row) => row.sceneId === scene.id).length
    }))
    .filter((item) => item.count > 0);

  return h("section", { className: "scene-material-overview" },
    h("div", { className: "eyebrow" }, "教材场景素材"),
    h("h2", null, `${sceneRows.length} 个主题场景承接 ${rows.length} 关`),
    h("div", { className: "scene-material-grid" },
      sceneRows.map(({ scene, count }) => h("article", { key: scene.id, className: "scene-material-card" },
        h("div", { className: "scene-material-head" },
          h("strong", null, scene.title),
          h("span", null, `${count}关`)
        ),
        h("p", null, scene.materials?.map((item) => item.title).join(" / ") || scene.description),
        h("div", { className: "scene-theme-tags" },
          [...new Set((scene.materials || []).flatMap((item) => item.corpusThemes || []))].slice(0, 4).map((tag) => h("em", { key: tag }, tag))
        )
      ))
    )
  );
}

function chapterSceneStats(rows) {
  return Object.entries(rows.reduce((acc, row) => {
    acc[row.sceneId] = (acc[row.sceneId] || 0) + 1;
    return acc;
  }, {}))
    .map(([sceneId, count]) => ({ sceneId, count }))
    .sort((left, right) => right.count - left.count || left.sceneId.localeCompare(right.sceneId));
}

function TaskPanel({ taskState, activeTask, progress, reviewKnowledgeIds, stepFeedback, sceneId, onChoice, onSubmit, onHint, onStartTask, onRestartSlice, onPreview, onPreviewEnd }) {
  const allTasksDone = isVerticalSliceComplete(progress);
  const reviewCards = buildReviewCards(progress, reviewKnowledgeIds);
  if (allTasksDone && !activeTask) return h(CompleteTownPanel, { progress, reviewCards, onStartTask, onRestartSlice });
  if (!activeTask && !taskState?.task) return h(CompleteTownPanel, { progress, reviewCards, onStartTask, onRestartSlice });
  const state = taskState || { task: activeTask, step: activeTask.steps[0], stepIndex: 0, totalSteps: activeTask.steps.length, selectedIds: [] };
  const step = state.step;
  const isSelectableSet = step.type === "match" || step.type === "order" || step.type === "drag";
  const needsConfirmation = step.type === "match" || step.type === "order" || step.type === "drag";
  const currentMainTaskId = getCurrentMainTaskId(progress, activeTask);
  const visibleTasks = taskConfigs.filter((task) => verticalSliceTaskIds.includes(task.id)).map((task) => ({
    task,
    done: progress.completedTaskIds.includes(task.id),
    current: task.id === currentMainTaskId
  }));
  const taskSceneId = getTownTaskSceneId(state.task);
  const scene = scenesById[taskSceneId || state.task.sceneId];
  const anchor = scene?.anchors.find((item) => item.id === step.anchorId);
  const selectedLabels = step.options.filter((option) => state.selectedIds?.includes(option.id)).map((option) => option.label);
  const isAtTaskScene = sceneId === (taskSceneId || state.task.sceneId);
  const hasNextTask = Boolean(progress.activeTaskId && !progress.completedTaskIds?.includes(progress.activeTaskId));
  const requiredSelectionCount = step.correctOptionIds?.length || 1;
  const canConfirmSelection = !needsConfirmation || state.selectedIds.length === requiredSelectionCount;
  const completedCount = getVerticalSliceCompletedCount(progress);
  const beat = verticalSliceTaskBeats[state.task.id] || {};
  const storyRow = englishStoryContentRows.find((row) => row.taskId === state.task.id);
  const logSummary = state.completed
    ? (beat.worldChange || "回到小镇后，钟塔保存了这次变化。")
    : isAtTaskScene
      ? (beat.playerAction || "完成这个委托，推进星路修复。")
      : `地图 HUD 会指向${scene?.title || "目标地点"}，这里保留详细线索。`;
  const optionControls = h("div", { key: "answerOptions", className: isAtTaskScene ? "answer-options in-scene-options" : "answer-options" },
    h("div", { className: "answer-options-title" }, needsConfirmation
      ? `${stepActionCopy(step.type)} 已选 ${state.selectedIds.length}/${requiredSelectionCount}`
      : isAtTaskScene ? stepActionCopy(step.type) : "备选操作"
    ),
    h("div", { className: `option-grid type-${step.type}` },
      step.options.map((option) => h("button", optionButtonProps(option, step, state, onChoice, onPreview, onPreviewEnd),
        step.type === "order" && h("b", { className: "order-index" }, getOrderIndex(state.selectedIds, option.id)),
        optionImage(option.asset || option.label),
        h("span", null, option.label)
      ))
    ),
    step.type === "drag" && h("div", {
      className: state.selectedIds.length ? "drop-zone filled" : "drop-zone",
      onDragOver: (event) => event.preventDefault(),
      onDrop: (event) => onChoice(event.dataTransfer.getData("text/plain"))
    }, state.selectedIds.length ? selectedLabels[0] : "拖到这里试试看")
  );

  return h("div", { className: isAtTaskScene ? "panel-stack in-scene-task" : "panel-stack" },
    !isAtTaskScene && reviewCards.length > 0 && h(ReviewQueuePanel, { reviewCards, onStartTask }),
    h("section", { className: "task-card adventure-log" },
      h("div", { className: "slice-goal-card" },
        h("div", null,
          h("strong", null, "冒险日志"),
          h("span", null, `${completedCount}/${verticalSliceTaskIds.length} 星片已回到钟塔`)
        ),
        h("em", null, logSummary)
      ),
      h("div", { className: "task-header" },
        h("div", null,
          h("div", { className: "eyebrow" }, `当前主线 · ${storyRow?.unitTitle || verticalSliceGoal.subtitle}`),
          h("h1", null, storyRow?.storyAct || verticalSliceGoal.openingTitle),
          h("p", { className: "log-subtitle" }, `当前委托：${state.task.title}`)
        ),
        h("div", { className: "step-badge" }, `${state.stepIndex + 1}/${state.totalSteps}`)
      ),
      h("div", { className: "task-progress", "aria-label": "任务步骤进度" },
        state.task.steps.map((taskStep, index) => h("span", {
          key: taskStep.id,
          className: index < state.stepIndex ? "done" : index === state.stepIndex ? "active" : ""
        }))
      ),
      h("details", { className: "adventure-brief" },
        h("summary", null, "查看详细线索"),
        h("span", null, h("strong", null, "故事原因"), h("em", null, beat.storySetup || verticalSliceGoal.openingCopy)),
        h("span", null, h("strong", null, "当前步骤目标"), h("em", null, step.prompt)),
        h("span", null, h("strong", null, "完成奖励"), h("em", null, state.review ? "掌握度更新" : state.task.rewards.map((grant) => rewardLabel(grant.rewardId)).join("、"))),
        h("span", null, h("strong", null, "奖励用途"), h("em", null, beat.rewardUse || "点亮钟塔星路，并放进收藏。"))
      ),
      !state.completed && h("div", { className: "story-beat-card" },
        h("strong", null, "下一步"),
        h("span", null, isAtTaskScene ? beat.playerAction || "完成这个委托，推进星路修复。" : `进入${scene?.title || "任务场景"}，找到${anchor?.name || "任务点"}。`)
      ),
      state.completed
        ? h("div", { className: "completion-card" },
          h("strong", null, state.review ? "回访完成" : "委托完成"),
          h("span", null, state.review ? "这次没有重复发奖励，线索掌握会记录得更稳。" : "奖励已经放进小镇，可以继续接新的委托。"),
          !state.review && h("span", { className: "town-change-copy" }, beat.worldChange || "回到小镇后，钟塔会保存这次变化。"),
          state.review
            ? h("div", { className: "reward-preview compact" }, h("strong", null, "掌握度更新"))
            : h("div", { className: "reward-preview compact" },
              state.task.rewards.map((grant) => h("strong", { key: grant.rewardId }, rewardLabel(grant.rewardId)))
            ),
          hasNextTask
            ? h("button", { className: "primary", onClick: () => navigateToScene("scene_town") }, "回小镇找目标")
            : h("button", { className: "primary", onClick: () => navigateToScene("scene_town") }, "回小镇看看")
        )
        : [
          !isAtTaskScene && h("button", { key: "travel", className: "travel-button", onClick: () => navigateToScene("scene_town") }, `下一步：去${firstTaskDestination(state.task.id, scene)}`),
          optionControls,
          h("div", { key: "actionDock", className: "action-dock" },
            selectedLabels.length > 0 && h("div", { className: "selection-tray" },
              h("span", null, step.type === "order" ? "当前顺序" : step.type === "drag" ? "已放入目标区" : "已选"),
              h("strong", null, selectedLabels.join(" → "))
            ),
            stepFeedback && h("div", { className: "live-feedback" }, stepFeedback),
            h("div", { className: "action-row" },
              isSelectableSet && h("button", { className: "primary", disabled: !canConfirmSelection, onClick: onSubmit }, confirmLabel(step.type, state.selectedIds.length, requiredSelectionCount)),
              h("button", { className: "ghost", onClick: onHint }, "小提示")
            )
          )
        ],
      !isAtTaskScene && h("div", { className: "reward-preview" },
        h("span", null, "本次预览"),
        h("strong", null, state.review ? "知识回访" : `+35 XP`),
        h("strong", null, `${Math.min(completedCount + (state.review ? 0 : 1), verticalSliceTaskIds.length)}/${verticalSliceTaskIds.length} 星片`),
        state.task.rewards.map((grant) => h("strong", { key: grant.rewardId }, rewardLabel(grant.rewardId)))
      )
    ),
    h("details", { className: "mini-list compact-list" },
      h("summary", null, "查看 3 个委托"),
      h("div", { className: "mini-task-list" },
        visibleTasks.map(({ task, done, current }) => h("button", {
          key: task.id,
          className: task.id === state.task.id ? "mini-task active" : done ? "mini-task done" : current ? "mini-task current" : "mini-task locked",
          disabled: !done && !current,
          onClick: () => (done || current) && onStartTask(task.id)
        },
          h("span", null, done ? "✓" : current ? "▶" : "·"),
          h("span", null, task.title),
          h("small", null, done ? "回访" : current ? scenesById[task.sceneId]?.title || "" : "未解锁")
        ))
      )
    )
  );
}

function ReviewQueuePanel({ reviewCards, onStartTask }) {
  return h("section", { className: "review-queue-panel" },
    h("div", null,
      h("div", { className: "eyebrow" }, "回访小线索"),
      h("h2", null, "今天适合复习")
    ),
    h("div", { className: "review-card-list" },
      reviewCards.slice(0, 3).map((card) => h("button", {
        key: card.knowledgeId,
        className: "review-card-button",
        onClick: () => onStartTask(card.task.id)
      },
        h("span", null,
          h("strong", null, card.knowledge.childVisibleLabel),
          h("small", null, card.row ? `${card.row.displayCode} ${card.row.unitTitle}` : card.task.title)
        ),
        h("em", null, "回访")
      ))
    )
  );
}

function buildReviewCards(progress, reviewKnowledgeIds) {
  const completedTaskIds = new Set(progress.completedTaskIds || []);
  return reviewKnowledgeIds
    .map((knowledgeId) => {
      const knowledge = knowledgeById[knowledgeId];
      if (!knowledge) return null;
      const task = taskConfigs.find((item) =>
        completedTaskIds.has(item.id) &&
        item.steps.some((step) => step.knowledgeIds.includes(knowledgeId))
      );
      if (!task) return null;
      const row = englishStoryContentRows.find((item) => item.taskId === task.id);
      const mastery = progress.knowledgeMastery?.[knowledgeId];
      return { knowledgeId, knowledge, task, row, mastery };
    })
    .filter(Boolean)
    .sort((left, right) => {
      const leftTime = new Date(left.mastery?.nextReviewAt || 0).getTime();
      const rightTime = new Date(right.mastery?.nextReviewAt || 0).getTime();
      return leftTime - rightTime;
    });
}

function getCurrentMainTaskId(progress, activeTask) {
  const storyTaskIds = new Set(verticalSliceTaskIds);
  if (progress.activeTaskId && storyTaskIds.has(progress.activeTaskId) && !progress.completedTaskIds?.includes(progress.activeTaskId)) return progress.activeTaskId;
  if (activeTask && !progress.completedTaskIds?.includes(activeTask.id)) return activeTask.id;
  return verticalSliceTaskIds.find((taskId) => !progress.completedTaskIds?.includes(taskId)) || null;
}

function unitNodeState(row, completedTaskIds, activeTaskId) {
  if (completedTaskIds.has(row.taskId)) return "done";
  if (row.taskId === activeTaskId) return "current";
  return "locked";
}

function unitNodeLabel(state) {
  return {
    done: "回访",
    current: "开始/继续",
    locked: "未解锁"
  }[state] || "未解锁";
}

function chapterStatusClass(status) {
  return {
    已完成: "done",
    进行中: "current",
    未解锁: "locked"
  }[status] || "locked";
}

function CompleteTownPanel({ progress, reviewCards = [], onStartTask = () => {}, onRestartSlice = () => {} }) {
  return h("div", { className: "panel-stack" },
    reviewCards.length > 0 && h(ReviewQueuePanel, { reviewCards, onStartTask }),
    h("section", { className: "task-card complete-town-card" },
      h("div", { className: "eyebrow" }, "今日冒险"),
      h("h1", null, "今日冒险已完成，可回访线索"),
      h("p", { className: "task-copy" }, "第一圈星路已经点亮，3/3 星片回到钟塔。可以回小镇查看变化，也可以回访今天遇到的英语线索。"),
      h("div", { className: "reward-preview" },
        h("span", null, "今日收获"),
        h("strong", null, "第一圈星路点亮"),
        h("strong", null, "3/3 星片"),
        h("strong", null, `Lv.${progress.level || 1}`),
        h("strong", null, `${progress.stars} 星星`),
        h("strong", null, `${progress.xp || 0}/${progress.xpToNextLevel || 100} XP`)
      ),
      h("div", { className: "action-row" },
        h("button", { className: "primary", onClick: () => navigateToScene("scene_town") }, "回小镇看看"),
        h("button", { className: "ghost", onClick: onRestartSlice }, "重新试玩切片")
      )
    )
  );
}

function CorpusPanel() {
  const [bookId, setBookId] = useState(englishCorpusBooks[0]?.id || "");
  const bookUnits = englishStoryContentUnitRows.filter((unit) => unit.bookId === bookId);
  const [unitId, setUnitId] = useState(bookUnits[0]?.id || "");
  const book = englishCorpusByBook[bookId] || englishCorpusByBook[englishCorpusBooks[0]?.id];
  const selectedUnit = bookUnits.find((unit) => unit.id === unitId) || bookUnits[0] || englishStoryContentUnitRows[0];
  const selectedContentRow = englishStoryContentRows.find((row) => row.unitId === selectedUnit?.id);
  const unitRawLines = resolveCorpusItems(book, selectedUnit?.rawLineIds, "rawLines");
  const unitVocabulary = resolveCorpusItems(book, selectedUnit?.corpusVocabularyIds, "vocabulary");
  const unitSentences = resolveCorpusItems(book, selectedUnit?.corpusSentenceIds, "sentences");

  function changeBook(nextBookId) {
    const nextUnits = englishStoryContentUnitRows.filter((unit) => unit.bookId === nextBookId);
    setBookId(nextBookId);
    setUnitId(nextUnits[0]?.id || "");
  }

  return h("section", { className: "parent-panel corpus-panel" },
    h("div", { className: "eyebrow" }, "教材库"),
    h("h1", null, "英语 Unit 内容"),
    h("p", null, "按课本 Unit 查看语料、主线任务、知识点和奖励，方便核对每一关覆盖了哪些内容。"),
    h("div", { className: "report-grid" },
      h("div", null, h("strong", null, englishCorpusStats.books), h("span", null, "册资料")),
      h("div", null, h("strong", null, englishCorpusStats.vocabulary), h("span", null, "单词/短语")),
      h("div", null, h("strong", null, englishCorpusStats.sentences), h("span", null, "英文句子"))
    ),
    h("label", { className: "corpus-book-select" },
      h("span", null, "选择册别"),
      h("select", { value: book?.id || "", onChange: (event) => changeBook(event.target.value) },
        englishCorpusBooks.map((item) => h("option", { key: item.id, value: item.id }, item.title))
      )
    ),
    h("label", { className: "corpus-book-select" },
      h("span", null, "选择 Unit"),
      h("select", { value: selectedUnit?.id || "", onChange: (event) => setUnitId(event.target.value) },
        bookUnits.map((unit) => h("option", { key: unit.id, value: unit.id }, `Unit ${unit.unitNumber} ${unit.unitTitle}`))
      )
    ),
    book && h("div", { className: "corpus-book-summary" },
      h("strong", null, book.title),
      h("span", null, `${book.rawLines.length} 行原文 · ${book.vocabulary.length} 个单词/短语 · ${book.sentences.length} 个句子`)
    ),
    selectedUnit && h("div", { className: "unit-corpus-card" },
      h("div", { className: "unit-corpus-title" },
        h("strong", null, `${selectedUnit.bookTitle} Unit ${selectedUnit.unitNumber}`),
        h("span", null, selectedUnit.unitTitle)
      ),
      h("p", null, selectedUnit.storyGoal),
      h("div", { className: "unit-corpus-meta" },
        h("span", null, `任务：${selectedUnit.taskId}`),
        h("span", null, `知识：${selectedUnit.knowledgeId}`),
        h("span", null, `奖励：${selectedUnit.rewardId}`)
      ),
      h("div", { className: "unit-corpus-focus" },
        h("strong", null, selectedUnit.languageFocus),
        h("span", null, selectedUnit.grammarFocus),
        h("em", null, `${selectedUnit.interactionPattern} · ${scenesById[selectedUnit.sceneId]?.title || "任务场景"} · ${selectedContentRow?.rewardTitle || selectedUnit.rewardId}`)
      ),
      h(SceneMaterialCard, { scene: scenesById[selectedUnit.sceneId] }),
      h("div", { className: "unit-coverage-grid" },
        h("div", null, h("strong", null, selectedUnit.coverage.rawLines), h("span", null, "原始行")),
        h("div", null, h("strong", null, selectedUnit.coverage.vocabulary), h("span", null, "词汇")),
        h("div", null, h("strong", null, selectedUnit.coverage.sentences), h("span", null, "句子"))
      )
    ),
    h("h2", null, `Unit 单词 ${unitVocabulary.length}`),
    h("div", { className: "corpus-chip-grid" },
      unitVocabulary.map((item) => h("span", { key: item.id, className: "corpus-chip" }, `${item.word}：${item.translation}`))
    ),
    h("h2", null, `Unit 句子 ${unitSentences.length}`),
    h("div", { className: "corpus-sentence-list" },
      unitSentences.map((item) => h("p", { key: item.id, className: "review-item" },
        h("strong", null, item.english),
        h("span", null, item.chinese)
      ))
    ),
    h("details", { className: "unit-raw-lines" },
      h("summary", null, `原文行 ${unitRawLines.length}`),
      h("div", null,
        unitRawLines.map((item) => h("p", { key: item.id },
          h("strong", null, `L${item.lineNumber}`),
          h("span", null, item.text)
        ))
      )
    ),
    h("p", { className: "data-note" }, "内容配置来自内置英语任务、知识点和奖励表。")
  );
}

function SceneMaterialCard({ scene }) {
  if (!scene?.materials?.length) return null;
  return h("div", { className: "unit-scene-materials" },
    h("strong", null, `${scene.title}素材`),
    h("div", null,
      scene.materials.map((material) => h("span", { key: material.id },
        h("b", null, material.title),
        h("em", null, material.corpusThemes?.join(" / "))
      ))
    )
  );
}

function resolveCorpusItems(book, ids = [], field) {
  if (!book || !Array.isArray(ids)) return [];
  const source = book[field] || [];
  const byId = new Map(source.map((item) => [item.id, item]));
  return ids.map((id) => byId.get(id)).filter(Boolean);
}

function optionButtonProps(option, step, state, onChoice, onPreview, onPreviewEnd) {
  const selected = state.selectedIds?.includes(option.id);
  return {
    key: option.id,
    className: selected ? "option selected" : "option",
    draggable: step.type === "drag",
    onDragStart: (event) => event.dataTransfer.setData("text/plain", option.id),
    onMouseEnter: () => onPreview(option),
    onMouseLeave: onPreviewEnd,
    onFocus: () => onPreview(option),
    onBlur: onPreviewEnd,
    onClick: () => onChoice(option.id)
  };
}

function getOrderIndex(selectedIds, optionId) {
  const index = selectedIds.indexOf(optionId);
  return index === -1 ? "" : index + 1;
}

function confirmLabel(type, selectedCount = 0, requiredCount = 1) {
  if (selectedCount < requiredCount) return `还需选择 ${requiredCount - selectedCount} 项`;
  return {
    drag: "放好了",
    order: "顺序摆好了",
    match: "确认这组线索"
  }[type] || "确认";
}

function stepTypeLabel(type) {
  return {
    choice: "挑一挑",
    drag: "拖到目标",
    order: "排好顺序",
    match: "配成一组"
  }[type] || "试一试";
}

function stepActionCopy(type) {
  return {
    choice: "在下面选择一个答案。",
    drag: "把道具放进目标区，再让角色检查。",
    order: "按先后点道具，排好后一起检查。",
    match: "按提示选够正确项，再点确认。"
  }[type] || "完成这个小步骤。";
}

function sceneFirstActionCopy(type) {
  return {
    choice: "优先点击画面里的道具。",
    drag: "优先在画面里点道具，再确认。",
    order: "优先按顺序点击画面里的道具。",
    match: "优先在画面里挑出一组道具。"
  }[type] || "优先操作游戏画面。";
}

function stepSceneStatusCopy(type) {
  return {
    choice: "道具已摆到场景前。",
    drag: "目标区已准备好。",
    order: "按顺序摆好步骤。",
    match: "把同一组放在一起。"
  }[type] || "任务点已准备好。";
}

function rewardLabel(rewardId) {
  const reward = rewardsById[rewardId];
  if (!reward) return "新奖励";
  if (reward.type === "star") return "星星";
  if (reward.type === "heart") return "爱心";
  return reward.title;
}

function OutfitPanel({ progress, onChange }) {
  const collectionRows = englishStoryContentRows.map((row) => ({
    ...row,
    collected: isRewardCollected(row, progress)
  }));
  const collectedCount = collectionRows.filter((row) => row.collected).length;

  return h("div", { className: "outfit-collection-panel" },
    h("section", { className: "task-card" },
      h("div", { className: "eyebrow" }, "角色换装"),
      h("h1", null, "换装与收藏"),
      h("div", { className: "outfit-grid" },
        progress.unlockedOutfits.map((outfitId) => h("button", {
          key: outfitId,
          className: progress.selectedOutfitId === outfitId ? "outfit selected" : "outfit",
          onClick: () => onChange(outfitId)
        }, h("img", { className: "outfit-thumb", src: outfitImage(outfitId), alt: "" }), h("span", null, getOutfitLabel(outfitId))))
      )
    ),
    h("section", { className: "task-card reward-collection-panel" },
      h("div", { className: "eyebrow" }, "主线奖励"),
      h("h2", null, "75 关收藏进度"),
      h("div", { className: "collection-summary-grid" },
        h("div", null, h("strong", null, collectedCount), h("span", null, "已收藏")),
        h("div", null, h("strong", null, englishStoryContentRows.length), h("span", null, "总奖励")),
        h("div", null, h("strong", null, `${Math.round((collectedCount / englishStoryContentRows.length) * 100)}%`), h("span", null, "收集率"))
      ),
      h("div", { className: "reward-collection-list" },
        englishStoryContentChapterRows.map((chapter) => {
          const chapterRows = collectionRows.filter((row) => row.chapterId === chapter.id);
          const chapterCollected = chapterRows.filter((row) => row.collected).length;
          return h("div", { key: chapter.id, className: "reward-chapter-card" },
            h("div", { className: "reward-chapter-header" },
              h("div", null,
                h("strong", null, chapter.title),
                h("span", null, `${chapter.bookTitle} · ${chapter.theme}`)
              ),
              h("em", null, `${chapterCollected}/${chapterRows.length}`)
            ),
            h("div", { className: "reward-chip-grid" },
              chapterRows.map((row) => h("div", {
                key: row.rewardId,
                className: row.collected ? "reward-chip collected" : "reward-chip locked"
              },
                h("img", { src: rewardIcon(row), alt: "" }),
                h("span", null,
                  h("strong", null, row.rewardTitle),
                  h("small", null, `${row.displayCode} · ${rewardCategoryLabel(row.rewardCategory)}`),
                  h("em", null, row.collected ? "已收藏" : "未获得")
                )
              ))
            )
          );
        })
      )
    )
  );
}

function isRewardCollected(row, progress) {
  if (progress.completedTaskIds?.includes(row.taskId)) return true;
  const reward = rewardsById[row.rewardId];
  if (!reward) return false;
  if (reward.type === "outfit") return Boolean(reward.asset && !["outfit_default", "outfit_sunny", "outfit_cozy"].includes(reward.asset) && progress.unlockedOutfits?.includes(reward.asset));
  if (reward.type === "album") return progress.unlockedAlbums?.includes(reward.id);
  if (reward.type === "decoration") return progress.unlockedDecorations?.includes(reward.id);
  return false;
}

function rewardCategoryLabel(category) {
  return {
    decoration: "装饰",
    outfit: "服饰",
    album: "相册",
    badge: "徽章"
  }[category] || "奖励";
}

function rewardIcon(row) {
  return `src/assets/images/${rewardAssetFile(row.rewardId)}`;
}

function ParentPanel({ report }) {
  return h("section", { className: "parent-panel" },
    h("div", { className: "eyebrow" }, "家长摘要"),
    h("h1", null, "英语主线记录"),
    h("div", { className: "report-grid" },
      h("div", null, h("strong", null, report.completedCount), h("span", null, "完成任务")),
      h("div", null, h("strong", null, `${report.storyProgressPercent}%`), h("span", null, "主线进度")),
      h("div", null, h("strong", null, report.totalStoryTasks), h("span", null, "总关卡")),
      h("div", null, h("strong", null, report.mistakeCount), h("span", null, "温和试错")),
      h("div", null, h("strong", null, report.hintCount), h("span", null, "提示使用"))
    ),
    report.currentStoryRow
      ? h("div", { className: "parent-current-card" },
        h("strong", null, "当前主线"),
        h("span", null, `${report.currentStoryRow.bookTitle} Unit ${report.currentStoryRow.unitNumber} · ${report.currentStoryRow.unitTitle}`),
        h("small", null, report.currentStoryRow.taskTitle)
      )
      : h("div", { className: "parent-current-card" },
        h("strong", null, "当前主线"),
        h("span", null, "75 个主线委托已经全部完成"),
        h("small", null, "可以继续回访易忘线索。")
      ),
    h("h2", null, "章节进度"),
    h("div", { className: "parent-chapter-list" },
      report.chapterProgress.map((chapter) => h("div", { key: chapter.id, className: `parent-chapter-item ${chapter.status}` },
        h("div", null,
          h("strong", null, chapter.title),
          h("span", null, `${chapter.bookTitle} · ${chapter.theme}`)
        ),
        h("div", { className: "parent-chapter-meter" },
          h("span", null, `${chapter.completed}/${chapter.total}`),
          h("b", { style: { width: `${chapter.percent}%` } })
        )
      ))
    ),
    report.recentCompleted.length > 0 && [
      h("h2", { key: "recentTitle" }, "最近完成"),
      h("div", { key: "recentList", className: "parent-recent-list" },
        report.recentCompleted.map((row) => h("p", { key: row.id, className: "review-item" },
          h("strong", null, `${row.displayCode} ${row.unitTitle}`),
          h("span", null, `${row.taskTitle} · ${row.rewardTitle}`)
        ))
      )
    ],
    h("h2", null, "学习概览"),
    h("p", { className: "review-item" }, `场景：${report.sceneSummary}`),
    h("p", { className: "review-item" }, `能力：${report.subjectSummary}`),
    h("h2", null, "易忘小线索"),
    report.needsReview.length
      ? report.needsReview.map((item) => h("p", { key: item.knowledgeId, className: "review-item" }, `${item.config.childVisibleLabel}：${item.config.descriptionForParent}`))
      : h("p", { className: "review-item" }, "目前没有明显易忘点，可以继续轻松游玩。"),
    h("h2", null, "共玩建议"),
    report.suggestions.map((item) => h("p", { key: item, className: "review-item" }, item)),
    h("p", { className: "data-note" }, "数据仅保存在本机，用于学习反馈；儿童端无开放聊天、外链、广告或内购。")
  );
}

function SettingsPanel({ settings, onAudio, onReset }) {
  return h("section", { className: "task-card" },
    h("div", { className: "eyebrow" }, "设置"),
    h("h1", null, "小镇设置"),
    h("label", { className: "toggle-row" },
      h("span", null, "柔和音效"),
      h("input", { type: "checkbox", checked: settings.audio, onChange: onAudio })
    ),
    h("button", { className: "danger", onClick: onReset }, "重置本地进度")
  );
}

function ParentGate({ value, onChange, onCancel, onSubmit }) {
  return h("div", { className: "modal-backdrop", role: "dialog", "aria-modal": "true", "aria-label": "家长入口" },
    h("section", { className: "parent-gate" },
      h("div", { className: "eyebrow" }, "家长入口"),
      h("h1", null, "请大人帮忙打开"),
      h("p", null, "为了让儿童不误触，请输入 4 + 5 的结果。"),
      h("input", {
        inputMode: "numeric",
        value,
        "aria-label": "家长门答案",
        onChange: (event) => onChange(event.target.value)
      }),
      h("div", { className: "gate-actions" },
        h("button", { className: "ghost", onClick: onCancel }, "返回"),
        h("button", { className: "primary", onClick: onSubmit }, "打开摘要")
      )
    )
  );
}

function optionImage(value) {
  return h("span", { className: "option-icon has-image" },
    h("img", { src: optionAsset(value), alt: "" })
  );
}

function optionAsset(value = "") {
  const normalized = value.toLowerCase();
  if (normalized.includes("pink-dress") || normalized.includes("dress")) return "src/assets/images/outfit-dress.png";
  if (normalized.includes("yellow-shoes") || normalized.includes("shoes")) return "src/assets/images/item-shoes.png";
  if (normalized.includes("blue-hat") || normalized.includes("hat")) return "src/assets/images/item-headband.png";
  if (normalized.includes("small-bag") || normalized.includes("bag")) return "src/assets/images/item-bag.png";
  if (normalized.includes("干净") || normalized.includes("整齐") || normalized.includes("圆圆")) return "src/assets/images/anchor-mirror.png";
  if (normalized.includes("柔软")) return "src/assets/images/outfit-jacket.png";
  if (normalized.includes("飞快")) return "src/assets/images/item-shoes.png";
  if (normalized.includes("响亮")) return "src/assets/images/anchor-timer.png";
  if (normalized.includes("book")) return "src/assets/images/item-book.png";
  if (normalized.includes("card")) return "src/assets/images/item-cat-card.png";
  if (normalized.includes("flower")) return "src/assets/images/item-flower.png";
  if (normalized.includes("spoon") || normalized.includes("勺")) return "src/assets/images/anchor-cup.png";
  if (normalized.includes("搅拌")) return "src/assets/images/anchor-cup.png";
  if (normalized.includes("倒入") || normalized.includes("烤箱")) return "src/assets/images/anchor-oven.png";
  if (normalized.includes("5 分钟") || normalized.includes("10 分钟") || normalized.includes("30 分钟")) return "src/assets/images/anchor-timer.png";
  if (normalized.includes("半") || normalized.includes("杯") || normalized.includes("中间线") || normalized.includes("满满") || normalized.includes("一点点")) return "src/assets/images/anchor-cup.png";
  if (normalized.includes("米娜") || normalized.includes("露娜") || normalized.includes("邮差")) return "src/assets/images/anchor-mailbox.png";
  if (normalized.includes("书架")) return "src/assets/images/anchor-bookshelf.png";
  if (normalized.includes("桌子下")) return "src/assets/images/anchor-map.png";
  if (normalized.includes("厨房")) return "src/assets/images/scene-kitchen.png";
  if (normalized.includes("信箱")) return "src/assets/images/anchor-mailbox.png";
  return "src/assets/images/icon-star.png";
}

function outfitImage(outfitId) {
  return {
    outfit_default: "src/assets/images/character-default.png",
    outfit_sunny: "src/assets/images/outfit-dress.png",
    outfit_cozy: "src/assets/images/outfit-jacket.png",
    outfit_garden_bow: "src/assets/images/item-bow.png",
    outfit_apron: "src/assets/images/item-cake.png"
  }[outfitId] || "src/assets/images/item-bow.png";
}

createRoot(document.getElementById("root")).render(h(App));
