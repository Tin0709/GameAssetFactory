from locomotion_sway_r12_common import *
out=BASE/'weapon_stow_r13_review';d=json.loads((out/'design.json').read_text());baseline=json.loads((out/'baseline.json').read_text());sc=bpy.data.scenes[d['scene']];bpy.context.window.scene=sc
fail=[];stats={}
for n,h in baseline['actions'].items():
    if digest(bpy.data.actions[n])!=h:fail.append('Original Action changed '+n)
geo=geometry()
for n,h in baseline['geometry'].items():
    if geo[n]!=h:fail.append('Original mesh changed '+n)
for n,h in baseline['rigs'].items():
    if json.dumps(bone_signature(bpy.data.objects[n]))!=json.dumps(h):fail.append('Original rest rig changed '+n)
for kind,a in d['actors'].items():
    r=bpy.data.objects[a['rig']];ws=[bpy.data.objects[n] for n in a['weapons']];boxes=boxes_for(r,bpy.data.objects[a['mesh']],.005)
    row={'head_hits':[],'chest_hits':[],'intentional_pistol_hip_overlap_frames':[],'gap_min':99,'bend_max_deg':0,'half_frame_step_deg':0,'max_step_bone_frame':None,'start_error':0,'loop_error':0,'lower_error':0,'grip_error_before_handoff':0,'stowed_matrix_drift':0};prev=None;first=None;grip=None;stowed=None
    act=bpy.data.actions[a['action']]
    if any(any('"'+n+'"' in c.data_path for n in LOWER) or c.data_path.endswith('scale') for c in curves(act)):fail.append(kind+' lower/scale keys')
    for i in range(249):
        f=1+i/2;sc.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
        for n in ['Head','Chest']:
            con=triangle_box(r,ws,n,boxes[n]);row['gap_min']=min(row['gap_min'],con['gap_lower_m'])
            if kind=='Pistol' and n=='Chest' and d.get('pistol_mount',{}).get('half_width_inside_hip') and con['triangles']:
                # Requested waist inset is intentional. Keep the upper torso clear.
                row['intentional_pistol_hip_overlap_frames'].append(f)
                lo,hi=boxes[n];lo=lo.copy();lo[1]=-.08
                con=triangle_box(r,ws,n,(lo,hi))
            if con['triangles']:row[n.lower()+'_hits'].append(f)
        for side in ['L','R']:
            u=r.pose.bones['UpperArm.'+side];fo=r.pose.bones['ForeArm.'+side];row['bend_max_deg']=max(row['bend_max_deg'],math.degrees((u.tail-u.head).angle(fo.tail-fo.head)))
        qs={n:r.pose.bones[n].rotation_quaternion.copy() for n in UPPER};pose={n:r.pose.bones[n].matrix_basis.copy() for n in UPPER}
        if prev:
            for n in UPPER:
                step=math.degrees(prev[n].rotation_difference(qs[n]).angle)
                if step>row['half_frame_step_deg']:row['half_frame_step_deg']=step;row['max_step_bone_frame']=[n,f]
        prev=qs
        row['lower_error']=max(row['lower_error'],max(abs(r.pose.bones[n].matrix_basis[x][y]-(1 if x==y else 0)) for n in LOWER for x in range(4) for y in range(4)))
        main=next(w for w in ws if '_Base' in w.name);gm=main.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world
        if f<=36:
            local=gm.inverted()@(r.matrix_world@r.pose.bones['ForeArm.R'].tail)
            if grip is None:grip=local
            row['grip_error_before_handoff']=max(row['grip_error_before_handoff'],(local-grip).length)
        if 46<=f<=78:
            local=(r.matrix_world@r.pose.bones['Chest'].matrix).inverted()@gm
            if stowed is None:stowed=local
            row['stowed_matrix_drift']=max(row['stowed_matrix_drift'],max(abs(local[x][y]-stowed[x][y]) for x in range(4) for y in range(4)))
            if f==46:
                ch=(r.matrix_world@r.pose.bones['Chest'].matrix).inverted()
                pts=[ch@w.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world@v.co for w in ws for v in w.data.vertices]
                axis=(local.to_3x3()@Vector((0,1,0))).normalized()
                if kind=='Pistol':
                    row['right_hip_inner_surface_x_m']=max(p.x for p in pts);row['barrel_down_y']=axis.y
                    width=max(p.x for p in pts)-min(p.x for p in pts)
                    row['hip_width_embedded_fraction']=(max(p.x for p in pts)+.225)/width
                    if abs(row['hip_width_embedded_fraction']-.5)>.01 or axis.y>-.99:fail.append(kind+' incorrect half-width right-hip inset')
                else:
                    row['back_nearest_surface_z_m']=max(p.z for p in pts)
                    row['back_gap_m']=-.1125-row['back_nearest_surface_z_m']
                    row['horizontal_slope_deg']=math.degrees(math.atan2(abs(axis.y),abs(axis.x)))
                    row['mount_center_chest_y_m']=(min(p.y for p in pts)+max(p.y for p in pts))/2
                    if abs(row['mount_center_chest_y_m']-.05)>.001:fail.append(kind+' mount is not above torso centre')
                    if abs(row['horizontal_slope_deg']-d['back_mount']['slope_degrees'])>.01 or axis.y>=0 or abs(row['back_gap_m']-.015)>.001:fail.append(kind+' incorrect close muzzle-down back mount')
        if f==1:
            first=pose;row['start_error']=max(max((r.pose.bones[n].location-Vector(p['location'])).length,min((r.pose.bones[n].rotation_quaternion-Quaternion(p['rotation_quaternion'])).magnitude,(r.pose.bones[n].rotation_quaternion+Quaternion(p['rotation_quaternion'])).magnitude)) for n,p in a['start'].items())
        if f==125:row['loop_error']=max(abs(first[n][x][y]-pose[n][x][y]) for n in UPPER for x in range(4) for y in range(4))
    if row['head_hits'] or row['chest_hits']:fail.append(kind+' intersects head/chest')
    if row['start_error']>1e-5 or row['loop_error']>1e-5 or row['lower_error']>1e-5 or row['bend_max_deg']>.08:fail.append(kind+' pose continuity/rig invariant')
    if row['half_frame_step_deg']>9:fail.append(kind+' abrupt motion')
    if row['grip_error_before_handoff']>1e-4 or row['stowed_matrix_drift']>1e-5:fail.append(kind+' unstable hand/back attachment')
    stats[kind]=row
report={'passed':not fail,'failures':fail,'actors':stats,'original_actions_preserved':len(baseline['actions']),'original_meshes_preserved':len(baseline['geometry']),'scope':'Study only; visual approval pending'}
(out/'validation.json').write_text(json.dumps(report,indent=2));sc.frame_set(26);result=report
