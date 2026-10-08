"""Additive authoring in the already-open exact study; never resets existing data.

Run through Blender MCP in the current connected window. Baseline backup must exist.
Rejects re-running over the authored collection; editing is intentionally explicit.
"""
import bpy
assert not bpy.app.background, 'Source writes require the connected foreground Blender session'
import hashlib
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
EVIDENCE = ROOT / '.validation/flower_patch_v1'
OUT = HERE / 'exports'
sys.path.insert(0, str(HERE))
from flower_preservation import compare, digest, mesh_content

assert Path(bpy.data.filepath).resolve() == (HERE / 'dungeons_ground_style_v2.blend').resolve()
assert bpy.context.mode == 'OBJECT'
assert 'FLOWERS_White_1Block_V1' not in bpy.data.collections, 'Asset already exists; do not duplicate'
baseline = json.loads((EVIDENCE / 'original_fingerprints_loaded.json').read_text())
assert not compare(baseline['data']), 'Baseline data must match before additions'
scene = bpy.context.scene
original_camera = scene.camera
flower_collection = bpy.data.collections.new('FLOWERS_White_1Block_V1')
scene.collection.children.link(flower_collection)
review = bpy.data.collections.new('REVIEW_Flowers_And_Original_Grass_V4')
scene.collection.children.link(review)
review['purpose'] = 'Display-only copies; original v4 grass geometry/material and source preserved'

PALETTE = {'white': '#f3f4e9', 'white_cool': '#e7eee4', 'yellow': '#e8bf42', 'stem': '#4c7c3b', 'leaf': '#628947'}
def srgb(hexcolor):
    return tuple(int(hexcolor[i:i+2], 16) / 255 for i in (1, 3, 5)) + (1,)

material = bpy.data.materials.new('MAT_WhiteFlower_V1_LinearVertexAlbedo')
material.use_nodes = True
material.use_backface_culling = False
bsdf = material.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value = 1
bsdf.inputs['Metallic'].default_value = 0
bsdf.inputs['Specular IOR Level'].default_value = .12
bsdf.inputs['Alpha'].default_value = 1
color_node = material.node_tree.nodes.new('ShaderNodeVertexColor')
color_node.layer_name = 'Color'
material.node_tree.links.new(color_node.outputs['Color'], bsdf.inputs['Base Color'])

vertices, faces, colors, bends, roots, flower_ids, parts = [], [], [], [], [], [], []
def face(points, color, bend, root, fid, part, h):
    start = len(vertices)
    vertices.extend(tuple(p) for p in points)
    faces.append(tuple(range(start, start+4)))
    colors.append(color)
    bends.extend((float(t), h) for t in bend)
    roots.extend((root[0]+.5, root[1]+.5) for _ in points)
    flower_ids.append(fid)
    parts.append(part)

# Original spacing, palette and rectangular construction informed by the user's crop.
# Height is flower-head centre above its own anchored root, not per-vertex geometry Y.
FLOWERS = [(-.29, -.29, .30, -12, 21, .070, .030, .020, -.009),
           (.25, -.26, .36, 24, 26, .072, .029, -.016, .014),
           (-.32, .24, .40, -25, 20, .070, .030, .016, .012),
           (.29, .26, .315, 14, 30, .074, .029, -.010, -.012),
           (.005, .005, .37, 38, 24, .078, .031, .022, -.014)]
for fid, (rx, ry, h, az, tilt, petal_len, centre, lean_x, lean_y) in enumerate(FLOWERS):
    root = Vector((rx, ry, 0))
    lean = Vector((lean_x, lean_y, 0))
    a, t = math.radians(az), math.radians(tilt)
    u = Vector((math.cos(a), math.sin(a), 0))
    v = Vector((-math.sin(a)*math.cos(t), math.cos(a)*math.cos(t), math.sin(t)))
    head = root + lean + Vector((0, 0, h))
    # Three thin planar stem segments. One plane, with slight progressive lean.
    stem_width = .012 + fid*.0006
    for t0, t1 in zip((0, .35, .70), (.35, .70, 1)):
        p0 = root + lean*t0 + Vector((0, 0, h*t0))
        p1 = root + lean*t1 + Vector((0, 0, h*t1))
        face((p0-u*stem_width/2, p0+u*stem_width/2, p1+u*stem_width/2, p1-u*stem_width/2),
             'stem', (t0, t0, t1, t1), root, fid, 0, h)
    # Four blunt rectangles around a flat square yellow centre, all on one head plane.
    halfwidth = centre*.91
    for petal in range(4):
        angle = petal*math.pi/2
        along = u*math.cos(angle) + v*math.sin(angle)
        across = -u*math.sin(angle) + v*math.cos(angle)
        inner = head + along*centre
        outer = head + along*(centre+petal_len)
        face((inner-across*halfwidth, outer-across*halfwidth, outer+across*halfwidth, inner+across*halfwidth),
             'white_cool' if (petal+fid)%3 == 0 else 'white', (1,)*4, root, fid, 1, h)
    face((head-u*centre-v*centre, head+u*centre-v*centre, head+u*centre+v*centre, head-u*centre+v*centre),
         'yellow', (1,)*4, root, fid, 2, h)
    # Two rigid blunt leaf planes, individually attached to a specific stem ring.
    for side, attach in ((-1, .43), (1, .65)):
        p = root + lean*attach + Vector((0, 0, h*attach))
        direction = u*side + v*.18 + Vector((0, 0, .43))
        direction.normalize()
        across = Vector((-direction.y, direction.x, 0)).normalized()
        end = p + direction*(.078+fid*.003)
        w = .017+fid*.0008
        face((p-across*w, end-across*w, end+across*w, p+across*w),
             'leaf', (attach,)*4, root, fid, 3, h)

