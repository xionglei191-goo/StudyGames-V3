"""Build the A apple-house environment through the live MCP for Blender connection.

Run in Blender's Python context. Creates a new scene and preserves existing scenes.
The Tripo house itself is represented by a non-rendering import socket and wire box.
"""
import bpy
import math
import random
from pathlib import Path
from mathutils import Vector

OUTPUT = Path('/Users/xionglei/Documents/StudyGame/assets/blender/A_orchard')
SCENE_NAME = 'A_Orchard_Environment_v01'
GROUND = 0.65
rng = random.Random(1729)


def enum_set(owner, name, preferred):
    values = [item.identifier for item in owner.bl_rna.properties[name].enum_items]
    if preferred not in values:
        raise ValueError(f'{name}: {preferred} not available in {values}')
    setattr(owner, name, preferred)


if SCENE_NAME in bpy.data.scenes:
    raise RuntimeError('Scene already exists. Preserve it and apply targeted edits instead.')
previous_engine = bpy.context.scene.render.engine
scene = bpy.data.scenes.new(SCENE_NAME)
bpy.context.window.scene = scene
scene.render.engine = previous_engine
enum_set(scene.unit_settings, 'system', 'METRIC')
scene.unit_settings.scale_length = 1.0
scene['asset_scope'] = 'A apple house environment sample; Tripo building pending'
scene['generated_by'] = 'Codex using MCP for Blender'
scene['walkable_surface_z'] = GROUND

collections = {}
for name in ['00_Site', '01_Paths_Water', '02_Orchard', '03_Fences', '04_Memory_Loci', '05_Dressing', '90_Landmark_Import', '99_Cameras_Lights']:
    c = bpy.data.collections.new('A_' + name)
    scene.collection.children.link(c)
    collections[name] = c


