extends SceneTree
## Check angular acceleration, rather than just the final direction reached.
var lab:Node
var failures:Array[String]=[]
var rows:Array=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if not ok:failures.append(label);push_error(label)
func tick(stick:Vector2,sprint:bool,dt:float):
 var a=lab.player;var v=a.visual
 var desired:=stick.limit_length()*float(a.run_speed if sprint else a.walk_speed)
 var planar:=Vector2(a.velocity.x,a.velocity.z).move_toward(desired,float(a.deceleration if stick.is_zero_approx() else a.acceleration)*dt)
 a.velocity=Vector3(planar.x,0,planar.y);a.position+=a.velocity*dt
 v.drive_jump_motion(a.velocity,not stick.is_zero_approx(),{"grounded":true,"body_position":a.position,"vertical_speed":0.,"takeoff":false,"sprinting":sprint},dt)
func run():
 var fps:=60 if OS.get_cmdline_user_args().has("60") else 30;var dt:=1./fps
 lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.zombie_combat_enabled=false;lab.auto_aim_enabled=false;root.add_child(lab)
 lab.set_process(false);lab.player.set_physics_process(false);lab.player.visual.set_process(false);lab.rifle_fire.set_physics_process(false);lab.soldier_appearance.set_process(false);lab.soldier_appearance.set_physics_process(false)
 var v=lab.player.visual
 for sprint in [false,true]:
  lab.reset_player()
  for i in fps:tick(Vector2(0,-1),sprint,dt)
  var yaw:float=v.rotation.y;var speed:=0.;var acceleration:=0.;var maximum_speed:=0.
  for i in fps:
   tick(Vector2(-1,0),sprint,dt)
   var current:float=wrapf(v.rotation.y-yaw,-PI,PI)/dt
   acceleration=maxf(acceleration,absf(current-speed)/dt)
   maximum_speed=maxf(maximum_speed,absf(current));speed=current;yaw=v.rotation.y
  check(acceleration<.65*14./dt,"90-degree turn eases angular speed instead of hard starting/stopping: "+str(sprint))
  check(absf(wrapf(v.rotation.y+PI*.5,-PI,PI))<.01,"Smooth travel turn still arrives promptly and accurately")
  var maximum_leg_step:=0.;var previous:Array=[];var floor_min:=0.
  for i in fps*3:
   var direction:Vector2=[Vector2(0,-1),Vector2(-1,0),Vector2(0,1),Vector2(1,0),Vector2(1,-1).normalized(),Vector2(-1,1).normalized()][int(i/maxi(1,roundi(.15*fps)))%6]
   tick(direction,sprint,dt)
   for side in 2:
    var bone:int=[v.leg_left,v.leg_right][side];var q:Quaternion=v._leg_world_rotation(bone)
    if previous.size()==2:maximum_leg_step=maxf(maximum_leg_step,rad_to_deg(previous[side].angle_to(q)))
    if previous.size()<2:previous.append(q)
    else:previous[side]=q
    floor_min=minf(floor_min,v._sole_world(bone).y)
  check(maximum_leg_step<65. and floor_min>-.004,"Rapid alternating directions keep continuous grounded leg poses")
  rows.append({"run":sprint,"maximum_angular_acceleration_rad_s2":acceleration,"peak_turn_speed_rad_s":maximum_speed,"maximum_leg_step_deg":maximum_leg_step,"minimum_foot_y":floor_min})
 print("SMOOTH_TRAVEL_TURN ",JSON.stringify({"fps":fps,"passed":failures.is_empty(),"failures":failures,"rows":rows}));lab.free();quit(0 if failures.is_empty() else 1)
