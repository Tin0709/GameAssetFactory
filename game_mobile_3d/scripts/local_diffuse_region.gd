extends Resource
## Map-authored area and opening used by the local diffuse return.

@export var center_xz := Vector2.ZERO
@export var radii_m := Vector2(8., 8.)
@export var opening_world := Vector3.ZERO

func is_valid() -> bool:
	return center_xz.is_finite() and radii_m.is_finite() and opening_world.is_finite() \
		and radii_m.x >= .1 and radii_m.y >= .1

func bounds() -> Vector4:
	return Vector4(center_xz.x, center_xz.y, radii_m.x, radii_m.y)

func source(gain: float) -> Vector4:
	return Vector4(opening_world.x, opening_world.y, opening_world.z, gain)
