"""Extend the existing living room into the approved rectangular household hub.

Open SOURCE in a separate Blender/MCP call, then run this script. File loading must
finish before operators use Blender's new window context. Original furniture,
learning anchors and six child rooms are retained.
This writes a new source version; install.py performs the separately verified replacement.
"""
import bpy, contextlib, hashlib, json, math, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'docs/verification/home-living-hub-20261113'
FOLDER = ROOT/'assets/blender/interiors/home'
SOURCE = FOLDER/'home_v07_own.blend'
BLEND = FOLDER/'home_v08_living_hub.blend'
GLB = FOLDER/'home_v08_living_hub.glb'
sys.path.insert(0, str(ROOT/'assets/blender/interiors/scripts'))
import modeling as m
import pipeline as p

SHELL = ('SG_COLLIDER_Pavilion_Edge', 'Pavilion_Rim', 'Left_Cutaway_Wall',
         'Back_Corner_Post', 'Rear_Wall', 'Rear_Crown', 'Rear_Baseboard',
         'Entry_Bollard', 'Entry_Threshold', 'SG_FLOOR_Main', 'SG_SPAWN', 'SG_EXIT')
DOORS = [('home_study',-1,4.5,'STUDY'), ('home_bedroom',-1,0,'BEDROOM'),
         ('home_bathroom',-1,-4.5,'BATHROOM'), ('home_kitchen',1,4.5,'KITCHEN'),
         ('home_dining',1,0,'DINING'), ('home_balcony',1,-4.5,'BALCONY')]

def fingerprint(o):
    h = hashlib.sha256()
    h.update(str((o.type, o.parent.name if o.parent else None, [list(v) for v in o.matrix_world], dict(o.items()))).encode())
    if o.type == 'MESH':
        for v in o.data.vertices: h.update(str(tuple(v.co)).encode())
        for f in o.data.polygons: h.update(str(tuple(f.vertices)).encode())
        for uv in o.data.uv_layers:
            for q in uv.data: h.update(str(tuple(q.uv)).encode())
        h.update(str([q.name if q else None for q in o.data.materials]).encode())
    return h.hexdigest()

def uv_project(o):
    uv = o.data.uv_layers.get('UVMap') or o.data.uv_layers.new(name='UVMap')
    o.data.update()
    for face in o.data.polygons:
        axis = max(range(3),key=lambda a:abs(face.normal[a]))
        axes = [a for a in range(3) if a != axis]
        for li in face.loop_indices:
            co = o.data.vertices[o.data.loops[li].vertex_index].co
            uv.data[li].uv = (co[axes[0]]*.38, co[axes[1]]*.38)

def box(name,pos,size,key='oak',bevel=.035):
    o=m.box('HUB_'+name,pos,size,key,bevel)
    uv_project(o)
    return o

def collision(name,pos,size):
    o=m.box('SG_COLLIDER_HUB_'+name,pos,size,'proxy',0)
    o.hide_render=True
    o.hide_set(True)
    return o

def side_piece(side,a,b):
    if b-a < .02: return
    x=side*10.05; y=(a+b)/2; length=b-a
    box(f'Wall_{side}_{a}',(x,y,1.85),(.30,length,3.7),'cream')
    box(f'Wainscot_{side}_{a}',(x-side*.17,y,.60),(.04,length,.95),'sage',.012)
    box(f'Rail_{side}_{a}',(x-side*.21,y,1.12),(.08,length,.09),'trim',.012)
    box(f'Skirting_{side}_{a}',(x-side*.19,y,.16),(.08,length,.18),'trim',.015)
    for j in range(max(1,int(length/.62))):
        yy=a+(j+.5)*length/max(1,int(length/.62))
        box(f'Batten_{side}_{a}_{j}',(x-side*.205,yy,.59),(.035,.045,.82),'trim',.008)
    collision(f'Wall_{side}_{a}',(x,y,1.85),(.30,length,3.7))

