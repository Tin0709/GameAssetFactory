extends SceneTree
class AimTarget extends Node3D:
 var is_dead:=false
var failures: Array[String]=[]
var current_case:=0.
var measuring:=false
var diagnostic:=OS.get_cmdline_user_args().has("diagnostic")
var max_grip:=0.;var max_palm:=0.;var max_contact_drift:=0.;var max_foot_yaw_drift:=0.;var min_floor:=0.;var max_pose_step:=0.
var previous_soles: Array=[]
var previous_yaws: Array=[]
var previous_ids: Array=[]
func check(ok: bool,message: String) -> void:
 if not ok and not failures.has(message):failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func tick(v: Node,dt: float,velocity:=Vector3.ZERO,requested:=false) -> void:
 v.drive_jump_motion(velocity,requested,{"grounded":true,"body_position":Vector3.ZERO,"vertical_speed":0.,"takeoff":false,"sprinting":velocity.length()>3.},dt)
 var carrier: Transform3D=v.skeleton.get_bone_global_pose(v.carrier_bone)
 var right: Transform3D=v.skeleton.get_bone_global_pose(v.arm_right)
 max_grip=maxf(max_grip,(right*v.rifle_carrier_attachment).origin.distance_to(carrier.origin))
 var palm:=Vector3(v.rifle_profile.palm_forearm_local[0],v.rifle_profile.palm_forearm_local[1],v.rifle_profile.palm_forearm_local[2])
 max_palm=maxf(max_palm,(v.skeleton.get_bone_global_pose(v.forearm_left)*palm).distance_to(carrier*v.rifle_support_anchor))
 for side in 2:
  var bone: int=[v.leg_left,v.leg_right][side];var sole: Vector3=v._sole_world(bone);var yaw: float=v._foot_yaw(v._leg_world_rotation(bone))
  min_floor=minf(min_floor,sole.y)
  if measuring and previous_soles.size()==2:
   if not v.move_requested:
    max_pose_step=maxf(max_pose_step,sole.distance_to(previous_soles[side]))
    if diagnostic and sole.distance_to(previous_soles[side])>.1:print("BIG ",current_case," ",side," ",v.stationary_turn.clock," ",sole.distance_to(previous_soles[side])," ",v.stationary_turn.snapshot.state)
   if not v.move_requested and v.foot_support[side] and v.contact_ids[side]==previous_ids[side]:
    var drift:=Vector2(sole.x-previous_soles[side].x,sole.z-previous_soles[side].z).length()
    max_contact_drift=maxf(max_contact_drift,drift)
    if diagnostic and drift>.008:print("DRIFT ",current_case," ",side," ",v.stationary_turn.clock," ",drift," budget ",v.maximum_correction," clamp ",v.correction_clamps," at ",sole," anchor ",v.foot_anchors[side])
    max_foot_yaw_drift=maxf(max_foot_yaw_drift,absf(wrapf(yaw-previous_yaws[side],-PI,PI)))
  if previous_soles.size()<2:
   previous_soles.append(sole);previous_yaws.append(yaw);previous_ids.append(v.contact_ids[side])
  else:previous_soles[side]=sole;previous_yaws[side]=yaw;previous_ids[side]=v.contact_ids[side]
