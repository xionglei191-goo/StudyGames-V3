"""Bind normalized Tripo meshes to the project's versioned semantic skeleton.

Uses fitted anatomical regions and mesh-adjacency smoothing, never random weights.
Retains editable rigs, normalized four-weight skins, and the existing action timing.
Run with Blender --background --factory-startup --python this_file.py -- [ids].
"""
from __future__ import annotations
import bpy
import bmesh
import hashlib
import heapq
import json
import math
import sys
import time
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/characters/tripo_v1'
sys.path.insert(0, str(ROOT / 'scripts'))
from prepare_tripo_characters import PROFILES, setup_render
G2B = Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
B2G = G2B.inverted()
CONTRACT = json.loads((OUT / 'action-contract.json').read_text(encoding='utf-8'))
MIXAMO_MODE = '--mixamo' in sys.argv
GESTURE_PATH = ROOT / 'game/assets/characters/tripo_v1/gesture-overrides.json'
GESTURES = json.loads(GESTURE_PATH.read_text(encoding='utf-8')) if GESTURE_PATH.exists() else {}

def smooth(a, b, v):
    t = np.clip((v-a)/(b-a), 0.0, 1.0)
    return t*t*(3.0-2.0*t)

def layout(character_id, family, height):
    p = dict(hip=.40, spine=.48, neck=.665, head=.685, shoulder=.605, elbow=.455, wrist=.355,
             sx=.130, ex=.184, wx=.218, legx=.084, knee=.205, ankle=.073, front=0., headfront=.015)
    if character_id == 'textbook_miss_li':
        p.update(hip=.465, spine=.56, neck=.765, head=.785, shoulder=.705, elbow=.555, wrist=.415,
                 sx=.125, ex=.157, wx=.187, legx=.070, knee=.265, ankle=.060)
    elif character_id == 'npc_rabbit_gardener':
        p.update(hip=.285, spine=.365, neck=.515, head=.535, shoulder=.475, elbow=.355, wrist=.275,
                 sx=.119, ex=.170, wx=.203, legx=.085, knee=.165, ankle=.074)
    elif character_id == 'npc_bear_uncle':
        p.update(hip=.29, spine=.395, neck=.565, head=.59, shoulder=.52, elbow=.395, wrist=.295,
                 sx=.17, ex=.215, wx=.255, legx=.12, knee=.17, ankle=.06)
    elif family == 'dino':
        p.update(hip=.28, spine=.42, neck=.595, head=.625, shoulder=.515, elbow=.425, wrist=.365,
                 sx=.12, ex=.195, wx=.245, legx=.12, knee=.15, ankle=.055, front=.09, headfront=.13)
    elif family == 'wheelchair':
        p.update(hip=.405, spine=.47, neck=.64, head=.67, shoulder=.565, elbow=.455, wrist=.385,
                 sx=.13, ex=.145, wx=.105, legx=.085, knee=.335, ankle=.145, front=-.16, headfront=-.16)
    pts = {'Root': (0,0,0), 'Hips': (0,p['hip'],p['front']),
           'Spine': (0,p['spine'],p['front']), 'Neck': (0,p['neck'],p['headfront']),
           'Head': (0,p['head'],p['headfront'])}
    parents = {'Root':None,'Hips':'Root','Spine':'Hips','Neck':'Spine','Head':'Neck'}
    rotations = {}
    arm_lines, leg_lines = {}, {}
    for side, sign in [('L',-1),('R',1)]:
        arm = [(sign*p['sx'],p['shoulder'],p['front']),
               (sign*p['ex'],p['elbow'],p['front']+.007),
               (sign*p['wx'],p['wrist'],p['front']+.022),
               (sign*(p['wx']+.003),p['wrist']-.045,p['front']+.027)]
        leg = [(sign*p['legx'],p['hip']-.025,p['front']),
               (sign*p['legx'],p['knee'],p['front']+.008),
               (sign*p['legx'],p['ankle'],p['front']+.008),
               (sign*p['legx'],p['ankle']*.45,p['front']+.072)]
        if family == 'wheelchair':
            arm[1] = (sign*p['ex'],p['elbow'],-.065)
            arm[2] = (sign*p['wx'],p['wrist'],.15)
            arm[3] = (sign*p['wx'],p['wrist']-.04,.18)
            leg[0] = (sign*p['legx'],p['hip']-.025,-.16)
            leg[1] = (sign*p['legx'],p['knee'],.14)
            leg[2] = (sign*p['legx'],p['ankle'],.19)
            leg[3] = (sign*p['legx'],.10,.27)
        for names, line, root_parent in [
            ([f'UpperArm_{side}',f'LowerArm_{side}',f'Hand_{side}'],arm,'Spine'),
            ([f'UpperLeg_{side}',f'LowerLeg_{side}',f'Foot_{side}'],leg,'Hips')]:
            for i, name in enumerate(names):
                pts[name] = line[i]
                parents[name] = names[i-1] if i else root_parent
        arm_lines[side], leg_lines[side] = np.array(arm), np.array(leg)
        if family == 'wheelchair':
            rotations[f'UpperLeg_{side}'] = (-math.pi/2,0,0)
            rotations[f'LowerLeg_{side}'] = (math.pi/2,0,0)
    if family == 'dino':
        pts.update(Tail=(0,.28,-.035),Tail_02=(.16,.20,-.20),Tail_03=(.32,.165,-.32),
                   Wing_L=(-.105,.535,-.035),Wing_R=(.105,.535,-.035))
        parents.update(Tail='Hips',Tail_02='Tail',Tail_03='Tail_02',Wing_L='Spine',Wing_R='Spine')
    elif character_id == 'npc_rabbit_gardener':
        pts.update(Ear_L=(-.075,.79,0),Ear_R=(.075,.79,0),RabbitTail=(0,.325,-.125))
        parents.update(Ear_L='Head',Ear_R='Head',RabbitTail='Hips')
    if family == 'wheelchair':
        pts.update(ChairRoot=(0,0,0),Wheel_L=(-.225,.215,-.115),Wheel_R=(.225,.215,-.115),
                   Castor_L=(-.185,.05,.24),Castor_R=(.185,.05,.24))
        parents.update(ChairRoot='Root',Wheel_L='ChairRoot',Wheel_R='ChairRoot',Castor_L='ChairRoot',Castor_R='ChairRoot')
    rest, bones = {}, []
    for name, xyz in pts.items():
        parent = parents[name]
        rotation = rotations.get(name,(0,0,0))
        basis = Matrix.Rotation(rotation[0],4,'X')
        if parent:
            origin = rest[parent].inverted() @ (Vector(xyz)*height)
            rest[name] = rest[parent] @ Matrix.Translation(origin) @ basis
        else:
            origin = Vector(xyz)*height
            rest[name] = Matrix.Translation(origin) @ basis
        bones.append(dict(name=name,parent=parent,origin=list(origin),rotation=list(rotation)))
    return p, pts, parents, rest, bones, arm_lines, leg_lines

def line_distance(points, line):
    best = np.full(len(points),np.inf)
    along = np.zeros(len(points))
    length = 0.
    borders = []
    for a,b in zip(line[:-1],line[1:]):
        segment = b-a
        segment_length = np.linalg.norm(segment)
        t = np.clip((points-a) @ segment / max(segment_length**2,1e-12),0,1)
        distance = np.linalg.norm(points-(a+t[:,None]*segment),axis=1)
        mask = distance < best
        along[mask] = length+t[mask]*segment_length
        best[mask] = distance[mask]
        length += segment_length
        borders.append(length)
    return best, along, borders

