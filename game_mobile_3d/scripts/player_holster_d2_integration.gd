extends "res://scripts/player_blocky_v7_integration.gd"
## Final filtered layer inside the existing sole pose writer. No AnimationPlayer
## playback, IK, second skeleton or modification of locomotion clocks.
@export var authored_long_gun_holster: bool = true
const HOLSTER_BONES = ["Spine", "Chest", "Arm.L", "Arm.R", "Neck", "Head", "WeaponCarrier"]
const HOLSTER_EVENTS = {&"HOLSTER_BEGIN": 1, &"SUPPORT_HAND_RELEASE": 5, &"WEAPON_BACK_CONTACT": 15, &"HOLSTER_RELEASE": 16, &"HOLSTER_DONE": 18}
const HOLSTER_BLEND_IN = 0.10
const HOLSTER_BLEND_OUT = 0.12
signal holster_event(event_name: StringName, token: int)
var holster_pose: RefCounted
var holster_mask := PackedInt32Array()
var holster_active := false
var holster_token := -1
var holster_weapon := -1
var holster_entry_positions: Array[Vector3] = []
var holster_entry_rotations: Array[Quaternion] = []
var holster_fired := {}
var holster_event_log: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	holster_pose = samples.get("HolsterLongGun")
	assert(holster_pose != null and skeleton.find_bone("WeaponCarrier") >= 0)
	for name in HOLSTER_BONES: holster_mask.append(skeleton.find_bone(name))
	var carrier := skeleton.find_bone("WeaponCarrier")
	# WeaponCarrier is a direct Chest child: cache the approved final local frame
	# once. Back socket matches it, without solving any bone chain per frame.
	var endpoint := Transform3D(Basis(holster_pose.rotation(carrier, holster_duration())), holster_pose.position(carrier, holster_duration()))
	socket.prepare_transport_socket(endpoint)

func has_authored_holster() -> bool:
	return authored_long_gun_holster and holster_pose != null and Socket.Profiles.category(socket.equipped) == Socket.Profiles.Category.LONG_GUN

func holster_duration() -> float:
	return holster_pose.clip.length if holster_pose != null else 17.0 / 24.0

func holster_event_time(event_name: StringName) -> float:
	return float(HOLSTER_EVENTS[event_name] - 1) / 17.0 * holster_duration()

func start_authored_holster(token: int) -> void:
	holster_token = token; holster_weapon = socket.equipped
	holster_entry_positions.clear(); holster_entry_rotations.clear(); holster_fired.clear()
	for bone in holster_mask:
		holster_entry_positions.append(skeleton.get_bone_pose_position(bone))
		holster_entry_rotations.append(skeleton.get_bone_pose_rotation(bone))
	holster_active = true
	_evaluate(0.0)

func cancel_authored_holster() -> void:
	holster_active = false; holster_token = -1; holster_fired.clear()
	if socket.current_attachment == &"carrier": socket.end_transport(true)

func _evaluate(delta: float) -> void:
	super._evaluate(delta)
	if not holster_active or holster_pose == null: return
	if weapon_behavior == null or holster_token != weapon_behavior.request_id or holster_weapon != socket.equipped:
		cancel_authored_holster(); return
	var time: float = minf(weapon_behavior.transition_elapsed, holster_duration())
	var entering := smoothstep(0.0, HOLSTER_BLEND_IN, time)
	var exiting := smoothstep(holster_duration() - HOLSTER_BLEND_OUT, holster_duration(), time)
	for i in holster_mask.size():
		var bone := holster_mask[i]
		var p: Vector3 = holster_pose.position(bone, time)
		var q: Quaternion = holster_pose.rotation(bone, time)
		if skeleton.get_bone_name(bone) != "WeaponCarrier":
			p = holster_entry_positions[i].lerp(p, entering)
			q = holster_entry_rotations[i].slerp(q, entering)
			p = p.lerp(skeleton.get_bone_pose_position(bone), exiting)
			q = q.slerp(skeleton.get_bone_pose_rotation(bone), exiting)
		skeleton.set_bone_pose_position(bone, p)
		skeleton.set_bone_pose_rotation(bone, q.normalized())
	# Flush native bone attachments at event boundaries; no competing pose writer.
	skeleton.force_update_all_bone_transforms()
	socket.sync_transport_sockets()
	if not holster_fired.has(&"HOLSTER_BEGIN"):
		weapon_behavior.weapon_attach_to_carrier(holster_token)
	for event_name: StringName in HOLSTER_EVENTS:
		if holster_fired.has(event_name) or time + 0.000001 < holster_event_time(event_name): continue
		holster_fired[event_name] = true
		holster_event_log.append({"event": event_name, "time": time, "token": holster_token, "weapon": holster_weapon})
		if holster_event_log.size()>64: holster_event_log.pop_front()
		holster_event.emit(event_name, holster_token)
		if event_name == &"HOLSTER_RELEASE":
			weapon_behavior.weapon_release_carrier_to_back(holster_token)
	socket.update_transport(time, holster_event_time(&"HOLSTER_RELEASE"), holster_duration(), HOLSTER_BLEND_IN)
	if holster_fired.has(&"HOLSTER_DONE"):
		holster_active = false
		weapon_behavior.holster_finished(holster_token)
