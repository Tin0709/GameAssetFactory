"""Foreground-only requested black-pixel cutout; exact supplied RGB retained."""
import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Vector
assert not bpy.app.background
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE));from flower_preservation import compare
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve()
before=json.loads((EVIDENCE/'before_black_leaf_cutout_fingerprints.json').read_text());assert not compare(before['data']);assert not bpy.data.images.get('IMG_LeafModules_UserProvided_512_BlackCutout')
source=bpy.data.images['IMG_LeafModules_UserProvided_512'];pixels=list(source.pixels)
for i in range(0,len(pixels),4):pixels[i+3]=0 if pixels[i:i+3]==[0,0,0]else 1
im=bpy.data.images.new('IMG_LeafModules_UserProvided_512_BlackCutout',width=512,height=512,alpha=True);im.colorspace_settings.name='sRGB';im.alpha_mode='STRAIGHT';im.pixels.foreach_set(pixels);im.update();im.filepath_raw=str(HERE/'textures/leaf_modules_user_provided_512_black_cutout.png');im.file_format='PNG';im.save();raw=Path(im.filepath_raw).read_bytes();im.pack(data=raw,data_len=len(raw));assert im.packed_file.data==raw
mat=bpy.data.materials['MAT_LeafModules_V1_DirectLeafPattern'];archive=mat.copy();archive.name='REVIEW_Preserved_ExactOpaqueLeafMaterial';mesh=bpy.data.meshes.new('REVIEW_Preserved_ExactOpaqueLeafMaterial');mesh.materials.append(archive);obj=bpy.data.objects.new(mesh.name,mesh);bpy.data.collections['LEAF_MODULES_1Block_V1'].objects.link(obj);obj.hide_render=True;obj.hide_set(True)
tex=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE');tex.image=im;clip=mat.node_tree.nodes.new('ShaderNodeMath');clip.name='Leaf Core Alpha Clip';clip.operation='ROUND';mat.node_tree.links.new(tex.outputs['Alpha'],clip.inputs[0]);mat.node_tree.links.new(clip.outputs[0],mat.node_tree.nodes['Principled BSDF'].inputs['Alpha']);mat.surface_render_method='DITHERED';mat.use_backface_culling=False
sprite=bpy.data.images['IMG_LeafBranch_V1_OriginalSpriteAtlas'];sp=list(before['branch_pixels'])
for i in range(0,len(sp),4):sp[i+3]=0 if sp[i:i+3]==[0,0,0]else sp[i+3]
sprite.pixels.foreach_set(sp);sprite.update();sprite.save();png=Path(sprite.filepath_raw).read_bytes();sprite.pack(data=png,data_len=len(png))
for variant in ('A','B','C'):
 core=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant];branch=bpy.data.objects[core.name+'_CrossBranches']
 for o in list(bpy.context.selected_objects):o.select_set(False)
 core.select_set(True);branch.select_set(True);bpy.context.view_layer.objects.active=core;display=core.location.copy();core.location=(0,0,0);bpy.context.view_layer.update()
 try:bpy.ops.export_scene.gltf(filepath=str(HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_texcoords=True,export_materials='EXPORT',export_vertex_color='NONE',export_animations=False,export_morph=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=False,export_apply=False)
 finally:core.location=display;bpy.context.view_layer.update()
manifest={'status':'Requested exact source RGB with black made transparent; artistic review pending','original_source_PNG':'textures/leaf_modules_user_provided_512.png','original_source_sha256':hashlib.sha256(Path(source.filepath_raw).read_bytes()).hexdigest(),'derived_core_PNG':'textures/leaf_modules_user_provided_512_black_cutout.png','derived_core_sha256':hashlib.sha256(raw).hexdigest(),'alpha':'Core alpha0 iff sourceRGB=(0,0,0),1 otherwise; branch alpha=previoussilhouette AND RGBnonblack','RGB':'All supplied green/gold/blackRGB pixels exact unchanged; no recolour/noise','materials':'Both core and branch nativeMASK,double-sided,nearest,directRGB,noCOLOR_0','UV':'Full supplied tile per1m logical cube face;512texels/m,16coarsecells/m','geometry':'1m core and2xrooted crossed branches unchanged; six-cell plus arrangement unchanged','scope':'Blender-only local study exports, no game/bulk edits'}
(HERE/'leaf_black_cutout_v1_manifest.json').write_text(json.dumps(manifest,indent=2))
for o in list(bpy.context.selected_objects):o.select_set(False)
core=bpy.data.objects['ENV_LeafBlock_1m_V1_A'];core.select_set(True);bpy.context.view_layer.objects.active=core
for window in bpy.context.window_manager.windows:
 for area in window.screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active;space.shading.type='MATERIAL';space.shading.use_scene_world=False;space.shading.use_scene_lights=False;space.region_3d.view_location=(25.5,3.2,.68);space.region_3d.view_distance=3;space.region_3d.view_rotation=(Vector((25.5,3.2,.6))-Vector((27,1,2))).to_track_quat('-Z','Y');space.region_3d.view_perspective='ORTHO';area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'),check_existing=False)
result={'status':'Black pixels now transparent LIVE and saved; RGB preserved','source_image':source.name,'derived_image':im.name}