def material(name, rgb, roughness=0.65, metallic=0.0, emission=0.0):
    m = bpy.data.materials.new('A_MAT_' + name)
    m.use_nodes = True
    p = next(node for node in m.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    if emission:
        p.inputs['Emission Color'].default_value = (*rgb, 1)
        p.inputs['Emission Strength'].default_value = emission
    m.diffuse_color = (*rgb, 1)
    return m


M = {
    'grass': material('Grass', (0.32, 0.53, 0.13)),
    'grass_light': material('Grass_Light', (0.44, 0.63, 0.20)),
    'grass_dark': material('Grass_Dark', (0.23, 0.40, 0.10)),
    'earth': material('Earth', (0.32, 0.22, 0.12)),
    'sand': material('Sand', (0.76, 0.62, 0.37)),
    'path': material('Warm_Path', (0.83, 0.70, 0.46)),
    'path_edge': material('Path_Edge', (0.65, 0.50, 0.29)),
    'stone': material('Warm_Stone', (0.51, 0.49, 0.38)),
    'stone_light': material('Light_Stone', (0.69, 0.67, 0.53)),
    'water': material('Creek_Water', (0.12, 0.55, 0.66), 0.27),
    'sea': material('Sea', (0.18, 0.46, 0.54), 0.35),
    'foam': material('Water_Glints', (0.72, 0.88, 0.81), 0.35),
    'bark': material('Bark', (0.29, 0.13, 0.055)),
    'wood': material('Honey_Wood', (0.58, 0.32, 0.12)),
    'wood_light': material('Fresh_Wood', (0.77, 0.52, 0.25)),
    'wood_dark': material('Dark_Wood', (0.30, 0.16, 0.07)),
    'leaf': material('Leaves', (0.21, 0.43, 0.075)),
    'leaf_light': material('Leaf_Light', (0.34, 0.56, 0.12)),
    'leaf_dark': material('Leaf_Shade', (0.12, 0.31, 0.055)),
    'apple': material('Apple_Red', (0.76, 0.045, 0.028), 0.36),
    'apple_yellow': material('Apple_Yellow', (0.94, 0.61, 0.08), 0.42),
    'cream': material('Cream', (0.94, 0.86, 0.65)),
    'pink': material('Flower_Pink', (0.89, 0.38, 0.43)),
    'yellow': material('Flower_Yellow', (0.96, 0.69, 0.12)),
    'blue': material('Paint_Teal', (0.12, 0.40, 0.42)),
    'brass': material('Brass', (0.56, 0.35, 0.12), 0.32, 0.3),
    'glass': material('Lantern_Glow', (1.0, 0.65, 0.22), 0.4, emission=0.6),
    'soil': material('Garden_Soil', (0.20, 0.13, 0.075)),
}


def link_object(name, data, group, parent=None):
    ob = bpy.data.objects.new(name, data)
    collections[group].objects.link(ob)
    if parent:
        ob.parent = parent
    ob['study_game_asset'] = True
    return ob


def mesh_object(name, verts, faces, mat, group, parent=None):
    mesh = bpy.data.meshes.new(name + '_Mesh')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    ob = link_object(name, mesh, group, parent)
    if mat:
        mesh.materials.append(mat)
    return ob


def bevel(ob, width=0.05, segments=2):
    mod = ob.modifiers.new('Soft_Edges', 'BEVEL')
    mod.width = width
    mod.segments = segments
    return ob


def box(name, loc, size, mat, group, roundness=0.04, parent=None):
    x, y, z = [v / 2 for v in size]
    verts = [(-x,-y,-z), (x,-y,-z), (x,y,-z), (-x,y,-z), (-x,-y,z), (x,-y,z), (x,y,z), (-x,y,z)]
    faces = [(0,3,2,1), (4,5,6,7), (0,1,5,4), (1,2,6,5), (2,3,7,6), (3,0,4,7)]
    ob = mesh_object(name, verts, faces, mat, group, parent)
    ob.location = loc
    if roundness:
        bevel(ob, min(roundness, min(size)/3), 2)
    return ob


def cylinder(name, loc, radius, depth, mat, group, vertices=12, top=None, parent=None):
    top = radius if top is None else top
    verts = [(math.cos(i*2*math.pi/vertices)*r, math.sin(i*2*math.pi/vertices)*r, z)
             for r,z in [(radius, -depth/2), (top,depth/2)] for i in range(vertices)]
    faces = [tuple(reversed(range(vertices))), tuple(range(vertices,2*vertices))]
    faces += [(i,(i+1)%vertices,(i+1)%vertices+vertices,i+vertices) for i in range(vertices)]
    ob = mesh_object(name, verts, faces, mat, group, parent)
    ob.location = loc
    bevel(ob, min(0.035, depth/8, radius/5), 2)
    return ob


def beam(name, a, b, width, mat, group, parent=None, square=False):
    a,b = Vector(a),Vector(b)
    mid=(a+b)/2
    if square:
        ob=box(name,mid,(width,width,(b-a).length),mat,group,0.025,parent)
    else:
        ob=cylinder(name,mid,width/2,(b-a).length,mat,group,10,parent=parent)
    ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return ob


# Shared sphere geometry keeps recurring foliage and fruit economical to edit.
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1)
template=bpy.context.object
ico_mesh=template.data
ico_mesh.name='A_Shared_Icosphere'
for p in ico_mesh.polygons:
    p.use_smooth=True
bpy.data.objects.remove(template,do_unlink=True)
sphere_meshes={}


def sphere(name, loc, size, mat, group, parent=None):
    key=mat.name
    if key not in sphere_meshes:
        mesh=ico_mesh.copy()
        mesh.materials.clear()
        mesh.materials.append(mat)
        sphere_meshes[key]=mesh
    ob=link_object(name,sphere_meshes[key],group,parent)
    ob.location=loc
    ob.scale=size
    return ob


def empty(name, loc, group, label=None):
    ob=link_object(name,None,group)
    ob.location=loc
    enum_set(ob,'empty_display_type','CIRCLE')
    ob.empty_display_size=0.5
    if label:
        ob['purpose']=label
    return ob


def island(name, rx, ry, z0, z1, mat, group):
    n=64
    outline=[]
    for i in range(n):
        t=2*math.pi*i/n
        factor=1+0.035*math.sin(t*3+0.5)+0.025*math.cos(t*7)
        outline.append((rx*math.cos(t)*factor,ry*math.sin(t)*factor))
    verts=[(x,y,z) for z in [z0,z1] for x,y in outline]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    ob=mesh_object(name,verts,faces,mat,group)
    bevel(ob,0.15,3)
    return ob


