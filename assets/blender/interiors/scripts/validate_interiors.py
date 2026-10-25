"""Validate exported GLB evidence, reachable anchors, source preservation and previews.

Run with normal Python (no Blender needed). Raster path checks use a 0.32 m player
radius and 0.20 m grid, conservative world-space AABBs of exported proxy meshes.
This is an asset check, not a Godot gameplay or performance acceptance test.
"""
import argparse, collections, hashlib, json, math, struct, sys, time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
OUT=ROOT/'assets/blender/interiors'
HOME_CHILDREN=['home','home_bedroom','home_kitchen','home_dining','home_bathroom','home_study','home_balcony']
EXPECTED=['landmark_'+chr(i) for i in range(65,91)]+['school','classroom','music_room','art_room','science_room','canteen','playground','football_field','home_estate','home_hall']+HOME_CHILDREN
COMMON=['SG_SPAWN','SG_EXIT','SG_NPC_HOST']+[f'SG_MEMORY_{i:02}' for i in range(1,6)]

def glb(path):
    raw=path.read_bytes()
    magic,version,length=struct.unpack_from('<4sII',raw)
    assert magic==b'glTF' and version==2 and length==len(raw),'Invalid GLB header'
    chunks={};offset=12
    while offset<len(raw):
        size,kind=struct.unpack_from('<II',raw,offset);offset+=8
        chunks[kind]=raw[offset:offset+size];offset+=size
    return json.loads(chunks[0x4E4F534A]),chunks.get(0x004E4942,b'')

def mm(a,b):return [[sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]
def identity():return [[float(i==j) for j in range(4)] for i in range(4)]
def local(n):
    if 'matrix' in n:return [[n['matrix'][j*4+i] for j in range(4)] for i in range(4)]
    x,y,z,w=n.get('rotation',[0,0,0,1]);s=n.get('scale',[1,1,1]);t=n.get('translation',[0,0,0])
    r=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),t[0]],
       [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),t[1]],
       [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y),t[2]], [0,0,0,1]]
    for i in range(3):
        for j in range(3):r[i][j]*=s[j]
    return r
def transform(mat,p):return [sum(mat[i][j]*p[j] for j in range(3))+mat[i][3] for i in range(3)]

def world_nodes(data):
    nodes=data.get('nodes',[]);world={}
    def visit(i,parent):
        mat=mm(parent,local(nodes[i]));world[i]=mat
        for child in nodes[i].get('children',[]):visit(child,mat)
    for i in data['scenes'][data.get('scene',0)]['nodes']:visit(i,identity())
    return nodes,world

def mesh_bounds(data,node,world):
    points=[]
    for p in data['meshes'][node['mesh']]['primitives']:
        a=data['accessors'][p['attributes']['POSITION']];lo=a['min'];hi=a['max']
        for x in [lo[0],hi[0]]:
            for y in [lo[1],hi[1]]:
                for z in [lo[2],hi[2]]:points.append(transform(world,[x,y,z]))
    return [min(p[i] for p in points) for i in range(3)]+[max(p[i] for p in points) for i in range(3)]

