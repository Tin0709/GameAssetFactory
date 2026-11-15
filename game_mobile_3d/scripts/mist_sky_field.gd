extends Resource
## Red-channel hemisphere occlusion on a world-space lattice, at texel centers.

@export var texture: Texture3D
@export var origin := Vector3.ZERO
@export var spacing := Vector3.ONE

func is_valid() -> bool:
	if texture == null or not origin.is_finite() or not spacing.is_finite():
		return false
	return minf(spacing.x, minf(spacing.y, spacing.z)) >= .01 and (
		mini(texture.get_width(), mini(texture.get_height(), texture.get_depth())) >= 2)

func parameters(source: Vector4) -> PackedFloat32Array:
	return PackedFloat32Array([source.x, source.y, source.z, source.w,
		origin.x, origin.y, origin.z, 0., spacing.x, spacing.y, spacing.z, 0.])
