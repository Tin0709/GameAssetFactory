extends Node
## D0 foundation. Timer handoffs are temporary until authored Blender events.
const Profiles = preload("res://scripts/weapon_fire_profiles.gd")
enum State { STOWED, DRAWING, READY, HOLSTERING }
signal state_changed(previous: int, current: int)
signal transition_requested(kind: StringName, request_id: int, weapon: int)
signal attachment_changed(socket_name: StringName)
@export var enabled: bool = true
@export var debug_visible: bool = true
@export var holster_grace_seconds: float = 1.5
@export_range(1.0, 2.0) var retain_range_multiplier: float = 1.20
@export var placeholder_transitions: bool = true
@export var long_gun_draw_seconds: float = 0.55
@export var long_gun_holster_seconds: float = 0.70
@export var pistol_draw_seconds: float = 0.35
@export var pistol_holster_seconds: float = 0.45
@export_range(0.0, 1.0) var placeholder_handoff_fraction: float = 0.5
var state: State = State.STOWED
var request_id: int = 0
var grace_elapsed: float = 0.0
var transition_elapsed: float = 0.0
var handoff_done: bool = false
var threat_present: bool = false
var suspended: bool = false
var visual: Node3D
var gun: Node3D
var socket: BoneAttachment3D
var authored_holster := false

func _cancel_authored() -> void:
	if visual.has_method("cancel_authored_holster"): visual.cancel_authored_holster()
	authored_holster = false

func _ready() -> void:
	process_physics_priority = -1
	visual = get_parent().get_node("Visual"); gun = get_parent().get_node("Pistol")
	socket = visual.socket
	visual.weapon_behavior = self; gun.weapon_behavior = self
	gun.awareness_range_multiplier = retain_range_multiplier
	socket.prepare_stow_sockets(); _attach_stowed()

func is_ready() -> bool:
	return not suspended and (not enabled or (state == State.READY and socket.current_attachment == &"hand" and visual.weapon_equipped))

func carry_requested() -> bool:
	return visual.weapon_equipped and (not enabled or socket.current_attachment == &"hand")

func _physics_process(delta: float) -> void:
	if get_parent().is_dead or not get_parent().is_physics_processing():
		if not suspended:
			_cancel_authored()
			suspended = true; request_id += 1; transition_elapsed = 0.0
			threat_present = false
			_set_state(State.READY if socket.current_attachment == &"hand" else State.STOWED)
		return
	suspended = false
	if not enabled:
		_cancel_authored()
		if state != State.READY:
			request_id += 1
			weapon_attach_to_hand(); _set_state(State.READY)
		return
	if not visual.weapon_equipped:
		threat_present = false; grace_elapsed = 0.0
		if state != State.STOWED or socket.current_attachment == &"hand":
			_cancel_authored()
			request_id += 1; _attach_stowed(); _set_state(State.STOWED)
		socket.set_equipped_visible(false)
		return
	socket.set_equipped_visible(true)
	gun.awareness_range_multiplier = retain_range_multiplier
	threat_present = is_instance_valid(gun.awareness_target(state != State.STOWED))
	if threat_present:
		grace_elapsed = 0.0
		if state == State.STOWED: _begin(State.DRAWING)
		elif state == State.HOLSTERING:
			if authored_holster: pass # Finish safely; re-check threat after DONE.
			elif socket.current_attachment == &"hand":
				request_id += 1; _set_state(State.READY)
			else: _begin(State.DRAWING)
	elif state == State.READY:
		grace_elapsed += delta
		if grace_elapsed >= holster_grace_seconds: _begin(State.HOLSTERING)
	if authored_holster and state == State.HOLSTERING:
		transition_elapsed = minf(transition_elapsed + delta, visual.holster_duration())
		return # Visual sole pose writer emits centralized clip events after posing.
	if placeholder_transitions and state in [State.DRAWING, State.HOLSTERING]:
		transition_elapsed += delta
		var duration := transition_duration()
		# Single documented placeholder handoff, replaced later by clip markers.
		if not handoff_done and transition_elapsed >= duration * placeholder_handoff_fraction:
			handoff_done = true
			if state == State.DRAWING: weapon_attach_to_hand(request_id)
			else: _attach_stowed(request_id)
		if transition_elapsed >= duration:
			if state == State.DRAWING: draw_finished(request_id)
			else: holster_finished(request_id)

