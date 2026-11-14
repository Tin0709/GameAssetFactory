extends Node
## Applies biome resources to the map's own environment and light.

const Profile = preload("res://scripts/biome_graphics_profile.gd")
const Palette = preload("res://scripts/world_map_showcase_palette.gd")
const MistVolume = preload("res://scripts/world_map_atmosphere_volume.gd")
const LocalExposure = preload("res://scripts/world_map_local_exposure.gd")
const HOURS := [7., 12., 16.5, 18.5, 22.]
enum Quality { ESSENTIAL, BALANCED, FULL }
const QUALITY_LABELS := ["Nhẹ", "Cân bằng", "Đầy đủ"]

var quality := Quality.FULL
var weather_weight := 0.
var _weather_target := 0.
var _weather_from := 0.
var _weather_progress := 1.
var _weather_duration := 0.
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
var _mist_sample: Dictionary
var _allow_adaptive_bloom := true
var _finish_effect: LocalExposure
var _finish_camera: Camera3D
var _finish_compositor: Compositor
var _previous_compositor: Compositor

func setup(world: Node3D, profile: Profile, alternatives: Array[Profile]) -> void:
	_world = world
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
		_weather_target = 0.
		weather_weight = 0.
		_weather_progress = 1.
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
	if _profile.overcast == null or not is_finite(overcast) or not is_finite(seconds):
		return
	_weather_from = weather_weight
	_weather_target = clampf(overcast, 0., 1.)
	_weather_progress = 0.
	_weather_duration = maxf(seconds, 0.)
	if _weather_duration == 0.:
		weather_weight = _weather_target
		_weather_progress = 1.
		refresh()

func _process(delta: float) -> void:
	_update_finish()
	_update_spatial_mist()
	if _cycle and _world.look.stage == 2:
		_world.showcase.set_hour(Palette.advance(_world.showcase.hour, delta, _profile.cycle_minutes * 60.))
	if _weather_progress < 1.:
		_weather_progress = minf(1., _weather_progress + delta / _weather_duration)
		weather_weight = lerpf(_weather_from, _weather_target, smoothstep(0., 1., _weather_progress))
		refresh()

func refresh() -> void:
	var hour: float = _world.showcase.hour
	if _label != null:
		_label.text = "%s · %s · %02d:%02d · Mây %d%%   T giờ · Shift+T tự chuyển · F6 mây · F8 preset · J so sương · F7 hậu kỳ · Shift+F7 chất lượng · B đối chiếu" % [
			_profile.display_name, QUALITY_LABELS[quality], int(hour), int(fmod(hour, 1.) * 60.), roundi(weather_weight * 100.)]
	if _world.look.stage != 2:
		_update_finish()
		return
	var env: Environment = _world.get_node("WorldEnvironment").environment
	var sun: DirectionalLight3D = _world.get_node("Sun")
	var p := _palette.sample(hour)
	apply_lighting(sun, env, p, _noon, _profile.noon_sun_rotation, _profile.noon_sun_color,
		_profile.noon_sun_energy, _profile.noon_ambient_color, _profile.noon_ambient_energy)
	var sky := _profile.noon_sky_color * Color(p.sky) / Color(_noon.sky)
	var fog_color := _profile.noon_fog_color * Color(p.fog) / Color(_noon.fog)
	var time := hour / 24.
	if _profile.key_energy_by_hour != null:
		sun.light_energy *= maxf(0., _profile.key_energy_by_hour.sample(time))
	var fog_density := _profile.noon_fog_density * float(p.fog_amount) / float(_noon.fog_amount)
	if _profile.fog_density_by_hour != null:
		fog_density *= maxf(0., _profile.fog_density_by_hour.sample(time))
	var saturation := _profile.saturation * float(p.saturation) / float(_noon.saturation)
	var weather := _profile.overcast
	if weather != null and weather_weight > 0.:
		sun.light_color = sun.light_color.lerp(weather.key_color, weather_weight)
		sun.light_energy *= lerpf(1., weather.key_energy_scale, weather_weight)
		env.ambient_light_energy *= lerpf(1., weather.ambient_energy_scale, weather_weight)
		sky = sky.lerp(weather.fog_color, .45 * weather_weight)
		fog_color = fog_color.lerp(weather.fog_color, weather_weight)
		fog_density += weather.additional_fog * weather_weight
		saturation *= lerpf(1., weather.saturation_scale, weather_weight)
	env.background_color = sky
	env.fog_enabled = _fog_enabled
	env.fog_mode = Environment.FOG_MODE_DEPTH
	apply_depth_fog(env, fog_color, clampf(fog_density, 0., 1.), _profile.fog_depth_m.x,
		maxf(_profile.fog_depth_m.y, _profile.fog_depth_m.x + .1))
	env.tonemap_mode = _profile.tonemap
	env.tonemap_exposure = _profile.exposure * float(p.exposure) / float(_noon.exposure)
	env.adjustment_enabled = true
	env.adjustment_color_correction = _profile.color_correction
	apply_finish(env, _profile.contrast, saturation, _profile.glow_intensity > 0.,
		_profile.glow_intensity, _profile.glow_bloom, _profile.glow_hdr_threshold)
	_prepare_spatial_mist(env)
	_update_finish()


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
		_finish_camera = camera
		_previous_compositor = camera.compositor
		_finish_compositor = Compositor.new()
		var source := _previous_compositor
		if source == null:
			var world_environment: WorldEnvironment = _world.get_node("WorldEnvironment")
			source = world_environment.compositor
		var chain: Array[CompositorEffect] = []
		if source != null:
			chain.assign(source.compositor_effects)
		_finish_effect = LocalExposure.new()
		chain.append(_finish_effect)
		_finish_compositor.compositor_effects = chain
		camera.compositor = _finish_compositor
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

