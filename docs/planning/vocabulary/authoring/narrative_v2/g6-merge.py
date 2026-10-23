import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'input_g6.json'
inputs = json.loads(SOURCE.read_text(encoding='utf-8'))
names = dict(zip('ABCDEFGHIJKLMNOPQRSTUVWXYZ', ['苹果','小船','蛋糕','鼓','蛋壳','花朵','地球仪','帽子','冰淇淋','罐子','风筝','灯笼','蘑菇','鸟巢','猫头鹰','南瓜','拼布被','机器人','星星','火车','雨伞','火山','鲸鱼','木琴','毛线','斑马']))
records = {}
errors = []
for path in sorted(ROOT.glob('g6-part*.tsv')):
    for lineno, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        if not line.strip():
            continue
        cells = line.split('\t')
        if len(cells) != 5:
            errors.append(f'{path.name}:{lineno}: expected 5 columns, got {len(cells)}')
            continue
        index = int(cells[0])
        if index in records:
            errors.append(f'duplicate index {index}')
            continue
        item = inputs[index]
        beats = cells[2].split('|')
        if len(beats) != len(item['steps']):
            errors.append(f'{index} {item["spelling"]}: beats {len(beats)} != {len(item["steps"])}')
        for pos, (beat, step) in enumerate(zip(beats, item['steps']), 1):
            if names[step['letter']] not in beat:
                errors.append(f'{index} {item["spelling"]} beat {pos}: missing actor {names[step["letter"]]}')
            if not beat.endswith(('。','！','？','”')):
                errors.append(f'{index} beat {pos}: incomplete sentence punctuation')
        if not cells[1] or not cells[3] or not cells[4].endswith(('？','?')):
            errors.append(f'{index}: incomplete title/meaning bridge/question')
        records[index] = dict(id=item['id'], title=cells[1], beats=beats, meaning_bridge=cells[3], recall_question=cells[4])

own_count = len(records)
tail_path = ROOT / 'root_tail_g6.json'
imported_tail = 0
if tail_path.exists():
    id_to_index = {item['id']: i for i, item in enumerate(inputs)}
    for record in json.loads(tail_path.read_text(encoding='utf-8')):
        index = id_to_index[record['id']]
        if index < 325 or index > 340 or index in records:
            errors.append(f'root tail unexpected or duplicated index {index}')
            continue
        item = inputs[index]
        if len(record['beats']) != len(item['steps']):
            errors.append(f'root tail {index}: beat count mismatch')
        for pos, (beat, step) in enumerate(zip(record['beats'], item['steps']), 1):
            if names[step['letter']] not in beat:
                errors.append(f'root tail {index} beat {pos}: missing actor {names[step["letter"]]}')
        if not record['title'] or not record['meaning_bridge'] or not record['recall_question'].endswith(('？','?')):
            errors.append(f'root tail {index}: incomplete title/meaning bridge/question')
        records[index] = record
        imported_tail += 1
missing = [i for i in range(len(inputs)) if i not in records]
status = dict(input_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(), completed=len(records), own_completed=own_count, imported_root_tail=imported_tail, total=len(inputs), beats=sum(len(x['beats']) for x in records.values()), missing_indices=missing, errors=errors, human_editor='pending', child_trial='not_conducted')
(ROOT / 'g6-progress.json').write_text(json.dumps(status, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({k:v for k,v in status.items() if k != 'missing_indices'}, ensure_ascii=False))
if errors:
    raise SystemExit(1)
if not missing:
    output = [records[i] for i in range(len(inputs))]
    assert {x['id'] for x in output} == {x['id'] for x in inputs}
    (ROOT / 'output_g6.json').write_text(json.dumps(output, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('Wrote output_g6.json')
