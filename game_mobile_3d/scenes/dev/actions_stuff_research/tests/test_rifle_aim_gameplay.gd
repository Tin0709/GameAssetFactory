extends SceneTree
var failures: Array[String]=[]
var grip_error:=0.0
var support_error:=0.0
var max_arm_step:=0.0
var max_weapon_step:=0.0
func check(ok: bool,label: String) -> void:
 if not ok and not failures.has(label):failures.append(label);push_error(label)
func difference(a: Transform3D,b: Transform3D) -> float:
 return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func _initialize() -> void:call_deferred("run")
func audit(v: Node,p: Node) -> void:
 var r: Skeleton3D=v.skeleton
 var palm:=Vector3(v.rifle_profile.palm_forearm_local[0],v.rifle_profile.palm_forearm_local[1],v.rifle_profile.palm_forearm_local[2])
 grip_error=maxf(grip_error,difference(r.get_bone_global_pose(v.arm_right).affine_inverse()*r.get_bone_global_pose(v.carrier_bone),v.rifle_carrier_attachment))
 support_error=maxf(support_error,(r.get_bone_global_pose(v.forearm_left)*palm).distance_to(r.get_bone_global_pose(v.carrier_bone)*v.rifle_support_anchor))
 for alpha in [0.,.5,1.]:
  p.prepare(alpha)
  var mount:=Transform3D(p.previous.rifle_attachment).interpolate_with(p.current.rifle_attachment,alpha)
  var anchor:=Vector3(p.previous.rifle_support).lerp(p.current.rifle_support,alpha)
  grip_error=maxf(grip_error,difference(Transform3D(p.display_world[v.arm_right]).affine_inverse()*Transform3D(p.display_world[v.carrier_bone]),mount))
  support_error=maxf(support_error,(Transform3D(p.display_world[v.forearm_left])*palm).distance_to(Transform3D(p.display_world[v.carrier_bone])*anchor))
