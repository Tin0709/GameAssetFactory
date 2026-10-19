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
authoring_origin=Vector(root.get('authoring_origin',(0,0,0)))
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
    hit,point,_,_=o.ray_cast(inv@(Vector(origin)-authoring_origin),inv.to_3x3()@Vector(direction),distance=distance)
    return hit,o.matrix_world@point+authoring_origin

for side in [-1,1]:
    for y,z in [(-.0716,.156),(.613,.1302)]:
        hit,point=cast(frame,(side*.12,y,z),(-side,0,0))
        assert hit and .010<abs(point.x)<.020,('Sight mount has an air gap',y,z)
    for y,z in [(-.340,.025),(-.310,.040),(-.280,.058)]:
        hit,_=cast(frame,(side*.20,y,z),(-side,0,0))
        assert not hit,('Stepped stock opening is filled',side,y,z)
    hit,_=cast(frame,(side*.20,-.035,.034),(-side,0,0))
    assert not hit,'Trigger guard opening is filled'
hit,point=cast(frame,(0,.76,.108),(0,-1,0))
assert hit and point.y<.49,('Main muzzle is shallow/capped',list(point))
for side in [-1,1]:
    hit,point=cast(frame,(side*.12,.615,.110),(-side,0,0))
    assert hit and abs(point.x)<.020,('Muzzle side window is raised/filled',list(point))
hit,barrel_bottom=cast(frame,(0,.469,.08825),(0,0,1))
assert hit
hit,collar_top=cast(frame,(0,.469,.08825),(0,0,-1))
collar_gap=barrel_bottom.z-collar_top.z
assert hit and .001<collar_gap<.004,('Excess gap between barrel and tube collars',collar_gap)
hit,barrel_bottom=cast(frame,(0,.580,.086),(0,0,1))
assert hit
hit,tube_top=cast(frame,(0,.580,.086),(0,0,-1))
tube_gap=barrel_bottom.z-tube_top.z
assert hit and .004<tube_gap<.008,('Excess gap between bare tubes',tube_gap)
hit,point=cast(frame,(0,.76,.066),(0,-1,0))
assert hit and .59<point.y<.616,('Missing recessed lower tube end',list(point))
hit,rib=cast(pump,(.20,.268,.078),(-1,0,0))
assert hit
hit,groove=cast(pump,(.20,.246,.078),(-1,0,0))
assert hit and .0015<rib.x-groove.x<.0035,('Pump grooves are absent or too deep',list(rib),list(groove))
assert pump.dimensions.x<.070 and .223<pump.dimensions.y<.231,tuple(pump.dimensions)
pump_width=pump.dimensions.x
hit,pump_top=cast(pump,(0,.330,.20),(0,0,-1))
assert hit
hit,pump_bottom=cast(pump,(0,.330,0),(0,0,1))
assert hit and .073<pump_top.z-pump_bottom.z<.080,'Pump body is too tall'
for side in [-1,1]:
    hit,point=cast(frame,(side*.12,authoring_origin.y,authoring_origin.z),(-side,0,0))
    assert hit and .017<abs(point.x)<.026,'RightHandGrip is not inside the grip'
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
assert .98<dims[1]<1.12 and .22<dims[2]<.25,dims
source_markers={name:tuple(bpy.data.objects[name].matrix_world.translation)
                for name in ['RightHandGrip','LeftHandGuide','Muzzle','AimReference','MagazineFeed']}
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
    assert (bpy.data.objects[name].matrix_world.translation-Vector(source_markers[name])).length<1e-6,name
images=[im for im in bpy.data.images if im.type=='IMAGE']
assert len(images)==1 and tuple(images[0].size)==(256,256)
texture_error=max(abs(a-b) for a,b in zip(pixels,images[0].pixels[:]))
assert texture_error<1e-6,texture_error
result={'passed':True,'meshes':4,'materials':1,'triangles':tris,'dimensions_m':dims,
        'roundtrip_error_m':error,'texture_roundtrip_error':texture_error,
        'stock_and_guard_open':True,'deep_main_muzzle':True,'recessed_muzzle_side_windows':True,
        'recessed_lower_cap':True,
        'barrel_to_collar_gap_m':collar_gap,'barrel_to_lower_tube_gap_m':tube_gap,
        'pump_width_m':pump_width,'pump_body_height_m':pump_top.z-pump_bottom.z,
        'grip_origin_inside_handle':True,'marker_roundtrip_exact':True,
        'sight_seats_attached':True,
        'pump_groove_depth_m':rib.x-groove.x,'inset_receiver_port':True,'shells':4,'animations':0}
(OUT/'validation.json').write_text(json.dumps(result,indent=2))
print('SHOTGUN_ASSET_VALIDATED',json.dumps(result))
