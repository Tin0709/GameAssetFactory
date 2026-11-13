extends "res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/hybrid_motion.gd"
## MechanicLab uses the source MD2 Walk for each weapon profile.

const WALKS := ["Walk", "StrafeLeft", "StrafeRight", "CombatWalk", "CombatStrafeLeft", "CombatStrafeRight"]
const RUNS := ["Run", "CombatRun"]
# Right-foot contact on the A&S cycle occurs just after the MD2 Walk seam.
const CROSSBOW_RUN_PHASE_OFFSET := 0.05

func apply(actor, key: String, delta: float) -> void:
	if actor.review_clip.is_empty() and key in WALKS:
		phase_advanced = 0.0
		phase_hz = 0.0
		run_weight = move_toward(run_weight, 0.0, delta / 0.22)
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
	super.apply(actor, key, delta)

func crossbow_run_pose(native: Array[Transform3D], cycle: float) -> Array[Transform3D]:
	var actions_and_stuff := run_pose(cycle)
	# Carry both authored MD2 arms as a unit with the A&S torso. The arm,
	# wrist and weapon joints keep their relative transforms through the run.
	for bone in _leg_bones:
		native[bone] = actions_and_stuff[bone]
	for bone in range(_hip_bone + 1):
		native[bone] = actions_and_stuff[bone]
	var spine := parents[_body_bone]
	native[spine] = native[spine].interpolate_with(actions_and_stuff[spine], 0.7)
	native[_body_bone] = native[_body_bone].interpolate_with(actions_and_stuff[_body_bone], 0.7)
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
