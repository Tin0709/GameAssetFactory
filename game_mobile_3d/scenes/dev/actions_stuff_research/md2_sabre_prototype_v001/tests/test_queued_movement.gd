extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();root.add_child(a);a.set_physics_process(false)
	var s=a.combo;var config:Dictionary=a.runtime_locomotion_profile.combat;var delivery:Dictionary=config.movement_delivery
	for index in 3:
		s.cancel();s._start_attack(index);var w:Dictionary=config.windows[index]
		var gate:float=(ceilf(float(w.resume)/float(w.rate)*float(delivery.evaluation_hz)-.0000001)+float(delivery.consumer_ticks))/float(delivery.evaluation_hz)
		s.advance(float(w.resume)/float(w.rate)+.00001)
		check(not s.movement_allowed(),"Raw notify key does not anticipate its queued movement consumption")
		s.advance(gate-s.clock+.000001)
		check(s.movement_allowed(),"Movement opens at the observed evaluated/consumed gate")
		s.cancel();s._start_attack(index);s.held=true
		var chain:float=ceilf(float(w.chain)/float(w.rate)*s.native_event_hz-.0000001)/s.native_event_hz
		var open:=0.
		for segment:Dictionary in s.movement_plan(chain):
			if segment.move:open+=segment.duration
		check(absf(open-(chain-gate))<.000001,"Forecast and actual permission share the queued consumption boundary")
	for bad:Variant in [null,{}, {"schema":"wrong"}, {"schema":"private-queued-movement/1","evaluation_hz":false,"consumer_ticks":1}, {"schema":"private-queued-movement/1","evaluation_hz":NAN,"consumer_ticks":1}, {"schema":"private-queued-movement/1","evaluation_hz":120.,"consumer_ticks":.5}, {"schema":"private-queued-movement/1","evaluation_hz":1.,"consumer_ticks":4}]:
		var invalid:Dictionary=config.duplicate(true);invalid.movement_delivery=bad
		check(not s.configure_native(invalid),"Malformed or overlong optional delivery configuration fails closed")
	var old:Dictionary=config.duplicate(true);old.erase("movement_delivery")
	check(s.configure_native(old),"Older sidecar preserves raw-gate compatibility")
	s.cancel();s._start_attack(0);s.advance(float(old.windows[0].resume)/float(old.windows[0].rate))
	check(s.movement_allowed(),"Explicit old policy remains available for A/B comparison")
	print("SABRE_QUEUED_MOVEMENT ",JSON.stringify({"checks":checks,"failures":failures}));a.free();quit(0 if failures.is_empty() else 1)
