"""Assemble the native three-view captures without altering the model renders."""
from pathlib import Path
import json,sys
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'docs/verification/textbook-expansion-v1'/(sys.argv[1] if len(sys.argv)>1 else 'final-captures')
rows=json.loads((folder/'captures.json').read_text(encoding='utf-8-sig'))
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
small=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',15)
labels={'idle':'待机','walk':'行走 / 游泳','greet_wave':'招呼','pose_photo':'拍照','give_item':'递物','place_item':'放下','carry_walk':'持物行走','point_target':'指向','take_item':'接物','pick_item':'拾取','carry_item':'持物','reach_target':'伸手','talk_gesture':'说话','listen_nod':'点头'}
views={'front':'正面','side':'侧面','back':'背面'}
byid={}
for r in rows:byid.setdefault(r['id'],[]).append(r)
out=folder/'sheets';out.mkdir(exist_ok=True)
for ident,items in byid.items():
 items.sort(key=lambda r:(list(labels).index(r['action']),r.get('mode','normal'),r['time'],['front','side','back'].index(r['view'])))
 assert len(items)%3==0
 sheet=Image.new('RGB',(1080,60+len(items)//3*280),'#eeede8');d=ImageDraw.Draw(sheet)
 d.text((14,12),ident+'  ·  Godot 原生三视角',font=font,fill='#253b30')
 for i,row in enumerate(items):
  x=i%3*360;y=60+i//3*280
  im=Image.open(folder/row['file']).convert('RGB');im.thumbnail((360,255));sheet.paste(im,(x,y+25))
  label=f"{labels[row['action']]} · {views[row['view']]} · {row['time']:.2f}s"+(' · 减少动态' if row.get('mode')=='reduced' else '')
  d.text((x+7,y+4),label,font=small,fill='#253b30')
 sheet.save(out/(ident+'.jpg'),quality=92)
print('EXPANSION_REVIEW_SHEETS',len(byid))
