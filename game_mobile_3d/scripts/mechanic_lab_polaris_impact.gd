extends MultiMeshInstance3D
## MechanicLab adapter for the NS_ArrowHit_Generic velocity-aligned sprites.

const Source := preload("res://scripts/mechanic_lab_weapon_source.gd")
const SHADER := preload("res://materials/mechanic_lab_polaris_impact.gdshader")
const CURVE_PATH := "reports/depth/vfx/polaris-impact-curves.private.json"
const CURVE_HASH := "015f9dceb8c6f2527dc79b457d296164135839fb4db3a15ad588deb9d05cd76e"
# 25 bolts in a full magazine, with at most ten sprites per bolt.
const CAPACITY := 250
const COLOR_DIVISOR := 250.0
# Linear User.Color on the saved PlayerChargedArrow component. The Lab
# uses that tint for an opening accent, with the existing warm fade.
const CHARGED_ACCENT_RGB := Vector3(0.058977, 0.587809, 1.0)
const SURFACE_GAP := 0.003
const OPEN_SPRITE := Color(0.5, 0.5, 1.0)

class Spark:
	var point: Vector3
	var velocity: Vector3
	var acceleration: Vector3
	var size: Vector2
	var age := 0.0
	var first_step := 0.0
	var birth_frame := -1
	var lifetime: float
	var drag: float
	var colors: PackedFloat32Array
	var surface := Plane()

var _particles: Array[Spark] = []
var _forward_colors: PackedFloat32Array
var _charged_forward_colors: PackedFloat32Array
var _sphere_colors: PackedFloat32Array
var _sizes: PackedFloat32Array
var _random := RandomNumberGenerator.new()
var _slot := 0
var _active_count := 0
var duration_scale := 1.0
var spawn_count_scale := 1.0

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
	_charged_forward_colors = _forward_colors.duplicate()
	var charge_tint := CHARGED_ACCENT_RGB.lerp(Vector3.ONE, 0.22)
	for sample in 128:
		var offset := sample * 4
		var warm := Vector3(_forward_colors[offset], _forward_colors[offset + 1], _forward_colors[offset + 2])
		var mix_weight := 1.0 - smoothstep(0.08, 0.27, sample / 127.0)
		var rgb := warm.lerp(charge_tint * warm.x, mix_weight)
		_charged_forward_colors[offset] = rgb.x
		_charged_forward_colors[offset + 1] = rgb.y
		_charged_forward_colors[offset + 2] = rgb.z
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var quad := QuadMesh.new()
	quad.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
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

func set_opacity(opacity: float) -> void:
	visible = opacity > 0.0
	var material := multimesh.mesh.material as ShaderMaterial
	material.set_shader_parameter("opacity_scale", opacity)

func burst(point: Vector3, direction: Vector3, normal: Vector3, first_step: float,
		on_terrain := false, charged := false) -> void:
	# The engine-side impact rotation is approximated from the surface normal.
	# Native local X points out of the surface and local Z points up.
	var axis := normal.normalized() if not normal.is_zero_approx() else -direction.normalized()
	var up := Vector3.UP if absf(axis.y) < 0.99 else Vector3.FORWARD
	var spread_axis := Basis.looking_at(axis, up, true).y
	var outside := point + axis * SURFACE_GAP
	var surface := Plane()
	if on_terrain:
		surface = Plane(axis, axis.dot(outside))
		# On flat ground, lift the scatter along the incoming shot instead
		# of choosing an arbitrary horizontal axis for the upward normal.
		var floor_axis := (axis + direction.slide(axis) * 0.8).normalized()
		spread_axis = spread_axis.lerp(floor_axis, smoothstep(0.70, 1.0, absf(axis.y))).normalized()
	var birth_frame := Engine.get_process_frames()
	# Niagara's system update truncates the independently scaled burst counts.
	var forward_count := int(_random.randi_range(4, 5) * spawn_count_scale)
	var forward_colors := _charged_forward_colors if charged else _forward_colors
	for i in forward_count:
		var velocity := _cone_direction(axis, 0.2) * _random.randf_range(11.0, 20.0)
		_spawn(outside, velocity, -axis * 1.5, Vector2(_random.randf_range(0.08, 0.13), 0.08),
			_random.randf_range(0.2, 0.4), 9.0, forward_colors, first_step, birth_frame, surface)
	var sphere_count := int(_random.randi_range(4, 5) * spawn_count_scale)
	for i in sphere_count:
		var offset := _cone_direction(Vector3.UP, 1.0) * (0.30 * pow(_random.randf(), 1.0 / 3.0))
		var velocity := _cone_direction(spread_axis, 0.8) * _random.randf_range(5.0, 12.0)
		if on_terrain:
			# Fold the sphere and inward velocity into the exposed hemisphere.
			offset -= 2.0 * minf(0.0, offset.dot(axis)) * axis
			velocity -= 2.0 * minf(0.0, velocity.dot(axis)) * axis
		_spawn(outside + offset, velocity, Vector3.DOWN * 1.5, Vector2(_random.randf_range(0.09, 0.13), 0.07),
			_random.randf_range(0.2, 0.3), 4.0, _sphere_colors, first_step, birth_frame, surface)

