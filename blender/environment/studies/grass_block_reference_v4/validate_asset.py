"""Blender v4 asset contract: fail before authoring, validate saved file after export."""
import bpy
import hashlib
import json
import math
import struct
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[4]
STUDY = Path(__file__).resolve().parent
ASSET = STUDY / 'grass_block_reference_v4.blend'
OUT = ROOT / 'game_mobile_3d/assets/environment/grassland'
V3_HASH = 'f1243780e7197d6b3495a43e9e19a145f5e4693bec08c8c502611ba1a2cc20be'
assert ASSET.exists(), 'Missing v4 square-ended grass Blender study'
bpy.ops.wm.open_mainfile(filepath=str(ASSET))
scene = bpy.data.scenes['ENV_Grass_Block_Reference_V4']
bpy.context.window.scene = scene
grass = bpy.data.objects['ENV_Grass_Square_Leaves_V4']
block = bpy.data.objects['ENV_GrassDirt_Block_1m']
mesh = grass.data
basis = [v.co.copy() for v in mesh.shape_keys.key_blocks['Basis'].data]
assert len(basis) == 36 * 8
mesh.calc_loop_triangles()
assert len(mesh.loop_triangles) == 216 and len(mesh.loop_triangles) <= 294
assert tuple(round(v, 6) for v in block.dimensions) == (1, 1, 1)
assert not grass.modifiers and not block.modifiers
mask = mesh.color_attributes['GRASS_BEND_DATA']
assert mask.domain == 'POINT'
heights, widths = [], []
for blade in range(36):
    start = blade * 8
    root = (basis[start] + basis[start+1]) * .5
    height = basis[start+6].z
    width = (basis[start+1] - basis[start]).length
    heights.append(height); widths.append(width)
    assert .28 <= height <= .48 and .12 <= width <= .20
    assert abs(root.z) < 1e-8
    direction = basis[start+1] - basis[start]
    for ring, t in enumerate((0, .22, .65, 1)):
        left, right = basis[start+ring*2:start+ring*2+2]
        assert abs(left.z-height*t) < 1e-6 and abs(right.z-left.z) < 1e-7
        # A substantial horizontal edge survives at the tip, with no taper.
        assert ((right-left)-direction).length < 1e-6
        for vi in (start+ring*2, start+ring*2+1):
            expected = (t*t, t, height/.48, 1)
            assert max(abs(a-b) for a,b in zip(mask.data[vi].color, expected)) < 1e-6
    for polygon in mesh.polygons[blade*3:blade*3+3]:
        for li in polygon.loop_indices:
            uv = mesh.uv_layers['UV_Blade_Root'].data[li].uv
            assert abs(uv.x-.5-root.x) < 1e-6 and abs(uv.y-.5-root.y) < 1e-6
    # Blade stays a single flat planar ribbon, no thickness or crossing rings.
    normal = direction.cross(basis[start+6]-basis[start])
    assert normal.length > 1e-5
    normal.normalize()
    assert max(abs((v-basis[start]).dot(normal)) for v in basis[start:start+8]) < 1e-6
roots = [i for i,v in enumerate(basis) if v.z == 0]
def evaluated(frame):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    obj = grass.evaluated_get(bpy.context.evaluated_depsgraph_get())
    temporary = obj.to_mesh()
    values = [v.co.copy() for v in temporary.vertices]
    obj.to_mesh_clear()
    return values
first, last = evaluated(1), evaluated(97)
assert max((a-b).length for a,b in zip(first,last)) < 1e-6
root_error, wind_max = 0, 0
for frame in (1, 13, 25, 37, 49, 61, 73, 85, 97):
    coords = evaluated(frame)
    root_error = max(root_error, max((coords[i]-basis[i]).length for i in roots))
    wind_max = max(wind_max, max((v-rest).length for v,rest in zip(coords,basis)))
assert root_error < 1e-8 and .014 < wind_max < .026
image = bpy.data.images['ENV_Atlas_128_Reference_V4']
assert image.packed_file and tuple(image.size) == (128, 128)
assert all(abs(v-1) < 1e-7 for v in image.pixels[3::4])
material = mesh.materials[0]
assert not material.use_backface_culling
assert any(n.type == 'TEX_IMAGE' and n.interpolation == 'Closest' for n in material.node_tree.nodes)
assert not grass.visible_shadow
for name in ('grass_patch_v4.glb', 'grass_dirt_block_v4.glb', 'environment_atlas_v4.png', 'export_manifest_v4.json'):
    assert (OUT/name).exists(), 'Missing export: ' + name
