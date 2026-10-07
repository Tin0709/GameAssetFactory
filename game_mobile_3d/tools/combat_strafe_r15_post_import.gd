@tool
extends EditorScenePostImport
## Preserve established imported clips; keep dense authored strafe channels only.
func _post_import(scene: Node) -> Object:
	var player:=scene.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var previous: PackedScene=load("res://assets/characters/r13/player_r13.glb")
	var old:=previous.instantiate()
	var old_player:=old.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var library:=player.get_animation_library("")
	for name in old_player.get_animation_list():
		if library.has_animation(name):library.remove_animation(name)
		library.add_animation(name,old_player.get_animation(name).duplicate(true))
	old.free()
	for name in ["Combat_StrafeLeft_V1","Combat_StrafeRight_V1"]:
		assert(library.has_animation(name))
		var clip:=library.get_animation(name)
		clip.loop_mode=Animation.LOOP_LINEAR
		for index in range(clip.get_track_count()-1,-1,-1):
			var path:=clip.track_get_path(index)
			var bone:=String(path.get_subname(0)) if path.get_subname_count()>0 else ""
			var type:=clip.track_get_type(index)
			var allowed:=type==Animation.TYPE_ROTATION_3D and bone in ["Hips","Leg.L","Leg.R","Spine"]
			allowed=allowed or (type==Animation.TYPE_POSITION_3D and bone in ["Hips","Leg.L","Leg.R"])
			if not allowed:clip.remove_track(index)
	return scene
