"""Material and player-scale polish for the saved v04 world, in Blender.

Run setup(), materials(), details(), grain_and_finish(), daylight_sky(),
near_texture_pass(), review_cameras() on a v05 copy.
The original Tripo GLBs and their color textures are never edited.
Surface normals are small generated, packed PBR textures with explicit mesh UVs.
"""
import bpy, math, json, random, sys, struct, tempfile
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import numpy as np
import studygame_world as w

BASE=Path(__file__).resolve().parent
GROUP='Character_Polish_v05'
R=random.Random(221005)
TREE=None
M={}
IMAGES={}
REPORT={'version':5,'source_images_modified':False,'material_changes':[], 'detail_areas':[]}
HIDDEN_KEYS=['editor_only','presentation_only','site_clearance_hidden','superseded_by_v03','superseded_by_v04','school_site_clearance','superseded_by_v05']

def visible(o):return not o.hide_render and not any(o.get(k) for k in HIDDEN_KEYS)

def setup():
    global TREE
    w.SCENE=bpy.data.scenes[w.SCENE_NAME]
    bpy.context.window.scene=w.SCENE
    w.COLLS={c.name.removeprefix('ALPHA_'):c for c in w.SCENE.collection.children if c.name.startswith('ALPHA_')}
    if GROUP in w.COLLS:raise RuntimeError('v05 exists; continue its staged pass without duplicating details.')
    c=bpy.data.collections.new('ALPHA_'+GROUP);w.SCENE.collection.children.link(c);w.COLLS[GROUP]=c
    TREE=BVHTree.FromObject(bpy.data.objects['ALPHA_Island_Continuous_Terrain'],bpy.context.evaluated_depsgraph_get())
    w.SCENE['output_version']='v05'
    for key,color in {'wood':(.35,.19,.085),'wood_light':(.55,.34,.16),'wood_dark':(.13,.075,.04),'stone':(.40,.43,.37),'stone_light':(.58,.58,.46),'cream':(.82,.72,.51),'teal':(.055,.28,.26),'brass':(.48,.32,.10),'soil':(.20,.12,.045),'leaf':(.085,.27,.075),'leaf_light':(.18,.38,.11),'pink':(.72,.20,.27),'yellow':(.83,.61,.18),'paper':(.83,.79,.62),'ink':(.075,.14,.13),'bread':(.64,.35,.13),'glass':(.57,.49,.28)}.items():
        M[key]=w.make_material('V5_'+key,color,.78)
    REPORT['preserved_transforms']={o.name:[list(row) for row in o.matrix_world] for o in w.SCENE.objects if o.get('memory_sequence') or (o.name.startswith('ALPHA_LANDMARK_') and o.name.endswith('_SOCKET')) or o.name=='ALPHA_SCHOOL_ROOT'}
    print({'stage':'setup','preserved_transforms':len(REPORT['preserved_transforms'])})

def ground(x,y):
    co,*_=TREE.ray_cast(Vector((x,y,80)),Vector((0,0,-1)),150)
    return co.z if co else w.height(x,y)

def bsdf(mat):return next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)

def constant(mat,name,value):
    sock=bsdf(mat).inputs.get(name)
    if sock is None:return
    for link in list(sock.links):mat.node_tree.links.remove(link)
    sock.default_value=value

def normal_image(kind):
    if kind in IMAGES:return IMAGES[kind]
    n=512;v,u=np.mgrid[0:n,0:n].astype(np.float32)/n;t=math.tau
    if kind=='wood':
        h=.0035*np.sin(t*(23*u+.65*np.sin(t*v)))+.0014*np.sin(t*(47*u+1.8*np.sin(t*v)))
    else:
        rng=np.random.default_rng(221005)
        freq=np.fft.fftfreq(n)*n;fy,fx=np.meshgrid(freq,freq)
        radius=np.sqrt(fx*fx+fy*fy)
        filt=np.exp(-(radius/42)**2)*(1-np.exp(-(radius/3)**2))
        h=np.fft.ifft2(np.fft.fft2(rng.standard_normal((n,n)))*filt).real
        h=h/h.std()*.0009
        if kind=='plaster':h*=.45
        if kind=='earth':h*=1.4
    dx=(np.roll(h,-1,axis=1)-np.roll(h,1,axis=1))*n/2
    dy=(np.roll(h,-1,axis=0)-np.roll(h,1,axis=0))*n/2
    normal=np.stack((-dx,-dy,np.ones_like(h)),axis=-1)
    normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
    pixels=np.ones((n,n,4),dtype=np.float32);pixels[:,:,:3]=normal*.5+.5
    img=bpy.data.images.new('V5_'+kind+'_surface_normal',width=n,height=n,alpha=False)
    options=[i.identifier for i in img.colorspace_settings.bl_rna.properties['name'].enum_items]
    assert 'Non-Color' in options;img.colorspace_settings.name='Non-Color'
    img.pixels.foreach_set(pixels.ravel());img.update();img.pack()
    IMAGES[kind]=img;return img

