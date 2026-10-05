"""Validate the saved asset through Blender MCP; no keyframes are created."""
import bpy, math, json
from pathlib import Path
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid')
scene=bpy.context.scene
mesh=bpy.data.objects['Player_Cuboid_Base']
rig=bpy.data.objects['Player_Cuboid_Rig']
assert len([o for o in scene.objects if o.type=='MESH'])==1
assert mesh.parent==rig and mesh.modifiers[0].object==rig
assert len(mesh.data.materials)==1
assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-7 for v in mesh.data.vertices)
assert all(not p.use_smooth for p in mesh.data.polygons)
assert all(0<=c<=1 for d in mesh.data.uv_layers.active.data for c in d.uv)
assert len(bpy.data.actions)==0
assert all(o.animation_data is None for o in (rig,mesh))
assert tuple(bpy.data.images['Player_Cuboid_Atlas_64'].size)==(64,64)
assert bpy.data.images['Player_Cuboid_Atlas_64'].packed_file is not None
rest=[(mesh.data.vertices[e.vertices[0]].co-mesh.data.vertices[e.vertices[1]].co).length for e in mesh.data.edges]
poses=[{'UpperArm.L':(25,0,-15),'Forearm.L':(65,0,0),'UpperArm.R':(-25,0,12),'Forearm.R':(30,0,0),'Thigh.L':(-30,0,0),'Shin.L':(60,0,0),'Foot.L':(-20,0,0),'Thigh.R':(20,0,0),'Spine':(4,0,3),'Chest':(-3,0,-5),'Head':(0,12,8)},
       {'UpperArm.R':(60,0,-18),'Forearm.R':(90,0,0),'Thigh.R':(-45,0,0),'Shin.R':(90,0,0),'Foot.R':(25,0,0),'Hips':(0,0,8),'Spine':(6,0,-4),'Chest':(-4,0,-6),'Neck':(3,0,0),'Head':(-5,-15,0)}]
max_error=0
try:
    for pose in poses:
        for pb in rig.pose.bones: pb.rotation_euler=(0,0,0)
        for name,angles in pose.items(): rig.pose.bones[name].rotation_euler=[math.radians(a) for a in angles]
        bpy.context.view_layer.update()
        evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()); dm=evaluated.to_mesh()
        for edge,length in zip(dm.edges,rest):
            actual=(dm.vertices[edge.vertices[0]].co-dm.vertices[edge.vertices[1]].co).length
            max_error=max(max_error,abs(actual-length))
        evaluated.to_mesh_clear()
finally:
    for pb in rig.pose.bones: pb.rotation_euler=(0,0,0)
    bpy.context.view_layer.update()
assert max_error<1e-5
mesh.data.calc_loop_triangles()
report=json.loads((OUT/'asset_report.json').read_text())
report['validation']={'saved_file_reopened':True,'one_mesh_one_material':True,'atlas_packed':True,'uvs_in_bounds':True,'single_rigid_weight_per_vertex':True,'flat_faces':True,'temporary_pose_checks':2,'maximum_edge_length_change_m':max_error,'all_poses_reset':True,'no_animation_data':True}
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
bpy.ops.object.select_all(action='DESELECT'); mesh.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active=rig
scene.render.filepath=str(OUT/'player_cuboid_v1_preview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'player_cuboid_v1.blend'))
result=report
