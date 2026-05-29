import { access, readdir, readFile } from "node:fs/promises";
import { inflateSync } from "node:zlib";
import { knowledgeConfigs } from "../src/content/knowledge.js";
import { rewardConfigs } from "../src/content/rewards.js";
import { sceneConfigs } from "../src/content/scenes.js";
import { assetFiles, imageAssetsByKey, rewardAssetFile, rewardAssetKey, sceneAssetFiles, transparentAssetFiles } from "../src/content/assetCatalog.js";
import { taskConfigs } from "../src/content/tasks.js";
import { englishCorpusByBook } from "../src/content/englishCorpus.js";
import { englishStoryContentChapterRows, englishStoryContentRows, englishStoryContentUnitRows } from "../src/content/englishStoryContentTable.js";
import { validateContent } from "../src/content/validators.js";

const store = new Map();
globalThis.window = new EventTarget();
globalThis.CustomEvent = class CustomEvent extends Event {
  constructor(type, init = {}) {
    super(type);
    this.detail = init.detail;
  }
};
globalThis.localStorage = {
  getItem: (key) => (store.has(key) ? store.get(key) : null),
  setItem: (key, value) => store.set(key, String(value)),
  removeItem: (key) => store.delete(key)
};
globalThis.performance = { now: () => Date.now() };

const { loadProgress, loadTelemetry, resetAllData } = await import("../src/data/progressStore.js");
const { taskRuntime } = await import("../src/game/TaskRuntime.js");

const failures = [];
const sceneIds = new Set(sceneConfigs.map((scene) => scene.id));
const anchorIds = new Set(sceneConfigs.flatMap((scene) => scene.anchors.map((anchor) => anchor.id)));
const knowledgeIds = new Set(knowledgeConfigs.map((knowledge) => knowledge.id));
const rewardIds = new Set(rewardConfigs.map((reward) => reward.id));
const requiredAssetFiles = assetFiles;
const sceneAssetFileSet = new Set(sceneAssetFiles);
const transparentAssetFileSet = new Set(transparentAssetFiles);

check("content validator passes", validateContent().length === 0);
check("new English flow has seventy-five playable tasks", taskConfigs.length === 75);
check("new English flow starts at g3b unit 1", taskConfigs[0]?.id === "task_eng_g3b_u01_main");
check("new English flow covers all story chapters", taskConfigs[10]?.id === "task_eng_g4a_u01_main" && taskConfigs[20]?.id === "task_eng_g4b_u01_main" && taskConfigs[30]?.id === "task_eng_g5a_u01_main" && taskConfigs[42]?.id === "task_eng_g5b_u01_main" && taskConfigs[54]?.id === "task_eng_g6a_u01_main" && taskConfigs[66]?.id === "task_eng_g6b_u01_main" && taskConfigs.at(-1)?.id === "task_eng_g6b_u09_main");
check("new English flow only exposes story tasks", taskConfigs.every((task) => /^task_eng_g(3b|4a|4b|5a|5b|6a|6b)_u\d\d_main$/.test(task.id)));
check("upper-grade story slices are handcrafted", taskConfigs
  .filter((task) => /^task_eng_g(5b|6a|6b)_u\d\d_main$/.test(task.id))
  .every((task) => !task.steps.some((step) => step.prompt.includes("读委托句"))));
const expectedThemeSceneIds = ["scene_wardrobe", "scene_kitchen", "scene_school", "scene_city", "scene_festival", "scene_nature", "scene_health", "scene_study"];
check("expanded textbook theme scenes", expectedThemeSceneIds.every((id) => sceneIds.has(id)));
check("story rows use expanded textbook scenes", new Set(englishStoryContentRows.map((row) => row.sceneId)).size >= 8);
check("expanded scenes carry textbook material sets", sceneConfigs
  .filter((scene) => scene.id !== "scene_town")
  .every((scene) => scene.materials?.length >= 3 && scene.materials.every((material) => material.title && material.imageKey && material.corpusThemes?.length)));
