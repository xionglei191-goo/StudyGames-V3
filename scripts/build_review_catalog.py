"""Author the bounded P3 revisit set from the existing letter and U1-U3 sources."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def build():
    prologue = json.loads((ROOT / 'game/data/learning/prologue.json').read_text('utf-8'))
    targets = []
    alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    places = [('landmark_F', 'npc_rabbit_gardener', '花园里的小邀请'),
              ('home', 'npc_bear_uncle', '回家整理旅行卡'),
              ('school', 'textbook_anne', '校园里的新相遇')]
    for row in prologue['letters']:
        letter = row['letter']['uppercase']
        image = row['anchor']['chinese_image_name']
        for dimension in ['case', 'image']:
            contexts = []
            for index, (room, actor, title) in enumerate(places):
                distractors = [alphabet[(alphabet.index(letter)+n+index)%26] for n in [5, 13]]
                options = [{'id': key, 'text': key.lower() if dimension == 'case' else key} for key in [letter]+distractors]
                options = options[index:] + options[:index]
                contexts.append({'room': room, 'actor': actor, 'title': title,
                    'prompt': ['一起给旅行卡配对。', '帮朋友整理桌上的发现卡。', '和朋友找一找卡片的伙伴。'][index] + ('\n这个大写字母的小写伙伴是哪一个？' if dimension == 'case' else '\n这个熟悉形象的字母伙伴是哪一个？'),
                    'stimulus': letter if dimension == 'case' else '', 'image_letter': letter if dimension == 'image' else '',
                    'correct': letter, 'options': options,
                    'hint': f'回想{image}地标和它的字母伙伴。' if dimension == 'case' else f'想一想{image}地标里藏着的字形。',
                    'demo': f'{letter} 的小写伙伴是 {letter.lower()}。' if dimension == 'case' else f'{image}的固定字母伙伴是 {letter}。',
                    'closing': '朋友把整理好的旅行卡收进了册子，想散步时还可以再来。'})
            targets.append({'id': f'letter/{letter}/{dimension}', 'group': 'letters', 'letter': letter,
                'title': f'{letter}{letter.lower()} · '+('大小写配对' if dimension == 'case' else '形象与字母'),
                'dimension': 'letter_case_association' if dimension == 'case' else 'letter_landmark_association',
                'unlock': 'letter/'+letter, 'source_refs': ['prologue.json#prologue_'+letter], 'contexts': contexts})
    # These are finite written-choice adaptations, never speech/listening assessments.
    phrases = [
        ('hello', 1, '打招呼', '和刚走进花园的朋友打招呼，你想选哪一句？', 'hello', [('hello','Hello!'),('thanks','Thank you.'),('bye','Goodbye!')], '这次是见面时的问候。', 'Hello! 你好！', ['U1-07','U1-10']),
        ('morning',1,'早晨问候','故事里的清晨，熊叔打开了窗。选一句早晨的问候。','morning',[('morning','Good morning.'),('bye','Goodbye!'),('thanks','Thank you.')],'留意故事中的清晨。','Good morning. 早上好。',['U1-01']),
        ('thanks',1,'表达感谢','朋友帮你扶好了花盆，你想向她表达感谢。','thanks',[('hello','Hello!'),('thanks','Thank you.'),('bye','Goodbye!')],'这一次要谢谢朋友的帮助。','Thank you. 谢谢你。',['U1-05']),
        ('name',2,'询问名字','给新来的朋友留一张小卡片，先问清她的名字。','name',[('name',"What's your name?"),('thanks','Thank you.'),('bye','Goodbye!')],'卡片收件人一栏需要名字。',"What's your name? 你叫什么名字？",['U2-02','U2-03']),
        ('goodbye',2,'道别','朋友准备结束这次散步，挥手告别时选哪一句？','bye',[('name',"What's your name?"),('hello','Hello!'),('bye','Goodbye!')],'这次是在离开时道别。','Goodbye! 再见！',['U2-05']),
        ('age',3,'询问年龄','在故事里填写角色年龄卡，想先问对方几岁。','age',[('age','How old are you?'),('name',"What's your name?"),('hello','Hello!')],'年龄和名字是两件事。','How old are you? 你几岁？',['U3-01']),
    ]
    for number, word, step in [(7,'seven','U3-04'),(8,'eight','U3-02'),(9,'nine','U3-03'),(10,'ten','U3-06')]:
        phrases.append((str(number),3,'读角色年龄卡',f'故事角色卡写着 “I\'m {word}.”，应放哪个数字？',str(number),[(str(n),str(n)) for n in [number,number-1,number+1 if number<10 else 8]],'读清角色卡上的年龄词，和座位数分开。',f'{word} 对应数字 {number}。',[step]))
    for key, unit, title, prompt, correct, options, hint, demo, sources in phrases:
        contexts = []
        situations = {
            'hello':['花园里遇见刚来的朋友，你想和她打个招呼。','家里来了客人。打开门时，选一句见面的问候。','校园里遇见新同学，他向你挥手。选一句问候。'],
            'morning':['故事里的清晨，兔兔正在给花浇水。选一句早晨的问候。','故事里的清晨，熊叔打开了窗。选一句早晨的问候。','故事里的清晨，你来到校门口。选一句早晨的问候。'],
            'thanks':['朋友帮你扶好了花盆，你想向她表达感谢。','熊叔借给你一块擦桌布，你想谢谢他的帮助。','朋友帮你找到了掉在校园里的旅行卡，你想谢谢她。'],
            'name':['给花园里新认识的朋友留卡片，先问清她的名字。','家里的小聚会来了新朋友，先问名字，再写座位卡。','帮新同学准备姓名贴，你想先问他叫什么名字。'],
            'goodbye':['花园散步结束了，向朋友挥手告别时选哪一句？','在朋友家做客结束了，出门时选一句告别的话。','准备离开校园了，想向朋友道别时选哪一句？'],
            'age':['花园故事会要填写角色年龄卡，你想问角色几岁。','熊叔的桌上有故事角色资料，你想先问角色的年龄。','校园角色扮演要填写年龄卡，你想先问对方几岁。'],
        }
        for index,(room,actor,place_title) in enumerate(places):
            choices = [{'id': k,'text':v} for k,v in options]
            choices = choices[index:]+choices[:index]
            situation = situations[key][index] if key in situations else ['花园故事会要整理角色牌。\n','熊叔拿来一套新的故事角色卡。\n','校园角色扮演要贴数字。\n'][index]+prompt
            contexts.append({'room':room,'actor':actor,'title':place_title,'prompt':situation,
                'stimulus':'','image_letter':'','correct':correct,'options':choices,'hint':hint,'demo':demo,
                'closing':['朋友邀请你看看花园里刚开的花。','熊叔把今天的小卡片收好，邀请你坐一会儿。','朋友说，下次还可以一起到校园散步。'][index]})
        targets.append({'id':'unit/'+key,'group':'u'+str(unit),'letter':'','title':f'U{unit} · {title}',
            'dimension':'written_situation_choice','unlock':'unit/'+str(unit),'source_refs':sources,'contexts':contexts})
    data = {'schema_version':1,'content_revision':'revisits-v1','scope':'26 letters in two separate dimensions and 10 written situations from U1-U3; authored adaptations; no speech or listening assessment',
        'source_files':['prologue.json','p2_journey.json','curriculum.json'],'targets':targets}
    destination = ROOT/'game/data/learning/revisits.json'
    destination.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Revisit catalog: {len(targets)} targets, {len(targets)*3} context variants')

if __name__ == '__main__':
    build()
