extends "res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/hybrid_motion.gd"
## MechanicLab uses the source MD2 Walk for each weapon profile.

const WALKS := ["Walk", "StrafeLeft", "StrafeRight", "CombatWalk", "CombatStrafeLeft", "CombatStrafeRight"]
const RUNS := ["Run", "CombatRun"]
# Right-foot contact on the A&S cycle occurs just after the MD2 Walk seam.
const CROSSBOW_RUN_PHASE_OFFSET := 0.05
const CROSSBOW_ARM_SWAY_WEIGHT := 0.40
const CROSSBOW_TORSO_SWAY_WEIGHT := 0.60
const Bow := preload("res://scripts/mechanic_lab_bow.gd")
var _left_arm := -1
var _right_arm := -1
var _crossbow_carry: Array[Transform3D] = []
var _bow_leg_weight := 0.0

func setup(skeleton: Skeleton3D, path: String, target_path: String) -> bool:
	if not super.setup(skeleton, path, target_path):
		return false
	_left_arm = rig.find_bone("J_L_Arm")
	_right_arm = rig.find_bone("J_R_Arm")
	return _left_arm >= 0 and _right_arm >= 0

func set_crossbow_carry(pose: Array[Transform3D]) -> void:
	_crossbow_carry = pose

func reset() -> void:
	super.reset()
	_bow_leg_weight = 0.0

func apply(actor, key: String, delta: float) -> void:
	if actor.bow_equipped and actor.review_clip.is_empty() and key == Bow.ACTION and actor.combat_legs != null:
		_apply_bow_stride(actor, delta)
		return
	_bow_leg_weight = 0.0
	if actor.review_clip.is_empty() and key in WALKS:
		phase_advanced = 0.0
		phase_hz = 0.0
		owns_pose = false
		last_kind = "MD2Walk"
		_last_stage = actor._jump_stage
		return
	if actor.crossbow_equipped and actor.review_clip.is_empty() and key in RUNS:
		var duration: float = actor.clips[key].duration
		phase = fposmod(actor.animation_player.current_animation_position / duration, 1.0)
		phase_hz = actor._playback_speed / duration
		phase_advanced = delta * phase_hz
		var native: Array[Transform3D] = []
		for bone in rig.get_bone_count():
			native.append(rig.get_bone_pose(bone))
		var composed := crossbow_run_pose(native, phase)
		for bone in composed.size():
			rig.set_bone_pose(bone, composed[bone])
		last_kind = "CrossbowRun"
		run_weight = 1.0
		owns_pose = true
		_last_stage = actor._jump_stage
		return
	if last_kind == "MD2Walk" and key in RUNS:
		phase = fposmod(actor.animation_player.current_animation_position / float(actor.clips[key].duration), 1.0)
		run_weight = 1.0
	super.apply(actor, key, delta)

func _apply_bow_stride(actor, delta: float) -> void:
	phase_advanced = 0.0
	phase_hz = 0.0
	owns_pose = false
	last_kind = "BowAction"
	_last_stage = actor._jump_stage
	if not actor._grounded:
		_bow_leg_weight = 0.0
		return
	var moving: bool = actor._move_requested and actor.current_speed > 0.025
	if not moving and _bow_leg_weight <= 0.0:
		return
	run_weight = move_toward(run_weight, 1.0 if actor._run_requested else 0.0, delta / 0.22)
	var speed: float = actor.current_speed
	var walk_stride: float = float(actor.clips.Walk.duration) * actor.walk_stride_speed
	var cycle_distance := lerpf(walk_stride, period(1.0, 1.0), run_weight)
	var before: float = actor._gait_resume_phase
	phase_hz = speed / cycle_distance if moving else 0.0
	phase_advanced = delta * phase_hz
	phase = fposmod(before + phase_advanced, 1.0)
	actor._gait_resume_phase = phase
	actor._gait_cycles_this_tick += phase_advanced
	var pose: Array[Transform3D] = []
	if run_weight < 1.0:
		pose = actor.source_gait.sample("Walk", phase)
	if run_weight > 0.0:
		var run := _locals(_sample("Run", phase * float(streams.Run.duration)))
		if pose.is_empty():
			pose = run
		else:
			for bone: int in actor.combat_legs.bones:
				pose[bone] = pose[bone].interpolate_with(run[bone], run_weight)
	# Use the existing leg mask and raw-pose restoration. The Bow owns
	# the rest of the skeleton, including its draw and release clocks.
	actor.combat_legs.weight = _bow_leg_weight
	actor.combat_legs.apply(pose, moving, delta)
	_bow_leg_weight = actor.combat_legs.weight
	if moving and run_weight < 0.5:
		var duration: float = actor.clips.Walk.duration
		actor._dispatch_locomotion_events("Walk", before * duration, phase_advanced * duration, delta)

func crossbow_run_pose(native: Array[Transform3D], cycle: float) -> Array[Transform3D]:
	var actions_and_stuff := run_pose(cycle)
	for bone in _leg_bones:
		native[bone] = actions_and_stuff[bone]
	for bone in range(_hip_bone + 1):
		native[bone] = actions_and_stuff[bone]
	var spine := parents[_body_bone]
	native[spine] = native[spine].interpolate_with(actions_and_stuff[spine], CROSSBOW_TORSO_SWAY_WEIGHT)
	native[_body_bone] = native[_body_bone].interpolate_with(actions_and_stuff[_body_bone], CROSSBOW_TORSO_SWAY_WEIGHT)
	# Start from the MD2 walk's authored two-handed hold. Sampling two
	# independently animated run arms on top of this swing made the support
	# hand travel across the stock.
	native[_left_arm] = _crossbow_carry[_left_arm]
	native[_right_arm] = _crossbow_carry[_right_arm]
	# Transfer the alternating A&S arm swing to the paired MD2 grip.
	# Rotate around the line through both shoulders. Each shoulder stays
	# seated and the two hands share one rigid rotation with the weapon.
	var left_axis := actions_and_stuff[_left_arm].basis.z
	var right_axis := actions_and_stuff[_right_arm].basis.z
	var swing := (atan2(right_axis.y, right_axis.z) - atan2(left_axis.y, left_axis.z)) * 0.5
	var shoulder_axis := (native[_left_arm].origin - native[_right_arm].origin).normalized()
	var sway := Basis(shoulder_axis, swing * CROSSBOW_ARM_SWAY_WEIGHT)
	for bone in [_left_arm, _right_arm]:
		native[bone].basis = sway * native[bone].basis
	return native

func run_pose(cycle: float) -> Array[Transform3D]:
	return _locals(_sample("Run", (cycle + CROSSBOW_RUN_PHASE_OFFSET) * float(streams.Run.duration)))

func keep_shoulders_attached() -> void:
	# The paired grip already comes from the source shoulders.
	if owns_pose and last_kind == "CrossbowRun":
		owns_pose = false
		super.keep_shoulders_attached()
		owns_pose = true
		return
	super.keep_shoulders_attached()
