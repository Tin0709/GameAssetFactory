extends Node
## Applies biome resources to the map's own environment and light.

const Profile = preload("res://scripts/biome_graphics_profile.gd")
const RenderSettings = preload("res://scripts/biome_render_settings.gd")
const Weather = preload("res://scripts/biome_weather.gd")
const DayNight = preload("res://scripts/biome_day_night.gd")
const DiffuseRegion = preload("res://scripts/local_diffuse_region.gd")
const ActorGroundLight = preload("res://scripts/world_map_actor_ground_light.gd")
const Palette = preload("res://scripts/world_map_showcase_palette.gd")
const MistVolume = preload("res://scripts/world_map_atmosphere_volume.gd")
const LocalExposure = preload("res://scripts/world_map_local_exposure.gd")
const PathFixture = preload("res://scripts/world_map_forest_path_light.gd")
const PathLamppost = preload("res://scripts/world_map_path_lamppost.gd")
const HOURS := [7., 12., 16.5, 18.5, 22.]
const LINEAR_LUMA := Vector3(.2126, .7152, .0722)
enum Quality { ESSENTIAL, BALANCED, FULL }
const QUALITY_LABELS := ["Nhẹ", "Cân bằng", "Đầy đủ"]

var quality := Quality.FULL
var _weather := Weather.new()
var weather_weight: float:
	get: return _weather.weight if _profile != null and _profile.overcast != null else 0.
var _world: Node3D
var _profile: Profile
var _palette := Palette.new()
var _noon := _palette.sample(12.)
var _cycle := false
var _fog_enabled := true
var _profile_index := 0
var _choices: Array[Profile] = []
var _settings_status: Label
var _settings_preset: OptionButton
var _settings_quality: OptionButton
var _actor_ground_light: ActorGroundLight
var _actor_ground_scale := 1.
var _actor_ground_slider: HSlider
var _actor_ground_drag_before := 1.
var _mist: MistVolume
var _allow_spatial_mist := true
var _path_fixture := PathFixture.new()
var _path_lamppost := PathLamppost.new()
var _allow_fixture_scatter := true
var _mist_sample: Dictionary
var _allow_adaptive_bloom := true
var _finish_effect: LocalExposure
var _finish_camera: Camera3D
var _finish_compositor: Compositor
var _previous_compositor: Compositor
var _local_diffuse_source := Vector4.ZERO
var _additional_diffuse_source := Vector4.ZERO
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
	set_profile(profile)
	var start_overcast: float = world.biome_start_overcast
	var start_hour: float = world.biome_start_hour
	var initial_hour := start_hour if 0. <= start_hour and start_hour <= 24. else profile.start_hour
	set_weather(start_overcast if 0. <= start_overcast and start_overcast <= 1. else profile.start_overcast, 0.)
	_world.showcase.set_hour(initial_hour)
	_cycle = profile.auto_cycle

func add_settings_controls(parent: VBoxContainer) -> Label:
	_settings_preset = OptionButton.new()
	_settings_preset.name = "BiomePreset"
	for profile: Profile in _choices:
		_settings_preset.add_item(profile.display_name)
	_settings_preset.disabled = _choices.size() < 2
	_settings_preset.item_selected.connect(func(index: int) -> void: set_profile(_choices[index]))
	parent.add_child(_settings_preset)

	_settings_quality = OptionButton.new()
	_settings_quality.name = "BiomeQuality"
	for label: String in QUALITY_LABELS:
		_settings_quality.add_item(label)
	_settings_quality.item_selected.connect(func(index: int) -> void: set_quality(index as Quality))
	parent.add_child(_settings_quality)

	if _has_actor_ground_settings():
		_actor_ground_slider = HSlider.new()
		_actor_ground_slider.name = "ActorGroundLightScale"
		_actor_ground_slider.max_value = 1.
		_actor_ground_slider.step = .05
		_actor_ground_slider.value = _actor_ground_scale
		_actor_ground_slider.tooltip_text = "Kéo về 0 để so sánh với ánh sáng gốc. Áp dụng lúc thiếu sáng."
		_actor_ground_slider.value_changed.connect(set_actor_ground_scale)
		_actor_ground_slider.drag_started.connect(func(): _actor_ground_drag_before = _actor_ground_scale)
		_actor_ground_slider.drag_ended.connect(func(changed: bool):
			if changed and not is_equal_approx(_actor_ground_drag_before, _actor_ground_scale):
				_world.showcase._settings.remember_edit(set_actor_ground_scale.bind(_actor_ground_drag_before)))
		parent.add_child(_actor_ground_slider)

	_settings_status = Label.new()
	parent.add_child(_settings_status)
	_refresh_settings()
	return _settings_status

