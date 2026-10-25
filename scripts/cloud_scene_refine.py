"""Deterministic Blender refinement of the current exported scenes (v07 island).

Run only on the baseline_import.blend created by cloud_scene_inspect.py.
The original Blender 5.2 files and source GLBs are never opened for writing.
"""
import bpy, bmesh, json, math, hashlib, sys, argparse, random, re
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

P=argparse.ArgumentParser();P.add_argument('--room',required=True);P.add_argument('--out',required=True);P.add_argument('--evidence',required=True)
A=P.parse_args(sys.argv[sys.argv.index('--')+1:]);ROOM=A.room;OUT=Path(A.out);EV=Path(A.evidence)
scene=bpy.context.scene;bpy.context.view_layer.update();ORIGINAL=list(scene.objects)
BASELINE_SHA=hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()
CHANGE={'room':ROOM,'source':'current repository GLB imported for editing in Blender 4.3.2; exported geometry verified separately','baseline_blend_sha256':BASELINE_SHA,'repairs':[],'architecture':[],'vegetation':[],'material_changes':[]}
for root in [o for o in ORIGINAL if o.name.startswith('HOME_TASK_') and o.get('household_state')]:
    for ob in [root,*root.children_recursive]:ob.hide_render=root.get('household_state')!='before'

def bounds(o):
    pts=[o.matrix_world@Vector(v) for v in o.bound_box]
    return Vector([min(v[i] for v in pts) for i in range(3)]),Vector([max(v[i] for v in pts) for i in range(3)])

def signature():
    roots=[o for o in ORIGINAL if o.name.startswith(('SG_','COL_','HOME_TASK_')) or o.get('sg_collision','none')!='none']
    obs={o.name:o for r in roots for o in [r,*r.children_recursive]}
    result={}
    for n,o in obs.items():
        h=hashlib.sha256();h.update(str(o.parent.name if o.parent else None).encode());h.update(str([list(x) for x in o.matrix_world]).encode());h.update(str(sorted((k,str(v)) for k,v in o.items())).encode())
        if o.type=='MESH':
            h.update(str([tuple(v.co) for v in o.data.vertices]).encode());h.update(str([tuple(p.vertices) for p in o.data.polygons]).encode())
        result[n]=h.hexdigest()
    return result

GUARD=signature()
MATS={}
def mat(key,color,rough=.75,metal=0):
    m=bpy.data.materials.new('CF08_'+key);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    MATS[key]=m;return m

for key,col,rough,metal in [
    ('oak',(.40,.235,.10),.74,0),('oak_light',(.63,.42,.22),.72,0),('cream',(.79,.68,.48),.78,0),
    ('sage',(.20,.38,.28),.8,0),('teal',(.08,.28,.28),.7,0),('clay',(.55,.21,.12),.86,0),
    ('brass',(.50,.32,.10),.35,.65),('linen',(.80,.73,.55),.92,0),('rose',(.57,.25,.25),.86,0),
    ('leaf',(.12,.30,.075),.9,0),('leaf_light',(.27,.43,.12),.9,0),('leaf_dark',(.055,.17,.045),.94,0),
    ('flower_gold',(.94,.57,.09),.86,0),('flower_cream',(.95,.82,.52),.86,0),('flower_coral',(.77,.24,.20),.86,0),
    ('stone',(.34,.35,.30),.96,0),('stone_warm',(.49,.43,.32),.96,0),('stone_light',(.58,.57,.45),.96,0),
    ('soil',(.13,.075,.035),1,0),('chalk',(.90,.85,.68),.95,0)]:mat(key,col,rough,metal)

BATCH={}
def append(category,key,verts,faces):
    item=BATCH.setdefault((category,key),[[],[]]);offset=len(item[0]);item[0].extend(verts);item[1].extend([tuple(offset+i for i in f) for f in faces])

def box(cat,key,pos,size):
    x,y,z=pos;a,b,c=[s/2 for s in size]
    v=[(x+sx*a,y+sy*b,z+sz*c) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    append(cat,key,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])

def tube(cat,key,a,b,r,segments=8):
    a,b=Vector(a),Vector(b);axis=b-a
    if axis.length<1e-5:return
    q=axis.to_track_quat('Z','Y');v=[p+q@Vector((r*math.cos(t*math.tau/segments),r*math.sin(t*math.tau/segments),0)) for p in [a,b] for t in range(segments)]
    f=[tuple(range(segments-1,-1,-1)),tuple(range(segments,2*segments))]+[(i,(i+1)%segments,(i+1)%segments+segments,i+segments) for i in range(segments)]
    append(cat,key,v,f)

