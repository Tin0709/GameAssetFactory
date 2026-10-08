"""Author editable square-ended v4 grass and rest-only glTF assets in Blender."""
import bpy
import hashlib
import json
import math
import random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[4]
STUDY = Path(__file__).resolve().parent
SOURCE = ROOT/'blender/environment/studies/grass_block_wind_v3/grass_block_wind_v3.blend'
OUT = ROOT/'game_mobile_3d/assets/environment/grassland'
REF = Path('C:/Users/ADMIN/AppData/Local/Temp/codex-clipboard-51777deb-1938-413c-b0b4-490be998ab9d.png')
source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
preserved = {name: hashlib.sha256((OUT/name).read_bytes()).hexdigest() for name in
             ('grass_patch_v3.glb','grass_dirt_block_v3.glb','environment_atlas_64.png','export_manifest.json')}
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
block = bpy.data.objects['ENV_GrassDirt_Block_1m']
block.data = block.data.copy()
scene = bpy.data.scenes.new('ENV_Grass_Block_Reference_V4')
scene.collection.objects.link(block)
bpy.context.window.scene = scene
for old in list(bpy.data.scenes):
    if old != scene: bpy.data.scenes.remove(old)
for obj in list(bpy.data.objects):
    if obj != block: bpy.data.objects.remove(obj, do_unlink=True)
block.animation_data_clear()
block.location = (0,0,0)
original_block_coords = [tuple(v.co) for v in block.data.vertices]
# Approved follow-up: make the physical stepped green cap 15% deeper.
# The same boundary vertices belong to green and dirt faces, so no cracks appear.
for vertex in block.data.vertices:
    if 0 < vertex.co.z < 1:
        vertex.co.z = 1 - (1-vertex.co.z)*1.15
block.data.update()
block['grass_cap_depth_multiplier']=1.15
block['grass_cap_depths_old_m']=[.125,.1875,.25]
block['grass_cap_depths_new_m']=[.14375,.215625,.2875]

# Original pixels, informed by representative light/shade/dirt samples.
reference = bpy.data.images.load(str(REF))
samples = {}
for label, x, y in [('lit_grass',1130,190),('lit_meadow',1070,80),('lit_tip',1090,470),
                    ('shade_grass',205,265),('shade_meadow',174,415),('dirt',777,227)]:
    offset = ((reference.size[1]-1-y)*reference.size[0]+x)*4
    samples[label] = {'pixel_top_left':[x,y], 'rgb':[round(c*255) for c in reference.pixels[offset:offset+3]]}
bpy.data.images.remove(reference)
palette = [(52,105,57),(62,116,62),(75,129,65),(87,137,69),(97,145,74),
           (106,151,78),(116,159,82),(124,165,87),(132,171,92)]
top_base = (91,135,66)
dirt_base = (130,103,64)
size = 128
pixels = [0.]*(size*size*4)
rng = random.Random(41008)
def pixel(x,y,c):
    offset=(y*size+x)*4
    pixels[offset:offset+4]=[v/255 for v in c]+[1]
for y in range(size):
    for x in range(size):
        jitter = rng.choice((-3,-1,0,0,0,1,3))
        pixel(x,y,tuple(v+jitter for v in dirt_base))
# Dirt fragments are deliberately sparse and irregular; no aligned diamond dots.
for i in range(240):
    x,y=rng.randrange(size),rng.randrange(82)
    shift=rng.choice((-11,-7,7,11))
    c=tuple(v+shift for v in dirt_base)
    for dx,dy in [(0,0),(1,0)] if i%3 == 0 else [(0,0)]:
        if x+dx<size:pixel(x+dx,y+dy,c)
# Retain original UV layout exactly: top panel occupies source 22..40 pixel tile.
for y in range(43,83):
    for x in range(43,83):pixel(x,y,top_base)
for i in range(95):
    x,y=rng.randrange(44,82),rng.randrange(44,82)
    c=rng.choice([(86,130,64),(96,140,69),(100,143,71)])
    pixel(x,y,c)
    if i%4 == 0 and x<81:pixel(x+1,y,c)
