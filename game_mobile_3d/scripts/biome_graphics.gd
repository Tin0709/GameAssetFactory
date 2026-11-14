extends Node
## Applies biome resources to the map's own environment and light.

const Profile = preload("res://scripts/biome_graphics_profile.gd")
const RenderSettings = preload("res://scripts/biome_render_settings.gd")
const Weather = preload("res://scripts/biome_weather.gd")
const DayNight = preload("res://scripts/biome_day_night.gd")
const DiffuseRegion = preload("res://scripts/local_diffuse_region.gd")
const Palette = preload("res://scripts/world_map_showcase_palette.gd")
const MistVolume = preload("res://scripts/world_map_atmosphere_volume.gd")
const LocalExposure = preload("res://scripts/world_map_local_exposure.gd")
const PathFixture = preload("res://scripts/world_map_forest_path_light.gd")
const HOURS := [7., 12., 16.5, 18.5, 22.]
enum Quality { ESSENTIAL, BALANCED, FULL }
const QUALITY_LABELS := ["Nhẹ", "Cân bằng", "Đầy đủ"]

var quality := Quality.FULL
var _weather := Weather.new()
var weather_weight: float:
	get: return _weather.weight
var _world: Node3D
var _profile: Profile
var _palette := Palette.new()
var _noon := _palette.sample(12.)
var _cycle := false
var _fog_enabled := true
var _profile_index := 0
var _choices: Array[Profile] = []
var _label: Label
var _mist: MistVolume
var _allow_spatial_mist := true
var _path_fixture := PathFixture.new()
var _allow_fixture_scatter := true
var _mist_sample: Dictionary
var _allow_adaptive_bloom := true
var _finish_effect: LocalExposure
var _finish_camera: Camera3D
var _finish_compositor: Compositor
var _previous_compositor: Compositor
var _local_diffuse_source := Vector4.ZERO
var _local_diffuse_bounds := Vector4.ZERO
var _local_diffuse_ambient := Vector3.ZERO
var _allow_local_diffuse := true

func setup(world: Node3D, profile: Profile, alternatives: Array[Profile]) -> void:
	_world = world
	DiffuseRegion.claim(self)
	quality = world.biome_quality
	_choices.append(profile)
	for choice in alternatives:
		if choice != null and not choice.use_forest_reference and not _choices.has(choice):
			_choices.append(choice)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2(18., 14.)
	_label.add_theme_color_override("font_outline_color", Color(0., 0., 0., .9))
	_label.add_theme_constant_override("outline_size", 4)
	world.get_node("HUD").add_child(_label)
	_label.hide()
	set_profile(profile)
	set_weather(profile.start_overcast, 0.)
	_world.showcase.set_hour(profile.start_hour)
	_cycle = profile.auto_cycle

func set_profile(profile: Profile) -> void:
	if profile == null or profile.use_forest_reference:
		return
	_profile = profile
	var slot := _choices.find(profile)
	if slot >= 0:
		_profile_index = slot
	if _profile.overcast == null:
		_weather.set_target(0., 0.)
	refresh()

func set_quality(value: Quality) -> void:
	if value == quality or value < Quality.ESSENTIAL or value > Quality.FULL:
		return
	quality = value
	refresh()
	if quality < Quality.FULL and _finish_effect != null:
		_release_inactive(_finish_effect)
	if quality == Quality.ESSENTIAL and is_instance_valid(_mist):
		_mist.suspend()
		_release_inactive(_mist.effect)

# A rapid switch can re-enable the effect before the render thread drains the queue.
func _release_inactive(effect: CompositorEffect) -> void:
	RenderingServer.call_on_render_thread(func() -> void:
		if not effect.enabled:
			effect.release_on_render_thread()
	)

func set_weather(overcast: float, seconds: float = 2.5) -> void:
	if _profile.overcast == null:
		return
	var previous := _weather.weight
	_weather.set_target(overcast, seconds)
	if _weather.weight != previous:
		refresh()

func _process(delta: float) -> void:
	_update_local_diffuse()
	_update_finish()
	_update_spatial_mist()
	if _cycle and _world.look.stage == 2:
		_world.showcase.set_hour(DayNight.advance(_world.showcase.hour, delta, _profile.cycle_minutes * 60.))
	if _weather.advance(delta):
		refresh()

