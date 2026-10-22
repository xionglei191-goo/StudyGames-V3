"""Build an editable northern school campus in the current alphabet-island scene.
Stages: setup(), terrace(), building(), campus(), paths_and_anchors(), finish().
Run once on a copy of v03 with studygame_world loaded. No story/quest content.
"""
import bpy,bmesh,math,json,random
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import studygame_world as w

BASE=Path(__file__).resolve().parent
ORIGIN=Vector((0,54.2,10.35))
R=random.Random(260421)
M={};GROUP='School_Building';TREE=None
RECORD={'origin':list(ORIGIN),'front_axis':'-Y','purpose':'World-map asset; no story or gameplay implementation','cleared_objects':[]}

def xyz(p):return tuple(ORIGIN+Vector(p))
def box(name,p,size,mat='cream',roundness=.06,group=None):return w.box('School_'+name,xyz(p),size,M[mat],group or GROUP,roundness)
def ball(name,p,size,mat='leaf',group=None):return w.ball('School_'+name,xyz(p),size,M[mat],group or GROUP)
def cyl(name,p,r,h,mat='wood',n=24,top=None,group=None):return w.cylinder('School_'+name,xyz(p),r,h,M[mat],group or GROUP,n,top)
def beam(name,a,b,width,mat='wood',group=None):return w.beam('School_'+name,xyz(a),xyz(b),width,M[mat],group or GROUP)

def setup():
    global TREE
    if bpy.data.collections.get('ALPHA_School_Building'):raise RuntimeError('School already exists; edit the delivered campus instead of duplicating it.')
    for group in ['School_Building','School_Campus','School_Paths']:
        c=bpy.data.collections.new('ALPHA_'+group);w.SCENE.collection.children.link(c);w.COLLS[group]=c
    colors={'cream':(.82,.67,.40),'trim':(.92,.83,.61),'teal':(.045,.29,.28),'roof_dark':(.035,.19,.18),'brick':(.48,.20,.095),'stone':(.42,.42,.32),'wood':(.39,.20,.075),'wood_light':(.66,.42,.19),'glass':(.16,.43,.48),'dark':(.09,.16,.17),'metal':(.68,.49,.16),'white':(.9,.85,.66),'court':(.21,.37,.29),'court_outer':(.54,.27,.16),'paving':(.53,.48,.34),'soil':(.26,.16,.07),'leaf':(.10,.30,.075),'leaf_light':(.25,.43,.10),'pink':(.76,.19,.27),'yellow':(.87,.62,.14),'blue':(.07,.30,.59)}
    for key,rgb in colors.items():M[key]=w.make_material('SCHOOL_'+key,rgb,.72 if key!='glass' else .25)
    M['path']=w.make_material('SCHOOL_Path',(.43,.29,.14),.76)
    TREE=BVHTree.FromObject(bpy.data.objects['ALPHA_Island_Continuous_Terrain'],bpy.context.evaluated_depsgraph_get())
    w.SCENE['output_version']='v04';w.SCENE['school_site']='Northern ridge, separate from home and the A-Z index'
    print({'school_initialized':True,'position':list(ORIGIN)})

def ground(x,y):
    co,*_=TREE.ray_cast(Vector((x,y,80)),Vector((0,0,-1)),150)
    return co.z if co else w.height(x,y)

def clear(o):
    if not o.get('school_site_clearance'):
        o['school_site_clearance']=True;o.hide_render=True;o.hide_set(True);RECORD['cleared_objects'].append(o.name)

