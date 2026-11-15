extends Node3D
## MechanicLab-only appearance. The source actor still owns gameplay and weapon sockets.

const Source := preload("res://scripts/mechanic_lab_weapon_source.gd")
const MODEL := "blender/khai_skin_v001/Kai_Survival_3D_Lab.glb"
const SHA256 := "b5909604ad5fcf8e28e27755316db281ced17b4c006f51af036b4f524faa4bd6"
const RUNS := ["Run", "CombatRun"]
const ACCESSORY_BONES := [&"J_Kai_Rope_Sway", &"J_Headband_Tail_A", &"J_Headband_Tail_B"]

var meshes: Array[MeshInstance3D] = []
var _actor: CharacterBody3D
var _rig: Skeleton3D
var _face: MeshInstance3D
var _focus_shape := -1
var _blink_shape := -1
var _run: Animation
var _run_tracks: Dictionary[int, int] = {}
var _source_bones := PackedInt32Array()
var _rest_corrections: Array[Transform3D] = []
var _poses: Array[Transform3D] = []
var _rig_offset: Transform3D
var _sway_weight := 0.0

static func source_available() -> bool:
	return OS.has_feature("editor") and FileAccess.file_exists(Source.research_root().path_join(MODEL))

func setup(actor: CharacterBody3D) -> bool:
	var path := Source.verified_path(Source.research_root(), MODEL, SHA256)
	if path.is_empty():
		return false
	var asset: Node3D = actor.load_private_model(path)
	if asset == null:
		return false
	add_child(asset)
	var rigs := asset.find_children("*", "Skeleton3D", true, false)
	var players := asset.find_children("*", "AnimationPlayer", true, false)
	if rigs.size() != 1 or players.size() != 1:
		return false
	_actor = actor
	_rig = rigs[0] as Skeleton3D
	var animation := players[0] as AnimationPlayer
	var clips := animation.get_animation_list()
	if clips.size() != 1:
		return false
	_run = animation.get_animation(clips[0])
	if not is_equal_approx(_run.length, 0.625):
		return false
	# The clip supplies only accessory rotations. The live pose supplies all other bones.
	for track in _run.get_track_count():
		var bone_name := _run.track_get_path(track).get_concatenated_subnames()
		var bone := _rig.find_bone(bone_name)
		if bone < 0 or bone_name not in ACCESSORY_BONES or _run.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			return false
		_run_tracks[bone] = track
	if _run_tracks.size() != ACCESSORY_BONES.size():
		return false
	animation.free()

	var source_rig: Skeleton3D = actor.skeleton
	for bone in _rig.get_bone_count():
		var source := source_rig.find_bone(_rig.get_bone_name(bone))
		_source_bones.append(source)
		var correction := Transform3D.IDENTITY
		if source >= 0:
			correction = source_rig.get_bone_global_rest(source).affine_inverse() * _rig.get_bone_global_rest(bone)
		elif not _run_tracks.has(bone):
			return false
		_rest_corrections.append(correction)
	_poses.resize(_rig.get_bone_count())

	for mesh: MeshInstance3D in asset.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or mesh.skin == null or mesh.get_node_or_null(mesh.skeleton) != _rig:
			return false
		meshes.append(mesh)
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			if material != null:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		if mesh.mesh.get_blend_shape_count() > 0:
			_face = mesh
			_focus_shape = mesh.find_blend_shape_by_name(&"Focused")
			_blink_shape = mesh.find_blend_shape_by_name(&"Blink")
	if meshes.is_empty() or _focus_shape < 0 or _blink_shape < 0:
		return false

	name = "KaiAppearance"
	top_level = true
	hide()
	actor.add_child(self)
	_rig_offset = (global_transform.affine_inverse() * _rig.global_transform).affine_inverse()
	set_process(false)
	return true

func show_skin(active: bool) -> void:
	if active:
		_sway_weight = _run_strength()
		_process(0.0)
	visible = active
	set_process(active)

func _run_strength() -> float:
	if _actor.is_dead or not _actor.is_on_floor() or _actor.active_clip not in RUNS:
		return 0.0
	return smoothstep(_actor.walk_speed, _actor.run_speed * 0.9, _actor.current_speed)

func _process(delta: float) -> void:
	var presenter: Node = _actor.render_presenter
	if presenter.display_world.is_empty():
		return
	# Follow the same interpolated source pose as the weapon, including aim and hit reactions.
	var previous_rig: Transform3D = presenter.previous.rig
	var current_rig: Transform3D = presenter.current.rig
	var rig_world := previous_rig.interpolate_with(current_rig, presenter.render_alpha)
	global_transform = rig_world * _rig_offset
	var local_from_world := rig_world.affine_inverse()
	_sway_weight = move_toward(_sway_weight, _run_strength(), delta / 0.12)
	var phase := fposmod(_actor._gait_resume_phase - _actor._gait_cycles_this_tick
		* (1.0 - presenter.render_alpha), 1.0)
	for bone in _source_bones.size():
		var parent := _rig.get_bone_parent(bone)
		var parent_pose := Transform3D.IDENTITY if parent < 0 else _poses[parent]
		var source := _source_bones[bone]
		if source >= 0:
			_poses[bone] = local_from_world * Transform3D(presenter.display_world[source]) * _rest_corrections[bone]
			if absf(parent_pose.basis.determinant()) > 0.000001:
				_rig.set_bone_pose(bone, parent_pose.affine_inverse() * _poses[bone])
			else:
				# Ranged clips can collapse an unused weapon branch to zero scale.
				var previous_pose: Transform3D = presenter.previous.poses[source]
				var current_pose: Transform3D = presenter.current.poses[source]
				_rig.set_bone_pose(bone, previous_pose.interpolate_with(current_pose, presenter.render_alpha))
		else:
			var rest := _rig.get_bone_rest(bone)
			_rig.set_bone_pose(bone, rest)
			if _sway_weight > 0.0:
				var rotation := _run.rotation_track_interpolate(_run_tracks[bone], phase * _run.length)
				_rig.set_bone_pose_rotation(bone, rest.basis.get_rotation_quaternion().slerp(rotation, _sway_weight))
			_poses[bone] = parent_pose * _rig.get_bone_pose(bone)
	_face.set_blend_shape_value(_focus_shape, _actor.focus_value)
	_face.set_blend_shape_value(_blink_shape, _actor.blink_value)

