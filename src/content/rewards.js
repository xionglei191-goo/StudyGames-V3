import { englishStoryRewardConfigs } from "./englishStoryRewards.js";

const handcraftedRewardConfigs = [
  { id: "reward_star", type: "star", title: "星星", description: "小镇委托完成标记。", visibleToChild: true },
  { id: "reward_heart", type: "heart", title: "爱心", description: "角色开心的小反馈。", visibleToChild: true },
  { id: "reward_outfit_001", type: "outfit", title: "花园蝴蝶结", description: "完成搭配后解锁的发饰。", asset: "outfit_garden_bow", visibleToChild: true },
  { id: "reward_outfit_002", type: "outfit", title: "点心围裙", description: "厨房任务解锁的小围裙。", asset: "outfit_apron", visibleToChild: true },
  { id: "reward_decoration_001", type: "decoration", title: "整理好的衣物篮", description: "衣帽间多了一组收好的配饰。", visibleToChild: true },
  { id: "reward_decoration_002", type: "decoration", title: "小蛋糕摆件", description: "厨房台面多了一份甜甜的装饰。", visibleToChild: true },
  { id: "reward_album_001", type: "album", title: "小镇相册", description: "记录读信找到的朋友。", visibleToChild: true },
  { id: "reward_eng_g3b_u01_star", type: "decoration", title: "问候星片", description: "三年级下册 Unit 1 的问候表达星片。", visibleToChild: true },
  { id: "reward_eng_g3b_u02_star", type: "decoration", title: "小闹钟装饰", description: "三年级下册 Unit 2 的时间表达星片。", visibleToChild: true },
  { id: "reward_eng_g3b_u03_star", type: "decoration", title: "天气贴纸", description: "三年级下册 Unit 3 的天气表达星片。", visibleToChild: true },
  { id: "reward_eng_g3b_u04_star", type: "outfit", title: "派对服饰", description: "三年级下册 Unit 4 的服饰与喜好星片。", asset: "outfit_garden_bow", visibleToChild: true },
  { id: "reward_eng_g3b_u05_star", type: "decoration", title: "风筝星片", description: "三年级下册 Unit 5 的数量与清点星片。", visibleToChild: true },
  { id: "reward_eng_g3b_u06_star", type: "decoration", title: "果蔬篮", description: "三年级下册 Unit 6 的 There be 与食物星片。", visibleToChild: true },
  { id: "reward_eng_g3b_u07_star", type: "decoration", title: "洗手星片", description: "三年级下册 Unit 7 的清洁与睡前卫生星片。", visibleToChild: true },
  { id: "reward_eng_g3b_u08_star", type: "decoration", title: "儿童节星片", description: "三年级下册 Unit 8 的节日活动星片。", visibleToChild: true },
  { id: "reward_eng_g3b_u09_star", type: "decoration", title: "交通星片", description: "三年级下册 Unit 9 的交通方式星片。", visibleToChild: true },
  { id: "reward_eng_g3b_u10_star", type: "decoration", title: "职业星片", description: "三年级下册 Unit 10 的职业判断星片。", visibleToChild: true },
  { id: "reward_eng_g4a_u01_star", type: "decoration", title: "校园地图", description: "四年级上册 Unit 1 的校园地点导览星片。", visibleToChild: true },
  { id: "reward_eng_g4a_u02_star", type: "decoration", title: "作息钟", description: "四年级上册 Unit 2 的作息时间星片。", visibleToChild: true },
  { id: "reward_eng_g4a_u03_star", type: "decoration", title: "午餐贴纸", description: "四年级上册 Unit 3 的午餐喜好星片。", visibleToChild: true },
  { id: "reward_eng_g4a_u04_star", type: "album", title: "动物相册", description: "四年级上册 Unit 4 的动物观察相册页。", visibleToChild: true },
  { id: "reward_eng_g4a_u05_star", type: "outfit", title: "运动发带", description: "四年级上册 Unit 5 的运动能力奖励。", asset: "outfit_sunny", visibleToChild: true },
  { id: "reward_eng_g4a_u06_star", type: "decoration", title: "花园种子", description: "四年级上册 Unit 6 的 these/those 星片。", visibleToChild: true },
  { id: "reward_eng_g4a_u07_star", type: "decoration", title: "小钥匙", description: "四年级上册 Unit 7 的物品归属星片。", visibleToChild: true },
  { id: "reward_eng_g4a_u08_star", type: "decoration", title: "安静书签", description: "四年级上册 Unit 8 的图书馆规则星片。", visibleToChild: true },
  { id: "reward_eng_g4a_u09_star", type: "decoration", title: "小房间装饰", description: "四年级上册 Unit 9 的家庭房间星片。", visibleToChild: true },
  { id: "reward_eng_g4a_u10_star", type: "album", title: "职业相册页", description: "四年级上册 Unit 10 的家庭职业相册页。", visibleToChild: true },
  { id: "reward_eng_g4b_u01_star", type: "decoration", title: "位置星片", description: "四年级下册 Unit 1 的物品方位星片。", visibleToChild: true },
  { id: "reward_eng_g4b_u02_star", type: "decoration", title: "课程贴纸", description: "四年级下册 Unit 2 的课程与科目星片。", visibleToChild: true },
  { id: "reward_eng_g4b_u03_star", type: "decoration", title: "周历装饰", description: "四年级下册 Unit 3 的星期与活动计划星片。", visibleToChild: true },
  { id: "reward_eng_g4b_u04_star", type: "decoration", title: "计分牌", description: "四年级下册 Unit 4 的比赛分数和数字星片。", visibleToChild: true },
  { id: "reward_eng_g4b_u05_star", type: "decoration", title: "帮助者徽章", description: "四年级下册 Unit 5 的帮助者墙报星片。", visibleToChild: true },
  { id: "reward_eng_g4b_u06_star", type: "outfit", title: "四季花环", description: "四年级下册 Unit 6 的四季换装奖励。", asset: "outfit_cozy", visibleToChild: true },
  { id: "reward_eng_g4b_u07_star", type: "decoration", title: "云朵卡", description: "四年级下册 Unit 7 的风景观察星片。", visibleToChild: true },
  { id: "reward_eng_g4b_u08_star", type: "decoration", title: "清洁贴纸", description: "四年级下册 Unit 8 的现在进行时和清洁行动星片。", visibleToChild: true },
  { id: "reward_eng_g4b_u09_star", type: "decoration", title: "龙舟装饰", description: "四年级下册 Unit 9 的端午活动星片。", visibleToChild: true },
  { id: "reward_eng_g4b_u10_star", type: "decoration", title: "安全标志牌", description: "四年级下册 Unit 10 的安全标志星片。", visibleToChild: true },
  { id: "reward_eng_g5a_u01_star", type: "album", title: "人物素描卡", description: "五年级上册 Unit 1 的外貌描述相册页。", visibleToChild: true },
  { id: "reward_eng_g5a_u02_star", type: "decoration", title: "餐厅菜单", description: "五年级上册 Unit 2 的餐厅点餐星片。", visibleToChild: true },
  { id: "reward_eng_g5a_u03_star", type: "decoration", title: "午餐碗", description: "五年级上册 Unit 3 的午餐选择星片。", visibleToChild: true },
  { id: "reward_eng_g5a_u04_star", type: "decoration", title: "文具盒", description: "五年级上册 Unit 4 的借用文具星片。", visibleToChild: true },
  { id: "reward_eng_g5a_u05_star", type: "decoration", title: "宠物名牌", description: "五年级上册 Unit 5 的宠物请求星片。", visibleToChild: true },
  { id: "reward_eng_g5a_u06_star", type: "outfit", title: "雨衣", description: "五年级上册 Unit 6 的衣物比较选择奖励。", asset: "outfit_cozy", visibleToChild: true },
  { id: "reward_eng_g5a_u07_star", type: "decoration", title: "采访本", description: "五年级上册 Unit 7 的作息采访星片。", visibleToChild: true },
  { id: "reward_eng_g5a_u08_star", type: "decoration", title: "家务徽章", description: "五年级上册 Unit 8 的家务帮助星片。", visibleToChild: true },
  { id: "reward_eng_g5a_u09_star", type: "album", title: "收藏册", description: "五年级上册 Unit 9 的兴趣爱好相册页。", visibleToChild: true },
  { id: "reward_eng_g5a_u10_star", type: "decoration", title: "小巡查证", description: "五年级上册 Unit 10 的公共标志星片。", visibleToChild: true },
  { id: "reward_eng_g5a_u11_star", type: "decoration", title: "和好贴纸", description: "五年级上册 Unit 11 的道歉与情绪星片。", visibleToChild: true },
  { id: "reward_eng_g5a_u12_star", type: "decoration", title: "红灯笼", description: "五年级上册 Unit 12 的春节与复习星片。", visibleToChild: true }
];