def terrace():
    global TREE
    terrain=bpy.data.objects['ALPHA_Island_Continuous_Terrain']
    bm=bmesh.new();bm.from_mesh(terrain.data)
    edges=[e for e in bm.edges if all(-21<v.co.x<11 and 46<v.co.y<62 for v in e.verts)]
    bmesh.ops.subdivide_edges(bm,edges=edges,cuts=1,use_grid_fill=True)
    for v in bm.verts:
        x,y,z=v.co
        dx=max(-18.6-x,0,x-8.7);dy=max(48.1-y,0,y-59.5)
        d=math.hypot(dx,dy)
        if d<2.1:
            t=1-w.smooth(0,2.1,d);v.co.z=z+(ORIGIN.z-.08-z)*t
    bm.to_mesh(terrain.data);bm.free();terrain.data.update()
    for f in terrain.data.polygons:f.use_smooth=True
    attr=terrain.data.color_attributes.get('Terrain_Color')
    if attr:
        for i,v in enumerate(terrain.data.vertices):
            if -19<v.co.x<9 and 48<v.co.y<59:attr.data[i].color=(.28,.44,.12,1)
    bpy.context.view_layer.update();TREE=BVHTree.FromObject(terrain,bpy.context.evaluated_depsgraph_get())
    # Relieve only vegetation/rocks inside the new campus; existing landmarks stay fixed.
    prefixes=[]
    for trunk in w.COLLS['Forest'].objects:
        if '_Trunk' in trunk.name and -20<trunk.location.x<10 and 47<trunk.location.y<60:
            prefixes.append(trunk.name.rsplit('_Trunk',1)[0])
    for c in [w.COLLS['Forest'],w.COLLS['Polish_v03']]:
        for o in c.objects:
            if any(o.name.startswith(pre+'_') or o.get('tree_source')==pre for pre in prefixes):clear(o)
    for o in w.COLLS['Terrain'].objects:
        if 'Coastal_Boulder' in o.name and -20<o.location.x<10 and 47<o.location.y<60:clear(o)
    # Batched meadow polygons underneath paving are trimmed from the map copy.
    for name in ['ALPHA_V3_Meadow_Grass_Clumps','ALPHA_V3_Wildflower_Patches']:
        o=bpy.data.objects.get(name)
        if o:
            bm=bmesh.new();bm.from_mesh(o.data)
            fs=[f for f in bm.faces if -19<f.calc_center_median().x<9 and 47.8<f.calc_center_median().y<59]
            context=[i.identifier for i in bpy.ops.mesh.delete.get_rna_type().properties['type'].enum_items]
            # bmesh has its own documented context string; not an RNA enum.
            bmesh.ops.delete(bm,geom=fs,context='FACES');bm.to_mesh(o.data);bm.free()
    RECORD['removed_tree_positions']=prefixes
    print({'campus_terrace':[-18.6,48.1,8.7,58.7],'cleared_trees':len(prefixes)})

def roof(name,cx,cy,width,depth,eave,rise):
    x0,x1=cx-width/2,cx+width/2;y0,y1=cy-depth/2,cy+depth/2
    vs=[xyz(v) for v in [(x0,y0,eave),(x1,y0,eave),(x0,cy,eave+rise),(x1,cy,eave+rise),(x0,y1,eave),(x1,y1,eave)]]
    obj=w.mesh('School_'+name,vs,[(0,1,3,2),(2,3,5,4),(0,2,4),(1,5,3),(0,4,5,1)],M['teal'],GROUP);w.bevel(obj,.05)
    # Joined tile mesh with slight relief and color variation.
    verts=[];faces=[];cols=[];nx=max(4,round(width/.48));ny=7
    for side in [-1,1]:
        for row in range(ny):
            d0=(depth/2)*row/ny;length=depth/2/ny+.065
            for col in range(nx):
                xx=x0+(col+.5)*width/nx;start=len(verts);factor=R.uniform(.87,1.12)
                for d in [d0,min(depth/2-.01,d0+length)]:
                    for k in range(6):
                        t=k/5;bulge=.045*math.sin(t*math.pi)
                        verts.append(xyz((xx+(t-.5)*width/nx*.97,cy+side*(depth/2-d),eave+rise*(d/(depth/2))+.035+bulge)))
                        cols.append((.045*factor,.29*factor,.28*factor,1))
                faces.extend((start+k,start+k+1,start+k+7,start+k+6) for k in range(5))
    mat=w.make_material('SCHOOL_Tile_Color',(.05,.3,.28))
    node=mat.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='School_Color'
    bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs['Base Color'])
    ob=w.mesh('School_'+name+'_Tiles',verts,faces,mat,GROUP)
    ob.data.color_attributes.new(name='School_Color',type='FLOAT_COLOR',domain='POINT')
    for a,c in zip(ob.data.color_attributes['School_Color'].data,cols):a.color=c
    beam(name+'_Ridge',(x0-.04,cy,eave+rise+.05),(x1+.04,cy,eave+rise+.05),.17,'roof_dark')
    for yy in [y0,y1]:beam(name+'_Eave',(x0,yy,eave),(x1,yy,eave),.16,'trim')

