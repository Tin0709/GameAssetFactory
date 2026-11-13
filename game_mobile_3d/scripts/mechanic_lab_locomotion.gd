extends "res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/hybrid_motion.gd"
## MechanicLab uses the source MD2 Walk for each weapon profile.

const WALKS := ["Walk", "StrafeLeft", "StrafeRight", "CombatWalk", "CombatStrafeLeft", "CombatStrafeRight"]
const RUNS := ["Run", "CombatRun"]
# Right-foot contact on the A&S cycle occurs just after the MD2 Walk seam.
const CROSSBOW_RUN_PHASE_OFFSET := 0.05
const CROSSBOW_ARM_SWAY_WEIGHT := 0.58
var _left_arm := -1
var _right_arm := -1
var _crossbow_carry: Array[Transform3D] = []

func setup(skeleton: Skeleton3D, path: String, target_path: String) -> bool:
	if not super.setup(skeleton, path, target_path):
		return false
	_left_arm = rig.find_bone("J_L_Arm")
	_right_arm = rig.find_bone("J_R_Arm")
	return _left_arm >= 0 and _right_arm >= 0

func set_crossbow_carry(pose: Array[Transform3D]) -> void:
	_crossbow_carry = pose

func apply(actor, key: String, delta: float) -> void:
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

func crossbow_run_pose(native: Array[Transform3D], cycle: float) -> Array[Transform3D]:
	var actions_and_stuff := run_pose(cycle)
	for bone in _leg_bones:
		native[bone] = actions_and_stuff[bone]
	for bone in range(_hip_bone + 1):
		native[bone] = actions_and_stuff[bone]
	var spine := parents[_body_bone]
	native[spine] = native[spine].interpolate_with(actions_and_stuff[spine], 0.7)
	native[_body_bone] = native[_body_bone].interpolate_with(actions_and_stuff[_body_bone], 0.7)
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
