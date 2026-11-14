extends "res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/world_map_actor.gd"
## MechanicLab-only weapon input, locomotion and attachments.

const CrossPollinator := preload("res://scripts/mechanic_lab_cross_pollinator.gd")
const Gauntlets := preload("res://scripts/mechanic_lab_gauntlets.gd")
const LabLocomotion := preload("res://scripts/mechanic_lab_locomotion.gd")
const Bow := preload("res://scripts/mechanic_lab_bow.gd")

signal bow_drawn
signal bow_released(serial: int, charged: bool, target: Variant)

const BOW_MIN_DRAW_SECONDS := 0.10
const BOW_DRAW_BLEND_SECONDS := 0.12
const IDLE_GESTURE_BLEND_SECONDS := 0.18
const MIN_WALL_STEP_PROGRESS := 0.10

var crossbow_equipped := false
var gauntlets_equipped := false
var _crossbow_pose_serial := -1
var _crossbow_mount: MeshInstance3D
var _crossbow_carry_mesh: Mesh
var _crossbow_recoil_mesh: Mesh
var _crossbow_socket: BoneAttachment3D
var _crossbow_carry_bone := -1
var _crossbow_recoil_bone := -1
var tool_air_hold := -1.0
var tool_air_loop := -1.0
var tool_air_landing := -1.0
var bow_equipped := false
var bow_target: Callable
var bow_can_draw: Callable
var _bow_mount: MeshInstance3D
var _bow_socket: BoneAttachment3D
var _bow_meshes: Array[Mesh]
var _bow_grip_from := Transform3D.IDENTITY
var _bow_down := false
var _bow_drawing := false
var _bow_held_seconds := 0.0
var _bow_draw_seconds := 0.0
var _bow_recovery := 0.0
var _bow_action_time := 0.0
var _bow_aim_tick := -1
var _bow_aim: Variant

func source_step_dust_size() -> float:
	var source: String = clips.get(active_clip, {}).get("source_name", "")
	match source:
		"Player_Master_Run":
			return 1.0
		"Player_Master_Walk", "Player_Crossbow_Walk", "Player_Crossbow_Run":
			return 0.0
	return -1.0

func configure_crossbow_mount(mount: MeshInstance3D, carry_mesh: Mesh, recoil_mesh: Mesh) -> void:
	_crossbow_mount = mount
	_crossbow_carry_mesh = carry_mesh
	_crossbow_recoil_mesh = recoil_mesh
	_crossbow_socket = mount.get_parent() as BoneAttachment3D
	_crossbow_carry_bone = skeleton.find_bone(&"J_L_Weapon")
	_crossbow_recoil_bone = skeleton.find_bone(&"J_L_Weapon1")

func configure_bow_mount(mount: MeshInstance3D, meshes: Array[Mesh]) -> void:
	_bow_mount = mount
	_bow_socket = mount.get_parent() as BoneAttachment3D
	_bow_meshes = meshes

func bow_busy() -> bool:
	return _bow_down or _bow_drawing or _bow_recovery > 0.0

func _refresh_markers() -> void:
	super._refresh_markers()
	if bow_equipped and _bow_mount != null:
		var in_action := active_clip == Bow.ACTION
		var state := Bow.mesh_state(_bow_action_time) if in_action else 0
		var hand := skeleton.get_bone_global_pose(_bow_socket.bone_idx)
		_bow_socket.transform = hand
		var grip := Bow.ACTION_GRIP if in_action else Transform3D.IDENTITY
		_bow_mount.transform = _bow_grip_from.interpolate_with(grip, source_transition.incoming_weight)
		if _bow_mount.mesh != _bow_meshes[state]:
			_bow_mount.mesh = _bow_meshes[state]
	if not crossbow_equipped or _crossbow_mount == null:
		return
	var hand := skeleton.get_bone_global_pose(_crossbow_socket.bone_idx)
	var carry := skeleton.get_bone_global_pose(_crossbow_carry_bone)
	var recoil := skeleton.get_bone_global_pose(_crossbow_recoil_bone)
	var recoiling := recoil.basis.x.length_squared() > carry.basis.x.length_squared()
	var weapon := recoil if recoiling else carry
	# The source switches models by collapsing one weapon branch. Use a
	# single full-size instance so transitions never interpolate that scale.
	var relative := (hand.affine_inverse() * weapon).orthonormalized()
	_crossbow_socket.transform = hand
	_crossbow_mount.transform = relative * Transform3D(Basis.IDENTITY, CrossPollinator.MESH_OFFSET)
	var mesh := _crossbow_recoil_mesh if recoiling else _crossbow_carry_mesh
	if _crossbow_mount.mesh != mesh:
		_crossbow_mount.mesh = mesh

