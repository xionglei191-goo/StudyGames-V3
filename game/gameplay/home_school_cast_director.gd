extends RefCounted
## V6 Home & School Cast Director (`HomeSchoolCastDirector`).
## Establishes Home (Mom, Dad, Doggie, Kitty) and School (Teachers + Classmates)
## as the two authentic English-immersion hubs in free sandbox play, removes Uncle Bear
## from Home (keeping him in the village bakery), and provides distinct character-specific
## contextual English greetings + persona conversations for every NPC and resident.

const CharacterVoices = preload("res://core/character_voices.gd")
const Residents = preload("res://actors/building_resident_catalog.gd")

const HOME_ROOMS := [
	"home_estate",
	"home",
	"home_bedroom",
	"home_kitchen",
	"home_dining",
	"home_bathroom",
	"home_study",
	"home_balcony",
]

const SCHOOL_ROOMS := [
	"school",
	"classroom",
	"music_room",
	"art_room",
	"science_room",
	"canteen",
	"playground",
	"football_field",
]

const ROOM_CAST := {
	# ---- Core Stage A: My Home (Parents & Pets; ZERO Uncle Bear) ----
	"home": [
		{"id": "textbook_role_lingling_mother", "display_name": "妈妈 · Mom"},
		{"id": "textbook_kitty", "display_name": "小猫 · Kitty"},
	],
	"home_study": [
		{"id": "textbook_role_lingling_father", "display_name": "爸爸 · Dad"},
	],
	"home_kitchen": [
		{"id": "textbook_role_lingling_mother", "display_name": "妈妈 · Mom"},
	],
	"home_dining": [
		{"id": "textbook_role_lingling_father", "display_name": "爸爸 · Dad"},
		{"id": "textbook_role_lingling_mother", "display_name": "妈妈 · Mom"},
	],
	"home_bedroom": [
		{"id": "textbook_kitty", "display_name": "小猫 · Kitty"},
	],
	"home_bathroom": [],
	"home_estate": [
		{"id": "textbook_doggie", "display_name": "小狗 · Doggie"},
	],
	"home_balcony": [
		{"id": "textbook_kitty", "display_name": "小猫 · Kitty"},
	],
	# ---- Core Stage B: Sunny School (Teachers & Classmates) ----
	"school": [
		{"id": "textbook_lingling", "display_name": "玲玲 · Lingling"},
		{"id": "textbook_anne", "display_name": "安妮 · Anne"},
		{"id": "textbook_peter", "display_name": "彼得 · Peter"},
	],
	"classroom": [
		{"id": "textbook_miss_li", "display_name": "李老师 · Miss Li"},
		{"id": "textbook_mingming", "display_name": "明明 · Mingming"},
		{"id": "textbook_tim", "display_name": "蒂姆 · Tim"},
		{"id": "textbook_amy", "display_name": "艾米 · Amy"},
	],
	"music_room": [
		{"id": "textbook_miss_lin", "display_name": "林老师 · Miss Lin"},
		{"id": "textbook_anne", "display_name": "安妮 · Anne"},
	],
	"art_room": [
		{"id": "textbook_lingling", "display_name": "玲玲 · Lingling"},
	],
	"science_room": [
		{"id": "textbook_mr_chen", "display_name": "陈老师 · Mr Chen"},
		{"id": "textbook_mingming", "display_name": "明明 · Mingming"},
	],
	"canteen": [
		{"id": "textbook_dongdong", "display_name": "东东 · Dongdong"},
	],
	"playground": [
		{"id": "textbook_peter", "display_name": "彼得 · Peter"},
		{"id": "textbook_dongdong", "display_name": "东东 · Dongdong"},
	],
	"football_field": [
		{"id": "textbook_mr_wang", "display_name": "王老师 · Mr Wang"},
		{"id": "textbook_tim", "display_name": "蒂姆 · Tim"},
	],
}

