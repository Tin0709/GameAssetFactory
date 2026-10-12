extends SceneTree
var checks: Array=[]
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var versions: Array=[]
	for enabled in [false,true]:
		var scene=load("res://scenes/dev/ExpressiveLocomotionTest.tscn").instantiate()
		root.add_child(scene);current_scene=scene;scene.actor.scripted_input=true
		if scene.actor.visual.get("heavier_landing")!=null:scene.actor.visual.heavier_landing=enabled
		await scene.tick(8)
		var still: Dictionary=await scene._jump_case(self,"Stationary",Vector2.ZERO,false)
		var running: Dictionary=await scene._jump_case(self,"Running",Vector2(0,1),true)
		versions.append({"stationary":still,"running":running,"max_penetration":scene._jump_floor_error,"max_joint_step":scene._jump_max_step,"phase_error":scene._maximum_flight_phase_error,"speed":scene.actor.current_speed})
		check(scene._jump_floor_error<.008,"Planted soles stay clear in landing comparison")
		check(scene.actor.current_speed>3.4,"Compression never slows horizontal Run")
		check(scene._maximum_flight_phase_error<.03,"Compression never resets the gait clock")
		scene.queue_free();await process_frame
	var still_gain: float=versions[0].stationary.impact_hip_min-versions[1].stationary.impact_hip_min
	var run_gain: float=versions[0].running.impact_hip_min-versions[1].running.impact_hip_min
	check(still_gain>.012,"Stationary landing has a measurably deeper hip dip")
	check(run_gain>.025,"Running landing has at least25mm additional compression")
	check(run_gain>still_gain+.008,"Running compression strengthens more than stationary compression")
	check(absf(versions[0].running.flight_seconds-versions[1].running.flight_seconds)<.001,"Landing refinement leaves physical flight timing unchanged")
	check(absf(versions[0].running.peak_y-versions[1].running.peak_y)<.001,"Landing refinement adds no duplicate jump trajectory")
	var out:="res://.validation/expressive_jump_heavier_landing_v1";DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/comparison.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"versions":versions,"stationary_extra_drop_m":still_gain,"running_extra_drop_m":run_gain},"\t"))
	print("EXPRESSIVE_LANDING_CHECKS ",checks.size()," failures ",failures.size())
	quit(0 if failures.is_empty() else 1)
