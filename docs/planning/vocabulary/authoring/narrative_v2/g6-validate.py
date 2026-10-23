"""Validate already-authored G6 narratives; this script creates no story prose."""
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent
source = ROOT / 'input_g6.json'
output = ROOT / 'output_g6.json'
inputs = json.loads(source.read_text(encoding='utf-8'))
records = json.loads(output.read_text(encoding='utf-8'))
names = dict(zip('ABCDEFGHIJKLMNOPQRSTUVWXYZ', ['苹果','小船','蛋糕','鼓','蛋壳','花朵','地球仪','帽子','冰淇淋','罐子','风筝','灯笼','蘑菇','鸟巢','猫头鹰','南瓜','拼布被','机器人','星星','火车','雨伞','火山','鲸鱼','木琴','毛线','斑马']))
numbers = {v: k for k, v in enumerate('一二三四五六七八九十', 1)}
errors = []
repeated_beats = 0
id_order_unchanged = [x['id'] for x in inputs] == [x['id'] for x in records]
if not id_order_unchanged:
    errors.append('ID order mismatch')
if len({x['id'] for x in records}) != len(records):
    errors.append('Duplicate output ID')
for index, (item, record) in enumerate(zip(inputs, records)):
    if set(record) != {'id', 'title', 'beats', 'meaning_bridge', 'recall_question'}:
        errors.append([index, 'schema'])
    if not all(isinstance(record[k], str) and record[k].strip() for k in ('id', 'title', 'meaning_bridge', 'recall_question')):
        errors.append([index, 'empty string field'])
    if len(item['steps']) != len(record['beats']):
        errors.append([index, 'beat count'])
    counts = Counter(step['letter'] for step in item['steps'])
    seen = Counter()
    for position, (step, beat) in enumerate(zip(item['steps'], record['beats']), 1):
        actor = names[step['letter']]
        seen[step['letter']] += 1
        if actor not in beat:
            errors.append([index, position, 'missing actor'])
            continue
        lead = beat[:beat.index(actor)]
        if len(lead) > 8:
            errors.append([index, position, 'actor not near beginning'])
        ordinal = re.search(r'第([一二三四五六七八九十])', lead)
        if counts[step['letter']] > 1:
            repeated_beats += 1
            if not ordinal or numbers[ordinal.group(1)] != seen[step['letter']]:
                errors.append([index, position, 'repeated actor ordinal'])
        elif ordinal:
            errors.append([index, position, 'unneeded actor ordinal'])
        if not beat.endswith(('。', '！', '？', '”')):
            errors.append([index, position, 'sentence punctuation'])
    if not record['recall_question'].endswith(('？', '?')):
        errors.append([index, 'question punctuation'])
report = {
    'count': len(records),
    'expected_count': len(inputs),
    'beats': sum(len(x['beats']) for x in records),
    'own_authored': 325,
    'imported_root_tail': 16,
    'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    'output_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
    'root_tail_sha256': hashlib.sha256((ROOT / 'root_tail_g6.json').read_bytes()).hexdigest(),
    'id_order_unchanged': id_order_unchanged,
    'repeated_actor_beats_checked': repeated_beats,
    'errors': errors,
    'validation_scope': 'structure, ID order, per-beat actor presence/position, repeated-actor ordinal order, sentence punctuation; not automated semantic validation',
    'human_editor': 'pending',
    'child_trial': 'not_conducted',
}
(ROOT / 'g6-validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))
raise SystemExit(bool(errors))
