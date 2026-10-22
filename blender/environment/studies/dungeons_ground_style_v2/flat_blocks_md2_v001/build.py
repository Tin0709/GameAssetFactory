"""One guarded additive build; publish the verified stage to the existing library."""
import bpy, hashlib, json, sys, uuid
from pathlib import Path
from mathutils import Vector

D = Path(__file__).resolve().parent
P = D.parent
R = P.parents[3]
E = R / '.validation/flat_blocks_v001'
LIB = P / 'dungeons_ground_style_v2.blend'
ROOT = 'MD2_Flat_Blocks_v001_PENDING'
sys.path.insert(0, str(P))
from flower_preservation import snapshot, compare

assert bpy.app.background
assert hashlib.sha256(LIB.read_bytes()).hexdigest() == (E / 'before.sha256').read_text().strip()
bpy.ops.wm.open_mainfile(filepath=str(LIB), load_ui=True)
scene = bpy.context.scene
assert 'md2_flat_blocks_review' not in scene, 'Do not rebuild over the completed candidate.'
baseline = snapshot()
(E / 'native_before.json').write_text(json.dumps(baseline))
old_layers = list(scene.view_layers)
palette = json.loads((D / 'palette.json').read_text())
root = bpy.data.collections.new(ROOT)
scene.collection.children.link(root)
root['review_status'] = 'Pending'
root['research_only'] = True
studio = bpy.data.collections.new('MD2_Flat_Blocks_Studio')
root.children.link(studio)
catalog = str(uuid.uuid5(uuid.NAMESPACE_URL, 'GameAssetFactory/Environment/FlatBlocksMD2Pending'))

def linear(value):
    s = value / 255.
    return s / 12.92 if s <= .04045 else ((s + .055) / 1.055) ** 2.4

def material(name, rgb):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*[linear(c) for c in rgb], 1.)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = mat.diffuse_color
    shader.inputs['Roughness'].default_value = 1.
    shader.inputs['Specular IOR Level'].default_value = 0.
    return mat

objects = {}
vertices = [(-.5,-.5,0.),(.5,-.5,0.),(.5,.5,0.),(-.5,.5,0.),
            (-.5,-.5,1.),(.5,-.5,1.),(.5,.5,1.),(-.5,.5,1.)]
faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
for i, (key, info) in enumerate(palette['blocks'].items()):
    name = 'MD2_Flat_' + key + '_Block_v001'
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mat = material(name + '_Solid_' + info['hex'][1:], info['srgb'])
    mat['srgb_hex'] = info['hex']
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    root.objects.link(obj)
    obj.location.x = i * 1.7
    obj['review_status'] = 'Pending'
    obj['research_only'] = True
    obj['flat_color_hex'] = info['hex']
    obj['color_method'] = info['method']
    obj['source_texture'] = info['source_texture']
    obj['source_texture_sha256'] = info['source_texture_sha256']
    obj['block_size_m'] = 1.
    obj.asset_mark()
    obj.asset_data.catalog_id = catalog
    obj.asset_data.description = 'Pending / one solid color on all six faces / 1m block / ' + info['method']
    objects[key] = obj

floor_mesh = bpy.data.meshes.new('MD2_Flat_Blocks_Review_Floor')
floor_mesh.from_pydata([(-30,-30,-.018),(30,-30,-.018),(30,30,-.018),(-30,30,-.018)], [], [(0,1,2,3)])
floor_mesh.materials.append(bpy.data.materials['REVIEW_Studio_Charcoal_Soft_V2'])
floor = bpy.data.objects.new(floor_mesh.name, floor_mesh)
studio.objects.link(floor)

for name, position, energy, size in [('Key',(-2.,-4.,7.),650.,6.),('Fill',(5.,2.,5.),350.,5.)]:
    data = bpy.data.lights.new('MD2_Flat_Blocks_' + name, 'AREA')
    data.energy = energy
    data.shape = 'DISK'
    data.size = size
    obj = bpy.data.objects.new(data.name, data)
    studio.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector((1.7,0.,.5)) - obj.location).to_track_quat('-Z','Y').to_euler()

cameras = {}
def camera(key, target, offset, scale):
    data = bpy.data.cameras.new('MD2_Flat_Blocks_Camera_' + key)
    data.type = 'ORTHO'
    data.ortho_scale = scale
    obj = bpy.data.objects.new(data.name, data)
    studio.objects.link(obj)
    obj.location = Vector(target) + Vector(offset)
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z','Y').to_euler()
    cameras[key] = obj.name

camera('All', (1.7,0.,.35), (4.,-8.,6.), 6.7)
for key, obj in objects.items():
    camera(key, (obj.location.x,0.,.5), (2.,-4.,3.), 2.5)
camera('Opposite', (1.7,0.,.35), (-4.,8.,6.), 6.7)

layer = scene.view_layers.new('Flat Blocks MD2')
for child in layer.layer_collection.children:
    child.exclude = child.collection != root
for old in old_layers:
    old.layer_collection.children[root.name].exclude = True
scene['md2_flat_blocks_review'] = json.dumps({'layer':layer.name, 'root':root.name,
    'objects':{k:o.name for k,o in objects.items()}, 'cameras':cameras, 'catalog':catalog, 'status':'Pending'})
scene['md2_flat_blocks_selected'] = 'All'
bpy.context.window.view_layer = layer
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type != 'VIEW_3D':
            continue
        space = area.spaces.active
        space.use_local_camera = True
        space.camera = bpy.data.objects[cameras['All']]
        space.region_3d.view_perspective = 'CAMERA'
        space.region_3d.view_camera_zoom = 0
        space.overlay.show_overlays = False
        space.show_region_ui = True
        space.shading.type = 'MATERIAL'
for obj in bpy.context.selected_objects:
    obj.select_set(False)
objects['Grass'].select_set(True)
layer.objects.active = objects['Grass']
assert not compare(baseline), compare(baseline)
for key, obj in objects.items():
    obj.data.calc_loop_triangles()
    assert tuple(obj.dimensions) == (1.,1.,1.)
    assert len(obj.data.loop_triangles) == 12 and len(obj.data.materials) == 1
    assert not obj.modifiers and all(not p.use_smooth for p in obj.data.polygons)
    assert not any(n.type == 'TEX_IMAGE' for n in obj.active_material.node_tree.nodes)
    assert all(p.material_index == 0 for p in obj.data.polygons)
    assert all(p.normal.dot(p.center - Vector((0,0,.5))) > 0 for p in obj.data.polygons)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(E / 'flat_blocks_stage.blend'), relative_remap=False, compress=True)
(E / 'build.json').write_text(json.dumps({'objects':{k:o.name for k,o in objects.items()},
    'catalog':catalog, 'preservation_changes':compare(baseline), 'status':'Pending'}, indent=2))
print('MD2_FLAT_BLOCKS_STAGE_READY', flush=True)
