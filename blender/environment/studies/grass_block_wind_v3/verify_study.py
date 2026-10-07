import bpy
import bmesh
import math
import json
from pathlib import Path
from mathutils import Vector

OUT=Path(__file__).resolve().parent
main=bpy.data.scenes['ENV_Grass_Block_Wind_Review']
demo=bpy.data.scenes['ENV_Player_Reaction_Demo']
grass=bpy.data.objects['ENV_Grass_Full_Surface_2D']
dg=bpy.data.objects['DEMO_Grass_Wind_Plus_Player']
block=bpy.data.objects['ENV_GrassDirt_Block_1m']
report={'file':bpy.data.filepath,'checks':{},'geometry':{}}
for obj in (block,grass):
    mesh=obj.data;mesh.calc_loop_triangles()
    bm=bmesh.new();bm.from_mesh(mesh)
    degenerate=sum((mesh.vertices[tri.vertices[1]].co-mesh.vertices[tri.vertices[0]].co).cross(mesh.vertices[tri.vertices[2]].co-mesh.vertices[tri.vertices[0]].co).length<1e-9 for tri in mesh.loop_triangles)
    seen=set();components=0
    for vertex in bm.verts:
        if vertex.index in seen:continue
        components+=1;queue=[vertex]
        while queue:
            v=queue.pop()
            if v.index in seen:continue
            seen.add(v.index)
            queue.extend(e.other_vert(v) for e in v.link_edges)
    report['geometry'][obj.name]={'vertices':len(mesh.vertices),'polygons':len(mesh.polygons),'triangles':len(mesh.loop_triangles),'components':components,'zero_area_triangles':degenerate,'loose_edges':sum(not e.link_faces for e in bm.edges),'boundary_edges':sum(e.is_boundary for e in bm.edges),'scale':list(obj.scale),'rotation':list(obj.rotation_euler),'dimensions':list(obj.dimensions)}
    assert degenerate==0 and not any(not e.link_faces for e in bm.edges)
    assert tuple(obj.scale)==(1,1,1) and tuple(obj.rotation_euler)==(0,0,0)
    if obj==block:assert all(e.is_manifold for e in bm.edges) and components==1
    else:assert components==49 and all(len(e.link_faces) in (1,2) for e in bm.edges)
    bm.free()
assert all(abs(x-1)<1e-7 for x in block.dimensions)
assert len(grass.data.vertices)==392 and len(grass.data.polygons)==147
assert grass['blade_count']==49
assert not grass.data.materials[0].use_backface_culling
assert not grass.modifiers and not dg.modifiers
report['checks']['exact_block_unchanged_and_clean_transforms']=True
report['checks']['49_zero_thickness_segmented_two_sided_leaves']=True

basis=[v.co.copy() for v in grass.data.shape_keys.key_blocks['Basis'].data]
roots=[i for i,co in enumerate(basis) if abs(co.z)<1e-7]
assert len(roots)==98
colors=grass.data.color_attributes['GRASS_BEND_DATA']
assert colors.domain=='POINT'
for blade in range(49):
    start=blade*8
    height=basis[start+6].z
    for j in range(8):
        t=basis[start+j].z/height
        c=colors.data[start+j].color
        assert abs(c[0]-t*t)<1e-6 and abs(c[1]-t)<1e-6
        assert abs(c[2]-height/.70)<1e-6
    assert (basis[start]-basis[start+1]).length>0
