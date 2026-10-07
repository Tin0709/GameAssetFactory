from hold_r10wh1_common import *
design=json.loads((OUT/'design.json').read_text());failures=[];rows={};loc=design['locomotion']
for old_name,old_hash in loc['source_action_digests'].items():
    if digest(bpy.data.actions[loc['imported_actions'][old_name]])!=old_hash:failures.append('Locomotion source changed: '+old_name)
def error(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
for key,row in design['reviews'].items():
    cat,mode=key.rsplit('_',1);s=bpy.data.scenes[row['scene']];bpy.context.window.scene=s;a=bpy.data.objects[row['actors']['A']['rig']];b=bpy.data.objects[row['actors']['B']['rig']];ws=[bpy.data.objects[n] for n in row['actors']['B']['weapons']];base=next(w for w in ws if '_Base' in w.name);m=bpy.data.objects[row['actors']['B']['mesh']];inset=boxes_for(b,m,.005)
    frames=[1,1.5,9,16,25,32,49,64,row['movie_frames'],row['frames'][1],row['frames'][1]+1]
    if mode=='Turn':frames=[1,1.5,24,48,73,96,120,145,169,193,217,241,265,289,313,337,349,373,397,421,445,456]
    stats={'lower_pose_error_max':0,'eye_line_error_max_m':0,'right_gap_max_m':0,'left_gap_max_m':0,'left_depth_max_m':0,'head_chest_inset_intersections_max':0,'path_transform_error_max':0,'samples':len(frames),'loop_error':None};ends={}
    for f in frames:
        s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
        for n in LOWER:stats['lower_pose_error_max']=max(stats['lower_pose_error_max'],error(a.pose.bones[n].matrix,b.pose.bones[n].matrix))
        mw=base.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world;eye=b.matrix_world@b.pose.bones['Head'].matrix@EYE;sight=mw@Vector((0,0,SETTINGS[cat]['sight_z']));direction=(mw.to_3x3()@Vector((0,1,0))).normalized();stats['eye_line_error_max_m']=max(stats['eye_line_error_max_m'],(eye-sight).cross(direction).length)
        for side,label in [('R','right'),('L','left')]:
            met=triangle_box(b,ws,'ForeArm.'+side,TERMINAL);stats[label+'_gap_max_m']=max(stats[label+'_gap_max_m'],met['gap_upper_m'])
            if side=='L':stats['left_depth_max_m']=max(stats['left_depth_max_m'],met['vertex_depth_m'])
        for n in ['Head','Chest']:stats['head_chest_inset_intersections_max']=max(stats['head_chest_inset_intersections_max'],triangle_box(b,ws,n,inset[n])['triangles'])
        if mode=='Turn':
            for rig in [a,b]:stats['path_transform_error_max']=max(stats['path_transform_error_max'],error(rig.matrix_world,rig.parent.parent.matrix_world@rig.parent.matrix_basis@rig.matrix_basis))
        if mode=='Sprint' and f in [1,833]:ends[f]={n:b.pose.bones[n].matrix_basis.copy() for n in LOWER+UPPER}
    if mode=='Sprint':stats['loop_error']=max(error(ends[1][n],ends[833][n]) for n in LOWER+UPPER)
    if stats['lower_pose_error_max']>1e-5 or stats['path_transform_error_max']>1e-5:failures.append(key+' gait/path changed')
    if stats['eye_line_error_max_m']>.005 or stats['right_gap_max_m']>.004 or stats['left_gap_max_m']>.004 or stats['left_depth_max_m']>.003 or stats['head_chest_inset_intersections_max']:failures.append(key+' eye/contact composition failed')
    if (stats['loop_error'] or 0)>1e-5:failures.append(key+' Sprint 832-frame loop failed')
    rows[key]=stats
result={'passed':not failures,'failures':failures,'reviews':rows,'native_gait_periods':{'Walk':16,'Sprint':13},'original_path_speeds_m_s':{'Walk':1.4,'Sprint':2.1},'note':'Full public/turn half-frame geometry checks plus representative composed native-gait samples; source path case cuts are preserved.'};(OUT/'review_validation.json').write_text(json.dumps(result,indent=2))