func transition_duration() -> float:
	if authored_holster and state == State.HOLSTERING: return visual.holster_duration()
	var long_gun := Profiles.category(socket.equipped) == Profiles.Category.LONG_GUN
	if state == State.DRAWING: return maxf(0.001, long_gun_draw_seconds if long_gun else pistol_draw_seconds)
	return maxf(0.001, long_gun_holster_seconds if long_gun else pistol_holster_seconds)

func _begin(next: State) -> void:
	request_id += 1; transition_elapsed = 0.0; handoff_done = false
	_set_state(next)
	authored_holster = next == State.HOLSTERING and visual.has_method("has_authored_holster") and visual.has_authored_holster()
	if authored_holster: visual.start_authored_holster(request_id)
	transition_requested.emit(&"Draw" if next == State.DRAWING else &"Holster", request_id, socket.equipped)

func _set_state(next: State) -> void:
	if state == next: return
	var previous := state; state = next
	state_changed.emit(previous, state)

func _valid_event(token: int) -> bool:
	return not suspended and (token < 0 or (enabled and token == request_id))

func weapon_attach_to_hand(token: int = -1) -> void:
	if not _valid_event(token): return
	socket.attach_equipped(&"hand"); attachment_changed.emit(&"WeaponAttachment")

func weapon_attach_to_carrier(token: int) -> void:
	if not _valid_event(token) or not authored_holster or state != State.HOLSTERING: return
	socket.begin_transport(); attachment_changed.emit(&"WeaponCarrierSocket")

func weapon_release_carrier_to_back(token: int) -> void:
	if not _valid_event(token) or not authored_holster or socket.current_attachment != &"carrier": return
	socket.end_transport(true); attachment_changed.emit(&"BackWeaponSocket")

func weapon_attach_to_back(token: int = -1) -> void:
	if not _valid_event(token) or Profiles.category(socket.equipped) != Profiles.Category.LONG_GUN: return
	socket.attach_equipped(&"back"); attachment_changed.emit(&"BackWeaponSocket")

func weapon_attach_to_hip(token: int = -1) -> void:
	if not _valid_event(token) or Profiles.category(socket.equipped) != Profiles.Category.PISTOL: return
	socket.attach_equipped(&"hip"); attachment_changed.emit(&"HipWeaponSocket_R")

func _attach_stowed(token: int = -1) -> void:
	if Profiles.category(socket.equipped) == Profiles.Category.LONG_GUN: weapon_attach_to_back(token)
	else: weapon_attach_to_hip(token)

func draw_finished(token: int = -1) -> void:
	if not _valid_event(token) or state != State.DRAWING or socket.current_attachment != &"hand": return
	grace_elapsed = 0.0; _set_state(State.READY)

func holster_finished(token: int = -1) -> void:
	if not _valid_event(token) or state != State.HOLSTERING or socket.current_attachment == &"hand": return
	_set_state(State.STOWED)
	if authored_holster:
		authored_holster = false
		if threat_present: _begin(State.DRAWING)

func on_weapon_switched() -> void:
	_cancel_authored()
	request_id += 1 # Reject events from the prior weapon/clip.
	if state == State.READY: weapon_attach_to_hand()
	elif state == State.DRAWING:
		_attach_stowed(); _begin(State.DRAWING)
	else:
		_attach_stowed(); _set_state(State.STOWED); grace_elapsed = 0.0

func debug_text() -> String:
	return "Weapon %s | threat %s | grace %.2f/%.2f | %s%s" % [State.keys()[state], threat_present, grace_elapsed, holster_grace_seconds, socket.current_attachment, " | AUTHORED HOLSTER" if authored_holster else (" | PLACEHOLDER" if placeholder_transitions else "")]
