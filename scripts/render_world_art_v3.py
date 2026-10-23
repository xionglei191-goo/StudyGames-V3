"""Small CPU-only preview of the new editable source, never opens original maps."""
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/art/world_refresh_v3'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'world_props_v3.blend'))
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=12
scene.render.resolution_x=800;scene.render.resolution_y=600;scene.render.resolution_percentage=100
scene.world.color=(.55,.55,.55)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.035))
floor=bpy.context.object
mat=bpy.data.materials.new('Preview neutral warm paper');mat.diffuse_color=(.67,.65,.58,1);floor.data.materials.append(mat)
for location,power,size in [((1,-3,6),550,5),((-4,1,3),260,4)]:
    bpy.ops.object.light_add(type='AREA',location=location);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size
    light.rotation_euler=(Vector((0,0,0))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(4,-6,7));cam=bpy.context.object
cam.rotation_euler=(Vector((0,0,.1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=4.6;scene.camera=cam
scene.view_settings.view_transform='AgX';scene.render.filepath=str(OUT/'props-review.png')
bpy.ops.render.render(write_still=True)