rootmap=grass.data.uv_layers['UV_Blade_Root']
for li,loop in enumerate(grass.data.loops):
    start=(loop.vertex_index//8)*8
    root=(basis[start]+basis[start+1])*.5
    uv=rootmap.data[li].uv
    assert abs(uv.x-.5-root.x)<1e-6 and abs(uv.y-.5-root.y)<1e-6
root_centers=[(basis[i*8]+basis[i*8+1])*.5 for i in range(49)]
assert min(v.x for v in root_centers)<-.41 and max(v.x for v in root_centers)>.41
assert min(v.y for v in root_centers)<-.41 and max(v.y for v in root_centers)>.41
report['grass_basis_dimensions_m']=[max(v[i] for v in basis)-min(v[i] for v in basis) for i in range(3)]
heights=[basis[i*8+6].z for i in range(49)]
assert min(heights)>=.479 and max(heights)<=.701 and max(heights)-min(heights)>.19
report['blade_heights_m']={'minimum':min(heights),'maximum':max(heights),'mean':sum(heights)/49}
report['checks']['unequal_blade_heights_around_60_percent_block']=True
report['checks']['full_surface_even_grid_and_gpu_masks_root_uv_valid']=True

def evaluate(obj,scene,frame):
    if bpy.context.window:bpy.context.window.scene=scene
    integer=math.floor(frame);scene.frame_set(integer,subframe=frame-integer)
    bpy.context.view_layer.update()
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh=evaluated.to_mesh();coords=[v.co.copy() for v in mesh.vertices]
    evaluated.to_mesh_clear();return coords
first=evaluate(grass,main,1);last=evaluate(grass,main,97)
wind_seam=max((a-b).length for a,b in zip(first,last))
a=evaluate(grass,main,1.01);b=evaluate(grass,main,.99)
c=evaluate(grass,main,97.01);d=evaluate(grass,main,96.99)
velocity=max((((aa-bb)-(cc-dd))/.02).length for aa,bb,cc,dd in zip(a,b,c,d))
root_error=0;wind_max=0
for frame in range(1,98):
    coords=evaluate(grass,main,frame)
    root_error=max(root_error,max((coords[i]-basis[i]).length for i in roots))
    wind_max=max(wind_max,max((co-rest).length for co,rest in zip(coords,basis)))
assert wind_seam<1e-6 and velocity<1e-4 and root_error<1e-7
assert .01<wind_max<.021
assert all(fc.driver.is_valid for fc in grass.data.shape_keys.animation_data.drivers)
assert all(abs(grass.data.shape_keys.key_blocks[name].value)<1e-7 for name in ('Player_Bend_X','Player_Bend_Y'))
report['wind']={'duration_seconds':4,'frames':[1,96],'fps':24,'seam_position_error_m':wind_seam,'seam_velocity_error_m_per_frame':velocity,'maximum_root_displacement_m':root_error,'maximum_vertex_displacement_m':wind_max}
report['checks']['wind_seam_and_roots_verified_after_reload']=True

far_indices=[]
for blade,root in enumerate(root_centers):
    if abs(root.y+.06)>=.30:far_indices.extend(range(blade*8,blade*8+8))
assert len(far_indices)>0
walk_max=0;run_max=0;demo_root_error=0;additive_error=0;far_player_error=0
keys=dg.data.shape_keys.key_blocks
player_keys=[key for key in keys if key.name.startswith('DEMO_Player_Column_')]
assert len(player_keys)==14
for frame in range(1,194):
    coords=evaluate(dg,demo,frame)
    player_delta=[Vector((0,0,0)) for i in basis]
    expected=[co.copy() for co in basis]
    for key in keys:
        if key.name=='Basis' or abs(key.value)<1e-10:continue
        for i,rest in enumerate(basis):
            delta=(key.data[i].co-rest)*key.value
            expected[i]+=delta
            if key in player_keys:player_delta[i]+=delta
    error=max((a-b).length for a,b in zip(expected,coords))
    additive_error=max(additive_error,error)
    demo_root_error=max(demo_root_error,max((coords[i]-basis[i]).length for i in roots))
    far_player_error=max(far_player_error,max(player_delta[i].length for i in far_indices))
    peak=max(delta.length for delta in player_delta)
    if frame<=104:walk_max=max(walk_max,peak)
    else:run_max=max(run_max,peak)
assert additive_error<1e-6 and demo_root_error<1e-7 and far_player_error<1e-7
assert .03<walk_max<.060 and run_max>walk_max*1.5 and run_max<.11
df=evaluate(dg,demo,1);dl=evaluate(dg,demo,193)
demo_seam=max((a-b).length for a,b in zip(df,dl))
assert demo_seam<1e-6
report['player_demo']={'duration_seconds':8,'frames':[1,192],'walk_peak_displacement_m':walk_max,'run_peak_displacement_m':run_max,'root_displacement_m':demo_root_error,'far_blade_player_displacement_m':far_player_error,'far_blade_count':len(far_indices)//8,'wind_plus_player_additive_error_m':additive_error,'grass_loop_seam_error_m':demo_seam,'method':'Authored, localized column responses; no runtime proximity simulation or Godot code.'}
report['checks']['wind_plus_player_additive_roots_fixed_far_leaves_unaffected']=True
report['checks']['run_stronger_than_walk_and_demo_grass_returns']=True
img=bpy.data.images['ENV_Atlas_64_Nearest']
assert img.packed_file and tuple(img.size)==(64,64)
i=(28*64+28)*4
assert all(abs(a-b)<.008 for a,b in zip(img.pixels[i:i+3],(145/255,190/255,91/255)))
report['checks']['packed_atlas_palette_correct_after_reload']=True
report['all_checks_passed']=all(report['checks'].values())
(OUT/'validation_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('VALIDATION_REPORT '+json.dumps(report))
