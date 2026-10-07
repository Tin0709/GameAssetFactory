extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var p=load("res://scenes/characters/CuboidPlayer.tscn").instantiate();root.add_child(p)
	var v=p.visual;v.set_process(false);p.set_physics_process(false);p.get_node("WeaponBehavior").enabled=false
	var result:={"scope":"desktop headless existing visual _process only; not a phone or GPU benchmark","samples_per_case":4000,"cases":{}}
	for armed in [false,true]:
		v.equip_weapon(1);v.set_weapon_equipped(armed)
		for sprint in [false,true]:
			p.fast_sprinting=sprint;v.movement_speed=6.25 if sprint else 4.25;v.has_target=armed;v.move_weight=1
			for mode in 2:
				v.set_locomotion_mode(mode)
				for warmup in 100:v._process(1.0/120)
				var times:Array[int]=[]
				for sample in 4000:
					v.reference_yaw_rate=0.8;var start:=Time.get_ticks_usec();v._process(1.0/120);times.append(Time.get_ticks_usec()-start)
				times.sort();var total:=0
				for value in times:total+=value
				var label:="%s_%s_%s"%["Armed" if armed else "Free","Sprint" if sprint else "Walk","Reference" if mode else "Legacy"]
				result.cases[label]={"mean_usec":float(total)/times.size(),"median_usec":times[2000],"p95_usec":times[3800]}
	DirAccess.make_dir_recursive_absolute("res://.validation/locomotion_r6p")
	FileAccess.open("res://.validation/locomotion_r6p/performance.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));p.queue_free();await process_frame;quit()
