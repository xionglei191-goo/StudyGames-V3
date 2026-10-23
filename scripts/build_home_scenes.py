"""Author the courtyard home and its rooms in Blender; preserve every old source.

Run: blender --background --python scripts/build_home_scenes.py -- [room_id]
All dimensions use metres, Blender Z up. Original modelling, no external assets.
"""
import json
import math
from pathlib import Path
import sys

import bpy

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'assets/blender/interiors/scripts'))
import modeling as m
import pipeline as p

DATA = json.loads((ROOT / 'game/data/home_hierarchy.json').read_text('utf-8'))
ROOMS = {r['room_id']: r for r in DATA['rooms']}
ANCHORS = {
    'home_estate': [(-10, -10.2), (8, -10.2), (-3.5, -5.2), (2, -10.2), (11.5, -10.3)],
    'home_bedroom': [(-4.6, 1.2), (-1.6, 3.4), (4.8, 2.8), (-3.1, -3.3), (3.0, -3.3)],
    'home_kitchen': [(-5.0, 2.5), (-1.4, 3.0), (4.5, 2.6), (2.0, -.5), (-3.2, -3.8)],
    'home_dining': [(-4.8, 2.6), (3.2, -4.8), (0, -1.1), (-3.2, -4.3), (4.8, 3.0)],
    'home_bathroom': [(-4.8, 2.1), (0, 3.0), (3.3, 2.1), (-3.4, -3.0), (3.4, -3.0)],
    'home_study': [(-4.8, 2.5), (0, 3.6), (4.8, 2.4), (-3.0, -3.9), (3.3, -3.0)],
    'home_balcony': [(-4.8, 2.3), (4.8, 2.8), (0, 4.5), (-3.3, -4.2), (3.2, -3.8)],
}
DOORS = {
    'home_study': (-10.5, 2.6), 'home_bedroom': (-3.5, 2.6),
    'home_bathroom': (3.5, 2.6), 'home_balcony': (10.5, 2.6),
    'home': (-10.0, 1.0), 'home_dining': (2.0, 1.0), 'home_kitchen': (9.5, 1.0),
}


def chair(name, x, y, color='teal', s=1):
    m.box(name + '_Seat', (x, y, .58*s), (.85*s, .85*s, .20*s), color, .10*s)
    m.box(name + '_Back', (x, y+.34*s, 1.10*s), (.85*s, .17*s, .95*s), color, .10*s)
    for dx in [-.3, .3]:
        for dy in [-.3, .3]:
            m.beam(name + '_Leg', (x+dx*s, y+dy*s, .05), (x+dx*.8*s, y+dy*.8*s, .55*s), .055*s, 'oak')


def armchair(name, x, y, color='rose', s=1):
    m.box(name+'_Base', (x, y, .40*s), (1.6*s, 1.45*s, .65*s), color, .2*s)
    m.box(name+'_Back', (x, y+.55*s, 1.1*s), (1.6*s, .35*s, 1.0*s), color, .16*s)
    for dx in [-.65, .65]:
        m.box(name+'_Arm', (x+dx*s, y, .8*s), (.3*s, 1.5*s, .75*s), color, .13*s)
    m.pillow(name+'_Cushion', x, y+.15*s, .9*s, 'yellow', (.65*s, .55*s, .2*s))
    m.collider(name, (x, y, .7*s), (1.7*s, 1.6*s, 1.4*s))


def sofa(name, x, y, s=1):
    m.box(name+'_Base', (x, y, .45*s), (3.3*s, 1.3*s, .65*s), 'rose', .18*s)
    m.box(name+'_Back', (x, y+.5*s, 1.0*s), (3.3*s, .32*s, .9*s), 'rose', .15*s)
    for dx in [-1.5, 1.5]:
        m.box(name+'_Arm', (x+dx*s, y, .8*s), (.32*s, 1.3*s, .72*s), 'rose', .13*s)
    for dx in [-.85, .85]:
        m.pillow(name+'_Pillow', x+dx*s, y+.1*s, .87*s, 'yellow', (.7*s, .5*s, .22*s))
    m.collider(name, (x, y, .7*s), (3.4*s, 1.4*s, 1.4*s))


