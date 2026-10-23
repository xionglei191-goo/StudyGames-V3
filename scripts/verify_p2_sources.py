"""Check P2 protected inputs and the 52 rendered landmark views without rebuilding them."""
from pathlib import Path
import hashlib, json, struct
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/verification/p2'
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else 'missing'
baseline=json.loads((ROOT/'docs/verification/art-finish-v3/protected-baseline.json').read_text(encoding='utf-8'))
protected=[]
for row in baseline['files']:
    path=Path(row['path'])
    path=path if path.is_absolute() else ROOT/path
    actual=sha(path)
    protected.append({'path':row['path'],'category':row.get('category',''),'expected':row['sha256'],'actual':actual,'passed':actual==row['sha256']})
p2base=json.loads((OUT/'pre-implementation-baseline.json').read_text(encoding='utf-8'))
for row in p2base:
    if Path(row['path']).is_absolute() or row['path'].endswith('prologue.json'):
        path=Path(row['path'])
        path=path if path.is_absolute() else ROOT/path
        actual=sha(path)
        protected.append({'path':row['path'],'category':'p2_source_or_formal_save','expected':row['sha256'],'actual':actual,'passed':actual==row['sha256']})
manifest=json.loads((ROOT/'game/assets/learning/landmark_views/manifest.json').read_text(encoding='utf-8'))
source=ROOT/'game'/manifest['source'].removeprefix('res://')
views=[]
for row in manifest['records']:
    path=ROOT/'game'/row['image'].removeprefix('res://')
    pixels=list(struct.unpack('>II',path.read_bytes()[16:24]))
    views.append({'letter':row['letter'],'view':row['view'],'path':str(path.relative_to(ROOT)), 'pixels':pixels,'sha256':sha(path),'passed':sha(path)==row['sha256'] and pixels==row['pixels']})
result={'scope':'Original art/source files and formal saves protected; code intentionally updated. Original-model snapshots verified against capture manifest.',
        'protected':protected,'landmark_views':views,'source_model_matches':sha(source)==manifest['source_sha256'],
        'view_pairs_complete':{(r['letter'],r['view']) for r in views}=={(c,v) for c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' for v in ['front','angle']}}
result['passed']=all(r['passed'] for r in protected+views) and result['source_model_matches'] and result['view_pairs_complete']
(OUT/'source-preservation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'passed':result['passed'],'protected':len(protected),'views':len(views),'changed':[r['path'] for r in protected if not r['passed']]},ensure_ascii=False))
raise SystemExit(0 if result['passed'] else 1)