def plaque(name,side,y,label):
    # A label on both wall faces keeps the doorway identifiable in the isometric view.
    for face in [-1,1]:
        x=side*10.05+face*.205
        box(name+f'_Plaque_{face}',(x,y,3.26),(.07,1.50,.35),'teal',.07)
        data=bpy.data.curves.new(name+f'_Label_{face}','FONT')
        data.body=label; data.size=.19; data.extrude=.002
        data.align_x=next(i.identifier for i in data.bl_rna.properties['align_x'].enum_items if i.identifier=='CENTER')
        data.align_y=next(i.identifier for i in data.bl_rna.properties['align_y'].enum_items if i.identifier=='CENTER')
        ob=bpy.data.objects.new('HUB_'+name+f'_Label_{face}',data);m.link(ob)
        ob.location=(x+face*.042,y,3.26)
        ob.rotation_euler=(math.pi/2,0,face*math.pi/2)
        data.materials.append(m.M['trim'])

def door(room,side,y,label):
    x=side*10.05; width=2.2; h=2.85
    box(room+'_Header',(x,y,(h+3.7)/2),(.30,width,3.7-h),'cream')
    collision(room+'_Header',(x,y,(h+3.7)/2),(.30,width,3.7-h))
    # The door is seated within a continuous wall opening, with a visible deep reveal.
    for offset in [-width/2,width/2]:
        box(room+'_Jamb',(x,y+offset,h/2),(.46,.14,h),'oak')
    box(room+'_Lintel',(x,y,h),(.46,width+.2,.16),'oak')
    box(room+'_Threshold',(x,y,.035),(.52,width,.07),'oak',.012)
    leafx=x+side*.10
    box(room+'_Leaf',(leafx,y,1.40),(.12,2.04,2.76),'oak',.055)
    collision(room+'_ClosedLeaf',(leafx,y,1.40),(.12,2.04,2.76))
    for face in [-1,1]:
        panelx=leafx+face*.075
        if room == 'home_balcony':
            for dy in [-.49,.49]:
                for z in [.78,1.94]:
                    box(room+'_Glazing',(panelx,y+dy,z),(.025,.83,1.02),'glass',.02)
            box(room+'_Mullion',(panelx+face*.02,y,1.43),(.045,.07,2.62),'trim',.01)
            box(room+'_Crossbar',(panelx+face*.02,y,1.38),(.045,1.9,.07),'trim',.01)
        else:
            for z,height in [(.65,.85),(1.95,1.35)]:
                box(room+'_Inset',(panelx,y,z),(.025,1.68,height),'sand',.04)
                for dy in [-.87,.87]:
                    box(room+'_PanelEdge',(panelx+face*.02,y+dy,z),(.045,.045,height+.06),'oak',.01)
                for zz in [z-height/2,z+height/2]:
                    box(room+'_PanelRail',(panelx+face*.02,y,zz),(.045,1.77,.045),'oak',.01)
        box(room+'_Escutcheon',(panelx+face*.04,y-.72,1.29),(.06,.15,.29),'metal',.035)
        box(room+'_Handle',(panelx+face*.11,y-.63,1.30),(.12,.28,.055),'metal',.025)
    plaque(room,side,y,label)
    marker=m.empty('SG_DOOR_'+room.upper(),(side*8.55,y,.0),label)
    marker['destination']=room
    marker['portal_width_m']=2.2
    marker['wall_integrated']=True
    # The marker and the return point are inside the unobstructed perimeter lane.
    marker['return_x']=side*8.15
    marker['return_y']=y

