"""Concrete plan alignment, applied only by the opt-in generator.

The authored game plan supplies labels and activity metadata. Geometry changes
below are explicit recipes, not a renaming pass over unrelated generic props.
"""
import bpy,json,math
from pathlib import Path
import modeling as m
import room_recipes as r
from modeling import *

ROOT=Path(__file__).resolve().parents[4]

def remove_prefix(*prefixes):
    for ob in list(bpy.context.scene.objects):
        if any(ob.name.startswith(p) for p in prefixes):bpy.data.objects.remove(ob,do_unlink=True)

def redo(i):
    name=f'1{i}_Locus_{i:02}'
    coll=bpy.data.collections.get(name)
    if coll:
        for ob in list(coll.objects):bpy.data.objects.remove(ob,do_unlink=True)
    remove_prefix(f'SG_COLLIDER_Locus_{i:02}')
    group(name)

def cards(name,x,y,z,w=2.0):
    for i in range(4):
        xx=x-w*.38+i*w*.25
        box(name+'_Card',(xx,y,z+.22),(.36,.1,.45),'paper',.025)
        ball(name+'_Picture',(xx,y-.07,z+.24),(.1,.02,.1),['rose','blue','yellow','mint'][i])

def round_table(name,x,y,radius=1.4,h=.9):
    cyl(name+'_Top',(x,y,h),radius,.16,'lightwood',48)
    cyl(name+'_Stem',(x,y,h/2),.30,h,'oak')
    cyl(name+'_Foot',(x,y,.12),.85,.24,'oak')
    collider(name,(x,y,h/2),(radius*2,radius*2,h+.15));return h+.09

def picture_wall(name,x,y,title):
    board(name,x,y,title,'Memories we share',color='cream')
    for i in range(3):
        xx=x-.65+i*.65
        box(name+'_Photo_Frame',(xx,y-.20,1.42),(.5,.06,.38),'teal')
        ball(name+'_Portrait',(xx,y-.25,1.45),(.11,.035,.12),'rose')

def wheel(name,x,y,title,colors=('yellow','navy')):
    board(name,x,y,title,'',color='teal',w=2.3)
    for i in range(8):
        a=i*math.tau/8
        ball(name+'_Sector',(x+.38*math.sin(a),y-.22,1.5+.38*math.cos(a)),(.18,.035,.18),colors[i%len(colors)])
    beam(name+'_Pointer',(x,y-.28,1.5),(x+.25,y-.28,1.8),.025,'ivory')

def sofa(name,x,y):
    box(name+'_Base',(x,y,.48),(2.8,1.15,.65),'rose',.2)
    box(name+'_Back',(x,y+.45,.94),(2.8,.3,.85),'rose',.15)
    for xx in [-1.25,1.25]:box(name+'_Arm',(x+xx,y,.8),(.3,1.2,.7),'rose',.12)
    for xx in [-.7,.7]:pillow(name+'_Cushion',x+xx,y,.86,'yellow')
    collider(name,(x,y,.7),(2.8,1.35,1.4))

def framed_window(name,x,y,label,color='glass'):
    window(name,x,y,1.85,2.3,1.7)
    text(name+'_Label',label,(x,y-.3,2.98),.23,'teal')
    for xx in [-1.1,1.1]:box(name+'_Leg',(x+xx,y,.65),(.13,.18,1.3),'oak')
    collider(name,(x,y,1.35),(2.6,.65,2.7))

