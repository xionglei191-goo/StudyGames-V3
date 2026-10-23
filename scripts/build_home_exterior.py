"""Original cottage exterior v02. Explicit rebuild only; v01 and all rooms preserved."""
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'assets/blender/interiors/scripts'))
sys.path.insert(0, str(ROOT / 'scripts'))
import modeling as m
import pipeline as p
import build_home_scenes as h
from home_courtyard_detail import build_courtyard


def palette():
    colors = {'plaster':(.88,.80,.65), 'trim':(.94,.88,.73),
              'roof':(.12,.29,.29), 'roof_light':(.16,.34,.33), 'roof_dark':(.10,.25,.26),
              'foundation':(.42,.43,.38), 'window_dark':(.10,.18,.20),
              'window_glass':(.25,.42,.44), 'doorwood':(.20,.31,.26),
              'mortar':(.34,.35,.30), 'stonewarm':(.64,.59,.47)}
    for key, rgb in colors.items():
        mat=bpy.data.materials.new('MAT_'+key);mat.use_nodes=True
        bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        bsdf.inputs['Base Color'].default_value=(*rgb,1)
        bsdf.inputs['Roughness'].default_value=.78
        mat.diffuse_color=(*rgb,1);m.M[key]=mat


def facade(name, length, height, openings, origin, rotation=0):
    """Real openings in wall strips with recessed glass, sills and dimensional trim."""
    old=m.PARENT
    root=m.empty(name,origin);root.rotation_euler.z=rotation;m.PARENT=root
    cuts=sorted([-length/2,length/2]+[v for o in openings for v in [o[0]-o[1]/2,o[0]+o[1]/2]])
    for a,b in zip(cuts,cuts[1:]):
        if b-a<.001:continue
        mid=(a+b)/2
        opening=next((o for o in openings if o[0]-o[1]/2<mid<o[0]+o[1]/2),None)
        spans=[(0,height)] if opening is None else [(0,opening[2]),(opening[2]+opening[3],height)]
        for lo,hi in spans:
            if hi-lo>.01:m.box(name+'_Plaster', (mid,0,(lo+hi)/2),(b-a,.40,hi-lo),'plaster',.025)
    m.box(name+'_Stone_Skirting',(0,-.03,.25),(length,.49,.5),'foundation',.035)
    m.box(name+'_Timber_Eave',(0,-.05,height-.08),(length+.12,.58,.20),'oak',.035)
    for i,(x,w,z,hh,kind) in enumerate(openings):
        pre=name+f'_Opening_{i}'
        m.box(pre+'_Interior_Shadow',(x,.16,z+hh/2),(w,.06,hh),'window_dark',.02)
        for dx in [-w/2-.07,w/2+.07]:m.box(pre+'_Jamb',(x+dx,-.14,z+hh/2),(.18,.28,hh+.25),'trim',.035)
        m.box(pre+'_Lintel',(x,-.17,z+hh+.12),(w+.45,.38,.23),'trim',.04)
        if kind=='door':
            m.box(pre+'_Door',(x,.03,z+hh/2),(w-.10,.16,hh-.08),'doorwood',.04)
            for dx in [-w*.24,w*.24]:
                for zz in [z+.55,z+1.48]:
                    m.box(pre+'_Raised_Panel',(x+dx,-.065,zz),(w*.36,.07,.72),'teal',.05)
            m.box(pre+'_Transom',(x,-.07,z+hh-.38),(w-.35,.05,.40),'window_glass',.03)
            for dx in [-.30,0,.30]:m.box(pre+'_Transom_Bar',(x+dx,-.11,z+hh-.38),(.045,.06,.41),'trim',.01)
            m.ball(pre+'_Brass_Knob',(x+w*.32,-.17,1.25),(.08,.065,.08),'gold',12,8)
            m.box(pre+'_Threshold',(x,-.3,.07),(w+.45,.80,.14),'stonewarm',.04)
        else:
            m.box(pre+'_Inset_Glass',(x,.07,z+hh/2),(w-.12,.06,hh-.12),'window_glass',.01)
            for dx in [-w/2+.08,0,w/2-.08]:m.box(pre+'_Mullion',(x+dx,-.01,z+hh/2),(.10,.12,hh-.05),'trim',.02)
            for zz in [z+.06,z+hh/2,z+hh-.06]:m.box(pre+'_Crossbar',(x,-.01,zz),(w,.12,.10),'trim',.02)
            m.box(pre+'_Projecting_Sill',(x,-.25,z-.10),(w+.45,.66,.20),'stonewarm',.045)
            if kind=='shutter':
                for side in [-1,1]:
                    xx=x+side*(w/2+.40)
                    m.box(pre+'_Shutter',(xx,-.13,z+hh/2),(.50,.16,hh+.12),'teal',.035)
                    for k in range(6):m.box(pre+'_Shutter_Louver',(xx,-.23,z+.18+k*(hh-.30)/5),(.40,.08,.09),'mint',.015)
            if kind=='flower':
                m.box(pre+'_Flower_Box',(x,-.48,z-.37),(w+.25,.65,.40),'oak',.06)
                m.box(pre+'_Flower_Soil',(x,-.48,z-.14),(w+.10,.55,.055),'soil',.015)
                for k in range(5):
                    xx=x+(k-2)*w*.16
                    m.ball(pre+'_Leaf',(xx,-.50,z+.01),(.18,.20,.17),'leaf',12,8)
                    m.ball(pre+'_Flower',(xx,-.55,z+.17),(.10,.12,.10),['rose','yellow','ivory'][k%3],10,6)
    m.PARENT=old
    return root