def chain_weights(points, line, joint_width=.035):
    distance, along, borders = line_distance(points,line)
    w1 = smooth(borders[0]-joint_width,borders[0]+joint_width,along)
    w2 = smooth(borders[1]-joint_width*.6,borders[1]+joint_width*.6,along)
    return distance, np.stack((1-w1,w1*(1-w2),w2),axis=1)

def mesh_arrays(obj):
    coordinates = np.empty(len(obj.data.vertices)*3,np.float32)
    obj.data.vertices.foreach_get('co',coordinates)
    b = coordinates.reshape(-1,3)
    return np.stack((b[:,0],b[:,2],-b[:,1]),axis=1)

def import_mixamo_candidate(character_id, original, height, pts, parents):
    source=ROOT/'assets/characters/mixamo_v1/downloads'/character_id/'t_pose.fbx'
    assert source.is_file(),f'Missing downloaded Mixamo source: {source}'
    material=original.data.materials[0]
    material.use_fake_user=True
    old_objects=set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=str(source))
    added=set(bpy.context.scene.objects)-old_objects
    source_arm=next(o for o in added if o.type=='ARMATURE')
    obj=next(o for o in added if o.type=='MESH')
    source_arm.animation_data_clear()
    source_arm.data.pose_position='REST'
    bpy.context.view_layer.update()
    source_names={b.name.split(':')[-1]:b for b in source_arm.data.bones}
    mapping={'Hips':'Hips','Spine':'Spine','Spine1':'Spine','Spine2':'Spine','Neck':'Neck','Head':'Head','HeadTop_End':'Head'}
    joint_sources={'Hips':'Hips','Spine':'Spine','Neck':'Neck','Head':'Head'}
    arms,legs={},{}
    for source_side,side in [('Left','R'),('Right','L')]:
        mapping[source_side+'Shoulder']='Spine'
        for suffix,target in [('Arm','UpperArm'),('ForeArm','LowerArm'),('Hand','Hand'),('UpLeg','UpperLeg'),('Leg','LowerLeg'),('Foot','Foot')]:
            mapping[source_side+suffix]=target+'_'+side
            joint_sources[target+'_'+side]=source_side+suffix
        for name in source_names:
            if name.startswith(source_side+'Hand'):mapping[name]='Hand_'+side
            if name.startswith(source_side+'Toe'):mapping[name]='Foot_'+side
    for target,source_name in joint_sources.items():
        position=B2G@(source_arm.matrix_world@source_names[source_name].head_local)
        pts[target]=tuple(position/height)
    for source_side,side in [('Left','R'),('Right','L')]:
        for collection,targets,end in [(arms,['UpperArm','LowerArm','Hand'],'Hand'),(legs,['UpperLeg','LowerLeg','Foot'],'Foot')]:
            tail=B2G@(source_arm.matrix_world@source_names[source_side+end].tail_local)/height
            collection[side]=np.array([pts[name+'_'+side] for name in targets]+[tuple(tail)])
    rest,bones={},[]
    for name,xyz in pts.items():
        position=Vector(xyz)*height
        parent=parents[name]
        rest[name]=Matrix.Translation(position)
        origin=position-rest[parent].translation if parent else position
        bones.append(dict(name=name,parent=parent,origin=list(origin),rotation=[0,0,0]))
    indices={b['name']:i for i,b in enumerate(bones)}
    weights=np.zeros((len(obj.data.vertices),len(bones)),np.float32)
    group_map={group.index:mapping.get(group.name.split(':')[-1]) for group in obj.vertex_groups}
    for vertex in obj.data.vertices:
        for group in vertex.groups:
            target=group_map.get(group.group)
            assert target or group.weight<1e-6,f'Unmapped Mixamo bone: {obj.vertex_groups[group.group].name}'
            if target:weights[vertex.index,indices[target]]+=group.weight
    assert np.all(weights.sum(axis=1)>.99),'Mixamo has uncovered vertices'
    obj.data.transform(obj.matrix_world)
    obj.parent=None
    obj.matrix_world=Matrix.Identity(4)
    obj.modifiers.clear();obj.vertex_groups.clear()
    obj.data.materials.clear();obj.data.materials.append(material)
    for other in old_objects|added:
        if other!=obj:bpy.data.objects.remove(other,do_unlink=True)
    for action in list(bpy.data.actions):bpy.data.actions.remove(action)
    obj.name='Body';obj['character_id']=character_id
    print('TRIPO_MIXAMO_SOURCE '+json.dumps({'id':character_id,'bones':len(source_names),'vertices':len(weights),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()}),flush=True)
    return obj,pts,rest,bones,arms,legs,weights,{
        'provider':'Adobe Mixamo','source_file':str(source.relative_to(ROOT)).replace('\\','/'),
        'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_bone_count':len(source_names),
        'runtime_mapping':'Spine and shoulder weights combine into Spine; finger weights into Hand; toe weights into Foot; anatomical joint positions retained',
    }

def assign_weights(obj,bones,weights):
    order=np.argsort(weights,axis=1)[:,-4:]
    kept=np.zeros_like(weights)
    np.put_along_axis(kept,order,np.take_along_axis(weights,order,axis=1),axis=1)
    kept/=np.maximum(kept.sum(axis=1),1e-12)[:,None]
    obj.vertex_groups.clear()
    for column,bone in enumerate(bones):
        group=obj.vertex_groups.new(name=bone['name'])
        for vertex in np.flatnonzero(kept[:,column]>1e-6):group.add([int(vertex)],float(kept[vertex,column]),'REPLACE')
    return kept

def refine_garment_weights(obj, character_id, bones, height):
    """Keep animal overalls on the torso with a soft sleeve/strap transition.

    Bone heat and geodesics can leak arm/leg influences through the small gap
    between the arm and the overalls. Color identifies the garment, while smooth
    spatial and mesh-adjacency blends keep its cuffs and shoulder straps supple.
    """
    if character_id not in ['npc_bear_uncle','npc_rabbit_gardener']:
        return {'changed_vertices':0}
    if obj.get('garment_weights_revision') == 3:
        return {'changed_vertices':0,'already_applied':True}
    xyz=mesh_arrays(obj)/height
    rgb,_=texture_data(obj)
    p,_,_,_,_,_,_=layout(character_id,'animal',height)
    names=[b['name'] for b in bones]; indices={name:i for i,name in enumerate(names)}
    weights=np.zeros((len(xyz),len(bones)),np.float32)
    for vertex in obj.data.vertices:
        for group in vertex.groups:weights[vertex.index,indices[obj.vertex_groups[group.group].name]]=group.weight
    before=weights.copy()
    if character_id=='npc_bear_uncle':
        garment=(rgb[:,1]>rgb[:,0]*1.06)&(rgb[:,2]>rgb[:,0]*.90)
        inner,outer=.185,.235
    else:
        garment=(rgb[:,1]>rgb[:,0]*1.04)&(rgb[:,1]>rgb[:,2]*1.10)
        inner,outer=.125,.160
    # Blur the material-region hint along connected edges, never across the
    # nearby but separate hand/torso surfaces.
    a,b=np.array([edge.vertices[:] for edge in obj.data.edges]).T
    degree=np.bincount(np.concatenate((a,b)),minlength=len(xyz))
    hint=garment.astype(np.float32)
    for _ in range(5):
        summed=np.zeros(len(xyz),np.float32)
        np.add.at(summed,a,hint[b]);np.add.at(summed,b,hint[a])
        hint=.45*hint+.55*summed/np.maximum(degree,1)
    amount=(1-smooth(inner,outer,np.abs(xyz[:,0])))
    amount*=smooth(p['hip']-.02,p['hip']+.025,xyz[:,1])
    amount*=1-smooth(p['shoulder']-.095,p['shoulder']-.005,xyz[:,1])
    amount*=np.clip(hint*1.35,0,1)
    spine=smooth(p['hip']+.015,p['shoulder']-.13,xyz[:,1])
    target=np.zeros_like(weights)
    target[:,indices['Hips']]=1-spine;target[:,indices['Spine']]=spine
    weights=weights*(1-amount[:,None])+target*amount[:,None]
    # Preserve smooth gradients across a painted cuff. A hard material boundary
    # must never become an equally hard skin-weight boundary.
    edge_weights=1/(np.linalg.norm(xyz[a]-xyz[b],axis=1)+.001)
    weighted_degree=np.zeros(len(xyz),np.float32)
    np.add.at(weighted_degree,a,edge_weights);np.add.at(weighted_degree,b,edge_weights)
    transition=(1-smooth(p['shoulder']+.01,p['shoulder']+.07,xyz[:,1]))*smooth(p['hip']+.01,p['hip']+.06,xyz[:,1])
    transition*=smooth(inner-.08,inner-.025,np.abs(xyz[:,0]))*.65
    for _ in range(36):
        summed=np.zeros_like(weights)
        np.add.at(summed,a,weights[b]*edge_weights[:,None]);np.add.at(summed,b,weights[a]*edge_weights[:,None])
        weights=weights*(1-transition[:,None])+summed/np.maximum(weighted_degree,1e-8)[:,None]*transition[:,None]
    result=assign_weights(obj,bones,weights)
    obj['garment_weights_revision']=3
    return {'changed_vertices':int(np.count_nonzero(np.max(np.abs(result-before),axis=1)>.01)),
            'method':'torso-anchored overalls with connected-surface cuff and strap blending'}