def oval(cat,key,pos,radii):
    p=Vector(pos);v=[];segments=10;rings=5
    v.append(tuple(p+Vector((0,0,-radii[2]))))
    for j in range(1,rings):
        e=-math.pi/2+math.pi*j/rings
        for i in range(segments):
            a=math.tau*i/segments;v.append((p.x+radii[0]*math.cos(a)*math.cos(e),p.y+radii[1]*math.sin(a)*math.cos(e),p.z+radii[2]*math.sin(e)))
    top=len(v);v.append(tuple(p+Vector((0,0,radii[2]))));f=[]
    for i in range(segments):f.append((0,1+(i+1)%segments,1+i))
    for j in range(rings-2):
        for i in range(segments):
            a=1+j*segments+i;b=1+j*segments+(i+1)%segments;f.append((a,b,b+segments,a+segments))
    for i in range(segments):f.append((1+(rings-2)*segments+i,1+(rings-2)*segments+(i+1)%segments,top))
    append(cat,key,v,f)

def leaf(cat,key,base,length,angle,lift=.3):
    d=Vector((math.cos(angle),math.sin(angle),0));side=Vector((-d.y,d.x,0));b=Vector(base);mid=b+d*length*.5+Vector((0,0,length*lift));tip=b+d*length+Vector((0,0,length*lift*.45));w=length*.20
    v=[b,mid+side*w,tip,mid-side*w,mid+Vector((0,0,length*.07)),mid-Vector((0,0,.012))]
    append(cat,key,v,[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,0,5),(2,1,5),(3,2,5),(0,3,5)])

def plant(cat,pos,seed,scale=1,flowers=False):
    rng=random.Random(seed);p=Vector(pos)
    for i in range(7):leaf(cat,['leaf','leaf_light','leaf_dark'][i%3],p,rng.uniform(.22,.42)*scale,i*2.4+rng.random()*.3,rng.uniform(.45,.9))
    if flowers:
        for i in range(3):
            a=i*2.4;r=.11*scale;q=p+Vector((math.cos(a)*r,math.sin(a)*r,rng.uniform(.33,.49)*scale));tube(cat,'leaf_dark',p,q,.012*scale,6)
            for k in range(5):
                a=k*math.tau/5;oval(cat,['flower_gold','flower_cream','flower_coral'][seed%3],q+Vector((math.cos(a)*.06*scale,math.sin(a)*.06*scale,0)),(.05*scale,.05*scale,.025*scale))
            oval(cat,'flower_gold',q,(.027*scale,)*3)

def move_center(o,target):
    mn,mx=bounds(o);o.matrix_world.translation+=Vector(target)-(mn+mx)/2

