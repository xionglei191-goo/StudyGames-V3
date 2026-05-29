import { englishCorpusSentences, englishCorpusVocabulary } from "./englishCorpus.js";
import { englishStoryTaskConfigs } from "./englishStoryTasks.js";

const legacyTaskConfigs = [
  {
    id: "task_wardrobe_001",
    title: "花园派对搭配",
    sceneId: "scene_wardrobe",
    subjectMix: ["english", "chinese"],
    recommendedGradeBand: "g3_4",
    introCopy: "花园派对快开始了，帮她选一套轻快的衣服吧。",
    successCopy: "搭配完成！她已经准备好去花园了。",
    retryCopy: "这个还不太合适，再看一眼活动线索。",
    estimatedMinutes: 3,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "花园派对要穿得轻快，帮她拿一件 pink dress。",
        anchorId: "anchor_wardrobe_rack",
        knowledgeIds: ["kn_eng_g3_001", "kn_eng_g3_002"],
        options: [
          { id: "opt_pink_dress", label: "pink dress", asset: "pink-dress", category: "dress" },
          { id: "opt_blue_hat", label: "blue hat", asset: "blue-hat", category: "hat" },
          { id: "opt_yellow_shoes", label: "yellow shoes", asset: "yellow-shoes", category: "shoes" }
        ],
        correctOptionIds: ["opt_pink_dress"],
        hintCopy: "先找颜色 pink，再找 dress。"
      },
      {
        id: "step_002",
        type: "drag",
        prompt: "把 yellow shoes 拖到镜子前，看看搭配效果。",
        anchorId: "anchor_wardrobe_mirror",
        knowledgeIds: ["kn_eng_g3_001", "kn_eng_g3_002"],
        options: [
          { id: "opt_yellow_shoes", label: "yellow shoes", asset: "yellow-shoes", category: "shoes" },
          { id: "opt_small_bag", label: "small bag", asset: "small-bag", category: "bag" }
        ],
        correctOptionIds: ["opt_yellow_shoes"],
        hintCopy: "shoes 是鞋子，yellow 是黄色。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_outfit_001", quantity: 1 }]
  },
  {
    id: "task_wardrobe_002",
    title: "衣柜整理日",
    sceneId: "scene_wardrobe",
    subjectMix: ["chinese"],
    recommendedGradeBand: "g3_4",
    introCopy: "衣帽间有点乱，帮她把物品放回合适的小格子。",
    successCopy: "整理好啦，衣帽间看起来清清爽爽。",
    retryCopy: "这个小格子还不太合适，看看它的用途。",
    estimatedMinutes: 2,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "衣柜收好后，看起来更像哪两个词？",
        anchorId: "anchor_wardrobe_mirror",
        knowledgeIds: ["kn_chi_g3_004"],
        options: [
          { id: "opt_clean_tidy", label: "干净、整齐" },
          { id: "opt_soft_fast", label: "柔软、飞快" },
          { id: "opt_round_loud", label: "圆圆、响亮" }
        ],
        correctOptionIds: ["opt_clean_tidy"],
        hintCopy: "想一想整理完的衣柜是什么样子。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把能穿戴的小物件放进衣物篮。",
        anchorId: "anchor_wardrobe_shoes",
        knowledgeIds: ["kn_chi_g3_006", "kn_eng_g3_006"],
        options: [
          { id: "opt_dress_clothes", label: "dress → 衣物篮" },
          { id: "opt_hat_clothes", label: "hat → 衣物篮" },
          { id: "opt_book_clothes", label: "book → 衣物篮" }
        ],
        correctOptionIds: ["opt_dress_clothes", "opt_hat_clothes"],
        hintCopy: "衣物篮里应该放能穿戴的东西。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_decoration_001", quantity: 1 }]
  },
  {
    id: "task_kitchen_001",
    title: "甜点配方",
    sceneId: "scene_kitchen",
    subjectMix: ["math", "chinese"],
    recommendedGradeBand: "g1_2",
    introCopy: "邻居想尝一块小蛋糕，照着配方把步骤排好。",
    successCopy: "香喷喷的小蛋糕出炉了。",
    retryCopy: "点心还差一步，再看看先后顺序。",
    estimatedMinutes: 3,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "配方卡写着 3 勺面粉，帮她拿到合适的量。",
        anchorId: "anchor_kitchen_cup",
        knowledgeIds: ["kn_math_g2_001", "kn_math_g3_006"],
        options: [
          { id: "opt_one_spoon", label: "1 勺" },
          { id: "opt_three_spoons", label: "3 勺" },
          { id: "opt_five_spoons", label: "5 勺" }
        ],
        correctOptionIds: ["opt_three_spoons"],
        hintCopy: "配方上的数字是 3。"
      },
      {
        id: "step_002",
        type: "order",
        prompt: "小蛋糕要先做哪一步？把动作按先后放好。",
        anchorId: "anchor_kitchen_oven",
        knowledgeIds: ["kn_math_g2_002", "kn_chi_g3_005"],
        options: [
          { id: "opt_mix", label: "搅拌" },
          { id: "opt_pour", label: "倒入模具" },
          { id: "opt_bake", label: "放进烤箱" }
        ],
        correctOptionIds: ["opt_mix", "opt_pour", "opt_bake"],
        hintCopy: "先把材料拌匀，再倒进模具。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_outfit_002", quantity: 1 }]
  },
  {
    id: "task_kitchen_002",
    title: "半杯果汁",
    sceneId: "scene_kitchen",
    subjectMix: ["math"],
    recommendedGradeBand: "g3_4",
    introCopy: "朋友只想喝半杯果汁，帮她倒到刚刚好的位置。",
    successCopy: "半杯果汁刚刚好。",
    retryCopy: "这个容量有点多或有点少，再看量杯线。",
    estimatedMinutes: 2,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "朋友想喝半杯果汁，哪一杯刚刚到中间线？",
        anchorId: "anchor_kitchen_cup",
        knowledgeIds: ["kn_math_g3_004", "kn_math_g3_005"],
        options: [
          { id: "opt_full", label: "满满一杯" },
          { id: "opt_half", label: "到中间线" },
          { id: "opt_little", label: "只有一点点" }
        ],
        correctOptionIds: ["opt_half"],
        hintCopy: "半杯大约在杯子的中间。"
      },
      {
        id: "step_002",
        type: "choice",
        prompt: "点心要等 10 分钟，帮她拧到合适的小铃声。",
        anchorId: "anchor_kitchen_timer",
        knowledgeIds: ["kn_math_g2_003"],
        options: [
          { id: "opt_5_min", label: "5 分钟" },
          { id: "opt_10_min", label: "10 分钟" },
          { id: "opt_30_min", label: "30 分钟" }
        ],
        correctOptionIds: ["opt_10_min"],
        hintCopy: "看清楚提示里的数字。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_decoration_002", quantity: 1 }]
  },
  {
    id: "task_study_001",
    title: "读信找人",
    sceneId: "scene_study",
    subjectMix: ["chinese"],
    recommendedGradeBand: "g1_2",
    introCopy: "信箱里有一封短信，帮邮差找到收信人。",
    successCopy: "信送到啦，小镇朋友很开心。",
    retryCopy: "再读一遍线索，名字或地点就在句子里。",
    estimatedMinutes: 3,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "信上写：请送给在书架旁读书的米娜。这封信要交给谁？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_chi_g2_001", "kn_chi_g2_003"],
        options: [
          { id: "opt_mina", label: "米娜" },
          { id: "opt_luna", label: "露娜" },
          { id: "opt_postman", label: "邮差" }
        ],
        correctOptionIds: ["opt_mina"],
        hintCopy: "找一找句子里“送给”后面的名字。"
      },
      {
        id: "step_002",
        type: "choice",
        prompt: "米娜会在小镇的哪个位置等信？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_chi_g2_002", "kn_chi_g2_003"],
        options: [
          { id: "opt_near_bookshelf", label: "书架旁" },
          { id: "opt_under_table", label: "桌子下" },
          { id: "opt_in_kitchen", label: "厨房里" }
        ],
        correctOptionIds: ["opt_near_bookshelf"],
        hintCopy: "地点线索藏在“在……旁”。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_album_001", quantity: 1 }]
  },
  {
    id: "task_study_002",
    title: "英文小卡片",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "书架上的英文小卡片散开了，帮她配回图案旁。",
    successCopy: "卡片都回到合适的位置了。",
    retryCopy: "再看看卡片上的词和旁边的图案。",
    estimatedMinutes: 2,
    steps: [
      {
        id: "step_001",
        type: "match",
        prompt: "英文小卡散开了，帮它们回到对应的小图案旁。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g3_004", "kn_eng_g3_005"],
        options: [
          { id: "opt_book_book", label: "book → 书" },
          { id: "opt_card_card", label: "card → 卡片" },
          { id: "opt_flower_book", label: "flower → 书" }
        ],
        correctOptionIds: ["opt_book_book", "opt_card_card"],
        hintCopy: "book 是书，card 是卡片。"
      },
      {
        id: "step_002",
        type: "choice",
        prompt: "地图上写 next to the mailbox，要把卡片放到哪里？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g3_003"],
        options: [
          { id: "opt_next_to_mailbox", label: "信箱旁边" },
          { id: "opt_under_mailbox", label: "信箱下面" },
          { id: "opt_on_mailbox", label: "信箱上面" }
        ],
        correctOptionIds: ["opt_next_to_mailbox"],
        hintCopy: "next to 表示在旁边。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }]
  },
  {
    id: "task_eng_g3b_u01_main",
    title: "小镇门口见面礼",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    chapterId: "arc_eng_g3b_new_town",
    unitId: "unit_eng_g3b_u01",
    corpusVocabularyIds: ["voc_g3b_0001", "voc_g3b_0002", "voc_g3b_0003", "voc_g3b_0004", "voc_g3b_0005", "voc_g3b_0006", "voc_g3b_0007", "voc_g3b_0008", "voc_g3b_0009", "voc_g3b_0010", "voc_g3b_0011", "voc_g3b_0012", "voc_g3b_0013", "voc_g3b_0014"],
    corpusSentenceIds: ["sen_g3b_0015", "sen_g3b_0016", "sen_g3b_0017", "sen_g3b_0018", "sen_g3b_0019", "sen_g3b_0020", "sen_g3b_0021", "sen_g3b_0022", "sen_g3b_0023", "sen_g3b_0024"],
    introCopy: "新朋友在小镇门口等你，帮她完成见面礼。",
    successCopy: "问候星片点亮了，新朋友已经认识你啦。",
    retryCopy: "这句还不太适合，再看看对方说了什么。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Mina 说：Good morning. How are you? 选一句自然回应。",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g3b_u01_core"],
        corpusSentenceIds: ["sen_g3b_0015", "sen_g3b_0016", "sen_g3b_0017"],
        options: [
          { id: "opt_im_fine", label: "I'm fine. And you?" },
          { id: "opt_its_seven", label: "It's seven o'clock." },
          { id: "opt_i_like_dress", label: "I like the dress." }
        ],
        correctOptionIds: ["opt_im_fine"],
        hintCopy: "别人问 How are you? 可以回答 I'm fine."
      },
      {
        id: "step_002",
        type: "choice",
        prompt: "Coco 举着名牌问：Are you Qiqi? 如果不是，应该怎么说？",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g3b_u01_core"],
        corpusSentenceIds: ["sen_g3b_0019", "sen_g3b_0020"],
        options: [
          { id: "opt_no_im_not", label: "No, I'm not." },
          { id: "opt_yes_i_do", label: "Yes, I do." },
          { id: "opt_good_night", label: "Good night." }
        ],
        correctOptionIds: ["opt_no_im_not"],
        hintCopy: "Are you...? 的否定回答是 No, I'm not."
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把见面礼小卡配成一组，送给新朋友。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g3b_u01_core"],
        corpusVocabularyIds: ["voc_g3b_0002", "voc_g3b_0003", "voc_g3b_0005", "voc_g3b_0011", "voc_g3b_0012"],
        options: [
          { id: "opt_glad_happy", label: "glad → 高兴的" },
          { id: "opt_fine_good", label: "fine → 健康的" },
          { id: "opt_rainy_weather", label: "rainy → 天气" }
        ],
        correctOptionIds: ["opt_glad_happy", "opt_fine_good"],
        hintCopy: "glad 和 fine 都是见面问候里会用到的词。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g3b_u01_star", quantity: 1 }]
  },
  {
    id: "task_eng_g3b_u02_main",
    title: "帮 Mina 赶上铃声",
    sceneId: "scene_kitchen",
    subjectMix: ["english", "math"],
    recommendedGradeBand: "g3_4",
    chapterId: "arc_eng_g3b_new_town",
    unitId: "unit_eng_g3b_u02",
    corpusVocabularyIds: ["voc_g3b_0015", "voc_g3b_0016", "voc_g3b_0017", "voc_g3b_0018", "voc_g3b_0019", "voc_g3b_0020", "voc_g3b_0021", "voc_g3b_0022", "voc_g3b_0023", "voc_g3b_0024", "voc_g3b_0025", "voc_g3b_0026", "voc_g3b_0027"],
    corpusSentenceIds: ["sen_g3b_0038", "sen_g3b_0039", "sen_g3b_0040", "sen_g3b_0041", "sen_g3b_0042", "sen_g3b_0043", "sen_g3b_0044", "sen_g3b_0045", "sen_g3b_0046"],
    introCopy: "小闹钟有点乱，帮 Mina 看清时间。",
    successCopy: "小闹钟装饰点亮了，Mina 没有错过铃声。",
    retryCopy: "再看一次时间线索，选更合适的一句。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "闹钟指向 7:00，Mina 问：What time is it? 选一句合适的回应。",
        anchorId: "anchor_kitchen_timer",
        knowledgeIds: ["kn_eng_g3b_u02_core"],
        corpusSentenceIds: ["sen_g3b_0039", "sen_g3b_0040"],
        options: [
          { id: "opt_seven_oclock", label: "It's seven o'clock." },
          { id: "opt_im_fine", label: "I'm fine." },
          { id: "opt_its_rainy", label: "It's rainy." }
        ],
        correctOptionIds: ["opt_seven_oclock"],
        hintCopy: "7:00 可以说 seven o'clock."
      },
      {
        id: "step_002",
        type: "order",
        prompt: "帮 Mina 把一天里的提醒按顺序放好。",
        anchorId: "anchor_kitchen_timer",
        knowledgeIds: ["kn_eng_g3b_u02_core"],
        corpusVocabularyIds: ["voc_g3b_0016", "voc_g3b_0018", "voc_g3b_0019"],
        options: [
          { id: "opt_wake_up", label: "wake up" },
          { id: "opt_time_for_school", label: "It's time for school." },
          { id: "opt_time_for_bed", label: "It's time for bed." }
        ],
        correctOptionIds: ["opt_wake_up", "opt_time_for_school", "opt_time_for_bed"],
        hintCopy: "先醒来，再上学，晚上才睡觉。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "小卡上写 Sorry, I don't know. 这句更像哪种意思？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g3b_u02_core"],
        corpusSentenceIds: ["sen_g3b_0045"],
        options: [
          { id: "opt_sorry_dont_know", label: "抱歉，我不知道" },
          { id: "opt_good_morning", label: "早上好" },
          { id: "opt_like_sunny", label: "我喜欢晴天" }
        ],
        correctOptionIds: ["opt_sorry_dont_know"],
        hintCopy: "Sorry 是抱歉，don't know 是不知道。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g3b_u02_star", quantity: 1 }]
  },
  {
    id: "task_eng_g3b_u03_main",
    title: "天气出门准备",
    sceneId: "scene_wardrobe",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    chapterId: "arc_eng_g3b_new_town",
    unitId: "unit_eng_g3b_u03",
    corpusVocabularyIds: ["voc_g3b_0028", "voc_g3b_0029", "voc_g3b_0030", "voc_g3b_0031", "voc_g3b_0032", "voc_g3b_0033", "voc_g3b_0034", "voc_g3b_0035", "voc_g3b_0036", "voc_g3b_0037", "voc_g3b_0038", "voc_g3b_0039", "voc_g3b_0040", "voc_g3b_0041"],
    corpusSentenceIds: ["sen_g3b_0061", "sen_g3b_0062", "sen_g3b_0063", "sen_g3b_0064", "sen_g3b_0065", "sen_g3b_0066", "sen_g3b_0068", "sen_g3b_0069"],
    introCopy: "广场活动要开始了，先帮大家看天气。",
    successCopy: "天气贴纸点亮了，大家可以放心出门。",
    retryCopy: "再看看天气图标和句子里的关键词。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Mina 指着窗外问：What's the weather like? 太阳很亮，选一句回答。",
        anchorId: "anchor_wardrobe_mirror",
        knowledgeIds: ["kn_eng_g3b_u03_core"],
        corpusSentenceIds: ["sen_g3b_0061", "sen_g3b_0062"],
        options: [
          { id: "opt_its_sunny", label: "It's sunny." },
          { id: "opt_its_bed", label: "It's time for bed." },
          { id: "opt_yes_i_am", label: "Yes, I am." }
        ],
        correctOptionIds: ["opt_its_sunny"],
        hintCopy: "sunny 是晴朗的。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把天气词和中文意思配成小贴纸。",
        anchorId: "anchor_wardrobe_rack",
        knowledgeIds: ["kn_eng_g3b_u03_core"],
        corpusVocabularyIds: ["voc_g3b_0030", "voc_g3b_0031", "voc_g3b_0032", "voc_g3b_0033", "voc_g3b_0035"],
        options: [
          { id: "opt_rainy_rain", label: "rainy → 下雨的" },
          { id: "opt_windy_wind", label: "windy → 有风的" },
          { id: "opt_cold_hot", label: "cold → 炎热的" }
        ],
        correctOptionIds: ["opt_rainy_rain", "opt_windy_wind"],
        hintCopy: "rainy 看 rain，windy 看 wind。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "如果朋友说 I feel cold，衣帽间里先拿什么更合适？",
        anchorId: "anchor_wardrobe_rack",
        knowledgeIds: ["kn_eng_g3b_u03_core"],
        corpusSentenceIds: ["sen_g3b_0063"],
        options: [
          { id: "opt_coat", label: "coat" },
          { id: "opt_shorts", label: "shorts" },
          { id: "opt_coke", label: "Coke" }
        ],
        correctOptionIds: ["opt_coat"],
        hintCopy: "cold 表示冷，外套更合适。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g3b_u03_star", quantity: 1 }]
  },
  {
    id: "task_eng_g3b_u04_main",
    title: "欢迎派对搭配",
    sceneId: "scene_wardrobe",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    chapterId: "arc_eng_g3b_new_town",
    unitId: "unit_eng_g3b_u04",
    corpusVocabularyIds: ["voc_g3b_0042", "voc_g3b_0043", "voc_g3b_0044", "voc_g3b_0045", "voc_g3b_0046", "voc_g3b_0047", "voc_g3b_0048", "voc_g3b_0049", "voc_g3b_0050", "voc_g3b_0051", "voc_g3b_0052", "voc_g3b_0053", "voc_g3b_0054", "voc_g3b_0055"],
    corpusSentenceIds: ["sen_g3b_0084", "sen_g3b_0085", "sen_g3b_0086", "sen_g3b_0087", "sen_g3b_0088", "sen_g3b_0089", "sen_g3b_0090", "sen_g3b_0091", "sen_g3b_0092", "sen_g3b_0093"],
    introCopy: "欢迎派对快到了，帮 Mina 挑一套她喜欢的衣服。",
    successCopy: "派对服饰解锁了，欢迎会可以开始啦。",
    retryCopy: "再看服饰词和喜好问句，选更合适的一项。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Mina 说：I like the red and white dress. 先帮她找哪一类？",
        anchorId: "anchor_wardrobe_rack",
        knowledgeIds: ["kn_eng_g3b_u04_core"],
        corpusVocabularyIds: ["voc_g3b_0042", "voc_g3b_0043", "voc_g3b_0044"],
        corpusSentenceIds: ["sen_g3b_0090"],
        options: [
          { id: "opt_dress", label: "dress" },
          { id: "opt_trousers", label: "trousers" },
          { id: "opt_cap", label: "cap" }
        ],
        correctOptionIds: ["opt_dress"],
        hintCopy: "dress 是连衣裙。"
      },
      {
        id: "step_002",
        type: "choice",
        prompt: "朋友问：Do you like the dress? 如果喜欢，怎么回答？",
        anchorId: "anchor_wardrobe_mirror",
        knowledgeIds: ["kn_eng_g3b_u04_core"],
        corpusSentenceIds: ["sen_g3b_0087", "sen_g3b_0088"],
        options: [
          { id: "opt_yes_i_do", label: "Yes, I do." },
          { id: "opt_yes_i_am", label: "Yes, I am." },
          { id: "opt_no_im_not", label: "No, I'm not." }
        ],
        correctOptionIds: ["opt_yes_i_do"],
        hintCopy: "Do you like...? 的肯定回答是 Yes, I do."
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把能穿戴的派对物品放进衣物篮。",
        anchorId: "anchor_wardrobe_shoes",
        knowledgeIds: ["kn_eng_g3b_u04_core"],
        corpusVocabularyIds: ["voc_g3b_0048", "voc_g3b_0049", "voc_g3b_0050", "voc_g3b_0051", "voc_g3b_0052"],
        options: [
          { id: "opt_cap_clothes", label: "cap → 衣物篮" },
          { id: "opt_shirt_clothes", label: "shirt → 衣物篮" },
          { id: "opt_weather_clothes", label: "weather → 衣物篮" }
        ],
        correctOptionIds: ["opt_cap_clothes", "opt_shirt_clothes"],
        hintCopy: "cap 和 shirt 都是能穿戴的物品。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g3b_u04_star", quantity: 1 }]
  },
  {
    id: "task_eng_g3b_u05_main",
    title: "风筝数量清点",
    sceneId: "scene_study",
    subjectMix: ["english", "math"],
    recommendedGradeBand: "g3_4",
    chapterId: "arc_eng_g3b_new_town",
    unitId: "unit_eng_g3b_u05",
    corpusVocabularyIds: ["voc_g3b_0056", "voc_g3b_0057", "voc_g3b_0058", "voc_g3b_0059", "voc_g3b_0060", "voc_g3b_0061", "voc_g3b_0062", "voc_g3b_0063", "voc_g3b_0064", "voc_g3b_0065", "voc_g3b_0066", "voc_g3b_0067", "voc_g3b_0068"],
    corpusSentenceIds: ["sen_g3b_0107", "sen_g3b_0108", "sen_g3b_0109", "sen_g3b_0110", "sen_g3b_0111"],
    introCopy: "花园里飘着很多风筝，先帮管理员数一数。",
    successCopy: "风筝星片点亮了，数量终于对上了。",
    retryCopy: "再看看数量线索，别把风筝和星星混在一起。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "管理员问：How many kites are there? 现在看到 17 只，选对回答。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g3b_u05_core"],
        corpusSentenceIds: ["sen_g3b_0108", "sen_g3b_0109"],
        options: [
          { id: "opt_seventeen_kites", label: "Seventeen kites." },
          { id: "opt_one_bird", label: "One bird." },
          { id: "opt_its_sunny", label: "It's sunny." }
        ],
        correctOptionIds: ["opt_seventeen_kites"],
        hintCopy: "题目问多少只风筝，就数风筝。"
      },
      {
        id: "step_002",
        type: "order",
        prompt: "把 16、17、18、19、20 的数字按顺序排好。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g3b_u05_core"],
        corpusVocabularyIds: ["voc_g3b_0059", "voc_g3b_0060", "voc_g3b_0061", "voc_g3b_0062", "voc_g3b_0063", "voc_g3b_0064", "voc_g3b_0065", "voc_g3b_0066"],
        options: [
          { id: "opt_16", label: "16" },
          { id: "opt_17", label: "17" },
          { id: "opt_18", label: "18" },
          { id: "opt_19", label: "19" },
          { id: "opt_20", label: "20" }
        ],
        correctOptionIds: ["opt_16", "opt_17", "opt_18", "opt_19", "opt_20"],
        hintCopy: "数字是越往后越大。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "星星卡上写 And four more! 这句话是在说什么？",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g3b_u05_core"],
        corpusSentenceIds: ["sen_g3b_0110"],
        options: [
          { id: "opt_add_four", label: "再加四个" },
          { id: "opt_stop_now", label: "现在停止" },
          { id: "opt_go_home", label: "回家" }
        ],
        correctOptionIds: ["opt_add_four"],
        hintCopy: "four more 是再多四个。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g3b_u05_star", quantity: 1 }]
  },
  {
    id: "task_eng_g3b_u06_main",
    title: "厨房找食材",
    sceneId: "scene_kitchen",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    chapterId: "arc_eng_g3b_new_town",
    unitId: "unit_eng_g3b_u06",
    corpusVocabularyIds: ["voc_g3b_0069", "voc_g3b_0070", "voc_g3b_0071", "voc_g3b_0072", "voc_g3b_0073", "voc_g3b_0074", "voc_g3b_0075", "voc_g3b_0076", "voc_g3b_0077", "voc_g3b_0078", "voc_g3b_0079"],
    corpusSentenceIds: ["sen_g3b_0123", "sen_g3b_0124", "sen_g3b_0125", "sen_g3b_0126", "sen_g3b_0127", "sen_g3b_0128", "sen_g3b_0129", "sen_g3b_0130", "sen_g3b_0131", "sen_g3b_0132", "sen_g3b_0133"],
    introCopy: "厨房里有好多食材，先把点心需要的东西找出来。",
    successCopy: "果蔬篮点亮了，厨房材料准备好啦。",
    retryCopy: "再看一眼 There is / There are 的线索。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "桌上有一个 egg，先选对词。",
        anchorId: "anchor_kitchen_cup",
        knowledgeIds: ["kn_eng_g3b_u06_core"],
        corpusSentenceIds: ["sen_g3b_0123"],
        options: [
          { id: "opt_egg", label: "egg" },
          { id: "opt_grape", label: "grape" },
          { id: "opt_bed", label: "bed" }
        ],
        correctOptionIds: ["opt_egg"],
        hintCopy: "egg 是鸡蛋。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把食材和中文意思配好。",
        anchorId: "anchor_kitchen_cup",
        knowledgeIds: ["kn_eng_g3b_u06_core"],
        corpusVocabularyIds: ["voc_g3b_0071", "voc_g3b_0072", "voc_g3b_0075", "voc_g3b_0076", "voc_g3b_0077"],
        options: [
          { id: "opt_tomato", label: "tomato → 西红柿" },
          { id: "opt_potato", label: "potato → 土豆" },
          { id: "opt_thirsty", label: "thirsty → 果汁" }
        ],
        correctOptionIds: ["opt_tomato", "opt_potato"],
        hintCopy: "tomato 和 potato 都是食材。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "朋友说 I'm thirsty. 你应该拿什么更合适？",
        anchorId: "anchor_kitchen_timer",
        knowledgeIds: ["kn_eng_g3b_u06_core"],
        corpusSentenceIds: ["sen_g3b_0132"],
        options: [
          { id: "opt_tomato_juice", label: "some tomato juice" },
          { id: "opt_shoes", label: "shoes" },
          { id: "opt_bed", label: "bed" }
        ],
        correctOptionIds: ["opt_tomato_juice"],
        hintCopy: "thirsty 和喝的东西有关。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g3b_u06_star", quantity: 1 }]
  },
  {
    id: "task_eng_g3b_u07_main",
    title: "洗手和睡前准备",
    sceneId: "scene_kitchen",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    chapterId: "arc_eng_g3b_new_town",
    unitId: "unit_eng_g3b_u07",
    corpusVocabularyIds: ["voc_g3b_0080", "voc_g3b_0081", "voc_g3b_0082", "voc_g3b_0083", "voc_g3b_0084", "voc_g3b_0085", "voc_g3b_0086", "voc_g3b_0087", "voc_g3b_0088", "voc_g3b_0089", "voc_g3b_0090", "voc_g3b_0091", "voc_g3b_0092"],
    corpusSentenceIds: ["sen_g3b_0147", "sen_g3b_0148", "sen_g3b_0149", "sen_g3b_0150", "sen_g3b_0151", "sen_g3b_0152", "sen_g3b_0153", "sen_g3b_0154", "sen_g3b_0155", "sen_g3b_0156"],
    introCopy: "晚饭要开始了，先把洗手和睡前步骤排好。",
    successCopy: "洗手台贴纸点亮了，大家准备好吃饭和睡觉了。",
    retryCopy: "再看看顺序词和身体部位的线索。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "order",
        prompt: "把晚饭前的动作按顺序排好。",
        anchorId: "anchor_kitchen_cup",
        knowledgeIds: ["kn_eng_g3b_u07_core"],
        corpusSentenceIds: ["sen_g3b_0147", "sen_g3b_0148", "sen_g3b_0149", "sen_g3b_0150", "sen_g3b_0151", "sen_g3b_0152", "sen_g3b_0153", "sen_g3b_0154", "sen_g3b_0155", "sen_g3b_0156"],
        options: [
          { id: "opt_hungry", label: "I'm hungry." },
          { id: "opt_wash_hands", label: "wash your hands" },
          { id: "opt_dinner_ready", label: "Dinner is ready." },
          { id: "opt_have_dinner", label: "Let's have dinner." },
          { id: "opt_go_to_bed", label: "Let's go to bed." }
        ],
        correctOptionIds: ["opt_hungry", "opt_wash_hands", "opt_dinner_ready", "opt_have_dinner", "opt_go_to_bed"],
        hintCopy: "先说饿了，再洗手，吃完晚饭再去睡觉。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把清洁动作和身体部位配对。",
        anchorId: "anchor_kitchen_oven",
        knowledgeIds: ["kn_eng_g3b_u07_core"],
        corpusVocabularyIds: ["voc_g3b_0183", "voc_g3b_0187", "voc_g3b_0188", "voc_g3b_0189", "voc_g3b_0190", "voc_g3b_0191"],
        options: [
          { id: "opt_brush_teeth", label: "brush → teeth" },
          { id: "opt_wash_face", label: "wash → face" },
          { id: "opt_wash_hair", label: "wash → hair" }
        ],
        correctOptionIds: ["opt_brush_teeth", "opt_wash_face", "opt_wash_hair"],
        hintCopy: "brush teeth、wash face、wash hair 都是清洁动作。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Mina 说：My hands are clean now. 这里的 clean 是什么意思？",
        anchorId: "anchor_kitchen_timer",
        knowledgeIds: ["kn_eng_g3b_u07_core"],
        corpusSentenceIds: ["sen_g3b_0150"],
        options: [
          { id: "opt_clean_meaning", label: "干净的" },
          { id: "opt_hungry_meaning", label: "饥饿的" },
          { id: "opt_sleep_meaning", label: "睡觉" }
        ],
        correctOptionIds: ["opt_clean_meaning"],
        hintCopy: "clean 就是干净的。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g3b_u07_star", quantity: 1 }]
  },
  {
    id: "task_eng_g3b_u08_main",
    title: "儿童节小舞台",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    chapterId: "arc_eng_g3b_new_town",
    unitId: "unit_eng_g3b_u08",
    corpusVocabularyIds: ["voc_g3b_0093", "voc_g3b_0094", "voc_g3b_0095", "voc_g3b_0096", "voc_g3b_0097", "voc_g3b_0098", "voc_g3b_0099", "voc_g3b_0100", "voc_g3b_0101", "voc_g3b_0102", "voc_g3b_0103"],
    corpusSentenceIds: ["sen_g3b_0168", "sen_g3b_0169", "sen_g3b_0170", "sen_g3b_0171", "sen_g3b_0172", "sen_g3b_0173"],
    introCopy: "儿童节的小舞台要开场了，先把活动顺序摆好。",
    successCopy: "小舞台灯已经点亮，儿童节派对开始啦。",
    retryCopy: "再看看唱歌、跳舞和聚会的词。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "match",
        prompt: "把儿童节活动和中文意思配起来。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g3b_u08_core"],
        corpusVocabularyIds: ["voc_g3b_0093", "voc_g3b_0094", "voc_g3b_0095", "voc_g3b_0096", "voc_g3b_0097", "voc_g3b_0098", "voc_g3b_0099", "voc_g3b_0100", "voc_g3b_0101", "voc_g3b_0102", "voc_g3b_0103"],
        options: [
          { id: "opt_sing", label: "sing → 唱歌" },
          { id: "opt_dance", label: "dance → 跳舞" },
          { id: "opt_draw", label: "draw → 画画" },
          { id: "opt_play", label: "play → 玩" },
          { id: "opt_party", label: "party → 聚会" },
          { id: "opt_paint", label: "paint → 画画" },
          { id: "opt_watch", label: "watch → 观看" },
          { id: "opt_game", label: "game → 游戏" }
        ],
        correctOptionIds: ["opt_sing", "opt_dance", "opt_draw", "opt_play", "opt_party", "opt_paint", "opt_watch"],
        hintCopy: "儿童节会唱歌、跳舞、画画、玩游戏、开派对、看节目。"
      },
      {
        id: "step_002",
        type: "choice",
        prompt: "Mina 说：We have fun on Children's Day. 这是什么意思？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g3b_u08_core"],
        corpusSentenceIds: ["sen_g3b_0169"],
        options: [
          { id: "opt_fun", label: "我们玩得很开心" },
          { id: "opt_bed", label: "我们去睡觉" },
          { id: "opt_bus", label: "我们坐公交" }
        ],
        correctOptionIds: ["opt_fun"],
        hintCopy: "fun 是开心和好玩。"
      },
      {
        id: "step_003",
        type: "order",
        prompt: "把儿童节舞台上的活动排好顺序。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g3b_u08_core"],
        corpusSentenceIds: ["sen_g3b_0168", "sen_g3b_0169", "sen_g3b_0170", "sen_g3b_0171", "sen_g3b_0172", "sen_g3b_0173"],
        options: [
          { id: "opt_sing_children", label: "We sing and dance." },
          { id: "opt_draw_children", label: "We draw pictures." },
          { id: "opt_play_children", label: "We play games." },
          { id: "opt_party", label: "We have a class party." },
          { id: "opt_lets_dance", label: "Let's dance." }
        ],
        correctOptionIds: ["opt_sing_children", "opt_draw_children", "opt_play_children", "opt_party", "opt_lets_dance"],
        hintCopy: "先唱歌跳舞，再画画、玩游戏，最后聚会跳舞。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g3b_u08_star", quantity: 1 }]
  },
  {
    id: "task_eng_g3b_u09_main",
    title: "去博物馆的交通",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    chapterId: "arc_eng_g3b_new_town",
    unitId: "unit_eng_g3b_u09",
    corpusVocabularyIds: ["voc_g3b_0104", "voc_g3b_0105", "voc_g3b_0106", "voc_g3b_0107", "voc_g3b_0108", "voc_g3b_0109", "voc_g3b_0110", "voc_g3b_0111", "voc_g3b_0112", "voc_g3b_0113", "voc_g3b_0114", "voc_g3b_0115", "voc_g3b_0116", "voc_g3b_0117"],
    corpusSentenceIds: ["sen_g3b_0188", "sen_g3b_0189", "sen_g3b_0190", "sen_g3b_0191", "sen_g3b_0192", "sen_g3b_0193", "sen_g3b_0194", "sen_g3b_0195", "sen_g3b_0196", "sen_g3b_0197"],
    introCopy: "明天要去博物馆，先把出行方式选好。",
    successCopy: "小交通票已经点亮，大家知道怎么出发了。",
    retryCopy: "再看看 go / by / bus / train 的线索。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "要去 Hunan Museum，Mina 问：How do you go there? 选最合适的回答。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g3b_u09_core"],
        corpusSentenceIds: ["sen_g3b_0188", "sen_g3b_0189", "sen_g3b_0190"],
        options: [
          { id: "opt_by_bus", label: "I go there by bus." },
          { id: "opt_yes_i_am", label: "Yes, I am." },
          { id: "opt_good_night", label: "Good night." }
        ],
        correctOptionIds: ["opt_by_bus"],
        hintCopy: "How do you go there? 可以答 I go there by bus."
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把交通工具和中文意思一次配齐。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g3b_u09_core"],
        corpusVocabularyIds: ["voc_g3b_0201", "voc_g3b_0202", "voc_g3b_0204", "voc_g3b_0205", "voc_g3b_0206", "voc_g3b_0207", "voc_g3b_0208", "voc_g3b_0209"],
        options: [
          { id: "opt_bus", label: "bus → 公共汽车" },
          { id: "opt_underground", label: "underground → 地铁" },
          { id: "opt_ship", label: "ship → 轮船" },
          { id: "opt_train", label: "train → 火车" },
          { id: "opt_taxi", label: "taxi → 出租车" },
          { id: "opt_car", label: "car → 小汽车" },
          { id: "opt_plane", label: "plane → 飞机" },
          { id: "opt_bike", label: "bike → 自行车" }
        ],
        correctOptionIds: ["opt_bus", "opt_underground", "opt_ship", "opt_train", "opt_taxi", "opt_car", "opt_plane", "opt_bike"],
        hintCopy: "bus、underground、ship、train、taxi、car、plane、bike 都是交通方式。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Tim 说：We go there on foot. 这句话是在说什么？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g3b_u09_core"],
        corpusSentenceIds: ["sen_g3b_0191"],
        options: [
          { id: "opt_walk", label: "我们步行去" },
          { id: "opt_sleep", label: "去睡觉" },
          { id: "opt_sing", label: "唱歌" }
        ],
        correctOptionIds: ["opt_walk"],
        hintCopy: "on foot 就是步行。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g3b_u09_star", quantity: 1 }]
  },
  {
    id: "task_eng_g3b_u10_main",
    title: "职业判断与采访",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    chapterId: "arc_eng_g3b_new_town",
    unitId: "unit_eng_g3b_u10",
    corpusVocabularyIds: ["voc_g3b_0118", "voc_g3b_0119", "voc_g3b_0120", "voc_g3b_0121", "voc_g3b_0122", "voc_g3b_0123", "voc_g3b_0124", "voc_g3b_0125", "voc_g3b_0126", "voc_g3b_0127", "voc_g3b_0128", "voc_g3b_0129", "voc_g3b_0130", "voc_g3b_0131"],
    corpusSentenceIds: ["sen_g3b_0212", "sen_g3b_0213", "sen_g3b_0214", "sen_g3b_0215", "sen_g3b_0216", "sen_g3b_0217", "sen_g3b_0218", "sen_g3b_0219", "sen_g3b_0220", "sen_g3b_0221"],
    introCopy: "食品工厂里来了很多朋友，先判断他们的职业。",
    successCopy: "职业徽章点亮了，大家都被介绍清楚了。",
    retryCopy: "再看 Is he/she...? 和职业词的线索。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Mina 问：Is she a driver? 看到食品工厂里的人，正确答案是什么？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g3b_u10_core"],
        corpusSentenceIds: ["sen_g3b_0212", "sen_g3b_0213"],
        options: [
          { id: "opt_farmer", label: "No, she's a farmer." },
          { id: "opt_driver_yes", label: "Yes, she is." },
          { id: "opt_bye", label: "Goodbye." }
        ],
        correctOptionIds: ["opt_farmer"],
        hintCopy: "答案在句子里，she's a farmer。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把职业和人物配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g3b_u10_core"],
        corpusVocabularyIds: ["voc_g3b_0210", "voc_g3b_0213", "voc_g3b_0214", "voc_g3b_0215", "voc_g3b_0216", "voc_g3b_0217", "voc_g3b_0218"],
        options: [
          { id: "opt_driver_job", label: "driver → 驾驶员" },
          { id: "opt_farmer_job", label: "farmer → 农民" },
          { id: "opt_worker_job", label: "worker → 工人" },
          { id: "opt_nurse_job", label: "nurse → 护士" },
          { id: "opt_doctor_job", label: "doctor → 医生" },
          { id: "opt_student_job", label: "student → 学生" },
          { id: "opt_teacher_job", label: "teacher → 教师" }
        ],
        correctOptionIds: ["opt_driver_job", "opt_farmer_job", "opt_worker_job", "opt_nurse_job", "opt_doctor_job", "opt_student_job", "opt_teacher_job"],
        hintCopy: "driver、farmer、worker、nurse、doctor、student、teacher 都是职业。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "如果别人问 What is he?，哪句最合适？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g3b_u10_core"],
        corpusSentenceIds: ["sen_g3b_0220", "sen_g3b_0221"],
        options: [
          { id: "opt_community_worker", label: "He's a community worker." },
          { id: "opt_im_fine", label: "I'm fine." },
          { id: "opt_yes_ido", label: "Yes, I do." }
        ],
        correctOptionIds: ["opt_community_worker"],
        hintCopy: "What is he? 回答职业。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g3b_u10_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4a_u01_main",
    title: "校园开放日导览",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "校园开放日开始了，带新同学认识学校。",
    successCopy: "校园地图点亮了，导览路线清清楚楚。",
    retryCopy: "再看看教室、操场和图书馆的线索。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "校门口写着 Welcome to school! 先带新同学去上课的地方，选哪一句？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4a_u01_core"],
        corpusSentenceIds: ["sen_g4a_0251", "sen_g4a_0252"],
        options: [
          { id: "opt_classroom", label: "This is our classroom." },
          { id: "opt_breakfast", label: "It's time for breakfast." },
          { id: "opt_fireman", label: "I'm a fireman." }
        ],
        correctOptionIds: ["opt_classroom"],
        hintCopy: "classroom 是教室，上课的地方。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把校园地点和用途配成导览卡。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4a_u01_core"],
        corpusVocabularyIds: ["voc_g4a_0219", "voc_g4a_0220", "voc_g4a_0221", "voc_g4a_0222", "voc_g4a_0223", "voc_g4a_0224"],
        corpusSentenceIds: ["sen_g4a_0262", "sen_g4a_0263", "sen_g4a_0264", "sen_g4a_0265"],
        options: [
          { id: "opt_classroom_classes", label: "classroom → have classes" },
          { id: "opt_library_stories", label: "library → read stories" },
          { id: "opt_playground_games", label: "playground → play games" },
          { id: "opt_music_sing", label: "music room → sing" },
          { id: "opt_office_lunch", label: "office → have lunch" }
        ],
        correctOptionIds: ["opt_classroom_classes", "opt_library_stories", "opt_playground_games", "opt_music_sing"],
        hintCopy: "教室上课，图书馆读故事，操场玩游戏，音乐室唱歌。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Dino 问：Is this the art room? 如果不是，哪句回应最合适？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4a_u01_core"],
        corpusSentenceIds: ["sen_g4a_0258", "sen_g4a_0259", "sen_g4a_0260"],
        options: [
          { id: "opt_no_dino", label: "No, Dino!" },
          { id: "opt_me_too", label: "Me too." },
          { id: "opt_go_bed", label: "Go to bed." }
        ],
        correctOptionIds: ["opt_no_dino"],
        hintCopy: "Is this...? 如果不是，可以回答 No。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g4a_u01_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4a_u02_main",
    title: "修复校园作息钟",
    sceneId: "scene_study",
    subjectMix: ["english", "math"],
    recommendedGradeBand: "g3_4",
    introCopy: "校园作息钟慢了一拍，帮大家排好一天。",
    successCopy: "作息钟点亮了，校园节奏回来了。",
    retryCopy: "再看看 get up、breakfast、school 和 bed。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Dongdong 被问：What time do you get up? 他 7:00 起床，选正确回答。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4a_u02_core"],
        corpusSentenceIds: ["sen_g4a_0267", "sen_g4a_0268"],
        options: [
          { id: "opt_get_up_7", label: "I get up at 7:00." },
          { id: "opt_like_dumplings", label: "I like dumplings." },
          { id: "opt_no_it_isnt", label: "No, it isn't." }
        ],
        correctOptionIds: ["opt_get_up_7"],
        hintCopy: "What time do you get up? 回答 I get up at..."
      },
      {
        id: "step_002",
        type: "order",
        prompt: "把作息钟的一天按顺序排好。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4a_u02_core"],
        corpusVocabularyIds: ["voc_g4a_0225", "voc_g4a_0226", "voc_g4a_0227", "voc_g4a_0228", "voc_g4a_0229", "voc_g4a_0230", "voc_g4a_0231"],
        corpusSentenceIds: ["sen_g4a_0277", "sen_g4a_0278", "sen_g4a_0279", "sen_g4a_0280"],
        options: [
          { id: "opt_get_up", label: "get up" },
          { id: "opt_breakfast", label: "have breakfast" },
          { id: "opt_school", label: "go to school" },
          { id: "opt_lunch", label: "have lunch" },
          { id: "opt_bed", label: "go to bed" }
        ],
        correctOptionIds: ["opt_get_up", "opt_breakfast", "opt_school", "opt_lunch", "opt_bed"],
        hintCopy: "先起床吃早饭，再上学吃午饭，晚上睡觉。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "闹钟显示 7:30，提示 Hurry up! 这时最该做什么？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4a_u02_core"],
        corpusSentenceIds: ["sen_g4a_0270", "sen_g4a_0271"],
        options: [
          { id: "opt_have_breakfast", label: "It's time to have breakfast." },
          { id: "opt_read_library", label: "Read stories in the library." },
          { id: "opt_play_fire", label: "Play with fire." }
        ],
        correctOptionIds: ["opt_have_breakfast"],
        hintCopy: "7:30 的句子里说该吃早饭了。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g4a_u02_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4a_u03_main",
    title: "食堂午餐推荐",
    sceneId: "scene_kitchen",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "食堂开饭了，帮同学们选喜欢的午餐。",
    successCopy: "午餐贴纸点亮了，大家都拿到喜欢的食物。",
    retryCopy: "再看 like、dumplings、bread 和 hamburger 的线索。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Mina 说：I'm hungry. I like dumplings. 先给她选什么？",
        anchorId: "anchor_kitchen_cup",
        knowledgeIds: ["kn_eng_g4a_u03_core"],
        corpusSentenceIds: ["sen_g4a_0281", "sen_g4a_0282"],
        options: [
          { id: "opt_dumplings", label: "dumplings" },
          { id: "opt_basketball", label: "basketball" },
          { id: "opt_umbrella", label: "umbrella" }
        ],
        correctOptionIds: ["opt_dumplings"],
        hintCopy: "I like dumplings 表示喜欢水饺。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把午餐卡片和喜欢的人配对。",
        anchorId: "anchor_kitchen_oven",
        knowledgeIds: ["kn_eng_g4a_u03_core"],
        corpusVocabularyIds: ["voc_g4a_0232", "voc_g4a_0233", "voc_g4a_0234"],
        corpusSentenceIds: ["sen_g4a_0284", "sen_g4a_0285", "sen_g4a_0286", "sen_g4a_0287", "sen_g4a_0289"],
        options: [
          { id: "opt_rice_fish_veg", label: "Peter → rice, fish and vegetables" },
          { id: "opt_bread_chicken_veg", label: "bread, chicken and vegetables → lunch tray" },
          { id: "opt_hamburgers", label: "hamburgers → hamburger card" },
          { id: "opt_noodles", label: "noodles → I like noodles" },
          { id: "opt_bread_watch", label: "bread → watch" }
        ],
        correctOptionIds: ["opt_rice_fish_veg", "opt_bread_chicken_veg", "opt_hamburgers", "opt_noodles"],
        hintCopy: "这些句子都在说喜欢的食物。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "如果朋友问 What do you like? 哪句是合适回答？",
        anchorId: "anchor_kitchen_timer",
        knowledgeIds: ["kn_eng_g4a_u03_core"],
        corpusSentenceIds: ["sen_g4a_0283", "sen_g4a_0287", "sen_g4a_0294"],
        options: [
          { id: "opt_i_like_noodles", label: "I like noodles." },
          { id: "opt_be_quiet", label: "Be quiet!" },
          { id: "opt_whose_watch", label: "Whose watch is this?" }
        ],
        correctOptionIds: ["opt_i_like_noodles"],
        hintCopy: "What do you like? 可以回答 I like..."
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g4a_u03_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4a_u04_main",
    title: "动物观察课",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "动物观察课开始了，帮老师整理观察记录。",
    successCopy: "动物相册点亮了，每个观察点都记录好了。",
    retryCopy: "再看看 animal、big、tall、strong 和 cute。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "老师说：Look at the elephant. It's big and tall. 选出这个动物。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4a_u04_core"],
        corpusSentenceIds: ["sen_g4a_0295", "sen_g4a_0296"],
        options: [
          { id: "opt_elephant", label: "elephant" },
          { id: "opt_bread", label: "bread" },
          { id: "opt_library", label: "library" }
        ],
        correctOptionIds: ["opt_elephant"],
        hintCopy: "elephant 是大象，big and tall 是又大又高。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把动物和观察词配好。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4a_u04_core"],
        corpusVocabularyIds: ["voc_g4a_0235", "voc_g4a_0236", "voc_g4a_0237", "voc_g4a_0238", "voc_g4a_0239", "voc_g4a_0240", "voc_g4a_0241", "voc_g4a_0242", "voc_g4a_0243"],
        corpusSentenceIds: ["sen_g4a_0297", "sen_g4a_0298", "sen_g4a_0299", "sen_g4a_0305"],
        options: [
          { id: "opt_tiger_strong", label: "tiger → strong" },
          { id: "opt_panda_cute", label: "panda → cute" },
          { id: "opt_monkey_funny", label: "monkey → funny" },
          { id: "opt_bear_friend", label: "bear → animal friend" },
          { id: "opt_lion_library", label: "lion → library" }
        ],
        correctOptionIds: ["opt_tiger_strong", "opt_panda_cute", "opt_monkey_funny", "opt_bear_friend"],
        hintCopy: "strong、cute、funny 都是动物观察时的描述。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Dino 猜：Is it a lion? 如果不是，看到橙黑相间的动物应答哪句？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4a_u04_core"],
        corpusSentenceIds: ["sen_g4a_0300", "sen_g4a_0301"],
        options: [
          { id: "opt_tiger_right", label: "No, it isn't. It's a tiger." },
          { id: "opt_yes_mother", label: "Yes, she is." },
          { id: "opt_get_up", label: "I get up at 7:00." }
        ],
        correctOptionIds: ["opt_tiger_right"],
        hintCopy: "orange and black 的动物线索指向 tiger。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g4a_u04_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4a_u05_main",
    title: "操场运动挑战",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "操场挑战赛开场了，帮大家登记会做的运动。",
    successCopy: "运动发带点亮了，挑战队伍准备好了。",
    retryCopy: "再看 Can you...? 和 I can / I can't。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "朋友问：Can you play basketball? 如果会，应该怎么回答？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4a_u05_core"],
        corpusSentenceIds: ["sen_g4a_0309", "sen_g4a_0310"],
        options: [
          { id: "opt_yes_can", label: "Yes, I can." },
          { id: "opt_no_isnt", label: "No, it isn't." },
          { id: "opt_i_like_bread", label: "I like bread." }
        ],
        correctOptionIds: ["opt_yes_can"],
        hintCopy: "Can you...? 的肯定回答是 Yes, I can."
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把运动能力和动作配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4a_u05_core"],
        corpusVocabularyIds: ["voc_g4a_0244", "voc_g4a_0245", "voc_g4a_0246", "voc_g4a_0247", "voc_g4a_0248"],
        corpusSentenceIds: ["sen_g4a_0308", "sen_g4a_0313", "sen_g4a_0314", "sen_g4a_0316", "sen_g4a_0320"],
        options: [
          { id: "opt_basketball", label: "play basketball → court" },
          { id: "opt_swim", label: "swim → pool" },
          { id: "opt_football", label: "play football → field" },
          { id: "opt_pingpong", label: "play ping-pong → table" },
          { id: "opt_jump_high", label: "jump high → sports card" },
          { id: "opt_litter", label: "litter → sports card" }
        ],
        correctOptionIds: ["opt_basketball", "opt_swim", "opt_football", "opt_pingpong", "opt_jump_high"],
        hintCopy: "basketball、swim、football、ping-pong 都是运动能力。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Ella 说：I can't jump, but I can run and swim. 她会什么？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4a_u05_core"],
        corpusSentenceIds: ["sen_g4a_0317", "sen_g4a_0320"],
        options: [
          { id: "opt_run_swim", label: "run and swim" },
          { id: "opt_draw_school", label: "draw our school" },
          { id: "opt_read_stories", label: "read stories" }
        ],
        correctOptionIds: ["opt_run_swim"],
        hintCopy: "but 后面说的是她会做的事。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g4a_u05_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4a_u06_main",
    title: "花园近远观察",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "花园观察课到了，分清这些和那些。",
    successCopy: "花园种子点亮了，近处远处都分清了。",
    retryCopy: "再看 these、those、flowers、birds 和 seeds。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "近处有一排花，卡片写 Look at these flowers. 选对应物品。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4a_u06_core"],
        corpusSentenceIds: ["sen_g4a_0321"],
        options: [
          { id: "opt_flowers", label: "these flowers" },
          { id: "opt_watch", label: "this watch" },
          { id: "opt_breakfast", label: "breakfast" }
        ],
        correctOptionIds: ["opt_flowers"],
        hintCopy: "these 指近处的复数，flowers 是花。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把花园里的复数物品配对。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4a_u06_core"],
        corpusVocabularyIds: ["voc_g4a_0249", "voc_g4a_0250", "voc_g4a_0251", "voc_g4a_0252", "voc_g4a_0253", "voc_g4a_0254", "voc_g4a_0255", "voc_g4a_0256"],
        corpusSentenceIds: ["sen_g4a_0322", "sen_g4a_0323", "sen_g4a_0324", "sen_g4a_0327", "sen_g4a_0328", "sen_g4a_0329"],
        options: [
          { id: "opt_those_birds", label: "those → birds" },
          { id: "opt_these_eggs", label: "these → eggs" },
          { id: "opt_flowers_garden", label: "flowers → garden" },
          { id: "opt_seeds_hills", label: "seeds → hills" },
          { id: "opt_bee_tree", label: "bee → flower/tree clue" },
          { id: "opt_job_tree", label: "job → tree" }
        ],
        correctOptionIds: ["opt_those_birds", "opt_these_eggs", "opt_flowers_garden", "opt_seeds_hills", "opt_bee_tree"],
        hintCopy: "these 是这些，those 是那些，birds/eggs/seeds 都是复数。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "谜语说：They have no legs, but they can go far. Oh, they're...? 选答案。",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4a_u06_core"],
        corpusSentenceIds: ["sen_g4a_0327", "sen_g4a_0370", "sen_g4a_0371"],
        options: [
          { id: "opt_seeds", label: "seeds" },
          { id: "opt_policewoman", label: "policewoman" },
          { id: "opt_hamburgers", label: "hamburgers" }
        ],
        correctOptionIds: ["opt_seeds"],
        hintCopy: "这句谜语的答案就是 seeds。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g4a_u06_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4a_u07_main",
    title: "失物招领台",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "失物招领台堆满小物件，帮大家找到主人。",
    successCopy: "小钥匙点亮了，物品都回到主人手里。",
    retryCopy: "再看 Whose...? 和 Jerry's / my 的线索。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "柜台上有手表，问 Whose watch is this? 看见 Jerry，应该怎么说？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4a_u07_core"],
        corpusSentenceIds: ["sen_g4a_0330", "sen_g4a_0331"],
        options: [
          { id: "opt_jerry_watch", label: "It's Jerry's watch." },
          { id: "opt_get_up", label: "I get up at 7:00." },
          { id: "opt_be_quiet", label: "Be quiet!" }
        ],
        correctOptionIds: ["opt_jerry_watch"],
        hintCopy: "Jerry's 表示 Jerry 的。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把失物招领卡配给正确线索。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4a_u07_core"],
        corpusVocabularyIds: ["voc_g4a_0257", "voc_g4a_0258", "voc_g4a_0259", "voc_g4a_0260", "voc_g4a_0261"],
        corpusSentenceIds: ["sen_g4a_0332", "sen_g4a_0333", "sen_g4a_0334", "sen_g4a_0335", "sen_g4a_0336", "sen_g4a_0372"],
        options: [
          { id: "opt_watch_jerry", label: "watch → Jerry's" },
          { id: "opt_bag_zip", label: "bag → Zip your bag" },
          { id: "opt_cap_my", label: "cap → my cap" },
          { id: "opt_key_lost", label: "key → lost-and-found key" },
          { id: "opt_umbrella_lost", label: "umbrella → lost-and-found umbrella" },
          { id: "opt_lunch_key", label: "lunch → key" }
        ],
        correctOptionIds: ["opt_watch_jerry", "opt_bag_zip", "opt_cap_my", "opt_key_lost", "opt_umbrella_lost"],
        hintCopy: "whose 问谁的，bag/key/umbrella 是失物台常见小物。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "如果主人确认：Is this your watch? 应该选哪句？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4a_u07_core"],
        corpusSentenceIds: ["sen_g4a_0332"],
        options: [
          { id: "opt_yes_it_is", label: "Yes, it is. Thank you." },
          { id: "opt_no_tiger", label: "No, it's a tiger." },
          { id: "opt_i_like_rice", label: "I like rice." }
        ],
        correctOptionIds: ["opt_yes_it_is"],
        hintCopy: "确认物品是自己的，可以说 Yes, it is."
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g4a_u07_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4a_u08_main",
    title: "图书馆安静规则",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "图书馆有点吵，帮大家贴好规则书签。",
    successCopy: "安静书签点亮了，图书馆恢复安静。",
    retryCopy: "再看 Don't talk/eat/write/litter 的规则。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "图书馆有人大声聊天，应该贴哪条规则？",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4a_u08_core"],
        corpusSentenceIds: ["sen_g4a_0339", "sen_g4a_0392"],
        options: [
          { id: "opt_dont_talk", label: "Don't talk here." },
          { id: "opt_play_games", label: "Play games on the playground." },
          { id: "opt_i_like_fish", label: "I like fish." }
        ],
        correctOptionIds: ["opt_dont_talk"],
        hintCopy: "Don't talk 表示不要说话。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把校园规则和场景配对。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4a_u08_core"],
        corpusVocabularyIds: ["voc_g4a_0262", "voc_g4a_0263", "voc_g4a_0264", "voc_g4a_0265", "voc_g4a_0266"],
        corpusSentenceIds: ["sen_g4a_0340", "sen_g4a_0341", "sen_g4a_0343", "sen_g4a_0344", "sen_g4a_0346", "sen_g4a_0373", "sen_g4a_0393", "sen_g4a_0394"],
        options: [
          { id: "opt_dont_write", label: "Don't write → on the book" },
          { id: "opt_dont_eat", label: "Don't eat → in class/library" },
          { id: "opt_dont_litter", label: "Don't litter → snack wrapper" },
          { id: "opt_dont_late", label: "Don't be late → school" },
          { id: "opt_say_magic", label: "say → magic words" },
          { id: "opt_take_fire", label: "take → fire" }
        ],
        correctOptionIds: ["opt_dont_write", "opt_dont_eat", "opt_dont_litter", "opt_dont_late", "opt_say_magic"],
        hintCopy: "这些 Don't... 句子都是规则，say magic words 是礼貌用语。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "管理员说 Be quiet! 这句话最适合哪里？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4a_u08_core"],
        corpusSentenceIds: ["sen_g4a_0342", "sen_g4a_0343"],
        options: [
          { id: "opt_library", label: "library" },
          { id: "opt_lunch_tray", label: "lunch tray" },
          { id: "opt_fire_station", label: "fire station" }
        ],
        correctOptionIds: ["opt_library"],
        hintCopy: "Be quiet 是保持安静，图书馆最需要。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g4a_u08_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4a_u09_main",
    title: "欢迎来到我的家",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "朋友邀请你参观家里，帮他介绍每个房间。",
    successCopy: "小房间装饰点亮了，家里的路线介绍好了。",
    retryCopy: "再看 living room、kitchen、bedroom 和 tidy。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "朋友开门说 Welcome to my home! 你进门后看到大房间，选哪句介绍？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4a_u09_core"],
        corpusSentenceIds: ["sen_g4a_0349", "sen_g4a_0350"],
        options: [
          { id: "opt_living_room", label: "This is the living room." },
          { id: "opt_play_basketball", label: "Can you play basketball?" },
          { id: "opt_dont_litter", label: "Don't litter." }
        ],
        correctOptionIds: ["opt_living_room"],
        hintCopy: "living room 是客厅。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把房间和描述配对，做成参观路线。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4a_u09_core"],
        corpusVocabularyIds: ["voc_g4a_0267", "voc_g4a_0268", "voc_g4a_0269", "voc_g4a_0270", "voc_g4a_0271", "voc_g4a_0272", "voc_g4a_0273", "voc_g4a_0274"],
        corpusSentenceIds: ["sen_g4a_0351", "sen_g4a_0352", "sen_g4a_0354", "sen_g4a_0355", "sen_g4a_0357", "sen_g4a_0358", "sen_g4a_0359", "sen_g4a_0374"],
        options: [
          { id: "opt_kitchen_clean", label: "kitchen → clean" },
          { id: "opt_bedroom_tidy", label: "bedroom → tidy" },
          { id: "opt_living_watch_tv", label: "living room → watch TV" },
          { id: "opt_chair_table", label: "chair/table → room things" },
          { id: "opt_house_home", label: "house → home" },
          { id: "opt_tiger_tv", label: "tiger → TV" }
        ],
        correctOptionIds: ["opt_kitchen_clean", "opt_bedroom_tidy", "opt_living_watch_tv", "opt_chair_table", "opt_house_home"],
        hintCopy: "房间词和家具词都属于 home 主题。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Dino 问 Where's their bedroom? 看到那间房时怎么说？",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4a_u09_core"],
        corpusSentenceIds: ["sen_g4a_0355"],
        options: [
          { id: "opt_thats_bedroom", label: "That's their bedroom." },
          { id: "opt_its_jerry_watch", label: "It's Jerry's watch." },
          { id: "opt_hurry_up", label: "Hurry up!" }
        ],
        correctOptionIds: ["opt_thats_bedroom"],
        hintCopy: "Where's...? 问在哪里，That's... 可以指出位置。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g4a_u09_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4a_u10_main",
    title: "家庭职业相册",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "家庭职业相册散开了，帮每张照片写上职业。",
    successCopy: "职业相册页点亮了，照片介绍都完成了。",
    retryCopy: "再看 What's her job? 和职业词。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "相册第一页写 This is my family photo. 问 What's her job? 看到篮球运动员，选回答。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4a_u10_core"],
        corpusSentenceIds: ["sen_g4a_0360", "sen_g4a_0361", "sen_g4a_0362"],
        options: [
          { id: "opt_basketball_player", label: "She's a basketball player." },
          { id: "opt_its_big", label: "It's big and tall." },
          { id: "opt_dont_talk", label: "Don't talk here." }
        ],
        correctOptionIds: ["opt_basketball_player"],
        hintCopy: "What's her job? 问她的职业。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把职业照片和英文职业配对。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4a_u10_core"],
        corpusVocabularyIds: ["voc_g4a_0275", "voc_g4a_0276", "voc_g4a_0277", "voc_g4a_0278", "voc_g4a_0279", "voc_g4a_0280", "voc_g4a_0281", "voc_g4a_0282", "voc_g4a_0283", "voc_g4a_0284"],
        corpusSentenceIds: ["sen_g4a_0363", "sen_g4a_0365", "sen_g4a_0366", "sen_g4a_0367", "sen_g4a_0368", "sen_g4a_0369", "sen_g4a_0395", "sen_g4a_0396"],
        options: [
          { id: "opt_scientist", label: "scientist → 科学家" },
          { id: "opt_policeman", label: "policeman → 警察" },
          { id: "opt_astronaut", label: "astronaut → 宇航员" },
          { id: "opt_fireman", label: "fireman → 消防员" },
          { id: "opt_policewoman", label: "policewoman → 女警察" },
          { id: "opt_artist", label: "artist → drawing dream" },
          { id: "opt_fire_danger", label: "fire → dangerous" },
          { id: "opt_library_job", label: "library → job" }
        ],
        correctOptionIds: ["opt_scientist", "opt_policeman", "opt_astronaut", "opt_fireman", "opt_policewoman", "opt_artist", "opt_fire_danger"],
        hintCopy: "这些都是职业相册或安全故事里的关键词。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "爸爸照片旁的问题是 What's your father's job? 句子说 He's a policeman. 应选哪张卡？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4a_u10_core"],
        corpusSentenceIds: ["sen_g4a_0363", "sen_g4a_0395", "sen_g4a_0396"],
        options: [
          { id: "opt_father_policeman", label: "policeman" },
          { id: "opt_father_dumplings", label: "dumplings" },
          { id: "opt_father_flowers", label: "flowers" }
        ],
        correctOptionIds: ["opt_father_policeman"],
        hintCopy: "He's a policeman 说明职业是 policeman。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g4a_u10_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4b_u01_main",
    title: "出门前找物件",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "出门时间快到了，帮大家把小物件找回来。",
    successCopy: "位置星片点亮了，东西都整理好了。",
    retryCopy: "再看 in、under、on、between、beside 和 behind。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Mingming 问：Where's my blue shirt, Mum? 妈妈说在书包里，选正确回答。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4b_u01_core"],
        corpusSentenceIds: ["sen_g4b_0420", "sen_g4b_0421"],
        options: [
          { id: "opt_in_schoolbag", label: "It's in your schoolbag." },
          { id: "opt_green_light", label: "It's green now." },
          { id: "opt_like_english", label: "I like English." }
        ],
        correctOptionIds: ["opt_in_schoolbag"],
        hintCopy: "in your schoolbag 表示在书包里。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把位置词和物品位置配对。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4b_u01_core"],
        corpusVocabularyIds: ["voc_g4b_0285", "voc_g4b_0286", "voc_g4b_0287", "voc_g4b_0288", "voc_g4b_0289", "voc_g4b_0290", "voc_g4b_0291", "voc_g4b_0292", "voc_g4b_0293"],
        corpusSentenceIds: ["sen_g4b_0422", "sen_g4b_0423", "sen_g4b_0429", "sen_g4b_0430", "sen_g4b_0433", "sen_g4b_0438", "sen_g4b_0441", "sen_g4b_0442", "sen_g4b_0443"],
        options: [
          { id: "opt_under_chair", label: "under → under the chair" },
          { id: "opt_on_head", label: "on → on your head" },
          { id: "opt_between_boxes", label: "between → between the boxes" },
          { id: "opt_beside_books", label: "beside → beside the books" },
          { id: "opt_behind_door", label: "behind → behind the door" },
          { id: "opt_window_door", label: "window / door → room clue" },
          { id: "opt_maths_under", label: "maths → under" }
        ],
        correctOptionIds: ["opt_under_chair", "opt_on_head", "opt_between_boxes", "opt_beside_books", "opt_behind_door", "opt_window_door"],
        hintCopy: "这些词都在说明物品在什么位置。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "如果铅笔盒在桌子下面，Is it under your desk? 应该怎样确认？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4b_u01_core"],
        corpusSentenceIds: ["sen_g4b_0423", "sen_g4b_0424"],
        options: [
          { id: "opt_yes_it_is", label: "Yes, it is." },
          { id: "opt_no_smoking", label: "No smoking." },
          { id: "opt_make_zongzi", label: "Make zongzi." }
        ],
        correctOptionIds: ["opt_yes_it_is"],
        hintCopy: "Is it...? 如果正确，可以答 Yes, it is."
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g4b_u01_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4b_u02_main",
    title: "整理上午课程包",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "上课铃快响了，帮同学整理今天的课程包。",
    successCopy: "课程贴纸点亮了，上午课程准备好了。",
    retryCopy: "再看 English、maths、Chinese、art 和 PE。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Jerry 被问：What classes do you have this morning? 课表是英语、数学、语文和美术。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4b_u02_core"],
        corpusSentenceIds: ["sen_g4b_0445", "sen_g4b_0446"],
        options: [
          { id: "opt_classes_morning", label: "I have English, maths, Chinese and art." },
          { id: "opt_season_winter", label: "My favourite season is winter." },
          { id: "opt_under_chair", label: "It's under the chair." }
        ],
        correctOptionIds: ["opt_classes_morning"],
        hintCopy: "What classes...? 回答今天有什么课。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把课程和对应能力配对。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4b_u02_core"],
        corpusVocabularyIds: ["voc_g4b_0294", "voc_g4b_0295", "voc_g4b_0296", "voc_g4b_0297"],
        corpusSentenceIds: ["sen_g4b_0447", "sen_g4b_0448", "sen_g4b_0449", "sen_g4b_0450", "sen_g4b_0452", "sen_g4b_0453", "sen_g4b_0455", "sen_g4b_0456", "sen_g4b_0673"],
        options: [
          { id: "opt_english_talk_write", label: "English → talk and write" },
          { id: "opt_maths_subject", label: "maths → subject" },
          { id: "opt_pe_subject", label: "PE → subject" },
          { id: "opt_art_drawing", label: "art → drawing and painting" },
          { id: "opt_us_join", label: "us → join us" },
          { id: "opt_phone_subject", label: "phone → subject" }
        ],
        correctOptionIds: ["opt_english_talk_write", "opt_maths_subject", "opt_pe_subject", "opt_art_drawing", "opt_us_join"],
        hintCopy: "这些卡片都和课程或社团邀请有关。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Lingling 被问：What subject do you like? 她喜欢英语，选哪句？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4b_u02_core"],
        corpusSentenceIds: ["sen_g4b_0448"],
        options: [
          { id: "opt_like_english", label: "I like English." },
          { id: "opt_get_points", label: "Class One gets 54 points." },
          { id: "opt_red_light", label: "Look at the red light." }
        ],
        correctOptionIds: ["opt_like_english"],
        hintCopy: "What subject do you like? 回答喜欢的科目。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g4b_u02_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4b_u03_main",
    title: "一周活动计划",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "活动周要开始了，帮大家把星期和活动排好。",
    successCopy: "周历装饰点亮了，一周安排清清楚楚。",
    retryCopy: "再看 today、tomorrow 和 Monday 到 Sunday。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "朋友问：What day is it today? 今天是 Tuesday，选正确回答。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4b_u03_core"],
        corpusSentenceIds: ["sen_g4b_0457"],
        options: [
          { id: "opt_tuesday", label: "It's Tuesday." },
          { id: "opt_fifty_six", label: "It's fifty-six." },
          { id: "opt_snowy", label: "It's snowy." }
        ],
        correctOptionIds: ["opt_tuesday"],
        hintCopy: "What day...? 问星期几。"
      },
      {
        id: "step_002",
        type: "order",
        prompt: "把一周的星期按顺序放进周历。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4b_u03_core"],
        corpusVocabularyIds: ["voc_g4b_0298", "voc_g4b_0299", "voc_g4b_0300", "voc_g4b_0301", "voc_g4b_0302", "voc_g4b_0303", "voc_g4b_0304", "voc_g4b_0305", "voc_g4b_0306", "voc_g4b_0307", "voc_g4b_0308", "voc_g4b_0309"],
        corpusSentenceIds: ["sen_g4b_0458", "sen_g4b_0459", "sen_g4b_0460", "sen_g4b_0461", "sen_g4b_0462", "sen_g4b_0463", "sen_g4b_0464", "sen_g4b_0468"],
        options: [
          { id: "opt_monday", label: "Monday" },
          { id: "opt_tuesday_day", label: "Tuesday" },
          { id: "opt_wednesday", label: "Wednesday" },
          { id: "opt_thursday", label: "Thursday" },
          { id: "opt_friday", label: "Friday" },
          { id: "opt_saturday", label: "Saturday" },
          { id: "opt_sunday", label: "Sunday" }
        ],
        correctOptionIds: ["opt_monday", "opt_tuesday_day", "opt_wednesday", "opt_thursday", "opt_friday", "opt_saturday", "opt_sunday"],
        hintCopy: "从 Monday 到 Sunday 依次排。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Today is Friday. Tomorrow is my birthday. 明天是星期几？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4b_u03_core"],
        corpusSentenceIds: ["sen_g4b_0460", "sen_g4b_0461", "sen_g4b_0467"],
        options: [
          { id: "opt_saturday_answer", label: "Saturday" },
          { id: "opt_monday_answer", label: "Monday" },
          { id: "opt_wednesday_answer", label: "Wednesday" }
        ],
        correctOptionIds: ["opt_saturday_answer"],
        hintCopy: "Friday 的 tomorrow 是 Saturday。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g4b_u03_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4b_u04_main",
    title: "篮球赛计分牌",
    sceneId: "scene_study",
    subjectMix: ["english", "math"],
    recommendedGradeBand: "g3_4",
    introCopy: "篮球赛打得正热闹，帮裁判记录比分。",
    successCopy: "计分牌点亮了，比分和数字都对上了。",
    retryCopy: "再看 point、twenty-one、fifty 和 one hundred。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "比赛记录写着 Class One gets 54 points. 选出一班分数。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4b_u04_core"],
        corpusSentenceIds: ["sen_g4b_0469", "sen_g4b_0472"],
        options: [
          { id: "opt_54", label: "54 points" },
          { id: "opt_52", label: "52 points" },
          { id: "opt_100", label: "100 points" }
        ],
        correctOptionIds: ["opt_54"],
        hintCopy: "Class One 后面的数字是 54。"
      },
      {
        id: "step_002",
        type: "order",
        prompt: "把计分牌数字从小到大排好。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4b_u04_core"],
        corpusVocabularyIds: ["voc_g4b_0310", "voc_g4b_0311", "voc_g4b_0312", "voc_g4b_0313", "voc_g4b_0314", "voc_g4b_0315", "voc_g4b_0316", "voc_g4b_0317", "voc_g4b_0318", "voc_g4b_0319", "voc_g4b_0320", "voc_g4b_0321"],
        corpusSentenceIds: ["sen_g4b_0474", "sen_g4b_0475", "sen_g4b_0476", "sen_g4b_0477", "sen_g4b_0478", "sen_g4b_0479", "sen_g4b_0480", "sen_g4b_0481", "sen_g4b_0482"],
        options: [
          { id: "opt_21", label: "twenty-one" },
          { id: "opt_30", label: "thirty" },
          { id: "opt_40", label: "forty" },
          { id: "opt_50", label: "fifty" },
          { id: "opt_60", label: "sixty" },
          { id: "opt_100_num", label: "one hundred" }
        ],
        correctOptionIds: ["opt_21", "opt_30", "opt_40", "opt_50", "opt_60", "opt_100_num"],
        hintCopy: "从 21、30、40、50、60 到 100。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "图书角有 science books，interesting books。它们属于哪类线索？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4b_u04_core"],
        corpusSentenceIds: ["sen_g4b_0481"],
        options: [
          { id: "opt_book_corner", label: "book corner" },
          { id: "opt_dragon_boat", label: "dragon boat race" },
          { id: "opt_window_clean", label: "cleaning the window" }
        ],
        correctOptionIds: ["opt_book_corner"],
        hintCopy: "science books 和 picture books 都在 book corner。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g4b_u04_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4b_u05_main",
    title: "帮助者墙报",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "校园墙报要介绍帮助者，帮大家贴上正确动作。",
    successCopy: "帮助者徽章点亮了，墙报完成了。",
    retryCopy: "再看 help、teach、learn、hard 和 but。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Miss Li teaches English. 她的工作动作是什么？",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4b_u05_core"],
        corpusSentenceIds: ["sen_g4b_0483", "sen_g4b_0487"],
        options: [
          { id: "opt_teaches_english", label: "teaches English" },
          { id: "opt_picks_flowers", label: "picks flowers" },
          { id: "opt_gets_points", label: "gets 54 points" }
        ],
        correctOptionIds: ["opt_teaches_english"],
        hintCopy: "teach / teaches 都和教课有关。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把帮助者动作和人物卡配对。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4b_u05_core"],
        corpusVocabularyIds: ["voc_g4b_0322", "voc_g4b_0323", "voc_g4b_0324", "voc_g4b_0325", "voc_g4b_0326"],
        corpusSentenceIds: ["sen_g4b_0484", "sen_g4b_0485", "sen_g4b_0486", "sen_g4b_0488", "sen_g4b_0489", "sen_g4b_0490", "sen_g4b_0491", "sen_g4b_0492", "sen_g4b_0493", "sen_g4b_0674"],
        options: [
          { id: "opt_help_students", label: "help → students in need" },
          { id: "opt_learn_english", label: "learn → English" },
          { id: "opt_teach_maths", label: "teach → maths" },
          { id: "opt_work_hard", label: "hard → works hard" },
          { id: "opt_busy_but_happy", label: "but → busy but happy" },
          { id: "opt_her_people", label: "her → she/her clue" },
          { id: "opt_lake_help", label: "lake → help" }
        ],
        correctOptionIds: ["opt_help_students", "opt_learn_english", "opt_teach_maths", "opt_work_hard", "opt_busy_but_happy", "opt_her_people"],
        hintCopy: "墙报主题是帮助、教学、学习和努力工作。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Xiaoxiao's father is busy but happy. Why? 选最贴近的句子。",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4b_u05_core"],
        corpusSentenceIds: ["sen_g4b_0492", "sen_g4b_0493"],
        options: [
          { id: "opt_helps_many", label: "He helps many people in need." },
          { id: "opt_likes_autumn", label: "He likes autumn." },
          { id: "opt_under_bed", label: "He is under the bed." }
        ],
        correctOptionIds: ["opt_helps_many"],
        hintCopy: "句子里说他帮助很多有需要的人。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g4b_u05_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4b_u06_main",
    title: "四季花园换装",
    sceneId: "scene_wardrobe",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "四季花园要换装，帮大家选合适的季节卡。",
    successCopy: "四季花环点亮了，花园换上了合适季节。",
    retryCopy: "再看 favourite、season、spring、summer、autumn、winter。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Mingming 被问：What's your favourite season? 他最喜欢 winter，怎么回答？",
        anchorId: "anchor_wardrobe_mirror",
        knowledgeIds: ["kn_eng_g4b_u06_core"],
        corpusSentenceIds: ["sen_g4b_0498"],
        options: [
          { id: "opt_winter_fav", label: "My favourite season is winter." },
          { id: "opt_class_english", label: "I have English." },
          { id: "opt_on_head", label: "It's on your head." }
        ],
        correctOptionIds: ["opt_winter_fav"],
        hintCopy: "favourite season 是最喜欢的季节。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把季节和天气、衣物或活动配对。",
        anchorId: "anchor_wardrobe_rack",
        knowledgeIds: ["kn_eng_g4b_u06_core"],
        corpusVocabularyIds: ["voc_g4b_0327", "voc_g4b_0328", "voc_g4b_0329", "voc_g4b_0330", "voc_g4b_0331", "voc_g4b_0332", "voc_g4b_0333", "voc_g4b_0334", "voc_g4b_0335"],
        corpusSentenceIds: ["sen_g4b_0494", "sen_g4b_0495", "sen_g4b_0496", "sen_g4b_0497", "sen_g4b_0499", "sen_g4b_0500", "sen_g4b_0501", "sen_g4b_0502", "sen_g4b_0503", "sen_g4b_0504", "sen_g4b_0505"],
        options: [
          { id: "opt_spring_warm", label: "spring → warm" },
          { id: "opt_summer_hot", label: "summer → hot" },
          { id: "opt_autumn_cool", label: "autumn → cool" },
          { id: "opt_winter_snowy", label: "winter → snowy" },
          { id: "opt_careful_snow", label: "careful → Be careful!" },
          { id: "opt_dear_letter", label: "dear → letter" },
          { id: "opt_maths_season", label: "maths → season" }
        ],
        correctOptionIds: ["opt_spring_warm", "opt_summer_hot", "opt_autumn_cool", "opt_winter_snowy", "opt_careful_snow", "opt_dear_letter"],
        hintCopy: "warm、hot、cool、snowy 都能描述季节天气。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "天气是 sunny and hot，适合穿什么？",
        anchorId: "anchor_wardrobe_shoes",
        knowledgeIds: ["kn_eng_g4b_u06_core"],
        corpusSentenceIds: ["sen_g4b_0500"],
        options: [
          { id: "opt_tshirt_shorts", label: "a T-shirt and shorts" },
          { id: "opt_snowman", label: "a snowman" },
          { id: "opt_schoolbag", label: "a schoolbag" }
        ],
        correctOptionIds: ["opt_tshirt_shorts"],
        hintCopy: "hot 的句子里穿 T-shirt and shorts。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g4b_u06_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4b_u07_main",
    title: "窗外风景画卡",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "打开窗户看风景，帮同学完成观察画卡。",
    successCopy: "云朵卡点亮了，风景画卡完成了。",
    retryCopy: "再看 cloud、sun、sky、boat、lake 和 moon。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "朋友问：What can you see? 看到 white clouds，选正确回答。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4b_u07_core"],
        corpusSentenceIds: ["sen_g4b_0506"],
        options: [
          { id: "opt_see_clouds", label: "I can see white clouds." },
          { id: "opt_get_54", label: "I get 54 points." },
          { id: "opt_no_phone", label: "No mobile phone." }
        ],
        correctOptionIds: ["opt_see_clouds"],
        hintCopy: "What can you see? 可以回答 I can see..."
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把风景元素贴到画卡上。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4b_u07_core"],
        corpusVocabularyIds: ["voc_g4b_0336", "voc_g4b_0337", "voc_g4b_0338", "voc_g4b_0339", "voc_g4b_0340", "voc_g4b_0341", "voc_g4b_0342"],
        corpusSentenceIds: ["sen_g4b_0507", "sen_g4b_0508", "sen_g4b_0509", "sen_g4b_0510", "sen_g4b_0511", "sen_g4b_0512", "sen_g4b_0513", "sen_g4b_0514", "sen_g4b_0515", "sen_g4b_0516", "sen_g4b_0517"],
        options: [
          { id: "opt_sun_sky", label: "the sun → blue sky" },
          { id: "opt_boat_river", label: "boat → river" },
          { id: "opt_place_beautiful", label: "place → beautiful" },
          { id: "opt_lake_water", label: "lake → water place" },
          { id: "opt_moon_night", label: "the moon → night sky" },
          { id: "opt_cloud_sky", label: "cloud → sky" },
          { id: "opt_point_sky", label: "point → sky" }
        ],
        correctOptionIds: ["opt_sun_sky", "opt_boat_river", "opt_place_beautiful", "opt_lake_water", "opt_moon_night", "opt_cloud_sky"],
        hintCopy: "这些词都可以出现在风景画里。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "夜晚观察卡写 I can see the moon. I can see many stars. 这是哪里？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4b_u07_core"],
        corpusSentenceIds: ["sen_g4b_0513", "sen_g4b_0514"],
        options: [
          { id: "opt_night_sky", label: "night sky" },
          { id: "opt_book_corner", label: "book corner" },
          { id: "opt_lunch_room", label: "lunch room" }
        ],
        correctOptionIds: ["opt_night_sky"],
        hintCopy: "moon 和 stars 都在 night sky。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g4b_u07_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4b_u08_main",
    title: "校园正在发生的事",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "校园里很热闹，帮大家判断正在发生的事。",
    successCopy: "清洁贴纸点亮了，校园行动都记录好了。",
    retryCopy: "再看 cleaning、sleeping、drinking、walking 和 litter。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Look! What is Dongdong doing? 句子说 Dongdong is drinking water. 选动作。",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4b_u08_core"],
        corpusSentenceIds: ["sen_g4b_0518", "sen_g4b_0519"],
        options: [
          { id: "opt_drinking_water", label: "drinking water" },
          { id: "opt_playing_basketball", label: "playing basketball" },
          { id: "opt_making_zongzi", label: "making zongzi" }
        ],
        correctOptionIds: ["opt_drinking_water"],
        hintCopy: "Dongdong 后面的动作是 drinking water。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把正在发生的动作和人物配对。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4b_u08_core"],
        corpusVocabularyIds: ["voc_g4b_0343", "voc_g4b_0344", "voc_g4b_0345"],
        corpusSentenceIds: ["sen_g4b_0518", "sen_g4b_0519", "sen_g4b_0520", "sen_g4b_0521", "sen_g4b_0522", "sen_g4b_0523", "sen_g4b_0524", "sen_g4b_0525", "sen_g4b_0675"],
        options: [
          { id: "opt_girl_cleaning", label: "girl → cleaning the window" },
          { id: "opt_cat_sleeping", label: "cat → sleeping" },
          { id: "opt_father_exercising", label: "father → exercising" },
          { id: "opt_litter_dirty", label: "litter → dirty" },
          { id: "opt_volunteers_busy", label: "volunteers → busy" },
          { id: "opt_water_drinking", label: "water → drinking" },
          { id: "opt_smoke_dirty", label: "smoke → dirty" }
        ],
        correctOptionIds: ["opt_girl_cleaning", "opt_cat_sleeping", "opt_father_exercising", "opt_litter_dirty", "opt_volunteers_busy", "opt_water_drinking"],
        hintCopy: "现在进行时常见结构是 is/are + 动作 ing。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "草地上有 litter，太 dirty。看到女孩在捡垃圾，应该怎么做？",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4b_u08_core"],
        corpusSentenceIds: ["sen_g4b_0522", "sen_g4b_0523"],
        options: [
          { id: "opt_join_her", label: "Let's go and join her." },
          { id: "opt_hide_door", label: "Hide behind the door." },
          { id: "opt_stop_wait", label: "Stop and wait here." }
        ],
        correctOptionIds: ["opt_join_her"],
        hintCopy: "捡垃圾是清洁行动，可以加入她。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g4b_u08_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4b_u09_main",
    title: "端午活动现场",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "端午节活动开始了，帮大家整理活动卡。",
    successCopy: "龙舟装饰点亮了，端午活动记录好了。",
    retryCopy: "再看 Dragon Boat Festival、race、remember 和 country。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "It is the Dragon Boat Festival. What are they doing? 看到龙舟，选动作。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4b_u09_core"],
        corpusSentenceIds: ["sen_g4b_0526", "sen_g4b_0527"],
        options: [
          { id: "opt_dragon_race", label: "They are having a dragon boat race." },
          { id: "opt_clean_window", label: "They are cleaning the window." },
          { id: "opt_go_school", label: "They go to school." }
        ],
        correctOptionIds: ["opt_dragon_race"],
        hintCopy: "dragon boat race 是赛龙舟。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把端午活动和意义配好。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4b_u09_core"],
        corpusVocabularyIds: ["voc_g4b_0346", "voc_g4b_0347", "voc_g4b_0348", "voc_g4b_0349", "voc_g4b_0350", "voc_g4b_0351", "voc_g4b_0352"],
        corpusSentenceIds: ["sen_g4b_0528", "sen_g4b_0529", "sen_g4b_0530", "sen_g4b_0531", "sen_g4b_0532", "sen_g4b_0533", "sen_g4b_0534"],
        options: [
          { id: "opt_dragon_festival", label: "Dragon Boat Festival → traditional festival" },
          { id: "opt_race_watch", label: "race → watch dragon boat race" },
          { id: "opt_zongzi_remember", label: "zongzi → remember Qu Yuan" },
          { id: "opt_about_book", label: "about → book about Qu Yuan" },
          { id: "opt_country_love", label: "country → loved his country" },
          { id: "opt_festival_fun", label: "festival → have a lot of fun" },
          { id: "opt_phone_festival", label: "phone → festival" }
        ],
        correctOptionIds: ["opt_dragon_festival", "opt_race_watch", "opt_zongzi_remember", "opt_about_book", "opt_country_love", "opt_festival_fun"],
        hintCopy: "端午活动围绕赛龙舟、粽子和纪念屈原。"
      },
      {
        id: "step_003",
        type: "order",
        prompt: "按步骤把 zongzi 制作流程排好。",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4b_u09_core"],
        corpusSentenceIds: ["sen_g4b_0535"],
        options: [
          { id: "opt_prepare", label: "Prepare leaves and fillings" },
          { id: "opt_take_leaves", label: "Take two leaves" },
          { id: "opt_form_cone", label: "Form a cone" },
          { id: "opt_fill", label: "Fill up the cone" },
          { id: "opt_wrap", label: "Wrap it up" },
          { id: "opt_tie", label: "Tie it with a string" }
        ],
        correctOptionIds: ["opt_prepare", "opt_take_leaves", "opt_form_cone", "opt_fill", "opt_wrap", "opt_tie"],
        hintCopy: "先准备材料，再拿叶子、成锥形、填馅、包好、系绳。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g4b_u09_star", quantity: 1 }]
  },
  {
    id: "task_eng_g4b_u10_main",
    title: "校园安全标志",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g3_4",
    introCopy: "校园需要新的安全标志，帮大家把标志放对位置。",
    successCopy: "安全标志牌点亮了，校园提醒都清楚了。",
    retryCopy: "再看 sign、mean、must、phone、smoke 和 pick。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "红灯亮了，标志意思是 Do not cross the street. 我们必须怎么做？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g4b_u10_core"],
        corpusSentenceIds: ["sen_g4b_0536", "sen_g4b_0537"],
        options: [
          { id: "opt_stop_wait", label: "We must stop and wait here." },
          { id: "opt_pick_flower", label: "Pick one flower." },
          { id: "opt_play_phone", label: "Use a mobile phone." }
        ],
        correctOptionIds: ["opt_stop_wait"],
        hintCopy: "red light 和 must stop and wait 配在一起。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把安全标志和含义配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g4b_u10_core"],
        corpusVocabularyIds: ["voc_g4b_0353", "voc_g4b_0354", "voc_g4b_0355", "voc_g4b_0356", "voc_g4b_0357", "voc_g4b_0358"],
        corpusSentenceIds: ["sen_g4b_0538", "sen_g4b_0539", "sen_g4b_0540", "sen_g4b_0541", "sen_g4b_0542", "sen_g4b_0543", "sen_g4b_0544", "sen_g4b_0545"],
        options: [
          { id: "opt_mean_sign", label: "mean → sign meaning" },
          { id: "opt_phone_no", label: "phone → Do not use a mobile phone" },
          { id: "opt_smoke_no", label: "smoke → No smoking" },
          { id: "opt_pick_no", label: "pick → Do not pick flowers" },
          { id: "opt_light_stop", label: "light → stop / go" },
          { id: "opt_must_rule", label: "must → rule" },
          { id: "opt_boat_phone", label: "boat → phone" }
        ],
        correctOptionIds: ["opt_mean_sign", "opt_phone_no", "opt_smoke_no", "opt_pick_no", "opt_light_stop", "opt_must_rule"],
        hintCopy: "安全标志告诉我们可以做什么、不能做什么。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Dino 想摘花，但看到 It means \"Do not pick flowers\"。应该怎么做？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g4b_u10_core"],
        corpusSentenceIds: ["sen_g4b_0544"],
        options: [
          { id: "opt_cannot_pick", label: "Dino cannot pick a flower." },
          { id: "opt_can_swim", label: "Dino can swim here." },
          { id: "opt_can_hide", label: "Dino can hide there." }
        ],
        correctOptionIds: ["opt_cannot_pick"],
        hintCopy: "Do not pick flowers 表示不能摘花。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g4b_u10_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5a_u01_main",
    title: "人物素描卡",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "新老师到了，帮大家按外貌线索找到她。",
    successCopy: "人物素描卡点亮了，外貌线索都整理好了。",
    retryCopy: "再看 tall、long、round、young 和 old。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "What does she look like? 线索说 She has long hair. 选正确素描。",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5a_u01_core"],
        corpusVocabularyIds: ["voc_g5a_0360"],
        corpusSentenceIds: ["sen_g5a_0680", "sen_g5a_0681"],
        options: [
          { id: "opt_long_hair", label: "She has long hair." },
          { id: "opt_round_bag", label: "She has a round bag." },
          { id: "opt_old_hat", label: "She has an old hat." }
        ],
        correctOptionIds: ["opt_long_hair"],
        hintCopy: "long hair 是长头发。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把人物外貌词和线索配好。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5a_u01_core"],
        corpusVocabularyIds: ["voc_g5a_0359", "voc_g5a_0360", "voc_g5a_0361", "voc_g5a_0362", "voc_g5a_0363"],
        corpusSentenceIds: ["sen_g5a_0683", "sen_g5a_0684", "sen_g5a_0686", "sen_g5a_0688"],
        options: [
          { id: "opt_tall_boy", label: "tall → tall boy" },
          { id: "opt_long_hair_pair", label: "long → long hair" },
          { id: "opt_round_face", label: "round → round face" },
          { id: "opt_young_teacher", label: "young → young teacher" },
          { id: "opt_old_man", label: "old → old man" },
          { id: "opt_beef_face", label: "beef → round face" }
        ],
        correctOptionIds: ["opt_tall_boy", "opt_long_hair_pair", "opt_round_face", "opt_young_teacher", "opt_old_man"],
        hintCopy: "外貌词可以描述高矮、头发、脸型和年龄。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "同学问 Is she tall? 素描里她又高又年轻，选合适回答。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5a_u01_core"],
        corpusSentenceIds: ["sen_g5a_0683", "sen_g5a_0684"],
        options: [
          { id: "opt_yes_tall", label: "Yes. She is tall and young." },
          { id: "opt_no_food", label: "No. I'd like a hamburger." },
          { id: "opt_go_bus", label: "I go there by bus." }
        ],
        correctOptionIds: ["opt_yes_tall"],
        hintCopy: "问外貌时，要用人物描述回答。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g5a_u01_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5a_u02_main",
    title: "小餐厅点餐",
    sceneId: "scene_kitchen",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "小餐厅开始营业，帮朋友把订单点准确。",
    successCopy: "餐厅菜单点亮了，订单都送到桌上了。",
    retryCopy: "再看 I'd like、hamburger、Coke、sandwich 和 beef。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "顾客说 I'd like a hamburger and a Coke. 选正确餐盘。",
        anchorId: "anchor_kitchen_cup",
        knowledgeIds: ["kn_eng_g5a_u02_core"],
        corpusVocabularyIds: ["voc_g5a_0364", "voc_g5a_0365"],
        corpusSentenceIds: ["sen_g5a_0689", "sen_g5a_0690"],
        options: [
          { id: "opt_burger_coke", label: "hamburger + Coke" },
          { id: "opt_beef_soup", label: "beef + soup" },
          { id: "opt_marker_glue", label: "marker + glue" }
        ],
        correctOptionIds: ["opt_burger_coke"],
        hintCopy: "I'd like 表示“我想要”。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把菜单词和餐厅物品配对。",
        anchorId: "anchor_kitchen_oven",
        knowledgeIds: ["kn_eng_g5a_u02_core"],
        corpusVocabularyIds: ["voc_g5a_0364", "voc_g5a_0365", "voc_g5a_0366", "voc_g5a_0367", "voc_g5a_0368"],
        corpusSentenceIds: ["sen_g5a_0691", "sen_g5a_0692", "sen_g5a_0693", "sen_g5a_0694", "sen_g5a_0695"],
        options: [
          { id: "opt_hamburger_food", label: "hamburger → food" },
          { id: "opt_coke_drink", label: "Coke → drink" },
          { id: "opt_sandwich_food", label: "sandwich → food" },
          { id: "opt_beef_food", label: "beef → food" },
          { id: "opt_food_menu", label: "food → menu" },
          { id: "opt_round_coke", label: "round → Coke" }
        ],
        correctOptionIds: ["opt_hamburger_food", "opt_coke_drink", "opt_sandwich_food", "opt_beef_food", "opt_food_menu"],
        hintCopy: "hamburger、sandwich、beef 都是 food，Coke 是饮料。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "服务员问 What would you like? 想要牛肉三明治，怎么说？",
        anchorId: "anchor_kitchen_timer",
        knowledgeIds: ["kn_eng_g5a_u02_core"],
        corpusSentenceIds: ["sen_g5a_0696", "sen_g5a_0697", "sen_g5a_0698", "sen_g5a_0699"],
        options: [
          { id: "opt_like_sandwich", label: "I'd like a beef sandwich." },
          { id: "opt_like_pet", label: "Can I have a pet?" },
          { id: "opt_like_sign", label: "What does that sign mean?" }
        ],
        correctOptionIds: ["opt_like_sandwich"],
        hintCopy: "点餐回答可用 I'd like + 食物。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g5a_u02_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5a_u03_main",
    title: "家庭午餐分餐",
    sceneId: "scene_kitchen",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "午餐桌准备好了，帮家人分好 rice 和 soup。",
    successCopy: "午餐碗点亮了，大家都拿到了想吃的食物。",
    retryCopy: "再看 rice、soup、vegetable、tomato 和 potato。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Grandma asks: Do you want some rice? 想要米饭时选什么？",
        anchorId: "anchor_kitchen_cup",
        knowledgeIds: ["kn_eng_g5a_u03_core"],
        corpusSentenceIds: ["sen_g5a_0700", "sen_g5a_0701"],
        options: [
          { id: "opt_yes_rice", label: "Yes, please." },
          { id: "opt_no_marker", label: "No, I want a marker." },
          { id: "opt_bus_rice", label: "By bus." }
        ],
        correctOptionIds: ["opt_yes_rice"],
        hintCopy: "别人询问是否要食物，想要可以说 Yes, please."
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把午餐词放到正确餐盘。",
        anchorId: "anchor_kitchen_oven",
        knowledgeIds: ["kn_eng_g5a_u03_core"],
        corpusVocabularyIds: ["voc_g5a_0369", "voc_g5a_0370", "voc_g5a_0371", "voc_g5a_0372", "voc_g5a_0373", "voc_g5a_0374"],
        corpusSentenceIds: ["sen_g5a_0702", "sen_g5a_0703", "sen_g5a_0704", "sen_g5a_0705", "sen_g5a_0706", "sen_g5a_0707"],
        options: [
          { id: "opt_breakfast_morning", label: "breakfast → morning meal" },
          { id: "opt_lunch_noon", label: "lunch → noon meal" },
          { id: "opt_soup_bowl", label: "soup → bowl" },
          { id: "opt_tomato_vegetable", label: "tomato → vegetable" },
          { id: "opt_potato_vegetable", label: "potato → vegetable" },
          { id: "opt_vegetable_plate", label: "vegetable → plate" },
          { id: "opt_pet_soup", label: "pet → soup" }
        ],
        correctOptionIds: ["opt_breakfast_morning", "opt_lunch_noon", "opt_soup_bowl", "opt_tomato_vegetable", "opt_potato_vegetable", "opt_vegetable_plate"],
        hintCopy: "午餐词里有餐次、汤和蔬菜。"
      },
      {
        id: "step_003",
        type: "drag",
        prompt: "把 family lunch 托盘里的食物一次选齐。",
        anchorId: "anchor_kitchen_timer",
        knowledgeIds: ["kn_eng_g5a_u03_core"],
        corpusSentenceIds: ["sen_g5a_0708", "sen_g5a_0709", "sen_g5a_0710"],
        options: [
          { id: "opt_rice_soup", label: "rice and soup" },
          { id: "opt_tomato_potato", label: "tomato and potato" },
          { id: "opt_coke_marker", label: "Coke and marker" }
        ],
        correctOptionIds: ["opt_rice_soup"],
        hintCopy: "午餐托盘先选主食和汤。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g5a_u03_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5a_u04_main",
    title: "借文具画风筝",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "风筝草图缺文具，帮 Leo 礼貌地借到工具。",
    successCopy: "文具盒点亮了，风筝草图完成了。",
    retryCopy: "再看 Can I use、borrow、dictionary、marker 和 glue。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "想借铅笔时，哪句最礼貌？",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5a_u04_core"],
        corpusSentenceIds: ["sen_g5a_0711", "sen_g5a_0712"],
        options: [
          { id: "opt_use_pencil", label: "Can I use your pencil, please?" },
          { id: "opt_want_rice", label: "Do you want some rice?" },
          { id: "opt_old_round", label: "She has a round face." }
        ],
        correctOptionIds: ["opt_use_pencil"],
        hintCopy: "请求使用别人物品时可以说 Can I use your...?"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把文具和用途配好。",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5a_u04_core"],
        corpusVocabularyIds: ["voc_g5a_0375", "voc_g5a_0376", "voc_g5a_0377", "voc_g5a_0378"],
        corpusSentenceIds: ["sen_g5a_0713", "sen_g5a_0714", "sen_g5a_0715", "sen_g5a_0716", "sen_g5a_0717"],
        options: [
          { id: "opt_borrow_ask", label: "borrow → ask to use" },
          { id: "opt_dictionary_words", label: "dictionary → words" },
          { id: "opt_marker_draw", label: "marker → draw" },
          { id: "opt_glue_stick", label: "glue → stick paper" },
          { id: "opt_beef_draw", label: "beef → draw" }
        ],
        correctOptionIds: ["opt_borrow_ask", "opt_dictionary_words", "opt_marker_draw", "opt_glue_stick"],
        hintCopy: "dictionary 查词，marker 画线，glue 粘贴。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "对方把 marker 借给你，哪句回应最合适？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5a_u04_core"],
        corpusSentenceIds: ["sen_g5a_0718", "sen_g5a_0719", "sen_g5a_0720", "sen_g5a_0721"],
        options: [
          { id: "opt_thank_you", label: "Thank you." },
          { id: "opt_no_smoking", label: "No smoking." },
          { id: "opt_by_plane", label: "By plane." }
        ],
        correctOptionIds: ["opt_thank_you"],
        hintCopy: "别人帮助你后，要表达感谢。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g5a_u04_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5a_u05_main",
    title: "宠物店小名牌",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "宠物店来了新朋友，帮 Coco 选合适的照顾卡。",
    successCopy: "宠物名牌点亮了，小宠物照顾好了。",
    retryCopy: "再看 pet、rabbit、basket 和 lovely。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "想问能不能养一只宠物，选哪句？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5a_u05_core"],
        corpusSentenceIds: ["sen_g5a_0722", "sen_g5a_0723"],
        options: [
          { id: "opt_have_pet", label: "Can I have a pet?" },
          { id: "opt_use_marker", label: "Can I use your marker?" },
          { id: "opt_get_up", label: "What time do you get up?" }
        ],
        correctOptionIds: ["opt_have_pet"],
        hintCopy: "Can I have...? 可以用来请求拥有某物。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把宠物店词汇和照顾物品配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5a_u05_core"],
        corpusVocabularyIds: ["voc_g5a_0379", "voc_g5a_0380", "voc_g5a_0381", "voc_g5a_0382"],
        corpusSentenceIds: ["sen_g5a_0724", "sen_g5a_0725", "sen_g5a_0726", "sen_g5a_0727"],
        options: [
          { id: "opt_pet_friend", label: "pet → animal friend" },
          { id: "opt_rabbit_pet", label: "rabbit → pet" },
          { id: "opt_basket_home", label: "basket → pet bed" },
          { id: "opt_lovely_pet", label: "lovely → cute" },
          { id: "opt_raincoat_pet", label: "raincoat → pet bed" }
        ],
        correctOptionIds: ["opt_pet_friend", "opt_rabbit_pet", "opt_basket_home", "opt_lovely_pet"],
        hintCopy: "rabbit 可以是 pet，basket 可以当小窝。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "看到兔子很可爱，描述卡应该选哪句？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5a_u05_core"],
        corpusSentenceIds: ["sen_g5a_0728", "sen_g5a_0729"],
        options: [
          { id: "opt_lovely_rabbit", label: "It is a lovely rabbit." },
          { id: "opt_old_sign", label: "It is an old sign." },
          { id: "opt_big_lesson", label: "It is a maths lesson." }
        ],
        correctOptionIds: ["opt_lovely_rabbit"],
        hintCopy: "lovely 可以描述可爱的兔子。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g5a_u05_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5a_u06_main",
    title: "雨天雨具选择",
    sceneId: "scene_wardrobe",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "雨天出门前，帮大家挑合适的雨衣和伞。",
    successCopy: "雨衣点亮了，雨天装备都选好了。",
    retryCopy: "再看 which、raincoat、thick、thin、jacket 和 umbrella。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "朋友问 Which one do you want? 天冷下雨，选哪件？",
        anchorId: "anchor_wardrobe_rack",
        knowledgeIds: ["kn_eng_g5a_u06_core"],
        corpusVocabularyIds: ["voc_g5a_0383", "voc_g5a_0384", "voc_g5a_0385"],
        corpusSentenceIds: ["sen_g5a_0730", "sen_g5a_0731"],
        options: [
          { id: "opt_thick_raincoat", label: "the thick raincoat" },
          { id: "opt_thin_sandwich", label: "the thin sandwich" },
          { id: "opt_round_face", label: "the round face" }
        ],
        correctOptionIds: ["opt_thick_raincoat"],
        hintCopy: "cold rainy day 适合 thick raincoat。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把衣物和描述词配好。",
        anchorId: "anchor_wardrobe_mirror",
        knowledgeIds: ["kn_eng_g5a_u06_core"],
        corpusVocabularyIds: ["voc_g5a_0384", "voc_g5a_0385", "voc_g5a_0386", "voc_g5a_0387", "voc_g5a_0388", "voc_g5a_0389"],
        corpusSentenceIds: ["sen_g5a_0732", "sen_g5a_0733", "sen_g5a_0734", "sen_g5a_0735", "sen_g5a_0736", "sen_g5a_0737"],
        options: [
          { id: "opt_raincoat_rain", label: "raincoat → rainy day" },
          { id: "opt_thick_warm", label: "thick → warm" },
          { id: "opt_thin_light", label: "thin → light" },
          { id: "opt_jacket_clothes", label: "jacket → clothes" },
          { id: "opt_umbrella_rain", label: "umbrella → rain" },
          { id: "opt_old_not_new", label: "old → not new" },
          { id: "opt_pet_rain", label: "pet → rain" }
        ],
        correctOptionIds: ["opt_raincoat_rain", "opt_thick_warm", "opt_thin_light", "opt_jacket_clothes", "opt_umbrella_rain", "opt_old_not_new"],
        hintCopy: "which one 问选择，thick/thin 用来比较厚薄。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "看到一把旧伞和一件新夹克，想要夹克怎么回答？",
        anchorId: "anchor_wardrobe_shoes",
        knowledgeIds: ["kn_eng_g5a_u06_core"],
        corpusSentenceIds: ["sen_g5a_0738", "sen_g5a_0739", "sen_g5a_0740"],
        options: [
          { id: "opt_new_jacket", label: "I want the new jacket." },
          { id: "opt_old_umbrella", label: "I want the old umbrella." },
          { id: "opt_clean_window", label: "I am cleaning the window." }
        ],
        correctOptionIds: ["opt_new_jacket"],
        hintCopy: "选择夹克时要说 jacket。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g5a_u06_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5a_u07_main",
    title: "城市作息采访",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "小记者要采访作息时间，帮他排好一天流程。",
    successCopy: "采访本点亮了，作息时间线完成了。",
    retryCopy: "再看 get up、go to bed、timetable、lesson、PE 和 maths。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "采访问题是 What time do you get up? 选回答。",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5a_u07_core"],
        corpusVocabularyIds: ["voc_g5a_0390"],
        corpusSentenceIds: ["sen_g5a_0741", "sen_g5a_0742"],
        options: [
          { id: "opt_get_up_time", label: "I get up at 7:00." },
          { id: "opt_have_pet", label: "I have a pet." },
          { id: "opt_no_smoke", label: "It means No smoking." }
        ],
        correctOptionIds: ["opt_get_up_time"],
        hintCopy: "What time 问时间，回答用 at + 时间。"
      },
      {
        id: "step_002",
        type: "order",
        prompt: "按一天作息把采访卡排好。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5a_u07_core"],
        corpusVocabularyIds: ["voc_g5a_0390", "voc_g5a_0391", "voc_g5a_0392", "voc_g5a_0393"],
        corpusSentenceIds: ["sen_g5a_0743", "sen_g5a_0744", "sen_g5a_0745", "sen_g5a_0746", "sen_g5a_0747"],
        options: [
          { id: "opt_get_up", label: "get up" },
          { id: "opt_lessons", label: "have lessons" },
          { id: "opt_computer", label: "use the computer" },
          { id: "opt_go_bed", label: "go to bed" }
        ],
        correctOptionIds: ["opt_get_up", "opt_lessons", "opt_computer", "opt_go_bed"],
        hintCopy: "先起床，再上课和活动，最后睡觉。"
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把课程词和 timetable 配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5a_u07_core"],
        corpusVocabularyIds: ["voc_g5a_0392", "voc_g5a_0394", "voc_g5a_0395", "voc_g5a_0396", "voc_g5a_0397"],
        corpusSentenceIds: ["sen_g5a_0748", "sen_g5a_0749", "sen_g5a_0750", "sen_g5a_0751", "sen_g5a_0752", "sen_g5a_0753", "sen_g5a_0795"],
        options: [
          { id: "opt_timetable_plan", label: "timetable → class plan" },
          { id: "opt_lesson_class", label: "lesson → class" },
          { id: "opt_pe_sport", label: "PE → sport lesson" },
          { id: "opt_art_draw", label: "art → drawing lesson" },
          { id: "opt_maths_numbers", label: "maths → numbers lesson" },
          { id: "opt_umbrella_lesson", label: "umbrella → lesson" }
        ],
        correctOptionIds: ["opt_timetable_plan", "opt_lesson_class", "opt_pe_sport", "opt_art_draw", "opt_maths_numbers"],
        hintCopy: "PE、art、maths 都可以出现在 timetable 上。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g5a_u07_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5a_u08_main",
    title: "家务小队清单",
    sceneId: "scene_kitchen",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "Lingling 在帮父母做家务，帮她勾好清单。",
    successCopy: "家务徽章点亮了，家里变整洁了。",
    retryCopy: "再看 make、iron、clean、meal、water、plant 和 wash。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Lingling helps her parents. 看到脏衣服，应该选哪项家务？",
        anchorId: "anchor_kitchen_cup",
        knowledgeIds: ["kn_eng_g5a_u08_core"],
        corpusVocabularyIds: ["voc_g5a_0404"],
        corpusSentenceIds: ["sen_g5a_0754", "sen_g5a_0755"],
        options: [
          { id: "opt_wash_clothes", label: "wash clothes" },
          { id: "opt_collect_stamp", label: "collect stamps" },
          { id: "opt_pick_flowers", label: "pick flowers" }
        ],
        correctOptionIds: ["opt_wash_clothes"],
        hintCopy: "wash 可用于洗衣服、洗手等清洁动作。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把家务动作和对象配好。",
        anchorId: "anchor_kitchen_oven",
        knowledgeIds: ["kn_eng_g5a_u08_core"],
        corpusVocabularyIds: ["voc_g5a_0398", "voc_g5a_0399", "voc_g5a_0400", "voc_g5a_0401", "voc_g5a_0402", "voc_g5a_0403", "voc_g5a_0404"],
        corpusSentenceIds: ["sen_g5a_0756", "sen_g5a_0757", "sen_g5a_0758", "sen_g5a_0759", "sen_g5a_0760", "sen_g5a_0761"],
        options: [
          { id: "opt_make_meal", label: "make → meal" },
          { id: "opt_iron_clothes", label: "iron → clothes" },
          { id: "opt_clean_room", label: "clean → room" },
          { id: "opt_water_plant", label: "water → plant" },
          { id: "opt_wash_clothes_pair", label: "wash → clothes" },
          { id: "opt_meal_food", label: "meal → food" },
          { id: "opt_sign_plant", label: "sign → plant" }
        ],
        correctOptionIds: ["opt_make_meal", "opt_iron_clothes", "opt_clean_room", "opt_water_plant", "opt_wash_clothes_pair", "opt_meal_food"],
        hintCopy: "家务动作常和具体对象一起出现。"
      },
      {
        id: "step_003",
        type: "order",
        prompt: "把晚餐前的家务顺序排好。",
        anchorId: "anchor_kitchen_timer",
        knowledgeIds: ["kn_eng_g5a_u08_core"],
        corpusSentenceIds: ["sen_g5a_0762", "sen_g5a_0796"],
        options: [
          { id: "opt_clean_table", label: "clean the table" },
          { id: "opt_make_meal_order", label: "make a meal" },
          { id: "opt_wash_hands", label: "wash hands" },
          { id: "opt_have_dinner", label: "have dinner" }
        ],
        correctOptionIds: ["opt_clean_table", "opt_make_meal_order", "opt_wash_hands", "opt_have_dinner"],
        hintCopy: "先整理和做饭，饭前洗手，再吃晚饭。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g5a_u08_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5a_u09_main",
    title: "兴趣展台布置",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "小镇要办兴趣展，帮每个展台放对收藏。",
    successCopy: "收藏册点亮了，兴趣展可以开幕了。",
    retryCopy: "再看 hobby、photo、chess、collect、stamp、storybook 和 violin。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "别人问 What's your hobby? 喜欢拍照，选哪句？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5a_u09_core"],
        corpusVocabularyIds: ["voc_g5a_0405", "voc_g5a_0406"],
        corpusSentenceIds: ["sen_g5a_0763", "sen_g5a_0764"],
        options: [
          { id: "opt_like_photos", label: "I like taking photos." },
          { id: "opt_like_soup", label: "I like soup." },
          { id: "opt_like_sign", label: "I mean this sign." }
        ],
        correctOptionIds: ["opt_like_photos"],
        hintCopy: "hobby 问兴趣爱好，拍照可说 taking photos。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把兴趣展品和活动配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5a_u09_core"],
        corpusVocabularyIds: ["voc_g5a_0405", "voc_g5a_0406", "voc_g5a_0407", "voc_g5a_0408", "voc_g5a_0409", "voc_g5a_0410", "voc_g5a_0411"],
        corpusSentenceIds: ["sen_g5a_0765", "sen_g5a_0766", "sen_g5a_0767", "sen_g5a_0768", "sen_g5a_0769"],
        options: [
          { id: "opt_photo_take", label: "photo → take photos" },
          { id: "opt_chess_play", label: "chess → play chess" },
          { id: "opt_collect_stamp", label: "collect → stamps" },
          { id: "opt_storybook_read", label: "storybook → read stories" },
          { id: "opt_violin_play", label: "violin → play the violin" },
          { id: "opt_hobby_like", label: "hobby → like doing" },
          { id: "opt_glue_chess", label: "glue → play chess" }
        ],
        correctOptionIds: ["opt_photo_take", "opt_chess_play", "opt_collect_stamp", "opt_storybook_read", "opt_violin_play", "opt_hobby_like"],
        hintCopy: "兴趣常用 like + doing 来表达。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "展台写着 I collect stamps. 应该放什么？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5a_u09_core"],
        corpusSentenceIds: ["sen_g5a_0770"],
        options: [
          { id: "opt_stamp_album", label: "stamp album" },
          { id: "opt_raincoat_rack", label: "raincoat rack" },
          { id: "opt_soup_bowl", label: "soup bowl" }
        ],
        correctOptionIds: ["opt_stamp_album"],
        hintCopy: "collect stamps 是集邮。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g5a_u09_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5a_u10_main",
    title: "标志巡查证",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "电影院和公园要巡查标志，帮大家读懂提醒。",
    successCopy: "小巡查证点亮了，公共标志都放好了。",
    retryCopy: "再看 sign、mean、talk、fish、pick、smoke 和 spit。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "看到电影院标志 No talking. 它表示什么？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5a_u10_core"],
        corpusVocabularyIds: ["voc_g5a_0412", "voc_g5a_0413", "voc_g5a_0414"],
        corpusSentenceIds: ["sen_g5a_0771", "sen_g5a_0772"],
        options: [
          { id: "opt_no_talking", label: "Do not talk here." },
          { id: "opt_talk_loudly", label: "Talk loudly here." },
          { id: "opt_make_meal", label: "Make a meal here." }
        ],
        correctOptionIds: ["opt_no_talking"],
        hintCopy: "No talking 表示不能说话。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把标志词和禁止行为配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5a_u10_core"],
        corpusVocabularyIds: ["voc_g5a_0412", "voc_g5a_0413", "voc_g5a_0414", "voc_g5a_0415", "voc_g5a_0416", "voc_g5a_0417", "voc_g5a_0418"],
        corpusSentenceIds: ["sen_g5a_0773", "sen_g5a_0774", "sen_g5a_0775", "sen_g5a_0776", "sen_g5a_0777"],
        options: [
          { id: "opt_sign_rule", label: "sign → rule" },
          { id: "opt_mean_explain", label: "mean → explain" },
          { id: "opt_talk_no", label: "talk → No talking" },
          { id: "opt_fish_no", label: "fish → No fishing" },
          { id: "opt_pick_no", label: "pick → Do not pick flowers" },
          { id: "opt_smoke_no", label: "smoke → No smoking" },
          { id: "opt_spit_no", label: "spit → No spitting" },
          { id: "opt_violin_no", label: "violin → No fishing" }
        ],
        correctOptionIds: ["opt_sign_rule", "opt_mean_explain", "opt_talk_no", "opt_fish_no", "opt_pick_no", "opt_smoke_no", "opt_spit_no"],
        hintCopy: "标志通常提醒我们哪些行为不能做。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "公园草地旁写着 Do not pick flowers. 应该怎么做？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5a_u10_core"],
        corpusSentenceIds: ["sen_g5a_0778"],
        options: [
          { id: "opt_leave_flowers", label: "Leave the flowers there." },
          { id: "opt_pick_flowers", label: "Pick the flowers." },
          { id: "opt_spit_here", label: "Spit here." }
        ],
        correctOptionIds: ["opt_leave_flowers"],
        hintCopy: "Do not pick flowers 表示不要摘花。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g5a_u10_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5a_u11_main",
    title: "道歉和情绪卡",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "邻居被吵到了，帮大家安静下来并说对话。",
    successCopy: "和好贴纸点亮了，大家的心情平静了。",
    retryCopy: "再看 loudly、noise、unhappy、proud、excited、sad 和 shy。",
    estimatedMinutes: 5,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "制造了 noise，让别人 unhappy，应该先说什么？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5a_u11_core"],
        corpusVocabularyIds: ["voc_g5a_0420", "voc_g5a_0421"],
        corpusSentenceIds: ["sen_g5a_0779", "sen_g5a_0780"],
        options: [
          { id: "opt_im_sorry", label: "I'm sorry." },
          { id: "opt_im_proud", label: "I'm proud." },
          { id: "opt_no_fishing", label: "No fishing." }
        ],
        correctOptionIds: ["opt_im_sorry"],
        hintCopy: "打扰别人后要先道歉。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把情绪和场景配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5a_u11_core"],
        corpusVocabularyIds: ["voc_g5a_0419", "voc_g5a_0420", "voc_g5a_0421", "voc_g5a_0422", "voc_g5a_0423", "voc_g5a_0424", "voc_g5a_0425"],
        corpusSentenceIds: ["sen_g5a_0781", "sen_g5a_0782", "sen_g5a_0783", "sen_g5a_0784", "sen_g5a_0785"],
        options: [
          { id: "opt_loudly_noise", label: "loudly → noise" },
          { id: "opt_unhappy_sad", label: "unhappy → sad" },
          { id: "opt_proud_good", label: "proud → did well" },
          { id: "opt_excited_party", label: "excited → party news" },
          { id: "opt_sad_cry", label: "sad → crying" },
          { id: "opt_shy_quiet", label: "shy → quiet with others" },
          { id: "opt_smoke_proud", label: "smoke → proud" }
        ],
        correctOptionIds: ["opt_loudly_noise", "opt_unhappy_sad", "opt_proud_good", "opt_excited_party", "opt_sad_cry", "opt_shy_quiet"],
        hintCopy: "情绪词可以帮助判断人物状态。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "朋友小声说 sorry 后，你想和好，选哪句回应？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5a_u11_core"],
        corpusSentenceIds: ["sen_g5a_0786"],
        options: [
          { id: "opt_thats_ok", label: "That's OK." },
          { id: "opt_get_up", label: "Get up at 7:00." },
          { id: "opt_collect_stamp", label: "Collect stamps." }
        ],
        correctOptionIds: ["opt_thats_ok"],
        hintCopy: "接受道歉可以说 That's OK."
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g5a_u11_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5a_u12_main",
    title: "春节团圆集市",
    sceneId: "scene_kitchen",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "春节集市要开了，帮大家准备团圆活动。",
    successCopy: "红灯笼点亮了，春节集市热闹开场。",
    retryCopy: "再看 Spring Festival、eve、reunion、packet、lion dance 和 fun。",
    estimatedMinutes: 8,
    steps: [
      {
        id: "step_001",
        type: "order",
        prompt: "按春节准备流程排序。",
        anchorId: "anchor_kitchen_oven",
        knowledgeIds: ["kn_eng_g5a_u12_core"],
        corpusVocabularyIds: ["voc_g5a_0426", "voc_g5a_0427", "voc_g5a_0428", "voc_g5a_0429", "voc_g5a_0430"],
        corpusSentenceIds: ["sen_g5a_0787", "sen_g5a_0788", "sen_g5a_0789", "sen_g5a_0790"],
        options: [
          { id: "opt_clean_house", label: "clean the house" },
          { id: "opt_festival_eve", label: "prepare on the eve" },
          { id: "opt_reunion_dinner", label: "have a reunion dinner" },
          { id: "opt_delicious_food", label: "share delicious food" }
        ],
        correctOptionIds: ["opt_clean_house", "opt_festival_eve", "opt_reunion_dinner", "opt_delicious_food"],
        hintCopy: "先打扫和准备，再吃团圆饭。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把春节活动和物品配对。",
        anchorId: "anchor_kitchen_cup",
        knowledgeIds: ["kn_eng_g5a_u12_core"],
        corpusVocabularyIds: ["voc_g5a_0426", "voc_g5a_0429", "voc_g5a_0430", "voc_g5a_0431", "voc_g5a_0432", "voc_g5a_0433"],
        corpusSentenceIds: ["sen_g5a_0791", "sen_g5a_0792", "sen_g5a_0793", "sen_g5a_0794"],
        options: [
          { id: "opt_spring_festival", label: "Spring Festival → holiday" },
          { id: "opt_reunion_family", label: "reunion → family together" },
          { id: "opt_packet_money", label: "packet → red packet" },
          { id: "opt_lion_dance", label: "lion dance → festival show" },
          { id: "opt_fun_happy", label: "fun → happy activity" },
          { id: "opt_delicious_food_pair", label: "delicious → food" },
          { id: "opt_chess_packet", label: "chess → red packet" }
        ],
        correctOptionIds: ["opt_spring_festival", "opt_reunion_family", "opt_packet_money", "opt_lion_dance", "opt_fun_happy", "opt_delicious_food_pair"],
        hintCopy: "春节线索包括团圆饭、红包和舞狮。"
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把复习展台里的句型线索配回主题。",
        anchorId: "anchor_kitchen_timer",
        knowledgeIds: ["kn_eng_g5a_u12_core"],
        corpusSentenceIds: ["sen_g5a_0797", "sen_g5a_0800", "sen_g5a_0804", "sen_g5a_0808", "sen_g5a_0812", "sen_g5a_0816", "sen_g5a_0820", "sen_g5a_0823"],
        options: [
          { id: "opt_review_look", label: "look like → appearance" },
          { id: "opt_review_food", label: "I'd like → ordering food" },
          { id: "opt_review_borrow", label: "Can I use → borrowing" },
          { id: "opt_review_time", label: "What time → timetable" },
          { id: "opt_review_hobby", label: "hobby → like doing" },
          { id: "opt_review_sign", label: "sign mean → rule" },
          { id: "opt_review_sorry", label: "I'm sorry → feelings" },
          { id: "opt_review_festival", label: "Spring Festival → reunion" },
          { id: "opt_review_bus", label: "by bus → reunion" }
        ],
        correctOptionIds: ["opt_review_look", "opt_review_food", "opt_review_borrow", "opt_review_time", "opt_review_hobby", "opt_review_sign", "opt_review_sorry", "opt_review_festival"],
        hintCopy: "Unit 12 也复习本册多个核心句型。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g5a_u12_star", quantity: 1 }]
  }
];