def texture_data(obj):
    textures = []
    for image in list(bpy.data.images):
        if not image.size[0]:
            continue
        before = list(image.size)
        if max(image.size)>2048:
            ratio=2048/max(image.size)
            image.scale(round(image.size[0]*ratio),round(image.size[1]*ratio))
        image.pack()
        textures.append({'name':image.name,'input_size':before,'size':list(image.size)})
    material = obj.data.materials[0]
    shader = next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    link = shader.inputs['Base Color'].links[0]
    image = link.from_node.image
    pixels = np.empty(len(image.pixels),np.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape(image.size[1],image.size[0],4)
    uv = obj.data.uv_layers.active
    vertex_rgb = np.zeros((len(obj.data.vertices),3),np.float32)
    counts = np.zeros(len(obj.data.vertices),np.float32)
    for loop in obj.data.loops:
        u,v = uv.data[loop.index].uv
        x = min(image.size[0]-1,max(0,int(u*image.size[0])))
        y = min(image.size[1]-1,max(0,int(v*image.size[1])))
        vertex_rgb[loop.vertex_index] += pixels[y,x,:3]
        counts[loop.vertex_index] += 1
    vertex_rgb /= np.maximum(counts,1)[:,None]
    return vertex_rgb, textures

def separate_jim_hand_contacts(obj, rgb, height):
    """Split the supplied hand/trouser contact seam before deforming either side.

    Tripo fused the resting fingers into the knees. No skinning algorithm can
    lift that connected surface cleanly without a topology seam.
    """
    bm=bmesh.new();bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table();bm.faces.ensure_lookup_table()
    region=bm.faces.layers.int.new('JimArmSurface')
    for face in bm.faces:
        color=np.mean([rgb[v.index] for v in face.verts],axis=0)
        center=B2G@face.calc_center_median()/height
        face[region]=int(color[0]>color[1]*1.17 and color[1]>color[2]*1.10
                         and abs(center.x)>.055 and .32<center.y<.55 and center.z>-.12)
    boundary=[]
    for edge in bm.edges:
        if len(edge.link_faces)!=2:continue
        center=B2G@((edge.verts[0].co+edge.verts[1].co)*.5)/height
        chair_contact=False
        if .43<center.y<.515 and abs(center.x)>.12:
            chair_contact=any(np.mean([rgb[v.index] for v in face.verts],axis=0).max()<.58 for face in edge.link_faces)
        if (.32<center.y<.44 or chair_contact) and edge.link_faces[0][region]!=edge.link_faces[1][region]:
            boundary.append(edge)
    bmesh.ops.split_edges(bm,edges=boundary)
    open_edges=[]
    for edge in bm.edges:
        center=B2G@((edge.verts[0].co+edge.verts[1].co)*.5)/height
        if edge.is_boundary and .30<center.y<.53 and abs(center.x)>.045:open_edges.append(edge)
    caps=bmesh.ops.holes_fill(bm,edges=open_edges,sides=0)['faces']
    cap_set=set(caps)
    uv=bm.loops.layers.uv.active
    cap_materials={}
    for kind,color in [('cloth',(.75,.70,.63)),('skin',(.89,.65,.51))]:
        material=bpy.data.materials.new('Jim repaired contact '+kind)
        material.use_nodes=True
        shader=next(node for node in material.node_tree.nodes if node.type=='BSDF_PRINCIPLED')
        linear=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in color]
        shader.inputs['Base Color'].default_value=(*linear,1)
        shader.inputs['Roughness'].default_value=.85
        cap_materials[kind]=len(obj.data.materials)
        obj.data.materials.append(material)
    for face in caps:
        face.smooth=True
        neighbors={other for edge in face.edges for other in edge.link_faces if other not in cap_set}
        if not neighbors:continue
        face[region]=int(sum(other[region] for other in neighbors)>len(neighbors)/2)
        face.material_index=cap_materials['skin' if face[region] else 'cloth']
        coordinates=[loop[uv].uv.copy() for other in neighbors for loop in other.loops if loop.vert in face.verts]
        if coordinates:
            center_uv=Vector(np.median(np.array(coordinates),axis=0))
            # A median atlas coordinate may land in another island. Pick a
            # real neighbouring cloth/skin texel instead of a nonexistent UV.
            cap_uv=min(coordinates,key=lambda value:(value-center_uv).length_squared)
            for loop in face.loops:loop[uv].uv=cap_uv
    # A branched contact loop can cap the finger side while leaving the
    # coincident trouser side open. Reconstruct that opposing cap explicitly.
    def position_key(vertex):return tuple(round(float(v),6) for v in vertex.co)
    coincident={}
    for vertex in bm.verts:coincident.setdefault(position_key(vertex),[]).append(vertex)
    cloth_caps={frozenset(position_key(v) for v in face.verts) for face in caps if face[region]==0}
    opposing_caps=[]
    for face in list(caps):
        center=B2G@face.calc_center_median()/height
        signature=frozenset(position_key(v) for v in face.verts)
        if face[region]!=1 or center.y>=.44 or center.z<=.02 or signature in cloth_caps:continue
        opposite=[]
        for vertex in face.verts:
            candidates=[other for other in coincident[position_key(vertex)] if other not in face.verts and any(f[region]==0 for f in other.link_faces)]
            if not candidates:break
            opposite.append(candidates[0])
        if len(opposite)!=len(face.verts) or len(set(opposite))!=len(opposite):continue
        try:repair=bm.faces.new(list(reversed(opposite)))
        except ValueError:continue
        repair[region]=0;repair.material_index=cap_materials['cloth']
        repair.smooth=True
        for loop in repair.loops:loop[uv].uv=face.loops[0][uv].uv.copy()
        opposing_caps.append(repair)
    degenerate_caps=[face for face in caps if face.calc_area()<1e-8]
    if degenerate_caps:bmesh.ops.delete(bm,geom=degenerate_caps,context='FACES_ONLY')
    # The supplied texture bakes the resting hand's shadow into the trousers.
    # Give only the exposed contact patch the same cloth material as its cap.
    contact_cloth_faces=0
    for face in bm.faces:
        center=B2G@face.calc_center_median()/height
        if face[region]==0 and .34<center.y<.405 and center.z>.06 and .06<abs(center.x)<.15:
            face.material_index=cap_materials['cloth']
            contact_cloth_faces+=1
    print('TRIPO_CONTACT_CLOTH_FACES',contact_cloth_faces,flush=True)
    print('TRIPO_OPPOSING_CAPS',len(opposing_caps),'REMOVED_DEGENERATE_CAPS',len(degenerate_caps),flush=True)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    vertex_region=bm.verts.layers.int.new('JimContactRegion')
    for vertex in bm.verts:
        values={face[region] for face in vertex.link_faces}
        vertex[vertex_region]=next(iter(values)) if len(values)==1 else 2
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    print('TRIPO_CONTACT_SEAM '+json.dumps({'id':'textbook_jim','split_edges':len(boundary),'caps':len(caps)}),flush=True)

