"""Prepare a Mixamo action and validate one target pose; never bake target animation.
Run: blender --background blocky_character_mixamo_test.blend --python prepare_mixamo_run.py
"""
import bpy, math, json, hashlib, shutil
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
TEST=BASE/'blocky_character_mixamo_test.blend'
REPORT=BASE/'mixamo_run_preparation_report.json'
assert Path(bpy.data.filepath)==TEST
scene=bpy.context.scene
assert scene.render.fps/scene.render.fps_base==24
src=bpy.data.objects['Armature']; target=bpy.data.objects['Player_Cuboid_Rig']; mesh=bpy.data.objects['Player_Cuboid_Base']
original=src.animation_data.action
assert original.name=='Armature|mixamo.com|Layer0'
assert target.animation_data.action.name=='Player_Idle'
for name in ['Running_Mixamo_RAW','Running_Mixamo_InPlace']:
    assert bpy.data.actions.get(name) is None, 'Already prepared; do not duplicate or overwrite: '+name
assert bpy.data.objects.get('Mixamo_Working') is None
old_frame=scene.frame_current;old_sub=scene.frame_subframe
old_timing=(scene.render.fps,scene.render.fps_base,scene.frame_start,scene.frame_end)
production_hash=hashlib.sha256((BASE/'player_cuboid_v6.blend').read_bytes()).hexdigest()

def vv(v):return [float(x) for x in v]
def mm(m):return [vv(r) for r in m]
def fcurves(action):
    out=[]
    if hasattr(action,'fcurves'):out.extend(action.fcurves)
    for l in action.layers:
        for s in l.strips:
            for bag in getattr(s,'channelbags',[]):out.extend(bag.fcurves)
    return out