def classify(name):
    name=name.lower()
    if any(k in name for k in ['water','sea','foam']):return 'water'
    if 'glass' in name:return 'glass'
    if any(k in name for k in ['leaf','foliage','grass','bush','pine','flower','pink','yellow','blue','red','lavender','reed']):return 'plant'
    if any(k in name for k in ['metal','brass']):return 'metal'
    if any(k in name for k in ['wood','bark']):return 'wood'
    if any(k in name for k in ['dirt','terrain','sand','earth','soil','edge','garden','gravel','volcanic']):return 'earth'
    if any(k in name for k in ['stone','rock','paving','brick','coastal']):return 'stone'
    return 'plaster'

def add_normal(mat,kind):
    if mat.get('v05_normal'):return
    nt=mat.node_tree;uv=nt.nodes.new('ShaderNodeUVMap');uv.uv_map='V5_SurfaceUV'
    tex=nt.nodes.new('ShaderNodeTexImage');tex.image=normal_image(kind)
    normal=nt.nodes.new('ShaderNodeNormalMap');w.enum_set(normal,'space','TANGENT');normal.uv_map='V5_SurfaceUV'
    normal.inputs['Strength'].default_value={'wood':.30,'earth':.24,'stone':.26,'plaster':.18}[kind]
    nt.links.new(uv.outputs['UV'],tex.inputs['Vector']);nt.links.new(tex.outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs['Normal'],bsdf(mat).inputs['Normal'])
    mat['v05_normal']=kind

def surface_uv(mesh):
    if mesh.uv_layers.get('V5_SurfaceUV'):return
    uv=mesh.uv_layers.new(name='V5_SurfaceUV')
    # Box projection in mesh coordinates, preserving all existing source UV layers.
    for poly in mesh.polygons:
        axis=max(range(3),key=lambda k:abs(poly.normal[k]))
        a,b=[k for k in range(3) if k!=axis]
        for li in poly.loop_indices:
            co=mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv=(co[a]*1.25,co[b]*1.25)
    mesh.uv_layers.active=uv