# Flat blade swatches and the source block's stepped grass rims.
for shade,c in enumerate(palette):
    for y in range(90,103):
        for x in range((3+shade*6)*2,(3+shade*6+5)*2):pixel(x,y,c)
image=bpy.data.images.new('ENV_Atlas_128_Reference_V4',width=size,height=size,alpha=True)
image.colorspace_settings.name='sRGB'
image.pixels.foreach_set(pixels);image.update()
image.file_format='PNG';image.filepath_raw=str(OUT/'environment_atlas_v4.png')
image.save();image.pack();image.filepath='//../../../../game_mobile_3d/assets/environment/grassland/environment_atlas_v4.png'
material=bpy.data.materials.new('ENV_Reference_Meadow_Opaque_V4')
material.use_nodes=True;material.use_backface_culling=False
nodes=material.node_tree.nodes;nodes.clear()
output=nodes.new('ShaderNodeOutputMaterial');output.location=(480,0)
principled=nodes.new('ShaderNodeBsdfPrincipled');principled.location=(180,0)
principled.inputs['Roughness'].default_value=1
principled.inputs['Specular IOR Level'].default_value=.08
texture=nodes.new('ShaderNodeTexImage');texture.image=image;texture.interpolation='Closest';texture.location=(-180,80)
uvnode=nodes.new('ShaderNodeUVMap');uvnode.uv_map='UV_Atlas';uvnode.location=(-400,80)
material.node_tree.links.new(uvnode.outputs['UV'],texture.inputs['Vector'])
material.node_tree.links.new(texture.outputs['Color'],principled.inputs['Base Color'])
material.node_tree.links.new(principled.outputs['BSDF'],output.inputs['Surface'])
block.data.materials.clear();block.data.materials.append(material)

vertices,faces,metadata,uvfaces=[],[],[],[]
blades=[];rng=random.Random(41208)
for row in range(6):
    for col in range(6):
        rx=-.5+(col+.5)/6+rng.uniform(-.026,.026)
        ry=-.5+(row+.5)/6+rng.uniform(-.026,.026)
        height=rng.uniform(.28,.48);width=rng.uniform(.12,.20)
        angle=(col*2.399+row*1.83+rng.uniform(-.7,.7))%math.pi
        tangent=Vector((math.cos(angle),math.sin(angle),0))
        # Small linear lean keeps each rest ribbon entirely planar.
        lean=Vector((-math.sin(angle),math.cos(angle),0))*rng.uniform(-.052,.052)
        start=len(vertices)
        blades.append(dict(root=[rx,ry,0],height_m=height,width_m=width,angle_radians=angle))
        for t in (0,.22,.65,1):
            center=Vector((rx,ry,height*t))+lean*t
            for side in (-1,1):
                vertices.append(tuple(center+tangent*width*.5*side))
                metadata.append((t,rx,ry,height))
        base_shade=rng.choice((1,2,2,3,3,4))
        for ring in range(3):
            a=start+ring*2;faces.append((a,a+1,a+3,a+2))
            shade=min(8,base_shade+ring)
            uvfaces.append([((3+shade*6+.5)/64,47.5/64)]*4)
mesh=bpy.data.meshes.new('ENV_Square_Leaves_36x4_Rings_V4')
mesh.from_pydata(vertices,[],faces);mesh.update();mesh.materials.append(material)
uv=mesh.uv_layers.new(name='UV_Atlas');rootuv=mesh.uv_layers.new(name='UV_Blade_Root')
for polygon,coords in zip(mesh.polygons,uvfaces):
    for li,coord in zip(polygon.loop_indices,coords):
        uv.data[li].uv=coord
        t,rx,ry,h=metadata[mesh.loops[li].vertex_index]
        rootuv.data[li].uv=(rx+.5,ry+.5)
