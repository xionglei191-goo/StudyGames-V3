"""Build isolated art registry and per-step coverage without changing curriculum.

Source PNGs are copied byte-for-byte. Pillow is used for read-only alpha QA and
preview sheets only; runtime thumbnailing happens in Godot with bounded caches.
"""
from __future__ import annotations
import csv
import hashlib
import json
import re
import shutil
from collections import Counter
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/art/story_props_v3'
RUNTIME = ROOT / 'game/assets/learning/story_props_v3'
REGISTRY = ROOT / 'game/data/learning/story_prop_art.json'

# Specific nouns only. Words such as model, thing, toy, friend, colour, pattern,
# material, picture, work and shape NEVER assign an arbitrary pictured object.
KEYWORDS = {
 'backpack':'旅行包|书包|背包|晨间包', 'travel_journal':'旅行册|旅行本|笔记本|字典|词典|课本|故事书|相册|书本|一本书|把书|小书|午后书',
 'gift_box':'礼物盒|礼盒|礼物|礼包', 'cup':'咖啡杯|茶杯|水杯|薄杯|杯子|空杯|咖啡|一杯茶',
 'bowl':'面条碗|面条|面汤', 'blank_card':'名牌|名卡|身份卡|邀请卡|问候卡|名称卡|地址卡|标签|名签|字卡|词卡|卡片|纸卡|空白卡|句子卡|题卡|题目卡|问题卡|说明卡|通知卡|便条|纸片|小纸|一张纸|报纸|对联|剪纸',
 'picture_frame':'亲属照片|亲属照|全家合照|家庭合照|两家合照|家庭图|全员微笑照|合照|合影|相框|照片|头像|自拍|介绍照|亲属图|祖辈图',
 'wooden_box':'木箱|方箱|箱盖|箱内|带盖方箱|空箱|盒子|空盒|盒盖|文具盒|铅笔盒',
 'wood_log':'木头|木块|木料|木板|木纹|木截面', 'key':'钥匙',
 'banana':'香蕉', 'lemon':'柠檬', 'dog':'导盲犬|小狗|狗玩具|狗模型|幼犬|狗垫|狗爪|狗鼻|狗尾', 'cat':'小猫|猫爪|猫垫|猫模型',
 'pencil':'铅笔', 'paint_palette':'调色盘|颜料盘|颜料|颜色盘|棕色刷子|画笔|刷子',
 'flower_box':'花箱|花园材料|小花园', 'folded_map':'路线图|地图|街区图|街道图|导览图|路径图',
 'picnic_basket':'野餐篮|果篮|空篮|篮子|野餐包|野餐用品', 'shirt':'T形上衣|T恤|短袖',
 'sun':'太阳|日光|阳光|晴天', 'leaf':'叶子|叶片|叶下|叶形板|绿色叶板|叶脉|落叶',
 'science_flask':'烧瓶|实验瓶|试管', 'cottage':'房子|房屋|屋顶|小屋|家屋|家庭屋顶',
 'chair':'椅子|小椅|座椅|家庭椅', 'bed':'床架|小床|单人床|被子|床铺|枕头',
 'bottle':'瓶子|水瓶|小瓶|空瓶|饮料瓶|酸奶瓶', 'clock':'时钟|闹钟|钟面|钟针|钟表|表盘',
 'tree':'树苗|树木|树干|大树|小树|树冠|森林模型', 'fish':'金鱼|小鱼|鱼模型|鱼尾|鱼鳍',
 'cow':'奶牛|牛模型|牛鼻|牛蹄', 'dinosaur':'恐龙|背棘', 'duck':'鸭子|鸭形|小鸭',
 'goose':'白鹅|鹅形|鹅蛋|鹅模型|鹅下水', 'horse':'马背|马缰|马蹄|马模型|小马',
 'pig':'小猪|猪模型|猪鼻|猪尾', 'sheep':'绵羊|羊毛|小羊|羊模型', 'swan':'天鹅',
 'bear':'熊脚|熊鼻|熊爪|小熊|熊模型', 'bee':'蜜蜂|蜂翅|小蜂', 'elephant':'大象|象鼻|象耳|象模型',
 'kangaroo':'袋鼠', 'lion':'狮子|狮鬃|狮头', 'monkey':'猴子|猴尾|小猴', 'panda':'熊猫',
 'rabbit':'兔子|小兔|兔耳|兔模型', 'tiger':'老虎|虎纹|虎模型', 'parrot':'鹦鹉',
 'chicken':'玩具鸡|鸡脚|活鸡|小鸡|母鸡', 'ant':'蚂蚁', 'pear':'梨柄|梨皮|一只梨|洗梨|梨子',
 'orange':'橙子|橘子|柑橘|橙皮', 'watermelon':'西瓜', 'grapes':'葡萄', 'carrot':'胡萝卜',
 'potato':'土豆|马铃薯', 'strawberry':'草莓', 'tomato':'番茄|西红柿', 'bread':'面包',
 'rice_bowl':'干米|熟饭|米粒|米饭|一碗饭', 'dumpling':'饺子|水饺|汤圆', 'hamburger':'汉堡',
 'sandwich':'三明治', 'meat_plate':'鸡肉|肉块|肉盘|肉片|牛肉|猪肉|火腿',
 'candy':'糖果|糖块|糖纸', 'biscuit':'饼干', 'chocolate':'巧克力', 'pudding':'布丁',
 'milk_carton':'牛奶', 'mooncake':'月饼', 'shirt_button':'衬衫', 'coat':'外套|大衣|夹克',
 'dress':'连衣裙', 'shorts':'短裤', 'skirt':'半身裙|裙摆|裙子', 'trousers':'长裤|裤腿',
 'sweater':'毛衣', 'scarf':'围巾', 'shoe':'鞋子|鞋带|鞋底|鞋面|皮鞋',
 'sock':'袜子|短袜|袜口', 'bicycle':'自行车|车把|脚踏板|单车', 'bus':'公交车|公共汽车|公交',
 'car':'小汽车|汽车模型|轿车|出租车|的士', 'airplane':'飞机|机翼', 'camera':'相机|镜头',
 'computer':'电脑|计算机|键盘|屏幕', 'phone':'手机|电话', 'piano':'钢琴|黑白琴键|白键',
 'violin':'小提琴|琴弓', 'spoon':'勺子|木勺|小勺|匙|勺柄', 'plate':'餐盘|托盘|盘子|空盘|碟子|早餐盘',
 'eraser':'橡皮|黑板擦', 'ruler':'尺子|直尺|刻度尺', 'glue':'胶水|一滴胶',
 'candle':'蜡烛|烛火', 'bin':'垃圾桶|废纸篓', 'doll':'玩偶|布娃娃|玩具娃娃',
 'anatomy_model':'人体玩偶|身体模型|手臂模型|头模型|腿模型|脚模型|手模型|身体轮廓|膝关节|手指|脚印|手印|额头|下巴|脖子|颈部|手臂|身体',
 'ear_model':'耳朵|耳模型|耳边', 'eye_model':'眼睛|眼模型', 'mouth_model':'嘴巴|嘴模型|张开的嘴',
 'tooth':'牙齿|牙模型|一颗牙', 'cloud':'云朵|白云|云模型|阴天', 'moon':'月亮|月球',
 'rainbow':'彩虹', 'snowman':'雪人', 'dragon':'龙模型|龙身|长龙|舞龙', 'monster':'怪物',
 'great_wall':'长城|烽火台', 'eiffel_tower':'埃菲尔铁塔|铁塔模型', 'golden_gate_bridge':'金门大桥',
 'big_ben':'大本钟', 'space_station':'太空站|空间站|补给飞船|轨道站', 'basketball':'篮球',
 'badminton':'羽毛球', 'fan':'扇子|扇面|扇骨', 'glasses':'眼镜', 'pot':'烹饪锅|锅盖|小锅|汤锅',
 'bamboo':'竹子|竹竿|竹节|竹林', 'rose':'玫瑰', 'lotus':'莲花|荷花|莲叶|荷叶',
 'firecracker':'鞭炮|爆竹',
 'apple':'苹果', 'cake':'蛋糕', 'drum':'鼓面|鼓点|小鼓', 'egg_shell':'蛋壳|鸡蛋',
 'flower':'花束|花瓣|一朵花|祝福花', 'globe':'地球仪|地球模型|地球', 'hat':'帽子|帽檐|帽顶|软帽|生日帽',
 'ice_cream':'冰淇淋|冰激凌', 'jar':'果酱|蜂蜜罐|罐子|陶罐', 'kite':'风筝', 'lantern':'灯笼|灯光|提灯',
 'mushroom':'蘑菇', 'nest':'鸟巢|巢枝|空巢', 'owl':'猫头鹰', 'pumpkin':'南瓜',
 'quilt':'棉被|被角|被面', 'robot':'机器人', 'star':'星星|星光', 'train':'火车|车厢|小火车',
 'umbrella':'雨伞|伞面|伞柄', 'volcano':'火山', 'whale':'鲸鱼', 'xylophone':'木琴|琴板',
 'yarn':'毛线|线团|毛线球|细绳', 'zebra':'斑马', 'boat':'小船|船模型|帆船|船帆|船桨',
 'football':'足球|圆球|把球|接球|小球|传球|球从|球稳|球滑|球推|球弹|球抛',
 'greeting_door':'门板|木门|敲门|门口', 'greeting_window':'窗框|窗户|窗边|窗口',
 'reading_table':'桌子|书桌|茶桌|餐桌|桌面|阅读台', 'drumstick':'鼓槌|鼓棒'
}

