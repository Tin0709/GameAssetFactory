extends RefCounted
## One scene-wide motion history. Cost is bounded independently of grass density.
const HISTORY_SIZE := 8
const SEGMENT_SECONDS := 0.12
const RECOVERY_SECONDS := 0.80
var clock := 0.0
var active_count := 0
var samples: Array[Dictionary] = []
var starts := PackedVector4Array()
var ends := PackedVector4Array()
var previous := Vector2.ZERO
var initialized := false

func advance(delta: float, position: Vector3, velocity: Vector3, walk_speed: float, run_speed: float) -> void:
	clock += delta
	var point := Vector2(position.x, position.z)
	var speed := Vector2(velocity.x, velocity.z).length()
	if not initialized:
		previous = point
		initialized = true
	# Expire before inserting, so recycled slots have already faded to zero.
	while not samples.is_empty() and clock - float(samples[0].last) >= RECOVERY_SECONDS:
		samples.pop_front()
	if speed > 0.10 and point.distance_to(previous) > 0.0001:
		var sprint_mix := clampf((speed - walk_speed) / maxf(0.1, run_speed - walk_speed), 0.0, 1.0)
		var strength := lerpf(0.050, 0.090, sprint_mix) * minf(1.0, speed / walk_speed)
		var attack := lerpf(0.14, 0.07, sprint_mix)
		var reversed := false
		if not samples.is_empty():
			var old_direction: Vector2 = samples.back().end - samples.back().start
			reversed = old_direction.normalized().dot((point - previous).normalized()) < 0.5
		if samples.is_empty() or reversed or clock - float(samples.back().born) >= SEGMENT_SECONDS:
			# Preserve old path/recovery at turns. At saturation, wait for an expired
			# slot instead of abruptly deleting a still-visible disturbance.
			if samples.size() < HISTORY_SIZE:
				samples.append({"start": previous, "end": point, "born": clock - delta, "last": clock, "strength": strength, "attack": attack})
		else:
			var sample: Dictionary = samples.back()
			sample.end = point
			sample.last = clock
			# Preserve passage strength while decelerating; fade by age on stopping.
			sample.strength = maxf(float(sample.strength), strength)
			sample.attack = minf(float(sample.attack), attack)
	previous = point
	starts.resize(HISTORY_SIZE)
	ends.resize(HISTORY_SIZE)
	starts.fill(Vector4.ZERO)
	ends.fill(Vector4(0, 0, RECOVERY_SECONDS, 0.14))
	active_count = samples.size()
	for i in range(active_count):
		var sample: Dictionary = samples[i]
		starts[i] = Vector4(sample.start.x, sample.start.y, clock - float(sample.born), sample.strength)
		ends[i] = Vector4(sample.end.x, sample.end.y, clock - float(sample.last), sample.attack)

func publish(material: ShaderMaterial) -> void:
	# One shared clock and two tiny arrays; never update per-instance uniforms.
	material.set_shader_parameter("wind_phase", fmod(clock, 4.0) * TAU / 4.0)
	material.set_shader_parameter("motion_start", starts)
	material.set_shader_parameter("motion_end", ends)
