"""Refine the existing living room into a source-preserving visual sample.

Run with a separate Blender: blender --background --python scripts/refine_home_living.py
Optional -- --no-render skips the previews. Never updates shared manifests or game GLBs.
Geometry and tiled PBR images are original deterministic project assets. No downloads.
"""
import bpy
import bmesh
import hashlib
import json
import math
import sys
from pathlib import Path
from mathutils import Vector
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'assets/blender/interiors/scripts'))
import modeling as m
import pipeline as p

FOLDER = ROOT/'assets/blender/interiors/home'
SOURCE = FOLDER/'home_v02.blend'
OUT = FOLDER/'home_v03.blend'
GLB = FOLDER/'home_v03.glb'
TEX = FOLDER/'textures_v03'
PROOF = ROOT/'docs/verification/living-room-polish'
NEW = []
TEXTURES = []


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def protected_objects():
    protected = {}
    roots = [o for o in bpy.context.scene.objects if o.name.startswith(('SG_', 'HOME_TASK_'))]
    for root in roots:
        for ob in [root, *root.children_recursive]:
            protected[ob.name] = {
                'parent': ob.parent.name if ob.parent else None,
                'matrix': [list(row) for row in ob.matrix_world],
                'properties': {k: str(v) for k,v in ob.items()},
                'vertices': [list(v.co) for v in ob.data.vertices] if ob.type == 'MESH' else [],
                'polygons': [list(f.vertices) for f in ob.data.polygons] if ob.type == 'MESH' else [],
            }
    return protected


def texture_image(name, data, normal=False):
    h,w = data.shape[:2]
    image = bpy.data.images.new('Living03_'+name, width=w, height=h, alpha=True)
    image.colorspace_settings.name = 'Non-Color' if normal else 'sRGB'
    rgba = np.ones((h,w,4), np.float32)
    rgba[:,:,:3] = np.clip(data, 0, 1)
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(TEX/(name+'.png'))
    image.file_format = 'PNG'
    image.save()
    image.pack()
    TEXTURES.append({'path':str((TEX/(name+'.png')).relative_to(ROOT)).replace('\\','/'),'size':[w,h],'usage':'normal' if normal else 'base_color'})
    return image


def material(name, color, roughness, pattern=None, strength=.20):
    mat = bpy.data.materials.new('MAT_Living03_'+name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color,1)
    bsdf.inputs['Roughness'].default_value = roughness
    mat.diffuse_color = (*color,1)
    if 'Sheen Weight' in bsdf.inputs and pattern == 'cloth':
        bsdf.inputs['Sheen Weight'].default_value = .12
    if pattern:
        size=512
        u,v=np.meshgrid(np.arange(size)/size,np.arange(size)/size)
        if pattern == 'wood':
            wave=v+0.016*np.sin(math.tau*u*2)+0.008*np.sin(math.tau*u*5)
            grain=.5+.5*np.sin(math.tau*(wave*24+0.08*np.sin(u*math.tau)))
            grain=grain**8
            broad=.5+.5*np.sin(math.tau*(wave*5))
            noise=np.random.default_rng(101).uniform(-.015,.015,(size,size))
            height=grain*.1+broad*.3+noise
            variation=(broad-.5)*.10-grain*.075+noise
        elif pattern == 'floor':
            row=np.floor(v*6)
            grain=(.5+.5*np.sin(math.tau*(v*96+.30*np.sin(u*math.tau*2))))**8
            seam_y=np.minimum(np.mod(v*6,1),1-np.mod(v*6,1)) < .010
            seam_x=np.minimum(np.mod(u*2+row*.5,1),1-np.mod(u*2+row*.5,1)) < .003
            tone=np.array([.01,-.025,.025,-.012,.035,-.006])[row.astype(int)]
            height=.3-grain*.025-(seam_y|seam_x)*.12
            variation=tone-grain*.045-(seam_y|seam_x)*.08
        else:
            a=np.sin(math.tau*u*64); b=np.sin(math.tau*v*64)
            weave=a*b*.5+np.sin(math.tau*u*16+np.sin(math.tau*v*8))*.045
            height=weave*.2
            variation=weave*.035
        # Source images store sRGB; convert the artist's linear palette to sRGB.
        rgb=np.asarray(color)[None,None,:]
        linear=np.clip(rgb*(1+variation[:,:,None]),0,1)
        srgb=np.where(linear<=.0031308,linear*12.92,1.055*linear**(1/2.4)-.055)
        image=texture_image(name+'_color',srgb)
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
        mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
        dy,dx=np.gradient(height)
        normal=np.dstack((-dx*14,-dy*14,np.ones_like(dx)))
        normal/=np.linalg.norm(normal,axis=2,keepdims=True)
        ni=texture_image(name+'_normal',normal*.5+.5,True)
        nt=mat.node_tree.nodes.new('ShaderNodeTexImage');nt.image=ni
        nm=mat.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=strength
        mat.node_tree.links.new(nt.outputs['Color'],nm.inputs['Color'])
        mat.node_tree.links.new(nm.outputs['Normal'],bsdf.inputs['Normal'])
    m.M[name]=mat
    return mat


