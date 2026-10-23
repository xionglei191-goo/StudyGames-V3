"""Reproducible, original Blender-authored near-field art; never opens source maps.

blender --background --factory-startup --python-exit-code 1 --python scripts/build_world_art_v3.py
Optional -- --render creates only a small six-object review plate (no game scene).
"""
from __future__ import annotations
import hashlib
import json
import math
import random
import shutil
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/art/world_refresh_v3'
RUNTIME = ROOT / 'game/assets/world_refresh_v3'
TEX = OUT / 'textures'
for folder in (OUT, RUNTIME, TEX):
    folder.mkdir(parents=True, exist_ok=True)
random.seed(3217)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def srgb(c):
    return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4


def rgba(hex):
    return tuple(srgb(int(hex[i:i+2], 16) / 255) for i in (0, 2, 4)) + (1,)


def make_texture(family, size=256):
    """Seamless neutral detail modulation + OpenGL normal, original analytic patterns."""
    heights = []
    for y in range(size):
        for x in range(size):
            u, v = x / size * math.tau, y / size * math.tau
            wave = math.sin(u*3 + math.sin(v*2)) * math.sin(v*4 - math.sin(u))
            if family == 'wood':
                flow = u*7 + 2.6*math.sin(v) + .85*math.sin(v*3) + .5*math.sin(u*2+v)
                h = .5 + .14*math.sin(flow) + .05*math.sin(u*19+2.5*math.sin(v)+.8*math.sin(v*4)) + .04*wave
            elif family == 'bark':
                h = .5 + .25*math.sin(u*11+1.2*math.sin(v*2)) + .1*math.sin(u*24+math.sin(v*7))
            elif family == 'foliage':
                h = .5 + .19*wave + .1*math.sin(u*13)*math.sin(v*11)
            elif family == 'cloth':
                h = .5 + .2*math.cos(u*32)*math.cos(v*32) + .05*wave
            elif family == 'paper':
                h = .5 + .12*math.sin(u*65 + math.sin(v*3)) + .07*wave
            else:
                h = .5 + .13*wave + .10*math.sin(u*41)*math.cos(v*37)
            heights.append(h)
    for mode in ('detail', 'normal'):
        image = bpy.data.images.new(f'{family}_{mode}', size, size, alpha=False)
        pixels = []
        for y in range(size):
            for x in range(size):
                h = heights[y*size+x]
                if mode == 'detail':
                    depth = .08 if family == 'wood' else (.18 if family == 'bark' else .08)
                    val = 1-depth + depth*h
                    pixels.extend((val,val,val,1))
                else:
                    dx = heights[y*size+(x+1)%size] - heights[y*size+(x-1)%size]
                    dy = heights[((y+1)%size)*size+x] - heights[((y-1)%size)*size+x]
                    normal = Vector((-dx*.7,-dy*.7,1)).normalized()
                    pixels.extend((normal.x*.5+.5,normal.y*.5+.5,normal.z*.5+.5,1))
        image.pixels.foreach_set(pixels)
        image.filepath_raw = str(TEX / f'{family}_{mode}.png')
        image.file_format = 'PNG'
        if mode == 'normal': image.colorspace_settings.name = 'Non-Color'
        image.save()
        shutil.copy2(image.filepath_raw, RUNTIME / Path(image.filepath_raw).name)


for family in ('wood','bark','foliage','cloth','paper','plaster'):
    make_texture(family)


def material(name, color, roughness=.62, metal=0):
    mat = bpy.data.materials.new('WR3_'+name)
    mat.diffuse_color = rgba(color)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = rgba(color)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metal
    return mat


M = {k: material(k,c,r,m) for k,c,r,m in [
    ('apple','bd544a',.42,0), ('stem','76513b',.8,0), ('leaf','789865',.72,0),
    ('vein','b7c083',.7,0), ('wicker','b99158',.7,0), ('wicker_light','cba96b',.72,0),
    ('wicker_shade','987344',.78,0), ('sponge','d9af71',.83,0), ('icing','f8edd4',.55,0),
    ('jam','b85562',.52,0), ('berry','b64e4b',.5,0), ('seed','efd19d',.68,0),
    ('plate','84aaa3',.36,0), ('cover','507c78',.75,0), ('paper','efe1bc',.82,0),
    ('gold','d3b46d',.44,.25), ('ribbon','b86f62',.76,0)
]}