const g5bTaskConfigs = [
  {
    id: "task_eng_g5b_u01_main",
    title: "故事剧场排练",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "故事剧场要排练短剧，先把计划卡排清楚。",
    successCopy: "剧场门票点亮了，短剧排练表完成。",
    retryCopy: "再看 story、listen to、talk about、put on 和 play。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Miss Li asks: What are we going to do today? 先做什么？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5b_u01_core"],
        corpusSentenceIds: ["sen_g5b_0927", "sen_g5b_0928"],
        options: [
          { id: "opt_listen_stories", label: "We're going to listen to stories." },
          { id: "opt_clean_library", label: "We're going to clean the road." },
          { id: "opt_get_off", label: "We're going to get off at the stop." }
        ],
        correctOptionIds: ["opt_listen_stories"],
        hintCopy: "listen to some interesting stories 是第一条计划。"
      },
      {
        id: "step_002",
        type: "order",
        prompt: "把剧场排练计划按顺序排好。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5b_u01_core"],
        corpusVocabularyIds: ["voc_g5b_0434", "voc_g5b_0435", "voc_g5b_0437", "voc_g5b_0438", "voc_g5b_0439"],
        corpusSentenceIds: ["sen_g5b_0928", "sen_g5b_0930", "sen_g5b_0931", "sen_g5b_0932"],
        options: [
          { id: "opt_listen", label: "listen to interesting stories" },
          { id: "opt_read", label: "read the stories" },
          { id: "opt_talk", label: "talk about them" },
          { id: "opt_put_on", label: "put on a short play" }
        ],
        correctOptionIds: ["opt_listen", "opt_read", "opt_talk", "opt_put_on"],
        hintCopy: "先听和读，再讨论，最后表演。"
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把剧场词语和活动配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5b_u01_core"],
        corpusVocabularyIds: ["voc_g5b_0434", "voc_g5b_0435", "voc_g5b_0436", "voc_g5b_0437", "voc_g5b_0438", "voc_g5b_0439", "voc_g5b_0441"],
        corpusSentenceIds: ["sen_g5b_1007", "sen_g5b_1008", "sen_g5b_1009", "sen_g5b_1010", "sen_g5b_1011", "sen_g5b_1012"],
        options: [
          { id: "opt_story_read", label: "story → read it" },
          { id: "opt_listen_to", label: "listen to → story" },
          { id: "opt_interesting_story", label: "interesting → story" },
          { id: "opt_talk_about", label: "talk about → story" },
          { id: "opt_put_play", label: "put on → play" },
          { id: "opt_write_play", label: "write about → short play" },
          { id: "opt_hospital_story", label: "hospital → story" }
        ],
        correctOptionIds: ["opt_story_read", "opt_listen_to", "opt_interesting_story", "opt_talk_about", "opt_put_play", "opt_write_play"],
        hintCopy: "这些词都围绕读故事和表演短剧。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g5b_u01_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5b_u02_main",
    title: "研究报告小组",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "研究小组要写报告，帮他们整理资料步骤。",
    successCopy: "研究夹点亮了，报告资料准备好了。",
    retryCopy: "再看 research、find、information、study、think 和 report。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "老师说 We're going to do some research. 小组要做什么？",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5b_u02_core"],
        corpusSentenceIds: ["sen_g5b_0933", "sen_g5b_0934"],
        options: [
          { id: "opt_do_research", label: "do some research" },
          { id: "opt_put_play", label: "put on a play" },
          { id: "opt_buy_roses", label: "buy roses" }
        ],
        correctOptionIds: ["opt_do_research"],
        hintCopy: "research 是研究调查。"
      },
      {
        id: "step_002",
        type: "order",
        prompt: "把 research report 的步骤排好。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5b_u02_core"],
        corpusVocabularyIds: ["voc_g5b_0442", "voc_g5b_0443", "voc_g5b_0444", "voc_g5b_0445", "voc_g5b_0446", "voc_g5b_0447"],
        corpusSentenceIds: ["sen_g5b_0935", "sen_g5b_0936", "sen_g5b_0937", "sen_g5b_0938"],
        options: [
          { id: "opt_read_find", label: "read and find information" },
          { id: "opt_collect_pictures", label: "collect pictures" },
          { id: "opt_study_think", label: "study and think" },
          { id: "opt_write_report", label: "write a report" }
        ],
        correctOptionIds: ["opt_read_find", "opt_collect_pictures", "opt_study_think", "opt_write_report"],
        hintCopy: "先找资料和图片，再思考，最后写报告。"
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把研究词语和报告任务配对。",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5b_u02_core"],
        corpusVocabularyIds: ["voc_g5b_0442", "voc_g5b_0443", "voc_g5b_0444", "voc_g5b_0445", "voc_g5b_0446", "voc_g5b_0447"],
        corpusSentenceIds: ["sen_g5b_1013", "sen_g5b_1014", "sen_g5b_1015", "sen_g5b_1016", "sen_g5b_1017", "sen_g5b_1018", "sen_g5b_1019"],
        options: [
          { id: "opt_research_animals", label: "research → wild animals" },
          { id: "opt_find_places", label: "find → places on the map" },
          { id: "opt_information_text", label: "information → useful facts" },
          { id: "opt_study_textbook", label: "study → textbook" },
          { id: "opt_think_questions", label: "think → questions" },
          { id: "opt_report_write", label: "report → write" },
          { id: "opt_rose_report", label: "rose → report" }
        ],
        correctOptionIds: ["opt_research_animals", "opt_find_places", "opt_information_text", "opt_study_textbook", "opt_think_questions", "opt_report_write"],
        hintCopy: "研究报告需要资料、图片、问题和结论。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g5b_u02_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5b_u03_main",
    title: "节日风筝工坊",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "风筝工坊开工了，按步骤做出漂亮风筝。",
    successCopy: "风筝点亮了，制作步骤都记住了。",
    retryCopy: "再看 kite、paper、cut、tie、First、Then、Next 和 Lastly。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Boys and girls, do you know how to make a kite? 需要什么材料？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5b_u03_core"],
        corpusSentenceIds: ["sen_g5b_0939", "sen_g5b_0940", "sen_g5b_0941"],
        options: [
          { id: "opt_paper_bamboo", label: "paper and bamboo" },
          { id: "opt_chocolate_rose", label: "chocolate and rose" },
          { id: "opt_hotel_bus", label: "hotel and bus" }
        ],
        correctOptionIds: ["opt_paper_bamboo"],
        hintCopy: "课文说 We need paper and bamboo."
      },
      {
        id: "step_002",
        type: "order",
        prompt: "按 First / Then / Next / Lastly 排风筝制作步骤。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5b_u03_core"],
        corpusVocabularyIds: ["voc_g5b_0448", "voc_g5b_0450", "voc_g5b_0451", "voc_g5b_0452"],
        corpusSentenceIds: ["sen_g5b_0942", "sen_g5b_0943", "sen_g5b_0944", "sen_g5b_0945", "sen_g5b_0946"],
        options: [
          { id: "opt_cut_bamboo", label: "First, cut the bamboo" },
          { id: "opt_cut_paper", label: "Then, cut the paper" },
          { id: "opt_draw_paint", label: "Next, draw and paint" },
          { id: "opt_glue_tie", label: "Lastly, glue and tie a string" }
        ],
        correctOptionIds: ["opt_cut_bamboo", "opt_cut_paper", "opt_draw_paint", "opt_glue_tie"],
        hintCopy: "顺序词会直接告诉你制作流程。"
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把工坊动作和材料配对。",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5b_u03_core"],
        corpusVocabularyIds: ["voc_g5b_0448", "voc_g5b_0449", "voc_g5b_0450", "voc_g5b_0451", "voc_g5b_0452"],
        corpusSentenceIds: ["sen_g5b_1020", "sen_g5b_1021", "sen_g5b_1022", "sen_g5b_1023", "sen_g5b_1024", "sen_g5b_1025", "sen_g5b_1026", "sen_g5b_1027", "sen_g5b_1028"],
        options: [
          { id: "opt_kite_string", label: "kite → string" },
          { id: "opt_show_steps", label: "show → how to make" },
          { id: "opt_paper_draw", label: "paper → draw a line" },
          { id: "opt_cut_bamboo_pair", label: "cut → bamboo / paper" },
          { id: "opt_tie_string", label: "tie → string" },
          { id: "opt_forest_kite", label: "forest → kite" }
        ],
        correctOptionIds: ["opt_kite_string", "opt_show_steps", "opt_paper_draw", "opt_cut_bamboo_pair", "opt_tie_string"],
        hintCopy: "制作类任务要关注动作和材料。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g5b_u03_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5b_u04_main",
    title: "图书馆规则巡查",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "图书馆和公园要恢复整洁，帮大家贴好规则。",
    successCopy: "环保夹子点亮了，规则提醒都放好了。",
    retryCopy: "再看 Don't、library、throw、waste、floor、road 和 park。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "They're in the reading room. Dongdong 正要说话，应该贴哪句？",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5b_u04_core"],
        corpusSentenceIds: ["sen_g5b_0947", "sen_g5b_0948", "sen_g5b_0949"],
        options: [
          { id: "opt_dont_talk", label: "Don't talk here." },
          { id: "opt_get_off", label: "Get off at the third stop." },
          { id: "opt_first_race", label: "Amy was first." }
        ],
        correctOptionIds: ["opt_dont_talk"],
        hintCopy: "reading room 里要保持安静。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把不文明行为和规则配对。",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5b_u04_core"],
        corpusVocabularyIds: ["voc_g5b_0456", "voc_g5b_0457", "voc_g5b_0458", "voc_g5b_0459", "voc_g5b_0460", "voc_g5b_0461"],
        corpusSentenceIds: ["sen_g5b_0950", "sen_g5b_0951", "sen_g5b_0952", "sen_g5b_0953", "sen_g5b_1029", "sen_g5b_1030"],
        options: [
          { id: "opt_library_no_eat", label: "library → Don't eat" },
          { id: "opt_book_no_write", label: "book → Don't write" },
          { id: "opt_throw_waste", label: "throw waste → wrong" },
          { id: "opt_floor_clean", label: "floor → keep clean" },
          { id: "opt_road_safe", label: "road → don't litter" },
          { id: "opt_park_clean", label: "park → keep clean" },
          { id: "opt_rose_floor", label: "rose → floor rule" }
        ],
        correctOptionIds: ["opt_library_no_eat", "opt_book_no_write", "opt_throw_waste", "opt_floor_clean", "opt_road_safe", "opt_park_clean"],
        hintCopy: "Don't 后接动词原形，表示不要做某事。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "看到有人把 waste 扔在 floor 上，巡查卡应该选什么？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5b_u04_core"],
        corpusSentenceIds: ["sen_g5b_1031", "sen_g5b_1032", "sen_g5b_1033", "sen_g5b_1034", "sen_g5b_1035", "sen_g5b_1036", "sen_g5b_1037", "sen_g5b_1038", "sen_g5b_1039", "sen_g5b_1040"],
        options: [
          { id: "opt_pick_up_waste", label: "Pick it up and keep the floor clean." },
          { id: "opt_throw_more", label: "Throw more waste on the floor." },
          { id: "opt_put_on_play", label: "Put on a short play." }
        ],
        correctOptionIds: ["opt_pick_up_waste"],
        hintCopy: "waste 和 floor 一起出现时，要想到清洁规则。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g5b_u04_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5b_u05_main",
    title: "生日月份墙",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "生日墙空出来了，帮朋友把月份和日期贴对。",
    successCopy: "生日贴纸点亮了，月份墙完成。",
    retryCopy: "再看 January 到 December、month、year 和 birthday。",
    estimatedMinutes: 8,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "When's your birthday? 回答 My birthday is in March. 生日在哪个月？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5b_u05_core"],
        corpusVocabularyIds: ["voc_g5b_0462"],
        corpusSentenceIds: ["sen_g5b_0954", "sen_g5b_0955"],
        options: [
          { id: "opt_march", label: "March" },
          { id: "opt_may", label: "May" },
          { id: "opt_june", label: "June" }
        ],
        correctOptionIds: ["opt_march"],
        hintCopy: "in March 表示在三月。"
      },
      {
        id: "step_002",
        type: "order",
        prompt: "按一年月份顺序整理生日墙。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5b_u05_core"],
        corpusVocabularyIds: ["voc_g5b_0468", "voc_g5b_0469", "voc_g5b_0462", "voc_g5b_0470", "voc_g5b_0463", "voc_g5b_0465", "voc_g5b_0471", "voc_g5b_0472", "voc_g5b_0473", "voc_g5b_0474", "voc_g5b_0475", "voc_g5b_0476"],
        corpusSentenceIds: ["sen_g5b_0858", "sen_g5b_0859", "sen_g5b_0852", "sen_g5b_0860", "sen_g5b_0853", "sen_g5b_0855", "sen_g5b_0861", "sen_g5b_0862", "sen_g5b_0863", "sen_g5b_0864", "sen_g5b_0865", "sen_g5b_0866"],
        options: [
          { id: "opt_jan", label: "January" },
          { id: "opt_feb", label: "February" },
          { id: "opt_mar", label: "March" },
          { id: "opt_apr", label: "April" },
          { id: "opt_may", label: "May" },
          { id: "opt_jun", label: "June" },
          { id: "opt_jul", label: "July" },
          { id: "opt_aug", label: "August" },
          { id: "opt_sep", label: "September" },
          { id: "opt_oct", label: "October" },
          { id: "opt_nov", label: "November" },
          { id: "opt_dec", label: "December" }
        ],
        correctOptionIds: ["opt_jan", "opt_feb", "opt_mar", "opt_apr", "opt_may", "opt_jun", "opt_jul", "opt_aug", "opt_sep", "opt_oct", "opt_nov", "opt_dec"],
        hintCopy: "从 January 开始，到 December 结束。"
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把节日和时间线索配好。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5b_u05_core"],
        corpusVocabularyIds: ["voc_g5b_0464", "voc_g5b_0465", "voc_g5b_0466", "voc_g5b_0467"],
        corpusSentenceIds: ["sen_g5b_0956", "sen_g5b_0957", "sen_g5b_1041", "sen_g5b_1042", "sen_g5b_1043", "sen_g5b_1044", "sen_g5b_1045"],
        options: [
          { id: "opt_childrens_june", label: "International Children's Day → June" },
          { id: "opt_month_calendar", label: "month → calendar" },
          { id: "opt_year_twelve", label: "year → twelve months" },
          { id: "opt_birthday_date", label: "birthday → date" },
          { id: "opt_hotel_june", label: "hotel → June" }
        ],
        correctOptionIds: ["opt_childrens_june", "opt_month_calendar", "opt_year_twelve", "opt_birthday_date"],
        hintCopy: "Children's Day 和 June 是一组重要线索。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g5b_u05_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5b_u06_main",
    title: "母亲节心意卡",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "母亲节快到了，帮朋友选礼物并写心意卡。",
    successCopy: "玫瑰卡点亮了，母亲节计划完成。",
    retryCopy: "再看 Mother's Day、favourite、chocolate、rose 和 celebrate。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Lingling 说 I'll make a beautiful card for her. 她要做什么？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5b_u06_core"],
        corpusVocabularyIds: ["voc_g5b_0477"],
        corpusSentenceIds: ["sen_g5b_0958", "sen_g5b_0959"],
        options: [
          { id: "opt_make_card", label: "make a Mother's Day card" },
          { id: "opt_write_report", label: "write a research report" },
          { id: "opt_turn_left", label: "turn left at the crossing" }
        ],
        correctOptionIds: ["opt_make_card"],
        hintCopy: "I'll make... 表示我将要制作。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把母亲节礼物和喜好配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5b_u06_core"],
        corpusVocabularyIds: ["voc_g5b_0477", "voc_g5b_0478", "voc_g5b_0479", "voc_g5b_0480", "voc_g5b_0481", "voc_g5b_0482"],
        corpusSentenceIds: ["sen_g5b_0960", "sen_g5b_0961", "sen_g5b_0962", "sen_g5b_0963"],
        options: [
          { id: "opt_mothers_day_card", label: "Mother's Day → card" },
          { id: "opt_favourite_choc", label: "favourite → chocolates" },
          { id: "opt_rose_flowers", label: "rose → flowers" },
          { id: "opt_celebrate_dinner", label: "celebrate → dinner" },
          { id: "opt_restaurant_dinner", label: "restaurant → dinner" },
          { id: "opt_race_rose", label: "race → rose" }
        ],
        correctOptionIds: ["opt_mothers_day_card", "opt_favourite_choc", "opt_rose_flowers", "opt_celebrate_dinner", "opt_restaurant_dinner"],
        hintCopy: "礼物线索包括 card、flowers、chocolates 和 dinner。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Jane 没钱买礼物，Amy 建议她怎么做？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5b_u06_core"],
        corpusSentenceIds: ["sen_g5b_1046", "sen_g5b_1047", "sen_g5b_1048", "sen_g5b_1049", "sen_g5b_1050", "sen_g5b_1051", "sen_g5b_1052", "sen_g5b_1053"],
        options: [
          { id: "opt_make_card_stars", label: "make a card or lucky stars" },
          { id: "opt_throw_waste", label: "throw waste on the floor" },
          { id: "opt_get_off_stop", label: "get off at the third stop" }
        ],
        correctOptionIds: ["opt_make_card_stars"],
        hintCopy: "没有钱买礼物时，可以亲手制作。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g5b_u06_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5b_u07_main",
    title: "小镇设施地图",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "小镇地图缺少设施，帮 Leo 标出地点。",
    successCopy: "小镇地图点亮了，设施位置都标好了。",
    retryCopy: "再看 post office、near、shop、cinema、street、hotel 和 bank。",
    estimatedMinutes: 8,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Is there a park near your school? 回答 No, there isn't. But there's 什么？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5b_u07_core"],
        corpusVocabularyIds: ["voc_g5b_0483", "voc_g5b_0484"],
        corpusSentenceIds: ["sen_g5b_0964", "sen_g5b_0965", "sen_g5b_0966"],
        options: [
          { id: "opt_post_office", label: "a post office" },
          { id: "opt_one_race", label: "a one-hundred-metre race" },
          { id: "opt_lucky_star", label: "a lucky star" }
        ],
        correctOptionIds: ["opt_post_office"],
        hintCopy: "But 后面说 there is a post office。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把小镇设施和地图线索配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5b_u07_core"],
        corpusVocabularyIds: ["voc_g5b_0483", "voc_g5b_0484", "voc_g5b_0486", "voc_g5b_0487", "voc_g5b_0488", "voc_g5b_0490", "voc_g5b_0491", "voc_g5b_0492", "voc_g5b_0493"],
        corpusSentenceIds: ["sen_g5b_0967", "sen_g5b_0968", "sen_g5b_0969", "sen_g5b_0970", "sen_g5b_0971"],
        options: [
          { id: "opt_shop_over", label: "shop → over there" },
          { id: "opt_cinema_street", label: "cinema → end of the street" },
          { id: "opt_post_near", label: "post office → near school" },
          { id: "opt_hotel_stay", label: "hotel → stay" },
          { id: "opt_bank_money", label: "bank → money" },
          { id: "opt_shopping_centre", label: "shopping centre → shops" },
          { id: "opt_chocolate_street", label: "chocolate → street" }
        ],
        correctOptionIds: ["opt_shop_over", "opt_cinema_street", "opt_post_near", "opt_hotel_stay", "opt_bank_money", "opt_shopping_centre"],
        hintCopy: "地点词常和 near、over there、street 等位置线索搭配。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "地图标注 There's a cinema at the end of the street. 周末可以做什么？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5b_u07_core"],
        corpusSentenceIds: ["sen_g5b_0970"],
        options: [
          { id: "opt_see_movie", label: "see a movie" },
          { id: "opt_cut_bamboo", label: "cut bamboo" },
          { id: "opt_was_sick", label: "was sick" }
        ],
        correctOptionIds: ["opt_see_movie"],
        hintCopy: "cinema 是电影院。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g5b_u07_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5b_u08_main",
    title: "酒店问路路线牌",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "客人找不到酒店，帮他读懂问路路线。",
    successCopy: "路线牌点亮了，客人顺利出发。",
    retryCopy: "再看 way、straight、along、crossing、get off、stop 和 hospital。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Excuse me, can you show me the way to the Xinhua Hotel? 他在问什么？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5b_u08_core"],
        corpusVocabularyIds: ["voc_g5b_0494", "voc_g5b_0492"],
        corpusSentenceIds: ["sen_g5b_0972"],
        options: [
          { id: "opt_ask_way_hotel", label: "the way to the hotel" },
          { id: "opt_birthday_month", label: "the birthday month" },
          { id: "opt_story_play", label: "the short play" }
        ],
        correctOptionIds: ["opt_ask_way_hotel"],
        hintCopy: "show me the way to... 是问路。"
      },
      {
        id: "step_002",
        type: "order",
        prompt: "按路线指示排出去酒店的路。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5b_u08_core"],
        corpusVocabularyIds: ["voc_g5b_0495", "voc_g5b_0496", "voc_g5b_0497", "voc_g5b_0498", "voc_g5b_0499"],
        corpusSentenceIds: ["sen_g5b_0973", "sen_g5b_0974", "sen_g5b_0975", "sen_g5b_0976", "sen_g5b_0977"],
        options: [
          { id: "opt_go_straight", label: "go straight along this road" },
          { id: "opt_turn_left", label: "turn left at the second crossing" },
          { id: "opt_take_bus", label: "take Bus No. 206" },
          { id: "opt_get_off", label: "get off at the third stop" }
        ],
        correctOptionIds: ["opt_go_straight", "opt_turn_left", "opt_take_bus", "opt_get_off"],
        hintCopy: "先步行到路口，再乘车并下车。"
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把问路词和交通地点配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5b_u08_core"],
        corpusVocabularyIds: ["voc_g5b_0495", "voc_g5b_0496", "voc_g5b_0497", "voc_g5b_0498", "voc_g5b_0499", "voc_g5b_0500", "voc_g5b_0501", "voc_g5b_0502", "voc_g5b_0503"],
        corpusSentenceIds: ["sen_g5b_0978", "sen_g5b_1061", "sen_g5b_1062", "sen_g5b_1063", "sen_g5b_1064", "sen_g5b_1065", "sen_g5b_1116"],
        options: [
          { id: "opt_straight_road", label: "straight → road" },
          { id: "opt_along_road", label: "along → road" },
          { id: "opt_crossing_turn", label: "crossing → turn" },
          { id: "opt_get_off_stop", label: "get off → stop" },
          { id: "opt_get_on_bus", label: "get on → bus" },
          { id: "opt_hospital_place", label: "hospital → place" },
          { id: "opt_airport_station", label: "airport / railway station → travel place" },
          { id: "opt_rose_crossing", label: "rose → crossing" }
        ],
        correctOptionIds: ["opt_straight_road", "opt_along_road", "opt_crossing_turn", "opt_get_off_stop", "opt_get_on_bus", "opt_hospital_place", "opt_airport_station"],
        hintCopy: "问路词常和 road、crossing、stop、station 搭配。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g5b_u08_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5b_u09_main",
    title: "人物品质采访卡",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "小记者要写人物采访卡，帮他选择品质词。",
    successCopy: "采访徽章点亮了，人物品质记录好了。",
    retryCopy: "再看 kind、village、teach、interested、active、friendly、smart 和 serious。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Peter's grandpa teaches English. He loves children. He's 什么？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5b_u09_core"],
        corpusVocabularyIds: ["voc_g5b_0504", "voc_g5b_0506"],
        corpusSentenceIds: ["sen_g5b_0979", "sen_g5b_0980", "sen_g5b_0981"],
        options: [
          { id: "opt_kind_children", label: "kind to children" },
          { id: "opt_sick_bed", label: "sick in bed" },
          { id: "opt_second_crossing", label: "second crossing" }
        ],
        correctOptionIds: ["opt_kind_children"],
        hintCopy: "loves children 和 kind to children 是一组线索。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把人物品质词和采访线索配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5b_u09_core"],
        corpusVocabularyIds: ["voc_g5b_0504", "voc_g5b_0505", "voc_g5b_0506", "voc_g5b_0507", "voc_g5b_0508", "voc_g5b_0509", "voc_g5b_0510", "voc_g5b_0511"],
        corpusSentenceIds: ["sen_g5b_0982", "sen_g5b_0983", "sen_g5b_1066", "sen_g5b_1067", "sen_g5b_1068", "sen_g5b_1069", "sen_g5b_1070"],
        options: [
          { id: "opt_kind_help", label: "kind → helps me" },
          { id: "opt_village_school", label: "village → primary school" },
          { id: "opt_teach_english", label: "teach → English" },
          { id: "opt_interested_lessons", label: "interested → lessons" },
          { id: "opt_active_tall", label: "active → tall and active" },
          { id: "opt_friendly_after", label: "friendly → after work" },
          { id: "opt_serious_work", label: "serious → working" },
          { id: "opt_smart_person", label: "smart → person trait" },
          { id: "opt_airport_kind", label: "airport → kind" }
        ],
        correctOptionIds: ["opt_kind_help", "opt_village_school", "opt_teach_english", "opt_interested_lessons", "opt_active_tall", "opt_friendly_after", "opt_serious_work", "opt_smart_person"],
        hintCopy: "品质词描述人的性格、状态和给人的感觉。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "采访卡写 He looks serious when he is working. serious 说明什么？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5b_u09_core"],
        corpusSentenceIds: ["sen_g5b_1067", "sen_g5b_1068"],
        options: [
          { id: "opt_serious_meaning", label: "He is focused and not joking." },
          { id: "opt_month_meaning", label: "It is a month in a year." },
          { id: "opt_route_meaning", label: "Turn left at the crossing." }
        ],
        correctOptionIds: ["opt_serious_meaning"],
        hintCopy: "serious 是严肃、认真的状态。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g5b_u09_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5b_u10_main",
    title: "昨天在哪里",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "老师在找昨天的线索，帮朋友说明去了哪里。",
    successCopy: "昨日相片点亮了，过去地点记录完成。",
    retryCopy: "再看 were、was、yesterday、sick、better、last 和 work。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Miss Li asks: Where were you yesterday? Mingming 怎么回答？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5b_u10_core"],
        corpusVocabularyIds: ["voc_g5b_0512", "voc_g5b_0513", "voc_g5b_0514", "voc_g5b_0515"],
        corpusSentenceIds: ["sen_g5b_0984", "sen_g5b_0985", "sen_g5b_0986", "sen_g5b_0987"],
        options: [
          { id: "opt_sick_home", label: "I was sick. I was in bed at home." },
          { id: "opt_first_race", label: "I was first in the race." },
          { id: "opt_make_kite", label: "I cut the bamboo." }
        ],
        correctOptionIds: ["opt_sick_home"],
        hintCopy: "where were you 问过去在哪里。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把过去式线索和意思配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5b_u10_core"],
        corpusVocabularyIds: ["voc_g5b_0512", "voc_g5b_0513", "voc_g5b_0514", "voc_g5b_0515", "voc_g5b_0516", "voc_g5b_0517", "voc_g5b_0518"],
        corpusSentenceIds: ["sen_g5b_0988", "sen_g5b_0989", "sen_g5b_0990", "sen_g5b_0991"],
        options: [
          { id: "opt_were_past", label: "were → past are" },
          { id: "opt_was_past", label: "was → past is/am" },
          { id: "opt_yesterday_past", label: "yesterday → past time" },
          { id: "opt_sick_bed_pair", label: "sick → in bed" },
          { id: "opt_better_now", label: "better → fine now" },
          { id: "opt_last_week", label: "last → past time" },
          { id: "opt_work_homework", label: "work → homework" },
          { id: "opt_rose_was", label: "rose → was" }
        ],
        correctOptionIds: ["opt_were_past", "opt_was_past", "opt_yesterday_past", "opt_sick_bed_pair", "opt_better_now", "opt_last_week", "opt_work_homework"],
        hintCopy: "was/were 用来描述过去的状态。"
      },
      {
        id: "step_003",
        type: "order",
        prompt: "按 Mr White 上周旅行顺序整理相片。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5b_u10_core"],
        corpusSentenceIds: ["sen_g5b_1071", "sen_g5b_1072", "sen_g5b_1073", "sen_g5b_1074", "sen_g5b_1075", "sen_g5b_1076", "sen_g5b_1077"],
        options: [
          { id: "opt_beijing", label: "Beijing on Monday and Tuesday" },
          { id: "opt_hangzhou", label: "Hangzhou on Wednesday" },
          { id: "opt_sanya", label: "Sanya on Thursday" },
          { id: "opt_changsha", label: "Changsha on Friday" }
        ],
        correctOptionIds: ["opt_beijing", "opt_hangzhou", "opt_sanya", "opt_changsha"],
        hintCopy: "按 Monday 到 Friday 的顺序排。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g5b_u10_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5b_u11_main",
    title: "运动会名次牌",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "运动会成绩出来了，帮大家排好名次牌。",
    successCopy: "奖牌点亮了，比赛名次记录完成。",
    retryCopy: "再看 first 到 tenth、sport、metre 和 race。",
    estimatedMinutes: 8,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Who was first? 课文说 Amy was first. 第一名是谁？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5b_u11_core"],
        corpusVocabularyIds: ["voc_g5b_0519", "voc_g5b_0522"],
        corpusSentenceIds: ["sen_g5b_0992", "sen_g5b_0993", "sen_g5b_0994", "sen_g5b_0995", "sen_g5b_0996"],
        options: [
          { id: "opt_amy_first", label: "Amy" },
          { id: "opt_lingling_first", label: "Lingling" },
          { id: "opt_anne_first", label: "Anne" }
        ],
        correctOptionIds: ["opt_amy_first"],
        hintCopy: "句子直接说 Amy was first。"
      },
      {
        id: "step_002",
        type: "order",
        prompt: "按序数词顺序排奖牌。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5b_u11_core"],
        corpusVocabularyIds: ["voc_g5b_0519", "voc_g5b_0523", "voc_g5b_0524", "voc_g5b_0525", "voc_g5b_0526", "voc_g5b_0527", "voc_g5b_0528", "voc_g5b_0529", "voc_g5b_0530", "voc_g5b_0531"],
        corpusSentenceIds: ["sen_g5b_0909", "sen_g5b_0913", "sen_g5b_0914", "sen_g5b_0915", "sen_g5b_0916", "sen_g5b_0917", "sen_g5b_0918", "sen_g5b_0919", "sen_g5b_0920", "sen_g5b_0921"],
        options: [
          { id: "opt_first", label: "first" },
          { id: "opt_second", label: "second" },
          { id: "opt_third", label: "third" },
          { id: "opt_fourth", label: "fourth" },
          { id: "opt_fifth", label: "fifth" },
          { id: "opt_sixth", label: "sixth" },
          { id: "opt_seventh", label: "seventh" },
          { id: "opt_eighth", label: "eighth" },
          { id: "opt_ninth", label: "ninth" },
          { id: "opt_tenth", label: "tenth" }
        ],
        correctOptionIds: ["opt_first", "opt_second", "opt_third", "opt_fourth", "opt_fifth", "opt_sixth", "opt_seventh", "opt_eighth", "opt_ninth", "opt_tenth"],
        hintCopy: "first、second、third 后面继续 fourth 到 tenth。"
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把运动会词语和比赛线索配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5b_u11_core"],
        corpusVocabularyIds: ["voc_g5b_0520", "voc_g5b_0521", "voc_g5b_0522", "voc_g5b_0519", "voc_g5b_0523", "voc_g5b_0524"],
        corpusSentenceIds: ["sen_g5b_0992", "sen_g5b_0997", "sen_g5b_1078", "sen_g5b_1079", "sen_g5b_1080", "sen_g5b_1081", "sen_g5b_1082", "sen_g5b_1083", "sen_g5b_1084", "sen_g5b_1085"],
        options: [
          { id: "opt_sport_day", label: "sport → Sports Day" },
          { id: "opt_metre_race", label: "metre → one-hundred-metre race" },
          { id: "opt_race_runners", label: "race → runners" },
          { id: "opt_first_win", label: "first → winner" },
          { id: "opt_second_lingling", label: "second → Lingling" },
          { id: "opt_third_anne", label: "third → Anne" },
          { id: "opt_hospital_race", label: "hospital → race" }
        ],
        correctOptionIds: ["opt_sport_day", "opt_metre_race", "opt_race_runners", "opt_first_win", "opt_second_lingling", "opt_third_anne"],
        hintCopy: "名次词用于记录比赛结果。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g5b_u11_star", quantity: 1 }]
  },
  {
    id: "task_eng_g5b_u12_main",
    title: "郊游调查笔记",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "学校郊游结束了，帮大家完成调查笔记。",
    successCopy: "旅行笔记点亮了，郊游记录完成。",
    retryCopy: "再看 forest、museum、note、ask、question 和 did。",
    estimatedMinutes: 8,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Mum asks: Where did you go? 回答 We went to 哪里？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g5b_u12_core"],
        corpusVocabularyIds: ["voc_g5b_0532", "voc_g5b_0533"],
        corpusSentenceIds: ["sen_g5b_0998", "sen_g5b_0999", "sen_g5b_1000", "sen_g5b_1001", "sen_g5b_1002"],
        options: [
          { id: "opt_mountains", label: "the mountains" },
          { id: "opt_xinhua_hotel", label: "the Xinhua Hotel" },
          { id: "opt_reading_room", label: "the reading room" }
        ],
        correctOptionIds: ["opt_mountains"],
        hintCopy: "Where did you go? 后面回答 went to the mountains。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把郊游问题和答案配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g5b_u12_core"],
        corpusVocabularyIds: ["voc_g5b_0534", "voc_g5b_0535", "voc_g5b_0536", "voc_g5b_0617", "voc_g5b_0618"],
        corpusSentenceIds: ["sen_g5b_1003", "sen_g5b_1004", "sen_g5b_1005", "sen_g5b_1006"],
        options: [
          { id: "opt_lunch_park", label: "Where lunch? → at the park" },
          { id: "opt_see_nature", label: "What see? → birds, trees and flowers" },
          { id: "opt_note_record", label: "note → record" },
          { id: "opt_ask_question", label: "ask → question" },
          { id: "opt_forest_museum", label: "forest / museum → outing place" },
          { id: "opt_rose_question", label: "rose → question" }
        ],
        correctOptionIds: ["opt_lunch_park", "opt_see_nature", "opt_note_record", "opt_ask_question", "opt_forest_museum"],
        hintCopy: "调查笔记用问题和答案整理经历。"
      },
      {
        id: "step_003",
        type: "order",
        prompt: "按 East Lake 郊游经历排相册。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g5b_u12_core"],
        corpusSentenceIds: ["sen_g5b_1086", "sen_g5b_1087", "sen_g5b_1088", "sen_g5b_1089", "sen_g5b_1090", "sen_g5b_1091", "sen_g5b_1092", "sen_g5b_1093", "sen_g5b_1094", "sen_g5b_1095"],
        options: [
          { id: "opt_went_lake", label: "went to the East Lake" },
          { id: "opt_went_boating", label: "went boating in the morning" },
          { id: "opt_little_house", label: "went to a little brown house" },
          { id: "opt_asked_questions", label: "asked questions and took notes" }
        ],
        correctOptionIds: ["opt_went_lake", "opt_went_boating", "opt_little_house", "opt_asked_questions"],
        hintCopy: "按郊游当天发生的先后顺序排。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g5b_u12_star", quantity: 1 }]
  }
];

