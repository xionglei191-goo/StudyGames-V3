"""Editable alphabet-island scene. Run stages in Blender through MCP.

The original A/B/C files and prior scenes are preserved. This module does not
generate Tripo assets. Missing landmarks receive hidden sockets and envelopes.
"""
import bpy
import math
import random
import json
from pathlib import Path
from mathutils import Vector, Matrix

BASE = Path(__file__).resolve().parent
PROJECT = BASE.parents[2]
LAYOUT = json.loads((BASE / 'layout.json').read_text())
PLOTS = LAYOUT['landmarks']
BY_LETTER = {p['letter']:p for p in PLOTS}
RIVER = LAYOUT['river']
SCENE_NAME = 'Alphabet_Island_Layout_v01'
RNG = random.Random(261021)
COLLS = {}
MATS = {}
ROAD_SAMPLES = []
ROUTE_RECORDS = []
ASSET_RECORDS = []
ICO = {}
SCENE = None


def enum_set(owner, name, value):
    options = [i.identifier for i in owner.bl_rna.properties[name].enum_items]
    if value not in options:
        raise ValueError((name, value, options))
    setattr(owner, name, value)


def smooth(a,b,x):
    t = max(0.0, min(1.0, (x-a)/(b-a)))
    return t*t*(3-2*t)


def coast_radius(theta):
    return 1 + 0.035*math.sin(theta*3+.4) + .025*math.cos(theta*5-.6) + .018*math.sin(theta*8)


def land_ratio(x,y):
    theta=math.atan2(y/64,x/74)
    return math.hypot(x/74,y/64)/coast_radius(theta)


def segment_distance(x,y,a,b):
    dx,dy=b[0]-a[0],b[1]-a[1]
    t=max(0,min(1,((x-a[0])*dx+(y-a[1])*dy)/(dx*dx+dy*dy)))
    return math.hypot(x-a[0]-t*dx,y-a[1]-t*dy), t


def river_query(x,y):
    best=(1e9,0)
    for i in range(len(RIVER)-1):
        d,t=segment_distance(x,y,RIVER[i],RIVER[i+1])
        if d<best[0]: best=(d,(i+t)/(len(RIVER)-1))
    return best[0],4.65-4.35*best[1]


def raw_height(x,y):
    z=5.4+4.8*smooth(2,33,y)+1.3*smooth(15,48,x)-2.4*(1-smooth(-50,-20,y))
    z += .32*math.sin(x*.09)*math.cos(y*.10)
    return z


for p in PLOTS:
    p['ground_z']=raw_height(p['x'],p['y'])
    p['flat_radius']=14.0 if p['letter']=='A' else p['target_width']*.6+1.8
    p['plot_radius']=p['target_width']*.58+.9
    p['entrance']=[p['x'],p['y']-p['target_width']*.5-1.5]
BY_LETTER['B']['ground_z']=1.85
BY_LETTER['B']['entrance']=[-55,-49.0]


def height(x,y):
    ratio=land_ratio(x,y)
    z=raw_height(x,y)
    for p in PLOTS:
        if p['letter']=='B': continue
        d=math.hypot(x-p['x'],y-p['y'])
        blend=1-smooth(p['flat_radius']-1,p['flat_radius']+3,d)
        z=z*(1-blend)+p['ground_z']*blend
    # Central house and courtyard form one usable terrace.
    dh=math.hypot((x+3)*.9,(y+17)*.7)
    bh=1-smooth(8,15,dh)
    z=z*(1-bh)+5.4*bh
    lake=math.hypot(x/20,(y-7)/16)
    bl=1-smooth(.93,1.16,lake)
    z=z*(1-bl)+3.50*bl
    d,w=river_query(x,y)
    br=1-smooth(2.4,5.0,d)
    z=z*(1-br)+(w-.9)*br
    # A shallow southwest inlet accommodates the boat and pier.
    bay=math.hypot((x+57)/12,(y+44)/11)
    bb=1-smooth(.85,1.15,bay)
    z=z*(1-bb)-.85*bb
    coastal=1-smooth(.925,1.0,ratio)
    z=.42+(z-.42)*coastal
    # Build solid terraces below landmark pads, including river and coast edges.
    for p in PLOTS:
        if p['letter']=='B': continue
        d=math.hypot(x-p['x'],y-p['y'])
        terrace=1-smooth(p['plot_radius']+.45,p['plot_radius']+2.3,d)
        z=z*(1-terrace)+p['ground_z']*terrace
    return z


def make_material(name,rgb,rough=.7,metal=0,emission=0):
    mat=bpy.data.materials.new('ALPHA_MAT_'+name)
    mat.use_nodes=True
    p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*rgb,1)
    p.inputs['Roughness'].default_value=rough
    p.inputs['Metallic'].default_value=metal
    if emission:
        p.inputs['Emission Color'].default_value=(*rgb,1)
        p.inputs['Emission Strength'].default_value=emission
    mat.diffuse_color=(*rgb,1)
    return mat


def link(name,data,group):
    obj=bpy.data.objects.new('ALPHA_'+name,data)
    COLLS[group].objects.link(obj)
    obj['alphabet_island']=True
    return obj


def mesh(name,verts,faces,mat,group):
    data=bpy.data.meshes.new('ALPHA_'+name+'_Mesh')
    data.from_pydata(verts,[],faces);data.update()
    if mat: data.materials.append(mat)
    return link(name,data,group)


def bevel(obj,amount=.06):
    types=[i.identifier for i in bpy.types.Modifier.bl_rna.properties['type'].enum_items]
    assert 'BEVEL' in types
    mod=obj.modifiers.new('Rounded edges','BEVEL');mod.width=amount;mod.segments=2
    return obj


