"""Current user-supplied leaf PNG, direct materials, physical UVs, preserved geometry."""
import bpy,json,sys,hashlib,struct
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare,mesh_content,node_content
UV_NAME='UV_UserLeafTile_1RepeatPerMetre'

def coplanar_assembly_pairs():
    groups={}
    for o in bpy.data.objects:
        if o.name not in ['ENV_LeafCluster_Plus_Cell_'+str(i)for i in range(6)]:continue
        m=o.data
        for p in m.polygons:
            ps=[o.location+m.vertices[vi].co for vi in p.vertices];axis=max(range(3),key=lambda k:abs(p.normal[k]));assert abs(abs(p.normal[axis])-1)<1e-6
            axes=[k for k in range(3)if k!=axis];rect=[(min(v[k]for v in ps),max(v[k]for v in ps))for k in axes];groups.setdefault((axis,round(ps[0][axis],6)),[]).append((o.name,p.index,rect))
    found=[]
    for key,entries in groups.items():
        for i,a in enumerate(entries):
            for b in entries[i+1:]:
                if a[0]==b[0]:continue
                overlap=[min(a[2][k][1],b[2][k][1])-max(a[2][k][0],b[2][k][0])for k in range(2)]
                if min(overlap)>1e-6:found.append({'a':[a[0],a[1]],'b':[b[0],b[1]],'axis':key[0],'plane':key[1],'area':overlap[0]*overlap[1]})
    return found

