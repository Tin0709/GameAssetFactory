extends SceneTree
## A short directional tap must not invent another two-foot stepping cycle.
var failures:Array[String]=[]
var results:Array=[]
var moving_foot_lag:=0.
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if not ok and not failures.has(label):failures.append(label);push_error(label)
func advance(scene:Node,input:Vector2,dt:float):
 var a=scene.player;var v=a.visual
 var wanted:Vector2=input.limit_length()*a.walk_speed
 var planar:=Vector2(a.velocity.x,a.velocity.z).move_toward(wanted,(a.deceleration if input.is_zero_approx() else a.acceleration)*dt)
 a.velocity=Vector3(planar.x,0,planar.y);a.position+=a.velocity*dt
 v.drive_jump_motion(a.velocity,not input.is_zero_approx(),{"grounded":true,"body_position":a.position,"vertical_speed":0.,"takeoff":false,"sprinting":false},dt)
 if v.move_requested:
  for side in 2:
   if not v.foot_support[side]:continue
   var b:int=[v.leg_left,v.leg_right][side]
   var raw:Transform3D=v._source_global_pose(b)
   var target_yaw:float=v._foot_yaw(raw.basis.orthonormalized().get_rotation_quaternion())
   moving_foot_lag=maxf(moving_foot_lag,rad_to_deg(absf(wrapf(v._foot_yaw(v._leg_world_rotation(b))-target_yaw,-PI,PI))))
func run():
 var fps:=60 if OS.get_cmdline_user_args().has("60") else 30;var dt:=1./fps
 for direction in [Vector2(-1,-1),Vector2(1,-1),Vector2(0,-1),Vector2(0,1),Vector2(-1,0),Vector2(1,0),Vector2(-1,1),Vector2(1,1)]:
  var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();scene.zombie_combat_enabled=false;scene.auto_aim_enabled=false;root.add_child(scene)
  scene.set_process(false);scene.player.set_physics_process(false);scene.player.visual.set_process(false);scene.rifle_fire.set_physics_process(false)
  var v=scene.player.visual
  for i in fps:advance(scene,Vector2.ZERO,dt)
  for i in int(.1*fps):advance(scene,direction,dt)
  for i in int(.2*fps):
   if not v.move_requested:break
   advance(scene,Vector2.ZERO,dt)
  var start:Array[float]=[v.last_sole[0].y,v.last_sole[1].y];var peaks:=start.duplicate();var min_y:=0.;var phase:float=v.direction_snapshot.phase
  for i in int(.6*fps):
   advance(scene,Vector2.ZERO,dt)
   check(v.direction_snapshot.phase>=phase,"Short stops preserve the common gait cursor");phase=v.direction_snapshot.phase
   for side in 2:
    peaks[side]=maxf(peaks[side],v.last_sole[side].y);min_y=minf(min_y,v.last_sole[side].y)
  for side in 2:
   if start[side]<.006:check(peaks[side]<.012,"A grounded foot must not take an extra corrective step after a short tap: "+str(direction)+" side "+str(side))
  check(min_y>-.004,"Short directional stops retain floor contact")
  check(not v.move_requested and v.rifle_move_weight<.001,"The same approved Idle is reached after release")
  results.append({"direction":str(direction),"stop_height_m":start,"peak_after_stop_m":peaks,"floor_min_m":min_y})
  for i in fps:advance(scene,direction,dt)
  scene.free()
 check(moving_foot_lag<18.,"Turning into movement releases stale foot headings before a visible sideways catch-up")
 var report:={"passed":failures.is_empty(),"fps":fps,"failures":failures,"cases":results,"maximum_moving_foot_heading_lag_deg":moving_foot_lag}
 print("RIFLE_STOP_REPLANT ",JSON.stringify(report))
 var dest:=OS.get_environment("RIFLE_STOP_RESULTS")
 if not dest.is_empty():FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 quit(0 if failures.is_empty() else 1)
