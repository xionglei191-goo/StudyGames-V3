const storage = new Map();
const eventListeners = new Map();

class MiniEventTarget {
  addEventListener(type, listener) {
    const listeners = eventListeners.get(type) || [];
    listeners.push(listener);
    eventListeners.set(type, listeners);
  }

  removeEventListener(type, listener) {
    eventListeners.set(type, (eventListeners.get(type) || []).filter((item) => item !== listener));
  }

  dispatchEvent(event) {
    (eventListeners.get(event.type) || []).forEach((listener) => listener(event));
    return true;
  }
}

class MiniCustomEvent {
  constructor(type, init = {}) {
    this.type = type;
    this.detail = init.detail;
  }
}

globalThis.window = new MiniEventTarget();
globalThis.window.dispatchEvent = globalThis.window.dispatchEvent.bind(globalThis.window);
globalThis.window.AudioContext = null;
globalThis.window.webkitAudioContext = null;
globalThis.CustomEvent = MiniCustomEvent;
globalThis.EventTarget = MiniEventTarget;
globalThis.localStorage = {
  getItem: (key) => storage.has(key) ? storage.get(key) : null,
  setItem: (key, value) => storage.set(key, String(value)),
  removeItem: (key) => storage.delete(key)
};

const { resetAllData, loadProgress, loadTelemetry } = await import("../src/data/progressStore.js");
const { taskRuntime } = await import("../src/game/TaskRuntime.js");
const { getVerticalSliceCompletedCount, isVerticalSliceComplete, verticalSliceTaskIds } = await import("../src/content/verticalSlice.js");
const { tasksById } = await import("../src/content/tasks.js");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function completeCurrentStep() {
  const state = taskRuntime.getState();
  assert(state?.step, "TaskRuntime has no active step.");
  const correctIds = state.step.correctOptionIds || [];
  assert(correctIds.length > 0, `Step ${state.step.id} has no correctOptionIds.`);

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

resetAllData();

assert(globalThis.window, "window mock was not installed.");
assert(globalThis.localStorage, "localStorage mock was not installed.");
assert(globalThis.CustomEvent, "CustomEvent mock was not installed.");
assert(globalThis.performance?.now, "performance.now is unavailable.");
assert(verticalSliceTaskIds.length === 3, "P0 should contain exactly three vertical slice tasks.");
assert(verticalSliceTaskIds.every((taskId) => tasksById[taskId]), "Every P0 task id should resolve in tasksById.");

const defaultProgress = loadProgress();
assert(defaultProgress.level === 1, "Default progress should start at level 1.");
assert(defaultProgress.xp === 0, "Default progress should start at 0 XP.");
assert(defaultProgress.starShard.total === 3, "Default star shard total should be 3.");
assert(defaultProgress.starShard.collectedIds.length === 0, "Default progress should not have collected star shards.");
assert(defaultProgress.activeTaskId === verticalSliceTaskIds[0], "Default activeTaskId should point to the first P0 task.");

const firstTaskState = taskRuntime.start(verticalSliceTaskIds[0]);
assert(firstTaskState.step.id === "step_001", "First P0 task did not start at step_001.");
taskRuntime.choose(firstTaskState.step.correctOptionIds[0]);
taskRuntime.choose(taskRuntime.getState().step.correctOptionIds[0]);
const matchState = taskRuntime.getState();
assert(matchState.step.type === "match", "First P0 task step 3 should be a match step.");
assert(matchState.step.correctOptionIds.length === 2, "First P0 task step 3 should require two selections.");
const firstTaskResult = completeCurrentStep();
assert(firstTaskResult.completed, "First P0 task did not complete after submitting match selections.");

const firstProgress = loadProgress();
assert(firstProgress.completedTaskIds.length === 1, "First P0 task was not recorded as completed.");
assert(firstProgress.starShard.collectedIds.length === 1, "First P0 task did not collect one star shard.");

const remainingResults = verticalSliceTaskIds.slice(1).map((taskId) => completeTask(taskId));
const progress = loadProgress();
const telemetryBeforeReview = loadTelemetry();
const rewardTelemetryBeforeReview = telemetryBeforeReview.filter((item) => item.type === "reward_granted").length;
const starsBeforeReview = progress.stars;
const heartsBeforeReview = progress.hearts;
const masteryAttemptsBeforeReview = Object.fromEntries(
  Object.entries(progress.knowledgeMastery || {}).map(([knowledgeId, item]) => [knowledgeId, item.attempts || 0])
);
const reviewResult = completeTask(verticalSliceTaskIds[0]);
const reviewProgress = loadProgress();
const telemetryAfterReview = loadTelemetry();
const rewardTelemetryAfterReview = telemetryAfterReview.filter((item) => item.type === "reward_granted").length;

const result = {
  ok: true,
  firstTaskSettlement: firstTaskResult.settlement,
  remainingSettlements: remainingResults.map((item) => item.settlement),
  final: {
    completedTaskIds: progress.completedTaskIds,
    level: progress.level,
    xp: progress.xp,
    starShard: progress.starShard,
    stars: progress.stars,
    hearts: progress.hearts,
    activeTaskId: progress.activeTaskId,
    verticalSliceComplete: isVerticalSliceComplete(progress),
    verticalSliceCompletedCount: getVerticalSliceCompletedCount(progress)
  },
  reviewSettlement: reviewResult.settlement,
  afterReview: {
    completedTaskIds: reviewProgress.completedTaskIds,
    level: reviewProgress.level,
    xp: reviewProgress.xp,
    starShard: reviewProgress.starShard,
    stars: reviewProgress.stars,
    hearts: reviewProgress.hearts,
    rewardTelemetryBeforeReview,
    rewardTelemetryAfterReview
  }
};

assert(firstTaskResult.review === false, "First P0 completion should not be a review.");
assert(firstTaskResult.settlement.xpGained === 35, "First P0 task should grant 35 XP.");
remainingResults.forEach((item, index) => {
  assert(item.completed === true, `P0 task ${index + 2} did not complete.`);
  assert(item.review === false, `P0 task ${index + 2} should not be a review.`);
  assert(item.settlement.xpGained === 35, `P0 task ${index + 2} should grant 35 XP.`);
});
assert(progress.completedTaskIds.length === 3, "P0 should complete exactly three vertical slice tasks.");
assert(verticalSliceTaskIds.every((taskId) => progress.completedTaskIds.includes(taskId)), "Not all P0 task ids were completed.");
assert(isVerticalSliceComplete(progress), "P0 completion should satisfy isVerticalSliceComplete.");
assert(getVerticalSliceCompletedCount(progress) === 3, "P0 completion count should be 3.");
assert(progress.level === 2, "P0 completion should raise the player to level 2.");
assert(progress.xp === 5, "P0 completion should leave 5 XP after level up.");
assert(progress.starShard.total === 3, "P0 star shard total should be 3.");
assert(progress.starShard.collectedIds.length === 3, "P0 should collect 3/3 star shards.");
assert(progress.starShard.collectedIds.join("|") === [
  "reward_eng_g3b_u01_star",
  "reward_eng_g3b_u02_star",
  "reward_eng_g3b_u03_star"
].join("|"), "P0 star shard ids did not match expected reward ids.");
assert(progress.activeTaskId === null, "P0 completion should clear activeTaskId.");
assert(reviewResult.review === true, "Replaying a completed P0 task should be marked as review.");
assert(reviewResult.settlement.xpGained === 0, "Review should not grant XP.");
assert(reviewProgress.level === 2, "Review should not change level.");
assert(reviewProgress.xp === 5, "Review should not change XP.");
assert(reviewProgress.starShard.collectedIds.length === 3, "Review should not grant duplicate star shards.");
assert(reviewProgress.stars === starsBeforeReview, "Review should not grant duplicate stars.");
assert(reviewProgress.hearts === heartsBeforeReview, "Review should not grant duplicate hearts.");
assert(rewardTelemetryAfterReview === rewardTelemetryBeforeReview, "Review should not log duplicate reward_granted telemetry.");
Object.entries(masteryAttemptsBeforeReview).forEach(([knowledgeId, attempts]) => {
  const nextAttempts = reviewProgress.knowledgeMastery?.[knowledgeId]?.attempts || 0;
  if (tasksById[verticalSliceTaskIds[0]].steps.some((step) => step.knowledgeIds.includes(knowledgeId))) {
    assert(nextAttempts > attempts, `Review should increase mastery attempts for ${knowledgeId}.`);
  }
});

console.log(JSON.stringify(result, null, 2));