def box(name,loc,size,mat,group,roundness=.04):
    x,y,z=[v/2 for v in size]
    obj=mesh(name,[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat,group)
    obj.location=loc
    if roundness: bevel(obj,min(roundness,min(size)*.25))
    return obj


def cylinder(name,loc,radius,depth,mat,group,n=12,top=None):
    top=radius if top is None else top
    verts=[(math.cos(i*math.tau/n)*r,math.sin(i*math.tau/n)*r,z) for r,z in [(radius,-depth/2),(top,depth/2)] for i in range(n)]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    obj=mesh(name,verts,faces,mat,group);obj.location=loc
    return obj


def beam(name,a,b,width,mat,group,square=True):
    a,b=Vector(a),Vector(b)
    obj=box(name,(a+b)/2,(width,width,(b-a).length),mat,group,.035) if square else cylinder(name,(a+b)/2,width/2,(b-a).length,mat,group,10)
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return obj


def ball(name,loc,scale,mat,group):
    if mat.name not in ICO:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1)
        temp=bpy.context.object;data=temp.data
        for poly in data.polygons: poly.use_smooth=True
        data.materials.append(mat);bpy.data.objects.remove(temp,do_unlink=True)
        ICO[mat.name]=data
    obj=link(name,ICO[mat.name],group);obj.location=loc;obj.scale=scale
    return obj


def empty(name,loc,group,size=.5):
    obj=link(name,None,group);obj.location=loc;enum_set(obj,'empty_display_type','CIRCLE');obj.empty_display_size=size
    return obj


def sampled(points,steps=12):
    pts=[Vector((x,y)) for x,y in points];out=[]
    for i in range(len(pts)-1):
        a,b,c,d=pts[max(0,i-1)],pts[i],pts[i+1],pts[min(i+2,len(pts)-1)]
        for j in range(steps):
            t=j/steps;out.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    out.append(pts[-1]);return out


def ribbon(name,points,width,mat,group,z_fn,skip_water=False):
    pts=sampled(points);verts=[];faces=[]
    for i,p in enumerate(pts):
        direction=pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)];direction.normalize();normal=Vector((-direction.y,direction.x))*width/2
        for v in (p+normal,p-normal): verts.append((v.x,v.y,z_fn(v.x,v.y)))
    for i in range(len(pts)-1):
        p=(pts[i]+pts[i+1])/2
        if skip_water and river_query(p.x,p.y)[0]<3.2: continue
        faces.append((2*i,2*i+1,2*i+3,2*i+2))
    obj=mesh(name,verts,faces,mat,group)
    return obj,pts


def initialize():
    global SCENE
    if SCENE_NAME in bpy.data.scenes: raise RuntimeError('World scene already exists; edit it instead of rebuilding.')
    previous=bpy.context.scene.render.engine
    SCENE=bpy.data.scenes.new(SCENE_NAME);bpy.context.window.scene=SCENE;SCENE.render.engine=previous
    enum_set(SCENE.unit_settings,'system','METRIC')
    for g in ['Terrain','Water','Paths','Bridges_Docks','Plots','Landmarks','Home','Orchard','Forest','Gardens','Street_Furniture','Wayfinding_Editor','Camera_Lighting']:
        c=bpy.data.collections.new('ALPHA_'+g);SCENE.collection.children.link(c);COLLS[g]=c
    colors={
        'grass':(.31,.51,.17),'grass_light':(.43,.59,.25),'grass_forest':(.245,.42,.15),
        'earth':(.35,.25,.16),'rock':(.52,.51,.42),'rock_light':(.68,.66,.55),
        'sand':(.82,.70,.46),'path':(.82,.73,.55),'path_edge':(.60,.51,.35),'paving':(.66,.67,.57),
        'water':(.105,.52,.64),'sea':(.11,.42,.52),'foam':(.66,.88,.86),
        'wood':(.51,.28,.11),'wood_light':(.74,.48,.22),'wood_dark':(.26,.14,.07),
        'bark':(.26,.13,.055),'leaf':(.19,.38,.095),'leaf_light':(.31,.50,.14),'pine':(.15,.32,.14),
        'cream':(.90,.83,.65),'roof':(.64,.20,.10),'teal':(.12,.37,.38),'glass':(.97,.63,.19),
        'pink':(.83,.39,.45),'yellow':(.94,.67,.15),'lavender':(.55,.43,.68),'red':(.74,.09,.045),'soil':(.22,.14,.085)}
    for name,rgb in colors.items(): MATS[name]=make_material(name,rgb,.28 if name in ['water','sea'] else .72,emission=.25 if name=='glass' else 0)
    SCENE['scope']='Editable connected world terrain, A-Z plots, central home, existing Tripo landmarks; static scene prototype.'
    SCENE['pending_landmarks']='D-Z'
    print({'stage':'initialized','scene':SCENE.name})


