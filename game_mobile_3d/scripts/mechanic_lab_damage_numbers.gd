extends MultiMeshInstance3D

const SHADER := preload("res://materials/mechanic_lab_damage_numbers.gdshader")
const DIGIT_SIZE := 32
const DIGIT_COUNT := 10
const DIGIT_ADVANCE := 24.5
const NUMBER_PIXEL_SIZE := 0.0144
const NUMBER_DURATION := 0.68
const POP_DURATION := 0.11
const FADE_DURATION := 0.28
const INITIAL_CAPACITY := 64
# A full buffer upload is cheaper for bursts. Sparse hits can write just the live slots.
const BUFFER_UPLOAD_MIN_GLYPHS := 48
const INSTANCE_FLOATS := 16
const LAYOUT_CELL := 0.24
const LAYOUT_POP_SCALE := 1.16
const LAYOUT_STEPS := [
	Vector2.ZERO, Vector2(0, 1.15), Vector2(-1.15, 0), Vector2(1.15, 0),
	Vector2(-0.85, 1.15), Vector2(0.85, 1.15), Vector2(0, 2.05),
]

class DamageNumber:
	var ascii_digits: PackedByteArray
	var origin: Vector3
	var travel: Vector3
	var age := 0.0
	var pending := true
	var centre: Vector3
	var depth: float
	var hit_order: int
	var layout_offset := Vector2.ZERO
	var layout_pending := true

var _numbers: Array[DamageNumber] = []
var _instance_buffer := PackedFloat32Array()
var _next_hit_order := 0

func setup(glyphs: Array[Texture2D]) -> void:
	var atlas := Image.create_empty(DIGIT_SIZE * DIGIT_COUNT, DIGIT_SIZE, false, Image.FORMAT_RGBA8)
	for i in DIGIT_COUNT:
		atlas.blit_rect(glyphs[i].get_image(), Rect2i(0, 0, DIGIT_SIZE, DIGIT_SIZE), Vector2i(i * DIGIT_SIZE, 0))
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = 1
	material.set_shader_parameter("digits", ImageTexture.create_from_image(atlas))
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = DIGIT_SIZE * NUMBER_PIXEL_SIZE
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * DIGIT_SIZE * NUMBER_PIXEL_SIZE
	multimesh = MultiMesh.new()
	multimesh.mesh = quad
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.instance_count = INITIAL_CAPACITY
	multimesh.visible_instance_count = 0
	set_process(false)

func add_number(amount: int, origin: Vector3, lateral: Vector3) -> void:
	var number := DamageNumber.new()
	number.hit_order = _next_hit_order
	_next_hit_order += 1
	number.ascii_digits = str(amount).to_ascii_buffer()
	number.origin = origin + lateral * 0.12
	number.travel = Vector3.UP * 0.74 + lateral * 0.32
	_numbers.append(number)
	set_process(true)

