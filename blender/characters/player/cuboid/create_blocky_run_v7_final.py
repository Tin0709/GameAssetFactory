import bpy,math,json,ast,hashlib,shutil
from pathlib import Path
from mathutils import Vector,Matrix,Euler
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid');TEST=BASE/'blocky_character_mixamo_test.blend'
assert Path(bpy.data.filepath)==TEST
scene=bpy.context.scene;rig=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base'];NAME='Player_Run_Blocky_V7_Final'
assert scene.render.fps/scene.render.fps_base==24
if not bpy.app.background and bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
assert bpy.data.actions.get(NAME) is None,'Final already exists; never overwrite'
for file,names in [('prepare_mixamo_run.py',{'vv','mm','fcurves','action_signature','object_signature'}),('create_blocky_run_v2_pass2.py',{'sample','box_axes','overlap'})]:
 t=ast.parse((BASE/file).read_text(encoding='utf-8-sig'));exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),'QA_helpers','exec'))
v6=bpy.data.actions['Player_Run_Blocky_V6'];protected={a.name:action_signature(a) for a in bpy.data.actions}
geom=object_signature(mesh);structure=object_signature(rig);structure.pop('pose');structure.pop('action')
production_hash=hashlib.sha256((BASE/'player_cuboid_v6.blend').read_bytes()).hexdigest()
assert not rig.animation_data.nla_tracks and not any(p.constraints for p in rig.pose.bones)
if not bpy.app.background and bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
parts={g.name:[v.index for v in mesh.data.vertices if any(w.group==g.index and w.weight>.999 for w in v.groups)] for g in mesh.vertex_groups}
frames=[1+i/64 for i in range(1025)]
rig.animation_data.action=v6
if v6.slots:rig.animation_data.action_slot=v6.slots[0]
rig.pose.bones['Root'].matrix_basis=Matrix.Identity(4)
baseline={f:sample(f) for f in frames}
final=v6.copy();final.name=NAME;final.use_fake_user=True
rig.animation_data.action=final
if final.slots:rig.animation_data.action_slot=final.slots[0]
# Only unused constant-zero leg yaw channels are redundant. Preserve every authored changing curve.
removed=[]
for layer in final.layers:
 for strip in layer.strips:
  for bag in strip.channelbags:
   for c in list(bag.fcurves):
    if c.data_path in ['pose.bones["Leg.L"].rotation_euler','pose.bones["Leg.R"].rotation_euler'] and c.array_index==1:
     assert all(abs(k.co.y)<1e-9 and abs(k.handle_left.y)<1e-9 and abs(k.handle_right.y)<1e-9 for k in c.keyframe_points)
     removed.append(dict(path=c.data_path,index=1,key_count=len(c.keyframe_points)));bag.fcurves.remove(c)
for n in ['Leg.L','Leg.R']:rig.pose.bones[n].rotation_euler.y=0
assert len(removed)==2
final.use_frame_range=True;final.frame_start=1;final.frame_end=17
if hasattr(final,'use_cyclic'):final.use_cyclic=True
final['authoring_fps']=24;final['cycle_frames']=16;final['duration_seconds']=16/24;final['duplicate_endpoint_frame']=17
final['qa_source_action']='Player_Run_Blocky_V6';final['qa_status']='Blender QA; awaiting visual approval; not exported'
keep=[c for c in action_signature(v6)['curves'] if not (c['path'] in ['pose.bones["Leg.L"].rotation_euler','pose.bones["Leg.R"].rotation_euler'] and c['index']==1)]
assert keep==action_signature(final)['curves']
animated=['Hips','Leg.L','Leg.R','Spine','Chest','Arm.L','Arm.R','Neck','Head']
for c in fcurves(final):
 assert c.data_path.startswith('pose.bones[') and c.data_path.split('"')[1] in animated
 assert c.data_path.endswith('.location') or c.data_path.endswith('.rotation_euler')
 assert not c.mute and all(k.interpolation=='BEZIER' for k in c.keyframe_points)
 assert len({round(k.co.x,6) for k in c.keyframe_points})==len(c.keyframe_points)
 assert any(m.type=='CYCLES' and m.mode_before=='REPEAT' and m.mode_after=='REPEAT' for m in c.modifiers)
