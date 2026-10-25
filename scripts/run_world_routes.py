"""Run the physical-route suites on the final 44 assets with source provenance."""
from pathlib import Path
import hashlib,json,subprocess,shutil,time
ROOT=Path(__file__).resolve().parents[1]
PROOF=ROOT/'docs/verification/world-refinement'
GODOT='F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe'
def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def signature():
    files=[ROOT/'game/assets/world/island.glb',*sorted((ROOT/'game/assets/interiors').glob('*.glb')),
           *sorted((ROOT/'game/scripts').glob('*.gd')),ROOT/'game/data/interiors_manifest.json']
    return {p.relative_to(ROOT).as_posix():sha(p) for p in files}
def main():
    before=signature();rows=[]
    suites=[('letters-A-M','test_world_refinement.gd',['--letters=ABCDEFGHIJKLM'],PROOF/'world-refinement-ABCDEFGHIJKLM.json'),
            ('letters-N-Z','test_world_refinement.gd',['--letters=NOPQRSTUVWXYZ'],PROOF/'world-refinement-NOPQRSTUVWXYZ.json'),
            ('campus','test_school_hierarchy.gd',[],ROOT/'.local/validation/school-hierarchy-report.json'),
            ('home','test_home_indoor.gd',[],ROOT/'docs/verification/home-indoor-v3/home-indoor-report.json')]
    for name,script,args,path in suites:
        started=time.time()
        command=[GODOT,'--headless','--fixed-fps','60','--path',str(ROOT/'game'),'--script','res://tests/'+script,'--','--test-harness',*args]
        with (PROOF/(name+'-final.log')).open('w',encoding='utf-8') as log:
            result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        assert result.returncode==0,(name,result.returncode)
        assert path.stat().st_mtime>=started,(name,'stale report')
        report=json.loads(path.read_text('utf-8'))
        assert report['passed'] and report['complete'] and report['actual_physics_movement'] and report['production_save_unchanged']
        destination=PROOF/(name+'-routes.json')
        shutil.copy2(path,destination)
        row={'suite':name,'passed':True,'checks':len(report['checks']),'routes':len(report['routes']),'transitions':len(report['transitions']),
             'report':destination.relative_to(ROOT).as_posix(),'report_sha256':sha(destination),'command':command,'seconds':round(time.time()-started,2)}
        rows.append(row);print('WORLD_ROUTES_PASS '+json.dumps(row),flush=True)
    after=signature();assert before==after,'Runtime changed during acceptance'
    output={'result':'PASS','suites':rows,'checks':sum(r['checks'] for r in rows),'routes':sum(r['routes'] for r in rows),
            'transitions':sum(r['transitions'] for r in rows),'source_sha256':before,'source_stable':True,'production_save_unchanged':True,
            'scope':'Headless 60 fixed simulation frames, actual CharacterBody movement. 26 letter doors and 130 loci, campus and seven rooms with 40 loci, house/hall and seven rooms with 40 loci and eight chores. Native visual acceptance is separate.'}
    (PROOF/'route-report.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('WORLD_ROUTES_COMPLETE '+json.dumps({k:output[k] for k in ['result','checks','routes','transitions']}),flush=True)
if __name__=='__main__':main()
