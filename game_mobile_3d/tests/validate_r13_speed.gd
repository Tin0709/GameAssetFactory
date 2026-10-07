extends SceneTree
const EXPECTED_SPEED: float=5.25
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		if failures.size()<=10:push_error(message)
func run() -> void:
	var level:=preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled=false
	level.get_node("Progression").enabled=false
	root.add_child(level);current_scene=level;level.select_test_weapon(0)
	var player: CharacterBody3D=level.player
	var v: Node3D=player.visual
	var b: Node=player.get_node("WeaponBehavior")
	player.set_physics_process(false);v.set_process(false);b.set_physics_process(false)
	player.get_node("Pistol").set_physics_process(false)
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/r13/source.json"))
	var duration:=46.0/24.0/EXPECTED_SPEED
	var completion_tick:=ceili(duration*60.0)
	check(is_equal_approx(v.draw_duration(),duration),"Draw must be 5.25x original speed: 0.365079 seconds")
	check(is_equal_approx(v.holster_duration(),duration),"Holster must be 5.25x original speed: 0.365079 seconds")
	check(is_equal_approx(b.holster_grace_seconds,1.5),"Awareness grace must stay unchanged")
	check(is_equal_approx(v.draw_event_time(&"WEAPON_BACK_RELEASE"),16.6/24.0/EXPECTED_SPEED),"Draw handoff must keep its native phase")
	check(is_equal_approx(v.holster_event_time(&"HOLSTER_RELEASE"),29.4/24.0/EXPECTED_SPEED),"Holster handoff must keep its native phase")
	for name: String in source.clips:
		var native: Dictionary=source.clips[name]
		var sampler: RefCounted=v.r13_samples[name]
		var speed:=EXPECTED_SPEED if name.begins_with("R13_") else 1.0
		check(is_equal_approx(sampler.clip.length,native.length/speed),"Playback duration: "+name)
		# Compare every source key, preserving the exact motion at the new speed.
		for index in native.samples.size():
			for bone_name: String in native.samples[index]:
				var bone: int=v.skeleton.find_bone(bone_name)
				var sample: Dictionary=native.samples[index][bone_name]
				var time: float=index/48.0/speed
				check(sampler.position(bone,time).distance_to(Vector3(sample.p[0],sample.p[1],sample.p[2]))<0.00001,"Position phase: "+name)
				check(absf(sampler.rotation(bone,time).dot(Quaternion(sample.q[0],sample.q[1],sample.q[2],sample.q[3])))>.99999,"Rotation phase: "+name)
	for weapon in 3:
		player.equip_test_weapon(weapon);b.threat_present=false
		for mode in [b.State.DRAWING,b.State.HOLSTERING]:
			b._begin(mode)
			for tick in range(1,completion_tick+1):
				b.transition_elapsed=minf(tick/60.0,duration)
				v._evaluate(0)
				if tick<completion_tick:check(b.state==mode,"Transition must not finish early")
				else:break
			check(b.state==(b.State.READY if mode==b.State.DRAWING else b.State.STOWED),"All weapons complete at the expected tick")
			check(v.socket.current_attachment==(&"hand" if mode==b.State.DRAWING else (&"hip" if weapon==0 else &"back")),"Correct final socket at accelerated speed")
	var report:={"speed":EXPECTED_SPEED,"duration_seconds":duration,"completion_tick":completion_tick,"checks":checks,"failures":failures}
	var file:=FileAccess.open("res://.validation/r13/speed_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("R13 SPEED: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
