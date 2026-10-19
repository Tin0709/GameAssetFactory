"""Inspect the saved sniper and its exported GLB, not authoring intermediates."""
import bmesh
import bpy
import json
import struct
from pathlib import Path
from mathutils import Vector

OUT=Path(__file__).resolve().parent
source=OUT/'Sniper_Sand_Block_V1.blend'
assert source.exists(),'New sniper source has not been built'
bpy.ops.wm.open_mainfile(filepath=str(source))
c=bpy.data.collections['WEAPON_EXPORT']
meshes=[o for o in c.all_objects if o.type=='MESH']
assert len(meshes)==4 and not bpy.data.actions
root=bpy.data.objects['Sniper_Sand_Block_V1']
assert root.parent is None and root.location.length<1e-7
assert root['forward']=='+Y' and root['review_status']=='Pending'
assert bpy.data.objects['RightHandGrip'].location.length<1e-7
assert all(o.parent==root for o in meshes)
for o in meshes:
    bm=bmesh.new();bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),o.name
    assert all(v.link_faces for v in bm.verts),o.name
    bm.free()
    assert o.data.uv_layers.active
    assert all(0<v.uv.x<1 and 0<v.uv.y<1 for v in o.data.uv_layers.active.data)

def Y(x):return (x-137)*.0019
def Z(y):return (134-y)*.0019
frame=bpy.data.objects['Sniper_Sand_Frame']
lenses=bpy.data.objects['Sniper_Scope_Lenses']
bolt=bpy.data.objects['Sniper_Sand_Bolt']

def cast(o,origin,direction,distance=2):
    inv=o.matrix_world.inverted()
    hit,point,_,_=o.ray_cast(inv@Vector(origin),inv.to_3x3()@Vector(direction),distance=distance)
    return hit,o.matrix_world@point

# Both sides of the stock and guard must contain actual air, not dark decals.
for side in [-1,1]:
    for px,py in [(85,123),(93,133),(163,123)]:
        hit,_=cast(frame,(side*.20,Y(px),Z(py)),(-side,0,0))
        assert not hit,('Stock/guard opening blocked',px,py)
    for px in [316,342,368,394,420]:
        hit,point=cast(frame,(side*.20,Y(px),Z(89)),(-side,0,0))
        assert not hit or abs(point.x)<.022,('Vent is filled',px,list(point))
    for px in [608,624]:
        hit,point=cast(frame,(side*.20,Y(px),Z(79)),(-side,0,0))
        assert not hit,('Muzzle side slot blocked',px,list(point))
    hit,point=cast(frame,(side*.20,0,0),(-side,0,0))
    assert hit and .016<abs(point.x)<.026,'Grip origin is outside handle'

hit,point=cast(frame,(0,Y(700),Z(79)),(0,-1,0))
assert hit and point.y<Y(460),('Main bore is capped or shallow',list(point))
for x,zoff in [(0,0),(.008,0),(-.008,0),(0,.008),(0,-.008)]:
    hit,point=cast(frame,(x,Y(98),Z(42)+zoff),(0,1,0),distance=.50)
    assert not hit,('Metal blocks optic tunnel',x,zoff,list(point))
assert lenses['lens_count']==2 and len(lenses.data.materials)==2
for m in lenses.data.materials:
    bs=m.node_tree.nodes.get('Principled BSDF')
    assert bs.inputs['Transmission Weight'].default_value>.9
    assert bs.inputs['Roughness'].default_value<.15
    assert bs.inputs['IOR'].default_value>1.4
    assert .3<bs.inputs['Alpha'].default_value<.8
    r,g,b,_=bs.inputs['Base Color'].default_value
    assert r>g*3 and g>b*3,'Scope glass lost red-orange tint'
for origin,direction in [((0,Y(98),Z(42)),(0,1,0)),((0,Y(360),Z(42)),(0,-1,0))]:
    hit,point=cast(lenses,origin,direction)
    assert hit,'Missing actual lens surface'
assert bolt.dimensions.x>.050 and bolt.dimensions.z>.045,'Missing projecting angled bolt handle'

atlas=bpy.data.images['Sniper_Sand_Atlas_256']
assert atlas.packed_file and tuple(atlas.size)==(256,256)
pixels=list(atlas.pixels[:])
points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
dims=[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]
assert 1.18<dims[1]<1.23 and .28<dims[2]<.32,dims
source_markers={name:tuple(bpy.data.objects[name].matrix_world.translation)
    for name in ['RightHandGrip','LeftHandGuide','Muzzle','AimReference','MagazineFeed','BoltHandle']}
tris=0
for o in meshes:
    o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
assert tris<9000,tris
data=(OUT/'Sniper_Sand_Block_V1.glb').read_bytes()
length,kind=struct.unpack_from('<II',data,12)
assert kind==0x4e4f534a
gltf=json.loads(data[20:20+length])
glass_specs=[m for m in gltf['materials'] if 'KHR_materials_transmission' in m.get('extensions',{})]
assert len(glass_specs)==2
for m in glass_specs:
    assert m['extensions']['KHR_materials_transmission']['transmissionFactor']>.9
    assert m['alphaMode']=='BLEND'
    r,g,b,_=m['pbrMetallicRoughness']['baseColorFactor']
    assert r>g*3 and g>b*3
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'Sniper_Sand_Block_V1.glb'))
meshes=[o for o in bpy.data.objects if o.type=='MESH']
assert len(meshes)==4 and not bpy.data.actions
points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
export_dims=[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]
error=max(abs(a-b) for a,b in zip(dims,export_dims))
assert error<1e-6,(dims,export_dims)
for name,pos in source_markers.items():
    assert bpy.data.objects.get(name),name
    assert (bpy.data.objects[name].matrix_world.translation-Vector(pos)).length<1e-6,name
images=[im for im in bpy.data.images if im.type=='IMAGE']
assert len(images)==1 and tuple(images[0].size)==(256,256)
texture_error=max(abs(a-b) for a,b in zip(pixels,images[0].pixels[:]))
assert texture_error<1e-6,texture_error
result={'passed':True,'meshes':4,'materials':3,'triangles':tris,'dimensions_m':dims,
    'roundtrip_error_m':error,'texture_roundtrip_error':texture_error,
    'stock_and_guard_open':True,'deep_muzzle_bore':True,'real_brake_slots':4,
    'handguard_vents':10,'clear_metal_optic_tunnel_rays':5,'red_orange_transmitting_lenses':2,
    'grip_origin_inside_handle':True,'marker_roundtrip_exact':True,'animations':0}
(OUT/'validation.json').write_text(json.dumps(result,indent=2))
print('SNIPER_ASSET_VALIDATED',json.dumps(result))
