"""Species-specific Mesh2Motion rigs for the eight quadrupeds, two birds and fish.

Animations retain the gameplay's action names, while their body motions follow
the animal anatomy. Carry/reach interactions are deliberately not offered.
"""
from pathlib import Path
import json, math, os, subprocess, sys, time
import bpy
import numpy as np
from mathutils import Matrix, Vector, Quaternion
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import rig_tripo_characters as base
import prepare_tripo_characters as prep
OUT=ROOT/'assets/characters/textbook_expansion_v1'
ENGINE=Path(os.environ.get('MESH2MOTION_ENGINE','F:/VideoMaker/experiments/mesh2motion-robots-20261027/engine'))
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

PARAMS={
 'P13':dict(hip=.50,body=.56,neck=.68,head=.76,front=.24,rear=-.30,knee=.25,headz=.30,tail=[(0,.49,-.41),(0,.67,-.52),(0,.86,-.48)],tail_cut=-.35),
 'P14':dict(hip=.43,body=.49,neck=.62,head=.69,front=.23,rear=-.28,knee=.22,headz=.31,tail=[(0,.44,-.39),(0,.69,-.48),(0,.88,-.46)],tail_cut=-.35),
 'P15':dict(hip=.48,body=.58,neck=.67,head=.75,front=.23,rear=-.30,knee=.23,headz=.28,tail=[(0,.48,-.45),(0,.37,-.53),(0,.30,-.55)],tail_cut=-.45,trunk=True),
 'P17':dict(hip=.39,body=.50,neck=.66,head=.73,front=.23,rear=-.26,knee=.21,headz=.22,tail=[(0,.40,-.37),(0,.68,-.50),(0,.84,-.39)],tail_cut=-.34),
 'P18':dict(hip=.24,body=.35,neck=.43,head=.54,front=.17,rear=-.10,knee=.12,headz=.11,ears=True),
 'P19':dict(hip=.39,body=.44,neck=.57,head=.65,front=.23,rear=-.28,knee=.18,headz=.25,tail=[(0,.36,-.36),(0,.54,-.52),(0,.82,-.35)],tail_cut=-.34),
 'P21':dict(hip=.56,body=.60,neck=.77,head=.84,front=.30,rear=-.33,knee=.28,headz=.40,tail=[(0,.56,-.49),(0,.49,-.68),(0,.60,-.89)],tail_cut=-.48),
 'P22':dict(hip=.41,body=.48,neck=.62,head=.71,front=.23,rear=-.27,knee=.20,headz=.29,tail=[(0,.43,-.37),(0,.57,-.50),(0,.73,-.43)],tail_cut=-.33),
}