def sample_path(points, per_span=8):
    points=[Vector((x,y)) for x,y in points]
    out=[]
    for i in range(len(points)-1):
        a=points[max(0,i-1)];b=points[i];c=points[i+1];d=points[min(len(points)-1,i+2)]
        for j in range(per_span):
            t=j/per_span
            out.append(0.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    out.append(points[-1])
    return out


def ribbon(name, points, width, z, mat, group):
    pts=sample_path(points)
    verts=[]
    for i,p in enumerate(pts):
        direction=pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]
        direction.normalize()
        normal=Vector((-direction.y,direction.x))*width/2
        verts.extend([(p.x+normal.x,p.y+normal.y,z),(p.x-normal.x,p.y-normal.y,z)])
    faces=[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(pts)-1)]
    return mesh_object(name,verts,faces,mat,group)


# Terrain and the connected walking route.
island('A_Shore_Sand',12.1,11.0,-0.55,0.12,M['sand'],'00_Site')
island('A_Island_Earth',11.65,10.45,0.02,0.50,M['earth'],'00_Site')
island('A_Grass_Surface',11.50,10.3,0.45,GROUND,M['grass'],'00_Site')
box('A_Sea_Plane',(0,0,-0.60),(200,200,0.1),M['sea'],'01_Paths_Water',0)

main=[(0,-10.2),(-0.5,-7.4),(-0.3,-4.2),(0,-1.8),(0,0.55)]
loop=[(-1.7,-2.3),(-4.5,-2.1),(-5.0,1.0),(-4.5,5.7),(-2,7.0),(2.5,7.0),(5.0,4.8),(5.0,0.0),(3.2,-2.5),(1.6,-3.0)]
branch=[(1.8,-4.0),(4.5,-4.1),(7.0,-3.8),(10.1,-3.8)]
for name,points,width in [('Main',main,1.8),('Garden_Loop',loop,1.45),('Bridge_Approach',branch,1.5)]:
    ribbon('A_Path_Edge_'+name,points,width+0.20,GROUND+0.011,M['path_edge'],'01_Paths_Water')
    ribbon('A_Path_'+name,points,width,GROUND+0.021,M['path'],'01_Paths_Water')
cylinder('A_Welcome_Court',(0,-2.6,GROUND+0.025),2.8,0.035,M['path'],'01_Paths_Water',48)

creek=[(8.3,8.6),(7.1,6.0),(7.9,3.0),(7.25,0.0),(7.7,-3.8),(6.4,-7.3),(6.2,-9.3)]
ribbon('A_Creek_Bank',creek,2.4,GROUND+0.030,M['sand'],'01_Paths_Water')
ribbon('A_Creek_Surface',creek,1.7,GROUND+0.043,M['water'],'01_Paths_Water')
for y,x in [(6.5,7.3),(3.0,7.9),(0.2,7.25),(-6.0,6.85),(-8.4,6.2)]:
    box('A_Creek_Glint',(x,y,GROUND+0.048),(0.62,0.035,0.008),M['foam'],'01_Paths_Water',0.008)

# Tripo landmark reservation: a foundation pad, socket and viewport-only wire volume.
box('A_House_Foundation',(0,3.35,GROUND+0.06),(6.25,6.25,0.12),M['stone_light'],'90_Landmark_Import',0.20)
socket=empty('A_LANDMARK_SOCKET',(0,3.35,GROUND+0.12),'90_Landmark_Import','Import Tripo A house here; local front -Y, ground at socket Z')
socket['target_shell_width_m']=6.0
socket['front_axis']='-Y'
socket['pending_asset']='A_apple_house_tripo_raw_v01.glb'
placeholder=box('A_HOUSE_PLACEHOLDER_VIEWPORT_ONLY',(0,3.35,GROUND+2.62),(6,6,5),None,'90_Landmark_Import',0)
enum_set(placeholder,'display_type','WIRE')
placeholder.hide_render=True
placeholder['purpose']='House envelope only; replace with Tripo model'

# Creek bridge with accessible deck and rounded timber rails.
for i in range(13):
    x=6.0+i*0.27
    z=GROUND+0.18+0.13*math.sin(i/12*math.pi)
    box(f'A_Bridge_Deck_{i:02}',(x,-3.8,z),(0.25,1.9,0.14),M['wood_light'],'01_Paths_Water',0.04)
