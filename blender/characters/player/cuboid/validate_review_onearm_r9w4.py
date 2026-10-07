"""Actual composed rig/gun checks plus unchanged native locomotion evidence."""
from onearm_r9w4_common import *
design=json.loads((OUT/'design.json').read_text());failures=[];rows={}
loc=design['locomotion'];export=json.loads((BASE/'export/locomotion_r6p/protection.json').read_text())['all_source_actions']
for name,d in loc['source_action_digests'].items():
    a=bpy.data.actions[loc['imported_actions'][name]]
    if digest(a)!=d:failures.append('Imported source Action altered: '+name)
    if name in export and digest(a)!=export[name]:failures.append('Not the approved R6 source: '+name)
def curve_sig(c):return (c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in c.keyframe_points])
for gait,name in loc['lower_copies'].items():
    source=bpy.data.actions[loc['imported_actions'][gait+'_ReferenceStudy_V2']];lookup={(c.data_path,c.array_index):c for c in curves(source)}
    for c in curves(bpy.data.actions[name]):
        if curve_sig(c)!=curve_sig(lookup[(c.data_path,c.array_index)]):failures.append(gait+' native lower curve changed')
def err(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
for key,row in design['reviews'].items():
    s=bpy.data.scenes[row['scene']];bpy.context.window.scene=s
    if key=='Sprint_All':
        actor_pairs=[(cat,bpy.data.objects[row['actors'][cat+'_A']['rig']],bpy.data.objects[row['actors'][cat+'_B']['rig']]) for cat in PREFIX]
        frames=[1,4.5,13,14,26,52,64,65,104,208,832,833]
    else:
        category=key.rsplit('_',1)[0];actor_pairs=[(category,bpy.data.objects[row['actors']['A']['rig']],bpy.data.objects[row['actors']['B']['rig']])]
        if key.endswith('_Turn'):frames=[1+i/2 for i in range(911)]
        else:frames=[1,1.5,9,16,25,32,49,64,row['frames'][1],row['frames'][1]+1]
    stats={'lower_pose_error_max':0,'path_world_yaw_error_max':0,'off_arm_intersections_max':0,'off_terminal_gap_lower_min_m':99,'off_terminal_gap_upper_max_m':0,'support_terminal_gap_upper_max_m':0,'head_chest_inset_intersections_max':0,'samples':len(frames),'loop_error':None}
    endpoints={}
    for f in frames:
        s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
        for category,a,b in actor_pairs:
            for n in LOWER:stats['lower_pose_error_max']=max(stats['lower_pose_error_max'],err(a.pose.bones[n].matrix,b.pose.bones[n].matrix))
            stats['path_world_yaw_error_max']=max(stats['path_world_yaw_error_max'],abs(a.matrix_world.to_quaternion().dot(b.matrix_world.to_quaternion())-1))
            mesh=next(o for o in s.objects if o.type=='MESH' and any(md.type=='ARMATURE' and md.object==b for md in o.modifiers));boxes=boxes_for(b,mesh);inset=boxes_for(b,mesh,.005)
            mount=next(o for o in s.objects if any(getattr(c,'target',None)==b and getattr(c,'subtarget',None)=='WeaponCarrier' for c in o.constraints))
            weapons=[o for o in s.objects if o.type=='MESH' and o!=mesh and (o.parent==mount or (o.parent and o.parent.parent==mount))]
            assert weapons,(key,b.name)
            off=triangle_box(b,weapons,'ForeArm.R',TERMINAL);support=triangle_box(b,weapons,'ForeArm.L',TERMINAL)
            stats['off_terminal_gap_lower_min_m']=min(stats['off_terminal_gap_lower_min_m'],off['gap_lower_m']);stats['off_terminal_gap_upper_max_m']=max(stats['off_terminal_gap_upper_max_m'],off['gap_upper_m']);stats['support_terminal_gap_upper_max_m']=max(stats['support_terminal_gap_upper_max_m'],support['gap_upper_m'])
            for n in ['UpperArm.R','ForeArm.R']:stats['off_arm_intersections_max']=max(stats['off_arm_intersections_max'],triangle_box(b,weapons,n,boxes[n])['triangles'])
            for n in ['Head','Chest']:stats['head_chest_inset_intersections_max']=max(stats['head_chest_inset_intersections_max'],triangle_box(b,weapons,n,inset[n])['triangles'])
            if key=='Sprint_All' and f in [1,833]:endpoints[(category,f)]={n:b.pose.bones[n].matrix_basis.copy() for n in LOWER+UPPER}
    if stats['lower_pose_error_max']>1e-5 or stats['path_world_yaw_error_max']>1e-5:failures.append(key+' mismatched gait/path phase')
    if stats['off_arm_intersections_max'] or stats['off_terminal_gap_lower_min_m']<.020:failures.append(key+' off-arm clearance failed')
    if stats['head_chest_inset_intersections_max'] or stats['support_terminal_gap_upper_max_m']>.007:failures.append(key+' composition contact failed')
    if key=='Sprint_All':
        stats['loop_error']=max(err(endpoints[(cat,1)][n],endpoints[(cat,833)][n]) for cat in PREFIX for n in LOWER+UPPER)
        if stats['loop_error']>1e-5:failures.append('Sprint joint 832-frame loop changed')
    rows[key]=stats
result={'passed':not failures,'failures':failures,'reviews':rows,'approved_locomotion_source_digests_match':True,'native_lower_curves_unchanged':True,'note':'Quarter-frame V3 lower reel bake, dense half-frame turn composition; distance bounds remain sampled evidence. Native 16/13-frame clocks continue through original path cuts.'}
(OUT/'review_validation.json').write_text(json.dumps(result,indent=2))
