extends RefCounted

const SOURCE_PATH := "res://scenes/dev/actions_stuff_research/zombie_combat/source_library.res"
const Pack := preload("res://scripts/mechanic_lab_zombie_actions_pack.gd")
const IDLE := &"Zombie_AS_Idle"
const MOVE := &"Zombie_AS_Move"
const PURSUIT := &"Zombie_AS_Pursuit"
const ALERT := &"Zombie_AS_Alert"
const JUMP := &"Zombie_AS_Jump"
const FALL := &"Zombie_AS_Fall"
const ATTACK := &"Zombie_AS_Attack"
const SPAWN := &"Zombie_AS_Spawn"
const STAGGER := &"Zombie_AS_Stagger"

const STRIDE_SECONDS := 0.75
const BABY_STRIDE_SECONDS := 0.4375
const BABY_CONTACTS := [Vector3(0.1563, 0.0625, 0.17), Vector3(0.375, -0.0625, 0.17)]
# The support foot sweeps backwards at roughly 4 m/s on the 0.675 m source leg.
const SOURCE_STRIDE_SPEED := 4.0
const SOURCE_LEG_HEIGHT := 0.675
const SOURCE_RELEASE := 10.0 / 60.0
const SOURCE_CONTACT := 12.0 / 60.0
const BAKE_RATE := 60.0
const ALERT_TIME := 0.7083
const LANDING_DELAY := 0.15 # A&S ground recovery controller.
const ADULT_IDLE_PERIOD := 360.0 / 100.0
const BABY_IDLE_PERIOD := 360.0 / 130.0

# Bind transforms of the Mobs research rig in the same +Z-facing space as MD2.
# The four rigid limb bones have a 180° Z rotation in that source bind pose.
const BONE_MAP := [
	[&"J_Hip", &"Hips", Vector3(0, 0.675, 0)],
	[&"J_Spine", &"Spine", Vector3(0, 0.1125, 0)],
	[&"J_Shoulders", &"Chest", Vector3(0, 0.28125, 0)],
	[&"J_Neck", &"Neck", Vector3(0, 0.28125, 0)],
	[&"J_L_Arm", &"Arm.L", Vector3(0.3375, 0.28125, 0)],
	[&"J_R_Arm", &"Arm.R", Vector3(-0.3375, 0.28125, 0)],
	[&"J_L_Leg", &"Leg.L", Vector3(0.1125, 0, 0)],
	[&"J_R_Leg", &"Leg.R", Vector3(-0.1125, 0, 0)],
]

class LandingPose:
	var duration: float
	var _rig_scale: float
	var _joints: Array[Dictionary] = []

	func _init(skeleton: Skeleton3D, source: Dictionary) -> void:
		duration = source.animation_length
		var hip := skeleton.find_bone(&"J_Hip")
		_rig_scale = skeleton.get_bone_global_rest(hip).origin.y / SOURCE_LEG_HEIGHT
		# Put the waist compression above the hips so the planted legs keep their stride.
		# Leave out the pack's whole-body squash to retain rigid blocks.
		for binding: Array in [[&"J_Spine", "waist"], [&"J_Neck", "head"],
				[&"J_L_Arm", "leftarm"], [&"J_R_Arm", "rightarm"]]:
			var bone := skeleton.find_bone(binding[0])
			var parent := skeleton.get_bone_global_rest(skeleton.get_bone_parent(bone))
			var channels: Dictionary = source.bones[binding[1]]
			_joints.append({
				"bone": bone,
				"to_local": parent.basis.get_rotation_quaternion().inverse(),
				"position": Pack.Channel.new(channels.position) if channels.has("position") else null,
				"rotation": Pack.Channel.new(channels.rotation) if channels.has("rotation") else null,
			})

	func apply(skeleton: Skeleton3D, time: float) -> void:
		for joint: Dictionary in _joints:
			var bone: int = joint.bone
			var to_local: Quaternion = joint.to_local
			if joint.position != null:
				var offset: Vector3 = joint.position.sample(time, true)
				offset *= Vector3(1, 1, -1) * Pack.SOURCE_PIXEL * _rig_scale
				skeleton.set_bone_pose_position(bone, skeleton.get_bone_pose_position(bone) + to_local * offset)
			if joint.rotation != null:
				var angles: Vector3 = joint.rotation.sample(time, true)
				angles *= (PI / 180.0) * Vector3(1, -1, -1)
				var rotation := Basis.from_euler(angles, EULER_ORDER_ZYX).get_rotation_quaternion()
				skeleton.set_bone_pose_rotation(bone, (to_local * rotation * to_local.inverse()
					* skeleton.get_bone_pose_rotation(bone)).normalized())