rest_lengths={(n,i,j):(mesh.matrix_world@(mesh.data.vertices[i].co-mesh.data.vertices[j].co)).length for n,ids in parts.items() for i in ids for j in ids if j>i}
roottravel=0;pose_difference=0;mesh_difference=0;rigid_error=0;groundmin=1e9;supportmin=1e9;supportmax=0;groundmax=0;clip={};hippos=[];angles=[];details=[]
world_ranges={n:[[1e9,-1e9] for _ in range(3)] for n in ['Chest','Head']};restrot=(rig.matrix_world@rig.data.bones['Chest'].matrix_local).to_3x3();gaze_min=1
for f in frames:
 mats,points=sample(f);bm,bp=baseline[f]
 pose_difference=max(pose_difference,max(abs(mats[n][i][j]-bm[n][i][j]) for n in mats for i in range(4) for j in range(4)))
 mesh_difference=max(mesh_difference,max((a-b).length for a,b in zip(points,bp)))
 rr=rig.matrix_world@rig.data.bones['Root'].matrix_local;roottravel=max(roottravel,(mats['Root'].translation-rr.translation).length)
 bottoms={n:min(points[i].z for i in parts[n]) for n in ['Leg.L','Leg.R']}
 groundmin=min(groundmin,min(bottoms.values()));groundmax=max(groundmax,max(bottoms.values()))
 for n,z in bottoms.items():
  if z<.0065:supportmin=min(supportmin,z);supportmax=max(supportmax,z)
 hippos.append(mats['Hips'].translation.copy())
 for (n,i,j),length in rest_lengths.items():rigid_error=max(rigid_error,abs((points[i]-points[j]).length-length))
 assert all(max(abs(v-1) for v in p.scale)<1e-7 for p in rig.pose.bones)
 for n in world_ranges:
  e=(restrot.inverted()@mats[n].to_3x3()).to_euler('XYZ')
  for i,v in enumerate(e):d=math.degrees(v);world_ranges[n][i][0]=min(world_ranges[n][i][0],d);world_ranges[n][i][1]=max(world_ranges[n][i][1],d)
 gaze_min=min(gaze_min,(mats['Head'].to_3x3()@Vector((0,0,1))).normalized().dot(Vector((0,-1,0))))
 angles.append({n:mats[n].to_quaternion() for n in animated})
 if f in [1,3,5,7,9,11,13,15,17]:
  def reach(n):return (mats[n].to_3x3()@Vector((0,1,0))).normalized().dot(Vector((0,-1,0)))
  details.append(dict(frame=f,leg_bottom_z_m=bottoms,forward_components={n:reach(n) for n in ['Leg.L','Leg.R','Arm.L','Arm.R']}))
 if round(f*64)%32==0:
  for a,b in [('Head','Chest'),('Head','Arm.L'),('Head','Arm.R'),('Arm.L','Chest'),('Arm.R','Chest'),('Chest','Leg.L'),('Chest','Leg.R')]:
   clip[a+' / '+b]=max(clip.get(a+' / '+b,0),overlap(a,b,points))
first,_=sample(1);last,_=sample(17)
loop=max(abs(first[n][i][j]-last[n][i][j]) for n in first for i in range(4) for j in range(4))
h=last['Hips'].translation-first['Hips'].translation
# Analytic channel velocities at each endpoint; never rewrite existing handles.
vels=[];slope_error=0
for c in fcurves(final):
 a,b=c.keyframe_points[0],c.keyframe_points[-1]
 start=(a.handle_right.y-a.co.y)/(a.handle_right.x-a.co.x);end=(b.co.y-b.handle_left.y)/(b.co.x-b.handle_left.x)
 assert abs(a.co.x-1)<1e-6 and abs(b.co.x-17)<1e-6 and abs(a.co.y-b.co.y)<1e-8
 slope_error=max(slope_error,abs(start-end));vels.append(dict(path=c.data_path,index=c.array_index,first_velocity=start,last_velocity=end,mismatch=abs(start-end)))