# Exact main-object vocabulary supplies continuity only inside that object's story.
# A synonym family still has an explicit source object and runtime captions.
WORDS = {
 'backpack':'bag|schoolbag', 'travel_journal':'book|storybook|notebook|dictionary|textbook|story|fairy tale',
 'gift_box':'gift', 'cup':'cup|coffee|tea', 'bowl':'noodle|noodles', 'blank_card':'card|paper|note|notice|couplet|paper-cut',
 'picture_frame':'photo|picture', 'wooden_box':'box|pencil case', 'wood_log':'wood', 'key':'key', 'banana':'banana',
 'lemon':'lemon', 'dog':'dog|doggie|puppy|guide dog', 'cat':'cat', 'pencil':'pencil',
 'paint_palette':'', 'flower_box':'garden', 'folded_map':'map', 'picnic_basket':'picnic',
 'shirt':'T-shirt', 'sun':'the sun|sunny|sunshine', 'leaf':'leaf|leaves', 'science_flask':'',
 'cottage':'house|home', 'chair':'chair', 'bed':'bed', 'bottle':'bottle|glue bottle', 'clock':'clock|alarm clock',
 'tree':'tree|forest', 'fish':'fish|goldfish', 'cow':'cow', 'dinosaur':'dinosaur', 'duck':'duck', 'goose':'goose',
 'horse':'horse', 'pig':'pig', 'sheep':'sheep', 'swan':'swan', 'bear':'bear', 'bee':'bee', 'elephant':'elephant',
 'kangaroo':'kangaroo', 'lion':'lion|lion dance', 'monkey':'monkey', 'panda':'panda', 'rabbit':'rabbit',
 'tiger':'tiger', 'parrot':'parrot|bird', 'chicken':'chicken', 'ant':'ant', 'pear':'pear', 'orange':'orange',
 'watermelon':'watermelon', 'grapes':'grape', 'carrot':'carrot', 'potato':'potato', 'strawberry':'strawberry',
 'tomato':'tomato', 'bread':'bread', 'rice_bowl':'rice', 'dumpling':'dumpling', 'hamburger':'hamburger',
 'sandwich':'sandwich', 'meat_plate':'meat|beef|pork|ham', 'candy':'candy', 'biscuit':'biscuit',
 'chocolate':'chocolate', 'pudding':'pudding', 'milk_carton':'milk', 'mooncake':'mooncake',
 'shirt_button':'shirt', 'coat':'coat|jacket', 'dress':'dress', 'shorts':'shorts', 'skirt':'skirt',
 'trousers':'trousers', 'sweater':'sweater', 'scarf':'scarf', 'shoe':'shoe|shoes', 'sock':'sock|socks',
 'bicycle':'bike', 'bus':'bus', 'car':'car|taxi', 'airplane':'plane', 'camera':'take photos',
 'computer':'computer', 'phone':'phone|mobile phone', 'piano':'piano', 'violin':'violin', 'spoon':'spoon',
 'plate':'dish', 'eraser':'eraser', 'ruler':'ruler', 'glue':'glue', 'candle':'candle', 'bin':'bin', 'doll':'doll|body',
 'anatomy_model':'arm|hand|head|leg|foot|feet|face|neck', 'ear_model':'ear', 'eye_model':'eye', 'mouth_model':'mouth',
 'tooth':'tooth|teeth', 'cloud':'cloud|cloudy', 'moon':'the moon', 'rainbow':'rainbow', 'snowman':'snowman',
 'dragon':'dragon', 'monster':'monster', 'great_wall':'the Great Wall', 'eiffel_tower':'the Eiffel Tower',
 'golden_gate_bridge':'the Golden Gate Bridge', 'big_ben':'Big Ben', 'space_station':'space station',
 'basketball':'basketball', 'badminton':'badminton', 'fan':'fan', 'glasses':'glasses', 'pot':'pot',
 'bamboo':'bamboo', 'rose':'rose', 'lotus':'lotus', 'firecracker':'firecracker', 'apple':'apple', 'cake':'cake',
 'egg_shell':'egg', 'flower':'flower', 'globe':'Earth|world', 'hat':'hat', 'ice_cream':'ice cream', 'jar':'jar|pot',
 'kite':'kite', 'lantern':'lantern|light', 'mushroom':'mushroom', 'nest':'nest', 'owl':'owl', 'pumpkin':'pumpkin',
 'quilt':'quilt', 'robot':'robot', 'star':'star', 'train':'train|underground', 'umbrella':'umbrella',
 'volcano':'volcano', 'whale':'whale', 'xylophone':'xylophone', 'yarn':'string|line', 'zebra':'zebra', 'boat':'boat|ship',
 'football':'ball|football', 'greeting_door':'door', 'greeting_window':'window', 'reading_table':'table|desk'
}

