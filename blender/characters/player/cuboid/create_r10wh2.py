from hold_r10wh2_common import *
design=json.loads((OUT/'design.json').read_text());meta=json.loads((BASE/'turning_study_r3_review/preview_metadata.json').read_text())['gaits']['Walk']['rows']
for cat in [globals().get('CATEGORY','Pistol')]:
    d=design['categories'][cat];s=bpy.data.scenes[d['scene']];bpy.context.window.scene=s;r=bpy.data.objects[d['rig']];ws=[bpy.data.objects[n] for n in d['weapons']];d['actions']={}
    for mode in ['Hold','Move','AimAround','Turn']:
        name='PREVIEW_ONLY_R10WH2_'+cat+'_TURN' if mode=='Turn' else PREFIX[cat]+mode+'_ElbowStudy_V2'
        assert name not in bpy.data.actions
        source=bpy.data.actions[d['baseline_turn'] if mode=='Turn' else d['baseline_actions'][mode]];a=source.copy();a.name=name;a.use_fake_user=True;a['scope']='WH2 arm-only elbow fold over approved WH1';a['approved_source']=source.name
        for c in curves(a):
            if any('"'+n+'"' in c.data_path for n in ARMS):
                c.keyframe_points.clear()
                for mod in list(c.modifiers):c.modifiers.remove(mod)
        previous={};first=None;N=455 if mode=='Turn' else PERIOD[mode]
        for i in range(N+1):
            f=i+1;sample(r,s,source,f);assign(r,None)
            if mode=='Turn':drive=.65*meta[i]['signed_weight'];follow=.65*meta[max(0,i-3)]['signed_weight']
            else:
                phase=2*math.pi*i/N;strength=.9 if mode=='AimAround' else .14 if mode=='Move' else .09;drive=strength*math.sin(phase);follow=strength*math.sin(phase-2*math.pi*3/N)
            refine_arms(r,ws,cat,drive,follow)
            if first is None:first={n:r.pose.bones[n].matrix_basis.copy() for n in ARMS}
            if mode!='Turn' and i==N:
                for n,m in first.items():r.pose.bones[n].matrix_basis=m.copy()
            assign(r,a)
            for n in ARMS:
                p=r.pose.bones[n];q=p.rotation_quaternion.copy()
                if n in previous and q.dot(previous[n])<0:q.negate()
                previous[n]=q.copy();p.rotation_quaternion=q;p.keyframe_insert('rotation_quaternion',frame=f,group=n)
        for c in curves(a):
            if not any('"'+n+'"' in c.data_path for n in ARMS):continue
            ks=c.keyframe_points;ys=[k.co.y for k in ks]
            for i,k in enumerate(ks):
                if mode=='Turn':slope=(ys[min(i+1,len(ys)-1)]-ys[max(0,i-1)])/(1 if i in [0,len(ys)-1] else 2)
                else:j=i%N;slope=(ys[(j+1)%N]-ys[(j-1)%N])/2
                k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='FREE';k.handle_left=(k.co.x-1/3,k.co.y-slope/3);k.handle_right=(k.co.x+1/3,k.co.y+slope/3)
            if mode!='Turn':c.modifiers.new('CYCLES')
            c.update()
        if mode=='Turn':d['turn_action']=name
        else:d['actions'][mode]=name
(OUT/'design.json').write_text(json.dumps(design,indent=2));result={'category':cat,'actions':d['actions'],'turn':d['turn_action'],'checkpoint':checkpoint()}