def finish(obj, name, mat, smooth=True):
    obj.name = name
    obj.data.materials.append(M[mat])
    if smooth:
        for poly in obj.data.polygons: poly.use_smooth = True
    return obj


def cube(name, loc, size, mat, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = finish(bpy.context.object,name,mat,False)
    obj.scale = size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod = obj.modifiers.new('Soft crafted edges','BEVEL')
        mod.width = bevel; mod.segments = 3
        bpy.ops.object.modifier_apply(modifier=mod.name)
        norm = obj.modifiers.new('Weighted corners','WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=norm.name)
    return obj


def sphere(name, loc, scale, mat, segments=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=loc)
    obj = finish(bpy.context.object,name,mat)
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return obj


def tube(name, points, radius, mat, closed=False, sides=6):
    curve = bpy.data.curves.new(name,'CURVE'); curve.dimensions = '3D'
    curve.resolution_u = 1; curve.bevel_depth = radius; curve.resolution_u = 1
    curve.bevel_resolution = 0; curve.resolution_u = 1; curve.fill_mode = 'FULL'; curve.use_fill_caps = True
    spline = curve.splines.new('POLY'); spline.points.add(len(points)-1)
    for v,p in zip(spline.points,points): v.co=(*p,1)
    spline.use_cyclic_u = closed
    obj = bpy.data.objects.new(name,curve); bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.object.convert(target='MESH')
    return finish(bpy.context.object,name,mat)


def cylinder(name, radius, depth, loc, mat, bevel=.02):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=radius,depth=depth,location=loc)
    obj=finish(bpy.context.object,name,mat)
    if bevel:
        mod=obj.modifiers.new('Rounded edge','BEVEL');mod.width=bevel;mod.segments=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def leaf(name,start,end,width,mat='leaf'):
    a,b=Vector(start),Vector(end); direction=b-a
    side=Vector((-direction.y,direction.x,0)).normalized()*width
    mid=(a+b)*.5+Vector((0,0,width*.35))
    verts=[a,mid+side,b,mid-side,mid+Vector((0,0,.008)),mid-Vector((0,0,.008))]
    faces=[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,0,5),(2,1,5),(3,2,5),(0,3,5)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    finish(obj,name,mat)
    tube(name+'_vein',[a+Vector((0,0,.009)),mid+Vector((0,0,.018)),b+Vector((0,0,.009))],.005,'vein')
    return obj


def apple():
    body=sphere('Apple_lobed_body',(0,0,0),(1,1,1),'apple',40,24)
    for v in body.data.vertices:
        x,y,z=v.co;theta=math.atan2(y,x)
        radial=math.sqrt(x*x+y*y)
        lobe=1+.035*math.cos(5*theta)*(abs(z)**2)
        v.co=(x*.29*lobe*(1+.1*z),y*.29*lobe*(1+.1*z),z*.265-.045*math.exp(-radial*radial*28)*(1 if z>0 else -1))
    # Soft color variation is part of the authored surface, no baked shadows.
    attr=body.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    base=rgba('bd544a')
    for loop in body.data.loops:
        v=body.data.vertices[loop.vertex_index].co
        shade=.92+.08*math.sin(v.x*13+v.y*5)+.045*math.cos(v.z*19)
        attr.data[loop.index].color=tuple(min(1,c*shade) for c in base[:3])+(1,)
    node=M['apple'].node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='Color'
    M['apple'].node_tree.links.new(node.outputs['Color'],M['apple'].node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    tube('Apple_curved_stem',[(0,0,.215),(.008,0,.27),(.025,.005,.33)],.018,'stem')
    leaf('Apple_leaf',(.012,0,.29),(.19,.08,.33),.052)
    for t in [-.3,0,.3]:
        angle=t+math.pi*.6
        tube('Apple_calyx',[(0,0,-.22),(.027*math.cos(angle),.027*math.sin(angle),-.24)],.006,'stem')


def basket():
    # 28 vertical stakes, 10 alternating woven courses, real open mouth.
    for i in range(28):
        angle=i*math.tau/28
        pts=[]
        for j in range(25):
            z=.03+j*.018;rad=.31+.09*(z/.48)+.007*math.cos(j*math.pi/2+i*math.pi)
            pts.append((rad*math.cos(angle),rad*math.sin(angle),z))
        tube('Basket_stake',pts,.012,'wicker_shade')
    for j in range(10):
        z=.05+j*.043;pts=[]
        for i in range(168):
            angle=i*math.tau/168;rad=.31+.09*(z/.48)+.012*math.sin(28*angle+j*math.pi)
            pts.append((rad*math.cos(angle),rad*math.sin(angle),z+.003*math.cos(28*angle)))
        tube('Basket_weave',pts,.016,'wicker' if j%2 else 'wicker_light',True)
    for z,rad in [(.02,.31),(.47,.405),(.445,.4)]:
        tube('Basket_bound_rim',[(rad*math.cos(i*math.tau/96),rad*math.sin(i*math.tau/96),z) for i in range(96)],.023,'wicker_light',True)
    cylinder('Basket_closed_base',.31,.026,(0,0,.02),'wicker_shade',.008)
    for i in range(-5,6):
        x=i*.052; reach=math.sqrt(max(0,.29**2-x*x))
        tube('Basket_base_weave',[(x,-reach,.038),(x,reach,.038)],.012,'wicker')
    for y in (-.19,.19):
        pts=[(.34*math.cos(i*math.pi/32),y,.44+.30*math.sin(i*math.pi/32)) for i in range(33)]
        tube('Basket_side_handle',pts,.025,'wicker_light')


def cake():
    cylinder('Cake_ceramic_plate',.57,.045,(0,0,.025),'plate')
    cylinder('Cake_lower_sponge',.47,.19,(0,0,.145),'sponge')
    cylinder('Cake_jam_filling',.475,.035,(0,0,.255),'jam',.012)
    cylinder('Cake_upper_sponge',.47,.19,(0,0,.365),'sponge')
    # Closed icing mesh with scalloped/dripping lower skirt.
    verts=[]; count=72
    for ring in range(4):
        for i in range(count):
            a=i*math.tau/count
            r=[.01,.46,.489,.485][ring]
            drip=.045*(.5+.5*math.cos(a*9))**4+.022*(.5+.5*math.sin(a*5))**4
            z=[.495,.49,.46,.405-drip][ring]
            verts.append((r*math.cos(a),r*math.sin(a),z))
    faces=[]
    for ring in range(3):
        for i in range(count): faces.append((ring*count+i,ring*count+(i+1)%count,(ring+1)*count+(i+1)%count,(ring+1)*count+i))
    faces.append(tuple(reversed(range(count))))
    faces.append(tuple(range(count*3,count*4)))
    mesh=bpy.data.meshes.new('Icing drape');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new('Cake_dripping_icing',mesh);bpy.context.collection.objects.link(obj);finish(obj,obj.name,'icing')
    for i in range(7):
        a=i*math.tau/7; x=.32*math.cos(a); y=.32*math.sin(a)
        berry=sphere('Cake_strawberry',(x,y,.565),(.074,.074,.105),'berry',16,10)
        for v in berry.data.vertices:
            v.co.x*=1-.2*(v.co.z/.105);v.co.y*=1-.2*(v.co.z/.105)
        for j in range(8):
            ang=j*math.tau/8
            sphere('Berry_seed',(x+.068*math.cos(ang),y+.068*math.sin(ang),.565),(.007,.007,.011),'seed',8,4)
        for j in range(3):
            ang=j*math.tau/3
            leaf('Berry_calyx',(x,y,.66),(x+.065*math.cos(ang),y+.065*math.sin(ang),.65),.018)
    for i in range(14):
        a=i*math.tau/14
        sphere('Cake_cream_rosette',(.41*math.cos(a),.41*math.sin(a),.505),(.036,.036,.03),'icing',12,6)
    for i in range(36):
        a=random.random()*math.tau;z=random.uniform(.07,.43)
        if .23<z<.28:continue
        sphere('Sponge_crumb',(.471*math.cos(a),.471*math.sin(a),z),(.007,.007,.01),'seed',6,4)


def book():
    cube('Book_bottom_cover',(0,0,.018),(.70,.52,.035),'cover',.018)
    cube('Book_paper_block',(.008,0,.075),(.655,.475,.085),'paper',.012)
    cube('Book_top_cover',(0,0,.131),(.70,.52,.035),'cover',.018)
    cube('Book_rounded_spine',(-.33,0,.075),(.045,.52,.125),'cover',.02)
    for i in range(7):
        z=.042+i*.010
        tube('Book_page_edges',[(.33,-.23,z),(.335,0,z+.002),(.33,.23,z)],.0015,'gold')
    for y in [-.19,-.13,.13,.19]: cube('Book_spine_band',(-.352,y,.075),(.006,.014,.112),'gold',.003)
    # Cover's inset border, embossed leaf motif and a ribbon bookmark.
    tube('Book_border',[(-.26,-.20,.152),(.27,-.20,.152),(.29,-.18,.152),(.29,.18,.152),(.27,.20,.152),(-.26,.20,.152)],.004,'gold')
    leaf('Book_embossed_leaf',(-.08,-.09,.151),(.12,.105,.153),.065,'gold')
    cube('Book_cloth_bookmark',(.19,-.16,.035),(.052,.34,.008),'ribbon',.004)
    for x in [-.28,.28]:
        for y in [-.20,.20]:
            cube('Book_corner',(x,y,.152),(.045,.035,.006),'gold',.004)


def invitation():
    # Godot +Z front is Blender -Y. Card-centred pivot, .32 x .23 m face.
    cube('Invitation_envelope',(0,0,0),(.32,.012,.23),'paper',.008)
    verts=[(-.15,-.007,.106),(.15,-.007,.106),(0,-.016,-.023),
           (-.15,-.005,.106),(.15,-.005,.106),(0,-.014,-.023)]
    faces=[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)]
    mesh=bpy.data.meshes.new('Folded invitation flap');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new('Invitation_folded_flap',mesh);bpy.context.collection.objects.link(obj);finish(obj,obj.name,'icing',False)
    tube('Invitation_fold_edge',[(-.15,-.009,.105),(0,-.018,-.025),(.15,-.009,.105)],.0018,'gold')
    tube('Invitation_lower_fold',[(-.15,-.007,-.103),(-.032,-.009,-.006)],.0011,'wicker_light')
    tube('Invitation_lower_fold',[(.15,-.007,-.103),(.032,-.009,-.006)],.0011,'wicker_light')
    seal=cylinder('Invitation_wax_seal',.025,.006,(0,-.021,-.026),'ribbon',.002)
    seal.rotation_euler.x=math.pi/2
    tube('Invitation_seal_leaf',[(-.010,-.025,-.030),(0,-.027,-.019),(.010,-.025,-.025)],.0022,'gold')
    for x in [-.142,.142]:
        for z in [-.096,.096]:sphere('Invitation_corner_emboss',(x,-.008,z),(.004,.0015,.004),'gold',12,6)


def nameplate():
    cube('Nameplate_rounded_frame',(0,0,0),(.32,.012,.23),'cover',.012)
    cube('Nameplate_inset_paper',(0,-.008,0),(.286,.005,.195),'paper',.010)
    # A slim raised gilt rim and tiny corner stitching, leaving the centre blank.
    points=[(-.135,-.012,-.089),(.135,-.012,-.089),(.141,-.012,-.083),(.141,-.012,.083),(.135,-.012,.089),(-.135,-.012,.089),(-.141,-.012,.083),(-.141,-.012,-.083)]
    tube('Nameplate_gilt_border',points,.0015,'gold',True)
    for x in [-.12,-.105,.105,.12]:
        for z in [-.10,.10]:
            tube('Nameplate_stitched_trim',[(x-.003,-.008,z),(x+.003,-.008,z)],.0008,'paper')
    for sign in [-1,1]:
        leaf_obj=sphere('Nameplate_embossed_leaf',(sign*.116,-.016,-.068),(.015,.003,.006),'leaf',16,8)
        leaf_obj.rotation_euler.y=sign*.45
    tube('Nameplate_leaf_stem',[(-.115,-.019,-.072),(-.100,-.019,-.071),(-.089,-.018,-.059)],.0012,'gold')


def collect_asset(key, build):
    old=set(bpy.data.objects)
    build()
    objects=[o for o in bpy.data.objects if o not in old and o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    obj=bpy.context.object;obj.name='WR3_'+key
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    # Recalculate, weld only coincident seam vertices, triangulate consistently.
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.000001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free()
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.015)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.calc_loop_triangles()
    coords=[obj.matrix_world@v.co for v in obj.data.vertices]
    lo=[min(v[i] for v in coords) for i in range(3)]; hi=[max(v[i] for v in coords) for i in range(3)]
    glb=OUT/(key+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_cameras=False,export_lights=False)
    shutil.copy2(glb,RUNTIME/glb.name)
    result={'id':key,'source':f'{key}.glb','runtime':f'game/assets/world_refresh_v3/{key}.glb',
            'sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'bytes':glb.stat().st_size,
            'vertices':len(obj.data.vertices),'triangles':len(obj.data.loop_triangles),'materials':len(obj.data.materials),
            'aabb_godot_min':[lo[0],lo[2],-hi[1]],'aabb_godot_size':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],
            'origin':'apple body center' if key=='apple' else ('card center; front +Z' if key in ('invitation','nameplate') else 'base center'),
            'collision':'none; existing scene collision and interaction proxies retained','uv':'smart projected UV0',
            'lod':'shared mesh; bounded near-field replacements only; no independent LOD mesh'}
    return obj,result


