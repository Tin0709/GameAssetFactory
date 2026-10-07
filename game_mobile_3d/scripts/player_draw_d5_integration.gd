extends "res://scripts/player_holster_d2_integration.gd"
## D5 adds a filtered Draw layer to the existing sole pose writer.
@export var authored_long_gun_draw := true
const DRAW_BLEND_IN := 0.125
const DRAW_BLEND_OUT := 0.10
const DRAW_BODY_BONES := ["Spine", "Chest", "Neck", "Head"]
const DrawTiming = preload("res://assets/characters/draw_long_gun_events.gd")
signal draw_event(event_name: StringName, token: int)
var draw_data: Dictionary
var draw_pose: RefCounted
var draw_mask := PackedInt32Array()
var draw_active := false
var draw_token := -1
var draw_weapon := -1
var draw_fired := {}
var draw_event_log: Array[Dictionary] = []
var draw_exit_time := -1.0
var draw_exit_positions: Array[Vector3] = []
var draw_exit_rotations: Array[Quaternion] = []
var draw_restarting := false
var draw_entry_positions: Array[Vector3] = []
var draw_entry_rotations: Array[Quaternion] = []

func _ready() -> void:
	super._ready()
	draw_data = DrawTiming.DATA
	draw_pose = samples.get("DrawLongGun")
	assert(draw_pose != null and absf(draw_pose.clip.length - float(draw_data.duration_seconds)) < 0.000001)
	for name: String in draw_data.bones: draw_mask.append(skeleton.find_bone(name))
	var carrier := skeleton.find_bone("WeaponCarrier")
	var carrier_endpoint := Transform3D(Basis(draw_pose.rotation(carrier, draw_duration())), draw_pose.position(carrier, draw_duration()))
	var hand_endpoint := Transform3D(Basis(long_gun_hold_pose.rotation(socket_bone, 0)), long_gun_hold_pose.position(socket_bone, 0))
	socket.prepare_draw_mounts(carrier_endpoint, hand_endpoint)

func has_authored_draw() -> bool:
	return authored_long_gun_draw and draw_pose != null and Socket.Profiles.category(socket.equipped) == Socket.Profiles.Category.LONG_GUN

func draw_duration() -> float:
	return float(draw_data.duration_seconds)

func draw_event_time(event_name: StringName) -> float:
	return float(draw_data.event_seconds[String(event_name)])

func start_authored_draw(token: int) -> void:
	draw_restarting = draw_exit_time >= 0.0
	draw_entry_positions.clear(); draw_entry_rotations.clear()
	for bone in draw_mask:
		draw_entry_positions.append(skeleton.get_bone_pose_position(bone))
		draw_entry_rotations.append(skeleton.get_bone_pose_rotation(bone))
	draw_token = token; draw_weapon = socket.equipped
	draw_fired.clear(); draw_exit_time = -1.0; draw_active = true
	_evaluate(0.0)

func _capture_draw_exit() -> void:
	draw_exit_positions.clear(); draw_exit_rotations.clear()
	for bone in draw_mask:
		draw_exit_positions.append(skeleton.get_bone_pose_position(bone))
		draw_exit_rotations.append(skeleton.get_bone_pose_rotation(bone))
	draw_exit_time = 0.0

func cancel_authored_draw(blend_back: bool = false) -> void:
	if blend_back and draw_active: _capture_draw_exit()
	else: draw_exit_time = -1.0
	draw_active = false; draw_token = -1; draw_fired.clear()

func finish_disabled_draw() -> void:
	# Behavior is being bypassed while the rifle is in flight. Keep its world
	# frame and captured upper pose, then settle into the normal disabled hold.
	socket.end_draw_transport()
	_capture_draw_exit(); draw_active = false; draw_token = -1
	weapon_hold_weight = 1.0; long_gun_weight = 1.0

