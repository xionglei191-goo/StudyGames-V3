"""Fit each resident and run the installed Mesh2Motion solver, then export real skins.

Blender -b -t 3 --python scripts/rig_building_residents.py -- resident_classroom ...
Only derived files are written. Original Tripo GLBs and the 12 core actors are preserved.
"""
from __future__ import annotations
import hashlib
import heapq
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/characters/building_residents_v1'
ENGINE = Path(os.environ.get('MESH2MOTION_ENGINE', 'F:/VideoMaker/experiments/mesh2motion-robots-20261027/engine'))
sys.path.insert(0, str(ROOT / 'scripts'))
import rig_tripo_characters as base
import prepare_tripo_characters as preparation


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def fitted_layout(spec, xyz, height):
    p = dict(hip=.45, spine=.56, neck=.72, head=.745, shoulder=.68, elbow=.54,
             wrist=.42, knee=.25, ankle=.055, sx=.125, ex=.185, wx=.235, legx=.075,
             front=0., headfront=0.)
    p.update({k: float(v) for k,v in spec.items() if k in p})
    p['spine'] = p['hip'] + (p['shoulder']-p['hip'])*.54
    # Slice the actual limbs; joint heights remain individually reviewed above.
    def segment_center(y, side, xmin, xmax, zmax=.16):
        mask = (np.abs(xyz[:,1]-y)<.018) & (xyz[:,0]*side>xmin) & (xyz[:,0]*side<xmax) & (xyz[:,2]>-.17) & (xyz[:,2]<zmax)
        points = xyz[mask]
        # Vertex density is not volume: the median can sit on a densely
        # tessellated front/back surface. Fit between the opposite boundaries.
        return np.quantile(points[:,[0,2]],[.08,.92],axis=0).mean(axis=0) if len(points)>8 else np.array([side*(xmin+xmax)/2,0.])
    pts={'Root':(0,0,0),'Hips':(0,p['hip'],p['front']),
         'Spine':(0,p['spine'],p['front']),'Neck':(0,p['neck'],p['headfront']),
         'Head':(0,p['head'],p['headfront'])}
    parents={'Root':None,'Hips':'Root','Spine':'Hips','Neck':'Spine','Head':'Neck'}
    arms,legs={},{}
    for side,sign in [('L',-1),('R',1)]:
        arm=[]
        for key,xkey in [('shoulder','sx'),('elbow','ex'),('wrist','wx')]:
            # At elbow/wrist the arm is the outer slice, away from the torso.
            x,z=segment_center(p[key],sign,p[xkey]-.035,p[xkey]+.055)
            arm.append((float(x),p[key],float(z)))
        arm.append((arm[2][0]+sign*.006,p['wrist']-.065,arm[2][2]+.008))
        leg=[]
        for y in [p['hip']-.02,p['knee'],p['ankle']]:
            x,z=segment_center(y,sign,max(.018,p['legx']-.055),p['legx']+.06)
            leg.append((float(x),y,float(z)))
        leg.append((leg[2][0],p['ankle']*.45,leg[2][2]+.075))
        for names,line,parent in [([f'UpperArm_{side}',f'LowerArm_{side}',f'Hand_{side}'],arm,'Spine'),([f'UpperLeg_{side}',f'LowerLeg_{side}',f'Foot_{side}'],leg,'Hips')]:
            for i,name in enumerate(names):
                pts[name]=line[i];parents[name]=names[i-1] if i else parent
        arms[side],legs[side]=np.array(arm),np.array(leg)
    # Tails and rigid attached accessories follow the pelvis as a separate region.
    if spec.get('tail'):
        pts['Tail']=tuple(spec['tail']);parents['Tail']='Hips'
    rest,bones={},[]
    for name,point in pts.items():
        parent=parents[name]
        world=Vector(point)*height
        origin=rest[parent].inverted()@world if parent else world
        rest[name]=Matrix.Translation(world)
        bones.append(dict(name=name,parent=parent,origin=list(origin),rotation=[0,0,0]))
    return p,pts,parents,rest,bones,arms,legs


