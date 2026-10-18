extends Node3D
## Scene-local experiment coordinator. No production autoloads, input map or settings edits.
const ZOMBIE = preload("res://scenes/dev/zombie_death_physics/lab_zombie.gd")
@export var pistol_profile: Resource = preload("res://scenes/dev/zombie_death_physics/presets/pistol.tres")
@export var rifle_profile: Resource = preload("res://scenes/dev/zombie_death_physics/presets/rifle.tres")
@export var shotgun_profile: Resource = preload("res://scenes/dev/zombie_death_physics/presets/shotgun.tres")
@export_range(1, 8, 1) var maximum_active_ragdolls := 4
@export_range(0.2, 35, 0.05) var corpse_lifetime := 1.2
@export_range(0.1, 35, 0.05) var active_physics_duration := 1.2
@export_range(0.0, 2, 0.05) var airborne_extension := 0.6
@export_range(0.0, 0.4, 0.01) var landing_grace := 0.12
@export_range(0.0, 0.15, 0.01) var fade_duration := 0.08
@export var pool_corpses := true
var corpse_pool: Array[Node3D] = []
@export_range(1, 25, 0.1) var ragdoll_gravity := 9.8
@export_enum("60 Hz:60", "120 Hz:120") var simulation_hz := 120
@export_range(8, 32, 8) var solver_iterations := 32
var actor: Node3D
var zombies: Array[Node3D] = []
var animation_choice: OptionButton
var weapon_choice: OptionButton
var hit_choice: OptionButton
var direction_choice: OptionButton
var controls: Dictionary = {}
var telemetry: Label
var status: Label
var pause_button: Button
var profiles: Array[Resource] = []
var yaw := 0.65
var pitch := 0.28
var distance := 5.3
var camera_target := Vector3(0, 0.8, 0)
var physics_samples: Array[float] = []
var monitor_elapsed := 0.0
var monitor_warmup_until := 0
var measured_peak := 0.0
var orbiting := false
var stress_queued := false
var saved_solver_iterations := 16.0
var lab_space: RID
var saved_physics_hz := 60
var saved_max_fps := 0
@onready var camera: Camera3D = $InspectionCamera

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	maximum_active_ragdolls = clampi(maximum_active_ragdolls, 1, 8)
	profiles = [pistol_profile, rifle_profile, shotgun_profile]
	saved_max_fps = Engine.max_fps
	Engine.max_fps = 30
	saved_physics_hz = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = simulation_hz
	lab_space = get_world_3d().space
	saved_solver_iterations = PhysicsServer3D.space_get_param(lab_space, PhysicsServer3D.SPACE_PARAM_SOLVER_ITERATIONS)
	PhysicsServer3D.space_set_param(lab_space, PhysicsServer3D.SPACE_PARAM_SOLVER_ITERATIONS, solver_iterations)
	_build_ui()
	reset_zombie()
	_update_camera()

func _exit_tree() -> void:
	for zombie in corpse_pool: zombie.free()
	corpse_pool.clear()
	Engine.max_fps = saved_max_fps
	Engine.physics_ticks_per_second = saved_physics_hz
	if lab_space.is_valid():
		PhysicsServer3D.space_set_param(lab_space, PhysicsServer3D.SPACE_PARAM_SOLVER_ITERATIONS, saved_solver_iterations)
	Engine.time_scale = 1.0
	get_tree().paused = false

func _label(parent: Node, value: String, size: int = 15) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size.y = 34
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	b.pressed.connect(callback)
	return b

func _choice(parent: Node, title: String, values: Array) -> OptionButton:
	_label(parent, title)
	var choice := OptionButton.new()
	for value in values: choice.add_item(value)
	choice.custom_minimum_size.y = 31
	parent.add_child(choice)
	return choice

