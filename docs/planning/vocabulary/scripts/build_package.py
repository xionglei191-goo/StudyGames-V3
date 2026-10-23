"""Build and validate editorial vocabulary artifacts. No game/source writes.

Run from any cwd: python -X utf8 <this-file> [--inventory-only]
Standard library only. Inputs remain under authoring/ and public textbook sources.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import io
import json
import re
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path
from integration_contract import build_integration_artifacts
from narrative_revision import apply_narrative_revision

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[2]
PUBLIC = Path(r'D:\Project\Englishbook\public')
LANDMARKS = dict(zip('ABCDEFGHIJKLMNOPQRSTUVWXYZ', [
    ('Apple','苹果'),('Boat','小船'),('Cake','蛋糕'),('Drum','鼓'),('Egg','蛋壳'),
    ('Flower','花朵'),('Globe','地球仪'),('Hat','帽子'),('Ice cream','冰淇淋'),
    ('Jar','罐子'),('Kite','风筝'),('Lantern','灯笼'),('Mushroom','蘑菇'),
    ('Nest','鸟巢'),('Owl','猫头鹰'),('Pumpkin','南瓜'),('Quilt','拼布被'),
    ('Robot','机器人'),('Star','星星'),('Train','火车'),('Umbrella','雨伞'),
    ('Volcano','火山'),('Whale','鲸鱼'),('Xylophone','木琴'),('Yarn','毛线'),('Zebra','斑马')]))
REQ = {'listen_speak_read_write':'听、说、读、写','recognition':'认读',
       'listen_speak_read':'听、说、认读','listen_speak_recognize':'听、说、认读',
       'listen_speak':'听、说','not_distinguished':'未区分（保留原表注）'}


def read(p): return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def digest(s): return hashlib.sha256(s.encode('utf-8')).hexdigest()[:12]
def write_json(rel, obj):
    p=ROOT/rel; p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def write_text(rel, text):
    p=ROOT/rel; p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(text.rstrip()+'\n',encoding='utf-8')
def norm(s): return unicodedata.normalize('NFC',str(s).replace('’',"'").replace('‘',"'"))
def canon_meaning(s): return re.sub(r'[\s；;，,（）()。·]', '', s)
def safe_public(url):
    p=(PUBLIC/str(url).lstrip('/')).resolve()
    if not p.is_relative_to(PUBLIC.resolve()): raise ValueError('Source path escaped public')
    return p
def md(s): return str(s).replace('|','\\|').replace('\n',' ')


def tokenize(spelling,entry_kind=None):
    result=[]; letters=[]; counts=Counter(); i=0
    while i < len(spelling):
        c=spelling[i]; decomposition=unicodedata.normalize('NFD',c)
        base=decomposition[0].upper(); start=i+1
        if base in LANDMARKS and c.isalpha():
            counts[base]+=1
            token={'type':'letter','raw':c,'surface_position':start,'letter_position':len(letters)+1,
                   'letter':base,'case':'upper' if c.isupper() else 'lower','occurrence':counts[base],
                   'anchor_en':LANDMARKS[base][0],'anchor_zh':LANDMARKS[base][1]}
            if len(decomposition)>1: token['diacritic']=decomposition[1:]
            letters.append(token)
        else:
            kind={' ':'space',"'":'apostrophe','-':'hyphen','.':'sentence_punctuation',
                  '!':'sentence_punctuation','?':'sentence_punctuation',',':'sentence_punctuation',
                  ':':'sentence_punctuation',';':'sentence_punctuation'}.get(c)
            if spelling[i:i+3]=='...': c='...';kind='placeholder';i+=2
            elif c=='…': kind='placeholder'
            elif c.isdigit(): kind='digit'
            elif c=='.' and (entry_kind=='abbreviation' or spelling in {'No.','p.m.','a.m.','Mr.','Mrs.','Ms.'}):kind='abbreviation_point'
            if kind is None: raise ValueError(('Unsupported spelling character',spelling,c))
            token={'type':kind,'raw':c,'surface_position':start}
        result.append(token); i+=1
    assert ''.join(t['raw'] for t in result)==spelling
    return result, letters


def load_inputs():
    library=read(PUBLIC/'library.json'); books={}; authors={}; authored={}
    for g in [3,4,5,6]:
        p=ROOT/'authoring'/f'g{g}.json'
        if not p.exists(): continue
        a=read(p); authors[g]=a
        for b in a['books']:
            bid=b['book_id']; books[bid]=b
            for entry in b['entries']: authored[(bid,norm(entry['spelling']))]=a['stories'].get(entry['spelling'])
    manifests={b['id']:read(safe_public(b['url'])) for b in library['books']}
    return library,books,authors,authored,manifests


def inventory(library,books,authored):
    groups=defaultdict(list)
    for b in library['books']:
        if b['id'] not in books:continue
        for e in books[b['id']]['entries']:
            w=norm(e['spelling']); groups[w].append({'book_id':b['id'],'meaning_zh':e['meaning_zh'],
                'kind':e['kind'],'story_exists':bool(authored[(b['id'],w)])})
    varied={w:v for w,v in groups.items() if len({canon_meaning(e['meaning_zh']) for e in v})>1}
    write_json('review/sense_candidates.json',varied)
    print(json.dumps({'input_books':len(books),'unique_spellings':len(groups),'meaning_variants':len(varied),
                     'missing_stories':[{'spelling':w,**e} for w,es in groups.items() for e in es if not e['story_exists']]},ensure_ascii=False))
    return groups


def select_story(base,book_id,spelling):
    if not base: raise ValueError(('Missing authored story',book_id))
    story=dict(base)
    exts=base.get('sense_extensions',[])
    if isinstance(exts,dict): exts=list(exts.values())
    matches=[x for x in exts if x.get('book_id')==book_id]
    replace_primary=(spelling,book_id) in {('have','xiangshao-g3-2'),('like','xiangshao-g3-2'),('fan','xiangshao-g5-2'),('drop','xiangshao-g6-2')}
    if len(matches)==1 and replace_primary:
        story.update({k:v for k,v in matches[0].items() if k not in ('book_id','meaning_zh')})
    elif matches:
        story['meaning_anchor']='；'.join([base['meaning_anchor']]+[x['meaning_anchor'] for x in matches if x.get('meaning_anchor')])
        story['transfer']='；'.join([base['transfer']]+[x['transfer'] for x in matches])
    return story


def extension_scenes(src,book_id,letters):
    result=[]
    for x in src.get('sense_extensions',[]):
        if x.get('book_id') and x['book_id']!=book_id:continue
        actions=x.get('actions',src['actions'])
        assert len(actions)==len(letters),(book_id,'extension',x.get('meaning_zh'))
        steps=[]
        for t,a in zip(letters,actions):
            if a.startswith(t['anchor_zh']):a=a[len(t['anchor_zh']):]
            steps.append({'letter_position':t['letter_position'],'letter':t['letter'],'anchor_zh':t['anchor_zh'],
                          'occurrence':t['occurrence'],'action':a})
        result.append({'meaning_zh':x.get('meaning_zh','补充义项'),'book_id':book_id,
                       'meaning_anchor':x.get('meaning_anchor',x.get('scene',x.get('reuse_policy',f"在原故事位置明确切换为{x.get('meaning_zh','本义项')}。"))),
                       'transfer':x['transfer'],'action_mode':'authored_alternate' if 'actions' in x else 'focus_on_core_story',
                       'steps':steps,'review':'assistant_authored_human_editor_pending'})
    return result


def reuse_extension_scenes(story):
    """Keep the first memory scene for each repeated supplemental meaning."""
    canonical={}
    for source in story['sense_extensions']:
        # Ellipses mark an argument slot, not a new sense (用 / 用……).
        key=re.sub(r'[\s….]+','',source['meaning_zh'])
        if key not in canonical:
            canonical[key]={**source,'id':'sense-scene-'+digest(story['id']+'\0'+key),
                'meaning_key':key,'book_ids':[],'meaning_labels':[], 'transfer_variants':[],
                'reuse_policy':'同义补充镜头复用首次固定位置和动作；后册情境仅作迁移练习。'}
        target=canonical[key]
        if source['book_id'] not in target['book_ids']:target['book_ids'].append(source['book_id'])
        if source['meaning_zh'] not in target['meaning_labels']:target['meaning_labels'].append(source['meaning_zh'])
        variant={'book_id':source['book_id'],'meaning_zh':source['meaning_zh'],'task':source['transfer']}
        if variant not in target['transfer_variants']:target['transfer_variants'].append(variant)
    story['sense_extensions']=list(canonical.values())


def build_story(w,lex_id,sense_key,src,meaning,letters,tokens,root_setting):
    actions=src['actions']
    assert len(actions)==len(letters),(w,len(actions),len(letters))
    sid='story-'+digest(w+'\0'+sense_key)
    steps=[{'letter_position':a['letter_position'],'surface_position':a['surface_position'],
            'letter':a['letter'],'raw':a['raw'],'anchor_en':a['anchor_en'],'anchor_zh':a['anchor_zh'],
            'occurrence':a['occurrence'],'action':act} for a,act in zip(letters,actions)]
    frames=[]
    for start in range(0,len(steps),4):
        chunk=steps[start:start+4]
        frames.append({'frame':len(frames)+1,'letter_positions':[s['letter_position'] for s in chunk],
                      'text':' → '.join(f"{s['letter_position']}.{s['anchor_zh']}〔{s['letter']}第{s['occurrence']}次〕{s['action']}" for s in chunk)})
    chain=' → '.join(f"{x['letter_position']}:{x['raw']}={x['anchor_zh']}({x['occurrence']})" for x in letters)
    boundary={'space':'轻停并留一个空格','apostrophe':'放高处小钩','hyphen':'放连接桥',
              'digit':'放原数字牌','sentence_punctuation':'放原句末/语气标记','placeholder':'保留可填内容槽',
              'abbreviation_point':'保留缩略点；它不是句子结束或语气标记'}
    events=[{**t,'instruction':boundary[t['type']]} for t in tokens if t['type']!='letter']
    for t in letters:
        if t.get('diacritic'):events.append({'type':'diacritic','raw':t['diacritic'],'surface_position':t['surface_position'],
                                            'instruction':'E地标不变，在e字形上保留教材重音符号'})
    prompt=[
      {'level':0,'name':'自主','prompt':f"{src['transfer']} 先按当前任务回应，不显示故事或字母链。可以随时打开帮助；主动回看也记录所见线索，不能据此记无提示回忆。"},
      {'level':1,'name':'位置与意义','prompt':f"想想{root_setting}的固定故事页。这次意思是“{meaning}”。{src['meaning_anchor']}"},
      {'level':2,'name':'第一步','prompt':f"第一格是{letters[0]['anchor_zh']}，对应{letters[0]['raw']}。它先{actions[0]}。接下来发生什么？"},
      {'level':3,'name':'缺口接续','prompt':'按编号补回缺口，保留重复实例。缺失位置的字母和形象在请求揭示前不显示；可以打开帮助继续。','answer_chain_for_evaluator_only':chain},
      {'level':4,'name':'逐步搭桥','prompt':'逐步展示当前动作，再给下一格两个形象候选；只补当前卡住的一步。','step_questions':[f"第{s['letter_position']}格的{s['anchor_zh']}{s['action']}，下一格怎样接住这一动作？" for s in steps[:-1]]},
      {'level':5,'name':'完整示范','prompt':'播放完整词音后依次展示下面分镜；逐个指读字母与形象，再回到完整词义。','frame_refs':list(range(1,len(frames)+1))}
    ]
    return {'id':sid,'lexeme_id':lex_id,'sense_key':sense_key,'meaning_label':meaning,
            'meaning_anchor':src['meaning_anchor'],'authored_setting':src['setting'],
            'storage':{'root_location':root_setting,'story_page':sid,'storage_slot':lex_id+'/'+sid,
                       'policy':'同一拼写主册固定；新义项为相邻页；同义跨册复用此页；这是内容索引设计，未实装。'},
            'steps':steps,'frames':frames,'orthography_events':events,
            'contrast':src.get('contrast',''),'child_operation':[
                f"先在物品或情境里理解“{meaning}”，听完整词音（语音未具备时不得假记听力通过）。",
                '按字母位置摆地标缩影；每个重复实例占独立一格；长词按分镜接续。',
                '口述、选图或画出每一步；可另存自己的故事，检查顺序与意思，不评审美。',
                '只有本次任务许可包含书写且玩家选择练习时，才把地标卡换回字母卡并补空格、标点与大小写；认读或仅听说条目不设强制拼写。最后按本册要求做新情境任务。'],
            'prompt_ladder':prompt,'transfer_task':src['transfer'],
            'recall_plan':{'windows':['当次隔开一个活动','约1天','约3天','约7天'],
                           'status':'待儿童试用的产品安排；记录实际间隔，不宣称最优或有效',
                           'task':f"先选择本册许可的任务模态，再回访{w}。地点提示、主动回看和声音都记录实际线索；完整词音可作听辨/听写题干，但在目标读音回忆中属于辅助。可随时求助或跳过，不因H0标签判为独立。"},
            'review':{'automation':'checked_on_build','assistant_editorial':'authored_and_structurally_checked',
                      'human_editor':'pending','child_trial':'not_conducted','learning_effect':'not_validated','runtime':'planning_only'}}


def main(inventory_only=False):
    library,books,authors,authored,manifests=load_inputs()
    groups=inventory(library,books,authored)
    if inventory_only:return
    assert len(books)==8,'All eight authoring books are required'
    policies=read(ROOT/'sense_policy.json') if (ROOT/'sense_policy.json').exists() else {}
    editorial_extensions=read(ROOT/'editorial_extensions.json') if (ROOT/'editorial_extensions.json').exists() else {}
    current=read(PROJECT/'game/data/curriculum.json')
    game_manifest=read(PROJECT/'game/data/content_manifest.json')
    ordered_ids=[b['id'] for b in library['books']]
    page_audit=[]; sources={}; lexemes={}; stories={}; occurrences=[]; summary=[]; unresolved=[]
    read_pages=set(); exceptions=[]
    # Index only exact full-region audio candidates; grouped region audio is never
    # asserted to be a standalone recording of one word.
    source_audio=defaultdict(list)
    for bid,d in manifests.items():
        for p in d['pages']:
            for r in p['regions']:
                t=norm(r['text']).strip()
                if r.get('audio') and t in groups and len(source_audio[t])<2:
                    audio_path=safe_public(r['audio'])
                    if audio_path.is_file():source_audio[t].append({'book_id':bid,'file_page':p['id'],'region_id':r['id'],
                        'source_audio':r['audio'],'bytes':audio_path.stat().st_size,'kind':d.get('audioKind',d.get('speechProfile'))})
    for order,b in enumerate(library['books']):
        bid=b['id']; data=books[bid]; manifest=manifests[bid]; pages={p['id']:p for p in manifest['pages']}
        formal=[c for c in manifest['chapters'] if c['title'].startswith(('Vocabulary','Word List'))]
        expected=sorted({i for c in formal for i in range(c['start'],c['end']+1)})
        assert sorted(data['visual_reviewed_file_pages'])==expected,(bid,'Unreviewed formal page')
        referenced=defaultdict(set)
        local=[]
        for e in data['entries']:
            w=norm(e['spelling']); tokens,letters=tokenize(w,e['kind']); assert letters,(bid,w)
            lx='lex-'+digest(w); meaning=e['meaning_zh']; base=authored[(bid,w)]
            base=dict(base)
            overlays=[x for x in editorial_extensions.get(w,[]) if not x.get('book_id') or x['book_id']==bid]
            overlay_labels={x['meaning_zh'] for x in overlays}
            base['sense_extensions']=[x for x in base.get('sense_extensions',[]) if x.get('meaning_zh') not in overlay_labels]+overlays
            authored_story=select_story(base,bid,w)
            assert len(authored_story['actions'])==len(letters),(bid,w,'actions length')
            policy=policies.get(w,{})
            sense=policy.get('book_senses',{}).get(bid,canon_meaning(meaning))
            if policy.get('merge_all'):sense='shared'
            if w not in lexemes:
                lexemes[w]={'id':lx,'spelling':w,'tokens':tokens,'letter_chain':letters,
                    'root_location':authored_story['setting'],'story_ids':[],'occurrence_ids':[],
                    'first_book_id':bid,'reuse_policy':policy or {'kind':'exact_gloss_match_else_adjacent_sense_page'}}
            lex=lexemes[w]; sid='story-'+digest(w+'\0'+sense)
            if sid not in stories:
                stories[sid]=build_story(w,lx,sense,authored_story,meaning,letters,tokens,lex['root_location'])
                stories[sid]['authored_origin_book']=bid
                stories[sid]['sense_extensions']=[]
                lex['story_ids'].append(sid)
            stories[sid]['sense_extensions'].extend(extension_scenes(base,bid,letters))
            source_refs=[]
            for s in e['sources']:
                fp=s['file_page'];p=pages[fp]; assert fp in expected,(bid,w,'Source outside formal table')
                rids=s.get('region_ids',[]); rmap={r['id']:r for r in p['regions']}
                assert set(rids)<=rmap.keys(),(bid,w,'Invalid region',rids)
                if not rids: assert any(s.get(x) for x in ('image_only_row','no_exact_region','image_only','image_only_reason')) or s.get('row_label'),(bid,w,'No image row locator')
                for rid in rids:referenced[fp].add(rid)
                source_id='src-'+digest(bid+'\0'+str(fp)+'\0'+s['row_label']+'\0'+','.join(rids))
                enriched={**s,'id':source_id,'book_id':bid,'page':p['printedPage'],'file_page':fp,
                          'image':p['image'],'image_absolute':str(safe_public(p['image'])),
                          'chapter_id':p['chapter'],'raw_regions':[{k:rmap[rid].get(k) for k in ('id','text','rect','source','sourceVerified','reviewed')} for rid in rids],
                          'review':{'page_image':'assistant_visual_checked','human_editor':'pending'},
                          'locator_kind':'image_row_only' if not rids else s.get('region_role','region_and_image_row')}
                sources[source_id]=enriched;source_refs.append(source_id)
                read_pages.add((bid,fp))
            oid='occ-'+digest(bid+'\0'+w+'\0'+meaning)
            exact_game=[{'phrase_id':key,'audio':v['audio'],'kind':v.get('audio_kind')}
                        for key,v in current['phrases'].items() if norm(v['en'])==w and (PROJECT/'game'/v['audio'].removeprefix('res://')).is_file()]
            req=e.get('requirement_normalized',e['requirement'])
            if req=='listen_speak_recognize':req='listen_speak_read'
            assert req in REQ,(bid,w,req)
            occ={'id':oid,'book_id':bid,'lexeme_id':lx,'spelling':w,'meaning_zh':meaning,
                 'kind':e['kind'],'requirement':req,'requirement_note':e.get('requirement_note',e.get('requirement_source_text',data.get('requirement_source_text',''))),
                 'surface_group':e.get('surface_group',w),'variant_relation':e.get('variant_relation'),
                 'unit_numbers':e.get('unit_numbers',[]),'source_ids':source_refs,'story_id':sid,
                 'occurrence_transfer_task':authored_story['transfer'],
                 'occurrence_meaning_anchor':stories[sid]['meaning_anchor'],
                 'reuse':{'first_book_id':lex['first_book_id'],'shared_story':stories[sid]['authored_origin_book']!=bid,
                          'meaning_branch_count':None},'notes':e.get('notes',''),
                 'audio':{'status':'existing_game_clip_candidate_pending_content_listening_review' if exact_game else 'pending_production_or_adaptation',
                          'game_exact_candidates':exact_game,'source_exact_candidates':source_audio.get(w,[]),
                          'source_candidate_note':'仅核对完整区域文字和文件存在；未听检、未复制、未全库接入；合并区域音频不作为单词语音。',
                          'pronunciation_review':'pending','story_narration':'待制作'},
                 'review':{'source_page':'assistant_visual_checked','automation':'passed_on_build','human_editor':'pending','child_trial':'not_conducted','runtime':'planning_only'}}
            occurrences.append(occ);local.append(occ);lex['occurrence_ids'].append(oid)
        excluded_ids=defaultdict(set)
        for ex in data.get('exclusions',[]):
            if isinstance(ex,dict) and ex.get('file_page'):
                for rid in ex.get('region_ids',[]):excluded_ids[ex['file_page']].add(rid)
                if ex.get('region_id'):excluded_ids[ex['file_page']].add(ex['region_id'])
        for c in formal:
            for fp in range(c['start'],c['end']+1):
                p=pages[fp];img=safe_public(p['image']);assert img.is_file()
                missing=[]; headers=[]
                for r in p['regions']:
                    t=norm(r['text']).strip()
                    if re.fullmatch(r'(?:Vocabular\s*y|Vocabulary|Word List(?: I{1,2})?|Page|Unit(?: \d+)?)',t):headers.append(r['id']);continue
                    if r['id'] not in referenced[fp] and r['id'] not in excluded_ids[fp]:missing.append({'region_id':r['id'],'text':t})
                if missing:unresolved.append({'book_id':bid,'file_page':fp,'unreferenced_regions':missing})
                page_audit.append({'book_id':bid,'section':c['title'],'page':p['printedPage'],'file_page':fp,
                    'image':p['image'],'image_sha256':sha(img),'region_count':len(p['regions']),
                    'referenced_region_count':len(referenced[fp]),'headers_or_letter_artifacts':headers,
                    'explicitly_excluded_regions':sorted(excluded_ids[fp]),'unreferenced_regions':missing,
                    'assistant_visual_checked':True,'human_editor':'pending'})
        counts=Counter(x['kind'] for x in local); spelling_set={x['spelling'] for x in local}
        previous={x['spelling'] for x in occurrences[:-len(local)]}
        summary.append({'book_id':bid,'title':b['title'],'grade':b['grade'],'volume':b['volume'],'edition':b['edition'],
                        'source_manifest':b['url'],'manifest_sha256':sha(safe_public(b['url'])),'source_pdf_sha256':manifest.get('sourceSha256'),
                        'source_page_count':len(manifest['pages']),'unit_count':sum(c['id'].startswith('unit-') for c in manifest['chapters']),
                        'formal_sections':[{k:c.get(k) for k in ('title','start','end','printedStart')} for c in formal],
                        'source_row_groups':len({x['surface_group'] for x in local}),'occurrences':len(local),'unique_spellings':len(spelling_set),
                        'kind_counts':dict(counts),'requirement_counts':dict(Counter(x['requirement'] for x in local)),
                        'reused_from_prior_books':len(spelling_set&previous),'new_spellings':len(spelling_set-previous),
                        'visual_reviewed_file_pages':expected,'corrections':data.get('corrections',[]),'exclusions':data.get('exclusions',[])})
    extension_source_count=sum(len(s['sense_extensions']) for s in stories.values())
    for story in stories.values():reuse_extension_scenes(story)
    for occ in occurrences:occ['reuse']['meaning_branch_count']=len(lexemes[occ['spelling']]['story_ids'])
    assert len({x['id'] for x in occurrences})==len(occurrences),'Duplicate book/spelling/sense target'
    assert len({x['id'] for x in lexemes.values()})==len(lexemes)
    preserved=[]
    for original in read(ROOT/'source_baseline.json'):
        p=Path(original['path']); unchanged=sha(p)==original['sha256']
        preserved.append({**original,'current_sha256':sha(p),'unchanged':unchanged})
        if p.is_relative_to(PUBLIC):assert unchanged,('Source manifest changed',str(p))
    catalog={'schema_version':1,'planning_version':'v1','date':'2026-10-22','status':'planning_only',
             'scope':'正式Vocabulary/Word List系列并集；含认读词、括号变体和缩略式展开；不声称逐词穷尽所有课文和附录文本',
             'landmarks':{k:{'anchor_en':v[0],'anchor_zh':v[1]} for k,v in LANDMARKS.items()},
             'books':summary,'lexemes':list(lexemes.values()),'stories':list(stories.values()),
             'occurrences':occurrences,'sources':list(sources.values()),
             'current_runtime_evidence':{'project_version':re.search(r'config/version="([^"]+)"',(PROJECT/'game/project.godot').read_text(encoding='utf-8')).group(1),
                'curriculum_coverage':current['coverage'],'curriculum_phrase_count':len(current['phrases']),
                'curriculum_question_count':len(current['questions']),'packaged_audio_count':game_manifest['audio_count']}}
    narrative_report=apply_narrative_revision(catalog,ROOT)
    integration_report=build_integration_artifacts(catalog,manifests,ROOT,PROJECT)
    learning_report_path=PROJECT/'game/data/learning/build_report.json'
    if learning_report_path.exists():
        learning_report=read(learning_report_path)
        catalog['current_runtime_evidence']['existing_learning_package_report']={
            'path':'game/data/learning/build_report.json',
            **{k:learning_report.get(k) for k in ('content_revision','codebook_revision','entries','stories')},
            'matches_planning_content_revision':learning_report.get('content_revision')==catalog['content_revision'],
            'runtime_acceptance':'not_checked_by_this_revision'}
    write_json('data/catalog.json',catalog)
    write_json('review/source_pages.json',page_audit)
    write_json('review/unreferenced_regions.json',unresolved)
    write_json('review/source_preservation.json',preserved)
    for b in summary:
        local=[x for x in occurrences if x['book_id']==b['book_id']]
        short=f"g{b['grade']}-{b['volume']}"
        write_json(f'books/{short}.json',{'book':b,'entries':[{**x,'letter_chain':lexemes[x['spelling']]['letter_chain'],
            'tokens':lexemes[x['spelling']]['tokens'],'story':stories[x['story_id']],
            'sources':[sources[s] for s in x['source_ids']]} for x in local]})
        render_book(b,local,lexemes,stories,sources,short)
    render_csv(occurrences,lexemes,stories,sources)
    reuse=[{'spelling':w,'lexeme_id':lex['id'],'books':[bid for bid in ordered_ids if any(x['book_id']==bid and x['spelling']==w for x in occurrences)],
            'story_ids':lex['story_ids'],'shared_location':lex['root_location']} for w,lex in lexemes.items()
           if len({x['book_id'] for x in occurrences if x['spelling']==w})>1]
    write_json('data/cross_book_reuse.json',reuse)
    report={'status':'passed' if not unresolved else 'needs_region_reconciliation','books':len(summary),
            'formal_pages':len(page_audit),'book_occurrences':len(occurrences),'unique_spellings':len(lexemes),
            'story_sense_pages':len(stories),'letter_steps':sum(len(s['steps']) for s in stories.values()),
            'additional_sense_scenes':sum(len(s['sense_extensions']) for s in stories.values()),
            'additional_sense_scene_book_references':extension_source_count,
            'cross_book_spellings':len(reuse),'image_only_sources':sum(not s['region_ids'] for s in sources.values()),
            'unreferenced_content_regions':sum(len(x['unreferenced_regions']) for x in unresolved),
            'source_manifests_unchanged':all(x['unchanged'] for x in preserved if Path(x['path']).is_relative_to(PUBLIC)),
            'human_editor_review':'pending','child_trial':'not_conducted','memory_effect':'not_validated',
            'full_game_test':'not_run_no_runtime_changes','checks':['eight-book formal page inventory','visual-check page declarations','valid source pages and region IDs','source hashes','all spellings reversible tokenization','letter/landmark fixed mapping','one action per letter including repeats','stable cross-book story references','supplemental meaning scenes reuse first actions across books','audio file existence candidates only','reference integrity'],
            'integration_contract':integration_report,'narrative_revision':narrative_report}
    write_json('review/validation.json',report)
    render_overview(catalog,report,reuse)
    render_scope(catalog,manifests)
    render_examples(catalog,stories,lexemes,sources)
    print(json.dumps(report,ensure_ascii=False))


def render_book(b,local,lexemes,stories,sources,short):
    lines=[f"# {b['title']}正式词汇策划",'',f"版本：{b['edition']}。全书{b['source_page_count']}文件页、{b['unit_count']}单元；本稿覆盖下列正式词表并集。",'',
           '| 表 | 印刷起页 | 文件页 |','|---|---:|---|']
    for s in b['formal_sections']:lines.append(f"| {s['title']} | {s['printedStart']} | {s['start']}–{s['end']} |")
    lines += ['',f"{b['source_row_groups']}个表面形式组展开为{b['occurrences']}条册内策划，{b['unique_spellings']}个唯一拼写。与此前册复用{b['reused_from_prior_books']}个拼写，本册新见{b['new_spellings']}个。各词类及教学要求见同名JSON。",
              '', '页图由智能助手逐页核对；独立人工编辑复核、儿童试用及本版故事的语音听检、游戏验收均未完成。故事是新编记忆脚本，不是教材原故事、词源或读音规则。','',
              '| 拼写 | 教材义项 | 类别／要求 | 单元 | 故事卡 |','|---|---|---|---|---|']
    for o in local:lines.append(f"| {md(o['spelling'])} | {md(o['meaning_zh'])} | {o['kind']}／{REQ[o['requirement']]} | {','.join(map(str,o['unit_numbers'])) or '扩展／待定位'} | [打开](../cards/{short}.md#{o['id']}) |")
    lines+=['','## 提取边界','', '正式词表中的词组、标题式表达、专名与括号变体保留各自类型。按字母表与按单元表重复出现的是来源复现，不重复计为新拼写。未把目录、练习指令、人名碎片或整句切词加入本表。表外补充词及附录图板见总范围说明，未宣称全书每个英文词都已建卡。']
    write_text(f'books/{short}.md','\n'.join(lines))
    cards=[f"# {b['title']}全部故事卡",'', '每条都可由同名 books JSON 读取完整字段。提示由H5完整示范逐渐淡出；求助按H0→H5递增。H0不是独立成绩，按任务模态和实际线索记录；正常词音可作听辨/听写题干，但不能当作无辅助的目标读音回忆。','']
    for o in local:
        st=stories[o['story_id']];lex=lexemes[o['spelling']]
        cards += [f'<a id="{o["id"]}"></a>',f"## {o['spelling']} — {o['meaning_zh']}",'',
          f"`{o['id']}` · {o['kind']} · {REQ[o['requirement']]} · 单元 {','.join(map(str,o['unit_numbers'])) or '扩展／待定位'}",'',
          f"**固定位置：** {st['storage']['root_location']}；永久故事页 `{st['id']}`。这是回忆册内容位置，不声明现有地图已有同名实体锚点。",
          f"**任务许可：** {o['task_permissions']['display_note']} 剧情从不要求拼写全对；所用帮助单独记录。"]
        if st.get('narrative'):
            cards+=['',f"### 完整故事 · {st['narrative']['title']}",'']
            for paragraph in st['narrative']['paragraphs']:cards+=['> '+paragraph,'']
            cards+=[f"**想象接续问题：** {st['narrative']['recall_question']}",'']
        cards += [f"**意义画面：** {st['meaning_anchor']}",
                  '**逐字母链：** '+' → '.join(f"{t['letter_position']}. {t['raw']}＝{t['anchor_zh']}〔第{t['occurrence']}次〕" for t in lex['letter_chain']), '']
        if st.get('narrative'):
            cards.append('**分镜定位：** '+'；'.join(f"第{f['frame']}镜对应字母位置{','.join(map(str,f['letter_positions']))}" for f in st['frames'])+'。完整逐格句子见同名JSON的steps。')
        else:
            for f in st['frames']:cards.append(f"- 分镜 {f['frame']}：{f['text']}。")
        for ex in st.get('sense_extensions',[]):
            cards+=['',f"**共用故事册的补充义项：{ex['meaning_zh']}**（来源册{'、'.join(ex['book_ids'])}；只按本卡教材义项选用）— {ex['meaning_anchor']}",f"固定补充镜头 `{ex['id']}`；各册复用本版本同一套动作。"]
            if ex.get('narrative',{}).get('shared_with') == st['id']:
                cards+=['', '此义项复用本页上方的完整核心故事，不另换情节。', '']
            elif ex.get('narrative',{}).get('shared_with'):
                cards+=['',f"此义项复用本页同义片段《{ex['narrative']['title']}》（固定镜头 `{ex['narrative']['shared_with']}`），不另换情节。",'']
            elif ex.get('narrative'):
                cards+=['',f"**{ex['narrative']['title']}**",'']
                for paragraph in ex['narrative']['paragraphs']:cards+=['> '+paragraph,'']
                cards.append('想象接续问题：'+ex['narrative']['recall_question'])
            else:
                cards.append(' → '.join(f"{p['letter_position']}.{p['anchor_zh']}〔{p['letter']}第{p['occurrence']}次〕{p['action']}" for p in ex['steps']))
            for variant in ex['transfer_variants']:
                cards.append(f"该义项迁移练习（{variant['book_id']}）：{variant['task']}")
        if st['orthography_events']:cards+=['','**独立书写事件：** '+'；'.join(f"字符位{t['surface_position']} `{t['raw']}`：{t['instruction']}" for t in st['orthography_events'])]
        cards+=['','**孩子操作：** '+' '.join(st['child_operation']),'','**提示梯度：**']
        for p in reversed(st['prompt_ladder']):cards.append(f"- {p['level']} {p['name']}：{p['prompt']}")
        cards+=['',f"**后续回忆：** {st['recall_plan']['task']} 依当次、约1/3/7天窗口邀请，记录真实间隔。",f"**新情境：** {o['occurrence_transfer_task']}",
                f"**复用：** 首见{lex['first_book_id']}；同拼写共{len(lex['story_ids'])}个意义页；同义故事不随册重置。",f"**语音：** {o['audio']['status']}；原库完整区域候选{len(o['audio']['source_exact_candidates'])}条；故事旁白待制作。",
                '**审核：** 自动结构核验通过；智能助手看图；独立人工编辑待复核；儿童试用未进行；本次故事修订未做游戏验收。','', '**来源：**']
        for ref in o['source_ids']:
            s=sources[ref];r=','.join(s['region_ids']) or '图片行定位，无精确region'
            cards.append(f"- {s['section']}：印刷{s['page']}页／文件{s['file_page']}页，{r}；行“{s['row_label']}”；表内引用课文页{s.get('listed_lesson_page') if s.get('listed_lesson_page') is not None else '未列'}。[页图](<{Path(s['image_absolute']).as_posix()}>)")
        if o['notes']:cards+=['',f"**编辑注：** {o['notes']}"]
        cards+=['','---','']
    write_text(f'cards/{short}.md','\n'.join(cards))


def render_csv(occurrences,lexemes,stories,sources):
    output=io.StringIO(newline='');fields=['book_id','spelling','meaning_zh','kind','requirement','unit_numbers','lexeme_id','story_id','letter_chain','story_title','story_text','recall_question','meaning_anchor','frames','storage','transfer','source_locations','audio_status','human_editor','child_trial']
    writer=csv.DictWriter(output,fieldnames=fields);writer.writeheader()
    for o in occurrences:
        s=stories[o['story_id']]; row={k:o[k] for k in ['book_id','spelling','meaning_zh','kind','requirement','lexeme_id','story_id']}
        row.update(unit_numbers=','.join(map(str,o['unit_numbers'])),letter_chain=' → '.join(f"{t['letter_position']}:{t['raw']}={t['anchor_zh']}({t['occurrence']})" for t in lexemes[o['spelling']]['letter_chain']),
            story_title=s.get('narrative',{}).get('title',''),story_text=s.get('narrative',{}).get('text',''),recall_question=s.get('narrative',{}).get('recall_question',''),
            meaning_anchor=o['occurrence_meaning_anchor'],frames='\n'.join(f['text'] for f in s['frames']),storage=s['storage']['root_location']+' / '+s['id'],transfer=o['occurrence_transfer_task'],
            source_locations='; '.join(f"{sources[r]['book_id']} 印刷{sources[r]['page']}/文件{sources[r]['file_page']}/{','.join(sources[r]['region_ids']) or 'image-only'}" for r in o['source_ids']),
            audio_status=o['audio']['status'],human_editor='pending',child_trial='not_conducted')
        writer.writerow(row)
    p=ROOT/'data'/'all_occurrences.csv';p.write_text(output.getvalue(),encoding='utf-8-sig',newline='')


def render_scope(catalog,manifests):
    lines=['# 教材范围与计数口径','',
           '源库只读：`D:/Project/Englishbook/public/library.json` 及其八册 `books/*.json`。页面图像以各页 `image` 字段相对于 public 定位。原PDF、页图、音频及Blender资产未修改。','',
           '## 计数定义','',
           '- **正式表面形式组**：教材一行中以同一写法列出的词项组，例如 `father (dad)` 算一个组。不同正式表重复列出同一组不重复计。',
           '- **册内策划目标**：展开后的可逐字符重建形式。father、dad各一项；foot、feet各一项；I\'m、I am各一项。数字序数、模式与缩写另分类。',
           '- **唯一拼写**：保留大小写、空格、连字符和撇号，弯撇号统一为ASCII撇号后完全相同才合并；不同含义仍共用一个lexeme_id，并有固定意义页/补充镜头。',
           '- **跨册复用**：某拼写在更早册已出现，首次册按三上→三下→四上→四下→五上→五下→六上→六下排序。它不代表孩子已经学会，也不改变当前教材要求。',
           '- **故事数**：核心意义页加补充义项场景分别统计，不把同一故事在多册引用重复算成新故事。全部故事为新编策划，不是教材故事复刻。','',
           '## 逐册版本、范围和类别','',
           '| 册 | 源库版本标签 | 单元 | 普通词 | 词组/表达 | 专名 | 缩略/模式/数字记号 | 册内唯一目标 |',
           '|---|---|---:|---:|---:|---:|---:|---:|']
    for b in catalog['books']:
        k=b['kind_counts'];other=sum(v for key,v in k.items() if key not in {'word','phrase','proper_name'})
        lines.append(f"| {b['title']} | {b['edition']} | {b['unit_count']} | {k.get('word',0)} | {k.get('phrase',0)} | {k.get('proper_name',0)} | {other} | {b['unique_spellings']} |")
    lines+=['','各类别互斥，proper_name优先于phrase；例如Children\'s Day是节日专名，即使含空格也不重复计词组。连字符词可在ordinary word内；不要用空格数量推断教材词数。精确类别与原始表面形式保存在JSON。','',
            '## 教学要求按书保留','',
            '| 册 | 听说读写 | 认读 | 听说认读 | 仅听说 | 未区分 |','|---|---:|---:|---:|---:|---:|']
    for b in catalog['books']:
        r=b['requirement_counts']
        lines.append(f"| {b['title']} | {r.get('listen_speak_read_write',0)} | {r.get('recognition',0)} | {r.get('listen_speak_read',0)} | {r.get('listen_speak',0)} | {r.get('not_distinguished',0)} |")
    lines+=['','五下、六下源库版本标签为“三年级起点版”，与其他册“2022年课标修订版”不相同，不擅自统一版本。表首说明显示旧版黑体为听说认读、白体为听说，不能当作新版四会/认读口径。','',
            '## 表外内容的边界','',
            '本交付对正式词表作穷尽转录和逐项故事策划。正式表中列出的蓝体、白体、星号词及专名均进入目标。课文中未列入正式表的专名、完整句子、练习题干、扩展阅读词和附录图板并未按任意英文空格拆成词库。它们仍属于可查教材内容，本次明确列为“表外上下文/另立范围”，不声称已逐词穷尽。',
            '若后续要求连附录图板和所有课文额外词都建卡，应以页图确认的词项为单位新增来源和目标，复用本库已有lexeme，不把源OCR碎片当新词。本次不把这项未来扩展隐藏为已完成。','']
    chapter_inventory=[]
    for b in catalog['books']:
        m=manifests[b['book_id']]
        lines += [f"### {b['title']}",'','| 章节 | 印刷页 | 文件页 | 本次口径 |','|---|---|---|---|']
        for c in m['chapters']:
            formal=c['title'].startswith(('Vocabulary','Word List'))
            mode='正式词表：全部建卡' if formal else '正文：词项以正式词表为主，句子/额外词仅作上下文' if c['id'].startswith('unit-') else '表外目录/附录/扩展/测评：未拆词纳入'
            ps=c.get('printedStart'); pe=ps+c['end']-c['start'] if isinstance(ps,int) else None
            lines.append(f"| {md(c['title'])} | {str(ps)+'–'+str(pe) if ps is not None else '未标'} | {c['start']}–{c['end']} | {mode} |")
            chapter_inventory.append({'book_id':b['book_id'],**c,'vocabulary_scope':mode})
    lines+=['','## 来源定位','',
            '`source.page`是承载词表的印刷页，`source.file_page`是该页在文件中的序号。`listed_lesson_page`是词表行末列出的课文引用页，三者不混用。若正式单元表与字母表给出的单元/页码不同，保留两条证据和作者纠错说明；不静默修改教材。',
            '`sourceVerified`、`reviewed`保存原manifest状态；本次助手看图与它们分离。`image_row_only`表示页图确有词条但JSON没有可靠区域，依file_page与row_label定位。附近区域只能作邻近定位，不能当作精确词条匹配。','',
            '归一化仅处理明确的排版/词表说明：弯撇号、括号变体、复数标记、缩略等式及经页图确认的OCR错字。修改记录留在各册作者稿和源审计文件中；源库完全只读。']
    write_text('教材范围与计数口径.md','\n'.join(lines));write_json('review/chapter_scope.json',chapter_inventory)


def render_examples(catalog,stories,lexemes,sources):
    chosen=['nose','book','apple','school','football','pencil case','T-shirt',"o'clock",'café','from... to...','1st','No.','p.m.']
    lines=['# 可检验的重点样例','',
           '以下卡来自完整词库，不是覆盖范围的替代。每次出现的字母都有位置编号；重复形象仍为同一个固定地标。完整读音另播，故事不构成词源或发音规则。','']
    for w in chosen:
        if w not in lexemes:continue
        lx=lexemes[w];o=next(x for x in catalog['occurrences'] if x['spelling']==w);s=stories[o['story_id']]
        b=next(b for b in catalog['books'] if b['book_id']==o['book_id']);short=f"g{b['grade']}-{b['volume']}"
        lines += [f'## {w}', '',f"教材义项：{o['meaning_zh']}。固定存放：{s['storage']['root_location']}。[完整卡](cards/{short}.md#{o['id']})。",'']
        if s.get('narrative'):
            lines += [f"**完整故事：{s['narrative']['title']}**",'']
            for paragraph in s['narrative']['paragraphs']:lines+=['> '+paragraph,'']
            lines += [f"**想象接续问题：** {s['narrative']['recall_question']}",'']
        lines += ['| 字母位置 | 原字形 | 固定形象 | 本词第几次 | 动作 |','|---:|---|---|---:|---|']
        for x in s['steps']:lines.append(f"| {x['letter_position']} | {x['raw']} | {x['anchor_en']}／{x['anchor_zh']} | {x['occurrence']} | {md(x['action'])} |")
        lines+=['',f"意义连接：{s['meaning_anchor']}",f"新情境：{o['occurrence_transfer_task']}"]
        if s['orthography_events']:lines.append('书写事件：'+'；'.join(f"字符位{x['surface_position']} `{x['raw']}`，{x['instruction']}" for x in s['orthography_events']))
        lines+=['','检验：遮住字母后按形象复原；再遮住形象写回字符；最后用新情境独立检查意思。完整示范后正确和独立正确分开记录。','']
    lines+=['## 同拼写的跨册处理','',
            'can能力义复用三上故事，六上“罐；听”在同一主册新增罐子意义页；不能把C地标从Cake改成Can。cold天气冷与感冒分别有意义页。park、with、make保留第一次核心故事；后册再现相同意思直接复用，新增的停放/工具/制定等放入具名补充镜头，不能因为中文释义标点或顺序不同另起故事。','',
            '若孩子想不出画面，先教意思并给一镜；若顺序乱，按编号接力；若会故事不会拼写，单独练地标到字母；若拼对却不懂，收起故事换新场景检查。详细话术见引导规范。']
    write_text('重点样例.md','\n'.join(lines))


def render_overview(catalog,report,reuse):
    narrative=report.get('narrative_revision') or {}
    learning=catalog['current_runtime_evidence'].get('existing_learning_package_report')
    learning_note=(f"现有学习包构建记录包含{learning['entries']}条词条，内容版本为`{learning['content_revision']}`。本策划内容版本为`{catalog['content_revision']}`；两者版本是否一致：{'是' if learning['matches_planning_content_revision'] else '否'}。该记录不是运行验收结果。" if learning else '本次未读取到独立学习包的构建记录。')
    rows=['| 册 | 词表文件页 | 表面形式组 | 册内目标／唯一拼写 | 既有拼写复用 | 新见拼写 |','|---|---|---:|---:|---:|---:|']
    for b in catalog['books']:
        short=f"g{b['grade']}-{b['volume']}"
        rows.append(f"| [{b['title']}](books/{short}.md) | {', '.join(str(i) for i in b['visual_reviewed_file_pages'])} | {b['source_row_groups']} | {b['occurrences']}／{b['unique_spellings']} | {b['reused_from_prior_books']} | {b['new_spellings']} |")
    text=f"""# 八册教材完整正式词表与逐字母记忆策划