def materials():
    landmark_meshes=set()
    for letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ':
        sock=bpy.data.objects['ALPHA_LANDMARK_'+letter+'_SOCKET'];copies={}
        for o in sock.children_recursive:
            if o.type!='MESH' or o.get('editor_only'):continue
            landmark_meshes.add(o)
            for i,mat in enumerate(o.data.materials):
                if not mat:continue
                if mat not in copies:
                    copy=mat.copy();copy.name='ALPHA_V5_Landmark_'+letter+'_'+str(len(copies)+1);copies[mat]=copy
                    copy['v04_material']=mat.name
                    rough={'B':.71,'J':.65,'R':.61,'W':.69}.get(letter,.76)
                    constant(copy,'Roughness',rough);constant(copy,'Metallic',.12 if letter=='R' else 0.0)
                    constant(copy,'Specular IOR Level',.32);constant(copy,'Coat Weight',0.0)
                    for node in copy.node_tree.nodes:
                        if node.type=='NORMAL_MAP':node.inputs['Strength'].default_value=.28
                    REPORT['material_changes'].append({'letter':letter,'material':copy.name,'roughness':rough,'metallic':.12 if letter=='R' else 0,'normal_strength':.28,'basecolor_preserved':True})
                o.data.materials[i]=copies[mat]
    env={m for o in w.SCENE.objects if o.type=='MESH' and o not in landmark_meshes and visible(o) for m in o.data.materials if m and m.use_nodes}
    for mat in env|set(M.values()):
        p=bsdf(mat)
        if not p:continue
        kind=classify(mat.name)
        rough={'wood':.79,'earth':.91,'stone':.86,'plaster':.82,'plant':.83,'metal':.46,'glass':.32,'water':.28}[kind]
        constant(mat,'Roughness',rough);constant(mat,'Specular IOR Level',.32 if kind in ['water','glass','metal'] else .27)
        if kind not in ['metal']:constant(mat,'Metallic',0.0)
        if kind in ['wood','earth','stone','plaster']:add_normal(mat,kind)
        mat['v05_surface_family']=kind
    meshes=set()
    for o in w.SCENE.objects:
        if o.type=='MESH' and o not in landmark_meshes and visible(o) and any(m and m.get('v05_normal') for m in o.data.materials):
            if o.data not in meshes:surface_uv(o.data);meshes.add(o.data)
    # A softer key light gives all assets the same warm daylight response.
    sun=bpy.data.objects['ALPHA_Sun'].data;sun.energy=2.25;sun.color=(1.0,.94,.84);sun.angle=.22
    bg=next(n for n in w.SCENE.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.68,.80,.94,1);bg.inputs['Strength'].default_value=.52
    w.SCENE.view_settings.exposure=0
    w.SCENE.eevee.taa_render_samples=96
    REPORT['environment_materials']=len(env);REPORT['environment_meshes_with_uv']=len(meshes);REPORT['shared_normal_textures']=list(IMAGES)
    print({'stage':'materials','landmark_materials':len(REPORT['material_changes']),'environment_materials':len(env),'uv_meshes':len(meshes)})

def box(name,loc,size,mat='wood',bevel=.035):return w.box('V5_'+name,loc,size,M[mat],GROUP,bevel)
def ball(name,loc,size,mat='leaf'):return w.ball('V5_'+name,loc,size,M[mat],GROUP)
def cyl(name,loc,r,h,mat='wood',n=24,top=None):return w.cylinder('V5_'+name,loc,r,h,M[mat],GROUP,n,top)
def beam(name,a,b,width,mat='wood'):return w.beam('V5_'+name,a,b,width,M[mat],GROUP)

def paving(name,x,y,width,depth,rows=3):
    for row in range(rows):
        columns=max(2,round(width/.5));tilew=width/columns
        for col in range(columns):
            xx=x-width/2+(col+.5)*tilew;yy=y-depth/2+(row+.5)*depth/rows
            ob=box(name,(xx,yy,ground(xx,yy)+.15),(tilew-.035,depth/rows-.035,.11),'stone_light',.04)
            ob.rotation_euler.z=R.uniform(-.016,.016)

def planter(name,x,y,length=1.1):
    z=ground(x,y)
    box(name+'_Box',(x,y,z+.24),(length,.55,.46),'wood',.06)
    box(name+'_Soil',(x,y,z+.48),(length-.12,.42,.06),'soil',.015)
    for side in [-1,1]:box(name+'_Rim',(x,y+side*.27,z+.47),(length+.08,.08,.1),'wood_light',.025)
    for dx in [-length*.32,0,length*.32]:
        for i in range(3):
            a=i*math.tau/3;ball(name+'_Leaf',(x+dx+.1*math.cos(a),y+.1*math.sin(a),z+.57),(.19,.12,.08),'leaf_light')
        for j in range(5):
            a=j*math.tau/5;ball(name+'_Petal',(x+dx+.09*math.cos(a),y+.09*math.sin(a),z+.75),(.085,.065,.04),'pink')
        ball(name+'_Center',(x+dx,y,z+.775),(.055,.055,.04),'yellow')

def cup(name,x,y,z):
    cyl(name+'_Saucer',(x,y,z),.14,.028,'cream',32)
    cyl(name+'_Cup',(x,y,z+.10),.085,.17,'teal',24,top=.095)
    cyl(name+'_Tea',(x,y,z+.19),.073,.008,'wood_dark',24)
    for i in range(8):
        a=i*math.tau/8;b=(i+1)*math.tau/8
        beam(name+'_Handle',(x+.1+.045*math.cos(a),y,z+.10+.06*math.sin(a)),(x+.1+.045*math.cos(b),y,z+.10+.06*math.sin(b)),.018,'teal')

