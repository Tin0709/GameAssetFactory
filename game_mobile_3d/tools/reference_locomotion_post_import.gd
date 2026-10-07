@tool
extends EditorScenePostImport
## Dedicated v5 import. Preserve exact v4 native clips; keep dense new locomotion.
func _post_import(scene: Node) -> Object:
	var player:=scene.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var prior:PackedScene=load("res://assets/characters/player_cuboid_animated_v4.glb")
	var old:=prior.instantiate()
	var old_player:=old.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var library:=player.get_animation_library("")
	for name in old_player.get_animation_list():
		if library.has_animation(name):library.remove_animation(name)
		library.add_animation(name,old_player.get_animation(name).duplicate(true))
	old.free()
	for name in ["Walk","WalkTurnLeft","WalkTurnRight","Sprint","SprintTurnLeft","SprintTurnRight"]:
		assert(player.has_animation(name),"Missing reference animation "+name)
		var clip:=player.get_animation(name);clip.loop_mode=Animation.LOOP_LINEAR
		for t in range(clip.get_track_count()-1,-1,-1):
			if clip.track_get_type(t)==Animation.TYPE_SCALE_3D:clip.remove_track(t)
	return scene
