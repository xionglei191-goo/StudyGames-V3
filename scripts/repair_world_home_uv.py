"""Version the already-refined living room and supply two missing curtain-rail UV maps."""
import bpy,json,sys,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import refine_world_assets as world
import refine_home_living as living
p=world.p
folder=ROOT/'assets/blender/interiors/home'
source=folder/'home_v03.blend';output=folder/'home_v04.blend';glb=folder/'home_v04.glb'
assert not output.exists() and not glb.exists(),'Refusing to overwrite an existing version'
source_hash=world.sha(source)
bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.view_layer.update()
before=world.protected()
fixed=[]
for name in ['Living03_Left_Curtain_Rail','Living03_Right_Curtain_Rail']:
    ob=bpy.data.objects[name]
    assert ob.type=='MESH' and not ob.data.uv_layers
    living.uv_project(ob,.65);fixed.append(name)
assert world.protected()==before
bpy.context.preferences.filepaths.save_version=0
bpy.context.scene['world_refinement_revision']='world-refinement-v1'
bpy.context.scene['protected_source']='assets/blender/interiors/home/home_v03.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output),compress=True)
scene=bpy.context.scene
ratio=scene.render.resolution_y/scene.render.resolution_x
scene.render.resolution_x=1200;scene.render.resolution_y=round(1200*ratio)
p.render_preview(folder/'preview_v04.png')
data=p.collect_source('home')
living.NEW=[o for o in bpy.context.scene.objects if o.type=='CURVE' and not o.name.startswith('PREVIEW_')]
living.GLB=glb;living.export_refined_glb()
stats=p.confirm_export(glb,data)
assert world.sha(source)==source_hash
entry=p.manifest_entry('home','客厅',data,stats,{'blend':'assets/blender/interiors/home/home_v04.blend','glb':'assets/blender/interiors/home/home_v04.glb',
    'preview':'assets/blender/interiors/home/preview_v04.png','refinement_revision':'world-refinement-v1'})
p.write_json(folder/'home_v04.manifest-entry.json',entry)
p.write_json(folder/'validation_v04.json',{**stats,'room_id':'home','uv_repairs':fixed,'protected_objects':len(before),'protected_geometry_unchanged':True,
    'source_blend':'assets/blender/interiors/home/home_v03.blend','source_sha256':source_hash,'blend':entry['blend'],'blend_sha256':world.sha(output),'glb':entry['glb']})
print('WORLD_HOME_UV_REPAIRED '+json.dumps(fixed),flush=True)
