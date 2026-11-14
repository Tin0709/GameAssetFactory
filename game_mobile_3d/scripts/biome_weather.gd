extends RefCounted
## One weather blend per map. Stack over the resolved time of day before publishing to materials.
const Profile := preload("res://scripts/biome_weather_profile.gd")

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

func apply_lighting(profile: Profile, sun: DirectionalLight3D, env: Environment) -> void:
	if profile == null or weight <= 0.:
		return
	sun.light_color = sun.light_color.lerp(profile.key_color, weight)
	sun.light_energy *= lerpf(1., profile.key_energy_scale, weight)
	env.ambient_light_energy *= lerpf(1., profile.ambient_energy_scale, weight)
	env.background_color = env.background_color.lerp(profile.fog_color, .45 * weight)

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
