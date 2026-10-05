import bpy,math,json,ast,hashlib,shutil
from pathlib import Path
from mathutils import Vector,Matrix,Euler
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid');TEST=BASE/'blocky_character_mixamo_test.blend'
assert Path(bpy.data.filepath)==TEST
scene=bpy.context.scene;rig=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base']
assert scene.render.fps/scene.render.fps_base==24
if not bpy.app.background and bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
assert bpy.data.actions.get('Player_Run_Blocky_V4') is None,'V4 exists; never overwrite'
for file,names in [('prepare_mixamo_run.py',{'vv','mm','fcurves','action_signature','object_signature'}),('create_blocky_run_v2_pass2.py',{'sample','box_axes','overlap'})]:
    tree=ast.parse((BASE/file).read_text(encoding='utf-8-sig'))
    exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),'snapshot_eval_helpers','exec'))
v3=bpy.data.actions['Player_Run_Blocky_V3'];protected={a.name:action_signature(a) for a in bpy.data.actions}
geom=object_signature(mesh);structure=object_signature(rig);structure.pop('pose');structure.pop('action')
production_hash=hashlib.sha256((BASE/'player_cuboid_v6.blend').read_bytes()).hexdigest()
assert not rig.animation_data.nla_tracks and not any(p.constraints for p in rig.pose.bones)
if not bpy.app.background and bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
axes={n:[vv((rig.matrix_world@rig.data.bones[n].matrix_local).to_3x3().col[i]) for i in range(3)] for n in ['Neck','Head']}
for n in axes:
    assert Vector(axes[n][0]).dot(Vector((1,0,0)))>.999 and Vector(axes[n][1]).dot(Vector((0,0,1)))>.999
    assert rig.pose.bones[n].rotation_mode=='XYZ'
parts={g.name:[v.index for v in mesh.data.vertices if any(w.group==g.index and w.weight>.999 for w in v.groups)] for g in mesh.vertex_groups}
frames=[1+i*.125 for i in range(129)]
rig.animation_data.action=v3
if v3.slots:rig.animation_data.action_slot=v3.slots[0]
for n in ['Root','Neck','Head']:rig.pose.bones[n].matrix_basis=Matrix.Identity(4)
baseline={f:sample(f) for f in frames}
restrot=(rig.matrix_world@rig.data.bones['Chest'].matrix_local).to_3x3()
def wrapped(f):return 1+(f-1)%16
def chest_delta(frame):
    mats,_=sample(wrapped(frame))
    return (restrot.inverted()@mats['Chest'].to_3x3()).to_euler('XYZ')
# Independent small offsets / gains leave substantial torso rhythm visible in world space.
# Positive local Y is world-up yaw. No world-space rotation copying or rest edits.
delays={'Neck':.45,'Head':.75}
gains={'Neck':(-.28,-.43,-.34),'Head':(-.18,-.25,-.24)}
imperfections={'Neck':[[.07,.10,.02,-.04,-.05,-.08,.01,.03],[.04,.07,.03,-.03,-.08,-.03,.01,.02],[.03,.04,.00,-.02,-.03,-.01,.01,.02]],'Head':[[.03,.05,.00,-.03,-.04,-.02,.02,.04],[.02,.04,.01,-.02,-.05,-.01,.00,.03],[.01,.02,.00,-.01,-.02,-.01,.01,.02]]}
def small_at(values,phase):
    u=(wrapped(phase)-1)/2;i=int(u)%8;t=u-int(u);s=t*t*(3-2*t)
    return values[i]*(1-s)+values[(i+1)%8]*s
# Evaluate the untouched V3 at delayed phases BEFORE assigning the new action.
key_values={}
for n in delays:
    offset=.95+delays[n]
    keys=sorted({1.,17.}|{1+2*i+offset for i in range(8) if 1+2*i+offset<17})
    key_values[n]=[(f,tuple(chest_delta(f-delays[n])[i]*gains[n][i]+math.radians(small_at(imperfections[n][i],f-offset)) for i in range(3))) for f in keys]
    key_values[n][-1]=(17.,key_values[n][0][1])
v4=v3.copy();v4.name='Player_Run_Blocky_V4';v4.use_fake_user=True
rig.animation_data.action=v4
if v4.slots:rig.animation_data.action_slot=v4.slots[0]
for n,keys in key_values.items():
    p=rig.pose.bones[n];assert tuple(p.location)==(0,0,0) and tuple(p.scale)==(1,1,1)
    for f,values in keys:p.rotation_euler=Euler(values,'XYZ');p.keyframe_insert(data_path='rotation_euler',frame=f,group=n)
