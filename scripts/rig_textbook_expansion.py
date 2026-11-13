"""Fit the new textbook characters with the existing Mesh2Motion pipeline.

Bipeds reuse the reviewed continuous-shoulder/hip constraints. Species rigs and
their authored clips are generated separately; raw downloads are never edited.
"""
from pathlib import Path
import json, sys, copy, heapq
from mathutils import Matrix, Vector
import numpy as np
import bpy
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import rig_building_residents as biped
OUT=ROOT/'assets/characters/textbook_expansion_v1'

def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

original_refine=biped.refine_continuous_weights
original_layout=biped.fitted_layout
def fitted_layout(spec,xyz,height):
    p,pts,parents,rest,bones,arms,legs=original_layout(spec,xyz,height)
    if 'skirt_bottom' in spec:
        pts['Skirt']=pts['Hips'];parents['Skirt']='Hips';rest['Skirt']=rest['Hips'].copy()
        bones.append(dict(name='Skirt',parent='Hips',origin=[0,0,0],rotation=[0,0,0]))
    return p,pts,parents,rest,bones,arms,legs
biped.fitted_layout=fitted_layout

def garment_mask(obj,xyz,top):
    """Use the actual open hem and separate feet as topological anchors."""
    edges=np.array([list(e.vertices) for e in obj.data.edges]);graph=[[] for _ in xyz]
    for a,b in edges:
        length=float(np.linalg.norm(xyz[a]-xyz[b]));graph[a].append((int(b),length));graph[b].append((int(a),length))
    anchors=None
    for cut in np.arange(.08,min(top-.05,.32),.01):
        allowed=xyz[:,1]<cut;seen=np.zeros(len(xyz),bool);groups=[]
        for start in np.flatnonzero(allowed):
            if seen[start]:continue
            stack=[int(start)];seen[start]=True;group=[]
            while stack:
                v=stack.pop();group.append(v)
                for other,_ in graph[v]:
                    if allowed[other] and not seen[other]:seen[other]=True;stack.append(other)
            if len(group)>30:groups.append(np.array(group))
        cloth=[g for g in groups if xyz[g,1].min()>.025 and xyz[g,0].min()<-.07 and xyz[g,0].max()>.07]
        feet=[g for g in groups if xyz[g,1].min()<.02]
        if cloth and len(feet)>=2:
            anchors=(np.concatenate(cloth),np.concatenate(feet))
    if anchors is None:return None,None
    distances=np.full((len(xyz),2),np.inf)
    for column,seeds in enumerate(anchors):
        queue=[];d=distances[:,column]
        for v in seeds:d[v]=0;heapq.heappush(queue,(0.,int(v)))
        while queue:
            distance,v=heapq.heappop(queue)
            if distance>d[v]+1e-9:continue
            for other,length in graph[v]:
                nd=distance+length
                if nd<d[other]-1e-9:d[other]=nd;heapq.heappush(queue,(nd,other))
    valid=np.isfinite(distances.min(axis=1));region=np.zeros(len(xyz))
    prob=np.exp(-(distances[valid]-distances[valid].min(axis=1)[:,None])/.035)
    region[valid]=prob[:,0]/np.maximum(prob.sum(axis=1),1e-9)
    return region,anchors

