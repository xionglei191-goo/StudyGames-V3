import { sceneConfigs, scenesById } from "../content/scenes.js";
import { sceneVisualProfiles } from "../content/sceneVisualProfiles.js";
import { imageAssetsByKey, rewardAssetKey } from "../content/assetCatalog.js";
import { taskConfigs, tasksBySceneId } from "../content/tasks.js";
import { englishStoryContentRows } from "../content/englishStoryContentTable.js";
import { getVerticalSliceCompletedCount, isVerticalSliceComplete, isVerticalSliceTask, verticalSliceGoal, verticalSliceTaskIds } from "../content/verticalSlice.js";
import { getReviewKnowledgeIds, loadProgress, logTelemetry } from "../data/progressStore.js";
import { eventBus } from "./EventBus.js";
import { taskRuntime } from "./TaskRuntime.js";

const Phaser = window.Phaser;

const imageAssets = imageAssetsByKey;

const sceneImages = {
  scene_town: "scene-town",
  scene_wardrobe: "scene-wardrobe",
  scene_kitchen: "scene-kitchen",
  scene_school: "scene-school",
  scene_city: "scene-city",
  scene_festival: "scene-festival",
  scene_nature: "scene-nature",
  scene_health: "scene-health",
  scene_study: "scene-study"
};

const anchorImages = {
  anchor_wardrobe_rack: "anchor-rack",
  anchor_wardrobe_mirror: "anchor-mirror",
  anchor_wardrobe_shoes: "anchor-shoes",
  anchor_kitchen_cup: "anchor-cup",
  anchor_kitchen_oven: "anchor-oven",
  anchor_kitchen_timer: "anchor-timer",
  anchor_school_board: "anchor-school-board",
  anchor_school_library: "anchor-school-library",
  anchor_school_playground: "anchor-school-playground",
  anchor_city_station: "anchor-city-station",
  anchor_city_map: "anchor-city-map",
  anchor_city_sign: "anchor-city-sign",
  anchor_festival_stage: "anchor-festival-stage",
  anchor_festival_craft: "anchor-festival-craft",
  anchor_festival_calendar: "anchor-festival-calendar",
  anchor_nature_garden: "anchor-nature-garden",
  anchor_nature_sky: "anchor-nature-sky",
  anchor_nature_earth: "anchor-nature-earth",
  anchor_health_sink: "anchor-health-sink",
  anchor_health_chart: "anchor-health-chart",
  anchor_health_kit: "anchor-health-kit",
  anchor_study_mailbox: "anchor-mailbox",
  anchor_study_map: "anchor-map",
  anchor_study_bookshelf: "anchor-bookshelf"
};

const optionPreviewImages = [
  ["trousers", "material-wardrobe-clothes"],
  ["cap", "item-headband"],
  ["driver", "material-city-jobs"],
  ["farmer", "material-city-jobs"],
  ["worker", "material-city-jobs"],
  ["nurse", "material-health-kit"],
  ["doctor", "material-health-kit"],
  ["teacher", "material-school-timetable"],
  ["student", "material-school-library"],
  ["bus", "material-city-transport"],
  ["train", "material-city-transport"],
  ["taxi", "material-city-transport"],
  ["plane", "material-city-transport"],
  ["bike", "material-city-transport"],
  ["underground", "material-city-transport"],
  ["on foot", "material-city-transport"],
  ["sing", "material-festival-stage"],
  ["dance", "material-festival-stage"],
  ["draw", "material-festival-craft"],
  ["paint", "material-festival-craft"],
  ["watch", "material-festival-calendar"],
  ["wash", "material-health-sink"],
  ["brush", "material-health-sink"],
  ["clean", "material-health-chart"],
  ["face", "material-health-sink"],
  ["teeth", "material-health-sink"],
  ["hair", "material-health-chart"],
  ["dress", "anchor-rack"],
  ["pink", "anchor-rack"],
  ["shoes", "anchor-shoes"],
  ["hat", "item-headband"],
  ["bag", "item-bag"],
  ["干净", "anchor-mirror"],
  ["整齐", "anchor-mirror"],
  ["柔软", "anchor-rack"],
  ["飞快", "anchor-shoes"],
  ["圆圆", "anchor-mirror"],
  ["响亮", "anchor-timer"],
  ["book", "item-book"],
  ["card", "item-cat-card"],
  ["flower", "item-flower"],
  ["spoon", "anchor-cup"],
  ["勺", "anchor-cup"],
  ["搅拌", "anchor-cup"],
  ["倒入", "anchor-oven"],
  ["烤箱", "anchor-oven"],
  ["分钟", "anchor-timer"],
  ["满满", "anchor-cup"],
  ["中间线", "anchor-cup"],
  ["一点点", "anchor-cup"],
  ["杯", "anchor-cup"],
  ["米娜", "anchor-mailbox"],
  ["露娜", "anchor-mailbox"],
  ["邮差", "anchor-mailbox"],
  ["next to", "anchor-mailbox"],
  ["旁边", "anchor-mailbox"],
  ["桌子下", "anchor-map"],
  ["下面", "anchor-mailbox"],
  ["上面", "anchor-mailbox"],
  ["厨房", "scene-kitchen"],
  ["信箱", "anchor-mailbox"],
  ["书架", "anchor-bookshelf"]
];

const outfitCharacterImages = {
  outfit_default: "character-default",
  outfit_sunny: "character-wave",
  outfit_cozy: "character-default",
  outfit_garden_bow: "character-wave",
  outfit_apron: "character-wave"
};

const rewardPreviewByTaskId = {
  task_wardrobe_001: { image: "anchor-rack", label: "花园蝴蝶结" },
  task_wardrobe_002: { image: "item-bag", label: "整理好的衣物篮" },
  task_kitchen_001: { image: "item-cake", label: "点心围裙" },
  task_kitchen_002: { image: "anchor-cup", label: "小蛋糕摆件" },
  task_study_001: { image: "anchor-mailbox", label: "小镇相册" },
  task_study_002: { image: "item-cat-card", label: "英文卡片角" }
};

const sceneRewardDecorByTaskId = {
  task_wardrobe_001: { image: "anchor-rack", label: "花园发饰", x: 650, y: 132, w: 58, h: 58 },
  task_wardrobe_002: { image: "item-bag", label: "衣物篮整理好", x: 728, y: 390, w: 52, h: 52 },
  task_kitchen_001: { image: "item-cake", label: "点心围裙", x: 594, y: 392, w: 64, h: 64 },
  task_kitchen_002: { image: "item-cake", label: "小蛋糕摆件", x: 434, y: 382, w: 72, h: 72 },
  task_study_001: { image: "anchor-bookshelf", label: "小镇相册", x: 666, y: 448, w: 60, h: 60 },
  task_study_002: { image: "item-cat-card", label: "英文卡片角", x: 704, y: 404, w: 46, h: 46 }
};

const stepWorldDecorByStepId = {
  task_wardrobe_001: {
    step_001: { image: "anchor-rack", label: "裙子选好", dx: 56, dy: -58, keep: true },
    step_002: { image: "anchor-shoes", label: "鞋子配好", dx: 72, dy: 54, keep: true }
  },
  task_wardrobe_002: {
    step_001: { image: "anchor-mirror", label: "镜子擦亮", dx: 58, dy: -54, keep: false },
    step_002: { image: "item-bag", label: "衣篮整理", dx: 72, dy: 52, keep: true }
  },
  task_kitchen_001: {
    step_001: { image: "anchor-cup", label: "面粉量好", dx: 66, dy: 52, keep: false },
    step_002: { image: "item-cake", label: "蛋糕进炉", dx: 74, dy: 52, keep: false }
  },
  task_kitchen_002: {
    step_001: { image: "anchor-cup", label: "半杯刚好", dx: 66, dy: 52, keep: false },
    step_002: { image: "anchor-timer", label: "铃声设好", dx: 58, dy: 48, keep: false }
  },
  task_study_001: {
    step_001: { image: "anchor-mailbox", label: "信件取出", dx: 66, dy: 52, keep: false },
    step_002: { image: "anchor-map", label: "地点找到", dx: 72, dy: 54, keep: false }
  },
  task_study_002: {
    step_001: { image: "item-cat-card", label: "卡片归位", dx: 68, dy: 54, keep: true },
    step_002: { image: "anchor-mailbox", label: "旁边放好", dx: 68, dy: 54, keep: false }
  }
};

const sceneAccent = {
  scene_town: 0xc75f78,
  scene_wardrobe: 0xd86a8b,
  scene_kitchen: 0x4f9d7a,
  scene_school: 0x557fd2,
  scene_city: 0x4f8f8d,
  scene_festival: 0xd96c4f,
  scene_nature: 0x5f9f57,
  scene_health: 0x43a98e,
  scene_study: 0x5f83c4
};

const sceneCharacterPositions = {
  scene_wardrobe: { x: 824, y: 512 },
  scene_kitchen: { x: 836, y: 512 },
  scene_school: { x: 834, y: 512 },
  scene_city: { x: 832, y: 512 },
  scene_festival: { x: 860, y: 512 },
  scene_nature: { x: 844, y: 512 },
  scene_health: { x: 858, y: 512 },
  scene_study: { x: 846, y: 512 }
};

const characterDisplay = {
  width: 132,
  height: 198,
  outfitScale: 0.62
};

const sceneCardTaskMap = {
  ...Object.fromEntries(sceneConfigs.filter((scene) => scene.id !== "scene_town").map((scene) => [scene.id, (tasksBySceneId[scene.id] || []).map((task) => task.id)]))
};

const townInteractionPoints = [
  {
    id: "clock_tower",
    label: "故事钟塔",
    action: "查看星路",
    x: 144,
    y: 268,
    width: 188,
    height: 236,
    approach: { x: 246, y: 452 },
    color: 0xc75f78
  },
  {
    id: "ray_board",
    label: "Keeper Ray / 公告牌",
    action: "接见面礼委托",
    x: 510,
    y: 344,
    width: 226,
    height: 154,
    approach: { x: 504, y: 496 },
    color: 0x426c7b
  },
  {
    id: "post_office",
    label: "邮局入口",
    action: "进入书房",
    x: 784,
    y: 310,
    width: 230,
    height: 188,
    approach: { x: 752, y: 500 },
    color: 0x5f83c4
  },
  {
    id: "mina_bell",
    label: "钟塔铃台 / Mina",
    action: "帮铃声回节奏",
    x: 324,
    y: 292,
    width: 166,
    height: 150,
    approach: { x: 348, y: 464 },
    color: 0xb48935
  },
  {
    id: "weather_station",
    label: "天气台 / 花园入口",
    action: "看看天空",
    x: 654,
    y: 426,
    width: 188,
    height: 142,
    approach: { x: 646, y: 524 },
    color: 0x4f9d7a
  }
];

const townRouteByTaskId = {
  task_eng_g3b_u01_main: {
    sceneId: "scene_study",
    startPointId: "post_office",
    guidePointId: "ray_board",
    goal: "去邮局找见面礼线索",
    destination: "邮局入口",
    panelAction: "去邮局",
    guideSpeech: "Ray：去邮局找见面礼线索",
    startSpeech: "进入邮局书房",
    nearSpeech: "点击邮局入口进入书房",
    source: "town_post_office"
  },
  task_eng_g3b_u02_main: {
    sceneId: "scene_kitchen",
    startPointId: "mina_bell",
    guidePointId: "mina_bell",
    goal: "去钟塔铃台找 Mina",
    destination: "钟塔铃台",
    panelAction: "找 Mina",
    guideSpeech: "Mina：钟塔铃声慢了一拍，来铃台看看吧。",
    startSpeech: "进入钟塔铃台",
    nearSpeech: "点击铃台帮 Mina 调回节奏",
    source: "town_mina_bell"
  },
  task_eng_g3b_u03_main: {
    sceneId: "scene_wardrobe",
    startPointId: "weather_station",
    guidePointId: "weather_station",
    goal: "去天气台看看天空",
    destination: "天气台",
    panelAction: "去天气台",
    guideSpeech: "天气台还暗着，先看看天空再准备出门。",
    startSpeech: "进入天气台",
    nearSpeech: "点击天气台找出门线索",
    source: "town_weather_station"
  }
};

function getTownRoute(task) {
  return townRouteByTaskId[task?.id] || townRouteByTaskId.task_eng_g3b_u01_main;
}

function getRuntimeSceneId(task) {
  return townRouteByTaskId[task?.id]?.sceneId || task?.sceneId;
}

class BootScene extends Phaser.Scene {
  constructor() {
    super("BootScene");
  }

  create() {
    this.scale.setGameSize(1024, 640);
    this.scene.start("PreloadScene");
  }
}

class PreloadScene extends Phaser.Scene {
  constructor() {
    super("PreloadScene");
  }

  preload() {
    this.load.setPath("src/assets/images");
    Object.entries(imageAssets).forEach(([key, file]) => this.load.image(key, file));
  }

  create() {
    window.__studyGameAssetsReady = true;
    window.__studyGameStatus = "ready";
    document.documentElement.dataset.studyGameStatus = "ready";
    eventBus.emit("game:ready", { scenes: sceneConfigs, tasks: taskConfigs });
    this.cameras.main.setBackgroundColor(0xf6e3bf);
    this.add.image(512, 320, "scene-town").setDisplaySize(1024, 640).setAlpha(0.38);
    this.add.rectangle(512, 320, 1024, 640, 0xfff7ea, 0.45);
    this.add.text(382, 304, "小镇准备中...", {
      fontFamily: "Arial, sans-serif",
      fontSize: "28px",
      color: "#4e3d3b",
      fontStyle: "bold"
    });
    const pendingSceneId = window.__studyGamePendingSceneId;
    window.__studyGamePendingSceneId = null;
    this.scene.start(scenesById[pendingSceneId]?.phaserKey || "TownScene");
  }
}

class BaseScene extends Phaser.Scene {
  constructor(key, sceneId) {
    super(key);
    this.sceneId = sceneId;
    this.anchorObjects = new Map();
    this.feedbackItems = [];
    this.previewGroup = null;
    this.targetMarker = null;
    this.placedOptionGroup = null;
    this.taskBubble = null;
    this.routeGuide = null;
    this.ambientGroup = null;
    this.sceneChoiceTray = null;
    this.anchorOptionPicker = null;
    this.anchorOptionPickerTaskId = null;
    this.anchorOptionPickerStepId = null;
    this.completedStepGroup = null;
    this.worldChangeGroup = null;
    this.transientWorldGroup = null;
    this.microInteractionGroup = null;
    this.roomMoodGroup = null;
    this.studyTrailGroup = null;
    this.hintGuideGroup = null;
    this.sceneIntroCard = null;
    this.lastIntroTaskId = null;
    this.emoteBubble = null;
    this.recipeBoardWrongUntil = 0;
    this.deferActiveTaskCueUntil = 0;
    this.deferredActiveTaskCueTimer = null;
    this.eventUnsubs = [];
  }

  create() {
    this.sceneConfig = scenesById[this.sceneId];
    this.anchorObjects = new Map();
    this.feedbackItems = [];
    this.eventUnsubs.forEach((unsubscribe) => unsubscribe());
    this.eventUnsubs = [];
    this.drawBackground(this.sceneConfig.color, this.sceneConfig.title, this.sceneConfig.description);
    this.drawSceneAtmosphere();
    if (!isVerticalSliceTask(taskRuntime.getState()?.task?.id)) {
      this.drawSceneSetDressing();
    }
    this.drawPersistentWorldChanges();
    const characterPosition = sceneCharacterPositions[this.sceneId] || { x: 838, y: 512 };
    this.drawCharacter(characterPosition.x, characterPosition.y);
    this.drawSceneActions();
    this.drawBackButton();
    this.bindRuntimeFeedback();
    this.showActiveTaskCue(taskRuntime.getState());
    eventBus.emit("scene:changed", { sceneId: this.sceneId });
    logTelemetry({ type: "scene_entered", sceneId: this.sceneId });
  }

  shutdown() {
    this.eventUnsubs.forEach((unsubscribe) => unsubscribe());
    this.eventUnsubs = [];
  }

  drawBackground(color, title, description) {
    this.cameras.main.setBackgroundColor(color);
    const imageKey = sceneImages[this.sceneId];
    if (imageKey && this.textures.exists(imageKey)) {
      this.add.image(512, 320, imageKey).setDisplaySize(1024, 640);
      this.add.rectangle(512, 320, 1024, 640, 0xfffbf5, 0.24);
    } else {
      this.add.rectangle(512, 320, 960, 560, 0xffffff, 0.22).setStrokeStyle(2, 0xffffff, 0.56);
    }
  }

  drawSceneAtmosphere() {
    return;
  }

  drawFloatingMotes(primary, secondary, count, top, bottom) {
    for (let i = 0; i < count; i += 1) {
      const x = 86 + i * 146 + (i % 2) * 34;
      const y = top + ((i * 53) % Math.max(1, bottom - top));
      const mote = this.add.circle(x, y, 3 + (i % 3), i % 2 ? primary : secondary, i % 2 ? 0.36 : 0.24);
      this.tweens.add({
        targets: mote,
        x: x + (i % 2 ? 18 : -18),
        y: y - 18,
        alpha: 0.58,
        duration: 1600 + i * 180,
        yoyo: true,
        repeat: -1,
        ease: "Sine.easeInOut"
      });
    }
  }

  drawForegroundDepth() {
    const accent = sceneAccent[this.sceneId] || 0xc75f78;
    this.add.ellipse(512, 622, 1050, 142, 0x4b3c36, 0.08);
    if (this.sceneId === "scene_wardrobe") {
      this.add.rectangle(512, 612, 1024, 56, 0xf7c9d8, 0.16);
      this.add.line(300, 578, 0, 0, 420, 0, 0xffffff, 0.18).setLineWidth(5);
      this.add.circle(886, 514, 36, accent, 0.08);
      return;
    }
    if (this.sceneId === "scene_kitchen") {
      this.add.rectangle(512, 602, 1024, 76, 0xb9dcb9, 0.14);
      this.add.rectangle(516, 536, 512, 28, 0xffffff, 0.16);
      this.add.line(260, 552, 0, 0, 520, 0, accent, 0.12).setLineWidth(4);
      return;
    }
    if (["scene_school", "scene_city", "scene_festival", "scene_nature", "scene_health"].includes(this.sceneId)) {
      this.add.rectangle(512, 604, 1024, 72, accent, 0.1);
      this.add.rectangle(514, 524, 430, 26, 0xffffff, 0.13);
      this.add.line(304, 542, 0, 0, 420, 0, accent, 0.14).setLineWidth(4);
      return;
    }
    if (this.sceneId === "scene_study") {
      this.add.rectangle(512, 604, 1024, 72, 0xb7cdea, 0.14);
      this.add.rectangle(514, 520, 360, 26, 0xffffff, 0.14);
      this.add.line(334, 538, 0, 0, 360, 0, accent, 0.14).setLineWidth(4);
      return;
    }
    this.add.rectangle(512, 604, 1024, 70, accent, 0.08);
  }

