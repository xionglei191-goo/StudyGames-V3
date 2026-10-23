"""Build a separate, editable, walkable second-level school campus.

This script owns only interiors/school/v02 outputs and never changes the shared
interior pipeline or manifest. Original school v01 assets are read-only inputs.
"""
import argparse
import collections
import hashlib
import json
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/blender/school/school_campus_v01.blend'
OUT = ROOT / 'assets/blender/interiors/school'
sys.path.insert(0, str(ROOT / 'assets/blender/interiors/scripts'))
import modeling as m
import pipeline

SOURCE_HASHES = {}
FONT = None
REUSED = []
DOORS = {
    'CLASSROOM': (0.0, 6.7),
    'MUSIC_ROOM': (-16.0, 3.8),
    'ART_ROOM': (-16.0, -8.7),
    'SCIENCE_ROOM': (16.0, 5.2),
    'CANTEEN': (16.0, -7.4),
    'PLAYGROUND': (10.5, -17.7),
}
MEMORIES = [(-6.5, -16.6), (-5.8, 6.2), (4.8, 0.0), (20.7, -12.6), (21.0, -6.9)]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def bounds(ob):
    points = [ob.matrix_world @ Vector(p) for p in ob.bound_box]
    return [min(p[i] for p in points) for i in range(3)] + [max(p[i] for p in points) for i in range(3)]


def inspect_source():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    bpy.context.view_layer.update()
    report = {'source': str(SOURCE), 'objects': [{'name': ob.name, 'type': ob.type,
        'parent': ob.parent.name if ob.parent else None,
        'position': list(ob.matrix_world.translation),
        'bounds': bounds(ob) if ob.type == 'MESH' else None,
        'collections': [c.name for c in ob.users_collection]}
        for ob in bpy.context.scene.objects]}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'source_inspection_v02.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
    print('CAMPUS_SOURCE_INSPECTED', len(report['objects']), flush=True)


def text(name, body, pos, size=.32, mat='teal', facing='front'):
    ob = m.text(name, body, pos, size, mat, facing)
    # Campus signs are viewed at metres, so font bevel tessellation is wasteful.
    ob.data.resolution_u = 3
    ob.data.bevel_depth = 0
    ob.data.bevel_resolution = 0
    ob.data.extrude = .002
    if FONT:
        ob.data.font = FONT
    return ob


def proxy(name, pos, size):
    return m.collider(name, pos, size)


def circle_proxy(name, xy, radius, height):
    old = m.CURRENT
    m.group('90_Collision_Proxies')
    ob = m.cyl('SG_COLLIDER_' + name, (*xy, height / 2), radius, height, 'proxy', 24)
    ob.hide_render = True
    ob.display_type = 'WIRE'
    ob['collision_proxy'] = True
    m.group(old)
    return ob


def plane(name, xmin, ymin, xmax, ymax, z, mat):
    return m.mesh(name, [(xmin,ymin,z),(xmax,ymin,z),(xmax,ymax,z),(xmin,ymax,z)], [(0,1,2,3)], mat)


def strip(name, points, width, mat='path', z=.008):
    verts, faces = [], []
    for index, point in enumerate(points):
        before = Vector(points[max(0,index-1)])
        after = Vector(points[min(len(points)-1,index+1)])
        direction = (after-before).normalized()
        normal = Vector((-direction.y,direction.x))*width/2
        for p in (Vector(point)+normal,Vector(point)-normal):
            verts.append((p.x,p.y,z))
        if index:
            a=2*index-2
            faces.append((a+1,a+3,a+2,a))
    return m.mesh(name,verts,faces,mat)


def disc_ring(name, center, inner, outer, mat, z=.01, segments=64):
    verts=[]
    for i in range(segments):
        angle=i*math.tau/segments
        for radius in (inner,outer):
            verts.append((center[0]+radius*math.cos(angle),center[1]+radius*math.sin(angle),z))
    faces=[]
    for i in range(segments):
        a=i*2;b=((i+1)%segments)*2
        faces.append((a,a+1,b+1,b))
    return m.mesh(name,verts,faces,mat)


def roof(name, x, y, width, depth, eave, rise, mat):
    x0,x1=x-width/2,x+width/2;y0,y1=y-depth/2,y+depth/2
    verts=[(x0,y0,eave),(x1,y0,eave),(x0,y,eave+rise),(x1,y,eave+rise),(x0,y1,eave),(x1,y1,eave)]
    ob=m.mesh(name,verts,[(0,1,3,2),(2,3,5,4),(0,2,4),(1,5,3),(0,4,5,1)],mat)
    m.soften(ob,.055)
    for yy in (y0,y1):
        m.box(name+'_Eave',(x,yy,eave),(width+.12,.16,.15),'ivory',.025)
    m.beam(name+'_Ridge',(x0-.1,y,eave+rise+.025),(x1+.1,y,eave+rise+.025),.09,'teal')
    # Parallel raised seams keep the roofs readable without heavy tile meshes.
    for i in range(1,11):
        xx=x0+width*i/11
        for side in (-1,1):
            m.beam(name+'_Seam',(xx,y,eave+rise+.025),(xx,y+side*depth/2,eave+.025),.018,mat)
    return ob