mesh.uv_layers.active_index=0;uv.active_render=True;rootuv.active_render=False
mask=mesh.color_attributes.new(name='GRASS_BEND_DATA',type='FLOAT_COLOR',domain='POINT')
for i,(t,rx,ry,h) in enumerate(metadata):mask.data[i].color=(t*t,t,h/.48,1)
mesh.color_attributes.active_color=mask
mesh.color_attributes.render_color_index=mesh.color_attributes.find(mask.name)
grass=bpy.data.objects.new('ENV_Grass_Square_Leaves_V4',mesh)
scene.collection.objects.link(grass);grass.location=(0,0,1);grass.visible_shadow=False
grass['blade_count']=36;grass['height_normalization_m']=.48
grass['blade_geometry']='36 flat constant-width ribbons; square horizontal tips; four rings at 0/.22/.65/1.'
grass['root_uv_attribute']='UV_Blade_Root: (root_x+.5,root_y+.5); glTF V flip yields Godot root XZ=UV2-.5.'
grass['deform_attribute']='GRASS_BEND_DATA: R=t^2, G=t, B=blade height/.48, A=1. Data only; not albedo.'
grass['cast_shadows']=False;grass['wind_loop_seconds']=4
grass.shape_key_add(name='Basis',from_mix=False)
for axis,amplitude,phase in [(0,.018,0),(1,.008,math.pi/3)]:
    for trig in ('Sin','Cos'):
        key=grass.shape_key_add(name=f'Preview_Wind_{axis}_{trig}',from_mix=False)
        key.slider_min=-1;key.slider_max=1
        for i,(t,rx,ry,h) in enumerate(metadata):
            lag=phase-.26*t
            key.data[i].co[axis]+=amplitude*t*t*(math.cos(lag) if trig=='Sin' else math.sin(lag))
        driver=key.driver_add('value').driver
        driver.expression=f'{trig.lower()}(2*pi*(frame-1)/96)'

scene.frame_start=1;scene.frame_end=96;scene.render.fps=24;scene.frame_set(1)
scene.timeline_markers.new('REST_PHASE_START',frame=1)
scene.timeline_markers.new('WIND_PHASE_QUARTER',frame=25)
scene.timeline_markers.new('LOOP_SEAM_EXCLUDED',frame=97)
world=bpy.data.worlds.new('ENV_Cool_Fill_V4');world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.39,.48,.59,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.65;scene.world=world
def area(name,location,color,power,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=location
    obj.rotation_euler=(Vector((0,0,.7))-obj.location).to_track_quat('-Z','Y').to_euler()
area('REVIEW_Warm_Key',(3,-4,7),(1,.90,.72),650,5)
area('REVIEW_Cool_Fill',(-3,-1,4),(.65,.77,1),220,5)
def camera(name,location,target,scale):
    data=bpy.data.cameras.new(name);data.type='ORTHO';data.ortho_scale=scale
    obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=location
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler();return obj
hero=camera('REVIEW_Camera_Hero_V4',(3,-4,3.7),(0,0,.68),2.15)
detail=camera('REVIEW_Camera_Grass_Detail_V4',(2.4,-3.2,2.3),(0,0,1.19),1.32)
scene.camera=hero
scene.render.engine='CYCLES';scene.cycles.samples=48
scene.cycles.device='CPU'
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.view_settings.exposure=0;scene.view_settings.gamma=1
scene['reference_samples']=json.dumps(samples)
scene['review_note']='Original broad square-ended grass, muted meadow/dirt palette. Grass cast shadows disabled. Quiet 4s Blender preview; game wind/player shader owns runtime deformation.'
bpy.context.view_layer.objects.active=grass;grass.select_set(True)
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':
            a.spaces.active.region_3d.view_perspective='CAMERA'
            a.spaces.active.shading.type='MATERIAL'
notes=bpy.data.texts.new('V4_ASSET_NOTES')
notes.write(scene['review_note']+'\n'+grass['deform_attribute']+'\n'+grass['root_uv_attribute'])
scene.render.filepath=str(STUDY/'preview_hero.png')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(STUDY/'grass_block_reference_v4.blend'))

