extends SceneTree
var failures: Array[String]=[]
var grip_error:=0.0
var support_error:=0.0
var minimum_floor:=INF
var maximum_leg_step:=0.0
func check(ok: bool,label: String) -> void:
 if not ok and not failures.has(label):failures.append(label);push_error(label)
func difference(a: Transform3D,b: Transform3D) -> float:
 return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func _initialize() -> void:call_deferred("run")
func audit(v: Node,p: Node) -> void:
 var r: Skeleton3D=v.skeleton
 var right: Transform3D=r.get_bone_global_pose(v.arm_right);var carrier: Transform3D=r.get_bone_global_pose(v.carrier_bone)
 grip_error=maxf(grip_error,difference(right.affine_inverse()*carrier,v.carrier_in_right_arm))
 var palm: Vector3=r.get_bone_global_pose(v.forearm_left)*Vector3(v.rifle_profile.palm_forearm_local[0],v.rifle_profile.palm_forearm_local[1],v.rifle_profile.palm_forearm_local[2])
 support_error=maxf(support_error,palm.distance_to(carrier*v.rifle_support_anchor))
 for alpha in [0.,.5,1.]:
  p.prepare(alpha)
  grip_error=maxf(grip_error,difference(Transform3D(p.display_world[v.arm_right]).affine_inverse()*Transform3D(p.display_world[v.carrier_bone]),v.carrier_in_right_arm))
  var anchor:=Vector3(p.previous.rifle_support).lerp(p.current.rifle_support,alpha)
  var actual: Vector3=Transform3D(p.display_world[v.forearm_left])*Vector3(v.rifle_profile.palm_forearm_local[0],v.rifle_profile.palm_forearm_local[1],v.rifle_profile.palm_forearm_local[2])
  support_error=maxf(support_error,actual.distance_to(Transform3D(p.display_world[v.carrier_bone])*anchor))
 for bone in [v.leg_left,v.leg_right]:minimum_floor=minf(minimum_floor,v._sole_world(bone).y)
