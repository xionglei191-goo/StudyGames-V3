"""Build the grade-3 editorial input; source library is read-only."""
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
PUBLIC = Path(r'D:\Project\Englishbook\public')


def norm(s):
    return re.sub(r'\s+', ' ', s.replace('’', "'")).strip()


def forms(surface):
    if '=' in surface:
        return surface.split('='), 'contraction_expansion'
    m = re.fullmatch(r'(.+?) \((?:pl\. )?(.+?)\)', surface)
    if m:
        return list(m.groups()), 'plural' if '(pl.' in surface else 'alternative'
    return [surface], None


def build():
    books = []
    for vol in [1, 2]:
        bid = f'xiangshao-g3-{vol}'
        d = json.loads((PUBLIC / 'books' / (bid + '.json')).read_text(encoding='utf-8-sig'))
        pages = {p['id']: p for p in d['pages']}
        entries = []
        for line in (HERE / 'g3_rows.tsv').read_text(encoding='utf-8').splitlines():
            if not line or line.startswith('#'): continue
            b, f, surface, meaning, lesson, flag = line.split('|')
            if int(b) != vol: continue
            f, lesson = int(f), int(lesson)
            fs, relation = forms(surface)
            search = re.compile(r'(?<![A-Za-z])' + re.escape(surface) + r'(?![A-Za-z])')
            ids = [r['id'] for r in pages[f]['regions'] if search.search(norm(r['text']))]
            if not ids:
                raise ValueError((bid, f, surface, 'no region for printed row'))
            for spelling in fs:
                entry = {
                    'spelling': spelling, 'meaning_zh': meaning,
                    'kind': ('phrase' if ' ' in spelling else 'contraction' if "'" in spelling else 'word'),
                    'requirement': 'recognition' if flag == 'R' else 'listen_speak_read_write',
                    'sources': [{'file_page': f, 'region_ids': ids, 'row_label': surface+' '+meaning,
                                 'listed_lesson_page': lesson, 'section': 'Word List'}],
                    'unit_numbers': [], 'surface_group': surface, 'variant_relation': relation,
                    'notes': ('等式未印中文义项；本条中文为基于等式的编辑释义。' if relation=='contraction_expansion' else '')
                }
                if spelling == "Children's Day": entry['kind']='proper_name'
                if relation == 'plural': entry['notes'] += '括号内为复数形式；保留全部字母，另作形式目标。'
                entries.append(entry)
        # Parse the unit glossary in visual column order, never by global OCR order.
        unit = None
        unresolved = []
        for f in [73, 74, 75]:
            p = pages[f]
            ordered = sorted(p['regions'], key=lambda r: (r['rect'][0] >= .45, r['rect'][1], r['rect'][0]))
            for r in ordered:
                t = norm(r['text'])
                if re.fullmatch(r'Unit \d+',t): unit=int(t.split()[-1]); continue
                if t in ['Vocabular y','Vocabulary','T']: continue
                fs, relation = forms(t)
                if t.startswith('('): fs=[t.strip('()')]
                matched=[]
                for e in entries:
                    if e['spelling'] in fs:
                        matched.append(e)
                        if unit and unit not in e['unit_numbers']: e['unit_numbers'].append(unit)
                        e['sources'].append({'file_page':f,'region_ids':[r['id']],'row_label':t,
                                             'listed_lesson_page':None,'section':'Vocabulary','unit_number':unit})
                if not matched: unresolved.append({'file_page':f,'region_id':r['id'],'text':t})
        for e in entries:
            if not e['unit_numbers']:
                lesson=e['sources'][0]['listed_lesson_page']
                cs=[c for c in d['chapters'] if c['id'].startswith('unit-') and c['printedStart'] <= lesson <= c['printedStart']+c['end']-c['start']]
                e['unit_numbers']=[int(c['id'].split('-')[1]) for c in cs]
                e['unit_assignment_method']='word_list_reference_page_to_chapter'
            else: e['unit_assignment_method']='Vocabulary_printed_unit'
        assert not unresolved, unresolved
        books.append({'book_id':bid,'visual_reviewed_file_pages':list(range(73,80)),
                      'entries':entries,'exclusions':([{'file_page':73,'region_id':'p73-r37','text':'T','reason':'T-shirt附近的重复T碎片，页面不是独立词条'}, {'file_page':79,'region_id':'p79-r4','text':'T','reason':'T-shirt重复碎片'}] if vol==2 else []),
                      'corrections':[{'kind':'curly_apostrophe','note':"页面弯撇号统一为ASCII撇号，词中位置保留；句末标点保留。"}],
                      'source_row_count':len({e['surface_group'] for e in entries}),
                      'requirement_source_text':'黑体词要求学生能听、说、读、写；蓝体词只作认读要求。'})
    stories={}
    for line in (HERE/'g3_stories.tsv').read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'): continue
        spelling,setting,anchor,actions,transfer=line.split('|')
        actions=actions.split('/')
        assert len(actions)==len(re.findall('[A-Za-z]',spelling)),(spelling,len(actions),len(re.findall('[A-Za-z]',spelling)))
        assert spelling not in stories,spelling
        stories[spelling]={'setting':setting,'meaning_anchor':anchor,'actions':actions,'transfer':transfer,'contrast':''}
    data={'grade':3,'books':books,'stories':stories}
    # Keep a stable main story and add explicitly named meaning pages; never overwrite
    # the earlier book's mnemonic when a later volume adds a different sense.
    extensions={
        'have': {'book_id':'xiangshao-g3-2','meaning_zh':'举行；有','meaning_anchor':'大家拥有聚会用品，随后举行聚会；吃喝主故事仍保留。','setting':'家中餐桌·聚会义项页','actions':['拿出自己拥有的聚会帽','把已有用品摆齐','点亮聚会场地','托出正在举行聚会的合照'],'transfer':'新场景分别理解have a party举行聚会与have a kite拥有风筝。'},
        'like': {'book_id':'xiangshao-g3-2','meaning_zh':'怎么样；像','meaning_anchor':'先比较云朵像小羊，再用天气图回答What is the weather like?；喜欢义故事保留。','setting':'家中喜好架·相似与询问义项页','actions':['照出羊形云','托出小羊图','把云图与羊图并排','托出天气图让朋友描述怎么样'],'transfer':'新云图判断像什么；新天气问句选择天气回答，不能答喜欢不喜欢。'},
        'too': {'book_id':'xiangshao-g3-2','meaning_zh':'太；也','meaning_anchor':'保留一起跳舞表示也；新增帽子太大遮眼表示程度过头。','setting':'学校同样动作台·程度义项页','actions':['载来超过头大小的帽','戴上后被帽遮住眼','掀帽指出太大导致看不见'],'transfer':'试新衣服时理解too big表示太大；Me too仍表示也。'}
    }
    for w, ext in extensions.items(): stories[w]['sense_extensions']=[ext]
    stories['make']['sense_extensions']=[
        {'book_id':'xiangshao-g3-2','meaning_zh':'制作','meaning_anchor':stories['make']['meaning_anchor'],'actions':stories['make']['actions'],'transfer':'在新手工台用材料制作一个物品，理解make。'},
        {'book_id':'xiangshao-g3-2','meaning_zh':'让','meaning_anchor':'按钮动作让玩偶笑起来，突出一个动作带来结果；保留制作主故事。','actions':['把不会笑的玩偶放到按钮台','滚动按下按钮','牵动玩偶嘴角向上','托出因按钮而笑起来的玩偶'],'transfer':'新因果图中选能让玩偶笑的动作，理解make it smile；不把“让”解释成制作玩偶。'}
    ]
    (HERE/'g3.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    targets={e['spelling'] for b in books for e in b['entries']}
    print(json.dumps({'books':[(b['book_id'],len(b['entries']),b['source_row_count']) for b in books], 'stories':len(stories),'missing':sorted(targets-stories.keys())},ensure_ascii=False))


if __name__=='__main__':build()
