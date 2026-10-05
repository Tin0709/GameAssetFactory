import bpy,math,json,ast,hashlib,shutil
from pathlib import Path
from mathutils import Vector,Matrix,Euler
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid');TEST=BASE/'blocky_character_mixamo_test.blend'
assert Path(bpy.data.filepath)==TEST
scene=bpy.context.scene;rig=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base']
assert scene.render.fps/scene.render.fps_base==24
if not bpy.app.background and bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
assert bpy.data.actions.get('Player_Run_Blocky_V6') is None,'V6 exists; never overwrite'
for file,names in [('prepare_mixamo_run.py',{'vv','mm','fcurves','action_signature','object_signature'}),('create_blocky_run_v2_pass2.py',{'sample','box_axes','overlap'})]:
    tree=ast.parse((BASE/file).read_text(encoding='utf-8-sig'))
    exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),'snapshot_eval_helpers','exec'))
v5=bpy.data.actions['Player_Run_Blocky_V5'];protected={a.name:action_signature(a) for a in bpy.data.actions}
geom=object_signature(mesh);structure=object_signature(rig);structure.pop('pose');structure.pop('action')
production_hash=hashlib.sha256((BASE/'player_cuboid_v6.blend').read_bytes()).hexdigest()
assert not rig.animation_data.nla_tracks and not any(p.constraints for p in rig.pose.bones)
if not bpy.app.background and bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
parts={g.name:[v.index for v in mesh.data.vertices if any(w.group==g.index and w.weight>.999 for w in v.groups)] for g in mesh.vertex_groups}
frames=[1+i/32 for i in range(513)]
rig.animation_data.action=v5
if v5.slots:rig.animation_data.action_slot=v5.slots[0]
rig.pose.bones['Root'].matrix_basis=Matrix.Identity(4)
baseline={f:sample(f) for f in frames}
old_count=sum(len(c.keyframe_points) for c in fcurves(v5));v6=v5.copy();v6.name='Player_Run_Blocky_V6';v6.use_fake_user=True
rig.animation_data.action=v6
if v6.slots:rig.animation_data.action_slot=v6.slots[0]
def bone_name(c):return c.data_path.split('"')[1]
def curve(n,prop,i):return next(c for c in fcurves(v6) if c.data_path==f'pose.bones["{n}"].{prop}' and c.array_index==i)
def replace_keys(c,values):
    c.keyframe_points.clear()
    for t,v in values:c.keyframe_points.insert(t,v,options={'FAST'})
    c.update()
def tangents(c):
    # Periodic monotone cubic slopes: C1 across every key and loop, no accidental overshoot.
    ks=c.keyframe_points;N=len(ks);ks[-1].co.y=ks[0].co.y
    for i,k in enumerate(ks):
        if i in [0,N-1]:
            p=ks[-2];q=ks[1];h0=ks[0].co.x-(p.co.x-16);h1=q.co.x-ks[0].co.x;v0=p.co.y;v1=q.co.y
        else:
            p=ks[i-1];q=ks[i+1];h0=k.co.x-p.co.x;h1=q.co.x-k.co.x;v0=p.co.y;v1=q.co.y
        d0=(k.co.y-v0)/h0;d1=(v1-k.co.y)/h1
        if d0*d1<=0:slope=0
        else:
            w0=2*h1+h0;w1=h1+2*h0;slope=(w0+w1)/(w0/d0+w1/d1)
        left=right=1/3
        phase=(k.co.x-1)%8;n=bone_name(c)
        if n=='Hips' and c.data_path.endswith('location') and c.array_index==1:
            if phase<.01 or phase>7.99:
                right=.23;slope=-.038 if k.co.x<5 or k.co.x>16 else -.034
            if abs(phase-2)<.01:left=.40;right=.28
            if abs(phase-6)<.01:left=.42;right=.42
        if n.startswith('Arm.') and c.array_index==0 and slope==0:left=.38;right=.38
        k.interpolation='BEZIER';k.handle_left_type='FREE';k.handle_right_type='FREE'
        k.handle_left=(k.co.x-h0*left,k.co.y-slope*h0*left);k.handle_right=(k.co.x+h1*right,k.co.y+slope*h1*right)
    if not any(m.type=='CYCLES' for m in c.modifiers):c.modifiers.new('CYCLES')
    c.update()