def build_terrain():
    # Radial mesh follows the entire coast without a jagged rectangular grid edge.
    rings,sectors=70,192
    verts=[(0,0,height(0,0))]
    for j in range(1,rings+1):
        t=j/rings
        for i in range(sectors):
            angle=math.tau*i/sectors;factor=coast_radius(angle)
            x=74*math.cos(angle)*factor*t;y=64*math.sin(angle)*factor*t
            verts.append((x,y,height(x,y)))
    faces=[]
    for i in range(sectors): faces.append((0,1+i,1+(i+1)%sectors))
    for j in range(rings-1):
        a=1+j*sectors;b=a+sectors
        for i in range(sectors):
            k=(i+1)%sectors;faces.extend([(a+i,b+i,b+k),(a+i,b+k,a+k)])
    terrain=mesh('Island_Continuous_Terrain',verts,faces,MATS['grass'],'Terrain')
    for name in ['grass_light','grass_forest','sand','rock']: terrain.data.materials.append(MATS[name])
    for poly in terrain.data.polygons:
        c=poly.center;ratio=land_ratio(c.x,c.y)
        if ratio>.945 or (c.y<-45 and c.x>-42): poly.material_index=3
        elif c.y>18 and c.x>0: poly.material_index=2
        elif c.x<-25 and c.y<12: poly.material_index=1
        if poly.normal.z<.78 and c.z>1: poly.material_index=4
        poly.use_smooth=True
    # Earth coast thickness; separate sand shelf extends into the ocean.
    coast=[]
    for i in range(sectors):
        a=math.tau*i/sectors;f=coast_radius(a);coast.append((74*math.cos(a)*f,64*math.sin(a)*f))
    verts2=[(x,y,z) for z in [-1.5,.42] for x,y in coast]
    wall=mesh('Island_Earth_Edge',verts2,[(i,(i+1)%sectors,(i+1)%sectors+sectors,i+sectors) for i in range(sectors)],MATS['earth'],'Terrain')
    shelf=[(x*s,y*s,z) for s,z in [(1.035,-.15),(1.0,.43)] for x,y in coast]
    mesh('Coastal_Sand_Shelf',shelf,[(i,(i+1)%sectors,(i+1)%sectors+sectors,i+sectors) for i in range(sectors)],MATS['sand'],'Terrain')
    box('Ocean_Presentation',(0,0,-.18),(600,600,.2),MATS['sea'],'Water',0)['presentation_only']=True
    lake=cylinder('Central_Lake',(0,7,4.65),1,.045,MATS['water'],'Water',128);lake.scale=(20.15,16.15,1)
    ribbon('River_Water',RIVER,4.7,MATS['water'],'Water',lambda x,y:river_query(x,y)[1]+.02)
    for j in range(28):
        a=math.tau*j/28
        x=20.7*math.cos(a);y=7+16.7*math.sin(a);z=height(x,y)
        if z<4.3: continue
        rock=ball('Lake_Shore_Rock', (x,y,z+.35),(.7+RNG.random()*.55,.6+RNG.random()*.4,.55+RNG.random()*.3),MATS['rock_light'],'Water')
    # A small island and resting jetty in the lake.
    islet=cylinder('Lake_Islet',(7,8,4.88),3.0,.48,MATS['sand'],'Water',32)
    cylinder('Lake_Islet_Grass',(7,8,5.15),2.65,.12,MATS['grass_light'],'Water',32)
    for i in range(15): box('Islet_Jetty_Plank',(7,3.7+i*.28,4.95),(2.4,.25,.15),MATS['wood_light'],'Bridges_Docks',.035)
    # Scatter foam marks around the outer shoreline only.
    for i in range(56):
        a=math.tau*i/56;f=coast_radius(a)*1.055;x=74*math.cos(a)*f;y=64*math.sin(a)*f
        mark=box('Coastal_Water_Glint',(x,y,-.065),(1.4,.08,.025),MATS['foam'],'Water',.015);mark.rotation_euler.z=a+math.pi/2
    print({'stage':'terrain','vertices':len(terrain.data.vertices),'faces':len(terrain.data.polygons)})


def bridge(name,a,b,width=3.5):
    a,b=Vector(a),Vector(b);direction=(b-a).normalized();side=Vector((-direction.y,direction.x))
    length=(b-a).length;count=max(8,math.ceil(length/.42))
    za,zb=height(a.x,a.y)+.16,height(b.x,b.y)+.16
    for i in range(count+1):
        t=i/count;p=a.lerp(b,t);z=za*(1-t)+zb*t+.45*math.sin(math.pi*t)
        plank=box(name+'_Deck',(p.x,p.y,z),(width,.40,.20),MATS['wood_light'],'Bridges_Docks',.045)
        plank.rotation_euler.z=math.atan2(direction.y,direction.x)-math.pi/2
    for sign in [-1,1]:
        posts=[]
        for i in range(6):
            t=i/5;p=a.lerp(b,t)+side*(width/2-.1)*sign;z=za*(1-t)+zb*t+.45*math.sin(math.pi*t)
            cylinder(name+'_Post',(p.x,p.y,z+.62),.12,1.3,MATS['wood'],'Bridges_Docks',10)
            ball(name+'_Cap',(p.x,p.y,z+1.28),(.16,.16,.12),MATS['wood_light'],'Bridges_Docks')
            posts.append((p.x,p.y,z+1.05))
        for i in range(len(posts)-1): beam(name+'_Rail',posts[i],posts[i+1],.15,MATS['wood_light'],'Bridges_Docks')
    ROUTE_RECORDS.append({'name':name,'type':'bridge','endpoints':[list(a),list(b)],'width':width})


def pier_segment(name,a,b,za,zb,width=3.0):
    a,b=Vector(a),Vector(b);direction=(b-a).normalized();side=Vector((-direction.y,direction.x));length=(b-a).length
    count=max(5,math.ceil(length/.42))
    for i in range(count+1):
        t=i/count;p=a.lerp(b,t);z=za*(1-t)+zb*t
        plank=box(name+'_Plank',(p.x,p.y,z),(width,.40,.2),MATS['wood_light'],'Bridges_Docks',.035)
        plank.rotation_euler.z=math.atan2(direction.y,direction.x)-math.pi/2
    for t in [0,.25,.5,.75,1]:
        p=a.lerp(b,t);z=za*(1-t)+zb*t
        for sign in [-1,1]:
            q=p+side*(width/2-.12)*sign
            cylinder(name+'_Pile',(q.x,q.y,(z-.7)/2),.16,z+.7,MATS['wood'],'Bridges_Docks',10)
            cylinder(name+'_Bollard',(q.x,q.y,z+.26),.19,.55,MATS['wood'],'Bridges_Docks',10)
    ROUTE_RECORDS.append({'name':name,'type':'pier','endpoints':[list(a),list(b)],'width':width,'z':[za,zb]})


def road(name,points,width=3.1,material='path',start=None,end=None):
    ribbon(name+'_Edge',points,width+.36,MATS['path_edge'],'Paths',lambda x,y:height(x,y)+.045,True)
    obj,pts=ribbon(name,points,width,MATS[material],'Paths',lambda x,y:height(x,y)+.065,True)
    obj['walkway_width_m']=width
    ROAD_SAMPLES.extend([(p.x,p.y,width) for p in pts])
    ROUTE_RECORDS.append({'name':name,'type':'path','from':start,'to':end,'width':width,'control_points':points})
    return obj