def book(name,x,y,z,color='teal',standing=False):
    if standing:
        box(name+'_Pages',(x,y,z+.17),(.075,.22,.32),'paper',.012)
        for dx in [-.052,.052]:box(name+'_Cover',(x+dx,y,z+.17),(.025,.25,.36),color,.012)
        box(name+'_Spine',(x,y-.13,z+.17),(.12,.035,.36),color,.012)
        for zz in [.10,.25]:box(name+'_Spine_Line',(x,y-.152,z+zz),(.09,.008,.016),'cream',.003)
    else:
        box(name+'_Pages',(x,y,z+.045),(.30,.38,.07),'paper',.012)
        for dz in [0,.09]:box(name+'_Cover',(x,y,z+dz),(.34,.41,.022),color,.012)
        box(name+'_Spine',(x-.16,y,z+.045),(.026,.41,.10),color,.008)

def home_details():
    # Shared palette with the school, deeper wood framing and teal window glass.
    mat=w.make_material('V5_Home_Plaster',(.74,.59,.38),.82);add_normal(mat,'plaster')
    bpy.data.objects['ALPHA_Home_Cream_Walls'].data.materials[0]=mat
    window=w.make_material('V5_Window_Glass',(.10,.29,.31),.32)
    p=bsdf(window);p.inputs['Specular IOR Level'].default_value=.38
    for ob in w.COLLS['Home'].objects:
        if ob.type!='MESH':continue
        if 'Glass' in ob.name:ob.data.materials[0]=window
        elif any(k in ob.name for k in ['Window_Frame','Door_Frame','Corner_Timber']):ob.data.materials[0]=M['wood']
    box('Home_Door_Mail_Slot',(-3,-16.965,6.65),(.42,.035,.085),'brass',.018)
    for x in [-3.56,-2.44]:
        for z in [6.05,7.20]:box('Home_Door_Hinge',(x,-16.99,z),(.10,.045,.15),'brass',.02)
    # A small glazed attic window and trim make the flat gable readable from below.
    for name,radius,depth,yy,matkey in [('Rim',.46,.10,-17.055,'wood'),('Glass',.35,.045,-17.12,'teal')]:
        ob=cyl('Home_Attic_'+name,(-3,yy,9.95),radius,depth,matkey,40);ob.rotation_euler.x=math.pi/2
    box('Home_Attic_Mullion',(-3,-17.16,9.95),(.045,.045,.65),'cream',.01)
    box('Home_Attic_Bar',(-3,-17.16,9.95),(.65,.045,.045),'cream',.01)
    box('Home_Doormat',(-3,-17.40,5.75),(1.20,.62,.05),'wood_dark',.04)
    for i in range(10):box('Home_Mat_Weave',(-3.50+i*.11,-17.40,5.784),(.043,.52,.012),'wood_light',.004)
    for x in [-5.1,-4.77]:
        ball('Home_Boot_Toe',(x,-17.60,5.80),(.13,.24,.12),'teal')
        cyl('Home_Boot_Shaft',(x,-17.47,5.98),.12,.34,'teal',20)
        cyl('Home_Boot_Opening',(x,-17.47,6.155),.086,.015,'wood_dark',20)
    # Thin sill shadows, window-glass glints and a base moulding.
    for x in [-5.0,-1.0]:
        box('Home_Window_Sill',(x,-16.86,6.65),(1.6,.34,.11),'wood_light',.025)
        box('Home_Window_Glint',(x-.25,-16.96,7.67),(.035,.018,.49),'cream',.008)
    paving('Home_Threshold',-3,-18.38,2.1,.72,2)
    REPORT['detail_areas'].append('Home: warm plaster, teal glazing, attic window, sill shadows, doorstep, mat and boots')