const g6aTaskConfigs = [
  {
    id: "task_eng_g6a_u01_main",
    title: "假期故事书",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "假期故事会开始了，帮 Anne 整理经历书页。",
    successCopy: "假期书页点亮了，过去经历讲清楚了。",
    retryCopy: "再看 during、learn、practise、speak 和 What did you do。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Anne 说 I read many books during the holidays. 她假期做了什么？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g6a_u01_core"],
        corpusVocabularyIds: ["voc_g6a_0621"],
        corpusSentenceIds: ["sen_g6a_1144", "sen_g6a_1145", "sen_g6a_1146"],
        options: [
          { id: "opt_read_books", label: "read many books" },
          { id: "opt_weather_forecast", label: "watched the weather forecast" },
          { id: "opt_bought_mooncakes", label: "bought mooncakes" }
        ],
        correctOptionIds: ["opt_read_books"],
        hintCopy: "during the holidays 表示在假期期间。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把假期表达和动作配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g6a_u01_core"],
        corpusVocabularyIds: ["voc_g6a_0621", "voc_g6a_0622", "voc_g6a_0623", "voc_g6a_0624"],
        corpusSentenceIds: ["sen_g6a_1147", "sen_g6a_1148", "sen_g6a_1149"],
        options: [
          { id: "opt_during_holidays", label: "during → holidays" },
          { id: "opt_learn_writing", label: "learn → learnt writing" },
          { id: "opt_practise_speaking", label: "practise → speak English" },
          { id: "opt_speak_read", label: "speak → read it to us" },
          { id: "opt_clear_speak", label: "clear → speak" }
        ],
        correctOptionIds: ["opt_during_holidays", "opt_learn_writing", "opt_practise_speaking", "opt_speak_read"],
        hintCopy: "过去经历里要关注 did、learnt、wrote、read。"
      },
      {
        id: "step_003",
        type: "order",
        prompt: "按 Simon says 的故事顺序排卡片。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g6a_u01_core"],
        corpusSentenceIds: ["sen_g6a_1150", "sen_g6a_1151", "sen_g6a_1152", "sen_g6a_1153", "sen_g6a_1154", "sen_g6a_1155", "sen_g6a_1156", "sen_g6a_1157"],
        options: [
          { id: "opt_stand_up", label: "Dino stood up" },
          { id: "opt_sit_down", label: "Dino sat down" },
          { id: "opt_bell_rang", label: "the bell rang" },
          { id: "opt_class_over", label: "Class is over" }
        ],
        correctOptionIds: ["opt_stand_up", "opt_sit_down", "opt_bell_rang", "opt_class_over"],
        hintCopy: "按课堂游戏从开始到下课的顺序排。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g6a_u01_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6a_u02_main",
    title: "习惯观察笔",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "观察员要记录日常习惯，帮他整理频率线索。",
    successCopy: "观察笔点亮了，习惯时间线完成。",
    retryCopy: "再看 weekday、after、wave、return、sometimes 和 never。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Katie always gets up early. On weekdays, she gets up at 几点？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g6a_u02_core"],
        corpusVocabularyIds: ["voc_g6a_0625"],
        corpusSentenceIds: ["sen_g6a_1158"],
        options: [
          { id: "opt_630", label: "6:30 a.m." },
          { id: "opt_645", label: "6:45 a.m." },
          { id: "opt_500", label: "5:00 p.m." }
        ],
        correctOptionIds: ["opt_630"],
        hintCopy: "句子里直接出现 at 6:30 a.m."
      },
      {
        id: "step_002",
        type: "order",
        prompt: "按 Katie 的一天排时间线。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g6a_u02_core"],
        corpusVocabularyIds: ["voc_g6a_0626", "voc_g6a_0627", "voc_g6a_0628"],
        corpusSentenceIds: ["sen_g6a_1159", "sen_g6a_1160", "sen_g6a_1161"],
        options: [
          { id: "opt_breakfast", label: "has breakfast" },
          { id: "opt_wave_go", label: "waves goodbye and goes to school" },
          { id: "opt_return_home", label: "returns home" },
          { id: "opt_homework_chess", label: "homework before dinner, chess after dinner" }
        ],
        correctOptionIds: ["opt_breakfast", "opt_wave_go", "opt_return_home", "opt_homework_chess"],
        hintCopy: "after breakfast 和 before/after dinner 是顺序线索。"
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把频率副词和科学家观察配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g6a_u02_core"],
        corpusVocabularyIds: ["voc_g6a_0629", "voc_g6a_0630"],
        corpusSentenceIds: ["sen_g6a_1162", "sen_g6a_1163", "sen_g6a_1164", "sen_g6a_1165", "sen_g6a_1166", "sen_g6a_1167", "sen_g6a_1263"],
        options: [
          { id: "opt_always_early", label: "always → gets up very early" },
          { id: "opt_often_walks", label: "often → walks in forests" },
          { id: "opt_sometimes_photos", label: "sometimes → takes photos" },
          { id: "opt_never_hurts", label: "never → hurts birds" },
          { id: "opt_weekday_school", label: "weekday → school day" },
          { id: "opt_mooncake_never", label: "mooncake → never" }
        ],
        correctOptionIds: ["opt_always_early", "opt_often_walks", "opt_sometimes_photos", "opt_never_hurts", "opt_weekday_school"],
        hintCopy: "always、often、sometimes、never 表示频率高低。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g6a_u02_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6a_u03_main",
    title: "电脑信息检索",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "新电脑可以查资料，帮 Dongdong 安排健康使用方式。",
    successCopy: "电脑贴纸点亮了，信息检索计划完成。",
    retryCopy: "再看 world、greeting、search、email 和 computer games。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Dad 说电脑 It will help you a lot. Dongdong 可以用它做什么？",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g6a_u03_core"],
        corpusSentenceIds: ["sen_g6a_1168", "sen_g6a_1169", "sen_g6a_1170"],
        options: [
          { id: "opt_search_world", label: "search for things and countries in the world" },
          { id: "opt_waste_water", label: "waste a lot of water" },
          { id: "opt_get_fever", label: "get a fever" }
        ],
        correctOptionIds: ["opt_search_world"],
        hintCopy: "search for 和 find out about 都和查资料有关。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把电脑用途和线索配对。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g6a_u03_core"],
        corpusVocabularyIds: ["voc_g6a_0631", "voc_g6a_0632"],
        corpusSentenceIds: ["sen_g6a_1171", "sen_g6a_1172", "sen_g6a_1173", "sen_g6a_1174", "sen_g6a_1264"],
        options: [
          { id: "opt_email_friends", label: "email → friends in Australia" },
          { id: "opt_homework_computer", label: "computer → do homework" },
          { id: "opt_drawing_learning", label: "computer → learn drawing and painting" },
          { id: "opt_search_things", label: "search → a lot of things" },
          { id: "opt_world_countries", label: "world → countries" },
          { id: "opt_greeting_email", label: "greeting → email friends" },
          { id: "opt_fever_world", label: "fever → world" }
        ],
        correctOptionIds: ["opt_email_friends", "opt_homework_computer", "opt_drawing_learning", "opt_search_things", "opt_world_countries", "opt_greeting_email"],
        hintCopy: "电脑可以学习和查资料，也能联系朋友。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Peter 提醒 Don't play computer games too often. 为什么？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g6a_u03_core"],
        corpusSentenceIds: ["sen_g6a_1175"],
        options: [
          { id: "opt_bad_eyes", label: "It is not good for your eyes." },
          { id: "opt_good_water", label: "It saves every drop of water." },
          { id: "opt_good_mooncake", label: "It tastes good." }
        ],
        correctOptionIds: ["opt_bad_eyes"],
        hintCopy: "too often 表示太频繁，要注意健康。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g6a_u03_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6a_u04_main",
    title: "月饼礼盒订单",
    sceneId: "scene_kitchen",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "中秋礼盒要出单，帮家人选对月饼口味。",
    successCopy: "月饼盒点亮了，礼盒订单完成。",
    retryCopy: "再看 Mid-Autumn Festival、mooncake、lotus seed、bean 和 taste。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Binbin says: I like the ones with lotus seeds. 他喜欢哪种月饼？",
        anchorId: "anchor_kitchen_cup",
        knowledgeIds: ["kn_eng_g6a_u04_core"],
        corpusVocabularyIds: ["voc_g6a_0636", "voc_g6a_0638", "voc_g6a_0639"],
        corpusSentenceIds: ["sen_g6a_1176", "sen_g6a_1177", "sen_g6a_1178"],
        options: [
          { id: "opt_lotus_seed", label: "lotus seed mooncakes" },
          { id: "opt_peanut_candy", label: "peanut candies" },
          { id: "opt_weather_clear", label: "clear weather" }
        ],
        correctOptionIds: ["opt_lotus_seed"],
        hintCopy: "with lotus seeds 表示莲蓉/莲子口味。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把月饼订单词和口味配对。",
        anchorId: "anchor_kitchen_oven",
        knowledgeIds: ["kn_eng_g6a_u04_core"],
        corpusVocabularyIds: ["voc_g6a_0633", "voc_g6a_0635", "voc_g6a_0636", "voc_g6a_0637", "voc_g6a_0638", "voc_g6a_0639", "voc_g6a_0640", "voc_g6a_0641", "voc_g6a_0643"],
        corpusSentenceIds: ["sen_g6a_1179", "sen_g6a_1180", "sen_g6a_1181", "sen_g6a_1182"],
        options: [
          { id: "opt_festival_mooncake", label: "Mid-Autumn Festival → mooncakes" },
          { id: "opt_centre_shopping", label: "centre → shopping centre" },
          { id: "opt_type_flavour", label: "type → mooncake flavour" },
          { id: "opt_lotus_seed_pair", label: "lotus seed → mooncake" },
          { id: "opt_red_bean", label: "bean → red bean mooncake" },
          { id: "opt_taste_good", label: "taste → tastes good" },
          { id: "opt_peanut_candy_pair", label: "peanut / candy → snack words" },
          { id: "opt_forecast_mooncake", label: "forecast → mooncake" }
        ],
        correctOptionIds: ["opt_festival_mooncake", "opt_centre_shopping", "opt_type_flavour", "opt_lotus_seed_pair", "opt_red_bean", "opt_taste_good", "opt_peanut_candy_pair"],
        hintCopy: "订单里要看口味、数量和价格。"
      },
      {
        id: "step_003",
        type: "order",
        prompt: "按爷爷打开中秋礼盒的过程排序。",
        anchorId: "anchor_kitchen_timer",
        knowledgeIds: ["kn_eng_g6a_u04_core"],
        corpusSentenceIds: ["sen_g6a_1183", "sen_g6a_1184", "sen_g6a_1185", "sen_g6a_1186", "sen_g6a_1187"],
        options: [
          { id: "opt_gift_box", label: "got a gift box" },
          { id: "opt_open_boxes", label: "opened smaller boxes" },
          { id: "opt_round_mooncake", label: "found a big round mooncake" },
          { id: "opt_cut_eat", label: "cut and enjoyed it" }
        ],
        correctOptionIds: ["opt_gift_box", "opt_open_boxes", "opt_round_mooncake", "opt_cut_eat"],
        hintCopy: "礼盒是一层一层打开的。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g6a_u04_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6a_u05_main",
    title: "天气预报出行",
    sceneId: "scene_wardrobe",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "天气预报来了，帮大家选择明天的出行装备。",
    successCopy: "天气预报牌点亮了，出行计划完成。",
    retryCopy: "再看 forecast、clear、will be 和 There will be。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Tomorrow will be clear in Beijing. It will be sunny and cool. 适合去哪？",
        anchorId: "anchor_wardrobe_mirror",
        knowledgeIds: ["kn_eng_g6a_u05_core"],
        corpusVocabularyIds: ["voc_g6a_0644", "voc_g6a_0645"],
        corpusSentenceIds: ["sen_g6a_1188", "sen_g6a_1189"],
        options: [
          { id: "opt_go_park", label: "go to the park" },
          { id: "opt_stay_storm", label: "stay home for a storm" },
          { id: "opt_buy_mooncakes", label: "buy mooncakes" }
        ],
        correctOptionIds: ["opt_go_park"],
        hintCopy: "sunny and cool 适合户外活动。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把城市和天气预报配对。",
        anchorId: "anchor_wardrobe_rack",
        knowledgeIds: ["kn_eng_g6a_u05_core"],
        corpusSentenceIds: ["sen_g6a_1190", "sen_g6a_1191", "sen_g6a_1192", "sen_g6a_1193", "sen_g6a_1194"],
        options: [
          { id: "opt_shanghai_wind", label: "Shanghai → light wind" },
          { id: "opt_xian_strong", label: "Xi'an → strong wind" },
          { id: "opt_changsha_rain", label: "Changsha → rain, not heavy" },
          { id: "opt_sanya_warm", label: "Sanya → sunny and warm" },
          { id: "opt_guangzhou_storm", label: "Guangzhou → big storm" },
          { id: "opt_beijing_mooncake", label: "Beijing → mooncake" }
        ],
        correctOptionIds: ["opt_shanghai_wind", "opt_xian_strong", "opt_changsha_rain", "opt_sanya_warm", "opt_guangzhou_storm"],
        hintCopy: "There will be 后面常接风、雨、雪等天气。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Guangzhou 明天有 strong wind and heavy rain，学生应该怎么做？",
        anchorId: "anchor_wardrobe_shoes",
        knowledgeIds: ["kn_eng_g6a_u05_core"],
        corpusSentenceIds: ["sen_g6a_1195", "sen_g6a_1196", "sen_g6a_1197"],
        options: [
          { id: "opt_stay_home", label: "stay at home" },
          { id: "opt_go_zoo", label: "go to the zoo" },
          { id: "opt_play_beach", label: "play beach volleyball" }
        ],
        correctOptionIds: ["opt_stay_home"],
        hintCopy: "storm、heavy rain 时要注意安全。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g6a_u05_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6a_u06_main",
    title: "公园野餐清单",
    sceneId: "scene_kitchen",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "周六要去野餐，帮大家把食物清单备齐。",
    successCopy: "野餐篮点亮了，食物清单完成。",
    retryCopy: "再看 bring、bottle、picnic、fruit 和 I will bring。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "What are we going to bring for the picnic? 选饮料。",
        anchorId: "anchor_kitchen_cup",
        knowledgeIds: ["kn_eng_g6a_u06_core"],
        corpusVocabularyIds: ["voc_g6a_0646", "voc_g6a_0647", "voc_g6a_0648"],
        corpusSentenceIds: ["sen_g6a_1198", "sen_g6a_1199", "sen_g6a_1200", "sen_g6a_1201", "sen_g6a_1202"],
        options: [
          { id: "opt_orange_juice", label: "a big bottle of orange juice" },
          { id: "opt_lotus_seed", label: "a box of lotus seed mooncakes" },
          { id: "opt_medicine", label: "some medicine" }
        ],
        correctOptionIds: ["opt_orange_juice"],
        hintCopy: "bottle 和 orange juice 是一组。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把野餐物品和包装数量配对。",
        anchorId: "anchor_kitchen_oven",
        knowledgeIds: ["kn_eng_g6a_u06_core"],
        corpusVocabularyIds: ["voc_g6a_0646", "voc_g6a_0647", "voc_g6a_0648", "voc_g6a_0649"],
        corpusSentenceIds: ["sen_g6a_1201", "sen_g6a_1202", "sen_g6a_1278", "sen_g6a_1279"],
        options: [
          { id: "opt_fruit_some", label: "fruit → some fruit" },
          { id: "opt_chocolate_bars", label: "chocolate → a few bars" },
          { id: "opt_juice_bottle", label: "orange juice → a bottle" },
          { id: "opt_coke_cans", label: "Coke → a few cans" },
          { id: "opt_cakes_box", label: "cakes → a box" },
          { id: "opt_forecast_fruit", label: "forecast → fruit" }
        ],
        correctOptionIds: ["opt_fruit_some", "opt_chocolate_bars", "opt_juice_bottle", "opt_coke_cans", "opt_cakes_box"],
        hintCopy: "bring 后面常接具体食物和数量包装。"
      },
      {
        id: "step_003",
        type: "order",
        prompt: "按海边野餐经历排相册。",
        anchorId: "anchor_kitchen_timer",
        knowledgeIds: ["kn_eng_g6a_u06_core"],
        corpusSentenceIds: ["sen_g6a_1203", "sen_g6a_1204", "sen_g6a_1205", "sen_g6a_1206", "sen_g6a_1207", "sen_g6a_1208", "sen_g6a_1209", "sen_g6a_1210"],
        options: [
          { id: "opt_meet_park", label: "meet at the park" },
          { id: "opt_play_volleyball", label: "played beach volleyball" },
          { id: "opt_have_lunch", label: "sat down to have lunch" },
          { id: "opt_share_food", label: "shared sandwiches, cookies and apples" }
        ],
        correctOptionIds: ["opt_meet_park", "opt_play_volleyball", "opt_have_lunch", "opt_share_food"],
        hintCopy: "先集合和玩，再吃午餐。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g6a_u06_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6a_u07_main",
    title: "老人中心帮助计划",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "志愿者小队要帮助老人，帮他们分配任务。",
    successCopy: "志愿者徽章点亮了，帮助计划完成。",
    retryCopy: "再看 weak、slow、I can 和 help old people。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Peter asks himself, What can I do? 他能做什么？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g6a_u07_core"],
        corpusSentenceIds: ["sen_g6a_1211", "sen_g6a_1216"],
        options: [
          { id: "opt_clean_houses", label: "clean their houses" },
          { id: "opt_search_games", label: "play computer games often" },
          { id: "opt_wash_car", label: "wash his car too often" }
        ],
        correctOptionIds: ["opt_clean_houses"],
        hintCopy: "Peter 的回答是 I can clean their houses."
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把孩子和帮助计划配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g6a_u07_core"],
        corpusVocabularyIds: ["voc_g6a_0650", "voc_g6a_0651"],
        corpusSentenceIds: ["sen_g6a_1212", "sen_g6a_1213", "sen_g6a_1214", "sen_g6a_1215"],
        options: [
          { id: "opt_jane_tea", label: "Jane → make tea or coffee" },
          { id: "opt_lingling_cakes", label: "Lingling → ask Mum to make cakes" },
          { id: "opt_anne_sing", label: "Anne → sing and make them happy" },
          { id: "opt_mingming_road", label: "Mingming → help them on the road" },
          { id: "opt_weak_slow", label: "weak and slow → need help" },
          { id: "opt_forecast_weak", label: "forecast → weak" }
        ],
        correctOptionIds: ["opt_jane_tea", "opt_lingling_cakes", "opt_anne_sing", "opt_mingming_road", "opt_weak_slow"],
        hintCopy: "I can 后面接具体能做的帮助行动。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Ms Li volunteers. She talks to old people and tells stories. 结果怎样？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g6a_u07_core"],
        corpusSentenceIds: ["sen_g6a_1217", "sen_g6a_1218", "sen_g6a_1219", "sen_g6a_1220"],
        options: [
          { id: "opt_makes_happy", label: "She makes them happy and feels happy." },
          { id: "opt_makes_sick", label: "She makes them sick." },
          { id: "opt_makes_storm", label: "She makes a storm." }
        ],
        correctOptionIds: ["opt_makes_happy"],
        hintCopy: "help old people 的结果是双方都开心。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g6a_u07_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6a_u08_main",
    title: "节水行动海报",
    sceneId: "scene_kitchen",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "节水海报要完成，帮大家判断哪些行为该改。",
    successCopy: "水滴星片点亮了，节水海报完成。",
    retryCopy: "再看 should、waste、enough、save、drop 和 fresh。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Mum says: We shouldn't waste water. 为什么？",
        anchorId: "anchor_kitchen_cup",
        knowledgeIds: ["kn_eng_g6a_u08_core"],
        corpusVocabularyIds: ["voc_g6a_0652", "voc_g6a_0653", "voc_g6a_0655"],
        corpusSentenceIds: ["sen_g6a_1221", "sen_g6a_1222", "sen_g6a_1223"],
        options: [
          { id: "opt_not_enough", label: "There isn't enough water on the earth." },
          { id: "opt_tastes_good", label: "The mooncake tastes good." },
          { id: "opt_biggest_bird", label: "The fifth bird is the biggest." }
        ],
        correctOptionIds: ["opt_not_enough"],
        hintCopy: "enough water 是关键线索。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把节水词语和海报提醒配对。",
        anchorId: "anchor_kitchen_oven",
        knowledgeIds: ["kn_eng_g6a_u08_core"],
        corpusVocabularyIds: ["voc_g6a_0652", "voc_g6a_0653", "voc_g6a_0654", "voc_g6a_0655", "voc_g6a_0656", "voc_g6a_0657", "voc_g6a_0658"],
        corpusSentenceIds: ["sen_g6a_1224", "sen_g6a_1265"],
        options: [
          { id: "opt_should_rule", label: "should → good rule" },
          { id: "opt_waste_bad", label: "waste → wrong use" },
          { id: "opt_blouse_wash", label: "blouse → washing clothes" },
          { id: "opt_enough_water", label: "enough → enough water" },
          { id: "opt_save_drop", label: "save → every drop" },
          { id: "opt_fresh_water", label: "fresh → clean water" },
          { id: "opt_fever_drop", label: "fever → drop" }
        ],
        correctOptionIds: ["opt_should_rule", "opt_waste_bad", "opt_blouse_wash", "opt_enough_water", "opt_save_drop", "opt_fresh_water"],
        hintCopy: "shouldn't 表示不应该，save every drop 是节水行动。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Mr Zhou often washes his car and uses a lot of water. Mrs Zhou 会怎么劝？",
        anchorId: "anchor_kitchen_timer",
        knowledgeIds: ["kn_eng_g6a_u08_core"],
        corpusSentenceIds: ["sen_g6a_1225", "sen_g6a_1226", "sen_g6a_1227", "sen_g6a_1228", "sen_g6a_1229", "sen_g6a_1230"],
        options: [
          { id: "opt_shouldnt_wash", label: "You shouldn't wash your car too often." },
          { id: "opt_should_play", label: "You should play computer games often." },
          { id: "opt_should_mooncake", label: "You should eat mooncakes." }
        ],
        correctOptionIds: ["opt_shouldnt_wash"],
        hintCopy: "too often 和 a lot of water 指向浪费。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g6a_u08_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6a_u09_main",
    title: "黏土鸟展台",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "黏土鸟展要开幕，帮 Peter 按大小布置展台。",
    successCopy: "黏土展台点亮了，比较线索排好了。",
    retryCopy: "再看 bigger than、smaller than、biggest、smallest 和 best。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "This bird is bigger than the first one. than 表示什么？",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g6a_u09_core"],
        corpusVocabularyIds: ["voc_g6a_0659"],
        corpusSentenceIds: ["sen_g6a_1231", "sen_g6a_1232"],
        options: [
          { id: "opt_compare_than", label: "compare two things" },
          { id: "opt_ask_way", label: "ask the way" },
          { id: "opt_save_water", label: "save water" }
        ],
        correctOptionIds: ["opt_compare_than"],
        hintCopy: "than 常用于比较。"
      },
      {
        id: "step_002",
        type: "order",
        prompt: "按黏土鸟从小到大的展台顺序排列。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g6a_u09_core"],
        corpusSentenceIds: ["sen_g6a_1232", "sen_g6a_1233", "sen_g6a_1234"],
        options: [
          { id: "opt_first_bird", label: "first bird: small" },
          { id: "opt_second_bird", label: "second bird: bigger" },
          { id: "opt_third_bird", label: "third bird: bigger" },
          { id: "opt_fifth_bird", label: "fifth bird: biggest" }
        ],
        correctOptionIds: ["opt_first_bird", "opt_second_bird", "opt_third_bird", "opt_fifth_bird"],
        hintCopy: "比较级逐步变大，biggest 是最大。"
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把森林鸟的比较线索配好。",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g6a_u09_core"],
        corpusSentenceIds: ["sen_g6a_1235", "sen_g6a_1236", "sen_g6a_1237", "sen_g6a_1238", "sen_g6a_1239", "sen_g6a_1240"],
        options: [
          { id: "opt_baker_bob", label: "Baker → bigger than Bob" },
          { id: "opt_baker_ben", label: "Baker → smaller than Ben" },
          { id: "opt_baker_louder", label: "Baker's singing → louder" },
          { id: "opt_jane_smallest", label: "Jane → smallest" },
          { id: "opt_best_singers", label: "birds → best singers" },
          { id: "opt_medicine_bigger", label: "medicine → bigger" }
        ],
        correctOptionIds: ["opt_baker_bob", "opt_baker_ben", "opt_baker_louder", "opt_jane_smallest", "opt_best_singers"],
        hintCopy: "bigger、smaller、louder、smallest 都是比较线索。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g6a_u09_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6a_u10_main",
    title: "健康建议包",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "朋友身体不舒服，帮医生选择合适建议。",
    successCopy: "健康包点亮了，医嘱卡整理完成。",
    retryCopy: "再看 feel、well、cough、headache、fever、medicine 和 rest。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "I don't feel well. I feel cold and I have a cough. 这是在说什么？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g6a_u10_core"],
        corpusVocabularyIds: ["voc_g6a_0660", "voc_g6a_0661", "voc_g6a_0662"],
        corpusSentenceIds: ["sen_g6a_1241"],
        options: [
          { id: "opt_not_well", label: "He is not well." },
          { id: "opt_happy_picnic", label: "He is having a picnic." },
          { id: "opt_bigger_bird", label: "He is making a bigger bird." }
        ],
        correctOptionIds: ["opt_not_well"],
        hintCopy: "don't feel well 表示身体不舒服。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把症状和医嘱配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g6a_u10_core"],
        corpusVocabularyIds: ["voc_g6a_0662", "voc_g6a_0663", "voc_g6a_0664", "voc_g6a_0665", "voc_g6a_0666"],
        corpusSentenceIds: ["sen_g6a_1242", "sen_g6a_1243", "sen_g6a_1244", "sen_g6a_1266"],
        options: [
          { id: "opt_headache_check", label: "headache → let me check" },
          { id: "opt_fever_cold", label: "fever → bad cold" },
          { id: "opt_cough_water", label: "cough → drink more water" },
          { id: "opt_medicine_take", label: "medicine → take some" },
          { id: "opt_rest_bed", label: "rest → in bed" },
          { id: "opt_than_fever", label: "than → fever" }
        ],
        correctOptionIds: ["opt_headache_check", "opt_fever_cold", "opt_cough_water", "opt_medicine_take", "opt_rest_bed"],
        hintCopy: "医生建议包括喝水、吃药、卧床休息。"
      },
      {
        id: "step_003",
        type: "order",
        prompt: "按 Dino 生病经过排相册。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g6a_u10_core"],
        corpusSentenceIds: ["sen_g6a_1245", "sen_g6a_1246", "sen_g6a_1247", "sen_g6a_1248"],
        options: [
          { id: "opt_party_late", label: "came back home very late" },
          { id: "opt_felt_cold", label: "felt cold and had a headache" },
          { id: "opt_tim_hospital", label: "Tim wanted to take him to hospital" },
          { id: "opt_water_medicine", label: "Dino wanted water as medicine" }
        ],
        correctOptionIds: ["opt_party_late", "opt_felt_cold", "opt_tim_hospital", "opt_water_medicine"],
        hintCopy: "先晚归，再生病，最后讨论治疗。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g6a_u10_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6a_u11_main",
    title: "剧场电话约定",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "新剧要开演了，帮朋友打电话约好时间地点。",
    successCopy: "剧场海报点亮了，电话约定完成。",
    retryCopy: "再看 idea、play、concert、hall、film、theatre、call 和 plan。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "电话里说 Is that Anne? Yes. This is Anne. 这是哪类对话？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g6a_u11_core"],
        corpusVocabularyIds: ["voc_g6a_0673"],
        corpusSentenceIds: ["sen_g6a_1249"],
        options: [
          { id: "opt_phone_call", label: "a phone call" },
          { id: "opt_weather_report", label: "a weather forecast" },
          { id: "opt_doctor_check", label: "a doctor check" }
        ],
        correctOptionIds: ["opt_phone_call"],
        hintCopy: "Is that...? This is... 是电话用语。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把剧场约定词和活动配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g6a_u11_core"],
        corpusVocabularyIds: ["voc_g6a_0667", "voc_g6a_0668", "voc_g6a_0669", "voc_g6a_0670", "voc_g6a_0671", "voc_g6a_0672", "voc_g6a_0674"],
        corpusSentenceIds: ["sen_g6a_1250", "sen_g6a_1251", "sen_g6a_1252", "sen_g6a_1253"],
        options: [
          { id: "opt_good_idea", label: "idea → good idea" },
          { id: "opt_play_theatre", label: "play → Star Theatre" },
          { id: "opt_concert_hall", label: "concert → hall" },
          { id: "opt_film_cinema", label: "film → cinema" },
          { id: "opt_theatre_play", label: "theatre → see the play" },
          { id: "opt_plan_meet", label: "plan → meet at 2:00 p.m." },
          { id: "opt_fever_theatre", label: "fever → theatre" }
        ],
        correctOptionIds: ["opt_good_idea", "opt_play_theatre", "opt_concert_hall", "opt_film_cinema", "opt_theatre_play", "opt_plan_meet"],
        hintCopy: "Shall we...? 用来提出建议。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "A new play is on at Star Theatre. The time is 2:30 p.m. 他们几点见？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g6a_u11_core"],
        corpusSentenceIds: ["sen_g6a_1251", "sen_g6a_1252", "sen_g6a_1253"],
        options: [
          { id: "opt_meet_200", label: "2:00 p.m. at Star Theatre" },
          { id: "opt_meet_230", label: "2:30 p.m. at home" },
          { id: "opt_meet_900", label: "9:00 a.m. at the park" }
        ],
        correctOptionIds: ["opt_meet_200"],
        hintCopy: "演出 2:30，见面时间是 2:00。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g6a_u11_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6a_u12_main",
    title: "冬日祝福树",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "冬日祝福树要装饰好了，帮大家整理节日卡。",
    successCopy: "彩灯点亮了，冬日祝福树完成。",
    retryCopy: "再看 Christmas、decorate、colourful、light、present、Santa Claus 和 greet。",
    estimatedMinutes: 8,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "It's Christmas again! Here's a present for you. 收到礼物应该怎么回应？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g6a_u12_core"],
        corpusVocabularyIds: ["voc_g6a_0675", "voc_g6a_0679"],
        corpusSentenceIds: ["sen_g6a_1254", "sen_g6a_1255"],
        options: [
          { id: "opt_thank_mum", label: "Thank you, Mum." },
          { id: "opt_get_off", label: "Get off at the third stop." },
          { id: "opt_have_fever", label: "You have a fever." }
        ],
        correctOptionIds: ["opt_thank_mum"],
        hintCopy: "收到 present 后要感谢。"
      },
      {
        id: "step_002",
        type: "order",
        prompt: "按圣诞准备和庆祝顺序排卡片。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g6a_u12_core"],
        corpusVocabularyIds: ["voc_g6a_0676", "voc_g6a_0677", "voc_g6a_0678", "voc_g6a_0681", "voc_g6a_0682", "voc_g6a_0683"],
        corpusSentenceIds: ["sen_g6a_1256", "sen_g6a_1257", "sen_g6a_1258", "sen_g6a_1259", "sen_g6a_1260", "sen_g6a_1261", "sen_g6a_1262"],
        options: [
          { id: "opt_send_cards", label: "send Christmas cards" },
          { id: "opt_buy_presents", label: "buy presents" },
          { id: "opt_decorate_tree", label: "decorate the Christmas tree" },
          { id: "opt_greet_dinner", label: "greet each other and have dinner" }
        ],
        correctOptionIds: ["opt_send_cards", "opt_buy_presents", "opt_decorate_tree", "opt_greet_dinner"],
        hintCopy: "先准备卡片礼物和树，再节日当天问候聚餐。"
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把六上复习句型配回主题。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g6a_u12_core"],
        corpusSentenceIds: ["sen_g6a_1267", "sen_g6a_1268", "sen_g6a_1269", "sen_g6a_1270", "sen_g6a_1271", "sen_g6a_1272", "sen_g6a_1273", "sen_g6a_1274", "sen_g6a_1275", "sen_g6a_1276", "sen_g6a_1277", "sen_g6a_1278", "sen_g6a_1279"],
        options: [
          { id: "opt_review_holiday", label: "What did you do → holidays" },
          { id: "opt_review_habit", label: "always/often/sometimes → habits" },
          { id: "opt_review_computer", label: "email/search → computer" },
          { id: "opt_review_mooncake", label: "I'd like mooncakes → festival order" },
          { id: "opt_review_weather", label: "It will be / There will be → forecast" },
          { id: "opt_review_picnic", label: "I will bring → picnic" },
          { id: "opt_review_route", label: "get off → Christmas" }
        ],
        correctOptionIds: ["opt_review_holiday", "opt_review_habit", "opt_review_computer", "opt_review_mooncake", "opt_review_weather", "opt_review_picnic"],
        hintCopy: "Unit 12 也复习六上多个核心表达。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g6a_u12_star", quantity: 1 }]
  }
];

