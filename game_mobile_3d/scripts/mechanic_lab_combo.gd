extends "res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/combo_state.gd"
## Lab-only pause of a confirmed ground strike. The input clock keeps running.

const MAX_IMPACT_PAUSE := 0.060

var impact_pause_left := 0.0
var _paused_serial := -1

func pause_after_contact(attack_serial: int, seconds: float) -> void:
	if seconds > 0.0 and phase == &"attack" and serial == attack_serial and _paused_serial != serial:
		_paused_serial = serial
		impact_pause_left = minf(seconds, MAX_IMPACT_PAUSE)

func boundary_seconds() -> float:
	return impact_pause_left if impact_pause_left > 0.0 else super.boundary_seconds()

func movement_allowed() -> bool:
	return impact_pause_left <= 0.0 and super.movement_allowed()

func movement_plan(delta: float) -> Array[Dictionary]:
	var paused := minf(maxf(delta, 0.0), impact_pause_left)
	if paused <= 0.0:
		return super.movement_plan(delta)
	var plan: Array[Dictionary] = [{"duration": paused, "move": false, "phase": phase,
		"index": index, "time": time, "serial": serial}]
	plan.append_array(super.movement_plan(delta - paused))
	return plan

func request_attack(airborne := false) -> void:
	if impact_pause_left <= 0.0 or airborne:
		if airborne:
			impact_pause_left = 0.0
		super.request_attack(airborne)
	elif native_input_policy != "live_hold" or native_tap_buffer_seconds > 0.0:
		var window := native_tap_buffer_seconds if native_input_policy == "live_hold" else buffer_seconds
		buffer_until = clock + window

func advance(delta: float, hold_air_pose := false) -> void:
	if impact_pause_left <= 0.0:
		super.advance(delta, hold_air_pose)
		return
	var paused := minf(delta, impact_pause_left)
	if buffer_until >= clock - 0.0000001:
		buffer_until += paused
	clock += paused
	impact_pause_left -= paused
	if delta > paused:
		super.advance(delta - paused, hold_air_pose)

func cancel() -> void:
	impact_pause_left = 0.0
	super.cancel()
