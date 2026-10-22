"""Join the northern school paths to the current map's path footprint."""
import sys,json,math
from pathlib import Path
sys.path.insert(0,str(Path.home()/'.cache/studygame-map-geometry'))
from shapely.geometry import Polygon,box
from shapely.ops import unary_union
import shapely
BASE=Path(__file__).resolve().parent
polys=[]
for pts in json.loads((BASE/'school_road_footprints_v01.json').read_text())['polygons']:
    p=Polygon(pts)
    if not p.is_valid:p=p.buffer(0)
    if not p.is_empty and p.area>.00001:polys.append(p)
road=unary_union(polys).buffer(.45,quad_segs=8).buffer(-.45,quad_segs=8).simplify(.025,preserve_topology=True)
def parts(g):
    if g.is_empty:return []
    if g.geom_type=='Polygon':return [g]
    return [p for x in getattr(g,'geoms',[]) for p in parts(x)]
def plan(g,step=.60):
    vertices=[];faces=[];lookup={};a,b,c,d=g.bounds
    for x in range(math.floor(a/step),math.ceil(c/step)):
        for y in range(math.floor(b/step),math.ceil(d/step)):
            for poly in parts(g.intersection(box(x*step,y*step,(x+1)*step,(y+1)*step))):
                for tri in shapely.constrained_delaunay_triangles(poly).geoms:
                    face=[]
                    for xx,yy in list(tri.exterior.coords)[:3]:
                        key=(round(xx,6),round(yy,6))
                        if key not in lookup:lookup[key]=len(vertices);vertices.append(key)
                        face.append(lookup[key])
                    faces.append(face)
    return {'vertices':vertices,'faces':faces}
result={'road':plan(road),'shoulder':plan(road.buffer(.28).difference(road))}
(BASE/'school_road_plan_v01.json').write_text(json.dumps(result,separators=(',',':')))
print({'connected_road_faces':len(result['road']['faces'])})