def layout(row,xyz,height):
    kind=row['rig_type'];spec=dict(PARAMS.get(row['selection_code'],{}))
    overrides=read(OUT/'creature-fitting.json') if (OUT/'creature-fitting.json').exists() else {}
    spec.update(overrides.get(row['id'],{}))
    pts={};parents={};ends={};chains={}
    def add(name,parent,point,end=None):
        pts[name]=tuple(float(v) for v in point);parents[name]=parent
        if end is not None:ends[name]=tuple(float(v) for v in end)
    def chain(names,parent,points):
        for i,name in enumerate(names):add(name,parent if i==0 else names[i-1],points[i],points[i+1])
        chains[names[0]]=(names,np.array(points))
    add('Root',None,(0,0,0))
    if kind=='quadruped':
        p=spec
        add('Hips','Root',(0,p['hip'],p['rear']*.55))
        add('Spine','Hips',(0,p['body'],p['front']*.55))
        add('Neck','Spine',(0,p['neck'],p['headz']*.8))
        add('Head','Neck',(0,p['head'],p['headz']),(0,p['head']+.12,p['headz']+.035))
        for side,sign in [('L',-1),('R',1)]:
            for front in [True,False]:
                z0=p['front'] if front else p['rear'];top=p['body']-.045 if front else p['hip']-.02
                # Actual paw surface sets the x/z centre, independent of mesh density.
                mask=(xyz[:,0]*sign>.035)&(xyz[:,1]<.09)&(np.abs(xyz[:,2]-z0)<.22)
                candidates=xyz[mask]
                x,z=sign*.12,z0
                if len(candidates)>8:x,z=np.quantile(candidates[:,[0,2]],[.08,.92],axis=0).mean(axis=0)
                points=[(x,top,z),(x,p['knee'],z-.015 if front else z+.02),(x,.045,z),(x,.025,z+.085)]
                names=[n+'_'+side for n in (['UpperArm','LowerArm','Hand'] if front else ['UpperLeg','LowerLeg','Foot'])]
                chain(names,'Spine' if front else 'Hips',points)
        if p.get('tail'):chain(['Tail','Tail_02','Tail_03'],'Hips',p['tail']+[tuple(np.array(p['tail'][-1])+[0,.03,-.05])])
        if p.get('ears'):
            for side,sign in [('L',-1),('R',1)]:add('Ear_'+side,'Head',(sign*.09,.69,.075),(sign*.12,.95,.035))
        if p.get('trunk'):
            chain(['Trunk','Trunk_02','Trunk_03'],'Head',[(0,.68,.35),(0,.53,.43),(0,.36,.44),(0,.33,.49)])
            for side,sign in [('L',-1),('R',1)]:add('Ear_'+side,'Head',(sign*.20,.75,.18),(sign*.38,.77,.14))
    elif kind=='bird':
        spec.update(dict(hip=.22,body=.43,neck=.64,head=.72))
        add('Hips','Root',(0,.22,-.02));add('Spine','Hips',(0,.43,0));add('Neck','Spine',(0,.64,.04));add('Head','Neck',(0,.72,.07),(0,.87,.11))
        for side,sign in [('L',-1),('R',1)]:
            chain(['UpperLeg_'+side,'LowerLeg_'+side,'Foot_'+side],'Hips',[(sign*.10,.23,.02),(sign*.10,.13,.01),(sign*.10,.045,.04),(sign*.10,.025,.17)])
            chain(['Wing_'+side,'WingTip_'+side],'Spine',[(sign*.14,.56,-.02),(sign*.22,.36,-.12),(sign*.24,.30,-.23)])
        zmin=float(xyz[:,2].min());chain(['Tail','Tail_02'],'Hips',[(0,.30,-.12),(0,.30,zmin*.68),(0,.31,zmin)])
    else:
        zmin,zmax=float(xyz[:,2].min()),float(xyz[:,2].max())
        spec.update(dict(zmin=zmin,zmax=zmax))
        add('Hips','Root',(0,.48,0));add('Spine','Hips',(0,.48,zmax*.28));add('Head','Spine',(0,.48,zmax*.65),(0,.48,zmax*.95))
        chain(['Tail','Tail_02','TailFin'],'Hips',[(0,.48,zmin*.30),(0,.48,zmin*.60),(0,.48,zmin*.82),(0,.48,zmin)])
        for side,sign in [('L',-1),('R',1)]:add('Fin_'+side,'Spine',(sign*.10,.37,zmax*.1),(sign*.27,.32,0))
        add('Dorsal','Hips',(0,.72,-.03),(0,.92,-.04))
    bones=[];rest={}
    for name,point in pts.items():
        parent=parents[name];world=Vector(point)*height
        origin=world-Vector(pts[parent])*height if parent else world
        bones.append(dict(name=name,parent=parent,origin=list(origin),rotation=[0,0,0]))
        rest[name]=Matrix.Translation(world)
    return spec,pts,parents,ends,chains,bones,rest

