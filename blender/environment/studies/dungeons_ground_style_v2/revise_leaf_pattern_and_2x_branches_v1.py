"""Foreground-only original leafy pattern and root-anchored2x crossed branch revision."""
import bpy,json,sys,hashlib,math,random
from pathlib import Path
from mathutils import Vector
assert not bpy.app.background,'Source writes require the current foreground Blender window'
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare
PALETTE=['324420','435222','59642b','687333','78853b','859344','3c4b1f']

def physical_leaf_uv(mesh,variant):
    uv=mesh.uv_layers.get('UV_Leaf_Pattern_32TexelsPerMetre')or mesh.uv_layers.new(name='UV_Leaf_Pattern_32TexelsPerMetre')
    phase={'A':0,'B':.3125,'C':.625}[variant]
    for p in mesh.polygons:
        fixed=max(range(3),key=lambda k:abs(p.normal[k]));axes=[k for k in range(3)if k!=fixed]
        for li in p.loop_indices:
            v=mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv=(v[axes[0]]+phase,v[axes[1]]+phase)
    mesh.uv_layers.active_index=list(mesh.uv_layers).index(uv)

assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve()
baseline=json.loads((EVIDENCE/'before_leaf_pattern_and_2x_branches_fingerprints.json').read_text());assert not compare(baseline['data'])
# Original repeatable32px leafy tile: curved stair-step elongated leaves with muted veins.
rng=random.Random(519773);tile=[[1 for x in range(32)]for y in range(32)]
for leaf in range(25):
    cx,cy=rng.randrange(32),rng.randrange(32);rotation=rng.randrange(4);length=rng.randrange(7,11);base=rng.choice((2,3,4));edge=rng.choice((0,6));vein=min(5,base+1)
    for y in range(length):
        t=(y+.5)/length;half=max(0,int(3*math.sin(math.pi*t)));drift=int(y*.27);width=half*2+1
        for x in range(-half,half+1):
            px,py=x+drift,y
            for _ in range(rotation):px,py=-py,px
            color=edge if abs(x)==half and half>0 else base
            if x==0 and 1<=y<length-1:color=vein
            tile[(cy+py)%32][(cx+px)%32]=color
rgb=[tuple(int(h[k:k+2],16)/255 for k in(0,2,4))for h in PALETTE];pixels=[value for row in tile for c in row for value in (*rgb[c],1)]
image=bpy.data.images.new('IMG_LeafModules_V1_OriginalLeafTile',width=32,height=32,alpha=False);image.colorspace_settings.name='sRGB';image.pixels.foreach_set(pixels);image.update();path=HERE/'textures/leaf_modules_v1_original_leaf_tile.png';image.filepath_raw=str(path);image.file_format='PNG';image.save();raw=path.read_bytes();image.pack(data=raw,data_len=len(raw));assert image.packed_file.data==raw
material=bpy.data.materials.new('MAT_LeafModules_V1_DirectLeafPattern');material.use_nodes=True;material.use_backface_culling=False;bsdf=material.node_tree.nodes['Principled BSDF'];bsdf.inputs['Roughness'].default_value=1;bsdf.inputs['Specular IOR Level'].default_value=0
texture=material.node_tree.nodes.new('ShaderNodeTexImage');texture.image=image;texture.interpolation='Closest';texture.extension='REPEAT';material.node_tree.links.new(texture.outputs['Color'],bsdf.inputs['Base Color'])
# Retain the original source vertex-albedo material unmodified, with a hidden archival user.
archive=bpy.data.meshes.new('REVIEW_Preserved_LeafVertexMaterial');archive.materials.append(bpy.data.materials['MAT_LeafModules_V1_OpaqueLinearVertexAlbedo']);archive_obj=bpy.data.objects.new(archive.name,archive);bpy.data.collections['LEAF_MODULES_1Block_V1'].objects.link(archive_obj);archive_obj.hide_render=True;archive_obj.hide_set(True);archive_obj['display_only']=True
# Recolour the existing branch sprite with the same leaf language, preserving its entire alpha mask.
sprite=bpy.data.images['IMG_LeafBranch_V1_OriginalSpriteAtlas'];spritepixels=list(baseline['branch_pixels'])
for y in range(40):
    for x in range(120):
        offset=(y*120+x)*4
        if spritepixels[offset+3]==1:
            variant=x//40;c=tile[(y+variant*5)%32][(x+variant*7)%32];spritepixels[offset:offset+3]=rgb[c]