for y in [-4.78,-2.82]:
    for x in [6.0,7.6,9.24]:
        cylinder('A_Bridge_Post',(x,y,GROUND+0.68),0.105,1.26,M['wood'],'01_Paths_Water',10)
        sphere('A_Bridge_Post_Cap',(x,y,GROUND+1.33),(0.14,0.14,0.10),M['wood_light'],'01_Paths_Water')
    beam('A_Bridge_Rail',(6.0,y,GROUND+1.08),(9.24,y,GROUND+1.08),0.12,M['wood_light'],'01_Paths_Water',square=True)


def apple(name, p, scale=1.0, group='02_Orchard'):
    x,y,z=p
    fruit=sphere(name,p,(0.16*scale,0.16*scale,0.15*scale),M['apple'],group)
    beam(name+'_Stem',(x,y,z+0.12*scale),(x+0.015*scale,y,z+0.23*scale),0.035*scale,M['bark'],group)
    leaf=sphere(name+'_Leaf',(x+0.075*scale,y,z+0.18*scale),(0.105*scale,0.042*scale,0.025*scale),M['leaf_light'],group)
    leaf.rotation_euler[1]=-0.35
    return fruit


def apple_tree(index,x,y,scale=1.0):
    root=empty(f'A_AppleTree_{index:02}',(0,0,0),'02_Orchard','Reusable orchard tree')
    start=set(bpy.data.objects)
    base=GROUND
    beam(f'A_Tree_{index}_Trunk',(x,y,base),(x+0.08,y,base+2.2*scale),0.38*scale,M['bark'],'02_Orchard')
    for dx,dy in [(-0.65,0.1),(0.62,0.1),(0,0.5)]:
        beam(f'A_Tree_{index}_Branch',(x,y,base+1.45*scale),(x+dx*scale,y+dy*scale,base+2.4*scale),0.22*scale,M['bark'],'02_Orchard')
    for j,(dx,dy,dz,sz) in enumerate([(-0.65,0,2.65,0.95),(0.65,0.05,2.7,1.0),(0,0.55,2.9,1.0),(0,-0.2,3.35,1.0)]):
        sphere(f'A_Tree_{index}_Crown_{j}',(x+dx*scale,y+dy*scale,base+dz*scale),(sz*scale,sz*0.9*scale,sz*0.86*scale),M[['leaf','leaf_light','leaf_dark','leaf_light'][j]],'02_Orchard')
    for j,(dx,dy,dz) in enumerate([(-0.9,-0.5,2.55),(-0.1,-0.95,2.8),(0.8,-0.6,2.75),(0.35,-0.65,3.5),(-0.65,0.4,3.25),(1.1,0.1,2.9)]):
        apple(f'A_Tree_{index}_Fruit_{j}',(x+dx*scale,y+dy*scale,base+dz*scale),1.15*scale)
    for ob in set(bpy.data.objects)-start:
        ob.parent=root
    return root


for i,(x,y,s) in enumerate([(-7.7,4.5,1.0),(-6.0,7.8,0.95),(-8.0,0.5,1.08),(-7.0,-3.8,0.95),(4.6,8.2,0.85)],1):
    apple_tree(i,x,y,s)


def fence_segment(name,a,b):
    ax,ay=a;bx,by=b
    length=math.hypot(bx-ax,by-ay)
    count=max(1,math.ceil(length/1.45))
    for i in range(count+1):
        t=i/count
        x=ax+(bx-ax)*t;y=ay+(by-ay)*t
        box(name+'_Post',(x,y,GROUND+0.55),(0.17,0.17,1.10),M['wood'],'03_Fences',0.05)
        sphere(name+'_Cap',(x,y,GROUND+1.1),(0.13,0.13,0.09),M['wood_light'],'03_Fences')
    for z in [GROUND+0.39,GROUND+0.81]:
        beam(name+'_Rail',(ax,ay,z),(bx,by,z),0.12,M['wood_light'],'03_Fences',square=True)


for i,(a,b) in enumerate([((-9.0,-5.0),(-9.7,-1.5)),((-9.4,2.3),(-8.0,7.0)),((-4.7,9.0),(2.6,9.0)),((2.5,-8.4),(4.8,-7.8)),((-6.3,-7.8),(-2.1,-8.9))]):
    fence_segment(f'A_Fence_{i}',a,b)


