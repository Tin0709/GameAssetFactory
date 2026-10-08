"""Read-only fresh-open tall grass audit. Never saves source or touches live UI."""
import bpy
import hashlib
import json
import struct
import sys
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
EVIDENCE = ROOT / '.validation/flower_patch_v1'
sys.path.insert(0, str(HERE))
from flower_preservation import compare, digest

bpy.ops.wm.open_mainfile(filepath=str(HERE / 'dungeons_ground_style_v2.blend'))
assert 'ENV_TallGoldenGrass_1m_V1' in bpy.data.objects, 'Missing tall planar golden-headed grass (expected initial RED)'
o = bpy.data.objects['ENV_TallGoldenGrass_1m_V1']
m = o.data
assert not o.modifiers and not m.shape_keys and not o.animation_data
assert tuple(o.scale) == (1, 1, 1) and tuple(o.rotation_euler) == (0, 0, 0)
assert len(m.materials) == 1 and len(m.uv_layers) == 2
m.calc_loop_triangles()
assert len(m.polygons) == 28*7 and len(m.loop_triangles) == 392 <= 500
assert all(len(p.vertices) == 4 and not p.use_smooth for p in m.polygons)
lo = [min(v.co[i] for v in m.vertices) for i in range(3)]
hi = [max(v.co[i] for v in m.vertices) for i in range(3)]
fan_report = None
if (HERE/'tall_golden_fan_revision_v1.json').exists():
    from tall_golden_fan_revision_audit import audit_tall_fan
    fan_report = audit_tall_fan()
    assert -.65 <= lo[0] < hi[0] <= .65 and -.65 <= lo[1] < hi[1] <= .65 and lo[2] == 0
    assert hi[0]-lo[0] <= 1.3 and hi[1]-lo[1] <= 1.3
else:
    assert -.5 <= lo[0] < hi[0] <= .5 and -.5 <= lo[1] < hi[1] <= .5 and lo[2] == 0
assert 2.15 <= hi[2] <= 2.4 and hi[2] > 1.8
mat = m.materials[0]
assert not mat.use_backface_culling
bsdf = mat.node_tree.nodes.get('Principled BSDF')
assert bsdf.inputs['Roughness'].default_value == 1 and bsdf.inputs['Metallic'].default_value == 0 and bsdf.inputs['Alpha'].default_value == 1
assert not any(n.type == 'TEX_IMAGE' for n in mat.node_tree.nodes)
stems, parts = m.attributes['stem_index'], m.attributes['part']
counts, heights, root_uv = {}, {}, {}
for p in m.polygons:
    fid, part = stems.data[p.index].value, parts.data[p.index].value
    counts.setdefault(fid, {}).setdefault(part, 0); counts[fid][part] += 1
    pts = [m.vertices[i].co for i in p.vertices]
    assert p.area > 1e-6 and abs(p.normal.length-1) < 1e-6
    assert max(abs((point-pts[0]).dot(p.normal)) for point in pts) < 1e-6
    for li in p.loop_indices:
        v = m.vertices[m.loops[li].vertex_index].co
        uv, root = m.uv_layers[0].data[li].uv, m.uv_layers[1].data[li].uv
        assert 0 <= uv.x <= 1 and 1.9 <= uv.y <= 2.2
        heights.setdefault(fid, uv.y); root_uv.setdefault(fid, root.copy())
        assert abs(uv.y-heights[fid]) < 1e-6 and (root-root_uv[fid]).length < 1e-6
        if part == 1:
            assert uv.x == 1 and v.z >= uv.y-.08, 'Top seed planes have rigid mask and belong to top'
        else:
            assert abs(v.z-uv.x*uv.y) < 1e-6
            if v.z == 0:
                assert uv.x == 0
assert counts == {i: {0: 3, 1: 4} for i in range(28)}
for fid in range(28):
    polys = [p for p in m.polygons if stems.data[p.index].value == fid and parts.data[p.index].value == 0]
    bottom = [m.vertices[i].co for i in polys[0].vertices[:2]]
    top = [m.vertices[i].co for i in polys[-1].vertices[2:]]
    width = (bottom[1]-bottom[0]).length
    assert .11 <= width <= .19 and abs((top[0]-top[1]).length-width) < 1e-6
    centre = (bottom[0]+bottom[1])*.5
    assert (Vector((centre.x+.5, centre.y+.5))-root_uv[fid]).length < 1e-6
    rings = sorted(set(round(m.uv_layers[0].data[li].uv.x, 6) for p in polys for li in p.loop_indices))
    assert rings == [0, .22, .65, 1]
baseline = json.loads((EVIDENCE / 'before_tall_golden_grass_fingerprints.json').read_text())
changes = compare(baseline['data'])
authorized_head_revision = None
if changes:
    assert changes == [('objects','ENV_WhiteFlowerPatch_1m_V1'),('meshes','ENV_WhiteFlowerPatch_1m_V1_PlanarMesh')], 'Unexpected previous data change: '+str(changes)
    from white_flower_head_revision_audit import audit_revision
    authorized_head_revision = audit_revision()
current_white_hash = hashlib.sha256((HERE / 'exports/white_flower_patch_1m_v1.glb').read_bytes()).hexdigest()
if authorized_head_revision:
    revision_spec = json.loads((HERE/'white_flower_head_revision_v1.json').read_text())
    white_manifest = json.loads((HERE/'white_flowers_v1_manifest.json').read_text())
    assert baseline['white_flower_glb_sha256'] == revision_spec['baseline_white_glb_sha256']
    assert current_white_hash == white_manifest['glb_sha256']
else:
    assert current_white_hash == baseline['white_flower_glb_sha256']
