extends Node3D
## Original scene-local Sword feedback. World-space endpoints/events; call setup once.
## Only accepted combat contacts may call impact/defense. swing() also works on a whiff.
## Pools/resources are allocated once; event paths never create nodes/materials/tweens.
const CAPACITY := 256
const TRAIL_SAMPLES := 10
const TRAIL_VERTICES := (TRAIL_SAMPLES - 1) * 6
const AUDIO_VOICES := 6
const PARTICLE_SHADER = preload("particles.gdshader")
const TRAIL_SHADER = preload("trail.gdshader")
const SWING_AUDIO = preload("audio/swing.wav")
const HIT_AUDIO = preload("audio/impact.wav")
const FINISHER_AUDIO = preload("audio/finisher.wav")
const GUARD_AUDIO = preload("audio/guard.wav")
const PARRY_AUDIO = preload("audio/parry.wav")
const IVORY := Color(1.0, 0.93, 0.72, 0.75)
const GOLD := Color(1.0, 0.65, 0.20, 0.40)
const CYAN := Color(0.27, 0.91, 1.0, 0.80)
const WHITE := Color(0.91, 1.0, 1.0, 0.85)
const EARTH := Color(0.48, 0.39, 0.24, 0.0)
@export_range(0, 2) var quality: int = 1
@export_range(0.0, 2.0, 0.05) var intensity: float = 1.0
var _initialized := false
var _particles: MultiMeshInstance3D
var _multimesh: MultiMesh
var _ribbon: MeshInstance3D
var _trail_mesh: ArrayMesh
var _trail_material: ShaderMaterial
var _voices: Array[AudioStreamPlayer] = []
var _voice_cursor := 0
var _audio_clock := 1.0
var _last_contact_sound := -1.0
var _last_swing_sound := -1.0
var _alive := 0
var _cursor := 0
var _emitted_this_frame := 0
var _life := PackedFloat32Array()
var _duration := PackedFloat32Array()
var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _sizes := PackedVector3Array()
var _gravity := PackedFloat32Array()
var _orientations: Array[Basis] = []
var _colors := PackedColorArray()
var _trail_base := PackedVector3Array()
var _trail_tip := PackedVector3Array()
var _trail_ages := PackedFloat32Array()
var _trail_bytes := PackedByteArray()
var _trail_count := 0
var _trail_active := false
var _trail_finisher := false
var _trail_fade := 0.0
var _rng := RandomNumberGenerator.new()

func setup() -> void:
	if _initialized: return
	_initialized = true
	# Every renderer uses world coordinates, independent of actor movement/rotation.
	_particles = MultiMeshInstance3D.new()
	_particles.name = "SwordParticlePool"
	_particles.top_level = true
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.instance_count = CAPACITY
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var particle_material := ShaderMaterial.new()
	particle_material.shader = PARTICLE_SHADER
	cube.material = particle_material
	_multimesh.mesh = cube
	_particles.multimesh = _multimesh
	add_child(_particles)
	_particles.global_transform = Transform3D.IDENTITY
	_life.resize(CAPACITY)
	_duration.resize(CAPACITY)
	_positions.resize(CAPACITY)
	_velocities.resize(CAPACITY)
	_sizes.resize(CAPACITY)
	_gravity.resize(CAPACITY)
	_orientations.resize(CAPACITY)
	_colors.resize(CAPACITY)
	_rng.seed = 0x53574F5244
	_trail_base.resize(TRAIL_SAMPLES)
	_trail_tip.resize(TRAIL_SAMPLES)
	_trail_ages.resize(TRAIL_SAMPLES)
	_trail_bytes.resize(TRAIL_VERTICES * 12)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(TRAIL_VERTICES)
	uvs.resize(TRAIL_VERTICES)
	for segment in TRAIL_SAMPLES - 1:
		var u0 := float(segment) / float(TRAIL_SAMPLES - 1)
		var u1 := float(segment + 1) / float(TRAIL_SAMPLES - 1)
		var offset := segment * 6
		uvs[offset] = Vector2(u0, 0)
		uvs[offset + 1] = Vector2(u0, 1)
		uvs[offset + 2] = Vector2(u1, 1)
		uvs[offset + 3] = Vector2(u0, 0)
		uvs[offset + 4] = Vector2(u1, 1)
		uvs[offset + 5] = Vector2(u1, 0)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	_trail_mesh = ArrayMesh.new()
	_trail_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	_trail_material = ShaderMaterial.new()
	_trail_material.shader = TRAIL_SHADER
	_ribbon = MeshInstance3D.new()
	_ribbon.name = "SwordBladeRibbon"
	_ribbon.top_level = true
	_ribbon.mesh = _trail_mesh
	_ribbon.material_override = _trail_material
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ribbon)
	_ribbon.global_transform = Transform3D.IDENTITY
	for index in AUDIO_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "SwordVoice%d" % index
		voice.max_polyphony = 1
		voice.volume_db = -15.0
		add_child(voice)
		_voices.append(voice)
	reset()