def crate(name,x,y,z,width=0.8,depth=0.6,height=0.55,group='04_Memory_Loci'):
    box(name+'_Bottom',(x,y,z+0.045),(width,depth,0.09),M['wood_dark'],group,0.025)
    for dx in [-width/2+0.045,width/2-0.045]:
        for dy in [-depth/2+0.045,depth/2-0.045]:
            box(name+'_Corner',(x+dx,y+dy,z+height/2),(0.08,0.08,height),M['wood'],group,0.02)
    for j in range(3):
        zz=z+0.10+j*(height-0.12)/3
        for dy in [-depth/2,depth/2]:
            box(name+'_Slat',(x,y+dy,zz),(width,0.06,(height-0.1)/4),M['wood_light'],group,0.018)
        for dx in [-width/2,width/2]:
            box(name+'_End',(x+dx,y,zz),(0.06,depth,(height-0.1)/4),M['wood_light'],group,0.018)


def basket(name,x,y,z):
    n=16
    r0,r1,height=0.30,0.40,0.48
    verts=[(x+math.cos(t*2*math.pi/n)*r,y+math.sin(t*2*math.pi/n)*r,z+zz) for r,zz in [(r0,0),(r1,height),(r1-0.07,height),(r0-0.07,0.08)] for t in range(n)]
    faces=[]
    for layer in range(3):
        for i in range(n):
            j=(i+1)%n
            faces.append((layer*n+i,layer*n+j,(layer+1)*n+j,(layer+1)*n+i))
    faces.append(tuple(range(3*n,4*n)))
    mesh_object(name,verts,faces,M['wood_light'],'04_Memory_Loci')
    for i in range(n):
        t=i*2*math.pi/n
        beam(name+'_Weave',(x+math.cos(t)*r0,y+math.sin(t)*r0,z+0.04),(x+math.cos(t)*r1,y+math.sin(t)*r1,z+height),0.028,M['wood'],'04_Memory_Loci')
    last=None
    for j in range(13):
        t=math.pi*j/12
        p=(x+0.38*math.cos(t),y,z+0.45+0.5*math.sin(t))
        if last:
            beam(name+'_Handle',last,p,0.055,M['wood'],'04_Memory_Loci')
        last=p


# Five semantic anchors match the memory-palace design, in walking order.
anchors={
    '01_Entrance_Basket':(-2.5,-0.8,GROUND),
    '02_Left_Apple_Tree':(-8.0,0.5,GROUND),
    '03_Sorting_Table':(-2.8,-4.7,GROUND),
    '04_Wash_Basin':(4.15,-1.3,GROUND),
    '05_Gift_Shelf':(3.6,-6.2,GROUND),
}
for key,loc in anchors.items():
    marker=empty('A_LOCUS_'+key,loc,'04_Memory_Loci',key)
    marker['memory_order']=int(key[:2])
    marker['fixed_location']=True
basket('A_Entrance_Basket',-2.5,-0.8,GROUND+0.03)
for dx,dy in [(-0.12,-0.08),(0.14,-0.04),(0,0.14)]:
    apple('A_Basket_Apple',(-2.5+dx,-0.8+dy,GROUND+0.48),0.75,'04_Memory_Loci')

# Sorting table with two open crates and generous clear standing space.
tx,ty=-2.8,-4.7
for dx in [-0.90,0.90]:
    for dy in [-0.36,0.36]:
        box('A_SortTable_Leg',(tx+dx,ty+dy,GROUND+0.43),(0.12,0.12,0.86),M['wood'],'04_Memory_Loci')
for j in range(4):
    box('A_SortTable_Top',(tx,ty+(j-1.5)*0.24,GROUND+0.90),(2.2,0.22,0.12),M['wood_light'],'04_Memory_Loci')
for dx in [-0.55,0.55]:
    crate('A_Sort_Crate',tx+dx,ty,GROUND+0.98,0.78,0.62,0.36)
    for ax,ay in [(-0.17,-0.09),(0.14,-0.08),(0,0.14)]:
        apple('A_Sort_Apple',(tx+dx+ax,ty+ay,GROUND+1.3),0.75,'04_Memory_Loci')
crate('A_Spare_Crate',tx-1.25,ty+0.65,GROUND+0.02,0.75,0.6,0.55)

