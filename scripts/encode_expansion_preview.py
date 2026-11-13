"""Encode and decode-check the native expansion preview."""
from pathlib import Path
import json,av
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1];folder=ROOT/'.local/expansion-motion-frames';out=ROOT/'docs/verification/textbook-expansion-v1'
frames=sorted(folder.glob('frame-*.png'));assert len(frames)==414,len(frames)
with Image.open(frames[0]) as im:width,height=im.size
with av.open(str(out/'expansion-motion.mp4'),'w',options={'movflags':'+faststart'}) as container:
 stream=container.add_stream('libx264',rate=24);stream.width=width;stream.height=height;stream.pix_fmt='yuv420p';stream.options={'crf':'20','preset':'medium'}
 for path in frames:
  with Image.open(path) as im:frame=av.VideoFrame.from_image(im.convert('RGB'))
  for packet in stream.encode(frame):container.mux(packet)
 for packet in stream.encode():container.mux(packet)
with av.open(str(out/'expansion-motion.mp4')) as container:count=sum(1 for _ in container.decode(video=0))
assert count==len(frames)
Image.open(frames[118]).convert('RGB').save(out/'motion-poster.jpg',quality=94)
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',16)
for group in range(2):
 picks=list(range(group*207,group*207+207,8));sheet=Image.new('RGB',(1440,300*((len(picks)+2)//3)),'#eeede8');draw=ImageDraw.Draw(sheet)
 for j,index in enumerate(picks):
  im=Image.open(frames[index]).convert('RGB');im.thumbnail((480,270));x=j%3*480;y=j//3*300;sheet.paste(im,(x,y+30));draw.text((x+8,y+6),f'{index/24:.2f}s · frame {index}',font=font,fill='#294739')
 sheet.save(out/f'motion-sequence-{group+1}.jpg',quality=91)
report=dict(status='PASS',frames=count,fps=24,duration_seconds=count/24,resolution=[width,height],size_bytes=(out/'expansion-motion.mp4').stat().st_size,renderer='Godot 4.7.2 / Vulkan Forward+ / RTX 4070',representatives=['Amy','Confucius','Robbie','Bunny','Kelly','Baker','Fendi'],file='expansion-motion.mp4')
(out/'motion-preview.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(report)
