"""Extend the saved v4 family with a bare ochre dirt cube; preserve prior exports."""
import bpy
import hashlib
import json
import random
from pathlib import Path
from mathutils import Vector

STUDY=Path(__file__).resolve().parent
ROOT=STUDY.parents[3]
OUT=ROOT/'game_mobile_3d/assets/environment/grassland'
REF=Path('C:/Users/ADMIN/AppData/Local/Temp/codex-clipboard-2a98967b-27dd-4356-8a19-707fc285c8db.png')
preserved={n:hashlib.sha256((OUT/n).read_bytes()).hexdigest() for n in ('grass_patch_v4.glb','grass_dirt_block_v4.glb')}
bpy.ops.wm.open_mainfile(filepath=str(STUDY/'grass_block_reference_v4.blend'))
main=bpy.data.scenes['ENV_Grass_Block_Reference_V4'];bpy.context.window.scene=main
for name in ('ENV_Dirt_Block_Reference_V4','ENV_Grass_Dirt_Pair_V4'):
    if name in bpy.data.scenes:bpy.data.scenes.remove(bpy.data.scenes[name])
for obj in list(bpy.data.objects):
    if obj.name.startswith(('ENV_Dirt_Block_1m_V4','PAIR_','REVIEW_Camera_Dirt','REVIEW_Camera_Pair')):
        bpy.data.objects.remove(obj,do_unlink=True)
image=bpy.data.images['ENV_Atlas_128_Reference_V4']
old=list(image.pixels);pixels=old.copy()
reference=bpy.data.images.load(str(REF))
samples={}
for label,x,y in [('top_mid',35,24),('top_light',49,20),('top_fleck',61,36),('side',72,50),('shade',37,54)]:
    x=min(x,reference.size[0]-1);y=min(y,reference.size[1]-1)
    offset=((reference.size[1]-1-y)*reference.size[0]+x)*4
    samples[label]=dict(pixel_top_left=[x,y],rgb=[round(c*255) for c in reference.pixels[offset:offset+3]])
bpy.data.images.remove(reference)
top_base=(162,130,77);side_base=(133,101,58);bottom_base=(117,88,52)
tiles={'top':(4,104,35,127),'sides':(44,104,75,127),'bottom':(84,104,115,127)}
rng=random.Random(50810)
def pixel(x,y,c):
    offset=(y*128+x)*4;pixels[offset:offset+4]=[v/255 for v in c]+[1]
for kind,base in [('top',top_base),('sides',side_base),('bottom',bottom_base)]:
    x0,y0,x1,y1=tiles[kind]
    for y in range(y0,y1+1):
        for x in range(x0,x1+1):
            j=rng.choice((-1,0,0,0,1));pixel(x,y,tuple(v+j for v in base))
    # Few uneven chunky soil fragments, with no regular lattice or diamond grid.
    for i in range(45 if kind=='top' else 27):
        x=rng.randrange(x0+1,x1-1);y=rng.randrange(y0+1,y1-1)
        delta=rng.choice((-9,-5,5,9))
        color=tuple(v+delta for v in base)
        shape=rng.choice([[(0,0)],[(0,0),(1,0)],[(0,0),(1,0),(1,1)],[(0,0),(0,1),(1,1)]])
        for dx,dy in shape:pixel(x+dx,y+dy,color)
# One-texel gutters protect the nearest-sampled panels from atlas-edge changes.
for x0,y0,x1,y1 in tiles.values():
    for y in range(y0,y1+1):
        for x in (x0,x1):
            src=((y*128)+(x0+1 if x==x0 else x1-1))*4
            dst=(y*128+x)*4;pixels[dst:dst+4]=pixels[src:src+4]
assert pixels[:104*128*4]==old[:104*128*4]
for y in range(104,128):
    for x in range(128):
        if not any(x0<=x<=x1 and y0<=y<=y1 for x0,y0,x1,y1 in tiles.values()):
            offset=(y*128+x)*4;assert pixels[offset:offset+4]==old[offset:offset+4]
image.pixels.foreach_set(pixels);image.update()
image.filepath_raw=str(OUT/'environment_atlas_v4.png');image.save();image.pack()
image.filepath='//../../../../game_mobile_3d/assets/environment/grassland/environment_atlas_v4.png'
material=bpy.data.materials['ENV_Reference_Meadow_Opaque_V4']
coords=[(-.5,-.5,0),(.5,-.5,0),(.5,.5,0),(-.5,.5,0),(-.5,-.5,1),(.5,-.5,1),(.5,.5,1),(-.5,.5,1)]
faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
mesh=bpy.data.meshes.new('ENV_Bare_Dirt_Cube_V4');mesh.from_pydata(coords,[],faces);mesh.update()
mesh.materials.append(material);uv=mesh.uv_layers.new(name='UV_Atlas')
for p in mesh.polygons:
    kind='top' if p.normal.z>.9 else 'bottom' if p.normal.z<-.9 else 'sides'
    x0,y0,x1,y1=tiles[kind]
    rect=[((x0+.5)/128,(y0+.5)/128),((x1-.5)/128,(y0+.5)/128),
          ((x1-.5)/128,(y1-.5)/128),((x0+.5)/128,(y1-.5)/128)]
    for li,value in zip(p.loop_indices,rect):uv.data[li].uv=value
