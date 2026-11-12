extends Resource
## World-space ellipsoid for a map using the shared orthographic mist.

@export var center_m := Vector3.ZERO
@export var radii_m := Vector3(5., 2., 5.)
@export_range(0., .1, .001) var extinction_per_meter := .045
@export var scatter_multiplier := Vector3(.95, 1.75, 2.9)

func render_parameters(gain: float) -> PackedFloat32Array:
	if not is_finite(gain) or gain <= 0. or not is_finite(extinction_per_meter) \
			or extinction_per_meter <= 0. or not center_m.is_finite() or not radii_m.is_finite() \
			or radii_m.x < .1 or radii_m.y < .1 or radii_m.z < .1 or not scatter_multiplier.is_finite():
		return PackedFloat32Array()
	var rgb := scatter_multiplier.clamp(Vector3.ZERO, Vector3(4., 4., 4.))
	return PackedFloat32Array([
		center_m.x, center_m.y, center_m.z, minf(extinction_per_meter, .1) * clampf(gain, 0., 1.),
		radii_m.x, radii_m.y, radii_m.z, 0.,
		rgb.x, rgb.y, rgb.z, 0.,
	])
