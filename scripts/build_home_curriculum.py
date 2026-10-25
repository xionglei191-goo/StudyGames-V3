"""Build the household's source-backed spatial catalogue from the read-only books.

The room arrangement and hands-on activities are original game design. Textbook
quotes retain book, unit, printed/file page and region, without inferring mastery.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = Path('D:/Project/Englishbook/public')
OUT = ROOT / 'docs/planning/home-hierarchy'
G3A, G3B, G4A, G4B = [f'xiangshao-g{g}-{v}' for g, v in [(3, 1), (3, 2), (4, 1), (4, 2)]]
G5A, G5B, G6A, G6B = 'english-grade5-volume1-smartedu-2022', 'xiangshao-g5-2', 'xiangshao-g6-1', 'xiangshao-g6-2'
BOOKS = {bid: json.loads((LIBRARY / 'books' / (bid + '.json')).read_text('utf-8')) for bid in [G3A, G3B, G4A, G4B, G5A, G5B, G6A, G6B]}


def save(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def source(bid: str, unit: int, page: int, region: str, expected: str) -> dict:
    book = BOOKS[bid]
    chapter = next(c for c in book['chapters'] if c['id'] == f'unit-{unit}')
    p = next(p for p in book['pages'] if p['id'] == page)
    r = next(r for r in p['regions'] if r['id'] == region)
    assert chapter['start'] <= page <= chapter['end'], (bid, page, unit)
    assert r['text'] == expected, (bid, region, r['text'], expected)
    result = {'book_id': bid, 'book_title': book['title'], 'unit_id': chapter['id'],
              'unit_title': chapter['title'], 'printed_page': p['printedPage'],
              'file_page': page, 'region_id': region, 'text': r['text'],
              'image': str(LIBRARY / p['image'].lstrip('/')), 'manifest_verified': True,
              'page_visually_reviewed': (bid, page) in [(G4A, 58), (G4A, 59), (G5A, 49)]}
    audio = LIBRARY / r.get('audio', '').lstrip('/')
    if r.get('audio') and audio.is_file():
        name = f'{bid}-{region}.mp3'
        target = ROOT / 'game/assets/audio/home' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(audio, target)
        result['audio'] = 'res://assets/audio/home/' + name
        result['audio_kind'] = 'existing_cached_synthetic_speech'
        result['audio_source_sha256'] = hashlib.sha256(audio.read_bytes()).hexdigest()
    return result


def a(label, description, bid, unit, page, region, text):
    return {'label': label, 'activity': description, 'source': source(bid, unit, page, region, text)}


def task(id, anchor, title, steps, result):
    return {'id': id, 'anchor': anchor, 'title': title, 'steps': steps, 'result': result,
            'kind': 'authored_household_action', 'records': 'experience_only_no_language_grade'}


def main():
    rooms = [
        {'room_id': 'home_estate', 'name': '我的家 · 小院与住宅', 'english_word': 'Home', 'scene_level': 2,
         'parent_room': 'village', 'theme': '穿过石径与花园，走到住宅正门；进屋后沿门厅与走廊，走到各个房间。',
         'composition': '完整的三体量住宅外观，坡屋顶、凹入门窗、石基座和木门廊面向小院；正门进入可行走的室内门厅，七扇房门连接各自生活空间。',
         'vocabulary_status': 'home is textbook vocabulary; courtyard and floor plan are original spatial design',
         'camera_size': 40.0,
         'anchors': [
             a('门前信箱', '读一张邀请卡，想想怎样欢迎来访的朋友。', G4A, 9, 58, 'p58-r7', 'Welcome to my home!'),
             a('小院花圃', '拿起水壶，为花圃浇水，再把水壶放回去。', G5A, 7, 49, 'p49-r9', 'water the plants'),
             a('门廊随身篮', '外出前整理随身物品，准备与家人一起散步。', G6B, 1, 9, 'p9-r3', 'do things together'),
             a('家庭日程板', '看看日程板，选择今天先去哪个房间。', G6A, 2, 13, 'p13-r11', 'Her family often has breakfast at 7:30 a.m.'),
             a('门廊小树', '观察小树怎样给门廊遮阴，照顾它慢慢长大。', G6B, 4, 25, 'p25-r11', 'I will water the young trees every day.'),
         ], 'task': task('water_garden', 2, '照顾小院花圃', ['拿起小水壶', '沿花盆慢慢浇水', '把水壶放回架上'], '花圃已经浇过水了。下次回来还可以看看它。')},
        {'room_id': 'home', 'name': '家里的客厅', 'english_word': 'Living room', 'scene_level': 3,
         'parent_room': 'home_estate', 'theme': '在沙发与茶几旁招待朋友，用家人相册和纪念架留住共同的生活。',
         'composition': '保留旧客厅的五个固定记忆位置、旅行册与朋友角；床角改为窗边阅读角，卧床移到独立卧室。',
         'vocabulary_status': 'direct_room_name', 'camera_size': 23.0,
         'anchors': [
             a('门厅随身篮', '欢迎朋友进来，把带来的物品放在门厅。', G4A, 9, 58, 'p58-r8', 'Come in, please.'),
             a('左侧衣柜', '在进门处挂好外套，也可以继续布置客厅。', G3B, 4, 29, 'p29-r16', "I like the red and white dress. It's beautiful."),
             a('中央茶几', '摆好茶杯与点心，和朋友介绍自己的家。', G4A, 9, 59, 'p59-r8', 'This is our living room.'),
             a('窗边家人相册', '看看相册，用照片介绍家人；晚上去卧室休息。', G3A, 4, 29, 'p29-r9', "She's my mother."),
             a('出口回忆展示架', '把合照与礼物放回纪念架，回想家人和朋友相聚的日子。', G6A, 10, 63, 'p63-r17', 'Festivals bring families together.'),
         ], 'task': task('welcome_table', 3, '为来访朋友摆好茶几', ['铺好小桌垫', '摆好两个杯子', '把果盘放到中间'], '茶几准备好了，可以邀请朋友坐下。')},
        {'room_id': 'home_bedroom', 'name': '温暖卧室', 'english_word': 'Bedroom', 'scene_level': 3,
         'parent_room': 'home_estate', 'theme': '起床、整理床铺、挑选衣服、收拾书包与睡前阅读，各有固定位置。',
         'vocabulary_status': 'direct_room_name', 'camera_size': 23.0,
         'anchors': [
             a('床边与被子', '把被子铺好，再摆正枕头。', G5A, 7, 49, 'p49-r4', 'make the bed'),
             a('床头小闹钟', '看一看起床时间，讲讲自己的早晨。', G4A, 2, 13, 'p13-r11', 'Hmm... I get up at 7:00.'),
             a('穿衣镜与衣柜', '选择今天喜欢的衣服，看看颜色。', G3B, 4, 29, 'p29-r2', 'Do you like the dress?'),
             a('书包收纳凳', '找找铅笔盒，把物品放回书包里。', G4B, 1, 8, 'p8-r10', "It's in your schoolbag."),
             a('床头阅读灯', '读一会儿书，再去休息；可以睡到游戏中的第二天。', G4A, 2, 14, 'p14-r9', 'go to bed'),
         ], 'task': task('make_bed', 1, '整理自己的床铺', ['把被子展开', '把枕头摆整齐', '轻轻抚平被角'], '床铺变得整齐了。')},
        {'room_id': 'home_kitchen', 'name': '明亮厨房', 'english_word': 'Kitchen', 'scene_level': 3,
         'parent_room': 'home_estate', 'theme': '从食材柜到洗菜池、备餐台和灶台，体验准备一餐的顺序。',
         'vocabulary_status': 'direct_room_name', 'camera_size': 23.0,
         'anchors': [
             a('食材储物柜', '认识米饭、鱼和蔬菜，挑选今天的食材。', G4A, 3, 18, 'p18-r12', 'I like rice, fish and vegetables.'),
             a('洗菜池', '将蔬菜放入水槽，洗净后放回篮子。', G5A, 7, 49, 'p49-r5', 'wash the vegetables'),
             a('灶台与汤锅', '看一看做饭的工具，和家人一起准备一餐。', G5A, 7, 49, 'p49-r6', 'cook a meal'),
             a('备餐操作台', '介绍厨房，观察台面上准备好的物品。', G4A, 9, 58, 'p58-r13', 'This is the kitchen.'),
             a('餐具收纳架', '用过的餐具归位，保持厨房干净。', G4A, 9, 58, 'p58-r15', "It's clean."),
         ], 'task': task('wash_vegetables', 2, '帮忙洗好蔬菜', ['把蔬菜放进洗菜池', '轻轻冲洗叶片', '关水并装入菜篮'], '蔬菜洗好了，可以送到备餐台。')},
        {'room_id': 'home_dining', 'name': '家庭餐厅', 'english_word': 'Dining area', 'scene_level': 3,
         'parent_room': 'home_estate', 'theme': '围着一张家庭餐桌吃早餐、表达食物喜好、庆祝生日和节日。',
         'vocabulary_status': 'authored_functional_space_for_textbook_meals', 'camera_size': 23.0,
         'anchors': [
             a('早餐边柜', '看时钟准备早餐，讲讲自己的早餐时间。', G4A, 2, 14, 'p14-r3', 'I have breakfast at half past seven.'),
             a('水果分享台', '看看水果，说说自己喜欢哪一种。', G3A, 9, 58, 'p58-r8', 'Thanks! I like apples.'),
             a('家庭餐桌', '为家人摆好餐盘，再一起吃饭。', G3B, 7, 48, 'p48-r11', 'Dinner is ready.'),
             a('生日点心桌', '摆放生日蛋糕和贺卡，向家人送上祝福。', G3A, 10, 64, 'p64-r2', 'Happy birthday! Here is a gift for you.'),
             a('节日餐边架', '观察节日餐具，聊聊一家人团聚的晚餐。', G6A, 10, 63, 'p63-r15', 'And we usually have a big family dinner.'),
         ], 'task': task('set_dinner', 3, '一起摆好餐桌', ['把餐垫摆好', '给每个座位放餐盘', '把杯子放到餐盘旁'], '四个座位都摆好了，可以叫家人来吃饭。')},
        {'room_id': 'home_bathroom', 'name': '清爽浴室', 'english_word': 'Bathroom', 'scene_level': 3,
         'parent_room': 'home_estate', 'theme': '洗手池、牙刷杯、浴缸、毛巾架与卫生间分区，练习日常清洁与节水。',
         'vocabulary_status': 'direct_room_name', 'camera_size': 23.0,
         'anchors': [
             a('牙刷杯与镜子', '认识牙刷与牙齿，跟着句子做刷牙动作。', G3B, 7, 48, 'p48-r18', 'Dongdong, brush your teeth.'),
             a('洗手池', '打开水龙头洗手，用完记得关好。', G3B, 7, 48, 'p48-r8', 'Dongdong, come and wash your hands.'),
             a('浴缸与花洒', '认识浴室，想想每天怎样保持身体清洁。', G6B, 3, 17, 'p17-r2', 'keep our body clean'),
             a('毛巾收纳架', '洗过脸后，把毛巾挂回原位。', G3B, 7, 48, 'p48-r17', 'Wash your face.'),
             a('节水提示与卫生间', '检查水龙头已经关闭，养成节约用水的习惯。', G6A, 7, 48, 'p48-r9', 'Turn off the tap please.'),
         ], 'task': task('wash_hands', 2, '洗手后关好水龙头', ['打开水龙头', '搓洗并冲净双手', '关好水龙头'], '双手洗干净了，水龙头也关好了。')},
        {'room_id': 'home_study', 'name': '窗边书房', 'english_word': 'Study area', 'scene_level': 3,
         'parent_room': 'home_estate', 'theme': '阅读、收纳文具、使用电脑、做贺卡和安排计划，各有可辨认的物件。',
         'vocabulary_status': 'authored_functional_space_for_textbook_reading_and_computer', 'camera_size': 23.0,
         'anchors': [
             a('电脑书桌', '看看电脑能帮我们做什么；这里的问候只发生在游戏里。', G5A, 3, 19, 'p19-r2', 'I can email my friends with the computer.'),
             a('绘本书架', '把读完的书放回书架，再挑一个故事。', G5B, 1, 8, 'p8-r8', "We're going to read them."),
             a('靠窗阅读座', '晚上坐下来读一会儿书。', G6A, 2, 14, 'p14-r10', 'read a book'),
             a('文具整理桌', '找一找铅笔盒，把文具放到合适的位置。', G4B, 1, 8, 'p8-r7', "Where's my pencil case?"),
             a('贺卡手工台', '画一张送给家人的卡片，表达自己的心意。', G5B, 6, 33, 'p33-r8', "I'll make a beautiful card."),
         ], 'task': task('tidy_books', 2, '把读过的书放回去', ['收起散放的绘本', '把绘本按大小排好', '放回书架'], '绘本已经排整齐了，下次更容易找到。')},
        {'room_id': 'home_balcony', 'name': '家务阳台', 'english_word': 'Housework area', 'scene_level': 3,
         'parent_room': 'home_estate', 'theme': '洗衣、晾晒、浇花、打扫与节水，共用一个明亮通风的家务区。',
         'vocabulary_status': 'authored_functional_space_for_textbook_chores', 'camera_size': 23.0,
         'anchors': [
             a('洗衣篮与晾衣架', '将洗好的袜子挂好，再整理衣篮。', G6A, 7, 48, 'p48-r12', "I'm washing my socks."),
             a('盆栽照料台', '观察盆栽，学着给植物浇水。', G5A, 7, 48, 'p48-r10', 'I make the bed and water the plants.'),
             a('窗户清洁台', '擦一擦窗户，看看家人在做什么。', G4B, 8, 54, 'p54-r3', 'He is cleaning the window.'),
             a('扫帚与簸箕', '找到扫帚，把地面的小纸屑扫起来。', G5A, 7, 49, 'p49-r3', 'I sweep the floor.'),
             a('节水储物角', '洗衣后关好水，收起用品。', G6A, 7, 49, 'p49-r2', 'We should save water.'),
         ], 'task': task('hang_laundry', 1, '晾好洗过的小袜子', ['从衣篮取出袜子', '一双一双挂到晾衣架上', '夹好夹子并收起衣篮'], '袜子已经挂好，衣篮也收整齐了。')},
    ]
    for room in rooms:
        room['status'] = 'runtime_spatial_content'
        if room['scene_level'] == 3:room['parent_room'] = 'home_hall'
        room['return_to'] = {'room_id': room['parent_room'], 'interaction_id': 'home_gate' if room['scene_level'] == 2 else room['room_id'] + '_gate'}
        for i, anchor in enumerate(room['anchors'], 1):
            anchor.update({'id': f'memory_{"HOME" if room["room_id"] == "home" else room["room_id"]}_{i:02}', 'node_name': f'SG_MEMORY_{i:02}', 'order': i,
                           'room_id': room['room_id'], 'language_status': 'exact_textbook_quote_with_authored_activity'})
        room['english_focus'] = [room['anchors'][0]['source']['text']]
    estate = rooms[0]
    estate['areas'] = [{**r, 'separate_scene': True} for r in rooms[1:]]
    estate['model_bindings'] = {'entry': 'SG_HOUSE_ENTRY', 'entry_destination': 'home_hall', 'entry_flow': 'front_door_then_walkable_indoor_hall', 'legacy_doors': {r['room_id']: 'SG_DOOR_' + r['room_id'].upper() for r in rooms[1:]}}
    hall = {'room_id': 'home_hall', 'name': '家里 · 门厅与走廊', 'scene_level': 2,
            'parent_room': 'home_estate', 'space_role': 'household_indoor_navigation',
            'same_property_as': 'home_estate', 'indoor': True, 'camera_size': 31.0,
            'theme': '进门后在玄关收拾随身物品，沿地毯与走廊走到七个房间门前。',
            'composition': '连续的玄关、中央通道与横向走廊，配有鞋凳、挂衣处、墙灯、收纳和七扇带用途标识的实体门。室内采用可见人物的剖视镜头。',
            'return_to': {'room_id': 'home_estate', 'interaction_id': 'house_entry'},
            'areas': [{**r, 'separate_scene': True} for r in rooms[1:]],
            'model_bindings': {'doors': {r['room_id']: 'SG_DOOR_' + r['room_id'].upper() for r in rooms[1:]}},
            'anchors': [], 'status': 'runtime_navigation_space',
            'learning_role': 'navigation_only_no_added_memory_points_or_tasks'}
    data = {'schema_version': 1, 'title': '家庭二级场景与七个三级空间', 'parent': 'home_estate',
            'room_ids': [r['room_id'] for r in rooms], 'rooms': rooms, 'routes': [hall],
            'coverage': {'referenced_books': len(BOOKS), 'spaces': len(rooms), 'navigation_spaces': 1, 'loaded_household_scenes': 9, 'child_rooms': 7, 'anchors': 40,
                         'complete_textbook_coverage': False, 'language_mastery_assessed': False},
            'space_design': 'An original courtyard home; never a claim that every textbook family lives in this floor plan.',
            'save_compatibility': 'home remains the existing living-room identifier, memory ids and story/friend records retain their identity.',
            'flow': ['小院', '正门进入室内玄关', '沿走廊走到房门', '卧室起床整理', '浴室洗手', '厨房备餐', '餐厅用餐', '客厅迎客', '书房阅读', '阳台家务', '门厅正门回到小院'],
            'sources': [{'book_id': bid, 'manifest': str(LIBRARY / 'books' / (bid + '.json')),
                         'sha256': hashlib.sha256((LIBRARY / 'books' / (bid + '.json')).read_bytes()).hexdigest()} for bid in BOOKS]}
    save(ROOT / 'game/data/home_hierarchy.json', data)
    save(OUT / 'home_hierarchy.json', data)
    plan_path = ROOT / 'game/data/landmark_interiors.json'
    plan = json.loads(plan_path.read_text('utf-8'))
    old_home = next((r for r in plan['landmarks'] if r['room_id'] in ['home', 'home_estate']), None)
    estate.update({'district': '中央家园', 'world_socket': 'ALPHA_Home_Door', 'legacy_world_anchors': []})
    if old_home:
        estate.update({k: old_home[k] for k in ['district', 'world_socket', 'legacy_world_anchors'] if k in old_home})
    estate['id'] = 'HOME'
    plan['landmarks'] = [r for r in plan['landmarks'] if r['room_id'] not in ['home', 'home_estate']]
    plan['landmarks'].append(estate)
    save(plan_path, plan)
    rows = ['# 家庭二级场景与三级空间', '', '采用用户确认的「带小院的完整住宅」。一级字母岛 → 二级家庭小院 → 住宅室内门厅与走廊 → 七个独立三级空间。门厅是同一住宅的室内状态，只有导航功能，不新增知识点或家务任务。', '',
            '课本是知识来源，住宅布局与动手流程是原创游戏设计。四上 Unit 9 直接出现 living room / bedroom / kitchen / bathroom；餐厅、书房、家务阳台按吃饭、阅读、电脑和家务活动划分，不声称是该课原有的房间词汇。', '',
            '## 空间与内容', '', '| 空间 | 层级 | 五处生活位置 | 课本依据 |', '|---|---:|---|---|']
    for r in rooms:
        refs = sorted({f"{a['source']['book_title']} {a['source']['unit_id']}" for a in r['anchors']})
        rows.append(f"| {r['name']} | {r['scene_level']} | {'、'.join(a['label'] for a in r['anchors'])} | {'；'.join(refs)} |")
    rows += ['', '## 导航与保存', '', '- 小院呈现完整住宅外观；正门直接进入可行走的室内门厅。沿中央通道和走廊走到七扇实体房门，再进入对应房间。',
             '- 三级房间出口回到室内对应房门前；门厅正门返回小院，院门再返回一级主岛家门。',
             '- 保留旧 `home` 作为客厅的内部标识，既有朋友角、旅行册、装饰与固定五点记录继续有效。新增二级标识 `home_estate`。',
             '- 新活动保存为家务体验，不增加教材通关、独立回忆或语言掌握记录。取消未做完的活动恢复原道具状态。',
             '- 原 `.blend`、人物素材、教材源和生产存档有独立保护核验。', '', '## 来源检查边界', '',
             '所有引用逐条匹配八册本地教材 JSON 的原文、单元与页码。已人工查看四上印刷页 51/52、五上印刷页 42；其余本轮只做清单匹配，不冒称逐页人工复核。已有缓存合成语音按原文件复制，保留哈希。', '',
             '这份空间内容不代表八册完整课程已实装，也不代表儿童学习效果已验证。当前室内通行证据见 `docs/verification/home-indoor-v3/`；住宅外观历史证据见 `docs/verification/home-exterior-v2/`；原三级房间证据见 `docs/verification/home-hierarchy-v1/`。', '']
    (OUT / 'README.md').write_text('\n'.join(rows), encoding='utf-8')
    audit = {'status': 'PASS', 'books': len(BOOKS), 'rooms': len(rooms), 'anchors': sum(len(r['anchors']) for r in rooms),
             'quotes': [{'room': r['room_id'], 'anchor': i + 1, **a['source']} for r in rooms for i, a in enumerate(r['anchors'])],
             'visual_review_pages': [G4A + '/58', G4A + '/59', G5A + '/49'],
             'source_hashes': data['sources']}
    save(OUT / 'source-audit.json', audit)
    print(json.dumps({'status': 'PASS', 'rooms': len(rooms), 'quotes': len(audit['quotes']),
                      'cached_audio': sum('audio' in q for q in audit['quotes'])}, ensure_ascii=False))


if __name__ == '__main__':
    main()