const PROXIMITY_GREETINGS := {
	"textbook_role_lingling_mother@home": [
		{"en": "Welcome home, sweetie! Come and sit on the soft sofa!", "zh": "欢迎回家呀宝贝！过来坐到松软的沙发上歇一歇吧！"},
		{"en": "Have a red apple or a banana from our tea table!", "zh": "来吃颗茶几果盘里的红苹果或者香甜黄香蕉吧！"},
		{"en": "Your home is tidy and warm! Want to check the study or kitchen?", "zh": "家里收拾得暖洋洋的！想去书房找爸爸，还是去厨房看看？"},
	],
	"textbook_role_lingling_mother@home_kitchen": [
		{"en": "Mmm, smell the tomato soup in the pot! Wash your hands first!", "zh": "嗯～闻闻汤锅里的番茄汤多香呀！先去洗干净小手哦！"},
		{"en": "Can you pass me the fresh milk and eggs from the fridge?", "zh": "能帮妈妈把冰箱里的新鲜牛奶和鸡蛋递过来吗？"},
		{"en": "I am washing red tomatoes in the sink right now!", "zh": "妈妈现在正在水槽里洗红彤彤的西红柿呢！"},
	],
	"textbook_role_lingling_mother@home_dining": [
		{"en": "Dinner is ready on the table! Help me set the bowls and spoons!", "zh": "丰盛晚餐摆上桌啦！来帮妈妈摆好碗和勺子吧！"},
		{"en": "How was your day at school today? Tell Mom and Dad!", "zh": "今天在学校过得怎么样呀？快来跟爸爸妈妈说说！"},
	],
	"textbook_role_lingling_father@home_study": [
		{"en": "Look at this sunny wooden desk! Ready to read an English book together?", "zh": "看看这张洒满阳光的木书桌！准备好和爸爸一起读英语书了吗？"},
		{"en": "Can you find your blue pen, pencil, and ruler on the desk?", "zh": "你能在书桌上找到你的蓝钢笔、铅笔和直尺吗？"},
		{"en": "Pull out the chair or sit on the little stool — let's study!", "zh": "拉开椅子或者坐上小木凳——我们一起轻松学起来！"},
	],
	"textbook_role_lingling_father@home_dining": [
		{"en": "Come sit on the dining chair! The dumplings smell wonderful!", "zh": "快坐到餐椅上来！热腾腾的饺子闻起来太香啦！"},
		{"en": "What did you learn with your classmates at school today?", "zh": "今天在学校和同学们学到了什么有趣的新知识？"},
	],
	"textbook_doggie": [
		{"en": "Woof woof! Look, Doggie loves running in the sunny garden!", "zh": "汪汪！快看，小狗最喜欢在阳光花园里奔跑啦！"},
		{"en": "Woof! Doggie is wagging its tail beside the colourful flowers!", "zh": "汪汪！小狗正在花朵旁的绿草地上开心地摇尾巴呢！"},
	],
	"textbook_kitty@home": [
		{"en": "Meow! Kitty is resting on the soft warm sofa!", "zh": "喵～小猫正窝在柔软温暖的沙发上休息呢！"},
		{"en": "Meow~ Look, little Kitty is stretching beside the sunny tea table!", "zh": "喵呜～快看，小猫正在阳光茶几旁轻轻伸懒腰呢！"},
	],
	"textbook_kitty": [
		{"en": "Meow! Little Kitty is curling up in a patch of warm sunshine!", "zh": "喵～小猫正蜷在暖融融的阳光里安静休息呢！"},
		{"en": "Meow~ Kitty is watching your neat wardrobe and cozy room!", "zh": "喵呜～小猫正陪着你一起打理整洁温暖的小房间呢！"},
	],
	"textbook_miss_li": [
		{"en": "Good morning, class! Please sit down and open your English books!", "zh": "同学们早上好！请坐好，翻开课桌上的英语书吧！"},
		{"en": "Look at the blackboard! Let's read this sentence aloud together!", "zh": "请看黑板！让我们一起大声把这句话读出来！"},
		{"en": "You speak English so clearly today — keep shining!", "zh": "你今天说英语的声音真清脆——继续闪闪发光吧！"},
	],
	"textbook_miss_lin": [
		{"en": "Listen to the piano melody! Would you like to sing a song with us?", "zh": "听这段优美的钢琴旋律！想不想走上舞台和我们一起唱歌？"},
		{"en": "Tap the red drum or shake the golden bell in rhythm!", "zh": "跟着节拍敲响红鼓，或者摇响清脆的金色手铃吧！"},
	],
	"textbook_mr_chen": [
		{"en": "Welcome to the science lab! Look closely at the green leaf on the table!", "zh": "欢迎来到科学实验室！仔细观察实验台上的翠绿叶片吧！"},
		{"en": "Spin the globe or test the red-and-blue magnet with Mingming!", "zh": "来转动地球仪，或者和明明一起试试神奇的红蓝磁铁！"},
	],
	"textbook_mr_wang": [
		{"en": "Team, eyes on the football! Dribble around the cones and kick to the goal!", "zh": "队员们看准足球！带球绕过橙色标志桶，向球门射门！"},
		{"en": "Tie your sports shoes tightly — our friendly match is about to start!", "zh": "把运动鞋鞋带系紧——我们的友谊赛马上开始啦！"},
	],
	"textbook_lingling@school": [
		{"en": "Hi friend! Welcome to school! Let's walk to our classroom together!", "zh": "嗨好朋友！欢迎来到学校，我们结伴走进教室吧！"},
		{"en": "Look at the campus clock — English class starts soon!", "zh": "快看校园钟塔——有趣的英语课马上就要开始啦！"},
	],
	"textbook_lingling@art_room": [
		{"en": "Look at my wooden easel! I am painting blue sky and yellow flowers!", "zh": "快看我的木画架！我正在画蓝天和金黄的花朵呢！"},
		{"en": "Pick up a red crayon or soft brush on the art table!", "zh": "拿起画桌上的红蜡笔或软画笔，一起来涂色创作吧！"},
	],
	"textbook_anne@school": [
		{"en": "Good morning! I really like your neat schoolbag today!", "zh": "早上好呀！我好喜欢你今天背的整洁小书包！"},
		{"en": "Are you going to the music room or the library after class?", "zh": "下课后你打算去音乐室，还是去图书角看绘本呀？"},
	],
	"textbook_anne@music_room": [
		{"en": "Listen! I am playing a sweet song on my violin!", "zh": "快听！我正在小舞台上拉一首甜美的小提琴曲呢！"},
		{"en": "The songbook is on the music stand — come sing along!", "zh": "英文歌本就在乐谱架上——快来一起合唱吧！"},
	],
	"textbook_peter@school": [
		{"en": "Hey buddy! Nice to see you at the school gate! High five!", "zh": "嘿好伙伴！在校门口见到你真高兴，来击个掌！"},
		{"en": "After morning class, let's play football on the playground!", "zh": "上完早课之后，我们一起去大操场上踢足球吧！"},
	],
	"textbook_peter@playground": [
		{"en": "Catch the ball! Can you play basketball or jump rope with us?", "zh": "接住球！你会打篮球，或者和我们一起跳绳吗？"},
		{"en": "Look how fast Dongdong is running on the green grass!", "zh": "快看东东在绿草坪上跑得多快呀！"},
	],
	"textbook_mingming@classroom": [
		{"en": "Excuse me, deskmate! May I borrow your green ruler for a minute?", "zh": "打扰一下同桌！我可以借用一下你的绿尺子吗？"},
		{"en": "My English book and notebook are ready on my desk!", "zh": "我的英语书和练习本都已经整齐摆在课桌上啦！"},
	],
	"textbook_mingming@science_room": [
		{"en": "Whoa, look! This magnet can pick up three iron clips at once!", "zh": "哇快看！这块磁铁能一下子吸起三枚回形针呢！"},
		{"en": "Our bean seed grew taller than last week!", "zh": "我们种下的小豆苗比上周长得更高啦！"},
	],
	"textbook_dongdong@canteen": [
		{"en": "Yum! Everything at the canteen window smells delicious today!", "zh": "好香呀！今天学校食堂窗口的饭菜闻起来太诱人啦！"},
		{"en": "I'd like roast chicken, rice, and warm milk on my tray!", "zh": "我想在餐盘里选一份烤鸡肉、白米饭和温牛奶！"},
	],
	"textbook_dongdong@playground": [
		{"en": "One, two, three — watch me jump across the hopscotch grid!", "zh": "一、二、三——看我一口气跳过彩虹数字格！"},
		{"en": "Let's fly a colourful kite high above the playground!", "zh": "我们一起在操场微风里把彩色风筝放得高高的吧！"},
	],
	"textbook_tim@classroom": [
		{"en": "Hi! Let's check today's timetable beside the blackboard!", "zh": "嗨！我们一起来看看黑板旁今天的课程表吧！"},
		{"en": "Don't forget to put your pencil-box neatly on your desk!", "zh": "别忘了把文具盒整整齐齐摆在课桌角哦！"},
	],
	"textbook_tim@football_field": [
		{"en": "Pass the football to me! Let's score a goal together!", "zh": "把足球传给我！我们配合踢进一球吧！"},
		{"en": "Remember to drink some water by the team bench!", "zh": "跑累了记得去替补席旁边喝口水补充体力哦！"},
	],
	"textbook_amy": [
		{"en": "Hello! I love reading English picture books in our book corner!", "zh": "你好呀！我最喜欢在班级图书角读英文图画书啦！"},
		{"en": "Which unit are you learning today? Let's practise together!", "zh": "你今天正在学哪一单元？我们一起开口练一练吧！"},
	],
	"npc_bear_uncle": [
		{"en": "Fresh warm bread and golden apple cakes straight from the oven!", "zh": "刚出炉的热面包和金黄苹果蛋糕，满街都是甜香！"},
		{"en": "Good day, little neighbour! Enjoying an after-school walk in the village?", "zh": "你好呀小邻居！放学后出来晨光村街区散步吗？"},
		{"en": "Bring three sweet red apples anytime if you want to bake a cake!", "zh": "想烤苹果蛋糕的话，随时去果园摘三颗红苹果带给我哦！"},
	],
	"npc_rabbit_gardener": [
		{"en": "Look at the sunny orchard — shiny red apples are hanging on the branches!", "zh": "快看阳光果园——枝头挂满了亮晶晶的红苹果！"},
		{"en": "Take a deep breath! Flowers, green grass, and fresh air feel wonderful!", "zh": "深呼吸一下！鲜花、绿草和清新的果园微风真舒服！"},
	],
	"resident_school": [
		{"en": "Welcome to Sunny School! Every classroom door is open for curious minds!", "zh": "欢迎来到阳光学校！每一间教室都向爱探索的你敞开！"},
		{"en": "Check the welcome board or head into the classroom, music room, or lab!", "zh": "看看校门迎新牌，或者随时走进教室、音乐室和科学室体验吧！"},
	],
	"resident_classroom": [
		{"en": "Our classroom desks and books are bright and tidy — come join the lesson!", "zh": "教室里的课桌和书本整洁明亮——快来加入课堂互动吧！"},
	],
	"resident_music_room": [
		{"en": "Do-re-mi! Come try the grand piano, violin, and cheerful hand bells!", "zh": "哆来咪！快来音乐室试试三角钢琴、小提琴和欢快手铃吧！"},
	],
	"resident_art_room": [
		{"en": "Red, yellow, sky blue! Pick your favourite colours at our easel table!", "zh": "红、黄、天蓝！来美术画桌前挑选你最爱的缤纷色彩吧！"},
	],
	"resident_science_room": [
		{"en": "Curious eyes make great scientists! Come inspect leaves, seeds, and magnets!", "zh": "好奇的眼睛造就小小科学家！快来观察叶片、种子与磁铁吧！"},
	],
	"resident_canteen": [
		{"en": "Warm soup, rice, roast chicken, and fresh milk — grab a clean lunch tray!", "zh": "热汤、米饭、烤鸡肉配鲜牛奶——快端起干净的午餐托盘吧！"},
	],
	"resident_playground": [
		{"en": "Stretch your arms and run! Balls and jump ropes are ready on the rack!", "zh": "伸展手臂跑起来吧！器材架上的球类和跳绳都准备好啦！"},
	],
	"resident_football_field": [
		{"en": "Step onto the green pitch! Ready to practise passing and shooting?", "zh": "踏上绿茵球场！准备好练习传球和射门了吗？"},
	],
}