def solve(obj,xyz,height,row,pts,parents,ends,bones,folder):
    aliases={'Root':'root','Hips':'pelvis','Spine':'spine_01','Neck':'neck_01','Head':'head'}
    if row['rig_type'] in ['quadruped','bird']: aliases['Hips']='hips'
    payload=[]
    for name,point in pts.items():
        payload.append(dict(name=name,solver_name=aliases.get(name,name.lower()),parent=parents[name],world_position=list(Vector(point)*height)))
    parent_names=set(parents.values())
    for name in pts:
        if name not in parent_names:
            point=ends.get(name,tuple(np.array(pts[name])+[0,.06,0]))
            payload.append(dict(name=name+'_leaf',solver_name=name.lower()+'_leaf',parent=name,world_position=list(Vector(point)*height)))
    obj.data.calc_loop_triangles()
    data=dict(id=row['id'],positions=(xyz*height).reshape(-1).tolist(),triangles=[int(v) for face in obj.data.loop_triangles for v in face.vertices],
        bones=payload,skeleton_type={'quadruped':'fox','bird':'bird','fish':'fish'}[row['rig_type']],head_correction=False,template='fitted '+row['rig_type']+' semantic rig with independent appendages')
    write(folder/'solver-input.json',data)
    command=['node','--max-old-space-size=4096','--import',(ENGINE/'node_modules/tsx/dist/loader.mjs').as_uri(),str(ROOT/'scripts/mesh2motion_skin.mjs'),str(ENGINE),str(folder/'solver-input.json'),str(folder/'solver-output.json')]
    run=subprocess.run(command,capture_output=True,text=True,encoding='utf-8',cwd=ROOT)
    (folder/'mesh2motion.log').write_text(run.stdout+'\n'+run.stderr,encoding='utf-8')
    assert run.returncode==0,run.stderr
    result=read(folder/'solver-output.json');raw=np.zeros((len(xyz),len(bones)),np.float32)
    indices=np.array(result['indices']).reshape(-1,4);values=np.array(result['weights']).reshape(-1,4);index={b['name']:i for i,b in enumerate(bones)}
    for source,name in enumerate(result['bone_names']):
        if name in index:raw[:,index[name]]+=(values*(indices==source)).sum(axis=1)
        else:assert not np.any(values[indices==source]>1e-7),name
    return raw,result

def refine(obj,xyz,raw,row,p,pts,chains,bones):
    kind=row['rig_type'];index={b['name']:i for i,b in enumerate(bones)};x,y,z=xyz.T
    weight=np.zeros_like(raw)
    def set_chain(names,points,amount):
        _,blend=base.chain_weights(xyz,np.array(points),.045)
        for i,name in enumerate(names):weight[:,index[name]]+=blend[:,i]*amount
    if kind=='quadruped':
        along=base.smooth(p['rear']*.6,p['front']*.75,z)
        weight[:,index['Hips']]=1-along;weight[:,index['Spine']]=along
        head=base.smooth(p['neck']-.12,p['head']-.015,y)*base.smooth(p['headz']-.24,p['headz']-.06,z)
        weight*=1-head[:,None];weight[:,index['Head']]+=head
        left=1-base.smooth(-.025,.025,x);front=base.smooth(-.10,.10,z)
        lower=(1-base.smooth(p['hip']-.12,p['body']-.025,y))*base.smooth(.025,.095,np.abs(x))
        weight*=1-lower[:,None]
        for side,sideamount in [('L',left),('R',1-left)]:
            for fore,amount in [(True,front),(False,1-front)]:
                names,line=chains[('UpperArm_' if fore else 'UpperLeg_')+side]
                set_chain(names,line,lower*sideamount*amount)
        if p.get('tail'):
            amount=(1-base.smooth(p.get('tail_cut',-.32),p.get('tail_cut',-.32)+.055,z))*base.smooth(p['hip']-.16,p['hip']-.06,y)
            weight*=1-amount[:,None];names,line=chains['Tail'];set_chain(names,line,amount)
        if p.get('ears'):
            amount=base.smooth(.70,.76,y)
            weight*=1-amount[:,None]
            weight[:,index['Ear_L']]+=amount*left;weight[:,index['Ear_R']]+=amount*(1-left)
        if p.get('trunk'):
            amount=base.smooth(.30,.39,z)*(1-base.smooth(.63,.72,y))
            weight*=1-amount[:,None];names,line=chains['Trunk'];set_chain(names,line,amount)
            amount=base.smooth(.21,.31,np.abs(x))*base.smooth(.53,.64,y)
            weight*=1-amount[:,None]
            weight[:,index['Ear_L']]+=amount*left;weight[:,index['Ear_R']]+=amount*(1-left)
    elif kind=='bird':
        head=base.smooth(.58,.72,y);weight[:,index['Spine']]=1-head;weight[:,index['Head']]=head
        amount=1-base.smooth(.16,.28,y);weight*=1-amount[:,None]
        for side,sign in [('L',-1),('R',1)]:
            sided=base.smooth(-.025,.025,x*sign);names,line=chains['UpperLeg_'+side];set_chain(names,line,amount*sided)
        amount=base.smooth(.14,.23,np.abs(x))*base.smooth(.24,.35,y)*(1-base.smooth(.57,.66,y))
        weight*=1-amount[:,None]
        for side,sign in [('L',-1),('R',1)]:
            names,line=chains['Wing_'+side];set_chain(names,line,amount*base.smooth(-.025,.025,x*sign))
        amount=1-base.smooth(-.25,-.14,z);weight*=1-amount[:,None]
        names,line=chains['Tail'];set_chain(names,line,amount)
    else:
        head=base.smooth(p['zmax']*.20,p['zmax']*.6,z);weight[:,index['Hips']]=1-head;weight[:,index['Head']]=head
        amount=1-base.smooth(p['zmin']*.48,p['zmin']*.20,z);weight*=1-amount[:,None]
        names,line=chains['Tail'];set_chain(names,line,amount)
        amount=base.smooth(.12,.22,np.abs(x))*(1-base.smooth(.42,.52,y))
        weight*=1-amount[:,None]
        for side,sign in [('L',-1),('R',1)]:weight[:,index['Fin_'+side]]+=amount*base.smooth(-.025,.025,x*sign)
    # Preserve the solver's local blends only inside the anatomically supported
    # region. Prevent nearby opposite feet/tails from cross-influencing a joint.
    supported=raw*(weight>.012)
    supported/=np.maximum(supported.sum(axis=1),1e-9)[:,None]
    valid=supported.sum(axis=1)>.9
    weight[valid]=.7*weight[valid]+.3*supported[valid]
    edges=np.array([list(e.vertices) for e in obj.data.edges]);a,b=edges.T
    ew=1/(np.linalg.norm(xyz[a]-xyz[b],axis=1)+.002)
    degree=np.zeros(len(xyz));np.add.at(degree,a,ew);np.add.at(degree,b,ew)
    for _ in range(32):
        total=np.zeros_like(weight);np.add.at(total,a,weight[b]*ew[:,None]);np.add.at(total,b,weight[a]*ew[:,None])
        weight=.60*weight+.40*total/np.maximum(degree,1e-9)[:,None]
    weight/=np.maximum(weight.sum(axis=1),1e-9)[:,None]
    return weight

