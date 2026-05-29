import { knowledgeConfigs } from "./knowledge.js";
import { rewardConfigs } from "./rewards.js";
import { sceneConfigs } from "./scenes.js";
import { taskConfigs } from "./tasks.js";
import { englishCorpusBooks, englishCorpusRawLines, englishCorpusSentences, englishCorpusStats, englishCorpusVocabulary } from "./englishCorpus.js";
import { englishChapterConfigs } from "./englishChapters.js";
import { englishStoryKnowledgeConfigs } from "./englishStoryKnowledge.js";
import { englishStoryRewardConfigs } from "./englishStoryRewards.js";
import { englishStoryTaskConfigs } from "./englishStoryTasks.js";
import {
  englishStoryContentChapterRows,
  englishStoryContentKnowledgeRows,
  englishStoryContentRewardRows,
  englishStoryContentRows,
  englishStoryContentTaskRows,
  englishStoryContentTables,
  englishStoryContentUnitRows
} from "./englishStoryContentTable.js";
import { englishUnitConfigs } from "./englishUnits.js";

export function validateContent() {
  const issues = [];
  const sceneIds = new Set(sceneConfigs.map((scene) => scene.id));
  const anchorIds = new Set(sceneConfigs.flatMap((scene) => scene.anchors.map((anchor) => anchor.id)));
  const knowledgeIds = new Set(knowledgeConfigs.map((knowledge) => knowledge.id));
  const rewardIds = new Set(rewardConfigs.map((reward) => reward.id));
  const vocabularyIds = new Set(englishCorpusVocabulary.map((item) => item.id));
  const sentenceIds = new Set(englishCorpusSentences.map((item) => item.id));
  const rawLineIds = new Set(englishCorpusRawLines.map((item) => item.id));

  if (englishCorpusBooks.length !== 7) issues.push("english corpus: expected 7 source books");
  if (englishCorpusRawLines.length < 2000) issues.push("english corpus: raw lines look incomplete");
  if (englishCorpusVocabulary.length < 500) issues.push("english corpus: vocabulary coverage looks incomplete");
  if (englishCorpusSentences.length < 500) issues.push("english corpus: sentence coverage looks incomplete");
  if (englishCorpusStats.rawLines !== englishCorpusRawLines.length) issues.push("english corpus: raw line stats mismatch");
  if (englishCorpusStats.vocabulary !== englishCorpusVocabulary.length) issues.push("english corpus: vocabulary stats mismatch");
  if (englishCorpusStats.sentences !== englishCorpusSentences.length) issues.push("english corpus: sentence stats mismatch");
  if (englishChapterConfigs.length !== 7) issues.push("english story config: expected 7 chapters");
  if (englishUnitConfigs.length !== 75) issues.push("english story config: expected 75 units");
  if (englishStoryKnowledgeConfigs.length !== 75) issues.push("english story config: expected 75 knowledge configs");
  if (englishStoryTaskConfigs.length !== 75) issues.push("english story config: expected 75 task configs");
  if (englishStoryRewardConfigs.length !== 75) issues.push("english story config: expected 75 reward configs");
  if (englishStoryContentRows.length !== 75) issues.push("english story config: expected 75 content table rows");
  if (englishStoryContentChapterRows.length !== 7) issues.push("english story content table: expected 7 chapter rows");
  if (englishStoryContentUnitRows.length !== 75) issues.push("english story content table: expected 75 unit rows");
  if (englishStoryContentTaskRows.length !== 75) issues.push("english story content table: expected 75 task rows");
  if (englishStoryContentKnowledgeRows.length !== 75) issues.push("english story content table: expected 75 knowledge rows");
  if (englishStoryContentRewardRows.length !== 75) issues.push("english story content table: expected 75 reward rows");
  if (
    englishStoryContentTables.chapters !== englishStoryContentChapterRows ||
    englishStoryContentTables.units !== englishStoryContentUnitRows ||
    englishStoryContentTables.tasks !== englishStoryContentTaskRows ||
    englishStoryContentTables.knowledge !== englishStoryContentKnowledgeRows ||
    englishStoryContentTables.rewards !== englishStoryContentRewardRows ||
    englishStoryContentTables.rows !== englishStoryContentRows
  ) {
    issues.push("english story content table: grouped exports should reference split tables");
  }
  const linkedRawLineIds = new Set([
    ...englishUnitConfigs.flatMap((unit) => unit.rawLineIds),
    ...englishChapterConfigs.flatMap((chapter) => chapter.overviewRawLineIds)
  ]);
  const linkedVocabularyIds = new Set([
    ...englishUnitConfigs.flatMap((unit) => unit.corpusVocabularyIds),
    ...englishChapterConfigs.flatMap((chapter) => chapter.overviewCorpusVocabularyIds)
  ]);
  const linkedSentenceIds = new Set([
    ...englishUnitConfigs.flatMap((unit) => unit.corpusSentenceIds),
    ...englishChapterConfigs.flatMap((chapter) => chapter.overviewCorpusSentenceIds)
  ]);
  englishCorpusRawLines.forEach((item) => {
    if (!linkedRawLineIds.has(item.id)) issues.push(`english story config: raw line not linked ${item.id}`);
  });
  englishCorpusVocabulary.forEach((item) => {
    if (!linkedVocabularyIds.has(item.id)) issues.push(`english story config: vocabulary not linked ${item.id}`);
  });
  englishCorpusSentences.forEach((item) => {
    if (!linkedSentenceIds.has(item.id)) issues.push(`english story config: sentence not linked ${item.id}`);
  });

  const expectedMainTaskIds = [
    ...Array.from({ length: 10 }, (_, index) => `task_eng_g3b_u${String(index + 1).padStart(2, "0")}_main`),
    ...Array.from({ length: 10 }, (_, index) => `task_eng_g4a_u${String(index + 1).padStart(2, "0")}_main`),
    ...Array.from({ length: 10 }, (_, index) => `task_eng_g4b_u${String(index + 1).padStart(2, "0")}_main`),
    ...Array.from({ length: 12 }, (_, index) => `task_eng_g5a_u${String(index + 1).padStart(2, "0")}_main`),
    ...Array.from({ length: 12 }, (_, index) => `task_eng_g5b_u${String(index + 1).padStart(2, "0")}_main`),
    ...Array.from({ length: 12 }, (_, index) => `task_eng_g6a_u${String(index + 1).padStart(2, "0")}_main`),
    ...Array.from({ length: 9 }, (_, index) => `task_eng_g6b_u${String(index + 1).padStart(2, "0")}_main`)
  ];
  const mainTaskIds = taskConfigs.map((task) => task.id);
  if (JSON.stringify(mainTaskIds) !== JSON.stringify(expectedMainTaskIds)) {
    issues.push("english story config: expected playable main flow to cover all 75 story units in order");
  }

  const chapterConfigIds = new Set(englishChapterConfigs.map((chapter) => chapter.id));
  const unitConfigIds = new Set(englishUnitConfigs.map((unit) => unit.id));
  const storyTaskConfigIds = new Set(englishStoryTaskConfigs.map((task) => task.id));
  const storyKnowledgeConfigIds = new Set(englishStoryKnowledgeConfigs.map((item) => item.id));
  const storyRewardConfigIds = new Set(englishStoryRewardConfigs.map((item) => item.id));
  const contentRowsByTaskId = new Map(englishStoryContentRows.map((row) => [row.taskId, row]));
  const contentRowsById = new Map(englishStoryContentRows.map((row) => [row.id, row]));
  const contentChapterRowsById = new Map(englishStoryContentChapterRows.map((row) => [row.id, row]));
  const contentUnitRowsById = new Map(englishStoryContentUnitRows.map((row) => [row.id, row]));
  const contentTaskRowsById = new Map(englishStoryContentTaskRows.map((row) => [row.id, row]));
  const contentKnowledgeRowsById = new Map(englishStoryContentKnowledgeRows.map((row) => [row.id, row]));
  const contentRewardRowsById = new Map(englishStoryContentRewardRows.map((row) => [row.id, row]));
  const expectedContentRowIds = expectedMainTaskIds.map((taskId) => taskId.replace(/^task_eng_/, "row_eng_").replace(/_main$/, ""));
  if (JSON.stringify(englishStoryContentRows.map((row) => row.id)) !== JSON.stringify(expectedContentRowIds)) {
    issues.push("english story config: content table rows should follow the playable main flow order");
  }

  const contentTableRawLineIds = new Set([
    ...englishStoryContentUnitRows.flatMap((row) => row.rawLineIds),
    ...englishStoryContentChapterRows.flatMap((row) => row.overviewRawLineIds)
  ]);
  const contentTableVocabularyIds = new Set([
    ...englishStoryContentUnitRows.flatMap((row) => row.corpusVocabularyIds),
    ...englishStoryContentChapterRows.flatMap((row) => row.overviewCorpusVocabularyIds)
  ]);
  const contentTableSentenceIds = new Set([
    ...englishStoryContentUnitRows.flatMap((row) => row.corpusSentenceIds),
    ...englishStoryContentChapterRows.flatMap((row) => row.overviewCorpusSentenceIds)
  ]);
  englishCorpusRawLines.forEach((item) => {
    if (!contentTableRawLineIds.has(item.id)) issues.push(`english story content table: raw line not linked ${item.id}`);
  });
  englishCorpusVocabulary.forEach((item) => {
    if (!contentTableVocabularyIds.has(item.id)) issues.push(`english story content table: vocabulary not linked ${item.id}`);
  });
  englishCorpusSentences.forEach((item) => {
    if (!contentTableSentenceIds.has(item.id)) issues.push(`english story content table: sentence not linked ${item.id}`);
  });

  englishChapterConfigs.forEach((chapter) => {
    const chapterRow = contentChapterRowsById.get(chapter.id);
    if (!chapter.summaryForParent) issues.push(`${chapter.id}: missing parent summary`);
    if (!chapter.mapRegion) issues.push(`${chapter.id}: missing map region`);
    if (chapter.unitCount !== chapter.unitIds?.length) issues.push(`${chapter.id}: unit count mismatch`);
    if (chapter.playableTaskIds?.length !== chapter.unitCount) issues.push(`${chapter.id}: playable task count mismatch`);
    if (chapter.contentTableRowIds?.length !== chapter.unitCount) issues.push(`${chapter.id}: content table row count mismatch`);
    if (!chapterRow) issues.push(`${chapter.id}: missing split chapter row`);
    if (chapterRow) {
      if (chapterRow.rowType !== "chapter") issues.push(`${chapter.id}: chapter row type mismatch`);
      if (chapterRow.unitCount !== chapter.unitCount) issues.push(`${chapter.id}: split chapter unit count mismatch`);
      if (JSON.stringify(chapterRow.taskIds) !== JSON.stringify(chapter.playableTaskIds)) issues.push(`${chapter.id}: split chapter task ids mismatch`);
      if (chapterRow.coverage.rawLines !== chapter.coverageSummary.rawLines) issues.push(`${chapter.id}: split chapter coverage mismatch`);
      if (JSON.stringify(chapterRow.overviewRawLineIds) !== JSON.stringify(chapter.overviewRawLineIds)) issues.push(`${chapter.id}: split chapter overview raw lines mismatch`);
      if (JSON.stringify(chapterRow.overviewCorpusVocabularyIds) !== JSON.stringify(chapter.overviewCorpusVocabularyIds)) issues.push(`${chapter.id}: split chapter overview vocabulary mismatch`);
      if (JSON.stringify(chapterRow.overviewCorpusSentenceIds) !== JSON.stringify(chapter.overviewCorpusSentenceIds)) issues.push(`${chapter.id}: split chapter overview sentences mismatch`);
    }
  });

  englishStoryContentRows.forEach((row, index) => {
    const unit = englishUnitConfigs.find((item) => item.id === row.unitId);
    const storyTask = englishStoryTaskConfigs.find((item) => item.id === row.taskId);
    const knowledge = englishStoryKnowledgeConfigs.find((item) => item.id === row.knowledgeId);
    const reward = englishStoryRewardConfigs.find((item) => item.id === row.rewardId);
    const splitUnit = contentUnitRowsById.get(row.unitId);
    const splitTask = contentTaskRowsById.get(row.taskId);
    const splitKnowledge = contentKnowledgeRowsById.get(row.knowledgeId);
    const splitReward = contentRewardRowsById.get(row.rewardId);
    const expectedPreviousTaskId = index === 0 ? null : englishStoryContentRows[index - 1].taskId;
    const expectedNextTaskId = englishStoryContentRows[index + 1]?.taskId || null;

    if (!chapterConfigIds.has(row.chapterId)) issues.push(`${row.id}: missing chapter ${row.chapterId}`);
    if (!unitConfigIds.has(row.unitId)) issues.push(`${row.id}: missing unit ${row.unitId}`);
    if (!storyTaskConfigIds.has(row.taskId)) issues.push(`${row.id}: missing task ${row.taskId}`);
    if (!storyKnowledgeConfigIds.has(row.knowledgeId)) issues.push(`${row.id}: missing knowledge ${row.knowledgeId}`);
    if (!storyRewardConfigIds.has(row.rewardId)) issues.push(`${row.id}: missing reward ${row.rewardId}`);
    if (!splitUnit) issues.push(`${row.id}: missing split unit row`);
    if (!splitTask) issues.push(`${row.id}: missing split task row`);
    if (!splitKnowledge) issues.push(`${row.id}: missing split knowledge row`);
    if (!splitReward) issues.push(`${row.id}: missing split reward row`);
    if (!sceneIds.has(row.sceneId)) issues.push(`${row.id}: missing scene ${row.sceneId}`);
    if (row.runtimeStatus !== "handcrafted_playable") issues.push(`${row.id}: content row should be handcrafted playable`);
    if (!row.storyGoal || !row.parentOutcome) issues.push(`${row.id}: missing story goal or parent outcome`);
    if (!row.skillTags?.length || !row.grammarFocus || !row.reviewHooks?.length) issues.push(`${row.id}: missing learning metadata`);
    if (row.prerequisiteTaskIds?.[0] !== expectedPreviousTaskId && !(index === 0 && row.prerequisiteTaskIds?.length === 0)) {
      issues.push(`${row.id}: prerequisite task chain mismatch`);
    }
    if (row.nextTaskId !== expectedNextTaskId) issues.push(`${row.id}: next task chain mismatch`);
    if (unit) {
      if (unit.taskId !== row.taskId) issues.push(`${row.id}: unit task link mismatch`);
      if (unit.knowledgeId !== row.knowledgeId) issues.push(`${row.id}: unit knowledge link mismatch`);
      if (unit.rewardId !== row.rewardId) issues.push(`${row.id}: unit reward link mismatch`);
      if (unit.sceneId !== row.sceneId) issues.push(`${row.id}: unit scene link mismatch`);
    }
    if (splitUnit) {
      if (splitUnit.rowType !== "unit") issues.push(`${row.id}: split unit row type mismatch`);
      if (splitUnit.contentRowId !== row.id) issues.push(`${row.id}: split unit content row mismatch`);
      if (splitUnit.taskId !== row.taskId) issues.push(`${row.id}: split unit task link mismatch`);
      if (splitUnit.knowledgeId !== row.knowledgeId) issues.push(`${row.id}: split unit knowledge link mismatch`);
      if (splitUnit.rewardId !== row.rewardId) issues.push(`${row.id}: split unit reward link mismatch`);
      if (splitUnit.coverage.rawLines !== row.coverage.rawLines) issues.push(`${row.id}: split unit coverage mismatch`);
    }
    if (storyTask) {
      if (storyTask.unitId !== row.unitId) issues.push(`${row.id}: task unit link mismatch`);
      if (storyTask.knowledgeIds?.[0] !== row.knowledgeId) issues.push(`${row.id}: task knowledge link mismatch`);
      if (storyTask.rewardIds?.[0] !== row.rewardId) issues.push(`${row.id}: task reward link mismatch`);
      if (storyTask.runtimeStatus !== "handcrafted_playable") issues.push(`${row.id}: task runtime status mismatch`);
      if (storyTask.implementationStatus !== "handcrafted_playable") issues.push(`${row.id}: task implementation status mismatch`);
      if (!storyTask.acceptanceCriteria?.length) issues.push(`${row.id}: task missing acceptance criteria`);
    }
    if (splitTask) {
      if (splitTask.rowType !== "task") issues.push(`${row.id}: split task row type mismatch`);
      if (splitTask.contentRowId !== row.id) issues.push(`${row.id}: split task content row mismatch`);
      if (splitTask.unitId !== row.unitId) issues.push(`${row.id}: split task unit link mismatch`);
      if (splitTask.knowledgeIds?.[0] !== row.knowledgeId) issues.push(`${row.id}: split task knowledge link mismatch`);
      if (splitTask.rewardIds?.[0] !== row.rewardId) issues.push(`${row.id}: split task reward link mismatch`);
      if (splitTask.runtimeStatus !== "handcrafted_playable") issues.push(`${row.id}: split task runtime status mismatch`);
    }
    if (knowledge) {
      if (knowledge.unitId !== row.unitId) issues.push(`${row.id}: knowledge unit link mismatch`);
      if (knowledge.coverage?.rawLines !== row.coverage.rawLines) issues.push(`${row.id}: knowledge coverage mismatch`);
      if (!knowledge.exampleSentenceIds?.length || !knowledge.reviewStrategy) issues.push(`${row.id}: knowledge missing review metadata`);
    }
    if (splitKnowledge) {
      if (splitKnowledge.rowType !== "knowledge") issues.push(`${row.id}: split knowledge row type mismatch`);
      if (splitKnowledge.contentRowId !== row.id) issues.push(`${row.id}: split knowledge content row mismatch`);
      if (splitKnowledge.unitId !== row.unitId) issues.push(`${row.id}: split knowledge unit link mismatch`);
      if (splitKnowledge.coverage.rawLines !== row.coverage.rawLines) issues.push(`${row.id}: split knowledge coverage mismatch`);
    }
    if (reward) {
      if (reward.unitId !== row.unitId) issues.push(`${row.id}: reward unit link mismatch`);
      if (reward.linkedTaskId !== row.taskId) issues.push(`${row.id}: reward linked task mismatch`);
      if (reward.linkedKnowledgeId !== row.knowledgeId) issues.push(`${row.id}: reward linked knowledge mismatch`);
    }
    if (splitReward) {
      if (splitReward.rowType !== "reward") issues.push(`${row.id}: split reward row type mismatch`);
      if (splitReward.contentRowId !== row.id) issues.push(`${row.id}: split reward content row mismatch`);
      if (splitReward.linkedTaskId !== row.taskId) issues.push(`${row.id}: split reward linked task mismatch`);
      if (splitReward.linkedKnowledgeId !== row.knowledgeId) issues.push(`${row.id}: split reward linked knowledge mismatch`);
      if (splitReward.contentStatus !== "ready_to_grant") issues.push(`${row.id}: split reward status mismatch`);
    }
    if (row.coverage.rawLines !== row.rawLineIds?.length) issues.push(`${row.id}: raw line coverage count mismatch`);
    if (row.coverage.vocabulary !== row.corpusVocabularyIds?.length) issues.push(`${row.id}: vocabulary coverage count mismatch`);
    if (row.coverage.sentences !== row.corpusSentenceIds?.length) issues.push(`${row.id}: sentence coverage count mismatch`);
  });

  englishStoryContentUnitRows.forEach((row, index) => {
    const sourceRow = contentRowsById.get(row.contentRowId);
    if (!sourceRow) issues.push(`${row.id}: split unit points to missing content row`);
    if (row.previousUnitId !== (englishStoryContentUnitRows[index - 1]?.id || null)) issues.push(`${row.id}: split unit previous link mismatch`);
    if (row.nextUnitId !== (englishStoryContentUnitRows[index + 1]?.id || null)) issues.push(`${row.id}: split unit next link mismatch`);
  });

  taskConfigs.forEach((task) => {
    const storyTask = englishStoryTaskConfigs.find((item) => item.id === task.id);
    const contentRow = contentRowsByTaskId.get(task.id);
    if (!sceneIds.has(task.sceneId)) issues.push(`${task.id}: missing scene ${task.sceneId}`);
    if (!task.steps?.length) issues.push(`${task.id}: missing steps`);
    if (!storyTask) issues.push(`${task.id}: missing generated story task config`);
    if (!contentRow) issues.push(`${task.id}: missing content table row`);
    if (contentRow && contentRow.runtimeStatus !== "handcrafted_playable") issues.push(`${task.id}: content row runtime status mismatch`);
    if (storyTask) {
      const missingTaskVocabularyIds = storyTask.corpusVocabularyIds.filter((id) => !task.corpusVocabularyIds?.includes(id));
      const missingTaskSentenceIds = storyTask.corpusSentenceIds.filter((id) => !task.corpusSentenceIds?.includes(id));
      const missingTaskRawLineIds = storyTask.rawLineIds.filter((id) => !task.rawLineIds?.includes(id));
      if (missingTaskVocabularyIds.length) issues.push(`${task.id}: missing top-level vocabulary coverage ${missingTaskVocabularyIds.join(",")}`);
      if (missingTaskSentenceIds.length) issues.push(`${task.id}: missing top-level sentence coverage ${missingTaskSentenceIds.join(",")}`);
      if (missingTaskRawLineIds.length) issues.push(`${task.id}: missing top-level raw line coverage ${missingTaskRawLineIds.join(",")}`);
    }
    task.corpusVocabularyIds?.forEach((id) => {
      if (!vocabularyIds.has(id)) issues.push(`${task.id}: missing corpus vocabulary ${id}`);
    });
    task.corpusSentenceIds?.forEach((id) => {
      if (!sentenceIds.has(id)) issues.push(`${task.id}: missing corpus sentence ${id}`);
    });
    task.rawLineIds?.forEach((id) => {
      if (!rawLineIds.has(id)) issues.push(`${task.id}: missing raw line ${id}`);
    });
    task.rewards?.forEach((grant) => {
      if (!rewardIds.has(grant.rewardId)) issues.push(`${task.id}: missing reward ${grant.rewardId}`);
    });
    task.steps?.forEach((step) => {
      if (!anchorIds.has(step.anchorId)) issues.push(`${task.id}/${step.id}: missing anchor ${step.anchorId}`);
      step.knowledgeIds?.forEach((knowledgeId) => {
        if (!knowledgeIds.has(knowledgeId)) issues.push(`${task.id}/${step.id}: missing knowledge ${knowledgeId}`);
      });
      step.corpusVocabularyIds?.forEach((id) => {
        if (!vocabularyIds.has(id)) issues.push(`${task.id}/${step.id}: missing corpus vocabulary ${id}`);
      });
      step.corpusSentenceIds?.forEach((id) => {
        if (!sentenceIds.has(id)) issues.push(`${task.id}/${step.id}: missing corpus sentence ${id}`);
      });
      step.correctOptionIds?.forEach((optionId) => {
        if (!step.options?.some((option) => option.id === optionId)) issues.push(`${task.id}/${step.id}: answer ${optionId} not in options`);
      });
    });
  });

  return issues;
}
