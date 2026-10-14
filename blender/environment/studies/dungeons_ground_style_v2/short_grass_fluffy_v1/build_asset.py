"""Additive grass candidate builder. Run on backed-up environment, never animation UI."""
import bpy, sys, json, math, random, hashlib
from pathlib import Path
from mathutils import Vector

HERE=Path(__file__).resolve().parent
STUDY=HERE.parent
ROOT=STUDY.parents[3]
EVIDENCE=ROOT/'.validation/short_grass_fluffy_v1'
sys.path.insert(0,str(STUDY))
from flower_preservation import compare, snapshot
baseline=json.loads((EVIDENCE/'before_fingerprints.json').read_text())
assert not compare(baseline), 'Environment baseline changed'
assert 'Vegetation_Grass_Pending' not in bpy.data.collections
scene=bpy.context.scene
original_camera=scene.camera
root=bpy.data.collections.new('Vegetation_Grass_Pending');scene.collection.children.link(root)
root['status']='PENDING REVIEW';root['future_siblings']='TallGrass / Fern / Flowers / Bush may be added separately; do not overwrite this candidate'
def collection(name):
    c=bpy.data.collections.new(name);root.children.link(c);c['status']='PENDING REVIEW';return c
masters=collection('01_ShortGrass_Fluffy_v1_Four_Colors')
patch=collection('02_FluffyGrass_Demonstration_Patch')
ground=collection('03_Existing_GrassBlock_Linked_Copies')
reviews=collection('04_Review_Cameras_And_Labels')
img=bpy.data.images.load(str(HERE/'ShortGrass_Fluffy_v1_Atlas.png'),check_existing=False)
img.name='IMG_ShortGrass_Fluffy_v1_Original_Atlas';img.colorspace_settings.name='sRGB';img.alpha_mode='STRAIGHT';img.pack()
mat=bpy.data.materials.new('MAT_ShortGrass_Fluffy_v1_PixelCutout')
mat.use_nodes=True;mat.use_backface_culling=False;mat.surface_render_method='DITHERED';mat.alpha_threshold=.5
mat['status']='PENDING REVIEW';mat['texture_filter']='Closest / glTF NEAREST';mat['alpha_contract']='Binary cutout .5, double sided; no blend transparency'
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=1;bs.inputs['Specular IOR Level'].default_value=0
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.name='Original16pxTiles_8pxGutters';tex.image=img;tex.interpolation='Closest';tex.extension='EXTEND'
uvnode=mat.node_tree.nodes.new('ShaderNodeUVMap');uvnode.uv_map='UV_Atlas'
clip=mat.node_tree.nodes.new('ShaderNodeMath');clip.name='Alpha_Cutout_05';clip.operation='ROUND'
mat.node_tree.links.new(uvnode.outputs['UV'],tex.inputs['Vector']);mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
mat.node_tree.links.new(tex.outputs['Alpha'],clip.inputs[0]);mat.node_tree.links.new(clip.outputs[0],bs.inputs['Alpha'])
# World-up thin-foliage shading on both faces. The engine companion material
# implements the same normal explicitly; no extra light or emission is added.
normal=mat.node_tree.nodes.new('ShaderNodeCombineXYZ');normal.name='Foliage_World_Up_Normal';normal.inputs['Z'].default_value=1
mat.node_tree.links.new(normal.outputs[0],bs.inputs['Normal'])
names=['SoftYellow','DustyPink','Lavender','SageGreen'];objects=[]
specs=[{'az':30,'height':.40,'width':.46,'radius':0,'lean':.018},
       {'az':120,'height':.375,'width':.44,'radius':.015,'lean':.014}]
for i,az in enumerate((12,102,192,282)):
    specs.append({'az':az,'height':(.31,.335,.30,.325)[i],'width':(.39,.37,.41,.38)[i],'radius':.06,'lean':.14})
