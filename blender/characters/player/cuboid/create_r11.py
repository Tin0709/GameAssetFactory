from hold_r11_common import *
old=json.loads((BASE/'weapon_hold_r10wh2_review/design.json').read_text());design={'categories':{},'locomotion':old['locomotion'],'source':'Stopped WH2 development, not approved production','scope':'R11 study only; human review pending'}
for cat in ['Pistol','Rifle','Shotgun']:
    s=studio('R11_AUTHOR_'+cat.upper());r,m,ws=clone_r11('Author_'+cat,s,cat);base=next(w for w in ws if '_Base' in w.name)
    bpy.context.view_layer.update();gm=r.matrix_world.inverted()@base.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world;socket=r.pose.bones['WeaponCarrier'].matrix.inverted()@gm
    d={'scene':s.name,'rig':r.name,'mesh':m.name,'weapons':[w.name for w in ws],'socket':[list(row) for row in socket],'trigger':list(TRIGGER[cat]),'actions':{},'baseline_actions':old['categories'][cat]['actions']}
    for mode in ['Hold','Move','AimAround']:
        N=PERIOD[mode];a=bpy.data.actions.new(PREFIX[cat]+mode+'_SimpleR11');a.use_fake_user=True;a['scope']='R11 upper only, straight arms; human review pending'
        previous={}
        for i in range(N+1):
            phase=2*math.pi*i/N;simple_pose(r,socket,cat,12*math.sin(phase) if mode=='AimAround' else 0,math.sin(phase))
            assign(r,a)
            for n in UPPER:
                p=r.pose.bones[n];q=p.rotation_quaternion.copy()
                if n in previous and q.dot(previous[n])<0:q.negate()
                p.rotation_quaternion=q;previous[n]=q.copy();p.keyframe_insert('rotation_quaternion',frame=i+1,group=n);p.keyframe_insert('location',frame=i+1,group=n)
        for c in curves(a):
            for k in c.keyframe_points:k.interpolation='LINEAR'
            c.modifiers.new('CYCLES')
        d['actions'][mode]=a.name
    s.frame_end=96;assign(r,bpy.data.actions[d['actions']['Hold']]);s.frame_set(25)
    cams={}
    for view,pos,target in [('FrontThreeQuarter',(-3,-5,2.6),(0,-.35,1.1)),('Side',(-5,-.2,1.8),(0,-.4,1.1)),('Overhead',(0,-.3,5),(0,-.3,0)),('Front',(0,-5,1.4),(0,-.35,1.1))]:
        cams[view]=camera(s,'R11_'+cat+'_'+view,pos,target,3.4).name
    d['cameras']=cams;design['categories'][cat]=d
(OUT/'design.json').write_text(json.dumps(design,indent=2));result={'actions':{c:d['actions'] for c,d in design['categories'].items()}}
