@tool
extends EditorScenePostImport
func _post_import(scene: Node) -> Object:
	var player:=scene.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var old:Node=load("res://assets/characters/jump_set_v002/player_r15_jump_set_v002.glb").instantiate()
	var old_player:=old.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var library:=player.get_animation_library("")
	# Preserve production import masks and weapon timings, not just raw GLB keys.
	for name in old_player.get_animation_list():
		if library.has_animation(name):library.remove_animation(name)
		library.add_animation(name,old_player.get_animation(name).duplicate(true))
	old.free()
	for name in ["Jump_Walk_Loop_v003","Jump_Run_Loop_v003"]:
		assert(library.has_animation(name))
		library.get_animation(name).loop_mode=Animation.LOOP_LINEAR
	return scene
