"""四年级词表逐页人工转录（作者为智能助手，仍待独立人工复核）。仅写本目录。"""
import json,re
from pathlib import Path
BASE=Path(__file__).parent
PUBLIC=Path(r'D:\Project\Englishbook\public')
# 文件页|区域号，以后各行为 拼写|教材义项|表内课文页|蓝体R(否则黑体)
UPPER='''
@78|4
a lot of|许多|4
after|在……之后|9
alarm clock|闹钟|6|R
always|总是|49
and|和；又；与|1
animal|动物|24
around|在……周围|59|R
art|美术；艺术|2
artist|画家；艺术家|59|R
astronaut|宇航员|57
at|在；向|6
Australia|澳大利亚|24|R
@78|8
bag|包|41
basketball|篮球|9
bathroom|浴室；卫生间|52|R
be|成为；是|45
bear|熊|24
beautiful|美丽的；优美的|22
@78|10
bedroom|卧室|51|R
bee|蜜蜂|32
best|最好的|34
bread|面包|11
breakfast|早餐|6
@78|5
can|能；会|26
can't=cannot|不能；不会|26
canteen|餐厅；食堂|4|R
chair|椅子|52
chicken|鸡肉；鸡|11
China|中国|24
class|（一节）课；上课时间|4
@78|6
classroom|教室|1
colour|给……上色|5
computer|电脑；计算机|2
cousin|堂兄弟（姐妹）；表兄弟（姐妹）|54
@78|7
cry|哭；哭泣|24
cute|漂亮的；逗人喜爱的|21
@78|9
dangerous|危险的|59|R
desk|书桌；办公桌|3
dinner|晚餐；正餐|7
down|向下；往下|49
dumpling|水饺；汤圆|11|R
@78|11
each other|相互|24|R
early|早的；早地|6
eat|吃|1
@79|3
elephant|大象|21
evening|晚上；傍晚|8
everything|每样东西|59|R
@79|7
far|远地；远的|29
fast|快地；快的|29
film|电影|49
fire|火|59
fireman|消防员|57|R
first (1st)|第一；第一的|9
fish|鱼肉；鱼；钓鱼|11
flower|花|31
fly|飞；飞翔|29
football|足球|27
friend|朋友|24
from... to...|从……到……|9
@79|9
fun|乐趣|4|R
funny|使人发笑的；有趣的|21|R
@79|11
garden|花园|5
get up|起床|6
go to bed|上床睡觉|7
grade|年级|1|R
guess|猜|9|R
@79|13
half|一半；半|7
@79|4
hamburger|汉堡包|11|R
has|have的第三人称单数形式|14
@79|6
have a look|看一看|34
have a try|试一试|26
high|高高地；高的|26|R
hill|小山|34
home|家；住所；窝|7
house|房子|54
hurry|赶紧|6
Hurry up!|快点！|6
@79|8
interesting|有趣的|46
into|到……里面；朝；向|34|R
@79|10
job|工作|56
join|加入|26|R
jump|跳；跃|26
@79|12
kangaroo|袋鼠|24|R
keep|保持|59|R
key|钥匙|42|R
kitchen|厨房|51
know|知道|41
@80|3
late|迟的|9
library|图书馆|1
lion|狮子|5
litter|乱扔垃圾|47|R
live|住；居住|24
living room|客厅|51
lunch|午餐|4
lunchtime|午餐时间|1|R
@80|5
magic|有魔力的；神奇的|49|R
@80|6
maybe|也许|34|R
Monday|星期一|9
monkey|猴子|10
music|音乐|2
@80|9
never|从不|9
noodle (pl. noodles)|面条|12
@80|10
of|……的|4
office|办公室|2|R
on|在……上面|4
on fire|着火|59
outing|短途旅游|31|R
@80|4
panda|大熊猫|21
parent|父；母|54
past|在……之后|7|R
pet|宠物|44
photo|照片|25
ping-pong|乒乓球|27
player|运动员；球员|56|R
playground|操场|1
policeman|男警察|56|R
policewoman|女警察|57|R
@80|7
quiet|安静的|45
@80|8
rabbit|兔子|29
read|阅读；读|4
reading room|阅览室|46
really|确实；的确|49|R
rice|米；米饭|11
right|正确的|22
river|河流；江|34
room|房间；室|2
rule|规则|48|R
run|跑；奔跑|27
@80|11
say|说|14
@81|3
scientist|科学家|57|R
seed|种子|34|R
September|九月|9
shot|击球；射球|29|R
still|还；仍然|6|R
story|故事|4
strange|奇怪的|44|R
strong|健壮的|21
sunshine|阳光|49|R
swim|游泳|27
@81|7
table|桌子|52
take|带|46
talk|交谈；说话|30
tall|高的|21
their|他（她；它）们的|42
@81|9
these|这些|31
they|他（她；它）们|14
they're=they are|他们是|14
those|那些|31
tidy|整洁的|51
tiger|老虎|21
together|一起|4|R
tree|树|25
TV|电视|54
@81|14
umbrella|雨伞|42
@81|4
up|向上地|6
@81|5
vegetable|蔬菜|11
village|村庄|59|R
@81|6
wall|墙；墙壁|47
want|想要|29
watch|手表|41
wear|穿；戴|44
well|熟练地；令人满意地|26
@81|8
where|在哪里|9
whose|谁的|41
wind|风|34|R
with|和……一起；具有；用|30
@81|10
wonderful|令人钦佩的；令人高兴的|56
@81|11
word|单词；词|49
write|写；写作|30
writer|作家；作者|57|R
@81|12
yummy|美味的|14|R
@81|13
zip|拉上……拉链|41|R
'''
LOWER='''
@78|5
about|关于|54
all|全部；每一个|6
altogether|总共|24|R
answer|回答|10
ask|问；询问|59
autumn|秋天|31
@78|7
beach|海滩；沙滩|34
behind|在……后面|2
beside|在……旁边|2
between|在……之间|2
between... and...|在……和……之间|21
@78|9
bin|垃圾桶|49|R
boat|小船|41
bottle|瓶子|1|R
brown|棕色的；棕色|4
busy|忙碌的|29
but|但是|29
@78|13
careful|小心的|34
Chinese|语文；中文；中国的|6
@78|15
cinema|电影院|59
@78|4
clean|（把……）弄干净；打扫；洁净的|4
@78|6
cloud|云|41|R
club|俱乐部|9|R
come on|加油|21
congratulation|恭喜；祝贺|21|R
cook|烹调；煮|8
cool|凉爽的|31
corner|角；角落|24|R
country|国家|54|R
cross|横跨；横穿|56|R
@78|8
dear|亲爱的|34
dirty|脏的|49
do|做；助动词|6
does|do的第三人称单数形式|25
@78|11
door|门|2
dragon|龙|51|R
Dragon Boat Festival|端午节|51|R
@78|12
drink|喝；饮|46
@78|14
eighty|八十|22
English|英语|6
@79|3
every|每个；每一|9
exercise|运动；锻炼|46
@79|5
favourite|最喜欢的|31
festival|节日|51|R
fifth (5th)|第五；第五的|54
fifty|五十|22
fly|飞；放飞|4
forty|四十|22
Friday|星期五|11
from|来自；从|31
@79|8
get|取得；得到|21
get to|到达|26
good job|真不错|9
grandparent|祖父（母）；外祖父（母）|14|R
@79|9
grass|草；草地|49
great|极棒的；极好的|11
@79|11
hard|努力地|29
help|帮助|5
her|她（宾格）；她的|15
@79|13
hide|躲；藏|4|R
@79|4
hide-and-seek|捉迷藏|4|R
hooray|好哇|14|R
hospital|医院|29
@79|6
in|在……里面|1
in need|需要帮助的|26|R
in order|整齐；有序|1|R
interesting|有趣的|24
@79|7
lake|湖|42
leaf (pl. leaves)|叶子|46|R
learn|学习|27
light|灯|56
litter|垃圾|49|R
look|看|4
look at|（仔细）看|56
love|爱；喜爱|24
lunar|阴历的|54|R
@79|10
make|制作；制定|13
match|体育比赛；竞赛|21|R
@79|12
maths|数学|6
mean|意思是|56|R
meet|碰头；见面|9
@80|3
mobile phone|移动电话；手机|56|R
@80|5
Monday|星期一|12
month|月；月份|54
mountain|高山；山脉|42|R
must|必须|56
@80|7
new|新的|1
ninety|九十|22
No.=number|编号|21|R
notice|通知|9|R
now|现在|10
@80|9
often|经常|24
on|在……上面|1
on duty|上班；值班|29|R
one hundred|一百|22
other|另一个；其他的|5|R
@80|11
park|公园；停放|13
PE|体育|6
people|人；人们|29
phone|电话|56
pick|摘|57|R
pick up|捡起|49|R
@80|4
place|地方|41
p.m.|下午|9|R
@80|6
poem|诗歌|9|R
poet|诗人|53|R
point|得分|21|R
put|放；放置|1
@80|8
race|竞赛|51|R
read|阅读；读|14
remember|纪念|51|R
respect|尊敬；敬意|54|R
river|江；河|10
@80|10
Saturday|星期六|11
science|科学|24
sea|海；海洋|42
season|季节|31
sentence|句子|47|R
seventy|七十|22
show|展示；表现出|54
sign|标志；指示牌|56|R
sixty|六十|22
sky|天空|41|R
sleep|睡觉|46
smoke|吸烟|57|R
snow|雪；下雪|34
@81|3
snowman|雪人|32|R
so|如此；这么|44
sometimes|有时|29
sorry|抱歉|14
spit|吐口水；吐唾沫|57|R
@81|5
spring|春天|31
stop|停止；停下|56
street|大街；街道|29
subject|学科；课程|6
summer|夏天|31
Sunday|星期日|12
sweater|毛衣|34
sweep|打扫；清扫|46
@81|9
teach|教|26|R
the Milky Way|银河|44|R
the moon|月亮|44
the sun|太阳|41
thirty|三十|22
throw|扔；投|54|R
Thursday|星期四|9
today|今天|6
tomorrow|明天|11
Tuesday|星期二|11
twenty-one|二十一|22
@81|4
under|在……下面|1
us|我们（宾格）|9
use|用；使用|5
@81|6
village|村庄|15|R
visit|拜访；参观|14
volunteer|志愿者|49|R
@81|7
wait|等；等候|50
walk|走；行走|46
warm|暖和的；温暖的|31
@81|8
water|水|1
way|道路；方法|44
Wednesday|星期三|11
where|在哪里|1
where's=where is|在哪里|1
window|窗户|2
winter|冬天|31
work|工作|29
@81|10
yours|你的；你们的|34|R
'''

