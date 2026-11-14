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
var _label: Label

func setup(world: Node3D, profile: Profile) -> void:
	_world = world
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
	if profile == null:
		return
	_profile = profile
	refresh()

func set_weather(overcast: float, seconds: float = 2.5) -> void:
	if not is_finite(overcast) or not is_finite(seconds):
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
		_label.text = "%s · %02d:%02d · Mây %d%%   T thời gian · Shift+T tự chuyển · F6 mây · B đối chiếu" % [
			_profile.display_name, int(hour), int(fmod(hour, 1.) * 60.), roundi(weather_weight * 100.)]
	if _world.look.stage != 2:
		return
	var env: Environment = _world.get_node("WorldEnvironment").environment
	var sun: DirectionalLight3D = _world.get_node("Sun")
	var p := _palette.sample(hour)
	var sky := _profile.noon_sky_color * Color(p.sky) / Color(_noon.sky)
	apply_lighting(sun, env, p, _noon, _profile.noon_sun_rotation, _profile.noon_sun_color,
		_profile.noon_sun_energy, _profile.noon_ambient_color, _profile.noon_ambient_energy)
	sun.light_color = sun.light_color.lerp(_profile.overcast_light_color, weather_weight)
	sun.light_energy *= lerpf(1., _profile.overcast_key, weather_weight)
	env.ambient_light_energy *= lerpf(1., _profile.overcast_ambient, weather_weight)
	env.background_color = sky.lerp(_profile.overcast_fog_color, .45 * weather_weight)
	_apply_fog(env, p)
	_apply_grade(env, p)
	_apply_bloom(env)

static func apply_lighting(sun: DirectionalLight3D, env: Environment, phase: Dictionary, noon: Dictionary,
		sun_rotation: Vector3, key_color: Color, key_energy: float, ambient_color: Color, ambient_energy: float) -> void:
	sun.rotation_degrees = sun_rotation + Vector3(phase.pitch - noon.pitch, phase.yaw - noon.yaw, 0.)
	sun.light_color = key_color * Color(phase.key) / Color(noon.key)
	sun.light_energy = key_energy * float(phase.energy) / float(noon.energy)
	env.ambient_light_color = ambient_color * Color(phase.ambient) / Color(noon.ambient)
	env.ambient_light_energy = ambient_energy * float(phase.ambient_energy) / float(noon.ambient_energy)

func _apply_fog(env: Environment, phase: Dictionary) -> void:
	env.fog_enabled = _fog_enabled
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = _profile.fog_depth_m.x
	env.fog_depth_end = maxf(_profile.fog_depth_m.y, _profile.fog_depth_m.x + .1)
	env.fog_light_color = (_profile.noon_fog_color * Color(phase.fog) / Color(_noon.fog)).lerp(
		_profile.overcast_fog_color, weather_weight)
	env.fog_density = clampf(_profile.noon_fog_density * float(phase.fog_amount) / float(_noon.fog_amount)
		+ _profile.overcast_density * weather_weight, 0., 1.)

func _apply_grade(env: Environment, phase: Dictionary) -> void:
	env.tonemap_mode = _profile.tonemap
	env.tonemap_exposure = _profile.exposure * float(phase.exposure) / float(_noon.exposure)
	env.adjustment_enabled = true
	env.adjustment_contrast = _profile.contrast
	env.adjustment_saturation = _profile.saturation * float(phase.saturation) / float(_noon.saturation)
	env.adjustment_saturation *= lerpf(1., _profile.overcast_saturation, weather_weight)
	env.adjustment_color_correction = _profile.color_correction

func _apply_bloom(env: Environment) -> void:
	env.glow_enabled = _profile.glow_intensity > 0.
	env.glow_intensity = _profile.glow_intensity
	env.glow_bloom = _profile.glow_bloom
	env.glow_hdr_threshold = _profile.glow_hdr_threshold

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
		KEY_L:
			_label.visible = not _label.visible
		_:
			return false
	return true
