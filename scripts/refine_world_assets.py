"""Source-preserving Blender refinement of the 42 remaining playable scenes.

blender --background --python scripts/refine_world_assets.py -- --rooms landmark_C,home_study
Original textures, interaction transforms, physical meshes and task-state geometry stay intact.
Outputs are versioned and individually audited; integration is a separate operation.
"""
import bpy, bmesh, numpy as np
import hashlib, json, math, re, sys, random, argparse, importlib.util
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
sys.path.insert(0,str(ROOT/'assets/blender/interiors/scripts'))
import modeling as m
import pipeline as p
import refine_home_living as living
import refine_home_courtyard as garden
PLAN=ROOT/'docs/planning/world-refinement'
BASE=json.loads((PLAN/'baseline.json').read_text(encoding='utf-8'))
ENTRIES={r['room_id']:r for r in BASE['rooms']}
MAT_CACHE={}
CHANGES={}
TEX=None
REBUILD=False
ROOM_ID=''
OUTDOOR={'village','school','playground','football_field','landmark_A','landmark_B','landmark_F','home_estate','home_balcony'}

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def protected():
    roots=[o for o in bpy.context.scene.objects if o.name.startswith(('SG_','COL_','HOME_TASK_')) or o.get('sg_collision','none')!='none']
    result={}
    for root in roots:
        for ob in [root,*root.children_recursive]:
            data={'parent':ob.parent.name if ob.parent else None,'matrix':[list(row) for row in ob.matrix_world],
                  'props':{k:str(v) for k,v in ob.items()}}
            if ob.type=='MESH':
                data['vertices']=[list(v.co) for v in ob.data.vertices]
                data['faces']=[list(f.vertices) for f in ob.data.polygons]
            result[ob.name]=sha_bytes(json.dumps(data,sort_keys=True).encode())
    return result

def sha_bytes(raw): return hashlib.sha256(raw).hexdigest()

def family(ob,mat):
    n=ob.name.lower(); key=mat.name.lower()
    if ob.name=='SG_FLOOR_Main' and ROOM_ID=='home_balcony': return 'paving'
    if ob.name=='SG_FLOOR_Main' and (any(t in key for t in ['wood','oak']) or (ROOM_ID not in OUTDOOR and 'sand' in key)): return 'floor'
    if n in ['boat_sail','kite_fabric'] or (n.startswith('wall_kite') and not any(t in n for t in ['spar','tail'])): return 'cloth'
    if n.startswith('xylophone_key'): return 'wood'
    if any(t in n for t in ['pillow','quilt','towel','cushion','curtainfold','curtain_fold','rug','apron_cloth','fabric_roll','sail_cloth','mattress','acousticpanel']): return 'cloth'
    if any(t in n for t in ['sofa_arm','sofa_back','sofa_seat','armchair_arm','armchair_back']): return 'cloth'
    if 'bark' in key or 'trunk' in n or '_branch' in n: return 'bark'
    if 'wood' in key or 'oak' in key: return 'wood'
    if any(t in key for t in ['grass','soil','sand','earth','dirt']): return 'earth'
    if any(t in key for t in ['rock','stone','paver','paving','path','brick']): return 'stone'
    if ('wall' in n or 'ceiling' in n or 'foundation' in n) and not any(t in n for t in ['clock','note','painting','sticker']): return 'plaster'
    if 'paper' in key or 'canvas' in n: return 'paper'
    if any(t in key for t in ['leaf','leaves','foliage']): return 'leaf'
    if 'clay' in key or (any(t in n for t in ['_pot','_cup','_bowl','_plate']) and not any(t in n for t in ['label','body_','stem','holder','handle','knob'])): return 'ceramic'
    if any(t in key for t in ['metal','gold','brass']): return 'metal'
    return None

def make_image(name,values,normal=False):
    size=values.shape[0]
    image=bpy.data.images.new(name,width=size,height=size,alpha=False)
    image.colorspace_settings.name='Non-Color' if normal else 'sRGB'
    rgba=np.ones((size,size,4),np.float32);rgba[:,:,:3]=np.clip(values,0,1)
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw=str(TEX/(name+'.png'));image.file_format='PNG';image.save();image.pack()
    return image

