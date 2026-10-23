"""合并转录、逐词故事及审计；无网络、无游戏目录写入。"""
import json,re,hashlib
from pathlib import Path
from collections import Counter
from g4_entries import make_book,UPPER,LOWER,PUBLIC
from g4_stories import parse,BASE

baseline_path=BASE.parent/'source_baseline.json'
if baseline_path.is_file():
 for item in json.loads(baseline_path.read_text(encoding='utf-8')):
  source_path=Path(item['path'])
  if source_path.name in ('xiangshao-g4-1.json','xiangshao-g4-2.json'):
   if hashlib.sha256(source_path.read_bytes()).hexdigest()!=item['sha256']:
    raise RuntimeError(f'教材源清单已变化，需重新看图复核而非静默重建：{source_path}')

d={'grade':4,'books':[make_book(1,UPPER),make_book(2,LOWER)],'stories':parse()}

def source_for(book_id,page,rid,row):
 b=json.loads((PUBLIC/f'books/{book_id}.json').read_text(encoding='utf-8-sig'))
 p=next(x for x in b['pages'] if x['id']==page)
 rr=next(x for x in p['regions'] if x['id']==rid)
 return {'file_page':page,'page':p['printedPage'],'region_ids':[rid],'row_label':row,'listed_lesson_page':None,'section':'Vocabulary','image':p['image'],'manifest_reviewed':p.get('reviewed'),'source_regions':[{k:rr.get(k) for k in ('id','text','source','reviewed','sourceVerified','rect')}]}

for b in d['books']:
 for e in b['entries']:
  e['review']={'source_visual':'assistant_page_checked','editorial_human':'pending','child_trial':'not_run','audio':'not_assessed_in_authoring'}
  e['spelling_form_type']='ordinary'
  if e['spelling'] in ('1st','5th'):
   e['kind']='notation';e['spelling_form_type']='ordinal_notation'
  if e['spelling'] in ('TV','PE','No.','p.m.'):
   e['kind']='abbreviation';e['spelling_form_type']='abbreviation'
   e['notes']+=' 缩略形式保留大小写及所有句点；完整读音独立教学。'
  if '...' in e['spelling']:
   e['kind']='pattern';e['spelling_form_type']='fill_in_pattern'
  if e['surface_group']=='first (1st)':
   e['source_surface']='first(1st)'
  elif e['surface_group']=='fifth (5th)':
   e['source_surface']='fifth(5th)'
  else:e['source_surface']=e['surface_group'].replace("'",'’')
  if e['surface_group']=='No.=number':
   if e['spelling']=='No.':e['variant_relation']={'type':'abbreviation','expanded':'number'}
   else:e['variant_relation']={'type':'expanded_abbreviation','abbreviated':'No.'}
   e['notes']='等号是缩写释义关系；No. 的句点保留。教材中文为“编号”，不自动扩展为本册未列的所有number义项。'
  if e['spelling'] in ('noodle','noodles'):
   e['sources'].append(source_for(b['book_id'],75,'p75-r24','(pl. noodles)'))
   if 3 not in e['unit_numbers']:e['unit_numbers'].append(3)
  if e['spelling'] in ('has','does'):
   # 英语原形出现在中文释义行内，与正式列头共享一条来源。
   source=e['sources'][0]
   extra='p79-r5' if e['spelling']=='has' else 'p78-r10'
   bb=json.loads((PUBLIC/f'books/{b["book_id"]}.json').read_text(encoding='utf-8-sig'))
   pp=next(x for x in bb['pages'] if x['id']==source['file_page'])
   rr=next(x for x in pp['regions'] if x['id']==extra)
   source['region_ids'].append(extra)
   source['source_regions'].append({k:rr.get(k) for k in ('id','text','source','reviewed','sourceVerified','rect')})
  if e['spelling']=='congratulation':
   e['notes']+=' 教材词表列头为单数congratulation，保留不偷改；常用祝贺表达Congratulations另作语言说明，不计本表额外词条。'
  if e['spelling'] in ('Saturday','Sunday'):
   e['notes']+=' 教材星期名不绑定强制活动；周历起始日随版式明确显示。'

 b['exclusions'].append({'kind':'explanatory_reference','file_page':79 if b['book_id'].endswith('-1') else 78,'region_ids':['p79-r5'] if b['book_id'].endswith('-1') else ['p78-r10'],'items':['have'] if b['book_id'].endswith('-1') else ['do'],'reason':'位于has/does的中文语法解释内；不是额外词表行。has/does的来源包含该释义关系。'})
 if b['book_id'].endswith('-1'):
  b['corrections']=[{'file_page':80,'region_ids':['p80-r10'],'raw':'o f','corrected':'of','evidence':'已看实际页图，印刷页73的词条为连续of；仅在策划词条修正。'}, {'file_page':79,'region_ids':['p79-r7'],'raw':'first(1st)','normalized':'first / 1st','evidence':'页图确认括号是序数另一种写法；分成word和notation两个关联目标。'}, {'file_page':80,'region_ids':['p80-r9'],'raw':'noodle (pl. noodles)','normalized':'noodle / noodles','evidence':'页图确认pl.是语法说明，不进入字母链。'}]
 else:
  b['corrections']=[{'file_page':79,'region_ids':['p79-r5'],'raw':'fifth (5th)','normalized':'fifth / 5th','evidence':'页图确认序数数字形式，独立notation目标。'}, {'file_page':79,'region_ids':['p79-r7'],'raw':'leaf (pl. leaves)','normalized':'leaf / leaves','evidence':'页图确认不规则复数leaves，保留全部字母，不只给leaf加s。'}, {'file_page':80,'region_ids':['p80-r7'],'raw':'No.=number','normalized':'No. / number','evidence':'页图确认No.的N大写，o小写，末点必须保留。'}]
 b['corrections'].append({'type':'typography','raw':'印刷弯撇号’','normalized':"ASCII撇号'",'evidence':'页面的缩写撇号在拼写目标中统一编码为ASCII；源表面保留。'})