def build_paths_and_plots():
    for p in PLOTS:
        letter=p['letter'];x,y,z=p['x'],p['y'],p['ground_z']
        if letter!='B':
            radius=p['plot_radius']
            pad=cylinder(letter+'_Site_Clearing',(x,y,z+.025),radius,.05,MATS['sand'],'Plots',48)
            pad['plot_letter']=letter;pad['pending_landmark']=letter not in 'ABC'
        socket=empty('LANDMARK_'+letter+'_SOCKET',(x,y,z+.11 if letter!='B' else -.48),'Landmarks',1.0)
        socket['letter']=letter;socket['word']=p['word'];socket['district']=p['district'];socket['target_width_m']=p['target_width'];socket['front_axis']='-Y';socket['asset_status']='pending'
        p['socket_name']=socket.name
        if letter not in 'ABC':
            envelope=box(letter+'_ENVELOPE_EDITOR_ONLY',(x,y,z+3),(p['target_width'],p['target_width'],6),None,'Wayfinding_Editor',0)
            enum_set(envelope,'display_type','WIRE');envelope.hide_render=True;envelope['editor_only']=True
            envelope['letter']=letter;envelope.parent=socket;envelope.matrix_parent_inverse=Matrix.Identity(4)
            envelope.location=(0,0,3);envelope.hide_set(True)
        if letter!='A':
            r=p['target_width']*.5
            pts=[(x,y-r-1.5),(x-r-2,y-.5),(x-r*.55,y-r-3),(x+r+2,y-.5),(x+r*.6,y-r-4.5)]
            for i,(lx,ly) in enumerate(pts,1):
                anchor=empty(letter+'_LOCUS_'+str(i).zfill(2),(lx,ly,height(lx,ly)+.08),'Wayfinding_Editor',.4)
                anchor['memory_sequence']=i;anchor['landmark']=letter;anchor['status']='layout_anchor_pending_site_detail'
    e=lambda l:BY_LETTER[l]['entrance']
    routes=[
        ('A','B',[e('A'),[-46,-29],[-45,-32]]),
        ('B','C',[[-45,-32],[-40,-34],e('C')]),
        ('C','D',[e('C'),[-27,-31],[-21,-27],e('D')]),
        ('D','E',[e('D'),[-30,-16],e('E')]),
        ('E','F',[e('E'),[-47,-13],e('F')]),
        ('F','G',[e('F'),[-62,2],[-58,10],e('G')]),
        ('G','H',[e('G'),[-60,25],e('H')]),
        ('H','I',[e('H'),[-45,34],e('I')]),
        ('I','J',[e('I'),[-29,34],e('J')]),
        ('J','K',[e('J'),[-24,27],e('K')]),
        ('K','L',[e('K'),[-24,25],[-16,31],e('L')]),
        ('L','M',[e('L'),[-2,35],[6,35],e('M')]),
        ('M','N',[e('M'),[23,33],e('N')]),
        ('N','O',[e('N'),[40,26],e('O')]),
        ('O','P',[e('O'),[42,18],e('P')]),
        ('P','Q',[e('P'),[38,10],e('Q')]),
        ('Q','R',[e('Q'),[57,-2],e('R')]),
        ('R','S',[e('R'),[49,-18],e('S')]),
        ('S','T',[e('S'),[43,-27],e('T')]),
        ('T','U',[e('T'),[47,-40],e('U')]),
        ('U','V',[e('U'),[34,-41],[28,-41],[22,-41],e('V')]),
        ('V','W',[e('V'),[20,-50],e('W')]),
        ('W','X',[e('W'),[3,-60],e('X')]),
        ('X','Y',[e('X'),[-17,-54],e('Y')]),
        ('Y','Z',[e('Y'),[-26,-48],e('Z')]),
        ('Z','A',[e('Z'),[-43,-53],[-45,-39],[-42,-30],e('A')]),
    ]
    for a,b,pts in routes:
        material='paving' if a in 'GHIJK' else 'path'
        road('Route_'+a+'_'+b,pts,3.1,material,a,b)
    home=[-3,-23]
    road('Home_West',[home,[-12,-25],e('D')],3.8,'path','HOME','D')
    road('Home_Northwest',[home,[-15,-15],[-23,-5],[-24,7],e('K')],3.5,'path','HOME','K')
    road('Home_East',[home,[8,-24],[18,-23],[25,-23],[32,-23],e('S')],3.8,'path','HOME','S')
    road('Home_Northeast',[home,[8,-16],[17,-7],[24,-7],[31,-7],[33,4],e('P')],3.4,'path','HOME','P')
    road('Home_South',[home,[5,-30],[11,-34],e('V')],3.4,'path','HOME','V')
    road('Home_Porch',[home,[-3,-19],[-3,-16]],3.0,'path','HOME','HOME_PORCH')
    for name,a,b in [('North_Bridge',(18.2,-7),(30.2,-7)),('Village_Bridge',(19,-23),(31,-23)),('South_Bridge',(22,-41),(34,-41))]: bridge(name,a,b)
    pier_segment('B_Pier_Ramp',(-45,-32),(-45,-47.5),height(-45,-32)+.12,1.85,3.1)
    pier_segment('B_Pier_Landing',(-45,-47.5),(-55,-47.5),1.85,1.85,3.5)
    # A southern shore boardwalk ties the ocean-facing sites together.
    pier_segment('W_Seaside_Jetty',(12,-59),(12,-64),height(12,-59)+.1,.9,2.8)
    SCENE['alphabet_route']='ABCDEFGHIJKLMNOPQRSTUVWXYZ';SCENE['main_path_width_m']=3.1
    print({'stage':'paths_and_plots','sockets':26,'route_segments':len(ROUTE_RECORDS)})


def source_for(letter):
    root=PROJECT/'assets'/'tripo'
    if letter=='A': return root/'A_apple_house'/'A_apple_house_optimized_v02.glb'
    found=list(root.glob(letter+'_*.glb'))
    exact=root/(letter+'.glb')
    if exact.exists():found.append(exact)
    return max(found,key=lambda p:p.stat().st_mtime) if found else None


