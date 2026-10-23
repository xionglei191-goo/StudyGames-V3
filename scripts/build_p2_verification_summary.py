"""Build a bounded current P0-P2 evidence index; never infer PASS from file existence."""
from pathlib import Path
import hashlib,json,struct
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/verification/p2'
def read(name):return json.loads((OUT/name).read_text(encoding='utf-8'))
reports=['state-report.json','actor-animation.json','orchard-integration.json','story-animation.json','alternate-choices.json',
 'learning-art/headless-1440x900-report.json',
 *[f'{prefix}-{size}-native.json' for size in ['1440x900','960x640'] for prefix in ['ui','chapters','journey-game']]]
checks=[]
for name in reports:
    obj=read(name)
    status=obj.get('status',obj.get('result',''))
    passed=str(status).lower() in ['pass','passed'] and not obj.get('failures')
    count=obj.get('checks',obj.get('assertions',0))
    checks.append({'report':name,'passed':passed,'checks':len(count) if isinstance(count,list) else count})
jobs=read('final-run.json')
expected={f'test_{s}' for s in ['state','journey_state','p2_state','memory_event_sink','living_world','p1_orchard','p1_story_animation']}|{f'{s}-{n}' for s in ['landmarks','chapters','journey'] for n in ['1440x900','960x640']}
jobs_passed={r['name'] for r in jobs}==expected and all(r['exit_code']==0 and not r['errors'] for r in jobs)
performance=read('performance-current/summary.json') if (OUT/'performance-current/summary.json').exists() else {}
source=read('source-preservation.json')
planning=json.loads((ROOT/'docs/planning/integration/integration_summary.json').read_text(encoding='utf-8'))
planning_passed=str(planning.get('result',planning.get('status',''))).lower() in ['pass','passed'] and not planning.get('errors')
captures=[]
for folder in sorted(OUT.glob('native-*')):
    files=[]
    for p in sorted(folder.glob('*.png')):
        b=p.read_bytes()
        files.append({'path':str(p.relative_to(ROOT)).replace('\\','/'),'pixels':list(struct.unpack('>II',b[16:24])),'sha256':hashlib.sha256(b).hexdigest()})
    captures.append({'folder':folder.name,'count':len(files),'files':files})
result={'version':'0.8.0-dev','scope':'GDD project P0-P2 engineering, local Windows source build; not P3/full textbook production or human validation',
 'reports':checks,'final_jobs':jobs,'final_jobs_passed':jobs_passed,'planning_integration_passed':planning_passed,
 'source_preservation_passed':source['passed'],'source_protected_records':len(source['protected']),
 'landmark_source_views':len(source['landmark_views']),
 'performance_record_valid':performance.get('formal_record_valid',False),
 'performance_invalid_reasons':performance.get('invalid_reasons',['not_finished']),
 'native_captures':captures,
 'visual_review':{'method':'Agent inspected original captures and contact sheets, separately from input/layout assertions',
  'reviewed':'All B-Z before/after at 1440 via five contact sheets; all 26 source-model front views via three sheets; detailed J/K/I/R/T/V steps and both-size home/chapter/photo/route samples; four second-option F/H/P/R native captures',
  'limits':'Not an independent human art review or a child usability study'},
 'remaining_human_validation':['Independent textbook/editorial review','Synthetic voice listening review','Child usability sessions','Longitudinal memory-effect evaluation'],
 'later_scope':['P3 full eight-book 81-chapter production','All 144 character identities produced','All weather/time/quality/hardware combinations','P4 expansion']}
result['engineering_evidence_passed']=all(r['passed'] for r in checks) and jobs_passed and planning_passed and source['passed'] and result['performance_record_valid']
(OUT/'verification-summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:result[k] for k in ['engineering_evidence_passed','final_jobs_passed','source_preservation_passed','performance_record_valid']},ensure_ascii=False))
raise SystemExit(0 if result['engineering_evidence_passed'] else 1)