def window(name,x,y,z,width=1.45,height=2):
    w.arch_panel('School_'+name+'_Frame',ORIGIN.x+x,ORIGIN.y+y,ORIGIN.z+z,width,height,.20,M['trim'],GROUP)
    w.arch_panel('School_'+name+'_Glass',ORIGIN.x+x,ORIGIN.y+y-.115,ORIGIN.z+z+.12,width-.24,height-.24,.08,M['glass'],GROUP)
    box(name+'_Mullion',(x,y-.19,z+height*.48),(.08,.08,height-.3),'trim',.015)
    box(name+'_Crossbar',(x,y-.2,z+height*.47),(width-.23,.08,.09),'trim',.015)
    box(name+'_Sill',(x,y-.12,z-.04),(width+.24,.45,.15),'stone')

def text_mesh(name,text,loc,size,mat='trim'):
    data=bpy.data.curves.new('School_'+name,'FONT');data.body=text;data.size=size;data.extrude=.022;data.bevel_depth=.005
    w.enum_set(data,'align_x','CENTER');data.materials.append(M[mat])
    obj=w.link('School_'+name,data,GROUP);obj.location=xyz(loc);obj.rotation_euler.x=math.pi/2
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    values=[i.identifier for i in bpy.ops.object.convert.get_rna_type().properties['target'].enum_items];assert 'MESH' in values
    bpy.ops.object.convert(target='MESH');return bpy.context.view_layer.objects.active

def building():
    box('Main_Foundation',(0,0,.16),(12.1,6.45,.32),'stone')
    box('Main_Walls',(0,0,2.31),(11.6,5.85,4.1),'cream',.12)
    box('Lower_Brick_Band',(0,0,.54),(11.72,5.97,.47),'brick')
    box('Upper_Cornice',(0,0,4.24),(11.95,6.18,.20),'trim')
    roof('Main_Roof',0,0,12.6,7.0,4.38,2.12)
    for x in [-4.55,-2.55,2.55,4.55]:window('Classroom_Window',x,-2.96,1.25,1.42,2.26)
    for x in [-5.55,5.55]:box('Corner_Trim',(x,-3.02,2.25),(.20,.24,3.9),'trim')
    for x in [-4.4,-2.2,0,2.2,4.4]:
        ob=box('Rear_Window',(x,2.96,2.35),(1.37,.12,1.85),'glass')
        for dx in [-.74,.74]:box('Rear_Window_Frame',(x+dx,3.03,2.35),(.1,.1,2.05),'trim')
        for zz in [1.34,3.36]:box('Rear_Window_Frame',(x,3.03,zz),(1.58,.1,.10),'trim')
        box('Rear_Window_Bar',(x,3.05,2.35),(1.5,.1,.10),'trim')
    # A projecting entrance tower gives the school a distinct silhouette.
    box('Entrance_Tower',(0,-3.0,3.75),(2.85,2.65,7.2),'cream',.12)
    box('Tower_Base',(0,-3.0,.31),(3.1,2.9,.55),'brick')
    box('Tower_Cornice',(0,-3.0,7.33),(3.17,2.95,.25),'trim')
    roof('Tower_Roof',0,-3.0,3.75,3.7,7.46,1.15)
    w.arch_panel('School_Entrance_Frame',ORIGIN.x,ORIGIN.y-4.39,ORIGIN.z+.36,2.25,3.02,.27,M['trim'],GROUP)
    w.arch_panel('School_Entrance_Door',ORIGIN.x,ORIGIN.y-4.56,ORIGIN.z+.45,1.93,2.70,.12,M['wood'],GROUP)
    box('Door_Divider',(0,-4.64,1.65),(.06,.08,2.3),'wood_light',.01)
    for x in [-.45,.45]:
        box('Door_Glass',(x,-4.65,2.04),(.60,.06,1.22),'glass')
        ball('Door_Handle',(x*.33,-4.72,1.33),(.07,.05,.08),'metal')
    box('Entry_Step',(0,-4.78,.14),(3.2,.8,.28),'stone')
    # Clock face lies in the front XZ plane.
    clock=cyl('Clock_Face',(0,-4.38,5.80),.88,.13,'white',64);clock.rotation_euler.x=math.pi/2
    rim=cyl('Clock_Rim',(0,-4.32,5.80),1.01,.09,'metal',64);rim.rotation_euler.x=math.pi/2
    for i in range(12):
        a=i*math.tau/12;dot=box('Clock_Mark',(.73*math.sin(a),-4.48,5.8+.73*math.cos(a)),(.065,.045,.14),'dark',.01);dot.rotation_euler.y=a
    beam('Clock_Hand_Hour',(0,-4.51,5.8),(-.43,-4.51,6.04),.07,'dark')
    beam('Clock_Hand_Minute',(0,-4.53,5.8),(0,-4.53,6.43),.055,'dark')
    ball('Clock_Pin',(0,-4.56,5.8),(.1,.06,.1),'metal')
    text_mesh('Facade_Name','SCHOOL',(0,-4.39,3.79),.43)
    # Two side wings and their entry markers remain separate editable meshes.
    for name,cx,color in [('Library',-7.0,'brick'),('Canteen',7.0,'cream')]:
        box(name+'_Foundation',(cx,.45,.15),(2.7,5.15,.3),'stone')
        box(name+'_Walls',(cx,.45,1.86),(2.5,4.9,3.35),color)
        roof(name+'_Roof',cx,.45,3.15,5.7,3.62,1.28)
        window(name+'_Window',cx,-2.04,1.05,1.65,2.05)
    # Small raised book emblem above the library window.
    for side in [-1,1]:
        ob=box('Library_Book_Emblem',(-7+side*.27,-2.18,3.18),(.55,.13,.48),'white',.03);ob.rotation_euler.y=side*.15
    # Canteen awning and service counter.
    box('Canteen_Awning',(7,-2.45,3.23),(2.65,.9,.18),'teal')
    box('Canteen_Counter',(7,-2.31,.95),(2.1,.65,.20),'wood_light')
    # Flower boxes and discrete vent details increase near-view readability.
    for x in [-4.55,-2.55,2.55,4.55]:
        box('Window_Box',(x,-3.18,1.06),(1.45,.47,.34),'wood')
        for j in range(5):
            xx=x-.52+j*.26;ball('Window_Leaf',(xx,-3.26,1.30),(.21,.20,.18),'leaf')
            ball('Window_Flower',(xx,-3.28,1.46),(.10,.11,.10),'yellow' if j%2 else 'pink')
    for x in [-3.6,3.6]:
        box('Roof_Vent',(x,1.45,6.0),(.45,.55,1.35),'brick');box('Roof_Vent_Cap',(x,1.45,6.69),(.65,.72,.17),'trim')
    print({'school_building_objects':len(w.COLLS[GROUP].objects)})

