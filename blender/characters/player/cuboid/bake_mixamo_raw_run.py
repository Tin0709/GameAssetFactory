"""Bake the prepared Mixamo run only. Refuses to replace an existing RAW retarget.
Uses the saved preparation JSON; preserves existing data and actions; no GUI.
"""
import bpy, math, json, hashlib, shutil, ast
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion, Euler
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
TEST=BASE/'blocky_character_mixamo_test.blend'
assert Path(bpy.data.filepath)==TEST
scene=bpy.context.scene
# Reuse only pure snapshot/helper definitions, never execute preparation mutations.
tree=ast.parse((BASE/'prepare_mixamo_run.py').read_text(encoding='utf-8-sig'))
needed={'vv','mm','fcurves','action_signature','object_signature','evaluate'}
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in needed],type_ignores=[]),'retarget_helpers','exec'))
prep=json.loads(bpy.data.texts['Mixamo_Retarget_Preparation.json'].as_string())
source=bpy.data.objects['Mixamo_Working'];target=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base'];rawsource=bpy.data.objects['Armature']
assert source.animation_data.action.name=='Running_Mixamo_InPlace'
assert target.animation_data.action.name=='Player_Idle'
assert scene.render.fps/scene.render.fps_base==24
NAME='Player_Run_Mixamo_RAW'
assert bpy.data.actions.get(NAME) is None,'RAW retarget already exists; never overwrite it'
assert not target.animation_data.nla_tracks,'Unexpected NLA; stop rather than alter it'
assert not any(p.constraints for p in target.pose.bones),'Unexpected constraints'
old_frame=scene.frame_current;old_sub=scene.frame_subframe
old_timing=(scene.render.fps,scene.render.fps_base,scene.frame_start,scene.frame_end)
old_action=target.animation_data.action;old_slot=target.animation_data.action_slot
old_pose={p.name:(p.rotation_mode,p.location.copy(),p.rotation_euler.copy(),p.rotation_quaternion.copy(),p.rotation_axis_angle[:],p.scale.copy()) for p in target.pose.bones}
original_objects={o.name:object_signature(o) for o in [target,mesh,source,rawsource]}
original_actions={a.name:action_signature(a) for a in bpy.data.actions}
production_hash=hashlib.sha256((BASE/'player_cuboid_v6.blend').read_bytes()).hexdigest()
corrections=prep['rest_corrections'];names=list(corrections)
assert len(names)==9
assert all(target.pose.bones[n].rotation_mode=='XYZ' for n in names)
start,end=prep['prepared_frame_range'];duration=(end-start)/24
hipname='mixamorig:Hips'
firstsource=evaluate(source,start);hiporigin=firstsource[hipname].translation.copy()
translation_scale=prep['single_frame_validation']['translation_amplitude_scale']
world_inv=target.matrix_world.inverted();world_invq=world_inv.to_quaternion()
root_rest=target.data.bones['Root'].matrix_local.copy()

def solution(frame):
    sm=evaluate(source,frame);matrices={'Root':root_rest.copy()};values={};directions={}
    for dst,c in corrections.items():
        bone=target.data.bones[dst];sn=c['source']
        parent_pose=matrices[bone.parent.name] if bone.parent else Matrix.Identity(4)
        parent_rest=bone.parent.matrix_local if bone.parent else Matrix.Identity(4)
        reference=bone.convert_local_to_pose(Matrix.Identity(4),bone.matrix_local,parent_matrix=parent_pose,parent_matrix_local=parent_rest)
        q=(sm[sn].to_quaternion().normalized()@Quaternion(c['source_rest_world_quaternion']).inverted()@Quaternion(c['virtual_target_reference_world_quaternion'])).normalized()
        desired=(world_invq@q).to_matrix().to_4x4();desired.translation=reference.translation
        if dst=='Hips':desired.translation+=world_inv.to_3x3()@((sm[hipname].translation-hiporigin)*translation_scale)
        basis=bone.convert_local_to_pose(desired,bone.matrix_local,parent_matrix=parent_pose,parent_matrix_local=parent_rest,invert=True)
        # Use exact zero static translations outside Hips to remove numerical residue.
        location=basis.translation.copy() if dst=='Hips' else Vector((0,0,0))
        qb=basis.to_quaternion().normalized()
        rebuilt=qb.to_matrix().to_4x4();rebuilt.translation=location
        matrices[dst]=bone.convert_local_to_pose(rebuilt,bone.matrix_local,parent_matrix=parent_pose,parent_matrix_local=parent_rest)
        values[dst]=(location,qb)
        directions[dst]=(sm[sn].to_3x3()@Vector((0,1,0))).normalized()
    return values,matrices,directions