func _process(delta: float) -> void:
	var glyph_count := 0
	var has_new_numbers := false
	for i in range(_numbers.size() - 1, -1, -1):
		var number := _numbers[i]
		# The first render delta can include time before this hit.
		if number.pending:
			number.pending = false
			has_new_numbers = true
		else:
			number.age += delta
		if number.age >= NUMBER_DURATION:
			_numbers.remove_at(i)
		else:
			glyph_count += number.ascii_digits.size()
	if glyph_count == 0:
		multimesh.visible_instance_count = 0
		set_process(false)
		return
	if glyph_count > multimesh.instance_count:
		multimesh.instance_count = nearest_po2(glyph_count)
	var upload_buffer := glyph_count >= BUFFER_UPLOAD_MIN_GLYPHS
	if upload_buffer:
		_instance_buffer.resize(multimesh.instance_count * INSTANCE_FLOATS)
	var camera := get_viewport().get_camera_3d()
	var camera_side := camera.global_basis.x if camera != null else Vector3.RIGHT
	var camera_up := camera.global_basis.y if camera != null else Vector3.UP
	var camera_back := camera.global_basis.z if camera != null else Vector3.BACK
	var previous_depth := -INF
	var previous_hit_order := -1
	var needs_sort := false
	for number in _numbers:
		var offset: Vector3 = Tween.interpolate_value(Vector3.ZERO, number.travel,
			number.age, NUMBER_DURATION, Tween.TRANS_QUAD, Tween.EASE_OUT)
		number.centre = number.origin + offset
		number.depth = number.centre.dot(camera_back)
		needs_sort = needs_sort or number.depth < previous_depth \
			or (number.depth == previous_depth and number.hit_order < previous_hit_order)
		previous_depth = number.depth
		previous_hit_order = number.hit_order
	# Draw farther glyphs first, including when two fading numbers overlap.
	# At the same depth, later hits draw over earlier hits.
	if needs_sort:
		_numbers.sort_custom(func(a: DamageNumber, b: DamageNumber) -> bool:
			return a.depth < b.depth or (a.depth == b.depth and a.hit_order < b.hit_order))
	if has_new_numbers and camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_place_new_numbers(camera_side, camera_up)
	var slot := 0
	var local_from_world := global_transform.affine_inverse()
	for number in _numbers:
		var scale: float = Tween.interpolate_value(0.85, 0.28, minf(number.age, POP_DURATION),
			POP_DURATION, Tween.TRANS_BACK, Tween.EASE_OUT)
		var alpha := minf(1.0, (NUMBER_DURATION - number.age) / FADE_DURATION)
		var centre := number.centre + camera_side * number.layout_offset.x + camera_up * number.layout_offset.y
		var spacing := camera_side * (DIGIT_ADVANCE * NUMBER_PIXEL_SIZE * scale)
		var digits := number.ascii_digits
		var middle := (digits.size() - 1) * 0.5
		for i in digits.size():
			var origin := centre + spacing * (i - middle)
			var point := local_from_world * origin
			var digit := digits[i] - 48
			if upload_buffer:
				# MultiMesh stores three row-major transform rows, then four custom floats.
				var offset := slot * INSTANCE_FLOATS
				_instance_buffer[offset] = scale
				_instance_buffer[offset + 3] = point.x
				_instance_buffer[offset + 5] = scale
				_instance_buffer[offset + 7] = point.y
				_instance_buffer[offset + 10] = scale
				_instance_buffer[offset + 11] = point.z
				_instance_buffer[offset + 12] = digit
				_instance_buffer[offset + 13] = alpha
			else:
				multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), point))
				multimesh.set_instance_custom_data(slot, Color(digit, alpha, 0.0, 0.0))
			slot += 1
	if upload_buffer:
		multimesh.buffer = _instance_buffer
	multimesh.visible_instance_count = glyph_count

func _place_new_numbers(side: Vector3, up: Vector3) -> void:
	var occupied := {}
	# Reserve the numbers already on screen. Layout happens at birth so
	# an older number continues to float without snapping to a new lane.
	for number in _numbers:
		if number.layout_pending:
			continue
		var centre := Vector2(number.centre.dot(side), number.centre.dot(up))
		_measure_cells(occupied, centre + number.layout_offset, _label_extent(number), true)
	# The vertex buffer is sorted far to near. Give the nearest new
	# numbers first choice so their hit anchors stay easy to associate.
	for index in range(_numbers.size() - 1, -1, -1):
		var number := _numbers[index]
		if not number.layout_pending:
			continue
		var centre := Vector2(number.centre.dot(side), number.centre.dot(up))
		var extent := _label_extent(number)
		var reach := Vector2(minf(extent.x * 2.0, 1.0), extent.y * 2.0)
		var best := 0x7fffffff
		for step: Vector2 in LAYOUT_STEPS:
			var offset := step * reach
			var score := _measure_cells(occupied, centre + offset, extent, false)
			if score < best:
				best = score
				number.layout_offset = offset
			if score == 0:
				break
		_measure_cells(occupied, centre + number.layout_offset, extent, true)
		number.layout_pending = false

func _label_extent(number: DamageNumber) -> Vector2:
	var size := Vector2(DIGIT_SIZE + DIGIT_ADVANCE * (number.ascii_digits.size() - 1), DIGIT_SIZE)
	return size * (0.5 * NUMBER_PIXEL_SIZE * LAYOUT_POP_SCALE) + Vector2(0.035, 0.035)

func _measure_cells(occupied: Dictionary, centre: Vector2, extent: Vector2, reserve: bool) -> int:
	var first := Vector2i(((centre - extent) / LAYOUT_CELL).floor())
	var last := Vector2i(((centre + extent) / LAYOUT_CELL).floor())
	var score := 0
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var count: int = occupied.get(cell, 0)
			if reserve:
				occupied[cell] = count + 1
			else:
				score += count
	return score