def close_jim_contact_loops(obj,height):
    """Triangulate remaining contact boundaries after body/chair separation.

    Some source contact rings double back in 3D. A single ngon for such a ring
    has zero signed area and disappears on export; an explicit fan survives.
    """
    bm=bmesh.new();bm.from_mesh(obj.data)
    face_region=bm.faces.layers.int.get('JimArmSurface')
    vertex_region=bm.verts.layers.int.get('JimContactRegion')
    deform=bm.verts.layers.deform.active
    uv=bm.loops.layers.uv.active
    materials={kind:next(i for i,m in enumerate(obj.data.materials) if m.name.startswith('Jim repaired contact '+kind)) for kind in ['skin','cloth']}
    remaining=set(e for e in bm.edges if e.is_boundary)
    repaired=0
    while remaining:
        todo=[remaining.pop()];component=[]
        while todo:
            edge=todo.pop();component.append(edge)
            for vertex in edge.verts:
                for linked in vertex.link_edges:
                    if linked in remaining:remaining.remove(linked);todo.append(linked)
        vertices={v for e in component for v in e.verts}
        center=sum((v.co for v in vertices),Vector())/len(vertices)
        normalized=B2G@center/height
        if not (3<=len(component)<=40 and .30<normalized.y<.535 and .045<abs(normalized.x)<.20):continue
        if any(sum(e in component for e in v.link_edges)!=2 for v in vertices):continue
        neighbors={f for e in component for f in e.link_faces}
        skin=sum(f[face_region] for f in neighbors)>len(neighbors)/2
        midpoint=bm.verts.new(center)
        midpoint[vertex_region]=int(skin)
        if deform:
            keys={key for v in vertices for key in v[deform].keys()}
            for key in keys:midpoint[deform][key]=sum(v[deform].get(key,0) for v in vertices)/len(vertices)
        for edge in component:
            face=bm.faces.new([edge.verts[0],edge.verts[1],midpoint])
            face.smooth=True
            face[face_region]=int(skin)
            face.material_index=materials['skin' if skin else 'cloth']
            for loop in face.loops:loop[uv].uv=(0,0)
        repaired+=1
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    print('TRIPO_EXPLICIT_CONTACT_CAPS',repaired,flush=True)

def bind_weights(obj, character_id, family, height, p, pts, bones, arms, legs, rgb):
    xyz = mesh_arrays(obj)/height
    x,y,z = xyz.T
    names = [b['name'] for b in bones]
    index = {name:i for i,name in enumerate(names)}
    weights = np.zeros((len(xyz),len(bones)),np.float32)
    spine = smooth(p['hip']-.015,p['spine']+.07,y)
    weights[:,index['Hips']] = 1-spine
    weights[:,index['Spine']] = spine
    # Leg chains are chosen by side, with a smooth pelvis transition.
    leg_distance = np.full(len(xyz),np.inf)
    leg_weights = np.zeros_like(weights)
    for side,sign in [('L',-1),('R',1)]:
        dist,w = chain_weights(xyz,legs[side],.033)
        chosen = sign*x >= 0
        leg_distance[chosen] = dist[chosen]
        for j,name in enumerate([f'UpperLeg_{side}',f'LowerLeg_{side}',f'Foot_{side}']):
            leg_weights[chosen,index[name]] = w[chosen,j]
    leg_amount = 1-smooth(p['hip']-.075,p['hip']+.025,y)
    weights = weights*(1-leg_amount[:,None])+leg_weights*leg_amount[:,None]
    torso = np.array([pts['Hips'],pts['Spine'],pts['Neck']])
    torso_distance,_,_ = line_distance(xyz,torso)
    competitor = np.where(y<p['hip']-.03,leg_distance,torso_distance)
    for side,sign in [('L',-1),('R',1)]:
        distance,w = chain_weights(xyz,arms[side],.032)
        amount = smooth(-.018,.035,competitor-distance-.022)
        amount *= (sign*x > .065)*(y < p['neck']+.02)
        width=.145 if family=='humanoid' else .15 if family=='animal' else .17
        if character_id=='npc_bear_uncle':width=.205
        if family!='wheelchair':
            torso_edge=np.interp(y,[p['hip'],p['shoulder']-.06,p['shoulder']+.02],[width,width*.88,p['sx']*.65])
            amount *= smooth(torso_edge-.006,torso_edge+.018,np.abs(x))
        if character_id=='player':
            amount[(z<-.065)&(np.abs(x)<.15)&(y>.42)] = 0
        if family=='wheelchair':
            # Jim's fingers touch his beige trousers. Their measured red/green
            # ratios differ (skin ~1.38, trousers ~1.08), so the cloth must not
            # be pulled into the hand by a Euclidean envelope.
            skin=(rgb[:,0]>rgb[:,1]*1.18)&(rgb[:,1]>rgb[:,2]*1.10)
            bare_arm=skin&(sign*x>.06)&(sign*x<.20)&(y>.33)&(y<.56)&(z>-.11)
            sleeve=(sign*x>.115)&(sign*x<.20)&(y>.49)&(y<.625)&(z>-.23)
            amount *= sleeve
            amount[bare_arm] = 1
        weights *= 1-amount[:,None]
        for j,name in enumerate([f'UpperArm_{side}',f'LowerArm_{side}',f'Hand_{side}']):
            weights[:,index[name]] += amount*w[:,j]
    head = smooth(p['neck']-.015,p['head']+.012,y)
    weights *= 1-head[:,None]
    weights[:,index['Head']] += head
    if family=='dino':
        wing = smooth(.105,.17,np.abs(x))*(y>.46)*(z<.025)
        for side,sign in [('L',-1),('R',1)]:
            amount=wing*(sign*x>0)
            weights *= 1-amount[:,None]
            weights[:,index[f'Wing_{side}']] += amount
        tail = (1-smooth(-.05,.045,z))*(y<.41)
        # Tail joins the pelvis at the rear, clear of the forward legs.
        tail *= smooth(.025,.12,np.sqrt((z-.09)**2+x*x))
        weights *= 1-tail[:,None]
        _,tw = chain_weights(xyz,np.array([pts['Tail'],pts['Tail_02'],pts['Tail_03'],(.40,.17,-.37)]),.045)
        for j,name in enumerate(['Tail','Tail_02','Tail_03']):
            weights[:,index[name]] += tail*tw[:,j]
    elif character_id=='npc_rabbit_gardener':
        for side,sign in [('L',-1),('R',1)]:
            amount=smooth(.79,.845,y)*(sign*x>0)
            weights *= 1-amount[:,None]
            weights[:,index[f'Ear_{side}']] += amount
        tail=(z<-.11)&(y>.25)&(y<.38)&(np.abs(x)<.06)
        weights[tail]=0;weights[tail,index['RabbitTail']]=1
    chair=np.zeros(len(xyz),bool)
    if family=='wheelchair':
        chair=(y<.665)&((rgb.max(axis=1)<.55)&((np.abs(x)>.15)|(z<-.21)))
        chair |= (y<.665)&(np.abs(x)>.207)
        chair |= (z<-.24)&(y<.655)
        chair |= (y<.105)&(rgb.max(axis=1)<.4)
        chair |= (y>.35)&(y<.415)&(z<.17)&(rgb[:,2]>rgb[:,0]*1.12)
        # Grey sleeve cuffs are part of the shirt, above the real armrests.
        chair &= ~((y>.475)&(z>-.21)&(np.abs(x)<.205))
        weights[chair]=0;weights[chair,index['ChairRoot']]=1
        for side,sign in [('L',-1),('R',1)]:
            wheel=chair&(sign*x>.19)&(y<.455)&(z<.12)
            castor=chair&(sign*x>.16)&(y<.12)&(z>.16)
            weights[wheel]=0;weights[wheel,index[f'Wheel_{side}']]=1
            weights[castor]=0;weights[castor,index[f'Castor_{side}']]=1
    # Diffuse only along actual connected mesh edges. This prevents weights
    # jumping across the air gap between a hand and the body.
    edge_data=np.empty(len(obj.data.edges)*2,np.int32)
    obj.data.edges.foreach_get('vertices',edge_data)
    edges=edge_data.reshape(-1,2)
    degree=np.bincount(edges.reshape(-1),minlength=len(xyz)).astype(np.float32)
    fixed=(y>p['head']+.05)|chair
    for _ in range(3):
        sums=np.zeros_like(weights)
        np.add.at(sums,edges[:,0],weights[edges[:,1]])
        np.add.at(sums,edges[:,1],weights[edges[:,0]])
        new=.68*weights+.32*sums/np.maximum(degree,1)[:,None]
        weights[~fixed]=new[~fixed]
    if family=='wheelchair':
        trousers=(y<.44)&~skin&~chair
        regions=np.array([item.value for item in obj.data.attributes['JimContactRegion'].data])
        trousers |= (y<.44)&(regions==0)&~chair
        for side in ['L','R']:
            for name in [f'UpperArm_{side}',f'LowerArm_{side}',f'Hand_{side}']:
                weights[trousers,index[name]]=0
        for side,sign in [('L',-1),('R',1)]:
            contact_hand=(y<.44)&(regions==1)&(sign*x>0)&~chair
            _,w=chain_weights(xyz,arms[side],.032)
            weights[contact_hand]=0
            for j,name in enumerate([f'UpperArm_{side}',f'LowerArm_{side}',f'Hand_{side}']):
                weights[contact_hand,index[name]]=w[contact_hand,j]
    order=np.argsort(weights,axis=1)[:,-4:]
    kept=np.zeros_like(weights)
    np.put_along_axis(kept,order,np.take_along_axis(weights,order,axis=1),axis=1)
    total=kept.sum(axis=1)
    assert np.all(total>1e-7), 'Unweighted vertices'
    kept /= total[:,None]
    for name,i in index.items():
        group=obj.vertex_groups.new(name=name)
        for vertex in np.flatnonzero(kept[:,i]>1e-6):
            group.add([int(vertex)],float(kept[vertex,i]),'REPLACE')
    if character_id=='player':
        # A second UV channel carries a garment mask. It never changes the
        # supplied base-colour texture or the skin/hair/backpack colours.
        mask=(y>.275)&(y<.65)&(np.abs(x)<.16)&~((z<-.06)&(y>.43))
        yellow=(rgb[:,0]>rgb[:,2]*1.8)&(rgb[:,1]>rgb[:,2]*1.35)&(rgb[:,1]>rgb[:,0]*.50)
        mask &= yellow
        layer=obj.data.uv_layers.new(name='OutfitMask')
        for loop in obj.data.loops:
            layer.data[loop.index].uv=(float(mask[loop.vertex_index]),.5)
    return kept,chair,xyz

