"""Save the inspected scene and export the active world as GLB.
Run with studygame_world loaded and attached to this scene.
"""
import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector
import studygame_world as w

scene=w.SCENE
version=scene.get('output_version','v01')
version_number=int(version.removeprefix('v'))
bpy.context.window.scene=scene
sockets=[o for o in scene.objects if o.name.startswith('ALPHA_LANDMARK_') and o.name.endswith('_SOCKET')]
loci=[o for o in scene.objects if o.get('memory_sequence')]
assert len(sockets)==26 and len(loci)==130
assert all(len([o for o in loci if o.get('landmark')==p['letter']])==5 for p in w.PLOTS)
# Route graph is a planning check; it does not establish engine walkability.
adj={}
for r in w.ROUTE_RECORDS:
    if r['type']=='path':
        a,b=r['from'],r['to'];adj.setdefault(a,set()).add(b);adj.setdefault(b,set()).add(a)
seen={'HOME'};queue=['HOME']
while queue:
    node=queue.pop()
    for other in adj.get(node,[]):
        if other not in seen:seen.add(other);queue.append(other)
assert all(p['letter'] in seen for p in w.PLOTS)
school_root=bpy.data.objects.get('ALPHA_SCHOOL_ROOT')
school_anchors=[o for o in scene.objects if o.get('school_anchor_sequence')]
if school_root:
    assert 'SCHOOL' in seen and len(school_anchors)==5
placements=[];sources=[]
for p in w.PLOTS:
    socket=bpy.data.objects[p['socket_name']]
    src=socket.get('source_file')
    row={**p,'socket_location':list(socket.location),'status':socket.get('asset_status'),'source_file':src,'source_sha256':socket.get('source_sha256'),
         'memory_anchors':[{'name':o.name,'sequence':o['memory_sequence'],'location':list(o.matrix_world.translation)} for o in sorted(loci,key=lambda a:a.name) if o.get('landmark')==p['letter']]}
    if src:
        digest=hashlib.sha256(Path(src).read_bytes()).hexdigest();assert digest==socket['source_sha256']
        objects=[o for o in socket.children_recursive if o.type=='MESH' and not o.get('editor_only')]
        corners=[o.matrix_world@Vector(v) for o in objects for v in o.bound_box]
        mn=[min(v[k] for v in corners) for k in range(3)];mx=[max(v[k] for v in corners) for k in range(3)]
        row['bounds_world']={'min':mn,'max':mx};row['dimensions']=[mx[k]-mn[k] for k in range(3)]
        assert abs(row['dimensions'][0]-p['target_width'])<.01
        row['triangles']=0
        for o in objects:o.data.calc_loop_triangles();row['triangles']+=len(o.data.loop_triangles)
        row['source_triangles']=socket.get('map_source_triangles',row['triangles'])
        row['map_texture_max_px']=socket.get('map_texture_max_px')
        row['entry_front_y']=socket.get('entry_front_y')
        sources.append({'letter':p['letter'],'sha256_unchanged':True,'source_file':src,'source_triangles':row['source_triangles'],'map_triangles':row['triangles']})
    placements.append(row)
finite=all(math.isfinite(v) for o in scene.objects for row in o.matrix_world for v in row)
assert finite
for o in scene.objects:
    if o.type=='MESH':assert all(math.isfinite(v) for vert in o.data.vertices for v in vert.co)
manifest={'version':version_number,'scene':scene.name,'units':'meters','blender_axes':'Z up; fronts -Y','landmarks':placements,'imported':[r['letter'] for r in placements if r['status']=='imported'],'pending':[r['letter'] for r in placements if r['status']!='imported']}
if school_root:
    manifest['shared_hubs']=[{'id':'SCHOOL','root':school_root.name,'position':list(school_root.matrix_world.translation),'alphabet_index':None,'anchors':[{'name':o.name,'position':list(o.matrix_world.translation)} for o in school_anchors]}]
(w.BASE/'placement_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(w.BASE/'route_graph.json').write_text(json.dumps({'version':version_number,'graph_connected':True,'gameplay_navmesh_baked':False,'routes':w.ROUTE_RECORDS},ensure_ascii=False,indent=2)+'\n')
scene['build_status']=f"Environment {version}; {len(manifest['imported'])}/26 landmarks integrated; no gameplay collision/navmesh."
scene.camera=bpy.data.objects['ALPHA_Camera_World_Overview']
scene.render.filepath=str(w.BASE/f'alphabet_island_overview_{version}.png')
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        w.enum_set(area.spaces.active.region_3d,'view_perspective','CAMERA')
        area.spaces.active.overlay.show_overlays=False
        w.enum_set(area.spaces.active.shading,'type','MATERIAL')
blend=w.BASE/f'alphabet_island_layout_{version}.blend'
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
bpy.ops.object.select_all(action='DESELECT')
selected=[]
for o in scene.objects:
    if o.get('editor_only') or o.get('presentation_only') or o.get('site_clearance_hidden') or o.get('superseded_by_v03') or o.get('superseded_by_v04') or o.get('superseded_by_v05') or o.get('school_site_clearance') or o.type in ['LIGHT','CAMERA']:continue
    o.select_set(True);selected.append(o)
params=bpy.ops.export_scene.gltf.get_rna_type().properties
formats=[i.identifier for i in params['export_format'].enum_items]
if not formats:
    import io_scene_gltf2
    for cls in io_scene_gltf2.ExportGLTF2.__mro__:
        prop=getattr(cls,'__annotations__',{}).get('export_format')
        if prop:
            items=prop.keywords['items']
            formats=[i[0] for i in (items(None,bpy.context) if callable(items) else items)]
assert 'GLB' in formats
glb=w.BASE/f'alphabet_island_layout_{version}.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_extras=True,export_cameras=False,export_lights=False,export_yup=True)
validation={'scene':scene.name,'sockets':len(sockets),'memory_anchors':len(loci),'alphabet_route_and_home_connected':True,'bridge_count':sum(r['type']=='bridge' for r in w.ROUTE_RECORDS),'path_count':sum(r['type']=='path' for r in w.ROUTE_RECORDS),'objects':len(scene.objects),'exported_selection':len(selected),'finite_coordinates':finite,'source_checks':sources,'export_files':{'blend':str(blend),'glb':str(glb)},'checks_not_performed':['game engine import','collision generation','navmesh baking','interactive doors','runtime performance'],'visual_checks':['world overview','A/B/C village','home and lake','terrain road projection','boat pier alignment'],'retaining_edges':[o.name for o in scene.objects if 'Terrace_Retaining_Edge' in o.name]}
if scene.get('visual_checks_v03'):
    validation['visual_checks']=json.loads(scene['visual_checks_v03'])
if scene.get('visual_checks_v04'):
    validation['visual_checks']=json.loads(scene['visual_checks_v04'])
if scene.get('visual_checks_v05'):
    validation['visual_checks']=json.loads(scene['visual_checks_v05'])
if school_root:
    validation['school']={'connected_to_home':True,'position':list(school_root.matrix_world.translation),'reserved_asset_anchors':len(school_anchors)}
if version_number>=3:
    validation['superseded_geometry_excluded']=sum(bool(o.get('superseded_by_v03')) for o in scene.objects)
    validation['polish_collection']='ALPHA_Polish_v03'
(w.BASE/'scene_validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2)+'\n')
bpy.ops.object.select_all(action='DESELECT')
print({'saved_blend':str(blend),'exported_glb':str(glb),'scene_objects':len(scene.objects),'imported':manifest['imported'],'pending':manifest['pending']})
