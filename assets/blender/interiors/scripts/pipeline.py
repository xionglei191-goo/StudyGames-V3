"""Save, render and export helpers. Existing .blend files remain the source of truth."""
import bpy, json, math, os, struct, hashlib
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[4]
OUT=ROOT/'assets/blender/interiors'
REQUIRED=['SG_SPAWN','SG_EXIT','SG_NPC_HOST']+[f'SG_MEMORY_{i:02}' for i in range(1,6)]
SCHOOL=['SG_DOOR_CLASSROOM','SG_DOOR_MUSIC_ROOM','SG_DOOR_ART_ROOM','SG_DOOR_SCIENCE_ROOM','SG_DOOR_CANTEEN','SG_DOOR_PLAYGROUND','SG_DOOR_FOOTBALL_FIELD']
HOME=['SG_BED','SG_WARDROBE','SG_DECOR_FLOWER_BOX','SG_DECOR_PICNIC','SG_DECOR_LAMP']
DECOR=['SG_DECOR_MODEL_FLOWER_BOX','SG_DECOR_MODEL_PICNIC','SG_DECOR_MODEL_LAMP']

def write_json(path,data):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    tmp=path.with_suffix(path.suffix+'.tmp')
    tmp.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    os.replace(tmp,path)

def point_camera(ob,target):ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()

def preview_setup(resolution=1000):
    from modeling import group, box, M, link
    sc=bpy.context.scene
    group('99_Preview_Only')
    bpy.ops.object.camera_add(location=(18,-24,25))
    camera=bpy.context.object;camera.name='PREVIEW_Camera';link(camera)
    camera.data.type='ORTHO';camera.data.ortho_scale=25.8 if sc.get('room_id')=='landmark_S' else 23.5;point_camera(camera,(0,0,.7));sc.camera=camera
    for name,p,power,size,color in [
        ('PREVIEW_Key',(-8,-10,16),1900,9,(1,.88,.71)),
        ('PREVIEW_Fill',(7,-2,12),1100,8,(.73,.86,1)),
        ('PREVIEW_Rim',(0,9,14),1800,7,(1,.88,.69)),
    ]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
        ob=bpy.data.objects.new(name,data);link(ob);ob.location=p;point_camera(ob,(0,0,0))
    data=bpy.data.lights.new('PREVIEW_Sun','SUN');data.energy=1.4;data.angle=math.radians(25)
    ob=bpy.data.objects.new('PREVIEW_Sun',data);link(ob);ob.rotation_euler=(.35,-.4,-.35)
    world=bpy.data.worlds.new('Warm_Studio');sc.world=world;world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.42,.47,.43,1);bg.inputs['Strength'].default_value=.45
    box('PREVIEW_Backdrop',(0,0,-.68),(200,200,.12),'cream',0)
    try:sc.render.engine='BLENDER_EEVEE'
    except TypeError:sc.render.engine='BLENDER_EEVEE_NEXT'
    sc.render.resolution_x=resolution;sc.render.resolution_y=round(resolution*.88);sc.render.resolution_percentage=100
    sc.render.image_settings.file_format='PNG';sc.render.film_transparent=False
    try:sc.eevee.taa_render_samples=64
    except AttributeError:pass
    sc.view_settings.view_transform='AgX'
    sc.render.image_settings.color_mode='RGB'
    sc.render.image_settings.color_depth='8'
    # Make a newly opened editable file immediately useful in the viewport.
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_perspective='CAMERA'
                area.spaces.active.shading.color_type='MATERIAL'

def world_bounds(ob):
    pts=[ob.matrix_world@Vector(p) for p in ob.bound_box]
    return [min(p[i] for p in pts) for i in range(3)]+[max(p[i] for p in pts) for i in range(3)]

