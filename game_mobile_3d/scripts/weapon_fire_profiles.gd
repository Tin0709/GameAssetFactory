extends RefCounted
## Prototype shot data shared by gameplay and the isolated Pose Lab.
const PROFILES = [
	{"damage": 20, "interval": 0.50, "target_range": 8.0, "speed": 14.0, "range": 12.6, "pellets": 1, "spread": 0.0, "flash_scale": 0.75, "flash_duration": 0.04},
	{"damage": 12, "interval": 0.12, "target_range": 10.0, "speed": 20.0, "range": 15.0, "pellets": 1, "spread": 0.0, "flash_scale": 0.95, "flash_duration": 0.035},
	{"damage": 10, "interval": 1.0, "target_range": 6.0, "speed": 18.0, "range": 7.0, "pellets": 7, "spread": 10.0, "flash_scale": 1.45, "flash_duration": 0.055}
]

static func directions(forward: Vector3, weapon: int, shot: int) -> Array[Vector3]:
	var result: Array[Vector3] = [forward.normalized()]
	var profile: Dictionary = PROFILES[weapon]
	if profile.pellets == 1: return result
	var axis := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var right := forward.cross(axis).normalized()
	var up := right.cross(forward).normalized()
	# Centre pellet plus a staggered outer ring: no coincident directions, no RNG.
	var radius := tan(deg_to_rad(profile.spread))
	for i in range(profile.pellets - 1):
		var angle: float = TAU * float(i) / (profile.pellets - 1) + shot * 0.37
		result.append((forward + (right * cos(angle) + up * sin(angle)) * radius).normalized())
	return result
