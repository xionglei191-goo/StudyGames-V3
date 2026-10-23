import bpy, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(ROOT/'assets/characters/mixamo_v1/downloads/player/t_pose.fbx'))
for obj in bpy.context.scene.objects:
    row={'name':obj.name,'type':obj.type,'location':list(obj.location),'scale':list(obj.scale),'rotation':list(obj.rotation_euler)}
    if obj.type=='MESH':
        row.update(vertices=len(obj.data.vertices),triangles=len(obj.data.polygons),materials=[m.name for m in obj.data.materials],groups=len(obj.vertex_groups),uv=[l.name for l in obj.data.uv_layers],bounds=[list(v) for v in obj.bound_box])
    elif obj.type=='ARMATURE':
        row.update(bone_count=len(obj.data.bones),bones=[{'name':b.name,'head':list(b.head_local),'tail':list(b.tail_local),'parent':b.parent.name if b.parent else None} for b in obj.data.bones if 'Hand' not in b.name and 'Toe' not in b.name])
    print(json.dumps(row),flush=True)
print('ACTIONS',[(a.name,a.frame_range[:]) for a in bpy.data.actions],flush=True)
print('IMAGES',[(i.name,i.size[:],i.has_data) for i in bpy.data.images],flush=True)