KEYWORDS.update({
 'beach':'沙滩|海滩|沙质|沙地', 'bean':'豆子|豆粒|豆荚', 'tin_can':'铁罐|罐头|易拉罐|饮料罐',
 'chess':'国际象棋|象棋|棋子|棋盘', 'chips':'薯条', 'clay':'黏土|泥团|泥土', 'flame':'火焰|火苗|火堆',
 'glass':'玻璃杯', 'hair':'头发|发丝|假发', 'ice_cube':'冰块', 'jeans':'牛仔裤', 'raincoat':'雨衣',
 'river_stream':'河道|河流|小河|河槽|长河|河岸', 'lake':'湖水|湖面|湖泊|小湖|池子|池塘|水池|泳池',
 'sea_wave':'海水|海浪|大海|海洋', 'seed':'种子', 'snowflake':'雪花|积雪|白雪', 'swimwear':'游泳衣|泳衣',
 'tap':'水龙头|龙头开关', 'water_drop':'水滴|一滴水|水流', 'rain_cloud':'雨滴|雨点|下雨|雨水',
 'mountain':'山峰|高山|山脉|山模型|小山|山坡', 'pen':'钢笔|笔尖|笔帽', 'television':'电视机|电视屏|电视',
 'turkey':'火鸡', 'pingpong':'乒乓球', 'cap':'鸭舌帽|棒球帽|帽舌'
})
WORDS.update({
 'beach':'beach', 'bean':'bean', 'tin_can':'can', 'chess':'chess', 'chips':'chip|chips', 'clay':'clay',
 'flame':'fire|on fire', 'glass':'glass', 'hair':'hair', 'ice_cube':'ice', 'jeans':'jeans', 'raincoat':'raincoat',
 'river_stream':'river', 'lake':'lake|pool', 'sea_wave':'sea', 'seed':'seed', 'snowflake':'snow|snowy',
 'swimwear':'swimwear', 'tap':'tap', 'water_drop':'water', 'rain_cloud':'rain|rainy', 'mountain':'mountain|hill',
 'pen':'pen', 'television':'TV', 'turkey':'turkey', 'pingpong':'ping-pong', 'cap':'cap'
})
KEYWORDS.update({
 'seashell':'贝壳', 'flowerpot':'花盆|两盆对照|植株|盆栽', 'bookshelf':'书架', 'mirror':'镜子|小镜|镜面',
 'tablecloth':'桌布|餐布', 'thermometer':'温度计', 'sofa':'沙发', 'blocks':'积木', 'hourglass':'沙漏',
 'envelope':'信封', 'balloon':'气球', 'blackboard':'黑板|粉笔字|粉笔点|全板', 'cola':'可乐',
 'grass_patch':'草地|草坪|草皮|青草', 'wall_section':'墙壁|墙体|砖墙|墙面|作品墙|墙段',
 'feather':'羽毛|羽形板', 'garland':'花环', 'mask':'面具', 'paper_cup':'纸杯|蛋筒',
 'staircase':'台阶|阶梯|楼梯', 'towel':'毛巾', 'wheel':'车轮|轮子', 'balance_scale':'天平|秤盘|秤砣|山坡秤',
 'wristwatch':'表带|腕表', 'steamship':'轮船|汽笛船|客轮'
})
WORDS.update({'seashell':'shell','flowerpot':'plant','bookshelf':'bookshelf','mirror':'mirror',
 'tablecloth':'tablecloth','thermometer':'thermometer','sofa':'sofa','blocks':'blocks','hourglass':'hourglass',
 'envelope':'envelope','balloon':'balloon','blackboard':'blackboard','cola':'cola','grass_patch':'grass',
 'wall_section':'wall','feather':'feather','garland':'garland','mask':'mask','paper_cup':'paper cup',
 'staircase':'step','towel':'towel','wheel':'wheel','balance_scale':'scale','wristwatch':'watch','steamship':'ship'})
