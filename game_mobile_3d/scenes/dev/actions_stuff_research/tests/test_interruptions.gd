extends SceneTree
var cases: Array=[]
var results: Array=[]
func _initialize():call_deferred("run")
func make_scene():
 var s=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(s)
 s.player.scripted_input=true;s.player.set_physics_process(false);s.player.visual.set_process(false)
 return s
func measure(v, prev: Array, stats: Dictionary):
 for side in 2:
  var bone: int=[v.leg_left,v.leg_right][side]
  var q: Quaternion=v.skeleton.get_bone_pose_rotation(bone)
  if prev.size()==2:stats.step=maxf(stats.step,rad_to_deg(q.angle_to(prev[side])))
  stats.min_y=minf(stats.min_y,v._sole_world(bone).y)
  stats.max_scale=maxf(stats.max_scale,v.skeleton.get_bone_pose_scale(bone).y)
 prev.clear();prev.append(v.skeleton.get_bone_pose_rotation(v.leg_left));prev.append(v.skeleton.get_bone_pose_rotation(v.leg_right))
func sim(s, dir: Vector2, sprint: bool, count: int, dt: float, prev: Array,stats: Dictionary):
 var actor=s.player;var v=actor.visual
 for i in count:
  var desired: Vector2=dir.limit_length()*(actor.run_speed if sprint else actor.walk_speed)
  var planar:=Vector2(actor.velocity.x,actor.velocity.z).move_toward(desired,(actor.deceleration if dir.is_zero_approx() else actor.acceleration)*dt)
  actor.velocity=Vector3(planar.x,0,planar.y);actor.position+=actor.velocity*dt;actor.current_speed=planar.length()
  v.drive_locomotion(actor.velocity,not dir.is_zero_approx(),dt);v._evaluate(dt)
  measure(v,prev,stats)
func run():
 for fps in [30,60]:
  var dt: float=1./fps
  for k in 16:
   var s=make_scene();var v=s.player.visual;var prev: Array=[]
   var st={"fps":fps,"phase_index":k,"step":0.,"min_y":INF,"max_scale":1.}
   sim(s,Vector2(0,1),true,int(2./dt)+k,dt,prev,st)
   st.stop_phase=v.gait_phase
   sim(s,Vector2.ZERO,false,int(1.1/dt),dt,prev,st)
   st.clamps=v.correction_clamps;st.correction=v.maximum_correction;st.settled=not v.settling;st.final_scale=v.skeleton.get_bone_pose_scale(v.leg_left).y
   results.append(st);s.free()
  for kind in ["reverse","turn90","taps","held_reset","idle_reset","shift_pulse"]:
   var s=make_scene();var v=s.player.visual;var prev: Array=[]
   var st={"fps":fps,"case":kind,"step":0.,"min_y":INF,"max_scale":1.}
   sim(s,Vector2(0,1),true,int(2./dt),dt,prev,st)
   if kind=="held_reset":s.reset_player();sim(s,Vector2(0,1),true,int(1./dt),dt,prev,st)
   elif kind=="idle_reset":sim(s,Vector2.ZERO,false,int(1./dt),dt,prev,st);s.reset_player();sim(s,Vector2.ZERO,false,int(.5/dt),dt,prev,st)
   elif kind=="reverse":sim(s,Vector2(0,-1),true,int(1./dt),dt,prev,st)
   elif kind=="turn90":sim(s,Vector2(1,0),true,int(1./dt),dt,prev,st)
   elif kind=="taps":
    for i in 12:
     sim(s,Vector2.ZERO,false,2,dt,prev,st);sim(s,Vector2(0,-1) if i%2 else Vector2(1,0),i%2==0,2,dt,prev,st)
   elif kind=="shift_pulse":
    for i in 16:sim(s,Vector2(0,1),i%2==0,2,dt,prev,st)
   sim(s,Vector2.ZERO,false,int(1./dt),dt,prev,st)
   st.clamps=v.correction_clamps;st.correction=v.maximum_correction;st.settled=not v.settling;st.final_scale=v.skeleton.get_bone_pose_scale(v.leg_left).y
   results.append(st);s.free()
 FileAccess.open("user://actions_stuff_interruptions.json",FileAccess.WRITE).store_string(JSON.stringify(results," "))
 var maxstep:=0.;var miny:=INF;var clamps:=0
 for st in results:maxstep=maxf(maxstep,st.step);miny=minf(miny,st.min_y);clamps+=st.clamps
 var passed:=miny>-.001 and maxstep<65.
 for st in results:passed=passed and st.settled and absf(st.final_scale-1.)<.0001
 if not passed:push_error("Rapid input changes must retain floor clearance and bounded leg rotation")
 print("INTERRUPTION_TEST ",JSON.stringify({"passed":passed,"cases":results.size(),"maxstep":maxstep,"min_y":miny,"clamps":clamps}));quit(0 if passed else 1)