const handcraftedRewardIds = new Set(handcraftedRewardConfigs.map((reward) => reward.id));
const generatedRuntimeRewardConfigs = englishStoryRewardConfigs
  .filter((reward) => !handcraftedRewardIds.has(reward.id))
  .map((reward) => ({
    id: reward.id,
    type: rewardTypeFor(reward.title),
    title: reward.title,
    description: reward.description,
    asset: rewardAssetFor(reward.title),
    visibleToChild: true
  }))
  .map((reward) => {
    if (!reward.asset) {
      const { asset, ...rest } = reward;
      return rest;
    }
    return reward;
  });

export const rewardConfigs = [...handcraftedRewardConfigs, ...generatedRuntimeRewardConfigs];
export const rewardsById = Object.fromEntries(rewardConfigs.map((reward) => [reward.id, reward]));

function rewardTypeFor(title) {
  if (/服|彩灯|彩带|手环|围裙|发带/.test(title)) return "outfit";
  if (/相册|书页|笔记|收藏|照片|相片|星图/.test(title)) return "album";
  return "decoration";
}

function rewardAssetFor(title) {
  if (/服|彩灯|彩带/.test(title)) return "outfit_garden_bow";
  if (/手环|发带/.test(title)) return "outfit_sunny";
  return null;
}