func _exit_tree() -> void:
	if _finish_effect == null:
		return
	var effect := _finish_effect
	effect.enabled = false
	if is_instance_valid(_finish_camera) and _finish_camera.compositor == _finish_compositor:
		_finish_camera.compositor = _previous_compositor
	RenderingServer.call_on_render_thread(effect.release_on_render_thread)

func _prepare_spatial_mist(env: Environment) -> void:
	var active := quality != Quality.ESSENTIAL and _profile.spatial_mist and RenderingServer.get_current_rendering_method() == "mobile" \
		and RenderingServer.get_rendering_device() != null
	if not active:
		_mist_sample.clear()
		_update_spatial_mist()
		return
	if _mist == null:
		_mist = MistVolume.new()
		_world.get_node("Camera3D").add_child(_mist)
		_mist.setup()
		_mist.material_provider = _world.showcase._mist_materials
		_mist.compositor_owned = _owns_finish_compositor
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
	var local_strength := _profile.local_mist_strength * lerpf(.55, 1., weather_weight)
	_mist.set_local_region(_world.local_mist_region, local_strength)
	_mist.set_additional_local_region(_world.additional_mist_region, local_strength)
	_update_spatial_mist()

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
		_mist.publish(_mist_sample, position, _world.spawn_position.y, _world.look.elapsed, true, 0.)

static func apply_lighting(sun: DirectionalLight3D, env: Environment, phase: Dictionary, noon: Dictionary,
		sun_rotation: Vector3, key_color: Color, key_energy: float, ambient_color: Color, ambient_energy: float) -> void:
	sun.rotation_degrees = sun_rotation + Vector3(phase.pitch - noon.pitch, phase.yaw - noon.yaw, 0.)
	sun.light_color = key_color * Color(phase.key) / Color(noon.key)
	sun.light_energy = key_energy * float(phase.energy) / float(noon.energy)
	env.ambient_light_color = ambient_color * Color(phase.ambient) / Color(noon.ambient)
	env.ambient_light_energy = ambient_energy * float(phase.ambient_energy) / float(noon.ambient_energy)

static func apply_depth_fog(env: Environment, tint: Color, density: float, begin: float, end: float) -> void:
	env.fog_light_color = tint
	env.fog_depth_begin = begin
	env.fog_depth_end = end
	env.fog_density = density

static func apply_finish(env: Environment, contrast: float, saturation: float,
		glow: bool, intensity: float, bloom: float, threshold: float) -> void:
	env.adjustment_contrast = contrast
	env.adjustment_saturation = saturation
	env.glow_enabled = glow
	env.glow_intensity = intensity
	env.glow_bloom = bloom
	env.glow_hdr_threshold = threshold

func handle_key(event: InputEventKey) -> bool:
	match event.physical_keycode:
		KEY_T:
			if event.shift_pressed:
				_cycle = not _cycle
			else:
				var next: float = HOURS[0]
				for time: float in HOURS:
					if time > _world.showcase.hour + .01:
						next = time
						break
				_world.showcase.set_hour(next)
		KEY_F6:
			set_weather(0. if _weather_target > 0. else 1.)
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
