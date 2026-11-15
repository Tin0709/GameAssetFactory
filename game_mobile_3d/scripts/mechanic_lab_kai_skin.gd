extends Node3D
## Private appearance shared by MechanicLab and WorldMap. The source actor owns the gameplay pose.

const Source := preload("res://scripts/mechanic_lab_weapon_source.gd")
const MODEL := "blender/khai_skin_v001/Kai_Survival_3D_Lab_v002.glb"
const SHA256 := "fd7e1f83f536a71ce31ab59139c65e2d841c8685f3dadb8f1422cc66d6035bfc"
const RUNS := ["Run", "CombatRun"]
const ACCESSORY_BONES := [&"J_Kai_Lantern_Sway", &"J_Headband_Tail_A", &"J_Headband_Tail_B"]
const LANTERN_MESH := &"Kai Run | MD2 metal lantern"
const CANOPY_SILHOUETTE := [
	&"Kai Run | Body", &"Kai Run | Face and expressions", &"Kai Run | Brown hair", &"Kai Run | Red headband",
]

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
var _lantern: MeshInstance3D
var _lantern_bone := -1
var _lantern_rest_point := Vector3.ZERO
var _lantern_base_gain := 0.

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
		if mesh.name == LANTERN_MESH:
			_lantern = mesh
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
	process_priority = actor.process_priority + 1
	hide()
	actor.add_child(self)
	_rig_offset = (global_transform.affine_inverse() * _rig.global_transform).affine_inverse()
	_lantern_bone = _rig.find_bone(ACCESSORY_BONES[0])
	if _lantern != null and _lantern_bone >= 0:
		var material := _lantern.get_active_material(0) as BaseMaterial3D
		if material != null:
			_lantern_base_gain = material.emission_energy_multiplier
		_lantern_rest_point = _rig.get_bone_global_rest(_lantern_bone).affine_inverse() \
			* _rig.to_local(_lantern.to_global(_lantern.get_aabb().get_center()))
	set_process(false)
	return true

func lantern_position() -> Vector3:
	if _lantern == null or _lantern_bone < 0:
		return Vector3.INF
	return _rig.to_global(_rig.get_bone_global_pose(_lantern_bone) * _lantern_rest_point)

func canopy_silhouette() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for mesh in meshes:
		if mesh.name in CANOPY_SILHOUETTE:
			result.append(mesh)
	return result

func set_lantern_receive_layers(mask: int) -> void:
	if _lantern != null:
		_lantern.layers = mask

func set_lantern_gain(multiplier: float) -> void:
	if _lantern == null:
		return
	var gain := _lantern_base_gain * multiplier
	var native := _lantern.mesh.surface_get_material(0) as BaseMaterial3D
	if native != null and not is_equal_approx(native.emission_energy_multiplier, gain):
		native.emission_energy_multiplier = gain
	var adapter := _lantern.get_active_material(0) as ShaderMaterial
	if adapter != null and not is_equal_approx(float(adapter.get_shader_parameter("glow_energy")), gain):
		adapter.set_shader_parameter("glow_energy", gain)

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