def window(name,x,y,z,w=1.35,h=1.7):
    m.box(name+'_Trim',(x,y,z),(w+.22,.18,h+.22),'ivory',.045)
    m.box(name+'_Glass',(x,y-.12,z),(w,.045,h),'glass',.025)
    m.box(name+'_Vertical',(x,y-.16,z),(.065,.045,h),'ivory',.012)
    m.box(name+'_Horizontal',(x,y-.16,z),(w,.045,.065),'ivory',.012)
    m.box(name+'_Sill',(x,y-.10,z-h/2-.12),(w+.36,.38,.14),'lightwood',.04)


def entrance(name,x,y,mat='teal'):
    m.box(name+'_Frame',(x,y,1.30),(1.90,.26,2.6),'ivory',.08)
    m.box(name+'_Leaf',(x,y-.16,1.25),(1.64,.14,2.42),mat,.045)
    for dx in (-.4,.4):
        m.box(name+'_Glass',(x+dx,y-.245,1.68),(.54,.055,1.06),'glass',.035)
        m.ball(name+'_Handle',(x+dx*.36,y-.29,.95),(.05,.035,.07),'gold',12,8)
    m.box(name+'_Divider',(x,y-.26,1.23),(.055,.04,2.4),'ivory',.015)
    m.box(name+'_Doorstep',(x,y-.38,.018),(2.6,.85,.036),'sand',.01)


def flowerbox(name,x,y,w=2.4,mat='clay'):
    m.box(name+'_Base',(x,y,.20),(w,.65,.40),mat,.08)
    m.box(name+'_Soil',(x,y,.405),(w-.14,.5,.025),'soil',.015)
    for i in range(max(3,int(w/.35))):
        xx=x-w*.39+i*w*.78/max(1,int(w/.35)-1)
        m.ball(name+'_Leaves',(xx,y,.57),(.26,.26,.25),'leaflight',12,8)
        m.ball(name+'_Flower',(xx,y-.03,.79),(.11,.11,.10),'pink' if i%2 else 'yellow',12,8)
    proxy(name,(x,y,.36),(w,.66,.72))


def tree(name,x,y,scale=1.0):
    m.cyl(name+'_Trunk',(x,y,1.15*scale),.16*scale,2.3*scale,'wood',12)
    for dx,dy,z,r in [(-.50,0,2.40,.94),(.46,.08,2.68,1.02),(0,-.35,3.12,.91)]:
        m.ball(name+'_Crown',(x+dx*scale,y+dy*scale,z*scale),(r*scale,r*.85*scale,r*scale),'leaflight',16,10)
    circle_proxy(name+'_Trunk',(x,y),.21*scale,2.2*scale)


def signboard(name,x,y,title,subtitle='',width=2.6,mat='teal'):
    for dx in (-width*.39,width*.39):
        m.box(name+'_Post',(x+dx,y,.72),(.12,.14,1.44),'oak',.025)
    m.box(name+'_Frame',(x,y,1.60),(width,.20,1.24),'lightwood',.065)
    m.box(name+'_Face',(x,y-.115,1.60),(width-.20,.035,1.04),mat,.025)
    text(name+'_Title',title,(x,y-.15,1.79),.28,'ivory')
    if subtitle:
        text(name+'_Subtitle',subtitle,(x,y-.15,1.39),.16,'ivory')
    proxy(name,(x,y,1.0),(width,.38,2.0))


