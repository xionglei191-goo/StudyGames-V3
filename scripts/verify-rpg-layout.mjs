import { mkdir } from "node:fs/promises";
import { spawn } from "node:child_process";
import { chromium } from "playwright";

const port = Number(process.env.PORT || 4185);
const appUrl = process.env.APP_URL || `http://127.0.0.1:${port}/`;
const outDir = ".tmp/screenshots";
const viewports = [
  { name: "desktop-1440x900", width: 1440, height: 900, mobile: false },
  { name: "desktop-1280x720", width: 1280, height: 720, mobile: false },
  { name: "mobile-390x844", width: 390, height: 844, mobile: true },
  { name: "mobile-360x740", width: 360, height: 740, mobile: true }
];

const server = spawn(process.execPath, ["scripts/serve.mjs"], {
  cwd: process.cwd(),
  env: { ...process.env, PORT: String(port), HOST: "127.0.0.1" },
  stdio: ["ignore", "pipe", "pipe"]
});

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertCanvasPaint(canvasPaint, label) {
  assert(canvasPaint, `${label} could not inspect Phaser canvas pixels.`);
  assert(canvasPaint.coverage > 0.95, `${label} canvas appears mostly transparent/empty: ${JSON.stringify(canvasPaint)}`);
  assert(canvasPaint.uniqueColors >= 80, `${label} canvas has too few visible colors: ${JSON.stringify(canvasPaint)}`);
  assert(canvasPaint.darkOrSaturatedRatio >= 0.02, `${label} canvas lacks foreground map/detail pixels: ${JSON.stringify(canvasPaint)}`);
}

function assertNoLargeMapCover(cover, label) {
  assert(cover, `${label} could not inspect map-cover heuristics.`);
  assert(cover.domLargestLightCoverRatio <= 0.42, `${label} has a large DOM light panel covering the map: ${JSON.stringify(cover)}`);
  assert(cover.canvasLightCoverRatio <= 0.62, `${label} has too much light label/panel coverage inside Phaser canvas: ${JSON.stringify(cover)}`);
  assert(cover.canvasLargestLightBlockRatio <= 0.22, `${label} has a large light block covering the town map: ${JSON.stringify(cover)}`);
}

function assertTopdownTown(townMode, label) {
  assert(townMode, `${label} could not inspect town map mode.`);
  if (townMode.exposed !== undefined && townMode.exposed !== null) {
    const value = String(townMode.exposed).toLowerCase();
    assert(/top.?down|town.?map|map/.test(value), `${label} exposed non-topdown town map mode: ${JSON.stringify(townMode)}`);
    return;
  }
  assert(townMode.activeTownScene, `${label} Phaser TownScene is not active: ${JSON.stringify(townMode)}`);
  assert(townMode.diffFromBackgroundRatio >= 0.06, `${label} looks too close to the raw scene-town background: ${JSON.stringify(townMode)}`);
}

