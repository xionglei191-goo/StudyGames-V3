"""Check household source exports, read-only originals, bindings and cached audio.

This validates assets and source provenance. Native physics, UI and captures are
separate Godot reports; passing this file does not certify learning efficacy.
"""
from pathlib import Path
import hashlib
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/verification/home-hierarchy-v1'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else 'missing'


def main():
    spec = importlib.util.spec_from_file_location('interior_checks', ROOT / 'assets/blender/interiors/scripts/validate_interiors.py')
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    baseline = json.loads((OUT / 'before.json').read_text('utf-8'))
    data = json.loads((ROOT / 'game/data/home_hierarchy.json').read_text('utf-8'))
    source = json.loads((ROOT / 'assets/blender/interiors/interiors_manifest.json').read_text('utf-8'))
    runtime = json.loads((ROOT / 'game/data/interiors_manifest.json').read_text('utf-8'))
    checks, errors = [], []

    def check(name, passed):
        checks.append({'name': name, 'passed': bool(passed)})
        if not passed:
            errors.append(name)

    protected = {}
    for group in ['protected_assets', 'textbook_sources']:
        changed = [path for path, sha in baseline[group].items() if digest(ROOT / path) != sha.lower()]
        protected[group] = {'checked': len(baseline[group]), 'changed': changed}
        check(group + '_unchanged', not changed)

    check('eight_distinct_household_rooms', len(data['rooms']) == 8 and len(set(data['room_ids'])) == 8)
    check('runtime_contains_42_scenes', len(runtime['rooms']) == 42)
    runtime_by_id = {r['room_id']: r for r in runtime['rooms']}
    reports = []
    for room in data['rooms']:
        rid = room['room_id']
        entry = next(r for r in source['rooms'] if r['room_id'] == rid)
        report = checker.check_room(entry)
        reports.append(report)
        check('asset_structure_and_reachability/' + rid, not report['errors'])
        check('runtime_export_hash/' + rid, digest(ROOT / 'game/assets/interiors' / (rid + '.glb')) == entry['glb_sha256'] == runtime_by_id[rid]['source_sha256'])
        check('five_unique_household_points/' + rid, len(room['anchors']) == 5 and len({a['node_name'] for a in room['anchors']}) == 5)
        raw, binary = checker.glb(ROOT / entry['glb'])
        nodes, transforms = checker.world_nodes(raw)
        names = {n.get('name'): i for i, n in enumerate(nodes)}
        points = {name: checker.transform(transforms[names[name]], [0, 0, 0]) for name in checker.COMMON}
        floor = checker.check_star_floor(raw, binary, nodes, transforms, points)
        report['floor_front_faces'] = floor
        check('floor_support_and_winding/' + rid, floor['passed'])
        check('three_task_prop_roots/' + rid, all('HOME_TASK_' + phase in names for phase in ['BEFORE', 'MIDDLE', 'AFTER']))
        if rid == 'home_estate':
            check('seven_physical_door_markers', all('SG_DOOR_' + child.upper() in names for child in data['room_ids'] if child != rid))
        for index, anchor in enumerate(room['anchors'], 1):
            quote = anchor['source']
            audio = ROOT / 'game' / quote['audio'].removeprefix('res://')
            check(f'exact_cached_audio/{rid}/{index}', digest(audio) == quote['audio_source_sha256'])

    report = {'passed': not errors, 'checks': checks, 'failures': errors, 'protected': protected,
              'rooms': reports, 'scope': 'Eight household GLBs, source/runtime identity, real floor winding, 0.32 m radius conservative navigation grid, anchors, 40 cached audio hashes, original assets and eight textbook JSON hashes. Engine acceptance is separate.'}
    (OUT / 'asset-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'passed': report['passed'], 'checks': len(checks), 'failures': errors, 'protected': protected}, ensure_ascii=False))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
