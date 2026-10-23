"""Convert individually authored TSV rows to the assigned narrative JSON."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
source = json.loads((ROOT / 'input_g4.json').read_text(encoding='utf-8'))
seen = {}
errors = []
for path in sorted(ROOT.glob('g4_part*.tsv')):
    part = []
    for line_no, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        if not line.strip():
            continue
        cells = line.split('\t')
        if len(cells) != 5:
            errors.append(f'{path.name}:{line_no}: {len(cells)} columns')
            continue
        number, title, raw_beats, bridge, question = cells
        index = int(number)
        item = source[index]
        beats = raw_beats.split('¦')
        if index in seen:
            errors.append(f'duplicate index {index}')
        if len(beats) != len(item['steps']):
            errors.append(f'{index} {item["spelling"]}: {len(beats)} beats != {len(item["steps"])}')
        for position, (beat, step) in enumerate(zip(beats, item['steps']), 1):
            if step['anchor_zh'] not in beat:
                errors.append(f'{index} {item["spelling"]} beat {position}: missing {step["anchor_zh"]}')
            if not beat.endswith(('。', '！', '？', '”')):
                errors.append(f'{index} {item["spelling"]} beat {position}: incomplete ending')
        out = {'id': item['id'], 'title': title, 'beats': beats,
               'meaning_bridge': bridge, 'recall_question': question}
        seen[index] = out
        part.append(out)
    path.with_suffix('.json').write_text(json.dumps(part, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
index_by_id = {item['id']: index for index, item in enumerate(source)}
tail = json.loads((ROOT / 'root_tail_g4.json').read_text(encoding='utf-8'))
for out in tail:
    index = index_by_id.get(out.get('id'))
    if index is None:
        errors.append(f'unknown tail ID {out.get("id")}')
        continue
    item = source[index]
    if index in seen:
        errors.append(f'duplicate tail index {index}')
    beats = out['beats']
    if len(beats) != len(item['steps']):
        errors.append(f'{index} {item["spelling"]}: {len(beats)} beats != {len(item["steps"])}')
    for position, (beat, step) in enumerate(zip(beats, item['steps']), 1):
        if step['anchor_zh'] not in beat:
            errors.append(f'{index} {item["spelling"]} beat {position}: missing {step["anchor_zh"]}')
        if not beat.endswith(('。', '！', '？', '”')):
            errors.append(f'{index} {item["spelling"]} beat {position}: incomplete ending')
    seen[index] = out
missing = [i for i in range(len(source)) if i not in seen]
audit = {'assigned': len(source), 'written': len(seen), 'missing_indices': missing,
         'errors': errors, 'scope': 'ID/count/explicit-anchor structure checks; prose authored and read individually',
         'human_editor': 'pending', 'child_trial': 'not_conducted'}
(ROOT / 'g4_audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
if not errors and not missing:
    (ROOT / 'output_g4.json').write_text(json.dumps([seen[i] for i in range(len(source))], ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'assigned': len(source), 'written': len(seen), 'missing': len(missing), 'errors': errors}, ensure_ascii=False))
if errors:
    raise SystemExit(1)