async function waitForServer() {
  for (let index = 0; index < 80; index += 1) {
    try {
      const response = await fetch(appUrl);
      if (response.ok) return;
    } catch {
      // Static server is still booting.
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("Timed out waiting for local StudyGame server.");
}

async function inspectTown(page, name) {
  await page.goto(`${appUrl}?layout=${name}-${Date.now()}`, { waitUntil: "networkidle" });
  await page.evaluate(() => localStorage.clear());
  await page.reload({ waitUntil: "networkidle" });
  await page.waitForSelector(".app-shell");
  await page.waitForFunction(() => document.documentElement.dataset.studyGameStatus === "ready");
  await page.screenshot({ path: `${outDir}/${name}-town.png`, fullPage: true });

  return page.evaluate((label) => {
    const doc = document.documentElement;
    const canvas = document.querySelector("#game-canvas canvas");
    const stage = document.querySelector(".game-stage");
    const hud = document.querySelector(".map-hud");
    const brand = document.querySelector(".brand div span")?.textContent || "";
    const canvasRect = canvas?.getBoundingClientRect();
    const stageRect = stage?.getBoundingClientRect();
    const hudRect = hud?.getBoundingClientRect();
    const domLargestLightCover = [...document.querySelectorAll("body *")].reduce((largest, el) => {
      const rect = el.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) return largest;
      if (el === stage || el.contains(stage) || stage?.contains(el)) return largest;
      const style = getComputedStyle(el);
      const background = style.backgroundColor || "";
      const match = background.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)/);
      if (!match) return largest;
      const [r, g, b, a = "1"] = match.slice(1).map(Number);
      const alpha = Number.isFinite(a) ? a : 1;
      const light = r >= 238 && g >= 238 && b >= 238 && alpha >= 0.58;
      const intersectsStage = stageRect
        && rect.right > stageRect.left
        && rect.left < stageRect.right
        && rect.bottom > stageRect.top
        && rect.top < stageRect.bottom;
      if (!light || !intersectsStage) return largest;
      const overlapWidth = Math.min(rect.right, stageRect.right) - Math.max(rect.left, stageRect.left);
      const overlapHeight = Math.min(rect.bottom, stageRect.bottom) - Math.max(rect.top, stageRect.top);
      return Math.max(largest, Math.max(0, overlapWidth) * Math.max(0, overlapHeight));
    }, 0);
    const overflowing = [...document.querySelectorAll("body *")]
      .filter((el) => {
        const rect = el.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0 && (rect.left < -1 || rect.right > window.innerWidth + 1);
      })
      .slice(0, 8)
      .map((el) => {
        const rect = el.getBoundingClientRect();
        return {
          tag: el.tagName,
          className: String(el.className),
          text: el.innerText?.slice(0, 80) || "",
          left: Math.round(rect.left),
          right: Math.round(rect.right),
          width: Math.round(rect.width)
        };
      });
    const shortTargets = [...document.querySelectorAll("button")]
      .map((el) => {
        const rect = el.getBoundingClientRect();
        return { text: el.innerText, width: Math.round(rect.width), height: Math.round(rect.height) };
      })
      .filter((item) => item.width > 0 && item.height > 0 && item.height < 34);

    const inspectCanvas = () => {
      if (!canvas) return null;
      const width = canvas.width;
      const height = canvas.height;
      const inspector = document.createElement("canvas");
      inspector.width = width;
      inspector.height = height;
      const ctx = inspector.getContext("2d", { willReadFrequently: true });
      ctx.drawImage(canvas, 0, 0, width, height);
      const data = ctx.getImageData(0, 0, width, height).data;
      const step = 4;
      let samples = 0;
      let painted = 0;
      let light = 0;
      let darkOrSaturated = 0;
      const colors = new Set();
      const lightMaskWidth = Math.ceil(width / step);
      const lightMaskHeight = Math.ceil(height / step);
      const lightMask = new Uint8Array(lightMaskWidth * lightMaskHeight);

      for (let y = 0; y < height; y += step) {
        for (let x = 0; x < width; x += step) {
          const index = (y * width + x) * 4;
          const r = data[index];
          const g = data[index + 1];
          const b = data[index + 2];
          const a = data[index + 3];
          const max = Math.max(r, g, b);
          const min = Math.min(r, g, b);
          const isPainted = a > 8;
          const isLight = isPainted && r >= 238 && g >= 238 && b >= 232 && max - min <= 26;
          samples += 1;
          if (isPainted) painted += 1;
          if (isLight) {
            light += 1;
            lightMask[(Math.floor(y / step) * lightMaskWidth) + Math.floor(x / step)] = 1;
          }
          if (isPainted && (max - min > 34 || max < 208)) darkOrSaturated += 1;
          colors.add(`${r >> 4},${g >> 4},${b >> 4},${a >> 6}`);
        }
      }

      const visited = new Uint8Array(lightMask.length);
      const queue = [];
      let largestLightBlock = 0;
      for (let index = 0; index < lightMask.length; index += 1) {
        if (!lightMask[index] || visited[index]) continue;
        let count = 0;
        visited[index] = 1;
        queue.push(index);
        while (queue.length) {
          const current = queue.pop();
          count += 1;
          const cx = current % lightMaskWidth;
          const cy = Math.floor(current / lightMaskWidth);
          const neighbors = [
            current - 1,
            current + 1,
            current - lightMaskWidth,
            current + lightMaskWidth
          ];
          for (const next of neighbors) {
            if (next < 0 || next >= lightMask.length || visited[next] || !lightMask[next]) continue;
            const nx = next % lightMaskWidth;
            const ny = Math.floor(next / lightMaskWidth);
            if (Math.abs(nx - cx) + Math.abs(ny - cy) !== 1) continue;
            visited[next] = 1;
            queue.push(next);
          }
        }
        largestLightBlock = Math.max(largestLightBlock, count);
      }

      return {
        width,
        height,
        coverage: Number((painted / samples).toFixed(4)),
        uniqueColors: colors.size,
        darkOrSaturatedRatio: Number((darkOrSaturated / samples).toFixed(4)),
        lightCoverRatio: Number((light / samples).toFixed(4)),
        largestLightBlockRatio: Number((largestLightBlock / samples).toFixed(4))
      };
    };

    const canvasPaint = inspectCanvas();
    const exposedMode = window.__studyGameTownState?.mapMode
      ?? window.__studyGameTownState?.mode
      ?? window.__studyGameTownState?.layoutMode
      ?? null;
    const activeScenes = window.__studyGame?.scene?.getScenes(true)?.map((scene) => scene.scene.key) || [];
    const backgroundDiff = (() => {
      if (!canvas) return null;
      const background = [...document.images].find((image) => image.currentSrc?.includes("scene-town.png"));
      if (!background?.complete || !background.naturalWidth) return null;
      const width = 256;
      const height = 160;
      const live = document.createElement("canvas");
      const base = document.createElement("canvas");
      live.width = base.width = width;
      live.height = base.height = height;
      const liveCtx = live.getContext("2d", { willReadFrequently: true });
      const baseCtx = base.getContext("2d", { willReadFrequently: true });
      liveCtx.drawImage(canvas, 0, 0, width, height);
      baseCtx.drawImage(background, 0, 0, width, height);
      const liveData = liveCtx.getImageData(0, 0, width, height).data;
      const baseData = baseCtx.getImageData(0, 0, width, height).data;
      let different = 0;
      for (let index = 0; index < liveData.length; index += 16) {
        const diff = Math.abs(liveData[index] - baseData[index])
          + Math.abs(liveData[index + 1] - baseData[index + 1])
          + Math.abs(liveData[index + 2] - baseData[index + 2]);
        if (diff > 54) different += 1;
      }
      return different / (liveData.length / 16);
    })();

    return {
      label,
      viewport: { width: window.innerWidth, height: window.innerHeight },
      documentWidth: doc.scrollWidth,
      hasHorizontalOverflow: doc.scrollWidth > window.innerWidth + 1,
      brand,
      hasModal: Boolean(document.querySelector(".story-modal")),
      hud: hud ? { text: hud.innerText, width: Math.round(hudRect.width), height: Math.round(hudRect.height) } : null,
      canvas: canvas ? { width: Math.round(canvasRect.width), height: Math.round(canvasRect.height), ratio: Number((canvasRect.width / canvasRect.height).toFixed(3)) } : null,
      stage: stage ? { width: Math.round(stageRect.width), height: Math.round(stageRect.height) } : null,
      townState: window.__studyGameTownState,
      canvasPaint,
      mapCover: {
        domLargestLightCoverRatio: stageRect ? Number((domLargestLightCover / (stageRect.width * stageRect.height)).toFixed(4)) : 0,
        canvasLightCoverRatio: canvasPaint?.lightCoverRatio ?? 0,
        canvasLargestLightBlockRatio: canvasPaint?.largestLightBlockRatio ?? 0
      },
      townMode: {
        exposed: exposedMode,
        activeTownScene: activeScenes.includes("TownScene"),
        activeScenes,
        diffFromBackgroundRatio: backgroundDiff == null ? 1 : Number(backgroundDiff.toFixed(4))
      },
      overflowing,
      shortTargets
    };
  }, name);
}

