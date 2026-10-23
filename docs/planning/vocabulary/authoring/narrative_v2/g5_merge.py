"""Convert hand-authored narrative TSV batches and validate fixed input steps."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
source = json.loads((ROOT / 'input_g5.json').read_text(encoding='utf-8'))
results = {}
errors = []
for part in sorted(ROOT.glob('g5_part*.tsv')):
    for line_number, line in enumerate(part.read_text(encoding='utf-8').splitlines(), 1):
        if not line or line.startswith('#'):
            continue
        columns = line.split('|')
        if len(columns) != 5:
            errors.append([part.name, line_number, 'column_count', len(columns)])
            continue
        idx, title, narrative, bridge, question = columns
        idx = int(idx)
        assert idx not in results, idx
        item = source[idx]
        beats = narrative.split('^')
        if len(beats) != len(item['steps']):
            errors.append([idx, item['spelling'], 'beat_count', len(beats), len(item['steps'])])
        for position, (beat, step) in enumerate(zip(beats, item['steps']), 1):
            if step['anchor_zh'] not in beat:
                errors.append([idx, item['spelling'], position, 'missing_actor', step['anchor_zh']])
            if len(beat) < 15:
                errors.append([idx, item['spelling'], position, 'too_short', len(beat)])
        results[idx] = {'id': item['id'], 'title': title, 'beats': beats, 'meaning_bridge': bridge, 'recall_question': question}

tail_path = ROOT / 'root_tail_g5.json'
if tail_path.exists():
    index_by_id = {item['id']: idx for idx, item in enumerate(source)}
    for row in json.loads(tail_path.read_text(encoding='utf-8')):
        idx = index_by_id.get(row.get('id'))
        if idx is None or idx < 330:
            errors.append(['root_tail_g5.json', 'unexpected_id', row.get('id')])
            continue
        assert idx not in results, idx
        item = source[idx]
        beats = row['beats']
        if len(beats) != len(item['steps']):
            errors.append([idx, item['spelling'], 'beat_count', len(beats), len(item['steps'])])
        for position, (beat, step) in enumerate(zip(beats, item['steps']), 1):
            if step['anchor_zh'] not in beat:
                errors.append([idx, item['spelling'], position, 'missing_actor', step['anchor_zh']])
            if len(beat) < 15:
                errors.append([idx, item['spelling'], position, 'too_short', len(beat)])
        results[idx] = row

ordered = [results[idx] for idx in sorted(results)]
progress = {'completed': len(ordered), 'assigned': len(source), 'beats': sum(len(r['beats']) for r in ordered),
            'errors': errors, 'missing_indices': [i for i in range(len(source)) if i not in results],
            'human_editorial_review': 'pending', 'child_trial': 'not_conducted'}
(ROOT / 'g5_progress.json').write_text(json.dumps(progress, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
(ROOT / 'g5_partial.json').write_text(json.dumps(ordered, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
if len(ordered) == len(source) and not errors:
    assert {r['id'] for r in ordered} == {r['id'] for r in source}
    (ROOT / 'output_g5.json').write_text(json.dumps(ordered, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: v for k, v in progress.items() if k != 'missing_indices'}, ensure_ascii=False))
if errors:
    raise SystemExit(1)
