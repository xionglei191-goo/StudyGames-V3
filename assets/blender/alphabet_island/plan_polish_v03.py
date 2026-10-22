"""Generate rounded 2D path/courtyard meshes for Blender projection.
Run with the bundled Python and Shapely 2.1.2; does not change source assets.
"""
import sys,json,math,random
from pathlib import Path
sys.path.insert(0,str(Path.home()/'.cache/studygame-map-geometry'))
from shapely.geometry import LineString,Point,Polygon,box
from shapely.ops import unary_union
import shapely
BASE=Path(__file__).resolve().parent
routes=json.loads((BASE/'route_graph_v02.json').read_text())['routes']
manifest=json.loads((BASE/'placement_manifest_v02.json').read_text())['landmarks']
layout=json.loads((BASE/'layout.json').read_text())

def curve(points,steps=20):
    out=[]
    for i in range(len(points)-1):
        a,b,c,d=points[max(0,i-1)],points[i],points[i+1],points[min(i+2,len(points)-1)]
        for j in range(steps):
            t=j/steps
            out.append([.5*((2*b[k])+(-a[k]+c[k])*t+(2*a[k]-5*b[k]+4*c[k]-d[k])*t*t+(-a[k]+3*b[k]-3*c[k]+d[k])*t*t*t) for k in range(2)])
    return out+[list(points[-1])]

def parts(geom):
    if geom.is_empty:return []
    if geom.geom_type=='Polygon':return [geom]
    return [p for g in getattr(geom,'geoms',[]) for p in parts(g)]

def mesh_plan(geom,step=.8):
    verts=[];faces=[];lookup={}
    if geom.is_empty:return {'vertices':[],'faces':[]}
    minx,miny,maxx,maxy=geom.bounds
    for ix in range(math.floor(minx/step),math.ceil(maxx/step)):
        for iy in range(math.floor(miny/step),math.ceil(maxy/step)):
            cell=geom.intersection(box(ix*step,iy*step,(ix+1)*step,(iy+1)*step))
            for poly in parts(cell):
                for tri in shapely.constrained_delaunay_triangles(poly).geoms:
                    indices=[]
                    for x,y in list(tri.exterior.coords)[:3]:
                        key=(round(x,6),round(y,6))
                        if key not in lookup:lookup[key]=len(verts);verts.append(key)
                        indices.append(lookup[key])
                    faces.append(indices)
    return {'vertices':verts,'faces':faces}

def rings(geom):
    return [list(r.coords) for p in parts(geom) for r in [p.exterior,*p.interiors]]

roads=[]
orchard=BASE/'orchard_path_footprints_v03.json'
if orchard.exists():
    for pts in json.loads(orchard.read_text())['polygons']:
        poly=Polygon(pts)
        if not poly.is_valid:poly=poly.buffer(0)
        # The standalone orchard's former south exit would descend into the inlet.
        # The island already connects A to the raised pier along the eastern route.
        poly=poly.intersection(box(-64,-31.5,-38,-10))
        if not poly.is_empty and poly.area>.0001:roads.append(poly)
for r in routes:
    if r['type']=='path':roads.append(LineString(curve(r['control_points'])).buffer(r['width']*.46,quad_segs=8))
for p in manifest:
    if p['letter'] in 'AB':continue
    x=p['x'];fy=p['bounds_world']['min'][1]
    roads.append(LineString([(x,p['entrance'][1]),(x,fy+.35)]).buffer(1.15,quad_segs=10))
road=unary_union(roads).buffer(.8,quad_segs=8).buffer(-.8,quad_segs=8)
river=LineString(curve(layout['river'])).buffer(3.05,quad_segs=8)
road=road.difference(river).simplify(.035,preserve_topology=True)
# Rounded courtyards respond to the actual building footprint and local theme.
courts=[]
for p in manifest:
    l=p['letter']
    if l=='B':continue
    mn,mx=p['bounds_world']['min'],p['bounds_world']['max'];x,y=p['x'],p['y']
    if l in 'ACEFMNOPUV':
        rx=p['target_width']/2+1.15;ry=(mx[1]-mn[1])/2+1.35
        pts=[]
        for i in range(64):
            a=i*math.tau/64;r=1+.055*math.sin(a*3+ord(l))+.035*math.cos(a*5)
            pts.append((x+rx*math.cos(a)*r,y-.3+ry*math.sin(a)*r))
        shape=Polygon(pts).buffer(.2).buffer(-.2)
    else:
        shape=box(mn[0]-.65,mn[1]-1.9,mx[0]+.65,mx[1]+.4).buffer(1.1,quad_segs=10).buffer(-.45,quad_segs=8)
    if l in 'AMNOPEF':style='garden'
    elif l in 'D L X Y'.split():style='wood'
    elif l=='V':style='volcanic'
    elif l in 'CHI Q'.replace(' ',''):style='brick'
    elif l=='W':style='coastal'
    else:style='stone'
    court={'letter':l,'style':style,'rings':rings(shape),'mesh':mesh_plan(shape,.75)}
    # Individual inlaid pavers/boards are joined into one mesh in Blender.
    tiles=[]
    if style in ['brick','stone','wood','coastal']:
        sx,sy=(.76,.36) if style=='brick' else ((.38,2.0) if style=='wood' else (.82,.64))
        a,b,c,d=shape.bounds
        body=box(mn[0]+.2,mn[1]+.25,mx[0]-.2,mx[1]-.25)
        field=shape.buffer(-.20).difference(body)
        for j in range(math.floor(b/sy),math.ceil(d/sy)):
            shift=(j%2)*sx*.5
            for i in range(math.floor(a/sx)-1,math.ceil(c/sx)+1):
                tile=box(i*sx+shift+.025,j*sy+.025,(i+1)*sx+shift-.025,(j+1)*sy-.025)
                clipped=tile.intersection(field)
                for poly in parts(clipped):
                    if poly.area>.045:tiles.append(list(poly.exterior.coords)[:-1])
    court['tiles']=tiles;courts.append(court)
allcourts=unary_union([Polygon(c['rings'][0]) for c in courts])
# Planting and curb guides exclude the open entry surfaces.
road_only=road.difference(allcourts.buffer(.1))
edge=road.buffer(.28).difference(road)
result={'version':3,'road':mesh_plan(road,.65),'road_edge':mesh_plan(edge,.6),'road_rings':rings(road_only),'courts':courts,'road_area_m2':road.area,'source':'Rounded union of existing route controls; landmark positions unchanged.'}
(BASE/'polish_plan_v03.json').write_text(json.dumps(result,separators=(',',':')))
print({'road_vertices':len(result['road']['vertices']),'road_faces':len(result['road']['faces']),'courtyards':len(courts),'paver_tiles':sum(len(c['tiles']) for c in courts),'plan_bytes':(BASE/'polish_plan_v03.json').stat().st_size})
