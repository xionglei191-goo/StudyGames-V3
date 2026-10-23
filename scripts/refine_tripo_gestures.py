"""Fit a modest, palm-forward greeting to each saved Tripo source rig.

Run in Blender background. Existing meshes, rest joints, materials, expressions,
and gameplay timings are retained. JSON curves are shared with the Godot adapter.
"""
from __future__ import annotations
import bpy, json, math, sys
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector, Quaternion

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import rig_tripo_characters as rig
PATH=ROOT/'game/assets/characters/tripo_v1/gesture-overrides.json'
TIMES=[0.0,.25,.65,.92,1.19,1.46,1.72,2.2]
LIFT=[0,.28,1,1,1,1,.72,0]
SWAY=[0,0,-1,1,-1,1,0,0]

def rest_matrices(bones):
    rest={}
    for bone in bones:
        local=Matrix.Translation(Vector(bone['origin']))@Matrix.Rotation(bone['rotation'][0],4,'X')
        rest[bone['name']]=rest[bone['parent']]@local if bone['parent'] else local
    return rest

def basis(direction,normal):
    direction=direction.normalized()
    normal=(normal-direction*normal.dot(direction)).normalized()
    return Matrix((direction.cross(normal),direction,normal)).transposed()

def make_curves(cid, data, arm, obj, rest, reduced=False):
    height=data['height']
    upper=(rest['LowerArm_R'].translation-rest['UpperArm_R'].translation).normalized()
    lower=(rest['Hand_R'].translation-rest['LowerArm_R'].translation).normalized()
    source_hand=arm.data.bones['Hand_R']
    finger=(rig.B2G.to_3x3()@(source_hand.tail_local-source_hand.head_local)).normalized()
    hand_id=obj.vertex_groups['Hand_R'].index
    chosen=[v.index for v in obj.data.vertices if any(g.group==hand_id and g.weight>.65 for g in v.groups)]
    points=rig.mesh_arrays(obj)[chosen]
    # Dino has a rounded paw blended into its short forearm rather than a flat
    # independently weighted palm. Use the relaxed inward-facing anatomical
    # axis when a surface plane cannot be measured from enough vertices.
    if len(points)>=8:
        _,axes=np.linalg.eigh(np.cov(points.T))
        normal=Vector(axes[:,0])
    else:
        normal=Vector((-1,0,0))
    normal-=finger*normal.dot(finger)
    normal.normalize()
    # In the original relaxed pose the palm faces the body. Keep this sign
    # explicit: PCA alone cannot distinguish the palm from the back of a hand.
    if normal.x>0:normal=-normal
    if abs(normal.x)<.45:normal=Vector((-.96,0,-.28))
    neutral=Quaternion((0,0,1),math.radians(-7))
    curves={name:[] for name in ['UpperArm_R','LowerArm_R','Hand_R']}
    for time,lift,sway in zip(TIMES,LIFT,SWAY):
        upper_target=Vector((.93,.06 if reduced else .18,.32)).normalized()
        if cid=='npc_bear_uncle':
            upper_target=Vector((.72,-.65 if reduced else -.55,.26)).normalized()
        lower_target=Vector((-.08+sway*(.025 if reduced else .065),.97,.22)).normalized()
        finger_target=Quaternion((0,0,1),math.radians(sway*(3 if reduced else 7)))@lower_target
        qupper=upper.rotation_difference(upper_target)
        qlower_global=(basis(lower_target,Vector((0,0,1)))@basis(lower,normal).transposed()).to_quaternion()
        qhand_global=(basis(finger_target,Vector((0,0,1)))@basis(finger,normal).transposed()).to_quaternion()
        rotations={
            'UpperArm_R':neutral.slerp(qupper,lift),
            'LowerArm_R':Quaternion().slerp(qupper.inverted()@qlower_global,lift),
            'Hand_R':Quaternion().slerp(qlower_global.inverted()@qhand_global,lift),
        }
        for name,q in rotations.items():
            q.normalize();curves[name].append({'time':time,'value':[q.x,q.y,q.z,q.w]})
    return [{'bone':name,'keys':keys} for name,keys in curves.items()],list(normal)

