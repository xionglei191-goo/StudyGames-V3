"""Verify provenance, real skins and clips, then publish runtime metadata."""
from pathlib import Path
import hashlib, json, struct, shutil, sys
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/characters/textbook_expansion_v1'
RUNTIME=ROOT/'game/assets/characters/textbook_expansion_v1'
RUNTIME.mkdir(parents=True,exist_ok=True)
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
catalog=read(SOURCE/'catalog.json');rows=[];gestures={};missing=[]
for row in catalog['assets']:
    if row['category']!='character':continue
    ident=row['id'];folder=SOURCE/ident
    if not (folder/'rig.json').exists():missing.append(ident);continue
    rig=read(folder/'rig.json')
    assert rig['source_sha256']==row['source_sha256']==sha(ROOT/row['source']),ident+' source changed'
    assert rig['unweighted_vertices']==0 and rig['weight_sum_max_error']<1e-5
    assert rig['triangles']<=32005
    raw=(folder/'character.glb').read_bytes()
    assert raw[:4]==b'glTF' and struct.unpack_from('<I',raw,8)[0]==len(raw)
    length=struct.unpack_from('<I',raw,12)[0];glb=json.loads(raw[20:20+length])
    assert len(glb.get('skins',[]))==1 and len(glb['skins'][0]['joints'])>=8
    assert len(glb.get('animations',[]))==len(rig['actions'])
    for mesh in glb['meshes']:
        for primitive in mesh['primitives']:
            assert 'JOINTS_0' in primitive['attributes'] and 'WEIGHTS_0' in primitive['attributes']
    if (folder/'gestures.json').exists():gestures[ident]=read(folder/'gestures.json')
    if (folder/'animation-clips.json').exists():
        (RUNTIME/ident).mkdir(exist_ok=True)
        shutil.copyfile(folder/'animation-clips.json',RUNTIME/ident/'animation-clips.json')
    rows.append(dict(id=ident,intake_id=row['intake_id'],name=row['name'],source=row['source'],source_sha256=row['source_sha256'],
        triangles=rig['triangles'],source_triangles=rig['source_triangles'],bones=len(rig['bones']),clips=len(glb['animations']),
        rig_type=row['rig_type'],glb=rig['export_glb'],glb_sha256=sha(folder/'character.glb'),blend=rig['editable_source'],blend_sha256=sha(folder/'rigged.blend')))
if '--partial' not in sys.argv:
    assert len(catalog['assets'])==56 and len(rows)==40 and not missing,missing
write(RUNTIME/'gesture-overrides.json',dict(schema_version=1,characters=gestures))
write(RUNTIME/'catalog.json',catalog)
write(SOURCE/'asset-checks.json',dict(status='PARTIAL' if missing or len(rows)!=40 else 'PASS',characters=len(rows),missing=missing,
    source_hashes_preserved=True,unique_sources=len({r['source_sha256'] for r in rows}),rows=rows))
engine=Path('F:/VideoMaker/experiments/mesh2motion-robots-20261027/engine')
if (engine/'LICENSE').exists():shutil.copyfile(engine/'LICENSE',SOURCE/'MESH2MOTION-LICENSE.txt')
print('EXPANSION_ASSETS_CHECKED',len(rows),'pending',len(missing))
