"""Refine the existing home estate source into a separate v03 asset.

Run in a separate Blender background process. Never updates shared manifests or
game files. SG_ nodes, collision meshes and HOME_TASK_ hierarchies are preserved.
All new geometry and textures are original deterministic project-authored art.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'assets/blender/interiors/home_estate'
SOURCE = FOLDER / 'home_estate_v02.blend'
sys.path.insert(0, str(ROOT / 'assets/blender/interiors/scripts'))
import modeling as m
import pipeline as p

SEED = 2610243
RNG = random.Random(SEED)
NEW_OBJECTS = []


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def protected_snapshot():
    rows = {}
    bpy.context.view_layer.update()
    for ob in bpy.context.scene.objects:
        if not ob.name.startswith(('SG_', 'COL_', 'HOME_TASK_')):
            continue
        rows[ob.name] = {
            'type': ob.type,
            'parent': ob.parent.name if ob.parent else None,
            'matrix': [round(float(v), 7) for row in ob.matrix_world for v in row],
            'properties': {k: ob[k] for k in ob.keys()},
        }
        if ob.type == 'MESH':
            payload = str(([tuple(v.co) for v in ob.data.vertices],
                           [tuple(f.vertices) for f in ob.data.polygons]))
            rows[ob.name]['geometry_sha256'] = hashlib.sha256(payload.encode()).hexdigest()
    return rows


def bind_helpers():
    m.M = {mat.name.removeprefix('MAT_'): mat for mat in bpy.data.materials}
    m.COLLS = {c.name: c for c in bpy.data.collections}
    m.PARENT = None
    m.SPHERES = {}
    m.group('34_Courtyard_Refined_Detail')


def material(key, color, roughness=.86, metallic=0):
    mat = bpy.data.materials.get('MAT_' + key) or bpy.data.materials.new('MAT_' + key)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    mat.diffuse_color = (*color, 1)
    m.M[key] = mat
    return mat


def textured_material(key, color, roughness, kind, strength=.06):
    """Small baked albedo images; no unsupported procedural shader nodes in GLB."""
    mat = material(key, color, roughness)
    size = 256
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    generator = np.random.default_rng(SEED + sum(ord(c) for c in key))
    noise = generator.uniform(-1, 1, (size, size)).astype(np.float32)
    broad = (np.sin(xx * math.tau * 2 + np.sin(yy * math.tau * 3)) +
             np.cos(yy * math.tau * 4 - np.sin(xx * math.tau * 2))) * .25
    if kind == 'wood':
        wave = np.sin(yy * math.tau * 25 + np.sin(xx * math.tau * 2) * 1.7)
        fine = np.sin(yy * math.tau * 59 + np.sin(xx * math.tau * 5))
        pattern = wave * .5 + fine * .15 + noise * .16 + broad * .2
    elif kind == 'grass':
        pattern = broad * .8 + noise * .42 + np.sin((xx + yy) * math.tau * 48) * .15
    else:
        pattern = broad * .45 + noise * .65
    rgba = np.ones((size, size, 4), dtype=np.float32)
    for channel in range(3):
        rgba[:, :, channel] = np.clip(color[channel] * (1 + pattern * strength), 0, 1)
    texdir = FOLDER / 'textures_v03'
    texdir.mkdir(exist_ok=True)
    image = bpy.data.images.new('home_v03_' + key, width=size, height=size, alpha=False)
    image.colorspace_settings.name = 'Linear Rec.709'
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(texdir / (key + '_albedo.png'))
    image.file_format = 'PNG'
    image.save()
    image.pack()
    node = mat.node_tree.nodes.new('ShaderNodeTexImage')
    node.name = 'Baked subtle surface pigment'
    node.image = image
    node.interpolation = 'Linear'
    node.extension = 'REPEAT'
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    mat.node_tree.links.new(node.outputs['Color'], bsdf.inputs['Base Color'])
    mat['texture_provenance'] = 'Original deterministic numpy pigment, seed ' + str(SEED)
    return mat


def surface_palette():
    textured_material('grass', (.34, .45, .205), .96, 'grass', .18)
    textured_material('wood', (.39, .235, .125), .87, 'wood', .13)
    textured_material('oak', (.58, .395, .22), .83, 'wood', .10)
    textured_material('lightwood', (.72, .55, .34), .82, 'wood', .09)
    textured_material('garden_paver', (.71, .665, .54), .93, 'stone', .11)
    textured_material('garden_paver_light', (.77, .725, .60), .92, 'stone', .10)
    textured_material('garden_gravel', (.56, .535, .42), .97, 'stone', .16)
    textured_material('garden_stone', (.58, .56, .46), .94, 'stone', .11)
    textured_material('plaster', (.86, .79, .66), .94, 'plaster', .045)
    textured_material('clay', (.59, .315, .205), .91, 'stone', .09)
    textured_material('soil', (.23, .165, .105), .99, 'stone', .14)
    textured_material('roof', (.145, .295, .29), .83, 'stone', .07)
    textured_material('roof_light', (.158, .313, .305), .82, 'stone', .06)
    textured_material('roof_dark', (.13, .274, .273), .86, 'stone', .06)
    for key, color in [('canopy_deep', (.155,.30,.10)),
                       ('canopy_middle', (.235,.385,.145)),
                       ('canopy_sage', (.305,.445,.19)),
                       ('canopy_sun', (.36,.49,.225)),
                       ('grass_blade_deep', (.265,.375,.16)),
                       ('grass_blade_sage', (.36,.465,.225)),
                       ('grass_tip', (.44,.53,.275)),
                       ('edge_pebble', (.65,.615,.51)),
                       ('leaf_vein', (.30,.38,.17)),
                       ('twig', (.355,.24,.135))]:
        material(key, color, .89)


def uv_project():
    """Physical-scale, dominant-face projection; grain follows each piece's length."""
    textured = {mat.name for mat in bpy.data.materials
                if mat.use_nodes and any(n.type == 'TEX_IMAGE' for n in mat.node_tree.nodes)}
    count = 0
    for ob in bpy.context.scene.objects:
        if ob.type != 'MESH' or ob.name.startswith(('SG_COLLIDER_', 'COL_', 'PREVIEW_')):
            continue
        if not any(s.material and s.material.name in textured for s in ob.material_slots):
            continue
        mesh = ob.data
        uv = mesh.uv_layers.get('SurfaceUV') or mesh.uv_layers.new(name='SurfaceUV')
        mesh.uv_layers.active = uv
        dims = [max(abs(v.co[i]) for v in mesh.vertices)*2 if mesh.vertices else 1 for i in range(3)]
        iswood = any(s.material and s.material.name in ('MAT_wood','MAT_oak','MAT_lightwood') for s in ob.material_slots)
        for face in mesh.polygons:
            axis = max(range(3), key=lambda i: abs(face.normal[i]))
            axes = [i for i in range(3) if i != axis]
            if iswood:
                axes.sort(key=lambda i: dims[i], reverse=True)
            for loop_index in face.loop_indices:
                co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
                uv.data[loop_index].uv = (co[axes[0]] * .65, co[axes[1]] * .65)
        count += 1
    return count