check("estimated playtime covers the full story flow", taskConfigs.reduce((sum, task) => sum + task.estimatedMinutes, 0) >= 380);
check("all playable tasks carry source vocabulary coverage", taskConfigs.every((task) => task.corpusVocabularyIds?.length > 0));
check("all playable tasks carry source sentence coverage", taskConfigs.every((task) => task.corpusSentenceIds?.length > 0));
check("all playable tasks carry source raw line coverage", taskConfigs.every((task) => task.rawLineIds?.length > 0));
check("reward collection table has seven chapters", englishStoryContentChapterRows.length === 7);
check("reward collection table has seventy-five rows", englishStoryContentRows.length === 75);
check("reward collection rows link tasks", englishStoryContentRows.every((row) => taskConfigs.some((task) => task.id === row.taskId)));
check("reward collection rows link rewards", englishStoryContentRows.every((row) => rewardIds.has(row.rewardId)));
check("corpus unit table has seventy-five rows", englishStoryContentUnitRows.length === 75);
check("corpus unit raw line ids resolve", englishStoryContentUnitRows.every((unit) => resolveCorpusCount(unit, "rawLineIds", "rawLines") === unit.rawLineIds.length));
check("corpus unit vocabulary ids resolve", englishStoryContentUnitRows.every((unit) => resolveCorpusCount(unit, "corpusVocabularyIds", "vocabulary") === unit.corpusVocabularyIds.length));
check("corpus unit sentence ids resolve", englishStoryContentUnitRows.every((unit) => resolveCorpusCount(unit, "corpusSentenceIds", "sentences") === unit.corpusSentenceIds.length));

for (const knowledge of knowledgeConfigs) {
  check(`${knowledge.id} has parent explanation`, Boolean(knowledge.descriptionForParent));
  check(`${knowledge.id} has anchor`, knowledge.anchorIds.length > 0 && knowledge.anchorIds.every((id) => anchorIds.has(id)));
}

for (const task of taskConfigs) {
  check(`${task.id} scene exists`, sceneIds.has(task.sceneId));
  check(`${task.id} has child copy`, [task.introCopy, task.successCopy, task.retryCopy].every((text) => text && text.length <= 80));
  check(`${task.id} has rewards`, task.rewards.length > 0 && task.rewards.every((grant) => rewardIds.has(grant.rewardId)));

  for (const step of task.steps) {
    check(`${task.id}/${step.id} anchor exists`, anchorIds.has(step.anchorId));
    check(`${task.id}/${step.id} knowledge exists`, step.knowledgeIds.length > 0 && step.knowledgeIds.every((id) => knowledgeIds.has(id)));
    check(`${task.id}/${step.id} answers exist`, step.correctOptionIds.every((id) => step.options.some((option) => option.id === id)));
    check(`${task.id}/${step.id} has hint`, Boolean(step.hintCopy));
  }
}

for (const task of taskConfigs) {
  taskRuntime.start(task.id);
  for (const step of task.steps) {
    if (step.type === "choice") taskRuntime.choose(step.correctOptionIds[0]);
    if (step.type === "drag") {
      taskRuntime.choose(step.correctOptionIds[0]);
      taskRuntime.submitSelection();
    }
    if (step.type === "order") step.correctOptionIds.forEach((id) => taskRuntime.choose(id));
    if (step.type === "order") taskRuntime.submitSelection();
    if (step.type === "match") {
      step.correctOptionIds.forEach((id) => taskRuntime.choose(id));
      taskRuntime.submitSelection();
    }
  }
}

const progress = loadProgress();
const telemetry = loadTelemetry();
check("all tasks runnable", progress.completedTaskIds.length === taskConfigs.length);
check("all complete leaves no active task", progress.activeTaskId === null);
const taskKnowledgeIds = new Set(taskConfigs.flatMap((task) => task.steps.flatMap((step) => step.knowledgeIds)));
check("all task knowledge receives mastery", Object.keys(progress.knowledgeMastery).length === taskKnowledgeIds.size);
check("telemetry has task completed events", telemetry.filter((event) => event.type === "task_completed").length === taskConfigs.length);
check("telemetry has reward events", telemetry.some((event) => event.type === "reward_granted"));

