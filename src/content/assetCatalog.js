import { englishStoryContentRows } from "./englishStoryContentTable.js";

const rewardAssets = englishStoryContentRows.map((row) =>
  transparentAsset(rewardAssetKey(row.rewardId), rewardAssetFile(row.rewardId), "reward")
);

const sceneLargeAssets = [
  "scene-large-wardrobe-rack.png",
  "scene-large-wardrobe-mirror.png",
  "scene-large-wardrobe-reward-wall.png",
  "scene-large-wardrobe-bench.png",
  "scene-large-kitchen-counter.png",
  "scene-large-kitchen-recipe-board.png",
  "scene-large-kitchen-reward-table.png",
  "scene-large-kitchen-prep-station.png",
  "scene-large-school-board.png",
  "scene-large-school-library.png",
  "scene-large-school-task-wall.png",
  "scene-large-school-playground.png",
  "scene-large-city-route-sign.png",
  "scene-large-city-sign-rack.png",
  "scene-large-city-interview-station.png",
  "scene-large-city-bus-stop.png",
  "scene-large-festival-stage.png",
  "scene-large-festival-craft-table.png",
  "scene-large-festival-calendar-wall.png",
  "scene-large-festival-reward-garland.png",
  "scene-large-nature-weather-station.png",
  "scene-large-nature-garden-bed.png",
  "scene-large-nature-globe-table.png",
  "scene-large-nature-reward-stand.png",
  "scene-large-health-sink-station.png",
  "scene-large-health-habit-board.png",
  "scene-large-health-care-kit.png",
  "scene-large-health-routine-shelf.png",
  "scene-large-study-mail-table.png",
  "scene-large-study-album-shelf.png",
  "scene-large-study-research-wall.png"
].map((file) => transparentAsset(file.replace(".png", ""), file, "scene-large"));