manifest = json.loads((OUT/'export_manifest_v4.json').read_text())
assert manifest['grass_cap_depth_multiplier'] == 1.15
for vertex, old in zip(block.data.vertices, manifest['original_block_vertex_coordinates']):
    assert abs(vertex.co.x-old[0]) < 1e-7 and abs(vertex.co.y-old[1]) < 1e-7
    expected_z = 1-(1-old[2])*1.15 if 0 < old[2] < 1 else old[2]
    assert abs(vertex.co.z-expected_z) < 1e-7
assert sorted(set(round(1-v.co.z,6) for v in block.data.vertices if 0<v.co.z<1)) == [.14375,.215625,.2875]
assert manifest['source_sha256'] == V3_HASH
assert hashlib.sha256((ROOT/'blender/environment/studies/grass_block_wind_v3/grass_block_wind_v3.blend').read_bytes()).hexdigest() == V3_HASH
for filename, digest in manifest['preserved_v3_exports_sha256'].items():
    assert hashlib.sha256((OUT/filename).read_bytes()).hexdigest() == digest

def glb(path):
    data=path.read_bytes()
    assert data[:4] == b'glTF'
    length,kind=struct.unpack_from('<II',data,12)
    document=json.loads(data[20:20+length])
    start=20+length
    binary_length,binary_kind=struct.unpack_from('<II',data,start)
    assert binary_kind == 0x004e4942
    return document,data[start+8:start+8+binary_length]

def accessor(document,binary,index):
    entry=document['accessors'][index];view=document['bufferViews'][entry['bufferView']]
    format_code,component_bytes={5121:('B',1),5123:('H',2),5125:('I',4),5126:('f',4)}[entry['componentType']]
    dimensions={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[entry['type']]
    stride=view.get('byteStride',component_bytes*dimensions)
    offset=view.get('byteOffset',0)+entry.get('byteOffset',0)
    result=[]
    for item in range(entry['count']):
        values=struct.unpack_from('<'+format_code*dimensions,binary,offset+item*stride)
        if entry.get('normalized'):
            maximum={5121:255,5123:65535}[entry['componentType']]
            values=tuple(v/maximum for v in values)
        result.append(values)
    return result

document,binary=glb(OUT/'grass_patch_v4.glb')
assert not document.get('animations') and not document.get('skins')
primitive=document['meshes'][0]['primitives'][0]
assert not primitive.get('targets')
attributes=primitive['attributes']
assert all(name in attributes for name in ('POSITION','TEXCOORD_0','TEXCOORD_1','COLOR_0'))
positions=accessor(document,binary,attributes['POSITION'])
rootuv=accessor(document,binary,attributes['TEXCOORD_1'])
colors=accessor(document,binary,attributes['COLOR_0'])
indices=accessor(document,binary,primitive['indices'])
assert len(indices)//3 == 216
exported_top_count=0
for pos,uv,color in zip(positions,rootuv,colors):
    # Blender (x,y,z) -> glTF (x,z,-y), including flipped texture V.
    local=Vector((pos[0],-pos[2],pos[1]))
    matches=[i for i,co in enumerate(basis) if (local-co).length<1e-6]
    assert matches, 'Exported non-rest vertex or geometry drift'
    vi=matches[0];blade=vi//8;start=blade*8
    root=(basis[start]+basis[start+1])*.5
    assert abs(uv[0]-.5-root.x)<1e-6 and abs(uv[1]-.5+root.y)<1e-6
    assert max(abs(a-b) for a,b in zip(color,mask.data[vi].color))<2/65535
    if vi%8 >= 6: exported_top_count+=1
assert exported_top_count == 72
document,binary=glb(OUT/'grass_dirt_block_v4.glb')
primitive=document['meshes'][0]['primitives'][0]
block_positions=accessor(document,binary,primitive['attributes']['POSITION'])
for axis in range(3):
    assert abs(max(v[axis] for v in block_positions)-min(v[axis] for v in block_positions)-1)<1e-7
assert len(accessor(document,binary,primitive['indices']))//3 == 288
cap_depths=sorted(set(round(1-v[1],6) for v in block_positions if 0<v[1]<1))
assert cap_depths == [.14375,.215625,.2875]
report = dict(all_checks_passed=True, blade_count=36, triangles=216,
              height_range_m=[min(heights),max(heights)], width_range_m=[min(widths),max(widths)],
              tip_width_ratio=1, root_error_m=root_error, preview_wind_max_m=wind_max,
              v3_source_sha256=V3_HASH, block_dimensions_m=list(block.dimensions))
report['grass_cap_depth_multiplier']=1.15
report['grass_cap_depths_old_m']=manifest['grass_cap_depths_old_m']
report['grass_cap_depths_new_m']=manifest['grass_cap_depths_new_m']
report['exported_glb_rest_vertices_masks_uv2_square_tips_verified']=True
report['exported_top_vertices']=exported_top_count
(STUDY/'validation_report.json').write_text(json.dumps(report,indent=2))
print('V4_ASSET_VALIDATED ' + json.dumps(report))
