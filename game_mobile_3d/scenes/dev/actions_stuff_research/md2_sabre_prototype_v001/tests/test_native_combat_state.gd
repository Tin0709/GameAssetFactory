extends SceneTree
const Combo=preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/combo_state.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var actor=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();root.add_child(actor);actor.set_physics_process(false)
	var s=actor.combo;var config:Dictionary=actor.runtime_locomotion_profile.combat
	check(s.has_method("movement_plan"),"Combo exposes event-delimited movement planning")
	if s.has_method("movement_plan"):
		check(s.native_enabled,"Normal source profile activates native event policy")
		for index in 3:
			s.cancel();s._start_attack(index);s.held=true
			var w:Dictionary=config.windows[index];var rate:float=w.rate;var unlock:float=w.resume/rate;var chain:float=w.chain/rate
			var plan:Array=s.movement_plan(chain)
			var open:=0.
			for segment:Dictionary in plan:
				if segment.move:open+=float(segment.duration)
			check(absf(open-(chain-unlock))<.000001,"Per-strike open time comes from notify gates "+str(index))
			s.advance(unlock-.0001);check(not s.movement_allowed(),"Windup blocks travel "+str(index));s.advance(.0001);check(s.movement_allowed(),"ResumeMovement opens travel "+str(index))
			s.advance(chain-unlock);check(s.index==(index+1)%3 and s.phase==&"attack" and absf(s.time)<.00001,"RecoveryStart chains directly without fixed-distance step "+str(index))
			check(not s.movement_allowed(),"Next strike owns a new windup lock "+str(index))
		for hz in [30,60,120]:
			s.cancel();s.attack(true);var travel_time:=0.;var accepted:Array=[]
			for i in hz*4:
				for segment:Dictionary in s.movement_plan(1./hz):
					if segment.move:travel_time+=float(segment.duration)
				s.advance(1./hz)
				for event:Dictionary in s.drain_events():
					if event.kind=="accepted":accepted.append([event.index,event.at])
			check(accepted.size()>6 and accepted.slice(0,3).map(func(x):return x[0])==[0,1,2],"Held chain retains ordered1/2/3 at "+str(hz))
			var oracle=Combo.new();oracle.setup(actor.clips);oracle.configure_native(config);oracle.attack(true)
			var expected_time:=0.
			for segment:Dictionary in oracle.movement_plan(4.):
				if segment.move:expected_time+=float(segment.duration)
			oracle.advance(4.)
			check(absf(travel_time-expected_time)<.00001 and s.index==oracle.index and absf(s.time-oracle.time)<.00001,"Permission integral and overshoot independent of physics rate "+str(hz))
		# Release does not enqueue surprise attacks; late queue executes at the
		# native gate or immediately if that gate has already passed.
		s.cancel();s.attack(true);s.attack(false);s.advance(.18);s.request_attack();s.advance(.16)
		check(s.index==1 and s.phase==&"attack","One bounded tap queues the next strike")
		s.release_inputs();s.advance(2.);check(s.phase==&"ready" and not s.held,"Focus/release clears future links")
		s.cancel();s.request_attack();s.advance(.36);s.request_attack();s.advance(0.)
		check(s.index==1 and s.time==0.,"Press after opened gate begins next strike without waiting for full recovery")
		s.cancel();s.request_attack();s.advance(.01);s.request_attack();s.advance(.33)
		check(s.index==0,"Expired220ms adapter tap cannot become a ghost combo")
	print("SABRE_NATIVE_COMBAT_STATE ",JSON.stringify({"checks":checks,"failures":failures}));actor.free();quit(0 if failures.is_empty() else 1)