export const assetCatalog = [
  sceneAsset("scene-town", "scene-town.png"),
  sceneAsset("scene-wardrobe", "scene-wardrobe.png"),
  sceneAsset("scene-kitchen", "scene-kitchen.png"),
  sceneAsset("scene-study", "scene-study.png"),
  sceneAsset("scene-school", "scene-school.png"),
  sceneAsset("scene-city", "scene-city.png"),
  sceneAsset("scene-festival", "scene-festival.png"),
  sceneAsset("scene-nature", "scene-nature.png"),
  sceneAsset("scene-health", "scene-health.png"),

  transparentAsset("character-default", "character-default.png", "character"),
  transparentAsset("character-wave", "character-wave.png", "character"),
  transparentAsset("icon-star", "icon-star.png", "ui"),
  transparentAsset("icon-heart", "icon-heart.png", "ui"),
  transparentAsset("item-bow", "item-bow.png", "item"),
  transparentAsset("item-bag", "item-bag.png", "item"),
  transparentAsset("item-headband", "item-headband.png", "item"),
  transparentAsset("item-book", "item-book.png", "item"),
  transparentAsset("item-cat-card", "item-cat-card.png", "item"),
  transparentAsset("item-apple-card", "item-apple-card.png", "item"),
  transparentAsset("item-butterfly-card", "item-butterfly-card.png", "item"),
  transparentAsset("item-flower", "item-flower.png", "item"),
  transparentAsset("item-cake", "item-cake.png", "item"),
  transparentAsset("item-gift", "item-gift.png", "item"),
  transparentAsset("item-chest", "item-chest.png", "item"),
  transparentAsset("item-key", "item-key.png", "item"),
  transparentAsset("item-shoes", "item-shoes.png", "item"),
  transparentAsset("outfit-jacket", "outfit-jacket.png", "outfit"),
  transparentAsset("anchor-rack", "outfit-dress.png", "anchor"),
  transparentAsset("anchor-mirror", "anchor-mirror.png", "anchor"),
  transparentAsset("anchor-shoes", "item-shoes.png", "anchor"),
  transparentAsset("anchor-cup", "anchor-cup.png", "anchor"),
  transparentAsset("anchor-oven", "anchor-oven.png", "anchor"),
  transparentAsset("anchor-timer", "anchor-timer.png", "anchor"),
  transparentAsset("anchor-mailbox", "anchor-mailbox.png", "anchor"),
  transparentAsset("anchor-map", "anchor-map.png", "anchor"),
  transparentAsset("anchor-bookshelf", "anchor-bookshelf.png", "anchor"),
  transparentAsset("anchor-music-box", "anchor-music-box.png", "anchor"),

  transparentAsset("anchor-school-board", "anchor-school-board.png", "anchor"),
  transparentAsset("anchor-school-library", "anchor-school-library.png", "anchor"),
  transparentAsset("anchor-school-playground", "anchor-school-playground.png", "anchor"),
  transparentAsset("anchor-city-station", "anchor-city-station.png", "anchor"),
  transparentAsset("anchor-city-map", "anchor-city-map.png", "anchor"),
  transparentAsset("anchor-city-sign", "anchor-city-sign.png", "anchor"),
  transparentAsset("anchor-festival-stage", "anchor-festival-stage.png", "anchor"),
  transparentAsset("anchor-festival-craft", "anchor-festival-craft.png", "anchor"),
  transparentAsset("anchor-festival-calendar", "anchor-festival-calendar.png", "anchor"),
  transparentAsset("anchor-nature-garden", "anchor-nature-garden.png", "anchor"),
  transparentAsset("anchor-nature-sky", "anchor-nature-sky.png", "anchor"),
  transparentAsset("anchor-nature-earth", "anchor-nature-earth.png", "anchor"),
  transparentAsset("anchor-health-sink", "anchor-health-sink.png", "anchor"),
  transparentAsset("anchor-health-chart", "anchor-health-chart.png", "anchor"),
  transparentAsset("anchor-health-kit", "anchor-health-kit.png", "anchor"),

  transparentAsset("material-wardrobe-clothes", "material-wardrobe-clothes.png", "material"),
  transparentAsset("material-wardrobe-mirror", "material-wardrobe-mirror.png", "material"),
  transparentAsset("material-wardrobe-show", "material-wardrobe-show.png", "material"),
  transparentAsset("material-kitchen-food", "material-kitchen-food.png", "material"),
  transparentAsset("material-kitchen-measure", "material-kitchen-measure.png", "material"),
  transparentAsset("material-kitchen-recipe", "material-kitchen-recipe.png", "material"),
  transparentAsset("material-school-timetable", "material-school-timetable.png", "material"),
  transparentAsset("material-school-library", "material-school-library.png", "material"),
  transparentAsset("material-school-playground", "material-school-playground.png", "material"),
  transparentAsset("material-city-transport", "material-city-transport.png", "material"),
  transparentAsset("material-city-signs", "material-city-signs.png", "material"),
  transparentAsset("material-city-jobs", "material-city-jobs.png", "material"),
  transparentAsset("material-festival-stage", "material-festival-stage.png", "material"),
  transparentAsset("material-festival-craft", "material-festival-craft.png", "material"),
  transparentAsset("material-festival-calendar", "material-festival-calendar.png", "material"),
  transparentAsset("material-nature-weather", "material-nature-weather.png", "material"),
  transparentAsset("material-nature-garden", "material-nature-garden.png", "material"),
  transparentAsset("material-nature-earth", "material-nature-earth.png", "material"),
  transparentAsset("material-health-sink", "material-health-sink.png", "material"),
  transparentAsset("material-health-chart", "material-health-chart.png", "material"),
  transparentAsset("material-health-kit", "material-health-kit.png", "material"),
  transparentAsset("material-study-mail", "material-study-mail.png", "material"),
  transparentAsset("material-study-album", "material-study-album.png", "material"),
  transparentAsset("material-study-research", "material-study-research.png", "material"),

  ...sceneLargeAssets,
  ...rewardAssets
];

export const assetFiles = [...new Set(assetCatalog.map((asset) => asset.file))].sort();
export const sceneAssetFiles = assetCatalog.filter((asset) => asset.kind === "scene").map((asset) => asset.file).sort();
export const transparentAssetFiles = assetFiles.filter((file) => !sceneAssetFiles.includes(file));
export const imageAssetsByKey = Object.fromEntries(assetCatalog.map((asset) => [asset.key, asset.file]));
export const assetCatalogByKey = Object.fromEntries(assetCatalog.map((asset) => [asset.key, asset]));
export const assetCatalogByFile = Object.fromEntries(assetCatalog.map((asset) => [asset.file, asset]));

function sceneAsset(key, file) {
  return { key, file, kind: "scene", transparent: false };
}

function transparentAsset(key, file, kind) {
  return { key, file, kind, transparent: true };
}

export function rewardAssetKey(rewardId) {
  return rewardId.replaceAll("_", "-");
}

export function rewardAssetFile(rewardId) {
  return `${rewardAssetKey(rewardId)}.png`;
}