日期：{catalog['date']}。版本：{catalog['planning_version']}。状态：可审阅策划稿，本版故事未做游戏验收。

全局规则入口：[GDD](../../../GDD.md)。内容权威仍是本目录的教材来源、词条与故事，GDD不替代教材事实。整合问题与修改证据见[整合核查与修订](整合核查与修订.md)。

八册正式 Vocabulary / Word List / Word List I / Word List II 的并集已形成 {report['book_occurrences']} 条册内策划、{report['unique_spellings']} 个不同拼写目标、{report['story_sense_pages']} 个固定核心意义故事页，另有 {report['additional_sense_scenes']} 个固定补充义项镜头（{report['additional_sense_scene_book_references']} 次册内引用）。共 {report['formal_pages']} 张正式词表页由智能助手实际查看；独立人工编辑与儿童试用仍待进行。

“完整”严格指本项目现有八册的正式词表并集，包括认读词、词组、专名、括号形式和缩略式展开；不指全书每句课文的所有拆分词、人名、附录图板或全部语言知识点均已游戏化。计数不等于孩子必须拼写的词数。仅听说、认读词保留教材原要求，不升级为强制拼写关卡。

{chr(10).join(rows)}

## 阅读入口

- [记忆故事与想象引导规范](记忆故事与想象引导规范.md)：固定地标、重复字母、空格、撇号、连字符、大小写、长词与四类困难。
- [重点样例](重点样例.md)：nose、book、apple、school、football 和复杂书写边界。
- [完整故事扩写对照](故事扩写对照.md)：先读自然连贯的正文，再看原稿与逐字母绑定；全库核心和补充义项均有完整扩写。
- 各册目录 `books/*.md` 可点击进入对应 `cards/*.md` 的完整故事卡；各册 JSON 自带来源和完整提示。
- [全库 JSON](data/catalog.json)、[全部册内 CSV](data/all_occurrences.csv)、[跨册复用关系](data/cross_book_reuse.json)。
- [主线接入合同](data/integration_contract.json)、[1314条真实词条适配表](data/mainline_entries.json)、[整合静态核验](review/integration_validation.json)：保持原entry/lexeme/story身份、六级帮助、任务许可与完整字符。
- [验证报告](验证报告.md)、[自动核验 JSON](review/validation.json)、[逐页来源审计](review/source_pages.json)、[源文件保护核验](review/source_preservation.json)。
- [v2叙事结构核验](review/narrative_validation.json)、[导出与原身份核验](review/narrative_publication_validation.json)、[v2叙事语义抽查](review/narrative_editorial_review.md)、[版本映射](data/narrative_revision_map.json)。
- 首轮v1记录：[样例核验](review/acceptance_examples.json)、[三年级复核](authoring/g3-independent-review.md)、[长词与跨册复用复核](authoring/cross-grade-story-review.md)；它们保留旧版发现和处理，不作为v2新文案的复核结论。
- [教材范围与计数口径](教材范围与计数口径.md)明确版本、表外内容边界和词形展开规则。

