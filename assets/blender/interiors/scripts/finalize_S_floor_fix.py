"""Merge focused S repair evidence while retaining the earlier 31-room checks."""
import hashlib,json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
OUT=ROOT/'assets/blender/interiors'
FIX=OUT/'reports/S_floor_fix'
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def write(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

manifest=read(OUT/'interiors_manifest.json')
entries={r['room_id']:r for r in manifest['rooms']}
validation=read(OUT/'reports/validation_report.json')
assert validation['passed']
s_check=next(r for r in validation['rooms'] if r['room_id']=='landmark_S')
assert s_check['floor_orientation']['passed'] and not s_check['errors']
focused=read(OUT/'reports/roundtrip_report.json')
assert focused['passed'] and focused['room_count']==1 and focused['rooms'][0]['room_id']=='landmark_S'
write(FIX/'roundtrip_report.json',focused)
previous=read(FIX/'roundtrip_before.json')
assert previous['passed'] and previous['room_count']==31
previous['rooms']=[focused['rooms'][0] if r['room_id']=='landmark_S' else r for r in previous['rooms']]
for row in previous['rooms']:
    entry=entries[row['room_id']]
    assert row['blend_sha256_after']==digest(ROOT/entry['blend'])
    row['current_source_matches_verified_snapshot']=True
    row['current_glb_sha256']=digest(ROOT/entry['glb'])
    row['current_glb_matches_verified_snapshot']=row['current_glb_sha256']==row['delivered_glb_sha256_after']
previous['focused_revalidation']='landmark_S floor winding correction, 2026-10-22'
previous['post_roundtrip_export_note']='Primary chat re-exported all saved sources for synchronization. Historical delivery hashes are retained; current hashes are listed separately. All source .blend hashes still match their verification snapshots.'
write(OUT/'reports/roundtrip_report.json',previous)
repair=read(FIX/'repair_report.json')
repair.update({
    'passed':True,'glb_sha256':s_check['sha256'],
    'blend_sha256':digest(ROOT/entries['landmark_S']['blend']),
    'floor_orientation':s_check['floor_orientation'],
    'saved_blend_roundtrip':focused['rooms'][0],
    'other_rooms_hash_snapshot_scope':'Captured immediately before and after the focused S repair; primary chat subsequently re-exported all rooms during its game sync.',
    'other_30_source_blend_hashes_still_unchanged':all(digest(ROOT/entries[room]['blend'])==hashes['blend'] for room,hashes in repair['other_rooms_hashes'].items()),
    'godot_runtime_retest':'Handled by primary chat; no gameplay acceptance claimed by this report',
})
assert repair['other_30_source_blend_hashes_still_unchanged']
write(FIX/'repair_report.json',repair)
print(json.dumps({'passed':True,'room_id':'landmark_S','sha256':repair['glb_sha256'],'ground_support_samples':len(repair['floor_orientation']['downward_front_face_rays']),'other_source_blends_unchanged':True},indent=2))