def cafe_details():
    # Existing terrace tables retain their positions; add small, legible tabletop objects.
    for index,name in enumerate(['ALPHA_C_Cafe_Table','ALPHA_C_Cafe_Table.001']):
        table=bpy.data.objects[name];x,y,z=table.location;z+=.085
        table.data.materials[0]=M['wood_light'];w.bevel(table,.028)
        cup('Cafe_'+str(index),x+.23,y-.17,z+.025)
        cyl('Cafe_Plate',(x-.20,y+.12,z+.018),.24,.026,'cream',32)
        for i in range(3):
            a=(i-1)*.55;ball('Cafe_Bread',(x-.2+.08*i,y+.12+.045*math.cos(a),z+.085),(.11,.07,.055),'bread')
    # Small menu board beside the entrance, beyond the central walking lane.
    x,y=-35.6,-38.1;z=ground(x,y)
    for dx in [-.34,.34]:
        beam('Cafe_Menu_Leg',(x+dx,y-.22,z+.13),(x+dx,y+.03,z+1.12),.065,'wood')
        beam('Cafe_Menu_Back',(x+dx,y+.38,z+.13),(x+dx,y+.03,z+1.12),.065,'wood')
    box('Cafe_Menu_Frame',(x,y-.04,z+.84),(.87,.10,.75),'wood_light',.04)
    box('Cafe_Menu_Face',(x,y-.10,z+.84),(.73,.04,.61),'ink',.025)
    # A cake pictogram and short chalk strokes; no quest text.
    for width,zz in [(.36,.72),(.29,.83),(.20,.93)]:box('Cafe_Menu_Cake',(x,y-.13,z+zz),(width,.015,.075),'cream',.012)
    for i in range(2):box('Cafe_Menu_Chalk',(x+.05,y-.132,z+.63-i*.055),(.39-i*.06,.012,.013),'cream',.004)
    paving('Cafe_Threshold',-33,-37.85,2.0,.85,2)
    planter('Cafe_Low_Planter',-30.55,-37.3,1.0)
    REPORT['detail_areas'].append('Bakery: entrance stones, low planter, cake menu pictogram, tea and pastries on existing tables')

def library_details():
    x,y=48.7,24.1;z=ground(x,y)
    for dx in [-.48,.48]:
        for dy in [-.25,.25]:
            ob=cyl('Library_Cart_Wheel',(x+dx,y+dy,z+.20),.14,.075,'wood_dark',20);ob.rotation_euler.x=math.pi/2
    for zz in [.34,.86]:box('Library_Cart_Shelf',(x,y,z+zz),(1.18,.66,.09),'wood_light',.04)
    for dx in [-.54,.54]:
        for dy in [-.28,.28]:box('Library_Cart_Post',(x+dx,y+dy,z+.67),(.07,.07,.79),'wood',.025)
    beam('Library_Cart_Handle',(x-.62,y,z+.91),(x-.62,y,z+1.15),.065,'brass')
    for i,color in enumerate(['teal','pink','cream','yellow','teal','pink']):book('Library_Book',x-.40+i*.145,y,z+.92,color,True)
    for i in range(3):book('Library_Lower_Book',x-.25+i*.28,y,z+.40,'teal' if i%2 else 'pink')
    book('Library_Bench_Book',46.9,24.45,12.12,'teal')
    paving('Library_Threshold',52,24.98,2.1,1.05,3)
    planter('Library_Low_Planter',54.5,25.0,1.0)
    REPORT['detail_areas'].append('Library: book trolley, individual books, bench book, threshold and low flower box')

def school_details():
    paving('School_Gate_Pavers',0,47.65,3.05,1.25,3)
    # Pins and pictograms give the noticeboard a believable child-scale reading surface.
    for x in [3.45,4.17]:
        ball('School_Notice_Pin',(x,48.004,12.18),(.034,.025,.034),'brass')
        for i in range(4):box('School_Notice_Line',(x,48.012,12.05-i*.08),(.30-(i%2)*.06,.012,.012),'ink',.003)
    for x in [-1.9,1.9]:
        for dx in [-.145,.145]:
            for dy in [-.145,.145]:box('School_Lamp_Frame',(x+dx,48.05+dy,12.0),(.032,.032,.42),'wood_dark',.009)
        box('School_Lamp_Cap',(x,48.05,12.25),(.41,.41,.075),'teal',.025)
    # Modest stone feet remove the impression that fence posts simply intersect paving.
    posts=[o for o in w.COLLS['School_Campus'].objects if o.type=='MESH' and 'Fence_Post' in o.name]
    for ob in posts:
        pos=ob.matrix_world.translation
        box('School_Fence_Foot',(pos.x,pos.y,10.42),(.27,.27,.16),'stone',.04)
    REPORT['detail_areas'].append('School: rounded gate paving, noticeboard marks, framed gate lanterns and fence feet')

