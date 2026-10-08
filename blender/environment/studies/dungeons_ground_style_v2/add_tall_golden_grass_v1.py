"""Add taller golden-headed grass through live MCP in the current exact study.

No file-open/reset. The caller executes this source in the connected Blender UI.
"""
import bpy
assert not bpy.app.background, 'Source writes require the connected foreground Blender session'
import hashlib
import json
import math
import random
import sys
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
EVIDENCE = ROOT / '.validation/flower_patch_v1'
OUT = HERE / 'exports'
sys.path.insert(0, str(HERE))
from flower_preservation import compare, digest

assert Path(bpy.data.filepath).resolve() == (HERE/'dungeons_ground_style_v2.blend').resolve()
assert bpy.context.mode == 'OBJECT' and 'TALL_GRASS_Golden_1Block_V1' not in bpy.data.collections
baseline = json.loads((EVIDENCE/'before_tall_golden_grass_fingerprints.json').read_text())
assert not compare(baseline['data']), 'Prior flowers/grass/original scene must remain unchanged'
scene = bpy.context.scene
original_camera = scene.camera
collection = bpy.data.collections.new('TALL_GRASS_Golden_1Block_V1')
scene.collection.children.link(collection)
display = bpy.data.collections.new('REVIEW_TallGolden_Grass_Comparison_V1')
scene.collection.children.link(display)
display['display_only'] = True
palette = {'green_deep': '#346939', 'green': '#4b7c43', 'green_mid': '#628949', 'green_tip': '#789b50',
           'seed_gold': '#d9ce8f', 'seed_pale': '#e7dca9', 'seed_shade': '#c6bb82'}
def rgba(name):
    value = palette[name]
    return tuple(int(value[i:i+2],16)/255 for i in (1,3,5))+(1,)
material = bpy.data.materials.new('MAT_TallGoldenGrass_V1_LinearVertexAlbedo')
material.use_nodes = True
material.use_backface_culling = False
bsdf = material.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value = 1
bsdf.inputs['Metallic'].default_value = 0
bsdf.inputs['Specular IOR Level'].default_value = .12
bsdf.inputs['Alpha'].default_value = 1
vc = material.node_tree.nodes.new('ShaderNodeVertexColor'); vc.layer_name = 'Color'
material.node_tree.links.new(vc.outputs['Color'],bsdf.inputs['Base Color'])
vertices,faces,colors,uv0s,uv2s,ids,parts = [],[],[],[],[],[],[]
def quad(points,color,masks,root,h,fid,part):
    start = len(vertices); vertices.extend(tuple(p) for p in points)
    faces.append(tuple(range(start,start+4)))
    colors.append(color);uv0s.extend((float(mask),h) for mask in masks)
    uv2s.extend((root.x+.5,root.y+.5) for _ in points)
    ids.append(fid);parts.append(part)
