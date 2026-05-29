import { englishStoryKnowledgeConfigs } from "./englishStoryKnowledge.js";

const reviewPolicy = {
  firstReviewAfterHours: 24,
  secondReviewAfterHours: 24,
  stableReviewAfterHours: 72
};

const handcraftedKnowledgeConfigs = [
  ["kn_eng_g3_001", "english", "g3_4", "颜色词：pink / blue / yellow", ["vocabulary"], "能把常见颜色词和实际物品联系起来。", "颜色小线索", ["anchor_wardrobe_rack"]],
  ["kn_eng_g3_002", "english", "g3_4", "服饰词：dress / shoes / hat", ["vocabulary", "classification"], "能识别服饰类英语词，并按类别选择。", "衣服小线索", ["anchor_wardrobe_rack", "anchor_wardrobe_shoes"]],
  ["kn_eng_g3_003", "english", "g3_4", "位置词：on / under / next to", ["spatial", "vocabulary"], "能理解简单位置词，配合场景找到物品。", "位置小线索", ["anchor_study_map"]],
  ["kn_eng_g3_004", "english", "g3_4", "问候语：hello / thank you", ["vocabulary"], "能在生活情境中辨认基础问候表达。", "问候小卡片", ["anchor_study_bookshelf"]],
  ["kn_eng_g3_005", "english", "g3_4", "物品词：book / card / flower", ["vocabulary"], "能把物品英语词和图像、场景对应起来。", "物品小卡片", ["anchor_study_bookshelf"]],
  ["kn_eng_g3_006", "english", "g3_4", "描述词：big / small / clean", ["vocabulary"], "能理解常见描述词并用于选择。", "描述小线索", ["anchor_wardrobe_mirror"]],
  ["kn_math_g2_001", "math", "g1_2", "物品数量比较", ["quantity"], "能按配方要求比较和选择数量。", "数量小勺子", ["anchor_kitchen_cup"]],
  ["kn_math_g2_002", "math", "g1_2", "步骤顺序", ["sequence"], "能把生活步骤按合理顺序排列。", "步骤小贴纸", ["anchor_kitchen_oven"]],
  ["kn_math_g2_003", "math", "g1_2", "10 分钟、20 分钟等时间感", ["time"], "能把任务提示中的时间与计时器对应起来。", "时间小铃铛", ["anchor_kitchen_timer"]],
  ["kn_math_g3_004", "math", "g3_4", "一半和半杯", ["fraction"], "能理解半杯这样的简单分数表达。", "半杯小标记", ["anchor_kitchen_cup"]],
  ["kn_math_g3_005", "math", "g3_4", "容量多少比较", ["quantity", "fraction"], "能比较杯中容量多少并选择合适份量。", "容量小标记", ["anchor_kitchen_cup"]],
  ["kn_math_g3_006", "math", "g3_4", "按条件选择数量", ["quantity"], "能根据条件挑选指定数量的物品。", "数量小条件", ["anchor_kitchen_cup"]],
  ["kn_chi_g2_001", "chinese", "g1_2", "从短句中找人物", ["reading_clue"], "能从短句线索中找出人物。", "人物小线索", ["anchor_study_mailbox"]],
  ["kn_chi_g2_002", "chinese", "g1_2", "从短句中找地点", ["reading_clue", "spatial"], "能从短句线索中提取地点信息。", "地点小线索", ["anchor_study_map"]],
  ["kn_chi_g2_003", "chinese", "g1_2", "关键词线索", ["reading_clue"], "能抓住关键词帮助判断。", "关键词贴纸", ["anchor_study_mailbox"]],
  ["kn_chi_g3_004", "chinese", "g3_4", "近义描述词", ["classification"], "能理解相近描述词，并用于整理物品。", "描述词小夹子", ["anchor_wardrobe_mirror"]],
  ["kn_chi_g3_005", "chinese", "g3_4", "动作顺序复述", ["sequence"], "能根据动作词复述或排列步骤。", "动作顺序卡", ["anchor_kitchen_oven"]],
  ["kn_chi_g3_006", "chinese", "g3_4", "物品类别归纳", ["classification"], "能按用途或类别归纳物品。", "分类小标签", ["anchor_wardrobe_shoes"]],
  ["kn_eng_g3b_u01_core", "english", "g3_4", "三下 Unit 1：问候与身份确认", ["vocabulary", "reading_clue"], "能理解 How are you、I'm fine、Are you...? 等基础问候和身份确认表达。", "问候星片", ["anchor_study_mailbox", "anchor_study_bookshelf"]],
  ["kn_eng_g3b_u02_core", "english", "g3_4", "三下 Unit 2：时间与作息提醒", ["time", "vocabulary"], "能理解 What time is it、o'clock、It's time for... 等时间和作息表达。", "时间星片", ["anchor_kitchen_timer", "anchor_study_map"]],
  ["kn_eng_g3b_u03_core", "english", "g3_4", "三下 Unit 3：天气与感受", ["observation", "vocabulary"], "能识别 sunny、rainy、windy、cold 等天气词，并理解 What's the weather like? 的问答。", "天气星片", ["anchor_wardrobe_mirror", "anchor_study_map"]],
  ["kn_eng_g3b_u04_core", "english", "g3_4", "三下 Unit 4：服饰与喜好", ["vocabulary", "classification"], "能识别 dress、T-shirt、trousers 等服饰词，并使用 Do you like...? 表达喜好。", "服饰星片", ["anchor_wardrobe_rack", "anchor_wardrobe_mirror"]],
  ["kn_eng_g3b_u05_core", "english", "g3_4", "三下 Unit 5：数量与清点", ["quantity", "vocabulary"], "能理解 How many、17-20 等数量表达，并把数字和事物数量对应起来。", "风筝星片", ["anchor_study_map", "anchor_study_bookshelf"]],
  ["kn_eng_g3b_u06_core", "english", "g3_4", "三下 Unit 6：There be 与食物", ["vocabulary", "reading_clue"], "能理解 There is / There are 的存在表达，并识别常见食材词。", "果蔬篮", ["anchor_kitchen_cup", "anchor_kitchen_timer"]],
  ["kn_eng_g3b_u07_core", "english", "g3_4", "三下 Unit 7：洗手与睡前卫生", ["vocabulary", "sequence"], "能理解 wash、brush、clean、face、teeth、hair 等清洁词，并按洗手和睡前步骤排序。", "洗手星片", ["anchor_kitchen_cup", "anchor_kitchen_oven", "anchor_kitchen_timer"]],
  ["kn_eng_g3b_u08_core", "english", "g3_4", "三下 Unit 8：儿童节活动", ["vocabulary", "classification"], "能理解 sing、dance、draw、play、party、paint、watch 等活动词，并识别节日活动句。", "儿童节星片", ["anchor_study_bookshelf", "anchor_study_mailbox"]],
  ["kn_eng_g3b_u09_core", "english", "g3_4", "三下 Unit 9：交通方式", ["vocabulary", "spatial"], "能理解 bus、train、taxi、plane、bike、underground、on foot 等交通表达，并回答 How do you go there?。", "交通星片", ["anchor_study_map", "anchor_study_bookshelf", "anchor_study_mailbox"]],
  ["kn_eng_g3b_u10_core", "english", "g3_4", "三下 Unit 10：职业判断", ["vocabulary", "classification", "reading_clue"], "能理解 driver、farmer、worker、nurse、doctor、teacher、student 等职业词，并回答 Is she/he...?。", "职业星片", ["anchor_study_mailbox", "anchor_study_bookshelf", "anchor_study_map"]],
  ["kn_eng_g4a_u01_core", "english", "g3_4", "四上 Unit 1：校园地点导览", ["vocabulary", "spatial"], "能理解 classroom、playground、library、music room 等校园地点，并用 This is / That is 介绍学校。", "校园地图", ["anchor_study_map", "anchor_study_bookshelf", "anchor_study_mailbox"]],
  ["kn_eng_g4a_u02_core", "english", "g3_4", "四上 Unit 2：作息时间表达", ["time", "sequence"], "能理解 get up、breakfast、lunch、go to bed 等作息词，并回答 What time do you...?。", "作息钟", ["anchor_study_map", "anchor_study_bookshelf", "anchor_study_mailbox"]],
  ["kn_eng_g4a_u03_core", "english", "g3_4", "四上 Unit 3：午餐喜好", ["vocabulary", "classification"], "能理解 dumplings、vegetables、bread、hamburger 等食物词，并用 I like... 表达喜好。", "午餐贴纸", ["anchor_kitchen_cup", "anchor_kitchen_oven", "anchor_kitchen_timer"]],
  ["kn_eng_g4a_u04_core", "english", "g3_4", "四上 Unit 4：动物观察", ["vocabulary", "observation"], "能理解 elephant、lion、tiger、panda、monkey 等动物词和 big、tall、strong、cute 等描述词。", "动物相册", ["anchor_study_bookshelf", "anchor_study_map", "anchor_study_mailbox"]],
  ["kn_eng_g4a_u05_core", "english", "g3_4", "四上 Unit 5：运动能力", ["vocabulary", "classification"], "能理解 basketball、swim、football、ping-pong 等运动词，并用 Can you...? / I can... 表达能力。", "运动发带", ["anchor_study_map", "anchor_study_bookshelf", "anchor_study_mailbox"]],
  ["kn_eng_g4a_u06_core", "english", "g3_4", "四上 Unit 6：这些和那些", ["vocabulary", "spatial"], "能理解 these、those、flower、tree、bee、garden、hill、seed 等词，并分辨近处和远处的复数事物。", "花园种子", ["anchor_study_bookshelf", "anchor_study_map", "anchor_study_mailbox"]],
  ["kn_eng_g4a_u07_core", "english", "g3_4", "四上 Unit 7：物品归属", ["vocabulary", "reading_clue"], "能理解 whose、watch、bag、key、umbrella 等物品和归属表达，并回答 Whose...?。", "小钥匙", ["anchor_study_mailbox", "anchor_study_bookshelf", "anchor_study_map"]],
  ["kn_eng_g4a_u08_core", "english", "g3_4", "四上 Unit 8：图书馆和课堂规则", ["vocabulary", "classification"], "能理解 take、eat、late、litter、say 等规则相关词，并读懂 Don't talk/eat/write/litter。", "安静书签", ["anchor_study_bookshelf", "anchor_study_map", "anchor_study_mailbox"]],
  ["kn_eng_g4a_u09_core", "english", "g3_4", "四上 Unit 9：家庭房间介绍", ["vocabulary", "spatial"], "能理解 living room、kitchen、bedroom、chair、table、TV 等家庭空间词，并用 This is... 介绍房间。", "小房间装饰", ["anchor_study_mailbox", "anchor_study_map", "anchor_study_bookshelf"]],
  ["kn_eng_g4a_u10_core", "english", "g3_4", "四上 Unit 10：家庭职业相册", ["vocabulary", "classification", "reading_clue"], "能理解 job、photo、scientist、policeman、astronaut、fireman、policewoman 等职业词，并回答 What's his/her job?。", "职业相册页", ["anchor_study_bookshelf", "anchor_study_map", "anchor_study_mailbox"]],
  ["kn_eng_g4b_u01_core", "english", "g3_4", "四下 Unit 1：物品方位", ["spatial", "vocabulary"], "能理解 on、in、under、between、beside、behind 等方位词，并回答 Where's...?。", "位置星片", ["anchor_study_bookshelf", "anchor_study_map", "anchor_study_mailbox"]],
  ["kn_eng_g4b_u02_core", "english", "g3_4", "四下 Unit 2：课程与科目", ["vocabulary", "classification"], "能理解 English、maths、PE 等课程词，并回答 What classes / What subject...?。", "课程贴纸", ["anchor_study_bookshelf", "anchor_study_map", "anchor_study_mailbox"]],
  ["kn_eng_g4b_u03_core", "english", "g3_4", "四下 Unit 3：星期与活动计划", ["time", "sequence"], "能理解 today、tomorrow、Monday-Sunday 等时间词，并按星期安排活动。", "周历装饰", ["anchor_study_map", "anchor_study_bookshelf", "anchor_study_mailbox"]],
  ["kn_eng_g4b_u04_core", "english", "g3_4", "四下 Unit 4：分数和大数字", ["quantity", "vocabulary"], "能理解 point、twenty-one、thirty、fifty、one hundred 等数字表达，并读取比赛和图书角数据。", "计分牌", ["anchor_study_map", "anchor_study_bookshelf", "anchor_study_mailbox"]],
  ["kn_eng_g4b_u05_core", "english", "g3_4", "四下 Unit 5：帮助与工作", ["vocabulary", "reading_clue"], "能理解 help、teach、learn、hard、but 等动作和转折词，并描述身边的帮助者。", "帮助者徽章", ["anchor_study_bookshelf", "anchor_study_map", "anchor_study_mailbox"]],
  ["kn_eng_g4b_u06_core", "english", "g3_4", "四下 Unit 6：四季和天气", ["vocabulary", "observation"], "能理解 favourite season、spring、summer、autumn、winter、cool 等季节天气表达。", "四季花环", ["anchor_wardrobe_mirror", "anchor_wardrobe_rack", "anchor_wardrobe_shoes"]],
  ["kn_eng_g4b_u07_core", "english", "g3_4", "四下 Unit 7：风景观察", ["observation", "vocabulary"], "能理解 cloud、sun、sky、boat、lake、moon 等风景词，并用 I can see... 描述观察结果。", "云朵卡", ["anchor_study_map", "anchor_study_bookshelf", "anchor_study_mailbox"]],
  ["kn_eng_g4b_u08_core", "english", "g3_4", "四下 Unit 8：正在发生的事", ["observation", "vocabulary"], "能理解 water、dirty、busy 等词，并识别 is/are + 动作 ing 的正在进行表达。", "清洁贴纸", ["anchor_study_mailbox", "anchor_study_map", "anchor_study_bookshelf"]],
  ["kn_eng_g4b_u09_core", "english", "g3_4", "四下 Unit 9：端午节活动", ["vocabulary", "sequence"], "能理解 Dragon Boat Festival、race、remember、country 等节日词，并按步骤理解包粽子流程。", "龙舟装饰", ["anchor_study_map", "anchor_study_bookshelf", "anchor_study_mailbox"]],
  ["kn_eng_g4b_u10_core", "english", "g3_4", "四下 Unit 10：安全标志", ["vocabulary", "classification"], "能理解 sign、mean、light、must、phone、smoke、pick 等标志词，并判断安全规则含义。", "安全标志牌", ["anchor_study_map", "anchor_study_bookshelf", "anchor_study_mailbox"]],
  ["kn_eng_g5a_u01_core", "english", "g5_6", "五上 Unit 1：外貌描述", ["vocabulary", "observation"], "能理解 tall、long、round、young、old 等外貌词，并回答 What does she look like?。", "人物素描卡", ["anchor_study_mailbox", "anchor_study_bookshelf", "anchor_study_map"]],
  ["kn_eng_g5a_u02_core", "english", "g5_6", "五上 Unit 2：餐厅点餐", ["vocabulary", "classification"], "能理解 hamburger、Coke、food、sandwich、beef 等餐厅词，并用 I'd like... 点餐。", "餐厅菜单", ["anchor_kitchen_cup", "anchor_kitchen_oven", "anchor_kitchen_timer"]],
  ["kn_eng_g5a_u03_core", "english", "g5_6", "五上 Unit 3：午餐选择", ["vocabulary", "classification"], "能理解 breakfast、lunch、soup、vegetable、tomato、potato 等餐食词，并回答 Do you want some...?。", "午餐碗", ["anchor_kitchen_cup", "anchor_kitchen_oven", "anchor_kitchen_timer"]],
  ["kn_eng_g5a_u04_core", "english", "g5_6", "五上 Unit 4：借用文具", ["vocabulary", "reading_clue"], "能理解 borrow、dictionary、marker、glue 等文具词，并用 Can I use your..., please? 礼貌请求。", "文具盒", ["anchor_study_bookshelf", "anchor_study_mailbox", "anchor_study_map"]],
  ["kn_eng_g5a_u05_core", "english", "g5_6", "五上 Unit 5：宠物请求", ["vocabulary", "classification"], "能理解 pet、rabbit、basket、lovely 等宠物词，并使用 Can I have a pet? 表达请求。", "宠物名牌", ["anchor_study_mailbox", "anchor_study_bookshelf", "anchor_study_map"]],
  ["kn_eng_g5a_u06_core", "english", "g5_6", "五上 Unit 6：衣物比较选择", ["vocabulary", "classification"], "能理解 which、raincoat、thick、thin、jacket、umbrella、old 等词，并回答 Which one do you want?。", "雨衣", ["anchor_wardrobe_rack", "anchor_wardrobe_mirror", "anchor_wardrobe_shoes"]],
  ["kn_eng_g5a_u07_core", "english", "g5_6", "五上 Unit 7：作息采访", ["time", "sequence"], "能理解 get up、go to bed、timetable、computer、lesson、PE、art、maths 等词，并采访作息时间。", "采访本", ["anchor_study_mailbox", "anchor_study_map", "anchor_study_bookshelf"]],
  ["kn_eng_g5a_u08_core", "english", "g5_6", "五上 Unit 8：家务帮助", ["vocabulary", "sequence"], "能理解 make、iron、clean、meal、water、plant、wash 等家务动作，并描述 Lingling helps her parents。", "家务徽章", ["anchor_kitchen_cup", "anchor_kitchen_oven", "anchor_kitchen_timer"]],
  ["kn_eng_g5a_u09_core", "english", "g5_6", "五上 Unit 9：兴趣爱好", ["vocabulary", "classification"], "能理解 hobby、photo、chess、collect、stamp、storybook、violin 等兴趣词，并用 like doing 表达爱好。", "收藏册", ["anchor_study_mailbox", "anchor_study_bookshelf", "anchor_study_map"]],
  ["kn_eng_g5a_u10_core", "english", "g5_6", "五上 Unit 10：公共标志", ["vocabulary", "classification"], "能理解 sign、mean、talk、fish、pick、smoke、spit 等标志词，并判断禁止行为。", "小巡查证", ["anchor_study_map", "anchor_study_bookshelf", "anchor_study_mailbox"]],
  ["kn_eng_g5a_u11_core", "english", "g5_6", "五上 Unit 11：道歉与情绪", ["vocabulary", "reading_clue"], "能理解 loudly、noise、unhappy、proud、excited、sad、shy 等情绪词，并使用 I'm sorry。", "和好贴纸", ["anchor_study_mailbox", "anchor_study_bookshelf", "anchor_study_map"]],
  ["kn_eng_g5a_u12_core", "english", "g5_6", "五上 Unit 12：春节与复习", ["vocabulary", "sequence"], "能理解 Spring Festival、house、eve、delicious、reunion、packet、lion dance、fun 等节日词，并复习本册核心表达。", "红灯笼", ["anchor_kitchen_oven", "anchor_kitchen_cup", "anchor_kitchen_timer"]]
].map(([id, subject, gradeBand, title, skillTags, descriptionForParent, childVisibleLabel, anchorIds]) => ({
  id,
  subject,
  gradeBand,
  title,
  skillTags,
  descriptionForParent,
  childVisibleLabel,
  anchorIds,
  reviewPolicy
}));