## 实装边界

本次读取到 `game/project.godot` 版本 {catalog['current_runtime_evidence']['project_version']}。原有课程数据文件记录三上前三单元的 {catalog['current_runtime_evidence']['curriculum_question_count']} 道情境题、{catalog['current_runtime_evidence']['curriculum_phrase_count']} 条表达及 {catalog['current_runtime_evidence']['packaged_audio_count']} 条合成语音；这些旧课程计数不代表当前游戏全部学习内容。

{learning_note} 本次只修订本目录的策划、故事和适配数据，没有重新生成游戏学习包或执行本版故事的运行验收，不能据策划文件存在宣称新文案已可玩。

音频字段只列文字完全相同且文件存在的候选。原库有缓存不等于游戏已接入；候选未听检，其他条目明确待制作或改编，全部故事旁白待制作。没有儿童试用数据，没有记忆提升率或效果结论。

## 可复现核验

```powershell
python -X utf8 F:/LoveStudy/docs/planning/vocabulary/scripts/build_package.py
python -X utf8 F:/LoveStudy/docs/planning/vocabulary/scripts/verify_narrative_revision.py
```

脚本只读取原教材及当前课程证据，只在本目录写输出；不用运行游戏、Blender、导入课程或发布。作者稿与修复记录保留在 `authoring/`。正式接入前应完成人工编辑复核、音频制作与听检、儿童可用性试用及单独的开发验收。
"""
    write_text('README.md',text)
    evidence=f"""# 验证报告

