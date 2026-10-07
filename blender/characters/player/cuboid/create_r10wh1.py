from hold_r10wh1_common import *
design=json.loads((OUT/'design.json').read_text());meta=json.loads((BASE/'turning_study_r3_review/preview_metadata.json').read_text())['gaits']['Walk']['rows']
def key_upper(r,a,f,previous):
    assign(r,a)
    for n in UPPER:
        p=r.pose.bones[n];q=p.rotation_quaternion.copy()
        if n in previous and q.dot(previous[n])<0:q.negate()
        p.rotation_quaternion=q;previous[n]=q.copy();p.keyframe_insert('rotation_quaternion',frame=f,group=n)
        if n=='WeaponCarrier':p.keyframe_insert('location',frame=f,group=n)
for category in [globals().get('CATEGORY','Rifle')]:
    data=design['categories'][category];s=bpy.data.scenes[data['scene']];bpy.context.window.scene=s;r=bpy.data.objects[data['rig']];ws=[bpy.data.objects[n] for n in data['weapons']];socket=Matrix(data['socket']);base={n:Matrix(x) for n,x in data['base'].items()};data['actions']={}
    for mode,N in PERIOD.items():
        name=PREFIX[category]+mode+'_RightEyeStudy_V1'
        if globals().get('REBAKE_OWNED',False):
            a=bpy.data.actions[name];assert a.get('scope','').startswith('R10-WH1 upper-only')
        else:
            assert name not in bpy.data.actions;a=bpy.data.actions[data['baseline_actions'][mode]].copy();a.name=name
        a.use_fake_user=True;a['scope']='R10-WH1 upper-only FK study: character RIGHT primary / LEFT shallow support / right-eye sight proxy';a['primary_arm']='R';a['support_arm']='L';a['eye_proxy_local']=list(EYE)
        for c in curves(a):
            c.keyframe_points.clear()
            for mod in list(c.modifiers):c.modifiers.remove(mod)
        previous={};first=None
        for i in range(N+1):
            phase=2*math.pi*i/N;strength=.9 if mode=='AimAround' else .14 if mode=='Move' else .09;drive=strength*math.sin(phase);follow=strength*math.sin(phase-2*math.pi*3/N);breath=math.sin(phase*(3 if mode=='AimAround' else 1))
            body_pose(r,base,phase,drive,follow,breath);pose_hold(r,ws,socket,category,drive,follow,breath)
            if i==0:first={n:r.pose.bones[n].matrix_basis.copy() for n in UPPER}
            if i==N:
                for n,mat in first.items():r.pose.bones[n].matrix_basis=mat.copy()
            key_upper(r,a,i+1,previous)
        periodic(a,N);data['actions'][mode]=a.name
    name='PREVIEW_ONLY_R10WH1_'+category+'_TURN'
    if globals().get('REBAKE_OWNED',False):
        a=bpy.data.actions[name];assert a.get('scope','').startswith('PREVIEW ONLY upper response')
    else:
        assert name not in bpy.data.actions;a=bpy.data.actions[data['actions']['Move']].copy();a.name=name
    a.use_fake_user=True;a['scope']='PREVIEW ONLY upper response; original turn gait/path/facing unchanged'
    for c in curves(a):
        c.keyframe_points.clear()
        for mod in list(c.modifiers):c.modifiers.remove(mod)
    previous={}
    for i,row in enumerate(meta):
        phase=2*math.pi*row['time']/4;drive=.65*row['signed_weight'];follow=.65*meta[max(0,i-3)]['signed_weight'];breath=math.sin(phase);body_pose(r,base,phase,drive,follow,breath);pose_hold(r,ws,socket,category,drive,follow,breath);key_upper(r,a,i+1,previous)
    for c in curves(a):
        ks=c.keyframe_points;ys=[k.co.y for k in ks]
        for i,k in enumerate(ks):
            slope=(ys[min(i+1,len(ks)-1)]-ys[max(0,i-1)])/(1 if i in [0,len(ks)-1] else 2);k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='FREE';k.handle_left=(k.co.x-1/3,k.co.y-slope/3);k.handle_right=(k.co.x+1/3,k.co.y+slope/3)
        c.update()
    data['turn_action']=a.name
(OUT/'design.json').write_text(json.dumps(design,indent=2));result={'actions':{c:d.get('actions',{}) for c,d in design['categories'].items()},'checkpoint':checkpoint()}
