"""Validate saved sword component geometry, decorative recesses and GLB parity."""
import bpy,bmesh,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
source=OUT/'Sword_Sand_Block_V1.blend'
assert source.exists(),'Sword source has not been built'
bpy.ops.wm.open_mainfile(filepath=str(source))
root=bpy.data.objects['Sword_Sand_Block_V1'];c=bpy.data.collections['WEAPON_EXPORT']
meshes=[o for o in c.all_objects if o.type=='MESH']
assert len(meshes)==2 and not bpy.data.actions
assert root.parent is None and root.location.length<1e-7 and root['review_status']=='Pending'
assert root['forward']=='+Y' and bpy.data.objects['RightHandGrip'].location.length<1e-7
points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
dims=[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]
assert 1.09<dims[1]<1.12 and .24<dims[2]<.26 and .07<dims[0]<.09,dims
tris=0
for o in meshes:
    assert o.parent==root and len(o.data.materials)==1 and o.data.uv_layers.active
    bm=bmesh.new();bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),o.name
    assert all(v.link_faces for v in bm.verts),o.name
    bm.free();o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
    assert all(0<v.uv.x<1 and 0<v.uv.y<1 for v in o.data.uv_layers.active.data)
assert tris<6500,tris
blade=bpy.data.objects['Sword_Blade'];hilt=bpy.data.objects['Sword_Hilt']
def Y(px):return (px-116)*.0019
def Z(py):return (587-py)*.0019
def cast(ob,origin,direction):
    inv=ob.matrix_world.inverted()
    hit,p,_,_=ob.ray_cast(inv@Vector(origin),inv.to_3x3()@Vector(direction),distance=2)
    return hit,ob.matrix_world@p
heights=[]
for px in [214,265,390,490,560,588,601,616]:
    hit,top=cast(blade,(0,Y(px),.25),(0,0,-1));assert hit
    heights.append(top.z)
assert all(a>b+.0015 for a,b in zip(heights,heights[1:])),heights
for side in [-1,1]:
    hit,field=cast(blade,(side*.2,Y(380),.022),(-side,0,0));assert hit
    hit,fuller=cast(blade,(side*.2,Y(380),0),(-side,0,0));assert hit
    assert .0007<abs(field.x)-abs(fuller.x)<.0025,('Missing shallow fuller',list(field),list(fuller))
    hit,grip=cast(hilt,(side*.2,0,0),(-side,0,0));assert hit and .018<abs(grip.x)<.031
hit,p=cast(hilt,(0,Y(10),0),(0,1,0));assert hit and Y(43)<p.y<Y(53),'Pommel end is not recessed'
wraps=[g for g in hilt.vertex_groups if g.name.startswith('Grip_Wrap_')]
assert len(wraps)==5,len(wraps)
atlas=bpy.data.images['Sword_Sand_Atlas_256'];assert atlas.packed_file and tuple(atlas.size)==(256,256)
pixels=list(atlas.pixels[:])
markers={name:tuple(bpy.data.objects[name].matrix_world.translation) for name in ['RightHandGrip','BladeTip','BladeBase','GuardCenter','HolsterAttach']}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'Sword_Sand_Block_V1.glb'))
meshes=[o for o in bpy.data.objects if o.type=='MESH'];assert len(meshes)==2 and not bpy.data.actions
points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
other=[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]
error=max(abs(a-b) for a,b in zip(dims,other));assert error<1e-6
for name,pos in markers.items():assert (bpy.data.objects[name].matrix_world.translation-Vector(pos)).length<1e-6,name
images=[im for im in bpy.data.images if im.type=='IMAGE'];assert len(images)==1
texture_error=max(abs(a-b) for a,b in zip(pixels,images[0].pixels[:]));assert texture_error<1e-6
result={'passed':True,'meshes':2,'materials':2,'triangles':tris,'dimensions_m':dims,
    'roundtrip_error_m':error,'texture_roundtrip_error':texture_error,'stepped_blade_profile':True,
    'symmetric_shallow_fuller':True,'grip_wraps':5,'pommel_recess':True,'marker_roundtrip_exact':True,'actions':0}
(OUT/'validation.json').write_text(json.dumps(result,indent=2))
print('SWORD_ASSET_VALIDATED',json.dumps(result))