rng = random.Random(41107)
specs = []
Z = Vector((0,0,1))
for j in range(7):
    for i in range(4):
        fid = j*4+i
        root = Vector((-.31+i*.62/3+rng.uniform(-.012,.012),-.32+j*.64/6+rng.uniform(-.010,.010),0))
        h = 1.96+rng.uniform(0,.22)
        width = rng.uniform(.120,.176)
        az = rng.uniform(-math.pi,math.pi)
        u = Vector((math.cos(az),math.sin(az),0))
        # A quiet lean remains entirely within the flat ribbon plane.
        lean = u*rng.uniform(-.021,.021)
        rings = [root+lean*t+Z*(h*t) for t in (0,.22,.65,1)]
        for ring,(t0,t1) in enumerate(zip((0,.22,.65),(.22,.65,1))):
            p0,p1 = rings[ring],rings[ring+1]
            color = ('green_deep','green','green_mid')[ring]
            if ring==2 and fid%3==0: color='green_tip'
            quad((p0-u*width/2,p0+u*width/2,p1+u*width/2,p1-u*width/2),color,(t0,t0,t1,t1),root,h,fid,0)
        head = rings[-1]
        gold = ('seed_gold','seed_pale','seed_shade')[fid%3]
        stem_half = rng.uniform(.024,.030)
        # Golden terminal band and squared cap, with two asymmetric rectangular
        # side panicles. This is a branched seed silhouette, not a four-petal daisy.
        quad((head-u*stem_half-Z*.045,head+u*stem_half-Z*.045,head+u*stem_half+Z*.090,head-u*stem_half+Z*.090),
             gold,(1,)*4,root,h,fid,1)
        cap_half = stem_half*1.38
        cap_height = rng.uniform(.045,.067)
        quad((head-u*cap_half+Z*.090,head+u*cap_half+Z*.090,head+u*cap_half+Z*(.09+cap_height),head-u*cap_half+Z*(.09+cap_height)),
             gold,(1,)*4,root,h,fid,1)
        for side,offset in ((-1,-.025),(1,.035)):
            tilt = rng.uniform(.28,.52)
            along = u*(side*math.cos(tilt))+Z*math.sin(tilt)
            across = -u*(side*math.sin(tilt))+Z*math.cos(tilt)
            branch_half = rng.uniform(.020,.029)
            start = head+u*side*(stem_half+branch_half*math.sin(tilt))+Z*offset
            end = start+along*rng.uniform(.075,.105)
            quad((start-across*branch_half,end-across*branch_half,end+across*branch_half,start+across*branch_half),
                 gold,(1,)*4,root,h,fid,1)
        specs.append({'stem':fid,'root_xy':list(root)[:2],'head_base_height_m':h,'blade_width_m':width,'angle_rad':az})

mesh = bpy.data.meshes.new('ENV_TallGoldenGrass_1m_V1_PlanarMesh')
mesh.from_pydata(vertices,[],faces);mesh.update();mesh.materials.append(material)
color = mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
uv0 = mesh.uv_layers.new(name='UV_Stem_Height');uv2 = mesh.uv_layers.new(name='UV_Stem_Root')
stem = mesh.attributes.new(name='stem_index',type='INT',domain='FACE')
part = mesh.attributes.new(name='part',type='INT',domain='FACE')
for p,c,fid,component in zip(mesh.polygons,colors,ids,parts):
    p.use_smooth = False;stem.data[p.index].value=fid;part.data[p.index].value=component
    for li in p.loop_indices:
        vi=mesh.loops[li].vertex_index;color.data[li].color_srgb=rgba(c)
        uv0.data[li].uv=uv0s[vi];uv2.data[li].uv=uv2s[vi]
mesh.color_attributes.active_color=color;mesh.uv_layers.active_index=0
obj=bpy.data.objects.new('ENV_TallGoldenGrass_1m_V1',mesh);collection.objects.link(obj)
obj['authoring_status']='Original tall broad grass with pale golden seed heads; awaiting user art review'
obj['placement_footprint_m']=[1.0,1.0]
obj['player_rest_stature_m']=1.8
obj['wind_contract']='UV0.x normalized blade height, gold seed planes all1; UV0.y head base height >1m; runtime height=1-UV.y; UV2 root XZ=UV2-.5'
obj['reference']='User codex-clipboard-d070c630-5467-4ed2-82be-246e36656969.png, observed broad grass and pale angular top seed heads; original geometry/colors'
obj['source_language']='Existing original v4 broad square-ended planar blades; original v4 source remains unchanged'
obj['units']='metres; bottom-centred reserved square; Blender Z-up; runtime identity scale and rotation'
lo=[min(v.co[k] for v in mesh.vertices) for k in range(3)]
hi=[max(v.co[k] for v in mesh.vertices) for k in range(3)]
assert all(-.5<=lo[k]<hi[k]<=.5 for k in (0,1)) and 2.15<=hi[2]<=2.4

for chosen in list(bpy.context.selected_objects):chosen.select_set(False)
obj.select_set(True);bpy.context.view_layer.objects.active=obj
export_path=OUT/'tall_golden_grass_1m_v1.glb'
bpy.ops.export_scene.gltf(filepath=str(export_path),export_format='GLB',use_selection=True,
    export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',
    export_vertex_color='NAME',export_vertex_color_name='Color',export_all_vertex_colors=False,
    export_animations=False,export_morph=False,export_skins=False,export_cameras=False,
    export_lights=False,export_extras=False,export_apply=False)