def solver_bones(pts,parents,arms,legs,height):
    aliases={'Root':'root','Hips':'pelvis','Spine':'spine_01','Neck':'neck_01','Head':'head','Tail':'tail_01'}
    if 'Skirt' in pts: aliases['Skirt']='skirt'
    for side in ['L','R']:
        for semantic,solver in [('UpperArm','upperarm'),('LowerArm','lowerarm'),('Hand','hand'),('UpperLeg','thigh'),('LowerLeg','calf'),('Foot','foot')]:
            aliases[f'{semantic}_{side}']=solver+'_'+side.lower()
    result=[dict(name=name,solver_name=aliases[name],parent=parents[name],world_position=list(Vector(point)*height)) for name,point in pts.items()]
    leaves={'Head':(0,.97,pts['Head'][2])}
    if 'Skirt' in pts: leaves['Skirt']=(pts['Skirt'][0],pts['Skirt'][1]-.25,pts['Skirt'][2])
    for side in ['L','R']:
        leaves['Hand_'+side]=arms[side][3];leaves['Foot_'+side]=legs[side][3]
    if 'Tail' in pts:leaves['Tail']=(pts['Tail'][0],pts['Tail'][1],pts['Tail'][2]-.13)
    for parent,point in leaves.items():
        result.append(dict(name=parent+'_leaf',solver_name=aliases[parent]+'_leaf',parent=parent,world_position=list(Vector(point)*height)))
    return result