func _refresh_settings() -> void:
	if _settings_status == null:
		return
	var hour: float = _world.showcase.hour
	var weather_status := "Mây %d%%" % roundi(weather_weight * 100.) if _profile.overcast != null else "Preset không có cấu hình mây"
	_settings_status.text = "%02d:%02d · %s" % [int(hour), int(fmod(hour, 1.) * 60.), weather_status]
	var index := _choices.find(_profile)
	if _settings_preset.selected != index:
		_settings_preset.select(index)
	if _settings_quality.selected != quality:
		_settings_quality.select(quality)
	if _actor_ground_slider != null:
		_actor_ground_slider.editable = quality != Quality.ESSENTIAL and _profile.actor_ground_light_by_hour != null \
			and _actor_ground_light != null and _actor_ground_light.supported

func set_profile(profile: Profile) -> void:
	if profile == null or profile.use_forest_reference:
		return
	_profile = profile
	var slot := _choices.find(profile)
	if slot >= 0:
		_profile_index = slot
	refresh()
	_release_effects_outside_budget()

func set_quality(value: Quality) -> void:
	if value == quality or value < Quality.ESSENTIAL or value > Quality.FULL:
		return
	quality = value
	refresh()
	_release_effects_outside_budget()

func _release_effects_outside_budget() -> void:
	var finish_allowed := quality == Quality.FULL and _profile.adaptive_bloom \
		and (_profile.local_exposure > 0. or _profile.adaptive_bloom_gain > 0.)
	if not finish_allowed and _finish_effect != null:
		_release_inactive(_finish_effect)
	if (quality == Quality.ESSENTIAL or not _profile.spatial_mist) and is_instance_valid(_mist):
		_mist.suspend()
		_release_inactive(_mist.effect)

# A rapid switch can re-enable the effect before the render thread drains the queue.
func _release_inactive(effect: CompositorEffect) -> void:
	RenderingServer.call_on_render_thread(func() -> void:
		if not effect.enabled:
			effect.release_on_render_thread()
	)

func set_weather(overcast: float, seconds: float = 2.5) -> void:
	var previous := weather_weight
	_weather.set_target(overcast, seconds)
	if weather_weight != previous:
		refresh()

func _process(delta: float) -> void:
	if _path_lamppost.support != null and _path_lamppost.fixture.visible and _path_lamppost.support.collision_layer == 0:
		_update_fixture(_world.showcase.hour / 24.)
	_update_local_diffuse()
	_update_finish()
	_update_spatial_mist()
	if _cycle and _world.look.stage == 2:
		_world.showcase.set_hour(DayNight.advance(_world.showcase.hour, delta, _profile.cycle_minutes * 60.))
	if _weather.advance(delta) and _profile.overcast != null:
		refresh()

func _has_actor_ground_settings() -> bool:
	if not ActorGroundLight.available() or _world.player.get("using_original_source") == true:
		return false
	for profile in _choices:
		if profile.actor_ground_light_by_hour != null:
			return true
	return false


func set_actor_ground_scale(value: float) -> void:
	_actor_ground_scale = clampf(value, 0., 1.)
	if _actor_ground_slider != null:
		_actor_ground_slider.set_value_no_signal(_actor_ground_scale)
	_update_actor_ground_light(_world.showcase.hour)


