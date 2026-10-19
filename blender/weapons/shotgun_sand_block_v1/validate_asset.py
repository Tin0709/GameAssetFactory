"""Verify the saved game prop and GLB, including actual visible openings."""
import bmesh
import bpy
import json
from pathlib import Path
from mathutils import Vector

OUT=Path(__file__).resolve().parent
source=OUT/'Shotgun_Sand_Block_V1.blend'
assert source.exists(),'New shotgun source has not been built'
bpy.ops.wm.open_mainfile(filepath=str(source))
c=bpy.data.collections['WEAPON_EXPORT']
meshes=[o for o in c.all_objects if o.type=='MESH']
assert len(meshes)==4 and not bpy.data.actions
root=bpy.data.objects['Shotgun_Sand_Block_V1']
assert root.parent is None and root.location.length<1e-7
assert root['forward']=='+Y' and root['review_status']=='Pending'
assert all(o.parent==root for o in meshes)
assert bpy.data.objects['RightHandGrip'].location.length<1e-7
for o in meshes:
    assert len(o.data.materials)==1 and o.data.uv_layers.active
    bm=bmesh.new();bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),o.name
    assert all(v.link_faces for v in bm.verts),o.name
    bm.free()
    assert all(0<v.uv.x<1 and 0<v.uv.y<1 for v in o.data.uv_layers.active.data)
frame=bpy.data.objects['Shotgun_Sand_Frame']
pump=bpy.data.objects['Shotgun_Sand_Pump']

def cast(o,origin,direction,distance=1):
    inv=o.matrix_world.inverted()
    hit,point,_,_=o.ray_cast(inv@Vector(origin),inv.to_3x3()@Vector(direction),distance=distance)
    return hit,o.matrix_world@point

for side in [-1,1]:
    hit,_=cast(frame,(side*.20,-.342,.075),(-side,0,0))
    assert not hit,'Stock opening is filled'
    hit,_=cast(frame,(side*.20,.028,.032),(-side,0,0))
    assert not hit,'Trigger guard opening is filled'
hit,point=cast(frame,(0,.76,.108),(0,-1,0))
assert hit and point.y<.49,('Main muzzle is shallow/capped',list(point))
hit,point=cast(frame,(0,.76,.044),(0,-1,0))
assert hit and .59<point.y<.616,('Missing recessed lower tube end',list(point))
hit,rib=cast(pump,(.20,.225,.059),(-1,0,0))
assert hit
hit,groove=cast(pump,(.20,.242,.059),(-1,0,0))
assert hit and rib.x-groove.x>.004,('Pump grooves lack depth',list(rib),list(groove))
hit,port=cast(frame,(-.20,-.030,.116),(1,0,0))
assert hit
hit,wall=cast(frame,(-.20,-.100,.116),(1,0,0))
assert hit and abs(wall.x)-abs(port.x)>.003,'Receiver port is not inset'
ammo=bpy.data.objects['Shotgun_Sand_Shells']
assert len([g for g in ammo.vertex_groups if g.name.startswith('Shell_Red_')])==4
atlas=bpy.data.images['Shotgun_Sand_Atlas_256']
assert atlas.packed_file and tuple(atlas.size)==(256,256)
pixels=list(atlas.pixels[:])
points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
dims=[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]
assert .98<dims[1]<1.12 and .24<dims[2]<.30,dims
tris=0
for o in meshes:
    o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
assert tris<6500,tris
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'Shotgun_Sand_Block_V1.glb'))
meshes=[o for o in bpy.data.objects if o.type=='MESH']
assert len(meshes)==4 and not bpy.data.actions
points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
export_dims=[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]
error=max(abs(a-b) for a,b in zip(dims,export_dims))
assert error<1e-6,(dims,export_dims)
for name in ['RightHandGrip','LeftHandGuide','Muzzle','AimReference','MagazineFeed']:
    assert bpy.data.objects.get(name),name
images=[im for im in bpy.data.images if im.type=='IMAGE']
assert len(images)==1 and tuple(images[0].size)==(256,256)
texture_error=max(abs(a-b) for a,b in zip(pixels,images[0].pixels[:]))
assert texture_error<1e-6,texture_error
result={'passed':True,'meshes':4,'materials':1,'triangles':tris,'dimensions_m':dims,
        'roundtrip_error_m':error,'texture_roundtrip_error':texture_error,
        'stock_and_guard_open':True,'deep_main_muzzle':True,'recessed_lower_cap':True,
        'pump_groove_depth_m':rib.x-groove.x,'inset_receiver_port':True,'shells':4,'animations':0}
(OUT/'validation.json').write_text(json.dumps(result,indent=2))
print('SHOTGUN_ASSET_VALIDATED',json.dumps(result))
