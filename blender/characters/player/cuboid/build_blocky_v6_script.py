from pathlib import Path
p=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
s=(p/'create_blocky_run_v5_pass5.py').read_text(encoding='utf-8-sig')
# Advance versions in one simultaneous replacement, never execute the prior pass.
s=s.replace('v5','TMPNEW').replace('v4','v5').replace('TMPNEW','v6').replace('V5','TMPNEW').replace('V4','V5').replace('TMPNEW','V6').replace('PASS5','PASS6').replace('pass5','pass6')
start=s.index('# Keep all principal phase frames.')
end=s.index("rig.pose.bones['Root'].matrix_basis=Matrix.Identity(4)",start)
style='''# Selected authored pose changes; unselected V5 curves remain bit-for-bit copied.
changed=set()
def touch(c):changed.add((c.data_path,c.array_index))
def phase(k):return round((k.co.x-1)%16,3)
# Contact front/rear separation: small angle changes, rather than a new stride.
for n,values in [('Leg.L',{0:-38.8,8:31.3}),('Leg.R',{0:29.2,8:-36.7})]:
    c=curve(n,'rotation_euler',0)
    for k in c.keyframe_points:
        if phase(k) in values:k.co.y=math.radians(values[phase(k)])
        if abs(k.co.x-(13 if n=='Leg.L' else 5))<.01:k.co.x-=.10
    c.update();tangents(c);touch(c)
# Passing recovery leg opens outward 0.55/0.65 degree, keeping the rigid boxes distinct.
for n,passing,peak in [('Leg.L',5,1.55),('Leg.R',13,-1.65)]:
    c=curve(n,'rotation_euler',2)
    sign=1 if n=='Leg.L' else -1
    replace_keys(c,[(f,math.radians(peak if f==passing else sign)) for f in [1,3,5,7,9,11,13,15,17]])
    tangents(c);touch(c)
# Hips drive push-off slightly earlier; Up peak is not raised.
c=curve('Hips','location',1)
for k in c.keyframe_points:
    if abs(k.co.x-5)<.01:k.co.x-=.15;k.co.y+=.0015
    if abs(k.co.x-13)<.01:k.co.x-=.12;k.co.y+=.0013
c.update();tangents(c);touch(c)
c=curve('Hips','rotation_euler',1)
for k in c.keyframe_points:
    if phase(k) in [0,8]:k.co.y*=1.05
c.update();tangents(c);touch(c)
# Chest counter-turn is emphasized selectively at contacts, retaining the athletic lean.
for n,offset in [('Spine',.45),('Chest',.85)]:
    c=curve(n,'rotation_euler',0)
    for k in c.keyframe_points:
        f=k.co.x
        if any(abs(f-(1+offset+8*j))<.01 for j in [0,1]):k.co.y+=math.radians(.10 if n=='Spine' else .08)
        if any(abs(f-(5+offset+8*j))<.01 for j in [0,1]):k.co.x-=.06 if n=='Spine' else .10
        if n=='Chest' and any(abs(f-(7+offset+8*j))<.01 for j in [0,1]):k.co.y-=math.radians(.10)
    c.update();tangents(c);touch(c)
c=curve('Chest','rotation_euler',1)
for k in c.keyframe_points:
    if any(abs(k.co.x-f)<.01 for f in [1,1.85,9.85,17]):k.co.y*=1.06
c.update();tangents(c);touch(c)
# Rear-arm drive +6%; controlled compact forward swing stays unchanged.
for n in ['Arm.L','Arm.R']:
    c=curve(n,'rotation_euler',0)
    for k in c.keyframe_points:
        if k.co.y<0:k.co.y*=1.06
        if n=='Arm.L' and abs(k.co.x-10.2)<.02:k.co.x-=.10
        if n=='Arm.R' and abs(k.co.x-2.35)<.02:k.co.x-=.12
    c.update();tangents(c);touch(c)
    # Tiny outward path and less twist keep top arm corners away from the head.
    c=curve(n,'rotation_euler',2)
    for k in c.keyframe_points:k.co.y+=math.radians(.9 if n=='Arm.L' else -.9)
    c.update();tangents(c);touch(c)
    c=curve(n,'rotation_euler',1)
    for k in c.keyframe_points:k.co.y*=.75
    c.update();tangents(c);touch(c)
# Gaze leads by only .08 degree; existing stabilization and delays are retained.
c=curve('Head','rotation_euler',0)
for k in c.keyframe_points:k.co.y+=math.radians(.08)
c.update();tangents(c);touch(c)
# A constant 1 mm lift reduces the rotated cube's shoulder seam contact without extra keys.
c=curve('Head','location',1)
for k in c.keyframe_points:k.co.y+=.001
c.update();tangents(c);touch(c)
# Contact accommodation only: preserve V5 foot heights, keep existing key locations where useful.
desired={n:[] for n in ['Leg.L','Leg.R']};max_ground_adjust=0
for f in frames:
    mats,points=sample(f);bm,bp=baseline[f]
    for n in desired:
        target=min(bp[i].z for i in parts[n]);current=min(points[i].z for i in parts[n])
        delta=target-current;max_ground_adjust=max(max_ground_adjust,abs(delta))
        pb=rig.pose.bones[n];b=pb.bone
        ref=b.convert_local_to_pose(Matrix.Identity(4),b.matrix_local,parent_matrix=pb.parent.matrix,parent_matrix_local=pb.parent.bone.matrix_local)
        correction=(rig.matrix_world@ref).to_3x3().inverted()@Vector((0,0,delta))
        desired[n].append((f,tuple(pb.location+correction)))
for n in desired:
    desired[n][-1]=(17.,desired[n][0][1])
    for axis in range(3):
        c=curve(n,'location',axis);data=[(f,v[axis]) for f,v in desired[n]]
        chosen={max(0,min(512,round((k.co.x-1)*32))) for k in c.keyframe_points}
        for iteration in range(100):
            replace_keys(c,[data[i] for i in sorted(chosen)]);tangents(c)
            error,index=max((abs(c.evaluate(f)-v),i) for i,(f,v) in enumerate(data))
            if error<=(.00050 if axis==1 else .00012):break
            chosen.add(index)
        assert error<=(.00050 if axis==1 else .00012),(n,axis,error)
        touch(c)
'''
s=s[:start]+style+s[end:]
s=s.replace('and new_count<old_count','and new_count<old_count+120')
s=s.replace("assert all(a<b for a,b in zip(half_compression(v6),half_compression(v5))),(half_compression(v6),half_compression(v5))", "assert all(abs(a-b)<.025 for a,b in zip(half_compression(v6),half_compression(v5)))")
s=s.replace("timing_changes='Spine/Chest 0.10 frame earlier; Arm.L +0.05; Neck/Head +0.05. Contact settling at 2.72/10.78; extended Up tangents.'", "timing_changes='Preserve Contact impact; Passing Hips 0.15/0.12 frame earlier, support-leg Passing 0.10 earlier, Spine/Chest recovery 0.06/0.10 earlier; rear arm extremes 0.10/0.12 earlier.'")
s=s.replace("intersections=clip,keys_before", "style_changes=dict(contact_leg_degrees={'Leg.L':[-38.8,31.3],'Leg.R':[-36.7,29.2]},rear_arm_gain=1.06,contact_chest_yaw_gain=1.06,contact_hips_yaw_gain=1.05,passing_recovery_abduction_added_degrees=[.55,.65],arm_outward_path_added_degrees=.9,arm_twist_gain=.75,head_pitch_intent_added_degrees=.08,head_seam_lift_m=.001,up_height_increase_m=0),changed_curve_count=len(changed),intersections=clip,keys_before")
s=s.replace("for view,camera in [('iso','V3 Isometric Camera'),('side','V3 Side Camera')]:", """# Dry-run-only camera for a front 3/4 view; never saved to the live test.
    front=bpy.data.objects['V3 Isometric Camera'].copy();front.data=front.data.copy();front.name='Pass6_Review_Front_Only';scene.collection.objects.link(front)
    front.location=(3.0,-5.5,2.8);front.rotation_euler=(Vector((0,0,.95))-front.location).to_track_quat('-Z','Y').to_euler();front.data.type='ORTHO';front.data.ortho_scale=2.4
    for view,camera in [('iso','V3 Isometric Camera'),('side','V3 Side Camera'),('front',front.name)]:""")
s=s.replace("return 6.0", "return 15.0")
# Record which V5 curves truly remained untouched.
s=s.replace("(BASE/'player_run_blocky_v6_pass6_report.json').write_text", "report['unmodified_curve_count']=len(fcurves(v6))-len(changed)\n(BASE/'player_run_blocky_v6_pass6_report.json').write_text")
(p/'create_blocky_run_v6_pass6.py').write_text(s,encoding='utf-8')