def add_expressions(obj, family, p, height):
    xyz=mesh_arrays(obj)/height
    x,y,z=xyz.T
    # Small geometric eyelid and mouth expressions, authored on the supplied
    # face. They are not phoneme-level lip sync.
    eye_y = .79 if family=='humanoid' else .645 if family=='animal' else .805 if family=='dino' else .785
    if obj.get('character_id')=='textbook_miss_li': eye_y=.878
    if obj.get('character_id')=='npc_bear_uncle': eye_y=.735
    eye_x = .054 if family=='humanoid' else .066 if family=='animal' else .066 if family=='dino' else .055
    if obj.get('character_id')=='textbook_miss_li': eye_x=.043
    mouth_y=eye_y-(.095 if family=='dino' else .065)
    front=np.clip((z-p['headfront']+.01)/.07,0,1)
    eye=np.exp(-((np.abs(x)-eye_x)/.025)**4-((y-eye_y)/.035)**4)*front
    mouth=np.exp(-(x/.075)**4-((y-mouth_y)/.03)**4)*front
    obj.shape_key_add(name='Basis')
    deltas={}
    blink=np.zeros_like(xyz);blink[:,1]=(eye_y-y)*eye*.92
    smile=np.zeros_like(xyz);smile[:,1]=np.abs(x)/.075*.008*mouth
    talk=np.zeros_like(xyz);talk[:,1]=-.009*mouth*(y<mouth_y)
    for name,delta in [('Blink',blink),('Smile',smile),('Talk',talk)]:
        key=obj.shape_key_add(name=name)
        target=(xyz+delta)*height
        b=np.stack((target[:,0],-target[:,2],target[:,1]),axis=1).astype(np.float32)
        key.data.foreach_set('co',b.reshape(-1))
        key.value=0
        deltas[name]=int(np.count_nonzero(np.linalg.norm(delta,axis=1)>1e-6))
    return deltas

def make_armature(character_id, pts, parents, rest, arms, legs, height):
    data=bpy.data.armatures.new(character_id+'_Rig')
    arm=bpy.data.objects.new('SemanticRig',data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active=arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name,xyz in pts.items():
        bone=data.edit_bones.new(name)
        head=Vector(xyz)*height
        end=head+Vector((0,.10*height,0))
        for side in ['L','R']:
            for names,line in [([f'UpperArm_{side}',f'LowerArm_{side}',f'Hand_{side}'],arms[side]),([f'UpperLeg_{side}',f'LowerLeg_{side}',f'Foot_{side}'],legs[side])]:
                if name in names:
                    end=Vector(line[names.index(name)+1])*height
        if name.startswith('Wing_'):
            end=Vector(((-.41 if name.endswith('L') else .41),.62,-.06))*height
        elif name=='Tail':end=Vector(pts['Tail_02'])*height
        elif name=='Tail_02':end=Vector(pts['Tail_03'])*height
        elif name=='Tail_03':end=Vector((.40,.17,-.37))*height
        elif name=='Head':end=head+Vector((0,.15*height,0))
        bone.head=G2B@head;bone.tail=G2B@end
        if parents[name]:bone.parent=data.edit_bones[parents[name]]
        bone.use_connect=False
        if name in ['Root','Neck']:
            bone.use_deform=False
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.show_in_front=True
    return arm

def heat_weights(obj,arm,bones,fallback,p,height):
    names=[b['name'] for b in bones]
    index={name:i for i,name in enumerate(names)}
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True);arm.select_set(True)
    bpy.context.view_layer.objects.active=arm
    obj.vertex_groups.clear()
    success=True
    heat_error=''
    try:
        bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    except RuntimeError as exc:
        heat_error=str(exc)
        success=False
    result=np.zeros_like(fallback)
    groups={g.index:index[g.name] for g in obj.vertex_groups if g.name in index}
    for vertex in obj.data.vertices:
        for group in vertex.groups:
            if group.group in groups:
                result[vertex.index,groups[group.group]]=group.weight
    covered=result.sum(axis=1)>1e-6
    coverage=float(np.mean(covered))
    success=coverage>.98
    if not success:
        result=fallback.copy()
    else:
        result[~covered]=fallback[~covered]
        # Facial features and hair are a rigid head region; this also prevents
        # the neck helper from partially immobilizing a nod or a head turn.
        xyz=mesh_arrays(obj)/height
        head=xyz[:,1]>p['head']+.035
        result[head]=0;result[head,index['Head']]=1
    order=np.argsort(result,axis=1)[:,-4:]
    kept=np.zeros_like(result)
    np.put_along_axis(kept,order,np.take_along_axis(result,order,axis=1),axis=1)
    kept/=np.maximum(kept.sum(axis=1),1e-12)[:,None]
    obj.vertex_groups.clear()
    for name,i in index.items():
        group=obj.vertex_groups.new(name=name)
        for vertex in np.flatnonzero(kept[:,i]>1e-6):
            group.add([int(vertex)],float(kept[vertex,i]),'REPLACE')
    print('TRIPO_HEAT_WEIGHTS '+json.dumps({'character':obj.get('character_id'),'solved':success,'coverage':coverage,'error':heat_error}),flush=True)
    return kept,success

