"""Integrate the supplied Tripo house into the existing orchard, saving version 02.

Runs through MCP in live Blender. The source GLB and version 01 blend are unchanged.
"""
import bpy
import math
import json
import hashlib
from pathlib import Path
from mathutils import Vector

OUT=Path('/Users/xionglei/Documents/StudyGame/assets/blender/A_orchard')
RAW=Path('/Users/xionglei/Documents/StudyGame/assets/tripo/A_apple_house_tripo_raw_v01.glb')
DEST=OUT/'A_orchard_with_apple_house_v02.blend'
TARGET_TRIANGLES=80000
scene=bpy.context.scene
assert scene.name=='A_Orchard_Environment_v01'
assert not DEST.exists(), 'Use a new version instead of replacing an existing result.'
house=bpy.data.objects['A_AppleHouse_Tripo']
root=bpy.data.objects['A_APPLE_HOUSE_ROOT']
socket=bpy.data.objects['A_LANDMARK_SOCKET']
assert house.type=='MESH' and house.parent==root
assert not root.get('integrated_v02',False)
source_sha256=hashlib.sha256(RAW.read_bytes()).hexdigest()
raw_faces=len(house.data.polygons)
raw_vertices=len(house.data.vertices)

# Collapse only the imported working mesh; the raw GLB stays on disk unchanged.
modifier=house.modifiers.new('Scene_Mesh_Reduction','DECIMATE')
modes=[i.identifier for i in modifier.bl_rna.properties['decimate_type'].enum_items]
assert 'COLLAPSE' in modes
modifier.decimate_type='COLLAPSE'
modifier.ratio=min(1.0,TARGET_TRIANGLES/raw_faces)
modifier.use_collapse_triangulate=True
bpy.context.view_layer.objects.active=house
house.select_set(True)
bpy.ops.object.modifier_apply(modifier=modifier.name)
for polygon in house.data.polygons:
    polygon.use_smooth=True
bpy.context.view_layer.update()

# Root-local bounds are independent of the temporary inspection position.
inverse=root.matrix_world.inverted()
points=[inverse@(house.matrix_world@Vector(p)) for p in house.bound_box]
lo=Vector(tuple(min(v[i] for v in points) for i in range(3)))
hi=Vector(tuple(max(v[i] for v in points) for i in range(3)))
scale=6.0/(hi.x-lo.x)
root.scale=(scale,scale,scale)
root.rotation_euler=(0,0,0)
centre_bottom=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
root.location=socket.location-centre_bottom*scale
root['integrated_v02']=True
root['front_axis']='-Y'
root['source_sha256']=source_sha256
root['mesh_target_triangles']=TARGET_TRIANGLES
root['raw_triangles']=raw_faces
root['working_triangles']=len(house.data.polygons)
root['door_status']='Static fused exterior; door animation and interior not implemented'
root['texture_resolution']='Original embedded 8192 x 8192 base color preserved'
house['asset_role']='Tripo apple-shaped house with integrated structural letter A'
house['source_file']=str(RAW)
bpy.context.view_layer.update()
world_points=[house.matrix_world@Vector(p) for p in house.bound_box]
world_lo=[min(v[i] for v in world_points) for i in range(3)]
world_hi=[max(v[i] for v in world_points) for i in range(3)]
assert abs(world_lo[2]-socket.location.z)<0.001
assert all(math.isfinite(c) for v in house.data.vertices for c in v.co)

scene.name='A_Orchard_With_Apple_House_v02'
scene['tripo_house_included']=True
scene['asset_scope']='Orchard sample with user-supplied Tripo apple house'
scene['source_tripo_glb']=str(RAW)
scene.render.filepath=str(OUT/'A_orchard_with_apple_house_preview_v02.png')
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(DEST))

report={
    'source_file':str(RAW),
    'source_sha256':source_sha256,
    'source_preserved':hashlib.sha256(RAW.read_bytes()).hexdigest()==source_sha256,
    'raw_vertices':raw_vertices,
    'raw_triangles':raw_faces,
    'working_vertices':len(house.data.vertices),
    'working_triangles':len(house.data.polygons),
    'triangle_reduction_percent':round(100*(1-len(house.data.polygons)/raw_faces),2),
    'world_bounds_min':world_lo,
    'world_bounds_max':world_hi,
    'world_size':[world_hi[i]-world_lo[i] for i in range(3)],
    'texture_resolution':[8192,8192],
    'texture_packed':all(n.image.packed_file is not None for m in house.data.materials for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image),
    'front_axis':'-Y',
    'ground_z':socket.location.z,
    'blend_file':str(DEST),
    'game_engine_tested':False,
    'door_interactive':False,
}
(OUT/'apple_house_integration_v02.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False))
