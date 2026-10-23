"""Export clean, unrigged Tripo humanoids for a Mixamo comparison.

Run with Blender --background --factory-startup --python this_file.py.
The original Tripo files and the current local binding candidates are preserved.
"""
import bpy
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from prepare_tripo_characters import PROFILES

SOURCE = ROOT / 'assets/characters/tripo_v1'
OUTPUT = ROOT / 'assets/characters/mixamo_v1/input'
OUTPUT.mkdir(parents=True, exist_ok=True)
records = []
for character_id, source_name, height, budget, family in PROFILES:
    if family != 'humanoid':
        continue
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE / character_id / 'prepared.blend'))
    bpy.ops.object.select_all(action='DESELECT')
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    assert len(meshes) == 1, character_id
    obj = meshes[0]
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    assert obj.parent is None and not any(m.type == 'ARMATURE' for m in obj.modifiers)
    output = OUTPUT / (character_id + '.fbx')
    bpy.ops.export_scene.fbx(
        filepath=str(output), use_selection=True, object_types={'MESH'},
        use_mesh_modifiers=True, bake_anim=False, add_leaf_bones=False,
        path_mode='COPY', embed_textures=True, axis_forward='-Z', axis_up='Y',
        use_custom_props=False,
    )
    records.append({'id': character_id, 'file': str(output.relative_to(ROOT)).replace('\\', '/'),
                    'bytes': output.stat().st_size, 'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
                    'source': 'assets/tripo/' + source_name, 'rigged': False, 'uploaded': False})
    print('MIXAMO_INPUT ' + json.dumps(records[-1]), flush=True)
(OUTPUT / 'manifest.json').write_text(json.dumps({'characters': records, 'status': 'prepared_not_uploaded'},
                                              ensure_ascii=False, indent=2), encoding='utf-8')