const g6bTaskConfigs = [
  {
    id: "task_eng_g6b_u01_main",
    title: "家庭周末出游",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "周末出游要安排好了，帮一家人做计划。",
    successCopy: "家庭出游票点亮了，周末计划完成。",
    retryCopy: "再看 Shall we、We'll、together、ride 和 grandparent。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "It's Sunday. Dad 说 We'll visit your grandpa and grandma. 他们要去哪？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g6b_u01_core"],
        corpusVocabularyIds: ["voc_g6b_0726"],
        corpusSentenceIds: ["sen_g6b_1334", "sen_g6b_1335", "sen_g6b_1336"],
        options: [
          { id: "opt_visit_grandparents", label: "visit grandparents" },
          { id: "opt_watch_film_earth", label: "watch a film about Earth" },
          { id: "opt_plant_trees", label: "plant more trees" }
        ],
        correctOptionIds: ["opt_visit_grandparents"],
        hintCopy: "grandpa and grandma 就是 grandparents。"
      },
      {
        id: "step_002",
        type: "order",
        prompt: "按家庭出游计划排序。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g6b_u01_core"],
        corpusVocabularyIds: ["voc_g6b_0685", "voc_g6b_0686", "voc_g6b_0724", "voc_g6b_0725"],
        corpusSentenceIds: ["sen_g6b_1337", "sen_g6b_1338", "sen_g6b_1339", "sen_g6b_1340"],
        options: [
          { id: "opt_walk", label: "take a walk" },
          { id: "opt_ride_bikes", label: "ride bicycles and look at flowers" },
          { id: "opt_go_shopping", label: "go shopping" },
          { id: "opt_dinner_together", label: "have dinner together" }
        ],
        correctOptionIds: ["opt_walk", "opt_ride_bikes", "opt_go_shopping", "opt_dinner_together"],
        hintCopy: "Then 提示后续顺序。"
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把出游词和家庭活动配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g6b_u01_core"],
        corpusVocabularyIds: ["voc_g6b_0684", "voc_g6b_0685", "voc_g6b_0686", "voc_g6b_0726"],
        corpusSentenceIds: ["sen_g6b_1341", "sen_g6b_1342", "sen_g6b_1343", "sen_g6b_1344", "sen_g6b_1345", "sen_g6b_1419", "sen_g6b_1420"],
        options: [
          { id: "opt_together_family", label: "together → family time" },
          { id: "opt_ride_bicycle", label: "ride → bicycle" },
          { id: "opt_land_beach", label: "land → beach / park" },
          { id: "opt_grandparent_home", label: "grandparent → family home" },
          { id: "opt_picnic_food", label: "outing → picnic food" },
          { id: "opt_meat_ride", label: "meat → ride" }
        ],
        correctOptionIds: ["opt_together_family", "opt_ride_bicycle", "opt_land_beach", "opt_grandparent_home", "opt_picnic_food"],
        hintCopy: "家庭出游强调 together。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g6b_u01_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6b_u02_main",
    title: "故事展选书",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "故事展要选书，帮大家读懂比较线索。",
    successCopy: "故事星片点亮了，选书展台完成。",
    retryCopy: "再看 better than、more interesting、meat、wood、drop 和 lose。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "狗想要水里的肉，因为它想 That piece of meat is better than mine. 结果怎样？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g6b_u02_core"],
        corpusVocabularyIds: ["voc_g6b_0687", "voc_g6b_0688"],
        corpusSentenceIds: ["sen_g6b_1346", "sen_g6b_1347", "sen_g6b_1348", "sen_g6b_1349", "sen_g6b_1350", "sen_g6b_1351", "sen_g6b_1352", "sen_g6b_1424"],
        options: [
          { id: "opt_lost_meat", label: "It lost its meat." },
          { id: "opt_got_two", label: "It got two pieces of meat." },
          { id: "opt_planted_tree", label: "It planted a tree." }
        ],
        correctOptionIds: ["opt_lost_meat"],
        hintCopy: "opened its mouth 后 meat dropped into the water。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把故事词和情节配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g6b_u02_core"],
        corpusVocabularyIds: ["voc_g6b_0687", "voc_g6b_0688", "voc_g6b_0689", "voc_g6b_0690", "voc_g6b_0691", "voc_g6b_0692", "voc_g6b_0693", "voc_g6b_0694"],
        options: [
          { id: "opt_meat_piece", label: "meat → a piece of meat" },
          { id: "opt_happily_home", label: "happily → walked home" },
          { id: "opt_wood_cross", label: "wood → cross the river" },
          { id: "opt_its_mouth", label: "its → its mouth" },
          { id: "opt_drop_water", label: "drop → into water" },
          { id: "opt_lose_meat", label: "lose → lost meat" },
          { id: "opt_earth_meat", label: "Earth → meat" }
        ],
        correctOptionIds: ["opt_meat_piece", "opt_happily_home", "opt_wood_cross", "opt_its_mouth", "opt_drop_water", "opt_lose_meat"],
        hintCopy: "这则故事按肉、过河、掉落、失去推进。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "Miss Li 说 Some books on science are like fairy tales. 它们怎么样？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g6b_u02_core"],
        corpusSentenceIds: ["sen_g6b_1353", "sen_g6b_1354", "sen_g6b_1355", "sen_g6b_1425"],
        options: [
          { id: "opt_more_interesting", label: "They are more interesting than others." },
          { id: "opt_more_difficult", label: "They are more difficult than others." },
          { id: "opt_more_afraid", label: "They are more afraid than others." }
        ],
        correctOptionIds: ["opt_more_interesting"],
        hintCopy: "more interesting than 是比较级表达。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g6b_u02_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6b_u03_main",
    title: "健康生活清单",
    sceneId: "scene_kitchen",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "健康清单要完成，帮大家选出自理习惯。",
    successCopy: "健康手环点亮了，自理清单完成。",
    retryCopy: "再看 take care of、healthy、keep、exercise 和 jog。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "We should learn to take care of ourselves. 这样我们会怎样？",
        anchorId: "anchor_kitchen_cup",
        knowledgeIds: ["kn_eng_g6b_u03_core"],
        corpusVocabularyIds: ["voc_g6b_0695", "voc_g6b_0696"],
        corpusSentenceIds: ["sen_g6b_1356", "sen_g6b_1426"],
        options: [
          { id: "opt_strong_healthy", label: "strong and healthy" },
          { id: "opt_afraid_tired", label: "afraid and tired" },
          { id: "opt_lost_meat", label: "lost meat" }
        ],
        correctOptionIds: ["opt_strong_healthy"],
        hintCopy: "strong and healthy 是健康自理目标。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把健康建议和行动配对。",
        anchorId: "anchor_kitchen_oven",
        knowledgeIds: ["kn_eng_g6b_u03_core"],
        corpusVocabularyIds: ["voc_g6b_0696", "voc_g6b_0697", "voc_g6b_0698", "voc_g6b_0699"],
        corpusSentenceIds: ["sen_g6b_1357", "sen_g6b_1358", "sen_g6b_1359", "sen_g6b_1360", "sen_g6b_1427"],
        options: [
          { id: "opt_wash_clean", label: "wash hands/face/body → keep clean" },
          { id: "opt_eat_healthy", label: "eat vegetables, fish and fruit → healthy food" },
          { id: "opt_exercise_strong", label: "do exercise → strong" },
          { id: "opt_jog_walk", label: "jog / take long walks → exercise" },
          { id: "opt_happy_sing", label: "sing, dance and draw → happy" },
          { id: "opt_meat_healthy", label: "lose meat → healthy" }
        ],
        correctOptionIds: ["opt_wash_clean", "opt_eat_healthy", "opt_exercise_strong", "opt_jog_walk", "opt_happy_sing"],
        hintCopy: "should 后面接健康习惯。"
      },
      {
        id: "step_003",
        type: "order",
        prompt: "按 Mr Lin 的一天排健康作息。",
        anchorId: "anchor_kitchen_timer",
        knowledgeIds: ["kn_eng_g6b_u03_core"],
        corpusSentenceIds: ["sen_g6b_1361", "sen_g6b_1362", "sen_g6b_1363", "sen_g6b_1364", "sen_g6b_1365"],
        options: [
          { id: "opt_tai_chi", label: "does tai chi and walks" },
          { id: "opt_lunch", label: "has healthy lunch" },
          { id: "opt_read_music", label: "reads newspapers and listens to music" },
          { id: "opt_bed_10", label: "goes to bed before 10:00 p.m." }
        ],
        correctOptionIds: ["opt_tai_chi", "opt_lunch", "opt_read_music", "opt_bed_10"],
        hintCopy: "按 morning、lunch、afternoon、night 排。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g6b_u03_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6b_u04_main",
    title: "小镇植树行动",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "植树日到了，帮小镇完成环保行动。",
    successCopy: "小树苗点亮了，植树行动完成。",
    retryCopy: "再看 Tree Planting Day、air、place、keep 和 make。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Planting trees is good for us. 今天是什么日子？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g6b_u04_core"],
        corpusVocabularyIds: ["voc_g6b_0700"],
        corpusSentenceIds: ["sen_g6b_1366", "sen_g6b_1428"],
        options: [
          { id: "opt_tree_day", label: "Tree Planting Day" },
          { id: "opt_childrens_day", label: "Children's Day" },
          { id: "opt_christmas", label: "Christmas" }
        ],
        correctOptionIds: ["opt_tree_day"],
        hintCopy: "Tree Planting Day 是植树节。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把树木作用和结果配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g6b_u04_core"],
        corpusVocabularyIds: ["voc_g6b_0701", "voc_g6b_0702", "voc_g6b_0739", "voc_g6b_0740", "voc_g6b_0741"],
        corpusSentenceIds: ["sen_g6b_1367", "sen_g6b_1368", "sen_g6b_1369", "sen_g6b_1429", "sen_g6b_1430"],
        options: [
          { id: "opt_air_clean", label: "air → keep clean" },
          { id: "opt_us_cool", label: "trees → keep us cool" },
          { id: "opt_place_beautiful", label: "place → make beautiful" },
          { id: "opt_plant_fun", label: "planting trees → fun" },
          { id: "opt_fruit_trees", label: "fruit trees → plant" },
          { id: "opt_meat_air", label: "meat → air" }
        ],
        correctOptionIds: ["opt_air_clean", "opt_us_cool", "opt_place_beautiful", "opt_plant_fun", "opt_fruit_trees"],
        hintCopy: "keep 和 make 后面说明树木的作用。"
      },
      {
        id: "step_003",
        type: "choice",
        prompt: "天气变热了，What can we do? 应该怎么做？",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g6b_u04_core"],
        corpusSentenceIds: ["sen_g6b_1370", "sen_g6b_1371", "sen_g6b_1372", "sen_g6b_1373"],
        options: [
          { id: "opt_plant_more", label: "plant more trees" },
          { id: "opt_cut_more", label: "cut down more trees" },
          { id: "opt_drop_meat", label: "drop the meat" }
        ],
        correctOptionIds: ["opt_plant_more"],
        hintCopy: "make the Earth clean and green 是目标。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g6b_u04_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6b_u05_main",
    title: "地球星空馆",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "星空馆要讲解地球，帮 Peter 整理展板。",
    successCopy: "地球徽章点亮了，星空馆展板完成。",
    retryCopy: "再看 Earth、space、sea、land、sun 和 seasons。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Peter and his mother went to the Space Museum. 他们看了什么电影？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g6b_u05_core"],
        corpusVocabularyIds: ["voc_g6b_0703", "voc_g6b_0704"],
        corpusSentenceIds: ["sen_g6b_1374", "sen_g6b_1375"],
        options: [
          { id: "opt_earth_film", label: "a film about the Earth" },
          { id: "opt_dog_story", label: "a story about a dog" },
          { id: "opt_dance_show", label: "a dance show" }
        ],
        correctOptionIds: ["opt_earth_film"],
        hintCopy: "Space Museum 和 Earth 是核心线索。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把地球展板信息配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g6b_u05_core"],
        corpusSentenceIds: ["sen_g6b_1376", "sen_g6b_1377", "sen_g6b_1378"],
        options: [
          { id: "opt_earth_ball", label: "Earth → looks like a ball" },
          { id: "opt_water_land", label: "Earth → has water and land" },
          { id: "opt_warm_live", label: "warm → animals and plants can live" },
          { id: "opt_space_books", label: "space → library books" },
          { id: "opt_stars_more", label: "stars → find out more" },
          { id: "opt_afraid_earth", label: "afraid → Earth" }
        ],
        correctOptionIds: ["opt_earth_ball", "opt_water_land", "opt_warm_live", "opt_space_books", "opt_stars_more"],
        hintCopy: "客观介绍地球时用一般现在时。"
      },
      {
        id: "step_003",
        type: "order",
        prompt: "按地球知识展板顺序排。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g6b_u05_core"],
        corpusSentenceIds: ["sen_g6b_1378", "sen_g6b_1379", "sen_g6b_1380"],
        options: [
          { id: "opt_ball", label: "Earth looks like a ball" },
          { id: "opt_day_night", label: "sun-facing half has day" },
          { id: "opt_year_sun", label: "Earth goes round the sun in one year" },
          { id: "opt_four_seasons", label: "we have four seasons" }
        ],
        correctOptionIds: ["opt_ball", "opt_day_night", "opt_year_sun", "opt_four_seasons"],
        hintCopy: "先外形，再昼夜，再四季。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g6b_u05_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6b_u06_main",
    title: "毕业演出排练",
    sceneId: "scene_wardrobe",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "毕业演出要排练，帮 Anne 学会舞步和演出安排。",
    successCopy: "演出服饰点亮了，排练计划完成。",
    retryCopy: "再看 wanted to、move、easy、step on、aloud 和 piano。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Anne watched Lingling. Anne wanted to do what?",
        anchorId: "anchor_wardrobe_mirror",
        knowledgeIds: ["kn_eng_g6b_u06_core"],
        corpusVocabularyIds: ["voc_g6b_0705"],
        corpusSentenceIds: ["sen_g6b_1381", "sen_g6b_1382"],
        options: [
          { id: "opt_wanted_dance", label: "dance like Lingling" },
          { id: "opt_wanted_swim", label: "swim in the pool" },
          { id: "opt_wanted_travel", label: "travel to France" }
        ],
        correctOptionIds: ["opt_wanted_dance"],
        hintCopy: "wanted to dance like Lingling 是关键句。"
      },
      {
        id: "step_002",
        type: "order",
        prompt: "按 Lingling 教舞步的过程排序。",
        anchorId: "anchor_wardrobe_rack",
        knowledgeIds: ["kn_eng_g6b_u06_core"],
        corpusVocabularyIds: ["voc_g6b_0705", "voc_g6b_0706", "voc_g6b_0707"],
        corpusSentenceIds: ["sen_g6b_1383", "sen_g6b_1384", "sen_g6b_1385", "sen_g6b_1386"],
        options: [
          { id: "opt_move_hands", label: "move hands and legs with music" },
          { id: "opt_arms_out", label: "put arms out" },
          { id: "opt_step_on", label: "stepped on Lingling's foot" },
          { id: "opt_do_again", label: "Let's do it again" }
        ],
        correctOptionIds: ["opt_move_hands", "opt_arms_out", "opt_step_on", "opt_do_again"],
        hintCopy: "先示范，再练习，出错后再来一次。"
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把演出安排和节目配对。",
        anchorId: "anchor_wardrobe_shoes",
        knowledgeIds: ["kn_eng_g6b_u06_core"],
        corpusVocabularyIds: ["voc_g6b_0708", "voc_g6b_0709"],
        corpusSentenceIds: ["sen_g6b_1387", "sen_g6b_1388", "sen_g6b_1389", "sen_g6b_1390"],
        options: [
          { id: "opt_concert_after", label: "school concert → after exams" },
          { id: "opt_modern_dance", label: "Anne and Lingling → modern dance" },
          { id: "opt_song_small_world", label: "Peter and Mingming → sing" },
          { id: "opt_dance_steps", label: "Lingling → teaches dance steps" },
          { id: "opt_clothes_make", label: "Anne's mother → concert clothes" },
          { id: "opt_piano_aloud", label: "piano / aloud → performance words" },
          { id: "opt_earth_dance", label: "Earth → dance steps" }
        ],
        correctOptionIds: ["opt_concert_after", "opt_modern_dance", "opt_song_small_world", "opt_dance_steps", "opt_clothes_make", "opt_piano_aloud"],
        hintCopy: "演出安排包含舞蹈、歌曲和服装。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g6b_u06_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6b_u07_main",
    title: "勇气挑战卡",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "伙伴有点害怕，帮他读懂鼓励和安全线索。",
    successCopy: "勇气贴纸点亮了，挑战完成。",
    retryCopy: "再看 afraid、close、tired、difficult、clever、worry 和 kid。",
    estimatedMinutes: 6,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "I'm afraid of it! Oh, please close the book. 他感觉怎样？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g6b_u07_core"],
        corpusVocabularyIds: ["voc_g6b_0710", "voc_g6b_0711"],
        corpusSentenceIds: ["sen_g6b_1391"],
        options: [
          { id: "opt_afraid", label: "afraid" },
          { id: "opt_interested", label: "interested" },
          { id: "opt_happily", label: "happily" }
        ],
        correctOptionIds: ["opt_afraid"],
        hintCopy: "afraid 表示害怕。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把情绪和鼓励语配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g6b_u07_core"],
        corpusVocabularyIds: ["voc_g6b_0710", "voc_g6b_0712", "voc_g6b_0713", "voc_g6b_0714", "voc_g6b_0715", "voc_g6b_0716"],
        corpusSentenceIds: ["sen_g6b_1392", "sen_g6b_1393", "sen_g6b_1394", "sen_g6b_1395"],
        options: [
          { id: "opt_tired_sleep", label: "tired → shouldn't sleep in library" },
          { id: "opt_difficult_not_afraid", label: "difficult → not afraid" },
          { id: "opt_clever_later", label: "clever → better later on" },
          { id: "opt_worry_dont", label: "worry → Don't worry" },
          { id: "opt_kid_still", label: "kid → still a kid" },
          { id: "opt_close_book", label: "close → close the book" },
          { id: "opt_meat_afraid", label: "meat → afraid" }
        ],
        correctOptionIds: ["opt_tired_sleep", "opt_difficult_not_afraid", "opt_clever_later", "opt_worry_dont", "opt_kid_still", "opt_close_book"],
        hintCopy: "鼓励语常用 Don't worry。"
      },
      {
        id: "step_003",
        type: "order",
        prompt: "按游泳挑战经历排序。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g6b_u07_core"],
        corpusSentenceIds: ["sen_g6b_1396", "sen_g6b_1397", "sen_g6b_1398", "sen_g6b_1399", "sen_g6b_1400", "sen_g6b_1401"],
        options: [
          { id: "opt_pool", label: "went to the swimming pool" },
          { id: "opt_afraid_water", label: "Dongdong was afraid of water" },
          { id: "opt_safe_steps", label: "Use the steps. It's safe" },
          { id: "opt_learn_swim", label: "jump into water to learn" }
        ],
        correctOptionIds: ["opt_pool", "opt_afraid_water", "opt_safe_steps", "opt_learn_swim"],
        hintCopy: "安全鼓励一步一步推进。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g6b_u07_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6b_u08_main",
    title: "儿童节派对计划",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "毕业前的儿童节派对要安排，帮班级排计划。",
    successCopy: "派对彩带点亮了，儿童节计划完成。",
    retryCopy: "再看 party、will、going to、have fun 和 first of June。",
    estimatedMinutes: 4,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: "Tomorrow will be International Children's Day. 明天会怎样？",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g6b_u08_core"],
        corpusVocabularyIds: ["voc_g6b_0717"],
        corpusSentenceIds: ["sen_g6b_1402", "sen_g6b_1403"],
        options: [
          { id: "opt_play_party", label: "play games and have a party" },
          { id: "opt_take_medicine", label: "take medicine and rest" },
          { id: "opt_cross_river", label: "cross the river" }
        ],
        correctOptionIds: ["opt_play_party"],
        hintCopy: "Children's Day 活动是 games 和 party。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把儿童节活动和安排配对。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g6b_u08_core"],
        corpusSentenceIds: ["sen_g6b_1404", "sen_g6b_1405", "sen_g6b_1406", "sen_g6b_1407", "sen_g6b_1408", "sen_g6b_1409", "sen_g6b_1410"],
        options: [
          { id: "opt_no_lessons", label: "no lessons → have a rest" },
          { id: "opt_class_party", label: "class party → enjoy ourselves" },
          { id: "opt_first_june", label: "first of June → Children's Day" },
          { id: "opt_games_cakes", label: "games and cakes → party" },
          { id: "opt_film_museum", label: "film / museum → holiday activity" },
          { id: "opt_afraid_party", label: "afraid → party" }
        ],
        correctOptionIds: ["opt_no_lessons", "opt_class_party", "opt_first_june", "opt_games_cakes", "opt_film_museum"],
        hintCopy: "will 和 be going to 都能描述未来安排。"
      },
      {
        id: "step_003",
        type: "order",
        prompt: "按儿童节介绍逻辑排展板。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g6b_u08_core"],
        corpusSentenceIds: ["sen_g6b_1402", "sen_g6b_1403", "sen_g6b_1407", "sen_g6b_1408", "sen_g6b_1409", "sen_g6b_1410"],
        options: [
          { id: "opt_day_tomorrow", label: "Tomorrow will be Children's Day" },
          { id: "opt_party_plan", label: "play games and have a party" },
          { id: "opt_date_june", label: "falls on the first of June" },
          { id: "opt_children_enjoy", label: "children enjoy the holiday" }
        ],
        correctOptionIds: ["opt_day_tomorrow", "opt_party_plan", "opt_date_june", "opt_children_enjoy"],
        hintCopy: "先说时间，再说活动和节日介绍。"
      }
    ],
    rewards: [{ rewardId: "reward_heart", quantity: 1 }, { rewardId: "reward_eng_g6b_u08_star", quantity: 1 }]
  },
  {
    id: "task_eng_g6b_u09_main",
    title: "世界名胜旅行分享",
    sceneId: "scene_study",
    subjectMix: ["english"],
    recommendedGradeBand: "g5_6",
    introCopy: "毕业旅行星图最后一站，完成世界名胜分享。",
    successCopy: "毕业星图点亮了，小学英语主线完成。",
    retryCopy: "再看 Eiffel Tower、Golden Gate Bridge、Great Wall、Big Ben 和 places of interest。",
    estimatedMinutes: 8,
    steps: [
      {
        id: "step_001",
        type: "match",
        prompt: "把世界名胜和地点配对。",
        anchorId: "anchor_study_map",
        knowledgeIds: ["kn_eng_g6b_u09_core"],
        corpusVocabularyIds: ["voc_g6b_0718", "voc_g6b_0720", "voc_g6b_0721", "voc_g6b_0722", "voc_g6b_0723"],
        corpusSentenceIds: ["sen_g6b_1411", "sen_g6b_1412", "sen_g6b_1413", "sen_g6b_1414"],
        options: [
          { id: "opt_eiffel_france", label: "Eiffel Tower → France" },
          { id: "opt_golden_usa", label: "Golden Gate Bridge → USA" },
          { id: "opt_great_wall_china", label: "Great Wall → Beijing" },
          { id: "opt_big_ben_london", label: "Big Ben → London" },
          { id: "opt_places_travel", label: "places of interest → travel" },
          { id: "opt_meat_france", label: "meat → France" }
        ],
        correctOptionIds: ["opt_eiffel_france", "opt_golden_usa", "opt_great_wall_china", "opt_big_ben_london", "opt_places_travel"],
        hintCopy: "名胜词和国家城市要一一对应。"
      },
      {
        id: "step_002",
        type: "order",
        prompt: "按旅行相册介绍顺序排卡片。",
        anchorId: "anchor_study_bookshelf",
        knowledgeIds: ["kn_eng_g6b_u09_core"],
        corpusVocabularyIds: ["voc_g6b_0719", "voc_g6b_0756"],
        corpusSentenceIds: ["sen_g6b_1415", "sen_g6b_1416", "sen_g6b_1417", "sen_g6b_1418"],
        options: [
          { id: "opt_father_pictures", label: "father brings pictures" },
          { id: "opt_peter_book", label: "Peter keeps them in a book" },
          { id: "opt_show_friends", label: "shows pictures to friends" },
          { id: "opt_anne_bridge", label: "Anne introduces Golden Gate Bridge" }
        ],
        correctOptionIds: ["opt_father_pictures", "opt_peter_book", "opt_show_friends", "opt_anne_bridge"],
        hintCopy: "相册先收集，再展示，最后介绍。"
      },
      {
        id: "step_003",
        type: "match",
        prompt: "把六下复习句型配回主题。",
        anchorId: "anchor_study_mailbox",
        knowledgeIds: ["kn_eng_g6b_u09_core"],
        corpusSentenceIds: ["sen_g6b_1421", "sen_g6b_1422", "sen_g6b_1423", "sen_g6b_1424", "sen_g6b_1425", "sen_g6b_1426", "sen_g6b_1427", "sen_g6b_1428", "sen_g6b_1429", "sen_g6b_1430"],
        options: [
          { id: "opt_review_outing", label: "Where are we going → outing" },
          { id: "opt_review_shall", label: "Shall we → suggestion" },
          { id: "opt_review_compare", label: "better / more interesting → comparison" },
          { id: "opt_review_health", label: "should take care → health" },
          { id: "opt_review_tree", label: "Planting trees → environment" },
          { id: "opt_review_earth", label: "keep air clean → Earth" },
          { id: "opt_review_party", label: "party → comparison" }
        ],
        correctOptionIds: ["opt_review_outing", "opt_review_shall", "opt_review_compare", "opt_review_health", "opt_review_tree", "opt_review_earth"],
        hintCopy: "最后一关复习出游、比较、健康和环保表达。"
      }
    ],
    rewards: [{ rewardId: "reward_star", quantity: 1 }, { rewardId: "reward_eng_g6b_u09_star", quantity: 1 }]
  }
];

