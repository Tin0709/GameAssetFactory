extends SceneTree
const Reference=preload("res://scenes/dev/actions_stuff_research/source_direction_sampler.gd")
var failures:Array[String]=[]
var max_source_error:=0.;var max_grip:=0.;var max_support:=0.;var min_floor:=0.;var max_leg_step:=0.;var contact_drift:=0.
var previous_feet:Array=[];var previous_ids:Array=[];var previous_q:Array=[]
var previous_support:Array=[];var previous_point:Array=[]
var contact_pairs:=0;var height_step:=0.;var previous_height:=0.
var source_samples:=0;var side_seen:=false;var back_seen:=false;var recent_seen:=false
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if not ok and not failures.has(label):failures.append(label);push_error(label)
func difference(a:Transform3D,b:Transform3D)->float:
 return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func tick(scene:Node,velocity:Vector3,dt:float,reference:RefCounted,audit_source:bool):
 var a=scene.player;var v=a.visual
 a.velocity=velocity;a.position+=velocity*dt
 var phase:float=v.direction_snapshot.phase
 v.drive_jump_motion(velocity,velocity.length()>.001,{"grounded":true,"body_position":a.position,"vertical_speed":0.,"takeoff":false,"sprinting":velocity.length()>3.},dt)
 height_step=maxf(height_step,absf(v.position.y-previous_height));previous_height=v.position.y
 check(v.direction_snapshot.phase>=phase and v.direction_snapshot.phase-phase<.2,"Combat direction changes keep the continuous source gait clock")
 if audit_source:
  reference.set_snapshot(v.direction_snapshot)
  for name in ["Root","Hips","Leg.L","Leg.R"]:
   var b:int=v.skeleton.find_bone(name)
   max_source_error=maxf(max_source_error,difference(v.direction_poses[b],reference.poses[b]))
  source_samples+=1
  side_seen=side_seen or absf(v.direction_snapshot.vars["v.mrmeib"])>.3
  back_seen=back_seen or v.direction_snapshot.vars["v.cknrcn"]<-.3
  recent_seen=recent_seen or bool(v.direction_snapshot.vars["v.nwocdu"])
 var right:Transform3D=v.skeleton.get_bone_global_pose(v.arm_right);var carrier:Transform3D=v.skeleton.get_bone_global_pose(v.carrier_bone)
 max_grip=maxf(max_grip,(right*v.rifle_carrier_attachment).origin.distance_to(carrier.origin))
 var palm:Vector3=Vector3(v.rifle_profile.palm_forearm_local[0],v.rifle_profile.palm_forearm_local[1],v.rifle_profile.palm_forearm_local[2])
 max_support=maxf(max_support,(v.skeleton.get_bone_global_pose(v.forearm_left)*palm).distance_to(carrier*v.rifle_support_anchor))
 for side in 2:
  var b:int=[v.leg_left,v.leg_right][side];var foot:Vector3=v.contact_point(side);var q:Quaternion=v._leg_world_rotation(b)
  var point:int=v.rolling_corner[side] if v.rolling_used[side] else -1
  min_floor=minf(min_floor,v._sole_world(b).y)
  if previous_q.size()==2:
   max_leg_step=maxf(max_leg_step,rad_to_deg(q.angle_to(previous_q[side])))
   if not v.settling and v.foot_support[side] and previous_support[side] and v.contact_ids[side]==previous_ids[side] and point==previous_point[side]:
    contact_pairs+=1;contact_drift=maxf(contact_drift,foot.distance_to(previous_feet[side]))
  if previous_q.size()<2:previous_q.append(q);previous_feet.append(foot);previous_ids.append(v.contact_ids[side]);previous_support.append(v.foot_support[side]);previous_point.append(point)
  else:previous_q[side]=q;previous_feet[side]=foot;previous_ids[side]=v.contact_ids[side];previous_support[side]=v.foot_support[side];previous_point[side]=point
func run():
 var fps:=60 if OS.get_cmdline_user_args().has("60") else 30;var dt:=1./fps
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();scene.auto_aim_enabled=false;root.add_child(scene)
 scene.set_process(false);scene.player.set_physics_process(false);scene.player.visual.set_process(false);scene.rifle_fire.set_physics_process(false)
 var v=scene.player.visual;var target=scene.zombie_combat.zombies[0]
 for z in scene.zombie_combat.zombies:z.set_physics_process(false);z.position=Vector3(30,0,30)
 target.position=Vector3(0,0,-9);target.current_hp=100000
 var reference=Reference.new(v.skeleton)
 for i in fps:tick(scene,Vector3.ZERO,dt,reference,false)
 var event:=InputEventKey.new();event.physical_keycode=KEY_E;event.pressed=true;scene._unhandled_input(event);v.auto_aim_target=target
 var reached_run:=false;var aligned_samples:=0
 for speed in [scene.player.walk_speed,scene.player.run_speed]:
  for direction in [Vector3(0,0,-1),Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(1,0,-1),Vector3(-1,0,1),Vector3(1,0,1),Vector3(-1,0,-1)]:
   for i in int(1.2*fps):
    tick(scene,direction.normalized()*speed,dt,reference,i>int(.5*fps))
    reached_run=reached_run or v.gait_run_weight>.98
    if v.auto_aim_aligned:aligned_samples+=1
 for i in fps*2:
  var direction:Vector3=[Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK][int(i/maxi(1,int(.1*fps)))%4]
  tick(scene,direction*scene.player.walk_speed,dt,reference,false)
 check(max_source_error<.00005,"Combat lower body uses literal directional source PRS, including waist compensation")
 check(side_seen and back_seen and recent_seen,"Held E activates the verified recent-action side/back source branch")
 check(reached_run and aligned_samples>fps*3,"Directional combat supports Run and real muzzle alignment")
 check(max_grip<.00005 and max_support<.00005,"Approved two-hand rifle hold remains synchronized")
 check(min_floor>-.004,"Directional combat feet remain above the research floor")
 check(max_leg_step<65.,"Rapid combat reversals do not spin legs")
 check(contact_pairs>4 and contact_drift<.008,"Actual same-point support contacts remain stable during strafe")
 check(height_step<.03,"Directional body-height changes remain smooth")
 # Release must return to ordinary movement-facing locomotion, retaining phase.
 event.pressed=false;scene._input(event);v.auto_aim_target=null
 for i in fps*2:tick(scene,Vector3.RIGHT*scene.player.walk_speed,dt,reference,false)
 check(absf(wrapf(v.rotation.y-PI*.5,-PI,PI))<.01,"E release restores existing movement-facing behavior")
 var report:={"passed":failures.is_empty(),"fps":fps,"failures":failures,"source_samples":source_samples,"maximum_source_pose_error":max_source_error,"side_seen":side_seen,"back_seen":back_seen,"recent_action_branch":recent_seen,"right_grip_error_m":max_grip,"left_support_error_m":max_support,"minimum_floor_m":min_floor,"maximum_leg_step_deg":max_leg_step,"contact_step_m":contact_drift,"contact_pairs":contact_pairs,"height_step_m":height_step,"aim_aligned_samples":aligned_samples}
 print("RIFLE_COMBAT_STRAFE ",JSON.stringify(report))
 var dest:=OS.get_environment("RIFLE_STRAFE_RESULTS")
 if not dest.is_empty():FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 scene.free();quit(0 if failures.is_empty() else 1)
