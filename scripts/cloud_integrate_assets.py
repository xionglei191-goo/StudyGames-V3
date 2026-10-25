"""Integrate locally validated, versioned scene assets. No remote operations."""
from pathlib import Path
import json,shutil,collections,os
import verify_world_refinement as v
ROOT=Path(__file__).resolve().parents[1];EV=Path(os.environ.get('STUDYGAMES_REFINEMENT_EVIDENCE',ROOT/'.local/cloud-refinement/evidence'))
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,j):p.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
report=read(EV/'asset_validation.json');assert report['passed']
backup=EV/'original_manifests';backup.mkdir(exist_ok=True)
paths=['assets/blender/alphabet_island/game_map_manifest.json','assets/blender/interiors/interiors_manifest.json','game/data/interiors_manifest.json','game/assets/world/manifest.json']
for path in paths:
    target=backup/path;target.parent.mkdir(parents=True,exist_ok=True)
    if not target.exists():shutil.copy2(ROOT/path,target)
island=report['rooms'][0];p=ROOT/paths[0];j=read(p);data,blob=v.load(ROOT/island['glb'])
collisions={n['name']:n.get('extras',{}).get('sg_collision','none') for n in data['nodes'] if 'mesh' in n}
for n,kind in j['collision_by_node'].items():assert collisions[n]==kind
j.update(version=8,working_blend=island['blend'],working_blend_sha256=island['blend_sha256'],glb_sha256=island['glb_sha256'],glb_bytes=island['glb_bytes'],source_v07_sha256=v.sha(ROOT/island['original_blend']),source_v07_glb_sha256=v.sha(ROOT/island['original_glb']),refinement_revision='cloud-08',collision_by_node=collisions,collision_counts=dict(collections.Counter(collisions.values())),source_import_limitation=report['source_import_limitation'])
write(p,j);write(ROOT/'game/assets/world/manifest.json',j);shutil.copy2(ROOT/island['glb'],ROOT/'game/assets/world/island.glb')
source=read(ROOT/paths[1]);runtime=read(ROOT/paths[2]);sources={x['room_id']:x for x in source['rooms']};runtimes={x['room_id']:x for x in runtime['rooms']}
for row in report['rooms'][1:]:
    rid=row['room_id'];s=sources[rid];s.update(blend=row['blend'],glb=row['glb'],glb_sha256=row['glb_sha256'],refinement_revision='cloud-08',source_import_limitation=report['source_import_limitation'])
    t=runtimes[rid];t.update(source_blend=row['blend'],source_glb=row['glb'],source_sha256=row['glb_sha256'])
    t['validation'].update(nodes=row['exported_nodes'],bytes=row['glb_bytes'],images=row['embedded_images'])
    shutil.copy2(ROOT/row['glb'],ROOT/('game/assets/interiors/'+rid+'.glb'))
write(ROOT/paths[1],source);write(ROOT/paths[2],runtime)
print('LOCAL_INTEGRATION_COMPLETE',len(report['rooms']))
