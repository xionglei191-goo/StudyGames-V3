"""Prepare user-supplied Tripo meshes without altering the originals.

Blender --background --factory-startup --python this_file.py -- [character ids]
Only the new assets/characters/tripo_v1 directory is written.
"""
from __future__ import annotations
import bpy
import bmesh
import hashlib
import json
import math
import sys
import time
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/characters/tripo_v1"
PROFILES = [
    ("player", "01_player.glb", 2.15, 36000, "humanoid"),
    ("textbook_lingling", "02_lingling.glb", 2.20, 36000, "humanoid"),
    ("textbook_peter", "03_peter.glb", 2.20, 36000, "humanoid"),
    ("textbook_anne", "04_anne.glb", 2.20, 36000, "humanoid"),
    ("textbook_mingming", "05_mingming.glb", 2.20, 36000, "humanoid"),
    ("textbook_dongdong", "06_dongdong.glb", 2.20, 36000, "humanoid"),
    ("textbook_tim", "07_tim.glb", 2.20, 36000, "humanoid"),
    ("textbook_miss_li", "08_miss_li.glb", 2.20, 36000, "humanoid"),
    ("textbook_dino", "09_dino.glb", 2.15, 48000, "dino"),
    ("npc_bear_uncle", "10_bear_uncle.glb", 2.15, 36000, "animal"),
    ("npc_rabbit_gardener", "11_rabbit_gardener.glb", 2.45, 40000, "animal"),
    ("textbook_jim", "12_jim.glb", 2.05, 60000, "wheelchair"),
]

def setup_render(height):
    scene = bpy.context.scene
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = next(i.identifier for i in scene.render.image_settings.bl_rna.properties['file_format'].enum_items if i.identifier == 'PNG')
    if hasattr(scene, 'eevee'):
        scene.eevee.taa_render_samples = 24
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new('ReviewWorld')
    scene.world.use_nodes = True
    background = next(n for n in scene.world.node_tree.nodes if n.type == 'BACKGROUND')
    background.inputs['Color'].default_value = (0.92, 0.92, 0.92, 1)
    background.inputs['Strength'].default_value = 0.6
    # Keep the installed OCIO configuration's default transform. Its dynamic
    # enum cannot be discovered from static RNA in Blender's headless process.
    for name, position, energy, size in [
        ('Key', (3, -4, 5), 360, 4), ('Fill', (-3, -2, 3), 180, 4), ('Back', (0, 3, 4), 230, 3)
    ]:
        data = bpy.data.lights.new(name, 'AREA')
        data.energy, data.shape, data.size = energy, 'DISK', size
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.location = position
        obj.rotation_euler = (Vector((0, 0, height * 0.55)) - obj.location).to_track_quat('-Z', 'Y').to_euler()
    data = bpy.data.cameras.new('ReviewCamera')
    data.type = 'ORTHO'
    data.ortho_scale = height * 1.23
    camera = bpy.data.objects.new('ReviewCamera', data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    return camera

def process(profile):
    character_id, filename, height, budget, family = profile
    started = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    source = ROOT / 'assets/tripo' / filename
    output = OUT / character_id
    output.mkdir(parents=True, exist_ok=True)
    if (output / 'prepared.blend').exists() and (output / 'preparation.json').exists():
        row = json.loads((output / 'preparation.json').read_text(encoding='utf-8'))
        assert row['source_sha256'] == hashlib.sha256(source.read_bytes()).hexdigest()
        if row.get('preparation_version',0) >= 2:
            bpy.ops.wm.open_mainfile(filepath=str(output / 'prepared.blend'))
            render_reviews(output, height)
            print('TRIPO_PREPARED ' + json.dumps(row, ensure_ascii=False), flush=True)
            return
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    assert len(meshes) == 1, (character_id, len(meshes))
    obj = meshes[0]
    obj.name = 'TripoCharacter'
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    low = Vector(tuple(min(v.co[i] for v in obj.data.vertices) for i in range(3)))
    high = Vector(tuple(max(v.co[i] for v in obj.data.vertices) for i in range(3)))
    # glTF Y-up imports as Blender Z-up; keep Tripo's original front direction.
    factor = height / (high.z - low.z)
    center = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    for vertex in obj.data.vertices:
        vertex.co = (vertex.co - center) * factor
    obj.data.update()
    original_triangles = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    # glTF duplicates geometric vertices at UV seams. Weld them before collapse;
    # otherwise separate seam boundaries simplify differently and open cracks.
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=height*1e-6)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    mod = obj.modifiers.new('Game triangle budget', 'DECIMATE')
    mod.ratio = min(1.0, budget / original_triangles)
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # Remove degenerate remnants, without voxelizing the texture-bearing surface.
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    degenerate = [f for f in bm.faces if f.calc_area() < 1e-12]
    if degenerate:
        bmesh.ops.delete(bm, geom=degenerate, context='FACES_ONLY')
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons:
        p.use_smooth = True
    obj.data.update()
    texture_rows = []
    for im in list(bpy.data.images):
        if im.size[0] == 0:
            continue
        original = list(im.size)
        if max(im.size) > 2048:
            ratio = 2048 / max(im.size)
            im.scale(round(im.size[0] * ratio), round(im.size[1] * ratio))
        im.pack()
        texture_rows.append({'name': im.name, 'original_size': original, 'size': list(im.size)})
    obj.data.calc_loop_triangles()
    row = dict(id=character_id, preparation_version=2, source=str(source.relative_to(ROOT)).replace('\\', '/'),
               source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
               family=family, height=height, source_triangles=original_triangles,
               triangles=len(obj.data.loop_triangles), vertices=len(obj.data.vertices),
               textures=texture_rows, coordinate_convention='Blender +Z up / -Y front; runtime +Y up / +Z front',
               bounds=[[min(v.co[i] for v in obj.data.vertices) for i in range(3)],
                       [max(v.co[i] for v in obj.data.vertices) for i in range(3)]],
               elapsed_seconds=round(time.time()-started, 2))
    # Save the mesh alone, before adding review cameras/lights.
    bpy.ops.wm.save_as_mainfile(filepath=str(output / 'prepared.blend'))
    (output / 'preparation.json').write_text(json.dumps(row, ensure_ascii=False, indent=2), encoding='utf-8')
    render_reviews(output, height)
    print('TRIPO_PREPARED ' + json.dumps(row, ensure_ascii=False), flush=True)

def render_reviews(output, height):
    camera = setup_render(height)
    for view, location in [('front', (0, -6, height * .52)), ('side', (6, 0, height * .52))]:
        camera.location = location
        camera.rotation_euler = (Vector((0, 0, height * .52)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
        bpy.context.scene.render.filepath = str(output / (view + '_prepared.png'))
        bpy.ops.render.render(write_still=True)

if __name__ == '__main__':
    selected = set(sys.argv[sys.argv.index('--') + 1:]) if '--' in sys.argv else set()
    for p in PROFILES:
        if not selected or p[0] in selected:
            process(p)