func set_trail(base: Vector3, tip: Vector3, active: bool, finisher: bool = false) -> void:
	if not _initialized: return
	var enabled := active and intensity > 0.0 and base.distance_squared_to(tip) > 0.001
	if enabled:
		# A teleport/switch cannot draw a long streak through the scene.
		if not _trail_active or (_trail_count > 0 and _trail_tip[0].distance_squared_to(tip) > 4.0):
			_trail_count = 0
		for index in range(mini(_trail_count, TRAIL_SAMPLES - 1), 0, -1):
			_trail_base[index] = _trail_base[index - 1]
			_trail_tip[index] = _trail_tip[index - 1]
			_trail_ages[index] = _trail_ages[index - 1]
		_trail_base[0] = base.lerp(tip, 0.30)
		_trail_tip[0] = tip
		_trail_ages[0] = 0.0
		_trail_count = mini(_trail_count + 1, TRAIL_SAMPLES)
		_trail_fade = 1.0
		_trail_finisher = finisher
	_trail_active = enabled
	_write_trail()

func swing(index: int) -> void:
	if not _initialized or intensity <= 0.0: return
	if _audio_clock - _last_swing_sound < 0.065: return
	_last_swing_sound = _audio_clock
	_play(SWING_AUDIO, -17.0 if index < 3 else -13.5, 1.08 - float(clampi(index, 1, 3)) * 0.07)

func impact(point: Vector3, direction: Vector3, finisher: bool = false, poise_break: bool = false) -> void:
	if not _initialized or intensity <= 0.0: return
	var forward := direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	var number := _scaled_count(13 if finisher else 8)
	for index in number:
		var scatter := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.15, 1.0), _rng.randf_range(-1.0, 1.0))
		var velocity := (forward * 0.75 + scatter).normalized() * _rng.randf_range(1.6, 3.5 if finisher else 2.7)
		var size := _rng.randf_range(0.035, 0.065) * (1.18 if finisher else 1.0)
		_emit(point, velocity, Vector3(size, size, size * 2.4), _rng.randf_range(0.12, 0.24), 6.0, IVORY if index % 3 == 0 else GOLD)
	# Compact radial contact spokes, never a full-screen flash/billboard.
	_ring(point, forward, 0.09, 1.6 if finisher else 1.1, 0.11, IVORY, 8 if finisher else 5)
	if poise_break:
		_ring(point, Vector3.UP, 0.24, 2.4, 0.25, CYAN, 18)
		_ring(point, forward, 0.12, 1.9, 0.19, WHITE, 12)
	if _audio_clock - _last_contact_sound >= 0.045:
		_last_contact_sound = _audio_clock
		_play(FINISHER_AUDIO if finisher or poise_break else HIT_AUDIO, -12.5 if finisher else -16.0, _rng.randf_range(0.94, 1.06))