def roof(name, cx,cy,width,depth,eave,rise,rot=0, omit_inner=None):
    """Closed pitched roof, low-contrast overlapping courses, substantial eaves."""
    old=m.PARENT;root=m.empty(name,(cx,cy,0));root.rotation_euler.z=rot;m.PARENT=root
    half=width/2;front=-depth/2;rear=depth/2
    vs=[(-half,front,eave),(half,front,eave),(0,front,eave+rise),(-half,rear,eave),(half,rear,eave),(0,rear,eave+rise)]
    m.mesh(name+'_Gable',vs,[(0,1,2),(5,4,3),(0,3,4,1),(0,2,5,3),(2,1,4,5)],'plaster')
    slope=math.atan2(rise,half);length=math.hypot(half,rise)
    for side in [-1,1]:
        ob=m.box(name+'_Roof_Base',(side*half/2,0,eave+rise/2+.10),(length+.55,depth+.9,.22),'roof_dark',.025)
        ob.rotation_euler.y=side*slope
        count=8;course=(length+.4)/count
        for row in range(count):
            dist=(row+.5)*course-.15
            x=side*(half-dist*math.cos(slope));z=eave+dist*math.sin(slope)+.24
            for j in range(math.ceil((depth+.8)/1.5)):
                # Broad slate courses, slight tonal variations, no black pinstripes.
                yy=-depth/2-.4+(j+.5)*(depth+.8)/math.ceil((depth+.8)/1.5)
                tone=['roof','roof','roof_light','roof','roof_dark'][(j*3+row)%5]
                tile=m.box(name+'_Slate',(x,yy,z),(course+.10,(depth+.8)/math.ceil((depth+.8)/1.5)-.018,.07),tone,.018)
                tile.rotation_euler.y=side*slope
        for yy in [-depth/2-.47,depth/2+.47]:
            if (omit_inner=='front' and yy<0) or (omit_inner=='rear' and yy>0):continue
            m.beam(name+'_Gable_Fascia',(side*(half+.18),yy,eave+.06),(0,yy,eave+rise+.14),.105,'trim')
        m.box(name+'_Eave_Fascia',(side*(half+.12),0,eave+.02),(.18,depth+1.0,.25),'oak',.035)
        m.box(name+'_Gutter',(side*(half+.30),0,eave+.09),(.15,depth+.90,.13),'roof_dark',.04)
    m.beam(name+'_Ridge',(0,-depth/2-.50,eave+rise+.28),(0,depth/2+.50,eave+rise+.28),.14,'roof_light')
    m.PARENT=old