def refine(obj,xyz,weight,bones,p,pts,legs,spec):
    weight=original_refine(obj,xyz,weight,bones,p,pts,legs,spec)
    if spec.get('wide_sleeves'):
        # Hanging sleeve panels may be disconnected from the fingers below the
        # elbow. Seed every side component, including the cloth panel itself.
        graph=[[] for _ in xyz]
        for edge in obj.data.edges:
            a,b=edge.vertices;graph[a].append(b);graph[b].append(a)
        for cut in np.arange(p['shoulder']-.035,p['wrist']+.04,-.015):
            allowed=xyz[:,1]<cut;seen=np.zeros(len(xyz),bool);groups=[]
            for start in np.flatnonzero(allowed):
                if seen[start]:continue
                stack=[int(start)];seen[start]=1;group=[]
                while stack:
                    v=stack.pop();group.append(v)
                    for other in graph[v]:
                        if allowed[other] and not seen[other]:seen[other]=1;stack.append(other)
                if len(group)>30:groups.append(np.array(group))
            body=[g for g in groups if xyz[g,1].min()<p['hip'] and xyz[g,0].min()<-.07 and xyz[g,0].max()>.07]
            left=[g for g in groups if xyz[g,1].min()>.10 and xyz[g,0].mean()<-.12 and xyz[g,1].max()>cut-.04]
            right=[g for g in groups if xyz[g,1].min()>.10 and xyz[g,0].mean()>.12 and xyz[g,1].max()>cut-.04]
            if not body or not left or not right:continue
            index={bone['name']:i for i,bone in enumerate(bones)}
            for side,parts in [('L',left),('R',right)]:
                names=['UpperArm_'+side,'LowerArm_'+side,'Hand_'+side]
                line=np.array([pts[n] for n in names]+[(pts[names[-1]][0],p['wrist']-.065,pts[names[-1]][2])])
                _,arm= biped.base.chain_weights(xyz,line,.045)
                for group in parts:
                    amount=1-biped.base.smooth(cut-.06,cut,xyz[group,1])
                    weight[group]*=1-amount[:,None]
                    for i,name in enumerate(names):weight[group,index[name]]+=arm[group,i]*amount
            break
    if 'skirt_bottom' in spec:
        # Continuous long garments stay with the pelvis, with a soft waist
        # transition. Exposed feet retain their own leg/foot weights.
        index={bone['name']:i for i,bone in enumerate(bones)}
        low=float(spec['skirt_bottom']);top=float(spec.get('skirt_top',p['hip']))
        y=xyz[:,1]
        region,anchors=garment_mask(obj,xyz,top)
        amount=(biped.base.smooth(low-.045,low+.045,y) if region is None else region)*(1-biped.base.smooth(top,top+.06,y))
        radius=float(spec.get('skirt_radius',.23))
        amount*=1-biped.base.smooth(radius,radius+.04,np.abs(xyz[:,0]))
        arm_columns=[i for i,bone in enumerate(bones) if bone['name'].startswith(('UpperArm','LowerArm','Hand'))]
        amount*=1-biped.base.smooth(.015,.10,weight[:,arm_columns].sum(axis=1))
        weight*=1-amount[:,None]
        weight[:,index['Skirt']]+=amount
        # Reconcile the waist/sleeve boundaries after the garment assignment.
        edges=np.array([list(e.vertices) for e in obj.data.edges]);a,b=edges.T
        ew=1/(np.linalg.norm(xyz[a]-xyz[b],axis=1)+.002)
        degree=np.zeros(len(xyz));np.add.at(degree,a,ew);np.add.at(degree,b,ew)
        preserve=weight.copy()
        for _ in range(int(spec.get('garment_smoothing_iterations',64))):
            total=np.zeros_like(weight);np.add.at(total,a,weight[b]*ew[:,None]);np.add.at(total,b,weight[a]*ew[:,None])
            weight=.6*weight+.4*total/np.maximum(degree,1e-9)[:,None]
            if anchors is not None:
                weight[anchors[0]]=preserve[anchors[0]];weight[anchors[1]]=preserve[anchors[1]]
        weight/=np.maximum(weight.sum(axis=1),1e-9)[:,None]
        obj['garment_region_method']='connected hem/feet anchors' if anchors is not None else 'wide continuous hem band'
    return weight