func refresh() -> void:
	var hour: float = _world.showcase.hour
	if _label != null:
		_label.text = "%s · %s · %02d:%02d · Mây %d%%   T giờ · Shift+T tự chuyển · F6 mây · F8 preset · J so sương · Shift+J tán xạ đèn · Alt+J ánh hắt · F7 hậu kỳ · Shift+F7 chất lượng · B đối chiếu" % [
			_profile.display_name, QUALITY_LABELS[quality], int(hour), int(fmod(hour, 1.) * 60.), roundi(weather_weight * 100.)]
	if _world.look.stage != 2:
		_update_local_diffuse()
		_update_fixture(0.)
		_update_spatial_mist()
		_update_finish()
		return
	var env: Environment = _world.get_node("WorldEnvironment").environment
	var sun: DirectionalLight3D = _world.get_node("Sun")
	var p := _palette.sample(hour)
	RenderSettings.apply_lighting(sun, env, p, _noon, _profile.noon_sun_rotation, _profile.noon_sun_color,
		_profile.noon_sun_energy, _profile.noon_ambient_color, _profile.noon_ambient_energy)
	sun.shadow_blur = _profile.shadow_blur
	sun.shadow_opacity = _profile.shadow_opacity
	var sky := _profile.noon_sky_color * Color(p.sky) / Color(_noon.sky)
	var fog_color := _profile.noon_fog_color * Color(p.fog) / Color(_noon.fog)
	var time := hour / 24.
	var exposure := _profile.exposure * float(p.exposure) / float(_noon.exposure)
	var day_night := _profile.day_night
	if day_night != null:
		sun.light_color = day_night.sample_color(day_night.sun_color, time, sun.light_color)
		env.ambient_light_color = day_night.sample_color(day_night.ambient_color, time, env.ambient_light_color)
		sky = day_night.sample_color(day_night.sky_color, time, sky)
		fog_color = day_night.sample_color(day_night.fog_color, time, fog_color)
		var rotation := sun.rotation_degrees
		rotation.x = day_night.sample_curve(day_night.sun_pitch_degrees, time, rotation.x)
		rotation.y = day_night.sample_curve(day_night.sun_yaw_degrees, time, rotation.y)
		if day_night.sun_pitch_degrees != null or day_night.sun_yaw_degrees != null:
			sun.rotation_degrees = rotation
		exposure = day_night.sample_curve(day_night.exposure, time, exposure)
	if _profile.key_energy_by_hour != null:
		sun.light_energy *= maxf(0., _profile.key_energy_by_hour.sample(time))
	var ambient_scale := DayNight.sample_curve(_profile.ambient_energy_by_hour, time, 1.)
	env.ambient_light_energy *= maxf(0., ambient_scale)
	var fog_density := _profile.noon_fog_density * float(p.fog_amount) / float(_noon.fog_amount)
	if _profile.fog_density_by_hour != null:
		fog_density *= maxf(0., _profile.fog_density_by_hour.sample(time))
	var saturation := _profile.saturation * float(p.saturation) / float(_noon.saturation)
	env.background_color = sky
	env.fog_enabled = _fog_enabled
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_curve = _profile.fog_depth_curve
	env.fog_light_energy = _profile.fog_light_energy
	RenderSettings.apply_depth_fog(env, fog_color, fog_density, _profile.fog_depth_m.x,
		maxf(_profile.fog_depth_m.y, _profile.fog_depth_m.x + .1))
	env.tonemap_mode = _profile.tonemap
	env.tonemap_exposure = clampf(exposure, .1, 4.)
	env.adjustment_enabled = true
	env.adjustment_color_correction = _profile.color_correction
	RenderSettings.apply_grade(env, _profile.contrast, saturation)
	RenderSettings.apply_bloom(env, _profile.glow_intensity > 0.,
		_profile.glow_intensity, _profile.glow_bloom, _profile.glow_hdr_threshold)
	_weather.apply_lighting(_profile.overcast, sun, env)
	# Scale the authored depth fog only after applying the weather response.
	var fog_gain := _profile.essential_fog_scale if quality == Quality.ESSENTIAL and _profile.spatial_mist else 1.
	env.fog_density *= fog_gain
	_weather.apply_air(_profile.overcast, env, fog_gain)
	env.fog_density = clampf(env.fog_density, 0., 1.)
	_update_fixture(time)
	_prepare_spatial_mist(env, time)
	_update_local_diffuse()
	_update_finish()

func _update_local_diffuse() -> void:
	if not DiffuseRegion.owns(self):
		return
	var source := Vector4.ZERO
	var bounds := Vector4.ZERO
	var ambient := Vector3.ZERO
	var region = _world.local_diffuse_region
	if _allow_local_diffuse and quality != Quality.ESSENTIAL and _world.look.stage == 2 \
			and _world.view_mode == "gameplay" and region != null and region.is_valid() \
			and _profile.local_diffuse_strength > 0. and RenderingServer.get_current_rendering_method() == "mobile":
		var time: float = _world.showcase.hour / 24.
		var gain := _profile.local_diffuse_strength * clampf(DayNight.sample_curve(_profile.local_diffuse_by_hour, time, 1.), 0., 1.)
		if _profile.overcast != null:
			gain *= lerpf(1., _profile.overcast.local_diffuse_scale, weather_weight)
		if gain > 0.:
			source = region.source(gain)
			bounds = region.bounds()
			var env: Environment = _world.get_node("WorldEnvironment").environment
			var linear := env.ambient_light_color.srgb_to_linear()
			ambient = Vector3(linear.r, linear.g, linear.b) * env.ambient_light_energy
	if bounds != _local_diffuse_bounds:
		_local_diffuse_bounds = bounds
		RenderingServer.global_shader_parameter_set("gaf_local_diffuse_region", bounds)
	if ambient != _local_diffuse_ambient:
		_local_diffuse_ambient = ambient
		RenderingServer.global_shader_parameter_set("gaf_local_diffuse_ambient", ambient)
	if source != _local_diffuse_source:
		_local_diffuse_source = source
		RenderingServer.global_shader_parameter_set("gaf_local_diffuse_source", source)

