"""Final surface alignment pass. Run after world_builder stages, once per new map.
Uses a loaded studygame_world module; edits only ALPHA scene objects.
"""
import bpy
import bmesh
import math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
import studygame_world as w


def refine():
    previously_refined=w.SCENE.get('surface_alignment_version') == 1
    w.BY_LETTER['A']['flat_radius'] = 14.0
    w.BY_LETTER['B']['entrance'] = [-55,-49]
    terrain = bpy.data.objects['ALPHA_Island_Continuous_Terrain']
    for v in terrain.data.vertices:
        v.co.z = w.height(v.co.x,v.co.y)
    terrain.data.update()
    bpy.context.view_layer.update()
    tree = BVHTree.FromObject(terrain,bpy.context.evaluated_depsgraph_get())
    def surface(x,y):
        co,_,_,_ = tree.ray_cast(Vector((x,y,80)),Vector((0,0,-1)),150)
        return co.z if co else w.height(x,y)
    # Dense strips follow the actual triangulated surface, including slope changes.
    for r in w.ROUTE_RECORDS:
        if r['type'] != 'path': continue
        points = w.sampled(r['control_points'],32)
        dense=[]
        for a,b in zip(points,points[1:]):
            count=max(1,math.ceil((b-a).length/.32))
            dense.extend(a.lerp(b,j/count) for j in range(count))
        dense.append(points[-1])
        for suffix,width,offset in [('_Edge',r['width']+.36,.085),('',r['width'],.13)]:
            obj=bpy.data.objects['ALPHA_'+r['name']+suffix]
            cross=10;verts=[];faces=[]
            for i,p in enumerate(dense):
                direction=(dense[min(i+1,len(dense)-1)]-dense[max(0,i-1)]).normalized()
                normal=Vector((-direction.y,direction.x))
                for j in range(cross+1):
                    v=p+normal*width*(j/cross-.5)
                    verts.append((v.x,v.y,surface(v.x,v.y)+offset))
            for i in range(len(dense)-1):
                p=(dense[i]+dense[i+1])/2
                if w.river_query(p.x,p.y)[0]<3.2: continue
                for j in range(cross):
                    a=i*(cross+1)+j;b=a+cross+1
                    faces.extend([(a,a+1,b+1),(a,b+1,b)])
            data=bpy.data.meshes.new(obj.name+'_Ground_Following')
            data.from_pydata(verts,[],faces);data.update()
            for mat in obj.data.materials:data.materials.append(mat)
            old=obj.data;obj.data=data
            if old.users==0:bpy.data.meshes.remove(old)
            obj['surface_projection']='terrain_bvh';obj['surface_clearance_m']=offset
    # The previous orchard retains its details but receives local ground-following paths.
    for obj in w.COLLS['Orchard'].objects:
        if obj.type!='MESH' or 'A_Path_' not in obj.name:continue
        if not obj.get('surface_subdivided'):
            obj.data=obj.data.copy()
            bm=bmesh.new();bm.from_mesh(obj.data)
            bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=5,use_grid_fill=True)
            bm.to_mesh(obj.data);bm.free()
            obj['surface_subdivided']=True
        inv=obj.matrix_world.inverted()
        offset=.085 if 'Edge' in obj.name else .13
        for v in obj.data.vertices:
            p=obj.matrix_world@v.co;p.z=surface(p.x,p.y)+offset;v.co=inv@p
        obj.data.update()
    for obj in w.COLLS['Wayfinding_Editor'].objects:
        if obj.get('editor_only'):
            obj.matrix_parent_inverse=Matrix.Identity(4);obj.location=(0,0,3)
            obj.hide_set(True);obj.hide_render=True
    if not previously_refined:
        for obj in w.SCENE.objects:
            if obj.name.startswith('ALPHA_Lake_Islet_Tree'):obj.location.z+=1.7
    # Rebuild the two boat piers with a clear edge at the boat's front platform.
    for obj in list(w.COLLS['Bridges_Docks'].objects):
        if obj.name.startswith(('ALPHA_B_Pier_Ramp','ALPHA_B_Pier_Landing')):
            bpy.data.objects.remove(obj,do_unlink=True)
    w.ROUTE_RECORDS[:]=[r for r in w.ROUTE_RECORDS if r['name'] not in ['B_Pier_Ramp','B_Pier_Landing']]
    w.pier_segment('B_Pier_Ramp',(-45,-32),(-45,-49),surface(-45,-32)+.12,1.85,3.1)
    w.pier_segment('B_Pier_Landing',(-45,-49),(-55,-49),1.85,1.85,3.5)
    # All B memory anchors are on the accessible pier; interaction props are future work.
    for i,(x,y) in enumerate([(-55,-49),(-52,-49),(-49,-49),(-45,-45),(-45,-37)],1):
        obj=bpy.data.objects['ALPHA_B_LOCUS_'+str(i).zfill(2)]
        z=1.85 if y==-49 else 1.85+(y+49)/17*(surface(-45,-32)+.12-1.85)
        obj.location=(x,y,z+.16)
    # Stone retaining skirts close small gaps at coastal and river terraces.
    for p in w.PLOTS:
        if p['letter']=='B':continue
        name='ALPHA_'+p['letter']+'_Terrace_Retaining_Edge'
        old=bpy.data.objects.get(name)
        if old:bpy.data.objects.remove(old,do_unlink=True)
        n=64;outline=[(p['x']+p['plot_radius']*math.cos(i*math.tau/n),p['y']+p['plot_radius']*math.sin(i*math.tau/n)) for i in range(n)]
        if max(p['ground_z']-surface(x,y) for x,y in outline)<.06:continue
        verts=[(x,y,surface(x,y)-.06) for x,y in outline]+[(x,y,p['ground_z']+.025) for x,y in outline]
        faces=[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        w.mesh(p['letter']+'_Terrace_Retaining_Edge',verts,faces,w.MATS['rock_light'],'Plots')
    bg=next(n for n in w.SCENE.world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Strength'].default_value=.42
    w.SCENE.view_settings.exposure=-.25
    w.SCENE['surface_alignment_version']=1
    bpy.context.view_layer.update()
    print({'surface_refined':True,'path_segments':sum(r['type']=='path' for r in w.ROUTE_RECORDS),'objects':len(w.SCENE.objects)})


if __name__=='__main__':refine()


def soften_terrain_colors():
    terrain=bpy.data.objects['ALPHA_Island_Continuous_Terrain']
    data=terrain.data
    attr=data.color_attributes.get('Terrain_Color')
    if attr is None:
        params=data.color_attributes.bl_rna.functions['new'].parameters
        assert 'FLOAT_COLOR' in [e.identifier for e in params['type'].enum_items]
        assert 'POINT' in [e.identifier for e in params['domain'].enum_items]
        attr=data.color_attributes.new(name='Terrain_Color',type='FLOAT_COLOR',domain='POINT')
    def blend(a,b,t):return tuple(a[i]*(1-t)+b[i]*t for i in range(3))
    for i,v in enumerate(data.vertices):
        x,y,z=v.co
        grass=blend((.20,.40,.085),(.32,.48,.14),.5+.5*math.sin(x*.07)*math.cos(y*.08))
        if x>0:grass=blend(grass,(.17,.34,.075),w.smooth(16,36,y)*.55)
        sand=w.smooth(.91,.985,w.land_ratio(x,y))
        sand=max(sand,w.smooth(-43,-58,y)*w.smooth(-46,-32,x))
        rgb=blend(grass,(.75,.64,.40),sand)
        dx=(w.height(x+.25,y)-w.height(x-.25,y))/.5
        dy=(w.height(x,y+.25)-w.height(x,y-.25))/.5
        nz=1/math.sqrt(1+dx*dx+dy*dy)
        rock=(1-w.smooth(.52,.88,nz))*(1-sand*.65)
        rgb=blend(rgb,(.42,.43,.30),rock)
        attr.data[i].color=(*rgb,1)
    mat=bpy.data.materials.get('ALPHA_MAT_Terrain_Blend')
    if mat is None:
        mat=w.make_material('Terrain_Blend',(.3,.5,.12))
        node=mat.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='Terrain_Color'
        bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs['Base Color'])
    data.materials.clear();data.materials.append(mat)
    for poly in data.polygons:poly.material_index=0
    print({'terrain_colors':'smooth vertex interpolation','vertices':len(data.vertices)})


if __name__=='__main__':soften_terrain_colors()