const LANDMARK_THEMES := {
	"resident_a": {"word": "apple", "zh": "红苹果", "spot": "sweet orchard stand"},
	"resident_b": {"word": "book", "zh": "故事书", "spot": "cozy bookshop"},
	"resident_c": {"word": "cake", "zh": "甜蛋糕", "spot": "pastry kitchen"},
	"resident_d": {"word": "duck", "zh": "小黄鸭", "spot": "pond dock"},
	"resident_e": {"word": "egg", "zh": "金鸡蛋", "spot": "sunny farmyard"},
	"resident_f": {"word": "flower", "zh": "鲜花", "spot": "blooming flower house"},
	"resident_g": {"word": "gift", "zh": "礼物盒", "spot": "ribbon workshop"},
	"resident_h": {"word": "hat", "zh": "小草帽", "spot": "hat studio"},
	"resident_i": {"word": "ice cream", "zh": "冰淇淋", "spot": "cool dessert cart"},
	"resident_j": {"word": "juice", "zh": "鲜果汁", "spot": "fruit juice bar"},
	"resident_k": {"word": "kite", "zh": "纸风筝", "spot": "breezy hilltop"},
	"resident_l": {"word": "lamp", "zh": "暖台灯", "spot": "lantern loft"},
	"resident_m": {"word": "milk", "zh": "鲜牛奶", "spot": "meadow dairy"},
	"resident_n": {"word": "nest", "zh": "小鸟巢", "spot": "treetop nook"},
	"resident_o": {"word": "orange", "zh": "甜橙子", "spot": "owl reading hall"},
	"resident_p": {"word": "pen", "zh": "钢笔", "spot": "stationery studio"},
	"resident_q": {"word": "queen", "zh": "王冠故事", "spot": "story crown gallery"},
	"resident_r": {"word": "ruler", "zh": "直尺", "spot": "craft bench"},
	"resident_s": {"word": "star", "zh": "亮星星", "spot": "starlight observatory"},
	"resident_t": {"word": "tea", "zh": "清香茶", "spot": "warm teahouse"},
	"resident_u": {"word": "umbrella", "zh": "彩虹伞", "spot": "weather porch"},
	"resident_v": {"word": "violin", "zh": "小提琴", "spot": "melody pavilion"},
	"resident_w": {"word": "watch", "zh": "小手表", "spot": "clockwork cottage"},
	"resident_x": {"word": "box", "zh": "百宝箱", "spot": "treasure box room"},
	"resident_y": {"word": "yellow", "zh": "向日葵黄", "spot": "sunflower dye house"},
	"resident_z": {"word": "zoo", "zh": "动物明信片", "spot": "zebra post office"},
}