WORDS['pot']=''
WORDS['boat']='boat'
KEYWORDS.update({'subway':'地铁','lion_dance':'舞狮|狮头套','bead':'珠子|颗珠|八珠|六珠|十珠','button':'纽扣|按钮','counting_stick':'根棒|捆棒|十根棒','toothbrush':'牙刷|湿刷毛','paint_brush':'画笔|一把刷子|刷毛|刷柄','juice_glass':'果汁|滴汁'})
KEYWORDS['paint_palette']='调色盘|颜料盘|颜料|颜色盘'
KEYWORDS['blank_card']+='|徽章|小旗|图卡|资料|文件夹'
WORDS.update({'subway':'underground|subway','lion_dance':'lion dance','juice_glass':'juice'})
WORDS['lion']='lion'
WORDS['train']='train'
KEYWORDS['car']+='|玩具车|小车'
KEYWORDS['balance_scale']+='|秤臂|称重台'
NUMBER_STORIES = {
 'one':('button',[1,1,1]), 'two':('cup',[2,2,2]), 'three':('apple',[3,3,3,3,3]),
 'four':('button',[4,4,4,4]), 'five':('seashell',[5,5,5,5]), 'six':('bead',[6,6,6]),
 'seven':('button',[0,7,7,7,7]), 'eight':('bead',[8,8,8,8,8]), 'nine':('seed',[9,9,9,9]),
 'ten':('football',[10,10,10]), 'eleven':('bead',[10,10,11,11,11,11]),
 'twelve':('bead',[10,2,12,10,2,12]), 'twenty':('bead',[10,10,10,10,20,20]),
 'thirteen':('bead',[10,3,13,13,13,10,3,13]), 'fourteen':('bead',[10,4,14,14,14,10,4,14]),
 'fifteen':('bead',[10,5,15,15,10,5,15]), 'sixteen':('bead',[10,6,6,16,10,6,16]),
 'seventeen':('bead',[10,7,17,17,10,17,7,17,17]), 'eighteen':('bead',[10,8,18,8,18,10,8,18]),
 'nineteen':('bead',[10,9,19,19,19,10,9,19]),
 'thirty':('counting_stick',[10,10,10,30,30,30]),
 'forty':('counting_stick',[10,10,10,10,40]), 'fifty':('counting_stick',[10,10,10,10,50])}
