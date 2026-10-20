extends SceneTree
class TimerProbe extends Node:
 var started:=0
 func _physics_process(_delta:float)->void:started=Time.get_ticks_usec()
class Observer extends Node:
 var timer:Node
 var costs:Array[float]=[]
 var actor: CharacterBody3D
 var steps:=0;var last_step:=false;var takeoffs:=0;var landings:=0;var planted_drift:=0.;var yaw_drift:=0.;var grip_error:=0.;var support_error:=0.;var floor_y:=0.;var sole: Array=[];var yaw: Array=[];var ids: Array=[]
 func _physics_process(_delta:float)->void:
  var v=actor.visual
  costs.append((Time.get_ticks_usec()-timer.started)/1000.)
  if v.stationary_turn.stepping and not last_step:steps+=1
  last_step=v.stationary_turn.stepping
  if actor.last_jump_query.get("takeoff",false):takeoffs+=1
  if actor.last_jump_query.get("landed",false):landings+=1
  var carrier:Transform3D=v.skeleton.get_bone_global_pose(v.carrier_bone)
  grip_error=maxf(grip_error,(v.skeleton.get_bone_global_pose(v.arm_right)*v.rifle_carrier_attachment).origin.distance_to(carrier.origin))
  support_error=maxf(support_error,(v.skeleton.get_bone_global_pose(v.arm_left)*v.palm_arm_local).distance_to(carrier*v.rifle_support_anchor))
  for side in 2:
   var foot:Vector3=v.last_sole[side];var q:float=v._foot_yaw(v._leg_world_rotation([v.leg_left,v.leg_right][side]))
   floor_y=minf(floor_y,foot.y)
   if sole.size()==2 and not v.move_requested and v.jump_grounded and not v.settling and v.foot_support[side] and ids[side]==v.contact_ids[side]:
    var drift:=Vector2(foot.x-sole[side].x,foot.z-sole[side].z).length()
    planted_drift=maxf(planted_drift,drift);yaw_drift=maxf(yaw_drift,absf(wrapf(q-yaw[side],-PI,PI)))
   if sole.size()<2:sole.append(foot);yaw.append(q);ids.append(v.contact_ids[side])
   else:sole[side]=foot;yaw[side]=q;ids[side]=v.contact_ids[side]
func _initialize():call_deferred("run")
func key(s:Node,code:int,down:bool)->void:
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
 if down:s._unhandled_input(e)
 else:s._input(e)
func run():
 var args:=OS.get_cmdline_user_args();var stage:=args[0];var fps:=int(args[1]);var ratio:=fps/30
 var s=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(s);current_scene=s
 var a=s.player;var v=a.visual;a.scripted_input=true
 var timer:=TimerProbe.new();timer.process_physics_priority=-2;s.add_child(timer)
 var observer:=Observer.new();observer.timer=timer;observer.actor=a;observer.process_physics_priority=2;s.add_child(observer)
 for j in 4:
  var z=s.zombie_combat.zombies[j];z.set_physics_process(false);z.position=Vector3(30+j*3,0,25)
 var max_speed:=0.;var camera_y:Array[float]=[];var shot_times:Array[float]=[];var shots:=0;var ragdolls:=0;var smallest_shot_gap:=1.;var last_shot_time:=-10.;var physics_ms:Array[float]=[]
 for frame in fps*18:
  var i:=int(frame/ratio)
  if frame%ratio==0:
   if i==20:key(s,KEY_Q,true)
   if i==26:key(s,KEY_Q,false)
   if i==45:key(s,KEY_C,true)
   if i==65:key(s,KEY_C,false)
   if i==95:key(s,KEY_Q,true)
   if i==115:key(s,KEY_Q,false)
   if i==145:key(s,KEY_C,true)
   if i==185:key(s,KEY_C,false)
   if i>=210 and i<242:
    key(s,KEY_Q,i%16<8);key(s,KEY_C,i%16>=8)
   if i==242:key(s,KEY_Q,false);key(s,KEY_C,false)
   if i==250:
    var m:=InputEventMouseButton.new();m.button_index=MOUSE_BUTTON_RIGHT;m.pressed=true;s._unhandled_input(m)
   if i==280:
    for j in 4:
     var z=s.zombie_combat.zombies[j];z.position=[Vector3(3,0,0),Vector3(0,0,-5),Vector3(-6,0,0),Vector3(2,0,7)][j];z.set_physics_process(true)
    key(s,KEY_E,true)
   if i==480:key(s,KEY_E,false)
  a.requested_direction=Vector2(1,-.4) if i>=420 and i<460 else Vector2.ZERO
  a.requested_run=i>=435 and i<460;a.requested_jump=frame==int(444*ratio)
  await physics_frame;await process_frame;await RenderingServer.frame_post_draw
  max_speed=maxf(max_speed,a.current_speed);ragdolls=maxi(ragdolls,s.zombie_combat.active_ragdolls())
  physics_ms.append(observer.costs[-1])
  if i>=443 and i<466:camera_y.append(s.camera_anchor.y)
  if s.rifle_fire.shots_fired>shots:
   smallest_shot_gap=minf(smallest_shot_gap,float(frame)/fps-last_shot_time);last_shot_time=float(frame)/fps;shot_times.append(last_shot_time)
  shots=s.rifle_fire.shots_fired
  if frame%ratio==0 and i in [6,24,51,57,64,75,109,162,173,221,259,300,330,388,450]:root.get_texture().get_image().save_png(stage+"/final_"+str(fps)+"_"+str(i)+".png")
 var report:={"render_fps":fps,"physics_hz":Engine.physics_ticks_per_second,"frames":fps*18,"source_steps":observer.steps,"right_grip_error_m":observer.grip_error,"support_error_m":observer.support_error,"planted_foot_step_m":observer.planted_drift,"planted_foot_yaw_step_rad":observer.yaw_drift,"minimum_sole_y_m":observer.floor_y,"shots":shots,"minimum_shot_interval_s":smallest_shot_gap,"kills":s.zombie_combat.kills,"pool_misses":s.rifle_fire.pool_misses,"max_active_corpses":ragdolls,"takeoffs":observer.takeoffs,"landings":observer.landings,"maximum_speed":max_speed,"camera_size":s.camera.size,"camera_distance":s.camera.position.distance_to(s.camera_anchor),"camera_jump_y_span_m":camera_y.max()-camera_y.min(),"mean_physics_ms":physics_ms.reduce(func(sum:float,value:float)->float:return sum+value,0.)/physics_ms.size(),"max_physics_ms":physics_ms.max()}
 # Native combined movement/landing retains the existing140mm safety cap;
 # allow <=10mm of its transient replant correction. Isolated turn contacts
 # are checked much more tightly in test_turn_gameplay.gd.
 report.passed=observer.steps>=5 and observer.grip_error<.00005 and observer.support_error<.00005 and observer.planted_drift<.010 and observer.yaw_drift<.015 and shots>=10 and smallest_shot_gap>=.16 and report.pool_misses==0 and ragdolls<=4 and observer.takeoffs==1 and observer.landings==1 and max_speed>7.5 and report.camera_jump_y_span_m<.03 and is_equal_approx(report.camera_size,7.2) and is_equal_approx(report.camera_distance,10.)
 FileAccess.open(stage+"/native_"+str(fps)+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("NATIVE_TURN ",JSON.stringify(report));quit(0 if report.passed else 1)
