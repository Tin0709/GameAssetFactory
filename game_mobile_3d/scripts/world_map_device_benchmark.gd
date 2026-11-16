extends Node
## Repeat the same interactive gameplay workload across two graphics quality levels.

const ORDER := [2, 1, 1, 2] # Full, Balanced, Balanced, Full.
const CONDITIONS := [Vector2(7., 0.), Vector2(12., 0.), Vector2(16.5, 0.),
	Vector2(16.5, 1.), Vector2(19.5, 0.), Vector2(22., 0.)]
const MOTION_ACTIONS := [&"move_forward", &"move_backward", &"sprint"]

var active := false
var last_path := ""
var status := ""
var _world: Node
var _sites: Array
var _original: Dictionary
var _rows: Array[Dictionary] = []
var _index := 0
var _step := -1
var _tick := 0
var _length := 0
var _warmup := 0
var _viewport_rid := RID()
var _measure_gpu := false
var _opened_usec := 0
var _segment_usec := 0
var _last_frame_usec := 0
var _frame_ms := PackedFloat32Array()
var _gpu_ms := PackedFloat32Array()
var _peak_visible_draws := 0
var _peak_texture_bytes := 0
var _peak_video_bytes := 0
var _previous_position := Vector3.ZERO
var _start_position := Vector3.ZERO
var _travel_m := 0.
var _jump_started := false


func setup(world: Node, sites: Array) -> void:
	_world = world
	_sites = sites
	process_physics_priority = -20
	set_physics_process(false)
	set_process(false)


func start(seconds := 12.5, warm_seconds := 2.) -> bool:
	if active or _sites.is_empty() or not _world.map_ready or _world.player.is_dead:
		return false
	if not is_finite(seconds) or not is_finite(warm_seconds) or seconds < .8 or warm_seconds < 0. or warm_seconds >= seconds:
		return false
	var biome: Node = _world.biome_controller
	_original = {
		"quality": biome.quality, "weather": biome.weather_weight, "hour": _world.showcase.hour,
		"cycle": biome._cycle, "position": _world.player.position, "zoom": _world._camera_size_target,
		"view": _world.view_mode,
	}
	biome._cycle = false
	_length = roundi(seconds * Engine.physics_ticks_per_second)
	_warmup = roundi(warm_seconds * Engine.physics_ticks_per_second)
	_rows.clear()
	_index = 0
	_opened_usec = Time.get_ticks_usec()
	_viewport_rid = get_viewport().get_viewport_rid()
	_measure_gpu = RenderingServer.get_rendering_device() != null
	if _measure_gpu:
		RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)
	active = true
	if not _begin_segment():
		cancel()
		return false
	set_process(true)
	set_physics_process(true)
	return true


func _segment_count() -> int:
	return ORDER.size() * CONDITIONS.size() * _sites.size()


func _segment() -> Dictionary:
	var block := CONDITIONS.size() * _sites.size()
	var condition: Vector2 = CONDITIONS[floori(float(_index % block) / _sites.size())]
	var site: Dictionary = _sites[_index % _sites.size()]
	return {"quality": ORDER[floori(float(_index) / block)], "site": site,
		"hour": condition.x, "weather": condition.y}


func _begin_segment() -> bool:
	var planned := _segment()
	var point: Vector2 = planned.site.position
	var ground: float = _world.surface_height(point.x, point.y)
	if not is_finite(ground):
		return false
	_release_motion()
	_world.biome_controller.set_quality(planned.quality)
	_world.biome_controller.set_weather(planned.weather, 0.)
	_world.showcase.set_hour(planned.hour)
	_start_position = Vector3(point.x, ground + .02, point.y)
	_place_player(_start_position, planned.site.zoom, "gameplay")
	_previous_position = _start_position
	_travel_m = 0.
	_step = -1
	_tick = 0
	_last_frame_usec = 0
	_frame_ms.clear()
	_gpu_ms.clear()
	_peak_visible_draws = 0
	_peak_texture_bytes = 0
	_peak_video_bytes = 0
	_jump_started = false
	_segment_usec = Time.get_ticks_usec()
	status = "%d/%d · %s" % [_index + 1, _segment_count(), planned.site.name]
	print("GAF_DEVICE_BENCH_BEGIN ", JSON.stringify({"segment": _index + 1,
		"quality": planned.quality, "site": planned.site.name, "hour": planned.hour, "weather": planned.weather}))
	return true


func _place_player(position: Vector3, zoom: float, view: String) -> void:
	var player: CharacterBody3D = _world.player
	player.cancel_jump()
	player.position = position
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	_world._camera_ground_y = position.y
	_world._camera_size_target = zoom
	_world.set_review_view(view)