def refresh_landmarks(letters=None):
    import hashlib,struct
    for p in PLOTS:
        letter=p['letter'];source=source_for(letter)
        if letters is not None and letter not in letters:continue
        if not source or not source.exists(): continue
        raw=source.read_bytes()
        if len(raw)<20 or raw[:4]!=b'glTF' or struct.unpack('<I',raw[8:12])[0]!=len(raw): continue
        digest=hashlib.sha256(raw).hexdigest()
        socket=bpy.data.objects[p['socket_name']]
        if socket.get('source_sha256')==digest: continue
        # Only replace assets under this world socket; all source files are read-only.
        for child in list(socket.children_recursive):
            if child.get('editor_only'): continue
            bpy.data.objects.remove(child,do_unlink=True)
        before=set(bpy.data.objects)
        bpy.context.window.scene=SCENE
        bpy.ops.import_scene.gltf(filepath=str(source))
        imported=[o for o in bpy.data.objects if o not in before]
        mesh_objects=[o for o in imported if o.type=='MESH']
        corners=[o.matrix_world@Vector(v) for o in mesh_objects for v in o.bound_box]
        mn=Vector([min(v[k] for v in corners) for k in range(3)]);mx=Vector([max(v[k] for v in corners) for k in range(3)])
        factor=p['target_width']/(mx.x-mn.x)
        root=empty(letter+'_MODEL_ROOT',(0,0,0),'Landmarks',.4);root.parent=socket
        root.matrix_local=Matrix.Scale(factor,4)@Matrix.Translation(Vector((-(mn.x+mx.x)/2,-(mn.y+mx.y)/2,-mn.z)))
        for i,o in enumerate(imported):
            is_top=o.parent not in imported
            old=o.matrix_world.copy()
            for c in list(o.users_collection): c.objects.unlink(o)
            COLLS['Landmarks'].objects.link(o)
            o.name='ALPHA_'+letter+'_Tripo_'+str(i).zfill(2)
            o['alphabet_island']=True;o['landmark']=letter
            if is_top: o.parent=root;o.matrix_local=old
        socket['asset_status']='imported';socket['source_file']=str(source);socket['source_sha256']=digest
        for key in ['map_asset_budget_version','map_texture_max_px','map_geometry_target_triangles','map_source_triangles','map_triangles','map_optimization_record']:
            if key in socket:del socket[key]
        socket['normalized_width_m']=p['target_width']
        for o in list(COLLS['Wayfinding_Editor'].objects):
            if o.get('letter')==letter and o.get('editor_only'): o.hide_set(True)
        triangles=0
        for o in mesh_objects: o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
        record={'letter':letter,'source_file':str(source),'source_sha256':digest,'triangles':triangles,'target_width':p['target_width'],'socket':socket.name,'location':list(socket.location)}
        ASSET_RECORDS[:]=[r for r in ASSET_RECORDS if r['letter']!=letter];ASSET_RECORDS.append(record)
        print({'imported':letter,'triangles':triangles,'width':p['target_width']})
    SCENE['pending_landmarks']=''.join(p['letter'] for p in PLOTS if bpy.data.objects[p['socket_name']].get('asset_status')!='imported')


def copy_orchard():
    # Reuse the approved A surroundings, excluding its standalone island and creek.
    p=BY_LETTER['A'];shift=Matrix.Translation(Vector((p['x'],p['y']-3.35,p['ground_z']-.65)))
    names=['A_02_Orchard','A_03_Fences','A_04_Memory_Loci','A_05_Dressing']
    needed=names+['A_01_Paths_Water']
    missing=[name for name in needed if name not in bpy.data.collections]
    if missing:
        source=BASE.parent/'A_orchard'/'A_orchard_with_apple_house_v02.blend'
        if not source.exists(): raise FileNotFoundError(source)
        with bpy.data.libraries.load(str(source),link=False) as (available,requested):
            requested.collections=[name for name in missing if name in available.collections]
    source_objects=[]
    for name in names:
        if name in bpy.data.collections: source_objects.extend(list(bpy.data.collections[name].objects))
    if 'A_01_Paths_Water' in bpy.data.collections:
        source_objects.extend(o for o in bpy.data.collections['A_01_Paths_Water'].objects if o.name.startswith(('A_Path_','A_Welcome_Court')))
    count=0
    for old in source_objects:
        if old.name.startswith('ALPHA_'): continue
        obj=old.copy();obj.name='ALPHA_ORCHARD_'+old.name
        COLLS['Orchard'].objects.link(obj);obj.parent=None;obj.matrix_world=shift@old.matrix_world
        obj['alphabet_island']=True;obj['reused_from']='A orchard v02'
        if old.type=='EMPTY' and old.name.startswith('A_LOCUS_'):
            obj['landmark']='A';obj['memory_sequence']=int(old.name.split('_')[2])
        count+=1
    print({'stage':'orchard_reused','objects':count})


def arch_panel(name,x,y,z,width,h,depth,mat,group):
    r=width/2;pts=[(-r,0),(r,0)]
    pts += [(r*math.cos(a*math.pi/12),h-r+r*math.sin(a*math.pi/12)) for a in range(13)]
    n=len(pts);verts=[(x+px,y+dy,z+pz) for dy in [-depth/2,depth/2] for px,pz in pts]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,mat,group)


def ring(name,loc,radius,tube,mat,group):
    n,m=40,8;verts=[];faces=[]
    for i in range(n):
        a=i*math.tau/n
        for j in range(m):
            b=j*math.tau/m;r=radius+tube*math.cos(b)
            verts.append((loc[0]+r*math.cos(a),loc[1]+r*math.sin(a),loc[2]+tube*math.sin(b)))
    for i in range(n):
        for j in range(m): faces.append((i*m+j,((i+1)%n)*m+j,((i+1)%n)*m+(j+1)%m,i*m+(j+1)%m))
    obj=mesh(name,verts,faces,mat,group)
    for p in obj.data.polygons: p.use_smooth=True
    return obj


def bench(name,x,y,angle=0):
    z=height(x,y);created=[]
    def part(suffix,local,size,mat):
        dx,dy,dz=local;xx=x+dx*math.cos(angle)-dy*math.sin(angle);yy=y+dx*math.sin(angle)+dy*math.cos(angle)
        obj=box(name+suffix,(xx,yy,z+dz),size,mat,'Street_Furniture',.04);obj.rotation_euler.z=angle;created.append(obj)
    for dy in [-.24,0,.24]: part('_Seat',(0,dy,.55),(2.0,.21,.12),MATS['wood_light'])
    for dx in [-.72,.72]:
        part('_Leg',(dx,0,.27),(.14,.60,.54),MATS['wood'])
        part('_Back_Post',(dx,.33,.78),(.12,.12,1.15),MATS['wood'])
    for zz in [.95,1.19]: part('_Back',(0,.33,zz),(2.0,.12,.19),MATS['wood_light'])


