from locomotion_sway_r12_common import *
design=json.loads((R12OUT/'design.json').read_text());baseline=json.loads((R12OUT/'baseline.json').read_text());fail=[];stats={}
for name,value in baseline['actions'].items():
    if digest(bpy.data.actions[name])!=value:fail.append('Source Action changed: '+name)
geo=geometry()
for name,value in baseline['geometry'].items():
    if geo[name]!=value:fail.append('Source mesh changed: '+name)
for name,value in baseline['rigs'].items():
    if json.dumps(bone_signature(bpy.data.objects[name]))!=json.dumps(value):fail.append('Source rest rig changed: '+name)
for key,v in design['scenes'].items():
    gait=key.split('_')[0];turning=key.endswith('_Turn');sc=bpy.data.scenes[v['scene']];bpy.context.window.scene=sc
    lower=bpy.data.actions[v['lower']];period=GAITS[gait]['period'];table=list(curves(lower))
    frames=[v['frame_start']+i/2 for i in range(2*(v['frame_end']-v['frame_start']+1)+1)]
    rows={}
    for kind,actor in v['actors'].items():
        upper=bpy.data.actions[actor['upper']]
        if any(any('"'+n+'"' in fc.data_path for n in LOWER) or fc.data_path.endswith('.scale') for fc in curves(upper)):fail.append(key+kind+' alters lower/scale channels')
        rig=bpy.data.objects[actor['rig']];strips=[st for tr in rig.animation_data.nla_tracks for st in tr.strips]
        if len(strips)!=1 or strips[0].action!=lower or strips[0].scale!=1 or strips[0].repeat!=(1 if turning else 4):fail.append(key+kind+' gait clock mismatch')
        rows[kind]={'lower_channel_error':0,'right_hand_gun_matrix_error':0,'straight_max_deg':0,'head_gap_min_m':99,'left_hand_gun_gap_min_m':99,'support_relative_positions':[],'torso_half_frame_angle_max_deg':0,'leg_lead':[],'shoulder_lead':[],'free_left_arm_x':[],'foreaft':[],'first':None,'last':None,'previous_spine':None,'grip_reference':None}
    for index,frame in enumerate(frames):
        sc.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
        source_frame=frame if turning else 1+((frame-1)%period)
        for kind,actor in v['actors'].items():
            r=bpy.data.objects[actor['rig']];rr=r.evaluated_get(dg);row=rows[kind]
            for fc in table:
                n=fc.data_path.split('"')[1];property_name=fc.data_path.rsplit('.',1)[1]
                expected=fc.evaluate(source_frame);actual=getattr(rr.pose.bones[n],property_name)[fc.array_index]
                row['lower_channel_error']=max(row['lower_channel_error'],abs(expected-actual))
            root_inv=rr.pose.bones['Root'].matrix.inverted()
            # Root-local Z is forward; Root-local Y is vertical on this rig.
            row['leg_lead'].append((root_inv@rr.pose.bones['Leg.R'].tail).z-(root_inv@rr.pose.bones['Leg.L'].tail).z)
            row['shoulder_lead'].append((root_inv@rr.pose.bones['UpperArm.R'].head).z-(root_inv@rr.pose.bones['UpperArm.L'].head).z)
            row['free_left_arm_x'].append(rr.pose.bones['UpperArm.L'].rotation_quaternion.to_euler('XYZ').x)
            row['foreaft'].append(rr.pose.bones['Spine'].location.z)
            q=rr.pose.bones['Spine'].rotation_quaternion.copy()
            if row['previous_spine'] is not None:row['torso_half_frame_angle_max_deg']=max(row['torso_half_frame_angle_max_deg'],math.degrees(row['previous_spine'].rotation_difference(q).angle))
            row['previous_spine']=q
            pose={n:rr.pose.bones[n].matrix_basis.copy() for n in UPPER}
            if row['first'] is None:row['first']=pose
            row['last']=pose
            for side in ['L','R']:
                a=rr.pose.bones['UpperArm.'+side];b=rr.pose.bones['ForeArm.'+side]
                row['straight_max_deg']=max(row['straight_max_deg'],math.degrees((a.tail-a.head).angle(b.tail-b.head)))
            if kind!='Unarmed':
                ws=[bpy.data.objects[n] for n in actor['weapons']];main=next(w for w in ws if '_Base' in w.name)
                grip=rr.matrix_world@rr.pose.bones['ForeArm.R'].matrix;relative=grip.inverted()@main.evaluated_get(dg).matrix_world
                if row['grip_reference'] is None:row['grip_reference']=relative.copy()
                row['right_hand_gun_matrix_error']=max(row['right_hand_gun_matrix_error'],max(abs(relative[i][j]-row['grip_reference'][i][j]) for i in range(4) for j in range(4)))
                support=(rr.matrix_world@rr.pose.bones['ForeArm.L'].matrix).inverted()@main.evaluated_get(dg).matrix_world
                row['support_relative_positions'].append(tuple(support.translation))
                if index%16==0 or index==len(frames)-1:
                    boxes=boxes_for(r,bpy.data.objects[actor['mesh']]);box=boxes['Head'];contact=triangle_box(r,ws,'Head',box)
                    row['head_gap_min_m']=min(row['head_gap_min_m'],contact['gap_lower_m'])
                    if contact['triangles']:fail.append(key+kind+' weapon intersects head')
                    lo,hi=boxes['ForeArm.L'];lo=lo.copy();hi=hi.copy();lo[1]=.1875
                    contact=triangle_box(r,ws,'ForeArm.L',(lo,hi));row['left_hand_gun_gap_min_m']=min(row['left_hand_gun_gap_min_m'],contact['gap_lower_m'])
                    if contact['triangles']:fail.append(key+kind+' left hand touches weapon')
    for kind,row in rows.items():
        row['same_side_foot_shoulder_correlation']=float(np.corrcoef(row.pop('leg_lead'),row.pop('shoulder_lead'))[0,1])
        arm=row.pop('free_left_arm_x');row['left_arm_swing_range_deg']=math.degrees(max(arm)-min(arm))
        foreaft=row.pop('foreaft');row['foreaft_translation_range_m']=max(foreaft)-min(foreaft)
        positions=row.pop('support_relative_positions');row['left_hand_independent_motion_m']=float(np.ptp(np.array(positions),axis=0).max()) if positions else None
        row['loop_error']=None if turning else max(abs(row['first'][n][i][j]-row['last'][n][i][j]) for n in UPPER for i in range(4) for j in range(4))
        for n in ['first','last','previous_spine','grip_reference']:row.pop(n)
        if row['lower_channel_error']>1e-5:fail.append(key+kind+' source foot/hip gait differs')
        if row['same_side_foot_shoulder_correlation']<.85:fail.append(key+kind+' shoulder does not follow same-side leading foot')
        if row['straight_max_deg']>.08 or row['right_hand_gun_matrix_error']>1e-5 or (kind!='Unarmed' and row['head_gap_min_m']<.025):fail.append(key+kind+' pose attachment/clearance failed')
        if row['loop_error'] is not None and row['loop_error']>1e-5:fail.append(key+kind+' loop seam')
        if row['foreaft_translation_range_m']<GAITS[gait]['foreaft']*1.8:fail.append(key+kind+' missing fore/aft rock')
        if kind in ['Pistol','Unarmed'] and row['left_arm_swing_range_deg']<15:fail.append(key+kind+' free arm is static')
        if kind in ['Rifle','Shotgun'] and (row['left_hand_independent_motion_m']<.015 or row['left_hand_gun_gap_min_m']<.015):fail.append(key+kind+' support arm is rigid or touching weapon')
        if row['torso_half_frame_angle_max_deg']>3:fail.append(key+kind+' abrupt torso motion')
    stats[key]=rows
report={'passed':not fail,'failures':fail,'scenes':stats,'source_actions_preserved':len(baseline['actions']),'source_meshes_preserved':len(baseline['geometry']),'source_rest_rigs_preserved':len(baseline['rigs']),'scope':'Study only; visual approval pending; no production migration'}
(R12OUT/'validation.json').write_text(json.dumps(report,indent=2));result=report
