extends RefCounted
## V5 Multi-Turn Situational Textbook Roleplay Director (`SituationalRoleplay`).
## Provides 3-turn authentic elementary English communicative roleplays inside
## `DiegeticDialogueOverlay` (with graceful `ui.show_panel` fallback).
## Zero raw OS emojis; warm recasts on playful distractors; stealth communicative logging.

const PalaceLoci = preload("res://gameplay/memory_palace_loci_3d.gd")
const Style = preload("res://ui/island_theme.gd")
const Progression = preload("res://core/progression_ledger.gd")
const V6_DIALOGUES_PATH := "res://data/learning/home_school_dialogues_v6.json"

static var _v6_loaded := false
static var _v6_scenarios: Dictionary = {}

const SCENARIOS := {
	"bakery": {
		"npc_id": "npc_bear_uncle",
		"speaker": "熊叔 · 暖香点心剧场",
		"key_word": "cake",
		"turns": [
			{
				"en": "Good morning! Fresh apple cakes and warm bread are ready. Can I help you?",
				"zh": "早上好！刚出炉的苹果蛋糕和热面包好香呀，请问你想点些什么？",
				"choices": [
					{"en": "I'd like an apple cake, please.", "zh": "请给我一份苹果蛋糕。", "ok": true},
					{"en": "Can I have some warm bread, please?", "zh": "请给我一些热面包好吗？", "ok": true},
					{"en": "It is a rainy umbrella.", "zh": "这是一把下雨的雨伞。", "ok": false, "recast_zh": "熊叔笑着指指橱窗：在点心坊点餐可以说 I'd like an apple cake, please! 再试一次吧。"}
				]
			},
			{
				"en": "Sure! Here is a warm slice for you. Would you like a cup of milk too?",
				"zh": "没问题！这是给你的热腾腾点心。还想再配一杯温牛奶吗？",
				"choices": [
					{"en": "Yes, please! How much is it?", "zh": "好的谢谢！请问一共多少钱？", "ok": true},
					{"en": "No, thank you. How much is the cake?", "zh": "不用啦谢谢，请问蛋糕多少钱？", "ok": true},
					{"en": "Where is my pencil box?", "zh": "我的铅笔盒在哪里？", "ok": false, "recast_zh": "结账前可以先礼貌回应 Yes, please! 再问价格 How much is it? 试试看吧！"}
				]
			},
			{
				"en": "It's five leaf coins. Here you are — enjoy your sunny treat!",
				"zh": "一共五枚叶币。请拿好，祝你享受阳光下的美味时光！",
				"choices": [
					{"en": "Here you are. Thank you very much!", "zh": "给您，非常感谢！", "ok": true},
					{"en": "Thank you! Have a nice day!", "zh": "谢谢您！祝您今天愉快！", "ok": true},
					{"en": "Good night, go to bed!", "zh": "晚安，去睡觉啦！", "ok": false, "recast_zh": "接过点心时微笑着说 Thank you! Have a nice day! 会特别有礼貌哦。"}
				]
			}
		],
		"finale_en": "You ordered politely like a real island neighbour! Enjoy your sweet cake!",
		"finale_zh": "你用超自然的英语完成了点餐、询价与道谢三连对话！"
	},
	"post_office": {
		"npc_id": "resident_z",
		"speaker": "斑马邮差 · 问路与寄信剧场",
		"key_word": "letter",
		"turns": [
			{
				"en": "Hello, traveller! Welcome to Zebra Post Office. How can I help you today?",
				"zh": "你好呀小旅行家！欢迎来到斑马邮局，今天需要寄信还是问路呢？",
				"choices": [
					{"en": "Excuse me, I want to send a postcard.", "zh": "打扰一下，我想寄一张明信片。", "ok": true},
					{"en": "Excuse me, where is the school?", "zh": "打扰一下，请问学校怎么走？", "ok": true},
					{"en": "Eat three bananas, please.", "zh": "请吃三根香蕉。", "ok": false, "recast_zh": "问路或办事时先说 Excuse me! 会让对方倍感温暖，再来选一句吧。"}
				]
			},
			{
				"en": "Go straight along the sunny path and turn right at the flower garden!",
				"zh": "沿着阳光小路直走，在花圃路口向右转就能看到啦！需要贴一张星星邮票吗？",
				"choices": [
					{"en": "Go straight and turn right — got it! One stamp, please.", "zh": "直走再右转，记住啦！请给我一张邮票。", "ok": true},
					{"en": "Thank you! That's very clear.", "zh": "谢谢你！路线讲得真清楚。", "ok": true},
					{"en": "Put on your winter coat.", "zh": "穿上你的冬大衣。", "ok": false, "recast_zh": "复述一下路线 Go straight and turn right 或者道谢会更贴切哦！"}
				]
			},
			{
				"en": "Your postcard is stamped and ready to fly! Safe travels around the island!",
				"zh": "明信片已经盖好邮戳准备出发啦！祝你在小岛一路顺风！",
				"choices": [
					{"en": "Thank you so much! Goodbye!", "zh": "太感谢啦！再见！", "ok": true},
					{"en": "See you next time!", "zh": "下次再见啦！", "ok": true},
					{"en": "Open the kitchen fridge.", "zh": "打开厨房冰箱。", "ok": false, "recast_zh": "挥挥手说声 See you next time! 为这段邮局对话画上句号吧。"}
				]
			}
		],
		"finale_en": "Fantastic! Your postcard is on its way and you mastered directions!",
		"finale_zh": "太棒啦！你顺利完成了礼貌问路、确认路线与寄出明信片对话！"
	},
	"weather_station": {
		"npc_id": "resident_u",
		"speaker": "晴雨伞匠 · 天气与穿搭剧场",
		"key_word": "umbrella",
		"turns": [
			{
				"en": "Look up at the sky! What's the weather like on our island today?",
				"zh": "抬头看看天空！今天我们小岛上的天气怎么样呀？",
				"choices": [
					{"en": "It's sunny and warm today!", "zh": "今天阳光明媚又暖和！", "ok": true},
					{"en": "It's a little windy and cloudy.", "zh": "今天有一点微风和多云。", "ok": true},
					{"en": "My ruler is under the desk.", "zh": "我的尺子在课桌下面。", "ok": false, "recast_zh": "描述天气可以用 It's sunny and warm today! 来试试吧。"}
				]
			},
			{
				"en": "Sometimes afternoon rain showers visit! What should we bring when it rains?",
				"zh": "海岛午后有时会飘来阵雨哦！下雨出门我们该带上什么呢？",
				"choices": [
					{"en": "Let's take a colourful umbrella!", "zh": "我们带上一把彩色雨伞吧！", "ok": true},
					{"en": "I can wear my raincoat and boots.", "zh": "我可以穿上雨衣和雨靴。", "ok": true},
					{"en": "Sing a song on the piano.", "zh": "在钢琴边唱首歌。", "ok": false, "recast_zh": "雨天出门当然要带雨伞或雨衣啦：Let's take a colourful umbrella!"}
				]
			},
			{
				"en": "Smart choice! You're ready for both sunshine and raindrops!",
				"zh": "真聪明！不管是晴天还是小雨，你都做好准备啦！",
				"choices": [
					{"en": "Hooray! Let's go exploring outside!", "zh": "太好啦！我们出门探索吧！", "ok": true},
					{"en": "Thank you! I love sunny days and rainy days!", "zh": "谢谢！晴天雨天我都喜欢！", "ok": true},
					{"en": "Wash three plates in the sink.", "zh": "在水槽里洗三个盘子。", "ok": false, "recast_zh": "开心地约伙伴一起出发吧：Hooray! Let's go exploring outside!"}
				]
			}
		],
		"finale_en": "Wonderful weather reporter! Rain or shine, have fun on the island!",
		"finale_zh": "小小气象员表现真棒！天气问答与出行穿搭表达一气呵成！"
	},
	"canteen": {
		"npc_id": "resident_canteen",
		"speaker": "食堂主厨 · 营养午餐剧场",
		"key_word": "milk",
		"turns": [
			{
				"en": "Welcome to the school canteen! Are you hungry after class?",
				"zh": "欢迎来到校园阳光餐厅！下课后肚子饿了吗？",
				"choices": [
					{"en": "Yes, I'm hungry! What's for lunch today?", "zh": "是的我饿啦！今天午餐有什么呀？", "ok": true},
					{"en": "A little hungry! Everything smells delicious.", "zh": "有一点饿！饭菜闻起来真香。", "ok": true},
					{"en": "Close the bedroom window.", "zh": "关上卧室的窗户。", "ok": false, "recast_zh": "在餐厅可以先问问今天吃什么：Yes, I'm hungry! What's for lunch today?"}
				]
			},
			{
				"en": "We have rice, fish, fresh vegetables, and warm milk! What would you like?",
				"zh": "今天有米饭、鱼肉、新鲜蔬菜和温牛奶！你想来点什么？",
				"choices": [
					{"en": "I'd like some rice, vegetables, and milk, please.", "zh": "请给我一些米饭、蔬菜和牛奶。", "ok": true},
					{"en": "Some fish and fresh vegetables for me, please!", "zh": "请给我来点鱼肉和新鲜蔬菜！", "ok": true},
					{"en": "Kick the football to the goal.", "zh": "把足球踢进球门。", "ok": false, "recast_zh": "用 I'd like some ..., please. 点一份营养均衡的午餐吧！"}
				]
			},
			{
				"en": "Healthy choice! Here is your lunch tray — don't waste food!",
				"zh": "搭配得真健康！请端好你的午餐托盘，记得光盘不浪费哦！",
				"choices": [
					{"en": "Thank you! I will finish all my food!", "zh": "谢谢！我会把饭菜吃得干干净净！", "ok": true},
					{"en": "Yummy! Thank you, Chef!", "zh": "真美味！谢谢主厨！", "ok": true},
					{"en": "Fly a kite on the roof.", "zh": "在屋顶放风筝。", "ok": false, "recast_zh": "端起餐盘说一声 Thank you! I will finish all my food! 吧！"}
				]
			}
		],
		"finale_en": "Great appetite and lovely manners! Enjoy your healthy lunch!",
		"finale_zh": "既懂礼貌又会搭配健康午餐，校园餐厅英语对话圆满完成！"
	},
	"classroom": {
		"npc_id": "textbook_miss_li",
		"speaker": "李老师 · 新朋友与爱好剧场",
		"key_word": "teacher",
		"turns": [
			{
				"en": "Good morning! Welcome to our sunny story circle. What's your favourite subject?",
				"zh": "早上好！欢迎来到阳光故事圈，在学校里你最喜欢哪一门课呀？",
				"choices": [
					{"en": "Good morning, Miss Li! I like English and Art!", "zh": "李老师早上好！我喜欢英语和美术！", "ok": true},
					{"en": "I love Music and Science very much!", "zh": "我非常喜欢音乐课和科学课！", "ok": true},
					{"en": "Two socks on the balcony.", "zh": "阳台上有两只袜子。", "ok": false, "recast_zh": "和李老师聊聊喜欢的课程吧：I like English and Art!"}
				]
			},
			{
				"en": "That's wonderful! What do you like doing with your friends after class?",
				"zh": "太棒啦！那下课以后你喜欢和好朋友一起做什么呢？",
				"choices": [
					{"en": "I like reading picture books and drawing!", "zh": "我喜欢读图画书和画画！", "ok": true},
					{"en": "We like singing songs and playing games!", "zh": "我们喜欢一起唱歌和做游戏！", "ok": true},
					{"en": "Soup is in the spoon.", "zh": "汤在勺子里。", "ok": false, "recast_zh": "用 I like reading picture books... 分享你的课余爱好吧！"}
				]
			},
			{
				"en": "Reading and playing together make every school day bright! Keep shining!",
				"zh": "爱阅读、爱分享会让校园每一天都闪闪发光！继续加油哦！",
				"choices": [
					{"en": "Thank you, Miss Li! Let's read together!", "zh": "谢谢李老师！我们一起读书吧！", "ok": true},
					{"en": "I'm happy to learn with my friends!", "zh": "能和朋友们一起学习我真开心！", "ok": true},
					{"en": "Turn off the bathroom tap.", "zh": "关掉浴室水龙头。", "ok": false, "recast_zh": "微笑回应李老师 Thank you, Miss Li! Let's read together! 吧。"}
				]
			}
		],
		"finale_en": "Bravo! You shared your favourite subjects and hobbies with confidence!",
		"finale_zh": "大方又自信地用英语介绍了喜欢的科目与课余爱好！"
	},
	"playground": {
		"npc_id": "textbook_peter",
		"speaker": "彼得 · 操场运动邀约剧场",
		"key_word": "football",
		"turns": [
			{
				"en": "Hey friend! What a sunny break! Would you like to play sports with us?",
				"zh": "嗨伙伴！课间阳光真好，想不想和我们一起运动呀？",
				"choices": [
					{"en": "Yes, I'd love to! What can we play?", "zh": "好呀我很想参加！我们玩什么呢？", "ok": true},
					{"en": "Great idea! Let's run and play together!", "zh": "好主意！我们一起奔跑运动吧！", "ok": true},
					{"en": "Put the pillow on the bed.", "zh": "把枕头放到床上。", "ok": false, "recast_zh": "答应伙伴的运动邀请可以说 Yes, I'd love to! 试试看！"}
				]
			},
			{
				"en": "We have a football and a skipping rope! Can you kick the ball to me?",
				"zh": "我们有足球也有跳绳！你能把足球传给我吗？",
				"choices": [
					{"en": "Yes, I can! Catch the ball, Peter!", "zh": "我可以！彼得，接住球！", "ok": true},
					{"en": "Sure! Let's pass the football and jump high!", "zh": "当然可以！我们一起传球跳跃吧！", "ok": true},
					{"en": "Drink hot soup with a fork.", "zh": "用叉子喝热汤。", "ok": false, "recast_zh": "传球前喊一声 Yes, I can! Catch the ball! 超有活力哦！"}
				]
			},
			{
				"en": "Nice pass! Teamwork makes every game twice as fun!",
				"zh": "好球！互相配合让运动变得双倍快乐！",
				"choices": [
					{"en": "High five! Let's play another round!", "zh": "击掌！我们再来一局吧！", "ok": true},
					{"en": "Good game! You are a great teammate!", "zh": "配合得真好！你是个超棒的队友！", "ok": true},
					{"en": "Sweep the kitchen floor.", "zh": "打扫厨房地板。", "ok": false, "recast_zh": "和队友击掌庆祝吧：High five! Let's play another round!"}
				]
			}
		],
		"finale_en": "Awesome teamwork! You made a sunny playground memory!",
		"finale_zh": "活力满满！你用流畅的运动英语和伙伴完成了操场配合！"
	},
	"home": {
		"npc_id": "textbook_role_lingling_mother",
		"speaker": "妈妈 Mom · 温馨家园待客剧场",
		"key_word": "home",
		"turns": [
			{
				"en": "Knock, knock! Hello, little host! May I come in and visit your cozy home?",
				"zh": "咚咚咚！你好呀小主人！我可以进来参观你温馨的家吗？",
				"choices": [
					{"en": "Welcome to my home! Come in, please!", "zh": "欢迎来到我家！快请进！", "ok": true},
					{"en": "Hello! Come in and have a seat on the sofa!", "zh": "你好！快进来坐在沙发上吧！", "ok": true},
					{"en": "Wait at the train station.", "zh": "在火车站等候。", "ok": false, "recast_zh": "招待客人进门最经典的一句就是：Welcome to my home! Come in, please!"}
				]
			},
			{
				"en": "Your living room is so tidy and bright! May I have a glass of water?",
				"zh": "你的客厅布置得又整洁又敞亮！可以请我喝一杯水吗？",
				"choices": [
					{"en": "Of course! Would you like some sweet apples too?", "zh": "当然可以！还要尝尝香甜的苹果吗？", "ok": true},
					{"en": "Here is warm tea and fresh fruit for you!", "zh": "给您端来热茶和新鲜水果！", "ok": true},
					{"en": "Erase the classroom blackboard.", "zh": "擦干净教室黑板。", "ok": false, "recast_zh": "热情端上茶水水果吧：Here is warm tea and fresh fruit for you!"}
				]
			},
			{
				"en": "How kind of you! Thank you for sharing such a warm afternoon with me!",
				"zh": "你真是热情又贴心的小主人！谢谢你陪我度过这么温暖的午后！",
				"choices": [
					{"en": "You're welcome! Come visit again anytime!", "zh": "不客气！欢迎随时再来我家做客！", "ok": true},
					{"en": "I'm glad you like my home! See you soon!", "zh": "很高兴你喜欢我家！回头见！", "ok": true},
					{"en": "Count twenty zebras.", "zh": "数二十只斑马。", "ok": false, "recast_zh": "客人道谢时记得微笑说 You're welcome! Come visit again anytime!"}
				]
			}
		],
		"finale_en": "What a warm and polite host! Your home feels full of sunshine!",
		"finale_zh": "热情周到的小主人！待客迎宾三步英语表达自然又地道！"
	},
	"library": {
		"npc_id": "resident_o",
		"speaker": "猫头鹰馆长 · 图书借阅剧场",
		"key_word": "book",
		"turns": [
			{
				"en": "Shh, welcome to Owl Reading Nook! Looking for an interesting storybook?",
				"zh": "嘘，欢迎来到猫头鹰静谧书屋！今天想找一本有趣的故事书吗？",
				"choices": [
					{"en": "Yes, quiet please! May I borrow a picture book?", "zh": "是的轻声细语！我可以借一本图画书吗？", "ok": true},
					{"en": "Hello! Do you have stories about animals and stars?", "zh": "你好！请问有关于动物和星星的故事书吗？", "ok": true},
					{"en": "Shout loudly in the hall.", "zh": "在走廊大声喊叫。", "ok": false, "recast_zh": "在阅览室轻声询问借书：May I borrow a picture book?"}
				]
			},
			{
				"en": "Here is a popup book about starry whales! Remember to keep books clean.",
				"zh": "这本星光蓝鲸立体书正适合你！记得爱护书页保持整洁哦。",
				"choices": [
					{"en": "I promise! When should I return the book?", "zh": "我保证爱护它！请问什么时候归还呢？", "ok": true},
					{"en": "Thank you! I will read quietly and take care of it.", "zh": "谢谢！我会安静阅读并好好爱惜。", "ok": true},
					{"en": "Throw the ball at the shelf.", "zh": "朝书架扔球。", "ok": false, "recast_zh": "借书时可以礼貌询问归还时间：When should I return the book?"}
				]
			},
			{
				"en": "Bring it back next Friday. Happy reading, little bookworm!",
				"zh": "下周五带回来就可以啦。祝你阅读愉快，爱读书的小朋友！",
				"choices": [
					{"en": "Got it! Thank you very much, Owl Librarian!", "zh": "记下啦！非常感谢猫头鹰馆长！", "ok": true},
					{"en": "See you next Friday! Goodbye!", "zh": "下周五见！再见啦！", "ok": true},
					{"en": "Cook noodles in the pan.", "zh": "在锅里煮面条。", "ok": false, "recast_zh": "轻声道谢告别吧：Thank you very much! See you next Friday!"}
				]
			}
		],
		"finale_en": "Wonderful library manners! Enjoy your magical storybook!",
		"finale_zh": "安静有礼的小读者！图书借阅与归还约定对话顺利达成！"
	}
}

