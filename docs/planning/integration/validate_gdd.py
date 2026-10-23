"""Read-only cross-domain planning audit; writes only integration_summary.json.

This checks source-to-plan joins, not gameplay or learning effectiveness.
Run after the three domain builders/validators have finished.
"""
from __future__ import annotations

import hashlib
import json
import re
import unicodedata
from collections import Counter
from datetime import datetime, timezone, timedelta
from pathlib import Path
from urllib.parse import unquote

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PLAN = ROOT / 'docs' / 'planning'
OUTPUT = HERE / 'integration_summary.json'
errors: list[dict] = []
checks = Counter()
inputs: dict[str, str] = {}


def check(ok: bool, group: str, context: str) -> None:
    checks[group] += 1
    if not ok:
        errors.append({'group': group, 'context': context})


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(relative: str):
    path = PLAN / relative
    inputs[path.relative_to(ROOT).as_posix()] = sha(path)
    return json.loads(path.read_text(encoding='utf-8'))


def unique(rows: list[dict], key: str, group: str) -> dict:
    result = {row[key]: row for row in rows}
    check(len(result) == len(rows), group, f'unique {key}')
    return result


def run() -> dict:
    catalog = read('vocabulary/data/catalog.json')
    vcontract = read('vocabulary/data/integration_contract.json')
    adapted = read('vocabulary/data/mainline_entries.json')
    arcs = read('mainline/curriculum_arcs.json')
    prologue = read('mainline/alphabet_prologue.json')
    mcontract = read('mainline/integration_contract.json')
    people = read('art/textbook_characters.json')
    npcs = read('art/npc_animation_assets.json')
    environment = read('art/environment_motion_assets.json')
    mnemonic = read('art/mnemonic_story_assets.json')
    lexemes = unique(catalog['lexemes'], 'id', 'vocabulary_ids')
    stories = unique(catalog['stories'], 'id', 'vocabulary_ids')
    occurrences = unique(catalog['occurrences'], 'id', 'vocabulary_ids')
    entries = unique(adapted['entries'], 'entry_id', 'adapter')
    source_ids = {source['id'] for source in catalog['sources']}
    unit_keys = {unit['source_unit_key'] for unit in arcs['units']}
    npc_ids = {npc['id'] for npc in npcs['characters']}
    people_ids = {person['id'] for person in people['characters']}
    role_slots = {slot['id'] for slot in npcs['functional_role_slots']}
    room_ids = set(environment['scene_catalog'])
    books = {book['book_id']: book for book in catalog['books']}
    arc_books = {book['book_id']: book for book in arcs['books']}
    person_books = {book['book_id']: book for book in people['source_books']}
    check(set(books) == set(arc_books) == set(person_books), 'source_versions', 'same eight book IDs')
    for book_id, book in books.items():
        expected = book['manifest_sha256']
        check(expected == arc_books[book_id]['manifest_sha256'] == person_books[book_id]['manifest_sha256'], 'source_versions', book_id)
        source = Path(arc_books[book_id]['source_manifest'])
        check(source.exists() and sha(source) == expected, 'source_versions', f'{book_id} current manifest')
        check(book['unit_count'] == arc_books[book_id]['unit_count'], 'source_versions', f'{book_id} unit count')

    alphabet = {row['letter']['uppercase']: row for row in prologue['letters']}
    miniatures = {row['letter']: row for row in mnemonic['miniature_assets']}
    check(set(alphabet) == set(catalog['landmarks']) == set(miniatures) == set('ABCDEFGHIJKLMNOPQRSTUVWXYZ'), 'codebook', 'all 26 letters in all domains')
    for letter, anchor in catalog['landmarks'].items():
        check(anchor['anchor_en'] == alphabet[letter]['anchor']['canonical_word'] == miniatures[letter]['canonical_anchor_en'], 'codebook', letter)
        check(alphabet[letter]['scene_ref']['room_id'] == miniatures[letter]['landmark_room_id'] == f'landmark_{letter}', 'codebook', f'{letter} room')
        if letter != 'E':
            check(anchor['anchor_zh'] == alphabet[letter]['anchor']['chinese_image_name'] == miniatures[letter]['representative_label_zh'], 'codebook', f'{letter} image label')
    check(alphabet['E']['anchor']['canonical_word_zh'] == miniatures['E']['canonical_word_zh'] == '鸡蛋', 'codebook', 'E word meaning remains egg')
    check(alphabet['E']['anchor']['representative_label_zh'] == miniatures['E']['representative_label_zh'] == '蛋壳（完整蛋形）', 'codebook', 'E representation is explicit')
    check(prologue['completion_contract']['hard_required_letter_count'] == 26, 'progression', 'all 26 supported experiences required for new route')
    check(prologue['completion_contract']['completion_is_not_mastery'] is True, 'progression', 'prologue is not mastery')
    check(mcontract['curriculum_route']['legacy_save_forced_prologue_retake'] is False, 'progression', 'old save is preserved')
    check(mcontract['curriculum_route']['bridging_marks_prior_books_completed'] is False, 'progression', 'selected book does not mark earlier books learned')

    levels = [(r['level'], r['id'], r['name']) for r in vcontract['prompt_contract']['levels']]
    check(levels == [(r['level'], r['id'], r['name']) for r in mcontract['assistance']['levels']], 'help_protocol', 'mainline and vocabulary six-level semantics')
    check(levels == [(r['source_level'], r['id'], r['name']) for r in mnemonic['prompt_levels']], 'help_protocol', 'art and vocabulary six-level semantics')
    check([x[0] for x in levels] == list(range(6)), 'help_protocol', 'H0 through H5')
    for field in ['content_revision', 'codebook_revision']:
        check(vcontract[field] == adapted[field] == mcontract['vocabulary_call'][field], 'content_revisions', field)
    check(vcontract['prompt_contract']['level_zero_implies_independent'] is False, 'help_protocol', 'H0 is not automatic independence')
    check(vcontract['prompt_contract']['child_requested_replay_still_counts_as_cue'] is True, 'help_protocol', 'voluntary recall aid remains a cue')
    check('first_response_correct' not in mcontract['assistance']['unassisted_attempt_requires'], 'help_protocol', 'unassisted attempt may be incorrect')
    check('first_response_correct' in mcontract['assistance']['independent_success_requires'], 'help_protocol', 'independent success requires correct first response')
    check(set(mcontract['assistance']['unassisted_attempt_outcomes']) == {'correct', 'not_correct'}, 'help_protocol', 'incorrect unassisted response remains observed')

    for lexeme_id, lexeme in lexemes.items():
        tokens = lexeme['tokens']
        check(''.join(t['raw'] for t in tokens) == lexeme['spelling'], 'orthography', f'{lexeme_id} exact reconstruction')
        check(unicodedata.normalize('NFC', lexeme['spelling']) == lexeme['spelling'], 'orthography', f'{lexeme_id} NFC')
        position = 1
        letter_tokens = []
        repeated = Counter()
        for token in tokens:
            check(token['surface_position'] == position, 'orthography', f'{lexeme_id} character {position}')
            position += len(token['raw'])
            if token['type'] == 'letter':
                letter_tokens.append(token)
                letter = token['letter']
                repeated[letter] += 1
                check(token['occurrence'] == repeated[letter], 'orthography', f'{lexeme_id} repeat {len(letter_tokens)}')
                check(token['anchor_en'] == catalog['landmarks'][letter]['anchor_en'], 'codebook', f'{lexeme_id} letter {len(letter_tokens)}')
        check(letter_tokens == lexeme['letter_chain'], 'orthography', f'{lexeme_id} complete letter chain')
        check([t['letter_position'] for t in letter_tokens] == list(range(1, len(letter_tokens) + 1)), 'orthography', f'{lexeme_id} letter positions')
    for story_id, story in stories.items():
        lexeme = lexemes[story['lexeme_id']]
        steps = story['steps']
        check([s['raw'] for s in steps] == [t['raw'] for t in lexeme['letter_chain']], 'story_frames', f'{story_id} exact letter chain')
        check([s['letter_position'] for s in steps] == list(range(1, len(steps) + 1)), 'story_frames', f'{story_id} step ordering')
        positions = [i for f in story['frames'] for i in f['letter_positions']]
        check(positions == list(range(1, len(steps) + 1)), 'story_frames', f'{story_id} complete frame coverage')
        check(all(len(f['letter_positions']) <= 4 for f in story['frames']), 'story_frames', f'{story_id} maximum four active letters')
        check([(p['level'], p['name']) for p in story['prompt_ladder']] == [(n, label) for n, _, label in levels], 'help_protocol', story_id)

    check(set(entries) == set(occurrences), 'adapter', 'all occurrence IDs preserved')
    unit_entries: dict[str, set] = {key: set() for key in unit_keys}
    association_count = 0
    for entry_id, occurrence in occurrences.items():
        entry = entries[entry_id]
        lexeme = lexemes[occurrence['lexeme_id']]
        story = stories[occurrence['story_id']]
        check(entry['provider_occurrence_id'] == entry_id, 'adapter', f'{entry_id} source identity')
        check(entry['lexeme_id'] == occurrence['lexeme_id'], 'adapter', f'{entry_id} lexeme')
        check(entry['sense_id'] == entry['story_id'] == occurrence['story_id'], 'adapter', f'{entry_id} sense')
        check(entry['spelling_display'] == occurrence['spelling'] == lexeme['spelling'], 'adapter', f'{entry_id} spelling')
        check(entry['source_ids'] == occurrence['source_ids'] and set(entry['source_ids']).issubset(source_ids), 'adapter', f'{entry_id} sources')
        check(entry['reconstruction_tokens'] == lexeme['tokens'], 'adapter', f'{entry_id} tokens')
        check([x['raw_character'] for x in entry['letter_slots']] == [x['raw'] for x in lexeme['letter_chain']], 'adapter', f'{entry_id} letter slots')
        check(entry['memory_home']['storage_slot'] == story['storage']['storage_slot'], 'adapter', f'{entry_id} stable storage')
        check(entry['requirement'] == occurrence['requirement'], 'requirements', entry_id)
        permission = vcontract['requirement_permissions'][occurrence['requirement']]
        check(entry['task_permissions'] == permission, 'requirements', f'{entry_id} task permissions')
        check(permission['formal_spelling_eligible'] == (occurrence['requirement'] == 'listen_speak_read_write'), 'requirements', f'{entry_id} no elevated spelling demand')
        check(permission['spelling_required_for_story_progress'] is False, 'requirements', f'{entry_id} story access')
        expected_units = [f'unit-{number}' for number in occurrence['unit_numbers']]
        check(entry['source_unit']['book_id'] == occurrence['book_id'] and entry['source_unit']['unit_ids'] == expected_units, 'unit_joins', entry_id)
        for unit_id in expected_units:
            key = f"{occurrence['book_id']}/{unit_id}"
            check(key in unit_keys, 'unit_joins', f'{entry_id} -> {key}')
            if key in unit_entries:
                unit_entries[key].add(entry_id)
                association_count += 1
    adapter_index = {f"{r['book_id']}/{r['unit_id']}": r['entry_ids'] for r in adapted['unit_index']}
    check(set(adapter_index) == unit_keys, 'unit_joins', 'adapter unit index exact coverage')
    unit_report = []
    for unit in arcs['units']:
        key = unit['source_unit_key']
        join = unit['vocabulary_join']['entry_ids']
        check(len(join) == len(set(join)) and set(join) == unit_entries[key] == set(adapter_index[key]), 'unit_joins', f'{key} exact three-way join')
        check(set(unit['room_ids']).issubset(room_ids), 'world_refs', key)
        cast = unit['cast_binding']
        check(set(cast['source_character_candidates']).issubset(people_ids), 'actor_refs', key)
        check(cast['automatic_cast_from_name_mentions'] is False, 'actor_refs', f'{key} candidate is not approved cast')
        for role in cast.get('planned_role_bindings', []):
            if 'npc_id' in role:
                check(role['npc_id'] in npc_ids, 'actor_refs', f'{key}:{role["role"]}')
            if 'functional_role_slot_id' in role:
                check(role['functional_role_slot_id'] in role_slots, 'actor_refs', f'{key}:{role["role"]} slot')
        unit_report.append({'source_unit_key': key, 'vocabulary_candidate_count': len(join), 'event_evidence': unit['source']['evidence_level'], 'cast_status': cast['status']})
    linked_textbook = {npc.get('textbook_character_id') for npc in npcs['characters'] if npc['source_kind'] == 'textbook'}
    check(linked_textbook == people_ids, 'actor_refs', 'all confirmed source identities included in first batch')
    check(all(npc['first_batch'] for npc in npcs['characters'] if npc['source_kind'] == 'textbook'), 'actor_refs', 'first batch flags')
    pose_specs = unique(npcs['pose_specs'], 'id', 'special_rig_plans')
    basic_specs = unique(npcs['special_rig_basic_specs'], 'id', 'special_rig_plans')
    work_orders = unique(npcs['special_action_work_orders'], 'id', 'special_rig_plans')
    rig_ids = {rig['id'] for rig in npcs['rig_families']}
    for spec_id, spec in basic_specs.items():
        check(spec['rig_family_id'] in rig_ids and spec['implementation_status'] == 'planned', 'special_rig_plans', spec_id)
        check(set(spec['pose_spec_ids']).issubset(pose_specs), 'special_rig_plans', f'{spec_id} poses resolve')
    for pose_id, pose in pose_specs.items():
        check(pose['rig_family_id'] in rig_ids and pose['representation'] == 'static_key_pose', 'special_rig_plans', pose_id)
        check(pose['implementation_status'] == 'planned' and pose['source_file'] is None and pose['source_file_status'] == 'not_created', 'planning_boundary', f'{pose_id} not produced')
        check(bool(pose['specification']) and bool(pose['acceptance']), 'special_rig_plans', f'{pose_id} concrete specification')
    planned_pose_bindings = 0
    pending_behavior_bindings = 0
    for npc in npcs['characters']:
        work_id = npc.get('special_action_work_order_id')
        if work_id:
            check(work_id in work_orders, 'special_rig_plans', f'{npc["id"]} work order')
            work = work_orders[work_id]
            check(work['character_id'] == npc['id'] and work['rig_family_id'] == npc['rig_family_id'], 'special_rig_plans', f'{work_id} actor and rig')
            check(work['basic_spec_id'] in basic_specs and set(work['pose_spec_ids']).issubset(pose_specs), 'special_rig_plans', f'{work_id} specification refs')
            check(work['production_stage'] == 'P3' and work['required_before'] == 'this_character_corresponding_chapter_release', 'special_rig_plans', f'{work_id} release gate')
        for binding in npc['behavior_clip_bindings']:
            if binding['status'] == 'awaiting_special_clip_specification':
                pending_behavior_bindings += 1
            if binding['status'] == 'planned_explicit_pose_fallback_not_tested':
                planned_pose_bindings += 1
                check(binding['planned_spec_id'] in basic_specs and binding['pose_spec_id'] in pose_specs, 'special_rig_plans', f'{npc["id"]}:{binding["state_id"]} spec refs')
                pose = pose_specs[binding['pose_spec_id']]
                check(pose['rig_family_id'] == npc['rig_family_id'] and pose['behavior_state_id'] == binding['state_id'], 'special_rig_plans', f'{npc["id"]}:{binding["state_id"]} compatible pose')
    check(pending_behavior_bindings == 0 and planned_pose_bindings == 52, 'special_rig_plans', 'all 52 previously unplanned bindings have explicit specs')
    for sample in mnemonic['samples']:
        lexeme = lexemes[sample['lexeme_id']]
        story = stories[sample['story_id']]
        check(sample['sense_id'] == story['id'], 'art_story_refs', f'{sample["spelling"]} sense')
        check(len(sample['tokens']) == len(lexeme['tokens']), 'art_story_refs', f'{sample["spelling"]} token count')
        for original, artwork in zip(lexeme['tokens'], sample['tokens']):
            check(all(artwork.get(k) == v for k, v in original.items()), 'art_story_refs', f'{sample["spelling"]} character {original["surface_position"]}')
        check(sample['frames'] == story['frames'], 'art_story_refs', f'{sample["spelling"]} exact frames')
        check(sample['storage']['storage_slot'] == story['storage']['storage_slot'], 'art_story_refs', f'{sample["spelling"]} storage')
    for reference in mnemonic.get('source_snapshot', []) + mnemonic.get('integration_sources', []):
        path = ROOT / reference['path']
        check(path.exists() and sha(path) == reference['sha256'], 'art_source_revisions', reference['path'])
    check(all(asset['implementation_status'] == 'planned' for asset in environment['assets']), 'planning_boundary', 'environment remains planned')
    check(all(clip['status'] == 'planned' for clip in npcs['clips']), 'planning_boundary', 'clips remain planned')

    gdd_path = ROOT / 'GDD.md'
    gdd = gdd_path.read_text(encoding='utf8')
    inputs['GDD.md'] = sha(gdd_path)
    check('source_character_id' not in gdd and '唯一 call_id' not in gdd, 'gdd_contract', 'no stale alias presented as real schema')
    for actual in [len(occurrences), len(lexemes), len(stories), association_count]:
        check(str(actual) in gdd, 'gdd_counts', str(actual))
    for book_id in books:
        check(book_id in gdd, 'gdd_counts', book_id)
    for level, label_id, name in levels:
        check(f'| {label_id} | {name} |' in gdd, 'gdd_contract', label_id)
    for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)', gdd):
        if re.match(r'^[a-z]+://', target) or target.startswith('#'):
            continue
        path = (ROOT / unquote(target.split('#', 1)[0])).resolve()
        check(path == OUTPUT or path.exists(), 'gdd_links', target)
    expected_counts = {'books': 8, 'unit_events': 81, 'prologue_letters': 26, 'book_occurrences': 1314, 'exact_spellings': 1073, 'core_sense_stories': 1096, 'unit_entry_associations': 1359, 'environment_specs': 24, 'npc_source_records': 142, 'npc_plan_records': 144, 'animation_specs': 40, 'special_rig_basic_specs': 9, 'static_pose_specs': 18, 'special_character_work_orders': 26, 'planned_pose_bindings': 52, 'pending_behavior_bindings': 0, 'art_story_samples': 20}
    counts = {'books': len(books), 'unit_events': len(unit_keys), 'prologue_letters': len(alphabet), 'book_occurrences': len(occurrences), 'exact_spellings': len(lexemes), 'core_sense_stories': len(stories), 'unit_entry_associations': association_count, 'environment_specs': len(environment['assets']), 'npc_source_records': len(people_ids), 'npc_plan_records': len(npcs['characters']), 'animation_specs': len(npcs['clips']), 'special_rig_basic_specs': len(basic_specs), 'static_pose_specs': len(pose_specs), 'special_character_work_orders': len(work_orders), 'planned_pose_bindings': planned_pose_bindings, 'pending_behavior_bindings': pending_behavior_bindings, 'art_story_samples': len(mnemonic['samples'])}
    for key, expected in expected_counts.items():
        check(counts[key] == expected, 'gdd_baseline', key)
    domain_reports = {}
    for report_name in ['mainline/validation_report.json', 'art/validation_report.json', 'vocabulary/review/validation.json']:
        path = PLAN / report_name
        check(path.exists(), 'domain_reports', report_name)
        if path.exists():
            report = json.loads(path.read_text(encoding='utf8'))
            status = str(report.get('status', report.get('result', ''))).lower()
            check(status in {'pass', 'passed'}, 'domain_reports', f'{report_name} passed')
            domain_reports[report_name] = {'status': status, 'sha256': sha(path), 'warnings': report.get('warnings', []), 'runtime_validation': False}
    for relative in ['GDD.md', 'README.md', 'docs/planning/integration/冲突核查与整合记录.md', 'docs/planning/integration/validate_gdd.py']:
        path = ROOT / relative
        inputs[relative] = sha(path)
    for domain in ['mainline', 'vocabulary', 'art']:
        for name in ['README.md', '整合核查与修订.md']:
            path = PLAN / domain / name
            check(path.exists(), 'domain_documents', f'{domain}/{name}')
            if path.exists():
                inputs[path.relative_to(ROOT).as_posix()] = sha(path)
    return {
        'schema_version': 1,
        'status': 'passed' if not errors else 'failed',
        'checked_at': datetime.now(timezone(timedelta(hours=8))).isoformat(),
        'scope': 'Cross-domain planning/content/source-reference audit; not runtime, pedagogy or child testing.',
        'counts': counts,
        'requirement_counts': dict(Counter(o['requirement'] for o in occurrences.values())),
        'versions': {key: adapted[key] for key in ['content_revision', 'codebook_revision']},
        'check_count': sum(checks.values()),
        'checks_by_group': dict(checks),
        'errors': errors,
        'domain_reports': domain_reports,
        'input_sha256': inputs,
        'units': unit_report,
        'remaining_gates': ['full_unit_editorial_review', 'vocabulary_independent_human_review', 'unconfirmed_character_identity_and_appearance_review', 'audio_production_and_listening_review', 'asset_production', 'runtime_integration', 'device_performance', 'child_usability_and_learning_evidence'],
        'runtime_changed_by_this_validator': False,
        'source_files_changed_by_this_validator': False,
        'full_game_tests_run': False,
    }


if __name__ == '__main__':
    report = run()
    OUTPUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    print(json.dumps({key: report[key] for key in ['status', 'check_count', 'counts', 'errors']}, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report['status'] == 'passed' else 1)
