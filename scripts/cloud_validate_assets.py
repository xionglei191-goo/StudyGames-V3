"""Compare exported geometry and contracts against the current, untouched sources."""
import json,sys,hashlib,collections,os
from pathlib import Path
import verify_world_refinement as v
ROOT=Path(__file__).resolve().parents[1];EV=Path(os.environ.get('STUDYGAMES_REFINEMENT_EVIDENCE',ROOT/'.local/cloud-refinement/evidence'))

def digest(p):
    with Path(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def parent_names(data):return {data['nodes'][c]['name']:n['name'] for n in data['nodes'] for c in n.get('children',[])}
def triangles(data):
    return sum(data['accessors'][p['indices']]['count']//3 if 'indices' in p else data['accessors'][p['attributes']['POSITION']]['count']//3 for n in data['nodes'] if 'mesh' in n for p in data['meshes'][n['mesh']]['primitives'] if p.get('mode',4)==4)

def main():
    rows=json.loads((EV/'refined_rooms.json').read_text())
    assert len(rows)==17,'Refinement batch is incomplete'
    rows.insert(0,{'room_id':'island','original_blend':'assets/blender/alphabet_island/alphabet_island_layout_v07_game.blend','original_glb':'assets/blender/alphabet_island/alphabet_island_layout_v07_game.glb','blend':'assets/blender/alphabet_island/alphabet_island_layout_v08_cloud.blend','glb':'assets/blender/alphabet_island/alphabet_island_layout_v08_cloud.glb'})
    lf={x['name']:x for x in json.loads((EV/'lfs_integrity.json').read_text())['files']};results=[]
    for row in rows:
        room=row['room_id'];old,ob=v.load(ROOT/row['original_glb']);new,nb=v.load(ROOT/row['glb']);names={n['name']:n for n in new['nodes']};original={n['name']:n for n in old['nodes']}
        op,np=parent_names(old),parent_names(new);missing=sorted(set(original)-set(names));transforms=[];geometry=[];metadata=[];hierarchy=[]
        protected=v.protected(old)
        for node in protected:
            n=node['name'];target=names.get(n)
            if target is None:continue
            for key,default in [('translation',[0,0,0]),('rotation',[0,0,0,1]),('scale',[1,1,1]),('matrix',[])]:
                a=node.get(key,default);b=target.get(key,default)
                if len(a)!=len(b) or any(abs(x-y)>1e-5 for x,y in zip(a,b)):transforms.append(n+'/'+key)
            if node.get('extras',{})!=target.get('extras',{}):metadata.append(n)
            if op.get(n)!=np.get(n):hierarchy.append(n)
            if v.geometry(old,ob,node)!=v.geometry(new,nb,target):geometry.append(n)
        external=[x.get('uri') for x in new.get('images',[]) if x.get('uri') and not x['uri'].startswith('data:')]
        missing_uv=[]
        for mesh in new['meshes']:
            for p in mesh['primitives']:
                m=new.get('materials',[])[p['material']] if 'material' in p else {}
                if ('baseColorTexture' in m.get('pbrMetallicRoughness',{}) or 'normalTexture' in m) and 'TEXCOORD_0' not in p['attributes']:missing_uv.append(mesh.get('name'))
        originals={key:digest(ROOT/row[key])==lf[row[key]]['oid'] for key in ['original_blend','original_glb']}
        changes=json.loads((EV/room/'changes.json').read_text())
        result={**row,'passed':not(missing or transforms or geometry or metadata or hierarchy or external or missing_uv) and all(originals.values()),
          'original_files_unchanged':originals,'all_original_node_names_retained':not missing,'protected_exported_nodes':len(protected),
          'protected_triangle_multisets_equal_at_1e_5':not geometry,'protected_transform_tolerance':1e-5,
          'geometry_differences':geometry,'transform_differences':transforms,'metadata_differences':metadata,'hierarchy_differences':hierarchy,'missing_nodes':missing,
          'external_images':external,'missing_uv':missing_uv,'embedded_images':len(new.get('images',[])),
          'original_nodes':len(old['nodes']),'exported_nodes':len(new['nodes']),'original_triangles':triangles(old),'exported_triangles':triangles(new),
          'original_bytes':(ROOT/row['original_glb']).stat().st_size,'glb_bytes':(ROOT/row['glb']).stat().st_size,'glb_sha256':digest(ROOT/row['glb']),'blend_sha256':digest(ROOT/row['blend']),
          'new_mesh_objects':changes['new_mesh_objects'],'repair_count':len(changes['repairs'])}
        results.append(result);print('ASSET',room,'PASS' if result['passed'] else 'FAIL',len(geometry),len(transforms),flush=True)
    report={'passed':all(x['passed'] for x in results),'base_commit':'74fdcf79d39f5ce6d5dfc8723ae96e35a2da8c41','source_import_limitation':'Blender 5.2 authoring source cannot be opened in installed 4.3.2. The actual current GLBs were imported; source files retained. Original modifier/curve authoring history is not reconstructed.','rooms':results}
    (EV/'asset_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));sys.exit(0 if report['passed'] else 1)

if __name__=='__main__':main()