func run() -> void:
 var fps:=60 if OS.get_cmdline_user_args().has("60") else 30
 var dt:=1./fps
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
 var a=scene.player;var v=a.visual
 check(v.has_method("set_rifle_aim"),"Existing rifle controller supports hold/release of the approved Aim")
 if not failures.is_empty():scene.free();quit(1);return
 check(v.rifle_aim_clip.clip.resource_name=="Crossbow_Aim_ActionsStuff_Refined_Test_v001","Exact approved Aim Action")
 check(v.rifle_aim_profile.clips.Aim.action_sha256=="4b4d072c8b6b909155207505eae19fc1dbd4bc15b227544c61791a6c7eae883f","Approved source pin")
 check(v.rifle_clips.size()==3,"Original Ready clip set retained")
 check(absf(a.walk_speed-2.70)<.001 and absf(a.run_speed-7.55)<.01,"Requested Walk/Run travel speeds")
 check(v.locomotion_playback_rate==1.,"Approved animation playback stays1x")
 scene.set_process(false);a.set_physics_process(false);v.set_process(false)
 var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_RIGHT;press.pressed=true;scene._unhandled_input(press)
 check(v.rifle_aim_requested and scene.orbiting,"RMB requests Aim and retains orbit gesture")
 press.pressed=false;scene._unhandled_input(press);check(not v.rifle_aim_requested,"RMB release returns Ready")
 # Exact upper-body target at full Aim; lower body remains the active gait.
 var ready_poses: Array=v._sample_set();v.rifle_aim_weight=1.;var aiming_poses: Array=v._sample_set()
 for bone in [v.leg_left,v.leg_right,v.skeleton.find_bone("Root")]:check(difference(ready_poses[bone],aiming_poses[bone])<.00001,"Aim leaves gait/root channels unchanged")
 for bone_name in ["Chest","Neck","Head","Arm.L","Arm.R","ForeArm.L","ForeArm.R","WeaponCarrier"]:
  var b: int=v.skeleton.find_bone(bone_name);check(difference(aiming_poses[b],v.rifle_aim_clip.pose(b,v.rifle_aim_time))<.00001,"Approved local pose retained: "+bone_name)
 v.rifle_aim_weight=0.;var reached_run:=false;var full_aim:=false;var released:=false;var saw_air:=false;var saw_land:=false;var camera_y: Array[float]=[];var previous: Array=[];var previous_weapon:=Transform3D.IDENTITY
 for i in int(12.*fps):
  var t:=i*dt;var moving:=t>2. and t<9.;var sprint:=t>4. and t<7.
  var held:=t>.3 and t<8.5
  if t>3. and t<3.5:held=fmod(t,.18)<.09 # Rapid reversals of the blend.
  v.set_rifle_aim(held)
  var direction:=Vector2(0,-1)
  if t>5. and t<6.:direction=Vector2(sin(t*10.),-cos(t*10.))
  var desired: Vector2=direction*(a.run_speed if sprint else a.walk_speed) if moving else Vector2.ZERO
  var planar:=Vector2(a.velocity.x,a.velocity.z).move_toward(desired,(a.acceleration if moving else a.deceleration)*dt)
  a.velocity=Vector3(planar.x,0,planar.y);a.position+=a.velocity*dt;a.current_speed=planar.length()
  var jump_t:=t-6.7;var air:=jump_t>0. and jump_t<.74
  a.position.y=maxf(0.,6.66*jump_t-9.*jump_t*jump_t) if air else 0.
  v.drive_jump_motion(a.velocity,moving,{"grounded":not air,"body_position":a.position,"vertical_speed":6.66-18.*jump_t if air else 0.,"takeoff":absf(jump_t)<dt*.5,"sprinting":sprint},dt)
  audit(v,scene.presentation)
  full_aim=full_aim or (t>1. and v.rifle_aim_weight>.999)
  released=released or (t>9. and v.rifle_aim_weight<.001)
  reached_run=reached_run or v.gait_run_weight>.98;saw_air=saw_air or not v.jump_grounded
  saw_land=saw_land or (saw_air and v.jump_grounded)
  var local_weapon: Transform3D=v.skeleton.get_bone_global_pose(v.chest).affine_inverse()*v.skeleton.get_bone_global_pose(v.carrier_bone)
  if not previous.is_empty():
   for side in 2:max_arm_step=maxf(max_arm_step,rad_to_deg(previous[side].angle_to(v.skeleton.get_bone_pose_rotation([v.arm_left,v.arm_right][side]))))
   max_weapon_step=maxf(max_weapon_step,local_weapon.origin.distance_to(previous_weapon.origin))
  previous=[v.skeleton.get_bone_pose_rotation(v.arm_left),v.skeleton.get_bone_pose_rotation(v.arm_right)];previous_weapon=local_weapon
  if t>6.5 and t<7.6:scene.presentation.prepare(1.);scene._update_camera(dt,scene.presentation.display_actor);camera_y.append(scene.camera_anchor.y)
  check(a.velocity.is_finite(),"Finite movement")
 check(full_aim and released,"Aim reaches both endpoints without a stuck state")
 check(reached_run and saw_air and saw_land,"Aim coexists with Run, Jump and Landing")
 check(grip_error<.00005,"Stable right grip during physics/render transitions: "+str(grip_error))
 check(support_error<.00005,"Stable authored left support during physics/render transitions: "+str(support_error))
 check(max_arm_step<35.,"No sudden arm pose reset: "+str(max_arm_step))
 check(max_weapon_step<.20,"No weapon snap in chest frame: "+str(max_weapon_step))
 check(camera_y.max()-camera_y.min()<.03,"Comfortable jump camera remains stable")
 v.set_rifle_aim(true);scene._notification(NOTIFICATION_APPLICATION_FOCUS_OUT);check(not v.rifle_aim_requested,"Focus loss releases Aim")
 var report:={"fps":fps,"failures":failures,"grip_error":grip_error,"support_error_m":support_error,"max_arm_step_deg":max_arm_step,"max_weapon_step_m":max_weapon_step,"camera_y_span":camera_y.max()-camera_y.min()}
 FileAccess.open("user://rifle_aim_"+str(fps)+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("RIFLE_AIM ",JSON.stringify(report));scene.free();quit(0 if failures.is_empty() else 1)