def bed(name, x, y, s=1, quilt=True):
    m.box(name+'_Frame', (x, y, .36*s), (2.7*s, 3.8*s, .55*s), 'oak', .1*s)
    m.box(name+'_Mattress', (x, y, .73*s), (2.56*s, 3.6*s, .42*s), 'ivory', .18*s)
    m.box(name+'_Headboard', (x, y+1.9*s, 1.1*s), (2.9*s, .22*s, 1.8*s), 'mint', .10*s)
    if quilt:
        m.box(name+'_Quilt', (x, y-.4*s, .99*s), (2.5*s, 2.4*s, .18*s), 'rose', .12*s)
        m.pillow(name+'_Pillow', x, y+1.08*s, 1.06*s, 'white', (1.6*s, .65*s, .22*s))
    m.collider(name, (x, y, .65*s), (2.8*s, 4.0*s, 1.3*s))


def cupboard(name, x, y, w=2.4, h=2.6, color='teal'):
    m.box(name+'_Case', (x, y, h/2), (w, 1.05, h), color, .12)
    for dx in [-w/4, w/4]:
        m.box(name+'_Panel', (x+dx, y-.56, h*.52), (w*.43, .10, h*.88), 'mint', .05)
        m.ball(name+'_Knob', (x+dx*.25, y-.65, h*.5), (.06,)*3, 'gold')
    m.collider(name, (x, y, h/2), (w+.1, 1.2, h))


def picture(name, x, y, z=1.4, w=.8, h=.65):
    m.box(name+'_Frame', (x, y, z), (w, .12, h), 'oak', .04)
    m.box(name+'_Paper', (x, y-.075, z), (w-.12, .025, h-.12), 'paper', .01)
    # Abstract, original family-photo silhouettes rather than invented textbook identities.
    for k, dx in enumerate([-.21, 0, .21]):
        m.ball(name+'_PortraitHead', (x+dx*w, y-.105, z+.08*h), (.085*w, .025, .09*h), 'clay', 12, 8)
        m.box(name+'_PortraitBody', (x+dx*w, y-.106, z-.12*h), (.14*w, .025, .24*h), ['teal','rose','yellow'][k], .025)


def faucet_water(name, x, y, z=1.40):
    m.cyl(name, (x, y, z), .035, .43, 'water', 10)


def task_root(state):
    m.group('60_Interactive_Household_Props')
    root = m.empty('HOME_TASK_'+state.upper(), (0, 0, 0))
    root['household_state'] = state
    m.PARENT = root
    return root


def end_task(root, hidden=False):
    m.PARENT = None
    if hidden:
        for ob in root.children_recursive:
            ob.hide_render = True
    m.group('40_Furniture')


def room_base(rid, wall='cream', floor='lightwood', outdoor=False):
    m.setup(rid)
    m.room_shell(16, 14, wall, floor, 'garden' if outdoor else 'room')
    m.group('20_Windows_and_Trim')
    if not outdoor:
        m.window('Rear_Window_Left', -4.8, 6.74, 2.35, 2.6, 1.6)
        m.window('Rear_Window_Right', 4.8, 6.74, 2.35, 2.6, 1.6)
    m.title_banner(ROOMS[rid]['english_word'].upper(), 'A LITTLE MOMENT AT HOME', y=6.73)
    m.group('40_Furniture')


def add_anchors(rid):
    points = ANCHORS[rid]
    for i, (xy, anchor) in enumerate(zip(points, ROOMS[rid]['anchors']), 1):
        ob = m.anchor(f'SG_MEMORY_{i:02}', xy, anchor['label'])
        ob['memory_id'] = anchor['id']
        ob['activity'] = anchor['activity']
    m.anchor('SG_SPAWN', (0, -13.4) if rid == 'home_estate' else (0, -5.5), '进入家园')
    m.anchor('SG_EXIT', (0, -14.5) if rid == 'home_estate' else (0, -6.4), '返回上一层')
    m.anchor('SG_NPC_HOST', (-2.0, -10.0) if rid == 'home_estate' else (-1.8, -3.0), '家人或朋友停留位置')
    if rid == 'home_bedroom':
        m.anchor('SG_BED', points[0], '休息床边')
        m.anchor('SG_WARDROBE', points[2], '选择今日穿搭')