# Selected authored pose changes; unselected V5 curves remain bit-for-bit copied.
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
    for k in c.keyframe_points:k.co.y+=math.radians(-.6 if n=='Arm.L' else 1.2)
    c.update();tangents(c);touch(c)
    c=curve(n,'rotation_euler',1)
    for k in c.keyframe_points:k.co.y=k.co.y*.75+math.radians(.6 if n=='Arm.L' else 0)
    c.update();tangents(c);touch(c)
# Gaze leads by only .08 degree; existing stabilization and delays are retained.
c=curve('Head','rotation_euler',0)
for k in c.keyframe_points:k.co.y+=math.radians(.08)
c.update();tangents(c);touch(c)
# A constant 3 mm lift reduces the rotated cube's shoulder seam contact without extra keys.
c=curve('Head','location',1)
for k in c.keyframe_points:k.co.y+=.003
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
rig.pose.bones['Root'].matrix_basis=Matrix.Identity(4)
# Validation including dense contact checks, rigid box overlap and periodic derivatives.
rest_lengths={(n,i,j):(mesh.matrix_world@(mesh.data.vertices[i].co-mesh.data.vertices[j].co)).length for n,ids in parts.items() for i in ids for j in ids if j>i}
animated=['Hips','Leg.L','Leg.R','Spine','Chest','Arm.L','Arm.R','Neck','Head']
ranges={n:[[1e9,-1e9] for i in range(3)] for n in animated};world_ranges={n:[[1e9,-1e9] for i in range(3)] for n in ['Chest','Head']}
root_travel=0;rigid_error=0;groundmin=1e9;groundmax=0;min_pair_max=0;supportmax=0;supportmin=1e9;hippos=[];clip={};angles=[];details=[];gaze_min=1
restrot=(rig.matrix_world@rig.data.bones['Chest'].matrix_local).to_3x3()
for f in frames:
    mats,points=sample(f);bm,bp=baseline[f]
    root_ref=rig.matrix_world@rig.data.bones['Root'].matrix_local;root_travel=max(root_travel,(mats['Root'].translation-root_ref.translation).length)
    bottoms={n:min(points[i].z for i in parts[n]) for n in ['Leg.L','Leg.R']}
    groundmin=min(groundmin,min(bottoms.values()));groundmax=max(groundmax,max(bottoms.values()));min_pair_max=max(min_pair_max,min(bottoms.values()))
    for n in bottoms:
        if min(bp[i].z for i in parts[n])<=.006:supportmax=max(supportmax,bottoms[n]);supportmin=min(supportmin,bottoms[n])
    hippos.append(mats['Hips'].translation.copy())
    for (n,i,j),length in rest_lengths.items():rigid_error=max(rigid_error,abs((points[i]-points[j]).length-length))
    assert all(max(abs(v-1) for v in p.scale)<1e-7 for p in rig.pose.bones)
    for n in ranges:
        for i,v in enumerate(rig.pose.bones[n].rotation_euler):
            d=math.degrees(v);ranges[n][i][0]=min(ranges[n][i][0],d);ranges[n][i][1]=max(ranges[n][i][1],d)
    for n in world_ranges:
        e=(restrot.inverted()@mats[n].to_3x3()).to_euler('XYZ')
        for i,v in enumerate(e):d=math.degrees(v);world_ranges[n][i][0]=min(world_ranges[n][i][0],d);world_ranges[n][i][1]=max(world_ranges[n][i][1],d)
    gaze=(mats['Head'].to_3x3()@Vector((0,0,1))).normalized();gaze_min=min(gaze_min,gaze.dot(Vector((0,-1,0))))
    if round(f*8)%4==0:
        for a,b in [('Head','Chest'),('Head','Arm.L'),('Head','Arm.R'),('Arm.L','Chest'),('Arm.R','Chest'),('Chest','Leg.L'),('Chest','Leg.R')]:
            d=overlap(a,b,points);bd=overlap(a,b,bp)
            if d:
                stat=clip.setdefault(a+' / '+b,dict(max_overlap_m=0,baseline_max_overlap_m=0,max_increase_from_v5_m=0));stat['max_overlap_m']=max(stat['max_overlap_m'],d);stat['baseline_max_overlap_m']=max(stat['baseline_max_overlap_m'],bd);stat['max_increase_from_v5_m']=max(stat['max_increase_from_v5_m'],d-bd)
    angles.append({n:mats[n].to_quaternion() for n in animated})
    if f in [1,3,5,7,9,11,13,15,17]:
        def reach(n):return (mats[n].to_3x3()@Vector((0,1,0))).normalized().dot(Vector((0,-1,0)))
        details.append(dict(frame=f,hips_world=vv(mats['Hips'].translation),leg_bottom_z_m=bottoms,arm_leg_forward_component={n:reach(n) for n in ['Arm.L','Arm.R','Leg.L','Leg.R']}))