func _update_finish() -> void:
	var camera := _world.get_node("Camera3D") as Camera3D
	var env: Environment = _world.get_node("WorldEnvironment").environment
	var combined: bool = _world.look.stage == 2
	var weight := 1.
	if _profile.adaptive_bloom_by_hour != null:
		weight = clampf(_profile.adaptive_bloom_by_hour.sample(_world.showcase.hour / 24.), 0., 1.)
	var wanted: bool = combined and quality == Quality.FULL and _allow_adaptive_bloom and _profile.adaptive_bloom and weight > 0. \
		and _world.view_mode == "gameplay" and camera.is_current() \
		and (_profile.local_exposure > 0. or _profile.adaptive_bloom_gain > 0.) \
		and RenderingServer.get_current_rendering_method() == "mobile" \
		and RenderingServer.get_rendering_device() != null
	if wanted and _finish_effect == null:
		_ensure_compositor(camera)
		_finish_effect = LocalExposure.new()
		var chain := _finish_compositor.compositor_effects.duplicate()
		chain.append(_finish_effect)
		_finish_compositor.compositor_effects = chain
	if _finish_effect != null:
		wanted = wanted and camera.compositor == _finish_compositor and _finish_effect.failure().is_empty()
		_finish_effect.enabled = wanted
		if wanted:
			var strength := _profile.local_exposure * weight
			if not is_equal_approx(_finish_effect._review_strength, strength):
				_finish_effect.set_review_strength(strength)
			_finish_effect.set_air_bloom(_profile.adaptive_bloom_gain > 0.)
			_finish_effect.set_air_bloom_response(_profile.adaptive_bloom_gain * weight)
			_finish_effect.set_bloom_local_response(_profile.adaptive_bloom_response)
			_finish_effect.set_bloom_prefilter(_profile.adaptive_bloom_prefilter)
			_finish_effect.set_air_bloom_spread(_profile.adaptive_bloom_spread)
	if combined:
		# Keep native glow until the custom pass has completed one successful frame.
		var custom_bloom := false
		if wanted and _profile.adaptive_bloom_gain > 0.:
			var state := _finish_effect.snapshot()
			custom_bloom = state.frames > 0 and state.bytes > 0
		var native_weight := 1. - weight if custom_bloom else 1.
		env.glow_enabled = _profile.glow_intensity > 0. and native_weight > 0.
		env.glow_intensity = _profile.glow_intensity * native_weight
		env.glow_bloom = _profile.glow_bloom * native_weight

func _ensure_compositor(camera: Camera3D) -> void:
	if _finish_compositor != null:
		return
	_finish_camera = camera
	_previous_compositor = camera.compositor
	var source := _previous_compositor
	if source == null:
		var world_environment: WorldEnvironment = _world.get_node("WorldEnvironment")
		source = world_environment.compositor
	_finish_compositor = Compositor.new()
	if source != null:
		_finish_compositor.compositor_effects = source.compositor_effects.duplicate()
	camera.compositor = _finish_compositor

func _exit_tree() -> void:
	DiffuseRegion.release(self)
	if is_instance_valid(_mist):
		_mist.suspend()
		_mist.queue_free()
	if is_instance_valid(_finish_camera) and _finish_camera.compositor == _finish_compositor:
		_finish_camera.compositor = _previous_compositor
	if _finish_effect != null:
		_finish_effect.enabled = false
		RenderingServer.call_on_render_thread(_finish_effect.release_on_render_thread)

func _update_fixture(time: float) -> void:
	var anchor: Vector2 = _world.biome_path_fixture_xz
	if not anchor.is_finite():
		return
	var curve := _profile.path_fixture_by_hour
	var phase := clampf(curve.sample(time), 0., 1.) if curve != null and _world.look.stage == 2 else 0.
	_path_fixture.update(_world, phase, _profile.path_fixture_energy, Vector2.ZERO, anchor)

