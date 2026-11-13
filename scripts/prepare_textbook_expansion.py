"""Normalize the 48+8 user-supplied GLBs and render identity views.

Originals are read-only here. Intake IDs are deliberately independent of identity.
Run with Blender -b -t 3 --python this_file.py -- [intake IDs].
"""
from pathlib import Path
import hashlib
import json
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import prepare_tripo_characters as preparation

OUT = ROOT / 'assets/characters/textbook_expansion_v1/intake'
SOURCE = ROOT / 'assets/tripo/generation_selection_20261112'
OUT.mkdir(parents=True, exist_ok=True)
inventory_file = OUT / 'inventory.json'
if inventory_file.exists():
    inventory = json.loads(inventory_file.read_text(encoding='utf-8'))
else:
    inventory = []
    for batch, prefix, count in [('01_priority_48', 'p', 48), ('02_optional_12', 'o', 8)]:
        files = sorted((SOURCE / batch).glob('*.glb'))
        assert len(files) == count, (batch, len(files), count)
        for i, path in enumerate(files, 1):
            inventory.append(dict(intake_id=f'{prefix}{i:02d}', batch=batch,
                source=path.relative_to(ROOT).as_posix(), original_filename=path.name,
                source_sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    inventory_file.write_text(json.dumps(inventory, indent=2) + '\n', encoding='utf-8')

preparation.OUT = OUT
def render_reviews(output, height):
    obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
    maximum = max(obj.dimensions)
    camera = preparation.setup_render(maximum)
    scene = bpy.context.scene
    scene.render.resolution_x = scene.render.resolution_y = 512
    if hasattr(scene, 'eevee'): scene.eevee.taa_render_samples = 12
    target = Vector((0, 0, height * .5))
    for name, direction in [('front',(0,-1,0)), ('side',(1,0,0)), ('angle',(.75,-1,.18))]:
        camera.location = target + Vector(direction) * maximum * 3
        camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath = str(output / f'{name}_prepared.png')
        bpy.ops.render.render(write_still=True)
preparation.render_reviews = render_reviews

selected = set(sys.argv[sys.argv.index('--')+1:]) if '--' in sys.argv else set()
for row in inventory:
    ident = row['intake_id']
    if selected and ident not in selected: continue
    folder = OUT / ident
    if all((folder/n).is_file() for n in ['prepared.blend','preparation.json','front_prepared.png','side_prepared.png','angle_prepared.png','prepared.glb']):
        print('EXPANSION_INTAKE_CACHED ' + ident, flush=True)
        continue
    path = ROOT / row['source']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == row['source_sha256']
    preparation.process((ident, path.relative_to(ROOT/'assets/tripo').as_posix(), 2.15, 32000, 'unclassified'))
    bpy.ops.wm.open_mainfile(filepath=str(folder/'prepared.blend'))
    bpy.ops.export_scene.gltf(filepath=str(folder/'prepared.glb'), export_format='GLB',
                             export_yup=True, export_animations=False, export_materials='EXPORT')
    print('EXPANSION_INTAKE_DONE ' + ident, flush=True)