static func scenario_id_for_context(room_id: String, npc_hint: String = "") -> String:
	if room_id in ["landmark_C"] or npc_hint in ["baker", "resident_c"]:
		return "bakery"
	if room_id == "landmark_Z" or npc_hint == "resident_z":
		return "post_office"
	if room_id == "landmark_U" or npc_hint == "resident_u":
		return "weather_station"
	if room_id == "canteen" or npc_hint == "lunch":
		return "canteen"
	if room_id in ["classroom", "school", "music_room", "art_room", "science_room"] or npc_hint == "teacher":
		return "classroom"
	if room_id in ["playground", "football_field"] or npc_hint == "sports":
		return "playground"
	if room_id == "landmark_O" or npc_hint == "resident_o":
		return "library"
	if room_id.begins_with("home"):
		return "home"
	if room_id.begins_with("landmark_"):
		return "dynamic_" + room_id
	return "bakery"

static func _build_dynamic_landmark_scenario(room_id: String, game: Node3D) -> Dictionary:
	var letter := room_id.trim_prefix("landmark_")
	var state_node := game.get_node_or_null("/root/State") if is_instance_valid(game) else null
	var ranked := PalaceLoci.stories_for_room(room_id)
	var target_word := letter
	var target_zh := "奇妙好物"
	var room_zh := letter + " 字母主题馆"
	var locus_zh := "展台角落"
	if not ranked.is_empty():
		var first_it: Dictionary = ranked[0] as Dictionary
		target_word = str(first_it.get("word", target_word))
		target_zh = str(first_it.get("meaning_zh", target_zh))
		room_zh = str(first_it.get("palace_room_zh", room_zh))
		locus_zh = str(first_it.get("palace_locus_zh", locus_zh))
	var _unused := state_node
	return {
		"npc_id": "resident_" + letter.to_lower(),
		"speaker": "%s · 情境小剧场" % room_zh,
		"key_word": target_word.to_lower(),
		"turns": [
			{
				"en": "Welcome to %s! Look over there — can you spot \"%s\"?" % [room_zh, target_word],
				"zh": "欢迎来到%s！往%s看一看，你发现「%s」（%s）了吗？" % [room_zh, locus_zh, target_word, target_zh],
				"choices": [
					{"en": "Hello! Yes, I see \"%s\" right here!" % target_word, "zh": "你好！我就在这里看到它啦！", "ok": true},
					{"en": "How nice! Tell me more about \"%s\", please!" % target_word, "zh": "真好看！请多给我讲讲它吧！", "ok": true},
					{"en": "Good night, close the door.", "zh": "晚安，把门关上。", "ok": false, "recast_zh": "和馆主招呼并回应眼前的发现吧：Yes, I see \"%s\" right here!" % target_word}
				]
			},
			{
				"en": "\"%s\" begins with crisp letters! Would you like to say it together?" % target_word,
				"zh": "「%s」（%s）的读音特别清脆！想不想和我一起开口读一读？" % [target_word, target_zh],
				"choices": [
					{"en": "Sure! Let's read \"%s\" aloud together!" % target_word, "zh": "好呀！我们一起大声读出来！", "ok": true},
					{"en": "I like this word! \"%s\" is easy to remember!" % target_word, "zh": "我喜欢这个词，很容易记住！", "ok": true},
					{"en": "Where are my winter gloves?", "zh": "我的冬手套在哪儿？", "ok": false, "recast_zh": "自信地跟伙伴一起开口吧：Sure! Let's read \"%s\" aloud together!" % target_word}
				]
			},
			{
				"en": "Wonderful voice! Keep \"%s\" in this corner of your Memory Palace!" % target_word,
				"zh": "声音真好听！把「%s」稳稳收藏进这座房间的「%s」角落吧！" % [target_word, locus_zh],
				"choices": [
					{"en": "Thank you! I will remember this corner!", "zh": "谢谢你！我会记住这个角落的！", "ok": true},
					{"en": "See you soon! Let's explore more!", "zh": "回头见！我们继续探索吧！", "ok": true},
					{"en": "Wash the soup bowl now.", "zh": "现在去洗汤碗。", "ok": false, "recast_zh": "礼貌道谢收尾吧：Thank you! I will remember this corner!"}
				]
			}
		],
		"finale_en": "Great conversation! \"%s\" is shining brightly in %s!" % [target_word, room_zh],
		"finale_zh": "对话真流畅！「%s」（%s）已经在%s点亮啦！" % [target_word, target_zh, room_zh]
	}