def constrain_regions(obj,xyz,weight,bones,p,pts,arms,legs,spec):
    """Keep Mesh2Motion's joint blends inside connected anatomical regions.

    Surface distance separates a hand from a nearby coat even when they are
    close in space. Three region solves suffice; joint weights remain M2M's.
    """
    index={b['name']:i for i,b in enumerate(bones)}
    edges=np.array([list(e.vertices) for e in obj.data.edges])
    graph=[[] for _ in xyz]
    for a,b in edges:
        length=float(np.linalg.norm(xyz[a]-xyz[b]))
        graph[a].append((int(b),length));graph[b].append((int(a),length))
    seeds=[]
    torso=set()
    eligible=np.flatnonzero(np.abs(xyz[:,0])<.045)
    for y in np.linspace(p['hip']-.025,p['neck']-.035,6):
        for z in [-.07,.07]:
            ds=np.sum((xyz[eligible]-np.array([0,y,z]))**2,axis=1)
            torso.update(eligible[np.argsort(ds)[:6]].tolist())
    # Lower legs are body-region anchors too, so all lower-body surfaces stay
    # separated from dangling fingers near a thigh or pocket.
    torso.update(np.flatnonzero((xyz[:,1]<p['knee'])&(np.abs(xyz[:,0])<.17)).tolist())
    seeds.append(torso)
    for side,sign in [('L',-1),('R',1)]:
        arm=set()
        eligible=np.flatnonzero((sign*xyz[:,0]>p['sx'])&(xyz[:,1]<p['shoulder']-.07))
        for point in arms[side][2:]:
            ds=np.sum((xyz[eligible]-point)**2,axis=1)
            arm.update(eligible[np.argsort(ds)[:12]].tolist())
        seeds.append(arm)
    # Find the highest horizontal cut that separates both hands/forearms from
    # the lower torso. Those connected components provide exact cloth anchors;
    # they cannot accidentally seed a cardigan hem as an elbow surface.
    split_height=None
    for cut in np.arange(p['shoulder']-.045,p['wrist']+.025,-.015):
        allowed=xyz[:,1]<cut
        seen=np.zeros(len(xyz),bool)
        groups=[]
        for start in np.flatnonzero(allowed):
            if seen[start]:continue
            stack=[int(start)];seen[start]=True;group=[]
            while stack:
                v=stack.pop();group.append(v)
                for other,_ in graph[v]:
                    if allowed[other] and not seen[other]:seen[other]=True;stack.append(other)
            if len(group)>40:groups.append(np.array(group,dtype=np.int32))
        body_candidates=[g for g in groups if abs(float(xyz[g,0].mean()))<.055 and xyz[g,1].min()<p['knee']]
        left=[g for g in groups if xyz[g,0].mean()<-p['sx'] and xyz[g,1].min()>p['wrist']-.15 and xyz[g,1].max()>p['wrist']+.025]
        right=[g for g in groups if xyz[g,0].mean()>p['sx'] and xyz[g,1].min()>p['wrist']-.15 and xyz[g,1].max()>p['wrist']+.025]
        if body_candidates and left and right:
            main=max(body_candidates,key=len)
            arm_l=max(left,key=len);arm_r=max(right,key=len)
            seeds=[set(g[xyz[g,1]<cut-.01].tolist()) for g in [main,arm_l,arm_r]]
            split_height=float(cut)
            break
    obj['region_split_height']=-1. if split_height is None else split_height
    distances=np.full((len(xyz),3),np.inf)
    for col,anchors in enumerate(seeds):
        dist=distances[:,col];queue=[]
        for v in anchors:dist[v]=0;heapq.heappush(queue,(0.,v))
        while queue:
            d,v=heapq.heappop(queue)
            if d>dist[v]+1e-9:continue
            for other,length in graph[v]:
                nd=d+length
                if nd<dist[other]-1e-9:dist[other]=nd;heapq.heappush(queue,(nd,other))
    valid=np.isfinite(distances.min(axis=1))
    region=np.zeros_like(distances);region[:,0]=1
    region[valid]=np.exp(-(distances[valid]-distances[valid].min(axis=1)[:,None])/float(spec.get('region_blend_width',.025)))
    region/=region.sum(axis=1)[:,None]
    if 'region_blend_width' in spec:
        # A broader shoulder transition should not dilute the unambiguous
        # separate hand and torso components below the anatomical split.
        for column,anchors in enumerate(seeds):
            selected=np.array(sorted(anchors),dtype=np.int32)
            region[selected]=0;region[selected,column]=1
    out=np.zeros_like(weight)
    arm_cols=[index[n] for n in index if n.startswith(('UpperArm','LowerArm','Hand'))]
    body=weight.copy();body[:,arm_cols]=0
    y=xyz[:,1]
    torso_mix=base.smooth(p['hip']-.02,p['spine']+.01,y)
    body_target=np.zeros_like(weight)
    body_target[:,index['Hips']]=1-torso_mix;body_target[:,index['Spine']]=torso_mix
    # The solver's pelvis heuristic is based on realistic human proportions.
    # Explicit torso constraints cover these short, broad cartoon bodies.
    amount=base.smooth(p['hip']-.035,p['hip']+.025,y)*(1-base.smooth(p['neck']-.03,p['neck']+.025,y))
    body=body*(1-amount[:,None])+body_target*amount[:,None]
    missing=body.sum(axis=1)<1e-5
    body[missing]=body_target[missing]
    body/=np.maximum(body.sum(axis=1),1e-9)[:,None]
    out=body*region[:,0,None]
    for col,side in enumerate(['L','R'],1):
        names=[f'UpperArm_{side}',f'LowerArm_{side}',f'Hand_{side}']
        columns=[index[n] for n in names]
        part=weight[:,columns].copy()
        missing=part.sum(axis=1)<.05
        _,fallback=base.chain_weights(xyz,arms[side],.04)
        part[missing]=fallback[missing]
        part/=np.maximum(part.sum(axis=1),1e-9)[:,None]
        # Surface distance alone can alternate the two joint weights on a
        # densely tessellated cuff. A small continuous anatomical prior removes
        # that high-frequency variation while retaining the solver's blends.
        prior=float(spec.get('arm_joint_prior',.25))
        part=(1-prior)*part+prior*fallback
        out[:,columns]+=part*region[:,col,None]
    if spec.get('apron_color')=='green':
        rgb,_=base.texture_data(obj)
        apron=(rgb[:,1]>rgb[:,0]*1.08)&(rgb[:,1]>rgb[:,2]*1.35)&(y>p['hip']-.08)&(y<p['shoulder']+.035)&(np.abs(xyz[:,0])<.25)
        out[apron]=body_target[apron]
    return out