# A bounded +/-3 mm Head local-Y correction gently reduces inherited vertical bob.
# It does not alter Hips/Chest or remove the natural run bounce.
hip_low=min(m['Hips'].translation.z for m,_ in baseline.values());hip_high=max(m['Hips'].translation.z for m,_ in baseline.values())
head_y_first=None
for f,_ in key_values['Head']:
    mats,_=sample(f);u=(mats['Hips'].translation.z-hip_low)/(hip_high-hip_low)
    y=.003*(1-2*u)
    if f==1:head_y_first=y
    if f==17:y=head_y_first
    rig.pose.bones['Head'].location.y=y
    rig.pose.bones['Head'].keyframe_insert(data_path='location',index=1,frame=f,group='Head')
for c in fcurves(v4):
    if not any('"'+n+'"' in c.data_path for n in delays):continue
    for k in c.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
    c.update();keys=c.keyframe_points;first,last=keys[0],keys[-1];last.co.y=first.co.y
    prev,nxt=keys[-2],keys[1];dt0=first.co.x-(prev.co.x-16);dt1=nxt.co.x-first.co.x
    slope=(nxt.co.y-prev.co.y)/(dt0+dt1)
    if (first.co.y-prev.co.y)*(nxt.co.y-first.co.y)<=0:slope=0
    for k in [first,last]:
        k.handle_left_type='FREE';k.handle_right_type='FREE'
        k.handle_left=(k.co.x-dt0/3,k.co.y-slope*dt0/3);k.handle_right=(k.co.x+dt1/3,k.co.y+slope*dt1/3)
    m=c.modifiers.new('CYCLES');m.mode_before='REPEAT';m.mode_after='REPEAT';c.update()
rig.pose.bones['Root'].matrix_basis=Matrix.Identity(4)
assert [c for c in action_signature(v4)['curves'] if not any('"'+n+'"' in c['path'] for n in delays)]==action_signature(v3)['curves']
assert len(fcurves(v4))==37
rest_lengths={(n,i,j):(mesh.matrix_world@(mesh.data.vertices[i].co-mesh.data.vertices[j].co)).length for n,ids in parts.items() for i in ids for j in ids if j>i}
ranges={n:[[1e9,-1e9] for i in range(3)] for n in delays};world_ranges={n:[[1e9,-1e9] for i in range(3)] for n in ['Chest','Head']}
unchanged_error=0;root_travel=0;rigid_error=0;groundmin=1e9;clip={};angles=[];details=[];gaze_min=1.;heights={n:[] for n in ['Hips','Chest','Head']}
for f in frames:
    mats,points=sample(f);bm,bp=baseline[f]
    for n in ['Root','Hips','Leg.L','Leg.R','Spine','Chest','Arm.L','Arm.R']:
        unchanged_error=max(unchanged_error,max(abs(mats[n][i][j]-bm[n][i][j]) for i in range(4) for j in range(4)))
    root_ref=rig.matrix_world@rig.data.bones['Root'].matrix_local;root_travel=max(root_travel,(mats['Root'].translation-root_ref.translation).length)
    groundmin=min(groundmin,min(points[i].z for n in ['Leg.L','Leg.R'] for i in parts[n]))
    for (n,i,j),length in rest_lengths.items():rigid_error=max(rigid_error,abs((points[i]-points[j]).length-length))
    assert all(max(abs(v-1) for v in p.scale)<1e-7 for p in rig.pose.bones)
    for n in ranges:
        for i,v in enumerate(rig.pose.bones[n].rotation_euler):
            d=math.degrees(v);ranges[n][i][0]=min(ranges[n][i][0],d);ranges[n][i][1]=max(ranges[n][i][1],d)
    for n in world_ranges:
        e=(restrot.inverted()@mats[n].to_3x3()).to_euler('XYZ')
        for i,v in enumerate(e):d=math.degrees(v);world_ranges[n][i][0]=min(world_ranges[n][i][0],d);world_ranges[n][i][1]=max(world_ranges[n][i][1],d)
    gaze=(mats['Head'].to_3x3()@Vector((0,0,1))).normalized();gaze_min=min(gaze_min,gaze.dot(Vector((0,-1,0))))
    for n in heights:
        ids=parts.get(n,[])
        if ids:heights[n].append(sum(points[i].z for i in ids)/len(ids))
        else:heights[n].append(mats[n].translation.z)
    for body in ['Chest','Arm.L','Arm.R']:
        d=overlap('Head',body,points);bd=overlap('Head',body,bp)
        if d:
            s=clip.setdefault('Head / '+body,dict(sample_count=0,max_overlap_m=0,baseline_max_overlap_m=0,max_increase_from_v3_m=0))
            s['sample_count']+=1;s['max_overlap_m']=max(s['max_overlap_m'],d);s['baseline_max_overlap_m']=max(s['baseline_max_overlap_m'],bd);s['max_increase_from_v3_m']=max(s['max_increase_from_v3_m'],d-bd)
    angles.append({n:mats[n].to_quaternion() for n in delays})
    if f in [1,3,5,7,9,11,13,15,17]:details.append(dict(frame=f,local_rotation_degrees={n:[math.degrees(v) for v in rig.pose.bones[n].rotation_euler] for n in delays},gaze_forward_dot=gaze.dot(Vector((0,-1,0)))))
