"""Create lightweight scene copies for an 8 GB machine; preserve input GLBs.
Run setup() once, then import_and_prepare('DEFG') in small batches.
"""
import bpy
import importlib.util
import sys
import json
from pathlib import Path
BASE=Path(__file__).resolve().parent


def setup():
    spec=importlib.util.spec_from_file_location('studygame_world',BASE/'world_builder.py')
    w=importlib.util.module_from_spec(spec);sys.modules[spec.name]=w;spec.loader.exec_module(w)
    w.SCENE=bpy.data.scenes[w.SCENE_NAME]
    bpy.context.window.scene=w.SCENE
    w.COLLS={c.name.removeprefix('ALPHA_'):c for c in w.SCENE.collection.children}
    w.MATS={n.removeprefix('ALPHA_MAT_'):m for n,m in bpy.data.materials.items() if n.startswith('ALPHA_MAT_')}
    w.ROUTE_RECORDS=json.loads((BASE/'route_graph.json').read_text())['routes']
    for p in w.PLOTS:p['socket_name']='ALPHA_LANDMARK_'+p['letter']+'_SOCKET'
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':w.enum_set(area.spaces.active.shading,'type','SOLID')
    w.SCENE['output_version']='v02'
    return w


def prepare(letter,max_triangles=50000,max_texture=1024):
    import studygame_world as w
    socket=bpy.data.objects['ALPHA_LANDMARK_'+letter+'_SOCKET']
    if socket.get('map_asset_budget_version')==2:return
    meshes=[o for o in socket.children_recursive if o.type=='MESH' and not o.get('editor_only')]
    if not meshes:return
    records=[];image_copies={};material_copies={}
    for obj in meshes:
        obj.data.calc_loop_triangles();before=len(obj.data.loop_triangles)
        # Decimation affects only the imported map mesh; the source GLB is read-only.
        if before>max_triangles:
            if obj.data.users>1:obj.data=obj.data.copy()
            bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
            allowed=[i.identifier for i in bpy.types.Modifier.bl_rna.properties['type'].enum_items]
            assert 'DECIMATE' in allowed
            mod=obj.modifiers.new('Map scene budget','DECIMATE');mod.ratio=max_triangles/before
            bpy.ops.object.modifier_apply(modifier=mod.name)
        for slot in obj.material_slots:
            mat=slot.material
            if mat is None or not mat.use_nodes:continue
            if mat.name not in material_copies:
                newmat=mat.copy();newmat.name='ALPHA_MAP_'+letter+'_'+mat.name
                for node in newmat.node_tree.nodes:
                    if node.type!='TEX_IMAGE' or not node.image:continue
                    original=node.image
                    if original.name not in image_copies:
                        im=original.copy();im.name='ALPHA_MAP_'+letter+'_'+original.name
                        width,height=im.size
                        if max(width,height)>max_texture:
                            factor=max_texture/max(width,height)
                            im.scale(max(1,round(width*factor)),max(1,round(height*factor)))
                            im.pack()
                        image_copies[original.name]=im
                        # Release the unused original decoded pixel buffer, keeping packed bytes.
                        if original.packed_file or original.source=='FILE':original.buffers_free()
                    node.image=image_copies[original.name]
                material_copies[mat.name]=newmat
            slot.material=material_copies[mat.name]
        obj.data.calc_loop_triangles();after=len(obj.data.loop_triangles)
        obj['map_source_triangles']=before;obj['map_triangles']=after
        records.append({'object':obj.name,'source_triangles':before,'map_triangles':after})
    socket['map_asset_budget_version']=2;socket['map_texture_max_px']=max_texture
    socket['map_geometry_target_triangles']=max_triangles
    socket['map_source_triangles']=sum(r['source_triangles'] for r in records)
    socket['map_triangles']=sum(r['map_triangles'] for r in records)
    socket['map_optimization_record']=json.dumps(records)
    print({'letter':letter,'geometry':records,'textures':[(im.name,list(im.size)) for im in image_copies.values()]})


def import_and_prepare(letters):
    import studygame_world as w
    for letter in letters:
        w.refresh_landmarks(letters=letter)
        prepare(letter)
        pad=bpy.data.objects.get('ALPHA_'+letter+'_Site_Clearing')
        if pad:pad['pending_landmark']=False
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'alphabet_island_layout_v02.blend'),compress=True)
