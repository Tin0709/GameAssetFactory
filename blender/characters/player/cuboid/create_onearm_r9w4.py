"""Bake the approved one-arm hold language to nine upper-only study Actions."""
from onearm_r9w4_common import *
assert Path(bpy.data.filepath).name=='player_weapon_onearm_r9w4_study.blend'
assert not bpy.data.actions.get('LongGunHold_OneArmStudy_V1')
design=json.loads((OUT/'design.json').read_text())
sources={'Hold':'LongGunReady_LivingRef_V2','Move':'LongGunReady_Move_V2','AimAround':'LongGunAimAround_LeftRight_V3'}
def key_upper(r,a,f,previous):
    assign(r,a)
    for n in UPPER:
        p=r.pose.bones[n];q=p.rotation_quaternion.copy()
        if n in previous and q.dot(previous[n])<0:q.negate()
        p.rotation_quaternion=q;previous[n]=q.copy();p.keyframe_insert('rotation_quaternion',frame=f,group=n)
        if n=='WeaponCarrier':p.keyframe_insert('location',frame=f,group=n)
def finish(a,N):
    # Existing periodic quaternion spline convention, without changing duration.
    periodic(a,N)
def body(r,basepose,phase,drive,follow,breath):
    assign(r,None)
    for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4)
    for n in UPPER:r.pose.bones[n].matrix_basis=basepose[n].copy()
    for n,angles in [('Spine',(.55*breath,2.5*drive,.35*math.sin(phase))),('Chest',(.8*breath,7*drive,-.7*drive)),('Neck',(.25*breath,2*drive,0))]:
        r.pose.bones[n].matrix_basis=basepose[n]@Euler(tuple(math.radians(x) for x in angles),'XYZ').to_matrix().to_4x4()
    # Rebase the old side-looking head bias to the new forward weapon line.
    r.pose.bones['Head'].rotation_quaternion=Euler(tuple(math.radians(x) for x in (.6*breath,6*drive+1.5*(drive-follow),-.35*drive)),'XYZ').to_quaternion()
    bpy.context.view_layer.update()
for category,data in design['categories'].items():
    s=bpy.data.scenes[data['scene']];bpy.context.window.scene=s;r=bpy.data.objects[data['rig']];ws=[bpy.data.objects[n] for n in data['weapons']];socket=Matrix(data['socket'])
    sample(r,s,bpy.data.actions[sources['Hold']],1);basepose={n:r.pose.bones[n].matrix_basis.copy() for n in UPPER}
    data['actions']={};data['records']={};data['baseline_actions']={}
    for mode,N in PERIOD.items():
        source=bpy.data.actions[sources[mode]];a=source.copy();a.name=PREFIX[category]+mode+'_OneArmStudy_V1';a.use_fake_user=True
        a['scope']='R9-W4 upper-only FK study; left carries, right hovers; no runtime migration'
        a['primary_support_arm']='L';a['off_arm']='R';a['hover_clearance_target_m']=.030
        previous={};rows=[];first=None
        for i in range(N+1):
            f=i+1;phase=2*math.pi*i/N
            strength=1 if mode=='AimAround' else (.12 if mode=='Move' else .08)
            drive=strength*math.sin(phase);follow=strength*math.sin(phase-2*math.pi*(.125*24)/N);breath=math.sin(phase*(3 if mode=='AimAround' else 1))
            body(r,basepose,phase,drive,follow,breath)
            fitted=configure_pose(r,ws,socket,category,drive,follow,breath)
            pose={n:r.pose.bones[n].matrix_basis.copy() for n in UPPER}
            if i==0:first=pose
            if i==N:
                for n,m in first.items():r.pose.bones[n].matrix_basis=m.copy()
                bpy.context.view_layer.update()
            key_upper(r,a,f,previous)
            rows.append({'frame':f,'drive':drive,'follow':follow,'breath':breath,'fit_config':fitted['config']})
        finish(a,N);data['actions'][mode]=a.name;data['records'][mode]=rows
        if category=='Rifle':data['baseline_actions'][mode]=source.name
        else:
            # No prior pistol/shotgun living RigV2 Action exists. Clearly named
            # comparison adapters reuse the preceding compact hold philosophy.
            a0=source.copy();a0.name='PREVIEW_ONLY_R9W4_COMPACT_'+category+'_'+mode;a0.use_fake_user=True;a0['scope']='Comparison adapter of previous compact hold; not a historical saved category Action'
            previous={};first=None
            for i in range(N+1):
                f=i+1;sample(r,s,source,f);pose={n:r.pose.bones[n].matrix_basis.copy() for n in UPPER}
                # Original carrier gives a common grip-root presentation. Keep
                # the category's native scale when adapting the reference gun.
                old_socket=Matrix(design['categories']['Rifle']['socket']);gm=r.pose.bones['WeaponCarrier'].matrix@old_socket
                gm=Matrix.LocRotScale(gm.translation,gm.to_quaternion(),socket.to_scale())
                assign(r,None);r.pose.bones['WeaponCarrier'].matrix=gm@socket.inverted();bpy.context.view_layer.update()
                poles={side:r.pose.bones['ForeArm.'+side].head.copy() for side in ['L','R']}
                for side,target in [('R',Vector((-.14,0,-.01))),('L',Vector((-.11,.035 if category=='Pistol' else .356,-.04)))]:
                    arm(r,side,gm@target,poles[side],gm.to_3x3()@Vector((1,0,0)))
                pose={n:r.pose.bones[n].matrix_basis.copy() for n in UPPER}
                if i==0:first=pose
                if i==N:
                    for n,m in first.items():r.pose.bones[n].matrix_basis=m.copy()
                key_upper(r,a0,f,previous)
            finish(a0,N);data['baseline_actions'][mode]=a0.name
    sample(r,s,bpy.data.actions[data['actions']['Hold']],1)
design['body_coordination']='Living Spine/Chest/Neck/head; forward head bias; leading weapon/left arm and 125 ms phase-delayed hovering right gesture'
design['baseline_note']='M4 A is actual W3; pistol/shotgun A are explicitly labeled compact comparison adapters because no older living RigV2 category Actions existed.'
(OUT/'design.json').write_text(json.dumps(design,indent=2))
checkpoint=save_checkpoint();result={'actions':{k:v['actions'] for k,v in design['categories'].items()},'checkpoint':str(checkpoint)}