def collect_source(room_id):
    bpy.context.view_layer.update()
    sc=bpy.context.scene
    expected=REQUIRED+(SCHOOL if room_id=='school' else HOME if room_id=='home' else [])
    missing=[n for n in expected if n not in sc.objects]
    if missing:raise ValueError(f'{room_id}: missing anchors {missing}')
    if room_id=='home' and any(n not in sc.objects for n in DECOR):raise ValueError('Missing home decoration roots')
    anchors=[];colliders=[];meshes=[];external=[]
    for ob in sc.objects:
        if ob.name in expected:
            p=ob.matrix_world.translation
            associated=ob.get('associated_prop')
            if associated and associated not in sc.objects:
                candidates=sorted(o.name for o in sc.objects if o.name.startswith(associated+'_') and not o.name.startswith('SG_'))
                associated=candidates[0] if candidates else associated
            if associated:ob['associated_prop']=associated
            anchors.append({'name':ob.name,'label':ob.get('label',''),'position_blender':[round(x,5) for x in p],
                            'position_godot':[round(p.x,5),round(p.z,5),round(-p.y,5)],'associated_prop':associated,
                            'memory_id':ob.get('memory_id',''),'activity':ob.get('activity','')})
        if ob.name.startswith('SG_COLLIDER_'):
            if ob.type!='MESH':raise ValueError('Collision marker is not mesh: '+ob.name)
            colliders.append({'name':ob.name,'aabb_blender':world_bounds(ob)})
        if ob.type=='MESH' and not ob.name.startswith('PREVIEW_'):meshes.append(ob)
    for im in bpy.data.images:
        if im.source=='FILE' and not im.packed_file and im.filepath:
            p=Path(bpy.path.abspath(im.filepath))
            if not p.exists():external.append(str(p))
    floors=[ob for ob in meshes if ob.name.startswith('SG_FLOOR_')]
    if not floors:raise ValueError('No exported floor mesh')
    b=world_bounds(bpy.data.objects.get('SG_FLOOR_Main') or floors[0])
    bounds=[b[0],-b[4],b[3]-b[0],b[4]-b[1]]
    return {'room_id':room_id,'anchors':anchors,'colliders':colliders,'bounds':bounds,
            'mesh_objects':len(meshes),'missing_external_textures':external,
            'floor_nodes':[ob.name for ob in floors], 'required_nodes':expected+(DECOR if room_id=='home' else [])}

def render_preview(output_path):
    output_path=Path(output_path);temporary=output_path.with_name('.preview.pending.png')
    bpy.context.scene.render.filepath=str(temporary)
    bpy.ops.render.render(write_still=True)
    os.replace(temporary,output_path)

def export_glb(output_path):
    # Convert only the in-memory copy after saving. Original editable fonts/curves
    # and all user edits stay intact in the .blend on disk.
    bpy.ops.object.select_all(action='DESELECT')
    convert=[o for o in bpy.context.scene.objects if o.type in ('FONT','CURVE','SURFACE') and not o.name.startswith('PREVIEW_')]
    if convert:
        for o in convert:o.select_set(True)
        bpy.context.view_layer.objects.active=convert[0]
        bpy.ops.object.convert(target='MESH')
    bpy.ops.object.select_all(action='DESELECT')
    for ob in bpy.context.scene.objects:
        if ob.type in ('MESH','EMPTY') and not ob.name.startswith('PREVIEW_'):
            ob.hide_set(False);ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(output_path),export_format='GLB',use_selection=True,
        use_visible=False,use_renderable=False,export_apply=True,export_yup=True,
        export_extras=True,export_cameras=False,export_lights=False,export_materials='EXPORT')

def parse_glb(path):
    raw=Path(path).read_bytes();magic,version,total=struct.unpack_from('<4sII',raw)
    if magic!=b'glTF' or version!=2 or total!=len(raw):raise ValueError('Invalid GLB header')
    length,kind=struct.unpack_from('<II',raw,12)
    if kind!=0x4E4F534A:raise ValueError('Missing GLB JSON')
    return json.loads(raw[20:20+length]),len(raw)

