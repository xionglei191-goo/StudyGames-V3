"""Read-only source/registry/report checks for the final art delivery snapshot."""
from __future__ import annotations

from collections import Counter
import csv
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/art/story_props_v3'
OUT = ROOT / 'docs/verification/art-finish-v3/art-provenance-review.json'

# Independently reviewed against the authored Chinese actions, including
# component groups (10 and N) and combined totals. This does not test rendering.
TEEN_COUNTS = {
    'thirteen': [10, 3, 13, 13, 13, 10, 3, 13],
    'fourteen': [10, 4, 14, 14, 14, 10, 4, 14],
    'fifteen': [10, 5, 15, 15, 10, 5, 15],
    'sixteen': [10, 6, 6, 16, 10, 6, 16],
    'seventeen': [10, 7, 17, 17, 10, 17, 7, 17, 17],
    'eighteen': [10, 8, 18, 8, 18, 10, 8, 18],
    'nineteen': [10, 9, 19, 19, 19, 10, 9, 19],
}


def read(path: Path):
    return json.loads(path.read_text(encoding='utf-8'))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    errors = []
    checks = []

    def check_hash(path: Path, expected: str, kind: str) -> None:
        actual = sha(path) if path.is_file() else ''
        row = {'path': str(path.relative_to(ROOT)), 'kind': kind,
               'sha256': actual, 'matches_record': actual == expected}
        checks.append(row)
        if actual != expected:
            errors.append({'kind': kind, 'path': row['path'], 'reason': 'recorded SHA mismatch'})

    registry_path = ROOT / 'game/data/learning/story_prop_art.json'
    registry = read(registry_path)
    catalog = read(ROOT / 'game/data/learning/catalog.json')
    manifest = read(ART / 'manifest.json')
    manifest_assets = {a['id']: a for a in manifest['assets']}
    with (ART / 'coverage.csv').open(encoding='utf-8-sig', newline='') as handle:
        coverage = list(csv.DictReader(handle))
    coverage_statuses = Counter(row['status'] for row in coverage)
    if (len(coverage) != len(catalog['entries']) or
            {row['entry_id'] for row in coverage} != {entry['entry_id'] for entry in catalog['entries']} or
            any(row['status'] != 'covered' for row in coverage)):
        errors.append({'kind': 'entry_coverage', 'rows': len(coverage), 'statuses': dict(coverage_statuses)})
    plans = {}
    records = {}
    batches = []
    for plan_name, record_name in [
        ('production_plan.json', 'generation_records.json'),
        ('root_batch_plan.json', 'root_generation_records.json'),
        ('world_extra_plan.json', 'world_extra_generation_records.json'),
    ]:
        jobs = read(ART / plan_name)['jobs']
        generated = read(ART / record_name)['assets']
        duplicate_plans = [j['id'] for j in jobs if j['id'] in plans]
        duplicate_records = [r['id'] for r in generated if r['id'] in records]
        if duplicate_plans or duplicate_records:
            errors.append({'kind': 'batch_merge', 'batch': plan_name,
                           'duplicate_plan_ids': duplicate_plans,
                           'duplicate_record_ids': duplicate_records})
        plans.update({j['id']: j for j in jobs})
        records.update({r['id']: r for r in generated})
        batches.append({'plan': plan_name, 'records': record_name,
                        'planned': len(jobs), 'recorded': len(generated)})
    if set(plans) != set(records):
        errors.append({'kind': 'batch_merge', 'unrecorded': sorted(set(plans) - set(records)),
                       'unplanned': sorted(set(records) - set(plans))})
    correction_path = ART / 'correction_generation_records.json'
    corrections = read(correction_path)['assets'] if correction_path.exists() else []
    for correction in corrections:
        if correction['id'] not in plans:
            errors.append({'kind': 'correction_merge', 'id': correction['id'], 'reason': 'unplanned correction'})
        records[correction['id']] = correction
    if corrections:
        batches.append({'records': correction_path.name, 'overrides': len(corrections),
                        'ids': [r['id'] for r in corrections], 'merge_order': 'applied last'})
    generated_rows = []
    for aid, plan in plans.items():
        record = records.get(aid, {})
        source = ART / 'source' / f'{aid}.png'
        runtime = ROOT / 'game/assets/learning/story_props_v3' / f'{aid}.png'
        generated = Path(record.get('generated_source', ''))
        expected = manifest_assets.get(aid, {}).get('sha256', '')
        hashes = {name: sha(path) if path.is_file() else ''
                  for name, path in [('generated_original', generated), ('source', source), ('runtime', runtime)]}
        effective_prompt = record.get('prompt') or plan.get('prompt', '')
        runtime_parts = record.get('runtime_parts', {})
        row = {'id': aid, 'record_status': record.get('status'),
               'has_prompt': bool(effective_prompt), 'prompt_matches_manifest': effective_prompt == manifest_assets.get(aid, {}).get('prompt'),
               'runtime_parts': runtime_parts,
               'runtime_parts_match': runtime_parts == registry['assets'].get(aid, {}).get('runtime_parts', {}) == manifest_assets.get(aid, {}).get('runtime_parts', {}),
               'hashes': hashes,
               'manifest_sha256': expected, 'registry_status': registry['assets'].get(aid, {}).get('status')}
        row['consistent'] = (bool(expected) and all(h == expected for h in hashes.values())
                             and row['record_status'] == 'generated' and row['has_prompt']
                             and row['prompt_matches_manifest'] and row['runtime_parts_match']
                             and row['registry_status'] == 'available')
        if not row['consistent']:
            errors.append({'kind': 'generated_provenance', 'id': aid, 'details': row})
        generated_rows.append(row)

    reused_rows = []
    for aid, asset in manifest_assets.items():
        if aid in plans:
            continue
        path = ROOT / 'game' / asset['path'].removeprefix('res://')
        check_hash(path, asset['sha256'], 'reused_story_asset')
        reused_rows.append({'id': aid, 'origin': asset.get('origin'), 'sha256': sha(path)})

    numbers = []
    source_action_count = 0
    for sid, story in registry['stories'].items():
        source_steps = catalog['stories'][sid]['steps']
        for i, step in enumerate(story['steps']):
            source_action_count += 1
            if step['source_action'] != source_steps[i]['action']:
                errors.append({'kind': 'source_action', 'story_id': sid, 'position': i + 1})
        word = story['word']
        if word in TEEN_COUNTS:
            actual = [s.get('count') for s in story['steps']]
            entities = sorted(set(s['prop_id'] for s in story['steps']))
            row = {'story_id': sid, 'word': word, 'expected_counts': TEEN_COUNTS[word],
                   'actual_counts': actual, 'entities': entities,
                   'source_actions': [s['source_action'] for s in story['steps']],
                   'pass': actual == TEEN_COUNTS[word] and entities == ['bead']}
            numbers.append(row)
            if not row['pass']:
                errors.append({'kind': 'teen_quantity', 'word': word})
    if {n['word'] for n in numbers} != set(TEEN_COUNTS):
        errors.append({'kind': 'teen_quantity', 'reason': 'one or more expected stories absent'})

    world_path = ROOT / 'assets/art/world_refresh_v3/manifest.json'
    world = read(world_path)
    check_hash(ROOT / world['source_script'], world['source_script_sha256'], 'world_source_script')
    editable = world['editable_source']
    check_hash(world_path.parent / editable['path'], editable['sha256'], 'world_editable_source')
    for asset in world['assets']:
        check_hash(world_path.parent / asset['source'], asset['sha256'], 'world_source_glb')
        check_hash(ROOT / asset['runtime'], asset['sha256'], 'world_runtime_glb')
    for texture in world['textures']:
        check_hash(world_path.parent / texture['path'], texture['sha256'], 'world_source_texture')
        check_hash(ROOT / 'game/assets/world_refresh_v3' / Path(texture['path']).name,
                   texture['sha256'], 'world_runtime_texture')
    for report in world['validation']['reports']:
        check_hash(ROOT / report['path'], report['sha256'], 'world_report')
        for capture in report.get('captures', []):
            check_hash(ROOT / capture['path'], capture['sha256'], 'world_capture')

    root_reports = []
    for filename in ['root-png-alpha-review.json', 'root-png-visual-review.json']:
        report_path = OUT.parent / filename
        data = read(report_path)
        for asset in data['assets']:
            path = ROOT / asset.get('path', f"assets/art/story_props_v3/source/{asset['id']}.png")
            check_hash(path, asset['sha256'], filename)
        root_reports.append({'path': str(report_path.relative_to(ROOT)), 'sha256': sha(report_path),
                             'asset_hashes_checked': len(data['assets'])})

    statuses = Counter(a['status'] for a in registry['assets'].values())
    step_statuses = Counter(s['status'] for story in registry['stories'].values() for s in story['steps'])
    if any(status != 'available' for status in statuses):
        errors.append({'kind': 'asset_availability', 'statuses': dict(statuses)})
    if step_statuses.get('pending_asset', 0) or step_statuses.get('missing_concrete_art', 0):
        errors.append({'kind': 'step_availability', 'statuses': dict(step_statuses)})
    result = {'status': 'PASS' if not errors else 'FAIL',
              'scope': 'Independent read-only provenance, current recorded SHA checks, source action preservation and reviewed 13-19 quantity contracts. No renderer launched.',
              'registry_sha256': sha(registry_path), 'manifest_sha256': sha(ART / 'manifest.json'),
              'summary': {'generated_assets': len(generated_rows), 'reused_assets': len(reused_rows),
                          'registry_assets': len(registry['assets']), 'asset_statuses': dict(statuses),
                          'coverage_entries': len(coverage), 'coverage_statuses': dict(coverage_statuses),
                          'source_actions_compared': source_action_count, 'step_statuses': dict(step_statuses),
                          'teen_stories_reviewed': len(numbers), 'recorded_file_hashes_checked': len(checks),
                          'errors': len(errors)},
              'batches': batches, 'generated_assets': generated_rows, 'reused_assets': reused_rows,
              'teen_quantity_review': numbers, 'recorded_file_checks': checks,
              'root_review_reports': root_reports, 'errors': errors,
              'limits': ['Known semantic rules and reviewed quantities do not establish exhaustive natural-language correctness.',
                         'Source and runtime byte identity does not establish on-screen readability, animation contact or performance.',
                         'Violin string count is completed with four runtime lines over an image-generated body; final rendered acceptance belongs to the engine validation report.',
                         'This is a hash-bound snapshot. Rerun after replacing any source image or registry.']}
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'status': result['status'], **result['summary'], 'errors_detail': errors}, ensure_ascii=False))
    raise SystemExit(bool(errors))


if __name__ == '__main__':
    main()