static func _ensure_v6_loaded() -> void:
	if _v6_loaded:
		return
	_v6_loaded = true
	_v6_scenarios.clear()
	if not FileAccess.file_exists(V6_DIALOGUES_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(V6_DIALOGUES_PATH))
	if not (parsed is Dictionary) or not ((parsed as Dictionary).get("scenarios") is Dictionary):
		return
	var raw_map: Dictionary = (parsed as Dictionary).get("scenarios") as Dictionary
	for sid: String in raw_map:
		if not (raw_map[sid] is Dictionary):
			continue
		var raw: Dictionary = raw_map[sid] as Dictionary
		var norm_turns: Array = []
		var raw_turns: Array = raw.get("turns", [])
		for t_idx: int in range(raw_turns.size()):
			if not (raw_turns[t_idx] is Dictionary):
				continue
			var rt: Dictionary = raw_turns[t_idx] as Dictionary
			var raw_opts: Array = rt.get("options", [])
			var choices: Array = []
			var n_opts := raw_opts.size()
			var shift := posmod(absi(sid.hash()) + t_idx, maxi(1, n_opts))
			for k: int in range(n_opts):
				var opt_v: Variant = raw_opts[(k + shift) % n_opts]
				if opt_v is Dictionary:
					var opt: Dictionary = opt_v as Dictionary
					choices.append({
						"en": str(opt.get("en", "")),
						"zh": str(opt.get("zh", "")),
						"ok": bool(opt.get("correct", false)),
						"recast_zh": str(opt.get("scaffold_zh", "再看看句型与时态提示，换一句试试吧！")),
					})
			norm_turns.append({
				"en": str(rt.get("npc_en", "")),
				"zh": str(rt.get("npc_zh", "")),
				"choices": choices,
			})
		var stage_num := int(raw.get("stage", 1))
		_v6_scenarios[sid] = {
			"id": sid,
			"is_v6": true,
			"domain": str(raw.get("domain", "home")),
			"stage": stage_num,
			"grade_label": str(raw.get("grade_label", "三年级基础")),
			"grammar_tag": str(raw.get("grammar_tag", "")),
			"grammar_tip": str(raw.get("grammar_tip", "")),
			"book_ref": str(raw.get("book_ref", "")),
			"room_ids": raw.get("room_ids", []),
			"npc_id": str(raw.get("npc_id", "textbook_role_lingling_mother")),
			"speaker": str(raw.get("speaker", "家人与同学")),
			"title_zh": str(raw.get("title_zh", "课本情境对话")),
			"key_word": str(raw.get("key_word", "hello")),
			"turns": norm_turns,
			"finale_en": "Awesome job! You just used Stage %d English naturally in real life!" % stage_num,
			"finale_zh": "太棒啦！你在真实场景对话里自然运用了【%s · %s】！" % [
				str(raw.get("grade_label", "")),
				str(raw.get("grammar_tag", "")),
			],
		}

