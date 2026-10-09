"""Current evaluated core-only cutout contract, exact user pattern/category preservation."""
import bpy,json,sys,hashlib,struct
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare,node_content
GREEN_MAP={(32,77,11):(70,112,47),(38,96,13):(76,122,49),(43,109,14):(84,130,52),(52,131,17):(97,143,60)}
CORE_NAMES=['ENV_LeafBlock_1m_V1_'+v for v in('A','B','C')]+['ENV_LeafCluster_Plus_Cell_'+str(i)for i in range(6)]
UV_NAME='UV_UserLeafTile_1RepeatPerMetre'

def audit_current_leaf_cores(check_exports=True):
    im=bpy.data.images.get('IMG_LeafModules_UserPattern_GrassGreenCutout');assert im,'Missing requested lighter-green black-cutout image'
    original=bpy.data.images['IMG_LeafModules_UserProvided_512'];sourcepng=(HERE/'textures/leaf_modules_user_provided_512.png').read_bytes();expected=json.loads((EVIDENCE/'user_exact_leaf_png_expected.json').read_text());assert hashlib.sha256(sourcepng).hexdigest()==expected['PNG_sha256']and original.packed_file.data==sourcepng
    original_rgba=bytes(round(v*255)for v in original.pixels);assert hashlib.sha256(original_rgba).hexdigest()==expected['RGBA_bottom_up_sha256'];target=bytearray(original_rgba)
    for i in range(0,len(target),4):
        rgb=tuple(target[i:i+3]);target[i+3]=0 if rgb==(0,0,0)else 255
        if rgb in GREEN_MAP:target[i:i+3]=GREEN_MAP[rgb]
    assert bytes(round(v*255)for v in im.pixels)==target,'Only four source green levels and black alpha may differ; gold and pixel positions exact'
    assert im.colorspace_settings.name=='sRGB'and list(im.size)==[512,512];png=(HERE/'textures/leaf_modules_user_pattern_grass_green_cutout.png').read_bytes();assert im.packed_file.data==png
    mat=bpy.data.materials['MAT_LeafModules_V1_DirectLeafPattern'];tex=mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].links[0].from_node;assert tex.type=='TEX_IMAGE'and tex.image==im and tex.interpolation=='Closest'and not mat.use_backface_culling
    clip=mat.node_tree.nodes['Principled BSDF'].inputs['Alpha'].links[0].from_node;assert clip.operation=='ROUND'and clip.inputs[0].links[0].from_node==tex
    # Source branch data remains authored; hidden cards have updated matching colors and requested black cutout.
    sprite=bpy.data.images['IMG_LeafBranch_V1_OriginalSpriteAtlas'];sp=bytes(round(v*255)for v in sprite.pixels);base_exact=json.loads((EVIDENCE/'before_exact_user_leaf_texture_fingerprints.json').read_text());mask=base_exact['branch_pixels']
    for y in range(40):
        for x in range(120):
            i=(y*120+x)*4;j=((y*512//40)*512+(x%40)*512//40)*4
            if mask[i+3]:assert sp[i:i+4]==target[j:j+4]
            else:assert sp[i+3]==0
    baseline=json.loads((EVIDENCE/'before_leaf_core_only_fingerprints.json').read_text());allowed={('objects',name)for name in CORE_NAMES+[n+'_CrossBranches'for n in CORE_NAMES]};assert set(compare(baseline['data']))==allowed,'Raw meshes/UVs/colors/materials/images and prior studies preserved; only reversible core masks and branch visibility change'
    lightbase=json.loads((EVIDENCE/'before_grass_green_leaf_cutout_fingerprints.json').read_text());assert set(compare(lightbase['data']))==allowed|{('materials',mat.name),('images',sprite.name)},'Latest palette and core-only phases must not change any unrelated data'
    oldnodes=lightbase['material_nodes'];nodes=json.loads(json.dumps(node_content(mat.node_tree)));oldnodes['nodes'][tex.name]['image']=im.name;assert nodes==oldnodes,'Lighter-green phase changes only core image pointer'
    # Canonical original vertex albedo remains available as source data, unused by the direct texture shader.
    density_error=0;assembly_points=[];module_reports=[];core_triangles={};dg=bpy.context.evaluated_depsgraph_get()
    for name in CORE_NAMES:
        obj=bpy.data.objects[name];assert tuple(obj.scale)==(1,1,1)and tuple(obj.rotation_euler)==(0,0,0);mod=obj.modifiers.get('REVIEW_Temporarily_Omit_Protruding_Leaves');assert mod and mod.type=='MASK'and mod.show_viewport and mod.show_render
        branch=bpy.data.objects[name+'_CrossBranches'];assert branch.hide_render
        raw=obj.data;evaluated=obj.evaluated_get(dg).to_mesh();evaluated.calc_loop_triangles();core_triangles[name]=len(evaluated.loop_triangles);assert 'Color'in evaluated.color_attributes and evaluated.uv_layers[0].name==UV_NAME
        def signature(mesh,p):return (tuple(tuple(round(c,7)for c in mesh.vertices[v].co)for v in p.vertices),tuple(tuple(round(c,7)for c in mesh.uv_layers[0].data[li].uv)for li in p.loop_indices))
        assert {signature(evaluated,p)for p in evaluated.polygons}=={signature(raw,p)for p in raw.polygons if raw.attributes['leaf_part'].data[p.index].value in(0,2)},'Evaluated geometry must exactly omit part1 only'
        assert all(evaluated.attributes['leaf_part'].data[p.index].value in(0,2)for p in evaluated.polygons)
        lo=[min(v.co[k]for v in evaluated.vertices)for k in range(3)];hi=[max(v.co[k]for v in evaluated.vertices)for k in range(3)];assert all(-.500001<=lo[k]and hi[k]<=.500001 for k in(0,1))and lo[2]>=0 and hi[2]<=1.000001
        for p in evaluated.polygons:
            points=[evaluated.vertices[v].co for v in p.vertices];uv=[evaluated.uv_layers[0].data[li].uv for li in p.loop_indices]
            for i in range(4):
                error=abs((uv[i]-uv[(i+1)%4]).length*512/(points[i]-points[(i+1)%4]).length-512);density_error=max(density_error,error);assert error<.002
            if evaluated.attributes['leaf_part'].data[p.index].value==0:
                side=evaluated.attributes['core_face'].data[p.index].value
                for li in p.loop_indices:
                    v=evaluated.vertices[evaluated.loops[li].vertex_index].co;targetuv=[(v.y+.5,v.z),(.5-v.y,v.z),(.5-v.x,v.z),(v.x+.5,v.z),(v.x+.5,v.y+.5),(v.x+.5,.5-v.y)][side];assert max(abs(a-b)for a,b in zip(evaluated.uv_layers[0].data[li].uv,targetuv))<1e-6
        if name.startswith('ENV_LeafCluster_'):assembly_points.extend(obj.location+v.co for v in evaluated.vertices)
        elif not check_exports:
            module_reports.append({'variant':name[-1],'active_core_bounds':[lo,hi],'core_triangles':len(evaluated.loop_triangles)})
        else:
            variant=name[-1];path=HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb');rawglb=path.read_bytes();n=struct.unpack_from('<I',rawglb,12)[0];g=json.loads(rawglb[20:20+n]);binary=rawglb[28+n:];assert len(g['meshes'])==len(g['materials'])==len(g['images'])==len(g['nodes'])==1 and not any(k in g for k in('skins','animations','cameras'));primitive=g['meshes'][0]['primitives'][0];assert len(g['meshes'][0]['primitives'])==1 and 'COLOR_0'not in primitive['attributes']and not primitive.get('targets')
            material=g['materials'][0];assert material['alphaMode']=='MASK'and material['doubleSided']and abs(material.get('alphaCutoff',.5)-.5)<1e-6 and material['pbrMetallicRoughness'].get('baseColorFactor',[1,1,1,1])==[1,1,1,1]
            assert g['nodes'][0].get('translation',[0,0,0])==[0,0,0]and g['nodes'][0].get('scale',[1,1,1])==[1,1,1];assert all(s['magFilter']==9728 and s['minFilter']in(9728,9984)for s in g['samplers'])
            view=g['bufferViews'][g['images'][0]['bufferView']];assert binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]==png;assert g['accessors'][primitive['indices']]['count']==len(evaluated.loop_triangles)*3
            def read(index):
                a=g['accessors'][index];view=g['bufferViews'][a['bufferView']];w={'VEC3':3,'VEC2':2}[a['type']];assert a['componentType']==5126;start=view.get('byteOffset',0)+a.get('byteOffset',0)
                return [struct.unpack_from('<'+'f'*w,binary,start+i*view.get('byteStride',w*4))for i in range(a['count'])]
            attrs={k:read(primitive['attributes'][k])for k in('POSITION','NORMAL','TEXCOORD_0')};corners={};errors=[0,0,0]
            for p in evaluated.polygons:
                for li in p.loop_indices:
                    v=evaluated.vertices[evaluated.loops[li].vertex_index].co;normal=evaluated.corner_normals[li].vector;uv=evaluated.uv_layers[0].data[li].uv;pos=(v.x,v.z,-v.y);corners.setdefault(tuple(round(c,6)for c in pos),[]).append((pos,(uv.x,1-uv.y),(normal.x,normal.z,-normal.y)))
            for i,pos in enumerate(attrs['POSITION']):
                candidates=corners.get(tuple(round(c,6)for c in pos));assert candidates;got=(pos,attrs['TEXCOORD_0'][i],attrs['NORMAL'][i]);best=min(candidates,key=lambda ex:max(abs(a-b)for ga,ea in zip(got,ex)for a,b in zip(ga,ea)));current=[max(abs(a-b)for a,b in zip(ga,ea))for ga,ea in zip(got,best)];assert current[0]<1e-6 and current[1]<1e-6 and current[2]<1.5e-4;errors=[max(a,b)for a,b in zip(errors,current)]
            module_reports.append({'variant':variant,'active_bounds':[lo,hi],'triangles':len(evaluated.loop_triangles),'source_raw_triangles_with_preserved_sprigs':len(raw.polygons)*2,'export_meshes_surfaces':[1,1],'native_MASK':True,'texels_per_m':512,'coarse_pixel_cells_per_m':16,'source_evaluated_binary_errors_position_uv_normal':errors,'sha256':hashlib.sha256(rawglb).hexdigest()})
        obj.evaluated_get(dg).to_mesh_clear()
    manifest=json.loads((HERE/'leaf_plus_6blocks_v1_manifest.json').read_text());cells={tuple(spec['cell'])for spec in manifest['cells']};assert cells=={(0,0,0),(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1)}
    for spec in manifest['cells']:assert tuple(bpy.data.objects[spec['object']].location)==tuple(spec['cell'])
    alo=[min(v[k]for v in assembly_points)for k in range(3)];ahi=[max(v[k]for v in assembly_points)for k in range(3)];assert alo==[-1.5,-1.5,0]and ahi==[1.5,1.5,2]
    return {'status':'PASS','modules':module_reports,'original_source_PNG_sha256':expected['PNG_sha256'],'current_RGBA_exact_four_green_remap_gold_preserved_black_cutout':True,'core_RGBA_alpha_values':[0,1],'core_transparent_fraction':sum(target[i]==0 for i in range(3,len(target),4))/(512*512),'packed_embedded_current_PNG_match':True,'UV_density_max_error':density_error,'assembly_active_bounds':[alo,ahi],'assembly_active_triangles':sum(core_triangles[n]for n in CORE_NAMES if n.startswith('ENV_LeafCluster_')),'raw_sprigs_cross_branches_preserved_but_hidden':True,'preservation_changes':sorted(allowed),'baseline_digest':baseline['digest'],'scope':'Current visible core-only Blender study; no game/bulk changes'}

if __name__=='__main__':
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'));r=audit_current_leaf_cores();(EVIDENCE/'validation_current_leaf_core_only.json').write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2))