first,_=sample(1);last,_=sample(17)
loop_error=max(abs(first[n][i][j]-last[n][i][j]) for n in first for i in range(4) for j in range(4))
h=last['Hips'].translation-first['Hips'].translation;horizontal=math.hypot(h.x,h.y)
max_step=max(min(math.degrees(a[n].rotation_difference(b[n]).angle),360-math.degrees(a[n].rotation_difference(b[n]).angle)) for a,b in zip(angles,angles[1:]) for n in animated)
tangent_error=0
for c in fcurves(v6):
    a,b=c.keyframe_points[0],c.keyframe_points[-1]
    sa=(a.handle_right.y-a.co.y)/(a.handle_right.x-a.co.x);sb=(b.co.y-b.handle_left.y)/(b.co.x-b.handle_left.x)
    tangent_error=max(tangent_error,abs(sa-sb))
new_count=sum(len(c.keyframe_points) for c in fcurves(v6))
for pose in details:
    d=pose['arm_leg_forward_component']
    if pose['frame'] in [1,17]:assert d['Arm.L']>0 and d['Leg.R']>0 and d['Arm.R']<0 and d['Leg.L']<0
    if pose['frame']==9:assert d['Arm.R']>0 and d['Leg.L']>0 and d['Arm.L']<0 and d['Leg.R']<0
assert root_travel<1e-7 and horizontal<1e-7 and loop_error<1e-7 and tangent_error<2e-5
assert groundmin>0 and supportmax<.0065 and rigid_error<1e-5 and max_step<2 and gaze_min>.98
assert max_ground_adjust<.025,max_ground_adjust
assert all((b-a)<(d-c)*.85 for (a,b),(c,d) in zip(world_ranges['Head'],world_ranges['Chest']))
assert not any('.scale' in c.data_path for c in fcurves(v6)) and new_count<old_count+120
assert protected=={n:action_signature(bpy.data.actions[n]) for n in protected}
assert geom==object_signature(mesh)
s=object_signature(rig);s.pop('pose');s.pop('action');assert s==structure
assert production_hash==hashlib.sha256((BASE/'player_cuboid_v6.blend').read_bytes()).hexdigest()
def half_compression(action):
    cc=next(c for c in fcurves(action) if c.data_path=='pose.bones["Hips"].location' and c.array_index==1)
    result=[]
    for contact in [1,9]:
        midpoint=(cc.evaluate(contact)+cc.evaluate(contact+2))/2
        result.append(next(contact+i/1000 for i in range(2001) if cc.evaluate(contact+i/1000)<=midpoint)-contact)
    return result
assert all(abs(a-b)<.025 for a,b in zip(half_compression(v6),half_compression(v5)))
report=dict(action=v6.name,phase_frames=[1,3,5,7,9,11,13,15,17],fps=24,frame_range=[1,17],duration_seconds=16/24,timing_changes='Preserve Contact impact; Passing Hips 0.15/0.12 frame earlier, support-leg Passing 0.10 earlier, Spine/Chest recovery 0.06/0.10 earlier; rear arm extremes 0.10/0.12 earlier.',half_compression_frames_v5=half_compression(v5),half_compression_frames_v6=half_compression(v6),overlap_stride_offsets_frames={'Spine':.45,'Chest':.85,'Arm.L':1.20,'Arm.R':1.35,'Neck':1.45,'Head':1.75},local_rotation_ranges_degrees=ranges,world_rotation_ranges_degrees=world_ranges,hips_world_ranges_m=[[min(v[i] for v in hippos),max(v[i] for v in hippos)] for i in range(3)],root_travel_m=root_travel,hips_accumulated_horizontal_travel_m=horizontal,loop_matrix_mismatch=loop_error,loop_curve_slope_max_mismatch=tangent_error,ground_min_m=groundmin,maximum_ground_penetration_m=max(0,-groundmin),support_clearance_range_m=[supportmin,supportmax],maximum_leg_bottom_clearance_m=groundmax,maximum_both_legs_clearance_m=min_pair_max,max_additional_ground_correction_m=max_ground_adjust,max_rigid_length_error_m=rigid_error,max_rotation_change_per_32nd_frame_degrees=max_step,gaze_max_deviation_degrees=math.degrees(math.acos(min(1,gaze_min))),style_changes=dict(contact_leg_degrees={'Leg.L':[-38.8,31.3],'Leg.R':[-36.7,29.2]},rear_arm_gain=1.06,contact_chest_yaw_gain=1.06,contact_hips_yaw_gain=1.05,passing_recovery_abduction_added_degrees=[.55,.65],arm_outward_path_adjustment_degrees={'Arm.L':-.6,'Arm.R':-1.2},arm_left_twist_bias_degrees=.6,arm_twist_gain=.75,head_pitch_intent_added_degrees=.08,head_seam_lift_m=.003,up_height_increase_m=0),changed_curve_count=len(changed),intersections=clip,keys_before=old_count,keys_after=new_count,net_keys_removed=old_count-new_count,location_curve_key_counts={n:[len(curve(n,'location',i).keyframe_points) for i in range(3)] for n in ['Leg.L','Leg.R']},key_poses=details,all_previous_actions_unchanged=True,mesh_weights_rest_hierarchy_unchanged=True,production_unchanged=True,preview=[1,17])
report['unmodified_curve_count']=len(fcurves(v6))-len(changed)
(BASE/'player_run_blocky_v6_pass6_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PASS6_VALIDATION='+json.dumps(report),flush=True)
scene.frame_set(1);scene.use_preview_range=True;scene.frame_preview_start=1;scene.frame_preview_end=17
for n in ['Armature','Mixamo_Working']:
    if bpy.data.objects.get(n):bpy.data.objects[n].hide_set(True)
