"""Fresh-open source and binary export audit. No mutation of the live Blender UI."""
import bpy
import hashlib
import json
import math
import struct
import sys
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
EVIDENCE = ROOT / '.validation/flower_patch_v1'
sys.path.insert(0, str(HERE))
from flower_preservation import compare, digest, mesh_content, node_content, rna_values

bpy.ops.wm.open_mainfile(filepath=str(HERE / 'dungeons_ground_style_v2.blend'))
assert 'ENV_WhiteFlowerPatch_1m_V1' in bpy.data.objects, 'Missing one-block flat white flower mesh (expected initial RED)'
o = bpy.data.objects['ENV_WhiteFlowerPatch_1m_V1']
m = o.data
assert o.type == 'MESH' and not o.modifiers and not m.shape_keys
assert tuple(o.scale) == (1, 1, 1) and tuple(o.rotation_euler) == (0, 0, 0)
assert len(m.materials) == 1 and len(m.uv_layers) == 2
m.calc_loop_triangles()
assert len(m.loop_triangles) <= 220
assert len(m.polygons) == 50 and all(len(p.vertices) == 4 for p in m.polygons)
lo = [min(v.co[k] for v in m.vertices) for k in range(3)]
hi = [max(v.co[k] for v in m.vertices) for k in range(3)]
assert all(-.5 <= lo[k] < hi[k] <= .5 for k in (0, 1)) and abs(lo[2]) < 1e-8 and .28 <= hi[2] <= .5
assert not m.materials[0].use_backface_culling
bsdf = m.materials[0].node_tree.nodes.get('Principled BSDF')
assert bsdf.inputs['Roughness'].default_value >= .95 and bsdf.inputs['Metallic'].default_value == 0
assert bsdf.inputs['Alpha'].default_value == 1
parts = list(m.attributes['flower_part'].data)
flowers = list(m.attributes['flower_index'].data)
counts = {}
for p in m.polygons:
    pts = [m.vertices[i].co for i in p.vertices]
    assert p.area > 1e-7 and abs(p.normal.length - 1) < 1e-6
    assert max(abs((x - pts[0]).dot(p.normal)) for x in pts) < 1e-6
    fid, part = flowers[p.index].value, parts[p.index].value
    counts.setdefault(fid, {}).setdefault(part, 0)
    counts[fid][part] += 1
    roots = [m.uv_layers[1].data[li].uv.copy() for li in p.loop_indices]
    assert all((x - roots[0]).length < 1e-6 for x in roots)
    for li in p.loop_indices:
        uv = m.uv_layers[0].data[li].uv
        assert 0 <= uv.x <= 1 and .28 <= uv.y <= .44
        if part in (1, 2):
            assert uv.x == 1, 'Every petal and centre stays rigid under head sway'
        if m.vertices[m.loops[li].vertex_index].co.z == 0:
            assert uv.x == 0, 'Root must remain anchored'
    if part == 3:
        assert len(set(round(m.uv_layers[0].data[li].uv.x, 6) for li in p.loop_indices)) == 1, 'Leaf uses attachment height for whole rigid plane'
assert counts == {i: {0: 3, 1: 4, 2: 1, 3: 2} for i in range(5)}
baseline = json.loads((EVIDENCE / 'original_fingerprints_loaded.json').read_text())
changes = compare(baseline['data'])
assert not changes, 'Original data changed: ' + str(changes)
source_path = ROOT / 'blender/environment/studies/grass_block_reference_v4/grass_block_reference_v4.blend'
assert hashlib.sha256(source_path.read_bytes()).hexdigest() == baseline['grass_source_sha256']
grass = bpy.data.objects['REVIEW_Original_Grass_V4']
lowgrass = bpy.data.objects['REVIEW_Meadow_Grass_V4_065']
assert grass.data == lowgrass.data and tuple(lowgrass.scale) == (1, 1, float(struct.unpack('f', struct.pack('f', .65))[0]))
assert lowgrass.get('display_only') and grass.get('source_file')
with bpy.data.libraries.load(str(source_path), link=False) as (source, target):
    target.objects = ['ENV_Grass_Square_Leaves_V4']
fresh_grass = target.objects[0]
authored_grass, fresh_content = mesh_content(grass.data), mesh_content(fresh_grass.data)
assert {k: v for k,v in authored_grass.items() if k != 'materials'} == {k: v for k,v in fresh_content.items() if k != 'materials'}
old_mat, fresh_mat = grass.data.materials[0], fresh_grass.data.materials[0]
assert rna_values(old_mat) == rna_values(fresh_mat)
old_nodes, new_nodes = node_content(old_mat.node_tree), node_content(fresh_mat.node_tree)
for payload in (old_nodes, new_nodes):
    for node in payload['nodes'].values():
        # Compare actual packed image data separately; library appends get .001 names.
        if node['image']:
            img = bpy.data.images[node['image']]
            node['image'] = {'size': list(img.size), 'pixels_sha256': digest(list(img.pixels)), 'packed_sha256': hashlib.sha256(img.packed_file.data).hexdigest() if img.packed_file else None}
assert old_nodes == new_nodes, 'Appended v4 grass material/atlas must match original source'

