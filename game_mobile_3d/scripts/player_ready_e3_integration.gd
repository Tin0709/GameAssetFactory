extends "res://scripts/player_draw_d5_integration.gd"
## Visual contexts within READY, evaluated before the unchanged Draw/Holster
## layers by the existing sole pose writer. Walk retains its calibrated Hold.
enum ReadyAnimationMode { LEGACY_HOLD, LIVING_READY }
@export var ready_animation_mode: ReadyAnimationMode = ReadyAnimationMode.LIVING_READY
@export_range(0.10, 0.18, 0.01) var ready_context_blend_duration: float = 0.13
const READY_BODY := ["Spine", "Chest", "Neck", "Head"]
const READY_BONES := ["Spine", "Chest", "Neck", "Head", "Arm.R", "Arm.L", "WeaponCarrier", "WeaponSocket"]
var ready_idle_pose: RefCounted
var ready_run_pose: RefCounted
var ready_mask := PackedInt32Array()
var ready_source_mask := PackedInt32Array()
var ready_base_positions: Array[Vector3] = []
var ready_base_rotations: Array[Quaternion] = []
var living_ready_weight := 0.0
var ready_move_weight := 0.0
var ready_idle_time := 0.0

func _ready() -> void:
	super._ready()
	ready_idle_pose = samples.get("LongGunReadyIdle")
	ready_run_pose = samples.get("LongGunReadyRun")
	assert(ready_idle_pose != null and ready_run_pose != null)
	for name in READY_BONES:
		ready_mask.append(skeleton.find_bone(name))
		# Carrier and the existing hand socket share Chest as parent. Evaluate
		# the authored Carrier local frame at both helpers, retaining mounts.
		ready_source_mask.append(skeleton.find_bone("WeaponCarrier" if name == "WeaponSocket" else name))
		ready_base_positions.append(Vector3.ZERO); ready_base_rotations.append(Quaternion.IDENTITY)
	assert(skeleton.get_bone_parent(socket_bone) == skeleton.get_bone_parent(skeleton.find_bone("WeaponCarrier")))
	_evaluate(0.0)

func _process(delta: float) -> void:
	if not frozen and ready_idle_pose != null:
		ready_idle_time = fposmod(ready_idle_time + delta, ready_idle_pose.clip.length)
		ready_move_weight = move_toward(ready_move_weight, clampf(movement_speed/0.5, 0.0, 1.0) if movement_speed >= LOCOMOTION_DEAD_ZONE else 0.0, delta/ready_context_blend_duration)
		# Draw uses the same destination underneath its captured endpoint exit
		# blend. No intermediate return through Hold is needed after DRAW_READY.
		var eligible: bool = generic_weapon_carry and long_gun_carry_v2 and authored_locomotion and weapon_equipped and Socket.Profiles.category(weapon_type) == Socket.Profiles.Category.LONG_GUN
		var requested: bool = weapon_behavior == null or not weapon_behavior.enabled or weapon_behavior.state in [weapon_behavior.State.READY, weapon_behavior.State.DRAWING]
		var living: bool = eligible and requested and ready_animation_mode == ReadyAnimationMode.LIVING_READY
		living_ready_weight = move_toward(living_ready_weight, 1.0 if living else 0.0, delta/ready_context_blend_duration)
	super._process(delta)

func ready_run_sample_time() -> float:
	# Run correction is sampled only into the actual Run contribution. Walk
	# never receives it, and there is no independently advancing ReadyRun clock.
	return authored_run_time / run.clip.length * ready_run_pose.clip.length

func _apply_weapon_carry() -> void:
	if ready_idle_pose == null or living_ready_weight <= 0.0 or Socket.Profiles.category(weapon_type) != Socket.Profiles.Category.LONG_GUN or (ready_move_weight == 1.0 and run_weight == 0.0):
		super._apply_weapon_carry(); return
	for i in ready_mask.size():
		ready_base_positions[i] = skeleton.get_bone_pose_position(ready_mask[i])
		ready_base_rotations[i] = skeleton.get_bone_pose_rotation(ready_mask[i])
	super._apply_weapon_carry()
	var run_time := ready_run_sample_time()
	for i in ready_mask.size():
		var bone := ready_mask[i]; var source := ready_source_mask[i]
		var name := skeleton.get_bone_name(bone)
		var base_p := ready_base_positions[i]; var base_q := ready_base_rotations[i]
		var legacy_p := skeleton.get_bone_pose_position(bone); var legacy_q := skeleton.get_bone_pose_rotation(bone)
		var idle_p: Vector3 = ready_idle_pose.position(source, ready_idle_time)
		var idle_q: Quaternion = ready_idle_pose.rotation(source, ready_idle_time)
		var run_p: Vector3 = ready_run_pose.position(source, run_time)
		var run_q: Quaternion = ready_run_pose.rotation(source, run_time)
		var carry_weight := weapon_hold_weight
		if name in READY_BODY:
			# Blender contract: base matrix_basis * Ready correction. Convert
			# imported absolute local tracks through the existing bone rest.
			var rest := skeleton.get_bone_rest(bone)
			var rest_q := rest.basis.get_rotation_quaternion()
			idle_p = base_p + Basis(base_q) * (rest.basis.inverse() * (idle_p-rest.origin))
			run_p = base_p + Basis(base_q) * (rest.basis.inverse() * (run_p-rest.origin))
			idle_q = base_q * rest_q.inverse() * idle_q
			run_q = base_q * rest_q.inverse() * run_q
			carry_weight = long_gun_weight
		idle_p = base_p.lerp(idle_p, carry_weight); idle_q = base_q.slerp(idle_q, carry_weight)
		run_p = base_p.lerp(run_p, carry_weight); run_q = base_q.slerp(run_q, carry_weight)
		# Normal Walk uses the original final Hold pose; its stride clock and
		# compensation are untouched. A dedicated ReadyWalk needs later authoring.
		var moving_p := legacy_p.lerp(run_p, run_weight)
		var moving_q := legacy_q.slerp(run_q, run_weight)
		var living_p := idle_p.lerp(moving_p, ready_move_weight)
		var living_q := idle_q.slerp(moving_q, ready_move_weight)
		skeleton.set_bone_pose_position(bone, legacy_p.lerp(living_p, living_ready_weight))
		skeleton.set_bone_pose_rotation(bone, legacy_q.slerp(living_q, living_ready_weight).normalized())

func ready_context_text() -> String:
	if ready_animation_mode == ReadyAnimationMode.LEGACY_HOLD: return "LEGACY HOLD"
	if weapon_type == 0: return "LIVING READY | Pistol unchanged"
	if weapon_behavior != null and weapon_behavior.enabled and weapon_behavior.state != weapon_behavior.State.READY: return "LIVING READY | " + weapon_behavior.State.keys()[weapon_behavior.state]
	if ready_move_weight < 0.01: return "LIVING READY | Idle"
	if run_weight < 0.01: return "LIVING READY | Walk: legacy Hold fallback"
	return "LIVING READY | Run shared phase %.3f" % (authored_run_time/run.clip.length)

func debug_text() -> String:
	return super.debug_text() + "\n" + ready_context_text()
