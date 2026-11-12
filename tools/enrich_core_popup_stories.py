"""Generate `game/data/learning/popup_choreography_v4.json` for `PopupBookTheater`.

Maps 250+ high-frequency elementary words (plus semantic fallback for all 1,314
entries in `catalog.json`) to:
  - `dance_style`: one of 5 3D standee puppet choreographies
    (`bounce_wave`, `orbit_dance`, `peekaboo_pop`, `domino_cheer`, `starlight_float`)
  - `example_en`: natural, cozy child-friendly English island usage sentence
  - `example_zh`: warm Chinese translation
  - `curated`: True for hand-authored core words, False for smart semantic fallback

Never mutates `catalog.json` so `test_memory_story.gd` (4,989 checks) remains untouched.
Also pre-bakes all unique curated `example_en` sentences into `.local/tts_cache/`!
"""
from __future__ import annotations

import asyncio
import hashlib
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from services.ai_companion.speech_service import synthesize_speech  # noqa: E402

CATALOG_PATH = ROOT / "game" / "data" / "learning" / "catalog.json"
OUT_PATH = ROOT / "game" / "data" / "learning" / "popup_choreography_v4.json"

DANCE_STYLES = [
    "bounce_wave",
    "orbit_dance",
    "peekaboo_pop",
    "domino_cheer",
    "starlight_float",
]

