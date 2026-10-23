"""Author the bounded P2 flow; consume, never rewrite, textbook and prologue sources."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'game/data/learning/prologue.json'
prologue = json.loads(SOURCE.read_text(encoding='utf-8-sig'))

# Each operation has a different visible outcome. The six original interaction
# families are retained; click alternatives invoke the same transition as dragging.
operations = {
 'A': [('pick','摘下一颗苹果'),('place','把苹果放进篮子')],
 'B': [('bow','看看船头'),('stern','看看船尾'),('whole','把整条船放进取景框')],
 'C': [('pick','拿起一颗莓果'),('place','把莓果放到蛋糕上')],
 'D': [('tap','轻敲鼓面')],
 'E': [('uncover','揭开观察遮片')],
 'F': [('choose','选一种喜欢的花色')],
 'G': [('rotate','转动观察滑条')],
 'H': [('choose','选一顶帽子试戴')],
 'I': [('pick','拿起冰淇淋球'),('place','放到蛋筒上')],
 'J': [('open','揭开罐盖'),('close','把罐盖合好')],
 'K': [('pick','拿起尾带'),('place','把尾带接到风筝下面')],
 'L': [('switch','点亮灯笼')],
 'M': [('cap','观察菌盖'),('stem','观察菌柄'),('whole','看看完整的蘑菇')],
 'N': [('frame','移动取景窗，对准鸟巢')],
 'O': [('choose','在借阅卡上选猫头鹰印记')],
 'P': [('choose','选一只南瓜放进收成框')],
 'Q': [('pick','拿起花纹布片'),('place','把布片放进拼布被的空格')],
 'R': [('choose','给机器人选一个动作')],
 'S': [('pick','拿起星星'),('place','放到五角星轮廓上')],
 'T': [('pick','拿起一节车厢'),('place','把车厢接到车头后面')],
 'U': [('rain','选择雨天，撑开雨伞')],
 'V': [('crater','移动放大窗，找到山顶火山口')],
 'W': [('whale','在观察图里找到鲸鱼')],
 'X': [('long','敲一根长音条'),('short','敲一根短音条')],
 'Y': [('start','找到短线头'),('trace','沿着线头连到毛线团')],
 'Z': [('pick','拿起斑马邮票'),('stamp','把邮票盖在明信片上')],
}
choices = {'F':['珊瑚粉','暖黄色'],'H':['宽檐帽','棒球帽'],'O':['猫头鹰','小鱼'],'P':['圆圆的大南瓜','小巧的南瓜'],'R':['挥挥手','转一转'],'U':['晴天','雨天'],'W':['鲸鱼','小鱼']}
instructions = dict(zip('ABCDEFGHIJKLMNOPQRSTUVWXYZ', [
 '和兔兔一起摘苹果，再把苹果放进篮子。','先看看船头，再看看船尾，最后看看整条小船。',
 '选一颗莓果，放到蛋糕上。','轻轻敲一下鼓，看看声音的波纹。',
 '揭开遮片，看看蛋壳的轮廓。','选一种喜欢的花色，留在发现卡上。',
 '转到另一侧，看看地球仪上的陆地。','给小岛朋友选一顶喜欢的帽子。',
 '拿起一球冰淇淋，放到蛋筒上。','打开罐盖，看看罐里的莓果，再把盖子合好。',
 '拿起尾带，接在风筝下面。','点亮小灯笼，看看暖暖的光。',
 '先看看菌盖，再看看菌柄，最后看看整朵蘑菇。','移动观察框，看看鸟巢；让它留在原处。',
 '在两位伙伴中找到猫头鹰。','选一个大南瓜或小南瓜，看看大小有什么不同。',
 '拿起花纹布片，补进拼布被的空格。','选一个动作，看看机器人怎样回应。',
 '把星星放进同样形状的轮廓里。','拿起一节车厢，接在车头后面。',
 '什么时候需要撑开伞？选一种天气看看。','看看山顶的火山口，再看旁边的放大图。',
 '在两位伙伴中找到鲸鱼。','先敲最长的音条，再敲最短的音条。',
 '从线头出发，沿着线找到毛线团。','拿起斑马邮票，把它盖在明信片上。',
]))
feedback = dict(zip('ABCDEFGHIJKLMNOPQRSTUVWXYZ', [
 '苹果已经放进篮子，兔兔和你一起收好啦。','船头和船尾连起来，是一整条小船。',
 '莓果放好啦，这块蛋糕有了你的装饰。','咚！看看鼓面荡开的波纹。',
 '遮片揭开了，看看光滑、完整的蛋壳。','发现卡留下了你喜欢的花色。',
 '换个角度看，地球仪上有海洋和陆地。','帽子戴好啦，看看今天的样子。',
 '冰淇淋球稳稳放在蛋筒上。','看过罐子里的小秘密，也把盖子合好啦。',
 '尾带接好了，风筝有了一条长尾巴。','灯笼亮起来了，暖暖的光照着你。',
 '大菌盖和长菌柄连在一起，就是蘑菇。','鸟巢进了取景框，我们轻轻看一看。',
 '猫头鹰印记留在了借阅卡上。','收成框留下了你选的南瓜。',
 '花纹布片补好了空格，拼布被更完整啦。','机器人收到了你的动作邀请。',
 '星星回到五角轮廓里了。','车厢接好了，小火车完整啦。',
 '雨伞撑开了，雨点落在伞面上。','找到山顶的火山口了，它静静地休息着。',
 '找到鲸鱼啦，看看它的大尾巴。','长音条和短音条，都听过、看过啦。',
 '沿着短线头，找到了毛线团。','斑马邮票留在了给朋友的明信片上。',
]))
letters = {}
for entry in prologue['letters']:
    letter = entry['letter']['uppercase']
    letters[letter] = {
        'room': entry['scene_ref']['room_id'], 'marker': entry['scene_ref']['learning_node'],
        'primitive': entry['micro_action']['primitive'],
        'instruction': instructions[letter],
        'feedback': feedback[letter],
        'operations':[{'id':op,'label':label} for op,label in operations[letter]],
        'choices': choices.get(letter, []),
        'glyph_cue': entry['case_and_name']['existing_glyph_cue_cn'],
        'source_entry_id':entry['id'],
        'world_view':f'res://assets/learning/landmark_views/{letter}-front.png',
        'alternate_view':f'res://assets/learning/landmark_views/{letter}-angle.png',
        'world_model_node':f'ALPHA_{letter}_MODEL_ROOT',
        'recall_prompt':entry['recall']['prompt_cn'],
    }

def question(prompt, correct, options, hint, demo, phrase=''):
    return dict(prompt=prompt, correct=correct, options=[dict(id=k,text=v) for k,v in options],hint=hint,demo=demo,phrase=phrase,dimension='written_situation_choice')

def step(sid, room, actor, title, text, kind='continue', **extra):
    return dict(id=sid,room=room,actor=actor,title=title,text=text,kind=kind,**extra)

chapters = {
 '2':dict(title='寄给新朋友的邀请',unit_title="What's your name?",source='xiangshao-g3-1/unit-2',source_pages=[13,17],objectives_region='p13-r5',letters='DEFG',steps=[
  step('U2-01','landmark_Z','npc_bear_uncle','两张空白邀请','欢迎会还可以邀请新朋友。先问清名字，再把邀请送到对应的信格。\nWhat\'s your name? 你叫什么名字？','continue',phrase='what_name'),
  step('U2-02','school','textbook_lingling','先问问这位同学','见到同学先打招呼，再问她叫什么名字。','question',recipient='textbook_lingling',question=question('想知道对方的名字，你会选哪一句？','ask_name',[('goodbye','Goodbye!'),('ask_name',"What's your name?"),('thanks','Thank you.')],'名字写在邀请的收件人一栏；这一次要问名字。',"What's your name?\n对方回答：I'm Lingling.",'what_name'),reply="I'm Lingling. 我是 Lingling。"),
  step('U2-03','landmark_M','textbook_tim','在邻居屋又见到一位朋友','邀请上还缺一个名字。可以再次询问，也可以请向导陪你说。','question',recipient='textbook_tim',question=question('给另一位朋友写邀请，先怎么问？','ask_name',[('ask_name',"What's your name?"),('thanks','Thank you.'),('goodbye','Goodbye!')],'先问清对方的名字，再填写邀请。',"What's your name?\n对方回答：I'm Tim.",'what_name'),reply="I'm Tim. 我是 Tim。"),
  step('U2-04','landmark_Z','npc_bear_uncle','把邀请送进对应信格','拖动邀请到同名信格；也可先点邀请，再点信格。两张都送好就完成。','mail'),
  step('U2-05','school','textbook_anne','离开前，向 Anne 道别','邀请已经送出了，准备离开校园。Anne 向你挥手。','question',question=question('这时想和 Anne 道别，你会选哪一句？','goodbye',[('thanks','Thank you.'),('goodbye','Goodbye!'),('ask_name',"What's your name?")],'现在要离开了，选一句道别的话。','Goodbye! 再见！','goodbye')),
  step('U2-06','landmark_Z','npc_bear_uncle','把字母路标放回旅行册','看看 Dd、Ee、Ff、Gg 和熟悉的鼓、鸡蛋、花、地球仪。可分别点读，也可直接收好。','letters'),
  step('U2-07','home','npc_bear_uncle','两封邀请都有了回音','Lingling 和 Tim 的回信已经放在邀请册里。下一次，我们为来客准备座位。','complete'),
 ]),
 '3':dict(title='欢迎会座位数',unit_title='How old are you?',source='xiangshao-g3-1/unit-3',source_pages=[18,22],objectives_region='p18-r5',letters='HIJK',steps=[
  step('U3-01','school','textbook_miss_li','欢迎桌需要几张座位卡？','先认识本次角色卡上的年龄，再数来客人数。年龄和座位数是两件事。\nHow old are you? 你几岁？','continue',phrase='how_old'),
  step('U3-02','classroom','textbook_mingming','给 Mingming 选年龄贴','本次欢迎会角色卡：Mingming — I\'m eight.\n看清角色的回答，再选择数字。','question',age_actor='textbook_mingming',age=8,question=question('Mingming 的角色卡说 “I\'m eight.”，应贴哪个数字？','8',[('7','7 · seven'),('8','8 · eight'),('9','9 · nine')],'eight 对应 8；可以再看看角色卡。','给 Mingming 的卡贴 8。')),
  step('U3-03','classroom','textbook_dongdong','再问 Dongdong','本次欢迎会角色卡：Dongdong — I\'m nine.\n这是另一位朋友，按他的回答选。','question',age_actor='textbook_dongdong',age=9,question=question('Dongdong 的角色卡说 “I\'m nine.”，应贴哪个数字？','9',[('9','9 · nine'),('7','7 · seven'),('8','8 · eight')],'nine 对应 9；姓名与年龄分别看。','给 Dongdong 的卡贴 9。')),
  step('U3-04','classroom','textbook_tim','还有 Tim 的角色卡','本次欢迎会角色卡：Tim — I\'m seven.\n每位来客的年龄贴保留在各自的卡上。','question',age_actor='textbook_tim',age=7,question=question('Tim 的角色卡说 “I\'m seven.”，应贴哪个数字？','7',[('8','8 · eight'),('9','9 · nine'),('7','7 · seven')],'seven 对应 7。','给 Tim 的卡贴 7。')),
  step('U3-05','classroom','textbook_miss_li','先给三位来客安排座位','来客是 Mingming、Dongdong、Tim。每个人一张座位卡，逐个摆好。这里数的是人数。','seats',seat_count=3),
  step('U3-06','classroom','textbook_anne','Anne 也来做客了','先问 How old are you?\n本次角色卡的回答是：I\'m ten.\n给她选一张年龄贴。','question',age_actor='textbook_anne',age=10,question=question('Anne 的角色卡说 “I\'m ten.”，应贴哪个数字？','10',[('10','10 · ten'),('4','4 · four'),('9','9 · nine')],'ten 是年龄 10；四位来客需要四个座位。','给 Anne 的年龄卡贴 10，座位另外增加一张。')),
  step('U3-07','classroom','textbook_miss_li','给新来客加一个座位','原来三位，又来一位 Anne。现在请数出四张座位卡；可随时拿走多放的卡。','seats',seat_count=4),
  step('U3-08','classroom','textbook_miss_li','把 Hh、Ii、Jj、Kk 带回家','看看帽子、冰淇淋、罐子和风筝，再回顾一到十。点读、跟着看或跳过回想都可以。','letters'),
  step('U3-09','home','npc_bear_uncle','欢迎桌准备好了','四位朋友都有自己的座位。年龄卡、邀请回信和合照会留在旅行册，随时可以回来看看。','complete'),
 ])
}
transfer = dict(id='U1-10',room='landmark_F',actor='npc_rabbit_gardener',title='在花园再次相遇',text='兔兔从花床边抬起头，看见你来了。换了一个地方，也换了一位朋友。',question=question('刚见到兔兔，先选一句合适的招呼吧。','hello',[('thanks','Thank you.'),('goodbye','Goodbye!'),('hello','Hello!')],'刚见面可以先打招呼；不是收到帮助或离开的时候。','Hello! 你好！','hello'))
output = dict(schema_version=1,revision='p2-journey-v1',source_prologue_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),letters=letters,chapters=chapters,u1_transfer=transfer,fictional_scene_ages={'textbook_mingming':8,'textbook_dongdong':9,'textbook_tim':7,'textbook_anne':10},age_provenance='Original game scenario cards, not claims about textbook character biographies or the child.',source_boundary='Unit 2/3 objectives and existing reviewed expressions support these original game events; this is not complete textbook-body coverage.')
path=ROOT/'game/data/learning/p2_journey.json'
path.write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'P2 content: {len(letters)} landmarks, {sum(len(x["steps"]) for x in chapters.values())} U2/U3 steps')
