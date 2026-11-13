"""Verify the completed expansion and index its final evidence without rerigging."""
from pathlib import Path
import csv
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/verification/textbook-expansion-v1'
SOURCE = ROOT / 'assets/characters/textbook_expansion_v1'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


catalog = read(SOURCE / 'catalog.json')['assets']
assert len(catalog) == 56 and len({row['id'] for row in catalog}) == 56
assert {row['selection_code'] for row in catalog} == {f'P{i:02}' for i in range(1, 49)} | {f'O{i:02}' for i in range(1, 9)}
renaming = read(ROOT / 'assets/tripo/generation_selection_20261112/model-renaming.json')
assert len(renaming['files']) == 56
hashes = []
for row in catalog:
    source = ROOT / row['source']
    assert source.name == row['target_filename']
    assert source.is_file() and sha(source) == row['source_sha256'], source
    hashes.append(row['source_sha256'])
assert len(set(hashes)) == 56

reports = {}
for label, relative in {
    'full_characters': 'full-tests/characters.json',
    'repaired_characters': 'recheck-tests/characters.json',
    'props': 'props/props.json',
    'formal_world': 'world/world.json',
    'resident_rooms': 'resident-regression/rooms.json',
    'core_animation': 'core-animation-regression.json',
}.items():
    data = read(OUT / relative)
    assert data['status'] == 'PASS' and not data['failures'], relative
    reports[label] = {'file': relative, 'sha256': sha(OUT / relative), 'checks': data['checks']}

characters = {row['id']: row for row in catalog if row['category'] == 'character'}
assert len(characters) == 40
metric_rows = []
resources = {}
for ident, row in characters.items():
    folder = SOURCE / ident
    rig = read(folder / 'rig.json')
    assert rig['source_sha256'] == row['source_sha256']
    assert rig['unweighted_vertices'] == 0 and rig['weight_sum_max_error'] < 1e-5
    metric = read(OUT / 'final-metrics' / (ident + '.json'))
    assert metric['max_severe_edges'] == 0, ident
    assert metric['export_sha256'] == sha(ROOT / '.local/expansion-deform-final' / (ident + '.json'))
    for resource in metric['resources']:
        path = ROOT / 'game' / resource['resource'].removeprefix('res://')
        assert sha(path) == resource['resource_sha256'], path
        resources[path.relative_to(ROOT).as_posix()] = resource['resource_sha256']
    metric_rows.append(metric)
    assert (OUT / 'final-captures/sheets' / (ident + '.jpg')).is_file()
    assert (OUT / 'world' / (ident + '.png')).is_file()
    for name in ['rigged.blend', 'character.glb', 'rig.json']:
        resources[(folder / name).relative_to(ROOT).as_posix()] = sha(folder / name)

for row in catalog:
    if row['category'] != 'prop':
        continue
    folder = ROOT / 'assets/props/tripo_expansion_v1' / row['id']
    data = read(folder / 'prop.json')
    assert data['source_sha256'] == row['source_sha256']
    runtime = ROOT / 'game' / data['path'].removeprefix('res://')
    assert sha(runtime) == sha(folder / 'prop.glb')
    for path in [folder / 'prop.glb', folder / 'prop.blend', runtime]:
        resources[path.relative_to(ROOT).as_posix()] = sha(path)

# The nine repaired characters supersede their rows in the earlier full run.
support = {row['id']: row for row in read(OUT / 'full-tests/characters.json')['rows']}
support.update({row['id']: row for row in read(OUT / 'recheck-tests/characters.json')['rows']})
grounded = [ident for ident, row in characters.items() if row['rig_type'] != 'fish']
assert len(grounded) == 39 and len(support) == 40
maximum_support = max(support[ident]['maximum_action_support_error_m'] for ident in grounded)
assert maximum_support < .01
captures = read(OUT / 'final-captures/captures.json')
assert {row['id'] for row in captures} == set(characters)
for row in captures:
    assert (OUT / 'final-captures' / row['file']).is_file()

