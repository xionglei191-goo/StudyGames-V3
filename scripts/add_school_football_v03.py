"""Extend the accepted editable school v02 with an east-side football wing.

Only loads school_v02.blend and writes separate v03 school assets. Existing
architecture and anchors are retained verbatim; no old generator is executed.
Run with Blender --background --python-exit-code 1 --python this_file.
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
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/blender/interiors/school'
SOURCE = OUT / 'school_v02.blend'
sys.path.insert(0, str(ROOT / 'assets/blender/interiors/scripts'))
import modeling as m
import pipeline

DOOR = (28.0, -17.0)
FONT = None


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def obj_record(ob):
    data = {'type': ob.type, 'matrix': [round(v, 8) for row in ob.matrix_world for v in row],
            'parent': ob.parent.name if ob.parent else None,
            'properties': {k: str(ob[k]) for k in ob.keys()},
            'materials': [slot.material.name if slot.material else None for slot in ob.material_slots]}
    if ob.type == 'MESH':
        data['geometry'] = hashlib.sha256(repr((
            [tuple(round(v, 8) for v in vertex.co) for vertex in ob.data.vertices],
            [tuple(p.vertices) for p in ob.data.polygons])).encode()).hexdigest()
    elif ob.type == 'FONT':
        data['text'] = ob.data.body
        data['font'] = ob.data.font.name
    return data


def bind_existing_helpers():
    """Bind the modeling vocabulary to loaded data, without setup/reset calls."""
    global FONT
    m.M = {key: bpy.data.materials['MAT_' + key] for key in m.PALETTE if 'MAT_' + key in bpy.data.materials}
    m.M['proxy'] = bpy.data.materials['MAT_COLLISION_TRANSPARENT']
    for key in ('grass', 'path', 'background'):
        m.M[key] = bpy.data.materials['CAMPUS_' + key]
    m.COLLS = {c.name: c for c in bpy.context.scene.collection.children}
    m.CURRENT = '30_Football_Expansion'
    m.PARENT = None
    m.COLLIDERS, m.ANCHORS, m.SPHERES = [], [], {}
    for ob in bpy.data.objects:
        if ob.type == 'FONT' and ob.name == 'Science_Name_CN':
            FONT = ob.data.font
    for key, color in {'pitch_a': (.25, .47, .23), 'pitch_b': (.31, .54, .26),
                       'field_line': (.97, .97, .91), 'field_border': (.36, .59, .46)}.items():
        mat = bpy.data.materials.new('FOOTBALL_' + key)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get('Principled BSDF')
        bsdf.inputs['Base Color'].default_value = (*color, 1)
        bsdf.inputs['Roughness'].default_value = .82
        mat.diffuse_color = (*color, 1)
        m.M[key] = mat


def text(name, body, pos, size=.30, mat='ivory'):
    ob = m.text(name, body, pos, size, mat)
    ob.data.resolution_u = 3
    ob.data.bevel_depth = 0
    ob.data.bevel_resolution = 0
    ob.data.extrude = .002
    if FONT:
        ob.data.font = FONT
    return ob


def plane(name, xmin, ymin, xmax, ymax, z, mat):
    return m.mesh(name, [(xmin,ymin,z),(xmax,ymin,z),(xmax,ymax,z),(xmin,ymax,z)], [(0,1,2,3)], mat)


def path(name, points, width, mat='path', z=.008):
    verts, faces = [], []
    for i, p in enumerate(points):
        direction = (Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])).normalized()
        normal = Vector((-direction.y, direction.x))*width/2
        for v in (Vector(p)+normal, Vector(p)-normal):
            verts.append((v.x,v.y,z))
        if i:
            a=2*i-2
            faces.append((a+1,a+3,a+2,a))
    return m.mesh(name, verts, faces, mat)


def ring(name, center, radius, thickness=.10, z=.030, segments=64):
    vs=[]
    for i in range(segments):
        a=i*math.tau/segments
        for r in (radius-thickness/2,radius+thickness/2):
            vs.append((center[0]+r*math.cos(a),center[1]+r*math.sin(a),z))
    fs=[]
    for i in range(segments):
        a=2*i;b=2*((i+1)%segments)
        fs.append((a,a+1,b+1,b))
    return m.mesh(name,vs,fs,'field_line')


def rod(name, a, b, radius=.018, mat='field_line', sides=6):
    """Small un-bevelled prism for readable low-cost goal net ropes."""
    a,b=Vector(a),Vector(b)
    axis=(b-a).normalized()
    tangent=axis.cross(Vector((0,0,1)))
    if tangent.length<.01:tangent=axis.cross(Vector((1,0,0)))
    tangent.normalize();bitangent=axis.cross(tangent)
    vs=[tuple(p+radius*(math.cos(i*math.tau/sides)*tangent+math.sin(i*math.tau/sides)*bitangent))
        for p in (a,b) for i in range(sides)]
    fs=[tuple(reversed(range(sides))),tuple(range(sides,2*sides))]
    fs += [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    return m.mesh(name,vs,fs,mat)


def resize_x(ob, width, x):
    old=ob.dimensions.x
    for vertex in ob.data.vertices:vertex.co.x *= width/old
    ob.location.x=x
    ob.data.update()


def expand_ground_and_boundaries():
    changed=[]
    for name,width in [('SG_FLOOR_Main',76.0),('Campus_Foundation_Rim',76.15),('Campus_Foundation_Lower',75.8)]:
        ob=bpy.data.objects[name];resize_x(ob,width,14.0);changed.append(name)
    # Move only the former east perimeter to the new outer edge.
    for ob in list(bpy.context.scene.objects):
        if ob.name.startswith('Side_Low_Planted_Wall') and ob.location.x>0:
            ob.location.x=51.55;changed.append(ob.name)
        elif ob.name=='SG_COLLIDER_Boundary_1':
            ob.location.x=51.55;changed.append(ob.name)
    m.group('31_Football_Wing_Boundary')
    m.box('Football_Rear_Wall_Extension',(37.55,19.55,.40),(28.10,.40,.80),'cream',.07)
    m.collider('Football_Rear_Boundary',(37.55,19.60,1.0),(28.10,.42,2.0))
    m.box('Football_Front_Wall_Extension',(37.50,-19.55,.22),(28.0,.38,.44),'cream',.06)
    m.collider('Football_Front_Boundary',(37.50,-19.65,1.0),(28.0,.40,2.0))
    for i in range(15):
        x=23.5+2*i
        m.box('Football_Front_Fence_Post',(x,-19.55,.56),(.15,.15,.78),'lightwood',.025)
    for z in (.52,.78):rod('Football_Front_Fence_Rail',(23.5,-19.55,z),(51.5,-19.55,z),.045,'lightwood',8)
    m.group('32_Football_Walkways')
    path('Football_South_Connection',[(19.5,-17.7),(48.8,-17.7)],3.0)
    path('Football_Cross_Connection',[(19.4,-9.1),(25.4,-9.1),(26.0,-7.5)],3.4)
    path('Football_West_Promenade',[(25.7,-17.7),(25.7,16.7)],2.8)
    path('Football_North_Promenade',[(25.7,16.7),(49.7,16.7)],2.4)
    path('Football_East_Promenade',[(49.7,-17.7),(49.7,16.7)],2.2)
    path('Football_Entry_Approach',[(28,-17.7),(28,-14.5),(30,-12.5)],2.8)
    return changed


def goal(name, side):
    y=14*side;back=y+side*1.15
    for x in (35.5,40.5):
        rod(name+'_Front_Post',(x,y,.05),(x,y,2.25),.075,sides=12)
        rod(name+'_Side_Foot',(x,y,.05),(x,back,.05),.05,sides=8)
        rod(name+'_Support',(x,y,2.25),(x,back,1.8),.05,sides=8)
        rod(name+'_Back_Post',(x,back,.05),(x,back,1.8),.045,sides=8)
        m.collider(name+'_Post_'+str(x),(x,y,1.15),(.17,.17,2.3))
        m.collider(name+'_Side_Net_'+str(x),(x,(y+back)/2,.9),(.055,1.15,1.8))
    rod(name+'_Crossbar',(35.5,y,2.25),(40.5,y,2.25),.075,sides=12)
    rod(name+'_Rear_Top',(35.5,back,1.8),(40.5,back,1.8),.045,sides=8)
    m.collider(name+'_Back_Net',(38,back,.9),(5.0,.06,1.8))
    m.collider(name+'_Crossbar',(38,y,2.25),(5.15,.17,.17))
    for i in range(17):
        x=35.5+5*i/16
        rod(name+'_Back_Net_V',(x,back,.07),(x,back,1.8),.012)
        rod(name+'_Roof_Net',(x,y,2.25),(x,back,1.8),.012)
    for i in range(7):
        z=.07+1.73*i/6
        rod(name+'_Back_Net_H',(35.5,back,z),(40.5,back,z),.012)
        for x in (35.5,40.5):rod(name+'_Side_Net_H',(x,y,z),(x,back,z),.012)
    for i in range(1,4):
        yy=y+(back-y)*i/4;top=2.25-.45*i/4
        for x in (35.5,40.5):rod(name+'_Side_Net_V',(x,yy,.07),(x,yy,top),.012)


def football_pitch():
    m.group('33_Football_Pitch')
    plane('Football_Field_Border',27.25,-14.75,48.75,14.75,.012,'field_border')
    for i in range(10):
        plane('Football_Mowing_Stripe_%02d'%i,28,-14+i*2.8,48,-14+(i+1)*2.8,.020,'pitch_a' if i%2 else 'pitch_b')
    for name,coords in {
        'Sideline_West':(27.94,-14.06,28.06,14.06),'Sideline_East':(47.94,-14.06,48.06,14.06),
        'Endline_South':(27.94,-14.06,48.06,-13.94),'Endline_North':(27.94,13.94,48.06,14.06),
        'Halfway_Line':(28,-.06,48,.06)}.items():plane('Football_'+name,*coords,.031,'field_line')
    ring('Football_Center_Circle',(38,0),3.0,.12)
    m.cyl('Football_Center_Spot',(38,0,.034),.16,.008,'field_line',20)
    for side in (-1,1):
        end=side*14;inner=side*9.5;six=side*12.3
        lo,hi=sorted((end,inner))
        for x in (32.1,43.9):plane('Football_Penalty_Box_Side',x-.06,lo,x+.06,hi,.032,'field_line')
        plane('Football_Penalty_Box_Front',32.1,inner-.06,43.9,inner+.06,.032,'field_line')
        lo,hi=sorted((end,six))
        for x in (34.0,42.0):plane('Football_Goal_Area_Side',x-.06,lo,x+.06,hi,.032,'field_line')
        plane('Football_Goal_Area_Front',34.0,six-.06,42.0,six+.06,.032,'field_line')
        m.cyl('Football_Penalty_Spot',(38,side*10.7,.034),.12,.008,'field_line',16)
        goal('Football_Goal_'+('North' if side>0 else 'South'),side)
    for x in (27.7,48.3):
        for y in (-14.3,14.3):
            rod('Football_Corner_Flag_Pole',(x,y,.02),(x,y,1.32),.025,'lightwood',8)
            m.mesh('Football_Corner_Flag',[(x,y,1.32),(x+.48,y,1.15),(x,y,.98)],[(0,1,2)],'yellow')
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=.32,location=(38,0,.35))
    ball=bpy.context.object;ball.name='Football_Center_Ball';m.link(ball)
    ball.data.materials.append(m.M['field_line']);ball.data.materials.append(m.M['navy'])
    for i,face in enumerate(ball.data.polygons):face.material_index=1 if i%7 in (0,1) else 0
    ball['prop_role']='Football at center spot; decorative in campus overview'


def wing_details():
    m.group('34_Football_Equipment')
    # Entry belongs to the pitch's southwest corner, away from both goal mouths.
    for x in (26.6,29.4):
        m.box('Football_Entry_Post',(x,-15.8,1.35),(.17,.17,2.7),'teal',.035)
        m.collider('Football_Entry_Post_'+str(x),(x,-15.8,1.35),(.21,.21,2.7))
    m.box('Football_Entry_Sign',(28,-15.8,2.64),(3.3,.20,.62),'teal',.065)
    text('Football_Entry_Title','足球场',(28,-15.92,2.78),.28)
    text('Football_Entry_Subtitle','FOOTBALL',(28,-15.925,2.48),.17)
    # Two slim benches face the field from the east-side path.
    for y in (-6,5):
        m.box('Football_Spectator_Seat',(50.45,y,.56),(.65,2.8,.14),'lightwood',.045)
        m.box('Football_Spectator_Back',(50.72,y,.96),(.14,2.8,.70),'lightwood',.045)
        for yy in (y-1.05,y+1.05):m.box('Football_Bench_Leg',(50.45,yy,.27),(.48,.14,.54),'teal',.025)
        m.collider('Football_Spectator_Bench_'+str(y),(50.50,y,.70),(.85,2.85,1.4))
    for x in (44.8,47.2):m.box('Football_Scoreboard_Post',(x,17.5,1.25),(.14,.16,2.5),'lightwood',.025)
    m.box('Football_Scoreboard_Frame',(46,17.5,2.70),(3.55,.22,1.55),'lightwood',.065)
    m.box('Football_Scoreboard_Face',(46,17.365,2.70),(3.31,.035,1.31),'teal',.025)
    text('Football_Scoreboard_Title','FRIENDLY MATCH',(46,17.33,3.08),.18)
    text('Football_Scoreboard_Numbers','0 : 0',(46,17.33,2.59),.56)
    m.collider('Football_Scoreboard',(46,17.5,1.8),(3.60,.40,3.6))
    for x in (31.2,34.0):
        m.cyl('Football_Training_Cone',(x,-16.1,.24),.20,.46,'orange',12,top=.055)
    anchor=m.anchor('SG_DOOR_FOOTBALL_FIELD',DOOR,'校园足球场','Football_Entry_Sign')
    anchor['destination']='football_field'
    anchor['interaction_id']='football_field_gate'


def validate(source, old_records, permitted_changes):
    changed=[];missing=[]
    for name, record in old_records.items():
        ob=bpy.data.objects.get(name)
        if ob is None:missing.append(name)
        elif obj_record(ob)!=record:changed.append(name)
    unexpected=[n for n in changed if n not in permitted_changes and not n.startswith('PREVIEW_')]
    if missing or unexpected:raise RuntimeError('Source preservation failed '+repr((missing,unexpected)))
    radius=.36;step=.25
    obstacles=[(a[0]-radius,a[1]-radius,a[3]+radius,a[4]+radius)
               for row in source['colliders'] for a in [row['aabb_blender']] if a[5]>.12 and a[2]<1.65]
    def blocked(p):return any(x0<=p[0]<=x1 and y0<=p[1]<=y1 for x0,y0,x1,y1 in obstacles)
    def cell(p):return round(p[0]/step),round(p[1]/step)
    start=cell(bpy.data.objects['SG_SPAWN'].matrix_world.translation)
    seen={start};queue=collections.deque([start])
    while queue:
        x,y=queue.popleft()
        for dx,dy in ((-1,0),(1,0),(0,-1),(0,1)):
            nxt=(x+dx,y+dy);p=(nxt[0]*step,nxt[1]*step)
            if nxt in seen or not(-23.25<=p[0]<=51.25 and -19.25<=p[1]<=19.25) or blocked(p):continue
            seen.add(nxt);queue.append(nxt)
    floor=bpy.data.objects['SG_FLOOR_Main'];inverse=floor.matrix_world.inverted()
    tree=BVHTree.FromObject(floor,bpy.context.evaluated_depsgraph_get())
    points=[(a['name'],a['position_blender']) for a in source['anchors']]
    points += [('FIELD_CENTER',(38,0,0)),('FIELD_SOUTH_SHOT',(38,-11.5,0)),('FIELD_NORTH_SHOT',(38,11.5,0)),
               ('FIELD_SW',(29.0,-13,0)),('FIELD_SE',(47,-13,0)),('FIELD_NW',(29,13,0)),('FIELD_NE',(47,13,0)),
               ('SOUTH_CONNECTOR',(23.5,-17.7,0)),('CROSS_CONNECTOR',(23.5,-9.1,0))]
    results=[]
    for name,p in points:
        hit,normal,_,_=tree.ray_cast(inverse@(Vector(p)+Vector((0,0,10))),Vector((0,0,-1)),20)
        results.append({'name':name,'position_blender':list(p),'reachable':cell(p) in seen,
                        'clear_at_point':not blocked(p),'floor_up_hit':hit is not None and normal.z>.95})
    failures=[r for r in results if not all(r[k] for k in ('reachable','clear_at_point','floor_up_hit'))]
    if failures:raise RuntimeError('Walkability check failed '+json.dumps(failures))
    for a in source['anchors']:
        if a['name']!='SG_DOOR_FOOTBALL_FIELD' and a['name'] not in old_records:raise RuntimeError('Unexpected old anchor')
    distances=[(Vector(a['position_blender'])-Vector((*DOOR,0))).length for a in source['anchors'] if a['name'].startswith('SG_MEMORY_')]
    if min(distances)<3.5:raise RuntimeError('Football door conflicts with memory radius')
    return {'result':'PASS','character_radius':radius,'grid_step':step,'reachable_cells':len(seen),'points':results,
            'scope':'2D proxy clearance and upward floor rays; final Godot controller and visual checks remain separate',
            'minimum_new_door_to_memory_distance':min(distances),
            'preservation':{'source_object_count':len(old_records),'missing_objects':missing,'unexpected_changes':unexpected,
                            'allowed_modified_objects':changed,'unchanged_objects':len(old_records)-len(changed),
                            'existing_anchors_unchanged':True,'existing_buildings_unchanged':True}}


def sync_memory_activity():
    plan=json.loads((ROOT/'game/data/landmark_interiors.json').read_text(encoding='utf-8'))
    school=next(r for r in plan['landmarks'] if r.get('room_id')=='school')
    changes=[]
    for row in school['anchors']:
        ob=bpy.data.objects[row['node_name']]
        old=ob.get('activity','');new=row.get('activity','')
        if old!=new:
            ob['activity']=new
            changes.append({'node':ob.name,'property':'activity','before':old,'after':new})
    return changes


def refresh_metadata_only():
    """Edit the saved v03 in place; never reconstruct the authored scene."""
    blend=OUT/'school_v03.blend';glb=OUT/'school_v03.glb'
    audit=json.loads((OUT/'source-edit-audit_v03.json').read_text(encoding='utf-8'))
    protected={ROOT/p:sha(ROOT/p) for p in audit['original_sources_preserved']}
    previous_hash=sha(blend)
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    bpy.context.preferences.filepaths.save_version=0
    bpy.context.view_layer.update()
    before={ob.name:obj_record(ob) for ob in bpy.context.scene.objects}
    changes=sync_memory_activity()
    for ob in bpy.context.scene.objects:
        after=obj_record(ob);old=before[ob.name]
        if {k:v for k,v in after.items() if k!='properties'}!={k:v for k,v in old.items() if k!='properties'}:
            raise RuntimeError('Metadata refresh changed geometry or transforms: '+ob.name)
    pipeline.SCHOOL=list(dict.fromkeys(pipeline.SCHOOL+['SG_DOOR_FOOTBALL_FIELD']))
    source=pipeline.collect_source('school')
    bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    pending=OUT/'.school_v03.pending.glb';pipeline.export_glb(pending)
    stats=pipeline.confirm_export(pending,source);os.replace(pending,glb)
    if any(sha(path)!=digest for path,digest in protected.items()):raise RuntimeError('Protected source changed')
    audit.update(source);audit.update(stats)
    audit['blend_sha256']=sha(blend)
    audit['metadata_refresh']={'previous_v03_blend_sha256':previous_hash,'changes':changes,
                               'geometry_and_transforms_unchanged':True,'preview_still_valid':True}
    pipeline.write_json(OUT/'validation_v03.json',audit)
    pipeline.write_json(OUT/'source-edit-audit_v03.json',audit)
    entry=json.loads((OUT/'school_v03.manifest-entry.json').read_text(encoding='utf-8'))
    entry.update({'anchors':source['anchors'],'bounds':source['bounds'],
                  'triangles':stats['triangles_instanced'],'glb_sha256':stats['sha256']})
    pipeline.write_json(OUT/'school_v03.manifest-entry.json',entry)
    print('CAMPUS_V03_METADATA_UPDATED',json.dumps({'changes':changes,'blend_sha256':audit['blend_sha256'],
          'glb_sha256':stats['sha256'],'glb_bytes':stats['glb_bytes'],'triangles':stats['triangles_instanced']},ensure_ascii=False),flush=True)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--no-render',action='store_true')
    parser.add_argument('--refresh-metadata',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    if args.refresh_metadata:
        refresh_metadata_only();return
    protected=[p for p in OUT.iterdir() if p.is_file() and ('v02' in p.name or 'v01' in p.name or p.name in ('preview.png','validation.json'))]
    protected += [ROOT/'assets/blender/school/school_campus_v01.blend',ROOT/'assets/blender/school/school_campus_v01.glb']
    baseline={p:sha(p) for p in protected}
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    bpy.context.preferences.filepaths.save_version=0
    bpy.context.view_layer.update()
    old_records={ob.name:obj_record(ob) for ob in bpy.context.scene.objects}
    bind_existing_helpers()
    permitted=expand_ground_and_boundaries()
    football_pitch();wing_details()
    sc=bpy.context.scene;sc.name='school_v03_campus_football'
    sc['campus_size_metres']='76 x 40';sc['campus_version']=3
    sc['source_campus_v02_sha256']=baseline[SOURCE]
    sc['campus_editing_contract']='Edit school_v03.blend and export_existing; original v01/v02 remain untouched.'
    sc['football_extension']='East-side 28m expansion; 20x28m school-scale pitch; original buildings and anchors preserved.'
    camera=sc.camera;camera.location=(66,-65,68);camera.data.ortho_scale=89.0
    pipeline.point_camera(camera,(13,1,1.2))
    sc.render.resolution_x=1920;sc.render.resolution_y=1280
    pipeline.SCHOOL=list(dict.fromkeys(pipeline.SCHOOL+['SG_DOOR_FOOTBALL_FIELD']))
    source=pipeline.collect_source('school')
    if source['missing_external_textures']:raise RuntimeError(source['missing_external_textures'])
    validation=validate(source,old_records,permitted)
    metadata_changes=sync_memory_activity()
    source=pipeline.collect_source('school')
    blend=OUT/'school_v03.blend';glb=OUT/'school_v03.glb';preview=OUT/'preview_v03.png'
    bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    if not args.no_render:pipeline.render_preview(preview)
    pending=OUT/'.school_v03.pending.glb';pipeline.export_glb(pending)
    stats=pipeline.confirm_export(pending,source);os.replace(pending,glb)
    preserved={p.relative_to(ROOT).as_posix():sha(p)==digest for p,digest in baseline.items()}
    if not all(preserved.values()):raise RuntimeError('Protected original asset hash changed')
    report={**source,**stats,'result':'PASS','source_blend':blend.relative_to(ROOT).as_posix(),
            'blend_sha256':sha(blend),'loaded_source':SOURCE.relative_to(ROOT).as_posix(),
            'loaded_source_sha256':baseline[SOURCE],'source_blend_preserved':False,
            'rendered':preview.exists(),'original_sources_preserved':preserved,'walkability':validation,
            'metadata_refresh':{'changes':metadata_changes,'geometry_and_transforms_unchanged':True},
            'campus_layout':{'size':[76,40],'expansion':'East','pitch_dimensions_metres':[20,28],
                             'football_door_blender':[*DOOR,0],'football_door_godot':[DOOR[0],0,-DOOR[1]],
                             'existing_buildings':'unchanged','existing_anchors':'unchanged'},
            'provenance':{'tool':'Blender 5.2.2 + existing modeling/pipeline helpers','source':'school_v02.blend',
                          'edit':'Original authored mesh extension; no generated images or external downloads',
                          'visual_system':'Existing soft-edged pastel school; green striped grass, ivory field lines, teal trim',
                          'scope':'school campus source assets only; independent football_field room maintained separately'}}
    pipeline.write_json(OUT/'validation_v03.json',report)
    # Keep the source edit audit when export_existing later refreshes validation.
    pipeline.write_json(OUT/'source-edit-audit_v03.json',report)
    entry={'room_id':'school','name':sc.get('room_display_name','山丘学园'),'blend':blend.relative_to(ROOT).as_posix(),
           'glb':glb.relative_to(ROOT).as_posix(),'preview':preview.relative_to(ROOT).as_posix(),
           'anchors':source['anchors'],'bounds':[round(x,4) for x in source['bounds']],
           'triangles':stats['triangles_instanced'],'glb_sha256':stats['sha256']}
    pipeline.write_json(OUT/'school_v03.manifest-entry.json',entry)
    print('CAMPUS_V03_COMPLETED',json.dumps({'bytes':stats['glb_bytes'],'triangles':stats['triangles_instanced'],
          'anchors':len(source['anchors']),'colliders':len(source['colliders']),'bounds':source['bounds'],
          'walkability':validation['result'],'original_sources_preserved':all(preserved.values()),
          'blend_sha256':report['blend_sha256'],'glb_sha256':stats['sha256']}),flush=True)


if __name__=='__main__':main()
