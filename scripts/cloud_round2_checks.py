"""Run existing exporters/synchronizers and actual physics tours; keep old reports intact."""
from pathlib import Path
import subprocess,json,os,argparse,concurrent.futures,time
P=argparse.ArgumentParser();P.add_argument('--evidence',required=True);P.add_argument('--phase',choices=['export','runtime'],required=True);P.add_argument('--only',default='');a=P.parse_args();ROOT=Path(__file__).resolve().parents[1];EV=Path(a.evidence).resolve();DOC=ROOT/'docs/verification/cloud-refinement-round2-20261025';DOC.mkdir(parents=True,exist_ok=True);env=os.environ.copy();env.update(XDG_CONFIG_HOME=str(EV/'godot-config'),XDG_CACHE_HOME=str(EV/'godot-cache'),XDG_DATA_HOME=str(EV/'godot-user'))
plan=json.loads((ROOT/'docs/planning/cloud-refinement-round2-20261025.json').read_text());results=[]
prior_path=DOC/(a.phase+'-checks.json');prior={r['name']:r for r in json.loads(prior_path.read_text())['results']} if a.only and prior_path.exists() else {}
def run(name,cmd,report=None,expected=0):
 if a.only and name not in a.only.split(','):
  assert name in prior,'No recorded result for '+name
  return prior[name]
 if cmd[0]=='blender' and '--python-exit-code' not in cmd:cmd[1:1]=['--python-exit-code','1']
 old=report.read_bytes() if report and report.exists() else None;start=time.monotonic();log=EV/(name+'.log');e=env.copy();e['XDG_DATA_HOME']=str(EV/('godot-'+name))
 try:
  with log.open('w') as f:r=subprocess.run(cmd,cwd=ROOT,env=e,stdout=f,stderr=subprocess.STDOUT)
  proof=None
  if report and report.exists():proof=DOC/(name+'-report.json');proof.write_bytes(report.read_bytes())
  result={'name':name,'command':cmd,'exit_code':r.returncode,'passed':r.returncode==expected,'expected_exit_code':expected,'seconds':round(time.monotonic()-start,2),'log':str((DOC/log.name).relative_to(ROOT))}
  if proof:
   j=json.loads(proof.read_text());result['report']=str(proof.relative_to(ROOT));result['reported_passed']=j.get('passed',j.get('result'));result['checks']=len(j.get('checks',[]));result['routes']=len(j.get('routes',[]));result['transitions']=len(j.get('transitions',[]));result['production_save_unchanged']=j.get('production_save_unchanged')
   if j.get('passed') is False or j.get('result')=='FAIL':result['passed']=False
  shutil_copy=DOC/log.name;shutil_copy.write_bytes(log.read_bytes());print('CHECK',name,r.returncode,flush=True);return result
 finally:
  if report:
   if old is None:
    if report.exists():report.unlink()
   else:report.write_bytes(old)
if a.phase=='export':
 results.append(run('world-conventional',['blender','-b',plan['rooms'][0]['blend'],'-t','2','--python-exit-code','1','-P','scripts/cloud_round2_world_export_check.py','--',str(EV)],EV/'world-conventional-report.json'))
 cmd=['blender','-b','-t','2','-P','assets/blender/interiors/scripts/export_existing.py','--','--verify-only','--no-render']
 for r in plan['rooms'][1:]:cmd+=['--room',r['room_id']]
 results.append(run('conventional-export',cmd,ROOT/'assets/blender/interiors/reports/roundtrip_report.json'))
 results.append(run('sync-interiors',['python3','scripts/sync_blender_interiors.py','--require-all','--verify-only']))
 results.append(run('sync-world',['python3','scripts/sync_blender_world.py','--verify-only']))
else:
 results.append(run('godot-import',['godot','--headless','--path','game','--import']))
 if results[-1]['passed']:
  specs=[('letters','test_world_refinement.gd',ROOT/'docs/verification/world-refinement/world-refinement-ABCDEFGHIJKLMNOPQRSTUVWXYZ.json',['--letters=ABCDEFGHIJKLMNOPQRSTUVWXYZ']),('campus','test_school_hierarchy.gd',ROOT/'.local/validation/school-hierarchy-report.json',[]),('household','test_home_indoor.gd',ROOT/'docs/verification/home-indoor-v3/home-indoor-report.json',[])]
  with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
   futures=[pool.submit(run,n,['godot','--headless','--fixed-fps','60','--path','game','--script','res://tests/'+script,'--','--test-harness']+extra,report) for n,script,report,extra in specs]
   for f in concurrent.futures.as_completed(futures):results.append(f.result())
 results.append(run('state-after',['godot','--headless','--path','game','--script','res://tests/test_state.gd'],expected=1))
 # Expected old failure is recorded as a failure of the state suite, not a new PASS.
 results[-1]['known_baseline_failure_expected']=True;results[-1]['passed']=results[-1]['exit_code']==0
output={'phase':a.phase,'results':results,'scope':'Actual current files; existing repository tools; no historical PASS substituted.'};(DOC/(a.phase+'-checks.json')).write_text(json.dumps(output,indent=2)+'\n')
raise SystemExit(0 if all(r['passed'] or (r.get('known_baseline_failure_expected') and r['exit_code']==1) for r in results) else 1)