def lantern_details():
    count=0
    for glow in list(w.SCENE.objects):
        if glow.type!='MESH' or not glow.name.endswith('_Glow') or not visible(glow):continue
        x,y,z=glow.location
        # Refine the common lantern design throughout the world.
        for dx in [-.20,.20]:
            for dy in [-.20,.20]:box('Lantern_Frame',(x+dx,y+dy,z),(.045,.045,.59),'wood_dark',.01)
        box('Lantern_Base',(x,y,z-.31),(.49,.49,.075),'wood_dark',.018)
        cap=bpy.data.objects.get(glow.name.removesuffix('_Glow')+'_Cap')
        if cap:cap.data.materials[0]=M['teal']
        count+=1
    REPORT['refined_lanterns']=count

def path_gardens():
    # Follow the actual unified road boundary in selected near-camera areas.
    plan=json.loads((BASE/'polish_plan_v03.json').read_text())
    areas=[(-3,-20,7),(-33,-35,7),(52,25,6),(-31,20,5)]
    sites=[]
    for ring in plan['road_rings']:
        area=sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(ring,ring[1:]))
        side=1 if area>0 else -1
        for a,b in zip(ring,ring[1:]):
            dx,dy=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dy)
            if length<.15:continue
            for i in range(max(1,int(length/.65))):
                t=(i+.5)/max(1,int(length/.65));x=a[0]+dx*t+side*dy/length*.26;y=a[1]+dy*t-side*dx/length*.26
                if not any(math.hypot(x-cx,y-cy)<r for cx,cy,r in areas):continue
                if any(math.hypot(x-sx,y-sy)<.65 for sx,sy in sites):continue
                if R.random()>.48:continue
                sites.append((x,y));z=ground(x,y)
                for k in range(3):
                    theta=k*math.tau/3+R.random()*.3
                    ob=ball('Roadside_Clover',(x+.1*math.cos(theta),y+.1*math.sin(theta),z+.10),(.16,.10,.045),'leaf_light');ob.rotation_euler.z=theta
                if len(sites)%4==0:
                    ob=ball('Roadside_Pebble',(x+.17,y-.12,z+.09),(.18,.13,.10),'stone');ob.rotation_euler.z=R.random()*math.tau
    REPORT['near_path_plant_clusters']=len(sites)

def details():
    home_details();cafe_details();library_details();school_details();lantern_details();path_gardens();finalize_surfaces()

def grain_image(kind):
    name='V5_'+kind+'_subtle_grain'
    existing=bpy.data.images.get(name)
    if existing:return existing
    n=512;rng=np.random.default_rng(221005);v,u=np.mgrid[0:n,0:n].astype(np.float32)/n
    if kind=='wood':
        field=np.sin(math.tau*(23*u+.65*np.sin(math.tau*v)))+.35*np.sin(math.tau*(47*u+1.8*np.sin(math.tau*v)))
        field=np.clip(field/1.35,-1,1)
        value=.94+.055*field
    else:
        freq=np.fft.fftfreq(n)*n;fy,fx=np.meshgrid(freq,freq);radius=np.sqrt(fx*fx+fy*fy)
        noise=rng.standard_normal((n,n))
        field=np.fft.ifft2(np.fft.fft2(noise)*np.exp(-(radius/32)**2)).real
        field=np.clip(field/field.std()/2.8,-1,1)
        strength={'earth':.075,'stone':.045,'plaster':.018}[kind]
        value=1-strength+strength*field
    pixels=np.ones((n,n,4),dtype=np.float32);pixels[:,:,:3]=value[:,:,None]
    img=bpy.data.images.new(name,width=n,height=n,alpha=False)
    options=[i.identifier for i in img.colorspace_settings.bl_rna.properties['name'].enum_items]
    assert 'sRGB' in options;img.colorspace_settings.name='sRGB'
    img.pixels.foreach_set(pixels.ravel());img.update();img.pack();return img

