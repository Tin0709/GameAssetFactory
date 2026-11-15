extends RefCounted
## One weather blend per map. Stack over the resolved time of day before publishing to materials.
const Profile := preload("res://scripts/biome_weather_profile.gd")
const DayNight := preload("res://scripts/biome_day_night.gd")
const LUMA := Vector3(.2126, .7152, .0722)

var weight := 0.
var target := 0.
var _from := 0.
var _progress := 1.
var _duration := 0.

func set_target(value: float, seconds: float) -> void:
	if not is_finite(value) or not is_finite(seconds):
		return
	_from = weight
	target = clampf(value, 0., 1.)
	_duration = maxf(seconds, 0.)
	_progress = 1. if _duration == 0. or target == weight else 0.
	if _progress == 1.:
		weight = target

func advance(delta: float) -> bool:
	if _progress == 1. or not is_finite(delta) or delta <= 0.:
		return false
	_progress = minf(1., _progress + delta / _duration)
	weight = lerpf(_from, target, smoothstep(0., 1., _progress))
	return true

func apply_lighting(profile: Profile, sun: DirectionalLight3D, env: Environment,
		hour: float = 12., phase_color_scale: float = 1.) -> void:
	if profile == null or weight <= 0.:
		return
	var phase_key := sun.light_color
	var cloud_key := phase_key.lerp(profile.key_color, weight)
	if phase_color_scale > 0. and maxf(profile.phase_key_color_retention, profile.ambient_chroma_reduction) > 0.:
		var hour_weight := DayNight.sample_curve(profile.phase_color_by_hour, fposmod(hour, 24.) / 24., 1.)
		var amount := weight * clampf(hour_weight, 0., 1.) * clampf(phase_color_scale, 0., 1.)
		cloud_key = _transfer_chroma(cloud_key, phase_key, amount * profile.phase_key_color_retention)
		env.ambient_light_color = _transfer_chroma(env.ambient_light_color, Color.WHITE,
			amount * profile.ambient_chroma_reduction)
	sun.light_color = cloud_key
	sun.light_energy *= lerpf(1., profile.key_energy_scale, weight)
	env.ambient_light_energy *= lerpf(1., profile.ambient_energy_scale, weight)
	env.background_color = env.background_color.lerp(profile.fog_color, .45 * weight)

static func _transfer_chroma(base: Color, source: Color, amount: float) -> Color:
	if amount <= 0.:
		return base
	var base_linear := base.srgb_to_linear()
	var source_linear := source.srgb_to_linear()
	var a := Vector3(base_linear.r, base_linear.g, base_linear.b)
	var b := Vector3(source_linear.r, source_linear.g, source_linear.b)
	var source_y := b.dot(LUMA)
	if source_y <= .00001:
		return base
	var delta := b * (a.dot(LUMA) / source_y) - a
	# Shorten the blend along the same constant-luminance line at the gamut boundary.
	for axis in 3:
		if delta[axis] > .00001:
			amount = minf(amount, (1. - a[axis]) / delta[axis])
	if amount <= 0.:
		return base
	var rgb := a + delta * amount
	return Color(rgb.x, rgb.y, rgb.z, base.a).linear_to_srgb()

func apply_air(profile: Profile, env: Environment, fog_gain: float = 1.) -> void:
	if profile == null or weight <= 0.:
		return
	env.fog_light_color = env.fog_light_color.lerp(profile.fog_color, weight)
	env.fog_density = clampf(env.fog_density + profile.additional_fog * weight * fog_gain, 0., 1.)
	env.adjustment_saturation *= lerpf(1., profile.saturation_scale, weight)

func apply_medium(profile: Profile, sample: Dictionary) -> void:
	if profile == null or weight <= 0.:
		return
	var scale := lerpf(1., profile.spatial_extinction_scale, weight)
	sample.volume_density *= scale
	if sample.has("near_layer"):
		var near_layer: Vector3 = sample.near_layer
		near_layer.y *= scale
		sample.near_layer = near_layer
	# Native-backed adapters may have supplied a calibrated linear scatter source.
	# Retint that source while retaining its luminance and the exposure calibration.
	if sample.has("linear_scatter_rgb"):
		var source: Vector3 = sample.linear_scatter_rgb
		var tint := profile.fog_color.srgb_to_linear()
		var rgb := Vector3(tint.r, tint.g, tint.b)
		var luma := Vector3(.2126, .7152, .0722)
		if rgb.dot(luma) > .00001:
			sample.linear_scatter_rgb = source.lerp(rgb * (source.dot(luma) / rgb.dot(luma)), weight)