func defense(point: Vector3, parry: bool) -> void:
	if not _initialized or intensity <= 0.0: return
	_ring(point, Vector3.FORWARD, 0.12, 1.7 if parry else 1.1, 0.22 if parry else 0.14, CYAN if parry else IVORY, 20 if parry else 10)
	if parry:
		_ring(point, Vector3.UP, 0.12, 2.0, 0.21, WHITE, 14)
		for index in _scaled_count(6):
			_emit(point, Vector3(_rng.randf_range(-2, 2), _rng.randf_range(0.7, 2.3), _rng.randf_range(-1, 1)), Vector3(0.045, 0.045, 0.11), 0.19, 4.0, WHITE)
	if _audio_clock - _last_contact_sound >= 0.045:
		_last_contact_sound = _audio_clock
		_play(PARRY_AUDIO if parry else GUARD_AUDIO, -13.0 if parry else -17.0, 1.0)

func dust(point: Vector3, strength: float = 1.0) -> void:
	if not _initialized or intensity <= 0.0 or strength <= 0.0: return
	for index in _scaled_count(5):
		var radial := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1))
		var size := _rng.randf_range(0.04, 0.075) * minf(strength, 1.6)
		_emit(point + radial * 0.13 + Vector3.UP * 0.045, radial * strength * 0.7 + Vector3.UP * 0.3, Vector3(size * 1.3, size * 0.6, size), 0.23, 1.0, EARTH)

func reset() -> void:
	if not _initialized: return
	_alive = 0
	_cursor = 0
	_emitted_this_frame = 0
	_trail_count = 0
	_trail_active = false
	_trail_fade = 0.0
	_ribbon.visible = false
	_life.fill(0.0)
	var hidden := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO)
	for index in CAPACITY:
		_multimesh.set_instance_transform(index, hidden)
	for voice in _voices:
		voice.stop()
	_last_contact_sound = -1.0
	_last_swing_sound = -1.0

func active_count() -> int:
	return _alive

func fixed_capacity() -> int:
	return CAPACITY

func _process(delta: float) -> void:
	if not _initialized: return
	# Controller hit-stop is local; this clock continues in ordinary render delta.
	var dt := maxf(delta, 0.0)
	_audio_clock += dt
	_emitted_this_frame = 0
	for index in CAPACITY:
		if _life[index] <= 0.0: continue
		_life[index] -= dt
		if _life[index] <= 0.0:
			_alive -= 1
			_multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
			continue
		_velocities[index].y -= _gravity[index] * dt
		_positions[index] += _velocities[index] * dt
		var remaining := _life[index] / _duration[index]
		var shrink := minf(1.0, remaining * 3.0)
		_multimesh.set_instance_transform(index, Transform3D(_orientations[index].scaled(_sizes[index] * shrink), _positions[index]))
	for index in _trail_count:
		_trail_ages[index] += dt
	if not _trail_active:
		_trail_fade = maxf(0.0, _trail_fade - dt / 0.095)
	if _trail_count > 0:
		_write_trail()

func _scaled_count(number: int) -> int:
	var quality_scale := 0.60 if quality <= 0 else (1.0 if quality == 1 else 1.25)
	return maxi(1, int(round(float(number) * quality_scale * clampf(intensity, 0.0, 2.0))))

