"""Build grade-six planning author data; read source manifests without changes."""
import json, re, hashlib
from collections import Counter
from pathlib import Path

BASE=Path(__file__).parent
PUBLIC=Path(r'D:\Project\Englishbook\public')

# Transcribed from every actual Word List page on 2026-10-22.
# page|spelling|textbook gloss|printed lesson page|black=1, blue/light=0|unit (g6 lower)
UPPER='''
78|age|年龄|33|1
78|air|空气|30|1
78|always|总是|6|1
78|a.m.|上午|6|0
78|away|相距；离开|43|0
78|bad|严重的；坏的|10|1
78|bar|条；棒|27|0
78|bean|豆子|11|0
78|biscuit|饼干|26|0
78|both|（两者）都|58|0
78|bottle|瓶子|26|0
78|box|盒；盒子|5|1
78|bright|明亮的|11|0
78|bring|带来|26|1
78|camp|营地|2|0
78|can|罐；听|27|1
78|candy|糖果|27|1
78|carry|提；拿|32|0
78|catch|患（病）|53|1
78|celebrate|庆祝|14|0
78|centre|中心|33|0
78|check|检查|51|0
78|chocolate|巧克力|27|0
78|Christmas|圣诞节|56|0
78|city|城市|3|1
78|clay|黏土；泥土|46|0
78|close|接近的；关上|13|1
78|cola|可乐|27|0
78|cold|感冒|51|1
78|college|大学|33|0
78|colourful|彩色的|5|0
78|cough|咳嗽|51|0
78|countryside|乡村；农村|28|0
78|decorate|装饰|56|0
78|delicious|美味的|4|0
78|different|不同的|4|0
78|drive|开车；驾驶|43|0
78|drop|（一）滴|41|0
78|during|在……期间|1|0
78|elderly|年老的|31|0
78|else|另外；其他|5|0
79|enjoy|喜爱；享受|11|0
79|enough|足够的|10|0
79|fall|发生；降临|58|0
79|farm|农场|1|1
79|fever|发烧|51|0
79|forecast|预报|21|0
79|fresh|新鲜的|30|0
79|full|完整的；满的|11|0
79|go shopping|去购物|2|1
79|grandparent|祖父（母）；外祖父（母）|1|0
79|greet|问候|57|0
79|ham|火腿|58|0
79|headache|头痛|51|0
79|health|健康|13|0
79|heavy|大量的；重的|21|1
79|himself|他自己|31|0
79|holiday|假日；假期|1|1
79|homework|家庭作业|7|1
79|hurt|伤害|8|1
79|ill|有病的；不适的|53|1
79|instead of|代替……；而不是……|42|0
79|joy|欢乐|58|0
79|kill|捕杀|42|0
79|leave|休假|54|0
79|lifestyle|生活方式|30|0
79|lotus|莲花|11|0
79|loud|大声的|48|0
79|make friends|交朋友|33|1
79|matter|事情；问题|51|0
79|medicine|药|15|0
79|merry|快乐的|57|0
80|message|信息|24|0
80|milk|牛奶|27|1
80|minute|分钟|43|1
80|miss|想念|13|0
80|mooncake|月饼|11|0
80|Ms|女士|33|1
80|name|说出……的名称|8|1
80|need|需要|25|0
80|never|从不|6|1
80|note|便条|54|0
80|observe|观察|8|0
80|often|常常；时常|4|1
80|once|曾经|48|0
80|open|打开|13|1
80|outing|短途旅行|28|0
80|picnic|野餐|26|0
80|poem|诗歌|11|0
80|pot|罐；瓶|27|0
80|pudding|布丁|58|0
80|rain|雨；下雨|21|1
80|receive|收到|56|0
80|relax|休息；（使）放松|28|0
80|rest|休息|51|0
80|road|道路|24|0
80|safe|安全的|23|1
80|sandy|多沙的|28|0
80|Santa Claus|圣诞老人|56|0
80|save|节约；拯救|41|0
80|seed|种子|11|0
80|sell|卖|30|1
80|share|分享|30|1
80|Shibadong Village|十八洞村|1|0
80|should|应该|24|1
80|shouldn't=should not|不应该（缩略式与完整形式）|41|1
80|singer|歌手；歌唱家|48|0
80|sit|坐|14|1
80|soldier|士兵；战士|13|0
80|sometimes|有时|6|1
80|song|歌曲|31|1
80|sound|听起来|1|0
80|soup|汤|3|1
81|stay|停留|2|0
81|storm|暴风雨；暴风雪|23|0
81|tap|龙头|41|0
81|taste|品尝；有……的味道|11|0
81|tear|眼泪；泪水|13|0
81|than|比|46|0
81|the Great Wall|长城|1|1
81|the Mid-Autumn Festival|中秋节|11|0
81|the West Lake|西湖|3|0
81|Tian'anmen Square|天安门广场|1|0
81|travel|旅行|1|1
81|turkey|火鸡|58|0
81|turn off|关闭|41|1
81|type|类型；种类|11|0
81|very|很；非常|3|1
81|village|村庄|1|0
81|visit|看望；参观|1|1
81|wait for|等待|8|1
81|waste|浪费|41|0
81|wave|挥手|6|0
81|weather forecast|天气预报|21|0
81|weekday|工作日|6|0
81|west|西；西方|3|0
81|wild|野生的|42|0
81|will|将要|21|1
81|wind|风|21|0
81|won't=will not|将不会（缩略式与完整形式）|21|1
81|wrong|不正确的|43|1
81|yogurt|酸奶|26|0
81|zoo|动物园|23|1
'''