resetAllData();
const repeatTask = taskConfigs[0];
completeTask(repeatTask);
const firstPass = loadProgress();
const firstTelemetry = loadTelemetry();
completeTask(repeatTask);
const secondPass = loadProgress();
const secondTelemetry = loadTelemetry();
check("replaying completed task does not duplicate stars", secondPass.stars === firstPass.stars);
check("replaying completed task does not duplicate hearts", secondPass.hearts === firstPass.hearts);
check("replaying completed task does not duplicate reward events", secondTelemetry.filter((event) => event.type === "reward_granted").length === firstTelemetry.filter((event) => event.type === "reward_granted").length);
check("replaying completed task still updates mastery", Object.values(secondPass.knowledgeMastery).every((item) => item.attempts >= 2));
check("replaying completed task is marked as review telemetry", secondTelemetry.some((event) => event.type === "task_completed" && event.taskId === repeatTask.id && event.review === true));
check("review telemetry only targets completed tasks", secondTelemetry
  .filter((event) => event.type === "task_completed" && event.review === true)
  .every((event) => secondPass.completedTaskIds.includes(event.taskId)));

const orderTask = taskConfigs.find((task) => task.steps.some((step) => step.type === "order"));
const orderStep = orderTask.steps.find((step) => step.type === "order");
resetAllData();
taskRuntime.start(orderTask.id);
const reversed = [...orderStep.correctOptionIds].reverse();
reversed.forEach((id) => taskRuntime.choose(id));
check("order interaction rejects wrong order", !loadProgress().completedTaskIds.includes(orderTask.id));

const appSource = await readFile(new URL("../src/app/main.js", import.meta.url), "utf-8");
const htmlSource = await readFile(new URL("../index.html", import.meta.url), "utf-8");
const cssSource = await readFile(new URL("../src/app/styles.css", import.meta.url), "utf-8");
const phaserSource = await readFile(new URL("../src/game/PhaserGame.js", import.meta.url), "utf-8");
const manifestSource = await readFile(new URL("../src/assets/images/manifest.txt", import.meta.url), "utf-8");
const imageDirUrl = new URL("../src/assets/images/", import.meta.url);
const actualPngFiles = (await readdir(imageDirUrl)).filter((file) => file.endsWith(".png")).sort();
const manifestFiles = manifestSource.split(/\r?\n/).filter(Boolean).sort();
check("parent gate exists", appSource.includes("4 + 5") && appSource.includes("ParentGate"));
check("no child external links", !/<a\s/i.test(appSource + htmlSource));
check("no payment/ad buttons", !/button[^)]*(支付|充值|购买|广告|抽卡|排行榜)/.test(appSource));
check("responsive css present", cssSource.includes("@media (max-width: 980px)") && cssSource.includes("@media (max-width: 560px)"));
check("task options use image assets", appSource.includes("function optionImage") && !/[◇⌒△▤□✦◦]/.test(appSource));
check("child review queue panel exists", appSource.includes("ReviewQueuePanel") && appSource.includes("buildReviewCards"));
check("child review queue only uses completed tasks", appSource.includes("completedTaskIds.has(item.id)"));
check("child review queue has styles", cssSource.includes(".review-queue-panel") && cssSource.includes(".review-card-button"));
check("corpus panel shows full unit corpus", appSource.includes("resolveCorpusItems") && appSource.includes("unitRawLines") && cssSource.includes(".unit-raw-lines"));
check("phaser reads English story rows", phaserSource.includes("englishStoryContentRows"));
check("phaser maps English rewards to room progress", phaserSource.includes("drawEnglishStoryRoomProgress") && phaserSource.includes("getEnglishStoryRewardPreview"));
check("phaser keeps scene focus on active task", phaserSource.includes("showTargetMarker") && phaserSource.includes("showSceneChoiceTray") && !phaserSource.includes("drawSceneMaterialShelf"));
check("map shows textbook scene material overview", appSource.includes("SceneMaterialOverview") && cssSource.includes(".scene-material-overview"));
check("asset gallery source removed from runtime project", !(await readdir(new URL("../src/assets/", import.meta.url))).includes("gallery.html"));
check("phaser reads unified asset catalog", phaserSource.includes("imageAssetsByKey"));
check("asset catalog includes dedicated expanded scene backgrounds", ["scene-school", "scene-city", "scene-festival", "scene-nature", "scene-health"].every((key) => imageAssetsByKey[key]));
check("asset catalog includes dedicated expanded anchors", ["anchor-school-board", "anchor-city-station", "anchor-festival-stage", "anchor-nature-garden", "anchor-health-sink"].every((key) => imageAssetsByKey[key]));
check("asset catalog includes dedicated material assets", ["material-school-timetable", "material-city-transport", "material-festival-calendar", "material-nature-earth", "material-health-kit"].every((key) => imageAssetsByKey[key]));
check("asset catalog includes dedicated reward assets", englishStoryContentRows.every((row) => imageAssetsByKey[rewardAssetKey(row.rewardId)] === rewardAssetFile(row.rewardId)));
check("app renders dedicated reward assets", appSource.includes("rewardAssetFile(row.rewardId)") && !appSource.includes("function rewardIcon(row) {\n  const reward = rewardsById[row.rewardId];"));
check("phaser previews dedicated reward assets", phaserSource.includes("rewardAssetKey(row.rewardId)") && !phaserSource.includes("function rewardCategoryImage"));
check("manifest matches actual PNG files", JSON.stringify(manifestFiles) === JSON.stringify(actualPngFiles));
check("manifest includes no duplicate PNG entries", new Set(manifestFiles).size === manifestFiles.length);