obj.location=(21,3.2,1)
base=bpy.data.objects['ENV_GrassBlock_DI_V3'].copy();base.name='REVIEW_TallGolden_Platform_21';base.location=(21,3.2,0)
display.objects.link(base);base['display_only']=True
label=bpy.data.curves.new('TallGolden_Label','FONT')
label.body=f'TALL GOLDEN GRASS / {hi[2]:.2f} m\nPLAYER REST / 1.80 m';label.align_x='CENTER';label.size=.12
text=bpy.data.objects.new('REVIEW_TallGolden_Actual_Height_Label',label);text.location=(21,2.12,.012)
display.objects.link(text);text['display_only']=True
camera_data=bpy.data.cameras.new('CAM_TallGolden_V1_Diagnostic')
camera=bpy.data.objects.new(camera_data.name,camera_data);display.objects.link(camera)
camera.location=(24,-3.8,5);camera.rotation_euler=(Vector((20,3.2,1.4))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO';camera_data.ortho_scale=6.2;camera['display_only']=True
assert scene.camera==original_camera and not compare(baseline['data'])
mesh.calc_loop_triangles()
manifest={'status':'Original editable tall golden grass V1; awaiting user art review','source_blend':str(Path(bpy.data.filepath).relative_to(ROOT)),
          'object':obj.name,'collection':collection.name,'stem_count':28,'green_quads_per_stem':3,'gold_seed_quads_per_stem':4,
          'bend_rings':[0,.22,.65,1],'triangles':len(mesh.loop_triangles),'quads':len(mesh.polygons),'authored_vertices':len(mesh.vertices),
          'placement_footprint_m':[1,1],'bounds_blender':[lo,hi],'height_m':hi[2],
          'player_rest_stature_m':1.8,'player_measurement_source':'CuboidPlayer.tscn capsule1.80m + current R15 GLB POSITION Y0..1.79999995, no visual/model scale',
          'height_above_player_rest_m':hi[2]-1.8,'palette_srgb':palette,'stems':specs,
          'material':'One matte opaque double-sided surface; linear albedo COLOR_0 via color_srgb; no texture/alpha/thickness',
          'UV0_source':['normalized stem height; all golden head planes1','shared head base height metres >1'],
          'UV0_gltf':['same normalized mask','1-height, negative values preserved; decode head height as1-UV.y'],
          'UV2_source':'per-stem root BlenderXY+(.5,.5)','UV2_godot':'local rootXZ=importedUV2-(.5,.5)',
          'runtime_transform':'Identity, Blender Z-up -> Godot Y-up once; no cameras/lights/rig/animation/texture/collision',
          'display_location_blender':list(obj.location),'glb':str(export_path.relative_to(ROOT)),
          'glb_sha256':hashlib.sha256(export_path.read_bytes()).hexdigest(),
          'source_continuation_fingerprint':digest(baseline['data']),'preserved_white_flower_glb_sha256':baseline['white_flower_glb_sha256'],
          'preserved_grass_source_sha256':baseline['grass_source_sha256']}
(HERE/'tall_golden_grass_v1_manifest.json').write_text(json.dumps(manifest,indent=2))
for selected in list(bpy.context.selected_objects):selected.select_set(False)
for selected in (obj,bpy.data.objects['REVIEW_Meadow_Grass_V4_065']):selected.select_set(True)
bpy.context.view_layer.objects.active=obj
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        space=area.spaces.active;space.shading.type='MATERIAL';space.shading.use_scene_lights=False;space.shading.use_scene_world=False
        space.overlay.show_overlays=False
        region=space.region_3d;region.view_location=(20,3.2,1.65);region.view_rotation=camera.rotation_euler.to_quaternion()
        region.view_distance=6.1;region.view_perspective='ORTHO';area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
result=manifest

