"""Fan existing pale seed cards outward in place; preserve roots and leaf cards.

One-shot refinement of the saved Pending meshes, guarded by the review backup.
Writes only a staged library and evidence; publish after inspecting the renders.
"""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

D = Path(__file__).resolve().parent
T = D.parent
P = T.parent
R = T.parents[4]
E = R / '.validation/tall_grass_seed_fan_v001'
LIB = P / 'dungeons_ground_style_v2.blend'
sys.path[:0] = [str(P), str(T)]
from flower_preservation import compare, mesh_content, snapshot
from geometry import asset_record


def update_layers(scene):
    for name in ['Tall Grass MD2', 'Short Grass MD2', 'ViewLayer']:
        bpy.context.window.view_layer = scene.view_layers[name]
        bpy.context.view_layer.update()


def set_coords(objects, coords):
    for obj in objects:
        for vertex, point in zip(obj.data.vertices, coords[obj.name]):
            vertex.co = point
        obj.data.update()


assert hashlib.sha256(LIB.read_bytes()).hexdigest() == (E / 'before.sha256').read_text()
bpy.ops.wm.open_mainfile(filepath=str(LIB))
scene = bpy.context.scene
saved_layer = bpy.context.view_layer.name
objects = [bpy.data.objects[n] for n in json.loads(scene['md2_tall_review'])['masters']]
assert len(objects) == 6
update_layers(scene)
baseline = snapshot()
old = {o.name: json.loads(json.dumps(mesh_content(o.data))) for o in objects}
(E / 'before_native.json').write_text(json.dumps(baseline, indent=2) + '\n')
(E / 'before_tall_meshes.json').write_text(json.dumps(old, indent=2) + '\n')
old_coords = {name: data['vertices'] for name, data in old.items()}
allowed = {o.name: set() for o in objects}
tip_records = []

# Three central seed cards per tuft; the surrounding low green cards are exact.
# Use each card's existing outward axis, keeping horizontal ring widths intact.
for index, obj in enumerate(objects[:4]):
    for card, extra in enumerate([.22, .19, .24]):
        start = card * 8
        mesh = obj.data
        base = (mesh.vertices[start].co + mesh.vertices[start + 1].co) * .5
        top = (mesh.vertices[start + 6].co + mesh.vertices[start + 7].co) * .5
        outward = Vector((top.x - base.x, top.y - base.y, 0)).normalized()
        addition = extra * [1., 1.04, .94, 1.02][index]
        for ring, t in enumerate([0., .34, .70, 1.]):
            if ring == 0:
                continue
            for side in range(2):
                vi = start + ring * 2 + side
                mesh.vertices[vi].co += outward * (addition * t * t)
                allowed[obj.name].add(vi)
        new_top = (mesh.vertices[start + 6].co + mesh.vertices[start + 7].co) * .5
        old_radius = (top - Vector((0, 0, top.z))).length
        new_radius = (new_top - Vector((0, 0, new_top.z))).length
        assert new_radius > old_radius + .17
        tip_records.append({'asset': obj.name, 'card': card,
                            'tip_radius_before_m': old_radius,
                            'tip_radius_after_m': new_radius,
                            'additional_outward_m': addition})
    obj.data.update()

# Transfer the same source deltas into existing cluster vertex blocks. Keep all
# layout offsets, roots, topology, UVs and lower green cards byte-for-byte exact.
recipes = [
    [(0, .3, .65), (2, 2., .65), (3, 4.2, .60)],
    [(1, .2, .60), (3, 1.3, .60), (0, 2.7, .60), (2, 4., .60)],
]
for obj, parts in zip(objects[4:], recipes):
    offset = 0
    for index, angle, scale in parts:
        source = objects[index]
        rotation = Matrix.Rotation(angle, 3, 'Z')
        for vi in sorted(allowed[source.name]):
            delta = source.data.vertices[vi].co - Vector(old_coords[source.name][vi])
            delta.x *= scale
            delta.y *= scale
            obj.data.vertices[offset + vi].co += rotation @ delta
            allowed[obj.name].add(offset + vi)
        offset += len(source.data.vertices)
    assert offset == len(obj.data.vertices)
    obj.data.update()

refined = {o.name: [list(v.co) for v in o.data.vertices] for o in objects}
for obj in objects:
    current = json.loads(json.dumps(mesh_content(obj.data)))
    previous = old[obj.name]
    assert {k: v for k, v in current.items() if k != 'vertices'} == {
        k: v for k, v in previous.items() if k != 'vertices'}, obj.name
    for vi, (before, after) in enumerate(zip(previous['vertices'], current['vertices'])):
        assert before[2] == after[2], (obj.name, vi, 'height')
        assert all(math.isfinite(x) for x in after)
        if vi not in allowed[obj.name]:
            assert before == after, (obj.name, vi, 'protected vertex')
    for polygon in obj.data.polygons:
        points = [obj.data.vertices[i].co for i in polygon.vertices]
        normal = (points[1] - points[0]).cross(points[2] - points[0])
        assert normal.length > 1e-7
        assert abs(normal.normalized().dot(points[3] - points[0])) < 1e-6

# Restoring just the six authorized mesh coordinates must reproduce the entire
# native baseline, including derived dimensions of all linked display instances.
set_coords(objects, old_coords)
update_layers(scene)
errors = compare(baseline)
assert not errors, errors
set_coords(objects, refined)
update_layers(scene)
bpy.context.window.view_layer = scene.view_layers[saved_layer]
bpy.context.view_layer.update()

image = next(n.image for n in objects[0].data.materials[0].node_tree.nodes if n.type == 'TEX_IMAGE')
assets = [asset_record(o, image) for o in objects]
report = {
    'passed': True, 'status': 'Pending', 'source_sha256': (E / 'before.sha256').read_text(),
    'only_core_card_xy_changed': True, 'all_roots_and_z_exact': True,
    'all_leaf_cards_exact': True, 'topology_uv_materials_images_exact': True,
    'native_preservation_errors_when_authorized_coords_restored': errors,
    'changed_vertices': {name: len(indices) for name, indices in allowed.items()},
    'seed_tip_spread': tip_records, 'assets': assets,
    'new_scenes': 0, 'new_actions': 0, 'godot_modified': False,
}
(E / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(E / LIB.name), relative_remap=False, compress=True)
assert hashlib.sha256(LIB.read_bytes()).hexdigest() == report['source_sha256']
print('SEED_FAN_STAGED', json.dumps({'passed': True, 'changed_vertices': report['changed_vertices']}), flush=True)
