"""Build labeled comparisons from actual Blender renders; no image retouching."""
from pathlib import Path
import json,sys
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1];EV=Path(sys.argv[1]);DEST=ROOT/'docs/verification/cloud-refinement-20261025';DEST.mkdir(parents=True,exist_ok=True)
EXPORT=Path(sys.argv[2]) if len(sys.argv)>2 else ROOT/'.local/cloud-refinement/deliverables';EXPORT.mkdir(parents=True,exist_ok=True)
PAIR=DEST/'comparisons';PAIR.mkdir(exist_ok=True)
font='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
f=ImageFont.truetype(font,28);small=ImageFont.truetype(font,19)
plan=json.loads((ROOT/'docs/planning/cloud-refinement-20261025.json').read_text())
names={r['room_id']:r['name'] for r in plan['rooms']};names['island']='字母岛 · 全景';names['island-neighborhood']='字母岛 · 住宅与湖岸'
notes={
 'island':'保留 A–Z 布局；补充门廊、百叶窗、种植层次和分层岸石。',
 'island-neighborhood':'同一镜头、灯光与色彩管理；变化来自实际网格和材质。',
 'school':'修复交叉路面重叠黑面；增加檐下托木、墙角石和花箱层次。',
 'classroom':'让护墙线与桌面镶边显露；补充护墙板、粉笔托与粉笔。',
 'music_room':'调整护墙细节；补充吸音板木条和书脊装帧。',
 'art_room':'修正埋入台面的镶边与柜门把手，增加柜门嵌板。',
 'science_room':'修正柜门五金位置，增加实验柜门板与墙面收边。',
 'canteen':'修正工作台收边与五金，补充柜门和护墙板。',
 'playground':'保留运动区域与碰撞；增加跑道色带和篮筐网。',
 'football_field':'轻量处理替补席五金和角落种植；场线、球门和路线保持。',
 'home':'保留生活任务与软装；修整护墙、桌面镶边和陈设细节。',
 'home_balcony':'轻量补充盆栽叶形与细节；三种家务状态全部保留。',
 'home_bathroom':'修正柜门五金，增加门板与护墙收边。',
 'home_bedroom':'增加床头木作与护墙；保留床铺任务的全部状态。',
 'home_dining':'修正桌面镶边和柜门五金；保持餐桌任务状态。',
 'home_estate':'轻量补充两翼屋脊盖瓦；保留既有庭院、门窗与家务状态。',
 'home_hall':'轻量补充坐垫扣和植物叶形；七扇房门与导览图标保持。',
 'home_kitchen':'修正柜门把手，补充门板、工作面和护墙细节。',
 'home_study':'书脊、书桌镶边与护墙细节；学习任务保持。'}
order=['island','island-neighborhood']+[r['room_id'] for r in plan['rooms'] if r['room_id']!='island']
for room in order:
    folder=EV/('island' if room=='island-neighborhood' else room);suffix='-neighborhood' if room=='island-neighborhood' else ''
    a=Image.open(folder/('before'+suffix+'.png')).convert('RGB');b=Image.open(folder/('after'+suffix+'.png')).convert('RGB');assert a.size==b.size,(room,a.size,b.size)
    w,h=a.size;g=24;out=Image.new('RGB',(2*w+3*g,h+154),'#f3f1e9');d=ImageDraw.Draw(out)
    d.text((g,12),names[room],font=f,fill='#263e36');d.text((g,58),'原场景  /  BEFORE',font=small,fill='#58665f');d.text((w+2*g,58),'本次精修  /  AFTER',font=small,fill='#276a55')
    out.paste(a,(g,94));out.paste(b,(w+2*g,94));d.text((g,h+110),notes[room],font=small,fill='#45524c')
    out.save(PAIR/(room+'.jpg'),quality=91,subsampling=0)
    if room in ['island','island-neighborhood']:out.save(EXPORT/('StudyGames-'+room+'-before-after.png'))
manifest=[{'room_id':room,'name':names[room],'note':notes[room],'comparison':'comparisons/'+room+'.jpg'} for room in order]
(DEST/'gallery.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('ACTUAL_RENDER_COMPARISONS',len(manifest))
