"""Consolidate the frozen delivery and isolated saved-source roundtrip evidence."""
import json,hashlib
from pathlib import Path
from PIL import Image,ImageChops,ImageStat

ROOT=Path(__file__).resolve().parents[4]
OUT=ROOT/'assets/blender/interiors'
manifest=json.loads((OUT/'interiors_manifest.json').read_text(encoding='utf-8'))
validation=json.loads((OUT/'reports/validation_report.json').read_text(encoding='utf-8'))
roundtrip=json.loads((OUT/'reports/roundtrip_report.json').read_text(encoding='utf-8'))
assert len(manifest['rooms'])==31 and validation['passed'] and roundtrip['room_count']==31
assert all(r['source_blend_preserved'] and r['node_transforms_unchanged'] and r['triangles_unchanged'] and r['delivered_glb_sha256_before']==r['delivered_glb_sha256_after'] for r in roundtrip['rooms'])
comparisons=[]
for room in manifest['rooms']:
    original=Image.open(ROOT/room['preview']).convert('RGB')
    reopened=Image.open(OUT/'reports/roundtrip'/room['room_id']/'preview.png').convert('RGB')
    assert original.size==reopened.size
    diff=ImageChops.difference(original,reopened)
    comparisons.append({'room_id':room['room_id'],'pixel_identical':diff.getbbox() is None,'mean_absolute_difference_255':round(sum(ImageStat.Stat(diff).mean)/3,7)})
totals={key:sum((ROOT/r[key]).stat().st_size for r in manifest['rooms']) for key in ['blend','glb','preview']}
report={
 'schema_version':1,'date':'2026-10-22','status':'asset_delivery_complete_frozen_for_godot',
 'completed_rooms':31,'editable_blend_files':31,'glb_files':31,'individual_previews':31,'memory_anchors':155,
 'manifest':'assets/blender/interiors/interiors_manifest.json',
 'plan_labels_match':all(r['plan_labels_checked']==5 for r in validation['rooms']),
 'original_assets_checked':validation['original_assets']['checked'],'original_assets_changed':validation['original_assets']['changed'],
 'original_orchard_reused':True,'orchard_source_report':'assets/blender/interiors/landmark_A/source_adaptation.json',
 'export_existing_preserves_artist_source':True,'roundtrip_room_count':31,
 'saved_source_renders':comparisons,'total_bytes':totals,
 'triangle_range':[min(r['triangles'] for r in manifest['rooms']),max(r['triangles'] for r in manifest['rooms'])],
 'visual_review':{
   'method':'Reviewed all 31 individual Blender renders through four contact sheets; opened full images for composition corrections and verification.',
   'full_image_inspections':['landmark_A','landmark_B','landmark_C','landmark_F','landmark_K','landmark_S','school','home'],
   'corrections':['Replaced procedural A rectangle with original orchard v02 including real apple house, creek, bridge and legacy loci.','Matched all 155 point labels and their concrete props to the authored plan.','Clipped bakery tiles to the rounded floor and brought windows within the wall.','Raised school title above door signs.','Added support geometry to greenhouse petals, kite pavilion and observatory sign.','Moved boat cabin and its approach anchor onto the rear right pier.','Kept bridge access ramps inside the original orchard shoreline.'],
   'contact_sheets':validation.get('contact_sheets',[])
 },
 'final_changed_rooms':['landmark_B','landmark_C','landmark_S'],
 'final_change_notes':{
   'landmark_B':'SG_MEMORY_05 moved to Blender (6.8,4.75,0), Godot (6.8,0,-4.75); cabin collision moved to the rear right pier.',
   'landmark_C':'Pickup window frame added. No anchor or collision changes in final pass.',
   'landmark_S':'Observatory sign support posts added. Subsequently corrected existing SG_FLOOR_Main outward winding only; vertex coordinates and all SG anchors unchanged. Focused floor repair and GLB ray evidence are in reports/S_floor_fix/repair_report.json.'
 },
 'scope_limits':['Godot character physics, slopes, navigation, interaction range and room returns are not accepted by this asset report.','No NPC animation, voice, lesson or production task logic is included in these model files.','Per-room mesh budgets have not been profiled on target hardware; no LOD or runtime batching acceptance is claimed.','v01 styling and decorative density remain available for user review; no additional optional polishing after delivery freeze.'],
 'git_commit_or_push_performed':False,
}
repair_path=OUT/'reports/S_floor_fix/repair_report.json'
if repair_path.exists():
    repair=json.loads(repair_path.read_text(encoding='utf-8'))
    if repair.get('passed'):
        report['focused_floor_repair']={'room_id':'landmark_S','passed':True,'report':'assets/blender/interiors/reports/S_floor_fix/repair_report.json','glb_sha256':repair['glb_sha256'],'godot_runtime_retest':'Primary chat'}
(OUT/'reports/acceptance_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
state=json.loads((OUT/'reports/production_status.json').read_text(encoding='utf-8-sig'))
state.update({'status':'complete_ready_for_godot_sync','current_work':'Complete; production assets remain frozen.','roundtrip_passed':True,'roundtrip_room_count':31,'acceptance_report':'assets/blender/interiors/reports/acceptance_report.json'})
if report.get('focused_floor_repair'):
    state['focused_floor_repair']=report['focused_floor_repair']
    state['final_changes']['landmark_S']=report['final_change_notes']['landmark_S']
    state['current_work']='S floor winding repair complete; assets frozen for primary chat Godot retest.'
(OUT/'reports/production_status.json').write_text(json.dumps(state,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'completed_rooms':31,'original_assets_checked':report['original_assets_checked'],'saved_source_pixel_identical':sum(c['pixel_identical'] for c in comparisons),'max_render_mean_difference':max(c['mean_absolute_difference_255'] for c in comparisons),'total_bytes':totals,'triangle_range':report['triangle_range']},ensure_ascii=False,indent=2))