func _emit(point: Vector3, velocity: Vector3, size: Vector3, lifetime: float, gravity: float, color: Color, orientation: Basis = Basis.IDENTITY) -> void:
	var alive_cap := 96 if quality <= 0 else (160 if quality == 1 else CAPACITY)
	var frame_cap := 36 if quality <= 0 else (64 if quality == 1 else 96)
	if _alive >= alive_cap or _emitted_this_frame >= frame_cap: return
	var slot := _cursor
	for attempt in CAPACITY:
		if _life[slot] <= 0.0: break
		slot = (slot + 1) % CAPACITY
	_cursor = (slot + 1) % CAPACITY
	_life[slot] = lifetime
	_duration[slot] = lifetime
	_positions[slot] = point
	_velocities[slot] = velocity
	_sizes[slot] = size
	_gravity[slot] = gravity
	var particle_basis := orientation
	if orientation == Basis.IDENTITY and velocity.length_squared() > 0.001:
		var travel := velocity.normalized()
		particle_basis = Basis.looking_at(travel, Vector3.UP if absf(travel.y) < 0.95 else Vector3.RIGHT)
	_orientations[slot] = particle_basis
	_colors[slot] = color
	_multimesh.set_instance_color(slot, color)
	_multimesh.set_instance_transform(slot, Transform3D(particle_basis.scaled(size), point))
	_alive += 1
	_emitted_this_frame += 1

func _ring(point: Vector3, normal: Vector3, radius: float, speed: float, lifetime: float, color: Color, count: int) -> void:
	var axis := normal.normalized()
	var tangent := axis.cross(Vector3.UP).normalized() if absf(axis.y) < 0.95 else Vector3.RIGHT
	var bitangent := axis.cross(tangent).normalized()
	var number := _scaled_count(count)
	for index in number:
		var angle := TAU * float(index) / float(number)
		var radial := tangent * cos(angle) + bitangent * sin(angle)
		var along := radial.cross(axis).normalized()
		# Separate crisp box segments; ring expands through velocity, then shrinks.
		var orientation := Basis(radial, axis, along)
		_emit(point + radial * radius, radial * speed, Vector3(0.025, 0.025, 0.10), lifetime, 0.0, color, orientation)

func _write_vertex(index: int, point: Vector3) -> void:
	var offset := index * 12
	_trail_bytes.encode_float(offset, point.x)
	_trail_bytes.encode_float(offset + 4, point.y)
	_trail_bytes.encode_float(offset + 8, point.z)

func _write_trail() -> void:
	_ribbon.visible = _trail_count >= 2 and _trail_fade > 0.001 and intensity > 0.0
	if not _ribbon.visible: return
	var oldest := 0
	var life := 0.12 if _trail_finisher else 0.095
	for index in _trail_count:
		if _trail_ages[index] <= life: oldest = index
	for segment in TRAIL_SAMPLES - 1:
		var current := mini(segment, oldest)
		var prior := mini(segment + 1, oldest)
		var offset := segment * 6
		_write_vertex(offset, _trail_base[current])
		_write_vertex(offset + 1, _trail_tip[current])
		_write_vertex(offset + 2, _trail_tip[prior])
		_write_vertex(offset + 3, _trail_base[current])
		_write_vertex(offset + 4, _trail_tip[prior])
		_write_vertex(offset + 5, _trail_base[prior])
	_trail_mesh.surface_update_vertex_region(0, 0, _trail_bytes)
	# Dynamic world-space AABB without querying renderer/readback.
	var bounds := AABB(_trail_base[0], Vector3.ZERO)
	for index in oldest + 1:
		bounds = bounds.expand(_trail_base[index]).expand(_trail_tip[index])
	_ribbon.custom_aabb = bounds.grow(0.1)
	_trail_material.set_shader_parameter("history_span", maxf(1.0 / float(TRAIL_SAMPLES - 1), float(oldest) / float(TRAIL_SAMPLES - 1)))
	_trail_material.set_shader_parameter("opacity", minf(intensity, 1.4) * _trail_fade)
	_trail_material.set_shader_parameter("finisher", 1.0 if _trail_finisher else 0.0)

func _play(stream: AudioStream, volume: float, pitch: float) -> void:
	# Compressed/headless drivers need not play; real user launch keeps normal audio.
	if DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy": return
	var voice := _voices[_voice_cursor]
	_voice_cursor = (_voice_cursor + 1) % AUDIO_VOICES
	voice.stop()
	voice.stream = stream
	voice.volume_db = volume + linear_to_db(maxf(0.05, minf(intensity, 1.5)))
	voice.pitch_scale = pitch
	voice.play()