for variant,name in enumerate(names):
    verts=[];faces=[];uvs=[];weights=[];card_ids=[]
    for ci,spec in enumerate(specs):
        az=math.radians(spec['az']);tangent=Vector((math.cos(az),math.sin(az),0));out=Vector((-math.sin(az),math.cos(az),0))
        # Two quad strips per card support future anchored sway without added bones.
        start=len(verts)
        for t in (0,.42,1):
            centre=out*(spec['radius']+spec['lean']*t*t)+Vector((0,0,-.012+spec['height']*t))
            for side in (-1,1):
                verts.append(tuple(centre+tangent*side*spec['width']/2))
                u=(variant*32+8+(0 if side==-1 else 16))/128
                v=(8+16*t)/32
                uvs.append((u,v));weights.append(t*t)
        for ring in range(2):
            a=start+ring*2;faces.append((a,a+1,a+3,a+2));card_ids.append(ci)
    mesh=bpy.data.meshes.new('MESH_ShortGrass_Fluffy_v1_'+name);mesh.from_pydata(verts,[],faces);mesh.update();mesh.materials.append(mat)
    uv=mesh.uv_layers.new(name='UV_Atlas');wind=mesh.uv_layers.new(name='UV2_WindWeight_CardID')
    ids=mesh.attributes.new(name='card_index',type='INT',domain='FACE')
    for p,ci in zip(mesh.polygons,card_ids):
        p.use_smooth=True;ids.data[p.index].value=ci
        for li in p.loop_indices:
            vi=mesh.loops[li].vertex_index;uv.data[li].uv=uvs[vi];wind.data[li].uv=(weights[vi],ci/5)
    # Upward-biased normals emulate the reference's upward lighting, preventing
    # dark vertical rectangles while preserving a small side response.
    mesh.normals_split_custom_set([(0,0,1)]*len(mesh.loops))
    mesh.uv_layers.active_index=0
    obj=bpy.data.objects.new('ShortGrass_Fluffy_v1_'+name,mesh);masters.objects.link(obj)
    obj.visible_shadow=False
    obj['status']='PENDING REVIEW';obj['asset']='ShortGrass_Fluffy_v1';obj['color_variation']=name
    obj['reference']='Os Colorful Grasses (Tall): visual/technical study only. All final texture pixels and geometry are original.'
    obj['wind_contract']='UV2.x = squared normalized height (0 at roots, .1764 middle, 1 tips). UV2.y = cardID/5 in Blender; glTF V flips, decode cardID=(1-UV2.y)*5. No COLOR_0, bones or wind system.'
    obj['origin_contract']='Bottom-centred, Blender Z-up to Godot Y-up; root geometry -0.012m below placement origin, top0.388m; one block=1m'
    obj['ground_contract']='Root palette from unchanged DI_V3_grass_top_0; no AO decal or fake dark root disk'
    group=obj.vertex_groups.new(name='Wind_Sway');anchor=obj.vertex_groups.new(name='Wind_Anchors')
    for vi,w in enumerate(weights):group.add([vi],w,'REPLACE');anchor.add([vi],1-w,'REPLACE')
    mesh.calc_loop_triangles();assert len(mesh.loop_triangles)==24
    objects.append(obj)

# All new platforms share the approved block data/materials. No old object edit.
template=bpy.data.objects['ENV_GrassBlock_DI_V3']
def block(name,x,y):
    o=template.copy();o.name=name;o.location=(x,y,0);ground.objects.link(o)
    o['status']='PENDING REVIEW';o['display_only']=True;return o
for i,o in enumerate(objects):
    x=8.2+1.2*i;o.location=(x,-11,1)
    block('SGF_Variant_Platform_'+names[i],x,-11)
for y in range(2):
    for x in range(3):block(f'SGF_Patch_GrassBlock_{x}_{y}',9+x,-8.5+y)
rng=random.Random(492815)
placements=[]
for row in range(5):
    for col in range(7):
        if (row,col) in {(0,0),(4,6),(4,0)}:continue
        i=rng.choices(range(4),weights=[3,2,2,4])[0]
        obj=bpy.data.objects.new(f'SGF_Patch_{row:02}_{col:02}_{names[i]}',objects[i].data);patch.objects.link(obj)
        obj.visible_shadow=False
        x=8.75+col*.40+rng.uniform(-.075,.075);y=-8.78+row*.39+rng.uniform(-.07,.07)
        obj.location=(x,y,1);obj.rotation_euler.z=rng.uniform(-math.pi,math.pi);scale=rng.uniform(.82,1.12);obj.scale=(scale,scale,scale)
        obj['status']='PENDING REVIEW';obj['linked_master']=objects[i].name
        placements.append({'object':obj.name,'variant':names[i],'location':list(obj.location),'scale':scale})
def label(name,text,loc,size):
    data=bpy.data.curves.new(name,'FONT');data.body=text;data.align_x='CENTER';data.size=size;data.extrude=0
    o=bpy.data.objects.new(name,data);reviews.objects.link(o);o.location=loc;o['status']='PENDING REVIEW';return o
for i,name in enumerate(names):label('SGF_Label_'+name,name.replace('SoftYellow','SOFT YELLOW').replace('DustyPink','DUSTY PINK').replace('Lavender','LAVENDER').replace('SageGreen','SAGE GREEN'),(8.2+1.2*i,-11.7,.012),.10)
label('SGF_Label_Status','SHORTGRASS FLUFFY v1 / PENDING REVIEW',(10,-12.08,.012),.13)
def camera(name,loc,target,scale):
    data=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,data);reviews.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=scale;o['status']='PENDING REVIEW';return o
