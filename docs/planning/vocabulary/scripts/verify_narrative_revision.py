"""Check narrative publication against the archived identities and exported files.

This verifies preservation and propagation, not literary quality or learning effect.
It reads textbook and runtime references but only writes this planning package.
"""
from __future__ import annotations

import csv
import hashlib
import json
import re
import zipfile
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
AUTHORING = ROOT / 'authoring/narrative_v2'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def indexed(rows):
    result = {row['id']: row for row in rows}
    assert len(result) == len(rows), 'Duplicate identity'
    return result


def records(catalog):
    return indexed([record for story in catalog['stories']
                    for record in [story] + story['sense_extensions']])


def check():
    manifest = read(AUTHORING / 'manifest.json')
    with zipfile.ZipFile(AUTHORING / manifest['baseline_archive']) as archive:
        baseline = json.loads(archive.read('data/catalog.json'))
        old_adapter = json.loads(archive.read('data/mainline_entries.json'))
    current = read(ROOT / 'data/catalog.json')
    adapter = read(ROOT / 'data/mainline_entries.json')
    old_records, new_records = records(baseline), records(current)
    assert old_records.keys() == new_records.keys()
    assert current['planning_version'] == 'v2-narrative'
    assert current['content_revision'] != baseline['content_revision']
    assert current['codebook_revision'] == baseline['codebook_revision']
    assert current['landmarks'] == baseline['landmarks']
    for kind in ('lexemes', 'sources', 'books'):
        assert current[kind] == baseline[kind], (kind, 'changed source or identity data')
    old_occurrences, occurrences = indexed(baseline['occurrences']), indexed(current['occurrences'])
    assert old_occurrences.keys() == occurrences.keys()
    for sid, story in indexed(current['stories']).items():
        old_story = indexed(baseline['stories'])[sid]
        for key in ('id', 'lexeme_id', 'sense_key', 'meaning_label', 'authored_setting',
                    'storage', 'orthography_events', 'authored_origin_book', 'representation_contract'):
            assert story[key] == old_story[key], (sid, key)
        prompts = {p['level']: p for p in story['prompt_ladder']}
        old_prompts = {p['level']: p for p in old_story['prompt_ladder']}
        assert sorted(prompts) == list(range(6))
        for level in (0, 3):
            assert prompts[level] == old_prompts[level], (sid, 'preserved prompt', level)
        assert story['narrative']['title'] in prompts[1]['prompt']
        assert story['steps'][0]['action'] in prompts[2]['prompt']
        if len(story['steps']) == 1:
            assert '接下来谁' not in prompts[2]['prompt']
        assert story['narrative']['recall_question'] in prompts[4]['prompt']
        assert len(prompts[4]['step_questions']) == len(story['steps']) - 1
        assert prompts[5]['frame_refs'] == [frame['frame'] for frame in story['frames']]
    for rid, record in new_records.items():
        old = old_records[rid]
        before = [{k: v for k, v in step.items() if k not in ('action', 'action_text_style')}
                  for step in old['steps']]
        after = [{k: v for k, v in step.items() if k not in ('action', 'action_text_style')}
                 for step in record['steps']]
        assert before == after, (rid, 'letter actor or repeated instance changed')
        assert [step['action'] for step in old['steps']] != [step['action'] for step in record['steps']]
        narrative = record['narrative']
        assert narrative['beat_count'] == len(record['steps'])
        assert narrative['text'] == ''.join(step['action'] for step in record['steps'])
        assert narrative['text'] == ''.join(narrative['paragraphs'])
        assert narrative['paragraphs'] == [frame['text'] for frame in record['frames']]
        assert [p for frame in record['frames'] for p in frame['letter_positions']] == list(range(1, len(record['steps']) + 1))
        assert all(1 <= len(frame['letter_positions']) <= 4 for frame in record['frames'])
        for step in record['steps']:
            assert step['anchor_zh'] in step['action'] and len(step['action']) >= 12
            assert any(mark in step['action'] for mark in '。！？!?.')
        if rid.startswith('sense-scene-'):
            for key in ('meaning_zh', 'book_ids'):
                assert record[key] == old[key], (rid, key)
    aliases = read(AUTHORING / 'reuse_aliases.json')['aliases']
    for alias in aliases:
        shared = new_records[alias['id']]['narrative']
        original = new_records[alias['canonical_id']]['narrative']
        assert shared['shared_with'] == alias['canonical_id']
        for key in ('title', 'text', 'paragraphs', 'meaning_bridge', 'recall_question'):
            assert shared[key] == original[key], (alias['id'], key)
    stories = indexed(current['stories'])
    for oid, occurrence in occurrences.items():
        old = old_occurrences[oid]
        assert {k: v for k, v in occurrence.items() if k != 'occurrence_meaning_anchor'} == {
            k: v for k, v in old.items() if k != 'occurrence_meaning_anchor'}, (oid, 'occurrence metadata')
        story = stories[occurrence['story_id']]
        assert story['meaning_anchor'] in occurrence['occurrence_meaning_anchor']
        for extra in story['sense_extensions']:
            if occurrence['book_id'] in extra['book_ids']:
                assert extra['meaning_anchor'] in occurrence['occurrence_meaning_anchor']
    assert adapter['unit_index'] == old_adapter['unit_index']
    assert adapter['content_revision'] == current['content_revision']
    assert adapter['codebook_revision'] == current['codebook_revision']
    assert {entry['entry_id'] for entry in adapter['entries']} == occurrences.keys()
    old_entries = {entry['entry_id']: entry for entry in old_adapter['entries']}
    for entry in adapter['entries']:
        old = old_entries[entry['entry_id']]
        for key in ('entry_id', 'provider_occurrence_id', 'lexeme_id', 'sense_id', 'story_id',
                    'source_unit', 'spelling_display', 'meaning_zh', 'kind', 'requirement',
                    'task_permissions', 'source_ids', 'letter_slots', 'boundaries',
                    'reconstruction_tokens', 'orthography_events', 'memory_home'):
            assert entry[key] == old[key], (entry['entry_id'], key)
        story = stories[entry['story_id']]
        assert entry['narrative'] == story['narrative']
        assert ''.join(beat['text'] for beat in entry['story_beats']) == story['narrative']['text']
        assert [p for beat in entry['story_beats'] for p in beat['letter_positions']] == list(range(1, len(entry['letter_slots']) + 1))
        assert ''.join(token['raw'] for token in entry['reconstruction_tokens']) == entry['spelling_display']
        expected_extras = [extra for extra in story['sense_extensions']
                           if entry['source_unit']['book_id'] in extra['book_ids']]
        assert [extra['beat_id'] for extra in entry['supplemental_beats']] == [extra['id'] for extra in expected_extras]
        for supplemental, extra in zip(entry['supplemental_beats'], expected_extras):
            assert supplemental['narrative'] == extra['narrative']
            assert supplemental['frames'] == extra['frames']
            assert supplemental['role'] == 'sense_extension'
    for book in current['books']:
        short = f"g{book['grade']}-{book['volume']}"
        export = read(ROOT / 'books' / f'{short}.json')
        expected = [o for o in occurrences.values() if o['book_id'] == book['book_id']]
        assert [o['id'] for o in export['entries']] == [o['id'] for o in expected]
        for entry in export['entries']:
            assert entry['story'] == stories[entry['story_id']]
    with (ROOT / 'data/all_occurrences.csv').open(encoding='utf-8-sig', newline='') as stream:
        rows = list(csv.DictReader(stream))
    assert len(rows) == len(occurrences)
    for row in rows:
        story = stories[row['story_id']]
        assert row['story_text'] == story['narrative']['text']
        assert row['story_title'] == story['narrative']['title']
        assert row['recall_question'] == story['narrative']['recall_question']
    source_files = [row for row in read(ROOT / 'source_baseline.json')
                    if 'Englishbook' in row['path']]
    assert len(source_files) == 9
    for row in source_files:
        assert hashlib.sha256(Path(row['path']).read_bytes()).hexdigest() == row['sha256']
    link_files = [ROOT / name for name in ('README.md', '故事扩写对照.md', '重点样例.md', '验证报告.md')]
    link_files += sorted((ROOT / 'books').glob('*.md'))
    link_files += sorted((ROOT / 'cards').glob('*.md'))
    report_path = ROOT / 'review/narrative_publication_validation.json'
    link_targets = []
    link_count = 0
    for path in link_files:
        for raw in re.findall(r'\[[^\]]*\]\(([^)]+)\)', path.read_text(encoding='utf-8')):
            target = unquote(raw.strip('<>')).split('#', 1)[0]
            if not target or re.match(r'[a-z]+://|mailto:', target, re.I):
                continue
            resolved = (path.parent / target).resolve()
            assert resolved == report_path.resolve() or resolved.exists(), (path.name, 'missing link', target)
            link_targets.append(resolved)
            link_count += 1
    report = {
        'status': 'passed', 'revision': current['narrative_revision'],
        'previous_content_revision': baseline['content_revision'],
        'content_revision': current['content_revision'], 'codebook_revision': current['codebook_revision'],
        'core_stories': len(stories), 'supplemental_stories': len(new_records) - len(stories),
        'book_occurrences': len(occurrences), 'books': len(current['books']),
        'stable_source_files': len(source_files), 'same_meaning_aliases': len(aliases),
        'validated_markdown_links': link_count,
        'checks': ['stable IDs and complete source records', 'source requirement and unit assignments',
                   'original storage and fixed letter instances', 'complete narrative propagation to eight books, CSV and adapter',
                   'all encoding positions covered once; supplemental positions are references',
                   'same-meaning canonical narratives reused', 'unchanged codebook and updated content revision',
                   'six prompt levels and new story-specific recall questions', 'nine source manifest hashes',
                   'published local Markdown link targets'],
        'scope_limit': '静态内容与导出一致性核验；不证明通顺性、儿童理解、学习效果或游戏运行验收。',
        'human_editor': 'pending', 'child_trial': 'not_conducted', 'runtime_test': 'not_run',
    }
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    assert all(target.exists() for target in link_targets)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    check()