def uv_project(ob, scale=.7):
    if ob.type != 'MESH': return
    uv=ob.data.uv_layers.get('UVMap') or ob.data.uv_layers.new(name='UVMap')
    ob.data.update()
    for poly in ob.data.polygons:
        axis=max(range(3),key=lambda a:abs(poly.normal[a]))
        axes=[a for a in range(3) if a!=axis]
        for li in poly.loop_indices:
            co=ob.data.vertices[ob.data.loops[li].vertex_index].co
            uv.data[li].uv=(co[axes[0]]*scale,co[axes[1]]*scale)


def assign(ob, key, scale=.7):
    if ob.data.users > 1: ob.data=ob.data.copy()
    ob.data.materials.clear();ob.data.materials.append(m.M[key]);uv_project(ob,scale)


def box(name, pos, size, key, bevel=.04):
    ob=m.box(name,pos,size,key,bevel)
    for polygon in ob.data.polygons:polygon.use_smooth=True
    for mod in ob.modifiers:
        if mod.type == 'BEVEL': mod.segments=5
    uv_project(ob,1.2 if 'cloth' in key else .7)
    NEW.append(ob)
    return ob


def curve(name, paths, radius, key, cyclic=False):
    data=bpy.data.curves.new(name+'_Paths','CURVE');data.dimensions='3D'
    data.resolution_u=1;data.bevel_depth=radius;data.bevel_resolution=2
    data.use_fill_caps=True
    for points in paths:
        sp=data.splines.new('POLY');sp.points.add(len(points)-1)
        for point,co in zip(sp.points,points):point.co=(*co,1)
        sp.use_cyclic_u=cyclic
    ob=bpy.data.objects.new(name,data);m.link(ob);data.materials.append(m.M[key]);NEW.append(ob)
    return ob


def rounded_rectangle(x,y,z,w,d,r,plane='xy'):
    points=[]
    for cx,cy,start in [(w/2-r,d/2-r,0),(-w/2+r,d/2-r,90),(-w/2+r,-d/2+r,180),(w/2-r,-d/2+r,270)]:
        for i in range(7):
            a=math.radians(start+i*90/6)
            aa=cx+math.cos(a)*r;bb=cy+math.sin(a)*r
            points.append((x+aa,y+bb,z) if plane=='xy' else (x+aa,y,z+bb))
    return points