def action_signature(a):
    return dict(name=a.name, range=vv(a.frame_range), curves=[dict(path=c.data_path,index=c.array_index,extrapolation=c.extrapolation,keys=[(vv(k.co),vv(k.handle_left),vv(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points],modifiers=[m.type for m in c.modifiers]) for c in fcurves(a)])
def object_signature(o):
    d=dict(name=o.name,transform=mm(o.matrix_basis),parent=o.parent.name if o.parent else None,parent_inverse=mm(o.matrix_parent_inverse),action=o.animation_data.action.name if o.animation_data and o.animation_data.action else None)
    if o.type=='ARMATURE':d.update(data=o.data.name,bones=[(b.name,b.parent.name if b.parent else None,mm(b.matrix_local),vv(b.head_local),vv(b.tail_local),b.use_deform,b.use_connect) for b in o.data.bones],pose=[(p.name,p.rotation_mode,mm(p.matrix_basis),[(c.name,c.type) for c in p.constraints]) for p in o.pose.bones],pose_position=o.data.pose_position)
    else:d.update(vertices=[(vv(v.co),[(g.group,g.weight) for g in v.groups]) for v in o.data.vertices],edges=[list(e.vertices) for e in o.data.edges],faces=[(list(p.vertices),p.material_index,p.use_smooth) for p in o.data.polygons],uv=[(l.name,[vv(x.uv) for x in l.data]) for l in o.data.uv_layers],groups=[g.name for g in o.vertex_groups],materials=[m.name for m in o.data.materials],modifiers=[(m.name,m.type,getattr(getattr(m,'object',None),'name',None)) for m in o.modifiers])
    return d
old_objects={o.name:object_signature(o) for o in [src,target,mesh]}
old_actions={a.name:action_signature(a) for a in bpy.data.actions}
raw=original.copy();raw.name='Running_Mixamo_RAW';raw.use_fake_user=True
working=original.copy();working.name='Running_Mixamo_InPlace';working.use_fake_user=True
work=src.copy();work.data=src.data.copy();work.name='Mixamo_Working';work.data.name='Mixamo_Working_Data';bpy.context.collection.objects.link(work)
work.animation_data_create();work.animation_data.action=working
# Blender 5 layered-action slots must refer to the copied action's slot.
if working.slots:work.animation_data.action_slot=working.slots[0]
start,end=map(float,original.frame_range);source_fps=30.0;dest_fps=24.0;ratio=dest_fps/source_fps
new_start=start;new_end=new_start+(end-start)*ratio

def evaluate(o,frame):
    scene.frame_set(math.floor(frame),subframe=frame-math.floor(frame))
    bpy.context.view_layer.update()
    ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return {p.name:(o.matrix_world@ev.pose.bones[p.name].matrix).copy() for p in o.pose.bones}
hips='mixamorig:Hips';forward=Vector((0,-1,0))
p0=evaluate(src,start)[hips].translation;p1=evaluate(src,end)[hips].translation
travel=(p1-p0).dot(forward)
# Pose-bone location channels live in the bone rest basis, then object space.
channel_to_world=(src.matrix_world@src.data.bones[hips].matrix_local).to_3x3()
channel_drift=channel_to_world.inverted()@(forward*travel)
path='pose.bones["'+hips+'"].location'
hipcurves={c.array_index:c for c in fcurves(working) if c.data_path==path}
assert set(hipcurves)=={0,1,2}
# Subtract the linear forward trend from keys AND tangents, retaining cyclic residual.
for axis,c in hipcurves.items():
    slope=channel_drift[axis]/(end-start)
    if abs(slope)<1e-12:continue
    for k in c.keyframe_points:
        co=k.co.copy();left=k.handle_left.copy();right=k.handle_right.copy()
        k.handle_left_type='FREE';k.handle_right_type='FREE'
        k.co=(co.x,co.y-slope*(co.x-start))
        k.handle_left=(left.x,left.y-slope*(left.x-start))
        k.handle_right=(right.x,right.y-slope*(right.x-start))
    c.update()
# Exact affine time conversion, including Bezier handle times. Subframes preserve duration.
for c in fcurves(working):
    for k in c.keyframe_points:
        co=k.co.copy();left=k.handle_left.copy();right=k.handle_right.copy()
        k.co.x=new_start+(co.x-start)*ratio
        k.handle_left.x=new_start+(left.x-start)*ratio
        k.handle_right.x=new_start+(right.x-start)*ratio
    c.update()
report=dict(raw_original_action=original.name,preserved_raw_action=raw.name,working_action=working.name,raw_armature=src.name,working_armature=work.name,source_fps=source_fps,scene_fps=24,source_frame_range=[start,end],prepared_frame_range=[new_start,new_end],source_duration_seconds=(end-start)/source_fps,prepared_duration_seconds=(new_end-new_start)/dest_fps,forward_axis_world=vv(forward),removed_forward_travel_m=travel,removed_hips_channel_drift=vv(channel_drift),method='Linear forward drift subtraction; exact affine key/handle retiming; no integer-frame rounding')
# Verify equivalent times across the entire clip, not just the chosen target pose.
source_samples=[];prepared_samples=[];max_rot=0;max_location_error=0
for i in range(77):
    sf=start+(end-start)*i/76;wf=new_start+(sf-start)*ratio
    sm=evaluate(src,sf);wm=evaluate(work,wf)
    source_samples.append(vv(sm[hips].translation));prepared_samples.append(vv(wm[hips].translation))
    expected=sm[hips].translation-forward*travel*(sf-start)/(end-start)
    max_location_error=max(max_location_error,(wm[hips].translation-expected).length)
    for n in sm:
        # Numerical comparison of rotation matrices avoids quaternion acos amplification.
        max_rot=max(max_rot,max(abs(sm[n].to_3x3()[r][c]-wm[n].to_3x3()[r][c]) for r in range(3) for c in range(3)))
assert max_location_error<1e-4, max_location_error
assert max_rot<1e-4, max_rot
first=evaluate(work,new_start);last=evaluate(work,new_end)
loop_angles={n:math.degrees(first[n].to_quaternion().rotation_difference(last[n].to_quaternion()).angle) for n in first}
loop_angles={n:min(a,360-a) for n,a in loop_angles.items()}
loop_hip=(last[hips].translation-first[hips].translation)
report['in_place_validation']=dict(endpoint_hips_displacement_m=vv(loop_hip),forward_position_range_m=max(Vector(p).dot(forward) for p in prepared_samples)-min(Vector(p).dot(forward) for p in prepared_samples),lateral_range_m=max(p[0] for p in prepared_samples)-min(p[0] for p in prepared_samples),vertical_range_m=max(p[2] for p in prepared_samples)-min(p[2] for p in prepared_samples),max_expected_location_error_m=max_location_error,max_rotation_matrix_error=max_rot)
report['loop']=dict(max_endpoint_rotation_difference_degrees=max(loop_angles.values()),hips_endpoint_distance_m=loop_hip.length,clean_pose_loop=max(loop_angles.values())<0.1 and loop_hip.length<1e-4,subframe_endpoint=new_end)
assert abs(loop_hip.dot(forward))<1e-4
# Virtual anatomical reference only: source T arms must correspond to target virtual T arms.
# Mapping source T directly to the actual arms-down rest would yield a 90-degree Run error.
# No edit bones or rest matrices are ever changed.
mapping={'Hips':'Hips','Spine':'Spine','Spine2':'Chest','Neck':'Neck','Head':'Head','LeftArm':'Arm.L','RightArm':'Arm.R','LeftUpLeg':'Leg.L','RightUpLeg':'Leg.R'}
corrections={}
for short,dst in mapping.items():
    sn='mixamorig:'+short;sb=work.data.bones[sn];tb=target.data.bones[dst]
    sr=(work.matrix_world@sb.matrix_local).to_quaternion().normalized()
    tr=(target.matrix_world@tb.matrix_local).to_quaternion().normalized()
    sd=(work.matrix_world.to_3x3()@(sb.tail_local-sb.head_local)).normalized()
    td=(target.matrix_world.to_3x3()@(tb.tail_local-tb.head_local)).normalized()
    anatomical=td.rotation_difference(sd)
    virtual=(anatomical@tr).normalized()
    corrections[dst]=dict(source=sn,target=dst,source_rest_world_quaternion=vv(sr),target_actual_rest_world_quaternion=vv(tr),virtual_target_reference_world_quaternion=vv(virtual),target_virtual_reference_from_actual_rest_quaternion=vv(anatomical),target_virtual_reference_from_actual_rest_degrees=math.degrees(anatomical.angle),source_rest_to_virtual_target_basis_quaternion=vv(sr.inverted()@virtual),source_rest_to_actual_target_basis_quaternion=vv(sr.inverted()@tr))
report['mapping']=dict(mapping,Chest_note='Spine1 and Spine2 are collapsed into Chest via source Spine2 cumulative pose delta relative to mapped Spine.')
report['rest_corrections']=corrections
report['rotation_formula']='Qdesired_world = (Qsource_pose_world @ inverse(Qsource_rest_world)) @ Qtarget_virtual_reference_world. Convert desired rotation through actual target rest and evaluated parent matrices into target matrix_basis. Virtual arm reference is a pose-space calibration, never a rest-pose edit.'
# A representative quarter-cycle: raw frame 6 -> prepared frame 5.
validation_source_frame=6.0;vf=new_start+(validation_source_frame-start)*ratio
pose=evaluate(work,vf)
idle=target.animation_data.action;idle_slot=target.animation_data.action_slot
stored_pose={p.name:(p.rotation_mode,p.location.copy(),p.rotation_euler.copy(),p.rotation_quaternion.copy(),p.rotation_axis_angle[:],p.scale.copy()) for p in target.pose.bones}
stored_nla=[(t,t.mute) for t in target.animation_data.nla_tracks]
target.animation_data.action=None
for track,_ in stored_nla:track.mute=True
for p in target.pose.bones:p.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
firsthip=first[hips].translation.copy()
# Scale only translation amplitudes by reference skeleton height; rotations remain scale-free.
source_height=max((work.matrix_world@b.tail_local).z for b in work.data.bones)-min((work.matrix_world@b.head_local).z for b in work.data.bones)
target_height=max((target.matrix_world@b.tail_local).z for b in target.data.bones)-min((target.matrix_world@b.head_local).z for b in target.data.bones)
translation_scale=target_height/source_height
hipdelta=(pose[hips].translation-firsthip)*translation_scale
validation={};direction_dots={}
for dst,c in corrections.items():
    pb=target.pose.bones[dst];b=pb.bone;sn=c['source']
    qdesired=(pose[sn].to_quaternion().normalized()@Quaternion(c['source_rest_world_quaternion']).inverted()@Quaternion(c['virtual_target_reference_world_quaternion'])).normalized()
    # Parent-aware conversion from actual rest into matrix_basis; retain target bone offsets.
    parentmatrix=pb.parent.matrix.copy() if pb.parent else Matrix.Identity(4)
    parentrest=pb.parent.bone.matrix_local if pb.parent else Matrix.Identity(4)
    zero_pose=b.convert_local_to_pose(Matrix.Identity(4),b.matrix_local,parent_matrix=parentmatrix,parent_matrix_local=parentrest)
    desired=(target.matrix_world.inverted().to_quaternion()@qdesired).to_matrix().to_4x4()
    desired.translation=zero_pose.translation
    if dst=='Hips':desired.translation+=target.matrix_world.inverted().to_3x3()@hipdelta
    basis=b.convert_local_to_pose(desired,b.matrix_local,parent_matrix=parentmatrix,parent_matrix_local=parentrest,invert=True)
    pb.rotation_mode='QUATERNION';pb.matrix_basis=basis
    bpy.context.view_layer.update()
    tdir=(target.matrix_world.to_3x3()@(pb.tail-pb.head)).normalized()
    sdir=(pose[sn].to_3x3()@Vector((0,1,0))).normalized()
    direction_dots[dst]=tdir.dot(sdir)
    validation[dst]=dict(basis_rotation_quaternion=vv(pb.rotation_quaternion),basis_location=vv(pb.location),bone_direction_world=vv(tdir),source_direction_world=vv(sdir),direction_alignment_dot=tdir.dot(sdir))
root_world=target.matrix_world@target.pose.bones['Root'].matrix
root_reference=target.matrix_world@target.data.bones['Root'].matrix_local
root_translation=(root_world.translation-root_reference.translation).length
root_angle=math.degrees(root_reference.to_quaternion().rotation_difference(root_world.to_quaternion()).angle)
# Rigid parts must keep all pairwise vertex distances under the evaluated pose.
ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());em=ev.to_mesh();max_rigid_error=0
for base in range(0,len(mesh.data.vertices),8):
    for i in range(base,base+8):
        for j in range(i+1,base+8):
            a=(mesh.matrix_world@(mesh.data.vertices[i].co-mesh.data.vertices[j].co)).length
            b=(ev.matrix_world@(em.vertices[i].co-em.vertices[j].co)).length
            max_rigid_error=max(max_rigid_error,abs(a-b))
ev.to_mesh_clear()
report['single_frame_validation']=dict(source_frame=validation_source_frame,prepared_frame=vf,bones=validation,root_world_translation_m=root_translation,root_world_rotation_degrees=root_angle,hips_world_delta_m=vv(hipdelta),translation_amplitude_scale=translation_scale,max_rigid_pairwise_distance_error_m=max_rigid_error,arm_axes_correct=min(direction_dots[n] for n in ['Arm.L','Arm.R'])>0.999,all_mapped_axes_correct=min(direction_dots.values())>0.999,passed=min(direction_dots.values())>0.999 and root_translation<1e-6 and root_angle<0.001 and max_rigid_error<1e-5)
# Restore target entirely; validation is data only, not a retained/baked target pose.
target.animation_data.action=idle
if idle_slot:target.animation_data.action_slot=idle_slot
for track,mute in stored_nla:track.mute=mute
for p in target.pose.bones:
    mode,loc,euler,quat,axisangle,scale=stored_pose[p.name];p.rotation_mode=mode;p.location=loc;p.rotation_euler=euler;p.rotation_quaternion=quat;p.rotation_axis_angle=axisangle;p.scale=scale
scene.frame_set(old_frame,subframe=old_sub);bpy.context.view_layer.update()
report['original_objects_unchanged']={o.name:old_objects[o.name]==object_signature(o) for o in [src,target,mesh]}
report['original_actions_unchanged']={name:old_actions[name]==action_signature(bpy.data.actions[name]) for name in old_actions}
report['scene_timing_unchanged']=old_timing==(scene.render.fps,scene.render.fps_base,scene.frame_start,scene.frame_end)
report['production_hash_unchanged']=production_hash==hashlib.sha256((BASE/'player_cuboid_v6.blend').read_bytes()).hexdigest()
report['target_idle_restored']=target.animation_data.action.name=='Player_Idle'
report['full_retarget_baked']=False
assert all(report['original_objects_unchanged'].values()), report['original_objects_unchanged']
assert all(report['original_actions_unchanged'].values()), report['original_actions_unchanged']
assert report['single_frame_validation']['passed'],report['single_frame_validation']
assert report['scene_timing_unchanged'] and report['production_hash_unchanged']
# Persist configuration as JSON in a Blender Text block; no rig constraints or drivers.
text=bpy.data.texts.new('Mixamo_Retarget_Preparation.json');text.write(json.dumps(report,indent=2))
REPORT.write_text(json.dumps(report,indent=2),encoding='utf-8')
backup=BASE/'blocky_character_mixamo_test_before_preparation.blend'
assert not backup.exists(), 'Do not overwrite pre-preparation backup'
shutil.copy2(TEST,backup)
bpy.ops.wm.save_as_mainfile(filepath=str(TEST),check_existing=False)
print('PREPARATION_SUCCESS='+json.dumps({k:report[k] for k in ['preserved_raw_action','working_action','prepared_frame_range','source_duration_seconds','prepared_duration_seconds','in_place_validation','loop','original_objects_unchanged','original_actions_unchanged','scene_timing_unchanged']}))


