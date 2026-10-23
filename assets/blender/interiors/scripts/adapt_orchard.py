"""Copy the mature A orchard into the interior pipeline, preserving its real layout.

Only reads the source .blend. Keeps apple house, creek, bridge, trees and original
A_LOCUS nodes; SG aliases are small, documented offsets onto walkable ground.
"""
import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector
import modeling as m
import pipeline

SOURCE=pipeline.ROOT/'assets/blender/A_orchard/A_orchard_with_apple_house_v02.blend'

def build(resolution=1100):
    m.setup('landmark_A')
    empty_scene=bpy.context.scene
    with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):
        dst.scenes=['A_Orchard_With_Apple_House_v02']
    sc=dst.scenes[0];bpy.context.window.scene=sc;bpy.data.scenes.remove(empty_scene)
    sc.name='landmark_A_v01';sc['room_id']='landmark_A';sc['source_asset']=SOURCE.relative_to(pipeline.ROOT).as_posix()
    sc['source_sha256']=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    sc['normalization_offset_blender']=[0,0,-.65];sc['walkable_floor_z']=0.0
    sc['preserved_layout']='A orchard v02: irregular island, loop paths, creek, bridge, Tripo apple house and five original A_LOCUS nodes'
    # A single vertical translation preserves every original X/Y relation.
    for ob in sc.objects:
        if ob.parent is None:ob.location.z-=.65
        if ob.type in ('CAMERA','LIGHT') or ob.name=='A_Sea_Plane' or ob.hide_render:
            ob['preview_only']=True;ob.name='PREVIEW_'+ob.name
    ground=bpy.data.objects['A_Grass_Surface'];ground['source_object_name']=ground.name;ground.name='SG_FLOOR_Main'
    for ob in sc.objects:
        if ob.name.startswith('A_Path_') and not ob.name.startswith('A_Path_Edge_'):
            ob['source_object_name']=ob.name;ob.name='SG_FLOOR_'+ob.name
        elif ob.name.startswith('A_Bridge_Deck_'):
            ob['source_object_name']=ob.name;ob.name='SG_FLOOR_'+ob.name
    bpy.context.view_layer.update()
    # Editable simple proxies: no high-resolution tree/house mesh collision.
    m.collider('Apple_House',(0,3.35,2.5),(5.8,5.7,5))
    m.collider('Entrance_Basket',(-2.5,-.8,.5),(.85,.85,1))
    m.collider('Sorting_Table',(-2.8,-4.7,.7),(2.2,1.0,1.4))
    m.collider('Wash_Basin',(4.15,-1.3,.8),(1.68,1.16,1.6))
    m.collider('Gift_Shelf',(3.6,-6.2,.72),(1.7,.7,1.44))
    m.collider('Bench',(-3.3,-.3,.6),(1.8,.8,1.2))
    for ob in list(sc.objects):
        if ob.name.startswith('A_Tree_') and ob.name.endswith('_Trunk'):
            b=pipeline.world_bounds(ob)
            m.collider(ob.name,((b[0]+b[3])/2,(b[1]+b[4])/2,1.3),(.7,.7,2.6))
        if ob.name.startswith('A_Fence_') and '_Rail' in ob.name:
            b=pipeline.world_bounds(ob);w=b[3]-b[0];d=b[4]-b[1]
            # Use only the low rail once, preserving the real fence gap positions.
            if b[2]<.6:m.collider(ob.name,((b[0]+b[3])/2,(b[1]+b[4])/2,.7),(max(w,.15),max(d,.15),1.4))
    # Block the creek except the bridge corridor; the matching bridge is a floor.
    water=bpy.data.objects['A_Creek_Surface']
    for i,p in enumerate(water.data.polygons):
        pts=[water.matrix_world@water.data.vertices[v].co for v in p.vertices]
        x0,x1=min(p.x for p in pts),max(p.x for p in pts);y0,y1=min(p.y for p in pts),max(p.y for p in pts)
        if y0<-2.75 and y1>-4.85:
            if y1>-2.75:y0=-2.75
            elif y0<-4.85:y1=-4.85
            else:continue
        if y1>y0:m.collider(f'Creek_{i:02}',((x0+x1)/2,(y0+y1)/2,.8),(x1-x0,y1-y0,1.6))
    for y in [-4.80,-2.80]:m.collider('Bridge_Rail',(7.62,y,.7),(3.6,.14,1.4))
    # Smooth entry/exit ramps remove the old 0.25 m boardwalk step for the player.
    m.group('01_Bridge_Access_Ramps')
    for name,x0,x1,z0,z1 in [('West',4.8,5.95,.025,.25),('East',9.35,10.0,.25,.025)]:
        m.mesh('SG_FLOOR_Bridge_Ramp_'+name,[(x0,-4.65,z0),(x1,-4.65,z1),(x1,-2.95,z1),(x0,-2.95,z0)],[(0,1,2,3)],'lightwood')
    # Follow the original irregular floor perimeter, not an invented rectangle.
    top=max(ground.data.polygons,key=lambda p:(p.normal.z,len(p.vertices)))
    outline=[ground.matrix_world@ground.data.vertices[v].co for v in top.vertices]
    for i,a in enumerate(outline):
        b=outline[(i+1)%len(outline)];x=(a.x+b.x)/2;y=(a.y+b.y)/2
        if y<-8 and abs(x)<1.25:continue
        delta=b-a;ob=m.collider(f'Orchard_Perimeter_{i:02}',(x,y,.9),(delta.xy.length+.06,.14,1.8));ob.rotation_euler.z=math.atan2(delta.y,delta.x)
    names=['A_LOCUS_01_Entrance_Basket','A_LOCUS_02_Left_Apple_Tree','A_LOCUS_03_Sorting_Table','A_LOCUS_04_Wash_Basin','A_LOCUS_05_Gift_Shelf']
    places=[(-2.5,-1.6),(-6.95,.5),(-2.8,-5.65),(4.15,-2.35),(3.6,-7.05)]
    labels=['门前篮子','左侧果树','中央分拣台','右侧洗果池','出口礼物架']
    props=['A_Entrance_Basket','A_Tree_3_Trunk','A_SortTable_Top','A_Wash_Pedestal','A_GiftShelf_Board']
    aliases=[]
    for i,(old,xy,label,prop) in enumerate(zip(names,places,labels,props),1):
        legacy=bpy.data.objects[old];p=legacy.matrix_world.translation
        ob=m.anchor(f'SG_MEMORY_{i:02}',xy,label,prop)
        ob['legacy_anchor']=old;ob['memory_id']=f'memory_A_{i:02}';ob['source_layout_preserved']=True
        offset=[round(xy[0]-p.x,3),round(xy[1]-p.y,3),0]
        ob['walkable_offset_from_legacy']=offset
        aliases.append({'legacy_node':old,'legacy_xy':[round(p.x,3),round(p.y,3)],'alias':ob.name,'approach_xy':list(xy),'offset':offset,'reason':'Stand beside the permanent prop rather than inside its collision proxy'})
    m.anchor('SG_SPAWN',(-.3,-8.65),'果园主路进入点')
    m.anchor('SG_EXIT',(-.15,-9.7),'沿原主路返回字母岛')
    m.anchor('SG_NPC_HOST',(-.8,-2.4),'果园主人')
    sc.render.resolution_x=resolution;sc.render.resolution_y=round(resolution*.88);sc.render.resolution_percentage=100
    sc.render.image_settings.file_format='PNG';sc.render.image_settings.color_mode='RGB'
    try:sc.render.engine='BLENDER_EEVEE'
    except TypeError:sc.render.engine='BLENDER_EEVEE_NEXT'
    # Keep the source camera composition and packed house texture.
    bpy.ops.file.pack_all()
    pipeline.write_json(pipeline.OUT/'landmark_A'/'source_adaptation.json',{
        'source':SOURCE.relative_to(pipeline.ROOT).as_posix(),'source_sha256':sc['source_sha256'],
        'normalization_offset_blender':[0,0,-.65],'xy_layout_preserved':True,'legacy_aliases':aliases,
        'kept':['real Tripo apple house','original irregular island','orchard loop and five mature trees','creek and original bridge','all five original A_LOCUS nodes'],
        'added':['SG gameplay aliases','simple collision proxies','two bridge approach ramps'],
        'source_file_written':False})
    return sc

if __name__=='__main__':
    build();pipeline.finish_room('landmark_A','苹果果园屋')
