"""Read-only Blender inventory and comparable source renders for cloud refinement."""
import bpy, json, sys, argparse
from pathlib import Path
from mathutils import Vector

parser=argparse.ArgumentParser()
parser.add_argument('--out',required=True)
parser.add_argument('--render',action='store_true')
parser.add_argument('--camera',default='')
parser.add_argument('--width',type=int,default=1200)
parser.add_argument('--glb',default='')
parser.add_argument('--island',action='store_true')
parser.add_argument('--samples',type=int,default=32)
parser.add_argument('--filename',default='before.png')
parser.add_argument('--fit',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
out=Path(args.out);out.mkdir(parents=True,exist_ok=True)
if args.glb:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(Path(args.glb).resolve()))
    scene=bpy.context.scene
    from math import radians
    if args.island:
        views=[('Overview',(145,-185,175),(0,0,5),180),('Neighborhood',(14,-42,29),(-5,-16,7),35),('School',(18,26,27),(0,53,12),43)]
    else:
        bpy.context.view_layer.update()
        floors=[o for o in scene.objects if o.name.startswith('SG_FLOOR_') and o.type=='MESH']
        pts=[o.matrix_world@Vector(p) for o in floors for p in o.bound_box]
        lo=Vector([min(v[i] for v in pts) for i in range(3)]);hi=Vector([max(v[i] for v in pts) for i in range(3)])
        center=(lo+hi)/2;center.z=1.0;span=max(hi.x-lo.x,hi.y-lo.y)
        views=[('Overview',center+Vector((.68,-1.0,.85))*span,center,span*1.24)]
    for name,pos,target,scale in views:
        data=bpy.data.cameras.new('REVIEW_'+name);cam=bpy.data.objects.new(data.name,data);scene.collection.objects.link(cam)
        cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=scale
    scene.camera=bpy.data.objects['REVIEW_Overview']
    data=bpy.data.lights.new('REVIEW_Sun','SUN');ob=bpy.data.objects.new(data.name,data);scene.collection.objects.link(ob);data.energy=2.0;data.angle=.2;ob.rotation_euler=(radians(27),radians(-24),radians(-32))
    world=bpy.data.worlds.new('REVIEW_Sky');scene.world=world;world.use_nodes=True
    bg=world.node_tree.nodes.get('Background');bg.inputs[0].default_value=(.55,.7,.86,1);bg.inputs[1].default_value=.55
    scene.view_settings.view_transform='AgX';scene.render.resolution_x=1440;scene.render.resolution_y=1000
    for o in scene.objects:
        if o.name.startswith(('SG_COLLIDER_','COL_')):o.hide_render=True
    if not args.island:
        bpy.context.view_layer.update();cam=scene.camera;inv=cam.matrix_world.inverted()
        pts=[inv@(o.matrix_world@Vector(p)) for o in scene.objects if o.type=='MESH' and not o.hide_render for p in o.bound_box]
        mn=Vector([min(v[i] for v in pts) for i in range(3)]);mx=Vector([max(v[i] for v in pts) for i in range(3)])
        cam.location+=cam.matrix_world.to_3x3()@Vector(((mn.x+mx.x)/2,(mn.y+mx.y)/2,0))
        cam.data.ortho_scale=max(mx.x-mn.x,(mx.y-mn.y)*1.44)*1.08
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'baseline_import.blend'),compress=True)
scene=bpy.context.scene
bpy.context.view_layer.update()
for root in [o for o in scene.objects if o.name.startswith('HOME_TASK_') and o.get('household_state')]:
    for ob in [root,*root.children_recursive]:ob.hide_render=root.get('household_state')!='before'
if args.fit:
    cam=scene.camera;inv=cam.matrix_world.inverted()
    pts=[inv@(o.matrix_world@Vector(p)) for o in scene.objects if o.type=='MESH' and not o.hide_render for p in o.bound_box]
    mn=Vector([min(v[i] for v in pts) for i in range(3)]);mx=Vector([max(v[i] for v in pts) for i in range(3)])
    cam.location+=cam.matrix_world.to_3x3()@Vector(((mn.x+mx.x)/2,(mn.y+mx.y)/2,0))
    cam.data.ortho_scale=max(mx.x-mn.x,(mx.y-mn.y)*1.44)*1.08
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'baseline_import.blend'),compress=True)
def bounds(o):
    pts=[o.matrix_world@Vector(p) for p in o.bound_box]
    return [[round(min(p[i] for p in pts),4) for i in range(3)],[round(max(p[i] for p in pts),4) for i in range(3)]]
objects=[]
for o in scene.objects:
    objects.append({'name':o.name,'type':o.type,'parent':o.parent.name if o.parent else None,
        'position':list(o.matrix_world.translation),'bounds':bounds(o) if o.type=='MESH' else None,
        'vertices':len(o.data.vertices) if o.type=='MESH' else 0,'hidden_render':o.hide_render,
        'materials':[s.material.name if s.material else None for s in o.material_slots],
        'props':{k:str(v) for k,v in o.items()}})
images=[{'name':i.name,'path':i.filepath,'packed':bool(i.packed_file),'size':list(i.size)} for i in bpy.data.images]
cameras=[{'name':o.name,'location':list(o.location),'rotation':list(o.rotation_euler),'type':o.data.type,'scale':o.data.ortho_scale,'lens':o.data.lens} for o in scene.objects if o.type=='CAMERA']
report={'source':bpy.data.filepath,'blender':bpy.app.version_string,'scene':scene.name,'active_camera':scene.camera.name if scene.camera else None,'render_engine':scene.render.engine,'resolution':[scene.render.resolution_x,scene.render.resolution_y],'objects':objects,'cameras':cameras,'images':images}
(out/'inventory.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print('INVENTORY',json.dumps({k:v for k,v in report.items() if k not in ['objects','images']}),flush=True)
print('COUNTS',len(objects),len(images),'packed',sum(i['packed'] for i in images),flush=True)
if args.render:
    if args.camera:scene.camera=bpy.data.objects[args.camera]
    ratio=scene.render.resolution_y/scene.render.resolution_x
    scene.render.resolution_x=args.width;scene.render.resolution_y=round(args.width*ratio);scene.render.resolution_percentage=100
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=args.samples;scene.cycles.use_denoising=False
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(out/args.filename)
    bpy.ops.render.render(write_still=True)
    print('RENDER_COMPLETE',scene.render.filepath,flush=True)
