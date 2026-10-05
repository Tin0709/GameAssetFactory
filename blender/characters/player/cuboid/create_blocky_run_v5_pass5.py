import bpy,math,json,ast,hashlib,shutil
from pathlib import Path
from mathutils import Vector,Matrix,Euler
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid');TEST=BASE/'blocky_character_mixamo_test.blend'
assert Path(bpy.data.filepath)==TEST
scene=bpy.context.scene;rig=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base']
assert scene.render.fps/scene.render.fps_base==24
if not bpy.app.background and bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
assert bpy.data.actions.get('Player_Run_Blocky_V5') is None,'V5 exists; never overwrite'
for file,names in [('prepare_mixamo_run.py',{'vv','mm','fcurves','action_signature','object_signature'}),('create_blocky_run_v2_pass2.py',{'sample','box_axes','overlap'})]:
    tree=ast.parse((BASE/file).read_text(encoding='utf-8-sig'))
    exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),'snapshot_eval_helpers','exec'))
v4=bpy.data.actions['Player_Run_Blocky_V4'];protected={a.name:action_signature(a) for a in bpy.data.actions}
geom=object_signature(mesh);structure=object_signature(rig);structure.pop('pose');structure.pop('action')
production_hash=hashlib.sha256((BASE/'player_cuboid_v6.blend').read_bytes()).hexdigest()
assert not rig.animation_data.nla_tracks and not any(p.constraints for p in rig.pose.bones)
if not bpy.app.background and bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
parts={g.name:[v.index for v in mesh.data.vertices if any(w.group==g.index and w.weight>.999 for w in v.groups)] for g in mesh.vertex_groups}
frames=[1+i/32 for i in range(513)]
rig.animation_data.action=v4
if v4.slots:rig.animation_data.action_slot=v4.slots[0]
rig.pose.bones['Root'].matrix_basis=Matrix.Identity(4)
baseline={f:sample(f) for f in frames}
old_count=sum(len(c.keyframe_points) for c in fcurves(v4));v5=v4.copy();v5.name='Player_Run_Blocky_V5';v5.use_fake_user=True
rig.animation_data.action=v5
if v5.slots:rig.animation_data.action_slot=v5.slots[0]
def bone_name(c):return c.data_path.split('"')[1]
def curve(n,prop,i):return next(c for c in fcurves(v5) if c.data_path==f'pose.bones["{n}"].{prop}' and c.array_index==i)
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
# Keep all principal phase frames. Small progressive overlap adjustments, not a new run.
shift={'Spine':-.10,'Chest':-.10,'Arm.L':.05,'Arm.R':0.,'Neck':.05,'Head':.05}
for c in fcurves(v5):
    n=bone_name(c)
    if n.startswith('Leg.') and c.data_path.endswith('location'):continue
    for k in c.keyframe_points:
        if 1<k.co.x<17 and n in shift:k.co.x+=shift[n]
    # Restrained contact absorption / balance and arm silhouette adjustments.
    if n=='Hips':
        for k in c.keyframe_points:
            phase=(k.co.x-1)%8
            if c.data_path.endswith('rotation_euler') and c.array_index==0:
                k.co.y=math.radians(1.45 if abs(phase-2)<.01 else 1.10 if abs(phase-6)<.01 else 1.20)
            if c.data_path.endswith('location'):
                if c.array_index==0:k.co.y*=.96
                if c.array_index==1 and abs(phase-6)<.01:k.co.y-=.0015
    if n in ['Spine','Chest'] and c.array_index==0:
        for k in c.keyframe_points:
            original_phase=(k.co.x-shift[n]-1)%8
            if abs(original_phase-(.55 if n=='Spine' else .95)-2)<.02:k.co.y+=math.radians(.10 if n=='Spine' else .08)
    if n.startswith('Arm.'):
        if c.array_index==0:
            for k in c.keyframe_points:k.co.y*=.988
        if c.array_index==2:
            for k in c.keyframe_points:k.co.y+=math.radians(.4 if n=='Arm.L' else -.4)
    if n in ['Neck','Head'] and c.array_index==0:
        for k in c.keyframe_points:
            offset=1.4 if n=='Neck' else 1.7
            if abs((k.co.x-shift[n]-1)%8-offset-2)<.02:k.co.y-=math.radians(.16 if n=='Neck' else .09)
    # Remove interior keys on truly constant channels; retain safe explicit constants.
    if max(k.co.y for k in c.keyframe_points)-min(k.co.y for k in c.keyframe_points)<1e-8:
        replace_keys(c,[(1,c.keyframe_points[0].co.y),(17,c.keyframe_points[0].co.y)])
    tangents(c)
