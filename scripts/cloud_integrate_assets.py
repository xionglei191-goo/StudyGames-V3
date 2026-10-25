"""Integrate locally validated, versioned scene assets. No remote operations."""
from pathlib import Path
import json,shutil,collections,os
import verify_world_refinement as v
from cloud_validate_assets import triangles
from sync_blender_interiors import inspect_glb
ROOT=Path(__file__).resolve().parents[1];EV=Path(os.environ.get('STUDYGAMES_REFINEMENT_EVIDENCE',ROOT/'.local/cloud-refinement/evidence'))
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,j):p.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
report=read(EV/'asset_validation.json');assert report['passed']
# Validate the complete batch before writing any manifest or runtime file.
prepared={}
for row in report['rooms']:
    assert v.sha(ROOT/row['blend'])==row['blend_sha256'],row['room_id']+' blend changed after validation'
    assert v.sha(ROOT/row['glb'])==row['glb_sha256'],row['room_id']+' GLB changed after validation'
    if row['room_id']=='island':continue
    rid=row['room_id'];data,_=v.load(ROOT/row['glb'])
    count=triangles(data);assert count==row['exported_triangles'],rid+' triangle report is stale'
    image=EV/rid/'after.png'
    with image.open('rb') as f:assert f.read(8)==b'\x89PNG\r\n\x1a\n',rid+' preview is missing or not a rendered PNG'
    model_version=Path(row['blend']).stem.removeprefix(rid+'_')
    preview=Path(row['blend']).with_name('preview_'+model_version+'.png')
    prepared[rid]={'triangles':count,'validation':inspect_glb(ROOT/row['glb'],rid),
                   'image':image,'preview':preview.as_posix(),'model_version':model_version}
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
    rid=row['room_id'];s=sources[rid];current=prepared[rid]
    # Retain historical authoring/review facts without presenting them as acceptance
    # of this GLB-derived version. Ordinary exporter fields describe the current file.
    history={k:s[k] for k in ['model_version','technical_frame','provenance','verification']
             if k in s and (k!='model_version' or s[k]!=current['model_version'])}
    if history:s.setdefault('source_history',{'blend':row['original_blend'],'glb':row['original_glb'],**history})
    s.update(blend=row['blend'],glb=row['glb'],glb_sha256=row['glb_sha256'],
             triangles=current['triangles'],preview=current['preview'],model_version=current['model_version'],
             refinement_revision='cloud-08',source_import_limitation=report['source_import_limitation'])
    if 'technical_frame' in s:
        s['technical_frame']={**s['technical_frame'],'engine':'Godot 4.7 project target',
                              'texture_count':current['validation']['images']}
    if 'provenance' in s:
        s['provenance']={'kind':'Refinement of the original exported GLB in Blender',
                         'tool':'Blender 4.3.2','source_script':'scripts/cloud_scene_refine.py',
                         'original_metadata':'source_history.provenance',
                         'preservation':'Original blend and GLB retained byte-for-byte; original authoring history not reconstructed.'}
    if 'verification' in s:
        s['verification']={'technical_checks_passed':True,'rendered_preview':True,
                           'preview':current['preview'],'in_engine_reviewed':False,
                           'approval_status':'current_version_visual_runtime_review_pending',
                           'scope':'Source/GLB structural checks and Blender render only. Run engine acceptance separately; historical native visual approval is retained under source_history.verification.'}
    shutil.copy2(current['image'],ROOT/current['preview'])
    t=runtimes[rid];t.update(source_blend=row['blend'],source_glb=row['glb'],source_sha256=row['glb_sha256'])
    t['validation']=current['validation']
    shutil.copy2(ROOT/row['glb'],ROOT/('game/assets/interiors/'+rid+'.glb'))
write(ROOT/paths[1],source);write(ROOT/paths[2],runtime)
print('LOCAL_INTEGRATION_COMPLETE',len(report['rooms']))