def make_bedroom():
    rid = 'home_bedroom'; room_base(rid, wall='cream')
    m.rug('Bedside_Rug', (-3.8, .7), (4.7, 1.8), 'mint')
    bed('Bedroom_Bed', -4.6, 3.8, quilt=False)
    z = m.table('Bedside_Table', -1.6, 5.0, 1.5, 1.0, .9)
    m.clock_face('Alarm_Clock', -1.6, 5.02, 1.7)
    cupboard('Clothes_Wardrobe', 4.8, 5, 2.8, 2.9)
    m.box('Full_Length_Mirror_Frame', (2.6, 5.85, 1.5), (1.0, .16, 2.6), 'oak')
    m.box('Full_Length_Mirror', (2.6, 5.75, 1.5), (.80, .04, 2.4), 'glass')
    m.bench('Bag_Bench', -5, -4.3, 2.2, 'oak')
    m.box('Schoolbag', (-5, -4.2, 1.08), (.75, .35, .95), 'yellow', .14)
    m.ring('Schoolbag_Handle', (-5, -4.2, 1.65), .2, .04, 'wood', (math.pi/2, 0, 0))
    armchair('Bedtime_Chair', 4.8, -3.7, 'mint')
    m.table('Reading_Side_Table', 6.5, -3.2, .8, .8, .85)
    m.lantern('Reading_Light', 6.5, -3.2, 1.4, 'yellow', .25)
    for state in ['before', 'middle', 'after']:
        root = task_root(state)
        ob = m.box('Quilt_'+state, (-4.6, 3.3, 1.0), (2.5, 2.5 if state=='after' else 1.9, .18), 'rose', .12)
        ob.rotation_euler.z = .22 if state == 'before' else 0
        m.pillow('Pillow_'+state, -4.6 if state=='after' else -4.1, 4.9, 1.1, 'white', (1.6, .65, .22))
        if state == 'after':
            m.box('Quilt_Fold_Edge', (-4.6, 4.35, 1.11), (2.5, .25, .08), 'pink')
        end_task(root, state != 'before')


def make_kitchen():
    rid='home_kitchen'; room_base(rid, wall='ivory', floor='cream')
    m.grid_tiles('Kitchen_Tiles', 0, 0, 15.5, 13.4, 'ivory', 'cream', 1.0)
    cupboard('Fridge', -5.4, 5.1, 2.2, 3.0, 'white')
    m.sink('Vegetable_Sink', -1.4, 5.1)
    m.table('Stove_Cabinet', 4.5, 5.1, 2.7, 1.35, 1.05, 'mint', True)
    for x in [3.8, 5.2]:
        m.ring('Hob_Ring', (x, 5.1, 1.18), .30, .045, 'metal')
    m.cyl('Soup_Pot', (4.0, 5.1, 1.5), .46, .55, 'teal')
    m.cyl('Soup_Pot_Lid', (4.0, 5.1, 1.82), .48, .08, 'metal')
    m.ball('Soup_Pot_Knob', (4.0, 5.1, 1.93), (.09, .09, .08), 'wood')
    m.box('Cooker_Hood', (4.5, 6.22, 2.85), (3.0, .75, .42), 'ivory')
    m.table('Preparation_Island', 2.0, -2.7, 3.6, 1.6, 1.05, 'lightwood', True)
    m.box('Chopping_Board', (2.0, -2.7, 1.18), (1.4, .8, .08), 'oak')
    m.basket('Fresh_Fruit', 3.0, -2.7, 1.15)
    m.shelf('Dish_Rack', -5.0, -4.5, 2.6, 3, 'jars', 2.5)
    m.box('Dry_Goods_Wall_Shelf',(.3,6.45,1.68),(2.7,.72,.13),'oak')
    for x in [-.4, .3, 1.0]: m.jar('Dry_Goods', x, 6.45, 1.75, .23, 'paper')
    m.plant('Kitchen_Herb', -6.7, -2.8, 0, False, .75)
    for state in ['before','middle','after']:
        root=task_root(state)
        x = -1.4 if state!='after' else -.5
        for dx,dy in [(-.3,0),(.2,.2),(.3,-.2)]:
            m.ball('Vegetable_'+state, (x+dx,5.1+dy,1.35), (.26,.35,.12), 'leaflight')
        if state=='middle': faucet_water('Running_Water',-1.4,5.1)
        if state=='after': m.basket('Washed_Basket', -.5,5.1,1.15,False)
        end_task(root,state!='before')


