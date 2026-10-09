"""Live-only latest requested grass-green palette, exact supplied pattern and gold, black cutout."""
import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Vector
assert not bpy.app.background
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE));from flower_preservation import compare
GREEN_MAP={(32,77,11):(70,112,47),(38,96,13):(76,122,49),(43,109,14):(84,130,52),(52,131,17):(97,143,60)}
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve()
before=json.loads((EVIDENCE/'before_grass_green_leaf_cutout_fingerprints.json').read_text());assert not compare(before['data']);assert not bpy.data.images.get('IMG_LeafModules_UserPattern_GrassGreenCutout')
source=bpy.data.images['IMG_LeafModules_UserProvided_512'];pixels=list(source.pixels)
for i in range(0,len(pixels),4):
 rgb=tuple(round(v*255)for v in pixels[i:i+3]);pixels[i+3]=0 if rgb==(0,0,0)else 1
 if rgb in GREEN_MAP:pixels[i:i+3]=[v/255 for v in GREEN_MAP[rgb]]
im=bpy.data.images.new('IMG_LeafModules_UserPattern_GrassGreenCutout',width=512,height=512,alpha=True);im.colorspace_settings.name='sRGB';im.alpha_mode='STRAIGHT';im.pixels.foreach_set(pixels);im.update();im.filepath_raw=str(HERE/'textures/leaf_modules_user_pattern_grass_green_cutout.png');im.file_format='PNG';im.save();raw=Path(im.filepath_raw).read_bytes();im.pack(data=raw,data_len=len(raw))
mat=bpy.data.materials['MAT_LeafModules_V1_DirectLeafPattern'];archive=mat.copy();archive.name='REVIEW_Preserved_DarkGreenLeafCutoutMaterial';mesh=bpy.data.meshes.new(archive.name);mesh.materials.append(archive);obj=bpy.data.objects.new(mesh.name,mesh);bpy.data.collections['LEAF_MODULES_1Block_V1'].objects.link(obj);obj.hide_render=True;obj.hide_set(True)
tex=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE');tex.image=im
sprite=bpy.data.images['IMG_LeafBranch_V1_OriginalSpriteAtlas'];sp=list(before['branch_pixels'])
for i in range(0,len(sp),4):
 rgb=tuple(round(v*255)for v in sp[i:i+3])
 if rgb in GREEN_MAP:sp[i:i+3]=[v/255 for v in GREEN_MAP[rgb]]
sprite.pixels.foreach_set(sp);sprite.update();sprite.save();png=Path(sprite.filepath_raw).read_bytes();sprite.pack(data=png,data_len=len(png))
for variant in ('A','B','C'):
 core=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant];branch=bpy.data.objects[core.name+'_CrossBranches']
 for o in list(bpy.context.selected_objects):o.select_set(False)
 core.select_set(True);branch.select_set(True);bpy.context.view_layer.objects.active=core;display=core.location.copy();core.location=(0,0,0);bpy.context.view_layer.update()
 try:bpy.ops.export_scene.gltf(filepath=str(HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_texcoords=True,export_materials='EXPORT',export_vertex_color='NONE',export_animations=False,export_morph=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=False,export_apply=False)
 finally:core.location=display;bpy.context.view_layer.update()
manifest={'status':'Latest requested lighter grass greens, unchanged user pixel layout/gold, black transparent; awaiting visual review','source_PNG':'textures/leaf_modules_user_provided_512.png','source_sha256':hashlib.sha256(Path(source.filepath_raw).read_bytes()).hexdigest(),'current_core_PNG':'textures/leaf_modules_user_pattern_grass_green_cutout.png','current_core_sha256':hashlib.sha256(raw).hexdigest(),'current_core_image':im.name,'green_RGBA_map':[{ 'source':list(a)+[255],'target':list(b)+[255]}for a,b in GREEN_MAP.items()],'palette_provenance':'Four ordered colors sampled from unchanged live grass_top_0.png / DI_V3_grass_top_0','pattern':'Exact supplied pixel positions and categories; only four greenRGB values remapped. All six goldRGB values unchanged.','alpha':'Core blackRGB→0, all nonblack→1; branches existing sprite mask AND nonblack; no translucent values','materials':'Both core and branch nativeMASK,nearest,double-sided,directRGB,basefactorwhite,noCOLOR_0','sourceUV':'UV_UserLeafTile_1RepeatPerMetre; wholelogicalface0..1,512texels/m,16coarsecells/m','preservation':'All geometry,sourceColor,UVs,2xbranchroots/crossangles,6cellplusgrid,earlierplants/wind/pausedbulk unchanged in latest palette phase','scope':'Live sameblend/window,local study restexports,no game'}
(HERE/'leaf_grass_green_cutout_v1_manifest.json').write_text(json.dumps(manifest,indent=2))
for o in list(bpy.context.selected_objects):o.select_set(False)
core=bpy.data.objects['ENV_LeafBlock_1m_V1_A'];core.select_set(True);bpy.context.view_layer.objects.active=core
for window in bpy.context.window_manager.windows:
 for area in window.screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active;space.shading.type='MATERIAL';space.shading.use_scene_world=False;space.shading.use_scene_lights=False;space.region_3d.view_location=(25.5,3.2,.68);space.region_3d.view_distance=3;space.region_3d.view_rotation=(Vector((25.5,3.2,.6))-Vector((27,1,2))).to_track_quat('-Z','Y');space.region_3d.view_perspective='ORTHO';area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'),check_existing=False)
result={'status':'Lighter grass greens with black cutouts LIVE and saved','map':manifest['green_RGBA_map']}
