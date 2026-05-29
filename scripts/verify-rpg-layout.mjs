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
    assert(!item.hasHorizontalOverflow, `${item.label} has horizontal overflow: ${item.documentWidth}`);
    assert(!item.overflowing.length, `${item.label} has overflowing elements: ${JSON.stringify(item.overflowing)}`);
    assert(!item.shortTargets.length, `${item.label} has very short button targets: ${JSON.stringify(item.shortTargets)}`);
    assert(item.townState?.activeTaskId === "task_eng_g3b_u01_main", `${item.label} missing first town task state.`);
  });

  console.log(JSON.stringify({ ok: true, screenshots: results.map((item) => `${outDir}/${item.label}-town.png`), results }, null, 2));
} finally {
  if (!server.killed) server.kill();
}