class Batch:
    def __init__(self, name, mat, smooth=False):
        self.name, self.mat, self.smooth = name, mat, smooth
        self.verts, self.faces = [], []

    def append(self, vertices, faces):
        start = len(self.verts)
        self.verts.extend(vertices)
        self.faces.extend(tuple(start+i for i in f) for f in faces)

    def finish(self):
        if not self.verts:
            return None
        ob = m.mesh(self.name, self.verts, self.faces, self.mat)
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(ob.data)
        bm.free()
        for face in ob.data.polygons:
            face.use_smooth = self.smooth
        ob['refinement_v03'] = True
        NEW_OBJECTS.append(ob)
        return ob


def leaf(batch, center, length, width, angle, tilt=.12, thickness=.012):
    """Closed lens leaf/blade: six vertices, eight triangles, outward normals."""
    transform = Matrix.Rotation(angle, 4, 'Z') @ Matrix.Rotation(tilt, 4, 'X')
    vertices = [(0,-length*.5,0), (width*.5,0,0), (0,length*.5,0),
                (-width*.5,0,0), (0,0,thickness), (0,0,-thickness)]
    origin = Vector(center)
    transformed = [tuple(origin + transform @ Vector(v)) for v in vertices]
    faces = []
    for i in range(4):
        faces.extend([(i,(i+1)%4,4), ((i+1)%4,i,5)])
    batch.append(transformed, faces)


def rounded_cluster(batch, center, radii, seed):
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1)
    bm.verts.ensure_lookup_table()
    verts = []
    for v in bm.verts:
        rough = 1 + .06*math.sin(v.co.x*8 + seed) + .045*math.sin(v.co.y*11)
        verts.append(tuple(center[j] + v.co[j]*radii[j]*rough for j in range(3)))
    faces = [tuple(v.index for v in f.verts) for f in bm.faces]
    batch.append(verts, faces)
    bm.free()


