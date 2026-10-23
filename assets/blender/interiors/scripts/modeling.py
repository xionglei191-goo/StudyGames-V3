"""Small editable geometry vocabulary for the alphabet-island interiors.

Run only inside a separate Blender process. All dimensions are metres, Z up.
No external textures, downloads, live-scene modifications or repository imports.
"""
import bpy, math, random
from mathutils import Vector

M = {}
COLLS = {}
CURRENT = 'Architecture'
PARENT = None
COLLIDERS = []
ANCHORS = []
RNG = random.Random(261022)
SPHERES = {}

PALETTE = {
    'cream':(.91,.82,.62), 'ivory':(.97,.93,.79), 'wood':(.48,.27,.13),
    'oak':(.69,.46,.24), 'lightwood':(.80,.62,.38), 'darkwood':(.22,.12,.07),
    'teal':(.10,.39,.39), 'mint':(.36,.62,.48), 'sage':(.36,.48,.23),
    'leaf':(.20,.40,.11), 'leaflight':(.39,.59,.16), 'grass':(.39,.52,.22),
    'soil':(.24,.16,.095), 'red':(.77,.12,.085), 'rose':(.77,.35,.36),
    'pink':(.92,.56,.56), 'yellow':(.95,.66,.18), 'gold':(.71,.46,.12),
    'blue':(.22,.49,.65), 'water':(.20,.59,.67), 'navy':(.055,.16,.25),
    'white':(.95,.93,.84), 'black':(.06,.075,.08), 'stone':(.46,.47,.40),
    'rock':(.38,.36,.30), 'clay':(.64,.32,.19), 'purple':(.45,.32,.53),
    'lavender':(.63,.53,.70), 'glass':(.47,.73,.74), 'paper':(.98,.91,.72),
    'metal':(.37,.49,.48), 'sand':(.80,.67,.42), 'orange':(.91,.39,.08),
}

def enum(owner, prop, value):
    valid = [i.identifier for i in owner.bl_rna.properties[prop].enum_items]
    if value not in valid:
        raise ValueError(f'{prop}: {value} unavailable: {valid}')
    setattr(owner, prop, value)

def setup(room_id):
    global M, COLLS, CURRENT, PARENT, COLLIDERS, ANCHORS, RNG, SPHERES
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.name = room_id + '_v01'
    enum(sc.unit_settings, 'system', 'METRIC')
    sc.unit_settings.scale_length = 1.0
    sc['room_id'] = room_id
    sc['coordinate_contract'] = 'Blender Z up; front -Y; glTF Y up; metres'
    sc['walkable_floor_z'] = 0.0
    bpy.context.preferences.filepaths.save_version = 0
    M, COLLS, COLLIDERS, ANCHORS, SPHERES = {}, {}, [], [], {}
    CURRENT, PARENT = 'Architecture', None
    RNG = random.Random(room_id)
    for key, rgb in PALETTE.items():
        mat = bpy.data.materials.new('MAT_' + key)
        mat.use_nodes = True
        bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        bsdf.inputs['Base Color'].default_value = (*rgb, 1)
        bsdf.inputs['Roughness'].default_value = .68 if key not in ('glass','water','metal') else .27
        bsdf.inputs['Metallic'].default_value = .32 if key in ('gold','metal') else 0
        mat.diffuse_color = (*rgb, 1)
        M[key] = mat
    mat = bpy.data.materials.new('MAT_COLLISION_TRANSPARENT')
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (1, 0, 1, 0)
    bsdf.inputs['Alpha'].default_value = 0
    enum(mat, 'surface_render_method', 'DITHERED')
    mat.diffuse_color = (1, 0, 1, 0)
    M['proxy'] = mat
    return sc

def group(name):
    global CURRENT
    CURRENT = name

def link(ob):
    if CURRENT not in COLLS:
        c = bpy.data.collections.new(CURRENT)
        bpy.context.scene.collection.children.link(c)
        COLLS[CURRENT] = c
    for c in list(ob.users_collection): c.objects.unlink(ob)
    COLLS[CURRENT].objects.link(ob)
    if PARENT: ob.parent = PARENT
    return ob

