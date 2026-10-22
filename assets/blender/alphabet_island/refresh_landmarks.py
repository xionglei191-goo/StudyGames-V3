"""Run inside Blender after opening the current alphabet island .blend.
Imports new or changed letter-prefixed GLBs. Does not save or overwrite exports.
"""
import bpy
import importlib.util
import sys
import json
from pathlib import Path

BASE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('studygame_world',BASE/'world_builder.py')
w=importlib.util.module_from_spec(spec);sys.modules[spec.name]=w;spec.loader.exec_module(w)
w.SCENE=bpy.data.scenes.get(w.SCENE_NAME)
if w.SCENE is None:raise RuntimeError('Open the alphabet island .blend before refreshing landmarks.')
bpy.context.window.scene=w.SCENE
w.COLLS={name.removeprefix('ALPHA_'):c for name,c in bpy.data.collections.items() if name.startswith('ALPHA_') and c in list(w.SCENE.collection.children)}
routes=BASE/'route_graph.json'
if routes.exists():w.ROUTE_RECORDS=json.loads(routes.read_text())['routes']
for p in w.PLOTS:
    p['socket_name']='ALPHA_LANDMARK_'+p['letter']+'_SOCKET'
    socket=bpy.data.objects[p['socket_name']]
    p['target_width']=float(socket.get('target_width_m',p['target_width']))
    p['x'],p['y']=socket.location.x,socket.location.y
if int(w.SCENE.get('output_version','v01').removeprefix('v'))>=2:
    spec=importlib.util.spec_from_file_location('studygame_map_prepare',BASE/'prepare_map_assets_v02.py')
    budget=importlib.util.module_from_spec(spec);sys.modules[spec.name]=budget;spec.loader.exec_module(budget)
    for p in w.PLOTS:
        w.refresh_landmarks(letters=p['letter'])
        budget.prepare(p['letter'])
else:
    w.refresh_landmarks()
for p in w.PLOTS:
    pad=bpy.data.objects.get('ALPHA_'+p['letter']+'_Site_Clearing')
    if pad:pad['pending_landmark']=bpy.data.objects[p['socket_name']].get('asset_status')!='imported'
print({'pending':w.SCENE['pending_landmarks'],'changes_are_unsaved':True})
