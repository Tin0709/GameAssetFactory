"""Guarded additive wind review in the existing environment scene/library."""
import bpy
import hashlib
import json
import math
import random
import sys
import uuid
from pathlib import Path
from mathutils import Vector

D = Path(__file__).resolve().parent; P = D.parent; R = D.parents[4]
E = R / '.validation/md2_grass_wind_v001'; LIB = P / 'dungeons_ground_style_v2.blend'
sys.path[:0] = [str(P), str(D)]
from flower_preservation import snapshot, compare, mesh_content
from wind_nodes import CONTROLS, NAME, make_group, add_modifier

assert hashlib.sha256(LIB.read_bytes()).hexdigest() == (E / 'before.sha256').read_text()
bpy.ops.wm.open_mainfile(filepath=str(LIB)); scene = bpy.context.scene
assert 'md2_wind_review' not in scene, 'Never rebuild over completed wind candidates.'
old_layers = [l.name for l in scene.view_layers]
for name in old_layers:
    bpy.context.window.view_layer = scene.view_layers[name]; bpy.context.view_layer.update()
baseline = snapshot(); (E / 'before_native.json').write_text(json.dumps(baseline, indent=2) + '\n')
timeline = {k: getattr(scene, k) for k in ['frame_current', 'frame_start', 'frame_end', 'use_preview_range', 'frame_preview_start', 'frame_preview_end', 'sync_mode']}
sources = [bpy.data.objects[n] for key in ['md2_review', 'md2_tall_review'] for n in json.loads(scene[key])['masters']]
(E / 'source_grass_meshes.json').write_text(json.dumps({o.name: mesh_content(o.data) for o in sources}) + '\n')

def collection(name, parent):
    c = bpy.data.collections.new(name); parent.children.link(c); return c
# A top-level review collection permits complete per-layer isolation. Linking
# beneath an old asset collection would also render objects directly in that
# ancestor, which Blender cannot exclude while retaining this child.
root = collection(NAME + '_PENDING', scene.collection)
root['review_status'] = 'Pending'; root['research_only'] = True
individual = collection('01_MD2_Wind_Individuals', root)
field = collection('02_MD2_Wind_Mixed_Field', root)
comparison = collection('03_MD2_Wind_Static_Comparison', root)
studio = collection('04_MD2_Wind_Studio', root)
controller = bpy.data.objects.new(NAME + '_Controls', None); studio.objects.link(controller)
controller.hide_render = True; controller.empty_display_type = 'PLAIN_AXES'
for name, (value, lo, hi, description) in CONTROLS.items():
    controller[name] = value
    kwargs = {'description': description, 'default': value}
    if lo is not None: kwargs.update(min=lo, max=hi, soft_min=lo, soft_max=hi)
    if name == 'Wind Direction': kwargs['subtype'] = 'ANGLE'
    controller.id_properties_ui(name).update(**kwargs)
group, sockets = make_group()

def wind_mesh(source):
    mesh = source.data.copy(); mesh.name = source.name + '__WindMesh_v001'
    # Connected card components provide a correct mask even on merged clusters.
    parent = list(range(len(mesh.vertices)))
    def find(v):
        while parent[v] != v:
            parent[v] = parent[parent[v]]; v = parent[v]
        return v
    for edge in mesh.edges:
        a, b = edge.vertices; parent[find(a)] = find(b)
    cards = {}
    for vi in range(len(mesh.vertices)): cards.setdefault(find(vi), []).append(vi)
    attrs = {}
    for name, kind in [('rest', 'FLOAT_VECTOR'), ('root', 'FLOAT_VECTOR'), ('t', 'FLOAT'), ('length', 'FLOAT'), ('phase', 'FLOAT')]:
        attrs[name] = mesh.attributes.new('md2_wind_' + name, kind, 'POINT')
    for ci, indices in enumerate(sorted(cards.values(), key=min)):
        assert len(indices) in [6, 8], (source.name, len(indices))
        low = min(mesh.vertices[i].co.z for i in indices); high = max(mesh.vertices[i].co.z for i in indices)
        roots = [mesh.vertices[i].co for i in indices if abs(mesh.vertices[i].co.z - low) < 1e-7]
        assert len(roots) == 2
        pivot = sum(roots, Vector()) / 2
        for vi in indices:
            p = mesh.vertices[vi].co
            attrs['rest'].data[vi].vector = p
            attrs['root'].data[vi].vector = pivot
            attrs['t'].data[vi].value = (p.z - low) / (high - low)
            attrs['length'].data[vi].value = high - low
            attrs['phase'].data[vi].value = math.tau * ((ci * .61803398875) % 1.)
    assert len(cards) == source['cards']
    return mesh