representatives=[start+(end-start)*f for f in [0,.25,.5,.75,1]]
# 0.1 project frame = 1/240 second. Include original prepared keys and review points.
frames=sorted(set(round(start+i*.1,8) for i in range(int(round((end-start)/.1))+1))|set(round(f,8) for f in representatives)|{round(start,8),round(end,8)})
baked={};previous_eulers={}
for frame in frames:
    values,_,_=solution(frame);baked[frame]={}
    for n,(loc,q) in values.items():
        e=q.to_euler('XYZ',previous_eulers[n]) if n in previous_eulers else q.to_euler('XYZ')
        previous_eulers[n]=e.copy();baked[frame][n]=(loc.copy(),e.copy())
# Preserve source motion internally; remove only sub-micron endpoint numerical residue.
endpoint_residue={n:dict(location_m=(baked[frames[-1]][n][0]-baked[frames[0]][n][0]).length,rotation_degrees=math.degrees(baked[frames[0]][n][1].to_quaternion().rotation_difference(baked[frames[-1]][n][1].to_quaternion()).angle)) for n in names}
assert max(v['location_m'] for v in endpoint_residue.values())<1e-5
assert max(min(v['rotation_degrees'],360-v['rotation_degrees']) for v in endpoint_residue.values())<.1
for n in names:
    assert max(abs(baked[frames[-1]][n][1][i]-baked[frames[0]][n][1][i]) for i in range(3))<math.pi,'Unexpected Euler winding'
    baked[frames[-1]][n]=(baked[frames[0]][n][0].copy(),baked[frames[0]][n][1].copy())
action=bpy.data.actions.new(NAME);action.use_fake_user=True
target.animation_data.action=action
for p in target.pose.bones:p.matrix_basis=Matrix.Identity(4)
for frame in frames:
    for n in names:
        p=target.pose.bones[n];loc,rot=baked[frame][n];p.location=loc;p.rotation_euler=rot;p.scale=(1,1,1)
        p.keyframe_insert(data_path='rotation_euler',frame=frame,group=n)
        if n=='Hips' or frame in (frames[0],frames[-1]):p.keyframe_insert(data_path='location',frame=frame,group=n)
for c in fcurves(action):
    for k in c.keyframe_points:k.interpolation='LINEAR'
    mod=c.modifiers.new('CYCLES');mod.mode_before='REPEAT';mod.mode_after='REPEAT'
    c.update()
assert all(c.data_path.startswith('pose.bones[') and ('rotation_euler' in c.data_path or '.location' in c.data_path) and 'Root' not in c.data_path for c in fcurves(action))
# Record cuboid components from the actual existing vertex groups.
parts={g.name:[v.index for v in mesh.data.vertices if any(w.group==g.index and w.weight>.999 for w in v.groups)] for g in mesh.vertex_groups}
assert len(parts)==6 and all(len(ids)==8 for ids in parts.values())
rest_lengths={(n,i,j):(mesh.matrix_world@(mesh.data.vertices[i].co-mesh.data.vertices[j].co)).length for n,ids in parts.items() for i in ids for j in ids if j>i}

def axes_for(ids,points):
    axes=[];valid=set(ids)
    for e in mesh.data.edges:
        i,j=e.vertices
        if i not in valid or j not in valid:continue
        v=(points[j]-points[i]).normalized()
        if not any(abs(v.dot(a))>.99999 for a in axes):axes.append(v)
    assert len(axes)==3
    return axes