def grain_and_finish():
    # Standard image × color / color attribute is recognized by the local glTF exporter.
    changed=0
    for mat in bpy.data.materials:
        if not mat.use_nodes or not mat.get('v05_normal') or mat.get('v05_grain'):continue
        kind=mat['v05_normal'];nt=mat.node_tree;p=bsdf(mat);base=p.inputs['Base Color']
        source=base.links[0].from_socket if base.is_linked else None;color=tuple(base.default_value)
        mix=nt.nodes.new('ShaderNodeMix');w.enum_set(mix,'data_type','RGBA');w.enum_set(mix,'blend_type','MULTIPLY')
        factors=[s for s in mix.inputs if s.name=='Factor' and s.type=='VALUE'];factors[0].default_value=1
        ca=next(s for s in mix.inputs if s.name=='A' and s.type=='RGBA');cb=next(s for s in mix.inputs if s.name=='B' and s.type=='RGBA')
        if source:nt.links.new(source,ca)
        else:ca.default_value=color
        uv=nt.nodes.new('ShaderNodeUVMap');uv.uv_map='V5_SurfaceUV'
        tex=nt.nodes.new('ShaderNodeTexImage');tex.image=grain_image(kind)
        nt.links.new(uv.outputs['UV'],tex.inputs['Vector']);nt.links.new(tex.outputs['Color'],cb)
        out=next(s for s in mix.outputs if s.type=='RGBA');nt.links.new(out,base)
        mat['v05_grain']=True;changed+=1
    # Gentle larger-scale painted variation keeps grass and paths from reading as flat sheets.
    for name in ['ALPHA_Island_Continuous_Terrain','ALPHA_V4_Connected_Paths','ALPHA_V4_Path_Shoulders']:
        ob=bpy.data.objects.get(name)
        if not ob or ob.get('v05_tonal_variation'):continue
        attr=ob.data.color_attributes.active_color
        if not attr or attr.domain!='POINT':continue
        for vertex,c in zip(ob.data.vertices,attr.data):
            x,y,z=vertex.co;f=1+.035*math.sin(x*.63+y*.29)+.023*math.sin(x*.23-y*.79)
            rgb=c.color[:3];c.color=(*[min(1,max(0,a*f)) for a in rgb],1)
        ob['v05_tonal_variation']=True
    # Round small legacy bushes visible at player height, without increasing tree density.
    softened=0
    for ob in w.SCENE.objects:
        if ob.type!='MESH' or not visible(ob) or ob.get('v05_softened'):continue
        if not any(k in ob.name for k in ['Bush','_Green']):continue
        if ob.name.startswith('ALPHA_V5_'):continue
        if len(ob.data.polygons)>150:continue
        kinds=[i.identifier for i in bpy.types.Modifier.bl_rna.properties['type'].enum_items]
        assert 'SUBSURF' in kinds
        mod=ob.modifiers.new('V5 softer shrub silhouette','SUBSURF');mod.levels=1;mod.render_levels=1
        ob['v05_softened']=True;softened+=1
    REPORT['grain_materials']=changed;REPORT['softened_legacy_shrubs']=softened
    finalize_surfaces()
    print({'grain_materials':changed,'softened_shrubs':softened})

def daylight_sky():
    # World lighting is stored in the Blender file; match it separately in an engine.
    nt=w.SCENE.world.node_tree;bg=next(n for n in nt.nodes if n.type=='BACKGROUND')
    tex=nt.nodes.new('ShaderNodeTexCoord');sep=nt.nodes.new('ShaderNodeSeparateXYZ')
    absolute=nt.nodes.new('ShaderNodeMath');w.enum_set(absolute,'operation','ABSOLUTE')
    ramp=nt.nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(.40,.63,.79,1);ramp.color_ramp.elements[1].color=(.09,.29,.58,1)
    nt.links.new(tex.outputs['Normal'],sep.inputs['Vector']);nt.links.new(sep.outputs['Z'],absolute.inputs[0]);nt.links.new(absolute.outputs[0],ramp.inputs[0]);nt.links.new(ramp.outputs['Color'],bg.inputs['Color'])
    bg.inputs['Strength'].default_value=.65
    REPORT['lighting']='Warm soft sun, blue daylight sky gradient; Blender lighting is not embedded in GLB.'

