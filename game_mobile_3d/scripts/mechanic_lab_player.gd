extends "res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/world_map_actor.gd"
## MechanicLab-only weapon input, locomotion and attachments.

const CrossPollinator := preload("res://scripts/mechanic_lab_cross_pollinator.gd")
const Gauntlets := preload("res://scripts/mechanic_lab_gauntlets.gd")
const LabLocomotion := preload("res://scripts/mechanic_lab_locomotion.gd")

var crossbow_equipped := false
var gauntlets_equipped := false
var _crossbow_pose_serial := -1
var _crossbow_mount: MeshInstance3D
var _crossbow_carry_mesh: Mesh
var _crossbow_recoil_mesh: Mesh
var _crossbow_socket: BoneAttachment3D
var _crossbow_carry_bone := -1
var _crossbow_recoil_bone := -1

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

func _refresh_markers() -> void:
	super._refresh_markers()
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
	super._physics_process(delta)
	if crossbow_equipped and not is_dead and (_left or _e) and not combo.held:
		# The shared jump cancels melee. Keep a physically held ranged trigger.
		attack(true)

func attack(value: bool) -> void:
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

func _play(key: String, blend: float = 0.04) -> void:
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

func _combat_entry_blend(key: String) -> float:
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
	if crossbow_equipped and active_clip in [CrossPollinator.SHOT, CrossPollinator.RECOVERY]:
		if key in GAITS or key in ["Idle", "CombatReady", "InspectWeapon"]:
			source_transition.begin_evaluated(CrossPollinator.IDLE_BLEND_SECONDS, Callable(), &"smoothstep")
			return
	super._begin_pose_transition(key, seconds)

func begin_gauntlet_landing() -> void:
	combo.air_landing_started = true
	combo.time = Gauntlets.AIR_CONTACT
	if active_clip == "AirAttack":
		animation_player.seek(combo.time, true)

func _animate(delta: float) -> void:
	if gauntlets_equipped and combo.phase == &"air_attack" and active_clip == "AirAttack":
		if not combo.air_landing_started and combo.time >= 18.0 / 30.0:
			# Hold the airborne pose until physics reports support.
			combo.time = 18.0 / 30.0 - delta * combo.playback_rate()
			animation_player.seek(combo.time, true)
		elif combo.air_landing_started and combo.time >= 31.0 / 30.0 and combo.time < 71.0 / 30.0:
			# The export contains a long static segment between impact and recovery.
			combo.time = 71.0 / 30.0
			animation_player.seek(combo.time, true)
	super._animate(delta)
