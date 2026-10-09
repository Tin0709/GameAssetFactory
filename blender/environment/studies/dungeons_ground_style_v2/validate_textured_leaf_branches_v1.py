"""Read-only verification of exact crossed textured quads, cutout persistence and preservation."""
import bpy,json,sys,hashlib,struct,math
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare

def audit_branches():
    if bpy.data.objects.get('ENV_LeafBlock_1m_V1_A_DenseInterior'):
        from validate_bushy_leaf_modules_v1 import audit_bushy_modules
        return audit_bushy_modules()
    if bpy.data.images.get('IMG_LeafModules_UserProvided_512'):
        from validate_exact_user_leaf_texture_v1 import audit_exact_texture
        return audit_exact_texture()
    if bpy.data.images.get('IMG_LeafModules_V1_OriginalLeafTile'):
        from validate_leaf_pattern_and_scale_v1 import audit_leaf_pattern
        return audit_leaf_pattern()
    im=bpy.data.images.get('IMG_LeafBranch_V1_OriginalSpriteAtlas');assert im,'Missing paired textured leaf branches (initial RED)'
    texture=HERE/'textures/leaf_branch_v1_original_sprites.png';png=texture.read_bytes()
    assert im.packed_file and im.packed_file.data==png,'Packed sprite bytes must equal the saved original PNG'
    alpha=set(round(a,6)for a in list(im.pixels)[3::4]);assert alpha=={0,1},alpha
    mat=bpy.data.materials['MAT_LeafBranch_V1_NearestCutout'];tex=[n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE'][0]
    assert tex.image==im and tex.interpolation=='Closest' and not mat.use_backface_culling
    assert mat.node_tree.nodes['Leaf Alpha Clip'].operation=='ROUND'
    reports=[]
    for variant in ('A','B','C'):
        core=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant];obj=bpy.data.objects.get('ENV_LeafBlock_1m_V1_'+variant+'_CrossBranches');assert obj
        m=obj.data;m.calc_loop_triangles();assert obj.parent==core and tuple(obj.location)==(0,0,0)and tuple(obj.scale)==(1,1,1)and tuple(obj.rotation_euler)==(0,0,0)
        groups={}
        for p in m.polygons:groups.setdefault(m.attributes['branch_index'].data[p.index].value,[]).append(p)
        assert len(groups)==11 and all(len(v)==2 for v in groups.values())and len(m.loop_triangles)==44
        assert [sum(m.attributes['branch_side'].data[pair[0].index].value==side for pair in groups.values())for side in range(5)]==[2,2,2,2,3]
        for pair in groups.values():
            a,b=pair;assert len(a.vertices)==len(b.vertices)==4 and abs(a.normal.dot(b.normal))<1e-6
            points=[[m.vertices[vi].co for vi in p.vertices]for p in pair]
            roots=[(ps[0]+ps[1])*.5 for ps in points];tips=[(ps[2]+ps[3])*.5 for ps in points]
            assert (roots[0]-roots[1]).length<1e-6 and (tips[0]-tips[1]).length<1e-6
            for p,ps in zip(pair,points):assert max(abs((v-ps[0]).dot(p.normal))for v in ps)<1e-6 and p.area>0
        allpoints=[v.co for v in core.data.vertices]+[v.co for v in m.vertices]
        lo=[min(v[k]for v in allpoints)for k in range(3)];hi=[max(v[k]for v in allpoints)for k in range(3)]
        assert all(-.680001<=lo[k]<=-.5 and .5<=hi[k]<=.680001 for k in (0,1))and lo[2]==0 and hi[2]<=1.180001
        # Independent coplanarity check: avoid any whole branch plane lying on a core/sprig plane.
        coplanar=0
        for p in m.polygons:
            point=m.vertices[p.vertices[0]].co
            for q in core.data.polygons:
                if abs(abs(p.normal.dot(q.normal))-1)<1e-6 and abs((core.data.vertices[q.vertices[0]].co-point).dot(p.normal))<1e-6:coplanar+=1
            for q in m.polygons:
                if q.index<=p.index:continue
                if abs(abs(p.normal.dot(q.normal))-1)<1e-6 and abs((m.vertices[q.vertices[0]].co-point).dot(p.normal))<1e-6:coplanar+=1
        assert coplanar==0
        path=HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb');raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);binary=raw[28+n:]
        assert len(g['meshes'])==len(g['nodes'])==len(g['materials'])==2
        assert len(g['images'])==len(g['textures'])==1 and all(len(mesh['primitives'])==1 for mesh in g['meshes'])
        assert not any(k in g for k in('skins','animations','cameras'))
        masked=[v for v in g['materials']if v.get('alphaMode')=='MASK'];assert len(masked)==1 and masked[0]['doubleSided'] and abs(masked[0].get('alphaCutoff',.5)-.5)<1e-6
        assert any(v.get('alphaMode','OPAQUE')=='OPAQUE'for v in g['materials'])
        sampler=g['samplers'][0];assert sampler['magFilter']==9728 and sampler['minFilter']in(9728,9984)
        view=g['bufferViews'][g['images'][0]['bufferView']];embedded=binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
        assert embedded==png,'Embedded branch PNG must match the original authored/packed PNG byte for byte'
        for node in g['nodes']:
            assert node.get('translation',[0,0,0])==[0,0,0] and node.get('scale',[1,1,1])==[1,1,1]
        branchmesh=[v for v in g['meshes']if v['name']==m.name][0];prim=branchmesh['primitives'][0];assert g['accessors'][prim['indices']]['count']==132 and 'TEXCOORD_0'in prim['attributes']
        def read(index):
            a=g['accessors'][index];view=g['bufferViews'][a['bufferView']];w={'VEC3':3,'VEC2':2}[a['type']];assert a['componentType']==5126;start=view.get('byteOffset',0)+a.get('byteOffset',0)
            return [struct.unpack_from('<'+'f'*w,binary,start+i*view.get('byteStride',w*4))for i in range(a['count'])]
        attrs={k:read(v)for k,v in prim['attributes'].items()};expected=[];errors=[0,0,0]
        for p in m.polygons:
            for li in p.loop_indices:
                v=m.vertices[m.loops[li].vertex_index].co;normal=m.corner_normals[li].vector;uv=m.uv_layers[0].data[li].uv;expected.append(((v.x,v.z,-v.y),(uv.x,1-uv.y),(normal.x,normal.z,-normal.y)))
        for i,v in enumerate(attrs['POSITION']):
            candidates=[e for e in expected if max(abs(a-b)for a,b in zip(v,e[0]))<1e-6];assert candidates
            got=(v,attrs['TEXCOORD_0'][i],attrs['NORMAL'][i]);best=min(candidates,key=lambda e:max(abs(a-b)for ga,ex in zip(got,e)for a,b in zip(ga,ex)))
            current=[max(abs(a-b)for a,b in zip(ga,ex))for ga,ex in zip(got,best)];assert current[0]<1e-6 and current[1]<1e-6 and current[2]<1.5e-4;errors=[max(a,b)for a,b in zip(errors,current)]
        reports.append({'variant':variant,'groups':len(groups),'textured_planes_per_group':2,'pair_angle_degrees':90,'branch_triangles':44,'total_triangles':len(core.data.polygons)*2+44,'bounds_blender':[lo,hi],'core_m':[1,1,1],'source_coplanar_branch_pairs':coplanar,'export_meshes_surfaces':[2,2],'export_alpha_mode':'OPAQUE core +MASK branches','embedded_png_matches_packed_original':True,'sha256':hashlib.sha256(raw).hexdigest(),'branch_source_binary_errors_position_uv_normal':errors})
    baseline=json.loads((EVIDENCE/'before_textured_leaf_branches_fingerprints.json').read_text());assert not compare(baseline['data']),'All existing fine core geometry/materials and previous studies must stay exact'
    return {'status':'PASS','modules':reports,'sprite_alpha_values':sorted(alpha),'sprite_png_sha256':hashlib.sha256(png).hexdigest(),'prior_authored_data_preserved':True,'scope':'Blender study only'}

if __name__=='__main__':
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'));report=audit_branches();(EVIDENCE/'validation_textured_leaf_branches_source_glb.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
