"""Reopen saved sources and inspect every modified or new evaluated mesh."""
import bpy,json,sys,math
from mathutils import Vector
from pathlib import Path
root=Path(sys.argv[sys.argv.index('--')+1]);ev=Path(sys.argv[sys.argv.index('--')+2]);plan=json.loads((root/'docs/planning/cloud-refinement-round2-20261025.json').read_text());results=[]
def bounds(o):
 pts=[o.matrix_world@Vector(p) for p in o.bound_box]
 return [min(v[i] for v in pts) for i in range(3)],[max(v[i] for v in pts) for i in range(3)]
def tabletop_candidates():
 keys=['ActivityCup','ActivityPaper','ActivityPencils','ScienceCeramic','ScienceSeedling','TeaSet','TeaCloth','FoldedTowels','Soap','PropagationPot','BreakfastCeramics','KitchenHerb','BreadBoard','BreadLoaf','TeamWaterBottles'];out=[]
 old=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.name.startswith(('SG_','CF09_','CF08_','WR_'))]
 cached=[(o,*bounds(o)) for o in old]
 for ob in bpy.context.scene.objects:
  if ob.type!='MESH' or not ob.name.startswith('CF09_') or not any(k in ob.name for k in keys):continue
  a,b=bounds(ob)
  for o,c,d in cached:
   size=[d[i]-c[i] for i in range(3)]
   if max(size)>1.6 or min(size)<.04:continue
   overlap=[min(b[i],d[i])-max(a[i],c[i]) for i in range(3)]
   if min(overlap)>.02 and math.prod(overlap)>.0004:out.append({'new':ob.name,'source':o.name,'aabb_overlap':overlap})
 return out
def view_signature():
 result={}
 for o in bpy.context.scene.objects:
  if o.type in ['CAMERA','LIGHT'] and o.name.startswith('REVIEW_'):
   value={'matrix':[list(r) for r in o.matrix_world]}
   if o.type=='CAMERA':value.update(type=o.data.type,size=o.data.ortho_scale,lens=o.data.lens)
   else:value.update(type=o.data.type,energy=o.data.energy,color=list(o.data.color),angle=o.data.angle if o.data.type=='SUN' else None)
   result[o.name]=value
 w=bpy.context.scene.world
 if w and w.use_nodes:
  bg=w.node_tree.nodes.get('Background')
  result['world']={'color':list(bg.inputs[0].default_value),'strength':bg.inputs[1].default_value}
 result['view_transform']=bpy.context.scene.view_settings.view_transform
 return result
for row in plan['rooms']:
 bpy.ops.wm.open_mainfile(filepath=str(root/row['first_blend']));bpy.context.view_layer.update();before_view=view_signature()
 rid=row['room_id'];changes=json.loads((ev/rid/'changes.json').read_text());names=set(changes['reshaped']);bpy.ops.wm.open_mainfile(filepath=str(root/row['blend']));bpy.context.view_layer.update();graph=bpy.context.evaluated_depsgraph_get();errors=[];count=0;tri=0
 for o in bpy.context.scene.objects:
  if o.type!='MESH' or not (o.name.startswith('CF09_') or o.name in names):continue
  count+=1;eo=o.evaluated_get(graph);me=eo.to_mesh();me.calc_loop_triangles();tri+=len(me.loop_triangles)
  if any(not math.isfinite(x) for v in me.vertices for x in v.co):errors.append(o.name+'/nonfinite')
  tiny=sum(t.area<1e-10 for t in me.loop_triangles)
  if tiny:errors.append(o.name+'/degenerate/'+str(tiny))
  eo.to_mesh_clear()
 if before_view!=view_signature():errors.append('comparison_camera_or_lighting_changed')
 props=tabletop_candidates()
 if props:errors.append('new_tabletop_prop_overlap_candidates')
 external=[i.name for i in bpy.data.images if i.source=='FILE' and i.filepath and not i.packed_file]
 result={'room_id':rid,'passed':not errors and not external,'reopened':True,'same_saved_cameras_and_lights':before_view==view_signature(),'modified_meshes':count,'evaluated_triangles':tri,'errors':errors,'unpacked_images':external,'tabletop_overlap_candidates':props,'tabletop_check_scope':'New tabletop story props against retained small source objects in all task states; AABB screening, not a universal mesh-intersection proof.'};results.append(result);print('SAVED_ROUND2',rid,result['passed'],errors[:5],flush=True)
(ev/'saved_blend_validation.json').write_text(json.dumps({'passed':all(r['passed'] for r in results),'blender':bpy.app.version_string,'rooms':results},indent=2))
if not all(r['passed'] for r in results):raise RuntimeError('Saved source QA failed')
