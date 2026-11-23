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

static func build(player: AnimationPlayer, skeleton: Skeleton3D, attack_timing: Vector3,
		spawn_duration: float, stagger_seconds: float, baby: bool, pack: Dictionary) -> void:
	if not ResourceLoader.exists(SOURCE_PATH, "AnimationLibrary"):
		return
	var source := ResourceLoader.load(SOURCE_PATH, "AnimationLibrary") as AnimationLibrary
	if (source == null or not source.has_animation(&"Idle") or not source.has_animation(&"Walk")
			or not source.has_animation(&"Attack")):
		return
	for binding: Array in BONE_MAP:
		if skeleton.find_bone(binding[0]) < 0:
			return
	var library := player.get_animation_library(&"")
	var idle_source := source.get_animation(&"Idle")
	var move_source := source.get_animation(&"Walk")
	var attack_source := source.get_animation(&"Attack")
	if not pack.is_empty():
		var bindings := BONE_MAP + [[&"", &"Head", Vector3.ZERO]]
		var alert: Dictionary = pack.alert.duplicate()
		alert.held_time = ALERT_TIME
		if baby:
			idle_source = Pack.bake(bindings, [pack.baby_idle], BABY_IDLE_PERIOD, true, BAKE_RATE, true)
			var baby_stance: Dictionary = pack.baby_idle.duplicate()
			baby_stance.held_time = 0.0
			move_source = Pack.bake(bindings, [baby_stance, pack.baby_move, alert],
				BABY_STRIDE_SECONDS, true, BAKE_RATE, true)
			# Both ages share the source attack layer. The baby uses its own
			# breathing pose and the already-raised arms underneath the swing.
			attack_source = Pack.bake(bindings, [alert, pack.attack],
				pack.attack.animation_length, false, BAKE_RATE, true, idle_source)
		else:
			var pursuit_source := Pack.bake(bindings, [pack.pursuit, alert],
				STRIDE_SECONDS, true, BAKE_RATE, true)
			library.add_animation(PURSUIT, _bake(skeleton, player.get_parent(), pursuit_source))
		var alert_source := Pack.bake(bindings, [alert], idle_source.length, true, BAKE_RATE, true, idle_source)
		library.add_animation(ALERT, _bake(skeleton, player.get_parent(), alert_source))
		for state: Array in [[JUMP, pack.jump], [FALL, pack.fall]]:
			var air := Pack.bake(bindings, [state[1]], state[1].animation_length, false,
				BAKE_RATE, false, idle_source)
			library.add_animation(state[0], _bake(skeleton, player.get_parent(), air, Vector3.ZERO, 0.0, false))
	var idle := _bake(skeleton, player.get_parent(), idle_source)
	var move := _bake(skeleton, player.get_parent(), move_source)
	var attack := _bake(skeleton, player.get_parent(), attack_source, attack_timing)
	library.add_animation(IDLE, idle)
	library.add_animation(MOVE, move)
	library.add_animation(ATTACK, attack)
	# The pack has no skeletal spawn or stagger. Use a short section of its
	# breathing pose for both while the Lab retains spawn and hit timing.
	library.add_animation(SPAWN, _bake(skeleton, player.get_parent(),
		idle_source, Vector3.ZERO, spawn_duration))
	library.add_animation(STAGGER, _bake(skeleton, player.get_parent(),
		idle_source, Vector3.ZERO, stagger_seconds))

static func _bake(skeleton: Skeleton3D, model: Node, source: Animation,
		attack_timing := Vector3.ZERO, intro_length := 0.0, grounded := true) -> Animation:
	var clip := Animation.new()
	var source_length := minf(source.length, intro_length) if intro_length > 0.0 else source.length
	clip.length = attack_timing.z if attack_timing.z > 0.0 else source_length
	clip.loop_mode = source.loop_mode if intro_length == 0.0 else Animation.LOOP_NONE
	var path := model.get_path_to(skeleton)
	var channels: Array[Dictionary] = []
	var hip := skeleton.find_bone(&"J_Hip")
	var hip_parent := skeleton.get_bone_global_rest(skeleton.get_bone_parent(hip))
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
		channels.append({
			"rest_position": rest.origin,
			"rest_rotation": rest.basis.get_rotation_quaternion(),
			"source_rest_position": binding[2],
			"source_rest_inverse": source_rest.inverse(),
			"to_local": to_local,
			"to_model": to_local.inverse(),
			"source_position": source.find_track(source_path, Animation.TYPE_POSITION_3D),
			"source_rotation": source.find_track(source_path, Animation.TYPE_ROTATION_3D),
			"position": _track(clip, bone_path, Animation.TYPE_POSITION_3D),
			"rotation": _track(clip, bone_path, Animation.TYPE_ROTATION_3D),
		})
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
				- (channel.source_rest_position as Vector3))
			var facing := (source.rotation_track_interpolate(channel.source_rotation, t)
				* (channel.source_rest_inverse as Quaternion))
			if i == 3:
				# Eyes and mouth are siblings of J_Head under J_Neck on both MD2 rigs.
				facing *= source.rotation_track_interpolate(head_track, t)
			positions[i] = (channel.rest_position as Vector3) + (channel.to_local as Quaternion) * offset * rig_scale
			rotations[i] = ((channel.to_local as Quaternion) * facing * (channel.to_model as Quaternion)
				* (channel.rest_rotation as Quaternion)).normalized()
		# Retargeting changes limb lengths and joint locations. Seat the lowest
		# sole corner at ground level on this rig, keeping the source swing foot.
		if grounded:
			var hips := hip_parent * Transform3D(Basis(rotations[0]), positions[0])
			var low := minf(_sole_y(hips, positions[6], rotations[6], channels[6], leg_length),
				_sole_y(hips, positions[7], rotations[7], channels[7], leg_length))
			positions[0] -= hip_parent.basis.inverse() * Vector3.UP * low
		for i in channels.size():
			clip.position_track_insert_key(channels[i].position, output_time, positions[i])
			clip.rotation_track_insert_key(channels[i].rotation, output_time, rotations[i])
	return clip

static func _track(clip: Animation, path: NodePath, type: Animation.TrackType) -> int:
	var index := clip.add_track(type)
	clip.track_set_path(index, path)
	return index

static func _sole_y(hips: Transform3D, pivot: Vector3, rotation: Quaternion, channel: Dictionary,
		leg_length: float) -> float:
	var leg := hips * Transform3D(Basis(rotation), pivot)
	var from_model: Quaternion = (channel.rest_rotation as Quaternion).inverse() * (channel.to_local as Quaternion)
	var sole := leg * (from_model * (Vector3.DOWN * leg_length))
	var across := leg.basis * (from_model * Vector3.RIGHT)
	var depth := leg.basis * (from_model * Vector3.BACK)
	return sole.y - (absf(across.y) + absf(depth.y)) * leg_length / 6.0

static func _attack_time(t: float, duration: float, timing: Vector3) -> float:
	if t <= SOURCE_RELEASE:
		return t * timing.x / SOURCE_RELEASE
	if t <= SOURCE_CONTACT:
		return remap(t, SOURCE_RELEASE, SOURCE_CONTACT, timing.x, timing.y)
	return remap(t, SOURCE_CONTACT, duration, timing.y, timing.z)