# Propagate endpoint values/rates through the actual hierarchy to verify world-space C1.
def endpoint_pose(end,dt):
 values={n:{'location':list(rig.pose.bones[n].location),'rotation_euler':list(rig.pose.bones[n].rotation_euler)} for n in rig.pose.bones.keys()}
 for c in fcurves(final):
  k=c.keyframe_points[-1] if end else c.keyframe_points[0]
  slope=(k.co.y-k.handle_left.y)/(k.co.x-k.handle_left.x) if end else (k.handle_right.y-k.co.y)/(k.handle_right.x-k.co.x)
  n=c.data_path.split('"')[1];prop=c.data_path.split('.')[-1];values[n][prop][c.array_index]=k.co.y+dt*slope
 out={}
 def depth(b):return 0 if not b.parent else 1+depth(b.parent)
 for b in sorted(rig.data.bones,key=depth):
  v=values[b.name];basis=Matrix.LocRotScale(Vector(v['location']),Euler(v['rotation_euler'],'XYZ').to_quaternion(),Vector((1,1,1)))
  if b.parent:out[b.name]=b.convert_local_to_pose(basis,b.matrix_local,parent_matrix=out[b.parent.name],parent_matrix_local=b.parent.matrix_local)
  else:out[b.name]=b.convert_local_to_pose(basis,b.matrix_local)
 return {n:rig.matrix_world@m for n,m in out.items()}
eps=.001;sp=endpoint_pose(False,eps);sm=endpoint_pose(False,-eps);ep=endpoint_pose(True,eps);em=endpoint_pose(True,-eps)
world_velocity_error=max(abs((sp[n][i][j]-sm[n][i][j]-ep[n][i][j]+em[n][i][j])/(2*eps)) for n in sp for i in range(4) for j in range(4))
# Repeat evaluation checks outside the authoring range through 15 -> 17 -> 19.
cyclic_error=0
for f in [15+i/16 for i in range(65)]:
 a,_=sample(f);b,_=sample(f-16)
 cyclic_error=max(cyclic_error,max(abs(a[n][i][j]-b[n][i][j]) for n in a for i in range(4) for j in range(4)))
max_step=max(min(math.degrees(a[n].rotation_difference(b[n]).angle),360-math.degrees(a[n].rotation_difference(b[n]).angle)) for a,b in zip(angles,angles[1:]) for n in animated)
for pose in details:
 d=pose['forward_components']
 if pose['frame'] in [1,17]:assert d['Leg.R']>0 and d['Arm.L']>0 and d['Leg.L']<0 and d['Arm.R']<0
 if pose['frame']==9:assert d['Leg.L']>0 and d['Arm.R']>0 and d['Leg.R']<0 and d['Arm.L']<0