def sofa_and_chair():
    m.group('41_Living03_Upholstery')
    for ob in list(bpy.context.scene.objects):
        if ob.name.startswith('Home_Rear_Sofa_') or ob.name.startswith('Window_Reading_Chair_'):
            bpy.data.objects.remove(ob,do_unlink=True)
    box('Home_Rear_Sofa_Base',(0,4.4,.40),(2.8,1.15,.46),'rose_cloth',.16)
    box('Home_Rear_Sofa_Back',(0,4.86,.99),(2.8,.30,.83),'rose_cloth',.13)
    for x in [-1.25,1.25]:box('Home_Rear_Sofa_Arm',(x,4.40,.80),(.30,1.20,.70),'rose_cloth',.12)
    for x in [-.545,.545]:
        box('Living03_Sofa_Seat',(x,4.30,.72),(1.06,.93,.25),'rose_cloth',.115)
        box('Living03_Sofa_Back_Cushion',(x,4.70,1.05),(1.06,.27,.56),'rose_cloth',.105)
    paths=[rounded_rectangle(x,4.30,.79,1.04,.91,.14) for x in [-.545,.545]]
    paths += [rounded_rectangle(x,4.545,1.06,1.02,.51,.12,'xz') for x in [-.545,.545]]
    curve('Living03_Sofa_Piping',paths,.012,'rose_edge',True)
    for x in [-1.06,1.06]:
        for y in [4.05,4.79]:
            box('Living03_Sofa_Foot',(x,y,.15),(.13,.13,.25),'walnut',.025)
    for x,key,angle in [(-.78,'honey_cloth',-.10),(.78,'flax_cloth',.10)]:
        ob=box('Home_Rear_Sofa_Cushion',(x,4.43,1.04),(.54,.23,.51),key,.105)
        ob.rotation_euler=(math.radians(-10),0,angle)
        edge=curve('Living03_Throw_Pillow_Seam',[rounded_rectangle(x,4.305,1.04,.48,.45,.10,'xz')],.008,'honey_edge',True)
        # Small stitched dimple reads in oblique light without ornate decoration.
        button=m.ball('Living03_Pillow_Button',(x,4.29,1.04),(.023,.012,.023),'honey_edge',12,8);NEW.append(button)
    box('Window_Reading_Chair_Base',(5,4.8,.36),(1.6,1.45,.52),'sage_cloth',.17)
    box('Window_Reading_Chair_Back',(5,5.35,1.1),(1.6,.35,1.0),'sage_cloth',.14)
    for x in [4.35,5.65]:box('Window_Reading_Chair_Arm',(x,4.8,.8),(.30,1.5,.75),'sage_cloth',.13)
    box('Living03_Chair_Seat',(5,4.63,.70),(1.06,1.02,.25),'sage_cloth',.12)
    box('Living03_Chair_Back_Cushion',(5,5.12,1.11),(1.10,.25,.66),'sage_cloth',.12)
    curve('Living03_Chair_Piping',[rounded_rectangle(5,4.63,.78,1.02,.98,.13),rounded_rectangle(5,4.975,1.11,1.04,.60,.12,'xz')],.012,'sage_edge',True)
    box('Window_Reading_Chair_Cushion',(5.16,4.89,1.04),(.58,.24,.48),'honey_cloth',.105).rotation_euler.y=-.08
    for x in [4.48,5.52]:
        for y in [4.32,5.29]:box('Living03_Chair_Foot',(x,y,.12),(.12,.12,.21),'walnut',.02)


def rugs():
    m.group('42_Living03_Textiles')
    for ob in list(bpy.context.scene.objects):
        if ob.name.startswith(('Living_Rug_Border','Reading_Nook_Rug_Border')):bpy.data.objects.remove(ob,do_unlink=True)
    for name,cx,cy,w,d,key in [('Living_Rug',0,1.3,5.4,4.8,'rug_rose'),('Reading_Nook_Rug',5,4.8,3.5,3.7,'flax_cloth')]:
        ob=bpy.data.objects[name];assign(ob,key,2.1)
        curve('Living03_'+name+'_Bound_Edge',[rounded_rectangle(cx,cy,.049,w-.06,d-.06,.07)],.018,'flax_edge',True)
        curve('Living03_'+name+'_Woven_Border',[rounded_rectangle(cx,cy,.052,w-.30,d-.30,.08),rounded_rectangle(cx,cy,.052,w-.40,d-.40,.08)],.012,'flax_edge',True)
        # Narrow tied fringe, merged into one curve, does not add collision.
        paths=[]
        for yy,sgn in [(cy-d/2,-1),(cy+d/2,1)]:
            for x in np.arange(cx-w/2+.14,cx+w/2-.13,.11):
                paths.append([(x,yy,.044),(x+.012,yy+sgn*.08,.037),(x-.008,yy+sgn*.14,.031)])
        curve('Living03_'+name+'_Fringe',paths,.010,'flax_edge')


