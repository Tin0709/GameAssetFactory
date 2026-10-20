extends SceneTree
## Real scene regression: held fire must outlive magazine-sized bursts, stop on
## release/focus loss, retain contacts in motion, and never allocate per shot.
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
 if not ok and not failures.has(label):failures.append(label);push_error(label)
func difference(a: Transform3D,b: Transform3D) -> float:
 return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var fps:=60 if OS.get_cmdline_user_args().has("60") else 30
 var dt:=1./fps
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
 check(scene.get("rifle_fire")!=null,"LMB continuous fire exists in the SAME research scene")
 if not failures.is_empty():scene.free();quit(1);return
 var control=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(control)
 var a=scene.player;var v=a.visual;var gun=scene.rifle_fire
 scene.set_process(false);a.set_physics_process(false);v.set_process(false);gun.set_physics_process(false)
 control.set_process(false);control.player.set_physics_process(false);control.player.visual.set_process(false);control.rifle_fire.set_physics_process(false)
 check(absf(a.walk_speed-2.70)<.001 and absf(a.run_speed-7.55)<.01,"Approved travel speeds retained")
 check(v.rifle_recoil_clip.clip.resource_name=="Rifle_Fire_Recoil_ActionsStyle_v001","Exact approved recoil selected")
 check(v.rifle_recoil_profile.clips.Recoil.action_sha256=="a0d88c8b85796cc670b7495de7ad4b86b3a4d3bd380c811a46eaca5ce97bd277","Latest1.5x source pin")
 var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;scene._unhandled_input(press)
 check(gun.trigger_held,"LMB press fires without requiring RMB")
 var children_before:=root.get_child_count(true);var pool_before: int=gun.get_child_count()
 for i in int(20.*fps):gun.tick(dt)
 check(gun.shots_fired==120,"Held fire remains uninterrupted across120shots, no reload or magazine limit: "+str(gun.shots_fired))
 check(gun.pool_misses==0,"Continuous fire never exhausts its fixed pools")
 check(gun.get_child_count()==pool_before and root.get_child_count(true)==children_before,"No per-shot nodes accumulate")
 press.pressed=false;scene._unhandled_input(press);var stopped: int=gun.shots_fired
 for i in fps:gun.tick(dt)
 check(gun.shots_fired==stopped,"LMB release stops new shots")
 gun.set_trigger(true)
 check(scene.has_method("_input"),"Mouse release is caught before a HUD can consume it")
 if scene.has_method("_input"):scene._input(press);check(not gun.trigger_held,"LMB release over UI cannot leave firing stuck")
 gun.set_trigger(false)
 # Rapid clicks must not bypass cooldown; a long stall must not emit a backlog.
 for i in 8:gun.set_trigger(true);gun.tick(.001);gun.set_trigger(false);gun.tick(.001)
 check(gun.shots_fired<=stopped+1,"Click spam obeys the same rate limit")
 gun.set_trigger(true);var before_stall: int=gun.shots_fired;gun.tick(2.)
 check(gun.shots_fired==before_stall+1,"A stalled frame emits at most one shot")
 scene.reset_player();check(not gun.trigger_held and gun.active_projectiles()==0,"Reset cancels firing and pooled projectiles")
 # Repeated recoil while using real Ready/Aim, gait, direction and jump layers.
 control.reset_player()
 var grip_error:=0.;var support_error:=0.;var lower_error:=0.;var recovered_error:=0.;var saw_air:=false;var saw_run:=false;var previous_camera: float=scene.camera_anchor.y;var camera_span:=0.
 var palm:=Vector3(v.rifle_profile.palm_forearm_local[0],v.rifle_profile.palm_forearm_local[1],v.rifle_profile.palm_forearm_local[2])
 gun.set_trigger(true)
 for i in int(8.*fps):
  var t:=i*dt;var moving:=t>1. and t<7.;var running:=t>3. and t<6.;v.set_rifle_aim(t>.3 and t<6.5)
  var direction:=Vector3(sin(t*5.),0.,-cos(t*5.))
  a.velocity=direction*(a.run_speed if running else a.walk_speed) if moving else Vector3.ZERO;a.position+=a.velocity*dt
  var jt:=t-4.5;var air:=jt>0. and jt<.74;a.position.y=maxf(0.,6.66*jt-9.*jt*jt) if air else 0.
  v.drive_jump_motion(a.velocity,moving,{"grounded":not air,"body_position":a.position,"vertical_speed":6.66-18.*jt if air else 0.,"takeoff":absf(jt)<dt*.5,"sprinting":running},dt);gun.tick(dt)
  control.player.position=a.position;control.player.velocity=a.velocity
  var cv=control.player.visual;cv.set_rifle_aim(t>.3 and t<6.5)
  cv.drive_jump_motion(a.velocity,moving,{"grounded":not air,"body_position":a.position,"vertical_speed":6.66-18.*jt if air else 0.,"takeoff":absf(jt)<dt*.5,"sprinting":running},dt)
  for bone_name in ["Root","Hips","Leg.L","Leg.R"]:
   var bone: int=v.skeleton.find_bone(bone_name);lower_error=maxf(lower_error,difference(v.skeleton.get_bone_pose(bone),cv.skeleton.get_bone_pose(bone)))
  var rig: Skeleton3D=v.skeleton
  grip_error=maxf(grip_error,difference(rig.get_bone_global_pose(v.arm_right).affine_inverse()*rig.get_bone_global_pose(v.carrier_bone),v.rifle_carrier_attachment))
  support_error=maxf(support_error,(rig.get_bone_global_pose(v.forearm_left)*palm).distance_to(rig.get_bone_global_pose(v.carrier_bone)*v.rifle_support_anchor))
  for alpha in [0.,.5,1.]:
   scene.presentation.prepare(alpha)
   var poses: Array=scene.presentation.display_world
   var attachment:=Transform3D(scene.presentation.previous.rifle_attachment).interpolate_with(scene.presentation.current.rifle_attachment,alpha)
   grip_error=maxf(grip_error,difference(Transform3D(poses[v.arm_right]).affine_inverse()*Transform3D(poses[v.carrier_bone]),attachment))
  saw_air=saw_air or not v.jump_grounded;saw_run=saw_run or v.gait_run_weight>.98
  if t>4.4 and t<5.4:scene._update_camera(dt,a.position);camera_span=maxf(camera_span,absf(scene.camera_anchor.y-previous_camera))
 check(saw_air and saw_run,"Held fire does not block Run or Jump")
 check(grip_error<.00005 and support_error<.00005,"Synchronized weapon/grips through physics and render: "+str([grip_error,support_error]))
 check(camera_span<.03,"Firing adds no camera kick/bob")
 check(lower_error<.00001,"Recoil never alters approved gait/pelvis/legs: "+str(lower_error))
 gun.set_trigger(false);v.set_rifle_aim(true)
 control.player.visual.set_rifle_aim(true)
 for i in fps:
  var context:={"grounded":true,"body_position":a.position,"vertical_speed":0.,"takeoff":false,"sprinting":false}
  v.drive_jump_motion(Vector3.ZERO,false,context,dt);control.player.visual.drive_jump_motion(Vector3.ZERO,false,context,dt);gun.tick(dt)
 for bone in v._aim_bones:recovered_error=maxf(recovered_error,difference(v.skeleton.get_bone_pose(bone),control.player.visual.skeleton.get_bone_pose(bone)))
 check(recovered_error<.00005,"After sustained fire the whole upper body matches never-fired control: "+str(recovered_error))
 check(v.rifle_recoil_time>=1./6.,"Last recoil recovers after release")
 var recovered: Array=[]
 for bone in v._aim_bones:recovered.append(v.skeleton.get_bone_pose(bone))
 v._apply_rifle_recoil()
 for j in recovered.size():check(difference(recovered[j],v.skeleton.get_bone_pose(v._aim_bones[j]))<.000001,"No accumulated recoil residue after release")
 gun.set_trigger(true);scene._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(not gun.trigger_held and not v.rifle_aim_requested,"Focus loss releases both mouse buttons")
 var report:={"fps":fps,"passed":failures.is_empty(),"failures":failures,"grip_error_m":grip_error,"support_error_m":support_error,"lower_body_error":lower_error,"recovered_pose_error":recovered_error,"camera_span_m":camera_span,"shots":gun.shots_fired,"pool_misses":gun.pool_misses}
 FileAccess.open("user://rifle_fire_"+str(fps)+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("RIFLE_FIRE ",JSON.stringify(report));scene.free();control.free();quit(0 if failures.is_empty() else 1)