meshes = {o.name: wind_mesh(o) for o in sources}
rng = random.Random(5821); wind_objects = []
def grass(source, name, loc, col, angle=0., animated=True):
    o = bpy.data.objects.new(name, meshes[source.name] if animated else source.data)
    col.objects.link(o); o.location = loc; o.rotation_euler.z = angle; o.visible_shadow = False
    o['review_status'] = 'Pending'; o['wind_source'] = source.name; o['review_only_no_godot'] = True
    if animated:
        add_modifier(o, controller, group, sockets, source in sources[5:], rng.random() * math.tau)
        wind_objects.append(o)
    return o
base = bpy.data.objects['ENV_GrassBlock_DI_V3']
def ground(name, x, y, col):
    o = bpy.data.objects.new(name, base.data); col.objects.link(o); o.location = (x, y, 0.); return o

masters = []; cameras = {}; visible = {}
catalog = str(uuid.uuid5(uuid.NAMESPACE_URL, 'GameAssetFactory/Environment/MD2GrassWindPending'))
for i, source in enumerate(sources):
    x = 12. + i * 2.5
    o = grass(source, source.name + '__Wind_v001', (x, 0., 1.), individual)
    o['variant'] = source.get('variant', 'Dense Cluster'); o.asset_mark(); o.asset_data.catalog_id = catalog
    o.asset_data.description = 'Pending / original MD2-inspired wind / separate review copy of ' + source.name
    masters.append(o)
    platforms = [ground('MD2_Wind_Base_%d_%d' % (i, j), x + ox, oy, individual).name
                 for j, (ox, oy) in enumerate([(-.5,-.5),(-.5,.5),(.5,-.5),(.5,.5)] if 'Cluster' in source.name else [(0.,0.)])]
    visible[source.name] = [o.name] + platforms

# A contiguous 7 x 5 block patch with an intentionally mixed family, not a lone tuft.
for x in range(-3, 4):
    for y in range(-2, 3):
        ground('MD2_Wind_FieldGround_%d_%d' % (x, y), x, y, field)
        source = sources[5 + (x + y * 2) % 4] if (x + 2 * y) % 3 == 0 else sources[(x * 3 + y) % 4]
        grass(source, 'MD2_Wind_Field_%d_%d' % (x, y), (x + rng.uniform(-.025,.025), y + rng.uniform(-.025,.025), 1.), field, rng.uniform(-math.pi, math.pi))
for i in range(12):
    x = -2.5 + (i % 6); y = -.5 if i < 6 else .5
    source = sources[5 + i % 4] if i % 4 == 0 else sources[i % 4]
    grass(source, 'MD2_Wind_Field_Infill_%02d' % i, (x, y, 1.), field, rng.uniform(-math.pi, math.pi))
for row, source in enumerate([sources[0], sources[5]]):
    for animated, x in [(False, 12.), (True, 14.)]:
        ground('MD2_Wind_CompareBase_%d_%s' % (row, animated), x, 4. + row * 2., comparison)
        grass(source, 'MD2_Wind_Compare_%d_%s' % (row, animated), (x, 4. + row * 2., 1.), comparison, animated=animated)

def label(text, loc):
    c = bpy.data.curves.new('MD2_Wind_Label', 'FONT'); c.body = text; c.align_x = 'CENTER'; c.size = .18
    c.materials.append(bpy.data.materials['MD2_Review_Type'])
    o = bpy.data.objects.new('MD2_Wind_Label_' + text, c); comparison.objects.link(o); o.location = loc
label('STATIC / ORIGINAL', (12., 2.9, .012)); label('WIND / PENDING', (14., 2.9, .012))
floor = bpy.data.meshes.new('MD2_Wind_Studio_Floor')
floor.from_pydata([(-80,-80,-.026),(80,-80,-.026),(80,80,-.026),(-80,80,-.026)], [], [(0,1,2,3)])
floor.materials.append(bpy.data.materials['REVIEW_Studio_Charcoal_Soft_V2'])
o = bpy.data.objects.new(floor.name, floor); studio.objects.link(o)
for name, pos, power, size, color in [('Key', (0,-4,10), 600, 7., (1.,.96,.87)), ('Fill', (5,4,7), 300, 6., (.82,.91,1.))]:
    d = bpy.data.lights.new('MD2_Wind_' + name, 'AREA'); d.energy = power; d.shape = 'DISK'; d.size = size; d.color = color
    o = bpy.data.objects.new(d.name, d); studio.objects.link(o); o.location = pos
    o.rotation_euler = (Vector((0,0,1)) - o.location).to_track_quat('-Z','Y').to_euler()