LOWER='''
78|a piece of|一块|5|1|2
78|afraid|害怕的|33|1|7
78|air|空气|17|1|4
78|aloud|大声地|26|1|6
78|Big Ben|大本钟|41|1|9
78|building|大楼|19|0|4
78|change|改变|19|0|4
78|clever|聪明的|33|1|7
78|close|关；闭|33|1|7
78|cross|穿过|5|1|2
78|dangerous|危险的|8|0|2
78|different|不同的|41|0|9
78|difficult|困难的|33|1|7
78|difficulty|困难|33|0|7
78|drop|落下|5|1|2
78|Earth|地球|21|1|5
78|easy|容易的|25|1|6
78|exam|考试|36|0|7
78|exercise|锻炼；练习|9|1|3
78|face|面对；面向|23|0|5
78|fairy|仙女；小精灵|7|0|2
78|fairy tale|童话故事|7|0|2
78|grandparent|（外）祖父／母|1|1|1
78|half|一半|23|0|5
78|happily|高兴地|5|1|2
78|healthy|健康的|9|1|3
78|hour|小时|11|0|3
78|its|它的|5|1|2
78|jog|慢跑|9|1|3
78|keep|保持|9|1|3
79|kid|小孩|33|1|7
79|land|陆地；土地|19|1|4
79|look after|照顾；照料|18|0|4
79|lose|失去|5|1|2
79|meat|肉|5|1|2
79|mine|我的（名词性物主代词）|5|0|2
79|monster|怪物|33|0|7
79|move|移动|25|1|6
79|ourselves|我们自己|2|0|1
79|party|聚会|37|1|8
79|piano|钢琴|26|1|6
79|place|地方；地点|17|1|4
79|places of interest|名胜古迹|42|1|9
79|pool|池子|35|0|7
79|reply|答复；回应|35|0|7
79|ride|骑（自行车／马等）|1|1|1
79|sandy|沙质的；多沙的|3|0|1
79|science|科学|7|0|2
79|season|季节|23|0|5
79|space|太空|21|1|5
79|step|台阶|35|0|7
79|step on|踩|25|1|6
79|still|仍然|33|0|7
79|swimwear|游泳衣|35|0|7
79|take care of|照顾|9|1|3
79|the Eiffel Tower|埃菲尔铁塔|41|1|9
79|the Golden Gate Bridge|金门大桥|41|1|9
79|the Great Wall|长城|41|1|9
79|tired|累的；疲倦的|33|1|7
79|together|在一起|1|1|1
79|travel|旅行|41|1|9
79|Tree Planting Day|植树节|17|1|4
79|wood|木头|5|1|2
79|worry|焦虑；担心|33|1|7
'''

