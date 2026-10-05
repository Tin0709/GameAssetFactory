extends "res://scripts/player_animation_v2.gd"
## Import adapter only; V2 remains the sole pose writer. The legacy GLB supplies
## unchanged Walk/weapon clips and its non-deforming socket, never a second rig.
const LEGACY = preload("res://assets/characters/player_animation_v2.glb")

func _ready() -> void:
	var source := LEGACY.instantiate()
	var old_skeleton := source.find_child("Skeleton3D", true, false) as Skeleton3D
	var new_skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	var old_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var new_player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(new_player.has_animation("Idle") and new_player.has_animation("Run"))
	for i in new_skeleton.get_bone_count():
		var old_index := old_skeleton.find_bone(new_skeleton.get_bone_name(i))
		assert(old_index >= 0 and new_skeleton.get_bone_rest(i).is_equal_approx(old_skeleton.get_bone_rest(old_index)), "Incompatible legacy rest basis")
	# Existing weapon handling requires this non-deforming attachment. Preserve
	# its original rest frame under Chest; no mesh skin weights refer to this bone.
	var old_socket := old_skeleton.find_bone("WeaponSocket")
	assert(old_socket >= 0 and new_skeleton.find_bone("WeaponSocket") < 0)
	new_skeleton.add_bone("WeaponSocket")
	var new_socket := new_skeleton.find_bone("WeaponSocket")
	new_skeleton.set_bone_parent(new_socket, new_skeleton.find_bone("Chest"))
	new_skeleton.set_bone_rest(new_socket, old_skeleton.get_bone_rest(old_socket))
	new_skeleton.reset_bone_pose(new_socket)
	var library := new_player.get_animation_library("")
	for name in old_player.get_animation_list():
		library.add_animation(name, old_player.get_animation(name).duplicate(true))
	source.free()
	super._ready()
