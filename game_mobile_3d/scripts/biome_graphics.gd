extends Node
## Applies biome resources to the map's own environment and light.

const Profile = preload("res://scripts/biome_graphics_profile.gd")
const Palette = preload("res://scripts/world_map_showcase_palette.gd")
const HOURS := [7., 12., 16.5, 18.5, 22.]

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

func setup(world: Node3D, profile: Profile, alternatives: Array[Profile]) -> void:
	_world = world
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
	if _profile.overcast == null:
		_weather_target = 0.
		weather_weight = 0.
		_weather_progress = 1.
	refresh()

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
	if _cycle and _world.look.stage == 2:
		_world.showcase.set_hour(Palette.advance(_world.showcase.hour, delta, _profile.cycle_minutes * 60.))
	if _weather_progress < 1.:
		_weather_progress = minf(1., _weather_progress + delta / _weather_duration)
		weather_weight = lerpf(_weather_from, _weather_target, smoothstep(0., 1., _weather_progress))
		refresh()

func refresh() -> void:
	var hour: float = _world.showcase.hour
	if _label != null:
		_label.text = "%s · %02d:%02d · Mây %d%%   T giờ · Shift+T tự chuyển · F6 mây · F8 preset · B đối chiếu" % [
			_profile.display_name, int(hour), int(fmod(hour, 1.) * 60.), roundi(weather_weight * 100.)]
	if _world.look.stage != 2:
		return
	var env: Environment = _world.get_node("WorldEnvironment").environment
	var sun: DirectionalLight3D = _world.get_node("Sun")
	var p := _palette.sample(hour)
	apply_lighting(sun, env, p, _noon, _profile.noon_sun_rotation, _profile.noon_sun_color,
		_profile.noon_sun_energy, _profile.noon_ambient_color, _profile.noon_ambient_energy)
	var sky := _profile.noon_sky_color * Color(p.sky) / Color(_noon.sky)
	var fog_color := _profile.noon_fog_color * Color(p.fog) / Color(_noon.fog)
	var fog_density := _profile.noon_fog_density * float(p.fog_amount) / float(_noon.fog_amount)
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
		KEY_F8:
			_profile_index = (_profile_index + 1) % _choices.size()
			set_profile(_choices[_profile_index])
		KEY_L:
			_label.visible = not _label.visible
		_:
			return false
	return true
