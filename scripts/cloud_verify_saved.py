"""Reopen every delivered .blend and inspect actual added mesh geometry."""
import bpy,json,sys,math
from pathlib import Path
args=sys.argv[sys.argv.index('--')+1:];root=Path(args[0]);ev=Path(args[1]);data=json.loads((ev/'asset_validation.json').read_text());results=[]
for row in data['rooms']:
    path=root/row['blend'];bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.view_layer.update()
    errors=[];count=0;triangles=0;graph=bpy.context.evaluated_depsgraph_get()
    for ob in bpy.context.scene.objects:
        if ob.type!='MESH' or not ob.name.startswith('CF08_'):continue
        count+=1;eo=ob.evaluated_get(graph);mesh=eo.to_mesh();mesh.calc_loop_triangles();triangles+=len(mesh.loop_triangles)
        if any(not math.isfinite(x) for v in mesh.vertices for x in v.co):errors.append(ob.name+'/nonfinite')
        tiny=sum(t.area<1e-10 for t in mesh.loop_triangles)
        if tiny:errors.append(ob.name+'/degenerate/'+str(tiny))
        eo.to_mesh_clear()
    external=[im.name for im in bpy.data.images if im.source=='FILE' and im.filepath and not im.packed_file]
    result={'room':row['room_id'],'saved_blend_reopened':True,'new_mesh_objects':count,'evaluated_added_triangles':triangles,'mesh_errors':errors,'unpacked_external_images':external,'passed':not errors and not external}
    results.append(result);print('SAVED_BLEND',row['room_id'],result['passed'],flush=True)
(ev/'saved_blend_validation.json').write_text(json.dumps({'passed':all(r['passed'] for r in results),'blender':bpy.app.version_string,'rooms':results},indent=2))
if not all(r['passed'] for r in results):raise RuntimeError('Saved blend validation failed')
