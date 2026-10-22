"""Entrance paths and site-specific street furniture for all 26 imported models.
Uses the existing world module. Adds an isolated collection, safely rebuilt on rerun.
"""
import bpy
import math
import json
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import studygame_world as w

def detail_sites():
    if 'red' not in w.MATS:w.MATS['red']=w.make_material('red',(.74,.09,.045))
    name='ALPHA_Site_Detail_v02'
    coll=bpy.data.collections.get(name)
    if coll:
        for o in list(coll.objects):bpy.data.objects.remove(o,do_unlink=True)
    else:
        coll=bpy.data.collections.new(name);w.SCENE.collection.children.link(coll)
    w.COLLS['Site_Detail_v02']=coll
    terrain=bpy.data.objects['ALPHA_Island_Continuous_Terrain']
    tree=BVHTree.FromObject(terrain,bpy.context.evaluated_depsgraph_get())
    def ground(x,y):
        co,*_=tree.ray_cast(Vector((x,y,80)),Vector((0,0,-1)),150)
        return co.z if co else w.height(x,y)
    def ground_path(letter,x,y0,y1,width):
        steps=max(2,math.ceil(abs(y1-y0)/.28));cross=8;verts=[];faces=[]
        for i in range(steps+1):
            y=y0+(y1-y0)*i/steps
            for j in range(cross+1):
                xx=x+width*(j/cross-.5);verts.append((xx,y,ground(xx,y)+.155))
        for i in range(steps):
            for j in range(cross):
                a=i*(cross+1)+j;b=a+cross+1;faces.extend([(a,a+1,b+1),(a,b+1,b)])
        obj=w.mesh(letter+'_Entry_Link_v02',verts,faces,w.MATS['path'],'Site_Detail_v02')
        obj['landmark']=letter;obj['entry_connection']=True
    bounds={}
    for p in w.PLOTS:
        letter=p['letter'];socket=bpy.data.objects[p['socket_name']]
        meshes=[o for o in socket.children_recursive if o.type=='MESH' and not o.get('editor_only')]
        corners=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
        mn=Vector([min(c[k] for c in corners) for k in range(3)]);mx=Vector([max(c[k] for c in corners) for k in range(3)])
        bounds[letter]=(mn,mx)
        if letter not in 'AB':
            ground_path(letter,p['x'],p['entrance'][1],mn.y+.15,min(2.8,p['target_width']*.36))
            socket['entry_front_y']=mn.y
            anchor=bpy.data.objects.get('ALPHA_'+letter+'_LOCUS_01')
            if anchor:anchor.location=(p['x'],mn.y-.7,ground(p['x'],mn.y-.7)+.17)
    def box(name,x,y,z,size,material='wood_light'):
        return w.box(name,(x,y,z),size,w.MATS[material],'Site_Detail_v02',.05)
    def disc(name,x,y,z,r,depth,material='wood_light',n=20):
        return w.cylinder(name,(x,y,z),r,depth,w.MATS[material],'Site_Detail_v02',n)
    def stool(name,x,y,color='wood_light'):
        z=ground(x,y);disc(name+'_Leg',x,y,z+.29,.14,.58,'wood',10);disc(name+'_Seat',x,y,z+.62,.43,.15,color)
    def table(name,x,y):
        z=ground(x,y);disc(name+'_Leg',x,y,z+.5,.15,1.0,'wood',10);disc(name+'_Top',x,y,z+1.03,.88,.15)
    def bench(name,x,y):
        z=ground(x,y)
        for dx in [-.75,.75]:box(name+'_Leg',x+dx,y,z+.27,(.14,.62,.54),'wood')
        box(name+'_Seat',x,y,z+.59,(2,.65,.15));box(name+'_Back',x,y+.31,z+.98,(2,.13,.62))
    def planters(name,x,y,color='pink'):
        z=ground(x,y);box(name+'_Box',x,y,z+.24,(1.25,.62,.48),'wood')
        for dx in [-.4,0,.4]:
            w.ball(name+'_Green',(x+dx,y,z+.66),(.28,.25,.3),w.MATS['leaf'],'Site_Detail_v02')
            w.ball(name+'_Flower',(x+dx,y-.07,z+.93),(.19,.18,.16),w.MATS[color],'Site_Detail_v02')
    # Each site keeps an unobstructed entry lane; props sit on its side.
    for letter in 'DEFGHIJKLMNOPQRSTUVWXYZ':
        p=w.BY_LETTER[letter];x=p['x'];fy=bounds[letter][0].y;side=p['target_width']*.5+.8
        planters(letter+'_Entry_Planter',x-side,fy+.6,'yellow' if letter in 'GILSTW' else 'pink')
    # D music circle and E nursery seating.
    for i in range(5):
        a=.15+i*math.pi/4;stool('D_Music_Seat',-24+2.4*math.cos(a),-27+2.4*math.sin(a),'yellow')
    bench('E_Nursery_Bench',-43,-11)
    # I's ice-cream terrace, G's route-planning table, and O's reading spot.
    table('I_Terrace_Table',-31.5,40);stool('I_Terrace_Seat',-30.1,40,'pink');stool('I_Terrace_Seat',-32.9,40,'teal')
    table('G_Travel_Table',-47,17)
    z=ground(-47,17);box('G_Map_Sheet',-47,17,z+1.13,(1.2,.7,.03),'cream')
    for xx,yy in [(-47.35,16.8),(-46.7,17.15)]:disc('G_Map_Marker',xx,yy,z+1.18,.10,.09,'red',10)
    bench('O_Reading_Bench',46.8,24.5)
    # R has a workbench, T a waiting platform, U a rain collector.
    x,y=62,-9;z=ground(x,y)
    for dx in [-.75,.75]:box('R_Workbench_Leg',x+dx,y,z+.5,(.15,.6,1),'wood')
    box('R_Workbench_Top',x,y,z+1.05,(2.0,.9,.14));box('R_Toolbox',x-.45,y,z+1.34,(.65,.45,.45),'teal')
    for dx in [0,.3,.6]:disc('R_Parts',x+dx,y,z+1.16,.12,.10,'rock',10)
    x,y=50,-30.6;z=ground(x,y)
    box('T_Passenger_Platform',x,y,z+.12,(10,1.7,.24),'paving')
    bench('T_Waiting_Bench',46.3,-31.1)
    disc('U_Rain_Barrel',39.8,-37,ground(39.8,-37)+.6,.6,1.2,'wood',16)
    disc('U_Barrel_Water',39.8,-37,ground(39.8,-37)+1.22,.48,.03,'water',24)
    # X audience seats, Y knitting corner and Z mailbox.
    for xx in [-11.5,-7,-2.5]:bench('X_Audience_Bench',xx,-60)
    table('Y_Craft_Table',-24.5,-42)
    for dx,color in [(-.35,'pink'),(.0,'yellow'),(.35,'teal')]:
        w.ball('Y_Yarn_Ball',(-24.5+dx,-42,ground(-24.5,-42)+1.38),(.26,.25,.25),w.MATS[color],'Site_Detail_v02')
    x,y=-37.8,-51.6;z=ground(x,y)
    box('Z_Mailbox_Post',x,y,z+.65,(.18,.18,1.3),'wood');box('Z_Mailbox',x,y,z+1.52,(.85,.65,.65),'teal');box('Z_Mail_Slot',x,y-.34,z+1.56,(.53,.04,.07),'wood_dark')
    # Move only trees directly blocking the widened train platform.
    moved=[]
    for obj in w.COLLS['Forest'].objects:
        if 44<obj.location.x<56 and -32.3<obj.location.y<-29.4:
            obj.hide_render=True;obj.hide_set(True);obj['site_clearance_hidden']=True;moved.append(obj.name)
    w.SCENE['site_detail_version']=2
    (w.BASE/'site_detail_v02.json').write_text(json.dumps({'entry_links':24,'added_objects':len(coll.objects),'hidden_for_platform':moved,'features':['music seating','nursery bench','ice cream terrace','travel table','reading bench','robot workbench','station platform','rain barrel','audience benches','yarn table','mailbox']},ensure_ascii=False,indent=2)+'\n')
    print({'site_details':len(coll.objects),'entry_links':24,'platform_clearance_hidden':len(moved)})