def parse(raw,book):
 out=[]
 for l in raw.strip().splitlines():
  if not l.strip():continue
  if l.startswith('@'):
   page,reg=map(int,l[1:].split('|'));continue
  a=l.split('|');sp,meaning,lesson=a[:3];rec=len(a)>3 and a[3]=='R'
  variants=[]
  if '=' in sp:
   left,right=sp.split('=');variants=[(left,{'type':'contraction','expanded':right}),(right,{'type':'expansion','contracted':left})]
  elif re.search(r'\(pl\. ',sp):
   base,plural=re.fullmatch(r'(.+) \(pl\. (.+)\)',sp).groups();variants=[(base,{'type':'base_form','plural':plural}),(plural,{'type':'plural','base':base})]
  elif sp in ('first (1st)','fifth (5th)'):
   a1,a2=sp[:-1].split(' (');variants=[(a1,{'type':'ordinal_word','notation':a2}),(a2,{'type':'ordinal_notation','word':a1})]
  else:variants=[(sp,None)]
  for word,rel in variants:
   kind='contraction' if "'" in word else 'phrase' if ' ' in word else 'word'
   if word in ['Australia','China','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday','September','English','Chinese','PE','TV','Dragon Boat Festival','the Milky Way']:kind='proper_name'
   notes=[]
   if '=' in sp:notes.append('等号是词表释义关系，不进入拼写；展开形式作为关联练习目标。中文为本策划语法释义。')
   if '...' in word:notes.append('省略号表示待填内容槽位，不是三个英语字母；从教材模式保留，不计为普通实词。')
   if word.endswith('!'):notes.append('保留教材感叹号，作为独立标点事件。')
   if rel and rel['type']=='ordinal_notation':notes.append('数字整体保留为数字事件，仅英文字母使用地标。')
   out.append({'spelling':word,'meaning_zh':meaning,'kind':kind,'requirement':'recognition' if rec else 'listen_speak_read_write','sources':[{'file_page':page,'region_ids':[f'p{page}-r{reg}'],'row_label':sp+' '+meaning,'listed_lesson_page':int(lesson),'section':'Word List'}],'unit_numbers':[],'surface_group':sp,'variant_relation':rel,'notes':' '.join(notes)})
 return out

