import bpy,bmesh,sys,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from rig_tripo_characters import B2G
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/characters/tripo_v1/textbook_jim/rigged.blend'))
for name in ['Body','Wheelchair']:
    obj=bpy.data.objects[name]
    bm=bmesh.new();bm.from_mesh(obj.data)
    boundaries=[];caps=[]
    for edge in bm.edges:
        if edge.is_boundary:
            pos=B2G@((edge.verts[0].co+edge.verts[1].co)*.5)/2.05
            if .2<pos.y<.55 and abs(pos.x)<.18 and pos.z>-.15:boundaries.append([round(v,4) for v in pos])
    for face in bm.faces:
        if face.material_index>0:
            pos=B2G@face.calc_center_median()/2.05
            caps.append(dict(material=face.material_index,vertices=len(face.verts),center=[round(v,4) for v in pos],normal=[round(v,4) for v in B2G.to_3x3()@face.normal],area=face.calc_area()))
    print(name,'CONTACT_BOUNDARIES',len(boundaries),json.dumps(boundaries[:12]))
    print(name,'CAPS',json.dumps(caps))
    selected=[]
    for edge in bm.edges:
        pos=B2G@((edge.verts[0].co+edge.verts[1].co)*.5)/2.05
        if edge.is_boundary and .30<pos.y<.44 and pos.z>.02 and .05<abs(pos.x)<.18:selected.append(edge)
    extra=bmesh.ops.holes_fill(bm,edges=selected,sides=0)['faces']
    print(name,'EXTRA_CAPS',len(extra),json.dumps([[round(v,4) for v in B2G@face.calc_center_median()/2.05] for face in extra]))
    bm.free()