def refine_continuous_weights(obj,xyz,weight,bones,p,pts,legs,spec):
    """Continuous neck/hip transitions and isolated appendages for real poses.

    Hard height cuts can pass weight validation but stretch a collar when the
    head counter-rotates. Cross-leg leakage also stretches short tails and the
    middle of a pair of shorts. Correct the regions before adjacency smoothing.
    """
    index={bone['name']:i for i,bone in enumerate(bones)}
    y=xyz[:,1];x=xyz[:,0]
    head_start=float(spec.get('head_blend_start',p['neck']-.025))
    head_end=float(spec.get('head_blend_end',p['head']+.01))
    head_amount=base.smooth(head_start,head_end,y)
    head_columns=[index['Head'],index['Neck']]
    previous_head=weight[:,head_columns].sum(axis=1)
    weight[:,head_columns]=0
    weight[:,index['Spine']]+=previous_head
    weight*=1-head_amount[:,None]
    weight[:,index['Head']]+=head_amount

    leg_columns=[index[name] for name in index if name.startswith(('UpperLeg','LowerLeg','Foot'))]
    leg_amount=weight[:,leg_columns].sum(axis=1)
    hip_lock=base.smooth(p['hip']-.065,p['hip']+.005,y)
    crotch=(1-base.smooth(.018,.075,np.abs(x)))*base.smooth(p['knee']+.015,p['hip']-.035,y)
    pelvis=np.maximum(hip_lock,crotch)
    weight[:,index['Hips']]+=leg_amount*pelvis
    leg_amount*=1-pelvis
    right=base.smooth(-.025,.025,x)
    for side,fraction in [('L',1-right),('R',right)]:
        columns=[index[name+'_'+side] for name in ['UpperLeg','LowerLeg','Foot']]
        part=weight[:,columns].copy()
        missing=part.sum(axis=1)<1e-5
        _,continuous=base.chain_weights(xyz,legs[side],.045)
        part[missing]=continuous[missing]
        part/=np.maximum(part.sum(axis=1),1e-9)[:,None]
        part=.5*part+.5*continuous
        weight[:,columns]=part*(leg_amount*fraction)[:,None]

    tail=np.zeros(len(xyz),bool)
    if 'Tail' in pts:
        if 'tail_bounds' in spec:
            xmin,xmax,ymin,ymax,zmin,zmax=spec['tail_bounds']
            tail=(x>xmin)&(x<xmax)&(y>ymin)&(y<ymax)&(xyz[:,2]>zmin)&(xyz[:,2]<zmax)
        else:
            tail=(xyz[:,2]<float(spec.get('tail_plane',-.13)))&(y<p['hip']+.14)
        weight[tail]=0;weight[tail,index['Tail']]=1

    edges=np.array([list(edge.vertices) for edge in obj.data.edges])
    a,b=edges[:,0],edges[:,1]
    edge_weight=1/(np.linalg.norm(xyz[a]-xyz[b],axis=1)+.002)
    degree=np.zeros(len(xyz),np.float32)
    np.add.at(degree,a,edge_weight);np.add.at(degree,b,edge_weight)
    # Keep the upper face rigid; allow the collar to blend over a real band.
    rigid_head=y>head_end+.025
    for _ in range(int(spec.get('weight_smoothing_iterations',32))):
        total=np.zeros_like(weight)
        np.add.at(total,a,weight[b]*edge_weight[:,None]);np.add.at(total,b,weight[a]*edge_weight[:,None])
        averaged=total/np.maximum(degree,1e-9)[:,None]
        weight[~rigid_head]=.55*weight[~rigid_head]+.45*averaged[~rigid_head]
    weight/=np.maximum(weight.sum(axis=1),1e-9)[:,None]
    obj['weight_refinement']='continuous-neck-hip-and-appendage-v2'
    return weight


