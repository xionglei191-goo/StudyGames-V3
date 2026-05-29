import { mkdir, writeFile } from "node:fs/promises";

const browserUrl = process.env.CDP_URL || "http://127.0.0.1:9223";
const appUrl = process.env.APP_URL || "http://127.0.0.1:4173/";
const outDir = ".tmp/screenshots";

async function cdp(method, params = {}) {
  const id = ++cdp.nextId;
  cdp.socket.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => {
    cdp.pending.set(id, { resolve, reject });
  });
}
cdp.nextId = 0;
cdp.pending = new Map();

async function connect() {
  const pages = await fetch(`${browserUrl}/json/list`).then((response) => response.json());
  const page = pages.find((item) => item.type === "page") || pages[0];
  if (!page?.webSocketDebuggerUrl) throw new Error("No Chrome page target found.");
  cdp.socket = new WebSocket(page.webSocketDebuggerUrl);
  cdp.socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (!message.id) return;
    const pending = cdp.pending.get(message.id);
    if (!pending) return;
    cdp.pending.delete(message.id);
    if (message.error) pending.reject(new Error(message.error.message));
    else pending.resolve(message.result);
  });
  await new Promise((resolve, reject) => {
    cdp.socket.addEventListener("open", resolve, { once: true });
    cdp.socket.addEventListener("error", reject, { once: true });
  });
}

async function evaluate(expression) {
  const result = await cdp("Runtime.evaluate", {
    expression,
    awaitPromise: true,
    returnByValue: true
  });
  if (result.exceptionDetails) throw new Error(result.exceptionDetails.text || "Runtime evaluate failed.");
  return result.result.value;
}