static func all_v6_scenarios() -> Dictionary:
	_ensure_v6_loaded()
	return _v6_scenarios

static func v6_scenarios_for_domain(domain: String) -> Array[Dictionary]:
	_ensure_v6_loaded()
	var list: Array[Dictionary] = []
	for sid: String in _v6_scenarios:
		var sc: Dictionary = _v6_scenarios[sid]
		if domain.is_empty() or str(sc.get("domain", "")) == domain:
			list.append(sc)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := int(a.get("stage", 1))
		var sb := int(b.get("stage", 1))
		if sa != sb:
			return sa < sb
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	return list

static func completed_v6_ids(state_node: Node) -> Array[String]:
	var out: Array[String] = []
	if state_node == null or not (state_node.get("data") is Dictionary):
		return out
	var v4: Dictionary = state_node.data.get("v4", {}) if state_node.data.get("v4") is Dictionary else {}
	var comms: Variant = v4.get("completed_commissions", [])
	if comms is Array:
		for entry: Variant in (comms as Array):
			var cs := str(entry).strip_edges()
			if cs.begins_with("v6_dlg:"):
				var sid := cs.trim_prefix("v6_dlg:").strip_edges()
				if not sid.is_empty() and not out.has(sid):
					out.append(sid)
	var raw: Variant = v4.get("v6_dialogues_done", [])
	if raw is Array:
		for x: Variant in (raw as Array):
			var s := str(x).strip_edges()
			if not s.is_empty() and not out.has(s):
				out.append(s)
	return out

