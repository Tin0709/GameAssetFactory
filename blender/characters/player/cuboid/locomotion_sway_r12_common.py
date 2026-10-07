"""Universal gait-driven torso motion for isolated art-review scenes."""
from hold_r11_common import *
R12OUT=BASE/'locomotion_sway_r12_review'
R12OUT.mkdir(exist_ok=True)
CURRENT=json.loads((OUT/'design.json').read_text())
META=json.loads((BASE/'turning_study_r3_review/preview_metadata.json').read_text())
GAITS={'Walk':{'period':16,'twist':3.0,'roll':1.8,'lateral':.006,'bank':4.0,'pitch_rock':1.0,'foreaft':.005},
       'Sprint':{'period':13,'twist':4.0,'roll':2.4,'lateral':.008,'bank':6.0,'pitch_rock':1.4,'foreaft':.008}}
ARM_INSET=.032 # close the 28 mm shoulder gap introduced by the slim mesh

def source_curves(gait):
    action=bpy.data.actions[CURRENT['locomotion']['imported_actions'][gait+'_ReferenceStudy_V2']]
    return {(c.data_path.split('"')[1],c.data_path.rsplit('.',1)[1],c.array_index):c for c in curves(action)}

def native_pose(table,bone,frame):
    loc=Vector((0,0,0));rot=Euler((0,0,0),'XYZ')
    for i in range(3):
        if (bone,'location',i) in table:loc[i]=table[bone,'location',i].evaluate(frame)
        if (bone,'rotation_euler',i) in table:rot[i]=table[bone,'rotation_euler',i].evaluate(frame)
    return loc,rot

def gait_harmonic(gait,table):
    # On this rig positive leg-X points the foot forward (native bone-Y points down).
    period=GAITS[gait]['period'];samples=np.array([native_pose(table,'Leg.R',1+i)[1].x-native_pose(table,'Leg.L',1+i)[1].x for i in range(period)])
    phase=2*np.pi*np.arange(period)/period
    c=float(np.dot(samples,np.cos(phase))*2/period);s=float(np.dot(samples,np.sin(phase))*2/period)
    amplitude=math.hypot(c,s)
    assert amplitude>.1
    return c/amplitude,s/amplitude

def banks(gait):
    rows=META['gaits'][gait]['rows'];values=np.zeros(len(rows));rates=np.zeros(len(rows))
    for case in META['cases']:
        indices=[i for i,r in enumerate(rows) if r['case']==case['name']]
        yaw=np.unwrap([rows[i]['yaw'] for i in indices]);rate=np.gradient(yaw)*24
        kernel=np.exp(-.5*(np.arange(-6,7)/2.0)**2);kernel/=kernel.sum()
        rate=np.convolve(np.pad(rate,(6,6),mode='edge'),kernel,mode='valid')
        n=len(indices)
        for j,i in enumerate(indices):
            ease=min(1,j/5,(n-1-j)/5);ease=max(0,ease);ease=ease*ease*(3-2*ease)
            rates[i]=rate[j];values[i]=-math.radians(GAITS[gait]['bank'])*math.tanh(rate[j]/1.4)*ease
    return values,rates

def new_actor(scene,gait,kind,turning):
    cat='Pistol' if kind=='Unarmed' else kind
    rig,mesh,weapons=clone_r11('R12_'+gait+'_'+kind+('_Turn' if turning else ''),scene,cat)
    rig.name='R12_'+gait+'_'+kind+('_Turn' if turning else '')+'_Rig'
    approved=bpy.data.objects[CURRENT['categories'][cat]['mesh']]
    assert [g.name for g in mesh.vertex_groups]==[g.name for g in approved.vertex_groups]
    mesh.data=approved.data.copy()
    if kind=='Unarmed':
        for ob in weapons:ob.hide_render=True;ob.hide_viewport=True
        weapons=[]
    return rig,mesh,weapons

def base_hold(kind):
    if kind=='Unarmed':return None
    d=CURRENT['categories'][kind];sc=bpy.data.scenes[d['scene']];bpy.context.window.scene=sc;rig=bpy.data.objects[d['rig']]
    sample(rig,sc,bpy.data.actions[d['actions']['Hold']],25)
    return {n:(rig.pose.bones[n].location.copy(),rig.pose.bones[n].rotation_quaternion.copy()) for n in UPPER}