LETTER_REUSE = dict(zip(['apple','boat','cake','drum','egg_shell','flower','globe','hat','ice_cream','jar','kite','lantern','mushroom','nest','owl','pumpkin','quilt','robot','star','train','umbrella','volcano','whale','xylophone','yarn','zebra'],'ABCDEFGHIJKLMNOPQRSTUVWXYZ'))
UI_ART = {'apple':'apple','cake':'cake','bag':'backpack','journal':'travel_journal','flower_box':'flower_box','home':'cottage','map':'folded_map','picnic':'picnic_basket','science':'science_flask','art':'paint_palette','music':'xylophone','outfit':'shirt','sun':'sun','leaf':'leaf','lamp':'lantern','football':'football'}
SPECIAL = {'hello','nose','book','football'}
TEXT_MATERIALS = {'blank_card','picture_frame'}
# These need custom objects; they must never silently count as abstract completion.
KNOWN_MISSING_WORDS = set('jeans|raincoat|swimwear|glass|hair|chess|fire|river|lake|sea|beach|hill|mountain|snow|rain|water|biscuit|chip|chips|seed|bean|ice|can|clay|pudding|pot|tap'.split('|'))
PLACE_WORDS = set('school|library|museum|factory|shop|hospital|village|town|city|country|China|Australia|London|New York|bathroom|bedroom|classroom|canteen|kitchen|living room|office|reading room|playground|park|community|hometown|street|road|airport|bank|bookstore|bus stop|café|cinema|hotel|inn|police station|post office|primary school|railway station|restaurant|shopping centre|supermarket|station|stop|theatre|college|building|zoo|the West Lake|Tian\'anmen Square|Shibadong Village'.split('|'))
NON_OBJECT_MEANINGS = ('能够','不能','能；','能；会','迷','点燃','点亮','线；','线','观看','画画','刷','咖啡','颜色','色；','色的')

