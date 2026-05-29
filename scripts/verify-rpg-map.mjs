import { spawn } from "node:child_process";
import { chromium } from "playwright";
import { scenesById } from "../src/content/scenes.js";
import { tasksById } from "../src/content/tasks.js";

const port = Number(process.env.PORT || 4183);
const appUrl = process.env.APP_URL || `http://127.0.0.1:${port}/`;
const taskFlow = [
  { id: "task_eng_g3b_u01_main", title: "小镇门口见面礼", targetPointId: "post_office", target: { x: 784, y: 310 }, guide: { x: 510, y: 344 } },
  { id: "task_eng_g3b_u02_main", title: "帮 Mina 赶上铃声", targetPointId: "mina_bell", target: { x: 324, y: 292 } },
  { id: "task_eng_g3b_u03_main", title: "天气出门准备", targetPointId: "weather_station", target: { x: 654, y: 426 } }
].map((task) => ({
  ...task,
  sceneTitle: scenesById[tasksById[task.id]?.sceneId]?.title || tasksById[task.id]?.sceneId || "任务场景"
}));
const p0TaskIds = taskFlow.map((task) => task.id);
const server = spawn(process.execPath, ["scripts/serve.mjs"], {
  cwd: process.cwd(),
  env: { ...process.env, PORT: String(port), HOST: "127.0.0.1" },
  stdio: ["ignore", "pipe", "pipe"]
});

function stopServer() {
  if (!server.killed) server.kill();
}