def lamp(name,x,y):
    z=height(x,y)
    cylinder(name+'_Pole',(x,y,z+1.35),.085,2.7,MATS['wood_dark'],'Street_Furniture',10)
    box(name+'_Glow',(x,y,z+2.76),(.42,.42,.55),MATS['glass'],'Street_Furniture',.06)
    cylinder(name+'_Cap',(x,y,z+3.12),.39,.26,MATS['wood_dark'],'Street_Furniture',4,top=.08)


def flowers(name,x,y,mat,count=8,radius=1.0):
    for i in range(count):
        a=RNG.random()*math.tau;r=math.sqrt(RNG.random())*radius;xx=x+r*math.cos(a);yy=y+r*math.sin(a);zz=height(xx,yy)
        cylinder(name+'_Stem',(xx,yy,zz+.22),.025,.44,MATS['leaf'],'Gardens',5)
        ball(name+'_Petals',(xx,yy,zz+.45),(.18,.18,.10),mat,'Gardens')
        ball(name+'_Center',(xx,yy,zz+.53),(.07,.07,.05),MATS['yellow'],'Gardens')


def tree(name,x,y,scale=1.0,pine=False):
    z=height(x,y)
    cylinder(name+'_Trunk',(x,y,z+1.2*scale),.23*scale,2.4*scale,MATS['bark'],'Forest',9,top=.17*scale)
    if pine:
        for i,(rad,h,zc) in enumerate([(1.65,2.5,2.65),(1.35,2.3,3.55),(.95,1.95,4.4)]):
            obj=cylinder(name+'_Needles_'+str(i),(x,y,z+zc*scale),rad*scale,h*scale,MATS['pine' if i!=1 else 'leaf'],'Forest',9,top=.10*scale)
            bevel(obj,.045*scale)
    else:
        for i,(dx,dy,dz,r) in enumerate([(-.75,0,3.15,1.5),(.75,.15,3.4,1.55),(0,.15,4.2,1.5)]):
            ball(name+'_Crown_'+str(i),(x+dx*scale,y+dy*scale,z+dz*scale),(r*scale,r*.86*scale,r*.92*scale),MATS['leaf' if i==0 else 'leaf_light'],'Forest')


def build_home():
    x,y=-3,-14;z=5.4
    box('Home_Stone_Foundation',(x,y,z+.12),(6.8,5.6,.24),MATS['rock_light'],'Home',.14)
    box('Home_Cream_Walls',(x,y,z+1.98),(6.2,5.0,3.7),MATS['cream'],'Home',.13)
    # Solid two-sided gable roof with broad eaves.
    verts=[(x-3.65,y-3.0,z+3.6),(x,y-3.0,z+5.85),(x+3.65,y-3.0,z+3.6),(x-3.65,y+3.0,z+3.6),(x,y+3.0,z+5.85),(x+3.65,y+3.0,z+3.6)]
    roof=mesh('Home_Terracotta_Roof',verts,[(0,1,4,3),(1,2,5,4),(0,2,1),(3,4,5),(0,3,5,2)],MATS['roof'],'Home');bevel(roof,.12)
    for yy in [y-3.02,y+3.02]:
        beam('Home_Roof_Edge',(x-3.66,yy,z+3.60),(x,yy,z+5.87),.20,MATS['wood_light'],'Home')
        beam('Home_Roof_Edge',(x,yy,z+5.87),(x+3.66,yy,z+3.60),.20,MATS['wood_light'],'Home')
    for xx in [x-3.02,x+3.02]: box('Home_Corner_Timber',(xx,y-2.55,z+1.98),(.20,.20,3.7),MATS['wood'],'Home')
    arch_panel('Home_Door_Frame',x,y-2.61,z+.24,1.75,2.55,.25,MATS['wood'],'Home')
    arch_panel('Home_Door',x,y-2.77,z+.25,1.42,2.32,.12,MATS['wood_light'],'Home')
    glass=box('Home_Door_Glass',(x,y-2.86,z+1.78),(.65,.08,.72),MATS['glass'],'Home',.10)
    ball('Home_Door_Handle',(x+.48,y-2.94,z+1.05),(.09,.07,.09),MATS['yellow'],'Home')
    for dx in [-2.05,2.05]:
        arch_panel('Home_Window_Frame',x+dx,y-2.64,z+1.55,1.18,1.43,.19,MATS['wood'],'Home')
        arch_panel('Home_Window_Glass',x+dx,y-2.76,z+1.65,.94,1.20,.10,MATS['glass'],'Home')
        box('Home_Window_Cross',(x+dx,y-2.84,z+2.21),(.07,.07,1.10),MATS['wood_light'],'Home')
        box('Home_Window_Cross',(x+dx,y-2.85,z+2.17),(.92,.07,.07),MATS['wood_light'],'Home')
    box('Home_Porch',(x,y-3.6,z+.14),(4.0,2.2,.28),MATS['wood_light'],'Home',.10)
    box('Home_Entry_Step',(x,y-4.9,z+.08),(2.2,.6,.16),MATS['rock_light'],'Home',.07)
    box('Home_Chimney',(x+1.85,y+.7,z+5.6),(.8,.9,2.4),MATS['rock_light'],'Home',.10)
    box('Home_Chimney_Cap',(x+1.85,y+.7,z+6.85),(1.05,1.1,.25),MATS['wood_dark'],'Home',.05)
    cylinder('Home_Plaza_Rim',(-3,-23,z+.06),5.2,.12,MATS['path_edge'],'Home',64)
    cylinder('Home_Plaza',(-3,-23,z+.14),4.95,.12,MATS['path'],'Home',64)
    cylinder('Home_Fountain_Base',(-3,-23,z+.32),1.45,.38,MATS['rock_light'],'Home',48)
    ring('Home_Fountain_Lip',(-3,-23,z+.58),1.30,.17,MATS['cream'],'Home')
    cylinder('Home_Fountain_Water',(-3,-23,z+.55),1.19,.045,MATS['water'],'Home',48)
    cylinder('Home_Fountain_Column',(-3,-23,z+.90),.25,.72,MATS['rock'],'Home',16)
    ball('Home_Fountain_Top',(-3,-23,z+1.34),(.44,.44,.22),MATS['rock_light'],'Home')
    for px,py in [(-8,-20),(2,-20),(-7.5,-27),(1.5,-27)]: flowers('Home_Flowerbed',px,py,MATS['pink'],10,.9)
    bench('Home_Bench_West',-7.2,-24,math.pi/2);bench('Home_Bench_East',1.3,-24,-math.pi/2)
    lamp('Home_Lamp_West',-8,-19);lamp('Home_Lamp_East',2,-19)
    box('Home_Mailbox_Post',(-7.7,-17.3,z+.62),(.20,.20,1.24),MATS['wood'],'Home')
    box('Home_Mailbox',(-7.7,-17.3,z+1.36),(.75,.65,.65),MATS['teal'],'Home',.16)
    box('Home_Mailbox_Slot',(-7.7,-17.64,z+1.42),(.42,.045,.06),MATS['wood_dark'],'Home',.01)
    empty('PLAYER_SPAWN',(-3,-28.4,5.6),'Wayfinding_Editor',.6)['purpose']='Player start outside home plaza'
    print({'stage':'central_home'})


