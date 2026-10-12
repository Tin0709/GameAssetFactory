extends SceneTree
var checks: Array=[]
var failures: Array=[]
var cases: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var scene=load("res://scenes/dev/ExpressiveLocomotionTest.tscn").instantiate();root.add_child(scene);current_scene=scene
	var actor=scene.actor;var v=actor.visual;actor.scripted_input=true
	for pace in [1.5,2.25]:
		for sprint in [false,true]:
			actor.requested_direction=Vector2.ZERO;scene.reset_actor();actor.position.x=-12;await scene.tick(50)
			actor.review_pace=pace;actor.requested_run=sprint;actor.requested_direction=Vector2(0,1);await scene.tick(45)
			var previous_rate: float=v.turn_rate;var worst_acceleration:=0.0;var distance:=0.0;var minimum_response:=100.0
			var trace: Array=[]
			for degrees in [90,-90,180,0,45,-45,180,90,-90,0,180,0]:
				actor.requested_direction=Vector2(sin(deg_to_rad(degrees)),cos(deg_to_rad(degrees)))
				var start: Vector3=actor.position
				for tick in 6:
					var old: Vector3=actor.position;var old_phase: float=v.gait_phase
					await scene.tick(1)
					worst_acceleration=maxf(worst_acceleration,absf(v.turn_rate-previous_rate)*60)
					distance+=actor.position.distance_to(old);previous_rate=v.turn_rate
					trace.append({"yaw":v.rotation.y,"rate":v.turn_rate,"phase_delta":wrapf(v.gait_phase-old_phase,-.5,.5),"position":actor.position})
				minimum_response=minf(minimum_response,actor.position.distance_to(start))
			actor.requested_direction=Vector2(0,1);await scene.tick(75)
			var final_error:=absf(wrapf(v.rotation.y,-PI,PI))
			cases.append({"pace":pace,"run":sprint,"maximum_yaw_acceleration":worst_acceleration,"distance":distance,"minimum_input_response":minimum_response,"final_heading_error":final_error,"trace":trace})
			check(worst_acceleration<120,"Spam turns avoid instantaneous full-speed yaw reversals")
			check(minimum_response>.015,"Every rapid input change keeps physical movement responsive")
			check(final_error<.015,"Visual facing settles to the requested heading without residual spin")
	var out:="res://.validation/expressive_turn_spin_v1";DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/rapid_turns.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases},"\t"))
	print("RAPID_TURN_CHECKS ",checks.size()," failures ",failures.size());quit(0 if failures.is_empty() else 1)