async function waitForServer() {
  for (let index = 0; index < 80; index += 1) {
    try {
      const response = await fetch(appUrl);
      if (response.ok) return;
    } catch {
      // Keep waiting while the static server boots.
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("Timed out waiting for local StudyGame server.");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function clickWorld(page, worldX, worldY) {
  const rect = await page.locator("#game-canvas canvas").boundingBox();
  assert(rect, "Phaser canvas was not found.");
  await page.mouse.click(rect.x + (worldX / 1024) * rect.width, rect.y + (worldY / 640) * rect.height);
}

async function snapshot(page) {
  return page.evaluate(async () => {
    const { taskRuntime } = await import("/src/game/TaskRuntime.js");
    const runtimeState = taskRuntime.getState();
    return {
      hasModal: Boolean(document.querySelector(".story-modal")),
      scene: document.querySelector(".brand div span")?.textContent || "",
      hud: document.querySelector(".map-hud")?.textContent || "",
      header: document.querySelector(".topbar")?.innerText || "",
      panel: document.querySelector(".side-panel")?.innerText || "",
      step: document.querySelector(".step-badge")?.textContent || "",
      townState: window.__studyGameTownState,
      activeScenes: window.__studyGame?.scene?.getScenes(true)?.map((scene) => scene.scene.key) || [],
      runtimeTaskId: runtimeState?.task?.id || null,
      progress: JSON.parse(localStorage.getItem("studygame.progress") || "{}")
    };
  });
}

async function chooseCurrentCorrectStep(page) {
  return page.evaluate(async () => {
    const { taskRuntime } = await import("/src/game/TaskRuntime.js");
    const state = taskRuntime.getState();
    if (!state?.step) return { completed: false, missing: true };
    const ids = state.step.correctOptionIds || [];
    if (state.step.type === "choice") {
      return taskRuntime.choose(ids[0]);
    }
    ids.forEach((id) => taskRuntime.choose(id));
    return taskRuntime.submitSelection();
  });
}

async function completeCurrentTask(page, taskId) {
  for (let guard = 0; guard < 8; guard += 1) {
    const result = await chooseCurrentCorrectStep(page);
    await page.waitForTimeout(220);
    if (result.completed || await page.locator(".reward-moment, .chapter-complete").count()) return;
  }
  throw new Error(`${taskId} did not reach reward modal.`);
}

async function assertTownForTask(page, task, index) {
  await page.waitForFunction(() => (document.querySelector(".brand div span")?.textContent || "").includes("星光小镇"));
  await page.waitForFunction((taskId) => window.__studyGameTownState?.activeTaskId === taskId, task.id);
  const state = await snapshot(page);
  assert(state.scene.includes("星光小镇"), `Expected town before ${task.id}, got: ${state.scene}`);
  assert(state.hud.includes("当前目标") && state.hud.includes("下一步地点"), `Town HUD missing goal/destination before ${task.id}.`);
  if (index === 0) {
    assert(state.hud.includes(task.title), `Town HUD should point to ${task.title}, got: ${state.hud}`);
  } else {
    assert(state.hud.includes("星片") || state.hud.includes("回镇变化"), `Town HUD should preserve return/change context before ${task.id}, got: ${state.hud}`);
  }
  assert(state.townState?.activeTaskId === task.id, `Town active task should be ${task.id}, got: ${state.townState?.activeTaskId}`);
  assert(state.townState?.targetPointId === task.targetPointId, `Town target point for ${task.id} should be ${task.targetPointId}, got: ${state.townState?.targetPointId}`);
  assert((state.progress.starShard?.collectedIds?.length || 0) === index, `Expected ${index}/3 shards before ${task.id}.`);
  return state;
}

async function startTaskFromTown(page, task) {
  if (task.guide) {
    const beforeGuide = await snapshot(page);
    await clickWorld(page, task.guide.x, task.guide.y);
    await page.waitForTimeout(500);
    const afterGuide = await snapshot(page);
    assert(afterGuide.scene.includes("星光小镇"), `Guide point should keep the player in town before ${task.id}.`);
    assert(afterGuide.runtimeTaskId === beforeGuide.runtimeTaskId, `Guide point should not start TaskRuntime for ${task.id}.`);
    assert(afterGuide.townState?.activeTaskId === task.id, `Guide interaction should preserve active task ${task.id}.`);
  }

  let entered = false;
  let current = null;
  for (let attempt = 0; attempt < 3 && !entered; attempt += 1) {
    await clickWorld(page, task.target.x, task.target.y);
    await page.waitForTimeout(700);
    current = await snapshot(page);
    entered = current.runtimeTaskId === task.id && current.step === "1/3";
  }
  if (!entered) {
    throw new Error(`${task.id} did not enter ${task.sceneTitle} from town point ${task.targetPointId}. Current snapshot: ${JSON.stringify(current)}`);
  }
  const study = await snapshot(page);
  assert(study.runtimeTaskId === task.id, `TaskRuntime should start ${task.id}, got: ${study.runtimeTaskId}`);
  assert(study.step === "1/3", `${task.id} should start at step 1/3, got ${study.step}`);
}

async function finishTaskAndReturnToTown(page, task, index) {
  await completeCurrentTask(page, task.id);
  await page.waitForSelector(".reward-moment, .chapter-complete");
  const rewardText = await page.locator(".reward-moment, .chapter-complete").innerText();
  const expectedShardText = `${index + 1}/3`;
  assert(rewardText.includes("小镇变化"), `${task.id} reward modal should explain the town change.`);
  assert(rewardText.includes(expectedShardText), `${task.id} reward modal should show ${expectedShardText} star shard progress.`);
  if (index === taskFlow.length - 1) {
    assert(rewardText.includes("第一圈星路点亮"), "Final reward modal should say the first star path ring is lit.");
    assert(rewardText.includes("校园星门"), "Final reward modal should mention the next visible story state.");
  }

  await page.locator(".reward-moment .modal-actions .primary, .chapter-complete .modal-actions .primary").click();
  await page.waitForFunction(() => (document.querySelector(".brand div span")?.textContent || "").includes("星光小镇"));
  await page.waitForTimeout(500);

  const returned = await snapshot(page);
  const completedSoFar = taskFlow.slice(0, index + 1).map((item) => item.id);
  completedSoFar.forEach((taskId) => {
    assert(returned.progress.completedTaskIds?.includes(taskId), `${taskId} was not recorded completed.`);
  });
  assert((returned.progress.starShard?.collectedIds?.length || 0) === index + 1, `Expected ${index + 1}/3 star shards after ${task.id}.`);
  assert(returned.header.includes(`${index + 1}/3 星片`), `Top status should show ${index + 1}/3 星片 after ${task.id}.`);

  const nextTask = taskFlow[index + 1];
  if (nextTask) {
    assert(returned.townState?.activeTaskId === nextTask.id, `Town should expose next active task ${nextTask.id}, got: ${returned.townState?.activeTaskId}`);
    assert(returned.townState?.targetPointId === nextTask.targetPointId, `Town should point to ${nextTask.targetPointId} after ${task.id}, got: ${returned.townState?.targetPointId}`);
    assert(returned.hud.includes("星片") || returned.hud.includes("小镇变化") || returned.hud.includes("回镇变化"), `Returned town HUD should show shard/change context, got: ${returned.hud}`);
  } else {
    const pendingP0TaskId = p0TaskIds.find((taskId) => !returned.progress.completedTaskIds?.includes(taskId));
    assert(!pendingP0TaskId, `All three tasks complete should leave no P0 task pending, got pending: ${pendingP0TaskId}`);
    assert(returned.progress.activeTaskId == null || returned.progress.completedTaskIds?.includes(returned.progress.activeTaskId), `All three tasks complete should clear activeTaskId or leave no pending active task, got: ${returned.progress.activeTaskId}`);
    assert(returned.townState?.activeTaskId == null || returned.progress.completedTaskIds?.includes(returned.townState.activeTaskId), `Town should have no pending active task after 3/3, got: ${returned.townState?.activeTaskId}`);
    assert(returned.hud.includes("第一圈星路") && (returned.hud.includes("已点亮") || returned.hud.includes("点亮") || returned.hud.includes("亮起")), `Final HUD should show first ring lit, got: ${returned.hud}`);
    assert(returned.hud.includes("钟塔") || returned.hud.includes("校园星门"), `Final HUD should expose lit-ring status, got: ${returned.hud}`);
    assert(returned.panel.includes("第一圈星路已经点亮") && returned.panel.includes("3/3 星片"), "Completion panel should show 3/3 shards and lit first ring copy.");
  }

  return returned;
}

try {
  await waitForServer();
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  await page.goto(appUrl, { waitUntil: "networkidle" });
  await page.evaluate(() => localStorage.clear());
  await page.reload({ waitUntil: "networkidle" });
  await page.waitForSelector(".app-shell");
  await page.waitForFunction(() => document.documentElement.dataset.studyGameStatus === "ready");

  const initial = await snapshot(page);
  assert(!initial.hasModal, "Initial screen should show the town map without a blocking story modal.");
  assert(initial.scene.includes("星光小镇"), `Initial scene should be town, got: ${initial.scene}`);
  assert(initial.hud.includes("当前目标") && initial.hud.includes("下一步地点"), "Map HUD did not expose current goal and destination.");
  assert(initial.townState?.activeTaskId === taskFlow[0].id, "Town state did not point to the first P0 task.");
  assert(!initial.runtimeTaskId, "TaskRuntime should not start before map interaction enters the first task scene.");

  await clickWorld(page, 144, 268);
  await page.waitForTimeout(450);

  const results = [];
  for (let index = 0; index < taskFlow.length; index += 1) {
    const task = taskFlow[index];
    await assertTownForTask(page, task, index);
    await startTaskFromTown(page, task);
    results.push(await finishTaskAndReturnToTown(page, task, index));
  }

  await browser.close();
  console.log(JSON.stringify({
    ok: true,
    appUrl,
    completedTasks: taskFlow.map((task) => task.id),
    finalShardText: "3/3 星片",
    finalHud: results.at(-1)?.hud || "",
    finalPanelIncludes: "第一圈星路已经点亮"
  }, null, 2));
} finally {
  stopServer();
}
