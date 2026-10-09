"""Foreground-only additive crossed cutout branches; fine leaf cores remain exact."""
import bpy,json,sys,random,math,hashlib
from pathlib import Path
from mathutils import Vector,Quaternion
assert not bpy.app.background,'Source authoring requires the existing foreground Blender window'
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve()
baseline=json.loads((EVIDENCE/'before_textured_leaf_branches_fingerprints.json').read_text());assert not compare(baseline['data'])
assert not bpy.data.images.get('IMG_LeafBranch_V1_OriginalSpriteAtlas')
palette=['324420','435222','59642b','687333','78853b','859344','3c4b1f'];rgb=[tuple(int(h[k:k+2],16)/255 for k in(0,2,4))for h in palette]
# Three original blunt pixel leaf sprites: sparse inner holes, jagged outline, centred stalk.
rows=[{3},{2,3,4},{1,2,3,4,5},{2,3,4},{0,1,2,3,5,6},{1,2,3,4,5},{2,3,4},{3,4}]
pixels=[0.0]*(120*40*4)
for tile in range(3):
    rng=random.Random(791133+tile*897)
    for y in range(8):
        cols=set(rows[y])
        if tile==1 and y in (2,5):cols.add(6)
        if tile==2 and y in (1,6):cols.add(1)
        for x in cols:
            color=rgb[rng.choices(range(7),weights=[11,16,21,24,16,6,6])[0]]
            for py in range(4):
                for px in range(4):
                    offset=((4+y*4+py)*120+tile*40+4+x*4+px)*4;pixels[offset:offset+4]=[*color,1]
image=bpy.data.images.new('IMG_LeafBranch_V1_OriginalSpriteAtlas',width=120,height=40,alpha=True);image.colorspace_settings.name='sRGB';image.alpha_mode='STRAIGHT';image.pixels.foreach_set(pixels);image.update()
texture=HERE/'textures/leaf_branch_v1_original_sprites.png';texture.parent.mkdir(exist_ok=True);image.filepath_raw=str(texture);image.file_format='PNG';image.save();png=texture.read_bytes();image.pack(data=png,data_len=len(png));assert image.packed_file.data==png
mat=bpy.data.materials.new('MAT_LeafBranch_V1_NearestCutout');mat.use_nodes=True;mat.use_backface_culling=False;mat.surface_render_method='DITHERED';mat.alpha_threshold=.5
bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=1;bsdf.inputs['Specular IOR Level'].default_value=0
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Closest';tex.extension='EXTEND'
clip=mat.node_tree.nodes.new('ShaderNodeMath');clip.name='Leaf Alpha Clip';clip.operation='ROUND';mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color']);mat.node_tree.links.new(tex.outputs['Alpha'],clip.inputs[0]);mat.node_tree.links.new(clip.outputs[0],bsdf.inputs['Alpha'])
collection=bpy.data.collections.new('LEAF_MODULES_Crossed_Textured_Branches_V1');bpy.data.collections['LEAF_MODULES_1Block_V1'].children.link(collection)
specs=[]
for variant in ('A','B','C'):
    rng=random.Random(872331+ord(variant)*709);core=bpy.data.objects['ENV_LeafBlock_1m_V1_'+variant];verts=[];faces=[];uvs=[];groups=[];sides=[];spec=[]
    for side in range(5):
        count=2 if side<4 else 3
        for i in range(count):
            group=len(spec);width=rng.uniform(.22,.26);length=rng.uniform(.215,.230)if side<4 else rng.uniform(.24,.26)
            if side<4:
                horizontal=Vector([(1,0,0),(-1,0,0),(0,1,0),(0,-1,0)][side]);tangent=Vector((-horizontal.y,horizontal.x,0));root=horizontal*.425+tangent*rng.uniform(-.27,.27)+Vector((0,0,(.30,.69)[i]+rng.uniform(-.05,.05)));growth=(horizontal+Vector((0,0,rng.uniform(.08,.15)))).normalized();basis=tangent
            else:
                px,py=[(-.28,-.14),(.12,.27),(.28,-.25)][i];root=Vector((px,py,.90));growth=Vector((rng.uniform(-.055,.055),rng.uniform(-.055,.055),1)).normalized();basis=growth.cross(Vector((1,0,0))).normalized()
            roll=Quaternion(growth,rng.uniform(.23,1.27));u=roll@basis;v=growth.cross(u).normalized();tip=root+growth*length;tile=rng.randrange(3)
            for direction in (u,v):
                points=[root-direction*width*.5,root+direction*width*.5,tip+direction*width*.5,tip-direction*width*.5];start=len(verts);verts.extend(tuple(p)for p in points);faces.append(tuple(range(start,start+4)));groups.append(group);sides.append(side)
                uvs.extend([((tile*40+4)/120,4/40),((tile*40+36)/120,4/40),((tile*40+36)/120,36/40),((tile*40+4)/120,36/40)])
            spec.append({'branch_index':group,'side':side,'root_xyz':list(root),'tip_xyz':list(tip),'growth_axis':list(growth),'width_m':width,'length_m':length,'sprite_variant':tile})
    m=bpy.data.meshes.new('ENV_LeafBlock_1m_V1_'+variant+'_CrossBranchPlanes');m.from_pydata(verts,[],faces);m.materials.append(mat);m.update();uv=m.uv_layers.new(name='UV_Original_LeafBranchSprite');gid=m.attributes.new(name='branch_index',type='INT',domain='FACE');sideid=m.attributes.new(name='branch_side',type='INT',domain='FACE')
    for p,g,s in zip(m.polygons,groups,sides):
        gid.data[p.index].value=g;sideid.data[p.index].value=s
        for li in p.loop_indices:uv.data[li].uv=uvs[m.loops[li].vertex_index]
    obj=bpy.data.objects.new('ENV_LeafBlock_1m_V1_'+variant+'_CrossBranches',m);collection.objects.link(obj);obj.parent=core;obj.location=(0,0,0);obj['authoring_status']='Original textured branch pairs, two perpendicular zero-thickness planes sharing outward growth axis; review pending';obj['provenance']='Original pixel RGBA sprite, no copied reference pixels'
    for o in list(bpy.context.selected_objects):o.select_set(False)
    core.select_set(True);obj.select_set(True);bpy.context.view_layer.objects.active=core;location=core.location.copy();core.location=(0,0,0);bpy.context.view_layer.update();export=HERE/'exports'/('leaf_block_1m_v1_'+variant.lower()+'.glb')
    try:bpy.ops.export_scene.gltf(filepath=str(export),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_texcoords=True,export_materials='EXPORT',export_vertex_color='NAME',export_vertex_color_name='Color',export_all_vertex_colors=False,export_animations=False,export_morph=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=False,export_apply=False)
    finally:core.location=location;bpy.context.view_layer.update()
    specs.append({'variant':variant,'groups':spec,'path':'exports/'+export.name,'sha256':hashlib.sha256(export.read_bytes()).hexdigest()})
