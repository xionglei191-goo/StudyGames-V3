"""Second art pass: edit saved round-one Blender scenes, preserving gameplay geometry.
Run with blender -b FIRST.blend -P this.py -- --room ID --out NEXT.blend --evidence DIR.
Every new surface is original DCC geometry, not a generated presentation image.
"""
import bpy, bmesh, math, json, hashlib, argparse, sys, random, re
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
P=argparse.ArgumentParser();P.add_argument('--room',required=True);P.add_argument('--out',required=True);P.add_argument('--evidence',required=True)
A=P.parse_args(sys.argv[sys.argv.index('--')+1:]);ROOM=A.room;OUT=Path(A.out);EV=Path(A.evidence)
scene=bpy.context.scene;bpy.context.view_layer.update();BASE=list(scene.objects)
C={'room_id':ROOM,'source_blend':bpy.data.filepath,'source_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),'revision':'cloud-09','reshaped':[],'details':[],'surface_changes':[]}

def bounds(o):
 p=[o.matrix_world@Vector(v) for v in o.bound_box]
 return Vector([min(v[i] for v in p) for i in range(3)]),Vector([max(v[i] for v in p) for i in range(3)])

def guard():
 roots=[o for o in BASE if o.name.startswith(('SG_','COL_','HOME_TASK_')) or o.get('sg_collision','none')!='none']
 obs={o.name:o for r in roots for o in [r,*r.children_recursive]};res={}
 for n,o in obs.items():
  h=hashlib.sha256();h.update(str(o.parent.name if o.parent else None).encode());h.update(str([list(x) for x in o.matrix_world]).encode());h.update(str(sorted((k,str(v)) for k,v in o.items())).encode())
  if o.type=='MESH':h.update(str([tuple(v.co) for v in o.data.vertices]).encode());h.update(str([tuple(p.vertices) for p in o.data.polygons]).encode())
  res[n]=h.hexdigest()
 return res
G=guard();M={};B={}
palette={'ivory':((.82,.75,.57),.8,0),'porcelain':((.82,.86,.76),.3,0),'oak':((.38,.19,.065),.64,0),'honey':((.64,.38,.14),.66,0),'teal':((.035,.23,.22),.56,0),'sage':((.22,.40,.28),.78,0),'linen':((.78,.65,.43),.95,0),'clay':((.59,.19,.095),.79,0),'terracotta':((.37,.095,.045),.86,0),'brass':((.55,.34,.095),.29,.65),'glass':((.13,.40,.44),.22,.1),'leaf':((.11,.29,.055),.9,0),'leaf_sun':((.27,.43,.10),.9,0),'leaf_shade':((.055,.17,.045),.93,0),'earth':((.29,.18,.085),.98,0),'sand':((.60,.46,.27),.96,0),'stone':((.42,.45,.35),.9,0),'berry':((.51,.10,.12),.63,0),'butter':((.91,.62,.22),.75,0),'ink':((.035,.085,.085),.65,0)}
for key,(col,r,metal) in palette.items():
 m=bpy.data.materials.new('CF09_'+key);m.diffuse_color=(*col,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1);p.inputs['Roughness'].default_value=r;p.inputs['Metallic'].default_value=metal;M[key]=m

# Reuse the project's neutral leaf surface language; avoid visible periodic canopy waves.
neutral=bpy.data.images.load(str(Path(__file__).resolve().parents[1]/'game/assets/world_refresh_v3/foliage_detail.png'),check_existing=False)
neutral_pixels=list(neutral.pixels);bpy.data.images.remove(neutral)
# Small original grain textures are packed and exported as ordinary glTF PBR images.
# This adds a restrained material response at close range without changing the lighting.
for key in ['oak','honey','linen','leaf','leaf_sun','leaf_shade']:
 image=bpy.data.images.new('CF09_'+key+'_surface',width=256,height=256,alpha=True)
 col=palette[key][0];pixels=[]
 # Packed PNG base-color samples are sRGB; encode linear foliage palette values.
 if key.startswith('leaf'):col=tuple(12.92*c if c<=.0031308 else 1.055*c**(1/2.4)-.055 for c in col)
 for y in range(256):
  for x in range(256):
   if key.startswith('leaf'):
    index=(y*256+x)*4;neutral_value=sum(neutral_pixels[index:index+3])/3;v=.98+.30*(neutral_value-.95)
   elif key=='linen':v=.97+.024*math.cos(x*math.pi)+.024*math.cos(y*math.pi)+.014*math.sin(x*1.73+y*.87)
   else:v=.96+.045*math.sin(y*.43+1.6*math.sin(x*.025))+.023*math.sin(y*1.7+.4*math.sin(x*.08))
   pixels.extend([min(1,max(0,c*v)) for c in col]+[1])
 image.pixels.foreach_set(pixels);image.pack()
 m=M[key];node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
 m.node_tree.links.new(node.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])

leaf_normal=bpy.data.images.load(str(Path(__file__).resolve().parents[1]/'game/assets/world_refresh_v3/foliage_normal.png'),check_existing=False);leaf_normal.colorspace_settings.name='Non-Color';leaf_normal.pack()
for key in ['leaf','leaf_sun','leaf_shade']:
 m=M[key];node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=leaf_normal;n=m.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.08;m.node_tree.links.new(node.outputs['Color'],n.inputs['Color']);m.node_tree.links.new(n.outputs['Normal'],m.node_tree.nodes.get('Principled BSDF').inputs['Normal'])

def add(cat,key,v,f,smooth=False):
 a=B.setdefault((cat,key,smooth),[[],[]]);off=len(a[0]);a[0].extend([tuple(x) for x in v]);a[1].extend([tuple(off+i for i in face) for face in f])

