"""Verify the indoor circulation asset and preserve all existing household art."""
from pathlib import Path
import hashlib
import importlib.util
import json

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/verification/home-indoor-v3'


def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else 'missing'


def main():
    spec=importlib.util.spec_from_file_location('checks',ROOT/'assets/blender/interiors/scripts/validate_interiors.py')
    c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
    baseline=json.loads((OUT/'before.json').read_text('utf-8'))
    prior=json.loads((ROOT/'docs/verification/home-hierarchy-v1/before.json').read_text('utf-8'))
    data=json.loads((ROOT/'game/data/home_hierarchy.json').read_text('utf-8'))
    source=json.loads((ROOT/'assets/blender/interiors/interiors_manifest.json').read_text('utf-8'))
    runtime=json.loads((ROOT/'game/data/interiors_manifest.json').read_text('utf-8'))
    checks=[];reports=[]
    def check(name,value):checks.append({'name':name,'passed':bool(value)})
    changed=[n for n,sha in baseline['protected_assets'].items() if digest(ROOT/n)!=sha]
    book_changed=[n for n,sha in prior['textbook_sources'].items() if digest(ROOT/n)!=sha.lower()]
    check('all_existing_models_and_previews_unchanged',not changed)
    check('eight_textbook_sources_unchanged',not book_changed)
    check('forty_points_and_eight_household_tasks_preserved',len(data['rooms'])==8 and sum(len(r['anchors']) for r in data['rooms'])==40)
    hall=next((r for r in data.get('routes',[]) if r['room_id']=='home_hall'),{})
    check('one_indoor_navigation_space',len(data.get('routes',[]))==1 and hall.get('indoor') is True)
    check('hall_adds_no_learning_points_or_task',not hall.get('anchors') and not hall.get('task'))
    check('same_home_indoor_state',hall.get('scene_level')==2 and hall.get('same_property_as')=='home_estate')
    check('hall_returns_to_courtyard_front_door',hall.get('return_to')=={'room_id':'home_estate','interaction_id':'house_entry'})
    check('seven_indoor_door_bindings',len(hall.get('model_bindings',{}).get('doors',{}))==7)
    check('forty_three_runtime_assets',len(runtime['rooms'])==43)
    for room in data['rooms']+[hall]:
        rid=room['room_id'];entry=next(r for r in source['rooms'] if r['room_id']==rid)
        report=c.check_room(entry);reports.append(report)
        check('structure_and_conservative_navigation/'+rid,not report['errors'])
        raw,binary=c.glb(ROOT/entry['glb']);nodes,world=c.world_nodes(raw);names={n.get('name'):i for i,n in enumerate(nodes)}
        required=c.COMMON if rid!='home_hall' else ['SG_SPAWN','SG_EXIT']+list(hall['model_bindings']['doors'].values())
        points={n:c.transform(world[names[n]],[0,0,0]) for n in required}
        report['floor_front_faces']=c.check_star_floor(raw,binary,nodes,world,points)
        check('real_floor_support/'+rid,report['floor_front_faces']['passed'])
        target=next(r for r in runtime['rooms'] if r['room_id']==rid)
        check('source_runtime_identity/'+rid,digest(ROOT/'game/assets/interiors'/(rid+'.glb'))==entry['glb_sha256']==target['source_sha256'])
        if rid=='home_estate':check('front_door_enters_hall',room['model_bindings']['entry_destination']=='home_hall')
        elif rid!='home_hall':check('room_returns_to_own_indoor_door/'+rid,room['return_to']=={'room_id':'home_hall','interaction_id':rid+'_gate'})
        if rid=='home_hall':
            check('hall_has_no_fake_memory_or_task_nodes',not any(n.startswith(('SG_MEMORY_','HOME_TASK_')) for n in names))
            check('new_editable_hall_source',entry['blend'].endswith('home_hall_v01.blend'))
        else:
            check('existing_three_state_household_props/'+rid,all('HOME_TASK_'+s in names for s in ['BEFORE','MIDDLE','AFTER']))
            for i,a in enumerate(room['anchors'],1):
                s=a['source'];check(f'cached_audio/{rid}/{i}',digest(ROOT/'game'/s['audio'].removeprefix('res://'))==s['audio_source_sha256'])
    failures=[x['name'] for x in checks if not x['passed']]
    report={'passed':not failures,'checks':checks,'failures':failures,'rooms':reports,
            'protected':{'assets_checked':len(baseline['protected_assets']),'changed_assets':changed,'textbooks_checked':len(prior['textbook_sources']),'changed_textbooks':book_changed},
            'scope':'Indoor navigation asset, seven physical door anchors, floor winding and conservative connectivity, source/runtime identities, existing art/audio preservation. Engine acceptance is separate.'}
    (OUT/'asset-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'passed':not failures,'checks':len(checks),'failures':failures,'protected':report['protected']},ensure_ascii=False))
    return 1 if failures else 0


if __name__=='__main__':raise SystemExit(main())