def intersection(a,b,points,axes):
    candidate=axes[a]+axes[b]
    for x in axes[a]:
        for y in axes[b]:
            c=x.cross(y)
            if c.length>1e-6:candidate.append(c.normalized())
    min_overlap=float('inf')
    for axis in candidate:
        pa=[points[i].dot(axis) for i in parts[a]];pb=[points[i].dot(axis) for i in parts[b]]
        overlap=min(max(pa),max(pb))-max(min(pa),min(pb))
        if overlap<=1e-5:return 0.0
        min_overlap=min(min_overlap,overlap)
    return min_overlap

results=[];max_rigid=0;max_scale=0;max_roottravel=0;min_alignment=1;max_bake_error=0
clip_summary={};hips_positions=[];lowest_z=float('inf')
validation_frames=sorted(set(round(start+i*.05,8) for i in range(int(round((end-start)/.05))+1))|set(round(f,8) for f in representatives))
for frame in validation_frames:
    expected,expectedmat,source_dirs=solution(frame)
    ev=target.evaluated_get(bpy.context.evaluated_depsgraph_get())
    actual={p.name:p.matrix.copy() for p in ev.pose.bones}
    root_delta=(target.matrix_world@(actual['Root'].translation-root_rest.translation)).length
    max_roottravel=max(max_roottravel,root_delta)
    align={};angular={}
    for n in names:
        d=(target.matrix_world.to_3x3()@actual[n].to_3x3()@Vector((0,1,0))).normalized()
        align[n]=d.dot(source_dirs[n]);min_alignment=min(min_alignment,align[n])
        aq=actual[n].to_quaternion();eq=expectedmat[n].to_quaternion()
        angle=math.degrees(eq.rotation_difference(aq).angle);angle=min(angle,360-angle)
        angular[n]=angle;max_bake_error=max(max_bake_error,angle)
        max_scale=max(max_scale,max(abs(v-1) for v in ev.pose.bones[n].scale))
    hip_world=target.matrix_world@actual['Hips'].translation;hips_positions.append(hip_world.copy())
    emobj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());em=emobj.to_mesh()
    points=[emobj.matrix_world@v.co for v in em.vertices]
    for (n,i,j),length in rest_lengths.items():max_rigid=max(max_rigid,abs((points[i]-points[j]).length-length))
    local_low=min(p.z for p in points);lowest_z=min(lowest_z,local_low)
    axes={n:axes_for(ids,points) for n,ids in parts.items()};partnames=list(parts);clips=[]
    for i,a in enumerate(partnames):
        for b in partnames[i+1:]:
            depth=intersection(a,b,points,axes)
            if depth:
                pair=a+' / '+b;clips.append(dict(pair=pair,minimum_sat_overlap_m=depth))
                summary=clip_summary.setdefault(pair,dict(sample_count=0,first_frame=frame,last_frame=frame,max_minimum_sat_overlap_m=0))
                summary['sample_count']+=1;summary['last_frame']=frame;summary['max_minimum_sat_overlap_m']=max(summary['max_minimum_sat_overlap_m'],depth)
    if any(abs(frame-f)<1e-7 for f in representatives):results.append(dict(frame=frame,time_seconds=(frame-start)/24,bone_direction_alignment=align,bone_rotation_error_degrees=angular,hips_world=vv(hip_world),root_travel_m=root_delta,min_mesh_z_m=local_low,intersections=clips))
    emobj.to_mesh_clear()
