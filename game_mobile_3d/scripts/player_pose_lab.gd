extends Node3D
## Development-only adapter. No changes to production runtime or gameplay input.
const STATES = [&"Idle", &"Walk", &"Run"]
const SPEEDS = [0.0, 4.25, 6.25]
const VIEWS = ["Front", "Side", "Rear", "3/4", "Isometric"]
const VIEW_ANGLES = [Vector2(0, 8), Vector2(90, 8), Vector2(180, 8), Vector2(35, 16), Vector2(37, 36)]
var locomotion := 0
var aiming := false
var animation_paused := false
var playback_speed := 1.0
var view_index := 3
var camera_mode := "3/4"
var yaw := deg_to_rad(35.0)
var pitch := deg_to_rad(16.0)
var distance := 3.8
var orbiting := false
var bounce_enabled := true
var bounce_strength := 1.0
@onready var visual: Node3D = $Player/Visual
@onready var camera: Camera3D = $Camera
@onready var status: Label = $HUD/Panel/Stack/Status

func _ready() -> void:
	# Use the same controller's public motion/state inputs and pose evaluator;
	# this adapter is its sole clock in this isolated scene.
	visual.set_process(false)
	_add_row(["1 Pistol", "2 M4A1", "3 Shotgun"], [equip.bind(0), equip.bind(1), equip.bind(2)])
	_add_row(["I Idle", "W Walk", "R Run"], [set_locomotion.bind(0), set_locomotion.bind(1), set_locomotion.bind(2)])
	_add_row(["L LowReady", "A Aim", "F Recoil"], [set_aim.bind(false), set_aim.bind(true), fire_recoil])
	_add_row(["Freeze / Play", "Step frame"], [toggle_pause, step_frame])
	_add_row(["N 1x", "H 0.5x", "Q 0.25x"], [set_speed.bind(1.0), set_speed.bind(0.5), set_speed.bind(0.25)])
	_add_row(["B Bounce ON/OFF", "T Hit"], [toggle_bounce, hit_preview])
	_add_row(["0%", "50%", "100%", "150%"], [set_bounce_strength.bind(0.0), set_bounce_strength.bind(0.5), set_bounce_strength.bind(1.0), set_bounce_strength.bind(1.5)])
	_add_row(["Front", "Side", "Rear"], [set_view.bind(0), set_view.bind(1), set_view.bind(2)])
	_add_row(["3/4", "Isometric", "C Reset"], [set_view.bind(3), set_view.bind(4), reset_camera])
	_add_row(["Orbit left", "Orbit right", "Zoom +", "Zoom -"], [rotate_camera.bind(-0.25), rotate_camera.bind(0.25), zoom.bind(0.85), zoom.bind(1.15)])
	_update_camera()
	_update_status()

func _add_row(labels: Array, actions: Array) -> void:
	var row := HBoxContainer.new()
	$HUD/Panel/Stack/Controls.add_child(row)
	for i in labels.size():
		var button := Button.new()
		button.text = labels[i]
		button.custom_minimum_size.y = 28
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(actions[i])
		row.add_child(button)

func equip(index: int) -> void:
	visual.equip_weapon(index)
	_update_status()

func set_locomotion(index: int) -> void:
	locomotion = clampi(index, 0, 2)
	_update_status()

func set_aim(value: bool) -> void:
	aiming = value
	_update_status()

func fire_recoil() -> void:
	# Production recoil, with no firing/projectile/damage service.
	visual.shot_recoil(Vector3.BACK)
	_update_status()

func toggle_pause() -> void:
	animation_paused = not animation_paused
	_update_status()

func set_speed(value: float) -> void:
	playback_speed = clampf(value, 0.25, 1.0)
	_update_status()

func toggle_bounce() -> void:
	bounce_enabled = not bounce_enabled
	visual.set_bounce(bounce_enabled, bounce_strength)
	_update_status()

func set_bounce_strength(value: float) -> void:
	bounce_strength = clampf(value, 0.0, 1.5)
	visual.set_bounce(bounce_enabled, bounce_strength)
	_update_status()

func hit_preview() -> void:
	visual.hit_impulse(Vector3.BACK)

func step_frame() -> void:
	if animation_paused:
		_advance(1.0 / 60.0)
		_update_status()

func _advance(delta: float) -> void:
	var animation_delta := delta * playback_speed
	visual.update_motion(Vector3.BACK * SPEEDS[locomotion], null, animation_delta)
	# Override target presence after motion input: no target/enemy is instantiated.
	visual.has_target = aiming
	visual._process(animation_delta)

func _process(delta: float) -> void:
	if not animation_paused: _advance(delta)
	_update_status()

func _update_status() -> void:
	status.text = "Weapon: %s\nPreview: %s | %s\nPose: %s | %s\nRecoil: %s (%.3fs)\nBounce: %s | %d%%\nPlayback: %.2fx | %s\nCamera: %s | %.2fm" % [
		visual.WEAPON_NAMES[visual.weapon_type], STATES[locomotion], "Aim" if aiming else "LowReady",
		visual.current_state, "Aim" if visual.aim_weight > 0.5 else "LowReady",
		"active" if visual.is_firing else ("queued" if visual.recoil_time == 0.0 else "settled"),
		visual.recoil_time if visual.recoil_time < 1.0 else 0.0,
		"ON" if bounce_enabled else "OFF", int(bounce_strength * 100),
		playback_speed, "FROZEN" if animation_paused else "playing", camera_mode, distance]

func set_view(index: int) -> void:
	view_index = index % VIEWS.size()
	camera_mode = VIEWS[view_index]
	yaw = deg_to_rad(VIEW_ANGLES[view_index].x)
	pitch = deg_to_rad(VIEW_ANGLES[view_index].y)
	_update_camera()

func reset_camera() -> void:
	distance = 3.8
	set_view(3)

func rotate_camera(amount: float) -> void:
	yaw = wrapf(yaw + amount, -PI, PI)
	camera_mode = "Orbit"
	_update_camera()

func zoom(factor: float) -> void:
	distance = clampf(distance * factor, 1.4, 8.0)
	_update_camera()

func _update_camera() -> void:
	var focus := Vector3(0, 1.02, 0)
	camera.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(focus)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		orbiting = false
	if event is InputEventMouseMotion and orbiting:
		yaw = wrapf(yaw - event.relative.x * 0.008, -PI, PI)
		pitch = clampf(pitch + event.relative.y * 0.008, deg_to_rad(-15), deg_to_rad(75))
		camera_mode = "Orbit"
		_update_camera()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT: orbiting = true
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom(1.1)
		else: return
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		match key:
			KEY_1, KEY_2, KEY_3: equip(key - KEY_1)
			KEY_I: set_locomotion(0)
			KEY_W: set_locomotion(1)
			KEY_R: set_locomotion(2)
			KEY_L: set_aim(false)
			KEY_A: set_aim(true)
			KEY_F: fire_recoil()
			KEY_B: toggle_bounce()
			KEY_T: hit_preview()
			KEY_SPACE: toggle_pause()
			KEY_PERIOD: step_frame()
			KEY_N: set_speed(1.0)
			KEY_H: set_speed(0.5)
			KEY_Q: set_speed(0.25)
			KEY_C: reset_camera()
			KEY_V: set_view(view_index + 1)
			_: return
		get_viewport().set_input_as_handled()