def geodesic_weights(obj,bones,fallback,p,pts,arms,legs,height,family,chair):
    """Diffuse from anatomical surface seeds through connected triangles only.

    The shortest surface path distinguishes the inner arm from a nearby torso,
    where Euclidean envelopes and bone heat on generated geometry can fail.
    """
    xyz=mesh_arrays(obj)/height
    contact_regions=None
    region_rgb=None
    if family=='wheelchair':
        contact_regions=np.array([item.value for item in obj.data.attributes['JimContactRegion'].data])
        region_rgb,_=texture_data(obj)
    names=[b['name'] for b in bones];index={n:i for i,n in enumerate(names)}
    n=len(xyz)
    graph=[[] for _ in range(n)]
    for edge in obj.data.edges:
        a,b=edge.vertices
        if chair[a]!=chair[b]:continue
        length=float(np.linalg.norm(xyz[a]-xyz[b]))
        graph[a].append((int(b),length));graph[b].append((int(a),length))
    lines={
        'Hips':np.array([pts['Hips']])+np.array([[0,-.035,0],[0,.035,0]]),
        'Spine':np.array([pts['Spine'],pts['Neck']]),
        'Head':np.array([pts['Head']])+np.array([[0,.035,0],[0,.18,0]]),
    }
    for side in ['L','R']:
        for bone_names,line in [([f'UpperArm_{side}',f'LowerArm_{side}',f'Hand_{side}'],arms[side]),([f'UpperLeg_{side}',f'LowerLeg_{side}',f'Foot_{side}'],legs[side])]:
            for i,name in enumerate(bone_names):lines[name]=line[i:i+2]
    if family=='dino':
        lines.update(Tail=np.array([pts['Tail'],pts['Tail_02']]),Tail_02=np.array([pts['Tail_02'],pts['Tail_03']]),Tail_03=np.array([pts['Tail_03'],(.40,.17,-.37)]),
                     Wing_L=np.array([pts['Wing_L'],(-.37,.61,-.075)]),Wing_R=np.array([pts['Wing_R'],(.37,.61,-.075)]))
    for side in ['L','R']:
        if f'Ear_{side}' in pts:lines[f'Ear_{side}']=np.array([pts[f'Ear_{side}'],np.array(pts[f'Ear_{side}'])+[0,.16,0]])
    if 'RabbitTail' in pts:lines['RabbitTail']=np.array([pts['RabbitTail'],(0,.325,-.16)])
    distances=np.full((n,len(bones)),np.inf,np.float32)
    for name,line in lines.items():
        column=index[name]
        seeds=set()
        eligible=~chair
        if name in ['Hips','Spine']:eligible=eligible&(np.abs(xyz[:,0])<.065)
        if name.startswith(('UpperArm','LowerArm','Hand')):
            sign=-1 if name.endswith('_L') else 1
            eligible=eligible&(sign*xyz[:,0]>.095)
            if family=='wheelchair':
                if name.startswith('UpperArm'):
                    eligible &= (xyz[:,1]>.49)&(xyz[:,1]<.625)&(xyz[:,2]>-.21)
                else:
                    eligible &= (contact_regions==1)&(xyz[:,1]>.33)&(xyz[:,1]<.53)
        ids=np.flatnonzero(eligible)
        for t in [.18,.5,.82]:
            point=line[0]*(1-t)+line[-1]*t
            sq=np.sum((xyz[ids]-point)**2,axis=1)
            closest=ids[np.argpartition(sq,min(9,len(sq)-1))[:10]]
            seeds.update(int(i) for i in closest)
        if name=='Head':
            seeds.update(int(i) for i in np.flatnonzero(xyz[:,1]>p['head']+.07))
        dist=distances[:,column]
        queue=[(0.,s) for s in seeds]
        for s in seeds:dist[s]=0
        heapq.heapify(queue)
        while queue:
            value,vertex=heapq.heappop(queue)
            if value>float(dist[vertex])+1e-7:continue
            for neighbor,length in graph[vertex]:
                candidate=value+length
                if candidate+1e-7<float(dist[neighbor]):
                    dist[neighbor]=candidate
                    heapq.heappush(queue,(candidate,neighbor))
    minimum=distances.min(axis=1)
    valid=np.isfinite(minimum)&~chair
    result=fallback.copy()
    score=np.zeros_like(fallback)
    score[valid]=np.exp(-(distances[valid]-minimum[valid,None])/.032)
    score[valid]/=np.maximum(score[valid].sum(axis=1),1e-12)[:,None]
    result[valid]=score[valid]
    if family=='wheelchair':
        # Skin-contact seams separate fingers from trousers. Keep the actual
        # trouser surface on the seated lower-body chains, even near a palm.
        trousers=(xyz[:,1]<.44)&(contact_regions==0)
        for side in ['L','R']:
            for name in [f'UpperArm_{side}',f'LowerArm_{side}',f'Hand_{side}']:
                result[trousers,index[name]]=0
        torso=(xyz[:,1]>.40)&(xyz[:,1]<.65)&(xyz[:,2]<.025)&(contact_regions!=1)
        allowance=smooth(.09,.15,np.abs(xyz[:,0]))*smooth(.44,.52,xyz[:,1])
        for side in ['L','R']:
            for name in [f'UpperArm_{side}',f'LowerArm_{side}',f'Hand_{side}']:
                result[torso,index[name]]*=allowance[torso]
        for side in ['L','R']:
            for name in [f'UpperLeg_{side}',f'LowerLeg_{side}',f'Foot_{side}']:
                result[:,index[name]]*=1-smooth(.42,.46,xyz[:,1])
        cuff=(xyz[:,1]>.47)&(xyz[:,1]<.55)&(np.abs(xyz[:,0])>.085)&(np.abs(xyz[:,0])<.20)&(xyz[:,2]>-.19)
        cuff &= (region_rgb[:,1]>region_rgb[:,0]*.90)&(region_rgb[:,2]>region_rgb[:,0]*.80)&(region_rgb.max(axis=1)<.70)
        for side,sign in [('L',-1),('R',1)]:
            chosen=cuff&(sign*xyz[:,0]>0)
            _,values=chain_weights(xyz,arms[side],.032)
            amount=smooth(.095,.14,np.abs(xyz[:,0]))
            result[chosen]*=(1-amount[chosen,None])
            for j,name in enumerate([f'UpperArm_{side}',f'LowerArm_{side}',f'Hand_{side}']):result[chosen,index[name]]+=values[chosen,j]*amount[chosen]
        result/=np.maximum(result.sum(axis=1),1e-20)[:,None]
        # Blend locally across the sleeve/skin boundary; texture color is only
        # a region hint and must not introduce a discontinuity in the skin.
        edge_pairs=np.array([list(edge.vertices) for edge in obj.data.edges],np.int32)
        a,b=edge_pairs.T
        edge_weights=1/(np.linalg.norm(xyz[a]-xyz[b],axis=1)+1e-4)
        degree=np.zeros(n,np.float32)
        np.add.at(degree,a,edge_weights);np.add.at(degree,b,edge_weights)
        blend=.65*smooth(.425,.465,xyz[:,1])*(1-smooth(.55,.59,xyz[:,1]))
        for iteration in range(8):
            summed=np.zeros_like(result)
            np.add.at(summed,a,result[b]*edge_weights[:,None])
            np.add.at(summed,b,result[a]*edge_weights[:,None])
            average=summed/np.maximum(degree,1e-12)[:,None]
            result=result*(1-blend[:,None])+average*blend[:,None]
    head=xyz[:,1]>p['head']+.035
    result[head]=0;result[head,index['Head']]=1
    if 'Ear_L' in index:
        for side,sign in [('L',-1),('R',1)]:
            ear=(xyz[:,1]>.84)&(sign*xyz[:,0]>0)
            result[ear]=0;result[ear,index[f'Ear_{side}']]=1
    order=np.argsort(result,axis=1)[:,-4:]
    kept=np.zeros_like(result)
    np.put_along_axis(kept,order,np.take_along_axis(result,order,axis=1),axis=1)
    kept/=np.maximum(kept.sum(axis=1),1e-12)[:,None]
    obj.vertex_groups.clear()
    for name,i in index.items():
        group=obj.vertex_groups.new(name=name)
        for vertex in np.flatnonzero(kept[:,i]>1e-6):group.add([int(vertex)],float(kept[vertex,i]),'REPLACE')
    print('TRIPO_GEODESIC '+json.dumps({'id':obj.get('character_id'),'covered':int(np.count_nonzero(valid)),'vertices':n}),flush=True)
    return kept

