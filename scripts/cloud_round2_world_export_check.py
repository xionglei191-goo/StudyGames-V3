"""Run the original world exporter with isolated output paths; never save over delivery."""
import bpy,sys,json,importlib.util,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts'));import verify_world_refinement as v
from cloud_validate_assets import triangles,parent_names
EV=Path(sys.argv[sys.argv.index('--')+1]);r=json.loads((ROOT/'docs/planning/cloud-refinement-round2-20261025.json').read_text())['rooms'][0]
paths=[ROOT/r['blend'],ROOT/r['glb'],ROOT/'assets/blender/alphabet_island/game_map_manifest.json'];before={str(p):v.sha(p) for p in paths}
spec=importlib.util.spec_from_file_location('original_export_game_map',ROOT/'assets/blender/alphabet_island/export_game_map.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
folder=ROOT/'.local/round2-world-export';folder.mkdir(parents=True,exist_ok=True);module.WORKING=folder/'island-roundtrip.blend';module.OUTPUT=folder/'island-roundtrip.glb';module.MANIFEST=folder/'manifest.json';bpy.context.preferences.filepaths.save_version=0
original_argv=sys.argv[:]
try:
 # Do not pass this harness's evidence directory to the original exporter's CLI.
 sys.argv=sys.argv[:sys.argv.index('--')] if '--' in sys.argv else sys.argv
 module.main()
finally:sys.argv=original_argv
old,ob=v.load(ROOT/r['glb']);new,nb=v.load(module.OUTPUT)
def sig(data):return {n['name']:{k:n[k] for k in ['translation','rotation','scale','matrix'] if k in n} for n in data['nodes'] if 'name' in n}
names={n['name']:n for n in new['nodes']};errors=[]
for node in v.protected(old):
 n=node['name']
 if n not in names or v.geometry(old,ob,node)!=v.geometry(new,nb,names[n]) or node.get('extras',{})!=names[n].get('extras',{}):errors.append(n)
roundtrip_manifest=json.loads(module.MANIFEST.read_text());delivered_manifest=json.loads(paths[2].read_text())
checks={'same_nodes_and_transforms':sig(old)==sig(new),'same_triangle_count':triangles(old)==triangles(new),'manifest_triangles_match_actual':roundtrip_manifest.get('triangles')==triangles(new),'preview_preserved':roundtrip_manifest.get('preview')==delivered_manifest.get('preview'),'protected_geometry_and_metadata':not errors,'delivered_files_unchanged':all(v.sha(Path(p))==sha for p,sha in before.items())}
result={'passed':all(checks.values()),'exporter':'assets/blender/alphabet_island/export_game_map.py','checks':checks,'errors':errors,'triangles':triangles(new),'roundtrip_glb_sha256':v.sha(module.OUTPUT),'delivered_before':before,'scope':'Original exporter main() executed against the saved source, with only output destinations redirected to .local. Source geometry and manifest delivery not modified.'};(EV/'world-conventional-report.json').write_text(json.dumps(result,indent=2)+'\n');print('WORLD_CONVENTIONAL',json.dumps(result),flush=True)
for p in [module.WORKING,module.OUTPUT,module.MANIFEST]:p.unlink()
if not result['passed']:raise RuntimeError('World conventional export roundtrip failed')
