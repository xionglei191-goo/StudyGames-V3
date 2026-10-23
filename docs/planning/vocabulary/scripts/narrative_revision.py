"""Apply the hand-authored, complete narrative revision to stable story IDs.

No story text is synthesized here: every beat comes from an authored output file.
The previous package remains in the revision archive for comparison and recovery.
"""
from __future__ import annotations

import hashlib
import json
import re
import zipfile
from pathlib import Path

REVISION = 'narrative-v2-2026-10-23'


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True).encode('utf-8')).hexdigest()


def write(root, relative, value):
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def grouped_frames(steps):
    return [
        {'frame': start // 4 + 1,
         'letter_positions': [x['letter_position'] for x in steps[start:start + 4]],
         'text': ''.join(x['action'] for x in steps[start:start + 4])}
        for start in range(0, len(steps), 4)
    ]


def prepare_record(source, target):
    assert source['id'] == target['id']
    for key in ('title', 'meaning_bridge', 'recall_question'):
        assert isinstance(source[key], str) and source[key].strip(), (source['id'], key)
    beats = source['beats']
    steps = target['steps']
    assert len(beats) == len(steps), (source['id'], len(beats), len(steps))
    for step, sentence in zip(steps, beats):
        assert isinstance(sentence, str) and len(sentence.strip()) >= 12, (source['id'], 'short beat')
        assert step['anchor_zh'] in sentence, (source['id'], step['letter_position'], 'missing anchor')
        assert any(p in sentence for p in '。！？!?.'), (source['id'], 'incomplete sentence')
        assert not re.search(r'TODO|待补写|待扩写|稍后补充', sentence, re.I), source['id']
        step['action'] = sentence
        step['action_text_style'] = 'complete_narrative_sentence'
    frames = grouped_frames(steps)
    narrative = {
        'revision': REVISION,
        'title': source['title'],
        'text': ''.join(beats),
        'paragraphs': [f['text'] for f in frames],
        'beat_count': len(beats),
        'meaning_bridge': source['meaning_bridge'],
        'recall_question': source['recall_question'],
        'authorship': 'individually_assistant_authored_not_template_generated',
        'human_editor': 'pending',
        'child_trial': 'not_conducted',
    }
    target['narrative'] = narrative
    target['meaning_anchor'] = source['meaning_bridge']
    target['frames'] = frames
    return narrative


