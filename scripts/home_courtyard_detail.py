"""Original, editable garden detailing for the complete home exterior.

Call ``build_courtyard(m, helpers=None)`` after modeling.setup/floor and before
export. Blender Z up, front -Y, metres. No scene reset, floor, gameplay anchors,
interactive task roots, exports, downloads, or external textures are created.
The optional helpers argument is reserved for the parent builder.
"""
import math
import random


def _material(m, key, color, roughness=.78, metallic=0):
    if key in m.M:
        return
    import bpy
    mat = bpy.data.materials.new('MAT_' + key)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    mat.diffuse_color = (*color, 1)
    m.M[key] = mat


def _slab(m, name, points, bottom, top, mat, bevel=0):
    n = len(points)
    verts = [(x, y, bottom) for x, y in points] + [(x, y, top) for x, y in points]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces.extend((i, (i+1) % n, (i+1) % n+n, i+n) for i in range(n))
    return m.soften(m.mesh(name, verts, faces, mat), bevel)


def _paver(m, name, x, y, w, d, angle, rng, mat):
    # Six-sided cut stone: shallow depth, asymmetric corners, uninterrupted floor.
    corners = [(-w*.45, -d*.5), (w*.34, -d*.5), (w*.5, -d*.24),
               (w*.46, d*.46), (-w*.32, d*.5), (-w*.5, d*.24)]
    ca, sa = math.cos(angle), math.sin(angle)
    pts = [(x+ca*u-sa*v, y+sa*u+ca*v) for u, v in corners]
    return _slab(m, name, pts, .021, .048+rng.uniform(0, .006), mat, .018)


def _leafy_shrub(m, name, x, y, z=0, scale=1, flower=False, seed=0):
    """Closed pointed leaf geometry in two shared material batches, not spheres."""
    rng = random.Random(seed)
    batches = [([], []), ([], [])]
    for j in range(18):
        a = math.tau*j/11 + rng.uniform(-.24, .24)
        radius = (.12 if j < 7 else .32)*scale
        length = rng.uniform(.43, .75)*scale
        width = rng.uniform(.13, .23)*scale
        lift = rng.uniform(.27, .65)*scale
        ox, oy = x+math.sin(a)*radius, y+math.cos(a)*radius
        local = [(0, 0, 0), (width, length*.45, lift*.5), (0, length, lift),
                 (-width, length*.45, lift*.5), (0, length*.45, lift*.5+.06*scale),
                 (0, length*.45, lift*.5-.04*scale)]
        verts, faces = batches[j % 2]
        start = len(verts)
        ca, sa = math.cos(a), math.sin(a)
        verts.extend((ox+ca*u-sa*v, oy+sa*u+ca*v, z+.06+zz) for u, v, zz in local)
        for k in range(4):
            faces.append((start+k, start+(k+1) % 4, start+4))
            faces.append((start+(k+1) % 4, start+k, start+5))
    for k, (verts, faces) in enumerate(batches):
        m.mesh(name+'_Leaf_Sprays_'+str(k), verts, faces, 'garden_sage' if k else 'leaf')
    if flower:
        for j in range(4):
            a = j*2.3
            xx, yy = x+math.cos(a)*.28*scale, y+math.sin(a)*.28*scale
            zz = z+(.68+(j % 2)*.18)*scale
            m.beam(name+'_Stem', (xx, yy, z+.08), (xx, yy, zz), .018*scale, 'leaf')
            for p in range(5):
                b = p*math.tau/5
                ob = m.ball(name+'_Petal', (xx+math.cos(b)*.105*scale, yy+math.sin(b)*.105*scale, zz),
                           (.12*scale, .085*scale, .055*scale), ['rose','yellow','lavender','white'][j], 8, 4)
                ob.rotation_euler.z = b
            m.cyl(name+'_Flower_Heart', (xx, yy, zz+.045*scale), .048*scale, .035*scale, 'gold', 8)