def track_value(track,t):
    keys=track['keys']
    a=keys[0];b=keys[-1]
    for left,right in zip(keys[:-1],keys[1:]):
        if left['time']<=t<=right['time']:
            a,b=left,right;break
    f=max(0,min(1,(t-a['time'])/max(1e-8,b['time']-a['time'])))
    if track['type']=='rotation':
        av,bv=a['value'],b['value']
        return Quaternion((av[3],*av[:3])).slerp(Quaternion((bv[3],*bv[:3])),f)
    return Vector(a['value']).lerp(Vector(b['value']),f)

def pose_at(arm, bones, rest, family, clip, t):
    values={(track['bone'],track['type']):track_value(track,t) for track in clip['tracks']}
    if clip is CONTRACT['families'][family]['clips'].get('greet_wave'):
        character_id=arm.data.name.removesuffix('_Rig')
        for track in GESTURES.get('characters',{}).get(character_id,{}).get('normal',{}).get('greet_wave',[]):
            values[(track['bone'],'rotation')]=track_value(dict(track,type='rotation'),t)
    global_poses={}
    desired_matrices={}
    source_hips=CONTRACT['families'][family]['source_hips_height']
    for bone in bones:
        name,parent=bone['name'],bone['parent']
        pos=Vector(bone['origin'])
        if (name,'position') in values:
            pos=values[(name,'position')]+pos-Vector((0,source_hips,0))
        rot=values.get((name,'rotation'),Matrix.Rotation(bone['rotation'][0],3,'X').to_quaternion())
        if family=='animal' and 'Ear_L' in rest and name=='UpperArm_R' and clip is CONTRACT['families'][family]['clips'].get('place_item'):
            amount=max(0,min(1,t/1.1,(clip['length']-t)/1.1))
            rot=Quaternion((0,1,0),math.radians(-10)*amount)@Quaternion((1,0,0),math.radians(-10)*amount)@rot
        local=Matrix.Translation(pos)@rot.to_matrix().to_4x4()
        global_poses[name]=global_poses[parent]@local if parent else local
        desired=G2B@global_poses[name]@rest[name].inverted()@B2G@arm.data.bones[name].matrix_local
        desired_matrices[name]=desired
        # Solve the parent-relative basis explicitly. Sequential assignment to
        # PoseBone.matrix otherwise reads stale evaluated parent matrices.
        source_rest=arm.data.bones[name].matrix_local
        if parent:
            relative_rest=arm.data.bones[parent].matrix_local.inverted()@source_rest
            basis=(desired_matrices[parent]@relative_rest).inverted()@desired
        else:
            basis=source_rest.inverted()@desired
        arm.pose.bones[name].matrix_basis=basis
    bpy.context.view_layer.update()

def make_actions(arm,bones,rest,family):
    bpy.context.scene.render.fps=30
    arm.animation_data_create()
    interpolation=bpy.context.preferences.edit.bl_rna.properties['keyframe_new_interpolation_type'].enum_items
    bpy.context.preferences.edit.keyframe_new_interpolation_type=next(i.identifier for i in interpolation if i.identifier=='LINEAR')
    rows=[]
    for action,clip in CONTRACT['families'][family]['clips'].items():
        data=bpy.data.actions.new(action)
        data.use_fake_user=True
        arm.animation_data.action=data
        times=sorted({key['time'] for track in clip['tracks'] for key in track['keys']})
        for t in times:
            pose_at(arm,bones,rest,family,clip,t)
            for bone in arm.pose.bones:
                bone.rotation_mode='QUATERNION'
                bone.keyframe_insert('location',frame=1+t*30,group=bone.name)
                bone.keyframe_insert('rotation_quaternion',frame=1+t*30,group=bone.name)
                bone.keyframe_insert('scale',frame=1+t*30,group=bone.name)
        rows.append(dict(name=action,duration=clip['length'],loop=clip['loop'],contact_time=clip['semantic_spec']['contact_time']))
    arm.animation_data.action=None
    for bone in arm.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    return rows