def make_dining():
    rid='home_dining';room_base(rid)
    m.rug('Dining_Rug',(0,1.6),(5.8,5.2),'mint')
    m.table('Family_Table',0,1.7,3.6,2.3,1.05,'lightwood')
    for x in [-1.1,1.1]:
        chair('Dining_Chair',x,3.4,'teal')
        chair('Dining_Chair',x,-.05,'teal')
    m.table('Breakfast_Cabinet',-5,4.7,2.6,1.2,1.1,'teal',True)
    m.clock_face('Breakfast_Clock',-5,6.5,2.8)
    for x in [-5.6,-4.7]: m.jar('Breakfast_Cup',x,4.7,1.22,.17,'ivory')
    m.table('Fruit_Side_Table',5,-4.8,2.0,1.2,.95)
    m.basket('Shared_Fruit',5,-4.8,1.06)
    m.table('Birthday_Table',-5,-4.3,2.3,1.4,.92)
    m.cake('Birthday_Cake',-5,-4.3,1.03,.8)
    picture('Birthday_Card',-5.75,-4.2,1.37,.45,.5)
    m.shelf('Festival_Cabinet',5,5.5,2.6,2,'jars',1.9)
    m.lantern('Family_Lantern',5,5.55,2.8,'red',.40)
    for state in ['before','middle','after']:
        root=task_root(state)
        for x in [-1.05,1.05]:
            for y in [1.0,2.4]:
                if state!='before': m.box('Place_Mat',(x,y,1.16),(1.05,.70,.025),'rose',.03)
                if state=='after':
                    m.cyl('Dinner_Plate',(x,y,1.2),.32,.045,'white',32)
                    m.jar('Dinner_Cup',x+.38,y+.12,1.18,.12,'teal')
        if state=='before':m.cyl('Stacked_Plates',(0,1.7,1.25),.35,.18,'ivory')
        end_task(root,state!='before')


def make_bathroom():
    rid='home_bathroom';room_base(rid,wall='mint',floor='ivory')
    m.grid_tiles('Bathroom_Tiles',0,0,15.5,13.4,'ivory','glass',.95)
    m.table('Vanity',-4.8,4.2,2.5,1.15,1.0,'cream',True)
    m.box('Vanity_Mirror_Frame',(-4.8,5.1,2.15),(2.15,.15,1.6),'oak')
    m.box('Vanity_Mirror',(-4.8,5.0,2.15),(1.95,.035,1.4),'glass')
    m.cyl('Toothbrush_Cup',(-4.8,4.2,1.3),.18,.3,'white')
    for x,color in [(-4.86,'rose'),(-4.72,'blue')]:
        m.beam('Toothbrush_Handle',(x,4.2,1.3),(x,4.2,1.9),.025,color)
        m.box('Toothbrush_Bristles',(x,4.17,1.86),(.08,.06,.20),'white',.02)
    m.sink('Hand_Wash_Sink',0,5.1)
    m.jar('Soap_Pump',.85,5.05,1.22,.16,'rose')
    m.box('Bathtub_Base',(4.8,4.7,.4),(2.7,3.7,.8),'white',.32)
    m.box('Bathtub_Interior',(4.8,4.7,.83),(2.2,3.2,.08),'glass',.28)
    m.collider('Bathtub',(4.8,4.7,.55),(2.8,3.8,1.1))
    m.beam('Shower_Riser',(6.2,5.8,.3),(6.2,5.8,3.0),.055,'metal')
    m.beam('Shower_Arm',(6.2,5.8,3.0),(5.5,5.8,3.0),.055,'metal')
    m.cyl('Shower_Head',(5.5,5.8,2.95),.28,.10,'metal')
    m.shelf('Towel_Cabinet',-5.2,-4.2,2.4,3,'',2.3)
    for z in [.5,1.2,1.9]:
        for x in [-5.65,-4.95]:m.box('Folded_Towel',(x,-4.2,z),(.6,.5,.22),'rose',.06)
    m.cyl('Toilet_Pedestal',(5.2,-4.0,.40),.40,.8,'white')
    m.ball('Toilet_Bowl',(5.2,-4.05,.72),(.62,.8,.32),'white')
    m.box('Toilet_Tank',(5.2,-3.4,1.1),(1.15,.45,1.1),'white',.15)
    m.collider('Toilet',(5.2,-4,.75),(1.4,1.8,1.5))
    m.box('Toilet_Privacy_Screen',(6.4,-3.7,1.0),(.12,2.5,2.0),'mint')
    for state in ['before','middle','after']:
        root=task_root(state)
        if state=='middle':
            faucet_water('Tap_Stream',0,5.12)
            for dx in [-.25,0,.25]:m.ball('Soap_Bubble',(dx,5.1,1.35),(.12,)*3,'white',12,8)
        else:
            m.box('Tap_Closed_Lever',(0,5.55,1.45),(.28,.08,.06),'gold')
            if state=='after':m.box('Clean_Hand_Towel',(.80,5.0,1.25),(.4,.4,.07),'white',.04)
        end_task(root,state!='before')