def floor_profile(key):
    # These are distinct usable outlines, not merely recoloured rectangular shells.
    rounded={'C':3.6,'D':3.2,'E':3.5,'F':4.0,'G':3.5,'H':3.5,'J':3.5,'L':4.0,'M':3.4,'N':3.1,'P':3.5,'Q':4.0,'U':3.5,'W':4.0,'Y':3.5}
    if key not in rounded and key not in ('K','S','home'):return
    remove_prefix('SG_FLOOR_Main','Foundation_Edge','Floor_Plank_Joint','Floor_End_Joint')
    group('00_Architecture')
    points=[]
    if key=='S':
        for i in range(10):
            a=math.pi+math.tau*i/10;rr=11.4 if i%2==0 else 7.9
            points.append((math.sin(a)*rr,math.cos(a)*rr))
        remove_prefix('Rear_Wall','Rear_Baseboard','Rear_Crown','Left_Cutaway_Wall','Back_Corner_Post','Wall_Star')
        for i in range(9):
            a=math.pi*i/8
            pts=[(2.4*math.cos(j*math.pi/20)*math.cos(a),5.2+2.4*math.cos(j*math.pi/20)*math.sin(a),.1+2.8*math.sin(j*math.pi/20)) for j in range(11)]
            for p,q in zip(pts,pts[1:]):beam('Observatory_Dome_Rib',p,q,.045,'gold')
        ring('Observatory_Dome_Base',(0,5.2,.1),2.4,.07,'gold',portion=.5)
        for x in [-2.6,2.6]:beam('Observatory_Sign_Post',(x,6.72,0),(x,6.72,3.45),.065,'gold')
    elif key=='K':points=[(-8.6,-3),(-5.2,-7.5),(4.7,-7.5),(8.6,-2.5),(8.6,4.2),(3.5,7.5),(-4,7.5),(-8.6,4)]
    elif key=='home':points=[(-8.1,-7.1),(8.1,-7.1),(8.1,7.1),(-8.1,7.1),(-8.1,2),(-7.8,2)]
    else:
        power=rounded[key]
        for i in range(96):
            a=math.tau*i/96;c,s=math.cos(a),math.sin(a)
            points.append((8.65*math.copysign(abs(c)**(2/power),c),7.65*math.copysign(abs(s)**(2/power),s)))
    # All objects and approach points fit within the clipped pavilion footprint.
    vs=[(x,y,z) for z in [-.46,0] for x,y in points];n=len(points)
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mat='grass' if key in ('F','P') else 'oak' if key in ('D','N') else 'blue' if key=='S' else 'lightwood'
    ob=mesh('SG_FLOOR_Main',vs,fs,mat);soften(ob,.08)
    if key=='S':
        # The star is sampled as (sin(a), cos(a)), a clockwise perimeter.
        # Keep vertex positions, but orient the closed shell outwards for Godot.
        import bmesh
        bm=bmesh.new();bm.from_mesh(ob.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(ob.data);bm.free();ob.data.update()
    if key=='C':
        # Clip the square tile field to the true rounded outline, leaving a clean border.
        for tile in list(bpy.context.scene.objects):
            if tile.name.startswith('Bakery_Floor'):
                corners=[(tile.location.x+dx*.5,tile.location.y+dy*.5) for dx in [-1,1] for dy in [-1,1]]
                if any((abs(x)/8.55)**3.6+(abs(y)/7.55)**3.6>.98 for x,y in corners):bpy.data.objects.remove(tile,do_unlink=True)
        for ob in bpy.context.scene.objects:
            if ob.name.startswith('Bakery_Window_Left'):ob.location.x+=.7
            elif ob.name.startswith('Bakery_Window_Right'):ob.location.x-=.7
        for ob in list(bpy.context.scene.objects):
            if ob.name.startswith('Cream_Cornice') and abs(ob.location.x)>5:bpy.data.objects.remove(ob,do_unlink=True)
    if key not in ('S','home','K'):
        # A short rear chord joins the curved pavilion edge; the old rectangular
        # corners would otherwise overhang the rounded footprint.
        for name in ['Rear_Wall','Rear_Baseboard','Rear_Crown']:
            ob=bpy.data.objects.get(name)
            if ob:ob.scale.x=.75;ob.location.y=6.9
        remove_prefix('Left_Cutaway_Wall','Back_Corner_Post')
    remove_prefix('SG_COLLIDER_Boundary','SG_COLLIDER_Front_')
    # Narrow visible perimeter, no tall camera-side wall.
    for i in range(n):
        a=points[i];b=points[(i+1)%n]
        beam('Pavilion_Rim',(*a,-.25),(*b,-.25),.07,'oak')
        length=math.hypot(b[0]-a[0],b[1]-a[1]);parts=max(1,math.ceil(length/.55))
        for j in range(parts):
            t=(j+.5)/parts;x=a[0]+(b[0]-a[0])*t;y=a[1]+(b[1]-a[1])*t
            if y<0 and abs(x)<1.45:continue
            proxy=collider('Pavilion_Edge',(x,y,1),(length/parts+.06,.12,2))
            proxy.rotation_euler.z=math.atan2(b[1]-a[1],b[0]-a[0])
    bpy.context.scene['floor_profile']='star' if key=='S' else 'kite_chamfer' if key=='K' else 'rounded_'+str(rounded.get(key,'L'))
    if key=='D':
        for rr in [2.4,3.8,5.3,6.5]:ring('Drum_Concentric_Inlay',(0,1,.024),rr,.025,'sand')
    if key=='F':
        for i in range(5):
            a=math.tau*i/5
            ob=ball('Petal_Glass_Rib',(math.cos(a)*3.8,3+math.sin(a)*1.9,3.75),(1.7,.1,.5),'glass');ob.rotation_euler[2]=a
            xx=math.cos(a)*3.8;yy=3+math.sin(a)*1.9
            beam('Petal_Greenhouse_Support',(xx,yy,0),(xx,yy,4.2),.06,'teal')
            collider('Petal_Support',(xx,yy,1.8),(.2,.2,3.6))
    if key=='K':
        remove_prefix('Rear_Wall','Rear_Baseboard','Rear_Crown','Left_Cutaway_Wall','Back_Corner_Post')
        for ob in bpy.context.scene.objects:
            if ob.name.startswith('Wall_Kite'):ob.location.y-=1
            elif ob.name.startswith('Shop_Title'):ob.location.y-=.9
        for x in [-5.8,5.8]:beam('Kite_Rear_Post',(x,5.7,0),(x,5.7,3.8),.09,'wood')
        beam('Kite_Rear_Rail',(-5.8,5.7,3.8),(5.8,5.7,3.8),.1,'wood')
        for a,b in [((-5,6.3,1.4),(0,6.3,4.7)),((0,6.3,4.7),(5,6.3,1.4)),((-5,6.3,1.4),(0,6.3,.4)),((0,6.3,.4),(5,6.3,1.4))]:beam('Kite_Diamond_Structure',a,b,.10,'wood')
    if key=='G':
        ring('Travel_Ring_Floor',(0,1.7,.03),3,.04,'gold')
        arc_wall('Travel_Curved_Niche',0,3.2,6.1,.2,math.pi-.2,1.15,'blue')
    if key=='H':ring('Hat_Brim_Circuit',(0,1,.03),4.7,.04,'cream')
    if key=='L':
        for x,y in [(-6,5.8),(6,5.8),(-6,-1.8),(6,-1.8)]:beam('Lantern_Pavilion_Column',(x,y,0),(x,y,3.4),.09,'clay')
    if key=='P':
        for i in range(9):
            a=.2+(math.pi-.4)*i/8
            ball('Pumpkin_Lobed_Wall',(7.4*math.cos(a),4+2.4*math.sin(a),1.2),(.6,.4,1.2),'clay')
    if key=='Q':
        for y in [2.8,5.1]:
            for x in [-6.8,6.8]:beam('Quilt_Arc_Post',(x,y,0),(x,y,3.4),.07,'wood')
            for i in range(12):
                x=-6.2+i*1.12;box('Quilt_Arc_Valance',(x,y,3.3+.25*math.cos(x/7*math.pi/2)),(1.1,.35,.30),['rose','mint','yellow','blue'][i%4])
    if key=='Y':
        for i in range(30):
            a=i*.17;rr=3.5+i*.045
            a2=a+.18;beam('Yarn_Spiral_Floor',(rr*math.cos(a),1+rr*math.sin(a),.035),((rr+.05)*math.cos(a2),1+(rr+.05)*math.sin(a2),.035),.035,'rose')

def apply(key):
    # A is adapted from its source .blend in adapt_orchard.py.
    if key=='A':return
    if key=='G':
        redo(1);z=table('Locus_01_Travel_Cards',-4.3,-4.8,2.2,.8,1);cards('Trip_Cards',-4.3,-4.8,z)
        redo(2);shelf('Locus_02_Postcards',-5.1,1.1,2.9,2,'none',1.7);cards('Postcards',-5.1,1, .45,2.6);cards('Postcards',-5.1,1,1.2,2.6)
        redo(5);board('Locus_05_Route_Wall',5.2,-5.15,'OUR ROUTE','Here - there - home',color='blue')
        for i in range(4):ball('Map_Stop',(4.4+i*.5,-5.34,1.5+math.sin(i)*.13),(.07,.025,.07),'yellow')
    elif key=='H':
        redo(1);remove_prefix('SG_COLLIDER_Mirror');board('Locus_01_Try_Hats',-4.3,-4.8,'TRY A HAT','Find your favourite',color='rose')
        redo(2);shelf('Locus_02_Fabrics',-5.1,1.1,3,2,'none',2.2)
        for j in range(5):
            x=-6.1+j*.5;ob=cyl('Fabric_Roll',(x,1.1,.65),.20,.9,['rose','yellow','blue','mint','purple'][j]);ob.rotation_euler[0]=math.pi/2
        redo(3);z=table('Locus_03_Mirror_Table',0,1.7,3,1.2,.8)
        box('Dressing_Mirror_Frame',(0,2,1.9),(1.6,.18,2.0),'gold',.18);box('Dressing_Mirror',(0,1.88,1.9),(1.35,.04,1.75),'glass',.14)
        hat('Trying_Hat',1,1.7,z,.5,'teal')
    elif key=='I':
        redo(2);z=table('Locus_02_Flavour_Cabinet',-5.1,1.1,2.8,1.2,1.0,'teal',True)
        for x,c in [(-5.9,'pink'),(-5.1,'mint'),(-4.3,'ivory')]:box('Flavour_Tub',(x,1.1,z+.07),(.7,.85,.14),'metal');ball('Flavour_Icecream',(x,1.1,z+.25),(.29,.34,.18),c)
        group('14_Locus_04');box('Topping_Slot_Tray',(5,.65,.95),(2.3,.5,.2),'cream')
    elif key=='J':
        redo(1);z=table('Locus_01_Deposit',-4.3,-4.8,2,1,.85);box('Deposit_Tray',(-4.3,-4.8,z+.06),(1.6,.65,.12),'teal')
        redo(3);z=round_table('Locus_03_Turntable',0,1.7,1.45,1)
        for x,c in [(-.7,'rose'),(0,'mint'),(.7,'yellow')]:jar('Sorting_Jar',x,1.7,z,.25,c)
        redo(4);sink('Locus_04_Clean_Label',5,1.25);cards('Jar_Labels',5,1.7,1.2,1.8)
    elif key=='K':
        redo(1);board('Locus_01_Plan',-4.3,-4.8,'BUILD A KITE','Frame - paper - ribbon',color='blue')
        redo(2);remove_prefix('SG_COLLIDER_Kite_Frame');shelf('Locus_02_Materials',-5.1,1.1,2.8,2,'yarn',1.9)
        for x in [-5.9,-5.7,-5.5]:beam('Bamboo_Spar',(x,1.2,.2),(x+.3,1.2,2.4),.03,'lightwood')
        redo(4);beam('Locus_04_Test_Frame',(4.1,1.25,0),(4.1,1.25,2.8),.08,'wood');beam('Test_Frame',(4.1,1.25,2.8),(6.1,1.25,2.8),.08,'wood');collider('Wind_Test_Post',(4.1,1.25,1.4),(.3,.3,2.8))
        for i in range(5):box('Wind_Ribbon',(4.5+i*.3,1.25,1.9),(.15,.05,1.5),['rose','yellow','mint','blue','purple'][i])
        redo(5);remove_prefix('SG_COLLIDER_Wind_Pole');r.kite('Locus_05_Kite_Gallery',5.2,-5.15,1.9,.85,'rose');collider('Kite_Gallery',(5.2,-5.15,1.3),(1.5,.3,2.6))
    elif key=='L':
        group('11_Locus_01');clock_face('Visit_Clock',-4.3,-4.95,2.7)
        group('15_Locus_05');beam('Lantern_Gallery_Rail',(4.0,-5.4,2.6),(6.5,-5.4,2.6),.06,'wood')
        for x in [4.2,5.2,6.2]:lantern('Gallery_Lantern',x,-5.4,2.2,'yellow',.25)
    elif key=='M':
        redo(1);basket('Locus_01_Slippers',-4.3,-4.8,0,False)
        for x in [-4.5,-4.1]:ball('Slipper',(x,-4.8,.56),(.13,.3,.08),'teal')
        redo(2);picture_wall('Locus_02_Neighbours',-5.1,1.1,'OUR NEIGHBOURS')
        redo(4);sofa('Locus_04_Window_Sofa',5,1.25);window('Neighbour_Window',5,2.1,2.2,2.3,1.2)
        group('70_Set_Dressing');sink('Cottage_Back_Kitchen',-4.8,5.5)
    elif key=='N':
        redo(2);telescope('Locus_02_Birdwatch',-5.1,1.1,0,.9)
        redo(3);z=table('Locus_03_Recording',0,1.7,3,1.5,.9);box('Bird_Journal',(0,1.7,z+.04),(1.1,.7,.08),'paper');cards('Bird_Cards',.8,1.7,z,1.0)
        redo(4);z=table('Locus_04_Feed_Water',5,1.25,2.6,1.3,.9)
        for x,c in [(4.4,'yellow'),(5.6,'water')]:cyl('Bird_Bowl',(x,1.25,z+.1),.4,.18,'oak');cyl('Bird_Bowl_Contents',(x,1.25,z+.21),.35,.025,c)
        redo(5);picture_wall('Locus_05_Bird_Diary',5.2,-5.15,'BIRDS WE SAW')
        group('70_Set_Dressing');table('Nest_Observation_Plinth',0,4.2,2,1.4,.7);ring('Bird_Nest',(0,4.2,.9),.7,.15,'wood');ball('Bird_Egg',(0,4.2,1.1),(.23,.18,.3),'blue')
    elif key=='O':
        redo(3);z=round_table('Locus_03_Question_Table',0,1.7,1.4,.85);box('Shared_Story',(0,1.7,z+.05),(1.1,.8,.1),'paper')
        group('14_Locus_04');ring('Eye_Reading_Window',(5,2.6,2.1),1.1,.12,'gold',(math.pi/2,0,0));box('Reading_Window_Stand',(5,2.6,.9),(.14,.20,1.8),'oak')
    elif key=='P':
        redo(3);box('Locus_03_Growing_Bed',(0,1.7,.14),(3.4,1.8,.28),'soil')
        for x in [-1,0,1]:r.pumpkin('Growing_Pumpkin',x,1.7,.15,.45);beam('Pumpkin_Vine',(x-.3,1,.2),(x+.5,2.3,.2),.045,'leaf')
        collider('Growing_Bed',(0,1.7,.4),(3.4,1.8,.8))
        redo(4);z=table('Locus_04_Compare_Scale',5,1.25,2.7,1.3,.9);beam('Scale_Upright',(5,1.25,z),(5,1.25,z+1.0),.065,'gold');beam('Scale_Balance',(4.1,1.25,z+.9),(5.9,1.25,z+.9),.05,'gold')
        for x,s in [(4.25,.3),(5.75,.42)]:cyl('Scale_Pan',(x,1.25,z+.2),.5,.07,'metal');r.pumpkin('Scale_Pumpkin',x,1.25,z+.25,s)
    elif key=='Q':
        redo(2);shelf('Locus_02_Picture_Drawers',-5.1,1.1,2.8,3,'none',1.8)
        for j in range(3):cards('Story_Cards',-5.1,.9,.2+j*.55,2.3)
        redo(5);board('Locus_05_Story_Quilt',5.2,-5.15,'OUR STORY','Beginning - middle - end',color='rose')
        for i in range(3):box('Story_Patch',(4.5+i*.7,-5.35,1.5),(.6,.06,.6),['blue','yellow','mint'][i]);ball('Story_Patch_Picture',(4.5+i*.7,-5.4,1.5),(.15,.025,.15),'paper')
    elif key=='R':
        redo(1);z=table('Locus_01_Command_Cards',-4.3,-4.8,2.3,1,.85,'metal',True);cards('Command_Cards',-4.3,-4.8,z)
        group('13_Locus_03')
        for yy in [1.1,2.3]:box('Robot_Test_Rail',(0,yy,1.06),(3.0,.07,.05),'yellow')
        redo(4);z=table('Locus_04_Repair_Arm',5,1.25,2.7,1.3,.9,'metal',True)
        cyl('Arm_Base',(5.5,1.25,z+.16),.35,.32,'teal');beam('Arm_Lower',(5.5,1.25,z+.3),(5.7,1.25,z+1.1),.12,'metal');ball('Arm_Joint',(5.7,1.25,z+1.1),(.19,)*3,'gold');beam('Arm_Upper',(5.7,1.25,z+1.1),(4.9,1.25,z+1.55),.1,'metal')
        for dx in [-.16,.16]:beam('Gripper',(4.9+dx,1.25,z+1.55),(4.8+dx,1.25,z+1.2),.045,'teal')
        redo(5);board('Locus_05_Status',5.2,-5.15,'READY TO HELP','All systems ready',color='teal')
        for x,c in [(4.6,'mint'),(5.2,'mint'),(5.8,'yellow')]:ball('Robot_Status_Light',(x,-5.34,1.4),(.11,.025,.11),c)
    elif key=='S':
        redo(1);wheel('Locus_01_Day_Night',-4.3,-4.8,'DAY AND NIGHT')
        redo(2);z=table('Locus_02_Star_Charts',-5.1,1.1,2.7,1.5,.9);box('Star_Map',(-5.1,1.1,z+.04),(2.2,1.1,.07),'navy');r.star_mesh('Map_Star',-5.1,1.1,z+.08,.35)
        redo(3);cyl('Locus_03_Celestial_Base',(0,1.7,.3),.85,.6,'gold');ball('Celestial_Sphere',(0,1.7,1.6),(.85,)*3,'navy');ring('Celestial_Equator',(0,1.7,1.6),1.05,.04,'gold');ring('Celestial_Meridian',(0,1.7,1.6),1.05,.04,'gold',(math.pi/2,.3,0));collider('Celestial_Sphere',(0,1.7,1.1),(2.2,2.2,2.2))
        redo(4);telescope('Locus_04_Telescope',5,1.25,0,1)
        for ob in bpy.data.collections['15_Locus_05'].objects:ob.location.y+=.3
        for ob in bpy.context.scene.objects:
            if ob.name.startswith('SG_COLLIDER_Locus_05'):ob.location.y+=.3
    elif key=='T':
        redo(2);z=table('Locus_02_Ticket_Window',-5.1,1.1,2.7,1.1,1,'teal',True);framed_window('Ticket_Window',-5.1,1.55,'TICKETS');cards('Tickets',-5.1,1.05,z)
        redo(3);bench('Locus_03_Waiting_Platform',0,1.7,3,'teal');box('Platform_Marker',(0,.9,.02),(3,.12,.04),'yellow')
        redo(5);remove_prefix('SG_COLLIDER_Platform_Portal');board('Locus_05_Arrivals',5.2,-5.15,'ARRIVING SOON','Welcome back',color='navy')
    elif key=='U':
        redo(1);wheel('Locus_01_Weather_Wheel',-4.3,-4.8,'SUN OR RAIN',('yellow','blue','ivory','rose'))
        group('12_Locus_02');hat('Weather_Hat',-5.1,1.1,2.05,.55,'yellow')
        redo(5);framed_window('Locus_05_Weather_Window',5.2,-5.15,'TODAY OUTSIDE')
    elif key=='V':
        redo(4);framed_window('Locus_04_Rock_Section',5,1.25,'ROCK LAYERS')
        for j in range(5):box('Rock_Strata',(5,1.05,1.1+j*.30),(2,.06,.27),['sand','clay','rock','stone','soil'][j])
        redo(5);shelf('Locus_05_Field_Records',5.2,-5.3,2.4,2,'books',1.6)
    elif key=='W':
        redo(2);z=table('Locus_02_Shore_Pool',-5.1,1.1,3,1.6,.75,'teal',True);box('Shore_Water',(-5.1,1.1,z+.06),(2.6,1.2,.08),'water');r.star_mesh('Shore_Starfish',-5.1,1.1,z+.12,.32,'rose');ball('Shore_Rock',(-5.8,1.1,z+.2),(.3,.2,.2),'stone')
        redo(3);rug('Locus_03_Whale_Size_Rug',(0,1.7),(4.3,2.7),'navy');ball('Whale_Size_Silhouette',(0,1.7,.08),(1.65,.65,.04),'blue')
        for y in [1.25,2.15]:ball('Whale_Size_Tail',(1.75,y,.08),(.45,.45,.04),'blue')
        for i in range(9):box('Size_Ruler_Tick',(-1.6+i*.4,.55,.07),(.04,.26,.015),'ivory',0)
        ball('Small_Fish_Silhouette',(-.8,2.55,.08),(.22,.1,.025),'yellow')
        redo(5);bench('Locus_05_Tail_Sharing_Bay',5.2,-5.15,2.5,'blue')
        for x in [4.7,5.7]:ball('Tail_Fin_Back',(x,-4.85,1.4),(.65,.15,.4),'teal')
    elif key=='X':
        redo(4);rug('Locus_04_Ensemble_Footprints',(5,1.25),(2.7,2),'teal')
        for x in [4.4,5.5]:
            for dy in [0,.4]:ball('Rehearsal_Footprint',(x,1.1+dy,.07),(.13,.25,.025),'yellow')
        stool('Ensemble_Stool',5.7,2.4,.55)
    elif key=='Y':
        redo(3);z=table('Locus_03_Winder',0,1.7,3,1.6,.9);beam('Winder_Shaft',(0,1.7,z),(0,1.7,z+1.3),.06,'wood')
        for i in range(6):
            a=i*math.tau/6;beam('Winder_Spoke',(-.85*math.cos(a),1.7-.85*math.sin(a),z+.9),(.85*math.cos(a),1.7+.85*math.sin(a),z+.9),.04,'wood')
        for zz in [z+.5,z+.65,z+.8,z+.95]:ring('Wound_Yarn',(0,1.7,zz),.7,.04,'rose')
        redo(4);z=table('Locus_04_Loom',5,1.25,2.7,1.4,.9)
        for x in [4.15,5.85]:beam('Loom_Frame',(x,1.25,z),(x,1.25,z+1.5),.07,'oak')
        for zz in [z+.2,z+1.5]:beam('Loom_Bar',(4.15,1.25,zz),(5.85,1.25,zz),.07,'oak')
        for i in range(12):beam('Warp_Thread',(4.25+i*.13,1.25,z+.2),(4.25+i*.13,1.25,z+1.5),.012,'cream')
        for j in range(7):box('Woven_Row',(5,1.18,z+.3+j*.12),(1.5,.05,.10),'rose' if j%2 else 'mint',.02)
        redo(5);z=table('Locus_05_Gift_Wrapping',5.2,-5.15,2.4,1, .9);parcel('Handmade_Gift',5.2,-5.15,z+.3,.9,'rose')
    elif key=='Z':
        redo(1);box('Locus_01_Incoming_Box',(-4.3,-4.8,.9),(1.5,1.1,1.8),'teal',.18);box('Incoming_Slot',(-4.3,-5.39,1.3),(.9,.04,.14),'navy');text('Incoming_Label','POST',(-4.3,-5.42,.8),.25);collider('Incoming_Box',(-4.3,-4.8,.9),(1.6,1.2,1.8))
        redo(3);z=table('Locus_03_Writing',0,1.7,3.2,1.6,.95);box('Writing_Paper',(0,1.7,z+.03),(1.4,.9,.06),'paper');beam('Writing_Pen',(-.4,1.2,z+.09),(.4,1.5,z+.09),.025,'teal')
        redo(4);z=table('Locus_04_Mailbags',5,1.25,2.7,1.2,.7)
        for x in [4.2,5,5.8]:ball('Mail_Sack',(x,1.25,z+.5),(.35,.3,.55),'sand');ring('Mail_Sack_Tie',(x,1.25,z+.95),.18,.04,'wood')
        redo(5);remove_prefix('SG_COLLIDER_Postbox');board('Locus_05_Postmark_Wall',5.2,-5.15,'OUR JOURNEYS','Stamped with a memory',color='paper')
        for i in range(3):ring('Postmark',(4.5+i*.7,-5.35,1.5),.22,.025,'teal',(math.pi/2,0,0))
        group('70_Set_Dressing');beam('Z_Counter_Line',(-1.6,2.6,.9),(1.6,2.6,.9),.04,'teal');beam('Z_Counter_Line',(1.6,2.6,.9),(-1.6,.8,.9),.04,'teal');beam('Z_Counter_Line',(-1.6,.8,.9),(1.6,.8,.9),.04,'teal')
    elif key=='school':
        redo(1);z=table('Locus_01_Welcome_Desk',-4.3,-4.8,2.4,1,1,'teal',True);plant('Welcome_Flower',-4.9,-4.8,z,True,.5);cards('Welcome_Card',-3.9,-4.8,z,1)
        redo(2);z=table('Locus_02_Roll_Call',-5.1,2.5,2.8,1.2,.9,'oak',True);cards('Name_Cards',-5.1,2.5,z,2.4)
        bpy.data.objects['SG_MEMORY_02'].location=(-4.8,1.2,0)
        redo(3);shelf('Locus_03_Library_Island',0,1.7,3,2,'books',1.35);rug('Library_Rug',(0,1.4),(4.2,3),'mint')
        redo(4);shelf('Locus_04_Equipment',5,1.25,2.7,2,'none',1.7)
        for x,c in [(4.2,'yellow'),(5,'orange'),(5.8,'blue')]:ball('School_Ball',(x,1.25,.55),(.27,)*3,c)
        redo(5);window('Locus_05_Canteen_Display',2.8,6.7,1.8,2,1.4);text('Lunch_Display_Label','LUNCH TODAY',(2.8,6.51,1.9),.20,'teal')
        bpy.data.objects['SG_MEMORY_05'].location=(2.8,5.15,0)
        for ob in bpy.context.scene.objects:
            if ob.name.startswith('Shop_Title'):ob.location.z+=.92
        bpy.data.objects['Rear_Wall'].scale.z=1.17;bpy.data.objects['Rear_Wall'].location.z=2.23
        bpy.data.objects['Rear_Crown'].location.z=4.49
        for ob in bpy.context.scene.objects:
            if ob.name.startswith('Back_Corner_Post'):ob.scale.z=1.16;ob.location.z=2.23
    elif key=='classroom':
        redo(1);z=table('Locus_01_Name_Plates',-4.3,-4.8,2.4,1,.8);cards('Class_Names',-4.3,-4.8,z)
        redo(4);shelf('Locus_04_Props_Cabinet',5,1.25,2.8,2,'none',1.85)
        hat('Class_Prop_Hat',4.4,1.25,.3,.45,'teal');jar('Class_Prop_Jar',5.3,1.25,.3,.24,'rose');parcel('Class_Prop_Parcel',5.7,1.25,1.3,.6,'paper')
        group('12_Locus_02');window('Reading_Window',-5.2,3,2.2,2.5,1.5)
    elif key=='canteen':
        redo(3);remove_prefix('SG_COLLIDER_Dining_Rear_Bench');z=table('Locus_03_Serving_Window',0,1.7,3.4,1.4,1.05,'teal',True)
        for x in [-1,0,1]:cyl('Serving_Pot',(x,1.7,z+.22),.32,.4,'metal');cyl('Serving_Lid',(x,1.7,z+.44),.35,.05,'metal')
        for x in [-1.8,1.8]:beam('Serving_Window_Frame',(x,2.25,0),(x,2.25,2.7),.07,'oak')
        beam('Serving_Window_Header',(-1.8,2.25,2.7),(1.8,2.25,2.7),.08,'oak');text('Serving_Greeting','Enjoy your lunch!',(0,2.22,2.5),.25,'teal')
        redo(4);z=table('Locus_04_Shared_Dining',5,1.25,2.9,1.5,.85)
        for x in [4.2,5,5.8]:cyl('Lunch_Plate',(x,1.25,z+.04),.28,.04,'ivory');apple('Lunch_Fruit',x,1.25,z+.2,.15)
        bench('Lunch_Bench',5,2.55,2.8,'teal',False)
    elif key=='playground':
        redo(4);remove_prefix('SG_COLLIDER_Slide','Hopscotch','Court_Sideline','Court_Crossline')
        for j in range(6):box('Locus_04_Hopscotch',(5.0+(j%2)*.35,.0+j*.6,.025),(.7,.55,.05),['rose','yellow','blue'][j%3]);text('Hop_Number',str(j+1),(5+(j%2)*.35,j*.6,.06),.25,'ivory','up')
        if 'SG_FLOOR_Court' in bpy.data.objects:bpy.data.objects['SG_FLOOR_Court'].data.materials.clear();bpy.data.objects['SG_FLOOR_Court'].data.materials.append(m.M['grass'])
        for rr in [3.4,3.7,4]:
            ob=ring('Running_Track',(0,1.5,.055),rr,.035,'ivory');ob.scale.x=1.38
        group('13_Locus_03');ring('Cooperative_Game_Circle',(0,1.5,.06),1.8,.06,'yellow')
        redo(5);picture_wall('Locus_05_Activity_Photos',5.2,-5.15,'OUR HAPPY DAYS')
    elif key=='home':
        group('11_Locus_01');basket('Locus_01_Everyday_Basket',-4.3,-4.8,.9,False)
        # Bed remains an independent rest interaction in the rear nook, not MEMORY_04.
        bed_objs=list(bpy.data.collections['14_Locus_04'].objects)
        for ob in bed_objs:ob.location.y+=2.5
        bpy.data.objects['SG_COLLIDER_Bed'].location.y+=2.5
        bpy.data.objects['SG_BED'].location=(3.15,3.8,0)
        group('14_Locus_04');z=table('Locus_04_Window_Desk',5,1.0,2.6,1.25,.95);box('Desk_Journal',(5,1,z+.04),(.9,.65,.08),'paper');jar('Pencil_Cup',5.8,1.2,z,.13,'teal')
        bpy.data.objects['SG_MEMORY_04']['associated_prop']='Locus_04_Window_Desk_Top'
        redo(3);z=table('Locus_03_Dining_Table',0,1.7,2.7,1.6,.9)
        remove_prefix('SG_COLLIDER_Sofa')
        for x in [-.7,.7]:cyl('Home_Plate',(x,1.7,z+.03),.3,.04,'ivory');jar('Home_Cup',x,2.2,z,.14,'teal')
        group('70_Set_Dressing');sofa('Home_Rear_Sofa',0,4.4)
    # Architecture refinements visible at normal gameplay distance.
    if key=='B':
        group('00_Architecture');box('U_Pier_Left',(-5.8,4.4,.025),(2.5,4.9,.05),'oak');box('U_Pier_Right',(6.8,4.4,.025),(1.5,4.9,.05),'oak')
        redo(5);remove_prefix('SG_COLLIDER_Cabin_Back')
        door('Locus_05_Cabin',6.8,5.45,'CABIN','teal')
        box('Cabin_Back_Wall',(6.8,6.55,1.45),(2.2,.18,2.9),'teal')
        for x in [5.75,7.85]:box('Cabin_Side',(x,6,1.1),(.16,1.2,2.2),'oak')
        box('Cabin_Rear_Roof',(6.8,6.35,3.0),(2.4,.75,.18),'wood')
        collider('Cabin_Back',(6.8,6.1,1.5),(2.3,1.5,3))
        bpy.data.objects['SG_MEMORY_05'].location=(6.8,4.75,0)
    if key=='C':
        group('70_Set_Dressing');z=table('Kitchen_Left_Return',-4.2,4.5,1.2,2.8,1,'cream',True);jar('Flour_On_Return',-4.2,4.5,z,.3,'paper')
        group('15_Locus_05')
        for x in [4.05,6.35]:beam('Pickup_Window_Post',(x,-5.45,0),(x,-5.45,2.65),.065,'teal')
        beam('Pickup_Window_Header',(4.05,-5.45,2.65),(6.35,-5.45,2.65),.08,'teal')
        text('Pickup_Window_Title','PICK UP',(5.2,-5.53,2.45),.23,'teal')
    if key=='E':
        redo(5);framed_window('Locus_05_Observation_Window',5.2,-5.15,'WATCH THEM GROW')
        ball('Chick_Body',(5.2,-5.4,1.55),(.24,.05,.27),'yellow');ball('Chick_Eye',(5.28,-5.47,1.63),(.03,)*3,'navy')
    floor_profile(key)
    # Whole-room proportion changes include anchors and proxies in the same transform.
    scales={'I':(.86,1.12),'T':(1.20,.88),'Q':(.92,1.12),'W':(1.16,.91),'X':(1.18,.88),'H':(1.08,.94),'Z':(1.12,.95)}
    if key in scales:
        sx,sy=scales[key]
        for ob in bpy.context.scene.objects:
            if ob.parent is None:
                ob.location.x*=sx;ob.location.y*=sy;ob.scale.x*=sx;ob.scale.y*=sy
        bpy.context.scene['plan_proportions']=[sx,sy]
    plan=json.loads((ROOT/'game/data/landmark_interiors.json').read_text(encoding='utf-8'))
    target=None
    for lm in plan['landmarks']:
        if lm['room_id']==('landmark_'+key if len(key)==1 else key):target=lm
        for area in lm.get('areas',[]):
            if area.get('separate_scene') and area['room_id']==key:target=area
    if not target:raise ValueError('Plan room not found '+key)
    for a in target['anchors']:
        ob=bpy.data.objects[a['node_name']];ob['label']=a['label'];ob['memory_id']=a['id'];ob['activity']=a.get('activity','')
    bpy.context.scene['plan_composition']=target.get('composition','')
    bpy.context.scene['plan_source']='game/data/landmark_interiors.json'