const handcraftedKnowledgeIds = new Set(handcraftedKnowledgeConfigs.map((item) => item.id));
const generatedRuntimeKnowledgeConfigs = englishStoryKnowledgeConfigs
  .filter((item) => ["g5b", "g6a", "g6b"].includes(item.bookId) && !handcraftedKnowledgeIds.has(item.id))
  .map((item) => ({
    id: item.id,
    subject: "english",
    gradeBand: "g5_6",
    title: runtimeKnowledgeTitle(item),
    skillTags: runtimeSkillTags(item.languageFocus),
    descriptionForParent: item.parentSummary,
    childVisibleLabel: runtimeKnowledgeLabel(item),
    anchorIds: runtimeAnchorIds(item),
    reviewPolicy
  }));

export const knowledgeConfigs = [...handcraftedKnowledgeConfigs, ...generatedRuntimeKnowledgeConfigs];
export const knowledgeById = Object.fromEntries(knowledgeConfigs.map((item) => [item.id, item]));

function runtimeKnowledgeTitle(item) {
  return `${bookShortName(item.bookId)} Unit ${item.unitNumber}：${item.languageFocus}`;
}

function runtimeKnowledgeLabel(item) {
  const rewardLabels = {
    g5b: ["剧场门票", "研究夹", "风筝", "环保夹子", "生日贴纸", "玫瑰卡", "小镇地图", "路线牌", "采访徽章", "昨日相片", "奖牌", "旅行笔记"],
    g6a: ["假期书页", "观察笔", "电脑贴纸", "月饼盒", "天气预报牌", "野餐篮", "志愿者徽章", "水滴星片", "黏土展台", "健康包", "剧场海报", "彩灯"],
    g6b: ["家庭出游票", "故事星片", "健康手环", "小树苗", "地球徽章", "演出服饰", "勇气贴纸", "派对彩带", "毕业星图"]
  };
  return rewardLabels[item.bookId]?.[item.unitNumber - 1] || "英语星片";
}

