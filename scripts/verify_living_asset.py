"""Check the shipped living-room GLB, not only Blender's source geometry."""
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    raw=path.read_bytes()
    length=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+length])
    offset=20+length
    binary_length=struct.unpack_from('<I',raw,offset)[0]
    return doc,raw[offset+8:offset+8+binary_length]


def values(doc,blob,index):
    accessor=doc['accessors'][index]
    view=doc['bufferViews'][accessor['bufferView']]
    fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[accessor['componentType']]
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[accessor['type']]
    stride=view.get('byteStride',struct.calcsize(fmt)*count)
    base=view.get('byteOffset',0)+accessor.get('byteOffset',0)
    return [struct.unpack_from('<'+fmt*count,blob,base+k*stride) for k in range(accessor['count'])]


def controls(doc):
    parents={child:node.get('name','') for node in doc['nodes'] for child in node.get('children',[])}
    out={}
    for index,node in enumerate(doc['nodes']):
        if node.get('name','').startswith(('SG_','HOME_TASK_')):
            out[node['name']]={'parent':parents.get(index),**{k:node[k] for k in ['matrix','translation','rotation','scale','extras'] if k in node}}
    return out


def main():
    old,_=read(ROOT/'assets/blender/interiors/home/home_v02.glb')
    doc,blob=read(ROOT/'assets/blender/interiors/home/home_v03.glb')
    before,after=controls(old),controls(doc)
    changed=[name for name,value in before.items() if after.get(name)!=value]
    zero=0
    opposed=[]
    tested=0
    for node in doc['nodes']:
        name=node.get('name','')
        if not name.startswith(('Living03_','Home_Cup_Refined','Home_Rear_Sofa_','Window_Reading_Chair_')) or 'mesh' not in node:
            continue
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            xyz=values(doc,blob,primitive['attributes']['POSITION'])
            normals=values(doc,blob,primitive['attributes']['NORMAL'])
            indices=[v[0] for v in values(doc,blob,primitive['indices'])]
            for offset in range(0,len(indices),3):
                ids=indices[offset:offset+3]
                p,q,r=[xyz[i] for i in ids]
                u=[q[j]-p[j] for j in range(3)]
                v=[r[j]-p[j] for j in range(3)]
                cross=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
                area2=sum(t*t for t in cross)
                if area2<1e-22:
                    zero+=1
                    continue
                mean=[sum(normals[i][j] for i in ids)/3 for j in range(3)]
                dot=sum(cross[j]*mean[j] for j in range(3))/math.sqrt(area2)
                if dot < -.0001:
                    opposed.append({'node':name,'triangle':offset//3,'normal_dot':dot})
                tested+=1
    report={'protected_export_nodes':len(before),'changed_protected_node_transforms_or_metadata':changed,
            'tested_new_exported_triangles':tested,'degenerate_triangles':zero,
            'normals_opposed_to_winding':opposed,'passed':not changed and not zero and not opposed}
    output=ROOT/'docs/verification/living-room-polish/export-check.json'
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf-8')
    print(json.dumps(report,ensure_ascii=False))
    if not report['passed']:raise SystemExit(1)


if __name__=='__main__':main()
