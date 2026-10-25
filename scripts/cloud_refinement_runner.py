"""Reproduce the versioned refinement from the recorded original GLBs.

python3 scripts/cloud_refinement_runner.py --rooms island,school,home
Use Blender 4.3.2; fetch the recorded Git LFS sources first.
"""
from pathlib import Path
import argparse,json,subprocess,hashlib,os
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--rooms',default='');p.add_argument('--blender',default='blender');p.add_argument('--evidence',type=Path,default=ROOT/'.local/cloud-refinement/evidence');p.add_argument('--overwrite-generated',action='store_true',help='Replace only this task\'s generated *_cloud versions');a=p.parse_args()
plan=json.loads((ROOT/'docs/planning/cloud-refinement-20261025.json').read_text());selected=set(a.rooms.split(',')) if a.rooms else set();results=[]
def run(args,log):
    with log.open('w') as f:subprocess.run([a.blender,'--background','--threads','4','--python-exit-code','1',*args],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,check=True)
for row in plan['rooms']:
    room=row['room_id']
    if selected and room not in selected:continue
    if not a.overwrite_generated and any((ROOT/row[key]).exists() for key in ['blend','glb']):raise RuntimeError('Generated draft already exists; use an isolated worktree and --overwrite-generated to reproduce it')
    src=ROOT/row['original_glb'];digest=hashlib.sha256(src.read_bytes()).hexdigest()
    if digest!=row['original_glb_sha256']:raise RuntimeError('Original GLB absent, changed or still an LFS pointer: '+str(src))
    ev=a.evidence/room;ev.mkdir(parents=True,exist_ok=True)
    args=['--python',str(ROOT/'scripts/cloud_scene_inspect.py'),'--','--glb',str(src),'--out',str(ev),'--render','--width','1400' if room=='island' else '1000','--samples','64' if room=='island' else '24']
    if room=='island':args.append('--island')
    run(args,ev/'before.log')
    run([str(ev/'baseline_import.blend'),'--python',str(ROOT/'scripts/cloud_scene_refine.py'),'--','--room',room,'--out',str(ROOT/row['blend']),'--evidence',str(ev)],ev/'refine.log')
    run([str(ROOT/row['blend']),'--python',str(ROOT/'scripts/cloud_scene_inspect.py'),'--','--out',str(ev),'--render','--width','1400' if room=='island' else '1000','--samples','64' if room=='island' else '24','--filename','after.png'],ev/'after.log')
    if room=='island':
        for state,source in [('before',ev/'baseline_import.blend'),('after',ROOT/row['blend'])]:
            run([str(source),'--python',str(ROOT/'scripts/cloud_scene_inspect.py'),'--','--out',str(ev),'--render','--camera','REVIEW_Neighborhood','--width','1200','--samples','64','--filename',state+'-neighborhood.png'],ev/(state+'-neighborhood.log'))
    if room!='island':results.append(row)
    print('DONE',room,flush=True)
(a.evidence/'refined_rooms.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
if not selected:
    (a.evidence/'lfs_integrity.json').write_text(json.dumps({'files':[{'name':row[key],'oid':row[key+'_sha256']} for row in plan['rooms'] for key in ['original_blend','original_glb']]}))
    env={**os.environ,'STUDYGAMES_REFINEMENT_EVIDENCE':str(a.evidence)}
    subprocess.run(['python3',str(ROOT/'scripts/cloud_validate_assets.py')],env=env,check=True)
print('Outputs are versioned; integration is an explicit subsequent step.')
