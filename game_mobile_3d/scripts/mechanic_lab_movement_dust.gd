extends Node3D

const EffectSource := preload("res://scripts/mechanic_lab_effect_source.gd")
const WeaponSource := preload("res://scripts/mechanic_lab_weapon_source.gd")
const SOURCE := "extracted/2026-10-25 19-26-25/Game/Spicewood/FX/Smoke/T_SmokePixel.png"
const SOURCE_SHA256 := "78d326787c4065d70e227ec386a7330f53621c8733ad114bc80eaea7f7f1b5fc"
const FRAMES := [0, 9, 10, 16, 24, 25]
const CAPACITY := 16
const HEAVY_PARTICLE_COUNT := 10
const STEP_ALPHA_PATH := "reports/depth/vfx/step-dust-alpha.private.json"
const STEP_ALPHA_HASH := "c2dae47cc6feaad21508e960739ab5451fcdd691bb194b70ffd85380285579ff"
const LANDING_CURVES_PATH := "reports/depth/vfx/landing-dust-curves.private.json"
const LANDING_CURVES_HASH := "c3144bc6635533a38f59e99fc7b63037beb00209fad19295ff0e37a8156151a3"
const LANDING_STEP := 1.0 / 60.0
# Keep the lab grass tint. The dirt and stone tints lift the source tile
# medians toward a lighter, less saturated dust color.
const SURFACE_DUST := {
	"grass": Color("#c8b67b"),
	"dirt": Color("#b1815d"),
	"stone": Color("#b6b6b6"),
}

class Particle:
	var sprite: Sprite3D
	var origin: Vector3
	var velocity: Vector3
	var age := 0.0
	var duration := 0.0
	var opacity := 0.0
	var run_drag := 0.0
	var landing_tick := -1
	var landing_position: Vector3

var _actor: CharacterBody3D
var _ground: CollisionShape3D
var _terrain_contact: Callable
var _landing_contact: Callable
var _heavy_delay: Callable
var _particles: Array[Particle] = []
var _next := 0
var _heavy_landing_point := Vector3.ZERO
var _heavy_landing_frame := -1
var _burst_frame := -1
var _burst_point: Vector3
var _burst_surface: String
var _random := RandomNumberGenerator.new()
var _run_profile: Callable
var _run_alpha := PackedFloat32Array()
var _run_alpha_duration := 1.0
var _landing_alpha := PackedFloat32Array()
var _landing_alpha_duration := 1.0
var _landing_drag := PackedFloat32Array()

func _ready() -> void:
	set_physics_process(false)

func setup(actor: CharacterBody3D, ground: CollisionShape3D = null, terrain_contact := Callable(),
		heavy_delay := Callable(), landing_contact := Callable(), run_profile := Callable()) -> bool:
	var texture := _load_mask()
	if texture == null:
		return false
	_actor = actor
	_ground = ground
	_terrain_contact = terrain_contact
	_landing_contact = landing_contact
	_heavy_delay = heavy_delay
	if run_profile.is_valid():
		var path := WeaponSource.verified_path(WeaponSource.research_root(), STEP_ALPHA_PATH, STEP_ALPHA_HASH)
		if not path.is_empty():
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			_run_alpha = PackedFloat32Array(data.alpha)
			_run_alpha_duration = float(data.alpha_duration)
			_run_profile = run_profile
	_random.seed = 27381
	for i in CAPACITY:
		var particle := Particle.new()
		particle.sprite = Sprite3D.new()
		particle.sprite.texture = texture
		particle.sprite.hframes = 8
		particle.sprite.vframes = 4
		particle.sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		particle.sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		particle.sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particle.sprite.hide()
		add_child(particle.sprite)
		_particles.append(particle)
	actor.surface_contact.connect(_on_surface_contact)
	actor.heavy_jump_landed.connect(_on_heavy_jump_landed)
	actor.presentation_reset.connect(clear)
	set_process(false)
	return true

func use_source_landing() -> void:
	var path := WeaponSource.verified_path(WeaponSource.research_root(), LANDING_CURVES_PATH, LANDING_CURVES_HASH)
	if path.is_empty():
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_landing_alpha = PackedFloat32Array(data.alpha)
	_landing_alpha_duration = float(data.alpha_duration)
	_landing_drag = PackedFloat32Array(data.drag)

static func _load_mask() -> Texture2D:
	var atlas := EffectSource.load_image(SOURCE, SOURCE_SHA256, Vector2i(128, 64))
	if atlas == null:
		return null
	atlas.convert(Image.FORMAT_RGBA8)
	# The exported RGB channels are masks. Preserve the atlas alpha exactly.
	var pixels := atlas.get_data()
	for i in range(0, pixels.size(), 4):
		pixels[i] = 255
		pixels[i + 1] = 255
		pixels[i + 2] = 255
	return ImageTexture.create_from_image(Image.create_from_data(128, 64, false, Image.FORMAT_RGBA8, pixels))