from validate_textured_leaf_branches_v1 import audit_branches
report=audit_branches()
manifest={'status':'User-requested crossed textured branches added to unchanged fine core; Blender art review pending','source_file':'dungeons_ground_style_v2.blend','texture':'textures/'+texture.name,'texture_png_sha256':hashlib.sha256(png).hexdigest(),'sprite_atlas_size':[120,40],'sprite_variants':3,'alpha':'Original0/1 RGBA pixels, ImageAlpha→MathROUND→PrincipledAlpha; exportedMASK cutoff.5','geometry':'11groups per module (2per side +3top), exactly2orthogonal zero-thickness quads/group;44extra triangles, child mesh +core mesh','palette_srgb':['#'+p for p in palette],'modules':specs,'audit':report}
(HERE/'textured_leaf_branches_v1_manifest.json').write_text(json.dumps(manifest,indent=2))
module_manifest_path=HERE/'leaf_modules_v1_manifest.json';module_manifest=json.loads(module_manifest_path.read_text());module_manifest['current_textured_branch_addition']='add_textured_leaf_branches_v1.py';module_manifest['branches_manifest']='textured_leaf_branches_v1_manifest.json';module_manifest['export_structure']='Each module exports selected unchangedcore +branchchild,2meshes/2surfaces,OPAQUEcore/MASKbranch'
for old,new in zip(module_manifest['modules'],specs):old['sha256']=new['sha256']
module_manifest_path.write_text(json.dumps(module_manifest,indent=2))
for o in list(bpy.context.selected_objects):o.select_set(False)
core=bpy.data.objects['ENV_LeafBlock_1m_V1_A'];core.select_set(True);bpy.context.view_layer.objects.active=core
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
result={'status':'Crossed textured branches now visible and saved LIVE in the same Blender file/window','audit':report}
