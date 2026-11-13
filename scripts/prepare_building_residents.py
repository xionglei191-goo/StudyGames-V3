"""Create normalized, decimated working copies and identity renders for 34 NPCs.

Run with the installed Blender in background mode. Originals are read-only.
The intake numbers deliberately do not guess character identity from UUID names.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import prepare_tripo_characters as preparation

OUT = ROOT / 'assets/characters/building_residents_v1/intake'
SOURCE = ROOT / 'assets/tripo/building_residents_v01'
OUT.mkdir(parents=True, exist_ok=True)
sources = sorted(SOURCE.glob('*.glb'))
assert len(sources) == 34, f'Expected 34 model files, got {len(sources)}'
catalog = [{'intake_id': f'model_{i:02d}', 'source': p.relative_to(ROOT).as_posix(),
            'source_filename': p.name} for i, p in enumerate(sources, 1)]
(OUT / 'inventory.json').write_text(json.dumps(catalog, indent=2) + '\n', encoding='utf-8')
preparation.OUT = OUT
original_setup = preparation.setup_render


def review_setup(height):
    camera = original_setup(height)
    bpy.context.scene.render.resolution_x = 512
    bpy.context.scene.render.resolution_y = 512
    if hasattr(bpy.context.scene, 'eevee'):
        bpy.context.scene.eevee.taa_render_samples = 16
    return camera


preparation.setup_render = review_setup
selected = set(sys.argv[sys.argv.index('--') + 1:]) if '--' in sys.argv else set()
for row in catalog:
    ident = row['intake_id']
    if selected and ident not in selected:
        continue
    folder = OUT / ident
    complete = all((folder / name).is_file() for name in ['prepared.blend', 'preparation.json', 'front_prepared.png', 'side_prepared.png', 'prepared.glb'])
    if complete:
        print('RESIDENT_INTAKE_CACHED ' + ident, flush=True)
        continue
    preparation.process((ident, 'building_residents_v01/' + row['source_filename'], 2.15, 32000, 'unclassified_biped'))
    bpy.ops.wm.open_mainfile(filepath=str(folder / 'prepared.blend'))
    bpy.ops.export_scene.gltf(filepath=str(folder / 'prepared.glb'), export_format='GLB',
                             export_yup=True, export_animations=False, export_materials='EXPORT')
    print('RESIDENT_INTAKE_DONE ' + ident, flush=True)