func _on_heavy_jump_landed(point: Vector3, _forward: Vector3, _serial: int, _fall_height: float) -> void:
	# The player posts this immediately before the ordinary surface event.
	_heavy_landing_point = point
	_heavy_landing_frame = Engine.get_physics_frames()

func _on_surface_contact(point: Vector3, landed: bool) -> void:
	var step_size := float(_run_profile.call()) if not landed and _run_profile.is_valid() else -1.0
	if is_zero_approx(step_size):
		return
	var heavy := landed and _heavy_landing_frame == Engine.get_physics_frames()
	if heavy:
		point = _heavy_landing_point
	_heavy_landing_frame = -1
	var ground_point: Vector3
	var surface := "grass"
	if _terrain_contact.is_valid():
		var resolver := _landing_contact if landed and _landing_contact.is_valid() else _terrain_contact
		var contact: Dictionary = resolver.call(point)
		if contact.is_empty():
			return
		ground_point = contact.position
		surface = contact.surface
	else:
		var box := _ground.shape as BoxShape3D if is_instance_valid(_ground) else null
		if box == null or _ground.disabled:
			return
		var half := box.size * 0.5
		var local := _ground.to_local(point)
		if absf(local.x) > half.x or absf(local.z) > half.z:
			return
		ground_point = _ground.to_global(Vector3(local.x, half.y, local.z))
	if heavy and _heavy_delay.is_valid():
		var delay_ticks := ceili(float(_heavy_delay.call()) * Engine.physics_ticks_per_second)
		if delay_ticks > 0:
			_burst_frame = Engine.get_physics_frames() + delay_ticks
			_burst_point = ground_point
			_burst_surface = surface
			set_physics_process(true)
			return
	if step_size > 0.0:
		_emit_run_dust(ground_point, surface, step_size)
	elif landed and not heavy and not _landing_alpha.is_empty():
		_emit_source_landing(ground_point, surface)
	else:
		_emit_dust(ground_point, surface, landed, heavy)

func _physics_process(_delta: float) -> void:
	if _burst_frame < 0 or Engine.get_physics_frames() < _burst_frame:
		return
	_burst_frame = -1
	set_physics_process(false)
	_emit_dust(_burst_point, _burst_surface, true, true)

func _emit_dust(ground_point: Vector3, surface: String, landed: bool, heavy: bool) -> void:
	var tint: Color = SURFACE_DUST.get(surface, SURFACE_DUST.grass)
	var motion := _actor.get_real_velocity()
	motion.y = 0.0
	var running := motion.length_squared() > 16.0
	if not landed:
		ground_point -= motion.normalized() * (0.12 if running else 0.06)
	var count := 5 if landed else (3 if running else 2)
	var spread := 0.24 if landed else 0.11
	if heavy:
		count = HEAVY_PARTICLE_COUNT
		spread = 0.42
	for i in count:
		var particle := _particles[_next]
		_next = (_next + 1) % _particles.size()
		var angle := _random.randf_range(0.0, TAU)
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		particle.origin = ground_point + radial * _random.randf_range(0.02, spread) + Vector3.UP * 0.05
		particle.velocity = radial * _random.randf_range(0.18, 0.62) - motion * 0.065 + Vector3.UP * 0.25
		particle.age = 0.0
		particle.run_drag = 0.0
		particle.landing_tick = -1
		particle.duration = _random.randf_range(0.19, 0.28) if landed else _random.randf_range(0.14, 0.22)
		particle.opacity = 0.58 if landed else (0.44 if running else 0.36)
		particle.sprite.frame = FRAMES[_random.randi_range(0, FRAMES.size() - 1)]
		particle.sprite.pixel_size = _random.randf_range(0.010, 0.016) if landed else _random.randf_range(0.007, 0.013)
		if heavy:
			particle.velocity = radial * _random.randf_range(0.65, 1.45) + Vector3.UP * _random.randf_range(0.45, 0.85)
			particle.duration = _random.randf_range(0.28, 0.40)
			particle.opacity = 0.72
			particle.sprite.pixel_size *= 1.45
		particle.sprite.scale = Vector3.ONE
		particle.sprite.global_position = particle.origin
		particle.sprite.modulate = Color(tint, particle.opacity)
		particle.sprite.show()
	set_process(true)