def run():
    if Path(bpy.data.filepath).resolve() != SOURCE.resolve():
        raise RuntimeError('Open the protected source in Blender before building.')
    bpy.context.view_layer.update()
    before={o.name:fingerprint(o) for o in bpy.context.scene.objects if not o.name.startswith(SHELL)}
    m.COLLS={};m.PARENT=None;m.group('80_Living_Hub_Architecture')
    m.M.update({'cream':bpy.data.materials['MAT_cream'],'oak':bpy.data.materials['MAT_Living03_oak'],
        'floor':bpy.data.materials['MAT_Living03_floor_oak'],'trim':bpy.data.materials['MAT_Living03_wall_trim'],
        'sage':bpy.data.materials['CF08_sage'],'teal':bpy.data.materials['CF09_teal'],
        'sand':bpy.data.materials['MAT_sand'],'glass':bpy.data.materials['MAT_glass'],
        'metal':bpy.data.materials['OWN17_Hardware'],'cloth':bpy.data.materials['MAT_Living03_sage_cloth'],
        'proxy':bpy.data.materials['MAT_COLLISION_TRANSPARENT']})
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(SHELL): bpy.data.objects.remove(o,do_unlink=True)
    floor=box('Floor',(0,-.70,-.23),(20.4,15.6,.46),'floor',.04);floor.name='SG_FLOOR_Main'
    box('Rear_Wall',(0,7,1.9),(20.4,.28,3.8),'cream')
    box('Rear_Crown',(0,7,3.84),(20.5,.4,.16),'oak')
    box('Rear_Skirting',(0,6.82,.20),(20.2,.15,.32),'trim')
    collision('Rear_Wall',(0,7,1.9),(20.4,.28,3.8))
    for side in [-1,1]:
        for a,b in [(-8.5,-5.6),(-3.4,-1.1),(1.1,3.4),(5.6,6.92)]: side_piece(side,a,b)
        box('Side_Crown_'+str(side),(side*10.05,-.70,3.79),(.42,15.6,.15),'oak')
        for x in [side*6.0]:
            box('Front_Cutaway_'+str(side),(x,-8.43,.35),(8.2,.22,.70),'cream')
            box('Front_Cap_'+str(side),(x,-8.43,.72),(8.2,.32,.10),'oak')
            collision('Front_'+str(side),(x,-8.5,1.1),(8.2,.18,2.2))
    for row in DOORS: door(*row)
    box('Entry_Threshold',(0,-8.36,.045),(3.7,.60,.09),'oak',.02)
    box('Entry_Mat',(0,-7.64,.025),(2.85,1.10,.05),'cloth',.08)
    for x in [-1.88,1.88]: box('Entry_Jamb',(x,-8.42,.70),(.22,.34,1.4),'oak',.03)
    # Small entry furniture stays in the new front margin, away from the existing basket.
    box('Entry_Bench',(-5.5,-7.38,.50),(2.15,.70,.14),'oak',.06)
    box('Entry_Bench_Cushion',(-5.5,-7.38,.62),(2.04,.65,.14),'cloth',.08)
    for x in [-6.33,-4.67]: box('Entry_Bench_Leg',(x,-7.38,.23),(.13,.56,.46),'oak')
    box('Entry_Shoe_Shelf',(-5.5,-7.38,.15),(1.90,.55,.08),'oak')
    collision('Entry_Bench',(-5.5,-7.38,.35),(2.15,.70,.7))
    m.empty('SG_EXIT',(0,-7.63,0),'走出家门 · 回到小院')
    m.empty('SG_SPAWN',(0,-6.25,0),'入户客厅')
    bpy.context.view_layer.update()
    after={name:fingerprint(bpy.context.scene.objects[name]) for name in before}
    changed=[name for name in before if before[name]!=after[name]]
    if changed: raise RuntimeError('Existing furniture or anchor changed: '+str(changed))
    source=p.collect_source('home')
    source['required_nodes'] += ['SG_DOOR_'+q[0].upper() for q in DOORS]
    if source['missing_external_textures']: raise RuntimeError(source['missing_external_textures'])
    p.preview_setup(1440)
    bpy.context.scene.camera.location=(9,-26,25)
    p.point_camera(bpy.context.scene.camera,(0,-.5,.7))
    bpy.context.scene.camera.data.ortho_scale=26.6
    for o in bpy.context.scene.objects:
        if o.name.startswith('SG_COLLIDER_'): o.hide_render=True;o.hide_set(True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND),compress=True)
    with (OUT/'blender-export.log').open('w',encoding='utf-8') as log, contextlib.redirect_stdout(log):
        p.export_glb(GLB)
    stats=p.confirm_export(GLB,source)
    report={'source':str(SOURCE.relative_to(ROOT)),'blend':str(BLEND.relative_to(ROOT)),
        'glb':str(GLB.relative_to(ROOT)),'preserved_objects':len(before),'changed_protected_objects':changed,
        'doors':[{'room':r,'side':s,'y':y,'label':label,'width_m':2.2} for r,s,y,label in DOORS],
        'source_contract':source,'export':stats,'bounds':source['bounds']}
    p.write_json(OUT/'model-report.json',report)
    print('LIVING_HUB_EXPORTED',json.dumps({k:v for k,v in report.items() if k not in ['source_contract','doors']},ensure_ascii=False))
    bpy.ops.wm.open_mainfile(filepath=str(BLEND))

run()