assert pose_difference<1e-7 and mesh_difference<1e-7 and roottravel<1e-7 and h.length<1e-7
assert loop<1e-7 and slope_error<1e-6 and world_velocity_error<.0002 and cyclic_error<2e-6
assert groundmin>.002 and rigid_error<1e-5 and max_step<1 and gaze_min>.98
assert all((b-a)<(d-c)*.85 for (a,b),(c,d) in zip(world_ranges['Head'],world_ranges['Chest']))
assert protected=={n:action_signature(bpy.data.actions[n]) for n in protected}
assert geom==object_signature(mesh)
s=object_signature(rig);s.pop('pose');s.pop('action');assert structure==s
assert production_hash==hashlib.sha256((BASE/'player_cuboid_v6.blend').read_bytes()).hexdigest()
report=dict(action=NAME,source_action=v6.name,exact_differences='Copied V6; removed only 2 constant-zero Leg yaw curves (4 keys); added explicit 24-FPS/16-frame cycle metadata. No pose, timing, handle, or clipping corrections.',removed_redundant_channels=removed,redundant_keys_removed=sum(x['key_count'] for x in removed),accidental_channels_removed=0,curves_before=len(fcurves(v6)),curves_after=len(fcurves(final)),keys_before=sum(len(c.keyframe_points) for c in fcurves(v6)),keys_after=sum(len(c.keyframe_points) for c in fcurves(final)),animated_bones=animated,frame_range=[1,17],unique_playback_frames=[1,16],fps=24,duration_seconds=16/24,qa_sample_count=len(frames),qa_frame_step=1/64,v6_pose_max_matrix_difference=pose_difference,v6_mesh_max_position_difference_m=mesh_difference,root_travel_m=roottravel,hips_accumulated_world_travel_m=h.length,loop_pose_max_matrix_mismatch=loop,loop_channel_velocity_max_mismatch=slope_error,loop_world_matrix_velocity_max_mismatch_per_frame=world_velocity_error,cyclic_evaluation_max_matrix_mismatch=cyclic_error,endpoint_velocity_details=vels,minimum_leg_bottom_z_m=groundmin,maximum_ground_penetration_m=max(0,-groundmin),support_clearance_range_m=[supportmin,supportmax],maximum_recovery_clearance_m=groundmax,max_rigid_length_error_m=rigid_error,max_world_rotation_step_per_64th_frame_degrees=max_step,clipping_max_overlap_m=clip,clipping_corrected=False,world_rotation_ranges_degrees=world_ranges,gaze_max_deviation_degrees=math.degrees(math.acos(min(1,gaze_min))),key_poses=details,all_prior_actions_unchanged=True,production_unchanged=True,mesh_skinning_rest_hierarchy_lengths_unchanged=True,scale_or_object_or_root_or_unused_bone_animation_present=False,ready_for_godot_testing_after_visual_approval=True,exported=False)
(BASE/'player_run_blocky_v7_final_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PASS7_QA='+json.dumps({k:report[k] for k in ['action','v6_pose_max_matrix_difference','root_travel_m','hips_accumulated_world_travel_m','loop_pose_max_matrix_mismatch','loop_channel_velocity_max_mismatch','loop_world_matrix_velocity_max_mismatch_per_frame','cyclic_evaluation_max_matrix_mismatch','minimum_leg_bottom_z_m','redundant_keys_removed']}),flush=True)
scene.frame_set(1);scene.use_preview_range=True;scene.frame_preview_start=1;scene.frame_preview_end=17
for n in ['Armature','Mixamo_Working']:
 if bpy.data.objects.get(n):bpy.data.objects[n].hide_set(True)
if bpy.app.background:
 out=BASE/'blocky_v7_final_review';out.mkdir(exist_ok=True)
 scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16;scene.cycles.use_denoising=True
 scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
 front=bpy.data.objects['V3 Isometric Camera'].copy();front.data=front.data.copy();front.name='Final_Review_Front_Only';scene.collection.objects.link(front)
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
 backup=BASE/'blocky_character_mixamo_test_before_v7_final.blend';assert not backup.exists(),'Never overwrite backup';shutil.copy2(TEST,backup)
 text=bpy.data.texts.new('Player_Run_Blocky_V7_Final_QA.json');text.write(json.dumps(report,indent=2))
 bpy.ops.wm.save_as_mainfile(filepath=str(TEST),check_existing=False)
 review_window=bpy.context.window;review_state={'stage':0}
 def final_playback_qa():
  try:
   assert Path(bpy.data.filepath)==TEST
   with bpy.context.temp_override(window=review_window):
    if review_window.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
    stage=review_state['stage'];scene.frame_set(1)
    if stage<2:
     scene.frame_preview_end=16;scene.render.fps=24 if stage==0 else 12
     bpy.ops.screen.animation_play();review_state['stage']+=1
     return 15.0
    scene.render.fps=24;scene.frame_preview_end=17
    report['playback_qa']=dict(normal_fps=24,half_speed_fps=12,normal_seconds=15,normal_cycles_at_least=10,unique_frames=[1,16],final_authoring_preview=[1,17])
    (BASE/'player_run_blocky_v7_final_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8');text.clear();text.write(json.dumps(report,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(TEST),check_existing=False)
    print('PASS7_FINAL_QA_SAVED_24FPS_READY',flush=True)
   return None
  except Exception:
   scene.render.fps=24;scene.frame_preview_end=17
   with bpy.context.temp_override(window=review_window):
    if review_window.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
   raise
 bpy.app.timers.register(final_playback_qa,first_interval=.5)