# Uniform soft daylight keeps the far-away individual/comparison rows as
# readable as the main field, without changing any original review lighting.
sun = bpy.data.lights.new('MD2_Wind_Soft_Daylight', 'SUN'); sun.energy = .8; sun.angle = math.radians(25.)
o = bpy.data.objects.new(sun.name, sun); studio.objects.link(o); o.rotation_euler = (math.radians(28), math.radians(-20), math.radians(-35))
def camera(key, pos, target, scale):
    data = bpy.data.cameras.new('MD2_Wind_Camera_' + key); data.type = 'ORTHO'; data.ortho_scale = scale
    o = bpy.data.objects.new(data.name, data); studio.objects.link(o); o.location = pos
    o.rotation_euler = (Vector(target) - o.location).to_track_quat('-Z','Y').to_euler(); cameras[key] = o.name
camera('Field', (9,-12,10), (0,0,1.), 10.6)
camera('Close', (3,-4.6,3.3), (0,-.5,1.3), 4.6)
camera('Gameplay', (10,-14,17), (0,0,1.), 11.5)
camera('Compare', (18.,-4.,8.), (13.,4.8,1.1), 8.)
for source, obj in zip(sources, masters):
    x = obj.location.x
    camera(source.name, (x+1.2,-2.4,2.6), (x,0,1.3), 2.8 if 'Cluster' in source.name else 2.3)

layer = scene.view_layers.new('Grass MD2 Wind')
def contains(c): return c == root or any(contains(child) for child in c.children)
def configure(lc, inside=False):
    keep = inside or contains(lc.collection); lc.exclude = not keep
    if keep:
        for child in lc.children: configure(child, inside or lc.collection == root)
for child in layer.layer_collection.children: configure(child)
def find(lc):
    if lc.collection == root: return lc
    return next((r for c in lc.children if (r := find(c))), None)
for name in old_layers: find(scene.view_layers[name].layer_collection).exclude = True
scene['md2_wind_review'] = json.dumps({
    'revision': NAME, 'status': 'Pending', 'layer': layer.name, 'root': root.name,
    'controller': controller.name, 'cameras': cameras, 'individual_visible': visible,
    'masters': [o.name for o in masters], 'wind_objects': [o.name for o in wind_objects],
    'original_timeline': timeline, 'duration_s': 20., 'open_wind_review': True,
    'field_collection': field.name, 'compare_collection': comparison.name, 'studio_collection': studio.name,
})
# Old data and old review layers are preserved; additions only.
for name in old_layers:
    bpy.context.window.view_layer = scene.view_layers[name]; bpy.context.view_layer.update()
assert not compare(baseline), compare(baseline)
bpy.context.window.view_layer = layer
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            v = area.spaces.active; v.use_local_camera = True; v.camera = bpy.data.objects[cameras['Field']]
            v.region_3d.view_perspective = 'CAMERA'; v.region_3d.view_camera_zoom = 0; v.show_region_ui = True; v.overlay.show_overlays = False
import wind_review_ui
wind_review_ui.select(bpy.context, 'Field')
report = {'status': 'Pending', 'native_preservation_errors': [], 'sources': [o.name for o in sources],
          'wind_objects': len(wind_objects), 'field_clumps': len([o for o in field.objects if o.get('wind_source')]),
          'field_triangles': sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in field.objects if o.get('wind_source')),
          'new_meshes': len(meshes), 'new_node_groups': 1, 'new_scenes': 0, 'new_actions': 0,
          'defaults': {k: v[0] for k, v in CONTROLS.items()}, 'catalog_line': catalog + ':Environment/Grass Wind Pending:Grass Wind Pending\n'}
(D / 'manifest.json').write_text(json.dumps(report, indent=2) + '\n')
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(E / LIB.name), relative_remap=False, compress=True)
print('MD2_WIND_BUILT', json.dumps(report), flush=True)
