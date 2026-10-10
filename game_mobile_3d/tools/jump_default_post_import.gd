@tool
extends EditorScenePostImport
func _post_import(scene: Node) -> Object:
	var player:=scene.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var old: Node=load("res://assets/characters/r15/player_r15_combat_strafe_v1.glb").instantiate()
	var old_player:=old.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var library:=player.get_animation_library("")
	for name in old_player.get_animation_list():
		if library.has_animation(name):library.remove_animation(name)
		library.add_animation(name,old_player.get_animation(name).duplicate(true))
	old.free()
	assert(library.has_animation("Jump_Default_v001"))
	library.get_animation("Jump_Default_v001").loop_mode=Animation.LOOP_NONE
	return scene