def fix_buried_details():
    wall=bpy.data.objects.get('Rear_Wall')
    if wall:
        mn,mx=bounds(wall);cx=(mn.x+mx.x)/2;front=mn.y
        dado=bpy.data.objects.get('WR_Dado_Rear_Wall')
        if dado and dado.name not in GUARD:
            move_center(dado,(cx,front-.028,1.02));CHANGE['repairs'].append(dado.name)
        battens=sorted([o for o in ORIGINAL if o.name.startswith('WR_Wall_Batten_Rear_Wall') and o.name not in GUARD],key=lambda o:o.name)
        for i,o in enumerate(battens):
            move_center(o,(mn.x+.32+(mx.x-mn.x-.64)*(i+.5)/len(battens),front-.026,.53))
            o.data=o.data.copy();o.data.materials.clear();o.data.materials.append(MATS['sage']);CHANGE['repairs'].append(o.name)
        # The 90 cm lower wall remains open and all classroom/sign surfaces remain visible.
        box('Wainscot','sage',(cx,front-.008,.49),(mx.x-mn.x-.36,.025,.85))
        box('PictureRail','cream',(cx,front-.047,1.04),(mx.x-mn.x-.24,.10,.09))
        count=max(3,int((mx.x-mn.x)/1.25))
        for i in range(count):
            x=mn.x+.22+(i+.5)*(mx.x-mn.x-.44)/count
            box('WainscotPanels','cream',(x,front-.031,.52),((mx.x-mn.x-.44)/count-.16,.026,.61))
        CHANGE['architecture'].append('Visible lower-wall panel joinery, below existing teaching signs and windows')
    for ob in ORIGINAL:
        if ob.name in GUARD or ob.type!='MESH':continue
        if ob.name.startswith('WR_Inlay_'):
            target=bpy.data.objects.get(ob.name[len('WR_Inlay_'):])
            if target and target.type=='MESH':
                mn,mx=bounds(target);a,b=bounds(ob);ob.matrix_world.translation.z+=mx.z+.009-(a.z+b.z)/2;CHANGE['repairs'].append(ob.name)
        if ob.name.startswith('WR_Cabinet_Pull_'):
            tail=ob.name[len('WR_Cabinet_Pull_'):];base=re.sub(r'\.\d+$','',tail);target=bpy.data.objects.get(base)
            if target:
                mn,mx=bounds(target);suffix=0 if tail==base else int(tail.rsplit('.',1)[1]);side=-1 if suffix%2==0 else 1
                move_center(ob,((mn.x+mx.x)/2+side*.15,mn.y-.055,(mn.z+mx.z)*.55));CHANGE['repairs'].append(ob.name)
    if ROOM=='school':
        paths=[o for o in ORIGINAL if o.type=='MESH' and o.name not in GUARD and any(s.material and s.material.name=='WR_stone_CAMPUS_path' for s in o.material_slots)]
        # The visual paving surfaces were exactly coplanar at every crossing.
        # Separate their surfaces by sub-centimetre amounts; SG_FLOOR stays identical.
        for i,o in enumerate(sorted(paths,key=lambda o:o.name)):
            o.data=o.data.copy();delta=o.matrix_world.inverted().to_3x3()@Vector((0,0,(i+1)*.0006))
            for v in o.data.vertices:v.co+=delta
            CHANGE['repairs'].append(o.name+' / coplanar paving intersection')

def architecture():
    outdoor=ROOM in ['island','school','home_estate']
    if outdoor:
        walls=[o for o in ORIGINAL if o.type=='MESH' and (o.name.endswith('_Walls') or o.name=='ALPHA_Home_Cream_Walls') and 'Cutaway' not in o.name]
        for o in walls:
            mn,mx=bounds(o);h=mx.z-mn.z
            if h<2 or mx.x-mn.x<2:continue
            for x in [mn.x+.11,mx.x-.11]:
                for k in range(int(h/.52)):
                    z=mn.z+.24+k*.52
                    box('FacadeQuoins','cream',(x,mn.y-.045,z),(.28 if k%2 else .40,.105,.21))
            for x in [mn.x+.40+i*.78 for i in range(max(1,int((mx.x-mn.x-.8)/.78)))]:
                box('EaveCorbels','oak',(x,mn.y-.10,mx.z-.11),(.12,.24,.30))
            CHANGE['architecture'].append(o.name+' / corner courses and eave corbels')
        for o in ORIGINAL:
            if o.type!='MESH' or not o.name.endswith('_Roof_Ridge'):continue
            mn,mx=bounds(o);length=mx.x-mn.x
            if length<1.5:continue
            for i in range(max(2,int(length/.45))):
                x=mn.x+(i+.5)*length/max(2,int(length/.45))
                tube('RidgeCaps','clay' if ROOM=='home_estate' else 'teal',(x-.205,(mn.y+mx.y)/2,mx.z+.035),(x+.205,(mn.y+mx.y)/2,mx.z+.035),.105,10)
        # Small existing planter volumes receive mixed leaf forms, without enlarging their footprint.
        for k,o in enumerate(ORIGINAL):
            n=o.name.lower()
            if o.type!='MESH' or not ('planter' in n or 'windowbox' in n) or not any(t in n for t in ['_base','_box','windowbox']):continue
            if any(t in n for t in ['flower','leaf','green']):continue
            mn,mx=bounds(o);dx=mx.x-mn.x;dy=mx.y-mn.y
            if dx<.45 or dy<.20 or mx.z-mn.z>1.5:continue
            for j in range(min(5,max(2,round(dx/.38)))):
                x=mn.x+.13+(dx-.26)*(j+.5)/min(5,max(2,round(dx/.38)));plant('WindowHerbs',(x,(mn.y+mx.y)/2,mx.z),k+j,.75,True)
            CHANGE['vegetation'].append(o.name)
    if ROOM=='island':
        # The original small home is preserved, with a raised, shallow entrance canopy.
        for side in [-1,1]:
            x=-3+side*1.07;tube('HomeCanopy','oak',(x,-16.78,7.87),(x,-17.42,8.35),.065)
            tube('HomeCanopy','oak_light',(x,-16.78,8.50),(x,-17.48,8.30),.055)
        for i in range(12):
            x=-4.2+(i+.5)*.2
            append('HomeCanopy','teal',[(x-.098,-16.76,8.60),(x+.098,-16.76,8.60),(x+.098,-17.52,8.37),(x-.098,-17.52,8.37),(x-.098,-16.76,8.55),(x+.098,-16.76,8.55),(x+.098,-17.52,8.32),(x-.098,-17.52,8.32)],[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)])
        for center in [-5.05,-.95]:
            for s in [-1,1]:
                x=center+s*.75;box('HomeShutters','teal',(x,-16.79,7.65),(.28,.10,1.32))
                for k in range(7):box('HomeShutterLouvers','sage',(x,-16.855,7.12+k*.165),(.24,.045,.07))
        CHANGE['architecture'].append('Home: shallow segmented entrance canopy, timber braces and louvered shutters')