def make_study():
    rid='home_study';room_base(rid,wall='ivory')
    m.table('Computer_Desk',-4.8,4.6,3.0,1.4,1.0)
    m.box('Monitor_Stand',(-4.8,4.6,1.35),(.12,.15,.55),'metal')
    m.box('Monitor_Frame',(-4.8,4.65,1.90),(1.5,.18,1.05),'teal',.08)
    m.box('Monitor_Screen',(-4.8,4.54,1.90),(1.28,.03,.82),'glass')
    m.box('Keyboard',(-4.8,4.10,1.14),(1.1,.4,.06),'ivory')
    chair('Desk_Chair',-4.8,3.4,'mint')
    m.shelf('Reading_Bookcase',0,5.6,3.2,3,'books',2.9)
    m.rug('Reading_Rug',(4.8,4.4),(3.8,3.3),'rose')
    armchair('Reading_Armchair',4.8,4.3,'teal')
    m.table('Pencil_Desk',-5.1,-4.1,2.3,1.4,1.0)
    m.box('Pencil_Case',(-5.1,-4.1,1.2),(.65,.25,.15),'yellow',.07)
    m.table('Card_Making_Desk',5,-4.0,2.6,1.5,1.0)
    m.box('Open_Card',(5,-4,1.15),(1.0,.75,.035),'paper')
    for i,color in enumerate(['rose','blue','yellow','mint']):m.beam('Crayon',(4.3+i*.2,-4.5,1.18),(4.3+i*.2,-4.15,1.18),.035,color)
    m.plant('Reading_Plant',6.7,5.5,0,False,.85)
    for state in ['before','middle','after']:
        root=task_root(state)
        for i,color in enumerate(['rose','blue','yellow']):
            if state=='after':
                m.box('Returned_Book',(1.0+i*.19,5.50,.45),(.15,.38,.45+i*.06),color,.02)
            else:
                ob=m.box('Gathered_Book',(1.4+.25*i,4.65 if state=='before' else 5.1,.15+i*.12),(.65,.45,.1),color,.02)
                ob.rotation_euler.z=.30*i if state=='before' else 0
        end_task(root,state!='before')


def laundry_frame(name,x,y):
    for dx in [-1.25,1.25]:
        m.beam(name+'_Pole',(x+dx,y,0),(x+dx,y,2.4),.065,'oak')
        m.beam(name+'_Foot',(x+dx,y-.5,.08),(x+dx,y+.5,.08),.06,'oak')
    m.beam(name+'_Rail',(x-1.35,y,2.4),(x+1.35,y,2.4),.06,'oak')
    m.collider(name,(x,y,1.2),(2.9,.7,2.4))


def sock(name,x,y,z,color='rose'):
    m.box(name+'_Leg',(x,y,z),(.22,.06,.5),color,.03)
    m.box(name+'_Foot',(x+.06,y,z-.23),(.35,.06,.16),color,.04)


