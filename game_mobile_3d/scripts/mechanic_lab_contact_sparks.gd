extends Node3D

const EffectSource := preload("res://scripts/mechanic_lab_effect_source.gd")
const STREAK_SHADER := preload("res://materials/mechanic_lab_contact_sparks.gdshader")
const SOURCE := "extracted/2026-10-25 19-26-25/Game/Spicewood/Materials/Common/T_PixelStreaksVertical.png"
const SOURCE_SHA256 := "62965f5ebeead3815fc44ecb3b4f8de27b929d907980e8cae8178c1f260c0c00"
const SOURCE_REGION := Rect2i(101, 8, 5, 14)
const CAPACITY := 48
const SPARKS_PER_CONTACT := 9
const HOT := Color(1.0, 0.89, 0.54)
const COOL := Color(1.0, 0.44, 0.10)

class Spark:
	var origin: Vector3
	var velocity: Vector3
	var age := 0.0
	var lifetime := 0.0
	var length := 0.0
	var width := 0.0

var _streaks: MultiMesh
var _particles: Array[Spark] = []
var _next := 0
var _random := RandomNumberGenerator.new()

func setup() -> bool:
	var source := EffectSource.load_image(SOURCE, SOURCE_SHA256, Vector2i(128, 128))
	if source == null:
		return false
	var mask := Image.create_empty(SOURCE_REGION.size.x, SOURCE_REGION.size.y, false, Image.FORMAT_RGBA8)
	for y in mask.get_height():
		for x in mask.get_width():
			var opacity := source.get_pixelv(SOURCE_REGION.position + Vector2i(x, y)).r
			mask.set_pixel(x, y, Color(1.0, 1.0, 1.0, opacity))
	var material := ShaderMaterial.new()
	material.shader = STREAK_SHADER
	material.set_shader_parameter(&"streak_mask", ImageTexture.create_from_image(mask))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material
	_streaks = MultiMesh.new()
	_streaks.transform_format = MultiMesh.TRANSFORM_3D
	_streaks.use_colors = true
	_streaks.mesh = quad
	_streaks.instance_count = CAPACITY
	_streaks.visible_instance_count = 0
	var renderer := MultiMeshInstance3D.new()
	renderer.name = "Streaks"
	renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	renderer.multimesh = _streaks
	add_child(renderer)
	for i in CAPACITY:
		_particles.append(Spark.new())
	_random.seed = 58136
	set_process(false)
	return true

func burst(point: Vector3, attack_direction: Vector3) -> void:
	var angle := _random.randf_range(0.0, TAU)
	for i in SPARKS_PER_CONTACT:
		var yaw := angle + TAU * float(i) / SPARKS_PER_CONTACT + _random.randf_range(-0.17, 0.17)
		var outward := Vector3(cos(yaw), _random.randf_range(-0.42, 0.8), sin(yaw))
		outward = (outward + attack_direction.normalized() * 0.24).normalized()
		var spark := _particles[_next]
		_next = (_next + 1) % _particles.size()
		spark.origin = point + outward * 0.09
		spark.velocity = outward * _random.randf_range(2.0, 4.4)
		spark.age = 0.0
		spark.lifetime = _random.randf_range(0.15, 0.24)
		spark.length = _random.randf_range(0.15, 0.26)
		spark.width = _random.randf_range(0.045, 0.075)
	set_process(true)

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var view := camera.global_basis.orthonormalized() if camera != null else Basis.IDENTITY
	var count := 0
	for spark in _particles:
		if spark.age >= spark.lifetime:
			continue
		var progress := spark.age / spark.lifetime
		var distance_time := spark.age * (1.0 - 0.42 * progress)
		var point := spark.origin + spark.velocity * distance_time
		var up := spark.velocity.slide(view.z).normalized()
		if up.is_zero_approx():
			up = view.y
		var side := up.cross(view.z)
		var size := 1.0 - 0.58 * progress
		var basis := Basis(side * spark.width * size, up * spark.length * size, view.z)
		_streaks.set_instance_transform(count, Transform3D(basis, to_local(point)))
		var color := HOT.lerp(COOL, smoothstep(0.22, 1.0, progress))
		color.a = 1.0 - smoothstep(0.18, 1.0, progress)
		_streaks.set_instance_color(count, color)
		spark.age += delta
		count += 1
	_streaks.visible_instance_count = count
	set_process(count > 0)

func clear() -> void:
	for spark in _particles:
		spark.age = spark.lifetime
	_streaks.visible_instance_count = 0
	set_process(false)
