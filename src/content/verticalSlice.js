export const verticalSliceTaskIds = [
  "task_eng_g3b_u01_main",
  "task_eng_g3b_u02_main",
  "task_eng_g3b_u03_main"
];

export const verticalSliceGoal = {
  title: "第一章试玩切片：钟塔醒来",
  subtitle: "10 分钟体验目标",
  openingTitle: "故事钟塔暗了",
  openingCopy: "钟塔第一圈星路失去了光。先帮小镇伙伴找回 3 个星片，让小镇门口、作息铃和天气台重新亮起来。",
  playerRole: "你是星路修复员",
  chapterRewardTitle: "第一圈星路",
  chapterRewardCopy: "问候星片、小闹钟装饰和天气贴纸已经回到钟塔。第一圈星路点亮后，校园星门会作为下一章目标出现。",
  completionTitle: "第一圈星路点亮",
  completionCopy: "这段试玩切片完成了。孩子应该能说出：我在帮星光小镇修复钟塔，我拿到了 3 个星片，小镇亮了一圈。",
  nextStepCopy: "下一轮开发再把这个体验模板扩展到完整第一章 10 关。"
};

export const verticalSliceTaskBeats = {
  task_eng_g3b_u01_main: {
    storySetup: "小镇门口的问候星片掉进邮局书房，新朋友还不知道该怎么和你打招呼。",
    playerAction: "完成见面礼，帮 Mina 和 Coco 认出自然的问候回应。",
    successResult: "问候星片回到钟塔，小镇门口亮起第一束光。",
    rewardUse: "点亮钟塔第一圈的第 1 格，并把问候星片放进收藏册。",
    worldChange: "小镇门口恢复欢迎光，伙伴开始叫你星路修复员。"
  },
  task_eng_g3b_u02_main: {
    storySetup: "钟塔的作息铃慢了一拍，Mina 可能错过上学和睡前提醒。",
    playerAction: "看懂时间表达，帮 Mina 把一天里的提醒排回正确顺序。",
    successResult: "小闹钟装饰回到钟塔，作息铃重新响起。",
    rewardUse: "点亮钟塔第一圈的第 2 格，并让小镇日程恢复节奏。",
    worldChange: "钟塔出现清亮铃声，下一站指向天气台。"
  },
  task_eng_g3b_u03_main: {
    storySetup: "欢迎会要开始了，但天气台没有亮，大家不知道该穿什么出门。",
    playerAction: "识别天气表达，帮伙伴选择合适的出门准备。",
    successResult: "天气贴纸回到钟塔，欢迎会可以继续准备。",
    rewardUse: "点亮钟塔第一圈的第 3 格，完成本次 10 分钟试玩切片。",
    worldChange: "第一圈星路点亮，校园星门在远处出现。"
  }
};

export function isVerticalSliceTask(taskId) {
  return verticalSliceTaskIds.includes(taskId);
}

export function isVerticalSliceComplete(progress) {
  const completed = new Set(progress.completedTaskIds || []);
  return verticalSliceTaskIds.every((taskId) => completed.has(taskId));
}

export function getVerticalSliceCompletedCount(progress) {
  const completed = new Set(progress.completedTaskIds || []);
  return verticalSliceTaskIds.filter((taskId) => completed.has(taskId)).length;
}
