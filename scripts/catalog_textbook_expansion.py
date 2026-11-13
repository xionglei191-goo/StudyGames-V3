"""Build the source-backed catalog from visually reviewed intake matches.

--rename performs the user-requested in-place UUID-to-semantic renaming, only
after a complete one-to-one mapping and SHA-256 checks. No file is overwritten.
"""
from pathlib import Path
import csv, hashlib, json, sys
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/characters/textbook_expansion_v1'
SOURCE=ROOT/'assets/tripo/generation_selection_20261112'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
inventory=read(OUT/'intake/inventory.json')
matches=read(OUT/'intake/matches.json')
assert len(set(matches.values()))==len(matches),'Duplicate identity match'
named={}
for batch in ['01_priority_48','02_optional_12']:
    for row in csv.DictReader((SOURCE/batch/'naming.csv').open(encoding='utf-8-sig')):
        named[row['顺序']]={**row,'batch':batch}
assert all(code in named for code in matches.values())
QUADS={'P13','P14','P15','P17','P18','P19','P21','P22'}
BIRDS={'P20','P23'}
CHILDREN={'P10','P11','P12','P27','O01','O02','O08'}
SKIRTS={'P06':.17,'P09':.23,'P10':.23,'P11':.27,'P25':.07,'P26':.09,'P29':.05,'P30':.075,'O03':.14}
HEIGHTS={'P13':1.1,'P14':.9,'P15':1.7,'P16':.60,'P17':1.15,'P18':.90,'P19':1.6,'P20':.85,'P21':1.25,'P22':.80,'P23':.90,'P24':1.8,'O04':1.9,'O05':2.05}
PROP_SIZES={'P33':.38,'P34':.29,'P35':.40,'P36':.45,'P37':.29,'P38':.34,'P39':.37,'P40':.35,'P41':1.75,'P42':1.65,'P43':.95,'P44':1.05,'P45':1.00,'P46':.81,'P47':.57,'P48':.55}
# Rotations are recorded from the identity views, not inferred from download order.
ROTATIONS={'P44':0,'P35':0,'P37':0,'P40':0,'P21':0,'P33':0,'P23':180}
assets=[];fitting={}
previous=read(OUT/'fitting.json').get('models',{}) if (OUT/'fitting.json').exists() else {}
for source in inventory:
    key=source['intake_id']
    if key not in matches:continue
    code=matches[key];choice=named[code];ident=Path(choice['建议 GLB 名称']).stem
    prop=ident.startswith('prop_')
    kind='prop' if prop else 'animal' if code in QUADS|BIRDS|{'P16','O04','O05'} else 'human'
    rig='static' if prop else 'quadruped' if code in QUADS else 'bird' if code in BIRDS else 'fish' if code=='P16' else 'robot' if code=='P24' else 'biped'
    reference=(SOURCE/choice['batch']/choice['图片文件']).relative_to(ROOT).as_posix()
    row=dict(id=ident,selection_code=code,intake_id=key,name=choice['名称'],category='prop' if prop else 'character',kind=kind,rig_type=rig,
        source=source['source'],original_filename=source['original_filename'],source_sha256=source['source_sha256'],reference=reference,
        target_filename=choice['建议 GLB 名称'],height=HEIGHTS.get(code,2.00 if code in CHILDREN else 2.25),
        rotation_z=ROTATIONS.get(code,-90),provenance='User generated Tripo GLB from the project reference image; source bytes retained')
    if prop:row['max_dimension']=PROP_SIZES[code]
    assets.append(row)
    if rig in ['biped','robot']:
        spec=dict(height=row['height'],rotation_z=row['rotation_z'],hip=.45,shoulder=.70,neck=.74,head=.775,elbow=.54,wrist=.405,
            knee=.25,ankle=.055,sx=.115,ex=.20,wx=.26,legx=.075,wave_upper_angle=50,wave_lower_angle=70,
            region_blend_width=.045,weight_smoothing_iterations=64,arm_joint_prior=.55)
        if code in CHILDREN:spec.update(hip=.39,shoulder=.63,neck=.67,head=.715,elbow=.49,wrist=.38,knee=.21,legx=.075)
        if code in SKIRTS:spec.update(skirt_bottom=SKIRTS[code],skirt_top=spec['hip'],stride_scale=.50 if SKIRTS[code]<.15 else .75,wave_upper_angle=32,wave_lower_angle=65)
        if code=='P25':spec.update(neck=.70,head=.75,shoulder=.66,hip=.40,skirt_radius=.28,wide_sleeves=True)
        if code=='P24':spec.update(hip=.39,shoulder=.58,neck=.65,head=.68,elbow=.45,wrist=.33,knee=.22,wx=.23,weight_smoothing_iterations=12)
        if code in ['O04','O05']:spec.update(hip=.34,shoulder=.55,neck=.62,head=.66,elbow=.43,wrist=.32,knee=.18,legx=.085,
            tail=[-.13,.27,-.16],tail_bounds=[-.50,-.07,.12,.42,-1,-.13])
        spec.update(previous.get(ident,{}))
        fitting[ident]=spec
write(OUT/'catalog.json',dict(schema_version=1,status='complete_identity_review' if len(assets)==56 else 'partial_identity_review',assets=assets))
write(OUT/'fitting.json',dict(schema_version=1,models=fitting))
if '--rename' in sys.argv:
    assert len(assets)==56 and len(matches)==56
    assert {a['selection_code'] for a in assets}=={f'P{i:02}' for i in range(1,49)}|{f'O{i:02}' for i in range(1,9)}
    operations=[]
    for row in assets:
        source=ROOT/row['source'];target=source.with_name(row['target_filename'])
        assert source.parent.resolve().is_relative_to(SOURCE.resolve())
        assert source.exists(),source
        assert source==target or not target.exists(),target
        assert hashlib.sha256(source.read_bytes()).hexdigest()==row['source_sha256']
        operations.append((row,source,target))
    for row,source,target in operations:
        if source!=target:source.rename(target)
        assert hashlib.sha256(target.read_bytes()).hexdigest()==row['source_sha256']
        row['source']=target.relative_to(ROOT).as_posix()
        for original in inventory:
            if original['intake_id']==row['intake_id']:original['source']=row['source']
        prepfile=OUT/'intake'/row['intake_id']/'preparation.json'
        prep=read(prepfile);prep['source']=row['source'];write(prepfile,prep)
        rigfile=OUT/row['id']/'rig.json'
        if rigfile.exists():
            rig=read(rigfile);rig['source']=row['source'];write(rigfile,rig)
    write(OUT/'catalog.json',dict(schema_version=1,status='complete_identity_review',assets=assets))
    write(OUT/'intake/inventory.json',inventory)
    write(SOURCE/'model-renaming.json',dict(schema_version=1,count=len(assets),bytes_preserved=True,files=assets))
print('EXPANSION_CATALOG',len(assets),'assets',len(fitting),'bipeds')
