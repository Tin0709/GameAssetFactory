extends "res://scripts/player_jump_loop_v003_visual.gd"
## Existing sole pose writer, weapon grips, contact support and combat limits.
var _landing:=false
var _landing_elapsed:=0.0
var _moving_takeoff:=false
var _landing_gait_requested:=false
var _landing_gait_elapsed:=0.0
const GAIT_BLEND_DURATION:=6.0/30.0
const TAKEOFF_GAIT_BLEND_DURATION:=7.0/30.0
func _ready() -> void:
	super._ready()
	jump_pose=samples["Jump_DungeonsII_Combined_v004"]
	jump_pose.clip.loop_mode=Animation.LOOP_NONE
	jump_duration=35.0/30.0

func select_jump(action:String,duration:float) -> void:
	# The moving landing now ends in the live gait, so blend the next takeoff
	# from that gait rather than snapping back to V004's neutral opening key.
	if _landing and movement_speed>LOCOMOTION_DEAD_ZONE:jump_blend=0.0
	_landing=false;_landing_elapsed=0.0
	_moving_takeoff=get_parent().jump_kind!=&"stationary"
	_landing_gait_requested=false;_landing_gait_elapsed=0.0
	super.select_jump(action,duration)

func _process(delta:float) -> void:
	if _landing and not frozen:
		_landing_elapsed+=delta
		if movement_speed>LOCOMOTION_DEAD_ZONE:_landing_gait_requested=true
		if _landing_gait_requested:_landing_gait_elapsed+=delta
	super._process(delta)

func _jump_bone_weight(name:String,weight:float) -> float:
	if name in ["Hips","Leg.L","Leg.R"]:
		if _landing and _landing_gait_requested:
			return weight*(1.0-smoothstep(0.0,GAIT_BLEND_DURATION,_landing_gait_elapsed))
		if not _landing and _moving_takeoff:
			# Ground anticipation keeps the live stride. Enter the airborne pose
			# only after lift-off; never pull moving feet into the neutral opening key.
			if not get_parent()._airborne:return 0.0
			var takeoff:float=get_parent().jump_profile.takeoff
			return weight*smoothstep(takeoff,takeoff+TAKEOFF_GAIT_BLEND_DURATION,jump_time)
	return weight

func begin_landing(from_time:float,contact_time:float) -> void:
	_landing=true;_landing_elapsed=0.0
	_landing_gait_requested=movement_speed>LOCOMOTION_DEAD_ZONE
	_landing_gait_elapsed=0.0
	_transition_pose=jump_pose
	_transition_time=from_time
	_transition_elapsed=0.0
	jump_time=contact_time