# Explicit corrections are attached to original region IDs, not silently rewritten.
CORRECTIONS={
 'xiangshao-g6-2':{
  (77,'p77-r2'):'land',(77,'p77-r10'):'step on',(77,'p77-r11'):None,
  (77,'p77-r14'):'a piece of',(77,'p77-r15'):None,(77,'p77-r17'):'happily',(77,'p77-r18'):None,
  (77,'p77-r21'):'wood',(77,'p77-r22'):'afraid',(77,'p77-r31'):'take care of',(77,'p77-r32'):None,(77,'p77-r33'):None,
  (77,'p77-r35'):'healthy|keep',(77,'p77-r37'):'exercise',(77,'p77-r39'):'jog',(77,'p77-r47'):'air',
  (77,'p77-r57'):'places of interest',(77,'p77-r58'):'space',
  (78,'p78-r8'):None,(78,'p78-final-2'):'fairy',(78,'p78-r17'):None,(78,'p78-r31'):'different',
  (79,'p79-r15'):'meat',(79,'p79-r16'):None,(79,'p79-r19'):'mine',(79,'p79-r23'):'move',
  (79,'p79-r24'):'take care of',(79,'p79-r25'):None,(79,'p79-r26'):None,
  (79,'p79-r27'):'the Eiffel Tower',(79,'p79-r30'):'the Great Wall',(79,'p79-r31'):'tired',
  (79,'p79-r37'):'Tree Planting Day',(79,'p79-r38'):'places of interest',(79,'p79-r39'):'pool'
 }
}
RELATED={
 (77,'a piece of'):['p77-r14','p77-r15'],(77,'happily'):['p77-r17','p77-r18'],
 (78,'a piece of'):['p78-final-1','p78-r8'],
 (77,'step on'):['p77-r10','p77-r11'],(77,'take care of'):['p77-r31','p77-r32','p77-r33'],
 (78,'fairy tale'):['p78-final-3','p78-r17'],(79,'meat'):['p79-r15','p79-r16'],
 (79,'take care of'):['p79-r24','p79-r25','p79-r26']
}

PROPER={'Christmas','Santa Claus','Shibadong Village','the Great Wall','the Mid-Autumn Festival','the West Lake',"Tian'anmen Square",'Earth','Big Ben','the Eiffel Tower','the Golden Gate Bridge','Tree Planting Day','Ms'}