biped.refine_continuous_weights=refine
biped.OUT=OUT
original_make_actions=biped.base.make_actions
def make_actions(arm,bones,rest,family):
    ident=arm.data.name.removesuffix('_Rig')
    spec=read(OUT/'fitting.json')['models'][ident]
    gestures=biped.base.GESTURES['characters'][ident]
    # Fit a reaching gesture to the actual sleeve/cuff range while preserving
    # the semantic action and its contact/recovery timing in GLB and Godot.
    for action,scale in spec.get('arm_action_scales',{}).items():
        for mode,gentle in [('normal',1.),('reduced',.6)]:
            tracks=[]
            for track in biped.base.CONTRACT['families'][family]['clips'][action]['tracks']:
                if track['type']!='rotation' or not track['bone'].startswith(('UpperArm','LowerArm','Hand')):continue
                keys=[]
                for key in track['keys']:
                    x,y,z,w=key['value']
                    q=biped.base.Quaternion((1,0,0,0)).slerp(biped.base.Quaternion((w,x,y,z)),float(scale)*gentle)
                    keys.append(dict(time=key['time'],value=[q.x,q.y,q.z,q.w]))
                tracks.append(dict(bone=track['bone'],keys=keys))
            gestures[mode][action]=tracks
    if any(b['name']=='Skirt' for b in bones):
        for action,clip in biped.base.CONTRACT['families'][family]['clips'].items():
            hips=next((t for t in clip['tracks'] if t['bone']=='Hips' and t['type']=='rotation'),None)
            frames=hips['keys'] if hips else [dict(time=0,value=[0,0,0,1]),dict(time=clip['length'],value=[0,0,0,1])]
            for mode,amount in [('normal',1.),('reduced',.6)]:
                keys=[]
                for key in frames:
                    x,y,z,w=key['value'];q=biped.base.Quaternion((1,0,0,0)).slerp(biped.base.Quaternion((w,-x,-y,-z)),amount)
                    keys.append(dict(time=key['time'],value=[q.x,q.y,q.z,q.w]))
                gestures[mode].setdefault(action,[]).append(dict(bone='Skirt',keys=keys))
    result=original_make_actions(arm,bones,rest,family)
    write(OUT/ident/'gestures.json',biped.base.GESTURES['characters'][ident])
    return result
biped.base.make_actions=make_actions

def main():
    selected=set(sys.argv[sys.argv.index('--')+1:]) if '--' in sys.argv else set()
    catalog=read(OUT/'catalog.json')['assets']
    fitting=read(OUT/'fitting.json')['models']
    for row in catalog:
        ident=row['id']
        if row['category']!='character' or row['rig_type'] not in ['biped','robot']:continue
        if selected and ident not in selected and row['intake_id'] not in selected:continue
        spec=fitting[ident]
        original_contract=biped.base.CONTRACT
        if 'stride_scale' in spec:
            biped.base.CONTRACT=copy.deepcopy(original_contract)
            for family in ['humanoid','animal']:
                for action in ['walk','carry_walk']:
                    for track in biped.base.CONTRACT['families'][family]['clips'][action]['tracks']:
                        if track['type']=='rotation' and track['bone'].startswith(('UpperLeg','LowerLeg','Foot')):
                            for key in track['keys']:
                                x,y,z,w=key['value']
                                q=biped.base.Quaternion((1,0,0,0)).slerp(biped.base.Quaternion((w,x,y,z)),float(spec['stride_scale']))
                                key['value']=[q.x,q.y,q.z,q.w]
        biped.process(row['intake_id'],spec,dict(resident_id=ident,
            type='human' if row['rig_type']=='robot' or row.get('kind')=='human' else 'animal',
            name_zh=row['name'],identity_reference=row['reference']))
        biped.base.CONTRACT=original_contract
        folder=OUT/ident
        data=read(folder/'rig.json')
        data['runtime_profile']=dict(name=row['name'],kind=row.get('kind','human'),source=row['reference'])
        data['locomotion']='biped'
        data['allowed_actions']=[a['name'] for a in data['actions']]
        if 'stride_scale' in spec: data['stride_scale']=spec['stride_scale']
        if 'skirt_bottom' in spec:data['skirt_bone']='Skirt'
        data['identity_reference']=row['reference']
        data['rig_type']=row['rig_type']
        write(folder/'rig.json',data)
        print('EXPANSION_RIG_DONE '+ident,flush=True)
if __name__=='__main__':main()
