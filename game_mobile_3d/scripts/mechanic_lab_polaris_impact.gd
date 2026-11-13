extends MultiMeshInstance3D
## MechanicLab adapter for the NS_ArrowHit_Generic velocity-aligned sprites.

const Source := preload("res://scripts/mechanic_lab_weapon_source.gd")
const SHADER := preload("res://materials/mechanic_lab_polaris_impact.gdshader")
const CURVE_PATH := "reports/depth/vfx/polaris-impact-curves.private.json"
const CURVE_HASH := "015f9dceb8c6f2527dc79b457d296164135839fb4db3a15ad588deb9d05cd76e"
# 25 bolts in a full magazine, with at most ten sprites per bolt.
const CAPACITY := 250
const COLOR_DIVISOR := 250.0

class Spark:
	var point: Vector3
	var velocity: Vector3
	var acceleration: Vector3
	var size: Vector2
	var age := 0.0
	var lifetime: float
	var drag: float
	var colors: PackedFloat32Array

var _particles: Array[Spark] = []
var _forward_colors: PackedFloat32Array
var _sphere_colors: PackedFloat32Array
var _sizes: PackedFloat32Array
var _random := RandomNumberGenerator.new()
var _slot := 0
var _active_count := 0

func setup(research_root: String) -> bool:
	var path := Source.verified_path(research_root, CURVE_PATH, CURVE_HASH)
	if path.is_empty():
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema") != "mechanic-lab-md2-polaris-impact/1":
		return false
	_forward_colors = PackedFloat32Array(data.forward_rgba)
	_sphere_colors = PackedFloat32Array(data.sphere_rgba)
	_sizes = PackedFloat32Array(data.size_xy)
	if _forward_colors.size() != 512 or _sphere_colors.size() != 512 or _sizes.size() != 206:
		return false
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var quad := QuadMesh.new()
	quad.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in CAPACITY:
		var spark := Spark.new()
		spark.lifetime = 0.0
		_particles.append(spark)
	_random.seed = 84713
	return true

func burst(point: Vector3, direction: Vector3, normal: Vector3) -> void:
	# The engine-side impact rotation is approximated from the surface normal.
	# Native local X points out of the surface and local Z points up.
	var axis := normal.normalized() if not normal.is_zero_approx() else -direction.normalized()
	var up := Vector3.UP if absf(axis.y) < 0.99 else Vector3.FORWARD
	var frame := Basis.looking_at(axis, up, true)
	var outside := point + axis * 0.003
	for i in _random.randi_range(4, 5):
		var velocity := _cone_direction(axis, 0.2) * _random.randf_range(11.0, 20.0)
		_spawn(outside, velocity, -axis * 1.5, Vector2(_random.randf_range(0.08, 0.13), 0.08),
			_random.randf_range(0.2, 0.4), 9.0, _forward_colors)
	for i in _random.randi_range(4, 5):
		var offset := _cone_direction(Vector3.UP, 1.0) * (0.30 * pow(_random.randf(), 1.0 / 3.0))
		var velocity := _cone_direction(frame.y, 0.8) * _random.randf_range(5.0, 12.0)
		_spawn(outside + offset, velocity, Vector3.DOWN * 1.5, Vector2(_random.randf_range(0.09, 0.13), 0.07),
			_random.randf_range(0.2, 0.3), 4.0, _sphere_colors)

func _cone_direction(axis: Vector3, spread: float) -> Vector3:
	var minimum := cos(PI * _random.randf() * spread) if spread < 1.0 else -1.0
	var axial := _random.randf_range(minimum, 1.0)
	var radial := sqrt(maxf(0.0, 1.0 - axial * axial))
	var azimuth := _random.randf_range(0.0, TAU)
	var up := Vector3.UP if absf(axis.y) < 0.99 else Vector3.FORWARD
	return Basis.looking_at(axis, up, true) * Vector3(radial * cos(azimuth), radial * sin(azimuth), axial)

func _spawn(point: Vector3, velocity: Vector3, acceleration: Vector3, size: Vector2,
		lifetime: float, drag: float, colors: PackedFloat32Array) -> void:
	var spark := _particles[_slot]
	_slot = (_slot + 1) % CAPACITY
	spark.point = point
	spark.velocity = velocity
	spark.acceleration = acceleration
	spark.size = size
	spark.age = 0.0
	spark.lifetime = lifetime
	spark.drag = drag
	spark.colors = colors
	_active_count = mini(CAPACITY, _active_count + 1)

func advance(delta: float) -> bool:
	if _active_count == 0:
		return false
	var camera := get_viewport().get_camera_3d()
	var view := camera.global_basis if camera != null else Basis.IDENTITY
	var inverse := global_transform.affine_inverse()
	var count := 0
	for spark in _particles:
		if spark.age >= spark.lifetime:
			continue
		spark.age += delta
		if spark.age >= spark.lifetime:
			continue
		# The cooked Niagara update divides the updated velocity by 1 + drag * dt.
		spark.velocity = (spark.velocity + spark.acceleration * delta) / (1.0 + spark.drag * delta)
		spark.point += spark.velocity * delta
		var life_fraction := spark.age / spark.lifetime
		var size_cursor := life_fraction * 102.0
		var size := spark.size * Vector2(_sample(_sizes, size_cursor, 2, 0), _sample(_sizes, size_cursor, 2, 1))
		var color_cursor := life_fraction * 127.0
		var color := Color(
			_sample(spark.colors, color_cursor, 4, 0) / COLOR_DIVISOR,
			_sample(spark.colors, color_cursor, 4, 1) / COLOR_DIVISOR,
			_sample(spark.colors, color_cursor, 4, 2) / COLOR_DIVISOR,
			_sample(spark.colors, color_cursor, 4, 3))
		var length_axis := spark.velocity.slide(view.z).normalized()
		if length_axis.is_zero_approx():
			length_axis = view.y
		var width_axis := length_axis.cross(view.z)
		var sprite := Basis(width_axis * size.x, length_axis * size.y, view.z)
		multimesh.set_instance_transform(count, inverse * Transform3D(sprite, spark.point))
		multimesh.set_instance_custom_data(count, color)
		count += 1
	_active_count = count
	multimesh.visible_instance_count = count
	return count > 0

static func _sample(curve: PackedFloat32Array, cursor: float, stride: int, channel: int) -> float:
	var index := int(cursor) * stride + channel
	var next := mini(index + stride, curve.size() - stride + channel)
	return lerpf(curve[index], curve[next], fposmod(cursor, 1.0))

func clear() -> void:
	for spark in _particles:
		spark.age = spark.lifetime
	_slot = 0
	_active_count = 0
	multimesh.visible_instance_count = 0