def build_book(bid,rows):
 d=json.loads((PUBLIC/'books'/f'{bid}.json').read_text(encoding='utf-8-sig'))
 lower=bid.endswith('-2')
 table_pages=list(range(77,80)) if lower else list(range(75,82))
 normalized=[]
 corrections=[]
 for p in d['pages']:
  if p['id'] not in table_pages: continue
  for r in p['regions']:
   txt=r['text'].replace('’',"'")
   corr=CORRECTIONS.get(bid,{}).get((p['id'],r['id']),txt)
   if corr!=txt: corrections.append({'file_page':p['id'],'region_ids':[r['id']],'original':txt,'corrected':corr,'evidence':'actual_page_image_checked_by_assistant'})
   if corr is not None:
    for s in corr.split('|'): normalized.append((p,r,s))
 entries=[]
 for row in rows.strip().splitlines():
  cells=row.split('|'); fp=int(cells[0]); surface=cells[1]; zh=cells[2]; lesson=int(cells[3]); strong=cells[4]=='1'
  forms=surface.split('=')
  for form_index,spelling in enumerate(forms):
   matches=[(p,r,s) for p,r,s in normalized if s==surface or s==spelling]
   sources=[]
   for p,r,s in matches:
    section=('Word List I' if p['id']==77 else 'Word List II') if lower else ('Vocabulary' if p['id']<78 else 'Word List')
    ids=RELATED.get((p['id'],s),[r['id']]) if lower else [r['id']]
    sources.append({'file_page':p['id'],'page':p['printedPage'],'region_ids':ids,'row_label':surface+' '+zh,'listed_lesson_page':lesson if p['id']==fp else None,'section':section,'image':p['image'],'raw_region_text':[x['text'] for x in p['regions'] if x['id'] in ids],'sourceVerified':[x.get('sourceVerified') for x in p['regions'] if x['id'] in ids],'reviewed_in_source':[x.get('reviewed') for x in p['regions'] if x['id'] in ids]})
   if not any(s['file_page']==fp for s in sources):
    p=next(p for p in d['pages'] if p['id']==fp)
    sources.append({'file_page':fp,'page':p['printedPage'],'region_ids':[],'row_label':surface+' '+zh,'listed_lesson_page':lesson,'section':'Word List II','image':p['image'],'no_exact_region':True,'evidence':'printed row visible in image but absent from manifest regions'})
   units=[]
   if lower: units=[int(cells[5])]
   else:
    # Track two-column unit vocabulary, then also preserve referenced lesson unit.
    active=0
    for p in d['pages']:
     if not 75<=p['id']<=77: continue
     for r in sorted(p['regions'], key=lambda r:(int(r['rect'][0]>=.5),r['rect'][1])):
      m=re.fullmatch(r'Unit (\d+)',r['text'])
      if m: active=int(m.group(1))
      elif r['text'].replace('’',"'")==surface and active: units.append(active)
    for c in d['chapters']:
     if c['id'].startswith('unit-') and c.get('printedStart',999)<=lesson<=c.get('printedStart',999)+c['end']-c['start']:
      units.append(int(c['id'].split('-')[1]))
   kind='proper_name' if spelling in PROPER else ('contraction' if "'" in spelling and not spelling.startswith('Tian') else 'phrase' if ' ' in spelling else 'word')
   requirement=(('listen_speak_read' if strong else 'listen_speak') if lower else ('listen_speak_read_write' if strong else 'recognition'))
   e={'spelling':spelling,'meaning_zh':zh if len(forms)==1 else ('不应该' if surface.startswith('should') else '将不会'),'meaning_source':'textbook_image_gloss' if len(forms)==1 else 'authored_gloss_of_textbook_expansion', 'kind':kind,'requirement':requirement,'requirement_normalized':requirement,'requirement_source_text':('黑体：听、说、认读' if strong else '白体：只作听、说要求') if lower else ('黑体：听、说、读、写' if strong else '蓝体：只作认读要求'),'sources':sources,'unit_numbers':sorted(set(units)),'surface_group':surface,'variant_relation':({'type':'contraction' if form_index==0 else 'expansion','partner':forms[1-form_index]} if len(forms)>1 else None),'notes':''}
   if spelling=='a.m.': e['notes']='教材原样含两个句点；按 a-.-m-. 保留，句点不映射字母地标。'
   if lower and spelling=='land': e['notes']='Word List I 归 Unit 5；Word List II 标 Unit 4 / p19，两种教材定位并存，未擅自纠正。'; e['unit_numbers']=[4,5]
   if lower and spelling=='drop': e['notes']='六上是名词“一滴”，六下是动词“落下”；同字母链须增义项分支。'
   if lower and spelling=='air':
    e['notes']='Word List II 图片有本行，源区域遗漏。'
    next(s for s in sources if s.get('no_exact_region'))['visual_location']='左栏 A 分栏第3行，afraid 下、aloud 上。'
   if lower and spelling=='lose':
    e['notes']='Word List II 图片有本行，源区域遗漏。'
    next(s for s in sources if s.get('no_exact_region'))['visual_location']='左栏 L 分栏第3行，look after 下、M 分栏标题上。'
   if lower and spelling=='a piece of':
    e['notes']='页78的 p78-r8 是同一印刷行词组开头 a 的原碎片；修复区域 p78-final-1 的文本已包含这个 a，两者合并定位但不得重复拼接成 a a piece of。'
    for s in sources:
     if s['file_page']==78:
      s['source_merge_note']='p78-r8 位于同一行 a piece of 的开头；p78-final-1 由原 piece/of 区域修复为完整词组，文本语义已覆盖该 a。两个区域共同提供位置证据，规范化结果只保留一个 a。'
   if spelling in {'name','can','leave','fall','catch','cold','sound','once'}: e['notes']+='本册义项需特别保留，不以最常见义替换。'
   entries.append(e)
 # Attach unit and source-image row identity, without upgrading source flags to human approval.
 for e in entries:
  for s in e['sources']:
   s['verification']='assistant_visual_transcription_checked_2026-10-22'
   s['independent_human_review']='pending'
   s['region_role']='exact_or_grouped_ocr_row' if s['region_ids'] else 'absent_from_manifest_visual_row_only'
   if s.get('source_merge_note'):s['region_role']='same_printed_row_overlapping_ocr_text'
 return {'book_id':bid,'visual_reviewed_file_pages':table_pages,'entries':entries,'exclusions':[{'kind':'heading','items':['Vocabulary','Word List','Word List I','Word List II','Unit','Page','A–Z 分栏字母'],'reason':'版面标题或分类标签，不计入词汇目标'}],'corrections':corrections}