sprite.pixels.foreach_set(spritepixels);sprite.update();sprite.save();raw=Path(sprite.filepath_raw).read_bytes();sprite.pack(data=raw,data_len=len(raw));assert sprite.packed_file.data==raw
for variant in ('A','B','C'):
    core=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant];core.data.materials[0]=material;physical_leaf_uv(core.data,variant)
    branch=bpy.data.objects[core.name+'_CrossBranches'];bm=branch.data;old=baseline['branches'][variant]['vertices']
    for p in bm.polygons:
        points=[Vector(old[vi])for vi in p.vertices];root=(points[0]+points[1])*.5
        for vi,point in zip(p.vertices,points):bm.vertices[vi].co=root+2*(point-root)
    bm.update()
    for o in list(bpy.context.selected_objects):o.select_set(False)
    core.select_set(True);branch.select_set(True);bpy.context.view_layer.objects.active=core;location=core.location.copy();core.location=(0,0,0);bpy.context.view_layer.update();export=HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb')
    try:bpy.ops.export_scene.gltf(filepath=str(export),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_texcoords=True,export_materials='EXPORT',export_vertex_color='NONE',export_animations=False,export_morph=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=False,export_apply=False)
    finally:core.location=location;bpy.context.view_layer.update()
from validate_leaf_pattern_and_scale_v1 import audit_leaf_pattern
report=audit_leaf_pattern();manifest={'status':'Requested original leaf-pattern appearance in current7greens +2xroot-anchored crossed branches; awaiting art review','core_tile':'textures/leaf_modules_v1_original_leaf_tile.png','tile_size_px':[32,32],'core_texels_per_m':32,'pattern':'Original curved stair-step/blunt elongated pixel leaf clumps with muted veins; screenshot only guided leaf language, no net/text/URL copied','palette_srgb':['#'+c for c in PALETTE],'core_alpha':'OPAQUE tile with dark-green negative spaces; actual geometry holes unchanged','branch_alpha':'Exact previous0/1 sprite mask preserved; RGB refreshed to original leaf pattern','branch_scale':'width andlength2x about each canonical preservedroot; UVs/sharedaxis/orientation unchanged; noncumulative baseline','export':'TextureRGB directly, whitebaseColorFactor, noCOLOR_0; original sourceColor attribute retained','audit':report}
(HERE/'leaf_pattern_and_2x_branches_v1_manifest.json').write_text(json.dumps(manifest,indent=2))
for file in ('leaf_modules_v1_manifest.json','textured_leaf_branches_v1_manifest.json'):
    path=HERE/file;metadata=json.loads(path.read_text());metadata['current_leaf_pattern_and_size_revision']='leaf_pattern_and_2x_branches_v1_manifest.json';metadata['current_contract']='2textured meshes/surfaces,OPAQUEcore+MASKcrossbranches, textureRGBdirect withoutCOLOR_0 multiplication';metadata['current_audit']=report
    for old,new in zip(metadata['modules'],report['modules']):old['sha256']=new['sha256']
    if file.startswith('textured'):metadata['texture_png_sha256']=hashlib.sha256(Path(sprite.filepath_raw).read_bytes()).hexdigest()
    path.write_text(json.dumps(metadata,indent=2))
for o in list(bpy.context.selected_objects):o.select_set(False)
core=bpy.data.objects['ENV_LeafBlock_1m_V1_A'];core.select_set(True);bpy.context.view_layer.objects.active=core
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'),check_existing=False)
result={'status':'New leafy pattern and2xcrossed branches visible and saved LIVE','audit':report}