const handcraftedTaskConfigs = [...legacyTaskConfigs, ...g5bTaskConfigs, ...g6aTaskConfigs, ...g6bTaskConfigs];

const playableStoryTaskIds = [
  ...Array.from({ length: 10 }, (_, index) => `task_eng_g3b_u${String(index + 1).padStart(2, "0")}_main`),
  ...Array.from({ length: 10 }, (_, index) => `task_eng_g4a_u${String(index + 1).padStart(2, "0")}_main`),
  ...Array.from({ length: 10 }, (_, index) => `task_eng_g4b_u${String(index + 1).padStart(2, "0")}_main`),
  ...Array.from({ length: 12 }, (_, index) => `task_eng_g5a_u${String(index + 1).padStart(2, "0")}_main`),
  ...Array.from({ length: 12 }, (_, index) => `task_eng_g5b_u${String(index + 1).padStart(2, "0")}_main`),
  ...Array.from({ length: 12 }, (_, index) => `task_eng_g6a_u${String(index + 1).padStart(2, "0")}_main`),
  ...Array.from({ length: 9 }, (_, index) => `task_eng_g6b_u${String(index + 1).padStart(2, "0")}_main`)
];

const storyTasksById = Object.fromEntries(englishStoryTaskConfigs.map((task) => [task.id, task]));
const corpusVocabularyById = Object.fromEntries(englishCorpusVocabulary.map((item) => [item.id, item]));
const corpusSentenceById = Object.fromEntries(englishCorpusSentences.map((item) => [item.id, item]));