def cubegeo(pos,size,r=0):
 bm=bmesh.new();bmesh.ops.create_cube(bm,size=1)
 for v in bm.verts:v.co=Vector([pos[i]+v.co[i]*size[i] for i in range(3)])
 if r>0:bmesh.ops.bevel(bm,geom=list(bm.edges),offset=min(r,min(size)*.45),segments=3,affect='EDGES',profile=.5)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.verts.ensure_lookup_table();bm.verts.index_update()
 v=[tuple(v.co) for v in bm.verts];f=[tuple(v.index for v in p.verts) for p in bm.faces];bm.free();return v,f

def pillgeo(pos,size,radius=.25):
 # Rounded footprint and a separate small edge roll; thin tabletops keep broad corner curves.
 w,d,h=size;e=min(.025,h*.22);r=min(radius,w*.38,d*.38);verts=[];N=24
 for z,inset in [(-h/2,e),(-h/2+e,0),(h/2-e,0),(h/2,e)]:
  ww=w/2-inset;dd=d/2-inset;rr=max(.002,r-inset)
  for cx,cy,angle in [(ww-rr,dd-rr,0),(-ww+rr,dd-rr,90),(-ww+rr,-dd+rr,180),(ww-rr,-dd+rr,270)]:
   for i in range(6):
    t=math.radians(angle+i*90/5);verts.append((pos[0]+cx+rr*math.cos(t),pos[1]+cy+rr*math.sin(t),pos[2]+z))
 faces=[tuple(range(N-1,-1,-1)),tuple(range(N*3,N*4))]
 faces.extend((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i) for j in range(3) for i in range(N))
 return verts,faces

def box(cat,key,pos,size,r=.015):add(cat,key,*cubegeo(pos,size,r))
def tube(cat,key,a,b,r,n=12,r2=None):
 a,b=Vector(a),Vector(b);axis=b-a
 if axis.length<1e-5:return
 q=axis.to_track_quat('Z','Y');r2=r if r2 is None else r2
 v=[p+q@Vector((rad*math.cos(t*math.tau/n),rad*math.sin(t*math.tau/n),0)) for p,rad in [(a,r),(b,r2)] for t in range(n)]
 f=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 add(cat,key,v,f,True)
def ellipsoid(cat,key,pos,rad,segments=16,rings=10):
 p=Vector(pos);v=[p+Vector((0,0,-rad[2]))]
 for j in range(1,rings):
  e=-math.pi/2+math.pi*j/rings
  for i in range(segments):
   a=math.tau*i/segments;v.append(p+Vector((rad[0]*math.cos(a)*math.cos(e),rad[1]*math.sin(a)*math.cos(e),rad[2]*math.sin(e))))
 top=len(v);v.append(p+Vector((0,0,rad[2])));f=[(0,1+(i+1)%segments,1+i) for i in range(segments)]
 for j in range(rings-2):
  for i in range(segments):
   a=1+j*segments+i;b=1+j*segments+(i+1)%segments;f.append((a,b,b+segments,a+segments))
 f.extend((1+(rings-2)*segments+i,1+(rings-2)*segments+(i+1)%segments,top) for i in range(segments));add(cat,key,v,f,True)
def lathe(cat,key,pos,profile,n=24):
 x,y,z=pos;v=[];rings=[];f=[]
 for r,h in profile:
  ids=[]
  for i in range(1 if r<1e-7 else n):
   ids.append(len(v));v.append((x+r*math.cos(i*math.tau/n),y+r*math.sin(i*math.tau/n),z+h))
  rings.append(ids)
 for a,b in zip(rings,rings[1:]):
  if len(a)==1 and len(b)>1:f.extend((a[0],b[(i+1)%n],b[i]) for i in range(n))
  elif len(b)==1 and len(a)>1:f.extend((a[i],a[(i+1)%n],b[0]) for i in range(n))
  elif len(a)>1 and len(b)>1:f.extend((a[i],a[(i+1)%n],b[(i+1)%n],b[i]) for i in range(n))
 add(cat,key,v,f,True)
def ring(cat,key,center,radius,axis='Z',thick=.035):
 c=Vector(center);v=[];N=32;K=8
 for i in range(N):
  a=i*math.tau/N
  for j in range(K):
   b=j*math.tau/K;p=Vector(((radius+thick*math.cos(b))*math.cos(a),(radius+thick*math.cos(b))*math.sin(a),thick*math.sin(b)))
   if axis=='Y':p=Vector((p.x,p.z,p.y))
   v.append(c+p)
 add(cat,key,v,[(i*K+j,((i+1)%N)*K+j,((i+1)%N)*K+(j+1)%K,i*K+(j+1)%K) for i in range(N) for j in range(K)],True)
def assign_mesh(o,v,f,key=None,smooth=False):
 assert o.name not in G,o.name
 mesh=bpy.data.meshes.new(o.name+'_Sculpt09');inv=o.matrix_world.inverted();mesh.from_pydata([inv@Vector(p) for p in v],[],f);mesh.update()
 mats=[M[key]] if key else [x for x in o.data.materials]
 for mat in mats:mesh.materials.append(mat)
 # Deterministic planar UVs, rather than missing UVs after remeshing.
 uv=mesh.uv_layers.new(name='UVMap')
 for p in mesh.polygons:
  axis=max(range(3),key=lambda a:abs(p.normal[a]));axes=[a for a in range(3) if a!=axis]
  for li in p.loop_indices:
   co=o.matrix_world@mesh.vertices[mesh.loops[li].vertex_index].co;uv.data[li].uv=(co[axes[0]]*.5,co[axes[1]]*.5)
  p.use_smooth=smooth
 o.data=mesh
 if not smooth:
  mod=o.modifiers.new('Crafted edge normals','WEIGHTED_NORMAL');mod.keep_sharp=True
 C['reshaped'].append(o.name)