def armature(ident,pts,parents,ends,height):
    data=bpy.data.armatures.new(ident+'_Rig');arm=bpy.data.objects.new('SemanticRig',data)
    bpy.context.scene.collection.objects.link(arm);bpy.context.view_layer.objects.active=arm;arm.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name,point in pts.items():
        bone=data.edit_bones.new(name);bone.head=base.G2B@(Vector(point)*height)
        bone.tail=base.G2B@(Vector(ends.get(name,tuple(np.array(point)+[0,.08,0])))*height)
        if parents[name]:bone.parent=data.edit_bones[parents[name]]
        bone.use_deform=name!='Root'
    bpy.ops.object.mode_set(mode='OBJECT');return arm

def clips(row,bones,rest):
    kind=row['rig_type'];allclips={}
    durations={'idle':3.2,'walk':1.12,'greet_wave':2.2,'listen_nod':1.8,'talk_gesture':2.2,'pose_photo':2.4}
    for reduced in [False,True]:
        result={};gentle=.6 if reduced else 1.
        for action,duration in durations.items():
            count=round(duration*30);tracks={b['name']:dict(bone=b['name'],type='rotation',keys=[]) for b in bones}
            pos=dict(bone='Hips',type='position',keys=[])
            for frame in range(count+1):
                t=duration*frame/count;cycle=2*math.pi*t/duration
                envelope=math.sin(math.pi*t/duration)**2
                angles={name:[0.,0.,0.] for name in tracks}
                if action=='walk' and kind=='quadruped':
                    for side,sign in [('L',1),('R',-1)]:
                        fore=math.sin(cycle)*sign;hind=-fore
                        for prefix,swing in [('Arm',fore),('Leg',hind)]:
                            angles['Upper'+prefix+'_'+side][0]=-swing*13
                            angles['Lower'+prefix+'_'+side][0]=max(0,swing)*19
                            angles[('Hand_' if prefix=='Arm' else 'Foot_')+side][0]=swing*13-max(0,swing)*19
                elif action=='walk' and kind=='bird':
                    for side,sign in [('L',1),('R',-1)]:
                        swing=math.sin(cycle)*sign
                        angles['UpperLeg_'+side][0]=-swing*12;angles['LowerLeg_'+side][0]=max(0,swing)*16
                        angles['Foot_'+side][0]=swing*12-max(0,swing)*16
                if kind=='fish':
                    amplitude=12 if action=='walk' else 5 if action=='idle' else 8
                    for i,name in enumerate(['Tail','Tail_02','TailFin']):angles[name][1]=math.sin(cycle-i*.65)*amplitude
                    for side,sign in [('L',-1),('R',1)]:angles['Fin_'+side][2]=math.sin(cycle)*sign*8
                elif 'Tail' in angles:
                    angles['Tail'][1]=math.sin(cycle*(2 if action=='greet_wave' else 1))*(10 if action=='greet_wave' else 3)
                if action in ['greet_wave','talk_gesture','pose_photo']:
                    angles['Head'][2]=envelope*(5 if action=='pose_photo' else math.sin(cycle)*4)
                    angles['Head'][1]=envelope*math.sin(cycle)*4
                    if kind=='bird':
                        angles['Wing_L'][2]=-envelope*(12 if action=='greet_wave' else 5)
                        angles['Wing_R'][2]=envelope*(12 if action=='greet_wave' else 5)
                if action=='listen_nod':angles['Head'][0]=envelope*math.sin(cycle*2)*7
                if 'Trunk' in angles:angles['Trunk'][0]=math.sin(cycle)*4
                for side,sign in [('L',-1),('R',1)]:
                    if 'Ear_'+side in angles:angles['Ear_'+side][2]=math.sin(cycle)*sign*3
                for name,track in tracks.items():
                    values=[math.radians(v*gentle) for v in angles[name]]
                    q=Quaternion((0,0,1),values[2])@Quaternion((0,1,0),values[1])@Quaternion((1,0,0),values[0])
                    track['keys'].append(dict(time=t,value=[q.x,q.y,q.z,q.w]))
                origin=list(rest['Hips'].translation)
                if kind=='fish':origin[1]+=.02*gentle*math.sin(cycle)
                pos['keys'].append(dict(time=t,value=origin))
            result[action]=dict(length=duration,loop=action in ['idle','walk'],tracks=list(tracks.values())+[pos],semantic_spec=dict(contact_time=-1.))
        allclips['reduced' if reduced else 'normal']=result
    return allclips

