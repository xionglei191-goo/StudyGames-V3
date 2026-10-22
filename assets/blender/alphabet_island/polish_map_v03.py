"""Visual polish of the existing alphabet island, preserving landmark/locus transforms.
Run setup(), surfaces(), vegetation(), waterside(), home_details(),
refine_shores(), integrate_lake_terrain(), garden_finishing() once in order.
Geometry planning is stored in polish_plan_v03.json. Source models are unchanged.
"""
import bpy,bmesh,math,json,random
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
import studygame_world as w
BASE=Path(__file__).resolve().parent
R=random.Random(31021)
COLL=None
TREE=None
PLAN=None
M={}
ROAD_KD=None

def hide(obj):
    obj['superseded_by_v03']=True;obj.hide_render=True;obj.hide_set(True)

def setup():
    global COLL,TREE,PLAN,ROAD_KD
    name='ALPHA_Polish_v03'
    if bpy.data.collections.get(name):raise RuntimeError('Polish collection exists. Continue the current pass rather than duplicating it.')
    COLL=bpy.data.collections.new(name);w.SCENE.collection.children.link(COLL);w.COLLS['Polish_v03']=COLL
    TREE=BVHTree.FromObject(bpy.data.objects['ALPHA_Island_Continuous_Terrain'],bpy.context.evaluated_depsgraph_get())
    PLAN=json.loads((BASE/'polish_plan_v03.json').read_text())
    colors={'dirt':(.43,.29,.14),'gravel':(.38,.31,.21),'stone':(.40,.45,.39),'brick':(.48,.26,.13),'wood':(.40,.23,.09),'garden':(.28,.31,.13),'coastal':(.50,.50,.36),'volcanic':(.18,.19,.15),'edge':(.22,.35,.09),'foliage':(.08,.31,.06),'bush':(.07,.29,.08),'grass':(.14,.36,.08),'bark':(.24,.12,.045),'rock':(.37,.40,.33),'reed':(.29,.40,.10),'flower_pink':(.78,.19,.28),'flower_cream':(.88,.76,.42),'flower_blue':(.22,.38,.67),'water':(.03,.40,.49),'foam':(.42,.70,.64),'roof':(.43,.12,.055),'ivory':(.80,.74,.53)}
    for key,rgb in colors.items():M[key]=w.make_material('V3_'+key,rgb,.76 if key!='water' else .3)
    pts=[]
    for route in w.ROUTE_RECORDS:
        if route['type']=='path':pts.extend((p.x,p.y,route['width']) for p in w.sampled(route['control_points'],32))
    ROAD_KD=KDTree(len(pts))
    for i,(x,y,width) in enumerate(pts):ROAD_KD.insert((x,y,0),i)
    ROAD_KD.balance()
    w.SCENE['output_version']='v03'
    print({'polish_initialized':True,'path_sample_count':len(pts)})

def zground(x,y):
    hit,*_=TREE.ray_cast(Vector((x,y,80)),Vector((0,0,-1)),150)
    return hit.z if hit else w.height(x,y)

def noise(x,y,z=0):return .5+.22*math.sin(x*1.37+y*.71+z)+.16*math.sin(x*.41-y*1.91+z*1.17)+.10*math.sin(x*3.3+y*4.1)

def vc_material(name):
    mat=M[name]
    if not any(n.type=='VERTEX_COLOR' for n in mat.node_tree.nodes):
        node=mat.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='Polish_Color'
        bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs['Base Color'])
    return mat

def color_mesh(obj,colors):
    attr=obj.data.color_attributes.get('Polish_Color')
    if not attr:
        params=obj.data.color_attributes.bl_rna.functions['new'].parameters
        assert 'FLOAT_COLOR' in [i.identifier for i in params['type'].enum_items]
        attr=obj.data.color_attributes.new(name='Polish_Color',type='FLOAT_COLOR',domain='POINT')
    for a,c in zip(attr.data,colors):a.color=(*c,1)
    obj.data.color_attributes.active_color=attr