def house():
    m.group('10_House_Architecture')
    # Three different roof directions / heights form a cottage silhouette.
    blocks=[('West',-10.2,1.75,7.6,15.7,3.7),('Main',-2.0,1.1,8.8,17.6,4.4),('East',8.2,2.0,11.6,15.2,3.7)]
    for name,cx,cy,w,d,height in blocks:
        m.box(name+'_Foundation',(cx,cy,.16),(w+.25,d+.25,.32),'foundation',.06)
        m.collider(name+'_House',(cx,cy,2.8),(w,d,5.6))
        if name=='Main':front=[(-1.5,2.0,.15,2.85,'door'),(2.25,1.35,1.3,1.75,'flower')]
        elif name=='West':front=[(-1.7,1.65,1.3,1.7,'shutter'),(1.7,1.65,1.3,1.7,'flower')]
        else:front=[(-3.5,1.7,1.3,1.7,'shutter'),(0,1.85,1.3,1.7,'flower'),(3.5,1.7,1.3,1.7,'shutter')]
        facade(name+'_Front',w,height,front,(cx,cy-d/2,0))
        facade(name+'_Rear',w,height,[(-w*.25,1.6,1.4,1.6,'plain'),(w*.25,1.6,1.4,1.6,'plain')],(cx,cy+d/2,0),math.pi)
        for side in [-1,1]:
            facade(name+'_Side',d,height,[(-d*.25,1.7,1.3,1.7,'plain'),(d*.25,1.7,1.3,1.7,'plain')],(cx+side*w/2,cy,0),side*math.pi/2)
        for x in [cx-w/2,cx+w/2]:
            for y in [cy-d/2,cy+d/2]:m.box(name+'_Corner_Post',(x,y,height/2),(.22,.23,height),'oak',.035)
        if name=='Main':roof(name+'_Roof',cx,cy,w+.20,d,4.4,2.65)
        else:
            # Bury the inner gable beneath the taller main slope. The overlap
            # forms a real roof valley instead of an exposed triangular cap.
            roof(name+'_Roof',cx+(1.25 if name=='West' else -1.25),cy,d+.10,w+2.5,3.70,2.1,math.pi/2,'front' if name=='West' else 'rear')
    # Small attic window and timberwork on the main front gable.
    m.group('20_Exterior_Details')
    m.cyl('Attic_Window_Shadow',(-2,-7.725,5.45),.64,.08,'window_dark',32).rotation_euler.x=math.pi/2
    m.ring('Attic_Round_Frame',(-2,-7.82,5.45),.64,.10,'trim',(math.pi/2,0,0))
    m.box('Attic_Vertical',(-2,-7.84,5.45),(.09,.09,1.08),'trim',.02)
    m.box('Attic_Horizontal',(-2,-7.84,5.45),(1.08,.09,.09),'trim',.02)
    for a,b in [((-5.9,-7.78,4.55),(-2,-7.78,6.95)),((1.9,-7.78,4.55),(-2,-7.78,6.95))]:m.beam('Gable_Timber',a,b,.08,'oak')
    # A porch whose shelter stops behind the gameplay standing position.
    m.box('Porch_Stone_Apron',(-3.5,-8.15,.025),(5.2,1.55,.05),'stonewarm',.12)
    for x in [-5.72,-1.28]:
        m.box('Porch_Column_Foot',(x,-8.35,.20),(.42,.42,.4),'foundation',.06)
        m.box('Porch_Timber_Column',(x,-8.35,1.55),(.20,.20,2.7),'oak',.035)
        m.beam('Porch_Angle_Brace',(x,-8.35,2.25),(x+(.45 if x<-3.5 else -.45),-8.35,2.85),.075,'lightwood')
        m.collider('Porch_Post',(x,-8.35,1.4),(.35,.35,2.8))
    m.box('Porch_Header',(-3.5,-8.35,2.93),(4.7,.25,.25),'lightwood',.04)
    awning=m.box('Porch_Slate_Awning',(-3.5,-8.15,3.27),(5.25,1.65,.22),'roof',.06)
    awning.rotation_euler.x=.15
    m.box('Porch_Front_Fascia',(-3.5,-8.96,3.13),(5.25,.15,.22),'trim',.035)
    m.box('Welcome_Plaque',(-3.5,-8.50,2.93),(2.3,.09,.35),'doorwood',.05)
    m.text('Welcome_Type','HOME',(-3.5,-8.57,2.93),.24,'ivory')
    m.lantern('Front_Door_Lantern',-5.04,-7.98,2.25,'yellow',.24)
    m.basket('Porch_Ready_Basket',-6.1,-8.2,0,False)
    m.plant('Porch_Geranium',-.60,-8.0,0,True,.85)
    m.box('Doormat',(-3.5,-8.22,.06),(1.8,.68,.08),'teal',.09)
    # Brick chimney with visible cap/opening, rather than a plain cuboid.
    m.box('Chimney_Body',(10.2,4.4,5.55),(1.05,1.10,2.20),'clay',.06)
    for k in range(6):
        z=4.6+k*.32
        m.box('Chimney_Mortar',(10.2,3.835,z),(1.05,.025,.035),'cream',.003)
        m.box('Chimney_Brick_Joint',(10.2+(.22 if k%2 else -.22),3.83,z+.16),(.025,.03,.30),'cream',.003)
    m.box('Chimney_Cap',(10.2,4.4,6.69),(1.35,1.38,.22),'stonewarm',.06)
    m.box('Chimney_Flue',(10.2,4.4,6.82),(.78,.80,.08),'window_dark',.04)
    for x,y in [(-13.9,-5.8),(13.9,-5.4)]:
        m.beam('Rain_Downpipe',(x,y,.4),(x,y,3.7),.06,'roof_dark')


