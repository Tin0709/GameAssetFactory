extends Resource
## Original canonical crown visibility; coefficients encode a low-order cosine kernel.
@export var origin := Vector3(-6, -1, -6)
@export var dimensions := Vector3i(25, 15, 25)
@export var spacing := 0.5
@export var coefficients := PackedVector4Array()

func sample(point: Vector3) -> PackedVector4Array:
	var result := PackedVector4Array([Vector4.ZERO, Vector4.ZERO, Vector4.ZERO])
	var p := (point - origin) / spacing
	if p.x < 0 or p.y < 0 or p.z < 0 or p.x > dimensions.x - 1 or p.y > dimensions.y - 1 or p.z > dimensions.z - 1: return result
	var low := Vector3i(p.floor())
	var high := (low + Vector3i.ONE).min(dimensions - Vector3i.ONE)
	var weight := p - Vector3(low)
	for z in 2:
		for y in 2:
			for x in 2:
				var ix := high.x if x else low.x
				var iy := high.y if y else low.y
				var iz := high.z if z else low.z
				var w := (weight.x if x else 1.0 - weight.x) * (weight.y if y else 1.0 - weight.y) * (weight.z if z else 1.0 - weight.z)
				var index := ((iz * dimensions.y + iy) * dimensions.x + ix) * 3
				for term in 3: result[term] += coefficients[index + term] * w
	# A broad static visibility cache is not a hard-edged gameplay volume.
	var fade := 1.0 - smoothstep(5.0, 6.0, maxf(absf(point.x), absf(point.z)))
	fade *= smoothstep(-1.0, -0.5, point.y)
	for term in 3: result[term] *= fade
	return result