mesh = bpy.data.meshes.new('ENV_WhiteFlowerPatch_1m_V1_PlanarMesh')
mesh.from_pydata(vertices, [], faces)
mesh.update()
mesh.materials.append(material)
color = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
uv0 = mesh.uv_layers.new(name='UV_Stem_Height')
uv2 = mesh.uv_layers.new(name='UV_Flower_Root')
flower_attribute = mesh.attributes.new(name='flower_index', type='INT', domain='FACE')
part_attribute = mesh.attributes.new(name='flower_part', type='INT', domain='FACE')
for polygon, c, fid, part in zip(mesh.polygons, colors, flower_ids, parts):
    polygon.use_smooth = False
    flower_attribute.data[polygon.index].value = fid
    part_attribute.data[polygon.index].value = part
    for li in polygon.loop_indices:
        vi = mesh.loops[li].vertex_index
        color.data[li].color_srgb = srgb(PALETTE[c])
        uv0.data[li].uv = bends[vi]
        uv2.data[li].uv = roots[vi]
mesh.color_attributes.active_color = color
mesh.uv_layers.active_index = 0
obj = bpy.data.objects.new('ENV_WhiteFlowerPatch_1m_V1', mesh)
flower_collection.objects.link(obj)
obj['authoring_status'] = 'Original white flowers V1; awaiting user art review'
obj['placement_footprint_m'] = [1.0, 1.0]
obj['units'] = 'metres; Blender Z-up; local bottom-centred origin; identity runtime transform'
obj['wind_contract'] = 'UV0.x normalized stem attachment; heads=1; UV0.y centre height metres; UV2 root XY+0.5'
obj['reference'] = 'User image codex-clipboard-580d030a-6156-4543-888f-094dfd27efab.png; observed silhouette only; no copied pixels/geometry'

# Runtime export before any display offsets. Exactly one selected mesh and surface.
OUT.mkdir(parents=True, exist_ok=True)
for selected in list(bpy.context.selected_objects):
    selected.select_set(False)
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
export_path = OUT / 'white_flower_patch_1m_v1.glb'
bpy.ops.export_scene.gltf(filepath=str(export_path), export_format='GLB', use_selection=True,
    export_yup=True, export_texcoords=True, export_normals=True, export_materials='EXPORT',
    export_vertex_color='NAME', export_vertex_color_name='Color', export_all_vertex_colors=False,
    export_animations=False, export_morph=False, export_skins=False, export_cameras=False,
    export_lights=False, export_extras=False, export_apply=False)

# Display area is separate from the established V2/V3 layout. Copies share source data.
obj.location = (15, 3.2, 1)
grass_source = ROOT / 'blender/environment/studies/grass_block_reference_v4/grass_block_reference_v4.blend'
with bpy.data.libraries.load(str(grass_source), link=False) as (source, target):
    assert 'ENV_Grass_Square_Leaves_V4' in source.objects
    target.objects = ['ENV_Grass_Square_Leaves_V4']