assert max_roottravel<1e-6
assert min_alignment>.999
assert max_bake_error<.25,max_bake_error
assert max_rigid<1e-5
assert max_scale<1e-6
firstpose=evaluate(target,start);lastpose=evaluate(target,end)
loop_angles={n:math.degrees(firstpose[n].to_quaternion().rotation_difference(lastpose[n].to_quaternion()).angle) for n in names}
loop_angles={n:min(a,360-a) for n,a in loop_angles.items()}
loop_hips=lastpose['Hips'].translation-firstpose['Hips'].translation
assert max(loop_angles.values())<.001 and loop_hips.length<1e-6
cycle_checks=[]
for phase in [.25,.5,.75]:
    f=start+(end-start)*phase;inside=evaluate(target,f);outside=evaluate(target,f+(end-start))
    matrix_error=max(abs(inside[n][i][j]-outside[n][i][j]) for n in names for i in range(4) for j in range(4))
    cycle_checks.append(dict(phase=phase,max_matrix_error=matrix_error));assert matrix_error<1e-5
# Restore Idle and all original pose values after temporary validation.
target.animation_data.action=old_action
if old_slot:target.animation_data.action_slot=old_slot
for p in target.pose.bones:
    mode,loc,euler,quat,aa,scale=old_pose[p.name];p.rotation_mode=mode;p.location=loc;p.rotation_euler=euler;p.rotation_quaternion=quat;p.rotation_axis_angle=aa;p.scale=scale
scene.frame_set(old_frame,subframe=old_sub);bpy.context.view_layer.update()
objects_unchanged={o.name:original_objects[o.name]==object_signature(o) for o in [target,mesh,source,rawsource]}
actions_unchanged={n:original_actions[n]==action_signature(bpy.data.actions[n]) for n in original_actions}
assert all(objects_unchanged.values()),objects_unchanged
assert all(actions_unchanged.values()),actions_unchanged
assert old_timing==(scene.render.fps,scene.render.fps_base,scene.frame_start,scene.frame_end)
assert production_hash==hashlib.sha256((BASE/'player_cuboid_v6.blend').read_bytes()).hexdigest()
report=dict(action=NAME,target=target.name,source=source.name,source_action=source.animation_data.action.name,frame_range=[start,end],duration_seconds=duration,fps=24,animated_bones=names,animated_bone_count=len(names),curve_count=len(fcurves(action)),bake_sample_count=len(frames),sample_step_frames=.1,rotation_representation='XYZ Euler, continuity unwrapped; original bone rotation modes preserved',location_channels='Hips motion plus constant zero location for other mapped bones, preventing residual Idle translations',interpolation='LINEAR',cyclic=True,loop_rotation_mismatch_degrees=loop_angles,loop_hips_displacement_m=vv(loop_hips),hips_accumulated_horizontal_travel_m=math.hypot(loop_hips.x,loop_hips.y),root_travel_m=max_roottravel,hips_axis_ranges_m=[max(p[i] for p in hips_positions)-min(p[i] for p in hips_positions) for i in range(3)],max_rotation_error_degrees=max_bake_error,min_bone_direction_alignment=min_alignment,max_rigid_length_error_m=max_rigid,max_scale_error=max_scale,scale_animation_present=False,representative_validation=results,cycle_checks=cycle_checks,intersection_summary=clip_summary,lowest_mesh_z_m=lowest_z,endpoint_numerical_residue_removed=endpoint_residue,original_objects_unchanged=objects_unchanged,original_actions_unchanged=actions_unchanged,production_file_unchanged=True,scene_timing_unchanged=True,target_idle_restored=True,stylized=False,exported=False)
backup=BASE/'blocky_character_mixamo_test_before_raw_retarget.blend'
assert not backup.exists(),'Never overwrite safety backup'
shutil.copy2(TEST,backup)
(BASE/'mixamo_raw_retarget_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
txt=bpy.data.texts.new('Mixamo_RAW_Retarget_Report.json');txt.write(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(TEST),check_existing=False)
print('RAW_RETARGET_SAVED='+json.dumps({k:report[k] for k in ['action','frame_range','duration_seconds','animated_bone_count','root_travel_m','hips_accumulated_horizontal_travel_m','max_rotation_error_degrees','max_rigid_length_error_m','intersection_summary','lowest_mesh_z_m','original_actions_unchanged']}))
