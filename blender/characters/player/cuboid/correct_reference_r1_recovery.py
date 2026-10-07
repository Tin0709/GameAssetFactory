"""Reference silhouette correction within V1: distinct lower reach / higher rigid recovery."""
import bpy,math
from mathutils import Matrix,Vector,Quaternion
from pathlib import Path
BASE=Path(__file__).resolve().parent
assert Path(bpy.data.filepath)==BASE/'player_locomotion_reference_study.blend'
scene=bpy.data.scenes['R1_Authoring'];bpy.context.window.scene=scene
rig=bpy.data.objects['R1_Study_Rig'];mesh=bpy.data.objects['R1_Study_Mesh']
points={}
for n in ['Head','Chest','Arm.L','Arm.R','Leg.L','Leg.R']:
    gi=mesh.vertex_groups[n].index
    points[n]=[v.co.copy() for v in mesh.data.vertices if any(g.group==gi and g.weight>.999 for g in v.groups)]
src=(BASE/'create_reference_r1.py').read_text();exec(src[src.index('def world_points('):src.index('actions={}')])
def curves(a):return [c for l in a.layers for s in l.strips for b in s.channelbags for c in b.fcurves]
for gait,period in [('Walk',16),('Sprint',13)]:
    poses=[pose(i/64,gait=='Sprint') for i in range(64)];poses.append(poses[0])
    action=bpy.data.actions[gait+'_ReferenceStudy_V1'];rig.animation_data.action=action
    for i,ps in enumerate(poses):
        f=1+period*i/64
        for n in ['Root','Hips','Spine','Chest','Neck','Head','Arm.L','Arm.R','Leg.L','Leg.R']:
            p=rig.pose.bones[n];p.location,p.rotation_euler=ps[n]
            p.keyframe_insert('rotation_euler',frame=f,group=n)
            if n in ['Root','Hips','Leg.L','Leg.R']:p.keyframe_insert('location',frame=f,group=n)
    step=period/64
    for c in curves(action):
        ks=c.keyframe_points;ys=[k.co.y for k in ks]
        for i,k in enumerate(ks):
            j=i%64;slope=(ys[(j+1)%64]-ys[(j-1)%64])/(2*step)
            k.handle_left_type=k.handle_right_type='FREE';k.interpolation='BEZIER'
            k.handle_left=(k.co.x-step/3,k.co.y-slope*step/3);k.handle_right=(k.co.x+step/3,k.co.y+slope*step/3)
        c.update()
    action['recovery']='Rigid leg arc shifted rearward by chosen 10 degrees Walk / 14 degrees Sprint to differentiate lower reach from higher foreshortened recovery; ground clearance recalculated.'
bpy.context.window.scene=bpy.data.scenes['R1_Walk_Sprint_Comparison'];bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,check_existing=False)
