extends SceneTree
## Reproduce Shift release, single-tick taps and repeated WASD direction changes.
var lab:Node
var failures:Array[String]=[]
var metrics:Dictionary={}
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func tick(stick:Vector2,sprint:bool,dt:float):
 var a=lab.player;var v=a.visual
 var wanted:=stick.limit_length()*float(a.run_speed if sprint else a.walk_speed)
 var planar:=Vector2(a.velocity.x,a.velocity.z).move_toward(wanted,float(a.deceleration if stick.is_zero_approx() else a.acceleration)*dt)
 a.velocity=Vector3(planar.x,0,planar.y);a.position+=a.velocity*dt
 v.drive_jump_motion(a.velocity,not stick.is_zero_approx(),{"grounded":true,"body_position":a.position,"vertical_speed":0.,"takeoff":false,"sprinting":sprint},dt)
func run():
 var fps:=60 if OS.get_cmdline_user_args().has("60") else 30;var dt:=1./fps
 lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.zombie_combat_enabled=false;lab.auto_aim_enabled=false;root.add_child(lab)
 lab.set_process(false);lab.player.set_physics_process(false);lab.player.visual.set_process(false);lab.rifle_fire.set_physics_process(false);lab.soldier_appearance.set_process(false);lab.soldier_appearance.set_physics_process(false)
 var a=lab.player;var v=a.visual
 check(absf(a.walk_speed-1.8)<.0001 and absf(a.run_speed-5.031)<.0001,"Saved scene uses original 1x movement speeds")
 for i in fps:tick(Vector2.ZERO,false,dt)
 for i in fps:tick(Vector2(0,-1),false,dt)
 for i in fps:tick(Vector2(0,-1),true,dt)
 check(v.gait_run_weight>.98,"Held Shift reaches the approved Run pose")
 for i in ceili(.3*fps):tick(Vector2(0,-1),false,dt)
 check(v.gait_run_weight<.05 and v.rifle_state=="Walk","Releasing Shift while moving returns to Walk within 0.3s")
 metrics["run_weight_after_release"]=v.gait_run_weight
 var maximum_phase_tail:=0.;var maximum_foot_drift:=0.;var late_settles:=0
 for heading in [Vector2(0,-1),Vector2(-1,0),Vector2(1,0),Vector2(0,1),Vector2(-1,-1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,1).normalized(),Vector2(1,1).normalized()]:
  lab.reset_player()
  for i in fps:tick(Vector2.ZERO,false,dt)
  tick(heading,false,dt)
  for i in 8:
   tick(Vector2.ZERO,false,dt)
   if not v.move_requested:break
  var phase:float=v.direction_snapshot.phase
  var feet:Array=[v.last_sole[0],v.last_sole[1]]
  for i in ceili(.4*fps):
   tick(Vector2.ZERO,false,dt)
   maximum_phase_tail=maxf(maximum_phase_tail,absf(v.direction_snapshot.phase-phase))
   for side in 2:maximum_foot_drift=maxf(maximum_foot_drift,Vector2(v.last_sole[side].x-feet[side].x,v.last_sole[side].z-feet[side].z).length())
   if i==ceili(.12*fps) and v.settling:late_settles+=1
 check(maximum_phase_tail<.00001,"A stopped capsule does not keep advancing the gait after a tap")
 check(late_settles==0,"A single-tick tap does not start a two-foot recovery step sequence")
 check(maximum_foot_drift<.025,"Feet remain planted after tiny taps in all eight directions")
 metrics["phase_travel_after_stop"]=maximum_phase_tail;metrics["tap_foot_drift_m"]=maximum_foot_drift
 var circle:Array=[]
 for sprint in [false,true]:
  lab.reset_player();var lag:=0.;var count:=0;var max_step:=0.;var previous:Array=[];var min_floor:=0.
  var segment:=maxi(1,roundi(.2*fps))
  for i in fps*3:
   var direction:Vector2=[Vector2(0,-1),Vector2(-1,0),Vector2(0,1),Vector2(1,0)][int(i/segment)%4]
   tick(direction,sprint,dt)
   if i%segment>=segment-2:
    lag+=absf(wrapf(atan2(a.velocity.x,a.velocity.z)-v.rotation.y,-PI,PI));count+=1
   for side in 2:
    var bone:int=[v.leg_left,v.leg_right][side];var q:Quaternion=v._leg_world_rotation(bone)
    min_floor=minf(min_floor,v._sole_world(bone).y)
    if previous.size()==2:max_step=maxf(max_step,rad_to_deg(previous[side].angle_to(q)))
    if previous.size()<2:previous.append(q)
    else:previous[side]=q
  var average:=rad_to_deg(lag/maxi(1,count))
  check(average<30.,"Repeated WASD turns keep body and travel coherent: "+str(sprint))
  check(max_step<65. and min_floor>-.004,"Circle input retains continuous grounded leg motion: "+str(sprint))
  circle.append({"run":sprint,"mean_late_heading_error_deg":average,"maximum_leg_step_deg":max_step,"minimum_foot_y":min_floor})
 metrics["circle"]=circle
 var appearance=lab.soldier_appearance
 check(appearance.SECONDARY_STRENGTH==4.,"Hair and bandana response is twice the previous 2x setting")
 var crown_peak:=0.
 for i in fps*3:
  var t:=float(i)/fps
  appearance.advance_motion(dt,Vector3(0,0,-5.031),Vector3(0,1.55+.02*sin(t*TAU*3.2),-t*5.031),Basis.IDENTITY,t*1.6,1.)
  if appearance.get("crown_spring")!=null:crown_peak=maxf(crown_peak,appearance.crown_spring.value.length())
 check(crown_peak>.04,"Crown cards have a visible independent gait and airflow response")
 metrics["crown_peak_rad"]=crown_peak
 print("PLAYER_MOTION ",JSON.stringify({"fps":fps,"checks":checks,"failures":failures,"metrics":metrics}));lab.free();quit(0 if failures.is_empty() else 1)
