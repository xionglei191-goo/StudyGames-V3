"""Reopen saved representative sources and compare ordinary exporter geometry."""
import bpy,json,sys,re,importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
sys.path.insert(0,str(ROOT/'assets/blender/interiors/scripts'))
import pipeline as p
import verify_world_refinement as verify

def main():
    proof=ROOT/'docs/verification/world-refinement'
    entries={r['room_id']:r for r in json.loads((ROOT/'assets/blender/interiors/interiors_manifest.json').read_text('utf-8'))['rooms']}
    manifest=json.loads((ROOT/'assets/blender/alphabet_island/game_map_manifest.json').read_text('utf-8'))
    entries['village']={'blend':manifest['working_blend'],'glb':str(Path(manifest['working_blend']).with_suffix('.glb'))}
    folder=ROOT/'.local/world-refinement-roundtrip';folder.mkdir(parents=True,exist_ok=True)
    rows=[]
    for room in ['village','home','landmark_K']:
        entry=entries[room];source=ROOT/entry['blend'];before=verify.sha(source)
        bpy.ops.wm.open_mainfile(filepath=str(source))
        output=folder/(room+'.glb')
        if room=='village':
            spec=importlib.util.spec_from_file_location('island_export',ROOT/'assets/blender/alphabet_island/export_game_map.py')
            island=importlib.util.module_from_spec(spec);spec.loader.exec_module(island)
            island.prepare_export_geometry()
            bpy.ops.object.select_all(action='DESELECT')
            for ob in bpy.context.scene.objects:
                if island.eligible(ob):ob.select_set(True)
            bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_extras=True,export_cameras=False,export_lights=False,export_yup=True)
        else:p.export_glb(output)
        left,lb=verify.load(ROOT/entry['glb']);right,rb=verify.load(output)
        oldnodes={n['name']:n for n in left['nodes']};newnodes={n['name']:n for n in right['nodes']}
        missing=sorted(set(oldnodes)-set(newnodes));extra=sorted(set(newnodes)-set(oldnodes));geometry=[];transforms=[]
        for name in oldnodes.keys() & newnodes.keys():
            a=oldnodes[name];b=newnodes[name]
            if verify.geometry(left,lb,a)!=verify.geometry(right,rb,b):geometry.append(name)
            for key in ['translation','rotation','scale','matrix']:
                av=a.get(key,[]);bv=b.get(key,[])
                if len(av)!=len(bv) or any(abs(x-y)>1e-5 for x,y in zip(av,bv)):transforms.append(name+'/'+key)
        oldmaterials={m['name']:m for m in left.get('materials',[])}
        newmaterials={m['name']:m for m in right.get('materials',[])}
        materials=sorted(set(oldmaterials)^set(newmaterials))
        saved_unchanged=verify.sha(source)==before
        row={'room':room,'passed':not missing and not extra and not geometry and not transforms and not materials and saved_unchanged,
             'source':entry['blend'],'source_sha256':before,'reopened_saved_source':True,'source_unchanged':saved_unchanged,
             'nodes':len(oldnodes),'missing_nodes':missing,'extra_nodes':extra,'geometry_differences':geometry,
             'transform_differences':transforms,'material_name_differences':materials,'triangles_coordinate_multiset_matches':not geometry,
             'ordinary_export_sha256':verify.sha(output),'authored_export_sha256':verify.sha(ROOT/entry['glb'])}
        rows.append(row);print('SAVED_EXPORT_CHECK '+json.dumps(row),flush=True)
    result={'result':'PASS' if all(r['passed'] for r in rows) else 'FAIL','rooms':rows,'scope':'Saved-source reopen through ordinary exporters, all node names, transforms, every mesh triangle coordinate multiset and material names for island, living room and a representative letter room. No source or runtime assets changed.'}
    p.write_json(proof/'saved-export-report.json',result)
    assert result['result']=='PASS',result
if __name__=='__main__':main()