static func recommended_v6_scenario(game: Node, room_id: String, actor_id: String = "") -> Dictionary:
	_ensure_v6_loaded()
	var domain := "home" if room_id.begins_with("home") else "school"
	var candidates := v6_scenarios_for_domain(domain)
	if candidates.is_empty():
		return SCENARIOS["home"] as Dictionary
	var state_node := game.get_node_or_null("/root/State") if is_instance_valid(game) else null
	var done := completed_v6_ids(state_node)

	# 1. Uncompleted scenario matching BOTH room_id and actor_id (lowest stage first)
	if not actor_id.is_empty():
		for sc: Dictionary in candidates:
			if not done.has(str(sc.get("id", ""))) and str(sc.get("npc_id", "")) == actor_id and (sc.get("room_ids", []) as Array).has(room_id):
				return sc
	# 2. Uncompleted scenario matching room_id (lowest stage first -> progressive Stage 1 -> 4!)
	for sc: Dictionary in candidates:
		if not done.has(str(sc.get("id", ""))) and (sc.get("room_ids", []) as Array).has(room_id):
			return sc
	# 3. Uncompleted scenario anywhere in this domain (Home or School)
	for sc: Dictionary in candidates:
		if not done.has(str(sc.get("id", ""))):
			return sc
	# 4. All stages completed! Pick best room match for free replay
	for sc: Dictionary in candidates:
		if (sc.get("room_ids", []) as Array).has(room_id):
			return sc
	return candidates[0]