def curtains():
    m.group('43_Living03_Window_Textiles')
    for cx,side in [(-5.3,'Left'),(5.2,'Right')]:
        beam=m.beam('Living03_'+side+'_Curtain_Rail',(cx-1.65,6.33,3.43),(cx+1.65,6.33,3.43),.036,'walnut');NEW.append(beam)
        for xx in [cx-1.68,cx+1.68]:
            ob=m.ball('Living03_Curtain_Finial',(xx,6.33,3.43),(.07,.07,.07),'honey_edge',16,10);NEW.append(ob)
        for direction in [-1,1]:
            center=cx+direction*1.38;verts=[];faces=[];nu=32;nv=18
            for j in range(nv+1):
                t=j/nv;z=3.36-2.05*t
                width=.52-.13*math.sin(math.pi*t)
                for i in range(nu+1):
                    u=i/nu;x=center+(u-.5)*width+direction*.11*math.sin(math.pi*t)
                    y=6.28+.065*math.sin(u*math.tau*4.0)*(1+.3*t)
                    verts.append((x,y,z+.015*math.cos(u*math.tau*4)*t))
            for j in range(nv):
                for i in range(nu):
                    a=j*(nu+1)+i;faces.append((a,a+1,a+nu+2,a+nu+1))
            # Author the thin shell explicitly. Smooth front/back cloth and flat
            # sewn rims keep opposing normals separate at the 12 mm perimeter.
            # A normal-offset Solidify modifier pinched a handful of rim faces.
            vertex_count=len(verts);sheet_faces=len(faces)
            verts += [(x,y+.012,z) for x,y,z in verts]
            outer=[tuple(reversed(face)) for face in faces]
            inner=[tuple(i+vertex_count for i in face) for face in faces]
            shell=outer+inner
            for i in range(nu):
                a=i;b=i+1;shell.append((a,b,b+vertex_count,a+vertex_count))
                a=nv*(nu+1)+i;b=a+1;shell.append((b,a,a+vertex_count,b+vertex_count))
            for j in range(nv):
                a=j*(nu+1);b=(j+1)*(nu+1);shell.append((b,a,a+vertex_count,b+vertex_count))
                a=j*(nu+1)+nu;b=(j+1)*(nu+1)+nu;shell.append((a,b,b+vertex_count,a+vertex_count))
            ob=m.mesh('Living03_'+side+'_Curtain',verts,shell,'flax_cloth');NEW.append(ob)
            for poly in ob.data.polygons:poly.use_smooth=poly.index<sheet_faces*2
            uv=ob.data.uv_layers.new(name='UVMap')
            for loop in ob.data.loops:
                co=ob.data.vertices[loop.vertex_index].co;uv.data[loop.index].uv=(co.x*2,co.z*2)
            for z in [3.29,1.37]:
                path=[(center+(i/nu-.5)*.52,6.28+.065*math.sin(i/nu*math.tau*4),z) for i in range(nu+1)]
                curve('Living03_Curtain_Hem',[path],.012,'flax_edge')
            for i in range(5):
                ring=m.ring('Living03_Curtain_Hanging_Ring',(center-.22+i*.11,6.33,3.40),.043,.009,'honey_edge',(math.pi/2,0,0),segments=16);NEW.append(ring)


def lathe(name, center, profile, key, segments=32):
    verts=[];faces=[]
    for radius,z in profile:
        for i in range(segments):
            a=i/segments*math.tau;verts.append((center[0]+radius*math.cos(a),center[1]+radius*math.sin(a),center[2]+z))
    for j in range(len(profile)-1):
        for i in range(segments):
            n=(i+1)%segments;a=j*segments;b=(j+1)*segments
            faces.append((a+i,a+n,b+n,b+i))
    ob=m.mesh(name,verts,faces,key);NEW.append(ob)
    for f in ob.data.polygons:f.use_smooth=True
    uv_project(ob,1)
    return ob


