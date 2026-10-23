import bpy,json
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[4]
p=root/'assets/blender/A_orchard/A_orchard_with_apple_house_v02.blend'
bpy.ops.wm.open_mainfile(filepath=str(p))
report={'scenes':[],'collections':[{'name':c.name,'objects':len(c.objects)} for c in bpy.data.collections]}
for sc in bpy.data.scenes:
    objects=[]
    for o in sc.objects:
        pts=[o.matrix_world@Vector(p) for p in o.bound_box] if o.type=='MESH' else []
        objects.append({'name':o.name,'type':o.type,'location':list(o.location),'world_position':list(o.matrix_world.translation),'dimensions':list(o.dimensions),'hidden':o.hide_render,'collections':[c.name for c in o.users_collection], 'bounds':[min(p[i] for p in pts) for i in range(3)]+[max(p[i] for p in pts) for i in range(3)] if pts else [],'props':{k:str(v) for k,v in o.items()}})
    report['scenes'].append({'name':sc.name,'objects':objects})
out=root/'assets/blender/interiors/reports/orchard_source_inventory.json';out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('ORCHARD_INVENTORY',[(s['name'],len(s['objects'])) for s in report['scenes']])