def cameras():
    settings=[('Northwest_Craft',(-14,-19,65),(-38,28,9),64),('Forest_Village',(61,-13,70),(24,32,9),66),('Eastern_Academy',(98,-65,65),(48,-13,6),61),('South_Bay',(28,-106,55),(-10,-43,4),68)]
    for name,loc,target,scale in settings:
        obj=bpy.data.objects.get('ALPHA_Camera_'+name)
        if not obj:
            data=bpy.data.cameras.new('ALPHA_Camera_'+name);w.enum_set(data,'type','ORTHO');obj=w.link('Camera_'+name,data,'Camera_Lighting')
        obj.location=loc;obj.data.ortho_scale=scale;w.aim(obj,target)
    print({'additional_cameras':len(settings)})

if __name__=='__main__':detail_sites();cameras()


def clear_entry_sightlines():
    changes=[]
    trunks=[o for o in w.COLLS['Forest'].objects if '_Trunk' in o.name and o.name.startswith('ALPHA_Forest_')]
    for p in w.PLOTS:
        socket=bpy.data.objects[p['socket_name']];fy=socket.get('entry_front_y')
        if fy is None:continue
        for trunk in trunks:
            if trunk.get('entry_sightline_reduced'):continue
            if abs(trunk.location.x-p['x'])<2.5 and fy-12<trunk.location.y<fy-1.5:
                prefix=trunk.name.rsplit('_Trunk',1)[0]+'_'
                base=Vector((trunk.location.x,trunk.location.y,w.height(trunk.location.x,trunk.location.y)))
                for obj in w.COLLS['Forest'].objects:
                    if obj.name.startswith(prefix):
                        obj.location=base+(obj.location-base)*.43;obj.scale*=.43;obj['entry_sightline_reduced']=True
                changes.append({'tree':prefix,'landmark':p['letter']})
    prior=w.BASE/'site_detail_v02.json'
    report=json.loads(prior.read_text());report['entry_sightline_lowered_trees']=changes
    prior.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print({'sightline_reduced_trees':changes})

if __name__=='__main__':clear_entry_sightlines()