def rgb(mat):return tuple(next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'].default_value[:3])

def surface(name,plan,style,offset=.12):
    verts=[(x,y,zground(x,y)+offset) for x,y in plan['vertices']]
    obj=w.mesh(name,verts,plan['faces'],vc_material(style),'Polish_v03')
    base=rgb(M[style]);colors=[]
    for x,y,z in verts:
        n=noise(x*.7,y*.7)*.18+.88;colors.append(tuple(c*n for c in base))
    color_mesh(obj,colors)
    for poly in obj.data.polygons:poly.use_smooth=True
    return obj

class Batch:
    def __init__(self):self.verts=[];self.faces=[];self.colors=[]
    def add(self,verts,faces,color):
        i=len(self.verts);self.verts.extend(verts);self.faces.extend(tuple(i+v for v in face) for face in faces);self.colors.extend([color]*len(verts))
    def block(self,loc,size,angle,color):
        x,y,z=[s/2 for s in size];cs=math.cos(angle);sn=math.sin(angle)
        verts=[(loc[0]+xx*cs-yy*sn,loc[1]+xx*sn+yy*cs,loc[2]+zz) for xx,yy,zz in [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]]
        self.add(verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],color)
    def emit(self,name,style):
        obj=w.mesh(name,self.verts,self.faces,vc_material(style),'Polish_v03');color_mesh(obj,self.colors);return obj

def surfaces():
    for obj in list(w.COLLS['Paths'].objects):hide(obj)
    for obj in w.COLLS['Site_Detail_v02'].objects:
        if obj.get('entry_connection'):hide(obj)
    for obj in w.COLLS['Plots'].objects:
        if 'Site_Clearing' in obj.name:hide(obj)
    for obj in w.COLLS['Orchard'].objects:
        if 'A_Path_' in obj.name or 'A_Welcome_Court' in obj.name:hide(obj)
    road=surface('V3_Connected_Rounded_Paths',PLAN['road'],'dirt',.115)
    edge=surface('V3_Path_Soft_Shoulder',PLAN['road_edge'],'edge',.075)
    # Distinct soil beds, wooden decks, warm brick and stone forecourts.
    for court in PLAN['courts']:
        l=court['letter'];style=court['style'];surface('V3_'+l+'_Courtyard',court['mesh'],style,.119)
        if court['tiles']:
            batch=Batch();base=rgb(M[style])
            for poly in court['tiles']:
                factor=R.uniform(.87,1.14);color=tuple(c*factor for c in base)
                vs=[(x,y,zground(x,y)+.153+R.uniform(-.003,.003)) for x,y in poly]
                batch.add(vs,[tuple(range(len(vs)))],color)
            obj=batch.emit('V3_'+l+'_Paving_Inlay',style)
            obj['courtyard_letter']=l
    # Short, uneven edging stones give the paths a tactile boundary.
    curb=Batch();count=0
    for ring in PLAN['road_rings']:
        distance=0
        for a,b in zip(ring,ring[1:]):
            dx,dy=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dy)
            if length==0:continue
            t=.0
            while t<length:
                distance+=.52
                q=min(1,(t+.25)/length);x=a[0]+dx*q;y=a[1]+dy*q
                # Forest paths keep softer plant edges; street corners get stones.
                if (x<-25 and y>12) or (x>34 and -37<y<16) or count%4==0:
                    shade=R.uniform(.82,1.16);color=tuple(c*shade for c in (.38,.37,.26))
                    curb.block((x,y,zground(x,y)+.15),(.46,.13,.10),math.atan2(dy,dx),color);count+=1
                t+=.64
    obj=curb.emit('V3_Path_Edging_Stones','stone');w.bevel(obj,.025)
    print({'rounded_path_triangles':len(road.data.polygons),'courts':len(PLAN['courts']),'edge_stones':count})

def make_canopy(index):
    data=bpy.data.metaballs.new('V3_Canopy_Form_'+str(index));data.resolution=.28;data.render_resolution=.24;data.threshold=.65
    obj=bpy.data.objects.new('ALPHA_V3_Canopy_Form_'+str(index),data);COLL.objects.link(obj)
    points=[(-.85,0,2.95,1.5),(.85,.2,3.1,1.5),(0,.1,4,1.45),(-.15,-.65,3.35,1.15),(.1,.7,3.3,1.2)]
    for x,y,z,r in points:
        e=data.elements.new();e.co=(x+R.uniform(-.15,.15),y+R.uniform(-.15,.15),z+R.uniform(-.15,.15));e.radius=r*(.93+.05*index)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    allowed=[i.identifier for i in bpy.ops.object.convert.get_rna_type().properties['target'].enum_items];assert 'MESH' in allowed
    bpy.ops.object.convert(target='MESH')
    obj=bpy.context.view_layer.objects.active
    for p in obj.data.polygons:p.use_smooth=True
    obj.data.materials.append(vc_material('foliage'))
    colors=[]
    for v in obj.data.vertices:
        f=.72+.25*noise(v.co.x,v.co.y,v.co.z)+.12*max(0,v.co.z-2)
        colors.append((.065*f,.30*f,.065*f))
    color_mesh(obj,colors);mesh=obj.data;bpy.data.objects.remove(obj,do_unlink=True);return mesh