def apply_narrative_revision(catalog, root):
    folder = root / 'authoring/narrative_v2'
    if not (folder / 'enabled.json').exists():
        return None
    manifest = read(folder / 'manifest.json')
    assignments = {}
    authored = {}
    for owner in manifest['assignments']:
        inputs = read(folder / f'input_{owner}.json')
        outputs = read(folder / f'output_{owner}.json')
        expected = {x['id'] for x in inputs}
        got = [x['id'] for x in outputs]
        assert len(got) == len(set(got)), (owner, 'duplicate authored ID')
        assert set(got) == expected, (owner, 'missing or unexpected stories', sorted(expected - set(got)))
        assert not set(got) & authored.keys(), (owner, 'overlapping assignment')
        authored.update({x['id']: x for x in outputs})
        assignments[owner] = {'stories': len(outputs), 'beats': sum(len(x['beats']) for x in outputs)}
    reuse = {row['id']: row for row in read(folder / 'reuse_aliases.json')['aliases']}
    for sid, alias in reuse.items():
        canonical_id = alias['canonical_id']
        assert sid in authored and canonical_id in authored and canonical_id not in reuse, alias
        authored[sid] = {**authored[canonical_id], 'id': sid}
    with zipfile.ZipFile(folder / manifest['baseline_archive']) as archive:
        baseline = json.loads(archive.read('data/catalog.json'))
    for key in ('stories', 'lexemes', 'occurrences', 'sources'):
        assert {x['id'] for x in catalog[key]} == set(manifest['stable_ids'][key]), (key, 'stable identity changed')
    old_stories = {x['id']: x for x in baseline['stories']}
    old_records = {**old_stories,
                   **{e['id']: e for s in old_stories.values() for e in s['sense_extensions']}}
    current_records = {s['id']: s for s in catalog['stories']}
    current_records.update({e['id']: e for s in catalog['stories'] for e in s['sense_extensions']})
    assert set(current_records) == set(authored) == set(old_records), 'Narrative coverage mismatch'
    changes = []
    for story in catalog['stories']:
        previous = old_stories[story['id']]
        for key in ('root_location', 'storage_slot', 'story_page'):
            assert story['storage'][key] == previous['storage'][key], (story['id'], key)
        for target in [story] + story['sense_extensions']:
            old = old_records[target['id']]
            assert [(s['letter_position'], s['letter'], s['occurrence']) for s in target['steps']] == [
                (s['letter_position'], s['letter'], s['occurrence']) for s in old['steps']
            ], (target['id'], 'letter order changed')
            narrative = prepare_record(authored[target['id']], target)
            if target['id'] in reuse:
                alias = reuse[target['id']]
                narrative['shared_with'] = alias['canonical_id']
                narrative['reuse_reason'] = alias['reason']
                narrative['authorship'] = 'assistant_authored_canonical_story_reused_for_same_meaning'
            changes.append({'id': target['id'], 'parent_story_id': story['id'],
                            'kind': 'core' if target is story else 'sense_extension',
                            'old_action_hash': fingerprint([s['action'] for s in old['steps']]),
                            'new_action_hash': fingerprint([s['action'] for s in target['steps']]),
                            'narrative_hash': fingerprint(narrative), 'identity_preserved': True,
                            'shared_narrative_with': narrative.get('shared_with')})
        n = story['narrative']
        prompts = {p['level']: p for p in story['prompt_ladder']}
        prompts[1]['prompt'] = f"回到{story['storage']['root_location']}。这篇故事叫《{n['title']}》；想想它怎样联系“{story['meaning_label']}”。"
        continuation = ('接下来谁会接住这个变化？' if len(story['steps']) > 1
                        else '这一格里谁做了什么，它和这个词的意思有什么联系？')
        prompts[2]['prompt'] = f"先想起第一格：{story['steps'][0]['action']} {continuation}"
        prompts[4]['prompt'] = f"先围绕具体情节想一想：{n['recall_question']} 需要时展示当前一格，再给下一形象的选择。"
        prompts[4]['step_questions'] = [
            f"这一格发生了：{step['action']} 这个结果给下一格的{next_step['anchor_zh']}留下了什么事情？"
            for step, next_step in zip(story['steps'], story['steps'][1:])
        ]
        prompts[5]['prompt'] = f"先听或阅读完整故事《{n['title']}》，再按分镜回看每个动作与对应字母；完整词音和故事旁白分别制作，缺少音频时只提供文字和图卡。"
        prompts[5]['frame_refs'] = [f['frame'] for f in story['frames']]
        story['review']['assistant_editorial'] = 'full_narrative_rewrite_with_structural_validation'
        story['review']['narrative_human_editor'] = 'pending'
        story['review']['narrative_child_trial'] = 'not_conducted'
    stories = {x['id']: x for x in catalog['stories']}
    for occurrence in catalog['occurrences']:
        story = stories[occurrence['story_id']]
        meanings = [story['meaning_anchor']]
        for extension in story['sense_extensions']:
            if occurrence['book_id'] in extension['book_ids'] and extension['meaning_anchor'] not in meanings:
                meanings.append(extension['meaning_anchor'])
        occurrence['occurrence_meaning_anchor'] = '；'.join(meanings)
    catalog.update({'date': '2026-10-24', 'planning_version': 'v2-narrative',
                    'narrative_revision': REVISION})
    lengths = [len(x['narrative']['text']) for x in current_records.values()]
    action_changes = sum(x['old_action_hash'] != x['new_action_hash'] for x in changes)
    assert action_changes == len(changes), 'A record was not actually rewritten'
    for sid, alias in reuse.items():
        assert current_records[sid]['narrative']['text'] == current_records[alias['canonical_id']]['narrative']['text']
    report = {
        'status': 'passed', 'date': '2026-10-24', 'revision': REVISION,
        'core_stories': len(catalog['stories']), 'supplemental_stories': len(authored) - len(catalog['stories']),
        'all_authored_stories': len(authored), 'rewritten_records': action_changes,
        'shared_same_meaning_records': len(reuse),
        'distinct_narrative_texts': len({x['narrative']['text'] for x in current_records.values()}),
        'narrative_letter_beats': sum(len(x['steps']) for x in current_records.values()),
        'book_occurrences': len(catalog['occurrences']), 'assignments': assignments,
        'shortest_story_characters': min(lengths), 'longest_story_characters': max(lengths),
        'stable_ids_preserved': True, 'stable_storage_preserved': True,
        'original_archive': 'authoring/narrative_v2/' + manifest['baseline_archive'],
        'automatic_checks': ['all core and supplemental IDs covered', 'one complete sentence beat per letter',
                             'fixed anchor name appears in its assigned beat', 'punctuation and spelling preserved',
                             'all letter positions and repeated instances unchanged', 'no missing author fields',
                             'all original actions revised', 'story text equals joined authored beats',
                             'explicit same-meaning aliases share the canonical complete story'],
        'automatic_check_limit': '固定形象出现、句数和字符一致只证明结构；不能证明文笔流畅、因果合理或儿童理解。',
        'human_editor_review': 'pending', 'child_trial': 'not_conducted', 'learning_effect': 'not_validated',
    }
    write(root, 'review/narrative_validation.json', report)
    write(root, 'data/narrative_revision_map.json', {
        'revision': REVISION, 'previous_content_revision': baseline.get('content_revision'),
        'policy': '同一词义和存放位置统一修订故事内容，保持ID；按content_revision区分版本，不重解释旧行为记录，不覆盖儿童自编版本。',
        'archive': report['original_archive'], 'changes': changes,
    })
    render_comparison(root, catalog, old_stories, report)
    return report


