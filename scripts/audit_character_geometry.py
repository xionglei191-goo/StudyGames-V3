"""Independent, read-only character GLB + runtime-interchange audit (stdlib only).

Writes an evidence report; never starts Godot/Blender, changes source assets or reads saves.
Reports DCC topology and skin math separately from renderer/animation acceptance.
"""
from __future__ import annotations
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'assets/characters/storybook_v3'
SOURCE=ART/'source'
OUTPUT=ROOT/'docs/verification/art-finish-v3/character-geometry-qa.json'
IDENTITY=[[float(i==j) for j in range(4)] for i in range(4)]
REQUIRED_MORPHS={'Eyes':['Blink'],'Face':['Smile','Talk']}


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def glb(path):
    raw=path.read_bytes()
    magic,version,total=struct.unpack_from('<4sII',raw)
    assert magic==b'glTF' and version==2 and total==len(raw),str(path)
    offset=12;data=None;blob=None
    while offset<len(raw):
        length,kind=struct.unpack_from('<II',raw,offset);offset+=8
        if kind==0x4E4F534A:data=json.loads(raw[offset:offset+length])
        elif kind==0x004E4942:blob=raw[offset:offset+length]
        offset+=length
    assert data is not None and blob is not None
    return data,blob


def accessor(data,blob,index):
    row=data['accessors'][index]
    width,fmt={5120:(1,'b'),5121:(1,'B'),5122:(2,'h'),5123:(2,'H'),5125:(4,'I'),5126:(4,'f')}[row['componentType']]
    dim={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[row['type']]
    result=[(0,)*dim for _ in range(row['count'])]
    if 'bufferView' in row:
        view=data['bufferViews'][row['bufferView']]
        offset=view.get('byteOffset',0)+row.get('byteOffset',0);stride=view.get('byteStride',width*dim)
        result=[struct.unpack_from('<'+fmt*dim,blob,offset+i*stride) for i in range(row['count'])]
    if row.get('normalized') and row['componentType']!=5126:
        maximum={5120:127,5121:255,5122:32767,5123:65535}[row['componentType']]
        result=[tuple(max(-1,x/maximum) for x in values) for values in result]
    if 'sparse' in row:
        sparse=row['sparse'];idx=sparse['indices'];values=sparse['values']
        iv=data['bufferViews'][idx['bufferView']];vv=data['bufferViews'][values['bufferView']]
        iw,iformat={5121:(1,'B'),5123:(2,'H'),5125:(4,'I')}[idx['componentType']]
        io=iv.get('byteOffset',0)+idx.get('byteOffset',0);vo=vv.get('byteOffset',0)+values.get('byteOffset',0)
        for k in range(sparse['count']):
            target=struct.unpack_from('<'+iformat,blob,io+k*iw)[0]
            result[target]=struct.unpack_from('<'+fmt*dim,blob,vo+k*width*dim)
    return result


def mul(a,b):return [[sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def matrix(node):
    if 'matrix' in node:return [[node['matrix'][j*4+i] for j in range(4)] for i in range(4)]
    x,y,z,w=node.get('rotation',[0,0,0,1]);sx,sy,sz=node.get('scale',[1,1,1]);t=node.get('translation',[0,0,0])
    rotation=[[1-2*y*y-2*z*z,2*x*y-2*z*w,2*x*z+2*y*w],
              [2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w],
              [2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y]]
    return [[rotation[i][j]*[sx,sy,sz][j] for j in range(3)]+[t[i]] for i in range(3)]+[[0,0,0,1]]


def global_matrices(data):
    parents={child:i for i,n in enumerate(data['nodes']) for child in n.get('children',[])};cache={}
    def world(i):
        if i not in cache:cache[i]=mul(world(parents[i]),matrix(data['nodes'][i])) if i in parents else matrix(data['nodes'][i])
        return cache[i]
    return {i:world(i) for i in range(len(data['nodes']))}


def distance(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))


def cross(a,b,c):
    u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
    return (u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])


def bounds(points):return {'min':[min(v[i] for v in points) for i in range(3)],'max':[max(v[i] for v in points) for i in range(3)]}


def audit_mesh(vertices,normals,uv,indices,weights,joints,joint_count,winding=1):
    errors=[];tris=len(indices)//3;zero=0;opposed=0
    if len(vertices)!=len(normals) or len(vertices)!=len(uv):errors.append('attribute_count_mismatch')
    nonfinite=sum(not all(math.isfinite(float(c)) for c in values) for values in vertices+normals+uv+weights)
    if nonfinite:errors.append('nonfinite_attribute')
    bad_normals=sum(abs(sum(c*c for c in n)-1)>.03 for n in normals)
    if bad_normals:errors.append('nonunit_normals')
    weight_errors=sum(abs(sum(w)-1)>.00002 or min(w)<0 for w in weights)
    if weight_errors:errors.append('unnormalized_weights')
    joint_errors=sum(any(j<0 or j>=joint_count for j in row) for row in joints)
    if joint_errors:errors.append('joint_index_out_of_bounds')
    edges=Counter();welded={};welded_ids=[]
    for v in vertices:
        key=tuple(round(float(c),6) for c in v)
        if key not in welded:welded[key]=len(welded)
        welded_ids.append(welded[key])
    for i in range(0,len(indices),3):
        ids=indices[i:i+3]
        if len(ids)!=3 or max(ids)>=len(vertices) or min(ids)<0:
            errors.append('triangle_index_invalid');continue
        a,b,c=(vertices[j] for j in ids);normal=cross(a,b,c)
        area2=sum(x*x for x in normal)
        if area2<1e-20:zero+=1
        avg=[sum(normals[j][axis] for j in ids) for axis in range(3)]
        if winding*sum(normal[j]*avg[j] for j in range(3)) < -1e-9:opposed+=1
        vv=[welded_ids[j] for j in ids]
        for e in range(3):edges[tuple(sorted((vv[e],vv[(e+1)%3])))]+=1
    if zero:errors.append('degenerate_triangles')
    if opposed:errors.append('normals_opposed_to_winding')
    return {'vertices':len(vertices),'triangles':tris,'nonfinite_vectors':nonfinite,'bad_normals':bad_normals,
            'weight_errors':weight_errors,'joint_errors':joint_errors,'degenerate_triangles':zero,
            'normals_opposed_to_winding':opposed,'welded_boundary_edges':sum(v==1 for v in edges.values()),
            'welded_nonmanifold_edges':sum(v>2 for v in edges.values()),
            'smooth_weight_vertices':sum(sum(x>.001 for x in w)>1 for w in weights),
            'uv_outside_0_1':sum(any(c<-.00001 or c>1.00001 for c in value) for value in uv),
            'bounds':bounds(vertices),'errors':errors}


def chunks(values,count):return [tuple(values[i:i+count]) for i in range(0,len(values),count)]


def audit_character(record):
    path=ART/record['source_glb'];data,blob=glb(path);world=global_matrices(data)
    source=json.loads((SOURCE/(record['id']+'.json')).read_text(encoding='utf-8'))
    result={'id':record['id'],'glb_sha256':digest(path),'glb_bytes':path.stat().st_size,
            'runtime_source_sha256':digest(SOURCE/(record['id']+'.json')),'glb_meshes':[],'runtime_groups':[],
            'skins':[],'errors':[],'warnings':[]}
    names=[b['name'] for b in source['bones']];rest={}
    for bone in source['bones']:
        angle=bone['rotation'][0]
        local=matrix({'translation':bone['origin'],'rotation':[math.sin(angle/2),0,0,math.cos(angle/2)]})
        rest[bone['name']]=mul(rest[bone['parent']],local) if bone['parent'] else local
    for skin in data.get('skins',[]):
        matrices=accessor(data,blob,skin['inverseBindMatrices'])
        bind_error=0;rest_error=0
        for joint,packed in zip(skin['joints'],matrices):
            inv=[[packed[j*4+i] for j in range(4)] for i in range(4)]
            bind_error=max(bind_error,distance(mul(world[joint],inv),IDENTITY))
            name=data['nodes'][joint]['name']
            if name not in rest:result['errors'].append('unknown_bone/'+name)
            else:rest_error=max(rest_error,distance(world[joint],rest[name]))
        if bind_error>1e-5:result['errors'].append('nonidentity_rest_bind')
        if rest_error>1e-5:result['errors'].append('GLB_runtime_rest_disagree')
        result['skins'].append({'joints':len(skin['joints']),'inverse_bind_count':len(matrices),'max_bind_identity_error':bind_error,'max_runtime_rest_error':rest_error})
    for mesh in data['meshes']:
        group={'name':mesh['name'],'primitives':[]}
        group_name=mesh['name'].removeprefix(record['id']+'_')
        expected_morphs=REQUIRED_MORPHS.get(group_name,[])
        for primitive in mesh['primitives']:
            a=primitive['attributes']
            required=['POSITION','NORMAL','TEXCOORD_0','COLOR_0','JOINTS_0','WEIGHTS_0']
            missing=[k for k in required if k not in a]
            if missing:
                result['errors'].append(mesh['name']+'/missing/'+','.join(missing));continue
            vertices=accessor(data,blob,a['POSITION']);normals=accessor(data,blob,a['NORMAL']);uv=accessor(data,blob,a['TEXCOORD_0'])
            weights=accessor(data,blob,a['WEIGHTS_0']);joints=accessor(data,blob,a['JOINTS_0']);indices=[x[0] for x in accessor(data,blob,primitive['indices'])]
            row=audit_mesh(vertices,normals,uv,indices,weights,joints,len(source['bones']))
            targets=primitive.get('targets',[])
            names2=mesh.get('extras',{}).get('targetNames',[])
            row['blend_shape_names']=names2;row['default_shape_weights']=mesh.get('weights',[0]*len(targets))
            row['morphs']={}
            if names2!=expected_morphs or len(targets)!=len(expected_morphs):result['errors'].append(mesh['name']+'/unexpected_morph_names_or_count')
            if len(row['default_shape_weights'])!=len(targets) or any(not math.isfinite(v) or abs(v)>1e-6 for v in row['default_shape_weights']):result['errors'].append(mesh['name']+'/source_GLB_default_morph_nonzero_or_invalid')
            for name,target in zip(names2,targets):
                if 'POSITION' not in target:
                    result['errors'].append(mesh['name']+'/'+name+'/no_position_delta');continue
                delta=accessor(data,blob,target['POSITION'])
                finite=all(math.isfinite(c) for v in delta for c in v)
                moved=sum(any(abs(c)>1e-7 for c in v) for v in delta)
                row['morphs'][name]={'vertices':len(delta),'finite':finite,'moved_vertices':moved,
                                     'max_displacement':max((math.sqrt(sum(c*c for c in v)) for v in delta),default=0)}
                if len(delta)!=len(vertices) or not finite or not moved:result['errors'].append(mesh['name']+'/'+name+'/invalid_or_empty_morph')
            result['errors'].extend(mesh['name']+'/'+e for e in row['errors'])
            group['primitives'].append(row)
        result['glb_meshes'].append(group)
    for node in data['nodes']:
        if 'mesh' in node and any(not math.isfinite(v) or abs(v)>1e-6 for v in node.get('weights',[])):
            result['errors'].append(node.get('name','node')+'/source_GLB_node_default_morph_nonzero_or_invalid')
    actual_glb_groups={m['name'].removeprefix(record['id']+'_') for m in result['glb_meshes']}
    for required in REQUIRED_MORPHS:
        if required not in actual_glb_groups:result['errors'].append('missing_GLB_morph_group/'+required)
    for group in source['groups']:
        vertices=chunks(group['vertices'],3);normals=chunks(group['normals'],3);uv=chunks(group['uv'],2)
        weights=chunks(group['weights'],4);joints=chunks(group['bones'],4)
        row=audit_mesh(vertices,normals,uv,list(range(len(vertices))),weights,joints,len(source['bones']),-1)
        row['name']=group['name'];row['raw_vertex_bytes_float32_estimate']=len(vertices)*80
        if group['blink']:
            blink=chunks(group['blink'],3)
            row['blink_vertices']=len(blink)
            row['blink_max_displacement']=max(math.sqrt(sum((p[i]-q[i])**2 for i in range(3))) for p,q in zip(vertices,blink))
            row['blink_moved_vertices']=sum(any(abs(p[i]-q[i])>1e-7 for i in range(3)) for p,q in zip(vertices,blink))
            row['blink_aabb']=bounds(blink)
            if len(blink)!=len(vertices):result['errors'].append('runtime_blink_count')
        morphs=group.get('morphs',{})
        row['morphs']={}
        if list(morphs)!=REQUIRED_MORPHS.get(group['name'],[]):result['errors'].append('runtime/'+group['name']+'/unexpected_morph_names')
        for name,packed in morphs.items():
            target=chunks(packed,3)
            finite=all(math.isfinite(c) for v in target for c in v)
            moved=sum(any(abs(p[i]-q[i])>1e-7 for i in range(3)) for p,q in zip(vertices,target))
            row['morphs'][name]={'vertices':len(target),'finite':finite,'moved_vertices':moved,
                                 'max_displacement':max((math.sqrt(sum((p[i]-q[i])**2 for i in range(3))) for p,q in zip(vertices,target)),default=0)}
            if len(packed)!=len(vertices)*3 or not finite or not moved:result['errors'].append('runtime/'+group['name']+'/'+name+'/invalid_or_empty_morph')
        if group['name']=='Eyes' and group.get('blink')!=morphs.get('Blink'):result['errors'].append('runtime/Eyes/backward_blink_mismatch')
        result['errors'].extend('runtime/'+group['name']+'/'+e for e in row['errors'])
        result['runtime_groups'].append(row)
    glb_triangles=sum(p['triangles'] for m in result['glb_meshes'] for p in m['primitives'])
    runtime_triangles=sum(g['triangles'] for g in result['runtime_groups'])
    if glb_triangles!=runtime_triangles or runtime_triangles!=record['triangles']:result['errors'].append('manifest_triangle_parity')
    runtime_vertices=sum(g['vertices'] for g in result['runtime_groups'])
    all_positions=[v for group in source['groups'] for v in chunks(group['vertices'],3)]
    bb=bounds(all_positions)
    # Existing renderer custom bounds: [-1.7,-.3,-1.7] + [3.4,3.6,3.4].
    fits=all(bb['min'][i]>=[-1.7,-.3,-1.7][i] and bb['max'][i]<=[1.7,3.3,1.7][i] for i in range(3))
    if not fits:result['errors'].append('rest_mesh_outside_runtime_custom_aabb')
    result['budget']={'draw_surfaces':len(result['runtime_groups']),'triangles':runtime_triangles,
                      'author_vertices':record['vertices'],'runtime_expanded_vertices':runtime_vertices,
                      'vertex_expansion_ratio':round(runtime_vertices/record['vertices'],3),
                      'float32_attribute_bytes_upper_estimate':runtime_vertices*80,
                      'bounds':bb,'fits_runtime_custom_aabb_at_rest':fits,
                      'animated_culling':'not inferred from rest bounds; requires runtime action fixtures'}
    return result


def main():
    manifest=json.loads((ART/'manifest.json').read_text(encoding='utf-8'))
    records=[audit_character(record) for record in manifest['assets']]
    errors=[{'id':r['id'],'issue':error} for r in records for error in r['errors']]
    warnings=[{'id':r['id'],'issue':warning} for r in records for warning in sorted(set(r['warnings']))]
    script_path=ROOT/'scripts/build_character_art_v3.py'
    if digest(script_path)!=manifest.get('source_script_sha256'):warnings.append({'id':'manifest','issue':'source_script_hash_changed_since_export'})
    runtime_manifest=json.loads((ROOT/'game/assets/characters/storybook_v3/manifest.json').read_text())
    for r in records:
        expected={g['name']:g['vertices'] for g in r['runtime_groups']}
        actual={g['name']:g['vertices'] for g in runtime_manifest['characters'][r['id']]['groups']}
        if expected!=actual:errors.append({'id':r['id'],'issue':'bake_manifest_vertex_counts_disagree'})
        expected_shapes={g['name']:list(g['morphs']) for g in r['runtime_groups']}
        actual_shapes={g['name']:g.get('blend_shapes',[]) for g in runtime_manifest['characters'][r['id']]['groups']}
        if expected_shapes!=actual_shapes:errors.append({'id':r['id'],'issue':'bake_manifest_morph_names_disagree'})
    report={'status':'FAIL' if errors else ('PASS_WITH_REVIEW' if warnings else 'PASS'),
            'scope':'read-only GLB accessor/topology/normals/UV/weights/bind math/morphs and runtime JSON parity; does not execute Blender or Godot',
            'source_blend_sha256':digest(ART/manifest['editable_source']),'source_script_sha256':digest(script_path),
            'characters':records,'errors':errors,'warnings':warnings,
            'cast_upper_scenario':{'characters':len(records),'draw_surfaces':sum(r['budget']['draw_surfaces'] for r in records),
                                   'triangles':sum(r['budget']['triangles'] for r in records),
                                   'expanded_vertices':sum(r['budget']['runtime_expanded_vertices'] for r in records),
                                   'float32_attribute_bytes_upper_estimate':sum(r['budget']['float32_attribute_bytes_upper_estimate'] for r in records)},
            'limits':['Disconnected overlapping authored clothing/facial/accessory shells are intentional; no whole-character watertight solid requirement.',
                      'Welded edge diagnostics quantize positions to 1e-6 and may flag touching/overlapping component rims; not a physics collider.',
                      'Native runtime is expanded triangles, approximately six times DCC shared-vertex count. Float32 estimate is a conservative attribute-storage scenario, not measured VRAM.',
                      'No LODs; full-cast scenario is a budget disclosure, not a claim that all cast appear simultaneously or a performance acceptance.',
                      'Binary .res content, actual animated silhouettes, facial expression and cloth intersections require engine validation.']}
    OUTPUT.parent.mkdir(parents=True,exist_ok=True);OUTPUT.write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
    print(json.dumps({'status':report['status'],'characters':len(records),'errors':errors,'warnings':warnings,'budget':report['cast_upper_scenario']},ensure_ascii=False))
    raise SystemExit(bool(errors))


if __name__=='__main__':main()
