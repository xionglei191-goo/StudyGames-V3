"""Targeted visual corrections after inspecting the first live viewport."""
import bpy
import math
from mathutils import Vector

scene=bpy.context.scene
assert scene.name=='A_Orchard_Environment_v01'
bpy.data.objects['A_HOUSE_PLACEHOLDER_VIEWPORT_ONLY'].hide_set(True)

colors={
    'Grass':(0.19,0.40,0.075),
    'Leaves':(0.12,0.34,0.035),
    'Leaf_Light':(0.23,0.46,0.065),
    'Leaf_Shade':(0.065,0.24,0.025),
    'Sea':(0.13,0.39,0.47),
    'Creek_Water':(0.06,0.43,0.57),
}
for name,rgb in colors.items():
    m=bpy.data.materials['A_MAT_'+name]
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*rgb,1)
    m.diffuse_color=(*rgb,1)
bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND')
bg.inputs['Strength'].default_value=0.35
light_types=[i.identifier for i in bpy.types.Light.bl_rna.properties['type'].enum_items]
assert 'SUN' in light_types
data=bpy.data.lights.new('A_Soft_Sun','SUN')
data.energy=1.65
data.angle=math.radians(12)
ob=bpy.data.objects.new('A_Light_Sun',data)
bpy.data.collections['A_99_Cameras_Lights'].objects.link(ob)
ob.location=(-8,-10,18)
ob.rotation_euler=(Vector((0,1,0))-ob.location).to_track_quat('-Z','Y').to_euler()
scene.eevee.taa_render_samples=96
scene.eevee.use_shadows=True
scene.eevee.use_fast_gi=True

# Keep the water and sand banks inside the real island outline.
for name in ['A_Creek_Bank','A_Creek_Surface']:
    obj=bpy.data.objects[name]
    for v in obj.data.vertices:
        x,y,z=v.co
        theta=math.atan2(y/10.3,x/11.5)
        edge=0.985*(1+0.035*math.sin(theta*3+0.5)+0.025*math.cos(theta*7))
        radial=math.sqrt((x/11.5)**2+(y/10.3)**2)
        if radial>edge:
            v.co.x*=edge/radial
            v.co.y*=edge/radial
    obj.data.update()
water=bpy.data.objects['A_Creek_Surface']
for index,ids in enumerate([(0,1),(len(water.data.vertices)-2,len(water.data.vertices)-1)]):
    a,b=[water.data.vertices[i].co.copy() for i in ids]
    centre=(a+b)/2
    direction=Vector((centre.x,centre.y,0)).normalized()
    c=b+direction*0.45;c.z=-0.54
    d=a+direction*0.45;d.z=-0.54
    mesh=bpy.data.meshes.new('A_Creek_Cascade_Mesh')
    mesh.from_pydata([a,b,c,d],[],[(0,1,2,3)])
    mesh.materials.append(bpy.data.materials['A_MAT_Creek_Water'])
    cascade=bpy.data.objects.new('A_Creek_Cascade_'+str(index),mesh)
    bpy.data.collections['A_01_Paths_Water'].objects.link(cascade)

# Place fruit at the canopy surface so it reads clearly from the game camera.
old=[(-0.9,-0.5,2.55),(-0.1,-0.95,2.8),(0.8,-0.6,2.75),(0.35,-0.65,3.5),(-0.65,0.4,3.25),(1.1,0.1,2.9)]
new=[(-0.95,-0.9,2.55),(-0.1,-1.1,2.8),(0.85,-0.95,2.75),(0.35,-1.05,3.5),(-1.2,0.4,3.25),(1.5,0.05,2.9)]
for i,scale in enumerate([1.0,0.95,1.08,0.95,0.85],1):
    for j,(a,b) in enumerate(zip(old,new)):
        delta=(Vector(b)-Vector(a))*scale
        prefix=f'A_Tree_{i}_Fruit_{j}'
        for obj in scene.objects:
            if obj.name==prefix or obj.name.startswith(prefix+'_'):
                obj.location+=delta

# Add clearance between the back of the foundation and the garden loop.
for name in ['A_Path_Edge_Garden_Loop','A_Path_Garden_Loop']:
    mesh=bpy.data.objects[name].data
    ymax=max(v.co.y for v in mesh.vertices)
    for v in mesh.vertices:
        if v.co.y>6.2:
            v.co.y+=0.45*(v.co.y-6.2)/(ymax-6.2)
    mesh.update()

bpy.ops.wm.save_as_mainfile(filepath='/Users/xionglei/Documents/StudyGame/assets/blender/A_orchard/A_orchard_environment_v01.blend')
print({'refined':True,'placeholder_hidden':True,'objects':len(scene.objects)})