# 260+ hand-authored core elementary vocabulary usage sentences & 3D choreographies
CORE_WORDS: dict[str, tuple[str, str, str]] = {
    # Greetings & Courtesy
    "hello": ("bounce_wave", "Hello! Welcome to our sunny island!", "你好！欢迎来到我们阳光明媚的小岛！"),
    "hi": ("bounce_wave", "Hi friend! Let's walk together.", "嗨，朋友！我们一起散步吧。"),
    "good": ("domino_cheer", "Good morning! Have a joyful day!", "早上好！祝你拥有开心的一天！"),
    "morning": ("starlight_float", "The morning sun warms our little garden.", "清晨的阳光温暖着我们的小花园。"),
    "afternoon": ("starlight_float", "Let's share sweet tea this afternoon.", "今天下午我们一起分享香甜茶点吧。"),
    "evening": ("starlight_float", "Soft lamps glow in the quiet evening.", "柔和的灯光在安静的傍晚亮起。"),
    "night": ("starlight_float", "Good night! Sweet dreams in your cozy bed.", "晚安！在松软的小床上做个好梦。"),
    "goodbye": ("bounce_wave", "Goodbye! See you tomorrow at school!", "再见！明天在学校见哦！"),
    "bye": ("bounce_wave", "Bye! Wave to Uncle Bear before you go.", "拜拜！走之前向熊叔挥挥手吧。"),
    "thank": ("domino_cheer", "Thank you for the sweet red apples!", "谢谢你送来的香甜红苹果！"),
    "thanks": ("domino_cheer", "Thanks for helping me tidy the desk!", "谢谢你帮我整理书桌！"),
    "please": ("bounce_wave", "Pass me the warm milk, please.", "请把温牛奶递给我吧。"),
    "sorry": ("peekaboo_pop", "I'm sorry! Let's pick up the books together.", "对不起呀！我们一起把书捡起来吧。"),
    "welcome": ("domino_cheer", "You're welcome to visit my home anytime!", "随时欢迎你来我家做客！"),
    "help": ("bounce_wave", "Can I help you carry this basket?", "我可以帮你一起提这个篮子吗？"),

    # Family & People
    "family": ("orbit_dance", "My family loves having picnics on Sunday.", "我们一家人喜欢在周日去野餐。"),
    "father": ("bounce_wave", "My father reads funny stories with me.", "爸爸和我一起读有趣的故事书。"),
    "dad": ("bounce_wave", "Dad baked warm bread in the kitchen.", "爸爸在厨房里烤了暖呼呼的面包。"),
    "mother": ("starlight_float", "My mother planted sunflowers in the yard.", "妈妈在院子里种下了向日葵。"),
    "mum": ("starlight_float", "Mum made a yummy fruit salad for us.", "妈妈为我们做了美味的水果沙拉。"),
    "brother": ("domino_cheer", "My brother plays football on the green grass.", "哥哥在绿草地上踢足球。"),
    "sister": ("orbit_dance", "My sister painted a rainbow postcard.", "姐姐画了一张彩虹明信片。"),
    "grandfather": ("bounce_wave", "Grandfather waters the apple trees every day.", "爷爷每天给苹果树浇水。"),
    "grandpa": ("bounce_wave", "Grandpa tells gentle tales under the tree.", "爷爷在大树下讲温柔的故事。"),
    "grandmother": ("starlight_float", "Grandmother knitted a soft yellow scarf.", "奶奶织了一条柔软的黄围巾。"),
    "grandma": ("starlight_float", "Grandma's tea smells like sweet flowers.", "奶奶泡的茶有甜甜的花香。"),
    "uncle": ("domino_cheer", "Uncle Bear runs the warmest bakery in town!", "熊叔经营着小镇最温暖的烘焙坊！"),
    "aunt": ("orbit_dance", "My aunt brought a basket of fresh pears.", "阿姨带来了一篮新鲜梨子。"),
    "cousin": ("peekaboo_pop", "My cousin and I fly kites in spring.", "我和表弟在春天一起放风筝。"),
    "baby": ("peekaboo_pop", "The little baby claps hands and smiles.", "小宝宝拍拍小手笑了起来。"),
    "boy": ("bounce_wave", "The friendly boy shared his blue ball.", "友好的小男孩分享了他的蓝皮球。"),
    "girl": ("orbit_dance", "The girl wears a sunny straw hat today.", "小女孩今天戴着阳光草帽。"),
    "friend": ("domino_cheer", "You are my best friend on Alphabet Island!", "你是我在字母岛上最好的朋友！"),
    "teacher": ("bounce_wave", "Our teacher listens to every story with a smile.", "老师微笑着倾听每一个故事。"),
    "pupil": ("domino_cheer", "Every pupil drew a star on the welcome wall.", "每位同学都在欢迎墙上画了一颗星星。"),
    "student": ("domino_cheer", "The student carries a neat green schoolbag.", "这位学生背着整洁的绿书包。"),
    "doctor": ("bounce_wave", "The kind doctor reminds us to drink warm water.", "温柔的医生提醒我们多喝温水。"),
    "nurse": ("starlight_float", "The nurse put a cute sticker on my hand.", "护士在我的手背贴了一张可爱贴纸。"),
    "driver": ("orbit_dance", "The bus driver waves hello every morning.", "公交车司机每天早上挥手问好。"),
    "farmer": ("bounce_wave", "The farmer harvested sweet oranges today.", "农夫今天收获了香甜的橙子。"),
    "cook": ("orbit_dance", "The cook stirs warm soup in the canteen.", "厨师在食堂里搅动热腾腾的浓汤。"),

    # School & Stationery
    "school": ("domino_cheer", "Let's walk along the flower path to school!", "我们顺着花径小路去学校吧！"),
    "class": ("domino_cheer", "Our class sang a cheerful song together.", "我们全班一起唱了一首欢快的歌。"),
    "classroom": ("bounce_wave", "Sunlight shines through our bright classroom window.", "阳光透过明亮的教室窗户照进来。"),
    "book": ("peekaboo_pop", "Open this pop-up book and watch letters dance!", "翻开这本立体书，看字母纸偶跳舞吧！"),
    "bag": ("bounce_wave", "I packed my storybook inside my yellow bag.", "我把故事书装进了黄色背包里。"),
    "schoolbag": ("bounce_wave", "My schoolbag feels light and tidy today.", "今天我的书包又轻巧又整洁。"),
    "pen": ("domino_cheer", "Write your wish on the card with this pen.", "用这支钢笔把心愿写在卡片上吧。"),
    "pencil": ("domino_cheer", "I drew a smiling bunny with my pencil.", "我用铅笔画了一只微笑的小兔子。"),
    "ruler": ("domino_cheer", "Use a wooden ruler to draw a straight line.", "用木尺画一条笔直的线吧。"),
    "eraser": ("peekaboo_pop", "My soft eraser looks like a little white cloud.", "我的软橡皮像一朵小白云。"),
    "crayon": ("orbit_dance", "Pick a bright crayon to color the flowers!", "挑一支鲜艳蜡笔给花朵涂色吧！"),
    "desk": ("bounce_wave", "There is a green plant on my wooden desk.", "我的木书桌上摆着一盆绿植。"),
    "chair": ("bounce_wave", "Pull up a cozy chair and join our story circle.", "拉一把舒适小椅加入我们的故事圈吧。"),
    "blackboard": ("domino_cheer", "We drew colorful stars on the blackboard.", "我们在黑板上画满了彩色星星。"),
    "computer": ("peekaboo_pop", "We look up island maps on the computer.", "我们在电脑上查阅小岛地图。"),
    "library": ("starlight_float", "The school library has hundreds of picture books.", "学校图书馆里有几百本图画书。"),
    "english": ("domino_cheer", "Speaking English with island friends is fun!", "和小岛伙伴说英语真有趣！"),
    "music": ("orbit_dance", "Sweet piano music floats across the courtyard.", "悦耳的钢琴曲飘过阳光小院。"),
    "art": ("orbit_dance", "In art room we paint postcards for neighbors.", "在美术室我们为邻居画明信片。"),
    "science": ("peekaboo_pop", "We mix blue and yellow water in science room!", "我们在科学室里把蓝水和黄水调在一起！"),

    # Food, Fruit & Drinks
    "apple": ("bounce_wave", "Pick a ripe red apple and put it in the basket!", "摘一颗熟透的红苹果放进果篮吧！"),
    "banana": ("bounce_wave", "Monkeys love sweet yellow bananas!", "小猴子最爱香甜的黄香蕉啦！"),
    "orange": ("orbit_dance", "This juicy orange smells so fresh and bright.", "这颗多汁的橙子闻起来真清新。"),
    "pear": ("bounce_wave", "Crisp golden pears grow in the autumn orchard.", "脆甜的金梨生长在秋日果园里。"),
    "peach": ("peekaboo_pop", "A pink peach tastes sweet on a summer day.", "夏日里的粉桃子尝起来甜甜的。"),
    "grape": ("orbit_dance", "Purple grapes hang like little bells on the vine.", "紫葡萄像小铃铛一样挂在藤上。"),
    "watermelon": ("domino_cheer", "Cool watermelon is the best summer treat!", "冰凉的西瓜是最棒的夏日美味！"),
    "strawberry": ("peekaboo_pop", "Put a red strawberry on top of the cake!", "把红草莓放在蛋糕最上面吧！"),
    "lemon": ("peekaboo_pop", "Add a slice of yellow lemon to warm tea.", "在热茶里加一片黄柠檬吧。"),
    "fruit": ("orbit_dance", "Fresh island fruit makes everyone healthy.", "新鲜的小岛水果让大家活力满满。"),
    "cake": ("domino_cheer", "Three apples bake one warm fluffy cake!", "三颗苹果能烤出一份松软蛋糕！"),
    "bread": ("bounce_wave", "Freshly baked bread smells so cozy at breakfast.", "早餐刚出炉的面包香气扑鼻。"),
    "milk": ("starlight_float", "Drink a cup of warm milk before bedtime.", "睡前喝一杯暖暖的牛奶吧。"),
    "water": ("starlight_float", "Clear spring water sparkles in the fountain.", "清澈的泉水在喷泉里闪闪发光。"),
    "juice": ("orbit_dance", "Would you like a glass of sweet orange juice?", "你想来一杯香甜的橙汁吗？"),
    "tea": ("starlight_float", "Let's set the tea table in our sunny living room.", "我们在阳光客厅摆好下午茶桌吧。"),
    "rice": ("bounce_wave", "Steaming white rice goes great with vegetables.", "热气腾腾的米饭配蔬菜真香。"),
    "noodle": ("orbit_dance", "Warm noodles make rainy days feel cozy.", "热汤面让雨天也变得暖洋洋。"),
    "noodles": ("orbit_dance", "I'd like a bowl of tomato noodles, please!", "请给我来一碗番茄面条吧！"),
    "dumpling": ("peekaboo_pop", "We make yummy dumplings together at home.", "我们在家里一起包香喷喷的饺子。"),
    "egg": ("peekaboo_pop", "A warm boiled egg gives me morning energy.", "一颗温热的鸡蛋给我满满晨间活力。"),
    "fish": ("orbit_dance", "Little silver fish swim happily in the pond.", "银色小鱼在池塘里快乐游动。"),
    "chicken": ("bounce_wave", "Roast chicken is ready on the dinner tray.", "烤鸡已经端上晚餐托盘啦。"),
    "tomato": ("bounce_wave", "Red tomatoes ripen in our backyard garden.", "红番茄在我们的后院菜园熟透了。"),
    "potato": ("peekaboo_pop", "Golden baked potatoes are crispy and warm.", "烤得金黄的土豆又香又暖。"),
    "candy": ("peekaboo_pop", "Share a fruit candy with your desk partner!", "和同桌分享一颗水果糖吧！"),
    "sweet": ("starlight_float", "Uncle Bear's honey cookies taste so sweet.", "熊叔做的蜂蜜饼干甜甜的。"),
    "breakfast": ("bounce_wave", "Good morning! Breakfast is ready on the table.", "早上好！早餐已经摆在餐桌上啦。"),
    "lunch": ("domino_cheer", "Let's eat lunch together in the sunny canteen!", "我们一起在阳光食堂吃午餐吧！"),
    "dinner": ("starlight_float", "Warm lantern light shines over family dinner.", "温暖的灯光照亮一家人的晚餐。"),

    # Animals & Nature
    "cat": ("peekaboo_pop", "The fluffy cat naps on our sunflower rug.", "毛茸茸的小猫在向日葵地毯上打盹。"),
    "dog": ("bounce_wave", "The happy dog wags its tail by the gate.", "开心的小狗在院门边摇尾巴。"),
    "doggie": ("bounce_wave", "Hello little doggie! Want to fetch the ball?", "你好呀小狗狗！想去捡皮球吗？"),
    "rabbit": ("bounce_wave", "The rabbit gardener wears a cute straw hat.", "兔兔园丁戴着一顶可爱的草帽。"),
    "duck": ("orbit_dance", "Yellow ducks paddle across the calm river.", "小黄鸭在平静的小河里划水。"),
    "bird": ("starlight_float", "A little blue bird sings in the apple tree.", "一只蓝小鸟在苹果树上唱歌。"),
    "hen": ("bounce_wave", "The brown hen walks slowly around the yard.", "棕色母鸡在院子里悠闲散步。"),
    "cow": ("bounce_wave", "The gentle cow eats green grass on the hill.", "温顺的奶牛在山坡上吃青草。"),
    "horse": ("domino_cheer", "The pony runs fast across the open meadow.", "小马穿过开阔的草地欢快奔跑。"),
    "sheep": ("starlight_float", "White sheep look like soft clouds on the hill.", "白绵羊在山坡上像软绵绵的云朵。"),
    "pig": ("peekaboo_pop", "The pink pig rolls happily in the sunshine.", "粉红小猪在阳光下开心地打滚。"),
    "monkey": ("orbit_dance", "A clever monkey swings from branch to branch.", "聪明的小猴子在树枝间荡秋千。"),
    "tiger": ("domino_cheer", "The brave tiger has bright orange stripes.", "勇敢的老虎有明亮的橙色条纹。"),
    "lion": ("domino_cheer", "The lion shakes its golden mane proudly.", "狮子神气地甩了甩金色鬃毛。"),
    "panda": ("peekaboo_pop", "The cute panda munches fresh green bamboo.", "可爱的熊猫津津有味地嚼着青竹子。"),
    "elephant": ("bounce_wave", "The elephant sprays cool water with its nose!", "大象用长鼻子喷出清凉的水花！"),
    "bear": ("bounce_wave", "Uncle Bear waves hello from the bakery door.", "熊叔在烘焙坊门口挥手问好。"),
    "mouse": ("peekaboo_pop", "A tiny mouse peeks out behind the wooden box.", "一只小老鼠从木箱后面探出头来。"),
    "dinosaur": ("domino_cheer", "My toy dinosaur stands tall on the bookshelf!", "我的玩具恐龙神气地立在书架上！"),
    "butterfly": ("starlight_float", "A colorful butterfly dances above the roses.", "彩色蝴蝶在玫瑰花丛上方翩翩起舞。"),
    "bee": ("orbit_dance", "Busy little bees hum softly near the flowers.", "勤劳的小蜜蜂在花朵旁轻轻哼唱。"),
    "ant": ("domino_cheer", "Little ants march in a neat line on the path.", "小蚂蚁在小路上排着整齐队伍前进。"),
    "tree": ("starlight_float", "Tall green trees shade our island footpath.", "高大的绿树为我们的小岛步道遮阴。"),
    "flower": ("starlight_float", "Water the flowers and watch them bloom!", "给花儿浇浇水，看它们绽放吧！"),
    "grass": ("bounce_wave", "Soft green grass tickles our shoes in spring.", "春天的绿草地轻拂着我们的鞋子。"),
    "river": ("starlight_float", "A wooden bridge crosses the singing river.", "一座小木桥跨过潺潺流淌的小河。"),
    "lake": ("starlight_float", "The clear lake mirrors the blue sky.", "清澈的湖水倒映着蔚蓝天空。"),
    "sea": ("orbit_dance", "Gentle waves kiss the sandy beach by the sea.", "温柔的海浪轻拍着海边沙滩。"),
    "mountain": ("domino_cheer", "Climb the hill to see the distant mountains!", "爬上小山丘看看远处的青山吧！"),
    "forest": ("starlight_float", "Fireflies twinkle inside the quiet forest.", "萤火虫在安静的森林里一闪一闪。"),
    "earth": ("orbit_dance", "We plant trees to take care of our green Earth.", "我们植树造林，守护绿色地球。"),
    "sun": ("starlight_float", "The golden sun smiles over Alphabet Island.", "金色的太阳朝字母岛微笑。"),
    "moon": ("starlight_float", "A silver moon hangs above our cozy roof.", "银色弯月挂在我们温馨的屋顶上。"),
    "star": ("starlight_float", "Count the twinkling stars in the night sky!", "数一数夜空里眨眼睛的小星星吧！"),
    "sky": ("starlight_float", "White clouds drift slowly across the blue sky.", "白云在蓝天上慢悠悠地飘过。"),

    # Colors & Adjectives
    "colour": ("orbit_dance", "What colour would you like for your postcard?", "你想给明信片涂上什么颜色呢？"),
    "color": ("orbit_dance", "Choose your favorite color from the paint box!", "从颜料盒里挑出你最喜欢的颜色吧！"),
    "red": ("bounce_wave", "Ripe apples and rooftops glow warm red.", "熟透的苹果与屋顶泛着温暖的红光。"),
    "blue": ("starlight_float", "My blue raincoat keeps me dry on rainy days.", "蓝色雨衣让我在雨天也干爽舒适。"),
    "yellow": ("bounce_wave", "Sunflowers wear bright yellow petals!", "向日葵长着明亮的黄色花瓣！"),
    "green": ("starlight_float", "Green leaves wave gently in the island breeze.", "绿叶在海岛微风中轻轻摇摆。"),
    "white": ("starlight_float", "Fluffy white clouds float above the lighthouse.", "蓬松的白云飘在灯塔上方。"),
    "black": ("domino_cheer", "The piano has shiny black and white keys.", "钢琴上有闪亮的黑白琴键。"),
    "pink": ("orbit_dance", "Peach blossoms turn the garden soft pink.", "桃花把小花园染成了柔和的粉色。"),
    "orange_color": ("orbit_dance", "Sunset paints the harbor warm orange.", "晚霞把小港口染成了温暖橙色。"),
    "brown": ("bounce_wave", "Our walnut bookshelf is warm chocolate brown.", "我们的胡桃木书架是温暖的棕褐色。"),
    "purple": ("starlight_float", "Sweet lavender flowers bloom in purple rows.", "薰衣草开出一排排淡紫色小花。"),
    "big": ("domino_cheer", "A big shady tree stands in the village square.", "一棵大树伫立在村庄广场中央。"),
    "small": ("peekaboo_pop", "A small ladybug rests on a green leaf.", "一只小瓢虫停在绿叶上休息。"),
    "little": ("peekaboo_pop", "This little wooden boat floats on the pond.", "这只小木船漂浮在池塘水面上。"),
    "long": ("domino_cheer", "A long stone path leads to the school gate.", "长长的石板路通向学校大门。"),
    "short": ("peekaboo_pop", "The puppy has short ears and a wagging tail.", "小狗长着短短的耳朵和摇晃的尾巴。"),
    "tall": ("domino_cheer", "The tall lighthouse guides ships home safely.", "高高的灯塔指引小船平安回家。"),
    "beautiful": ("starlight_float", "What a beautiful garden full of sunflowers!", "开满向日葵的花园真美丽呀！"),
    "nice": ("bounce_wave", "Nice to meet you on this sunny morning!", "在这个晴朗早晨见到你真高兴！"),
    "happy": ("bounce_wave", "Happy birthday! Make a wish by the cake!", "生日快乐！在蛋糕边许个愿吧！"),
    "new": ("domino_cheer", "I put on my new canvas bag for school.", "我背上新帆布包去上学啦。"),
    "old": ("bounce_wave", "How old are you? I am nine years old!", "你几岁啦？我今年九岁啦！"),
    "clean": ("starlight_float", "Our living room looks bright and clean!", "我们的客厅看起来又明亮又干净！"),
    "warm": ("starlight_float", "Warm sunshine fills our cozy study room.", "温暖的阳光洒满我们舒适的书房。"),
    "cool": ("orbit_dance", "Autumn wind feels cool and refreshing.", "秋天的微风凉爽又宜人。"),
    "hot": ("bounce_wave", "Put on a sun hat on a hot summer day!", "炎热的夏天记得戴上遮阳帽哦！"),
    "cold": ("peekaboo_pop", "Wear a soft coat when the winter wind is cold.", "冬风寒冷时穿上柔软的外套吧。"),

    # Weather, Seasons & Clothes
    "weather": ("orbit_dance", "How is the weather on the island today?", "今天小岛上的天气怎么样呀？"),
    "sunny": ("bounce_wave", "It's sunny today! Let's play in the courtyard!", "今天阳光明媚！我们去院子里玩吧！"),
    "rainy": ("peekaboo_pop", "On rainy days we listen to stories indoors.", "下雨天我们在屋里听故事。"),
    "rain": ("peekaboo_pop", "Gentle rain waters all the garden sprouts.", "温柔的春雨浇灌着花园里的嫩芽。"),
    "windy": ("orbit_dance", "Windy days are great for spinning pinwheels!", "有风的日子最适合转小风车啦！"),
    "cloudy": ("starlight_float", "It is cloudy and cool — nice for a walk.", "今天多云又凉爽，正好去散步。"),
    "snowy": ("starlight_float", "Snowy rooftops look like frosted sugar cakes!", "覆雪的屋顶像洒了糖霜的蛋糕！"),
    "snow": ("starlight_float", "Soft white snow sparkles in the morning light.", "洁白的雪花在晨光里闪闪发亮。"),
    "spring": ("bounce_wave", "In spring, green buds wake up everywhere.", "春天里，嫩绿的新芽到处苏醒。"),
    "summer": ("orbit_dance", "In summer, we hear cicadas and sea waves.", "夏天里，我们听见蝉鸣和海浪声。"),
    "autumn": ("starlight_float", "Golden leaves dance down in cozy autumn.", "金黄的落叶在温暖的秋天飘舞。"),
    "winter": ("peekaboo_pop", "In winter, we sip hot cocoa by the lamp.", "冬天里，我们在暖灯旁喝热可可。"),
    "coat": ("bounce_wave", "Button up your warm coat before going out.", "出门前扣好你暖和的外套吧。"),
    "shirt": ("domino_cheer", "This clean cotton shirt feels so comfortable.", "这件干净的棉衬衫穿起来真舒服。"),
    "t-shirt": ("bounce_wave", "My yellow T-shirt has a little star pocket.", "我的黄色T恤上有一个星星小口袋。"),
    "dress": ("orbit_dance", "Her floral dress twirls like a blooming flower.", "她的碎花裙转起来像盛开的花朵。"),
    "skirt": ("orbit_dance", "She chose a sky-blue skirt in the wardrobe.", "她在衣帽间挑了一条天蓝色短裙。"),
    "trousers": ("domino_cheer", "Comfortable trousers are great for climbing hills.", "舒服的长裤最适合去爬小山丘了。"),
    "shoe": ("bounce_wave", "Tie your shoes neatly before football practice!", "足球练习前把鞋带系整齐哦！"),
    "shoes": ("bounce_wave", "My rain shoes splash happily in puddles.", "我的小雨鞋在水洼里快乐踩水。"),
    "hat": ("peekaboo_pop", "Put on your straw hat and let's explore!", "戴上小草帽，我们出发探索吧！"),
    "cap": ("peekaboo_pop", "A sporty cap shades my eyes on the playground.", "运动帽在操场上为我遮挡阳光。"),
    "scarf": ("starlight_float", "Wrap a soft wool scarf around your neck.", "在脖子上围一条柔软的羊毛围巾吧。"),
    "umbrella": ("orbit_dance", "Open your rainbow umbrella in the light rain!", "在细雨中撑开你的彩虹雨伞吧！"),

    # Home, Rooms & Furniture
    "home": ("starlight_float", "Welcome home! Arrange your furniture any way you like!", "欢迎回家！随心布置你喜欢的家具吧！"),
    "house": ("domino_cheer", "Our little house has a sunny front courtyard.", "我们的小房子有一个阳光前院。"),
    "room": ("bounce_wave", "Every room in our house holds warm memories.", "家里的每个房间都藏着温暖回忆。"),
    "bedroom": ("starlight_float", "My bedroom has a soft bed and a star lamp.", "我的卧室有松软小床和摘星落地灯。"),
    "kitchen": ("orbit_dance", "Sweet cake aromas drift out of the kitchen.", "香甜的蛋糕味从厨房飘出来。"),
    "bathroom": ("peekaboo_pop", "Wash your hands clean in the bright bathroom.", "在明亮的洗手间把小手洗干净吧。"),
    "study": ("starlight_float", "I read picture books quietly in the study.", "我在书房里安安静静地读绘本。"),
    "garden": ("orbit_dance", "Butterflies visit our courtyard garden every day.", "蝴蝶每天都来拜访我们的庭院花园。"),
    "bed": ("starlight_float", "Tuck into your cozy bed for a peaceful sleep.", "钻进温暖小床睡个安稳好觉吧。"),
    "sofa": ("bounce_wave", "Sit on the cloud sofa and listen to music!", "坐在云朵沙发上听听音乐吧！"),
    "table": ("domino_cheer", "Set teacups and apple cake on the round table.", "把茶杯和苹果蛋糕摆上小圆桌吧。"),
    "window": ("peekaboo_pop", "Open the window to let in the morning breeze!", "推开窗户让清晨微风吹进来吧！"),
    "door": ("peekaboo_pop", "Knock gently on the wooden door and say hello.", "轻轻敲敲木门说声你好吧。"),
    "lamp": ("starlight_float", "The star floor lamp casts a golden glow.", "摘星落地灯洒下柔和的金光。"),
    "clock": ("orbit_dance", "The wall clock chimes softly at eight o'clock.", "墙上的挂钟在八点轻轻报时。"),
    "photo": ("peekaboo_pop", "We hung our first friend photo on the wall!", "我们把第一张伙伴合照挂上了墙！"),
    "picture": ("starlight_float", "Your hand-drawn picture brightens the whole room.", "你亲手画的画点亮了整个房间。"),
    "box": ("peekaboo_pop", "What treasure is hiding inside this wooden box?", "这个木匣子里藏着什么小宝贝呢？"),
    "gift": ("peekaboo_pop", "I wrapped a handmade gift for your birthday!", "我为你的生日包了一份手作礼物！"),
    "present": ("peekaboo_pop", "Open your birthday present with a big smile!", "带着大大的笑容拆开生日礼物吧！"),
    "card": ("bounce_wave", "Write a warm message on this greeting card.", "在这张贺卡上写下温暖祝福吧。"),
    "doll": ("peekaboo_pop", "The cloth doll sits neatly beside my pillow.", "布偶娃娃乖巧地坐在枕头边。"),
    "ball": ("bounce_wave", "Kick the colorful ball into the goal!", "把彩色皮球踢进大门里吧！"),
    "kite": ("starlight_float", "Our paper kite flies high above the green hill.", "我们的纸风筝在绿山丘高高飞翔。"),
    "toy": ("bounce_wave", "Put your wooden toys back on the shelf neatly.", "把木头玩具整整齐齐放回架子上吧。"),

    # Body Parts
    "body": ("bounce_wave", "Stretch your body in the morning sunshine!", "在晨光里舒展一下身体吧！"),
    "head": ("bounce_wave", "Nod your head and say yes with a smile!", "微笑着点点头说声好呀！"),
    "face": ("peekaboo_pop", "Wash your face with cool clear water.", "用清凉干净的水洗洗脸吧。"),
    "eye": ("peekaboo_pop", "Close your eyes and listen to the ocean waves.", "闭上眼睛听听温柔的海浪声。"),
    "eyes": ("peekaboo_pop", "Bright curious eyes spot treasures everywhere!", "明亮好奇的眼睛到处发现小宝藏！"),
    "ear": ("bounce_wave", "Rabbit ears perk up when music starts playing!", "音乐响起时兔耳朵竖起来啦！"),
    "nose": ("peekaboo_pop", "My nose smells Uncle Bear's fresh apple pie!", "我的鼻子闻到了熊叔刚烤好的苹果派！"),
    "mouth": ("bounce_wave", "Open your mouth and sing along happily!", "张开嘴巴开心地跟着唱吧！"),
    "hand": ("bounce_wave", "Wave your hand to greet our island neighbors!", "挥挥小手向岛上的邻居打招呼吧！"),
    "hands": ("domino_cheer", "Carry the ripe apple gently in both hands.", "用双手轻轻捧起熟透的红苹果。"),
    "arm": ("bounce_wave", "Open your arms for a warm friendly hug!", "张开双臂来一个温暖拥抱吧！"),
    "leg": ("domino_cheer", "Run across the playground on strong legs!", "迈开有力的双腿跑过操场吧！"),
    "foot": ("bounce_wave", "Tap your foot to the cheerful drum beat!", "跟着欢快的鼓点轻轻踏脚吧！"),
    "feet": ("bounce_wave", "Jump with both feet onto the stepping stone!", "双脚轻轻跳上花园汀步石吧！"),

    # Numbers, Time & Days
    "one": ("bounce_wave", "One little seed grows into a tall apple tree.", "一颗小种子长成高高的苹果树。"),
    "two": ("bounce_wave", "Two best friends share one big umbrella.", "两个好朋友共撑一把大大的雨伞。"),
    "three": ("domino_cheer", "Bring three red apples to Uncle Bear's bakery!", "带三颗红苹果去熊叔烘焙坊吧！"),
    "four": ("domino_cheer", "Four seasons paint our island in rich colors.", "四季把我们的小岛涂成丰富色彩。"),
    "five": ("domino_cheer", "High five! We finished our island quest!", "击个掌！我们完成了小岛心愿！"),
    "six": ("orbit_dance", "Six colorful lanterns glow along the dock.", "六盏彩灯沿着小码头亮起。"),
    "seven": ("starlight_float", "Seven rainbow colors arch across the sky.", "七道彩虹色横跨晴朗天空。"),
    "eight": ("orbit_dance", "School starts with stories at eight o'clock.", "八点钟学校伴随着故事开启。"),
    "nine": ("bounce_wave", "I am nine years old and love exploring!", "我今年九岁，最喜欢探索啦！"),
    "ten": ("domino_cheer", "Count from one to ten as stars appear!", "看着星星亮起，从一数到十吧！"),
    "time": ("orbit_dance", "It's time for afternoon tea in our courtyard!", "到我们小院的下午茶时间啦！"),
    "day": ("bounce_wave", "Every day on Alphabet Island brings a new wish.", "字母岛的每一天都有新心愿。"),
    "today": ("bounce_wave", "Today let's decorate our sunny living room!", "今天我们来装扮阳光客厅吧！"),
    "tomorrow": ("starlight_float", "Tomorrow ripe apples will grow again!", "明天果园里的红苹果又会成熟啦！"),
    "week": ("domino_cheer", "There are seven joyful days in every week.", "每个星期都有七个快乐的日子。"),
    "sunday": ("starlight_float", "On Sunday we have a picnic on the grass.", "星期天我们在草地上野餐。"),
    "monday": ("bounce_wave", "On Monday we greet our friends at school!", "星期一我们在学校向伙伴问好！"),
    "birthday": ("domino_cheer", "Light the candles on the sweet birthday cake!", "点亮香甜生日蛋糕上的蜡烛吧！"),

    # Places, Transport & Actions
    "park": ("orbit_dance", "Let's feed the ducks in the sunny park!", "我们去阳光公园喂小鸭子吧！"),
    "zoo": ("bounce_wave", "We saw pandas and giraffes at the zoo.", "我们在动物园看到了熊猫和长颈鹿。"),
    "shop": ("peekaboo_pop", "Pick a cute flowerpot at the village shop.", "在村口小店挑一只可爱的花盆吧。"),
    "cinema": ("starlight_float", "We watched an animated film at the cinema.", "我们在电影院看了一场动画电影。"),
    "hospital": ("bounce_wave", "The town hospital stands beside the quiet park.", "小镇医院坐落在安静的公园旁。"),
    "museum": ("peekaboo_pop", "Old sailing ships rest inside the island museum.", "古老的帆船陈列在小岛博物馆里。"),
    "post": ("domino_cheer", "Drop your painted postcard into the post box!", "把画好的明信片投进邮筒吧！"),
    "bus": ("domino_cheer", "The yellow school bus stops by the village gate.", "黄色校车停在村口大门旁。"),
    "car": ("orbit_dance", "A little toy car rolls down the wooden ramp.", "玩具小汽车顺着木坡滑下来。"),
    "train": ("domino_cheer", "Choo-choo! The toy train circles the rug!", "呜呜！玩具小火车绕着地毯转圈！"),
    "ship": ("starlight_float", "A white ship sails across the sparkling sea.", "白色轮船驶过波光粼粼的大海。"),
    "boat": ("orbit_dance", "Build a little wooden boat at Landmark B!", "在 B 船坞馆亲手拼一只小木船吧！"),
    "bike": ("orbit_dance", "Ride your bike along the breezy coastal road.", "沿着微风习习的海滨小路骑单车吧。"),
    "bicycle": ("orbit_dance", "My blue bicycle has a cheerful silver bell.", "我的蓝色自行车有一只清脆银铃铛。"),
    "plane": ("starlight_float", "Fold a paper plane and watch it glide!", "折一架纸飞机看它轻轻滑翔吧！"),
    "walk": ("bounce_wave", "Walk slowly and listen to the island birds.", "慢慢散步，听听小岛上的鸟鸣。"),
    "run": ("domino_cheer", "Run happily across the green football field!", "欢快地跑过绿茵茵的足球场吧！"),
    "jump": ("bounce_wave", "Jump up high and catch the floating bubble!", "高高跳起接住飘浮的彩色泡泡吧！"),
    "swim": ("orbit_dance", "Ducks swim gracefully in the cool pond.", "小鸭子在清凉池塘里优雅游水。"),
    "fly": ("starlight_float", "Colorful kites fly high in the spring wind.", "彩色风筝在春风里高高飞翔。"),
    "sing": ("orbit_dance", "Sing a gentle melody in the music room!", "在音乐教室唱一段温柔旋律吧！"),
    "dance": ("orbit_dance", "Watch the paper puppets dance on the page!", "看立体纸偶在书页上跳舞吧！"),
    "draw": ("peekaboo_pop", "Draw your favorite island corner on a card.", "把你最爱的小岛角落画在卡片上吧。"),
    "read": ("starlight_float", "Read one cozy story together before sleep.", "睡前一起读一个温暖的小故事吧。"),
    "write": ("domino_cheer", "Write your nickname on the welcome plaque.", "把你的昵称写在欢迎纪念牌上吧。"),
    "listen": ("starlight_float", "Listen closely to the gentle guitar music.", "静静聆听温柔的原声吉他曲吧。"),
    "speak": ("bounce_wave", "Speak out loud — every voice is wonderful here!", "大胆开口读出来，这里的每个声音都很棒！"),
    "look": ("peekaboo_pop", "Look! The pop-up letters just sprang upright!", "快看！立体字母纸偶刚刚弹起来啦！"),
    "play": ("bounce_wave", "Come play with your friends on Alphabet Island!", "快来字母岛和伙伴们一起玩吧！"),
    "love": ("starlight_float", "We love our warm home and island neighbors!", "我们热爱温馨的小家与海岛邻居！"),
    "like": ("bounce_wave", "I like sweet apples and sunny afternoons!", "我喜欢香甜的苹果和晴朗的午后！"),
}


