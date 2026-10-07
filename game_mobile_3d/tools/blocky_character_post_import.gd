@tool
extends EditorScenePostImport
## Only the dedicated authored asset uses this hook.
func _post_import(scene: Node) -> Object:
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(player != null)
	if player.has_animation("LongGunReadyIdle"):
		# v4 disables the generic key optimizer to preserve subtle Ready motion.
		# Reuse the exact previous native clips so locomotion/transitions retain
		# their established import interpolation and key reduction as well.
		var previous: PackedScene = load("res://assets/characters/player_cuboid_animated_v3.glb")
		var previous_model := previous.instantiate()
		var previous_player := previous_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var library := player.get_animation_library("")
		for name in ["Idle", "Run", "DrawLongGun", "HolsterLongGun"]:
			library.remove_animation(name)
			library.add_animation(name, previous_player.get_animation(name).duplicate(true))
		previous_model.free()
	for name in ["Idle", "Run", "LongGunReadyIdle", "LongGunReadyRun"]:
		if name.begins_with("LongGunReady") and not player.has_animation(name): continue
		assert(player.has_animation(name), "Missing authored clip: " + name)
		player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	# Godot can synthesize rest tracks for animated descendants. Preserve this
	# authored clip's strict upper-body mask after import as well as in the GLB.
	for clip_name in ["HolsterLongGun", "DrawLongGun", "LongGunReadyIdle", "LongGunReadyRun"]:
		if not player.has_animation(clip_name): continue
		var holster := player.get_animation(clip_name)
		var mask := ["Spine", "Chest", "Arm.L", "Arm.R", "Neck", "Head", "WeaponCarrier"]
		for track in range(holster.get_track_count()-1, -1, -1):
			var path := holster.track_get_path(track)
			if path.get_subname_count()==0 or str(path.get_subname(0)) not in mask or holster.track_get_type(track) not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D]:
				holster.remove_track(track)
	return scene