def import_original():
    with bpy.data.libraries.load(str(SOURCE),link=False) as (data_from,data_to):
        data_to.objects=[name for name in data_from.objects if name.startswith('ASSET_')]
    collection=bpy.data.collections.new('01_Reused_Original_Campus')
    bpy.context.scene.collection.children.link(collection)
    loaded=[ob for ob in data_to.objects if ob]
    for ob in loaded:
        collection.objects.link(ob)
    bpy.context.view_layer.update()
    teaching=bpy.data.objects.get('ASSET_SCHOOL_ROOT')
    original_campus=bpy.data.objects.get('ASSET_SCHOOL_CAMPUS_ROOT')
    teaching_children=set(teaching.children_recursive)
    keep={teaching}|teaching_children
    teaching.name='Campus_Teaching_Building_ROOT'
    teaching.location.y+=13.0
    teaching['source_asset']=str(SOURCE.relative_to(ROOT))
    for ob in teaching_children:
        REUSED.append(ob.name)
        if ob.name=='ASSET_School_Facade_Name':
            keep.discard(ob)
    # Put the actual original court and hoop into the new southeast sports area.
    parts=('Playground_','Court_','Hoop_','Backboard','Basket_Rim')
    sports=[];racks=[];guide=[];benches=[];gates=[]
    for ob in list(original_campus.children_recursive):
        suffix=ob.name.removeprefix('ASSET_School_')
        if suffix.startswith(parts):sports.append(ob)
        elif suffix.startswith(('Ball_Rack','Play_Ball')):racks.append(ob)
        elif suffix.startswith(('Noticeboard_','Notice_Paper')):guide.append(ob)
        elif suffix.startswith('Schoolyard_Bench'):benches.append(ob)
        elif suffix.startswith(('Gate_Pier','Gate_Cap','Gate_Lamp')):gates.append(ob)
    def relocate(objects,delta,root_name):
        m.group('01_Reused_Original_Campus')
        root=m.empty(root_name,(0,0,0))
        root['source_asset']=str(SOURCE.relative_to(ROOT))
        for ob in objects:
            matrix=ob.matrix_world.copy()
            ob.parent=root
            ob.matrix_world=Matrix.Translation(Vector(delta))@matrix
            keep.add(ob);REUSED.append(ob.name)
        return root
    relocate(sports,(27.25,-12.45,-.173),'Campus_Playground_Original_ROOT')
    relocate(racks,(37.4,-15.4,0),'Campus_Equipment_Original_ROOT')
    relocate(guide,(-10.35,-9.2,0),'Campus_Guide_Original_ROOT')
    relocate([o for o in benches if bounds(o)[0]<0],(1.4,5.1,0),'Campus_Bench_West_Original_ROOT')
    relocate([o for o in benches if bounds(o)[0]>0],(.4,8.5,0),'Campus_Bench_East_Original_ROOT')
    for side in (-1,1):
        selected=[o for o in gates if o.matrix_world.translation.x*side>0]
        relocate(selected,(side*1.1,-12.75,0),'Campus_Gate_'+('Left' if side<0 else 'Right')+'_Original_ROOT')
    for ob in loaded:
        if ob not in keep:
            bpy.data.objects.remove(ob,do_unlink=True)
    bpy.context.view_layer.update()
    # No old school model or source file is saved; these are independent appended copies.
    m.group('02_Teaching_Courtyard')
    text('Teaching_Facade_CN','阳光教学楼',(0,8.54,3.84),.39,'ivory')
    text('Teaching_Facade_EN','CLASSROOMS',(0,8.52,3.39),.22,'ivory')
    proxy('Teaching_Main',(0,13.25,2.7),(16.8,6.5,5.4))
    proxy('Teaching_Tower',(0,9.95,4.0),(3.15,3.10,8.0))
    proxy('Guide_Original',(-6.5,-15.2,1.0),(2.0,.45,2.0))
    proxy('Bench_West_Original',(-6.0,.4,.75),(1.85,1.0,1.5))
    proxy('Bench_East_Original',(6.2,3.7,.75),(1.85,1.0,1.5))
    proxy('Sports_Rack_Original',(20.7,-11.0,.5),(2.2,.75,1.0))
    proxy('Sports_Hoop_Original',(9.65,-13.0,1.7),(.42,.42,3.4))
    for x in (-3.0,3.0):proxy('Gate_Pier_'+str(x),(x,-18.9,.78),(.70,.76,1.56))
    # Thin underlay preserves the original court's terracotta border at lawn level.
    plane('Sports_Red_Border',9.30,-17.25,18.70,-8.75,.006,'clay')
    print('ORIGINAL_ASSET_REUSED',len(REUSED),flush=True)