# Very small late-compression settling keys, while the labelled Down poses stay at 3/11.
z=curve('Hips','location',1)
for f,down in [(2.72,3),(10.78,11)]:z.keyframe_points.insert(f,z.evaluate(down)+.00045)
z.update();tangents(z)
# Preserve the rigid support/recovery arrangement with small measured vertical corrections.
# Sparse approximation is checked to 0.45 mm vertical / 0.12 mm transverse local error; no dense new bake.
desired={n:[] for n in ['Leg.L','Leg.R']};max_ground_adjust=0
for f in frames:
    mats,points=sample(f);bm,bp=baseline[f]
    for n in desired:
        old_z=min(bp[i].z for i in parts[n]);new_z=min(points[i].z for i in parts[n])
        target=.003+.96*max(0,old_z-.003)
        delta=target-new_z;max_ground_adjust=max(max_ground_adjust,abs(delta))
        p=rig.pose.bones[n];b=p.bone
        ref=b.convert_local_to_pose(Matrix.Identity(4),b.matrix_local,parent_matrix=p.parent.matrix,parent_matrix_local=p.parent.bone.matrix_local)
        local_delta=(rig.matrix_world@ref).to_3x3().inverted()@Vector((0,0,delta))
        desired[n].append((f,tuple(p.location+local_delta)))
for n in desired:
    desired[n][-1]=(17.,desired[n][0][1])
    for axis in range(3):
        c=curve(n,'location',axis);data=[(f,v[axis]) for f,v in desired[n]]
        # Adaptive, error bounded key reduction against the measured contact solution.
        chosen={0,len(data)-1}|{i for i,(f,v) in enumerate(data) if f in [3,5,7,9,11,13,15]}
        for iteration in range(100):
            replace_keys(c,[data[i] for i in sorted(chosen)]);tangents(c)
            error,index=max((abs(c.evaluate(f)-v),i) for i,(f,v) in enumerate(data))
            if error<=(.00045 if axis==1 else .00012):break
            chosen.add(index)
        assert error<=(.00045 if axis==1 else .00012),(n,axis,error)
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
                stat=clip.setdefault(a+' / '+b,dict(max_overlap_m=0,baseline_max_overlap_m=0,max_increase_from_v4_m=0));stat['max_overlap_m']=max(stat['max_overlap_m'],d);stat['baseline_max_overlap_m']=max(stat['baseline_max_overlap_m'],bd);stat['max_increase_from_v4_m']=max(stat['max_increase_from_v4_m'],d-bd)
    angles.append({n:mats[n].to_quaternion() for n in animated})
    if f in [1,3,5,7,9,11,13,15,17]:
        def reach(n):return (mats[n].to_3x3()@Vector((0,1,0))).normalized().dot(Vector((0,-1,0)))
        details.append(dict(frame=f,hips_world=vv(mats['Hips'].translation),leg_bottom_z_m=bottoms,arm_leg_forward_component={n:reach(n) for n in ['Arm.L','Arm.R','Leg.L','Leg.R']}))
first,_=sample(1);last,_=sample(17)
loop_error=max(abs(first[n][i][j]-last[n][i][j]) for n in first for i in range(4) for j in range(4))
h=last['Hips'].translation-first['Hips'].translation;horizontal=math.hypot(h.x,h.y)
max_step=max(min(math.degrees(a[n].rotation_difference(b[n]).angle),360-math.degrees(a[n].rotation_difference(b[n]).angle)) for a,b in zip(angles,angles[1:]) for n in animated)
tangent_error=0
for c in fcurves(v5):
    a,b=c.keyframe_points[0],c.keyframe_points[-1]
    sa=(a.handle_right.y-a.co.y)/(a.handle_right.x-a.co.x);sb=(b.co.y-b.handle_left.y)/(b.co.x-b.handle_left.x)
    tangent_error=max(tangent_error,abs(sa-sb))
new_count=sum(len(c.keyframe_points) for c in fcurves(v5))
for pose in details:
    d=pose['arm_leg_forward_component']
    if pose['frame'] in [1,17]:assert d['Arm.L']>0 and d['Leg.R']>0 and d['Arm.R']<0 and d['Leg.L']<0
    if pose['frame']==9:assert d['Arm.R']>0 and d['Leg.L']>0 and d['Arm.L']<0 and d['Leg.R']<0