static func build(player: AnimationPlayer, skeleton: Skeleton3D, attack_timing: Vector3,
		spawn_duration: float, stagger_seconds: float, baby: bool, pack: Dictionary) -> void:
	for step: Callable in bake_steps(player, skeleton, attack_timing, spawn_duration, stagger_seconds, baby, pack):
		step.call()

static func bake_steps(player: AnimationPlayer, skeleton: Skeleton3D, attack_timing: Vector3,
		spawn_duration: float, stagger_seconds: float, baby: bool, pack: Dictionary) -> Array[Callable]:
	for binding: Array in BONE_MAP:
		if skeleton.find_bone(binding[0]) < 0:
			return []
	var library := player.get_animation_library(&"")
	var model := player.get_parent()
	var source_clips: Dictionary[StringName, Animation] = {}
	var steps: Array[Callable] = []
	var preview: AnimationLibrary
	if (pack.is_empty() or not baby) and ResourceLoader.exists(SOURCE_PATH, "AnimationLibrary"):
		preview = ResourceLoader.load(SOURCE_PATH, "AnimationLibrary") as AnimationLibrary
	if pack.is_empty():
		if (preview == null or not preview.has_animation(&"Idle") or not preview.has_animation(&"Walk")
				or not preview.has_animation(&"Attack")):
			return []
		source_clips[IDLE] = preview.get_animation(&"Idle")
		source_clips[MOVE] = preview.get_animation(&"Walk")
		source_clips[ATTACK] = preview.get_animation(&"Attack")
	else:
		var bindings := BONE_MAP + [[&"", &"Head", Vector3.ZERO]]
		var idle_layer: Dictionary = pack.baby_idle if baby else pack.adult_idle
		var idle_period := BABY_IDLE_PERIOD if baby else ADULT_IDLE_PERIOD
		var alert: Dictionary = pack.alert.duplicate()
		alert.held_time = ALERT_TIME
		steps.append(func():
			source_clips[IDLE] = Pack.bake(bindings, [idle_layer], idle_period, true, BAKE_RATE, true))
		if baby:
			var baby_stance := idle_layer.duplicate()
			baby_stance.held_time = 0.0
			steps.append(func():
				source_clips[MOVE] = Pack.bake(bindings, [baby_stance, pack.baby_move, alert],
					BABY_STRIDE_SECONDS, true, BAKE_RATE, true))
		else:
			steps.append(func():
				source_clips[MOVE] = Pack.bake(bindings, [pack.adult_move], STRIDE_SECONDS, true, BAKE_RATE, true))
			steps.append(func():
				var pursuit := Pack.bake(bindings, [pack.pursuit, alert], STRIDE_SECONDS, true, BAKE_RATE, true)
				library.add_animation(PURSUIT, _bake(skeleton, model, pursuit)))
		# Both ages share the source swing over their own breathing pose and raised arms.
		steps.append(func():
			source_clips[ATTACK] = Pack.bake(bindings, [alert, pack.attack],
				pack.attack.animation_length, false, BAKE_RATE, true, source_clips[IDLE]))
		steps.append(func():
			var idle := source_clips[IDLE]
			var alert_source := Pack.bake(bindings, [alert], idle.length, true, BAKE_RATE, true, idle)
			source_clips[ALERT] = alert_source
			library.add_animation(ALERT, _bake(skeleton, model, alert_source)))
		for state: Array in [[JUMP, pack.jump], [FALL, pack.fall]]:
			var name: StringName = state[0]
			var layer: Dictionary = state[1]
			steps.append(func():
				var air := Pack.bake(bindings, [layer], layer.animation_length, false, BAKE_RATE, false, source_clips[IDLE])
				library.add_animation(name, _bake(skeleton, model, air, Vector3.ZERO, 0.0, false)))
	steps.append(func(): library.add_animation(IDLE, _bake(skeleton, model, source_clips[IDLE])))
	steps.append(func(): library.add_animation(MOVE, _bake(skeleton, model, source_clips[MOVE])))
	steps.append(func(): library.add_animation(ATTACK, _bake(skeleton, model, source_clips[ATTACK], attack_timing)))
	# A&S has no corresponding spawn or stagger montage. Use the breathing
	# stance for each age and let the Lab keep its existing one-shot timing.
	var resting_clip := ALERT if baby and not pack.is_empty() else IDLE
	steps.append(func():
		var spawn_source: Animation = source_clips[resting_clip]
		# Keep the adult entrance from the evaluated A&S library. Its initial
		# pose also initializes the dormant physical bones before their handoff.
		if not baby and preview != null and preview.has_animation(&"Idle"):
			spawn_source = preview.get_animation(&"Idle")
		library.add_animation(SPAWN, _bake(skeleton, model, spawn_source, Vector3.ZERO, spawn_duration)))
	steps.append(func(): library.add_animation(STAGGER,
		_bake(skeleton, model, source_clips[resting_clip], Vector3.ZERO, stagger_seconds)))
	return steps