def refine_tree(prefix, x, y, scale):
    old = [o for o in list(bpy.context.scene.objects) if o.name.startswith(prefix+'_Canopy_')]
    for ob in old:
        bpy.data.objects.remove(ob, do_unlink=True)
    mats = ['canopy_deep', 'canopy_middle', 'canopy_sage', 'canopy_sun']
    batches = [Batch(prefix+'_Foliage_Boughs_'+str(i), mat, True) for i,mat in enumerate(mats)]
    leaves = [Batch(prefix+'_Leaf_Sprays_'+str(i), mat) for i,mat in enumerate(mats)]
    rng = random.Random(prefix + str(SEED))
    centers = []
    # Six unequal branch tips, with flattened sprays following each branch.
    # This keeps a canted, open outline instead of a single spherical shell.
    boughs=[(-.92,.10,2.98,.80),(.83,.27,3.10,.97),(-.27,-.63,3.53,1.0),
            (.13,.55,3.92,.86),(-.64,.22,4.12,.65),(.73,-.43,4.03,.72)]
    for i in range(36):
        bx,by,bz,extent=boughs[i//6]
        a = (i%6)*2.39996 + rng.uniform(-.24,.24)
        ring = .35 if i%6<4 else .13
        center = (x+(bx+math.cos(a)*ring*extent)*scale,
                  y+(by+math.sin(a)*ring*extent)*scale,
                  (bz+rng.uniform(-.16,.20))*scale)
        radius = rng.uniform(.43,.63)*scale*extent
        radii = (radius*rng.uniform(1.0,1.32), radius*rng.uniform(.90,1.15), radius*.69)
        tone = 0 if bz < 3.1 and i%3==0 else 1+(i%3)
        rounded_cluster(batches[tone], center, radii, i+SEED)
        centers.append((center,radii,tone))
        # Exterior leaves break each bough contour without alpha cards.
        for j in range(16):
            az = rng.uniform(0,math.tau)
            elevation = rng.uniform(-.5,.95)
            rr = math.sqrt(1-elevation*elevation)
            pos = (center[0]+math.cos(az)*radii[0]*rr*.98,
                   center[1]+math.sin(az)*radii[1]*rr*.98,
                   center[2]+elevation*radii[2])
            leaf(leaves[tone], pos, rng.uniform(.22,.36)*scale,
                 rng.uniform(.085,.145)*scale, az+.5, rng.uniform(-.65,.65), .012*scale)
    for batch in batches+leaves:
        batch.finish()
    # Branchlets visible through small lower gaps; all inside the original crown.
    for i,((cx,cy,cz),_,_) in enumerate(centers):
        if i%5 == 0 and cz < 3.55*scale:
            ob = m.beam(prefix+'_Fine_Bough', (x+.03,y,2.4*scale), (cx,cy,cz), .026*scale, 'twig')
            ob['refinement_v03']=True
            NEW_OBJECTS.append(ob)


def grass_edges():
    blades = [Batch('Garden_Grass_Edge_'+str(i), mat) for i,mat in enumerate(
        ['grass_blade_deep','grass_blade_sage','grass_tip'])]
    gravel = Batch('Garden_Path_Scattered_Grains','edge_pebble',True)
    rng = random.Random(SEED)
    locations = []
    # Keep the whole transverse navigation lane open. Tufts sit beyond its edge.
    for side in [-1,1]:
        for i in range(77):
            x = -12.8 + i*.335 + rng.uniform(-.1,.1)
            y = -10.2 + side*(1.17+rng.uniform(.05,.20))
            t = min(1,max(0,(y+15.25)/7.5))
            curve_x = -3.5*(3*t*t-2*t*t*t)
            if abs(x-curve_x)<1.55:
                continue
            locations.append((x,y,rng.uniform(.065,.14)))
            if i%2==0:
                rounded_cluster(gravel,(x,y-side*.08,.038),(.05,.035,.016),SEED+i)
    # Soft outer curves: no detail placed across the gate opening.
    for i in range(34):
        t = .1 + .58*i/33
        xx = -3.5*(3*t*t-2*t*t*t)
        yy = -15.25+7.5*t
        dx,dy=-3.5*(6*t-6*t*t),7.5
        length=math.hypot(dx,dy)
        for side in [-1,1]:
            x,y = xx+side*dy/length*1.43,yy-side*dx/length*1.43
            if y<-11.5 and abs(x)>2.5:
                locations.append((x,y,rng.uniform(.06,.13)))
    # Sparse lawn tufts and slightly denser foreground herb borders.
    for i in range(130):
        x,y = rng.uniform(-13.5,13.5), rng.uniform(-13.45,-11.65)
        t = min(1,max(0,(y+15.25)/7.5))
        curve_x = -3.5*(3*t*t-2*t*t*t)
        if abs(x-curve_x)<1.7 or (abs(x-2)<1.6 and abs(y+11.82)<.7) or (6<x<10.5 and y>-12.7):
            continue
        locations.append((x,y,rng.uniform(.045,.11)))
    for i,(x,y,h) in enumerate(locations):
        for j in range(4):
            angle = rng.uniform(0,math.tau)
            leaf(blades[(i+j)%3], (x+rng.uniform(-.05,.05),y+rng.uniform(-.05,.05),h*.45),
                 h*1.5, rng.uniform(.025,.042), angle, rng.uniform(.6,1.15), .003)
    for batch in blades+[gravel]:
        batch.finish()
    return len(locations)


def living_details():
    # Small fruit at the visible branch tips; original fruit remains untouched.
    for i,(x,y,z) in enumerate([(-15.16,-12.54,2.77),(-13.52,-12.94,3.25),
                                (-14.56,-12.95,3.52),(-13.13,-12.30,3.76)]):
        m.apple('Refined_West_Apple_'+str(i),x,y,z,.13)
    # Turned cup rim and dark tea surface give the existing cup readable depth.
    m.cyl('Refined_Tea_Surface',(13.4,-8.9,.966),.079,.005,'wood',20)
    m.ring('Refined_Tea_Cup_Rim',(13.4,-8.9,.963),.097,.011,'ivory',segments=24)
    # Brass fasteners sit on the existing bench/raised-bed timber, not in walkways.
    for x in [10.30,12.70]:
        for z in [1.06,1.33]:
            ob=m.cyl('Refined_Bench_Bolt',(x,-8.553,z),.026,.015,'garden_iron',10)
            ob.rotation_euler.x=math.pi/2
    for x in [7.20,10.10]:
        for z in [.39,.49]:
            ob=m.cyl('Refined_Planter_Pin',(x,-12.493,z),.021,.012,'garden_iron',8)
            ob.rotation_euler.x=math.pi/2
    # A folded tea towel belongs to the existing rest bench and adds textile scale.
    m.box('Refined_Bench_Linen',(12.35,-8.78,.715),(.52,.43,.026),'ivory',.012)
    for x in [12.17,12.22,12.47,12.52]:
        m.box('Refined_Linen_Woven_Stripe',(x,-8.78,.730),(.012,.40,.003),'teal',.001)
    # Small irregular weeds beside planted rings, behind the interaction lane.
    beds=[(-14,-12.1),(14.1,-10.0)]
    leaves=Batch('Refined_Tree_Base_Herbs','canopy_sage')
    for x,y in beds:
        for i in range(22):
            angle=i*2.39996
            radius=.65+RNG.random()*.40
            xx,yy=x+math.cos(angle)*radius,y+math.sin(angle)*radius
            for j in range(3):
                leaf(leaves,(xx,yy,.09),.23,.075,angle+j*1.8,.45,.01)
    leaves.finish()
    # Keep new props grouped and identifiable in the editable project.
    for ob in bpy.context.scene.objects:
        if ob.name.startswith('Refined_'):
            ob['refinement_v03']=True
            if ob not in NEW_OBJECTS:
                NEW_OBJECTS.append(ob)


def geometry_report():
    reports = []
    for ob in NEW_OBJECTS:
        if ob.type != 'MESH':
            continue
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=.000001)
        # Preserve existing helper conventions; recalculation only for new geometry.
        bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
        bm.to_mesh(ob.data)
        bad_area = sum(f.calc_area()<1e-10 for f in bm.faces)
        boundary = sum(e.is_boundary for e in bm.edges)
        nonmanifold = sum(not e.is_manifold for e in bm.edges)
        report={'name':ob.name,'vertices':len(bm.verts),'faces':len(bm.faces),
                'boundary_edges':boundary,'nonmanifold_edges':nonmanifold,
                'degenerate_faces':bad_area,'signed_volume':round(bm.calc_volume(signed=True),8)}
        reports.append(report)
        bm.free()
    return reports