func _update_actor_ground_light(hour: float) -> void:
	var curve := _profile.actor_ground_light_by_hour
	if _actor_ground_light == null and curve != null and ActorGroundLight.available() \
			and _world.player.get("using_original_source") != true:
		_actor_ground_light = ActorGroundLight.new()
		add_child(_actor_ground_light)
		_actor_ground_light.setup(_world)
	if _actor_ground_light == null:
		return
	var power := 0.
	if quality != Quality.ESSENTIAL and _world.look.stage == 2 and _world.view_mode == "gameplay":
		power = DayNight.sample_curve(curve, hour / 24., 0.)
		power *= lerpf(1., _profile.actor_ground_light_cloudy_scale, weather_weight) * _actor_ground_scale
	_actor_ground_light.set_power(power)


func refresh() -> void:
	var hour: float = _world.showcase.hour
	_update_actor_ground_light(hour)
	_refresh_settings()
	if _world.look.stage != 2:
		_world.showcase.sync_cliff_vista(false)
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
	sun.shadow_opacity = _weather.shadow_opacity(_profile.overcast, _profile.shadow_opacity, hour)
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
	var key_scale := DayNight.sample_curve(_profile.key_energy_by_hour, time, 1.)
	sun.light_energy *= maxf(0., key_scale)
	env.ambient_light_energy *= _profile.ambient_hour_scale(hour)
	var fog_density := _profile.noon_fog_density * float(p.fog_amount) / float(_noon.fog_amount)
	var fog_scale := DayNight.sample_curve(_profile.fog_density_by_hour, time, 1.)
	fog_density *= maxf(0., fog_scale)
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
	_weather.apply_lighting(_profile.overcast, sun, env, hour)
	# Scale the authored depth fog only after applying the weather response.
	var fog_gain := _profile.essential_fog_scale if quality == Quality.ESSENTIAL and _profile.spatial_mist else 1.
	env.fog_density *= fog_gain
	_weather.apply_air(_profile.overcast, env, fog_gain)
	env.fog_density = clampf(env.fog_density, 0., 1.)
	_world.showcase.sync_cliff_vista(quality != Quality.ESSENTIAL)
	_update_fixture(time)
	_prepare_spatial_mist(env, fog_color, time)
	_update_local_diffuse()
	_update_finish()

func _update_local_diffuse() -> void:
	if not DiffuseRegion.owns(self):
		return
	var source := Vector4.ZERO
	var bounds := Vector4.ZERO
	var ambient := Vector3.ZERO
	var region = _world.local_diffuse_region
	var gain := 0.0
	if _allow_local_diffuse and quality != Quality.ESSENTIAL and _world.look.stage == 2 \
			and _world.view_mode == "gameplay" \
			and _profile.local_diffuse_strength > 0. and RenderingServer.get_current_rendering_method() == "mobile":
		var time: float = _world.showcase.hour / 24.
		gain = _profile.local_diffuse_strength * clampf(DayNight.sample_curve(_profile.local_diffuse_by_hour, time, 1.), 0., 1.)
		if _profile.overcast != null:
			gain *= lerpf(1., _profile.overcast.local_diffuse_scale, weather_weight)
	if gain > 0. and region != null and region.is_valid():
		source = region.source(gain)
		bounds = region.bounds()
	_additional_diffuse_source = DiffuseRegion.publish_additional(_world.additional_local_diffuse_region, gain, _additional_diffuse_source)
	if source.w > 0. or _additional_diffuse_source.w > 0.:
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
	var curve := _profile.path_fixture_by_hour
	var phase := clampf(curve.sample(time), 0., 1.) if curve != null and _world.look.stage == 2 else 0.
	var lamp_wanted: bool = _world.biome_path_lamp_xz.is_finite() and curve != null and _world.look.stage == 2
	var lamp_active := _path_lamppost.update(_world, lamp_wanted, phase, _profile.path_fixture_energy)
	var anchor: Vector2 = _world.biome_path_fixture_xz
	if not anchor.is_finite():
		return
	_path_fixture.update(_world, 0. if lamp_active else phase, _profile.path_fixture_energy, Vector2.ZERO, anchor)

func _fixture_air() -> PackedFloat32Array:
	if not _allow_fixture_scatter or not is_instance_valid(_mist) or not _mist.visible:
		return PackedFloat32Array()
	if is_instance_valid(_path_lamppost.fixture) and _path_lamppost.fixture.visible:
		return _path_lamppost.air_parameters(_profile.path_fixture_scatter)
	return _path_fixture.air_parameters(_profile.path_fixture_scatter)