function runtimeSkillTags(languageFocus = "") {
  const tags = ["vocabulary"];
  if (/步骤|First|Then|Next|Lastly|顺序|序数|计划|将来|will|going to/.test(languageFocus)) tags.push("sequence");
  if (/日期|月份|时间|频率|昨天|过去|作息/.test(languageFocus)) tags.push("time");
  if (/问路|地点|路线|near|旅行/.test(languageFocus)) tags.push("spatial");
  if (/比较|健康|环保|规则|should|Don't|情绪|性格/.test(languageFocus)) tags.push("classification");
  return [...new Set(tags)];
}

function runtimeAnchorIds(item) {
  const focus = `${item.title} ${item.languageFocus}`;
  if (/礼物|服饰|舞|演出|天气|彩灯/.test(focus)) return ["anchor_wardrobe_rack", "anchor_wardrobe_mirror", "anchor_wardrobe_shoes"];
  if (/月饼|野餐|健康|水|食|餐|果汁/.test(focus)) return ["anchor_kitchen_cup", "anchor_kitchen_oven", "anchor_kitchen_timer"];
  return ["anchor_study_mailbox", "anchor_study_bookshelf", "anchor_study_map"];
}

function bookShortName(bookId) {
  return {
    g5b: "五下",
    g6a: "六上",
    g6b: "六下"
  }[bookId] || bookId;
}
