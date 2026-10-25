"""Compare exported gameplay geometry and saved originals across all 44 scenes."""
import hashlib,json,struct,math,re
from pathlib import Path
from collections import Counter
ROOT=Path(__file__).resolve().parents[1]
PLAN=ROOT/'docs/planning/world-refinement'
PROOF=ROOT/'docs/verification/world-refinement'

def sha(path):
    with path.open('rb') as f: return hashlib.file_digest(f,'sha256').hexdigest()

def load(path):
    raw=path.read_bytes()
    magic,version,size,length,kind=struct.unpack_from('<4sIIII',raw)
    assert magic==b'glTF' and version==2 and size==len(raw) and kind==0x4e4f534a
    data=json.loads(raw[20:20+length]);return data,raw[28+length:]

def accessor(data,blob,index):
    a=data['accessors'][index];v=data['bufferViews'][a['bufferView']]
    width,fmt={5120:(1,'b'),5121:(1,'B'),5122:(2,'h'),5123:(2,'H'),5125:(4,'I'),5126:(4,'f')}[a['componentType']]
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    offset=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',width*count)
    return [struct.unpack_from('<'+fmt*count,blob,offset+i*stride) for i in range(a['count'])]

def geometry(data,blob,node):
    if 'mesh' not in node: return None
    triangles=[]
    for primitive in data['meshes'][node['mesh']]['primitives']:
        if primitive.get('mode',4)!=4: continue
        vertices=[tuple(round(x,5) for x in row) for row in accessor(data,blob,primitive['attributes']['POSITION'])]
        indices=[i[0] for i in accessor(data,blob,primitive['indices'])] if 'indices' in primitive else list(range(len(vertices)))
        for i in range(0,len(indices),3): triangles.append(tuple(sorted(vertices[indices[i+j]] for j in range(3))))
    return hashlib.sha256(repr(sorted(triangles)).encode()).hexdigest()

def protected(data):
    ids=set()
    def add(i):
        ids.add(i)
        for child in data['nodes'][i].get('children',[]): add(child)
    for i,node in enumerate(data['nodes']):
        if node.get('name','').startswith(('SG_','COL_','HOME_TASK_')) or node.get('extras',{}).get('sg_collision','none')!='none': add(i)
    return [data['nodes'][i] for i in sorted(ids)]

def signature(data,node):
    name=node.get('name')
    parent=next((p.get('name') for p in data['nodes'] if data['nodes'].index(node) in p.get('children',[])),None)
    transform={k:[round(v,5) for v in node[k]] for k in ['matrix','translation','rotation','scale'] if k in node}
    return {'parent':parent,'transform':transform,'extras':node.get('extras',{})}

def main():
    base=json.loads((PLAN/'baseline.json').read_text(encoding='utf-8'))
    original_errors=[p for p,h in base['protected_files'].items() if not (ROOT/p).is_file() or sha(ROOT/p)!=h]
    current=json.loads((ROOT/'assets/blender/interiors/interiors_manifest.json').read_text(encoding='utf-8'))
    entries={r['room_id']:r for r in current['rooms']}
    island=json.loads((ROOT/'assets/blender/alphabet_island/game_map_manifest.json').read_text(encoding='utf-8'))
    entries['village']={'glb':str(Path(island['working_blend']).with_suffix('.glb')).replace('\\','/'),'blend':island['working_blend']}
    errors=[];rows=[]
    for old in base['rooms']:
        room=old['room_id'];entry=entries[room]
        source=ROOT/entry['glb'];runtime=ROOT/('game/assets/world/island.glb' if room=='village' else f'game/assets/interiors/{room}.glb')
        olddata,oldblob=load(ROOT/old['glb']);newdata,newblob=load(source)
        names={n.get('name'):n for n in newdata['nodes']}
        geometry_errors=[];transform_errors=[]
        oldparents={olddata['nodes'][c].get('name'):n.get('name') for n in olddata['nodes'] for c in n.get('children',[])}
        newparents={newdata['nodes'][c].get('name'):n.get('name') for n in newdata['nodes'] for c in n.get('children',[])}
        protected_nodes=protected(olddata)
        for node in protected_nodes:
            name=node['name'];target=names.get(name)
            if target is None: transform_errors.append(name+'/missing');continue
            for key in ['translation','rotation','scale','matrix']:
                defaults={'translation':[0,0,0],'rotation':[0,0,0,1],'scale':[1,1,1],'matrix':[]}
                a=node.get(key,defaults[key]);b=target.get(key,defaults[key])
                if len(a)!=len(b) or any(abs(x-y)>1e-5 for x,y in zip(a,b)): transform_errors.append(name+'/'+key)
            if oldparents.get(name)!=newparents.get(name) or node.get('extras',{})!=target.get('extras',{}): transform_errors.append(name+'/hierarchy_metadata')
            if geometry(olddata,oldblob,node)!=geometry(newdata,newblob,target): geometry_errors.append(name)
        missing_uv=[];external=[]
        for mesh in newdata['meshes']:
            for primitive in mesh['primitives']:
                material=newdata.get('materials',[])[primitive['material']] if 'material' in primitive else {}
                pbr=material.get('pbrMetallicRoughness',{})
                if ('baseColorTexture' in pbr or 'normalTexture' in material) and 'TEXCOORD_0' not in primitive['attributes']: missing_uv.append(mesh.get('name',''))
        for image in newdata.get('images',[]):
            if image.get('uri') and not image['uri'].startswith('data:'): external.append(image['uri'])
        synchronized=sha(source)==sha(runtime)
        passed=not geometry_errors and not transform_errors and not missing_uv and not external and synchronized
        row={'room':room,'passed':passed,'protected_exported_nodes':len(protected_nodes),'gameplay_triangle_coordinates_unchanged':not geometry_errors,
             'marker_transforms_hierarchy_metadata_unchanged':not transform_errors,'geometry_errors':geometry_errors,'transform_errors':transform_errors,
             'embedded_images':len(newdata.get('images',[])),'missing_uv':missing_uv,'external_images':external,'runtime_synchronized':synchronized,
             'source_blend':entry['blend'],'source_glb':entry['glb'],'sha256':sha(source),'glb_bytes':source.stat().st_size,
             'retained_approved_sample':room in ['home','home_estate']}
        if not passed: errors.append(room)
        rows.append(row);print('WORLD_STATIC',room,'PASS' if passed else 'FAIL',flush=True)
    report={'result':'PASS' if not errors and not original_errors else 'FAIL','rooms':rows,'original_source_files':len(base['protected_files']),
            'original_source_errors':original_errors,'failed_rooms':errors,'scope':'44 exported assets, original file SHA256, marker hierarchy and metadata, triangle-coordinate multiset equality for gameplay meshes, UV presence, embedded images and runtime synchronization. Engine movement/visual evidence is separate.'}
    (PROOF/'asset-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'result':report['result'],'rooms':len(rows),'protected_exported_nodes':sum(r['protected_exported_nodes'] for r in rows),'failures':errors,'original_errors':original_errors}))
    raise SystemExit(bool(errors or original_errors))

if __name__=='__main__':main()