def audit_exact_texture():
    if bpy.data.objects.get('ENV_LeafBlock_1m_V1_A_DenseInterior'):
        from validate_bushy_leaf_modules_v1 import audit_bushy_modules
        return audit_bushy_modules()
    im=bpy.data.images.get('IMG_LeafModules_UserProvided_512');assert im,'Missing exact user-supplied leaf texture (initial RED)'
    before=json.loads((EVIDENCE/'before_exact_user_leaf_texture_fingerprints.json').read_text());expected=json.loads((EVIDENCE/'user_exact_leaf_png_expected.json').read_text());png=(HERE/'textures/leaf_modules_user_provided_512.png').read_bytes()
    assert hashlib.sha256(png).hexdigest()==expected['PNG_sha256'] and im.packed_file.data==png and list(im.size)==[512,512]
    rgba=bytes(round(v*255)for v in im.pixels);assert hashlib.sha256(rgba).hexdigest()==expected['RGBA_bottom_up_sha256'],'Actual Blender image pixels must match provided RGBA, including opaque black'
    mat=bpy.data.materials['MAT_LeafModules_V1_DirectLeafPattern'];bsdf=mat.node_tree.nodes['Principled BSDF'];tex=bsdf.inputs['Base Color'].links[0].from_node;assert tex.type=='TEX_IMAGE'and tex.image==im and tex.interpolation=='Closest'and not mat.use_backface_culling
    nodebaseline=before['material_nodes'];current=json.loads(json.dumps(node_content(mat.node_tree)));nodebaseline['nodes'][tex.name]['image']=im.name;assert current==nodebaseline,'Only core texture image pointer changes'
    sprite=bpy.data.images['IMG_LeafBranch_V1_OriginalSpriteAtlas'];sp=list(sprite.pixels);old=before['branch_pixels'];assert sp[3::4]==old[3::4]
    for y in range(40):
        for x in range(120):
            i=(y*120+x)*4
            if sp[i+3]:
                j=((y*512//40)*512+((x%40)*512//40))*4;assert all(abs(sp[i+k]-im.pixels[j+k])<1e-7 for k in range(3))
    spritepng=(HERE/'textures/leaf_branch_v1_original_sprites.png').read_bytes();assert sprite.packed_file.data==spritepng
    revision=json.loads((HERE/'exact_user_leaf_texture_v1_manifest.json').read_text());adjustments=revision['assembly_sprig_offsets'];allowed={('materials',mat.name),('images',sprite.name)};density_error=0
    for name,original in before['core_meshes'].items():
        mesh=bpy.data.meshes[name];now=json.loads(json.dumps(mesh_content(mesh)));assert all(now[k]==original[k]for k in ('edges','faces','colors','materials'))
        offsets=adjustments.get(name,{})
        for i,(v,oldv)in enumerate(zip(now['vertices'],original['vertices'])):
            offset=offsets.get(str(i),[0,0,0]);assert max(abs(v[k]-oldv[k]-offset[k])for k in range(3))<1e-7
        assert set(now['uv'])=={UV_NAME}
        for p in mesh.polygons:
            ps=[mesh.vertices[vi].co for vi in p.vertices];uv=[mesh.uv_layers[0].data[li].uv for li in p.loop_indices]
            for i in range(4):
                error=abs((uv[i]-uv[(i+1)%4]).length*512/(ps[i]-ps[(i+1)%4]).length-512);density_error=max(error,density_error);assert error<.002
            if mesh.attributes['leaf_part'].data[p.index].value==0:
                side=mesh.attributes['core_face'].data[p.index].value
                for li in p.loop_indices:
                    v=mesh.vertices[mesh.loops[li].vertex_index].co;target=[(v.y+.5,v.z),(.5-v.y,v.z),(.5-v.x,v.z),(v.x+.5,v.z),(v.x+.5,v.y+.5),(v.x+.5,.5-v.y)][side];assert max(abs(a-b)for a,b in zip(mesh.uv_layers[0].data[li].uv,target))<1e-6
        allowed.add(('meshes',name))
    assert not coplanar_assembly_pairs(),'No positive-area coplanar assembly overlaps'
    assert set(compare(before['data']))==allowed,'Texture/UV revision and recorded assembly micro-offsets only'
    reports=[]
    for variant in ('A','B','C'):
        core=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant];branch=bpy.data.objects[core.name+'_CrossBranches'];path=HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb');raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);binary=raw[28+n:];assert len(g['meshes'])==len(g['images'])==len(g['materials'])==2 and not any(k in g for k in('skins','animations','cameras'))
        for material in g['materials']:
            assert material['doubleSided']and material['pbrMetallicRoughness'].get('baseColorFactor',[1,1,1,1])==[1,1,1,1]
            imidx=g['textures'][material['pbrMetallicRoughness']['baseColorTexture']['index']]['source'];view=g['bufferViews'][g['images'][imidx]['bufferView']];data=binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']];assert data==(spritepng if material.get('alphaMode')=='MASK'else png)
        assert sorted(m.get('alphaMode','OPAQUE')for m in g['materials'])==['MASK','OPAQUE']and all(s['magFilter']==9728 and s['minFilter']in(9728,9984)for s in g['samplers'])
        errors=[0,0,0]
        for source in (core.data,branch.data):
            source.calc_loop_triangles();prim=next(m for m in g['meshes']if m['name']==source.name)['primitives'][0];assert 'COLOR_0'not in prim['attributes']and g['accessors'][prim['indices']]['count']==len(source.loop_triangles)*3
            def read(index):
                a=g['accessors'][index];view=g['bufferViews'][a['bufferView']];w={'VEC3':3,'VEC2':2}[a['type']];assert a['componentType']==5126;start=view.get('byteOffset',0)+a.get('byteOffset',0)
                return [struct.unpack_from('<'+'f'*w,binary,start+i*view.get('byteStride',w*4))for i in range(a['count'])]
            attrs={k:read(prim['attributes'][k])for k in('POSITION','NORMAL','TEXCOORD_0')};corners={}
            for p in source.polygons:
                for li in p.loop_indices:
                    v=source.vertices[source.loops[li].vertex_index].co;normal=source.corner_normals[li].vector;uv=source.uv_layers[0].data[li].uv;position=(v.x,v.z,-v.y);corners.setdefault(tuple(round(c,6)for c in position),[]).append((position,(uv.x,1-uv.y),(normal.x,normal.z,-normal.y)))
            for i,position in enumerate(attrs['POSITION']):
                possible=corners.get(tuple(round(c,6)for c in position));assert possible;got=(position,attrs['TEXCOORD_0'][i],attrs['NORMAL'][i]);best=min(possible,key=lambda ex:max(abs(a-b)for ga,ea in zip(got,ex)for a,b in zip(ga,ea)));current=[max(abs(a-b)for a,b in zip(ga,ea))for ga,ea in zip(got,best)];assert current[0]<1e-6 and current[1]<1e-6 and current[2]<1.5e-4;errors=[max(a,b)for a,b in zip(errors,current)]
        points=[v.co for m in(core.data,branch.data)for v in m.vertices];reports.append({'variant':variant,'core_m':[1,1,1],'texture_full_tile_per_m':1,'PNG_size':[512,512],'texels_per_m':512,'coarse_pixel_cells_per_m':16,'UV_density_max_error':density_error,'bounds_blender':[[min(v[k]for v in points)for k in range(3)],[max(v[k]for v in points)for k in range(3)]],'triangles':len(core.data.loop_triangles)+len(branch.data.loop_triangles),'export_meshes_surfaces':[2,2],'source_binary_errors_position_uv_normal':errors,'sha256':hashlib.sha256(raw).hexdigest()})
    return {'status':'PASS','modules':reports,'user_input_PNG_sha256':expected['PNG_sha256'],'Blender_RGBA_pixels_match_input':True,'PNG_packed_embedded_exact_match':True,'branch_original_alpha_and_geometry_preserved':True,'core_source_Color_preserved_and_not_exported':True,'assembly_coplanar_overlap_pairs':0,'preservation_changes':sorted(allowed),'baseline_digest':before['digest'],'scope':'Blender-only user-supplied bitmap directly, no game/bulk change'}

if __name__=='__main__':
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'));r=audit_exact_texture();(EVIDENCE/'validation_exact_user_leaf_texture.json').write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2))