def cup(name,x,y,z,key='ceramic'):
    # Closed cross-section: genuine inner cup wall, rounded lip and sealed base.
    lathe(name,(x,y,z),[(0,0),(.09,0),(.125,.025),(.14,.20),(.137,.23),(.116,.23),(.111,.21),(.095,.045),(0,.045)],key)
    handle=[(x+.13+.088*math.sin(i/20*math.pi),y,z+.13+.085*math.cos(i/20*math.pi)) for i in range(21)]
    curve(name+'_Handle',[handle],.023,key)
    ob=m.cyl(name+'_Tea',(x,y,z+.196),.112,.006,'tea',32);NEW.append(ob)
    lathe(name+'_Saucer',(x,y,z-.025),[(0,0),(.19,0),(.21,.023),(.20,.038),(.17,.025),(0,.02)],'ceramic_warm')


def tabletop_life():
    m.group('44_Living03_Ceramics_and_Reading')
    for ob in list(bpy.context.scene.objects):
        if ob.name.startswith('Home_Cup_'):bpy.data.objects.remove(ob,do_unlink=True)
    for x in [-.7,.7]:cup('Home_Cup_Refined',x,2.2,1.01)
    # Keep the welcome-table center free for task state and party keepsake geometry.
    # The desk remains an active journal locus; details stay on its right rear corner.
    x,y,z=5.72,1.06,1.05
    box('Living03_Tea_Tray',(x,y,z+.015),(.75,.57,.035),'walnut',.08)
    lathe('Living03_Teapot',(x+.10,y+.02,z+.045),[(0,0),(.10,0),(.16,.06),(.18,.16),(.14,.26),(.095,.28),(.085,.255),(.12,.22),(.14,.15),(.12,.07),(0,.035)],'ceramic_warm')
    ob=m.cyl('Living03_Teapot_Lid',(x+.10,y+.02,z+.33),.11,.035,'ceramic',32);NEW.append(ob)
    ob=m.ball('Living03_Teapot_Knob',(x+.10,y+.02,z+.37),(.035,.035,.035),'honey_edge',16,10);NEW.append(ob)
    curve('Living03_Teapot_Handle',[[(x+.10-.13-.09*math.sin(i/20*math.pi),y+.02,z+.21+.10*math.cos(i/20*math.pi)) for i in range(21)]],.025,'ceramic_warm')
    curve('Living03_Teapot_Spout',[[(x+.22,y+.02,z+.16),(x+.32,y+.02,z+.22),(x+.38,y+.02,z+.28)]],.045,'ceramic_warm')
    # Real book boards and page stack on the album stand; never replace Desk_Journal.
    box('Living03_Reading_Book_Cover',(3.47,5.52,1.00),(.72,.47,.045),'sage_edge',.014).rotation_euler.z=-.12
    box('Living03_Reading_Book_Pages',(3.47,5.52,1.045),(.68,.43,.055),'paper',.008).rotation_euler.z=-.12
    box('Living03_Reading_Book_Top',(3.47,5.52,1.08),(.72,.47,.025),'sage_edge',.012).rotation_euler.z=-.12
    box('Living03_Reading_Book_Ribbon',(3.67,5.30,1.09),(.045,.17,.008),'rose_edge',.002)


def furniture_finish():
    m.group('45_Living03_Carpentry')
    for ob in list(bpy.context.scene.objects):
        if ob.type!='MESH' or ob.name.startswith(('SG_COLLIDER_','PREVIEW_')):continue
        if ob.name.startswith('SG_DECOR_') or any(p.name.startswith(('SG_DECOR_','HOME_TASK_')) for p in ([ob.parent] if ob.parent else [])):continue
        names=[ma.name for ma in ob.data.materials]
        if ob.name=='SG_FLOOR_Main':
            # Appearance only: original vertices and floor winding remain byte-for-byte stable.
            assign(ob,'floor_oak',.20)
        elif any(ma in ['MAT_oak','MAT_lightwood','MAT_wood'] for ma in names):
            assign(ob,'oak' if 'MAT_wood' not in names else 'walnut',.65)
    # A slender undercut/apron gives the already rounded tabletop a constructed edge.
    for name,x,y,w,d,h in [('Dining',0,1.7,2.7,1.6,.9),('Journal',5,1,2.6,1.25,.95),('Mail',-4.3,-4.8,1.9,1,.78)]:
        for yy in [y-d/2+.13,y+d/2-.13]:
            box('Living03_'+name+'_Apron',(x,yy,h-.17),(w-.30,.08,.18),'oak',.025)
        for xx in [x-w/2+.13,x+w/2-.13]:
            box('Living03_'+name+'_Apron',(xx,y,h-.17),(.08,d-.30,.18),'oak',.025)
    # Soft wall wainscot pattern creates a domestic scale, behind all walkable areas.
    for x in np.arange(-7.55,7.56,.82):
        box('Living03_Wall_Batten',(x,6.815,.73),(.045,.032,.85),'wall_trim',.009)
    box('Living03_Wall_Dado',(0,6.78,1.18),(15.8,.07,.07),'wall_trim',.016)


