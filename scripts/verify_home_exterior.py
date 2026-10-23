"""Focused v02 asset/contract checks; never overwrite historical v01 evidence."""
from pathlib import Path
import hashlib
import importlib.util
import json

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/verification/home-exterior-v2'


def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else 'missing'


def main():
    spec=importlib.util.spec_from_file_location('checks',ROOT/'assets/blender/interiors/scripts/validate_interiors.py')
    c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
    baseline=json.loads((OUT/'before.json').read_text('utf-8'))
    old=json.loads((ROOT/'docs/verification/home-hierarchy-v1/before.json').read_text('utf-8'))
    data=json.loads((ROOT/'game/data/home_hierarchy.json').read_text('utf-8'))
    source=json.loads((ROOT/'assets/blender/interiors/interiors_manifest.json').read_text('utf-8'))
    runtime=json.loads((ROOT/'game/data/interiors_manifest.json').read_text('utf-8'))
    checks=[];reports=[]
    def check(name,result):checks.append({'name':name,'passed':bool(result)})
    changed=[path for path,sha in baseline['protected_assets'].items() if digest(ROOT/path)!=sha]
    check('all_existing_blend_glb_preview_and_other_runtime_assets_unchanged',not changed)
    book_changed=[path for path,sha in old['textbook_sources'].items() if digest(ROOT/path)!=sha.lower()]
    check('eight_textbook_sources_unchanged',not book_changed)
    check('eight_distinct_spaces_and_seven_children',len(data['rooms'])==8 and len(set(data['room_ids']))==8)
    for room in data['rooms']:
        rid=room['room_id'];entry=next(r for r in source['rooms'] if r['room_id']==rid)
        report=c.check_room(entry);reports.append(report)
        check('asset_navigation/'+rid,not report['errors'])
        raw,binary=c.glb(ROOT/entry['glb']);nodes,world=c.world_nodes(raw);names={n.get('name'):i for i,n in enumerate(nodes)}
        points={n:c.transform(world[names[n]],[0,0,0]) for n in c.COMMON}
        report['floor_front_faces']=c.check_star_floor(raw,binary,nodes,world,points)
        check('real_floor_support/'+rid,report['floor_front_faces']['passed'])
        target=next(r for r in runtime['rooms'] if r['room_id']==rid)
        check('runtime_source_identical/'+rid,digest(ROOT/'game/assets/interiors'/(rid+'.glb'))==entry['glb_sha256']==target['source_sha256'])
        check('three_household_states/'+rid,all('HOME_TASK_'+s in names for s in ['BEFORE','MIDDLE','AFTER']))
        if rid=='home_estate':
            check('new_editable_source_version',entry['blend'].endswith('home_estate_v02.blend'))
            check('unique_front_door_anchor','SG_HOUSE_ENTRY' in names)
            check('front_door_bound_in_catalogue',room['model_bindings']['entry']=='SG_HOUSE_ENTRY')
            check('three_complete_roof_volumes',all(n+'_Roof_Ridge' in names for n in ['West','Main','East']))
        else:check('child_returns_to_front_door/'+rid,room['return_to']=={'room_id':'home_estate','interaction_id':'house_entry'})
        for i,a in enumerate(room['anchors']):
            s=a['source'];check(f'cached_audio/{rid}/{i+1}',digest(ROOT/'game'/s['audio'].removeprefix('res://'))==s['audio_source_sha256'])
    failures=[x['name'] for x in checks if not x['passed']]
    report={'passed':not failures,'checks':checks,'failures':failures,'rooms':reports,
            'protected':{'assets_checked':len(baseline['protected_assets']),'changed_assets':changed,'textbooks_checked':len(old['textbook_sources']),'changed_textbooks':book_changed},
            'scope':'Asset geometry, front-face floor, conservative navigation, front-door contract, source/runtime identity, unchanged prior sources and seven room GLBs. Actual engine/input acceptance reported separately.'}
    (OUT/'asset-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'passed':not failures,'checks':len(checks),'failures':failures,'protected':report['protected']},ensure_ascii=False))
    return 1 if failures else 0


if __name__=='__main__':raise SystemExit(main())