def soften(o,key=None,r=.08):
 mn,mx=bounds(o);assign_mesh(o,*cubegeo((mn+mx)/2,mx-mn,r),key)
def vessel(cat,pos,scale=1,key='porcelain',handle=False):
 x,y,z=pos;lathe(cat,key,pos,[(0,0),(.14*scale,0),(.18*scale,.04*scale),(.19*scale,.31*scale),(.17*scale,.34*scale),(.14*scale,.31*scale),(.13*scale,.06*scale),(0,.06*scale)])
 if handle:ring(cat,key,(x+.21*scale,y,z+.19*scale),.105*scale,'Y',.027*scale)
def plant(cat,pos,s=1):
 x,y,z=pos;lathe(cat,'clay',pos,[(0,0),(.16*s,0),(.21*s,.27*s),(.23*s,.28*s),(.23*s,.33*s),(.18*s,.33*s),(.17*s,.27*s),(0,.27*s)])
 for i in range(7):
  a=i*2.4;p=(x+math.cos(a)*.17*s,y+math.sin(a)*.17*s,z+(.42+.08*(i%3))*s)
  tube(cat,'leaf_shade',(x,y,z+.29*s),p,.012*s,6);ellipsoid(cat,['leaf','leaf_sun'][i%2],p,(.14*s,.11*s,.20*s),12,7)
def replace_batch(name,cat,key):
 o=bpy.data.objects.get(name);entry=B.pop((cat,key,False),None)
 if o and entry:assign_mesh(o,*entry,key)

def roof(cat,cx,cy,z,w,d,h,key='teal',rot=0):
 # Raised gable roof, with a real underside and substantial curved front bargeboards.
 local=[(-w/2,-d/2,0),(0,-d/2,h),(w/2,-d/2,0),(-w/2,d/2,0),(0,d/2,h),(w/2,d/2,0)]
 def point(p):x,y,zz=p;return (cx+x*math.cos(rot)-y*math.sin(rot),cy+x*math.sin(rot)+y*math.cos(rot),z+zz)
 v=[point(p) for p in local]+[point((x,y,zz-.12)) for x,y,zz in local]
 f=[(0,3,4,1),(1,4,5,2),(6,7,10,9),(7,8,11,10),(0,1,7,6),(1,2,8,7),(3,9,10,4),(4,10,11,5),(0,6,9,3),(2,5,11,8)]
 add(cat,key,v,f)
 for a,b in [(0,1),(1,2),(3,4),(4,5)]:tube(cat+'Fascia','ivory',point(local[a]),point(local[b]),.085,10)
 tube(cat+'Ridge',key,point((0,-d/2-.08,h+.02)),point((0,d/2+.08,h+.02)),.11,12)
 # Broad roof strips are deliberate roof planes, no hundreds of tiny decorations.
 for side in [-1,1]:
  for i in range(1,5):
   t=i/5;x=side*w*.5*t;zz=h*(1-t)+.025
   tube(cat+'Seams',key,point((x,-d/2,zz)),point((x,d/2,zz)),.028,8)
 return point

def dormer(cat,cx,cy,z,w=1.65,d=1.35,h=.9,rot=0,key='teal'):
 point=roof(cat,cx,cy,z+h,w+.30,d+.20,.55,key,rot)
 def pt(x,y,zz):return (cx+x*math.cos(rot)-y*math.sin(rot),cy+x*math.sin(rot)+y*math.cos(rot),z+zz)
 # Facade is a shallow framed, round window; no ground-level collision additions.
 v=[pt(x,y,zz) for x,y,zz in [(-w/2,-d/2,0),(w/2,-d/2,0),(w/2,-d/2,h),(-w/2,-d/2,h),(-w/2,d/2,0),(w/2,d/2,0),(w/2,d/2,h),(-w/2,d/2,h)]]
 add(cat+'Body','ivory',v,[(0,1,2,3),(0,4,5,1),(3,2,6,7),(0,3,7,4),(1,5,6,2),(4,7,6,5)])
 # Oriented window circles and mullions are assembled in local facade coordinates.
 n=32;rad=min(w*.31,h*.39);center=pt(0,-d/2-.025,h*.51)
 v=[center]+[pt(math.cos(i*math.tau/n)*rad,-d/2-.026,h*.51+math.sin(i*math.tau/n)*rad) for i in range(n)]
 add(cat+'Glass','glass',v,[(0,i+1,(i+1)%n+1) for i in range(n)])
 for i in range(n):
  a=i*math.tau/n;b=(i+1)*math.tau/n;tube(cat+'Frame','honey',pt(math.cos(a)*rad,-d/2-.06,h*.51+math.sin(a)*rad),pt(math.cos(b)*rad,-d/2-.06,h*.51+math.sin(b)*rad),.045,6)
 tube(cat+'Frame','ivory',pt(-rad,-d/2-.07,h*.51),pt(rad,-d/2-.07,h*.51),.025,8)
 tube(cat+'Frame','ivory',pt(0,-d/2-.07,h*.51-rad),pt(0,-d/2-.07,h*.51+rad),.025,8)
 C['details'].append(cat+' / thick gabled roof and deep round window')