def campus_base():
    m.group('00_Campus_Ground')
    m.box('SG_FLOOR_Main',(0,0,-.22),(48.0,40.0,.44),'grass',.15)
    m.box('Campus_Foundation_Rim',(0,0,-.34),(48.15,40.15,.22),'sand',.15)
    m.box('Campus_Foundation_Lower',(0,0,-.53),(47.8,39.8,.18),'oak',.12)
    strip('Main_Welcome_Walk',[(0,-20),(0,-5.0)],4.4)
    strip('Teaching_Walk',[(0,4.9),(0,8.4)],4.4)
    disc_ring('Garden_Round_Walk',(0,0),3.45,5.65,'path')
    strip('South_Cross_Walk',[(-21,-9.1),(19.5,-9.1)],3.6)
    strip('West_Academy_Walk',[(-10.5,-15),(-10.5,5.0)],3.1)
    strip('East_Academy_Walk',[(10.0,-17.7),(10.0,6.5)],3.1)
    strip('North_Cross_Walk',[(-18,3.8),(18,3.8)],3.2)
    strip('Music_Entry_Walk',[(-16,3.8),(-16,5.7)],3.0)
    strip('Science_Entry_Walk',[(16,3.8),(16,7.2)],3.1)
    strip('Canteen_Entry_Walk',[(16,-9.1),(16,-5.6)],3.4)
    strip('Art_Entry_Walk',[(-16,-9.1),(-16,-6.8)],3.2)
    strip('Guide_Approach',[(0,-16.6),(-6.5,-16.6)],2.5)
    strip('Sports_South_Walk',[(0,-17.7),(19.7,-17.7)],2.5)
    strip('Equipment_Path',[(19.9,-16.5),(20.7,-10.1)],2.1)
    strip('Menu_Path',[(16,-7.0),(21,-7.0)],2.3)
    # Flush pavers clarify circulation without producing stair collisions.
    for yy in (-18.3,-16.8,-15.3,-13.8,-12.3,-10.8,-6.0,6.3):
        m.box('Welcome_Paver',(0,yy,.013),(3.8,.035,.01),'sand',.004)
    m.group('03_Perimeter_Low_Walls')
    for side in (-1,1):
        x=side*23.55
        m.box('Side_Low_Planted_Wall',(x,0,.37),(.38,39,.74),'cream',.07)
        proxy('Boundary_'+str(side),(x,0,1.0),(.40,39.5,2.0))
    m.box('Rear_Low_Wall',(0,19.55,.40),(47.3,.40,.80),'cream',.07)
    proxy('Boundary_Rear',(0,19.60,1.0),(47.5,.42,2.0))
    for a,b in [(-23.5,-3.4),(3.4,23.5)]:
        m.box('Front_Low_Wall',((a+b)/2,-19.55,.22),(b-a,.38,.44),'cream',.06)
        proxy('Front_Boundary_'+str(a),((a+b)/2,-19.65,1.0),(b-a,.40,2.0))
        for i in range(int((b-a)/2)+1):
            x=a+(b-a)*i/max(1,int((b-a)/2))
            m.box('Front_Fence_Post',(x,-19.55,.56),(.15,.15,.78),'lightwood',.025)
        for z in (.52,.78):m.beam('Front_Fence_Rail',(a,-19.55,z),(b,-19.55,z),.045,'lightwood')
    for x in (-22.8,22.8):
        for y in (-16,-10,-3,4,11,17):tree('Boundary_Tree',x,y,.82)
    for x in (-17,-10,10,17):tree('Rear_Tree',x,18.0,.90)
    # Campus flags mark the low, open front gate without a camera-blocking arch.
    for x in (-4.2,4.2):
        m.cyl('Gate_Flag_Pole',(x,-18.7,1.9),.055,3.8,'lightwood',12)
        m.box('Gate_Flag',(x+.4,-18.7,3.25),(.8,.06,.65),'pink' if x<0 else 'teal',.02)
    text('Gate_Name','SUNSHINE SCHOOL',(-11.5,-19.80,.65),.26,'teal')


