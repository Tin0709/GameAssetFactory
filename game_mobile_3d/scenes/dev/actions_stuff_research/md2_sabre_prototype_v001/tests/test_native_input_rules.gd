extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();root.add_child(a);a.set_physics_process(false)
	var s=a.combo
	s.cancel();s.request_attack();s.advance(.13);s.attack(true);s.advance(.10);s.attack(false);s.advance(.11)
	check(s.index==0 and s.phase==&"attack","Native early released tap cannot queue across RecoveryStart (captured counterexample)")
	check(s.buffer_until<0.,"Source ground attacks do not invent a220ms pending command")
	s.attack(true);s.advance(0.)
	check(s.index==1 and s.time==0.,"Fresh press after RecoveryStart immediately accepts the next variant")
	for index in 3:
		s.cancel();s._start_attack(index);s.attack(true)
		var gate:float=s.native_windows[index].chain/s.native_windows[index].rate
		s.advance(gate)
		check(s.index==(index+1)%3 and s.time<.00001,"Holding through native ability gate chains in order "+str(index))
	for hz in [30,60,120]:
		s.cancel();s.request_attack()
		for i in hz/2:
			if i==ceili(hz*.13):s.attack(true)
			if i==ceili(hz*.23):s.attack(false)
			s.advance(1./hz)
		check(s.index==0,"Rejected early tap stays rejected at "+str(hz))
	s.release_inputs();s.advance(3.)
	check(s.phase==&"ready" and not s.held,"Release/focus cannot produce a delayed ghost attack")
	print("SABRE_NATIVE_INPUT_RULES ",JSON.stringify({"checks":checks,"failures":failures}));a.free();quit(0 if failures.is_empty() else 1)