low=camera('SGF_CAM_Low_Gameplay',(13.5,-16.7,3.9),(10,-9.35,1.02),6.4)
elev=camera('SGF_CAM_Elevated',(13.8,-16,9.4),(10,-9.4,.65),7.1)
detail=camera('SGF_CAM_Tuft_Detail',(9.4,-13.1,2.1),(8.2,-11,1.16),1.28)
side=camera('SGF_CAM_Opposite_Detail',(7.1,-8.9,2.0),(8.2,-11,1.16),1.28)

# Match the actual Mobs window's studio preview; preserve scene lighting/world.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;sh=space.shading
            sh.type='MATERIAL';sh.light='STUDIO';sh.studio_light='forest.exr';sh.studiolight_intensity=1;sh.studiolight_rotate_z=0
            sh.studiolight_background_alpha=0;sh.studiolight_background_blur=.5;sh.use_scene_lights=False;sh.use_scene_world=False
            sh.show_shadows=False;sh.show_cavity=False;sh.background_type='THEME';space.overlay.show_overlays=False
            space.region_3d.view_location=(10,-9.4,.9);space.region_3d.view_rotation=elev.rotation_euler.to_quaternion();space.region_3d.view_distance=7.8;space.region_3d.view_perspective='ORTHO'
for o in list(bpy.context.selected_objects):o.select_set(False)
objects[0].select_set(True);bpy.context.view_layer.objects.active=objects[0]
scene.camera=original_camera
assert not compare(baseline),'Original assets or scene settings changed during additive build'
exports=HERE/'exports';exports.mkdir(exist_ok=True)
export_reports=[]
for obj in objects:
    for o in list(bpy.context.selected_objects):o.select_set(False)
    obj.select_set(True);bpy.context.view_layer.objects.active=obj;loc=obj.location.copy();obj.location=(0,0,0)
    path=exports/(obj.name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_texcoords=True,export_materials='EXPORT',export_vertex_color='NONE',export_animations=False,export_morph=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=True,export_apply=False)
    obj.location=loc;export_reports.append({'variant':obj['color_variation'],'path':str(path.relative_to(ROOT)),'bytes':path.stat().st_size})

# Standalone appendable asset-library file; central scene remains review home.
locations=[o.location.copy() for o in objects]
for obj in objects:obj.location=(0,0,0)
bpy.data.libraries.write(str(HERE/'ShortGrass_Fluffy_v1.blend'),set(objects),path_remap='ABSOLUTE',fake_user=True,compress=True)
for obj,loc in zip(objects,locations):obj.location=loc
for o in list(bpy.context.selected_objects):o.select_set(False)
objects[0].select_set(True);bpy.context.view_layer.objects.active=objects[0]
assert not compare(baseline)
bpy.ops.wm.save_as_mainfile(filepath=str(EVIDENCE/'candidate_environment.blend'))
manifest={'status':'PENDING REVIEW','primary_review_scene':str(STUDY/'dungeons_ground_style_v2.blend'),'collection':root.name,'master_collection':masters.name,'objects':[o.name for o in objects],
 'per_tuft':{'cards':6,'quads':12,'triangles':24,'authored_vertices':36,'meshes':1,'materials':1,'textures':1,'height_above_origin_m':.388,'root_penetration_m':.012},
 'shared_atlas':{'pixels':[128,32],'logical_tile':[16,16],'padding_each_edge_px':8,'material':mat.name,'image':img.name},'demo_tufts':len(placements),'copied_existing_blocks':10,'placements':placements,'card_specs':specs,'exports':export_reports,
 'lighting':'Existing scene/world/lights unchanged for renders. Saved viewport matches live Mobs: MATERIAL forest.exr intensity1, scene lights/world off, overlays/shadows/cavity off.',
 'baseline_preserved_before_save':True,'native_asset':str(HERE/'ShortGrass_Fluffy_v1.blend')}
(HERE/'manifest.json').write_text(json.dumps(manifest,indent=2))

# Render only after saving immutable candidate; render setting changes are temporary.
scene.render.resolution_x=1440;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
scene.cycles.samples=48;scene.cycles.use_denoising=True;scene.render.image_settings.file_format='PNG'
for cam,name in [(low,'Low_Gameplay_Existing_Lighting'),(elev,'Elevated_Existing_Lighting'),(detail,'Tuft_Detail_Existing_Lighting'),(side,'Opposite_Detail_Existing_Lighting')]:
    scene.camera=cam;scene.render.filepath=str(HERE/'previews'/(name+'.png'));bpy.ops.render.render(write_still=True)
print('GRASS_BUILD_COMPLETE',json.dumps(manifest['per_tuft']))
