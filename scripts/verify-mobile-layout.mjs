import { writeFile, mkdir } from "node:fs/promises";

const browserUrl = process.env.CDP_URL || "http://127.0.0.1:9223";
const appUrl = process.env.APP_URL || "http://127.0.0.1:4173/";
const outDir = ".tmp/screenshots";

async function cdp(method, params = {}, sessionId = null) {
  const id = ++cdp.nextId;
  const message = { id, method, params };
  if (sessionId) message.sessionId = sessionId;
  cdp.socket.send(JSON.stringify(message));
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

async function waitForLoad() {
  await cdp("Runtime.evaluate", {
    expression: "document.readyState",
    returnByValue: true
  });
  for (let index = 0; index < 50; index += 1) {
    const result = await evaluate("document.readyState === 'complete' && !!document.querySelector('.app-shell')");
    if (result) return;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("Timed out waiting for app shell.");
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
    const modal = document.querySelector('.story-modal');
    const canvas = document.querySelector('#game-canvas canvas');
    const topButtons = [...document.querySelectorAll('.top-actions button')].map((el) => {
      const rect = el.getBoundingClientRect();
      return { text: el.innerText, width: Math.round(rect.width), height: Math.round(rect.height) };
    });
    const overflowing = [...document.querySelectorAll('body *')].filter((el) => {
      const rect = el.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0 && (rect.left < -1 || rect.right > window.innerWidth + 1);
    }).slice(0, 8).map((el) => {
      const rect = el.getBoundingClientRect();
      return { tag: el.tagName, className: String(el.className), text: el.innerText?.slice(0, 80) || '', left: Math.round(rect.left), right: Math.round(rect.right), width: Math.round(rect.width) };
    });
    const modalRect = modal?.getBoundingClientRect();
    const canvasRect = canvas?.getBoundingClientRect();
    return {
      label: ${JSON.stringify(label)},
      viewport: { width: window.innerWidth, height: window.innerHeight },
      documentWidth: doc.scrollWidth,
      hasHorizontalOverflow: doc.scrollWidth > window.innerWidth + 1,
      topButtons,
      modal: modal ? { width: Math.round(modalRect.width), left: Math.round(modalRect.left), right: Math.round(modalRect.right), text: modal.innerText.slice(0, 160) } : null,
      canvas: canvas ? { width: Math.round(canvasRect.width), height: Math.round(canvasRect.height), ratio: Number((canvasRect.width / canvasRect.height).toFixed(3)) } : null,
      rewardVisible: Boolean(document.querySelector('.reward-moment')),
      chapterVisible: Boolean(document.querySelector('.chapter-complete')),
      overflowing
    };
  })()`);
}

async function runViewport(width, height) {
  await cdp("Emulation.setDeviceMetricsOverride", {
    width,
    height,
    deviceScaleFactor: 1,
    mobile: true
  });
  await cdp("Page.navigate", { url: appUrl });
  await waitForLoad();
  await evaluate("localStorage.clear()");
  await cdp("Page.navigate", { url: `${appUrl}?qa=${width}x${height}-${Date.now()}` });
  await waitForLoad();
  const initial = await state(`${width}x${height} intro`);
  await screenshot(`mobile-${width}x${height}-intro`);
  await clickSelector(".modal-actions .primary");
  await new Promise((resolve) => setTimeout(resolve, 600));
  const task = await state(`${width}x${height} task`);
  await screenshot(`mobile-${width}x${height}-task`);

  const rewards = [];
  for (let taskIndex = 0; taskIndex < 3; taskIndex += 1) {
    for (let guard = 0; guard < 5; guard += 1) {
      const done = await evaluate(`(async () => {
        const { taskRuntime } = await import('/src/game/TaskRuntime.js');
        const current = taskRuntime.getState();
        if (!current?.step || current.completed) return true;
        const ids = current.step.correctOptionIds || [];
        if (current.step.type === 'choice') {
          taskRuntime.choose(ids[0]);
        } else {
          ids.forEach((id) => taskRuntime.choose(id));
          taskRuntime.submitSelection();
        }
        return Boolean(taskRuntime.getState()?.completed);
      })()`);
      await new Promise((resolve) => setTimeout(resolve, 260));
      if (done || await evaluate("Boolean(document.querySelector('.story-modal'))")) break;
    }

    const reward = await state(`${width}x${height} reward ${taskIndex + 1}`);
    rewards.push(reward);
    await screenshot(`mobile-${width}x${height}-reward-${taskIndex + 1}`);
    await clickSelector(".modal-actions .primary");
    await new Promise((resolve) => setTimeout(resolve, 600));
  }

  const complete = await state(`${width}x${height} complete`);
  await screenshot(`mobile-${width}x${height}-complete`);
  return [initial, task, ...rewards, complete];
}

function assertState(item) {
  if (item.hasHorizontalOverflow) {
    throw new Error(`${item.label} has horizontal overflow: documentWidth=${item.documentWidth}`);
  }
  const shortButton = item.topButtons.find((button) => button.height < 44);
  if (shortButton) {
    throw new Error(`${item.label} has touch target below 44px: ${shortButton.text} ${shortButton.height}px`);
  }
  if (item.canvas && Math.abs(item.canvas.ratio - 1.6) > 0.02) {
    throw new Error(`${item.label} canvas ratio changed: ${item.canvas.ratio}`);
  }
  if (item.overflowing.length) {
    throw new Error(`${item.label} has overflowing elements: ${JSON.stringify(item.overflowing)}`);
  }
}

await mkdir(outDir, { recursive: true });
await connect();
await cdp("Page.enable");
await cdp("Runtime.enable");

const results = [
  ...(await runViewport(390, 844)),
  ...(await runViewport(360, 740))
];

results.forEach(assertState);
for (const size of ["390x844", "360x740"]) {
  const rewards = results.filter((item) => item.label.startsWith(size) && item.label.includes("reward"));
  if (rewards.length !== 3) throw new Error(`${size} should capture three reward/chapter states.`);
  if (!rewards.slice(0, 2).every((item) => item.rewardVisible)) throw new Error(`${size} reward modals were not visible.`);
  if (!rewards[2].chapterVisible) throw new Error(`${size} chapter completion modal was not visible.`);
}

cdp.socket.close();
console.log(JSON.stringify(results, null, 2));