{catalog['date']}，策划 {catalog['planning_version']}。自动结果：**{report['status']}**。

| 项目 | 结果 |
|---|---:|
| 八册 / 正式词表页 | {report['books']} / {report['formal_pages']} |
| 册内策划目标 | {report['book_occurrences']} |
| 跨册唯一拼写 | {report['unique_spellings']} |
| 固定意义故事页 | {report['story_sense_pages']} |
| 固定补充义项镜头 / 册内引用 | {report['additional_sense_scenes']} / {report['additional_sense_scene_book_references']} |
| 各意义故事页逐字母动作总量 | {report['letter_steps']} |
| 跨册复现拼写 | {report['cross_book_spellings']} |
| 仅页图定位的来源记录 | {report['image_only_sources']} |
| 未对账的词表内容区域 | {report['unreferenced_content_regions']} |
| 源库索引与八册JSON哈希不变 | {report['source_manifests_unchanged']} |

核验包括全部条目的字符重建、字母顺序、26个固定映射、重复实例编号、动作数量、引用完整性和跨册故事引用。源表页数与作者实际看图页清单一致；自动匹配不能代替词义或故事质量人工审核。无精确region的条目使用图片行定位，见各册来源，不伪造区域。

本次叙事扩写：{narrative.get('core_stories',0)}篇核心故事、{narrative.get('supplemental_stories',0)}篇补充故事、{narrative.get('narrative_letter_beats',0)}个逐字母叙事格，结构结果为{narrative.get('status','未启用')}。这些检查只确认结构和覆盖，不把更长的文字或句子数量当作通顺性、记忆效果或儿童接受度证据。完整检查数据见 [叙事核验JSON](review/narrative_validation.json)，正文语义抽查范围和处理见 [v2叙事审阅](review/narrative_editorial_review.md)，新旧动作与稳定ID见 [版本映射](data/narrative_revision_map.json)。

