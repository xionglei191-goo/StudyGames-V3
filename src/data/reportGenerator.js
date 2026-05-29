import { knowledgeById } from "../content/knowledge.js";
import { englishStoryContentChapterRows, englishStoryContentRows } from "../content/englishStoryContentTable.js";
import { sceneConfigs, scenesById } from "../content/scenes.js";
import { taskConfigs } from "../content/tasks.js";
import { getSubjectLabel } from "./progressStore.js";

export function generateParentReport(progress, telemetry) {
  const completedTaskIds = new Set(progress.completedTaskIds || []);
  const completedTasks = taskConfigs.filter((task) => completedTaskIds.has(task.id));
  const completedStoryRows = englishStoryContentRows.filter((row) => completedTaskIds.has(row.taskId));
  const currentStoryRow = englishStoryContentRows.find((row) => row.taskId === progress.activeTaskId) ||
    englishStoryContentRows.find((row) => !completedTaskIds.has(row.taskId)) ||
    null;
  const sceneCounts = completedTasks.reduce((result, task) => {
    const scene = scenesById[task.sceneId];
    result[scene.title] = (result[scene.title] || 0) + 1;
    return result;
  }, {});

  const subjectCounts = completedTasks.reduce((result, task) => {
    task.subjectMix.forEach((subject) => {
      const label = getSubjectLabel(subject);
      result[label] = (result[label] || 0) + 1;
    });
    return result;
  }, {});

  const masteryItems = Object.values(progress.knowledgeMastery || {})
    .map((item) => ({ ...item, config: knowledgeById[item.knowledgeId] }))
    .filter((item) => item.config);

  const needsReview = masteryItems
    .filter((item) => item.status === "learning" || item.status === "review" || item.hintCount > 0)
    .slice(0, 4);

  const sceneList = Object.entries(sceneCounts).map(([label, count]) => `${label} ${count} 次`);
  const subjectList = Object.entries(subjectCounts).map(([label, count]) => `${label} ${count} 次`);
  const mistakeCount = telemetry.filter((event) => event.type === "mistake_made").length;
  const hintCount = telemetry.filter((event) => event.type === "hint_used").length;
  const chapterProgress = englishStoryContentChapterRows.map((chapter) => {
    const rows = englishStoryContentRows.filter((row) => row.chapterId === chapter.id);
    const completed = rows.filter((row) => completedTaskIds.has(row.taskId)).length;
    const active = currentStoryRow?.chapterId === chapter.id && completed < rows.length;
    return {
      id: chapter.id,
      title: chapter.title,
      bookTitle: chapter.bookTitle,
      theme: chapter.theme,
      completed,
      total: rows.length,
      percent: Math.round((completed / rows.length) * 100),
      status: completed === rows.length ? "done" : active || completed > 0 ? "current" : "locked"
    };
  });
  const recentCompleted = [...completedStoryRows].slice(-3).reverse();

  return {
    completedCount: completedTasks.length,
    totalStoryTasks: englishStoryContentRows.length,
    storyProgressPercent: Math.round((completedStoryRows.length / englishStoryContentRows.length) * 100),
    currentStoryRow,
    chapterProgress,
    recentCompleted,
    sceneSummary: sceneList.length ? sceneList.join("，") : "还没有完成场景任务",
    subjectSummary: subjectList.length ? subjectList.join("，") : "还没有学习记录",
    masteryItems,
    needsReview,
    mistakeCount,
    hintCount,
    suggestions: buildSuggestions(needsReview),
    allScenes: sceneConfigs.filter((scene) => scene.id !== "scene_town")
  };
}

function buildSuggestions(needsReview) {
  if (!needsReview.length) {
    return ["下次共玩时，可以请孩子讲一讲当前章节里最喜欢的小镇任务。"];
  }

  return needsReview.slice(0, 3).map((item) => {
    const subject = getSubjectLabel(item.config.subject);
    return `${subject}：用 2 分钟回看一次“${item.config.childVisibleLabel}”，让孩子说出一个游戏里见过的例子。`;
  });
}