def _tree(m, name, x, y, scale=1, fruit=False):
    rng = random.Random(name)
    m.cyl(name+'_Root_Flare', (x, y, .17), .43*scale, .34, 'wood', 9, top=.22*scale)
    m.beam(name+'_Curved_Trunk_Base', (x, y, .17), (x-.14*scale, y+.02, 1.55*scale), .19*scale, 'wood')
    m.beam(name+'_Curved_Trunk_Top', (x-.14*scale, y+.02, 1.55*scale), (x+.18*scale, y+.10, 3.05*scale), .12*scale, 'wood')
    for j, (dx, dy, dz) in enumerate([(-.9,.0,2.6),(.8,.35,2.9),(.1,-.7,3.2)]):
        m.beam(name+'_Branch', (x-.07, y, 1.65*scale), (x+dx*scale, y+dy*scale, dz*scale), .09*scale, 'oak')
    # Faceted broad crown masses have irregular silhouettes and no smooth ball shading.
    for j, (dx, dy, dz, s) in enumerate([(-.9,.1,3.0,1.1),(.85,.15,3.1,1.2),(-.2,-.65,3.35,1.0),
                                        (.1,.55,3.8,1.15),(-.65,.3,3.9,.85),(.7,-.45,4.0,.8)]):
        verts = [(0, 0, .9)]
        count = 7
        for zz, rr in [(.43,.8),(-.22,1),(-.65,.64)]:
            for k in range(count):
                a = math.tau*k/count + j*.27
                r = rr*rng.uniform(.88,1.11)
                verts.append((math.cos(a)*r, math.sin(a)*r*.88, zz+rng.uniform(-.07,.07)))
        verts.append((0,0,-.82))
        faces = [(0,1+k,1+(k+1)%count) for k in range(count)]
        for row in range(2):
            base=1+row*count
            faces.extend((base+k,base+count+k,base+count+(k+1)%count,base+(k+1)%count) for k in range(count))
        faces.extend((len(verts)-1,1+2*count+(k+1)%count,1+2*count+k) for k in range(count))
        ob=m.mesh(name+'_Canopy_'+str(j),verts,faces,['garden_sage','leaflight','leaf'][j%3])
        ob.location=(x+dx*scale,y+dy*scale,dz*scale)
        ob.scale=(s*scale,s*scale,s*scale)
    if fruit:
        for dx,dy,dz in [(-1.2,-.6,2.9),(.7,-.85,3.25),(-.1,-1.3,3.3),(.3,-.3,4.35)]:
            m.apple(name+'_Apple',x+dx*scale,y+dy*scale,dz*scale,.16*scale)
    m.collider(name+'_Trunk',(x,y,1.35*scale),(.65*scale,.65*scale,2.7*scale))


def _fence_panel(m, name, a, b, height=.80):
    x1,y1=a; x2,y2=b
    w=math.hypot(x2-x1,y2-y1)
    angle=math.atan2(y2-y1,x2-x1)
    center=((x1+x2)/2,(y1+y2)/2)
    for label,z,size,mat in [('Wall',height/2,(w,.30,height),'cream'),
                              ('Plinth',.11,(w,.39,.22),'garden_stone'),
                              ('Coping',height+.045,(w+.06,.43,.12),'ivory')]:
        ob=m.box(name+'_'+label,(*center,z),size,mat,.035)
        ob.rotation_euler.z=angle
    # Simple masonry divisions are legible without busy pseudo-textures.
    for i in range(1,int(w/1.3)):
        t=i/int(w/1.3)
        ob=m.box(name+'_Masonry_Joint',(x1+(x2-x1)*t,y1+(y2-y1)*t-.155,height*.47),(.018,.012,height*.57),'garden_stone',0)
        ob.rotation_euler.z=angle