def tree_forms():
 start_count=len(C['reshaped'])
 for i,o in enumerate(BASE):
  if o.type!='MESH' or o.name in G:continue
  n=o.name
  if not (n.startswith('ALPHA_V3_Tree_Canopy_') or ('Crown' in n and 'ORCHARD' not in n and ROOM in ['school','home_estate','playground','football_field'])):continue
  mn,mx=bounds(o);d=mx-mn;c=(mn+mx)/2
  if min(d)<.3:continue
  # Replace flat triangulated blobs with asymmetric, softly scalloped crown masses.
  # Horizontal crown envelope is retained; varied tops grow only above existing canopy.
  key=['leaf','leaf_sun','leaf_shade'][i%3];cat='__crown';height=d.z*(1.12+.07*(i%4));z=mn.z
  if ROOM=='island' and any((o2.matrix_world.translation.xy-c.xy).length<8 for o2 in BASE if o2.name.startswith('SG_DOOR_')):height=d.z*.97
  family=i%3
  ellipsoid(cat,key,(c.x-.04*d.x,c.y+.035*d.y,z+height*(.60 if family!=1 else .62)),(d.x*(.35 if family!=1 else .40),d.y*.36,height*(.41 if family!=1 else .30)),20,13)
  for j in range(5):
   a=j*math.tau/5+i*.71;level=.36+.055*((i+j)%4);ellipsoid(cat,key,(c.x+math.cos(a)*d.x*.22,c.y+math.sin(a)*d.y*.22,z+height*level),(d.x*(.25+.015*(j%2)),d.y*.255,height*(.27+.025*(j%3))),16,11)
  v,f=B.pop((cat,key,True));assign_mesh(o,v,f,key,True)
 if len(C['reshaped'])>start_count:C['details'].append('Organic layered crown silhouettes; original trunk and crown ground footprints retained')

def path_edges():
 paths=[o for o in BASE if o.type=='MESH' and o.name not in G and any(s.material and s.material.name=='WR_stone_CAMPUS_path' for s in o.material_slots)]
 bvh={o.name:BVHTree.FromObject(o,bpy.context.evaluated_depsgraph_get()) for o in paths}
 for o in paths:
  counts={}
  for p in o.data.polygons:
   for e in p.edge_keys:counts[e]=counts.get(e,0)+1
  for (i,j),count in counts.items():
   if count!=1:continue
   a=o.matrix_world@o.data.vertices[i].co;b=o.matrix_world@o.data.vertices[j].co;delta=b-a;length=delta.xy.length
   if length<.08:continue
   perpendicular=Vector((-delta.y,delta.x,0)).normalized()*.055
   for k in range(max(1,math.ceil(length/.6))):
    n=max(1,math.ceil(length/.6));p=a+delta*k/n;q=a+delta*(k+1)/n;mid=(p+q)/2
    if any(t.ray_cast(other.matrix_world.inverted()@Vector((mid.x,mid.y,30)),other.matrix_world.inverted().to_3x3()@Vector((0,0,-1)),60)[0] is not None for other in paths if other!=o for t in [bvh[other.name]]):continue
    p.z+=.012;q.z+=.012;add('PavingBorder','sand',[p-perpendicular,p+perpendicular,q+perpendicular,q-perpendicular],[(0,1,2,3)])
 C['details'].append('Flush paving borders follow exposed union edges; no stripes through junctions')

def lake_margin():
 water=bpy.data.objects.get('ALPHA_V3_Lake_Deep_To_Shallow');terrain=bpy.data.objects.get('ALPHA_Island_Continuous_Terrain')
 if not water or not terrain:return
 tree=BVHTree.FromObject(terrain,bpy.context.evaluated_depsgraph_get());im=terrain.matrix_world.inverted();counts={}
 for p in water.data.polygons:
  for e in p.edge_keys:counts[e]=counts.get(e,0)+1
 def ground(p):
  hit=tree.ray_cast(im@Vector((p.x,p.y,40)),im.to_3x3()@Vector((0,0,-1)),80)[0]
  return terrain.matrix_world@hit if hit else None
 for (i,j),count in counts.items():
  if count!=1:continue
  a=water.matrix_world@water.data.vertices[i].co;b=water.matrix_world@water.data.vertices[j].co
  pts=[]
  for v in [a,b]:
   radial=Vector((v.x,v.y-6,0)).normalized();width=.32+.12*math.sin(v.x*.7+v.y*.4);p=ground(v+radial*width)
   if p is None or p.z<4.67 or p.z>5.12:break
   pts.extend([v+Vector((0,0,.012)),p+Vector((0,0,.016))])
  if len(pts)==4:add('LakeShore','sand',pts,[(0,1,3,2)])
 C['details'].append('Terrain-following shallow sandy lake margin; original terrain/water collision retained')