func _create_hybrid_motion() -> RefCounted:
	return LabLocomotion.new()

func _physics_process(delta: float) -> void:
	var planted_bow := _bow_locks_ground_movement()
	var direction_before := requested_direction
	var jump_before := requested_jump
	if planted_bow:
		requested_direction = Vector2.ZERO
		requested_jump = false
		velocity.x = 0.0
		velocity.z = 0.0
	super._physics_process(delta)
	if planted_bow:
		requested_direction = direction_before
		requested_jump = jump_before
	if crossbow_equipped and not is_dead and (_left or _e) and not combo.held:
		# The shared jump cancels melee. Keep a physically held ranged trigger.
		attack(true)

func _bow_locks_ground_movement() -> bool:
	# The MD2 controller input tree runs ranged aim instead of PlayerMove
	# while the ranged input is held. Release hands control back to movement.
	return bow_equipped and _bow_down and _bow_drawing and is_on_floor()

func _live_movement_input_enabled() -> bool:
	return not _bow_locks_ground_movement() and super._live_movement_input_enabled()

func accepts_step_during_wall_contact() -> bool:
	if not is_on_wall() or not _move_requested:
		return true
	var direction := requested_direction
	if not scripted_input:
		var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		direction = _movement_right * stick.x + _movement_back * stick.y
	direction = direction.limit_length()
	var strength := direction.length()
	if is_zero_approx(strength):
		return true
	var motion := get_real_velocity()
	var forward_speed := Vector2(motion.x, motion.z).dot(direction / strength)
	var requested_speed := (run_speed if _run_requested else walk_speed) * strength
	return forward_speed >= requested_speed * MIN_WALL_STEP_PROGRESS

func attack(value: bool) -> void:
	if bow_equipped:
		if value and not bow_busy() and not is_dead and bow_can_draw.is_valid() and bow_can_draw.call():
			resume_gameplay()
			_bow_drawing = true
			_bow_held_seconds = 0.0
			_bow_draw_seconds = 0.0
			_bow_action_time = Bow.DRAW_START
			if novelty_jump != null:
				novelty_jump.cancel()
			bow_drawn.emit()
		_bow_down = value
		return
	if crossbow_equipped:
		if value:
			resume_gameplay()
		# The crossbow uses the same action in the air and on the ground.
		# Using the aerial melee phase would start the heavy-slam gravity path.
		combo.attack(value, false)
		if novelty_jump != null and combo.active():
			novelty_jump.cancel()
		return
	super.attack(value)

func release_inputs() -> void:
	_bow_down = false
	_bow_drawing = false
	_bow_recovery = 0.0
	super.release_inputs()

func _play(key: String, blend: float = 0.04) -> void:
	if bow_equipped and _bow_mount != null and active_clip != key:
		_bow_grip_from = _bow_mount.transform if not active_clip.is_empty() else Transform3D.IDENTITY
	if key == Bow.ACTION and review_clip.is_empty():
		super._play(key, blend)
		animation_player.seek(_bow_action_time)
		return
	if crossbow_equipped and combo.active() and review_clip.is_empty():
		if key == CrossPollinator.SHOT and _crossbow_pose_serial != combo.serial:
			_crossbow_pose_serial = combo.serial
			if active_clip == key:
				animation_player.seek(0.0, true)
		elif key == CrossPollinator.RECOVERY and active_clip != key:
			super._play(key, blend)
			animation_player.seek(CrossPollinator.ATTACK_PERIOD, true)
			return
	super._play(key, blend)