def fence(name,points):
    for j,(a,b) in enumerate(zip(points,points[1:])):
        count=max(1,math.ceil(math.dist(a,b)/2.0));posts=[]
        for i in range(count+1):
            t=i/count;x=a[0]*(1-t)+b[0]*t;y=a[1]*(1-t)+b[1]*t;z=height(x,y)
            cylinder(name+'_Post',(x,y,z+.55),.11,1.1,MATS['wood'],'Gardens',9)
            ball(name+'_Cap',(x,y,z+1.12),(.14,.14,.1),MATS['wood_light'],'Gardens')
            posts.append((x,y,z))
        for u,v in zip(posts,posts[1:]):
            for dz in [.4,.85]: beam(name+'_Rail',(u[0],u[1],u[2]+dz),(v[0],v[1],v[2]+dz),.10,MATS['wood_light'],'Gardens')


def palm(name,x,y,s=1):
    z=height(x,y);joints=[(x,y,z),(x+.1*s,y,z+1.6*s),(x+.5*s,y,z+3.2*s),(x+.7*s,y,z+4.4*s)]
    for a,b in zip(joints,joints[1:]): beam(name+'_Trunk',a,b,.42*s,MATS['bark'],'Forest',False)
    cx,cy,cz=joints[-1]
    for i in range(7):
        a=i*math.tau/7
        leaf=ball(name+'_Frond',(cx+1.05*s*math.cos(a),cy+1.05*s*math.sin(a),cz+.08*s),(1.5*s,.4*s,.14*s),MATS['leaf'],'Forest')
        leaf.rotation_euler.z=a;leaf.rotation_euler.y=.22
    for dx in [-.25,.25]: ball(name+'_Coconut',(cx+dx,cy,cz-.18),(.26*s,.26*s,.31*s),MATS['wood'],'Forest')