func _evaluate(delta: float) -> void:
	super._evaluate(delta)
	if draw_pose == null: return # Base _ready evaluates before Draw setup.
	if draw_active:
		if weapon_behavior == null or draw_token != weapon_behavior.request_id or draw_weapon != socket.equipped:
			cancel_authored_draw(); return
		var time: float = minf(weapon_behavior.transition_elapsed, draw_duration())
		var entering := smoothstep(0.0, DRAW_BLEND_IN, time)
		for i in draw_mask.size():
			var bone := draw_mask[i]
			var name := skeleton.get_bone_name(bone)
			var p: Vector3 = draw_pose.position(bone, time)
			var q: Quaternion = draw_pose.rotation(bone, time)
			if name in DRAW_BODY_BONES:
				# Same additive body response as the approved Blender overlay.
				var rest := skeleton.get_bone_rest(bone)
				p = skeleton.get_bone_pose_position(bone) + p - rest.origin
				q = skeleton.get_bone_pose_rotation(bone) * rest.basis.get_rotation_quaternion().inverse() * q
			elif name != "WeaponCarrier" and not draw_restarting:
				p = skeleton.get_bone_pose_position(bone).lerp(p, entering)
				q = skeleton.get_bone_pose_rotation(bone).slerp(q, entering)
			if draw_restarting and name != "WeaponCarrier":
				p = draw_entry_positions[i].lerp(p, entering)
				q = draw_entry_rotations[i].slerp(q, entering)
			skeleton.set_bone_pose_position(bone, p)
			skeleton.set_bone_pose_rotation(bone, q.normalized())
		# Prepare the hidden destination frame; Carrier still owns the rifle.
		skeleton.set_bone_pose_position(socket_bone, long_gun_hold_pose.position(socket_bone, 0))
		skeleton.set_bone_pose_rotation(socket_bone, long_gun_hold_pose.rotation(socket_bone, 0))
		skeleton.force_update_all_bone_transforms()
		socket.on_skeleton_update(); socket.sync_transport_sockets()
		for key: String in draw_data.event_seconds:
			var event_name := StringName(key)
			if draw_fired.has(event_name) or time + 0.0000001 < draw_event_time(event_name): continue
			draw_fired[event_name] = true
			draw_event_log.append({"event":key,"time":time,"authored_time":draw_event_time(event_name),"token":draw_token,"weapon":draw_weapon})
			if draw_event_log.size() > 64: draw_event_log.pop_front()
			if event_name == &"WEAPON_BACK_RELEASE": weapon_behavior.weapon_draw_to_carrier(draw_token, time)
			draw_event.emit(event_name, draw_token)
		socket.update_draw_transport(time, draw_event_time(&"SUPPORT_HAND_CATCH"), draw_event_time(&"DRAW_READY"))
		if draw_fired.has(&"DRAW_READY"):
			weapon_behavior.weapon_draw_to_hand(draw_token)
			# The authored endpoint is already Hold_V2. Prime its underlying layer
			# before the exit blend so it cannot fade through the unarmed pose.
			weapon_hold_weight = 1.0; long_gun_weight = 1.0
			_capture_draw_exit(); draw_active = false
			weapon_behavior.draw_finished(draw_token)
	elif draw_exit_time >= 0.0 and not holster_active:
		draw_exit_time = minf(draw_exit_time + delta, DRAW_BLEND_OUT)
		var weight := smoothstep(0.0, DRAW_BLEND_OUT, draw_exit_time)
		for i in draw_mask.size():
			var bone := draw_mask[i]
			if skeleton.get_bone_name(bone) == "WeaponCarrier": continue
			skeleton.set_bone_pose_position(bone, draw_exit_positions[i].lerp(skeleton.get_bone_pose_position(bone), weight))
			skeleton.set_bone_pose_rotation(bone, draw_exit_rotations[i].slerp(skeleton.get_bone_pose_rotation(bone), weight).normalized())
		skeleton.force_update_all_bone_transforms(); socket.on_skeleton_update()
		if socket.current_attachment == &"hand": socket.finish_draw_mount(weight)
		if draw_exit_time >= DRAW_BLEND_OUT: draw_exit_time = -1.0