func run() -> void:
 var fps:=60 if OS.get_cmdline_user_args().has("60") else 30
 var dt:=1./fps
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
 var a=scene.player;var v=a.visual
 check(v.get("rifle_ready_active")==true,"Existing dev scene activates the approved Rifle Ready set")
 if not failures.is_empty():scene.free();quit(1);return
 check(v.rifle_clips.size()==3,"Exactly three approved Rifle Ready clips")
 check(v.rifle_clips.Idle.clip.resource_name=="Rifle_Ready_Idle_ActionsStyle_v004","Exact approved Idle")
 check(v.rifle_clips.Walk.clip.resource_name=="Rifle_Ready_Walk_ActionsStyle_v0012","Exact approved Walk")
 check(v.rifle_clips.Run.clip.resource_name=="Rifle_Ready_Run_ActionsStyle_v002","Exact approved Run")
 # An already-contacting authored moving pose must retain its shoulder root.
 var moving_shoulder_error:=0.
 for kind in ["Walk","Run"]:
  for time in [.0,.071,.251,.501,1.37]:
   var authored: Transform3D=v.rifle_clips[kind].pose(v.arm_left,time)
   var palm: Vector3=authored*v.palm_arm_local
   v.rifle_move_weight=1.
   moving_shoulder_error=maxf(moving_shoulder_error,v.constrained_left_pose(authored,palm).origin.distance_to(authored.origin))
 v.rifle_move_weight=0.
 check(moving_shoulder_error<.00002,"Approved moving shoulders survive contact solve: "+str(moving_shoulder_error))
 check(v.rifle_profile.clips.Run.action_sha256=="433d33c3b73c9f5aedd0420b2ab27123521270d22373c83fedae464717d9e76b","Latest Walking-matched-shoulder Run source pin")
 check(v.rifle_model.visible,"Actual Rifle Stylized V2 visible")
 scene.set_process(false);a.set_physics_process(false);v.set_process(false)
 var previous: Array[Quaternion]=[];var reached_run:=false;var saw_support:=0;var camera_span: Array[float]=[];var idle_scan_cancelled:=false
 for i in int(14.*fps):
  var t:=i*dt;var moving:=t>1. and t<10.;var sprint:=t>3. and t<7.
  var direction:=Vector2(0,-1)
  if t>5. and t<6.8:direction=Vector2(sin(t*11.),-cos(t*11.))
  elif t>=6.8 and t<7.5:direction=Vector2(0,1)
  var desired: Vector2=direction*(a.run_speed if sprint else a.walk_speed) if moving else Vector2.ZERO
  var planar:=Vector2(a.velocity.x,a.velocity.z).move_toward(desired,(a.acceleration if moving else a.deceleration)*dt)
  a.velocity=Vector3(planar.x,0,planar.y);a.position+=a.velocity*dt;a.current_speed=planar.length()
  var jump_t:=t-8.;var air:=jump_t>0. and jump_t<.74
  a.position.y=maxf(0.,6.66*jump_t-9.*jump_t*jump_t) if air else 0.
  v.drive_jump_motion(a.velocity,moving,{"grounded":not air,"body_position":a.position,"vertical_speed":6.66-18.*jump_t if air else 0.,"takeoff":absf(jump_t)<dt*.5,"sprinting":sprint},dt)
  audit(v,scene.presentation)
  if v.foot_support[0] or v.foot_support[1]:saw_support+=1
  if v.gait_run_weight>.98:reached_run=true
  if t>1. and t<1.1 and moving:idle_scan_cancelled=not v.idle_active and a.current_speed>.1
  if t>7.7 and t<8.9:
   scene.presentation.prepare(1.);scene._update_camera(dt,scene.presentation.display_actor);camera_span.append(scene.camera_anchor.y)
  if not previous.is_empty():
   for side in 2:maximum_leg_step=maxf(maximum_leg_step,rad_to_deg(previous[side].angle_to(v.skeleton.get_bone_pose_rotation([v.leg_left,v.leg_right][side]))))
  previous=[v.skeleton.get_bone_pose_rotation(v.leg_left),v.skeleton.get_bone_pose_rotation(v.leg_right)]
  for bone in v.skeleton.get_bone_count():check(v.skeleton.get_bone_pose(bone).origin.is_finite(),"Finite poses throughout transitions")
 check(reached_run,"Shift-speed motion reaches Rifle Run")
 check(idle_scan_cancelled,"Movement interrupts Idle scan without input delay")
 check(v.rifle_state=="Idle" and not v.settling and v.rifle_move_weight<.001,"Release naturally settles to approved Idle")
 check(grip_error<.00005,"Right grip stable through physics and rendered blends: "+str(grip_error))
 check(support_error<.00005,"Left palm remains on live support target: "+str(support_error))
 check(minimum_floor>-.004,"No foot penetration: "+str(minimum_floor))
 check(maximum_leg_step<75.,"No extreme leg resets: "+str(maximum_leg_step))
 check(saw_support>10,"Usable foot support during motion")
 check(camera_span.max()-camera_span.min()<.03,"Ordinary jump keeps comfortable camera height")
 var life: float=v.entity_lifetime;scene.reset_player();check(a.position.length()<.001 and v.entity_lifetime==life,"Reset preserves persistent locomotion clocks")
 var report:={"fps":fps,"moving_shoulder_error_m":moving_shoulder_error,"failures":failures,"right_grip_matrix_error":grip_error,"left_support_error_m":support_error,"minimum_foot_y":minimum_floor,"maximum_leg_step_deg":maximum_leg_step,"support_samples":saw_support,"camera_jump_y_span":camera_span.max()-camera_span.min()}
 var out:="user://rifle_ready_"+str(fps)+".json";FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("RIFLE_READY ",JSON.stringify(report));scene.free();quit(0 if failures.is_empty() else 1)
