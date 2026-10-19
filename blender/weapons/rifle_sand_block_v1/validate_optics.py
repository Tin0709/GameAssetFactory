"""Check the visible optic tunnel and real transmitting lens surfaces."""
import bpy
import json
import struct
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Rifle_Sand_Block_V1.blend'))
body = bpy.data.objects['Rifle_Sand_Block_Body']
for x,z in [(0,.233),(.009,.233),(-.009,.233),(0,.241),(0,.225)]:
    hit, point, _, _ = body.ray_cast(Vector((x,-.030,z)),Vector((0,1,0)),distance=.35)
    assert not hit, ('Opaque metal blocks optic bore',x,z,list(point))
lenses = bpy.data.objects.get('Rifle_Sand_Block_Lenses')
assert lenses and lenses['lens_count'] == 2
assert len(lenses.data.materials) == 2
glass = lenses.data.materials[0]
bsdf = glass.node_tree.nodes.get('Principled BSDF')
assert bsdf.inputs['Transmission Weight'].default_value > .9
assert bsdf.inputs['Roughness'].default_value < .15
assert bsdf.inputs['IOR'].default_value > 1.4
assert .3 < bsdf.inputs['Alpha'].default_value < .8
for material in lenses.data.materials:
    node = material.node_tree.nodes.get('Principled BSDF')
    assert node.inputs['Transmission Weight'].default_value > .9
    assert node.inputs['Roughness'].default_value < .15
    r,g,b,_ = node.inputs['Base Color'].default_value
    assert r > g*3 and g > b*3, ('Glass must retain the requested red-orange tint',material.name)
for origin,direction in [((0,-.030,.233),(0,1,0)),((0,.300,.233),(0,-1,0))]:
    hit, point, _, _ = lenses.ray_cast(Vector(origin),Vector(direction))
    assert hit and -.01 < point.y < .27
data = (OUT/'Rifle_Sand_Block_V1.glb').read_bytes()
length,kind = struct.unpack_from('<II',data,12)
assert kind == 0x4e4f534a
gltf = json.loads(data[20:20+length])
assert 'KHR_materials_transmission' in gltf['extensionsUsed']
glass_specs = [m for m in gltf['materials'] if 'KHR_materials_transmission' in m.get('extensions',{})]
assert len(glass_specs) == 2
for material in glass_specs:
    assert material['extensions']['KHR_materials_transmission']['transmissionFactor'] > .9
    assert material['alphaMode'] == 'BLEND'
    r,g,b,_ = material['pbrMetallicRoughness']['baseColorFactor']
    assert r > g*3 and g > b*3, 'GLB lost the red-orange glass tint'
result = {'passed':True,'clear_metal_bore_rays':5,'lens_surface_rays':2,
          'lens_count':2,'transmission':bsdf.inputs['Transmission Weight'].default_value,
          'gltf_transmission_preserved':True,'gltf_alpha_mode':'BLEND','lens_tint':'red-orange'}
(OUT/'optics_validation.json').write_text(json.dumps(result,indent=2))
print('OPTICS_VALIDATED',json.dumps(result))