for (const assetFile of requiredAssetFiles) {
  const assetUrl = new URL(`../src/assets/images/${assetFile}`, import.meta.url);
  await access(assetUrl).catch(() => failures.push(`missing image asset ${assetFile}`));
  check(`manifest includes ${assetFile}`, manifestSource.includes(assetFile));
  check(`runtime references are covered for ${assetFile}`, appSource.includes(assetFile) || phaserSource.includes(assetFile) || manifestSource.includes(assetFile));
  const info = await readPngInfo(assetUrl).catch((error) => {
    failures.push(`could not inspect image asset ${assetFile}: ${error.message}`);
    return null;
  });
  if (!info) continue;
  if (sceneAssetFileSet.has(assetFile)) {
    check(`${assetFile} is 4096x2560`, info.width === 4096 && info.height === 2560);
  }
  if (transparentAssetFileSet.has(assetFile)) {
    check(`${assetFile} has alpha channel`, info.hasAlpha);
    check(`${assetFile} has transparent corners`, info.cornerAlphas.length === 4 && info.cornerAlphas.every((alpha) => alpha === 0));
  }
}

if (failures.length) {
  console.error(`Verification failed:\n- ${failures.join("\n- ")}`);
  process.exit(1);
}

console.log(JSON.stringify({
  ok: true,
  knowledge: knowledgeConfigs.length,
  tasks: taskConfigs.length,
  completed: progress.completedTaskIds.length,
  mastery: Object.keys(progress.knowledgeMastery).length,
  telemetry: telemetry.length
}, null, 2));

function check(label, condition) {
  if (!condition) failures.push(label);
}

function completeTask(task) {
  taskRuntime.start(task.id);
  for (const step of task.steps) {
    if (step.type === "choice") taskRuntime.choose(step.correctOptionIds[0]);
    if (step.type === "drag") {
      taskRuntime.choose(step.correctOptionIds[0]);
      taskRuntime.submitSelection();
    }
    if (step.type === "order") {
      step.correctOptionIds.forEach((id) => taskRuntime.choose(id));
      taskRuntime.submitSelection();
    }
    if (step.type === "match") {
      step.correctOptionIds.forEach((id) => taskRuntime.choose(id));
      taskRuntime.submitSelection();
    }
  }
}