def academic_building(key,title,subtitle,x,y,width,depth,wall,roof_mat,kind):
    m.group('10_'+key+'_Building')
    front=y-depth/2
    m.box(key+'_Foundation',(x,y,.12),(width+.25,depth+.25,.24),'sand',.08)
    m.box(key+'_Walls',(x,y,1.95),(width,depth,3.9),wall,.12)
    m.box(key+'_Base_Band',(x,y,.40),(width+.07,depth+.07,.32),'lightwood',.03)
    m.box(key+'_Cornice',(x,y,3.92),(width+.22,depth+.22,.18),'ivory',.04)
    roof(key+'_Roof',x,y,width+.65,depth+.75,4.05,1.25,roof_mat)
    entrance(key+'_Entrance',x,front-.12,'teal' if kind!='art' else 'rose')
    for dx in (-width*.32,width*.32):
        window(key+'_Front_Window',x+dx,front-.10,2.05,1.36,1.62)
        flowerbox(key+'_Window_Planter',x+dx,front-.36,1.45,'clay' if kind!='science' else 'teal')
    m.box(key+'_Name_Plaque',(x,front-.24,3.25),(3.05,.13,.72),'ivory',.08)
    text(key+'_Name_CN',title,(x,front-.33,3.40),.32,'teal')
    text(key+'_Name_EN',subtitle,(x,front-.33,3.08),.20,'teal')
    for side in (-1,1):
        xx=x+side*(width/2+.06)
        for yy in (y-depth*.25,y+depth*.25):
            glass=m.box(key+'_Side_Window',(xx,yy,2.05),(.10,1.6,1.60),'glass',.025)
            for z in (1.20,2.90):m.box(key+'_Side_Trim',(xx+side*.04,yy,z),(.13,1.82,.12),'ivory',.025)
    proxy(key+'_Building',(x,y,2.55),(width+.15,depth+.15,5.1))
    if kind=='music':
        # A real raised double-note emblem and a compact outdoor xylophone.
        for dx in (-.44,.43):
            m.ball('Music_Note_Head',(x+dx,front-.18,4.58),(.26,.10,.18),'navy',16,10)
            m.box('Music_Note_Stem',(x+dx+.17,front-.17,4.95),(.09,.12,.75),'navy',.018)
        m.box('Music_Note_Beam',(x+.17,front-.17,5.26),(.94,.12,.15),'navy',.025)
        for i,mat in enumerate(['red','orange','yellow','mint','blue','lavender']):
            m.box('Music_Outdoor_Xylophone_Key',(x-4.9+i*.29,y-1.4,1.0),(.24,1.1-i*.06,.10),mat,.035)
        for xx in (x-4.65,x-3.6):m.box('Music_Xylophone_Leg',(xx,y-1.4,.48),(.12,.74,.96),'oak',.025)
        proxy('Music_Outdoor_Xylophone',(x-4.15,y-1.4,.65),(1.8,1.2,1.3))
    elif kind=='art':
        m.cyl('Art_Palette',(x,front-.13,4.79),.62,.10,'lightwood',32).rotation_euler.x=math.pi/2
        for i,mat in enumerate(['red','yellow','blue','mint','lavender']):
            a=math.pi*.2+i*math.tau/5
            m.ball('Art_Palette_Paint',(x+.38*math.cos(a),front-.21,4.79+.38*math.sin(a)),(.12,.055,.12),mat,12,8)
        for xx,mat in [(x-5.0,'pink'),(x-4.0,'blue')]:
            m.beam('Art_Outdoor_Easel',(xx-.35,y-1.6,.03),(xx,y-1.6,1.85),.045,'oak')
            m.beam('Art_Outdoor_Easel',(xx+.35,y-1.6,.03),(xx,y-1.6,1.85),.045,'oak')
            m.box('Art_Outdoor_Canvas',(xx,y-1.68,1.25),(.70,.10,.85),'ivory',.025)
            m.ball('Art_Painting_Color',(xx,y-1.75,1.3),(.20,.025,.25),mat,16,10)
            proxy('Art_Outdoor_Easel_'+str(xx),(xx,y-1.55,.7),(.8,.55,1.4))
    elif kind=='science':
        # Glass observatory dome and an atom emblem make this more than a renamed room.
        m.cyl('Science_Dome_Base',(x,y+.3,5.12),1.20,.22,'ivory',32)
        m.ball('Science_Rooftop_Dome',(x,y+.3,5.20),(1.10,1.10,.86),'glass',24,14)
        for rotation in [(math.pi/2,0,0),(math.pi/2,.8,0),(math.pi/2,-.8,0)]:
            m.ring('Science_Atom_Orbit',(x,front-.20,4.80),.54,.025,'blue',rotation,segments=32)
        m.ball('Science_Atom_Core',(x,front-.20,4.80),(.16,.13,.16),'yellow',16,10)
        m.cyl('Science_Weather_Stand',(x+5.3,y-.6,1.25),.065,2.5,'metal',12)
        for angle in (0,math.tau/3,2*math.tau/3):
            px=x+5.3+.45*math.cos(angle);py=y-.6+.45*math.sin(angle)
            m.beam('Science_Wind_Arm',(x+5.3,y-.6,2.5),(px,py,2.5),.035,'metal')
            m.ball('Science_Wind_Cup',(px,py,2.5),(.17,.17,.11),'blue',12,8)
        proxy('Science_Weather_Stand',(x+5.3,y-.6,1.25),(.45,.45,2.5))
    elif kind=='canteen':
        for i in range(10):
            xx=x-width/2+(i+.5)*width/10
            m.box('Canteen_Striped_Awning',(xx,front-.75,2.85),(width/10,.95,.12),'teal' if i%2 else 'ivory',.025)
        # A plate and cutlery emblem plus outdoor lunch tables identify the building.
        m.cyl('Canteen_Plate',(x,front-.14,4.75),.45,.10,'ivory',28).rotation_euler.x=math.pi/2
        for dx in (-.70,.70):m.box('Canteen_Cutlery',(x+dx,front-.16,4.75),(.08,.09,.95),'gold',.025)
        m.ball('Canteen_Spoon',(x+.70,front-.16,5.18),(.15,.08,.22),'gold',14,9)
        for i in (-1,0,1):m.box('Canteen_Fork_Tine',(x-.70+i*.075,front-.16,5.18),(.035,.08,.25),'gold',.01)
        m.table('Canteen_Outdoor_Table',x-5.0,y+.5,2.3,1.3,.92,'lightwood')
        for yy in (y-.55,y+1.55):m.bench('Canteen_Outdoor_Bench',x-5.0,yy,2.3,'lightwood',False)