assert hashlib.sha256((ROOT / 'blender/environment/studies/grass_block_reference_v4/grass_block_reference_v4.blend').read_bytes()).hexdigest() == baseline['grass_source_sha256']

path = HERE / 'exports/tall_golden_grass_1m_v1.glb'
raw = path.read_bytes()
assert raw[:4] == b'glTF'
jlen = struct.unpack_from('<I', raw, 12)[0]
g = json.loads(raw[20:20+jlen])
bin_start = 20+jlen
blen = struct.unpack_from('<I', raw, bin_start)[0]
binary = raw[bin_start+8:bin_start+8+blen]
assert len(g['nodes']) == len(g['meshes']) == 1 and len(g['meshes'][0]['primitives']) == 1
assert not any(k in g for k in ('animations', 'skins', 'cameras', 'images', 'textures'))
assert not g.get('extensions', {}).get('KHR_lights_punctual')
node = g['nodes'][0]
assert node.get('translation', [0, 0, 0]) == [0, 0, 0] and node.get('scale', [1, 1, 1]) == [1, 1, 1]
assert node.get('rotation', [0, 0, 0, 1]) == [0, 0, 0, 1]
primitive = g['meshes'][0]['primitives'][0]
assert primitive.get('mode', 4) == 4 and not primitive.get('targets')
assert len(g['materials']) == 1 and g['materials'][0]['doubleSided'] and g['materials'][0].get('alphaMode', 'OPAQUE') == 'OPAQUE'

def accessor(index):
    a = g['accessors'][index]; v = g['bufferViews'][a['bufferView']]
    fmt = {5126: 'f', 5123: 'H', 5125: 'I', 5121: 'B'}[a['componentType']]
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
    size = struct.calcsize('<'+fmt*width)
    offset = v.get('byteOffset', 0)+a.get('byteOffset', 0)
    result = [struct.unpack_from('<'+fmt*width, binary, offset+i*v.get('byteStride', size)) for i in range(a['count'])]
    if a.get('normalized'):
        result = [tuple(x/{5121: 255, 5123: 65535}[a['componentType']] for x in row) for row in result]
    return result

attrs = {key: accessor(index) for key,index in primitive['attributes'].items()}
assert {'POSITION', 'NORMAL', 'COLOR_0', 'TEXCOORD_0', 'TEXCOORD_1'} <= set(attrs)
assert len(accessor(primitive['indices']))//3 == 392
assert all(uv[1] < 0 and 1.9 < 1-uv[1] < 2.2 for uv in attrs['TEXCOORD_0']), 'Negative UV metadata must survive glTF export'
expected = []
for p in m.polygons:
    for li in p.loop_indices:
        v = m.vertices[m.loops[li].vertex_index].co
        c = m.color_attributes['Color'].data[li].color
        uv, root, normal = m.uv_layers[0].data[li].uv, m.uv_layers[1].data[li].uv, m.corner_normals[li].vector
        assert normal.dot(p.normal) > .99999
        expected.append(((v.x, v.z, -v.y), tuple(c), (uv.x, 1-uv.y), (root.x, 1-root.y), (normal.x, normal.z, -normal.y)))
max_errors = [0]*5
for i,position in enumerate(attrs['POSITION']):
    candidates = [item for item in expected if max(abs(a-b) for a,b in zip(position,item[0])) < 1e-6]
    assert candidates
    got = (position, attrs['COLOR_0'][i], attrs['TEXCOORD_0'][i], attrs['TEXCOORD_1'][i], attrs['NORMAL'][i])
    best = min(candidates, key=lambda item: max(abs(a-b) for ga,ex in zip(got,item) for a,b in zip(ga,ex)))
    errors = [max(abs(a-b) for a,b in zip(ga,ex)) for ga,ex in zip(got,best)]
    assert errors[0] < 1e-6 and errors[1] <= 1/65535+1e-7 and errors[2] < 1e-6 and errors[3] < 1e-6
    assert errors[4] < 1.5e-4 and abs(Vector(attrs['NORMAL'][i]).length-1) < 1e-5
    max_errors = [max(a,b) for a,b in zip(max_errors,errors)]
manifest = json.loads((HERE / 'tall_golden_grass_v1_manifest.json').read_text())
assert manifest['glb_sha256'] == hashlib.sha256(raw).hexdigest()
assert manifest['player_rest_stature_m'] == 1.8 and manifest['source_continuation_fingerprint'] == digest(baseline['data'])
report = {'status': 'PASS', 'triangles': 392, 'quads': len(m.polygons), 'authored_vertices': len(m.vertices), 'stem_count': 28,
          'bounds_blender': [lo,hi], 'head_base_height_range_m': [min(heights.values()),max(heights.values())],
          'player_rest_stature_m': 1.8, 'top_above_player_rest_m': hi[2]-1.8,
          'negative_exported_uv_height_metadata_preserved': True, 'source_corner_export_max_errors_position_color_uv0_uv2_normal': max_errors,
          'prior_data_changes': changes, 'prior_datablocks_checked': {k:len(v) for k,v in baseline['data'].items()},
          'continuation_fingerprint': digest(baseline['data']), 'white_flower_export_preserved_without_revision': not bool(authorized_head_revision),
          'white_flower_user_authorized_head_revision_audit': authorized_head_revision, 'unauthorized_prior_data_changes': [], 'v4_source_preserved': True,
          'glb_sha256': manifest['glb_sha256'], 'glb_vertex_count': len(attrs['POSITION']), 'authorized_fan_revision_audit': fan_report,
          'export_scope': 'Blender study only; no current game integration'}
(EVIDENCE / 'validation_tall_golden_grass_source_glb.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