def outdoor():
 tree_forms()
 for o in BASE:
  if o.type=='MESH' and o.name not in G and o.name.split('.')[0].endswith(('_Bench_Top','_Bench_Seat','_Stand_Seat')):
   soften(o,'honey',.06)
 if ROOM=='island':
  lake_margin()
  # The old curved shingles overlapped on exactly the same plane, causing dark
  # raster/ray intersections. Give each row a real tapered lap and thickness.
  tiled=bpy.data.objects.get('ALPHA_V3_Home_Curved_Roof_Tiles')
  if tiled and tiled.name not in G:
   verts=[];faces=[]
   for sign in [-1,1]:
    for row in range(9):
     for col in range(14):
      cy=-16.94+col*.43;d0=row*.42;length=min(.55,3.65-d0);off=len(verts)
      for layer in [0,-.018]:
       for along in [0,length]:
        d=min(3.64,d0+along)
        for k in range(7):
         t=k/6;bulge=.065*math.sin(t*math.pi)
         verts.append((-3+sign*(3.65-d)+sign*bulge*.52,cy+(t-.5)*.42,9+d*(2.25/3.65)+.055+bulge*.85+.04*(1-along/length)+layer))
      local=[(k,k+1,k+8,k+7) for k in range(6)]
      local += [(k+14,k+21,k+22,k+15) for k in range(6)]
      local += [(k,k+14,k+15,k+1) for k in range(6)]
      local += [(k+7,k+8,k+22,k+21) for k in range(6)]
      local += [(0,7,21,14),(6,20,27,13)]
      faces.extend(tuple(off+i for i in f) for f in local)
   assign_mesh(tiled,verts,faces,'clay')
   # Consistent normals on the closed tile sections, without changing node transforms.
   bm=bmesh.new();bm.from_mesh(tiled.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(tiled.data);bm.free()
   for cap in BASE:
    if cap.type=='MESH' and cap.name.startswith('ALPHA_V3_Home_Ridge_Cap_') and cap.name not in G:
     mn,mx=bounds(cap);center=(mn.y+mx.y)/2;vs=[]
     for v in cap.data.vertices:
      p=cap.matrix_world@v.co;p.y=center+(p.y-center)*.84;vs.append(tuple(p))
     assign_mesh(cap,vs,[tuple(p.vertices) for p in cap.data.polygons],'clay',True)
   C['details'].append('Rebuilt tapered terracotta shingles and separated ridge caps to remove coplanar roof striping')
  # Replace the first-pass thin shed canopy with a full gabled porch roof.
  roof('HomePorch',-3,-17.12,8.36,2.85,1.50,.78,'teal')
  replace_batch('CF08_HomeCanopy_teal','HomePorch','teal')
  dormer('HomeDormer',-.82,-15.0,10.05,1.55,1.28,.83,math.pi/2,'teal')
  # Chimney collar makes the original box chimney sit in the tiled roof.
  for o in BASE:
   if o.type=='MESH' and o.name not in G and ('Home_Chimney' in o.name) and 'Cap' not in o.name:
    mn,mx=bounds(o);d=mx-mn
    if d.z>1:
     box('ChimneyCrown','ivory',((mn.x+mx.x)/2,(mn.y+mx.y)/2,mx.z-.1),(d.x+.16,d.y+.16,.2),.05)
  for n in ['ALPHA_Home_Door','ALPHA_Home_Door_Frame']:
   o=bpy.data.objects.get(n)
   if o and o.name not in G and n.endswith('Door'):soften(o,'honey',.10)
  # Keep the ground mesh's material partitions as well as its geometry intact.
  # Godot builds physics faces from these surfaces; repartitioning can alter a
  # borderline navigation ray at the U/V road. Separate visual skins do not collide.
  terrain=bpy.data.objects.get('ALPHA_Island_Continuous_Terrain')
  if terrain:
   count=0
   normal=terrain.matrix_world.to_3x3().inverted().transposed()
   for p in terrain.data.polygons:
    n=(normal@p.normal).normalized()
    key='earth' if n.z<.64 else 'sand' if n.z<.78 else None
    if key:
     vs=[terrain.matrix_world@terrain.data.vertices[i].co+n*.006 for i in p.vertices]
     add('TerrainSlopeSkin',key,vs,[tuple(range(len(vs)))]);count+=1
   C['surface_changes'].append({'decorative_slope_faces':count,'original_ground_geometry_and_material_partitions_unchanged':True})
  # A subdued rounded paver ribbon follows the existing decorative path edging.
  edge=bpy.data.objects.get('ALPHA_V3_Path_Edging_Stones')
  if edge and edge.name not in G:
   edge.data=edge.data.copy();edge.data.materials.clear();edge.data.materials.append(M['sand']);C['surface_changes'].append(edge.name)
 if ROOM=='school':
  path_edges()
  dormer('MusicPracticeLoft',-16,8.2,5.00,2.05,1.80,.95,0,'teal')
  dormer('ArtNorthlight',-16,-4.1,5.02,2.50,1.65,.70,0,'clay')
  # Science roof gets a small observatory drum, completely above the existing roof.
  lathe('ScienceLantern','ivory',(16,10.5,5.05),[(.88,0),(.88,.18),(.70,.23),(.70,1.0),(.83,1.04),(.83,1.17)])
  lathe('ScienceLantern','teal',(16,10.5,6.20),[(.91,0),(.86,.14),(.71,.40),(.48,.59),(.08,.73),(0,.77)])
  for i in range(8):
   a=i*math.tau/8;x=16+.71*math.cos(a);y=10.5+.71*math.sin(a);tube('ScienceLantern','brass',(x,y,5.30),(x,y,6.15),.045,8)
  # Porch roofs shelter existing doorway footprints; generous headroom and no new posts.
  roof('MusicPorch',-16,5.0,3.15,2.30,1.45,.58,'teal')
  roof('ArtPorch',-16,-7.5,3.15,2.30,1.45,.58,'clay')
  # Existing central garden supports a quieter layered perennial bed.
  for i in range(9):
   a=i*2.399;rad=1.7+(i%3)*.32;x=math.cos(a)*rad;y=math.sin(a)*rad
   ellipsoid('GardenMounds',['leaf','leaf_sun'][i%2],(x,y,.74),(.48,.42,.40+.13*(i%3)),14,9)
  C['details'].append('Distinct music loft, art rooflight, science observatory, sheltered doors and layered central garden')
 if ROOM=='football_field':
  # A useful shelter over the existing team bench; all posts stay inside its collision footprint.
  for x in [4.17,8.23]:tube('TeamShelterFrame','teal',(x,-11.41,.60),(x,-11.41,2.88),.055,12)
  for j in range(8):
   x1=3.85+j*4.70/8;x2=3.85+(j+1)*4.70/8;v=[]
   for x in [x1,x2]:
    for k in range(13):
     t=k/12;v.append((x,-12.35+t*1.7,2.72+.20*math.sin(t*math.pi)))
   add('TeamShelterCanvas','teal' if j%2==0 else 'ivory',v,[(k,k+1,13+k+1,13+k) for k in range(12)],True)
  for x in [3.85,8.55]:
   for k in range(12):
    t=k/12;tt=(k+1)/12;tube('TeamShelterFrame','teal',(x,-12.35+t*1.7,2.72+.2*math.sin(t*math.pi)),(x,-12.35+tt*1.7,2.72+.2*math.sin(tt*math.pi)),.035,8)
  # Retain the original three water bottles; avoid redundant overlapping props.
  C['details'].append('Arched canvas team shelter over the existing bench and original water bottles')
 if ROOM=='playground':
  for o in BASE:
   if o.type=='MESH' and o.name not in G and o.name.startswith('Locus_02_Equipment_Shelf'):soften(o,'honey',.045)
  for i in range(3):ring('EquipmentHoops',['clay','teal','butter'][i],(-6.60+i*.30,1.70,1.12),.27,'Y',.025)
  C['details'].append('Rounded equipment cubbies with hanging hoops; clear play surface retained')
 if ROOM=='home_estate':
  # Add a dormer only to a broad roof surface, using its measured envelope.
  candidates=[o for o in BASE if o.type=='MESH' and 'Main_Roof_Roof_Base' in o.name]
  if candidates:
   o=candidates[0];mn,mx=bounds(o);c=(mn+mx)/2;dormer('EstateDormer',c.x,c.y-2.0,mx.z-.6,1.8,1.55,.95,-math.pi/2,'teal')
 # Reinforce shallow front windows with rounded jambs and a projecting sill.
 for o in BASE:
  if o.type!='MESH' or o.name in G or not ('Window' in o.name and o.name.split('.')[0].endswith('_Glass')):continue
  mn,mx=bounds(o);d=mx-mn;c=(mn+mx)/2
  if d.y>.16 or d.z<.8 or d.x<.65 or d.x>4:continue
  for x in [mn.x-.055,mx.x+.055]:box('WindowJamb','ivory',(x,mn.y-.035,c.z),(.12,.18,d.z+.18),.035)
  box('WindowSill','honey',(c.x,mn.y-.10,mn.z-.09),(d.x+.30,.36,.16),.05)
  # Distinct inner reveal gives a visible edge shadow at native camera distance.
  box('WindowLintel','ivory',(c.x,mn.y-.04,mx.z+.07),(d.x+.23,.18,.14),.035)


def curtains(o):
 mn,mx=bounds(o);d=mx-mn;c=(mn+mx)/2
 if d.y>.12 or d.z<.7 or d.x<.8 or d.x>4:return
 y=mn.y-.16;z1=mn.z-.06;z2=mx.z+.12
 tube('CurtainRail','oak',(mn.x-.28,y,z2+.13),(mx.x+.28,y,z2+.13),.045,12)
 for sign in [-1,1]:
  x=c.x+sign*(d.x/2-.16);w=min(.46,d.x*.20);v=[];N=18;K=8
  for j in range(K+1):
   t=j/K
   for i in range(N+1):
    u=i/N;shift=sign*.06*math.sin(t*math.pi);v.append((x+(u-.5)*w+shift,y-.045*math.cos(u*math.tau*3),z1+t*(z2-z1)+.025*math.cos(u*math.tau*3)*(1-t)))
  add('CurtainFabric','linen',v,[(j*(N+1)+i,j*(N+1)+i+1,(j+1)*(N+1)+i+1,(j+1)*(N+1)+i) for j in range(K) for i in range(N)],True)
  box('CurtainTie','teal',(x+sign*.045,y-.055,z1+(z2-z1)*.35),(w+.04,.06,.075),.018)
 # Replace exposed rectangular sill with a thick softly rounded cap inside its existing depth.
 sill=bpy.data.objects.get(o.name.replace('Glass','Sill'))
 if sill and sill.name not in G:soften(sill,'honey',.055)

def furniture():
 for o in BASE:
  if o.type!='MESH' or o.name in G or o.name.startswith(('WR_','CF08_','ALPHA_','Living')):continue
  n=o.name.split('.')[0];lo=n.lower();mn,mx=bounds(o);d=mx-mn
  if min(d)<.025:continue
  key=None;r=None
  if n.endswith(('_Top','_Seat','_Shelf')) and d.z<.4 and d.x>.45 and d.y>.28:r=.065;key='honey' if not any(t in lo for t in ['sink','stove','vanity']) else 'porcelain'
  elif n.endswith(('_Cabinet','_Case')) and d.x>.7 and .6<d.z<3.4 and d.y>.4:
   r=.12;key='ivory' if 'fridge' in lo else 'sage'
  elif any(t in lo for t in ['sofa_cushion','sofa_arm','sofa_back','chair_cushion','chair_arm','chair_back','bench_cushion','mattress']):r=min(.18,min(d)*.42);key='linen' if 'bed' in lo else 'teal'
  elif n.endswith('_Panel') and 'Fridge' in n:r=.04;key='sage'
  elif n.endswith(('_Headboard','_Bed_Frame')):r=.08;key='honey'
  if r:
   if n.endswith(('_Top','_Seat')) and d.z<.4 and d.x>.45 and d.y>.28:assign_mesh(o,*pillgeo((mn+mx)/2,d,.24),key)
   else:soften(o,key,r)
  if 'Window' in n and n.endswith('_Glass') and ROOM!='home' and not (ROOM=='home_kitchen' and 'Right' in n):curtains(o)
 # Existing decorative inlays follow the new rounded tabletop footprint.
 for o in BASE:
  if o.type=='MESH' and o.name not in G and o.name.startswith('WR_Inlay_'):
   mn,mx=bounds(o);d=mx-mn
   if d.x>.5 and d.y>.3:assign_mesh(o,*pillgeo((mn+mx)/2,d,.20),'honey')
 # Coherent shelf joinery: substantial softened original sides remain in their original footprint.
 for o in BASE:
  if o.type=='MESH' and o.name not in G and o.name.split('.')[0].endswith('_Side') and any(t in o.name for t in ['Bookcase','Cabinet','Shelf','Rack']):
   mn,mx=bounds(o)
   if min(mx-mn)>.05:soften(o,'honey',.035)


def free_table_anchor(o,kind):
 mn,mx=bounds(o);z=mx.z+(.022 if ROOM in ['classroom','science_room','art_room','home_bedroom'] else .008)
 extent={'study':(-.11,.41,-.19,.24,.45),'art':(-.11,.41,-.19,.24,.45),'science':(-.14,.63,-.18,.18,.45),'tea':(-.15,.56,-.20,.20,.25),'bedside':(-.15,.56,-.20,.20,.25),'bath':(-.14,.44,-.22,.22,.30),'garden':(-.24,.24,-.24,.24,.55)}[kind]
 left,right,front,back,height=extent
 def clear(x,y):
  lo=Vector((x+left,y+front,z));hi=Vector((x+right,y+back,z+height))
  if lo.x<mn.x+.04 or hi.x>mx.x-.04 or lo.y<mn.y+.04 or hi.y>mx.y-.04:return False
  for other in BASE:
   if other==o or other.type!='MESH' or other.name.startswith(('SG_','WR_')):continue
   a,b=bounds(other)
   if b.z<=z+.015:continue
   overlap=[min(hi[i],b[i])-max(lo[i],a[i]) for i in range(3)]
   if min(overlap)>.012:return False
  return True
 preferred=(mn.x+(mx.x-mn.x)*.18,(mn.y+mx.y)/2)
 if clear(*preferred):return (*preferred,z)
 for j in range(5):
  y=mn.y-front+.06+(mx.y-mn.y-(back-front)-.12)*j/4
  for i in range(9):
   x=mn.x-left+.06+(mx.x-mn.x-(right-left)-.12)*i/8
   if clear(x,y):return (x,y,z)
 return None

def interiors():
 # The original classroom window floated behind the reading shelf. Mount its purely
 # decorative pieces on the rear wall; all five associated learning props stay put.
 if ROOM=='classroom':
  moved=[]
  for o in BASE:
   if o.name.startswith('Reading_Window_') and o.name not in G:
    o.matrix_world.translation.y+=3.8;moved.append(o.name)
  bpy.context.view_layer.update();C['details'].append({'decorative_window_mounted_on_rear_wall':moved})
 furniture()
 if ROOM=='home_kitchen':
  o=bpy.data.objects.get('Cooker_Hood')
  if o and o.name not in G:
   mn,mx=bounds(o);c=(mn+mx)/2;d=mx-mn
   v=[(c.x+sx*d.x/2,c.y+sy*d.y/2,mn.z) for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1)]]+[(c.x+sx*d.x*.28,c.y+sy*d.y*.32,mx.z+.28) for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1)]]
   assign_mesh(o,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'ivory')
   box('HoodRim','honey',(c.x,c.y,mn.z+.025),(d.x+.05,d.y+.04,.10),.035)
  # Back counter is an existing protected footprint. Stage a compact breakfast preparation vignette.
  # The existing cooker remains clear; the preparation vignette stays on the island.
  plant('KitchenHerb',(1.45,6.45,1.745),.55)
  # Rounded appliance handles and a retracted blind clear the cooker hood.
  for x in [-5.62,-5.18]:tube('FridgeHandles','brass',(x,4.40,1.38),(x,4.40,1.88),.038,12)
  box('KitchenBlind','linen',(4.8,6.49,3.56),(2.72,.16,.24),.05)
  for i in range(3):tube('BlindHems','honey',(3.47,6.39,3.49+i*.065),(6.13,6.39,3.49+i*.065),.015,8)
  box('BreadBoard','honey',(.88,-2.6,1.18),(.70,.65,.08),.12)
  ellipsoid('BreadLoaf','butter',(.95,-2.6,1.37),(.31,.23,.17),20,12)
  for j in range(3):
   x=.79+j*.14;tube('BreadScore','ivory',(x,-2.74,1.48),(x+.06,-2.47,1.48),.017,8)
  # Backsplash is wall-mounted and does not intrude into circulation.
  for row in range(3):
   for col in range(9):box('KitchenTiles','porcelain',(-2.43+col*.27,6.675,1.27+row*.23),(.25,.035,.21),.012)
  # Linen runner lies flush with the existing floor, away from exit thresholds.
  box('KitchenRunner','linen',(-1.8,2.15,.021),(5.0,1.25,.024),.01)
  for j in range(15):box('RunnerWeave','honey',(-4.05+j*.32,2.15,.037),(.035,1.08,.005),0)
  for i in [-1,1]:box('RunnerBorder','teal',(-1.8,2.15+i*.52,.036),(4.8,.06,.006),0)
  C['details'].append('Rounded sage cabinetry, porcelain surfaces, tapered hood, pleated curtains and bread and herb preparation vignette')
 else:
  # Scene-specific useful activity, always supported by an existing tabletop.
  anchors={
   'classroom':('Shared_Desk_Top','study'),'home_study':('Pencil_Desk_Top','study'),
   'art_room':('Art_ClayTable_Top','art'),'science_room':('Science_Preparation_Top','science'),
   'canteen':('Kitchen_Back_Counter_Top','tea'),'home_dining':('Breakfast_Cabinet_Top','tea'),
   'home':('Locus_04_Window_Desk_Top','study'),'home_bedroom':('Bedside_Table_Top','bedside'),
   'home_bathroom':('Vanity_Top','bath'),'home_balcony':('Window_Cleaning_Stand_Top','garden')}
  if ROOM in anchors:
   name,kind=anchors[ROOM];o=bpy.data.objects.get(name)
   if not o:
    # Only use an unprotected, existing horizontal support matching the semantic family.
    wanted={'classroom':'Desk','home_bedroom':'Bedside'}.get(ROOM,'__missing')
    o=next((x for x in BASE if x.type=='MESH' and x.name not in G and wanted in x.name and x.name.endswith('_Top')),None)
   if o:
    mn,mx=bounds(o);x=mn.x+(mx.x-mn.x)*.18;y=(mn.y+mx.y)/2;z=mx.z+.022
    placement=free_table_anchor(o,kind)
    if placement:x,y,z=placement
    else:kind='skip'
    if kind in ['study','art']:
     box('ActivityPaper','ivory',(x+.18,y,z+.018),(.44,.34,.025),.01)
     vessel('ActivityCup',(x,y+.13,z),.50,'teal')
     for i in range(3):tube('ActivityPencils',['clay','honey','teal'][i],(x+(i-1)*.035,y+.13,z+.10),(x+(i-1)*.05,y+.13,z+.43),.015,6)
    elif kind=='science':
     vessel('ScienceCeramic',(x,y,z),.65,'porcelain');plant('ScienceSeedling',(x+.45,y,z),.55)
    elif kind in ['tea','bedside']:
     vessel('TeaSet',(x,y,z),.65,'porcelain',True);box('TeaCloth','linen',(x+.36,y,z+.02),(.35,.38,.04),.015)
    elif kind=='bath':
     box('FoldedTowels','linen',(x+.15,y,z+.09),(.55,.38,.16),.055);box('Soap','sage',(x+.15,y,z+.21),(.22,.16,.07),.035)
    elif kind=='garden':plant('PropagationPot',(x,y,z),.75)
    if kind!='skip':C['details'].append(kind+' activity group on '+o.name+' / checked clear against all source task states')
 if ROOM=='home_bedroom':
  o=bpy.data.objects.get('Bedroom_Bed_Headboard')
  if o and o.name not in G:
   mn,mx=bounds(o);c=(mn+mx)/2;outline=[(mn.x,mn.z),(mx.x,mn.z)]
   for i in range(17):
    t=1-i/8;outline.append((c.x+t*(mx.x-mn.x)*.5,mx.z-.28*t*t))
   n=len(outline);v=[(x,y,z) for y in [mn.y,mx.y] for x,z in outline]
   f=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
   assign_mesh(o,v,f,'honey');C['details'].append('Arched bed headboard within the original frame envelope')
 if ROOM=='music_room':
  # Existing piano remains recognizable. A shaped music-rest ledge is supported by its body.
  candidates=[o for o in BASE if o.type=='MESH' and 'Piano' in o.name and 'KeyboardBed' in o.name]
  if candidates:
   mn,mx=bounds(candidates[0]);c=(mn+mx)/2;box('PianoKeyLip','honey',(c.x,mn.y-.018,mn.z+.04),(mx.x-mn.x,.08,.09),.025)
 if ROOM=='home_hall':
  # Hooks above existing furniture read as daily routine without creating obstacles.
  candidates=[o for o in BASE if o.type=='MESH' and o.name=='Entry_Shoe_Bench_Seat']
  if candidates:
   mn,mx=bounds(candidates[0]);c=(mn+mx)/2
   for i in [-1,0,1]:tube('HallHooks','brass',(c.x+i*.4,mx.y,2.18),(c.x+i*.4,mx.y-.13,2.12),.035,10)