def gardens_and_learning():
    m.group('20_Garden_and_Learning')
    m.cyl('Campus_Central_Planter',(0,0,.22),3.25,.44,'clay',48)
    m.cyl('Campus_Central_Soil',(0,0,.45),3.08,.05,'soil',48)
    circle_proxy('Central_Garden',(0,0),3.28,.9)
    tree('Campus_Garden_Reading_Tree',0,0,1.2)
    for index in range(16):
        a=index*math.tau/16
        x,y=2.66*math.cos(a),2.66*math.sin(a)
        m.ball('Garden_Low_Shrub',(x,y,.69),(.43,.43,.34),'leaflight',12,8)
        m.ball('Garden_Bloom',(x,y,.99),(.16,.16,.14),'pink' if index%2 else 'yellow',12,8)
    signboard('Teaching_Rollcall_Board',-5.8,7.7,'今日班级','HELLO, FRIENDS!',2.7)
    signboard('Canteen_Menu_Board',21.0,-5.3,'今日午餐','RICE  ·  SOUP  ·  FRUIT',2.55)
    text('Guide_School_Title','CAMPUS MAP',(-6.5,-15.39,1.83),.20,'ivory')
    text('Guide_School_Arrow','LEARN  ·  CREATE  ·  PLAY',(-6.5,-15.39,1.31),.095,'ivory')
    # A small outdoor reading/creative garden fills the southwest quarter.
    disc_ring('Reading_Garden_Path',(-14.8,-14.3),1.8,2.5,'path',.009,40)
    m.cyl('Reading_Garden_Lawn',(-14.8,-14.3,.01),1.75,.02,'leaflight',40)
    m.bench('Reading_Garden_Bench',-14.8,-12.3,2.7,'lightwood')
    tree('Reading_Garden_Tree',-15.2,-15.0,.85)
    flowerbox('Welcome_Flowers_Left',-7.0,-12.4,3.2)
    flowerbox('Welcome_Flowers_Right',5.3,-11.2,2.7)
    flowerbox('Teaching_Flowers_Left',-9.1,7.0,2.5)
    flowerbox('Teaching_Flowers_Right',9.1,7.2,2.1)
    # Sports entry is an open court-side gateway, not a seventh fake building.
    for xx in (9.4,11.6):
        m.box('Sports_Entry_Post',(xx,-17.05,1.35),(.15,.15,2.7),'teal',.035)
    m.box('Sports_Entry_Sign',(10.5,-17.05,2.60),(2.45,.14,.48),'teal',.07)
    text('Sports_Entry_Title','PLAYGROUND',(10.5,-17.14,2.62),.21,'ivory')
    for xx in (9.4,11.6):proxy('Sports_Gate_Post_'+str(xx),(xx,-17.05,1.35),(.2,.2,2.7))
    # A couple of colourful hopscotch tiles add life without closing any route.
    for i in range(5):
        m.box('Hopscotch_Tile',(-6.5+i*.8,-9.1,.014),(.62,.62,.022),['pink','yellow','mint','blue','lavender'][i],.035)
        text('Hopscotch_Number',str(i+1),(-6.5+i*.8,-9.1,.028),.32,'ivory','up')


def anchors():
    plan=json.loads((ROOT/'game/data/landmark_interiors.json').read_text(encoding='utf-8'))
    rows=plan.get('landmarks',plan.get('rooms',[]))
    if isinstance(rows,dict):
        school=rows.get('school') or rows.get('SCHOOL')
    else:
        school=next((r for r in rows if r.get('room_id')=='school' or r.get('id')=='SCHOOL'),None)
    if school is None:
        school=next((r for r in plan.get('interiors',[]) if r.get('room_id')=='school' or r.get('id')=='SCHOOL'),None)
    if school is None:
        raise ValueError('Cannot resolve current school curriculum labels')
    planned=school['anchors']
    associated=['ASSET_School_Noticeboard_Face','Teaching_Rollcall_Board_Face','Campus_Garden_Reading_Tree_Trunk','ASSET_School_Ball_Rack','Canteen_Menu_Board_Face']
    for i,(xy,row,prop) in enumerate(zip(MEMORIES,planned,associated),1):
        ob=m.anchor(f'SG_MEMORY_{i:02}',xy,row['label'],prop)
        ob['memory_id']=row.get('id',row.get('memory_id',f'memory_SCHOOL_{i:02}'))
        ob['activity']=row.get('activity','')
    m.anchor('SG_SPAWN',(0,-16.8),'从主岛进入校园')
    m.anchor('SG_EXIT',(0,-19.0),'返回字母岛')
    m.anchor('SG_NPC_HOST',(4.6,-14.3),'和校园老师聊一聊')
    labels={'CLASSROOM':'普通教室','MUSIC_ROOM':'音乐教室','ART_ROOM':'美术教室','SCIENCE_ROOM':'科学教室','CANTEEN':'校园餐厅','PLAYGROUND':'青草操场'}
    for key,xy in DOORS.items():
        ob=m.anchor('SG_DOOR_'+key,xy,labels[key])
        ob['destination']=key.lower()
    return school


