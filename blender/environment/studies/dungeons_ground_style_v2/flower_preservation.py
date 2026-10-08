"""Stable content fingerprints for existing Blender data; ignores UI selection/users."""
import bpy
import hashlib
import json
import struct


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), default=str).encode()).hexdigest()


def scalar_copy(item):
    if isinstance(item, (str, bool, int, float)) or item is None:
        return item
    if isinstance(item, set):
        return sorted(item)
    if hasattr(item, '__iter__'):
        return [scalar_copy(x) for x in item]
    return str(item)


def rna_values(value):
    result = {}
    for prop in value.bl_rna.properties:
        if prop.identifier in {'rna_type', 'name', 'name_full', 'users', 'use_fake_user', 'is_updated', 'is_updated_data', 'is_updated_transform', 'is_runtime_data', 'tag', 'session_uid'}:
            continue
        if prop.type in {'BOOLEAN', 'INT', 'FLOAT', 'STRING', 'ENUM'}:
            try:
                item = getattr(value, prop.identifier)
                result[prop.identifier] = scalar_copy(item)
            except Exception:
                pass
    return result


def node_content(tree):
    if not tree:
        return None
    return {'nodes': {n.name: {'type': n.bl_idname, 'rna': rna_values(n), 'image': n.image.name if hasattr(n, 'image') and n.image else None,
                              'inputs': {s.identifier: list(s.default_value) if hasattr(s.default_value, '__len__') and not isinstance(s.default_value, str) else s.default_value for s in n.inputs if hasattr(s, 'default_value')}} for n in tree.nodes},
            'links': sorted((l.from_node.name, l.from_socket.identifier, l.to_node.name, l.to_socket.identifier) for l in tree.links)}


def mesh_content(mesh):
    result = {'vertices': [list(v.co) for v in mesh.vertices], 'edges': [list(e.vertices) for e in mesh.edges],
              'faces': [(list(p.vertices), p.material_index, p.use_smooth) for p in mesh.polygons],
              'uv': {u.name: [list(x.uv) for x in u.data] for u in mesh.uv_layers},
              'colors': {c.name: {'type': c.data_type, 'domain': c.domain, 'values': [list(x.color) for x in c.data]} for c in mesh.color_attributes},
              'materials': [m.name if m else None for m in mesh.materials]}
    if mesh.shape_keys:
        result['keys'] = {k.name: [list(v.co) for v in k.data] for k in mesh.shape_keys.key_blocks}
    return result


def snapshot():
    bpy.context.view_layer.update()
    result = {'objects': {}, 'meshes': {}, 'materials': {}, 'images': {}, 'cameras': {}, 'lights': {}, 'worlds': {}, 'scenes': {}}
    for o in bpy.data.objects:
        result['objects'][o.name] = digest({'rna': rna_values(o), 'matrix': [list(row) for row in o.matrix_basis],
                                         'data': o.data.name if o.data else None, 'parent': o.parent.name if o.parent else None,
                                         'collections': sorted(c.name for c in o.users_collection),
                                         'modifiers': [(m.name, m.type, rna_values(m)) for m in o.modifiers],
                                         'props': dict(o.items())})
    for m in bpy.data.meshes:
        result['meshes'][m.name] = digest(mesh_content(m))
    for m in bpy.data.materials:
        result['materials'][m.name] = digest({'rna': rna_values(m), 'nodes': node_content(m.node_tree)})
    for i in bpy.data.images:
        # Render Result / Viewer transient images have no authored pixels.
        if i.type in {'RENDER_RESULT', 'COMPOSITING'}:
            continue
        # Access pixels before has_data: packed images load lazily after file open.
        # A cache state change must not masquerade as an authored image edit.
        pixel_values = list(i.pixels)
        pixels = struct.pack('<' + 'f' * len(pixel_values), *pixel_values)
        result['images'][i.name] = digest({'size': list(i.size), 'filepath': i.filepath, 'source': i.source,
                                         'colorspace': i.colorspace_settings.name, 'pixels': hashlib.sha256(pixels).hexdigest(),
                                         'packed': hashlib.sha256(i.packed_file.data).hexdigest() if i.packed_file else None})
    for label, data in [('cameras', bpy.data.cameras), ('lights', bpy.data.lights)]:
        for d in data:
            result[label][d.name] = digest(rna_values(d))
    for w in bpy.data.worlds:
        result['worlds'][w.name] = digest({'rna': rna_values(w), 'nodes': node_content(w.node_tree)})
    for s in bpy.data.scenes:
        result['scenes'][s.name] = digest({'camera': s.camera.name if s.camera else None, 'world': s.world.name if s.world else None,
                                         'render': rna_values(s.render), 'cycles': rna_values(s.cycles),
                                         'view': rna_values(s.view_settings), 'units': rna_values(s.unit_settings)})
    return result


def compare(baseline):
    current = snapshot()
    return [(group, name) for group, values in baseline.items() for name, expected in values.items() if current[group].get(name) != expected]
