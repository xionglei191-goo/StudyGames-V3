"""Compile the parent's hand-authored closing segments; never generate story text."""
import json
from pathlib import Path

root = Path(__file__).resolve().parent
inputs = {key: json.loads((root / f'input_{key}.json').read_text('utf-8'))
          for key in ('g4', 'g5', 'g6')}
parts = {key: {} for key in inputs}
for line in (root / 'root_tail_stories.tsv').read_text('utf-8').splitlines():
    if not line.strip():
        continue
    owner, index, title, bridge, question, text = line.split('|')
    index = int(index)
    source = inputs[owner][index]
    beats = text.split('¦')
    assert index not in parts[owner], (owner, index)
    assert len(beats) == len(source['steps']), (owner, index, source['spelling'], len(beats))
    for step, beat in zip(source['steps'], beats):
        assert step['anchor_zh'] in beat and len(beat) >= 12, (owner, index, step['letter_position'])
    parts[owner][index] = {'id': source['id'], 'title': title, 'beats': beats,
                           'meaning_bridge': bridge, 'recall_question': question}
for owner, rows in parts.items():
    if rows:
        (root / f'root_tail_{owner}.json').write_text(
            json.dumps([rows[index] for index in sorted(rows)], ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(owner, len(rows), 'complete authored records')