static func open_stage_ladder(game: Node3D, domain_hint: String = "") -> void:
	if not is_instance_valid(game):
		return
	_ensure_v6_loaded()
	if is_instance_valid(game.ui.diegetic) and game.ui.diegetic.visible:
		game.ui.diegetic.dismiss()
	if not game._prepare_screen():
		return

	var domain := domain_hint.strip_edges().to_lower()
	if domain not in ["home", "school"]:
		domain = "home" if str(game.room).begins_with("home") else "school"

	var state_node := game.get_node_or_null("/root/State")
	var done := completed_v6_ids(state_node)
	var list := v6_scenarios_for_domain(domain)
	var ui: CanvasLayer = game.ui

	var cur_lv: int = state_node.level() if (state_node != null and state_node.has_method("level")) else 1
	var cur_coins: int = int(state_node.data.get("coins", 0)) if state_node != null else 0
	ui._begin("v6_grammar_ladder", "map")
	var domain_title := "在家与爸爸妈妈对话" if domain == "home" else "在学校与老师同学对话"
	ui._heading(
		"课本语法与时态 · 四阶情境对话（%s）" % domain_title,
		"当前 Lv.%d · %d 叶币  ｜  全阶自由开放不锁关，达到推荐等级完成可点亮「晋级挑战徽章（+20 EXP / +8 叶币）」" % [cur_lv, cur_coins]
	)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 10)
	ui.panel_box.add_child(tab_row)
	var home_tab: Button = ui.button("★ 我的家 · 父母生活对话", "v6_ladder_open:home", domain == "home", Vector2(230, 44))
	var school_tab: Button = ui.button("★ 阳光学校 · 师生同学对话", "v6_ladder_open:school", domain == "school", Vector2(240, 44))
	tab_row.add_child(home_tab)
	tab_row.add_child(school_tab)
	var done_count := 0
	for sc: Dictionary in list:
		if done.has(str(sc.get("id", ""))):
			done_count += 1
	var prog_lbl: Label = ui.label("本区已点亮：%d / %d 幕" % [done_count, list.size()], 16, Style.SAGE)
	prog_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tab_row.add_child(prog_lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.panel_box.add_child(scroll)

	var cards_col := VBoxContainer.new()
	cards_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_col.add_theme_constant_override("separation", 10)
	scroll.add_child(cards_col)

	for sc: Dictionary in list:
		var sid := str(sc.get("id", ""))
		var is_done := done.has(sid)
		var card := PanelContainer.new()
		var bg := Color("f2f8ee") if is_done else Color("fbf7ec")
		var border := Color("b6d4a8") if is_done else Color("dfd0b4")
		var csb := Style.keycap(bg, border, 2, 14, 14, 10)
		csb.shadow_size = 0
		card.add_theme_stylebox_override("panel", csb)
		cards_col.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var info_col := VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.add_theme_constant_override("separation", 4)
		row.add_child(info_col)

		var stage_n := int(sc.get("stage", 1))
		var rec_lv := Progression.stage_recommended_level(stage_n)
		var stage_cfg: Dictionary = Progression.STAGE_CLEAR_REWARDS.get(stage_n, {"exp": 25, "coins": 8})
		var has_badge := Progression.has_stage_badge(state_node.data, sid) if state_node != null else false
		var badge := ""
		if has_badge:
			badge = "★ 晋级徽章已得"
		elif cur_lv >= rec_lv:
			badge = "◈ 可夺晋级徽章" if not is_done else "✓ 已体验 · 重温夺章"
		else:
			badge = ("✓ 已体验 · Lv.%d夺章" % rec_lv) if is_done else ("○ 自由开放 · 推荐Lv.%d+" % rec_lv)

		var top_line := "【第 %d 阶 · %s】%s  （%s · %s）" % [
			stage_n,
			str(sc.get("grade_label", "")),
			str(sc.get("title_zh", "")),
			str(sc.get("speaker", "")),
			badge,
		]
		var t_lbl: Label = ui.label(top_line, 18, Style.INK)
		t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_col.add_child(t_lbl)

		var g_lbl: Label = ui.label("语法焦点：%s  ｜  教材：%s  ｜  首通 +%d EXP / +%d 叶币" % [
			str(sc.get("grammar_tag", "")),
			str(sc.get("book_ref", "")),
			int(stage_cfg["exp"]),
			int(stage_cfg["coins"]),
		], 14, Style.SAGE)
		g_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_col.add_child(g_lbl)

		var tip_lbl: Label = ui.label(str(sc.get("grammar_tip", "")), 14, Style.MUTED)
		tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_col.add_child(tip_lbl)

		var start_btn: Button = ui.button("▶ 开始对话" if not is_done else "· 重温对话", "v6_roleplay_stage:" + sid, not is_done, Vector2(138, 46))
		start_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(start_btn)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	ui.panel_box.add_child(foot)
	var bench_btn: Button = ui.button("★ 打开本房间实物词丛台", "v6_bench_open:" + str(game.room), false, Vector2(230, 44))
	foot.add_child(bench_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	foot.add_child(ui.button("返回房间", "close", false, Vector2(140, 44)))

	ui._layout.call_deferred()

static func get_scenario(scenario_id: String, game: Node3D) -> Dictionary:
	_ensure_v6_loaded()
	if _v6_scenarios.has(scenario_id):
		return _v6_scenarios[scenario_id] as Dictionary
	if SCENARIOS.has(scenario_id):
		return SCENARIOS[scenario_id] as Dictionary
	if scenario_id.begins_with("dynamic_"):
		return _build_dynamic_landmark_scenario(scenario_id.trim_prefix("dynamic_"), game)
	if is_instance_valid(game):
		var r := str(game.room)
		if r.begins_with("home") or r in ["school", "classroom", "music_room", "art_room", "science_room", "canteen", "playground", "football_field"]:
			return recommended_v6_scenario(game, r)
	return SCENARIOS["bakery"] as Dictionary

static func open_turn(game: Node3D, scenario_id: String, turn_idx: int = 0, recast_note: String = "") -> void:
	if not is_instance_valid(game):
		return
	var scen := get_scenario(scenario_id, game)
	var turns: Array = scen.get("turns", [])
	if turns.is_empty():
		return
	if turn_idx >= turns.size():
		_finish_roleplay(game, scenario_id, scen)
		return

	var is_v6 := bool(scen.get("is_v6", false))
	var turn_data: Dictionary = turns[clampi(turn_idx, 0, turns.size() - 1)]
	var step_tag := "情境对话第 %d / %d 轮" % [turn_idx + 1, turns.size()]
	if is_v6:
		step_tag = "第%d阶·%s (%d/%d)｜%s" % [
			int(scen.get("stage", 1)),
			str(scen.get("grade_label", "")),
			turn_idx + 1,
			turns.size(),
			str(scen.get("grammar_tag", "")),
		]
	var zh_text := "【%s】\n%s" % [step_tag, str(turn_data.get("zh", ""))]
	if is_v6 and turn_idx == 0 and recast_note.is_empty():
		var gtip := str(scen.get("grammar_tip", "")).strip_edges()
		if not gtip.is_empty():
			zh_text += "\n· 语法小锦囊：" + gtip
	if not recast_note.is_empty():
		zh_text = "◈ 语法与语境引导：%s\n\n%s" % [recast_note, zh_text]

	var actions: Array = []
	var choices: Array = turn_data.get("choices", [])
	for c_idx in range(choices.size()):
		var ch: Dictionary = choices[c_idx]
		actions.append({
			"label": "%s（%s）" % [str(ch.get("en", "")), str(ch.get("zh", ""))],
			"id": "v5_roleplay_pick:%s:%d:%d" % [scenario_id, turn_idx, c_idx],
			"primary": (not is_v6) and (c_idx == 0),
		})
	if is_v6:
		actions.append({"label": "◈ 切换 1～4 阶语法话题", "id": "v6_ladder_open:" + str(scen.get("domain", "home"))})
	actions.append({"label": "先聊到这里", "id": "close"})

	var speaker := str(scen.get("speaker", "小岛伙伴 · 情境剧场"))
	var npc_id := str(scen.get("npc_id", "textbook_role_lingling_mother"))
	var en_text := str(turn_data.get("en", ""))

	if is_instance_valid(game.audio_director):
		game.audio_director.play_foley("bubble_pop")

	if is_instance_valid(game.ui.diegetic) and not game.validation_mode:
		if game.ui.modal.visible:
			game._close()
		game.ui.current_panel = "v5_roleplay"
		game.ui.diegetic.open_conversation({
			"npc_id": npc_id,
			"speaker": speaker,
			"en": en_text,
			"zh": zh_text,
			"world_pos": game.conversation_position,
			"show_zh_immediately": is_v6 or (not recast_note.is_empty()),
			"auto_speak": recast_note.is_empty(),
			"actions": actions
		})
	else:
		game.ui.show_panel("v5_roleplay", speaker, step_tag, en_text + "\n" + zh_text, actions)

static func handle_pick(game: Node3D, payload: String) -> void:
	var parts := payload.split(":", true, 2)
	if parts.size() < 3 or not is_instance_valid(game):
		return
	var scenario_id := parts[0]
	var turn_idx := int(parts[1])
	var choice_idx := int(parts[2])
	var scen := get_scenario(scenario_id, game)
	var turns: Array = scen.get("turns", [])
	if turn_idx < 0 or turn_idx >= turns.size():
		return
	var choices: Array = (turns[turn_idx] as Dictionary).get("choices", [])
	if choice_idx < 0 or choice_idx >= choices.size():
		return
	var chosen: Dictionary = choices[choice_idx]
	var spoken_en := str(chosen.get("en", ""))

	if bool(chosen.get("ok", false)):
		open_turn(game, scenario_id, turn_idx + 1, "")
	else:
		if not spoken_en.is_empty() and is_instance_valid(game.ai_bridge):
			game.ai_bridge.speak_text(spoken_en, "en", "player")
		var recast := str(chosen.get("recast_zh", "想想刚才伙伴问的是什么，换一句更贴切的英文回应试试吧！"))
		open_turn(game, scenario_id, turn_idx, recast)

static func _finish_roleplay(game: Node3D, scenario_id: String, scen: Dictionary) -> void:
	var state_node := game.get_node_or_null("/root/State")
	var key_word := str(scen.get("key_word", "hello")).to_lower()
	var exp_gained := 0
	var coins_gained := 0
	var badge_earned := false
	if state_node != null:
		state_node.record_stealth_evidence({
			"word": key_word,
			"support_level": 0,
			"correct": true,
			"context": "situational_roleplay:" + scenario_id
		})
		var is_v6 := bool(scen.get("is_v6", false))
		var stage_n := int(scen.get("stage", 1)) if is_v6 else 1
		if is_v6:
			state_node.complete_v4_commission("v6_dlg:" + scenario_id, 0)
		if state_node.has_method("grant_exp"):
			var r_res: Dictionary = state_node.grant_exp({
				"key": "dlg:" + scenario_id,
				"scenario_id": scenario_id,
				"mode": "dialogue_clear",
				"stage": stage_n,
			})
			exp_gained = int(r_res.get("exp_gained", 0))
			coins_gained = int(r_res.get("total_coins_gained", 0))
			badge_earned = bool(r_res.get("badge_earned", false))

	if is_instance_valid(game.audio_director):
		game.audio_director.play_foley("wardrobe_sparkle")
	game.player.gesture("wave")
	if (exp_gained > 0 or coins_gained > 0) and is_instance_valid(game.feedback):
		var pop_txt := "+%d EXP" % exp_gained
		if coins_gained > 0:
			pop_txt += " · +%d 叶币" % coins_gained
		game.feedback.pickup(game.player.position, game.player.position, "leaf", pop_txt)

	var speaker := str(scen.get("speaker", "小岛伙伴"))
	var npc_id := str(scen.get("npc_id", "npc_bear_uncle"))
	var fin_en := str(scen.get("finale_en", "Wonderful conversation! See you soon!"))
	var fin_zh := str(scen.get("finale_zh", "三轮情境英语对话顺利完成！"))
	if badge_earned:
		fin_zh += "\n★ 恭喜点亮本幕「晋级挑战徽章」！本次共收获 +%d EXP、+%d 叶币！" % [exp_gained, coins_gained]
	elif exp_gained > 0 or coins_gained > 0:
		fin_zh += "\n★ 本次对话收获 +%d EXP%s！" % [exp_gained, ("、+%d 叶币" % coins_gained) if coins_gained > 0 else ""]

	var actions: Array = []
	if bool(scen.get("is_v6", false)):
		var next_rec := recommended_v6_scenario(game, str(game.room), "")
		var next_id := str(next_rec.get("id", scenario_id))
		if next_id != scenario_id:
			actions.append({
				"label": "★ 下一阶对话 · 第%d阶《%s》" % [int(next_rec.get("stage", 1)), str(next_rec.get("title_zh", ""))],
				"id": "v6_roleplay_stage:" + next_id,
				"primary": true,
			})
		actions.append({"label": "◈ 查看 1～4 阶全部语法对话", "id": "v6_ladder_open:" + str(scen.get("domain", "home")), "primary": actions.is_empty()})
		actions.append({"label": "★ 打开本房间实物词丛台", "id": "v6_bench_open:" + str(game.room)})
		actions.append({"label": "开心告别", "id": "close"})
	else:
		actions = [
			{"label": "◈ 再演一遍这段对话", "id": "v5_roleplay_start:" + scenario_id, "primary": true},
			{"label": "★ 巡游本屋记忆宫殿角落", "id": "v5_palace_tour:0"},
			{"label": "开心告别", "id": "close"}
		]
	if is_instance_valid(game.ui.diegetic) and not game.validation_mode:
		game.ui.current_panel = "v5_roleplay_done"
		game.ui.diegetic.open_conversation({
			"npc_id": npc_id,
			"speaker": speaker + " · 对话达成",
			"en": fin_en,
			"zh": fin_zh,
			"world_pos": game.conversation_position,
			"show_zh_immediately": true,
			"auto_speak": true,
			"actions": actions
		})
	else:
		game.ui.show_panel("v5_roleplay_done", speaker, "三轮情境对话完成", fin_en + "\n" + fin_zh, actions)
