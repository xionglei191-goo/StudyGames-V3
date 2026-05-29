import { taskConfigs, tasksById } from "../content/tasks.js";
import { verticalSliceTaskIds } from "../content/verticalSlice.js";
import { applyGrowthReward, applyRewards, loadProgress, logTelemetry, saveProgress, updateMasteryForTask } from "../data/progressStore.js";
import { playSound } from "./AudioSystem.js";
import { eventBus } from "./EventBus.js";

export class TaskRuntime {
  constructor() {
    this.task = null;
    this.stepIndex = 0;
    this.startedAt = 0;
    this.mistakes = 0;
    this.hints = 0;
    this.selectedIds = [];
  }

  getCurrentTask(progress = loadProgress()) {
    const reviewTask = getDueReviewTask(progress);
    if (reviewTask) return reviewTask;
    const activeTask = tasksById[progress.activeTaskId];
    if (activeTask && verticalSliceTaskIds.includes(activeTask.id) && !progress.completedTaskIds.includes(activeTask.id)) return activeTask;
    return getNextUnfinishedTask(progress);
  }

  getNextTaskForScene(sceneId, progress = loadProgress()) {
    return getNextUnfinishedTask(progress, sceneId);
  }

  start(taskId) {
    this.task = tasksById[taskId] || taskConfigs[0];
    this.stepIndex = 0;
    this.startedAt = performance.now();
    this.mistakes = 0;
    this.hints = 0;
    this.selectedIds = [];
    logTelemetry({ type: "task_started", taskId: this.task.id, sceneId: this.task.sceneId });
    eventBus.emit("task:started", this.getState());
    return this.getState();
  }

  getState() {
    if (!this.task) return null;
    return {
      task: this.task,
      step: this.task.steps[this.stepIndex],
      stepIndex: this.stepIndex,
      totalSteps: this.task.steps.length,
      mistakes: this.mistakes,
      hints: this.hints,
      selectedIds: [...this.selectedIds]
    };
  }

  useHint() {
    if (!this.task) return null;
    this.hints += 1;
    const step = this.task.steps[this.stepIndex];
    logTelemetry({
      type: "hint_used",
      taskId: this.task.id,
      sceneId: this.task.sceneId,
      knowledgeIds: step.knowledgeIds,
      anchorId: step.anchorId,
      value: step.hintCopy
    });
    eventBus.emit("task:hint-used", { task: this.task, step, hint: step.hintCopy, state: this.getState() });
    eventBus.emit("task:progress", this.getState());
    return step.hintCopy;
  }

  choose(optionId) {
    if (!this.task) return { ok: false, completed: false };
    const step = this.task.steps[this.stepIndex];
    const isMulti = step.type === "match";
    const isOrder = step.type === "order";
    const isDrag = step.type === "drag";

    if (isOrder) {
      if (this.selectedIds.includes(optionId)) {
        this.selectedIds = this.selectedIds.filter((id) => id !== optionId);
      } else if (this.selectedIds.length < step.correctOptionIds.length) {
        this.selectedIds = [...this.selectedIds, optionId];
      }
      eventBus.emit("task:progress", this.getState());
      return { ok: true, pending: true, completed: false };
    }

    if (isDrag) {
      this.selectedIds = [optionId];
      eventBus.emit("task:progress", this.getState());
      return { ok: true, pending: true, completed: false };
    }

    if (isMulti) {
      if (this.selectedIds.includes(optionId)) {
        this.selectedIds = this.selectedIds.filter((id) => id !== optionId);
      } else {
        this.selectedIds = [...this.selectedIds, optionId];
      }
      eventBus.emit("task:progress", this.getState());
      return { ok: true, pending: true, completed: false };
    }

    return this.evaluateStep([optionId]);
  }

  submitSelection() {
    return this.evaluateStep(this.selectedIds);
  }