grass = target.objects[0]
grass.name = 'REVIEW_Original_Grass_V4'
review.objects.link(grass)
grass.location = (17, 3.2, 1)
grass.rotation_euler = (0, 0, 0)
grass.scale = (1, 1, 1)
grass['source_file'] = str(grass_source.relative_to(ROOT))
grass['source_object'] = 'ENV_Grass_Square_Leaves_V4'
grass['display_only'] = True
lowgrass = grass.copy()
lowgrass.name = 'REVIEW_Meadow_Grass_V4_065'
review.objects.link(lowgrass)
lowgrass.location = (19, 3.2, 1)
lowgrass.scale = (1, 1, .65)
lowgrass['display_only'] = True
lowgrass['display_height_scale'] = .65
lowgrass['note'] = 'Linked display copy of original v4 mesh; 0.65 Blender Z = runtime Godot Y scale'
for x, label in ((15, 'WHITE FLOWERS / 1m PATCH'), (17, 'ORIGINAL V4 GRASS'), (19, 'V4 MEADOW HEIGHT / 0.65')):
    base = bpy.data.objects['ENV_GrassBlock_DI_V3'].copy()
    base.name = 'REVIEW_FlowerGrass_Platform_' + str(x)
    base.location = (x, 3.2, 0)
    review.objects.link(base)
    base['display_only'] = True
    text_data = bpy.data.curves.new('FlowerGrass_Label_' + str(x), 'FONT')
    text_data.body = label
    text_data.align_x = 'CENTER'
    text_data.size = .13
    text = bpy.data.objects.new('REVIEW_' + label, text_data)
    text.location = (x, 2.20, .012)
    review.objects.link(text)
    text['display_only'] = True
camera_data = bpy.data.cameras.new('CAM_Flowers_Grass_V1_Diagnostic')
camera = bpy.data.objects.new('CAM_Flowers_Grass_V1_Diagnostic', camera_data)
review.objects.link(camera)
camera.location = (21, -4.8, 6)
camera.rotation_euler = (Vector((17, 3.2, .7))-camera.location).to_track_quat('-Z', 'Y').to_euler()
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 6.5
camera['display_only'] = True
assert scene.camera == original_camera
assert not compare(baseline['data']), 'Additive changes altered existing data'

mesh.calc_loop_triangles()
manifest = {'status': 'Original editable V1, awaiting user art review', 'source_blend': str(Path(bpy.data.filepath).relative_to(ROOT)),
            'collection': flower_collection.name, 'object': obj.name, 'placement_footprint_m': [1, 1],
            'mesh_local_bounds_blender': [[min(v.co[i] for v in mesh.vertices) for i in range(3)], [max(v.co[i] for v in mesh.vertices) for i in range(3)]],
            'triangles': len(mesh.loop_triangles), 'quads': len(mesh.polygons), 'authored_vertices': len(mesh.vertices),
            'flowers': 5, 'parts_per_flower': {'stem_quads': 3, 'rectangular_white_petals': 4, 'square_yellow_centre': 1, 'blunt_green_leaves': 2},
            'palette_srgb': PALETTE, 'vertex_color_storage': 'FLOAT_COLOR, linear albedo via color_srgb assignment; exported COLOR_0',
            'material': 'One opaque matte double-sided material; no textures or thickness',
            'UV0_source': ['normalized stem/rigid leaf attachment; all head/petal vertices exactly 1', 'head centre height in metres'],
            'UV0_gltf': ['same normalized attachment', '1 - head centre height (glTF V flip)'],
            'UV2_source': 'flower root Blender XY + (0.5,0.5)', 'UV2_godot': 'root local XZ = imported UV2 - (0.5,0.5)',
            'runtime_transform': 'Identity; Z-up -> Y-up once; no camera/light/rig/animation/collision',
            'display_location_blender': list(obj.location), 'grass_source': str(grass_source.relative_to(ROOT)),
            'grass_source_sha256': baseline['grass_source_sha256'], 'grass_reuse': 'Appended original v4 object; low version shares same mesh, display Z scale .65 only',
            'glb': str(export_path.relative_to(ROOT)), 'glb_sha256': hashlib.sha256(export_path.read_bytes()).hexdigest(),
            'preservation_fingerprint_digest': digest(baseline['data']), 'baseline_blend_sha256': baseline['blend_sha256']}
(HERE / 'white_flowers_v1_manifest.json').write_text(json.dumps(manifest, indent=2))

# Frame just the new group in the existing window without replacing the scene camera.
for selected in list(bpy.context.selected_objects):
    selected.select_set(False)
for candidate in (obj, grass, lowgrass):
    candidate.select_set(True)
bpy.context.view_layer.objects.active = obj
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        region = next((r for r in area.regions if r.type == 'WINDOW'), None)
        if region:
            with bpy.context.temp_override(area=area, region=region):
                bpy.ops.view3d.view_selected(use_all_regions=False)
        break
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'dungeons_ground_style_v2.blend'))
result = manifest