dirt=bpy.data.objects.new('ENV_Dirt_Block_1m_V4',mesh)
dirt['asset_note']='Bare dirt block, exactly 1m, original ochre pixel texture, no green cap, 12 triangles.'
dirt['top_base_rgb']=top_base;dirt['side_base_rgb']=side_base
def setup_scene(name):
    s=bpy.data.scenes.new(name);s.world=main.world
    s.render.engine='CYCLES';s.cycles.samples=48;s.cycles.device='CPU'
    s.render.resolution_x=900;s.render.resolution_y=900;s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG';s.view_settings.view_transform='Standard';s.view_settings.look='None'
    for obj in main.objects:
        if obj.type=='LIGHT':s.collection.objects.link(obj)
    return s
def camera(s,name,location,target,scale):
    data=bpy.data.cameras.new(name);data.type='ORTHO';data.ortho_scale=scale
    obj=bpy.data.objects.new(name,data);s.collection.objects.link(obj);obj.location=location
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler();s.camera=obj
dirt_scene=setup_scene('ENV_Dirt_Block_Reference_V4');dirt_scene.collection.objects.link(dirt)
camera(dirt_scene,'REVIEW_Camera_Dirt_V4',(3,-4,3.7),(0,0,.5),1.9)
paired=setup_scene('ENV_Grass_Dirt_Pair_V4')
for original,name,dx in [(bpy.data.objects['ENV_GrassDirt_Block_1m'],'PAIR_Grass_Block_V4',-.65),
                         (bpy.data.objects['ENV_Grass_Square_Leaves_V4'],'PAIR_Square_Grass_V4',-.65),
                         (dirt,'PAIR_Dirt_Block_V4',.65)]:
    obj=original.copy();obj.name=name;paired.collection.objects.link(obj);obj.location.x=dx
camera(paired,'REVIEW_Camera_Pair_V4',(2.8,-5,3.8),(0,0,.65),3.0)
main.frame_set(1);bpy.context.window.scene=main
notes=bpy.data.texts.get('V4_BARE_DIRT_NOTES') or bpy.data.texts.new('V4_BARE_DIRT_NOTES')
notes.clear();notes.write('Bare dirt family: separate 12 triangle 1m cube; original golden ochre top and deeper earthy sides. New atlas tiles occupy unused rows 104..127 only. Prior grass/cap geometry, UVs, used pixels and GLB bytes remain unchanged.\n'+json.dumps(samples))
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(STUDY/'grass_block_reference_v4.blend'))
bpy.context.window.scene=dirt_scene
bpy.ops.object.select_all(action='DESELECT');dirt.select_set(True);bpy.context.view_layer.objects.active=dirt
bpy.ops.export_scene.gltf(filepath=str(OUT/'dirt_block_v4.glb'),export_format='GLB',use_selection=True,
                         export_animations=False,export_skins=False,export_morph=False,export_yup=True,
                         export_texcoords=True,export_normals=True,export_materials='EXPORT',use_active_scene=True)
manifest=json.loads((OUT/'export_manifest_v4.json').read_text())
manifest['bare_dirt_family']=dict(reference=str(REF),reference_samples=samples,top_base_rgb=top_base,
                                 side_base_rgb=side_base,bottom_base_rgb=bottom_base,atlas_tiles_blender_pixels=tiles,
                                 atlas_unchanged_outside_new_tiles=True,preserved_v4_mesh_exports_sha256=preserved,
                                 no_grass_cap=True)
manifest['dirt_block_v4.glb']=dict(triangles=12,vertices=8,dimensions_m=[1,1,1],location=[0,0,0],
                                   uv_layers=['UV_Atlas'],color_attributes=[],top_uv_blender=[(4.5/128,104.5/128),(34.5/128,126.5/128)],
                                   sides_uv_blender=[(44.5/128,104.5/128),(74.5/128,126.5/128)])
assert all(hashlib.sha256((OUT/name).read_bytes()).hexdigest()==digest for name,digest in preserved.items())
(OUT/'export_manifest_v4.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
print('V4_DIRT_EXPORT_READY '+json.dumps(manifest['bare_dirt_family']))
