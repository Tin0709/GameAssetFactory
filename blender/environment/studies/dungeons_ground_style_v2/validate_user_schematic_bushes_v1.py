"""Focused fresh-source proof for exact two schematics, half-height UVs and partial adjacency."""
import bpy,json,sys,hashlib,struct
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE));from flower_preservation import compare

def audit_user_schematics():
    layouts=json.loads((HERE/'user_litematic_layouts_v1.json').read_text(encoding='utf-8'));manifest=json.loads((HERE/'user_schematic_bushes_v1_manifest.json').read_text(encoding='utf-8'));base=json.loads((EVIDENCE/'before_user_schematic_bushes_fingerprints.json').read_text(encoding='utf-8'))
    # Hidden collections are unevaluated on fresh open: derived world matrices and
    # modifier bounds otherwise contain stale raw caches. Evaluate only this
    # newly hidden comparison collection, then restore its authorized flags.
    # All authored data remain included in the exact preservation comparison.
    old_plus=bpy.data.collections['LEAF_CLUSTER_Plus_6Blocks_V1'];hidden=old_plus.hide_viewport
    try:
        old_plus.hide_viewport=False;bpy.context.view_layer.update()
        differences=compare(base['data'])
        assert not differences,repr(differences)
    finally:
        old_plus.hide_viewport=hidden;bpy.context.view_layer.update()
    for name,flags in base['collection_flags'].items():
        c=bpy.data.collections[name];assert [c.hide_viewport,c.hide_render]==([True,True]if name=='LEAF_CLUSTER_Plus_6Blocks_V1'else flags)
    reports=[];all_partial=0
    for design,source in zip(manifest['designs'],layouts['designs']):
        assert hashlib.sha256((HERE/design['stored_source']).read_bytes()).hexdigest()==design['source_sha256']==source['source_sha256'];assert hashlib.sha256(Path(source['source_file']).read_bytes()).hexdigest()==source['source_sha256']
        assert len(design['cells'])==len(source['cells']);offset=Vector(design['source_recenter_offset']);root=bpy.data.objects[design['name']+'_Root'];assert list(root.location)==list(design['display_root'])and tuple(root.rotation_euler)==(0,0,0)and tuple(root.scale)==(1,1,1)
        points=[];triangles=0;partial=0;core_rects={}
        for spec,cell in zip(design['cells'],source['cells']):
            assert spec['source_minecraft_xyz']==cell['minecraft_xyz']and spec['height_m']==cell['height_m']and spec['slab_type']==cell['slab_type'];obj=bpy.data.objects[spec['object']];assert obj.parent==root and max(abs(a-b)for a,b in zip(obj.location,Vector(cell['blender_bottom_center'])-offset))<1e-6 and tuple(obj.scale)==(1,1,1)and tuple(obj.rotation_euler)==(0,0,0)
            for side,intervals in spec['contact_intervals'].items():
                side=int(side);faces=[p for p in obj.data.polygons if obj.data.attributes['leaf_part'].data[p.index].value==0 and obj.data.attributes['core_face'].data[p.index].value==side]
                if side in(4,5):assert not faces
                elif cell['height_m']==1 and intervals==[[0,.5]]:
                    partial+=1;assert faces and all(obj.data.vertices[v].co.z>=.499999 for p in faces for v in p.vertices),'Full block retains exposed upper half against slab'
                    sourcecore=bpy.data.objects['ENV_LeafBlock_1m_V1_A'];axis=1 if side in(0,1)else 0;expectedarea=0
                    for p in sourcecore.data.polygons:
                        if sourcecore.data.attributes['leaf_part'].data[p.index].value!=0 or sourcecore.data.attributes['core_face'].data[p.index].value!=side:continue
                        ps=[sourcecore.data.vertices[v].co for v in p.vertices];expectedarea+=(max(v[axis]for v in ps)-min(v[axis]for v in ps))*max(0,max(v.z for v in ps)-max(.5,min(v.z for v in ps)))
                    assert abs(sum(p.area for p in faces)-expectedarea)<1e-5,'Partial neighbour must not erase the whole full side'
                else:assert not faces,'Complete occupied-side contacts removed'
            for o in(obj,bpy.data.objects[obj.name+'_BushyFoliage'],bpy.data.objects[obj.name+'_DenseInterior']):
                m=o.data;m.calc_loop_triangles();triangles+=len(m.loop_triangles);points.extend(obj.location+v.co for v in m.vertices)
                for p in m.polygons:
                    ps=[m.vertices[v].co for v in p.vertices];assert p.area>1e-8 and max(abs((v-ps[0]).dot(p.normal))for v in ps)<1e-6
                    uv=[m.uv_layers[0].data[li].uv for li in p.loop_indices]
                    for i in range(len(ps)):assert abs((uv[i]-uv[(i+1)%len(ps)]).length*512/(ps[i]-ps[(i+1)%len(ps)]).length-512)<.002
                    if o==obj:
                        assert all(-.500001<=v.x<=.500001 and -.500001<=v.y<=.500001 and 0<=v.z<=cell['height_m']+1e-6 for v in ps)
                        axis=max(range(3),key=lambda k:abs(p.normal[k]));assert abs(abs(p.normal[axis])-1)<1e-6;axes=[k for k in range(3)if k!=axis];wp=[obj.location+v for v in ps];rect=[(min(v[k]for v in wp),max(v[k]for v in wp))for k in axes];core_rects.setdefault((axis,round(wp[0][axis],6)),[]).append((obj.name,rect))
        overlaps=0
        for entries in core_rects.values():
            for i,a in enumerate(entries):
                for b in entries[i+1:]:
                    if a[0]!=b[0]and all(min(a[1][k][1],b[1][k][1])-max(a[1][k][0],b[1][k][0])>1e-6 for k in range(2)):overlaps+=1
        assert overlaps==0;all_partial+=partial;reports.append({'name':design['name'],'cells':len(design['cells']),'full_cells':sum(c['height_m']==1 for c in source['cells']),'half_cells':sum(c['height_m']==.5 for c in source['cells']),'structural_bounds':design['structural_bounds_local'],'foliage_bounds':[[min(v[k]for v in points)for k in range(3)],[max(v[k]for v in points)for k in range(3)]],'triangles':triangles,'partial_full_to_slab_sides_kept':partial,'coplanar_core_overlap_pairs':overlaps,'source_sha256':design['source_sha256']})
    assert all_partial==7
    png=(HERE/'textures/leaf_modules_user_pattern_grass_green_cutout.png').read_bytes();halves=[]
    for variant in('A','B','C'):
        core=bpy.data.objects['ENV_LeafSlab_1x1x05m_V1_'+variant];objects=[core,bpy.data.objects[core.name+'_BushyFoliage'],bpy.data.objects[core.name+'_DenseInterior']];assert len(objects[1].data.polygons)==32 and len(objects[2].data.polygons)==18
        lo=[min(v.co[k]for v in core.data.vertices)for k in range(3)];hi=[max(v.co[k]for v in core.data.vertices)for k in range(3)];assert lo==[-.5,-.5,0]and hi==[.5,.5,.5];density_error=0
        for obj in objects:
            for p in obj.data.polygons:
                ps=[obj.data.vertices[v].co for v in p.vertices];uv=[obj.data.uv_layers[0].data[li].uv for li in p.loop_indices]
                for i in range(len(ps)):
                    err=abs((uv[i]-uv[(i+1)%len(ps)]).length*512/(ps[i]-ps[(i+1)%len(ps)]).length-512);density_error=max(err,density_error);assert err<.002
                if obj==core and core.data.attributes['leaf_part'].data[p.index].value==0:
                    side=core.data.attributes['core_face'].data[p.index].value
                    for li in p.loop_indices:
                        v=core.data.vertices[core.data.loops[li].vertex_index].co;target=[(v.y+.5,v.z),(.5-v.y,v.z),(.5-v.x,v.z),(v.x+.5,v.z),(v.x+.5,v.y+.5),(v.x+.5,.5-v.y)][side];assert max(abs(a-b)for a,b in zip(core.data.uv_layers[0].data[li].uv,target))<1e-6
        path=HERE/'exports'/('leaf_slab_1x1x05m_v1_'+variant.lower()+'.glb');raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);binary=raw[28+n:];assert len(g['nodes'])==len(g['meshes'])==3 and len(g['materials'])==2 and len(g['images'])==1
        assert all(m['alphaMode']=='MASK'and m['doubleSided']for m in g['materials']);assert all('COLOR_0'not in p['attributes']for m in g['meshes']for p in m['primitives']);assert not any(k in g for k in('skins','animations','cameras'));view=g['bufferViews'][g['images'][0]['bufferView']];assert binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]==png
        assert g.get('samplers') and all(s.get('magFilter')==9728 and s.get('minFilter')in(9728,9984)for s in g['samplers']),'Half exports must preserve nearest pixel sampling'
        for material in g['materials']:
            texture=material['pbrMetallicRoughness']['baseColorTexture'];sampler=g['samplers'][g['textures'][texture['index']]['sampler']]
            assert sampler['magFilter']==9728 and sampler['minFilter']in(9728,9984)
        errors=[0,0,0];triangles=0;points=[]
        for obj in objects:
            m=obj.data;m.calc_loop_triangles();triangles+=len(m.loop_triangles);points.extend(v.co for v in m.vertices);node=next(n for n in g['nodes']if n['name']==obj.name);assert node.get('translation',[0,0,0])==[0,0,0]and node.get('scale',[1,1,1])==[1,1,1];p=g['meshes'][node['mesh']]['primitives'][0];assert g['accessors'][p['indices']]['count']==len(m.loop_triangles)*3
            factor=g['materials'][p['material']]['pbrMetallicRoughness'].get('baseColorFactor',[1,1,1,1]);target=[.88,.88,.88,1]if obj.name.endswith('_DenseInterior')else[1,1,1,1]
            assert len(factor)==4 and max(abs(a-b)for a,b in zip(factor,target))<1e-6,'Outer albedo must remain white-factor direct texture; interior .88 linear'
            def read(index):
                a=g['accessors'][index];v=g['bufferViews'][a['bufferView']];w={'VEC2':2,'VEC3':3}[a['type']];assert a['componentType']==5126;start=v.get('byteOffset',0)+a.get('byteOffset',0);return [struct.unpack_from('<'+'f'*w,binary,start+i*v.get('byteStride',w*4))for i in range(a['count'])]
            attrs={k:read(p['attributes'][k])for k in('POSITION','NORMAL','TEXCOORD_0')};corners={}
            for poly in m.polygons:
                for li in poly.loop_indices:
                    v=m.vertices[m.loops[li].vertex_index].co;uv=m.uv_layers[0].data[li].uv;normal=m.corner_normals[li].vector;pos=(v.x,v.z,-v.y);corners.setdefault(tuple(round(c,6)for c in pos),[]).append((pos,(uv.x,1-uv.y),(normal.x,normal.z,-normal.y)))
            for i,pos in enumerate(attrs['POSITION']):
                candidates=corners.get(tuple(round(c,6)for c in pos));assert candidates;got=(pos,attrs['TEXCOORD_0'][i],attrs['NORMAL'][i]);best=min(candidates,key=lambda ex:max(abs(a-b)for ga,ea in zip(got,ex)for a,b in zip(ga,ea)));current=[max(abs(a-b)for a,b in zip(ga,ea))for ga,ea in zip(got,best)];assert current[0]<1e-6 and current[1]<1e-6 and current[2]<1.5e-4;errors=[max(a,b)for a,b in zip(errors,current)]
        halves.append({'variant':variant,'core_m':[1,1,.5],'full_foliage_bounds':[[min(v[k]for v in points)for k in range(3)],[max(v[k]for v in points)for k in range(3)]],'triangles':triangles,'UV_density_max_error':density_error,'source_binary_errors_position_uv_normal':errors,'nearest_sampler_verified':True,'outer_white_interior_088_factors_verified':True,'sha256':hashlib.sha256(raw).hexdigest()})
    return {'status':'PASS','designs':reports,'half_templates':halves,'prior_authored_data_preserved':True,'old_plus_visibility_only_collection_change':True,'baseline_digest':base['digest'],'scope':'Two exact user schematic Blender-only assemblies, no game'}
if __name__=='__main__':
    assert bpy.app.background,'Run this fresh-source audit in a read-only background process; do not reload the live window'
    assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve()
    r=audit_user_schematics();(EVIDENCE/'validation_user_schematic_bushes.json').write_text(json.dumps(r,indent=2),encoding='utf-8');print(json.dumps(r,indent=2))
