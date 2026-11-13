extends "res://scenes/dev/zombie_death_physics/ragdoll.gd"

var _sample_bone_ids: Dictionary[String, int]
var _sample_body_offsets: Dictionary[String, Transform3D]

func setup(target: Skeleton3D, part_layout: Array = PARTS, bone_names: Dictionary = {},
		body_offsets: Dictionary = {}, authored_joints: Dictionary = {}) -> void:
	super.setup(target, part_layout, bone_names, body_offsets, authored_joints)
	_sample_bone_ids.clear()
	_sample_body_offsets.clear()
	for name: String in bodies:
		var body: PhysicalBone3D = bodies[name]
		_sample_bone_ids[name] = body.get_bone_id()
		_sample_body_offsets[name] = body.body_offset

func sample(delta: float) -> void:
	# Both dictionaries keep the same body keys, so the older buffer can be overwritten.
	var next := previous
	previous = current
	current = next
	sample_delta = delta
	var skeleton_transform := skeleton.global_transform
	for name: String in _sample_bone_ids:
		current[name] = (skeleton_transform * skeleton.get_bone_global_pose(_sample_bone_ids[name])
			* _sample_body_offsets[name])
	sample_count += 1

func release(visible_world_pose: Array[Transform3D] = []) -> void:
	super.release(visible_world_pose)
	_sample_bone_ids.clear()
	_sample_body_offsets.clear()