def _gate(m):
    for side in [-1,1]:
        x=side*1.85
        m.box('Garden_Gate_Pier',(x,-15.25,.82),(.62,.62,1.64),'cream',.05)
        m.box('Garden_Gate_Pier_Base',(x,-15.25,.15),(.76,.76,.30),'garden_stone',.04)
        m.box('Garden_Gate_Pier_Cap',(x,-15.25,1.66),(.78,.78,.18),'ivory',.05)
        m.cyl('Garden_Gate_Lamp_Base',(x,-15.25,1.82),.16,.13,'garden_iron',12)
        m.box('Garden_Gate_Lantern',(x,-15.25,2.02),(.28,.28,.37),'paper',.04)
        for dx in [-.16,.16]:
            for dy in [-.16,.16]:m.beam('Garden_Lantern_Frame',(x+dx,-15.25+dy,1.83),(x+dx,-15.25+dy,2.22),.018,'garden_iron')
        m.box('Garden_Gate_Lantern_Cap',(x,-15.25,2.25),(.40,.40,.10),'garden_iron',.04)
        m.collider('Garden_Gate_Pier_'+str(side),(x,-15.25,.9),(.70,.70,1.8))
        # Two open leaves lie alongside the path, leaving a 3 m clear opening.
        xx=side*1.85
        for z in [.28,1.27]:m.beam('Open_Garden_Gate_Rail',(xx,-14.95,z),(xx,-13.65,z),.045,'garden_iron')
        for i in range(6):
            yy=-14.95+i*.26
            m.beam('Open_Garden_Gate_Picket',(xx,yy,.23),(xx,yy,1.30),.026,'garden_iron')
            m.ball('Garden_Gate_Finial',(xx,yy,1.33),(.055,.055,.09),'gold',8,4)
        for yy in [-14.60,-14.06]:
            m.ring('Garden_Gate_Scroll',(xx,yy,.79),.20,.025,'garden_iron',(0,math.pi/2,0),segments=20)
        m.collider('Garden_Open_Gate_'+str(side),(xx,-14.30,.70),(.14,1.40,1.40))


def _mail_corner(m):
    x,y=-11.55,-11.85
    m.box('Mailbox_Stone_Shoe',(x,y,.10),(.60,.57,.20),'garden_stone',.05)
    m.box('Mailbox_Carved_Post',(x,y,.67),(.20,.20,1.22),'wood',.03)
    m.box('Mailbox_Support_Bracket',(x+.17,y,1.12),(.56,.12,.14),'oak',.03)
    m.box('Mailbox_House_Body',(x,y,1.53),(1.10,.67,.68),'teal',.06)
    for dx in [-.43,-.21,0,.21,.43]:m.box('Mailbox_Wood_Grain',(x+dx,y-.346,1.53),(.018,.016,.52),'mint',.006)
    for side in [-1,1]:
        ob=m.box('Mailbox_Pitched_Roof',(x+side*.30,y,1.97),(.67,.85,.10),'wood',.025)
        ob.rotation_euler.y=side*.35
    m.box('Mailbox_Slot',(x,y-.354,1.66),(.53,.024,.065),'darkwood',.012)
    m.box('Mailbox_Address_Plate',(x,y-.37,1.37),(.59,.035,.19),'paper',.02)
    m.text('Mailbox_Address','HOME',(x,y-.397,1.37),.12,'teal')
    m.beam('Mailbox_Flag_Post',(x+.57,y,1.58),(x+.57,y,2.04),.028,'gold')
    m.box('Mailbox_Flag',(x+.72,y,2.02),(.32,.06,.18),'rose',.025)
    m.collider('Mailbox',(x,y,.95),(1.18,.82,1.9))
    m.table('Welcome_Letter_Table',-10,-11.73,1.80,.83,.91,'lightwood')
    for dx in [-.58,-.29,0,.29,.58]:m.box('Welcome_Table_Slat',(-10+dx,-11.73,1.009),(.018,.73,.012),'oak',0)
    m.box('Welcome_Letter_Envelope',(-10,-11.66,1.04),(.61,.40,.035),'paper',.02)
    m.beam('Welcome_Envelope_Fold',(-10.29,-11.85,1.065),(-10,-11.66,1.065),.009,'oak')
    m.beam('Welcome_Envelope_Fold',(-9.71,-11.85,1.065),(-10,-11.66,1.065),.009,'oak')
    m.cyl('Welcome_Envelope_Seal',(-10,-11.66,1.079),.055,.015,'rose',12)
    m.plant('Welcome_Table_Herb',-10.62,-11.75,1.02,False,.30)
    m.basket('Welcome_Parcel_Basket',-9.10,-12.12,0,False)