def process(intake_id,spec,resident):
    started=time.time();ident=resident['resident_id'];height=float(spec.get('height',2.15))
    family='humanoid' if resident['type']=='human' else 'animal'
    folder=OUT/ident;folder.mkdir(parents=True,exist_ok=True)
    intake=OUT/'intake'/intake_id
    bpy.ops.wm.open_mainfile(filepath=str(intake/'prepared.blend'))
    obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    obj.name='Body';obj['character_id']=ident
    prepared_height=float(read(intake/'preparation.json')['height'])
    if abs(height-prepared_height)>1e-6:
        for vertex in obj.data.vertices: vertex.co*=height/prepared_height
    rotate=Matrix.Rotation(math.radians(float(spec.get('rotation_z',-90))),3,'Z')
    for vertex in obj.data.vertices:vertex.co=rotate@vertex.co
    obj.data.update()
    xyz=base.mesh_arrays(obj)/height
    p,pts,parents,rest,bones,arms,legs=fitted_layout(spec,xyz,height)
    obj.data.calc_loop_triangles()
    payload=dict(id=ident,positions=(xyz*height).reshape(-1).tolist(),triangles=[int(v) for f in obj.data.loop_triangles for v in f.vertices],bones=solver_bones(pts,parents,arms,legs,height),head_plane=(p['neck']+.025)*height)
    write(folder/'solver-input.json',payload)
    command=['node','--max-old-space-size=4096','--import',(ENGINE/'node_modules/tsx/dist/loader.mjs').as_uri(),str(ROOT/'scripts/mesh2motion_skin.mjs'),str(ENGINE),str(folder/'solver-input.json'),str(folder/'solver-output.json')]
    run=subprocess.run(command,cwd=str(ROOT),text=True,capture_output=True,encoding='utf-8')
    (folder/'mesh2motion.log').write_text(run.stdout+'\n'+run.stderr,encoding='utf-8')
    assert run.returncode==0,run.stderr
    result=read(folder/'solver-output.json')
    weight=np.zeros((len(xyz),len(bones)),np.float32)
    index={b['name']:i for i,b in enumerate(bones)}
    inds=np.array(result['indices']).reshape(-1,4);values=np.array(result['weights']).reshape(-1,4)
    for source,name in enumerate(result['bone_names']):
        if name in index:weight[:,index[name]]+=(values*(inds==source)).sum(axis=1)
        else:assert not np.any(values[inds==source]>1e-7),name
    raw=weight.copy()
    weight=constrain_regions(obj,xyz,weight,bones,p,pts,arms,legs,spec)
    weight=refine_continuous_weights(obj,xyz,weight,bones,p,pts,legs,spec)
    influences=int(spec.get('max_influences',4))
    weight=base.assign_weights(obj,bones,weight,max_influences=influences)
    # The source helper expects a three-segment dinosaur tail. These residents
    # have an independently weighted, single tail joint on a biped rig.
    core_pts={k:v for k,v in pts.items() if k!='Tail'}
    arm=base.make_armature(ident,core_pts,parents,rest,arms,legs,height)
    if 'Tail' in pts:
        bpy.context.view_layer.objects.active=arm
        bpy.ops.object.mode_set(mode='EDIT')
        bone=arm.data.edit_bones.new('Tail')
        bone.head=base.G2B@(Vector(pts['Tail'])*height)
        bone.tail=bone.head+Vector((0,.15*height,0))
        bone.parent=arm.data.edit_bones['Hips']
        bpy.ops.object.mode_set(mode='OBJECT')
    obj.parent=arm
    modifier=obj.modifiers.new('Mesh2Motion skin','ARMATURE');modifier.object=arm
    # A shoulder-height wave clears broad heads and avoids stretching sleeves
    # into an overhead pose. These same tracks are read by the runtime adapter.
    gesture=[]
    upper=float(spec.get('wave_upper_angle',65 if family=='humanoid' else 50))
    lower=float(spec.get('wave_lower_angle',65))
    for bone,peak in [('UpperArm_R',(-12,0,upper)),('LowerArm_R',(-12,0,lower)),('Hand_R',(0,0,0))]:
        keys=[]
        for t,amount in [(0,0),(.25,.25),(.65,1),(.92,1),(1.19,1),(1.46,1),(1.72,.65),(2.2,0)]:
            degrees=list(peak)
            if bone=='LowerArm_R' and t in [.92,1.46]:degrees[2]+=12
            q=base.Quaternion((0,0,1),math.radians(degrees[2]*amount))@base.Quaternion((1,0,0),math.radians(degrees[0]*amount))
            keys.append(dict(time=t,value=[q.x,q.y,q.z,q.w]))
        gesture.append(dict(bone=bone,keys=keys))
    reduced=[]
    for track in gesture:
        frames=[]
        for key in track['keys']:
            value=key['value'];q=base.Quaternion((value[3],*value[:3]))
            q=base.Quaternion((1,0,0,0)).slerp(q,.60)
            frames.append(dict(time=key['time'],value=[q.x,q.y,q.z,q.w]))
        reduced.append(dict(bone=track['bone'],keys=frames))
    photo=[];photo_reduced=[]
    photo_pose={'UpperArm_R':(-12,0,min(upper,45)), 'LowerArm_R':(-12,0,85 if family=='animal' else 75), 'Hand_R':(0,0,0), 'UpperArm_L':(-18,0,7), 'LowerArm_L':(-30,0,0), 'Hand_L':(0,0,0), 'Head':(0,0,-5)}
    for bone,degrees in photo_pose.items():
        regular=[];gentle=[]
        for t,amount in [(0,0),(.55,1),(1.9,1),(2.4,0)]:
            q=base.Quaternion((0,0,1),math.radians(degrees[2]*amount))@base.Quaternion((1,0,0),math.radians(degrees[0]*amount))
            regular.append(dict(time=t,value=[q.x,q.y,q.z,q.w]))
            g=base.Quaternion((1,0,0,0)).slerp(q,.6)
            gentle.append(dict(time=t,value=[g.x,g.y,g.z,g.w]))
        photo.append(dict(bone=bone,keys=regular));photo_reduced.append(dict(bone=bone,keys=gentle))
    # The generic place clip reaches 108 degrees at the right shoulder while
    # the torso is already bent. Fit its reach to these short clothed bodies;
    # keep the original contact/recovery times and lower-arm articulation.
    place=[];place_reduced=[]
    for track in base.CONTRACT['families'][family]['clips']['place_item']['tracks']:
        if track['bone']!='UpperArm_R' or track['type']!='rotation':continue
        regular=[];gentle=[]
        for key in track['keys']:
            x,y,z,w=key['value']
            q=base.Quaternion((1,0,0,0)).slerp(base.Quaternion((w,x,y,z)),.74)
            regular.append(dict(time=key['time'],value=[q.x,q.y,q.z,q.w]))
            g=base.Quaternion((1,0,0,0)).slerp(q,.6)
            gentle.append(dict(time=key['time'],value=[g.x,g.y,g.z,g.w]))
        place.append(dict(bone=track['bone'],keys=regular));place_reduced.append(dict(bone=track['bone'],keys=gentle))
    base.GESTURES.setdefault('characters',{})[ident]={'normal':{'greet_wave':gesture,'pose_photo':photo,'place_item':place},'reduced':{'greet_wave':reduced,'pose_photo':photo_reduced,'place_item':place_reduced}}
    write(folder/'gestures.json',base.GESTURES['characters'][ident])
    actions=base.make_actions(arm,bones,rest,family)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);arm.select_set(True)
    bpy.context.view_layer.objects.active=arm
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'rigged.blend'))
    bpy.ops.export_scene.gltf(filepath=str(folder/'character.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_yup=True,export_apply=False,export_extras=True,export_materials='EXPORT',export_all_influences=influences>4)
    prep=read(intake/'preparation.json')
    sockets={side:list(rest['LowerArm_'+side].inverted()@(Vector(arms[side][2:4].mean(axis=0))*height+Vector((0,0,.035)))) for side in ['L','R']}
    row=dict(id=ident,intake_id=intake_id,revision='tripo-character-v1',family=family,height=height,bones=bones,
        hand_sockets=sockets,source=prep['source'],source_sha256=prep['source_sha256'],source_triangles=prep['source_triangles'],triangles=prep['triangles'],
        editable_source=(folder/'rigged.blend').relative_to(ROOT).as_posix(),export_glb=(folder/'character.glb').relative_to(ROOT).as_posix(),
        weight_method=f'Unmodified Mesh2Motion solver; fitted semantic biped, connected-surface body/arm constraints, continuous collar/hip transitions, cross-leg filtering, isolated appendages and weighted adjacency smoothing; up to {influences} normalized influences',
        weight_refinement='continuous-neck-hip-and-appendage-v2',joint_fitting='opposing-surface-quantile-midpoint',
        rigging_provider=dict(provider='Mesh2Motion',engine_commit=result['engine_commit'],core_solver_modified=False,adapter='scripts/mesh2motion_skin.mjs',coordinate_fit=spec),
        vertices=len(weight),unweighted_vertices=int(np.count_nonzero(weight.sum(axis=1)<1e-6)),weight_sum_max_error=float(np.max(np.abs(weight.sum(axis=1)-1))),
        blended_vertices=int(np.count_nonzero((weight>1e-4).sum(axis=1)>1)),raw_solver_blended_vertices=int(np.count_nonzero((raw>1e-4).sum(axis=1)>1)),
        bone_vertex_counts={b['name']:int(np.count_nonzero(weight[:,i]>1e-4)) for i,b in enumerate(bones)},actions=actions,
        region_split_height=float(obj.get('region_split_height',-1.)),
        room_id=resident.get('room_id',''),name_zh=resident['name_zh'],identity_reference=resident.get('identity_reference','assets/tripo/building_residents_v01/'+resident.get('path','')),
        status='rigged_pending_engine_validation',elapsed_seconds=round(time.time()-started,2))
    write(folder/'rig.json',row)
    write(folder/'fitted-joints.json',dict(parameters=p,points=pts,arms={k:v.tolist() for k,v in arms.items()},legs={k:v.tolist() for k,v in legs.items()}))
    camera=preparation.setup_render(height)
    bpy.context.scene.render.resolution_x=512;bpy.context.scene.render.resolution_y=512
    camera.data.ortho_scale=height*1.4
    camera.location=(height*.65,-height*2.5,height*.7)
    camera.rotation_euler=(Vector((0,0,height*.50))-camera.location).to_track_quat('-Z','Y').to_euler()
    for name,t in [('idle',0),('walk',.28),('greet_wave',.92)]:
        base.pose_at(arm,bones,rest,family,base.CONTRACT['families'][family]['clips'][name],t)
        bpy.context.scene.render.filepath=str(folder/(name+'_rigged.png'))
        bpy.ops.render.render(write_still=True)
    print('RESIDENT_RIG_DONE '+ident,flush=True)


if __name__=='__main__':
    selected=set(sys.argv[sys.argv.index('--')+1:]) if '--' in sys.argv else set()
    catalog={r['resident_id']:r for r in read(ROOT/'assets/tripo/building_residents_v01/manifest.json')['assets']}
    specs=read(OUT/'fitting.json')['models']
    for intake_id,spec in specs.items():
        if selected and spec['resident_id'] not in selected:continue
        process(intake_id,spec,catalog[spec['resident_id']])