func _fixture_air() -> PackedFloat32Array:
	if not _allow_fixture_scatter or not is_instance_valid(_mist) or not _mist.visible:
		return PackedFloat32Array()
	return _path_fixture.air_parameters(_profile.path_fixture_scatter)

func _prepare_spatial_mist(env: Environment, time: float) -> void:
	var active := quality != Quality.ESSENTIAL and _profile.spatial_mist and RenderingServer.get_current_rendering_method() == "mobile" \
		and RenderingServer.get_rendering_device() != null
	if not active:
		_mist_sample.clear()
		_update_spatial_mist()
		return
	if _mist == null:
		var camera := _world.get_node("Camera3D") as Camera3D
		_ensure_compositor(camera)
		_mist = MistVolume.new()
		camera.add_child(_mist)
		_mist.setup()
		_mist.material_provider = _mist_materials
		_mist.compositor_owned = _owns_finish_compositor
		_mist.path_light_provider = _fixture_air
		_mist.noise_strength = .28
	_mist.screen_tile_pixels = 32 if quality == Quality.BALANCED else 16
	var tint := Vector3(env.fog_light_color.r, env.fog_light_color.g, env.fog_light_color.b)
	var phase_density := env.fog_density / maxf(_profile.noon_fog_density, .05)
	var density := _profile.mist_extinction * phase_density
	_mist_sample = {
		"fog_begin": env.fog_depth_end,
		"fog_color": tint,
		"volume_density": density,
		"height_falloff": _profile.mist_height_falloff,
		"near_layer": Vector3(env.fog_depth_begin, density, _world.spawn_position.y),
		"near_fade_start": .8,
		"scatter_energy": _profile.mist_scatter,
		"player_light_color": Vector3.ZERO,
		"player_light_weight": 0.,
	}
	_weather.apply_medium(_profile.overcast, _mist_sample)
	var local_strength := _profile.local_mist_strength * lerpf(.55, 1., weather_weight)
	var local_weight := clampf(DayNight.sample_curve(_profile.local_mist_by_hour, time, 1.), 0., 1.)
	var additional_weight := clampf(DayNight.sample_curve(_profile.additional_mist_by_hour, time, 1.), 0., 1.)
	_mist.set_local_region(_world.local_mist_region, local_strength * local_weight)
	_mist.set_additional_local_region(_world.additional_mist_region, local_strength * additional_weight)
	_update_spatial_mist()

func _mist_materials() -> Array:
	var receivers: Array = _world.showcase._mist_materials()
	if _path_fixture.material != null:
		receivers.append(_path_fixture.material)
	return receivers

func _owns_finish_compositor(compositor: Compositor) -> bool:
	return compositor == _finish_compositor

func _update_spatial_mist() -> void:
	if not is_instance_valid(_mist):
		return
	var camera: Camera3D = _mist.get_parent()
	_mist.visible = _allow_spatial_mist and _fog_enabled and not _mist_sample.is_empty() \
		and _world.look.stage == 2 and _world.view_mode == "gameplay" \
		and camera.projection == Camera3D.PROJECTION_ORTHOGONAL and camera.is_current() \
		and _mist.failure().is_empty()
	if _mist.visible:
		var position: Vector3 = _world.presentation.player_position()
		var subject_depth := -camera.global_basis.z.dot(position - camera.global_position)
		_mist_sample.ground_haze = _profile.sample_ground_haze(_world.showcase.hour, subject_depth, _world.spawn_position.y)
		_mist.publish(_mist_sample, position, _world.spawn_position.y, _world.look.elapsed, true, 0.)

func handle_key(event: InputEventKey) -> bool:
	match event.physical_keycode:
		KEY_T:
			if event.shift_pressed:
				_cycle = not _cycle
			else:
				_world.showcase.set_hour(DayNight.next_hour(_world.showcase.hour, HOURS))
		KEY_F6:
			set_weather(0. if _weather.target > 0. else 1.)
		KEY_H:
			_fog_enabled = not _fog_enabled
			refresh()
		KEY_F7:
			if event.shift_pressed:
				set_quality(Quality.BALANCED if quality == Quality.FULL else
					Quality.ESSENTIAL if quality == Quality.BALANCED else Quality.FULL)
			else:
				_allow_adaptive_bloom = not _allow_adaptive_bloom
				_update_finish()
		KEY_J:
			if event.alt_pressed:
				_allow_local_diffuse = not _allow_local_diffuse
				_update_local_diffuse()
			elif event.shift_pressed:
				_allow_fixture_scatter = not _allow_fixture_scatter
			else:
				_allow_spatial_mist = not _allow_spatial_mist
				_update_spatial_mist()
		KEY_F8:
			_profile_index = (_profile_index + 1) % _choices.size()
			set_profile(_choices[_profile_index])
		KEY_L:
			_label.visible = not _label.visible
		_:
			return false
	return true
