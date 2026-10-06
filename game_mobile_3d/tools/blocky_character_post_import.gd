@tool
extends EditorScenePostImport
## Only the dedicated authored asset uses this hook.
func _post_import(scene: Node) -> Object:
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(player != null)
	for name in ["Idle", "Run"]:
		assert(player.has_animation(name), "Missing authored clip: " + name)
		player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	# Godot can synthesize rest tracks for animated descendants. Preserve this
	# authored clip's strict upper-body mask after import as well as in the GLB.
	if player.has_animation("HolsterLongGun"):
		var holster := player.get_animation("HolsterLongGun")
		var mask := ["Spine", "Chest", "Arm.L", "Arm.R", "Neck", "Head", "WeaponCarrier"]
		for track in range(holster.get_track_count()-1, -1, -1):
			var path := holster.track_get_path(track)
			if path.get_subname_count()==0 or str(path.get_subname(0)) not in mask or holster.track_get_type(track) not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D]:
				holster.remove_track(track)
	return scene
