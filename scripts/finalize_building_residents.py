"""Check the 34 source/rig mappings and publish the authored runtime metadata.

Does not mark visual or engine validation complete; delivery reports own that.
"""
from __future__ import annotations
import hashlib
import json
import math
from pathlib import Path
import shutil
import struct

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/characters/building_residents_v1'
RUNTIME=ROOT/'game/assets/characters/building_residents_v1'

def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path,value):path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def main():
    fits=read(ASSETS/'fitting.json')['models']
    catalog=read(ROOT/'assets/tripo/building_residents_v01/manifest.json')['assets']
    assert len(fits)==34 and len({r['resident_id'] for r in fits.values()})==34
    assert set(r['resident_id'] for r in catalog)==set(r['resident_id'] for r in fits.values())
    rows=[];gestures={}
    for intake,spec in fits.items():
        ident=spec['resident_id'];folder=ASSETS/ident;rig=read(folder/'rig.json')
        assert rig['id']==ident and rig['intake_id']==intake
        assert rig['source_sha256']==sha(ROOT/rig['source']),ident+' original changed'
        assert rig['unweighted_vertices']==0 and rig['weight_sum_max_error']<1e-5
        assert rig['triangles']<=32005
        assert rig['rigging_provider']['provider']=='Mesh2Motion'
        raw=(folder/'character.glb').read_bytes()
        assert raw[:4]==b'glTF' and struct.unpack_from('<I',raw,8)[0]==len(raw)
        length=struct.unpack_from('<I',raw,12)[0];glb=json.loads(raw[20:20+length])
        assert len(glb.get('skins',[]))==1 and len(glb['skins'][0]['joints'])>=17
        assert len(glb.get('animations',[]))==14
        for mesh in glb['meshes']:
            for primitive in mesh['primitives']:
                assert 'JOINTS_0' in primitive['attributes'] and 'WEIGHTS_0' in primitive['attributes']
        # Derive reduced waves directly from the same normal-track rotations.
        pose=read(folder/'gestures.json');reduced=[]
        for track in pose['normal']['greet_wave']:
            keys=[]
            for key in track['keys']:
                x,y,z,w=key['value'];angle=math.acos(max(-1.,min(1.,w)))
                factor=math.sin(angle*.60)/math.sin(angle) if abs(angle)>1e-8 else .60
                keys.append(dict(time=key['time'],value=[x*factor,y*factor,z*factor,math.cos(angle*.60)]))
            reduced.append(dict(bone=track['bone'],keys=keys))
        pose.setdefault('reduced',{})['greet_wave']=reduced;write(folder/'gestures.json',pose);gestures[ident]=pose
        rows.append(dict(id=ident,intake_id=intake,name_zh=rig['name_zh'],room_id=rig['room_id'],
            source=rig['source'],source_sha256=rig['source_sha256'],source_triangles=rig['source_triangles'],
            triangles=rig['triangles'],bones=len(rig['bones']),clips=len(glb['animations']),
            region_split_height=rig['region_split_height'],weight_refinement=rig.get('weight_refinement','initial'),glb=rig['export_glb'],glb_sha256=sha(folder/'character.glb'),
            blend=rig['editable_source'],blend_sha256=sha(folder/'rigged.blend'),reference=rig['identity_reference']))
    RUNTIME.mkdir(parents=True,exist_ok=True)
    write(RUNTIME/'gesture-overrides.json',dict(schema_version=1,characters=gestures))
    write(ASSETS/'mapping.json',dict(schema_version=1,characters=rows))
    write(ASSETS/'asset-checks.json',dict(status='PASS',characters=34,originals_unchanged=34,
        unique_sources=len({r['source_sha256'] for r in rows}),total_source_triangles=sum(r['source_triangles'] for r in rows),
        total_runtime_triangles=sum(r['triangles'] for r in rows),rows=rows))
    print('RESIDENT_ASSETS_CHECKED',len(rows),sum(r['triangles'] for r in rows))

if __name__=='__main__':main()
