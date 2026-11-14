extends Resource
## A world-height and view-depth envelope for ambient scattering.

@export var depth_behind_subject_m := Vector2(4., 12.)
@export var height_above_map_base_m := Vector2(0., 4.)
@export_range(0., 2., .01) var max_gain := 1.2
@export var morning_hours := Vector4(5.5, 7.0, 8.3, 10.5)
@export var evening_hours := Vector4(14.5, 16.5, 18.3, 19.0)

func _window(hours: Vector4, time: float) -> float:
	if not hours.is_finite() or hours.x >= hours.y or hours.y > hours.z or hours.z >= hours.w:
		return 0.
	return smoothstep(hours.x, hours.y, time) * (1. - smoothstep(hours.z, hours.w, time))

func sample(hour: float, subject_depth_m: float, map_base_y: float, mix_strength: float) -> PackedFloat32Array:
	if not is_finite(hour) or not is_finite(subject_depth_m) or not is_finite(map_base_y) or not is_finite(mix_strength) or not is_finite(max_gain) 			or not depth_behind_subject_m.is_finite() or depth_behind_subject_m.x < 0. or depth_behind_subject_m.y <= depth_behind_subject_m.x 			or not height_above_map_base_m.is_finite() or height_above_map_base_m.y <= height_above_map_base_m.x:
		return PackedFloat32Array()
	var weight := maxf(_window(morning_hours, hour), _window(evening_hours, hour)) * clampf(mix_strength, 0., 1.)
	var gain := clampf(max_gain, 0., 2.) * weight
	if gain <= 0.:
		return PackedFloat32Array()
	return PackedFloat32Array([
		subject_depth_m + depth_behind_subject_m.x, subject_depth_m + depth_behind_subject_m.y,
		map_base_y + height_above_map_base_m.x, map_base_y + height_above_map_base_m.y,
		gain, 0., 0., 0.,
	])