def make_book(v,raw):
 book_id=f'xiangshao-g4-{v}';d=json.loads((PUBLIC/f'books/{book_id}.json').read_text(encoding='utf-8-sig'))
 entries=parse(raw,d)
 # 按栏目而非 region 原始交错顺序读取单元表，以免左右栏单元串线。
 unit=0
 for p in d['pages']:
  if not 75<=p['id']<=77:continue
  for col in (0,1):
   rr=sorted([r for r in p['regions'] if (r['rect'][0]>=.5)==bool(col)],key=lambda r:r['rect'][1])
   for r in rr:
    t=r['text'].strip()
    if t.startswith('Unit '):unit=int(t.split()[-1]);continue
    normalized=t.replace('’',"'").replace('o f','of')
    for e in entries:
     if normalized==e['spelling'] or normalized==e['surface_group'] or normalized.replace('first(1st)','first (1st)')==e['surface_group']:
      e['sources'].append({'file_page':p['id'],'region_ids':[r['id']],'row_label':t,'listed_lesson_page':None,'section':'Vocabulary'})
      if unit and unit not in e['unit_numbers']:e['unit_numbers'].append(unit)
 for e in entries:
  for s in e['sources']:
   p=next(p for p in d['pages'] if p['id']==s['file_page'])
   s.update({'page':p['printedPage'],'image':p['image'],'manifest_reviewed':p.get('reviewed'), 'source_regions':[{k:r.get(k) for k in ('id','text','source','reviewed','sourceVerified','rect')} for r in p['regions'] if r['id'] in s['region_ids']]})
  if not e['unit_numbers']:
   lesson=e['sources'][0]['listed_lesson_page']
   for c in d['chapters']:
    if c['id'].startswith('unit-') and c['printedStart']<=lesson<=c['printedStart']+c['end']-c['start']:e['unit_numbers']=[int(c['id'].split('-')[1])]
 return {'book_id':book_id,'visual_reviewed_file_pages':list(range(75,82)),'entries':entries,'exclusions':[{'kind':'page_furniture','items':['Vocabulary','Word List','Page','Unit 1-10','A-Z分栏标题'],'reason':'表头、页码和分组标签不是词条'}], 'corrections':[]}

if __name__=='__main__':
 out={'grade':4,'books':[make_book(1,UPPER),make_book(2,LOWER)],'stories':{}}
 (BASE/'g4.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print([(b['book_id'],len(b['entries'])) for b in out['books']])