export const taskConfigs = playableStoryTaskIds
  .map((id) => {
    const task = handcraftedTaskConfigs.find((item) => item.id === id);
    const storyTask = storyTasksById[id];
    if (!task && !storyTask) return null;
    const playableTask = task || createPlayableStoryTask(storyTask);
    const finalSceneId = storyTask?.sceneId || playableTask.sceneId;
    const sceneAnchoredTask = remapTaskScene(playableTask, finalSceneId);
    return {
      ...storyTask,
      ...sceneAnchoredTask,
      sceneId: finalSceneId,
      subjectMix: sceneAnchoredTask.subjectMix,
      corpusVocabularyIds: storyTask?.corpusVocabularyIds || playableTask.corpusVocabularyIds || [],
      corpusSentenceIds: storyTask?.corpusSentenceIds || playableTask.corpusSentenceIds || [],
      rawLineIds: storyTask?.rawLineIds || playableTask.rawLineIds || []
    };
  })
  .filter(Boolean);

export const tasksById = Object.fromEntries(taskConfigs.map((task) => [task.id, task]));
export const tasksBySceneId = taskConfigs.reduce((result, task) => {
  result[task.sceneId] = result[task.sceneId] || [];
  result[task.sceneId].push(task);
  return result;
}, {});

function createPlayableStoryTask(storyTask) {
  const knowledgeId = storyTask.knowledgeIds[0];
  const rewardId = storyTask.rewardIds[0];
  const anchors = anchorsForScene(storyTask.sceneId);
  const vocabularyItems = storyTask.corpusVocabularyIds
    .map((id) => corpusVocabularyById[id])
    .filter(Boolean);
  const sentenceItems = storyTask.corpusSentenceIds
    .map((id) => corpusSentenceById[id])
    .filter((item) => item && item.section !== "vocabulary");
  const selectedVocabulary = vocabularyItems.slice(0, Math.min(6, Math.max(3, vocabularyItems.length)));
  const selectedSentences = (sentenceItems.length ? sentenceItems : storyTask.corpusSentenceIds.map((id) => corpusSentenceById[id]).filter(Boolean))
    .slice(0, 4);
  const choiceSentence = selectedSentences[0];
  const reviewSentences = selectedSentences.slice(0, 3);
  const wrongVocabulary = vocabularyItems.find((item) => !selectedVocabulary.some((selected) => selected.id === item.id));

  return {
    id: storyTask.id,
    title: storyTask.title,
    sceneId: storyTask.sceneId,
    subjectMix: ["english"],
    recommendedGradeBand: storyTask.bookId.startsWith("g6") ? "g5_6" : "g5_6",
    introCopy: compactCopy(storyTask.introCopy, "完成本单元主线委托。"),
    successCopy: compactCopy(storyTask.successCopy, "本单元星片已经点亮。"),
    retryCopy: "再看词语、句子和顺序线索，选更合适的答案。",
    estimatedMinutes: storyTask.estimatedMinutes,
    steps: [
      {
        id: "step_001",
        type: "choice",
        prompt: choiceSentence ? `读委托句：${shortText(choiceSentence.english)} 选它的意思。` : `先确认 ${storyTask.title} 的核心表达。`,
        anchorId: anchors[0],
        knowledgeIds: [knowledgeId],
        corpusSentenceIds: choiceSentence ? [choiceSentence.id] : storyTask.corpusSentenceIds.slice(0, 1),
        options: buildSentenceOptions(choiceSentence, selectedVocabulary, storyTask),
        correctOptionIds: ["opt_sentence_correct"],
        hintCopy: "先抓句子里的关键词，再看中文意思。"
      },
      {
        id: "step_002",
        type: "match",
        prompt: "把本单元核心词语和中文线索配好。",
        anchorId: anchors[1],
        knowledgeIds: [knowledgeId],
        corpusVocabularyIds: selectedVocabulary.map((item) => item.id),
        options: [
          ...selectedVocabulary.map((item, index) => ({
            id: `opt_vocab_${index + 1}`,
            label: `${cleanWord(item.word)} → ${shortText(item.translation, 18)}`
          })),
          {
            id: "opt_vocab_extra",
            label: `${cleanWord(wrongVocabulary?.word || "review")} → 复习干扰项`
          }
        ],
        correctOptionIds: selectedVocabulary.map((_, index) => `opt_vocab_${index + 1}`),
        hintCopy: "只选择词语和中文意思能对应上的卡片。"
      },
      {
        id: "step_003",
        type: "order",
        prompt: "按教材语料出现的顺序整理复盘卡。",
        anchorId: anchors[2],
        knowledgeIds: [knowledgeId],
        corpusSentenceIds: reviewSentences.map((item) => item.id),
        options: reviewSentences.map((item, index) => ({
          id: `opt_line_${index + 1}`,
          label: shortText(item.english, 46)
        })),
        correctOptionIds: reviewSentences.map((_, index) => `opt_line_${index + 1}`),
        hintCopy: "按课文线索从前到后排列。"
      }
    ],
    rewards: [{ rewardId: storyTask.unitNumber % 2 ? "reward_star" : "reward_heart", quantity: 1 }, { rewardId, quantity: 1 }]
  };
}

