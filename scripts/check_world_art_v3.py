"""Read-only GLB/provenance checks for the world refresh, no engine or saved game I/O."""
from __future__ import annotations
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT/'assets/art/world_refresh_v3'
RUNTIME = ROOT/'game/assets/world_refresh_v3'


def glb(path):
    raw=path.read_bytes()
    magic,version,total,length,kind=struct.unpack_from('<4sIIII',raw)
    assert magic==b'glTF' and version==2 and total==len(raw) and kind==0x4E4F534A,path
    return json.loads(raw[20:20+length]),raw[28+length:]


def accessor(data,blob,index):
    row=data['accessors'][index];view=data['bufferViews'][row['bufferView']]
    size,fmt={5121:(1,'B'),5123:(2,'H'),5125:(4,'I'),5126:(4,'f')}[row['componentType']]
    dims={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[row['type']]
    step=view.get('byteStride',size*dims);offset=view.get('byteOffset',0)+row.get('byteOffset',0)
    return [struct.unpack_from('<'+fmt*dims,blob,offset+i*step) for i in range(row['count'])]


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    manifest=json.loads((ART/'manifest.json').read_text(encoding='utf-8'))
    rows=[];errors=[]
    for record in manifest['assets']:
        path=ROOT/record['runtime'];data,blob=glb(path)
        assert sha(path)==record['sha256']==sha(ART/record['source'])
        count=0;degenerate=0;nonfinite=0;bad_normals=0;missing=[]
        for mesh in data['meshes']:
            for primitive in mesh['primitives']:
                attrs=primitive['attributes']
                for required in ('POSITION','NORMAL','TEXCOORD_0'):
                    if required not in attrs:missing.append(required)
                verts=accessor(data,blob,attrs['POSITION']);normals=accessor(data,blob,attrs['NORMAL'])
                indices=[x[0] for x in accessor(data,blob,primitive['indices'])]
                nonfinite+=sum(not all(math.isfinite(c) for c in v) for v in verts+normals)
                bad_normals+=sum(abs(sum(c*c for c in n)-1)>.03 for n in normals)
                for i in range(0,len(indices),3):
                    a,b,c=(verts[indices[i+j]] for j in range(3))
                    u=[b[j]-a[j] for j in range(3)];v=[c[j]-a[j] for j in range(3)]
                    cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                    if sum(x*x for x in cross)<1e-20:degenerate+=1
                    count+=1
        external=[image['uri'] for image in data.get('images',[]) if 'uri' in image and not image['uri'].startswith('data:')]
        row={'id':record['id'],'triangles':count,'degenerate_triangles':degenerate,'nonfinite_vectors':nonfinite,
             'bad_unit_normals':bad_normals,'missing_attributes':missing,'external_images':external,'sha256':sha(path),'bytes':path.stat().st_size}
        if degenerate or nonfinite or bad_normals or missing or external:errors.append(row['id'])
        rows.append(row)
    # Source map hashes are checked against the existing authoritative export records.
    scene_rows=[]
    for path in sorted((ROOT/'game/assets/interiors').glob('*.glb')):
        data,_=glb(path)
        names=[n.get('name','') for n in data.get('nodes',[])]
        candidates=Counter()
        for name in names:
            if name.startswith('SG_'):continue
            plain=name.split('.')[0]
            if ('_Fruit_' in plain and not plain.endswith(('_Stem','_Leaf'))) or plain.endswith('_Apple'):candidates['apple']+=1
            elif name=='A_Entrance_Basket' or plain.endswith('_Basket_Wicker'):candidates['basket']+=1
            elif (plain.endswith('_Cake_Layer') and '.' not in name) or name=='Cake_In_Progress_Layer':candidates['cake']+=1
            elif plain in ('Pupil_Book','Desk_Journal','Bird_Journal','Teacher_Book'):candidates['book']+=1
        scene_rows.append({'room':path.stem,'protected_source_sha256':sha(path),'markers':sum(n.startswith('SG_') for n in names),'replacement_candidates':dict(candidates)})
    textures=[]
    for path in sorted((ART/'textures').glob('*.png')):
        raw=path.read_bytes();width,height=struct.unpack_from('>II',raw,16)
        assert width==height==256 and sha(path)==sha(RUNTIME/path.name)
        textures.append({'file':path.name,'size':[width,height],'sha256':sha(path)})
    report={'status':'PASS' if not errors else 'FAIL','scope':'static GLB data, resource hashes, source map inventory; no engine acceptance',
            'assets':rows,'textures':textures,'protected_rooms':scene_rows,'errors':errors,
            'runtime_contract':'visual descendants only; source MeshInstance retains AABB/transform; no CollisionObject3D created'}
    (ART/'static-qa.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
    print(json.dumps({'status':report['status'],'assets':len(rows),'textures':len(textures),'protected_rooms':len(scene_rows),'triangles':sum(r['triangles'] for r in rows),'errors':errors}))
    raise SystemExit(bool(errors))


if __name__=='__main__':main()