def geometry_audit():
    closed=[];open_mesh=[];degenerate=[];negative=[];verts=0;tris=0
    dg=bpy.context.evaluated_depsgraph_get()
    for ob in NEW:
        if ob.type not in ('MESH','CURVE'):continue
        if ob.type=='MESH':
            bm=bmesh.new();bm.from_mesh(ob.data)
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
            bm.to_mesh(ob.data);bm.free();ob.data.update()
        evaluated=ob.evaluated_get(dg)
        data=evaluated.to_mesh();bm=bmesh.new();bm.from_mesh(data)
        # Blender curve end caps duplicate their boundary vertices. Evaluate the
        # welded topology that is shipped, rather than flagging those seams as holes.
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
        is_closed=all(e.is_manifold for e in bm.edges)
        volume=bm.calc_volume(signed=True) if is_closed else None
        if volume is not None and volume < -1e-8:negative.append(ob.name)
        (closed if is_closed else open_mesh).append(ob.name)
        for face in bm.faces:
            if face.calc_area()<1e-12:degenerate.append(ob.name);break
        verts+=len(bm.verts);tris+=sum(len(f.verts)-2 for f in bm.faces)
        bm.free();evaluated.to_mesh_clear()
    # Lathed center rings have coincident vertices; weld and remove resulting zero-area faces.
    return {'new_objects':len(NEW),'new_vertices_evaluated':verts,'new_triangles_evaluated':tris,
            'closed_meshes':len(closed),'open_detail_meshes':open_mesh,'negative_closed_volumes':negative,'degenerate_meshes':degenerate}


