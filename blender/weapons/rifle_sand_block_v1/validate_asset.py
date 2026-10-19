"""Reopen the actual source/export; check asset and visible vent contracts."""
import bpy
import bmesh
import json
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Rifle_Sand_Block_V1.blend'))
collection = bpy.data.collections['WEAPON_EXPORT']
meshes = [o for o in collection.all_objects if o.type == 'MESH']
assert len(meshes) == 2
assert not bpy.data.actions
root = bpy.data.objects['Rifle_Sand_Block_V1']
assert root.parent is None and root.location.length < 1e-7
assert root['review_status'] == 'Pending'
assert root['forward'] == '+Y'
assert bpy.data.objects['Rifle_Sand_Block_Magazine'].parent == root
assert bpy.data.objects['Muzzle'].location.y > .86
assert bpy.data.objects['RightHandGrip'].location.length < 1e-7
for ob in meshes:
    assert len(ob.data.materials) == 1
    assert ob.data.uv_layers.active
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    assert all(e.is_manifold for e in bm.edges)
    assert all(v.link_faces for v in bm.verts)
    bm.free()
    assert all(0 < loop.uv.x < 1 and 0 < loop.uv.y < 1 for loop in ob.data.uv_layers.active.data)
body = bpy.data.objects['Rifle_Sand_Block_Body']
# Across every opening the first surface is the recessed central barrel, not
# a painted black rectangle or an exterior wall occluding the opening.
for i in range(7):
    y = .272+i*.038
    for side in [-1,1]:
        hit, point, _, _ = body.ray_cast(Vector((side*.2,y,.1275)),Vector((-side,0,0)))
        assert hit and abs(point.x) < .025, ('Blocked vent',i,side,list(point))
atlas = bpy.data.images['Sand_Block_Atlas_256']
assert atlas.packed_file and tuple(atlas.size) == (256,256)
points = [o.matrix_world@v.co for o in meshes for v in o.data.vertices]
source_dims = [max(v[i] for v in points)-min(v[i] for v in points) for i in range(3)]
source_tris = 0
for o in meshes:
    o.data.calc_loop_triangles()
    source_tris += len(o.data.loop_triangles)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'Rifle_Sand_Block_V1.glb'))
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
assert len(meshes) == 2 and not bpy.data.actions
points = [o.matrix_world@v.co for o in meshes for v in o.data.vertices]
export_dims = [max(v[i] for v in points)-min(v[i] for v in points) for i in range(3)]
assert max(abs(a-b) for a,b in zip(source_dims,export_dims)) < 1e-6
assert bpy.data.objects.get('RightHandGrip') and bpy.data.objects.get('Muzzle')
images = [im for im in bpy.data.images if im.type == 'IMAGE']
assert len(images) == 1 and tuple(images[0].size) == (256,256)
result = {'passed':True,'meshes':2,'triangles':source_tris,
          'vent_opening_ray_checks':14,'dimensions_m':source_dims,
          'roundtrip_dimensions_max_error_m':max(abs(a-b) for a,b in zip(source_dims,export_dims)),
          'packed_texture':[256,256], 'animations':0}
(OUT/'validation.json').write_text(json.dumps(result,indent=2))
print('SAND_BLOCK_ASSET_VALIDATED',json.dumps(result))