func _combat_entry(key: String) -> bool:
	return (bow_equipped and key == Bow.ACTION) or super._combat_entry(key)

func _combat_entry_blend(key: String) -> float:
	if key == Bow.ACTION:
		return BOW_DRAW_BLEND_SECONDS
	var seconds := super._combat_entry_blend(key)
	if key == CrossPollinator.SHOT and active_clip in GAITS:
		# Blend the running stride into the authored shot within one shot period.
		return maxf(seconds, 0.10)
	return seconds

func _combat_stride_pose(phase: float, speed: float) -> Array[Transform3D]:
	if crossbow_equipped and hybrid_motion != null:
		return hybrid_motion.run_pose(phase) if _run_requested else source_gait.sample("Walk", phase)
	return super._combat_stride_pose(phase, speed)

func _combat_stride_period(speed: float, state: Dictionary) -> float:
	if crossbow_equipped and hybrid_motion != null:
		if not _run_requested:
			return float(clips.Walk.duration) * walk_stride_speed / maxf(speed, 0.001)
		return hybrid_motion.period(speed, 1.0)
	return super._combat_stride_period(speed, state)

func _restart_combat_stride() -> bool:
	return not crossbow_equipped and super._restart_combat_stride()

func _use_composed_gait(key: String) -> bool:
	return key not in LabLocomotion.WALKS and super._use_composed_gait(key)

func _composed_gait_period(key: String, speed: float, state: Dictionary) -> float:
	if crossbow_equipped and key in LabLocomotion.RUNS and hybrid_motion != null:
		return hybrid_motion.period(speed, 1.0)
	return super._composed_gait_period(key, speed, state)

func _select_clip() -> String:
	if bow_equipped and (_bow_drawing or _bow_recovery > 0.0) and review_clip.is_empty():
		_idle_wait = 0.0
		_inspect_age = 0.0
		_inspecting = false
		return Bow.ACTION
	var key := super._select_clip()
	if key in LabLocomotion.WALKS and weapon_source_locomotion and review_clip.is_empty():
		# These profiles have a dedicated armed Walk, shared across directions.
		return "Walk"
	return key

func _outgoing_locomotion_sampler(key: String, phase: float) -> Callable:
	if key in LabLocomotion.WALKS:
		# SourceTransition already holds the exact outgoing pose. The shared
		# speed blend would reintroduce Idle or Run while fading out a Walk.
		_outgoing_locomotion_state.clear()
		return Callable()
	if key not in GAITS or not weapon_source_locomotion:
		return super._outgoing_locomotion_sampler(key, phase)
	var crossbow_run := crossbow_equipped and key in LabLocomotion.RUNS
	var cursor := {"clip": key, "phase": phase}
	_outgoing_locomotion_state = cursor
	return func(delta: float) -> Array[Transform3D]:
		var speed := _animation_motion_speed if _combat_plan_active else current_speed
		var gait_state: Dictionary = source_gait.state(speed)
		cursor.phase = fposmod(float(cursor.phase) + delta / _composed_gait_period(key, speed, gait_state), 1.0)
		var pose: Array[Transform3D] = source_gait.compose(float(cursor.phase), speed)
		return hybrid_motion.crossbow_run_pose(pose, float(cursor.phase)) if crossbow_run else pose

