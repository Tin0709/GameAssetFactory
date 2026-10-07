from locomotion_sway_r12_common import *
design=json.loads((R12OUT/'design.json').read_text());assert not bpy.data.scenes.get('R12_HOLD_ALL')
baseposes={k:base_hold(k) for k in ['Unarmed','Pistol','Rifle','Shotgun']}
sc=studio('R12_HOLD_ALL');sc.render.resolution_x=1800;sc.render.resolution_y=700;sc.frame_end=96
sc.camera=camera(sc,'R12_Hold_Camera',(3,-5,3),(0,-.25,1.1),11.5);right=sc.camera.rotation_euler.to_quaternion()@Vector((1,0,0));actors={}
for i,kind in enumerate(['Unarmed','Pistol','Rifle','Shotgun']):
    rig,mesh,weapons=new_actor(sc,'Hold',kind,False);base=baseposes[kind];bpy.context.window.scene=sc
    action=bpy.data.actions.new('R12_Hold_'+kind+'_Upper');action.use_fake_user=True;assign(rig,action)
    for frame in range(1,98):
        phase=2*math.pi*(frame-1)/96
        for n in UPPER:
            p=rig.pose.bones[n];p.rotation_mode='QUATERNION';p.location=(0,0,0);p.rotation_quaternion=(1,0,0,0)
            if base is not None:p.location=base[n][0];p.rotation_quaternion=base[n][1]
        if kind in ['Rifle','Shotgun']:
            p=rig.pose.bones['UpperArm.L'];rest=p.parent.bone.matrix_local.inverted()@p.bone.matrix_local
            axis=rest.to_3x3().inverted()@Vector((1,0,0))
            p.rotation_quaternion=Quaternion(axis,math.radians(2+.5*math.sin(phase)))@base['UpperArm.L'][1]
        for side in ['L','R']:
            p=rig.pose.bones['UpperArm.'+side];rest=p.parent.bone.matrix_local.inverted()@p.bone.matrix_local
            p.location+=rest.to_3x3().inverted()@Vector((ARM_INSET if side=='R' else -ARM_INSET,0,0))
        if kind!='Unarmed':
            p=rig.pose.bones['WeaponCarrier'];rest=p.parent.bone.matrix_local.inverted()@p.bone.matrix_local
            p.location+=rest.to_3x3().inverted()@Vector((ARM_INSET+(LONG_GUN_CENTER_EXTRA if kind in ['Rifle','Shotgun'] else 0),-PISTOL_CARRIER_DROP if kind=='Pistol' else 0,SHOTGUN_FIXED_BACK_ADVANCE if kind=='Shotgun' else 0))
        rig.pose.bones['Spine'].location.y+=.0015*math.sin(phase)
        for n in UPPER:
            p=rig.pose.bones[n];p.keyframe_insert('rotation_quaternion',frame=frame,group=n);p.keyframe_insert('location',frame=frame,group=n)
    for fc in curves(action):
        for k in fc.keyframe_points:k.interpolation='LINEAR'
        fc.modifiers.new('CYCLES')
    compose(rig,action,None,1);rig.location=right*((i-1.5)*2.65)
    actors[kind]={'rig':rig.name,'mesh':mesh.name,'weapons':[w.name for w in weapons],'upper':action.name}
    label(sc,sc.camera,kind.upper(),(i-1.5)*2.65)
sc.frame_set(1);design['idle']={'scene':sc.name,'actors':actors,'frame_start':1,'frame_end':96,'loop':True,'scope':'Same close shoulders, single-hand pistol and lateral long-gun placement at rest'}
(R12OUT/'design.json').write_text(json.dumps(design,indent=2));result={'idle_scene':sc.name,'actors':list(actors)}