def decorate():
    # Forest density gives the five areas their character without covering entrances.
    placed=[]
    for attempt in range(6000):
        if len(placed)>=225: break
        x=RNG.uniform(-70,70);y=RNG.uniform(-57,59)
        if y<-10 and RNG.random()<.55: continue
        if land_ratio(x,y)>.915 or height(x,y)<2.2: continue
        if math.hypot(x/23,(y-7)/19)<1 or river_query(x,y)[0]<6: continue
        if math.hypot((x+3)/12,(y+18)/15)<1: continue
        if any(math.hypot(x-p['x'],y-p['y'])<p['plot_radius']+2.5 for p in PLOTS): continue
        if any(abs(x-p['x'])<p['target_width']*.55+2 and p['y']-13<y<p['y']+1 for p in PLOTS): continue
        if math.hypot(x+50,y+25)<13: continue
        if any((x-px)**2+(y-py)**2<(width*.5+2.1)**2 for px,py,width in ROAD_SAMPLES): continue
        if any((x-a)**2+(y-b)**2<3.7**2 for a,b in placed): continue
        placed.append((x,y));tree('Forest_'+str(len(placed)).zfill(3),x,y,RNG.uniform(.75,1.13),pine=(y>13 and RNG.random()<.70))
    # Coastal rock groupings break up the shoreline silhouette.
    for i in range(68):
        a=math.tau*i/68;f=coast_radius(a)*RNG.uniform(.927,.956);x=74*math.cos(a)*f;y=64*math.sin(a)*f
        if math.hypot(x+55,y+43)<14 or any(math.hypot(x-p['x'],y-p['y'])<p['plot_radius']+2 for p in PLOTS): continue
        z=height(x,y)
        ball('Coastal_Boulder',(x,y,z+.35),(RNG.uniform(1,2),RNG.uniform(.8,1.5),RNG.uniform(.8,1.6)),MATS['rock' if i%2 else 'rock_light'],'Terrain')
    for i,(x,y,s) in enumerate([(-44,-53,.75),(-39,-58,.8),(-22,-57,.85),(-11,-62,.7),(1,-57,.8),(24,-55,.9),(35,-51,.8),(45,-44,.85)]):
        if height(x,y)>0: palm('Beach_Palm_'+str(i),x,y,s)
    # Shore reeds and water glints remain clear of the three bridge decks.
    riverpts=sampled(RIVER,8)
    for i,p in enumerate(riverpts):
        if i%2 or min(abs(p.y-v) for v in [-7,-23,-41])<3: continue
        glint=box('River_Glint',(p.x,p.y,river_query(p.x,p.y)[1]+.055),(.9,.055,.012),MATS['foam'],'Water',.01)
        for side in [-1,1]:
            xx=p.x+side*3.4;yy=p.y+.35;zz=height(xx,yy)
            ball('Riverbank_Rock',(xx,yy,zz+.28),(.6,.47,.48),MATS['rock_light'],'Water')
            for k in range(3): beam('River_Reed',(xx+.13*k,yy,zz),(xx+.13*k+.08,yy,zz+.7+k*.1),.055,MATS['leaf'],'Gardens',False)
    # The lake islet gains a quiet shade tree.
    tree('Lake_Islet_Tree',7,8,.72,False)
    # Planting beds at F; flowers are actual scene objects, not texture planes.
    for i,(x,y) in enumerate([(-61,2),(-57,4),(-52,4),(-62,-3),(-48,0),(-50,7)]):
        ribbon('F_Planting_Bed',[(x-1,y),(x+1,y)],1.0,MATS['soil'],'Gardens',lambda a,b:height(a,b)+.055)
        flowers('F_Flowers',x,y,MATS[['pink','yellow','lavender'][i%3]],9,1.0)
    fence('F_Garden_Fence',[(-63,-2),(-63,6),(-49,8)])
    # Pumpkin-farm rows north-west of P.
    for j in range(4):
        yy=26+j*1.5
        ribbon('P_Farm_Row',[(18,yy),(24,yy)],.9,MATS['soil'],'Gardens',lambda a,b:height(a,b)+.055)
        for k in range(6):
            xx=18.4+k;zz=height(xx,yy)
            ball('P_Crop',(xx,yy,zz+.28),(.35,.34,.28),MATS['yellow' if (j+k)%3==0 else 'leaf'],'Gardens')
    fence('P_Farm_Fence',[(17,25),(17,32.5),(25,32.5)])
    # C has an outdoor bakery terrace on each side of its entrance.
    cp=BY_LETTER['C']
    for x,y in [(-38,-32),(-28,-32)]:
        z=height(x,y)
        cylinder('C_Cafe_Table_Leg',(x,y,z+.46),.13,.92,MATS['wood'],'Street_Furniture',10)
        cylinder('C_Cafe_Table',(x,y,z+.98),.75,.14,MATS['wood_light'],'Street_Furniture',24)
        for dx in [-1.15,1.15]:
            cylinder('C_Cafe_Stool',(x+dx,y,z+.28),.16,.56,MATS['wood'],'Street_Furniture',10)
            cylinder('C_Cafe_Stool_Top',(x+dx,y,z+.60),.39,.12,MATS['pink'],'Street_Furniture',16)
    flowers('C_Flowerbed',-37.5,-37,MATS['pink'],7,.7);flowers('C_Flowerbed',-28.5,-37,MATS['yellow'],7,.7)
    # Music gathering circle, rail approach, and quiet science courtyard.
    dp=BY_LETTER['D'];cylinder('D_Music_Court',(-24,-27,height(-24,-27)+.05),3.0,.10,MATS['wood_light'],'Gardens',48)
    tp=BY_LETTER['T'];tz=tp['ground_z']
    for i in range(23): box('T_Rail_Sleeper',(tp['x']-10+i*.9,tp['y'],tz+.06),(.48,3.2,.14),MATS['wood_dark'],'Gardens',.025)
    for dy in [-1,1]: beam('T_Station_Rail',(tp['x']-10,tp['y']+dy,tz+.19),(tp['x']+10,tp['y']+dy,tz+.19),.16,MATS['rock'],'Gardens')
    vp=BY_LETTER['V']
    for i in range(7):
        a=.3+i*.44;x=vp['x']+6.6*math.cos(a);y=vp['y']+6.1*math.sin(a)
        ball('V_Observation_Rock',(x,y,height(x,y)+.45),(1.1,.9,.9),MATS['rock'],'Gardens')
    # Benches and warm lamps mark useful route junctions.
    for i,(x,y,a) in enumerate([(-44,20,0),(-18,28,0),(-6,31,0),(21,35,0),(43,18,0),(47,-20,0),(35,-44,0),(-17,-48,0),(9,-27,0)]):
        bench('District_Bench_'+str(i),x,y,a)
    for i,(x,y) in enumerate([(-45,-28),(-29,-29),(-43,-12),(-59,10),(-43,32),(-15,31),(4,34),(26,32),(44,20),(45,3),(53,-18),(42,-36),(19,-45),(-13,-55),(8,-27),(16,-21),(33,-21)]):
        lamp('Path_Lamp_'+str(i),x,y)
    # Short fences separate gardens from paths while leaving all entries open.
    for p in PLOTS:
        if p['letter'] in 'ABFPTVWX': continue
        x,y=p['x'],p['y'];r=p['plot_radius']+1.3
        fence(p['letter']+'_Rear_Garden_Fence',[(x-r*.7,y+r),(x+r*.7,y+r)])
    print({'stage':'decoration','forest_trees':len(placed),'scene_objects':len(SCENE.objects)})


def aim(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()


def configure_view():
    world=bpy.data.worlds.new('ALPHA_Soft_Daylight');world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.70,.81,.88,1);bg.inputs['Strength'].default_value=.7;SCENE.world=world
    types=[i.identifier for i in bpy.types.Light.bl_rna.properties['type'].enum_items]
    assert 'SUN' in types and 'AREA' in types
    sun_data=bpy.data.lights.new('ALPHA_Sun','SUN');sun_data.energy=2.0;sun_data.angle=.45
    sun=link('Sun',sun_data,'Camera_Lighting');sun.location=(-50,-55,100);aim(sun,(0,0,0))
    fill_data=bpy.data.lights.new('ALPHA_Soft_Fill','AREA');fill_data.energy=16000;fill_data.size=95
    fill=link('Soft_Fill',fill_data,'Camera_Lighting');fill.location=(30,25,85);aim(fill,(0,0,0))
    settings=[('World_Overview',(98,-152,160),(0,-1,3),176),('Morning_Village',(-11,-87,63),(-43,-22,5),59),('Home_Lake',(35,-55,49),(-1,-4,5),51),('World_Top',(0,-.01,200),(0,0,0),158)]
    for name,loc,target,scale in settings:
        data=bpy.data.cameras.new('ALPHA_Camera_'+name);enum_set(data,'type','ORTHO');data.ortho_scale=scale
        cam=link('Camera_'+name,data,'Camera_Lighting');cam.location=loc;aim(cam,target)
    SCENE.camera=bpy.data.objects['ALPHA_Camera_World_Overview']
    SCENE.render.resolution_x=1920;SCENE.render.resolution_y=1440;SCENE.render.resolution_percentage=100
    enum_set(SCENE.render.image_settings,'file_format','PNG');SCENE.render.film_transparent=False
    SCENE.render.filepath=str(BASE/'alphabet_island_overview_v01.png')
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            enum_set(area.spaces.active.region_3d,'view_perspective','CAMERA');area.spaces.active.overlay.show_overlays=False
            enum_set(area.spaces.active.shading,'type','MATERIAL')
    print({'stage':'lighting_and_cameras','camera':SCENE.camera.name})
