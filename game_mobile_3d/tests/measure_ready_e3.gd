extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var level := preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled = false; level.get_node("Progression").enabled = false
	root.add_child(level); current_scene = level; level.select_test_weapon(1)
	var p: CharacterBody3D = level.player
	var v: Node3D = p.visual
	p.get_node("WeaponBehavior").enabled = false
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var report := {"phone_tested":false,"warm_iterations":200,"measured_iterations":3000,"cpu_pose_usec":{}}
	for context in ["Idle","Walk","Run"]:
		v.update_motion(Vector3.RIGHT*({"Idle":0.0,"Walk":4.25,"Run":6.25}[context]),null,1.0/60.0)
		for mode in [0,1]:
			v.ready_animation_mode = mode
			for i in 200: v._process(1.0/60.0)
			var started := Time.get_ticks_usec()
			for i in 3000: v._process(1.0/60.0)
			report.cpu_pose_usec[context+"_"+("legacy" if mode == 0 else "living")] = float(Time.get_ticks_usec()-started)/3000
	var file := FileAccess.open("res://tests/ready_e3_performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print(JSON.stringify(report)); quit()