const ACTOR_PERSONAS := {
	"textbook_role_lingling_mother": {
		"title": "妈妈 Mom · 温柔陪伴",
		"open_en": "Sweetie, I'm right here at home with you! Want to learn the things in this room together, or practise a daily family conversation?",
		"open_zh": "宝贝，妈妈在家里陪着你呢！想先走近台面认识屋里的大小物品，还是和妈妈来一段课本生活对话？",
	},
	"textbook_role_lingling_father": {
		"title": "爸爸 Dad · 伴读伙伴",
		"open_en": "Hey champ! Look around our room — every piece of furniture and stationery has a great English name. Let's explore or chat!",
		"open_zh": "嗨宝贝！看看房间四周——从桌椅书架到台面小文具，都能串成生动的英语表达。想先看实物台，还是和爸爸对话？",
	},
	"textbook_doggie": {
		"title": "小狗 · Doggie",
		"open_en": "Woof woof! Look, Doggie loves running in the sunny garden! Let's check the flowers, grass, and umbrella nearby!",
		"open_zh": "汪汪！快看，小狗最喜欢在阳光花园里奔跑啦！快来看看花圃旁的花朵、青草和雨伞单词吧！",
	},
	"textbook_kitty": {
		"title": "小猫 · Kitty",
		"open_en": "Meow! Little Kitty loves cozy rooms and warm sunshine! Come learn the clothes and furniture nearby!",
		"open_zh": "喵～小猫最喜欢温暖整洁的小房间啦！快来看看身边的衣物和家居单词吧！",
	},
	"textbook_miss_li": {
		"title": "李老师 Miss Li · 英语课堂",
		"open_en": "Good morning! In our classroom, every blackboard, desk, and English book comes alive. Ready for a textbook dialogue or desk check?",
		"open_zh": "早上好！在阳光教室里，黑板、讲台、课桌和英语书都能连成地道句子。想和李老师演练课堂对话，还是查看课桌实物？",
	},
	"textbook_miss_lin": {
		"title": "林老师 Miss Lin · 音乐社团",
		"open_en": "Welcome to the Music Room! Listen — piano, violin, drum, and bell! Let's talk about what everyone is playing!",
		"open_zh": "欢迎来到音乐教室！钢琴、小提琴、大鼓与手铃都在等你点响，快来聊聊大家正在演奏什么乐器吧！",
	},
	"textbook_mr_chen": {
		"title": "陈老师 Mr Chen · 科学实验室",
		"open_en": "Hello, young scientist! On our lab table we have seeds, green leaves, magnets, and a globe. Want to observe them up close?",
		"open_zh": "你好呀小小科学家！实验台上有种子、绿叶、磁铁和地球仪，想走近观察台动手摆放，还是来一段科学英语对话？",
	},
	"textbook_mr_wang": {
		"title": "王老师 Mr Wang · 体育教练",
		"open_en": "Great energy today! On our football field we practise teamwork, plans, and sports rules. Ready to warm up?",
		"open_zh": "今天精神头真足！在绿茵球场上我们一边练传球射门，一边用英语聊比赛计划与运动守则！",
	},
	"textbook_lingling": {
		"title": "玲玲 Lingling · 同班好友",
		"open_en": "Hi friend! So happy to see you at school! Want to talk about today's classes, art colours, and lunch plans?",
		"open_zh": "嗨好朋友！在学校见到你太开心啦！想一起聊聊今天的课程安排、美术画具，还是去食堂点午餐？",
	},
	"textbook_peter": {
		"title": "彼得 Peter · 运动伙伴",
		"open_en": "Hey buddy! Look at the basketballs, footballs, and jump ropes! Let's talk about what our friends are doing on the playground!",
		"open_zh": "嘿好搭档！看看这边的篮球、足球和跳绳，我们用英语聊聊同学们正在操场上做什么运动吧！",
	},
	"textbook_anne": {
		"title": "安妮 Anne · 音乐与观察伙伴",
		"open_en": "Hello! Whether playing the violin or comparing our science plants, practising English together is so much fun!",
		"open_zh": "你好呀！不管是拉小提琴，还是对比上周见闻与植物高矮，一起用英语交流都超有趣！",
	},
	"textbook_mingming": {
		"title": "明明 Mingming · 同桌伙伴",
		"open_en": "Hi deskmate! Look at my clean desk — I brought my pencil, ruler, eraser, and English book today!",
		"open_zh": "嗨同桌！看看我整洁的课桌——今天我带齐了铅笔、直尺、橡皮和英语书，一起来认一认、聊一聊吧！",
	},
	"textbook_dongdong": {
		"title": "东东 Dongdong · 活力伙伴",
		"open_en": "Hey! After running fast on the playground, healthy canteen food tastes extra yummy! Let's practise together!",
		"open_zh": "嘿！在操场上痛快奔跑之后，去阳光食堂端起营养餐盘学点餐英语最棒啦！",
	},
	"textbook_tim": {
		"title": "蒂姆 Tim · 球场队友",
		"open_en": "Hello teammate! From our classroom desks to the green football pitch, let's learn cool English expressions!",
		"open_zh": "你好队友！从教室课桌到绿茵足球场，我们一起把课本里的好词好句活学活用吧！",
	},
	"textbook_amy": {
		"title": "艾米 Amy · 图书角伙伴",
		"open_en": "Hi there! I love linking desk words into little stories. Want to inspect our classroom desk or try a dialogue?",
		"open_zh": "嗨！我最喜欢把课桌上的单词串成小故事啦，要打开课桌特写台看看，还是来一段情境对话？",
	},
}

