import bpy,bmesh,sys,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from rig_tripo_characters import B2G
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/characters/tripo_v1/textbook_jim/rigged.blend'))
obj=bpy.data.objects['Body'];bm=bmesh.new();bm.from_mesh(obj.data)
edges=set(e for e in bm.edges if e.is_boundary)
rows=[]
while edges:
    todo=[edges.pop()];component=[]
    while todo:
        e=todo.pop();component.append(e)
        for v in e.verts:
            for linked in v.link_edges:
                if linked in edges:edges.remove(linked);todo.append(linked)
    vertices={v for e in component for v in e.verts}
    coordinates=[B2G@v.co/2.05 for v in vertices]
    center=sum(coordinates,coordinates[0]*0)/len(coordinates)
    if .29<center.y<.55:
        rows.append(dict(edges=len(component),vertices=len(vertices),center=list(center),minimum=[min(c[i] for c in coordinates) for i in range(3)],maximum=[max(c[i] for c in coordinates) for i in range(3)],degrees=sorted(set(sum(e in component for e in v.link_edges) for v in vertices))))
print('BOUNDARY_COMPONENTS',json.dumps(rows))
bm.free()
