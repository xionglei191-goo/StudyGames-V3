"""Focused repair: recalculate outward winding on S's existing floor only."""
import sys,json,hashlib,shutil
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import bpy,bmesh,pipeline

out=pipeline.OUT;room='landmark_S';source=out/room/(room+'_v01.blend')
backup=out/'reports'/'S_floor_fix';backup.mkdir(parents=True,exist_ok=True)
shutil.copy2(source,backup/'before.blend')
manifest=json.loads((out/'interiors_manifest.json').read_text(encoding='utf-8'))
other_before={r['room_id']:{k:hashlib.sha256((pipeline.ROOT/r[k]).read_bytes()).hexdigest() for k in ['blend','glb','preview']} for r in manifest['rooms'] if r['room_id']!=room}
bpy.ops.wm.open_mainfile(filepath=str(source))
floor=bpy.data.objects['SG_FLOOR_Main']
before_vertices=[list(v.co) for v in floor.data.vertices]
anchors_before={o.name:[list(row) for row in o.matrix_world] for o in bpy.context.scene.objects if o.type=='EMPTY' and o.name.startswith('SG_')}
other_objects_before={o.name:[list(row) for row in o.matrix_world] for o in bpy.context.scene.objects if o!=floor}
def faces():return [{'center_z':round(p.center.z,5),'normal_z':round(p.normal.z,5)} for p in floor.data.polygons if abs(p.normal.z)>.99]
before=faces()
bm=bmesh.new();bm.from_mesh(floor.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(floor.data);bm.free();floor.data.update()
after=faces()
assert [list(v.co) for v in floor.data.vertices]==before_vertices
assert any(p['center_z']==0 and p['normal_z']>.99 for p in after)
assert any(p['center_z']==-.46 and p['normal_z']<-.99 for p in after)
assert anchors_before=={o.name:[list(row) for row in o.matrix_world] for o in bpy.context.scene.objects if o.type=='EMPTY' and o.name.startswith('SG_')}
assert other_objects_before=={o.name:[list(row) for row in o.matrix_world] for o in bpy.context.scene.objects if o!=floor}
pipeline.finish_room(room,'星形天文台',save_blend=True,render=True)
other_after={r['room_id']:{k:hashlib.sha256((pipeline.ROOT/r[k]).read_bytes()).hexdigest() for k in ['blend','glb','preview']} for r in manifest['rooms'] if r['room_id']!=room}
assert other_before==other_after
pipeline.write_json(backup/'repair_report.json',{'room_id':room,'changed_mesh':'SG_FLOOR_Main','before_horizontal_faces':before,'after_horizontal_faces':after,'vertex_coordinates_unchanged':True,'sg_anchor_transforms_unchanged':True,'all_other_object_transforms_unchanged':True,'other_30_rooms_blend_glb_preview_hashes_unchanged':True,'other_rooms_hashes':other_after,'scope':'Only existing S floor winding/normals recalculated; no generator rebuild'})
print('S_FLOOR_REPAIRED',json.dumps({'before':before,'after':after}),flush=True)