static func is_home_or_school(room_id: String) -> bool:
	return room_id in HOME_ROOMS or room_id in SCHOOL_ROOMS

static func domain_for_room(room_id: String) -> String:
	if room_id in HOME_ROOMS:
		return "home"
	if room_id in SCHOOL_ROOMS:
		return "school"
	return "village"

static func actors_for_room(room_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not ROOM_CAST.has(room_id):
		return result
	var raw: Array = ROOM_CAST[room_id]
	for item: Variant in raw:
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result

static func resolve_entry_speaker(room_id: String, entry: Dictionary) -> String:
	var char_id := str(entry.get("character_id", "")).strip_edges()
	if not char_id.is_empty():
		return char_id
	var res_id := str(entry.get("resident_id", "")).strip_edges()
	if not res_id.is_empty():
		return res_id
	var eid := str(entry.get("id", "")).strip_edges()
	if eid.begins_with("actor:"):
		return eid.trim_prefix("actor:")
	match eid:
		"baker":
			return "npc_bear_uncle"
		"gardener":
			return "npc_rabbit_gardener"
		"teacher":
			return "textbook_miss_li"
		"lunch":
			return "resident_canteen"
		"sports":
			return "textbook_peter"
	return CharacterVoices.npc_for_room(room_id)

static func pick_proximity_greeting(room_id: String, entry: Dictionary, turn_index: int = 0) -> Dictionary:
	var speaker_id := resolve_entry_speaker(room_id, entry)
	var scoped_key := "%s@%s" % [speaker_id, room_id]
	var pool: Array = []
	if PROXIMITY_GREETINGS.has(scoped_key):
		pool = PROXIMITY_GREETINGS[scoped_key]
	elif PROXIMITY_GREETINGS.has(speaker_id):
		pool = PROXIMITY_GREETINGS[speaker_id]
	if not pool.is_empty():
		var chosen: Dictionary = pool[posmod(turn_index, pool.size())]
		return {
			"speaker_id": speaker_id,
			"en": str(chosen.get("en", "")),
			"zh": str(chosen.get("zh", "")),
		}
	if LANDMARK_THEMES.has(speaker_id):
		var lm: Dictionary = LANDMARK_THEMES[speaker_id]
		var res: Dictionary = Residents.profile(speaker_id)
		var name_en := str(res.get("name_en", "Friend"))
		var name_zh := str(res.get("name", "伙伴"))
		var bname := str(res.get("building_name", "主题馆"))
		var letter := speaker_id.trim_prefix("resident_").to_upper()
		var word := str(lm.get("word", "apple"))
		var wzh := str(lm.get("zh", "好物"))
		var spot := str(lm.get("spot", "cozy corner"))
		var variants := [
			{
				"en": "Welcome to our %s! \"%s\" starts with %s!" % [spot, word.capitalize(), letter],
				"zh": "欢迎来到%s！「%s」（%s）是以字母 %s 开头的好词哦！" % [bname, word, wzh, letter],
			},
			{
				"en": "Hi! I'm %s — come spot \"%s\" with me!" % [name_en, word],
				"zh": "嗨！我是%s——快来%s和我一起发现「%s」（%s）吧！" % [name_zh, bname, word, wzh],
			},
		]
		var v: Dictionary = variants[posmod(turn_index, variants.size())]
		return {"speaker_id": speaker_id, "en": str(v.en), "zh": str(v.zh)}
	return {
		"speaker_id": speaker_id,
		"en": "Hello! What a sunny day to learn English together!",
		"zh": "你好呀！今天阳光真好，一起在生活场景里感受英语吧！",
	}

static func resident_opening(room_id: String, resident_id: String, resident: Dictionary) -> Dictionary:
	var name_en := str(resident.get("name_en", "Friend"))
	var name_zh := str(resident.get("name", "伙伴"))
	var role_zh := str(resident.get("role", "主理人"))
	var bname := str(resident.get("building_name", "小屋"))
	if PROXIMITY_GREETINGS.has(resident_id):
		var first: Dictionary = (PROXIMITY_GREETINGS[resident_id] as Array)[0]
		return {
			"en": "Hi, I'm %s! %s" % [name_en, str(first.get("en", ""))],
			"zh": "你好，我是%s（%s）！%s" % [name_zh, role_zh, str(first.get("zh", ""))],
		}
	if LANDMARK_THEMES.has(resident_id):
		var lm: Dictionary = LANDMARK_THEMES[resident_id]
		var letter := resident_id.trim_prefix("resident_").to_upper()
		var word := str(lm.get("word", "star"))
		var wzh := str(lm.get("zh", "星星"))
		var spot := str(lm.get("spot", "studio"))
		return {
			"en": "Hi, I'm %s at the %s! Let's explore letter %s and \"%s\" after school!" % [name_en, spot, letter, word],
			"zh": "你好呀，我是%s的%s%s！课余时间来这里认识字母 %s 与「%s」（%s）最有趣啦！" % [bname, role_zh, name_zh, letter, word, wzh],
		}
	var _unused := room_id
	return {
		"en": "Warm greetings from %s! Take your time looking around %s!" % [name_en, bname],
		"zh": "你好，我是%s，这里的%s。欢迎在%s慢慢探索！" % [name_zh, role_zh, bname],
	}

static func build_actor_conversation(game: Node, actor_id: String, room_id: String, world_pos: Vector3) -> Dictionary:
	var Roleplay = load("res://gameplay/situational_roleplay.gd")
	var persona: Dictionary = ACTOR_PERSONAS.get(actor_id, {
		"title": "小岛伙伴",
		"open_en": "Hello, my friend! Let's explore the words around us and practise speaking together!",
		"open_zh": "你好呀好朋友！我们一起看看身边的物品，用英语自然聊聊天吧！",
	})
	var voice_npc_id := actor_id

	var domain := domain_for_room(room_id)
	var actions: Array = []
	var ErrandDir = load("res://gameplay/ebbinghaus_errand_director.gd")
	var V8Mem = load("res://core/v8_memory_ledger.gd")
	var st_node := game.get_node_or_null("/root/State") if is_instance_valid(game) else null
	var errand_override_en := ""
	var errand_override_zh := ""
	if st_node != null and domain in ["home", "school"]:
		var active_er: Dictionary = V8Mem.ensure(st_node.data).get("active_errand", {})
		if not active_er.is_empty():
			actions.append({
				"label": "◈ 前往完成温故寻物委托",
				"id": "v8_errand_go",
				"primary": true,
			})
		elif actor_id not in ["textbook_kitty", "textbook_doggie"] and ErrandDir.can_offer_errand(st_node, room_id):
			var prop: Dictionary = ErrandDir.build_errand_proposal(st_node, room_id, voice_npc_id, str(persona.get("title", "伙伴")))
			if not prop.is_empty():
				errand_override_en = str(prop.get("prompt_en", ""))
				errand_override_zh = str(prop.get("prompt_zh", ""))
				actions.append({
					"label": "◈ 接下温故寻物（盲找双倍 EXP）",
					"id": "v8_accept_errand:%s:%s" % [room_id, voice_npc_id],
					"primary": true,
				})
	if domain in ["home", "school"]:
		var rec_scen: Dictionary = Roleplay.recommended_v6_scenario(game, room_id, actor_id)
		var rec_id := str(rec_scen.get("id", "home_s1_living_mom"))
		var stage_num := int(rec_scen.get("stage", 1))
		var title_zh := str(rec_scen.get("title_zh", "课本情境对话"))
		actions.append({
			"label": "★ 第%d阶对话 · %s" % [stage_num, title_zh],
			"id": "v6_roleplay_stage:" + rec_id,
			"primary": actions.is_empty(),
		})
		actions.append({
			"label": "◈ 走近实物台 · 大家具与小物品连学摆一摆",
			"id": "v6_bench_open:" + room_id,
		})
		actions.append({
			"label": "◈ 自选 1～4 阶语法与时态对话（3～6年级）",
			"id": "v6_ladder_open:" + domain,
		})
	else:
		actions.append({
			"label": "★ 开启当前章节共创",
			"id": "v4_chap_open_here",
			"primary": true,
		})
		actions.append({
			"label": "◈ 今日手账小委托",
			"id": "v4_commission:" + actor_id,
		})
	actions.append({
		"label": "· 本屋记忆宫殿奇象角落",
		"id": "v5_palace_tour:0",
	})
	actions.append({
		"label": "继续自由逛逛",
		"id": "close",
	})

	var en_text := str(persona.get("open_en", ""))
	var zh_text := str(persona.get("open_zh", ""))
	var scoped_key := "%s@%s" % [actor_id, room_id]
	if PROXIMITY_GREETINGS.has(scoped_key):
		var first_line: Dictionary = (PROXIMITY_GREETINGS[scoped_key] as Array)[0]
		en_text = str(first_line.get("en", en_text))
		if actor_id in ["textbook_kitty", "textbook_doggie"]:
			zh_text = str(first_line.get("zh", zh_text))
	if not errand_override_en.is_empty():
		en_text = errand_override_en
		zh_text = errand_override_zh
	return {
		"npc_id": voice_npc_id,
		"speaker": str(persona.get("title", "伙伴")),
		"en": en_text,
		"zh": zh_text,
		"world_pos": world_pos,
		"show_zh_immediately": true,
		"auto_speak": true,
		"actions": actions,
	}