assets=[];objects=[]
for key,build in [('apple',apple),('basket',basket),('cake',cake),('book',book),('invitation',invitation),('nameplate',nameplate)]:
    obj,record=collect_asset(key,build);objects.append(obj);assets.append(record)
    obj.hide_set(True)
for obj,loc in zip(objects,[(-1,-1,0),(1,-1,0),(-1,1,0),(1,1,0),(-.35,0,.13),(.35,0,.13)]):
    obj.hide_set(False);obj.location=loc
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'world_props_v3.blend'))
manifest={
    'schema_version':1,'revision':'world-refresh-v3','status':'authored_exported_pending_engine_visual_review',
    'direction':'warm toy-like storybook; softened edges, coral fruit, sage leaves, honey wicker, teal linen cover; readable silhouettes',
    'tool':'Blender '+bpy.app.version_string,'source_script':'scripts/build_world_art_v3.py','seed':3217,
    'source_script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'editable_source':{'path':'world_props_v3.blend','sha256':hashlib.sha256((OUT/'world_props_v3.blend').read_bytes()).hexdigest()},
    'authorship':'Original procedural mesh and analytic texture authoring for this project; no downloaded third-party assets.',
    'license':'Project-owned original source; no external artwork restrictions introduced.',
    'engine':'Godot 4.7 GL Compatibility','world_unit':'meter; export +Y up',
    'source_preservation':'Builder starts from factory empty scene and never loads or writes existing map blend/GLB files.',
    'assets':assets,
    'surface_families':['wood','bark','foliage','cloth','paper','plaster'],
    'textures':[{'path':str(p.relative_to(OUT)).replace('\\','/'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
                for p in sorted((OUT/'textures').glob('*.png'))],
    'texture_contract':{'size':[256,256],'channels':'neutral RGB albedo modulation and OpenGL tangent-space normal; non-color normal',
                        'mapping':'runtime world triplanar only on original untextured standard materials; original colors retained',
                        'filter':'linear with mipmaps; repeat'},
    'limits':['DCC render is an asset preview, not in-engine acceptance.','Repeated large map foliage keeps original silhouettes; this pass adds surface detail.',
              'No separate LOD meshes: near-field props share loaded resources and are limited to existing named props.']}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
(RUNTIME/'manifest.json').write_text(json.dumps({'revision':manifest['revision'],'assets':assets},indent=2),encoding='utf-8')
print('WORLD_ART_EXPORT',json.dumps({r['id']:{'triangles':r['triangles'],'bytes':r['bytes']} for r in assets}))

if '--render' in sys.argv:
    # Small evidence image only; background rendering requires parent coordination.
    for obj in objects:obj.hide_render=False
    cube('Preview_floor',(0,0,-.07),(6,6,.1),'paper',.02)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.render.resolution_x=1000;scene.render.resolution_y=760;scene.render.resolution_percentage=100
    scene.world.color=(.55,.55,.55)
    for location,power,size in [((1,-3,6),500,5),((-4,1,3),220,4)]:
        bpy.ops.object.light_add(type='AREA',location=location);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size
        light.rotation_euler=(Vector((0,0,0))-light.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=(4,-6,7));cam=bpy.context.object
    cam.rotation_euler=(Vector((0,0,.15))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=4.8;scene.camera=cam
    scene.view_settings.view_transform='AgX';scene.render.filepath=str(OUT/'props-review.png')
    bpy.ops.render.render(write_still=True)