def sha(path: Path) -> str:
 return hashlib.sha256(path.read_bytes()).hexdigest()

def inspect_png(path: Path) -> dict:
 with Image.open(path) as image:
  rgba=image.convert('RGBA'); alpha=rgba.getchannel('A'); bbox=alpha.point(lambda x:255 if x>=128 else 0).getbbox()
  if not bbox: raise ValueError(f'No visible alpha in {path}')
  w,h=rgba.size; x0,y0,x1,y1=bbox
  corners=[alpha.getpixel(p) for p in [(0,0),(w-1,0),(0,h-1),(w-1,h-1)]]
  return {'size':[w,h],'mode':image.mode,'alpha_bbox':list(bbox),'region':[x0/w,y0/h,(x1-x0)/w,(y1-y0)/h],'corner_alpha':corners,'sha256':sha(path),'bytes':path.stat().st_size,'warnings':(['opaque_corner'] if max(corners)>5 else [])}

def make_assets() -> dict:
 plan=json.loads((ART/'production_plan.json').read_text(encoding='utf-8'))
 records={a['id']:a for a in json.loads((ART/'generation_records.json').read_text(encoding='utf-8'))['assets']}
 root_plan=ART/'root_batch_plan.json';root_records=ART/'root_generation_records.json'
 if root_plan.exists():plan['jobs']+=json.loads(root_plan.read_text(encoding='utf-8'))['jobs']
 if root_records.exists():records.update({a['id']:a for a in json.loads(root_records.read_text(encoding='utf-8'))['assets']})
 world_plan=ART/'world_extra_plan.json';world_records=ART/'world_extra_generation_records.json'
 if world_plan.exists():plan['jobs']+=json.loads(world_plan.read_text(encoding='utf-8'))['jobs']
 if world_records.exists():records.update({a['id']:a for a in json.loads(world_records.read_text(encoding='utf-8'))['assets']})
 corrections=ART/'correction_generation_records.json'
 if corrections.exists():records.update({a['id']:a for a in json.loads(corrections.read_text(encoding='utf-8'))['assets']})
 assets={}; RUNTIME.mkdir(parents=True,exist_ok=True); (ART/'source').mkdir(exist_ok=True)
 for job in plan['jobs']:
  aid=job['id']; rec=records.get(aid,{'status':'pending'}); source=ART/'source'/f'{aid}.png'; runtime=RUNTIME/f'{aid}.png'
  item={'id':aid,'path':f'res://assets/learning/story_props_v3/{aid}.png','source':str(source.relative_to(ROOT)).replace('\\','/'),'origin':'built-in image_gen','prompt':job['prompt'],'status':'pending_generation','keywords':KEYWORDS.get(aid,'').split('|')}
  if rec['status']=='generated':
   if not source.exists() or (rec.get('rejected_sources') and sha(source)!=sha(Path(rec['generated_source']))): shutil.copy2(rec['generated_source'],source)
   if not runtime.exists() or sha(runtime)!=sha(source): shutil.copy2(source,runtime)
   item.update(inspect_png(source)); item['status']='available';item['generated_source']=rec['generated_source']
   if rec.get('prompt'):item['prompt']=rec['prompt']
   if rec.get('runtime_parts'):item['runtime_parts']=rec['runtime_parts']
   if rec.get('rejected_sources'):item['rejected_sources']=rec['rejected_sources']
  assets[aid]=item
 v2=json.loads((ROOT/'assets/art/storybook_v2/manifest.json').read_text(encoding='utf-8'))
 by_id={a['id']:a for a in v2['assets']}
 for aid,letter in LETTER_REUSE.items():
  original=by_id[letter]; path=ROOT/original['runtime_path']; qa=inspect_png(path)
  assets[aid]={'id':aid,'path':'res://'+original['runtime_path'].removeprefix('game/'),'origin':'reused_accepted_storybook_v2_letter','source_letter':letter,'status':'available','keywords':KEYWORDS.get(aid,'').split('|'),**qa}
 for aid in v2['props']:
  original=by_id[aid]; path=ROOT/original['runtime_path']; qa=inspect_png(path)
  assets[aid]={'id':aid,'path':'res://'+original['runtime_path'].removeprefix('game/'),'origin':'reused_accepted_storybook_v2_prop','status':'available','keywords':KEYWORDS.get(aid,'').split('|'),**qa}
 return assets