try {
  await mkdir(outDir, { recursive: true });
  await waitForServer();
  const browser = await chromium.launch({ headless: true });
  const results = [];

  for (const viewport of viewports) {
    const page = await browser.newPage({
      viewport: { width: viewport.width, height: viewport.height },
      isMobile: viewport.mobile,
      deviceScaleFactor: 1
    });
    const result = await inspectTown(page, viewport.name);
    results.push(result);
    await page.close();
  }

  await browser.close();

  results.forEach((item) => {
    assert(!item.hasModal, `${item.label} should not show a blocking intro modal.`);
    assert(item.brand.includes("星光小镇"), `${item.label} should start at town, got ${item.brand}`);
    assert(item.hud?.text.includes("当前目标"), `${item.label} HUD missing current goal.`);
    assert(item.hud?.text.includes("下一步地点"), `${item.label} HUD missing next destination.`);
    assert(item.canvas, `${item.label} has no Phaser canvas.`);
    assert(Math.abs(item.canvas.ratio - 1.6) <= 0.03, `${item.label} canvas ratio changed: ${item.canvas.ratio}`);
    assertCanvasPaint(item.canvasPaint, item.label);
    assertNoLargeMapCover(item.mapCover, item.label);
    assertTopdownTown(item.townMode, item.label);
    assert(!item.hasHorizontalOverflow, `${item.label} has horizontal overflow: ${item.documentWidth}`);
    assert(!item.overflowing.length, `${item.label} has overflowing elements: ${JSON.stringify(item.overflowing)}`);
    assert(!item.shortTargets.length, `${item.label} has very short button targets: ${JSON.stringify(item.shortTargets)}`);
    assert(item.townState?.activeTaskId === "task_eng_g3b_u01_main", `${item.label} missing first town task state.`);
    assert(item.townState?.targetPointId === "post_office", `${item.label} town state should point the first task to post_office, got ${item.townState?.targetPointId}`);
  });

  console.log(JSON.stringify({ ok: true, screenshots: results.map((item) => `${outDir}/${item.label}-town.png`), results }, null, 2));
} finally {
  if (!server.killed) server.kill();
}
