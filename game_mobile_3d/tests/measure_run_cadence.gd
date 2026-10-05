extends SceneTree
const Sampler = preload("res://scripts/animation_pose_sampler.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model = preload("res://assets/characters/player_cuboid_animated_v1.glb").instantiate()
	root.add_child(model)
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	player.stop()
	var sample = Sampler.new(player.get_animation("Run"), skeleton)
	var data := []
	var matrices: Array[Transform3D] = []
	matrices.resize(skeleton.get_bone_count())
	for f in 641:
		var t: float = sample.clip.length * f / 640.0
		for i in skeleton.get_bone_count():
			var local := Transform3D(Basis(sample.rotation(i,t)),sample.position(i,t))
			var parent := skeleton.get_bone_parent(i)
			matrices[i] = matrices[parent] * local if parent >= 0 else local
		var feet := {}
		for name in ["Leg.L", "Leg.R"]:
			var transform := matrices[skeleton.find_bone(name)]
			var point := transform * Vector3(0,0.675,0)
			var min_y := INF
			for z in [-0.1125,0.1125]:
				for x in [-0.1125,0.1125]:min_y=minf(min_y,(transform * Vector3(x,0.675,z)).y)
			feet[name] = {"z":point.z,"y":point.y,"minimum_y":min_y}
		data.append({"time":t,"feet":feet})
	var file := FileAccess.open("res://tests/run_cadence_samples.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"duration":sample.clip.length,"forward":"+Z","samples":data}));file.close()
	print("RUN_CADENCE_SAMPLED=641")
	quit()
