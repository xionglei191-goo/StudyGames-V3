"""Validate and install only the new living-room GLB and household route metadata."""
from pathlib import Path
import copy, hashlib, json, shutil, sys
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/verification/home-living-hub-20261113'
sys.path.insert(0,str(ROOT/'scripts'))
from sync_blender_interiors import inspect_glb

def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path,data):
    tmp=path.with_suffix(path.suffix+'.tmp')
    tmp.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    tmp.replace(path)
def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

model=read(OUT/'model-report.json')
blend=ROOT/model['blend']; glb=ROOT/model['glb']
check=inspect_glb(glb,'home')
assert sha(glb)==model['export']['sha256']
assert not model['changed_protected_objects']
doors={r['room']:'SG_DOOR_'+r['room'].upper() for r in model['doors']}
source_path=ROOT/'assets/blender/interiors/interiors_manifest.json'
game_path=ROOT/'game/data/interiors_manifest.json'
source=read(source_path);game=read(game_path)
se=next(e for e in source['rooms'] if e['room_id']=='home')
ge=next(e for e in game['rooms'] if e['room_id']=='home')
source_other=copy.deepcopy([e for e in source['rooms'] if e['room_id']!='home'])
game_other=copy.deepcopy([e for e in game['rooms'] if e['room_id']!='home'])
common={'bounds':[round(x,4) for x in model['bounds']], 'model_version':'v08_living_hub',
        'triangles':model['export']['triangles_instanced'], 'refinement_revision':'living-hub-20261113',
        'preview':'docs/verification/home-living-hub-20261113/overview.png'}
se.update(common,blend=blend.relative_to(ROOT).as_posix(),glb=glb.relative_to(ROOT).as_posix(),
          glb_sha256=sha(glb),anchors=model['source_contract']['anchors'])
for row in model['doors']:
    se['anchors'].append({'name':doors[row['room']],'label':row['label'],
        'position_blender':[row['side']*8.55,row['y'],0],
        'position_godot':[row['side']*8.55,0,-row['y']]})
ge.update(common,source_blend=se['blend'],source_glb=se['glb'],source_sha256=sha(glb),
          validation={**check,'triangles':common['triangles']})
assert source_other==[e for e in source['rooms'] if e['room_id']!='home']
assert game_other==[e for e in game['rooms'] if e['room_id']!='home']

hierarchy_path=ROOT/'game/data/home_hierarchy.json'
h=read(hierarchy_path)
learning_before={q['room_id']:{k:copy.deepcopy(q[k]) for k in ['anchors','task']} for q in h['rooms']}
by_id={q['room_id']:q for q in h['rooms']}
living=by_id['home']
living.update(parent_room='home_estate',return_to={'room_id':'home_estate','interaction_id':'house_entry'},
    composition='方正客厅内设置开放玄关，两侧连续墙体中的六个门洞连接原有独立房间；家具、五个记忆点及生活任务沿用。',
    model_bindings={'doors':doors,'entry_flow':'exterior_entry_to_living_room'},camera_size=26.3)
for rid in doors:
    by_id[rid].update(parent_room='home',return_to={'room_id':'home','interaction_id':rid+'_gate'})
living['areas']=[{k:by_id[rid][k] for k in ['room_id','name','scene_level','parent_room']}|{'separate_scene':True} for rid in doors]
estate=by_id['home_estate']
estate['theme']='穿过石径与花园，走到住宅正门；入户就是客厅，从客厅前往其他六个房间。'
estate['composition']='完整住宅外观与庭院；正门直接进入方正客厅，六个房间沿客厅两侧相连。'
estate['model_bindings']['entry_destination']='home'
estate['model_bindings']['entry_flow']='front_door_then_living_room_hub'
for area in estate.get('areas',[]):
    rid=area.get('room_id')
    if rid in by_id:
        for key in ['parent_room','return_to','composition','model_bindings']:
            if key in by_id[rid]:area[key]=copy.deepcopy(by_id[rid][key])
for route in h.get('routes',[]):
    if route.get('room_id')=='home_hall':
        route.update(status='legacy_alias',redirect_to='home',name='家里的客厅（兼容入口）',
                     theme='旧门厅引用兼容到客厅，不作为独立房间进入。')
learning_after={q['room_id']:{k:q[k] for k in ['anchors','task']} for q in h['rooms']}
assert learning_before==learning_after

target=ROOT/'game/assets/interiors/home.glb'
tmp=target.with_suffix('.glb.tmp');shutil.copy2(glb,tmp)
assert sha(tmp)==sha(glb)
tmp.replace(target)
write(source_path,source);write(game_path,game);write(hierarchy_path,h)
write(OUT/'installation.json',{'runtime_asset':str(target.relative_to(ROOT)), 'sha256':sha(target),
    'source_matches_runtime':sha(glb)==sha(target),'only_home_manifest_entry_changed':True,
    'household_learning_and_tasks_unchanged':True,'room_count':7,'destination_count':len(doors),
    'legacy_hall_redirect':'home','flow':'village -> home_estate -> home -> six existing rooms'})
print('INSTALLED living hub:',check['nodes'],'nodes;',len(doors),'room doors; runtime SHA-256',sha(target))
