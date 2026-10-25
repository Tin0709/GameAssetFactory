extends SceneTree
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:
	var path:="res://scenes/dev/actions_stuff_research/sword_combat_v001/combat_state.gd"
	if not ResourceLoader.exists(path):push_error("Missing original Sword combat state machine");quit(1);return
	var Script=load(path)
	for fps in [30,60]:
		var s=Script.new();s.request_attack();check(s.state==&"attack" and s.attack_index==0,"First press starts first attack")
		s.tick(.05,1.);s.request_attack()
		for i in fps:s.tick(1./fps,1.)
		check(s.state==&"ready","Early input expires instead of ghost chaining")
		s.reset();s.request_attack();s.tick(.48,1.);s.request_attack();s.tick(.12,1.)
		check(s.state==&"attack" and s.attack_index==1,"One buffered input chains second attack")
		s.tick(.37,1.);s.request_attack();s.tick(.13,1.)
		check(s.attack_index==2,"Buffered second attack reaches finisher")
		s.tick(1.,1.);check(s.state==&"ready","Finisher recovers without endless combo")
		s.request_attack();s.tick(.4,1.);check(s.overlaps_active(),"Crossing active interval at coarse FPS remains detectable")
		s.cancel();check(not s.overlaps_active() and not s.has_buffer(),"Cancellation clears damage window and input")
		s.request_guard(true);check(s.can_parry(),"Guard entry opens timed parry")
		s.tick(.25,1.);check(not s.can_parry() and s.state==&"guard","Held guard outlasts parry window")
		s.request_attack();s.tick(1.,1.);check(s.state==&"guard" and s.guard_held,"Held guard resumes after attack recovery")
		s.request_guard(false);check(s.request_roll(),"Ready can roll")
		s.tick(.12,1.);check(s.invulnerable(),"Roll invulnerability is timed")
		s.tick(.45,1.);check(not s.invulnerable(),"Roll recovery is vulnerable")
		s.cancel();check(not s.request_roll(),"Switch/cancel cannot reset roll cooldown")
		s.reset();s.request_attack();s.tick(.3,1.,true);check(s.time==0.,"Local hit-stop freezes attack clock")
		check(s.clock>.29,"Buffer/cooldown wall clock still advances during hit-stop")
	print("SWORD_STATE_CHECKS ",JSON.stringify({"failures":failures,"fps":[30,60]}));quit(0 if failures.is_empty() else 1)