function resolveCorpusCount(unit, idField, corpusField) {
  const book = englishCorpusByBook[unit.bookId];
  if (!book) return 0;
  const sourceIds = new Set((book[corpusField] || []).map((item) => item.id));
  return (unit[idField] || []).filter((id) => sourceIds.has(id)).length;
}

async function readPngInfo(fileUrl) {
  const buffer = await readFile(fileUrl);
  const signature = "89504e470d0a1a0a";
  if (buffer.subarray(0, 8).toString("hex") !== signature) throw new Error("not a PNG");
  const width = buffer.readUInt32BE(16);
  const height = buffer.readUInt32BE(20);
  const bitDepth = buffer[24];
  const colorType = buffer[25];
  const hasAlpha = colorType === 4 || colorType === 6 || hasTrnsChunk(buffer);
  return {
    width,
    height,
    bitDepth,
    colorType,
    hasAlpha,
    cornerAlphas: hasAlpha ? readCornerAlphas(buffer, width, height, bitDepth, colorType) : []
  };
}

function hasTrnsChunk(buffer) {
  let offset = 8;
  while (offset < buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.subarray(offset + 4, offset + 8).toString("ascii");
    if (type === "tRNS") return true;
    offset += 12 + length;
  }
  return false;
}

function readCornerAlphas(buffer, width, height, bitDepth, colorType) {
  if (bitDepth !== 8) return [];
  if (colorType !== 6 && colorType !== 4) return [];
  const bytesPerPixel = colorType === 6 ? 4 : 2;
  const idatChunks = [];
  let offset = 8;
  while (offset < buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.subarray(offset + 4, offset + 8).toString("ascii");
    if (type === "IDAT") idatChunks.push(buffer.subarray(offset + 8, offset + 8 + length));
    offset += 12 + length;
  }
  const inflated = inflateSync(Buffer.concat(idatChunks));
  const stride = width * bytesPerPixel;
  const rows = [];
  let sourceOffset = 0;
  let previous = Buffer.alloc(stride);
  for (let y = 0; y < height; y += 1) {
    const filter = inflated[sourceOffset];
    sourceOffset += 1;
    const raw = inflated.subarray(sourceOffset, sourceOffset + stride);
    sourceOffset += stride;
    const row = Buffer.alloc(stride);
    for (let index = 0; index < stride; index += 1) {
      const left = index >= bytesPerPixel ? row[index - bytesPerPixel] : 0;
      const up = previous[index] || 0;
      const upLeft = index >= bytesPerPixel ? previous[index - bytesPerPixel] || 0 : 0;
      if (filter === 0) row[index] = raw[index];
      else if (filter === 1) row[index] = (raw[index] + left) & 255;
      else if (filter === 2) row[index] = (raw[index] + up) & 255;
      else if (filter === 3) row[index] = (raw[index] + Math.floor((left + up) / 2)) & 255;
      else if (filter === 4) row[index] = (raw[index] + paeth(left, up, upLeft)) & 255;
      else throw new Error(`unsupported PNG filter ${filter}`);
    }
    rows.push(row);
    previous = row;
  }
  return [
    alphaAt(rows, 0, 0, width, bytesPerPixel),
    alphaAt(rows, width - 1, 0, width, bytesPerPixel),
    alphaAt(rows, 0, height - 1, width, bytesPerPixel),
    alphaAt(rows, width - 1, height - 1, width, bytesPerPixel)
  ];
}

function alphaAt(rows, x, y, width, bytesPerPixel) {
  const index = x * bytesPerPixel + bytesPerPixel - 1;
  return rows[y]?.[index] ?? 255;
}

function paeth(left, up, upLeft) {
  const estimate = left + up - upLeft;
  const leftDistance = Math.abs(estimate - left);
  const upDistance = Math.abs(estimate - up);
  const upLeftDistance = Math.abs(estimate - upLeft);
  if (leftDistance <= upDistance && leftDistance <= upLeftDistance) return left;
  if (upDistance <= upLeftDistance) return up;
  return upLeft;
}
