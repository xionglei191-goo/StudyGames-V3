"""Preflight every versioned asset and preview, then update actual game manifests and resources."""
from pathlib import Path
import json,shutil,argparse,collections
import verify_world_refinement as v
from cloud_validate_assets import triangles
from sync_blender_interiors import inspect_glb
p=argparse.ArgumentParser();p.add_argument('--evidence',required=True);p.add_argument('--native-reviewed',action='store_true');a=p.parse_args();EV=Path(a.evidence);ROOT=Path(__file__).resolve().parents[1]
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,j):p.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
report=read(EV/'asset_validation.json');assert report['passed'];assert read(EV/'saved_blend_validation.json')['passed'];prepared={}
for r in report['rooms']:
 rid=r['room_id'];assert v.sha(ROOT/r['blend'])==r['blend_sha256'];assert v.sha(ROOT/r['glb'])==r['glb_sha256'];data,_=v.load(ROOT/r['glb']);assert triangles(data)==r['exported_triangles'];im=EV/rid/'after.png'
 with im.open('rb') as f:assert f.read(8)==b'\x89PNG\r\n\x1a\n'
 version=Path(r['blend']).stem.removeprefix(rid+'_');preview=Path(r['blend']).with_name('preview_'+version+'.png').as_posix();prepared[rid]={'data':data,'image':im,'preview':preview,'version':version,'validation':inspect_glb(ROOT/r['glb'],rid) if rid!='island' else None}
 if a.native_reviewed:
  proof=read(ROOT/'docs/verification/cloud-refinement-round2-20261025/native/after/round2/report.json');assert proof['result']=='PASS';runtime='res://assets/world/island.glb' if rid=='island' else 'res://assets/interiors/'+rid+'.glb';assert proof['source_sha256'][runtime]==r['glb_sha256']
for r in report['rooms']:
 shutil.copy2(prepared[r['room_id']]['image'],ROOT/prepared[r['room_id']]['preview'])
r=report['rooms'][0];d=prepared['island'];path=ROOT/'assets/blender/alphabet_island/game_map_manifest.json';j=read(path);collision={n['name']:n.get('extras',{}).get('sg_collision','none') for n in d['data']['nodes'] if 'mesh' in n}
for n,kind in j['collision_by_node'].items():assert collision[n]==kind,n
j.update(version=9,working_blend=r['blend'],working_blend_sha256=r['blend_sha256'],working_glb=r['glb'],glb_sha256=r['glb_sha256'],glb_bytes=r['glb_bytes'],triangles=r['exported_triangles'],preview=d['preview'],model_version='v09_cloud',refinement_revision='cloud-09',collision_by_node=collision,collision_counts=dict(collections.Counter(collision.values())),first_round_blend=r['first_blend'],first_round_glb=r['first_glb'],source_import_limitation=report['source_import_limitation'])
write(path,j);write(ROOT/'game/assets/world/manifest.json',j);shutil.copy2(ROOT/r['glb'],ROOT/'game/assets/world/island.glb')
p=ROOT/'assets/blender/interiors/interiors_manifest.json';q=ROOT/'game/data/interiors_manifest.json';source=read(p);runtime=read(q);ss={r['room_id']:r for r in source['rooms']};tt={r['room_id']:r for r in runtime['rooms']}
for r in report['rooms'][1:]:
 rid=r['room_id'];d=prepared[rid];s=ss[rid];t=tt[rid]
 s.update(blend=r['blend'],glb=r['glb'],glb_sha256=r['glb_sha256'],triangles=r['exported_triangles'],preview=d['preview'],model_version=d['version'],refinement_revision='cloud-09',first_round_blend=r['first_blend'],first_round_glb=r['first_glb'],source_import_limitation=report['source_import_limitation'])
 if 'technical_frame' in s:s['technical_frame'].update(texture_count=d['validation']['images'])
 if 'provenance' in s:s['provenance'].update(kind='Native second pass on saved round-one Blender scene',source_script='scripts/cloud_round2_refine.py',tool='Blender 4.3.2')
 s['verification']={'technical_checks_passed':True,'rendered_preview':True,'preview':d['preview'],'in_engine_reviewed':a.native_reviewed,'approval_status':'native_visual_comparison_completed' if a.native_reviewed else 'native_visual_comparison_pending','scope':'Godot 4.6.3 compatibility/llvmpipe native captures; performance and Godot 4.7 acceptance are separate.' if a.native_reviewed else 'Native capture and route checks follow asset integration.'}
 t.update(source_blend=r['blend'],source_glb=r['glb'],source_sha256=r['glb_sha256'],model_version=d['version'],preview=d['preview'],triangles=r['exported_triangles'],refinement_revision='cloud-09',validation=d['validation'])
 shutil.copy2(ROOT/r['glb'],ROOT/('game/assets/interiors/'+rid+'.glb'))
write(p,source);write(q,runtime);print('ROUND2_INTEGRATED',len(report['rooms']))