glb_path = HERE / 'exports/white_flower_patch_1m_v1.glb'
raw = glb_path.read_bytes()
assert raw[:4] == b'glTF'
jlen, jtype = struct.unpack_from('<II', raw, 12)
g = json.loads(raw[20:20+jlen])
bin_start = 20+jlen
blen, btype = struct.unpack_from('<II', raw, bin_start)
binary = raw[bin_start+8:bin_start+8+blen]
assert len(g['meshes']) == 1 and len(g['meshes'][0]['primitives']) == 1
assert len(g['nodes']) == 1 and not any(k in g for k in ('skins', 'animations', 'cameras', 'images', 'textures'))
assert not g.get('extensions', {}).get('KHR_lights_punctual')
node = g['nodes'][0]
assert node.get('translation', [0, 0, 0]) == [0, 0, 0] and node.get('scale', [1, 1, 1]) == [1, 1, 1]
assert node.get('rotation', [0, 0, 0, 1]) == [0, 0, 0, 1]
prim = g['meshes'][0]['primitives'][0]
assert prim.get('mode', 4) == 4 and 'targets' not in prim
assert g['materials'][0]['doubleSided'] and g['materials'][0].get('alphaMode', 'OPAQUE') == 'OPAQUE'

def accessor(index):
    a = g['accessors'][index]
    v = g['bufferViews'][a['bufferView']]
    fmt = {5126: 'f', 5123: 'H', 5125: 'I', 5121: 'B'}[a['componentType']]
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
    sz = struct.calcsize('<' + fmt * width)
    stride = v.get('byteStride', sz)
    start = v.get('byteOffset', 0) + a.get('byteOffset', 0)
    values = [struct.unpack_from('<' + fmt * width, binary, start + i * stride) for i in range(a['count'])]
    if a.get('normalized'):
        values = [tuple(x / {5121: 255, 5123: 65535}[a['componentType']] for x in row) for row in values]
    return values

attrs = {key: accessor(value) for key, value in prim['attributes'].items()}
assert {'POSITION', 'NORMAL', 'COLOR_0', 'TEXCOORD_0', 'TEXCOORD_1'} <= set(attrs)
assert len(accessor(prim['indices'])) // 3 == len(m.loop_triangles)
# Match every exported vertex to its source corner after glTF Y-up and UV-V conversion.
expected = []
for p in m.polygons:
    for li in p.loop_indices:
        v = m.vertices[m.loops[li].vertex_index].co
        c = m.color_attributes['Color'].data[li].color
        u, r = m.uv_layers[0].data[li].uv, m.uv_layers[1].data[li].uv
        # glTF exports the calculated corner normal (Blender stores it with a
        # small angular rounding difference from MeshPolygon.normal).
        normal = m.corner_normals[li].vector
        assert abs(normal.length - 1) < 1e-5 and normal.dot(p.normal) > .99999
        expected.append(((v.x, v.z, -v.y), tuple(c), (u.x, 1-u.y), (r.x, 1-r.y), (normal.x, normal.z, -normal.y)))
max_error = 0
max_normal_error = 0
for i, position in enumerate(attrs['POSITION']):
    candidates = [item for item in expected if max(abs(a-b) for a,b in zip(position, item[0])) < 1e-6]
    assert candidates, 'Exported vertex has no source position'
    got = (position, attrs['COLOR_0'][i], attrs['TEXCOORD_0'][i], attrs['TEXCOORD_1'][i], attrs['NORMAL'][i])
    best = min(candidates, key=lambda item: max(abs(a-b) for ga, ex in zip(got, item) for a,b in zip(ga, ex)))
    errors = [max(abs(a-b) for a,b in zip(ga,ex)) for ga,ex in zip(got,best)]
    # COLOR_0 is normalized unsigned 16-bit; allow one quantization step.
    assert errors[0] < 1e-6 and errors[1] <= 1/65535+1e-7 and errors[2] < 1e-6 and errors[3] < 1e-6
    assert errors[4] < 1e-4 and abs(Vector(attrs['NORMAL'][i]).length-1) < 1e-5
    error = max(errors[:4])
    max_normal_error = max(max_normal_error, errors[4])
    max_error = max(max_error, error)
manifest = json.loads((HERE / 'white_flowers_v1_manifest.json').read_text())
assert manifest['glb_sha256'] == hashlib.sha256(raw).hexdigest()
revision_report = None
if (HERE/'white_flower_head_revision_v1.json').exists():
    from white_flower_head_revision_audit import audit_revision
    revision_report = audit_revision()
report = {'status': 'PASS', 'triangles': len(m.loop_triangles), 'quads': len(m.polygons), 'authored_vertices': len(m.vertices),
          'mesh_local_bounds_blender': [lo, hi], 'flower_face_counts': counts,
          'original_data_changes': changes, 'original_datablocks_checked': {k: len(v) for k,v in baseline['data'].items()},
          'original_fingerprint_digest': digest(baseline['data']), 'grass_source_sha256': baseline['grass_source_sha256'],
          'appended_grass_source_geometry_uv_colors_shape_keys_material_atlas_equal': True,
          'source_corner_to_glb_max_error': max_error, 'source_corner_to_glb_normal_max_error': max_normal_error,
          'glb_sha256': manifest['glb_sha256'], 'glb_vertices': len(attrs['POSITION']), 'authorized_head_revision_audit': revision_report}
(EVIDENCE / 'validation_source_and_glb.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
