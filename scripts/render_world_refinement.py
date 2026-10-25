"""Render new versioned source previews without saving or re-exporting any source."""
import bpy,json,sys,hashlib,argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'assets/blender/interiors/scripts'))
import pipeline as p
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--rooms',default='')
parser.add_argument('--refresh',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
selected=set(args.rooms.split(',')) if args.rooms else set()
report=ROOT/'docs/verification/world-refinement/source-previews.json'
rows=json.loads(report.read_text('utf-8')) if report.exists() else []
for file in sorted((ROOT/'assets/blender/interiors').glob('*/*v*.manifest-entry.json')):
    entry=json.loads(file.read_text(encoding='utf-8'))
    if entry.get('refinement_revision')!='world-refinement-v1': continue
    if selected and entry['room_id'] not in selected: continue
    source=ROOT/entry['blend']
    version=source.stem.rsplit('_',1)[-1]
    preview=source.parent/f'preview_{version}.png'
    entry['preview']=preview.relative_to(ROOT).as_posix()
    p.write_json(file,entry)
    if preview.exists() and not args.refresh: continue
    before=hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene=bpy.context.scene
    if not scene.camera: raise RuntimeError('No saved preview camera: '+str(source))
    ratio=scene.render.resolution_y/scene.render.resolution_x
    scene.render.resolution_x=1200;scene.render.resolution_y=round(1200*ratio);scene.render.resolution_percentage=100
    if hasattr(scene,'eevee') and hasattr(scene.eevee,'taa_render_samples'): scene.eevee.taa_render_samples=32
    p.render_preview(preview)
    assert hashlib.sha256(source.read_bytes()).hexdigest()==before
    rows=[r for r in rows if r['room']!=entry['room_id']]
    rows.append({'room':entry['room_id'],'image':entry['preview'],'saved_blend_unchanged':True,'source_sha256':before})
    print('WORLD_PREVIEW_RENDERED '+entry['room_id'],flush=True)
p.write_json(report,rows)
