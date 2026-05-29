export const sceneConfigs = [
  {
    id: "scene_town",
    phaserKey: "TownScene",
    title: "星光小镇",
    description: "查看委托和前往不同小房间。",
    color: 0xf6e3bf,
    unlockedByDefault: true,
    anchors: []
  },
  {
    id: "scene_wardrobe",
    phaserKey: "WardrobeScene",
    title: "衣帽间",
    description: "挑选衣服、整理配饰、照镜子的小房间。",
    color: 0xf9d5d3,
    unlockedByDefault: true,
    materials: [
      { id: "mat_wardrobe_clothes", title: "服饰卡", description: "dress、T-shirt、trousers、coat、raincoat 等穿戴词。", imageKey: "material-wardrobe-clothes", corpusThemes: ["服饰", "雨具", "搭配"] },
      { id: "mat_wardrobe_mirror", title: "搭配镜", description: "Do you like...? Which one...? 等喜好和选择表达。", imageKey: "material-wardrobe-mirror", corpusThemes: ["喜好", "比较", "选择"] },
      { id: "mat_wardrobe_show", title: "演出配饰", description: "dance、wanted to、show 等演出和动作表达。", imageKey: "material-wardrobe-show", corpusThemes: ["演出", "动作", "毕业"] }
    ],
    anchors: [
      { id: "anchor_wardrobe_rack", name: "衣架", x: 164, y: 188, width: 210, height: 210, stable: true, allowedSkillTags: ["classification", "vocabulary"] },
      { id: "anchor_wardrobe_mirror", name: "镜子", x: 486, y: 146, width: 148, height: 268, stable: true, allowedSkillTags: ["vocabulary"] },
      { id: "anchor_wardrobe_shoes", name: "鞋柜", x: 762, y: 302, width: 204, height: 126, stable: true, allowedSkillTags: ["classification"] }
    ]
  },
  {
    id: "scene_kitchen",
    phaserKey: "KitchenScene",
    title: "厨房",
    description: "量一量、排一排，把点心准备好。",
    color: 0xd9f0da,
    unlockedByDefault: true,
    materials: [
      { id: "mat_kitchen_food", title: "食物篮", description: "egg、rice、hamburger、soup、vegetable 等食物词。", imageKey: "material-kitchen-food", corpusThemes: ["食物", "点餐", "餐食"] },
      { id: "mat_kitchen_measure", title: "量杯与数量", description: "How many、half、one hundred、point 等数量线索。", imageKey: "material-kitchen-measure", corpusThemes: ["数量", "分数", "得分"] },
      { id: "mat_kitchen_recipe", title: "菜谱步骤", description: "First、Then、Next、Lastly 和餐前流程。", imageKey: "material-kitchen-recipe", corpusThemes: ["顺序", "步骤", "时间"] }
    ],
    anchors: [
      { id: "anchor_kitchen_cup", name: "量杯", x: 196, y: 250, width: 172, height: 170, stable: true, allowedSkillTags: ["quantity", "fraction"] },
      { id: "anchor_kitchen_oven", name: "烤箱", x: 520, y: 246, width: 230, height: 192, stable: true, allowedSkillTags: ["sequence"] },
      { id: "anchor_kitchen_timer", name: "计时器", x: 828, y: 164, width: 136, height: 132, stable: true, allowedSkillTags: ["time"] }
    ]
  },
  {
    id: "scene_school",
    phaserKey: "SchoolScene",
    title: "星光学校",
    description: "导览校园、整理课程、完成课堂和运动委托。",
    color: 0xe4ecff,
    unlockedByDefault: true,
    materials: [
      { id: "mat_school_timetable", title: "课程表", description: "English、maths、PE、music、lesson、timetable。", imageKey: "material-school-timetable", corpusThemes: ["课程", "作息", "星期"] },
      { id: "mat_school_library", title: "图书角", description: "library、book、story、borrow、dictionary、marker。", imageKey: "material-school-library", corpusThemes: ["阅读", "文具", "研究"] },
      { id: "mat_school_playground", title: "操场任务牌", description: "basketball、football、swim、score、rank、can。", imageKey: "material-school-playground", corpusThemes: ["运动", "能力", "比赛"] }
    ],
    anchors: [
      { id: "anchor_school_board", name: "课程板", x: 188, y: 188, width: 190, height: 156, stable: true, allowedSkillTags: ["vocabulary", "classification", "time"] },
      { id: "anchor_school_library", name: "图书角", x: 520, y: 178, width: 210, height: 178, stable: true, allowedSkillTags: ["reading_clue", "vocabulary"] },
      { id: "anchor_school_playground", name: "操场", x: 790, y: 316, width: 220, height: 138, stable: true, allowedSkillTags: ["sequence", "classification"] }
    ]
  },
  {
    id: "scene_city",
    phaserKey: "CityScene",
    title: "城市街区",
    description: "看地图、读标志、规划交通路线和职业采访。",
    color: 0xe6f0ef,
    unlockedByDefault: true,
    materials: [
      { id: "mat_city_transport", title: "交通票", description: "bus、train、taxi、plane、bike、underground、on foot。", imageKey: "material-city-transport", corpusThemes: ["交通", "路线", "问路"] },
      { id: "mat_city_signs", title: "公共标志", description: "sign、mean、must、Don't、No smoking、No fishing。", imageKey: "material-city-signs", corpusThemes: ["标志", "规则", "公共空间"] },
      { id: "mat_city_jobs", title: "职业采访卡", description: "driver、farmer、worker、doctor、teacher、policeman。", imageKey: "material-city-jobs", corpusThemes: ["职业", "采访", "身份确认"] }
    ],
    anchors: [
      { id: "anchor_city_station", name: "车站", x: 180, y: 282, width: 190, height: 156, stable: true, allowedSkillTags: ["spatial", "sequence"] },
      { id: "anchor_city_map", name: "街区图", x: 512, y: 162, width: 230, height: 166, stable: true, allowedSkillTags: ["spatial", "reading_clue"] },
      { id: "anchor_city_sign", name: "标志牌", x: 806, y: 226, width: 170, height: 174, stable: true, allowedSkillTags: ["classification", "vocabulary"] }
    ]
  },
  {
    id: "scene_festival",
    phaserKey: "FestivalScene",
    title: "节日广场",
    description: "布置舞台、安排活动、收集节日和派对线索。",
    color: 0xffeadf,
    unlockedByDefault: true,
    materials: [
      { id: "mat_festival_stage", title: "节日舞台", description: "sing、dance、draw、play、party、have fun。", imageKey: "material-festival-stage", corpusThemes: ["儿童节", "活动", "派对"] },
      { id: "mat_festival_craft", title: "手作桌", description: "kite、card、rose、gift、make、decorate。", imageKey: "material-festival-craft", corpusThemes: ["手作", "礼物", "母亲节"] },
      { id: "mat_festival_calendar", title: "节日日历", description: "Dragon Boat Festival、Spring Festival、Christmas、first of June。", imageKey: "material-festival-calendar", corpusThemes: ["端午", "春节", "圣诞", "日期"] }
    ],
    anchors: [
      { id: "anchor_festival_stage", name: "小舞台", x: 210, y: 238, width: 210, height: 164, stable: true, allowedSkillTags: ["classification", "observation"] },
      { id: "anchor_festival_craft", name: "手作桌", x: 524, y: 330, width: 220, height: 138, stable: true, allowedSkillTags: ["sequence", "vocabulary"] },
      { id: "anchor_festival_calendar", name: "节日日历", x: 804, y: 176, width: 168, height: 160, stable: true, allowedSkillTags: ["time", "reading_clue"] }
    ]
  },
  {
    id: "scene_nature",
    phaserKey: "NatureScene",
    title: "自然花园",
    description: "观察天气、四季、动物、植物、地球和星空。",
    color: 0xe3f3dc,
    unlockedByDefault: true,
    materials: [
      { id: "mat_nature_weather", title: "天气天空", description: "sunny、rainy、windy、cloud、sky、moon、lake。", imageKey: "material-nature-weather", corpusThemes: ["天气", "风景", "观察"] },
      { id: "mat_nature_garden", title: "花园观察卡", description: "flower、tree、seed、bee、bird、planting trees。", imageKey: "material-nature-garden", corpusThemes: ["植物", "花园", "环保"] },
      { id: "mat_nature_earth", title: "地球星图", description: "Earth、space、air、keep clean、places of interest。", imageKey: "material-nature-earth", corpusThemes: ["地球", "星空", "旅行"] }
    ],
    anchors: [
      { id: "anchor_nature_garden", name: "花园", x: 184, y: 300, width: 210, height: 156, stable: true, allowedSkillTags: ["vocabulary", "classification"] },
      { id: "anchor_nature_sky", name: "天空台", x: 512, y: 154, width: 232, height: 158, stable: true, allowedSkillTags: ["observation", "spatial"] },
      { id: "anchor_nature_earth", name: "地球仪", x: 806, y: 270, width: 182, height: 170, stable: true, allowedSkillTags: ["reading_clue", "observation"] }
    ]
  },
  {
    id: "scene_health",
    phaserKey: "HealthScene",
    title: "健康小站",
    description: "完成洗手、刷牙、作息、照顾和健康建议。",
    color: 0xe3f7f1,
    unlockedByDefault: true,
    materials: [
      { id: "mat_health_sink", title: "洗手台", description: "wash、brush、clean、face、teeth、hair。", imageKey: "material-health-sink", corpusThemes: ["清洁", "卫生", "步骤"] },
      { id: "mat_health_chart", title: "健康习惯表", description: "often、always、should、shouldn't、take care。", imageKey: "material-health-chart", corpusThemes: ["习惯", "建议", "作息"] },
      { id: "mat_health_kit", title: "健康包", description: "doctor、nurse、medicine、rest、ill、help。", imageKey: "material-health-kit", corpusThemes: ["医护", "照顾", "公益"] }
    ],
    anchors: [
      { id: "anchor_health_sink", name: "洗手台", x: 184, y: 294, width: 196, height: 152, stable: true, allowedSkillTags: ["sequence", "vocabulary"] },
      { id: "anchor_health_chart", name: "习惯表", x: 514, y: 166, width: 216, height: 164, stable: true, allowedSkillTags: ["time", "sequence"] },
      { id: "anchor_health_kit", name: "健康包", x: 816, y: 298, width: 176, height: 146, stable: true, allowedSkillTags: ["classification", "reading_clue"] }
    ]
  },
  {
    id: "scene_study",
    phaserKey: "StudyScene",
    title: "邮局书房",
    description: "读短信、看地图、把卡片送到合适地方。",
    color: 0xd5e5f7,
    unlockedByDefault: true,
    materials: [
      { id: "mat_study_mail", title: "信件线索", description: "How are you、I'm sorry、Shall we、Can I 等对话句。", imageKey: "material-study-mail", corpusThemes: ["问候", "请求", "对话"] },
      { id: "mat_study_album", title: "故事相册", description: "photo、storybook、holiday、memory、enjoy doing。", imageKey: "material-study-album", corpusThemes: ["故事", "回忆", "相册"] },
      { id: "mat_study_research", title: "研究卡片", description: "computer、email、find out、report、interesting。", imageKey: "material-study-research", corpusThemes: ["研究", "电脑", "报告"] }
    ],
    anchors: [
      { id: "anchor_study_mailbox", name: "信箱", x: 168, y: 250, width: 182, height: 176, stable: true, allowedSkillTags: ["reading_clue"] },
      { id: "anchor_study_map", name: "地图", x: 512, y: 152, width: 226, height: 176, stable: true, allowedSkillTags: ["spatial", "reading_clue"] },
      { id: "anchor_study_bookshelf", name: "书架", x: 824, y: 188, width: 178, height: 246, stable: true, allowedSkillTags: ["vocabulary"] }
    ]
  }
];

export const scenesById = Object.fromEntries(sceneConfigs.map((scene) => [scene.id, scene]));
