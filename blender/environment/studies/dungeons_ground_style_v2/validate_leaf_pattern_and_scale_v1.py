"""Read-only current leaf pattern, physical UVs, anchored2x branches and explicit preservation."""
import bpy,json,sys,hashlib,struct
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare,mesh_content,rna_values

def audit_leaf_pattern():
    if bpy.data.objects.get('ENV_LeafBlock_1m_V1_A_DenseInterior'):
        from validate_bushy_leaf_modules_v1 import audit_bushy_modules
        return audit_bushy_modules()
    if bpy.data.images.get('IMG_LeafModules_UserProvided_512'):
        from validate_exact_user_leaf_texture_v1 import audit_exact_texture
        return audit_exact_texture()
    image=bpy.data.images.get('IMG_LeafModules_V1_OriginalLeafTile');assert image,'Missing recognizable original leaf-pattern revision (initial RED)'
    baseline=json.loads((EVIDENCE/'before_leaf_pattern_and_2x_branches_fingerprints.json').read_text());palette={(int(h[0:2],16),int(h[2:4],16),int(h[4:6],16))for h in ['324420','435222','59642b','687333','78853b','859344','3c4b1f']}
    tilepng=(HERE/'textures/leaf_modules_v1_original_leaf_tile.png').read_bytes();sprite=bpy.data.images['IMG_LeafBranch_V1_OriginalSpriteAtlas'];spritepng=(HERE/'textures/leaf_branch_v1_original_sprites.png').read_bytes()
    assert image.packed_file.data==tilepng and sprite.packed_file.data==spritepng
    for im in (image,sprite):
        pixels=list(im.pixels);visible={tuple(round(pixels[i+k]*255)for k in range(3))for i in range(0,len(pixels),4)if pixels[i+3]>.5};assert visible<=palette and len(visible)>=6
    assert set(list(image.pixels)[3::4])=={1} and list(sprite.pixels)[3::4]==baseline['branch_pixels'][3::4]
    reports=[];allowed={('images',sprite.name)}
    layout_path=HERE/'leaf_plus_6blocks_v1_manifest.json';layout_present=bpy.data.objects.get('ENV_LeafCluster_Plus_6Blocks_V1')is not None
    if layout_present:
        from validate_leaf_plus_6blocks_v1 import audit_assembly
        audit_assembly()
        layout_base=json.loads((EVIDENCE/'before_leaf_plus_assembly_fingerprints.json').read_text())
        allowed.update(('objects',name)for name in layout_base['display_fields'])
    for variant in ('A','B','C'):
        obj=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant];m=obj.data;old=baseline['cores'][variant];current=json.loads(json.dumps(mesh_content(m)))
        assert all(current[k]==old[k]for k in('vertices','edges','faces','colors')),'Core geometry and original Color author data must remain exact'
        assert len(m.uv_layers)==1 and m.uv_layers[0].name=='UV_Leaf_Pattern_32TexelsPerMetre'
        max_density_error=0
        for p in m.polygons:
            ps=[m.vertices[vi].co for vi in p.vertices];uvs=[m.uv_layers[0].data[li].uv for li in p.loop_indices]
            for i in range(4):
                density=(uvs[i]-uvs[(i+1)%4]).length*32/(ps[i]-ps[(i+1)%4]).length;max_density_error=max(max_density_error,abs(density-32));assert abs(density-32)<1e-4
        material=m.materials[0];bsdf=material.node_tree.nodes.get('Principled BSDF');assert bsdf.inputs['Base Color'].links[0].from_node.type=='TEX_IMAGE'
        branch=bpy.data.objects[obj.name+'_CrossBranches'];bm=branch.data;before=baseline['branches'][variant];after=json.loads(json.dumps(mesh_content(bm)));assert all(after[k]==before[k]for k in before if k!='vertices')
        groups={}
        for p in bm.polygons:groups.setdefault(bm.attributes['branch_index'].data[p.index].value,[]).append(p)
        assert len(groups)==11 and all(len(pair)==2 for pair in groups.values())
        assert [sum(bm.attributes['branch_side'].data[pair[0].index].value==side for pair in groups.values())for side in range(5)]==[2,2,2,2,3]
        for a,b in groups.values():
            assert abs(a.normal.dot(b.normal))<1e-6
            endpoints=[[(bm.vertices[p.vertices[i]].co+bm.vertices[p.vertices[i+1]].co)*.5 for i in (0,2)]for p in (a,b)]
            assert all((endpoints[0][i]-endpoints[1][i]).length<1e-6 for i in (0,1))
        root_error=0
        for p in bm.polygons:
            oldpoints=[Vector(before['vertices'][vi])for vi in p.vertices];root=(oldpoints[0]+oldpoints[1])*.5
            for vi,v in zip(p.vertices,oldpoints):assert (bm.vertices[vi].co-(root+2*(v-root))).length<1e-6
            newroot=(bm.vertices[p.vertices[0]].co+bm.vertices[p.vertices[1]].co)*.5;root_error=max(root_error,(newroot-root).length)
        assert root_error<1e-6 and min(v.co.z for v in bm.vertices)>=0
        fields=rna_values(branch)
        for k in ('bound_box','dimensions'):fields.pop(k,None)
        prior=baseline['branch_objects'][variant]
        if layout_present:
            fields.pop('matrix_world',None);prior=json.loads(json.dumps(prior));prior['fields'].pop('matrix_world',None)
        authored={'fields':fields,'data':bm.name,'collections':sorted(c.name for c in branch.users_collection),'parent':branch.parent.name,'props':dict(branch.items())};assert authored==prior
        for name in (m.name,bm.name):allowed.add(('meshes',name))
        allowed.add(('objects',branch.name))
        points=[v.co for v in m.vertices]+[v.co for v in bm.vertices];lo=[min(v[k]for v in points)for k in range(3)];hi=[max(v[k]for v in points)for k in range(3)]
        path=HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb');raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);binary=raw[28+n:]
        assert len(g['meshes'])==len(g['materials'])==len(g['images'])==2
        assert all('COLOR_0'not in p['attributes']for mesh in g['meshes']for p in mesh['primitives']),'Direct texture RGB must not multiply the old vertex albedo'
        for material in g['materials']:
            assert material['pbrMetallicRoughness'].get('baseColorFactor',[1,1,1,1])==[1,1,1,1]
            imidx=g['textures'][material['pbrMetallicRoughness']['baseColorTexture']['index']]['source'];view=g['bufferViews'][g['images'][imidx]['bufferView']];png=binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
            assert png==(spritepng if material.get('alphaMode')=='MASK'else tilepng)
        assert sorted(v.get('alphaMode','OPAQUE')for v in g['materials'])==['MASK','OPAQUE']
        assert all(s['magFilter']==9728 and s['minFilter']in(9728,9984)for s in g['samplers'])
        errors=[0,0,0]
        for source in (m,bm):
            source.calc_loop_triangles();exportmesh=next(mesh for mesh in g['meshes']if mesh['name']==source.name);prim=exportmesh['primitives'][0]
            assert g['accessors'][prim['indices']]['count']==len(source.loop_triangles)*3
            def read(index):
                a=g['accessors'][index];view=g['bufferViews'][a['bufferView']];w={'VEC3':3,'VEC2':2}[a['type']];assert a['componentType']==5126;start=view.get('byteOffset',0)+a.get('byteOffset',0)
                return [struct.unpack_from('<'+'f'*w,binary,start+i*view.get('byteStride',w*4))for i in range(a['count'])]
            attrs={key:read(prim['attributes'][key])for key in ('POSITION','NORMAL','TEXCOORD_0')};expected={}
            for poly in source.polygons:
                for li in poly.loop_indices:
                    v=source.vertices[source.loops[li].vertex_index].co;nrm=source.corner_normals[li].vector;uv=source.uv_layers[0].data[li].uv;pos=(v.x,v.z,-v.y)
                    expected.setdefault(tuple(round(x,6)for x in pos),[]).append((pos,(uv.x,1-uv.y),(nrm.x,nrm.z,-nrm.y)))
            for i,pos in enumerate(attrs['POSITION']):
                candidates=expected.get(tuple(round(x,6)for x in pos));assert candidates;got=(pos,attrs['TEXCOORD_0'][i],attrs['NORMAL'][i]);best=min(candidates,key=lambda e:max(abs(a-b)for ga,ex in zip(got,e)for a,b in zip(ga,ex)))
                current=[max(abs(a-b)for a,b in zip(ga,ex))for ga,ex in zip(got,best)];assert current[0]<1e-6 and current[1]<1e-6 and current[2]<1.5e-4;errors=[max(a,b)for a,b in zip(errors,current)]
        reports.append({'variant':variant,'core_m':[1,1,1],'core_texels_per_m':32,'UV_density_max_error':max_density_error,'branch_scale_width_length':2,'fixed_root_max_error_m':root_error,'branch_groups':11,'planes_per_group':2,'pair_angle_degrees':90,'bounds_blender':[lo,hi],'branch_ground_clearance_m':min(v.co.z for v in bm.vertices),'triangles':len(m.polygons)*2+len(bm.polygons)*2,'export_meshes_surfaces':[2,2],'direct_texture_rgb_no_COLOR0':True,'source_binary_errors_position_uv_normal':errors,'sha256':hashlib.sha256(raw).hexdigest()})
    changes=compare(baseline['data']);assert set(changes)==allowed,'Only requested core UV/material slots, branch geometry/derived bounds and spriteRGB may change: '+str(changes)
    return {'status':'PASS','modules':reports,'current7green_palette_preserved':True,'core_geometry_and_source_Color_preserved':True,'sprite_alpha_and_branch_UVs_preserved':True,'PNG_packed_embedded_match':True,'preservation_changes':changes,'baseline_digest':baseline['digest'],'scope':'Blender-only current modules, no game/bulk work'}

if __name__=='__main__':
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'));r=audit_leaf_pattern();(EVIDENCE/'validation_leaf_pattern_and_2x_branches.json').write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2))
