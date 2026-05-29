import { knowledgeConfigs } from "../content/knowledge.js";
import { rewardsById } from "../content/rewards.js";
import { verticalSliceTaskIds } from "../content/verticalSlice.js";

const STORAGE_VERSION = "0.1.0";
const PROGRESS_KEY = "studygame.progress";
const TELEMETRY_KEY = "studygame.telemetry";
const SETTINGS_KEY = "studygame.settings";
const VERSION_KEY = "studygame.version";
const TELEMETRY_LIMIT = 1000;
const XP_PER_P0_TASK = 35;
const XP_TO_NEXT_LEVEL = 100;
const STAR_SHARD_TOTAL = 3;

const defaultOutfits = ["outfit_default", "outfit_sunny", "outfit_cozy"];
const p0StarShardIds = verticalSliceTaskIds.map((taskId) => taskId.replace(/^task_/, "reward_").replace(/_main$/, "_star"));
const p0StarShardByTaskId = Object.fromEntries(verticalSliceTaskIds.map((taskId, index) => [taskId, p0StarShardIds[index]]));

export function createDefaultProgress() {
  return {
    playerId: `local_${Math.random().toString(36).slice(2, 9)}`,
    nickname: "小设计师",
    stars: 0,
    hearts: 3,
    level: 1,
    xp: 0,
    xpToNextLevel: XP_TO_NEXT_LEVEL,
    title: "星路修复员",
    starShard: {
      total: STAR_SHARD_TOTAL,
      collectedIds: []
    },
    unlockedOutfits: [...defaultOutfits],
    selectedOutfitId: "outfit_default",
    unlockedDecorations: [],
    unlockedAlbums: [],
    completedTaskIds: [],
    activeTaskId: "task_eng_g3b_u01_main",
    knowledgeMastery: {},
    lastPlayedAt: new Date().toISOString()
  };
}

export function loadProgress() {
  try {
    const raw = localStorage.getItem(PROGRESS_KEY);
    if (!raw) return createDefaultProgress();
    return normalizeProgress(JSON.parse(raw));
  } catch {
    return createDefaultProgress();
  }
}

export function normalizeProgress(progress = {}) {
  const defaults = createDefaultProgress();
  const next = { ...defaults, ...(progress || {}) };
  next.stars = safeNumber(next.stars, defaults.stars);
  next.hearts = safeNumber(next.hearts, defaults.hearts);
  next.level = Math.max(1, Math.floor(safeNumber(next.level, defaults.level)));
  next.xp = Math.max(0, Math.floor(safeNumber(next.xp, defaults.xp)));
  next.xpToNextLevel = XP_TO_NEXT_LEVEL;
  next.title = typeof next.title === "string" && next.title ? next.title : defaults.title;
  next.unlockedOutfits = uniqueArray(next.unlockedOutfits, defaultOutfits);
  next.selectedOutfitId = typeof next.selectedOutfitId === "string" ? next.selectedOutfitId : defaults.selectedOutfitId;
  next.unlockedDecorations = uniqueArray(next.unlockedDecorations);
  next.unlockedAlbums = uniqueArray(next.unlockedAlbums);
  next.completedTaskIds = uniqueArray(next.completedTaskIds);
  next.knowledgeMastery = next.knowledgeMastery && typeof next.knowledgeMastery === "object" ? next.knowledgeMastery : {};

  const collectedIds = uniqueArray(next.starShard?.collectedIds);
  inferCollectedStarShardIds(next).forEach((id) => collectedIds.push(id));
  next.starShard = {
    total: STAR_SHARD_TOTAL,
    collectedIds: uniqueArray(collectedIds).filter((id) => p0StarShardIds.includes(id))
  };

  return next;
}

export function saveProgress(progress) {
  const next = { ...progress, lastPlayedAt: new Date().toISOString() };
  localStorage.setItem(PROGRESS_KEY, JSON.stringify(next));
  localStorage.setItem(VERSION_KEY, STORAGE_VERSION);
  window.dispatchEvent(new CustomEvent("studygame:progress", { detail: next }));
  return next;
}

export function loadTelemetry() {
  try {
    return JSON.parse(localStorage.getItem(TELEMETRY_KEY) || "[]");
  } catch {
    return [];
  }
}

