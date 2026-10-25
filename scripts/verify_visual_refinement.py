"""Verify the two home art samples and preservation of pre-existing source art."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/verification/visual-refinement'
ROOMS = ('home_estate', 'home')


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def load_checks():
    spec = importlib.util.spec_from_file_location('interior_checks', ROOT / 'assets/blender/interiors/scripts/validate_interiors.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def protected_geometry(path, c):
    data, binary = c.glb(path)
    nodes, matrices = c.world_nodes(data)
    result = {}
    for index, node in enumerate(nodes):
        name = node.get('name', '')
        if not name.startswith(('SG_', 'HOME_TASK_')):
            continue
        item = {'world': [[round(v, 5) for v in row] for row in matrices[index]]}
        if name.startswith(('SG_FLOOR_', 'SG_COLLIDER_')):
            geometry = []
            for primitive in data['meshes'][node['mesh']]['primitives']:
                positions = c.accessor_values(data, binary, primitive['attributes']['POSITION'])
                indices = [list(value) for value in c.accessor_values(data, binary, primitive['indices'])]
                geometry.append({'vertices': [[round(v, 5) for v in row] for row in positions], 'indices': indices})
            item['mesh'] = geometry
        result[name] = item
    return result


def snapshot():
    OUT.mkdir(parents=True, exist_ok=True)
    destination = OUT / 'asset-baseline.json'
    if destination.exists():
        raise SystemExit('Existing baseline is immutable; refusing to overwrite.')
    source = json.loads((ROOT / 'assets/blender/interiors/interiors_manifest.json').read_text('utf-8'))
    entries = {entry['room_id']: entry for entry in source['rooms']}
    protected = {}
    for entry in source['rooms']:
        for key in ('blend', 'glb', 'preview'):
            path = ROOT / entry[key]
            protected[path.relative_to(ROOT).as_posix()] = digest(path)
        if entry['room_id'] not in ROOMS:
            path = ROOT / 'game/assets/interiors' / (entry['room_id'] + '.glb')
            protected[path.relative_to(ROOT).as_posix()] = digest(path)
    c = load_checks()
    data = {'protected_files': protected, 'rooms': {room: entries[room] for room in ROOMS},
            'semantics': {room: protected_geometry(ROOT / entries[room]['glb'], c) for room in ROOMS}}
    destination.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'baseline_files': len(protected), 'rooms': list(ROOMS)}))


def verify():
    baseline = json.loads((OUT / 'asset-baseline.json').read_text('utf-8'))
    source = json.loads((ROOT / 'assets/blender/interiors/interiors_manifest.json').read_text('utf-8'))
    runtime = json.loads((ROOT / 'game/data/interiors_manifest.json').read_text('utf-8'))
    entries = {entry['room_id']: entry for entry in source['rooms']}
    runtime_entries = {entry['room_id']: entry for entry in runtime['rooms']}
    checks = []
    reports = []

    def check(name, ok, detail=None):
        checks.append({'name': name, 'passed': bool(ok), 'detail': detail})

    changed = [name for name, sha in baseline['protected_files'].items()
               if not (ROOT / name).is_file() or digest(ROOT / name) != sha]
    check('prior_sources_previews_and_other_runtime_rooms_unchanged', not changed, changed)
    c = load_checks()
    for room in ROOMS:
        entry = entries[room]
        report = c.check_room(entry)
        reports.append(report)
        check(room + '/structure_and_navigation', not report['errors'], report['errors'])
        check(room + '/versioned_editable_source', entry['blend'].endswith('_v03.blend') and entry['glb'].endswith('_v03.glb'))
        check(room + '/source_runtime_identity', digest(ROOT / entry['glb']) == entry['glb_sha256'] == runtime_entries[room]['source_sha256'] == digest(ROOT / 'game/assets/interiors' / (room + '.glb')))
        current = protected_geometry(ROOT / entry['glb'], c)
        mismatches = [name for name, value in baseline['semantics'][room].items() if current.get(name) != value]
        check(room + '/anchors_floors_collision_geometry_unchanged', not mismatches, mismatches)
        check(room + '/bounds_unchanged', entry['bounds'] == baseline['rooms'][room]['bounds'])
        data, binary = c.glb(ROOT / entry['glb'])
        nodes, matrices = c.world_nodes(data)
        points = {node['name']: c.transform(matrices[i], [0, 0, 0]) for i, node in enumerate(nodes)
                  if node.get('name', '').startswith(('SG_SPAWN', 'SG_EXIT', 'SG_MEMORY_', 'SG_HOUSE_ENTRY'))}
        floor = c.check_star_floor(data, binary, nodes, matrices, points)
        check(room + '/indexed_floor_winding_and_support', floor['passed'], floor)
    passed = all(item['passed'] for item in checks)
    output = {'passed': passed, 'checks': checks, 'rooms': reports,
              'protected_files': len(baseline['protected_files']),
              'scope': 'Versioned DCC sources, embedded GLB structure, unchanged semantic transforms and collision geometry, indexed floor support, conservative connectivity; native gameplay acceptance reported separately.'}
    (OUT / 'asset-report.json').write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'passed': passed, 'checks': len(checks), 'failures': [item for item in checks if not item['passed']]}, ensure_ascii=False))
    return 0 if passed else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--snapshot', action='store_true')
    args = parser.parse_args()
    if args.snapshot:
        snapshot()
    else:
        raise SystemExit(verify())
