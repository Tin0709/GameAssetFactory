extends SceneTree
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
 if not ok:failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var path:="res://scenes/dev/actions_stuff_research/turn_in_place_v001/source_turn_controller.gd"
 check(ResourceLoader.exists(path),"Source turn controller is implemented")
 if not ResourceLoader.exists(path):quit(1);return
 var Runtime=load(path)
 var report:=[]
 for fps in [30,60]:
  for angle in [25.,90.,-90.,180.]:
   var c=Runtime.new();c.seed_heading(0.)
   var max_body:=0.;var steps:=0;var previous:="";var phase:=0.;var lift_layers:=false
   for i in fps*3:
    var s=c.step_turn(-angle,false,1./fps)
    if s.state=="vywhcj" and previous!="vywhcj":steps+=1
    previous=s.state;max_body=maxf(max_body,absf(s.body_degrees));phase=s.phase
    for layer in s.layers:lift_layers=lift_layers or layer.controller_weight>0.
   if absf(angle)<60.:
    check(steps==0 and max_body<.001,"Small head turns do not walk or spin the feet")
   else:
    check(steps>=1 and lift_layers,"Large turns use actual weighted corrective clips")
    check(absf(wrapf(c.env["v.nthjcy"]+angle,-180,180))<.1,"Turn reaches requested heading")
    if angle==180.:check(steps==2,"180-degree turn chains two source 90-degree steps")
   check(absf(phase)<.0001,"Stationary turns never advance locomotion gait")
   report.append({"fps":fps,"angle":angle,"steps":steps,"max_body":max_body})
  var c=Runtime.new();c.seed_heading(0.)
  for i in 10:c.step_turn(-90.,false,1./fps)
  var phase_before: float=c.env["v.eqhdel"]
  var interrupted=c.step_turn(-90.,true,1./fps)
  check(interrupted.state=="default","Movement interrupts turn on its first tick")
  check(is_equal_approx(phase_before,c.env["v.eqhdel"]),"Turn interruption does not reset shared gait")
  for i in fps*2:
   var s=c.step_turn(100. if i%(fps/2)<fps/4 else -100.,false,1./fps)
   check(is_finite(s.body_degrees),"Rapid alternating turns stay finite")
 print("TURN_SOURCE ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":report}))
 quit(0 if failures.is_empty() else 1)