def preview_setup():
    pipeline.preview_setup(1600)
    sc=bpy.context.scene
    sc.render.resolution_y=1280
    camera=sc.camera
    camera.location=(45,-59,56)
    camera.data.ortho_scale=68.5
    pipeline.point_camera(camera,(0,1,1.2))
    sc.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.52,.70,.76,1)
    sc.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.65
    for ob in sc.objects:
        if ob.type=='LIGHT' and ob.data.type=='SUN':
            ob.data.energy=1.8
            ob.data.angle=math.radians(22)
    backdrop=bpy.data.objects.get('PREVIEW_Backdrop')
    backdrop.data.materials.clear()
    backdrop.data.materials.append(m.M['background'])
    sc.view_settings.view_transform='AgX'
    sc.view_settings.look='AgX - Medium High Contrast'
    sc.view_settings.exposure=.35
    sc['campus_size_metres']='48 x 40'
    sc['campus_version']=2
    sc['source_asset_reused']=str(SOURCE.relative_to(ROOT))
    sc['campus_editing_contract']='Edit school_v02.blend; use export_existing to keep the authored campus. Original v01 files remain untouched.'


def validate_walkability(source):
    # Broad-phase clearance at character radius .36m; Godot runs the final real-controller checks.
    radius=.36;step=.25
    obstacles=[]
    for record in source['colliders']:
        a=record['aabb_blender']
        if a[5]<.12:continue
        obstacles.append((a[0]-radius,a[1]-radius,a[3]+radius,a[4]+radius))
    def blocked(point):
        x,y=point[:2]
        return any(a<=x<=c and b<=y<=d for a,b,c,d in obstacles)
    def cell(point):return (round(point[0]/step),round(point[1]/step))
    def point(key):return (key[0]*step,key[1]*step)
    xmin,xmax,ymin,ymax=-23.25,23.25,-19.25,19.25
    start=cell((0,-16.8));visited={start};queue=collections.deque([start])
    dirs=[(-1,0),(1,0),(0,-1),(0,1)]
    while queue:
        current=queue.popleft()
        for dx,dy in dirs:
            nxt=(current[0]+dx,current[1]+dy)
            if nxt in visited:continue
            p=point(nxt)
            if not(xmin<=p[0]<=xmax and ymin<=p[1]<=ymax) or blocked(p):continue
            visited.add(nxt);queue.append(nxt)
    rows=[]
    floor=bpy.data.objects['SG_FLOOR_Main']
    graph=bpy.context.evaluated_depsgraph_get()
    tree=BVHTree.FromObject(floor,graph)
    inverse=floor.matrix_world.inverted()
    for record in source['anchors']:
        p=record['position_blender'];location=Vector(p)
        hit,normal,_,_=tree.ray_cast(inverse@(location+Vector((0,0,10))),Vector((0,0,-1)),20)
        floor_ok=hit is not None and normal.z>.95
        rows.append({'name':record['name'],'reachable':cell(p) in visited,'clear_at_anchor':not blocked(p),'floor_up_hit':floor_ok})
    minimum=min((Vector((*MEMORIES[i],0))-Vector((*p,0))).length for i in range(5) for p in DOORS.values())
    if any(not r['reachable'] or not r['clear_at_anchor'] or not r['floor_up_hit'] for r in rows):
        raise ValueError('Campus geometry validation failed: '+json.dumps(rows))
    if minimum<3.5:raise ValueError('A door and a memory anchor are too close')
    return {'result':'PASS','character_radius':radius,'grid_step':step,'reachable_cells':len(visited),'anchors':rows,'minimum_memory_to_door_distance':minimum,'scope':'2D collision clearance and upward floor ray checks; actual Godot walking is separate'}