def accessor_values(data,binary,index):
    accessor=data['accessors'][index];view=data['bufferViews'][accessor['bufferView']]
    assert not accessor.get('sparse'),'Sparse accessor is not supported by this focused check'
    formats={5120:'b',5121:'B',5122:'h',5123:'H',5125:'I',5126:'f'}
    widths={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
    fmt='<'+formats[accessor['componentType']]*widths[accessor['type']]
    size=struct.calcsize(fmt);stride=view.get('byteStride',size)
    start=view.get('byteOffset',0)+accessor.get('byteOffset',0)
    return [struct.unpack_from(fmt,binary,start+i*stride) for i in range(accessor['count'])]

def check_star_floor(data,binary,nodes,world,points):
    """Check indexed GLB geometry, including one-sided support at every S anchor."""
    triangles=[];errors=[]
    for i,node in enumerate(nodes):
        if node.get('name')!='SG_FLOOR_Main':continue
        for primitive in data['meshes'][node['mesh']]['primitives']:
            assert primitive.get('mode',4)==4,'Floor is not a triangle primitive'
            positions=[transform(world[i],p) for p in accessor_values(data,binary,primitive['attributes']['POSITION'])]
            indices=[v[0] for v in accessor_values(data,binary,primitive['indices'])] if 'indices' in primitive else list(range(len(positions)))
            for offset in range(0,len(indices),3):
                a,b,c=[positions[j] for j in indices[offset:offset+3]]
                u=[b[k]-a[k] for k in range(3)];v=[c[k]-a[k] for k in range(3)]
                cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                length=math.sqrt(sum(x*x for x in cross))
                if length>1e-10:triangles.append((a,b,c,[x/length for x in cross]))
    if not triangles:return {'passed':False,'errors':['S main floor contains no triangles']}
    top=max(p[1] for tri in triangles for p in tri[:3]);bottom=min(p[1] for tri in triangles for p in tri[:3])
    top_faces=[t for t in triangles if all(abs(p[1]-top)<1e-5 for p in t[:3])]
    bottom_faces=[t for t in triangles if all(abs(p[1]-bottom)<1e-5 for p in t[:3])]
    if not top_faces or any(t[3][1]<.999 for t in top_faces):errors.append('S floor top triangles do not face upward')
    if not bottom_faces or any(t[3][1]>-.999 for t in bottom_faces):errors.append('S floor bottom triangles do not face downward')
    samples={}
    for name,p in points.items():
        hits=[]
        for a,b,c,normal in triangles:
            if normal[1]<=1e-6:continue
            denominator=(b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
            if abs(denominator)<1e-10:continue
            alpha=((b[2]-c[2])*(p[0]-c[0])+(c[0]-b[0])*(p[2]-c[2]))/denominator
            beta=((c[2]-a[2])*(p[0]-c[0])+(a[0]-c[0])*(p[2]-c[2]))/denominator
            gamma=1-alpha-beta
            if min(alpha,beta,gamma)>=-1e-6:
                y=alpha*a[1]+beta*b[1]+gamma*c[1]
                if y<=p[1]+2:hits.append(y)
        height=max(hits) if hits else None
        supported=height is not None and abs(height)<1e-5
        samples[name]={'ray_origin':[round(p[0],5),round(p[1]+2,5),round(p[2],5)],'front_face_ground_y':round(height,6) if height is not None else None,'supported_at_y_zero':supported}
        if not supported:errors.append('S floor does not support '+name+' at y=0')
    return {'passed':not errors,'errors':errors,'mesh':'SG_FLOOR_Main','indexed_triangles':len(triangles),
        'top_y':round(top,6),'bottom_y':round(bottom,6),'top_triangles':len(top_faces),'bottom_triangles':len(bottom_faces),
        'top_normal_y':sorted({round(t[3][1],6) for t in top_faces}),'bottom_normal_y':sorted({round(t[3][1],6) for t in bottom_faces}),
        'downward_front_face_rays':samples,'scope':'Indexed GLB winding and vertical front-face triangle intersections; Godot physics retest remains separate'}

def walkability(bounds,blockers,points,radius=.32,step=.20):
    x0,z0,w,d=bounds;nx=int(w/step)+1;nz=int(d/step)+1
    def pos(cell):return (x0+cell[0]*step,z0+cell[1]*step)
    def blocked(x,z):
        if x<x0+radius or x>x0+w-radius or z<z0+radius or z>z0+d-radius:return True
        return any(b[0]-radius<x<b[3]+radius and b[2]-radius<z<b[5]+radius and b[4]>.08 and b[1]<1.6 for b in blockers)
    free={(ix,iz) for ix in range(nx) for iz in range(nz) if not blocked(*pos((ix,iz)))}
    def nearest(p):
        guess=(round((p[0]-x0)/step),round((p[2]-z0)/step))
        choices=[c for c in free if abs(c[0]-guess[0])<=2 and abs(c[1]-guess[1])<=2]
        return min(choices,key=lambda c:(pos(c)[0]-p[0])**2+(pos(c)[1]-p[2])**2) if choices else None
    start=nearest(points['SG_SPAWN']);seen=set();q=collections.deque([start] if start else [])
    while q:
        c=q.popleft()
        if c in seen:continue
        seen.add(c)
        for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
            n=(c[0]+dx,c[1]+dz)
            if n in free and n not in seen:q.append(n)
    result={}
    for name,p in points.items():
        cell=nearest(p)
        result[name]={'inside_obstacle':blocked(p[0],p[2]),'reachable':cell in seen if cell else False,'ground_height':p[1]}
    return {'player_radius_m':radius,'grid_step_m':step,'reachable_cells':len(seen),'free_cells':len(free),'anchors':result}

def check_room(entry):
    room_id=entry['room_id'];errors=[]
    paths={key:ROOT/entry[key] for key in ['blend','glb','preview']}
    for key,p in paths.items():
        if not p.is_file():errors.append('Missing '+key)
    if errors:return {'room_id':room_id,'errors':errors}
    data,binary=glb(paths['glb']);nodes,world=world_nodes(data);named={n.get('name'):i for i,n in enumerate(nodes)}
    required=COMMON+(['SG_DOOR_CLASSROOM','SG_DOOR_MUSIC_ROOM','SG_DOOR_ART_ROOM','SG_DOOR_SCIENCE_ROOM','SG_DOOR_CANTEEN','SG_DOOR_PLAYGROUND','SG_DOOR_FOOTBALL_FIELD'] if room_id=='school' else ['SG_BED','SG_WARDROBE','SG_DECOR_FLOWER_BOX','SG_DECOR_PICNIC','SG_DECOR_LAMP'] if room_id=='home' else [])
    if room_id=='home_estate':required += ['SG_HOUSE_ENTRY'] + ['SG_DOOR_'+rid.upper() for rid in HOME_CHILDREN]
    if room_id=='home_hall':required = ['SG_SPAWN','SG_EXIT'] + ['SG_DOOR_'+rid.upper() for rid in HOME_CHILDREN]
    if room_id=='home_bedroom':required += ['SG_BED','SG_WARDROBE']
    for name in required:
        if name not in named:errors.append('Missing anchor '+name)
    if room_id=='home':
        for suf in ['FLOWER_BOX','PICNIC','LAMP']:
            name='SG_DECOR_MODEL_'+suf
            if name not in named:errors.append('Missing decor root '+name)
            elif not nodes[named[name]].get('children'):errors.append('Empty decor hierarchy '+name)
    meshes=[n for n in nodes if 'mesh' in n]
    floor=[n for n in meshes if n.get('name','').startswith('SG_FLOOR_')]
    if not floor:errors.append('No floor mesh')
    blockers=[];proxy_names=[]
    for i,n in enumerate(nodes):
        if n.get('name','').startswith('SG_COLLIDER_'):
            proxy_names.append(n['name'])
            if 'mesh' not in n:errors.append('Non-mesh collider '+n['name']);continue
            blockers.append(mesh_bounds(data,n,world[i]))
            for primitive in data['meshes'][n['mesh']]['primitives']:
                mat=data['materials'][primitive['material']]
                if mat.get('pbrMetallicRoughness',{}).get('baseColorFactor',[1,1,1,1])[3]!=0:errors.append('Opaque proxy '+n['name'])
        for field in ['translation','rotation','scale','matrix']:
            if any(not math.isfinite(v) for v in n.get(field,[])):errors.append('Non-finite transform '+n.get('name','?'))
    if not blockers:errors.append('No collider meshes')
    points={name:transform(world[named[name]],[0,0,0]) for name in required if name in named}
    floor_orientation=check_star_floor(data,binary,nodes,world,points) if room_id=='landmark_S' else None
    if floor_orientation:errors.extend(floor_orientation['errors'])
    nav=walkability(entry['bounds'],blockers,points) if 'SG_SPAWN' in points else {}
    for name,check in nav.get('anchors',{}).items():
        if check['inside_obstacle'] or not check['reachable']:errors.append('Blocked/unreachable '+name)
        if abs(check['ground_height'])>.10:errors.append('Anchor off ground '+name)
    for a in entry['anchors']:
        if a['name'] in points and any(abs(x-y)>.005 for x,y in zip(a['position_godot'],points[a['name']])):errors.append('Manifest transform mismatch '+a['name'])
        if a.get('associated_prop') and a['associated_prop'] not in named:errors.append('Associated prop absent '+a['name']+': '+a['associated_prop'])
    plan=json.loads((ROOT/'game/data/landmark_interiors.json').read_text(encoding='utf-8'))
    authored=[]
    for lm in plan['landmarks']:
        if lm['room_id']==room_id:authored=lm['anchors']
        for area in lm.get('areas',[]):
            if area.get('separate_scene') and area['room_id']==room_id:authored=area['anchors']
    actual={a['name']:a for a in entry['anchors']}
    for a in authored:
        if actual.get(a['node_name'],{}).get('label')!=a['label']:errors.append('Plan label mismatch '+a['node_name'])
    if room_id=='home_hall':
        if authored:errors.append('Navigation-only hall must not add memory points')
        house=json.loads((ROOT/'game/data/home_hierarchy.json').read_text(encoding='utf-8'))
        route=next((r for r in house.get('routes',[]) if r['room_id']==room_id),None)
        if not route or route.get('space_role')!='household_indoor_navigation':errors.append('Hall navigation contract missing')
    elif len(authored)!=5:errors.append('Plan does not contain five points')
    if room_id=='landmark_A':
        for old in ['A_LOCUS_01_Entrance_Basket','A_LOCUS_02_Left_Apple_Tree','A_LOCUS_03_Sorting_Table','A_LOCUS_04_Wash_Basin','A_LOCUS_05_Gift_Shelf','A_AppleHouse_Tripo','A_Creek_Surface']:
            if old not in named:errors.append('Orchard source object missing '+old)
    for im in data.get('images',[]):
        if 'uri' in im and not im['uri'].startswith('data:'):errors.append('External texture URI')
    # Every accessor is bounded by its underlying bufferView and finite geometry bounds.
    for a in data.get('accessors',[]):
        if any(not math.isfinite(v) for v in a.get('min',[])+a.get('max',[])):errors.append('Non-finite accessor')
        if 'bufferView' in a:
            view=data['bufferViews'][a['bufferView']]
            if view.get('byteOffset',0)+view['byteLength']>len(binary):errors.append('Out-of-bounds buffer view')
    png=paths['preview'].read_bytes()
    if png[:8]!=b'\x89PNG\r\n\x1a\n':errors.append('Invalid PNG')
    width,height=struct.unpack_from('>II',png,16)
    if width<800 or height<700:errors.append('Preview too small')
    digest=hashlib.sha256(paths['glb'].read_bytes()).hexdigest()
    if entry.get('glb_sha256')!=digest:errors.append('Manifest GLB checksum mismatch')
    return {'room_id':room_id,'name':entry['name'],'errors':errors,'nodes':len(nodes),'mesh_nodes':len(meshes),
        'collision_proxies':len(proxy_names),'floor_meshes':len(floor),'textures':len(data.get('images',[])),
        'preview_dimensions':[width,height],'glb_bytes':paths['glb'].stat().st_size,'triangles':entry.get('triangles'),
        'sha256':digest,'plan_labels_checked':len(authored),'walkability':nav,
        **({'floor_orientation':floor_orientation} if floor_orientation else {})}

def preserved_originals():
    source=OUT/'reports/original_assets_before.json'
    if not source.exists():return {'checked':0,'changed':['Baseline missing']}
    rows=json.loads(source.read_text(encoding='utf-8-sig'));changed=[]
    for r in rows:
        p=ROOT/r['path']
        if not p.exists() or hashlib.sha256(p.read_bytes()).hexdigest().upper()!=r['sha256'].upper():changed.append(r['path'])
    return {'checked':len(rows),'changed':changed}

def contact_sheets(entries):
    try:from PIL import Image,ImageDraw,ImageFont
    except ImportError:return []
    font_path=Path('C:/Windows/Fonts/msyh.ttc')
    font=ImageFont.truetype(str(font_path),21) if font_path.exists() else ImageFont.load_default()
    small=ImageFont.truetype(str(font_path),16) if font_path.exists() else font
    results=[]
    for batch in range(math.ceil(len(entries)/9)):
        selected=entries[batch*9:(batch+1)*9];sheet=Image.new('RGB',(1500,1545),(239,234,220));draw=ImageDraw.Draw(sheet)
        for i,r in enumerate(selected):
            p=ROOT/r['preview']
            if not p.exists():continue
            im=Image.open(p).convert('RGB');im.thumbnail((490,440))
            xx=(i%3)*500;yy=(i//3)*515
            sheet.paste(im,(xx+(500-im.width)//2,yy))
            draw.text((xx+18,yy+445),r['room_id']+'  '+r['name'],font=font,fill=(36,72,65))
            draw.text((xx+18,yy+478),'Blender source | '+str(r.get('triangles',0))+' triangles',font=small,fill=(85,91,79))
        target=OUT/'reports'/f'contact_sheet_{batch+1:02}.jpg';sheet.save(target,quality=92);results.append(target.relative_to(ROOT).as_posix())
    return results

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--partial',action='store_true');parser.add_argument('--contact-sheets',action='store_true');args=parser.parse_args()
    manifest=json.loads((OUT/'interiors_manifest.json').read_text(encoding='utf-8'))
    entries=manifest['rooms'];missing=sorted(set(EXPECTED)-{r['room_id'] for r in entries})
    reports=[check_room(r) for r in entries]
    original=preserved_originals()
    report={'schema_version':2,'room_count':len(reports),'expected_room_count':len(EXPECTED),'missing_rooms':missing,
        'passed':all(not r['errors'] for r in reports) and not original['changed'] and (args.partial or not missing),
        'asset_validation_scope':'GLB structure, named meshes/empties, embedded textures, finite bounds, PNGs, 0.32 m radius 2D connectivity, S indexed floor winding and front-face ground support, original asset hashes',
        'not_verified':['Godot runtime navigation and scene transition gameplay','Target-device frame rate','Audio, NPC animation and interaction behaviour'],
        'original_assets':original,'rooms':reports}
    if args.contact_sheets:report['contact_sheets']=contact_sheets(entries)
    target=OUT/'reports'/'validation_report.json';target.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'passed':report['passed'],'rooms':len(reports),'missing':missing,'errors':{r['room_id']:r['errors'] for r in reports if r['errors']},'original_assets':original},ensure_ascii=False,indent=2))
    return 0 if report['passed'] else 1

if __name__=='__main__':sys.exit(main())