if bpy.app.background:
    out=BASE/'blocky_v6_pass6_review';out.mkdir(exist_ok=True)
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16;scene.cycles.use_denoising=True
    scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    # Dry-run-only camera for a front 3/4 view; never saved to the live test.
    front=bpy.data.objects['V3 Isometric Camera'].copy();front.data=front.data.copy();front.name='Pass6_Review_Front_Only';scene.collection.objects.link(front)
    front.location=(3.0,-5.5,2.8);front.rotation_euler=(Vector((0,0,.95))-front.location).to_track_quat('-Z','Y').to_euler();front.data.type='ORTHO';front.data.ortho_scale=2.4
    for view,camera in [('iso','V3 Isometric Camera'),('side','V3 Side Camera'),('front',front.name)]:
        scene.camera=bpy.data.objects[camera]
        for i,f in enumerate([1,3,5,7,9,11,13,15,17]):
            scene.frame_set(f);scene.render.filepath=str(out/f'{view}_{i:02d}.png');bpy.ops.render.render(write_still=True)
else:
    area=bpy.context.area
    for obj in bpy.context.selected_objects:obj.select_set(False)
    rig.hide_set(False);mesh.hide_set(False);rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
    if area and area.type=='CONSOLE':area.type='VIEW_3D'
    for view in bpy.context.screen.areas:
        region=next((r for r in view.regions if r.type=='WINDOW'),None)
        if region and view.type=='VIEW_3D':
            view.spaces.active.shading.type='MATERIAL';view.spaces.active.overlay.show_overlays=False
            with bpy.context.temp_override(area=view,region=region):bpy.ops.view3d.view_selected(use_all_regions=False)
    mesh.select_set(False)
    backup=BASE/'blocky_character_mixamo_test_before_blocky_v6.blend';assert not backup.exists(),'Never overwrite backup';shutil.copy2(TEST,backup)
    text=bpy.data.texts.new('Player_Run_Blocky_V6_Pass5_Report.json');text.write(json.dumps(report,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(TEST),check_existing=False)
    print('PASS6_SAVED_PREVIEW_READY',flush=True)




    # Bounded live review only: 24 FPS, then 12 FPS, restore 24 and stop at frame 1.
    # No action/key data changes during playback inspection.
    review_window=bpy.context.window;review_stage_state={'stage':0}
    def run_preview_review():
        try:
            assert Path(bpy.data.filepath)==TEST
            with bpy.context.temp_override(window=review_window):
                if review_window.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
                stage=review_stage_state['stage'];scene.frame_set(1)
                if stage<2:
                    scene.render.fps=24 if stage==0 else 12
                    bpy.ops.screen.animation_play();review_stage_state['stage']+=1
                    print('PASS6_REVIEW_FPS='+str(scene.render.fps),flush=True)
                    return 15.0
                scene.render.fps=24
                bpy.ops.wm.save_as_mainfile(filepath=str(TEST),check_existing=False)
                print('PASS6_REVIEW_DONE_24FPS_READY',flush=True)
            return None
        except Exception:
            scene.render.fps=24
            with bpy.context.temp_override(window=review_window):
                if review_window.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
            raise
    bpy.app.timers.register(run_preview_review,first_interval=.5)