  drawSceneSetDressing() {
    const profile = sceneVisualProfiles[this.sceneId];
    if (profile?.centerpieces?.length) {
      this.drawProfileSceneSetDressing(profile);
    }
  }

  drawProfileSceneSetDressing(profile) {
    const accent = sceneAccent[this.sceneId] || 0xc75f78;
    const groundedProps = this.sceneId === "scene_study";
    profile.centerpieces.forEach((item, index) => {
      if (!this.textures.exists(item.image)) return;
      const sprite = this.add.image(item.x, item.y, item.image)
        .setDisplaySize(item.width, item.height)
        .setAlpha(0.9)
        .setDepth(1 + index * 0.01);
      const shadow = this.add.ellipse(item.x, item.y + item.height * 0.36, item.width * 0.72, Math.max(22, item.height * 0.14), 0x4b3c36, 0.09)
        .setDepth(0.5);
      if (groundedProps) {
        this.tweens.add({ targets: sprite, alpha: 0.98, duration: 1250 + index * 120, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
      } else {
        this.floatDecor(sprite, 2 + (index % 2), 1260 + index * 140);
      }
      this.makeMicroProp(sprite, {
        label: item.microCopy || item.label,
        icon: item.image,
        color: accent
      });
      shadow.setAlpha(0.08);
    });
  }

  makeMicroProp(target, config) {
    if (!target?.setInteractive) return;
    const baseScaleX = target.scaleX;
    const baseScaleY = target.scaleY;
    target.setInteractive({ useHandCursor: true });
    target.isMicroProp = true;
    target.microPropLabel = config.label;
    target.microPropBaseScaleX = baseScaleX;
    target.microPropBaseScaleY = baseScaleY;
    target.on("pointerover", () => {
      target.setAlpha(1);
      target.microPropScaleTween?.stop();
      target.microPropScaleTween = this.tweens.add({ targets: target, scaleX: baseScaleX * 1.08, scaleY: baseScaleY * 1.08, duration: 120, ease: "Sine.easeOut" });
    });
    target.on("pointerout", () => {
      target.setAlpha(0.82);
      target.microPropScaleTween?.stop();
      target.microPropScaleTween = this.tweens.add({ targets: target, scaleX: baseScaleX, scaleY: baseScaleY, duration: 120, ease: "Sine.easeOut" });
    });
    target.on("pointerdown", () => this.playMicroInteraction(target, config));
  }

  playMicroInteraction(target, config) {
    if (!target) return;
    if (this.microInteractionGroup) {
      this.microInteractionGroup.destroy();
      this.microInteractionGroup = null;
    }
    const accent = config.color || sceneAccent[this.sceneId] || 0xc75f78;
    this.tweens.add({ targets: target, angle: target.angle + 7, duration: 70, yoyo: true, repeat: 2, ease: "Sine.easeInOut" });
    this.microInteractionGroup = this.add.container(target.x, target.y - 54).setDepth(18);
    const panel = this.add.rectangle(0, 0, 218, 42, 0xfffbf5, 0.92).setStrokeStyle(2, accent, 0.42);
    const icon = this.add.image(-90, 0, config.icon || "icon-star").setDisplaySize(28, 28);
    const text = this.add.text(-66, -10, config.label, {
      fontFamily: "Arial, sans-serif",
      fontSize: "14px",
      color: "#3e332f",
      fontStyle: "bold"
    });
    this.microInteractionGroup.add([panel, icon, text]);
    this.microInteractionGroup.setAlpha(0);
    this.microInteractionGroup.setScale(0.9);
    this.tweens.add({ targets: this.microInteractionGroup, alpha: 1, scale: 1, y: this.microInteractionGroup.y - 8, duration: 160, ease: "Back.Out" });
    this.emitTinySparkles(target.x, target.y, accent, 6);
    this.showRoomMood(config.label, accent);
    this.time.delayedCall(1100, () => {
      if (!this.microInteractionGroup) return;
      const group = this.microInteractionGroup;
      this.microInteractionGroup = null;
      this.tweens.add({ targets: group, alpha: 0, y: group.y - 12, duration: 220, onComplete: () => group.destroy() });
    });
  }

  drawBackButton() {
    return;
  }

  drawCharacter(x, y) {
    const progress = loadProgress();
    this.add.ellipse(x + 2, y + 10, 132, 28, 0x6d4f49, 0.12).setDepth(4);
    const key = outfitCharacterImages[progress.selectedOutfitId] || (progress.completedTaskIds.length > 0 ? "character-wave" : "character-default");
    const characterY = y - 86;
    this.characterSprite = this.add.image(x, characterY, key).setDisplaySize(characterDisplay.width, characterDisplay.height).setDepth(5);
    this.characterOutfitGroup = this.add.container(x, y - 92).setDepth(6);
    this.drawCharacterOutfitLayers(this.characterOutfitGroup, progress.selectedOutfitId, false);
    this.characterOutfitGroup.setPosition(x, characterY);
    this.characterOutfitGroup.setScale(characterDisplay.outfitScale);
    this.tweens.add({
      targets: [this.characterSprite, this.characterOutfitGroup],
      y: this.characterSprite.y - 5,
      duration: 1500,
      yoyo: true,
      repeat: -1,
      ease: "Sine.easeInOut"
    });
    this.characterLabel = null;
    const hitArea = this.add.rectangle(x, characterY, characterDisplay.width, characterDisplay.height, 0xffffff, 0.001).setInteractive({ useHandCursor: true }).setDepth(8);
    this.characterHitArea = hitArea;
    hitArea.on("pointerdown", () => this.handleCharacterClick());
  }

  handleCharacterClick() {
    const state = taskRuntime.getState();
    if (getRuntimeSceneId(state?.task) === this.sceneId) {
      this.playCharacterReact("idle");
      this.setCharacterLine(`一起去${this.getAnchorName(state.step.anchorId)}`);
      this.showActiveTaskCue(state);
      return;
    }
    this.playCharacterReact("idle");
    this.setCharacterLine("等你安排");
  }

  drawCharacterOutfitLayers(group, outfitId, townScale) {
    drawOutfitLayers(this, group, outfitId, townScale);
  }

  drawSceneActions() {
    this.sceneConfig.anchors.forEach((anchor, index) => {
      const container = this.add.container(anchor.x, anchor.y).setDepth(8);
      const hotspotWidth = anchor.width;
      const hotspotHeight = anchor.height;
      const accent = sceneAccent[this.sceneId] || 0xc75f78;
      const glow = this.add.ellipse(0, 0, hotspotWidth + 22, hotspotHeight + 16, accent, 0).setStrokeStyle(3, accent, 0);
      const rect = this.add.rectangle(0, 0, hotspotWidth, hotspotHeight, 0xffffff, 0.001);
      rect.setInteractive({ useHandCursor: true });
      container.add([glow, rect]);
      const labelPanel = null;
      const nameText = null;
      const actionText = null;
      this.anchorObjects.set(anchor.id, { anchor, container, rect, glow, actionText, labelPanel, nameText });

      rect.on("pointerover", () => {
        this.tweens.add({ targets: container, scale: 1.035, duration: 120, ease: "Sine.easeOut" });
      });
      rect.on("pointerout", () => {
        this.tweens.add({ targets: container, scale: 1, duration: 120, ease: "Sine.easeOut" });
      });
      rect.on("pointerdown", () => {
        const state = taskRuntime.getState();
        if (getRuntimeSceneId(state?.task) === this.sceneId) {
          this.handleAnchorTaskClick(anchor.id, state);
          return;
        }
        this.pulseAnchor(anchor.id);
      });
    });
  }

  drawOvenAnchorFallback(container, hotspotWidth, hotspotHeight) {
    const body = this.add.rectangle(0, 10, Math.min(hotspotWidth - 38, 116), Math.min(hotspotHeight - 34, 74), 0xfffbf5, 0.86)
      .setStrokeStyle(3, 0x4f9d7a, 0.36);
    const window = this.add.rectangle(-16, 18, 48, 34, 0xd5e9ec, 0.82)
      .setStrokeStyle(2, 0xffffff, 0.72);
    const handle = this.add.rectangle(0, -20, 72, 7, 0x6f8f88, 0.58);
    const knobA = this.add.circle(32, -2, 7, 0x4f9d7a, 0.72);
    const knobB = this.add.circle(48, -2, 7, 0x4f9d7a, 0.48);
    const cake = this.add.image(-16, 17, "item-cake").setDisplaySize(30, 30).setAlpha(0.9);
    container.add([body, window, handle, knobA, knobB, cake]);
  }

  handleAnchorTaskClick(anchorId, state) {
    const activeAnchorId = state.step?.anchorId;
    if (!activeAnchorId) return;
    if (anchorId === activeAnchorId) {
      this.pulseAnchor(anchorId);
      this.showActiveTaskCue(state);
      return;
    }
    const active = this.anchorObjects.get(activeAnchorId);
    this.pulseAnchor(activeAnchorId);
    this.showGuideBackToActiveAnchor(active?.anchor);
    this.setCharacterLine(`先去${this.getAnchorName(activeAnchorId)}`);
  }

  getAnchorActionText(anchorId) {
    const state = taskRuntime.getState();
    if (getRuntimeSceneId(state?.task) !== this.sceneId) return "查看";
    if (state.step?.anchorId === anchorId) return targetActionLabel(state.step.type);
    return "稍后";
  }

  showGuideBackToActiveAnchor(anchor) {
    if (!anchor) return;
    const accent = sceneAccent[this.sceneId] || 0xc75f78;
    const guide = this.add.container(anchor.x, anchor.y).setDepth(18);
    const ring = this.add.ellipse(0, 0, Math.min(anchor.width + 62, 250), Math.min(anchor.height + 50, 216), 0xffffff, 0.18)
      .setStrokeStyle(5, accent, 0.72);
    const tag = this.add.text(-78, -Math.min(anchor.height / 2, 82) - 52, "先到这里", {
      fontFamily: "Arial, sans-serif",
      fontSize: "15px",
      color: "#ffffff",
      fontStyle: "bold",
      backgroundColor: "rgba(66,108,123,0.84)"
    }).setPadding(10, 5, 10, 5);
    guide.add([ring, tag]);
    guide.setAlpha(0);
    this.tweens.add({ targets: guide, alpha: 1, scale: 1.04, duration: 160, yoyo: true, hold: 480, onComplete: () => guide.destroy() });
  }

  drawPersistentWorldChanges() {
    const progress = loadProgress();
    this.drawProfileRewardCollection(progress);
  }

  drawProfileRewardCollection(progress) {
    const profile = sceneVisualProfiles[this.sceneId];
    if (!profile?.rewardSlots?.length) return;
    const completed = new Set(progress.completedTaskIds || []);
    const rows = englishStoryContentRows
      .filter((row) => row.sceneId === this.sceneId && completed.has(row.taskId))
      .slice(-profile.rewardSlots.length);
    if (!rows.length) return;

    const accent = sceneAccent[this.sceneId] || 0xc75f78;
    const group = this.add.container(0, 0).setDepth(4);
    rows.forEach((row, index) => {
      const [x, y] = profile.rewardSlots[index];
      const token = this.add.container(x, y);
      const halo = this.add.circle(0, 0, 24, 0xffffff, 0.58).setStrokeStyle(2, accent, 0.34);
      const image = this.add.image(0, 0, rewardAssetKey(row.rewardId)).setDisplaySize(38, 38).setAlpha(0.96);
      token.add([halo, image]);
      token.setScale(0.9);
      group.add(token);
      if (this.sceneId === "scene_study") {
        this.tweens.add({ targets: halo, alpha: 0.72, duration: 1150 + index * 110, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
      } else {
        this.floatDecor(token, 2 + (index % 2), 1120 + index * 120);
      }
    });
  }

  drawEnglishStoryRoomProgress(progress) {
    const completed = new Set(progress.completedTaskIds || []);
    const sceneRows = englishStoryContentRows.filter((row) => row.sceneId === this.sceneId);
    const completedRows = sceneRows.filter((row) => completed.has(row.taskId));
    if (!completedRows.length) return;

    if (this.sceneId === "scene_wardrobe") {
      this.drawWardrobeEnglishProgress(completedRows);
      return;
    }
    if (this.sceneId === "scene_kitchen") {
      this.drawKitchenEnglishProgress(completedRows);
      return;
    }
    if (this.sceneId === "scene_school") {
      this.drawThemeEnglishProgress(completedRows, { label: "校园任务", total: sceneRows.length, icon: "item-book", secondIcon: "anchor-bookshelf", x: 194 });
      return;
    }
    if (this.sceneId === "scene_city") {
      this.drawThemeEnglishProgress(completedRows, { label: "街区任务", total: sceneRows.length, icon: "anchor-map", secondIcon: "item-key", x: 196 });
      return;
    }
    if (this.sceneId === "scene_festival") {
      this.drawThemeEnglishProgress(completedRows, { label: "节日任务", total: sceneRows.length, icon: "item-gift", secondIcon: "anchor-timer", x: 198 });
      return;
    }
    if (this.sceneId === "scene_nature") {
      this.drawThemeEnglishProgress(completedRows, { label: "自然任务", total: sceneRows.length, icon: "item-flower", secondIcon: "item-butterfly-card", x: 196 });
      return;
    }
    if (this.sceneId === "scene_health") {
      this.drawThemeEnglishProgress(completedRows, { label: "健康任务", total: sceneRows.length, icon: "anchor-cup", secondIcon: "item-cat-card", x: 196 });
      return;
    }
    if (this.sceneId === "scene_study") {
      this.drawStudyEnglishProgress(completedRows);
    }
  }

  drawWardrobeEnglishProgress(rows) {
    const outfitCount = rows.filter((row) => row.rewardCategory === "outfit").length;
    const badgeCount = rows.filter((row) => row.rewardCategory === "badge").length;
    const group = this.add.container(170, 132).setDepth(3);
    const rail = this.add.rectangle(0, 0, 164, 44, 0xfffbf5, 0.72).setStrokeStyle(2, 0xffffff, 0.72);
    const bow = this.add.image(-55, -2, "item-bow").setDisplaySize(34, 34).setAlpha(0.94);
    const star = this.add.image(-18, -4, "icon-star").setDisplaySize(24, 24).setAlpha(0.84);
    const title = this.add.text(10, -15, `英语服饰 ${outfitCount}`, decorTextStyle()).setPadding(7, 4, 7, 4);
    const copy = this.add.text(10, 9, `徽章 ${badgeCount}`, decorTextStyle()).setPadding(7, 4, 7, 4);
    group.add([rail, bow, star, title, copy]);
    this.floatDecor(bow, 4, 1180);
    if (rows.length >= 3) {
      const hanger = this.add.image(660, 144, "anchor-rack").setDisplaySize(58, 58).setAlpha(0.9).setDepth(3);
      this.add.text(692, 126, "英语搭配角", decorTextStyle()).setPadding(8, 5, 8, 5).setDepth(3);
      this.floatDecor(hanger, 4, 1260);
    }
  }

  drawKitchenEnglishProgress(rows) {
    const group = this.add.container(202, 128).setDepth(3);
    const board = this.add.rectangle(0, 0, 190, 58, 0xfffbf5, 0.76).setStrokeStyle(2, 0xffffff, 0.72);
    const cup = this.add.image(-68, -2, "anchor-cup").setDisplaySize(38, 38).setAlpha(0.94);
    const timer = this.add.image(-31, -2, "anchor-timer").setDisplaySize(34, 34).setAlpha(0.9);
    const title = this.add.text(0, -18, `英语厨房 ${rows.length}/8`, decorTextStyle()).setPadding(7, 4, 7, 4);
    const copy = this.add.text(0, 9, rows.at(-1)?.rewardTitle || "菜谱星片", decorTextStyle()).setPadding(7, 4, 7, 4);
    group.add([board, cup, timer, title, copy]);
    this.floatDecor(cup, 3, 1150);
    if (rows.length >= 4) {
      const cake = this.add.image(512, 390, "item-cake").setDisplaySize(62, 62).setAlpha(0.94).setDepth(3);
      this.add.text(542, 424, "英语点心台", decorTextStyle()).setPadding(8, 5, 8, 5).setDepth(3);
      this.floatDecor(cake, 4, 1220);
    }
  }

  drawThemeEnglishProgress(rows, config) {
    const group = this.add.container(config.x || 190, 130).setDepth(3);
    const panel = this.add.rectangle(0, 0, 220, 62, 0xfffbf5, 0.76).setStrokeStyle(2, 0xffffff, 0.72);
    const icon = this.add.image(-78, -4, config.icon).setDisplaySize(36, 38).setAlpha(0.94);
    const secondIcon = this.add.image(-40, -4, config.secondIcon || "icon-star").setDisplaySize(30, 30).setAlpha(0.88);
    const title = this.add.text(-4, -19, `${config.label} ${rows.length}/${config.total}`, decorTextStyle()).setPadding(7, 4, 7, 4);
    const copy = this.add.text(-4, 9, rows.at(-1)?.rewardTitle || "英语星片", decorTextStyle()).setPadding(7, 4, 7, 4);
    group.add([panel, icon, secondIcon, title, copy]);
    this.floatDecor(icon, 3, 1180);
    if (rows.length >= 4) {
      const star = this.add.image(722, 132, "icon-star").setDisplaySize(30, 30).setTint(sceneAccent[this.sceneId] || 0xc75f78).setAlpha(0.86).setDepth(3);
      this.add.text(752, 116, "主线进度", decorTextStyle()).setPadding(8, 5, 8, 5).setDepth(3);
      this.floatDecor(star, 4, 1280);
    }
  }

  drawStudyEnglishProgress(rows) {
    const albumCount = rows.filter((row) => row.rewardCategory === "album").length;
    const badgeCount = rows.filter((row) => row.rewardCategory === "badge").length;
    const group = this.add.container(190, 130).setDepth(3);
    const panel = this.add.rectangle(0, 0, 210, 62, 0xfffbf5, 0.76).setStrokeStyle(2, 0xffffff, 0.72);
    const book = this.add.image(-76, -3, "item-book").setDisplaySize(38, 42).setAlpha(0.94);
    const star = this.add.image(-38, -4, "icon-star").setDisplaySize(25, 25).setAlpha(0.84);
    const title = this.add.text(-4, -19, `英语星册 ${rows.length}/62`, decorTextStyle()).setPadding(7, 4, 7, 4);
    const copy = this.add.text(-4, 9, `相册 ${albumCount} · 徽章 ${badgeCount}`, decorTextStyle()).setPadding(7, 4, 7, 4);
    group.add([panel, book, star, title, copy]);
    this.tweens.add({ targets: star, alpha: 0.98, duration: 1180, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    if (rows.length >= 10) {
      this.drawStudyCardDecor();
    }
    if (rows.length >= 30) {
      const badgeWall = this.add.container(786, 168).setDepth(3);
      const back = this.add.rectangle(0, 0, 118, 64, 0xfff6dc, 0.72).setStrokeStyle(2, 0x5f83c4, 0.28);
      const key = this.add.image(-32, -4, "item-cat-card").setDisplaySize(34, 40).setAlpha(0.9);
      const card = this.add.image(12, -4, "item-apple-card").setDisplaySize(34, 40).setAlpha(0.9);
      const label = this.add.text(-48, 28, "主线徽章墙", decorTextStyle()).setPadding(7, 4, 7, 4);
      badgeWall.add([back, key, card, label]);
      this.tweens.add({ targets: [key, card], alpha: 1, duration: 1320, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    }
  }

  drawWardrobeOrganizedDecor() {
    const group = this.add.container(746, 382);
    const basket = this.add.rectangle(0, 22, 132, 54, 0xfff2dc, 0.78).setStrokeStyle(3, 0xd86a8b, 0.34);
    const lip = this.add.rectangle(0, -8, 146, 18, 0xffffff, 0.66).setStrokeStyle(2, 0xd86a8b, 0.22);
    const shoes = this.add.image(-42, 10, "anchor-shoes").setDisplaySize(44, 38).setAlpha(0.94);
    const bag = this.add.image(6, 8, "item-bag").setDisplaySize(38, 38).setAlpha(0.94);
    const bow = this.add.image(46, 6, "item-headband").setDisplaySize(40, 34).setAlpha(0.94);
    const shineA = this.add.image(-70, -34, "icon-star").setDisplaySize(22, 22).setAlpha(0.72);
    const shineB = this.add.image(70, -30, "icon-star").setDisplaySize(18, 18).setAlpha(0.58);
    group.add([basket, lip, shoes, bag, bow, shineA, shineB]);
    this.floatDecor(shineA, 4, 980);
    this.floatDecor(shineB, 5, 1180);

    const mirror = this.add.ellipse(488, 146, 132, 236, 0xffffff, 0.08).setStrokeStyle(3, 0xffffff, 0.28);
    const glint = this.add.line(462, 76, 0, 0, 54, -30, 0xffffff, 0.36).setLineWidth(4);
    this.tweens.add({ targets: [mirror, glint], alpha: 0.18, duration: 1300, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    return [group, mirror, glint];
  }

  drawStudyAlbumDecor() {
    const group = this.add.container(662, 434);
    const album = this.add.rectangle(0, 0, 82, 62, 0xfff6dc, 0.88).setStrokeStyle(3, 0x5f83c4, 0.32);
    const photo = this.add.rectangle(-15, -5, 28, 28, 0xd5e5f7, 0.9).setStrokeStyle(2, 0xffffff, 0.8);
    const mail = this.add.image(22, -8, "anchor-mailbox").setDisplaySize(32, 32).setAlpha(0.86);
    const mapPin = this.add.image(-6, 20, "anchor-map").setDisplaySize(34, 24).setAlpha(0.78);
    const star = this.add.image(40, 22, "icon-star").setDisplaySize(18, 18).setAlpha(0.74);
    group.add([album, photo, mail, mapPin, star]);
    this.tweens.add({ targets: star, alpha: 0.96, duration: 920, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    return [group];
  }

  drawStudyCardDecor() {
    const group = this.add.container(764, 406);
    const shelf = this.add.rectangle(0, 30, 162, 12, 0x8ab0d5, 0.32).setStrokeStyle(1, 0xffffff, 0.36);
    const book = this.add.image(-54, 0, "item-book").setDisplaySize(42, 46).setAlpha(0.94);
    const cat = this.add.image(-14, 0, "item-cat-card").setDisplaySize(38, 44).setAlpha(0.94);
    const apple = this.add.image(24, 1, "item-apple-card").setDisplaySize(38, 44).setAlpha(0.92);
    const butterfly = this.add.image(62, 0, "item-butterfly-card").setDisplaySize(38, 44).setAlpha(0.92);
    group.add([shelf, book, cat, apple, butterfly]);
    [book, cat, apple, butterfly].forEach((item, index) => {
      this.tweens.add({
        targets: item,
        alpha: 1,
        duration: 900 + index * 110,
        yoyo: true,
        repeat: -1,
        ease: "Sine.easeInOut"
      });
    });
    return [group];
  }

  popInWorldChange(targets) {
    const list = Array.isArray(targets) ? targets.filter(Boolean) : [targets].filter(Boolean);
    if (!list.length) return;
    list.forEach((target) => {
      target.setAlpha?.(0);
      target.setScale?.(0.82);
    });
    this.tweens.add({ targets: list, alpha: 1, scale: 1, duration: 260, ease: "Back.Out" });
  }

  floatDecor(target, distance, duration) {
    this.tweens.add({
      targets: target,
      y: target.y - distance,
      duration,
      yoyo: true,
      repeat: -1,
      ease: "Sine.easeInOut"
    });
  }

  bindRuntimeFeedback() {
    this.eventUnsubs.push(
      eventBus.on("task:started", (state) => {
        this.deferActiveTaskCueUntil = 0;
        this.clearCompletedStepArtifacts();
        this.lastIntroTaskId = null;
        this.showActiveTaskCue(state);
      }),
      eventBus.on("task:progress", (state) => this.showActiveTaskCue(state)),
      eventBus.on("task:hint-used", (detail) => this.showHintGuide(detail)),
      eventBus.on("task:step-correct", (detail) => this.showCorrectFeedback(detail)),
      eventBus.on("task:choice-wrong", (detail) => this.showWrongFeedback(detail)),
      eventBus.on("ui:preview-option", (detail) => this.showOptionPreview(detail.option))
    );
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.shutdown());
  }

  showActiveTaskCue(state) {
    const step = state?.step;
    if (!step) return;
    if (state.task?.sceneId === this.sceneId && this.deferActiveTaskCueUntil && this.time.now < this.deferActiveTaskCueUntil) {
      if (!this.deferredActiveTaskCueTimer) {
        const delay = Math.max(80, this.deferActiveTaskCueUntil - this.time.now);
        this.deferredActiveTaskCueTimer = this.time.delayedCall(delay, () => {
          this.deferredActiveTaskCueTimer = null;
          this.showActiveTaskCue(taskRuntime.getState());
        });
      }
      return;
    }
    this.clearOptionPreview();
    const shouldRefreshAnchorPicker = Boolean(
      this.anchorOptionPicker &&
      this.anchorOptionPickerTaskId === state.task?.id &&
      this.anchorOptionPickerStepId === step.id
    );
    if (this.anchorOptionPicker) {
      this.anchorOptionPicker.destroy();
      this.anchorOptionPicker = null;
      this.anchorOptionPickerTaskId = null;
      this.anchorOptionPickerStepId = null;
    }
    if (!shouldRefreshAnchorPicker) this.restoreSceneFocus();
    this.anchorObjects.forEach(({ glow }) => {
      glow.setAlpha(0.01);
      glow.setStrokeStyle(4, sceneAccent[this.sceneId] || 0xc75f78, 0);
    });
    if (getRuntimeSceneId(state.task) !== this.sceneId) return;
    this.anchorObjects.forEach(({ labelPanel, nameText }) => {
      labelPanel?.setAlpha(0);
      nameText?.setAlpha(0);
    });
    const active = this.anchorObjects.get(step.anchorId);
    active?.labelPanel?.setAlpha(0.84);
    active?.nameText?.setAlpha(1);
    this.pulseAnchor(step.anchorId, true);
    this.showTargetMarker(step);
    this.setCharacterLine(`看${this.getAnchorName(step.anchorId)}`);
  }

  showAnchorOptionPicker(state) {
    if (this.anchorOptionPicker) {
      this.anchorOptionPicker.destroy();
      this.anchorOptionPicker = null;
    }
    if (this.sceneChoiceTray) {
      this.sceneChoiceTray.destroy();
      this.sceneChoiceTray = null;
    }
    return;
    this.enterFocusedPickerMode();
    const step = state?.step;
    const target = step ? this.anchorObjects.get(step.anchorId)?.anchor : null;
    if (!step?.options?.length || !target) return;
    const accent = sceneAccent[this.sceneId] || 0xc75f78;
    const visibleOptions = step.options.slice(0, 4);
    const selected = new Set(state.selectedIds || []);
    const needsConfirm = step.type === "drag" || step.type === "match" || step.type === "order";
    const canSubmit = selected.size > 0;
    const tileWidth = step.type === "order" ? 80 : 74;
    const tileGap = 10;
    const width = Math.min(430, 64 + visibleOptions.length * tileWidth + Math.max(0, visibleOptions.length - 1) * tileGap + (needsConfirm ? 86 : 0));
    const height = step.type === "order" ? 176 : needsConfirm ? 128 : 94;
    const placement = this.getPickerPlacement(target, width, height);
    const x = placement.x;
    const y = placement.y;
    this.anchorOptionPicker = this.add.container(x, y).setDepth(19);
    this.anchorOptionPickerTaskId = state.task.id;
    this.anchorOptionPickerStepId = step.id;
    this.anchorOptionPickerHasConfirm = needsConfirm;
    this.anchorOptionPickerSelectedCount = selected.size;
    const panel = this.add.rectangle(0, 0, width, height, 0xfffbf5, 0.94).setStrokeStyle(3, accent, 0.36);
    const title = this.add.text(-width / 2 + 12, -height / 2 + 9, anchorPickerTitle(step.type), {
      fontFamily: "Arial, sans-serif",
      fontSize: "13px",
      color: "#5d4b45",
      fontStyle: "bold"
    });
    const progressText = needsConfirm
      ? this.add.text(width / 2 - 132, -height / 2 + 9, pickerSelectionLabel(step, selected.size), {
        fontFamily: "Arial, sans-serif",
        fontSize: "13px",
        color: canSubmit ? "#2f684f" : "#7b665a",
        fontStyle: "bold"
      })
      : null;
    this.anchorOptionPicker.add(progressText ? [panel, title, progressText] : [panel, title]);
    visibleOptions.forEach((option, index) => {
      const itemX = -width / 2 + 44 + tileWidth / 2 + index * (tileWidth + tileGap);
      const itemY = step.type === "order" ? 42 : 12;
      const picked = selected.has(option.id);
      const tile = this.add.rectangle(itemX, itemY, tileWidth, 68, picked ? 0xffeef3 : 0xffffff, 0.92)
        .setStrokeStyle(2, picked ? accent : 0xffffff, picked ? 0.72 : 0.52)
        .setInteractive({ useHandCursor: true });
      tile.optionId = option.id;
      tile.isAnchorOptionTile = true;
      tile.isSelectedOptionTile = picked;
      tile.anchorPickerLocalX = itemX;
      tile.anchorPickerLocalY = itemY;
      const image = this.add.image(itemX, itemY - 18, getOptionPreviewKey(option)).setDisplaySize(36, 36);
      const label = this.add.text(itemX - tileWidth / 2 + 5, itemY + 5, microOptionLabel(option.label), {
        fontFamily: "Arial, sans-serif",
        fontSize: step.type === "order" ? "12px" : "11px",
        color: "#4e3d3b",
        align: "center",
        lineSpacing: -1,
        wordWrap: { width: tileWidth - 10 }
      });
      const orderIndex = picked && step.type === "order" ? (state.selectedIds || []).indexOf(option.id) + 1 : 0;
      const check = picked ? this.add.circle(itemX + tileWidth / 2 - 10, itemY - 34, 9, accent, 0.92) : null;
      const checkText = picked ? this.add.text(itemX + tileWidth / 2 - (orderIndex ? 5 : 14), itemY - 43, orderIndex ? String(orderIndex) : "✓", {
        fontFamily: "Arial, sans-serif",
        fontSize: "14px",
        color: "#ffffff",
        fontStyle: "bold"
      }) : null;
      tile.on("pointerover", () => this.showOptionPreview(option));
      tile.on("pointerout", () => this.showOptionPreview(null));
      if (step.type === "drag" || step.type === "order") {
        tile.anchorPickerDragMoved = false;
        tile.disableInteractive();
        tile.setInteractive({ useHandCursor: true, draggable: true });
        this.input.setDraggable(tile);
        tile.isAnchorPickerDraggable = true;
        tile.on("pointerup", () => {
          if (!tile.anchorPickerDragMoved) {
            this.showOptionTargetPulse(step.anchorId, option);
            eventBus.emit("scene:choose-option", { optionId: option.id });
          }
          this.time.delayedCall(0, () => {
            tile.anchorPickerDragMoved = false;
          });
        });
        tile.on("dragstart", (pointer) => {
          tile.anchorPickerDragMoved = true;
          this.startSceneDragPreview(option, pointer);
        });
        tile.on("drag", (pointer) => this.moveSceneDragPreview(pointer));
        tile.on("dragend", (pointer) => {
          this.finishSceneDragPreview(pointer, step, option, { autoSubmit: step.type === "drag" });
          this.time.delayedCall(0, () => {
            tile.anchorPickerDragMoved = false;
          });
        });
      } else {
        tile.on("pointerdown", () => {
          this.showOptionTargetPulse(step.anchorId, option);
          eventBus.emit("scene:choose-option", { optionId: option.id });
        });
      }
      this.anchorOptionPicker.add(check ? [tile, image, label, check, checkText] : [tile, image, label]);
    });
    if (step.type === "order") {
      this.addRecipeSlotsToPicker(state, width, height, accent);
    }
    if (needsConfirm) {
      const confirmY = step.type === "order" ? 42 : 12;
      const confirm = this.add.rectangle(width / 2 - 58, confirmY, 92, 70, 0x426c7b, canSubmit ? 0.92 : 0.34)
        .setStrokeStyle(1, 0xffffff, 0.42)
        .setInteractive({ useHandCursor: canSubmit });
      confirm.isAnchorOptionConfirm = true;
      const confirmText = this.add.text(width / 2 - 88, confirmY - 9, pickerConfirmLabel(step.type), {
        fontFamily: "Arial, sans-serif",
        fontSize: "13px",
        color: "#ffffff",
        fontStyle: "bold"
      });
      confirm.on("pointerdown", () => {
        if (canSubmit) eventBus.emit("scene:submit-options");
      });
      this.anchorOptionPicker.add([confirm, confirmText]);
    }
    this.anchorOptionPicker.setAlpha(0);
    this.anchorOptionPicker.setScale(0.88);
    this.tweens.add({ targets: this.anchorOptionPicker, alpha: 1, scale: 1, y: y - 4, duration: 180, ease: "Back.Out" });
  }

  enterFocusedPickerMode() {
    ["taskBubble", "routeGuide", "placedOptionGroup"].forEach((key) => {
      if (!this[key]) return;
      this[key].destroy();
      this[key] = null;
    });
    if (this.targetMarker) this.targetMarker.setAlpha(0.12);
    if (this.ambientGroup) this.ambientGroup.setAlpha(0.38);
    if (this.characterSprite) {
      this.characterSprite.setAlpha(0.78);
      this.characterOutfitGroup?.setAlpha(0.78);
    }
  }

  addRecipeSlotsToPicker(state, width, height, accent) {
    const step = state?.step;
    if (step?.type !== "order") return;
    const selectedIds = state.selectedIds || [];
    const wrongActive = this.recipeBoardWrongUntil && this.time.now < this.recipeBoardWrongUntil;
    this.anchorOptionPicker.isRecipePickerWrong = Boolean(wrongActive);
    const slotCount = step.correctOptionIds.length;
    const startX = -width / 2 + 30;
    const slotWidth = Math.min(82, (width - 128) / Math.max(slotCount, 1));
    const y = -height / 2 + 54;
    const title = this.add.text(startX, y - 23, wrongActive ? "重新排" : "配方槽", {
      fontFamily: "Arial, sans-serif",
      fontSize: "13px",
      color: wrongActive ? "#8e4e52" : "#5d4b45",
      fontStyle: "bold"
    });
    this.anchorOptionPicker.add(title);
    for (let index = 0; index < slotCount; index += 1) {
      const optionId = selectedIds[index];
      const option = step.options.find((item) => item.id === optionId);
      const x = startX + 78 + index * slotWidth;
      const slot = this.add.container(x, y).setDepth(1);
      slot.isRecipeSlot = true;
      const emptyStroke = wrongActive ? 0x8e4e52 : 0xd8c9b7;
      const plate = this.add.rectangle(0, 0, 58, 42, option ? 0xe9f7ed : wrongActive ? 0xffeee8 : 0xffffff, option ? 0.96 : 0.72)
        .setStrokeStyle(2, option ? accent : emptyStroke, option ? 0.72 : 0.52);
      const num = this.add.circle(-20, -15, 10, option ? accent : emptyStroke, 0.92);
      const numText = this.add.text(-24, -23, String(index + 1), {
        fontFamily: "Arial, sans-serif",
        fontSize: "13px",
        color: "#ffffff",
        fontStyle: "bold"
      });
      slot.add([plate, num, numText]);
      if (option) {
        const icon = this.add.image(7, 1, getOptionPreviewKey(option)).setDisplaySize(32, 32);
        slot.add(icon);
      } else {
        const dash = this.add.text(-8, -10, "+", {
          fontFamily: "Arial, sans-serif",
          fontSize: "22px",
          color: "#a39186",
          fontStyle: "bold"
        });
        slot.add(dash);
      }
      this.anchorOptionPicker.add(slot);
    }
  }

  restoreSceneFocus() {
    if (this.characterSprite) {
      this.characterSprite.setAlpha(1);
      this.characterOutfitGroup?.setAlpha(1);
    }
    this.targetMarker?.setAlpha(0.9);
    this.ambientGroup?.setAlpha(1);
  }

  getPickerPlacement(target, width, height) {
    const candidates = [
      { x: target.x, y: target.y - Math.min(target.height / 2 + height / 2 + 22, 170) },
      { x: target.x, y: target.y + Math.min(target.height / 2 + height / 2 + 24, 160) },
      { x: target.x - Math.min(target.width / 2 + width / 2 + 26, 260), y: target.y },
      { x: target.x + Math.min(target.width / 2 + width / 2 + 26, 260), y: target.y }
    ].map((candidate) => ({
      x: Phaser.Math.Clamp(candidate.x, width / 2 + 24, 1024 - width / 2 - 24),
      y: Phaser.Math.Clamp(candidate.y, 112 + height / 2, 596 - height / 2)
    }));
    const characterBox = new Phaser.Geom.Rectangle(748, 246, 210, 338);
    const scoreCandidate = (candidate) => {
      const box = new Phaser.Geom.Rectangle(candidate.x - width / 2, candidate.y - height / 2, width, height);
      const overlap = Phaser.Geom.Intersects.RectangleToRectangle(box, characterBox) ? 1 : 0;
      const edgePenalty = Math.abs(candidate.x - 512) * 0.002 + Math.max(0, candidate.y - 450) * 0.01;
      return overlap * 100 + edgePenalty;
    };
    return candidates.sort((a, b) => scoreCandidate(a) - scoreCandidate(b))[0];
  }

  showTargetMarker(step) {
    const anchorId = step?.anchorId;
    const target = this.anchorObjects.get(anchorId);
    if (!target) return;
    if (this.targetMarker) this.targetMarker.destroy();
    const accent = sceneAccent[this.sceneId] || 0xc75f78;
    this.targetMarker = this.add.container(target.anchor.x, target.anchor.y).setDepth(13);
    const zoneWidth = Math.min(target.anchor.width + 30, 230);
    const zoneHeight = Math.min(target.anchor.height + 22, 190);
    const dropZone = this.add.ellipse(0, 0, zoneWidth, zoneHeight, 0xffffff, 0)
      .setStrokeStyle(3, accent, 0.28);
    this.targetMarker.add(dropZone);
    this.targetMarker.setAlpha(0.42);
    this.tweens.add({ targets: dropZone, scaleX: 1.015, scaleY: 1.015, alpha: 0.04, duration: 900, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
  }

  showAmbientCue(anchorId) {
    if (this.ambientGroup) {
      this.ambientGroup.destroy();
      this.ambientGroup = null;
    }
    const target = this.anchorObjects.get(anchorId);
    if (!target) return;
    this.ambientGroup = this.add.container(target.anchor.x, target.anchor.y);
    for (let i = 0; i < 9; i += 1) {
      const angle = (Math.PI * 2 * i) / 7;
      const radius = 42 + (i % 3) * 13;
      const sparkle = this.add.circle(
        Math.cos(angle) * radius,
        Math.sin(angle) * radius * 0.58,
        i % 3 === 0 ? 4 : 3,
        i % 2 ? 0xffffff : sceneAccent[this.sceneId] || 0xc75f78,
        i % 2 ? 0.62 : 0.42
      );
      this.ambientGroup.add(sparkle);
      this.tweens.add({
        targets: sparkle,
        alpha: 0.82,
        y: sparkle.y - 10,
        scaleX: 1.35,
        scaleY: 1.35,
        duration: 700 + i * 90,
        yoyo: true,
        repeat: -1,
        ease: "Sine.easeInOut"
      });
    }
  }

  showHintGuide(detail) {
    if (detail.task.sceneId !== this.sceneId) return;
    const target = this.anchorObjects.get(detail.step.anchorId);
    if (!target) return;
    if (this.hintGuideGroup) {
      this.hintGuideGroup.destroy();
      this.hintGuideGroup = null;
    }
    const accent = sceneAccent[this.sceneId] || 0xc75f78;
    this.hintGuideGroup = this.add.container(0, 0).setDepth(15);
    const anchor = target.anchor;
    const spotlight = this.add.ellipse(anchor.x, anchor.y, Math.min(anchor.width + 86, 260), Math.min(anchor.height + 72, 230), 0xffffff, 0.14)
      .setStrokeStyle(5, accent, 0.5);
    const magnifier = this.add.container(anchor.x + Math.min(anchor.width / 2 + 34, 124), anchor.y - Math.min(anchor.height / 2 + 24, 92));
    const lens = this.add.circle(0, 0, 27, 0xffffff, 0.9).setStrokeStyle(4, accent, 0.72);
    const handle = this.add.line(20, 22, 0, 0, 26, 26, accent, 0.72).setLineWidth(5);
    const clue = this.add.text(-132, 42, compactPrompt(detail.hint || detail.step.hintCopy, 30), {
      fontFamily: "Arial, sans-serif",
      fontSize: "14px",
      color: "#3e332f",
      backgroundColor: "rgba(255,250,244,0.88)",
      wordWrap: { width: 228 }
    }).setPadding(9, 6, 9, 6);
    magnifier.add([lens, handle]);
    this.hintGuideGroup.add([spotlight, magnifier, clue]);
    this.hintGuideGroup.setAlpha(0);
    this.tweens.add({ targets: this.hintGuideGroup, alpha: 1, duration: 160, ease: "Sine.easeOut" });
    this.tweens.add({ targets: spotlight, scaleX: 1.08, scaleY: 1.08, alpha: 0.28, duration: 520, yoyo: true, repeat: 2, ease: "Sine.easeInOut" });
    this.tweens.add({ targets: magnifier, angle: 8, y: magnifier.y - 8, duration: 360, yoyo: true, repeat: 2, ease: "Sine.easeInOut" });
    this.time.delayedCall(2200, () => {
      if (!this.hintGuideGroup) return;
      const guide = this.hintGuideGroup;
      this.hintGuideGroup = null;
      this.tweens.add({ targets: guide, alpha: 0, duration: 260, onComplete: () => guide.destroy() });
    });
  }

  showOptionPreview(option) {
    this.clearOptionPreview();
    const state = taskRuntime.getState();
    const step = state?.step;
    if (!option || !step || getRuntimeSceneId(state.task) !== this.sceneId) return;
    const target = this.anchorObjects.get(step.anchorId);
    if (!target) return;
    const imageKey = getOptionPreviewKey(option);
    this.previewGroup = this.add.container(target.anchor.x + 72, target.anchor.y - 44);
    const halo = this.add.circle(0, 0, 46, 0xffffff, 0.72).setStrokeStyle(3, sceneAccent[this.sceneId] || 0xc75f78, 0.62);
    const image = this.add.image(0, 0, imageKey).setDisplaySize(58, 58).setAlpha(0.96);
    const label = this.add.text(-56, 48, option.label, {
      fontFamily: "Arial, sans-serif",
      fontSize: "14px",
      color: "#4e3d3b",
      backgroundColor: "rgba(255,250,244,0.82)"
    }).setPadding(8, 5, 8, 5);
    this.previewGroup.add([halo, image, label]);
    this.previewGroup.setAlpha(0);
    this.previewGroup.setScale(0.82);
    this.tweens.add({ targets: this.previewGroup, alpha: 1, scale: 1, duration: 160, ease: "Back.Out" });
  }

  clearOptionPreview() {
    if (!this.previewGroup) return;
    this.previewGroup.destroy();
    this.previewGroup = null;
  }

  showPlacedOptions(state) {
    if (this.placedOptionGroup) {
      this.placedOptionGroup.destroy();
      this.placedOptionGroup = null;
    }
    const step = state.step;
    const target = this.anchorObjects.get(step.anchorId);
    if (!target) return;
    if (!state?.selectedIds?.length) return;

    this.placedOptionGroup = this.add.container(target.anchor.x - 82, target.anchor.y + 76);
    const panelWidth = Math.min(step.type === "order" ? 292 : 240, 72 + state.selectedIds.length * 64);
    const panelHeight = step.type === "order" ? 78 : 66;
    const panel = this.add.rectangle(0, 0, panelWidth, panelHeight, 0xffffff, 0.72).setStrokeStyle(2, sceneAccent[this.sceneId] || 0xc75f78, 0.38);
    const label = this.add.text(-panelWidth / 2 + 12, -panelHeight / 2 + 8, step.type === "order" ? "配方步骤" : "已摆放", {
      fontFamily: "Arial, sans-serif",
      fontSize: "13px",
      color: "#5d4b45",
      fontStyle: "bold"
    });
    this.placedOptionGroup.add([panel, label]);

    state.selectedIds.forEach((optionId, index) => {
      const option = step.options.find((item) => item.id === optionId);
      if (!option) return;
      const x = -panelWidth / 2 + 46 + index * 64;
      const image = this.add.image(x, 12, getOptionPreviewKey(option)).setDisplaySize(38, 38);
      this.placedOptionGroup.add(image);
      if (step.type === "order") {
        const badge = this.add.circle(x - 20, -10, 12, sceneAccent[this.sceneId] || 0xc75f78, 0.92);
        const num = this.add.text(x - 25, -19, String(index + 1), { fontFamily: "Arial, sans-serif", fontSize: "14px", color: "#ffffff", fontStyle: "bold" });
        const connector = index > 0 ? this.add.line(x - 54, 12, 0, 0, 24, 0, sceneAccent[this.sceneId] || 0xc75f78, 0.35).setLineWidth(3) : null;
        this.placedOptionGroup.add(connector ? [connector, badge, num] : [badge, num]);
      }
    });
    this.placedOptionGroup.setAlpha(0);
    this.tweens.add({ targets: this.placedOptionGroup, alpha: 1, y: this.placedOptionGroup.y - 6, duration: 180, ease: "Sine.easeOut" });
  }

  showSceneChoiceTray(state) {
    if (this.sceneChoiceTray) {
      this.sceneChoiceTray.destroy();
      this.sceneChoiceTray = null;
    }
    const step = state?.step;
    if (!step?.options?.length) return;
    const selected = new Set(state.selectedIds || []);
    const optionCount = step.options.length;
    const columns = optionCount > 4 ? Math.ceil(optionCount / 2) : optionCount;
    const rows = Math.ceil(optionCount / columns);
    const optionWidth = optionCount > 4 ? 118 : 132;
    const optionHeight = optionCount > 4 ? 42 : 56;
    const optionGap = 10;
    const rowGap = 6;
    const needsConfirm = step.type === "drag" || step.type === "order" || step.type === "match";
    const confirmWidth = needsConfirm ? 68 : 0;
    const trayWidth = Math.min(700, 32 + columns * optionWidth + Math.max(0, columns - 1) * optionGap + confirmWidth);
    const trayHeight = 42 + rows * optionHeight + Math.max(0, rows - 1) * rowGap;
    const trayX = 512;
    const trayY = 640 - trayHeight / 2 - 22;
    const accent = sceneAccent[this.sceneId] || 0xc75f78;
    this.sceneChoiceTray = this.add.container(trayX, trayY).setDepth(14);
    const panel = this.add.rectangle(0, 0, trayWidth, trayHeight, 0xfffbf5, 0.94).setStrokeStyle(2, accent, 0.24);
    const labelText = step.type === "order" && state.selectedIds?.length
      ? `${trayLabel(step.type)} ${state.selectedIds.length}/${step.correctOptionIds.length}`
      : trayLabel(step.type);
    const label = this.add.text(-trayWidth / 2 + 16, -trayHeight / 2 + 8, labelText, {
      fontFamily: "Arial, sans-serif",
      fontSize: "13px",
      color: "#5d4b45",
      fontStyle: "bold"
    });
    this.sceneChoiceTray.add([panel, label]);

    step.options.forEach((option, index) => {
      const col = index % columns;
      const row = Math.floor(index / columns);
      const itemX = -trayWidth / 2 + 16 + optionWidth / 2 + col * (optionWidth + optionGap);
      const itemY = -trayHeight / 2 + 40 + optionHeight / 2 + row * (optionHeight + rowGap);
      const chosen = selected.has(option.id);
      const tile = this.add.rectangle(itemX, itemY, optionWidth - 8, optionHeight, chosen ? 0xffeef3 : 0xffffff, chosen ? 0.96 : 0.9)
        .setStrokeStyle(2, chosen ? accent : 0xe5d8c7, chosen ? 0.76 : 0.5)
        .setInteractive({ useHandCursor: true });
      const iconSize = optionCount > 4 ? 22 : 27;
      const image = this.add.image(itemX - optionWidth / 2 + 25, itemY - 1, getOptionPreviewKey(option)).setDisplaySize(iconSize, iconSize);
      const shortLabel = this.add.text(itemX - optionWidth / 2 + 42, itemY - (optionCount > 4 ? 14 : 16), compactOptionLabel(option.label), {
        fontFamily: "Arial, sans-serif",
        fontSize: optionCount > 4 ? "11px" : "12px",
        color: "#4e3d3b",
        align: "left",
        lineSpacing: 1,
        wordWrap: { width: optionWidth - 54 }
      });
      this.sceneChoiceTray.add([tile, image, shortLabel]);
      if (chosen) {
        const orderIndex = step.type === "order" ? (state.selectedIds || []).indexOf(option.id) + 1 : 0;
        const check = this.add.circle(itemX + optionWidth / 2 - 17, itemY - optionHeight / 2 + 11, 10, accent, 0.94);
        const checkLabel = this.add.text(itemX + optionWidth / 2 - (orderIndex ? 21 : 22), itemY - optionHeight / 2 + 2, orderIndex ? String(orderIndex) : "✓", {
          fontFamily: "Arial, sans-serif",
          fontSize: "13px",
          color: "#ffffff",
          fontStyle: "bold"
        });
        this.sceneChoiceTray.add([check, checkLabel]);
      }
      tile.on("pointerover", () => this.showOptionPreview(option));
      tile.on("pointerout", () => this.showOptionPreview(null));
      tile.on("pointerdown", () => {
        this.showOptionTargetPulse(step.anchorId, option);
      });
      if (step.type === "drag") {
        tile.sceneDragMoved = false;
        this.input.setDraggable(tile);
        tile.on("pointerup", () => {
          if (!tile.sceneDragMoved) eventBus.emit("scene:choose-option", { optionId: option.id });
          this.time.delayedCall(0, () => {
            tile.sceneDragMoved = false;
          });
        });
        tile.on("dragstart", (pointer) => {
          tile.sceneDragMoved = true;
          this.startSceneDragPreview(option, pointer);
        });
        tile.on("drag", (pointer, dragX, dragY) => this.moveSceneDragPreview(pointer));
        tile.on("dragend", (pointer) => this.finishSceneDragPreview(pointer, step, option));
      } else if (step.type === "order") {
        tile.sceneDragMoved = false;
        this.input.setDraggable(tile);
        tile.on("pointerup", () => {
          if (!tile.sceneDragMoved) eventBus.emit("scene:choose-option", { optionId: option.id });
          this.time.delayedCall(0, () => {
            tile.sceneDragMoved = false;
          });
        });
        tile.on("dragstart", (pointer) => {
          tile.sceneDragMoved = true;
          this.startSceneDragPreview(option, pointer);
        });
        tile.on("drag", (pointer, dragX, dragY) => this.moveSceneDragPreview(pointer));
        tile.on("dragend", (pointer) => this.finishSceneDragPreview(pointer, step, option, { autoSubmit: false }));
      } else {
        tile.on("pointerdown", () => eventBus.emit("scene:choose-option", { optionId: option.id }));
      }
    });

    if (needsConfirm) {
      const canSubmit = selected.size > 0;
      const confirm = this.add.rectangle(trayWidth / 2 - 42, rows > 1 ? 16 : 8, 58, rows > 1 ? trayHeight - 50 : optionHeight, 0x426c7b, canSubmit ? 0.88 : 0.3)
        .setStrokeStyle(1, 0xffffff, 0.42)
        .setInteractive({ useHandCursor: canSubmit });
      const confirmText = this.add.text(trayWidth / 2 - 58, rows > 1 ? 7 : -5, step.type === "order" ? "检查" : "放好", {
        fontFamily: "Arial, sans-serif",
        fontSize: "13px",
        color: "#ffffff",
        fontStyle: "bold"
      });
      this.sceneChoiceTray.add([confirm, confirmText]);
      confirm.on("pointerdown", () => {
        if (canSubmit) eventBus.emit("scene:submit-options");
      });
    }

    this.sceneChoiceTray.setAlpha(0);
    this.tweens.add({ targets: this.sceneChoiceTray, alpha: 1, y: this.sceneChoiceTray.y - 4, duration: 160, ease: "Sine.easeOut" });
  }

  showOptionTargetPulse(anchorId, option) {
    const target = this.anchorObjects.get(anchorId)?.anchor;
    if (!target) return;
    const accent = sceneAccent[this.sceneId] || 0xc75f78;
    const imageKey = getOptionPreviewKey(option);
    const ghost = this.add.image(target.x, target.y, imageKey).setDisplaySize(46, 46).setAlpha(0.78).setDepth(13);
    const ring = this.add.ellipse(target.x, target.y, Math.min(target.width + 42, 220), Math.min(target.height + 34, 178), 0xffffff, 0.1)
      .setStrokeStyle(4, accent, 0.58)
      .setDepth(12);
    this.tweens.add({ targets: ghost, scale: 1.18, alpha: 0, duration: 420, ease: "Sine.easeOut", onComplete: () => ghost.destroy() });
    this.tweens.add({ targets: ring, scaleX: 1.08, scaleY: 1.08, alpha: 0, duration: 460, ease: "Sine.easeOut", onComplete: () => ring.destroy() });
  }

  startSceneDragPreview(option, pointer) {
    this.clearOptionPreview();
    if (this.dragPreview) this.dragPreview.destroy();
    this.dragPreview = this.add.container(pointer.x, pointer.y).setDepth(20);
    const halo = this.add.circle(0, 0, 34, 0xffffff, 0.76).setStrokeStyle(3, sceneAccent[this.sceneId] || 0xc75f78, 0.6);
    const image = this.add.image(0, 0, getOptionPreviewKey(option)).setDisplaySize(48, 48);
    this.dragPreview.add([halo, image]);
    this.dragPreview.setScale(0.92);
    this.tweens.add({ targets: this.dragPreview, scale: 1.06, duration: 120, ease: "Sine.easeOut" });
  }

  moveSceneDragPreview(pointer) {
    if (!this.dragPreview) return;
    this.dragPreview.setPosition(pointer.x, pointer.y);
  }

  finishSceneDragPreview(pointer, step, option, config = {}) {
    const target = this.anchorObjects.get(step.anchorId)?.anchor;
    const dropped = target && Phaser.Geom.Rectangle.Contains(
      new Phaser.Geom.Rectangle(target.x - target.width / 2, target.y - target.height / 2, target.width, target.height),
      pointer.x,
      pointer.y
    );
    if (this.dragPreview) {
      const preview = this.dragPreview;
      this.dragPreview = null;
      const endX = dropped ? target.x : pointer.x;
      const endY = dropped ? target.y : pointer.y;
      this.tweens.add({
        targets: preview,
        x: endX,
        y: endY,
        alpha: dropped ? 0.9 : 0,
        scale: dropped ? 0.8 : 0.55,
        duration: 180,
        ease: "Sine.easeOut",
        onComplete: () => preview.destroy()
      });
    }
    if (!dropped) {
      this.showSceneSpeech("拖到亮起的位置", 0x8e4e52);
      return;
    }
    eventBus.emit("scene:choose-option", { optionId: option.id });
    if (config.autoSubmit !== false) this.time.delayedCall(40, () => eventBus.emit("scene:submit-options"));
  }

  showCorrectFeedback(detail) {
    if (detail.task.sceneId !== this.sceneId) return;
    const anchorObject = this.anchorObjects.get(detail.step.anchorId);
    this.pulseAnchor(detail.step.anchorId);
    if (!isVerticalSliceTask(detail.task.id)) {
      this.flyChosenOptionsToAnchor(anchorObject?.anchor, detail.step, detail.optionIds || []);
      this.dropFeedbackItem(anchorObject?.anchor, detail.step);
      this.addCompletedStepArtifact(anchorObject?.anchor, detail.task, detail.step, detail.optionIds || []);
    }
    if (!isVerticalSliceTask(detail.task.id)) {
      this.playStepSceneEffect(detail.task, detail.step, anchorObject?.anchor);
    }
    this.playCharacterReact("correct");
    this.showAnchorSolved(anchorObject?.anchor);
    this.setCharacterLine(detail.completed ? "委托完成啦" : "这一处变好了");
  }

  clearActiveChoiceSurfaces() {
    [
      "targetMarker",
      "placedOptionGroup",
      "taskBubble",
      "routeGuide",
      "ambientGroup",
      "sceneChoiceTray",
      "taskAssetPreview",
      "anchorOptionPicker",
      "hintGuideGroup",
      "sceneIntroCard"
    ].forEach((key) => {
      if (!this[key]) return;
      this[key].destroy();
      this[key] = null;
    });
    this.anchorOptionPickerTaskId = null;
    this.anchorOptionPickerStepId = null;
  }

  showWrongFeedback(detail) {
    if (detail.task.sceneId !== this.sceneId) return;
    const target = this.anchorObjects.get(detail.step.anchorId)?.container;
    const anchor = this.anchorObjects.get(detail.step.anchorId)?.anchor;
    if (target) {
      this.tweens.add({
        targets: target,
        x: target.x + 8,
        duration: 70,
        yoyo: true,
        repeat: 3,
        ease: "Sine.easeInOut"
      });
    }
    if (detail.step?.type === "order") {
      this.recipeBoardWrongUntil = this.time.now + 900;
      const wrongTray = this.sceneChoiceTray;
      if (wrongTray) {
        this.tweens.add({
          targets: wrongTray,
          x: wrongTray.x - 10,
          duration: 70,
          yoyo: true,
          repeat: 4,
          ease: "Sine.easeInOut"
        });
      }
    }
    this.showTryAgainTarget(anchor);
    this.playCharacterReact("wrong");
    this.showSceneSpeech(detail.step?.type === "order" ? "配方槽清空了，重新排" : "再看一次线索", 0x8e4e52);
    this.setCharacterLine(detail.step?.type === "order" ? "从第一步重新排" : "再看一次线索");
  }

  flyChosenOptionsToAnchor(anchor, step, optionIds) {
    if (!anchor || !step || !optionIds.length) return;
    const startY = this.sceneChoiceTray?.y || 520;
    const startX = this.sceneChoiceTray?.x || 360;
    optionIds.forEach((optionId, index) => {
      const option = step.options.find((item) => item.id === optionId);
      if (!option) return;
      const item = this.add.container(startX - 44 + index * 44, startY).setDepth(18);
      const halo = this.add.circle(0, 0, 28, 0xffffff, 0.72).setStrokeStyle(2, sceneAccent[this.sceneId] || 0xc75f78, 0.42);
      const image = this.add.image(0, 0, getOptionPreviewKey(option)).setDisplaySize(42, 42);
      item.add([halo, image]);
      this.tweens.add({
        targets: item,
        x: anchor.x + (index - (optionIds.length - 1) / 2) * 34,
        y: anchor.y + Math.min(anchor.height / 2, 66) - 18,
        scale: 0.82,
        duration: 420 + index * 70,
        ease: "Cubic.easeOut",
        onComplete: () => this.tweens.add({ targets: item, alpha: 0, y: item.y - 10, duration: 220, onComplete: () => item.destroy() })
      });
    });
  }

  showTryAgainTarget(anchor) {
    if (!anchor) return;
    const ring = this.add.ellipse(anchor.x, anchor.y, Math.min(anchor.width + 58, 250), Math.min(anchor.height + 46, 216), 0xffeee8, 0.16)
      .setStrokeStyle(5, 0x8e4e52, 0.58)
      .setDepth(15);
    const copy = this.add.text(anchor.x - 62, anchor.y - Math.min(anchor.height / 2, 82) - 46, "再试一次", {
      fontFamily: "Arial, sans-serif",
      fontSize: "15px",
      color: "#ffffff",
      fontStyle: "bold",
      backgroundColor: "rgba(142,78,82,0.82)"
    }).setPadding(10, 5, 10, 5).setDepth(16);
    this.tweens.add({ targets: ring, scaleX: 1.08, scaleY: 1.08, alpha: 0, duration: 620, ease: "Sine.easeOut", onComplete: () => ring.destroy() });
    this.tweens.add({ targets: copy, alpha: 0, y: copy.y - 18, delay: 520, duration: 260, onComplete: () => copy.destroy() });
  }

  applyCurrentOutfitVisual(outfitId) {
    if (!outfitId || !this.characterOutfitGroup) return;
    this.characterOutfitGroup.removeAll(true);
    this.drawCharacterOutfitLayers(this.characterOutfitGroup, outfitId, false);
    this.characterOutfitGroup.setAlpha(0);
    this.characterOutfitGroup.setScale(characterDisplay.outfitScale * 0.88);
    this.tweens.add({ targets: this.characterOutfitGroup, alpha: 1, scale: characterDisplay.outfitScale, duration: 260, ease: "Back.Out" });
  }

  playCharacterReact(type) {
    if (!this.characterSprite) return;
    this.showCharacterEmote(type);
    if (type === "wrong") {
      this.tweens.add({ targets: this.characterSprite, angle: -5, x: this.characterSprite.x - 6, duration: 70, yoyo: true, repeat: 4, ease: "Sine.easeInOut" });
      return;
    }
    if (type === "complete") {
      this.tweens.add({ targets: this.characterSprite, scaleX: 1.13, scaleY: 1.13, y: this.characterSprite.y - 22, duration: 180, yoyo: true, repeat: 1, ease: "Back.Out" });
      this.emitCharacterCelebration();
      return;
    }
    this.tweens.add({ targets: this.characterSprite, y: this.characterSprite.y - 20, scaleX: 1.05, scaleY: 1.05, duration: 140, yoyo: true, ease: "Sine.easeOut" });
  }

  showCharacterEmote(type) {
    if (!this.characterSprite) return;
    if (this.emoteBubble) {
      this.emoteBubble.destroy();
      this.emoteBubble = null;
    }
    const config = {
      idle: { text: "?", color: 0xffffff, alpha: 0.72 },
      correct: { text: "✓", color: 0xe9f7ed, alpha: 0.96 },
      wrong: { text: "!", color: 0xffeee8, alpha: 0.96 },
      complete: { text: "★", color: 0xfff4dc, alpha: 0.98 }
    }[type] || { text: "✓", color: 0xffffff, alpha: 0.88 };
    const x = this.characterSprite.x + 64;
    const y = this.characterSprite.y - 128;
    this.emoteBubble = this.add.container(x, y).setDepth(18);
    const bubble = this.add.circle(0, 0, 22, config.color, config.alpha).setStrokeStyle(2, sceneAccent[this.sceneId] || 0xc75f78, 0.36);
    const text = this.add.text(-7, -14, config.text, {
      fontFamily: "Arial, sans-serif",
      fontSize: "24px",
      color: type === "wrong" ? "#8e4e52" : "#426c7b",
      fontStyle: "bold"
    });
    this.emoteBubble.add([bubble, text]);
    this.emoteBubble.setAlpha(0);
    this.emoteBubble.setScale(0.7);
    this.tweens.add({ targets: this.emoteBubble, alpha: 1, scale: 1, y: y - 10, duration: 180, ease: "Back.Out" });
    if (type !== "idle") {
      this.time.delayedCall(type === "complete" ? 1600 : 950, () => {
        if (!this.emoteBubble) return;
        const target = this.emoteBubble;
        this.emoteBubble = null;
        this.tweens.add({ targets: target, alpha: 0, y: target.y - 12, duration: 220, onComplete: () => target.destroy() });
      });
    }
  }

  emitCharacterCelebration() {
    if (!this.characterSprite) return;
    const colors = [0xffd3df, 0xfff4dc, 0xd5e9ec, 0xe9f7ed];
    for (let i = 0; i < 12; i += 1) {
      const angle = (Math.PI * 2 * i) / 12;
      const confetti = this.add.rectangle(this.characterSprite.x, this.characterSprite.y - 110, 8, 12, colors[i % colors.length], 0.9).setDepth(17);
      this.tweens.add({
        targets: confetti,
        x: confetti.x + Math.cos(angle) * (48 + (i % 3) * 18),
        y: confetti.y + Math.sin(angle) * 44 - 18,
        angle: 180 + i * 30,
        alpha: 0,
        duration: 760,
        ease: "Cubic.easeOut",
        onComplete: () => confetti.destroy()
      });
    }
  }

  pulseAnchor(anchorId, persistent = false) {
    const target = this.anchorObjects.get(anchorId);
    if (!target) return;
    target.glow.setStrokeStyle(4, sceneAccent[this.sceneId] || 0xc75f78, persistent ? 0.78 : 0.94);
    target.glow.setAlpha(persistent ? 0.12 : 0.22);
    this.tweens.add({
      targets: target.container,
      scaleX: persistent ? 1.02 : 1.06,
      scaleY: persistent ? 1.02 : 1.06,
      duration: 160,
      yoyo: true,
      ease: "Sine.easeOut"
    });
    if (!persistent) {
      this.tweens.add({ targets: target.glow, alpha: 0.02, duration: 620, ease: "Sine.easeOut" });
    }
  }

  dropFeedbackItem(anchor, step) {
    if (!anchor) return;
    const imageKey = anchorImages[anchor.id] || "icon-star";
    const item = this.add.image(86, 540, imageKey).setDisplaySize(52, 52).setAlpha(0.95);
    this.feedbackItems.push(item);
    this.tweens.add({
      targets: item,
      x: anchor.x,
      y: anchor.y,
      scale: 1.25,
      duration: 520,
      ease: "Cubic.easeOut",
      onComplete: () => {
        this.tweens.add({ targets: item, alpha: 0, scale: 0.7, duration: 260, onComplete: () => item.destroy() });
      }
    });
    const sparkle = this.add.text(anchor.x + 30, anchor.y - 46, "完成", {
      fontFamily: "Arial, sans-serif",
      fontSize: "20px",
      color: "#ffffff",
      fontStyle: "bold",
      backgroundColor: "rgba(66,108,123,0.78)"
    }).setPadding(10, 6, 10, 6).setAlpha(0);
    this.tweens.add({ targets: sparkle, alpha: 1, y: sparkle.y - 18, duration: 180, yoyo: true, hold: 460, onComplete: () => sparkle.destroy() });
  }

  showAnchorSolved(anchor) {
    if (!anchor) return;
    const ring = this.add.circle(anchor.x, anchor.y, 12, 0xffffff, 0).setStrokeStyle(5, sceneAccent[this.sceneId] || 0xc75f78, 0.78);
    this.tweens.add({
      targets: ring,
      radius: Math.max(anchor.width, anchor.height) * 0.58,
      alpha: 0,
      duration: 520,
      ease: "Sine.easeOut",
      onComplete: () => ring.destroy()
    });
  }

  addCompletedStepArtifact(anchor, task, step, optionIds) {
    if (!anchor) return;
    if (!this.completedStepGroup) {
      this.completedStepGroup = this.add.container(0, 0);
    }
    if (step.type === "order") {
      this.addCompletedOrderArtifact(anchor, task.id, step.id, optionIds.length || step.correctOptionIds.length);
      return;
    }
    const option = step.options.find((item) => optionIds.includes(item.id)) || step.options[0];
    const index = this.completedStepGroup.length || 0;
    const x = anchor.x + 38 + (index % 2) * 48;
    const y = anchor.y + Math.min(anchor.height / 2, 68) - 12 + Math.floor(index / 2) * 40;
    const token = this.add.container(x, y);
    const plate = this.add.rectangle(0, 0, 88, 34, 0xfffbf5, 0.86).setStrokeStyle(2, sceneAccent[this.sceneId] || 0xc75f78, 0.32);
    const icon = this.add.image(-28, 0, getOptionPreviewKey(option)).setDisplaySize(26, 26);
    const text = this.add.text(-8, -9, completedArtifactLabel(step), {
      fontFamily: "Arial, sans-serif",
      fontSize: "13px",
      color: "#4e3d3b",
      fontStyle: "bold"
    });
    token.add([plate, icon, text]);
    token.setAlpha(0);
    token.setScale(0.86);
    this.completedStepGroup.add(token);
    this.tweens.add({ targets: token, alpha: 1, scale: 1, duration: 180, ease: "Back.Out" });
    this.addStepWorldDecor(anchor, task.id, step.id);
  }

  addCompletedOrderArtifact(anchor, taskId, stepId, count) {
    const index = this.completedStepGroup.length || 0;
    const width = Math.max(126, count * 42 + 26);
    const token = this.add.container(anchor.x - 10, anchor.y + Math.min(anchor.height / 2, 74) - 8 + index * 18);
    const plate = this.add.rectangle(0, 0, width, 38, 0xfffbf5, 0.86).setStrokeStyle(2, sceneAccent[this.sceneId] || 0x4f9d7a, 0.32);
    const label = this.add.text(-width / 2 + 10, -10, "步骤", {
      fontFamily: "Arial, sans-serif",
      fontSize: "13px",
      color: "#4e3d3b",
      fontStyle: "bold"
    });
    token.add([plate, label]);
    for (let i = 0; i < count; i += 1) {
      const x = -width / 2 + 54 + i * 38;
      const dot = this.add.circle(x, 0, 13, sceneAccent[this.sceneId] || 0x4f9d7a, 0.86);
      const num = this.add.text(x - 4, -9, String(i + 1), {
        fontFamily: "Arial, sans-serif",
        fontSize: "14px",
        color: "#ffffff",
        fontStyle: "bold"
      });
      token.add([dot, num]);
    }
    token.setAlpha(0);
    token.setScale(0.88);
    this.completedStepGroup.add(token);
    this.tweens.add({ targets: token, alpha: 1, scale: 1, duration: 180, ease: "Back.Out" });
    this.addStepWorldDecor(anchor, taskId, stepId);
  }

  addStepWorldDecor(anchor, taskId, stepId) {
    const config = stepWorldDecorByStepId[taskId]?.[stepId];
    if (!anchor || !config) return;
    const groupName = config.keep ? "worldChangeGroup" : "transientWorldGroup";
    if (!this[groupName]) this[groupName] = this.add.container(0, 0);
    const token = this.add.container(anchor.x + config.dx, anchor.y + config.dy);
    const glow = this.add.circle(0, 0, 30, 0xffffff, 0.42).setStrokeStyle(2, sceneAccent[this.sceneId] || 0xc75f78, 0.38);
    const image = this.add.image(0, -4, config.image).setDisplaySize(42, 42).setAlpha(0.96);
    const label = this.add.text(-44, 30, config.label, decorTextStyle()).setPadding(7, 4, 7, 4);
    token.add([glow, image, label]);
    token.setAlpha(0);
    token.setScale(0.74);
    this[groupName].add(token);
    this.tweens.add({ targets: token, alpha: 1, scale: 1, duration: 220, ease: "Back.Out" });
    if (taskId.startsWith("task_study_")) {
      this.tweens.add({ targets: glow, alpha: 0.62, duration: 960, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    } else {
      this.tweens.add({ targets: image, y: image.y - 5, duration: 960, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    }
    if (!config.keep) {
      this.time.delayedCall(1150, () => {
        if (!token.active) return;
        this.tweens.add({ targets: token, alpha: 0, scale: 0.82, duration: 260, onComplete: () => token.destroy() });
      });
    } else {
      this.time.delayedCall(520, () => {
        if (!label.active) return;
        this.tweens.add({ targets: [label, glow], alpha: 0, duration: 260 });
      });
    }
  }

  addSceneRewardDecor(taskId) {
    const storyReward = getEnglishStoryRewardPreview(taskId);
    const profile = sceneVisualProfiles[this.sceneId];
    if (storyReward && profile?.rewardSlots?.length) {
      this.addProfileRewardDecor(storyReward, profile);
      return;
    }
    if (taskId === "task_wardrobe_002") {
      this.popInWorldChange(this.drawWardrobeOrganizedDecor());
      return;
    }
    if (taskId === "task_study_001") {
      this.popInWorldChange(this.drawStudyAlbumDecor());
      return;
    }
    if (taskId === "task_study_002") {
      this.popInWorldChange(this.drawStudyCardDecor());
      return;
    }
    const config = sceneRewardDecorByTaskId[taskId];
    if (!config) return;
    if (!this.worldChangeGroup) this.worldChangeGroup = this.add.container(0, 0);
    const token = this.add.container(config.x, config.y);
    const plate = this.add.rectangle(0, 30, Math.max(98, config.label.length * 18), 28, 0xfffbf5, 0.78).setStrokeStyle(1, sceneAccent[this.sceneId] || 0xc75f78, 0.28);
    const image = this.add.image(0, -8, config.image).setDisplaySize(config.w, config.h).setAlpha(0.98);
    const label = this.add.text(-Math.max(42, config.label.length * 7), 20, config.label, {
      fontFamily: "Arial, sans-serif",
      fontSize: "14px",
      color: "#4e3d3b",
      fontStyle: "bold"
    });
    token.add([plate, image, label]);
    token.setAlpha(0);
    token.setScale(0.72);
    this.worldChangeGroup.add(token);
    this.tweens.add({ targets: token, alpha: 1, scale: 1, duration: 260, ease: "Back.Out" });
    if (this.sceneId === "scene_study") {
      this.tweens.add({ targets: image, alpha: 0.86, duration: 980, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    } else {
      this.floatDecor(image, 5, 1200);
    }
    this.time.delayedCall(620, () => {
      if (!label.active) return;
      this.tweens.add({ targets: [plate, label], alpha: 0, duration: 280 });
    });
  }

  addProfileRewardDecor(preview, profile) {
    const progress = loadProgress();
    const completedInScene = englishStoryContentRows
      .filter((row) => row.sceneId === this.sceneId && progress.completedTaskIds?.includes(row.taskId))
      .length;
    const slot = profile.rewardSlots[Math.min(profile.rewardSlots.length - 1, Math.max(0, completedInScene - 1))] || profile.rewardSlots[0];
    const accent = sceneAccent[this.sceneId] || 0xc75f78;
    if (!this.worldChangeGroup) this.worldChangeGroup = this.add.container(0, 0).setDepth(18);
    const token = this.add.container(512, 104).setDepth(18);
    const halo = this.add.circle(0, 0, 38, 0xffffff, 0.76).setStrokeStyle(3, accent, 0.56);
    const image = this.add.image(0, 0, preview.image).setDisplaySize(60, 60).setAlpha(0.98);
    const label = this.add.text(-68, 46, preview.label, decorTextStyle()).setPadding(8, 5, 8, 5);
    token.add([halo, image, label]);
    token.setAlpha(0);
    token.setScale(0.72);
    this.worldChangeGroup.add(token);
    this.tweens.add({
      targets: token,
      alpha: 1,
      scale: 0.82,
      x: slot[0],
      y: slot[1],
      duration: 620,
      ease: "Cubic.easeOut",
      onComplete: () => {
        if (this.sceneId === "scene_study") {
          this.tweens.add({ targets: halo, alpha: 0.44, duration: 980, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
        } else {
          this.floatDecor(image, 3, 1100);
        }
        this.time.delayedCall(720, () => {
          if (!label.active) return;
          this.tweens.add({ targets: [label, halo], alpha: 0, duration: 260 });
        });
      }
    });
  }

  playStepSceneEffect(task, step, anchor) {
    if (!anchor) return;
    if (task.sceneId === "scene_wardrobe") {
      this.playWardrobeEffect(task, step, anchor);
      return;
    }
    if (task.sceneId === "scene_kitchen") {
      this.playKitchenEffect(task, step, anchor);
      return;
    }
    if (task.sceneId === "scene_study") {
      this.playStudyEffect(task, step, anchor);
    }
  }

  playWardrobeEffect(task, step, anchor) {
    if (step.anchorId === "anchor_wardrobe_mirror") {
      const glow = this.add.ellipse(anchor.x, anchor.y, 148, 186, 0xffffff, 0.18).setStrokeStyle(4, sceneAccent[this.sceneId] || 0xd86a8b, 0.52);
      this.tweens.add({ targets: glow, scaleX: 1.18, scaleY: 1.12, alpha: 0, duration: 760, ease: "Sine.easeOut", onComplete: () => glow.destroy() });
      this.showSceneSpeech("镜子里的搭配亮起来了", sceneAccent[this.sceneId] || 0xd86a8b);
      return;
    }
    const ribbon = this.add.container(anchor.x + 22, anchor.y - 84);
    const left = this.add.circle(-16, 0, 16, 0xffd3df, 0.9).setScale(1.35, 0.82);
    const right = this.add.circle(16, 0, 16, 0xffd3df, 0.9).setScale(1.35, 0.82);
    const knot = this.add.circle(0, 0, 10, sceneAccent[this.sceneId] || 0xd86a8b, 0.95);
    ribbon.add([left, right, knot]);
    ribbon.setAlpha(0);
    ribbon.setScale(0.7);
    this.tweens.add({ targets: ribbon, alpha: 1, scale: 1, y: ribbon.y - 10, duration: 220, ease: "Back.Out" });
    this.time.delayedCall(1100, () => this.tweens.add({ targets: ribbon, alpha: 0, duration: 260, onComplete: () => ribbon.destroy() }));
  }

  playKitchenEffect(task, step, anchor) {
    const group = this.add.container(anchor.x, anchor.y - 28);
    for (let i = 0; i < 4; i += 1) {
      const steam = this.add.circle(-24 + i * 16, 0, 8, 0xffffff, 0.52);
      group.add(steam);
      this.tweens.add({
        targets: steam,
        y: steam.y - 52,
        alpha: 0,
        scaleX: 1.8,
        scaleY: 1.8,
        duration: 900 + i * 90,
        ease: "Sine.easeOut"
      });
    }
    const label = task.id === "task_kitchen_002" ? "刚刚好" : "香味出来了";
    const tag = this.add.text(anchor.x - 42, anchor.y - 96, label, {
      fontFamily: "Arial, sans-serif",
      fontSize: "17px",
      color: "#ffffff",
      fontStyle: "bold",
      backgroundColor: "rgba(79,157,122,0.78)"
    }).setPadding(10, 6, 10, 6).setAlpha(0);
    this.tweens.add({ targets: tag, alpha: 1, y: tag.y - 12, duration: 180, yoyo: true, hold: 620, onComplete: () => tag.destroy() });
    this.time.delayedCall(1100, () => group.destroy());
  }

  playStudyEffect(task, step, anchor) {
    let destination = null;
    if (task.id === "task_study_001") {
      destination = step.anchorId === "anchor_study_mailbox" ? this.anchorObjects.get("anchor_study_map")?.anchor : this.anchorObjects.get("anchor_study_bookshelf")?.anchor;
    } else {
      destination = step.anchorId === "anchor_study_bookshelf" ? this.anchorObjects.get("anchor_study_map")?.anchor : this.anchorObjects.get("anchor_study_mailbox")?.anchor;
    }
    if (destination) {
      const cardImage = task.id === "task_study_002" ? "item-cat-card" : "anchor-mailbox";
      const card = this.add.image(anchor.x, anchor.y, cardImage).setDisplaySize(34, 34).setAlpha(0.95);
      this.drawStudyRouteTrail(anchor, destination, task.id === "task_study_001" ? "送信路线" : "卡片路线");
      this.tweens.add({
        targets: card,
        x: destination.x,
        y: destination.y,
        scale: 1.18,
        duration: 620,
        ease: "Cubic.easeOut",
        onComplete: () => this.tweens.add({ targets: card, alpha: 0, scale: 0.72, duration: 240, onComplete: () => card.destroy() })
      });
    }
    if (task.id === "task_study_001") this.showLetterClueBoard(task, step, anchor, destination);
    if (task.id === "task_study_002") this.showCardMatchBoard(task, step, anchor, destination);
    const text = task.id === "task_study_001" ? "信件路线连上了" : "卡片贴回去了";
    this.showSceneSpeech(text, sceneAccent[this.sceneId] || 0x5f83c4);
  }

  drawStudyRouteTrail(from, to, label) {
    if (!from || !to) return;
    if (this.studyTrailGroup) {
      this.studyTrailGroup.destroy();
      this.studyTrailGroup = null;
    }
    const accent = sceneAccent[this.sceneId] || 0x5f83c4;
    this.studyTrailGroup = this.add.container(0, 0).setDepth(15);
    const steps = 7;
    for (let i = 1; i <= steps; i += 1) {
      const t = i / (steps + 1);
      const x = Phaser.Math.Linear(from.x, to.x, t);
      const y = Phaser.Math.Linear(from.y, to.y, t) - Math.sin(t * Math.PI) * 34;
      const dot = this.add.circle(x, y, i % 2 ? 5 : 4, i % 2 ? accent : 0xffffff, i % 2 ? 0.62 : 0.72)
        .setStrokeStyle(1, accent, 0.28);
      this.studyTrailGroup.add(dot);
      this.tweens.add({ targets: dot, alpha: 1, scaleX: 1.35, scaleY: 1.35, delay: i * 45, duration: 280, yoyo: true, ease: "Sine.easeOut" });
    }
    const tagX = Phaser.Math.Linear(from.x, to.x, 0.48);
    const tagY = Phaser.Math.Linear(from.y, to.y, 0.48) - 54;
    const tag = this.add.text(tagX - 42, tagY - 12, label, {
      fontFamily: "Arial, sans-serif",
      fontSize: "14px",
      color: "#ffffff",
      fontStyle: "bold",
      backgroundColor: "rgba(95,131,196,0.78)"
    }).setPadding(9, 5, 9, 5);
    this.studyTrailGroup.add(tag);
    this.studyTrailGroup.isStudyRouteTrail = true;
    this.time.delayedCall(1350, () => {
      if (!this.studyTrailGroup) return;
      const group = this.studyTrailGroup;
      this.studyTrailGroup = null;
      this.tweens.add({ targets: group, alpha: 0, duration: 260, onComplete: () => group.destroy() });
    });
  }

  showLetterClueBoard(task, step, anchor, destination) {
    if (!anchor) return;
    const accent = sceneAccent[this.sceneId] || 0x5f83c4;
    const board = this.add.container(anchor.x + 76, anchor.y - 74).setDepth(16);
    board.isStudyLetterBoard = true;
    const panel = this.add.rectangle(0, 0, 164, 58, 0xfffbf5, 0.9).setStrokeStyle(2, accent, 0.36);
    const mail = this.add.image(-58, -2, "anchor-mailbox").setDisplaySize(28, 28).setAlpha(0.9);
    const copy = this.add.text(-36, -20, step.anchorId === "anchor_study_mailbox" ? "收信人：米娜" : "地点：书架旁", {
      fontFamily: "Arial, sans-serif",
      fontSize: "14px",
      color: "#3e332f",
      fontStyle: "bold",
      wordWrap: { width: 116 }
    });
    board.add([panel, mail, copy]);
    if (destination) {
      const pin = this.add.circle(destination.x, destination.y - 48, 14, 0xfff4dc, 0.9).setStrokeStyle(3, accent, 0.52).setDepth(16);
      pin.isStudyLetterPin = true;
      this.tweens.add({ targets: pin, y: pin.y - 8, duration: 520, yoyo: true, repeat: 1, ease: "Sine.easeInOut", onComplete: () => this.tweens.add({ targets: pin, alpha: 0, duration: 220, onComplete: () => pin.destroy() }) });
    }
    board.setAlpha(0);
    board.setScale(0.86);
    this.tweens.add({ targets: board, alpha: 1, scale: 1, duration: 180, ease: "Back.Out" });
    this.time.delayedCall(1300, () => this.tweens.add({ targets: board, alpha: 0, y: board.y - 14, duration: 240, onComplete: () => board.destroy() }));
  }

  showCardMatchBoard(task, step, anchor, destination) {
    if (!anchor) return;
    const accent = sceneAccent[this.sceneId] || 0x5f83c4;
    const board = this.add.container(anchor.x + 84, anchor.y - 64).setDepth(16);
    board.isStudyCardBoard = true;
    const panel = this.add.rectangle(0, 0, 178, 64, 0xfffbf5, 0.9).setStrokeStyle(2, accent, 0.36);
    const title = this.add.text(-76, -24, step.type === "match" ? "卡片配对" : "旁边位置", {
      fontFamily: "Arial, sans-serif",
      fontSize: "14px",
      color: "#3e332f",
      fontStyle: "bold"
    });
    const left = this.add.image(-44, 10, "item-book").setDisplaySize(28, 30).setAlpha(0.92);
    const right = this.add.image(2, 10, "item-cat-card").setDisplaySize(28, 32).setAlpha(0.92);
    const mail = this.add.image(50, 10, step.anchorId === "anchor_study_map" ? "anchor-mailbox" : "item-apple-card").setDisplaySize(30, 30).setAlpha(0.88);
    board.add([panel, title, left, right, mail]);
    if (destination) {
      const line = this.add.line(0, 0, anchor.x, anchor.y, destination.x, destination.y, accent, 0.32).setLineWidth(4).setDepth(14);
      line.isStudyCardRoute = true;
      this.tweens.add({ targets: line, alpha: 0, delay: 950, duration: 260, onComplete: () => line.destroy() });
    }
    board.setAlpha(0);
    board.setScale(0.86);
    this.tweens.add({ targets: board, alpha: 1, scale: 1, duration: 180, ease: "Back.Out" });
    this.time.delayedCall(1300, () => this.tweens.add({ targets: board, alpha: 0, y: board.y - 14, duration: 240, onComplete: () => board.destroy() }));
  }

  clearCompletedStepArtifacts() {
    if (!this.completedStepGroup) return;
    this.completedStepGroup.destroy();
    this.completedStepGroup = null;
  }

  clearActiveTaskGuides() {
    this.clearOptionPreview();
    this.clearCompletedStepArtifacts();
    if (this.transientWorldGroup) {
      this.transientWorldGroup.destroy();
      this.transientWorldGroup = null;
    }
    [
      "targetMarker",
      "placedOptionGroup",
      "taskBubble",
      "routeGuide",
      "ambientGroup",
      "sceneChoiceTray",
      "taskAssetPreview",
      "anchorOptionPicker",
      "hintGuideGroup",
      "sceneIntroCard",
      "studyTrailGroup"
    ].forEach((key) => {
      if (!this[key]) return;
      this[key].destroy();
      this[key] = null;
    });
    this.anchorOptionPickerTaskId = null;
    this.anchorOptionPickerStepId = null;
    this.anchorObjects.forEach(({ glow }) => {
      glow.setAlpha(0.01);
      glow.setStrokeStyle(4, sceneAccent[this.sceneId] || 0xc75f78, 0);
    });
    this.anchorObjects.forEach(({ actionText, labelPanel, nameText }) => {
      actionText?.setAlpha(0);
      labelPanel?.setAlpha(0);
      nameText?.setAlpha(0);
    });
    this.anchorObjects.forEach(({ container }) => {
      this.tweens.add({ targets: container, alpha: 0.42, duration: 240, ease: "Sine.easeOut" });
    });
  }

  showSceneSpeech(text, color) {
    this.lastSceneSpeechText = text;
    const bubble = this.add.container(742, 254);
    this.sceneSpeech = bubble;
    const panel = this.add.rectangle(0, 0, 232, 52, 0xffffff, 0.88).setStrokeStyle(2, color, 0.42);
    const copy = this.add.text(-96, -13, text, {
      fontFamily: "Arial, sans-serif",
      fontSize: "16px",
      color: "#3e332f",
      fontStyle: "bold"
    });
    bubble.add([panel, copy]);
    bubble.setAlpha(0);
    bubble.setScale(0.92);
    this.tweens.add({ targets: bubble, alpha: 1, scale: 1, duration: 160, ease: "Back.Out" });
    this.time.delayedCall(1050, () => {
      this.tweens.add({
        targets: bubble,
        alpha: 0,
        y: bubble.y - 18,
        duration: 220,
        onComplete: () => {
          if (this.sceneSpeech === bubble) this.sceneSpeech = null;
          bubble.destroy();
        }
      });
    });
  }

  showRoomMood(text, color) {
    if (this.roomMoodGroup) {
      this.roomMoodGroup.destroy();
      this.roomMoodGroup = null;
    }
    this.roomMoodGroup = this.add.container(512, 606).setDepth(17);
    const panel = this.add.rectangle(0, 0, 286, 38, 0xffffff, 0.78).setStrokeStyle(2, color, 0.28);
    const icon = this.add.image(-122, 0, "icon-star").setDisplaySize(22, 22).setAlpha(0.78);
    const copy = this.add.text(-98, -10, text, {
      fontFamily: "Arial, sans-serif",
      fontSize: "14px",
      color: "#4e3d3b",
      fontStyle: "bold"
    });
    this.roomMoodGroup.add([panel, icon, copy]);
    this.roomMoodGroup.setAlpha(0);
    this.roomMoodGroup.setScale(0.92);
    this.tweens.add({ targets: this.roomMoodGroup, alpha: 1, scale: 1, y: 596, duration: 160, ease: "Sine.easeOut" });
    this.time.delayedCall(1050, () => {
      if (!this.roomMoodGroup) return;
      const group = this.roomMoodGroup;
      this.roomMoodGroup = null;
      this.tweens.add({ targets: group, alpha: 0, y: group.y - 10, duration: 220, onComplete: () => group.destroy() });
    });
  }

  emitTinySparkles(x, y, color, count = 6) {
    for (let i = 0; i < count; i += 1) {
      const angle = (Math.PI * 2 * i) / count;
      const sparkle = this.add.image(x, y, "icon-star").setDisplaySize(16, 16).setTint(color).setAlpha(0.82).setDepth(18);
      this.tweens.add({
        targets: sparkle,
        x: x + Math.cos(angle) * (32 + (i % 2) * 14),
        y: y + Math.sin(angle) * 24 - 12,
        angle: 160,
        alpha: 0,
        scale: 0.58,
        duration: 520,
        ease: "Cubic.easeOut",
        onComplete: () => sparkle.destroy()
      });
    }
  }

  setCharacterLine(text) {
    if (!this.characterLabel) return;
    this.characterLabel.setText(text);
    this.tweens.add({ targets: this.characterLabel, scale: 1.08, duration: 120, yoyo: true });
  }

  getAnchorName(anchorId) {
    return this.sceneConfig.anchors.find((anchor) => anchor.id === anchorId)?.name || "亮起的位置";
  }
}

class TownScene extends Phaser.Scene {
  constructor() {
    super("TownScene");
    this.townSpeech = null;
    this.townCharacter = null;
    this.townCharacterOutfitGroup = null;
    this.townCharacterShadow = null;
    this.townCharacterMoveTween = null;
    this.townDestinationMarker = null;
    this.townKeyboardTarget = null;
    this.activeTownGlow = null;
    this.townPathMarkerCount = 0;
    this.townInteractions = new Map();
    this.townEventUnsubs = [];
  }

  create() {
    this.townSpeech = null;
    this.townCharacter = null;
    this.townCharacterOutfitGroup = null;
    this.townCharacterShadow = null;
    this.townCharacterMoveTween = null;
    this.townDestinationMarker = null;
    this.townKeyboardTarget = null;
    this.activeTownGlow = null;
    this.townPathMarkerCount = 0;
    this.townInteractions = new Map();
    this.townEventUnsubs.forEach((unsubscribe) => unsubscribe());
    this.townEventUnsubs = [];
    this.cameras.main.setBackgroundColor(0xf7e4bc);
    this.drawTownGroundMap();
    const ground = this.add.zone(512, 352, 1024, 516).setOrigin(0.5).setInteractive({ useHandCursor: true }).setDepth(0.2);
    ground.on("pointerdown", (pointer) => this.handleTownGroundClick(pointer));
    const progress = loadProgress();
    const activeTask = taskRuntime.getCurrentTask(progress);
    const activeRoute = getTownRoute(activeTask);
    window.__studyGameTownState = {
      activeTaskId: activeTask?.id || null,
      targetPointId: activeTask ? activeRoute.startPointId : null,
      mapMode: "topdown-town-map",
      cards: {},
      allDone: !activeTask
    };
    this.drawTownProgressDecorations(progress, activeTask);
    this.drawTownLandmarks(progress, activeTask);
    this.drawCharacter(842, 512, activeTask);
    this.bindTownInput(activeTask);
    this.bindTownRuntimeFeedback();
    eventBus.emit("scene:changed", { sceneId: "scene_town" });
    logTelemetry({ type: "scene_entered", sceneId: "scene_town" });
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.shutdown());
  }

  drawTownGroundMap() {
    if (this.textures.exists("scene-town")) {
      this.add.image(512, 320, "scene-town").setDisplaySize(1024, 640).setDepth(-5);
      this.add.rectangle(512, 320, 1024, 640, 0xfff7fb, 0.08).setDepth(-4.8);
      this.add.rectangle(512, 320, 1024, 640, 0xffffff, 0.06).setDepth(-4.7);
      return;
    }

    this.add.rectangle(512, 320, 1024, 640, 0xfbe6f0, 1).setDepth(-5);
    this.add.rectangle(512, 94, 1024, 188, 0xcfeefe, 0.34).setDepth(-4);
    this.add.rectangle(512, 598, 1024, 108, 0xbfe7d5, 0.26).setDepth(-4);
    const roadColor = 0xffe6c9;
    const roadEdge = 0xe2b98d;
    const road = this.add.graphics().setDepth(-1);
    road.lineStyle(50, roadColor, 1);
    road.beginPath();
    road.moveTo(904, 514);
    road.lineTo(752, 500);
    road.lineTo(646, 524);
    road.lineTo(504, 496);
    road.lineTo(348, 464);
    road.lineTo(246, 452);
    road.strokePath();
    road.lineStyle(24, 0xfff6e2, 0.9);
    road.beginPath();
    road.moveTo(904, 514);
    road.lineTo(752, 500);
    road.lineTo(646, 524);
    road.lineTo(504, 496);
    road.lineTo(348, 464);
    road.lineTo(246, 452);
    road.strokePath();

    const roadTrim = this.add.graphics().setDepth(-0.8);
    roadTrim.lineStyle(4, roadEdge, 0.38);
    [[904, 514, 752, 500], [752, 500, 646, 524], [646, 524, 504, 496], [504, 496, 348, 464], [348, 464, 246, 452]].forEach(([x1, y1, x2, y2]) => {
      roadTrim.strokeLineShape(new Phaser.Geom.Line(x1, y1 - 28, x2, y2 - 28));
      roadTrim.strokeLineShape(new Phaser.Geom.Line(x1, y1 + 28, x2, y2 + 28));
    });

    const plaza = this.add.graphics().setDepth(-0.6);
    plaza.fillStyle(0xfff0d6, 0.96);
    plaza.fillEllipse(246, 452, 188, 82);
    plaza.fillEllipse(504, 496, 184, 76);
    plaza.fillEllipse(752, 500, 190, 84);
    plaza.fillStyle(0xf3cfa5, 0.22);
    plaza.lineStyle(3, roadEdge, 0.4);
    plaza.strokeEllipse(246, 452, 188, 82);
    plaza.strokeEllipse(504, 496, 184, 76);
    plaza.strokeEllipse(752, 500, 190, 84);

    this.add.text(892, 516, "镇口", decorTextStyle()).setPadding(10, 5, 10, 5).setDepth(1);
  }

  shutdown() {
    this.townEventUnsubs.forEach((unsubscribe) => unsubscribe());
    this.townEventUnsubs = [];
  }

  drawTownProgressDecorations(progress, activeTask) {
    this.drawTownProgressBadge(progress, activeTask);
  }

  drawTownLandmarks(progress, activeTask) {
    const completedCount = getVerticalSliceCompletedCount(progress);
    if (completedCount > 0) {
      const welcomeLight = this.add.container(320, 486).setDepth(2);
      welcomeLight.add([
        this.add.circle(0, 0, 28, 0xffcf5a, 0.26).setStrokeStyle(2, 0xffffff, 0.54),
        this.add.image(0, 0, "icon-star").setDisplaySize(30, 30).setTint(0xffcf5a)
      ]);
      this.tweens.add({ targets: welcomeLight.list[0], alpha: 0.62, scaleX: 1.12, scaleY: 1.12, duration: 900, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    }

    if (completedCount > 1) {
      const bellGlow = this.add.container(318, 330).setDepth(2);
      bellGlow.add([
        this.add.ellipse(0, 0, 92, 30, 0xffcf5a, 0.16).setStrokeStyle(2, 0xd9ae5f, 0.42),
        this.add.image(0, -8, "icon-star").setDisplaySize(24, 24).setTint(0xffcf5a)
      ]);
      this.tweens.add({ targets: bellGlow.list[0], alpha: 0.42, scaleX: 1.1, duration: 840, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    }

    if (completedCount > 2) {
      const skyGlow = this.add.container(782, 250).setDepth(2);
      skyGlow.add([
        this.add.circle(0, 0, 34, 0x7abfad, 0.18).setStrokeStyle(2, 0xffffff, 0.64),
        this.add.image(0, 0, "icon-star").setDisplaySize(30, 30).setTint(0x7abfad)
      ]);
      this.tweens.add({ targets: skyGlow.list[0], alpha: 0.5, scaleX: 1.18, scaleY: 1.18, duration: 900, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    }

    townInteractionPoints.forEach((point) => this.drawTownInteractionPoint(point, activeTask, progress));
  }

  drawTownInteractionPoint(point, activeTask, progress) {
    const completedCount = getVerticalSliceCompletedCount(progress);
    const route = getTownRoute(activeTask);
    const isNext = Boolean(activeTask && point.id === route.startPointId);
    const group = this.add.container(point.x, point.y).setDepth(5);
    const ring = this.add.ellipse(0, point.height * 0.42, point.width * 0.58, 26, 0xffffff, isNext ? 0.14 : 0.015)
      .setStrokeStyle(3, point.color, isNext ? 0.76 : 0.2);
    const sparkleRing = this.add.ellipse(0, point.height * 0.42, point.width * 0.44, 14, 0xffffff, isNext ? 0.16 : 0)
      .setStrokeStyle(2, 0xffffff, isNext ? 0.68 : 0);
    const hotspot = this.add.rectangle(0, 0, point.width, point.height, 0xffffff, 0.001)
      .setInteractive({ useHandCursor: true });
    const labelPanel = this.add.rectangle(0, -point.height / 2 - 20, Math.max(140, point.label.length * 12), 34, 0xfffbff, 0.9)
      .setStrokeStyle(2, point.color, 0.38);
    const label = this.add.text(-Math.max(54, point.label.length * 5.1), -point.height / 2 - 29, point.label, {
      fontFamily: "Avenir Next, sans-serif",
      fontSize: "13px",
      color: "#583f55",
      fontStyle: "bold"
    });
    const action = this.add.text(-Math.max(48, point.action.length * 5.2), point.height / 2 + 10, point.action, {
      fontFamily: "Avenir Next, sans-serif",
      fontSize: "14px",
      color: "#ffffff",
      fontStyle: "bold",
      backgroundColor: `rgba(${point.color >> 16},${(point.color >> 8) & 255},${point.color & 255},0.82)`
    }).setPadding(8, 4, 8, 4);
    labelPanel.setAlpha(isNext ? 0.9 : 0);
    label.setAlpha(isNext ? 1 : 0);
    action.setAlpha(isNext ? 1 : 0);
    group.add([ring, sparkleRing, hotspot, labelPanel, label, action]);
    if (point.id === "clock_tower" && completedCount > 0) {
      const star = this.add.image(60, -84, "icon-star").setDisplaySize(26, 26).setTint(0xffcf5a);
      group.add(star);
      this.tweens.add({ targets: star, angle: 10, y: star.y - 5, duration: 820, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    }
    this.townInteractions.set(point.id, { point, group, ring, hotspot, labelPanel, label, action });
    hotspot.on("pointerover", () => this.highlightTownInteraction(point.id, true));
    hotspot.on("pointerout", () => this.highlightTownInteraction(point.id, false));
    hotspot.on("pointerdown", () => this.handleTownInteraction(point.id, activeTask));
    if (isNext) {
      this.tweens.add({ targets: [ring, sparkleRing], alpha: 0.34, scaleX: 1.06, scaleY: 1.14, duration: 820, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    }
  }

  drawTownProgressBadge(progress, activeTask) {
    const completedCount = getVerticalSliceCompletedCount(progress);
    const accent = activeTask ? sceneAccent[activeTask.sceneId] || 0xc75f78 : 0x4f9d7a;
    const badge = this.add.container(146, 420).setDepth(6);
    const panel = this.add.rectangle(0, 0, 128, 42, 0xfffbff, 0.82).setStrokeStyle(2, accent, 0.28);
    badge.add(panel);
    const labels = ["问候", "铃声", "天气"];
    labels.forEach((label, index) => {
      const x = -36 + index * 36;
      const lit = index < completedCount;
      const star = this.add.star(x, -4, 5, 6, 13, lit ? 0xffcf5a : 0xd8c9b7, lit ? 0.95 : 0.52).setStrokeStyle(1, 0xffffff, 0.72);
      const text = this.add.text(x - 16, 12, label, {
        fontFamily: "Avenir Next, sans-serif",
        fontSize: "10px",
        color: lit ? "#8b5e79" : "#8d6f82",
        fontStyle: "bold"
      });
      badge.add([star, text]);
      if (lit) this.tweens.add({ targets: star, alpha: 0.72, duration: 760, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    });
    const title = this.add.text(-52, -38, `${completedCount}/${verticalSliceTaskIds.length} 第一圈`, {
      fontFamily: "Avenir Next, sans-serif",
      fontSize: "13px",
      color: "#583f55",
      fontStyle: "bold"
    }).setBackgroundColor("rgba(255,251,255,0.72)").setPadding(8, 4, 8, 4);
    badge.add(title);
  }

  drawTownPath(progress, activeTask) {
    const completedCount = progress.completedTaskIds?.length || 0;
    const totalCount = taskConfigs.length;
    const accent = activeTask ? sceneAccent[activeTask.sceneId] || 0xc75f78 : 0x4f9d7a;
    const path = this.add.container(0, 0).setDepth(1);
    const railY = 484;
    const labelY = 454;
    const rail = this.add.rectangle(448, railY, 612, 12, 0xffffff, 0.52).setStrokeStyle(1, 0xffffff, 0.72);
    const fillWidth = 612 * (completedCount / Math.max(totalCount, 1));
    const fill = this.add.rectangle(142 + fillWidth / 2, railY, fillWidth, 12, accent, 0.68);
    path.add([rail, fill]);
    for (let i = 0; i <= totalCount; i += 1) {
      const x = 142 + (612 / totalCount) * i;
      const done = i <= completedCount;
      const marker = this.add.circle(x, railY, done ? 9 : 7, done ? accent : 0xfffbf5, done ? 0.9 : 0.72)
        .setStrokeStyle(2, done ? 0xffffff : 0xd8c9b7, 0.86);
      path.add(marker);
      this.townPathMarkerCount += 1;
      if (i === completedCount && activeTask) {
        const arrow = this.add.triangle(x, railY - 26, 0, -10, 18, 0, 0, 10, accent, 0.86);
        arrow.setAngle(90);
        path.add(arrow);
        this.tweens.add({ targets: arrow, y: arrow.y - 6, duration: 650, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
      }
    }
    const label = this.add.text(126, labelY, activeTask ? `下一站：${scenesById[activeTask.sceneId]?.title || "房间"}` : "小镇已经布置完成", {
      fontFamily: "Arial, sans-serif",
      fontSize: "16px",
      color: "#3f3430",
      fontStyle: "bold",
      backgroundColor: "rgba(255,250,244,0.72)"
    }).setPadding(10, 5, 10, 5).setDepth(2);
    path.add(label);
  }

  drawCharacter(x, y, activeTask) {
    this.townCharacterShadow = this.add.ellipse(x + 2, y + 10, 42, 14, 0x4d4038, 0.16).setDepth(39);
    const progress = loadProgress();
    const character = this.add.container(x, y - 82).setDepth(41);
    const imageKey = outfitCharacterImages[progress.selectedOutfitId] || "character-default";
    const sprite = this.add.image(0, 0, imageKey)
      .setDisplaySize(82, 123)
      .setOrigin(0.5, 0.98);
    const bow = progress.selectedOutfitId === "outfit_garden_bow"
      ? this.add.image(15, -92, "item-bow").setDisplaySize(22, 16).setAngle(-8)
      : null;
    character.add([sprite, ...(bow ? [bow] : [])]);
    character.setSize(54, 104);
    character.setInteractive({ useHandCursor: true });
    character.walkParts = { sprite, bow };
    [sprite, bow].filter(Boolean).forEach((part) => {
      part.__walkBaseY = part.y;
      part.__walkBaseAngle = part.angle || 0;
    });
    this.townCharacter = character;
    this.townCharacterOutfitGroup = null;
    this.tweens.add({ targets: character, y: character.y - 2, duration: 920, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    character.on("pointerdown", () => {
      this.tweens.add({ targets: character, scaleX: Math.sign(character.scaleX || 1) * 1.08, scaleY: 1.08, duration: 120, yoyo: true, ease: "Sine.easeOut" });
      const route = getTownRoute(activeTask);
      this.showTownSpeech(activeTask ? route.goal : "小镇亮起来了", activeTask ? 0x426c7b : 0x4f9d7a);
    });
  }

  bindTownInput(activeTask) {
    this.input.keyboard?.removeAllKeys?.();
    this.townCursors = this.input.keyboard?.createCursorKeys?.();
    this.townWasd = this.input.keyboard?.addKeys?.("W,A,S,D");
    this.townKeyboardTarget = { x: this.townCharacter?.x || 842, y: this.getTownCharacterGroundY() };
    this.events.on("update", () => this.updateTownKeyboardMovement(activeTask));
  }

  bindTownRuntimeFeedback() {
    this.townEventUnsubs.push(
      eventBus.on("task:completed", (detail) => {
        if (!verticalSliceTaskIds.includes(detail.task?.id)) return;
        const copyByTaskId = {
          task_eng_g3b_u01_main: "问候星片回到钟塔",
          task_eng_g3b_u02_main: "小闹钟点亮第 2 格",
          task_eng_g3b_u03_main: "第一圈星路已点亮"
        };
        this.time.delayedCall(120, () => {
          if (!this.scene.isActive("TownScene")) return;
          this.showTownSpeech(copyByTaskId[detail.task.id] || "星片回到钟塔", 0xffcf5a, 2200);
        });
      })
    );
  }

  handleTownGroundClick(pointer) {
    if (!pointer) return;
    const x = Phaser.Math.Clamp(pointer.x, 96, 928);
    const y = Phaser.Math.Clamp(pointer.y, 390, 560);
    this.moveTownCharacterTo(x, y, "去这里");
  }

  updateTownKeyboardMovement(activeTask) {
    if (!this.townCharacter || !this.townKeyboardTarget) return;
    const cursors = this.townCursors;
    const wasd = this.townWasd;
    const left = cursors?.left?.isDown || wasd?.A?.isDown;
    const right = cursors?.right?.isDown || wasd?.D?.isDown;
    const up = cursors?.up?.isDown || wasd?.W?.isDown;
    const down = cursors?.down?.isDown || wasd?.S?.isDown;
    if (!left && !right && !up && !down) return;
    const speed = 3.1;
    const dx = (right ? speed : 0) - (left ? speed : 0);
    const dy = (down ? speed : 0) - (up ? speed : 0);
    const nextX = Phaser.Math.Clamp(this.townCharacter.x + dx, 96, 928);
    const nextGroundY = Phaser.Math.Clamp(this.getTownCharacterGroundY() + dy, 390, 560);
    this.townCharacterMoveTween?.stop();
    if (dx !== 0) this.faceTownCharacter(dx);
    this.playTownWalkStep();
    this.setTownCharacterPosition(nextX, nextGroundY);
    this.updateTownInteractionProximity(activeTask);
  }

  moveTownCharacterTo(x, groundY, label = "") {
    if (!this.townCharacter) return;
    this.townCharacterMoveTween?.stop();
    this.showTownDestinationMarker(x, groundY, label);
    const startX = this.townCharacter.x;
    const startY = this.getTownCharacterGroundY();
    const distance = Phaser.Math.Distance.Between(startX, startY, x, groundY);
    this.faceTownCharacter(x - startX);
    this.townCharacterMoveTween = this.tweens.addCounter({
      from: 0,
      to: 1,
      duration: Phaser.Math.Clamp(distance * 5.2, 260, 1200),
      ease: "Sine.easeInOut",
      onUpdate: (tween) => {
        const value = tween.getValue();
        this.playTownWalkStep(value);
        this.setTownCharacterPosition(
          Phaser.Math.Linear(startX, x, value),
          Phaser.Math.Linear(startY, groundY, value)
        );
      },
      onComplete: () => {
        this.townCharacterMoveTween = null;
        this.updateTownInteractionProximity(taskRuntime.getCurrentTask(loadProgress()));
      }
    });
  }

  setTownCharacterPosition(x, groundY) {
    if (!this.townCharacter) return;
    const spriteY = groundY - 82;
    this.townCharacter.setPosition(x, spriteY);
    this.townCharacterShadow?.setPosition(x + 2, groundY + 10);
    const depth = Phaser.Math.Clamp(Math.round(groundY / 10), 39, 57);
    this.townCharacter.setDepth(depth + 1);
    this.townCharacterShadow?.setDepth(depth);
  }

  getTownCharacterGroundY() {
    return (this.townCharacter?.y || 430) + 82;
  }

  faceTownCharacter(dx) {
    if (!this.townCharacter || dx === 0) return;
    const facing = dx < 0 ? -1 : 1;
    this.townCharacter.setScale(facing, 1);
  }

  playTownWalkStep(phase = null) {
    if (!this.townCharacter?.walkParts) return;
    const value = phase == null ? this.time.now / 180 : phase * Math.PI * 4;
    const swing = Math.sin(value) * 2.2;
    const bob = Math.abs(Math.sin(value)) * 2;
    const { sprite, bow } = this.townCharacter.walkParts;
    [sprite, bow].filter(Boolean).forEach((part) => {
      if (part.__walkBaseY == null) part.__walkBaseY = part.y;
      if (part.__walkBaseAngle == null) part.__walkBaseAngle = part.angle || 0;
      part.setY(part.__walkBaseY - bob);
      part.setAngle(part.__walkBaseAngle + swing);
    });
  }

  showTownDestinationMarker(x, y, label) {
    if (this.townDestinationMarker) {
      this.townDestinationMarker.destroy();
      this.townDestinationMarker = null;
    }
    this.townDestinationMarker = this.add.container(x, y).setDepth(4);
    const ring = this.add.ellipse(0, 0, 72, 28, 0xffffff, 0.16).setStrokeStyle(3, 0x426c7b, 0.58);
    const dot = this.add.circle(0, 0, 5, 0x426c7b, 0.9);
    this.townDestinationMarker.add([ring, dot]);
    if (label) {
      const copy = this.add.text(-30, -38, label, {
        fontFamily: "Arial, sans-serif",
        fontSize: "13px",
        color: "#ffffff",
        fontStyle: "bold",
        backgroundColor: "rgba(66,108,123,0.78)"
      }).setPadding(7, 4, 7, 4);
      this.townDestinationMarker.add(copy);
    }
    this.tweens.add({ targets: ring, scaleX: 1.16, scaleY: 1.16, alpha: 0, duration: 720, ease: "Sine.easeOut" });
    this.time.delayedCall(760, () => {
      if (!this.townDestinationMarker) return;
      const marker = this.townDestinationMarker;
      this.townDestinationMarker = null;
      this.tweens.add({ targets: marker, alpha: 0, duration: 180, onComplete: () => marker.destroy() });
    });
  }

  handleTownInteraction(pointId, activeTask) {
    const item = this.townInteractions.get(pointId);
    if (!item) return;
    const route = getTownRoute(activeTask);
    this.moveTownCharacterTo(item.point.approach.x, item.point.approach.y, item.point.label);
    this.highlightTownInteraction(pointId, true);
    this.time.delayedCall(280, () => {
      if (!this.scene.isActive("TownScene")) return;
      if (pointId === "clock_tower") {
        this.showClockTowerFeedback();
        return;
      }
      if (pointId === "ray_board") {
        this.showRayBoardFeedback(activeTask);
        return;
      }
      if (activeTask && pointId === route.startPointId) {
        this.enterTownTask(activeTask, route);
        return;
      }
      if (pointId === "post_office") {
        this.enterPostOffice(activeTask);
      }
    });
  }

  highlightTownInteraction(pointId, enabled) {
    const item = this.townInteractions.get(pointId);
    if (!item) return;
    item.ring.setStrokeStyle(4, item.point.color, enabled ? 0.9 : 0.42);
    item.ring.setAlpha(enabled ? 0.22 : 0.03);
    item.labelPanel.setAlpha(enabled ? 0.9 : 0);
    item.label.setAlpha(enabled ? 1 : 0);
    item.action.setAlpha(enabled ? 1 : 0);
    this.tweens.add({ targets: item.group, scale: enabled ? 1.035 : 1, duration: 120, ease: "Sine.easeOut" });
  }

  updateTownInteractionProximity(activeTask) {
    const groundX = this.townCharacter?.x || 0;
    const groundY = this.getTownCharacterGroundY();
    townInteractionPoints.forEach((point) => {
      const near = Phaser.Math.Distance.Between(groundX, groundY, point.approach.x, point.approach.y) < 92;
      if (near) {
        this.highlightTownInteraction(point.id, true);
        const route = getTownRoute(activeTask);
        if (activeTask && point.id === route.startPointId) this.showTownSpeech(route.nearSpeech, point.color, 1200);
      }
    });
  }

  showClockTowerFeedback() {
    const progress = loadProgress();
    const completedCount = getVerticalSliceCompletedCount(progress);
    const copy = completedCount > 0 ? `星路亮起 ${completedCount}/3` : "第一圈星路还暗着";
    this.showTownSpeech(copy, 0xc75f78, 1800);
    const item = this.townInteractions.get("clock_tower");
    if (item) {
      this.emitTinySparkles(item.point.x, item.point.y - 84, completedCount > 0 ? 0xffcf5a : 0xc75f78, 8);
    }
  }

  showRayBoardFeedback(activeTask) {
    if (activeTask) {
      const route = getTownRoute(activeTask);
      this.showTownSpeech(route.guideSpeech, 0x426c7b, 2000);
      eventBus.emit("town:quest-accepted", { taskId: activeTask.id, source: "town_ray_board" });
      this.pulseTownInteraction(route.startPointId);
      return;
    }
    this.showTownSpeech("Ray：今天的委托完成啦", 0x4f9d7a, 1600);
  }

  pulseTownInteraction(pointId) {
    const item = this.townInteractions.get(pointId);
    if (!item) return;
    this.highlightTownInteraction(pointId, true);
    this.tweens.add({ targets: item.group, scale: 1.08, duration: 150, yoyo: true, repeat: 1, ease: "Sine.easeInOut" });
    this.time.delayedCall(780, () => this.highlightTownInteraction(pointId, false));
  }

  enterPostOffice(activeTask) {
    if (!activeTask) {
      this.showTownSpeech("邮局的灯已经亮着", 0x4f9d7a, 1500);
      return;
    }
    this.enterTownTask(activeTask, getTownRoute(activeTask), "town_post_office");
  }

  enterTownTask(activeTask, route, sourceOverride = null) {
    if (!activeTask) return;
    this.showTownSpeech(route.startSpeech, sceneAccent[activeTask.sceneId] || 0x5f83c4, 900);
    this.time.delayedCall(360, () => {
      eventBus.emit("ui:focus-task", { taskId: activeTask.id, source: sourceOverride || route.source });
    });
  }

  emitTinySparkles(x, y, color, count = 6) {
    for (let i = 0; i < count; i += 1) {
      const angle = (Math.PI * 2 * i) / count;
      const sparkle = this.add.image(x, y, "icon-star").setDisplaySize(15, 15).setTint(color).setAlpha(0.82).setDepth(8);
      this.tweens.add({
        targets: sparkle,
        x: x + Math.cos(angle) * (32 + (i % 2) * 12),
        y: y + Math.sin(angle) * 22 - 10,
        angle: 160,
        alpha: 0,
        scale: 0.58,
        duration: 520,
        ease: "Cubic.easeOut",
        onComplete: () => sparkle.destroy()
      });
    }
  }

  showTownSpeech(text, color, autoHideMs = 1400) {
    if (this.townSpeech) {
      this.townSpeech.destroy();
      this.townSpeech = null;
    }
    this.townSpeech = this.add.container(800, 430).setDepth(8);
    const panel = this.add.rectangle(0, 0, 220, 48, 0xffffff, 0.88).setStrokeStyle(2, color, 0.38);
    const copy = this.add.text(-92, -10, text, {
      fontFamily: "Arial, sans-serif",
      fontSize: "15px",
      color: "#3e332f",
      fontStyle: "bold",
      wordWrap: { width: 184 }
    });
    const pointer = this.add.triangle(84, 20, 0, 0, 22, 10, 0, 20, 0xffffff, 0.88);
    this.townSpeech.add([panel, pointer, copy]);
    this.townSpeech.setAlpha(0);
    this.townSpeech.setScale(0.9);
    this.tweens.add({ targets: this.townSpeech, alpha: 1, scale: 1, y: this.townSpeech.y - 8, duration: 160, ease: "Back.Out" });
    if (autoHideMs) {
      this.time.delayedCall(autoHideMs, () => {
        if (!this.townSpeech) return;
        const speech = this.townSpeech;
        this.townSpeech = null;
        this.tweens.add({ targets: speech, alpha: 0, y: speech.y - 12, duration: 220, onComplete: () => speech.destroy() });
      });
    }
  }

  drawTownSceneGrid(progress, activeTask) {
    return;
    const cards = sceneConfigs
      .filter((scene) => scene.id !== "scene_town")
      .map((scene) => ({
        sceneId: scene.id,
        targetScene: scene.phaserKey,
        title: scene.title,
        subtitle: compactSceneSubtitle(scene.description)
      }));
    const activeCard = cards.find((card) => card.sceneId === activeTask?.sceneId) || cards[0];
    if (activeCard) {
      this.drawFeaturedTownCard(382, 294, activeCard.title, activeCard.subtitle, activeCard.targetScene, activeCard.sceneId, progress, activeTask);
    }
  }

  drawFeaturedTownCard(x, y, title, subtitle, targetScene, sceneId, progress, activeTask) {
    const imageKey = sceneImages[sceneId];
    const taskIds = sceneCardTaskMap[sceneId] || [];
    const completed = taskIds.filter((taskId) => progress.completedTaskIds?.includes(taskId)).length;
    const accent = sceneAccent[sceneId] || 0xc75f78;
    const group = this.add.container(x, y).setDepth(3);
    const card = this.add.rectangle(0, 0, 460, 260, 0xfffbf5, 0.86).setStrokeStyle(3, accent, 0.62).setInteractive({ useHandCursor: true });
    const image = this.add.image(0, -48, imageKey).setDisplaySize(420, 168).setAlpha(0.96);
    const titleText = this.add.text(-198, 58, title, {
      fontFamily: "Arial, sans-serif",
      fontSize: "26px",
      color: "#3e332f",
      fontStyle: "bold"
    });
    const subtitleText = this.add.text(-198, 92, activeTask?.title || subtitle, {
      fontFamily: "Arial, sans-serif",
      fontSize: "15px",
      color: "#51423d",
      lineSpacing: 2,
      wordWrap: { width: 300 }
    });
    const progressText = this.add.text(132, 76, `${getVerticalSliceCompletedCount(progress)}/${verticalSliceTaskIds.length}`, {
      fontFamily: "Arial, sans-serif",
      fontSize: "18px",
      color: "#ffffff",
      fontStyle: "bold",
      backgroundColor: "rgba(66,108,123,0.9)"
    }).setPadding(12, 7, 12, 7);
    group.add([card, image, titleText, subtitleText, progressText]);
    card.on("pointerover", () => this.tweens.add({ targets: group, scale: 1.015, duration: 140 }));
    card.on("pointerout", () => this.tweens.add({ targets: group, scale: 1, duration: 140 }));
    card.on("pointerdown", () => this.scene.start(targetScene));
  }

  drawTownCard(x, y, title, subtitle, targetScene, sceneId, progress) {
    const imageKey = sceneImages[sceneId];
    const taskIds = sceneCardTaskMap[sceneId] || [];
    const completed = taskIds.filter((taskId) => progress.completedTaskIds?.includes(taskId)).length;
    const reviewTask = getReviewTaskForScene(sceneId, progress);
    const nextTask = taskRuntime.getNextTaskForScene(sceneId, progress) || reviewTask;
    const previewTaskId = nextTask?.id || [...taskIds].reverse().find((taskId) => progress.completedTaskIds?.includes(taskId));
    const rewardPreview = getEnglishStoryRewardPreview(previewTaskId);
    const allDone = taskIds.length > 0 && completed >= taskIds.length;
    if (window.__studyGameTownState?.cards) {
      window.__studyGameTownState.cards[sceneId] = {
        completed,
        total: taskIds.length,
        nextTaskId: nextTask?.id,
        reviewTaskId: reviewTask?.id,
        reviewDue: Boolean(reviewTask),
        allDone
      };
    }
    const group = this.add.container(x, y).setDepth(3);
    const accent = sceneAccent[sceneId] || 0xc75f78;
    const isActiveScene = nextTask?.id && taskRuntime.getCurrentTask(progress)?.sceneId === sceneId;
    const card = this.add.rectangle(0, 0, 124, 58, reviewTask ? 0xfff4dc : allDone ? 0xe9f7ed : 0xffffff, reviewTask ? 0.72 : allDone ? 0.66 : 0.62).setStrokeStyle(2, reviewTask ? 0xc78b42 : allDone ? accent : 0xffffff, reviewTask ? 0.56 : allDone ? 0.34 : 0.72);
    card.setInteractive({ useHandCursor: true });
    const activeGlow = isActiveScene ? this.add.rectangle(0, 0, 132, 66, accent, 0.12).setStrokeStyle(3, accent, 0.6) : null;
    if (activeGlow) this.activeTownGlow = activeGlow;
    const progressRail = this.add.rectangle(18, 20, 74, 5, 0xe2d8cb, 0.8);
    const progressFill = this.add.rectangle(-19 + (completed / Math.max(taskIds.length, 1)) * 37, 20, 74 * (completed / Math.max(taskIds.length, 1)), 5, accent, 0.82);
    group.add([
      ...(activeGlow ? [activeGlow] : []),
      card,
      this.add.image(-42, -1, imageKey).setDisplaySize(52, 38).setAlpha(0.92),
      this.add.text(-8, -16, title, { fontFamily: "Arial, sans-serif", fontSize: "15px", color: "#3e332f", fontStyle: "bold" }),
      progressRail,
      progressFill
    ]);
    if (isActiveScene) {
      this.tweens.add({ targets: activeGlow, alpha: 0.22, scaleX: 1.025, scaleY: 1.025, duration: 760, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    }
    if (allDone || reviewTask) {
      const star = this.add.image(50, -20, reviewTask ? "anchor-bookshelf" : rewardPreview.image).setDisplaySize(20, 20).setAlpha(0.92);
      group.add(star);
      this.tweens.add({ targets: star, angle: 8, y: star.y - 4, duration: 900, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
    }
    card.on("pointerover", () => this.tweens.add({ targets: group, scale: 1.035, duration: 140 }));
    card.on("pointerout", () => this.tweens.add({ targets: group, scale: 1, duration: 140 }));
    card.on("pointerdown", () => {
      if (nextTask?.id) eventBus.emit("ui:focus-task", { taskId: nextTask.id });
      this.scene.start(targetScene);
    });
  }
}

class WardrobeScene extends BaseScene {
  constructor() {
    super("WardrobeScene", "scene_wardrobe");
  }
}

class KitchenScene extends BaseScene {
  constructor() {
    super("KitchenScene", "scene_kitchen");
  }
}

class SchoolScene extends BaseScene {
  constructor() {
    super("SchoolScene", "scene_school");
  }
}

class CityScene extends BaseScene {
  constructor() {
    super("CityScene", "scene_city");
  }
}

class FestivalScene extends BaseScene {
  constructor() {
    super("FestivalScene", "scene_festival");
  }
}

class NatureScene extends BaseScene {
  constructor() {
    super("NatureScene", "scene_nature");
  }
}

class HealthScene extends BaseScene {
  constructor() {
    super("HealthScene", "scene_health");
  }
}

class StudyScene extends BaseScene {
  constructor() {
    super("StudyScene", "scene_study");
  }
}

function buttonStyle() {
  return {
    fontFamily: "Arial, sans-serif",
    fontSize: "18px",
    color: "#3e332f",
    backgroundColor: "rgba(255,255,255,0.76)"
  };
}

function decorTextStyle() {
  return {
    fontFamily: "Avenir Next, sans-serif",
    fontSize: "14px",
    color: "#5d4660",
    backgroundColor: "rgba(255,247,251,0.82)"
  };
}

function getOutfitSceneLabel(outfitId) {
  return {
    outfit_default: "日常出发",
    outfit_sunny: "花园装扮",
    outfit_cozy: "温暖外套",
    outfit_garden_bow: "新蝴蝶结",
    outfit_apron: "点心围裙"
  }[outfitId] || "欢迎回来";
}

function drawOutfitLayers(scene, group, outfitId, townScale = false) {
  if (!scene || !group) return;
  const scale = townScale ? 0.88 : 1;
  if (outfitId === "outfit_garden_bow") {
    group.add(scene.add.image(8 * scale, -128 * scale, "item-bow").setDisplaySize(56 * scale, 42 * scale).setAngle(-4));
  }
  if (outfitId === "outfit_apron") {
    const bib = scene.add.rectangle(2 * scale, 8 * scale, 50 * scale, 66 * scale, 0xfff4dc, 0.58).setStrokeStyle(2, 0xd98f9c, 0.36);
    const waist = scene.add.rectangle(0, 40 * scale, 68 * scale, 13 * scale, 0xffd3df, 0.62).setStrokeStyle(1, 0xd98f9c, 0.28);
    const strapLeft = scene.add.line(-20 * scale, -22 * scale, 0, 0, 16 * scale, 42 * scale, 0xd98f9c, 0.48).setLineWidth(Math.max(2, 3 * scale));
    const strapRight = scene.add.line(20 * scale, -22 * scale, 0, 0, -16 * scale, 42 * scale, 0xd98f9c, 0.48).setLineWidth(Math.max(2, 3 * scale));
    const cake = scene.add.image(16 * scale, 12 * scale, "item-cake").setDisplaySize(25 * scale, 25 * scale).setAlpha(0.9);
    group.add([strapLeft, strapRight, bib, waist, cake]);
  }
  if (outfitId === "outfit_cozy") {
    group.add(scene.add.image(0, -8 * scale, "outfit-jacket").setDisplaySize(86 * scale, 128 * scale).setAlpha(0.72));
  }
}

function compactPrompt(prompt = "", maxLength = 34) {
  return prompt.length > maxLength ? `${prompt.slice(0, maxLength)}...` : prompt;
}

function compactOptionLabel(label = "") {
  const normalized = label.replace(/\s+/g, " ").trim();
  if (normalized.includes("→")) {
    const [left, right] = normalized.split("→").map((item) => item.trim());
    return `${left}\n→ ${right}`;
  }
  if (normalized.length <= 18) return normalized;
  const firstSpace = normalized.indexOf(" ", 10);
  if (firstSpace > 0 && firstSpace <= 18) return `${normalized.slice(0, firstSpace)}\n${normalized.slice(firstSpace + 1, 34)}`;
  return `${normalized.slice(0, 18)}...`;
}

function microOptionLabel(label = "") {
  const normalized = label
    .replace(/\s+/g, " ")
    .replace("衣物篮", "衣篮")
    .replace("分钟", "分");
  if (normalized.includes("→")) {
    const [left, right] = normalized.split("→").map((item) => item.trim());
    return `${left}\n→ ${right}`;
  }
  return normalized;
}

function trayLabel(type) {
  return {
    choice: "点一个道具",
    drag: "拖到亮起的位置",
    match: "选好一组道具",
    order: "按顺序摆放"
  }[type] || "道具盘";
}

function targetActionLabel(type) {
  return {
    choice: "看这里",
    drag: "放这里",
    match: "归到这里",
    order: "排在这里"
  }[type] || "这里";
}

function characterPromptForStep(step) {
  if (!step) return "我在这里等你";
  return {
    choice: "帮我挑一个合适的",
    drag: "把它拖到亮起的位置",
    match: "把同类小物放一组",
    order: "按先后顺序摆好"
  }[step.type] || "一起看看线索";
}

function anchorPickerTitle(type) {
  return {
    choice: "点一个放过去",
    drag: "也可以直接点选",
    match: "选成一组",
    order: "按顺序点"
  }[type] || "选道具";
}

function pickerSelectionLabel(step, selectedCount) {
  if (!step) return "";
  if (step.type === "order") return selectedCount ? `已排 ${selectedCount}/${step.correctOptionIds.length}` : "先点第一步";
  if (step.type === "match") return selectedCount ? `已选 ${selectedCount}/${step.correctOptionIds.length}` : "先挑同一组";
  if (step.type === "drag") return selectedCount ? "已拿起道具" : "先选道具";
  return "";
}

function pickerConfirmLabel(type) {
  return {
    drag: "放好了",
    match: "一起放好",
    order: "检查"
  }[type] || "确认";
}

function pickerInlineHint(type) {
  return {
    drag: "点道具后在这里确认",
    match: "挑好一组后确认",
    order: "按先后点，再检查"
  }[type] || "选好后确认";
}

function shortTaskTitle(title = "") {
  return title.length > 5 ? `${title.slice(0, 5)}...` : title;
}

function compactSceneSubtitle(description = "") {
  return description
    .replace(/[。,.，]/g, "、")
    .split("、")
    .filter(Boolean)
    .slice(0, 3)
    .join("、")
    .slice(0, 12);
}

function getEnglishStoryRewardPreview(taskId) {
  const row = englishStoryContentRows.find((item) => item.taskId === taskId);
  if (!row) return { image: "icon-star", label: "新奖励" };
  return {
    image: rewardAssetKey(row.rewardId),
    label: row.rewardTitle || "主线奖励"
  };
}

function getReviewTaskForScene(sceneId, progress) {
  const dueKnowledgeIds = new Set(getReviewKnowledgeIds(progress));
  if (!dueKnowledgeIds.size) return null;
  return taskConfigs.find((task) =>
    task.sceneId === sceneId &&
    progress.completedTaskIds?.includes(task.id) &&
    task.steps.some((step) => step.knowledgeIds.some((knowledgeId) => dueKnowledgeIds.has(knowledgeId)))
  ) || null;
}

function getOptionPreviewKey(option) {
  if (option?.asset && imageAssets[option.asset]) return option.asset;
  const value = `${option.asset || ""} ${option.label || ""}`.toLowerCase();
  const match = optionPreviewImages.find(([needle]) => value.includes(needle));
  return match?.[1] || "icon-star";
}

function completedArtifactLabel(step) {
  const value = `${step.id || ""} ${step.prompt || ""} ${step.anchorId || ""}`.toLowerCase();
  if (value.includes("勺") || value.includes("半杯") || value.includes("中间线") || value.includes("cup")) return "已量好";
  if (value.includes("分钟") || value.includes("timer")) return "已调好";
  if (value.includes("信") || value.includes("mailbox") || value.includes("map")) return "已送到";
  if (value.includes("卡片") || value.includes("bookshelf")) return "已归位";
  if (value.includes("mirror") || value.includes("搭配") || value.includes("wardrobe")) return "已搭好";
  return "已放好";
}

export function createPhaserGame(parent) {
  if (!Phaser) throw new Error("Phaser runtime is not loaded");
  window.__studyGameStatus = "creating";
  document.documentElement.dataset.studyGameStatus = "creating";
  const game = new Phaser.Game({
    type: Phaser.CANVAS,
    parent,
    width: 1024,
    height: 640,
    backgroundColor: "#f6e3bf",
    scale: {
      mode: Phaser.Scale.FIT,
      autoCenter: Phaser.Scale.CENTER_BOTH,
      width: 1024,
      height: 640
    },
    scene: [BootScene, PreloadScene, TownScene, WardrobeScene, KitchenScene, SchoolScene, CityScene, FestivalScene, NatureScene, HealthScene, StudyScene]
  });

  window.__studyGame = game;
  return game;
}

export function navigateToScene(sceneId) {
  const game = window.__studyGame;
  const scene = scenesById[sceneId];
  if (!window.__studyGameAssetsReady) {
    window.__studyGamePendingSceneId = sceneId;
    return;
  }
  if (game && scene?.phaserKey) {
    game.scene.start(scene.phaserKey);
  }
}