# Export duplicate rest meshes only. Source/preview has no impact on runtime motion.
export_scene=bpy.data.scenes.new('EXPORT_ONLY_V4');bpy.context.window.scene=export_scene
copies=[]
for original in (block,grass):
    obj=original.copy();obj.data=original.data.copy();obj.animation_data_clear()
    export_scene.collection.objects.link(obj);obj.name=original.name+'_Rest_Export'
    if original==grass:
        basis=[v.co.copy() for v in original.data.shape_keys.key_blocks['Basis'].data]
        obj.shape_key_clear()
        for v,co in zip(obj.data.vertices,basis):v.co=co
        obj.location=(0,0,0)
    else:
        # Identical E1 export optimization: remove redundant planar rim points only.
        source_mesh=obj.data;coords=[v.co.copy() for v in source_mesh.vertices];newfaces=[];newuv=[]
        for polygon in source_mesh.polygons:
            loops=list(polygon.loop_indices)
            if all(abs(coords[source_mesh.loops[i].vertex_index].z-coords[source_mesh.loops[loops[0]].vertex_index].z)<1e-7 for i in loops) and (polygon.center.z<1e-6 or polygon.center.z>.999999):
                kept=[]
                for k,li in enumerate(loops):
                    prev=coords[source_mesh.loops[loops[k-1]].vertex_index]
                    here=coords[source_mesh.loops[li].vertex_index]
                    nxt=coords[source_mesh.loops[loops[(k+1)%len(loops)]].vertex_index]
                    if (here-prev).cross(nxt-here).length>1e-8:kept.append(li)
                loops=kept
            newfaces.append([source_mesh.loops[i].vertex_index for i in loops])
            newuv.append([tuple(source_mesh.uv_layers[0].data[i].uv) for i in loops])
        optimized=bpy.data.meshes.new('ENV_Block_V4_Export_Only');optimized.from_pydata(coords,[],newfaces)
        optimized.materials.append(material);uv=optimized.uv_layers.new(name='UV_Atlas')
        for polygon,values in zip(optimized.polygons,newuv):
            for li,value in zip(polygon.loop_indices,values):uv.data[li].uv=value
        optimized.update();obj.data=optimized
    copies.append(obj)
options=dict(export_format='GLB',use_selection=True,export_animations=False,export_skins=False,
             export_morph=False,export_yup=True,export_texcoords=True,export_normals=True,
             export_materials='EXPORT',use_active_scene=True,export_vertex_color='ACTIVE',
             export_all_vertex_colors=True,export_active_vertex_color_when_no_material=True)
manifest=dict(source=str(SOURCE.relative_to(ROOT)),source_sha256=source_hash,
              preserved_v3_exports_sha256=preserved,source_unchanged=True,
              study='grass_block_reference_v4.blend',grass_vertices=288,grass_triangles=216,
              blade_count=36,height_rings=[0,.22,.65,1],height_normalization_m=.48,
              square_tip_width_ratio=1,wind_seconds=4,wind_tip_x_m=.018,wind_tip_y_m=.008,
              runtime_wind='Rest-only GLB; runtime retains user-requested 3x wind and 1.85x player splay.',
              cast_grass_shadows=False,texture_size=[128,128],reference_samples=samples,
              grass_cap_depth_multiplier=1.15,grass_cap_depths_old_m=[.125,.1875,.25],
              grass_cap_depths_new_m=[.14375,.215625,.2875],
              original_block_vertex_coordinates=original_block_coords,
              blade_palette_rgb=palette,block_top_rgb=top_base,dirt_base_rgb=dirt_base,
              blades=blades,adjustments=['Approved v4 change: green cap depths multiplied by 1.15; X/Y, topology, UVs, top Z=1 and bottom Z=0 preserved.', 'Export copy only: same E1 collinear planar rim simplification.'])
for obj,filename in zip(copies,('grass_dirt_block_v4.glb','grass_patch_v4.glb')):
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(OUT/filename),**options)
    obj.data.calc_loop_triangles()
    manifest[filename]=dict(triangles=len(obj.data.loop_triangles),vertices=len(obj.data.vertices),location=list(obj.location),
                            uv_layers=[v.name for v in obj.data.uv_layers],color_attributes=[c.name for c in obj.data.color_attributes])
assert source_hash==hashlib.sha256(SOURCE.read_bytes()).hexdigest()
assert all(hashlib.sha256((OUT/n).read_bytes()).hexdigest()==h for n,h in preserved.items())
(OUT/'export_manifest_v4.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
print('V4_EXPORT_READY '+json.dumps({k:manifest[k] for k in ('grass_vertices','grass_triangles','blade_count','blade_palette_rgb','block_top_rgb','dirt_base_rgb','source_unchanged')}))
