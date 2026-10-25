"""Build the walkable home entrance hall and connecting corridor.

Run by the integrator: blender --background --python scripts/build_home_hall.py
Original geometry, Blender Z up, metres, forward -Y; no external art assets.
This script never edits the exterior or the seven existing room source files.
"""
import math
from pathlib import Path
import sys

import bpy

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'assets/blender/interiors/scripts'))
import modeling as m
import pipeline as p

ROOM_ID = 'home_hall'
ROOM_LABEL = '家里 · 门厅与走廊'
DOORS = {
    'home_study': (-10.5, 6.0),
    'home_bedroom': (-3.5, 6.0),
    'home_bathroom': (3.5, 6.0),
    'home_balcony': (10.5, 6.0),
    'home': (-10.5, -3.95),
    'home_dining': (3.5, -3.95),
    'home_kitchen': (10.5, -3.95),
}
DOOR_STYLE = {
    'home_study': ('书房', 'STUDY', 'teal', 'book'),
    'home_bedroom': ('卧室', 'BEDROOM', 'rose', 'bed'),
    'home_bathroom': ('浴室', 'BATHROOM', 'blue', 'bath'),
    'home_balcony': ('家务阳台', 'BALCONY', 'sage', 'leaf'),
    'home': ('客厅', 'LIVING', 'mint', 'sofa'),
    'home_dining': ('餐厅', 'DINING', 'clay', 'plate'),
    'home_kitchen': ('厨房', 'KITCHEN', 'yellow', 'pot'),
}


