extends Control
## Touch overlay for device review builds of the existing WorldMap.

const MOVE := [&"move_left", &"move_right", &"move_forward", &"move_backward"]
const HOURS := [7., 12., 16.5, 19.5, 22.]
const STICK_RADIUS := 65.
const BUTTON_SIZE := Vector2(88., 58.)
const MOUSE_POINTER := -2
const Benchmark := preload("res://scripts/world_map_device_benchmark.gd")
const REVIEW_SITES := [
	{"name": "Lối rừng", "position": Vector2(-22.5, 17.5), "zoom": 18.},
	{"name": "Bậc đá", "position": Vector2(-22.5, -40.5), "zoom": 26.},
]

var _world: Node
var _benchmark: Benchmark
var _held: Dictionary = {}
var _stick_id := -1
var _stick_offset := Vector2.ZERO
var _refresh_after := 0.


func setup(world: Node) -> void:
	_world = world
	AudioServer.set_bus_mute(0, true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world.showcase.panel.visibility_changed.connect(_release_controls)
	_world.showcase._settings.gear.hide()
	if _world.map_layout_path == _world.DATA:
		_benchmark = Benchmark.new()
		_benchmark.name = "DeviceBenchmark"
		add_child(_benchmark)
		_benchmark.setup(_world, REVIEW_SITES)
	print("GAF_DEVICE_REVIEW renderer=%s driver=%s scene=WorldMap assets=project" % [
		RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name()])


func _stick_center() -> Vector2:
	return Vector2(155., size.y - 147.)


func _buttons() -> Dictionary:
	var right := size.x - 153.
	var measure_button := Rect2(Vector2(right - 495., 40.), BUTTON_SIZE)
	if _benchmark != null and _benchmark.active:
		return {&"measure": measure_button}
	var buttons := {
		&"jump": Rect2(Vector2(right, size.y - 145.), BUTTON_SIZE),
		&"sprint": Rect2(Vector2(right - 99., size.y - 106.), BUTTON_SIZE),
		&"zoom_in": Rect2(Vector2(right - 99., 40.), BUTTON_SIZE),
		&"zoom_out": Rect2(Vector2(right, 40.), BUTTON_SIZE),
		&"hour": Rect2(Vector2(right - 198., 40.), BUTTON_SIZE),
		&"weather": Rect2(Vector2(right - 297., 40.), BUTTON_SIZE),
		&"settings": Rect2(Vector2(right - 396., 40.), BUTTON_SIZE),
	}
	if _benchmark != null:
		buttons[&"measure"] = measure_button
	return buttons


func _process(delta: float) -> void:
	_refresh_after -= delta
	if _refresh_after <= 0.:
		_refresh_after = .25
		queue_redraw()


func _draw() -> void:
	if _world == null or _world.showcase.panel.visible:
		return
	var font := ThemeDB.fallback_font
	var ink := Color("#ecf6ef")
	var panel_color := Color(0.07, 0.12, 0.12, .83)
	var measuring := _benchmark != null and _benchmark.active
	if not measuring:
		var center := _stick_center()
		draw_circle(center, STICK_RADIUS, panel_color, true, -1., true)
		draw_arc(center, STICK_RADIUS, 0., TAU, 48, Color("#b3cabc"), 2., true)
		draw_circle(center + _stick_offset, 22., Color("#a4c9af"), true, -1., true)
	var names := {&"jump": "Nhảy", &"sprint": "Chạy", &"zoom_in": "+", &"zoom_out": "−", &"hour": "Đổi giờ", &"weather": "Mây", &"settings": "Cài đặt"}
	names[&"measure"] = "Dừng" if measuring else "Đo 10p"
	var buttons := _buttons()
	for key: StringName in buttons:
		var rect: Rect2 = buttons[key]
		draw_rect(rect, Color("#386449") if key in _held.values() else panel_color)
		var title: String = names[key]
		var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		draw_string(font, rect.get_center() + Vector2(-width * .5, 8.), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, ink)
	var hour: float = _world.showcase.hour
	var status := "%02d:%02d   %d FPS   %s" % [int(hour), roundi(fmod(hour, 1.) * 60.),
		Engine.get_frames_per_second(), RenderingServer.get_current_rendering_driver_name()]
	draw_rect(Rect2(Vector2(65., 40.), Vector2(255., 44.)), panel_color)
	draw_string(font, Vector2(79., 70.), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	if _benchmark != null and not _benchmark.status.is_empty():
		draw_rect(Rect2(Vector2(65., 95.), Vector2(255., 40.)), panel_color)
		draw_string(font, Vector2(79., 123.), _benchmark.status, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)


func _input(event: InputEvent) -> void:
	if _world == null or _world.showcase.panel.visible:
		return
	if event is InputEventScreenTouch:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed:
			if _press(event.index, point):
				get_viewport().set_input_as_handled()
		elif _release(event.index):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _stick_id:
		_move_stick(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if _press(MOUSE_POINTER, point) if event.pressed else _release(MOUSE_POINTER):
			get_viewport().set_input_as_handled()


func _press(index: int, point: Vector2) -> bool:
	var measuring := _benchmark != null and _benchmark.active
	if not measuring and index != MOUSE_POINTER and _stick_id < 0 and point.distance_to(_stick_center()) <= STICK_RADIUS * 1.35:
		_stick_id = index
		_move_stick(point)
		return true
	var buttons := _buttons()
	for key: StringName in buttons:
		if not buttons[key].has_point(point):
			continue
		_held[index] = key
		match key:
			&"jump", &"sprint":
				Input.action_press(key)
			&"zoom_in":
				_world.step_gameplay_zoom(-1.)
			&"zoom_out":
				_world.step_gameplay_zoom(1.)
			&"hour":
				var hour: float = _world.showcase.hour
				var next: float = HOURS[0]
				for candidate: float in HOURS:
					if candidate > hour + .01:
						next = candidate
						break
				_world.showcase.set_hour(next)
			&"weather":
				var weather: float = _world.biome_controller.weather_weight
				_world.biome_controller.set_weather(0. if weather >= .5 else 1.)
			&"settings":
				_world.showcase._settings.gear.pressed.emit()
			&"measure":
				_release_controls()
				if measuring:
					_benchmark.cancel()
				else:
					_benchmark.start()
		queue_redraw()
		return true
	return false


func _move_stick(point: Vector2) -> void:
	_stick_offset = (point - _stick_center()).limit_length(STICK_RADIUS)
	var direction := _stick_offset / STICK_RADIUS
	var strengths := [-direction.x, direction.x, -direction.y, direction.y]
	for i in MOVE.size():
		if strengths[i] > .02:
			Input.action_press(MOVE[i], strengths[i])
		else:
			Input.action_release(MOVE[i])
	queue_redraw()


func _release(index: int) -> bool:
	if index == _stick_id:
		_stick_id = -1
		_move_stick(_stick_center())
		return true
	if not _held.has(index):
		return false
	var key: StringName = _held[index]
	_held.erase(index)
	if key in [&"jump", &"sprint"] and key not in _held.values():
		Input.action_release(key)
	queue_redraw()
	return true


func _release_controls() -> void:
	if _stick_id >= 0:
		_release(_stick_id)
	for index: int in _held.keys():
		_release(index)
	queue_redraw()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_EXIT_TREE]:
		_release_controls()
		if what != NOTIFICATION_EXIT_TREE and _benchmark != null:
			_benchmark.cancel()
