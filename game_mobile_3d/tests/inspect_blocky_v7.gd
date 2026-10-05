extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var results := []
	for path in ["res://assets/characters/player_animation_v2.glb", "res://assets/characters/player_cuboid_animated_v1.glb"]:
		var model = load(path).instantiate()
		root.add_child(model)
		var sk = model.find_child("Skeleton3D", true, false)
		var ap = model.find_child("AnimationPlayer", true, false)
		var bones := []
		for i in sk.get_bone_count():
			bones.append({"name":sk.get_bone_name(i),"parent":sk.get_bone_parent(i),"rest":str(sk.get_bone_rest(i))})
		var clips := {}
		for name in ap.get_animation_list():
			var a = ap.get_animation(name)
			clips[name]={"length":a.length,"loop":a.loop_mode,"first_path":str(a.track_get_path(0)) if a.get_track_count()>0 else ""}
		results.append({"path":path,"bones":bones,"clips":clips})
		model.queue_free()
	print("BLOCKY_IMPORT_INSPECTION="+JSON.stringify(results))
	quit()
