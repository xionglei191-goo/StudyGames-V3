"""Measure the saved source skins without modifying them (Blender background)."""
import bpy, json, sys
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import rig_tripo_characters as rig
ids=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['npc_bear_uncle','npc_rabbit_gardener','textbook_dongdong']
rows=[]
for cid in ids:
    folder=ROOT/'assets/characters/tripo_v1'/cid
    data=json.loads((folder/'rig.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(folder/'rigged.blend'))
    arm=bpy.data.objects['SemanticRig']; obj=bpy.data.objects['Body']
    arm.animation_data_clear()
    bones=data['bones']; height=data['height']; rest={}
    for bone in bones:
        local=Matrix.Translation(Vector(bone['origin']))@Matrix.Rotation(bone['rotation'][0],4,'X')
        rest[bone['name']]=rest[bone['parent']]@local if bone['parent'] else local
    xyz=rig.mesh_arrays(obj)/height
    weights=np.zeros((len(xyz),len(bones)))
    indices={b['name']:i for i,b in enumerate(bones)}
    for v in obj.data.vertices:
        for g in v.groups:weights[v.index,indices[obj.vertex_groups[g.group].name]]=g.weight
    hand=xyz[weights[:,indices['Hand_R']]>.7]
    covariance=np.cov(hand.T)
    vals,axes=np.linalg.eigh(covariance)
    normal=axes[:,0]
    if normal[2]<0:normal=-normal
    rig.pose_at(arm,bones,rest,data['family'],rig.CONTRACT['families'][data['family']]['clips']['greet_wave'],.8)
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh=evaluated.to_mesh()
    deformed=rig.mesh_arrays(type('MeshHolder',(),{'data':mesh})())/height
    pairs=np.array([e.vertices[:] for e in obj.data.edges]); a,b=pairs.T
    old=np.linalg.norm(xyz[a]-xyz[b],axis=1);new=np.linalg.norm(deformed[a]-deformed[b],axis=1)
    growth=new-old
    shoulder=rest['UpperArm_R'].translation/height
    mask=(xyz[:,1]>.25)&(xyz[:,1]<shoulder.y)&(xyz[:,0]>0)&(xyz[:,0]<shoulder.x+.055)
    top=np.argsort(growth*np.logical_or(mask[a],mask[b]))[-7:][::-1]
    row={'id':cid,'palm_plane_normal':normal.tolist(),'pca_values':vals.tolist(),'hand_vertices':len(hand),'shoulder':list(shoulder),'stretch_max':float(growth.max()),'stretch_p99':float(np.quantile(new/np.maximum(old,1e-6),.99)),
         'torso_edges':[{'growth':float(growth[i]),'rest':xyz[pairs[i]].round(3).tolist(),'posed':deformed[pairs[i]].round(3).tolist(),'weights':[{bones[j]['name']:round(float(weights[v,j]),3) for j in np.flatnonzero(weights[v]>.01)} for v in pairs[i]]} for i in top]}
    rows.append(row);print('WAVE_INSPECT '+json.dumps(row),flush=True)
    evaluated.to_mesh_clear()
(ROOT/'docs/verification/tripo-wave-refinement/source-inspection.json').write_text(json.dumps(rows,indent=2))