def island_ecology():
    if ROOM!='island':return
    terrain=bpy.data.objects['ALPHA_Island_Continuous_Terrain'];tree=BVHTree.FromObject(terrain,bpy.context.evaluated_depsgraph_get());inv=terrain.matrix_world.inverted()
    markers=[o.matrix_world.translation.copy() for o in ORIGINAL if o.name.startswith('SG_')]
    roadtrees=[]
    for o in ORIGINAL:
        if o.type=='MESH' and o.get('sg_collision')=='ground' and any(t in o.name.lower() for t in ['path','road','plaza','paver','court','plot']):
            roadtrees.append((o,BVHTree.FromObject(o,bpy.context.evaluated_depsgraph_get())))
    def zground(x,y):
        hit=tree.ray_cast(inv@Vector((x,y,50)),inv.to_3x3()@Vector((0,0,-1)),100)[0]
        return (terrain.matrix_world@hit).z if hit else None
    def clear(x,y):
        if any(math.hypot(x-p.x,y-p.y)<3.4 for p in markers):return False
        for o,t in roadtrees:
            im=o.matrix_world.inverted();hit=t.ray_cast(im@Vector((x,y,50)),im.to_3x3()@Vector((0,0,-1)),100)[0]
            if hit is not None:return False
        return True
    trunks=[o for o in ORIGINAL if o.type=='MESH' and o.get('sg_collision')=='trunk' and 'palm' not in o.name.lower()]
    count=0
    for i,o in enumerate(trunks):
        if i%2:continue
        mn,mx=bounds(o);c=(mn+mx)/2
        for k in range(2):
            a=i*2.4+k*2.8;x=c.x+math.cos(a)*.95;y=c.y+math.sin(a)*.95;z=zground(x,y)
            if z is not None and clear(x,y):plant('Understory',(x,y,z+.012),i*7+k,1.25,i%3==0);count+=1
    CHANGE['vegetation'].append({'understory_groups':count,'road_and_marker_clearance':True})
    # Facet and terrace non-colliding coastal stones inside their existing silhouettes.
    rocks=[o for o in ORIGINAL if o.type=='MESH' and o.name not in GUARD and (o.name.startswith('ALPHA_Coastal_Boulder') or o.name.startswith('ALPHA_V3_Shore_Rock'))]
    for o in rocks:
        o.data=o.data.copy();zmin=min(v.co.z for v in o.data.vertices);zmax=max(v.co.z for v in o.data.vertices);h=zmax-zmin
        if h<.01:continue
        for v in o.data.vertices:
            t=(v.co.z-zmin)/h;v.co.z=zmin+h*(.7*t+.3*round(t*5)/5)
        o.data.materials.clear()
        for k in ['stone','stone_warm','stone_light']:o.data.materials.append(MATS[k])
        o.data.update()
        for f in o.data.polygons:
            t=(f.center.z-zmin)/h;f.material_index=2 if t>.68 else 1 if .25<t<.44 else 0;f.use_smooth=False
        CHANGE['architecture'].append(o.name+' / layered coastal stone')
    for m in bpy.data.materials:
        if not m.use_nodes:continue
        key=m.name.lower();p=m.node_tree.nodes.get('Principled BSDF')
        if not p or p.inputs['Base Color'].is_linked:continue
        if any(t in key for t in ['leaf_mid','leaf_light','leaf_deep']):
            color={'leaf_mid':(.14,.32,.075),'leaf_light':(.28,.46,.14),'leaf_deep':(.065,.18,.04)}
            for k,c in color.items():
                if k in key:p.inputs['Base Color'].default_value=(*c,1);m.diffuse_color=(*c,1);CHANGE['material_changes'].append(m.name)