# Stone washing trough with a teal rim and a simple brass tap.
wx,wy=4.15,-1.3
box('A_Wash_Pedestal',(wx,wy,GROUND+0.34),(1.42,0.94,0.68),M['stone'],'04_Memory_Loci',0.11)
box('A_Wash_Bottom',(wx,wy,GROUND+0.77),(1.65,1.12,0.16),M['blue'],'04_Memory_Loci',0.06)
for dx in [-0.78,0.78]:
    box('A_Wash_End',(wx+dx,wy,GROUND+0.95),(0.12,1.12,0.33),M['blue'],'04_Memory_Loci',0.06)
for dy in [-0.50,0.50]:
    box('A_Wash_Rim',(wx,wy+dy,GROUND+0.95),(1.65,0.12,0.33),M['blue'],'04_Memory_Loci',0.055)
box('A_Wash_Water',(wx,wy,GROUND+0.95),(1.46,0.88,0.025),M['water'],'04_Memory_Loci',0.02)
beam('A_Wash_Tap',(wx,wy+0.38,GROUND+0.9),(wx,wy+0.38,GROUND+1.55),0.07,M['brass'],'04_Memory_Loci')
beam('A_Wash_Spout',(wx,wy+0.38,GROUND+1.55),(wx,wy+0.10,GROUND+1.55),0.07,M['brass'],'04_Memory_Loci')
beam('A_Wash_Handle',(wx-0.12,wy+0.38,GROUND+1.34),(wx+0.12,wy+0.38,GROUND+1.34),0.055,M['brass'],'04_Memory_Loci')

# Gift shelf at the departure path.
gx,gy=3.6,-6.2
for dx in [-0.72,0.72]:
    box('A_GiftShelf_Upright',(gx+dx,gy,GROUND+0.65),(0.12,0.52,1.3),M['wood'],'04_Memory_Loci')
for zz in [0.24,0.80,1.34]:
    box('A_GiftShelf_Board',(gx,gy,GROUND+zz),(1.65,0.65,0.10),M['wood_light'],'04_Memory_Loci')
for dx,dy,zz,col in [(-0.4,0,0.47,'pink'),(0.32,0,0.47,'blue'),(-0.3,0,1.04,'cream'),(0.4,0,1.02,'apple_yellow')]:
    box('A_Gift_Box',(gx+dx,gy+dy,GROUND+zz),(0.43,0.40,0.34),M[col],'04_Memory_Loci',0.055)
    box('A_Gift_Ribbon',(gx+dx,gy-0.205,GROUND+zz),(0.07,0.015,0.35),M['cream'],'04_Memory_Loci',0.005)


def shrub(name,x,y,s=0.7):
    for j,(dx,dy,dz) in enumerate([(-0.32,0,0.25),(0.28,0.05,0.28),(0,0,0.50)]):
        sphere(name+str(j),(x+dx*s,y+dy*s,GROUND+dz*s),(0.47*s,0.42*s,0.42*s),M[['leaf','leaf_light','leaf'][j]],'05_Dressing')


def flower(name,x,y,color):
    z=GROUND+0.2
    beam(name+'_Stem',(x,y,GROUND),(x,y,z+0.20),0.035,M['leaf_dark'],'05_Dressing')
    for i in range(5):
        t=i*2*math.pi/5
        sphere(name+'_Petal',(x+0.10*math.cos(t),y+0.10*math.sin(t),z+0.19),(0.10,0.09,0.055),M[color],'05_Dressing')
    sphere(name+'_Center',(x,y,z+0.23),(0.066,0.066,0.05),M['yellow'],'05_Dressing')


for i,(x,y,s) in enumerate([(-4,6.9,0.85),(-9,-2.4,1.0),(-8.5,6.5,0.8),(-4.4,-6.9,0.7),(2.0,8.6,0.9),(6,6.5,0.7),(9,2.1,0.7),(8.9,-6.3,0.8),(1.8,-8.0,0.6)]):
    shrub('A_Shrub_'+str(i),x,y,s)
for i,(cx,cy) in enumerate([(-4.6,-6.5),(-5.1,4.7),(2.6,8.2),(5.8,0.8),(1.7,-7.8)]):
    for j in range(4):
        flower(f'A_Flower_{i}_{j}',cx+rng.uniform(-0.45,0.45),cy+rng.uniform(-0.32,0.32),['pink','cream'][i%2])

