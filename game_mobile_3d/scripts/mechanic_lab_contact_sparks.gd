extends Node3D

const EffectSource := preload("res://scripts/mechanic_lab_effect_source.gd")
const STREAK_SHADER := preload("res://materials/mechanic_lab_contact_sparks.gdshader")
const SOURCE := "extracted/2026-10-25 19-26-25/Game/Spicewood/Materials/Common/T_PixelStreaksVertical.png"
const SOURCE_SHA256 := "62965f5ebeead3815fc44ecb3b4f8de27b929d907980e8cae8178c1f260c0c00"
const SOURCE_REGION := Rect2i(101, 8, 5, 14)
const SPARKS_PER_CONTACT := 9
const CONTACTS_PER_FRAME := 5
const CAPACITY := CONTACTS_PER_FRAME * SPARKS_PER_CONTACT
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
var _pending: Array[Dictionary] = []
var _next := 0
var _contact_budget := CONTACTS_PER_FRAME
var _sparks_per_contact := SPARKS_PER_CONTACT
var _pool_limit := CAPACITY
var _random := RandomNumberGenerator.new()
var _display_clock: Callable
var duration_scale := 1.0

func setup(display_clock := Callable()) -> bool:
	var source := EffectSource.load_image(SOURCE, SOURCE_SHA256, Vector2i(128, 128))
	if source == null:
		return false
	_display_clock = display_clock
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

func set_opacity(opacity: float) -> void:
	visible = opacity > 0.0
	var material := _streaks.mesh.material as ShaderMaterial
	material.set_shader_parameter("opacity_scale", opacity)

func set_budget_scale(scale: float) -> void:
	_contact_budget = ceili(CONTACTS_PER_FRAME * scale)
	_sparks_per_contact = ceili(SPARKS_PER_CONTACT * scale)
	_pool_limit = _contact_budget * _sparks_per_contact
	_next %= _pool_limit
	# Preserve the nearest scheduled contacts and let visible sparks finish fading.
	if _pending.size() > _contact_budget:
		_pending.resize(_contact_budget)

func queue_contact(point: Vector3, attack_direction: Vector3, viewer: Vector3, sample_time := -1.0,
		capsule := Vector2.ZERO, weapon_points := PackedVector3Array()) -> void:
	var distance := point.distance_squared_to(viewer)
	var index := _pending.size()
	while index > 0 and distance < float(_pending[index - 1].distance):
		index -= 1
	if index == _contact_budget:
		return
	_pending.insert(index, {"point": point, "direction": attack_direction, "distance": distance,
		"sample_time": sample_time, "capsule": capsule, "weapon_points": weapon_points})
	if _pending.size() > _contact_budget:
		_pending.pop_back()
	set_process(true)

func _contact_surface_point(centre: Vector3, capsule: Vector2, weapon_points: PackedVector3Array, direction: Vector3) -> Vector3:
	var axis := Vector3.UP * capsule.y
	var body_point: Vector3
	var weapon_point: Vector3
	if weapon_points.size() == 1:
		weapon_point = weapon_points[0]
		body_point = Geometry3D.get_closest_point_to_segment(weapon_point, centre - axis, centre + axis)
	else:
		var closest := Geometry3D.get_closest_points_between_segments(
			centre - axis, centre + axis, weapon_points[0], weapon_points[1])
		body_point = closest[0]
		weapon_point = closest[1]
	var normal := (weapon_point - body_point).normalized()
	if normal.is_zero_approx():
		normal = -direction.normalized()
	return body_point + normal * capsule.x

func _spawn_burst(point: Vector3, attack_direction: Vector3) -> void:
	var angle := _random.randf_range(0.0, TAU)
	var bias := attack_direction.normalized() * 0.24
	for i in _sparks_per_contact:
		var yaw := angle + TAU * float(i) / _sparks_per_contact + _random.randf_range(-0.17, 0.17)
		var outward := Vector3(cos(yaw), _random.randf_range(-0.42, 0.8), sin(yaw))
		outward = (outward + bias).normalized()
		var spark := _particles[_next]
		_next = (_next + 1) % _pool_limit
		spark.origin = point + outward * 0.21
		spark.velocity = outward * _random.randf_range(2.0, 4.4)
		spark.age = 0.0
		spark.lifetime = _random.randf_range(0.15, 0.24)
		spark.length = _random.randf_range(0.15, 0.26)
		spark.width = _random.randf_range(0.045, 0.075)

func _process(delta: float) -> void:
	# The elapsed frame only advances streaks that were already displayed.
	var step := delta / duration_scale
	for spark in _particles:
		if spark.age < spark.lifetime:
			spark.age += step
	var display_time := float(_display_clock.call()) if not _pending.is_empty() and _display_clock.is_valid() else INF
	var pending_index := 0
	while pending_index < _pending.size():
		var contact := _pending[pending_index]
		if contact.sample_time > display_time:
			pending_index += 1
			continue
		var point: Vector3 = contact.point
		if contact.capsule.x > 0.0 and not contact.weapon_points.is_empty():
			point = _contact_surface_point(point, contact.capsule, contact.weapon_points, contact.direction)
		_spawn_burst(point, contact.direction)
		_pending.remove_at(pending_index)
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
		count += 1
	_streaks.visible_instance_count = count
	set_process(count > 0 or not _pending.is_empty())

func clear() -> void:
	_pending.clear()
	for spark in _particles:
		spark.age = spark.lifetime
	_streaks.visible_instance_count = 0
	set_process(false)