def _day_board(m):
    x,y=2,-11.82
    for dx in [-1.0,1.0]:
        m.box('Family_Day_Post',(x+dx,y,.93),(.14,.17,1.86),'wood',.025)
        m.box('Family_Day_Post_Shoe',(x+dx,y,.10),(.30,.33,.20),'garden_stone',.03)
    m.box('Family_Day_Frame',(x,y,1.52),(2.65,.19,1.26),'oak',.06)
    m.box('Family_Day_Cork',(x,y-.117,1.52),(2.40,.045,1.03),'teal',.02)
    m.text('Family_Day_Title','OUR DAY',(x,y-.153,1.85),.21,'ivory')
    for i,(label,color) in enumerate([('PLAY','yellow'),('HELP','rose'),('REST','mint')]):
        xx=x+(i-1)*.73
        m.box('Family_Plan_Card',(xx,y-.157,1.39),(.60,.035,.50),'paper',.02)
        m.ball('Family_Plan_Pin',(xx,y-.187,1.60),(.035,.025,.035),color,8,4)
        m.text('Family_Plan_Label',label,(xx,y-.183,1.26),.105,'teal')
        m.cyl('Family_Plan_Icon',(xx,y-.188,1.44),.10,.025,color,8).rotation_euler.x=math.pi/2
    m.box('Family_Day_Rain_Cap',(x,y,2.20),(2.87,.43,.13),'garden_roof',.04)
    m.collider('Family_Day_Board',(x,y,1.0),(2.87,.43,2.0))


def _flower_bed(m):
    x,y=8.65,-11.85
    m.box('Kitchen_Garden_Base',(x,y,.17),(3.12,1.16,.34),'garden_stone',.06)
    m.box('Kitchen_Garden_Soil',(x,y,.40),(2.88,.94,.20),'soil',.03)
    for yy in [y-.57,y+.57]:
        m.box('Flower_Bed_Wood_Rim',(x,yy,.44),(3.20,.12,.25),'oak',.025)
        m.box('Flower_Bed_Rim_Cap',(x,yy,.58),(3.30,.19,.09),'lightwood',.025)
    for xx in [x-1.54,x+1.54]:m.box('Flower_Bed_End',(xx,y,.44),(.12,1.15,.25),'oak',.025)
    for j,xx in enumerate([7.50,8.15,8.80,9.50]):
        _leafy_shrub(m,'Flower_Bed_Plant_'+str(j),xx,y,.50,.63,True,30+j)
    m.collider('Flower_Bed',(x,y,.45),(3.30,1.30,.90))
    # Fixed task watering can expects a support top at z=.8.
    m.table('Watering_Can_Stand',6.5,-11.8,.72,.70,.71,'lightwood')
    for xx in [6.20,6.80]:m.box('Watering_Stand_Rail',(xx,-11.8,.35),(.08,.66,.09),'oak',.02)


def _rest_corner(m):
    x,y=11.5,-8.8
    for yy in [y-.25,y,y+.25]:m.box('Porch_Bench_Seat_Slat',(x,yy,.62),(2.82,.22,.12),'lightwood',.035)
    for dx in [-1.20,1.20]:
        m.box('Porch_Bench_Leg',(x+dx,y,.30),(.17,.65,.60),'garden_iron',.035)
        m.box('Porch_Bench_Back_Post',(x+dx,y+.29,1.02),(.12,.13,1.08),'garden_iron',.025)
        m.box('Porch_Bench_Arm',(x+dx,y,.94),(.18,.80,.11),'oak',.035)
    for z in [1.06,1.33]:m.box('Porch_Bench_Back_Slat',(x,y+.32,z),(2.82,.12,.22),'lightwood',.035)
    m.pillow('Porch_Reading_Cushion',10.68,y+.10,.80,'rose',(.60,.48,.22))
    m.box('Porch_Story_Book',(11.80,y-.05,.72),(.49,.33,.08),'teal',.02)
    m.box('Porch_Book_Pages',(11.80,y-.052,.73),(.42,.34,.04),'paper',.006)
    m.collider('Porch_Rest_Bench',(x,y,.68),(2.96,.82,1.36))
    m.cyl('Porch_Tea_Table_Top',(13.40,-8.90,.72),.48,.12,'lightwood',20)
    m.cyl('Porch_Tea_Table_Foot',(13.40,-8.90,.35),.10,.68,'garden_iron',10)
    m.cyl('Porch_Tea_Cup',(13.40,-8.90,.87),.105,.18,'ivory',16)
    m.ring('Porch_Tea_Cup_Handle',(13.54,-8.90,.88),.08,.018,'ivory',(math.pi/2,0,0),segments=16)
    m.collider('Porch_Tea_Table',(13.40,-8.90,.40),(.96,.96,.80))