其中{narrative.get('shared_same_meaning_records',0)}个既有补充记录与同义核心页或较早补充页共用正文，保留各自ID，共有{narrative.get('distinct_narrative_texts',0)}篇不同正文。相同意思不因记录类型或中文标点而另换情节。

整合适配保持1314个册内entry、1073个拼写、1096个核心故事ID；81单元共1359个词条关联，其中45条跨两个单元。H0–H5帮助合同、708条四会/358条认读/146条听说认读/102条仅听说的任务许可、26个真实SG序章入口均有独立静态核验，见 `review/integration_validation.json`。故事页仍是持久内容索引，未自动绑定地图实体位置。

同一核心义项和补充义项在本版本中使用统一镜头，后册复用动作并保留本册迁移任务。此次用户要求对全部故事扩写，内容版本已更新，原ID、位置和词义保留，旧稿完整归档。例如 with 的“用 / 用……”仍共用画笔镜头，五下剪刀任务保留为迁移练习；fly、litter、think 的相同补充义项也合并引用，不重复计为新故事。

各册原始词表区域全部都有“引用、页眉/字母栏标识、明确排除或待对账”之一，详见 `review/source_pages.json` 与 `review/unreferenced_regions.json`。单元表和字母表重复来源保留；源OCR状态不等于最终复核。原始版本、印刷页、文件页、表内引用课文页与区域文本均可追踪。

本次智能助手页面核对已完成；独立人类编辑复核待完成。第二位智能助手的复核意见另存作者审计文件，不计为人类复核。儿童试用未开展，学习效果未验证。未运行游戏全量测试，因为没有运行代码变更；没有执行构建发布或替换引擎。

首轮v1记录见 [acceptance_examples.json](review/acceptance_examples.json)。当时三年级复核重新查看全部14张正式词表页，并对46条故事作语义抽查；另一次全库抽查阅读了最长30个目标及书写边界、近形词、多义词，合计60个不同拼写。旧版范围和发现处理分别见 [三年级复核](authoring/g3-independent-review.md)、[长词与跨册复用复核](authoring/cross-grade-story-review.md)。这些历史记录保留来源复核证据，不表示已检查过v2全部新文案。

音频仅做候选文件存在检查，没有全词库听检、录音或复制；未把原库合成语音候选算成已打包游戏资源。书面提示与字母动作的自动通过不表示语音、儿童理解和长期回忆通过。
"""
    write_text('验证报告.md',evidence)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--inventory-only',action='store_true')
    main(parser.parse_args().inventory_only)