func _begin_pose_transition(key: String, seconds: float) -> void:
	if bow_equipped and active_clip == Bow.ACTION:
		source_transition.begin_evaluated(0.25, Callable(), &"smoothstep")
		return
	if key == "InspectWeapon" or (active_clip == "InspectWeapon" and key == "Idle"):
		source_transition.begin_evaluated(IDLE_GESTURE_BLEND_SECONDS, Callable(), &"smoothstep")
		return
	if crossbow_equipped and active_clip in [CrossPollinator.SHOT, CrossPollinator.RECOVERY]:
		if key in GAITS or key in ["Idle", "CombatReady", "InspectWeapon"]:
			source_transition.begin_evaluated(CrossPollinator.BLEND_OUT_SECONDS, Callable(), &"smoothstep")
			return
	super._begin_pose_transition(key, seconds)

func begin_gauntlet_landing() -> void:
	combo.air_landing_started = true
	combo.time = Gauntlets.AIR_CONTACT
	if active_clip == "AirAttack":
		animation_player.seek(combo.time, true)

func _animate(delta: float) -> void:
	var release_bow := false
	var target: Variant = null
	if bow_equipped and review_clip.is_empty():
		if _bow_recovery > 0.0:
			_bow_recovery = maxf(0.0, _bow_recovery - delta)
			_bow_action_time = minf(Bow.RELEASE_END, _bow_action_time + delta)
		if _bow_drawing:
			_bow_draw_seconds += delta
			if _bow_down:
				_bow_held_seconds += delta
			_bow_action_time = lerpf(Bow.DRAW_START, Bow.DRAW_HOLD, clampf(_bow_draw_seconds / Bow.CHARGE_TIME, 0.0, 1.0))
			if not _bow_down and _bow_draw_seconds >= BOW_MIN_DRAW_SECONDS:
				_bow_drawing = false
				_bow_recovery = Bow.ATTACK_PERIOD_SECONDS
				_bow_action_time = Bow.RELEASE_START
				release_bow = true
		if _bow_drawing or release_bow:
			if combat_requested and has_aim_point:
				target = aim_point
			elif not combat_requested and bow_target.is_valid():
				var frame := Engine.get_physics_frames()
				if _bow_aim_tick != frame:
					_bow_aim_tick = frame
					_bow_aim = bow_target.call(Bow.AIM_RANGE, Vector3(velocity.x, 0.0, velocity.z))
				target = _bow_aim
			if target is Vector3:
				var aim: Vector3 = target - global_position
				if Vector2(aim.x, aim.z).length_squared() > 0.01:
					var heading := atan2(aim.x, aim.z)
					visual.rotation.y = heading if release_bow else rotate_toward(visual.rotation.y, heading, ground_turn_rate * delta)
					if hybrid_motion != null:
						hybrid_motion.facing.reset(visual.rotation.y)
	if gauntlets_equipped and combo.phase == &"air_attack" and active_clip == "AirAttack":
		if not combo.air_landing_started and combo.time >= 18.0 / 30.0:
			# Hold the airborne pose until physics reports support.
			combo.time = 18.0 / 30.0 - delta * combo.playback_rate()
			animation_player.seek(combo.time, true)
		elif combo.air_landing_started and combo.time >= 31.0 / 30.0 and combo.time < 71.0 / 30.0:
			# The export contains a long static segment between impact and recovery.
			combo.time = 71.0 / 30.0
			animation_player.seek(combo.time, true)
	elif tool_air_hold >= 0.0 and combo.phase == &"air_attack" and active_clip == "AirAttack" \
			and not combo.air_landing_started and combo.time >= tool_air_hold:
		combo.time = tool_air_loop if tool_air_hold - tool_air_loop > 1.0 / 30.0 \
			else tool_air_hold - delta * combo.playback_rate()
		animation_player.seek(combo.time, true)
	super._animate(delta)
	if release_bow:
		combo.serial += 1
		bow_released.emit(combo.serial, _bow_held_seconds >= Bow.CHARGE_TIME - 0.00001, target)

func begin_tool_landing() -> void:
	if tool_air_landing < 0.0 or combo.phase != &"air_attack":
		return
	combo.air_landing_started = true
	combo.time = tool_air_landing
	if active_clip == "AirAttack":
		animation_player.seek(combo.time, true)
