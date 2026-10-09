"""Live-only direct user-supplied PNG and exact full-face mapping; no regenerated/recoloured core pixels."""
import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Vector
assert not bpy.app.background,'Modify only the current live Blender window'
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare
from validate_exact_user_leaf_texture_v1 import UV_NAME,coplanar_assembly_pairs,audit_exact_texture
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve()
before=json.loads((EVIDENCE/'before_exact_user_leaf_texture_fingerprints.json').read_text());assert not compare(before['data']);assert not bpy.data.images.get('IMG_LeafModules_UserProvided_512')
source=Path('C:/Users/ADMIN/AppData/Local/Temp/codex-clipboard-9fb37aa4-1b31-4b43-91e5-ff38568cf74e.png');png=source.read_bytes();assert hashlib.sha256(png).hexdigest()=='843cebc821ccb8fdd19cd709ef648890eac2cb5fb561c50b7fbd41d3afca7ed7';path=HERE/'textures/leaf_modules_user_provided_512.png';path.write_bytes(png)
im=bpy.data.images.load(str(path),check_existing=False);im.name='IMG_LeafModules_UserProvided_512';im.colorspace_settings.name='sRGB';im.pack(data=png,data_len=len(png));assert im.packed_file.data==png
mat=bpy.data.materials['MAT_LeafModules_V1_DirectLeafPattern'];tex=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE');oldmaterial=mat.copy();oldmaterial.name='REVIEW_Preserved_OriginalLeafPatternMaterial';archive=bpy.data.meshes.new('REVIEW_Preserved_OriginalLeafPattern');archive.materials.append(oldmaterial);ao=bpy.data.objects.new(archive.name,archive);bpy.data.collections['LEAF_MODULES_1Block_V1'].objects.link(ao);ao.hide_render=True;ao.hide_set(True);tex.image=im
# Assembly-only three sprig cards get a0.15mm offset; core module library remains exact.
pairs=coplanar_assembly_pairs();offsets={};moved=set()
for pair in pairs:
    name,pi=pair['a'];obj=bpy.data.objects[name];m=obj.data;assert m.attributes['leaf_part'].data[pi].value==1
    for vi in m.polygons[pi].vertices:
        key=(m.name,vi)
        if key in moved:continue
        moved.add(key);delta=[0,0,0];delta[pair['axis']]=.00015;m.vertices[vi].co[pair['axis']]+=.00015;offsets.setdefault(m.name,{})[str(vi)]=delta
for name in offsets:bpy.data.meshes[name].update()
assert not coplanar_assembly_pairs()
# Full supplied tile on every logical structural face, no variant phase or half-tile wrap.
for name in before['core_meshes']:
    mesh=bpy.data.meshes[name];uv=mesh.uv_layers[0];uv.name=UV_NAME
    for p in mesh.polygons:
        side=mesh.attributes['core_face'].data[p.index].value;kind=mesh.attributes['leaf_part'].data[p.index].value;fixed=max(range(3),key=lambda k:abs(p.normal[k]));axes=[k for k in range(3)if k!=fixed]
        for li in p.loop_indices:
            v=mesh.vertices[mesh.loops[li].vertex_index].co
            if kind==0:coord=[(v.y+.5,v.z),(.5-v.y,v.z),(.5-v.x,v.z),(v.x+.5,v.z),(v.x+.5,v.y+.5),(v.x+.5,.5-v.y)][side]
            else:coord=[v[k]+(.5 if k<2 else 0)for k in axes]
            uv.data[li].uv=coord
# Derivative branch atlas: exact inputRGB samples within unchanged original transparent silhouette.
sprite=bpy.data.images['IMG_LeafBranch_V1_OriginalSpriteAtlas'];pixels=list(before['branch_pixels']);inputpixels=list(im.pixels)
for y in range(40):
    for x in range(120):
        i=(y*120+x)*4
        if pixels[i+3]:j=((y*512//40)*512+((x%40)*512//40))*4;pixels[i:i+3]=inputpixels[j:j+3]
sprite.pixels.foreach_set(pixels);sprite.update();sprite.save();spritepng=Path(sprite.filepath_raw).read_bytes();sprite.pack(data=spritepng,data_len=len(spritepng))
for variant in ('A','B','C'):
    core=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant];branch=bpy.data.objects[core.name+'_CrossBranches']
    for o in list(bpy.context.selected_objects):o.select_set(False)
    core.select_set(True);branch.select_set(True);bpy.context.view_layer.objects.active=core;display=core.location.copy();core.location=(0,0,0);bpy.context.view_layer.update()
    try:bpy.ops.export_scene.gltf(filepath=str(HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_texcoords=True,export_materials='EXPORT',export_vertex_color='NONE',export_animations=False,export_morph=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=False,export_apply=False)
    finally:core.location=display;bpy.context.view_layer.update()
manifest={'status':'Exact supplied user PNG; latest explicit request supersedes original7green pattern','source_image':str(source),'stored_PNG':'textures/leaf_modules_user_provided_512.png','source_PNG_sha256':hashlib.sha256(png).hexdigest(),'core_image':'IMG_LeafModules_UserProvided_512','core_pattern':'Entire512px input tile per logical1m cube face; no recolour/generation/phase/crop','core_alpha':'Opaque input, black preserved as RGB0/0/0 alpha1; real geometry holes unchanged','branch_pattern':'Nearest RGB samples from exact source in previous0/1 silhouette; composite derivative, not byte-identical to source','UV_name':UV_NAME,'texels_per_m':512,'coarse_pixel_cells_per_m':16,'branch_geometry':'Existing2xroot-anchored perpendicular crossed planes unchanged','assembly_sprig_offsets':offsets,'assembly_overlap_pairs_before':pairs,'assembly_overlap_pairs_after':0,'scope':'Live current Blender file only; study-local restGLBs; no game/bulk work'}
(HERE/'exact_user_leaf_texture_v1_manifest.json').write_text(json.dumps(manifest,indent=2))
# Immediately expose the actual live updated material before diagnostics.
for o in list(bpy.context.selected_objects):o.select_set(False)
core=bpy.data.objects['ENV_LeafBlock_1m_V1_A'];core.select_set(True);bpy.context.view_layer.objects.active=core
for window in bpy.context.window_manager.windows:
    for area in window.screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;space.shading.type='MATERIAL';space.shading.use_scene_world=False;space.shading.use_scene_lights=False;space.region_3d.view_location=(25.5,3.2,.68);space.region_3d.view_distance=3;space.region_3d.view_rotation=(Vector((25.5,3.2,.6))-Vector((27,1,2))).to_track_quat('-Z','Y');space.region_3d.view_perspective='ORTHO';area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'),check_existing=False)
report=audit_exact_texture();manifest['audit']=report;(HERE/'exact_user_leaf_texture_v1_manifest.json').write_text(json.dumps(manifest,indent=2))
result={'status':'Exact user PNG now visible and saved LIVE; suppliedRGBA verified','audit':report}