def make_balcony():
    rid='home_balcony';room_base(rid,floor='sand',outdoor=True)
    for x in [-6,0,6]:m.window('Sunroom_Window',x,6.8,2.1,3.2,2.0)
    laundry_frame('Drying_Rack',-4.8,4.4)
    m.box('Washing_Machine',(-6.1,1.2,.65),(1.5,1.3,1.3),'white',.14)
    ob=m.cyl('Washer_Door',(-6.1,.5,.7),.44,.08,'glass',32);ob.rotation_euler.x=math.pi/2
    m.collider('Washer',(-6.1,1.2,.65),(1.6,1.4,1.3))
    m.garden_box('Balcony_Plants',4.8,5.0,3.6,1.2)
    m.table('Window_Cleaning_Stand',0,5.7,1.4,.65,.75)
    m.jar('Cleaning_Bottle',0,5.7,.85,.18,'blue')
    m.beam('Broom_Handle',(-5.3,-4.3,.3),(-5.3,-4.1,2.15),.045,'oak')
    m.box('Broom_Brush',(-5.3,-4.3,.25),(.7,.3,.35),'sand')
    m.box('Dustpan',(-4.6,-4.3,.10),(.6,.6,.18),'teal')
    m.sink('Laundry_Sink',5,-4.1)
    for state in ['before','middle','after']:
        root=task_root(state)
        m.basket('Laundry_Basket',-4.8,3.7,0,False)
        for i in range(4):
            if state=='after' or (state=='middle' and i<2):
                sock('Hanging_Sock',-5.65+i*.55,4.4,2.07,['rose','yellow'][i//2])
                m.box('Clothes_Peg',(-5.65+i*.55,4.4,2.39),(.08,.08,.15),'oak',.015)
            else:m.box('Clean_Laundry',(-5.0+i*.13,3.7,.65+i*.05),(.35,.25,.09),['rose','yellow'][i//2],.04)
        end_task(root,state!='before')


def make_living():
    # Derive from the user's current source, preserving its stable five anchors.
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/blender/interiors/home/home_v01.blend'))
    m.M={key:bpy.data.materials.get('MAT_'+key) for key in m.PALETTE}
    for key in [k for k,v in m.M.items() if v is None]:
        mat=bpy.data.materials.new('MAT_'+key);mat.use_nodes=True
        bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        bsdf.inputs['Base Color'].default_value=(*m.PALETTE[key],1)
        bsdf.inputs['Roughness'].default_value=.68
        m.M[key]=mat
    m.M['proxy']=bpy.data.materials.get('MAT_COLLISION_TRANSPARENT')
    m.COLLS={c.name:c for c in bpy.context.scene.collection.children};m.PARENT=None;m.SPHERES={}
    m.COLLIDERS=[];m.ANCHORS=[]
    for ob in list(bpy.context.scene.objects):
        if ('bed' in ob.name.lower() and ob.name!='SG_BED') or ob.name.startswith('HOME_TASK_'):
            bpy.data.objects.remove(ob,do_unlink=True)
    m.group('40_Living_Room_Refinement')
    armchair('Window_Reading_Chair',5,4.8,'mint')
    m.table('Family_Album_Stand',3.45,5.6,1.2,.8,.9)
    picture('Family_Photo',3.45,5.6,1.4,1.0,.72)
    picture('Wall_Family_Picture',1.9,6.65,2.2,1.3,1.0)
    m.rug('Reading_Nook_Rug',(5,4.8),(3.5,3.7),'cream')
    for i,anchor in enumerate(ROOMS['home']['anchors'],1):
        ob=bpy.data.objects.get(f'SG_MEMORY_{i:02}')
        ob['label']=anchor['label'];ob['activity']=anchor['activity']
    title=bpy.data.objects.get('Shop_Title')
    if title and title.type=='FONT':title.data.body='OUR LIVING ROOM'
    for state in ['before','middle','after']:
        root=task_root(state)
        if state!='before':m.box('Welcome_Runner',(0,1.7,1.03),(1.8,.9,.025),'mint')
        if state=='after':
            m.cyl('Welcome_Fruit_Plate',(0,1.7,1.09),.35,.04,'white')
            for x in [-.15,.15]:m.apple('Welcome_Apple',x,1.7,1.23,.13)
            for x in [-.65,.65]:m.jar('Welcome_Cup',x,1.7,1.06,.12,'teal')
        if state=='before':m.box('Folded_Table_Runner',(.8,1.7,1.06),(.5,.4,.12),'mint')
        end_task(root,state!='before')
    bpy.context.scene['room_display_name']=ROOMS['home']['name']


def mini_room(rid,x,y,w,d,color,front):
    m.group('10_House_'+rid)
    m.box(rid+'_Floor',(x,y,.077),(w,d,.035),color,.03)
    if front:
        m.box(rid+'_Rear_Wall',(x,y+d/2,1.25),(w,.18,2.5),'cream')
        m.window(rid+'_Window',x,y+d/2-.13,1.75,2.6,1.2)
    else:
        for dx in [-1,1]:
            m.box(rid+'_Door_Wall',(x+dx*(w+2.4)/4,y+d/2,1.25),((w-2.4)/2,.18,2.5),'cream')
    m.box(rid+'_Cutaway_Left',(x-w/2,y,.55),(.16,d,1.1),'cream')
    m.box(rid+'_Rear_Trim',(x,y+d/2,2.55),(w+.15,.24,.14),'oak')
    # The L2 room is an overview footprint; its accessible threshold loads the L3 room.
    m.collider(rid+'_Overview_Footprint',(x,y,1.0),(w-.05,d-.05,2.0))
    door_y=y-d/2 if front else y+d/2
    for dx in [-1.15,1.15]:
        m.box(rid+'_Door_Post',(x+dx,door_y,1.3),(.16,.22,2.6),'oak')
    m.box(rid+'_Door_Header',(x,door_y,2.65),(2.46,.24,.23),'oak')
    m.box(rid+'_Door_Nameplate',(x,door_y-.15,2.72),(2.1,.08,.35),'ivory')
    m.text(rid+'_Door_Title',ROOMS[rid]['english_word'].upper(),(x,door_y-.20,2.72),.16,'teal')
    m.rug(rid+'_Door_Mat',(x,door_y-.25 if front else door_y+.25),(2.0,.7),'teal')
    m.text(rid+'_Floor_Label',ROOMS[rid]['english_word'].upper(),(x,y-d*.32,.11),.38,'teal','up')
    if rid=='home_bedroom':bed('Overview_Bed',x,y+.4,.68)
    elif rid=='home':
        sofa('Overview_Sofa',x,y+.5,.70);m.table('Overview_Coffee_Table',x,y-1.0,1.7,.9,.60)
    elif rid=='home_bathroom':
        m.box('Overview_Tub',(x+.8,y+.2,.45),(1.5,2.6,.8),'white',.2)
        m.box('Overview_Tub_Inside',(x+.8,y+.2,.88),(1.15,2.25,.06),'glass',.18)
        m.table('Overview_Basin',x-1.6,y+.8,1.2,.8,.8,'teal',True)
    elif rid=='home_study':
        m.table('Overview_Desk',x,y+.7,2.6,1.0,.85);m.shelf('Overview_Books',x+1.6,y+1.8,1.2,2,'books',1.8)
        m.box('Overview_Computer',(x,y+.7,1.3),(1.1,.12,.7),'teal')
    elif rid=='home_balcony':
        m.garden_box('Overview_Planter',x+1.0,y+.6,2.0,.8);laundry_frame('Overview_Laundry',x-1.2,y+.7)
    elif rid=='home_kitchen':
        m.sink('Overview_Kitchen_Sink',x-1.4,y+.9);m.table('Overview_Stove',x+1.3,y+.9,2.0,1.0,.95,'mint',True)
        m.cyl('Overview_Pot',(x+1.3,y+.9,1.24),.35,.4,'teal')
    elif rid=='home_dining':
        m.table('Overview_Dining_Table',x,y,2.5,1.7,.9)
        for dx in [-.8,.8]:
            for dy in [-1.1,1.1]:chair('Overview_Chair',x+dx,y+dy,'mint',.65)


def make_estate():
    rid='home_estate';m.setup(rid);m.group('00_Architecture')
    m.floor(34,32,'grass',False)
    m.box('House_Foundation',(0,1.1,-.01),(30,18,.09),'stone')
    m.box('House_Hall_Floor',(0,2.1,.035),(29.5,4.2,.06),'lightwood')
    m.box('House_Entrance_Floor',(-3.5,-3.9,.035),(4.7,8.0,.06),'lightwood')
    m.box('House_Rear_Wall',(0,10.2,1.55),(30,.30,3.1),'cream')
    m.box('Continuous_Roof_Eave',(0,10.2,3.3),(30.5,1.6,.32),'teal')
    m.mesh('Rear_Pitched_Roof',[(-15.3,8.5,3.3),(15.3,8.5,3.3),(15.3,10.2,4.5),(-15.3,10.2,4.5),(-15.3,11.6,3.3),(15.3,11.6,3.3)],[(0,1,2,3),(3,2,5,4)],'teal')
    m.box('Chimney',(12.8,10.2,4.8),(.75,.8,1.5),'clay')
    m.box('Chimney_Cap',(12.8,10.2,5.55),(.95,1.0,.18),'ivory')
    m.box('House_Left_Facade',(-15,1.1,.70),(.28,18,1.4),'cream')
    m.box('House_Right_Facade',(15,1.1,.70),(.28,18,1.4),'cream')
    m.box('House_Porch',(-3.5,-8.2,.04),(6.2,1.3,.08),'sand')
    for x in [-6.3,-.7]:
        m.box('Porch_Post',(x,-8.2,1.35),(.20,.20,2.7),'oak')
    m.box('Porch_Lintel',(-3.5,-8.2,2.75),(6.0,.25,.25),'oak')
    m.text('Porch_Welcome','WELCOME HOME',(-3.5,-8.38,2.75),.26,'teal')
    for rid,x,color in [('home_study',-10.5,'lightwood'),('home_bedroom',-3.5,'rose'),('home_bathroom',3.5,'glass'),('home_balcony',10.5,'sand')]:
        mini_room(rid,x,7.1,6.7,6.0,color,True)
    for rid,x,w,color in [('home',-10,7,'lightwood'),('home_dining',2,6,'mint'),('home_kitchen',9.5,7,'cream')]:
        mini_room(rid,x,-3.6,w,7.0,color,False)
    m.group('30_Courtyard')
    for i in range(7):
        x=-3.5*min(1,i/4);y=-14+i*.82
        m.box('Garden_Stepping_Stone',(x,y,.025),(2.0,.66,.05),'sand',.12)
    for x in [-16,16]:
        m.collider('Garden_Boundary', (x,0,1),(.3,32,2))
        for y in range(-15,15,2):m.cyl('Fence_Post',(x,y,.65),.09,1.3,'oak',12)
        for z in [.4,.95]:m.beam('Fence_Rail',(x,-15,z),(x,15,z),.055,'lightwood')
    m.collider('Rear_Boundary',(0,15.7,1),(32,.3,2))
    m.collider('Front_Left',(-8.7,-15.5,1),(14.5,.3,2));m.collider('Front_Right',(8.7,-15.5,1),(14.5,.3,2))
    m.table('Mail_Table',-10,-11.7,2.2,1.0,.9)
    m.box('Mailbox_Post',(-11.5,-12.0,.65),(.2,.2,1.3),'oak')
    m.box('Mailbox',(-11.5,-12.0,1.55),(1.2,.6,.7),'teal',.12)
    m.parcel('Invitation_Letter',-10,-11.7,1.06,.65,'paper')
    m.garden_box('Front_Flower_Bed',8,-11.7,4.3,1.3,True)
    m.table('Watering_Can_Stand',6.5,-11.8,.85,.75,.80)
    m.basket('Entrance_Basket',-5.8,-6.6,0,False)
    m.board('Family_Day_Board',2,-11.7,'OUR DAY','PLAY / HELP / REST','teal',1.4,2.8)
    m.bench('Porch_Bench',11.5,-8.8,3.0,'lightwood')
    m.tree('Garden_Shade_Tree',14.1,-10.0,False,1.0)
    m.tree('Garden_Apple_Tree',-14,-11.8,True,.9)
    m.plant('Porch_Flower',-7.0,-8.0,0,True,.8)
    for rid,xy in DOORS.items():m.anchor('SG_DOOR_'+rid.upper(),xy,'走进'+ROOMS[rid]['name'])
    for state in ['before','middle','after']:
        root=task_root(state)
        m.cyl('Watering_Can',(6.5 if state!='middle' else 7.8,-11.8,1.0),.25,.4,'teal')
        if state=='middle':m.beam('Watering_Stream',(7.8,-11.8,1.1),(8,-11.6,.6),.05,'water')
        if state=='after':
            for x in [7.3,8,8.7]:m.ball('Damp_Soil',(x,-11.6,.62),(.25,.23,.02),'soil')
        end_task(root,state!='before')


BUILDERS={'home_estate':make_estate,'home':make_living,'home_bedroom':make_bedroom,'home_kitchen':make_kitchen,
          'home_dining':make_dining,'home_bathroom':make_bathroom,'home_study':make_study,'home_balcony':make_balcony}


def build(rid):
    BUILDERS[rid]()
    if rid!='home':
        add_anchors(rid);p.preview_setup(1200)
        if rid=='home_estate':
            bpy.context.scene.camera.data.ortho_scale=48
            p.point_camera(bpy.context.scene.camera,(0,-1,0))
    folder=ROOT/'assets/blender/interiors'/rid;folder.mkdir(parents=True,exist_ok=True)
    version='v02' if rid=='home' else 'v01'
    existing={'blend':(folder/(rid+'_'+version+'.blend')).relative_to(ROOT).as_posix(),
              'glb':(folder/(rid+'_'+version+'.glb')).relative_to(ROOT).as_posix(),
              'preview':(folder/('preview_'+version+'.png')).relative_to(ROOT).as_posix()}
    p.finish_room(rid,ROOMS[rid]['name'],existing=existing,render=True)


if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for rid in args or list(BUILDERS):build(rid)
    path=ROOT/'assets/blender/interiors/interiors_manifest.json'
    data=json.loads(path.read_text('utf-8'))
    data.setdefault('hierarchy',{}).update({'home_estate':'home_estate','home_children':[r for r in ROOMS if r!='home_estate']})
    p.write_json(path,data)
