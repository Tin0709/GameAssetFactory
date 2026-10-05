extends RefCounted
## Closed-form underdamped state step, with zero-centred impulse targets.
## Channels are vertical displacement, pitch, yaw. No allocations per update.
var value := Vector3.ZERO
var velocity := Vector3.ZERO

func reset() -> void:
	value = Vector3.ZERO
	velocity = Vector3.ZERO

func kick(impulse: Vector3, limit: float) -> void:
	velocity = (velocity + impulse).clamp(Vector3.ONE * -limit, Vector3.ONE * limit)

func advance(delta: float, target: Vector3, frequency: float, damping: float, limits: Vector3) -> void:
	if delta <= 0.0: return
	var omega := TAU * maxf(0.1, frequency)
	var decay := omega * clampf(damping, 0.05, 0.95)
	var angular := sqrt(omega * omega - decay * decay)
	var attenuation := exp(-decay * delta)
	var sine := sin(angular * delta)
	var cosine := cos(angular * delta)
	var offset := value - target
	var old_velocity := velocity
	value = target + attenuation * (offset * cosine + (old_velocity + decay * offset) * (sine / angular))
	velocity = attenuation * (old_velocity * cosine - (decay * old_velocity + omega * omega * offset) * (sine / angular))
	var bounded := value.clamp(-limits, limits)
	for axis in 3:
		if bounded[axis] != value[axis]: velocity[axis] = 0.0
	value = bounded

static func contacts_crossed(phase: float, travel: float, marker: float) -> int:
	# Two alternating authored stride extrema per cycle, including wraps/reverse.
	return mini(4, absi(int(floor((phase + travel - marker) * 2.0)) - int(floor((phase - marker) * 2.0))))