func _cone_direction(axis: Vector3, spread: float) -> Vector3:
	var minimum := cos(PI * _random.randf() * spread) if spread < 1.0 else -1.0
	var axial := _random.randf_range(minimum, 1.0)
	var radial := sqrt(maxf(0.0, 1.0 - axial * axial))
	var azimuth := _random.randf_range(0.0, TAU)
	var up := Vector3.UP if absf(axis.y) < 0.99 else Vector3.FORWARD
	return Basis.looking_at(axis, up, true) * Vector3(radial * cos(azimuth), radial * sin(azimuth), axial)

func _spawn(point: Vector3, velocity: Vector3, acceleration: Vector3, size: Vector2,
		lifetime: float, drag: float, colors: PackedFloat32Array, first_step: float, birth_frame: int, surface: Plane) -> void:
	var spark := _particles[_slot]
	_slot = (_slot + 1) % CAPACITY
	spark.point = point
	spark.velocity = velocity
	spark.acceleration = acceleration
	spark.size = size
	spark.age = 0.0
	spark.first_step = first_step
	spark.birth_frame = birth_frame
	spark.lifetime = lifetime
	spark.drag = drag
	spark.colors = colors
	spark.surface = surface
	_active_count = mini(CAPACITY, _active_count + 1)

func advance(delta: float) -> bool:
	if _active_count == 0:
		return false
	var camera := get_viewport().get_camera_3d()
	var view := camera.global_basis if camera != null else Basis.IDENTITY
	var inverse := global_transform.affine_inverse()
	var render_frame := Engine.get_process_frames()
	var count := 0
	for spark in _particles:
		if spark.age >= spark.lifetime:
			continue
		# Use the real partial collision tick, then retain that sample across
		# any other physics steps preceding the first rendered impact.
		var step := 0.0
		if spark.first_step < INF or spark.birth_frame != render_frame:
			step = minf(spark.first_step, delta) / duration_scale
		spark.first_step = INF
		spark.age += step
		if spark.age >= spark.lifetime:
			continue
		# The cooked Niagara update divides the updated velocity by 1 + drag * dt.
		if step > 0.0:
			spark.velocity = (spark.velocity + spark.acceleration * step) / (1.0 + spark.drag * step)
			spark.point += spark.velocity * step
			# Each terrain spark reuses the projectile's contact plane.
			# Sliding along it avoids separate physics queries for each sprite.
			var penetration := spark.surface.distance_to(spark.point)
			if penetration < 0.0:
				spark.point -= spark.surface.normal * penetration
				spark.velocity -= spark.surface.normal * minf(0.0, spark.velocity.dot(spark.surface.normal))
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
		var plane_data := OPEN_SPRITE
		if not spark.surface.normal.is_zero_approx():
			var normal := spark.surface.normal
			var slope := Vector2(sprite.x.dot(normal), sprite.y.dot(normal))
			var span := absf(slope.x) + absf(slope.y)
			var clearance := maxf(0.0, spark.surface.distance_to(spark.point))
			if clearance < span * 0.5:
				# COLOR carries the normalized plane in the unit quad's XY.
				# Keep the Niagara palette in INSTANCE_CUSTOM.
				slope /= span
				plane_data = Color(0.5 + 0.5 * slope.x, 0.5 + 0.5 * slope.y, clearance / span)
		multimesh.set_instance_transform(count, inverse * Transform3D(sprite, spark.point))
		multimesh.set_instance_color(count, plane_data)
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