export function logTelemetry(event) {
  const telemetry = loadTelemetry();
  const nextEvent = {
    id: `evt_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
    createdAt: new Date().toISOString(),
    ...event
  };
  telemetry.push(nextEvent);
  localStorage.setItem(TELEMETRY_KEY, JSON.stringify(telemetry.slice(-TELEMETRY_LIMIT)));
  window.dispatchEvent(new CustomEvent("studygame:telemetry", { detail: nextEvent }));
  return nextEvent;
}

export function loadSettings() {
  try {
    return { audio: true, ...JSON.parse(localStorage.getItem(SETTINGS_KEY) || "{}") };
  } catch {
    return { audio: true };
  }
}

export function saveSettings(settings) {
  localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  window.dispatchEvent(new CustomEvent("studygame:settings", { detail: settings }));
  return settings;
}

export function resetAllData() {
  localStorage.removeItem(PROGRESS_KEY);
  localStorage.removeItem(TELEMETRY_KEY);
  localStorage.removeItem(SETTINGS_KEY);
  localStorage.setItem(VERSION_KEY, STORAGE_VERSION);
  return saveProgress(createDefaultProgress());
}

export function applyRewards(progress, rewards) {
  const next = { ...progress };
  next.unlockedOutfits = [...new Set(next.unlockedOutfits || defaultOutfits)];
  next.unlockedDecorations = [...new Set(next.unlockedDecorations || [])];
  next.unlockedAlbums = [...new Set(next.unlockedAlbums || [])];

  rewards.forEach((grant) => {
    const reward = rewardsById[grant.rewardId];
    if (!reward) return;
    if (reward.type === "star") next.stars += grant.quantity;
    if (reward.type === "heart") next.hearts += grant.quantity;
    if (reward.type === "outfit" && reward.asset) {
      next.unlockedOutfits.push(reward.asset);
      next.selectedOutfitId = reward.asset;
    }
    if (reward.type === "decoration") next.unlockedDecorations.push(reward.id);
    if (reward.type === "album") next.unlockedAlbums.push(reward.id);
    logTelemetry({ type: "reward_granted", value: reward.id });
  });

  next.unlockedOutfits = [...new Set(next.unlockedOutfits)];
  next.unlockedDecorations = [...new Set(next.unlockedDecorations)];
  next.unlockedAlbums = [...new Set(next.unlockedAlbums)];
  return next;
}

export function applyGrowthReward(progress, task) {
  const next = normalizeProgress(progress);
  const starShardId = p0StarShardByTaskId[task?.id] || null;
  const levelBefore = next.level;
  const baselineCollectedIds = progress?.starShard && Array.isArray(progress.starShard.collectedIds)
    ? uniqueArray(progress.starShard.collectedIds).filter((id) => p0StarShardIds.includes(id))
    : inferCollectedStarShardIds(progress);
  const alreadyCollected = Boolean(starShardId && baselineCollectedIds.includes(starShardId));
  const xpGained = starShardId && !alreadyCollected ? XP_PER_P0_TASK : 0;

  if (starShardId && !alreadyCollected) {
    next.starShard = {
      total: STAR_SHARD_TOTAL,
      collectedIds: uniqueArray([...next.starShard.collectedIds, starShardId])
    };
  }

  next.xp += xpGained;
  while (next.xp >= XP_TO_NEXT_LEVEL) {
    next.xp -= XP_TO_NEXT_LEVEL;
    next.level += 1;
  }
  next.xpToNextLevel = XP_TO_NEXT_LEVEL;

  const settlement = {
    xpGained,
    levelBefore,
    levelAfter: next.level,
    leveledUp: next.level > levelBefore,
    starShardId,
    starShardCollectedCount: next.starShard.collectedIds.length,
    starShardTotal: next.starShard.total
  };

  return { progress: next, settlement };
}

export function updateMasteryForTask(progress, task, stats) {
  const knowledgeIds = [...new Set(task.steps.flatMap((step) => step.knowledgeIds))];
  const next = { ...progress, knowledgeMastery: { ...(progress.knowledgeMastery || {}) } };

  knowledgeIds.forEach((knowledgeId) => {
    const previous = next.knowledgeMastery[knowledgeId] || {
      knowledgeId,
      score: 60,
      attempts: 0,
      correctCount: 0,
      hintCount: 0,
      status: "new"
    };

    const fastBonus = stats.durationMs < task.estimatedMinutes * 60 * 1000 ? 5 : 0;
    const noHintBonus = stats.hints === 0 ? 10 : 0;
    const rawScore = previous.score + 20 + noHintBonus + fastBonus - stats.mistakes * 10 - stats.hints * 8;
    const score = Math.max(0, Math.min(100, Math.round((previous.score + rawScore) / 2)));
    const status = score < 50 ? "learning" : score < 75 ? "review" : "stable";
    const nextReviewAt = getNextReviewAt(status);

    next.knowledgeMastery[knowledgeId] = {
      knowledgeId,
      score,
      attempts: previous.attempts + 1,
      correctCount: previous.correctCount + 1,
      hintCount: previous.hintCount + stats.hints,
      lastSeenAt: new Date().toISOString(),
      nextReviewAt,
      status
    };
  });

  return next;
}

function getNextReviewAt(status) {
  const date = new Date();
  if (status === "learning") date.setHours(date.getHours() + 1);
  if (status === "review") date.setDate(date.getDate() + 1);
  if (status === "stable") date.setDate(date.getDate() + 3);
  return date.toISOString();
}

export function getReviewKnowledgeIds(progress) {
  const now = Date.now();
  return Object.values(progress.knowledgeMastery || {})
    .filter((item) => item.nextReviewAt && new Date(item.nextReviewAt).getTime() <= now)
    .map((item) => item.knowledgeId);
}

export function getSubjectLabel(subject) {
  return {
    chinese: "语文",
    math: "数学",
    english: "英语"
  }[subject] || subject;
}

export function getOutfitLabel(outfitId) {
  return {
    outfit_default: "日常裙装",
    outfit_sunny: "阳光套装",
    outfit_cozy: "软绒外套",
    outfit_garden_bow: "花园蝴蝶结",
    outfit_apron: "点心围裙"
  }[outfitId] || "新服饰";
}

export function getAllConfiguredKnowledge() {
  return knowledgeConfigs;
}

function inferCollectedStarShardIds(progress) {
  const completedTaskIds = new Set(progress.completedTaskIds || []);
  const unlockedRewardIds = new Set([
    ...(progress.unlockedDecorations || []),
    ...(progress.unlockedAlbums || []),
    ...(progress.unlockedOutfits || [])
  ]);

  return p0StarShardIds.filter((rewardId, index) =>
    completedTaskIds.has(verticalSliceTaskIds[index]) || unlockedRewardIds.has(rewardId)
  );
}

function safeNumber(value, fallback) {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function uniqueArray(value, fallback = []) {
  return [...new Set(Array.isArray(value) ? value : fallback)];
}
