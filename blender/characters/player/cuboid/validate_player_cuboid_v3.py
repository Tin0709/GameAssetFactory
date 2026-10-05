"""Measured dimensional and rigid-pose verification of the final v3 file."""
import bpy,json,math,hashlib
from pathlib import Path
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid')
bpy.ops.wm.open_mainfile(filepath=str(OUT/'player_cuboid_v3.blend'))
p=bpy.data.objects['Player_Cuboid_Base'];r=bpy.data.objects['Player_Cuboid_Rig'];mesh=p.data
parts=json.loads(p['rigid_parts'])
expected={'Head':(.45,.45,.45),'Torso':(.45,.225,.675),'Arm.L':(.225,.225,.675),'Arm.R':(.225,.225,.675),'Leg.L':(.225,.225,.675),'Leg.R':(.225,.225,.675)}
measured={};ranges={}
for name,dims in expected.items():
    verts=[v.co for part in parts if part['part']==name or part['part'].startswith(name+' ') for v in list(mesh.vertices)[part['first_vertex']:part['first_vertex']+8]]
    lo=[min(v[i] for v in verts) for i in range(3)];hi=[max(v[i] for v in verts) for i in range(3)]
    actual=[hi[i]-lo[i] for i in range(3)]
    assert all(abs(a-b)<1e-6 for a,b in zip(actual,dims)),(name,actual)
    measured[name]=[round(a,6) for a in actual];ranges[name]=[round(lo[2],6),round(hi[2],6)]
lo=[min(v.co[i] for v in mesh.vertices) for i in range(3)];hi=[max(v.co[i] for v in mesh.vertices) for i in range(3)]
assert abs(lo[2])<1e-7 and abs(hi[2]-1.8)<1e-6
assert abs(hi[0]-lo[0]-.9)<1e-6
assert all(abs(v.co[i]/.05625-round(v.co[i]/.05625))<2e-6 for v in mesh.vertices for i in range(3))
assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-7 for v in mesh.vertices)
assert all(not face.use_smooth for face in mesh.polygons)
assert len(p.data.materials)==1 and len(bpy.data.actions)==0
img=bpy.data.images['Player_Cuboid_Atlas_64'];assert img.packed_file and tuple(img.size)==(64,64)
assert p.data.materials[0].node_tree.nodes.get('Image Texture').interpolation=='Closest'
rest=[(mesh.vertices[e.vertices[0]].co-mesh.vertices[e.vertices[1]].co).length for e in mesh.edges];error=0
for pose in [{'UpperArm.L':(30,0,-10),'Forearm.L':(60,0,0),'Thigh.R':(-30,0,0),'Shin.R':(60,0,0),'Head':(0,10,0),'Chest':(3,0,4)},
             {'UpperArm.R':(55,0,15),'Forearm.R':(90,0,0),'Thigh.L':(-45,0,0),'Shin.L':(90,0,0),'Spine':(4,0,-4)}]:
    for pb in r.pose.bones:pb.rotation_euler=(0,0,0)
    for name,angles in pose.items():r.pose.bones[name].rotation_euler=[math.radians(v) for v in angles]
    bpy.context.view_layer.update();obj=p.evaluated_get(bpy.context.evaluated_depsgraph_get());dm=obj.to_mesh()
    for edge,length in zip(dm.edges,rest):error=max(error,abs((dm.vertices[edge.vertices[0]].co-dm.vertices[edge.vertices[1]].co).length-length))
    obj.to_mesh_clear()
for pb in r.pose.bones:pb.rotation_euler=(0,0,0)
bpy.context.view_layer.update();assert error<1e-5
report=json.loads((OUT/'asset_report_v3.json').read_text())
assert all(hashlib.sha256((OUT/name).read_bytes()).hexdigest()==digest for name,digest in report['earlier_version_sha256'].items())
report['measured_dimensions_m']=measured;report['measured_z_ranges_m']=ranges;report['measured_total_dimensions_m']=[round(hi[i]-lo[i],6) for i in range(3)]
report['validation']={'saved_file_reopened':True,'dimension_tolerance_m':1e-6,'model_pixel_grid_verified':True,'rigid_pose_checks':2,'maximum_edge_length_change_m':error,'pose_reset':True,'previous_versions_unchanged':True,'atlas_packed':True,'nearest_sampling':True,'no_actions':True}
(OUT/'asset_report_v3.json').write_text(json.dumps(report,indent=2))
scene=bpy.context.scene;scene.camera=bpy.data.objects['V3 Isometric Camera'];scene.render.filepath=str(OUT/'player_cuboid_v3_isometric.png')
bpy.ops.object.select_all(action='DESELECT');p.select_set(True);r.select_set(True);bpy.context.view_layer.objects.active=r
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'player_cuboid_v3.blend'))
result=report