def surface(original,kind):
    key=(original.name,kind)
    if key in MAT_CACHE: return MAT_CACHE[key]
    bs=next((n for n in original.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None) if original.use_nodes else None
    color=np.array(bs.inputs['Base Color'].default_value[:3] if bs else original.diffuse_color[:3])
    # Retain the existing palette, reducing only the strongest synthetic greens.
    if kind=='leaf': color=color*.91+np.array([.29,.38,.17])*.09
    if kind=='earth' and 'grass' in original.name.lower(): color=color*.92+np.array([.38,.43,.23])*.08
    mat=original.copy();mat.name='WR_'+kind+'_'+original.name
    mat.use_nodes=True
    out=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    out.inputs['Roughness'].default_value={'floor':.77,'paving':.86,'wood':.72,'bark':.93,'cloth':.94,'earth':.97,'stone':.91,'plaster':.94,'paper':.94,'leaf':.85,'ceramic':.30,'metal':.40}[kind]
    if kind=='metal': out.inputs['Metallic'].default_value=.48
    if kind=='cloth' and 'Sheen Weight' in out.inputs: out.inputs['Sheen Weight'].default_value=.14
    if kind not in ['metal','ceramic','leaf']:
        size=256;u,v=np.meshgrid(np.arange(size)/size,np.arange(size)/size)
        rng=np.random.default_rng(261024)
        noise=rng.normal(0,1,(size,size))
        if kind=='floor':
            row=np.floor(v*5)
            grain=(.5+.5*np.sin(math.tau*(v*70+.25*np.sin(u*math.tau*2))))**8
            seam_y=np.minimum(np.mod(v*5,1),1-np.mod(v*5,1))<.008
            seam_x=np.minimum(np.mod(u*2+row*.5,1),1-np.mod(u*2+row*.5,1))<.004
            tone=np.array([.012,-.017,.018,-.010,.025])[row.astype(int)]
            variation=tone-grain*.035-(seam_y|seam_x)*.12
            height=variation*.2
        elif kind=='paving':
            seam=(np.minimum(np.mod(u*4,1),1-np.mod(u*4,1))<.01)|(np.minimum(np.mod(v*4,1),1-np.mod(v*4,1))<.01)
            variation=noise*.006-seam*.09
            height=variation*.12
        elif kind in ['wood','bark']:
            wave=v+.022*np.sin(u*math.tau*2)+.012*np.sin(u*math.tau*5)
            grain=(.5+.5*np.sin(wave*math.tau*31))**9
            broad=np.sin(wave*math.tau*5)
            variation=broad*(.01 if kind=='wood' else .036)-grain*(.035 if kind=='wood' else .065)+noise*.004
            height=broad*(.003 if kind=='wood' else .02)-grain*(.012 if kind=='wood' else .04)
        elif kind=='cloth':
            weave=np.sin(u*math.tau*64)*np.sin(v*math.tau*64)
            variation=weave*.027+noise*.004
            height=weave*.027
        else:
            strength={'earth':.05,'stone':.035,'plaster':.014,'paper':.008}[kind]
            broad=np.sin(u*math.tau*3+np.sin(v*math.tau*2))*.5+np.sin(v*math.tau*7)*.25
            variation=broad*strength+noise*strength*.25
            height=variation*.3
        linear=np.clip(color[None,None,:]*(1+variation[:,:,None]),0,1)
        srgb=np.where(linear<=.0031308,linear*12.92,1.055*linear**(1/2.4)-.055)
        token=kind+'_'+sha_bytes((original.name+str(color)).encode())[:12]
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=make_image(token+'_color',srgb)
        mat.node_tree.links.new(tex.outputs['Color'],out.inputs['Base Color'])
        dy,dx=np.gradient(height);normal=np.dstack((-dx*10,-dy*10,np.ones_like(dx)))
        normal/=np.linalg.norm(normal,axis=2,keepdims=True)
        tn=mat.node_tree.nodes.new('ShaderNodeTexImage');tn.image=make_image(token+'_normal',normal*.5+.5,True)
        nm=mat.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.07 if kind=='wood' else .16 if kind=='cloth' else .10
        mat.node_tree.links.new(tn.outputs['Color'],nm.inputs['Color']);mat.node_tree.links.new(nm.outputs['Normal'],out.inputs['Normal'])
    mat['authorship']='Original deterministic 256px surface pigment and normal; 2026-10-24 world refinement'
    MAT_CACHE[key]=mat
    return mat

def materials(objects):
    for ob in objects:
        if ob.type!='MESH' or ob.name.startswith(('SG_COLLIDER_','SG_DECOR_','COL_','PREVIEW_')): continue
        changes=[]
        for index,slot in enumerate(ob.material_slots):
            mat=slot.material
            if not mat: continue
            if mat.use_nodes and any(n.type=='TEX_IMAGE' and n.image for n in mat.node_tree.nodes): continue
            if mat.diffuse_color[3]<.99 or 'collision' in mat.name.lower(): continue
            kind=family(ob,mat)
            if kind: changes.append((index,surface(mat,kind),kind))
        if changes:
            if ob.data.users>1: ob.data=ob.data.copy()
            for index,mat,kind in changes:
                ob.data.materials[index]=mat
                CHANGES['surface_families'][kind]=CHANGES['surface_families'].get(kind,0)+1
            # All replaced source slots had no textures; retain existing UVs on mixed authored assets.
            if len(changes)==len(ob.material_slots): living.uv_project(ob,.15 if changes[0][2] in ['floor','paving'] else .65)
            CHANGES['textured_objects']+=1

def local_bounds(ob):
    return [min(v.co[a] for v in ob.data.vertices) for a in range(3)]+[max(v.co[a] for v in ob.data.vertices) for a in range(3)]

def local_trim(ob,kind,b):
    x,y,z=(b[0]+b[3])/2,(b[1]+b[4])/2,b[5]
    w,d,h=b[3]-b[0],b[4]-b[1],b[5]-b[2]
    if min(w,d)<.28 or max(w,d)>9 or h>1.2: return
    inset=min(.07,min(w,d)*.06)
    path=living.rounded_rectangle(x,y,z-.018,w-inset*2,d-inset*2,min(.10,min(w,d)*.13))
    obnew=living.curve('WR_'+('Piped_' if kind=='cloth' else 'Inlay_')+ob.name,[path],.009 if kind=='cloth' else .007,'seam' if kind=='cloth' else 'inlay',True)
    obnew.matrix_world=ob.matrix_world.copy()
    obnew['sg_collision']='none'
    CHANGES['tailored_details'].append(obnew.name)

def joinery(objects,guard):
    count=0
    for ob in objects:
        if ob.type!='MESH' or ob.name in guard or ob.name.startswith(('PREVIEW_','SG_','COL_')): continue
        n=ob.name.lower()
        if len(ob.data.vertices)!=8: continue
        slots=[s.material for s in ob.material_slots if s.material]
        if not slots: continue
        kind='cloth' if any(s.name.startswith('WR_cloth_') for s in slots) else 'wood' if any(s.name.startswith('WR_wood_') for s in slots) else ''
        if kind=='cloth' and not any(t in n for t in ['rug_border','curtain','canvas']):
            for mod in ob.modifiers:
                if mod.type=='BEVEL': mod.segments=5;mod.width=min(.12,min(ob.dimensions)*.25)
            local_trim(ob,kind,local_bounds(ob))
        elif kind=='wood' and (n.endswith('_top') or '_top.' in n or n.endswith('_seat')) and count<18:
            local_trim(ob,kind,local_bounds(ob));count+=1
        if kind and any(t in n for t in ['table','cabinet','shelf','chair','bed_']):
            for mod in ob.modifiers:
                if mod.type=='BEVEL' and mod.segments<4: mod.segments=4;CHANGES['softened_edges']+=1

def attached_box(name,ob,pos,size,key,bevel=.015):
    child=living.box('WR_'+name+'_'+ob.name,pos,size,key,bevel)
    child.matrix_world=ob.matrix_world @ child.matrix_world
    child['sg_collision']='none'
    CHANGES['tailored_details'].append(child.name)
    return child

def architecture_and_furniture(objects,guard):
    for ob in objects:
        if ob.type!='MESH' or ob.name in guard or ob.name.startswith(('PREVIEW_','SG_')): continue
        n=ob.name.lower()
        if len(ob.data.vertices)!=8: continue
        b=local_bounds(ob);w,d,h=b[3]-b[0],b[4]-b[1],b[5]-b[2]
        x,y,z=(b[0]+b[3])/2,(b[1]+b[4])/2,(b[2]+b[5])/2
        if ob.name=='Rear_Wall' and w>8 and d<.6:
            top=min(1.15,b[5]-.3);bottom=max(b[2]+.2,.24)
            if top<=bottom: continue
            attached_box('Dado',ob,(x,b[1]-.03,top),(w-.18,.065,.065),'wall_trim')
            for xx in np.arange(b[0]+.22,b[3]-.20,.88):
                attached_box('Wall_Batten',ob,(xx,b[1]-.018,(top+bottom)/2),(.038,.032,top-bottom),'wall_trim',.007)
        if (n.endswith('_cabinet') or n.endswith('_cabinet_cabinet')) and .75<w<6 and .6<h<1.8 and d>.4:
            doors=2 if w>1.5 else 1
            for i in range(doors):
                cx=b[0]+w*(i+.5)/doors
                path=living.rounded_rectangle(cx,b[1]-.014,z,w/doors-.12,h-.18,.045,plane='xz')
                seam=living.curve('WR_Cabinet_Frame_'+ob.name,[path],.008,'wall_trim',True)
                seam.matrix_world=ob.matrix_world.copy();seam['sg_collision']='none';CHANGES['tailored_details'].append(seam.name)
                attached_box('Cabinet_Pull',ob,(cx+(w/doors*.27 if i==0 else -w/doors*.27),b[1]-.038,z+.12),(.045,.045,.19),'hardware',.018)
        if ('_table_top' in n or 'desk_top' in n or 'dining_top' in n) and 1<w<7 and .6<d<3 and h<.25:
            for yy in [b[1]+.12,b[4]-.12]:
                attached_box('Table_Apron',ob,(x,yy,b[2]-.09),(w-.22,.07,.15),'apron_wood',.02)

def pottery_rims(objects,guard):
    for ob in objects:
        n=ob.name.lower()
        if ob.type!='MESH' or ob.name in guard or not (n.endswith('_pot') or re.search(r'_pot\.\d+$',n)): continue
        if any(t in n for t in ['soup','serving','stove']): continue
        b=local_bounds(ob);rx=(b[3]-b[0])/2;ry=(b[4]-b[1])/2
        if not .12<rx<.65 or abs(rx-ry)>.03: continue
        path=[((b[0]+b[3])/2+math.cos(i/48*math.tau)*rx*.97,(b[1]+b[4])/2+math.sin(i/48*math.tau)*ry*.97,b[5]-.025) for i in range(48)]
        rim=living.curve('WR_Pottery_Lip_'+ob.name,[path],.018,'pottery_edge',True)
        rim.matrix_world=ob.matrix_world.copy();rim['sg_collision']='none';CHANGES['tailored_details'].append(rim.name)

def attached_curve(ob,name,paths,radius,key,cyclic=False):
    child=living.curve('WR_'+name+'_'+ob.name,paths,radius,key,cyclic)
    child.matrix_world=ob.matrix_world.copy();child['sg_collision']='none'
    CHANGES['tailored_details'].append(child.name)
    return child

def theme_details(objects,guard):
    # Details derive from inspected current meshes, never from recipe coordinates.
    for ob in objects:
        if ob.type!='MESH' or ob.name in guard or ob.name.startswith(('PREVIEW_','SG_')): continue
        n=ob.name.lower();b=local_bounds(ob)
        cx,cy,cz=[(b[i]+b[i+3])/2 for i in range(3)]
        w,d,h=[b[i+3]-b[i] for i in range(3)]
        if ROOM_ID in ['landmark_B','landmark_K'] and (n=='boat_sail' or n.startswith('wall_kite') and not any(t in n for t in ['spar','tail'])):
            bm=bmesh.new();bm.from_mesh(ob.data)
            edges=[[tuple(v.co) for v in edge.verts] for edge in bm.edges if edge.is_boundary]
            bm.free()
            if edges: attached_curve(ob,'Sewn_Edge',edges,.012,'seam')
        if ROOM_ID=='landmark_B' and n=='boat_wooden_hull':
            upper=sorted([v.co.copy() for v in ob.data.vertices if v.co.z>b[5]-.05],key=lambda v:math.atan2(v.y-cy,v.x-cx))
            if len(upper)>=4: attached_curve(ob,'Rounded_Gunwale',[upper],.045,'wall_trim',True)
        if ROOM_ID=='landmark_B' and n=='locus_03_mooring_bollard':
            path=[]
            for i in range(181):
                t=i/180;angle=t*math.tau*3;radius=max(w,d)*.56
                path.append((cx+math.cos(angle)*radius,cy+math.sin(angle)*radius,b[2]+h*(.48+t*.26)))
            attached_curve(ob,'Coiled_Mooring_Rope',[path],.033,'seam')
        if ROOM_ID=='landmark_P' and n.startswith('pumpkin_patch'):
            vines=[]
            leafbatch=garden.Batch('WR_Pumpkin_Vine_Leaves_'+ob.name,'leaf_mid',False)
            for j in [-1,0,1]:
                path=[(cx+w*.4*(2*t/30-1),cy+j*d*.24+math.sin(t*.27+j)*.10,b[5]+.035) for t in range(31)]
                vines.append(path)
                for t in [5,12,20,27]:
                    pos=Vector(path[t])+Vector((0,.13 if t%2 else -.13,.03))
                    garden.leaf(leafbatch,pos,.34,.23,.5*t,.1,.008)
            attached_curve(ob,'Pumpkin_Vines',vines,.014,'leaf_deep')
            new=leafbatch.finish()
            if new:
                new.matrix_world=ob.matrix_world.copy();new['sg_collision']='none';living.NEW.append(new);CHANGES['tailored_details'].append(new.name)
        if ROOM_ID=='landmark_T' and n=='carriage_body':
            for z in [b[2]+h*.19,b[2]+h*.27]:
                attached_box('Carriage_Pinstripe',ob,(cx,b[1]-.018,z),(w-.16,.025,.025),'hardware',.009)
            for x in np.linspace(b[0]+.18,b[3]-.18,13):
                attached_box('Carriage_Rivet',ob,(x,b[1]-.027,b[2]+.13),(.035,.035,.035),'hardware',.015)
        if ROOM_ID=='landmark_T' and n.startswith('train_wheel'):
            radius=min(w,d)*.33
            paths=[]
            for j in range(6):
                a=j*math.tau/6
                paths.append([(cx,cy,b[5]+.012),(cx+math.cos(a)*radius,cy+math.sin(a)*radius,b[5]+.012)])
            attached_curve(ob,'Wheel_Spokes',paths,.018,'hardware')
        if ROOM_ID=='landmark_S' and n.endswith('telescope_tube'):
            radius=min(w,d)*.50
            rings=[]
            for z in [b[2]+h*.12,b[2]+h*.88]:
                rings.append([(cx+math.cos(i*math.tau/48)*radius,cy+math.sin(i*math.tau/48)*radius,z) for i in range(48)])
            attached_curve(ob,'Telescope_Bands',rings,.023,'hardware',True)
        if ROOM_ID=='landmark_V' and n.endswith('_mountain'):
            levels=sorted({round(v.co.z,5) for v in ob.data.vertices})
            if len(levels)<2: continue
            low=[v.co for v in ob.data.vertices if abs(v.co.z-levels[0])<.001]
            high=[v.co for v in ob.data.vertices if abs(v.co.z-levels[-1])<.001]
            rb=max(math.hypot(v.x-cx,v.y-cy) for v in low);rt=max(math.hypot(v.x-cx,v.y-cy) for v in high)
            paths=[]
            for t in [.24,.46,.69]:
                radius=rb+(rt-rb)*t+.018
                paths.append([(cx+math.cos(i*math.tau/64)*radius,cy+math.sin(i*math.tau/64)*radius,b[2]+h*t+math.sin(i*math.tau*3/64)*h*.008) for i in range(64)])
            attached_curve(ob,'Geological_Strata',paths,.012,'stone_edge',True)
        if ROOM_ID=='landmark_X' and n.startswith('xylophone_key'):
            paths=[[(b[0]+.045,b[1]+.08,b[5]+.004),(b[0]+.045,b[4]-.08,b[5]+.004)],
                   [(b[3]-.045,b[1]+.08,b[5]+.004),(b[3]-.045,b[4]-.08,b[5]+.004)]]
            attached_curve(ob,'Key_Inlay',paths,.005,'inlay')
        if ROOM_ID=='playground' and n=='basketball_hoop':
            radius=min(w,d)*.43;paths=[]
            for j in range(12):
                a=j*math.tau/12
                paths.append([(cx+math.cos(a)*radius,cy+math.sin(a)*radius,b[2]),
                              (cx+math.cos(a+.15)*radius*.72,cy+math.sin(a+.15)*radius*.72,b[2]-.23),
                              (cx+math.cos(a+.28)*radius*.68,cy+math.sin(a+.28)*radius*.68,b[2]-.47)])
            attached_curve(ob,'Basket_Net',paths,.009,'seam')

def crowns(objects,guard):
    # Each replacement keeps its existing object name, transform, origin and wind grouping.
    for ob in objects:
        n=ob.name.lower()
        if ob.type!='MESH' or ob.name in guard: continue
        if not (('crown' in n or 'canopy' in n) and ('tree' in n or 'orchard' in n)): continue
        if any(s.material and s.material.use_nodes and any(t.type=='TEX_IMAGE' for t in s.material.node_tree.nodes) for s in ob.material_slots): continue
        b=local_bounds(ob);center=Vector([(b[i]+b[i+3])/2 for i in range(3)]);rad=Vector([(b[i+3]-b[i])/2 for i in range(3)])
        if min(rad)<.05: continue
        seed=int(sha_bytes(ob.name.encode())[:8],16);rng=random.Random(seed)
        batch=garden.Batch('WR_CrownBuild','leaf_mid',True)
        smooth_faces=set()
        # Seven unequal overlapping boughs produce an open contour within the old envelope.
        for k in range(7):
            angle=k*2.39996
            offset=Vector((math.cos(angle)*rad.x*.42,math.sin(angle)*rad.y*.42,rad.z*(.16 if k%2 else -.15)))
            if k==6: offset=Vector((0,0,rad.z*.36))
            radii=Vector((rad.x*.53,rad.y*.53,rad.z*.57))
            first=len(batch.faces)
            garden.rounded_cluster(batch,center+offset,radii,seed%1000+k)
            smooth_faces.update(range(first,len(batch.faces)))
            for _ in range(13):
                az=rng.uniform(0,math.tau);el=rng.uniform(-.65,.8);rr=math.sqrt(1-el*el)
                pos=center+offset+Vector((math.cos(az)*radii.x*rr,math.sin(az)*radii.y*rr,radii.z*el))
                length=min(rad)*rng.uniform(.16,.23)
                garden.leaf(batch,pos,length,length*.42,az,rng.uniform(-.9,.9),length*.025)
        mesh=bpy.data.meshes.new(ob.name+'_Boughs');mesh.from_pydata(batch.verts,[],batch.faces);mesh.update()
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
        for key in ['leaf_mid','leaf_light','leaf_deep']: mesh.materials.append(m.M[key])
        for face in mesh.polygons:
            face.use_smooth=face.index in smooth_faces
            face.material_index=1 if face.center.z>center.z+rad.z*.2 and face.index%4==0 else 2 if face.center.z<center.z-rad.z*.25 else 0
        ob.data=mesh
        living.NEW.append(ob)
        CHANGES['layered_crowns'].append(ob.name)

def setup_palette():
    for key,color,rough in [('seam',(.77,.69,.53),.95),('inlay',(.32,.22,.12),.82),
                             ('wall_trim',(.72,.67,.54),.86),('hardware',(.53,.39,.17),.36),
                             ('apron_wood',(.64,.43,.23),.76),('pottery_edge',(.69,.40,.25),.42),
                             ('stone_edge',(.34,.30,.23),.92),
                             ('leaf_mid',(.27,.42,.17),.9),('leaf_light',(.38,.51,.23),.9),('leaf_deep',(.20,.34,.12),.92)]:
        living.material(key,color,rough)

def run_room(room_id):
    global TEX,MAT_CACHE,CHANGES,ROOM_ID
    ROOM_ID=room_id
    if room_id in ['home','home_estate']: return
    entry=ENTRIES[room_id];source=ROOT/entry['blend']
    match=re.search(r'_v(\d+)',source.stem);ver=int(match.group(1))+1
    stem=re.sub(r'_v\d+',f'_v{ver:02}',source.stem)
    output=source.with_name(stem+'.blend');glb=output.with_suffix('.glb')
    report=source.parent/f'validation_v{ver:02}.json'
    if output.exists() or glb.exists():
        if not REBUILD or not report.exists(): raise RuntimeError('Versioned output exists: '+str(output))
        previous=json.loads(report.read_text(encoding='utf-8'))
        assert previous['source_blend']==entry['blend'] and previous['source_sha256']==sha(source)
        assert previous['blend_sha256']==sha(output) and previous['sha256']==sha(glb),'Draft changed outside this refiner'
    TEX=source.parent/f'textures_v{ver:02}';TEX.mkdir(exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.view_layer.update()
    bpy.context.preferences.filepaths.save_version=0
    guard=protected()
    objects=list(bpy.context.scene.objects)
    if room_id=='village':
        spec=importlib.util.spec_from_file_location('island_export',ROOT/'assets/blender/alphabet_island/export_game_map.py')
        island=importlib.util.module_from_spec(spec);spec.loader.exec_module(island)
        objects=[o for o in objects if island.eligible(o)]
    m.M={key:bpy.data.materials.get('MAT_'+key) for key in m.PALETTE}
    m.COLLS={c.name:c for c in bpy.context.scene.collection.children};m.PARENT=None;m.SPHERES={};m.group('48_World_Refinement')
    living.NEW=[];living.TEXTURES=[];MAT_CACHE={}
    CHANGES={'room_id':room_id,'textured_objects':0,'surface_families':{},'softened_edges':0,'tailored_details':[],'layered_crowns':[]}
    setup_palette();materials(objects);joinery(objects,guard);architecture_and_furniture(objects,guard);pottery_rims(objects,guard);theme_details(objects,guard);crowns(objects,guard)
    bpy.context.view_layer.update()
    assert guard==protected(),'Protected gameplay geometry changed: '+room_id
    living.clean_lathe_centers();audit=living.geometry_audit()
    assert not audit['negative_closed_volumes'] and not audit['degenerate_meshes'],audit
    scene=bpy.context.scene;scene['world_refinement_revision']='world-refinement-v1';scene['protected_source']=entry['blend']
    scene['authorship']='Original Blender refinement and deterministic PBR; no external downloads'
    if room_id=='village':
        scene['sg_game_export_version']=ver
        scene['sg_editing_note']='Edit the v07 refinement; v05 and v06 remain preserved source versions.'
    bpy.ops.wm.save_as_mainfile(filepath=str(output),compress=True)
    if room_id=='village':
        bpy.ops.object.select_all(action='DESELECT')
        curves=[o for o in living.NEW if o.type=='CURVE']
        if curves:
            for ob in curves: ob.select_set(True)
            bpy.context.view_layer.objects.active=curves[0];bpy.ops.object.convert(target='MESH')
        bpy.ops.object.select_all(action='DESELECT')
        for ob in bpy.context.scene.objects:
            if island.eligible(ob): ob.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_extras=True,export_cameras=False,export_lights=False,export_yup=True)
        source_data={'required_nodes':[n for n in guard if n.startswith('SG_')]}
    else:
        source_data=p.collect_source(room_id)
        living.GLB=glb;living.export_refined_glb()
    stats=p.confirm_export(glb,source_data)
    result={**CHANGES,**stats,'new_detail_geometry':audit,'protected_objects':len(guard),'protected_geometry_unchanged':True,
            'protected_signature':guard,'source_blend':entry['blend'],'source_sha256':sha(source),
            'blend':output.relative_to(ROOT).as_posix(),'blend_sha256':sha(output),'glb':glb.relative_to(ROOT).as_posix(),
            'textures':len(list(TEX.glob('*.png'))),'engine_acceptance':'pending','source_materials_preserved':True}
    p.write_json(report,result)
    if room_id!='village':
        newentry=p.manifest_entry(room_id,entry['name'],source_data,stats,{**entry,'blend':result['blend'],'glb':result['glb'],
            'preview':(source.parent/f'preview_v{ver:02}.png').relative_to(ROOT).as_posix(),
            'refinement_revision':'world-refinement-v1'})
        p.write_json(source.parent/(stem+'.manifest-entry.json'),newentry)
    print('WORLD_ROOM_REFINED '+json.dumps({k:result[k] for k in ['room_id','textured_objects','softened_edges','textures','protected_objects','triangles_instanced','glb_bytes']}),flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--rooms',required=True);parser.add_argument('--rebuild',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    REBUILD=args.rebuild
    for room in args.rooms.split(','): run_room(room)
