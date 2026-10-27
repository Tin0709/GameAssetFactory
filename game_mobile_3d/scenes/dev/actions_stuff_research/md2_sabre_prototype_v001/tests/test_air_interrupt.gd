extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();root.add_child(a);a.set_physics_process(false)
	var config:Dictionary=a.runtime_locomotion_profile.combat.duplicate(true)
	for index in 3:
		for recovery:bool in [false,true]:
			var s=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/combo_state.gd").new();s.setup(a.clips);s.configure_native(config)
			s._start_attack(index);s.advance(.03)
			if recovery:s.phase=&"recovery";s.time=.01
			var serial:int=s.serial;s.attack(true,true)
			check(s.phase==&"air_attack" and s.serial==serial+1,"Fresh aerial press can interrupt ground attack/recovery without its ground combo gate")
			check(s.clip()=="AirAttack" and s.time==0.,"Accepted aerial input starts the existing air clip on its own source clock")
			s.advance(.01);s.attack(true,true)
			check(s.serial==serial+1,"Held aerial input is not a repeated fresh press")
			s.release_inputs();s.advance(3.)
			check(not s.active() and not s.held,"Released aerial interruption cannot leave a ghost ground chain")
	var s=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/combo_state.gd").new();s.setup(a.clips)
	config.input.airborne_press_interrupts_ground="bad"
	check(not s.configure_native(config),"Malformed optional interrupt flag fails closed")
	config=a.runtime_locomotion_profile.combat.duplicate(true);config.input.erase("airborne_press_interrupts_ground")
	check(s.configure_native(config),"Older private sidecars remain supported")
	s._start_attack(0);s.attack(true,true)
	check(s.phase==&"attack","Absent evidence opt-in preserves earlier behavior")
	print("SABRE_AIR_INTERRUPT ",JSON.stringify({"checks":checks,"failures":failures}));a.free();quit(0 if failures.is_empty() else 1)