def main():
    FOLDER.mkdir(parents=True,exist_ok=True)
    original_hash=digest(SOURCE)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    bpy.context.preferences.filepaths.save_version=0
    before=protected_snapshot()
    bind_helpers()
    surface_palette()
    refine_tree('West_Apple_Tree',-14,-12.1,.96)
    refine_tree('East_Shade_Tree',14.1,-10.0,1.0)
    tuft_count=grass_edges()
    living_details()
    uv_count=uv_project()
    geometry=geometry_report()
    after=protected_snapshot()
    if before != after:
        raise RuntimeError('Protected node contract changed')
    # Independent geometry checks are on actual authored faces, not a render.
    bad=[r for r in geometry if r['degenerate_faces'] or r['nonmanifold_edges']]
    if bad:
        raise RuntimeError('New geometry failed validation: '+str(bad))
    scene=bpy.context.scene
    scene.name='home_estate_v03'
    scene['art_revision']='courtyard-refinement-v03'
    scene['source_preservation']='Derived from v02 without editing original; gameplay nodes unchanged'
    scene['refinement_direction']='Soft natural boughs, individual leaves, warm worn surfaces, grass/path transitions'
    blend=FOLDER/'home_estate_v03.blend'
    glb=FOLDER/'home_estate_v03.glb'
    preview=FOLDER/'preview_v03.png'
    if 'SG_HOUSE_ENTRY' not in p.REQUIRED:
        p.REQUIRED.append('SG_HOUSE_ENTRY')
    source=p.collect_source('home_estate')
    if source['missing_external_textures']:
        raise RuntimeError(source['missing_external_textures'])
    source['required_nodes']=sorted(before)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    p.render_preview(preview)
    # Also render a closer native-source view; not a substitute for Godot checks.
    camera=scene.camera
    old_pos=camera.location.copy();old_rot=camera.rotation_euler.copy();old_scale=camera.data.ortho_scale
    camera.location=(21,-34,22);camera.data.ortho_scale=31.5
    p.point_camera(camera,(0,-10.8,1.4))
    p.render_preview(FOLDER/'preview_detail_v03.png')
    camera.location=old_pos;camera.rotation_euler=old_rot;camera.data.ortho_scale=old_scale
    p.export_glb(glb)
    stats=p.confirm_export(glb,source)
    if digest(SOURCE)!=original_hash:
        raise RuntimeError('Original source changed')
    textures=[{'path':f.relative_to(ROOT).as_posix(),'width':256,'height':256,
               'bytes':f.stat().st_size,'sha256':digest(f)}
              for f in sorted((FOLDER/'textures_v03').glob('*.png'))]
    texture_budget={'count':len(textures),'source_png_bytes':sum(t['bytes'] for t in textures),
                    'uncompressed_rgba8_bytes':len(textures)*256*256*4,
                    'uncompressed_rgba8_with_mips_approx_bytes':round(len(textures)*256*256*4*4/3),
                    'embedded_in_glb':True,'textures':textures}
    validation={**source,**stats,'source_blend':blend.relative_to(ROOT).as_posix(),
                'source_v02_sha256':original_hash,'source_v02_preserved':True,
                'protected_nodes_unchanged':before==after,'protected_node_count':len(before),
                'protected_snapshot':before,'new_geometry':geometry,
                'new_geometry_checks_passed':not bad,'new_grass_tufts':tuft_count,
                'textured_mesh_objects':uv_count,'blender_version':bpy.app.version_string,
                'texture_budget':texture_budget,
                'validation_scope':'Blender source geometry and GLB export; pending Godot runtime inspection'}
    p.write_json(FOLDER/'validation_v03.json',validation)
    entry=p.manifest_entry('home_estate','家园院落',source,stats,existing={
        'blend':blend.relative_to(ROOT).as_posix(),'glb':glb.relative_to(ROOT).as_posix(),
        'preview':preview.relative_to(ROOT).as_posix()})
    p.write_json(FOLDER/'manifest_v03.json',{
        'schema_version':1,'room':entry,'status':'authored_pending_engine_validation',
        'source_script':'scripts/refine_home_courtyard.py','seed':SEED,
        'source_script_sha256':digest(__file__),'texture_budget':texture_budget,
        'provenance':'Original project-authored Blender geometry and mathematical surface textures; no external media',
        'source_v02_sha256':original_hash,
        'changes':['Replaced twelve coarse crown blocks with layered boughs and closed individual leaf sprays',
                   'Added sparse closed grass blades and small pebbles outside path',
                   'Authored fourteen packed 256px albedo textures with physical-scale UVs',
                   'Reduced roof slate color contrast and separated material roughness',
                   'Added bench joinery, folded linen and cup rim/tea detail'],
        'locks':'All original SG_, COL_ and HOME_TASK_ transforms, parents, custom properties and collision/floor vertex geometry unchanged',
        'technical':stats})
    print('COURTYARD_V03_READY '+json.dumps(stats),flush=True)


if __name__=='__main__':
    main()