def pine_mesh():
    verts=[];faces=[];colors=[];n=20;rings=9
    for tier,(basez,height,radius) in enumerate([(1.65,2.0,1.70),(2.65,1.9,1.36),(3.65,1.65,1.0)]):
        start=len(verts)
        for j in range(rings):
            t=j/(rings-1);r=radius*(1-t)**.75+.035
            for i in range(n):
                a=i*math.tau/n;rr=r*(1+.10*math.sin(3*a+tier)+.05*math.cos(5*a))
                z=basez+height*t-.12*(1-t)*math.cos(a*3+tier)
                verts.append((rr*math.cos(a),rr*math.sin(a),z));f=.8+.35*t+R.uniform(-.05,.05);colors.append((.045*f,.23*f,.09*f))
        for j in range(rings-1):
            for i in range(n):
                a=start+j*n+i;b=start+j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
        faces.append(tuple(reversed(range(start,start+n))))
    obj=w.mesh('V3_Pine_Template',verts,faces,vc_material('foliage'),'Polish_v03');color_mesh(obj,colors)
    for p in obj.data.polygons:p.use_smooth=True
    mesh=obj.data;bpy.data.objects.remove(obj,do_unlink=True);return mesh

def safe_plant(x,y,margin=1):
    if w.land_ratio(x,y)>.91:return False
    if math.hypot(x/21,(y-7)/17)<1.04 or w.river_query(x,y)[0]<4.0:return False
    if any(math.hypot(x-p['x'],y-p['y'])<p['target_width']*.55+1.4 for p in w.PLOTS):return False
    _,_,dist=ROAD_KD.find((x,y,0))
    return dist>2.0+margin

