extends Node3D

const PrivatePath := preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/reference_audio.gd")
const SOURCE := "extracted/2026-10-25 19-26-25/Game/Spicewood/FX/Smoke/T_SmokePixel.png"
const SOURCE_SHA256 := "78d326787c4065d70e227ec386a7330f53621c8733ad114bc80eaea7f7f1b5fc"
const FRAMES := [0, 9, 10, 16, 24, 25]
const CAPACITY := 16
const GRASS_DUST := Color("#c8b67b")

class Particle:
	var sprite: Sprite3D
	var origin: Vector3
	var velocity: Vector3
	var age := 0.0
	var duration := 0.0
	var opacity := 0.0

var _actor: CharacterBody3D
var _ground: CollisionShape3D
var _particles: Array[Particle] = []
var _next := 0
var _random := RandomNumberGenerator.new()

func setup(actor: CharacterBody3D, ground: CollisionShape3D) -> bool:
	var texture := _load_mask()
	if texture == null:
		return false
	_actor = actor
	_ground = ground
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
	actor.presentation_reset.connect(clear)
	set_process(false)
	return true

static func _load_mask() -> Texture2D:
	if not OS.has_feature("editor"):
		return null
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	var path := PrivatePath.resolve_private_file(root, SOURCE)
	if path.is_empty() or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != SOURCE_SHA256:
		return null
	var atlas := Image.load_from_file(path)
	if atlas == null or atlas.get_size() != Vector2i(128, 64):
		return null
	atlas.convert(Image.FORMAT_RGBA8)
	# The exported RGB channels are masks. Preserve the atlas alpha exactly.
	var pixels := atlas.get_data()
	for i in range(0, pixels.size(), 4):
		pixels[i] = 255
		pixels[i + 1] = 255
		pixels[i + 2] = 255
	return ImageTexture.create_from_image(Image.create_from_data(128, 64, false, Image.FORMAT_RGBA8, pixels))

func _on_surface_contact(point: Vector3, landed: bool) -> void:
	var box := _ground.shape as BoxShape3D
	if _ground.disabled or box == null:
		return
	var half := box.size * 0.5
	var local := _ground.to_local(point)
	if absf(local.x) > half.x or absf(local.z) > half.z:
		return
	var ground_point := _ground.to_global(Vector3(local.x, half.y, local.z))
	var motion := _actor.get_real_velocity()
	motion.y = 0.0
	var running := motion.length_squared() > 16.0
	var count := 5 if landed else (3 if running else 2)
	var spread := 0.24 if landed else 0.11
	for i in count:
		var particle := _particles[_next]
		_next = (_next + 1) % _particles.size()
		var angle := _random.randf_range(0.0, TAU)
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		particle.origin = ground_point + radial * _random.randf_range(0.02, spread) + Vector3.UP * 0.05
		particle.velocity = radial * _random.randf_range(0.18, 0.62) - motion * 0.065 + Vector3.UP * 0.25
		particle.age = 0.0
		particle.duration = _random.randf_range(0.19, 0.28) if landed else _random.randf_range(0.14, 0.22)
		particle.opacity = 0.58 if landed else (0.44 if running else 0.36)
		particle.sprite.frame = FRAMES[_random.randi_range(0, FRAMES.size() - 1)]
		particle.sprite.pixel_size = _random.randf_range(0.010, 0.016) if landed else _random.randf_range(0.007, 0.013)
		particle.sprite.scale = Vector3.ONE
		particle.sprite.global_position = particle.origin
		particle.sprite.modulate = Color(GRASS_DUST, particle.opacity)
		particle.sprite.show()
	set_process(true)

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
		particle.sprite.global_position = particle.origin + particle.velocity * particle.age * (1.0 - 0.4 * progress)
		particle.sprite.scale = Vector3.ONE * (1.0 + 0.35 * progress)
		particle.sprite.modulate.a = particle.opacity * (1.0 - smoothstep(0.12, 1.0, progress))
		active = true
	set_process(active)

func clear() -> void:
	for particle in _particles:
		particle.sprite.hide()
	set_process(false)