def anchors_and_task():
    points=[(-10,-10.2),(8,-10.2),(-6.3,-9.2),(2,-10.2),(11.5,-10.3)]
    for i,(xy,data) in enumerate(zip(points,h.ROOMS['home_estate']['anchors']),1):
        ob=m.anchor(f'SG_MEMORY_{i:02}',xy,data['label']);ob['memory_id']=data['id'];ob['activity']=data['activity']
    m.anchor('SG_SPAWN',(0,-13.4),'进入家园');m.anchor('SG_EXIT',(0,-14.5),'返回字母岛')
    m.anchor('SG_NPC_HOST',(-2,-10),'家人停留位置')
    m.anchor('SG_HOUSE_ENTRY',(-3.5,-8.7),'正门 · 走进家里')
    # Historic marker names remain import-compatible; runtime binds only house_entry.
    for rid in h.DOORS:m.anchor('SG_DOOR_'+rid.upper(),(-3.5,-8.7),'入户导览中的房间')
    for state in ['before','middle','after']:
        root=h.task_root(state);x=7.8 if state=='middle' else 6.5
        m.cyl('Watering_Can',(x,-11.8,1.05),.25,.40,'teal')
        m.ring('Watering_Can_Handle',(x-.22,-11.8,1.12),.23,.045,'teal',(math.pi/2,0,0))
        m.beam('Watering_Can_Spout',(x+.18,-11.8,1.05),(x+.50,-11.8,1.25),.06,'teal')
        if state=='middle':m.beam('Watering_Stream',(8.3,-11.8,1.25),(8.4,-11.6,.6),.035,'water')
        if state=='after':
            for xx in [7.3,8,8.7]:m.ball('Damp_Soil',(xx,-11.6,.62),(.25,.23,.02),'soil')
        h.end_task(root,state!='before')


def main():
    m.setup('home_estate');palette();m.group('00_Ground')
    m.floor(34,32,'grass',False)
    house();build_courtyard(m);anchors_and_task()
    p.preview_setup(1500)
    camera=bpy.context.scene.camera;camera.location=(24,-34,27);camera.data.ortho_scale=44
    p.point_camera(camera,(0,-1.0,1.2))
    bpy.context.scene.name='home_estate_v02'
    bpy.context.scene['design']='Complete cottage exterior and courtyard; front door opens seven-room guide'
    bpy.context.scene['original_geometry']='Procedurally authored in Blender; no third-party models or textures'
    # Include the entrance in editable metadata as well as exported nodes.
    old=list(p.REQUIRED);p.REQUIRED.append('SG_HOUSE_ENTRY')
    folder=Path('assets/blender/interiors/home_estate')
    p.finish_room('home_estate',h.ROOMS['home_estate']['name'],existing={
        'blend':(folder/'home_estate_v02.blend').as_posix(),
        'glb':(folder/'home_estate_v02.glb').as_posix(),
        'preview':(folder/'preview_v02.png').as_posix()},render=True)
    p.REQUIRED[:]=old


if __name__=='__main__':main()
