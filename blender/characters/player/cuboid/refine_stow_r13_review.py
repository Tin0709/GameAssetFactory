from locomotion_sway_r12_common import *
R13OUT=BASE/'weapon_stow_r13_review';d=json.loads((R13OUT/'design.json').read_text());sc=bpy.data.scenes[d['scene']];bpy.context.window.scene=sc
proto=bpy.data.objects['Player_Cuboid_Rig'];sampler=proto.copy();sampler.data=proto.data.copy();sampler.animation_data_clear();sc.collection.objects.link(sampler);assign(sampler,bpy.data.actions[d['source']])
for p in sampler.pose.bones:p.matrix_basis=Matrix.Identity(4)
cache={}
for i in range(205):
    f=1+i/12;sc.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
    ch=sampler.pose.bones['Chest'].matrix.copy()
    cache[i]={'body':{n:sampler.pose.bones[n].matrix_basis.to_quaternion() for n in ['Spine','Chest','Neck','Head']},'weapon':ch.inverted()@sampler.pose.bones['WeaponCarrier'].matrix}
tmp=sampler.data;bpy.data.objects.remove(sampler,do_unlink=True);bpy.data.armatures.remove(tmp)
def smooth(x):x=max(0,min(1,x));return x*x*(3-2*x)
def sf_for(f):
    if f<=12:return 1
    if f<=46:return 1+(f-12)*17/34
    if f<=58:return 18+(f-46)/3
    if f<=66:return 22
    if f<=78:return 22-(f-66)/3
    if f<=112:return 18-(f-78)*17/34
    return 1
def blendmat(a,b,t):
    pa,qa,sa=a.decompose();pb,qb,sb=b.decompose();m=(qa.slerp(qb,t).to_matrix()@Matrix.Diagonal(sa.lerp(sb,t))).to_4x4();m.translation=pa.lerp(pb,t);return m
def q_from_dir(r,side,direction,reference=None):
    p=r.pose.bones['UpperArm.'+side];rel=p.parent.bone.matrix_local.inverted()@p.bone.matrix_local
    rest=rel.to_3x3();orientation=rest@(reference or p.rotation_quaternion).to_matrix();y=orientation@Vector((0,1,0))
    turn=y.rotation_difference(direction.normalized()).to_matrix()
    return (rest.inverted()@turn@orientation).to_quaternion()
def interpolate_keys(keys,f):
    for i in range(len(keys)-1):
        a,qa=keys[i];b,qb=keys[i+1]
        if a<=f<=b:return qa.slerp(qb,smooth((f-a)/(b-a)))
    return keys[-1][1]