def line(name,points,width=.06,mat='white',z=.13):
    verts=[];faces=[]
    for i,p in enumerate(points):
        a=Vector(points[max(i-1,0)]);b=Vector(points[min(i+1,len(points)-1)]);d=b-a
        if d.length==0:d=Vector((1,0))
        d.normalize();n=Vector((-d.y,d.x))*width/2
        for v in [Vector(p)+n,Vector(p)-n]:verts.append(xyz((v.x,v.y,z)))
        if i:faces.append((2*i-2,2*i-1,2*i+1,2*i))
    return w.mesh('School_'+name,verts,faces,M[mat],'School_Campus')

def bench(name,x,y):
    for dx in [-.65,.65]:box(name+'_Leg',(x+dx,y,.29),(.14,.57,.58),'teal',group='School_Campus')
    for k in range(3):box(name+'_Seat',(x,y-.25+k*.25,.60),(1.75,.21,.13),'wood_light',group='School_Campus')
    box(name+'_Back',(x,y+.34,1.00),(1.75,.13,.64),'wood_light',group='School_Campus')

def campus():
    global GROUP
    GROUP='School_Campus'
    box('Courtyard_Base',(-4.9,-.2,-.005),(27.0,10.8,.12),'stone',.13)
    box('Forecourt',(-.1,-4.97,.055),(16.9,2.0,.10),'paving',.12)
    # Court and perimeter lines, scaled as a small playground rather than a regulation stadium.
    box('Playground_Outer',(-13.25,-.55,.065),(9.3,8.4,.15),'court_outer',.18)
    box('Playground_Surface',(-13.25,-.55,.155),(8.5,7.6,.06),'court',.12)
    line('Court_Boundary',[(-17.1,-3.9),(-9.4,-3.9),(-9.4,2.8),(-17.1,2.8),(-17.1,-3.9)],.075,z=.194)
    line('Court_Center_Line',[(-13.25,-3.9),(-13.25,2.8)],.06,z=.195)
    line('Court_Center_Circle',[(-13.25+1.08*math.cos(i*math.tau/48),-.55+1.08*math.sin(i*math.tau/48)) for i in range(49)],.065,z=.195)
    for cx in [-16.8,-9.7]:
        line('Court_Key',[(cx,-2),(cx+(1.4 if cx< -13 else -1.4),-2),(cx+(1.4 if cx< -13 else -1.4),.9),(cx,.9)],.065,z=.196)
    # One clear, durable hoop plus a ball rack on the play side.
    beam('Hoop_Post',(-17.6,-.55,.16),(-17.6,-.55,3.4),.15,'teal')
    beam('Hoop_Arm',(-17.6,-.55,3.2),(-16.8,-.55,3.2),.14,'teal')
    box('Backboard',(-16.75,-.55,3.2),(.10,1.45,.90),'white')
    ring=w.ring('School_Basket_Rim',xyz((-16.25,-.55,2.87)),.27,.025,M['brick'],GROUP)
    for i in range(8):
        a=i*math.tau/8;beam('Hoop_Net',(-16.25+.27*math.cos(a),-.55+.27*math.sin(a),2.86),(-16.25+.18*math.cos(a+.2),-.55+.18*math.sin(a+.2),2.47),.018,'white')
    box('Ball_Rack',(-16.7,4.4,.40),(2.1,.65,.60),'wood_light')
    for i,c in enumerate(['brick','yellow','blue']):ball('Play_Ball',(-17.4+i*.7,4.4,.88),(.27,.27,.27),c)
    # Low boundary walls and timber railings keep the cliff side readable.
    for x in [-18.6,8.7]:
        for j in range(12):
            yy=-5.7+j*.9;box('Boundary_Post',(x,yy,.54),(.16,.16,1.1),'wood_light')
        for z in [.45,.85]:beam('Boundary_Rail',(x,-5.7,z),(x,4.35,z),.10,'wood_light')
    for x in [i*1.15-18.4 for i in range(24)]:box('Rear_Fence_Post',(x,4.65,.59),(.16,.16,1.2),'wood_light')
    for z in [.5,.92]:beam('Rear_Fence_Rail',(-18.6,4.65,z),(8.6,4.65,z),.10,'wood_light')
    # Gate is open. No barriers or gates animate in this asset.
    for x in [-1.9,1.9]:
        box('Gate_Pier',(x,-6.15,.63),(.52,.58,1.36),'brick');box('Gate_Cap',(x,-6.15,1.35),(.65,.70,.16),'trim')
        ball('Gate_Lamp',(x,-6.15,1.65),(.22,.22,.25),'white')
    for a,b in [(-18.6,-2.3),(2.3,8.7)]:
        for i in range(math.ceil(b-a)+1):
            x=a+(b-a)*i/math.ceil(b-a);box('Front_Fence_Post',(x,-5.95,.45),(.12,.13,.95),'wood_light')
        for z in [.32,.68]:beam('Front_Fence_Rail',(a,-5.95,z),(b,-5.95,z),.08,'wood_light')
    # Seating, a notice board and planting strips are independent reusable props.
    bench('Schoolyard_Bench',-7.4,-4.7);bench('Schoolyard_Bench',5.8,-4.8)
    for x in [-3.8,3.8]:
        box('Planter',(x,-5.1,.25),(1.8,.62,.45),'brick')
        for j in range(5):
            xx=x-.65+j*.32;ball('Planter_Leaf',(xx,-5.1,.59),(.28,.27,.27),'leaf')
            ball('Planter_Bloom',(xx,-5.14,.85),(.12,.13,.11),'pink' if j%2 else 'yellow')
    for x in [3.1,4.6]:box('Noticeboard_Post',(x,-6.0,.85),(.12,.15,1.7),'wood')
    box('Noticeboard_Frame',(3.85,-6.0,1.55),(1.9,.22,1.16),'wood_light')
    box('Noticeboard_Face',(3.85,-6.13,1.55),(1.68,.045,.94),'teal')
    for x,z in [(3.45,1.6),(4.17,1.56)]:box('Notice_Paper',(x,-6.17,z),(.50,.018,.64),'white',.01)
    # Small planting bed behind the play area, safely below window height.
    for x in [-15.8,-13.8,-11.8]:
        box('Garden_Bed',(x,4.0,.16),(1.6,.75,.30),'wood')
        for j in range(3):ball('Garden_Plant',(x-.48+j*.48,4.0,.49),(.24,.23,.28),'leaf_light')
    print({'campus_objects':len(w.COLLS[GROUP].objects)})