def resolve_story(entry: dict,story: dict,assets: dict) -> dict:
 word=entry['spelling_display']; meaning=entry['meaning_zh']; main=''
 for aid,words in WORDS.items():
  if word in words.split('|'): main=aid;break
 if word=='fan' and '迷' in meaning: main=''
 if word=='light' and ('点燃' in meaning or '点亮' in meaning): main=''
 if word=='orange' and '橙子' not in meaning:main=''
 if word=='watch' and '手表' not in meaning:main=''
 if word=='can' and '罐' not in meaning:main=''
 if word=='glasses' and '眼镜' not in meaning:main=''
 if word=='face' and '脸' not in meaning:main=''
 if word=='brush':main='toothbrush' if meaning=='刷' else 'paint_brush'
 result=[];previous='';unique=[]
 for i,step in enumerate(story['steps']):
  action=step['action']; anchor=step.get('anchor_zh',''); source=action
  # Named mnemonic actors at the head of a sentence are not the carried prop.
  if anchor:source=re.sub(r'^(?:第[一二三四五六七八九十0-9]+[只朵列个颗枚根]*)?'+re.escape(anchor),'',source)
  actor_id=next((aid for aid,letter in LETTER_REUSE.items() if letter==step.get('letter')),'')
  matches=[]
  for aid,terms in KEYWORDS.items():
   for keyword in terms.split('|'):
    if keyword and keyword in source:
     if aid==actor_id and aid!=main:continue
     if keyword=='手指' and re.search(r'手指[出向着明给]',source):continue
     if aid=='football' and re.search(r'(把|接|传|小|圆)?球[队场赛迷类]',source):continue
     # Actor-only verbs remain an actor animation; don't duplicate its sprite.
     if keyword==anchor and len(source)<=len(keyword)+3:continue
     matches.append((len(keyword)+(1 if aid==main else 0),source.find(keyword),aid,keyword))
  # An explicit object-story referent outranks a secondary actor part.
  matches.sort(key=lambda x:(0 if x[2]==main else 1,-x[0],x[1]))
  prop='';keyword='';status='abstract_runtime_text'
  if word in SPECIAL:status='specialized_v2'
  elif matches:
   _,_,prop,keyword=matches[0];status='text_surface' if prop in TEXT_MATERIALS else 'concrete_asset'
  elif main:
   prop=main;keyword='exact_object_story_continuity';status='text_surface' if prop in TEXT_MATERIALS else 'concrete_asset'
  elif previous and re.search(r'^(接过|接住|托住|递给|放回|放好|扶正|打开|合上|盖好|收走|转动|整理|展示|照亮|举起|挂起|尝后|洗净|擦亮|指出|将它|把它|它)',source):
   prop=previous;keyword='previous_explicit_prop_continuity';status='text_surface' if prop in TEXT_MATERIALS else 'concrete_asset'
  elif word in KNOWN_MISSING_WORDS and not (word=='can' and '罐' not in meaning):status='missing_concrete_art'
  elif word in PLACE_WORDS:status='location_runtime_text'
  quantity={}
  if word in NUMBER_STORIES:
   prop,counts=NUMBER_STORIES[word];count=counts[min(i,len(counts)-1)]
   status='concrete_asset';keyword='reviewed_cardinal_story_step'
   quantity={'count':count,'rows':0,'columns':0,'group_size':10 if prop=='counting_stick' else 0}
   if word=='eight' and i==1:quantity.update(rows=2,columns=4)
   if word=='nine' and i==1:quantity.update(rows=3,columns=3)
   if word=='seven' and i==0:quantity['empty_slots']=7
  if word=='brush':prop=main;status='concrete_asset';keyword='exact_brush_sense'
  if word=='juice' and i>=2:prop='juice_glass';status='concrete_asset';keyword='exact_juice_continuity'
  if prop:
   previous=prop
   if prop not in unique:unique.append(prop)
   if assets.get(prop,{}).get('status')!='available':status='pending_asset'
  result.append({'position':i+1,'prop_id':prop,'status':status,'source_action':action,'match':keyword,'label':meaning if prop in TEXT_MATERIALS else '',**quantity})
 return {'word':word,'meaning_zh':meaning,'main_prop_id':main,'prop_ids':unique,'steps':result,'status':'missing_concrete_art' if any(x['status']=='missing_concrete_art' for x in result) else ('pending_asset' if any(x['status']=='pending_asset' for x in result) else 'covered')}

