"""Read-only core grid, real open gaps, planar zero-thickness leaf modules and preservation."""
import bpy,json,sys,hashlib,struct
from pathlib import Path
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare

def audit_modules():
    if bpy.data.objects.get('ENV_LeafBlock_1m_V1_A_DenseInterior'):
        from validate_bushy_leaf_modules_v1 import audit_bushy_modules
        current=audit_bushy_modules()
        return {'status':'PASS','core_modules':current['modules'],'current_combined_export_contract':current,'scope':'Current bushy cutout layers and denser darker interior'}
    if bpy.data.images.get('IMG_LeafModules_UserProvided_512'):
        from validate_exact_user_leaf_texture_v1 import audit_exact_texture
        current=audit_exact_texture()
        return {'status':'PASS','core_modules':current['modules'],'current_combined_export_contract':current,'scope':'Current exact user bitmap and doubled branches; earlier palettes are historical'}
    if bpy.data.images.get('IMG_LeafModules_V1_OriginalLeafTile'):
        from validate_leaf_pattern_and_scale_v1 import audit_leaf_pattern
        current=audit_leaf_pattern()
        return {'status':'PASS','core_modules':current['modules'],'current_combined_export_contract':current,'scope':'Current direct-textured core and doubled crossed branches; older vertex-only checks are historical'}
    reports=[]
    for variant in ('A','B','C'):
        obj=bpy.data.objects.get('ENV_LeafBlock_1m_V1_'+variant);assert obj,'Missing individual1m open leaf module '+variant+' (initial RED)'
        m=obj.data;m.calc_loop_triangles();assert len(m.materials)==1 and not obj.modifiers and not m.shape_keys
        assert not m.materials[0].use_backface_culling
        assert tuple(obj.scale)==(1,1,1) and tuple(obj.rotation_euler)==(0,0,0)
        lo=[min(v.co[k]for v in m.vertices)for k in range(3)];hi=[max(v.co[k]for v in m.vertices)for k in range(3)]
        assert all(-.600001<=lo[k]<=-.4999 and .4999<=hi[k]<=.600001 for k in (0,1)) and lo[2]==0 and 1<=hi[2]<=1.100001
        areas=[0]*6
        plane_rects={}
        for p in m.polygons:
            points=[m.vertices[vi].co for vi in p.vertices];assert len(points)==4 and p.area>1e-7 and max(abs((q-points[0]).dot(p.normal))for q in points)<1e-6
            kind=m.attributes['leaf_part'].data[p.index].value
            fixed=max(range(3),key=lambda k:abs(p.normal[k]));assert abs(abs(p.normal[fixed])-1)<1e-6
            moving=[k for k in range(3)if k!=fixed];key=(fixed,round(points[0][fixed],6))
            rect=tuple((min(v[k]for v in points),max(v[k]for v in points))for k in moving)
            plane_rects.setdefault(key,[]).append(rect)
            if kind==0:
                axis=m.attributes['core_face'].data[p.index].value;areas[axis]+=p.area
                assert all(all(-.500001<=v[k]<=.500001 for k in (0,1))and 0<=v.z<=1.000001 for v in points)
        assert all(.75<a<.86 for a in areas),'Dense foliage retains small real open gaps, not alpha or filled background'
        overlap_pairs=0
        for rects in plane_rects.values():
            for i,a in enumerate(rects):
                for b in rects[i+1:]:
                    if all(min(a[k][1],b[k][1])-max(a[k][0],b[k][0])>1e-6 for k in (0,1)):overlap_pairs+=1
        assert overlap_pairs==0,'No positive-area coplanar leaf overlaps/z-fighting'
        path=HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb');raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);coremesh=next(v for v in g['meshes']if v['name']==m.name);p=coremesh['primitives'][0]
        has_branches=bpy.data.objects.get(obj.name+'_CrossBranches')is not None;count=2 if has_branches else 1
        assert len(g['nodes'])==len(g['meshes'])==len(g['materials'])==count and len(coremesh['primitives'])==1
        assert not any(k in g for k in ('skins','animations','cameras')) and not p.get('targets')
        if not has_branches:assert not any(k in g for k in('textures','images'))
        coremat=g['materials'][p['material']]
        assert 'COLOR_0'in p['attributes'] and coremat['doubleSided'] and coremat.get('alphaMode','OPAQUE')=='OPAQUE'
        assert g['accessors'][p['indices']]['count']==len(m.loop_triangles)*3
        node=next(v for v in g['nodes']if v['name']==obj.name);assert node.get('translation',[0,0,0])==[0,0,0] and node.get('scale',[1,1,1])==[1,1,1]
        binary=raw[28+n:]
        def read(index):
            a=g['accessors'][index];view=g['bufferViews'][a['bufferView']];fmt={5126:'f',5123:'H',5125:'I',5121:'B'}[a['componentType']];w={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']];size=struct.calcsize('<'+fmt*w);offset=view.get('byteOffset',0)+a.get('byteOffset',0)
            values=[struct.unpack_from('<'+fmt*w,binary,offset+i*view.get('byteStride',size))for i in range(a['count'])]
            if a.get('normalized'):values=[tuple(v/{5123:65535,5121:255}[a['componentType']]for v in row)for row in values]
            return values
        attrs={k:read(v)for k,v in p['attributes'].items()};expected={}
        for poly in m.polygons:
            for li in poly.loop_indices:
                v=m.vertices[m.loops[li].vertex_index].co;normal=m.corner_normals[li].vector;c=m.color_attributes['Color'].data[li].color
                position=(v.x,v.z,-v.y);key=tuple(round(a,6)for a in position)
                expected.setdefault(key,[]).append((position,tuple(c),(normal.x,normal.z,-normal.y)))
        maxerrors=[0,0,0]
        for vi,point in enumerate(attrs['POSITION']):
            choices=expected.get(tuple(round(a,6)for a in point));assert choices
            got=(point,attrs['COLOR_0'][vi],attrs['NORMAL'][vi]);best=min(choices,key=lambda e:max(abs(a-b)for ga,ex in zip(got,e)for a,b in zip(ga,ex)))
            errors=[max(abs(a-b)for a,b in zip(ga,ex))for ga,ex in zip(got,best)]
            assert errors[0]<1e-6 and errors[1]<1/65535+1e-7 and errors[2]<1.5e-4
            maxerrors=[max(a,b)for a,b in zip(maxerrors,errors)]
        reports.append({'variant':variant,'reserved_core_m':[1,1,1],'core_rest_bounds_blender':[lo,hi],'core_triangles':len(m.loop_triangles),'core_quads':len(m.polygons),'solid_surface_coverage':areas,'real_gap_fraction':[1-a for a in areas],'sha256':hashlib.sha256(raw).hexdigest(),'core_one_mesh_one_surface':True,'module_export_meshes_surfaces':[count,count],'opaque_geometric_core_leaf_planes':True,'source_corner_binary_errors_position_color_normal':maxerrors,'positive_area_coplanar_overlap_pairs':overlap_pairs})
    baseline=json.loads((EVIDENCE/'before_leaf_modules_fingerprints.json').read_text());assert not compare(baseline['data']),'All prior source including paused bulk and wind studies must remain preserved'
    result={'status':'PASS','core_modules':reports,'prior_data_preserved':True,'scope':'Blender-only reusable1m blocks; no assembled bush/game integration'}
    branch_presence=[bpy.data.objects.get('ENV_LeafBlock_1m_V1_'+v+'_CrossBranches')is not None for v in ('A','B','C')]
    assert all(branch_presence)or not any(branch_presence),'Partial branch source needs completion before a combined contract'
    if all(branch_presence):
        from validate_textured_leaf_branches_v1 import audit_branches
        result['current_combined_export_contract']=audit_branches()
    return result

if __name__=='__main__':
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'));r=audit_modules();(EVIDENCE/'validation_leaf_modules_source_glb.json').write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2))