def save_outputs(school,render=True):
    source=pipeline.collect_source('school')
    expected=['SG_SPAWN','SG_EXIT','SG_NPC_HOST']+[f'SG_MEMORY_{i:02}' for i in range(1,6)]+['SG_DOOR_'+k for k in DOORS]
    if set(expected)-set(source['required_nodes']):
        # Older helper modules may not know the new campus doors; preserve the exact same schema.
        source['required_nodes']=expected
        for name in expected:
            if not any(a['name']==name for a in source['anchors']):
                ob=bpy.data.objects[name];p=ob.matrix_world.translation
                source['anchors'].append({'name':name,'label':ob.get('label',''),'position_blender':list(p),'position_godot':[p.x,p.z,-p.y],'associated_prop':ob.get('associated_prop'),'memory_id':ob.get('memory_id',''),'activity':ob.get('activity','')})
    walk=validate_walkability(source)
    blend=OUT/'school_v02.blend';glb=OUT/'school_v02.glb';preview=OUT/'preview_v02.png'
    bpy.context.scene['room_display_name']=school.get('name','山丘学园')
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    if render:pipeline.render_preview(preview)
    pending=OUT/'.school_v02.pending.glb'
    pipeline.export_glb(pending)
    stats=pipeline.confirm_export(pending,source)
    os.replace(pending,glb)
    preserved={str(path.relative_to(ROOT)):sha(path)==digest for path,digest in SOURCE_HASHES.items()}
    if not all(preserved.values()):raise RuntimeError('An original school source was modified')
    validation={**source,**stats,'rendered':preview.exists(),'source_blend':str(blend.relative_to(ROOT)).replace('\\','/'),'source_blend_preserved':False,'original_sources_preserved':preserved,'reused_original_objects':len(REUSED),'source_reuse_names':REUSED,'walkability':walk,'campus_layout':{'size':[48,40],'north':'Original clock-tower teaching building','west':['Music building','Art building'],'east':['Science building','Canteen'],'southeast':'Original basketball court, hoop and equipment','center':'Garden with wide loop path'},'six_destinations':list(DOORS)}
    pipeline.write_json(OUT/'validation_v02.json',validation)
    entry={'room_id':'school','name':school.get('name','山丘学园'),'blend':blend.relative_to(ROOT).as_posix(),'glb':glb.relative_to(ROOT).as_posix(),'preview':preview.relative_to(ROOT).as_posix(),'anchors':source['anchors'],'bounds':[round(x,4) for x in source['bounds']],'triangles':stats['triangles_instanced'],'glb_sha256':stats['sha256']}
    pipeline.write_json(OUT/'school_v02.manifest-entry.json',entry)
    print('CAMPUS_V02_COMPLETED',json.dumps({'bytes':stats['glb_bytes'],'triangles':stats['triangles_instanced'],'anchors':len(source['anchors']),'reused_objects':len(REUSED),'walkability':walk['result'],'original_sources_preserved':all(preserved.values())}),flush=True)


def main():
    global FONT,SOURCE_HASHES
    parser=argparse.ArgumentParser()
    parser.add_argument('--inspect',action='store_true')
    parser.add_argument('--no-render',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    if args.inspect:
        inspect_source();return
    protected=[SOURCE,ROOT/'assets/blender/school/school_campus_v01.glb']+[OUT/name for name in ('school_v01.blend','school_v01.glb','preview.png','validation.json')]
    SOURCE_HASHES={path:sha(path) for path in protected}
    m.setup('school')
    bpy.context.scene.name='school_v02_campus'
    for key,rgb in {'path':(.79,.72,.55),'grass':(.36,.54,.20),'background':(.58,.76,.81),'music_wall':(.69,.80,.75),'art_wall':(.86,.65,.55),'science_wall':(.70,.82,.81),'canteen_wall':(.89,.76,.49)}.items():
        material=bpy.data.materials.new('CAMPUS_'+key);material.use_nodes=True
        bsdf=material.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=(*rgb,1);bsdf.inputs['Roughness'].default_value=.75
        material.diffuse_color=(*rgb,1);m.M[key]=material
    font_path=Path('C:/Windows/Fonts/msyh.ttc')
    if font_path.exists():FONT=bpy.data.fonts.load(str(font_path))
    campus_base()
    import_original()
    academic_building('Music','音乐楼','MUSIC',-16,9.0,7.6,6.8,'music_wall','lavender','music')
    academic_building('Art','美术楼','ART',-16,-3.5,7.6,6.8,'art_wall','rose','art')
    academic_building('Science','科学楼','SCIENCE',16,10.5,8.0,7.0,'science_wall','blue','science')
    academic_building('Canteen','校园餐厅','CANTEEN',16,-2.1,8.0,7.0,'canteen_wall','orange','canteen')
    gardens_and_learning()
    school=anchors()
    preview_setup()
    save_outputs(school,not args.no_render)


if __name__ == '__main__':
    main()
