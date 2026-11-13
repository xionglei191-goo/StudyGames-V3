"""Read the current living-room source without modifying it."""
import bpy,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/verification/home-living-hub-20261113'
d=json.loads((ROOT/'game/data/interiors_manifest.json').read_text(encoding='utf-8-sig'))
entry=next(r for r in d['rooms'] if r['room_id']=='home')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/entry['source_blend']))
bpy.context.view_layer.update()
rows=[]
for o in bpy.context.scene.objects:
    corners=[o.matrix_world@Vector(c) for c in o.bound_box] if o.type=='MESH' else [o.matrix_world.translation]
    rows.append({'name':o.name,'type':o.type,'parent':o.parent.name if o.parent else None,'location':list(o.location),'dimensions':list(o.dimensions),'bounds':[[min(c[i] for c in corners) for i in range(3)],[max(c[i] for c in corners) for i in range(3)]],'matrix':[list(r) for r in o.matrix_world],'materials':[m.name for m in o.data.materials if m] if o.type=='MESH' else [],'properties':{k:str(v) for k,v in o.items()},'vertices':len(o.data.vertices) if o.type=='MESH' else 0})
(OUT/'source-inventory.json').write_text(json.dumps({'entry':entry,'objects':rows,'collections':[c.name for c in bpy.data.collections],'materials':[m.name for m in bpy.data.materials]},ensure_ascii=False,indent=2),encoding='utf-8')
print('INSPECTED',len(rows),entry['source_blend'],flush=True)
