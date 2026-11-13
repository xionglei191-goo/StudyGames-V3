"""Verify the delivered household replacement and record its exact scope."""
from pathlib import Path
import hashlib,json,struct
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/verification/home-living-hub-20261113'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def write(p,data):p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')

base=read(OUT/'baseline.json');model=read(OUT/'model-report.json')
runtime=read(OUT/'runtime-report.json');native=read(OUT/'native-report.json')
household=read(OUT/'household/results.json');refs=read(OUT/'reference-check.json')
assert runtime['passed'] and native['passed'] and household['failed']==0
assert refs['error_count']==0 and refs['warning_count']==0
assert not model['changed_protected_objects']
changed_assets=[q['path'] for q in base['assets'] if not Path(q['path']).exists() or sha(Path(q['path']))!=q['sha256']]
assert changed_assets==[str(ROOT/'game/assets/interiors/home.glb')]
saves=[q for q in base['saves'] if Path(q['path']).name in ['progress.json','progress.json.bak','profile.json','island-save-v1.json','island-save-v1.json.bak']]
assert all(Path(q['path']).exists() and sha(Path(q['path']))==q['sha256'] for q in saves)
changed_code=[str(Path(q['path']).relative_to(ROOT)).replace('\\','/') for q in base['code'] if sha(Path(q['path']))!=q['sha256']]
allowed={'game/data/home_hierarchy.json','game/data/interiors_manifest.json','game/scripts/home_catalog.gd',
    'game/scripts/home_controller.gd','game/scripts/imported_interior.gd','game/scripts/main.gd','game/ui/world_map.gd'}
assert set(changed_code)==allowed
target=ROOT/'game/assets/interiors/home.glb'
assert sha(target)==sha(ROOT/model['glb'])==model['export']['sha256']
captures=[]
for row in native['captures']:
    path=OUT/row['image']
    width,height=struct.unpack('>II',path.read_bytes()[16:24])
    captures.append({**row,'image_pixels':[width,height],'sha256':sha(path)})
report={'status':'completed','date':'2026-11-13','request':'那继续完成模型修改，并进行替换',
    'source_blend':model['blend'],'source_glb':model['glb'],'runtime_glb':'game/assets/interiors/home.glb',
    'runtime_sha256':sha(target),'runtime_matches_source':True,
    'preserved_source_objects':model['preserved_objects'],'baseline_assets':len(base['assets']),
    'only_existing_asset_replaced':'game/assets/interiors/home.glb',
    'six_child_rooms_unchanged':True,'production_save_files_checked':len(saves),'production_saves_unchanged':True,
    'unrelated_existing_code_unchanged':True,'changed_existing_code':changed_code,
    'headless_checks':len(runtime['checks']),'native_checks':len(native['checks']),
    'actual_routes':len(native['routes']),'actual_transitions':len(native['transitions']),
    'household_checks':household['passed'],'reference_files_checked':refs['files_checked'],
    'full_gameplay_suite_run':False,'captures':captures,
    'launch':'启动字母岛.cmd','scope':'current local project; older packaged EXE/PCK and web exports are not rebuilt'}
write(OUT/'delivery.json',report)
manifest_path=ROOT/'docs/planning/home-redesign-20261113/asset-manifest-v06.json'
manifest=read(manifest_path)
manifest.update(status='implemented_and_verified',production_model_modified=True,concept_geometry_verified_in_engine=True)
manifest['implementation']={'date':'2026-11-13','authorization':report['request'],
    'source_blend':model['blend'],'runtime_glb':report['runtime_glb'],
    'verification':'docs/verification/home-living-hub-20261113/delivery.json'}
for q in manifest['protected_baseline']:
    if q['path']=='game/assets/interiors/home.glb':
        q['unchanged']=False;q['change']='authorized runtime replacement; prior file retained in backup'
write(manifest_path,manifest)
print(json.dumps({k:report[k] for k in ['status','headless_checks','native_checks','household_checks','actual_routes','actual_transitions','production_saves_unchanged','unrelated_existing_code_unchanged']},ensure_ascii=False))
