import bpy, sys, json
import numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from rig_tripo_characters import mesh_arrays,texture_data
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/characters/tripo_v1/textbook_jim/prepared.blend'))
obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
xyz=mesh_arrays(obj)/2.05
rgb,_=texture_data(obj)
x,y,z=xyz.T
for label,mask in [('hand',(abs(x)>.08)&(abs(x)<.16)&(y>.34)&(y<.43)&(z>.12)),('forearm',(abs(x)>.12)&(abs(x)<.18)&(y>.43)&(y<.51)),('trousers',(abs(x)>.06)&(abs(x)<.13)&(y>.23)&(y<.32)&(z>.15)),('shirt',(abs(x)<.07)&(y>.45)&(y<.6)&(z>-.1))]:
    colors=rgb[mask]
    print('COLOR',label,len(colors),np.quantile(colors,[.1,.5,.9],axis=0).tolist(),np.quantile(colors[:,0]/np.maximum(colors[:,1],.001),[.1,.5,.9]).tolist(),flush=True)
    points=xyz[mask]
    print('XYZ',label,np.quantile(points,[.1,.5,.9],axis=0).tolist(),flush=True)
