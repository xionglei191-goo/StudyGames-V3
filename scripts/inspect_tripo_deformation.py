import bpy,sys,json
import numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from rig_tripo_characters import layout,pose_at,texture_data,mesh_arrays,CONTRACT
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/characters/tripo_v1/textbook_jim/rigged.blend'))
arm=bpy.data.objects['SemanticRig'];obj=bpy.data.objects['Body']
p,pts,parents,rest,bones,arms,legs=layout('textbook_jim','wheelchair',2.05)
pose_at(arm,bones,rest,'wheelchair',CONTRACT['families']['wheelchair']['clips']['give_item'],1.1)
rgb,_=texture_data(obj)
xyz=mesh_arrays(obj)/2.05
ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
rows=[]
for edge in obj.data.edges:
    a,b=edge.vertices
    original=(obj.data.vertices[a].co-obj.data.vertices[b].co).length
    posed=(ev.vertices[a].co-ev.vertices[b].co).length
    if posed>.20 and posed>original*3:
        vertices=[]
        for i in [a,b]:
            weights=[(obj.vertex_groups[g.group].name,round(g.weight,3)) for g in obj.data.vertices[i].groups if g.weight>.001]
            vertices.append({'id':int(i),'xyz':xyz[i].round(3).tolist(),'rgb':rgb[i].round(3).tolist(),'weights':weights})
        rows.append({'original':original,'posed':posed,'vertices':vertices})
rows.sort(key=lambda row:row['posed'],reverse=True)
print('STRETCHED_EDGE_COUNT',len(rows),flush=True)
print(json.dumps(rows[:8]),flush=True)