def render_comparison(root, catalog, old_stories, report):
    lexemes = {x['spelling']: x for x in catalog['lexemes']}
    stories = {x['id']: x for x in catalog['stories']}
    lines = ['# 连贯故事扩写：阅读与对照', '',
             '2026-10-24 · 全库故事修订 v2（10月23日开始）。每个故事保留固定字母链和原存放位置，按完整情节重新编写。', '',
             f"范围：{report['core_stories']}篇核心故事、{report['supplemental_stories']}篇补充义项故事，共{report['narrative_letter_beats']}个逐字母叙事格；跨册仍引用同一故事。", '',
             '阅读时先看连续故事，再看字母链。故事中的其他物件是道具，只有绑定的字母形象占编码位置；重复形象保留独立实例。下列是对照样例，各册完整稿见[总目录](README.md)。', '']
    for word in ['nose', 'book', 'apple', 'school', 'football', 'pencil case', 'can', 'cold',
                 'with', 'make', 'interesting', "International Children's Day"]:
        for sid in lexemes[word]['story_ids']:
            st = stories[sid]; n = st['narrative']; old = old_stories[sid]
            lines += [f"## {word} · {st['meaning_label']}", '',
                      f"**原存放位置：** {st['storage']['root_location']}", '',
                      '**原稿动作清单：** ' + ' → '.join(x['action'] for x in old['steps']), '',
                      f"**扩写故事：{n['title']}**", '']
            lines.extend('> ' + paragraph + '\n' for paragraph in n['paragraphs'])
            lines += ['**字母顺序：** ' + ' → '.join(f"{p['letter']}({p['occurrence']})={p['anchor_zh']}" for p in st['steps']),
                      '', '**词义怎么连起来：** ' + n['meaning_bridge'], '',
                      '**孩子卡住时：** ' + n['recall_question'], '']
            for ex in st['sense_extensions']:
                en = ex['narrative']
                lines += [f"**补充义项：{ex['meaning_zh']}｜{en['title']}**", '']
                lines.extend('> ' + paragraph + '\n' for paragraph in en['paragraphs'])
            lines += ['---', '']
    lines += ['## 版本和核验', '',
              '旧版包保存在 `authoring/narrative_v2/before_narrative_v2.zip`；新旧动作哈希和稳定ID关系见 `data/narrative_revision_map.json`。不同册引用共同更新后的故事，不把它们各自改成不同版本。', '',
              '自动核验检查覆盖、字母绑定、重复实例、完整字符、ID与存放位置；助手语义抽查另行记录。人类编辑、儿童试用和新旁白制作仍待完成，不能把故事更长或字数更多当作学习效果证据。']
    (root / '故事扩写对照.md').write_text('\n'.join(lines).rstrip() + '\n', encoding='utf-8')