def _smart_fallback(word: str, zh: str, kind: str) -> tuple[str, str, str]:
    clean_zh = zh.split("；")[0].split("（")[0].strip() or zh
    digest = hashlib.md5(word.encode("utf-8")).digest()
    dance = DANCE_STYLES[digest[0] % len(DANCE_STYLES)]

    if kind == "phrase" or " " in word.strip():
        en = f'Let\'s say "{word}" together with a warm smile!'
        zh_s = f"让我们带着温暖微笑，一起说出「{word}」（{clean_zh}）吧！"
        return ("domino_cheer", en, zh_s)

    if any(k in zh for k in ["吃", "果", "糕", "茶", "奶", "饭", "面", "菜", "糖", "肉", "汤", "饮"]):
        return ("bounce_wave", f'Would you like some "{word}" at our island cafe?', f"想在小岛餐台尝尝「{clean_zh}」吗？")
    if any(k in zh for k in ["猫", "狗", "鸟", "鱼", "兔", "熊", "象", "猴", "虎", "狮", "羊", "牛", "马", "虫", "蝶"]):
        return ("peekaboo_pop", f'Look! A friendly "{word}" is visiting our garden!', f"快看！可爱的「{clean_zh}」来拜访我们的花园啦！")
    if any(k in zh for k in ["春", "夏", "秋", "冬", "雨", "雪", "风", "云", "晴", "星", "月", "阳", "花", "树", "山", "海"]):
        return ("starlight_float", f'What a lovely "{word}" on Alphabet Island today!', f"今天字母岛上的「{clean_zh}」真美好呀！")
    if any(k in zh for k in ["衣", "裤", "裙", "鞋", "帽", "色", "红", "蓝", "黄", "绿"]):
        return ("orbit_dance", f'This "{word}" looks so cozy in our wardrobe!', f"这件「{clean_zh}」搭配在衣帽间里真好看！")

    return (
        dance,
        f'Let\'s remember "{word}" while exploring our cozy island!',
        f"在温暖小岛散步时，一起记住「{word}」（{clean_zh}）吧！",
    )