func _prepare_spatial_mist(env: Environment, clear_fog_color: Color, time: float) -> void:
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
		_mist.set_sky_field(_world.mist_sky_field)
		_mist.material_provider = _mist_materials
		_mist.compositor_owned = _owns_finish_compositor
		_mist.path_light_provider = _fixture_air
		_mist.noise_strength = .28
	_mist.screen_tile_pixels = 32 if quality == Quality.BALANCED else 16
	var tint := Vector3(env.fog_light_color.r, env.fog_light_color.g, env.fog_light_color.b)
	var phase_density := env.fog_density / maxf(_profile.noon_fog_density, .05)
	var density := _profile.mist_extinction * phase_density
	var scatter_scale := DayNight.sample_curve(_profile.mist_scatter_energy_by_hour, time, 1.)
	var base_y: float = _world.biome_atmosphere_base_y
	if not is_finite(base_y):
		base_y = _world.spawn_position.y
	_mist_sample = {
		"fog_begin": env.fog_depth_end,
		"fog_color": tint,
		"volume_density": density,
		"height_falloff": _profile.mist_height_falloff,
		"near_layer": Vector3(env.fog_depth_begin, density, base_y),
		"near_fade_start": .8,
		"scatter_energy": clampf(_profile.mist_scatter * scatter_scale, 0., 1.),
		"entry_scatter_gain": _profile.sample_mist_entry_scatter(time),
		"sky_scatter_source": _profile.sample_mist_sky_scatter(time, env) if _mist.has_sky_field() else Vector4.ZERO,
		"player_light_color": Vector3.ZERO,
		"player_light_weight": 0.,
	}
	var tint_track := _profile.mist_scatter_color_by_hour
	if tint_track != null and tint_track.get_point_count() > 0:
		var phase_tint := tint_track.sample(time).srgb_to_linear()
		var source := Vector3(phase_tint.r, phase_tint.g, phase_tint.b)
		var source_luma := source.dot(LINEAR_LUMA)
		if source_luma > .00001:
			var clear := clear_fog_color.srgb_to_linear()
			var clear_luma := Vector3(clear.r, clear.g, clear.b).dot(LINEAR_LUMA)
			_mist_sample.linear_scatter_rgb = source * (clear_luma / source_luma)
	_weather.apply_medium(_profile.overcast, _mist_sample, time)
	var local_strength := _profile.local_mist_strength * lerpf(.55, 1., weather_weight)
	var local_weight := clampf(DayNight.sample_curve(_profile.local_mist_by_hour, time, 1.), 0., 1.)
	var alternate_weight := clampf(DayNight.sample_curve(_profile.alternate_mist_by_hour, time, 0.), 0., 1.)
	var additional_weight := clampf(DayNight.sample_curve(_profile.additional_mist_by_hour, time, 1.), 0., 1.)
	_mist.set_local_region_for_phase(_world.local_mist_region, local_strength * local_weight,
		_world.alternate_mist_region, local_strength * alternate_weight)
	_mist.set_additional_local_region(_world.additional_mist_region, local_strength * additional_weight)
	_update_spatial_mist()

func _mist_materials() -> Array:
	var receivers: Array = _world.showcase._mist_materials()
	if _path_fixture.material != null:
		receivers.append(_path_fixture.material)
	if _path_lamppost.material != null:
		receivers.append(_path_lamppost.material)
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
		var near_layer: Vector3 = _mist_sample.near_layer
		_mist_sample.ground_haze = _profile.sample_ground_haze(_world.showcase.hour, subject_depth, near_layer.z)
		_mist.publish(_mist_sample, position, near_layer.z, _world.look.elapsed, true, 0.)

func handle_key(event: InputEventKey) -> bool:
	match event.physical_keycode:
		KEY_T:
			if event.shift_pressed:
				_cycle = not _cycle
			else:
				_world.showcase.set_hour(DayNight.next_hour(_world.showcase.hour, HOURS))
		KEY_F6:
			if _profile.overcast != null:
				_world.showcase.set_weather(0. if _weather.target > 0. else 1.)
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
		_:
			return false
	return true