func run() -> void:
 var fps:=60 if OS.get_cmdline_user_args().has("60") else 30;var dt:=1./fps
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();scene.auto_aim_enabled=false;scene.zombie_combat_enabled=false;root.add_child(scene)
 var a=scene.player;var v=a.visual
 scene.set_process(false);a.set_physics_process(false);v.set_process(false);scene.rifle_fire.set_physics_process(false)
 var raw=v.stationary_turn.sampler
 check(absf(raw.sample_clip("rjfeeq",.0833).rightleg.position.y-.015)<.000001,"Exact source leading-foot lift key is retained")
 check(absf(raw.sample_clip("rjfeeq",.1667).rightleg.rotation.y-.5)<.000001 and absf(raw.sample_clip("ejnecs",.1667).leftleg.rotation.y+.5)<.000001,"Mirrored source yaw keys are retained")
 check(absf(raw.sample_clip("rjfeeq",.22915).leftleg.rotation.x-.083125)<.000001,"Source Catmull-Rom stays curved rather than linearized")
 for i in fps*12:
  tick(v,dt)
  check(not v.stationary_turn.active and not v.stationary_turn.stepping,"Source zero-angle idle timeout cannot create walking-in-place")
 var cases:=[]
 for angle in [25.,90.,-90.,180.]:
  current_case=angle;measuring=false
  v.rotation.y=PI;v.look_yaw=PI;v.reset_contacts();previous_soles.clear();previous_yaws.clear();previous_ids.clear()
  for i in fps:tick(v,dt)
  measuring=true;previous_soles.clear();previous_yaws.clear();previous_ids.clear()
  var initial: float=v.rotation.y;var phase: float=v.direction_snapshot.phase
  v.stationary_turn.requested_yaw=initial+deg_to_rad(angle)
  var lift: Array[float]=[0.,0.];var stepped:=false
  for i in fps*3:
   tick(v,dt);stepped=stepped or v.stationary_turn.stepping
   for side in 2:lift[side]=maxf(lift[side],v.last_sole[side].y)
  check(is_equal_approx(v.direction_snapshot.phase,phase),"Stationary turn preserves the locomotion phase")
  if angle==25.:
   check(not stepped and absf(wrapf(v.rotation.y-initial,-PI,PI))<.001,"Small turn is head-led with planted body/feet")
  else:
   check(stepped and absf(wrapf(v.rotation.y-initial-deg_to_rad(angle),-PI,PI))<=deg_to_rad(60.1),"Large turn leaves at most the source 60-degree head/body dead zone")
   check(lift[0]>.015 and lift[1]>.015,"Both feet adjust during a large turn")
  cases.append({"angle":angle,"body_angle_deg":rad_to_deg(wrapf(v.rotation.y-initial,-PI,PI)),"foot_lifts_m":lift,"stepped":stepped})
 # Reversals and Aim/Ready retain synchronized grip, not independent arm spins.
 for i in fps*3:
  v.stationary_turn.requested_yaw=PI+(.5*PI if i%(fps/2)<fps/4 else -.5*PI)
  v.set_rifle_aim(i>fps);tick(v,dt)
 # A movement request interrupts immediately; phase is continuous at handoff.
 var phase_before: float=v.direction_snapshot.phase
 tick(v,dt,Vector3(2.7,0,0),true)
 check(not v.stationary_turn.stepping and v.move_requested,"Walking immediately interrupts the source turn")
 check(v.direction_snapshot.phase>=phase_before and v.direction_snapshot.phase-phase_before<.2,"Walking resumes the existing gait without resetting it")
 for i in fps:tick(v,dt,Vector3(7.5465,0,0),true)
 check(v.gait_run_weight>.98,"Turn can lead directly into approved Run")
 # Input is separate from orbit; key release and focus loss cannot leave spin.
 var event:=InputEventKey.new();event.physical_keycode=KEY_Q;event.pressed=true;scene._unhandled_input(event)
 check(v.turn_axis>0.,"Q requests a deliberate left turn")
 event.pressed=false;scene._input(event);check(v.turn_axis==0.,"Key-up caught over GUI")
 event.physical_keycode=KEY_C;event.pressed=true;scene._unhandled_input(event);check(v.turn_axis<0.,"C requests a deliberate right turn")
 scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);check(v.turn_axis==0.,"Focus loss clears turn input")
 var intent: float=v.stationary_turn.requested_yaw
 var mouse:=InputEventMouseMotion.new();mouse.relative=Vector2(20,0);scene.orbiting=true;scene._unhandled_input(mouse)
 check(v.stationary_turn.requested_yaw==intent,"Camera orbit does not request player turning")
 # A close target can be inside the60deg yaw zone yet outside a60deg 3D
 # weapon cone because of pitch/parallax. It must not starve continuous fire.
 measuring=false
 v.rotation.y=deg_to_rad(123.);v.look_yaw=v.rotation.y;v.reset_contacts()
 var target:=AimTarget.new();scene.add_child(target);target.position=Vector3(0,0,-1.6)
 v.auto_aim_target=target;v.set_rifle_aim(true);scene.rifle_fire.set_trigger(true)
 for i in fps*2:tick(v,dt);scene.rifle_fire.tick(dt)
 if diagnostic:print("CLOSE ",v.auto_aim_aligned," shots ",scene.rifle_fire.shots_fired," angle ",rad_to_deg(v._auto_aim_rotation.get_angle())," gaze ",rad_to_deg(v.stationary_turn.gaze))
 check(v.auto_aim_aligned and scene.rifle_fire.shots_fired>=5,"Close57deg target remains fireable inside the source head/body dead zone")
 scene.rifle_fire.set_trigger(false);v.auto_aim_target=null
 check(max_grip<.00005 and max_palm<.00005,"Rifle grip and left support remain stable throughout")
 check(min_floor>-.004,"Feet never penetrate the research floor")
 check(max_contact_drift<.008,"Planted feet stay at their world contact")
 check(max_foot_yaw_drift<.015,"A planted foot does not spin on the floor")
 var report:={"passed":failures.is_empty(),"fps":fps,"failures":failures,"cases":cases,"right_grip_error_m":max_grip,"left_palm_error_m":max_palm,"contact_step_m":max_contact_drift,"planted_foot_yaw_step_rad":max_foot_yaw_drift,"minimum_sole_y_m":min_floor,"maximum_sole_frame_motion_m":max_pose_step}
 print("TURN_GAMEPLAY ",JSON.stringify(report))
 var destination:=OS.get_environment("TURN_RESULTS")
 if not destination.is_empty():FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 scene.free();quit(0 if failures.is_empty() else 1)
