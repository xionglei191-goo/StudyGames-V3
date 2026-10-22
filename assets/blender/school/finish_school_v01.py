"""Final northern-campus road fitting and standalone asset export.
Execute fit_paths() before exporting. Uses live studygame_school/world modules.
"""
import bpy,json,math,heapq,contextlib,io
from mathutils import Vector,Matrix
import studygame_school as s
import studygame_world as w

def fit_paths():
    import studygame_polish as p
    plan=json.loads((s.BASE/'school_road_plan_v01.json').read_text())
    for name in ['ALPHA_V3_Connected_Rounded_Paths','ALPHA_V3_Path_Soft_Shoulder','ALPHA_School_North_School_From_L','ALPHA_School_North_School_From_M']:
        o=bpy.data.objects[name];o['superseded_by_v04']=True;o.hide_render=True;o.hide_set(True)
    p.TREE=s.TREE
    for name,key,style,offset in [('V4_Connected_Paths','road','dirt',.115),('V4_Path_Shoulders','shoulder','edge',.075)]:
        o=p.surface(name,plan[key],style,offset)
        for c in list(o.users_collection):c.objects.unlink(o)
        w.COLLS['School_Paths'].objects.link(o)
    pts=[v for r in s.RECORD['routes'] for v in w.sampled(r['control_points'],32)]
    removed=[]
    for trunk in list(w.COLLS['Forest'].objects):
        if '_Trunk' not in trunk.name or trunk.get('school_site_clearance'):continue
        if min(math.hypot(trunk.location.x-v.x,trunk.location.y-v.y) for v in pts)<1.85:
            prefix=trunk.name.rsplit('_Trunk',1)[0];removed.append(prefix)
            for c in [w.COLLS['Forest'],w.COLLS['Polish_v03']]:
                for o in c.objects:
                    if o.name.startswith(prefix+'_') or o.get('tree_source')==prefix:s.clear(o)
    graph={}
    for r in w.ROUTE_RECORDS:
        if r['type']!='path':continue
        samples=w.sampled(r['control_points'],32);length=sum((b-a).length for a,b in zip(samples,samples[1:]))
        a,b=r['from'],r['to'];graph.setdefault(a,[]).append((b,length));graph.setdefault(b,[]).append((a,length))
    q=[(0,'HOME',['HOME'])];visited=set()
    while q:
        dist,node,route=heapq.heappop(q)
        if node in visited:continue
        visited.add(node)
        if node=='SCHOOL':break
        for nxt,length in graph.get(node,[]):heapq.heappush(q,(dist+length,nxt,route+[nxt]))
    assert node=='SCHOOL'
    s.RECORD['planned_walk_from_home_plaza_m']=round(dist,1);s.RECORD['shortest_route_nodes']=route
    s.RECORD['route_clearance_trees']=removed
    (s.BASE/'school_asset_manifest_v01.json').write_text(json.dumps(s.RECORD,ensure_ascii=False,indent=2)+'\n')
    camera=bpy.data.objects['ALPHA_Camera_School_North'];camera.location=(16,28,41);w.aim(camera,(-4.8,53.8,13.9));camera.data.ortho_scale=33
    print({'planned_route_m':round(dist,1),'route':route,'trees_cleared_on_paths':removed})

def create_asset_scene():
    name='School_Campus_Asset_v01'
    if bpy.data.scenes.get(name):raise RuntimeError('Standalone scene exists; inspect it instead of creating another.')
    scene=bpy.data.scenes.new(name);bpy.context.window.scene=scene
    coll=bpy.data.collections.new('SCHOOL_ASSET');scene.collection.children.link(coll)
    source=[*w.COLLS['School_Building'].objects,*w.COLLS['School_Campus'].objects]
    objects={};matrices={}
    for old in source:
        new=old.copy();new.name=old.name.replace('ALPHA_','ASSET_',1);new.parent=None
        matrix=old.matrix_world.copy();matrix.translation-=s.ORIGIN
        coll.objects.link(new);new.matrix_world=matrix;new.hide_set(False)
        objects[old]=new;matrices[new]=matrix
    bpy.context.view_layer.update()
    for old,new in objects.items():
        if old.parent in objects:
            new.parent=objects[old.parent];new.matrix_parent_inverse=new.parent.matrix_world.inverted();new.matrix_world=matrices[new]
    bpy.context.view_layer.update()
    world=bpy.data.worlds.new('School_Studio_World');world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.82,.86,.9,1);bg.inputs['Strength'].default_value=.8;scene.world=world
    # Copy the established render engine, color management and soft studio lights.
    try:scene.render.engine=w.SCENE.render.engine
    except TypeError as e:raise RuntimeError(str(e))
    scene.render.resolution_x=1600;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.view_settings.view_transform=w.SCENE.view_settings.view_transform;scene.view_settings.exposure=0
    if hasattr(scene,'eevee'):scene.eevee.taa_render_samples=96
    for old in w.SCENE.objects:
        if old.type=='LIGHT':
            new=old.copy();new.data=old.data.copy();coll.objects.link(new);new.location=old.location-s.ORIGIN
            if new.data.type=='AREA':new.location=(-10,-12,22);new.data.energy=2000
    data=bpy.data.cameras.new('School_Asset_Camera');camera=bpy.data.objects.new('School_Asset_Camera',data);coll.objects.link(camera)
    w.enum_set(data,'type','ORTHO');data.ortho_scale=32;camera.location=(20,-29,23);w.aim(camera,(-4.7,-.4,3.4));scene.camera=camera
    # Neutral floor is presentation-only and does not go into either GLB.
    material=w.make_material('School_Studio_Floor',(.88,.88,.84),.9)
    data=bpy.data.meshes.new('School_Studio_Floor');data.from_pydata([(-80,-80,-.09),(80,-80,-.09),(80,80,-.09),(-80,80,-.09)],[],[(0,1,2,3)]);data.materials.append(material)
    floor=bpy.data.objects.new('School_Studio_Floor',data);coll.objects.link(floor);floor['presentation_only']=True
    scene.render.filepath=str(s.BASE/'school_campus_preview_v01.png');bpy.ops.render.render(write_still=True)
    formats=[i.identifier for i in bpy.ops.export_scene.gltf.get_rna_type().properties['export_format'].enum_items]
    if not formats:
        import io_scene_gltf2
        for cls in io_scene_gltf2.ExportGLTF2.__mro__:
            prop=getattr(cls,'__annotations__',{}).get('export_format')
            if prop:
                items=prop.keywords['items'];formats=[i[0] for i in (items(None,bpy.context) if callable(items) else items)]
    assert 'GLB' in formats
    for kind in ['building','campus']:
        bpy.ops.object.select_all(action='DESELECT')
        for old,new in objects.items():
            if kind=='campus' or old in list(w.COLLS['School_Building'].objects):new.select_set(True)
        with contextlib.redirect_stdout(io.StringIO()):
            bpy.ops.export_scene.gltf(filepath=str(s.BASE/('school_'+kind+'_v01.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_extras=True,export_cameras=False,export_lights=False)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.data.libraries.write(str(s.BASE/'school_campus_v01.blend'),{scene},compress=True)
    bpy.context.window.scene=w.SCENE;w.SCENE.camera=bpy.data.objects['ALPHA_Camera_World_Overview']
    print({'standalone_scene':scene.name,'files':['school_campus_preview_v01.png','school_building_v01.glb','school_campus_v01.glb','school_campus_v01.blend']})