def main():
    selected=[arg for arg in sys.argv[sys.argv.index('--')+1:] if not arg.startswith('--')] if '--' in sys.argv else []
    ids=selected or [p[0] for p in rig.PROFILES]
    gestures=json.loads(PATH.read_text()) if PATH.exists() else {'schema_version':1,'revision':'anatomical-wave-v2','characters':{}}
    report=[]
    for cid in ids:
        folder=rig.OUT/cid
        data=json.loads((folder/'rig.json').read_text())
        bpy.ops.wm.open_mainfile(filepath=str(folder/'rigged.blend'))
        arm=bpy.data.objects['SemanticRig']; obj=bpy.data.objects['Body']
        arm.animation_data_clear()
        for bone in arm.pose.bones:bone.matrix_basis=Matrix.Identity(4)
        bpy.context.view_layer.update()
        rest=rest_matrices(data['bones'])
        normal,palm=make_curves(cid,data,arm,obj,rest,False)
        reduced,_=make_curves(cid,data,arm,obj,rest,True)
        gestures['characters'][cid]={'normal':{'greet_wave':normal},'reduced':{'greet_wave':reduced},'palm_rest_normal':palm}
        rig.GESTURES=gestures
        weights=rig.refine_garment_weights(obj,cid,data['bones'],data['height'])
        if weights.get('changed_vertices'):data['garment_refinement']=weights
        for action in list(bpy.data.actions):bpy.data.actions.remove(action)
        rig.make_actions(arm,data['bones'],rest,data['family'])
        bpy.ops.object.select_all(action='DESELECT')
        meshes=[]
        for name in data['meshes']:
            mesh=bpy.data.objects[name];meshes.append(mesh);mesh.select_set(True)
        arm.select_set(True);bpy.context.view_layer.objects.active=arm
        bpy.ops.wm.save_as_mainfile(filepath=str(folder/'rigged.blend'))
        bpy.ops.export_scene.gltf(filepath=str(folder/'character.glb'),export_format='GLB',use_selection=True,
            export_animations=True,export_yup=True,export_apply=False,export_extras=True,export_materials='EXPORT',export_animation_mode='ACTIONS')
        data['gesture_refinement']={'revision':'anatomical-wave-v2','source':'game/assets/characters/tripo_v1/gesture-overrides.json',
            'description':'fitted elbow raise, forearm roll, neutral wrist and small palm-forward wave; stable original duration'}
        data['status']='refined_pending_engine_validation'
        indices={bone['name']:i for i,bone in enumerate(data['bones'])}
        all_weights=[]
        for mesh in meshes:
            matrix=np.zeros((len(mesh.data.vertices),len(indices)))
            for vertex in mesh.data.vertices:
                for group in vertex.groups:matrix[vertex.index,indices[mesh.vertex_groups[group.group].name]]=group.weight
            all_weights.append(matrix)
        matrix=np.concatenate(all_weights)
        data['blended_vertices']=int(np.count_nonzero((matrix>1e-4).sum(axis=1)>1))
        data['unweighted_vertices']=int(np.count_nonzero(matrix.sum(axis=1)<1e-6))
        data['weight_sum_max_error']=float(np.max(np.abs(matrix.sum(axis=1)-1)))
        data['bone_vertex_counts']={bone['name']:int(np.count_nonzero(matrix[:,i]>1e-4)) for i,bone in enumerate(data['bones'])}
        (folder/'rig.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
        camera=rig.setup_render(data['height'])
        camera.data.ortho_scale=data['height']*1.55
        camera.location=(data['height']*.9,-data['height']*2.5,data['height']*.8)
        camera.rotation_euler=(Vector((0,0,data['height']*.5))-camera.location).to_track_quat('-Z','Y').to_euler()
        for action,time in [('idle',0),('greet_wave',.92),('take_item' if data['family']=='wheelchair' else 'walk',1.1 if data['family']=='wheelchair' else .28),('give_item',1.1)]:
            rig.pose_at(arm,data['bones'],rest,data['family'],rig.CONTRACT['families'][data['family']]['clips'][action],time)
            bpy.context.scene.render.filepath=str(folder/(action+'_rigged.png'))
            bpy.ops.render.render(write_still=True)
        row={'id':cid,'garment_weights':weights,'palm_rest_normal':palm}
        report.append(row);print('TRIPO_GESTURE_REFINED '+json.dumps(row),flush=True)
    PATH.write_text(json.dumps(gestures,indent=2)+'\n')
    (ROOT/'docs/verification/tripo-wave-refinement/refinement.json').write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':main()