func _emit_run_dust(ground_point: Vector3, surface: String, size: float) -> void:
	# NS_Step_Dust spawns one sprite 20 cm above the supported foot, with
	# zero initial velocity and an upward acceleration of 100 cm/s².
	var particle := _particles[_next]
	_next = (_next + 1) % _particles.size()
	particle.origin = ground_point + Vector3.UP * 0.20
	particle.velocity = Vector3.ZERO
	particle.age = 0.0
	particle.duration = _random.randf_range(0.80, 1.75)
	particle.run_drag = _random.randf_range(4.0, 10.0)
	particle.landing_tick = -1
	_show_source_particle(particle, surface, size, _run_alpha[0])
	set_process(true)

func _emit_source_landing(ground_point: Vector3, surface: String) -> void:
	# NS_PlayerLanding_Medium_Dust at full scalability. The launch occupies
	# the band from 85 to 90 degrees about the vertical axis.
	for i in _random.randi_range(4, 6):
		var particle := _particles[_next]
		_next = (_next + 1) % _particles.size()
		particle.origin = ground_point + Vector3.UP * 0.50
		particle.landing_position = particle.origin
		particle.landing_tick = 0
		particle.age = 0.0
		particle.duration = _random.randf_range(1.0, 2.0)
		particle.run_drag = 0.0
		var yaw := _random.randf_range(0.0, TAU)
		var up := _random.randf_range(0.0, sin(deg_to_rad(5.0)))
		var planar := sqrt(1.0 - up * up)
		particle.velocity = Vector3(cos(yaw) * planar, up, sin(yaw) * planar) * _random.randf_range(20.0, 35.0)
		_show_source_particle(particle, surface, 1.0, _landing_alpha[0])
	set_process(true)

func _show_source_particle(particle: Particle, surface: String, size: float, alpha: float) -> void:
	particle.sprite.frame = FRAMES[_random.randi_range(0, FRAMES.size() - 1)]
	particle.sprite.pixel_size = size / 16.0
	particle.sprite.scale = Vector3.ONE
	particle.sprite.global_position = particle.origin
	particle.sprite.modulate = Color(SURFACE_DUST.get(surface, SURFACE_DUST.grass), alpha)
	particle.sprite.show()

static func _sample_curve(curve: PackedFloat32Array, normalized_age: float) -> float:
	var cursor := clampf(normalized_age, 0.0, 1.0) * (curve.size() - 1)
	var index := floori(cursor)
	return lerpf(curve[index], curve[mini(index + 1, curve.size() - 1)], cursor - index)

func _update_source_landing(particle: Particle) -> void:
	# Use the cooked semi-implicit velocity update on a fixed clock, with
	# interpolation to the current render time between simulation ticks.
	var tick := floori(particle.age / LANDING_STEP)
	while particle.landing_tick < tick:
		particle.landing_tick += 1
		var progress := particle.landing_tick * LANDING_STEP / particle.duration
		var drag := _sample_curve(_landing_drag, progress)
		particle.velocity = (particle.velocity + Vector3.UP * 0.50 * LANDING_STEP) / (1.0 + drag * LANDING_STEP)
		particle.landing_position += particle.velocity * LANDING_STEP
	var remainder := particle.age - particle.landing_tick * LANDING_STEP
	var next_drag := _sample_curve(_landing_drag, (particle.landing_tick + 1) * LANDING_STEP / particle.duration)
	var next_velocity := (particle.velocity + Vector3.UP * 0.50 * LANDING_STEP) / (1.0 + next_drag * LANDING_STEP)
	particle.sprite.global_position = particle.landing_position + next_velocity * remainder
	particle.sprite.modulate.a = _sample_curve(_landing_alpha, particle.age / (particle.duration * _landing_alpha_duration))

func _process(delta: float) -> void:
	var active := false
	for particle in _particles:
		if not particle.sprite.visible:
			continue
		particle.age += delta
		if particle.age >= particle.duration:
			particle.sprite.hide()
			continue
		var progress := particle.age / particle.duration
		if particle.landing_tick >= 0:
			_update_source_landing(particle)
			active = true
			continue
		if particle.run_drag > 0.0:
			# Closed form of upward acceleration with linear drag, sampled
			# by age so the rendered path is independent of render cadence.
			var drag := particle.run_drag
			var height := (particle.age - (1.0 - exp(-drag * particle.age)) / drag) / drag
			particle.sprite.global_position = particle.origin + Vector3.UP * height
			particle.sprite.modulate.a = _sample_curve(_run_alpha, progress / _run_alpha_duration)
			active = true
			continue
		particle.sprite.global_position = particle.origin + particle.velocity * particle.age * (1.0 - 0.4 * progress)
		particle.sprite.scale = Vector3.ONE * (1.0 + 0.35 * progress)
		particle.sprite.modulate.a = particle.opacity * (1.0 - smoothstep(0.12, 1.0, progress))
		active = true
	set_process(active)

func clear() -> void:
	_heavy_landing_frame = -1
	_burst_frame = -1
	set_physics_process(false)
	for particle in _particles:
		particle.sprite.hide()
	set_process(false)