func _physics_process(_delta: float) -> void:
	var position: Vector3 = _world.player.position
	_travel_m += Vector2(position.x - _previous_position.x, position.z - _previous_position.z).length()
	_previous_position = position
	if _tick >= _length:
		_save_segment()
		_index += 1
		if _index == _segment_count():
			_finish()
		elif not _begin_segment():
			cancel()
		return
	var fraction := float(_tick - _warmup) / (_length - _warmup)
	var step := -1 if fraction < 0. else mini(floori(fraction * 5.), 4)
	if step != _step:
		_step = step
		_release_motion()
		match step:
			0:
				Input.action_press(&"move_forward")
			1:
				Input.action_press(&"move_backward")
				Input.action_press(&"sprint")
			2:
				_jump_started = _world.player.request_jump()
			3:
				_world.step_gameplay_zoom(1.)
			4:
				_world.step_gameplay_zoom(-1.)
	_tick += 1


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _tick > _warmup and _last_frame_usec > 0:
		_frame_ms.append((now - _last_frame_usec) / 1000.)
		var viewport := get_viewport()
		_peak_visible_draws = maxi(_peak_visible_draws,
			viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		if _measure_gpu:
			var ms := RenderingServer.viewport_get_measured_render_time_gpu(_viewport_rid)
			if ms > 0. and is_finite(ms):
				_gpu_ms.append(ms)
			_peak_texture_bytes = maxi(_peak_texture_bytes,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED))
			_peak_video_bytes = maxi(_peak_video_bytes,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED))
	_last_frame_usec = now


func _summary(samples: PackedFloat32Array) -> Dictionary:
	if samples.is_empty():
		return {}
	var total := 0.
	for sample: float in samples:
		total += sample
	samples.sort()
	return {"mean": total / samples.size(), "p50": samples[floori((samples.size() - 1) * .5)],
		"p95": samples[ceili((samples.size() - 1) * .95)], "max": samples[-1]}


func _save_segment() -> void:
	var planned := _segment()
	var frame_time := _summary(_frame_ms)
	_rows.append({"segment": _index + 1, "site": planned.site.name, "quality": planned.quality,
		"hour": planned.hour, "weather": planned.weather, "camera_size": planned.site.zoom,
		"started_s": (_segment_usec - _opened_usec) / 1000000.,
		"ended_s": (Time.get_ticks_usec() - _opened_usec) / 1000000.,
		"start": [_start_position.x, _start_position.y, _start_position.z],
		"end": [_previous_position.x, _previous_position.y, _previous_position.z],
		"travel_m": _travel_m, "jump_started": _jump_started, "sample_count": _frame_ms.size(),
		"gpu_sample_count": _gpu_ms.size(), "frame_ms": frame_time, "gpu_ms": _summary(_gpu_ms),
		"mean_fps": 1000. / float(frame_time.mean) if not frame_time.is_empty() else 0.,
		"peak_visible_draws": _peak_visible_draws, "peak_texture_bytes": _peak_texture_bytes if _measure_gpu else null,
		"peak_render_video_bytes": _peak_video_bytes if _measure_gpu else null})


func _finish() -> void:
	var dir := "user://device_review_runs"
	var filename := "%s_%d.json" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_usec()]
	var path := dir.path_join(filename)
	var output: FileAccess
	if DirAccess.make_dir_recursive_absolute(dir) == OK:
		output = FileAccess.open(path, FileAccess.WRITE)
	if output != null:
		var size := get_viewport().get_visible_rect().size
		output.store_string(JSON.stringify({"schema": 1, "renderer": RenderingServer.get_current_rendering_method(),
			"driver": RenderingServer.get_current_rendering_driver_name(), "platform": OS.get_name(),
			"device": OS.get_model_name(), "os_version": OS.get_version(), "engine": Engine.get_version_info().string,
			"rendering_scale": get_viewport().scaling_3d_scale, "debug_template": OS.is_debug_build(),
			"source_commit": ProjectSettings.get_setting("gaf_device_review/source_commit", "editor"),
			"source_dirty": ProjectSettings.get_setting("gaf_device_review/source_dirty", null),
			"viewport": [size.x, size.y], "physics_hz": Engine.physics_ticks_per_second, "order": ORDER,
			"segment_ticks": _length, "warmup_ticks": _warmup, "elapsed_s": (Time.get_ticks_usec() - _opened_usec) / 1000000.,
			"rows": _rows}, "\t"))
		output.close()
		last_path = path
		print("GAF_DEVICE_BENCH_RESULT ", ProjectSettings.globalize_path(path))
	_restore()
	status = "Đã lưu kết quả đo" if output != null else "Không lưu được kết quả"


func cancel() -> void:
	if active:
		_restore()
		status = "Đã dừng phép đo"


func _restore() -> void:
	set_process(false)
	set_physics_process(false)
	if _measure_gpu:
		RenderingServer.viewport_set_measure_render_time(_viewport_rid, false)
	active = false
	_release_motion()
	_world.biome_controller.set_quality(_original.quality)
	_world.biome_controller.set_weather(_original.weather, 0.)
	_world.biome_controller._cycle = _original.cycle
	_world.showcase.set_hour(_original.hour)
	_place_player(_original.position, _original.zoom, _original.view)


func _release_motion() -> void:
	for action: StringName in MOTION_ACTIONS:
		Input.action_release(action)


func _exit_tree() -> void:
	if active:
		_release_motion()