async function waitForLoad() {
  for (let index = 0; index < 60; index += 1) {
    const ready = await evaluate("document.readyState === 'complete' && !!document.querySelector('.app-shell')");
    if (ready) return;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("Timed out waiting for app shell.");
}

async function clickSelector(selector) {
  const point = await evaluate(`(() => {
    const el = document.querySelector(${JSON.stringify(selector)});
    if (!el) return null;
    const rect = el.getBoundingClientRect();
    return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
  })()`);
  if (!point) throw new Error(`Selector not found: ${selector}`);
  await cdp("Input.dispatchMouseEvent", { type: "mousePressed", x: point.x, y: point.y, button: "left", clickCount: 1 });
  await cdp("Input.dispatchMouseEvent", { type: "mouseReleased", x: point.x, y: point.y, button: "left", clickCount: 1 });
}

async function screenshot(name) {
  const result = await cdp("Page.captureScreenshot", { format: "png", fromSurface: true });
  await writeFile(`${outDir}/${name}.png`, Buffer.from(result.data, "base64"));
}

async function state(label) {
  return evaluate(`(() => {
    const doc = document.documentElement;
    const canvas = document.querySelector('#game-canvas canvas');
    const modal = document.querySelector('.story-modal');
    const gameStage = document.querySelector('.game-stage');
    const sidePanel = document.querySelector('.side-panel');
    const canvasRect = canvas?.getBoundingClientRect();
    const stageRect = gameStage?.getBoundingClientRect();
    const sideRect = sidePanel?.getBoundingClientRect();
    const overflowing = [...document.querySelectorAll('body *')].filter((el) => {
      const rect = el.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0 && (rect.left < -1 || rect.right > window.innerWidth + 1);
    }).slice(0, 8).map((el) => {
      const rect = el.getBoundingClientRect();
      return { tag: el.tagName, className: String(el.className), text: el.innerText?.slice(0, 80) || '', left: Math.round(rect.left), right: Math.round(rect.right), width: Math.round(rect.width) };
    });
    return {
      label: ${JSON.stringify(label)},
      viewport: { width: window.innerWidth, height: window.innerHeight },
      documentWidth: doc.scrollWidth,
      hasHorizontalOverflow: doc.scrollWidth > window.innerWidth + 1,
      canvas: canvas ? { width: Math.round(canvasRect.width), height: Math.round(canvasRect.height), ratio: Number((canvasRect.width / canvasRect.height).toFixed(3)) } : null,
      stage: gameStage ? { width: Math.round(stageRect.width), height: Math.round(stageRect.height) } : null,
      sidePanel: sidePanel ? { width: Math.round(sideRect.width), height: Math.round(sideRect.height) } : null,
      modal: modal ? { text: modal.innerText.slice(0, 180), width: Math.round(modal.getBoundingClientRect().width) } : null,
      rewardVisible: Boolean(document.querySelector('.reward-moment')),
      chapterVisible: Boolean(document.querySelector('.chapter-complete')),
      taskStep: document.querySelector('.step-badge')?.innerText || '',
      taskTitle: document.querySelector('.task-header h1')?.innerText || '',
      selectedText: document.querySelector('.selection-tray strong')?.innerText || '',
      completeTown: Boolean(document.querySelector('.complete-town-card')),
      overflowing
    };
  })()`);
}

async function setViewport(width, height) {
  await cdp("Emulation.setDeviceMetricsOverride", {
    width,
    height,
    deviceScaleFactor: 1,
    mobile: false
  });
}

async function chooseCurrentCorrectStep(submitMulti = true) {
  return evaluate(`(async () => {
    const { taskRuntime } = await import('/src/game/TaskRuntime.js');
    const current = taskRuntime.getState();
    if (!current?.step || current.completed) return { completed: true, step: current?.step?.id || null };
    const ids = current.step.correctOptionIds || [];
    if (current.step.type === 'choice') {
      taskRuntime.choose(ids[0]);
    } else {
      ids.forEach((id) => taskRuntime.choose(id));
      if (${submitMulti ? "true" : "false"}) taskRuntime.submitSelection();
    }
    const next = taskRuntime.getState();
    return { completed: Boolean(next?.completed), step: next?.step?.id || null, selectedIds: next?.selectedIds || [] };
  })()`);
}

async function completeTaskToReward() {
  for (let guard = 0; guard < 5; guard += 1) {
    const result = await chooseCurrentCorrectStep(true);
    await new Promise((resolve) => setTimeout(resolve, 260));
    if (result.completed || await evaluate("Boolean(document.querySelector('.story-modal'))")) return;
  }
  throw new Error("Task did not complete within expected steps.");
}

function assertState(item) {
  if (item.hasHorizontalOverflow) throw new Error(`${item.label} has horizontal overflow.`);
  if (item.overflowing.length) throw new Error(`${item.label} has overflowing elements: ${JSON.stringify(item.overflowing)}`);
  if (!item.canvas) throw new Error(`${item.label} has no Phaser canvas.`);
  if (Math.abs(item.canvas.ratio - 1.6) > 0.02) throw new Error(`${item.label} canvas ratio changed: ${item.canvas.ratio}`);
  if (!item.sidePanel || item.sidePanel.width < 300) throw new Error(`${item.label} side panel is unexpectedly narrow.`);
}

await mkdir(outDir, { recursive: true });
await connect();
await cdp("Page.enable");
await cdp("Runtime.enable");

await setViewport(1440, 900);
await cdp("Page.navigate", { url: appUrl });
await waitForLoad();
await evaluate("localStorage.clear()");
await cdp("Page.navigate", { url: `${appUrl}?desktop=1440-${Date.now()}` });
await waitForLoad();
await clickSelector(".modal-actions .ghost");
await new Promise((resolve) => setTimeout(resolve, 500));
const town1440 = await state("1440x900 town");
await screenshot("desktop-1440x900-town");

await clickSelector(".travel-button");
await new Promise((resolve) => setTimeout(resolve, 700));
const studyStep1 = await state("1440x900 study step 1");
await screenshot("desktop-1440x900-study-step1");

await chooseCurrentCorrectStep(true);
await new Promise((resolve) => setTimeout(resolve, 260));
await chooseCurrentCorrectStep(true);
await new Promise((resolve) => setTimeout(resolve, 260));
await chooseCurrentCorrectStep(false);
await new Promise((resolve) => setTimeout(resolve, 260));
const step3Selected = await state("1440x900 first task step 3 selected");
await screenshot("desktop-1440x900-task1-step3-selected");

await evaluate(`(async () => {
  const { taskRuntime } = await import('/src/game/TaskRuntime.js');
  taskRuntime.submitSelection();
})()`);
await new Promise((resolve) => setTimeout(resolve, 500));
const reward1 = await state("1440x900 reward");
await screenshot("desktop-1440x900-reward");

await clickSelector(".modal-actions .primary");
await new Promise((resolve) => setTimeout(resolve, 500));
await completeTaskToReward();
await clickSelector(".modal-actions .primary");
await new Promise((resolve) => setTimeout(resolve, 500));
await completeTaskToReward();
await new Promise((resolve) => setTimeout(resolve, 500));
const chapter = await state("1440x900 chapter complete");
await screenshot("desktop-1440x900-chapter-complete");

await setViewport(1280, 720);
await cdp("Page.navigate", { url: `${appUrl}?desktop=1280-${Date.now()}` });
await waitForLoad();
await evaluate("localStorage.clear()");
await cdp("Page.navigate", { url: `${appUrl}?desktop=1280-fresh-${Date.now()}` });
await waitForLoad();
await clickSelector(".modal-actions .ghost");
await new Promise((resolve) => setTimeout(resolve, 500));
const town1280 = await state("1280x720 town and log");
await screenshot("desktop-1280x720-town-log");

const results = [town1440, studyStep1, step3Selected, reward1, chapter, town1280];
results.forEach(assertState);
if (studyStep1.taskStep !== "1/3") throw new Error(`Study step should be 1/3, got ${studyStep1.taskStep}`);
if (step3Selected.taskStep !== "3/3") throw new Error(`Selected state should be step 3/3, got ${step3Selected.taskStep}`);
if (!step3Selected.selectedText) throw new Error("Step 3 selected screenshot has no selected text.");
if (!reward1.rewardVisible) throw new Error("Reward settlement modal was not visible.");
if (!chapter.chapterVisible) throw new Error("Chapter completion modal was not visible.");

cdp.socket.close();
console.log(JSON.stringify(results, null, 2));