first,_=sample(1);last,_=sample(17)
loop_error=max(abs(first[n][i][j]-last[n][i][j]) for n in first for i in range(4) for j in range(4))
h=last['Hips'].translation-first['Hips'].translation;horizontal=math.hypot(h.x,h.y)
max_step=max(min(math.degrees(a[n].rotation_difference(b[n]).angle),360-math.degrees(a[n].rotation_difference(b[n]).angle)) for a,b in zip(angles,angles[1:]) for n in delays)
head_span=[b-a for a,b in world_ranges['Head']];chest_span=[b-a for a,b in world_ranges['Chest']]
assert unchanged_error<1e-7 and root_travel<1e-7 and horizontal<1e-7 and loop_error<1e-7
assert groundmin>0 and rigid_error<1e-5 and max_step<1.0 and gaze_min>.98
assert all(h<c*.8 for h,c in zip(head_span,chest_span)),(head_span,chest_span)
assert max(heights['Head'])-min(heights['Head']) < max(heights['Chest'])-min(heights['Chest'])
assert not any('.scale' in c.data_path for c in fcurves(v4))
assert protected=={n:action_signature(bpy.data.actions[n]) for n in protected}
assert geom==object_signature(mesh)
s=object_signature(rig);s.pop('pose');s.pop('action');assert s==structure
assert production_hash==hashlib.sha256((BASE/'player_cuboid_v6.blend').read_bytes()).hexdigest()
report=dict(action=v4.name,bones_added=list(delays),local_axes=axes,local_rotation_ranges_degrees=ranges,timing_offsets_behind_chest_frames=delays,absolute_stride_key_offsets_frames={n:.95+d for n,d in delays.items()},compensation_gains=gains,world_rotation_ranges_degrees=world_ranges,angular_span_reduction_percent=[100*(1-h/c) for h,c in zip(head_span,chest_span)],gaze_max_deviation_degrees=math.degrees(math.acos(min(1,gaze_min))),explicit_translation_used=True,head_local_y_translation_range_m=[min(c.evaluate(f) for f in frames) for c in fcurves(v4) if c.data_path=='pose.bones["Head"].location']+[max(c.evaluate(f) for f in frames) for c in fcurves(v4) if c.data_path=='pose.bones["Head"].location'],vertical_center_range_m={n:[min(v),max(v)] for n,v in heights.items()},root_travel_m=root_travel,hips_accumulated_horizontal_travel_m=horizontal,existing_bone_matrix_max_difference=unchanged_error,loop_matrix_mismatch=loop_error,minimum_leg_bottom_z_m=groundmin,ground_penetration_m=max(0,-groundmin),max_rigid_length_error_m=rigid_error,max_rotation_change_per_eighth_frame_degrees=max_step,head_intersections=clip,neck_chest_check='Neck has no weighted mesh vertices; inspect pivot and connected Head/Chest geometry',keys_per_bone={n:len(v) for n,v in key_values.items()},key_poses=details,support_edits=[],all_previous_actions_unchanged=True,mesh_weights_rest_hierarchy_unchanged=True,production_unchanged=True,preview=[1,17],fps=24)
(BASE/'player_run_blocky_v4_pass4_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PASS4_VALIDATION='+json.dumps(report),flush=True)
scene.frame_set(1);scene.use_preview_range=True;scene.frame_preview_start=1;scene.frame_preview_end=17
for n in ['Armature','Mixamo_Working']:
    if bpy.data.objects.get(n):bpy.data.objects[n].hide_set(True)
if bpy.app.background:
    out=BASE/'blocky_v4_pass4_review';out.mkdir(exist_ok=True)
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
    backup=BASE/'blocky_character_mixamo_test_before_blocky_v4.blend';assert not backup.exists(),'Never overwrite backup';shutil.copy2(TEST,backup)
    text=bpy.data.texts.new('Player_Run_Blocky_V4_Pass4_Report.json');text.write(json.dumps(report,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(TEST),check_existing=False)
    print('PASS4_SAVED_PREVIEW_READY',flush=True)