assert root_travel<1e-7 and horizontal<1e-7 and loop_error<1e-7 and tangent_error<2e-5
assert groundmin>0 and supportmax<.0065 and rigid_error<1e-5 and max_step<2 and gaze_min>.98
assert max_ground_adjust<.025,max_ground_adjust
assert all((b-a)<(d-c)*.85 for (a,b),(c,d) in zip(world_ranges['Head'],world_ranges['Chest']))
assert not any('.scale' in c.data_path for c in fcurves(v5)) and new_count<old_count
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
assert all(a<b for a,b in zip(half_compression(v5),half_compression(v4))),(half_compression(v5),half_compression(v4))
report=dict(action=v5.name,phase_frames=[1,3,5,7,9,11,13,15,17],fps=24,frame_range=[1,17],duration_seconds=16/24,timing_changes='Spine/Chest 0.10 frame earlier; Arm.L +0.05; Neck/Head +0.05. Contact settling at 2.72/10.78; extended Up tangents.',half_compression_frames_v4=half_compression(v4),half_compression_frames_v5=half_compression(v5),overlap_stride_offsets_frames={'Spine':.45,'Chest':.85,'Arm.L':1.20,'Arm.R':1.35,'Neck':1.45,'Head':1.75},local_rotation_ranges_degrees=ranges,world_rotation_ranges_degrees=world_ranges,hips_world_ranges_m=[[min(v[i] for v in hippos),max(v[i] for v in hippos)] for i in range(3)],root_travel_m=root_travel,hips_accumulated_horizontal_travel_m=horizontal,loop_matrix_mismatch=loop_error,loop_curve_slope_max_mismatch=tangent_error,ground_min_m=groundmin,maximum_ground_penetration_m=max(0,-groundmin),support_clearance_range_m=[supportmin,supportmax],maximum_leg_bottom_clearance_m=groundmax,maximum_both_legs_clearance_m=min_pair_max,max_additional_ground_correction_m=max_ground_adjust,max_rigid_length_error_m=rigid_error,max_rotation_change_per_32nd_frame_degrees=max_step,gaze_max_deviation_degrees=math.degrees(math.acos(min(1,gaze_min))),intersections=clip,keys_before=old_count,keys_after=new_count,net_keys_removed=old_count-new_count,location_curve_key_counts={n:[len(curve(n,'location',i).keyframe_points) for i in range(3)] for n in ['Leg.L','Leg.R']},key_poses=details,all_previous_actions_unchanged=True,mesh_weights_rest_hierarchy_unchanged=True,production_unchanged=True,preview=[1,17])
(BASE/'player_run_blocky_v5_pass5_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PASS5_VALIDATION='+json.dumps(report),flush=True)
scene.frame_set(1);scene.use_preview_range=True;scene.frame_preview_start=1;scene.frame_preview_end=17
for n in ['Armature','Mixamo_Working']:
    if bpy.data.objects.get(n):bpy.data.objects[n].hide_set(True)
if bpy.app.background:
    out=BASE/'blocky_v5_pass5_review';out.mkdir(exist_ok=True)
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16;scene.cycles.use_denoising=True
    scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    for view,camera in [('iso','V3 Isometric Camera'),('side','V3 Side Camera')]:
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
    backup=BASE/'blocky_character_mixamo_test_before_blocky_v5.blend';assert not backup.exists(),'Never overwrite backup';shutil.copy2(TEST,backup)
    text=bpy.data.texts.new('Player_Run_Blocky_V5_Pass5_Report.json');text.write(json.dumps(report,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(TEST),check_existing=False)
    print('PASS5_SAVED_PREVIEW_READY',flush=True)




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
                    print('PASS5_REVIEW_FPS='+str(scene.render.fps),flush=True)
                    return 6.0
                scene.render.fps=24
                bpy.ops.wm.save_as_mainfile(filepath=str(TEST),check_existing=False)
                print('PASS5_REVIEW_DONE_24FPS_READY',flush=True)
            return None
        except Exception:
            scene.render.fps=24
            with bpy.context.temp_override(window=review_window):
                if review_window.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
            raise
    bpy.app.timers.register(run_preview_review,first_interval=.5)
