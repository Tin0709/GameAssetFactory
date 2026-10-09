"""Focused final saved-source/evaluatedGLB audit: bushy exterior +darker dense cutout interior."""
import bpy,json,sys,struct,hashlib
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare
from validate_leaf_core_only_v1 import audit_current_leaf_cores

def audit_bushy_modules():
    assert bpy.data.objects.get('ENV_LeafBlock_1m_V1_A_DenseInterior'),'Missing latest denser interior (initial RED)'
    coreaudit=audit_current_leaf_cores(check_exports=False)
    for filename in('before_bushy_leaf_layers_fingerprints.json','before_dense_leaf_interior_fingerprints.json'):
        base=json.loads((EVIDENCE/filename).read_text());assert not compare(base['data']),'Each final leaf layer phase must preserve all prior authored data exactly'
    png=(HERE/'textures/leaf_modules_user_pattern_grass_green_cutout.png').read_bytes();reports=[];dg=bpy.context.evaluated_depsgraph_get()
    for variant in('A','B','C'):
        core=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant];bushy=bpy.data.objects[core.name+'_BushyFoliage'];inside=bpy.data.objects[core.name+'_DenseInterior'];assert len(bushy.data.polygons)==52 and len(inside.data.polygons)==36 and not bushy.modifiers and not inside.modifiers
        assert [sum(bushy.data.attributes['bushy_side'].data[p.index].value==i for p in bushy.data.polygons)for i in range(5)]==[10,10,10,10,12]
        density_error=0
        for obj in(bushy,inside):
            assert obj.parent==core and tuple(obj.location)==(0,0,0)and tuple(obj.scale)==(1,1,1)and tuple(obj.rotation_euler)==(0,0,0)
            for p in obj.data.polygons:
                ps=[obj.data.vertices[v].co for v in p.vertices];uv=[obj.data.uv_layers[0].data[li].uv for li in p.loop_indices];assert len(ps)==4 and p.area>1e-6 and max(abs((v-ps[0]).dot(p.normal))for v in ps)<1e-6
                for i in range(4):
                    error=abs((uv[i]-uv[(i+1)%4]).length*512/(ps[i]-ps[(i+1)%4]).length-512);density_error=max(error,density_error);assert error<.002
                if obj==inside:assert all(-.5<v.x<.5 and -.5<v.y<.5 and 0<v.z<1 for v in ps)
                else:assert all(-.700001<=v.x<=.700001 and -.700001<=v.y<=.700001 and 0<=v.z<=1.200001 for v in ps)
        path=HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb');raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);binary=raw[28+n:];assert len(g['meshes'])==len(g['nodes'])==3 and len(g['materials'])==2 and len(g['images'])==1 and not any(k in g for k in('skins','animations','cameras'))
        for material in g['materials']:
            factor=material['pbrMetallicRoughness'].get('baseColorFactor',[1,1,1,1]);target=[.88,.88,.88,1]if 'Interior'in material['name']else[1,1,1,1];assert max(abs(a-b)for a,b in zip(factor,target))<1e-6
            assert material['alphaMode']=='MASK'and material['doubleSided']and abs(material.get('alphaCutoff',.5)-.5)<1e-6
        assert all(s['magFilter']==9728 and s['minFilter']in(9728,9984)for s in g['samplers']);view=g['bufferViews'][g['images'][0]['bufferView']];assert binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]==png
        errors=[0,0,0];triangles=0;allpoints=[]
        for obj in(core,bushy,inside):
            evaluated=obj.evaluated_get(dg).to_mesh();evaluated.calc_loop_triangles();triangles+=len(evaluated.loop_triangles);allpoints.extend(v.co.copy()for v in evaluated.vertices);node=next(v for v in g['nodes']if v['name']==obj.name);assert node.get('translation',[0,0,0])==[0,0,0]and node.get('scale',[1,1,1])==[1,1,1];mesh=g['meshes'][node['mesh']];assert len(mesh['primitives'])==1;prim=mesh['primitives'][0];assert 'COLOR_0'not in prim['attributes']and not prim.get('targets')and g['accessors'][prim['indices']]['count']==len(evaluated.loop_triangles)*3
            def read(index):
                a=g['accessors'][index];view=g['bufferViews'][a['bufferView']];w={'VEC3':3,'VEC2':2}[a['type']];assert a['componentType']==5126;start=view.get('byteOffset',0)+a.get('byteOffset',0)
                return [struct.unpack_from('<'+'f'*w,binary,start+i*view.get('byteStride',w*4))for i in range(a['count'])]
            attrs={k:read(prim['attributes'][k])for k in('POSITION','NORMAL','TEXCOORD_0')};corners={}
            for p in evaluated.polygons:
                for li in p.loop_indices:
                    v=evaluated.vertices[evaluated.loops[li].vertex_index].co;normal=evaluated.corner_normals[li].vector;uv=evaluated.uv_layers[0].data[li].uv;pos=(v.x,v.z,-v.y);corners.setdefault(tuple(round(c,6)for c in pos),[]).append((pos,(uv.x,1-uv.y),(normal.x,normal.z,-normal.y)))
            for i,pos in enumerate(attrs['POSITION']):
                candidates=corners.get(tuple(round(c,6)for c in pos));assert candidates;got=(pos,attrs['TEXCOORD_0'][i],attrs['NORMAL'][i]);best=min(candidates,key=lambda ex:max(abs(a-b)for ga,ea in zip(got,ex)for a,b in zip(ga,ea)));current=[max(abs(a-b)for a,b in zip(ga,ea))for ga,ea in zip(got,best)];assert current[0]<1e-6 and current[1]<1e-6 and current[2]<1.5e-4;errors=[max(a,b)for a,b in zip(errors,current)]
            obj.evaluated_get(dg).to_mesh_clear()
        lo=[min(v[k]for v in allpoints)for k in range(3)];hi=[max(v[k]for v in allpoints)for k in range(3)];reports.append({'variant':variant,'core_m':[1,1,1],'active_foliage_bounds':[lo,hi],'bushy_quads':52,'interior_quads':36,'interior_linear_albedo_factor':.88,'total_triangles':triangles,'export_meshes_surfaces':[3,3],'materials':2,'embedded_images':1,'all_surfaces_MASK':True,'texels_per_m':512,'coarse_pixel_cells_per_m':16,'UV_density_error_max':density_error,'evaluated_source_binary_errors_position_uv_normal':errors,'sha256':hashlib.sha256(raw).hexdigest()})
    assembly=json.loads((HERE/'leaf_plus_6blocks_v1_manifest.json').read_text());points=[];atri=0
    for spec in assembly['cells']:
        core=bpy.data.objects[spec['object']];source=bpy.data.objects['ENV_LeafBlock_1m_V1_'+spec['variant']+'_BushyFoliage'];child=bpy.data.objects[core.name+'_BushyFoliage'];inside=bpy.data.objects[core.name+'_DenseInterior'];blocked=spec['blocked_sides'];assert inside.data==bpy.data.objects['ENV_LeafBlock_1m_V1_'+spec['variant']+'_DenseInterior'].data
        def signature(m,p):return(tuple(tuple(round(c,7)for c in m.vertices[v].co)for v in p.vertices),tuple(tuple(round(c,7)for c in m.uv_layers[0].data[li].uv)for li in p.loop_indices))
        assert {signature(child.data,p)for p in child.data.polygons}=={signature(source.data,p)for p in source.data.polygons if source.data.attributes['bushy_side'].data[p.index].value not in blocked}
        for obj in(core,child,inside):
            m=obj.evaluated_get(dg).to_mesh();m.calc_loop_triangles();atri+=len(m.loop_triangles);points.extend(Vector(spec['cell'])+v.co for v in m.vertices);obj.evaluated_get(dg).to_mesh_clear()
    alo=[min(v[k]for v in points)for k in range(3)];ahi=[max(v[k]for v in points)for k in range(3)]
    # Flat core sides remain removed at occupied neighbours; only noncoplanar small exterior cards are added.
    from validate_exact_user_leaf_texture_v1 import coplanar_assembly_pairs
    assert not coplanar_assembly_pairs()
    return {'status':'PASS','modules':reports,'core_pattern_palette_alpha_preservation':coreaudit,'assembly_structural_core_m':[3,3,2],'assembly_active_foliage_bounds':[alo,ahi],'assembly_total_triangles':atri,'assembly_coplanar_core_overlap_pairs':0,'prior_authored_data_preserved_in_both_additive_layer_phases':True,'scope':'Latest Blender-only bushy exterior +slightly darker denser interior, no game/bulk changes'}

if __name__=='__main__':
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'));r=audit_bushy_modules();(EVIDENCE/'validation_latest_bushy_leaf_modules.json').write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2))