class RetargetBone:
	var rest_position: Vector3
	var rest_rotation: Quaternion
	var source_rest_position: Vector3
	var source_rest_inverse: Quaternion
	var to_local: Quaternion
	var to_model: Quaternion
	var source_position: int
	var source_rotation: int
	var position: int
	var rotation: int
	var sole: Vector3
	var across: Vector3
	var depth: Vector3

static func _bake(skeleton: Skeleton3D, model: Node, source: Animation,
		attack_timing := Vector3.ZERO, intro_length := 0.0, grounded := true) -> Animation:
	var clip := Animation.new()
	var source_length := minf(source.length, intro_length) if intro_length > 0.0 else source.length
	clip.length = attack_timing.z if attack_timing.z > 0.0 else source_length
	clip.loop_mode = source.loop_mode if intro_length == 0.0 else Animation.LOOP_NONE
	var path := model.get_path_to(skeleton)
	var channels: Array[RetargetBone] = []
	var hip := skeleton.find_bone(&"J_Hip")
	var hip_parent := skeleton.get_bone_global_rest(skeleton.get_bone_parent(hip))
	var floor_up := hip_parent.basis.inverse() * Vector3.UP
	var leg_length := skeleton.get_bone_global_rest(hip).origin.y
	var rig_scale := leg_length / SOURCE_LEG_HEIGHT
	var mapped_bones: Array[int] = []
	for i in BONE_MAP.size():
		var binding: Array = BONE_MAP[i]
		var bone := skeleton.find_bone(binding[0])
		mapped_bones.append(bone)
		var bone_path := NodePath("%s:%s" % [path, binding[0]])
		var source_path := NodePath(":%s" % binding[1])
		var source_rest := Quaternion(Vector3.BACK, PI) if i >= 4 else Quaternion.IDENTITY
		var parent := skeleton.get_bone_global_rest(skeleton.get_bone_parent(bone))
		var to_local := parent.basis.get_rotation_quaternion().inverse()
		var rest := skeleton.get_bone_rest(bone)
		var channel := RetargetBone.new()
		channel.rest_position = rest.origin
		channel.rest_rotation = rest.basis.get_rotation_quaternion()
		channel.source_rest_position = binding[2]
		channel.source_rest_inverse = source_rest.inverse()
		channel.to_local = to_local
		channel.to_model = to_local.inverse()
		channel.source_position = source.find_track(source_path, Animation.TYPE_POSITION_3D)
		channel.source_rotation = source.find_track(source_path, Animation.TYPE_ROTATION_3D)
		channel.position = _track(clip, bone_path, Animation.TYPE_POSITION_3D)
		channel.rotation = _track(clip, bone_path, Animation.TYPE_ROTATION_3D)
		if i >= 6 and grounded:
			var foot_basis := channel.rest_rotation.inverse() * to_local
			channel.sole = foot_basis * (Vector3.DOWN * leg_length)
			channel.across = foot_basis * Vector3.RIGHT
			channel.depth = foot_basis * Vector3.BACK
		channels.append(channel)
	# Clear pose channels left by a previous MD2 clip. The hands, feet and face
	# inherit the rigid parent motion without any source joint bends or scales.
	for bone in skeleton.get_bone_count():
		var bone_path := NodePath("%s:%s" % [path, skeleton.get_bone_name(bone)])
		var rest := skeleton.get_bone_rest(bone)
		if not mapped_bones.has(bone):
			clip.position_track_insert_key(_track(clip, bone_path, Animation.TYPE_POSITION_3D), 0.0, rest.origin)
			clip.rotation_track_insert_key(_track(clip, bone_path, Animation.TYPE_ROTATION_3D), 0.0,
				rest.basis.get_rotation_quaternion())
		clip.scale_track_insert_key(_track(clip, bone_path, Animation.TYPE_SCALE_3D), 0.0, rest.basis.get_scale())

	var positions: Array[Vector3] = []
	var rotations: Array[Quaternion] = []
	positions.resize(channels.size())
	rotations.resize(channels.size())
	var head_track := source.find_track(NodePath(":Head"), Animation.TYPE_ROTATION_3D)
	var sample_count := ceili(source_length * BAKE_RATE)
	for sample in range(sample_count + 1):
		var t := minf(sample / BAKE_RATE, source_length)
		var output_time := _attack_time(t, source.length, attack_timing) if attack_timing.z > 0.0 else t
		for i in channels.size():
			var channel := channels[i]
			var offset := (source.position_track_interpolate(channel.source_position, t)
				- channel.source_rest_position)
			var facing := (source.rotation_track_interpolate(channel.source_rotation, t)
				* channel.source_rest_inverse)
			if i == 3:
				# Eyes and mouth are siblings of J_Head under J_Neck on both MD2 rigs.
				facing *= source.rotation_track_interpolate(head_track, t)
			positions[i] = channel.rest_position + channel.to_local * offset * rig_scale
			rotations[i] = (channel.to_local * facing * channel.to_model
				* channel.rest_rotation).normalized()
		# Retargeting changes limb lengths and joint locations. Seat the lowest
		# sole corner at ground level on this rig, keeping the source swing foot.
		if grounded:
			var hips := hip_parent * Transform3D(Basis(rotations[0]), positions[0])
			var low := minf(_sole_y(hips, positions[6], rotations[6], channels[6], leg_length),
				_sole_y(hips, positions[7], rotations[7], channels[7], leg_length))
			positions[0] -= floor_up * low
		for i in channels.size():
			clip.position_track_insert_key(channels[i].position, output_time, positions[i])
			clip.rotation_track_insert_key(channels[i].rotation, output_time, rotations[i])
	return clip

static func _track(clip: Animation, path: NodePath, type: Animation.TrackType) -> int:
	var index := clip.add_track(type)
	clip.track_set_path(index, path)
	return index

static func _sole_y(hips: Transform3D, pivot: Vector3, rotation: Quaternion, channel: RetargetBone,
		leg_length: float) -> float:
	var leg := hips * Transform3D(Basis(rotation), pivot)
	var sole := leg * channel.sole
	var across := leg.basis * channel.across
	var depth := leg.basis * channel.depth
	return sole.y - (absf(across.y) + absf(depth.y)) * leg_length / 6.0

static func _attack_time(t: float, duration: float, timing: Vector3) -> float:
	if t <= SOURCE_RELEASE:
		return t * timing.x / SOURCE_RELEASE
	if t <= SOURCE_CONTACT:
		return remap(t, SOURCE_RELEASE, SOURCE_CONTACT, timing.x, timing.y)
	return remap(t, SOURCE_CONTACT, duration, timing.y, timing.z)
