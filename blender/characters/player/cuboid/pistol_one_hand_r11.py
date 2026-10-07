from hold_r11_common import *
design=json.loads((OUT/'design.json').read_text());assert not design.get('pistol_one_hand')
preserved={a.name:digest(a) for a in bpy.data.actions};d=design['categories']['Pistol']
table={(fc.data_path.split('"')[1],fc.data_path.rsplit('.',1)[-1],fc.array_index):fc for fc in curves(bpy.data.actions[design['locomotion']['imported_actions']['Walk_ReferenceStudy_V2']])}
sc=bpy.data.scenes[d['scene']];bpy.context.window.scene=sc;r=bpy.data.objects[d['rig']]
for mode,name in list(d['actions'].items()):
    a=bpy.data.actions[name].copy();a.name=name+'_OneHand';a.use_fake_user=True
    for fc in curves(a):
        if any('"'+n+'"' in fc.data_path for n in ['UpperArm.L','ForeArm.L']):
            fc.keyframe_points.clear()
            for mod in list(fc.modifiers):fc.modifiers.remove(mod)
    assign(r,a);previous=None
    for frame in range(1,PERIOD[mode]+2):
        rotation=Euler((0,0,0),'XYZ')
        if mode=='Move':
            for i in range(3):rotation[i]=table['Arm.L','rotation_euler',i].evaluate(1+(frame-1)%16)
        q=rotation.to_quaternion()@Quaternion((0,0,1),math.radians(3))
        if previous is not None and q.dot(previous)<0:q.negate()
        previous=q.copy()
        for bone,quat in [('UpperArm.L',q),('ForeArm.L',Quaternion())]:
            p=r.pose.bones[bone];p.rotation_mode='QUATERNION';p.rotation_quaternion=quat;p.location=(0,0,0)
            p.keyframe_insert('rotation_quaternion',frame=frame,group=bone);p.keyframe_insert('location',frame=frame,group=bone)
    for fc in curves(a):
        if any('"'+n+'"' in fc.data_path for n in ['UpperArm.L','ForeArm.L']):
            for k in fc.keyframe_points:k.interpolation='LINEAR'
            fc.modifiers.new('CYCLES')
    d['actions'][mode]=a.name
for mode,v in design['showcases'].items():
    actor=v['actors']['Pistol'];name=d['actions']['Move' if mode=='Turn' else mode]
    assign(bpy.data.objects[actor['rig']],bpy.data.actions[name]);actor['upper']=name
actor=design['walking']['Pistol']['actors']['Pistol'];assign(bpy.data.objects[actor['rig']],bpy.data.actions[d['actions']['Move']]);actor['upper']=d['actions']['Move']
assign(r,bpy.data.actions[d['actions']['Hold']]);sc.frame_set(25)
design['walk_sway']['actions']['Pistol']=d['actions']['Move']
design['pistol_one_hand']={'primary':'character RIGHT','left':'relaxed at rest; native free-arm gait swing while moving','scope':'study only'}
assert all(digest(bpy.data.actions[n])==h for n,h in preserved.items())
(OUT/'design.json').write_text(json.dumps(design,indent=2));result=design['pistol_one_hand']