def room_details():
    if ROOM in ['island','school','home_estate']:return
    # Existing furniture footprint, task objects, signs and all interactive subtrees are untouched.
    for o in ORIGINAL:
        if o.type!='MESH' or o.name in GUARD or o.name.startswith(('WR_','Living','CF08_')):continue
        n=o.name.lower();mn,mx=bounds(o);d=mx-mn;c=(mn+mx)/2
        if ('cabinet' in n or 'wardrobe' in n) and n.endswith(('_cabinet','_case')) and d.x>1 and .7<d.z<3.5:
            cols=max(2,round(d.x/.95))
            for i in range(cols):
                w=d.x/cols;x=mn.x+(i+.5)*w
                box('CabinetPanels','sage' if ROOM in ['home_kitchen','science_room'] else 'oak_light',(x,mn.y-.014,c.z),(w-.11,.028,d.z-.22))
                box('CabinetPanels','cream',(x,mn.y-.032,c.z),(w-.20,.020,d.z-.34))
                tube('CabinetHardware','brass',(x+w*.25,mn.y-.075,c.z-.06),(x+w*.25,mn.y-.075,c.z+.06),.025)
            CHANGE['architecture'].append(o.name+' / recessed panels and handles')
        if n.endswith('_book') or '_book.' in n:
            if d.x<.8 and d.y<.9 and d.z>.2:
                for z in [mn.z+d.z*.18,mx.z-d.z*.18]:box('BookBinding','cream',(c.x,mn.y-.008,z),(d.x*.88,.014,.018))
        if 'acousticpanel' in n:
            for i in range(5):
                y=mn.y+(i+.5)*d.y/5;x=mx.x+.018 if c.x<0 else mn.x-.018
                box('AcousticBattens','oak_light',(x,y,c.z),(.035,.04,d.z-.12))
            CHANGE['architecture'].append(o.name+' / timber acoustic slats')
        if n.endswith(('_desk_top','_table_top')) and ROOM in ['home_study','home_dining','canteen']:
            box('TableLinen','sage' if ROOM=='home_study' else 'linen',(c.x,c.y,mx.z+.012),(d.x*.73,d.y*.44,.018))
            for x in [c.x-d.x*.35,c.x+d.x*.35]:box('TableLinenStitch','oak',(x,c.y,mx.z+.023),(.018,d.y*.40,.006))
            CHANGE['architecture'].append(o.name+' / inset textile runner')
        if n.endswith('_headboard') and d.z>.3 and d.x>1:
            for i in range(7):box('BedJoinery','oak_light',(mn.x+(i+.5)*d.x/7,mn.y-.018,c.z),(d.x/7-.075,.04,d.z-.12))
            CHANGE['architecture'].append(o.name+' / headboard joinery')
        if n.endswith('_soil') and max(d.x,d.y)<1.5:
            plant('InteriorHerbs',(c.x,c.y,mx.z+.005),len(CHANGE['vegetation']),.75,False);CHANGE['vegetation'].append(o.name)
        if ROOM=='home_hall' and n=='entry_bench_cushion':
            for i in range(4):
                for j in range(2):oval('CushionTufts','linen',(mn.x+d.x*(i+1)/5,mn.y+d.y*(j+1)/3,mx.z+.008),(.042,.042,.015))
            CHANGE['architecture'].append('Entry bench cushion: stitched button tufts')
    if ROOM=='classroom':
        o=bpy.data.objects.get('Class_Blackboard')
        if o:
            mn,mx=bounds(o);box('ChalkTray','oak',((mn.x+mx.x)/2,mn.y-.12,mn.z-.045),(mx.x-mn.x+.16,.24,.095))
            for i in range(4):tube('Chalk','chalk',(mn.x+.4+i*.25,mn.y-.15,mn.z+.012),(mn.x+.57+i*.25,mn.y-.15,mn.z+.012),.022)
            CHANGE['architecture'].append('Blackboard: modeled chalk tray, rounded chalk sticks')
    if ROOM in ['playground','football_field','home_balcony']:
        for o in ORIGINAL:
            n=o.name.lower()
            if o.type!='MESH' or o.name in GUARD or not any(t in n for t in ['bench_seat','bench_top','rail_post','swing_beam','goal_post']):continue
            mn,mx=bounds(o);c=(mn+mx)/2;d=mx-mn
            for x in [mn.x+d.x*.15,mx.x-d.x*.15]:oval('OutdoorFasteners','brass',(x,mn.y-.012,mx.z-.04),(.025,.018,.025))
            CHANGE['architecture'].append(o.name+' / visible fasteners')
    if ROOM=='playground':
        for o in ORIGINAL:
            if o.name.startswith('Running_Track'):
                mn,mx=bounds(o);c=(mn+mx)/2;rx=(mx.x-mn.x)/2;ry=(mx.y-mn.y)/2
                verts=[]
                for rad in [-.13,.13]:
                    for k in range(96):
                        t=k*math.tau/96;verts.append((c.x+(rx+rad)*math.cos(t),c.y+(ry+rad)*math.sin(t),.038))
                append('TrackLanes','clay',verts,[(k,k+96,(k+1)%96+96,(k+1)%96) for k in range(96)])
                CHANGE['architecture'].append(o.name+' / rubber lane band under retained painted line')
        hoop=bpy.data.objects.get('Basketball_Hoop')
        if hoop:
            mn,mx=bounds(hoop);c=(mn+mx)/2;r=max(mx.x-mn.x,mx.y-mn.y)*.45
            for k in range(12):
                a=k*math.tau/12;b=a+.28
                tube('HoopNet','linen',(c.x+r*math.cos(a),c.y+r*math.sin(a),c.z),(c.x+r*.62*math.cos(b),c.y+r*.62*math.sin(b),c.z-.46),.009,5)
            CHANGE['architecture'].append('Basketball hoop: woven hanging net')