def vegetation():
    canopies=[make_canopy(i) for i in range(3)];pine=pine_mesh();replaced=0;branches=Batch();grass=Batch();flowers=Batch()
    trunks=[o for o in w.COLLS['Forest'].objects if '_Trunk' in o.name and o.name.startswith(('ALPHA_Forest_','ALPHA_Lake_Islet_Tree'))]
    for trunk in trunks:
        prefix=trunk.name.rsplit('_Trunk',1)[0];members=[o for o in w.COLLS['Forest'].objects if o.name.startswith(prefix+'_')]
        is_pine=any('Needles' in o.name for o in members);scale=trunk.dimensions.z/2.4
        base=Vector((trunk.location.x,trunk.location.y,trunk.location.z-trunk.dimensions.z/2))
        for obj in members:
            if 'Crown' in obj.name or 'Needles' in obj.name:hide(obj)
        obj=w.link('V3_Tree_Canopy_'+str(replaced),pine if is_pine else canopies[replaced%3],'Polish_v03');obj.location=base;obj.scale=(scale,scale,scale);obj.rotation_euler.z=R.random()*math.tau;obj['tree_source']=prefix
        if not is_pine:obj.scale.x*=1.20;obj.scale.y*=1.20
        if trunk.get('entry_sightline_reduced'):obj['entry_sightline_reduced']=True
        replaced+=1
    # Clustered meadow tufts and flowers, keeping building entries and roads clear.
    clusters=[]
    for _ in range(600):
        x,y=R.uniform(-66,66),R.uniform(-55,54)
        if safe_plant(x,y,.4):clusters.append((x,y))
        if len(clusters)>=145:break
    for ci,(x,y) in enumerate(clusters):
        for t in range(R.randint(5,11)):
            xx=x+R.uniform(-1.2,1.2);yy=y+R.uniform(-1.0,1.0)
            if not safe_plant(xx,yy,.15):continue
            z=zground(xx,yy)
            for k in range(5):
                a=R.random()*math.tau;h=R.uniform(.16,.42);wid=.055;dx=math.cos(a);dy=math.sin(a)
                grass.add([(xx-dy*wid,yy+dx*wid,z),(xx+dy*wid,yy-dx*wid,z),(xx+dx*.10,yy+dy*.10,z+h)],[(0,1,2)],(.13+R.random()*.06,.31+R.random()*.08,.055))
            if ci%3==0:
                h=R.uniform(.22,.46);color=[(.78,.22,.30),(.9,.77,.43),(.28,.42,.75)][ci%9//3]
                for j in range(5):
                    a=j*math.tau/5;cx=xx+.11*math.cos(a);cy=yy+.11*math.sin(a)
                    flowers.add([(cx-.08,cy,z+h),(cx,cy-.09,z+h+.035),(cx+.08,cy,z+h),(cx,cy+.09,z+h+.035)],[(0,1,2,3)],color)
    grass.emit('V3_Meadow_Grass_Clumps','grass');flowers.emit('V3_Wildflower_Patches','flower_pink')
    print({'tree_canopies_replaced':replaced,'meadow_clusters':len(clusters),'meadow_blades':len(grass.faces)})

def waterside():
    # A continuous, irregular shoreline replaces the perfect ellipse and bead-like rocks.
    for o in list(w.COLLS['Water'].objects):
        if o.name=='ALPHA_Central_Lake' or 'Lake_Shore_Rock' in o.name:hide(o)
    n=256;nr=18;verts=[(0,7,4.69)];colors=[(.025,.22,.29)];faces=[]
    def outline(a):return 1+.032*math.sin(3*a+.8)+.022*math.cos(7*a-.3)+.012*math.sin(11*a)
    for j in range(1,nr+1):
        t=j/nr
        for i in range(n):
            a=i*math.tau/n;r=outline(a)*t
            verts.append((20.1*r*math.cos(a),7+16.1*r*math.sin(a),4.69))
            f=t**3;colors.append((.025+.055*f,.22+.20*f,.29+.13*f))
    for i in range(n):faces.append((0,1+i,1+(i+1)%n))
    for j in range(nr-1):
        a=1+j*n;b=a+n
        for i in range(n):faces.append((a+i,b+i,b+(i+1)%n,a+(i+1)%n))
    o=w.mesh('V3_Lake_Deep_To_Shallow',verts,faces,vc_material('water'),'Polish_v03');color_mesh(o,colors)
    bank=Batch();ripples=Batch();reeds=Batch();lilies=Batch()
    for i in range(n):
        a=i*math.tau/n;b=(i+1)*math.tau/n
        vs=[]
        for t in [0,.3,.65,1]:
            for angle in [a,b]:
                r=outline(angle)+(1.115-outline(angle))*t
                x=20.1*r*math.cos(angle);y=7+16.1*r*math.sin(angle)
                zg=zground(x,y)
                z=4.67+(max(zg,4.72)-4.67)*math.sin(t*math.pi/2)
                vs.append((x,y,z+.018))
        mid=vs[3]
        if w.river_query(mid[0],mid[1])[0]>3.15:
            for j in range(3):
                shade=.9+.12*noise(mid[0],mid[1]);c=(.34*shade,.41*shade,.18*shade) if j>0 else (.43*shade,.44*shade,.25*shade)
                bank.add(vs[j*2:j*2+4],[(0,1,3,2)],c)
    bank.emit('V3_Natural_Lake_Bank','garden')
    # Sparse rock groups and reeds leave the house/jetty sightline open.
    for cluster,a in enumerate([.4,.8,1.2,1.65,2.05,2.6,3.05,3.55,4.0,4.65,5.05]):
        for j in range(R.randint(2,4)):
            aa=a+R.uniform(-.09,.09);r=outline(aa)+R.uniform(.015,.05)
            x=20.1*r*math.cos(aa);y=7+16.1*r*math.sin(aa)
            z=max(4.67,zground(x,y))
            if w.river_query(x,y)[0]<4:continue
            size=R.uniform(.28,.74)
            o=w.ball('V3_Shore_Rock',(x,y,z+size*.25),(size,size*.76,size*.52),M['rock'],'Polish_v03');o.rotation_euler.z=R.random()*math.tau
        for j in range(12):
            aa=a+R.uniform(-.12,.12);r=outline(aa)+R.uniform(-.01,.035)
            x=20.1*r*math.cos(aa);y=7+16.1*r*math.sin(aa);z=max(4.68,zground(x,y))
            if w.river_query(x,y)[0]<4:continue
            for k in range(3):
                an=R.random()*math.tau;h=R.uniform(.4,.95);dx,dy=math.cos(an),math.sin(an)
                reeds.add([(x-dy*.035,y+dx*.035,z),(x+dy*.035,y-dx*.035,z),(x+dx*.16,y+dy*.16,z+h)],[(0,1,2)],(.25,.39,.085))
    reeds.emit('V3_Lakeside_Reed_Clusters','reed')
    for cx,cy in [(-13,13),(-11,18),(4,19),(12,16),(-15,4)]:
        for j in range(5):
            x=cx+R.uniform(-1.2,1.2);y=cy+R.uniform(-.9,.9);r=R.uniform(.19,.37)
            vs=[(x,y,4.712)]+[(x+r*math.cos(a),y+r*math.sin(a),4.712) for a in [k*math.tau/14 for k in range(14)]]
            lilies.add(vs,[(0,k,k+1) for k in range(1,14)],(.13,.37,.09))
    lilies.emit('V3_Lily_Pads','foliage')
    # Broken ripple arcs and a shallow coastal color band use geometry/vertex colors.
    for j in range(28):
        x,y=R.uniform(-16,16),R.uniform(-6,20)
        if math.hypot(x/18,(y-7)/14)>.92 or math.hypot(x-7,y-8)<4:continue
        length=R.uniform(.55,1.4)
        vs=[]
        for k in range(7):
            xx=x+(k/6-.5)*length;yy=y+.04*math.sin(k/6*math.pi)
            vs.extend([(xx,yy,4.715),(xx,yy+.022,4.715)])
        ripples.add(vs,[(2*k,2*k+1,2*k+3,2*k+2) for k in range(6)],(.24,.51,.50))
    ripples.emit('V3_Lake_Ripple_Strokes','foam')
    verts=[];faces=[];cols=[]
    for r in [1.025,1.06,1.115,1.19]:
        for i in range(n):
            a=i*math.tau/n;f=w.coast_radius(a)*r;verts.append((74*f*math.cos(a),64*f*math.sin(a),-.035))
            t=(r-1.025)/.165;cols.append((.08-.035*t,.43-.12*t,.44-.03*t))
    for j in range(3):
        for i in range(n):a=j*n+i;b=j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
    o=w.mesh('V3_Coastal_Shallow_Water',verts,faces,vc_material('water'),'Polish_v03');color_mesh(o,cols)
    print({'lake':'irregular shoreline, depth colors, grouped rocks, reeds, lilies and ripples','coast':'shallow water band'})

def home_details():
    x,y,z=-3,-14,5.4;tiles=Batch();stone=Batch();planks=Batch()
    # Curved terracotta shingles follow both existing roof slopes.
    for sign in [-1,1]:
        for row in range(9):
            for col in range(14):
                cy=y-2.94+col*.43;d0=row*.42;length=min(.55,3.65-d0)
                if length<=0:continue
                vs=[]
                for along in [0,length]:
                    d=min(3.64,d0+along)
                    for k in range(7):
                        t=k/6;bulge=.065*math.sin(t*math.pi)
                        vs.append((x+sign*(3.65-d)+sign*bulge*.52,cy+(t-.5)*.42,z+3.6+d*(2.25/3.65)+.055+bulge*.85))
                f=R.uniform(.85,1.12);tiles.add(vs,[(k,k+1,k+8,k+7) for k in range(6)],(.46*f,.14*f,.07*f))
    tiles.emit('V3_Home_Curved_Roof_Tiles','roof')
    for j in range(14):
        cy=y-2.8+j*.43;vs=[]
        for yy in [cy-.25,cy+.25]:
            for k in range(9):
                a=k*math.pi/8;vs.append((x+.16*math.cos(a),yy,z+5.85+.16*math.sin(a)+.03))
        tiles2=Batch();tiles2.add(vs,[(k,k+1,k+10,k+9) for k in range(8)],(.47,.16,.085));tiles2.emit('V3_Home_Ridge_Cap_'+str(j),'roof')
    for i in range(15):planks.block((x-1.86+i*.266,y-3.6,z+.294),(.25,2.13,.045),0,(.49+R.random()*.055,.31,.14))
    planks.emit('V3_Home_Porch_Planks','wood')
    for row in range(2):
        for j in range(13):
            xx=x-3.1+j*.50+(row%2)*.20
            stone.block((xx,y-2.81,z+.12+row*.16),(.46,.12,.13),0,(.46,.46,.36))
    stone.emit('V3_Home_Foundation_Masonry','stone')
    for dx in [-2.05,2.05]:
        w.box('V3_Home_Windowbox',(x+dx,y-2.92,z+1.38),(1.35,.48,.38),M['wood'],'Polish_v03',.05)
        for j in range(6):
            xx=x+dx-.53+j*.21;yy=y-3.02
            w.ball('V3_Windowbox_Leaf',(xx,yy,z+1.60),(.22,.20,.20),M['bush'],'Polish_v03')
            w.ball('V3_Windowbox_Flower',(xx,yy-.03,z+1.79),(.12,.11,.09),M['flower_cream' if j%2 else 'flower_pink'],'Polish_v03')
    # Concentric cobblestones replace a plain disk around the fountain.
    paving=Batch()
    for radius in [1.9,2.45,3.0,3.55,4.1,4.65]:
        count=int(math.tau*radius/.65)
        for i in range(count):
            a=math.tau*i/count;da=math.tau/count*.47;vs=[]
            for r in [radius-.25,radius+.25]:
                for an in [a-da,a,a+da]:vs.append((-3+r*math.cos(an),-23+r*math.sin(an),z+.214))
            f=R.uniform(.86,1.12);paving.add(vs,[(0,1,4,3),(1,2,5,4)],(.49*f,.44*f,.31*f))
    paving.emit('V3_Home_Fountain_Cobblestones','stone')
    # Low clipped shrubs anchor the house without covering the windows or door.
    for xx in [-7.4,1.3]:
        for yy in [-13,-14,-15]:
            w.ball('V3_Home_Garden_Shrub',(xx,yy,zground(xx,yy)+.35),(.62,.64,.45),M['bush'],'Polish_v03')
    print({'home':'curved roof tiles, porch boards, masonry, window boxes, fountain paving'})

def refine_shores():
    old=bpy.data.objects.get('ALPHA_V3_Natural_Lake_Bank')
    if old:bpy.data.objects.remove(old,do_unlink=True)
    n=384;steps=12;verts=[];faces=[];colors=[]
    def outline(a):return 1+.032*math.sin(3*a+.8)+.022*math.cos(7*a-.3)+.012*math.sin(11*a)
    def grass(x,y):
        f=.5+.5*math.sin(x*.07)*math.cos(y*.08)
        c=tuple(a+(b-a)*f for a,b in zip((.20,.40,.085),(.32,.48,.14)))
        if x>0:
            f=w.smooth(16,36,y)*.55;c=tuple(a+(b-a)*f for a,b in zip(c,(.17,.34,.075)))
        return c
    for j in range(steps+1):
        t=j/steps
        for i in range(n):
            a=i*math.tau/n;r=outline(a)+(1.125-outline(a))*t
            x=20.1*r*math.cos(a);y=7+16.1*r*math.sin(a)
            z=max(4.67,zground(x,y)+.10)
            verts.append((x,y,z))
            f=w.smooth(.05,.75,t);g=grass(x,y);colors.append(tuple(s+(q-s)*f for s,q in zip((.40,.43,.22),g)))
    for j in range(steps):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n
            if w.river_query(verts[a][0],verts[a][1])[0]>3.4:faces.append((a,b,b+n,a+n))
    obj=w.mesh('V3_Natural_Lake_Bank',verts,faces,vc_material('garden'),'Polish_v03');color_mesh(obj,colors)
    for f in obj.data.polygons:f.use_smooth=True
    terrain=bpy.data.objects['ALPHA_Island_Continuous_Terrain'];attr=terrain.data.color_attributes['Terrain_Color']
    for i,v in enumerate(terrain.data.vertices):
        x,y,z=v.co;r=math.hypot(x/20,(y-7)/16)
        if .97<r<1.26 and w.river_query(x,y)[0]>4:
            c=grass(x,y);f=1-w.smooth(1.15,1.26,r);old=attr.data[i].color
            attr.data[i].color=(*(old[k]*(1-f)+c[k]*f for k in range(3)),1)
    sea=rgb(w.MATS['sea']);o=bpy.data.objects['ALPHA_V3_Coastal_Shallow_Water'];attr=o.data.color_attributes['Polish_Color']
    for i,c in enumerate(attr.data):
        j=i//256;t=[0,.28,.66,1][j]
        c.color=(*(a+(b-a)*t for a,b in zip((.09,.43,.42),sea)),1)
    print({'shorebank':'dense projected mesh, continuous grass colors','coast_outer_color':sea})

def integrate_lake_terrain():
    # Join the shore to the actual land mesh: no overlapping colored bank sheet.
    global TREE
    overlay=bpy.data.objects.get('ALPHA_V3_Natural_Lake_Bank')
    if overlay:hide(overlay)
    terrain=bpy.data.objects['ALPHA_Island_Continuous_Terrain']
    bm=bmesh.new();bm.from_mesh(terrain.data)
    edges=[e for e in bm.edges if all(.91<math.hypot(v.co.x/20.1,(v.co.y-7)/16.1)<1.23 for v in e.verts)]
    bmesh.ops.subdivide_edges(bm,edges=edges,cuts=2,use_grid_fill=True)
    changed=0
    for v in bm.verts:
        x,y,z=v.co;r=math.hypot(x/20.1,(y-7)/16.1);a=math.atan2((y-7)/16.1,x/20.1)
        edge=1+.032*math.sin(3*a+.8)+.022*math.cos(7*a-.3)+.012*math.sin(11*a)
        d=r-edge
        if -.055<d<.13 and w.river_query(x,y)[0]>3.45:
            blend=w.smooth(-.055,.005,d)*(1-w.smooth(.035,.13,d))
            target=max(z,4.77+.4*max(0,d))
            v.co.z=z+(target-z)*blend;changed+=1
    bm.to_mesh(terrain.data);bm.free();terrain.data.update()
    for f in terrain.data.polygons:f.use_smooth=True
    TREE=BVHTree.FromObject(terrain,bpy.context.evaluated_depsgraph_get())
    # Re-project the nearby routes onto the revised bank.
    for name,offset in [('ALPHA_V3_Connected_Rounded_Paths',.115),('ALPHA_V3_Path_Soft_Shoulder',.075)]:
        obj=bpy.data.objects[name]
        for v in obj.data.vertices:v.co.z=zground(v.co.x,v.co.y)+offset
        obj.data.update()
    for o in COLL.objects:
        if 'Shore_Rock' in o.name:o.location.z=max(o.location.z,zground(o.location.x,o.location.y)+o.dimensions.z*.25)
    print({'lake_bank_terrain_vertices_adjusted':changed,'terrain_vertices':len(terrain.data.vertices)})

def garden_finishing():
    # Primitive props need ordinary color materials, not the vertex-color batch shader.
    plain={key:w.make_material('V3_Plain_'+key,rgb(M[key])) for key in ['wood','flower_pink','flower_cream','bush']}
    for o in COLL.objects:
        if 'Home_Windowbox' in o.name:o.data.materials.clear();o.data.materials.append(plain['wood'])
        if 'Windowbox_Flower' in o.name:
            current=o.data.materials[0]
            if any(n.type=='VERTEX_COLOR' for n in current.node_tree.nodes):
                o.data.materials.clear();o.data.materials.append(plain['flower_pink'])
    stones=Batch();beds=0
    for letter in 'EFMNOP':
        plot=w.BY_LETTER[letter];socket=bpy.data.objects[plot['socket_name']]
        x,y=plot['x'],plot['y'];front=socket['entry_front_y'];half=plot['target_width']/2
        for j in range(3):
            xx=x+R.uniform(-.12,.12);yy=front-.45-j*.65;zz=zground(xx,yy)+.16
            for side in [-1,1]:
                stones.block((xx+side*.35,yy,zz),(.63,.52,.08),R.uniform(-.08,.08),(.41+R.random()*.07,.42,.32))
        for side in [-1,1]:
            cx=x+side*(half+1.1);cy=y+.35
            _,_,d=ROAD_KD.find((cx,cy,0))
            if d<2.3:continue
            for j in range(3):
                xx=cx+R.uniform(-.3,.3);yy=cy+(j-1)*.6;zz=zground(xx,yy)
                w.ball('V3_'+letter+'_Garden_Shrub',(xx,yy,zz+.36),(.55,.58,.46),plain['bush'],'Polish_v03')
                for k in range(3):
                    w.ball('V3_'+letter+'_Garden_Bloom',(xx+R.uniform(-.3,.3),yy+R.uniform(-.3,.3),zz+.77),(.12,.12,.11),plain['flower_cream' if j%2 else 'flower_pink'],'Polish_v03')
            beds+=1
    stones.emit('V3_Garden_Entry_Stepping_Stones','stone')
    print({'garden_planting_groups':beds,'garden_entry_slabs':len(stones.faces)//6})