def path(name,controls,width,start,end):
    pts=w.sampled(controls,24);verts=[];faces=[];cross=8
    for i,pt in enumerate(pts):
        d=pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)];d.normalize();n=Vector((-d.y,d.x))
        for j in range(cross+1):
            xy=pt+n*width*(j/cross-.5);verts.append((xy.x,xy.y,ground(xy.x,xy.y)+.12))
        if i:
            for j in range(cross):a=(i-1)*(cross+1)+j;b=a+cross+1;faces.extend([(a,a+1,b+1),(a,b+1,b)])
    o=w.mesh('School_'+name,verts,faces,M['path'],'School_Paths');o['school_path']=True
    rec={'name':name,'type':'path','from':start,'to':end,'width':width,'control_points':controls}
    w.ROUTE_RECORDS.append(rec);return rec

def paths_and_anchors():
    recs=[]
    recs.append(path('North_School_From_L',[[-8,37],[-3.2,37],[-1.1,40],[-1.6,44],[0,48.1]],2.7,'L','SCHOOL'))
    recs.append(path('North_School_From_M',[[13,38.5],[7.4,38.3],[5.5,41.4],[4.9,45.5],[0,48.1]],2.7,'M','SCHOOL'))
    RECORD['routes']=recs
    # These are asset sockets only, deliberately separate from A-Z's 130 learning loci.
    anchors=[('Gate',(0,-6.1,.15)),('Classroom',(-3.5,-3.6,.15)),('Library',(-7,-2.8,.15)),('Playground',(-13.25,-.55,.25)),('Canteen',(7,-3.2,.15))]
    for i,(name,loc) in enumerate(anchors,1):
        o=w.empty('SCHOOL_ANCHOR_'+name,xyz(loc),'School_Campus',.35);o['place_id']='SCHOOL';o['school_anchor_sequence']=i;o['purpose']='Reserved placement for future interaction; not implemented'
    root=w.empty('SCHOOL_ROOT',ORIGIN,'School_Building',.8);root['place_id']='SCHOOL';root['asset_role']='school_building';root['not_an_alphabet_landmark']=True
    bpy.context.view_layer.update()
    for o in list(w.COLLS['School_Building'].objects):
        if o!=root:
            matrix=o.matrix_world.copy();o.parent=root;o.matrix_parent_inverse=root.matrix_world.inverted();o.matrix_world=matrix
    campusroot=w.empty('SCHOOL_CAMPUS_ROOT',ORIGIN,'School_Campus',.8);campusroot['place_id']='SCHOOL';campusroot['asset_role']='school_campus'
    bpy.context.view_layer.update()
    for o in list(w.COLLS['School_Campus'].objects):
        if o!=campusroot:
            matrix=o.matrix_world.copy();o.parent=campusroot;o.matrix_parent_inverse=campusroot.matrix_world.inverted();o.matrix_world=matrix
    RECORD['building_root']=root.name;RECORD['campus_root']=campusroot.name

def finish():
    for name,loc,target,scale in [('School_North',(23,27,34),(-4.5,53.1,13.1),33),('Home_To_School',(54,-64,100),(-1,21,6),110)]:
        data=bpy.data.cameras.new('ALPHA_Camera_'+name);o=w.link('Camera_'+name,data,'Camera_Lighting');o.location=loc;w.enum_set(data,'type','ORTHO');data.ortho_scale=scale;w.aim(o,target)
    RECORD['home_location']=[-3,-14];RECORD['straight_distance_home_to_school_m']=round(math.hypot(3,ORIGIN.y+14),2)
    RECORD['building_meshes']=len([o for o in w.COLLS['School_Building'].objects if o.type=='MESH'])
    RECORD['campus_meshes']=len([o for o in w.COLLS['School_Campus'].objects if o.type=='MESH'])
    RECORD['version']=1;RECORD['map_version']='v04'
    (BASE/'school_asset_manifest_v01.json').write_text(json.dumps(RECORD,ensure_ascii=False,indent=2)+'\n')
    bpy.ops.object.select_all(action='DESELECT');w.SCENE.camera=bpy.data.objects['ALPHA_Camera_School_North']
    print(RECORD)
