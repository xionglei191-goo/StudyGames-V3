"""Run sequential native Godot batches, never alongside performance measurement."""
from pathlib import Path
import argparse, json, subprocess, sys
ROOT=Path(__file__).resolve().parents[1]
GODOT=Path('F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe')
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('stage',choices=['before','after'])
parser.add_argument('--start',type=int,default=1)
parser.add_argument('--end',type=int,default=6)
args=parser.parse_args()
rooms=[r['room_id'] for r in json.loads((ROOT/'docs/planning/world-refinement/baseline.json').read_text(encoding='utf-8'))['rooms']]
for index in range(args.start,args.end+1):
    batch=f'{index:02d}'
    subset=rooms[(index-1)*8:index*8]
    if not subset: continue
    folder=ROOT/f'docs/verification/world-refinement/{args.stage}/{batch}'
    folder.mkdir(parents=True,exist_ok=True)
    print('CAPTURE_BATCH_START',args.stage,batch,','.join(subset),flush=True)
    with (folder/'run.log').open('w',encoding='utf-8') as log:
        result=subprocess.run([str(GODOT),'--path',str(ROOT/'game'),'--resolution','1440x900','--script','res://tests/capture_world_refinement.gd','--',
            '--test-harness',f'--refinement-stage={args.stage}',f'--batch={batch}','--rooms='+','.join(subset)],
            stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    if result.returncode: raise SystemExit(f'Capture batch {batch} failed: {result.returncode}; {folder}/run.log')
    report=json.loads((folder/'report.json').read_text(encoding='utf-8'))
    if report['result']!='PASS': raise SystemExit(f'Capture batch {batch} failed checks')
    print('CAPTURE_BATCH_PASS',batch,len(report['captures']),flush=True)