  evaluateStep(optionIds) {
    const step = this.task.steps[this.stepIndex];
    const expected = step.type === "order" ? step.correctOptionIds.join("|") : [...step.correctOptionIds].sort().join("|");
    const actual = step.type === "order" ? optionIds.join("|") : [...optionIds].sort().join("|");
    const ok = expected === actual;

    logTelemetry({
      type: "choice_made",
      taskId: this.task.id,
      sceneId: this.task.sceneId,
      knowledgeIds: step.knowledgeIds,
      anchorId: step.anchorId,
      value: optionIds.join(",")
    });

    if (!ok) {
      this.mistakes += 1;
      this.selectedIds = [];
      playSound("error");
      logTelemetry({
        type: "mistake_made",
        taskId: this.task.id,
        sceneId: this.task.sceneId,
        knowledgeIds: step.knowledgeIds,
        anchorId: step.anchorId,
        value: optionIds.join(",")
      });
      const state = this.getState();
      eventBus.emit("task:choice-wrong", { task: this.task, step, optionIds, state });
      eventBus.emit("task:progress", state);
      return { ok: false, message: this.task.retryCopy, completed: false };
    }

    const completedStep = step;
    this.stepIndex += 1;
    this.selectedIds = [];
    playSound(this.stepIndex + 1 >= this.task.steps.length ? "reward" : "success");
    eventBus.emit("task:step-correct", {
      task: this.task,
      step: completedStep,
      optionIds,
      nextStep: this.task.steps[this.stepIndex],
      completed: this.stepIndex >= this.task.steps.length
    });
    if (this.stepIndex >= this.task.steps.length) {
      return this.complete();
    }

    eventBus.emit("task:progress", this.getState());
    return { ok: true, completed: false };
  }

  complete() {
    const durationMs = performance.now() - this.startedAt;
    const progress = loadProgress();
    const alreadyCompleted = progress.completedTaskIds.includes(this.task.id);
    let next = {
      ...progress,
      completedTaskIds: [...new Set([...progress.completedTaskIds, this.task.id])]
    };
    let settlement = createEmptySettlement(progress);

    if (!alreadyCompleted) {
      next = applyRewards(next, this.task.rewards);
      const growthReward = applyGrowthReward(next, this.task);
      next = growthReward.progress;
      settlement = growthReward.settlement;
    }
    next = updateMasteryForTask(next, this.task, {
      durationMs,
      mistakes: this.mistakes,
      hints: this.hints
    });

    const nextTask = getNextUnfinishedTask(next);
    next.activeTaskId = nextTask ? nextTask.id : null;
    next = saveProgress(next);

    logTelemetry({
      type: "task_completed",
      taskId: this.task.id,
      sceneId: this.task.sceneId,
      knowledgeIds: [...new Set(this.task.steps.flatMap((step) => step.knowledgeIds))],
      review: alreadyCompleted,
      durationMs: Math.round(durationMs)
    });

    const state = this.getState();
    eventBus.emit("task:completed", { task: this.task, progress: next, state, review: alreadyCompleted, settlement });
    return { ok: true, completed: true, progress: next, task: this.task, review: alreadyCompleted, settlement };
  }
}

export const taskRuntime = new TaskRuntime();

function getDueReviewTask(progress) {
  const completedSlice = verticalSliceTaskIds.every((taskId) => progress.completedTaskIds?.includes(taskId));
  if (!completedSlice) return null;
  const now = Date.now();
  const dueKnowledgeIds = Object.values(progress.knowledgeMastery || {})
    .filter((item) => item.nextReviewAt && new Date(item.nextReviewAt).getTime() <= now)
    .map((item) => item.knowledgeId);

  if (!dueKnowledgeIds.length) return null;
  return taskConfigs.find((task) =>
    task.steps.some((step) => step.knowledgeIds.some((knowledgeId) => dueKnowledgeIds.includes(knowledgeId)))
  ) || null;
}

function getNextUnfinishedTask(progress, sceneId = null) {
  return taskConfigs.find((task) =>
    verticalSliceTaskIds.includes(task.id) &&
    (!sceneId || task.sceneId === sceneId) &&
    !progress.completedTaskIds.includes(task.id)
  ) || null;
}

function createEmptySettlement(progress) {
  return {
    xpGained: 0,
    levelBefore: progress.level,
    levelAfter: progress.level,
    leveledUp: false,
    starShardId: null,
    starShardCollectedCount: progress.starShard?.collectedIds?.length || 0,
    starShardTotal: progress.starShard?.total || 3
  };
}