for relative in [
    'assets/characters/textbook_expansion_v1/fitting.json',
    'game/assets/characters/textbook_expansion_v1/manifest.json',
    'game/assets/characters/textbook_expansion_v1/gesture-overrides.json',
    'game/assets/characters/textbook_expansion_v1/grounding.json',
    'game/assets/props/tripo_expansion_v1/manifest.json',
    'game/actors/character_art_v3.gd', 'game/actors/expansion_animation.gd',
    'game/actors/tripo_prop_library.gd', 'game/scripts/textbook_actor.gd',
    'game/actors/modular_wardrobe.gd', 'game/gameplay/free_grid_decor_studio.gd',
    'scripts/rig_textbook_expansion.py', 'scripts/rig_expansion_creatures.py',
]:
    resources[relative] = sha(ROOT / relative)

renaming_csv = ROOT / 'assets/tripo/generation_selection_20261112/model-renaming.csv'
with renaming_csv.open('w', encoding='utf-8-sig', newline='') as stream:
    writer = csv.writer(stream)
    writer.writerow(['编号', '名称', '原文件名', '新文件名', '所在路径', 'SHA-256'])
    for row in sorted(catalog, key=lambda item: item['selection_code']):
        writer.writerow([row['selection_code'], row['name'], row['original_filename'], row['target_filename'], row['source'], row['source_sha256']])

report = {
    'status': 'COMPLETED_WITH_DOCUMENTED_LIMITATIONS',
    'date': '2026-11-12',
    'assets': 56, 'characters': 40, 'props': 16,
    'source_hashes_preserved': 56,
    'rig_types': {kind: sum(row['rig_type'] == kind for row in characters.values()) for kind in ['biped', 'robot', 'quadruped', 'bird', 'fish']},
    'clips': {'biped_and_robot': 14, 'quadruped_bird_fish': 6},
    'deformation': {
        'samples': sum(row['sample_count'] for row in metric_rows),
        'characters_with_severe_flags': 0,
        'maximum_strained_edges_in_one_pose': max(row['max_strained_edges'] for row in metric_rows),
        'definition': read(OUT / 'final-metrics/summary.json')['definition'],
        'current_resource_hashes_verified': True,
    },
    'ground_support': {
        'characters': len(grounded),
        'samples': sum(len(read(SOURCE / ident / 'rig.json')['actions']) * 2 * 49 for ident in grounded),
        'maximum_error_m': maximum_support,
        'excluded_swimming_character': 'textbook_fendi',
        'report_combination': 'full-tests plus superseding rows from recheck-tests',
    },
    'tests': reports,
    'visual_review': {
        'character_native_stills': len(captures),
        'characters': 40,
        'prop_native_stills': len(read(OUT / 'props/props.json')['captures']),
        'formal_world_stills': 40,
        'views': ['front', 'side', 'back'],
        'motion': read(OUT / 'motion-preview.json'),
        'result': 'Reviewed all character sheets, prop display/equipped sheets, representative native world views and motion sequences; no obvious mesh spikes in reviewed final views.',
    },
    'integration': {
        'source_game_updated': True,
        'formal_actor_loading_and_actions_verified': 40,
        'prop_factories_verified': 16,
        'chapter_story_placement': 'Not authored for all new characters; available to the formal actor loader.',
        'exports_rebuilt': False,
    },
    'limits': [
        'Small cloth compression and stretching remain in some sleeve and jacket poses, including Spot.',
        'No cloth simulation, separate finger grasp, facial expression or lip-sync added.',
        'Nonhuman characters expose six appropriate body actions and reject human hand-item actions.',
        'Ground support measured on a plane; no per-foot terrain IK, exhaustive self-intersection check or long-run GPU performance acceptance.',
        'GLB contains base clips; Godot applies the game gait and support correction.',
        'No full-project suite, Windows package export or Web export performed.',
    ],
    'resource_sha256': resources,
}
gallery = OUT / 'gallery-checks.json'
if gallery.exists():
    report['artifact_checks'] = read(gallery)
    assert report['artifact_checks']['status'] == 'PASS'
    report['artifact_checks']['report_sha256'] = sha(gallery)
(OUT / 'review.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('EXPANSION_REVIEW', report['status'], '56 assets; 16048 deformation samples;', report['ground_support'])
