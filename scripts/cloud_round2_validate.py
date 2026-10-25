"""Independent binary GLB compatibility / performance accounting for round two."""
from pathlib import Path
import sys,json,collections,argparse
import verify_world_refinement as v
from cloud_validate_assets import triangles,parent_names,digest
p=argparse.ArgumentParser();p.add_argument('--evidence',required=True);a=p.parse_args();EV=Path(a.evidence);ROOT=Path(__file__).resolve().parents[1]
plan=json.loads((ROOT/'docs/planning/cloud-refinement-round2-20261025.json').read_text());rows=[]
def ordered_ground(data,blob,node):
 import hashlib
 h=hashlib.sha256()
 for p in data['meshes'][node['mesh']]['primitives']:
  points=v.accessor(data,blob,p['attributes']['POSITION']);indices=v.accessor(data,blob,p['indices']) if 'indices' in p else [(i,) for i in range(len(points))]
  h.update(repr([points[i[0]] for i in indices]).encode())
 return h.hexdigest()
for row in plan['rooms']:
 rid=row['room_id'];old,ob=v.load(ROOT/row['first_glb']);new,nb=v.load(ROOT/row['glb']);oldnames={n['name']:n for n in old['nodes']};names={n['name']:n for n in new['nodes']};op,np=parent_names(old),parent_names(new)
 errors=[];protected=v.protected(old)
 for node in protected:
  name=node['name'];other=names.get(name)
  if other is None:errors.append(name+'/missing');continue
  for key,default in [('translation',[0,0,0]),('rotation',[0,0,0,1]),('scale',[1,1,1]),('matrix',[])]:
   x=node.get(key,default);y=other.get(key,default)
   if len(x)!=len(y) or any(abs(i-j)>1e-5 for i,j in zip(x,y)):errors.append(name+'/'+key)
  if node.get('extras',{})!=other.get('extras',{}):errors.append(name+'/extras')
  if op.get(name)!=np.get(name):errors.append(name+'/parent')
  if v.geometry(old,ob,node)!=v.geometry(new,nb,other):errors.append(name+'/geometry')
  if node.get('extras',{}).get('sg_collision')=='ground' and ordered_ground(old,ob,node)!=ordered_ground(new,nb,other):errors.append(name+'/ground_surface_face_order')
 missing=sorted(set(oldnames)-set(names));external=[i.get('uri') for i in new.get('images',[]) if i.get('uri') and not i['uri'].startswith('data:')];uv=[]
 for mesh in new['meshes']:
  for prim in mesh['primitives']:
   m=new.get('materials',[])[prim['material']] if 'material' in prim else {}
   if ('baseColorTexture' in m.get('pbrMetallicRoughness',{}) or 'normalTexture' in m) and 'TEXCOORD_0' not in prim['attributes']:uv.append(mesh.get('name'))
 preserved={key:digest(ROOT/row[key])==row[key+'_sha256'] for key in ['original_blend','original_glb','first_blend','first_glb']}
 change=json.loads((EV/rid/'changes.json').read_text())
 def image_hashes(data,blob):
  out=[]
  import hashlib
  for im in data.get('images',[]):
   if 'bufferView' in im:
    b=data['bufferViews'][im['bufferView']];off=b.get('byteOffset',0);out.append(hashlib.sha256(blob[off:off+b['byteLength']]).hexdigest())
  return collections.Counter(out)
 oi=image_hashes(old,ob);ni=image_hashes(new,nb)
 r={**row,'passed':not(errors or missing or external or uv) and all(preserved.values()),'protected_exported_nodes':len(protected),'protected_triangle_multisets_equal_at_1e_5':not errors,'protected_errors':errors,'missing_nodes':missing,'missing_uv':uv,'external_images':external,'preserved_files':preserved,'first_triangles':triangles(old),'exported_triangles':triangles(new),'first_materials':len(old.get('materials',[])),'materials':len(new.get('materials',[])),'first_nodes':len(old['nodes']),'nodes':len(new['nodes']),'first_images':len(old.get('images',[])),'embedded_images':len(new.get('images',[])),'first_image_entries_retained':sum((oi&ni).values()),'first_image_entries_replaced_or_unused':sum((oi-ni).values()),'first_bytes':(ROOT/row['first_glb']).stat().st_size,'glb_bytes':(ROOT/row['glb']).stat().st_size,'glb_sha256':digest(ROOT/row['glb']),'blend_sha256':digest(ROOT/row['blend']),'first_animations':len(old.get('animations',[])),'animations':len(new.get('animations',[])),'skins':len(new.get('skins',[])),'reshaped_objects':change['reshaped_count'],'new_mesh_objects':change['new_mesh_objects']}
 rows.append(r);print('ROUND2_ASSET',rid,'PASS' if r['passed'] else 'FAIL',r['first_triangles'],r['exported_triangles'],errors[:5],flush=True)
report={'passed':all(r['passed'] for r in rows),'base_commit':plan['base_commit'],'source_import_limitation':plan['source_limitation'],'round2_method':'Native edit of round-one saved Blender 4.3 files, preserving original 5.2 files and first-round assets. No second GLB import. Original authoring history remains unavailable.','rooms':rows}
(EV/'asset_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');sys.exit(0 if report['passed'] else 1)
