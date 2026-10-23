"""Export saved, artist-edited .blend files without invoking any generator.

blender --background --python export_existing.py -- --all
blender --background --python export_existing.py -- --room landmark_A
The .blend files are read-only in this process; exports and previews are refreshed.
"""
import sys, argparse, json, hashlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import bpy, pipeline

parser=argparse.ArgumentParser()
parser.add_argument('--all',action='store_true')
parser.add_argument('--room',action='append')
parser.add_argument('--no-render',action='store_true',help='Keep existing preview; use only for fast integration checks')
parser.add_argument('--verify-only',action='store_true',help='Write isolated roundtrip evidence without changing delivered GLB, previews or manifest')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
if not args.all and not args.room:parser.error('Specify --all or --room room_id')
manifest=pipeline.OUT/'interiors_manifest.json'
data=json.loads(manifest.read_text(encoding='utf-8'))
selected=data['rooms'] if args.all else [r for r in data['rooms'] if r['room_id'] in args.room]
if args.room and len(selected)!=len(set(args.room)):raise ValueError('Room not present in manifest')
evidence=[]
for entry in selected:
    path=pipeline.ROOT/entry['blend']
    before=hashlib.sha256(path.read_bytes()).hexdigest()
    delivered=pipeline.ROOT/entry['glb'];delivered_before=hashlib.sha256(delivered.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(path))
    if args.verify_only:
        folder=pipeline.OUT/'reports'/'roundtrip'/entry['room_id'];folder.mkdir(parents=True,exist_ok=True)
        source=pipeline.collect_source(entry['room_id'])
        if not args.no_render:pipeline.render_preview(folder/'preview.png')
        check_glb=folder/'roundtrip.glb'
        pipeline.export_glb(check_glb)
        stats=pipeline.confirm_export(check_glb,source)
        if stats['triangles_instanced']!=entry['triangles']:raise RuntimeError('Roundtrip geometry changed')
        before_json,_=pipeline.parse_glb(delivered);after_json,_=pipeline.parse_glb(check_glb)
        def geometry_signature(data):
            return {n['name']:{k:n[k] for k in ['translation','rotation','scale','matrix'] if k in n} for n in data.get('nodes',[]) if 'name' in n}
        if geometry_signature(before_json)!=geometry_signature(after_json):raise RuntimeError('Roundtrip node transforms changed')
        evidence.append({'room_id':entry['room_id'],'blend_sha256_before':before,'blend_sha256_after':hashlib.sha256(path.read_bytes()).hexdigest(),
            'delivered_glb_sha256_before':delivered_before,'delivered_glb_sha256_after':hashlib.sha256(delivered.read_bytes()).hexdigest(),
            'roundtrip_glb_sha256':stats['sha256'],'node_transforms_unchanged':True,'triangles_unchanged':True,
            'source_blend_preserved':before==hashlib.sha256(path.read_bytes()).hexdigest(),'rendered_from_reopened_blend':not args.no_render})
        pipeline.write_json(pipeline.OUT/'reports'/'roundtrip_report.json',{'passed':True,'room_count':len(evidence),'rooms':evidence,'scope':'Reopen artist source; export without generator; compare nodes/transforms/triangle counts; hash source and delivered files'})
        # Only this verification copy is removed; evidence includes its checksum.
        if check_glb.resolve().is_relative_to((pipeline.OUT/'reports'/'roundtrip').resolve()):check_glb.unlink()
    else:
        pipeline.finish_room(entry['room_id'],entry['name'],save_blend=False,render=not args.no_render,existing=entry)
    after=hashlib.sha256(path.read_bytes()).hexdigest()
    if before!=after:raise RuntimeError('Source .blend unexpectedly changed: '+str(path))
    if args.verify_only and delivered_before!=hashlib.sha256(delivered.read_bytes()).hexdigest():raise RuntimeError('Delivered GLB changed during verification')
    print('ARTIST_SOURCE_PRESERVED '+entry['room_id']+' '+after,flush=True)