def process(profile):
    character_id,_,height,_,family=profile
    start=time.time();folder=OUT/character_id
    bpy.ops.wm.open_mainfile(filepath=str(folder/'prepared.blend'))
    obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    obj.name='Body';obj['character_id']=character_id
    # UV seams are loop data, so welding coincident positions preserves UVs.
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=height*1e-6)
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    p,pts,parents,rest,bones,arms,legs=layout(character_id,family,height)
    mixamo_source=None
    if MIXAMO_MODE:
        assert family=='humanoid','Mixamo adapter is restricted to standing humanoids'
        obj,pts,rest,bones,arms,legs,mixamo_weights,mixamo_source=import_mixamo_candidate(character_id,obj,height,pts,parents)
    rgb,textures=texture_data(obj)
    if family=='wheelchair':
        separate_jim_hand_contacts(obj,rgb,height)
        rgb,textures=texture_data(obj)
    weights,chair,xyz=bind_weights(obj,character_id,family,height,p,pts,bones,arms,legs,rgb)
    arm=make_armature(character_id,pts,parents,rest,arms,legs,height)
    heat_solved=False
    if mixamo_source:
        weights=assign_weights(obj,bones,mixamo_weights)
    elif family!='wheelchair':
        weights,heat_solved=heat_weights(obj,arm,bones,weights,p,height)
        if not heat_solved:
            weights=geodesic_weights(obj,bones,weights,p,pts,arms,legs,height,family,chair)
    mesh_objects=[obj]
    if family=='wheelchair' and np.any(chair):
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        for vertex in obj.data.vertices:vertex.select=False
        for edge in obj.data.edges:edge.select=False
        for face in obj.data.polygons:face.select=bool(sum(chair[i] for i in face.vertices)>len(face.vertices)/2)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.context.tool_settings.mesh_select_mode=(False,False,True)
        bpy.ops.mesh.separate(type='SELECTED')
        bpy.ops.object.mode_set(mode='OBJECT')
        for other in list(bpy.context.scene.objects):
            if other.type=='MESH' and other!=obj:
                other.name='Wheelchair';mesh_objects.append(other)
        for mesh in mesh_objects:
            mesh.data.validate(clean_customdata=False)
            mesh.data.update()
            points=mesh_arrays(mesh)/height
            contact_regions=mesh.data.attributes['JimContactRegion'].data
            surface_rgb,_=texture_data(mesh)
            for vertex in mesh.data.vertices:
                chair_groups=[group for group in vertex.groups if mesh.vertex_groups[group.group].name.startswith(('Chair','Wheel','Castor'))]
                if mesh.name=='Wheelchair':
                    for group in list(vertex.groups):
                        mesh.vertex_groups[group.group].remove([vertex.index])
                    mesh.vertex_groups['ChairRoot'].add([vertex.index],1.0,'REPLACE')
                elif sum(group.weight for group in chair_groups)>.98:
                    point=points[vertex.index]
                    color=surface_rgb[vertex.index]
                    skin_region=contact_regions[vertex.index].value==1 or (color[0]>color[1]*1.18 and color[1]>color[2]*1.10)
                    if skin_region and .33<point[1]<.56 and abs(point[0])>.055 and point[2]>-.13:
                        for group in list(vertex.groups):mesh.vertex_groups[group.group].remove([vertex.index])
                        side='R' if point[0]>0 else 'L'
                        _,values=chain_weights(points[vertex.index:vertex.index+1],arms[side],.032)
                        for j,name in enumerate([f'UpperArm_{side}',f'LowerArm_{side}',f'Hand_{side}']):
                            if values[0,j]>1e-6:mesh.vertex_groups[name].add([vertex.index],float(values[0,j]),'REPLACE')
        close_jim_contact_loops(obj,height)
        body_fallback=np.zeros((len(obj.data.vertices),len(bones)),np.float32)
        bone_indices={bone['name']:i for i,bone in enumerate(bones)}
        for vertex in obj.data.vertices:
            for group in vertex.groups:
                name=obj.vertex_groups[group.group].name
                body_fallback[vertex.index,bone_indices[name]]=group.weight
        geodesic_weights(obj,bones,body_fallback,p,pts,arms,legs,height,family,np.zeros(len(body_fallback),bool))
    garment_refinement=refine_garment_weights(obj,character_id,bones,height)
    morphs=add_expressions(obj,family,p,height)
    for mesh in mesh_objects:
        mesh.parent=arm
        modifier=next((m for m in mesh.modifiers if m.type=='ARMATURE'),None)
        if modifier is None:modifier=mesh.modifiers.new('Semantic skin','ARMATURE')
        modifier.object=arm
    actions=make_actions(arm,bones,rest,family)
    for mesh in mesh_objects:mesh.select_set(True)
    arm.select_set(True);bpy.context.view_layer.objects.active=arm
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'rigged.blend'))
    export_args=dict(filepath=str(folder/'character.glb'),export_format='GLB',use_selection=True,
                     export_animations=True,export_yup=True,export_apply=False,export_extras=True,export_materials='EXPORT')
    props=bpy.ops.export_scene.gltf.get_rna_type().properties
    if 'export_animation_mode' in props:
        modes=[i.identifier for i in props['export_animation_mode'].enum_items]
        if 'ACTIONS' in modes:export_args['export_animation_mode']='ACTIONS'
    bpy.ops.export_scene.gltf(**export_args)
    sockets={}
    for side in ['L','R']:
        # The semantic prop anchor sits just forward of the palm centre.
        palm=Vector(arms[side][2:4].mean(axis=0))*height+Vector((0,0,.035))
        sockets[side]=list(rest[f'LowerArm_{side}'].inverted()@palm)
    prep=json.loads((folder/'preparation.json').read_text(encoding='utf-8'))
    final_weights=[]
    bone_indices={bone['name']:i for i,bone in enumerate(bones)}
    for mesh in mesh_objects:
        matrix=np.zeros((len(mesh.data.vertices),len(bones)),np.float32)
        for vertex in mesh.data.vertices:
            for group in vertex.groups:
                matrix[vertex.index,bone_indices[mesh.vertex_groups[group.group].name]]=group.weight
        final_weights.append(matrix)
    weights=np.concatenate(final_weights)
    actual_triangles=sum(sum(len(face.vertices)-2 for face in mesh.data.polygons) for mesh in mesh_objects)
    row=dict(id=character_id,revision='tripo-character-v1',family=family,height=height,bones=bones,
             hand_sockets=sockets,source=prep['source'],source_sha256=prep['source_sha256'],
             source_triangles=prep['source_triangles'],triangles=actual_triangles,textures=textures,
             editable_source=str((folder/'rigged.blend').relative_to(ROOT)).replace('\\','/'),
             export_glb=str((folder/'character.glb').relative_to(ROOT)).replace('\\','/'),
             weight_method=('Blender bone heat with fitted anatomical joints and rigid head anchors' if heat_solved else 'anatomical surface geodesics with rigid region anchors' if family!='wheelchair' else 'repaired hand contact seams, seated surface geodesics, constrained sleeve weights and rigid separate wheelchair')+'; four normalized influences',
             vertices=len(weights),blended_vertices=int(np.count_nonzero((weights>1e-4).sum(axis=1)>1)),
             unweighted_vertices=int(np.count_nonzero(weights.sum(axis=1)<1e-6)),weight_sum_max_error=float(np.max(np.abs(weights.sum(axis=1)-1))),
             bone_vertex_counts={b['name']:int(np.count_nonzero(weights[:,i]>1e-4)) for i,b in enumerate(bones)},
             morph_vertex_counts=morphs,actions=actions,meshes=[o.name for o in mesh_objects],
             raw_model_preserved=True,status='rigged_pending_engine_validation',elapsed_seconds=round(time.time()-start,2))
    if mixamo_source:
        row['rigging_provider']=mixamo_source
        row['weight_method']='Adobe Mixamo auto-rigging and skin weights, consolidated to the semantic runtime skeleton; four normalized influences'
    if garment_refinement.get('changed_vertices'):
        row['garment_refinement']=garment_refinement
    (folder/'rig.json').write_text(json.dumps(row,ensure_ascii=False,indent=2),encoding='utf-8')
    camera=setup_render(height)
    camera.data.ortho_scale=height*1.55
    camera.location=(height*.9,-height*2.5,height*.8)
    camera.rotation_euler=(Vector((0,0,height*.5))-camera.location).to_track_quat('-Z','Y').to_euler()
    for action,t in [('idle',0),('greet_wave',.92),('take_item' if family=='wheelchair' else 'walk',1.1 if family=='wheelchair' else .28),('give_item',1.1)]:
        pose_at(arm,bones,rest,family,CONTRACT['families'][family]['clips'][action],t)
        bpy.context.scene.render.filepath=str(folder/(action+'_rigged.png'))
        bpy.ops.render.render(write_still=True)
    print('TRIPO_RIGGED '+json.dumps({'id':character_id,'bones':len(bones),'triangles':row['triangles'],'morphs':morphs,'seconds':round(time.time()-start,1)}),flush=True)

if __name__=='__main__':
    selected=set(sys.argv[sys.argv.index('--')+1:]) if '--' in sys.argv else set()
    for profile in PROFILES:
        if not selected or profile[0] in selected:
            process(profile)