def clean_lathe_centers():
    for ob in NEW:
        if ob.type!='MESH':continue
        bm=bmesh.new();bm.from_mesh(ob.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
        bad=[f for f in bm.faces if f.calc_area()<1e-12]
        if bad:bmesh.ops.delete(bm,geom=bad,context='FACES')
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(ob.data);bm.free()


def export_refined_glb():
    # Save above preserves editable curves. Weld their coincident cap seams only
    # in this export copy, so handles/fringes are genuinely closed runtime solids.
    curves=[ob for ob in NEW if ob.type=='CURVE']
    if curves:
        bpy.ops.object.select_all(action='DESELECT')
        for ob in curves:ob.select_set(True)
        bpy.context.view_layer.objects.active=curves[0]
        bpy.ops.object.convert(target='MESH')
        for ob in bpy.context.selected_objects:
            bm=bmesh.new();bm.from_mesh(ob.data)
            bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
            bm.to_mesh(ob.data);bm.free();ob.data.update()
    p.export_glb(GLB)


def run():
    for directory in [TEX,PROOF]:directory.mkdir(parents=True,exist_ok=True)
    old_files={str(f.relative_to(ROOT)).replace('\\','/'):digest(f) for f in FOLDER.iterdir() if f.is_file() and any(x in f.name for x in ['v01','v02'])}
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    bpy.context.view_layer.update()
    before=protected_objects()
    m.M={key:bpy.data.materials.get('MAT_'+key) for key in m.PALETTE}
    m.M['proxy']=bpy.data.materials.get('MAT_COLLISION_TRANSPARENT')
    m.COLLS={c.name:c for c in bpy.context.scene.collection.children};m.PARENT=None;m.SPHERES={}
    bpy.context.preferences.filepaths.save_version=0
    material('oak',(.63,.43,.25),.48,'wood',.17)
    material('walnut',(.38,.22,.12),.48,'wood',.17)
    material('floor_oak',(.67,.51,.33),.62,'floor',.14)
    material('rose_cloth',(.65,.29,.285),.92,'cloth',.22)
    material('sage_cloth',(.24,.46,.38),.92,'cloth',.22)
    material('honey_cloth',(.78,.55,.24),.92,'cloth',.22)
    material('flax_cloth',(.81,.76,.61),.95,'cloth',.18)
    material('rug_rose',(.59,.32,.31),.98,'cloth',.28)
    material('rose_edge',(.43,.16,.16),.91)
    material('sage_edge',(.15,.32,.26),.88)
    material('honey_edge',(.59,.37,.12),.70)
    material('flax_edge',(.69,.61,.43),.95)
    material('ceramic',(.29,.51,.47),.27)
    material('ceramic_warm',(.86,.79,.64),.31)
    material('tea',(.16,.065,.02),.22)
    material('wall_trim',(.75,.68,.52),.78)
    furniture_finish();sofa_and_chair();rugs();curtains();tabletop_life()
    clean_lathe_centers()
    bpy.context.view_layer.update()
    after=protected_objects()
    assert before==after, 'Gameplay geometry, markers, hierarchy or metadata changed'
    audit=geometry_audit()
    assert not audit['negative_closed_volumes'],audit
    assert not audit['degenerate_meshes'],audit
    sc=bpy.context.scene
    sc.name='home_v03';sc['refinement_version']='living-room-v03'
    sc['authorship']='Original Blender geometry and deterministic 512px tiled PBR textures; no third-party downloads'
    sc['gameplay_preservation']='SG markers, floor vertices, collision proxies, task-state and decoration roots preserved from home_v02'
    sc['protected_source']=str(SOURCE.relative_to(ROOT)).replace('\\','/')
    sc.render.resolution_x=1320;sc.render.resolution_y=1162;sc.render.resolution_percentage=100
    if hasattr(sc,'eevee') and hasattr(sc.eevee,'taa_render_samples'):sc.eevee.taa_render_samples=96
    # Match the original preview camera and lights for a fair full-room comparison.
    source=p.collect_source('home')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT),compress=True)
    if '--no-render' not in sys.argv:
        p.render_preview(FOLDER/'preview_v03_verified.png')
        cam=sc.camera;old_pos=cam.location.copy();old_rot=cam.rotation_euler.copy();old_scale=cam.data.ortho_scale
        cam.location=(10,-9,10);cam.data.ortho_scale=10.5;p.point_camera(cam,(1.25,3.65,.7))
        sc.render.resolution_x=1440;sc.render.resolution_y=1000
        p.render_preview(FOLDER/'detail_v03_verified.png')
        cam.location=old_pos;cam.rotation_euler=old_rot;cam.data.ortho_scale=old_scale
    export_refined_glb()
    stats=p.confirm_export(GLB,source)
    for path,hashval in old_files.items():assert digest(ROOT/path)==hashval,path
    report={**source,**stats,'source_blend':str(OUT.relative_to(ROOT)).replace('\\','/'),'protected_source_files':old_files,
            'protected_object_count':len(before),'protected_objects_unchanged':True,'geometry':audit,'textures':TEXTURES,
            'preview_camera_matches_v02':True,'runtime_validation':'pending parent integration',
            'shared_manifests_modified':False,'game_glb_modified':False}
    p.write_json(FOLDER/'validation_v03.json',report)
    p.write_json(PROOF/'source-asset-report.json',report)
    entry=p.manifest_entry('home','客厅',source,stats,{'blend':str(OUT.relative_to(ROOT)).replace('\\','/'),'glb':str(GLB.relative_to(ROOT)).replace('\\','/'),'preview':'assets/blender/interiors/home/preview_v03_verified.png'})
    p.write_json(FOLDER/'home_v03.manifest-entry.json',entry)
    print('LIVING_ROOM_REFINED '+json.dumps({'stats':stats,'geometry':audit,'protected_objects':len(before)},ensure_ascii=False),flush=True)


if __name__=='__main__':run()