extensions={
 'fish':[
  {'meaning_zh':'鱼肉','reuse_policy':'同一个鱼池/食物双窗位置，切换到右侧食材窗；不重置字母映射。','actions':['花朵把食物窗打开露出熟鱼肉图','冰淇淋冷盘接住鱼肉餐盘','星星照亮食材标签','帽檐将食物图与左侧活鱼图隔开'],'transfer':'新订单要fish时选择鱼肉餐盘，区分观察动物任务。'},
  {'meaning_zh':'钓鱼','reuse_policy':'在原鱼池窗前添加钓鱼动作层，仍用F-I-S-H。','actions':['花朵弯成玩具鱼竿','冰淇淋棒轻拉竿线','星星照见鱼钩模型与池中鱼的关系','帽檐网接住玩具鱼后放回模型池'],'transfer':'新动作图听fish识别钓鱼动作；不进行未经许可的真实捕捞。'}],
 'home':[{'meaning_zh':'动物的窝','reuse_policy':'原家园门前槽位加动物住所翻页，不重新随机选地点。','scene':'将屋内家人图翻到鸟窝/动物住所图，H-O-M-E顺序动作改为布置、归巢与安放食物。','transfer':'新动物故事go home，让动物回自己的窝。'}],
 'fly':[{'meaning_zh':'放飞','reuse_policy':'同风筝草地，F-L-Y角色仍按序。','actions':['花朵花瓣吹风托起风筝','灯笼照见风筝离地','毛线逐渐放长使风筝飞高'],'transfer':'新草地任务fly a kite，选择放飞动作，区别仅看飞鸟。'}],
 'with':[
  {'meaning_zh':'具有','reuse_policy':'结伴出游台同槽位附物品特征层。','actions':['鲸鱼展示两只不同书包','冰淇淋棒指出其中带口袋的一只','火车把有口袋的包送来','帽檐圈起包和附带口袋'],'transfer':'新选择a bag with a pocket，选具有口袋的包。'},
  {'meaning_zh':'用','reuse_policy':'同出游台附工具层，W-I-T-H顺序保留。','actions':['鲸鱼托来待画的卡','冰淇淋棒充当画笔','火车载着笔沿卡片画线','帽檐展示用笔完成的画'],'transfer':'新制作任务draw with a pencil，选择并使用铅笔。'}],
 'litter':[{'meaning_zh':'垃圾（四下）','reuse_policy':'保持四上清理台与L-I-T-T-E-R动作，先指出落在地面的物，再做清理。','scene':'镜头先停在纸团本身，对应名词litter；四上动词镜头聚焦乱扔的动作。','transfer':'在新清理区圈出litter物体，再选择正确处理。'}],
 'be':[{'meaning_zh':'是','reuse_policy':'职业镜子的同一角色名牌由愿望翻到当前身份。','actions':['小船载来角色当前职业名牌','蛋壳把名牌扣到人物上建立“是”的关系'],'transfer':'新身份句中的be形式按句型教学，不从故事推导语法变位。'}],
 'make':[{'meaning_zh':'制定','reuse_policy':'原手工作台添加计划纸，仍同M-A-K-E顺序。','actions':['蘑菇撑起空计划纸','苹果推来待安排的活动卡','风筝尾按先后连活动','蛋壳托起完成的计划'],'transfer':'新任务make a plan，把活动安排成计划。'}],
 'park':[{'meaning_zh':'停放','reuse_policy':'公园模型旁固定停车分栏，词义不同但记忆位置关联不变。','actions':['南瓜指出空车位','苹果滚到车位前停住','机器人引导车辆进入','风筝尾轻拉停车线确认停妥'],'transfer':'新图park the car选择停放车辆动作。'}],
 'do':[{'meaning_zh':'助动词','reuse_policy':'行动台加问句支架，与做事的实义分开。','actions':['鼓把Do放到问句开头','猫头鹰把you like apples接在后面并问出整句'],'transfer':'新Do you...?听力配对应喜好问题，不让孩子给助动词强配一个物体。'}],
 'way':[{'meaning_zh':'方法','reuse_policy':'路线板右侧固定步骤栏。','actions':['鲸鱼递出待折的纸','苹果按步骤压一道折痕','毛线串起完成小船的步骤'],'transfer':'新问题找a way to make it，选择可执行的步骤方案。'}]
}
for word,items in extensions.items():d['stories'][word]['sense_extensions']=items
for word,s in d['stories'].items():
 s['editorial_review']='pending_human_review';s['child_trial']='not_run'
 if word in ['football','basketball','school','book','noodle','noodles']:
  s['contrast']='重复字母按全拼写位置编号，同映射多次出场；不能合并一次。'
 if word=='football':s['contrast']='F-O-O-T-B-A-L-L：O在第2、3位，L在第7、8位；与basketball的投篮场景区分。'
 if word=='litter':s['contrast']='第3、4位T均为Train；名词垃圾与乱扔动作在同一清理台分镜区分。'
 if word=='Wednesday':s['contrast']='W-E-D-N-E-S-D-A-Y九字母，读音不显著的D也不能删；语音另教。'