def build_courtyard(m, helpers=None):
    """Author courtyard detail; return a plain coordinate/clearance summary."""
    _material(m,'garden_stone',(.64,.60,.48))
    _material(m,'garden_paver',(.79,.73,.58))
    _material(m,'garden_paver_light',(.87,.81,.66))
    _material(m,'garden_gravel',(.66,.62,.48))
    _material(m,'garden_sage',(.34,.49,.24))
    _material(m,'garden_iron',(.075,.17,.17),.48,.35)
    _material(m,'garden_roof',(.17,.38,.36))
    rng=random.Random(261024)
    m.group('30_Courtyard_Paving')
    # Broad cross-court path connects all five memory anchors.
    m.box('Garden_Cross_Path_Bedding',(.1,-10.2,.012),(25.7,2.15,.024),'garden_gravel',.18)
    for row in range(3):
        for col in range(34):
            xx=-12.2+col*.74+(row%2)*.30
            yy=-10.80+row*.60
            _paver(m,'Cross_Path_Cut_Stone',xx,yy,.70,.55,rng.uniform(-.025,.025),rng,
                   'garden_paver_light' if (row+col)%4==0 else 'garden_paver')
    # A slow left curve leads to the front door. Cubic samples avoid abrupt kinks.
    curve=[]
    for i in range(22):
        t=i/21
        xx=-3.5*(3*t*t-2*t*t*t)
        yy=-15.25+7.50*t
        dx=-3.5*(6*t-6*t*t);dy=7.50
        norm=math.hypot(dx,dy)
        curve.append((xx,yy,dy/norm,-dx/norm))
    points=[(x+nx*1.26,y+ny*1.26) for x,y,nx,ny in curve]
    points += [(x-nx*1.26,y-ny*1.26) for x,y,nx,ny in reversed(curve)]
    _slab(m,'Curving_Entry_Path',points,.004,.020,'garden_gravel')
    for i,(x,y,nx,ny) in enumerate(curve):
        if i%2==0:
            for side in [-1,1]:
                _paver(m,'Entry_Path_Edge',x+nx*1.20*side,y+ny*1.20*side,.25,.55,
                       math.atan2(ny,nx),rng,'garden_stone')
        for j in [-1,0,1]:
            px,py=x+nx*j*.66,y+ny*j*.66
            # Existing cross-path stones carry this intersection without z-fighting.
            if -11.15<py<-9.20 and -12.7<px<12.95:
                continue
            _paver(m,'Entry_Path_Cut_Stone',px,py,.62,.32,math.atan2(ny,nx),rng,
                   'garden_paver_light' if (i+j)%3==0 else 'garden_paver')
    # Porch and resting nook in a separate warm paving language.
    m.box('Porch_Rest_Paving',(11.9,-8.55,.018),(5.60,1.80,.036),'garden_gravel',.10)
    for j in range(2):
        for i in range(7):_paver(m,'Porch_Rest_Paver',9.55+i*.76,-9.0+j*.72,.72,.68,0,rng,'garden_paver')

    m.group('31_Courtyard_Enclosure')
    for a,b in [((-16.2,-15.25),(-2.22,-15.25)),((2.22,-15.25),(16.2,-15.25)),
                ((-16.2,-15.25),(-16.2,15.3)),((16.2,-15.25),(16.2,15.3)),
                ((-16.2,15.3),(16.2,15.3))]:
        _fence_panel(m,'Garden_Boundary',a,b,.72)
    for side in [-1,1]:
        for yy in [-15.25,-7.4,1.0,9.0,15.3]:
            m.box('Garden_Perimeter_Pier',(side*16.2,yy,.55),(.50,.50,1.10),'cream',.04)
            m.box('Garden_Perimeter_Pier_Cap',(side*16.2,yy,1.13),(.65,.65,.12),'ivory',.04)
        m.collider('Garden_Side_Boundary_'+str(side),(side*16.2,0,1),(.48,31.2,2))
    m.collider('Garden_Back_Boundary',(0,15.3,1),(32.8,.48,2))
    m.collider('Garden_Front_Left',(-9.21,-15.25,1),(13.98,.48,2))
    m.collider('Garden_Front_Right',(9.21,-15.25,1),(13.98,.48,2))
    _gate(m)

    m.group('32_Courtyard_Living_Objects')
    _mail_corner(m)
    _day_board(m)
    _flower_bed(m)
    _rest_corner(m)
    # Tool nook sits against the left facade, clear of the letter interaction lane.
    m.box('Garden_Tool_Crate',(-13.4,-8.25,.26),(1.05,.66,.52),'oak',.04)
    for dx in [-.35,0,.35]:m.box('Tool_Crate_Slat',(-13.4+dx,-8.60,.27),(.24,.08,.48),'lightwood',.02)
    for i in range(2):
        xx=-13.7+i*.54
        m.beam('Garden_Tool_Handle',(xx,-8.22,.20),(xx+.18,-8.10,1.65),.035,'wood')
        m.box('Garden_Tool_Spade',(xx+.20,-8.10,1.73),(.27,.07,.35),'metal',.04)
    m.plant('Tool_Nook_Terracotta',-14.55,-8.45,0,False,.62)
    m.collider('Tool_Crate',(-13.4,-8.25,.40),(1.10,.72,.80))

    m.group('33_Courtyard_Layered_Planting')
    # Low front beds frame the open gate; nothing occupies the broad transverse path.
    for x,y,w,d in [(-8.7,-14.05,11.4,1.45),(8.8,-14.05,11.7,1.45),
                    (-15.0,-10.9,1.45,5.7),(15.0,-11.0,1.35,5.6)]:
        m.box('Garden_Mulch_Bed',(x,y,.012),(w,d,.025),'soil',.20)
        if w>d:
            for k in range(int(w/.55)):
                m.box('Garden_Bed_Edging',(x-w/2+.30+k*.55,y+.71,.075),(.50,.13,.15),'garden_stone',.04)
    for j,x in enumerate([-13.9,-12.5,-11.2,-9.8,-8.5,-7.2,-5.8,-4.5,4.1,5.4,6.8,8.1,9.4,10.8,12.1,13.4]):
        _leafy_shrub(m,'Front_Border_Shrub_'+str(j),x,-14.10+(j%3)*.13,.04,.76+(j%2)*.18,j%3==0,200+j)
    for j,(x,y) in enumerate([(-15.10,-9.4),(-15.10,-10.9),(-15.0,-13.1),(15.0,-12.8),(15.0,-9.2),
                               (-8.8,-8.25),(5.0,-8.25),(6.4,-8.25),(7.8,-8.25)]):
        _leafy_shrub(m,'Facade_Leaf_Cluster_'+str(j),x,y,.03,.85,j%2==0,400+j)
    _tree(m,'West_Apple_Tree',-14.0,-12.1,.96,True)
    _tree(m,'East_Shade_Tree',14.1,-10.0,1.0,False)
    # Nested tree rings and irregular low stones give the trunks a planted base.
    for x,y in [(-14,-12.1),(14.1,-10.0)]:
        m.cyl('Tree_Mulch_Ring',(x,y,.025),.82,.045,'soil',16)
        for k in range(10):
            a=k*math.tau/10
            _paver(m,'Tree_Ring_Stone',x+math.cos(a)*.87,y+math.sin(a)*.87,.28,.20,a,rng,'garden_stone')
    m.group('40_Furniture')
    return {'module':'home_courtyard_detail','coordinates':'Blender Z up; front -Y; metres',
            'entry_clear_width':3.0,'cross_path_center_y':-10.2,'cross_path_width':2.15,
            'front_door_approach':[-3.5,-8.7],'watering_support_top':.80,
            'static_only':True,'provenance':'Original procedural Blender geometry; existing palette; no external assets'}
