"""Original stepped 3×3×2m cuboid leaf bush, authored in the live current Blender study."""
import bpy,json,sys,random,hashlib
from pathlib import Path
from mathutils import Vector
assert not bpy.app.background,'Source writes require the connected foreground Blender session'
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3];EVIDENCE=ROOT/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare
from validate_leaf_bush_v1 import audit_bush
assert Path(bpy.data.filepath).resolve()==(HERE/'dungeons_ground_style_v2.blend').resolve()
baseline=json.loads((EVIDENCE/'before_leaf_bush_fingerprints.json').read_text());assert not compare(baseline['data'])
assert not bpy.data.objects.get('ENV_LeafBush_3x3x2m_V1')
collection=bpy.data.collections.new('LEAF_BUSH_3x3Blocks_V1');bpy.context.scene.collection.children.link(collection)
# Original dense leaf clusters, not a terrain image. Six orientation variants with gutters.
palette=['30492a','3b532d','485f32','566c38','66783f','737f49','868b56','8e8957','99925e']
rgb=[tuple(int(h[i:i+2],16)/255 for i in(0,2,4))for h in palette]
width,height=336,224;pixels=[0.0]*(width*height*4)
for tile in range(6):
    rng=random.Random(490831+tile*839);canvas=[[1 for x in range(96)]for y in range(96)]
    def rect(x,y,w,h,c):
        for iy in range(y,y+h):
            for ix in range(x,x+w):canvas[iy%96][ix%96]=c
    # Broad irregular underlying shadow/highlight masses, then angular connected leaf patches.
    for _ in range(30):rect(rng.randrange(96),rng.randrange(96),rng.randrange(10,23),rng.randrange(6,16),rng.choice([0,1,2,5]))
    for _ in range(820):
        x,y=rng.randrange(96),rng.randrange(96);w,h=rng.randrange(3,7),rng.randrange(2,4)
        c=rng.choices(range(9),weights=[24,23,18,14,7,7,4,2,1])[0]
        rect(x,y,w,h,c);rect(x+2,y+h,max(2,w-4),2,c);rect(x-1,y+1,2,max(1,h-2),c)
        if rng.random()<.37:rect(x+2,y+1,max(2,w-3),1,max(0,c-1))
    tx,ty=(tile%3)*112,(tile//3)*112
    for y in range(112):
        for x in range(112):
            c=rgb[canvas[(y-8)%96][(x-8)%96]];offset=((ty+y)*width+tx+x)*4;pixels[offset:offset+4]=[*c,1]
image=bpy.data.images.new('IMG_LeafBush_V1_OriginalClusterAtlas',width=width,height=height,alpha=False);image.colorspace_settings.name='sRGB';image.pixels.foreach_set(pixels);image.update()
texture=HERE/'textures/leaf_bush_v1_original_clusters.png';texture.parent.mkdir(exist_ok=True);image.filepath_raw=str(texture);image.file_format='PNG';image.save();image.pack()
mat=bpy.data.materials.new('MAT_LeafBush_V1_OpaqueNearestAtlas');mat.use_nodes=True;mat.diffuse_color=(*rgb[1],1)
principled=mat.node_tree.nodes.get('Principled BSDF');principled.inputs['Roughness'].default_value=1;principled.inputs['Specular IOR Level'].default_value=0
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Closest';tex.extension='EXTEND';mat.node_tree.links.new(tex.outputs['Color'],principled.inputs['Base Color'])
cells={(x,y,0)for x in range(3)for y in range(3)if (x,y)not in ((0,0),(2,0))}|{(x,y,1)for x,y in [(1,1),(2,1),(1,2),(2,2),(0,2)]}
directions=[((1,0,0),[(1,0,0),(1,1,0),(1,1,1),(1,0,1)]),((-1,0,0),[(0,1,0),(0,0,0),(0,0,1),(0,1,1)]),((0,1,0),[(1,1,0),(0,1,0),(0,1,1),(1,1,1)]),((0,-1,0),[(0,0,0),(1,0,0),(1,0,1),(0,0,1)]),((0,0,1),[(0,0,1),(1,0,1),(1,1,1),(0,1,1)]),((0,0,-1),[(0,1,0),(1,1,0),(1,0,0),(0,0,0)])]
verts=[];indices={};faces=[];face_axes=[];cell_ids=[];face_uvs=[]
for cell in sorted(cells):
    for axis,(direction,corners)in enumerate(directions):
        if tuple(cell[k]+direction[k]for k in range(3))in cells:continue
        face=[];uvs=[]
        for corner in corners:
            grid=tuple(cell[k]+corner[k]for k in range(3))
            if grid not in indices:indices[grid]=len(verts);verts.append((grid[0]-1.5,grid[1]-1.5,grid[2]))
            face.append(indices[grid])
            if axis<2:a,b=grid[1],grid[2]
            elif axis<4:a,b=grid[0],grid[2]
            else:a,b=grid[0],grid[1]
            uvs.append(((axis%3*112+8+a*32)/width,(axis//3*112+8+b*32)/height))
        faces.append(face);face_uvs.append(uvs);face_axes.append(axis);cell_ids.append(cell[0]+cell[1]*3+cell[2]*9)
m=bpy.data.meshes.new('ENV_LeafBush_3x3x2m_V1_UnitBlockMesh');m.from_pydata(verts,[],faces);m.materials.append(mat);m.update()
uv=m.uv_layers.new(name='UV_Leaf_32TexelsPerMetre');a=m.attributes.new(name='block_index',type='INT',domain='FACE');b=m.attributes.new(name='face_axis',type='INT',domain='FACE')
for p,uvs,cellid,axis in zip(m.polygons,face_uvs,cell_ids,face_axes):
    a.data[p.index].value=cellid;b.data[p.index].value=axis
    for li,value in zip(p.loop_indices,uvs):uv.data[li].uv=value
obj=bpy.data.objects.new('ENV_LeafBush_3x3x2m_V1',m);collection.objects.link(obj);obj.location=(27,3.2,1)
obj['authoring_status']='User-requested original 3×3×2m leaf bush; Blender-only art review pending';obj['unit_block_m']=1;obj['texture_texels_per_m']=32;obj['provenance']='Original seeded rectangular leaf clusters; user reference for cuboid foliage silhouette only'
for x in range(3):
    for y in range(3):
        o=bpy.data.objects['REVIEW_TallGolden_Platform_21'].copy();o.name='REVIEW_LeafBush_Platform_'+str(x)+'_'+str(y);collection.objects.link(o);o.location=(26+x,2.2+y,0)
cal=bpy.data.objects['REVIEW_TallGolden_Platform_21'].copy();cal.name='REVIEW_LeafBush_1m_Calibration';collection.objects.link(cal);cal.location=(29.5,2.2,0)
label=bpy.data.objects['REVIEW_TallGolden_Actual_Height_Label'].copy();label.data=label.data.copy();label.name='REVIEW_LeafBush_Dimensions_Label';collection.objects.link(label);label.location=(25.5,1.1,.04);label.data.size=.16;label.data.body='LEAF BUSH / 3 x 3 BLOCKS / 2 m\n1 BLOCK = 1 m / PLAYER = 1.8 m'
# Display-only imported actual R15 rest reference, source file untouched.
actor=ROOT/'game_mobile_3d/assets/characters/r15/player_r15_combat_strafe_v1.glb';actor_hash=hashlib.sha256(actor.read_bytes()).hexdigest();old_objects=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(actor),import_pack_images=True)
new_objects=set(bpy.data.objects)-old_objects
reference=bpy.data.collections.new('REVIEW_LeafBush_R15_Rest_1p8m');collection.children.link(reference)
for o in new_objects:
    for c in list(o.users_collection):c.objects.unlink(o)
    reference.objects.link(o);o['display_only']=True;o['reference_only']='Actual R15 source rest proportions,1.8m; no character source edits'
    if o.animation_data:o.animation_data_clear()
    if o.type=='ARMATURE':o.data.pose_position='REST'
    if o.type=='MESH' and not o.parent and not o.data.materials:o.hide_render=True;o.hide_set(True)
for o in new_objects:
    if not o.parent:o.location+=Vector((30.7,3.2,1))
assert hashlib.sha256(actor.read_bytes()).hexdigest()==actor_hash
report=audit_bush()
for o in list(bpy.context.selected_objects):o.select_set(False)
obj.select_set(True);bpy.context.view_layer.objects.active=obj;display=obj.location.copy();obj.location=(0,0,0);bpy.context.view_layer.update()
export=HERE/'exports/leaf_bush_3x3x2m_v1.glb'
try:bpy.ops.export_scene.gltf(filepath=str(export),export_format='GLB',use_selection=True,export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_animations=False,export_morph=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=False,export_apply=False)
finally:obj.location=display;bpy.context.view_layer.update()
manifest={'status':'Blender-only study, awaiting art review','object':obj.name,'source_file':str(HERE/'dungeons_ground_style_v2.blend'),'export':'exports/leaf_bush_3x3x2m_v1.glb','sha256':hashlib.sha256(export.read_bytes()).hexdigest(),'palette_srgb':['#'+h for h in palette],'texture':'textures/leaf_bush_v1_original_clusters.png','texture_sha256':hashlib.sha256(texture.read_bytes()).hexdigest(),'texture_generation':'Original seeded irregular connected rectangular leaf clusters; six face-direction variants,8pixel gutters','cell_coordinates':sorted(cells),'source_units':'1 metre per cuboid block, constant32texels/m all axes','actor_reference_sha256':actor_hash,'audit':report}
(HERE/'leaf_bush_v1_manifest.json').write_text(json.dumps(manifest,indent=2))
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        space=area.spaces.active;space.region_3d.view_location=(26,3.3,1.8);space.region_3d.view_distance=12;space.region_3d.view_perspective='ORTHO';area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
result={'status':'New cuboid leaf bush and actual1.8m R15 rest reference now live in SAME window/file','audit':report,'export_sha256':manifest['sha256'],'imported_reference_objects':len(new_objects)}

