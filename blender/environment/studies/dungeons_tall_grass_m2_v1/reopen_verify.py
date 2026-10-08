import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'tall_grass_m2_v1.blend'))
o=bpy.data.objects['ENV_TallGrass_M2_V1']
assert abs(o.dimensions.z-1.95)<1e-6 and tuple(o.location)==(0,0,0)
assert len(o.data.polygons)*2==32
assert o.data.color_attributes['Bend'].data_type=='FLOAT_COLOR'
assert o.data.uv_layers['UV2']
assert all(tuple(d.uv)==(.5,.5) for d in o.data.uv_layers['UV2'].data)
assert any(i.packed_file for i in bpy.data.images if i.name.startswith('meadow_m2_atlas'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'tall_grass_m2_v1.glb'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH')
assert abs(o.dimensions.z-1.95)<1e-6 and tuple(o.location)==(0,0,0)
assert o.data.color_attributes and len(o.data.uv_layers)==2
assert len(o.data.polygons)==32
(ROOT/'reopen_verification.json').write_text(json.dumps({'status':'PASS','saved_blend_reopened':True,'native_glb_reimported':True,'height_m':o.dimensions.z,'triangles':len(o.data.polygons),'uv_layers':[u.name for u in o.data.uv_layers],'color_layers':[c.name for c in o.data.color_attributes]},indent=2))
print('REOPEN_VERIFY_PASS')