def author_upper(scene,rig,gait,kind,turning,base,target=None):
    cfg=GAITS[gait];table=source_curves(gait);hc,hs=gait_harmonic(gait,table);bank,rate=banks(gait)
    end=len(bank) if turning else cfg['period']+1
    name='R12_'+gait+'_'+kind+('_Turn' if turning else '')+'_Upper'
    action=target or bpy.data.actions.new(name);action.use_fake_user=True
    if target is not None:
        assert action.name.startswith('R12_')
        for fc in curves(action):
            fc.keyframe_points.clear()
            for mod in list(fc.modifiers):fc.modifiers.remove(mod)
    action['scope']='Study only; unchanged lower gait. Same-side shoulder follows leading leg; arms/gun inherit torso.'
    action['gait_period_frames']=cfg['period'];previous={}
    bpy.context.window.scene=scene;assign(rig,action)
    lower=bpy.data.actions[CURRENT['locomotion']['turn_lower' if turning else 'lower_copies'][gait]]
    hip_yaw=next(fc for fc in curves(lower) if fc.data_path=='pose.bones["Hips"].rotation_euler' and fc.array_index==1)
    for k in range((end-1)*2+1):
        frame=1+k/2;phase=2*math.pi*(frame-1)/cfg['period'];drive=hc*math.cos(phase)+hs*math.sin(phase)
        source_frame=1+((frame-1)%cfg['period'])
        for n in UPPER:
            p=rig.pose.bones[n];p.rotation_mode='QUATERNION';p.location=(0,0,0);p.rotation_quaternion=(1,0,0,0);p.scale=(1,1,1)
            if base is not None:p.location=base[n][0];p.rotation_quaternion=base[n][1]
            else:
                source_name=n.replace('UpperArm','Arm')
                if not n.startswith('ForeArm') and n!='WeaponCarrier':
                    loc,rot=native_pose(table,source_name,source_frame);p.location=loc;p.rotation_quaternion=rot.to_quaternion()
        if kind=='Pistol':
            # Only the right arm carries the pistol. Left arm retains native gait swing.
            loc,rot=native_pose(table,'Arm.L',source_frame)
            p=rig.pose.bones['UpperArm.L'];p.location=loc;p.rotation_quaternion=rot.to_quaternion()@Quaternion((0,0,1),math.radians(3))
            p=rig.pose.bones['ForeArm.L'];p.location=(0,0,0);p.rotation_quaternion=(1,0,0,0)
        elif kind in ['Rifle','Shotgun']:
            # Free support shape: one straight cuboid arm, softly swinging below
            # its old support position. The gun remains owned by the right side.
            lag=1.5 if gait=='Walk' else 1.0
            support_phase=phase-2*math.pi*lag/cfg['period']
            drop=math.radians(2+2*math.sin(support_phase))
            drift=math.radians(.75)*math.cos(support_phase)
            p=rig.pose.bones['UpperArm.L'];rest=p.parent.bone.matrix_local.inverted()@p.bone.matrix_local
            down_axis=rest.to_3x3().inverted()@Vector((1,0,0));yaw_axis=rest.to_3x3().inverted()@Vector((0,1,0))
            p.rotation_quaternion=Quaternion(yaw_axis,drift)@Quaternion(down_axis,drop)@base['UpperArm.L'][1]
        for side in ['R','L']:
            p=rig.pose.bones['UpperArm.'+side]
            rest=p.parent.bone.matrix_local.inverted()@p.bone.matrix_local
            p.location+=rest.to_3x3().inverted()@Vector((ARM_INSET if side=='R' else -ARM_INSET,0,0))
        if kind!='Unarmed':
            p=rig.pose.bones['WeaponCarrier'];rest=p.parent.bone.matrix_local.inverted()@p.bone.matrix_local
            p.location+=rest.to_3x3().inverted()@Vector((ARM_INSET,0,0))
        p=rig.pose.bones['Spine']
        pitch=0 if base is not None else native_pose(table,'Spine',source_frame)[1].x
        rock=2*drive*drive-1 # two gentle fore/aft rocks per full left/right stride
        pitch+=math.radians(cfg['pitch_rock'])*rock
        lean=float(np.interp(frame-1,np.arange(len(bank)),bank)) if turning else 0
        # The native hips counter-yaw. Keep those source leg/hip keys untouched,
        # while letting the upper torso visibly follow the same-side leading leg.
        native_hip_yaw=hip_yaw.evaluate(frame if turning else source_frame)
        p.rotation_quaternion=Euler((pitch,math.radians(cfg['twist'])*drive-native_hip_yaw,math.radians(cfg['roll'])*drive+lean),'XYZ').to_quaternion()
        p.location.x-=cfg['lateral']*drive
        p.location.z+=cfg['foreaft']*rock
        if base is not None:p.location.y=base['Spine'][0].y+.0015*math.cos(2*phase)
        else:
            # Replace the old torso yaw/roll, retaining native forward pitch.
            chest=rig.pose.bones['Chest'];pitch_ch=native_pose(table,'Chest',source_frame)[1].x
            chest.rotation_quaternion=Euler((pitch_ch,0,0),'XYZ').to_quaternion()
        for n in UPPER:
            p=rig.pose.bones[n];q=p.rotation_quaternion.copy()
            if n in previous and q.dot(previous[n])<0:q.negate()
            previous[n]=q.copy();p.rotation_quaternion=q
            p.keyframe_insert('rotation_quaternion',frame=frame,group=n);p.keyframe_insert('location',frame=frame,group=n)
    for fc in curves(action):
        for key in fc.keyframe_points:key.interpolation='LINEAR'
        if not turning:fc.modifiers.new('CYCLES')
    return action,{'harmonic_cos':hc,'harmonic_sin':hs,'end_frame':end,'bank_max_deg':float(np.degrees(np.abs(bank).max())) if turning else 0}
