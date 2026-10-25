"""Read-only background Blender inventory for the living-room refinement."""
import bpy, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/blender/interiors/home/home_v02.blend'))
bpy.context.view_layer.update()
rows=[]
for ob in bpy.context.scene.objects:
    rows.append({'name':ob.name,'type':ob.type,'location':list(ob.location),'dimensions':list(ob.dimensions),'parent':ob.parent.name if ob.parent else None,'materials':[ma.name for ma in ob.data.materials] if ob.type=='MESH' else [],'properties':{k:str(v) for k,v in ob.items()},'mesh_vertices':len(ob.data.vertices) if ob.type=='MESH' else 0})
out=ROOT/'docs/verification/living-room-polish/source-inventory.json'
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(rows,ensure_ascii=False,indent=2),'utf-8')
print('INVENTORY',len(rows),str(out),flush=True)
