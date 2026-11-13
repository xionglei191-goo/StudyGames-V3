"""Build `game/data/learning/world_object_semantics_v5.json` covering ALL 210
fixed 3D scene object anchors across the 42 interior/courtyard scenes of Alphabet Island
(8 Home scenes x 5 = 40, 26 Alphabet Landmarks x 5 = 130, 8 School scenes x 5 = 40).

Every anchor teaches:
  1. `object_en` / `object_zh` — exact physical object noun(s) the child is looking at
  2. `phrase_en` / `phrase_zh` — natural first/second-person situational sentence at that object
  3. `palace_word` / `palace_entry_id` — direct link into the 3D PopupBookTheater Memory Palace!
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "game/data/learning/catalog.json"
HOME_PATH = ROOT / "game/data/home_hierarchy.json"
LANDMARK_PATH = ROOT / "game/data/landmark_interiors.json"
OUT_PATH = ROOT / "game/data/learning/world_object_semantics_v5.json"

# Tuple schema per anchor:
# (object_en, object_zh, phrase_en, phrase_zh, palace_candidates)
ANCHOR_SPECS: dict[str, dict[int, tuple[str, str, str, str, list[str]]]] = {
    # ===================== 8 HOME SCENES (40 ANCHORS) =====================
    "home_estate": {
        1: ("mailbox / card", "信箱 · 迎宾卡", "Open the mailbox and read the welcome card: Welcome to my home!", "打开门前信箱读读迎宾卡：欢迎来到我家！", ["welcome", "home", "card"]),
        2: ("flower / watering can", "花朵 · 浇水壶", "Lift the watering can and water the colourful flowers.", "提起浇水壶，给小院五彩的花朵浇浇水吧。", ["flower", "plant", "water"]),
        3: ("basket / hat", "随身篮 · 遮阳帽", "Put your sun hat and water bottle in the porch basket.", "出门散步前，把遮阳帽和水壶放进门廊随身篮吧。", ["hat", "bag", "basket"]),
        4: ("board / clock", "日程板 · 时钟", "Check our family board! Breakfast is at seven thirty.", "看一看家庭日程板！我们的早餐在七点半开始。", ["breakfast", "clock", "time", "family"]),
        5: ("young tree / leaf", "小树苗 · 绿叶", "Water the young tree every day so it grows tall and green.", "每天给门廊边的小树苗浇水，让它长得又高又绿。", ["tree", "young trees", "plant"]),
    },
    "home": {
        1: ("basket / bag", "门厅藤篮 · 书包", "Put your bag and cap in the hall basket, please.", "进门后，请把你的书包和帽子放进门厅随身篮里吧。", ["bag", "cap", "hat"]),
        2: ("wardrobe / coat", "衣柜 · 外套", "Open the wooden wardrobe and hang up your warm coat.", "打开左侧木衣柜，把暖和的外套整齐挂好。", ["coat", "clothes", "dress"]),
        3: ("tea table / cup", "茶几 · 茶杯", "Set two clean cups of warm tea on the living room table.", "在客厅中央茶几上摆好两只干净的暖茶杯吧。", ["tea", "cup", "table", "living room"]),
        4: ("photo album / family", "相册 · 家人合照", "Open the photo album by the window to see my happy family.", "翻开窗边的家庭相册，看看我们幸福的一家人。", ["photo", "family", "mother", "father"]),
        5: ("shelf / gift", "展示架 · 纪念礼物", "Place our holiday gifts and cards neatly on the memory shelf.", "把节日礼物与纪念贺卡整齐摆回出口展示架上。", ["gift", "present", "festival", "card"]),
    },
    "home_bedroom": {
        1: ("bed / quilt", "小床 · 柔软被子", "Fold the soft quilt neatly and make your bed every morning.", "每天早上把松软的被子叠整齐，铺好自己的小床。", ["bed", "make the bed", "quilt"]),
        2: ("alarm clock / morning", "小闹钟 · 早晨", "Look at the little clock by the bed! I get up at seven o'clock.", "看看床头滴答响的小闹钟！我早上七点钟起床。", ["clock", "get up", "morning"]),
        3: ("mirror / dress", "穿衣镜 · 衣裳", "Stand before the mirror and choose a clean shirt or dress today.", "站在穿衣镜前照一照，挑一件今天想穿的漂亮衣服吧。", ["dress", "shirt", "coat", "clothes"]),
        4: ("schoolbag / pencil box", "书包 · 文具盒", "Pack your pencil box and ruler into your schoolbag.", "把文具盒和尺子收好，装进收纳凳上的书包里。", ["schoolbag", "pencil-box", "pencil", "ruler"]),
        5: ("lamp / bedtime book", "床头灯 · 睡前书", "Turn off the warm bedside lamp when it is time to go to bed.", "读完睡前故事，准备睡觉时记得关掉温暖的床头阅读灯哦。", ["go to bed", "light", "bed", "sleep"]),
    },
    "home_kitchen": {
        1: ("cupboard / rice", "储物柜 · 米和食材", "Open the kitchen cupboard to find rice, noodles, and fresh food.", "打开厨房食材储物柜，找找米饭、面条和新鲜食材。", ["rice", "noodles", "food", "vegetable"]),
        2: ("sink / vegetables", "洗菜池 · 新鲜蔬菜", "Wash the green vegetables in the clean kitchen sink.", "把翠绿的蔬菜放进干净的洗菜池里冲一冲、洗干净。", ["vegetable", "vegetables", "tomato", "potato", "wash"]),
        3: ("stove / soup pot", "灶台 · 热汤锅", "Warm soup is bubbling in the pot on the stove!", "灶台上的汤锅正咕嘟咕嘟冒着香喷喷的热气呢！", ["soup", "cook", "kitchen", "fish"]),
        4: ("counter / cutting board", "备餐台 · 料理板", "Arrange the washed tomatoes and eggs on the kitchen counter.", "把洗净的西红柿和鸡蛋整齐摆在明亮的备餐操作台上。", ["kitchen", "tomato", "egg"]),
        5: ("dish rack / bowl", "碗碟架 · 碗和勺子", "Put the clean bowls and spoons back on the dish rack.", "把洗干净的小碗和勺子放回餐具收纳架上沥干。", ["bowl", "clean", "spoon", "plate"]),
    },
    "home_dining": {
        1: ("sideboard / milk", "早餐柜 · 牛奶面包", "Pour a glass of warm milk from the breakfast sideboard.", "从早餐边柜端起一杯温牛奶，开启元气满满的早晨。", ["breakfast", "milk", "bread"]),
        2: ("fruit bowl / apple", "果盘 · 香甜水果", "Pick a sweet red apple or a yellow banana from the fruit tray!", "从阳光水果分享盘里挑一颗红苹果或黄香蕉吧！", ["apple", "fruit", "banana", "orange"]),
        3: ("dining table / chopsticks", "家庭餐桌 · 餐具", "Set the plates and chopsticks on the table — dinner is ready!", "在家庭餐桌上摆好餐盘和筷子——香喷喷的晚餐准备好啦！", ["dinner", "lunch", "table"]),
        4: ("cake table / candle", "点心桌 · 生日蛋糕", "Light the candles on the birthday cake and make a sweet wish!", "点亮生日点心桌上蛋糕的小蜡烛，许一个温暖的心愿吧！", ["birthday", "cake", "gift"]),
        5: ("cabinet / family dinner", "餐边架 · 团圆餐盘", "Take out the big round plates for our warm family dinner.", "从节日餐边架取出大圆盘，准备一家人团聚的丰盛晚餐。", ["family", "dinner", "festival"]),
    },
    "home_bathroom": {
        1: ("toothbrush / mirror", "牙刷杯 · 洗漱镜", "Take your toothbrush from the cup and brush your teeth clean!", "拿起牙刷杯里的小牙刷，对着镜子把牙齿刷得白白净净！", ["tooth", "teeth", "brush", "clean"]),
        2: ("washbasin / soap", "洗手池 · 香皂", "Wash your hands with bubbles in the clean washbasin.", "在清爽的洗手池前搓出泡泡，把小手洗得干干净净。", ["hand", "wash", "clean", "water"]),
        3: ("bathtub / shower", "浴缸 · 淋浴花洒", "A warm shower in the bathroom keeps our body fresh and clean.", "在浴缸与花洒旁冲个温水澡，让身体每天都清爽干净。", ["clean", "body", "water"]),
        4: ("towel / rack", "软毛巾 · 毛巾架", "Wipe your face dry and hang the soft towel back on the rack.", "洗完脸擦干水珠，再把柔软的毛巾挂回收纳架原位。", ["face", "clean", "wash"]),
        5: ("tap / water", "水龙头 · 节约用水", "Turn off the water tap tightly after washing — let's save water!", "洗完手记得把水龙头拧紧关好——一起养成节约用水的好习惯！", ["water", "save", "clean"]),
    },
    "home_study": {
        1: ("computer / desk", "电脑 · 写字书桌", "Use the computer on the study desk to send a friendly email.", "在窗边电脑书桌上给好朋友发一封温暖的问候邮件吧。", ["computer", "email", "desk"]),
        2: ("bookshelf / storybook", "书架 · 故事绘本", "Pick an interesting storybook from the wooden bookshelf.", "从整洁的绘本书架上挑一本你最感兴趣的故事书吧。", ["book", "story", "read"]),
        3: ("reading chair / cushion", "阅读椅 · 靠窗软垫", "Sit by the sunny window and read a wonderful book quietly.", "坐在阳光洒满的靠窗阅读座上，安安静静读一会儿好书。", ["read", "book", "window"]),
        4: ("pencil case / ruler", "铅笔盒 · 尺子橡皮", "Put your pencils, eraser, and ruler neatly into the pencil case.", "把铅笔、橡皮和尺子整整齐齐收进文具整理桌的铅笔盒里。", ["pencil-box", "pencil", "ruler", "eraser", "pen"]),
        5: ("card / crayons", "手工贺卡 · 彩笔", "Draw a bright rainbow with crayons to make a thank-you card!", "拿起手工台上的彩笔画一道彩虹，做一张漂亮的感谢贺卡吧！", ["card", "draw", "crayon", "picture"]),
    },
    "home_balcony": {
        1: ("laundry basket / socks", "洗衣篮 · 干净短袜", "Hang the clean socks on the sunny rack above the laundry basket.", "把洗衣篮里洗干净的小袜子夹在阳光晾衣架上晒干吧。", ["sock", "socks", "clothes", "coat"]),
        2: ("flowerpot / green plant", "花盆 · 阳台绿植", "Give fresh water to the green plants on the sunny stand.", "给阳台盆栽照料台上的绿叶小植物浇一点清凉的水吧。", ["plant", "flower", "water"]),
        3: ("window / cloth", "玻璃窗 · 擦窗布", "Wipe the balcony window with a soft cloth until the glass shines!", "用干净的软布擦一擦阳台大窗户，让玻璃亮晶晶！", ["window", "clean"]),
        4: ("broom / floor", "小扫帚 · 簸箕", "Hold the broom and sweep the balcony floor nice and tidy.", "拿起角落的小扫帚和簸箕，把阳台地面扫得整整齐齐。", ["floor", "sweep", "clean"]),
        5: ("bucket / water tap", "储水桶 · 节水角", "Close the tap and store the clean bucket neatly in the corner.", "关好阳台水龙头，把干净的小水桶收进节水储物角里。", ["water", "clean"]),
    },

    # ===================== 26 ALPHABET LANDMARKS (130 ANCHORS) =====================
    "landmark_A": {
        1: ("basket / orchard", "采果藤篮 · 果园入口", "Pick up a woven basket at the gate before picking apples.", "在果园门口领一只轻巧藤篮，准备去树下采苹果吧。", ["apple", "bag"]),
        2: ("apple tree / red apple", "苹果树 · 红苹果", "Look up at the green apple tree — sweet red apples hang on the branches!", "抬头看看繁茂的苹果树——红彤彤的甜苹果正挂满枝头呢！", ["apple", "tree"]),
        3: ("sorting table / count", "分果木台 · 数苹果", "Count the apples on the wooden table: one, two, three, four, five!", "在中央分拣台上数一数红苹果：一、二、三、四、五！", ["apple", "five", "three"]),
        4: ("wash basin / clear water", "洗果水池 · 清泉", "Wash the fresh apples in cool clear water before tasting them.", "把刚摘下的红苹果放进清凉的洗果池里洗得亮晶晶。", ["wash", "water", "apple"]),
        5: ("gift shelf / apple basket", "礼物木架 · 果篮", "Share a basket of crisp sweet apples with our island neighbours!", "从出口礼物架端起一篮脆甜苹果，送给小岛邻居分享吧！", ["apple", "gift"]),
    },
    "landmark_B": {
        1: ("harbour sign / map", "码头路牌 · 航向标", "Read the wooden dock sign to check where our boat will sail.", "看看岸边木路牌上的箭头，确认小船今天要驶向哪座海湾。", ["boat", "ship", "sea"]),
        2: ("wooden bench / cushion", "木长凳 · 软坐垫", "Sit on the harbour bench and watch little boats rock on the waves.", "坐在码头边的木长凳上，看小木船在波浪上轻轻摇晃。", ["boat", "chair", "sit"]),
        3: ("mooring post / rope", "系船木柱 · 缆绳", "Tie the boat rope safely around the sturdy wooden post.", "把小木船的缆绳稳稳系在中央结实的系船木柱上。", ["boat", "ship"]),
        4: ("cargo shelf / wooden box", "码头货架 · 物资木箱", "Stack the wooden boxes neatly on the harbour shelf.", "把出航物资木箱按大小整整齐齐码放在右侧货架上。", ["box", "boat"]),
        5: ("cabin door / life ring", "船舱门 · 救生圈", "Check the life ring by the cabin door before we set sail!", "推开船舱门出发前，先检查门边的橙色救生圈是否挂好！", ["boat", "door", "sea"]),
    },
    "landmark_C": {
        1: ("order board / menu", "烘焙订单板 · 甜点单", "Read today's bakery order board — someone wants an apple cake!", "看看门口的烘焙订单板——有位客人点了一份香甜苹果蛋糕！", ["cake", "bread"]),
        2: ("flour / egg / milk", "原料木架 · 鸡蛋牛奶", "Take fresh eggs, milk, and flour from the ingredient shelf.", "从左侧材料架取出新鲜鸡蛋、牛奶和面粉。", ["egg", "milk", "cake"]),
        3: ("mixing bowl / cream", "料理台 · 奶油搅拌碗", "Mix the batter and pipe sweet white cream onto the cake!", "在中央料理台搅匀面糊，再给蛋糕挤上一圈香甜白奶油！", ["cake", "sweet"]),
        4: ("warm oven / timer", "烘焙烤箱 · 计时器", "Mmm, smell the warm cake baking inside the golden oven!", "闻一闻！右侧烤箱里正飘出烤蛋糕暖融融的甜香呢！", ["cake", "bread", "hot"]),
        5: ("pickup window / cake box", "取餐木窗 · 蛋糕礼盒", "Hand the warm cake box through the window with a big smile!", "在出口取餐窗微笑着递出系好丝带的蛋糕盒吧！", ["cake", "thank"]),
    },
    "landmark_D": {
        1: ("program board / song", "节目木牌 · 合奏曲目", "Check the concert board to choose our happy rhythm song!", "看看音乐厅门口的节目牌，挑一首今天要合奏的欢快曲目吧！", ["music", "sing", "play"]),
        2: ("drumsticks / rack", "乐器架 · 木鼓槌", "Pick up a pair of smooth wooden drumsticks from the rack.", "从左侧乐器架上拿起一对光滑轻巧的小木鼓槌。", ["play", "music"]),
        3: ("big drum / beat", "中央大圆鼓 · 鼓点", "Tap the big round drum: boom, boom, clap to the beat!", "敲响舞台中央的大圆鼓：咚、咚、哒，跟着节拍一起合奏！", ["play", "music", "dance"]),
        4: ("rehearsal seats / turn", "排练木席 · 轮流合奏", "Sit on the rehearsal bench and listen — now it is your turn!", "坐在右侧排练席上认真倾听伙伴的鼓声——现在轮到你演奏啦！", ["listen", "turn", "play"]),
        5: ("photo wall / concert", "演出纪念墙 · 合影", "Pin our joyful band photo onto the concert memory wall!", "把我们神采飞扬的合奏照片贴在出口纪念墙上吧！", ["photo", "picture", "music"]),
    },
    "landmark_E": {
        1: ("care chart / schedule", "照料记录板 · 孵蛋表", "Check the care chart to keep every little egg warm and safe.", "查看门口的照料记录板，了解守护每一枚小蛋壳的温暖步骤。", ["egg", "warm"]),
        2: ("soft cushion / straw mat", "绒毛软垫 · 干草窝", "Fluff up the soft warm cushion so the eggs never roll away.", "把左侧的绒毛软垫铺得松软暖和，不让小蛋壳滚落。", ["egg", "warm", "bed"]),
        3: ("incubator / little chick", "暖光孵化台 · 小雏鸡", "Listen closely! A yellow chick is tapping inside the white egg!", "凑近中央孵化台仔细听！一只黄绒毛小鸡正在白蛋壳里轻轻啄壳呢！", ["egg", "bird", "small"]),
        4: ("water dish / grain bowl", "食水小架 · 清水谷粒", "Fill the tiny bowl with clean water and grain for the hungry chick.", "给右侧食水架添满干净的清水与小米粒，招待刚破壳的小鸡。", ["water", "hungry", "eat"]),
        5: ("window / growth diary", "观察木窗 · 成长画页", "Draw how the little egg hatched into a fluffy chick in our diary!", "站在出口观察窗前，把蛋壳孵出毛茸茸小鸡的变化画进日记本吧！", ["draw", "egg", "small"]),
    },
    "landmark_F": {
        1: ("seed box / packet", "种子木盒 · 花种袋", "Choose a packet of flower seeds from the wooden seed box.", "从温室门口的木盒里挑一袋饱满的花朵种子吧。", ["flower", "plant"]),
        2: ("flowerpot / soil", "花盆工作台 · 松软泥土", "Plant the tiny seed gently in a terracotta flowerpot with soft soil.", "在左侧花盆台捧起松软泥土，把小花种轻轻种进红陶花盆里。", ["flower", "plant"]),
        3: ("flower bed / petals", "五彩花床 · 鲜艳花瓣", "Look at the central flower bed — red, yellow, and pink flowers bloom!", "看中央花床里百花盛开——红的、黄的、粉的花瓣真灿烂呀！", ["flower", "red", "yellow", "pink"]),
        4: ("water basin / watering can", "温室水池 · 喷壶", "Fill your watering can at the basin and give thirsty flowers a drink.", "在右侧水池灌满小喷壶，给口渴的花朵们洒下清甜水珠。", ["water", "flower"]),
        5: ("bouquet stand / ribbon", "花束展示架 · 丝带花束", "Tie a bright ribbon around the fresh flower bouquet for a friend!", "在出口花束架系上漂亮丝带，把芬芳的小花束送给好朋友！", ["flower", "friend", "gift"]),
    },
    "landmark_G": {
        1: ("travel pass / ticket", "旅行卡架 · 探索通行证", "Take a travel pass at the stand and start your world journey!", "在入口旅行卡架领一张探索卡，开启奇妙的环球小旅程！", ["travel", "world", "go"]),
        2: ("postcard / beach", "明信片墙 · 世界各地风景", "Look at the postcards — sunny beaches, snowy mountains, and green forests!", "欣赏左侧明信片湾上的风景——有阳光海滩、雪山和绿森林！", ["beach", "mountain", "forest", "place"]),
        3: ("spinning globe / ocean", "大地球仪 · 海洋与陆地", "Spin the big blue globe and find oceans, islands, and countries!", "轻轻转动中央蔚蓝的大地球仪，找找广阔的海洋与不同国家吧！", ["world", "earth", "country", "China"]),
        4: ("packing table / suitcase", "打包木桌 · 旅行小箱", "Pack your map, notebook, and hat neatly into the travel bag.", "在右侧打包桌上把地图、笔记本和帽子整齐收进行李包里。", ["bag", "map", "hat"]),
        5: ("route wall / compass", "航线地图墙 · 指南针", "Trace our next island adventure route on the big wall map!", "顺着出口路线墙上的地图与指南针，规划我们的下一站旅行吧！", ["map", "place", "left", "right"]),
    },
    "landmark_H": {
        1: ("style board / hat", "帽型图牌 · 试戴指南", "Look at the hat board — do you need a sun hat or a warm wool cap?", "看看店门口的试戴图牌——今天想选遮阳草帽还是暖绒帽呢？", ["hat", "cap"]),
        2: ("fabric shelf / cloth", "布料木架 · 彩色布卷", "Touch the soft red felt and blue cotton rolls on the fabric shelf.", "摸一摸左侧布料架上的红毛毡和蓝棉布，颜色多鲜艳呀。", ["red", "blue", "clothes"]),
        3: ("fitting mirror / size", "全身试戴镜 · 比大小", "Try on the wide hat in front of the mirror — does it fit just right?", "站在中央试戴镜前戴上宽檐帽照一照——大小刚刚好吗？", ["hat", "big", "small", "try"]),
        4: ("trimming table / ribbon", "修整工作桌 · 帽带花饰", "Decorate the brim of your hat with a silk ribbon and a little flower.", "在右侧修整桌上为帽子系上一条丝带，再别一朵精致小花。", ["hat", "flower", "beautiful"]),
        5: ("hat stand / display", "成品帽架 · 各式礼帽", "Hang your finished hat proudly on the wooden display stand!", "把亲手装饰好的漂亮帽子挂上出口帽架展示吧！", ["hat", "cap", "nice"]),
    },
    "landmark_I": {
        1: ("flavour board / menu", "甜筒点单牌 · 口味图", "Read the picture menu — strawberry, milk, or sweet mango ice cream?", "看看入口点单图牌——今天想尝草莓、牛奶还是甜芒果冰淇淋？", ["ice cream", "sweet", "milk"]),
        2: ("freezer / scoop", "冰霜口味柜 · 冰淇淋球", "Look inside the cold glass freezer full of colourful ice cream tubs!", "透过左侧冰凉的玻璃口味柜，看看五颜六色的冰淇淋球！", ["ice cream", "cold"]),
        3: ("cone stand / crispy cone", "中央甜筒台 · 脆皮蛋筒", "Put two cool scoops of ice cream onto a crispy waffle cone!", "在中央冰淇淋台往脆皮蛋筒上稳稳叠起两颗清凉冰淇淋球！", ["ice cream", "cold", "sweet"]),
        4: ("topping bar / berries", "缤纷配料槽 · 果干糖珠", "Sprinkle sweet berries and crunchy nuts on top of your ice cream.", "在右侧配料槽给冰淇淋撒上酸甜莓果粒和香脆坚果碎吧。", ["sweet", "fruit", "ice cream"]),
        5: ("serving counter / napkin", "取餐小吧台 · 礼貌道谢", "Take your cold ice cream cone at the counter and say: Thank you!", "在出口取餐台双手接过冰凉甜筒，礼貌地说一声谢谢吧！", ["ice cream", "thank"]),
    },
    "landmark_J": {
        1: ("tray / new treasure", "寄存木盘 · 新拾贝壳", "Place your newly found seashell gently onto the wooden tray.", "把刚从海边捡来的漂亮小贝壳轻轻放在入口寄存盘上。", ["box", "small"]),
        2: ("sorting shelf / glass jar", "材质分类格 · 透明玻璃罐", "Sort shells, smooth stones, and buttons into clear glass jars.", "在左侧分类格把贝壳、鹅卵石和彩扣分别装进透明玻璃罐里。", ["glass", "bottle", "box"]),
        3: ("turntable / magnifier", "中央分拣转台 · 放大镜", "Turn the wooden tray to compare big jars and tiny jars!", "轻轻转动中央分拣转台，比一比哪只玻璃罐大、哪只小！", ["big", "small", "look"]),
        4: ("label desk / name tag", "清洁贴签台 · 姓名标签", "Wipe the glass jar clean and stick a neat name tag on the lid.", "在右侧贴签台把玻璃罐擦得透亮，再贴上整洁的收藏标签。", ["clean", "name", "write"]),
        5: ("display cabinet / collection", "晶亮展柜 · 珍藏玻璃罐", "Look at the sparkling glass jars shining inside the display case!", "欣赏出口收藏展柜里一排排闪闪发亮的玻璃宝藏罐吧！", ["look", "beautiful", "star"]),
    },
    "landmark_K": {
        1: ("kite blueprint / shape", "风筝图纸架 · 燕子造型", "Choose a kite drawing on the board — a bird kite or a star kite!", "看看入口制作图，挑一款喜欢的燕子风筝或星星风筝造型吧！", ["kite", "bird", "star"]),
        2: ("paper / long string", "材料木格 · 彩纸与线轴", "Take light colourful paper and a roll of strong kite string.", "从左侧材料格取出轻盈的彩纸和一卷结实的风筝细线。", ["paper", "kite"]),
        3: ("bamboo frame / glue", "风筝骨架桌 · 竹条拼搭", "Cross two light bamboo sticks and paste bright paper on the kite.", "在中央骨架桌上交叉绑好轻竹条，糊上鲜艳的风筝面。", ["kite", "make", "draw"]),
        4: ("wind tunnel / ribbon tail", "风带测试口 · 测风飘带", "Watch the colourful ribbons flutter — the breeze is strong enough!", "观察右侧测试口飞舞的彩带——微风正好，足够托起风筝啦！", ["wind", "windy", "fly"]),
        5: ("kite gallery / sky kite", "风筝长廊 · 彩绘成品", "Hang your finished kite in the gallery before flying it high!", "把做好的彩绘风筝挂上出口长廊展示，再去草地迎风放飞吧！", ["kite", "fly", "high"]),
    },
    "landmark_L": {
        1: ("clock board / evening", "时刻木牌 · 傍晚相约", "Check the lantern station clock — friends will visit this evening!", "看看入口拜访时刻牌——好朋友们约好今天傍晚来相聚！", ["evening", "time", "clock"]),
        2: ("paper lantern / handle", "修整木架 · 灯纸与竹提手", "Mend the warm paper shade and fix the bamboo lantern handle.", "在左侧修整架粘好柔和的灯纸，装稳竹子小提手。", ["light", "warm"]),
        3: ("tea round table / lantern", "暖光会客圆桌 · 桌心灯笼", "Sit around the warm lantern table and greet our evening guests!", "围坐在点着暖灯笼的中央圆桌旁，热情招呼来访的朋友！", ["welcome", "sit", "friend"]),
        4: ("invitation desk / brush pen", "邀请卡木桌 · 手绘灯笼卡", "Write a warm invitation card to invite neighbours to our lantern night.", "在右侧邀请卡桌上画一盏小灯笼，写下温暖的聚会邀请卡。", ["card", "write", "evening"]),
        5: ("lit corridor / warm glow", "亮灯长廊 · 一串暖灯笼", "Walk down the glowing corridor lit by rows of golden lanterns!", "沿着挂满金色暖灯笼的出口长廊散步，灯光照亮回家的路！", ["light", "night", "warm"]),
    },
    "landmark_M": {
        1: ("slipper basket / mat", "拖鞋藤篮 · 迎客门垫", "Change into cosy slippers by the basket when visiting a friend's room.", "到蘑菇邻居屋做客时，在门口拖鞋篮旁换上柔软舒适的拖鞋吧。", ["shoe", "shoes", "room"]),
        2: ("neighbour wall / photo", "邻居相册墙 · 好朋友笑脸", "Meet all our friendly forest neighbours on the photo wall!", "看看左侧相册墙上的笑脸，认识住在树林里的每一位好邻居！", ["friend", "photo", "happy"]),
        3: ("mushroom tea table / snack", "蘑菇圆茶桌 · 森林茶点", "Please sit down at the round mushroom table and share sweet snacks!", "请在中央圆圆的蘑菇茶桌旁坐下，一起品尝香甜小点心吧！", ["table", "sit", "cake"]),
        4: ("window sofa / sunny view", "靠窗软沙发 · 林间窗景", "Relax on the soft sofa by the window and chat with your friend.", "坐在右侧松软的沙发窗台边，看着林间美景和好朋友聊聊天。", ["window", "room", "friend"]),
        5: ("sharing cabinet / toy", "邻里分享柜 · 互借好物", "Borrow a storybook or puzzle from the neighbour sharing shelf!", "从出口分享柜挑一本图画书或拼图借回家，读完记得送回来哦！", ["book", "toy", "share"]),
    },
    "landmark_N": {
        1: ("quiet sign / bird rule", "护鸟枝牌 · 安静观察守则", "Shh! Keep your voice soft so we do not scare the little birds.", "嘘！看看入口枝条守则牌，放轻脚步，别惊扰枝头的小鸟哦。", ["bird", "quiet"]),
        2: ("binoculars / treetop", "观鸟望远镜 · 树冠枝头", "Look through the binoculars — two blue birds are singing in the tree!", "透过左侧望远镜往树冠看——两只蓝羽毛小鸟正在枝头唱歌呢！", ["bird", "see", "tree"]),
        3: ("logbook desk / bird nest", "观察记录台 · 草编鸟巢", "Count how many cosy grass nests rest safely among the branches.", "在中央记录台写下观察笔记，数数树枝间藏着几个温暖的小鸟巢。", ["bird", "count", "three"]),
        4: ("feeder tray / fresh water", "护鸟食水架 · 清水与浆果", "Leave clean water and berries on the tray for flying birds.", "在右侧食水托架添上干净清水与小浆果，招待飞累的小鸟。", ["water", "bird", "fly"]),
        5: ("nature board / feather sketch", "观察日记栏 · 飞鸟速写", "Pin your bird and nest drawing onto the nature diary board!", "把你画的小鸟与鸟巢观察图贴到出口日记栏上展示吧！", ["bird", "draw", "picture"]),
    },
    "landmark_O": {
        1: ("library desk / reading card", "借阅木台 · 猫头鹰图书卡", "Show your owl reading card at the front desk to borrow a book.", "在图书馆入口借阅台出示你的小读者卡，借阅喜欢的绘本吧。", ["book", "library", "read"]),
        2: ("tall bookshelf / topic", "主题高书架 · 科学童话书", "Search the tall wooden shelves for animal stories and science books!", "在左侧高高的主题书架间找一找有趣的动物故事和科学书！", ["book", "story", "science"]),
        3: ("round table / question card", "提问圆木桌 · 故事讨论", "Gather at the round table and ask: Who is the hero in this story?", "围坐在中央提问圆桌旁轻声交流：这个故事里的主角是谁呢？", ["story", "who", "read"]),
        4: ("owl window / reading nook", "圆眼窗阅读湾 · 安静读书角", "Curl up by the round owl window and read quietly in the soft light.", "坐在猫头鹰大圆眼窗旁的阅读湾里，伴着柔和阳光安静读书。", ["quiet", "read", "window"]),
        5: ("book cart / return", "木质还书车 · 图书归位", "Place your finished storybook neatly back onto the return cart.", "读完故事后，记得把绘本整整齐齐放回出口还书车上哦。", ["book", "put"]),
    },
    "landmark_P": {
        1: ("season sign / autumn", "农时木牌 · 金秋种植季", "Read the farm board — autumn is harvest season for golden pumpkins!", "看看农场门口的季节牌——金秋正是大南瓜丰收的好时节！", ["autumn", "season"]),
        2: ("trowel / pumpkin seeds", "农具木台 · 南瓜籽与小铲", "Take plump pumpkin seeds and a hand trowel from the tool bench.", "从左侧工具台挑几颗饱满的南瓜籽，拿起趁手的小园艺铲。", ["plant", "grow"]),
        3: ("pumpkin vine / big leaf", "瓜藤田垄 · 圆滚滚大南瓜", "Look under the wide green leaves — a round orange pumpkin is growing!", "拨开中央田垄宽大的绿叶看一看——圆滚滚的橙色大南瓜正长高呢！", ["orange", "big", "grow"]),
        4: ("farm scale / heavy", "丰收木秤台 · 比比谁更大", "Weigh two pumpkins on the scale — this orange pumpkin is heavier!", "把两个南瓜抱上右侧秤台比一比——左边这个橙南瓜更重更大！", ["big", "heavy"]),
        5: ("harvest basket / farm stand", "农产木篮架 · 丰收分享篮", "Load ripe pumpkins into the wooden basket to share with the canteen!", "把熟透的金黄南瓜装进出口木篮架，送去食堂煮香甜南瓜汤吧！", ["sweet", "soup", "share"]),
    },
    "landmark_Q": {
        1: ("story folder / cover", "故事封面夹 · 挑选主题", "Open the patchwork folder and pick today's fairy-tale theme!", "翻开入口拼布封面夹，挑选今天想编织的童话故事主题吧！", ["story", "book"]),
        2: ("card drawer / character", "图卡木抽屉 · 角色与场景卡", "Pull open the wooden drawer to pick character and scene picture cards.", "拉开左侧图片卡抽屉，挑出有趣的人物卡与小岛场景卡。", ["picture", "card"]),
        3: ("patchwork table / order", "拼布故事桌 · 先后顺序拼图", "Lay the quilt squares in order: first, then, and finally!", "在中央拼布故事桌上按先后顺序铺好彩布块，串起完整故事！", ["first", "then", "story"]),
        4: ("storytelling cushion / tell", "软布坐垫 · 给朋友讲故事", "Sit on the colourful quilt cushion and tell your story aloud!", "盘腿坐在右侧柔软的拼布坐垫上，把你排好的故事讲给伙伴听！", ["tell", "story", "listen"]),
        5: ("quilt wall / tapestry", "故事被展墙 · 百衲故事挂毯", "Admire the giant colourful story quilt hanging on the warm wall!", "抬头看看出口展墙上悬挂的大幅五彩拼布被，每一格都是一段回忆！", ["beautiful", "warm", "picture"]),
    },
    "landmark_R": {
        1: ("command slot / card", "指令卡槽 · 前进左转卡", "Insert action cards into the slot: go straight, turn left, then stop!", "把动作指令卡插进门口卡槽：直走、左转，然后稳稳停下！", ["left", "right", "turn", "stop"]),
        2: ("gear tray / robot parts", "零件收纳格 · 齿轮与小轮子", "Find shiny gears, springs, and wheels in the robot parts tray.", "在左侧零件格里找出闪亮的小齿轮、发条弹簧和滚轮。", ["robot", "toy"]),
        3: ("test track / little robot", "中央测试台 · 发条小机器人", "Press start and watch the little robot march along the test track!", "按下启动键，看发条小机器人沿着中央测试台轨道咔哒前进！", ["robot", "walk", "go"]),
        4: ("repair arm / wrench", "维修工作桌 · 拧紧机械臂", "Use the small wrench to tighten the robot's waving metal arm.", "在右侧维修桌上拿起小扳手，帮小机器人拧紧会挥手的机械臂。", ["arm", "help", "robot"]),
        5: ("status screen / check", "完成状态屏 · 绿灯亮起", "Green light on the screen! Our helper robot finished every task!", "出口状态屏亮起绿灯啦！能干的小机器人顺利完成了全部指令！", ["good", "clever", "robot"]),
    },
    "landmark_S": {
        1: ("day-night wheel / sun & moon", "昼夜转盘 · 白昼与星空", "Turn the wooden wheel to see how bright day changes into starry night.", "轻轻转动门口的昼夜圆盘，观察晴朗白昼怎样变成璀璨星夜。", ["sun", "moon", "day", "night"]),
        2: ("star chart / constellation", "发光星图台 · 连星成图", "Connect the glowing dots on the star map to find the Big Bear!", "在左侧发光星图台上把闪亮的星星连成线，找找大熊星座吧！", ["star", "sky", "draw"]),
        3: ("celestial globe / sky", "中央天球仪 · 旋转星轨", "Turn the brass sky globe to see stars shining high above our island.", "拨动中央精巧的天球仪，看看小岛夜空上方旋转的闪亮星群。", ["star", "sky", "high"]),
        4: ("telescope / bright moon", "观星望远镜 · 寻找月亮与亮星", "Look through the dome telescope — the silver moon and stars are so clear!", "凑近右侧大望远镜仰望夜空——银色月亮和金星星清晰极啦！", ["moon", "star", "see"]),
        5: ("astronomy corner / star note", "星空展示角 · 观星小发现", "Pin your starlight observation card onto the observatory board!", "把今晚观测到的星星与月亮记录卡贴在出口发现展示角吧！", ["star", "night", "card"]),
    },
    "landmark_T": {
        1: ("timetable / nine o'clock", "发车时刻牌 · 列车时间表", "Check the station timetable — the red train leaves at nine o'clock!", "抬头看看车站入口时刻牌——红色小火车九点整准时发车！", ["train", "time", "nine"]),
        2: ("ticket window / ticket", "木质售票窗 · 小火车票", "Buy a train ticket to Harbour Bay at the sunny ticket window, please.", "在左侧售票窗礼貌说明目的地，领一张前往海湾站的小车票吧。", ["train", "ticket", "go"]),
        3: ("platform / yellow line", "中央候车站台 · 安全候车线", "Stand behind the yellow line on the platform while waiting for the train.", "站在中央候车站台的安全黄线内，听小火车呜呜拉响汽笛进站！", ["train", "wait", "stop"]),
        4: ("luggage rack / suitcase", "站台行李架 · 整齐提包", "Put your heavy bag and suitcase safely onto the station luggage rack.", "把随身旅行包和小皮箱稳稳放到右侧站台行李架上。", ["bag", "put", "heavy"]),
        5: ("arrival board / next stop", "到站显示牌 · 下一站提示", "Look at the arrival screen — next stop is Central Island Square!", "看看出口到站显示屏——列车的下一站是字母岛中央广场！", ["train", "next", "stop"]),
    },
    "landmark_U": {
        1: ("weather wheel / sunny & rainy", "晴雨风向盘 · 今日天气", "Spin the weather wheel to today's icon: is it sunny, windy, or rainy?", "拨动门口的天气轮盘对准今天的天空：是晴天、微风还是下雨呢？", ["weather", "sunny", "rainy", "windy"]),
        2: ("coat stand / umbrella & raincoat", "雨具衣帽架 · 雨伞与雨衣", "It is raining outside — grab a bright umbrella and raincoat from the stand!", "窗外下起小雨啦——快从左侧衣帽架拿起花雨伞和小雨衣吧！", ["umbrella", "coat", "rain"]),
        3: ("rain gauge / raindrop", "中央雨量柱 · 测雨刻度管", "Read the clear glass tube to measure how much rain fell today.", "观察中央透明雨量柱上的刻度，看看今天一共下了多少雨水。", ["rain", "water", "cloud"]),
        4: ("plan table / outdoor or indoor", "天气活动桌 · 晴天野餐雨天读书", "Plan our day by the weather: fly kites on sunny days, read books on rainy days!", "在右侧计划桌按天气安排活动：晴天去放风筝，雨天在屋里读绘本！", ["sunny", "rainy", "kite", "book"]),
        5: ("forecast window / microphone", "小小气象窗 · 播报明日天气", "Stand at the forecast window and tell neighbours: Tomorrow will be warm and sunny!", "站在出口播报窗前当小小气象员：明天会是温暖晴朗的好天气哦！", ["tomorrow", "warm", "sunny", "weather"]),
    },
    "landmark_V": {
        1: ("trail sign / hill path", "登山路线牌 · 环山观察步道", "Follow the wooden trail sign to walk safely around the quiet volcano hill.", "对照入口路线牌，沿着平缓安全的环山步道开启岩石观察之旅。", ["hill", "mountain", "walk"]),
        2: ("rock table / rough stone", "岩石样本台 · 粗糙火山石", "Touch the volcano rock on the table — it feels rough, porous, and light!", "摸一摸左侧样本台上的休眠火山石——表面粗糙又有细小气孔！", ["stone", "rock", "small"]),
        3: ("sand table / crater peak", "火山地形沙盘 · 山顶与山脚", "Look at the 3D sand model to compare the round crater peak and gentle foot.", "围着中央火山地形沙盘看一看，比较圆圆的山顶与平缓的山脚。", ["mountain", "high", "hill"]),
        4: ("strata window / earth layers", "岩层观察窗 · 彩色地质条纹", "Count the brown, red, and grey rock layers through the viewing window!", "透过右侧岩层观察窗数一数：棕色、红褐色与灰色的岩石纹理真奇妙！", ["brown", "red", "see"]),
        5: ("explorer shelf / field log", "探险记录架 · 地质考察本", "Stamp your explorer notebook on the shelf after finishing the hill walk!", "完成火山观察站巡礼后，在出口记录架上给探险手册盖个纪念章吧！", ["book", "walk", "hill"]),
    },
    "landmark_W": {
        1: ("ocean map / deep sea", "海洋导览图 · 蔚蓝航程", "Trace the blue ocean map to see where gentle whales swim and sing!", "顺着入口海洋旅程图看一看，温柔的大蓝鲸在哪些海域巡游歌唱！", ["sea", "water", "blue"]),
        2: ("tide pool / seashell & crab", "海岸样本池 · 贝壳与海星", "Look into the shallow tide pool at spiral shells and little starfish.", "低头看看左侧浅水样本池里的螺旋花贝壳和彩色小海星。", ["fish", "sea", "small"]),
        3: ("whale rug / giant size", "鲸鱼比例地毯 · 比比有多长", "Walk from head to tail on the blue whale rug — whales are huge!", "从中央蓝鲸比例地毯的鼻尖走到尾鳍——原来蓝鲸这么巨大呀！", ["big", "long", "fish"]),
        4: ("aquarium window / swimming whale", "海底观察巨窗 · 鲸鱼跃游", "Watch through the giant blue window as a whale waves its wide tail!", "站在右侧蔚蓝海底巨窗前，看大蓝鲸摇动宽大尾鳍悠然游过！", ["sea", "swim", "big"]),
        5: ("tail bay / ocean story", "尾鳍分享湾 · 守护蔚蓝大海", "Share your favourite sea animal at the bay and promise to keep oceans clean!", "在出口尾鳍分享湾聊聊你最爱的海洋动物，一起守护洁净大海！", ["clean", "sea", "animal"]),
    },
    "landmark_X": {
        1: ("rehearsal board / music time", "排练日程牌 · 海风音乐会", "Check the seaside stage board for our afternoon xylophone rehearsal!", "看看海边舞台门口的日程牌，确认下午木琴合奏的排练时间！", ["music", "afternoon", "time"]),
        2: ("mallet rack / wooden mallets", "木琴槌架 · 圆头小琴槌", "Take two round-headed mallets from the stand and pass a pair to your friend.", "从左侧琴槌架取两支圆头小琴槌，再递给身旁合奏伙伴一对吧。", ["play", "friend", "music"]),
        3: ("rainbow xylophone / clear notes", "中央彩木琴 · 叮咚音条", "Tap the long and short xylophone bars — ding-dong, listen to the clear notes!", "轻轻敲击中央彩木琴长短不同的音条——叮咚叮咚，音色多清脆呀！", ["listen", "music", "play"]),
        4: ("footprint spots / duet", "合奏脚印位 · 默契轮流敲", "Stand on the painted footprints and play a cheerful duet together!", "踩在右侧彩色合奏脚印位上，和小伙伴一唱一和敲出欢快旋律！", ["play", "listen", "dance"]),
        5: ("stage photo stand / applause", "海边演出照架 · 谢幕合影", "Smile by the seaside photo stand to celebrate our wonderful concert!", "在出口演出照片架前开心地比个耶，纪念这场精彩的海风音乐会！", ["happy", "photo", "music"]),
    },
    "landmark_Y": {
        1: ("craft card / scarf & coaster", "手作样卡板 · 绒线小物图", "Pick a craft pattern card — let's weave a warm scarf or a cup coaster!", "在入口手作样卡板上挑一张图样——今天来织小围巾还是杯垫呢？", ["sweater", "coat", "warm"]),
        2: ("yarn rack / colourful wool", "毛线轴木架 · 五彩软绒线", "Touch the yarn spools on the rack — pink, yellow, and sky-blue wool feel so soft!", "摸摸左侧木架上的毛线团——粉的、黄的、天蓝的绒线软绵绵真舒服！", ["pink", "yellow", "blue", "colour"]),
        3: ("yarn winder / round ball", "中央绕线器 · 绕成圆线团", "Turn the wooden handle gently to wind loose yarn into a neat round ball.", "轻轻摇动中央木绕线器的手柄，把松散毛线绕成圆滚滚的线团。", ["round", "ball", "turn"]),
        4: ("knitting table / weave", "编织工作桌 · 巧手织毛线", "Weave the colourful yarn threads across the loom step by step.", "坐在右侧织作桌前，按图样把彩色绒线一针一线编织成温暖布片。", ["make", "warm", "sweater"]),
        5: ("gift box table / handmade gift", "绒线礼盒台 · 暖心手作礼", "Pack your soft handmade scarf into a gift box: This warm gift is for you!", "在出口礼盒台把织好的软围巾装进礼盒：这份暖心礼物送给你！", ["gift", "warm", "you"]),
    },
    "landmark_Z": {
        1: ("inbox / postcard & letter", "斑马收件箱 · 待寄信件", "Check the striped postbox at the door for letters waiting to travel!", "看看邮局门口黑白条纹收件箱里有哪些等待出发的信件与明信片！", ["letter", "card"]),
        2: ("sorting cubbies / address", "地址分拣格 · 按街区归类", "Read the island address on each envelope and sort it into the right box.", "仔细看清信封上的小岛地址，在左侧分拣格按街区准确归类。", ["letter", "home", "school"]),
        3: ("writing desk / stamp & postcard", "中央写信桌 · 贴邮票写祝福", "Write a kind note on a postcard and stick a cute zebra stamp in the corner!", "在中央写信桌写下温暖祝福，再在明信片右上角贴一张小斑马邮票！", ["write", "card", "letter"]),
        4: ("mailbag rack / canvas bag", "路线邮袋架 · 投递帆布袋", "Put the sorted letters into the harbour, school, and village mailbags.", "把分拣好的信件分别装进右侧前往港口、校园和广场的帆布邮袋里。", ["bag", "school", "put"]),
        5: ("postmark wall / island stamps", "旅程邮戳墙 · 纪念邮戳印记", "Press a round postmark stamp to see all the places our letters visited!", "在出口邮戳墙盖一枚圆圆的纪念戳，看看信件走遍了小岛多少角落！", ["place", "world", "draw"]),
    },

    # ===================== 8 SCHOOL SCENES (40 ANCHORS) =====================
    "school": {
        1: ("campus map / school gate", "校门导览牌 · 学园地图", "Look at the campus map by the gate to find all seven school rooms!", "在校门导览牌前看清校园地图，认识教室、食堂与操场七处场所！", ["school", "classroom", "map"]),
        2: ("hallway doors / classroom signs", "教学楼门廊 · 四间教室门牌", "Read the door signs ahead: Classroom, Music Room, Art Room, and Science Room!", "站在教学楼前认一认门牌：阳光教室、音乐室、美术室和科学室！", ["classroom", "music", "art", "science"]),
        3: ("campus garden / green grass", "中心小花园 · 校园花草", "Walk along the sunny garden path and smell the blooming campus flowers.", "沿着中心花园的石子路散步，观察校园里盛开的花朵与青草。", ["garden", "flower", "grass"]),
        4: ("sports rack / skipping rope", "操场入口器材架 · 球与跳绳", "Check the sports stand by the playground gate for balls and jump ropes!", "在通往操场的运动器材旁认一认篮球、足球和彩色跳绳！", ["football", "basketball", "play"]),
        5: ("canteen menu / lunch board", "餐厅菜单牌 · 今日营养午餐", "Read today's lunch menu outside the canteen — warm soup, bread, and fruit!", "看看食堂门口的今日菜单牌——有热汤、松软面包和新鲜水果！", ["lunch", "soup", "bread", "fruit"]),
    },
    "classroom": {
        1: ("name card / desk tag", "门口姓名牌台 · 桌签卡", "Find your name card on the stand and say: Hello, nice to meet you!", "在门口姓名牌台找到名字卡，微笑着打招呼：你好，很高兴认识你！", ["name", "hello", "meet"]),
        2: ("reading corner / picture book", "左窗阅读角 · 英语绘本架", "Open a picture book in the sunny reading corner and read aloud!", "在明亮的左窗阅读角翻开一本图画书，跟着示范大声读一句吧！", ["book", "read", "story"]),
        3: ("partner desks / blackboard", "中央结伴课桌 · 黑板与讲台", "Sit at the partner desk, look at the blackboard, and greet your classmate!", "在中央结伴课桌坐好，看向黑板，和同桌用英语互相问好吧！", ["blackboard", "desk", "class", "classmate"]),
        4: ("prop cabinet / role-play cards", "情境道具柜 · 课堂头饰与词卡", "Pick word cards and puppets from the cabinet for our classroom game!", "从右侧情境道具柜取出手偶和单词卡，一起演一段有趣的课堂对话！", ["card", "game", "play"]),
        5: ("work wall / gold stars", "班级作品墙 · 优秀画作贴纸", "Look at our colourful drawings and star stickers on the classroom wall!", "欣赏出口作品墙上同学们贴满星星贴纸的英语小报与画作吧！", ["picture", "star", "good"]),
    },
    "music_room": {
        1: ("music stand / songbook", "乐谱木柜 · 五线谱歌本", "Open the songbook on the cabinet to pick a happy melody to sing!", "翻开入口乐谱柜上的歌本，挑一首轻快好听的英文歌来学唱吧！", ["music", "sing", "song"]),
        2: ("grand piano / black & white keys", "三角钢琴 · 黑白琴键", "Press the black and white piano keys gently to hear sweet notes!", "走近三角钢琴观察整齐的黑白琴键，轻轻按下听听悦耳的琴声！", ["piano", "music", "play"]),
        3: ("rhythm drum / steady beat", "节奏圆鼓 · 欢快节拍", "Tap a steady one-two-three beat on the classroom rhythm drum!", "拍打音乐室里的节奏圆鼓，打出“咚哒、咚哒”的欢快节拍！", ["music", "play", "three"]),
        4: ("violin / string rack", "弦乐器架 · 小提琴与琴弓", "Look at the wooden violin and bow resting neatly on the string rack.", "仔细观察弦乐器架上优雅的木制小提琴与细长琴弓。", ["violin", "music", "listen"]),
        5: ("mini stage / microphone", "合唱小舞台 · 登台演唱", "Step onto the little music stage and sing a cheerful song with friends!", "站上音乐室的小舞台，和伙伴们自信快乐地合唱一首歌吧！", ["sing", "song", "dance"]),
    },
    "art_room": {
        1: ("apron cabinet / paintbrush", "围裙工具柜 · 画笔与小围裙", "Put on a clean art apron and pick a soft paintbrush before painting!", "打开美术室围裙柜系好防脏小围裙，挑一支顺手的软毛画笔吧！", ["draw", "brush", "art"]),
        2: ("palette / colourful paints", "颜料调色台 · 红黄蓝调色盘", "Mix yellow and blue paint on the palette — look, it turns bright green!", "在颜料调色台上把黄颜料和蓝颜料混在一起——哇，变成鲜绿色啦！", ["colour", "yellow", "blue", "green", "red"]),
        3: ("wooden easel / canvas", "木画架 · 风景画布", "Stand in front of the wooden easel and paint a sunny island picture!", "站在木画架前拿起画笔，在画布上描绘阳光明媚的小岛风景吧！", ["draw", "picture", "art"]),
        4: ("clay table / soft clay", "陶泥手工桌 · 捏小动物", "Shape soft brown clay on the table into a cute little rabbit or cup!", "在陶泥桌上揉一揉柔软的陶土，捏出一只长耳小兔或小茶杯吧！", ["rabbit", "cup", "make"]),
        5: ("art gallery wall / paintings", "美术作品墙 · 缤纷画展", "Walk along the gallery wall and tell which colourful painting you like best!", "沿着美术室作品墙欣赏大家的画作，说说你最喜欢哪一幅色彩！", ["picture", "colour", "beautiful"]),
    },
    "science_room": {
        1: ("goggles / lab coat", "安全准备区 · 护目镜与放大镜", "Put on safety goggles and pick up a magnifying glass before our experiment!", "做实验前先到安全准备区戴好护目镜，拿起清晰的小放大镜！", ["science", "glasses", "look"]),
        2: ("microscope / slide", "显微镜实验台 · 微观观察镜", "Look through the microscope lens to see tiny veins on a green leaf!", "凑近显微镜台的目镜看一看——绿叶片上细小的叶脉清晰可见！", ["science", "see", "small"]),
        3: ("sprout pot / green leaves", "植物观察台 · 发芽小豆苗", "Measure how tall the green bean plant grew in the sunlight this week!", "在植物观察台量一量向阳生长的小豆苗这周又长出了几片新叶！", ["plant", "tree", "green", "grow"]),
        4: ("magnet / paperclips", "磁铁实验台 · 红蓝吸铁石", "Bring the U-shaped magnet close — click! It pulls the metal clips right up!", "把磁铁实验台上的红蓝磁铁靠近回形针——啪！金属回形针被吸起来啦！", ["science", "try", "look"]),
        5: ("model shelf / dinosaur & globe", "科学模型架 · 恐龙与太阳系模型", "Explore the dinosaur skeleton and planet models on the science shelf!", "看看模型展示架上酷酷的恐龙骨架模型与旋转的行星仪吧！", ["dinosaur", "earth", "science"]),
    },
    "canteen": {
        1: ("today's menu / healthy food", "入口菜单板 · 今日美味食谱", "Read the canteen menu board: warm milk, fresh bread, fish, and apples!", "看看食堂入口菜单板上的今日美食：温牛奶、软面包、鱼肉和红苹果！", ["milk", "bread", "fish", "apple"]),
        2: ("cutlery tray / spoon & chopsticks", "洁净餐具台 · 勺子筷子与餐盘", "Take a clean tray, a spoon, and chopsticks from the cutlery stand.", "从左侧餐具台取一只干净餐盘、一把小勺和一双筷子。", ["spoon", "chopsticks", "clean"]),
        3: ("serving window / polite order", "中央取餐窗口 · 礼貌点餐", "Smile at the chef by the window: I'd like some bread and warm soup, please!", "在中央取餐窗口礼貌地对主厨说：请给我一些面包和热汤，谢谢！", ["bread", "soup", "milk", "please"]),
        4: ("dining table / yummy lunch", "阳光用餐桌 · 与同学共进午餐", "Sit with your classmates at the sunny table and enjoy a yummy lunch!", "端着餐盘在右侧用餐分享桌坐下，和同学们开心地享用营养午餐！", ["lunch", "eat", "friend"]),
        5: ("tray return / tidy up", "餐盘回收台 · 光盘归位", "Carry your empty tray and bowl neatly to the return stand after lunch.", "吃完午餐做到光盘不浪费，再把空餐盘和小碗整齐送回出口回收台。", ["clean", "bowl", "good"]),
    },
    "playground": {
        1: ("game rules board / take turns", "活动约定牌 · 轮流友好玩耍", "Read the playground board: let's play safely and take turns with friends!", "看看操场入口约定牌：和伙伴安全运动、互相礼让、轮流玩耍！", ["play", "turn", "friend"]),
        2: ("ball rack / jump rope", "运动器材架 · 彩球与长跳绳", "Pick a bouncy ball or a skipping rope from the playground rack!", "从左侧器材架挑一颗弹性十足的彩球或一根彩色跳绳吧！", ["ball", "jump", "play"]),
        3: ("game circle / play together", "中央合作游戏圈 · 手拉手做游戏", "Join the sunny grass circle and call out: Come and play with us!", "跑进青草操场中央的合作游戏圈，热情招呼伙伴一起来做游戏！", ["play", "run", "happy"]),
        4: ("hopscotch grid / numbers", "彩虹跳格线 · 边跳边数数", "Hop along the painted squares on the ground: one, two, three, four, five!", "顺着右侧地面彩绘跳格线轻快单脚跳：一、二、三、四、五！", ["jump", "one", "two", "three", "five"]),
        5: ("photo board / team smile", "课间照片栏 · 活力笑脸墙", "Look at the playground photo board full of running and laughing friends!", "看看出口活动照片栏里大家在阳光下奔跑欢笑的精彩瞬间吧！", ["photo", "run", "happy"]),
    },
    "football_field": {
        1: ("gear bench / football & jersey", "球场装备区 · 足球与队服背心", "Put on your team jersey and lace up your shoes by the football bench!", "在装备区穿好鲜艳的运动队服背心，系紧球鞋鞋带准备上场！", ["football", "shirt", "shoes"]),
        2: ("centre circle / kick off", "绿茵开球中圈 · 准备开球", "Place the black-and-white football on the white centre spot to kick off!", "把黑白相间的足球稳稳放在绿茵场开球中圈的白点上准备开球！", ["football", "ball", "play"]),
        3: ("goalpost / shoot & score", "白色射门球门 · 瞄准球网射门", "Aim carefully at the wide white goalpost and kick the ball into the net!", "站在球门前看准空当，飞起一脚把足球稳稳踢进球网得分！", ["football", "goal", "win"]),
        4: ("training cones / pass the ball", "锥桶传球区 · 带球绕桩配合", "Dribble around the orange cones and pass the football to your teammate!", "灵巧地带球绕过橙色训练锥桶，再把足球稳稳传给队友！", ["football", "run", "fast"]),
        5: ("scoreboard / cheer", "看台计分牌 · 为双方喝彩", "Check the match scoreboard by the stand and cheer for every great play!", "抬头看看看台计分牌上的比分，为球场上每一次精彩配合鼓掌喝彩！", ["football", "game", "win"]),
    },
}


def build_word_lookup(catalog: dict) -> dict[str, dict]:
    by_lower: dict[str, dict] = {}
    for entry in catalog.get("entries", []):
        w = str(entry.get("spelling_display", "")).strip().lower()
        # Prefer formal_spelling_eligible or first occurrence
        if w not in by_lower:
            by_lower[w] = entry
    return by_lower


def resolve_palace_link(candidates: list[str], word_map: dict[str, dict], fallback_entry: dict) -> tuple[str, str, str]:
    for cand in candidates:
        c = cand.lower().strip()
        if c in word_map:
            ent = word_map[c]
            return str(ent["spelling_display"]), str(ent["entry_id"]), str(ent["meaning_zh"])
    return str(fallback_entry["spelling_display"]), str(fallback_entry["entry_id"]), str(fallback_entry["meaning_zh"])


def main() -> None:
    catalog = json.loads(CATALOG_PATH.read_text("utf-8"))
    home_data = json.loads(HOME_PATH.read_text("utf-8"))
    landmark_data = json.loads(LANDMARK_PATH.read_text("utf-8"))

    word_map = build_word_lookup(catalog)
    fallback_entry = word_map["apple"]

    # Collect all 210 anchors from game data to ensure 100% exact coverage
    expected_anchors: dict[str, tuple[str, str, str]] = {}
    for r in home_data["rooms"]:
        rid = r["room_id"]
        for a in r["anchors"]:
            key = f"{rid}:{a['order']}"
            expected_anchors[key] = (r["name"], a["label"], a.get("activity", ""))

    for entry in landmark_data["landmarks"]:
        rid = entry.get("room_id", "")
        if rid and rid != "home" and entry.get("anchors"):
            for idx, a in enumerate(entry["anchors"], start=1):
                order = int(a.get("order", idx))
                expected_anchors[f"{rid}:{order}"] = (entry.get("name", rid), a.get("label", ""), a.get("activity", ""))
        for area in entry.get("areas", []):
            arid = area.get("room_id", "")
            if arid and arid != "home" and area.get("anchors"):
                for idx, a in enumerate(area["anchors"], start=1):
                    order = int(a.get("order", idx))
                    expected_anchors[f"{arid}:{order}"] = (area.get("name", arid), a.get("label", ""), a.get("activity", ""))

    assert len(expected_anchors) == 210, f"Expected 210 anchors, found {len(expected_anchors)}"

    compiled: dict[str, dict] = {}
    for key, (room_name, label_zh, orig_activity) in sorted(expected_anchors.items()):
        rid, ord_str = key.split(":")
        order = int(ord_str)
        assert rid in ANCHOR_SPECS and order in ANCHOR_SPECS[rid], f"Missing spec for {key} ({label_zh})"
        obj_en, obj_zh, phrase_en, phrase_zh, candidates = ANCHOR_SPECS[rid][order]
        p_word, p_entry_id, p_meaning = resolve_palace_link(candidates, word_map, fallback_entry)
        compiled[key] = {
            "room_id": rid,
            "order": order,
            "room_name": room_name,
            "anchor_label": label_zh,
            "object_en": obj_en,
            "object_zh": obj_zh,
            "phrase_en": phrase_en,
            "phrase_zh": phrase_zh,
            "activity_zh": orig_activity,
            "palace_word": p_word,
            "palace_entry_id": p_entry_id,
            "palace_meaning_zh": p_meaning,
        }

    # Verify zero duplicate phrase_en across the entire 210-anchor world!
    seen_phrases: dict[str, str] = {}
    for k, v in compiled.items():
        pe = v["phrase_en"]
        assert pe not in seen_phrases, f"Duplicate phrase_en between {k} and {seen_phrases[pe]}: {pe}"
        seen_phrases[pe] = k

    out_payload = {
        "schema_version": 5,
        "anchor_count": len(compiled),
        "anchors": compiled,
    }
    OUT_PATH.write_text(json.dumps(out_payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Successfully compiled {len(compiled)} unique object anchors -> {OUT_PATH} ({OUT_PATH.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