def near_texture_pass():
    """Use the original embedded images for two hero sites; never upscale 1K copies."""
    folder=BASE/'textures_v05';folder.mkdir(exist_ok=True)
    updated=[]
    for letter in ['C','O']:
        sock=bpy.data.objects['ALPHA_LANDMARK_'+letter+'_SOCKET']
        source=Path(sock['source_file']);raw=source.read_bytes();length=struct.unpack_from('<I',raw,12)[0]
        gltf=json.loads(raw[20:20+length]);binary_start=20+length+8
        mats={m for o in sock.children_recursive if o.type=='MESH' for m in o.data.materials if m and m.name.startswith('ALPHA_V5_')}
        for src in gltf.get('images',[]):
            name=src.get('name','')
            kind='basecolor' if 'basecolor' in name.lower() else 'normal' if 'normal' in name.lower() else None
            if not kind:continue
            view=gltf['bufferViews'][src['bufferView']];offset=binary_start+view.get('byteOffset',0)
            data=raw[offset:offset+view['byteLength']]
            with tempfile.TemporaryDirectory(prefix='studygame-hero-texture-') as tmp:
                temp=Path(tmp)/name;temp.write_bytes(data)
                image=bpy.data.images.load(str(temp),check_existing=False);image.name='ALPHA_V5_'+letter+'_'+kind+'_2K'
                w.enum_set(image.colorspace_settings,'name','sRGB' if kind=='basecolor' else 'Non-Color')
                original=list(image.size);longest=max(original)
                if longest>2048:image.scale(round(original[0]*2048/longest),round(original[1]*2048/longest))
                image.filepath_raw=str(folder/(letter+'_'+kind+'_2k.png'));w.enum_set(image,'file_format','PNG');image.save();image.pack()
            for mat in mats:
                for node in mat.node_tree.nodes:
                    if node.type=='TEX_IMAGE' and node.image and kind in node.image.name.lower():node.image=image
            updated.append({'letter':letter,'kind':kind,'original_size':original,'map_size':list(image.size),'file':str(Path(image.filepath_raw).relative_to(BASE))})
        sock['map_texture_max_px']=2048;sock['material_profile_v05']='matte hero 2K basecolor/normal'
    REPORT['hero_textures']=updated
    print({'hero_textures':updated})

def review_cameras():
    views=[('Player_Home',(5,-32,12.1),(-3,-16,7.8),36),('Player_Bakery',(-25.5,-47,11.1),(-33,-34.7,7.5),36),('Player_Library',(60,12.5,17.6),(51.2,28,15.0),36),('Player_School',(6,34,18.5),(-2.0,52.3,13.8),32),('Eye_Home',(1,-22,ground(1,-22)+1.35),(-3,-14,8.1),24),('Eye_School',(.5,43,ground(.5,43)+1.35),(-1,53,13.5),26),('Eye_Bakery',(-37,-40,ground(-37,-40)+1.35),(-33,-34,7.0),22)]
    records=[]
    for key,pos,target,lens in views:
        name='ALPHA_Camera_'+key;cam=bpy.data.objects.get(name)
        if not cam:
            data=bpy.data.cameras.new(name);cam=w.link('Camera_'+key,data,'Camera_Lighting')
        w.enum_set(cam.data,'type','PERSP');cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=lens;cam.data.clip_start=.05;cam.data.clip_end=500;cam['player_view_review']=True
        records.append({'name':name,'position':list(pos),'target':list(target),'lens_mm':lens,'type':'1.35m child eye height' if key.startswith('Eye_') else 'third-person neighborhood view'})
    (BASE/'player_view_cameras_v05.json').write_text(json.dumps({'render_size':[1600,1000],'eye_height_m':1.35,'cameras':records,'gameplay_camera_implemented':False},ensure_ascii=False,indent=2)+'\n')
    print({'review_cameras':len(records)})

def finalize_surfaces():
    for ob in w.COLLS[GROUP].objects:
        if ob.type=='MESH' and any(m and m.get('v05_normal') for m in ob.data.materials):surface_uv(ob.data)
    for name,matrix in REPORT['preserved_transforms'].items():
        assert max(abs(bpy.data.objects[name].matrix_world[i][j]-matrix[i][j]) for i in range(4) for j in range(4))<1e-6,name
    REPORT['preserved_transform_check']=True
    REPORT['detail_objects']=len(w.COLLS[GROUP].objects)
    (BASE/'character_polish_v05.json').write_text(json.dumps(REPORT,ensure_ascii=False,indent=2)+'\n')
    print({'detail_objects':REPORT['detail_objects'],'preserved_transform_check':True})
