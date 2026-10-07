extends "res://scripts/player_ready_e3_integration.gd"
## R6-P visual-only branch in the existing sole writer; weapon layers run after it.
enum LocomotionMode { LEGACY_LOCOMOTION, REFERENCE_LOCOMOTION }
@export var locomotion_mode: LocomotionMode = LocomotionMode.REFERENCE_LOCOMOTION
# Exact approved R5 mode C values from scenes/dev/locomotion_lab_actor.gd.
@export var reference_full_turn_rate := 1.20
@export var reference_response_exponent := 1.35
@export var reference_filter_seconds := 0.10
@export var reference_gait_blend_seconds := 0.14
var reference_phase := 0.0
var reference_sprint_weight := 0.0
var reference_yaw_rate := 0.0
var reference_normalized_turn := 0.0
var reference_shaped_turn := 0.0
var reference_turn_amount := 0.0
var reference_clips := {}
const REFERENCE_CLIPS := ["Walk","WalkTurnLeft","WalkTurnRight","Sprint","SprintTurnLeft","SprintTurnRight"]

func _ready() -> void:
	super._ready()
	for name in REFERENCE_CLIPS:
		assert(samples.has(name),"Missing production reference clip "+name)
		reference_clips[name]=samples[name]
	_evaluate(0)

func set_locomotion_mode(mode: int) -> void:
	locomotion_mode=clampi(mode,0,1) as LocomotionMode
	_evaluate(0) # Both clocks keep running; rollback never restarts a gait.

func reference_sample_time(name: String) -> float:
	return reference_phase*reference_clips[name].clip.length

func update_motion(velocity_world: Vector3, target: Node3D, delta: float) -> void:
	var previous_yaw:=rotation.y
	super.update_motion(velocity_world,target,delta)
	# Preserve production facing and target orientation. Measure its actual raw
	# yaw delta, avoiding the Legacy secondary layer's already-filtered turn_rate.
	reference_yaw_rate=wrapf(rotation.y-previous_yaw,-PI,PI)/maxf(delta,0.001) if movement_speed>=LOCOMOTION_DEAD_ZONE and not frozen else 0.0

func _process(delta: float) -> void:
	if not frozen and not reference_clips.is_empty():
		var moving:=movement_speed>=LOCOMOTION_DEAD_ZONE
		var sprint: bool=get_parent().fast_sprinting and moving
		reference_sprint_weight=move_toward(reference_sprint_weight,1.0 if sprint else 0.0,delta/maxf(reference_gait_blend_seconds,0.001))
		if moving:
			reference_phase=fposmod(reference_phase+delta*lerpf(1.0/reference_clips.Walk.clip.length,1.0/reference_clips.Sprint.clip.length,reference_sprint_weight),1.0)
		reference_normalized_turn=clampf(-reference_yaw_rate/maxf(reference_full_turn_rate,0.001),-1,1) if moving else 0.0
		reference_shaped_turn=signf(reference_normalized_turn)*pow(absf(reference_normalized_turn),maxf(reference_response_exponent,0.01))
		reference_turn_amount=lerpf(reference_turn_amount,reference_shaped_turn,1.0-exp(-delta/maxf(reference_filter_seconds,0.001)))
	super._process(delta)

func _evaluate_locomotion_pose(_delta: float) -> bool:
	if locomotion_mode==LocomotionMode.LEGACY_LOCOMOTION or reference_clips.is_empty() or move_weight<=0.0: return false
	var amount:=reference_turn_amount
	var weight:=absf(amount)
	var straight_walk: RefCounted=reference_clips.Walk
	var straight_sprint: RefCounted=reference_clips.Sprint
	var turn_walk: RefCounted=reference_clips.WalkTurnLeft if amount<0 else reference_clips.WalkTurnRight
	var turn_sprint: RefCounted=reference_clips.SprintTurnLeft if amount<0 else reference_clips.SprintTurnRight
	var wt:=reference_sample_time("Walk")
	var st:=reference_sample_time("Sprint")
	for i in skeleton.get_bone_count():
		var wp:Vector3=straight_walk.position(i,wt).lerp(turn_walk.position(i,wt),weight)
		var sp:Vector3=straight_sprint.position(i,st).lerp(turn_sprint.position(i,st),weight)
		var wr:Quaternion=straight_walk.rotation(i,wt).slerp(turn_walk.rotation(i,wt),weight)
		var sr:Quaternion=straight_sprint.rotation(i,st).slerp(turn_sprint.rotation(i,st),weight)
		skeleton.set_bone_pose_position(i,idle.position(i,idle_time).lerp(wp.lerp(sp,reference_sprint_weight),move_weight))
		skeleton.set_bone_pose_rotation(i,idle.rotation(i,idle_time).slerp(wr.slerp(sr,reference_sprint_weight),move_weight).normalized())
	if aim_weight>0.0:
		# Keep the existing lower stride-plane / upper target-facing relationship.
		# Target eligibility changes during sprint release; use the existing aim
		# transition instead of inserting the whole offset on that first frame.
		var aimed_lower:=Quaternion.IDENTITY.slerp(lower_rotation,aim_weight)
		_rotate_global(hips,aimed_lower);_rotate_global(chest,aimed_lower.inverse())
	_apply_firing_recoil()
	for i in upper:
		skeleton.set_bone_pose_position(i,switch_positions[i].lerp(skeleton.get_bone_pose_position(i),switch_weight))
		skeleton.set_bone_pose_rotation(i,switch_rotations[i].slerp(skeleton.get_bone_pose_rotation(i),switch_weight).normalized())
	if generic_weapon_carry: _apply_weapon_carry()
	return true

func ready_run_blend_weight() -> float:
	return 0.0 if locomotion_mode==LocomotionMode.REFERENCE_LOCOMOTION else super.ready_run_blend_weight()

func ready_context_text() -> String:
	if locomotion_mode==LocomotionMode.LEGACY_LOCOMOTION or ready_move_weight<0.01: return super.ready_context_text()
	if weapon_behavior!=null and weapon_behavior.enabled and weapon_behavior.state!=weapon_behavior.State.READY:return "REFERENCE | "+weapon_behavior.State.keys()[weapon_behavior.state]
	return "REFERENCE READY | Walk: existing Hold; Run V7 correction excluded"

func debug_text() -> String:
	return super.debug_text()+"\nF6: %s | reference phase %.3f | Sprint %.2f | turn %+.2f | raw yaw %+.2f rad/s"%["LEGACY_LOCOMOTION" if locomotion_mode==0 else "REFERENCE_LOCOMOTION",reference_phase,reference_sprint_weight,reference_turn_amount,reference_yaw_rate]