def main() -> None:
 assets=make_assets();catalog=json.loads((ROOT/'game/data/learning/catalog.json').read_text(encoding='utf-8'))
 stories={};coverage=[];fixtures={}
 for e in catalog['entries']:
  sid=e['story_id']
  if sid not in stories:stories[sid]=resolve_story(e,catalog['stories'][sid],assets)
  info=stories[sid]
  coverage.append({'entry_id':e['entry_id'],'story_id':sid,'word':e['spelling_display'],'meaning_zh':e['meaning_zh'],'status':info['status'],'prop_ids':'|'.join(info['prop_ids']),'step_statuses':'|'.join(x['status'] for x in info['steps'])})
  for step in info['steps']:
   aid=step['prop_id']
   if aid and aid not in fixtures:fixtures[aid]={'entry_id':e['entry_id'],'word':e['spelling_display'],'position':step['position'],'source_action':step['source_action'],'match':step['match']}
 registry={'schema_version':1,'art_revision':'story-props-v3','catalog_sha256':sha(ROOT/'game/data/learning/catalog.json'),'texture_policy':{'lazy':True,'max_cached_per_stage':12,'max_raster_edge':256,'source_pixels_unchanged':True},'assets':{k:{x:v for x,v in a.items() if x in ['id','path','region','status','origin','runtime_parts']} for k,a in assets.items()},'stories':stories,'ui_art':UI_ART,'fixtures':fixtures}
 REGISTRY.write_text(json.dumps(registry,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
 ui_root=ROOT/'game/assets/ui/illustrations';ui_root.mkdir(parents=True,exist_ok=True);ui_manifest={'schema_version':1,'art_revision':'story-props-v3','icons':{}}
 for icon_id,aid in UI_ART.items():
  asset=assets[aid]
  if asset['status']!='available':continue
  source=ROOT/'game'/asset['path'].removeprefix('res://');target=ui_root/f'{icon_id}.png'
  if not target.exists() or sha(target)!=sha(source):shutil.copy2(source,target)
  ui_manifest['icons'][icon_id]={'prop_id':aid,'path':f'res://assets/ui/illustrations/{icon_id}.png','region':asset['region'],'sha256':sha(target),'source_path':asset['path']}
 (ui_root/'manifest.json').write_text(json.dumps(ui_manifest,ensure_ascii=False,indent=2),encoding='utf-8')
 with (ART/'coverage.csv').open('w',encoding='utf-8-sig',newline='') as f:
  writer=csv.DictWriter(f,fieldnames=list(coverage[0]));writer.writeheader();writer.writerows(coverage)
 missing=[x for x in coverage if x['status']=='missing_concrete_art']
 manifest={'schema_version':1,'art_revision':'story-props-v3','status':'awaiting_runtime_validation','generator':'built-in image_gen','reference':'assets/art/storybook_v1/source/style-board.png','source_policy':'Original PNGs copied without pixel edits; runtime thumbnails are generated lazily by Godot. Existing v2 letter and prop source files are unchanged.','semantic_policy':'Longest explicit concrete noun matches; exact object stories can retain the same prop across pronoun/continuation actions. Runtime words and numbers never baked into images. Abstract and geographic labels remain text.','registry':'game/data/learning/story_prop_art.json','assets':list(assets.values()),'ui_art':UI_ART,'coverage_summary':{'entries':len(coverage),'stories':len(stories),'entry_statuses':dict(Counter(x['status'] for x in coverage)),'step_statuses':dict(Counter(step['status'] for story in stories.values() for step in story['steps'])),'registered_assets':len(assets),'available_assets':sum(x['status']=='available' for x in assets.values()),'unused_asset_ids':[a for a in assets if a not in fixtures and a not in UI_ART.values()]},'missing_concrete_records':missing,'fixtures':fixtures}
 (ART/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps(manifest['coverage_summary'],ensure_ascii=False))
 print('missing concrete words:',sorted(set(x['word'] for x in missing)))

if __name__=='__main__':main()