if ROOM in ['island','school','home_estate','playground','football_field']:outdoor()
else:interiors()
# Create UV-equipped batches with a small material vocabulary. No gameplay parents or collision.
coll=bpy.data.collections.new('Cloud_Refinement_09');scene.collection.children.link(coll)
for (cat,key,smooth),(verts,faces) in B.items():
 mesh=bpy.data.meshes.new('CF09_'+cat+'_'+key);mesh.from_pydata(verts,[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 mesh.materials.append(M[key]);uv=mesh.uv_layers.new(name='UVMap')
 for p in mesh.polygons:
  p.use_smooth=smooth;axis=max(range(3),key=lambda a:abs(p.normal[a]));axes=[a for a in range(3) if a!=axis]
  for li in p.loop_indices:
   co=mesh.vertices[mesh.loops[li].vertex_index].co;uv.data[li].uv=(co[axes[0]],co[axes[1]])
 ob=bpy.data.objects.new(mesh.name,mesh);coll.objects.link(ob);ob['sg_collision']='none';ob['cloud_refinement']='cloud-09 / original geometry'
 if not smooth:
  mod=ob.modifiers.new('Crafted edge normals','WEIGHTED_NORMAL');mod.keep_sharp=True
bpy.context.view_layer.update();assert guard()==G,'Protected gameplay geometry or metadata changed'
C['protected_objects']=len(G);C['protected_unchanged']=True;C['new_mesh_objects']=len(B);C['reshaped_count']=len(C['reshaped'])
scene['cloud_refinement_revision']='cloud-09';scene['cloud_round2_source']='Native edit of saved first-round Blender 4.3 file; inherited GLB reconstruction limitation retained.'
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=48;scene.cycles.use_denoising=False
for root in [o for o in scene.objects if o.name.startswith('HOME_TASK_') and o.get('household_state')]:
 for ob in [root,*root.children_recursive]:ob.hide_render=root.get('household_state')!='before'
OUT.parent.mkdir(parents=True,exist_ok=True);EV.mkdir(parents=True,exist_ok=True);bpy.context.preferences.filepaths.save_version=0
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for o in scene.objects:
 if o.type in ['MESH','EMPTY'] and not o.name.startswith('REVIEW_'):o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT.with_suffix('.glb')),export_format='GLB',use_selection=True,use_visible=False,use_renderable=False,export_apply=True,export_extras=True,export_yup=True,export_cameras=False,export_lights=False)
C['blend']=str(OUT);C['glb']=str(OUT.with_suffix('.glb'));(EV/'changes.json').write_text(json.dumps(C,indent=2,ensure_ascii=False))
print('ROUND2_COMPLETE',ROOM,'reshaped',len(C['reshaped']),'batches',len(B),flush=True)