# Stones along the creek and shore add readable edges without covering the path.
for i,(x,y) in enumerate([(6.9,2.2),(8.9,4.0),(6.4,5.0),(8.5,-0.9),(6.5,-5.9),(5.3,-8.7),(-9.8,4.0),(-8.5,-6.5),(9.2,-4.8),(3.3,9.6)]):
    sphere(f'A_Edge_Rock_{i}',(x,y,GROUND+0.14),(0.38+rng.random()*0.2,0.30+rng.random()*0.2,0.26),M['stone_light' if i%2 else 'stone'],'05_Dressing')

# Rest bench and two lamps along the primary route.
for dy in [-0.22,0.0,0.22]:
    box('A_Bench_Seat',(-3.3,-0.3+dy,GROUND+0.48),(1.7,0.19,0.10),M['wood_light'],'05_Dressing')
for dx in [-0.6,0.6]:
    box('A_Bench_Leg',(-3.3+dx,-0.3,GROUND+0.24),(0.12,0.40,0.48),M['wood'],'05_Dressing')
    box('A_Bench_BackSupport',(-3.3+dx,0.03,GROUND+0.66),(0.09,0.09,1.05),M['wood'],'05_Dressing')
for z in [0.79,1.02]:
    box('A_Bench_Back',(-3.3,0.03,GROUND+z),(1.7,0.10,0.18),M['wood_light'],'05_Dressing')

for i,(x,y) in enumerate([(-1.8,-6.6),(2.65,-0.55)]):
    cylinder(f'A_Lamp_{i}_Pole',(x,y,GROUND+1.1),0.065,2.2,M['wood_dark'],'05_Dressing')
    box(f'A_Lamp_{i}_Glass',(x,y,GROUND+2.25),(0.28,0.28,0.43),M['glass'],'05_Dressing',0.04)
    cylinder(f'A_Lamp_{i}_Roof',(x,y,GROUND+2.51),0.27,0.22,M['wood_dark'],'05_Dressing',4,top=0.06)

# Camera and soft daylight. No assets or paid generation services are used.
world=bpy.data.worlds.new('A_Orchard_Daylight')
world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
bg.inputs['Color'].default_value=(0.70,0.83,0.88,1)
bg.inputs['Strength'].default_value=0.55
scene.world=world


def aim(ob,target):
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()


light_types=[i.identifier for i in bpy.types.Light.bl_rna.properties['type'].enum_items]
assert 'AREA' in light_types
for name,loc,power,size in [('Key',(-8,-10,18),1900,10),('Fill',(10,1,13),1000,12)]:
    data=bpy.data.lights.new('A_'+name,'AREA')
    data.energy=power
    data.shape='DISK' if 'DISK' in [i.identifier for i in data.bl_rna.properties['shape'].enum_items] else data.shape
    data.size=size
    ob=link_object('A_Light_'+name,data,'99_Cameras_Lights')
    ob.location=loc
    aim(ob,(0,1,0))
cam_data=bpy.data.cameras.new('A_Camera_Isometric')
enum_set(cam_data,'type','ORTHO')
cam_data.ortho_scale=30
cam=link_object('A_Camera_Isometric',cam_data,'99_Cameras_Lights')
cam.location=(24,-30,29)
aim(cam,(0,0.4,0.8))
scene.camera=cam
scene.render.resolution_x=1600
scene.render.resolution_y=1300
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
scene.render.filepath=str(OUTPUT/'A_orchard_preview_v01.png')

# Use the scene camera when the user opens this scene.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.overlay.show_extras=False

scene['memory_route']='Entrance basket -> left apple tree -> sorting table -> wash basin -> gift shelf'
scene['landmark_socket']='A_LANDMARK_SOCKET'
scene['main_path_width_m']=1.8
scene['loop_path_width_m']=1.45
scene['tripo_house_included']=False
OUTPUT.mkdir(parents=True,exist_ok=True)
blend_path=OUTPUT/'A_orchard_environment_v01.blend'
if blend_path.exists():
    raise RuntimeError('Output exists; save a new version instead of replacing it.')
bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
print({'scene':scene.name,'objects':len(scene.objects),'blend_file':str(blend_path),'socket':tuple(socket.location),'loci':list(anchors)})
