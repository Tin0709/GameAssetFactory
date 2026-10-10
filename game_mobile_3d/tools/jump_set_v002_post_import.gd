@tool
extends EditorScenePostImport
func _post_import(scene: Node) -> Object:
	var player:=scene.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var old: Node=load("res://assets/characters/jump_default_v001/player_r15_jump_default_v001.glb").instantiate()
	var old_player:=old.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var library:=player.get_animation_library("")
	for name in old_player.get_animation_list():
		if library.has_animation(name):library.remove_animation(name)
		library.add_animation(name,old_player.get_animation(name).duplicate(true))
	old.free()
	for name in ["Jump_Stationary_v002","Jump_Walk_v002","Jump_Run_v002"]:
		assert(library.has_animation(name))
		library.get_animation(name).loop_mode=Animation.LOOP_NONE
	return scene