def confirm_export(glb,source):
    data,size=parse_glb(glb);nodes=data.get('nodes',[]);names={n.get('name'):n for n in nodes}
    missing=[n for n in source['required_nodes'] if n not in names]
    if missing:raise ValueError('GLB lost required nodes: '+str(missing))
    for n in nodes:
        if n.get('name','').startswith(('SG_COLLIDER_','SG_FLOOR_')) and 'mesh' not in n:
            raise ValueError('GLB collision/floor not mesh: '+n['name'])
    for im in data.get('images',[]):
        if 'uri' in im and not im['uri'].startswith('data:'):raise ValueError('External image in GLB')
    tris=0
    for n in nodes:
        if 'mesh' not in n:continue
        for p in data['meshes'][n['mesh']]['primitives']:
            if p.get('mode',4)==4:
                count=data['accessors'][p['indices']]['count'] if 'indices' in p else data['accessors'][p['attributes']['POSITION']]['count']
                tris+=count//3
    return {'glb_bytes':size,'glb_node_count':len(nodes),'triangles_instanced':tris,'embedded_images':len(data.get('images',[])),
            'missing_nodes':missing,'sha256':hashlib.sha256(Path(glb).read_bytes()).hexdigest()}

def manifest_entry(room_id,name,source,stats,existing=None):
    folder=OUT/room_id
    existing=existing or {}
    return {**existing,'room_id':room_id,'name':name,
            'blend':existing.get('blend',(folder/(room_id+'_v01.blend')).relative_to(ROOT).as_posix()),
            'glb':existing.get('glb',(folder/(room_id+'_v01.glb')).relative_to(ROOT).as_posix()),
            'preview':existing.get('preview',(folder/'preview.png').relative_to(ROOT).as_posix()),
            'anchors':source['anchors'],'bounds':[round(x,4) for x in source['bounds']],
            'triangles':stats['triangles_instanced'],'glb_sha256':stats['sha256']}

def update_manifest(entry):
    path=OUT/'interiors_manifest.json'
    data=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'schema_version':1,'rooms':[]}
    rooms={r['room_id']:r for r in data['rooms']};rooms[entry['room_id']]=entry
    order=['landmark_'+chr(i) for i in range(65,91)]+['school','classroom','music_room','art_room','science_room','canteen','playground','football_field','home']
    data['rooms']=[rooms[k] for k in order if k in rooms]+[rooms[k] for k in sorted(set(rooms)-set(order))]
    data['coordinate_system']='GLB/Godot Y up; bounds = xmin, zmin, width, depth; metres'
    data['source_contract']='Edit .blend, then export_existing.py; generator is opt-in only'
    write_json(path,data)

def finish_room(room_id,name,save_blend=True,render=True,existing=None):
    folder=OUT/room_id;folder.mkdir(parents=True,exist_ok=True)
    existing=existing or {}
    blend=ROOT/existing['blend'] if existing.get('blend') else folder/(room_id+'_v01.blend')
    glb=ROOT/existing['glb'] if existing.get('glb') else folder/(room_id+'_v01.glb')
    preview=ROOT/existing['preview'] if existing.get('preview') else folder/'preview.png'
    source=collect_source(room_id)
    if source['missing_external_textures']:raise ValueError(source['missing_external_textures'])
    bpy.context.scene['room_display_name']=name
    if save_blend:bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    if render:render_preview(preview)
    pending=glb.with_name('.'+glb.stem+'.pending.glb')
    export_glb(pending)
    stats=confirm_export(pending,source)
    os.replace(pending,glb)
    version=blend.stem.rsplit('_',1)[-1]
    validation=folder/(f'validation_{version}.json' if version.startswith('v') and version[1:].isdigit() and version!='v01' else 'validation.json')
    write_json(validation,{**source,**stats,'rendered':preview.exists(),
        'source_blend':blend.relative_to(ROOT).as_posix(),'source_blend_preserved':not save_blend})
    update_manifest(manifest_entry(room_id,name,source,stats,existing))
    print('ROOM_COMPLETED '+room_id+' '+json.dumps(stats),flush=True)

