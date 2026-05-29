import { beforeEach, describe, expect, it } from "vitest";
import { resetAllData, loadProgress, loadTelemetry } from "../data/progressStore.js";
import { taskRuntime } from "./TaskRuntime.js";
import { verticalSliceTaskIds, isVerticalSliceComplete, getVerticalSliceCompletedCount } from "../content/verticalSlice.js";

const storage = new Map();

globalThis.localStorage = {
  getItem: (key) => storage.has(key) ? storage.get(key) : null,
  setItem: (key, value) => storage.set(key, String(value)),
  removeItem: (key) => storage.delete(key),
  clear: () => storage.clear()
};

globalThis.window = {
  AudioContext: null,
  webkitAudioContext: null,
  dispatchEvent: () => true
};

globalThis.CustomEvent = class CustomEvent extends Event {
  constructor(type, init = {}) {
    super(type);
    this.detail = init.detail;
  }
};

function completeCurrentStep() {
  const state = taskRuntime.getState();
  const correctIds = state.step.correctOptionIds || [];

  if (state.step.type === "choice") {
    return taskRuntime.choose(correctIds[0]);
  }

  correctIds.forEach((optionId) => taskRuntime.choose(optionId));
  return taskRuntime.submitSelection();
}

function completeTask(taskId) {
  taskRuntime.start(taskId);
  let result = { completed: false };

  while (!result.completed) {
    result = completeCurrentStep();
  }

  return result;
}

describe("P0 task runtime", () => {
  beforeEach(() => {
    localStorage.clear();
    resetAllData();
  });

  it("completes the three-task RPG-lite slice and grants first-time growth rewards", () => {
    const settlements = verticalSliceTaskIds.map((taskId) => completeTask(taskId).settlement);
    const progress = loadProgress();

    expect(progress.completedTaskIds).toEqual(verticalSliceTaskIds);
    expect(isVerticalSliceComplete(progress)).toBe(true);
    expect(getVerticalSliceCompletedCount(progress)).toBe(3);
    expect(progress.level).toBe(2);
    expect(progress.xp).toBe(5);
    expect(progress.starShard).toEqual({
      total: 3,
      collectedIds: [
        "reward_eng_g3b_u01_star",
        "reward_eng_g3b_u02_star",
        "reward_eng_g3b_u03_star"
      ]
    });
    expect(progress.activeTaskId).toBe(null);
    expect(settlements.map((settlement) => settlement.xpGained)).toEqual([35, 35, 35]);
    expect(settlements.at(-1).leveledUp).toBe(true);
  });

  it("does not grant duplicate XP, stars, hearts, shards, or reward telemetry on review", () => {
    verticalSliceTaskIds.forEach((taskId) => completeTask(taskId));
    const progressBeforeReview = loadProgress();
    const rewardTelemetryBeforeReview = loadTelemetry().filter((event) => event.type === "reward_granted").length;

    const reviewResult = completeTask(verticalSliceTaskIds[0]);
    const progressAfterReview = loadProgress();
    const rewardTelemetryAfterReview = loadTelemetry().filter((event) => event.type === "reward_granted").length;

    expect(reviewResult.review).toBe(true);
    expect(reviewResult.settlement.xpGained).toBe(0);
    expect(progressAfterReview.level).toBe(progressBeforeReview.level);
    expect(progressAfterReview.xp).toBe(progressBeforeReview.xp);
    expect(progressAfterReview.stars).toBe(progressBeforeReview.stars);
    expect(progressAfterReview.hearts).toBe(progressBeforeReview.hearts);
    expect(progressAfterReview.starShard.collectedIds).toEqual(progressBeforeReview.starShard.collectedIds);
    expect(rewardTelemetryAfterReview).toBe(rewardTelemetryBeforeReview);
  });
});
