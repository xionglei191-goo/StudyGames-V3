"""Rebuild versioned round-two assets and reproducible same-camera evidence locally."""
from pathlib import Path
import subprocess,json,argparse,concurrent.futures
p=argparse.ArgumentParser();p.add_argument('--evidence',required=True);p.add_argument('--rooms',default='');p.add_argument('--workers',type=int,default=2);p.add_argument('--skip-build',action='store_true');a=p.parse_args()
root=Path(__file__).resolve().parents[1];ev=Path(a.evidence).resolve();ev.mkdir(parents=True,exist_ok=True)
plan=json.loads((root/'docs/planning/cloud-refinement-round2-20261025.json').read_text());rows=plan['rooms']
if a.rooms:rows=[r for r in rows if r['room_id'] in a.rooms.split(',')]
def run(cmd,log):
 if cmd[0]=='blender' and '--python-exit-code' not in cmd:cmd[1:1]=['--python-exit-code','1']
 with log.open('w') as f:
  result=subprocess.run(cmd,cwd=root,stdout=f,stderr=subprocess.STDOUT)
 if result.returncode:raise RuntimeError(str(log))
def room(r):
 rid=r['room_id'];out=ev/rid;out.mkdir(parents=True,exist_ok=True)
 if not a.skip_build:run(['blender','-b',r['first_blend'],'-t','3','-P','scripts/cloud_round2_refine.py','--','--room',rid,'--out',r['blend'],'--evidence',str(out)],out/'build.log')
 for phase,src in [('before',r['first_blend']),('after',r['blend'])]:
  run(['blender','-b',src,'-t','3','-P','scripts/cloud_scene_inspect.py','--','--out',str(out),'--render','--width','1280','--samples','48','--filename',phase+'.png'],out/(phase+'-render.log'))
  if rid in ['island','school','home_kitchen']:
   run(['blender','-b',src,'-t','3','-P','scripts/cloud_round2_views.py','--','--room',rid,'--out',str(out),'--phase',phase],out/(phase+'-detail.log'))
  if rid=='island':
   run(['blender','-b',src,'-t','3','-P','scripts/cloud_scene_inspect.py','--','--out',str(out),'--render','--width','1400','--samples','48','--filename',phase+'-neighborhood.png','--camera','REVIEW_Neighborhood'],out/(phase+'-neighborhood.log'))
 print('ROUND2_ROOM_READY',rid,flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=a.workers) as pool:
 for f in concurrent.futures.as_completed([pool.submit(room,r) for r in rows]):f.result()