for kind,a in d['actors'].items():
    rig=bpy.data.objects[a['rig']];ws=[bpy.data.objects[n] for n in a['weapons']];main=next(w for w in ws if '_Base' in w.name)
    old=bpy.data.actions[a['action']];assign(rig,None)
    start={n:(Vector(p['location']),Quaternion(p['rotation_quaternion'])) for n,p in a['start'].items()}
    for n,(l,q) in start.items():rig.pose.bones[n].location=l;rig.pose.bones[n].rotation_quaternion=q
    bpy.context.view_layer.update();wm=rig.matrix_world.inverted()@main.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world
    socket=rig.pose.bones['WeaponCarrier'].matrix.inverted()@wm;start_gun=rig.pose.bones['Chest'].matrix.inverted()@wm;grip=wm.inverted()@rig.pose.bones['ForeArm.R'].tail;scale=wm.to_scale()
    lean=math.radians(12)
    angle=math.atan(math.tan(math.radians(55))/math.cos(lean)) # retain 55-degree rear silhouette
    # Gun Y points down and across the back; the mount centre is above torso centre.
    target_q=(Matrix.Diagonal(Vector((-1,-1,1))) if kind=='Pistol' else Matrix.Rotation(-lean,3,'X')@Matrix(((0,-math.cos(angle),-math.sin(angle)),(0,-math.sin(angle),math.cos(angle)),(-1,0,0)))).to_quaternion()
    target=(target_q.to_matrix()@Matrix.Diagonal(scale)).to_4x4()
    pts=[target@(main.matrix_world.inverted()@w.matrix_world@v.co) for w in ws for v in w.data.vertices]
    lo=Vector(tuple(min(p[j] for p in pts) for j in range(3)));hi=Vector(tuple(max(p[j] for p in pts) for j in range(3)))
    target.translation=(Vector((-.225-(lo.x+hi.x)/2,-.40-(lo.y+hi.y)/2,.02-(lo.z+hi.z)/2)) if kind=='Pistol' else Vector((-(lo.x+hi.x)/2,.05-(lo.y+hi.y)/2,-.1275-hi.z)))
    # A simple straight-arm outward arc keeps resized long-gun stocks clear.
    qkeys=[(1,start['UpperArm.R'][1])]
    directions=[(4,(-.50,.12,.86)),(8,(-.94,.25,.18)),(11,(-.78,-.50,-.36)),(14,(-.32,-.50,-.80)),(15.5,(-.12,-.50,-.86)),(22,(0,-1,0))]
    if kind=='Pistol':directions=[(5,(-.30,-.55,.78)),(10,(-.18,-.85,.49)),(14,(-.10,-.99,.03)),(15.5,(-.10,-.99,.02)),(22,(0,-1,0))]
    for fr,vec in directions:
        qkeys.append((fr,q_from_dir(rig,'R',Vector(vec),qkeys[-1][1])))
    left_down=q_from_dir(rig,'L',Vector((0,-1,0)))
    new=bpy.data.actions.new('R13_'+kind+('_Holster_RightHipInset' if kind=='Pistol' else '_Holster_MuzzleDownBack'));new.use_fake_user=True;assign(rig,new);prev={}
    for j in range(249):
        f=1+j/2;sc.frame_set(int(f),subframe=f-int(f));sf=sf_for(f);src=cache[max(0,min(204,round((sf-1)*12)))]
        for n,(l,q) in start.items():rig.pose.bones[n].location=l;rig.pose.bones[n].rotation_quaternion=q
        for n in ['Spine','Chest','Neck','Head']:
            rig.pose.bones[n].rotation_quaternion=start[n][1]@(cache[0]['body'][n].inverted()@src['body'][n])
        rig.pose.bones['UpperArm.R'].rotation_quaternion=interpolate_keys(qkeys,sf)
        rig.pose.bones['UpperArm.L'].rotation_quaternion=start['UpperArm.L'][1].slerp(left_down,smooth((sf-2)/5))
        for side in ['L','R']:rig.pose.bones['ForeArm.'+side].rotation_quaternion=(1,0,0,0)
        bpy.context.view_layer.update();ch=rig.pose.bones['Chest'].matrix.copy()
        # Native gun rotation timing, with an unchanged hand-local attachment.
        tq=(src['weapon']@socket).to_quaternion();q=start_gun.to_quaternion().slerp(tq,smooth((sf-1)/6))
        if kind=='Pistol':q=start_gun.to_quaternion().slerp(target_q,smooth((sf-1)/14.7))
        elif sf>8:
            q8=start_gun.to_quaternion().slerp((cache[84]['weapon']@socket).to_quaternion(),smooth(7/6))
            q=q8.slerp(target_q,smooth((sf-8)/7.7))
        gm=(q.to_matrix()@Matrix.Diagonal(scale)).to_4x4();hand=ch.inverted()@rig.pose.bones['ForeArm.R'].tail;gm.translation=hand-gm.to_3x3()@grip
        gm=blendmat(gm,target,smooth((sf-13.5)/2.2))
        rig.pose.bones['WeaponCarrier'].matrix=ch@gm@socket.inverted();bpy.context.view_layer.update()
        for n in UPPER:
            p=rig.pose.bones[n];q=p.rotation_quaternion.copy()
            if n in prev and q.dot(prev[n])<0:q.negate();p.rotation_quaternion=q
            prev[n]=q.copy();p.keyframe_insert('location',frame=f,group=n);p.keyframe_insert('rotation_quaternion',frame=f,group=n)
    for fc in curves(new):
        for k in fc.keyframe_points:k.interpolation='LINEAR'
        fc.modifiers.new('CYCLES')
    for fr,name in [(12,'HOLSTER_BEGIN'),(22,'LEFT_RELEASE'),(41,'STOW_HANDOFF'),(46,'STOWED'),(78,'REVIEW_RETURN'),(112,'READY')]:new.pose_markers.new(name).frame=fr
    new['source']=d['source'];new['scope']=('Right-hip pistol stow with half-width inset' if kind=='Pistol' else 'Close-back mount, muzzle-down 55-degree slope')+'; reverse is review reset only';a['action']=new.name
    a['back_target_chest_matrix']=[list(row) for row in target]
d['back_mount']={'orientation':'diagonal across upper back, muzzle down','slope_degrees':55,'additional_degrees':45,'stock_clearance_lean_degrees':12,'nearest_surface_chest_z_m':-.1275,'chest_back_surface_z_m':-.1125,'gap_m':.015,'center_chest_y_m':.05,'torso_center_chest_y_m':-.05625}
d['pistol_mount']={'side':'CHARACTER RIGHT HIP','barrel':'down','center_chest_x_m':-.225,'half_width_inside_hip':True,'intentional_overlap':'User requested half the gun width inset into right hip','center_chest_y_m':-.40,'center_chest_z_m':.02}
d['frames']={'ready':[1,12],'holster':[12,46],'arm_settle':[46,58],'stowed_rest':[58,66],'review_arm_prepare':[66,78],'review_return':[78,112],'ready_rest':[112,124]}
for scene_name in [d['scene'],d['front_scene']]:
    review=bpy.data.scenes[scene_name];review.frame_end=124
    for marker in list(review.timeline_markers):review.timeline_markers.remove(marker)
    for fr,name in [(12,'CẤT SÚNG'),(46,'VỊ TRÍ CẤT'),(78,'TRỞ VỀ ĐỂ LẶP REVIEW')]:review.timeline_markers.new(name,frame=fr)
(R13OUT/'design.json').write_text(json.dumps(d,indent=2));sc.frame_set(26);result={'refined':list(d['actors']),'source_actions_preserved':True}
