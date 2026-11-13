"""Create runtime props and editable Blender files from reviewed intakes."""
from pathlib import Path
import json, sys, math
import bpy, bmesh
from mathutils import Matrix, Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import prepare_tripo_characters as prep
OUT=ROOT/'assets/props/tripo_expansion_v1'
INTAKE=ROOT/'assets/characters/textbook_expansion_v1/intake'
RUNTIME=ROOT/'game/assets/props/tripo_expansion_v1'
OUT.mkdir(parents=True,exist_ok=True);RUNTIME.mkdir(parents=True,exist_ok=True)
catalog=json.loads((INTAKE.parent/'catalog.json').read_text(encoding='utf-8'))
selected=set(sys.argv[sys.argv.index('--')+1:]) if '--' in sys.argv else set()
assets=[]
for row in catalog['assets']:
    if row['category']!='prop':continue
    ident=row['id'];folder=OUT/ident;folder.mkdir(parents=True,exist_ok=True)
    if selected and ident not in selected:continue
    bpy.ops.wm.open_mainfile(filepath=str(INTAKE/row['intake_id']/'prepared.blend'))
    obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    obj.name=ident
    rotate=Matrix.Rotation(math.radians(row['rotation_z']),3,'Z')
    for vertex in obj.data.vertices:vertex.co=rotate@vertex.co
    obj.data.update()
    lo=Vector([min(v.co[i] for v in obj.data.vertices) for i in range(3)])
    hi=Vector([max(v.co[i] for v in obj.data.vertices) for i in range(3)])
    center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
    factor=row['max_dimension']/max(hi-lo)
    for vertex in obj.data.vertices:vertex.co=(vertex.co-center)*factor
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Prop triangle budget','DECIMATE')
    budget=16000 if row['selection_code'] in ['P41','P42','P43','P44'] else 12000
    mod.ratio=budget/max(1,len(obj.data.polygons));mod.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for im in bpy.data.images:
        if max(im.size)>1024 and budget==12000:
            im.scale(1024,1024);im.pack()
    obj['asset_id']=ident;obj['source_sha256']=row['source_sha256']
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'prop.blend'))
    bpy.ops.export_scene.gltf(filepath=str(folder/'prop.glb'),export_format='GLB',export_animations=False,export_yup=True,export_extras=True)
    (RUNTIME/(ident+'.glb')).write_bytes((folder/'prop.glb').read_bytes())
    lo=Vector([min(v.co[i] for v in obj.data.vertices) for i in range(3)])
    hi=Vector([max(v.co[i] for v in obj.data.vertices) for i in range(3)])
    obj.data.calc_loop_triangles()
    record={**row,'path':'res://assets/props/tripo_expansion_v1/'+ident+'.glb',
        'triangles':len(obj.data.loop_triangles),'bounds_min':[lo.x,lo.z,-hi.y],
        'bounds_size':[hi.x-lo.x,hi.z-lo.z,hi.y-lo.y],
        'editable_source':(folder/'prop.blend').relative_to(ROOT).as_posix(),
        'rigging':'static mesh; parent/socket attachment supplies movement'}
    (folder/'prop.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    assets.append(record)
    print('EXPANSION_PROP_DONE '+ident,flush=True)
all_assets=[]
for folder in OUT.iterdir():
    if (folder/'prop.json').exists():all_assets.append(json.loads((folder/'prop.json').read_text(encoding='utf-8')))
(RUNTIME/'manifest.json').write_text(json.dumps(dict(schema_version=1,assets=all_assets),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