def main():
 books=[build_book('xiangshao-g6-1',UPPER),build_book('xiangshao-g6-2',LOWER)]
 stories={}
 for path in sorted(BASE.glob('g6-stories-*.json')):
  more=json.loads(path.read_text(encoding='utf-8'))
  assert not (stories.keys() & more.keys()),path
  stories.update(more)
 for path in sorted(BASE.glob('g6-storydraft-*.txt')):
  for line in path.read_text(encoding='utf-8').splitlines():
   if not line.strip() or line.startswith('#'):continue
   word,setting,anchor,actions,transfer,*rest=line.split('|')
   assert word not in stories,word
   stories[word]={'setting':setting,'meaning_anchor':anchor,'actions':actions.split('/'),'transfer':transfer,'contrast':rest[0] if rest else '按全部字母位置回忆；字母地标名称不当作词内发音规则。'}
 if 'drop' in stories:
  stories['drop']['sense_extensions']=[{'book_id':'xiangshao-g6-1','meaning_zh':'（一）滴','meaning_anchor':'停格指向鼓边悬着的一滴水，关注可数的一滴。','transfer':'在新图里选择 a drop of water，而非整杯水。'},{'book_id':'xiangshao-g6-2','meaning_zh':'落下','meaning_anchor':'播放同一水滴从托盘落入南瓜盘的动作，关注落下过程。','transfer':'听 drop，让模型小球落入软垫，描述动作。'}]
 if 'close' in stories:
  stories['close']['sense_extensions']=[{'book_id':'xiangshao-g6-1','meaning_zh':'接近的','meaning_anchor':'门与门框的距离越来越小，停在很接近却未闭合的一格。','transfer':'在新配物图里选择 close to 的一对物品。'},{'book_id':'xiangshao-g6-1','meaning_zh':'关上','meaning_anchor':'继续同一故事，把门完全闭合。','transfer':'听 close the box，合上新盒子的盖子。'},{'book_id':'xiangshao-g6-2','meaning_zh':'关；闭','meaning_anchor':'复用六上闭合门的核心镜头。','transfer':'离开新房间时按 close the door 关门。'}]
 result={'grade':6,'books':books,'stories':stories,'review':{'assistant_visual_page_check':'complete','independent_human_editor_review':'pending','child_trial':'not_conducted'}}
 (BASE/'g6.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 targets={e['spelling'] for b in books for e in b['entries']}
 print('books',[(b['book_id'],len(b['entries'])) for b in books], 'unique',len(targets),'stories',len(stories))
 missing=sorted(targets-stories.keys()); print('MISSING',missing)
 errors=[]
 for word,s in stories.items():
  n=len(re.findall('[A-Za-z]',word))
  if len(s['actions'])!=n: errors.append((word,n,len(s['actions'])))
 print('LENGTH_ERRORS',errors)
 for b in books:
  print(b['book_id'],'without exact region',[(e['spelling'],s['file_page']) for e in b['entries'] for s in e['sources'] if s.get('no_exact_region')])
 audit={'date':'2026-10-22','status':'pass' if not missing and not errors else 'fail','missing_stories':missing,'letter_action_count_errors':errors,'unique_story_count':len(stories),'total_letter_actions':sum(len(x['actions']) for x in stories.values()),'books':[],'claim_limits':['本次页面核对由智能助手完成，不等于独立编辑人工复核。','未进行儿童试用，不声明记忆效果。','全部故事为策划，未生成或接入语音。']}
 for b in books:
  srcpath=PUBLIC/'books'/f"{b['book_id']}.json"
  source=json.loads(srcpath.read_text(encoding='utf-8-sig'))
  covered={(s['file_page'],r) for e in b['entries'] for s in e['sources'] for r in s['region_ids']}
  unmatched=[]; page_audit=[]
  for p in source['pages']:
   if p['id'] not in b['visual_reviewed_file_pages']:continue
   for r in p['regions']:
    if (p['id'],r['id']) in covered:continue
    if re.fullmatch(r'(Vocabulary|Word List(?: I{1,2})?|Unit(?: \d+)?|Page)',r['text']):continue
    if CORRECTIONS.get(b['book_id'],{}).get((p['id'],r['id']),r['text']) is None:continue
    unmatched.append({'file_page':p['id'],'region_id':r['id'],'text':r['text']})
   img=PUBLIC/p['image'].lstrip('/')
   page_audit.append({'file_page':p['id'],'printed_page':p['printedPage'],'image':p['image'],'image_sha256':hashlib.sha256(img.read_bytes()).hexdigest(),'entry_count_anchored_here':sum(any(s['file_page']==p['id'] for s in e['sources']) for e in b['entries']),'image_checked_by':'assistant','human_editor_review':'pending'})
  audit['books'].append({'book_id':b['book_id'],'manifest_sha256':hashlib.sha256(srcpath.read_bytes()).hexdigest(),'formal_surface_row_count':len({e['surface_group'] for e in b['entries']}),'expanded_spelling_targets':len(b['entries']),'requirements':dict(Counter(e['requirement'] for e in b['entries'])),'unmatched_formal_regions':unmatched,'ocr_correction_records':len(b['corrections']),'image_only_rows':[{'spelling':e['spelling'],'file_page':s['file_page'],'row_label':s['row_label'],'visual_location':s.get('visual_location')} for e in b['entries'] for s in e['sources'] if s.get('no_exact_region')],'pages':page_audit})
  assert not unmatched,(b['book_id'],unmatched)
 for word,s in stories.items():
  counts=Counter(re.findall('[a-z]',word.lower()))
  for n,letter in re.findall('(两|三|四)个 ([a-z])',s['contrast']):
   assert counts[letter]=={'两':2,'三':3,'四':4}[n],(word,s['contrast'])
  for n in re.findall(r'(\d+)\s*个?字母',s['contrast']):
   assert int(n)==sum(counts.values()),(word,s['contrast'])
 (BASE/'g6-validation.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 assert not missing and not errors,(missing,errors)

if __name__=='__main__':main()