def main() -> int:
    t0 = time.perf_counter()
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    entries = catalog.get("entries", [])

    by_entry: dict[str, dict] = {}
    curated_count = 0
    unique_curated_sentences: set[str] = set()

    for entry in entries:
        eid = str(entry.get("entry_id", "")).strip()
        word = str(entry.get("spelling_display", "")).strip()
        zh = str(entry.get("meaning_zh", "")).strip()
        kind = str(entry.get("kind", "word")).strip()
        if not eid or not word:
            continue
        key = word.lower()
        if key == "orange" and "色" in zh:
            key = "orange_color"

        if key in CORE_WORDS:
            dance, ex_en, ex_zh = CORE_WORDS[key]
            curated = True
            curated_count += 1
            unique_curated_sentences.add(ex_en)
        else:
            dance, ex_en, ex_zh = _smart_fallback(word, zh, kind)
            curated = False

        by_entry[eid] = {
            "word": word,
            "dance_style": dance,
            "example_en": ex_en,
            "example_zh": ex_zh,
            "curated": curated,
        }

    # Pre-bake all curated example sentences into `.local/tts_cache/` via Piper ONNX!
    async def _bake_all(sentences: list[str]) -> int:
        done = 0
        for s in sentences:
            res = await synthesize_speech(s, "en", "storyteller")
            if res.get("ok"):
                done += 1
        return done

    baked = asyncio.run(_bake_all(sorted(unique_curated_sentences)))

    payload = {
        "schema_version": "popup-choreography-v4.5",
        "total_entries": len(by_entry),
        "curated_entries": curated_count,
        "curated_unique_words": len(CORE_WORDS),
        "dance_styles": DANCE_STYLES,
        "entries": by_entry,
    }
    OUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    elapsed = time.perf_counter() - t0
    print(
        f"[enrich_core_popup] Enriched {len(by_entry)} catalog entries "
        f"({curated_count} curated core occurrences, {baked} example sentences pre-baked) "
        f"in {elapsed:.1f}s -> {OUT_PATH}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