def mesh(name, verts, faces, mat):
    data = bpy.data.meshes.new(name + '_Mesh')
    data.from_pydata(verts, [], faces); data.update()
    ob = bpy.data.objects.new(name, data); link(ob)
    if mat: data.materials.append(M[mat])
    return ob

def soften(ob, radius=.06):
    if radius:
        mod=ob.modifiers.new('Soft rounded edges','BEVEL'); mod.width=radius; mod.segments=3
        mod2=ob.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL'); mod2.keep_sharp=True
    return ob

def box(name, pos, size, mat='wood', bevel=.05):
    x,y,z=[v/2 for v in size]
    ob=mesh(name,[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat)
    ob.location=pos
    return soften(ob,min(bevel,min(size)/3))

def cyl(name,pos,radius,height,mat='oak',vertices=24,top=None):
    rt=radius if top is None else top
    vs=[(r*math.cos(i*math.tau/vertices),r*math.sin(i*math.tau/vertices),z) for r,z in [(radius,-height/2),(rt,height/2)] for i in range(vertices)]
    fs=[tuple(reversed(range(vertices))),tuple(range(vertices,2*vertices))]+[(i,(i+1)%vertices,(i+1)%vertices+vertices,i+vertices) for i in range(vertices)]
    ob=mesh(name,vs,fs,mat);ob.location=pos
    for p in ob.data.polygons[2:]: p.use_smooth=True
    return soften(ob,min(.035,height/8,radius/10))

def ball(name,pos,size,mat='leaf',segments=20,rings=12):
    key=(segments,rings,mat)
    if key not in SPHERES:
        vs=[(0,0,1),(0,0,-1)]
        for j in range(1,rings):
            b=math.pi*j/rings
            for i in range(segments):
                a=math.tau*i/segments
                vs.append((math.sin(b)*math.cos(a),math.sin(b)*math.sin(a),math.cos(b)))
        fs=[]
        for i in range(segments):
            k=(i+1)%segments
            fs.append((0,2+i,2+k))
            fs.append((1,2+(rings-2)*segments+k,2+(rings-2)*segments+i))
        for j in range(rings-2):
            for i in range(segments):
                k=(i+1)%segments;a=2+j*segments;b=a+segments
                fs.append((a+i,b+i,b+k,a+k))
        data=bpy.data.meshes.new('Shared_Sphere_'+mat);data.from_pydata(vs,[],fs);data.update();data.materials.append(M[mat])
        for p in data.polygons:p.use_smooth=True
        SPHERES[key]=data
    ob=bpy.data.objects.new(name,SPHERES[key]);link(ob);ob.location=pos;ob.scale=size
    return ob

def beam(name,a,b,radius=.06,mat='wood'):
    a,b=Vector(a),Vector(b);ob=cyl(name,(a+b)/2,radius,(b-a).length,mat,12)
    ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return ob

def ring(name,pos,radius,tube=.035,mat='oak',rotation=None,portion=1,segments=48):
    vs=[];fs=[];n=max(8,int(segments*portion));q=8
    for i in range(n+1):
        a=math.tau*portion*i/n
        for j in range(q):
            b=math.tau*j/q;rr=radius+tube*math.cos(b)
            vs.append((rr*math.cos(a),rr*math.sin(a),tube*math.sin(b)))
    for i in range(n):
        for j in range(q):fs.append((i*q+j,i*q+(j+1)%q,(i+1)*q+(j+1)%q,(i+1)*q+j))
    ob=mesh(name,vs,fs,mat);ob.location=pos
    if rotation:ob.rotation_euler=rotation
    for p in ob.data.polygons:p.use_smooth=True
    return ob

def text(name,body,pos,size=.3,mat='cream',facing='front'):
    cv=bpy.data.curves.new(name+'_Typography','FONT');cv.body=body;cv.size=size
    cv.align_x='CENTER';cv.align_y='CENTER';cv.extrude=.008;cv.bevel_depth=.002
    ob=bpy.data.objects.new(name,cv);link(ob);ob.location=pos
    ob.rotation_euler=(math.pi/2,0,0) if facing=='front' else (0,0,0)
    cv.materials.append(M[mat]);return ob

def empty(name,pos,label=None):
    ob=bpy.data.objects.new(name,None);link(ob);ob.location=pos;ob.empty_display_size=.35
    if label:ob['label']=label
    return ob

def collider(name,pos,size):
    global CURRENT
    old=CURRENT;group('90_Collision_Proxies')
    ob=box('SG_COLLIDER_'+name,pos,size,'proxy',0)
    ob.display_type='WIRE';ob.hide_render=True;ob['collision_proxy']=True
    COLLIDERS.append({'name':ob.name,'position_blender':list(pos),'size_blender':list(size)})
    group(old);return ob

def anchor(name,xy,label='',target=None):
    global CURRENT
    old=CURRENT;group('80_Gameplay_Anchors')
    ob=empty(name,(*xy,0),label);ob['interaction_anchor']=True
    if target:ob['associated_prop']=target
    ANCHORS.append({'name':name,'label':label,'position_blender':[*xy,0],'position_godot':[xy[0],0,-xy[1]],'associated_prop':target})
    group(old);return ob

def floor(width=16,depth=14,mat='lightwood',planks=True):
    box('SG_FLOOR_Main',(0,0,-.23),(width,depth,.46),mat,.22)
    box('Foundation_Edge',(0,0,-.42),(width+.10,depth+.10,.20),'darkwood',.15)
    if planks:
        for i in range(int(depth/.7)):
            y=-depth/2+.35+i*.7
            box('Floor_Plank_Joint_%02d'%i,(0,y,-.002),(width-.16,.022,.01),'oak',.002)
            for x in [-width*.25,width*.25]:
                xx=x+(.7 if i%2 else 0)
                box('Floor_End_Joint',(xx,y+.34,0),(.018,.67,.008),'oak',.002)

def room_shell(width=16,depth=14,wall='cream',floor_mat='lightwood',style='room'):
    group('00_Architecture');floor(width,depth,floor_mat,style not in ['garden','water','stone','court'])
    # Back boundary is tall; left side is cut to a sill; front and camera-side are open.
    if style=='room':
        box('Rear_Wall',(0,depth/2,1.9),(width,.28,3.8),wall,.08)
        box('Rear_Baseboard',(0,depth/2-.18,.2),(width,.15,.32),'oak',.03)
        box('Rear_Crown',(0,depth/2,3.84),(width+.2,.40,.16),'oak')
        box('Left_Cutaway_Wall',(-width/2,0,.45),(.22,depth,.9),wall)
        for x in [-width/2,width/2]:
            box('Back_Corner_Post',(x,depth/2,1.9),(.24,.36,3.9),'oak')
    else:
        for i in range(int(width/2)+1):
            x=-width/2+i*2
            cyl('Rear_Fence_Post',(x,depth/2,.62),.10,1.24,'oak',12)
        for z in [.42,.92]:beam('Rear_Fence_Rail',(-width/2,depth/2,z),(width/2,depth/2,z),.065,'lightwood')
    collider('Boundary_Rear',(0,depth/2+.15,1),(width+.4,.3,2))
    collider('Boundary_Left',(-width/2-.15,0,1),(.3,depth,2))
    collider('Boundary_Right',(width/2+.15,0,1),(.3,depth,2))
    collider('Front_Left',(-(width+2.8)/4,-depth/2-.15,1),((width-2.8)/2,.3,2))
    collider('Front_Right',((width+2.8)/4,-depth/2-.15,1),((width-2.8)/2,.3,2))
    box('Entry_Threshold',(0,-depth/2+.12,.025),(2.5,.7,.05),'sand')
    for x in [-1.35,1.35]:
        cyl('Entry_Bollard',(x,-depth/2+.1,.37),.12,.74,'oak')
        ball('Entry_Bollard_Cap',(x,-depth/2+.1,.76),(.15,.15,.11),'gold')

def rug(name,xy,size=(3,2),mat='teal'):
    ob=box(name,(*xy,.022),(*size,.035),mat,.07)
    for yy in [-size[1]/2+.15,size[1]/2-.15]:
        box(name+'_Border',(xy[0],xy[1]+yy,.045),(size[0]-.2,.055,.008),'cream',.005)
    return ob

def table(name,x,y,w=2.6,d=1.4,h=1.05,mat='lightwood',solid=False,collision=True):
    box(name+'_Top',(x,y,h),(w,d,.18),mat,.09)
    if solid:box(name+'_Cabinet',(x,y,h/2),(w-.15,d-.12,h),'cream',.06)
    else:
        for dx in [-w/2+.17,w/2-.17]:
            for dy in [-d/2+.17,d/2-.17]:box(name+'_Leg',(x+dx,y+dy,h/2),(.13,.13,h),'oak',.03)
    if collision:collider(name,(x,y,h/2),(w,d,h+.12))
    return h+.1

def stool(name,x,y,h=.58,mat='teal'):
    cyl(name+'_Seat',(x,y,h),.37,.18,mat)
    for a in [0,math.tau/3,math.tau*2/3]:beam(name+'_Leg',(x+.3*math.cos(a),y+.3*math.sin(a),.06),(x+.19*math.cos(a),y+.19*math.sin(a),h),.055,'oak')

def bench(name,x,y,w=2.7,mat='oak',back=True):
    table(name,x,y,w,.65,.58,mat,collision=True)
    if back:
        for dx in [-w/2+.15,w/2-.15]:box(name+'_Back_Post',(x+dx,y+.28,.92),(.12,.12,.85),'wood')
        box(name+'_Back',(x,y+.28,1.02),(w,.14,.45),mat)

def shelf(name,x,y,w=2.9,levels=3,content='books',height=2.5):
    box(name+'_Back',(x,y+.3,height/2),(w,.12,height),'oak')
    for dx in [-w/2,w/2]:box(name+'_Side',(x+dx,y,height/2),(.12,.75,height),'wood')
    for j in range(levels+1):
        z=.18+j*(height-.25)/levels
        box(name+'_Shelf',(x,y,z),(w,.78,.12),'lightwood')
        if j==levels:continue
        for k in range(5):
            xx=x-w*.36+k*w*.18
            if content=='books':
                hh=.35+.17*((k+j)%3);ob=box(name+'_Book',(xx,y-.05,z+.08+hh/2),(.18,.42,hh),['teal','red','yellow','mint','blue'][(k+j)%5],.015)
                box(name+'_Book_Label',(xx,y-.268,z+.22),(.13,.018,.045),'cream',.005)
            elif content=='jars':jar(name+'_Jar',xx,y-.03,z+.07,.22,['rose','mint','yellow','blue','cream'][k])
            elif content=='parcels':parcel(name+'_Parcel',xx,y,z+.25,.38,['paper','rose','teal'][k%3])
            elif content=='yarn':yarn(name+'_Wool',xx,y-.05,z+.28,.24,['rose','mint','yellow','blue','purple'][k])
            elif content=='seeds':box(name+'_Seed_Packet',(xx,y-.04,z+.28),(.30,.13,.40),['rose','mint','yellow','blue','paper'][k])
    collider(name,(x,y,height/2),(w+.14,.85,height))

def board(name,x,y,title,subtitle='',color='teal',z=1.5,w=2.4):
    for dx in [-w*.36,w*.36]:box(name+'_Support',(x+dx,y,.8),(.12,.16,1.6),'oak')
    box(name+'_Frame',(x,y,z),(w,.20,1.25),'oak')
    box(name+'_Face',(x,y-.13,z),(w-.18,.04,1.05),color,.02)
    text(name+'_Title',title,(x,y-.17,z+.16),min(.26,3.5/max(len(title),1)))
    if subtitle:text(name+'_Sub',subtitle,(x,y-.175,z-.20),.15,'ivory')
    collider(name,(x,y,.8),(w,.25,1.6))

def jar(name,x,y,z,r=.22,color='rose'):
    cyl(name+'_Body',(x,y,z+r*.9),r,r*1.8,color,20,top=r*.9)
    cyl(name+'_Lid',(x,y,z+r*1.86),r*1.02,.07,'gold',20)
    box(name+'_Label',(x,y-r,z+r),(.22,.025,.18),'paper',.02)

def parcel(name,x,y,z,s=.5,mat='paper'):
    box(name,(x,y,z),(s,s*.7,s*.65),mat,.04)
    box(name+'_Ribbon',(x,y,z+s*.34),(.08,s*.74,.025),'cream',.01)
    box(name+'_Ribbon2',(x,y-s*.36,z),(.08,.025,s*.67),'cream',.005)

def apple(name,x,y,z,s=.23):
    ball(name,(x,y,z),(s,s,s*.9),'red')
    beam(name+'_Stem',(x,y,z+s*.72),(x+.03,y,z+s*1.15),s*.09,'wood')
    ob=ball(name+'_Leaf',(x+s*.28,y,z+s),(.45*s,.18*s,.12*s),'leaf');ob.rotation_euler[1]=-.3

def basket(name,x,y,z=0,fruit=True):
    cyl(name+'_Wicker',(x,y,z+.28),.47,.5,'oak',24,top=.54)
    for h in [.12,.27,.43]:ring(name+'_Weave',(x,y,z+h),.49,.027,'lightwood')
    ring(name+'_Handle',(x,y,z+.54),.45,.045,'wood',(math.pi/2,0,0),.5)
    if fruit:
        for dx,dy in [(-.22,-.15),(.23,-.1),(0,.2)]:apple(name+'_Apple',x+dx,y+dy,z+.57,.21)

def plant(name,x,y,z=0,flower=False,s=1):
    cyl(name+'_Pot',(x,y,z+.25*s),.30*s,.5*s,'clay',20,top=.4*s)
    cyl(name+'_Soil',(x,y,z+.51*s),.35*s,.04*s,'soil',20)
    for j in range(5):
        a=j*math.tau/5;xx=x+math.cos(a)*.22*s;yy=y+math.sin(a)*.22*s;zz=z+(1+.18*(j%2))*s
        beam(name+'_Stem',(x,y,z+.5*s),(xx,yy,zz),.025*s,'leaf')
        ball(name+'_Leaf',(xx,yy,z+.78*s),(.22*s,.12*s,.08*s),'leaflight')
        if flower:
            for k in range(5):
                b=k*math.tau/5;ball(name+'_Petal',(xx+math.cos(b)*.13*s,yy+math.sin(b)*.13*s,zz),(.14*s,.14*s,.06*s),['rose','yellow','pink'][j%3],12,8)
            ball(name+'_Heart',(xx,yy,zz+.03*s),(.07*s,)*3,'yellow',12,8)

def tree(name,x,y,fruit=False,s=1):
    cyl(name+'_Trunk',(x,y,1.3*s),.20*s,2.6*s,'wood',16,top=.14*s)
    for dx,dy,dz,rr in [(-.7,0,2.65,1),( .65,.15,2.9,.95),(0,.45,3.5,1.15),(0,-.5,3.0,1.05)]:
        ball(name+'_Crown',(x+dx*s,y+dy*s,dz*s),(rr*s,rr*.85*s,rr*.8*s),'leaflight' if dz>3 else 'leaf')
    if fruit:
        for dx,dy,z in [(-1.25,-.48,2.65),(.82,-.72,2.85),(0,-1.40,3.05),(.35,-.43,4.1),(-.65,.1,3.55)]:apple(name+'_Fruit',x+dx*s,y+dy*s,z*s,.25*s)
    collider(name,(x,y,1.3*s),(.65*s,.65*s,2.6*s))

def sink(name,x,y):
    table(name,x,y,2.25,1.2,1.0,'teal',solid=True)
    box(name+'_Basin',(x,y,1.12),(1.8,.85,.06),'water',.12)
    for dx in [-1.05,1.05]:box(name+'_Rim',(x+dx,y,1.18),(.12,1.2,.20),'teal')
    for dy in [-.54,.54]:box(name+'_Rim',(x,y+dy,1.18),(2.25,.12,.20),'teal')
    beam(name+'_Tap',(x,y+.45,1.15),(x,y+.45,1.72),.055,'gold')
    beam(name+'_Spout',(x,y+.45,1.72),(x,y+.05,1.72),.055,'gold')

def lantern(name,x,y,z=2.5,color='yellow',s=.5):
    ball(name+'_Shade',(x,y,z),(s,s,s*1.2),color)
    for dz in [-s,s]:cyl(name+'_Cap',(x,y,z+dz),s*.53,.10,'wood')
    ring(name+'_Handle',(x,y,z+s*1.3),s*.25,.025,'gold',(math.pi/2,0,0))
    for k in range(8):
        a=k*math.tau/8;beam(name+'_Rib',(x+s*.84*math.cos(a),y+s*.84*math.sin(a),z-s*.5),(x+s*.84*math.cos(a),y+s*.84*math.sin(a),z+s*.5),.014,'cream')

def window(name,x,y,z=2.35,w=2.0,h=1.5):
    box(name+'_Frame',(x,y,z),(w+.2,.15,h+.2),'oak')
    box(name+'_Glass',(x,y-.09,z),(w,.04,h),'glass',.02)
    box(name+'_Mullion',(x,y-.12,z),(.07,.05,h),'cream')
    box(name+'_Transom',(x,y-.12,z),(w,.05,.07),'cream')
    box(name+'_Sill',(x,y-.18,z-h/2-.04),(w+.4,.55,.12),'lightwood')

def cake(name,x,y,z=0,s=1):
    for rr,hh,zz in [(.65,.40,.20),(.46,.32,.56)]:
        cyl(name+'_Layer',(x,y,z+zz*s),rr*s,hh*s,'pink')
        cyl(name+'_Icing',(x,y,z+(zz+hh/2)*s),rr*s+.025,.09*s,'ivory')
        for j in range(10):
            a=j*math.tau/10;ball(name+'_Cream',(x+rr*s*.9*math.cos(a),y+rr*s*.9*math.sin(a),z+(zz+hh/2)*s),(.10*s,.1*s,.1*s),'white',12,8)
    apple(name+'_Cherry',x,y,z+.81*s,.13*s)

def hat(name,x,y,z=0,s=.7,color='teal'):
    cyl(name+'_Brim',(x,y,z+.06),s,.12,color)
    cyl(name+'_Crown',(x,y,z+.36),s*.57,.58,color,32,top=s*.49)
    cyl(name+'_Band',(x,y,z+.21),s*.58,.14,'cream')

def yarn(name,x,y,z=0,s=.4,color='rose'):
    ball(name+'_Ball',(x,y,z),(s,s,s),color)
    for a in [-.65,-.25,.15,.55]:ring(name+'_Wrap',(x,y,z),s*1.01,.018,'cream',(math.pi/2,a,.2))

def drum(name,x,y,z=0,r=.7,h=.85,color='red'):
    cyl(name+'_Shell',(x,y,z+h/2),r,h,color)
    cyl(name+'_Skin',(x,y,z+h+.01),r*1.03,.07,'ivory')
    for zz in [.08,h-.05]:ring(name+'_Hoop',(x,y,z+zz),r*1.03,.045,'gold')
    for j in range(12):
        a=j*math.tau/12;beam(name+'_Lacing',(x+r*math.cos(a),y+r*math.sin(a),z+.1),(x+r*math.cos(a+.2),y+r*math.sin(a+.2),z+h-.1),.018,'cream')

def pillow(name,x,y,z=.1,color='rose',size=(.65,.5,.18)):
    return box(name,(x,y,z),size,color,.15)

def telescope(name,x,y,z=0,s=1):
    for dx,dy in [(-.65,-.5),(.65,-.5),(0,.7)]:beam(name+'_Tripod',(x+dx*s,y+dy*s,z+.05),(x,y,z+1.7*s),.065*s,'oak')
    beam(name+'_Tube',(x-.75*s,y,z+1.55*s),(x+.8*s,y,z+2.25*s),.24*s,'teal')
    beam(name+'_Eyepiece',(x-.9*s,y,z+1.48*s),(x-.73*s,y,z+1.56*s),.11*s,'gold')
    collider(name,(x,y,z+.75*s),(1.6*s,1.5*s,1.5*s))

def door(name,x,y,title,color='teal'):
    box(name+'_Surround',(x,y,1.55),(2.35,.3,3.1),'oak')
    box(name+'_Inset',(x,y-.19,1.48),(2.05,.14,2.87),color)
    window(name+'_Upper_Light',x,y-.29,2.05,1.45,.8)
    ball(name+'_Handle',(x+.65,y-.35,1.2),(.085,.085,.085),'gold')
    box(name+'_Nameplate',(x,y-.24,3.25),(2.65,.13,.48),'cream')
    text(name+'_Name',title,(x,y-.32,3.25),.26,'teal')

def grid_tiles(name,x,y,w,d,mat='cream',alt='ivory',step=.8,z=.01):
    for i in range(int(w/step)):
        for j in range(int(d/step)):
            box(name,(x-w/2+(i+.5)*step,y-d/2+(j+.5)*step,z),(step-.025,step-.025,.025),mat if (i+j)%2 else alt,.015)

def arc_wall(name,cx,cy,r,a0,a1,height=1.1,mat='cream',segments=24):
    for i in range(segments):
        a=a0+(a1-a0)*(i+.5)/segments;da=(a1-a0)/segments
        ob=box(name,(cx+r*math.cos(a),cy+r*math.sin(a),height/2),(.22,r*da*1.03,height),mat,.04);ob.rotation_euler[2]=a

def title_banner(title,subtitle='',color='teal',y=6.72):
    box('Shop_Title_Beam',(0,y,3.15),(max(4.5,min(10,len(title)*.35)),.25,.65),color)
    text('Shop_Title',title,(0,y-.16,3.18),.40,'ivory')
    if subtitle:text('Shop_Subtitle',subtitle,(0,y-.17,2.80),.17,'darkwood')

def garden_box(name,x,y,w=2.4,d=1.0,flowers=True):
    box(name+'_Box',(x,y,.25),(w,d,.5),'oak')
    box(name+'_Soil',(x,y,.52),(w-.16,d-.16,.08),'soil')
    for i in range(max(2,int(w/.65))):plant(name+'_Plant',x-w*.32+i*w*.64/max(1,int(w/.65)-1),y,.4,flowers,.48)
    collider(name,(x,y,.4),(w,d,.8))

def clock_face(name,x,y,z=2.8):
    ob=cyl(name+'_Case',(x,y,z),.62,.14,'gold',48);ob.rotation_euler[0]=math.pi/2
    ob=cyl(name+'_Dial',(x,y-.09,z),.54,.035,'ivory',48);ob.rotation_euler[0]=math.pi/2
    for i in range(12):
        a=i*math.tau/12
        box(name+'_Tick',(x+math.sin(a)*.45,y-.125,z+math.cos(a)*.45),(.055,.025,.055),'teal',.01)
    beam(name+'_Hand',(x,y-.16,z),(x-.24,y-.16,z+.27),.03,'teal')
    beam(name+'_Hand',(x,y-.16,z),(x+.08,y-.16,z+.39),.022,'teal')