def pose_at(arm,bones,rest,family,clip,t):
    values={(track['bone'],track['type']):base.track_value(track,t) for track in clip['tracks']}
    poses={};desired={}
    for bone in bones:
        name,parent=bone['name'],bone['parent']
        position=values.get((name,'position'),Vector(bone['origin']))
        rotation=values.get((name,'rotation'),Quaternion((1,0,0,0)))
        local=Matrix.Translation(position)@rotation.to_matrix().to_4x4()
        poses[name]=poses[parent]@local if parent else local
        target=base.G2B@poses[name]@rest[name].inverted()@base.B2G@arm.data.bones[name].matrix_local
        desired[name]=target
        bone_rest=arm.data.bones[name].matrix_local
        if parent:
            relative=arm.data.bones[parent].matrix_local.inverted()@bone_rest
            arm.pose.bones[name].matrix_basis=(desired[parent]@relative).inverted()@target
        else:arm.pose.bones[name].matrix_basis=bone_rest.inverted()@target
    bpy.context.view_layer.update()

base.pose_at=pose_at

def process(row):
    started=time.time();ident=row['id'];folder=OUT/ident;folder.mkdir(parents=True,exist_ok=True)
    intake=OUT/'intake'/row['intake_id'];source=read(intake/'preparation.json');height=float(row['height'])
    bpy.ops.wm.open_mainfile(filepath=str(intake/'prepared.blend'))
    obj=next(o for o in bpy.context.scene.objects if o.type=='MESH');obj.name='Body';obj['character_id']=ident
    rotation=Matrix.Rotation(math.radians(row['rotation_z']),3,'Z')
    for v in obj.data.vertices:v.co=rotation@v.co*(height/source['height'])
    obj.data.update();xyz=base.mesh_arrays(obj)/height
    spec,pts,parents,ends,chains,bones,rest=layout(row,xyz,height)
    raw,solver=solve(obj,xyz,height,row,pts,parents,ends,bones,folder)
    weight=base.assign_weights(obj,bones,refine(obj,xyz,raw,row,spec,pts,chains,bones))
    arm=armature(ident,pts,parents,ends,height);obj.parent=arm
    mod=obj.modifiers.new('Mesh2Motion skin','ARMATURE');mod.object=arm
    authored=clips(row,bones,rest);write(folder/'animation-clips.json',authored)
    # The shared exporter accepts canonical clip data without retargeting.
    family='expansion_'+row['rig_type']
    base.CONTRACT['families'][family]=dict(source_hips_height=float(rest['Hips'].translation.y),clips=authored['normal'])
    actions=base.make_actions(arm,bones,rest,family)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);arm.select_set(True);bpy.context.view_layer.objects.active=arm
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'rigged.blend'))
    bpy.ops.export_scene.gltf(filepath=str(folder/'character.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_yup=True,export_apply=False,export_extras=True)
    rowdata=dict(id=ident,intake_id=row['intake_id'],family='animal',rig_type=row['rig_type'],height=height,bones=bones,hand_sockets={},
        source=source['source'],source_sha256=source['source_sha256'],source_triangles=source['source_triangles'],triangles=source['triangles'],
        name_zh=row['name'],identity_reference=row['reference'],runtime_profile=dict(name=row['name'],kind='animal',source=row['reference']),
        editable_source=(folder/'rigged.blend').relative_to(ROOT).as_posix(),export_glb=(folder/'character.glb').relative_to(ROOT).as_posix(),
        rigging_provider=dict(provider='Mesh2Motion',engine_commit=solver['engine_commit'],core_solver_modified=False,template=solver['template']),
        weight_method='Unmodified Mesh2Motion '+row['rig_type']+' solve, explicit continuous anatomical regions, 30% supported solver blends and 32 adjacency smoothing passes; four normalized influences',
        weight_refinement='species-regions-v1',vertices=len(weight),unweighted_vertices=int(np.count_nonzero(weight.sum(axis=1)<1e-6)),
        weight_sum_max_error=float(np.max(np.abs(weight.sum(axis=1)-1))),actions=actions,allowed_actions=[a['name'] for a in actions],
        locomotion='swim' if row['rig_type']=='fish' else row['rig_type'],
        animation_clip_path='res://assets/characters/textbook_expansion_v1/'+ident+'/animation-clips.json',
        bounds=dict(min=(xyz.min(axis=0)*height).tolist(),max=(xyz.max(axis=0)*height).tolist()),status='rigged_pending_engine_validation',elapsed_seconds=round(time.time()-started,2))
    write(folder/'rig.json',rowdata);write(folder/'fitted-joints.json',dict(parameters=spec,points=pts))
    camera=prep.setup_render(max(obj.dimensions));bpy.context.scene.render.resolution_x=512;bpy.context.scene.render.resolution_y=512
    target=Vector((0,0,height*.48));camera.location=target+Vector((1,-2,.3))*max(obj.dimensions)
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    for action,t in [('idle',0),('walk',.28),('greet_wave',.92)]:
        base.pose_at(arm,bones,rest,family,authored['normal'][action],t)
        bpy.context.scene.render.filepath=str(folder/(action+'_rigged.png'));bpy.ops.render.render(write_still=True)
    print('EXPANSION_CREATURE_DONE '+ident,flush=True)

if __name__=='__main__':
    selected=set(sys.argv[sys.argv.index('--')+1:]) if '--' in sys.argv else set()
    for row in read(OUT/'catalog.json')['assets']:
        if row['rig_type'] not in ['quadruped','bird','fish']:continue
        if selected and row['id'] not in selected and row['intake_id'] not in selected:continue
        process(row)
