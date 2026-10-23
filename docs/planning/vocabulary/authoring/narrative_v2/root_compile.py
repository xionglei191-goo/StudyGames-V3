import json
from pathlib import Path

root=Path(__file__).resolve().parent
items=json.loads((root/'input_root.json').read_text(encoding='utf-8'))
written={}
for line in (root/'root_stories.tsv').read_text(encoding='utf-8').splitlines():
    if not line.strip():continue
    index,title,bridge,question,raw=line.split('|')
    index=int(index);item=items[index];beats=raw.split('¦')
    assert index not in written,index
    assert len(beats)==len(item['steps']),(index,item['spelling'],len(beats),len(item['steps']))
    for step,beat in zip(item['steps'],beats):
        assert step['anchor_zh'] in beat,(index,step['letter_position'],beat)
    written[index]={'id':item['id'],'title':title,'beats':beats,'meaning_bridge':bridge,'recall_question':question}
(root/'output_root.json').write_text(json.dumps([written[i] for i in sorted(written)],ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'Root stories: {len(written)}/{len(items)}; missing: {[i for i in range(len(items)) if i not in written]}')
