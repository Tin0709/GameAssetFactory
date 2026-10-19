"""Reopen actual Blender/GLB; validate silhouette contracts and genuine openings."""
import bmesh
import bpy
import json
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Pistol_Sand_Block_V1.blend'))
c = bpy.data.collections['WEAPON_EXPORT']
meshes = [o for o in c.all_objects if o.type == 'MESH']
assert len(meshes) == 3 and not bpy.data.actions
root = bpy.data.objects['Pistol_Sand_Block_V1']
assert root.parent is None and root.location.length < 1e-7
assert root['forward'] == '+Y' and root['review_status'] == 'Pending'
assert all(o.parent == root for o in meshes)
assert bpy.data.objects['RightHandGrip'].location.length < 1e-7
assert bpy.data.objects['MagazineFeed'].location.z > .04
for o in meshes:
    assert len(o.data.materials) == 1 and o.data.uv_layers.active
    bm = bmesh.new()
    bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),o.name
    assert all(v.link_faces for v in bm.verts),o.name
    bm.free()
    assert all(0 < x.uv.x < 1 and 0 < x.uv.y < 1 for x in o.data.uv_layers.active.data)
frame = bpy.data.objects['Pistol_Sand_Frame']
slide = bpy.data.objects['Pistol_Sand_Slide']


def cast(o,origin,direction,distance=1):
    inv = o.matrix_world.inverted()
    start = inv@Vector(origin)
    ray = inv.to_3x3()@Vector(direction)
    hit,point,_,_ = o.ray_cast(start,ray,distance=distance)
    return hit,o.matrix_world@point


# Both side-to-side views through the guard are empty ahead of the trigger.
for side in [-1,1]:
    for z in [.028,.035]:
        hit,point = cast(frame,(side*.1,.086*.98,z*.95),(-side,0,0))
        assert not hit,('Blocked trigger guard',side,z,list(point))
# A central ray reaches a deep recess; the warm front rim cannot cap the bore.
for ob in [frame,slide]:
    hit,point = cast(ob,(0,.30,.096*.95),(0,-1,0))
    assert hit and point.y < .115,('Shallow/capped muzzle',ob.name,list(point))
# The center of the rear sight remains open, while both raised ears exist.
hit,point = cast(slide,(0,-.10,.123*.95),(0,1,0),distance=.13)
assert not hit,('Rear sight notch capped',list(point))
for side in [-1,1]:
    hit,_ = cast(slide,(side*.010,-.10,.123*.95),(0,1,0),distance=.13)
    assert hit,'Missing rear sight ear'
# The lowered top chamber is visibly below the slide's surrounding top planes.
hit,point = cast(slide,(.017,.080*.98,.20),(0,0,-1))
assert hit and point.z < .094,('Top chamber is filled',list(point))
# Check the usable cavity below the frame/feed seat, rather than ray casting
# through the solid receiver above the grip's opening.
top_center = Vector((0,-.00225*.98,.034*.95))
bottom_center = Vector((0,-.031*.98,-.0505*.95))
ray = (top_center-bottom_center).normalized()
hit,point = cast(frame,bottom_center-ray*.025,ray,distance=(top_center-bottom_center).length+.024)
assert not hit,('Grip well is filled with frame geometry',list(point))
atlas = bpy.data.images['Pistol_Sand_Atlas_256']
assert atlas.packed_file and tuple(atlas.size) == (256,256)
source_pixels = list(atlas.pixels[:])
points = [o.matrix_world@v.co for o in meshes for v in o.data.vertices]
dims = [max(v[i] for v in points)-min(v[i] for v in points) for i in range(3)]
assert .26 < dims[1] < .30 and .16 < dims[2] < .20,dims
triangles = 0
for o in meshes:
    o.data.calc_loop_triangles()
    triangles += len(o.data.loop_triangles)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'Pistol_Sand_Block_V1.glb'))
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
assert len(meshes) == 3 and not bpy.data.actions
points = [o.matrix_world@v.co for o in meshes for v in o.data.vertices]
export_dims = [max(v[i] for v in points)-min(v[i] for v in points) for i in range(3)]
error = max(abs(a-b) for a,b in zip(dims,export_dims))
assert error < 1e-6,(dims,export_dims)
assert bpy.data.objects.get('Muzzle') and bpy.data.objects.get('MagazineFeed')
assert len([m for m in bpy.data.materials if m.use_nodes]) == 1
images = [im for im in bpy.data.images if im.type == 'IMAGE']
assert len(images) == 1 and tuple(images[0].size) == (256,256)
texture_error = max(abs(a-b) for a,b in zip(source_pixels,images[0].pixels[:]))
assert texture_error < 1e-6,('GLB texture differs from the saved source atlas',texture_error)
result = {'passed':True,'meshes':3,'materials':1,'triangles':triangles,
          'dimensions_m':dims,'roundtrip_error_m':error,'texture_roundtrip_error':texture_error,
          'guard_ray_checks':4,
          'muzzle_recess_ray_checks':2,'sight_notch_and_ears':True,
          'lowered_top_chamber':True,'open_grip_well':True,'animations':0}
(OUT/'validation.json').write_text(json.dumps(result,indent=2))
print('PISTOL_ASSET_VALIDATED',json.dumps(result))
