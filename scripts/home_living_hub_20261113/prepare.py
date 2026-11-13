"""Protect the current working tree and household assets before the approved redesign."""
from pathlib import Path
import hashlib, json, subprocess, zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/verification/home-living-hub-20261113'
OUT.mkdir(parents=True, exist_ok=True)
def sha(p):
    with p.open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()
def record(p): return {'path': str(p), 'sha256': sha(p), 'bytes': p.stat().st_size}
if (OUT/'baseline.json').exists():
    raise SystemExit('Baseline already exists; do not replace it.')
assets = sorted(p for d in (ROOT/'assets/blender/interiors').glob('home*') if d.is_dir() for p in d.rglob('*') if p.is_file())
assets += sorted((ROOT/'game/assets/interiors').glob('home*.glb'))
code = sorted(p for d in ['game/scripts','game/data','game/ui','game/actors','game/gameplay'] for p in (ROOT/d).rglob('*') if p.is_file() and p.suffix in ['.gd','.json','.tscn','.tres'])
save_roots = [ROOT/'.local/shared-profiles', Path.home()/'AppData/Roaming/Godot/app_userdata/字母岛 · 我的第一天']
saves = sorted(p for d in save_roots if d.exists() for p in d.rglob('*') if p.is_file() and not any(x in p.parts for x in ['logs','shader_cache']) and not p.name.startswith('validation-'))
touch = [ROOT/x for x in ['game/scripts/main.gd','game/scripts/imported_interior.gd','game/scripts/home_catalog.gd','game/scripts/home_controller.gd','game/ui/world_map.gd','game/data/home_hierarchy.json','game/data/interiors_manifest.json','assets/blender/interiors/interiors_manifest.json','game/assets/interiors/home.glb']]
backup = list(dict.fromkeys([*touch,*saves]))
backup_path = OUT/('before-resumed.zip' if (OUT/'before.zip').exists() else 'before.zip')
if backup_path.exists(): raise SystemExit('Backup already exists; do not replace it.')
with zipfile.ZipFile(backup_path,'x',zipfile.ZIP_DEFLATED) as z:
    for i,p in enumerate(backup):
        if p.exists(): z.write(p, f'{i:04d}/{p.name}')
state = {'assets':[record(p) for p in assets], 'code':[record(p) for p in code], 'saves':[record(p) for p in saves], 'backup':[{'entry':f'{i:04d}/{p.name}',**record(p)} for i,p in enumerate(backup) if p.exists()]}
(OUT/'baseline.json').write_text(json.dumps(state,ensure_ascii=False,indent=2),encoding='utf-8')
(OUT/'working-tree-before.patch').write_bytes(subprocess.check_output(['git','diff','--binary'],cwd=ROOT))
(OUT/'git-status-before.txt').write_bytes(subprocess.check_output(['git','status','--short','--untracked-files=no'],cwd=ROOT))
print(json.dumps({k:len(v) for k,v in state.items()}),flush=True)