fix_buried_details();architecture();island_ecology();room_details()
collection=bpy.data.collections.new('Cloud_Refinement_08');scene.collection.children.link(collection)
for (category,key),(verts,faces) in BATCH.items():
    mesh=bpy.data.meshes.new('CF08_'+category+'_'+key);mesh.from_pydata(verts,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    ob=bpy.data.objects.new(mesh.name,mesh);collection.objects.link(ob);mesh.materials.append(MATS[key]);ob['sg_collision']='none';ob['cloud_refinement']='2026-10-25 / authored Blender geometry'
    if category in ['FacadeQuoins','EaveCorbels','WainscotPanels','CabinetPanels','HomeShutters','ChalkTray','BedJoinery']:
        mod=ob.modifiers.new('Soft crafted edges','BEVEL');mod.width=.004 if category=='CabinetPanels' else .012;mod.segments=2
        mod=ob.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
bpy.context.view_layer.update()
assert signature()==GUARD,'Protected gameplay transforms, properties or geometry changed'
CHANGE['protected_objects']=len(GUARD);CHANGE['protected_signature_unchanged']=True
CHANGE['new_mesh_objects']=len(BATCH);CHANGE['new_base_vertices']=sum(len(x[0]) for x in BATCH.values());CHANGE['new_base_faces']=sum(len(x[1]) for x in BATCH.values())
scene['cloud_refinement_revision']='cloud-08';scene['cloud_source_limitation']='Blender 5.2 original preserved; editing baseline imported from the exact current GLB in Blender 4.3.2'
scene['cloud_refinement_note']='Gameplay markers, original collision geometry and scene layout retained. REVIEW cameras/lights excluded from GLB.'
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False;scene.cycles.device='CPU'
scene.render.resolution_x=1200;scene.render.resolution_y=833;scene.render.resolution_percentage=100
bpy.context.preferences.filepaths.save_version=0
OUT.parent.mkdir(parents=True,exist_ok=True);EV.mkdir(parents=True,exist_ok=True)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for o in scene.objects:
    if o.type in ['MESH','EMPTY'] and not o.name.startswith('REVIEW_'):o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT.with_suffix('.glb')),export_format='GLB',use_selection=True,use_visible=False,use_renderable=False,export_apply=True,export_extras=True,export_yup=True,export_cameras=False,export_lights=False)
CHANGE['blend']=str(OUT);CHANGE['glb']=str(OUT.with_suffix('.glb'))
CHANGE['blend_sha256']=hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()
(EV/'changes.json').write_text(json.dumps(CHANGE,ensure_ascii=False,indent=2))
print('CLOUD_REFINED',json.dumps({k:v for k,v in CHANGE.items() if k not in ['repairs','architecture','vegetation','material_changes']}),flush=True)
