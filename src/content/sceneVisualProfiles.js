export const sceneVisualProfiles = {
  scene_wardrobe: {
    centerpieces: [
      visual("scene-large-wardrobe-rack", 190, 354, 180, 168, "服饰展示架", "服饰卡都挂好了"),
      visual("scene-large-wardrobe-mirror", 506, 324, 150, 178, "搭配镜", "镜子前可以试搭配"),
      visual("scene-large-wardrobe-bench", 764, 420, 178, 132, "配饰长凳", "小配饰收在篮子里")
    ],
    rewardDisplay: visual("scene-large-wardrobe-reward-wall", 820, 194, 178, 142, "奖励衣物墙", "服饰星片挂上去了"),
    rewardSlots: [
      [768, 166], [816, 160], [864, 168], [780, 218], [832, 214], [884, 222]
    ]
  },
  scene_kitchen: {
    centerpieces: [
      visual("scene-large-kitchen-counter", 220, 402, 212, 150, "料理台", "食材已经摆好"),
      visual("scene-large-kitchen-recipe-board", 516, 306, 170, 148, "步骤菜谱板", "步骤卡可以排顺序"),
      visual("scene-large-kitchen-prep-station", 754, 398, 190, 148, "烤箱准备区", "计时器和量杯准备好了")
    ],
    rewardDisplay: visual("scene-large-kitchen-reward-table", 598, 462, 180, 118, "点心展示台", "奖励点心放上去了"),
    rewardSlots: [
      [542, 430], [586, 424], [630, 432], [560, 476], [604, 470], [648, 478]
    ]
  },
  scene_school: {
    centerpieces: [
      visual("scene-large-school-board", 206, 310, 180, 150, "课程公告板", "课程图标亮起来"),
      visual("scene-large-school-library", 518, 392, 192, 154, "图书角", "阅读角整理好了"),
      visual("scene-large-school-playground", 786, 404, 186, 134, "操场活动站", "运动道具排好了")
    ],
    rewardDisplay: visual("scene-large-school-task-wall", 778, 194, 178, 134, "校园任务墙", "校园奖励贴上去了"),
    rewardSlots: [
      [730, 166], [778, 160], [826, 168], [744, 212], [792, 206], [840, 214]
    ]
  },
  scene_city: {
    centerpieces: [
      visual("scene-large-city-bus-stop", 170, 410, 172, 128, "车站路线点", "下一站路线确认"),
      visual("scene-large-city-route-sign", 506, 318, 158, 128, "交通路线牌", "交通方式都在这里"),
      visual("scene-large-city-interview-station", 742, 420, 150, 114, "职业采访站", "采访卡准备好了")
    ],
    rewardDisplay: visual("scene-large-city-sign-rack", 810, 202, 170, 138, "公共标志架", "街区奖励贴上去了"),
    rewardSlots: [
      [766, 176], [812, 168], [858, 176], [778, 220], [824, 214], [870, 222]
    ]
  },
  scene_festival: {
    centerpieces: [
      visual("scene-large-festival-stage", 220, 378, 200, 154, "活动舞台", "表演道具准备好"),
      visual("scene-large-festival-craft-table", 524, 430, 196, 130, "手作桌", "手作材料摆好了"),
      visual("scene-large-festival-calendar-wall", 804, 292, 170, 150, "节日日历墙", "节日图标亮起来")
    ],
    rewardDisplay: visual("scene-large-festival-reward-garland", 534, 174, 214, 126, "派对彩带架", "节日奖励挂起来"),
    rewardSlots: [
      [468, 150], [514, 142], [560, 150], [492, 196], [538, 188], [584, 196]
    ]
  },
  scene_nature: {
    centerpieces: [
      visual("scene-large-nature-weather-station", 206, 302, 178, 146, "天气观察台", "天气图标排好了"),
      visual("scene-large-nature-garden-bed", 500, 430, 220, 130, "花园前景", "花园线索冒出来"),
      visual("scene-large-nature-globe-table", 794, 368, 176, 150, "地球星图台", "星图转到新地点")
    ],
    rewardDisplay: visual("scene-large-nature-reward-stand", 812, 184, 166, 132, "自然奖励架", "自然星片放上去"),
    rewardSlots: [
      [768, 160], [812, 154], [856, 162], [780, 206], [824, 198], [868, 206]
    ]
  },
  scene_health: {
    centerpieces: [
      visual("scene-large-health-sink-station", 198, 396, 190, 150, "洗手步骤台", "清洁步骤准备好"),
      visual("scene-large-health-habit-board", 514, 302, 178, 150, "健康习惯板", "习惯图标排好了"),
      visual("scene-large-health-care-kit", 804, 398, 176, 140, "医护包展示区", "照顾卡准备好了")
    ],
    rewardDisplay: visual("scene-large-health-routine-shelf", 526, 454, 174, 126, "清洁奖励架", "健康奖励收好了"),
    rewardSlots: [
      [478, 426], [522, 420], [566, 428], [490, 470], [534, 464], [578, 472]
    ]
  },
  scene_study: {
    centerpieces: [
      visual("scene-large-study-mail-table", 286, 414, 202, 142, "信件工作台", "信件线索排好路线"),
      visual("scene-large-study-album-shelf", 668, 394, 206, 152, "故事相册架", "相册页翻开了"),
      visual("scene-large-study-research-wall", 814, 204, 170, 142, "研究资料墙", "研究卡片收好了")
    ],
    rewardDisplay: visual("scene-large-study-album-shelf", 786, 414, 168, 122, "书房奖励架", "故事奖励摆上去"),
    rewardSlots: [
      [736, 382], [780, 376], [824, 384], [748, 426], [792, 420], [836, 428]
    ]
  }
};

function visual(image, x, y, width, height, label, microCopy) {
  return { image, x, y, width, height, label, microCopy };
}
