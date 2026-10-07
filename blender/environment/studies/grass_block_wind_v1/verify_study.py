"""Read-only fresh-file geometry, wind, dependency, and loop validation."""
import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Vector

OUT=Path(__file__).resolve().parent
assert Path(bpy.data.filepath).resolve()==(OUT/'grass_block_wind_v1.blend').resolve()
scene=bpy.context.scene
block=bpy.data.objects['ENV_GrassDirt_Block_1m']
grass=bpy.data.objects['ENV_Grass_Tuft_Hero']
wind=bpy.data.objects['ENV_Wind_Global']
report={'file':bpy.data.filepath,'blender_version':bpy.app.version_string,'objects':{},'checks':{}}
for obj in (block,grass):
    mesh=obj.data
    mesh.calc_loop_triangles()
    bm=bmesh.new(); bm.from_mesh(mesh)
    loose=sum(len(e.link_faces)==0 for e in bm.edges)
    nonmanifold=sum(not e.is_manifold for e in bm.edges)
    zeroarea=sum(f.calc_area()<1e-10 for f in bm.faces)
    seen=set(); components=0
    for v in bm.verts:
        if v.index in seen: continue
        components+=1; stack=[v]
        while stack:
            current=stack.pop()
            if current.index in seen: continue
            seen.add(current.index)
            stack.extend(e.other_vert(current) for e in current.link_edges)
    report['objects'][obj.name]={'vertices':len(mesh.vertices),'polygons':len(mesh.polygons),'triangles':len(mesh.loop_triangles),'dimensions':list(obj.dimensions),'connected_components':components,'nonmanifold_edges':nonmanifold,'loose_edges':loose,'zero_area_faces':zeroarea,'signed_volume_m3':bm.calc_volume(signed=True),'location':list(obj.location),'scale':list(obj.scale),'rotation':list(obj.rotation_euler),'material_count':len(mesh.materials),'modifier_count':len(obj.modifiers)}
    assert nonmanifold==0 and loose==0 and zeroarea==0,(obj.name,report['objects'][obj.name])
    assert bm.calc_volume(signed=True)>0
    assert len(mesh.materials)==1 and len(obj.modifiers)==0
    assert tuple(obj.scale)==(1,1,1) and tuple(obj.rotation_euler)==(0,0,0)
    bm.free()
assert all(abs(c-1)<1e-7 for c in block.dimensions)
assert report['objects'][block.name]['connected_components']==1
assert report['objects'][grass.name]['connected_components']==14
assert tuple(grass.location)==(0,0,1)
report['checks']['geometry_and_exact_block_dimensions']=True
report['checks']['clean_applied_rotation_scale']=True

basis=[v.co.copy() for v in grass.data.shape_keys.key_blocks['Basis'].data]
roots=[i for i,co in enumerate(basis) if abs(co.z)<1e-7]
assert len(roots)==56
def coordinates(frame):
    whole=math.floor(frame)
    scene.frame_set(whole,subframe=frame-whole)
    bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get()
    evaluated=grass.evaluated_get(deps)
    mesh=evaluated.to_mesh()
    coords=[v.co.copy() for v in mesh.vertices]
    evaluated.to_mesh_clear()
    return coords
first=coordinates(1)
last=coordinates(97)
seam=max((a-b).length for a,b in zip(first,last))
before=coordinates(.99); after=coordinates(1.01)
before2=coordinates(96.99); after2=coordinates(97.01)
velocity=max((((a-b)/.02)-((c-d)/.02)).length for a,b,c,d in zip(after,before,after2,before2))
root_error=0; max_move=0; min_z=1e3
for frame in range(1,98):
    coords=coordinates(frame)
    root_error=max(root_error,max((coords[i]-basis[i]).length for i in roots))
    max_move=max(max_move,max((a-b).length for a,b in zip(coords,basis)))
    min_z=min(min_z,min(v.z for v in coords))
assert seam<1e-6,seam
assert velocity<1e-4,velocity
assert root_error<1e-7,root_error
assert .01<max_move<.021,max_move
assert min_z>=-1e-7
assert scene.frame_start==1 and scene.frame_end==96 and scene.render.fps==24
drivers=grass.data.shape_keys.animation_data.drivers
assert len(drivers)==4 and all(fc.driver.is_valid for fc in drivers)
assert wind.animation_data.drivers[0].driver.is_valid
report['wind']={'duration_seconds':4,'fps':24,'playback_frames':[1,96],'duplicate_seam_frame':97,'root_vertex_count':len(roots),'maximum_root_displacement_m':root_error,'maximum_vertex_displacement_m':max_move,'seam_position_error_m':seam,'seam_velocity_error_m_per_frame':velocity,'valid_shape_key_drivers':len(drivers),'shared_phase_expression':wind.animation_data.drivers[0].driver.expression}
report['checks']['roots_planted_all_97_samples']=True
report['checks']['seam_position_and_velocity_match']=True
report['checks']['drivers_valid_and_motion_subtle']=True
minimum=[min(v[a] for v in basis) for a in range(3)]
maximum=[max(v[a] for v in basis) for a in range(3)]
report['grass_basis_dimensions_m']=[b-a for a,b in zip(minimum,maximum)]
image=bpy.data.images['ENV_Atlas_64_Nearest']
assert tuple(image.size)==(64,64) and image.packed_file
index=(28*64+28)*4
pixel=list(image.pixels[index:index+3])
expected=[145/255,190/255,91/255]
assert all(abs(a-b)<.008 for a,b in zip(pixel,expected)),('packed atlas color',pixel,expected)
report['packed_atlas_base_top_srgb']=pixel
report['checks']['packed_atlas_palette_survives_reload']=True
material=grass.data.materials[0]
assert material==block.data.materials[0]
nodes=[n for n in material.node_tree.nodes if n.type=='TEX_IMAGE']
assert len(nodes)==1 and nodes[0].interpolation=='Closest'
missing=[]
for image in bpy.data.images:
    if image.source=='FILE' and not image.packed_file:
        path=bpy.path.abspath(image.filepath)
        if not Path(path).exists(): missing.append(path)
assert not missing
report['checks']['one_shared_opaque_material_packed_nearest_64_atlas']=True
report['checks']['no_missing_image_dependencies']=True
report['all_checks_passed']=all(report['checks'].values())
scene.frame_set(1)
(OUT/'validation_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('VALIDATION_REPORT '+json.dumps(report))