errors=[]
targets={e['spelling'] for b in d['books'] for e in b['entries']}
if targets!=set(d['stories']):errors.append({'story_target_mismatch':sorted(targets^set(d['stories']))})
for word,s in d['stories'].items():
 if len(s['actions'])!=len(re.findall('[A-Za-z]',word)):errors.append({'word':word,'error':'action_count'})
 for ext in s.get('sense_extensions',[]):
  if 'actions' in ext and len(ext['actions'])!=len(re.findall('[A-Za-z]',word)):errors.append({'word':word,'error':'sense_action_count'})
for b in d['books']:
 seen=set()
 for e in b['entries']:
  if e['spelling'] in seen:errors.append({'book':b['book_id'],'duplicate':e['spelling']})
  seen.add(e['spelling'])
  for s in e['sources']:
   if not (PUBLIC/s['image'].lstrip('/')).is_file():errors.append({'missing_image':s['image']})
   if len(s['source_regions'])!=len(s['region_ids']):errors.append({'bad_regions':s})
   if s['page']!=s['file_page']-7:errors.append({'page_offset':s})
 raw=json.loads((PUBLIC/f'books/{b["book_id"]}.json').read_text(encoding='utf-8-sig'))
 used={rid for e in b['entries'] for src in e['sources'] for rid in src['region_ids']}
 excluded={rid for x in b['exclusions'] for rid in x.get('region_ids',[])}
 b['page_audit']=[]
 for p in raw['pages']:
  if not 75<=p['id']<=81:continue
  rr=[r for r in p['regions'] if not r['text'].startswith(('Unit','Vocab','Word List','Page'))]
  missing=[r['id'] for r in rr if r['id'] not in used|excluded]
  if missing:errors.append({'unaccounted_region':missing})
  page_rows={e['surface_group'] for e in b['entries'] for src in e['sources'] if src['file_page']==p['id'] and src['section']=='Word List'}
  b['page_audit'].append({'file_page':p['id'],'page':p['printedPage'],'section':'Vocabulary' if p['id']<=77 else 'Word List','nonheader_regions':len(rr),'regions_accounted_for':len(rr)-len(missing),'formal_rows_on_alphabetical_page':len(page_rows) if p['id']>=78 else None,'image':p['image'],'image_sha256':hashlib.sha256((PUBLIC/p['image'].lstrip('/')).read_bytes()).hexdigest(),'visual_review':'assistant_checked_all_rows','human_review':'pending'})

audit={'status':'pass' if not errors else 'fail','errors':errors,'unique_spelling_targets':len(targets),'story_count':len(d['stories']),'letter_actions':sum(len(s['actions']) for s in d['stories'].values()),'books':[],'scope':'两册正式Vocabulary/Word List并集，非所有课文英文碎片','human_editor_review':'pending','child_trial':'not_run','audio':'本作者未制作或接入任何语音'}
for b in d['books']:
 other=next(x for x in d['books'] if x['book_id']!=b['book_id'])
 shared=sorted({e['spelling'] for e in b['entries']}&{e['spelling'] for e in other['entries']})
 counts=Counter(e['kind'] for e in b['entries'])
 b['summary']={'formal_rows':len(set(e['surface_group'] for e in b['entries'])),'expanded_spelling_targets':len(b['entries']),'kind_counts':dict(counts),'shared_with_other_volume':shared,'visual_page_count':7}
 audit['books'].append({'book_id':b['book_id'],**b['summary']})
baseline=[{'path':f'books/{b["book_id"]}.json','sha256':hashlib.sha256((PUBLIC/f'books/{b["book_id"]}.json').read_bytes()).hexdigest()} for b in d['books']]
d['source_baseline']=baseline
(BASE/'g4.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(BASE/'g4-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(audit,ensure_ascii=False,indent=2))
if errors:raise SystemExit(1)