func _number(parent: Node, key: String, title: String, low: float, high: float, step: float, value: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _label(row, title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = value
	spin.custom_minimum_size.x = 104
	row.add_child(spin)
	controls[key] = spin
	return spin

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	margin.offset_left = -362
	margin.offset_right = -12
	margin.offset_top = 12
	margin.offset_bottom = -12
	layer.add_child(margin)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17232eee")
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.corner_radius_top_left = 12
	style.corner_radius_bottom_left = 12
	panel.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.name = "ExperimentControls"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 7)
	scroll.add_child(box)
	_label(box, "ZOMBIE / DEATH PHYSICS", 21)
	_label(box, "V002 · IMPACT + SHORT LIFETIME", 11)
	var note := _label(box, "Original rig + original runtime clips\n7 bodies / 6 limited joints · rigid limbs", 13)
	note.modulate = Color("acc4d7")
	animation_choice = _choice(box, "Starting animation (resets zombie)", ["Idle", "Walk", "Attack"])
	animation_choice.item_selected.connect(func(_id): reset_zombie())
	weapon_choice = _choice(box, "Death profile", ["Pistol — Light", "Rifle — Medium", "Shotgun — Heavy / rotational"])
	weapon_choice.item_selected.connect(_load_profile)
	_number(box, "linear", "Linear impulse · N s", 0, 900, 1, 180)
	_number(box, "angular", "Extra torque · N m s", 0, 20, 0.1, 0.7)
	_number(box, "up", "Upward impulse · N s", 0, 360, 1, 108)
	_number(box, "distance", "Shot distance · m", 0.5, 20, 0.1, 1.5)
	hit_choice = _choice(box, "Hit location", ["Chest", "Right shoulder", "Left shoulder", "Head", "Hip"])
	hit_choice.select(1)
	direction_choice = _choice(box, "World hit direction (pushes toward)", ["Back (−Z)", "Front (+Z)", "Left (−X)", "Right (+X)", "Diagonal"])
	var action_row := HBoxContainer.new()
	box.add_child(action_row)
	_button(action_row, "TRIGGER DEATH  [Space]", trigger_death).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(box, "Reset Zombie  [R]", reset_zombie)
	status = _label(box, "Ready", 13)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(box, "Simulation", 17)
	var slow := _number(box, "speed", "Time scale", 0.1, 1, 0.1, 1)
	slow.value_changed.connect(func(value): Engine.time_scale = value)
	pause_button = _button(box, "Pause / Resume  [P]", toggle_pause)
	var speed := _number(box, "walk", "Walk travel · m/s", 0, 2, 0.05, 0.65)
	speed.value_changed.connect(func(value):
		for zombie in zombies:
			if not zombie.dead: zombie.walk_speed = value)
	var gravity := _number(box, "gravity", "Corpse gravity · m/s²", 1, 25, 0.1, ragdoll_gravity)
	gravity.tooltip_text = "18 matches the existing Zombie controller. 9.8 tests project-default gravity."
	var hz_choice := _choice(box, "Lab physics rate (resets all actors)", ["60 Hz — contact experiment", "120 Hz — stable review preset"])
	hz_choice.select(1 if simulation_hz == 120 else 0)
	hz_choice.item_selected.connect(func(index):
		simulation_hz = 60 if index == 0 else 120
		Engine.physics_ticks_per_second = simulation_hz
		reset_zombie())
	_label(box, "Joint limits + damping (next death)", 15)
	_number(box, "limits", "Angular limit multiplier", 0.2, 2, 0.05, 0.85)
	_number(box, "linear_damp", "Linear damping · 1/s", 0, 5, 0.05, 0.25)
	_number(box, "angular_damp", "Angular damping · 1/s", 0, 8, 0.05, 0.9)
	_number(box, "resistance", "Joint resistance", 0, 2.5, 0.05, 1.0)
	_number(box, "transport", "Whole-body force share", 0, 0.98, 0.01, 0.9)
	var passive := _label(box, "Resistance calms limb flailing for 2 s.\nLower limits keep the body connected.", 12)
	passive.modulate = Color("acc4d7")
	_label(box, "Corpse cleanup (simulation seconds)", 17)
	_number(box,"lifetime","Total death lifetime · s",.2,35,.05,corpse_lifetime).value_changed.connect(func(v): corpse_lifetime=v)
	_number(box,"physics_time","Active physics target · s",.1,35,.05,active_physics_duration).value_changed.connect(func(v): active_physics_duration=v)
	_number(box,"air_extension","Air / landing extension · s",0,2,.05,airborne_extension).value_changed.connect(func(v): airborne_extension=v)
	_number(box,"landing_grace","Landing grace · s",0,.4,.01,landing_grace).value_changed.connect(func(v): landing_grace=v)
	_number(box,"fade","Fade within lifetime · s",0,.15,.01,fade_duration).value_changed.connect(func(v): fade_duration=v)
	var recycle := CheckButton.new()
	recycle.text = "Pool visual models (physics rebuilt)"
	recycle.button_pressed = pool_corpses
	box.add_child(recycle)
	recycle.toggled.connect(func(v):
		pool_corpses=v
		if not v:
			for z in corpse_pool: z.queue_free()
			corpse_pool.clear())
	var lifetime_note := _label(box,"Physics target is soft while falling/moving.\nOnly a grounded, settled pose may be parked.\nExtension is bounded; no midair freeze.",12)
	lifetime_note.modulate = Color("acc4d7")
	_label(box, "Inspection camera", 17)
	var views := HBoxContainer.new()
	box.add_child(views)
	_button(views, "Front [F1]", func(): set_view(0))
	_button(views, "Side [F2]", func(): set_view(1))
	_button(views, "¾ [F3]", func(): set_view(2))
	_label(box, "Right-drag: orbit · Wheel: zoom", 12)
	_label(box, "Basic simultaneous-death test", 17)
	_number(box, "cap", "Max ragdolls", 1, 8, 1, maximum_active_ragdolls).value_changed.connect(func(value):
		maximum_active_ragdolls = int(value)
		reset_zombie())
	_button(box, "Reset + stress test (up to cap)", stress_test)
	telemetry = _label(box, "", 12)
	telemetry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_load_profile(0)
	var hint := Label.new()
	hint.text = "ZOMBIE DEATH PHYSICS LAB   /   Development scene only\nSpace: death   R: reset   P: pause   F1–F3: views"
	hint.position = Vector2(24, 20)
	hint.add_theme_font_size_override("font_size", 15)
	layer.add_child(hint)

func _load_profile(index: int) -> void:
	var p: Resource = profiles[index]
	for pair in [["linear", "linear_impulse"], ["angular", "angular_impulse"], ["up", "upward_impulse"], ["limits", "limit_scale"], ["linear_damp", "linear_damping"], ["angular_damp", "angular_damping"], ["resistance", "joint_resistance"], ["transport", "transport_fraction"]]:
		controls[pair[0]].value = p.get(pair[1])

func trial_profile() -> Resource:
	var p: Resource = profiles[weapon_choice.selected].duplicate(true)
	p.linear_impulse = controls.linear.value
	p.angular_impulse = controls.angular.value
	p.upward_impulse = controls.up.value
	p.limit_scale = controls.limits.value
	p.linear_damping = controls.linear_damp.value
	p.angular_damping = controls.angular_damp.value
	p.joint_resistance = controls.resistance.value
	p.transport_fraction = controls.transport.value
	return p

func _spawn(at: Vector3) -> Node3D:
	var zombie: Node3D
	if pool_corpses and not corpse_pool.is_empty():
		zombie = corpse_pool.pop_back()
		zombie.reset_for_reuse(at)
	else:
		zombie = Node3D.new()
		zombie.set_script(ZOMBIE)
		zombie.position = at
		zombie.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(zombie)
	zombie.name = "LabZombie_%d" % zombies.size()
	zombie.walk_speed = controls.walk.value
	zombie.set_state(animation_choice.get_item_text(animation_choice.selected))
	zombies.append(zombie)
	return zombie

func _retire(zombie: Node3D) -> void:
	zombie.retire()
	if pool_corpses and corpse_pool.size() < maximum_active_ragdolls:
		corpse_pool.append(zombie)
	else:
		remove_child(zombie)
		zombie.queue_free()

func _clear() -> void:
	for zombie in zombies:
		if is_instance_valid(zombie):
			_retire(zombie)
	zombies.clear()
	while corpse_pool.size()>maximum_active_ragdolls: corpse_pool.pop_back().queue_free()
	actor = null
	stress_queued = false
	physics_samples.clear()
	measured_peak = 0.0
	monitor_warmup_until = Time.get_ticks_msec() + 1250
	telemetry.text = "Warming physics monitor…"

func reset_zombie() -> void:
	_clear()
	actor = _spawn(Vector3.ZERO)
	camera_target = Vector3(0, 0.8, 0)
	distance = 5.3
	status.text = "Alive · %s · all presets await visual review" % actor.state

func direction() -> Vector3:
	return [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3(-0.45,0,-1).normalized()][direction_choice.selected]

func trigger_death() -> void:
	var count := 0
	for zombie in zombies:
		if zombie.dead and zombie.ragdoll.running: count += 1
	for zombie in zombies:
		if zombie.dead: continue
		if count >= maximum_active_ragdolls: break
		zombie.request_death(trial_profile(), direction(), hit_choice.get_item_text(hit_choice.selected), controls.distance.value, controls.gravity.value)
		count += 1
	status.text = "%s · %s · %d admitted\nReset before changing start pose. Profile values affect the next death." % [weapon_choice.get_item_text(weapon_choice.selected), hit_choice.get_item_text(hit_choice.selected), count]

func stress_test() -> void:
	maximum_active_ragdolls = clampi(maximum_active_ragdolls, 1, 8)
	_clear()
	for i in maximum_active_ragdolls:
		var x := (float(i % 4) - float(mini(maximum_active_ragdolls, 4) - 1) * 0.5) * 1.65
		var zombie := _spawn(Vector3(x, 0, -float(i / 4) * 2.0))
		if i == 0: actor = zombie
	distance = 7.5 if maximum_active_ragdolls <= 4 else 10.0
	camera_target = Vector3(0, 0.8, -0.8)
	stress_queued = true
	status.text = "Warming original animation for 0.5 s, then simultaneous deaths…"

func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_button.text = "Resume  [P]" if get_tree().paused else "Pause / Resume  [P]"

func set_view(index: int) -> void:
	yaw = [0.0, PI * 0.5, 0.65][index]
	pitch = 0.22 if index < 2 else 0.28
	_update_camera()

func _update_camera() -> void:
	camera.position = camera_target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(camera_target)
	# Keep the subject centered in the visible area beside the 350px panel at any zoom.
	camera.h_offset = 187.0 * (2.0 * distance * tan(deg_to_rad(camera.fov * 0.5))) / maxf(1.0, get_viewport().get_visible_rect().size.y)

func _process(delta: float) -> void:
	if not zombies.is_empty():
		var center := Vector3.ZERO
		var has_corpse := false
		for zombie in zombies:
			if zombie.dead:
				center += zombie.corpse_center if zombie.corpse_parked else zombie.ragdoll.bodies.Chest.global_position
				has_corpse = true
			else: center += zombie.global_position + Vector3(0,0.8,0)
		center /= zombies.size()
		center.y = maxf(0.55, center.y) if has_corpse else 0.8
		camera_target = camera_target.lerp(center, 1.0 - exp(-(14.0 if has_corpse else 3.5) * delta))
	_update_camera()
	if get_tree().paused: return
	if stress_queued and is_instance_valid(actor) and actor.elapsed >= 0.5:
		stress_queued = false
		trigger_death()
	var remove_list: Array[Node3D] = []
	for zombie in zombies:
		if not zombie.dead: continue
		if not zombie.corpse_parked:
			zombie.corpse_center = zombie.ragdoll.bodies.Chest.global_position
			var motion: Dictionary = zombie.ragdoll.contact_motion()
			if motion.core_contacts > 0:
				if zombie.first_contact_age < 0: zombie.first_contact_age = zombie.age
			else: zombie.first_contact_age = -1.0
			if motion.core_contacts > 0 and motion.contacts >= 2 and motion.linear < .55 and motion.angular < 1.3:
				zombie.stable_contact_time += delta
			else: zombie.stable_contact_time = 0.0
			if zombie.age >= active_physics_duration and zombie.stable_contact_time >= .1:
				zombie.ragdoll.release(zombie.visible_pose)
				zombie.corpse_parked = true
		if zombie.corpse_center.y < -15:
			remove_list.append(zombie)
			continue
		var fade := minf(fade_duration,corpse_lifetime)
		var base_end := corpse_lifetime
		var hard_end := base_end + airborne_extension
		var landing_seen: bool = zombie.corpse_parked or (zombie.first_contact_age >= 0 and zombie.age-zombie.first_contact_age >= landing_grace)
		# Landing protection may extend the nominal deadline, never indefinitely.
		if zombie.fade_started < 0 and zombie.age >= base_end-fade and (landing_seen or zombie.age >= hard_end-fade):
			zombie.fade_started = zombie.age
		if zombie.fade_started >= 0:
			var progress: float = (zombie.age-zombie.fade_started)/maxf(.0001,fade)
			if fade > 0: zombie.fade_out(progress)
			if progress >= 1.0 or fade == 0: remove_list.append(zombie)
	for zombie in remove_list:
		zombies.erase(zombie)
		if zombie == actor: actor = null
		_retire(zombie)
		status.text = "Corpse cleaned: physics/joints removed. Press R to respawn."
	if Time.get_ticks_msec() < monitor_warmup_until: return
	monitor_elapsed += delta
	if monitor_elapsed < 0.25: return
	monitor_elapsed = 0.0
	var ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	physics_samples.append(ms)
	if physics_samples.size() > 240: physics_samples.pop_front()
	measured_peak = maxf(measured_peak, ms)
	var alive := 0
	var dead := 0
	var sleeping := 0
	var active := 0
	var parked := 0
	var anchors := 0.0
	for zombie in zombies:
		if not zombie.dead:
			alive += 1
			continue
		dead += 1
		if zombie.corpse_parked:
			parked += 1
			continue
		active += 1
		anchors = maxf(anchors, zombie.ragdoll.max_anchor_error())
		for body in zombie.ragdoll.bodies.values():
			var direct := PhysicsServer3D.body_get_direct_state(body.get_rid())
			if direct and direct.sleeping: sleeping += 1
	telemetry.text = "Alive %d · Active %d / %d · Parked %d\nBodies %d · Joints %d · Sleeping bodies %d\nPooled visuals %d (zero physics)\nPhysics monitor %.3f ms · peak %.3f ms\nJoint anchor error %.1f mm\nGodot %s · %d Hz\nDesktop observation ≠ mobile validation\nLifetime %.2f s + up to %.2f s landing grace" % [alive, active, maximum_active_ragdolls, parked, active*7, active*6, sleeping, corpse_pool.size(), ms, measured_peak, anchors*1000, Engine.get_version_info().string, Engine.physics_ticks_per_second,corpse_lifetime,airborne_extension]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: orbiting = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(2.3, distance - 0.3)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(15, distance + 0.3)
	elif event is InputEventMouseMotion and orbiting:
		yaw -= event.relative.x * 0.007
		pitch = clampf(pitch + event.relative.y * 0.005, -0.05, 1.15)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: trigger_death()
			KEY_R: reset_zombie()
			KEY_P: toggle_pause()
			KEY_F1: set_view(0)
			KEY_F2: set_view(1)
			KEY_F3: set_view(2)