function remapTaskScene(task, sceneId) {
  const anchors = anchorsForScene(sceneId);
  return {
    ...task,
    sceneId,
    steps: task.steps.map((step, index) => ({
      ...step,
      anchorId: anchors[index % anchors.length]
    }))
  };
}

function buildSentenceOptions(sentence, vocabularyItems, storyTask) {
  if (!sentence) {
    return [
      { id: "opt_sentence_correct", label: storyTask.title },
      { id: "opt_sentence_wrong_1", label: "整理旧委托" },
      { id: "opt_sentence_wrong_2", label: "离开任务" }
    ];
  }
  const vocabHint = vocabularyItems[0];
  return [
    { id: "opt_sentence_correct", label: shortText(sentence.chinese || sentence.english, 34) },
    { id: "opt_sentence_wrong_1", label: vocabHint ? `${cleanWord(vocabHint.word)} 的单词卡` : "单词卡" },
    { id: "opt_sentence_wrong_2", label: "和本句不匹配的生活提示" }
  ];
}

function anchorsForScene(sceneId) {
  return {
    scene_wardrobe: ["anchor_wardrobe_rack", "anchor_wardrobe_mirror", "anchor_wardrobe_shoes"],
    scene_kitchen: ["anchor_kitchen_cup", "anchor_kitchen_oven", "anchor_kitchen_timer"],
    scene_school: ["anchor_school_board", "anchor_school_library", "anchor_school_playground"],
    scene_city: ["anchor_city_station", "anchor_city_map", "anchor_city_sign"],
    scene_festival: ["anchor_festival_stage", "anchor_festival_craft", "anchor_festival_calendar"],
    scene_nature: ["anchor_nature_garden", "anchor_nature_sky", "anchor_nature_earth"],
    scene_health: ["anchor_health_sink", "anchor_health_chart", "anchor_health_kit"],
    scene_study: ["anchor_study_mailbox", "anchor_study_bookshelf", "anchor_study_map"]
  }[sceneId] || ["anchor_study_mailbox", "anchor_study_bookshelf", "anchor_study_map"];
}

function cleanWord(value = "word") {
  return String(value).replace(/^、+/, "").trim() || "word";
}

function compactCopy(value, fallback) {
  return shortText(value || fallback, 76);
}

function shortText(value = "", maxLength = 54) {
  const text = String(value).replace(/\s+/g, " ").trim();
  if (text.length <= maxLength) return text;
  return `${text.slice(0, Math.max(0, maxLength - 1))}…`;
}
