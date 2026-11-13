"""Measure production skin edge strain from Godot exports; flags require visual review."""
from __future__ import annotations
import os
os.environ['OPENBLAS_NUM_THREADS']='1'
import argparse
import hashlib
from concurrent.futures import ProcessPoolExecutor
import json
from pathlib import Path
import numpy as np

def read(path): return json.loads(Path(path).read_text(encoding='utf-8-sig'))

def analyze(path):
    data=read(path)
    geometries=[]
    for mesh in data['geometries']:
        surfaces=[]
        for surface in mesh['surfaces']:
            xyz=np.asarray(surface['vertices'],np.float32).reshape(-1,3)
            weights=np.asarray(surface['weights'],np.float32).reshape(len(xyz),-1)
            bones=np.asarray(surface['bones'],np.int32).reshape(len(xyz),-1)
            tris=np.asarray(surface['triangles'],np.int32).reshape(-1,3)
            edges=np.unique(np.sort(np.concatenate([tris[:,[0,1]],tris[:,[1,2]],tris[:,[0,2]]]),axis=1),axis=0)
            lengths=np.linalg.norm(xyz[edges[:,0]]-xyz[edges[:,1]],axis=1)
            keep=lengths>.006
            edges=edges[keep];lengths=lengths[keep]
            homogeneous=np.column_stack([xyz,np.ones(len(xyz),np.float32)])
            surfaces.append((xyz,homogeneous,weights,bones,edges,lengths))
        geometries.append(surfaces)
    records=[]
    for pose in data['poses']:
        # Sample both modes: partial blends may reach a different worst pose.
        worst=None
        severe=0
        strained=0
        total=0
        lowest_sole=float('inf')
        for mesh_index,surfaces in enumerate(geometries):
            matrices=np.asarray(pose['transforms'][mesh_index],np.float32).reshape(-1,3,4)
            for xyz,homogeneous,weights,bones,edges,lengths in surfaces:
                deformed=np.zeros_like(xyz)
                for slot in range(weights.shape[1]):
                    deformed+=np.einsum('vij,vj->vi',matrices[bones[:,slot]],homogeneous)*weights[:,slot,None]
                sole=xyz[:,1]<.22
                if sole.any():lowest_sole=min(lowest_sole,float(deformed[sole,1].min()))
                moved=np.linalg.norm(deformed[edges[:,0]]-deformed[edges[:,1]],axis=1)
                gain=moved-lengths
                ratios=moved/lengths
                bad=(ratios>2.)&(gain>.025)
                extreme=(ratios>3.)&(gain>.045)
                severe+=int(extreme.sum());strained+=int(bad.sum());total+=len(edges)
                score=gain*np.maximum(ratios-1.,0.)
                edge=int(np.argmax(score))
                if worst is None or float(score[edge])>worst['score']:
                    vertices=edges[edge].tolist()
                    influences=[]
                    for vertex in vertices:
                        influences.append([{ 'bone':data['bone_names'][int(bones[vertex,i])], 'weight':round(float(weights[vertex,i]),4)} for i in range(weights.shape[1]) if weights[vertex,i]>.001])
                    worst=dict(score=float(score[edge]),ratio=float(ratios[edge]),rest_length=float(lengths[edge]),gain=float(gain[edge]),rest_points=xyz[vertices].tolist(),deformed_points=deformed[vertices].tolist(),influences=influences)
        records.append(dict(action=pose['action'],mode=pose['mode'],time=pose['time'],severe_edges=severe,strained_edges=strained,edge_count=total,lowest_sole_y=lowest_sole,worst=worst))
    by_action=[]
    for action in dict.fromkeys(pose['action'] for pose in records):
        samples=[pose for pose in records if pose['action']==action]
        worst=max(samples,key=lambda pose:(pose['severe_edges'],pose['strained_edges'],pose['worst']['score']))
        by_action.append(worst)
    result=dict(id=data['id'],name=data['profile']['name'],export_sha256=hashlib.sha256(Path(path).read_bytes()).hexdigest(),resources=[{key:mesh.get(key) for key in ['resource','resource_sha256']} for mesh in data['geometries']],sample_count=len(records),maximum_sole_support_error_m=max(abs(pose['lowest_sole_y']) for pose in records),max_severe_edges=max(pose['severe_edges'] for pose in records),max_strained_edges=max(pose['strained_edges'] for pose in records),worst_actions=sorted(by_action,key=lambda pose:(pose['severe_edges'],pose['strained_edges']),reverse=True),samples=records)
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('input',type=Path)
    parser.add_argument('output',type=Path)
    parser.add_argument('--only',default='')
    parser.add_argument('--glob',default='resident_*.json')
    args=parser.parse_args()
    files=sorted(args.input.glob(args.glob))
    if args.only:files=[path for path in files if path.stem in args.only.split(',')]
    args.output.mkdir(parents=True,exist_ok=True)
    rows=[]
    with ProcessPoolExecutor(max_workers=3) as pool:
        for result in pool.map(analyze,files):
            (args.output/(result['id']+'.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
            rows.append({key:result[key] for key in ['id','name','sample_count','maximum_sole_support_error_m','max_severe_edges','max_strained_edges','worst_actions']})
            print('REVIEW_METRICS',result['id'],result['max_severe_edges'],result['max_strained_edges'],flush=True)
    rows.sort(key=lambda item:(item['max_severe_edges'],item['max_strained_edges']),reverse=True)
    summary=dict(status='MEASURED_REQUIRES_VISUAL_REVIEW',definition='Unique mesh edges longer than 6 mm. Strained: >2x original length and >25mm growth; severe: >3x and >45mm growth. Flags locate suspicious deformations, not automatic visual acceptance.',characters=len(rows),rows=rows)
    (args.output/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