def _material(name, color):
    mat = bpy.data.materials.new('MAT_' + name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = .74
    mat.diffuse_color = (*color, 1)
    m.M[name] = mat


def _wall_section(name, x, y, width, height=3.5, depth=.26):
    m.box(name, (x, y, height/2), (width, depth, height), 'cream', .035)
    m.box(name+'_Skirting', (x, y-depth/2-.025, .12), (width, .10, .24), 'ivory', .018)
    m.box(name+'_Chair_Rail', (x, y-depth/2-.035, 1.01 if height>1.2 else height-.02),
          (width, .12, .10), 'lightwood', .018)
    # Recessed lower wall panels have a real rectangular frame and warm inset.
    count=max(1, int(width/1.25))
    panel_width=width/count-.20
    panel_height=min(.65,max(.22,height-.30))
    panel_z=.18+panel_height/2
    for j in range(count):
        xx=x-width/2+(j+.5)*width/count
        m.box(name+'_Wainscot_Frame', (xx,y-depth/2-.015,panel_z), (panel_width,.045,panel_height), 'ivory', .025)
        m.box(name+'_Wainscot_Inset', (xx,y-depth/2-.046,panel_z), (panel_width-.13,.025,panel_height-.13), 'hall_panel', .018)
    if height>1.2:
        m.box(name+'_Crown', (x,y,height-.04), (width+.04,depth+.16,.16), 'ivory', .03)


def _icon(name, kind, x, y, z):
    """Small solid pictograms on doors, authored from geometry, facing -Y."""
    def b(s, dx, dz, w, h, color='ivory'):
        return m.box(name+'_'+s,(x+dx,y,z+dz),(w,.055,h),color,.025)
    if kind=='book':
        b('Book_Left',-.21,0,.37,.55);b('Book_Right',.21,0,.37,.55)
        b('Book_Spine',0,-.02,.045,.61,'gold')
        for dx in [-.21,.21]:
            for dz in [-.12,.02,.16]:b('Book_Line',dx,dz,.25,.024,'oak')
    elif kind=='bed':
        b('Bed_Frame',0,-.10,.82,.12);b('Bed_Quilt',.12,.04,.59,.26)
        b('Bed_Headboard',-.38,.10,.09,.56);b('Bed_Pillow',-.21,.12,.22,.17,'paper')
        for dx in [-.35,.35]:b('Bed_Leg',dx,-.25,.08,.21)
    elif kind=='bath':
        b('Tub',0,-.07,.75,.28);b('Tub_Rim',0,.10,.88,.08)
        for dx in [-.27,.27]:b('Tub_Foot',dx,-.25,.08,.14,'gold')
        m.beam(name+'_Tap',(x-.32,y,z+.13),(x-.32,y,z+.37),.03,'gold')
        m.beam(name+'_Tap_Spout',(x-.32,y,z+.37),(x-.10,y,z+.37),.03,'gold')
    elif kind=='leaf':
        m.beam(name+'_Stem',(x,y,z-.36),(x+.08,y,z+.37),.027,'ivory')
        for dx,dz,angle in [(-.16,-.14,-.45),(.19,.02,.45),(-.13,.18,-.4)]:
            ob=m.ball(name+'_Leaf',(x+dx,y,z+dz),(.20,.04,.115),'ivory',10,5)
            ob.rotation_euler.y=angle
    elif kind=='sofa':
        b('Sofa_Back',0,.10,.64,.34);b('Sofa_Seat',0,-.13,.75,.15)
        for dx in [-.38,.38]:b('Sofa_Arm',dx,-.02,.13,.34)
        for dx in [-.28,.28]:b('Sofa_Foot',dx,-.26,.07,.12,'gold')
    elif kind=='plate':
        m.ring(name+'_Plate',(x,y,z),.29,.045,'ivory',(math.pi/2,0,0),segments=24)
        m.ring(name+'_Plate_Inner',(x,y-.01,z),.20,.018,'gold',(math.pi/2,0,0),segments=24)
        for dx in [-.46,.46]:b('Cutlery',dx,-.01,.045,.68)
        for dx in [-.51,-.46,-.41]:b('Fork_Prong',dx,.27,.025,.17)
    elif kind=='pot':
        b('Pot',0,-.06,.60,.40);b('Pot_Lid',0,.18,.73,.07)
        b('Pot_Lid_Handle',0,.28,.18,.09,'gold')
        for dx in [-.39,.39]:b('Pot_Handle',dx,.03,.17,.08,'gold')


def _door(rid, x, y):
    chinese,label,color,kind=DOOR_STYLE[rid]
    name='Hall_Door_'+rid
    m.group('20_Seven_Room_Doors')
    # Complete solid doors sit in wall openings: inner stop, jambs, lintel,
    # transom surround, recessed panels, hinge pins, knob, purpose pictogram.
    m.box(name+'_Shadow_Reveal',(x,y+.10,1.53),(2.44,.20,3.06),'darkwood',.025)
    m.box(name+'_Leaf',(x,y-.025,1.48),(2.24,.15,2.96),color,.04)
    for dx in [-1.28,1.28]:
        m.box(name+'_Jamb',(x+dx,y-.06,1.60),(.20,.32,3.20),'lightwood',.025)
        m.box(name+'_Casing',(x+dx,y-.25,1.60),(.27,.10,3.27),'ivory',.025)
        m.box(name+'_Plinth',(x+dx,y-.25,.18),(.33,.14,.36),'ivory',.02)
    m.box(name+'_Lintel',(x,y-.06,3.16),(2.75,.34,.23),'lightwood',.035)
    m.box(name+'_Head_Casing',(x,y-.25,3.22),(2.93,.12,.24),'ivory',.035)
    m.box(name+'_Cornice',(x,y-.16,3.39),(3.10,.45,.13),'ivory',.035)
    m.box(name+'_Bottom_Panel_Frame',(x,y-.115,.70),(1.74,.06,.87),'hall_panel',.035)
    m.box(name+'_Bottom_Panel_Inset',(x,y-.154,.70),(1.53,.025,.65),color,.025)
    m.box(name+'_Icon_Plaque',(x,y-.13,2.14),(1.20,.09,1.10),color,.09)
    _icon(name+'_Purpose',kind,x,y-.23,2.15)
    m.box(name+'_Name_Plate',(x,y-.17,1.35),(1.65,.06,.30),'ivory',.035)
    m.text(name+'_Name',label,(x,y-.21,1.35),.15 if len(label)>7 else .18,'teal')
    m.cyl(name+'_Knob_Plate',(x+.85,y-.15,1.35),.12,.04,'gold',16).rotation_euler.x=math.pi/2
    m.ball(name+'_Door_Knob',(x+.85,y-.24,1.35),(.085,.11,.085),'gold',12,6)
    for z in [.53,2.45]:m.cyl(name+'_Hinge',(x-1.14,y-.11,z),.04,.19,'gold',10)
    m.box(name+'_Threshold',(x,y-.34,.035),(2.45,.61,.07),'oak',.03)
    # Door face itself is solid; approach anchors trigger scene transitions.
    m.collider(name,(x,y+.01,1.55),(2.60,.28,3.10))
    anchor=m.anchor('SG_DOOR_'+rid.upper(),DOORS[rid],'走进'+chinese)
    anchor['target_room_id']=rid
    anchor['approach_side']='front'


def _sconce(name,x,y,z=2.65):
    m.box(name+'_Backplate',(x,y,z),(.18,.08,.37),'gold',.04)
    m.beam(name+'_Arm',(x,y-.02,z-.1),(x,y-.33,z-.1),.025,'gold')
    m.cyl(name+'_Shade',(x,y-.35,z+.08),.19,.36,'paper',16,top=.28)
    m.cyl(name+'_Shade_Trim',(x,y-.35,z-.11),.19,.04,'gold',16)


def _entry_furniture():
    m.group('40_Entry_Furniture')
    # All furniture remains left/right of the main x=-3.5 entry axis.
    x,y=-8.3,-7.15
    m.box('Entry_Shoe_Bench_Frame',(x,y,.35),(3.0,.95,.70),'ivory',.06)
    m.box('Entry_Shoe_Bench_Seat',(x,y,.75),(3.13,1.04,.16),'lightwood',.06)
    for dx in [-1.0,0,1.0]:
        m.box('Shoe_Cubby_Recess',(x+dx,y-.49,.35),(.82,.025,.44),'darkwood',.025)
        for sx in [-.17,.17]:
            m.box('Entry_Shoe',(x+dx+sx,y-.51,.20),(.23,.40,.16),'teal' if dx==0 else 'oak',.07)
    m.pillow('Entry_Bench_Cushion',x+.72,y,.91,'mint',(1.28,.80,.22))
    # Backed coat rail provides a wall surface instead of floating hooks.
    m.box('Entry_Coat_Backboard',(x,y+.42,1.87),(3.10,.12,2.26),'cream',.04)
    m.box('Entry_Coat_Rail',(x,y+.30,2.51),(2.70,.16,.19),'lightwood',.025)
    for i,xx in enumerate([x-.95,x-.32,x+.32,x+.95]):
        m.beam('Entry_Coat_Hook',(xx,y+.18,2.50),(xx,y-.02,2.40),.027,'gold')
        m.ball('Entry_Hook_End',(xx,y-.02,2.40),(.045,.045,.045),'gold',10,5)
        if i in [0,2]:
            coat=m.box('Entry_Hanging_Coat',(xx,y+.15,1.97),(.44,.14,.75),['rose','teal'][i//2],.08)
            for side in [-1,1]:
                sleeve=m.box('Entry_Coat_Sleeve',(xx+side*.27,y+.15,2.07),(.15,.13,.47),['rose','teal'][i//2],.045)
                sleeve.rotation_euler.y=side*.28
    m.collider('Entry_Shoe_Bench',(x,y,.49),(3.17,1.06,.98))
    m.collider('Entry_Coat_Backboard',(x,y+.42,1.3),(3.16,.20,2.6))
    m.box('Entry_Mirror_Frame',(-11.6,-7.30,1.72),(1.22,.18,2.50),'oak',.12)
    m.box('Entry_Mirror',(-11.6,-7.41,1.72),(1.02,.045,2.27),'glass',.10)
    for xx in [-12.0,-11.2]:m.box('Entry_Mirror_Foot',(xx,-7.12,.13),(.15,.75,.26),'oak',.03)
    m.collider('Entry_Full_Length_Mirror',(-11.6,-7.27,1.3),(1.25,.70,2.6))
    m.basket('Entry_Umbrella_Basket',-6.2,-7.25,0,False)
    for xx in [-6.35,-6.12]:
        m.beam('Entry_Umbrella_Stem',(xx,-7.25,.22),(xx,-7.25,1.60),.025,'wood')
        m.ring('Entry_Umbrella_Crook',(xx+.09,-7.25,1.60),.10,.022,'gold',(math.pi/2,0,0),.5,20)
        m.cyl('Entry_Folded_Umbrella',(xx,-7.25,.90),.10,.88,'navy',8,top=.035)


def _hall_life():
    m.group('41_Hall_Living_Details')
    # A practical shallow console at the back and a quiet seat in the entry wing.
    m.table('Hall_Family_Console',0,7.06,2.22,.74,.94,'lightwood')
    for dx in [-.52,.52]:
        m.box('Hall_Console_Drawer',(dx,6.66,.77),(.87,.08,.22),'ivory',.025)
        m.ball('Hall_Console_Knob',(dx,6.60,.77),(.045,.04,.045),'gold',10,5)
    m.plant('Hall_Console_Plant',-.70,7.06,1.04,False,.37)
    m.box('Hall_Family_Photo_Frame',(.48,7.08,1.35),(.65,.10,.57),'oak',.035)
    m.box('Hall_Family_Photo_Paper',(.48,7.01,1.35),(.52,.025,.44),'paper',.025)
    for j,xx in enumerate([.30,.48,.66]):
        m.ball('Hall_Family_Photo_Head',(xx,6.985,1.43),(.06,.025,.06),'clay',10,5)
        m.box('Hall_Family_Photo_Body',(xx,6.985,1.28),(.12,.025,.20),['mint','rose','yellow'][j],.02)
    m.clock_face('Hall_Family_Clock',0,7.94,2.58)
    m.bench('Hall_Window_Seat',7.05,-7.20,3.35,'lightwood')
    m.pillow('Hall_Window_Seat_Cushion',6.20,-7.15,.77,'rose',(.72,.52,.21))
    m.pillow('Hall_Window_Seat_Cushion',7.87,-7.15,.77,'mint',(.72,.52,.21))
    m.box('Hall_Reading_Book',(7.1,-7.16,.72),(.58,.39,.08),'teal',.02)
    m.table('Hall_Window_End_Table',9.55,-7.20,.82,.75,.75,'lightwood')
    m.plant('Hall_Quiet_Corner_Plant',11.90,-7.15,0,False,1.0)
    m.plant('Hall_Rear_Corner_Plant',12.70,6.90,0,False,.80)
    # One compact wall display in the front wing; no gameplay text overlays.
    m.box('Hall_Family_Gallery_Back',(2.4,-7.40,1.45),(2.22,.15,2.90),'cream',.05)
    for dx,dz,color in [(-.54,.28,'rose'),(.48,.40,'mint'),(.22,-.44,'yellow')]:
        m.box('Hall_Gallery_Frame',(2.4+dx,-7.50,1.75+dz),(.78,.12,.66),'oak',.035)
        m.box('Hall_Gallery_Artwork',(2.4+dx,-7.57,1.75+dz),(.62,.025,.50),'paper',.02)
        m.ball('Hall_Gallery_Motif',(2.4+dx,-7.59,1.75+dz),(.19,.022,.16),color,12,6)
    m.collider('Hall_Family_Gallery',(2.4,-7.40,1.5),(2.3,.28,3.0))


def make_hall():
    m.setup(ROOM_ID)
    bpy.context.scene['room_label']=ROOM_LABEL
    bpy.context.scene['navigation_only']=True
    bpy.context.scene['home_hierarchy_role']='walkable indoor entrance hall and corridor'
    _material('hall_panel',(.88,.82,.68))
    _material('hall_oak',(.76,.57,.33))
    _material('hall_oak_light',(.80,.62,.38))
    _material('hall_rug',(.21,.43,.40))
    m.group('00_Hall_Architecture')
    m.floor(28,20,'lightwood',False)
    # Alternating broad floorboards with staggered end joints, all under .01 m.
    for row in range(27):
        yy=-9.45+row*.68
        m.box('Hall_Oak_Floorboard_Row',(0,yy,.003),(27.35,.65,.006),
              'hall_oak_light' if row%3 else 'hall_oak',.002)
        for xx in [-10.4,-5.2,0,5.2,10.4]:
            m.box('Hall_Staggered_Plank_Joint',(xx+(2.3 if row%2 else 0),yy,.008),(.016,.65,.008),'oak',0)
    # A continuous rear wall and low cutaway side/front walls enclose the home.
    _wall_section('Hall_Rear_Wall',0,8.16,27.7,3.58,.30)
    m.collider('Hall_Rear_Wall',(0,8.16,1.8),(28,.34,3.6))
    for side in [-1,1]:
        ob=m.box('Hall_Cutaway_Side_Wall',(side*13.79,-.52,.56),(.26,17.64,1.12),'cream',.03)
        m.box('Hall_Cutaway_Side_Cap',(side*13.79,-.52,1.12),(.38,17.70,.10),'ivory',.025)
        m.box('Hall_Side_Baseboard',(side*13.58,-.52,.13),(.10,17.62,.26),'ivory',.018)
        m.collider('Hall_Side_Boundary_'+str(side),(side*13.92,0,1),(.28,20,2))
    # Entry threshold keeps a real, open front door location in the cutaway shell.
    _wall_section('Hall_Front_Left',-9.47,-9.72,8.80,.72)
    _wall_section('Hall_Front_Right',5.87,-9.72,15.86,.72)
    m.collider('Hall_Front_Left',(-9.47,-9.86,1),(8.80,.28,2))
    m.collider('Hall_Front_Right',(5.87,-9.86,1),(15.86,.28,2))
    for xx in [-5.06,-1.94]:m.box('Hall_Entry_Cut_Jamb',(xx,-9.71,.65),(.25,.45,1.30),'lightwood',.025)
    m.box('Hall_Entry_Threshold',(-3.5,-9.54,.035),(2.92,.70,.07),'oak',.025)
    m.rug('Hall_Entry_Mat',(-3.5,-8.66),(2.48,1.25),'sand')
    # These joined wall runs form two wings; the central 5.2 m gap is the corridor.
    for name,left,right in [('Left',-13.78,-6.10),('Right',-.90,13.78)]:
        _wall_section('Hall_Front_Wing_'+name,(left+right)/2,-2.02,right-left,.92,.28)
        m.collider('Hall_Front_Wing_'+name,((left+right)/2,-2.02,.48),(right-left,.30,.96))
        # Low rear returns make the cutaway architectural depth explicit.
        for xx in [left,right]:
            m.box('Hall_Wing_Return',(xx,-.91,.46),(.22,2.24,.92),'cream',.025)
            m.box('Hall_Wing_Return_Cap',(xx,-.91,.94),(.32,2.27,.10),'ivory',.025)
            m.collider('Hall_Wing_Return',(xx,-.91,.50),(.22,2.24,1.0))
    for rid,(x,anchor_y) in DOORS.items():
        y=7.70 if anchor_y>0 else -2.25
        if anchor_y<0:
            # Raised wall shoulders join each portal to the continuous cutaway wall.
            for dx in [-1.63,1.63]:_wall_section('Hall_Door_Shoulder_'+rid,x+dx,-2.03,.45,2.96,.27)
        _door(rid,x,y)
    m.group('30_Hall_Rugs_and_Wall_Lights')
    m.rug('Hall_Entry_Runner',(-3.5,-2.00),(3.26,10.69),'hall_rug')
    m.rug('Hall_Corridor_Runner',(0,4.72),(24.40,2.75),'hall_rug')
    # Slim gold/cream borders and diamond markers provide direction, not signage.
    for xx in [-4.97,-2.03]:m.box('Hall_Runner_Long_Border',(xx,-2.00,.047),(.045,10.35,.009),'paper',0)
    for xx in [-10.5,-3.5,3.5,10.5]:
        ob=m.box('Hall_Corridor_Woven_Diamond',(xx,4.72,.048),(.40,.40,.01),'sand',.025)
        ob.rotation_euler.z=math.pi/4
    for xx in [-12.85,-8.45,-1.2,1.2,8.45,12.85]:_sconce('Hall_Wall_Light',xx,7.96,2.50)
    for xx in [-7,7]:
        m.window('Hall_High_Window',xx,7.96,2.24,1.55,1.45)
    _entry_furniture()
    _hall_life()
    m.anchor('SG_SPAWN',(-3.5,-7.8),'从家门进入门厅')
    m.anchor('SG_EXIT',(-3.5,-8.8),'返回小院')
    return {'room_id':ROOM_ID,'room_label':ROOM_LABEL,'doors_blender':DOORS,
            'spawn_blender':[-3.5,-7.8],'exit_blender':[-3.5,-8.8],
            'walkable_center_opening_x':[-6.1,-.9]}


def build(render=True):
    metadata=make_hall()
    p.preview_setup(1440)
    camera=bpy.context.scene.camera
    camera.location=(18,-26,28)
    camera.data.ortho_scale=36.5
    p.point_camera(camera,(0,-.35,.65))
    folder=ROOT/'assets/blender/interiors/home_hall'
    existing={key:(folder/file).relative_to(ROOT).as_posix() for key,file in {
        'blend':'home_hall_v01.blend','glb':'home_hall_v01.glb','preview':'preview_v01.png'}.items()}
    # Navigation halls deliberately do not invent memory/housework anchors.
    previous_required=p.REQUIRED
    try:
        p.REQUIRED=['SG_SPAWN','SG_EXIT']+['SG_DOOR_'+rid.upper() for rid in DOORS]
        p.finish_room(ROOM_ID,ROOM_LABEL,existing=existing,render=render)
    finally:
        p.REQUIRED=previous_required
    return metadata


if __name__=='__main__':
    build()
